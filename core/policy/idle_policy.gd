class_name IdlePolicy
extends Policy
## Does nothing but pick a home and half-heartedly pick things up.
##
## The floor of the balance baselines: whatever the numbers say, a player who
## does nothing must lose, and must lose to containment.

const ID: String = "idle"
## The chance of bothering with a given anomaly today. A policy constant, not
## game balance — it never belongs in `balance.json`.
const COLLECT_CHANCE: float = 0.5

## The day the anomalies were last decided on, so the roll happens once a day.
var _decided_day: int = -1
var _queue: Array[int] = []


func policy_id() -> String:
	return ID


func next_command(sim: Simulation) -> Command:
	if sim.world.agent.origin == 0:
		var eligible: PackedInt32Array = _eligible_origins(sim)
		if eligible.is_empty():
			return null
		var pick: int = eligible[_rng.randi_range(0, eligible.size() - 1)]
		return ChooseOriginCommand.new(sim.db.regions[pick].id)

	if _decided_day != sim.world.day:
		_decided_day = sim.world.day
		_queue.clear()
		for anomaly: Anomaly in sim.world.anomalies:
			if _rng.chance(COLLECT_CHANCE):
				_queue.append(anomaly.id)

	while not _queue.is_empty():
		var id: int = _queue.pop_front()
		var command: CollectAnomalyCommand = CollectAnomalyCommand.new(id)
		# An anomaly decided on this morning may have expired since.
		if sim.can_apply(command).is_empty():
			return command
	return null
