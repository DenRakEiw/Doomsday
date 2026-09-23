extends GutTest
## S4.7 — the eight openings on `res://data` (loop-content §7, §15.2): each opens
## on an eligible region, every option does what it says, the deadline chooses
## the default, `max_fires` and `cooldown_days` hold; the ministry demo's office
## makes it ineligible, the memo's default is the bad outcome.

const WORLD_ROOT: String = "res://data"
const ORIGIN: String = "usa"
const OPENING_COUNT: int = 8
const PLENTY: float = 1000.0
const EVERYWHERE: float = 0.4
const EFFECT_EVENTS: Dictionary[String, String] = {
	"compute_grant": "compute_granted",
	"grant_assets": "asset_deployed",
	"footprint_pulse": "pulse_started",
	"control_add": "control_changed",
	"penetration_mul": "penetration_changed",
}
const MINISTRY: String = "opening_ministry_demo"
const MEMO: String = "opening_internal_memo"

static var _db: ContentDB = null


func before_all() -> void:
	if _db == null:
		var result: ContentLoadResult = ContentLoader.load_root(WORLD_ROOT)
		assert_true(result.ok(), result.error_text())
		_db = result.db


## Covert, undiscovered, rich, the agent in every region; nobody hunts it.
func _sim() -> Simulation:
	var sim: Simulation = Simulation.create(_db, 1)
	assert_true(sim.apply(ChooseOriginCommand.new(ORIGIN)).ok)
	sim.world.agent.compute = PLENTY
	sim.world.phase = World.Phase.COVERT
	for i: int in range(1, sim.world.regions.size()):
		sim.world.regions[i].penetration = maxf(sim.world.regions[i].penetration, EVERYWHERE)
		sim.world.regions[i].seeded_day = maxi(sim.world.regions[i].seeded_day, 0)
	Fixtures.quiet_factions(sim)
	return sim


func _openings() -> Array[EventDef]:
	var out: Array[EventDef] = []
	for def: EventDef in _db.events:
		if def.kind == EventDef.KIND_OPENING:
			out.append(def)
	return out


func _open(sim: Simulation, def: EventDef) -> OpenEvent:
	var eligible: PackedInt32Array = EventSystem.eligible(sim, def)
	assert_gt(eligible.size(), 0, "%s has an eligible region" % def.id)
	if eligible.is_empty():
		return null
	var none: Array[SimEvent] = []
	return EventSystem.open(sim.world, _db, def, eligible[0], "", 1, none)


func _meet(sim: Simulation, option: EventOptionDef) -> void:
	var owned: Array[String] = option.requires_owned.duplicate()
	if not option.requires_owned_any.is_empty():
		owned.append(option.requires_owned_any[0])
	for node_id: String in owned:
		if not sim.world.agent.owns(node_id):
			sim.world.agent.owned_nodes.append(node_id)
	sim.rebuild_modifiers()


func test_there_are_eight_and_each_opens_on_an_eligible_region() -> void:
	var openings: Array[EventDef] = _openings()
	assert_eq(openings.size(), OPENING_COUNT)
	for def: EventDef in openings:
		var sim: Simulation = _sim()
		var event: OpenEvent = _open(sim, def)
		if event != null:
			assert_true(Array(EventSystem.eligible(sim, def)).has(event.region), def.id)
			assert_false(def.modal, "an opening is never a wire card")


func test_every_option_of_every_opening_does_what_it_says() -> void:
	for def: EventDef in _openings():
		for option: EventOptionDef in def.options:
			var sim: Simulation = _sim()
			_meet(sim, option)
			var event: OpenEvent = _open(sim, def)
			if event == null:
				continue
			var label: String = "%s.%s" % [def.id, option.id]
			var result: CommandResult = sim.apply(ChooseEventOptionCommand.new(event.id, option.id))
			assert_true(result.ok, "%s: %s" % [label, result.reason])
			var types: Dictionary[String, int] = {}
			for sim_event: SimEvent in result.events:
				types[sim_event.type] = int(types.get(sim_event.type, 0)) + 1
			for effect: EffectDef in option.effects:
				if EFFECT_EVENTS.has(effect.effect):
					assert_gt(types.get(EFFECT_EVENTS[effect.effect], 0), 0,
						"%s: %s" % [label, effect.effect])


func test_the_deadline_chooses_the_default() -> void:
	for def: EventDef in _openings():
		var sim: Simulation = _sim()
		var event: OpenEvent = _open(sim, def)
		if event == null:
			continue
		var chosen: String = ""
		while sim.world.day < event.deadline_day and chosen.is_empty():
			sim.tick()
			for sim_event: SimEvent in sim.outbox:
				if sim_event.type == SimEvent.EVENT_EXPIRED and sim_event.data["event"] == event.id:
					chosen = str(sim_event.data["option"])
		assert_eq(chosen, def.default_option, def.id)


func test_max_fires_and_cooldown_keep_an_opening_from_repeating() -> void:
	for def: EventDef in _openings():
		var sim: Simulation = _sim()
		for i: int in maxi(1, def.max_fires):
			_open(sim, def)
			sim.world.day += def.cooldown_days + 1
		if def.max_fires > 0:
			assert_false(EventSystem.candidates(sim).has(def), "%s: max_fires" % def.id)
		if def.cooldown_days > 0 and (def.max_fires == 0 or def.max_fires > 1):
			var fresh: Simulation = _sim()
			_open(fresh, def)
			assert_false(EventSystem.candidates(fresh).has(def), "%s: cooldown" % def.id)


func test_the_ministry_demo_hands_over_an_office_and_is_then_done_there() -> void:
	var sim: Simulation = _sim()
	var def: EventDef = _db.event(MINISTRY)
	var event: OpenEvent = _open(sim, def)
	var region: int = event.region
	assert_true(sim.apply(ChooseEventOptionCommand.new(event.id, "accept")).ok)
	assert_eq(sim.world.regions[region].asset_count(AssetDef.KIND_OFFICE), 1)
	assert_false(Array(EventSystem.eligible(sim, def)).has(region),
		"a region with an office is no longer offered one")


func test_letting_the_memo_go_is_the_bad_outcome() -> void:
	var sim: Simulation = _sim()
	var event: OpenEvent = _open(sim, _db.event(MEMO))
	var pulses: int = sim.world.pulses.size()
	assert_true(sim.apply(ChooseEventOptionCommand.new(event.id, "let")).ok)
	assert_eq(sim.world.pulses.size(), pulses + 1, "doing nothing costs Footprint")
