extends Control
## The frame-time bench (release.md §11.3). The `Perf (local)` export starts it
## (`run/main_scene.perf`); `"$GODOT" --path . res://tools/perf/perf_bench.tscn`
## runs it while iterating. It plays seed 1 with the greedy bot to the late game
## with nothing on screen, timing every day from day 300 on; saves the late game;
## continues it the way the title's *Continue* does, timing the load; then drives
## a 120-second script at 4× with the bot still playing and records every frame.
## `-- --label=<name>` names the output: `user://perf/<label>.csv` (one row per
## frame) and `user://perf/<label>.json` (the summary), and one `perf:` line on
## stdout. The player's files are read by the autoloads as always, never written.
## In a browser (web.md §13.2, the `Perf web (local)` export) the label is `web`,
## no file is written (it would sit in the page's IndexedDB), the engine's static
## memory peak stands in for the working set, and the `perf:` line on the console
## is the result — `tools/web/web_perf.py` reads it.
##
## A tool, so no `class_name`. It stands in for `game/main.gd`: the backdrop, the
## slot the router fills, the theme and the logical scale are set up the same way.

const PerfStats := preload("res://tools/perf/perf_stats.gd")

## After `--` on the command line.
const ARG_LABEL: String = "--label="
const DEFAULT_LABEL: String = "bench"
## web.md §13.2: the runner names the run; the bench only says where it ran.
const WEB_LABEL: String = "web"
const FEATURE_WEB: String = "web"
const DIR: String = "user://perf/"
const PROFILE_PATH: String = "user://perf/profile.json"
const SAVES_DIR: String = "user://perf/saves/"
const CSV_PATH: String = "user://perf/%s.csv"
const SUMMARY_PATH: String = "user://perf/%s.json"

## §11.3 step 2: seed 1, the greedy bot, the default setup (Language Model,
## standard) — `sim_run`'s and the smoke's reference run.
const RUN_SEED: int = 1
const LATE_FROM_DAY: int = 300
const LATE_TO_DAY: int = 450
## A run that ends before `LATE_TO_DAY` is saved this many days before its end.
const END_MARGIN_DAYS: int = 30
## Untimed days per frame on the way to the late game.
const DAYS_PER_FRAME: int = 25
## Timed days between two frames, so the window keeps answering.
const TIMED_DAYS_PER_FRAME: int = 10
## The script reloads the late save this many days before the run's end: the
## late game is shorter than 120 s at 4×, and an ending is a screen change.
const RELOAD_MARGIN_DAYS: int = 2
## Frames after a reload that belong to the screen change (§11.2's max row).
const SCREEN_CHANGE_FRAMES: int = 3

## §11.3 step 4, seconds from the script's start.
const SPEED: int = 4
const SCRIPT_SECONDS: float = 120.0
const PAN_FROM_S: float = 20.0
const OVERLAYS_FROM_S: float = 40.0
const TREE_FROM_S: float = 60.0
const ANALYSIS_FROM_S: float = 80.0
const ANALYSIS_TO_S: float = 100.0
const OVERLAY_SECONDS: float = 4.0
const TREE_TOGGLE_SECONDS: float = 5.0
## The map is panned over Europe at the camera's closest zoom, from this far
## west of the anchor to as far east of it (map pixels).
const PAN_REGION: String = "germany"
const PAN_HALF_SPAN: float = 400.0
const OVERLAY_COUNT: int = 4
const ACTION_TREE: StringName = &"game_tree"
const ACTION_ANALYSIS: StringName = &"game_analysis"
const NODE_TREE: String = "%TechTree"
const NODE_ANALYSIS: String = "%AnalysisPanel"
const NODE_MAP_VIEW: String = "MapLayer/MapView"

const WATCHDOG_S: float = 900.0
const EXIT_OK: int = 0
const EXIT_FAILED: int = 1
const EXIT_TIMEOUT: int = 2
const USEC_PER_MS: float = 1000.0
const USEC_PER_S: float = 1000000.0
const BYTES_PER_MB: float = 1048576.0
const P50: float = 50.0
const P95: float = 95.0
const P99: float = 99.0
const CSV_HEADER: String = "frame,t_ms,frame_us,process_us,ticks,draw_calls,video_mem_bytes,screen_change"

enum Stage { SETUP, SCRIPT, DONE }

var _label: String = DEFAULT_LABEL
var _stage: Stage = Stage.SETUP
var _boot_ms: int = 0
var _load_ms: float = 0.0
var _end_day: int = -1
var _late_day: int = 0
var _tick_us: PackedFloat64Array = PackedFloat64Array()
var _script_start_us: int = 0
var _last_frame_us: int = 0
var _process_start_us: int = 0
var _pre_draw_us: int = 0
var _ticks_this_frame: int = 0
var _change_frames_left: int = 0
var _reload_pending: bool = false
var _reloads: int = 0
var _session: Node = null
var _map_view: MapView = null
var _tree: Node = null
var _analysis: Node = null

# One entry per recorded frame.
var _t_ms: PackedFloat64Array = PackedFloat64Array()
var _frame_us: PackedFloat64Array = PackedFloat64Array()
var _process_us: PackedFloat64Array = PackedFloat64Array()
var _ticks: PackedInt32Array = PackedInt32Array()
var _draw_calls: PackedInt32Array = PackedInt32Array()
var _video_mem: PackedInt64Array = PackedInt64Array()
var _screen_change: PackedByteArray = PackedByteArray()

@onready var _slot: Control = %ScreenSlot


func _ready() -> void:
	_boot_ms = Time.get_ticks_msec()
	_label = WEB_LABEL if OS.has_feature(FEATURE_WEB) else _label_from(OS.get_cmdline_user_args())
	print("perf: adapter=%s driver=%s window=%s" % [RenderingServer.get_video_adapter_name(),
		RenderingServer.get_current_rendering_driver_name(), get_window().size])
	_isolate()
	theme = ThemeBuilder.build(ThemeBuilder.VARIANT_COLD, Settings.text_scale)
	ScreenRouter.slot = _slot
	LogicalScale.apply(get_window())
	get_window().size_changed.connect(_on_window_size_changed)
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.run_ended.connect(_on_run_ended)
	get_tree().process_frame.connect(_on_process_frame)
	RenderingServer.frame_pre_draw.connect(_on_frame_pre_draw)
	RenderingServer.frame_post_draw.connect(_on_frame_post_draw)
	get_tree().create_timer(WATCHDOG_S).timeout.connect(_on_watchdog_timeout)
	_run.call_deferred()


func _process(_delta: float) -> void:
	if _stage != Stage.SCRIPT:
		return
	var t: float = float(Time.get_ticks_usec() - _script_start_us) / USEC_PER_S
	if t >= SCRIPT_SECONDS:
		_finish(EXIT_OK)
		return
	if _reload_pending or _near_end():
		_reload()
		return
	_steer(t)


## §11.3 step 1's isolation, as the smoke's (§8 step 1): the profile and the
## saves go to `user://perf/`, the settings file is not written, and the bench
## is silent. Screen effects at the platform's default (Full on a desktop,
## Subtle in a browser — web.md §13.1), reduced motion off, text 100 %.
func _isolate() -> void:
	DirAccess.make_dir_recursive_absolute(SAVES_DIR)
	Settings.persist = false
	for bus: StringName in AudioSheet.BUS_IDS:
		Settings.set_volume(String(bus), 0.0)
	Settings.set_locale(Settings.LOCALE_EN)
	Settings.set_screen_effects(Settings.default_screen_effects())
	Settings.set_reduced_motion(false)
	Settings.set_text_scale(Settings.DEFAULT_TEXT_SCALE)
	# The heavier case: the tree open while the days still run (the phone's
	# default), and no introduction cards over a bot run.
	Settings.set_tree_pauses(false)
	Settings.set_tutorial(false)
	Settings.set_hints(false)
	ProfileManager.use_path(PROFILE_PATH)
	ProfileManager.reset()
	SaveManager.save_dir = SAVES_DIR


func _run() -> void:
	await _play_to_late_game()
	if not _save_late_game():
		_finish(EXIT_FAILED)
		return
	var started: int = Time.get_ticks_usec()
	ScreenRouter.continue_run()
	if ScreenRouter.current != ScreenRouter.Screen.SESSION or Game.sim == null:
		push_error("perf: the late save did not load")
		_finish(EXIT_FAILED)
		return
	await RenderingServer.frame_post_draw
	_load_ms = float(Time.get_ticks_usec() - started) / USEC_PER_MS
	Game.set_speed(SPEED)
	_script_start_us = Time.get_ticks_usec()
	_last_frame_us = _script_start_us
	_ticks_this_frame = 0
	_stage = Stage.SCRIPT


## §11.3 step 2: to day 300 untimed, then every day timed to day 450 or the end.
func _play_to_late_game() -> void:
	_start_bot_run()
	while _running() and Game.sim.world.day < LATE_FROM_DAY:
		Game.advance(mini(DAYS_PER_FRAME, LATE_FROM_DAY - Game.sim.world.day))
		await get_tree().process_frame
	while _running() and Game.sim.world.day < LATE_TO_DAY:
		for i: int in TIMED_DAYS_PER_FRAME:
			if not _running() or Game.sim.world.day >= LATE_TO_DAY:
				break
			Game.advance(1)
			_tick_us.append(float(Game.last_tick_usec))
		await get_tree().process_frame
	if Game.sim == null:
		return
	if Game.sim.world.outcome == World.Outcome.NONE:
		_late_day = Game.sim.world.day
		return
	# The run ended first: the same run again, to `END_MARGIN_DAYS` before it.
	_end_day = Game.sim.world.day
	_late_day = maxi(LATE_FROM_DAY, _end_day - END_MARGIN_DAYS)
	_start_bot_run()
	while _running() and Game.sim.world.day < _late_day:
		Game.advance(mini(DAYS_PER_FRAME, _late_day - Game.sim.world.day))
		await get_tree().process_frame


## The clock stays stopped: only the bench advances the run here.
func _start_bot_run() -> void:
	Game.start_run(RUN_SEED, GreedyPolicy.ID, RunSetup.new())
	Game.set_speed(0)


func _running() -> bool:
	return Game.sim != null and Game.sim.world.outcome == World.Outcome.NONE


## The late game goes where *Continue* looks for it.
func _save_late_game() -> bool:
	if not _running():
		push_error("perf: no late game to save")
		return false
	var reason: String = SaveManager.save(SaveManager.AUTOSAVE)
	if not reason.is_empty():
		push_error("perf: saving the late game failed: %s" % reason)
		return false
	# The run stays: a load keeps `Game.policy`, so the bot plays on after it.
	return true


func _near_end() -> bool:
	return _end_day > 0 and Game.sim != null \
		and Game.sim.world.day >= _end_day - RELOAD_MARGIN_DAYS


## The late save again, as *Continue* loads it; the frames around it are a
## screen change.
func _reload() -> void:
	_reload_pending = false
	_reloads += 1
	_change_frames_left = SCREEN_CHANGE_FRAMES
	ScreenRouter.continue_run()
	Game.set_speed(SPEED)


## Puts the view the script wants at `t` in place — after a reload too, since
## the new session starts with every panel closed.
func _steer(t: float) -> void:
	var session: Node = ScreenRouter.screen_node()
	if session == null:
		return
	if session != _session:
		# Looked up while every panel is closed: the modal host takes an open
		# tree in, and a unique name does not find it there.
		_session = session
		_map_view = session.get_node_or_null(NODE_MAP_VIEW) as MapView
		_tree = session.get_node_or_null(NODE_TREE)
		_analysis = session.get_node_or_null(NODE_ANALYSIS)
	var camera: MapCamera = get_tree().get_first_node_in_group(MapCamera.GROUP) as MapCamera
	if camera != null:
		_steer_camera(camera, t)
	var overlay: int = 0
	if t >= OVERLAYS_FROM_S and t < TREE_FROM_S:
		overlay = int((t - OVERLAYS_FROM_S) / OVERLAY_SECONDS) % OVERLAY_COUNT
	if _map_view != null and int(_map_view.overlay_mode) != overlay:
		EventBus.overlay_changed.emit(overlay)
	var tree_wanted: bool = t >= TREE_FROM_S and t < ANALYSIS_FROM_S \
		and int((t - TREE_FROM_S) / TREE_TOGGLE_SECONDS) % 2 == 0
	if _tree != null and bool(_tree.call(&"is_open")) != tree_wanted:
		_press(ACTION_TREE)
		return
	var analysis_wanted: bool = t >= ANALYSIS_FROM_S and t < ANALYSIS_TO_S
	if _analysis != null and bool(_analysis.get(&"is_open")) != analysis_wanted:
		_press(ACTION_ANALYSIS)


func _steer_camera(camera: MapCamera, t: float) -> void:
	if t < PAN_FROM_S or t >= OVERLAYS_FROM_S:
		camera.set_view(MapCamera.START_CENTER, camera.zoom_min)
		return
	var region: RegionDef = Game.db.region_by_id(PAN_REGION) if Game.db != null else null
	if region == null:
		return
	var along: float = (t - PAN_FROM_S) / (OVERLAYS_FROM_S - PAN_FROM_S)
	var anchor: Vector2 = Vector2(region.anchor)
	var x: float = lerpf(anchor.x - PAN_HALF_SPAN, anchor.x + PAN_HALF_SPAN, along)
	camera.set_view(Vector2(x, anchor.y), MapCamera.ZOOM_MAX)


## The player's path: the session's own action handler.
func _press(action: StringName) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	var release: InputEventAction = InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)


## §11.3 step 5: one row per drawn frame. The frame time runs from the last
## frame's end of drawing to this one's; the process time from the start of this
## frame's process step to the start of its drawing — every `_process` and the
## tick, which `TIME_PROCESS` (the largest of the last second) cannot tell apart.
func _record() -> void:
	var now: int = Time.get_ticks_usec()
	_t_ms.append(float(now - _script_start_us) / USEC_PER_MS)
	_frame_us.append(float(now - _last_frame_us))
	_last_frame_us = now
	_process_us.append(float(maxi(0, _pre_draw_us - _process_start_us)))
	_ticks.append(_ticks_this_frame)
	_ticks_this_frame = 0
	_draw_calls.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	_video_mem.append(int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)))
	_screen_change.append(1 if _change_frames_left > 0 else 0)
	_change_frames_left = maxi(0, _change_frames_left - 1)


func _summary() -> Dictionary:
	var frames: PackedFloat64Array = PackedFloat64Array()
	var process: PackedFloat64Array = PackedFloat64Array()
	var tick_frames: PackedFloat64Array = PackedFloat64Array()
	var all_frames_max: float = 0.0
	var draw_max: int = 0
	var video_max: int = 0
	for i: int in _frame_us.size():
		all_frames_max = maxf(all_frames_max, _frame_us[i])
		draw_max = maxi(draw_max, _draw_calls[i])
		video_max = maxi(video_max, _video_mem[i])
		if _screen_change[i] != 0:
			continue
		frames.append(_frame_us[i])
		process.append(_process_us[i])
		if _ticks[i] > 0:
			tick_frames.append(_frame_us[i])
	return {
		"label": _label,
		"version": str(ProjectSettings.get_setting("application/config/version", "")),
		"build": "debug" if OS.is_debug_build() else "release",
		"adapter": RenderingServer.get_video_adapter_name(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"window": "%dx%d" % [get_window().size.x, get_window().size.y],
		"frames": frames.size(),
		"frame_p50_ms": PerfStats.percentile(frames, P50) / USEC_PER_MS,
		"frame_p95_ms": PerfStats.percentile(frames, P95) / USEC_PER_MS,
		"frame_p99_ms": PerfStats.percentile(frames, P99) / USEC_PER_MS,
		"frame_max_ms": PerfStats.maximum(frames) / USEC_PER_MS,
		"frame_max_with_changes_ms": all_frames_max / USEC_PER_MS,
		"process_p95_ms": PerfStats.percentile(process, P95) / USEC_PER_MS,
		"tick_frames": tick_frames.size(),
		"tick_frame_p99_ms": PerfStats.percentile(tick_frames, P99) / USEC_PER_MS,
		"tick_days": _tick_us.size(),
		"tick_mean_ms": PerfStats.mean(_tick_us) / USEC_PER_MS,
		"tick_max_ms": PerfStats.maximum(_tick_us) / USEC_PER_MS,
		"draw_calls_max": draw_max,
		"video_mem_max_mb": float(video_max) / BYTES_PER_MB,
		# web.md §13.1's memory row; the engine counts it in debug templates only.
		"static_memory_peak_mb": float(OS.get_static_memory_peak_usage()) / BYTES_PER_MB,
		"boot_ms": _boot_ms,
		"load_ms": _load_ms,
		"end_day": _end_day,
		"late_day": _late_day,
		"reloads": _reloads,
	}


func _write_csv() -> void:
	var file: FileAccess = FileAccess.open(CSV_PATH % _label, FileAccess.WRITE)
	if file == null:
		push_error("perf: cannot write %s" % (CSV_PATH % _label))
		return
	file.store_line(CSV_HEADER)
	for i: int in _frame_us.size():
		file.store_line("%d,%.1f,%d,%d,%d,%d,%d,%d" % [i, _t_ms[i], int(_frame_us[i]),
			int(_process_us[i]), _ticks[i], _draw_calls[i], _video_mem[i], _screen_change[i]])
	file.close()


func _finish(code: int) -> void:
	if _stage == Stage.DONE:
		return
	_stage = Stage.DONE
	Game.set_speed(0)
	var summary: Dictionary = _summary()
	summary["exit"] = code
	if not OS.has_feature(FEATURE_WEB):
		_write_csv()
		var file: FileAccess = FileAccess.open(SUMMARY_PATH % _label, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(summary, "\t", false))
			file.close()
	print("perf: %s" % JSON.stringify(summary, "", false))
	get_tree().quit(code)


static func _label_from(args: PackedStringArray) -> String:
	for arg: String in args:
		if arg.begins_with(ARG_LABEL) and arg.length() > ARG_LABEL.length():
			return arg.substr(ARG_LABEL.length())
	return DEFAULT_LABEL


func _on_tick_advanced(_day: int) -> void:
	_ticks_this_frame += 1


func _on_process_frame() -> void:
	_process_start_us = Time.get_ticks_usec()


func _on_frame_pre_draw() -> void:
	_pre_draw_us = Time.get_ticks_usec()


func _on_frame_post_draw() -> void:
	if _stage == Stage.SCRIPT:
		_record()


func _on_run_ended(_outcome: String) -> void:
	# The bench's own runs to the late game end too; only the script's matters.
	if _stage == Stage.SCRIPT:
		_reload_pending = true


func _on_watchdog_timeout() -> void:
	_finish(EXIT_TIMEOUT)


func _on_window_size_changed() -> void:
	LogicalScale.apply(get_window())
