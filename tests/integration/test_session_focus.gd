extends GutTest
## S6.8 — the session's own focus ring (accessibility.md §4.3): `Tab` walks the
## zones in order across the canvas layers, a hidden zone adds nothing,
## `Shift+Tab` goes back, and with a modal up the ring is the modal's.

const SESSION: PackedScene = preload("res://game/session/session.tscn")
const SEED: int = 1

var _session: Control = null
var _reduced_motion: bool = false


func before_each() -> void:
	_reduced_motion = Settings.reduced_motion
	Settings.reduced_motion = true
	Game.stop_run()
	Game.debug_log = false
	_session = SESSION.instantiate()
	add_child_autofree(_session)
	Game.start_run(SEED)
	Game.apply(ChooseOriginCommand.new(Game.db.regions[1].id))
	Game.set_speed(0)


func after_each() -> void:
	Settings.reduced_motion = _reduced_motion
	Game.stop_run()


func _tab(backwards: bool = false) -> void:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_TAB
	key.shift_pressed = backwards
	key.pressed = true
	_session.call(&"_input", key)


func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


func _chain() -> Array[Control]:
	return _session.call(&"focus_chain")


func _map() -> Control:
	return _session.get(&"map_focus") as Control


func _panel(path: String) -> Control:
	return _session.get_node(path) as Control


func test_the_zones_come_in_order_with_the_region_panel_open() -> void:
	EventBus.region_selected.emit(1)
	var chain: Array[Control] = _chain()
	var top_bar: Control = _session.get_node("%Hud").get_node("%TopBar")
	var region_panel: Control = _panel("PanelLayer/RegionPanel")
	var map_at: int = chain.find(_map())
	assert_gt(map_at, 0, "the map is in the ring, after the HUD above it")
	var top_seen: int = 0
	var panel_seen: int = 0
	for i: int in chain.size():
		if top_bar.is_ancestor_of(chain[i]):
			top_seen += 1
			assert_lt(i, map_at, "zone 1 before the map")
		if region_panel.is_ancestor_of(chain[i]):
			panel_seen += 1
			assert_gt(i, map_at, "zone 6 after the map")
	assert_gt(top_seen, 0)
	assert_gt(panel_seen, 0)


func test_a_hidden_zone_adds_nothing() -> void:
	var containment: Control = _panel("PanelLayer/ContainmentPanel")
	for control: Control in _chain():
		assert_false(containment.is_ancestor_of(control), "a closed panel is not in the ring")


func test_tab_and_shift_tab_walk_the_ring() -> void:
	var chain: Array[Control] = _chain()
	var at: int = chain.find(_map())
	_map().grab_focus()
	_tab()
	assert_eq(_focus(), chain[(at + 1) % chain.size()])
	_tab(true)
	assert_eq(_focus(), _map())
	_tab(true)
	assert_eq(_focus(), chain[at - 1])


func test_nothing_focused_tab_starts_at_the_top_bar() -> void:
	var owner: Control = _focus()
	if owner != null:
		owner.release_focus()
	_tab()
	var top_bar: Control = _session.get_node("%Hud").get_node("%TopBar")
	assert_true(top_bar.is_ancestor_of(_focus()), "zone 1 first")


func test_with_a_modal_up_the_session_leaves_tab_alone() -> void:
	_session.call(&"_open_pause_menu")
	var before: Control = _focus()
	_tab()
	assert_eq(_focus(), before)


func test_the_pending_chip_is_a_focusable_button() -> void:
	var top_bar: Node = _session.get_node("%Hud").get_node("%TopBar")
	var pending: Button = top_bar.call(&"pending_chip") as Button
	assert_not_null(pending)
	assert_eq(pending.focus_mode, Control.FOCUS_ALL)
