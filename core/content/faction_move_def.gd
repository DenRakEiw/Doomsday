class_name FactionMoveDef
extends RefCounted
## One counter-move a faction may prepare, and when (`opposition.md` §4.1). The
## schedule that reads it is S4.5's.

## The value of a trigger that is not given.
const NOT_GIVEN: float = -1.0
## The keys a move and its trigger and variants blocks allow.
const KEYS: Array[String] = ["event", "trigger", "variants"]
const TRIGGER_KEYS: Array[String] = ["containment", "risk"]
const VARIANTS_KEYS: Array[String] = ["select", "events"]
## The selectors `variants.select` may name (`CounterMoveRules.SELECTORS`, S4.5).
const SELECTOR_SEEDS_BY_KIND_MAX: String = "seeds_by_kind_max"
const SELECTORS: Array[String] = ["seeds_by_kind_max"]

## A counter-move event of this faction.
var event: String
## In (0, 1), or `NOT_GIVEN`.
var trigger_containment: float = NOT_GIVEN
## The daily discovery risk, in (0, 1], before discovery only; or `NOT_GIVEN`.
var trigger_risk: float = NOT_GIVEN
## "" or one of `SELECTORS`.
var variants_select: String = ""
## Selector key → event id; a key absent falls back to `event`.
var variants: Dictionary[String, String] = {}


## Whether `event_id` is this move, its variants included.
func names_event(event_id: String) -> bool:
	return event == event_id or variants.values().has(event_id)


## Every event id this move may open: `event`, then the variants in key order.
func event_ids() -> Array[String]:
	var ids: Array[String] = [event]
	var keys: Array = variants.keys()
	keys.sort()
	for key: Variant in keys:
		var id: String = variants[key]
		if not ids.has(id):
			ids.append(id)
	return ids
