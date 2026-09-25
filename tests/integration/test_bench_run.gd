extends GutTest
## S6.12 — the benchmark tool end to end (docs/specs/benchmark.md §11, §14.1) on
## the real content with the `mock:cheapest` backend: the quick suite at 300 days,
## into a board of its own under `user://`. Nothing is asked of any service.

const Tool := preload("res://tools/bench/bench_run.gd")
const Writer := preload("res://tools/bench/leaderboard_writer.gd")
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
