class_name GlobalBoardRow
extends RefCounted
## One row of the global leaderboard (docs/specs/benchmark.md §16.6): a model on
## one content, its score over the standard suite and its verified runs.

var model: String = ""
var params_id: String = ""
var content_hash: String = ""
var complete: bool = false
var runs: int = 0
var of: int = 0
var wins: int = 0
var score: float = 0.0
var seeds: Array[GlobalBoardRun] = []


## A built-in bot's reference row (`bot:<policy>`).
func is_bot() -> bool:
	return model.begins_with(BenchEntry.MODEL_BOT_PREFIX)
