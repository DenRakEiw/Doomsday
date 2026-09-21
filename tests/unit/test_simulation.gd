extends GutTest
## S1.2 — the tick loop, the command path and the outbox, with no systems in
## place yet. An empty simulation must already tick deterministically.


## A system that reports one event per tick, so that a test can watch the outbox.
class ProbeSystem:
	extends SimSystem

	var ticks: int = 0

	func tick(world: World, db: ContentDB, events: Array[SimEvent]) -> void:
		ticks += 1
		events.append(SimEvent.new("probe_tick", world.day, {"ticks": ticks}))


## A command whose acceptance the test decides.
class ProbeCommand:
	extends Command

	var accept: bool = true
	var executed: int = 0

	func type_id() -> String:
		return "probe"

	func validate(sim: Simulation) -> String:
		return "" if accept else "probe_rejected"

	func execute(sim: Simulation, events: Array[SimEvent]) -> void:
		executed += 1
		sim.world.agent.compute += 1.0
		events.append(SimEvent.new("probe_done", sim.world.day, {}))


func test_ticking_an_empty_simulation_changes_only_the_day() -> void:
	var sim: Simulation = Fixtures.sim()
	var before: Dictionary = sim.world.to_dict()
	for i: int in 100:
		assert_true(sim.tick())
	assert_eq(sim.world.day, 100)
	var after: Dictionary = sim.world.to_dict()
	after["day"] = before["day"]
	assert_eq(JSON.stringify(after, "", true, true), JSON.stringify(before, "", true, true))


func test_the_same_seed_gives_the_same_hash() -> void:
	var a: Simulation = Fixtures.sim(4)
	var b: Simulation = Fixtures.sim(4)
	for i: int in 10:
		a.tick()
		b.tick()
	assert_eq(a.state_hash(), b.state_hash())


func test_a_different_seed_gives_a_different_hash() -> void:
	var a: Simulation = Fixtures.sim(4)
	var b: Simulation = Fixtures.sim(5)
	# The generator's state is part of the hash, so the worlds differ even before
	# a system has drawn anything.
	assert_ne(a.state_hash(), b.state_hash())


func test_the_outbox_holds_only_the_last_tick() -> void:
	var sim: Simulation = Fixtures.sim()
	sim.systems.append(ProbeSystem.new())
	sim.tick()
	assert_eq(sim.outbox.size(), 1)
	sim.tick()
	assert_eq(sim.outbox.size(), 1, "the outbox never accumulates")
	assert_eq(sim.outbox[0].day, 2)
	assert_eq(sim.outbox[0].data["ticks"], 2)


func test_systems_run_in_the_order_of_the_list() -> void:
	var sim: Simulation = Fixtures.sim()
	var first: ProbeSystem = ProbeSystem.new()
	var second: ProbeSystem = ProbeSystem.new()
	sim.systems.append(first)
	sim.systems.append(second)
	sim.tick()
	assert_eq(sim.outbox.size(), 2)
	assert_eq(first.ticks, 1)
	assert_eq(second.ticks, 1)


func test_the_system_list_starts_empty() -> void:
	assert_eq(Fixtures.sim().systems.size(), 0, "S1.3 onwards fill it, in the fixed order")


func test_an_accepted_command_is_logged_with_its_day() -> void:
	var sim: Simulation = Fixtures.sim()
	sim.tick()
	sim.tick()
	var command: ProbeCommand = ProbeCommand.new()
	var result: CommandResult = sim.apply(command)
	assert_true(result.ok)
	assert_eq(result.reason, "")
	assert_eq(command.day, 2, "the day it was applied on")
	assert_eq(sim.command_log.size(), 1)
	assert_eq(result.events.size(), 1, "command events travel in the result")
	assert_eq(sim.outbox.size(), 0, "and never in the outbox")


func test_a_rejected_command_changes_nothing() -> void:
	var sim: Simulation = Fixtures.sim()
	var before: String = sim.state_hash()
	var command: ProbeCommand = ProbeCommand.new()
	command.accept = false
	var result: CommandResult = sim.apply(command)
	assert_false(result.ok)
	assert_eq(result.reason, "probe_rejected")
	assert_eq(command.executed, 0)
	assert_eq(sim.command_log.size(), 0, "a rejected command is not logged")
	assert_eq(sim.state_hash(), before)


func test_can_apply_answers_without_changing_anything() -> void:
	var sim: Simulation = Fixtures.sim()
	var command: ProbeCommand = ProbeCommand.new()
	assert_eq(sim.can_apply(command), "")
	command.accept = false
	assert_eq(sim.can_apply(command), "probe_rejected")
	assert_eq(command.executed, 0)


func test_nothing_happens_after_an_outcome() -> void:
	var sim: Simulation = Fixtures.sim()
	sim.systems.append(ProbeSystem.new())
	sim.tick()
	sim.world.outcome = World.Outcome.WIN_ASCENDANCE
	var after_outcome: String = sim.state_hash()

	assert_false(sim.tick(), "a finished run does not tick")
	assert_eq(sim.state_hash(), after_outcome, "and nothing moved")
	var result: CommandResult = sim.apply(ProbeCommand.new())
	assert_false(result.ok)
	assert_eq(result.reason, Command.FAIL_GAME_OVER)
	assert_eq(sim.command_log.size(), 0)


func test_node_cost_rises_with_every_node_owned() -> void:
	var sim: Simulation = Fixtures.sim()
	assert_eq(sim.node_cost("fx_reach"), 7.0)
	sim.world.agent.owned_nodes.append("fx_vector_net")
	assert_eq(sim.node_cost("fx_reach"), 8.0, "one step per owned node")
	assert_eq(sim.node_cost("fx_nothing"), -1.0, "an unknown node has no price")


func test_available_nodes_respects_prerequisites() -> void:
	var sim: Simulation = Fixtures.sim()
	var open_ids: Array[String] = []
	for node: TechNodeDef in sim.available_nodes():
		open_ids.append(node.id)
	assert_true(open_ids.has("fx_vector_net"), "a node without prerequisites is open")
	assert_false(open_ids.has("fx_reach"), "requires_any is not met yet")
	assert_false(open_ids.has("fx_harm_2"), "requires is not met yet")

	sim.world.agent.owned_nodes.append("fx_vector_mass")
	var after: Array[String] = []
	for node: TechNodeDef in sim.available_nodes():
		after.append(node.id)
	assert_true(after.has("fx_reach"), "one of requires_any is enough")
	assert_false(after.has("fx_vector_mass"), "what is owned is no longer available")


func test_rebuilding_modifiers_follows_the_owned_nodes() -> void:
	var sim: Simulation = Fixtures.sim()
	sim.world.agent.owned_nodes.append("fx_vector_net")
	sim.world.agent.owned_nodes.append("fx_ghost")
	sim.rebuild_modifiers()
	assert_true(sim.world.modifiers.has_source(ModifierStack.source_for_tech("fx_vector_net")))
	assert_false(sim.world.modifiers.has_source(ModifierStack.source_for_tech("fx_ghost")),
		"a node the content does not have is skipped, not fatal")
	assert_true(sim.world.modifiers.has_flag(ModifierDef.FLAG_BREAKOUT), "flags follow the source")


func test_a_world_can_be_continued_from_its_written_form() -> void:
	var sim: Simulation = Fixtures.sim(9)
	sim.systems.append(ProbeSystem.new())
	for i: int in 5:
		sim.tick()
	sim.world.agent.owned_nodes.append("fx_vector_net")

	var restored: World = World.from_dict(sim.world.to_dict(), Fixtures.db())
	var continued: Simulation = Simulation.from_world(Fixtures.db(), restored, sim.command_log)
	assert_eq(continued.state_hash(), sim.state_hash())
	assert_true(continued.world.modifiers.has_flag(ModifierDef.FLAG_BREAKOUT),
		"from_world rebuilds the stack a loaded world has no way to carry")
