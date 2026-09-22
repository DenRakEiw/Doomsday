extends GutTest
## S2.3 — the camera's geometry (spec ui-foundation.md §7.5).
##
## Everything here is a static function on plain values, so the clamp, the zoom
## floor and the anchor rule are checked without a viewport, a frame or a node.
## The camera *node* is checked in `tests/integration/test_map_camera.gd`.

const WIDE: Vector2 = Vector2(1920.0, 1080.0)
const COMPACT: Vector2 = Vector2(411.0, 914.0)
## The backdrop's two rules are geometry as well, and its script is
## scene-specific, so it is named by its file rather than by a class.
const BACKDROP: GDScript = preload("res://game/map/backdrop.gd")


## The map rectangle the camera shows at this centre and zoom.
func _visible_rect(center: Vector2, zoom: float, view: Vector2) -> Rect2:
	var size: Vector2 = view / zoom
	return Rect2(center - size * 0.5, size)


func test_the_start_zoom_makes_the_map_cover_the_viewport() -> void:
	for view: Vector2 in [WIDE, COMPACT]:
		var zoom: float = MapCamera.zoom_min_for(view)
		var visible: Vector2 = view / zoom
		assert_almost_eq(minf(MapCamera.MAP_WIDTH - visible.x,
			MapCamera.MAP_ROW_MAX - visible.y), 0.0, 0.001,
			"one axis fits exactly and neither overflows (%s)" % view)
		assert_true(visible.x <= MapCamera.MAP_WIDTH + 0.001, "width (%s)" % view)
		assert_true(visible.y <= MapCamera.MAP_ROW_MAX + 0.001, "height (%s)" % view)


func test_a_zero_sized_viewport_does_not_divide_by_it() -> void:
	assert_eq(MapCamera.zoom_min_for(Vector2.ZERO), 1.0)


func test_the_clamp_keeps_the_visible_rectangle_inside_the_map() -> void:
	var bounds: Rect2 = MapCamera.bounds()
	for zoom: float in [MapCamera.zoom_min_for(WIDE), 1.0, 2.0, MapCamera.ZOOM_MAX]:
		for wanted: Vector2 in [Vector2(-5000.0, -5000.0), Vector2(9000.0, 9000.0),
				Vector2(0.0, 1750.0), MapCamera.START_CENTER]:
			var center: Vector2 = MapCamera.clamp_center(wanted, zoom, WIDE)
			var visible: Rect2 = _visible_rect(center, zoom, WIDE)
			assert_almost_eq(visible.position.x, maxf(visible.position.x, 0.0), 0.001,
				"left edge at zoom %f for %s" % [zoom, wanted])
			assert_almost_eq(visible.position.y, maxf(visible.position.y, 0.0), 0.001,
				"top edge at zoom %f for %s" % [zoom, wanted])
			assert_true(visible.end.x <= bounds.end.x + 0.001,
				"right edge at zoom %f for %s" % [zoom, wanted])
			assert_true(visible.end.y <= bounds.end.y + 0.001,
				"bottom edge at zoom %f for %s" % [zoom, wanted])


func test_a_centre_well_inside_the_map_is_left_alone() -> void:
	var center: Vector2 = Vector2(2048.0, 875.0)
	assert_eq(MapCamera.clamp_center(center, MapCamera.ZOOM_MAX, WIDE), center)


func test_the_south_below_the_row_limit_is_never_shown() -> void:
	var center: Vector2 = MapCamera.clamp_center(Vector2(2048.0, 5000.0),
		MapCamera.ZOOM_MAX, WIDE)
	assert_true(_visible_rect(center, MapCamera.ZOOM_MAX, WIDE).end.y
		<= MapCamera.MAP_ROW_MAX + 0.001)
	assert_true(MapCamera.MAP_ROW_MAX < MapCamera.MAP_HEIGHT,
		"the bounds are shorter than the map on purpose")


func test_below_the_start_zoom_the_map_is_centred_rather_than_stuck() -> void:
	# Only reachable through a clamp that is handed a zoom the camera would not
	# take; the axis that no longer fits must not oscillate at an edge.
	var center: Vector2 = MapCamera.clamp_center(Vector2.ZERO, 0.1, WIDE)
	assert_eq(center, Vector2(MapCamera.MAP_WIDTH * 0.5, MapCamera.MAP_ROW_MAX * 0.5))


func test_the_transform_puts_the_centre_in_the_middle_of_the_viewport() -> void:
	var center: Vector2 = Vector2(1000.0, 600.0)
	var canvas: Transform2D = MapCamera.transform_for(center, 2.0, WIDE)
	assert_eq(canvas * center, WIDE * 0.5)
	assert_almost_eq(canvas.get_scale().x, 2.0, 0.0001)


func test_zooming_leaves_the_world_point_under_the_cursor_where_it_is() -> void:
	var view: Vector2 = WIDE
	var cursor: Vector2 = Vector2(1500.0, 300.0)
	var before: Transform2D = MapCamera.transform_for(Vector2(2048.0, 875.0), 1.0, view)
	var world: Vector2 = before.affine_inverse() * cursor
	for zoom: float in [1.15, 2.0, 0.8]:
		var center: Vector2 = MapCamera.center_keeping_point(world, cursor, zoom, view)
		var after: Transform2D = MapCamera.transform_for(center, zoom, view)
		assert_almost_eq((after * world).x, cursor.x, 0.001, "x at zoom %f" % zoom)
		assert_almost_eq((after * world).y, cursor.y, 0.001, "y at zoom %f" % zoom)


func test_the_backdrop_reads_centre_and_zoom_back_out_of_the_canvas_transform() -> void:
	var center: Vector2 = Vector2(1234.0, 777.0)
	var canvas: Transform2D = MapCamera.transform_for(center, 1.75, WIDE)
	var view: Array = BACKDROP.view_from_canvas(canvas, WIDE)
	var read_center: Vector2 = view[0]
	assert_almost_eq(read_center.x, center.x, 0.001)
	assert_almost_eq(read_center.y, center.y, 0.001)
	assert_almost_eq(float(view[1]), 1.75, 0.001)


func test_the_backdrop_lags_the_map_and_widens_with_the_zoom() -> void:
	var center: Vector2 = Vector2(2000.0, 900.0)
	var zoom_min: float = MapCamera.zoom_min_for(WIDE)
	var at_start: Array = BACKDROP.shader_values(center, zoom_min, WIDE, false)
	var offset: Vector2 = at_start[0]
	assert_almost_eq(offset.x, center.x * BACKDROP.PARALLAX, 0.001, "the offset lags")
	assert_almost_eq(float(at_start[1]), 1.0, 0.001, "no widening at the start zoom")
	var zoomed: Array = BACKDROP.shader_values(center, zoom_min + 2.0, WIDE, false)
	assert_almost_eq(float(zoomed[1]), 1.0 + 2.0 * BACKDROP.ZOOM_SCALE_GAIN, 0.001)


func test_reduced_motion_pins_the_backdrop_to_the_map() -> void:
	var center: Vector2 = Vector2(2000.0, 900.0)
	var values: Array = BACKDROP.shader_values(center, 3.0, WIDE, true)
	assert_eq(values[0], center, "no lag")
	assert_almost_eq(float(values[1]), 1.0, 0.001, "no breathing")


# ------------------------------------------------- §7.5 reveal (S2.P, from G2)


## The free rectangle an open side panel leaves at 1920 × 1080: §4.6's width is
## 30 % of the viewport, clamped to 480.
func _free_beside_panel() -> Rect2:
	return Rect2(480.0, 0.0, WIDE.x - 480.0, WIDE.y)


func test_an_anchor_the_panel_covers_is_panned_out_from_behind_it() -> void:
	var zoom: float = 2.0
	var free: Rect2 = _free_beside_panel()
	# A point well inside the panel's half of the screen.
	var center: Vector2 = Vector2(2048.0, 875.0)
	var anchor: Vector2 = MapCamera.transform_for(center, zoom, WIDE).affine_inverse() \
		* Vector2(120.0, 540.0)

	var moved: Vector2 = MapCamera.reveal_center(center, zoom, WIDE, anchor, free, 32.0)

	var screen: Vector2 = MapCamera.transform_for(moved, zoom, WIDE) * anchor
	assert_almost_eq(screen.x, free.position.x + 32.0, 0.001,
		"just inside the free rectangle, and no further")
	assert_almost_eq(screen.y, 540.0, 0.001, "the axis that was fine is untouched")


func test_an_anchor_that_is_already_visible_moves_nothing() -> void:
	var center: Vector2 = Vector2(2048.0, 875.0)
	var anchor: Vector2 = MapCamera.transform_for(center, 2.0, WIDE).affine_inverse() \
		* Vector2(1200.0, 500.0)

	assert_eq(MapCamera.reveal_center(center, 2.0, WIDE, anchor, _free_beside_panel(),
		32.0), center)


func test_the_reveal_never_leaves_the_map() -> void:
	var zoom: float = MapCamera.zoom_min_for(WIDE)
	var center: Vector2 = MapCamera.clamp_center(Vector2(200.0, 875.0), zoom, WIDE)
	# The far west, behind the panel, with no map left to pan in from the left.
	var anchor: Vector2 = Vector2(10.0, 875.0)

	var moved: Vector2 = MapCamera.reveal_center(center, zoom, WIDE, anchor,
		_free_beside_panel(), 32.0)

	assert_eq(moved, MapCamera.clamp_center(moved, zoom, WIDE), "still inside the bounds")


func test_a_bottom_sheet_pushes_the_anchor_up_instead() -> void:
	var zoom: float = 2.0
	var free: Rect2 = Rect2(0.0, 0.0, COMPACT.x, COMPACT.y * 0.5)
	var center: Vector2 = Vector2(2048.0, 875.0)
	var anchor: Vector2 = MapCamera.transform_for(center, zoom, COMPACT).affine_inverse() \
		* Vector2(200.0, 800.0)

	var moved: Vector2 = MapCamera.reveal_center(center, zoom, COMPACT, anchor, free, 32.0)

	var screen: Vector2 = MapCamera.transform_for(moved, zoom, COMPACT) * anchor
	assert_almost_eq(screen.y, free.end.y - 32.0, 0.001)
	assert_almost_eq(screen.x, 200.0, 0.001, "x was inside all along")


func test_a_free_rectangle_smaller_than_the_margin_is_ignored() -> void:
	var center: Vector2 = Vector2(2048.0, 875.0)
	assert_eq(MapCamera.reveal_center(center, 2.0, WIDE, Vector2.ZERO,
		Rect2(0.0, 0.0, 40.0, 40.0), 32.0), center, "rather than pan to nowhere")
