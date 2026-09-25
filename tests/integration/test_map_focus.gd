extends GutTest
## S6.8 — the map from the keyboard (accessibility.md §4.5): the cursor steps and
## hovers, `Enter` selects, `Enter` again goes into the region panel, `Page Down`
## jumps to a region that wants the player, and the arrows stop panning the map
## while a button has the focus.

const SESSION: PackedScene = preload("res://game/session/session.tscn")
const SEED: int = 1

var _session: Control = null
var _map: Control = null
var _reduced_motion: bool = false
var _hovered: Array[int] = []


func before_each() -> void:
	_reduced_motion = Settings.reduced_motion
	Settings.reduced_motion = true
	Game.stop_run()
	Game.debug_log = false
	_session = SESSION.instantiate()
	add_child_autofree(_session)
	_map = _session.get(&"map_focus") as Control
	_hovered.clear()
	EventBus.region_hovered.connect(_on_hovered)


func after_each() -> void:
	EventBus.region_hovered.disconnect(_on_hovered)
	Settings.reduced_motion = _reduced_motion
	Game.stop_run()


func _on_hovered(index: int) -> void:
	_hovered.append(index)


func _key(keycode: Key) -> void:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = keycode
	key.pressed = true
	_map.call(&"_gui_input", key)


func _cursor() -> int:
	return int(_map.get(&"cursor"))


func _panel() -> SlidePanel:
	return _session.get_node("PanelLayer/RegionPanel") as SlidePanel


func _start_with_origin() -> void:
	Game.start_run(SEED)
	Game.apply(ChooseOriginCommand.new(Game.db.regions[1].id))
	Game.set_speed(0)


func test_the_first_arrow_places_the_cursor_and_the_next_steps_it() -> void:
	_start_with_origin()
	_map.grab_focus()
	_key(KEY_RIGHT)
	var first: int = _cursor()
	assert_gt(first, 0, "placed on a region")
	_key(KEY_RIGHT)
	assert_ne(_cursor(), first, "moved")
	assert_eq(_hovered.back(), _cursor(), "and hovered like a pointer would")


func test_the_cursor_shows_only_with_focus_and_the_keyboard() -> void:
	_start_with_origin()
	var markers: Node2D = _session.get_node("MapLayer/MarkerLayer")
	_map.grab_focus()
	_map.set(&"keyboard_mode", true)
	_key(KEY_RIGHT)
	assert_true(bool(markers.get(&"cursor_visible")))
	_map.set(&"keyboard_mode", false)
	assert_false(bool(markers.get(&"cursor_visible")), "a pointer player sees no cursor")


func test_enter_selects_and_enter_again_goes_into_the_panel() -> void:
	# The origin prompt: the second Enter lands on the one button that answers.
	Game.start_run(SEED)
	_map.grab_focus()
	_map.call(&"jump", true)
	var target: int = _cursor()
	assert_gt(target, 0, "a region the origin can be")
	var selected: Array[int] = []
	var on_selected: Callable = func(index: int) -> void: selected.append(index)
	EventBus.region_selected.connect(on_selected)
	_key(KEY_ENTER)
	EventBus.region_selected.disconnect(on_selected)
	assert_eq(selected, [target] as Array[int])
	assert_true(_panel().is_open)
	assert_eq(get_viewport().gui_get_focus_owner(), _map, "the player keeps browsing")
	_key(KEY_ENTER)
	assert_eq(get_viewport().gui_get_focus_owner(), _panel().get_node("%OriginButton"))


func test_page_down_jumps_to_a_region_that_wants_the_player() -> void:
	_start_with_origin()
	var world: World = Game.sim.world
	var target: int = world.regions.size() - 1
	var anomaly: Anomaly = Anomaly.new()
	anomaly.region = target
	world.anomalies.append(anomaly)
	_map.grab_focus()
	_key(KEY_PAGEDOWN)
	var wanted: PackedInt32Array = _map.call(&"wanted")
	assert_true(wanted.has(target))
	assert_true(wanted.has(_cursor()), "the cursor is on a wanted region")


func test_a_jump_with_nothing_wanted_says_so() -> void:
	_start_with_origin()
	var map_focus: Node = _map
	var live: LiveRegion = map_focus.call(&"live_region")
	live.force_active = true
	for anomaly: Anomaly in Game.sim.world.anomalies.duplicate():
		Game.sim.world.anomalies.erase(anomaly)
	Game.sim.world.events.clear()
	map_focus.set(&"clock_override_ms", 100000)
	_map.call(&"jump", true)
	map_focus.call(&"_process", 0.0)
	assert_eq(live.text, tr("UI_A11Y_MAP_NOTHING"))


func test_the_arrows_pan_only_with_nothing_focused() -> void:
	_start_with_origin()
	var camera: MapCamera = _session.get_node("MapLayer/MapCamera") as MapCamera
	var owner: Control = get_viewport().gui_get_focus_owner()
	if owner != null:
		owner.release_focus()
	assert_true(camera.arrows_pan(), "nothing focused: the arrows pan")
	var top_bar: Node = _session.get_node("%Hud").get_node("%TopBar")
	(top_bar.get_node("%SpeedGroup").get_child(0) as Button).grab_focus()
	assert_false(camera.arrows_pan(), "a button has the focus: they move the focus")
	_map.grab_focus()
	assert_false(camera.arrows_pan(), "the map has it: they move the cursor")
