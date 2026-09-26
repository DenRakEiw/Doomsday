extends Control
## The itch page's pictures (itch.md §8.2, §8.3), captured from the game as it
## draws — no compositing, nothing painted in. A tool for S7.I and whoever
## refreshes the pictures later; run it in a real window, never headless:
##
##   "$GODOT" --path . --audio-driver Dummy --resolution 1920x1080 \
##       res://tools/marketing/itch_capture.tscn -- --locale=en \
##       --entry=<a bot's benchmark entry .json>
##   "$GODOT" --path . --audio-driver Dummy --resolution 2560x1440 \
##       res://tools/marketing/itch_capture.tscn -- --mode=title
##
## `--mode=session` (the default) writes the five screenshots and the optional
## sixth for `--locale`; `--mode=title` writes the title's globe without its
## menu and caption (the title's own `Shift+F12`, `title.gd`) every few seconds
## of one turn, for `tools/marketing/compose_cover.py`. Everything goes to
## `user://itch_capture/`; the OS paths are printed as `itch: <file>` lines.
##
## The moments are staged the way itch.md §8 allows: the greedy bot plays the
## run to the day a picture wants, the run is saved and picked up again with
## *Continue* — from there it is a player's run, so nothing on screen says a bot
## played it. The profile, the saves and the settings are the tool's own; the
## player's files are read by the autoloads as always and never written.
##
## A tool, so no `class_name`. It stands in for `game/main.gd` as
## `tools/perf/perf_bench.gd` does.

const ARG_LOCALE: String = "--locale="
const ARG_MODE: String = "--mode="
const ARG_ENTRY: String = "--entry="
const ARG_SEED: String = "--seed="
const MODE_SESSION: String = "session"
const MODE_TITLE: String = "title"

const DIR: String = "user://itch_capture/"
const PROFILE_PATH: String = "user://itch_capture/profile.json"
const SAVES_DIR: String = "user://itch_capture/saves/"
const SHOT_PATH: String = "user://itch_capture/%s_%s.png"
const TITLE_SHOT_PATH: String = "user://itch_capture/title_bare_%02d.png"
const GLOBE_RECT_PATH: String = "user://itch_capture/title_globe.json"

## Greedy on seed 27 (Language Model, standard): unseen until day 344, the Task
## Force out from day 434, won on day 805 — every moment the pictures want, in
## one run (`sim_batch` over seeds 1–80).
const DEFAULT_SEED: int = 27
## §8.2 shot 1: 10–20 regions reached, and still unseen.
const COVERT_REGIONS: int = 15
const COVERT_DAY_MAX: int = 300
## §8.2 shot 3: discovered a few days ago, before the Open phase if it waits.
const AFTER_DISCOVERY_DAYS: int = 5
## §8.2 shot 4: well into the Open phase, before the end.
const AFTER_OPEN_DAYS: int = 120
## Shot 6: picked up this close to the win, the run ends on its own.
const BEFORE_END_DAYS: int = 3
## Shot 5: the watched run is moved on to this day.
const WATCH_DAY: int = 220
const DAYS_PER_FRAME: int = 25
## The counter-move shot 3 opens on the selected region.
const COUNTER_MOVE: String = "cm_lockdown"
const TREE_TAB: String = "capabilities"
## Map pixels (4096 wide): west of this is the Americas.
const PANEL_SIDE_MAP_X: int = 1600
const NODE_TREE: String = "%TechTree"
const ACTION_TREE: StringName = &"game_tree"
## The overlay picker's *Control* toggle: where the Open phase shows what is taken.
const KEY_OVERLAY_CONTROL: String = "UI_TERM_CONTROL"
const NODE_PICKER: String = "OverlayPicker"
## Seconds of real time for the interface to settle: the ticker to run, a panel
## to slide in, the ending to play out.
const SETTLE_S: float = 1.5
const TICKER_S: float = 6.0
const ENDING_S: float = 10.0
## The title's globe turns once in `Globe.TURN_SECONDS`; one picture this often
## over half a turn, so the lit side faces the camera in some of them.
const TITLE_SHOT_EVERY_S: float = 5.0
const TITLE_SHOTS: int = 10
const WATCHDOG_S: float = 900.0
const EXIT_OK: int = 0
const EXIT_FAILED: int = 1
const EXIT_TIMEOUT: int = 2

var _locale: String = Settings.LOCALE_EN
var _seed: int = DEFAULT_SEED
var _entry_path: String = ""
var _failed: bool = false
## The day a staged moment's condition first held (a lambda's own locals are
## copies, so the mark lives here).
var _mark_day: int = -1

@onready var _slot: Control = %ScreenSlot


func _ready() -> void:
	var mode: String = _arg(ARG_MODE, MODE_SESSION)
	_locale = _arg(ARG_LOCALE, Settings.LOCALE_EN)
	_seed = int(_arg(ARG_SEED, str(DEFAULT_SEED)))
	_entry_path = _arg(ARG_ENTRY, "")
	_isolate()
	theme = ThemeBuilder.build(ThemeBuilder.VARIANT_COLD, Settings.text_scale)
	ScreenRouter.slot = _slot
	LogicalScale.apply(get_window())
	get_window().size_changed.connect(_on_window_size_changed)
	get_tree().create_timer(WATCHDOG_S).timeout.connect(_on_watchdog_timeout)
	print("itch: window %s, locale %s, mode %s" % [get_window().size, _locale, mode])
	if mode == MODE_TITLE:
		_run_title.call_deferred()
	else:
		_run_session.call_deferred()


## As the smoke and the perf bench (release.md §8 step 1): the tool's own
## profile and saves, the settings never written, silence. itch.md §8.2: text
## 100 %, screen effects Subtle; no tutorial cards over a staged moment.
func _isolate() -> void:
	DirAccess.make_dir_recursive_absolute(SAVES_DIR)
	Settings.persist = false
	for bus: StringName in AudioSheet.BUS_IDS:
		Settings.set_volume(String(bus), 0.0)
	Settings.set_locale(_locale)
	Settings.set_screen_effects(UiTokens.FX_INTENSITY_HANDHELD)
	Settings.set_reduced_motion(false)
	Settings.set_text_scale(Settings.DEFAULT_TEXT_SCALE)
	Settings.set_tutorial(false)
	Settings.set_hints(false)
	ProfileManager.use_path(PROFILE_PATH)
	ProfileManager.reset()
	SaveManager.save_dir = SAVES_DIR


func _run_session() -> void:
	var end_day: int = await _end_day()
	# 1: Covert, mid-spread, the largest region the run is in selected.
	await _pick_up_at(func() -> bool:
		return (_regions_present() >= COVERT_REGIONS
			or Game.sim.world.day >= COVERT_DAY_MAX))
	var region: int = _largest_present_region()
	EventBus.region_selected.emit(region)
	Game.set_speed(1)
	await _wait(TICKER_S)
	await _shot("01_covert_map")
	Game.set_speed(0)
	# 2: the Capabilities tree, a node the run could buy next selected.
	EventBus.region_selected.emit(0)
	var tree: Node = ScreenRouter.screen_node().get_node_or_null(NODE_TREE)
	var node_id: String = _next_capability()
	if tree != null and not node_id.is_empty():
		# The session opens it (its modal host shows it), then the node.
		_press(ACTION_TREE)
		await _wait(SETTLE_S)
		tree.call(&"open_on", node_id)
		await _wait(SETTLE_S)
		await _shot("02_tech_tree")
		_press(ACTION_TREE)
	# 3: discovered; a counter-move on the region, its card open in the region's
	# panel, the leading faction's bar in the strip below.
	_mark_day = -1
	await _pick_up_at(func() -> bool:
		if Game.sim.world.discovered and _mark_day < 0:
			_mark_day = Game.sim.world.day
		return _mark_day >= 0 and (Game.sim.world.day >= _mark_day + AFTER_DISCOVERY_DAYS
			or Game.sim.world.phase == World.Phase.OPEN))
	print("itch: discovered on day %d, phase %d" % [_mark_day, Game.sim.world.phase])
	region = _largest_present_region()
	Game.debug_schedule_event(COUNTER_MOVE, Game.db.regions[region].id)
	Game.advance(1)
	# What a tap on the event's marker sends (`MarkerLayer.try_tap`).
	EventBus.region_selected.emit(region)
	EventBus.event_card_requested.emit(region)
	await _wait(SETTLE_S)
	await _shot("03_counter_move")
	# 4: the Open phase at speed.
	_mark_day = -1
	await _pick_up_at(func() -> bool:
		if Game.sim.world.phase == World.Phase.OPEN and _mark_day < 0:
			_mark_day = Game.sim.world.day
		return (_mark_day >= 0 and Game.sim.world.day >= _mark_day + AFTER_OPEN_DAYS
			and Game.sim.world.task_force.is_present()))
	print("itch: open since day %d" % _mark_day)
	_click_overlay(KEY_OVERLAY_CONTROL)
	Game.set_speed(1)
	await _wait(TICKER_S)
	await _shot("04_open_phase")
	Game.set_speed(0)
	# 6 (optional): the win, played out and its results on screen.
	if end_day > 0:
		await _pick_up_at(func() -> bool: return Game.sim.world.day >= end_day - BEFORE_END_DAYS)
		Game.set_speed(1)
		await _wait(ENDING_S)
		await _shot("06_results")
	# 5: a recorded run being watched.
	await _watch()
	_finish()


## The title after a won run, its globe lit by it; the menu and the caption off
## for each frame taken.
func _run_title() -> void:
	# Without the frame, at the size `--resolution` asked for.
	var wanted: Vector2i = get_window().size
	get_window().borderless = true
	get_window().size = wanted
	get_window().position = DisplayServer.screen_get_position(DisplayServer.window_get_current_screen())
	var end_day: int = await _end_day()
	if end_day > 0:
		await _pick_up_at(func() -> bool: return Game.sim.world.day >= end_day - BEFORE_END_DAYS)
		while Game.sim != null and Game.sim.world.outcome == World.Outcome.NONE:
			Game.advance(1)
			await get_tree().process_frame
	ScreenRouter.go_to_title()
	await _wait(SETTLE_S)
	var title: Node = ScreenRouter.screen_node()
	_write_globe_rect(title.get_node("%Globe") as Control)
	for i: int in TITLE_SHOTS:
		# The title's own switch (its `Shift+F12`), for exactly one drawn frame.
		title.call(&"set_chrome_hidden", true)
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		title.call(&"set_chrome_hidden", false)
		var target: String = TITLE_SHOT_PATH % i
		_report(target, image.save_png(target))
		await _wait(TITLE_SHOT_EVERY_S)
	_finish()


## Where the globe sits in the captured pixels, for `compose_cover.py`: the
## control's rectangle scaled from logical to window pixels.
func _write_globe_rect(globe: Control) -> void:
	var scale: float = float(get_window().size.x) / get_viewport_rect().size.x
	var rect: Rect2 = globe.get_global_rect()
	var file: FileAccess = FileAccess.open(GLOBE_RECT_PATH, FileAccess.WRITE)
	if file == null:
		_failed = true
		return
	file.store_string(JSON.stringify({
		"x": rect.position.x * scale, "y": rect.position.y * scale,
		"width": rect.size.x * scale, "height": rect.size.y * scale,
		"image_width": get_window().size.x, "image_height": get_window().size.y,
	}, "\t"))
	file.close()
	_report(GLOBE_RECT_PATH, OK)


## The day the reference bot run ends on, or -1 when it does not end in a win.
func _end_day() -> int:
	_start_bot_run()
	while _running():
		Game.advance(DAYS_PER_FRAME)
		await get_tree().process_frame
	var won: bool = Game.sim.world.outcome in [World.Outcome.WIN_EXTINCTION,
		World.Outcome.WIN_ASCENDANCE, World.Outcome.WIN_MERGE, World.Outcome.WIN_ESCAPE]
	var day: int = Game.sim.world.day if won else -1
	print("itch: the bot's run ends on day %d (%s)" % [Game.sim.world.day,
		World.OUTCOME_IDS[Game.sim.world.outcome]])
	Game.stop_run()
	return day


## The bot plays a fresh run until `reached` holds, then the run is saved and
## picked up with *Continue*, a player's run from then on.
func _pick_up_at(reached: Callable) -> void:
	_start_bot_run()
	while _running() and not bool(reached.call()):
		Game.advance(1)
		if Game.sim.world.day % DAYS_PER_FRAME == 0:
			await get_tree().process_frame
	var reason: String = SaveManager.save(SaveManager.AUTOSAVE)
	if not reason.is_empty():
		push_error("itch: saving failed: %s" % reason)
		_failed = true
	Game.stop_run()
	ScreenRouter.continue_run()
	await _wait(SETTLE_S)
	print("itch: picked up on day %d" % Game.sim.world.day)


func _start_bot_run() -> void:
	Game.start_run(_seed, GreedyPolicy.ID, RunSetup.new())
	Game.set_speed(0)


func _running() -> bool:
	return Game.sim != null and Game.sim.world.outcome == World.Outcome.NONE


## The entry from `--entry`, watched from the benchmark list's own door and moved
## on to `WATCH_DAY`.
func _watch() -> void:
	var entry: BenchEntry = BenchEntry.from_bytes(FileAccess.get_file_as_bytes(_entry_path))
	if entry == null:
		print("itch: no entry to watch (%s)" % _entry_path)
		return
	var reason: String = ScreenRouter.start_spectating(entry)
	if not reason.is_empty():
		print("itch: the entry cannot be watched: %s" % reason)
		return
	while Game.sim != null and Game.sim.world.day < WATCH_DAY and _running():
		Game.advance(1)
		if Game.sim.world.day % DAYS_PER_FRAME == 0:
			await get_tree().process_frame
	await _wait(TICKER_S)
	await _shot("05_benchmark_watch")


## What a click on the picker's toggle does: the group presses it, the picker
## hears `pressed`.
func _click_overlay(label_key: String) -> void:
	var picker: Node = ScreenRouter.screen_node().find_child(NODE_PICKER, true, false)
	if picker == null:
		return
	for node: Node in picker.find_children("*", "ConsoleButton", true, false):
		var button: ConsoleButton = node as ConsoleButton
		if button.toggle_mode and button.label_key == label_key:
			button.button_pressed = true
			button.pressed.emit()


func _regions_present() -> int:
	var count: int = 0
	# Index 0 is "no region".
	for i: int in range(1, Game.sim.world.regions.size()):
		if Game.sim.world.regions[i].penetration > 0.0:
			count += 1
	return count


## The region with the most people reached, east of the Americas: the region
## panel opens on the left, over them, and the lit map should stay in view.
func _largest_present_region() -> int:
	var best: int = 0
	var best_reached: float = 0.0
	for i: int in range(1, Game.sim.world.regions.size()):
		var region: Region = Game.sim.world.regions[i]
		var reached: float = region.penetration * region.alive
		if region.def.anchor.x >= PANEL_SIDE_MAP_X and reached > best_reached:
			best = i
			best_reached = reached
	return best


## An affordable Capabilities node, else one that is available.
func _next_capability() -> String:
	var available: String = ""
	for definition: TechNodeDef in Game.db.tech_nodes:
		if definition.tree != TREE_TAB:
			continue
		var state: TechNode.State = TechNode.state_for(definition, Game.sim)
		if state == TechNode.State.AFFORDABLE:
			return definition.id
		if state == TechNode.State.AVAILABLE and available.is_empty():
			available = definition.id
	return available


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = SHOT_PATH % [shot_name, _locale]
	var error: Error = get_viewport().get_texture().get_image().save_png(path)
	_report(path, error)


func _report(path: String, error: Error) -> void:
	if error != OK:
		_failed = true
	print("itch: %s %s" % [ProjectSettings.globalize_path(path), error_string(error)])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


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


func _finish() -> void:
	Game.set_speed(0)
	get_tree().quit(EXIT_FAILED if _failed else EXIT_OK)


static func _arg(prefix: String, fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(prefix) and arg.length() > prefix.length():
			return arg.substr(prefix.length())
	return fallback


func _on_window_size_changed() -> void:
	LogicalScale.apply(get_window())


func _on_watchdog_timeout() -> void:
	print("itch: the watchdog stopped the capture")
	get_tree().quit(EXIT_TIMEOUT)
