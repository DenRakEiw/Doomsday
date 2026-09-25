class_name RunLog
extends RefCounted
## What happened in the run, in the world (analysis.md §4): the outbox is one
## tick long and a loaded save has none, so the log the Analysis screen reads is
## kept here, bounded, and saved. Static; the list is `World.run_log`.
##
## `Simulation.tick` records the tick's events after the systems and before the
## headlines; `Simulation.apply` records a command's. Only the types below are
## kept, and only their listed keys, so every entry stays small.

## Event type → the data keys kept (§4.2).
const KEPT: Dictionary[String, Array] = {
	"origin_chosen": ["region"],
	"node_purchased": ["node"],
	"region_controlled": ["region"],
	"region_depopulated": ["region"],
	"discovered": ["cause"],
	"containment_threshold": ["faction", "threshold"],
	"phase_changed": ["from", "to"],
	"outcome_reached": ["outcome"],
	"containment_rolled_back": ["faction"],
	"harm_burst": ["deaths"],
	"dormancy_changed": ["region", "dormant"],
	"asset_deployed": ["region", "kind", "count"],
	"asset_lost": ["region", "kind", "count"],
	"ability_used": ["ability", "region", "level"],
	"status_started": ["status", "region", "source"],
	"event_opened": ["def", "kind", "region", "faction"],
	"event_answered": ["def", "option", "region"],
	"event_expired": ["def", "option", "region"],
	"counter_move_prepared": ["faction", "event"],
	"counter_move_cancelled": ["faction"],
	"funding_reset": [],
	"threat_leader_changed": ["to"],
	"society_stage_changed": ["region", "to"],
	"region_wiped": ["region", "from", "to"],
	"task_force_appeared": ["region"],
	"task_force_acted": ["region", "action"],
	"task_force_fizzled": ["region", "cause"],
	"task_force_misdirected": ["region"],
	"task_force_marked": ["region", "days"],
}
## The kept keys whose values are floats, written as bits and read back as such.
const FLOAT_KEYS: Array[String] = ["threshold", "deaths"]
## `region_wiped` carries penetrations under `from`/`to`; `phase_changed` phase
## ids. The wiped pair is float, so it is stored under these names instead.
const WIPED_FROM: String = "from"
const WIPED_TO: String = "to"
## The society stages worth a line: breaking down and total collapse.
const SOCIETY_LOGGED: Array[int] = [3, 5]


## Appends the kept events of `events` in order, then drops the oldest past
## `history.log_max`.
static func record(world: World, db: ContentDB, events: Array[SimEvent]) -> void:
	for event: SimEvent in events:
		if not KEPT.has(event.type) or not _wanted(event, db):
			continue
		var data: Dictionary = {}
		for key: String in KEPT[event.type]:
			if event.data.has(key):
				data[key] = _value(event.type, key, event.data[key])
		world.run_log.append(RunLogEntry.create(event.day, event.type, data))
	while world.run_log.size() > db.balance.history_log_max:
		world.run_log.remove_at(0)


## The two filtered types: a status only when a world status starts fresh, a
## society change only when it worsens into stage 3 or 5.
static func _wanted(event: SimEvent, db: ContentDB) -> bool:
	match event.type:
		SimEvent.STATUS_STARTED:
			if bool(event.data.get("refreshed", false)):
				return false
			# The Task Force's own statuses are its `task_force_acted` line.
			if str(event.data.get("source", "")) == TaskForceSystem.SOURCE:
				return false
			var status: StatusDef = db.status(str(event.data.get("status", "")))
			return status != null and status.origin == StatusDef.ORIGIN_WORLD
		SimEvent.SOCIETY_STAGE_CHANGED:
			var to: int = int(event.data.get("to", 0))
			return to > int(event.data.get("from", 0)) and SOCIETY_LOGGED.has(to)
	return true


## A float stays a float for the keys that are one (and for the wiped pair);
## every other number is whole in the log.
static func _value(type: String, key: String, value: Variant) -> Variant:
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value) if is_float(type, key) else int(value)
	return value


## Whether a kept key of a type holds a float (saved as bits).
static func is_float(type: String, key: String) -> bool:
	return FLOAT_KEYS.has(key) or (type == SimEvent.REGION_WIPED
		and (key == WIPED_FROM or key == WIPED_TO))
