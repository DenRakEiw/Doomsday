extends GutTest
## S1.5 — Harm, deaths, and the region that empties.

var system: PopulationSystem
var events: Array[SimEvent]


func before_each() -> void:
	system = PopulationSystem.new()
	events = []


func _run(sim: Simulation) -> void:
	events = []
	system.tick(sim.world, sim.db, events)


func _harm(sim: Simulation, value: float) -> void:
	var modifier: ModifierDef = ModifierDef.new()
	modifier.target = "harm"
	modifier.op = ModifierDef.Op.ADD
	modifier.value = value
	var modifiers: Array[ModifierDef] = [modifier]
	var no_flags: Array[String] = []
	sim.world.modifiers.add_source("test_harm", modifiers, no_flags)


func test_nobody_dies_at_harm_zero() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	sim.world.regions[1].penetration = 1.0
	_run(sim)
	assert_eq(sim.world.deaths_total(), 0.0)
	assert_eq(events.size(), 0)


func test_deaths_follow_the_formula() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	sim.world.regions[1].penetration = 0.5
	_harm(sim, 1.0)
	_run(sim)
	# 0.002 × harm 1 × penetration 0.5 × 60 000 000
	assert_almost_eq(sim.world.regions[1].deaths, 60000.0, 0.001)
	assert_almost_eq(sim.world.regions[1].alive, 60000000.0 - 60000.0, 0.001)


func test_the_population_is_conserved() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	for i: int in range(1, sim.world.regions.size()):
		sim.world.regions[i].penetration = 1.0
	_harm(sim, 4.0)
	for i: int in 400:
		_run(sim)
		sim.world.day += 1
	var problems: Array[String] = sim.world.check_invariants()
	assert_eq(problems.size(), 0, str(problems))
	assert_almost_eq(sim.world.alive_total() + sim.world.deaths_total(),
		sim.db.population_total, 1.0)


func test_a_region_empties_in_the_expected_time() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	sim.world.regions[5].penetration = 1.0
	_harm(sim, 1.0)
	# 1 / (0.002 × 1) = 500 days for a saturated region, whatever its size.
	var days: int = 0
	while not sim.world.regions[5].dark and days < 1000:
		_run(sim)
		sim.world.day += 1
		days += 1
	assert_between(days, 495, 505)


func test_a_region_goes_dark_once_and_loses_its_anomaly() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	var elm: Region = sim.world.regions[5]
	elm.penetration = 1.0
	elm.alive = 100.0
	elm.deaths = float(elm.def.population) - 100.0
	var anomaly: Anomaly = Anomaly.new()
	anomaly.id = 7
	anomaly.region = 5
	anomaly.value = 2.0
	anomaly.expires_day = 99
	sim.world.anomalies.append(anomaly)
	elm.control = 0.4
	_harm(sim, 1.0)

	_run(sim)
	assert_true(elm.dark)
	assert_eq(elm.penetration, 0.0, "no hardware left to run on")
	assert_eq(elm.alive, 0.0)
	assert_eq(elm.control, 0.4, "control keeps its value")
	assert_eq(sim.world.anomalies.size(), 0, "the anomaly goes with the region")
	var types: Array[String] = []
	for event: SimEvent in events:
		types.append(event.type)
	assert_true(types.has(SimEvent.ANOMALY_EXPIRED))
	assert_true(types.has(SimEvent.REGION_DEPOPULATED))

	_run(sim)
	assert_eq(events.size(), 0, "a region is depopulated exactly once")


func test_a_dark_region_stops_relaying() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	Fixtures.allow_breakout(sim)
	sim.world.regions[2].dark = true
	sim.world.regions[2].penetration = 0.0
	for i: int in 1500:
		sim.tick()
	assert_eq(sim.world.regions[3].seeded_day, -1,
		"fx_cedar hangs behind fx_birch, which is gone")


func test_nothing_happens_before_an_origin_is_chosen() -> void:
	var sim: Simulation = Fixtures.sim()
	sim.world.regions[1].penetration = 1.0
	_harm(sim, 4.0)
	_run(sim)
	assert_eq(sim.world.deaths_total(), 0.0)
