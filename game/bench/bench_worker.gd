extends Node
## The game as a headless benchmark worker (docs/specs/benchmark.md §19.4):
## `<game> --headless -- --bench-worker=<job dir>` plays the seeds of
## `<job dir>/job.json` with a model, writes one entry per finished seed where
## the tool would (§10.2), appends its progress to `<job dir>/progress.jsonl`
## and quits with §11.3's exit codes. `BenchJobs` starts it; a benchmark never
## runs in the game's own process, because a backend blocks while it waits.
##
## The key comes on stdin, one line, read once — never in the job file, never an
## argument. A mock backend (debug builds only) reads `BenchJob.MOCK_KEY_LINE`
## the same way and stops without it, so a mock run checks the pipe. The worker never
## enters the session and writes nothing but its entries, the cache and the
## progress file: no settings, no profile, no statistics, no autosave.
##
## `game/main.gd` adds it in place of the boot. Scene-specific, so no
## `class_name`; it works in `_ready`, once the main loop runs (TLS).

const DATA_ROOT: String = "res://data"
## Under the job's `out` when it names no cache.
const CACHE_FOLDER: String = "cache"

## The key line's end, and the most bytes it is read to.
const NEWLINE: int = 10
const CARRIAGE_RETURN: int = 13
const KEY_MAX_BYTES: int = 4096

var _job_dir: String = ""
var _progress_path: String = ""


func _ready() -> void:
	_job_dir = BenchRunner.worker_job_dir(OS.get_cmdline_user_args())
	_progress_path = _job_dir.path_join(BenchJobState.PROGRESS_FILE)
	# `Settings` read the switch too and wrote nothing; nothing later may either.
	Settings.persist = false
	get_tree().quit(run())


## The whole worker; the exit code.
func run() -> int:
	var job: BenchJob = BenchJob.read(_job_dir)
	if job == null:
		return _stop(BenchRunner.STOP_ERROR, BenchRunner.EXIT_BAD_INPUT)
	return play(job, _job_dir)


## Plays `job` and writes its progress into `job_dir`. Public so a test can
## drive it in-process as well as through a real child.
func play(job: BenchJob, job_dir: String) -> int:
	_progress_path = job_dir.path_join(BenchJobState.PROGRESS_FILE)
	var config: BenchConfig = BenchConfig.load_file()
	var db: ContentDB = ContentLoader.load_root(DATA_ROOT).db if config.ok() else null
	var setup: RunSetup = RunSetup.from_dict(config.setup) if db != null else null
	if setup == null or not setup.validate(db).is_empty():
		return _stop(BenchRunner.STOP_ERROR, BenchRunner.EXIT_BAD_INPUT)
	var model: String = job.model
	var effort: String = job.effort
	var suite: String = job.suite if not job.suite.is_empty() else config.player_suite
	var locale: String = job.locale if not job.locale.is_empty() else config.locale
	var out: String = job.out
	var cap: float = job.max_cost_usd
	var seeds: Array[int] = []
	for value: int in job.seeds:
		if config.suite_seeds(suite).has(value):
			seeds.append(value)
	var mock_mode: String = MockBackend.mode_of(job.backend)
	var mock: bool = not mock_mode.is_empty()
	var typesafe: bool = job.backend == BenchJob.BACKEND_TYPESAFE
	if model.is_empty() or out.is_empty() or seeds.size() != job.seeds.size() or seeds.is_empty() \
			or not BenchEffort.is_level(effort) or (mock and not OS.is_debug_build()) \
			or (not mock and not typesafe and job.backend != BenchJob.BACKEND_OPENROUTER):
		return _stop(BenchRunner.STOP_ERROR, BenchRunner.EXIT_BAD_INPUT)
	if mock and _read_key() != BenchJob.MOCK_KEY_LINE:
		return _stop(BenchRunner.STOP_AUTH, BenchRunner.EXIT_BAD_INPUT)
	var params: Dictionary = {}
	var live: ModelBackend = null
	if typesafe:
		params = BenchChoice.params_of(config)
		# The game asks a decision model through OpenRouter only (§19.3): its
		# address and key, the id sent whole.
		live = TypeSafeBackend.new(model, _read_key(), config.base_url, config, cap,
			config.typesafe_max_requests)
	else:
		# One look at the public list (no key): the price, and what the model does
		# with an effort level. What a level sends was resolved once by the game
		# (`reasoning`), so every worker of one benchmark sends the same.
		var info: Dictionary = {} if mock else BenchEstimate.fetch_model(config.base_url, model,
			config)
		var leveled: Dictionary = BenchRunner.effort_params(BenchRunner.default_params(config),
			effort, model, info, config, job.reasoning)
		if not str(leveled["error"]).is_empty():
			return _stop(BenchRunner.STOP_BAD_REQUEST, BenchRunner.EXIT_BAD_INPUT)
		params = leveled["params"]
		# A model that thinks hard answers slowly (§18.2).
		config.timeout_s = maxi(config.timeout_s, int(config.effort_timeout_s.get(effort, 0)))
		if not mock:
			var service: OpenRouterBackend = OpenRouterBackend.new(model, _read_key(),
				config.base_url, config, cap)
			service.prompt_price = float(info.get(BenchEstimate.FIELD_PROMPT,
				OpenRouterBackend.NO_PRICE))
			service.completion_price = float(info.get(BenchEstimate.FIELD_COMPLETION,
				OpenRouterBackend.NO_PRICE))
			live = service
	var hooks: Dictionary = {}
	if live != null:
		var cache: String = job.cache if not job.cache.is_empty() else out.path_join(CACHE_FOLDER)
		hooks = BenchCache.new(cache).hooks(model, params, config.prompt_version,
			config.parser_version, true)
	for seed_value: int in seeds:
		# A mock answers each run afresh, as the tool's does.
		var backend: ModelBackend = live if live != null else MockBackend.new(mock_mode)
		var on_decision: Callable = func(policy: ModelPolicy, sim: Simulation) -> void:
			_append({
				BenchJobState.EVENT: BenchJobState.EVENT_DECISION,
				BenchJobState.FIELD_SEED: seed_value,
				BenchJobState.FIELD_DAY: sim.world.day,
				BenchJobState.FIELD_CALLS: policy.calls,
				BenchJobState.FIELD_COST: policy.cost_usd,
			})
		var result: Dictionary = BenchRunner.run_seed(db, config, setup, seed_value, backend,
			params, locale, model, suite, out, hooks, on_decision)
		var fatal: String = str(result[BenchRunner.RESULT_FATAL])
		if not fatal.is_empty():
			return _stop(BenchRunner.stop_reason(fatal), int(result[BenchRunner.RESULT_EXIT]))
		var entry: BenchEntry = result[BenchRunner.RESULT_ENTRY]
		if entry == null or str(result[BenchRunner.RESULT_PATH]).is_empty():
			return _stop(BenchRunner.STOP_ERROR, int(result[BenchRunner.RESULT_EXIT]))
		var line: Dictionary = {BenchJobState.EVENT: BenchJobState.EVENT_RUN}
		line.merge(BenchRunner.run_line(entry))
		_append(line)
	_append({BenchJobState.EVENT: BenchJobState.EVENT_DONE})
	return BenchRunner.EXIT_OK


## The key: one line on stdin, read once, to its line break or the end.
func _read_key() -> String:
	var bytes: PackedByteArray = []
	while bytes.size() < KEY_MAX_BYTES:
		var chunk: PackedByteArray = OS.read_buffer_from_stdin(1)
		if chunk.is_empty() or chunk[0] == NEWLINE:
			break
		if chunk[0] != CARRIAGE_RETURN:
			bytes.append(chunk[0])
	return bytes.get_string_from_utf8()


func _stop(reason: String, code: int) -> int:
	_append({BenchJobState.EVENT: BenchJobState.EVENT_STOPPED,
		BenchJobState.FIELD_REASON: reason})
	return code


## One JSON line at the end of the progress file — never the key, never model text.
func _append(line: Dictionary) -> void:
	var file: FileAccess = null
	if FileAccess.file_exists(_progress_path):
		file = FileAccess.open(_progress_path, FileAccess.READ_WRITE)
	else:
		file = FileAccess.open(_progress_path, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(JSON.stringify(line))
	file.close()
