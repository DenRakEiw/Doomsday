extends GutTest
## S6.12 — the benchmark tool end to end (docs/specs/benchmark.md §11, §14.1) on
## the real content with the `mock:cheapest` backend: the quick suite at 300 days,
## into a board of its own under `user://`. S6.12c: the same for a decision model
## (`mock-choice:first`, §17.10) and the tool's rules for TypeSafe (§17.9).
## Nothing is asked of any service: every TypeSafe case here stops before a
## request (a refused flag, a missing key under a variable no one sets, a dry run).

const Tool := preload("res://tools/bench/bench_run.gd")
const Writer := preload("res://tools/bench/leaderboard_writer.gd")
const Verifier := preload("res://tools/bench/bench_verifier.gd")
const VerifyRecord := preload("res://tools/bench/verify_record.gd")
const COMMIT: String = "0123456789abcdef0123456789abcdef01234567"
## A variable no one sets, so a key check can never find a real key.
const UNSET_KEY_ENV: String = "DOOMSDAY_TEST_KEY_THAT_IS_NEVER_SET"
const BOARD: String = "user://test_bench/run_board"
const CACHE: String = "user://test_bench/run_cache"
const MAX_DAYS: int = 300
const RECORDED: String = "\"recorded\": "

var _config: BenchConfig = null
var _db: ContentDB = null


func before_all() -> void:
	_db = ContentLoader.load_root("res://data").db


func before_each() -> void:
	_config = BenchConfig.load_file()
	_config.max_days = MAX_DAYS
	_clear(BOARD)
	_clear(CACHE)


func after_all() -> void:
	_clear(BOARD)
	_clear(CACHE)


func _clear(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for sub: String in DirAccess.get_directories_at(dir):
		_clear(dir.path_join(sub))
	for file_name: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file_name))
	DirAccess.remove_absolute(dir)


func _mock_args() -> Dictionary[String, String]:
	return {"model": "mock", "backend": "mock:cheapest", "suite": "quick", "out": BOARD,
		"cache": CACHE}


func _runs() -> Dictionary[String, String]:
	var out: Dictionary[String, String] = {}
	var dir: String = BOARD.path_join(Writer.RUNS_DIR)
	for file_name: String in DirAccess.get_files_at(dir):
		out[file_name] = FileAccess.get_file_as_string(dir.path_join(file_name))
	return out


## The file without its `recorded` line — the one field a re-run changes.
func _unrecorded(text: String) -> String:
	var lines: PackedStringArray = []
	for line: String in text.split("\n"):
		if not line.strip_edges().begins_with(RECORDED):
			lines.append(line)
	return "\n".join(lines)


func test_a_mock_run_of_the_quick_suite_replays_and_repeats_exactly() -> void:
	assert_eq(Tool.run(_mock_args(), _config), Tool.EXIT_OK)
	var first: Dictionary[String, String] = _runs()
	assert_eq(first.size(), 3, "one entry per seed")
	for file_name: String in first:
		var entry: BenchEntry = BenchEntry.from_json(first[file_name])
		assert_not_null(entry, BenchEntry.last_error)
		assert_eq(entry.file_name(), file_name)
		assert_eq(entry.max_days, MAX_DAYS)
		var replayed: Simulation = Simulation.replay(_db, entry.seed_value, entry.commands,
			entry.end_day, entry.setup)
		assert_not_null(replayed)
		assert_eq(replayed.state_hash(), entry.state_hash, file_name + " replays to its hash")
	assert_eq(Tool.run(_mock_args(), _config), Tool.EXIT_OK)
	var second: Dictionary[String, String] = _runs()
	assert_eq(second.keys(), first.keys())
	for file_name: String in first:
		assert_eq(_unrecorded(second[file_name]), _unrecorded(first[file_name]), file_name)
	var board: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(BOARD.path_join(Writer.LEADERBOARD_JSON)))
	var rows: Array = board["rows"]
	assert_eq(rows.size(), 1)
	assert_true(bool((rows[0] as Dictionary)["complete"]))
	assert_true(bool((rows[0] as Dictionary)["current"]))
	assert_eq(((rows[0] as Dictionary)["seeds"] as Array).size(), 3)
	assert_true(FileAccess.file_exists(BOARD.path_join(Writer.LEADERBOARD_MD)))
	assert_false(DirAccess.dir_exists_absolute(CACHE), "a mock never touches the cache")


func test_the_bots_write_their_reference_rows_and_if_missing_plays_nothing_again() -> void:
	var args: Dictionary[String, String] = {"bots": "true", "suite": "quick",
		"seeds": "1001..1001", "out": BOARD}
	assert_eq(Tool.run(args, _config), Tool.EXIT_OK)
	var first: Dictionary[String, String] = _runs()
	assert_eq(first.size(), Policy.ids().size(), "one per bot")
	for file_name: String in first:
		var entry: BenchEntry = BenchEntry.from_json(first[file_name])
		assert_true(entry.is_bot(), file_name)
		assert_eq(entry.calls, 0)
	var board: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(BOARD.path_join(Writer.LEADERBOARD_JSON)))
	assert_eq((board["rows"] as Array).size(), Policy.ids().size())
	args["if-missing"] = "true"
	args["no-rebuild"] = "true"
	DirAccess.remove_absolute(BOARD.path_join(Writer.LEADERBOARD_JSON))
	assert_eq(Tool.run(args, _config), Tool.EXIT_OK)
	assert_eq(_runs(), first, "nothing was played again: every file is as it was")
	assert_false(FileAccess.file_exists(BOARD.path_join(Writer.LEADERBOARD_JSON)),
		"--no-rebuild leaves the board to someone else")


func test_a_missing_key_stops_before_anything_is_played() -> void:
	var args: Dictionary[String, String] = {"model": "vendor/model", "suite": "quick",
		"out": BOARD, "key-env": "DOOMSDAY_TEST_KEY_THAT_IS_NEVER_SET"}
	assert_eq(Tool.run(args, _config), Tool.EXIT_BAD_INPUT)
	assert_false(DirAccess.dir_exists_absolute(BOARD))


func test_a_dry_run_prints_the_prompt_and_writes_nothing() -> void:
	var args: Dictionary[String, String] = _mock_args()
	args["dry-run"] = "true"
	assert_eq(Tool.run(args, _config), Tool.EXIT_OK)
	assert_false(DirAccess.dir_exists_absolute(BOARD))
	var measured: Dictionary = Tool.measure(_db, _config, RunSetup.from_dict(_config.setup), 1001,
		"en")
	assert_string_contains(str(measured["brief"]), BenchPrompt.EXAMPLE)
	assert_string_contains(str(measured["digest"]), "Day 0")


func test_bad_arguments_exit_one() -> void:
	for bad: Dictionary in [{"backend": "mock:telepathy"}, {"suite": "huge"},
			{"seeds": "5..9"}, {"temperature": "warm"}, {"reasoning": "extreme"},
			{"locale": "fr"}, {"model": ""}]:
		var args: Dictionary[String, String] = _mock_args()
		for key: Variant in bad:
			args[str(key)] = str(bad[key])
		assert_eq(Tool.run(args, _config), Tool.EXIT_BAD_INPUT, str(bad))
	assert_false(DirAccess.dir_exists_absolute(BOARD))


func test_the_seeds_argument_restricts_the_suite() -> void:
	var suite: Array[int] = [1001, 1002, 1003]
	assert_eq(Tool.seeds_in("", suite), suite)
	assert_eq(Tool.seeds_in("1002..1003", suite), [1002, 1003] as Array[int])
	assert_eq(Tool.seeds_in("1003", suite), [1003] as Array[int])
	assert_eq(Tool.seeds_in("a..b", suite), [] as Array[int])


func test_a_fatal_reason_maps_to_its_exit_code() -> void:
	assert_eq(Tool.exit_for("auth"), Tool.EXIT_REFUSED)
	assert_eq(Tool.exit_for("bad_request: 404 model not found"), Tool.EXIT_REFUSED)
	assert_eq(Tool.exit_for("unavailable"), Tool.EXIT_UNAVAILABLE)
	assert_eq(Tool.exit_for("cost_cap"), Tool.EXIT_COST_CAP)


func _choice_args() -> Dictionary[String, String]:
	return {"model": "mock", "backend": "mock-choice:first", "suite": "quick", "out": BOARD,
		"cache": CACHE}


func _typesafe_args() -> Dictionary[String, String]:
	return {"model": "typesafe/jev-latest", "suite": "quick", "seeds": "1001", "out": BOARD,
		"cache": CACHE, "key-env": UNSET_KEY_ENV}


func test_a_mock_decision_model_run_replays_repeats_ranks_and_verifies() -> void:
	assert_eq(Tool.run(_choice_args(), _config), Tool.EXIT_OK)
	var first: Dictionary[String, String] = _runs()
	assert_eq(first.size(), 3, "one entry per seed")
	for file_name: String in first:
		var entry: BenchEntry = BenchEntry.from_json(first[file_name])
		assert_not_null(entry, BenchEntry.last_error)
		assert_eq(entry.backend, "mock-choice:first")
		assert_eq(entry.model_version, MockChoiceBackend.MODEL_VERSION)
		assert_eq(entry.params_id, BenchEntry.params_id_of(BenchChoice.params_of(_config)))
		assert_gt(entry.decisions.size(), 10)
		var replayed: Simulation = Simulation.replay(_db, entry.seed_value, entry.commands,
			entry.end_day, entry.setup)
		assert_eq(replayed.state_hash(), entry.state_hash, file_name + " replays to its hash")
		var record: Variant = Verifier.check(first[file_name].to_utf8_buffer(), file_name, _config,
			_db, {Verifier.CONTEXT_COMMIT: COMMIT, Verifier.CONTEXT_VERSION: "0.6.0",
			Verifier.CONTEXT_CHECKED: "2026-09-26"})
		assert_true(bool(record.verified), "%s: %s" % [file_name, record.detail])
	assert_eq(Tool.run(_choice_args(), _config), Tool.EXIT_OK)
	var second: Dictionary[String, String] = _runs()
	for file_name: String in first:
		assert_eq(_unrecorded(second[file_name]), _unrecorded(first[file_name]), file_name)
	var chat: Dictionary[String, String] = _mock_args()
	chat["seeds"] = "1001"
	assert_eq(Tool.run(chat, _config), Tool.EXIT_OK)
	assert_eq(Tool.run({"bots": "true", "suite": "quick", "seeds": "1001", "out": BOARD}, _config),
		Tool.EXIT_OK)
	var board: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(BOARD.path_join(Writer.LEADERBOARD_JSON)))
	var backends: Array[String] = []
	for row: Variant in board["rows"]:
		backends.append(str((row as Dictionary)["backend"]))
		if str((row as Dictionary)["backend"]) == "mock-choice:first":
			assert_eq((row as Dictionary)["model_versions"], [MockChoiceBackend.MODEL_VERSION])
			assert_eq(int((row as Dictionary)["runs"]), 3)
	assert_true(backends.has("mock-choice:first"))
	assert_true(backends.has("mock:cheapest"))
	assert_true(backends.has(BenchEntry.BACKEND_BOT))
	assert_string_contains(FileAccess.get_file_as_string(BOARD.path_join(Writer.LEADERBOARD_MD)),
		"mock (mock-choice-1)")
	assert_false(DirAccess.dir_exists_absolute(CACHE), "a mock never touches the cache")


func test_a_typesafe_model_id_picks_the_typesafe_backend() -> void:
	assert_eq(Tool.backend_for({"model": "typesafe/jev-latest"}, _config), "typesafe")
	assert_eq(Tool.backend_for({"model": "vendor/model"}, _config), "openrouter")
	assert_eq(Tool.backend_for({"model": "typesafe/jev-latest", "backend": "mock-choice:idle"},
		_config), "mock-choice:idle")


func test_the_typesafe_backend_refuses_another_model_and_the_chat_flags() -> void:
	var other: Dictionary[String, String] = _typesafe_args()
	other["model"] = "vendor/model"
	other["backend"] = "typesafe"
	assert_eq(Tool.run(other, _config), Tool.EXIT_BAD_INPUT)
	for flag: String in Tool.CHAT_FLAGS:
		var args: Dictionary[String, String] = _typesafe_args()
		args[flag] = "1"
		assert_eq(Tool.run(args, _config), Tool.EXIT_BAD_INPUT, flag)
	var mock: Dictionary[String, String] = _choice_args()
	mock["temperature"] = "0.5"
	assert_eq(Tool.run(mock, _config), Tool.EXIT_BAD_INPUT, "a mock decision model too")
	var requests: Dictionary[String, String] = _typesafe_args()
	requests["max-requests"] = "0"
	assert_eq(Tool.run(requests, _config), Tool.EXIT_BAD_INPUT)
	assert_false(DirAccess.dir_exists_absolute(BOARD))


func test_a_missing_typesafe_key_stops_before_anything_is_played() -> void:
	assert_eq(Tool.run(_typesafe_args(), _config), Tool.EXIT_BAD_INPUT)
	assert_false(DirAccess.dir_exists_absolute(BOARD))
	assert_false(DirAccess.dir_exists_absolute(CACHE))


func test_a_typesafe_dry_run_needs_no_key_and_prints_the_request() -> void:
	var args: Dictionary[String, String] = _typesafe_args()
	args["dry-run"] = "true"
	assert_eq(Tool.run(args, _config), Tool.EXIT_OK)
	assert_false(DirAccess.dir_exists_absolute(BOARD))
	var request: Dictionary = Tool.measure_choice(_db, _config, RunSetup.from_dict(_config.setup),
		1001, "en", "jev-latest")
	var body: Dictionary = request["body"]
	assert_eq(str(body["model"]), "jev-latest")
	assert_eq((body["questions"] as Dictionary).keys(), ["stance", "origin"])
	assert_eq((body["state"] as Dictionary).keys(), ["rules", "situation"])
	var lines: PackedStringArray = Tool.limit_lines(request, _config)
	assert_eq(lines.size(), 1, "today's request is within the service's limits")
	assert_string_contains(lines[0], "(limit 32000)")
	assert_gt(int(request["state_tokens"]), 1000)


func test_a_request_cap_maps_to_the_cost_cap_exit() -> void:
	assert_eq(Tool.exit_for("request_cap"), Tool.EXIT_COST_CAP)


func test_an_effort_run_is_a_row_of_its_own_and_verifies() -> void:
	var args: Dictionary[String, String] = _mock_args()
	args["seeds"] = "1001"
	assert_eq(Tool.run(args, _config), Tool.EXIT_OK)
	args["effort"] = "ultra"
	assert_eq(Tool.run(args, _config), Tool.EXIT_OK)
	var runs: Dictionary[String, String] = _runs()
	assert_eq(runs.size(), 2, "normal and ultra are two files")
	var efforts: Array[String] = []
	for file_name: String in runs:
		var entry: BenchEntry = BenchEntry.from_json(runs[file_name])
		assert_not_null(entry, BenchEntry.last_error)
		efforts.append(BenchEffort.of_entry(entry))
		var record: VerifyRecord = Verifier.check(runs[file_name].to_utf8_buffer(), file_name,
			_config, _db, {Verifier.CONTEXT_COMMIT: COMMIT, Verifier.CONTEXT_VERSION: "0.6.0",
				Verifier.CONTEXT_CHECKED: "2026-09-27"})
		assert_true(record.verified, record.detail)
		if entry.effort == "ultra":
			assert_eq(entry.params["reasoning"], "max", "the model's efforts are unknown to a mock")
			assert_true(runs[file_name].contains("\"effort\": \"ultra\""))
		else:
			assert_false(runs[file_name].contains("\"effort\""), "normal writes no effort")
	efforts.sort()
	assert_eq(efforts, ["normal", "ultra"] as Array[String])
	var board: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		BOARD.path_join(Writer.LEADERBOARD_JSON)))
	var shown: Array[String] = []
	for row: Dictionary in board["rows"]:
		shown.append(str(row["effort"]))
	shown.sort()
	assert_eq(shown, ["normal", "ultra"] as Array[String], "each row says its effort")
	var page: String = FileAccess.get_file_as_string(BOARD.path_join(Writer.LEADERBOARD_MD))
	assert_string_contains(page, "| Effort |")
	assert_string_contains(page, "| Ultra |")


func test_bad_effort_arguments_exit_one() -> void:
	for bad: Dictionary in [{"effort": "extreme"}, {"effort": "high", "reasoning": "low"}]:
		var args: Dictionary[String, String] = _mock_args()
		for key: Variant in bad:
			args[str(key)] = str(bad[key])
		assert_eq(Tool.run(args, _config), Tool.EXIT_BAD_INPUT, str(bad))
	var choice: Dictionary[String, String] = _choice_args()
	choice["effort"] = "high"
	assert_eq(Tool.run(choice, _config), Tool.EXIT_BAD_INPUT, "a decision model has no effort")
	assert_false(DirAccess.dir_exists_absolute(BOARD))


func test_shards_given_the_same_pinned_reasoning_make_one_row() -> void:
	# run_models.ps1 resolves what ultra sends once and gives every shard the same.
	for seed_text: String in ["1001", "1002"]:
		var args: Dictionary[String, String] = _mock_args()
		args["seeds"] = seed_text
		args["effort"] = "ultra"
		args["effort-reasoning"] = "high"
		args["no-rebuild"] = "true"
		assert_eq(Tool.run(args, _config), Tool.EXIT_OK)
	var ids: Array[String] = []
	for text: String in _runs().values():
		var entry: BenchEntry = BenchEntry.from_json(text)
		assert_eq(entry.params["reasoning"], "high", "the pinned effort, not a guess")
		if not ids.has(entry.params_id):
			ids.append(entry.params_id)
	assert_eq(ids.size(), 1, "both shards share one params_id")


func test_a_live_level_whose_list_cannot_be_read_stops_before_anything_is_played() -> void:
	# A base URL other than OpenRouter's has no public list to read, and nothing is
	# requested before the refusal; PATH stands in for a key that is set.
	var args: Dictionary[String, String] = {"model": "vendor/model", "suite": "quick",
		"out": BOARD, "cache": CACHE, "key-env": "PATH", "base-url": "http://127.0.0.1:9/v1",
		"effort": "ultra", "yes": "true"}
	assert_eq(Tool.run(args, _config), Tool.EXIT_BAD_INPUT)
	assert_false(DirAccess.dir_exists_absolute(BOARD))


func test_no_rebuild_leaves_the_board_to_the_last_shard() -> void:
	var args: Dictionary[String, String] = _mock_args()
	args["seeds"] = "1001"
	args["no-rebuild"] = "true"
	assert_eq(Tool.run(args, _config), Tool.EXIT_OK)
	assert_eq(_runs().size(), 1)
	assert_false(FileAccess.file_exists(BOARD.path_join(Writer.LEADERBOARD_JSON)))
