extends SceneTree
## The benchmark tool (docs/specs/benchmark.md §11): a model plays the fixed seed
## suite headless, each run is written as an entry and the leaderboard is rebuilt.
##
##     "$GODOT" --headless --path . -s tools/bench/bench_run.gd -- \
##         --model=<id> [--backend=openrouter|typesafe|mock:cheapest|mock:wait|mock:invalid
##             |mock:mixed|mock-choice:first|mock-choice:idle|mock-choice:shuffled
##             |mock-choice:broken]
##         [--suite=standard|quick] [--seeds=a..b] [--locale=en|de]
##         [--temperature=<f>] [--max-tokens=<n>] [--json-mode=true|false]
##         [--effort=normal|high|ultra [--effort-reasoning=<effort>]
##             | --reasoning=low|medium|high] [--top-p=<f>]
##         [--base-url=<url>] [--key-env=<VAR>] [--via-openrouter] [--max-cost=<usd>]
##         [--max-requests=<n>] [--yes]
##         [--out=<dir=res://benchmark>] [--cache=<dir=res://benchmark/cache>] [--fresh]
##         [--data=<root=res://data>] [--dry-run] [--no-rebuild]
##     … -- --bots [--suite=…] [--seeds=a..b] [--out=<dir>] [--if-missing] [--no-rebuild]
##     … -- --rebuild [--out=<dir>]
##     … -- --determinism-fixture
##
## A model id beginning with `typesafe/` is a decision model (§17): TypeSafeBackend's
## backend, one request of choice questions per decision, the chat-only flags
## refused. The key comes from the environment (`OPENROUTER_API_KEY` or
## `TYPESAFE_API_KEY`, or the variable `--key-env` names) and is never printed;
## with `OPENROUTER_API_KEY` empty, the key the game stored (§19.2) is used.
## `--via-openrouter` asks a decision model through OpenRouter's copy of the same
## endpoint instead: OpenRouter's address and key, and the id sent whole
## (`typesafe/jev-1.13`), as OpenRouter names it.
## Before the first request the tool prints what the invocation will likely cost
## and stops when that is above the cap, unless `--yes` (§11.5, §17.9).
##
## Exit codes: 0 finished · 1 bad arguments, content or config errors, missing key
## · 3 a replay did not reproduce its run · 4 the service refused (auth, credits,
## forbidden, bad request) · 5 the service was unavailable after the retries · 6
## the cost cap (or TypeSafe's request cap) was reached · 7 the estimate is above
## the cap and `--yes` was not given (nothing was requested).
##
## `--effort` (§18) asks a chat model to think harder: `high` sends OpenRouter's
## reasoning effort `high`, `ultra` the highest effort the model's public list
## names (`max`, else `xhigh`, else `high`), both with a larger completion limit
## and timeout; never below the effort a model reasons at by default. The level
## goes into the params — a row of its own — and into the entry. What a level
## sends is read from the list once per process, so a live `high` or `ultra`
## whose list cannot be read stops (exit 1) instead of guessing;
## `--effort-reasoning=<effort>` pins it (`run_models.ps1` resolves it once and
## gives every shard the same, so they share one `params_id`). `--reasoning`
## stays the low-level form: that effort as it is, nothing else.

const Harness := preload("res://tools/sim_harness.gd")
const Writer := preload("res://tools/bench/leaderboard_writer.gd")

## §11.3 — `BenchRunner`'s, which the game's worker quits with too.
const EXIT_OK: int = BenchRunner.EXIT_OK
const EXIT_BAD_INPUT: int = BenchRunner.EXIT_BAD_INPUT
const EXIT_REPLAY_MISMATCH: int = BenchRunner.EXIT_REPLAY_MISMATCH
const EXIT_REFUSED: int = BenchRunner.EXIT_REFUSED
const EXIT_UNAVAILABLE: int = BenchRunner.EXIT_UNAVAILABLE
const EXIT_COST_CAP: int = BenchRunner.EXIT_COST_CAP
const EXIT_ESTIMATE: int = BenchRunner.EXIT_ESTIMATE

const DEFAULT_OUT: String = "res://benchmark"
const DEFAULT_CACHE: String = "res://benchmark/cache"
const BACKEND_OPENROUTER: String = "openrouter"
const BACKEND_TYPESAFE: String = "typesafe"
## A decision model takes none of these (§17.7).
const CHAT_FLAGS: Array[String] = ["temperature", "max-tokens", "json-mode", "reasoning",
	"top-p", "effort", "effort-reasoning"]
const VERSION_ARROW: String = " → "
const REASONING_LEVELS: Array[String] = ["low", "medium", "high"]
const LOCALES: Array[String] = ["en", "de"]
const SEED_RANGE: String = ".."
## §16.8: the cross-platform canary — `mock:cheapest`, the standard suite's first
## seed, 300 days, recorded on Windows.
const FIXTURE_PATH: String = "res://tests/fixtures/bench/determinism_entry.json"
const FIXTURE_MAX_DAYS: int = 300
const FIXTURE_MODEL: String = "mock"
const FIXTURE_BACKEND: String = "mock:cheapest"

const PARAM_TEMPERATURE: String = BenchRunner.PARAM_TEMPERATURE
const PARAM_MAX_TOKENS: String = BenchRunner.PARAM_MAX_TOKENS
const PARAM_JSON_MODE: String = BenchRunner.PARAM_JSON_MODE
const PARAM_REASONING: String = BenchRunner.PARAM_REASONING
const PARAM_TOP_P: String = BenchRunner.PARAM_TOP_P
const ARG_TRUE: String = "true"
const ARG_FALSE: String = "false"
const ARG_VIA_OPENROUTER: String = "via-openrouter"


## Not `_init`: TLS is ready only once the main loop starts, and the price list
## and the model are asked over HTTPS.
func _initialize() -> void:
	quit(run(Harness.parse_args(OS.get_cmdline_user_args())))


## The whole tool; `config` null reads `data/benchmark.json`. The tests call this
## with a config of their own and an `--out` under `user://`.
static func run(args: Dictionary[String, String], config: BenchConfig = null) -> int:
	if config == null:
		config = BenchConfig.load_file()
	if not config.ok():
		for error: String in config.errors:
			print("benchmark: config: %s" % error)
		return EXIT_BAD_INPUT
	var db: ContentDB = Harness.load_content(args.get("data", Harness.DEFAULT_DATA))
	if db == null:
		return EXIT_BAD_INPUT
	var setup: RunSetup = RunSetup.from_dict(config.setup)
	if setup == null or not setup.validate(db).is_empty():
		print("benchmark: config: setup is not a run this content can play")
		return EXIT_BAD_INPUT
	var out: String = args.get("out", DEFAULT_OUT)
	if args.has("rebuild"):
		return _rebuild(out, config, db, [])
	if args.has("determinism-fixture"):
		return _fixture(db, config, setup)
	var suite: String = args.get("suite", BenchConfig.SUITE_STANDARD)
	if config.suite_seeds(suite).is_empty():
		print("benchmark: unknown suite \"%s\"" % suite)
		return EXIT_BAD_INPUT
	var seeds: Array[int] = seeds_in(args.get("seeds", ""), config.suite_seeds(suite))
	if seeds.is_empty():
		print("benchmark: --seeds names no seed of the suite \"%s\"" % suite)
		return EXIT_BAD_INPUT
	if args.has("bots"):
		return _bots(args, db, config, setup, suite, seeds, out)
	return _models(args, db, config, setup, suite, seeds, out)


## The suite's seeds within `--seeds=a..b` (or one seed, `--seeds=a`); all of
## them without the argument; none for an argument that does not read.
static func seeds_in(range_text: String, suite_seeds: Array[int]) -> Array[int]:
	if range_text.is_empty():
		return suite_seeds.duplicate()
	var bounds: PackedStringArray = range_text.split(SEED_RANGE)
	if bounds.size() > 2 or not bounds[0].is_valid_int() \
			or (bounds.size() == 2 and not bounds[1].is_valid_int()):
		return []
	var low: int = bounds[0].to_int()
	var high: int = bounds[1].to_int() if bounds.size() == 2 else low
	var out: Array[int] = []
	for value: int in suite_seeds:
		if value >= low and value <= high:
			out.append(value)
	return out


## The backend an invocation plays with (§17.9): `--backend` when given, else
## TypeSafe's for a model id with its prefix, else OpenRouter's.
static func backend_for(args: Dictionary[String, String], config: BenchConfig) -> String:
	if args.has("backend"):
		return args["backend"]
	var model: String = args.get("model", "")
	return BACKEND_TYPESAFE if model.begins_with(config.typesafe_model_prefix) \
		else BACKEND_OPENROUTER


## The run's parameters (§10.2) from the flags and the config's defaults:
## `{"params": Dictionary, "error": String, "effort": String, "pinned": String}`.
## The effort level (§18) is only named here — `BenchEffort.apply` adds it to the
## params once the model's supported efforts are known; `pinned` is
## `--effort-reasoning`'s value ("" without it).
static func build_params(args: Dictionary[String, String], config: BenchConfig) -> Dictionary:
	var params: Dictionary = BenchRunner.default_params(config)
	if args.has("temperature"):
		if not args["temperature"].is_valid_float():
			return _bad_params("--temperature is not a number")
		params[PARAM_TEMPERATURE] = args["temperature"].to_float()
	if args.has("max-tokens"):
		if not args["max-tokens"].is_valid_int() or args["max-tokens"].to_int() < 1:
			return _bad_params("--max-tokens is not a whole number above 0")
		params[PARAM_MAX_TOKENS] = args["max-tokens"].to_int()
	if args.has("json-mode"):
		if args["json-mode"] != ARG_TRUE and args["json-mode"] != ARG_FALSE:
			return _bad_params("--json-mode is true or false")
		params[PARAM_JSON_MODE] = args["json-mode"] == ARG_TRUE
	if args.has("reasoning"):
		if not REASONING_LEVELS.has(args["reasoning"]):
			return _bad_params("--reasoning is low, medium or high")
		params[PARAM_REASONING] = args["reasoning"]
	if args.has("top-p"):
		if not args["top-p"].is_valid_float() or args["top-p"].to_float() < 0.0:
			return _bad_params("--top-p is not a number of 0 or more")
		params[PARAM_TOP_P] = args["top-p"].to_float()
	var effort: String = args.get("effort", BenchEffort.NORMAL)
	if not BenchEffort.is_level(effort):
		return _bad_params("--effort is normal, high or ultra")
	if effort != BenchEffort.NORMAL and args.has("reasoning"):
		return _bad_params("--effort and --reasoning cannot be given together"
			+ " (--reasoning is the low-level form of the same thing)")
	var pinned: String = args.get("effort-reasoning", "")
	if args.has("effort-reasoning") and not BenchEffort.sends(effort, pinned, config):
		return _bad_params("--effort-reasoning names an effort that --effort=%s does not send"
			% effort)
	return {"params": params, "error": "", "effort": effort, "pinned": pinned}


static func _bad_params(reason: String) -> Dictionary:
	return {"params": {}, "error": reason, "effort": BenchEffort.NORMAL, "pinned": ""}


## §18.2: the params with the effort level applied (`BenchRunner.effort_params`).
static func effort_params(params: Dictionary, effort: String, model: String, info: Dictionary,
		config: BenchConfig, pinned: String = "") -> Dictionary:
	return BenchRunner.effort_params(params, effort, model, info, config, pinned)


## The per-seed pieces live in `BenchRunner` since S6.12f (§19.3); these keep the
## tool's names for its callers and tests.
static func play_model(db: ContentDB, config: BenchConfig, setup: RunSetup, seed_value: int,
		backend: ModelBackend, params: Dictionary, locale: String,
		hooks: Dictionary = {}) -> Dictionary:
	return BenchRunner.play_model(db, config, setup, seed_value, backend, params, locale, hooks)


static func reproduces(db: ContentDB, seed_value: int, sim: Simulation, setup: RunSetup) -> bool:
	return BenchRunner.reproduces(db, seed_value, sim, setup)


static func make_entry(sim: Simulation, config: BenchConfig, model: String, backend: String,
		params: Dictionary, locale: String, suite: String, max_days: int,
		policy: ModelPolicy = null) -> BenchEntry:
	return BenchRunner.make_entry(sim, config, model, backend, params, locale, suite, max_days,
		policy)


static func write_entry(out: String, entry: BenchEntry) -> String:
	return BenchRunner.write_entry(out, entry)


static func write_text(path: String, text: String) -> String:
	return BenchRunner.write_text(path, text)


static func exit_for(fatal: String) -> int:
	return BenchRunner.exit_for(fatal)


## The brief and the day-0 digest of a seed, in the run's language — what
## `--dry-run` prints and the estimate measures.
static func measure(db: ContentDB, config: BenchConfig, setup: RunSetup, seed_value: int,
		locale: String) -> Dictionary:
	var previous: String = TranslationServer.get_locale()
	TranslationServer.set_locale(locale)
	var brief: String = BenchPrompt.brief(db, setup, config)
	var sim: Simulation = Simulation.create(db, seed_value, setup)
	var digest: String = BenchPrompt.digest_text(
		BenchDigest.build(sim, BenchDigest.new_memory(), config), db)
	TranslationServer.set_locale(previous)
	return {"brief": brief, "digest": digest}


## A decision model's day-0 request of a seed (§17.9): its `rules` and
## `situation`, the request body for `model`, and the three token measures the
## dry run checks against the service's limits.
static func measure_choice(db: ContentDB, config: BenchConfig, setup: RunSetup, seed_value: int,
		locale: String, model: String) -> Dictionary:
	var previous: String = TranslationServer.get_locale()
	TranslationServer.set_locale(locale)
	var rules: String = BenchPrompt.rules(db, setup, config)
	var sim: Simulation = Simulation.create(db, seed_value, setup)
	var digest: BenchDigest = BenchDigest.build(sim, BenchDigest.new_memory(), config)
	var situation: String = BenchPrompt.digest_text(digest, db, false)
	var plan: BenchChoicePlan = BenchChoice.plan(sim, digest, rules, situation, config)
	TranslationServer.set_locale(previous)
	var body: Dictionary = plan.body(model)
	var longest: int = 0
	for question: Variant in plan.questions:
		longest = maxi(longest, BenchEstimate.tokens(JSON.stringify(plan.questions[question]).length(),
			config))
	return {
		"rules": rules,
		"situation": situation,
		"body": body,
		"state_tokens": BenchEstimate.tokens(JSON.stringify(plan.state).length(), config),
		"question_tokens": longest,
		"request_tokens": BenchEstimate.tokens(JSON.stringify(body).length(), config),
	}


## The lines the dry run prints after a decision model's request (§17.9).
static func limit_lines(measured: Dictionary, config: BenchConfig) -> PackedStringArray:
	var state: int = int(measured["state_tokens"])
	var question: int = int(measured["question_tokens"])
	var request: int = int(measured["request_tokens"])
	var out: PackedStringArray = [("benchmark: state ≈%d + longest question ≈%d = ≈%d tokens"
		+ " (limit %d); request ≈%d tokens (limit %d)") % [state, question, state + question,
		config.typesafe_state_limit, request, config.typesafe_request_limit]]
	if state + question > config.typesafe_state_limit or request > config.typesafe_request_limit:
		out.append("benchmark: above the service's limit")
	return out


static func _models(args: Dictionary[String, String], db: ContentDB, config: BenchConfig,
		setup: RunSetup, suite: String, seeds: Array[int], out: String) -> int:
	var model: String = args.get("model", "")
	if model.is_empty() or model == ARG_TRUE:
		print("benchmark: --model=<id> is required (or --bots, --rebuild, --determinism-fixture)")
		return EXIT_BAD_INPUT
	# §17.9: the backend follows the model id unless `--backend` says otherwise.
	var typesafe_model: bool = model.begins_with(config.typesafe_model_prefix)
	var backend_name: String = backend_for(args, config)
	var mock_mode: String = MockBackend.mode_of(backend_name)
	var choice_mode: String = MockChoiceBackend.mode_of(backend_name)
	var typesafe: bool = backend_name == BACKEND_TYPESAFE
	if backend_name != BACKEND_OPENROUTER and not typesafe and mock_mode.is_empty() \
			and choice_mode.is_empty():
		print("benchmark: unknown backend \"%s\"" % backend_name)
		return EXIT_BAD_INPUT
	if typesafe and not typesafe_model:
		print("benchmark: the typesafe backend takes %s<model>" % config.typesafe_model_prefix)
		return EXIT_BAD_INPUT
	var choosing: bool = typesafe or not choice_mode.is_empty()
	var mock: bool = not mock_mode.is_empty() or not choice_mode.is_empty()
	var params: Dictionary = {}
	var effort: String = BenchEffort.NORMAL
	var pinned: String = ""
	if choosing:
		for flag: String in CHAT_FLAGS:
			if args.has(flag):
				print("benchmark: --%s is for chat models; a decision model takes no such parameter"
					% flag)
				return EXIT_BAD_INPUT
		params = BenchChoice.params_of(config)
	else:
		var built: Dictionary = build_params(args, config)
		if not str(built["error"]).is_empty():
			print("benchmark: %s" % built["error"])
			return EXIT_BAD_INPUT
		params = built["params"]
		effort = str(built["effort"])
		pinned = str(built["pinned"])
	var locale: String = args.get("locale", config.locale)
	if not LOCALES.has(locale):
		print("benchmark: --locale is en or de")
		return EXIT_BAD_INPUT
	# OpenRouter serves TypeSafe's endpoint under its own address and key.
	var via_openrouter: bool = typesafe and args.has(ARG_VIA_OPENROUTER)
	if args.has(ARG_VIA_OPENROUTER) and not typesafe:
		print("benchmark: --%s is for a decision model (%s<model>)"
			% [ARG_VIA_OPENROUTER, config.typesafe_model_prefix])
		return EXIT_BAD_INPUT
	var base_url: String = args.get("base-url",
		config.typesafe_base_url if typesafe and not via_openrouter else config.base_url)
	if not mock and OpenRouterBackend.parse_base_url(base_url).is_empty():
		print("benchmark: --base-url is not an https URL (or http to this machine)")
		return EXIT_BAD_INPUT
	var cap_text: String = args.get("max-cost", str(config.max_cost_usd))
	if not cap_text.is_valid_float() or cap_text.to_float() < 0.0:
		print("benchmark: --max-cost is not a number of 0 or more")
		return EXIT_BAD_INPUT
	var cap: float = cap_text.to_float()
	var requests_text: String = args.get("max-requests", str(config.typesafe_max_requests))
	if not requests_text.is_valid_int() or requests_text.to_int() < 1:
		print("benchmark: --max-requests is not a whole number above 0")
		return EXIT_BAD_INPUT
	var dry_run: bool = args.has("dry-run")
	var key_env: String = args.get("key-env",
		config.typesafe_key_env if typesafe and not via_openrouter else config.key_env)
	var key: String = ""
	if not mock and not dry_run:
		key = OS.get_environment(key_env)
		# §19.3: a key the player set in the game serves the tool too — OpenRouter's
		# only, the one key the store holds.
		if key.is_empty() and key_env == config.key_env and BenchKeyStore.is_supported():
			key = BenchKeyStore.new().load()
		if key.is_empty():
			print("benchmark: set %s in the environment (or the key in the game's settings)"
				% key_env)
			return EXIT_BAD_INPUT
	# What is sent as `model`: a decision model's id after its prefix (§17.7) —
	# TypeSafe's own name — or whole, OpenRouter's.
	var sent_model: String = model.trim_prefix(config.typesafe_model_prefix) \
		if typesafe and not via_openrouter else model
	var estimate: Dictionary = {}
	if choosing:
		var request: Dictionary = measure_choice(db, config, setup, seeds[0], locale, sent_model)
		var rules_tokens: int = BenchEstimate.tokens(str(request["rules"]).length(), config)
		var situation_tokens: int = BenchEstimate.tokens(str(request["situation"]).length(), config)
		if dry_run:
			print(request["rules"])
			print("≈%d tokens" % rules_tokens)
			print("")
			print(request["situation"])
			print("≈%d tokens" % situation_tokens)
			print("")
			print(JSON.stringify(request["body"], "\t", false))
			for text: String in limit_lines(request, config):
				print(text)
		if typesafe:
			estimate = BenchEstimate.choice_figures(rules_tokens, situation_tokens, seeds.size(), config)
			print(BenchEstimate.choice_line(estimate, seeds.size(), model, cap, requests_text.to_int(),
				config))
	else:
		var measured: Dictionary = measure(db, config, setup, seeds[0], locale)
		var brief_tokens: int = BenchEstimate.tokens(str(measured["brief"]).length(), config)
		var digest_tokens: int = BenchEstimate.tokens(str(measured["digest"]).length(), config)
		if dry_run:
			print(measured["brief"])
			print("≈%d tokens" % brief_tokens)
			print("")
			print(measured["digest"])
			print("≈%d tokens" % digest_tokens)
		# One look at the public list (no key): the price, and what the model does
		# with an effort level (§18.2).
		var info: Dictionary = {} if mock else BenchEstimate.fetch_model(base_url, model, config)
		# §18.2: what a level sends must not hang on whether this one process could
		# read the list — shards of one suite would record different params.
		if not mock and not dry_run and info.is_empty() and effort != BenchEffort.NORMAL \
				and pinned.is_empty():
			print(("benchmark: OpenRouter's model list could not be read, so what --effort=%s"
				+ " sends to %s is unknown — try again, or pin it with --effort-reasoning=<effort>")
				% [effort, model])
			return EXIT_BAD_INPUT
		var leveled: Dictionary = effort_params(params, effort, model, info, config, pinned)
		if not str(leveled["error"]).is_empty():
			print("benchmark: %s" % leveled["error"])
			return EXIT_BAD_INPUT
		params = leveled["params"]
		if not str(leveled["line"]).is_empty():
			print(leveled["line"])
		if not mock:
			estimate = BenchEstimate.figures(brief_tokens, digest_tokens, seeds.size(),
				float(info.get(BenchEstimate.FIELD_PROMPT, OpenRouterBackend.NO_PRICE)),
				float(info.get(BenchEstimate.FIELD_COMPLETION, OpenRouterBackend.NO_PRICE)), config,
				BenchEffort.output_tokens(effort, config,
					bool(info.get(BenchEstimate.FIELD_DEFAULT_ON, false))),
				int(params[PARAM_MAX_TOKENS]))
			print(BenchEstimate.line(estimate, seeds.size(), model, cap))
	if not estimate.is_empty() and BenchEstimate.preflight_blocks(estimate, cap, args.has("yes")):
		print(BenchEstimate.block_line(estimate))
		if not dry_run:
			return EXIT_ESTIMATE
	if dry_run:
		return EXIT_OK
	# A model that thinks hard answers slowly (§18.2).
	config.timeout_s = maxi(config.timeout_s, int(config.effort_timeout_s.get(effort, 0)))
	var live: ModelBackend = null
	var hooks: Dictionary = {}
	if typesafe:
		live = TypeSafeBackend.new(sent_model, key, base_url, config, cap, requests_text.to_int())
	elif not mock:
		var service: OpenRouterBackend = OpenRouterBackend.new(model, key, base_url, config, cap)
		service.prompt_price = float(estimate[BenchEstimate.FIELD_PROMPT_PRICE])
		service.completion_price = float(estimate[BenchEstimate.FIELD_COMPLETION_PRICE])
		live = service
	if live != null:
		hooks = BenchCache.new(args.get("cache", DEFAULT_CACHE)).hooks(model, params,
			config.prompt_version, config.parser_version, not args.has("fresh"))
	var touched: Array[String] = []
	for seed_value: int in seeds:
		# A mock answers each run afresh, so a shard plays what the whole suite would.
		var backend: ModelBackend = live
		if backend == null:
			backend = MockChoiceBackend.new(choice_mode) if choosing else MockBackend.new(mock_mode)
		var result: Dictionary = BenchRunner.run_seed(db, config, setup, seed_value, backend, params,
			locale, model, suite, out, hooks)
		var fatal: String = str(result[BenchRunner.RESULT_FATAL])
		if not fatal.is_empty():
			print("benchmark: stopped — %s" % fatal)
			_rebuild(out, config, db, touched)
			return int(result[BenchRunner.RESULT_EXIT])
		var entry: BenchEntry = result[BenchRunner.RESULT_ENTRY]
		if entry == null:
			print("benchmark: seed %d — the command log does not reproduce the run" % seed_value)
			return EXIT_REPLAY_MISMATCH
		var policy: ModelPolicy = result[BenchRunner.RESULT_POLICY]
		if policy.model_versions.size() > 1:
			print("benchmark: the service changed the model version during the run (%s)"
				% VERSION_ARROW.join(policy.model_versions))
		if str(result[BenchRunner.RESULT_PATH]).is_empty():
			print("benchmark: could not write %s" % entry.file_name())
			return EXIT_BAD_INPUT
		touched.append(Writer.RUNS_DIR + "/" + entry.file_name())
		_print_run(entry)
	# Parallel shards leave the board to one rebuild after them all.
	if args.has("no-rebuild"):
		return EXIT_OK
	return _rebuild(out, config, db, touched)


## §10.4: every bot of `Policy.ids()` over the seeds, scored like a model.
static func _bots(args: Dictionary[String, String], db: ContentDB, config: BenchConfig,
		setup: RunSetup, suite: String, seeds: Array[int], out: String) -> int:
	var params_id: String = BenchEntry.params_id_of({})
	var touched: Array[String] = []
	for policy_id: String in Policy.ids():
		var model: String = BenchEntry.MODEL_BOT_PREFIX + policy_id
		for seed_value: int in seeds:
			var name: String = BenchEntry.file_name_for(model, params_id, config.prompt_version,
				suite, seed_value)
			var path: String = out.path_join(Writer.RUNS_DIR).path_join(name)
			if args.has("if-missing") and _is_current(path, db.content_hash):
				continue
			var problems: Array[String] = []
			var played: Dictionary = Harness.play(db, seed_value, policy_id, config.max_days,
				false, problems, setup)
			var sim: Simulation = played["sim"]
			if not reproduces(db, seed_value, sim, setup):
				print("benchmark: %s seed %d — the command log does not reproduce the run"
					% [model, seed_value])
				return EXIT_REPLAY_MISMATCH
			var entry: BenchEntry = make_entry(sim, config, model, BenchEntry.BACKEND_BOT, {},
				config.locale, suite, config.max_days)
			if write_entry(out, entry).is_empty():
				print("benchmark: could not write %s" % name)
				return EXIT_BAD_INPUT
			touched.append(Writer.RUNS_DIR + "/" + name)
			_print_run(entry)
	if args.has("no-rebuild"):
		return EXIT_OK
	return _rebuild(out, config, db, touched)


## §16.8: the canary entry — the config's rules with `max_days` at 300 —
## written to its fixture path; the hash is printed.
static func _fixture(db: ContentDB, config: BenchConfig, setup: RunSetup) -> int:
	var seed_value: int = config.suite_seeds(BenchConfig.SUITE_STANDARD)[0]
	var params: Dictionary = build_params({}, config)["params"]
	var max_days: int = config.max_days
	config.max_days = FIXTURE_MAX_DAYS
	var played: Dictionary = play_model(db, config, setup, seed_value,
		MockBackend.new(MockBackend.MODE_CHEAPEST), params, config.locale)
	config.max_days = max_days
	var sim: Simulation = played["sim"]
	if not reproduces(db, seed_value, sim, setup):
		print("benchmark: the fixture's command log does not reproduce its run")
		return EXIT_REPLAY_MISMATCH
	var entry: BenchEntry = make_entry(sim, config, FIXTURE_MODEL, FIXTURE_BACKEND, params,
		config.locale, BenchConfig.SUITE_STANDARD, FIXTURE_MAX_DAYS, played["policy"])
	if write_text(FIXTURE_PATH, entry.to_json()).is_empty():
		print("benchmark: could not write %s" % FIXTURE_PATH)
		return EXIT_BAD_INPUT
	print("benchmark: determinism fixture %s — hash %s" % [FIXTURE_PATH, entry.state_hash])
	return EXIT_OK


## Whether `path` is an entry on the current content.
static func _is_current(path: String, content_hash: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var entry: BenchEntry = BenchEntry.from_json(FileAccess.get_file_as_string(path))
	return entry != null and entry.content_hash == content_hash


## §11.1 step 5: the board rebuilt, the rows this invocation touched printed, and
## a reminder when the current content has no reference rows yet.
static func _rebuild(out: String, config: BenchConfig, db: ContentDB,
		touched: Array[String]) -> int:
	var result: Dictionary = Writer.rebuild(out, config, db.content_hash)
	for skipped: String in result["skipped"]:
		print("benchmark: skipped %s — not an entry" % skipped)
	var has_reference: bool = false
	for row: Dictionary in result["rows"]:
		if str(row["backend"]) == BenchEntry.BACKEND_BOT and bool(row["current"]):
			has_reference = true
		var files: Array = row["entries"]
		var mine: bool = false
		for file: String in touched:
			mine = mine or files.has(file)
		if mine:
			print("benchmark: %s · %s · score %s · %d/%d runs · %d wins" % [row["model"],
				row["suite"], str(row["score"]), int(row["runs"]), int(row["of"]),
				int(row["wins"])])
	if not has_reference:
		print("benchmark: no reference rows on this content — run bench_run.gd -- --bots")
	if not bool(result["ok"]):
		print("benchmark: could not write the leaderboard in %s" % out)
		return EXIT_BAD_INPUT
	return EXIT_OK


## §11.2: one JSON line per finished run (`BenchRunner.run_line`).
static func _print_run(entry: BenchEntry) -> void:
	print(JSON.stringify(BenchRunner.run_line(entry)))
