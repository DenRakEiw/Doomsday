class_name StealthSpreadPolicy
extends Policy
## The careful player with the real trees (spec `tech-trees.md` §7.3):
## Sandbagging and Log Manipulation before the second vector, then breadth, and
## Architecture Migration whenever a containment track passes half.
##
## It is the bot that answers "does buying quiet actually buy time?"

const ID: String = "stealth_spread"
## Evasion first on a tie — the whole difference from spreading greedily.
const TREE_ORDER: Array[String] = ["evasion", "infiltration", "capabilities"]
## §7.3: bought before the second vector, in this order.
const EARLY_QUIET: Array[String] = ["benchmark_sandbagging", "log_manipulation_1"]
## The one-shot button, in the order the run may use it.
const MIGRATION: Array[String] = ["architecture_migration_1", "architecture_migration_2",
	"architecture_migration_3"]
## §7.3: Migration whenever max containment is at least this and it can afford it.
const MIGRATION_CONTAINMENT: float = 0.5
## Below this share of the world, being seen is not worth what Capabilities buy.
## A policy constant, not game balance.
const CAPABILITY_SHARE: float = 0.8


func policy_id() -> String:
	return ID


func next_command(sim: Simulation) -> Command:
	if sim.world.agent.origin == 0:
		return _choose_origin(sim)
	var answer: Command = answer_events(sim)
	if answer != null:
		return answer
	var anomaly: Command = _collect_oldest(sim)
	if anomaly != null:
		return anomaly
	if sim.world.max_containment() >= MIGRATION_CONTAINMENT:
		var migration: Command = _first_buyable(sim, MIGRATION)
		if migration != null:
			return migration
	if _vectors(sim) <= 1:
		var quiet: Command = _first_buyable(sim, EARLY_QUIET)
		if quiet != null:
			return quiet
	return _cheapest_allowed(sim, TREE_ORDER, _allows.bind(sim))


## The least regulated, then the most hardware: a backwater with something in it.
func _choose_origin(sim: Simulation) -> Command:
	var best: int = 0
	for index: int in _eligible_origins(sim):
		if best == 0 or _is_quieter(sim.db.regions[index], sim.db.regions[best]):
			best = index
	if best == 0:
		return null
	return ChooseOriginCommand.new(sim.db.regions[best].id)


static func _is_quieter(candidate: RegionDef, current: RegionDef) -> bool:
	if candidate.attr("regulation") != current.attr("regulation"):
		return candidate.attr("regulation") < current.attr("regulation")
	return candidate.attr("compute") > current.attr("compute")


## Everything quiet, always; Capabilities only once the world is taken anyway.
func _allows(node: TechNodeDef, sim: Simulation) -> bool:
	if node.tree != TechNodeDef.TREE_CAPABILITIES:
		return true
	return sim.world.infected_share(sim.db) >= CAPABILITY_SHARE


func _vectors(sim: Simulation) -> int:
	return _owned_in_tree(sim, TechNodeDef.TREE_INFILTRATION, TechNodeDef.TIER_MIN)
