extends SceneTree
## The submission collector (docs/specs/benchmark.md §20.4): takes waiting
## submission groups from Supabase, checks each group with `submission_check.gd`
## (including a full `BenchVerifier.check` replay of every file), writes
## accepted files into `<board>/runs/`, and writes the verdicts to `--out` so a
## second invocation (`--confirm=<file>`) after a successful publish marks them
## in the database.
##
##     "$GODOT" --headless --path . -s tools/bench/collect_submissions.gd -- \
##         --board=<leaderboard checkout> --out=<collected.json>
##         [--limit=<n = global.collect_limit>]
##     "$GODOT" --headless --path . -s tools/bench/collect_submissions.gd -- \
##         --confirm=<collected.json>
##
## `SUPABASE_URL` and `SUPABASE_SECRET_KEY` come from the environment only
## (never an argument, never printed). Every line printed begins with `collect:`.

const Harness := preload("res://tools/sim_harness.gd")
const Check := preload("res://tools/bench/submission_check.gd")
const Writer := preload("res://tools/bench/leaderboard_writer.gd")

const EXIT_OK: int = 0
const EXIT_BAD_INPUT: int = 1
const EXIT_WRITE: int = 2

const VERSION: int = 1
const ENV_URL: String = "SUPABASE_URL"
const ENV_KEY: String = "SUPABASE_SECRET_KEY"
const RPC_TAKE: String = "/rest/v1/rpc/take_submissions"
const RPC_MARK: String = "/rest/v1/rpc/mark_submission"
const HEADER_KEY_PREFIX: String = "apikey: "
const HEADER_CONTENT_TYPE: String = "Content-Type: application/json"
const HEADER_ACCEPT: String = "Accept: application/json"
const LINE_PREFIX: String = "collect: "
const TEMP_SUFFIX: String = ".tmp"


func _initialize() -> void:
	quit(run(Harness.parse_args(OS.get_cmdline_user_args())))


## The whole tool; `config` null reads `data/benchmark.json`, `env` empty reads
## the process environment, `transport` unset uses `OpenRouterBackend.request`.
static func run(args: Dictionary[String, String], config: BenchConfig = null,
		env: Dictionary = {}, transport: Callable = Callable()) -> int:
	if config == null:
		config = BenchConfig.load_file()
	if not config.ok():
		for error: String in config.errors:
			say("config: %s" % JSON.stringify(error))
		return EXIT_BAD_INPUT
	if args.has("confirm"):
		return _confirm(args.get("confirm", ""), config, env, transport)
	return _collect(args, config, env, transport)


static func _collect(args: Dictionary[String, String], config: BenchConfig,
		env: Dictionary, transport: Callable) -> int:
	var db: ContentDB = Harness.load_content(Harness.DEFAULT_DATA)
	if db == null:
		say("the content does not load")
		return EXIT_BAD_INPUT
	var setup: RunSetup = RunSetup.from_dict(config.setup)
	if setup == null or not setup.validate(db).is_empty():
		say("config: setup is not a run this content can play")
		return EXIT_BAD_INPUT
	var board: String = args.get("board", "")
	if board.is_empty() or not DirAccess.dir_exists_absolute(board.path_join(Writer.RUNS_DIR)):
		say("--board=<dir> must name a leaderboard checkout with a runs/ directory")
		return EXIT_BAD_INPUT
	var out_path: String = args.get("out", "")
	if out_path.is_empty():
		say("--out=<file> is required")
		return EXIT_BAD_INPUT
	var limit_text: String = args.get("limit", str(config.global_collect_limit))
	if not limit_text.is_valid_int() or limit_text.to_int() < 1:
		say("--limit is not a whole number above 0")
		return EXIT_BAD_INPUT
	var limit: int = limit_text.to_int()

	var url: String = _env_get(env, ENV_URL).strip_edges().trim_suffix("/")
	var secret_key: String = _env_get(env, ENV_KEY).strip_edges()
	if url.is_empty() or secret_key.is_empty():
		say("no Supabase secret — nothing to collect")
		return EXIT_OK if _write_collected(out_path, []) else EXIT_WRITE

	var headers: PackedStringArray = _supabase_headers(secret_key)
	var take_res: Dictionary = _request(transport, HTTPClient.METHOD_POST, url + RPC_TAKE,
		headers, JSON.stringify({"p_limit": limit}), config.submit_timeout_s)
	var take_status: int = int(take_res.get("status", 0))
	if take_status != OpenRouterBackend.STATUS_OK:
		say("Supabase unreachable (%d) — nothing taken" % take_status)
		return EXIT_OK if _write_collected(out_path, []) else EXIT_WRITE
	var parsed_rows: Variant = JSON.parse_string(str(take_res.get("body", "")))
	if typeof(parsed_rows) != TYPE_ARRAY:
		say("Supabase unreachable (0) — nothing taken")
		return EXIT_OK if _write_collected(out_path, []) else EXIT_WRITE
	var rows: Array = parsed_rows
	if rows.is_empty():
		if not _write_collected(out_path, []):
			return EXIT_WRITE
		say("taken 0, accepted 0, rejected 0, held 0, waiting 0")
		return EXIT_OK

	# Step 3: fetch OpenRouter's public model list (no key).
	var models_res: Dictionary = _request(transport, HTTPClient.METHOD_GET,
		config.base_url + config.models_path, PackedStringArray(), "",
		config.global_timeout_s)
	var known_models: Dictionary[String, bool] = {}
	var models_known: bool = false
	if int(models_res.get("status", 0)) == OpenRouterBackend.STATUS_OK:
		var catalogue: Array[Dictionary] = ModelCatalogue.parse(str(models_res.get("body", "")))
		if not catalogue.is_empty():
			models_known = true
			for row_info: Dictionary in catalogue:
				known_models[str(row_info[ModelCatalogue.FIELD_ID])] = true

	var runs_dir: String = board.path_join(Writer.RUNS_DIR)
	var judged: Array[Dictionary] = []
	var counts: Dictionary[String, int] = {
		"accepted": 0,
		"rejected": 0,
		"held": 0,
		"waiting": 0,
	}
	for item: Variant in rows:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = item
		var id: int = int(row.get("id", 0))
		var row_status: String = str(row.get("status", Check.ROW_NEW))
		if not models_known and row_status != Check.ROW_APPROVED:
			counts["waiting"] += 1
			continue
		var verdict: Dictionary = Check.judge(row, known_models, config, db)
		var v_status: String = str(verdict["status"])
		var v_reason: String = str(verdict["reason"])
		if v_status == Check.STATUS_ACCEPTED:
			var files: Array[Dictionary] = verdict["files"]
			for file_entry: Dictionary in files:
				var file_name: String = str(file_entry["name"])
				var file_body: String = str(file_entry["body"])
				if not _write_file(runs_dir.path_join(file_name), file_body):
					say("could not write %s" % JSON.stringify(file_name))
					return EXIT_WRITE
			counts["accepted"] += 1
		elif v_status == Check.STATUS_HELD:
			counts["held"] += 1
		else:
			counts["rejected"] += 1
		judged.append({
			"id": id,
			"status": v_status,
			"reason": v_reason,
		})

	if not _write_collected(out_path, judged):
		say("could not write %s" % JSON.stringify(out_path))
		return EXIT_WRITE
	say("taken %d, accepted %d, rejected %d, held %d, waiting %d" % [
		rows.size(), counts["accepted"], counts["rejected"], counts["held"], counts["waiting"]])
	return EXIT_OK


static func _confirm(confirm_path: String, config: BenchConfig, env: Dictionary,
		transport: Callable) -> int:
	if confirm_path.is_empty() or not FileAccess.file_exists(confirm_path):
		say("could not read %s" % JSON.stringify(confirm_path))
		return EXIT_BAD_INPUT
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(confirm_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		say("could not read %s" % JSON.stringify(confirm_path))
		return EXIT_BAD_INPUT
	var doc: Dictionary = parsed
	if int(doc.get("version", 0)) != VERSION or typeof(doc.get("groups")) != TYPE_ARRAY:
		say("could not read %s" % JSON.stringify(confirm_path))
		return EXIT_BAD_INPUT
	var groups: Array = doc["groups"]
	if groups.is_empty():
		return EXIT_OK
	var url: String = _env_get(env, ENV_URL).strip_edges().trim_suffix("/")
	var secret_key: String = _env_get(env, ENV_KEY).strip_edges()
	if url.is_empty() or secret_key.is_empty():
		say("no Supabase secret — nothing marked")
		return EXIT_OK
	var headers: PackedStringArray = _supabase_headers(secret_key)
	for item: Variant in groups:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var group: Dictionary = item
		var id: int = int(group.get("id", 0))
		var payload: String = JSON.stringify({
			"p_id": id,
			"p_status": str(group.get("status", "")),
			"p_reason": str(group.get("reason", "")),
		})
		var res: Dictionary = _request(transport, HTTPClient.METHOD_POST, url + RPC_MARK,
			headers, payload, config.submit_timeout_s)
		var status: int = int(res.get("status", 0))
		if status < 200 or status >= 300:
			say("could not mark %d" % id)
	return EXIT_OK


static func say(text: String) -> void:
	print(LINE_PREFIX + text)


static func _env_get(env: Dictionary, key: String) -> String:
	if env.has(key):
		return str(env[key])
	return OS.get_environment(key)


static func _supabase_headers(secret_key: String) -> PackedStringArray:
	return PackedStringArray([
		HEADER_KEY_PREFIX + secret_key,
		HEADER_CONTENT_TYPE,
		HEADER_ACCEPT,
	])


static func _request(transport: Callable, method: int, url: String,
		headers: PackedStringArray, body: String, timeout_s: int) -> Dictionary:
	if transport.is_valid():
		var faked: Variant = transport.call(method, url, headers, body)
		return faked if typeof(faked) == TYPE_DICTIONARY else {"status": 0, "body": ""}
	var base: Dictionary = OpenRouterBackend.parse_base_url(url)
	if base.is_empty():
		return {"status": 0, "body": ""}
	var path: String = str(base["prefix"])
	if path.is_empty():
		path = "/"
	var answer: Dictionary = OpenRouterBackend.request(base, method, path, headers, body,
		timeout_s)
	return {"status": int(answer["status"]), "body": str(answer["body"])}


static func _write_collected(path: String, groups: Array) -> bool:
	var doc: Dictionary = {
		"version": VERSION,
		"groups": groups,
	}
	return _write_file(path, JSON.stringify(doc, "\t", false) + "\n")


static func _write_file(path: String, text: String) -> bool:
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
		return false
	var temp: String = path + TEMP_SUFFIX
	var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(temp, path) == OK
