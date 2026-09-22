extends GutTest
## S2.6 — the shape of a link (spec ui-foundation.md §7.8, world.md §5.4).
##
## The shapes are pure functions of two anchors and a kind, so the whole of the
## edge-crossing rule is checked here on the **real** world: the seven Pacific
## links world.md §5.4 names are the case the rule exists for, and a link that
## suddenly crosses — or stops crossing — is a moved anchor worth failing for.

const CONTENT_ROOT: String = "res://data"
## world.md §5.4: USA to Japan by air and by network, to South Korea, Australia,
## China and the Pacific Islands; Argentina & Chile to New Zealand.
const PACIFIC_LINKS: int = 7

static var _db: ContentDB = null


func before_all() -> void:
	if _db == null:
		var result: ContentLoadResult = ContentLoader.load_root(CONTENT_ROOT)
		assert_true(result.ok(), "the shipped content must load")
		_db = result.db


## The anchors of a link, in map pixels.
func _anchors(link: LinkDef) -> Array[Vector2]:
	return [Vector2(_db.regions[link.a].anchor), Vector2(_db.regions[link.b].anchor)]


func _crossing_links() -> Array[LinkDef]:
	var crossing: Array[LinkDef] = []
	for link: LinkDef in _db.links:
		var ends: Array[Vector2] = _anchors(link)
		if absf(ends[0].x - ends[1].x) > LinkLine.HALF_MAP:
			crossing.append(link)
	return crossing


func _inside(point: Vector2) -> bool:
	return point.x >= 0.0 and point.x <= LinkLine.MAP_WIDTH


# ------------------------------------------------------------ the map's edge


func test_exactly_seven_links_cross_the_pacific() -> void:
	assert_eq(_crossing_links().size(), PACIFIC_LINKS)


func test_a_link_that_stays_on_the_map_is_one_shape() -> void:
	var ends: Array[Vector2] = _anchors(_db.links[0])
	assert_eq(LinkLine.polylines(ends[0], ends[1], _db.links[0].kind).size(), 1)


func test_each_crossing_link_is_drawn_twice() -> void:
	for link: LinkDef in _crossing_links():
		var ends: Array[Vector2] = _anchors(link)
		assert_eq(LinkLine.polylines(ends[0], ends[1], link.kind).size(), 2, link.id)


func test_each_drawn_shape_takes_the_short_way_round() -> void:
	for link: LinkDef in _crossing_links():
		var ends: Array[Vector2] = _anchors(link)
		for shape: PackedVector2Array in LinkLine.polylines(ends[0], ends[1], link.kind):
			var span: float = absf(shape[shape.size() - 1].x - shape[0].x)
			assert_lt(span, LinkLine.HALF_MAP,
				"%s spans %f" % [link.id, span])


func test_each_drawn_shape_leaves_the_map_at_exactly_one_end() -> void:
	for link: LinkDef in _crossing_links():
		var ends: Array[Vector2] = _anchors(link)
		for shape: PackedVector2Array in LinkLine.polylines(ends[0], ends[1], link.kind):
			var inside: int = 0
			inside += 1 if _inside(shape[0]) else 0
			inside += 1 if _inside(shape[shape.size() - 1]) else 0
			assert_eq(inside, 1, "%s: one end on the map, one over the edge" % link.id)


func test_the_two_shapes_are_a_whole_map_apart() -> void:
	for link: LinkDef in _crossing_links():
		var ends: Array[Vector2] = _anchors(link)
		var shapes: Array[PackedVector2Array] = LinkLine.polylines(ends[0], ends[1], link.kind)
		assert_almost_eq(absf(shapes[1][0].x - shapes[0][0].x), LinkLine.MAP_WIDTH, 0.001,
			link.id)


func test_both_shapes_still_run_from_the_first_anchor_to_the_second() -> void:
	# The flow travels from the region that seeded to the region that was seeded,
	# and a shift must not turn a link around.
	var link: LinkDef = _crossing_links()[0]
	var ends: Array[Vector2] = _anchors(link)
	for shape: PackedVector2Array in LinkLine.polylines(ends[0], ends[1], link.kind):
		assert_almost_eq(shape[0].y, ends[0].y, 0.001, "%s starts at a" % link.id)
		assert_almost_eq(shape[shape.size() - 1].y, ends[1].y, 0.001, "and ends at b")


# ----------------------------------------------------------------- the kinds


func test_an_air_link_arcs_toward_the_top_of_the_map() -> void:
	var a: Vector2 = Vector2(1000.0, 800.0)
	var b: Vector2 = Vector2(1400.0, 800.0)
	var arc: PackedVector2Array = LinkLine.shape(a, b, LinkDef.KIND_AIR)
	assert_gt(arc.size(), 2, "an arc is sampled, not a straight line")
	assert_lt(LinkLine.midpoint_of(arc).y, 800.0, "y grows downwards, so up is less")


func test_the_arc_bulges_by_the_share_the_spec_states() -> void:
	var a: Vector2 = Vector2(1000.0, 800.0)
	var b: Vector2 = Vector2(1400.0, 800.0)
	var arc: PackedVector2Array = LinkLine.shape(a, b, LinkDef.KIND_AIR)
	# A quadratic curve reaches half way to its control point at its middle.
	var expected: float = 800.0 - 400.0 * LinkLine.ARC_BULGE * 0.5
	assert_almost_eq(arc[arc.size() / 2].y, expected, 1.0)


func test_the_arc_is_independent_of_the_order_of_its_ends() -> void:
	var a: Vector2 = Vector2(1000.0, 800.0)
	var b: Vector2 = Vector2(1400.0, 900.0)
	var forward: Vector2 = LinkLine.midpoint_of(LinkLine.shape(a, b, LinkDef.KIND_AIR))
	var backward: Vector2 = LinkLine.midpoint_of(LinkLine.shape(b, a, LinkDef.KIND_AIR))
	assert_almost_eq(forward.y, backward.y, 0.001, "both bulge upwards")


func test_every_other_kind_is_a_straight_line() -> void:
	for kind: String in [LinkDef.KIND_LAND, LinkDef.KIND_SEA, LinkDef.KIND_NETWORK]:
		var shape: PackedVector2Array = LinkLine.shape(
			Vector2(100.0, 100.0), Vector2(300.0, 200.0), kind)
		assert_eq(shape.size(), 2, kind)


func test_only_sea_and_air_carry_a_pattern() -> void:
	assert_eq(LinkLine.dash_of(LinkDef.KIND_LAND), Vector2.ZERO, "land is solid")
	assert_eq(LinkLine.dash_of(LinkDef.KIND_NETWORK), Vector2.ZERO, "so is network")
	assert_eq(LinkLine.dash_of(LinkDef.KIND_SEA), LinkLine.DASH_SEA)
	assert_eq(LinkLine.dash_of(LinkDef.KIND_AIR), LinkLine.DASH_AIR)


func test_a_network_link_is_thinner_than_the_rest() -> void:
	assert_eq(LinkLine.width_of(LinkDef.KIND_NETWORK), LinkLine.NETWORK_WIDTH_PX)
	assert_eq(LinkLine.width_of(LinkDef.KIND_LAND), LinkLine.WIDTH_PX)


func test_the_two_lines_of_a_network_link_run_beside_it() -> void:
	var points: PackedVector2Array = PackedVector2Array(
		[Vector2(100.0, 100.0), Vector2(300.0, 100.0)])
	var above: PackedVector2Array = LinkLine.offset_polyline(points, -2.0)
	var below: PackedVector2Array = LinkLine.offset_polyline(points, 2.0)
	assert_almost_eq(above[0].distance_to(below[0]), 4.0, 0.001, "four apart")
	assert_almost_eq(above[0].x, 100.0, 0.001, "and along the same line")


func test_the_midpoint_is_half_way_along_the_shape() -> void:
	var points: PackedVector2Array = PackedVector2Array(
		[Vector2(0.0, 0.0), Vector2(100.0, 0.0), Vector2(100.0, 100.0)])
	assert_eq(LinkLine.midpoint_of(points), Vector2(100.0, 0.0))


func test_a_link_between_two_identical_anchors_does_not_divide_by_zero() -> void:
	var same: Vector2 = Vector2(500.0, 500.0)
	for kind: String in LinkDef.KINDS:
		var shape: PackedVector2Array = LinkLine.shape(same, same, kind)
		assert_eq(LinkLine.polyline_length(shape), 0.0, kind)
		assert_eq(LinkLine.midpoint_of(shape), same, kind)


# ------------------------------------------------------------------ the state


func test_the_three_states_have_the_three_colours_of_the_spec() -> void:
	assert_eq(LinkLine.color_for(true, false), UiTokens.ACCENT_DIM, "at rest")
	assert_eq(LinkLine.color_for(true, true), UiTokens.ACCENT, "flowing")
	assert_eq(LinkLine.color_for(false, false), UiTokens.LINE_2, "closed")


func test_the_line_keeps_its_screen_width_at_every_zoom() -> void:
	var line: LinkLine = LinkLine.new()
	autofree(line)
	line.setup(Vector2(100.0, 100.0), Vector2(500.0, 100.0), LinkDef.KIND_LAND)
	for zoom: float in [0.5, 1.0, 4.0]:
		line.apply_zoom(zoom)
		var drawn: Line2D = line.get_child(0) as Line2D
		assert_almost_eq(drawn.width * zoom, LinkLine.WIDTH_PX, 0.001, "at zoom %f" % zoom)


func test_the_pattern_is_measured_in_screen_pixels() -> void:
	var line: LinkLine = LinkLine.new()
	autofree(line)
	line.setup(Vector2(0.0, 0.0), Vector2(400.0, 0.0), LinkDef.KIND_SEA)
	line.apply_zoom(2.0)
	var material: ShaderMaterial = (line.get_child(0) as Line2D).material as ShaderMaterial
	assert_almost_eq(float(material.get_shader_parameter(LinkLine.PARAM_LENGTH)),
		800.0, 0.001, "400 map pixels at zoom 2 are 800 screen pixels")
	assert_eq(material.get_shader_parameter(LinkLine.PARAM_DASH), LinkLine.DASH_SEA.x)


func test_a_network_link_is_two_lines_and_a_crossing_one_is_twice_that() -> void:
	var line: LinkLine = LinkLine.new()
	autofree(line)
	line.setup(Vector2(3500.0, 500.0), Vector2(900.0, 500.0), LinkDef.KIND_NETWORK)
	assert_eq(line.get_child_count(), 4, "two shapes, two lines each")
