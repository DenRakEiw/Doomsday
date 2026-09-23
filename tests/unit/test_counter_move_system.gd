extends GutTest
## S4.5 — the counter-move schedule (opposition.md §6). The fixture's factions:
## the labs probe on a risk of 5 % or at 0.9, the governments move at 0.2
## (`fx_move`, any infected region), the researchers notice at 0.4 (by sea when
## the agent seeded most by sea), the public riot at 0.3 where the fleets are.
## Prepare 6 days × (1 − c), at least 2; cooldown 5; two moves at most; level 2
## from 0.5.

const LABS: String = "ai_labs"
const GOVERNMENTS: String = "governments"
const RESEARCHERS: String = "security_researchers"
const PUBLIC: String = "public_sentiment"

var system: CounterMoveSystem
var events: Array[SimEvent]


func before_each() -> void:
	system = CounterMoveSystem.new()
	events = []


func _run(sim: Simulation) -> void:
	events = []
	system.tick(sim.world, sim.db, events)


func _of_type(type: String) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for event: SimEvent in events:
		if event.type == type:
			out.append(event)
	return out


func _force(sim: Simulation, target: String, op: ModifierDef.Op, value: float) -> void:
	var modifier: ModifierDef = ModifierDef.new()
	modifier.target = target
	modifier.op = op
	modifier.value = value
	var modifiers: Array[ModifierDef] = [modifier]
	var no_flags: Array[String] = []
	sim.world.modifiers.add_source("test_%s" % target, modifiers, no_flags)


## A world status running in `region`, applied as a faction's move.
func _move_status(sim: Simulation, status_id: String, region: int) -> void:
	var none: Array[SimEvent] = []
	StatusSystem.apply(sim.world, sim.db, status_id, region,
		Status.source_for(Status.SOURCE_FACTION, GOVERNMENTS), 1, "", none)


func _infect(sim: Simulation, region: int, penetration: float = 0.3) -> void:
	sim.world.regions[region].penetration = penetration
	sim.world.regions[region].seeded_day = 0


# ------------------------------------------------------------------ preparing


func test_nothing_happens_before_the_origin() -> void:
	var sim: Simulation = Fixtures.sim()
	sim.world.faction(GOVERNMENTS).containment = 0.5
	_run(sim)
	assert_eq(sim.world.faction(GOVERNMENTS).preparing, "")
	assert_eq(events.size(), 0)


func test_a_containment_trigger_prepares_the_move() -> void:
	var sim: Simulation = Fixtures.sim_with_containment(GOVERNMENTS, 0.3)
	var day: int = sim.world.day
	_run(sim)
	var governments: Faction = sim.world.faction(GOVERNMENTS)
	assert_eq(governments.preparing, Fixtures.COUNTER_EVENT)
	# max(2, round(6 × 0.7)) = 4.
	assert_eq(governments.fire_day, day + 4)
	var prepared: Array[SimEvent] = _of_type(SimEvent.COUNTER_MOVE_PREPARED)
	assert_eq(prepared.size(), 1)
	assert_eq(prepared[0].data["faction"], GOVERNMENTS)
	assert_eq(prepared[0].data["event"], Fixtures.COUNTER_EVENT)
	assert_eq(prepared[0].data["fire_day"], day + 4)


func test_the_preparation_is_never_shorter_than_the_minimum() -> void:
	var sim: Simulation = Fixtures.sim_with_containment(GOVERNMENTS, 0.95)
	_run(sim)
	assert_eq(sim.world.faction(GOVERNMENTS).fire_day, sim.world.day + 2)


func test_below_the_trigger_nothing_is_prepared() -> void:
	var sim: Simulation = Fixtures.sim_with_containment(GOVERNMENTS, 0.1)
	_run(sim)
	assert_eq(sim.world.faction(GOVERNMENTS).preparing, "")


func test_a_faction_in_cooldown_prepares_nothing() -> void:
	var sim: Simulation = Fixtures.sim_with_containment(GOVERNMENTS, 0.3)
	sim.world.faction(GOVERNMENTS).cooldown_until = sim.world.day + 3
	_run(sim)
	assert_eq(sim.world.faction(GOVERNMENTS).preparing, "")


func test_a_risk_trigger_prepares_before_discovery_only() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	_force(sim, "footprint", ModifierDef.Op.ADD, 60.0)
	_force(sim, "discovery", ModifierDef.Op.MUL, 20.0)
	assert_gte(float(sim.discovery_risk()[ContainmentSystem.RISK_TOTAL]), 0.05)
	_run(sim)
	assert_eq(sim.world.faction(LABS).preparing, Fixtures.PROBE_EVENT,
		"the labs act on the risk before anybody has found the agent")
	# The full preparation: nothing is contained before discovery.
	assert_eq(sim.world.faction(LABS).fire_day, sim.world.day + 6)

	var found: Simulation = Fixtures.sim_with_containment(GOVERNMENTS, 0.0)
	_force(found, "footprint", ModifierDef.Op.ADD, 60.0)
	_force(found, "discovery", ModifierDef.Op.MUL, 20.0)
	_run(found)
	assert_eq(found.world.faction(LABS).preparing, "", "after discovery the risk counts no more")


func test_a_move_with_nowhere_to_land_is_not_prepared() -> void:
	# The riot needs a fleet or the dead; this world has neither.
	var sim: Simulation = Fixtures.sim_with_containment(PUBLIC, 0.5)
	_run(sim)
	assert_eq(sim.world.faction(PUBLIC).preparing, "")
	sim.world.set_assets(1, AssetDef.KIND_FLEET, 1)
	_run(sim)
	assert_eq(sim.world.faction(PUBLIC).preparing, Fixtures.RIOT_EVENT)


# --------------------------------------------------------------------- firing


func test_on_its_day_the_move_opens_with_its_faction_and_level() -> void:
	var sim: Simulation = Fixtures.sim_with_containment(GOVERNMENTS, 0.3)
	Fixtures.quiet_factions(sim)
	var governments: Faction = sim.world.faction(GOVERNMENTS)
	governments.cooldown_until = 0
	governments.preparing = Fixtures.COUNTER_EVENT
	governments.fire_day = sim.world.day + 1
	sim.tick()
	var opened: Array[OpenEvent] = []
	for event: OpenEvent in sim.world.events:
		if event.def == Fixtures.COUNTER_EVENT:
			opened.append(event)
	assert_eq(opened.size(), 1, "scheduled and opened on the same tick")
	assert_eq(opened[0].faction, GOVERNMENTS)
	assert_eq(opened[0].level, 1)
	assert_eq(opened[0].region, sim.world.agent.origin, "the only infected region")
	assert_eq(governments.preparing, "")
	assert_eq(governments.fire_day, -1)
	assert_eq(governments.cooldown_until, sim.world.day + 5)


func test_a_move_at_the_level_threshold_comes_at_level_two() -> void:
	var sim: Simulation = Fixtures.sim_with_containment(GOVERNMENTS, 0.6)
	var governments: Faction = sim.world.faction(GOVERNMENTS)
	governments.preparing = Fixtures.COUNTER_EVENT
	governments.fire_day = sim.world.day
	_run(sim)
	assert_eq(sim.world.pending_events.size(), 1)
	assert_eq(sim.world.pending_events[0].level, 2)
	assert_eq(CounterMoveSystem.level_for(sim.db, 0.49, "fx_lock"), 1)
	assert_eq(CounterMoveSystem.level_for(sim.db, 0.5, "fx_lock"), 2)
	assert_eq(CounterMoveSystem.level_for(sim.db, 0.9, "fx_hold"), 1,
		"never above the levels the status has")


func test_a_move_waits_while_the_world_has_its_fill_of_moves() -> void:
	var sim: Simulation = Fixtures.sim_with_containment(GOVERNMENTS, 0.3)
	_infect(sim, 2)
	_infect(sim, 4)
	_move_status(sim, "fx_riot", 2)
	_move_status(sim, "fx_riot", 4)
	var governments: Faction = sim.world.faction(GOVERNMENTS)
	governments.preparing = Fixtures.COUNTER_EVENT
	governments.fire_day = sim.world.day
	_run(sim)
	assert_eq(governments.preparing, Fixtures.COUNTER_EVENT, "held: two moves already stand")
	assert_eq(sim.next_move(GOVERNMENTS)["state"], "held")
	assert_eq(sim.world.pending_events.size(), 0)
	var none: Array[SimEvent] = []
	StatusSystem.end(sim.world, sim.db, sim.world.statuses[0], StatusSystem.CAUSE_ENDED, none)
	_run(sim)
	assert_eq(governments.preparing, "", "and it fires once one of them ends")
	assert_eq(sim.world.pending_events.size(), 1)


func test_a_move_on_its_way_counts_against_the_cap() -> void:
	var sim: Simulation = Fixtures.sim_with_containment(GOVERNMENTS, 0.3)
	sim.world.faction(PUBLIC).containment = 0.3
	sim.world.set_assets(1, AssetDef.KIND_FLEET, 1)
	_move_status(sim, "fx_riot", 2)
	for id: String in [GOVERNMENTS, PUBLIC]:
		var faction: Faction = sim.world.faction(id)
		faction.preparing = Fixtures.COUNTER_EVENT if id == GOVERNMENTS else Fixtures.RIOT_EVENT
		faction.fire_day = sim.world.day
	_run(sim)
	# One standing plus the governments' scheduled move fill the cap of two.
	assert_eq(sim.world.pending_events.size(), 1)
	assert_eq(sim.world.faction(PUBLIC).preparing, Fixtures.RIOT_EVENT)


func test_a_rule_that_finds_nothing_drops_the_move() -> void:
	var sim: Simulation = Fixtures.sim_with_containment(PUBLIC, 0.5)
	var public: Faction = sim.world.faction(PUBLIC)
	public.preparing = Fixtures.RIOT_EVENT
	public.fire_day = sim.world.day
	_run(sim)
	var dropped: Array[SimEvent] = _of_type(SimEvent.COUNTER_MOVE_DROPPED)
	assert_eq(dropped.size(), 1)
	assert_eq(dropped[0].data["cause"], SimEvent.CAUSE_NO_SITE)
	assert_eq(public.preparing, "")
	assert_eq(public.cooldown_until, sim.world.day + 5, "the cooldown starts all the same")
	assert_eq(sim.world.pending_events.size(), 0)


## Seed 1 fixed: the eligibility pick draws on the sim's stream.
func test_an_eligibility_pick_skips_blocked_and_dormant_regions() -> void:
	var sim: Simulation = Fixtures.sim_with_containment(GOVERNMENTS, 0.3)
	_infect(sim, 2)
	_infect(sim, 3)
	sim.world.regions[1].dormant = true
	# fx_lock blocks itself: a region under a lock is not locked twice.
	_move_status(sim, "fx_lock", 2)
	var governments: Faction = sim.world.faction(GOVERNMENTS)
	governments.preparing = Fixtures.COUNTER_EVENT
	governments.fire_day = sim.world.day
	_run(sim)
	assert_eq(sim.world.pending_events.size(), 1)
	assert_eq(sim.world.pending_events[0].region, 3, "the only open infected region")


# ---------------------------------------------------------- choice of a move


func _two_moves() -> Simulation:
	var content: Dictionary = Fixtures.raw_content()
	var list: Array = ((content["events"] as Array)[0] as Dictionary)["events"]
	var second: Dictionary = {}
	for entry: Variant in list:
		if (entry as Dictionary)["id"] == Fixtures.COUNTER_EVENT:
			second = (entry as Dictionary).duplicate(true)
	second["id"] = "fx_move_b"
	list.append(second)
	var governments: Dictionary = ((content["factions"] as Dictionary)["factions"] as Array)[1]
	(governments["moves"] as Array).append({"event": "fx_move_b", "trigger": {"containment": 0.25}})
	var result: ContentLoadResult = Fixtures.load_raw(content)
	assert_true(result.ok(), result.error_text())
	var sim: Simulation = Simulation.create(result.db, 1)
	sim.apply(ChooseOriginCommand.new("fx_alder"))
	sim.world.discovered = true
	sim.world.discovery_day = 0
	sim.world.faction(GOVERNMENTS).containment = 0.3
	return sim


func test_a_faction_alternates_its_moves() -> void:
	var sim: Simulation = _two_moves()
	sim.world.event_last_day[Fixtures.COUNTER_EVENT] = 4
	_run(sim)
	assert_eq(sim.world.faction(GOVERNMENTS).preparing, "fx_move_b", "never made yet")

	var again: Simulation = _two_moves()
	again.world.event_last_day["fx_move_b"] = 4
	again.world.event_last_day[Fixtures.COUNTER_EVENT] = 2
	_run(again)
	assert_eq(again.world.faction(GOVERNMENTS).preparing, Fixtures.COUNTER_EVENT,
		"the one made longer ago")


func test_between_two_moves_never_made_the_later_wins() -> void:
	var sim: Simulation = _two_moves()
	_run(sim)
	assert_eq(sim.world.faction(GOVERNMENTS).preparing, "fx_move_b")


func test_a_variant_follows_the_kind_seeded_most() -> void:
	var sim: Simulation = Fixtures.sim_with_containment(RESEARCHERS, 0.5)
	sim.world.agent.seeds_by_kind = {"land": 1, "sea": 3}
	_run(sim)
	assert_eq(sim.world.faction(RESEARCHERS).preparing, Fixtures.NOTICE_SEA_EVENT)


func test_a_variant_the_move_lacks_falls_back_to_the_move() -> void:
	var sim: Simulation = Fixtures.sim_with_containment(RESEARCHERS, 0.5)
	sim.world.agent.seeds_by_kind = {"air": 2}
	_run(sim)
	assert_eq(sim.world.faction(RESEARCHERS).preparing, Fixtures.NOTICE_EVENT)


# -------------------------------------------------------------------- queries


func test_next_move_in_all_four_states() -> void:
	var sim: Simulation = Fixtures.sim_with_containment(GOVERNMENTS, 0.0)
	assert_eq(sim.next_move(GOVERNMENTS)["state"], "none")
	var governments: Faction = sim.world.faction(GOVERNMENTS)
	governments.cooldown_until = sim.world.day + 3
	assert_eq(sim.next_move(GOVERNMENTS), {"state": "cooldown", "event": "", "days": 3})
	governments.preparing = Fixtures.COUNTER_EVENT
	governments.fire_day = sim.world.day + 4
	assert_eq(sim.next_move(GOVERNMENTS),
		{"state": "preparing", "event": Fixtures.COUNTER_EVENT, "days": 4})
	governments.fire_day = sim.world.day
	assert_eq(sim.next_move(GOVERNMENTS)["state"], "held")


func test_the_last_move_is_derived_from_the_events_opened() -> void:
	var sim: Simulation = Fixtures.sim_with_containment(RESEARCHERS, 0.0)
	assert_eq(CounterMoveSystem.last_move(sim.world, sim.db, RESEARCHERS), ["", -1])
	sim.world.event_last_day[Fixtures.NOTICE_SEA_EVENT] = 9
	assert_eq(CounterMoveSystem.last_move(sim.world, sim.db, RESEARCHERS),
		[Fixtures.NOTICE_SEA_EVENT, 9], "a variant is the faction's move too")


func test_a_funding_reset_cancels_a_preparation_the_schedule_made() -> void:
	var sim: Simulation = Fixtures.sim_with_containment(GOVERNMENTS, 0.3)
	_run(sim)
	assert_ne(sim.world.faction(GOVERNMENTS).preparing, "")
	var reset: EffectDef = EffectDef.from_dict({"effect": EffectDef.FUNDING_RESET, "value": 1.0})
	var none: Array[SimEvent] = []
	EffectRunner.apply(sim, reset, EffectContext.for_node("fx_rollback", 0), none)
	assert_eq(sim.world.faction(GOVERNMENTS).preparing, "")
	assert_eq(sim.next_move(GOVERNMENTS)["state"], "cooldown")


func test_invariants_hold_through_a_run_with_moves() -> void:
	var sim: Simulation = Fixtures.sim_with_containment(GOVERNMENTS, 0.3)
	sim.world.faction(PUBLIC).containment = 0.4
	sim.world.set_assets(1, AssetDef.KIND_FLEET, 2)
	for i: int in 60:
		sim.tick()
		var problems: Array[String] = sim.world.check_invariants(sim.db)
		assert_eq(problems.size(), 0, "day %d: %s" % [sim.world.day, problems])
		if not problems.is_empty():
			return
