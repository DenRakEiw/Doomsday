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
## A node granted an ability, or raised its level (§14).
const ABILITY_UNLOCKED: String = "ability_unlocked"
const ABILITY_USED: String = "ability_used"
## A status began — `refreshed` when one of the same id already stood there.
const STATUS_STARTED: String = "status_started"
## A status is over; `cause` is `expired`, `ended` or `cancelled`.
const STATUS_ENDED: String = "status_ended"
## An effect moved a region's penetration or control, outside the tick's growth.
const PENETRATION_CHANGED: String = "penetration_changed"
const CONTROL_CHANGED: String = "control_changed"
## A shutdown took a share of a region's penetration away.
const REGION_WIPED: String = "region_wiped"
## An effect moved a containment track.
const CONTAINMENT_ADDED: String = "containment_added"
## A timed Footprint began or ended.
const PULSE_STARTED: String = "pulse_started"
const PULSE_ENDED: String = "pulse_ended"
## A flag was set (`until_day` −1 for a permanent one) or ran out.
const FLAG_SET: String = "flag_set"
const FLAG_EXPIRED: String = "flag_expired"
## A map event came onto the map (§14).
const EVENT_OPENED: String = "event_opened"
## The player answered one.
const EVENT_ANSWERED: String = "event_answered"
## Its deadline answered it with the default.
const EVENT_EXPIRED: String = "event_expired"
## A pending event could not open: its region went dark, or nowhere was eligible.
const EVENT_DROPPED: String = "event_dropped"
## The faction closest to switching the agent off changed (opposition.md §5.6);
## `from` is "" on the first tick after discovery.
const THREAT_LEADER_CHANGED: String = "threat_leader_changed"
## `funding_reset` ran: every faction stands down until `until_day` (§6.5).
const FUNDING_RESET: String = "funding_reset"
## A faction's preparation was cancelled before it fired.
const COUNTER_MOVE_CANCELLED: String = "counter_move_cancelled"
## A faction began preparing a move, which fires on `fire_day` (opposition.md
## §6.2).
const COUNTER_MOVE_PREPARED: String = "counter_move_prepared"
## A prepared move found nowhere to land and was called off (§6.1).
const COUNTER_MOVE_DROPPED: String = "counter_move_dropped"
## A region's Societal Function changed stage, either way (§8.2).
const SOCIETY_STAGE_CHANGED: String = "society_stage_changed"
## The Response Task Force (`taskforce-endings.md` §1): it formed; its funding
## rose; it chose a target; it moved a hop; it set up an action; it acted; it found
## nothing; it was sent somewhere else.
const TASK_FORCE_APPEARED: String = "task_force_appeared"
const TASK_FORCE_LEVEL: String = "task_force_level"
const TASK_FORCE_TARGETED: String = "task_force_targeted"
const TASK_FORCE_MOVED: String = "task_force_moved"
const TASK_FORCE_SETUP: String = "task_force_setup"
const TASK_FORCE_ACTED: String = "task_force_acted"
const TASK_FORCE_FIZZLED: String = "task_force_fizzled"
const TASK_FORCE_MISDIRECTED: String = "task_force_misdirected"
## What the world says about the rest of them (ticker.md §3.7). Emitted by
## `HeadlineSystem` after the systems, never a trigger for another headline.
const HEADLINE: String = "headline"

## Everything a headline may be triggered by — the catalogue above without
## `HEADLINE` itself (ticker.md §5).
const TYPES_ALL: Array[String] = [ORIGIN_CHOSEN, NODE_PURCHASED, ANOMALY_COLLECTED, REGION_SEEDED,
	REGION_CONTROLLED, ANOMALY_SPAWNED, ANOMALY_EXPIRED, MILESTONE_REACHED, REGION_DEPOPULATED,
	DISCOVERED, CONTAINMENT_THRESHOLD, PHASE_CHANGED, OUTCOME_REACHED, CONTAINMENT_ROLLED_BACK,
	COMPUTE_GRANTED, HARM_BURST, DORMANCY_CHANGED, ASSET_DEPLOYED, ASSET_LOST,
	ABILITY_UNLOCKED, ABILITY_USED, STATUS_STARTED, STATUS_ENDED, PENETRATION_CHANGED,
	CONTROL_CHANGED, REGION_WIPED, CONTAINMENT_ADDED, PULSE_STARTED, PULSE_ENDED,
	FLAG_SET, FLAG_EXPIRED, EVENT_OPENED, EVENT_ANSWERED, EVENT_EXPIRED, EVENT_DROPPED,
	THREAT_LEADER_CHANGED, FUNDING_RESET, COUNTER_MOVE_CANCELLED, COUNTER_MOVE_PREPARED,
	COUNTER_MOVE_DROPPED, SOCIETY_STAGE_CHANGED, TASK_FORCE_APPEARED, TASK_FORCE_LEVEL,
	TASK_FORCE_TARGETED, TASK_FORCE_MOVED, TASK_FORCE_SETUP, TASK_FORCE_ACTED,
	TASK_FORCE_FIZZLED, TASK_FORCE_MISDIRECTED]

## Fields of a `HEADLINE` event that are not arguments of its text.
const FIELD_HEADLINE: String = "headline"
const FIELD_STREAM: String = "stream"

## Causes of `DISCOVERED`.
const CAUSE_SCRUTINY: String = "scrutiny"
const CAUSE_DEATHS: String = "deaths"
## The `cause` of an `ASSET_LOST` that the region itself caused: it went dark and
## everything standing in it went with it.
const CAUSE_DARK: String = "dark"
## The `cause` of an `EVENT_DROPPED` whose def found no eligible region.
const CAUSE_NO_SITE: String = "no_site"

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
