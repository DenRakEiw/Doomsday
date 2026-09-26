class_name BenchChoiceRead
extends RefCounted
## A decision model's reply, read against its plan (docs/specs/benchmark.md
## §17.5): one ranking per answered question, the service's confidence and model
## version, and what could not be read.

## Question id → its option keys, most likely first, ties in plan order.
var rankings: Dictionary[String, Array] = {}
## Question id → the service's confidence, 0–1.
var confidence: Dictionary[String, float] = {}
var model_version: String = ""
## `{"reason": <§17.5 problem id>, "question": <question id>}`, in plan order.
var problems: Array[Dictionary] = []
## "" or `bad_reply`: the whole reply is unreadable.
var error: String = ""


## The first key of a question's ranking; "" when it is unanswered.
func pick(question: String) -> String:
	var ranking: Array = rankings.get(question, [])
	return "" if ranking.is_empty() else str(ranking[0])


func answered(question: String) -> bool:
	return rankings.has(question)
