extends GutTest
## The headline system of spec ticker.md §3: what fires, in which order, how
## often, and with which arguments.
##
## The tests drive the system directly with events they build, because the point
## is the choosing — the simulation that produced the event is not the subject.

const ORIGIN: String = "fx_alder"
## Seeds are stated where a test depends on one (§3.6).
const SEED: int = 7


func _sim(entries: Array, seed_value: int = SEED) -> Simulation:
	var sim: Simulation = Fixtures.sim_with_headlines(entries, seed_value)
	var result: CommandResult = sim.apply(ChooseOriginCommand.new(ORIGIN))
	assert_true(result.ok, "the origin must be acceptable")
	return sim


## The headline ids one tick would fire, given the events it produced.
func _tick_ids(sim: Simulation, events: Array[SimEvent]) -> Array[String]:
	return _ids(sim.headlines.on_tick(sim.world, sim.db, events))


func _ids(fired: Array[SimEvent]) -> Array[String]:
	var out: Array[String] = []
	for event: SimEvent in fired:
		out.append(str(event.data[SimEvent.FIELD_HEADLINE]))
	return out


func _event(type: String, data: Dictionary = {}) -> SimEvent:
	return SimEvent.new(type, 1, data)


func _events(list: Array[SimEvent]) -> Array[SimEvent]:
	return list


func _seeded(region_id: String) -> SimEvent:
	return _event(SimEvent.REGION_SEEDED, {"region": region_id, "from": ORIGIN,
		"link_kind": "network"})


# ------------------------------------------------------------------- triggers


func test_event_trigger_matches_data_and_region_attrs() -> void:
	var sim: Simulation = _sim([
		Fixtures.headline("h_rich_net", HeadlineDef.STREAM_CONSEQUENCE, {
			"on": {
				"event": SimEvent.REGION_SEEDED,
				"data": {"link_kind": "network"},
				"region_attr_min": {"compute": 3},
			},
		}),
	])
	assert_eq(_tick_ids(sim, _events([_seeded("fx_dogwood")])), ["h_rich_net"] as Array[String],
		"compute 3 over a network link")
	assert_eq(_tick_ids(sim, _events([_seeded("fx_cedar")])), [] as Array[String],
		"the same link into a compute-1 region says nothing")


func test_when_conditions_read_the_world() -> void:
	var sim: Simulation = _sim([])
	var world: World = sim.world
	world.day = 30
	world.discovered = true
	world.discovery_day = 20
	world.regions[2].seeded_day = 1
	world.regions[3].dark = true
	world.regions[4].dormant = true
	world.agent.compute = 12.0
	Fixtures.grant(sim, 100.0)
	Fixtures.buy(sim, ["fx_vector_net"] as Array[String])

	_assert_bound(sim, "day_min", 30.0)
	_assert_bound(sim, "regions_max", 2.0, true)
	_assert_bound(sim, "days_since_discovery_min", 10.0)
	_assert_bound(sim, "dark_min", 1.0)
	_assert_bound(sim, "dormant_min", 1.0)
	_assert_bound(sim, "compute_min", world.agent.compute)
	_assert_bound(sim, "owned_count_min", 1.0)
	_assert_bound(sim, "share_min", world.infected_share(sim.db))
	_assert_bound(sim, "containment_max", world.max_containment(), true)
	_assert_bound(sim, "footprint_min", world.footprint())
	_assert_bound(sim, "deaths_share_min", 0.0)
	_assert_bound(sim, "harm_min", world.modifiers.value("harm"))

	assert_true(_holds(sim, "discovered", true))
	assert_false(_holds(sim, "discovered", false))
	assert_true(_holds(sim, "phase", ["boxed", "covert"] as Array[String]))
	assert_false(_holds(sim, "phase", ["open"] as Array[String]))
	assert_true(_holds(sim, "owned", ["fx_vector_net"] as Array[String]))
	assert_false(_holds(sim, "owned", ["fx_quiet"] as Array[String]))
	assert_true(_holds(sim, "owned_any", ["fx_vector_net", "fx_quiet"] as Array[String]))
	assert_true(_holds(sim, "not_owned", ["fx_quiet"] as Array[String]))
	assert_false(_holds(sim, "not_owned", ["fx_vector_net"] as Array[String]))
	assert_true(_holds(sim, "flag", [ModifierDef.FLAG_BREAKOUT] as Array[String]))
	assert_false(_holds(sim, "not_flag", [ModifierDef.FLAG_BREAKOUT] as Array[String]))


## True exactly at the bound and false one step past it, whichever way the key
## points.
func _assert_bound(sim: Simulation, key: String, bound: float, is_max: bool = false) -> void:
	var step: float = 1.0 if absf(bound) >= 1.0 else 0.01
	var past: float = bound - step if is_max else bound + step
	assert_true(_holds(sim, key, bound), "%s holds at %s" % [key, bound])
	assert_false(_holds(sim, key, past), "%s does not hold at %s" % [key, past])


func _holds(sim: Simulation, key: String, value: Variant) -> bool:
	var def: HeadlineDef = HeadlineDef.new()
	def.when[key] = value
	return HeadlineConditions.state_holds(def, sim.world, sim.db)


func test_register_follows_the_phase() -> void:
	var sim: Simulation = _sim([
		Fixtures.headline("h_inst", HeadlineDef.STREAM_CONSEQUENCE,
			{"register": HeadlineDef.REGISTER_INSTITUTIONAL,
			"on": {"event": SimEvent.REGION_CONTROLLED}}),
		Fixtures.headline("h_open", HeadlineDef.STREAM_CONSEQUENCE,
			{"register": HeadlineDef.REGISTER_EMERGENCY,
			"on": {"event": SimEvent.REGION_CONTROLLED}}),
		Fixtures.headline("h_any", HeadlineDef.STREAM_CONSEQUENCE,
			{"register": HeadlineDef.REGISTER_ANY,
			"on": {"event": SimEvent.REGION_CONTROLLED}}),
	])
	var controlled: Array[SimEvent] = _events([_event(SimEvent.REGION_CONTROLLED,
		{"region": ORIGIN})])

	sim.world.phase = World.Phase.EMERGENT
	var quiet: Array[String] = _tick_ids(sim, controlled)
	assert_false(quiet.has("h_open"), "the emergency register waits for Open")

	sim.world.phase = World.Phase.OPEN
	sim.world.day += 1
	var loud: Array[String] = _tick_ids(sim, controlled)
	assert_false(loud.has("h_inst"), "and the institutional one stops there")
	assert_true(quiet.size() == 1 and loud.size() == 1, "one line either way")


# ---------------------------------------------------------------- how often


func test_cooldown_and_max_fires() -> void:
	var sim: Simulation = _sim([
		Fixtures.headline("h_cool", HeadlineDef.STREAM_CONSEQUENCE,
			{"on": {"event": SimEvent.REGION_CONTROLLED}, "cooldown_days": 5}),
	])
	var controlled: Array[SimEvent] = _events([_event(SimEvent.REGION_CONTROLLED,
		{"region": ORIGIN})])
	sim.world.day = 10
	assert_eq(_tick_ids(sim, controlled).size(), 1)
	sim.world.day = 14
	assert_eq(_tick_ids(sim, controlled).size(), 0, "four days is inside the cooldown")
	sim.world.day = 15
	assert_eq(_tick_ids(sim, controlled).size(), 1, "five days is not")

	var once: Simulation = _sim([
		Fixtures.headline("h_once", HeadlineDef.STREAM_CONSEQUENCE,
			{"on": {"event": SimEvent.REGION_CONTROLLED}, "max_fires": 1}),
	])
	assert_eq(_tick_ids(once, controlled).size(), 1)
	once.world.day += 100
	assert_eq(_tick_ids(once, controlled).size(), 0, "once is once")


func test_fallback_yields_to_a_specific_headline() -> void:
	var sim: Simulation = _sim([
		Fixtures.headline("h_grip", HeadlineDef.STREAM_CONSEQUENCE,
			{"on": {"event": SimEvent.NODE_PURCHASED, "data": {"node": "fx_grip"}}}),
		Fixtures.headline("h_any_node", HeadlineDef.STREAM_CONSEQUENCE,
			{"on": {"event": SimEvent.NODE_PURCHASED}, "fallback": true}),
	])
	assert_eq(_tick_ids(sim, _events([_event(SimEvent.NODE_PURCHASED,
		{"node": "fx_grip", "cost": 3.0})])), ["h_grip"] as Array[String])
	sim.world.day += 1
	assert_eq(_tick_ids(sim, _events([_event(SimEvent.NODE_PURCHASED,
		{"node": "fx_quiet", "cost": 3.0})])), ["h_any_node"] as Array[String],
		"the line that fits any of them is for the ones nobody wrote")


func test_urgent_events_go_first_and_the_cap_holds() -> void:
	var sim: Simulation = _sim([
		Fixtures.headline("h_seed", HeadlineDef.STREAM_CONSEQUENCE,
			{"on": {"event": SimEvent.REGION_SEEDED}}),
		Fixtures.headline("h_found", HeadlineDef.STREAM_REACTION,
			{"on": {"event": SimEvent.DISCOVERED}}),
	])
	assert_eq(sim.db.balance.headlines_max_per_tick, 2, "the fixture keeps the shipped cap")
	var fired: Array[String] = _tick_ids(sim, _events([
		_seeded("fx_birch"), _seeded("fx_cedar"), _seeded("fx_dogwood"),
		_event(SimEvent.DISCOVERED, {"cause": SimEvent.CAUSE_SCRUTINY}),
	]))
	assert_eq(fired, ["h_found", "h_seed"] as Array[String],
		"the discovery is never crowded out, and the cap stops the rest")


## §3.6: the same seed says the same things, and weight decides how often.
func test_selection_is_weighted_and_deterministic() -> void:
	var entries: Array = [
		Fixtures.headline("h_light", HeadlineDef.STREAM_CONSEQUENCE,
			{"on": {"event": SimEvent.REGION_CONTROLLED}, "weight": 1}),
		Fixtures.headline("h_heavy", HeadlineDef.STREAM_CONSEQUENCE,
			{"on": {"event": SimEvent.REGION_CONTROLLED}, "weight": 3}),
	]
	var first: Array[String] = _selections(entries, 400)
	var heavy: int = 0
	for id: String in first:
		if id == "h_heavy":
			heavy += 1
	var share: float = float(heavy) / float(first.size())
	assert_between(share, 0.65, 0.85, "three parts in four, within the noise of 400 rolls")
	assert_eq(_selections(entries, 400), first, "seed %d twice is the same sequence" % SEED)


## `count` selections from a fresh system, one per day so nothing is on cooldown.
func _selections(entries: Array, count: int) -> Array[String]:
	var sim: Simulation = _sim(entries)
	var controlled: Array[SimEvent] = _events([_event(SimEvent.REGION_CONTROLLED,
		{"region": ORIGIN})])
	var out: Array[String] = []
	for i: int in count:
		sim.world.day += 1
		out.append_array(_tick_ids(sim, controlled))
	return out


# -------------------------------------------------------------- the state pass


func test_filler_pace_and_silence() -> void:
	var sim: Simulation = _sim([
		Fixtures.headline("h_filler", HeadlineDef.STREAM_FILLER, {"when": {}}),
	])
	var none: Array[SimEvent] = _events([])
	sim.world.phase = World.Phase.COVERT
	sim.world.day = 1
	assert_eq(_tick_ids(sim, none), ["h_filler"] as Array[String], "filler on the first day")
	for day: int in range(2, 6):
		sim.world.day = day
		assert_eq(_tick_ids(sim, none).size(), 0, "covert holds them five days apart")

	# Three dark regions stretch the next gap by int(3 × 0.4) = 1 day. The gap is
	# decided when the line fires, so they go dark before it does.
	for i: int in [2, 3, 4]:
		sim.world.regions[i].dark = true
	sim.world.day = 6
	assert_eq(_tick_ids(sim, none).size(), 1)
	sim.world.day = 11
	assert_eq(_tick_ids(sim, none).size(), 0, "5 + int(1.2) is six days, not five")
	sim.world.day = 12
	assert_eq(_tick_ids(sim, none).size(), 1)


func test_filler_is_silenced_by_a_loud_world() -> void:
	var sim: Simulation = _sim([
		Fixtures.headline("h_filler", HeadlineDef.STREAM_FILLER, {"when": {}}),
	])
	sim.world.day = 40
	sim.world.regions[2].deaths = sim.db.population_total \
		* sim.db.balance.headlines_filler_silence_deaths_share
	assert_eq(_tick_ids(sim, _events([])).size(), 0, "nobody files a colour piece")


func test_reaction_gap_applies_to_state_triggers_only() -> void:
	var sim: Simulation = _sim([
		Fixtures.headline("h_state", HeadlineDef.STREAM_REACTION, {"when": {}}),
		Fixtures.headline("h_event", HeadlineDef.STREAM_REACTION,
			{"on": {"event": SimEvent.DISCOVERED}}),
	])
	var none: Array[SimEvent] = _events([])
	sim.world.day = 10
	# The discovery is news whenever it happens: the event reaction fires on the
	# same day as a state one, and only the state one waits out the gap.
	assert_eq(_tick_ids(sim, _events([_event(SimEvent.DISCOVERED,
		{"cause": SimEvent.CAUSE_DEATHS})])), ["h_event", "h_state"] as Array[String])
	sim.world.day = 12
	assert_eq(_tick_ids(sim, none).size(), 0, "two days is inside the three-day gap")
	sim.world.day = 13
	assert_eq(_tick_ids(sim, none), ["h_state"] as Array[String])


func test_no_state_headline_before_an_origin() -> void:
	var sim: Simulation = Fixtures.sim_with_headlines([
		Fixtures.headline("h_filler", HeadlineDef.STREAM_FILLER, {"when": {}}),
	], SEED)
	sim.world.day = 5
	assert_eq(_tick_ids(sim, _events([])).size(), 0, "there is no run to narrate yet")


func test_outcome_tick_ends_with_the_outcome_line() -> void:
	var sim: Simulation = _sim([
		Fixtures.headline("h_filler", HeadlineDef.STREAM_FILLER, {"when": {}}),
		Fixtures.headline("h_seed", HeadlineDef.STREAM_CONSEQUENCE,
			{"on": {"event": SimEvent.REGION_SEEDED}}),
		Fixtures.headline("h_end", HeadlineDef.STREAM_CONSEQUENCE,
			{"on": {"event": SimEvent.OUTCOME_REACHED}}),
	])
	sim.world.day = 50
	var fired: Array[String] = _tick_ids(sim, _events([
		_seeded("fx_birch"),
		_event(SimEvent.OUTCOME_REACHED, {"outcome": "win_ascendance"}),
	]))
	assert_eq(fired, ["h_end"] as Array[String], "the last line of a run is how it ended")


# --------------------------------------------------------------- the event


func test_headline_event_carries_standard_and_event_args() -> void:
	var sim: Simulation = _sim([
		Fixtures.headline("h_seed", HeadlineDef.STREAM_CONSEQUENCE,
			{"on": {"event": SimEvent.REGION_SEEDED}}),
	])
	var fired: Array[SimEvent] = sim.headlines.on_tick(sim.world, sim.db,
		_events([_seeded("fx_birch")]))
	assert_eq(fired.size(), 1)
	var data: Dictionary = fired[0].data
	for field: String in [SimEvent.FIELD_HEADLINE, SimEvent.FIELD_STREAM, "day", "regions",
			"dark", "share", "deaths", "containment", "compute", "region", "from", "link_kind",
			"continent"]:
		assert_true(data.has(field), "the line may spell out %s" % field)
	assert_eq(str(data["region"]), "fx_birch")
	assert_eq(str(data["continent"]), "west", "the region's continent comes with it")
	assert_eq(fired[0].day, sim.world.day)


## §3.7: `harm_burst` carries the wave, which is the number the line is about.
func test_an_event_field_wins_over_the_standard_one() -> void:
	var sim: Simulation = _sim([
		Fixtures.headline("h_burst", HeadlineDef.STREAM_CONSEQUENCE,
			{"on": {"event": SimEvent.HARM_BURST}}),
	])
	var fired: Array[SimEvent] = sim.headlines.on_tick(sim.world, sim.db,
		_events([_event(SimEvent.HARM_BURST, {"node": "fx_burst", "deaths": 4200.0})]))
	assert_eq(float(fired[0].data["deaths"]), 4200.0)


## §3.1: the system reads the world and never writes it.
func test_headlines_do_not_move_the_state_hash() -> void:
	var quiet: Simulation = Fixtures.sim_with_headlines([], 3)
	var loud: Simulation = Fixtures.sim_with_headlines([
		Fixtures.headline("h_filler", HeadlineDef.STREAM_FILLER, {"when": {}}),
		Fixtures.headline("h_seed", HeadlineDef.STREAM_CONSEQUENCE,
			{"on": {"event": SimEvent.REGION_SEEDED}}),
	], 3)
	for sim: Simulation in [quiet, loud]:
		sim.apply(ChooseOriginCommand.new(ORIGIN))
		for i: int in 40:
			sim.tick()
	assert_eq(loud.state_hash(), quiet.state_hash())
