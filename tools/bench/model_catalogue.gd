extends RefCounted
## The model catalogue (docs/specs/benchmark.md §18.4): OpenRouter's public model
## list read into rows — id, context, prices, whether and how a model reasons —
## and what a suite of it would likely cost at each effort level, by the
## pre-flight estimate's own rule (§11.5, §18.3). Pure: `model_list.gd` asks for
## the list and prints; the tests feed a fixture.
##
## A tool, so no `class_name`; `model_list.gd` and the tests preload it.

const Estimate := preload("res://tools/bench/bench_estimate.gd")
const TypeSafe := preload("res://tools/bench/typesafe_backend.gd")

const FREE_SUFFIX: String = ":free"
const FIELD_ID: String = "id"
const FIELD_NAME: String = "name"
const FIELD_CONTEXT: String = "context"
const FIELD_PROMPT: String = "prompt"
const FIELD_COMPLETION: String = "completion"
const FIELD_FREE: String = "free"
const FIELD_REASONING: String = "reasoning"
const FIELD_EFFORTS: String = "efforts"
const FIELD_MANDATORY: String = "mandatory"
## Whether the model reasons when nothing is sent, and at which effort (§18.1).
const FIELD_DEFAULT_ON: String = "reasons_by_default"
const FIELD_DEFAULT_EFFORT: String = "default_effort"
const FIELD_TYPESAFE: String = "typesafe"
const FIELD_LISTED: String = "listed"
const LIST_NAME: String = "name"
const LIST_CONTEXT: String = "context_length"
## A price the list does not give (Backend.NO_PRICE's value).
const NO_PRICE: float = -1.0
## The TypeSafe row's id: the ranked alias (§17.7).
const TYPESAFE_ALIAS: String = "jev-latest"
const USD_PER_MTOK_FORMAT: String = "%.2f"
const NONE_MARK: String = "—"


## Every entry of a `GET /models` body with an id, sorted by id; [] when the
## body is not the list.
static func parse(body: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for item: Variant in Estimate.list_items(body):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = item
		if typeof(d.get(Estimate.LIST_ID)) != TYPE_STRING or str(d[Estimate.LIST_ID]).is_empty():
			continue
		rows.append(row_of(d))
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a[FIELD_ID]) < str(b[FIELD_ID]))
	return rows


## One entry of the list as a row.
static func row_of(item: Dictionary) -> Dictionary:
	var info: Dictionary = Estimate.model_info(item)
	var id: String = str(item[Estimate.LIST_ID])
	var prompt: float = float(info.get(Estimate.FIELD_PROMPT, NO_PRICE))
	var completion: float = float(info.get(Estimate.FIELD_COMPLETION, NO_PRICE))
	var context: Variant = item.get(LIST_CONTEXT)
	return {
		FIELD_ID: id,
		FIELD_NAME: str(item[LIST_NAME]) if typeof(item.get(LIST_NAME)) == TYPE_STRING else id,
		FIELD_CONTEXT: int(context) if typeof(context) in [TYPE_INT, TYPE_FLOAT] else 0,
		FIELD_PROMPT: prompt,
		FIELD_COMPLETION: completion,
		FIELD_FREE: id.ends_with(FREE_SUFFIX) or (prompt == 0.0 and completion == 0.0),
		FIELD_REASONING: bool(info[Estimate.FIELD_REASONING]),
		FIELD_EFFORTS: info[Estimate.FIELD_EFFORTS],
		FIELD_MANDATORY: bool(info[Estimate.FIELD_MANDATORY]),
		FIELD_DEFAULT_ON: bool(info[Estimate.FIELD_DEFAULT_ON]),
		FIELD_DEFAULT_EFFORT: str(info[Estimate.FIELD_DEFAULT_EFFORT]),
		FIELD_TYPESAFE: false,
		FIELD_LISTED: true,
	}


## The decision model's row (§17): its published price from the data, no
## reasoning levels.
static func typesafe_row(config: BenchConfig) -> Dictionary:
	var efforts: Array[String] = []
	return {
		FIELD_ID: config.typesafe_model_prefix + TYPESAFE_ALIAS,
		FIELD_NAME: "TypeSafe Jev (decision model)",
		FIELD_CONTEXT: config.typesafe_request_limit,
		FIELD_PROMPT: config.typesafe_price_input / TypeSafe.TOKENS_PER_MTOK
			if config.typesafe_price_input >= 0.0 else NO_PRICE,
		FIELD_COMPLETION: config.typesafe_price_output / TypeSafe.TOKENS_PER_MTOK
			if config.typesafe_price_output >= 0.0 else NO_PRICE,
		FIELD_FREE: false,
		FIELD_REASONING: false,
		FIELD_EFFORTS: efforts,
		FIELD_MANDATORY: false,
		FIELD_DEFAULT_ON: false,
		FIELD_DEFAULT_EFFORT: "",
		FIELD_TYPESAFE: true,
		FIELD_LISTED: true,
	}


## A row for an id the list does not name: prices unknown.
static func unlisted_row(id: String) -> Dictionary:
	var efforts: Array[String] = []
	return {FIELD_ID: id, FIELD_NAME: id, FIELD_CONTEXT: 0, FIELD_PROMPT: NO_PRICE,
		FIELD_COMPLETION: NO_PRICE, FIELD_FREE: false, FIELD_REASONING: false,
		FIELD_EFFORTS: efforts, FIELD_MANDATORY: false, FIELD_DEFAULT_ON: false,
		FIELD_DEFAULT_EFFORT: "", FIELD_TYPESAFE: false, FIELD_LISTED: false}


## Whether `row` answers a search: its id or name contains `text`, any case.
static func matches(row: Dictionary, text: String) -> bool:
	if text.is_empty():
		return true
	var wanted: String = text.to_lower()
	return str(row[FIELD_ID]).to_lower().contains(wanted) \
		or str(row[FIELD_NAME]).to_lower().contains(wanted)


## Whether an effort level means anything for `row`: normal always; high and
## ultra for a chat model that takes a reasoning parameter — or that the list
## does not name (unknown; `bench_run.gd` refuses only what the list rules out).
static func takes_effort(row: Dictionary, effort: String) -> bool:
	if bool(row[FIELD_TYPESAFE]):
		return effort == BenchEffort.NORMAL
	return effort == BenchEffort.NORMAL or bool(row[FIELD_REASONING]) \
		or not bool(row[FIELD_LISTED])


## The estimate of `runs` seeds of `row` at `effort` (§11.5, §18.3) — the tool's
## own figures: the input measured from the brief and the day-0 digest (for the
## decision model: its rules and situation), the output and the completion limit
## the level's. {} when the level does not apply to the model.
static func estimate(row: Dictionary, prompt_tokens: int, digest_tokens: int, runs: int,
		effort: String, config: BenchConfig) -> Dictionary:
	if not takes_effort(row, effort):
		return {}
	if bool(row[FIELD_TYPESAFE]):
		return Estimate.choice_figures(prompt_tokens, digest_tokens, runs, config)
	var max_tokens: int = config.max_completion_tokens
	if effort != BenchEffort.NORMAL:
		max_tokens = maxi(max_tokens, int(config.effort_max_tokens.get(effort, 0)))
	return Estimate.figures(prompt_tokens, digest_tokens, runs, float(row[FIELD_PROMPT]),
		float(row[FIELD_COMPLETION]), config,
		BenchEffort.output_tokens(effort, config, bool(row[FIELD_DEFAULT_ON])), max_tokens)


## What the level sends to this model (§18.2), "" for normal and where it does
## not apply; never less than the effort it reasons at by default.
static func reasoning_sent(row: Dictionary, effort: String, config: BenchConfig) -> String:
	if effort == BenchEffort.NORMAL or not takes_effort(row, effort):
		return ""
	var efforts: Array[String] = []
	efforts.assign(row[FIELD_EFFORTS])
	return BenchEffort.reasoning_for(effort, config, efforts, Estimate.effort_floor(row))


## The reasoning cell: the dash (none), "yes", "default" (it reasons when
## nothing is sent — at normal too — but can be switched off) or "always" (it
## cannot), and the highest effort it lists.
static func reasoning_text(row: Dictionary) -> String:
	if not bool(row[FIELD_REASONING]):
		return NONE_MARK
	var text: String = "yes"
	if bool(row[FIELD_MANDATORY]):
		text = "always"
	elif bool(row[FIELD_DEFAULT_ON]):
		text = "default"
	var efforts: Array = row[FIELD_EFFORTS]
	if not efforts.is_empty():
		text += ", up to %s" % str(efforts[0])
	return text


## USD per million tokens of a per-token price; the dash when unknown.
static func per_million(price: float) -> String:
	if price < 0.0:
		return NONE_MARK
	return USD_PER_MTOK_FORMAT % (price * TypeSafe.TOKENS_PER_MTOK)


## An estimate's likely figure in USD; the dash when it does not apply, "?"
## when the price is unknown.
static func likely_text(figures: Dictionary) -> String:
	if figures.is_empty():
		return NONE_MARK
	if not bool(figures[Estimate.FIELD_KNOWN]):
		return "?"
	return Estimate.usd(float(figures[Estimate.FIELD_LIKELY]))
