class_name PendingEvent
extends RefCounted
## A map event scheduled but not open yet (`loop-mechanics.md` §3.3): a chain's
## follow-up, a counter-move from the schedule (S4.5), or anything that came due
## while `max_open` events stood.

var def: String = ""
## 0 = the definition picks its region when it opens (or it is global).
var region: int = 0
var faction: String = ""
var due_day: int = 0
var level: int = 1


## The save's row (§3.6).
func to_dict(region_id: String) -> Dictionary:
	return {
		"def": def,
		"region": region_id,
		"faction": faction,
		"due_day": due_day,
		"level": level,
	}
