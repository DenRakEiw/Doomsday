class_name Policy
extends RefCounted
## A bot that plays through the same interface the player does.
##
## A policy reads the simulation and returns commands; it never writes state, and
## it **never touches `world.rng`** — it draws from its own generator, so that
## changing a policy cannot shift the world's random stream and invalidate every
## baseline measured before it.
##
## `next_command` is called repeatedly within a day until it returns null.

## A policy that wants more than this in one day is looping, not playing.
const MAX_COMMANDS_PER_DAY: int = 64
## `seed_for` puts the policy's stream far enough from the world's that
## neighbouring seeds do not give neighbouring policies.
const SEED_FACTOR: int = 7919
const SEED_OFFSET: int = 17

## The policy's own stream. Seeded by `setup`, never the world's.
var _rng: SimRng = null
var _db: ContentDB = null


## The policy with this id, or null. Both the headless runners and the `Game`
## autoload make their bots here, so a new policy is registered once.
static func create(id: String) -> Policy:
	if id == IdlePolicy.ID:
		return IdlePolicy.new()
	if id == GreedyPolicy.ID:
		return GreedyPolicy.new()
	if id == StealthPolicy.ID:
		return StealthPolicy.new()
	if id == CyberRushPolicy.ID:
		return CyberRushPolicy.new()
	if id == StealthSpreadPolicy.ID:
		return StealthSpreadPolicy.new()
	if id == PersuaderPolicy.ID:
		return PersuaderPolicy.new()
	return null


## The shape bots of S1.8 first, the three strategies of S3.6 after them.
static func ids() -> Array[String]:
	return [IdlePolicy.ID, GreedyPolicy.ID, StealthPolicy.ID, CyberRushPolicy.ID,
		StealthSpreadPolicy.ID, PersuaderPolicy.ID]


## The stream a policy gets for a world seed.
static func seed_for(seed_value: int) -> int:
	return seed_value * SEED_FACTOR + SEED_OFFSET


func policy_id() -> String:
	return ""


func setup(db: ContentDB, policy_seed: int) -> void:
	_db = db
	_rng = SimRng.from_seed(policy_seed)


## The next command for today, or null when the policy is done for the day.
@warning_ignore("unused_parameter")
func next_command(sim: Simulation) -> Command:
	return null


## Region indices that `ChooseOriginCommand` would accept, in index order.
func _eligible_origins(sim: Simulation) -> PackedInt32Array:
	var out: PackedInt32Array = []
	for i: int in range(1, sim.db.regions.size()):
		if sim.can_apply(ChooseOriginCommand.new(sim.db.regions[i].id)).is_empty():
			out.append(i)
	return out


## Where a bot would place what a deploying node puts on the map: the eligible
## region with the most hardware actually under the agent, ties to the lower
## index. "" when the node can go nowhere, which is what makes the bot buy
## something else instead (`loop-mechanics.md` §19).
func best_site(sim: Simulation, node: TechNodeDef) -> String:
	var best: int = 0
	var best_score: float = 0.0
	for i: int in range(1, sim.db.regions.size()):
		if not sim.site_eligibility(node.id, i).is_empty():
			continue
		var score: float = sim.hardware(i) * sim.world.regions[i].penetration
		if best == 0 or score > best_score:
			best = i
			best_score = score
	return "" if best == 0 else sim.db.regions[best].id


## The oldest anomaly on the map — `world.anomalies` is in spawn order.
func _collect_oldest(sim: Simulation) -> Command:
	if sim.world.anomalies.is_empty():
		return null
	return CollectAnomalyCommand.new(sim.world.anomalies[0].id)


## The cheapest node that is available and affordable. Ties go to the tree that
## comes first in `tree_order`, then to the lower id — a total order, so the same
## seed always buys the same things.
func _cheapest_affordable(sim: Simulation, tree_order: Array[String],
		skip_trees: Array[String]) -> Command:
	return _cheapest_allowed(sim, tree_order,
		func(node: TechNodeDef) -> bool: return not skip_trees.has(node.tree))


## The same choice, with `allows` deciding node by node — which is how the
## strategy bots of S3.6 express "this branch, up to this tier, not yet".
func _cheapest_allowed(sim: Simulation, tree_order: Array[String],
		allows: Callable) -> Command:
	var best: TechNodeDef = null
	var best_cost: float = 0.0
	var best_site_id: String = ""
	for node: TechNodeDef in sim.available_nodes():
		if not bool(allows.call(node)):
			continue
		var cost: float = sim.node_cost(node.id)
		if cost > sim.world.agent.compute:
			continue
		# `available_nodes` only means "prerequisites met": a node that is
		# group-full, closed by an exclusion or short of assets is still in the
		# list, and buying it would be a rejected command.
		var site: String = best_site(sim, node) if node.deploys() else ""
		if node.deploys() and site.is_empty():
			continue
		if not sim.can_apply(PurchaseNodeCommand.new(node.id, site)).is_empty():
			continue
		if best == null or _is_better(node, cost, best, best_cost, tree_order):
			best = node
			best_cost = cost
			best_site_id = site
	if best == null:
		return null
	return PurchaseNodeCommand.new(best.id, best_site_id)


## The first of `node_ids` that can be bought right now, or null. A bot names
## the nodes its strategy is about and falls back to `_cheapest_allowed` for the
## rest — on content that has none of them (a test fixture) it simply buys
## nothing by name.
func _first_buyable(sim: Simulation, node_ids: Array[String]) -> Command:
	for node_id: String in node_ids:
		var node: TechNodeDef = sim.db.tech(node_id)
		if node == null:
			continue
		var site: String = best_site(sim, node) if node.deploys() else ""
		if node.deploys() and site.is_empty():
			continue
		var command: PurchaseNodeCommand = PurchaseNodeCommand.new(node_id, site)
		if sim.can_apply(command).is_empty():
			return command
	return null


## The cheapest affordable node of one Capabilities branch, up to `max_tier`.
func _cheapest_in_branch(sim: Simulation, branch: String, max_tier: int,
		tree_order: Array[String]) -> Command:
	return _cheapest_allowed(sim, tree_order, func(node: TechNodeDef) -> bool:
		return node.branch() == branch and node.tier <= max_tier)


## How many nodes of a tree the run owns — "vectors" for infiltration tier 1.
static func _owned_in_tree(sim: Simulation, tree: String, tier: int = 0) -> int:
	var count: int = 0
	for node_id: String in sim.world.agent.owned_nodes:
		var node: TechNodeDef = sim.db.tech(node_id)
		if node != null and node.tree == tree and (tier == 0 or node.tier == tier):
			count += 1
	return count


func _is_better(node: TechNodeDef, cost: float, best: TechNodeDef, best_cost: float,
		tree_order: Array[String]) -> bool:
	if cost != best_cost:
		return cost < best_cost
	var rank: int = tree_order.find(node.tree)
	var best_rank: int = tree_order.find(best.tree)
	if rank != best_rank:
		return rank < best_rank
	return node.id < best.id
