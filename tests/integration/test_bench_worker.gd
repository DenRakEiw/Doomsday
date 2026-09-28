extends GutTest
## S6.12f — the game as a headless benchmark worker (docs/specs/benchmark.md
## §19.4), as a real child process: the job file, a key line on stdin, the
## progress events in order, the entry written, exit 0 — and a job it cannot
## play, or a key line that never came, stops it with a reason and writes
## nothing. `mock:cheapest` only: nothing is asked of any service, and the key
## line is the mock's stand-in (`BenchJob.MOCK_KEY_LINE`).

const ROOT: String = "user://test_bench/worker"
const MODEL: String = "vendor/probe"
const WAIT_MS: int = 120000
const POLL_MS: int = 50


func before_each() -> void:
	_clear(ROOT)


func after_all() -> void:
	_clear(ROOT)


func _clear(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for sub: String in DirAccess.get_directories_at(dir):
		_clear(dir.path_join(sub))
	for file_name: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file_name))
	DirAccess.remove_absolute(dir)


func _job(backend: String) -> BenchJob:
	var job: BenchJob = BenchJob.new()
	job.model = MODEL
	job.backend = backend
	job.suite = BenchConfig.SUITE_QUICK
	job.seeds = [1001]
	job.max_cost_usd = 1.0
	job.locale = "en"
	job.out = ROOT.path_join("out")
	job.cache = ROOT.path_join("out/cache")
	return job


## Starts the worker on `dir`, hands it the key line and waits for its end: the
## exit code, or −1 when it could not start or did not end in time.
func _run_worker(dir: String, key_line: String = BenchJob.MOCK_KEY_LINE) -> int:
	var arguments: PackedStringArray = ["--headless", "--path",
		ProjectSettings.globalize_path("res://"), "--", BenchRunner.WORKER_ARG + dir]
	var child: Dictionary = OS.execute_with_pipe(OS.get_executable_path(), arguments, false)
	if child.is_empty():
		return -1
	var pipe: FileAccess = child["stdio"]
	var errors: FileAccess = child["stderr"]
	var pid: int = int(child["pid"])
	pipe.store_string(key_line + "\n")
	pipe.flush()
	var waited: int = 0
	while OS.is_process_running(pid) and waited < WAIT_MS:
		# Drained, as `BenchJobs` does: a full pipe would stall the worker.
		for stream: FileAccess in [pipe, errors]:
			while not stream.get_buffer(4096).is_empty():
				pass
		OS.delay_msec(POLL_MS)
		waited += POLL_MS
	pipe.close()
	errors.close()
	if OS.is_process_running(pid):
		OS.kill(pid)
		return -1
	return OS.get_process_exit_code(pid)


func _events(dir: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var text: String = FileAccess.get_file_as_string(dir.path_join(BenchJobState.PROGRESS_FILE))
	for line: String in text.split("\n", false):
		var parsed: Variant = JSON.parse_string(line)
		if typeof(parsed) == TYPE_DICTIONARY:
			out.append(parsed)
	return out


func _can_spawn() -> bool:
	return OS.has_feature("pc") and not OS.has_feature("web")


func test_a_mock_job_plays_its_seed_and_reports_in_order() -> void:
	if not _can_spawn():
		pending("no child processes on this platform")
		return
	var dir: String = ROOT.path_join("job_ok")
	assert_true(_job("mock:cheapest").write(dir))
	assert_eq(_run_worker(dir), BenchRunner.EXIT_OK)
	var events: Array[Dictionary] = _events(dir)
	assert_gt(events.size(), 2)
	if events.size() < 3:
		return
	assert_eq(str(events[0][BenchJobState.EVENT]), BenchJobState.EVENT_DECISION)
	assert_eq(str(events[events.size() - 2][BenchJobState.EVENT]), BenchJobState.EVENT_RUN)
	assert_eq(str(events[events.size() - 1][BenchJobState.EVENT]), BenchJobState.EVENT_DONE)
	var last_day: int = -1
	for event: Dictionary in events.slice(0, events.size() - 2):
		assert_eq(str(event[BenchJobState.EVENT]), BenchJobState.EVENT_DECISION)
		assert_eq(int(event[BenchJobState.FIELD_SEED]), 1001)
		assert_gt(int(event[BenchJobState.FIELD_DAY]), last_day, "days go forward")
		last_day = int(event[BenchJobState.FIELD_DAY])
	var run: Dictionary = events[events.size() - 2]
	var entry: BenchEntry = BenchEntry.from_json(FileAccess.get_file_as_string(
		ROOT.path_join("out").path_join(BenchRunner.RUNS_DIR).path_join(str(run["file"]))))
	assert_not_null(entry, "the entry is where the run line says")
	if entry != null:
		assert_eq(entry.model, MODEL)
		assert_eq(entry.backend, "mock:cheapest")
		assert_eq(entry.seed_value, 1001)
	var progress: String = FileAccess.get_file_as_string(
		dir.path_join(BenchJobState.PROGRESS_FILE))
	assert_false(progress.contains(BenchJob.MOCK_KEY_LINE), "the key line is never written")


func test_a_job_it_cannot_play_stops_with_a_reason_and_writes_nothing() -> void:
	if not _can_spawn():
		pending("no child processes on this platform")
		return
	var dir: String = ROOT.path_join("job_broken")
	# No mock of that name, and not a service: the worker refuses the job.
	assert_true(_job("mock:broken").write(dir))
	assert_eq(_run_worker(dir), BenchRunner.EXIT_BAD_INPUT)
	var events: Array[Dictionary] = _events(dir)
	assert_eq(events.size(), 1)
	if events.size() == 1:
		assert_eq(str(events[0][BenchJobState.EVENT]), BenchJobState.EVENT_STOPPED)
		assert_eq(str(events[0][BenchJobState.FIELD_REASON]), BenchRunner.STOP_ERROR)
	assert_false(DirAccess.dir_exists_absolute(ROOT.path_join("out").path_join(
		BenchRunner.RUNS_DIR)))


func test_a_key_line_that_is_not_the_one_sent_stops_it() -> void:
	if not _can_spawn():
		pending("no child processes on this platform")
		return
	var dir: String = ROOT.path_join("job_no_key")
	assert_true(_job("mock:cheapest").write(dir))
	assert_eq(_run_worker(dir, "something else"), BenchRunner.EXIT_BAD_INPUT)
	var events: Array[Dictionary] = _events(dir)
	assert_eq(events.size(), 1)
	if events.size() == 1:
		assert_eq(str(events[0][BenchJobState.FIELD_REASON]), BenchRunner.STOP_AUTH)


func test_a_missing_job_file_stops_with_error() -> void:
	if not _can_spawn():
		pending("no child processes on this platform")
		return
	var dir: String = ROOT.path_join("job_missing")
	DirAccess.make_dir_recursive_absolute(dir)
	assert_eq(_run_worker(dir), BenchRunner.EXIT_BAD_INPUT)
	var events: Array[Dictionary] = _events(dir)
	assert_eq(events.size(), 1)
	if events.size() == 1:
		assert_eq(str(events[0][BenchJobState.FIELD_REASON]), BenchRunner.STOP_ERROR)
