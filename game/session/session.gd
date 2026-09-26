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
const CodexModal: GDScript = preload("res://ui/modals/codex.gd")
## accessibility.md §4.5, §5.3: the focusable map and the key list.
const MapFocusScript: GDScript = preload("res://game/map/map_focus.gd")
const CONTROLS_SCENE: PackedScene = preload("res://ui/modals/controls.tscn")

## The holds of m3-screens §10.2 this screen takes.
const HOLD_DISCOVERY: StringName = &"discovery"
const HOLD_PAUSE: StringName = &"pause"
const HOLD_RESULTS: StringName = &"results"
const HOLD_ORIGIN: StringName = &"origin"
## `loop-mechanics.md` §16.7: the wire card holds the clock while it is up.
const HOLD_EVENT: StringName = &"event"
## first-run.md §6.7: *How to play* holds the clock while it is read.
const HOLD_HELP: StringName = &"help"
## The keys that open a surface do nothing while the Codex is over it: `T` would
## close the tree under the page instead of the page.
const ACTIONS_BLOCKED_BY_HELP: Array[StringName] = [&"game_tree", &"game_containment",
	&"game_analysis", &"game_abilities"]
## accessibility.md §5.1: the session's actions.
const ACTION_HELP: StringName = &"game_help"
const ACTION_PAUSE: StringName = &"game_pause"
const ACTION_SPEED_1: StringName = &"game_speed_1"
const ACTION_SPEED_2: StringName = &"game_speed_2"
const ACTION_SPEED_3: StringName = &"game_speed_3"
const ACTION_SPEED_CYCLE: StringName = &"game_speed_cycle"
const ACTION_TREE: StringName = &"game_tree"
const ACTION_CONTAINMENT: StringName = &"game_containment"
const ACTION_ANALYSIS: StringName = &"game_analysis"
const ACTION_ABILITIES: StringName = &"game_abilities"
const ACTION_MENU: StringName = &"game_menu"
const ACTION_CANCEL: StringName = &"ui_cancel"
## §4.3: the session's own focus ring — `Tab`/`Shift+Tab`, and the bumpers.
const ACTION_FOCUS_NEXT: StringName = &"ui_focus_next"
const ACTION_FOCUS_PREV: StringName = &"ui_focus_prev"
const ACTION_PAD_NEXT: StringName = &"game_focus_next"
const ACTION_PAD_PREV: StringName = &"game_focus_prev"
## §4.3: with nothing focused, the first of these puts the focus on the map.
const ACTIONS_ARROWS: Array[StringName] = [&"ui_left", &"ui_right", &"ui_up", &"ui_down"]
## §4.7: Y steps paused → 1× → 2× → 4× → 1×.
const SPEED_CYCLE: Dictionary[int, int] = {0: 1, 1: 2, 2: 4, 4: 1}
## §4.1: a stick counts as the player's hands on the pad past this deflection.
const PAD_MOTION_THRESHOLD: float = 0.5

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
@onready var _codex: CodexModal = %Codex
@onready var _hud_layer: CanvasLayer = $HudLayer
@onready var _marker_layer: Node2D = $MapLayer/MarkerLayer

## accessibility.md §4.5: the map as one focusable control.
var map_focus: MapFocusScript = null
var _controls: Control = null

## accessibility.md §4.1: the player is on the keyboard or a pad rather than a
## pointer. A key or a pad button sets it, a click or a touch clears it; it
## decides whether a panel takes the focus and whether the map cursor shows.
var keyboard_mode: bool = false

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
	_coach.set(&"modals", _modals)
	_hud.set(&"side_panel", _region_panel)
	_build_map_focus()
	# accessibility.md §4.4 item 3: a hint about the open tree can be read and
	# put away without leaving it.
	_modals.companions = [_coach] as Array[Control]
	_controls = CONTROLS_SCENE.instantiate() as Control
	_modals.add_child(_controls)
	_controls.connect(&"closed", _close_controls)
	_pause_menu.connect(&"controls_requested", _open_controls)
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
	_codex.closed.connect(close_help)
	# The coach asks whether help is up (first-run.md §6.7).
	_codex.add_to_group(CoachRing.group(CoachRing.TARGET_HELP))
	EventBus.help_requested.connect(open_help)
	EventBus.platform_overlay_opened.connect(_on_platform_overlay_opened)
	EventBus.page_hidden.connect(_on_page_hidden)
	EventBus.speed_changed.connect(_on_speed_changed)
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.text_scale_changed.connect(_on_text_scale_changed)
	_apply_logical_scale()
	_apply_safe_area()


## §5.2: the keys that steer the run are the session's, and they are taken in
## `_input` — ahead of the GUI. A focused `Button` turns `Space` into `ui_accept`
## and swallows it, so after any click on the HUD the pause key was dead (G2).
## A text field is the one thing that may keep them: there the keys are letters.
## Since S6.8 they are actions (accessibility.md §5.1), so a remapped key and a
## pad button run the same code.
func _input(event: InputEvent) -> void:
	_track_input_mode(event)
	if not event.is_pressed() or event.is_echo() or _text_has_focus():
		return
	if is_help_open() and _any_action(event, ACTIONS_BLOCKED_BY_HELP):
		get_viewport().set_input_as_handled()
		return
	# §4.3: the ring is the session's while no modal is up; a modal walks its own.
	if not _modals.is_open() and _step_focus(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(ACTION_HELP):
		# first-run.md §6.7: the page for what is on top; again, and it closes.
		if is_help_open():
			close_help()
		else:
			open_help(HelpPages.page_for_context(help_context()))
	elif event.is_action_pressed(ACTION_PAUSE):
		Game.set_speed(0 if Game.speed > 0 else _last_speed)
	elif event.is_action_pressed(ACTION_SPEED_1):
		Game.set_speed(1)
	elif event.is_action_pressed(ACTION_SPEED_2):
		Game.set_speed(2)
	elif event.is_action_pressed(ACTION_SPEED_3):
		Game.set_speed(4)
	elif event.is_action_pressed(ACTION_SPEED_CYCLE):
		Game.set_speed(int(SPEED_CYCLE.get(Game.speed, SPEED_DEFAULT)))
	elif event.is_action_pressed(ACTION_TREE):
		_toggle_tech_tree()
	elif event.is_action_pressed(ACTION_CONTAINMENT):
		_toggle_containment()
	elif event.is_action_pressed(ACTION_ANALYSIS):
		_toggle_analysis()
	elif event.is_action_pressed(ACTION_ABILITIES):
		_toggle_ability_picker()
	elif event.is_action_pressed(ACTION_MENU):
		# §4.7: Start opens the pause menu and closes it again.
		if _modals.current() == _pause_menu:
			_pause_menu.call(&"on_escape")
		else:
			_open_pause_menu()
	elif Game.debug_allowed and event is InputEventKey \
			and (event as InputEventKey).keycode == KEY_V:
		# polish-visuals.md §5.1: Off → Subtle → Full, for review. A debug key,
		# not an action (accessibility.md §5.1); none in a release build (release.md §7).
		Settings.cycle_screen_effects()
		print("screen effects: %s" % Settings.screen_effects)
	elif event.is_action_pressed(ACTION_CANCEL):
		if not _on_cancel():
			return
	else:
		return
	get_viewport().set_input_as_handled()


## The `Escape` chain (§4.7: B on a pad): false when the modal host answers it.
func _on_cancel() -> bool:
	if _modals.is_open():
		# The modal host answers `Escape` itself (m3-screens §10.4).
		return false
	# `Escape` leaves site select (`loop-mechanics.md` §16.1) — except the
	# origin's, which cannot be cancelled: there is nothing behind the run's first
	# decision, so the key goes on to the pause menu.
	if Game.is_selecting_site() and Game.site_request.can_cancel():
		Game.site_cancel()
	elif _containment.is_open:
		_containment.close()
	elif _analysis.is_open:
		_analysis.close()
	elif _menu_sheet.is_open:
		# The phone's menu sheet is a panel like the others (m3-screens §9.2).
		_menu_sheet.close()
	elif _region_panel.is_open:
		# One door (§5.6): the map clears its outline on the same signal.
		EventBus.region_selected.emit(0)
	else:
		# §7.3: with nothing else open, `Escape` is the pause menu.
		_open_pause_menu()
	return true


static func _any_action(event: InputEvent, actions: Array[StringName]) -> bool:
	for action: StringName in actions:
		if event.is_action_pressed(action):
			return true
	return false


## accessibility.md §4.1: which hands are on the game.
func _track_input_mode(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		if event.is_pressed():
			_set_keyboard_mode(false)
		return
	if event is InputEventKey or event is InputEventJoypadButton:
		if event.is_pressed():
			_set_keyboard_mode(true)
		return
	var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
	if motion != null and absf(motion.axis_value) > PAD_MOTION_THRESHOLD:
		_set_keyboard_mode(true)


func _set_keyboard_mode(value: bool) -> void:
	if value == keyboard_mode:
		return
	keyboard_mode = value
	EventBus.keyboard_mode_changed.emit(value)


## §4.3: `Tab`/`Shift+Tab` (and the bumpers) walk the zones in order; with
## nothing focused, an arrow key puts the focus on the map. True when taken.
func _step_focus(event: InputEvent) -> bool:
	var backwards: bool = event.is_action_pressed(ACTION_FOCUS_PREV, false, true) \
		or event.is_action_pressed(ACTION_PAD_PREV)
	var forwards: bool = event.is_action_pressed(ACTION_FOCUS_NEXT, false, true) \
		or event.is_action_pressed(ACTION_PAD_NEXT)
	if backwards or forwards:
		var target: Control = FocusRing.next(focus_chain(),
			get_viewport().gui_get_focus_owner(), backwards)
		if target != null:
			target.grab_focus()
		return true
	var key: InputEventKey = event as InputEventKey
	if get_viewport().gui_get_focus_owner() == null and _any_action(event, ACTIONS_ARROWS) \
			and not (key != null and key.shift_pressed):
		map_focus.grab_focus()
		map_focus.step(Vector2.ZERO)
		return true
	return false


## §4.3's zones, in order: the top bar; the left column and the coach; the dock
## or the status strip; the map; the site prompt; the region panel; the open one
## of containment, analysis and the menu sheet. A hidden zone adds nothing, and
## neither does a HUD zone an open panel covers by more than half (D6.8: the
## overlay picker under the region panel).
func focus_chain() -> Array[Control]:
	var zones: Array[Control] = _hud.call(&"focus_zones")
	var prompt: Control = _hud.call(&"site_prompt") as Control
	var covers: Array[Rect2] = []
	for panel: SlidePanel in [_region_panel, _containment, _menu_sheet, _analysis]:
		if panel.is_open:
			covers.append(panel.covered_rect())
	var hud_zones: Array[Control] = zones.duplicate()
	hud_zones.append(prompt)
	var covered: Array[Control] = []
	for zone: Control in hud_zones:
		if zone != null and zone.is_visible_in_tree() \
				and FocusRing.is_covered(zone.get_global_rect(), covers):
			covered.append(zone)
	var roots: Array[Control] = []
	for root: Control in [zones[0], zones[1], _coach, zones[2], zones[3], map_focus, prompt,
			_region_panel, _containment, _analysis, _menu_sheet]:
		if not covered.has(root):
			roots.append(root)
	return FocusRing.collect(roots)


## accessibility.md §4.5: the focusable map sits behind every HUD control, and a
## panel closed from the keyboard with its opener gone gives the focus back here.
func _build_map_focus() -> void:
	map_focus = MapFocusScript.new()
	map_focus.name = "MapFocus"
	_hud_layer.add_child(map_focus)
	_hud_layer.move_child(map_focus, 0)
	map_focus.markers = _marker_layer
	map_focus.camera = _camera
	map_focus.map_view = _map_view
	map_focus.region_panel = _region_panel
	for panel: SlidePanel in [_region_panel, _containment, _menu_sheet, _analysis]:
		panel.focus_fallback = map_focus


## accessibility.md §5.3: over the settings, which it goes back to.
func _open_controls() -> void:
	_controls.call(&"open")
	_modals.open_over(_controls)


func _close_controls() -> void:
	if _modals.current() == _controls:
		_modals.close()
	_controls.visible = false


## first-run.md §6.7: the Codex on *How to play*, on `page` ("" = the first),
## over whatever modal is up — it comes back when the Codex closes. It holds the
## clock. Already up, it only turns to `page`.
func open_help(page: String = "") -> void:
	if Game.sim == null:
		return
	_codex.open(CodexEntries.TAB_HELP, page)
	if is_help_open():
		return
	Game.hold(HOLD_HELP)
	_modals.open_over(_codex)


func close_help() -> void:
	if _modals.current() == _codex:
		_modals.close()
	_codex.visible = false
	Game.release(HOLD_HELP)


func is_help_open() -> bool:
	return _modals.current() == _codex


## §6.7: the surface `F1` asks about — the modal on top when it has a page of
## its own, else the panel that is open, else the session's page.
func help_context() -> String:
	if _modals.is_open():
		if _modals.current() == _tech_tree:
			return HelpPages.CONTEXT_TREE
		if _modals.current() == _ability_picker:
			return HelpPages.CONTEXT_ABILITIES
		return HelpPages.CONTEXT_SESSION
	if _containment.is_open:
		return HelpPages.CONTEXT_CONTAINMENT
	if _analysis.is_open:
		return HelpPages.CONTEXT_ANALYSIS
	if _region_panel.is_open:
		return HelpPages.CONTEXT_REGION
	return HelpPages.CONTEXT_SESSION


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
	_containment.open(keyboard_mode)


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
	_analysis.open(keyboard_mode)


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
	_menu_sheet.open(keyboard_mode)


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


## release.md §1.3: the platform's overlay over a live run pauses it exactly as
## the menu key does. After the outcome, or under a modal, nothing changes.
func _on_platform_overlay_opened() -> void:
	if Game.sim == null or Game.sim.world.outcome != World.Outcome.NONE:
		return
	_open_pause_menu()


## web.md §6.3: the browser stops a hidden page's frames, and at the return the
## clock would take many days in one frame — so the player's live run is saved
## and paused as the menu key pauses it. A watched run, a bot's, a run before
## its origin or after its outcome goes on untouched.
func _on_page_hidden() -> void:
	if Game.sim == null or Game.policy != null:
		return
	var world: World = Game.sim.world
	if world.agent.origin == 0 or world.outcome != World.Outcome.NONE:
		return
	_autosave()
	_open_pause_menu()


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
	# benchmark.md §12.4: only the player's own run ends their autosave — a bot
	# run (the debug keys) or a watched one leaves it where it was.
	if Game.policy == null:
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
	_results.show_unlocks(architectures, slots, codex_new,
		ProfileManager.last_run_achievements)
	if Game.is_spectating():
		_show_spectator_result()
	_modals.open(_results)


## §12.6: whether the replay reached the recording — the same end hash and no
## command refused or missed on the way.
func _show_spectator_result() -> void:
	var replay: ReplayPolicy = Game.spectator()
	var verified: bool = replay.diverged_day < 0 \
		and Game.sim.state_hash() == replay.entry.state_hash
	_results.show_spectator(replay.entry, verified, replay.diverged_day)


## Whether the results are the modal on top — the smoke run's end (release.md §8).
func results_open() -> bool:
	return _modals.current() == _results


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


## §12.4: *Watch again* replays the same entry; otherwise *Again* is a new run.
func _on_again_requested() -> void:
	_modals.close()
	if Game.is_spectating():
		ScreenRouter.start_spectating(Game.spectator().entry)
		return
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
		# accessibility.md §4.3: the run's first question is asked on the map.
		if is_inside_tree():
			map_focus.grab_focus.call_deferred()


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
	# release.md §7: a debug key; in a release build F12 stays Steam's.
	if not Game.debug_allowed or key == null or not key.pressed or key.echo \
			or key.keycode != KEY_F12:
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
	# The coach sits on its own layer, outside the margin container (D6.8).
	_coach.set(&"safe_top", float(margins.y))


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
