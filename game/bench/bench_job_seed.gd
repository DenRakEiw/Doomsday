class_name BenchJobSeed
extends RefCounted
## One seed of the player's running benchmark (docs/specs/benchmark.md §19.5,
## §19.9.1): waiting, playing (its day and calls so far) or finished (outcome and
## score) — what one line of the progress section shows.

var seed_value: int = 0
var started: bool = false
var finished: bool = false
var day: int = 0
var calls: int = 0
var cost_usd: float = 0.0
## `BenchEntry.outcome` once finished ("" before).
var outcome: String = ""
var score: float = 0.0


func _init(p_seed: int = 0) -> void:
	seed_value = p_seed


func won() -> bool:
	return finished and outcome.begins_with(BenchScore.WIN_PREFIX)
