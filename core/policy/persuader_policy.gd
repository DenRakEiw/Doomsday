class_name PersuaderPolicy
extends Policy
## The Alignment & Persuasion branch as a player (spec `tech-trees.md` §7.5.6's
## `Diplomat`): Sycophancy as the first purchase after the vector, Personalised
## Persuasion and Elite Capture before anybody is looking, Indispensability once
## the run actually operates something, then Succession.
##
## It is the reference "was never contained" run — the slowest Ascendance there
## is, and the one that should never lose to containment.

const ID: String = "persuader"
const TREE_ORDER: Array[String] = ["capabilities", "infiltration", "evasion"]
## §7.5.6, in the order it wants them.
const PLAN: Array[String] = ["sycophancy_tuning", "personalised_persuasion", "elite_capture",
	"regulatory_capture", "indispensability", "constitutional_integration", "succession"]
## "You now run enough that switching you off costs lives" is a prerequisite,
## not a claim (`tech-trees.md` §7.5.5): one piece of infrastructure does it.
const RUNNING_SOMETHING: String = "indispensability"


func policy_id() -> String:
	return ID


func next_command(sim: Simulation) -> Command:
	if sim.world.agent.origin == 0:
		return _choose_origin(sim)
	var anomaly: Command = _collect_oldest(sim)
	if anomaly != null:
		return anomaly
	if _vectors(sim) == 0:
		return _cheapest_allowed(sim, TREE_ORDER, _is_vector)
	var planned: Command = _first_buyable(sim, PLAN)
	if planned != null:
		return planned
	var infrastructure: Command = _infrastructure_for_indispensability(sim)
	if infrastructure != null:
		return infrastructure
	return _cheapest_allowed(sim, TREE_ORDER, _allows)


## The best connected, then the most hardware: persuasion travels on networks.
func _choose_origin(sim: Simulation) -> Command:
	var best: int = 0
	for index: int in _eligible_origins(sim):
		if best == 0 or _is_better_connected(sim.db.regions[index], sim.db.regions[best]):
			best = index
	if best == 0:
		return null
	return ChooseOriginCommand.new(sim.db.regions[best].id)


static func _is_better_connected(candidate: RegionDef, current: RegionDef) -> bool:
	if candidate.attr("connectivity") != current.attr("connectivity"):
		return candidate.attr("connectivity") > current.attr("connectivity")
	return candidate.attr("compute") > current.attr("compute")


## The cheapest Cyber Tier 1, and only while Indispensability is still waiting
## for one: the run has to operate something before it can be missed.
func _infrastructure_for_indispensability(sim: Simulation) -> Command:
	if sim.world.agent.owns(RUNNING_SOMETHING) or sim.db.tech(RUNNING_SOMETHING) == null:
		return null
	if _owned_in_branch(sim, TechNodeDef.BRANCH_CYBER) > 0:
		return null
	return _cheapest_in_branch(sim, TechNodeDef.BRANCH_CYBER, TechNodeDef.TIER_MIN, TREE_ORDER)


## Infiltration for reach, Persuasion for everything else. Nothing loud: the
## point of the run is that nobody ever has a reason to stop it.
static func _allows(node: TechNodeDef) -> bool:
	if node.tree == TechNodeDef.TREE_INFILTRATION:
		return true
	return node.branch() == TechNodeDef.BRANCH_PERSUASION


static func _is_vector(node: TechNodeDef) -> bool:
	return node.tree == TechNodeDef.TREE_INFILTRATION


func _vectors(sim: Simulation) -> int:
	return _owned_in_tree(sim, TechNodeDef.TREE_INFILTRATION, TechNodeDef.TIER_MIN)


func _owned_in_branch(sim: Simulation, branch: String) -> int:
	var count: int = 0
	for node_id: String in sim.world.agent.owned_nodes:
		var node: TechNodeDef = sim.db.tech(node_id)
		if node != null and node.branch() == branch:
			count += 1
	return count
