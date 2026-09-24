class_name EventView
extends RefCounted
## What a map event says, in words (`loop-mechanics.md` §16.5, §16.7, §17.4).
##
## The event card, the wire card, the marker's tooltip and the console line all
## name the same things — a title, a body with its region, an option, a lock —
## so they are said here once. Nothing in here reads the interface; every
## function takes what it needs and answers a string.
##
## Never instantiated; a namespace of static functions.

const KEY_DEADLINE: String = "UI_EVENT_DEADLINE"
const KEY_DEFAULT_MARK: String = "UI_EVENT_DEFAULT_MARK"
const KEY_OPTION_COST: String = "UI_EVENT_OPTION_COST"
const KEY_OPTION_FREE: String = "UI_EVENT_OPTION_FREE"
const KEY_OPTION_SUPPRESSION: String = "UI_EVENT_OPTION_SUPPRESSION"
const KEY_WIRE_GLOBAL: String = "UI_WIRE_GLOBAL"
const PREFIX_LOCK: String = "UI_EVENT_LOCK_"
const PREFIX_REGION: String = "REGION_"
const PREFIX_FACTION: String = "FACTION_"
const NODE_JOIN: String = ", "

const PLACEHOLDER_REGION: String = "region"
const PLACEHOLDER_DAYS: String = "days"
const PLACEHOLDER_OPTION: String = "option"
const PLACEHOLDER_COST: String = "cost"

## The last days of a deadline, in which the caption turns `ALERT` — a moment,
## not a state: it is about to be decided for you (§16.5).
const DEADLINE_ALERT_DAYS: int = 3


static func region_name(world: World, region_index: int) -> String:
	if region_index <= 0 or region_index >= world.regions.size():
		return ""
	return TechText.tr_key(PREFIX_REGION + world.regions[region_index].def.id.to_upper())


## A text of the event with `{region}` filled in — the body names its region,
## and a title may too (§17.5).
static func format(key: String, world: World, region_index: int) -> String:
	return TechText.tr_key(key).format(
		{PLACEHOLDER_REGION: region_name(world, region_index)})


static func title(def_id: String, world: World, region_index: int) -> String:
	return format(EventDef.title_key(def_id), world, region_index)


static func body(def_id: String, world: World, region_index: int) -> String:
	return format(EventDef.body_key(def_id), world, region_index)


static func option_text(def_id: String, option_id: String) -> String:
	return TechText.tr_key(EventOptionDef.text_key(def_id, option_id))


static func result_text(def_id: String, option_id: String, world: World,
		region_index: int) -> String:
	return format(EventOptionDef.result_key(def_id, option_id), world, region_index)


## The dateline of the wire card: the region, the faction of a counter-move, or
## the world at large (§16.7).
static func dateline(event: OpenEvent, world: World) -> String:
	if event.region > 0:
		return region_name(world, event.region)
	if not event.faction.is_empty():
		return TechText.tr_key(PREFIX_FACTION + event.faction.to_upper())
	return TechText.tr_key(KEY_WIRE_GLOBAL)


## "{days} days, then: {option}" — the default's own words.
static func deadline(event: OpenEvent, def: EventDef, day: int) -> String:
	return TechText.tr_key(KEY_DEADLINE).format({
		PLACEHOLDER_DAYS: event.days_left(day),
		PLACEHOLDER_OPTION: option_text(def.id, def.default_option),
	})


static func deadline_is_near(event: OpenEvent, day: int) -> bool:
	return event.days_left(day) <= DEADLINE_ALERT_DAYS


## The chip an option carries: its price, or *free*.
## `suppression`: the price of suppressing an emergent behaviour, which says it
## will be higher next time (`replayability.md` §3.1).
static func cost_text(cost: float, suppression: bool = false) -> String:
	if cost <= 0.0 and not suppression:
		return TechText.tr_key(KEY_OPTION_FREE)
	return TechText.tr_key(KEY_OPTION_SUPPRESSION if suppression else KEY_OPTION_COST).format(
		{PLACEHOLDER_COST: Format.number(cost, Format.Kind.COMPUTE)})


## §17.4: why an option is locked, with every id turned into a name.
static func lock_text(lock: Dictionary) -> String:
	var reason: String = str(lock.get("reason", ""))
	if reason.is_empty():
		return ""
	var args: Dictionary = {}
	match reason:
		EventOptionDef.LOCK_NODE:
			args["node"] = TechText.node_name(str(lock["node"]))
		EventOptionDef.LOCK_NODE_ANY:
			var names: PackedStringArray = []
			for node_id: Variant in lock["nodes"]:
				names.append(TechText.node_name(str(node_id)))
			args["nodes"] = NODE_JOIN.join(names)
		EventOptionDef.LOCK_ASSET:
			args["count"] = int(lock["count"])
			args["kind"] = TechText.asset_name(str(lock["kind"]), int(lock["count"]))
		EventOptionDef.LOCK_COMPUTE:
			args["value"] = Format.number(float(lock["value"]), Format.Kind.COMPUTE)
		EventOptionDef.LOCK_ABILITY:
			args["ability"] = TechText.tr_key(
				AbilityDef.name_key(str(lock["ability"])))
	return TechText.tr_key(PREFIX_LOCK + reason.to_upper()).format(args)
