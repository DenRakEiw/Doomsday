extends SceneTree
## The model catalogue (docs/specs/benchmark.md §18.4): OpenRouter's public model
## list — asked without a key — with what a suite of each model would likely
## cost at each effort level, by the pre-flight estimate's rule (§11.5, §18.3).
## `tools/bench/models.ps1` runs it; `run_models.ps1` asks it for its estimate
## (`--models … --json`).
##
##     "$GODOT" --headless --path . -s tools/bench/model_list.gd -- \
##         [--search=<text>] [--free] [--max-cost=<usd>] [--suite=standard|quick]
##         [--effort=normal|high|ultra] [--models=<id>,<id>…] [--json]
##         [--prices=<a saved GET /models body>] [--data=<root=res://data>]
##
## Without `--effort` the table shows both suites at normal and the standard
## suite at high and ultra; with it, both suites at that level. `--max-cost`
## keeps the models whose likely cost of `--suite` at that level is at most so
## many USD (an unknown price is left out). The decision model
## `typesafe/jev-latest` is always listed first, at its published price.
##
## Exit codes: 0 listed · 1 bad arguments, content or config errors, the list
## could not be read (and no `--models` were named).

const Harness := preload("res://tools/sim_harness.gd")
const Tool := preload("res://tools/bench/bench_run.gd")
const Estimate := preload("res://tools/bench/bench_estimate.gd")
const Catalogue := preload("res://tools/bench/model_catalogue.gd")

const EXIT_OK: int = 0
const EXIT_BAD_INPUT: int = 1
const ID_WIDTH_MAX: int = 56
const MODEL_SEPARATOR: String = ","


func _initialize() -> void:
	quit(run(Harness.parse_args(OS.get_cmdline_user_args())))


## The tool; `config` null reads `data/benchmark.json`, `body` "" asks the
## network (or reads `--prices`).
static func run(args: Dictionary[String, String], config: BenchConfig = null,
		body: String = "") -> int:
	if config == null:
		config = BenchConfig.load_file()
	if not config.ok():
		for error: String in config.errors:
			print("models: config: %s" % error)
		return EXIT_BAD_INPUT
	var options: Dictionary = options_of(args, config)
	if not str(options["error"]).is_empty():
		print("models: %s" % options["error"])
		return EXIT_BAD_INPUT
	var db: ContentDB = Harness.load_content(args.get("data", Harness.DEFAULT_DATA))
	if db == null:
		return EXIT_BAD_INPUT
	var setup: RunSetup = RunSetup.from_dict(config.setup)
	if setup == null or not setup.validate(db).is_empty():
		print("models: config: setup is not a run this content can play")
		return EXIT_BAD_INPUT
	if body.is_empty():
		body = FileAccess.get_file_as_string(str(options["prices"])) \
			if not str(options["prices"]).is_empty() else Estimate.fetch_list(config.base_url, config)
	var rows: Array[Dictionary] = Catalogue.parse(body)
	var named: Array[String] = options["models"]
	if rows.is_empty() and named.is_empty():
		print("models: OpenRouter's public model list could not be read")
		return EXIT_BAD_INPUT
	var seed_value: int = config.suite_seeds(BenchConfig.SUITE_STANDARD)[0]
	var measured: Dictionary = Tool.measure(db, config, setup, seed_value, config.locale)
	var chat: Vector2i = Vector2i(Estimate.tokens(str(measured["brief"]).length(), config),
		Estimate.tokens(str(measured["digest"]).length(), config))
	var choice_request: Dictionary = Tool.measure_choice(db, config, setup, seed_value,
		config.locale, Catalogue.TYPESAFE_ALIAS)
	var choice: Vector2i = Vector2i(Estimate.tokens(str(choice_request["rules"]).length(), config),
		Estimate.tokens(str(choice_request["situation"]).length(), config))
	var shown: Array[Dictionary] = select(rows, options, config, chat, choice)
	if bool(options["json"]):
		for row: Dictionary in shown:
			print(JSON.stringify(json_line(row, options, config, chat, choice)))
		return EXIT_OK
	for text: String in table(shown, options, config, chat, choice):
		print(text)
	return EXIT_OK


## The arguments read and checked: `{"error", "search", "free", "max_cost" (−1:
## none), "suite", "effort", "effort_given", "models", "json", "prices"}`.
static func options_of(args: Dictionary[String, String], config: BenchConfig) -> Dictionary:
	var out: Dictionary = {"error": "", "search": args.get("search", ""),
		"free": args.has("free"), "max_cost": -1.0,
		"suite": args.get("suite", BenchConfig.SUITE_STANDARD),
		"effort": args.get("effort", BenchEffort.NORMAL), "effort_given": args.has("effort"),
		"models": [] as Array[String], "json": args.has("json"),
		"prices": args.get("prices", "")}
	if config.suite_seeds(str(out["suite"])).is_empty():
		out["error"] = "unknown suite \"%s\"" % out["suite"]
	elif not BenchEffort.is_level(str(out["effort"])):
		out["error"] = "--effort is normal, high or ultra"
	elif args.has("max-cost"):
		if not args["max-cost"].is_valid_float() or args["max-cost"].to_float() < 0.0:
			out["error"] = "--max-cost is not a number of 0 or more"
		else:
			out["max_cost"] = args["max-cost"].to_float()
	if args.has("models"):
		var named: Array[String] = []
		for id: String in args["models"].split(MODEL_SEPARATOR, false):
			if not id.strip_edges().is_empty():
				named.append(id.strip_edges())
		if named.is_empty() and str(out["error"]).is_empty():
			out["error"] = "--models names no model"
		out["models"] = named
	return out


## The rows to show: the named models in their order (a name the list lacks
## gets a row with unknown prices), or the decision model first and then every
## listed model that the search, `--free` and `--max-cost` keep.
static func select(rows: Array[Dictionary], options: Dictionary, config: BenchConfig,
		chat: Vector2i, choice: Vector2i) -> Array[Dictionary]:
	var by_id: Dictionary[String, Dictionary] = {}
	for row: Dictionary in rows:
		by_id[str(row[Catalogue.FIELD_ID])] = row
	var typesafe: Dictionary = Catalogue.typesafe_row(config)
	var out: Array[Dictionary] = []
	var named: Array[String] = options["models"]
	if not named.is_empty():
		for id: String in named:
			if id.begins_with(config.typesafe_model_prefix):
				var pinned: Dictionary = typesafe.duplicate(true)
				pinned[Catalogue.FIELD_ID] = id
				out.append(pinned)
			else:
				out.append(by_id.get(id, Catalogue.unlisted_row(id)))
		return out
	for row: Dictionary in [typesafe] + rows:
		if not Catalogue.matches(row, str(options["search"])):
			continue
		if bool(options["free"]) and not bool(row[Catalogue.FIELD_FREE]):
			continue
		if float(options["max_cost"]) >= 0.0:
			var figures: Dictionary = _figures(row, str(options["suite"]),
				str(options["effort"]), config, chat, choice)
			if figures.is_empty() or not bool(figures[Estimate.FIELD_KNOWN]) \
					or float(figures[Estimate.FIELD_LIKELY]) > float(options["max_cost"]):
				continue
		out.append(row)
	return out


## One machine-readable line per model (`run_models.ps1` reads it): the
## estimate of `--suite` at `--effort`, what the level sends, and why it cannot
## run when it cannot.
static func json_line(row: Dictionary, options: Dictionary, config: BenchConfig,
		chat: Vector2i, choice: Vector2i) -> Dictionary:
	var effort: String = str(options["effort"])
	var suite: String = str(options["suite"])
	var typesafe: bool = bool(row[Catalogue.FIELD_TYPESAFE])
	# A decision model has no effort; run_models plays it at its only one.
	var level: String = BenchEffort.NORMAL if typesafe else effort
	var figures: Dictionary = _figures(row, suite, level, config, chat, choice)
	var error: String = ""
	if figures.is_empty():
		error = "%s takes no reasoning parameter (OpenRouter's model list) — play it with -Effort normal" \
			% row[Catalogue.FIELD_ID]
	var max_tokens: int = config.max_completion_tokens
	if level != BenchEffort.NORMAL:
		max_tokens = maxi(max_tokens, int(config.effort_max_tokens.get(level, 0)))
	return {
		"id": row[Catalogue.FIELD_ID],
		"listed": row[Catalogue.FIELD_LISTED],
		"typesafe": typesafe,
		"free": row[Catalogue.FIELD_FREE],
		"reasoning": row[Catalogue.FIELD_REASONING],
		"mandatory": row[Catalogue.FIELD_MANDATORY],
		"effort": "" if typesafe else level,
		"reasoning_sent": Catalogue.reasoning_sent(row, level, config),
		"max_completion_tokens": 0 if typesafe else max_tokens,
		"suite": suite,
		"seeds": config.suite_seeds(suite),
		"known": not figures.is_empty() and bool(figures[Estimate.FIELD_KNOWN]),
		"likely": 0.0 if figures.is_empty() else float(figures[Estimate.FIELD_LIKELY]),
		"at_most": 0.0 if figures.is_empty() else float(figures[Estimate.FIELD_AT_MOST]),
		"cap": config.max_cost_usd,
		"error": error,
	}


## The human table (§18.4).
static func table(rows: Array[Dictionary], options: Dictionary, config: BenchConfig,
		chat: Vector2i, choice: Vector2i) -> PackedStringArray:
	var given: bool = bool(options["effort_given"])
	var effort: String = str(options["effort"])
	var headings: PackedStringArray = ["Model", "Context", "In $/M", "Out $/M", "Reasoning"]
	if given:
		headings.append_array(["Quick (%s)" % effort, "Standard (%s)" % effort])
	else:
		headings.append_array(["Quick", "Standard", "Std high", "Std ultra"])
	var cells: Array[PackedStringArray] = []
	for row: Dictionary in rows:
		var id: String = str(row[Catalogue.FIELD_ID])
		if id.length() > ID_WIDTH_MAX:
			id = id.substr(0, ID_WIDTH_MAX - 1) + "…"
		var line: PackedStringArray = [
			id + (" *" if bool(row[Catalogue.FIELD_FREE]) else ""),
			str(row[Catalogue.FIELD_CONTEXT]) if int(row[Catalogue.FIELD_CONTEXT]) > 0 \
				else Catalogue.NONE_MARK,
			Catalogue.per_million(float(row[Catalogue.FIELD_PROMPT])),
			Catalogue.per_million(float(row[Catalogue.FIELD_COMPLETION])),
			"decision model" if bool(row[Catalogue.FIELD_TYPESAFE]) \
				else Catalogue.reasoning_text(row),
		]
		var levels: Array[Array] = [[BenchConfig.SUITE_QUICK, effort],
			[BenchConfig.SUITE_STANDARD, effort]]
		if not given:
			levels = [[BenchConfig.SUITE_QUICK, BenchEffort.NORMAL],
				[BenchConfig.SUITE_STANDARD, BenchEffort.NORMAL],
				[BenchConfig.SUITE_STANDARD, BenchEffort.HIGH],
				[BenchConfig.SUITE_STANDARD, BenchEffort.ULTRA]]
		for level: Array in levels:
			line.append(Catalogue.likely_text(_figures(row, str(level[0]), str(level[1]), config,
				chat, choice)))
		cells.append(line)
	var widths: Array[int] = []
	for heading: String in headings:
		widths.append(heading.length())
	for line: PackedStringArray in cells:
		for i: int in line.size():
			widths[i] = maxi(widths[i], line[i].length())
	var out: PackedStringArray = [_joined(headings, widths)]
	var rule: PackedStringArray = []
	for width: int in widths:
		rule.append("-".repeat(width))
	out.append(_joined(rule, widths))
	for line: PackedStringArray in cells:
		out.append(_joined(line, widths))
	out.append("")
	out.append(("%d models. Costs are likely USD for a whole suite (quick %d seeds, standard %d)"
		+ " by the pre-flight rule; ? = price unknown, — = the level does not apply."
		+ " * = free. The tool's cap is %s USD per invocation.") % [rows.size(),
		config.suite_seeds(BenchConfig.SUITE_QUICK).size(),
		config.suite_seeds(BenchConfig.SUITE_STANDARD).size(), Estimate.usd(config.max_cost_usd)])
	return out


static func _figures(row: Dictionary, suite: String, effort: String, config: BenchConfig,
		chat: Vector2i, choice: Vector2i) -> Dictionary:
	var runs: int = config.suite_seeds(suite).size()
	var tokens: Vector2i = choice if bool(row[Catalogue.FIELD_TYPESAFE]) else chat
	return Catalogue.estimate(row, tokens.x, tokens.y, runs, effort, config)


static func _joined(cells: PackedStringArray, widths: Array[int]) -> String:
	var parts: PackedStringArray = []
	for i: int in cells.size():
		parts.append(cells[i].rpad(widths[i]) if i == 0 else cells[i].lpad(widths[i]))
	return "  ".join(parts).strip_edges(false, true)
