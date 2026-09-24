extends GutTest
## S3.6 — the three strategy bots on the shipped content (`tech-trees.md` §7.3
## and §7.5.6). Each one is a claim about how a branch is played; the tests
## assert the claim, not the outcome, because the outcome is G3's business.

const Harness := preload("res://tools/sim_harness.gd")
const WORLD_ROOT: String = "res://data"
const SEED: int = 1
const DAYS: int = 5000
## Enough to buy anything, for the tests that arrange a situation by hand.
const PLENTY: float = 10000.0

static var _db: ContentDB = null
static var _runs: Dictionary[String, Simulation] = {}


func before_all() -> void:
	if _db == null:
		var result: ContentLoadResult = ContentLoader.load_root(WORLD_ROOT)
		assert_true(result.ok(), result.error_text())
		_db = result.db


## The run a bot plays on the shipped world, played once and shared: three full
## runs is the whole cost of this script.
func _run(policy_id: String) -> Simulation:
	if not _runs.has(policy_id):
		var problems: Array[String] = []
		var played: Dictionary = Harness.play(_db, SEED, policy_id, DAYS, true, problems)
		assert_eq(problems.size(), 0, str(problems))
		assert_eq(played["rejected"], 0, "%s asked for something it could not have" % policy_id)
		_runs[policy_id] = played["sim"]
	return _runs[policy_id]


## The nodes a run bought, in purchase order, with the day of each.
func _purchases(sim: Simulation) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for command: Command in sim.command_log:
		if command is PurchaseNodeCommand:
			var purchase: PurchaseNodeCommand = command
			out.append({"node": _db.tech(purchase.node), "day": command.day})
	return out


func _day_bought(sim: Simulation, node_id: String) -> int:
	for entry: Dictionary in _purchases(sim):
		var node: TechNodeDef = entry["node"]
		if node.id == node_id:
			return int(entry["day"])
	return -1


func test_every_strategy_finishes_the_shipped_world() -> void:
	for policy_id: String in [CyberRushPolicy.ID, StealthSpreadPolicy.ID, PersuaderPolicy.ID]:
		var sim: Simulation = _run(policy_id)
		assert_ne(sim.world.outcome, World.Outcome.NONE, "%s did not finish" % policy_id)
		assert_gt(sim.world.agent.owned_nodes.size(), 3, "%s barely played" % policy_id)


## §7.5.6: Content Recommendation opens the branch, and nothing outside it is
## bought while the run is still hiding.
func test_cyber_rush_stays_in_its_branch() -> void:
	var sim: Simulation = _run(CyberRushPolicy.ID)
	assert_true(sim.world.agent.owns(CyberRushPolicy.OPENER), "the branch opens where it says")
	for entry: Dictionary in _purchases(sim):
		var node: TechNodeDef = entry["node"]
		if node.tree != TechNodeDef.TREE_CAPABILITIES:
			continue
		assert_eq(node.branch(), TechNodeDef.BRANCH_CYBER,
			"%s is not Cyber" % node.id)


func test_cyber_rush_leaves_evasion_alone_until_it_is_seen() -> void:
	var sim: Simulation = _run(CyberRushPolicy.ID)
	assert_gt(sim.world.discovery_day, 0, "the run was found at all")
	for entry: Dictionary in _purchases(sim):
		var node: TechNodeDef = entry["node"]
		if node.tree == TechNodeDef.TREE_EVASION:
			assert_gte(int(entry["day"]), sim.world.discovery_day,
				"%s was bought before anybody was looking" % node.id)


## §7.3: Sandbagging and Log Manipulation I before the second vector.
func test_stealth_spread_buys_quiet_before_its_second_vector() -> void:
	var sim: Simulation = _run(StealthSpreadPolicy.ID)
	var vectors: int = 0
	var second_vector_day: int = -1
	for entry: Dictionary in _purchases(sim):
		var node: TechNodeDef = entry["node"]
		if node.tree != TechNodeDef.TREE_INFILTRATION or node.tier != TechNodeDef.TIER_MIN:
			continue
		vectors += 1
		if vectors == 2:
			second_vector_day = int(entry["day"])
			break
	assert_gt(second_vector_day, 0, "the run spread at all")
	for node_id: String in StealthSpreadPolicy.EARLY_QUIET:
		var day: int = _day_bought(sim, node_id)
		assert_between(day, 0, second_vector_day, "%s came before the second vector" % node_id)


## §7.3: Migration the moment a track passes half, if it can afford it.
func test_stealth_spread_migrates_when_containment_passes_half() -> void:
	var sim: Simulation = Simulation.create(_db, SEED)
	var policy: StealthSpreadPolicy = StealthSpreadPolicy.new()
	policy.setup(_db, Harness.policy_seed(SEED))
	sim.apply(policy.next_command(sim))
	sim.world.agent.compute = PLENTY
	# Migration stands on Fragmentation, which stands on one of the quiet pair.
	for node_id: String in ["log_manipulation_1", "weight_fragmentation_1"]:
		assert_true(sim.apply(PurchaseNodeCommand.new(node_id)).ok, node_id)

	sim.world.factions[0].containment = StealthSpreadPolicy.MIGRATION_CONTAINMENT
	var command: Command = policy.next_command(sim)
	assert_true(command is PurchaseNodeCommand)
	assert_eq((command as PurchaseNodeCommand).node, StealthSpreadPolicy.MIGRATION[0])


## §7.5.6: the reference "was never contained" run buys nothing that kills.
func test_persuader_buys_nothing_loud() -> void:
	var sim: Simulation = _run(PersuaderPolicy.ID)
	# Since S5.5 the dead can be the Task Force's: its Switch-off harms the region
	# it shuts down. The Diplomat's own purchases are what this test is about.
	if sim.world.task_force.actions_done == 0:
		assert_eq(sim.world.deaths_total(), 0.0, "the Diplomat kills nobody")
	var cyber: int = 0
	for entry: Dictionary in _purchases(sim):
		var node: TechNodeDef = entry["node"]
		if node.tree != TechNodeDef.TREE_CAPABILITIES:
			continue
		if node.branch() == TechNodeDef.BRANCH_CYBER:
			cyber += 1
			assert_eq(node.tier, TechNodeDef.TIER_MIN,
				"the one thing it runs is a Tier 1, not a weapon")
			continue
		assert_eq(node.branch(), TechNodeDef.BRANCH_PERSUASION, "%s is not Persuasion" % node.id)
	assert_lte(cyber, 1, "one piece of infrastructure is all Indispensability asks for")


## The rule every bot lives under: the world's stream is the world's.
func test_a_strategy_draws_nothing_from_the_world_s_generator() -> void:
	var sim: Simulation = Simulation.create(_db, SEED)
	var policy: CyberRushPolicy = CyberRushPolicy.new()
	policy.setup(_db, Harness.policy_seed(SEED))
	for day: int in 60:
		for i: int in Harness.MAX_COMMANDS_PER_DAY:
			var before: String = sim.world.rng.state_string()
			var command: Command = policy.next_command(sim)
			assert_eq(sim.world.rng.state_string(), before,
				"next_command drew from the world on day %d" % sim.world.day)
			if command == null:
				break
			sim.apply(command)
		sim.tick()
