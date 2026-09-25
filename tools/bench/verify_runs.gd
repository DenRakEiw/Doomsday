extends SceneTree
## The replay verifier (docs/specs/benchmark.md §16.4): every run in a checkout of
## the public leaderboard repository without a current record is replayed on this
## game checkout, its record written to `verified/`, and the board rebuilt from
## the verified runs only. It never plays a model — `bench_run.gd` stays the
## submitter's tool.
##
##     "$GODOT" --headless --path . -s tools/bench/verify_runs.gd -- \
##         --board=<directory of a doomsday-leaderboard checkout> --game-commit=<40-hex>
##         [--limit=<n = global.verify_limit>]
##         [--canary=<path = res://tests/fixtures/bench/determinism_entry.json>]
##         [--today=<YYYY-MM-DD>] [--message=<file>]
##
## Run files are data, only data: names are listed here and checked against a
## pattern before they reach a path, nothing from a file's contents reaches a
## path or a shell, and every line printed begins with `verify:` with its values
## JSON-escaped (the workflow also stops workflow commands around this tool).
##
## Exit codes: 0 done (a rejection is a result, not a failure) · 1 bad arguments,
## content or config errors, no `runs/` in the board · 2 a record or the board
## could not be written · 3 the canary did not reproduce (nothing written).

const Harness := preload("res://tools/sim_harness.gd")
const Verifier := preload("res://tools/bench/bench_verifier.gd")
const VerifyRecord := preload("res://tools/bench/verify_record.gd")
const Writer := preload("res://tools/bench/leaderboard_writer.gd")

const EXIT_OK: int = 0
const EXIT_BAD_INPUT: int = 1
const EXIT_WRITE: int = 2
const EXIT_CANARY: int = 3

const DEFAULT_CANARY: String = "res://tests/fixtures/bench/determinism_entry.json"
const VERIFIED_DIR: String = "verified"
const GENERATOR: String = "tools/bench/verify_runs.gd (the replay verifier)"
const LINE_PREFIX: String = "verify: "
const VERSION_SETTING: String = "application/config/version"
const TEMP_SUFFIX: String = ".tmp"
const JSON_SUFFIX: String = ".json"
## A run file name the verifier reads at all; anything else in `runs/` is ignored.
const RUN_NAME_PATTERN: String = "^[a-z0-9._-]+\\.json$"
const COMMIT_PATTERN: String = "^[0-9a-f]{40}$"
const DATE_PATTERN: String = "^[0-9]{4}-[0-9]{2}-[0-9]{2}$"
## The commit message names the game commit by its first characters.
const SHORT_COMMIT: int = 7
const HASH_CHUNK: int = 65536


func _initialize() -> void:
	quit(run(Harness.parse_args(OS.get_cmdline_user_args())))


## The whole tool; `config` null reads `data/benchmark.json`. The tests call this
## with a config of their own and a board under `user://`.
static func run(args: Dictionary[String, String], config: BenchConfig = null) -> int:
	if config == null:
		config = BenchConfig.load_file()
	if not config.ok():
		for error: String in config.errors:
			say("config: %s" % JSON.stringify(error))
		return EXIT_BAD_INPUT
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
	var commit: String = args.get("game-commit", "")
	if not _matches(COMMIT_PATTERN, commit):
		say("--game-commit=<40 lower-case hex> is required")
		return EXIT_BAD_INPUT
	var limit_text: String = args.get("limit", str(config.global_verify_limit))
	if not limit_text.is_valid_int() or limit_text.to_int() < 1:
		say("--limit is not a whole number above 0")
		return EXIT_BAD_INPUT
	var limit: int = limit_text.to_int()
	var today: String = args.get("today", Time.get_date_string_from_system(true))
	if not _matches(DATE_PATTERN, today):
		say("--today is not YYYY-MM-DD")
		return EXIT_BAD_INPUT
	var message_path: String = args.get("message", "")
	var canary: String = args.get("canary", DEFAULT_CANARY)
	if not FileAccess.file_exists(canary):
		say("the canary %s is missing" % JSON.stringify(canary))
		return EXIT_BAD_INPUT
	var context: Dictionary = {
		Verifier.CONTEXT_COMMIT: commit,
		Verifier.CONTEXT_VERSION: str(ProjectSettings.get_setting(VERSION_SETTING, "")),
		Verifier.CONTEXT_CHECKED: today,
	}

	# §16.8: a machine that does not reproduce the recorded canary would reject
	# every honest run, so it stops before anything is written.
	var canary_record: VerifyRecord = Verifier.check_canary(
		FileAccess.get_file_as_bytes(canary), config, db, context)
	if not canary_record.verified:
		say("canary %s — %s" % [canary_record.reason, JSON.stringify(canary_record.detail)])
		say("canary mismatch — this machine does not reproduce the recorded run; nothing written")
		return EXIT_CANARY

	var verified_dir: String = board.path_join(VERIFIED_DIR)
	if DirAccess.make_dir_recursive_absolute(verified_dir) != OK:
		say("could not create verified/")
		return EXIT_WRITE
	var runs_dir: String = board.path_join(Writer.RUNS_DIR)
	var counts: Dictionary[String, int] = {"checked": 0, "verified": 0, "rejected": 0,
		"waiting": 0, "ignored": 0}
	for file_name: String in _json_files(runs_dir):
		if not _matches(RUN_NAME_PATTERN, file_name):
			counts["ignored"] += 1
			continue
		var run_path: String = runs_dir.path_join(file_name)
		var sha256: String = file_sha256(run_path)
		var record_path: String = verified_dir.path_join(file_name)
		var old: VerifyRecord = read_record(record_path)
		if old != null and old.sha256 == sha256:
			continue
		if counts["checked"] >= limit:
			counts["waiting"] += 1
			continue
		var record: VerifyRecord = _judge(run_path, file_name, sha256, config, db, context)
		if not _write_file(record_path, record.to_json()):
			say("could not write %s" % JSON.stringify(VERIFIED_DIR + "/" + file_name))
			return EXIT_WRITE
		counts["checked"] += 1
		counts["verified" if record.verified else "rejected"] += 1
		say(JSON.stringify({"file": record.file, "verified": record.verified,
			"reason": record.reason, "detail": record.detail}))

	# A record whose run the owner removed goes with it.
	for file_name: String in _json_files(verified_dir):
		if not FileAccess.file_exists(runs_dir.path_join(file_name)):
			if DirAccess.remove_absolute(verified_dir.path_join(file_name)) != OK:
				say("could not remove %s" % JSON.stringify(VERIFIED_DIR + "/" + file_name))
				return EXIT_WRITE

	var records: Dictionary = {}
	for file_name: String in _json_files(verified_dir):
		var record: VerifyRecord = read_record(verified_dir.path_join(file_name))
		if record != null:
			records[file_name] = record.to_dict()
	var rebuilt: Dictionary = Writer.rebuild(board, config, db.content_hash, records, true,
		GENERATOR)
	if not bool(rebuilt["ok"]):
		say("could not write the leaderboard")
		return EXIT_WRITE
	say("checked %d, verified %d, rejected %d, waiting %d, ignored %d, board %s" % [
		counts["checked"], counts["verified"], counts["rejected"], counts["waiting"],
		counts["ignored"], "changed" if bool(rebuilt["changed"]) else "unchanged"])
	if not message_path.is_empty():
		if not _write_file(message_path, commit_message(counts["verified"], counts["rejected"],
				commit)):
			say("could not write the commit message")
			return EXIT_WRITE
	return EXIT_OK


## The public repository's commit message: numbers and the game commit only,
## nothing from a run file.
static func commit_message(verified: int, rejected: int, commit: String) -> String:
	return "verify: %d verified, %d rejected (game %s)\n" % [verified, rejected,
		commit.left(SHORT_COMMIT)]


## Prints one line; every line of this tool begins with `verify:`.
static func say(text: String) -> void:
	print(LINE_PREFIX + text)


## A record file read; null when it is missing or does not read (its run is then
## verified again).
static func read_record(path: String) -> VerifyRecord:
	if not FileAccess.file_exists(path):
		return null
	return VerifyRecord.from_json(FileAccess.get_file_as_string(path)) as VerifyRecord


## The hex SHA-256 of a file, read in chunks so a large one is never held whole;
## "" when it cannot be opened.
static func file_sha256(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	while file.get_position() < file.get_length():
		context.update(file.get_buffer(HASH_CHUNK))
	return context.finish().hex_encode()


## A run judged: a file above the size limit unread, any other from its bytes.
static func _judge(path: String, file_name: String, sha256: String, config: BenchConfig,
		db: ContentDB, context: Dictionary) -> VerifyRecord:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return Verifier.unread(file_name, sha256, 0, config, db, context)
	var size: int = file.get_length()
	if size > config.global_max_run_bytes:
		return Verifier.unread(file_name, sha256, size, config, db, context)
	return Verifier.check(file.get_buffer(size), file_name, config, db, context)


## `<dir>/*.json`, sorted by name, no recursion.
static func _json_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for file_name: String in DirAccess.get_files_at(dir):
		if file_name.ends_with(JSON_SUFFIX):
			out.append(file_name)
	out.sort()
	return out


static func _matches(pattern: String, text: String) -> bool:
	var regex: RegEx = RegEx.create_from_string(pattern)
	return regex.search(text) != null


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
