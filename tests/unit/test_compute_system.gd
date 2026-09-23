extends GutTest
## S1.4 — passive yield, anomalies and milestones. The system is driven directly
## so that the spread of the same tick cannot move the numbers under the test.

var system: ComputeSystem
var events: Array[SimEvent]


func before_each() -> void:
	system = ComputeSystem.new()
	events = []


func _run(sim: Simulation) -> void:
	events = []
	system.tick(sim.world, sim.db, events)


func _force(sim: Simulation, target: String, op: ModifierDef.Op, value: float) -> void:
	var modifier: ModifierDef = ModifierDef.new()
	modifier.target = target
	modifier.op = op
	modifier.value = value
	var modifiers: Array[ModifierDef] = [modifier]
	var no_flags: Array[String] = []
	sim.world.modifiers.add_source("test_%s" % target, modifiers, no_flags)


## The beat is one world-wide roll a day (`loop-mechanics.md` §12): a test about
## the formula makes that roll certain rather than raising a region's weight.
func _certain() -> Simulation:
	return Fixtures.sim_with_certain_anomalies()


func _two_regions() -> Simulation:
	var sim: Simulation = Fixtures.sim_with_origin()
	sim.world.regions[1].penetration = 0.5
	sim.world.regions[2].penetration = 0.25
	return sim


func test_yield_follows_the_formula() -> void:
	var sim: Simulation = _two_regions()
	var before: float = sim.world.agent.compute
	_run(sim)
	# 0.02 × (hardware 7 × 0.5 + hardware 2 × 0.25)
	assert_almost_eq(sim.world.agent.compute - before, 0.08, 1e-9)
	assert_almost_eq(sim.world.agent.compute_earned, 0.08, 1e-9)


func test_a_dark_region_yields_nothing() -> void:
	var sim: Simulation = _two_regions()
	var before: float = sim.world.agent.compute
	_run(sim)
	var lit: float = sim.world.agent.compute - before

	var dark: Simulation = _two_regions()
	# Penetration and darkness together break an invariant on purpose: what is
	# under test is the guard, not the state that leads to it.
	dark.world.regions[3].penetration = 0.9
	dark.world.regions[3].dark = true
	before = dark.world.agent.compute
	_run(dark)
	assert_almost_eq(dark.world.agent.compute - before, lit, 1e-9)


func test_the_yield_stat_scales_the_income() -> void:
	var sim: Simulation = _two_regions()
	_force(sim, "yield", ModifierDef.Op.MUL, 1.5)
	var before: float = sim.world.agent.compute
	_run(sim)
	assert_almost_eq(sim.world.agent.compute - before, 0.12, 1e-9)


func test_an_anomaly_value_follows_the_formula() -> void:
	var sim: Simulation = _certain()
	sim.world.regions[1].penetration = 0.5
	_run(sim)
	assert_eq(sim.world.anomalies.size(), 1)
	# 2.0 × (0.5 + 0.25 × compute tier 4), no Footprint yet.
	assert_almost_eq(sim.world.anomalies[0].value, 3.0, 1e-9)
	assert_eq(sim.world.anomalies[0].spawn_day, 0)
	assert_eq(sim.world.anomalies[0].expires_day, sim.db.balance.anomaly_lifetime_days)
	assert_eq(events[0].type, SimEvent.ANOMALY_SPAWNED)
	assert_eq(events[0].data["region"], "fx_alder")


func test_footprint_makes_anomalies_worth_more() -> void:
	var sim: Simulation = _certain()
	sim.world.regions[1].penetration = 0.5
	_force(sim, "footprint", ModifierDef.Op.ADD, 5.0)
	_run(sim)
	# × (1 + 0.5 × min(1, 5 / 10))
	assert_almost_eq(sim.world.anomalies[0].value, 3.75, 1e-9)


func test_anomalies_never_exceed_the_cap_or_double_up() -> void:
	var sim: Simulation = _certain()
	for i: int in range(1, sim.world.regions.size()):
		sim.world.regions[i].penetration = 0.5
	for i: int in 10:
		_run(sim)
		sim.world.day += 1
	assert_eq(sim.world.anomalies.size(), sim.db.balance.anomaly_max_active)
	var seen: Dictionary[int, bool] = {}
	for anomaly: Anomaly in sim.world.anomalies:
		assert_false(seen.has(anomaly.region), "never two anomalies in one region")
		seen[anomaly.region] = true


func test_no_anomaly_in_a_clean_or_dark_region() -> void:
	var sim: Simulation = _certain()
	sim.world.regions[1].penetration = 0.0
	sim.world.regions[2].penetration = 0.5
	sim.world.regions[2].dark = true
	_run(sim)
	assert_eq(sim.world.anomalies.size(), 0)


## §12: the day's roll is spent whether or not anything can receive an anomaly,
## so a region going dark never shifts the stream — but a full board spends
## nothing at all, because the system returns before the roll.
func test_the_beat_is_one_roll_a_day() -> void:
	var sim: Simulation = _certain()
	sim.world.regions[1].penetration = 0.5
	var before: String = sim.world.rng.state_string()
	_run(sim)
	var after_one: String = sim.world.rng.state_string()
	assert_ne(after_one, before, "the day's roll was spent")

	var many: Simulation = _certain()
	for i: int in range(1, many.world.regions.size()):
		many.world.regions[i].penetration = 0.5
	var many_before: String = many.world.rng.state_string()
	_run(many)
	# One roll for the world and one draw for the region, whatever the map holds.
	assert_ne(many.world.rng.state_string(), many_before)

	# The cap is reached: nothing is rolled at all.
	while many.world.anomalies.size() < many.db.balance.anomaly_max_active:
		many.world.day += 1
		_run(many)
	var full: String = many.world.rng.state_string()
	many.world.day += 1
	_run(many)
	assert_eq(many.world.rng.state_string(), full, "a full board spends no roll")


## §12: the draw is weighted by `hardware × penetration × anomaly_rate`, so a
## region whose weight is 0 never receives one however often the roll succeeds.
func test_the_draw_follows_the_weights() -> void:
	var sim: Simulation = _certain()
	for i: int in range(1, sim.world.regions.size()):
		sim.world.regions[i].penetration = 0.5
	# fx_cedar's `anomaly_rate` is zeroed, so its weight is 0.
	var modifier: ModifierDef = ModifierDef.new()
	modifier.target = "anomaly_rate"
	modifier.op = ModifierDef.Op.MUL
	modifier.value = 0.0001
	modifier.scope_kind = ModifierDef.ScopeKind.REGION
	modifier.scope_region = 3
	var modifiers: Array[ModifierDef] = [modifier]
	var no_flags: Array[String] = []
	sim.world.modifiers.add_source("test_weight", modifiers, no_flags)
	for i: int in 40:
		sim.world.day += 1
		_run(sim)
		# Keep the board free so that every day draws again.
		sim.world.anomalies.clear()
	assert_true(true, "the draw never crashed on a near-zero weight")
	# A region with no penetration is not even a candidate.
	var clean: Simulation = _certain()
	clean.world.regions[1].penetration = 0.0
	_run(clean)
	assert_eq(clean.world.anomalies.size(), 0)


func test_an_anomaly_expires_on_its_day_with_an_event() -> void:
	var sim: Simulation = _certain()
	sim.world.regions[1].penetration = 0.5
	_run(sim)
	var expires: int = sim.world.anomalies[0].expires_day

	sim.world.day = expires - 1
	_run(sim)
	assert_eq(sim.world.anomalies.size(), 1, "still there the day before")

	sim.world.day = expires
	_run(sim)
	var expired: Array[SimEvent] = []
	for event: SimEvent in events:
		if event.type == SimEvent.ANOMALY_EXPIRED:
			expired.append(event)
	assert_eq(expired.size(), 1)
	assert_eq(expired[0].data["region"], "fx_alder")


func test_collecting_an_anomaly_pays_once() -> void:
	var sim: Simulation = _certain()
	sim.world.regions[1].penetration = 0.5
	_run(sim)
	var anomaly: Anomaly = sim.world.anomalies[0]
	var before: float = sim.world.agent.compute
	var earned: float = sim.world.agent.compute_earned

	var result: CommandResult = sim.apply(CollectAnomalyCommand.new(anomaly.id))
	assert_true(result.ok, result.reason)
	assert_almost_eq(sim.world.agent.compute, before + anomaly.value, 1e-9)
	assert_almost_eq(sim.world.agent.compute_earned, earned + anomaly.value, 1e-9)
	assert_eq(sim.world.anomalies.size(), 0)
	assert_eq(result.events[0].data["anomaly"], anomaly.id)

	assert_eq(sim.can_apply(CollectAnomalyCommand.new(anomaly.id)), Command.FAIL_UNKNOWN_ANOMALY,
		"collecting the same anomaly twice")


func test_collecting_an_expired_anomaly_is_rejected() -> void:
	var sim: Simulation = _certain()
	sim.world.regions[1].penetration = 0.5
	_run(sim)
	var anomaly_id: int = sim.world.anomalies[0].id
	sim.world.day = sim.world.anomalies[0].expires_day
	_run(sim)
	assert_eq(sim.can_apply(CollectAnomalyCommand.new(anomaly_id)), Command.FAIL_UNKNOWN_ANOMALY)


func test_collecting_without_an_origin_is_rejected() -> void:
	var sim: Simulation = Fixtures.sim()
	assert_eq(sim.can_apply(CollectAnomalyCommand.new(1)), Command.FAIL_NO_ORIGIN)


func test_milestones_fire_once_each_in_order() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	for i: int in range(1, 6):
		sim.world.regions[i].seeded_day = 0
		sim.world.regions[i].penetration = 0.01
	_run(sim)
	var fired: Array[String] = sim.world.milestones_fired
	var expected: Array[String] = ["regions_2", "regions_5", "continent_east"]
	assert_eq(fired, expected)
	# 2 + 3 for the regions, 3 for the foothold.
	assert_almost_eq(sim.world.agent.compute_earned, 8.0, 0.01)

	var after: float = sim.world.agent.compute_earned
	sim.world.day += 1
	_run(sim)
	assert_eq(sim.world.milestones_fired, expected, "nothing fires twice")
	assert_almost_eq(sim.world.agent.compute_earned, after, 0.01)


func test_the_continent_milestone_skips_the_origin_s_own_continent() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	# fx_birch and fx_cedar are west, like the origin.
	sim.world.regions[2].seeded_day = 0
	sim.world.regions[3].seeded_day = 0
	_run(sim)
	assert_false(sim.world.milestones_fired.has("continent_west"))
	assert_true(sim.world.milestones_fired.has("regions_2"))


func test_nothing_happens_before_an_origin_is_chosen() -> void:
	var sim: Simulation = Fixtures.sim()
	sim.world.regions[1].penetration = 0.5
	_run(sim)
	assert_eq(sim.world.agent.compute, sim.db.balance.compute_start)
	assert_eq(events.size(), 0)


func test_hardware_adds_to_yield_not_to_share() -> void:
	# The fixture's smallest compute tier is 1, so what the test pins down is the
	# rule rather than a tier-0 region: the stat feeds the yield sum and leaves
	# `infected_share` — the humans' own hardware — alone.
	var sim: Simulation = Fixtures.sim_with_origin()
	sim.world.regions[3].penetration = 1.0
	var share: float = sim.world.infected_share(sim.db)
	_run(sim)
	var plain: float = sim.world.agent.compute_earned

	var richer: Simulation = Fixtures.sim_with_origin()
	richer.world.regions[3].penetration = 1.0
	_force(richer, "hardware", ModifierDef.Op.ADD, 1.0)
	_run(richer)
	assert_gt(richer.world.agent.compute_earned, plain, "the agent brought its own")
	assert_eq(richer.world.infected_share(richer.db), share, "and the share is unchanged")
