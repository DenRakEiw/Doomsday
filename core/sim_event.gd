class_name SimEvent
extends RefCounted
## Something the simulation reports, in the outbox of a tick or in the result of
## a command. `core/` has no signals: the `Game` autoload (S2.1) drains both and
## re-emits them on `EventBus`.
##
## This class owns the event vocabulary (core.md §6.4). `data` holds plain values
## only — String, int, float, bool — and names regions by **id**, never by index.

const ORIGIN_CHOSEN: String = "origin_chosen"
const NODE_PURCHASED: String = "node_purchased"
const ANOMALY_COLLECTED: String = "anomaly_collected"
const REGION_SEEDED: String = "region_seeded"
const REGION_CONTROLLED: String = "region_controlled"
const ANOMALY_SPAWNED: String = "anomaly_spawned"
const ANOMALY_EXPIRED: String = "anomaly_expired"
const MILESTONE_REACHED: String = "milestone_reached"
const REGION_DEPOPULATED: String = "region_depopulated"
const DISCOVERED: String = "discovered"
const CONTAINMENT_THRESHOLD: String = "containment_threshold"
const PHASE_CHANGED: String = "phase_changed"
const OUTCOME_REACHED: String = "outcome_reached"
const CONTAINMENT_ROLLED_BACK: String = "containment_rolled_back"
const COMPUTE_GRANTED: String = "compute_granted"
const HARM_BURST: String = "harm_burst"
const DORMANCY_CHANGED: String = "dormancy_changed"
## An asset came to stand somewhere (a purchase, an ability, an event).
const ASSET_DEPLOYED: String = "asset_deployed"
## One went away — destroyed, or lost with the region it stood in.
const ASSET_LOST: String = "asset_lost"
## What the world says about the rest of them (ticker.md §3.7). Emitted by
## `HeadlineSystem` after the systems, never a trigger for another headline.
const HEADLINE: String = "headline"

## Everything a headline may be triggered by — the catalogue above without
## `HEADLINE` itself (ticker.md §5).
const TYPES_ALL: Array[String] = [ORIGIN_CHOSEN, NODE_PURCHASED, ANOMALY_COLLECTED, REGION_SEEDED,
	REGION_CONTROLLED, ANOMALY_SPAWNED, ANOMALY_EXPIRED, MILESTONE_REACHED, REGION_DEPOPULATED,
	DISCOVERED, CONTAINMENT_THRESHOLD, PHASE_CHANGED, OUTCOME_REACHED, CONTAINMENT_ROLLED_BACK,
	COMPUTE_GRANTED, HARM_BURST, DORMANCY_CHANGED, ASSET_DEPLOYED, ASSET_LOST]

## Fields of a `HEADLINE` event that are not arguments of its text.
const FIELD_HEADLINE: String = "headline"
const FIELD_STREAM: String = "stream"

## Causes of `DISCOVERED`.
const CAUSE_SCRUTINY: String = "scrutiny"
const CAUSE_DEATHS: String = "deaths"
## The `cause` of an `ASSET_LOST` that the region itself caused: it went dark and
## everything standing in it went with it.
const CAUSE_DARK: String = "dark"

var type: String
var day: int
var data: Dictionary


func _init(p_type: String, p_day: int, p_data: Dictionary) -> void:
	type = p_type
	day = p_day
	data = p_data


func to_dict() -> Dictionary:
	return {"type": type, "day": day, "data": data}


func _to_string() -> String:
	return "%s day %d %s" % [type, day, data]
