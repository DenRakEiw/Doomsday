class_name StealthPolicy
extends Policy
## The careful player: a backwater to start in, and nothing loud bought until the
## world is already mostly taken.

const ID: String = "stealth"
## Ties go down this list — evasion before capabilities, which is the whole
## difference from `greedy`.
const TREE_ORDER: Array[String] = ["infiltration", "evasion", "capabilities"]
## Below this share of the world, capabilities are not worth being seen for. A
## policy constant, not game balance.
const CAPABILITY_SHARE: float = 0.8
const SKIP_CAPABILITIES: Array[String] = ["capabilities"]
const SKIP_NOTHING: Array[String] = []


func policy_id() -> String:
	return ID


func next_command(sim: Simulation) -> Command:
	if sim.world.agent.origin == 0:
		return _choose_origin(sim)
	var anomaly: Command = _collect_oldest(sim)
	if anomaly != null:
		return anomaly
	var skip: Array[String] = SKIP_NOTHING
	if sim.world.infected_share(sim.db) < CAPABILITY_SHARE:
		skip = SKIP_CAPABILITIES
	return _cheapest_affordable(sim, TREE_ORDER, skip)


## The least regulated, then the most hardware, then the lowest index.
func _choose_origin(sim: Simulation) -> Command:
	var best: int = 0
	for index: int in _eligible_origins(sim):
		if best == 0:
			best = index
			continue
		var candidate: RegionDef = sim.db.regions[index]
		var current: RegionDef = sim.db.regions[best]
		if candidate.attr("regulation") < current.attr("regulation"):
			best = index
		elif candidate.attr("regulation") == current.attr("regulation") \
				and candidate.attr("compute") > current.attr("compute"):
			best = index
	if best == 0:
		return null
	return ChooseOriginCommand.new(sim.db.regions[best].id)
