class_name DriftSystem
extends SimSystem
## The Swarm's `drift` hook (`replayability.md` §2.2): how far its copies have
## wandered, and what a copy that has wandered far enough does.
##
## Drift rises a little every day and by a step whenever an emergent behaviour is
## kept (`EventSystem`), and falls when one is suppressed. Each day, with chance
## `drift / 100 × defect_chance`, one region the agent holds well enough
## **defects**: its yield goes to the copies for a while (status `defected`). At
## drift 60 Value Drift may come — its own `when` says so. Every other
## architecture has no drift, rolls nothing here and spends no draw of the stream.

const DRIFT_MAX: float = 100.0
const STATUS_DEFECTED: String = "defected"
## The source a defection is applied under, and what the log says it came from.
const SOURCE_DRIFT: String = "drift"


func tick(world: World, db: ContentDB, events: Array[SimEvent]) -> void:
	if world.agent.origin == 0 or not world.has_hook(db, ArchitectureDef.HOOK_DRIFT):
		return
	var agent: Agent = world.agent
	agent.drift = minf(DRIFT_MAX, agent.drift + db.balance.drift_per_day)
	var chance: float = agent.drift / DRIFT_MAX * db.balance.drift_defect_chance
	if chance <= 0.0 or not world.rng.chance(clampf(chance, 0.0, 1.0)):
		return
	var candidates: PackedInt32Array = defectable(world, db)
	if candidates.is_empty():
		return
	var weights: PackedFloat64Array = []
	weights.resize(candidates.size())
	weights.fill(1.0)
	var picked: int = world.rng.weighted_pick(weights)
	if picked < 0:
		return
	StatusSystem.apply(world, db, STATUS_DEFECTED, candidates[picked], SOURCE_DRIFT, 1, "",
		events, db.balance.drift_defect_days)


## The regions a copy could defect in, in index order: held well enough, awake,
## not dark, and not already gone over.
static func defectable(world: World, db: ContentDB) -> PackedInt32Array:
	var out: PackedInt32Array = []
	for i: int in range(1, world.regions.size()):
		var region: Region = world.regions[i]
		if region.dark or region.dormant:
			continue
		if region.penetration < db.balance.drift_defect_min_penetration:
			continue
		if world.status_in_region(STATUS_DEFECTED, i) != null:
			continue
		out.append(i)
	return out
