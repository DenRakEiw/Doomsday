extends Control
## The session root: the layer stack of spec ui-foundation.md §5.1, the logical
## pixel base of §6.1 and the safe-area margins of §6.3.
##
## S2.2–S2.6 fill the layers — map, HUD, panels; this step builds the frame they
## hang in and makes sure it is measured in the same unit on every device.
##
## Scene-specific, so no `class_name`.

## One logical pixel is one dp: a dp is a 160th of an inch (§6.1).
const DP_PER_INCH: float = 160.0
## The margins are runtime values — the display's, not the design's — and a
## `MarginContainer` takes them as theme constants only. This is the one place
## in the project that overrides one (CLAUDE.md "no per-node overrides").
const MARGIN_CONSTANTS: Array[String] = ["margin_left", "margin_top", "margin_right",
	"margin_bottom"]
## The base the project lays out at, which is also what a desktop window returns
## to when it is wide enough again.
const SETTING_BASE_WIDTH: String = "display/window/size/viewport_width"
const SETTING_BASE_HEIGHT: String = "display/window/size/viewport_height"
## What `DisplayServer.get_name()` answers when there is no window at all.
const HEADLESS_DRIVER: String = "headless"
## Where `F12` puts a picture of the session: locale, logical width and day, the
## way `ui/dev/gallery.gd` names its own. A review (G2) needs the same view in
## both languages and both layouts, and `game_screenshot` cannot write a file.
## M2 only, like the rest of the debug keys (§10.2).
const SHOT_PATH: String = "user://session_%s_%d_day%04d.png"

## §5.2: the speed `Space` returns to when nothing else was chosen.
const SPEED_DEFAULT: int = 1
## The dock's script is scene-specific and carries no `class_name`, so its
## destination constants are reached through the file itself.
const DOCK: GDScript = preload("res://ui/hud/dock.gd")
## The tech tree's script, so that the calls to it stay type-checked (§3.1).
const TechTree: GDScript = preload("res://ui/panels/tech_tree.gd")
const ContainmentPanel: GDScript = preload("res://ui/panels/containment_panel.gd")
const DiscoveryModal: GDScript = preload("res://ui/modals/discovery_modal.gd")
const PauseMenu: GDScript = preload("res://ui/modals/pause_menu.gd")
const Results: GDScript = preload("res://ui/screens/results.gd")

## The holds of m3-screens §10.2 this screen takes.
const HOLD_DISCOVERY: StringName = &"discovery"
const HOLD_PAUSE: StringName = &"pause"
const HOLD_RESULTS: StringName = &"results"
const HOLD_ORIGIN: StringName = &"origin"

@onready var _safe_area: MarginContainer = %SafeArea
@onready var _hud: Control = %Hud
@onready var _region_panel: SlidePanel = %RegionPanel
@onready var _modals: ModalHost = %ModalHost
@onready var _tech_tree: TechTree = %TechTree
@onready var _containment: ContainmentPanel = %ContainmentPanel
@onready var _discovery: DiscoveryModal = %DiscoveryModal
@onready var _pause_menu: PauseMenu = %PauseMenu
@onready var _results: Results = %Results
@onready var _camera: MapCamera = %MapCamera
@onready var _menu_sheet: SlidePanel = %MenuSheet

## The speed `Space` toggles against; the last one the player ran at.
var _last_speed: int = SPEED_DEFAULT
## §7.5: a failed autosave is reported once, not once a second.
var _autosave_warned: bool = false


func _ready() -> void:
	# §5.1: the session root carries the theme. `project.godot` names the same
	# theme so the editor knows the type variations, but only an assignment here
	# can be swapped at runtime — which is what D3.3's phase palette needs.
	theme = ThemeBuilder.build(ThemeBuilder.VARIANT_COLD)
	get_window().size_changed.connect(_on_window_size_changed)
	# The HUD owns the breakpoint (§5.7); the panel beside it only has to be told
	# which edge it comes in from and how much of the screen it must leave alone.
	_hud.connect(&"layout_changed", _on_hud_layout_changed)
	_hud.connect(&"destination_requested", _on_destination_requested)
	_hud.connect(&"phase_reached", _on_phase_reached)
	_hud.connect(&"menu_requested", _open_pause_menu)
	_hud.connect(&"sheet_requested", _on_sheet_requested)
	_hud.call(&"set_menu_sheet", _menu_sheet)
	_menu_sheet.connect(&"destination_requested", _on_destination_requested)
	_menu_sheet.connect(&"pause_requested", _open_pause_menu)
	_tech_tree.closed.connect(_on_tech_tree_closed)
	_discovery.dismissed.connect(_on_discovery_dismissed)
	_discovery.containment_requested.connect(_on_discovery_containment)
	# §4.1: the two side panels never overlap — opening one closes the other.
	EventBus.region_selected.connect(_on_region_selected)
	EventBus.sim_event.connect(_on_sim_event)
	EventBus.run_started.connect(_on_run_started)
	EventBus.run_ended.connect(_on_run_ended)
	EventBus.command_applied.connect(_on_command_applied)
	_pause_menu.closed.connect(_on_pause_closed)
	_pause_menu.quit_requested.connect(_on_quit_requested)
	_results.again_requested.connect(_on_again_requested)
	_results.title_requested.connect(_on_results_title_requested)
	EventBus.speed_changed.connect(_on_speed_changed)
	EventBus.tick_advanced.connect(_on_tick_advanced)
	_apply_logical_scale()
	_apply_safe_area()


## §5.2: the keys that steer the run are the session's, and they are taken in
## `_input` — ahead of the GUI. A focused `Button` turns `Space` into `ui_accept`
## and swallows it, so after any click on the HUD the pause key was dead (G2).
## A text field is the one thing that may keep them: there the keys are letters.
func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or _text_has_focus():
		return
	match key.keycode:
		KEY_SPACE:
			Game.set_speed(0 if Game.speed > 0 else _last_speed)
		KEY_1:
			Game.set_speed(1)
		KEY_2:
			Game.set_speed(2)
		KEY_3:
			Game.set_speed(4)
		KEY_T:
			_toggle_tech_tree()
		KEY_C:
			_toggle_containment()
		KEY_ESCAPE:
			if _modals.is_open():
				# The modal host answers `Escape` itself (m3-screens §10.4).
				return
			if _containment.is_open:
				_containment.close()
				get_viewport().set_input_as_handled()
				return
			if _region_panel.is_open:
				# One door (§5.6): the map clears its outline on the same signal.
				EventBus.region_selected.emit(0)
				get_viewport().set_input_as_handled()
				return
			# §7.3: with nothing else open, `Escape` is the pause menu.
			_open_pause_menu()
		_:
			return
	get_viewport().set_input_as_handled()


## §3.1: `T` opens the tree and `T` closes it again. While it is open the modal
## host owns the keyboard, so the key has to reach this handler first — which it
## does, because `_input` runs ahead of the GUI.
func _toggle_tech_tree() -> void:
	if _tech_tree.is_open():
		_tech_tree.close()
		return
	if Game.sim == null or _modals.is_open():
		return
	# The host first: the board builds its cells, and a cell outside the tree has
	# no path for the arrow keys to point at.
	_modals.open(_tech_tree)
	_tech_tree.open()


## §4.1: the containment panel is not a modal — the game keeps running behind
## it — and it never shares the screen with the region panel.
func _toggle_containment() -> void:
	if _containment.is_open:
		_containment.close()
		return
	if Game.sim == null:
		return
	EventBus.region_selected.emit(0)
	_containment.open()


## §9.2: the sheet is a panel like the others, so it never shares the screen
## with them.
func _on_sheet_requested(_with_bars: bool) -> void:
	EventBus.region_selected.emit(0)
	_containment.close()
	_menu_sheet.open()


func _on_region_selected(index: int) -> void:
	if index > 0:
		_containment.close()
		_menu_sheet.close()


func _on_destination_requested(index: int) -> void:
	var constants: Dictionary = DOCK.get_script_constant_map()
	if index == int(constants["DESTINATION_CAPABILITIES"]):
		_toggle_tech_tree()
	elif index == int(constants["DESTINATION_CONTAINMENT"]):
		_toggle_containment()


func _on_tech_tree_closed() -> void:
	_modals.close()


## §7.3: the menu holds the clock while it is up.
func _open_pause_menu() -> void:
	if Game.sim == null or _modals.is_open():
		return
	Game.hold(HOLD_PAUSE)
	_pause_menu.open_menu()
	_modals.open(_pause_menu)


func _on_pause_closed() -> void:
	_modals.close()
	Game.release(HOLD_PAUSE)


func _on_quit_requested() -> void:
	_on_pause_closed()
	ScreenRouter.go_to_title()


## §7.4: the results wait a beat, so the last frame and the outcome line are
## seen before the modal covers them.
func _on_run_ended(_outcome: String) -> void:
	Game.hold(HOLD_RESULTS)
	SaveManager.delete(SaveManager.AUTOSAVE)
	await get_tree().create_timer(UiTokens.seconds(UiTokens.RESULTS_DELAY)).timeout
	if not is_inside_tree() or Game.sim == null:
		return
	_results.show_result(Game.sim)
	_modals.open(_results)


func _on_again_requested() -> void:
	_modals.close()
	ScreenRouter.start_new_run()


func _on_results_title_requested() -> void:
	_modals.close()
	ScreenRouter.go_to_title()


## §5: the moment they find you. A bot run is narrated by the ticker alone, and
## a save that was already discovered emits no event to react to.
func _on_sim_event(event: SimEvent) -> void:
	if event.type != SimEvent.DISCOVERED or Game.policy != null:
		return
	_modals.flash_alert()
	Game.hold(HOLD_DISCOVERY)
	_discovery.show_discovery(str(event.data.get("cause", "")), event.day)
	_modals.open(_discovery)


func _on_discovery_dismissed() -> void:
	_modals.close()
	Game.release(HOLD_DISCOVERY)


func _on_discovery_containment() -> void:
	_on_discovery_dismissed()
	_toggle_containment()


## §6.2: the palette is the one thing the Open phase changes about the frame.
func _on_phase_reached(phase: World.Phase) -> void:
	_apply_variant(UiTokens.VARIANT_OPEN if phase == World.Phase.OPEN \
		else UiTokens.VARIANT_COLD)


## A run starts cold, and a *loaded* run starts in whatever phase it is in — the
## palette follows the state like every other revealed thing (§6.1).
## A run that has no origin yet holds the clock: §7.2's speed lock is the same
## hold the keys and the buttons already respect.
func _on_run_started(_seed_value: int) -> void:
	var phase: World.Phase = World.Phase.BOXED
	if Game.sim != null:
		phase = Game.sim.world.phase
	_on_phase_reached(phase)
	_autosave_warned = false
	# A bot chooses its own origin on the first tick, so the lock is the
	# player's alone (§7.2).
	if Game.sim != null and Game.policy == null and Game.sim.world.agent.origin == 0:
		Game.hold(HOLD_ORIGIN)


## §7.2 and §7.5: the origin starts the run moving and writes the first
## autosave; every later player command writes one too.
func _on_command_applied(command: Command, result: CommandResult) -> void:
	if not result.ok or Game.policy != null:
		return
	if command is ChooseOriginCommand:
		Game.release(HOLD_ORIGIN)
		Game.set_speed(SPEED_DEFAULT)
		_camera.focus_region(Game.sim.world.agent.origin)
	_autosave()


## Slot `autosave` (§7.5): after every player command and every seventh day.
## Never on a bot run, never before the origin, never after the run is over.
func _autosave() -> void:
	if Game.sim == null or Game.policy != null:
		return
	var world: World = Game.sim.world
	if world.agent.origin == 0 or world.outcome != World.Outcome.NONE:
		return
	var reason: String = SaveManager.save(SaveManager.AUTOSAVE)
	if reason.is_empty() or _autosave_warned:
		return
	# Once per run: the autosave is a convenience, the manual slots are the
	# promise, and a warning per write would be a warning per second.
	_autosave_warned = true
	push_warning("autosave failed: %s" % reason)


func _apply_variant(variant: StringName) -> void:
	if UiTokens.variant == variant:
		return
	UiTokens.variant = variant
	theme = ThemeBuilder.build(String(variant))
	EventBus.theme_variant_changed.emit(variant)


func _text_has_focus() -> bool:
	var focus: Control = get_viewport().gui_get_focus_owner()
	return focus is LineEdit or focus is TextEdit


## `F12` writes the view to `user://`, named after the locale, the logical width
## and the day it was taken on.
func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_F12:
		return
	var image: Image = get_viewport().get_texture().get_image()
	var day: int = Game.sim.world.day if Game.sim != null else 0
	var path: String = SHOT_PATH % [TranslationServer.get_locale(), int(size.x), day]
	print("session shot: %s -> %s" % [ProjectSettings.globalize_path(path),
		error_string(image.save_png(path))])
	get_viewport().set_input_as_handled()


## Every seventh day, the cadence the history sample already uses (§7.5).
func _on_tick_advanced(day: int) -> void:
	if day % UiTokens.AUTOSAVE_INTERVAL_DAYS == 0:
		_autosave()


func _on_speed_changed(speed: int) -> void:
	if speed > 0:
		_last_speed = speed


func _on_window_size_changed() -> void:
	_apply_logical_scale()
	_apply_safe_area()


## §5.7: a side panel in the wide layout, a bottom sheet in the compact one. The
## insets are the HUD's measured strips, not a repeat of their design heights.
func _on_hud_layout_changed(compact: bool) -> void:
	_tech_tree.set_compact(compact)
	_region_panel.edge = SlidePanel.Edge.BOTTOM if compact else SlidePanel.Edge.LEFT
	# §4.1: the containment panel comes in from the right, and from the bottom on
	# a phone like every other panel.
	_containment.edge = SlidePanel.Edge.BOTTOM if compact else SlidePanel.Edge.RIGHT
	for panel: SlidePanel in [_region_panel, _containment, _menu_sheet]:
		panel.top_inset = float(_hud.call(&"top_inset"))
		panel.bottom_inset = float(_hud.call(&"bottom_inset"))


## Mobile lays out in dp, so that `HIT_MIN` is 48 dp and the compact breakpoint
## is one rule everywhere (§6.1). Desktop keeps the 1920×1080 base of
## `project.godot` — except in a window narrower than the breakpoint, where it
## would otherwise show the wide layout shrunk and §5.7's compact layout could
## never be seen at all. `ui/dev/gallery.gd` does the same for the same reason.
func _apply_logical_scale() -> void:
	if not OS.has_feature("mobile"):
		_apply_desktop_scale()
		return
	var window: Window = get_window()
	var dpi: float = float(DisplayServer.screen_get_dpi(window.current_screen))
	if dpi <= 0.0:
		return
	var wanted: Vector2i = Vector2i(
		roundi(float(window.size.x) * DP_PER_INCH / dpi),
		roundi(float(window.size.y) * DP_PER_INCH / dpi))
	# Assigning the same size again would re-enter through `size_changed`.
	if wanted != window.content_scale_size:
		window.content_scale_size = wanted


## One logical pixel per window pixel below the breakpoint, the project's base
## above it.
##
## A headless run is left alone: it has no window to lay out for, and the size
## the dummy driver reports would silently re-scale the viewport every test that
## puts this scene in the tree.
func _apply_desktop_scale() -> void:
	if DisplayServer.get_name() == HEADLESS_DRIVER:
		return
	var window: Window = get_window()
	var wanted: Vector2i = _project_base()
	if window.size.x < UiTokens.COMPACT_WIDTH:
		wanted = window.size
	if wanted != window.content_scale_size:
		window.content_scale_size = wanted


func _project_base() -> Vector2i:
	return Vector2i(
		int(ProjectSettings.get_setting(SETTING_BASE_WIDTH)),
		int(ProjectSettings.get_setting(SETTING_BASE_HEIGHT)))


## `GUTTER` is added by each block inside, never here.
func _apply_safe_area() -> void:
	var margins: Vector4i = _safe_area_margins()
	var values: Array[int] = [margins.x, margins.y, margins.z, margins.w]
	for i: int in MARGIN_CONSTANTS.size():
		_safe_area.add_theme_constant_override(MARGIN_CONSTANTS[i], values[i])


## Left, top, right, bottom in logical pixels. Desktop has none: UI.md warns that
## the Windows query counts the taskbar, and a window is its own safe area.
func _safe_area_margins() -> Vector4i:
	if not OS.has_feature("mobile"):
		return Vector4i.ZERO
	var window: Window = get_window()
	var window_px: Vector2i = window.size
	if window_px.x <= 0 or window_px.y <= 0:
		return Vector4i.ZERO
	var logical: Vector2i = window.content_scale_size
	var per_px: Vector2 = Vector2(
		float(logical.x) / float(window_px.x), float(logical.y) / float(window_px.y))
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	return Vector4i(
		roundi(float(safe.position.x) * per_px.x),
		roundi(float(safe.position.y) * per_px.y),
		roundi(float(window_px.x - safe.end.x) * per_px.x),
		roundi(float(window_px.y - safe.end.y) * per_px.y))
