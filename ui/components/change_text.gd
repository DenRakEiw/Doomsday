class_name ChangeText
extends RefCounted
## What an answer changed, as generated lines (plain-language.md §5.2 C2): the
## events the command produced, each said once — a node gained, a status with its
## days, compute, regions reached, containment moved. The event card and the wire
## card show these above the result line, so the flavour never has to carry them.
##
## Pure text: a test reads them from a `CommandResult` without a scene.
## Never instantiated; a namespace of static functions.

const KEY_TITLE: String = "UI_EVENT_CHANGED"
const KEY_NODE: String = "UI_EVENT_CHANGED_NODE"
const KEY_STATUS: String = "UI_EVENT_CHANGED_STATUS"
const KEY_STATUS_REGION: String = "UI_EVENT_CHANGED_STATUS_REGION"
const KEY_STATUS_ENDED: String = "UI_EVENT_CHANGED_STATUS_ENDED"
const KEY_COMPUTE: String = "UI_EVENT_CHANGED_COMPUTE"
const KEY_SEEDED: String = "UI_EVENT_CHANGED_SEEDED"
const KEY_CONTAINMENT: String = "UI_EVENT_CHANGED_CONTAINMENT"
const KEY_CONTAINMENT_TO: String = "UI_EVENT_CHANGED_CONTAINMENT_TO"
const KEY_PRESENCE: String = "UI_EVENT_CHANGED_PRESENCE"
const KEY_CONTROL: String = "UI_EVENT_CHANGED_CONTROL"
const KEY_ASSET_GAINED: String = "UI_EVENT_CHANGED_ASSET_GAINED"
const KEY_ASSET_LOST: String = "UI_EVENT_CHANGED_ASSET_LOST"
const KEY_DEATHS: String = "UI_EVENT_CHANGED_DEATHS"
const KEY_FOOTPRINT: String = "EFFECT_FOOTPRINT_PULSE"
## Every key this file names — the strings test reads this list.
const KEYS: Array[String] = [KEY_TITLE, KEY_NODE, KEY_STATUS, KEY_STATUS_REGION,
	KEY_STATUS_ENDED, KEY_COMPUTE, KEY_SEEDED, KEY_CONTAINMENT, KEY_CONTAINMENT_TO,
	KEY_PRESENCE, KEY_CONTROL, KEY_ASSET_GAINED, KEY_ASSET_LOST, KEY_DEATHS]
const PREFIX_REGION: String = "REGION_"
const PREFIX_FACTION: String = "FACTION_"
## The placeholders a result line may take from the answer's events (C2).
const PLACEHOLDER_NODE: String = "node"
const PLACEHOLDER_DAYS: String = "days"


## One line per event that says something to the player, in the order they
## happened. `day` is the day of the answer, for the days a status has left.
static func lines(events: Array[SimEvent], day: int) -> PackedStringArray:
	var out: PackedStringArray = []
	for event: SimEvent in events:
		var said: String = line(event, day)
		if not said.is_empty() and not out.has(said):
			out.append(said)
	return out


## One event as a line, or "" for an event the answer's summary leaves out.
static func line(event: SimEvent, day: int) -> String:
	var data: Dictionary = event.data
	match event.type:
		SimEvent.NODE_PURCHASED:
			return _tr(KEY_NODE).format({"node": TechText.node_name(str(data["node"]))})
		SimEvent.STATUS_STARTED:
			return _status_line(data, day)
		SimEvent.STATUS_ENDED:
			return _tr(KEY_STATUS_ENDED).format(
				{"status": _tr(StatusDef.name_key(str(data["status"])))})
		SimEvent.COMPUTE_GRANTED:
			return _tr(KEY_COMPUTE).format(
				{"value": Format.number(float(data["value"]), Format.Kind.COMPUTE)})
		SimEvent.REGION_SEEDED:
			return _tr(KEY_SEEDED).format({"region": _region(str(data["region"]))})
		SimEvent.CONTAINMENT_ADDED:
			return _tr(KEY_CONTAINMENT).format({
				"faction": _faction(str(data["faction"])),
				"value": Format.signed_percent(float(data["value"])),
			})
		SimEvent.CONTAINMENT_ROLLED_BACK:
			return _tr(KEY_CONTAINMENT_TO).format({
				"faction": _faction(str(data["faction"])),
				"from": Format.percent(float(data["from"])),
				"to": Format.percent(float(data["to"])),
			})
		SimEvent.PENETRATION_CHANGED, SimEvent.REGION_WIPED:
			return _from_to(KEY_PRESENCE, data)
		SimEvent.CONTROL_CHANGED:
			return _from_to(KEY_CONTROL, data)
		SimEvent.ASSET_DEPLOYED:
			return _asset(KEY_ASSET_GAINED, data)
		SimEvent.ASSET_LOST:
			return _asset(KEY_ASSET_LOST, data)
		SimEvent.HARM_BURST:
			if float(data["deaths"]) <= 0.0:
				return ""
			return _tr(KEY_DEATHS).format(
				{"count": Format.number(float(data["deaths"]), Format.Kind.COMPACT)})
		SimEvent.PULSE_STARTED:
			var value: float = float(data["value"])
			var signed: String = Format.number(value, Format.Kind.PLAIN)
			if value > 0.0:
				signed = ValueLabel.PLUS + signed
			return _tr(KEY_FOOTPRINT).format({
				"value": signed,
				"days": int(data["until_day"]) - day,
			})
	return ""


## What a result line may name besides its region (C2): the node an answer
## granted and the days the status it started runs — the first of each.
static func result_args(events: Array[SimEvent], day: int) -> Dictionary:
	var args: Dictionary = {}
	for event: SimEvent in events:
		if event.type == SimEvent.NODE_PURCHASED and not args.has(PLACEHOLDER_NODE):
			args[PLACEHOLDER_NODE] = TechText.node_name(str(event.data["node"]))
		elif event.type == SimEvent.STATUS_STARTED and not args.has(PLACEHOLDER_DAYS):
			args[PLACEHOLDER_DAYS] = _days_left(event.data, day)
	return args


## The nodes an answer handed over for nothing — what the tree marks (C2).
static func granted_nodes(events: Array[SimEvent]) -> Array[String]:
	var out: Array[String] = []
	for event: SimEvent in events:
		if event.type == SimEvent.NODE_PURCHASED:
			out.append(str(event.data["node"]))
	return out


static func _status_line(data: Dictionary, day: int) -> String:
	var until_day: int = int(data["until_day"])
	var time: String = _tr(StatusText.KEY_STANDING)
	if until_day != Status.UNTIL_STANDING:
		time = _tr(StatusText.KEY_DAYS_LEFT).format({"days": until_day - day})
	var region: String = str(data["region"])
	var args: Dictionary = {
		"status": _tr(StatusDef.name_key(str(data["status"]))),
		"region": _region(region),
		"time": time,
	}
	return _tr(KEY_STATUS if region.is_empty() else KEY_STATUS_REGION).format(args)


static func _days_left(data: Dictionary, day: int) -> int:
	var until_day: int = int(data["until_day"])
	return 0 if until_day == Status.UNTIL_STANDING else until_day - day


static func _from_to(key: String, data: Dictionary) -> String:
	return _tr(key).format({
		"region": _region(str(data["region"])),
		"from": Format.percent(float(data["from"])),
		"to": Format.percent(float(data["to"])),
	})


static func _asset(key: String, data: Dictionary) -> String:
	var count: int = int(data["count"])
	return _tr(key).format({
		"count": count,
		"kind": TechText.asset_name(str(data["kind"]), count),
		"region": _region(str(data["region"])),
	})


static func _region(region_id: String) -> String:
	if region_id.is_empty():
		return ""
	return _tr(PREFIX_REGION + region_id.to_upper())


static func _faction(faction_id: String) -> String:
	return _tr(PREFIX_FACTION + faction_id.to_upper())


static func _tr(key: String) -> String:
	return TechText.tr_key(key)
