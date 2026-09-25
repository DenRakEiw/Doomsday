extends GutTest
## S6.8 — the keyboard's map cursor (accessibility.md §4.5): a step in a
## direction within a 60° cone, and a jump through the regions that want the
## player.
##
## Index 0 is "no region", as on the real map.
##
##         2 (100, 0)
##   4 (0, 100)   1 (100, 100)   3 (200, 100)
##         5 (100, 200)      6 (300, 110)

const ANCHORS: PackedVector2Array = [Vector2.ZERO, Vector2(100, 100), Vector2(100, 0),
	Vector2(200, 100), Vector2(0, 100), Vector2(100, 200), Vector2(300, 110)]
const REGIONS: PackedInt32Array = [1, 2, 3, 4, 5, 6]


func test_each_direction_picks_its_neighbour() -> void:
	assert_eq(MapNav.step(1, Vector2.RIGHT, ANCHORS, REGIONS), 3)
	assert_eq(MapNav.step(1, Vector2.LEFT, ANCHORS, REGIONS), 4)
	assert_eq(MapNav.step(1, Vector2.UP, ANCHORS, REGIONS), 2)
	assert_eq(MapNav.step(1, Vector2.DOWN, ANCHORS, REGIONS), 5)


func test_the_cone_excludes_a_far_sideways_region() -> void:
	# From 2 going right, 3 lies 45° down-right (inside the cone), 1 lies straight
	# down (outside it).
	assert_eq(MapNav.step(2, Vector2.RIGHT, ANCHORS, [1, 3] as PackedInt32Array), 3)
	assert_eq(MapNav.step(2, Vector2.RIGHT, ANCHORS, [1] as PackedInt32Array), -1)


func test_the_nearer_one_along_the_way_wins() -> void:
	assert_eq(MapNav.step(4, Vector2.RIGHT, ANCHORS, REGIONS), 1)


func test_a_tie_goes_to_the_lower_index() -> void:
	var anchors: PackedVector2Array = [Vector2.ZERO, Vector2(0, 0), Vector2(100, 20),
		Vector2(100, -20)]
	assert_eq(MapNav.step(1, Vector2.RIGHT, anchors, [1, 2, 3] as PackedInt32Array), 2)
	assert_eq(MapNav.step(1, Vector2.RIGHT, anchors, [1, 3, 2] as PackedInt32Array), 2,
		"whatever order the candidates come in")


func test_nothing_in_the_direction_gives_minus_one() -> void:
	assert_eq(MapNav.step(6, Vector2.RIGHT, ANCHORS, REGIONS), -1)


func test_jump_goes_to_the_next_wanted_and_wraps_both_ways() -> void:
	var wanted: PackedInt32Array = [5, 2]
	assert_eq(MapNav.jump(1, true, wanted), 2)
	assert_eq(MapNav.jump(2, true, wanted), 5)
	assert_eq(MapNav.jump(5, true, wanted), 2, "past the last to the first")
	assert_eq(MapNav.jump(5, false, wanted), 2)
	assert_eq(MapNav.jump(2, false, wanted), 5, "before the first to the last")
	assert_eq(MapNav.jump(0, true, wanted), 2, "no cursor yet")


func test_jump_with_nothing_wanted_gives_minus_one() -> void:
	assert_eq(MapNav.jump(1, true, PackedInt32Array()), -1)


func test_the_first_cursor_is_the_region_nearest_the_point() -> void:
	assert_eq(MapNav.nearest(Vector2(190, 90), ANCHORS, REGIONS), 3)
