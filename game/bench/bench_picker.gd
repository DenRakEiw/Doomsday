class_name BenchPicker
extends RefCounted
## The rules of the player's model picker (docs/specs/benchmark.md §19.8 items
## 4–6): which of OpenRouter's models are offered, in which order, which effort
## levels each may play, what the quick suite likely costs, and when the cap or
## a confirmation stands in the way. Pure: the benchmark modal
## (`ui/modals/bench_run.gd`) asks and draws, the tests feed a fixture list.

## §19.8 item 4: kinds of model that cannot play (PROGRESS *Waiting on the
## user*, the *Not suitable* kinds of 2026-09-27).
const SUFFIX_CONTENT_SAFETY: String = "-content-safety"
const PREFIX_ROUTER: String = "openrouter/"
## `measure`'s answer: tokens of the brief and the day-0 digest (`x`, `y`) for a
## chat model, of the rules and the situation for a decision model.
const FIELD_CHAT: String = "chat"
const FIELD_CHOICE: String = "choice"


## The rows of `ModelCatalogue.parse` a player may choose: without the content
## classifiers, the router ids and the models that do not answer in text. A
## `typesafe/*` id plays through the decision-model backend (§17), so its row is
## the decision model's: no effort levels, its estimate from the data.
static func candidates(rows: Array[Dictionary], config: BenchConfig) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Dictionary in rows:
		var id: String = str(row[ModelCatalogue.FIELD_ID])
		if id.ends_with(SUFFIX_CONTENT_SAFETY) or id.begins_with(PREFIX_ROUTER):
			continue
		if not bool(row.get(ModelCatalogue.FIELD_TEXT_OUT, true)):
			continue
		if not config.typesafe_model_prefix.is_empty() \
				and id.begins_with(config.typesafe_model_prefix):
			var decision: Dictionary = row.duplicate(true)
			var none: Array[String] = []
			decision[ModelCatalogue.FIELD_TYPESAFE] = true
			decision[ModelCatalogue.FIELD_REASONING] = false
			decision[ModelCatalogue.FIELD_EFFORTS] = none
			decision[ModelCatalogue.FIELD_DEFAULT_ON] = false
			out.append(decision)
			continue
		out.append(row)
	return out


## The rows to list (§19.8 item 4): those the search and *Free only* keep —
## free first, then the likely cost of the player's suite at `effort` (a model
## the level does not apply to at normal; unknown prices after known ones), then
## id — at most `player.models_shown`.
static func shown(rows: Array[Dictionary], search: String, free_only: bool, effort: String,
		tokens: Dictionary, config: BenchConfig) -> Array[Dictionary]:
	var kept: Array[Dictionary] = []
	var likely: Array[float] = []
	for row: Dictionary in rows:
		if not ModelCatalogue.matches(row, search.strip_edges()):
			continue
		if free_only and not is_free(row):
			continue
		kept.append(row)
		var level: String = effort if ModelCatalogue.takes_effort(row, effort) else BenchEffort.NORMAL
		var figures: Dictionary = estimate(row, level, tokens, config)
		likely.append(float(figures[BenchEstimate.FIELD_LIKELY])
			if not figures.is_empty() and bool(figures[BenchEstimate.FIELD_KNOWN]) else INF)
	var order: Array[int] = []
	for i: int in kept.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		var a_free: bool = is_free(kept[a])
		if a_free != is_free(kept[b]):
			return a_free
		if likely[a] != likely[b]:
			return likely[a] < likely[b]
		return str(kept[a][ModelCatalogue.FIELD_ID]) < str(kept[b][ModelCatalogue.FIELD_ID]))
	var out: Array[Dictionary] = []
	for i: int in order:
		if out.size() >= config.player_models_shown:
			break
		out.append(kept[i])
	return out


static func is_free(row: Dictionary) -> bool:
	return bool(row[ModelCatalogue.FIELD_FREE])


## §19.8 item 5: the levels `row` may play. Normal always; High and Ultra for a
## model the list names with reasoning; a decision model Normal only.
static func efforts(row: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for level: String in BenchEffort.LEVELS:
		if ModelCatalogue.takes_effort(row, level):
			out.append(level)
	return out


## §19.8 item 5: a model that reasons by default starts on High, every other on
## Normal.
static func start_effort(row: Dictionary) -> String:
	if bool(row[ModelCatalogue.FIELD_DEFAULT_ON]) and efforts(row).has(BenchEffort.HIGH):
		return BenchEffort.HIGH
	return BenchEffort.NORMAL


## Whether the Normal level wants the note that this model reasons there too.
static func reasons_at_normal(row: Dictionary) -> bool:
	return bool(row[ModelCatalogue.FIELD_DEFAULT_ON]) and not bool(row[ModelCatalogue.FIELD_TYPESAFE])


## What the level sends to the model, resolved once when *Start* is pressed.
static func reasoning(row: Dictionary, effort: String, config: BenchConfig) -> String:
	return ModelCatalogue.reasoning_sent(row, effort, config)


## The estimate of the player's suite (§11.5, §18.3); {} when the level does
## not apply to the model.
static func estimate(row: Dictionary, effort: String, tokens: Dictionary,
		config: BenchConfig) -> Dictionary:
	var runs: int = config.suite_seeds(config.player_suite).size()
	var key: String = FIELD_CHOICE if bool(row[ModelCatalogue.FIELD_TYPESAFE]) else FIELD_CHAT
	var measured: Vector2i = tokens.get(key, Vector2i.ZERO)
	return ModelCatalogue.estimate(row, measured.x, measured.y, runs, effort, config)


## §19.8 item 6: the cap the player chose, when it is one of the choices; else
## the data's default.
static func cap_for(chosen: float, config: BenchConfig) -> float:
	return chosen if config.player_cap_choices.has(chosen) else config.player_default_cap_usd


## §19.8 item 6: a paid model whose likely cost is above the cap may not start
## (the tool's exit 7). An unknown price never blocks; a free model ignores the cap.
static func over_cap(row: Dictionary, figures: Dictionary, cap: float) -> bool:
	if is_free(row) or figures.is_empty() or not bool(figures[BenchEstimate.FIELD_KNOWN]):
		return false
	return float(figures[BenchEstimate.FIELD_LIKELY]) > cap


## §19.8 item 8: a paid or unknown-price model asks before it starts.
static func needs_confirm(row: Dictionary) -> bool:
	return not is_free(row)


## §19.8 item 6: the tokens the estimate is measured from — the brief and the
## day-0 digest of the suite's first seed, and the decision model's request —
## in the language the game shows (switching it would rebuild every screen).
static func measure(db: ContentDB, config: BenchConfig) -> Dictionary:
	var setup: RunSetup = RunSetup.from_dict(config.setup)
	var seeds: Array[int] = config.suite_seeds(config.player_suite)
	if db == null or setup == null or seeds.is_empty():
		return {FIELD_CHAT: Vector2i.ZERO, FIELD_CHOICE: Vector2i.ZERO}
	var locale: String = TranslationServer.get_locale()
	var chat: Dictionary = BenchRunner.measure(db, config, setup, seeds[0], locale)
	var choice: Dictionary = BenchRunner.measure_choice(db, config, setup, seeds[0], locale,
		config.typesafe_model_prefix + ModelCatalogue.TYPESAFE_ALIAS)
	return {
		FIELD_CHAT: Vector2i(BenchEstimate.tokens(str(chat["brief"]).length(), config),
			BenchEstimate.tokens(str(chat["digest"]).length(), config)),
		FIELD_CHOICE: Vector2i(BenchEstimate.tokens(str(choice["rules"]).length(), config),
			BenchEstimate.tokens(str(choice["situation"]).length(), config)),
	}
