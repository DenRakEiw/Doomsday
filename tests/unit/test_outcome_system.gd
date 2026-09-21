extends GutTest
## S1.5 — how a run ends, and in which order the four endings are tested.

var system: OutcomeSystem
var events: Array[SimEvent]


func before_each() -> void:
	system = OutcomeSystem.new()
	events = []


func _run(sim: Simulation) -> void:
	events = []
	system.tick(sim.world, sim.db, events)


func _empty_the_world(sim: Simulation) -> void:
	for i: int in range(1, sim.world.regions.size()):
		var region: Region = sim.world.regions[i]
		region.deaths = float(region.def.population)
		region.alive = 0.0
		region.dark = true
		region.penetration = 0.0


func test_a_running_game_has_no_outcome() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	_run(sim)
	assert_eq(sim.world.outcome, World.Outcome.NONE)
	assert_eq(events.size(), 0)


func test_an_empty_world_is_extinction() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	_empty_the_world(sim)
	_run(sim)
	assert_eq(sim.world.outcome, World.Outcome.WIN_EXTINCTION)
	assert_eq(events[0].type, SimEvent.OUTCOME_REACHED)
	assert_eq(events[0].data["outcome"], "win_extinction")


func test_every_region_held_or_gone_is_ascendance() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	for i: int in range(1, sim.world.regions.size()):
		sim.world.regions[i].control = 1.0
		sim.world.regions[i].penetration = 1.0
	_run(sim)
	assert_eq(sim.world.outcome, World.Outcome.WIN_ASCENDANCE)


func test_a_dark_region_counts_as_satisfied_for_ascendance() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	for i: int in range(1, sim.world.regions.size()):
		sim.world.regions[i].control = 1.0
		sim.world.regions[i].penetration = 1.0
	var elm: Region = sim.world.regions[5]
	elm.control = 0.0
	elm.dark = true
	elm.penetration = 0.0
	elm.deaths = float(elm.def.population)
	elm.alive = 0.0
	_run(sim)
	assert_eq(sim.world.outcome, World.Outcome.WIN_ASCENDANCE)


func test_one_region_short_is_not_ascendance() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	for i: int in range(1, sim.world.regions.size()):
		sim.world.regions[i].control = 1.0
		sim.world.regions[i].penetration = 1.0
	sim.world.regions[6].control = 0.5
	_run(sim)
	assert_eq(sim.world.outcome, World.Outcome.NONE)


func test_full_containment_is_a_loss() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	sim.world.regions[1].penetration = 0.5
	sim.world.factions[0].containment = 1.0
	_run(sim)
	assert_eq(sim.world.outcome, World.Outcome.LOSE_CONTAINED)


func test_no_hardware_left_is_a_loss() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	sim.world.regions[1].penetration = 0.0
	_run(sim)
	assert_eq(sim.world.outcome, World.Outcome.LOSE_NO_COMPUTE)


func test_a_win_beats_a_loss_reached_on_the_same_tick() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	_empty_the_world(sim)
	sim.world.factions[0].containment = 1.0
	_run(sim)
	assert_eq(sim.world.outcome, World.Outcome.WIN_EXTINCTION,
		"extinction is checked before containment")


func test_an_outcome_is_reported_once() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	_empty_the_world(sim)
	_run(sim)
	assert_eq(events.size(), 1)
	_run(sim)
	assert_eq(events.size(), 0)
