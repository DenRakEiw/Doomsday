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
	return null


static func ids() -> Array[String]:
	return [IdlePolicy.ID, GreedyPolicy.ID, StealthPolicy.ID]


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
	var best: TechNodeDef = null
	var best_cost: float = 0.0
	for node: TechNodeDef in sim.available_nodes():
		if skip_trees.has(node.tree):
			continue
		var cost: float = sim.node_cost(node.id)
		if cost > sim.world.agent.compute:
			continue
		if best == null or _is_better(node, cost, best, best_cost, tree_order):
			best = node
			best_cost = cost
	if best == null:
		return null
	return PurchaseNodeCommand.new(best.id)


func _is_better(node: TechNodeDef, cost: float, best: TechNodeDef, best_cost: float,
		tree_order: Array[String]) -> bool:
	if cost != best_cost:
		return cost < best_cost
	var rank: int = tree_order.find(node.tree)
	var best_rank: int = tree_order.find(best.tree)
	if rank != best_rank:
		return rank < best_rank
	return node.id < best.id
