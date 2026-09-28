class_name BenchEstimate
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
## In `game/bench/` since S6.12f (§19.3): the game's benchmark modal estimates too.

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
## `read_model`'s fields (§18.2): whether the list names the model, whether it
## takes a reasoning parameter, the efforts it lists, whether it always reasons,
## whether it reasons when nothing is sent (`mandatory` or `default_enabled`) and
## at which effort then.
const FIELD_LISTED: String = "listed"
const FIELD_REASONING: String = "reasoning"
const FIELD_EFFORTS: String = "efforts"
const FIELD_MANDATORY: String = "mandatory"
const FIELD_DEFAULT_ON: String = "reasons_by_default"
const FIELD_DEFAULT_EFFORT: String = "default_effort"
const LIST_DATA: String = "data"
const LIST_ID: String = "id"
const LIST_PRICING: String = "pricing"
const LIST_SUPPORTED: String = "supported_parameters"
const LIST_REASONING: String = "reasoning"
const LIST_SUPPORTED_EFFORTS: String = "supported_efforts"
const LIST_MANDATORY: String = "mandatory"
const LIST_DEFAULT_ENABLED: String = "default_enabled"
const LIST_DEFAULT_EFFORT: String = "default_effort"
const USD_FORMAT: String = "%.2f"


## ⌈characters ÷ `estimate.chars_per_token`⌉.
static func tokens(characters: int, config: BenchConfig) -> int:
	return ceili(float(characters) / float(config.chars_per_token))


## The two figures for `runs` seeds (§11.5 step 3); per call, the input is the
## brief plus the day-0 digest grown by `digest_growth`. A negative price is an
## unknown one: then only the calls and the input tokens are known.
## `output_tokens` and `max_tokens` (−1: the config's) are an effort level's
## (§18.3): a model that reasons writes far more than one that does not.
static func figures(brief_tokens: int, digest_tokens: int, runs: int, prompt_price: float,
		completion_price: float, config: BenchConfig, output_tokens: int = -1,
		max_tokens: int = -1) -> Dictionary:
	var per_call_out: int = config.output_tokens_per_call if output_tokens < 0 else output_tokens
	var limit: int = config.max_completion_tokens if max_tokens < 0 else max_tokens
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
			+ float(per_call_out) * completion_price)
		out[FIELD_AT_MOST] = float(runs * config.max_calls) * (input * prompt_price
			+ float(limit) * completion_price)
	return out


## `{"prompt": float, "completion": float}` (USD per token) of `model` in the
## body of `GET /models`, or {} when the body is not the list, the model is not
## in it, or a price is not a number string.
static func read_prices(body: String, model: String) -> Dictionary:
	var info: Dictionary = read_model(body, model)
	if not info.has(FIELD_PROMPT) or not info.has(FIELD_COMPLETION):
		return {}
	return {FIELD_PROMPT: info[FIELD_PROMPT], FIELD_COMPLETION: info[FIELD_COMPLETION]}


## What the public list says about `model` (§18.2): {} when the body is not the
## list; `{"listed": false}` when the model is not in it; else `listed`,
## `reasoning`, `efforts`, `mandatory`, `reasons_by_default`, `default_effort`
## and — when both parse — the two prices.
static func read_model(body: String, model: String) -> Dictionary:
	var items: Array = list_items(body)
	if items.is_empty() and not _is_list(body):
		return {}
	for item: Variant in items:
		if typeof(item) == TYPE_DICTIONARY and str((item as Dictionary).get(LIST_ID, "")) == model:
			return model_info(item)
	return {FIELD_LISTED: false}


## The entries of a `GET /models` body; [] when it is not the list.
static func list_items(body: String) -> Array:
	var json: JSON = JSON.new()
	if json.parse(body) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return []
	var data: Variant = (json.data as Dictionary).get(LIST_DATA)
	return data if typeof(data) == TYPE_ARRAY else []


## One entry of the list read: prices only when both are number strings; a
## model takes reasoning when it names the parameter or carries a reasoning
## object (OpenRouter's reasoning-tokens guide: "non-reasoning models … omit the
## `reasoning` field"). It reasons by default when that object says `mandatory`
## or `default_enabled` — then even a normal run, which sends no reasoning
## parameter, thinks at its `default_effort` (§18.1).
static func model_info(item: Dictionary) -> Dictionary:
	var info: Dictionary = {FIELD_LISTED: true}
	var pricing: Variant = item.get(LIST_PRICING)
	if typeof(pricing) == TYPE_DICTIONARY:
		var prompt: Variant = (pricing as Dictionary).get(FIELD_PROMPT)
		var completion: Variant = (pricing as Dictionary).get(FIELD_COMPLETION)
		if typeof(prompt) == TYPE_STRING and typeof(completion) == TYPE_STRING \
				and str(prompt).is_valid_float() and str(completion).is_valid_float():
			info[FIELD_PROMPT] = str(prompt).to_float()
			info[FIELD_COMPLETION] = str(completion).to_float()
	var supported: Variant = item.get(LIST_SUPPORTED)
	var reasoning: Variant = item.get(LIST_REASONING)
	var efforts: Array[String] = []
	var mandatory: bool = false
	var by_default: bool = false
	var default_effort: String = ""
	if typeof(reasoning) == TYPE_DICTIONARY:
		var object: Dictionary = reasoning
		var listed: Variant = object.get(LIST_SUPPORTED_EFFORTS)
		if typeof(listed) == TYPE_ARRAY:
			for value: Variant in listed:
				if typeof(value) == TYPE_STRING:
					efforts.append(str(value))
		mandatory = object.get(LIST_MANDATORY) == true
		by_default = mandatory or object.get(LIST_DEFAULT_ENABLED) == true
		if typeof(object.get(LIST_DEFAULT_EFFORT)) == TYPE_STRING \
				and BenchEffort.rank(str(object[LIST_DEFAULT_EFFORT])) >= 0:
			default_effort = str(object[LIST_DEFAULT_EFFORT])
	info[FIELD_REASONING] = typeof(reasoning) == TYPE_DICTIONARY \
		or (typeof(supported) == TYPE_ARRAY and (supported as Array).has(LIST_REASONING))
	info[FIELD_EFFORTS] = efforts
	info[FIELD_MANDATORY] = mandatory
	info[FIELD_DEFAULT_ON] = by_default
	info[FIELD_DEFAULT_EFFORT] = default_effort
	return info


## The effort a level must not go below for this model (`BenchEffort.reasoning_for`'s
## `floor`): its default effort when it reasons by default, else "".
static func effort_floor(info: Dictionary) -> String:
	if not bool(info.get(FIELD_DEFAULT_ON, false)):
		return ""
	return str(info.get(FIELD_DEFAULT_EFFORT, ""))


static func _is_list(body: String) -> bool:
	var json: JSON = JSON.new()
	return json.parse(body) == OK and typeof(json.data) == TYPE_DICTIONARY \
		and typeof((json.data as Dictionary).get(LIST_DATA)) == TYPE_ARRAY


## The public price list, asked once without the key (§11.5 step 2). {} for any
## host but openrouter.ai, and for any failure — the price is then unknown.
static func fetch_prices(base_url: String, model: String, config: BenchConfig) -> Dictionary:
	return read_prices(fetch_list(base_url, config), model)


## `read_model` of the public list (§18.2); {} when it cannot be asked.
static func fetch_model(base_url: String, model: String, config: BenchConfig) -> Dictionary:
	return read_model(fetch_list(base_url, config), model)


## The body of the public model list — no key, one try; "" for any host but
## openrouter.ai and for any failure.
static func fetch_list(base_url: String, config: BenchConfig) -> String:
	var base: Dictionary = OpenRouterBackend.parse_base_url(base_url)
	if base.is_empty() or str(base["host"]) != PRICE_HOST:
		return ""
	var result: Dictionary = OpenRouterBackend.request(base, HTTPClient.METHOD_GET,
		str(base["prefix"]) + config.models_path, PackedStringArray(), "", config.timeout_s)
	if int(result["status"]) != OpenRouterBackend.STATUS_OK:
		return ""
	return str(result["body"])


## §17.9: a decision model's figures for `runs` seeds. Per call the input is its
## `rules`, the day-0 `situation` grown by `digest_growth`, and the questions'
## allowance; only input is priced (output is free today). A negative price in
## the data is an unknown one.
static func choice_figures(rules_tokens: int, situation_tokens: int, runs: int,
		config: BenchConfig) -> Dictionary:
	var input: float = float(rules_tokens) + float(situation_tokens) * config.digest_growth \
		+ float(config.typesafe_question_tokens)
	var calls: int = runs * config.calls_per_run
	var price: float = config.typesafe_price_input / TypeSafeBackend.TOKENS_PER_MTOK
	var out: Dictionary = {
		FIELD_KNOWN: config.typesafe_price_input >= 0.0 and config.typesafe_price_output >= 0.0,
		FIELD_CALLS: calls,
		FIELD_INPUT_TOKENS: roundi(float(calls) * input),
		FIELD_PROMPT_PRICE: price,
		FIELD_COMPLETION_PRICE: config.typesafe_price_output / TypeSafeBackend.TOKENS_PER_MTOK,
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
