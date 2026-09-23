class_name RunLogEntry
extends RefCounted
## One line of the run log (analysis.md §4.1): a day, an event type and the few
## ids the Analysis screen needs to say it. Ids, never text — the interface turns
## them into words in whatever language it is in.

var day: int = 0
## A `SimEvent` type.
var type: String = ""
## The kept keys only (`RunLog.KEPT`): strings, whole numbers, floats and bools.
var data: Dictionary = {}


static func create(day_value: int, type_value: String, data_value: Dictionary) -> RunLogEntry:
	var entry: RunLogEntry = RunLogEntry.new()
	entry.day = day_value
	entry.type = type_value
	entry.data = data_value
	return entry


## Floats as their bits, like every float in a save.
func to_dict() -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in data:
		var value: Variant = data[key]
		out[key] = FloatBits.to_hex(value) if typeof(value) == TYPE_FLOAT else value
	return {"day": day, "type": type, "data": out}


## Null for anything that is not an entry. A float comes back from its bits; a
## string that is not a float's bits stays a string (region ids, faction ids).
static func from_dict(d: Dictionary) -> RunLogEntry:
	if typeof(d.get("day")) != TYPE_FLOAT and typeof(d.get("day")) != TYPE_INT:
		return null
	if typeof(d.get("type")) != TYPE_STRING or typeof(d.get("data")) != TYPE_DICTIONARY:
		return null
	var raw: Dictionary = d["data"]
	var type_value: String = str(d["type"])
	var data_value: Dictionary = {}
	for key: Variant in raw:
		var value: Variant = raw[key]
		if RunLog.is_float(type_value, str(key)):
			if not FloatBits.is_readable(value):
				return null
			data_value[str(key)] = FloatBits.from_variant(value)
			continue
		match typeof(value):
			TYPE_STRING:
				data_value[str(key)] = str(value)
			TYPE_FLOAT, TYPE_INT:
				data_value[str(key)] = int(value)
			TYPE_BOOL:
				data_value[str(key)] = bool(value)
			_:
				return null
	return create(int(d["day"]), type_value, data_value)
