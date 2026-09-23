class_name OpenEvent
extends RefCounted
## A map event standing on the map, waiting for an answer
## (`loop-mechanics.md` §3.3).
##
## Opened by `EventSystem.open`, closed by an answer or by its deadline, which
## chooses the definition's default for the player.

## `World.next_event_id` at opening; commands name it.
var id: int = 0
## The `EventDef` id.
var def: String = ""
## 0 = global.
var region: int = 0
## "" unless a counter-move.
var faction: String = ""
var opened_day: int = 0
## The tick whose day reaches it chooses the default.
var deadline_day: int = 0
## The counter-move's status level (S4.5); 1 otherwise.
var level: int = 1


## How many days are left on `day`; never negative.
func days_left(day: int) -> int:
	return maxi(0, deadline_day - day)


## How many days it was given.
func days_total() -> int:
	return deadline_day - opened_day


## The save's row (§3.6). `region_id` is written by the caller, which knows the
## world.
func to_dict(region_id: String) -> Dictionary:
	return {
		"id": id,
		"def": def,
		"region": region_id,
		"faction": faction,
		"opened_day": opened_day,
		"deadline_day": deadline_day,
		"level": level,
	}
