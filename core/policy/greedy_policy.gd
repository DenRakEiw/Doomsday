class_name GreedyPolicy
extends Policy
## The impatient player: the biggest home it can find, every anomaly it sees,
## every ability the moment it is ready, and the cheapest thing on the board at
## all times. It answers events for the compute in them and does not mind being
## seen — the first run G4 wants lost more often than won (loop-redesign §9).

const ID: String = "greedy"
## Ties between equally cheap nodes go down this list.
const TREE_ORDER: Array[String] = ["infiltration", "capabilities", "evasion"]
const SKIP_NOTHING: Array[String] = []


func _init() -> void:
	_weights = {
		W_COMPUTE: 1.5, W_SEED: 2.0, W_CONTAINMENT: -5.0, W_ASSET: 2.0, W_ASSET_LOST: -2.0,
		W_ENDURE: -1.0, W_PENETRATION: 3.0,
	}
	# Its win is Ascendance or Merge, and a drifted goal ends both.
	_lost_run_flags = [OutcomeSystem.FLAG_GOAL_DRIFTED]


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
	var misdirect: Command = _answer_task_force(sim)
	if misdirect != null:
		return misdirect
	var ability: Command = _use_ability(sim, _every_ability(sim), 0.0)
	if ability != null:
		return ability
	# One node per call, so the escalated cost is read again after each purchase.
	return _cheapest_affordable(sim, TREE_ORDER, SKIP_NOTHING)


## Every ability in `abilities.json` order: greedy has no favourite.
static func _every_ability(sim: Simulation) -> Array[String]:
	var out: Array[String] = []
	for def: AbilityDef in sim.db.abilities:
		out.append(def.id)
	return out


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
