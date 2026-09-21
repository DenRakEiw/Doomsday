extends GutTest
## S1.4 — buying technology: the price, the checks, and that it changes the
## simulation measurably.


func _force(sim: Simulation, target: String, op: ModifierDef.Op, value: float) -> void:
	var modifier: ModifierDef = ModifierDef.new()
	modifier.target = target
	modifier.op = op
	modifier.value = value
	var modifiers: Array[ModifierDef] = [modifier]
	var no_flags: Array[String] = []
	sim.world.modifiers.add_source("test", modifiers, no_flags)


func test_every_node_owned_raises_the_price_of_the_next() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	Fixtures.grant(sim, 100.0)
	assert_eq(sim.node_cost("fx_vector_net"), 4.0, "the base cost while nothing is owned")
	Fixtures.buy(sim, ["fx_vector_net"])
	assert_eq(sim.node_cost("fx_efficiency"), 6.0, "5 + one owned node")
	Fixtures.buy(sim, ["fx_efficiency"])
	assert_eq(sim.node_cost("fx_grip"), 8.0, "6 + two owned nodes")


func test_the_node_cost_stat_scales_the_price() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	_force(sim, "node_cost", ModifierDef.Op.MUL, 2.0)
	assert_eq(sim.node_cost("fx_reach"), 14.0)
	_force(sim, "node_cost", ModifierDef.Op.MUL, 0.1)
	assert_eq(sim.node_cost("fx_reach"), 1.0, "and never below one Compute")


func test_compute_is_deducted_exactly() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	Fixtures.grant(sim, 20.0)
	var before: float = sim.world.agent.compute
	var earned: float = sim.world.agent.compute_earned
	var result: CommandResult = sim.apply(PurchaseNodeCommand.new("fx_vector_net"))
	assert_true(result.ok, result.reason)
	assert_eq(sim.world.agent.compute, before - 4.0)
	assert_eq(sim.world.agent.compute_earned, earned, "spending is not earning")
	assert_eq(result.events[0].type, SimEvent.NODE_PURCHASED)
	assert_eq(result.events[0].data["node"], "fx_vector_net")
	assert_eq(result.events[0].data["cost"], 4.0)


func test_a_purchase_activates_the_modifiers_and_the_flags() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	Fixtures.grant(sim, 20.0)
	assert_false(sim.world.modifiers.has_flag(ModifierDef.FLAG_BREAKOUT))
	Fixtures.buy(sim, ["fx_vector_net"])
	assert_true(sim.world.modifiers.has_flag(ModifierDef.FLAG_BREAKOUT))
	assert_almost_eq(sim.world.modifiers.value("spread_growth",
		sim.db.region_by_id("fx_alder")), 1.25, 1e-9)


func test_without_an_origin_nothing_can_be_bought() -> void:
	var sim: Simulation = Fixtures.sim()
	Fixtures.grant(sim, 100.0)
	assert_eq(sim.can_apply(PurchaseNodeCommand.new("fx_vector_net")), Command.FAIL_NO_ORIGIN)
	assert_eq(sim.can_apply(PurchaseNodeCommand.new("fx_ghost")), Command.FAIL_NO_ORIGIN,
		"the origin is checked before the node id")


func test_an_unknown_node_is_rejected() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	assert_eq(sim.can_apply(PurchaseNodeCommand.new("fx_ghost")), Command.FAIL_UNKNOWN_NODE)


func test_a_node_cannot_be_bought_twice() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	Fixtures.grant(sim, 100.0)
	Fixtures.buy(sim, ["fx_vector_net"])
	assert_eq(sim.can_apply(PurchaseNodeCommand.new("fx_vector_net")), Command.FAIL_ALREADY_OWNED)


func test_a_missing_prerequisite_is_rejected() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	Fixtures.grant(sim, 100.0)
	assert_eq(sim.can_apply(PurchaseNodeCommand.new("fx_reach")),
		Command.FAIL_MISSING_PREREQUISITE, "requires_any, none owned")
	Fixtures.buy(sim, ["fx_vector_mass"])
	assert_eq(sim.can_apply(PurchaseNodeCommand.new("fx_reach")), "",
		"one of requires_any is enough")


func test_the_cross_tree_prerequisite_holds() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	Fixtures.grant(sim, 100.0)
	Fixtures.buy(sim, ["fx_harm_1"])
	assert_eq(sim.can_apply(PurchaseNodeCommand.new("fx_harm_2")),
		Command.FAIL_MISSING_PREREQUISITE, "fx_harm_2 also needs fx_reach, from another tree")
	Fixtures.buy(sim, ["fx_vector_net", "fx_reach"])
	assert_eq(sim.can_apply(PurchaseNodeCommand.new("fx_harm_2")), "")


func test_too_little_compute_is_rejected_last() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	assert_eq(sim.world.agent.compute, 5.0)
	assert_eq(sim.can_apply(PurchaseNodeCommand.new("fx_grip")), Command.FAIL_INSUFFICIENT_COMPUTE)
	assert_eq(sim.can_apply(PurchaseNodeCommand.new("fx_reach")),
		Command.FAIL_MISSING_PREREQUISITE, "the prerequisite is checked before the price")
	var result: CommandResult = sim.apply(PurchaseNodeCommand.new("fx_grip"))
	assert_false(result.ok)
	assert_eq(sim.world.agent.compute, 5.0, "a rejected purchase costs nothing")
	assert_eq(sim.world.agent.owned_nodes.size(), 0)


func test_reach_measurably_shortens_the_way_to_the_second_continent() -> void:
	# The step's "done when": a purchase has to change the simulation, not just
	# the numbers on it.
	var without: float = _mean_day_of_dogwood([])
	var with_reach: float = _mean_day_of_dogwood(["fx_reach"])
	assert_lt(with_reach, without,
		"fx_reach doubles the seeding chance, so fx_dogwood should fall sooner")


const _SEEDS: int = 20
const _LIMIT: int = 600


func _mean_day_of_dogwood(extra: Array[String]) -> float:
	var total: float = 0.0
	for seed_value: int in range(1, _SEEDS + 1):
		var sim: Simulation = Fixtures.sim_with_origin("fx_alder", seed_value)
		Fixtures.grant(sim, 100.0)
		var plan: Array[String] = ["fx_vector_net"]
		plan.append_array(extra)
		Fixtures.buy(sim, plan)
		var day: int = _LIMIT
		for i: int in _LIMIT:
			sim.tick()
			if sim.world.regions[4].seeded_day >= 0:
				day = sim.world.regions[4].seeded_day
				break
		total += float(day)
	return total / float(_SEEDS)
