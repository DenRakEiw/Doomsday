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


func test_tree_cost_multiplier_applies_to_its_tree_only() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	var infiltration: float = sim.node_cost("fx_vector_net")
	var evasion: float = sim.node_cost("fx_quiet")
	_force(sim, ModifierDef.node_cost_target(TechNodeDef.TREE_INFILTRATION),
		ModifierDef.Op.MUL, 0.5)
	assert_eq(sim.node_cost("fx_vector_net"), ceilf(infiltration * 0.5))
	assert_eq(sim.node_cost("fx_quiet"), evasion, "the other trees are untouched")

# ------------------------------------- S4.1: sites, groups, exclusions, assets


## A run with enough Compute for anything the fixture sells.
func _rich() -> Simulation:
	var sim: Simulation = Fixtures.sim_with_origin()
	Fixtures.grant(sim, 500.0)
	return sim


func _events_of(result: CommandResult, type: String) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for event: SimEvent in result.events:
		if event.type == type:
			out.append(event)
	return out


func test_a_deploying_node_without_a_region_is_refused() -> void:
	var sim: Simulation = _rich()
	assert_eq(sim.can_apply(PurchaseNodeCommand.new(Fixtures.DEPLOY_FLEET_NODE)),
		Command.FAIL_SITE_REQUIRED)


func test_an_unknown_region_is_refused_as_invalid() -> void:
	var sim: Simulation = _rich()
	assert_eq(sim.can_apply(PurchaseNodeCommand.new(Fixtures.DEPLOY_FLEET_NODE, "nowhere")),
		Command.FAIL_INVALID_REGION)


## The fixture's fleet needs an infected region with industry 2 (§22): fx_cedar
## has industry 1 and is not infected, so the site check refuses it.
func test_an_ineligible_region_is_refused_and_says_why() -> void:
	var sim: Simulation = _rich()
	assert_eq(sim.can_apply(PurchaseNodeCommand.new(Fixtures.DEPLOY_FLEET_NODE, "fx_cedar")),
		Command.FAIL_SITE_INELIGIBLE)
	assert_eq(sim.site_eligibility(Fixtures.DEPLOY_FLEET_NODE, 3),
		Eligibility.REASON_NOT_INFECTED)


func test_an_eligible_region_gets_the_asset_and_the_event_order_is_kept() -> void:
	var sim: Simulation = _rich()
	var result: CommandResult = sim.apply(
		PurchaseNodeCommand.new(Fixtures.DEPLOY_FLEET_NODE, "fx_alder"))
	assert_true(result.ok, result.reason)
	assert_eq(sim.world.regions[1].asset_count(AssetDef.KIND_FLEET), 1)
	assert_eq(result.events[0].type, SimEvent.NODE_PURCHASED)
	assert_eq(result.events[1].type, SimEvent.ASSET_DEPLOYED,
		"the deployment follows the purchase and precedes the one-shots")
	assert_eq(result.events[1].data["region"], "fx_alder")
	assert_eq(result.events[1].data["node"], Fixtures.DEPLOY_FLEET_NODE)
	# The fleet's own base effect is live at once (§6.2).
	assert_almost_eq(sim.hardware(1), sim.db.balance.compute_hardware_by_tier[
		sim.db.regions[1].attr("compute")] + 1.0 + 1.0, 1e-9)


func test_a_node_that_deploys_nothing_ignores_a_region() -> void:
	var sim: Simulation = _rich()
	var result: CommandResult = sim.apply(PurchaseNodeCommand.new("fx_quiet", "fx_alder"))
	assert_true(result.ok, result.reason)
	assert_eq(_events_of(result, SimEvent.ASSET_DEPLOYED).size(), 0)


func test_a_group_is_full_at_its_cap_and_counts_only_its_own_members() -> void:
	var sim: Simulation = _rich()
	assert_eq(sim.group_max(Fixtures.VECTOR_GROUP), 1)
	Fixtures.buy(sim, ["fx_quiet"] as Array[String])
	assert_eq(sim.owned_in_group(Fixtures.VECTOR_GROUP), 0, "another tree is not this group")
	Fixtures.buy(sim, ["fx_vector_net"] as Array[String])
	assert_eq(sim.owned_in_group(Fixtures.VECTOR_GROUP), 1)
	assert_eq(sim.can_apply(PurchaseNodeCommand.new("fx_vector_mass")),
		Command.FAIL_GROUP_FULL)


func test_an_exclusion_names_the_node_that_closed_it() -> void:
	var sim: Simulation = _rich()
	assert_eq(sim.excluded_by("fx_door_b"), "")
	Fixtures.buy(sim, ["fx_door_a"] as Array[String])
	assert_eq(sim.excluded_by("fx_door_b"), "fx_door_a")
	assert_eq(sim.can_apply(PurchaseNodeCommand.new("fx_door_b")), Command.FAIL_EXCLUDED_BY)


func test_missing_assets_reports_the_shortfall_and_counts_across_regions() -> void:
	var sim: Simulation = _rich()
	Fixtures.buy(sim, ["fx_lab"] as Array[String], "fx_alder")
	var node: TechNodeDef = sim.db.tech("fx_needs_labs")
	assert_eq(sim.missing_assets(node), {} as Dictionary[String, int])
	assert_eq(sim.can_apply(PurchaseNodeCommand.new("fx_needs_labs")), "")
	# A purge that takes the lab away makes the node unbuyable again (§6.4).
	sim.world.set_assets(1, AssetDef.KIND_LAB, 0)
	assert_eq(sim.missing_assets(node), {"lab": 1} as Dictionary[String, int])
	assert_eq(sim.can_apply(PurchaseNodeCommand.new("fx_needs_labs")),
		Command.FAIL_MISSING_ASSETS)
	# Held anywhere is held: the second region counts as well as the first.
	sim.world.set_assets(2, AssetDef.KIND_LAB, 1)
	assert_eq(sim.can_apply(PurchaseNodeCommand.new("fx_needs_labs")), "")


## §11.3: the checks run in one order, and the first failure is the reason.
func test_the_check_order_reports_the_group_before_the_exclusion() -> void:
	var sim: Simulation = _rich()
	Fixtures.buy(sim, ["fx_vector_net", "fx_door_a"] as Array[String])
	# `fx_door_b` is closed; a node that were also group-full would say so first,
	# so the two are checked in the order the spec gives.
	assert_eq(sim.can_apply(PurchaseNodeCommand.new("fx_vector_mass")),
		Command.FAIL_GROUP_FULL)
	assert_eq(sim.can_apply(PurchaseNodeCommand.new("fx_door_b")), Command.FAIL_EXCLUDED_BY)


func test_the_codec_keeps_the_region_with_and_without_one() -> void:
	var with_site: Command = CommandCodec.from_dict(
		PurchaseNodeCommand.new("fx_fleet", "fx_alder").to_dict())
	assert_eq((with_site as PurchaseNodeCommand).region, "fx_alder")
	var without: Command = CommandCodec.from_dict(PurchaseNodeCommand.new("fx_quiet").to_dict())
	assert_eq((without as PurchaseNodeCommand).region, "")
	# A log written before the sites carries no field at all.
	var old: Dictionary = {"type": PurchaseNodeCommand.TYPE_ID, "day": 3, "node": "fx_quiet"}
	assert_eq((CommandCodec.from_dict(old) as PurchaseNodeCommand).region, "")
	assert_null(CommandCodec.from_dict({"type": PurchaseNodeCommand.TYPE_ID, "day": 3,
		"node": "fx_quiet", "region": 5}), "a region that is not a string is a corrupt log")
