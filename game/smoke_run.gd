extends Node
## `--smoke` (release.md §8): a bot plays one full run in the real session at high
## speed with the player's files untouched, writes `user://smoke/result.json`,
## prints one line and quits — 0 clean, 1 when an error was logged, 2 when the
## run did not end in time. Every build has it; CI runs it on the exported builds
## and compares the outcome and the hash with `tools/sim_run.gd`'s (§9.1).
##
## `game/main.gd` adds it in place of the boot. Scene-specific, so no `class_name`.

## After `--` on the command line.
const ARG: String = "--smoke"
const DIR: String = "user://smoke/"
const PROFILE_PATH: String = "user://smoke/profile.json"
const SAVES_DIR: String = "user://smoke/saves/"
const RESULT_PATH: String = "user://smoke/result.json"
## §8 item 3: seed 1, the greedy bot, the default setup — `sim_run`'s reference.
const RUN_SEED: int = 1
## Days a frame is worth, on top of the clock's own.
const DAYS_PER_FRAME: int = 20
## How long the ending sequence may take before the result is written anyway.
const RESULTS_TIMEOUT_S: float = 10.0
## §8 item 5: a run that does not end is a failure too.
const WATCHDOG_S: float = 600.0
const EXIT_OK: int = 0
const EXIT_ERRORS: int = 1
const EXIT_TIMEOUT: int = 2
const VERSION_SETTING: String = "application/config/version"
const BUILD_DEBUG: String = "debug"
const BUILD_RELEASE: String = "release"
const OUTCOME_NONE: String = "none"
const LINE: String = "smoke: %s outcome=%s day=%d hash=%s errors=%d"
const WORD_OK: String = "ok"
const WORD_FAIL: String = "fail"
const KEY_VERSION: String = "version"
const KEY_BUILD: String = "build"
const KEY_OUTCOME: String = "outcome"
const KEY_DAY: String = "day"
const KEY_HASH: String = "hash"
const KEY_ERRORS: String = "errors"
const KEY_SECONDS: String = "seconds"
const MS_PER_S: float = 1000.0
## What the session answers whether its results are up.
const RESULTS_OPEN: StringName = &"results_open"


## §8 item 2: counts what the engine logs as an error — errors, script and
## shader errors, never warnings. Called from any thread, hence the lock.
class ErrorCount extends Logger:
	var count: int = 0
	var _lock: Mutex = Mutex.new()

	func _log_error(_function: String, _file: String, _line: int, _code: String,
			_rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_lock.lock()
		count += 1
		_lock.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func errors() -> int:
		_lock.lock()
		var value: int = count
		_lock.unlock()
		return value


var _errors: ErrorCount = ErrorCount.new()
var _started_ms: int = 0
var _ended: bool = false
var _finished: bool = false


func _ready() -> void:
	_started_ms = Time.get_ticks_msec()
	OS.add_logger(_errors)
	isolate()
	get_tree().create_timer(WATCHDOG_S).timeout.connect(_on_watchdog_timeout)
	EventBus.run_ended.connect(_on_run_ended)
	Game.next_setup = RunSetup.new()
	ScreenRouter.show_session()
	Game.start_run(RUN_SEED, GreedyPolicy.ID, Game.next_setup)


func _process(_delta: float) -> void:
	if not _ended:
		Game.advance(DAYS_PER_FRAME)


func _exit_tree() -> void:
	OS.remove_logger(_errors)


## §8 item 1: the profile, the saves and the settings go elsewhere or nowhere, and
## the run is silent. The player's files were read at start as always; nothing
## here writes them. Static so a test can run it and put everything back.
static func isolate() -> void:
	DirAccess.make_dir_recursive_absolute(SAVES_DIR)
	Settings.persist = false
	for bus: StringName in AudioSheet.BUS_IDS:
		Settings.set_volume(String(bus), 0.0)
	ProfileManager.use_path(PROFILE_PATH)
	ProfileManager.reset()
	SaveManager.save_dir = SAVES_DIR


## §8 item 4: the one line on stdout.
static func result_line(ok: bool, outcome: String, day: int, hash_value: String,
		errors: int) -> String:
	return LINE % [WORD_OK if ok else WORD_FAIL, outcome, day, hash_value, errors]


func _on_run_ended(_outcome: String) -> void:
	_ended = true
	var waited: float = 0.0
	while waited < RESULTS_TIMEOUT_S and not _results_open():
		await get_tree().process_frame
		waited += get_process_delta_time()
	_finish(EXIT_ERRORS if _errors.errors() > 0 else EXIT_OK)


func _on_watchdog_timeout() -> void:
	_finish(EXIT_TIMEOUT)


func _results_open() -> bool:
	var screen: Node = ScreenRouter.screen_node()
	return screen != null and screen.has_method(RESULTS_OPEN) and screen.call(RESULTS_OPEN) == true


func _finish(code: int) -> void:
	if _finished:
		return
	_finished = true
	var errors: int = _errors.errors()
	var world: World = Game.sim.world if Game.sim != null else null
	var outcome: String = World.OUTCOME_IDS[world.outcome] if world != null else OUTCOME_NONE
	var day: int = world.day if world != null else 0
	var hash_value: String = world.state_hash() if world != null else ""
	var result: Dictionary = {
		KEY_VERSION: str(ProjectSettings.get_setting(VERSION_SETTING, "")),
		KEY_BUILD: BUILD_DEBUG if OS.is_debug_build() else BUILD_RELEASE,
		KEY_OUTCOME: outcome,
		KEY_DAY: day,
		KEY_HASH: hash_value,
		KEY_ERRORS: errors,
		KEY_SECONDS: (Time.get_ticks_msec() - _started_ms) / MS_PER_S,
	}
	var file: FileAccess = FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result, "\t", false))
		file.close()
	print(result_line(code == EXIT_OK, outcome, day, hash_value, errors))
	get_tree().quit(code)
