extends GutTest
## S2.3 — the camera and the picking as they are wired into the session
## (spec ui-foundation.md §7.4, §7.5).
##
## The whole session scene is instantiated, because the two things that can go
## wrong here are wiring: whether the engine's canvas transform is the one the
## picker computes, and whether a gesture reaches the right node. Neither shows
## in a unit test.

const SESSION: PackedScene = preload("res://game/session/session.tscn")
## The South Pacific, 55 map pixels from the nearest coast — far enough that the
## camera's clamp cannot push the centre onto land. The headless viewport is
## square (1920 x 1920), so it clamps harder in y than any real window.
const OPEN_WATER: Vector2 = Vector2(400.0, 1200.0)

var _session: Control = null
var _camera: MapCamera = null
var _view: MapView = null
var _selected: Array[int] = []


func before_each() -> void:
	Game.stop_run()
	Game.debug_log = false
	_selected = []
	_session = SESSION.instantiate()
	add_child_autofree(_session)
	_camera = _session.get_node("MapLayer/MapCamera") as MapCamera
	_view = _session.get_node("MapLayer/MapView") as MapView
	EventBus.region_selected.connect(_on_region_selected)


func after_each() -> void:
	if EventBus.region_selected.is_connected(_on_region_selected):
		EventBus.region_selected.disconnect(_on_region_selected)


func after_all() -> void:
	Game.stop_run()


func _on_region_selected(index: int) -> void:
	_selected.append(index)


func _view_size() -> Vector2:
	return _camera.view_size()


func _screen_of(index: int) -> Vector2:
	var anchor: Vector2i = Game.db.regions[index].anchor
	return _camera.canvas_transform() * (Vector2(anchor) + Vector2(0.5, 0.5))


func _press(at: Vector2) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = at
	return event


func _release(at: Vector2) -> InputEventMouseButton:
	var event: InputEventMouseButton = _press(at)
	event.pressed = false
	return event


func _drag(to: Vector2, relative: Vector2) -> InputEventMouseMotion:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = to
	event.relative = relative
	event.velocity = Vector2.ZERO
	return event


# ------------------------------------------------------------------- the view


func test_the_camera_starts_at_the_zoom_and_centre_the_spec_gives() -> void:
	var view: Vector2 = _view_size()
	assert_almost_eq(_camera.zoom.x, MapCamera.zoom_min_for(view), 0.0001)
	assert_eq(_camera.position,
		MapCamera.clamp_center(MapCamera.START_CENTER, _camera.zoom.x, view))
	assert_true(_camera.is_current(), "and it is the viewport's camera")


func test_the_engine_agrees_with_the_transform_the_picker_uses() -> void:
	_camera.set_view(Vector2(1500.0, 700.0), 2.0)
	await get_tree().process_frame
	var engine: Transform2D = _camera.get_canvas_transform()
	var ours: Transform2D = _camera.canvas_transform()
	assert_almost_eq(engine.origin.x, ours.origin.x, 0.01, "origin x")
	assert_almost_eq(engine.origin.y, ours.origin.y, 0.01, "origin y")
	assert_almost_eq(engine.get_scale().x, ours.get_scale().x, 0.001, "scale")


func test_the_map_quad_sits_in_the_same_canvas_as_the_camera() -> void:
	_camera.set_view(Vector2(1500.0, 700.0), 2.0)
	await get_tree().process_frame
	# The map is in a `CanvasLayer`, which follows the viewport only when it is
	# told to; without that the camera would move nothing.
	assert_almost_eq(_view.get_canvas_transform().origin.x,
		_camera.canvas_transform().origin.x, 0.01)


func test_the_outline_stays_two_screen_pixels_at_every_zoom() -> void:
	for zoom: float in [_camera.zoom_min, 2.0, MapCamera.ZOOM_MAX]:
		_camera.set_view(_camera.position, zoom)
		assert_almost_eq(_view.outline_px * zoom, MapView.OUTLINE_SCREEN_PX, 0.001,
			"at zoom %f" % zoom)


# -------------------------------------------------------------------- gestures


func test_a_click_without_a_drag_selects_the_region_under_it() -> void:
	Game.start_run(1, GreedyPolicy.ID)
	Game.set_speed(0)
	var index: int = Game.db.region_index_by_id["germany"]
	_camera.set_view(Vector2(Game.db.regions[index].anchor), 3.0)
	var at: Vector2 = _screen_of(index)

	_camera.handle_pointer(_press(at))
	_camera.handle_pointer(_release(at))

	assert_eq(_view.selected_index, index, "the map took the tap")
	assert_eq(_selected, [index] as Array[int], "and said so once on the bus")


func test_a_drag_pans_the_map_and_selects_nothing() -> void:
	Game.start_run(1, GreedyPolicy.ID)
	Game.set_speed(0)
	var index: int = Game.db.region_index_by_id["germany"]
	_camera.set_view(Vector2(Game.db.regions[index].anchor), 3.0)
	var at: Vector2 = _screen_of(index)
	var before: Vector2 = _camera.position

	_camera.handle_pointer(_press(at))
	_camera.handle_pointer(_drag(at + Vector2(40.0, 0.0), Vector2(40.0, 0.0)))
	_camera.handle_pointer(_release(at + Vector2(40.0, 0.0)))

	assert_almost_eq(_camera.position.x, before.x - 40.0 / 3.0, 0.001,
		"dragging right moves the view west")
	assert_eq(_view.selected_index, 0, "nothing was selected")
	assert_eq(_selected.size(), 0, "and nothing was announced")


func test_a_tiny_wobble_is_still_a_tap() -> void:
	Game.start_run(1, GreedyPolicy.ID)
	Game.set_speed(0)
	var index: int = Game.db.region_index_by_id["japan"]
	_camera.set_view(Vector2(Game.db.regions[index].anchor), 3.0)
	var at: Vector2 = _screen_of(index)

	_camera.handle_pointer(_press(at))
	_camera.handle_pointer(_drag(at + Vector2(2.0, 1.0), Vector2(2.0, 1.0)))
	_camera.handle_pointer(_release(at + Vector2(2.0, 1.0)))

	assert_eq(_view.selected_index, index)


## S3.P item 8: the rule was the length of the path walked between press and
## release, so a hand that shakes while it clicks lost the tap although the
## pointer never left the target. §7.4 measures press to release.
func test_a_shaky_click_that_ends_where_it_began_is_still_a_tap() -> void:
	Game.start_run(1, GreedyPolicy.ID)
	Game.set_speed(0)
	var index: int = Game.db.region_index_by_id["japan"]
	_camera.set_view(Vector2(Game.db.regions[index].anchor), 3.0)
	var at: Vector2 = _screen_of(index)

	_camera.handle_pointer(_press(at))
	# Six pixels out and six back: twelve walked, two from where it started.
	_camera.handle_pointer(_drag(at + Vector2(6.0, 0.0), Vector2(6.0, 0.0)))
	_camera.handle_pointer(_drag(at + Vector2(2.0, 0.0), Vector2(-4.0, 0.0)))
	_camera.handle_pointer(_release(at + Vector2(2.0, 0.0)))

	assert_eq(_view.selected_index, index, "the target never left the pointer")


func test_a_tap_on_open_water_deselects() -> void:
	Game.start_run(1, GreedyPolicy.ID)
	Game.set_speed(0)
	var index: int = Game.db.region_index_by_id["japan"]
	_camera.set_view(Vector2(Game.db.regions[index].anchor), 3.0)
	var at: Vector2 = _screen_of(index)
	_camera.handle_pointer(_press(at))
	_camera.handle_pointer(_release(at))
	assert_eq(_view.selected_index, index, "arranged: something is selected")

	_camera.set_view(OPEN_WATER, 3.0)
	var water: Vector2 = _view_size() * 0.5
	_camera.handle_pointer(_press(water))
	_camera.handle_pointer(_release(water))

	assert_eq(_view.selected_index, 0)
	assert_eq(_selected, [index, 0] as Array[int])


func test_the_wheel_zooms_towards_the_cursor() -> void:
	var cursor: Vector2 = Vector2(400.0, 300.0)
	var before: Transform2D = _camera.canvas_transform()
	var world: Vector2 = before.affine_inverse() * cursor
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = cursor
	# Reduced motion takes the tween out of the way; the anchor rule is the same.
	Settings.set_reduced_motion(true)

	_camera.handle_pointer(wheel)

	assert_almost_eq(_camera.zoom.x, _camera.zoom_min * MapCamera.ZOOM_STEP, 0.0001)
	var after: Vector2 = _camera.canvas_transform() * world
	assert_almost_eq(after.x, cursor.x, 0.5, "the point under the cursor stayed")
	assert_almost_eq(after.y, cursor.y, 0.5, "in both axes")
	Settings.set_reduced_motion(false)


func test_the_zoom_never_leaves_its_range() -> void:
	Settings.set_reduced_motion(true)
	for i: int in 40:
		_camera.zoom_by(MapCamera.ZOOM_STEP, _view_size() * 0.5, true)
	assert_almost_eq(_camera.zoom.x, MapCamera.ZOOM_MAX, 0.0001)
	for i: int in 40:
		_camera.zoom_by(1.0 / MapCamera.ZOOM_STEP, _view_size() * 0.5, true)
	assert_almost_eq(_camera.zoom.x, _camera.zoom_min, 0.0001)
	Settings.set_reduced_motion(false)


func test_the_camera_never_leaves_the_map() -> void:
	Settings.set_reduced_motion(true)
	_camera.zoom_by(MapCamera.ZOOM_STEP, _view_size() * 0.5, true)
	for step: Vector2 in [Vector2(9000.0, 0.0), Vector2(-9000.0, 0.0),
			Vector2(0.0, 9000.0), Vector2(0.0, -9000.0)]:
		_camera.set_view(_camera.position + step, _camera.zoom.x)
		var half: Vector2 = _view_size() / _camera.zoom.x * 0.5
		var rect: Rect2 = Rect2(_camera.position - half, half * 2.0)
		assert_true(rect.position.x >= -0.001 and rect.position.y >= -0.001
			and rect.end.x <= MapCamera.MAP_WIDTH + 0.001
			and rect.end.y <= MapCamera.MAP_ROW_MAX + 0.001, "after %s" % step)
	Settings.set_reduced_motion(false)


func test_focusing_a_region_puts_its_anchor_in_the_middle() -> void:
	Game.start_run(1, GreedyPolicy.ID)
	Game.set_speed(0)
	Settings.set_reduced_motion(true)
	var index: int = Game.db.region_index_by_id["japan"]
	_camera.set_view(MapCamera.START_CENTER, 2.0)

	_camera.focus_region(index)

	var anchor: Vector2 = Vector2(Game.db.regions[index].anchor)
	assert_eq(_camera.position, MapCamera.clamp_center(anchor, 2.0, _view_size()))
	Settings.set_reduced_motion(false)


func test_focusing_nothing_is_ignored() -> void:
	var before: Vector2 = _camera.position
	_camera.focus_region(0)
	_camera.focus_region(99999)
	assert_eq(_camera.position, before)


# --------------------------------------------- §7.5 wheel and reveal (S2.P)


func test_two_notches_in_one_frame_are_two_steps() -> void:
	# Motion on: the bug of G2 is that a second notch arrives while the first is
	# still tweening, and against the drawn zoom it changes nothing.
	var cursor: Vector2 = _view_size() * 0.5
	var start: float = _camera.zoom.x

	_camera.zoom_by(MapCamera.ZOOM_STEP, cursor, true)
	_camera.zoom_by(MapCamera.ZOOM_STEP, cursor, true)

	assert_almost_eq(_camera.target_zoom(),
		start * MapCamera.ZOOM_STEP * MapCamera.ZOOM_STEP, 0.0001)


func test_a_notch_against_the_drawn_zoom_is_still_one_step() -> void:
	Settings.set_reduced_motion(true)
	var start: float = _camera.zoom.x
	_camera.zoom_by(MapCamera.ZOOM_STEP, _view_size() * 0.5, true)
	assert_almost_eq(_camera.target_zoom(), start * MapCamera.ZOOM_STEP, 0.0001,
		"without a tween the target is what is on the screen")
	Settings.set_reduced_motion(false)


func test_opening_the_panel_brings_the_region_out_from_behind_it() -> void:
	Settings.set_reduced_motion(true)
	Game.start_run(1, GreedyPolicy.ID)
	Game.set_speed(0)
	var panel: SlidePanel = _session.get_node("%RegionPanel") as SlidePanel
	var index: int = Game.db.region_index_by_id["usa"]
	# The USA behind the panel: the camera is put there on purpose, because the
	# headless viewport is square and shows the whole map at the start zoom.
	_camera.set_view(MapCamera.clamp_center(Vector2(Game.db.regions[index].anchor)
		+ Vector2(700.0, 0.0), 2.0, _view_size()), 2.0)

	EventBus.region_selected.emit(index)

	var free: Rect2 = panel.uncovered_rect()
	var screen: Vector2 = _camera.canvas_transform() * Vector2(Game.db.regions[index].anchor)
	assert_true(free.grow(-float(UiTokens.SPACE_6)).has_point(screen),
		"the anchor at %s is inside the free rect %s" % [screen, free])
	Settings.set_reduced_motion(false)
