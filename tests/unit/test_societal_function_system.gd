extends GutTest
## S4.5 — Societal Function (opposition.md §8). Fixture balance: gain 0.5 per
## point of pressure, recovery 0.1, deaths weight 50, stages at 10/25/45/70/90.

const ALDER: int = 1
const BIRCH: int = 2

var sim: Simulation
var system: SocietalFunctionSystem
var events: Array[SimEvent]


func before_each() -> void:
	sim = Fixtures.sim_with_origin()
	system = SocietalFunctionSystem.new()
	events = []


func _run() -> void:
	events = []
	system.tick(sim.world, sim.db, events)


func _pressure(value: float, region: int = BIRCH) -> void:
	var modifier: ModifierDef = ModifierDef.new()
	modifier.target = SocietalFunctionSystem.TARGET_PRESSURE
	modifier.op = ModifierDef.Op.ADD
	modifier.value = value
	modifier.scope_kind = ModifierDef.ScopeKind.REGION
	modifier.scope_region = region
	var modifiers: Array[ModifierDef] = [modifier]
	var no_flags: Array[String] = []
	sim.world.modifiers.add_source("test_pressure_%d" % region, modifiers, no_flags)


func test_pressure_raises_the_disorder() -> void:
	_pressure(8.0)
	_run()
	# 0.5 × 8 − 0.1.
	assert_almost_eq(sim.world.regions[BIRCH].society, 3.9, 1e-9)
	assert_eq(sim.world.regions[ALDER].society, 0.0, "only where the pressure is")


func test_recovery_lowers_it_and_stops_at_zero() -> void:
	sim.world.regions[BIRCH].society = 0.25
	_run()
	assert_almost_eq(sim.world.regions[BIRCH].society, 0.15, 1e-9)
	_run()
	_run()
	assert_eq(sim.world.regions[BIRCH].society, 0.0)


func test_the_dead_press_on_a_society() -> void:
	var birch: Region = sim.world.regions[BIRCH]
	birch.deaths = float(birch.def.population) * 0.2
	birch.alive -= birch.deaths
	_run()
	# 0.5 × 50 × 0.2 − 0.1.
	assert_almost_eq(birch.society, 4.9, 1e-9)


func test_disorder_stops_at_one_hundred() -> void:
	sim.world.regions[BIRCH].society = 99.0
	_pressure(50.0)
	_run()
	assert_eq(sim.world.regions[BIRCH].society, 100.0)


func test_a_dark_region_is_left_alone() -> void:
	var birch: Region = sim.world.regions[BIRCH]
	birch.society = 30.0
	birch.dark = true
	_pressure(20.0)
	_run()
	assert_eq(birch.society, 30.0)


func test_the_stage_is_the_number_of_thresholds_reached() -> void:
	var balance: BalanceDef = sim.db.balance
	var cases: Dictionary[float, int] = {0.0: 0, 9.99: 0, 10.0: 1, 25.0: 2, 44.9: 2, 45.0: 3,
		70.0: 4, 90.0: 5, 100.0: 5}
	for value: float in cases:
		assert_eq(SocietalFunctionSystem.stage(value, balance), cases[value], str(value))


func test_a_stage_change_is_announced_both_ways() -> void:
	sim.world.regions[BIRCH].society = 9.95
	_pressure(1.0)
	_run()
	assert_eq(events.size(), 1)
	assert_eq(events[0].type, SimEvent.SOCIETY_STAGE_CHANGED)
	assert_eq(events[0].data, {"region": "fx_birch", "from": 0, "to": 1})
	sim.world.modifiers.remove_source("test_pressure_%d" % BIRCH)
	sim.world.regions[BIRCH].society = 10.05
	_run()
	assert_eq(events[0].data, {"region": "fx_birch", "from": 1, "to": 0})


func test_the_capacity_cut_reaches_the_containment_capacity() -> void:
	sim.world.discovered = true
	var before: float = float(sim.containment_breakdown("ai_labs")[ContainmentSystem.CAPACITY])
	sim.world.regions[ALDER].society = 30.0  # stage 2: × 0.75
	var after: float = float(sim.containment_breakdown("ai_labs")[ContainmentSystem.CAPACITY])
	assert_lt(after, before)
	assert_almost_eq(SocietalFunctionSystem.capacity_mul(30.0, sim.db.balance), 0.75, 1e-12)
	assert_almost_eq(SocietalFunctionSystem.capacity_mul(95.0, sim.db.balance), 0.0, 1e-12,
		"at total collapse the region hunts nobody")


func test_the_yield_cut_spares_the_agents_own_hardware() -> void:
	var alder: Region = sim.world.regions[ALDER]
	alder.penetration = 1.0
	var modifier: ModifierDef = ModifierDef.new()
	modifier.target = "hardware"
	modifier.op = ModifierDef.Op.ADD
	modifier.value = 2.0
	var modifiers: Array[ModifierDef] = [modifier]
	var no_flags: Array[String] = []
	sim.world.modifiers.add_source("test_own_hardware", modifiers, no_flags)
	alder.society = 100.0  # total collapse: the humans' hardware yields nothing
	# The yield alone: the same tick also pays milestones, which are not income.
	ComputeSystem.new().tick(sim.world, sim.db, events)
	var expected: float = 2.0 * sim.world.modifiers.value("yield", alder.def) \
		* sim.db.balance.compute_yield_scale
	assert_almost_eq(sim.world.last_income, expected, 1e-9,
		"the fleets' hardware keeps yielding")
	assert_eq(sim.hardware(ALDER), sim.db.balance.compute_hardware_by_tier[
		alder.def.attr("compute")] + 2.0, "the site-select read is not cut")
