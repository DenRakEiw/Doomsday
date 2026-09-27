class_name GlobalBoardRow
extends RefCounted
## One row of the global leaderboard (docs/specs/benchmark.md §16.6): a model on
## one content, its score over one suite (standard or quick) and its verified
## runs.

var model: String = ""
## `BenchConfig.SUITE_STANDARD` or `SUITE_QUICK`.
var suite: String = BenchConfig.SUITE_STANDARD
var params_id: String = ""
var content_hash: String = ""
var complete: bool = false
var runs: int = 0
var of: int = 0
var wins: int = 0
var score: float = 0.0
## §18: how hard the model was asked to think — a level, a raw reasoning value,
## or "" (a bot, a decision model, a board from before the levels).
var effort: String = ""
var seeds: Array[GlobalBoardRun] = []


## A built-in bot's reference row (`bot:<policy>`).
func is_bot() -> bool:
	return model.begins_with(BenchEntry.MODEL_BOT_PREFIX)


func is_quick() -> bool:
	return suite == BenchConfig.SUITE_QUICK
