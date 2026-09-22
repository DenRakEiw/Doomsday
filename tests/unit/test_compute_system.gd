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


## Anomalies spawn on a roll; a rate high enough to clamp the chance to 1 makes
## the test about the formula rather than about the seed.
func _always_spawn(sim: Simulation) -> void:
	_force(sim, "anomaly_rate", ModifierDef.Op.MUL, 100.0)


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
	var sim: Simulation = Fixtures.sim_with_origin()
	sim.world.regions[1].penetration = 0.5
	_always_spawn(sim)
	_run(sim)
	assert_eq(sim.world.anomalies.size(), 1)
	# 2.0 × (0.5 + 0.25 × compute tier 4), no Footprint yet.
	assert_almost_eq(sim.world.anomalies[0].value, 3.0, 1e-9)
	assert_eq(sim.world.anomalies[0].spawn_day, 0)
	assert_eq(sim.world.anomalies[0].expires_day, sim.db.balance.anomaly_lifetime_days)
	assert_eq(events[0].type, SimEvent.ANOMALY_SPAWNED)
	assert_eq(events[0].data["region"], "fx_alder")


func test_footprint_makes_anomalies_worth_more() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	sim.world.regions[1].penetration = 0.5
	_always_spawn(sim)
	_force(sim, "footprint", ModifierDef.Op.ADD, 5.0)
	_run(sim)
	# × (1 + 0.5 × min(1, 5 / 10))
	assert_almost_eq(sim.world.anomalies[0].value, 3.75, 1e-9)


func test_anomalies_never_exceed_the_cap_or_double_up() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	for i: int in range(1, sim.world.regions.size()):
		sim.world.regions[i].penetration = 0.5
	_always_spawn(sim)
	for i: int in 5:
		_run(sim)
		sim.world.day += 1
	assert_eq(sim.world.anomalies.size(), sim.db.balance.anomaly_max_active)
	var seen: Dictionary[int, bool] = {}
	for anomaly: Anomaly in sim.world.anomalies:
		assert_false(seen.has(anomaly.region), "never two anomalies in one region")
		seen[anomaly.region] = true


func test_no_anomaly_in_a_clean_or_dark_region() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	sim.world.regions[1].penetration = 0.0
	sim.world.regions[2].penetration = 0.5
	sim.world.regions[2].dark = true
	_always_spawn(sim)
	_run(sim)
	assert_eq(sim.world.anomalies.size(), 0)


func test_an_anomaly_expires_on_its_day_with_an_event() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	sim.world.regions[1].penetration = 0.5
	_always_spawn(sim)
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
	var sim: Simulation = Fixtures.sim_with_origin()
	sim.world.regions[1].penetration = 0.5
	_always_spawn(sim)
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
	var sim: Simulation = Fixtures.sim_with_origin()
	sim.world.regions[1].penetration = 0.5
	_always_spawn(sim)
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
