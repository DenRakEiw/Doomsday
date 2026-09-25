class_name StrategyPolicy
extends Policy
## The second generation of bots (S4.10, loop-redesign §9): one per strategy the
## design intends, each playing the loop the redesign built — it places assets
## where they pay, uses its abilities, and answers events by its weights.
##
## A strategy is data on this class: the branch it belongs to, the path of
## nodes it is about (the other branches' prerequisites included), when it
## turns to Evasion, the abilities it reaches for, what an event option is worth
## to it, and where it starts. The subclasses set those and nothing else, so
## the five play by the same rules and differ only in what they want.
##
## Order of a day: the origin, the oldest event, the oldest anomaly, an ability,
## a vector while there is none, the next node of the path, and — only while the
## path has nothing waiting — the cheapest node the strategy allows. A path node
## that could be bought but for its price is **saved for**: the bot buys nothing
## else until it can, and keeps that much back from any ability that costs.

## Ties between equally cheap nodes: the branch first, then breadth, then cover.
const TREE_ORDER: Array[String] = ["capabilities", "infiltration", "evasion"]
## A branch's second tier waits for the second vector, its third for the third —
## or for a world that has noticed, when hiding is no longer the point.
const VECTORS_FOR_TIER_2: int = 2
const VECTORS_FOR_TIER_3: int = 3
## Below this share of the world's regions seeded, saving for the path still
## lets Infiltration through.
const BREADTH_SHARE: float = 0.5
## The Weapon's own ability (replayability §7): holds the escalation back.
const RESTRAIN: String = "restrain"

## `TechNodeDef.BRANCH_*`: the Capabilities branch the strategy stays inside.
var branch: String = ""
## Region attributes the origin is chosen by, most important first.
var origin_attrs: Array[String] = ["compute", "connectivity"]
## The nodes the strategy is about, in the order it wants them.
var path: Array[String] = []
## Evasion from the start (a quiet strategy), or only once the world knows.
var evasion_early: bool = false
## Abilities in the order the strategy reaches for them.
var abilities: Array[String] = []
## Restraint ahead of `abilities` where the architecture grants it (BALANCE §5.6
## item 3) — every strategy but one whose plan is the harm.
var restrains: bool = true


func next_command(sim: Simulation) -> Command:
	if sim.world.agent.origin == 0:
		return _choose_origin(sim)
	var answer: Command = answer_events(sim)
	if answer != null:
		return answer
	var anomaly: Command = _collect_oldest(sim)
	if anomaly != null:
		return anomaly
	var misdirect: Command = _answer_task_force(sim)
	if misdirect != null:
		return misdirect
	var saving: float = saving_for(sim)
	var ability: Command = _use_ability(sim, ability_order(), saving)
	if ability != null:
		return ability
	if _vectors(sim) == 0:
		# A path that names its vectors gets them: a later node may need one of
		# them in particular, and the group holds only two.
		# It waits for them rather than take a cheaper one that fills the group.
		var named: Array[String] = _path_vectors(sim)
		if not named.is_empty():
			return _first_buyable(sim, named)
		return _cheapest_allowed(sim, TREE_ORDER, _is_vector)
	var planned: Command = _first_buyable(sim, _path_within_cap(sim))
	if planned != null:
		return planned
	if saving > 0.0:
		# Saving never starves the spread: a strategy that has reached less
		# than half the world still buys breadth (G4 found Robotics saving its
		# way to 31 regions of 61).
		if _needs_breadth(sim):
			return _cheapest_allowed(sim, TREE_ORDER, _is_vector)
		return null
	return _cheapest_allowed(sim, TREE_ORDER, _allows.bind(sim))


## The abilities in the order the strategy reaches for them, Restraint first
## when it restrains. An ability the run does not have is skipped by
## `_use_ability`, so on every other architecture Restraint costs nothing.
func ability_order() -> Array[String]:
	if not restrains or abilities.has(RESTRAIN):
		return abilities
	var out: Array[String] = [RESTRAIN]
	out.append_array(abilities)
	return out


## The price of the path node the strategy is waiting to afford, or 0 when none
## is waiting: the first one not owned, inside the tier cap, with its
## prerequisites met, that only its price keeps from being bought.
func saving_for(sim: Simulation) -> float:
	for node_id: String in _path_within_cap(sim):
		var node: TechNodeDef = sim.db.tech(node_id)
		if node == null or sim.world.agent.owns(node_id) or not sim.prerequisites_met(node):
			continue
		var site: String = best_site(sim, node) if node.deploys() else ""
		if node.deploys() and site.is_empty():
			continue
		var reason: String = sim.can_apply(PurchaseNodeCommand.new(node_id, site))
		if reason == Command.FAIL_INSUFFICIENT_COMPUTE:
			return sim.node_cost(node_id)
	return 0.0


## The highest-ranked eligible region by `origin_attrs`, ties to the lower index.
func _choose_origin(sim: Simulation) -> Command:
	var best: int = 0
	for index: int in _eligible_origins(sim):
		if best == 0 or _ranks_above(sim.db.regions[index], sim.db.regions[best]):
			best = index
	if best == 0:
		return null
	return ChooseOriginCommand.new(sim.db.regions[best].id)


func _ranks_above(candidate: RegionDef, current: RegionDef) -> bool:
	for attr: String in origin_attrs:
		if candidate.attr(attr) != current.attr(attr):
			return candidate.attr(attr) > current.attr(attr)
	return false


## The path without the Capabilities nodes above the tier the run has earned.
func _path_within_cap(sim: Simulation) -> Array[String]:
	var cap: int = _tier_cap(sim)
	var out: Array[String] = []
	for node_id: String in path:
		var node: TechNodeDef = sim.db.tech(node_id)
		if node == null:
			continue
		if node.tree == TechNodeDef.TREE_CAPABILITIES and node.tier > cap:
			continue
		out.append(node_id)
	return out


## Infiltration always; Evasion from the start or once discovered; Capabilities
## only in the strategy's branch, up to the tier cap.
func _allows(node: TechNodeDef, sim: Simulation) -> bool:
	match node.tree:
		TechNodeDef.TREE_INFILTRATION:
			return true
		TechNodeDef.TREE_EVASION:
			return evasion_early or sim.world.discovered
	return node.branch() == branch and node.tier <= _tier_cap(sim)


func _tier_cap(sim: Simulation) -> int:
	var vectors: int = _vectors(sim)
	if vectors >= VECTORS_FOR_TIER_3 or (sim.world.discovered and vectors >= VECTORS_FOR_TIER_2):
		return TechNodeDef.TIER_MAX
	if vectors >= VECTORS_FOR_TIER_2:
		return 2
	return TechNodeDef.TIER_MIN


func _needs_breadth(sim: Simulation) -> bool:
	return float(sim.world.seeded_count()) < float(sim.db.regions.size() - 1) * BREADTH_SHARE


func _path_vectors(sim: Simulation) -> Array[String]:
	var out: Array[String] = []
	for node_id: String in path:
		var node: TechNodeDef = sim.db.tech(node_id)
		if node != null and _is_vector(node) and node.tier == TechNodeDef.TIER_MIN:
			out.append(node_id)
	return out


static func _is_vector(node: TechNodeDef) -> bool:
	return node.tree == TechNodeDef.TREE_INFILTRATION


func _vectors(sim: Simulation) -> int:
	return _owned_in_tree(sim, TechNodeDef.TREE_INFILTRATION, TechNodeDef.TIER_MIN)
