class_name TaskForce
extends RefCounted
## The Response Task Force (PLAN §3.10, `taskforce-endings.md` §1): one team, on the
## map, from the day a containment track reaches half. Pure state;
## `TaskForceSystem` moves it and never draws a random number to do so.

const STATE_ABSENT: String = "absent"
const STATE_TRAVEL: String = "travel"
const STATE_SETUP: String = "setup"
const STATE_REST: String = "rest"
const STATES: Array[String] = ["absent", "travel", "setup", "rest"]

var state: String = STATE_ABSENT
## Where it stands; 0 while absent.
var region: int = 0
## Where it is going or setting up; 0 = none.
var target: int = 0
## The action being set up (§3), "" otherwise.
var action: String = ""
## Days of work done on the current hop, setup or rest (`task_force_pace` a day).
var progress: float = 0.0
## 1…3 once present; never falls.
var level: int = 0
var actions_done: int = 0
var fizzled: int = 0
var appeared_day: int = -1
## Misdirected (§4): it goes to its false target whatever is there, and finds out
## on arrival.
var misled: bool = false
## D5.5 (§14): region index → the first day it is no longer marked. While a
## region is marked, dormancy does not hide it from the team.
var marked: Dictionary[int, int] = {}


func is_present() -> bool:
	return state != STATE_ABSENT


## Whether a `dormant` fizzle there is still remembered on `day`.
func is_marked(index: int, day: int) -> bool:
	return marked.has(index) and day < marked[index]


## The save's block (§1): region ids, not indices, like every other row.
func to_dict(region_id: Callable) -> Dictionary:
	return {
		"state": state,
		"region": str(region_id.call(region)),
		"target": str(region_id.call(target)),
		"action": action,
		"progress": FloatBits.to_hex(progress),
		"level": level,
		"actions_done": actions_done,
		"fizzled": fizzled,
		"appeared_day": appeared_day,
		"misled": misled,
		"marked": _marked_to_dict(region_id),
	}


## Null for anything that is not a block this build wrote.
static func from_dict(d: Dictionary, db: ContentDB) -> TaskForce:
	var team: TaskForce = TaskForce.new()
	if not STATES.has(str(d.get("state", ""))):
		return null
	for key: String in ["level", "actions_done", "fizzled", "appeared_day"]:
		if typeof(d.get(key)) != TYPE_INT and typeof(d.get(key)) != TYPE_FLOAT:
			return null
	team.state = str(d["state"])
	team.action = str(d.get("action", ""))
	team.progress = FloatBits.from_variant(d.get("progress", FloatBits.to_hex(0.0)))
	team.level = int(d["level"])
	team.actions_done = int(d["actions_done"])
	team.fizzled = int(d["fizzled"])
	team.appeared_day = int(d["appeared_day"])
	team.misled = typeof(d.get("misled")) == TYPE_BOOL and bool(d["misled"])
	for key: String in ["region", "target"]:
		var id: String = str(d.get(key, ""))
		var index: int = 0
		if not id.is_empty():
			if not db.region_index_by_id.has(id):
				return null
			index = db.region_index_by_id[id]
		team.set(key, index)
	# §14.3: a v3 save written before D5.5 has no marks.
	var marks: Variant = d.get("marked", {})
	if typeof(marks) != TYPE_DICTIONARY:
		return null
	for id: Variant in marks:
		var until: Variant = (marks as Dictionary)[id]
		if not db.region_index_by_id.has(str(id)) \
				or (typeof(until) != TYPE_INT and typeof(until) != TYPE_FLOAT):
			return null
		team.marked[int(db.region_index_by_id[str(id)])] = int(until)
	return team


## Region id → until day, in region order so the save and the hash do not depend
## on the order the marks were made in.
func _marked_to_dict(region_id: Callable) -> Dictionary:
	var out: Dictionary = {}
	var indices: Array[int] = []
	indices.assign(marked.keys())
	indices.sort()
	for index: int in indices:
		out[str(region_id.call(index))] = marked[index]
	return out
