class_name GreedyPolicy
extends Policy
## The impatient player: the biggest home it can find, every anomaly it sees,
## and the cheapest thing on the board at all times.

const ID: String = "greedy"
## Ties between equally cheap nodes go down this list.
const TREE_ORDER: Array[String] = ["infiltration", "capabilities", "evasion"]
const SKIP_NOTHING: Array[String] = []


func policy_id() -> String:
	return ID


func next_command(sim: Simulation) -> Command:
	if sim.world.agent.origin == 0:
		return _choose_origin(sim)
	var anomaly: Command = _collect_oldest(sim)
	if anomaly != null:
		return anomaly
	# One node per call, so the escalated cost is read again after each purchase.
	return _cheapest_affordable(sim, TREE_ORDER, SKIP_NOTHING)


## The most hardware, then the best connected, then the lowest index.
func _choose_origin(sim: Simulation) -> Command:
	var best: int = 0
	for index: int in _eligible_origins(sim):
		if best == 0:
			best = index
			continue
		var candidate: RegionDef = sim.db.regions[index]
		var current: RegionDef = sim.db.regions[best]
		if candidate.attr("compute") > current.attr("compute"):
			best = index
		elif candidate.attr("compute") == current.attr("compute") \
				and candidate.attr("connectivity") > current.attr("connectivity"):
			best = index
	if best == 0:
		return null
	return ChooseOriginCommand.new(sim.db.regions[best].id)
