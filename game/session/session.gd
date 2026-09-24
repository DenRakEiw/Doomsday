extends Control
## The session root: the layer stack of spec ui-foundation.md §5.1, the logical
## pixel base of §6.1 and the safe-area margins of §6.3.
##
## S2.2–S2.6 fill the layers — map, HUD, panels; this step builds the frame they
## hang in and makes sure it is measured in the same unit on every device.
##
## Scene-specific, so no `class_name`.

## The margins are runtime values — the display's, not the design's — and a
## `MarginContainer` takes them as theme constants only. This is the one place
## in the project that overrides one (CLAUDE.md "no per-node overrides").
const MARGIN_CONSTANTS: Array[String] = ["margin_left", "margin_top", "margin_right",
	"margin_bottom"]
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
const AnalysisPanel: GDScript = preload("res://ui/panels/analysis_panel.gd")

## The holds of m3-screens §10.2 this screen takes.
const HOLD_DISCOVERY: StringName = &"discovery"
const HOLD_PAUSE: StringName = &"pause"
const HOLD_RESULTS: StringName = &"results"
const HOLD_ORIGIN: StringName = &"origin"
## `loop-mechanics.md` §16.7: the wire card holds the clock while it is up.
const HOLD_EVENT: StringName = &"event"

@onready var _safe_area: MarginContainer = %SafeArea
@onready var _hud: Control = %Hud
@onready var _coach: PanelContainer = %Coach
@onready var _coach_ring: CoachRing = %CoachRing
@onready var _region_panel: SlidePanel = %RegionPanel
@onready var _modals: ModalHost = %ModalHost
@onready var _tech_tree: TechTree = %TechTree
@onready var _containment: ContainmentPanel = %ContainmentPanel
@onready var _discovery: DiscoveryModal = %DiscoveryModal
@onready var _pause_menu: PauseMenu = %PauseMenu
@onready var _ability_picker: Control = %AbilityPicker
@onready var _wire: WireCard = %WireCard
@onready var _results: Results = %Results
@onready var _camera: MapCamera = %MapCamera
@onready var _map_view: MapView = $MapLayer/MapView
@onready var _menu_sheet: SlidePanel = %MenuSheet
@onready var _analysis: AnalysisPanel = %AnalysisPanel

## The speed `Space` toggles against; the last one the player ran at.
var _last_speed: int = SPEED_DEFAULT
## §7.5: a failed autosave is reported once, not once a second.
var _autosave_warned: bool = false
## Events waiting for the wire card while it shows another, oldest first.
var _wire_queue: Array[int] = []
## screens-full.md §5.1: what this run adds to the Codex.
var _codex_tracker: CodexTracker = null
## §7 item 4a: what was unlocked when the run started, to tell at its end what
## it unlocked.
var _architectures_before: Array[String] = []
var _slots_before: int = 0


func _ready() -> void:
	# §5.1: the session root carries the theme. `project.godot` names the same
	# theme so the editor knows the type variations, but only an assignment here
	# can be swapped at runtime — which is what D3.3's phase palette needs.
	_set_theme(ThemeBuilder.build(ThemeBuilder.VARIANT_COLD, Settings.text_scale))
	# first-run.md §3: the introduction sits above everything and moves the ring.
	_coach.set(&"ring", _coach_ring)
	_coach.set(&"hud", _hud)
	_codex_tracker = CodexTracker.new()
	_codex_tracker.name = "CodexTracker"
	add_child(_codex_tracker)
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
	_menu_sheet.connect(&"abilities_requested", _toggle_ability_picker)
	_ability_picker.connect(&"closed", _close_ability_picker)
	_tech_tree.closed.connect(_on_tech_tree_closed)
	_tech_tree.reopen_requested.connect(_on_tech_tree_reopen_requested)
	_discovery.dismissed.connect(_on_discovery_dismissed)
	_discovery.containment_requested.connect(_on_discovery_containment)
	_wire.closed.connect(_on_wire_closed)
	EventBus.wire_requested.connect(_open_wire)
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
	_results.review_requested.connect(_on_results_review_requested)
	_analysis.back_requested.connect(_on_analysis_back)
	EventBus.speed_changed.connect(_on_speed_changed)
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.text_scale_changed.connect(_on_text_scale_changed)
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
		KEY_G:
			_toggle_analysis()
		KEY_A:
			_toggle_ability_picker()
		KEY_ESCAPE:
			if _modals.is_open():
				# The modal host answers `Escape` itself (m3-screens §10.4).
				return
			# `Escape` leaves site select (`loop-mechanics.md` §16.1) — except
			# the origin's, which cannot be cancelled: there is nothing behind
			# the run's first decision, so the key goes on to the pause menu.
			if Game.is_selecting_site() and Game.site_request.can_cancel():
				Game.site_cancel()
				get_viewport().set_input_as_handled()
				return
			if _containment.is_open:
				_containment.close()
				get_viewport().set_input_as_handled()
				return
			if _analysis.is_open:
				_analysis.close()
				get_viewport().set_input_as_handled()
				return
			# The phone's menu sheet is a panel like the others (m3-screens §9.2);
			# only its × closed it until S4.P.
			if _menu_sheet.is_open:
				_menu_sheet.close()
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


## The tree comes back where the player left it when a deploy site was not
## chosen after all (`loop-mechanics.md` §16.1).
func _on_tech_tree_reopen_requested(node_id: String) -> void:
	if Game.sim == null or _modals.is_open():
		return
	_modals.open(_tech_tree)
	_tech_tree.open_on(node_id)


## §16.10: `A` opens the picker and `A` closes it again. It holds no clock —
## the run keeps going while the player reads their own verbs.
func _toggle_ability_picker() -> void:
	if _ability_picker.visible:
		_close_ability_picker()
		return
	if Game.sim == null or _modals.is_open():
		return
	_ability_picker.call(&"refresh")
	_modals.open(_ability_picker)


func _close_ability_picker() -> void:
	_modals.close()


## §4.1: the containment panel is not a modal — the game keeps running behind
## it — and it never shares the screen with the region panel.
func _toggle_containment() -> void:
	if _containment.is_open:
		_containment.close()
		return
	if Game.sim == null:
		return
	EventBus.region_selected.emit(0)
	_analysis.close()
	_containment.open()


## analysis.md §5.1: the sheet over the live map; `G` opens and closes it, and
## it never shares the screen with the other two panels.
func _toggle_analysis() -> void:
	if _analysis.is_open:
		_analysis.close()
		return
	if Game.sim == null or _modals.is_open():
		return
	EventBus.region_selected.emit(0)
	_containment.close()
	_menu_sheet.close()
	_analysis.open()


## §5.9: the results step aside for the sheet, the hold stays.
func _on_results_review_requested() -> void:
	_modals.close()
	_analysis.open_review()


func _on_analysis_back() -> void:
	if Game.sim != null and Game.sim.world.outcome != World.Outcome.NONE:
		_modals.open(_results)


## §9.2: the sheet is a panel like the others, so it never shares the screen
## with them.
func _on_sheet_requested(_with_bars: bool) -> void:
	EventBus.region_selected.emit(0)
	_containment.close()
	_analysis.close()
	_menu_sheet.open()


func _on_region_selected(index: int) -> void:
	if index > 0:
		_containment.close()
		_menu_sheet.close()
		_analysis.close()


func _on_destination_requested(index: int) -> void:
	var constants: Dictionary = DOCK.get_script_constant_map()
	if index == int(constants["DESTINATION_CAPABILITIES"]):
		_toggle_tech_tree()
	elif index == int(constants["DESTINATION_CONTAINMENT"]):
		_toggle_containment()
	elif index == int(constants["DESTINATION_ANALYSIS"]):
		_toggle_analysis()


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


## screens-full.md §7: the ending sequence. The camera pushes in to where the
## run ended and holds there (G5 1/3), then pulls out to the whole world on the
## penetration view while the last headline runs, the map taking no input; then
## the results. A camera already there waits the old beat, so the last frame
## and the outcome line are seen before the modal covers them. Reduced motion
## skips the push and the hold and cuts to the whole world.
## The profile has counted the run already (`ProfileManager` hears the signal
## first), so what it unlocked is the difference to the run's start.
func _on_run_ended(_outcome: String) -> void:
	Game.hold(HOLD_RESULTS)
	SaveManager.delete(SaveManager.AUTOSAVE)
	var codex_new: int = 0 if Game.policy != null else _codex_tracker.new_count()
	_codex_tracker.merge()
	var architectures: Array[String] = _new_architectures()
	var slots: Array[String] = _new_slots()
	EventBus.overlay_changed.emit(int(MapView.Overlay.PENETRATION))
	if not UiTokens.reduced_motion():
		var region: int = ending_region(Game.sim.world, Game.db)
		var push: float = _camera.push_in(region, UiTokens.duration(UiTokens.ENDING_PUSH))
		_map_view.hover_index = region
		await get_tree().create_timer(push + UiTokens.seconds(UiTokens.ENDING_HOLD)).timeout
		if not is_inside_tree() or Game.sim == null:
			return
		_map_view.hover_index = 0
	var pull: float = _camera.pull_out(UiTokens.duration(UiTokens.ENDING_PULL))
	var wait: float = pull if pull > 0.0 else UiTokens.seconds(UiTokens.RESULTS_DELAY)
	await get_tree().create_timer(wait).timeout
	if not is_inside_tree() or Game.sim == null:
		return
	_camera.input_locked = false
	_results.show_result(Game.sim)
	_results.show_unlocks(architectures, slots, codex_new)
	_modals.open(_results)


## §7 beat 2a: where the run ended — the region of the newest run-log entry
## that names one (the last wipe, the team's last action, the last region
## taken), or the origin when none does.
static func ending_region(world: World, db: ContentDB) -> int:
	for i: int in range(world.run_log.size() - 1, -1, -1):
		var index: int = RunLogText.region_index(world.run_log[i], db)
		if index > 0:
			return index
	return world.agent.origin


## The architectures a player's run has unlocked since it started.
func _new_architectures() -> Array[String]:
	var out: Array[String] = []
	if Game.policy != null or Game.db == null:
		return out
	for id: String in _unlocked_architectures():
		if not _architectures_before.has(id):
			out.append(id)
	return out


## The directive slots a player's run has opened since it started.
func _new_slots() -> Array[String]:
	var out: Array[String] = []
	if Game.policy != null or Game.db == null:
		return out
	var slots: Array[String] = Game.db.directive_slots
	for i: int in range(_slots_before, ProfileManager.slots_unlocked(slots.size())):
		out.append(slots[i])
	return out


func _unlocked_architectures() -> Array[String]:
	var out: Array[String] = []
	for def: ArchitectureDef in Game.db.architectures:
		if ProfileManager.is_unlocked(def):
			out.append(def.id)
	return out


func _on_again_requested() -> void:
	_modals.close()
	ScreenRouter.start_new_run()


func _on_results_title_requested() -> void:
	_modals.close()
	ScreenRouter.go_to_title()


## §5: the moment they find you. A bot run is narrated by the ticker alone, and
## a save that was already discovered emits no event to react to.
func _on_sim_event(event: SimEvent) -> void:
	if event.type == SimEvent.EVENT_OPENED:
		_on_event_opened(event)
		return
	if event.type != SimEvent.DISCOVERED or Game.policy != null:
		return
	_modals.flash_alert()
	Game.hold(HOLD_DISCOVERY)
	_discovery.show_discovery(str(event.data.get("cause", "")), event.day)
	_modals.open(_discovery)


## §16.7: a global event, or one that asks for the card, opens the wire card —
## except in a bot run, where the bot answers or the deadline does.
func _on_event_opened(event: SimEvent) -> void:
	if Game.policy != null:
		return
	if not bool(event.data.get("modal", false)) and not str(event.data.get("region", "")).is_empty():
		return
	_open_wire(int(event.data.get("event", 0)))


func _open_wire(event_id: int) -> void:
	if Game.sim == null or Game.sim.world.event_by_id(event_id) == null:
		return
	if _wire.visible or _modals.current() == _wire:
		if _wire.event_id() != event_id and not _wire_queue.has(event_id):
			_wire_queue.append(event_id)
		return
	if not _wire.show_event(event_id):
		return
	Game.hold(HOLD_EVENT)
	_modals.open(_wire)


func _on_wire_closed() -> void:
	if _modals.current() == _wire:
		_modals.close()
	_wire.visible = false
	Game.release(HOLD_EVENT)
	while not _wire_queue.is_empty():
		var next: int = _wire_queue.pop_front()
		if Game.sim != null and Game.sim.world.event_by_id(next) != null:
			_open_wire(next)
			return


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
	if Game.db != null:
		_architectures_before = _unlocked_architectures()
		_slots_before = ProfileManager.slots_unlocked(Game.db.directive_slots.size())
	# A bot chooses its own origin on the first tick, so the lock is the
	# player's alone (§7.2).
	if Game.sim != null and Game.policy == null and Game.sim.world.agent.origin == 0:
		Game.hold(HOLD_ORIGIN)
		Game.site_select(SiteRequest.for_origin())


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
	if reason.is_empty():
		# §5.1: the Codex is written with every autosave, so a crash loses at
		# most what the save does.
		_codex_tracker.merge()
		return
	if _autosave_warned:
		return
	# Once per run: the autosave is a convenience, the manual slots are the
	# promise, and a warning per write would be a warning per second.
	_autosave_warned = true
	push_warning("autosave failed: %s" % reason)


func _apply_variant(variant: StringName) -> void:
	if UiTokens.variant == variant:
		return
	UiTokens.variant = variant
	_set_theme(ThemeBuilder.build(String(variant), Settings.text_scale))
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


## UI.md §5: the palette stays, the type grows.
func _on_text_scale_changed(scale: float) -> void:
	_set_theme(ThemeBuilder.build(String(UiTokens.variant), scale))


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
	_analysis.compact = compact
	for panel: SlidePanel in [_region_panel, _containment, _menu_sheet, _analysis]:
		panel.top_inset = float(_hud.call(&"top_inset"))
		panel.bottom_inset = float(_hud.call(&"bottom_inset"))


## §6.1: the logical pixel, shared with the other screens since S5.7.
func _apply_logical_scale() -> void:
	LogicalScale.apply(get_window())


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


## A `CanvasLayer` ends theme inheritance: a control under one looks for its
## theme among the controls above it inside the layer, then falls back to the
## project theme. So the session hands its theme to the top controls of every
## layer — without that, the phase palette and the text scale reached nothing
## but the session root (found in S4.9's screenshots).
func _set_theme(value: Theme) -> void:
	theme = value
	for layer: Node in get_children():
		if not layer is CanvasLayer:
			continue
		for child: Node in layer.get_children():
			if child is Control:
				(child as Control).theme = value
