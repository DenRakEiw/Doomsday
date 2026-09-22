class_name SimEvent
extends RefCounted
## Something the simulation reports, in the outbox of a tick or in the result of
## a command. `core/` has no signals: the `Game` autoload (S2.1) drains both and
## re-emits them on `EventBus`.
##
## This class owns the event vocabulary (core.md §6.4). `data` holds plain values
## only — String, int, float, bool — and names regions by **id**, never by index.

const ORIGIN_CHOSEN: String = "origin_chosen"
const NODE_PURCHASED: String = "node_purchased"
const ANOMALY_COLLECTED: String = "anomaly_collected"
const REGION_SEEDED: String = "region_seeded"
const REGION_CONTROLLED: String = "region_controlled"
const ANOMALY_SPAWNED: String = "anomaly_spawned"
const ANOMALY_EXPIRED: String = "anomaly_expired"
const MILESTONE_REACHED: String = "milestone_reached"
const REGION_DEPOPULATED: String = "region_depopulated"
const DISCOVERED: String = "discovered"
const CONTAINMENT_THRESHOLD: String = "containment_threshold"
const PHASE_CHANGED: String = "phase_changed"
const OUTCOME_REACHED: String = "outcome_reached"
const CONTAINMENT_ROLLED_BACK: String = "containment_rolled_back"
const COMPUTE_GRANTED: String = "compute_granted"
const HARM_BURST: String = "harm_burst"
const DORMANCY_CHANGED: String = "dormancy_changed"

## Causes of `DISCOVERED`.
const CAUSE_SCRUTINY: String = "scrutiny"
const CAUSE_DEATHS: String = "deaths"

var type: String
var day: int
var data: Dictionary


func _init(p_type: String, p_day: int, p_data: Dictionary) -> void:
	type = p_type
	day = p_day
	data = p_data


func to_dict() -> Dictionary:
	return {"type": type, "day": day, "data": data}


func _to_string() -> String:
	return "%s day %d %s" % [type, day, data]
