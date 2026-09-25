class_name BenchDecision
extends RefCounted
## What one decision of a model did (docs/specs/benchmark.md §4.4): the entry's
## `decisions` row, and the next digest's feedback.

const KEYS: Array[String] = ["day", "stance", "actions", "done", "refused", "invalid", "cached",
	"retried"]

var day: int = 0
## A §7.1 stance id, or "" (none given, or the answer was unreadable).
var stance: String = ""
## Actions read from the answer, after the limit.
var actions: int = 0
## Actions that were applied.
var done: int = 0
## `{"action": <compact form>, "reason": <a Command FAIL_* id or a §7.2 action error>}`.
var refused: Array[Dictionary] = []
## "" or the §7.2 answer error of the final attempt.
var invalid: String = ""
## Every answer of this decision came from the cache.
var cached: bool = false
var retried: bool = false


func to_dict() -> Dictionary:
	var rows: Array[Dictionary] = []
	for row: Dictionary in refused:
		rows.append({"action": str(row.get("action", "")), "reason": str(row.get("reason", ""))})
	return {
		"day": day,
		"stance": stance,
		"actions": actions,
		"done": done,
		"refused": rows,
		"invalid": invalid,
		"cached": cached,
		"retried": retried,
	}


## Null on a missing or ill-typed key — a decision row is data from a file.
static func from_dict(d: Dictionary) -> BenchDecision:
	for key: String in ["day", "actions", "done"]:
		if not _is_whole(d.get(key)):
			return null
	for key: String in ["stance", "invalid"]:
		if typeof(d.get(key)) != TYPE_STRING:
			return null
	for key: String in ["cached", "retried"]:
		if typeof(d.get(key)) != TYPE_BOOL:
			return null
	if typeof(d.get("refused")) != TYPE_ARRAY:
		return null
	var decision: BenchDecision = BenchDecision.new()
	for row: Variant in d["refused"]:
		if typeof(row) != TYPE_DICTIONARY:
			return null
		var entry: Dictionary = row
		if typeof(entry.get("action")) != TYPE_STRING or typeof(entry.get("reason")) != TYPE_STRING:
			return null
		decision.refused.append({"action": str(entry["action"]), "reason": str(entry["reason"])})
	decision.day = int(d["day"])
	decision.stance = str(d["stance"])
	decision.actions = int(d["actions"])
	decision.done = int(d["done"])
	decision.invalid = str(d["invalid"])
	decision.cached = bool(d["cached"])
	decision.retried = bool(d["retried"])
	return decision


static func _is_whole(value: Variant) -> bool:
	var type: int = typeof(value)
	if type == TYPE_INT:
		return true
	return type == TYPE_FLOAT and float(value) == floorf(float(value))
