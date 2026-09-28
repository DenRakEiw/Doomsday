extends GutTest
## S6.12f — `BenchJobs` (docs/specs/benchmark.md §19.5) with fake workers: the
## job files and the cap split for a paid and a free model, one benchmark at a
## time, the key handed over and never written, the progress read into the
## state, the ends (done, a worker's stop, a worker gone silent, *Stop*, no key)
## and old job folders removed. No process is started here; `test_bench_worker`
## starts real ones.

const BenchJobsScript: GDScript = preload("res://game/autoload/bench_jobs.gd")
const OUT: String = "user://test_bench/jobs"
const KEY: String = "sk-or-v1-fake"
const PAID: String = "vendor/paid"
const FREE: String = "vendor/model:free"
const FIRST_PID: int = 5000

var _jobs: Node = null
var _stored_key: String = KEY
var _launched: Array[Dictionary] = []
var _alive: Array[int] = []
var _killed: Array[int] = []
var _next_pid: int = FIRST_PID


func before_each() -> void:
	_clear(OUT)
	_stored_key = KEY
	_launched.clear()
	_alive.clear()
	_killed.clear()
	_next_pid = FIRST_PID
	_jobs = BenchJobsScript.new()
	add_child_autofree(_jobs)
	_jobs.set("out_dir", OUT)
	_jobs.set("launcher", _launch)
	_jobs.set("running", func(pid: int) -> bool: return _alive.has(pid))
	_jobs.set("killer", func(pid: int) -> void:
		_killed.append(pid)
		_alive.erase(pid))
	var store: BenchKeyStore = BenchKeyStore.new()
	store.backend_override = func(op: String, _key: String) -> Dictionary:
		if op == BenchKeyStore.OP_LOAD and not _stored_key.is_empty():
			return {BenchKeyStore.FIELD_STATUS: BenchKeyStore.STATUS_OK,
				BenchKeyStore.FIELD_KEY: _stored_key}
		return {BenchKeyStore.FIELD_STATUS: BenchKeyStore.STATUS_NONE}
	_jobs.set("key_store", store)
	# Nothing here runs on its own: every test polls when it means to.
	_jobs.set_process(false)


func after_all() -> void:
	_clear(OUT)


func _clear(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for sub: String in DirAccess.get_directories_at(dir):
		_clear(dir.path_join(sub))
	for file_name: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file_name))
	DirAccess.remove_absolute(dir)


func _launch(dir: String, key: String) -> int:
	var pid: int = _next_pid
	_next_pid += 1
	_launched.append({"dir": dir, "key": key, "pid": pid})
	_alive.append(pid)
	return pid


func _start(model: String, cap: float = 3.0) -> String:
	var reason: String = str(_jobs.call("start", model, BenchEffort.NORMAL, cap))
	_jobs.call("wait_started")
	return reason


func _state() -> BenchJobState:
	return _jobs.call("state")


func _write(worker: int, lines: Array[Dictionary]) -> void:
	var path: String = str(_jobs.call("worker_dir", worker)).path_join(
		BenchJobState.PROGRESS_FILE)
	var file: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE) \
		if FileAccess.file_exists(path) else FileAccess.open(path, FileAccess.WRITE)
	file.seek_end()
	for line: Dictionary in lines:
		file.store_line(JSON.stringify(line))
	file.close()


func _run_line(seed_value: int, outcome: String, score: float) -> Dictionary:
	return {BenchJobState.EVENT: BenchJobState.EVENT_RUN, BenchJobState.FIELD_SEED: seed_value,
		BenchJobState.FIELD_OUTCOME: outcome, BenchJobState.FIELD_SCORE: score,
		BenchJobState.FIELD_CALLS: 40, BenchJobState.FIELD_COST: 0.2, BenchJobState.FIELD_DAYS: 300}


func _done() -> Dictionary:
	return {BenchJobState.EVENT: BenchJobState.EVENT_DONE}


func test_a_paid_model_plays_one_seed_per_worker_with_a_third_of_the_cap_each() -> void:
	assert_eq(_start(PAID, 3.0), "")
	assert_eq(int(_jobs.call("worker_count")), 3)
	assert_eq(_launched.size(), 3)
	var seeds: Array[int] = []
	for i: int in 3:
		var job: BenchJob = BenchJob.read(str(_jobs.call("worker_dir", i)))
		assert_not_null(job)
		assert_eq(job.seeds.size(), 1)
		seeds.append_array(job.seeds)
		assert_almost_eq(job.max_cost_usd, 1.0, 0.0001)
		assert_eq(job.model, PAID)
		assert_eq(job.backend, BenchJob.BACKEND_OPENROUTER)
		assert_eq(job.suite, BenchConfig.SUITE_QUICK)
		assert_eq(str(_launched[i]["key"]), KEY, "the key goes to the worker")
		var text: String = FileAccess.get_file_as_string(
			str(_jobs.call("worker_dir", i)).path_join(BenchJob.FILE))
		assert_false(text.contains(KEY), "and never into the job file")
	seeds.sort()
	assert_eq(seeds, BenchConfig.load_file().suite_seeds(BenchConfig.SUITE_QUICK))


func test_a_free_model_plays_every_seed_in_one_worker_with_the_whole_cap() -> void:
	assert_eq(_start(FREE, 2.0), "")
	assert_eq(int(_jobs.call("worker_count")), 1)
	var job: BenchJob = BenchJob.read(str(_jobs.call("worker_dir", 0)))
	assert_eq(job.seeds.size(), 3)
	assert_almost_eq(job.max_cost_usd, 2.0, 0.0001)
	assert_true(_state().free)


func test_a_decision_model_plays_through_openrouter() -> void:
	assert_eq(_start("typesafe/jev-latest"), "")
	var job: BenchJob = BenchJob.read(str(_jobs.call("worker_dir", 0)))
	assert_eq(job.backend, BenchJob.BACKEND_TYPESAFE)


func test_only_one_benchmark_runs_at_a_time() -> void:
	assert_eq(_start(PAID), "")
	assert_eq(_start(FREE), BenchJobsScript.REASON_RUNNING)
	assert_eq(_state().model, PAID)


func test_progress_reaches_the_state_and_all_done_is_done() -> void:
	assert_eq(_start(PAID), "")
	var state: BenchJobState = _state()
	var first: int = BenchJob.read(str(_jobs.call("worker_dir", 0))).seeds[0]
	_write(0, [{BenchJobState.EVENT: BenchJobState.EVENT_DECISION,
		BenchJobState.FIELD_SEED: first, BenchJobState.FIELD_DAY: 11,
		BenchJobState.FIELD_CALLS: 2, BenchJobState.FIELD_COST: 0.01}])
	watch_signals(_jobs)
	_jobs.call("poll")
	assert_signal_emitted(_jobs, "changed")
	var row: BenchJobSeed = state.seed_row(first)
	assert_true(row.started)
	assert_eq(row.day, 11)
	assert_eq(row.calls, 2)
	assert_almost_eq(state.cost_usd(), 0.01, 0.0001)
	assert_true(state.is_running())
	for i: int in 3:
		var seed_value: int = BenchJob.read(str(_jobs.call("worker_dir", i))).seeds[0]
		_write(i, [_run_line(seed_value, "win_takeover" if i == 0 else "lose_contained", 50.0),
			_done()])
	_jobs.call("poll")
	assert_eq(state.status, BenchJobState.DONE)
	assert_eq(state.finished_runs(), 3)
	assert_eq(state.wins(), 1)
	assert_almost_eq(state.cost_usd(), 0.6, 0.0001)
	assert_eq(_killed, [] as Array[int], "nothing to kill after a clean end")


func test_a_worker_that_stops_stops_the_benchmark_and_the_others() -> void:
	assert_eq(_start(PAID), "")
	_write(1, [{BenchJobState.EVENT: BenchJobState.EVENT_STOPPED,
		BenchJobState.FIELD_REASON: BenchRunner.STOP_CREDITS}])
	_alive.erase(FIRST_PID + 1)
	_jobs.call("poll")
	assert_eq(_state().status, BenchJobState.STOPPED)
	assert_eq(_state().reason, BenchRunner.STOP_CREDITS)
	_killed.sort()
	assert_eq(_killed, [FIRST_PID, FIRST_PID + 2] as Array[int])


func test_a_worker_gone_without_a_word_is_an_error() -> void:
	assert_eq(_start(PAID), "")
	_alive.erase(FIRST_PID)
	_jobs.call("poll")
	assert_eq(_state().status, BenchJobState.STOPPED)
	assert_eq(_state().reason, BenchRunner.STOP_ERROR)


func test_stop_kills_every_worker() -> void:
	assert_eq(_start(PAID), "")
	_jobs.call("stop")
	assert_eq(_state().status, BenchJobState.STOPPED)
	assert_eq(_state().reason, BenchJobState.REASON_PLAYER)
	assert_eq(_killed.size(), 3)
	assert_eq(_start(FREE), "", "a stopped benchmark makes room for the next")


func test_without_a_key_nothing_starts() -> void:
	_stored_key = ""
	assert_eq(_start(PAID), "")
	assert_eq(_launched.size(), 0)
	assert_eq(_state().status, BenchJobState.STOPPED)
	assert_eq(_state().reason, BenchRunner.STOP_AUTH)


func test_a_session_key_is_used_before_the_store() -> void:
	_stored_key = ""
	_jobs.set("session_key", "sk-or-session")
	assert_eq(_start(PAID), "")
	assert_eq(str(_launched[0]["key"]), "sk-or-session")


func test_old_job_folders_are_removed_at_the_next_start() -> void:
	for n: int in range(1, 7):
		DirAccess.make_dir_recursive_absolute(OUT.path_join("jobs").path_join(str(n)))
	assert_eq(_start(PAID), "")
	var kept: Array[String] = []
	kept.assign(DirAccess.get_directories_at(OUT.path_join("jobs")))
	kept.sort()
	assert_eq(kept, ["3", "4", "5", "6", "7"] as Array[String])
	assert_true(str(_jobs.call("worker_dir", 0)).begins_with(OUT.path_join("jobs/7")))


func test_a_mock_benchmark_needs_no_key_and_writes_elsewhere() -> void:
	_stored_key = ""
	var library_dir: String = BenchLibrary.user_dir
	_jobs.call("use_mock", true)
	# `use_mock` points the folders at the mock's; this test keeps its own.
	_jobs.set("out_dir", OUT)
	assert_eq(_start(PAID), "")
	assert_eq(str(_launched[0]["key"]), BenchJob.MOCK_KEY_LINE, "a stand-in, never a key")
	assert_eq(BenchJob.read(str(_jobs.call("worker_dir", 0))).backend,
		BenchJobsScript.MOCK_BACKEND)
	assert_true(_state().mock)
	assert_true(BenchLibrary.user_dir.contains(BenchJobsScript.MOCK_FOLDER),
		"the list reads the mock's runs")
	_jobs.call("use_mock", false)
	BenchLibrary.user_dir = library_dir


func test_the_state_ignores_lines_for_seeds_it_does_not_play() -> void:
	var state: BenchJobState = BenchJobState.new(PAID, BenchEffort.NORMAL, 2.0, false,
		[1001] as Array[int])
	assert_false(state.apply_line({BenchJobState.EVENT: BenchJobState.EVENT_DECISION,
		BenchJobState.FIELD_SEED: 9999}))
	assert_false(state.apply_line({BenchJobState.EVENT: "nonsense"}))
	assert_true(state.apply_line(_run_line(1001, "win_takeover", 80.0)))
	assert_false(state.apply_line({BenchJobState.EVENT: BenchJobState.EVENT_DECISION,
		BenchJobState.FIELD_SEED: 1001, BenchJobState.FIELD_DAY: 5}),
		"a finished seed does not play on")
	assert_eq(state.wins(), 1)
