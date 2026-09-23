class_name CyberRushPolicy
extends Policy
## The Cyber branch as a player (spec `tech-trees.md` §7.5.6): one vector, the
## cheap infrastructure that pays for itself, a second vector, then the loud
## Tier 2s. Evasion is bought only once the world already knows.
##
## It is the bot that answers "is scoped Harm loud enough?" — a run that takes
## Blackout and Grid Failure before Robotics should sometimes run out of compute.

const ID: String = "cyber_rush"
## Capabilities first on a tie: the branch is the point of this bot.
const TREE_ORDER: Array[String] = ["capabilities", "infiltration", "evasion"]
## §7.5.6: the branch opens here, before anything else of it.
const OPENER: String = "content_recommendation"
## Tier 3 waits for the swarm that keeps the lights on — or for a world that has
## already noticed, when hiding is no longer the point.
const TIER_3_GATE: String = "construction_swarm"
## Tier 2 waits for the second vector, so that the run has somewhere to spread.
const VECTORS_FOR_TIER_2: int = 2


func policy_id() -> String:
	return ID


func next_command(sim: Simulation) -> Command:
	if sim.world.agent.origin == 0:
		return _choose_origin(sim)
	var anomaly: Command = _collect_oldest(sim)
	if anomaly != null:
		return anomaly
	if _vectors(sim) == 0:
		# Nothing is worth buying before there is somewhere to be.
		return _cheapest_allowed(sim, TREE_ORDER, _is_vector)
	var opener: Command = _first_buyable(sim, [OPENER])
	if opener != null:
		return opener
	return _cheapest_allowed(sim, TREE_ORDER, _allows.bind(sim))


## The most hardware, then the best connected — the branch runs on compute.
func _choose_origin(sim: Simulation) -> Command:
	var best: int = 0
	for index: int in _eligible_origins(sim):
		if best == 0 or _is_richer(sim.db.regions[index], sim.db.regions[best]):
			best = index
	if best == 0:
		return null
	return ChooseOriginCommand.new(sim.db.regions[best].id)


static func _is_richer(candidate: RegionDef, current: RegionDef) -> bool:
	if candidate.attr("compute") != current.attr("compute"):
		return candidate.attr("compute") > current.attr("compute")
	return candidate.attr("connectivity") > current.attr("connectivity")


## Infiltration always — breadth is what the branch is bought with. Capabilities
## only in Cyber, up to the tier the run has earned. Evasion only once the world
## knows, and then anything of it.
func _allows(node: TechNodeDef, sim: Simulation) -> bool:
	match node.tree:
		TechNodeDef.TREE_INFILTRATION:
			return true
		TechNodeDef.TREE_EVASION:
			return sim.world.discovered
	return node.branch() == TechNodeDef.BRANCH_CYBER and node.tier <= _tier_cap(sim)


static func _is_vector(node: TechNodeDef) -> bool:
	return node.tree == TechNodeDef.TREE_INFILTRATION


func _tier_cap(sim: Simulation) -> int:
	if sim.world.discovered or sim.world.agent.owns(TIER_3_GATE):
		return TechNodeDef.TIER_MAX
	if _vectors(sim) >= VECTORS_FOR_TIER_2:
		return 2
	return 1


func _vectors(sim: Simulation) -> int:
	return _owned_in_tree(sim, TechNodeDef.TREE_INFILTRATION, TechNodeDef.TIER_MIN)
