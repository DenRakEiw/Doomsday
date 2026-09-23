class_name CommandCodec
extends RefCounted
## Turns a logged command back into a `Command`, for replaying a save.
##
## The one place that knows every command type. Each build step that adds a
## command adds its line to `_make` — S1.3 `choose_origin`, S1.4 `purchase_node`
## and `collect_anomaly`, S3.1 `set_dormancy`, S4.2 `use_ability`, S4.3 `choose_event_option` — and nothing
## else changes.

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


## The command types, by id. Each reads its own fields and returns null when one
## of them is missing or of the wrong type.
static func _make(type: String, d: Dictionary) -> Command:
	if type == ChooseOriginCommand.TYPE_ID:
		var region: String = read_id(d, "region")
		if region.is_empty():
			return null
		return ChooseOriginCommand.new(region)
	if type == PurchaseNodeCommand.TYPE_ID:
		var node: String = read_id(d, "node")
		if node.is_empty():
			return null
		# A log written before the deploy sites carries no region, and a node
		# that places nothing never has one: an absent field reads as "none".
		if d.has("region") and typeof(d["region"]) != TYPE_STRING:
			return null
		return PurchaseNodeCommand.new(node, str(d.get("region", "")))
	if type == SetDormancyCommand.TYPE_ID:
		var dormancy_region: String = read_id(d, "region")
		if dormancy_region.is_empty():
			return null
		if not d.has("dormant") or typeof(d["dormant"]) != TYPE_BOOL:
			return null
		return SetDormancyCommand.new(dormancy_region, bool(d["dormant"]))
	if type == UseAbilityCommand.TYPE_ID:
		var ability: String = read_id(d, "ability")
		if ability.is_empty():
			return null
		# A global ability carries an empty region, which is a string like any
		# other — only a missing or ill-typed field is a corrupt log.
		if not d.has("region") or typeof(d["region"]) != TYPE_STRING:
			return null
		return UseAbilityCommand.new(ability, str(d["region"]))
	if type == ChooseEventOptionCommand.TYPE_ID:
		var event: int = read_int(d, "event")
		var option: String = read_id(d, "option")
		if event == INVALID or option.is_empty():
			return null
		return ChooseEventOptionCommand.new(event, option)
	if type == CollectAnomalyCommand.TYPE_ID:
		var anomaly: int = read_int(d, "anomaly")
		if anomaly == INVALID:
			return null
		return CollectAnomalyCommand.new(anomaly)
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
