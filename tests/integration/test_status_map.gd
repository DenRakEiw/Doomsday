extends GutTest
## S4.2 — what a status looks like on the map
## (`docs/specs/loop-mechanics.md` §16.3.1, §16.3.2, §16.4).

const SESSION_SCENE: PackedScene = preload("res://game/session/session.tscn")

const SEED: int = 1
const REGION_USA: String = "usa"
## A status the player's own abilities apply, and one of the world's with a
## border of its own (`data/statuses.json`).
const HARVESTED: String = "harvested"
const LOCKDOWN: String = "lockdown"

var _session: Node = null
var _reduced_motion: bool = false
var _locale: String = ""


func before_each() -> void:
	_reduced_motion = Settings.reduced_motion
	_locale = TranslationServer.get_locale()
	Settings.reduced_motion = true
	TranslationServer.set_locale("en")
	Game.stop_run()
	Game.debug_log = false
	_session = SESSION_SCENE.instantiate()
	add_child_autofree(_session)
	Game.start_run(SEED)
	Game.set_speed(0)
	Game.apply(ChooseOriginCommand.new(REGION_USA))


func after_each() -> void:
	Settings.reduced_motion = _reduced_motion
	TranslationServer.set_locale(_locale)
	Game.stop_run()


func _index_of(region_id: String) -> int:
	return Game.db.region_index_by_id[region_id]


func _markers() -> Node2D:
	return _session.get_node("MapLayer/MarkerLayer") as Node2D


func _links() -> Node2D:
	return _session.get_node("MapLayer/LinkLayer") as Node2D


func _apply(status_id: String, region_index: int, source: String = Status.SOURCE_EFFECT,
		level: int = 1) -> void:
	var events: Array[SimEvent] = []
	StatusSystem.apply(Game.sim.world, Game.db, status_id, region_index, source, level, "",
		events)
	for event: SimEvent in events:
		EventBus.sim_event.emit(event)


func _end(status_id: String, region_index: int) -> void:
	var events: Array[SimEvent] = []
	StatusSystem.end(Game.sim.world, Game.db,
		Game.sim.world.status_in_region(status_id, region_index),
		StatusSystem.CAUSE_EXPIRED, events)
	for event: SimEvent in events:
		EventBus.sim_event.emit(event)


# ------------------------------------------------------------ the status ring


func test_a_status_puts_a_ring_on_its_region_and_takes_it_away_again() -> void:
	var index: int = _index_of(REGION_USA)
	assert_eq(int(_markers().call("status_count")), 0)
	_apply(HARVESTED, index)
	assert_eq(int(_markers().call("status_count")), 1)
	var marker: StatusMarker = _markers().call("status_marker_of", index) as StatusMarker
	assert_eq(marker.count(), 1)
	assert_eq(str(marker.rows[0]["code"]), tr(StatusDef.code_key(HARVESTED)))
	_end(HARVESTED, index)
	assert_eq(int(_markers().call("status_count")), 0)


func test_a_second_status_nests_outside_the_first() -> void:
	var index: int = _index_of(REGION_USA)
	_apply(HARVESTED, index)
	_apply(LOCKDOWN, index, "faction:governments")
	var marker: StatusMarker = _markers().call("status_marker_of", index) as StatusMarker
	assert_eq(marker.count(), 2)
	assert_gt(StatusMarker.radius_of(1), StatusMarker.radius_of(0))
	assert_eq(marker.rows[0]["color"] as Color, UiTokens.color(&"ACCENT"),
		"the player's own wears the accent")
	assert_eq(marker.rows[1]["color"] as Color, UiTokens.faction_color("governments"))


## §16.3.2: the ring empties as the days run out.
func test_the_ring_empties_with_the_days() -> void:
	var index: int = _index_of(REGION_USA)
	_apply(HARVESTED, index)
	var marker: StatusMarker = _markers().call("status_marker_of", index) as StatusMarker
	var full: float = float(marker.rows[0]["share"])
	assert_almost_eq(full, 1.0, 1e-6)
	Game.advance(5)
	assert_lt(float(marker.rows[0]["share"]), full)


func test_a_global_status_has_no_ring() -> void:
	_apply("paused", 0)
	assert_eq(int(_markers().call("status_count")), 0)


# ------------------------------------------------------- the data texture


func test_the_row_one_colour_index_reads_the_source_not_the_definition() -> void:
	var index: int = _index_of(REGION_USA)
	assert_eq(RegionData.status_index(Game.sim.world, index), RegionData.STATUS_NONE)

	_apply(HARVESTED, index)
	assert_eq(RegionData.status_index(Game.sim.world, index), RegionData.STATUS_PLAYER)

	# A world status a chain applied has no faction behind it, so it still draws
	# in the player's own colour (§16.3.1).
	_end(HARVESTED, index)
	_apply(LOCKDOWN, index)
	assert_eq(RegionData.status_index(Game.sim.world, index), RegionData.STATUS_PLAYER)

	_end(LOCKDOWN, index)
	_apply(LOCKDOWN, index, "faction:governments")
	assert_eq(RegionData.status_index(Game.sim.world, index),
		RegionData.STATUS_FACTION_BASE + Faction.FACTION_IDS.find("governments"))


func test_a_border_status_sets_the_alpha_flag_and_nothing_else_does() -> void:
	var index: int = _index_of(REGION_USA)
	_apply(HARVESTED, index)
	assert_false(RegionData.has_border(Game.sim.world, Game.db, index))
	var plain: Color = RegionData.encode_row1(Game.sim.world, Game.db, index, false, false)
	assert_eq(plain.a, RegionData.OFF)

	_apply(LOCKDOWN, index, "faction:governments")
	assert_true(RegionData.has_border(Game.sim.world, Game.db, index))
	var bordered: Color = RegionData.encode_row1(Game.sim.world, Game.db, index, false, false)
	assert_eq(bordered.a, RegionData.ON)


# ------------------------------------------------------------------- links


## §16.4: a link a status closed is drawn in that status's colour, and goes back
## to the ordinary line when the status ends.
func test_a_link_a_status_closed_wears_its_colour() -> void:
	var index: int = _index_of(REGION_USA)
	_apply(LOCKDOWN, index, "faction:governments")
	var closed: Status = Game.sim.world.status_in_region(LOCKDOWN, index)
	assert_gt(closed.closed_links.size(), 0, "a Lockdown closes every link it can")

	var link_index: int = _link_index(closed.closed_links[0])
	var line: LinkLine = _links().call("line_at", link_index) as LinkLine
	assert_eq(line.closed_color(), UiTokens.faction_color("governments"))

	_end(LOCKDOWN, index)
	assert_eq(line.closed_color().a, 0.0, "nothing holds it any more")


func _link_index(link_id: String) -> int:
	for i: int in Game.sim.world.links.size():
		if Game.sim.world.links[i].def.id == link_id:
			return i
	return -1
