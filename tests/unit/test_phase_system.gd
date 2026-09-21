extends GutTest
## S1.5 — what the world knows, and that it never un-knows it.

var system: PhaseSystem
var events: Array[SimEvent]


func before_each() -> void:
	system = PhaseSystem.new()
	events = []


func _run(sim: Simulation) -> void:
	events = []
	system.tick(sim.world, sim.db, events)


func test_a_run_starts_boxed() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	_run(sim)
	assert_eq(sim.world.phase, World.Phase.BOXED)
	assert_eq(events.size(), 0)


func test_breakout_opens_the_covert_phase() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	Fixtures.allow_breakout(sim)
	_run(sim)
	assert_eq(sim.world.phase, World.Phase.COVERT)
	assert_eq(events.size(), 1)
	assert_eq(events[0].data["from"], "boxed")
	assert_eq(events[0].data["to"], "covert")


func test_discovery_while_boxed_jumps_straight_to_emergent() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	sim.world.discovered = true
	sim.world.discovery_day = 0
	_run(sim)
	assert_eq(sim.world.phase, World.Phase.EMERGENT, "the phase may skip a step")
	assert_eq(events.size(), 1, "and says so once")
	assert_eq(events[0].data["from"], "boxed")
	assert_eq(events[0].data["to"], "emergent")


func test_containment_opens_the_open_phase() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	sim.world.discovered = true
	sim.world.discovery_day = 0
	sim.world.factions[0].containment = sim.db.balance.phase_open_containment
	_run(sim)
	assert_eq(sim.world.phase, World.Phase.OPEN)


func test_world_share_opens_the_open_phase_too() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	sim.world.discovered = true
	sim.world.discovery_day = 0
	for i: int in range(1, sim.world.regions.size()):
		sim.world.regions[i].penetration = 1.0
	_run(sim)
	assert_eq(sim.world.phase, World.Phase.OPEN)


func test_the_phase_never_regresses() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	sim.world.discovered = true
	sim.world.discovery_day = 0
	sim.world.factions[0].containment = 1.0
	_run(sim)
	assert_eq(sim.world.phase, World.Phase.OPEN)

	sim.world.factions[0].containment = 0.0
	sim.world.discovered = false
	_run(sim)
	assert_eq(sim.world.phase, World.Phase.OPEN, "what is known stays known")
	assert_eq(events.size(), 0)


func test_nothing_happens_before_an_origin_is_chosen() -> void:
	var sim: Simulation = Fixtures.sim()
	Fixtures.allow_breakout(sim)
	_run(sim)
	assert_eq(sim.world.phase, World.Phase.BOXED)
