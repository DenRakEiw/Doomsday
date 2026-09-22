class_name EventText
extends RefCounted
## A `SimEvent` as the one line the ticker shows (spec ui-foundation.md §8.4).
##
## `core/` speaks in ids — a region id, a phase id, an outcome id — and the
## interface speaks in the player's language. This is the whole of the
## translation between the two in M2, and the only place that knows which event
## types are worth narrating: an unlisted type produces nothing rather than a
## placeholder nobody wrote.
##
## Static and free of nodes, so the mapping is tested as a table rather than
## through a running game. §8.4 gives the job to `Game`; an autoload that owns
## interface strings would be the wrong home for it, and `Game` drains the
## outbox onto `EventBus` either way — the ticker reads it there.
##
## S3.5 replaces this with the headline system of D3.4.

## Event type → the `UI_EVENT_*` key that narrates it.
const KEYS: Dictionary[String, String] = {
	SimEvent.ORIGIN_CHOSEN: "UI_EVENT_ORIGIN_CHOSEN",
	SimEvent.REGION_SEEDED: "UI_EVENT_REGION_SEEDED",
	SimEvent.REGION_CONTROLLED: "UI_EVENT_REGION_CONTROLLED",
	SimEvent.ANOMALY_SPAWNED: "UI_EVENT_ANOMALY_SPAWNED",
	SimEvent.ANOMALY_EXPIRED: "UI_EVENT_ANOMALY_EXPIRED",
	SimEvent.ANOMALY_COLLECTED: "UI_EVENT_ANOMALY_COLLECTED",
	SimEvent.MILESTONE_REACHED: "UI_EVENT_MILESTONE",
	SimEvent.NODE_PURCHASED: "UI_EVENT_NODE_PURCHASED",
	SimEvent.REGION_DEPOPULATED: "UI_EVENT_DEPOPULATED",
	SimEvent.DISCOVERED: "UI_EVENT_DISCOVERED",
	SimEvent.CONTAINMENT_THRESHOLD: "UI_EVENT_CONTAINMENT_THRESHOLD",
	SimEvent.PHASE_CHANGED: "UI_EVENT_PHASE_CHANGED",
	SimEvent.OUTCOME_REACHED: "UI_EVENT_OUTCOME",
}

## The key prefixes D1.2 and §8.2 gave the content's own ids.
const PREFIX_REGION: String = "REGION_"
const PREFIX_PHASE: String = "UI_PHASE_"
const PREFIX_OUTCOME: String = "UI_OUTCOME_"

## Payload fields of core.md §6.4, and the placeholders §8.2 spells them into.
const FIELD_REGION: String = "region"
const FIELD_VALUE: String = "value"
const FIELD_REWARD: String = "reward"
const FIELD_NODE: String = "node"
const FIELD_THRESHOLD: String = "threshold"
const FIELD_PHASE_TO: String = "to"
const FIELD_OUTCOME: String = "outcome"
const PLACEHOLDER_PERCENT: String = "percent"
const PLACEHOLDER_PHASE: String = "phase"


## The line for an event, or `""` for a type the ticker stays silent about.
static func for_event(event: SimEvent) -> String:
	if event == null or not KEYS.has(event.type):
		return ""
	return translate(KEYS[event.type]).format(_arguments(event))


## `tr` belongs to `Object`; a static function asks the server itself. Also the
## one place that turns an id into a key, so a content id never reaches a label.
static func translate(key: String) -> String:
	return String(TranslationServer.translate(key))


## The name of a region id, e.g. `usa` → `REGION_USA`.
static func region_name(region_id: String) -> String:
	return translate(PREFIX_REGION + region_id.to_upper())


static func _arguments(event: SimEvent) -> Dictionary:
	var data: Dictionary = event.data
	var args: Dictionary = {}
	if data.has(FIELD_REGION):
		args[FIELD_REGION] = region_name(str(data[FIELD_REGION]))
	if data.has(FIELD_VALUE):
		args[FIELD_VALUE] = Format.number(float(data[FIELD_VALUE]), Format.Kind.COMPUTE)
	if data.has(FIELD_REWARD):
		args[FIELD_REWARD] = Format.number(float(data[FIELD_REWARD]), Format.Kind.COMPUTE)
	if data.has(FIELD_NODE):
		# M2's placeholder technology has no names; D3.1 gives it `TECH_*_NAME`.
		args[FIELD_NODE] = str(data[FIELD_NODE])
	if data.has(FIELD_THRESHOLD):
		args[PLACEHOLDER_PERCENT] = Format.percent(float(data[FIELD_THRESHOLD]))
	if event.type == SimEvent.PHASE_CHANGED and data.has(FIELD_PHASE_TO):
		args[PLACEHOLDER_PHASE] = translate(PREFIX_PHASE + str(data[FIELD_PHASE_TO]).to_upper())
	if data.has(FIELD_OUTCOME):
		args[FIELD_OUTCOME] = translate(PREFIX_OUTCOME + str(data[FIELD_OUTCOME]).to_upper())
	return args
