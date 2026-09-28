class_name BenchJob
extends RefCounted
## One worker's job file, `<job dir>/job.json` (docs/specs/benchmark.md §19.4):
## what `BenchJobs` asks a headless worker to play. **Never the key** — that
## travels on the worker's stdin.

const FILE: String = "job.json"
const VERSION: int = 1

## The backends a job may name. A mock is `mock:<mode>`, debug builds only.
const BACKEND_OPENROUTER: String = "openrouter"
const BACKEND_TYPESAFE: String = "typesafe-openrouter"
## What a mock worker gets on stdin in place of a key: no secret, but the same
## pipe, so every mock run proves the key would have arrived (§19.4).
const MOCK_KEY_LINE: String = "mock-worker-key-line"

const KEY_VERSION: String = "version"
const KEY_MODEL: String = "model"
const KEY_BACKEND: String = "backend"
const KEY_EFFORT: String = "effort"
const KEY_REASONING: String = "reasoning"
const KEY_SUITE: String = "suite"
const KEY_SEEDS: String = "seeds"
const KEY_MAX_COST: String = "max_cost_usd"
const KEY_LOCALE: String = "locale"
const KEY_OUT: String = "out"
const KEY_CACHE: String = "cache"

var model: String = ""
var backend: String = BACKEND_OPENROUTER
var effort: String = BenchEffort.NORMAL
## §18.1's resolved reasoning effort, "" at normal — resolved once by the game,
## so every worker of one benchmark sends the same.
var reasoning: String = ""
var suite: String = ""
var seeds: Array[int] = []
## This worker's share of the player's cap (USD).
var max_cost_usd: float = 0.0
var locale: String = ""
## Where entries go (`<out>/runs/`) and where the answer cache lives.
var out: String = ""
var cache: String = ""


func to_dict() -> Dictionary:
	return {
		KEY_VERSION: VERSION,
		KEY_MODEL: model,
		KEY_BACKEND: backend,
		KEY_EFFORT: effort,
		KEY_REASONING: reasoning,
		KEY_SUITE: suite,
		KEY_SEEDS: seeds.duplicate(),
		KEY_MAX_COST: max_cost_usd,
		KEY_LOCALE: locale,
		KEY_OUT: out,
		KEY_CACHE: cache,
	}


## The job in `d`, or null when it is not one of this version (a worker then
## stops with `error`).
static func from_dict(d: Variant) -> BenchJob:
	if typeof(d) != TYPE_DICTIONARY:
		return null
	var raw: Dictionary = d
	if int(raw.get(KEY_VERSION, 0)) != VERSION or typeof(raw.get(KEY_SEEDS)) != TYPE_ARRAY:
		return null
	var job: BenchJob = BenchJob.new()
	job.model = str(raw.get(KEY_MODEL, ""))
	job.backend = str(raw.get(KEY_BACKEND, ""))
	job.effort = str(raw.get(KEY_EFFORT, BenchEffort.NORMAL))
	job.reasoning = str(raw.get(KEY_REASONING, ""))
	job.suite = str(raw.get(KEY_SUITE, ""))
	for value: Variant in raw[KEY_SEEDS]:
		if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
			job.seeds.append(int(value))
	job.max_cost_usd = float(raw.get(KEY_MAX_COST, 0.0))
	job.locale = str(raw.get(KEY_LOCALE, ""))
	job.out = str(raw.get(KEY_OUT, ""))
	job.cache = str(raw.get(KEY_CACHE, ""))
	return job


## Reads `<dir>/job.json`; null when it is missing or not a job.
static func read(dir: String) -> BenchJob:
	return from_dict(JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(FILE))))


## Writes `<dir>/job.json`; false when it could not.
func write(dir: String) -> bool:
	return not BenchRunner.write_text(dir.path_join(FILE),
		JSON.stringify(to_dict(), "\t", false)).is_empty()
