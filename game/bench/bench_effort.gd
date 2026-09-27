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
## A `--reasoning` run's raw value: "reasoning {reasoning}".
const KEY_RAW: String = "BENCH_EFFORT_RAW"
## A `--reasoning` run shows its raw OpenRouter value (data, like a model id)
## when it looks like one; anything else shows the dash.
const RAW_PATTERN: String = "^[a-z]{1,16}$"
## What `of_run` puts before a `--reasoning` run's raw value, so that
## `--reasoning=high` (the default limit, no `effort`) never reads as the level
## High (§18.2).
const RAW_PREFIX: String = "reasoning-"
## OpenRouter's reasoning efforts, lowest first (§18.1) — only to compare them.
const EFFORT_ORDER: Array[String] = ["none", "minimal", "low", "medium", "high", "xhigh", "max"]

static var _raw: RegEx = null


static func is_level(text: String) -> bool:
	return LEVELS.has(text)


## Whether `text` is a `--reasoning` run's marked raw value (`reasoning-low`).
static func is_raw(text: String) -> bool:
	return text.begins_with(RAW_PREFIX) and _regex_raw().search(raw_value(text)) != null


## The raw value of `reasoning-low`: `low`.
static func raw_value(text: String) -> String:
	return text.trim_prefix(RAW_PREFIX)


## What a run's effort was: "" when the idea does not apply (a bot, a decision
## model), a level, or — for a run made with the low-level `--reasoning` — that
## raw value marked with `RAW_PREFIX` (§18.2).
static func of_run(backend: String, model: String, params: Dictionary, effort: String) -> String:
	if backend == BenchEntry.BACKEND_BOT or model.begins_with(BenchEntry.MODEL_BOT_PREFIX) \
			or params.has(BenchChoice.PARAM_CHOICE_VERSION):
		return ""
	if is_level(effort):
		return effort
	var reasoning: String = str(params.get(PARAM_REASONING, ""))
	return NORMAL if reasoning.is_empty() else RAW_PREFIX + reasoning


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


## The word a list shows: the level translated, a `--reasoning` run's raw value
## as "reasoning low", an unmarked short word (a board from before the marker)
## as it is, the dash for "" and for anything that does not look like a value.
static func label(effort: String) -> String:
	var key: String = key_of(effort)
	if not key.is_empty():
		return TranslationServer.translate(key)
	if is_raw(effort):
		return TranslationServer.translate(KEY_RAW).format({"reasoning": raw_value(effort)})
	if not effort.is_empty() and label_is_safe(effort):
		return effort
	return TranslationServer.translate(KEY_NONE)


## Whether `effort` may be shown: a level, a marked raw value, or a short
## lower-case word.
static func label_is_safe(effort: String) -> bool:
	return is_level(effort) or is_raw(effort) or _regex_raw().search(effort) != null


## "Effort: High" — the line a list and the strip show.
static func line(effort: String) -> String:
	return TranslationServer.translate(KEY_LINE).format({"effort": label(effort)})


## Where an OpenRouter effort stands in `EFFORT_ORDER`; −1 for anything else.
static func rank(value: String) -> int:
	return EFFORT_ORDER.find(value)


## The reasoning effort a level sends (§18.2): the first of the config's list
## for it that the model lists as supported; the first of the list when the
## model's efforts are unknown (OpenRouter maps an effort a model does not have
## to its nearest one). `floor` is the effort the model reasons at when nothing
## is sent (its `default_effort` when it reasons by default, else ""): a level
## never sends less, so normal ≤ high ≤ ultra holds for every model. "" for
## normal.
static func reasoning_for(effort: String, config: BenchConfig, supported: Array[String],
		floor: String = "") -> String:
	if not config.effort_reasoning.has(effort):
		return ""
	var wanted: Array[String] = []
	wanted.assign(config.effort_reasoning[effort])
	var chosen: String = wanted[0] if not wanted.is_empty() else ""
	for value: String in wanted:
		if supported.has(value):
			chosen = value
			break
	return floor if rank(floor) > rank(chosen) else chosen


## Whether a level may send `value` (§18.2): an OpenRouter effort at or above
## the lowest one the config lists for it — what `reasoning_for` can resolve to.
static func sends(effort: String, value: String, config: BenchConfig) -> bool:
	if not config.effort_reasoning.has(effort) or rank(value) < 0:
		return false
	var lowest: int = EFFORT_ORDER.size()
	for listed: Variant in config.effort_reasoning[effort]:
		lowest = mini(lowest, rank(str(listed)))
	return rank(value) >= lowest


## Why a run's params are not what its level sends (§16.4 `rules`, §18.2); ""
## when they are, and for a run without a level above normal: the reasoning one
## the level may send, the completion limit at least the level's.
static func params_broken(params: Dictionary, effort: String, config: BenchConfig) -> String:
	if effort.is_empty() or effort == NORMAL:
		return ""
	if not config.effort_reasoning.has(effort):
		return "the effort is not a level"
	if not sends(effort, str(params.get(PARAM_REASONING, "")), config):
		return "effort %s does not send that reasoning" % effort
	var limit: int = int(config.effort_max_tokens.get(effort, 0))
	var given: Variant = params.get(PARAM_MAX_TOKENS)
	if typeof(given) not in [TYPE_INT, TYPE_FLOAT] or int(given) < limit:
		return "effort %s needs max_completion_tokens of at least %d" % [effort, limit]
	return ""


## A chat run's params with the level applied (§18.2): normal leaves them as
## they are; high and ultra add `effort`, set `reasoning` — `pinned` when given
## (`--effort-reasoning`: resolved once, the same for every shard), else
## `reasoning_for`'s — and raise `max_completion_tokens` to the level's (a
## larger `--max-tokens` stays).
static func apply(params: Dictionary, effort: String, config: BenchConfig,
		supported: Array[String], floor: String = "", pinned: String = "") -> Dictionary:
	var out: Dictionary = params.duplicate(true)
	if effort == NORMAL or not config.effort_reasoning.has(effort):
		return out
	out[PARAM] = effort
	out[PARAM_REASONING] = pinned if not pinned.is_empty() \
		else reasoning_for(effort, config, supported, floor)
	out[PARAM_MAX_TOKENS] = maxi(int(out.get(PARAM_MAX_TOKENS, 0)),
		int(config.effort_max_tokens.get(effort, 0)))
	return out


## The output tokens a call of this level likely writes, for the estimate. A
## model that reasons by default reasons at normal too — until its limit, so
## that limit is its likely output (§18.3).
static func output_tokens(effort: String, config: BenchConfig,
		reasons_by_default: bool = false) -> int:
	if effort == NORMAL and reasons_by_default:
		return config.max_completion_tokens
	return int(config.effort_output_tokens.get(effort, config.output_tokens_per_call))


static func _regex_raw() -> RegEx:
	if _raw == null:
		_raw = RegEx.create_from_string(RAW_PATTERN)
	return _raw
