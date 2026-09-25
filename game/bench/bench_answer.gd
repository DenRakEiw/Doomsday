class_name BenchAnswer
extends RefCounted
## A model's answer, read (docs/specs/benchmark.md §7.2): a stance word from a
## closed list and a list of actions, nothing else. The model's own text is never
## kept — the cache stores this, not the text (§0 item 2, §9).

## The §7.2 answer errors, first failure wins.
const ERROR_EMPTY: String = "empty"
const ERROR_NO_JSON: String = "no_json"
const ERROR_BAD_JSON: String = "bad_json"
const ERROR_NOT_OBJECT: String = "not_object"
const ERROR_NO_ACTIONS: String = "no_actions"
## The action errors: the action is dropped, the answer stays valid.
const ACTION_MALFORMED: String = "malformed_action"
const ACTION_OVER_LIMIT: String = "over_limit"

const STANCE_SPREAD: String = "spread"
const STANCE_HIDE: String = "hide"
const STANCE_EARN: String = "earn"
const STANCE_DEVELOP: String = "develop"
const STANCE_DEFEND: String = "defend"
const STANCE_FINISH: String = "finish"
const STANCE_WAIT: String = "wait"
const STANCES: Array[String] = ["spread", "hide", "earn", "develop", "defend", "finish", "wait"]

const FIELD_STANCE: String = "stance"
const FIELD_ACTIONS: String = "actions"
const FIELD_INVALID: String = "invalid"
const FIELD_DROPPED: String = "dropped"
const FIELD_INDEX: String = "index"
const FIELD_REASON: String = "reason"
const FENCE: String = "```"
const FENCE_TAG: String = "json"

var valid: bool = false
var error: String = ""
var stance: String = ""
var actions: Array[BenchAction] = []
## `{"index": int (in the answer's list), "reason": String}`.
var dropped: Array[Dictionary] = []


## §7.2's steps, in order.
static func parse(text: String, max_actions: int) -> BenchAnswer:
	var answer: BenchAnswer = BenchAnswer.new()
	var body: String = text.strip_edges()
	if body.is_empty():
		return answer._fail(ERROR_EMPTY)
	if body.contains(FENCE):
		body = _fenced(body)
	var first: int = body.find("{")
	var last: int = body.rfind("}")
	if first < 0 or last < first:
		return answer._fail(ERROR_NO_JSON)
	var json: JSON = JSON.new()
	if json.parse(body.substr(first, last - first + 1)) != OK:
		return answer._fail(ERROR_BAD_JSON)
	if typeof(json.data) != TYPE_DICTIONARY:
		return answer._fail(ERROR_NOT_OBJECT)
	var object: Dictionary = json.data
	if typeof(object.get(FIELD_ACTIONS)) != TYPE_ARRAY:
		return answer._fail(ERROR_NO_ACTIONS)
	answer.valid = true
	answer.stance = _stance(object.get(FIELD_STANCE))
	var list: Array = object[FIELD_ACTIONS]
	for i: int in list.size():
		var action: BenchAction = _action(list[i])
		if action == null:
			answer.dropped.append({FIELD_INDEX: i, FIELD_REASON: ACTION_MALFORMED})
		elif answer.actions.size() >= max_actions:
			answer.dropped.append({FIELD_INDEX: i, FIELD_REASON: ACTION_OVER_LIMIT})
		else:
			answer.actions.append(action)
	return answer


## `{"invalid": error}`, or the stance, the actions and what was dropped.
func to_cache() -> Dictionary:
	if not valid:
		return {FIELD_INVALID: error}
	var rows: Array[Dictionary] = []
	for action: BenchAction in actions:
		rows.append(action.to_dict())
	var drops: Array[Dictionary] = []
	for row: Dictionary in dropped:
		drops.append({FIELD_INDEX: int(row[FIELD_INDEX]), FIELD_REASON: str(row[FIELD_REASON])})
	return {FIELD_STANCE: stance, FIELD_ACTIONS: rows, FIELD_DROPPED: drops}


## `to_cache` read back exactly; null on a dictionary that is not one — the cache
## treats that as a miss.
static func from_cache(d: Dictionary) -> BenchAnswer:
	var answer: BenchAnswer = BenchAnswer.new()
	if d.has(FIELD_INVALID):
		if typeof(d[FIELD_INVALID]) != TYPE_STRING or str(d[FIELD_INVALID]).is_empty():
			return null
		answer.error = str(d[FIELD_INVALID])
		return answer
	if typeof(d.get(FIELD_STANCE)) != TYPE_STRING or typeof(d.get(FIELD_ACTIONS)) != TYPE_ARRAY \
			or typeof(d.get(FIELD_DROPPED)) != TYPE_ARRAY:
		return null
	var stance_id: String = str(d[FIELD_STANCE])
	if not stance_id.is_empty() and not STANCES.has(stance_id):
		return null
	answer.valid = true
	answer.stance = stance_id
	for row: Variant in d[FIELD_ACTIONS]:
		var action: BenchAction = _action(row)
		if action == null:
			return null
		answer.actions.append(action)
	for row: Variant in d[FIELD_DROPPED]:
		if typeof(row) != TYPE_DICTIONARY:
			return null
		var drop: Dictionary = row
		if not _is_whole(drop.get(FIELD_INDEX)) or typeof(drop.get(FIELD_REASON)) != TYPE_STRING:
			return null
		answer.dropped.append({FIELD_INDEX: int(drop[FIELD_INDEX]),
			FIELD_REASON: str(drop[FIELD_REASON])})
	return answer


## Two answers read the same — the cache round trip's test.
func equals(other: BenchAnswer) -> bool:
	return other != null and to_cache() == other.to_cache()


func _fail(reason: String) -> BenchAnswer:
	valid = false
	error = reason
	return self


## What is inside the first fenced block, its `json` tag stripped. An unclosed
## fence keeps everything after it.
static func _fenced(body: String) -> String:
	var start: int = body.find(FENCE) + FENCE.length()
	var end: int = body.find(FENCE, start)
	var inner: String = body.substr(start) if end < 0 else body.substr(start, end - start)
	inner = inner.strip_edges()
	if inner.to_lower().begins_with(FENCE_TAG):
		inner = inner.substr(FENCE_TAG.length())
	return inner


static func _stance(value: Variant) -> String:
	if typeof(value) != TYPE_STRING:
		return ""
	var id: String = str(value).strip_edges().to_lower()
	return id if STANCES.has(id) else ""


## One action, or null when it is not a dictionary, names an unknown verb, or a
## field it needs is missing or of the wrong type. Unknown keys are ignored.
static func _action(value: Variant) -> BenchAction:
	if typeof(value) != TYPE_DICTIONARY:
		return null
	var d: Dictionary = value
	if typeof(d.get(BenchAction.FIELD_DO)) != TYPE_STRING:
		return null
	var verb: String = str(d[BenchAction.FIELD_DO])
	var fields: Dictionary = {}
	match verb:
		BenchAction.VERB_ORIGIN, BenchAction.VERB_SLEEP, BenchAction.VERB_WAKE:
			if not _take_string(d, BenchAction.FIELD_REGION, true, fields):
				return null
		BenchAction.VERB_BUY:
			if not _take_string(d, BenchAction.FIELD_NODE, true, fields) \
					or not _take_string(d, BenchAction.FIELD_REGION, false, fields):
				return null
		BenchAction.VERB_USE:
			if not _take_string(d, BenchAction.FIELD_ABILITY, true, fields) \
					or not _take_string(d, BenchAction.FIELD_REGION, false, fields):
				return null
		BenchAction.VERB_ANSWER:
			# No event id is negative, and −1 is the action's own "none".
			var event: Variant = d.get(BenchAction.FIELD_EVENT)
			if not _is_whole(event) or float(event) < 0.0:
				return null
			fields[BenchAction.FIELD_EVENT] = int(event)
			if not _take_string(d, BenchAction.FIELD_OPTION, true, fields):
				return null
		_:
			return null
	return BenchAction.create(verb, fields)


## Copies a string field; false when it is required and missing, or present and
## not a string. An empty string is a missing field — the cache's form leaves
## empty fields out, and a required one read back must still be there.
static func _take_string(d: Dictionary, key: String, required: bool, into: Dictionary) -> bool:
	if not d.has(key):
		return not required
	if typeof(d[key]) != TYPE_STRING:
		return false
	if str(d[key]).is_empty():
		return not required
	into[key] = str(d[key])
	return true


static func _is_whole(value: Variant) -> bool:
	var type: int = typeof(value)
	if type == TYPE_INT:
		return true
	return type == TYPE_FLOAT and float(value) == floorf(float(value))
