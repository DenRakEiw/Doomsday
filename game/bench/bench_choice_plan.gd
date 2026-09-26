class_name BenchChoicePlan
extends RefCounted
## One decision as a decision model is asked it (docs/specs/benchmark.md §17.3):
## the request's `state` and `questions`, and what the combiner needs to turn
## the answers back into actions. Built by `BenchChoice.plan`; never changed after.

const FIELD_MODEL: String = "model"
const FIELD_STATE: String = "state"
const FIELD_QUESTIONS: String = "questions"

## `{"rules": String, "situation": String}` (§17.2).
var state: Dictionary = {}
## The wire form, question id → `{"type", "instructions", "criteria"}`, in asking
## order.
var questions: Dictionary = {}
## Question id → its option keys in order — the tie-break order (§17.5).
var keys: Dictionary[String, Array] = {}
## Question id → option key → compute cost, for `event_*`, `use` and `buy`.
var costs: Dictionary = {}
## Deploying nodes offered under `buy` — each has its `site_<node>` question.
var deploying: Array[String] = []
## Region abilities offered under `use` — each has its `target_<ability>` question.
var regional: Array[String] = []


## The request body (§17.1): the model, the state and the questions, nothing else.
func body(model: String) -> Dictionary:
	return {FIELD_MODEL: model, FIELD_STATE: state.duplicate(true),
		FIELD_QUESTIONS: questions.duplicate(true)}


## What the cache keys a choice request by (§17.7).
func basis() -> Dictionary:
	return {FIELD_STATE: state.duplicate(true), FIELD_QUESTIONS: questions.duplicate(true)}


## The option keys of a question; empty for one the plan does not ask.
func keys_of(question: String) -> Array[String]:
	var out: Array[String] = []
	for key: Variant in keys.get(question, []):
		out.append(str(key))
	return out


## An option's compute cost; 0 for a free one or one without a cost.
func cost_of(question: String, key: String) -> float:
	var table: Dictionary = costs.get(question, {})
	return float(table.get(key, 0.0))
