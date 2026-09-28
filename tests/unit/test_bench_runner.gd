extends GutTest
## S6.12f — one seed through `BenchRunner` (docs/specs/benchmark.md §19.3): the
## same entries the tool writes, a fatal stop that writes nothing, the progress
## hook, and the names the worker's progress file uses. The canary and
## `test_bench_run` prove the tool itself unchanged.

const Tool := preload("res://tools/bench/bench_run.gd")
const TOOL_BOARD: String = "user://test_bench/runner_tool"
const RUNNER_BOARD: String = "user://test_bench/runner"
const MAX_DAYS: int = 300
const MODEL: String = "mock"


## A backend that fails for good at its first request.
class FatalBackend extends ModelBackend:
	var reason: String = ""

	func _init(p_reason: String) -> void:
		reason = p_reason

	func backend_id() -> String:
		return "fatal"

	@warning_ignore("unused_parameter")
	func answer(messages: Array[Dictionary], digest: BenchDigest,
			params: Dictionary) -> ModelReply:
		return ModelReply.fatal(reason)


var _config: BenchConfig = null
var _db: ContentDB = null
var _setup: RunSetup = null


func before_all() -> void:
	_db = ContentLoader.load_root("res://data").db


func before_each() -> void:
	_config = BenchConfig.load_file()
	_config.max_days = MAX_DAYS
	_setup = RunSetup.from_dict(_config.setup)
	_clear(TOOL_BOARD)
	_clear(RUNNER_BOARD)


func after_all() -> void:
	_clear(TOOL_BOARD)
	_clear(RUNNER_BOARD)


func _clear(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for sub: String in DirAccess.get_directories_at(dir):
		_clear(dir.path_join(sub))
	for file_name: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file_name))
	DirAccess.remove_absolute(dir)


func _entry_at(board: String, file_name: String) -> BenchEntry:
	return BenchEntry.from_json(FileAccess.get_file_as_string(
		board.path_join(BenchRunner.RUNS_DIR).path_join(file_name)))


func test_the_quick_suite_gives_the_entries_the_tool_gives() -> void:
	var args: Dictionary[String, String] = {"model": MODEL, "backend": "mock:cheapest",
		"suite": BenchConfig.SUITE_QUICK, "out": TOOL_BOARD, "no-rebuild": "true"}
	assert_eq(Tool.run(args, _config), Tool.EXIT_OK)
	var params: Dictionary = BenchRunner.default_params(_config)
	for seed_value: int in _config.suite_seeds(BenchConfig.SUITE_QUICK):
		var result: Dictionary = BenchRunner.run_seed(_db, _config, _setup, seed_value,
			MockBackend.new(MockBackend.MODE_CHEAPEST), params, _config.locale, MODEL,
			BenchConfig.SUITE_QUICK, RUNNER_BOARD)
		assert_eq(int(result[BenchRunner.RESULT_EXIT]), BenchRunner.EXIT_OK)
		var entry: BenchEntry = result[BenchRunner.RESULT_ENTRY]
		assert_not_null(entry)
		if entry == null:
			continue
		var tool_entry: BenchEntry = _entry_at(TOOL_BOARD, entry.file_name())
		assert_not_null(tool_entry, "the tool wrote %s" % entry.file_name())
		if tool_entry == null:
			continue
		assert_eq(entry.state_hash, tool_entry.state_hash, "seed %d plays the same" % seed_value)
		assert_eq(entry.commands.size(), tool_entry.commands.size())
		assert_eq(entry.outcome, tool_entry.outcome)
		assert_eq(entry.params_id, tool_entry.params_id)
		assert_not_null(_entry_at(RUNNER_BOARD, entry.file_name()), "and wrote it")


func test_the_progress_hook_hears_every_decision() -> void:
	var heard: Array[int] = []
	var on_decision: Callable = func(policy: ModelPolicy, sim: Simulation) -> void:
		heard.append(sim.world.day)
		assert_gt(policy.calls, 0)
	var result: Dictionary = BenchRunner.run_seed(_db, _config, _setup, 1001,
		MockBackend.new(MockBackend.MODE_CHEAPEST), BenchRunner.default_params(_config),
		_config.locale, MODEL, BenchConfig.SUITE_QUICK, RUNNER_BOARD, {}, on_decision)
	var entry: BenchEntry = result[BenchRunner.RESULT_ENTRY]
	assert_eq(heard.size(), entry.decisions.size(), "one call per decision")


func test_a_fatal_backend_stops_the_seed_and_writes_nothing() -> void:
	var result: Dictionary = BenchRunner.run_seed(_db, _config, _setup, 1001,
		FatalBackend.new("credits (402)"), BenchRunner.default_params(_config), _config.locale,
		MODEL, BenchConfig.SUITE_QUICK, RUNNER_BOARD)
	assert_null(result[BenchRunner.RESULT_ENTRY])
	assert_eq(str(result[BenchRunner.RESULT_FATAL]), "credits (402)")
	assert_eq(int(result[BenchRunner.RESULT_EXIT]), BenchRunner.EXIT_REFUSED)
	assert_false(DirAccess.dir_exists_absolute(RUNNER_BOARD.path_join(BenchRunner.RUNS_DIR)))


func test_a_fatal_reason_names_its_stop() -> void:
	assert_eq(BenchRunner.stop_reason("auth (401)"), BenchRunner.STOP_AUTH)
	assert_eq(BenchRunner.stop_reason("credits"), BenchRunner.STOP_CREDITS)
	assert_eq(BenchRunner.stop_reason("forbidden (403)"), BenchRunner.STOP_FORBIDDEN)
	assert_eq(BenchRunner.stop_reason("bad_request (400)"), BenchRunner.STOP_BAD_REQUEST)
	assert_eq(BenchRunner.stop_reason("unavailable"), BenchRunner.STOP_UNAVAILABLE)
	assert_eq(BenchRunner.stop_reason("cost_cap"), BenchRunner.STOP_COST_CAP)
	assert_eq(BenchRunner.stop_reason("request_cap"), BenchRunner.STOP_COST_CAP)
	assert_eq(BenchRunner.stop_reason("bad_base_url"), BenchRunner.STOP_ERROR)
	for reason: String in BenchRunner.STOP_REASONS:
		assert_false(reason.is_empty())


func test_the_worker_switch_names_its_job_folder() -> void:
	assert_eq(BenchRunner.worker_job_dir(["--bench-worker=user://benchmark/jobs/3/0"]),
		"user://benchmark/jobs/3/0")
	assert_eq(BenchRunner.worker_job_dir(["--smoke"]), "")
	assert_eq(BenchRunner.worker_job_dir([]), "")


func test_the_run_line_is_the_tools() -> void:
	var result: Dictionary = BenchRunner.run_seed(_db, _config, _setup, 1001,
		MockBackend.new(MockBackend.MODE_CHEAPEST), BenchRunner.default_params(_config),
		_config.locale, MODEL, BenchConfig.SUITE_QUICK, RUNNER_BOARD)
	var entry: BenchEntry = result[BenchRunner.RESULT_ENTRY]
	var line: Dictionary = BenchRunner.run_line(entry)
	assert_eq(line.keys(), ["model", "seed", "outcome", "days", "score", "calls", "cached_calls",
		"invalid_answers", "rejected_actions", "cost_usd", "file"])
	assert_eq(str(line["file"]), entry.file_name())
