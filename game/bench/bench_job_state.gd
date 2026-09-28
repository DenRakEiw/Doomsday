class_name BenchJobState
extends RefCounted
## The player's benchmark as the interface sees it (docs/specs/benchmark.md
## §19.5, §19.9.1): the model, the effort, the cap, one `BenchJobSeed` per seed,
## the cost so far, and whether it runs, finished or stopped — and why.
## `BenchJobs` feeds it the workers' progress lines through `apply_line`; pure,
## so a test can feed it lines of its own.

const RUNNING: String = "running"
const DONE: String = "done"
const STOPPED: String = "stopped"
## `reason` of a benchmark the player stopped: no reason line.
const REASON_PLAYER: String = ""

## §19.4: a worker's `progress.jsonl` — one JSON object per line. The worker
## writes them, this class reads them; the key and model text never appear.
const PROGRESS_FILE: String = "progress.jsonl"
const EVENT: String = "event"
const EVENT_DECISION: String = "decision"
const EVENT_RUN: String = "run"
const EVENT_STOPPED: String = "stopped"
const EVENT_DONE: String = "done"
const FIELD_SEED: String = "seed"
const FIELD_DAY: String = "day"
const FIELD_DAYS: String = "days"
const FIELD_CALLS: String = "calls"
const FIELD_COST: String = "cost_usd"
const FIELD_OUTCOME: String = "outcome"
const FIELD_SCORE: String = "score"
const FIELD_REASON: String = "reason"

var model: String = ""
var effort: String = BenchEffort.NORMAL
var cap_usd: float = 0.0
## A free model plays in one worker and shows no cost (§19.5, §19.9.1).
var free: bool = false
## Mock workers (`--bench-mock`, debug builds): their entries go elsewhere.
var mock: bool = false
var seeds: Array[BenchJobSeed] = []
var status: String = RUNNING
## One of `BenchRunner.STOP_REASONS` once stopped; `REASON_PLAYER` for *Stop*.
var reason: String = REASON_PLAYER


func _init(p_model: String = "", p_effort: String = BenchEffort.NORMAL, p_cap_usd: float = 0.0,
		p_free: bool = false, p_seeds: Array[int] = []) -> void:
	model = p_model
	effort = p_effort
	cap_usd = p_cap_usd
	free = p_free
	for value: int in p_seeds:
		seeds.append(BenchJobSeed.new(value))


func is_running() -> bool:
	return status == RUNNING


## The row of `seed_value`, or null for a seed this benchmark does not play.
func seed_row(seed_value: int) -> BenchJobSeed:
	for row: BenchJobSeed in seeds:
		if row.seed_value == seed_value:
			return row
	return null


## What every seed has cost so far.
func cost_usd() -> float:
	var total: float = 0.0
	for row: BenchJobSeed in seeds:
		total += row.cost_usd
	return total


func finished_runs() -> int:
	var count: int = 0
	for row: BenchJobSeed in seeds:
		if row.finished:
			count += 1
	return count


func wins() -> int:
	var count: int = 0
	for row: BenchJobSeed in seeds:
		if row.won():
			count += 1
	return count


## One line of a worker's `progress.jsonl` (§19.4). Returns whether anything
## changed. `stopped` and `done` are the worker's own end; the whole benchmark's
## end is `BenchJobs`' to judge.
func apply_line(line: Dictionary) -> bool:
	var row: BenchJobSeed = seed_row(int(line.get(FIELD_SEED, -1)))
	match str(line.get(EVENT, "")):
		EVENT_DECISION:
			if row == null or row.finished:
				return false
			row.started = true
			row.day = int(line.get(FIELD_DAY, row.day))
			row.calls = int(line.get(FIELD_CALLS, row.calls))
			row.cost_usd = float(line.get(FIELD_COST, row.cost_usd))
			return true
		EVENT_RUN:
			if row == null:
				return false
			row.started = true
			row.finished = true
			row.day = int(line.get(FIELD_DAYS, row.day))
			row.calls = int(line.get(FIELD_CALLS, row.calls))
			row.cost_usd = float(line.get(FIELD_COST, row.cost_usd))
			row.outcome = str(line.get(FIELD_OUTCOME, ""))
			row.score = float(line.get(FIELD_SCORE, 0.0))
			return true
	return false


## The benchmark ends: done, or stopped for `why`.
func end(why: String, stopped: bool) -> void:
	status = STOPPED if stopped else DONE
	reason = why if stopped else REASON_PLAYER
