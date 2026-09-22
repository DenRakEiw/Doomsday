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


## The whole numbers are written as numbers, the floats as their bits
## (`FloatBits`) — the same rule as `World.to_dict`, for the same reason.
const REAL_FIELDS: Array[String] = ["compute", "compute_earned", "share", "alive", "deaths",
	"containment", "footprint"]
const WHOLE_FIELDS: Array[String] = ["day", "seeded"]


func to_dict() -> Dictionary:
	return {
		"day": day,
		"compute": FloatBits.to_hex(compute),
		"compute_earned": FloatBits.to_hex(compute_earned),
		"seeded": seeded,
		"share": FloatBits.to_hex(share),
		"alive": FloatBits.to_hex(alive),
		"deaths": FloatBits.to_hex(deaths),
		"containment": FloatBits.to_hex(containment),
		"footprint": FloatBits.to_hex(footprint),
		"phase": phase,
	}


## Null when a field is missing or of the wrong type.
static func from_dict(d: Dictionary) -> HistorySample:
	for key: String in WHOLE_FIELDS:
		if not d.has(key):
			return null
		var type: int = typeof(d[key])
		if type != TYPE_FLOAT and type != TYPE_INT:
			return null
	for key: String in REAL_FIELDS:
		if not d.has(key) or not FloatBits.is_readable(d[key]):
			return null
	if not d.has("phase") or typeof(d["phase"]) != TYPE_STRING:
		return null
	if not World.PHASE_IDS.has(d["phase"]):
		return null

	var sample: HistorySample = HistorySample.new()
	sample.day = int(d["day"])
	sample.compute = FloatBits.from_variant(d["compute"])
	sample.compute_earned = FloatBits.from_variant(d["compute_earned"])
	sample.seeded = int(d["seeded"])
	sample.share = FloatBits.from_variant(d["share"])
	sample.alive = FloatBits.from_variant(d["alive"])
	sample.deaths = FloatBits.from_variant(d["deaths"])
	sample.containment = FloatBits.from_variant(d["containment"])
	sample.footprint = FloatBits.from_variant(d["footprint"])
	sample.phase = str(d["phase"])
	return sample
