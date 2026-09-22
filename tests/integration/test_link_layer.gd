extends GutTest
## S2.6 — the links as they are wired into a run (spec ui-foundation.md §7.8).
##
## The whole session scene, because what can go wrong here is wiring: a link
## lights up because an event named it, and it stops because ten days went by.
## The geometry itself is `tests/unit/test_link_geometry.gd`.

const SESSION: PackedScene = preload("res://game/session/session.tscn")
## The layer's script is scene-specific and carries no `class_name`, so its rule
## and its constant are reached through the file itself.
const LINK_LAYER: GDScript = preload("res://game/map/link_layer.gd")
const FLOW_DAYS: int = 10

const SEED: int = 1
## Far enough for the bot to hold an origin and to have spread from it.
const WARMUP_DAYS: int = 40

var _session: Control = null
var _layer: Node2D = null
var _camera: MapCamera = null
var _reduced_motion: bool = false


func before_each() -> void:
	_reduced_motion = Settings.reduced_motion
	Settings.reduced_motion = true
	Game.stop_run()
	Game.debug_log = false
	_session = SESSION.instantiate()
	add_child_autofree(_session)
	_layer = _session.get_node("MapLayer/LinkLayer") as Node2D
	_camera = _session.get_node("MapLayer/MapCamera") as MapCamera


func after_each() -> void:
	Settings.reduced_motion = _reduced_motion
	Game.stop_run()


func _start() -> void:
	Game.start_run(SEED, GreedyPolicy.ID)
	Game.set_speed(0)
	Game.advance(WARMUP_DAYS)


## A region of the shipped world, as fresh state a rule can be tried on.
func _region(id: String) -> Region:
	return Region.create(Game.db.region_by_id(id))


## Tells the layer that `from` seeded `to` across a link of `kind`, the way the
## spread system does (core.md §6.4).
func _seed(from_id: String, to_id: String, kind: String) -> void:
	EventBus.sim_event.emit(SimEvent.new(SimEvent.REGION_SEEDED, Game.sim.world.day,
		{"region": to_id, "from": from_id, "link_kind": kind}))


## §7.8's visibility rule, reached through the script rather than a class name.
func _drawn(kind: String, a: Region, b: Region, flowing: bool) -> bool:
	return bool(LINK_LAYER.call("is_drawn", kind, a, b, flowing))


func _index_of(a_id: String, b_id: String, kind: String) -> int:
	var wanted: String = LinkDef.derive_id(a_id, b_id, kind)
	for i: int in Game.sim.world.links.size():
		if Game.sim.world.links[i].def.id == wanted:
			return i
	return -1


# ------------------------------------------------------------- the visibility rule


func test_a_land_link_is_drawn_only_while_something_crosses_it() -> void:
	_start()
	var a: Region = _region("germany")
	var b: Region = _region("france")
	a.penetration = 1.0
	assert_false(_drawn(LinkDef.KIND_LAND, a, b, false),
		"the border already shows that they touch")
	assert_true(_drawn(LinkDef.KIND_LAND, a, b, true))


func test_a_sea_link_is_drawn_as_soon_as_one_end_is_reached() -> void:
	_start()
	var a: Region = _region("japan")
	var b: Region = _region("usa")
	assert_false(_drawn(LinkDef.KIND_SEA, a, b, false), "untouched")
	b.penetration = 0.01
	assert_true(_drawn(LinkDef.KIND_SEA, a, b, false), "one end is enough")


func test_a_dark_region_is_connected_to_nothing() -> void:
	_start()
	var a: Region = _region("japan")
	var b: Region = _region("usa")
	a.penetration = 1.0
	b.penetration = 1.0
	b.dark = true
	for kind: String in LinkDef.KINDS:
		assert_false(_drawn(kind, a, b, true), kind)


# ------------------------------------------------------------------- the wiring


func test_a_run_draws_every_link_of_the_world() -> void:
	_start()
	assert_eq(_layer.line_count(), Game.sim.world.links.size())


func test_without_a_run_there_is_nothing_to_draw() -> void:
	assert_eq(_layer.line_count(), 0)


func test_a_seeding_lights_its_link() -> void:
	_start()
	var index: int = _index_of("alpine", "france", LinkDef.KIND_LAND)
	assert_gt(index, -1, "arranged: the two are neighbours")
	var line: LinkLine = _layer.line_at(index)
	assert_false(line.is_flowing(), "arranged: nothing has crossed here")

	_seed("alpine", "france", LinkDef.KIND_LAND)

	assert_true(line.is_flowing(), "the link the event named")
	assert_true(line.visible, "and a land link is visible exactly then")


func test_the_flow_follows_the_direction_the_infection_took() -> void:
	_start()
	var index: int = _index_of("alpine", "france", LinkDef.KIND_LAND)
	var line: LinkLine = _layer.line_at(index)

	_seed("france", "alpine", LinkDef.KIND_LAND)

	assert_eq(line.is_forward(), Game.sim.world.links[index].def.a
		== Game.db.region_index_by_id["france"],
		"the pattern travels from the source to the region that was seeded")


func test_the_flow_stops_after_ten_days() -> void:
	_start()
	var index: int = _index_of("alpine", "france", LinkDef.KIND_LAND)
	var line: LinkLine = _layer.line_at(index)
	var day: int = Game.sim.world.day
	_seed("alpine", "france", LinkDef.KIND_LAND)

	EventBus.tick_advanced.emit(day + FLOW_DAYS - 1)
	assert_true(line.is_flowing(), "still lit on the last day")

	EventBus.tick_advanced.emit(day + FLOW_DAYS)
	assert_false(line.is_flowing(), "and dark on the next")
	assert_false(line.visible, "so the land link goes with it")


func test_the_flow_lasts_the_ten_days_the_spec_gives_it() -> void:
	assert_eq(int(LINK_LAYER.get_script_constant_map()["FLOW_DAYS"]), FLOW_DAYS)


func test_a_seeding_across_a_link_the_world_does_not_have_is_ignored() -> void:
	_start()
	_seed("germany", "japan", LinkDef.KIND_LAND)
	for i: int in _layer.line_count():
		assert_false(_layer.line_at(i).is_flowing(), "line %d" % i)


func test_the_lines_keep_their_screen_width_when_the_camera_zooms() -> void:
	_start()
	var index: int = _index_of("alpine", "france", LinkDef.KIND_LAND)
	var line: LinkLine = _layer.line_at(index)
	for zoom: float in [1.5, 3.0]:
		_camera.set_view(_camera.position, zoom)
		var drawn: Line2D = line.get_child(0) as Line2D
		assert_almost_eq(drawn.width * _camera.zoom.x, LinkLine.WIDTH_PX, 0.01,
			"at zoom %f" % zoom)
