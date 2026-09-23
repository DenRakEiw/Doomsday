extends GutTest
## S4.7 — every headline D4.3 and D4.4 staged for the M4 events fires
## (loop-content §15.2): for each one a hand-built event that matches its
## trigger goes through `HeadlineSystem.on_command`, a few seeds over, until the
## line is said. A headline that could never be said is text nobody reads.

const WORLD_ROOT: String = "res://data"
const ORIGIN: String = "usa"
## The events M4 added (S4.1–S4.5): their headlines are the staged ones.
const M4_EVENTS: Array[String] = ["asset_deployed", "asset_lost", "ability_used",
	"status_started", "event_opened", "event_answered", "event_expired",
	"threat_leader_changed", "funding_reset", "counter_move_prepared",
	"society_stage_changed", "region_wiped"]
const TRIES: int = 60

static var _db: ContentDB = null


func before_all() -> void:
	if _db == null:
		var result: ContentLoadResult = ContentLoader.load_root(WORLD_ROOT)
		assert_true(result.ok(), result.error_text())
		_db = result.db


func _m4_headlines() -> Array[HeadlineDef]:
	var out: Array[HeadlineDef] = []
	for def: HeadlineDef in _db.headlines:
		if M4_EVENTS.has(def.on_event):
			out.append(def)
		elif def.on_event == SimEvent.OUTCOME_REACHED \
				and Array(def.on_data.get("outcome", [])).has("lose_autophagy"):
			out.append(def)
	return out


## The event data a headline's trigger asks for: the first accepted value of
## every field, and a region where the event carries one.
func _data_for(def: HeadlineDef) -> Dictionary:
	var data: Dictionary = {}
	for field: String in def.on_data:
		data[field] = def.on_data[field][0]
	if SchemaValidator.REGION_EVENTS.has(def.on_event) and not data.has("region"):
		data["region"] = _region_for(def)
	return data


func _region_for(def: HeadlineDef) -> String:
	for i: int in range(1, _db.regions.size()):
		var region: RegionDef = _db.regions[i]
		var fits: bool = true
		for attr: String in def.on_region_attr_min:
			fits = fits and region.attr(attr) >= def.on_region_attr_min[attr]
		for attr: String in def.on_region_attr_max:
			fits = fits and region.attr(attr) <= def.on_region_attr_max[attr]
		if fits:
			return region.id
	return ORIGIN


func _world_for(def: HeadlineDef, seed_value: int) -> World:
	var sim: Simulation = Simulation.create(_db, seed_value)
	sim.apply(ChooseOriginCommand.new(ORIGIN))
	sim.world.day = 100
	sim.world.phase = World.Phase.OPEN if def.register == HeadlineDef.REGISTER_EMERGENCY \
		else World.Phase.COVERT
	return sim.world


func test_there_are_the_staged_lines() -> void:
	# 62 of D4.3 and 8 of D4.4, less the purchase lines that trigger on
	# `node_purchased` and the state-triggered reaction.
	assert_gte(_m4_headlines().size(), 55)


func test_every_m4_headline_can_be_said() -> void:
	var silent: Array[String] = []
	for def: HeadlineDef in _m4_headlines():
		if not def.when.is_empty():
			continue
		var said: bool = false
		for seed_value: int in range(1, TRIES + 1):
			var world: World = _world_for(def, seed_value)
			var system: HeadlineSystem = HeadlineSystem.create(seed_value)
			var events: Array[SimEvent] = [SimEvent.new(def.on_event, world.day, _data_for(def))]
			for line: SimEvent in system.on_command(world, _db, events):
				if line.data[SimEvent.FIELD_HEADLINE] == def.id:
					said = true
			if said:
				break
		if not said:
			silent.append(def.id)
	assert_eq(silent, [] as Array[String], "never said in %d tries: %s" % [TRIES, silent])
