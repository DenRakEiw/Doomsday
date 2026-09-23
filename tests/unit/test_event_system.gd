extends GutTest
## S4.3 — `EventSystem` (`docs/specs/loop-mechanics.md` §10.4–§10.6).
##
## Seed 1 throughout. The draw is checked against a copy of the world's own
## generator rather than against a remembered number, so the test says *why* a
## def and a region came out, not only that they did.

const ORIGIN: String = "fx_alder"
const ORIGIN_INDEX: int = 1
const BIRCH: int = 2
const CEDAR: int = 3

var sim: Simulation
var system: EventSystem


func before_each() -> void:
	sim = Fixtures.sim_with_origin(ORIGIN)
	sim.world.phase = World.Phase.COVERT
	system = EventSystem.new()


## Seeds a region by hand, the way the spread system would leave it.
func _seed(index: int, penetration: float = 0.3) -> void:
	sim.world.regions[index].penetration = penetration
	sim.world.regions[index].seeded_day = sim.world.day


func _tick() -> Array[SimEvent]:
	var events: Array[SimEvent] = []
	system.tick(sim.world, sim.db, events)
	return events


func _of(events: Array[SimEvent], type: String) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for event: SimEvent in events:
		if event.type == type:
			out.append(event)
	return out


func _rng_copy() -> SimRng:
	return SimRng.from_strings(sim.world.rng.seed_string(), sim.world.rng.state_string())


# ------------------------------------------------------------------ openings


func test_nothing_opens_before_two_regions_are_seeded() -> void:
	for day: int in 40:
		sim.world.day += 1
		assert_true(_of(_tick(), SimEvent.EVENT_OPENED).is_empty())
	assert_eq(sim.world.open_event_count(), 0)


func test_nothing_opens_in_the_boxed_phase() -> void:
	_seed(BIRCH)
	sim.world.phase = World.Phase.BOXED
	var before: String = sim.world.rng.state_string()
	_tick()
	assert_eq(sim.world.rng.state_string(), before, "a zero chance is not rolled")


func test_the_draw_is_the_one_the_weights_give() -> void:
	_seed(BIRCH)
	# Predict with the world's own stream: one roll, then the def, then the region.
	var rng: SimRng = _rng_copy()
	var candidates: Array[EventDef] = EventSystem.candidates(sim)
	assert_eq(candidates.size(), 2, "the opening and the chain start share the list")
	var opened: bool = rng.chance(0.5)
	var events: Array[SimEvent] = _tick()
	var opened_events: Array[SimEvent] = _of(events, SimEvent.EVENT_OPENED)
	assert_eq(opened_events.size(), 1 if opened else 0)
	if not opened:
		return
	var weights: PackedFloat64Array = [1.0, 1.0]
	var def: EventDef = candidates[rng.weighted_pick(weights)]
	var regions: PackedInt32Array = EventSystem.eligible(sim, def)
	var region_weights: PackedFloat64Array = []
	for index: int in regions:
		region_weights.append(1.0)
	var region: int = regions[rng.weighted_pick(region_weights)]
	assert_eq(str(opened_events[0].data["def"]), def.id)
	assert_eq(str(opened_events[0].data["region"]), sim.world.regions[region].def.id)
	assert_eq(sim.world.rng.state_string(), rng.state_string())


func test_one_roll_a_tick_and_none_while_max_open_stands() -> void:
	_seed(BIRCH)
	Fixtures.open_event(sim, Fixtures.OPENING_EVENT, ORIGIN)
	Fixtures.open_event(sim, Fixtures.CHAIN_START, ORIGIN)
	var before: String = sim.world.rng.state_string()
	_tick()
	assert_eq(sim.world.rng.state_string(), before, "two open events fill the fixture's slots")
	sim.world.events.pop_back()
	var rng: SimRng = _rng_copy()
	var success: bool = rng.chance(0.5)
	_tick()
	if not success:
		assert_eq(sim.world.rng.state_string(), rng.state_string(), "exactly one roll")


func test_max_fires_keeps_a_def_out_of_the_draw() -> void:
	_seed(BIRCH)
	sim.world.event_fires[Fixtures.OPENING_EVENT] = 3
	var ids: Array[String] = _candidate_ids()
	assert_false(ids.has(Fixtures.OPENING_EVENT))
	assert_true(ids.has(Fixtures.CHAIN_START))


func test_cooldown_days_keep_a_def_out_until_they_pass() -> void:
	_seed(BIRCH)
	sim.world.day = 10
	sim.world.event_last_day[Fixtures.OPENING_EVENT] = 9
	assert_false(_candidate_ids().has(Fixtures.OPENING_EVENT))
	sim.world.event_last_day[Fixtures.OPENING_EVENT] = 8
	assert_true(_candidate_ids().has(Fixtures.OPENING_EVENT))


func test_a_def_whose_when_fails_is_not_drawn() -> void:
	# regions_min 2: the origin alone is one.
	assert_false(_candidate_ids().has(Fixtures.OPENING_EVENT))
	_seed(BIRCH)
	assert_true(_candidate_ids().has(Fixtures.OPENING_EVENT))


func test_a_def_with_nowhere_to_land_is_not_drawn() -> void:
	_seed(BIRCH)
	sim.world.regions[ORIGIN_INDEX].dormant = true
	sim.world.regions[BIRCH].dormant = true
	assert_false(_candidate_ids().has(Fixtures.OPENING_EVENT), "fx_opening wants not_dormant")


func test_event_opened_carries_the_deadline() -> void:
	sim.world.day = 5
	var events: Array[SimEvent] = []
	var event: OpenEvent = EventSystem.open(sim.world, sim.db, sim.db.event(Fixtures.OPENING_EVENT),
		BIRCH, "", 1, events)
	assert_eq(event.deadline_day, 9)
	assert_eq(event.opened_day, 5)
	assert_eq(events[0].type, SimEvent.EVENT_OPENED)
	assert_eq(int(events[0].data["deadline_day"]), 9)
	assert_eq(str(events[0].data["region"]), "fx_birch")
	assert_eq(str(events[0].data["kind"]), EventDef.KIND_OPENING)
	assert_false(bool(events[0].data["modal"]))
	assert_eq(sim.world.event_fires[Fixtures.OPENING_EVENT], 1)
	assert_eq(sim.world.event_last_day[Fixtures.OPENING_EVENT], 5)


func test_open_sets_the_definitions_story_flags() -> void:
	var def: EventDef = sim.db.event(Fixtures.OPENING_EVENT)
	var flagged: EventDef = EventDef.new()
	flagged.id = def.id
	flagged.deadline_days = def.deadline_days
	flagged.flags = ["fx_marked"] as Array[String]
	var events: Array[SimEvent] = []
	EventSystem.open(sim.world, sim.db, flagged, ORIGIN_INDEX, "", 1, events)
	assert_true(sim.world.agent.has_story_flag("fx_marked"))
	assert_eq(_of(events, SimEvent.FLAG_SET).size(), 1)


# ----------------------------------------------------------------- deadlines


func test_the_deadline_chooses_the_default_and_its_effects_run() -> void:
	var event: OpenEvent = Fixtures.open_event(sim, Fixtures.COUNTER_EVENT, ORIGIN, "governments")
	sim.world.day = event.deadline_day
	var events: Array[SimEvent] = _tick()
	var expired: Array[SimEvent] = _of(events, SimEvent.EVENT_EXPIRED)
	assert_eq(expired.size(), 1)
	assert_eq(str(expired[0].data["option"]), "ride")
	assert_true(_of(events, SimEvent.EVENT_ANSWERED).is_empty(), "expired instead of answered")
	assert_true(sim.world.has_status(Fixtures.WORLD_STATUS, ORIGIN_INDEX), "ride lets it land")
	assert_eq(sim.world.status_in_region(Fixtures.WORLD_STATUS, ORIGIN_INDEX).source,
		"faction:governments")
	assert_eq(sim.world.status_in_region(Fixtures.WORLD_STATUS, ORIGIN_INDEX).option, "ride")
	assert_null(sim.world.event_by_id(event.id), "the event is closed")


func test_an_event_before_its_deadline_stays_open() -> void:
	var event: OpenEvent = Fixtures.open_event(sim, Fixtures.OPENING_EVENT, ORIGIN)
	sim.world.day = event.deadline_day - 1
	_tick()
	assert_not_null(sim.world.event_by_id(event.id))


# ------------------------------------------------------------------- pending


func test_a_pending_event_opens_when_due_and_a_slot_is_free() -> void:
	sim.world.day = 3
	EventSystem.schedule(sim.world, Fixtures.OPENING_EVENT, BIRCH, "", 5, 1)
	sim.world.day = 4
	assert_true(_of(_tick(), SimEvent.EVENT_OPENED).is_empty(), "not due yet")
	sim.world.day = 5
	var opened: Array[SimEvent] = _of(_tick(), SimEvent.EVENT_OPENED)
	assert_eq(opened.size(), 1)
	assert_eq(str(opened[0].data["region"]), "fx_birch", "a scheduled region is kept")
	assert_true(sim.world.pending_events.is_empty())


func test_pending_events_open_in_due_order() -> void:
	EventSystem.schedule(sim.world, Fixtures.CHAIN_START, ORIGIN_INDEX, "", 2, 1)
	EventSystem.schedule(sim.world, Fixtures.OPENING_EVENT, ORIGIN_INDEX, "", 1, 1)
	EventSystem.schedule(sim.world, Fixtures.COUNTER_EVENT, ORIGIN_INDEX, "governments", 2, 1)
	assert_eq(sim.world.pending_events[0].def, Fixtures.OPENING_EVENT)
	assert_eq(sim.world.pending_events[1].def, Fixtures.CHAIN_START, "ties keep their order")
	sim.world.day = 2
	var opened: Array[SimEvent] = _of(_tick(), SimEvent.EVENT_OPENED)
	assert_eq(opened.size(), 2, "max_open is 2 in the fixture")
	assert_eq(str(opened[0].data["def"]), Fixtures.OPENING_EVENT)
	assert_eq(str(opened[1].data["def"]), Fixtures.CHAIN_START)
	assert_eq(sim.world.pending_events.size(), 1, "the third waits for a slot")


func test_a_due_pending_event_blocks_the_opening_roll() -> void:
	_seed(BIRCH)
	# One due, a slot to spare: it opens with the region it carries (no draw), and
	# the tick is its — the opening roll waits for the next one.
	EventSystem.schedule(sim.world, Fixtures.CHAIN_START, ORIGIN_INDEX, "", 0, 1)
	var before: String = sim.world.rng.state_string()
	_tick()
	assert_eq(sim.world.open_event_count(), 1)
	assert_eq(sim.world.rng.state_string(), before, "no roll in a tick a pending event had")


func test_a_pending_event_in_a_dark_region_is_dropped() -> void:
	EventSystem.schedule(sim.world, Fixtures.OPENING_EVENT, CEDAR, "", 0, 1)
	sim.world.regions[CEDAR].dark = true
	var events: Array[SimEvent] = _tick()
	var dropped: Array[SimEvent] = _of(events, SimEvent.EVENT_DROPPED)
	assert_eq(dropped.size(), 1)
	assert_eq(str(dropped[0].data["cause"]), SimEvent.CAUSE_DARK)
	assert_eq(sim.world.open_event_count(), 0)


func test_a_pending_event_without_a_region_picks_one_or_is_dropped() -> void:
	EventSystem.schedule(sim.world, Fixtures.OPENING_EVENT, 0, "", 0, 1)
	sim.world.regions[ORIGIN_INDEX].dormant = true
	var events: Array[SimEvent] = _tick()
	assert_eq(str(_of(events, SimEvent.EVENT_DROPPED)[0].data["cause"]), SimEvent.CAUSE_NO_SITE)
	sim.world.regions[ORIGIN_INDEX].dormant = false
	EventSystem.schedule(sim.world, Fixtures.OPENING_EVENT, 0, "", 0, 1)
	var opened: Array[SimEvent] = _of(_tick(), SimEvent.EVENT_OPENED)
	assert_eq(str(opened[0].data["region"]), ORIGIN, "the only eligible region")


func test_an_open_event_goes_with_a_region_that_goes_dark() -> void:
	var event: OpenEvent = Fixtures.open_event(sim, Fixtures.OPENING_EVENT, "fx_birch")
	var events: Array[SimEvent] = []
	PopulationSystem.go_dark(sim.world, sim.world.regions[BIRCH], BIRCH, events)
	assert_null(sim.world.event_by_id(event.id))
	assert_eq(_of(events, SimEvent.EVENT_DROPPED).size(), 1)
	assert_true(_of(events, SimEvent.EVENT_EXPIRED).is_empty(), "no default runs")


# -------------------------------------------------------------------- chains


func test_a_chains_next_is_scheduled_with_its_delay_and_keeps_the_region() -> void:
	var event: OpenEvent = Fixtures.open_event(sim, Fixtures.CHAIN_START, "fx_birch")
	sim.world.day = 4
	var result: CommandResult = sim.apply(ChooseEventOptionCommand.new(event.id, "go"))
	assert_true(result.ok, result.reason)
	assert_eq(sim.world.pending_events.size(), 1)
	var pending: PendingEvent = sim.world.pending_events[0]
	assert_eq(pending.def, Fixtures.CHAIN_STEP)
	assert_eq(pending.due_day, 7)
	assert_eq(pending.region, BIRCH, "pick same")
	sim.world.day = 7
	var opened: Array[SimEvent] = _of(_tick(), SimEvent.EVENT_OPENED)
	assert_eq(str(opened[0].data["def"]), Fixtures.CHAIN_STEP)
	assert_eq(str(opened[0].data["region"]), "fx_birch")
	assert_true(bool(opened[0].data["modal"]))


func test_schedule_from_outside_opens_through_the_same_path() -> void:
	EventSystem.schedule(sim.world, Fixtures.COUNTER_EVENT, ORIGIN_INDEX, "governments", 0, 2)
	var opened: Array[SimEvent] = _of(_tick(), SimEvent.EVENT_OPENED)
	assert_eq(opened.size(), 1)
	assert_eq(str(opened[0].data["faction"]), "governments")
	assert_eq(sim.world.events[0].level, 2)
	assert_eq(sim.world.event_fires[Fixtures.COUNTER_EVENT], 1)


func test_the_whole_system_runs_in_the_tick_order() -> void:
	# A full run on the fixture opens events and never lets one break an invariant.
	Fixtures.allow_breakout(sim)
	Fixtures.grant(sim, 50.0)
	var opened: int = 0
	for day: int in 120:
		sim.tick()
		opened += _of(sim.outbox, SimEvent.EVENT_OPENED).size()
		assert_eq(sim.world.check_invariants(sim.db), [] as Array[String])
		if sim.world.outcome != World.Outcome.NONE:
			break
	assert_gt(opened, 0, "the fixture's chances are 0.5 — something must open")


func _candidate_ids() -> Array[String]:
	var ids: Array[String] = []
	for def: EventDef in EventSystem.candidates(sim):
		ids.append(def.id)
	return ids
