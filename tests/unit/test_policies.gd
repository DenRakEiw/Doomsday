extends GutTest
## S1.8 — the bots on the fixture world. They play through the same interface
## the player does, and they must never disturb the world's random stream.
##
## What the three strategies of S3.6 actually *do* is asserted on the shipped
## content, in `tests/integration/test_strategy_bots.gd`: their plans name nodes
## that only exist there.

const Harness := preload("res://tools/sim_harness.gd")
const DAYS: int = 4000


func _play(policy_id: String, seed_value: int = 1) -> Dictionary:
	var problems: Array[String] = []
	var played: Dictionary = Harness.play(Fixtures.db(), seed_value, policy_id, DAYS, true,
		problems)
	assert_eq(problems.size(), 0, str(problems))
	return played


func test_every_policy_finishes_the_fixture_without_a_rejected_command() -> void:
	for policy_id: String in Harness.policy_ids():
		var played: Dictionary = _play(policy_id)
		var sim: Simulation = played["sim"]
		assert_eq(played["rejected"], 0, "%s asked for something it could not have" % policy_id)
		assert_ne(sim.world.outcome, World.Outcome.NONE, "%s did not finish" % policy_id)
		assert_gt(sim.command_log.size(), 0, "%s never did anything" % policy_id)


func test_doing_nothing_loses_to_containment() -> void:
	var sim: Simulation = _play(IdlePolicy.ID)["sim"]
	assert_eq(sim.world.outcome, World.Outcome.LOSE_CONTAINED, "idle is the floor")
	assert_eq(sim.world.agent.owned_nodes.size(), 0, "and it buys nothing")


func test_the_same_seed_and_policy_give_the_same_run_twice() -> void:
	for policy_id: String in Harness.policy_ids():
		var first: Simulation = _play(policy_id, 5)["sim"]
		var second: Simulation = _play(policy_id, 5)["sim"]
		assert_eq(first.state_hash(), second.state_hash(), policy_id)


func test_different_seeds_give_different_runs() -> void:
	var first: Simulation = _play(GreedyPolicy.ID, 1)["sim"]
	var second: Simulation = _play(GreedyPolicy.ID, 2)["sim"]
	assert_ne(first.state_hash(), second.state_hash())


func test_a_policy_draws_nothing_from_the_world_s_generator() -> void:
	# The rule the baselines depend on: changing a policy must not shift the
	# world's stream, or every measurement taken before it becomes meaningless.
	var sim: Simulation = Simulation.create(Fixtures.db(), 1)
	var policy: IdlePolicy = IdlePolicy.new()
	policy.setup(Fixtures.db(), 99)
	while sim.world.outcome == World.Outcome.NONE and sim.world.day < DAYS:
		for i: int in Harness.MAX_COMMANDS_PER_DAY:
			var before: String = sim.world.rng.state_string()
			var command: Command = policy.next_command(sim)
			assert_eq(sim.world.rng.state_string(), before,
				"next_command drew from the world on day %d" % sim.world.day)
			if command == null:
				break
			sim.apply(command)
		sim.tick()
	assert_ne(sim.world.outcome, World.Outcome.NONE)


func test_greedy_starts_where_the_hardware_is() -> void:
	var sim: Simulation = _play(GreedyPolicy.ID)["sim"]
	# fx_alder is the fixture's only compute-tier-4 region.
	assert_eq(sim.db.regions[sim.world.agent.origin].id, "fx_alder")


func test_stealth_starts_where_nobody_is_looking() -> void:
	var sim: Simulation = _play(StealthPolicy.ID)["sim"]
	# fx_cedar has regulation 0; the eligible regions below it are air-gapped.
	assert_eq(sim.db.regions[sim.world.agent.origin].id, "fx_cedar")


func test_stealth_buys_no_capabilities_while_the_world_is_still_free() -> void:
	var sim: Simulation = Simulation.create(Fixtures.db(), 1)
	var policy: StealthPolicy = StealthPolicy.new()
	policy.setup(Fixtures.db(), 7)
	for day: int in 400:
		for i: int in Harness.MAX_COMMANDS_PER_DAY:
			var command: Command = policy.next_command(sim)
			if command == null:
				break
			if command is PurchaseNodeCommand and sim.world.infected_share(sim.db) \
					< StealthPolicy.CAPABILITY_SHARE:
				var purchase: PurchaseNodeCommand = command
				assert_ne(sim.db.tech(purchase.node).tree, "capabilities",
					"bought %s at share %f" % [purchase.node,
					sim.world.infected_share(sim.db)])
			sim.apply(command)
		sim.tick()


func test_an_unknown_policy_id_yields_nothing() -> void:
	assert_null(Harness.make_policy("reckless"))
	# Three shape bots (S1.8) and three strategies (S3.6).
	assert_eq(Harness.policy_ids().size(), 6)

# ------------------------------------------------- S4.1: where a bot places


## §19: the eligible region with the most `hardware × penetration`, ties to the
## lower index; "" when the node can go nowhere.
func test_best_site_picks_the_richest_eligible_region() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	var policy: Policy = GreedyPolicy.new()
	policy.setup(sim.db, Policy.seed_for(1))
	var node: TechNodeDef = sim.db.tech(Fixtures.DEPLOY_FLEET_NODE)

	# Only the origin is infected, and its industry is 2 — so it is the site.
	assert_eq(policy.best_site(sim, node), "fx_alder")

	# fx_dogwood has industry 4 and, once infected harder, more of the agent.
	sim.world.regions[4].penetration = 0.9
	sim.world.regions[4].seeded_day = 0
	assert_eq(policy.best_site(sim, node), "fx_dogwood")


func test_best_site_is_empty_when_nothing_is_eligible() -> void:
	var sim: Simulation = Fixtures.sim()
	var policy: Policy = GreedyPolicy.new()
	policy.setup(sim.db, Policy.seed_for(1))
	assert_eq(policy.best_site(sim, sim.db.tech(Fixtures.DEPLOY_FLEET_NODE)), "",
		"nothing is infected before there is an origin")


## §19: a bot never sends a command the simulation would refuse — a deploying
## node it cannot place is simply not the node it buys.
func test_greedy_is_never_rejected_over_three_hundred_days() -> void:
	var sim: Simulation = Fixtures.sim()
	var policy: Policy = GreedyPolicy.new()
	policy.setup(sim.db, Policy.seed_for(1))
	var rejected: int = 0
	var placed: int = 0
	for day: int in 300:
		for i: int in Policy.MAX_COMMANDS_PER_DAY:
			var command: Command = policy.next_command(sim)
			if command == null:
				break
			if not sim.apply(command).ok:
				rejected += 1
		sim.tick()
	for i: int in range(1, sim.world.regions.size()):
		placed += sim.world.regions[i].asset_count(AssetDef.KIND_FLEET)
	assert_eq(rejected, 0)
	assert_gt(placed, 0, "and it placed the fixture fleet by itself")
