extends GutTest
## S7.IP (seen in S6.P4) — a row of toggles chosen by the code draws one choice,
## not the new one beside the old: the Codex's tabs, the setup's difficulty, the
## tech tree's tab on `open_on`, and the overlay picker when a phase takes its
## mode away. `set_pressed_no_signal` releases nothing in a `ButtonGroup`; only a
## click does (`ToggleGroup.press`). Through the game's own main scene, the first
## choice made by a real click.
##
## The seed is fixed (`SEED`).

const MAIN: PackedScene = preload("res://game/main.tscn")
const SEED: int = 7
const ORIGIN: String = "france"
const WINDOW_FHD: Vector2i = Vector2i(1920, 1080)
## A capability: `open_on` switches the tree from its first tab to this one's.
const CAPABILITY: String = "distributed_synthesis"
const CAPABILITIES_TAB: int = 1

var _window_size: Vector2i = Vector2i.ZERO
var _gut_layer: CanvasLayer = null
var _tutorial: bool = true
var _hints: bool = true
var _reduced_motion: bool = false
var _boot_seen: bool = false
var _locale: String = ""


func before_each() -> void:
	_tutorial = Settings.tutorial
	_hints = Settings.hints
	_reduced_motion = Settings.reduced_motion
	_boot_seen = ProfileManager.boot_seen
	_locale = TranslationServer.get_locale()
	Settings.reduced_motion = true
	ProfileManager.clear_hints_seen()
	Game.stop_run()
	Game.debug_log = false
	_window_size = get_window().size
	# GUT's own panel sits on a layer above the game and would take the clicks.
	_gut_layer = get_tree().root.find_child("GutLayer", true, false) as CanvasLayer
	if _gut_layer != null:
		_gut_layer.visible = false


func after_each() -> void:
	if _gut_layer != null:
		_gut_layer.visible = true
	get_window().size = _window_size
	ScreenRouter.slot = null
	# Assigned, not set: nothing here may write the player's settings file.
	Settings.tutorial = _tutorial
	Settings.hints = _hints
	Settings.reduced_motion = _reduced_motion
	ProfileManager.clear_hints_seen()
	ProfileManager.boot_seen = _boot_seen
	TranslationServer.set_locale(_locale)
	Game.stop_run()


func _launch() -> void:
	Settings.tutorial = false
	Settings.hints = false
	TranslationServer.set_locale("en")
	get_window().size = WINDOW_FHD
	add_child_autofree(MAIN.instantiate())
	await wait_process_frames(3)


func _push(event: InputEvent, at: Vector2) -> void:
	var mouse: InputEventMouse = event as InputEventMouse
	if mouse != null:
		# `push_input` takes window pixels; the controls answer in the viewport's.
		var window_at: Vector2 = get_viewport().get_final_transform() * at
		mouse.position = window_at
		mouse.global_position = window_at
	get_viewport().push_input(event)


## Clicks the centre of `control`; "" when the pointer reached it.
func _click_control(control: Control) -> String:
	var at: Vector2 = control.get_global_rect().get_center()
	_push(InputEventMouseMotion.new(), at)
	await wait_process_frames(1)
	var over: Control = get_viewport().gui_get_hovered_control()
	for pressed: bool in [true, false]:
		var button: InputEventMouseButton = InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = pressed
		button.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		_push(button, at)
		await wait_process_frames(1)
	if over == null or (over != control and not control.is_ancestor_of(over)):
		return "the pointer at %s was taken by %s" % [at, over]
	return ""


func _key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var key: InputEventKey = InputEventKey.new()
		key.keycode = keycode
		key.physical_keycode = keycode
		key.pressed = pressed
		get_viewport().push_input(key)
		await wait_process_frames(1)


static func _pressed(buttons: Array) -> Array[BaseButton]:
	var out: Array[BaseButton] = []
	for button: Variant in buttons:
		if (button as BaseButton).button_pressed:
			out.append(button as BaseButton)
	return out


func test_a_codex_tab_chosen_by_the_code_is_the_only_one_drawn_pressed() -> void:
	await _launch()
	ScreenRouter.go_to_title()
	await wait_process_frames(3)
	var title: Node = ScreenRouter.screen_node()
	# Taken before it opens: the modal host moves it into its slot.
	var codex: Node = title.get_node("%Codex")
	assert_eq(await _click_control(title.get_node("%CodexButton") as Control), "",
		"the click reached the Codex")
	await wait_process_frames(3)
	var tabs: Dictionary = codex.get(&"_tab_buttons")
	assert_eq(await _click_control(tabs[CodexEntries.TAB_REGIONS] as Control), "",
		"the click reached the Regions tab")
	codex.call(&"show_tab", CodexEntries.TAB_FACTIONS)
	await wait_process_frames(2)
	assert_eq(_pressed(tabs.values()), [tabs[CodexEntries.TAB_FACTIONS]] as Array[BaseButton],
		"Factions alone")
	assert_eq(get_viewport().gui_get_focus_owner(), tabs[CodexEntries.TAB_FACTIONS],
		"the focus ring went along")
	codex.call(&"open", CodexEntries.TAB_ENDINGS)
	await wait_process_frames(2)
	assert_eq(_pressed(tabs.values()), [tabs[CodexEntries.TAB_ENDINGS]] as Array[BaseButton],
		"Endings alone")


func test_a_difficulty_chosen_by_the_code_is_the_only_one_drawn_pressed() -> void:
	await _launch()
	ScreenRouter.show_setup()
	await wait_process_frames(3)
	var setup: Node = ScreenRouter.screen_node()
	var buttons: Dictionary = setup.get(&"_difficulty_buttons")
	var ids: Array = buttons.keys()
	assert_gt(ids.size(), 1, "more than one tier to choose from")
	var first: Control = buttons[ids[0]] as Control
	assert_eq(await _click_control(first), "", "the click reached the first tier")
	setup.call(&"select_difficulty", str(ids[ids.size() - 1]))
	await wait_process_frames(2)
	assert_eq(_pressed(buttons.values()), [buttons[ids[ids.size() - 1]]] as Array[BaseButton])


func test_the_tree_opened_on_a_node_elsewhere_moves_tab_and_focus_along() -> void:
	await _launch()
	ScreenRouter.start_new_run(null, SEED)
	Game.set_speed(0)
	await wait_process_frames(2)
	var session: Node = ScreenRouter.screen_node()
	var tree: Node = session.get_node("%TechTree")
	Game.site_confirm(ORIGIN)
	Game.set_speed(0)
	await wait_process_frames(2)
	await _key(KEY_T)
	await wait_process_frames(3)
	var tabs: Array = tree.get(&"_tab_buttons")
	assert_eq(get_viewport().gui_get_focus_owner(), tabs[0], "the tree opens on its first tab")
	tree.call(&"open_on", CAPABILITY)
	await wait_process_frames(3)
	assert_eq(_pressed(tabs), [tabs[CAPABILITIES_TAB]] as Array[BaseButton])
	assert_eq(get_viewport().gui_get_focus_owner(), tabs[CAPABILITIES_TAB],
		"no ring left on the tab before it")


func test_a_mode_a_phase_takes_away_leaves_one_toggle_pressed() -> void:
	await _launch()
	ScreenRouter.start_new_run(null, SEED)
	Game.set_speed(0)
	await wait_process_frames(2)
	var session: Node = ScreenRouter.screen_node()
	Game.site_confirm(ORIGIN)
	Game.set_speed(0)
	var hud: Node = session.get_node("%Hud")
	Game.sim.world.phase = World.Phase.EMERGENT
	hud.call(&"apply_reveal")
	await wait_process_frames(3)
	var picker: Node = hud.get_node("%OverlayPicker")
	var toggles: Array = picker.get_node("%Row").get_children()
	assert_eq(await _click_control(toggles[3] as Control), "", "the click reached Society")
	Game.sim.world.phase = World.Phase.COVERT
	hud.call(&"apply_reveal")
	await wait_process_frames(2)
	assert_eq(int(picker.get(&"mode")), int(MapView.Overlay.PENETRATION), "the fallback")
	assert_eq(_pressed(toggles), [toggles[0]] as Array[BaseButton],
		"Society let go, though hidden — it shows again with the next phase")
