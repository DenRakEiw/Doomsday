class_name HeadlineText
extends RefCounted
## A `headline` event as the line the ticker shows (spec ticker.md §4.2).
##
## `core/` speaks in ids and raw numbers; the player reads names and formatted
## values. The conversion is a function of the **placeholder name** alone, so a
## new headline needs no code: whatever a line calls `{region}` is a region, and
## whatever it calls `{deaths}` is a count of people.
##
## Static and node-free, so the table is tested without a running game.

const KEY_PREFIX: String = HeadlineDef.KEY_PREFIX
const PREFIX_REGION: String = "REGION_"
const PREFIX_CONTINENT: String = "CONTINENT_"
const PREFIX_TECH: String = "TECH_"
const SUFFIX_TECH_NAME: String = "_NAME"

## Argument names that name a region, a continent or a node.
const REGION_ARGS: Array[String] = ["region", "from"]
const CONTINENT_ARGS: Array[String] = ["continent"]
const NODE_ARGS: Array[String] = ["node"]
## Argument names that are numbers, by the way they are written.
const COMPUTE_ARGS: Array[String] = ["value", "reward", "cost", "compute"]
const COMPACT_ARGS: Array[String] = ["deaths"]
const PERCENT_ARGS: Array[String] = ["share", "containment", "threshold"]
const WHOLE_ARGS: Array[String] = ["day", "regions", "dark", "count", "expires_day", "anomaly"]


## The item for a `headline` event, or null for anything else — the strip shows
## headlines and nothing else now.
static func item_for(event: SimEvent) -> TickerItem:
	if event == null or event.type != SimEvent.HEADLINE:
		return null
	var args: Dictionary = event.data.duplicate()
	args.erase(SimEvent.FIELD_HEADLINE)
	args.erase(SimEvent.FIELD_STREAM)
	return TickerItem.make(key_for(str(event.data.get(SimEvent.FIELD_HEADLINE, ""))), args)


static func key_for(headline_id: String) -> String:
	return KEY_PREFIX + headline_id.to_upper()


## The line in the player's language. A key with no row renders as the key,
## which is what makes a missing string visible instead of silent.
static func render(key: String, args: Dictionary) -> String:
	return translate(key).format(_converted(args))


## `tr` belongs to `Object`; a static function asks the server itself.
static func translate(key: String) -> String:
	return String(TranslationServer.translate(key))


## Every argument is converted, not only the ones this line spells out —
## `String.format` ignores the extras and the table stays a function of the name.
static func _converted(args: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in args:
		var name: String = str(key)
		out[name] = _convert(name, args[key])
	return out


static func _convert(name: String, value: Variant) -> String:
	if REGION_ARGS.has(name):
		return translate(PREFIX_REGION + str(value).to_upper())
	if CONTINENT_ARGS.has(name):
		return translate(PREFIX_CONTINENT + str(value).to_upper())
	if NODE_ARGS.has(name):
		return translate(PREFIX_TECH + str(value).to_upper() + SUFFIX_TECH_NAME)
	if COMPUTE_ARGS.has(name):
		return Format.number(float(value), Format.Kind.COMPUTE)
	if COMPACT_ARGS.has(name):
		return Format.number(float(value), Format.Kind.COMPACT)
	if PERCENT_ARGS.has(name):
		return Format.percent(float(value))
	if WHOLE_ARGS.has(name):
		return str(int(value))
	return str(value)
