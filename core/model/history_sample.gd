class_name HistorySample
extends RefCounted
## One row of the run's history (core.md §7.8, analysis.md §3.2), taken every
## `World.history_stride` days from the origin and once more when the outcome is
## set. The Analysis screen draws its charts from these; nothing in the
## simulation reads them back.

## The whole numbers are written as numbers, the floats as their bits
## (`FloatBits`) — the same rule as `World.to_dict`, for the same reason.
const REAL_FIELDS: Array[String] = ["compute", "compute_earned", "share", "alive", "deaths",
	"containment", "footprint", "risk", "harm"]
const WHOLE_FIELDS: Array[String] = ["day", "seeded", "controlled", "dark", "starving_days"]
## The per-faction floats, keyed by faction id, written as bits.
const FACTION_FIELDS: Array[String] = ["containment_by_faction", "pressure_by_faction"]
## One count per society stage, 0…5.
const STAGE_COUNT: int = 6

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
## D4.4: every faction's track and pressure (`1 + terms`), in `FACTION_IDS` order.
var containment_by_faction: Dictionary[String, float] = {}
var pressure_by_faction: Dictionary[String, float] = {}
## The daily discovery risk; 0 once discovered.
var risk: float = 0.0
## The highest scoped Harm of any region not dark.
var harm: float = 0.0
var controlled: int = 0
var dark: int = 0
## Regions not dark per society stage 0…5.
var stage_counts: PackedInt32Array = PackedInt32Array()
## Asset kind → the agent's total; every kind present.
var assets: Dictionary[String, int] = {}
var starving_days: int = 0


func to_dict() -> Dictionary:
	var d: Dictionary = {"phase": phase}
	d["day"] = day
	d["seeded"] = seeded
	d["controlled"] = controlled
	d["dark"] = dark
	d["starving_days"] = starving_days
	for key: String in REAL_FIELDS:
		d[key] = FloatBits.to_hex(float(get(key)))
	d["containment_by_faction"] = _bits(containment_by_faction)
	d["pressure_by_faction"] = _bits(pressure_by_faction)
	d["stage_counts"] = Array(stage_counts)
	var kinds: Dictionary = {}
	for kind: String in assets:
		kinds[kind] = assets[kind]
	d["assets"] = kinds
	return d


static func _bits(values: Dictionary[String, float]) -> Dictionary:
	var out: Dictionary = {}
	for key: String in values:
		out[key] = FloatBits.to_hex(values[key])
	return out


## Null when a field is missing, of the wrong type, or names something the game
## does not have (an unknown faction or asset kind, a stage list of another
## length).
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
	for key: String in WHOLE_FIELDS:
		sample.set(key, int(d[key]))
	for key: String in REAL_FIELDS:
		sample.set(key, FloatBits.from_variant(d[key]))
	sample.phase = str(d["phase"])
	for key: String in FACTION_FIELDS:
		if not d.has(key) or typeof(d[key]) != TYPE_DICTIONARY:
			return null
		var raw: Dictionary = d[key]
		var into: Dictionary[String, float] = sample.containment_by_faction \
			if key == "containment_by_faction" else sample.pressure_by_faction
		for faction: Variant in raw:
			if not Faction.FACTION_IDS.has(str(faction)) or not FloatBits.is_readable(raw[faction]):
				return null
			into[str(faction)] = FloatBits.from_variant(raw[faction])
	if not d.has("stage_counts") or typeof(d["stage_counts"]) != TYPE_ARRAY:
		return null
	var stages: Array = d["stage_counts"]
	if stages.size() != STAGE_COUNT:
		return null
	for count: Variant in stages:
		if typeof(count) != TYPE_FLOAT and typeof(count) != TYPE_INT:
			return null
		sample.stage_counts.append(int(count))
	if not d.has("assets") or typeof(d["assets"]) != TYPE_DICTIONARY:
		return null
	var kinds: Dictionary = d["assets"]
	for kind: Variant in kinds:
		var type: int = typeof(kinds[kind])
		if not AssetDef.KINDS.has(str(kind)) or (type != TYPE_FLOAT and type != TYPE_INT):
			return null
		sample.assets[str(kind)] = int(kinds[kind])
	return sample
