extends RefCounted
## The pre-flight cost estimate (docs/specs/benchmark.md §11.5): before the first
## request of an invocation, what it will likely cost and what it could cost at
## most — and, above the cap without `--yes`, a stop before anything is asked.
##
## The price comes from the service's public model list, asked once without the
## key; not reachable, not listed or not a number means "unknown", and an unknown
## price never blocks.
##
## A decision model's estimate (§17.9) asks nothing: its price is data.
##
## A tool, so no `class_name`; `bench_run.gd` and the tests preload it.

const Backend := preload("res://tools/bench/open_router_backend.gd")
const TypeSafe := preload("res://tools/bench/typesafe_backend.gd")

## The one host whose price list is asked for.
const PRICE_HOST: String = "openrouter.ai"
const FIELD_KNOWN: String = "known"
const FIELD_LIKELY: String = "likely"
const FIELD_AT_MOST: String = "at_most"
const FIELD_CALLS: String = "calls"
const FIELD_INPUT_TOKENS: String = "input_tokens"
const FIELD_PROMPT_PRICE: String = "prompt_price"
const FIELD_COMPLETION_PRICE: String = "completion_price"
const FIELD_PROMPT: String = "prompt"
const FIELD_COMPLETION: String = "completion"
const USD_FORMAT: String = "%.2f"


## ⌈characters ÷ `estimate.chars_per_token`⌉.
static func tokens(characters: int, config: BenchConfig) -> int:
	return ceili(float(characters) / float(config.chars_per_token))


## The two figures for `runs` seeds (§11.5 step 3); per call, the input is the
## brief plus the day-0 digest grown by `digest_growth`. A negative price is an
## unknown one: then only the calls and the input tokens are known.
static func figures(brief_tokens: int, digest_tokens: int, runs: int, prompt_price: float,
		completion_price: float, config: BenchConfig) -> Dictionary:
	var input: float = float(brief_tokens) + float(digest_tokens) * config.digest_growth
	var calls: int = runs * config.calls_per_run
	var out: Dictionary = {
		FIELD_KNOWN: prompt_price >= 0.0 and completion_price >= 0.0,
		FIELD_CALLS: calls,
		FIELD_INPUT_TOKENS: roundi(float(calls) * input),
		FIELD_PROMPT_PRICE: prompt_price,
		FIELD_COMPLETION_PRICE: completion_price,
		FIELD_LIKELY: 0.0,
		FIELD_AT_MOST: 0.0,
	}
	if bool(out[FIELD_KNOWN]):
		out[FIELD_LIKELY] = float(calls) * (input * prompt_price
			+ float(config.output_tokens_per_call) * completion_price)
		out[FIELD_AT_MOST] = float(runs * config.max_calls) * (input * prompt_price
			+ float(config.max_completion_tokens) * completion_price)
	return out


## `{"prompt": float, "completion": float}` (USD per token) of `model` in the
## body of `GET /models`, or {} when the body is not the list, the model is not
## in it, or a price is not a number string.
static func read_prices(body: String, model: String) -> Dictionary:
	var json: JSON = JSON.new()
	if json.parse(body) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	var data: Variant = (json.data as Dictionary).get("data")
	if typeof(data) != TYPE_ARRAY:
		return {}
	for item: Variant in data:
		if typeof(item) != TYPE_DICTIONARY or str((item as Dictionary).get("id", "")) != model:
			continue
		var pricing: Variant = (item as Dictionary).get("pricing")
		if typeof(pricing) != TYPE_DICTIONARY:
			return {}
		var prompt: Variant = (pricing as Dictionary).get(FIELD_PROMPT)
		var completion: Variant = (pricing as Dictionary).get(FIELD_COMPLETION)
		if typeof(prompt) != TYPE_STRING or typeof(completion) != TYPE_STRING \
				or not str(prompt).is_valid_float() or not str(completion).is_valid_float():
			return {}
		return {FIELD_PROMPT: str(prompt).to_float(), FIELD_COMPLETION: str(completion).to_float()}
	return {}


## The public price list, asked once without the key (§11.5 step 2). {} for any
## host but openrouter.ai, and for any failure — the price is then unknown.
static func fetch_prices(base_url: String, model: String, config: BenchConfig) -> Dictionary:
	var base: Dictionary = Backend.parse_base_url(base_url)
	if base.is_empty() or str(base["host"]) != PRICE_HOST:
		return {}
	var result: Dictionary = Backend.request(base, HTTPClient.METHOD_GET,
		str(base["prefix"]) + config.models_path, PackedStringArray(), "", config.timeout_s)
	if int(result["status"]) != Backend.STATUS_OK:
		return {}
	return read_prices(str(result["body"]), model)


## §17.9: a decision model's figures for `runs` seeds. Per call the input is its
## `rules`, the day-0 `situation` grown by `digest_growth`, and the questions'
## allowance; only input is priced (output is free today). A negative price in
## the data is an unknown one.
static func choice_figures(rules_tokens: int, situation_tokens: int, runs: int,
		config: BenchConfig) -> Dictionary:
	var input: float = float(rules_tokens) + float(situation_tokens) * config.digest_growth \
		+ float(config.typesafe_question_tokens)
	var calls: int = runs * config.calls_per_run
	var price: float = config.typesafe_price_input / TypeSafe.TOKENS_PER_MTOK
	var out: Dictionary = {
		FIELD_KNOWN: config.typesafe_price_input >= 0.0 and config.typesafe_price_output >= 0.0,
		FIELD_CALLS: calls,
		FIELD_INPUT_TOKENS: roundi(float(calls) * input),
		FIELD_PROMPT_PRICE: price,
		FIELD_COMPLETION_PRICE: config.typesafe_price_output / TypeSafe.TOKENS_PER_MTOK,
		FIELD_LIKELY: 0.0,
		FIELD_AT_MOST: 0.0,
	}
	if bool(out[FIELD_KNOWN]):
		out[FIELD_LIKELY] = float(calls) * input * price
		out[FIELD_AT_MOST] = float(runs * config.max_calls) * input * price
	return out


## §17.9's line: as §11.5's when the price is known; when it is not, what guards
## the run instead.
static func choice_line(estimate: Dictionary, runs: int, model: String, cap: float,
		max_requests: int, config: BenchConfig) -> String:
	if bool(estimate[FIELD_KNOWN]):
		return line(estimate, runs, model, cap)
	return ("benchmark: estimate for %d runs of %s: price unknown (≈%d calls, ≈%d input tokens)"
		+ " — only the request cap (%d) and %d calls a run guard this run") % [runs, model,
		int(estimate[FIELD_CALLS]), int(estimate[FIELD_INPUT_TOKENS]), max_requests,
		config.max_calls]


## §11.5 step 4's line.
static func line(estimate: Dictionary, runs: int, model: String, cap: float) -> String:
	if bool(estimate[FIELD_KNOWN]):
		return "benchmark: estimate for %d runs of %s: ≈%s USD, at most %s USD (cap %s USD)" % [
			runs, model, usd(float(estimate[FIELD_LIKELY])), usd(float(estimate[FIELD_AT_MOST])),
			usd(cap)]
	return ("benchmark: estimate for %d runs of %s: price unknown (≈%d calls, ≈%d input tokens)"
		+ " — the cap guards only the cost the service reports") % [runs, model,
		int(estimate[FIELD_CALLS]), int(estimate[FIELD_INPUT_TOKENS])]


## §11.5 step 5: the likely cost above the cap stops the tool unless `--yes`. An
## unknown price never does; `--yes` never lifts the cap itself.
static func preflight_blocks(estimate: Dictionary, cap: float, yes: bool) -> bool:
	return bool(estimate[FIELD_KNOWN]) and float(estimate[FIELD_LIKELY]) > cap and not yes


static func block_line(estimate: Dictionary) -> String:
	return ("benchmark: the estimate is above the cap — raise it with --max-cost=%d"
		+ " or pass --yes to play until the cap stops it") % ceili(float(estimate[FIELD_LIKELY]))


static func usd(value: float) -> String:
	return USD_FORMAT % value
