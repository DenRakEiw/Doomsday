class_name CollectAnomalyCommand
extends Command
## Picks up an anomaly before it expires. The only thing in M1 that rewards
## watching the map rather than the numbers.

const TYPE_ID: String = "collect_anomaly"

var anomaly: int


func _init(p_anomaly: int = 0) -> void:
	anomaly = p_anomaly


func type_id() -> String:
	return TYPE_ID


func validate(sim: Simulation) -> String:
	if sim.world.agent.origin == 0:
		return FAIL_NO_ORIGIN
	# One reason for all three ways of missing: never existed, already expired,
	# already collected. The player cannot tell them apart either.
	if _find(sim) == null:
		return FAIL_UNKNOWN_ANOMALY
	return ""


func execute(sim: Simulation, events: Array[SimEvent]) -> void:
	var found: Anomaly = _find(sim)
	sim.world.agent.compute += found.value
	sim.world.agent.compute_earned += found.value
	sim.world.anomalies.erase(found)
	events.append(SimEvent.new(SimEvent.ANOMALY_COLLECTED, sim.world.day, {
		"anomaly": found.id,
		"region": sim.world.regions[found.region].def.id,
		"value": found.value,
	}))


func _find(sim: Simulation) -> Anomaly:
	for candidate: Anomaly in sim.world.anomalies:
		if candidate.id == anomaly:
			return candidate
	return null


func to_dict() -> Dictionary:
	var d: Dictionary = super()
	d["anomaly"] = anomaly
	return d
