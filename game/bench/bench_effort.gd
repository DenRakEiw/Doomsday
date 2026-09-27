class_name BenchEffort
extends RefCounted
## How hard a chat model is asked to think (docs/specs/benchmark.md §18): three
## levels the user picks per run — `normal` (no reasoning parameter, the
## provider's default), `high` and `ultra` — and how each one shows in a list.
##
## A level other than normal goes into the run's `params` (so it is a row of its
## own, a `params_id` of its own and a cache key of its own) and into the entry
## as `effort`. Normal is never written: every entry and board from before the
## levels reads as normal, byte for byte unchanged.
##
## Bots and decision models have no effort: their lists show a dash.

const NORMAL: String = "normal"
const HIGH: String = "high"
const ULTRA: String = "ultra"
const LEVELS: Array[String] = [NORMAL, HIGH, ULTRA]
## The key in `params` and in the entry.
const PARAM: String = "effort"
## `params`' OpenRouter reasoning effort (§8.3) — what a level resolves to, or
## what `--reasoning` sets directly.
const PARAM_REASONING: String = "reasoning"
const PARAM_MAX_TOKENS: String = "max_completion_tokens"
## The line under a list's row and in the spectator strip.
const KEY_LINE: String = "UI_BENCH_EFFORT"
const KEY_NONE: String = "BENCH_EFFORT_NONE"
const KEY_NORMAL: String = "BENCH_EFFORT_NORMAL"
const KEY_HIGH: String = "BENCH_EFFORT_HIGH"
const KEY_ULTRA: String = "BENCH_EFFORT_ULTRA"
## A `--reasoning` run shows its raw OpenRouter value (data, like a model id)
## when it looks like one; anything else shows the dash.
const RAW_PATTERN: String = "^[a-z]{1,16}$"

static var _raw: RegEx = null


static func is_level(text: String) -> bool:
	return LEVELS.has(text)


## What a run's effort was: "" when the idea does not apply (a bot, a decision
## model), a level, or — for a run made with the low-level `--reasoning` — that
## raw value.
static func of_run(backend: String, model: String, params: Dictionary, effort: String) -> String:
	if backend == BenchEntry.BACKEND_BOT or model.begins_with(BenchEntry.MODEL_BOT_PREFIX) \
			or params.has(BenchChoice.PARAM_CHOICE_VERSION):
		return ""
	if is_level(effort):
		return effort
	var reasoning: String = str(params.get(PARAM_REASONING, ""))
	return NORMAL if reasoning.is_empty() else reasoning


static func of_entry(entry: BenchEntry) -> String:
	return of_run(entry.backend, entry.model, entry.params, entry.effort)


## The translation key of a level; "" for anything else.
static func key_of(effort: String) -> String:
	match effort:
		NORMAL:
			return KEY_NORMAL
		HIGH:
			return KEY_HIGH
		ULTRA:
			return KEY_ULTRA
	return ""


## The word a list shows: the level translated, a raw reasoning value as it is,
## the dash for "" and for anything that does not look like a value.
static func label(effort: String) -> String:
	var key: String = key_of(effort)
	if not key.is_empty():
		return TranslationServer.translate(key)
	if not effort.is_empty() and label_is_safe(effort):
		return effort
	return TranslationServer.translate(KEY_NONE)


## Whether `effort` may be shown as it is: a level, or a short lower-case word.
static func label_is_safe(effort: String) -> bool:
	return is_level(effort) or _regex_raw().search(effort) != null


## "Effort: High" — the line a list and the strip show.
static func line(effort: String) -> String:
	return TranslationServer.translate(KEY_LINE).format({"effort": label(effort)})


## The reasoning effort a level sends (§18.2): the first of the config's list
## for it that the model lists as supported; the first of the list when the
## model's efforts are unknown (OpenRouter maps an effort a model does not have
## to its nearest one). "" for normal.
static func reasoning_for(effort: String, config: BenchConfig, supported: Array[String]) -> String:
	if not config.effort_reasoning.has(effort):
		return ""
	var wanted: Array[String] = config.effort_reasoning[effort]
	for value: String in wanted:
		if supported.has(value):
			return value
	return wanted[0] if not wanted.is_empty() else ""


## A chat run's params with the level applied (§18.2): normal leaves them as
## they are; high and ultra add `effort`, set `reasoning` and raise
## `max_completion_tokens` to the level's (a larger `--max-tokens` stays).
static func apply(params: Dictionary, effort: String, config: BenchConfig,
		supported: Array[String]) -> Dictionary:
	var out: Dictionary = params.duplicate(true)
	if effort == NORMAL or not config.effort_reasoning.has(effort):
		return out
	out[PARAM] = effort
	out[PARAM_REASONING] = reasoning_for(effort, config, supported)
	out[PARAM_MAX_TOKENS] = maxi(int(out.get(PARAM_MAX_TOKENS, 0)),
		int(config.effort_max_tokens.get(effort, 0)))
	return out


## The output tokens a call of this level likely writes, for the estimate.
static func output_tokens(effort: String, config: BenchConfig) -> int:
	return int(config.effort_output_tokens.get(effort, config.output_tokens_per_call))


static func _regex_raw() -> RegEx:
	if _raw == null:
		_raw = RegEx.create_from_string(RAW_PATTERN)
	return _raw
