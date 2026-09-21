class_name HistorySample
extends RefCounted
## One row of the run's history, taken every `balance.history_interval_days` and
## once more when the outcome is set (core.md §7.8). The Analysis screen of M4
## draws its charts from these; nothing in the simulation reads them back.

var day: int = 0
var compute: float = 0.0
var compute_earned: float = 0.0
var seeded: int = 0
var share: float = 0.0
var alive: float = 0.0
var deaths: float = 0.0
## The highest containment of any faction.
var containment: float = 0.0
var footprint: float = 0.0
## A phase id, never the enum value.
var phase: String = ""


func to_dict() -> Dictionary:
	return {
		"day": day,
		"compute": compute,
		"compute_earned": compute_earned,
		"seeded": seeded,
		"share": share,
		"alive": alive,
		"deaths": deaths,
		"containment": containment,
		"footprint": footprint,
		"phase": phase,
	}


## Null when a field is missing or of the wrong type.
static func from_dict(d: Dictionary) -> HistorySample:
	for key: String in ["day", "compute", "compute_earned", "seeded", "share", "alive", "deaths",
			"containment", "footprint"]:
		if not d.has(key):
			return null
		var type: int = typeof(d[key])
		if type != TYPE_FLOAT and type != TYPE_INT:
			return null
	if not d.has("phase") or typeof(d["phase"]) != TYPE_STRING:
		return null
	if not World.PHASE_IDS.has(d["phase"]):
		return null

	var sample: HistorySample = HistorySample.new()
	sample.day = int(d["day"])
	sample.compute = float(d["compute"])
	sample.compute_earned = float(d["compute_earned"])
	sample.seeded = int(d["seeded"])
	sample.share = float(d["share"])
	sample.alive = float(d["alive"])
	sample.deaths = float(d["deaths"])
	sample.containment = float(d["containment"])
	sample.footprint = float(d["footprint"])
	sample.phase = str(d["phase"])
	return sample
