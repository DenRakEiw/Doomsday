class_name EventDef
extends RefCounted
## One map event: a marker with options and a deadline (`loop-mechanics.md`
## §10.1).
##
## Three kinds share one format. An **opening** is something the world leaves
## lying around, rolled by `EventSystem` each day. A **counter-move** is a
## faction's move, opened by the schedule of S4.5, and applies its `status`
## unless the answer prevents it. A **chain** step belongs to a story: the step
## marked `start` is rolled like an opening, every other one is reached only
## through an option's `next`.
##
## Where it lands is `pick`: an eligibility rule, `"same"` (the region of the
## step that scheduled it), a named target rule (counter-moves, S4.5), or nothing
## at all, which makes it global.

const KIND_OPENING: String = "opening"
const KIND_COUNTER_MOVE: String = "counter_move"
const KIND_CHAIN: String = "chain"
## `replayability.md` §3: an unplanned behaviour of the agent's own, rolled on its
## own beat and answered keep or suppress.
const KIND_EMERGENT: String = "emergent"
const KINDS: Array[String] = ["opening", "counter_move", "chain", "emergent"]

## `pick: "same"` — the region of the step that scheduled this one.
const PICK_SAME: String = "same"
## The key of a named target rule: `pick: {"rule": id}`.
const PICK_RULE_KEY: String = "rule"
## The target rules of opposition.md §6.4 — the names from S4.3 on, the
## functions (`CounterMoveRules`) in S4.5.
const PICK_RULES: Array[String] = ["lockdown_target", "richest_infected", "audit_target",
	"purge_target", "exposure_target", "protest_target"]

const PICK_WEIGHT_UNIFORM: String = "uniform"
const PICK_WEIGHT_HARDWARE_PENETRATION: String = "hardware_penetration"
const PICK_WEIGHTS: Array[String] = ["uniform", "hardware_penetration"]

## The keys an event allows.
const KEYS: Array[String] = ["id", "kind", "chain", "start", "pick", "pick_weight", "when",
	"weight", "max_fires", "cooldown_days", "deadline_days", "default", "modal",
	"illustration", "status", "faction", "flags", "options"]
## The root list of an `events/*.json` file.
const ROOT_KEY: String = "events"
const OPTIONS_MIN: int = 2
const OPTIONS_MAX: int = 4

var id: String
var kind: String = KIND_OPENING
## KIND_CHAIN: the chain every step of it shares; "" otherwise.
var chain: String = ""
## KIND_CHAIN: this step is entered from the world, rolled like an opening.
var start: bool = false
## Where it lands; null when `pick_same`, `pick_rule` or global.
var pick: Eligibility = null
var pick_same: bool = false
## A named target rule (S4.5).
var pick_rule: String = ""
var pick_weight: String = PICK_WEIGHT_UNIFORM
## ticker.md §3.3 B plus loop-mechanics §10.3, evaluated at the draw. Values are
## cast as the headline loader casts them: lists of strings, bools, floats.
var when: Dictionary[String, Variant] = {}
var weight: float = 1.0
## 0 = unlimited.
var max_fires: int = 0
var cooldown_days: int = 0
var deadline_days: int = 1
var default_option: String = ""
## Opens the wire card even with a region.
var modal: bool = false
## "" or an id; M6 supplies the file.
var illustration: String = ""
## KIND_COUNTER_MOVE: the status it applies, and who fires it.
var status: String = ""
var faction: String = ""
## Story flags set when the event opens.
var flags: Array[String] = []
var options: Array[EventOptionDef] = []


## Whether it lands on nothing — no pick of any kind.
func is_global() -> bool:
	return pick == null and not pick_same and pick_rule.is_empty()


## Rolled by the daily opening draw (§10.4 step 3): an opening, or a chain's first
## step.
func is_rolled() -> bool:
	return kind == KIND_OPENING or (kind == KIND_CHAIN and start)


## The option with this id, or null.
func option(option_id: String) -> EventOptionDef:
	for candidate: EventOptionDef in options:
		if candidate.id == option_id:
			return candidate
	return null


## Why `option_id` cannot be chosen on `event`, or empty when it can (§10.2). An
## unknown option has no lock; the command reports it as unknown.
func lock_reason(sim: Simulation, event: OpenEvent, option_id: String) -> Dictionary:
	var chosen: EventOptionDef = option(option_id)
	if chosen == null:
		return {}
	return chosen.lock_reason(sim, event.region)


static func title_key(event_id: String) -> String:
	return "EVENT_%s_TITLE" % event_id.to_upper()


static func body_key(event_id: String) -> String:
	return "EVENT_%s_BODY" % event_id.to_upper()


## plain-language.md §5.2 C6: the optional plain sentence an opening or a chain
## card shows as its explanation, above the options and the wire copy.
static func summary_key(event_id: String) -> String:
	return "EVENT_%s_SUMMARY" % event_id.to_upper()


## `UI_EVENT_KIND_OPENING` and so on — the card's dateline.
static func kind_key(event_kind: String) -> String:
	return "UI_EVENT_KIND_%s" % event_kind.to_upper()
