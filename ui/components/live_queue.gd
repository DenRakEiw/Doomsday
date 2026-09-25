class_name LiveQueue
extends RefCounted
## The pace of one spoken channel (spec accessibility.md §3.4): at most one text
## per `min_gap_ms`, and a text pushed during the gap replaces any text still
## waiting — the newest wins, the older ones are dropped without a word.
##
## Pure: the owner passes its clock in and calls `pop_due` from `_process`, so a
## test steps time by hand.

var _min_gap_ms: int = 0
var _waiting: String = ""
## When the last text was handed out; below zero, never.
var _last_ms: int = -1


func _init(min_gap_ms: int) -> void:
	_min_gap_ms = maxi(min_gap_ms, 0)


## Keeps only the newest waiting text.
func push(text: String, _now_ms: int) -> void:
	if text.is_empty():
		return
	_waiting = text


## The text to speak now, or "" when nothing is due.
func pop_due(now_ms: int) -> String:
	if _waiting.is_empty():
		return ""
	if _last_ms >= 0 and now_ms - _last_ms < _min_gap_ms:
		return ""
	var text: String = _waiting
	_waiting = ""
	_last_ms = now_ms
	return text


## Whether a text waits for its turn.
func has_waiting() -> bool:
	return not _waiting.is_empty()
