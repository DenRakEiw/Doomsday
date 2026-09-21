extends GutTest
## S1.5 — being found, and the track that closes in afterwards.

var system: ContainmentSystem
var events: Array[SimEvent]


func before_each() -> void:
	system = ContainmentSystem.new()
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


func _discovered() -> Simulation:
	var sim: Simulation = Fixtures.sim_with_origin()
	sim.world.discovered = true
	sim.world.discovery_day = 0
	return sim


func test_containment_does_not_grow_before_discovery() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	for i: int in 200:
		if sim.world.discovered:
			break
		_run(sim)
		sim.world.day += 1
		assert_eq(sim.world.factions[0].containment, 0.0)


func test_containment_does_not_grow_on_the_day_of_discovery() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	_force(sim, "discovery", ModifierDef.Op.MUL, 20.0)
	sim.world.regions[1].deaths = 30000.0
	sim.world.regions[1].alive -= 30000.0
	_run(sim)
	assert_true(sim.world.discovered)
	assert_eq(sim.world.factions[0].containment, 0.0, "the world needs a day to react")
	_run(sim)
	assert_gt(sim.world.factions[0].containment, 0.0)


func test_deaths_above_the_threshold_discover_without_a_roll() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	# 0.0001 of 255 000 000 people.
	sim.world.regions[1].deaths = 30000.0
	sim.world.regions[1].alive -= 30000.0
	var before: String = sim.world.rng.state_string()
	_run(sim)
	assert_true(sim.world.discovered)
	assert_eq(sim.world.discovery_day, 0)
	assert_eq(events[0].type, SimEvent.DISCOVERED)
	assert_eq(events[0].data["cause"], SimEvent.CAUSE_DEATHS)
	assert_eq(sim.world.rng.state_string(), before, "certainty costs no roll")


func test_a_discovery_stat_of_zero_means_no_risk_at_all() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	_force(sim, "discovery", ModifierDef.Op.MUL, 0.0)
	for i: int in 2000:
		_run(sim)
		sim.world.day += 1
	assert_false(sim.world.discovered)
	assert_eq(sim.world.rng.state_string(), SimRng.from_seed(1).state_string(),
		"a risk of zero is never rolled")


func test_footprint_brings_discovery_forward() -> void:
	assert_lt(_mean_discovery_day(8.0), _mean_discovery_day(0.0),
		"being visible is what gets the agent found")


const _SEEDS: int = 10
const _LIMIT: int = 3000


func _mean_discovery_day(footprint: float) -> float:
	var total: float = 0.0
	for seed_value: int in range(1, _SEEDS + 1):
		var sim: Simulation = Fixtures.sim_with_origin("fx_alder", seed_value)
		if footprint > 0.0:
			_force(sim, "footprint", ModifierDef.Op.ADD, footprint)
		var day: int = _LIMIT
		for i: int in _LIMIT:
			sim.world.day += 1
			_run(sim)
			if sim.world.discovered:
				day = sim.world.discovery_day
				break
		total += float(day)
	return total / float(_SEEDS)


func test_capacity_falls_with_deaths() -> void:
	var healthy: Simulation = _discovered()
	_run(healthy)
	var full: float = healthy.world.factions[0].containment

	var emptied: Simulation = _discovered()
	# fx_fir is research tier 3 and weighs heavily; losing it slows the hunt.
	emptied.world.regions[6].deaths = float(emptied.world.regions[6].def.population)
	emptied.world.regions[6].alive = 0.0
	_run(emptied)
	assert_lt(emptied.world.factions[0].containment, full)


func test_capacity_falls_with_control() -> void:
	var free: Simulation = _discovered()
	_run(free)
	var full: float = free.world.factions[0].containment

	var held: Simulation = _discovered()
	held.world.regions[6].control = 1.0
	_run(held)
	assert_lt(held.world.factions[0].containment, full)


func test_footprint_harm_and_share_all_push_containment() -> void:
	var quiet: Simulation = _discovered()
	_run(quiet)
	var base: float = quiet.world.factions[0].containment

	for target: String in ["footprint", "harm"]:
		var loud: Simulation = _discovered()
		_force(loud, target, ModifierDef.Op.ADD, 4.0)
		_run(loud)
		assert_gt(loud.world.factions[0].containment, base, "%s raises the pressure" % target)

	var wide: Simulation = _discovered()
	for i: int in range(1, wide.world.regions.size()):
		wide.world.regions[i].penetration = 1.0
	_run(wide)
	assert_gt(wide.world.factions[0].containment, base, "world share raises it too")


func test_containment_growth_can_be_slowed() -> void:
	var loud: Simulation = _discovered()
	_run(loud)
	var quiet: Simulation = _discovered()
	_force(quiet, "containment_growth", ModifierDef.Op.MUL, 0.6)
	_run(quiet)
	assert_almost_eq(quiet.world.factions[0].containment,
		loud.world.factions[0].containment * 0.6, 1e-9)


func test_each_threshold_is_announced_once_in_order() -> void:
	var sim: Simulation = _discovered()
	_force(sim, "containment_growth", ModifierDef.Op.MUL, 20.0)
	var announced: Array[float] = []
	for i: int in 2000:
		sim.world.day += 1
		_run(sim)
		for event: SimEvent in events:
			if event.type == SimEvent.CONTAINMENT_THRESHOLD:
				announced.append(event.data["threshold"])
				assert_eq(event.data["faction"], World.FACTION_UNIFIED)
		if sim.world.factions[0].containment >= 1.0:
			break
	var expected: Array[float] = sim.db.balance.containment_thresholds
	assert_eq(announced, expected, "each threshold once, in ascending order")


func test_containment_never_passes_one() -> void:
	var sim: Simulation = _discovered()
	_force(sim, "containment_growth", ModifierDef.Op.MUL, 20.0)
	for i: int in 3000:
		sim.world.day += 1
		_run(sim)
	assert_eq(sim.world.factions[0].containment, 1.0)


func test_nothing_happens_before_an_origin_is_chosen() -> void:
	var sim: Simulation = Fixtures.sim()
	sim.world.day = 500
	_run(sim)
	assert_false(sim.world.discovered)
