extends Node
## Autoload `BenchJobs` (docs/specs/benchmark.md §19.5): the player's own
## benchmark, which outlives screens — started from the Benchmark list, it keeps
## running while the player goes back to the title or plays a run.
##
## One benchmark at a time: one model, one effort, the suite of
## `benchmark.json` `player`. A paid model plays its seeds in several headless
## workers at once, each with its share of the cap; a free one plays them in one
## worker, one after the other (the free tier's rate limit). The workers are the
## game started again (`--bench-worker=`, §19.4); this node writes their job
## files, hands each the key on its stdin, reads their `progress.jsonl` every
## `player.poll_s` seconds and kills them on *Stop* and when the game closes —
## no worker outlives the game.
##
## The key comes from `BenchKeyStore`, read once per start off the main thread,
## or from `session_key` (a key the store could not take, memory only).
##
## `-- --bench-mock` (debug builds): workers play `mock:cheapest` under the
## chosen model id, need no key, and write into `user://benchmark_mock/`, which
## the Benchmark list then reads — never mixed with real runs.

signal changed
## §19.6–§19.7: what is known about the key changed (`key_status`, `key_hint`).
signal key_changed
## A key call of the dialog ended: `op` one of `KEY_OP_*`, `ok` whether it did
## what was asked (a save the store refused is kept for the session: false).
signal key_done(op: String, ok: bool)

## Why `start` refused.
const REASON_RUNNING: String = "running"
const REASON_UNSUPPORTED: String = "unsupported"
const REASON_CONFIG: String = "config"
const REASON_MODEL: String = "model"
const REASON_FOLDER: String = "folder"

const ARG_MOCK: String = "--bench-mock"
## Debug builds with `--bench-mock` only: a mock benchmark of that model starts
## at launch — the hand check of a build that has no picker yet (S6.12f).
const ARG_START: String = "--bench-start="
const MOCK_BACKEND: String = "mock:cheapest"
## web.md §7.1: folders under `UserPaths.root()`.
const OUT_FOLDER: String = "benchmark"
const MOCK_FOLDER: String = "benchmark_mock"
const JOBS_FOLDER: String = "jobs"
const CACHE_FOLDER: String = "cache"
const ARG_HEADLESS: String = "--headless"
const ARG_PATH: String = "--path"
const ARG_USER: String = "--"
const FEATURE_EDITOR: String = "editor"
const LINE_END: String = "\n"
const PIPE_CHUNK: int = 4096

## §19.6: what the settings row and the key dialog say about the key.
const KEY_UNKNOWN: String = "unknown"
const KEY_NONE: String = "none"
const KEY_STORED: String = "stored"
const KEY_SESSION: String = "session"
## §19.6's caption for each `key_status`; unknown reads as the look under way.
const STATE_KEYS: Dictionary[String, String] = {KEY_UNKNOWN: "UI_KEY_CHECKING",
	KEY_NONE: "UI_KEY_STATE_NONE", KEY_STORED: "UI_KEY_STATE_STORED",
	KEY_SESSION: "UI_KEY_STATE_SESSION"}
## The key calls, each off the main thread.
const KEY_OP_LOAD: String = "load"
const KEY_OP_SAVE: String = "save"
const KEY_OP_REMOVE: String = "remove"
const KEY_OP_CHECK: String = "check"
## §19.6: a hint is this and the key's last `HINT_LENGTH` characters, never more.
const HINT_PREFIX: String = "…"
const HINT_LENGTH: int = 4
## §19.7.1: OpenRouter's *current API key* endpoint under `http.base_url`.
const KEY_PATH: String = "/key"
const HEADER_AUTH: String = "Authorization: Bearer %s"
## `check_answer`'s fields: the HTTP status (−1: no answer) and the body.
const FIELD_STATUS: String = "status"
const FIELD_BODY: String = "body"

## A key the store could not take, for this session only (§19.2). Never written.
var session_key: String = ""
## The store the key is read from; tests put a fake behind it.
var key_store: BenchKeyStore = BenchKeyStore.new()
## Debug builds with `--bench-mock`.
var mock: bool = false
## Where entries (`runs/`), the cache and the job folders go.
var out_dir: String = UserPaths.at(OUT_FOLDER)

## Test seams, unset for the real thing: `launcher(job_dir: String, key: String)
## -> int` starts a worker and answers its pid (−1: failed); `running(pid: int)
## -> bool`; `killer(pid: int) -> void`.
var launcher: Callable = Callable()
var running: Callable = Callable()
var killer: Callable = Callable()
## §19.7.1's seam: `func(key: String) -> Dictionary` answering `{"status": int,
## "body": String}` in place of the request to OpenRouter.
var key_http: Callable = Callable()
## Tests: key calls run where they are asked, not on a thread.
var key_inline: bool = false

## §19.6: stored, for this session only, none — or not known before the first
## look. Memory only, like `session_key`.
var key_status: String = KEY_UNKNOWN
## `hint_of` the key, "" without one.
var key_hint: String = ""
## The answer of the last *Check* (`FIELD_STATUS`, `FIELD_BODY`).
var check_answer: Dictionary = {}

var _config: BenchConfig = null
var _state: BenchJobState = null
var _workers: Array[Worker] = []
var _launch: Thread = null
var _no_key: bool = false
var _poll_left: float = 0.0
var _key_thread: Thread = null
var _key_op: String = ""
var _key_result: Dictionary = {}


## One headless worker: its folder, its process and pipe, how far its progress
## file has been read, and how it ended.
class Worker:
	var dir: String = ""
	var pid: int = -1
	var pipe: FileAccess = null
	var errors: FileAccess = null
	var offset: int = 0
	var ended: bool = false
	## "" when done, else a `BenchRunner.STOP_REASONS` value.
	var stop_reason: String = ""


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	# A worker is this game too; it plays its job and is nobody's parent.
	if not BenchRunner.worker_job_dir(args).is_empty():
		set_process(false)
		return
	if Game.debug_allowed and args.has(ARG_MOCK):
		use_mock(true)
		var model: String = ""
		for arg: String in args:
			if arg.begins_with(ARG_START):
				model = arg.trim_prefix(ARG_START)
		if not model.is_empty():
			start.call_deferred(model, BenchEffort.NORMAL, config().player_default_cap_usd)


func _process(delta: float) -> void:
	if _key_thread != null and not _key_thread.is_alive():
		_finish_key()
	if _launch != null and not _launch.is_alive():
		_finish_launch()
	if _state == null or not _state.is_running() or _launch != null:
		return
	_poll_left -= delta
	if _poll_left > 0.0:
		return
	_poll_left = config().player_poll_s
	poll()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_kill_all()


func _exit_tree() -> void:
	wait_started()
	if _key_thread != null:
		_finish_key()
	_kill_all()


## `--bench-mock`: mock workers, and the list reads their folder.
func use_mock(on: bool) -> void:
	mock = on
	out_dir = UserPaths.at(MOCK_FOLDER if on else OUT_FOLDER)
	if on:
		BenchLibrary.user_dir = out_dir.path_join(BenchRunner.RUNS_DIR) + "/"


func config() -> BenchConfig:
	if _config == null:
		_config = BenchConfig.load_file()
	return _config


## The running or last benchmark, or null before the first.
func state() -> BenchJobState:
	return _state


## Starts a benchmark of `model` at `effort` with the player's total cap:
## "" when it started, else a `REASON_*`. `reasoning` is what the effort
## resolved to (`BenchEffort.reasoning_for`, §19.8 item 5), resolved once by the
## caller so every worker sends the same; `free` a model whose price is zero.
func start(model: String, effort: String, cap_usd: float, reasoning: String = "",
		free: bool = false) -> String:
	if _state != null and _state.is_running():
		return REASON_RUNNING
	if not mock and not BenchKeyStore.is_supported():
		return REASON_UNSUPPORTED
	var settings: BenchConfig = config()
	if not settings.ok():
		return REASON_CONFIG
	if model.strip_edges().is_empty() or not BenchEffort.is_level(effort):
		return REASON_MODEL
	free = free or model.ends_with(ModelCatalogue.FREE_SUFFIX)
	var seeds: Array[int] = settings.suite_seeds(settings.player_suite)
	var count: int = mini(settings.player_workers_free if free else settings.player_workers_paid,
		seeds.size())
	var root: String = _next_job_dir()
	if root.is_empty():
		return REASON_FOLDER
	var jobs: Array[BenchJob] = []
	for i: int in count:
		var job: BenchJob = BenchJob.new()
		job.model = model
		job.backend = _backend_for(model, settings)
		job.effort = effort
		job.reasoning = reasoning
		job.suite = settings.player_suite
		job.max_cost_usd = cap_usd / float(count)
		job.locale = settings.locale
		job.out = out_dir
		job.cache = out_dir.path_join(CACHE_FOLDER)
		jobs.append(job)
	# Round robin, so three workers play one seed each and one plays them all.
	for i: int in seeds.size():
		jobs[i % count].seeds.append(seeds[i])
	_workers.clear()
	for i: int in count:
		var worker: Worker = Worker.new()
		worker.dir = root.path_join(str(i))
		if not jobs[i].write(worker.dir):
			return REASON_FOLDER
		_workers.append(worker)
	_state = BenchJobState.new(model, effort, cap_usd, free, seeds)
	_state.mock = mock
	_no_key = false
	_poll_left = 0.0
	# The store blocks for a second or two (PowerShell); the workers start after.
	_launch = Thread.new()
	_launch.start(_launch_all)
	changed.emit()
	return ""


## Blocks until the workers of the last `start` are launched (or the start
## failed for want of a key). The interface never needs it: `_process` adopts
## them when the launch is done.
func wait_started() -> void:
	if _launch != null:
		_finish_launch()


## *Stop*: every worker killed. A seed in play leaves no entry; finished ones
## and every answer in the cache stay.
func stop() -> void:
	if _state == null or not _state.is_running():
		return
	wait_started()
	_kill_all()
	_state.end(BenchJobState.REASON_PLAYER, true)
	changed.emit()


## Reads what every worker wrote since the last look and judges the end: a
## worker that stopped stops the benchmark (the others are killed), a worker
## that vanished without a word stopped with `error`, all done is done.
func poll() -> void:
	if _state == null or not _state.is_running():
		return
	var moved: bool = false
	for worker: Worker in _workers:
		_drain(worker)
		moved = _read_progress(worker) or moved
		if not worker.ended and not _is_running(worker.pid):
			# Its last lines may have landed after the read above.
			moved = _read_progress(worker) or moved
			if not worker.ended:
				worker.ended = true
				worker.stop_reason = BenchRunner.STOP_ERROR
	var reason: String = ""
	var all_done: bool = true
	for worker: Worker in _workers:
		all_done = all_done and worker.ended
		if worker.ended and not worker.stop_reason.is_empty() and reason.is_empty():
			reason = worker.stop_reason
	if not reason.is_empty():
		_kill_all()
		_state.end(reason, true)
		moved = true
	elif all_done:
		_close_pipes()
		_state.end("", false)
		moved = true
	if moved:
		changed.emit()


## §19.6: "…" and the key's last four characters.
static func hint_of(key: String) -> String:
	return "" if key.is_empty() else HINT_PREFIX + key.right(HINT_LENGTH)


## §19.6: the caption of the settings row and the key dialog — never more of
## the key than its hint.
func key_state_text() -> String:
	return tr(STATE_KEYS[key_status]).format({"hint": key_hint})


## Whether a key call is under way (the dialog waits with its buttons off).
func key_busy() -> bool:
	return _key_thread != null


## Looks the key up in the store (a session key counts); `key_changed` after.
func refresh_key() -> bool:
	return _key_call(KEY_OP_LOAD, "")


## Saves `key` in the store — or, when the store refuses, for the session.
func save_key(key: String) -> bool:
	return _key_call(KEY_OP_SAVE, key)


## Removes the key from the store and the session.
func remove_key() -> bool:
	return _key_call(KEY_OP_REMOVE, "")


## §19.7.1: asks OpenRouter about `typed`, or — empty — about the saved key;
## the answer lands in `check_answer`.
func check_key(typed: String) -> bool:
	return _key_call(KEY_OP_CHECK, typed)


## The job folder of worker `index` of the running benchmark ("" none) — for
## tests and the hand check.
func worker_dir(index: int) -> String:
	return _workers[index].dir if index >= 0 and index < _workers.size() else ""


func worker_count() -> int:
	return _workers.size()


## One key call: off the main thread (PowerShell takes a second or two), its
## result taken in `_process`. False when one is already under way.
func _key_call(op: String, key: String) -> bool:
	if _key_thread != null:
		return false
	_key_op = op
	if key_inline:
		_key_result = _key_work(op, key)
		_apply_key()
		return true
	_key_thread = Thread.new()
	_key_thread.start(func() -> void: _key_result = _key_work(op, key))
	return true


## Off the main thread: the store's answer, and for *Check* OpenRouter's. The
## key goes into the result only as its hint — and, when the store refused it,
## as the session's key.
func _key_work(op: String, key: String) -> Dictionary:
	var result: Dictionary = {"ok": true, "stored": "", "session": session_key}
	match op:
		KEY_OP_SAVE:
			result["ok"] = key_store.save(key)
			result["stored"] = key if bool(result["ok"]) else ""
			result["session"] = "" if bool(result["ok"]) else key
		KEY_OP_REMOVE:
			result["ok"] = key_store.remove()
			result["session"] = ""
		KEY_OP_CHECK:
			var stored: String = key_store.load()
			result["stored"] = stored
			var asked: String = key
			if asked.is_empty():
				asked = session_key if not session_key.is_empty() else stored
			result["answer"] = _ask_key(asked)
			result["ok"] = int((result["answer"] as Dictionary)[FIELD_STATUS]) \
				== OpenRouterBackend.STATUS_OK
		_:
			result["stored"] = key_store.load()
	return result


## §19.7.1: one `GET <base_url>/key` with the key, `global.timeout_s` at most.
func _ask_key(key: String) -> Dictionary:
	if key.is_empty():
		return {FIELD_STATUS: OpenRouterBackend.STATUS_AUTH, FIELD_BODY: ""}
	if key_http.is_valid():
		var faked: Variant = key_http.call(key)
		return faked if typeof(faked) == TYPE_DICTIONARY \
			else {FIELD_STATUS: OpenRouterBackend.STATUS_NONE, FIELD_BODY: ""}
	var settings: BenchConfig = config()
	var base: Dictionary = OpenRouterBackend.parse_base_url(settings.base_url)
	if base.is_empty():
		return {FIELD_STATUS: OpenRouterBackend.STATUS_NONE, FIELD_BODY: ""}
	var answer: Dictionary = OpenRouterBackend.request(base, HTTPClient.METHOD_GET,
		str(base["prefix"]) + KEY_PATH, PackedStringArray([HEADER_AUTH % key]), "",
		settings.global_timeout_s)
	return {FIELD_STATUS: int(answer["status"]), FIELD_BODY: str(answer["body"])}


func _finish_key() -> void:
	_key_thread.wait_to_finish()
	_key_thread = null
	_apply_key()


## On the main thread: the result of the last key call made the state.
func _apply_key() -> void:
	var result: Dictionary = _key_result
	_key_result = {}
	session_key = str(result.get("session", session_key))
	var stored: String = str(result.get("stored", ""))
	if _key_op == KEY_OP_REMOVE:
		stored = ""
	if not stored.is_empty():
		key_status = KEY_STORED
		key_hint = hint_of(stored)
	elif not session_key.is_empty():
		key_status = KEY_SESSION
		key_hint = hint_of(session_key)
	else:
		key_status = KEY_NONE
		key_hint = ""
	if _key_op == KEY_OP_CHECK:
		check_answer = result.get("answer", {})
	key_changed.emit()
	key_done.emit(_key_op, bool(result.get("ok", false)))


func _backend_for(model: String, settings: BenchConfig) -> String:
	if mock:
		return MOCK_BACKEND
	if model.begins_with(settings.typesafe_model_prefix):
		return BenchJob.BACKEND_TYPESAFE
	return BenchJob.BACKEND_OPENROUTER


## Off the main thread: the key once, then every worker.
func _launch_all() -> void:
	var key: String = BenchJob.MOCK_KEY_LINE
	if not mock:
		key = session_key if not session_key.is_empty() else key_store.load()
		if key.is_empty():
			_no_key = true
			return
	for worker: Worker in _workers:
		_start_worker(worker, key)


func _start_worker(worker: Worker, key: String) -> void:
	if launcher.is_valid():
		worker.pid = int(launcher.call(worker.dir, key))
		return
	var arguments: PackedStringArray = [ARG_HEADLESS]
	# From the editor the executable is the editor's: it needs the project.
	if OS.has_feature(FEATURE_EDITOR):
		arguments.append_array([ARG_PATH, ProjectSettings.globalize_path("res://")])
	arguments.append_array([ARG_USER, BenchRunner.WORKER_ARG + worker.dir])
	var child: Dictionary = OS.execute_with_pipe(OS.get_executable_path(), arguments, false)
	if child.is_empty():
		return
	worker.pid = int(child["pid"])
	worker.pipe = child["stdio"]
	worker.errors = child["stderr"]
	# §19.4: the key on stdin, one line. The pipe stays open (closing it would
	# close the worker's stdout under it) and is drained.
	worker.pipe.store_string(key + LINE_END)
	worker.pipe.flush()


func _finish_launch() -> void:
	_launch.wait_to_finish()
	_launch = null
	_adopt_launched()


## After the launch thread: a missing key or a worker that did not start stops
## the benchmark at once.
func _adopt_launched() -> void:
	if _state == null or not _state.is_running():
		return
	if _no_key:
		_state.end(BenchRunner.STOP_AUTH, true)
		changed.emit()
		return
	for worker: Worker in _workers:
		if worker.pid < 0:
			_kill_all()
			_state.end(BenchRunner.STOP_ERROR, true)
			changed.emit()
			return


## New complete lines of a worker's progress file; whether any changed the state.
func _read_progress(worker: Worker) -> bool:
	var file: FileAccess = FileAccess.open(worker.dir.path_join(BenchJobState.PROGRESS_FILE),
		FileAccess.READ)
	if file == null:
		return false
	var length: int = file.get_length()
	if length <= worker.offset:
		return false
	file.seek(worker.offset)
	var bytes: PackedByteArray = file.get_buffer(length - worker.offset)
	file.close()
	# Only whole lines: the worker may be halfway through its next one.
	var last: int = bytes.rfind(LINE_END.unicode_at(0))
	if last < 0:
		return false
	worker.offset += last + 1
	var moved: bool = false
	for text: String in bytes.slice(0, last).get_string_from_utf8().split(LINE_END, false):
		var line: Variant = JSON.parse_string(text)
		if typeof(line) != TYPE_DICTIONARY:
			continue
		var event: String = str((line as Dictionary).get(BenchJobState.EVENT, ""))
		if event == BenchJobState.EVENT_DONE:
			worker.ended = true
		elif event == BenchJobState.EVENT_STOPPED:
			worker.ended = true
			var why: String = str((line as Dictionary).get(BenchJobState.FIELD_REASON, ""))
			worker.stop_reason = why if BenchRunner.STOP_REASONS.has(why) \
				else BenchRunner.STOP_ERROR
		moved = _state.apply_line(line) or moved
	return moved


## Whatever the worker printed, thrown away: a full pipe would stall it.
func _drain(worker: Worker) -> void:
	for pipe: FileAccess in [worker.pipe, worker.errors]:
		if pipe == null or not pipe.is_open():
			continue
		while not pipe.get_buffer(PIPE_CHUNK).is_empty():
			pass


func _is_running(pid: int) -> bool:
	if running.is_valid():
		return bool(running.call(pid))
	return pid >= 0 and OS.is_process_running(pid)


func _kill_all() -> void:
	for worker: Worker in _workers:
		if worker.pid >= 0 and not worker.ended and _is_running(worker.pid):
			if killer.is_valid():
				killer.call(worker.pid)
			else:
				OS.kill(worker.pid)
		worker.ended = true
	_close_pipes()


func _close_pipes() -> void:
	for worker: Worker in _workers:
		for pipe: FileAccess in [worker.pipe, worker.errors]:
			if pipe != null and pipe.is_open():
				pipe.close()
		worker.pipe = null
		worker.errors = null


## A fresh `jobs/<n>/`, one above the highest there; the oldest folders beyond
## `player.jobs_kept` go first. "" when it cannot be made.
func _next_job_dir() -> String:
	var jobs: String = out_dir.path_join(JOBS_FOLDER)
	var numbers: Array[int] = []
	if DirAccess.dir_exists_absolute(jobs):
		for name: String in DirAccess.get_directories_at(jobs):
			if name.is_valid_int():
				numbers.append(name.to_int())
	numbers.sort()
	while numbers.size() >= config().player_jobs_kept:
		_remove_tree(jobs.path_join(str(numbers[0])))
		numbers.remove_at(0)
	var next: int = numbers[numbers.size() - 1] + 1 if not numbers.is_empty() else 1
	var dir: String = jobs.path_join(str(next))
	return dir if DirAccess.make_dir_recursive_absolute(dir) == OK else ""


static func _remove_tree(dir: String) -> void:
	for sub: String in DirAccess.get_directories_at(dir):
		_remove_tree(dir.path_join(sub))
	for file_name: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file_name))
	DirAccess.remove_absolute(dir)
