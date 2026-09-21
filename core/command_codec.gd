class_name CommandCodec
extends RefCounted
## Turns a logged command back into a `Command`, for replaying a save.
##
## The one place that knows every command type. Each build step that adds a
## command adds its line to `_make` — S1.3 `choose_origin`, S1.4 `purchase_node`
## and `collect_anomaly` — and nothing else changes.

## What `read_int` returns for a field it could not read. No command field is
## negative, so it cannot collide with a real value.
const INVALID: int = -1


## Null for an unknown type or a field that is missing or of the wrong type. A
## null here is a corrupt log, which the save reader reports as such.
static func from_dict(d: Dictionary) -> Command:
	if not d.has("type") or typeof(d["type"]) != TYPE_STRING:
		return null
	if not d.has("day"):
		return null
	var day_type: int = typeof(d["day"])
	if day_type != TYPE_FLOAT and day_type != TYPE_INT:
		return null
	var day: float = float(d["day"])
	if day != floor(day):
		return null

	var command: Command = _make(str(d["type"]), d)
	if command == null:
		return null
	command.day = int(day)
	return command


## The command types, by id.
@warning_ignore("unused_parameter")
static func _make(type: String, d: Dictionary) -> Command:
	# S1.3 adds "choose_origin"; S1.4 adds "purchase_node" and "collect_anomaly".
	return null


## Reads a required id field, or "" when it is missing or not a string.
static func read_id(d: Dictionary, key: String) -> String:
	if not d.has(key) or typeof(d[key]) != TYPE_STRING:
		return ""
	return str(d[key])


## Reads a required whole number, or `INVALID` when it is missing, not a number
## or fractional. JSON has no integers, so this is a value check, not a type one.
static func read_int(d: Dictionary, key: String) -> int:
	if not d.has(key):
		return INVALID
	var type: int = typeof(d[key])
	if type != TYPE_FLOAT and type != TYPE_INT:
		return INVALID
	var value: float = float(d[key])
	if value != floor(value):
		return INVALID
	return int(value)
