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
##         [--effort=normal|high|ultra | --reasoning=low|medium|high] [--top-p=<f>]
##         [--base-url=<url>] [--key-env=<VAR>] [--max-cost=<usd>] [--max-requests=<n>] [--yes]
##         [--out=<dir=res://benchmark>] [--cache=<dir=res://benchmark/cache>] [--fresh]
##         [--data=<root=res://data>] [--dry-run] [--no-rebuild]
##     … -- --bots [--suite=…] [--seeds=a..b] [--out=<dir>] [--if-missing] [--no-rebuild]
##     … -- --rebuild [--out=<dir>]
##     … -- --determinism-fixture
##
## A model id beginning with `typesafe/` is a decision model (§17): TypeSafe's
## backend, one request of choice questions per decision, the chat-only flags
## refused. The key comes from the environment only (`OPENROUTER_API_KEY` or
## `TYPESAFE_API_KEY`, or the variable `--key-env` names) and is never printed.
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
## and timeout. The level goes into the params — a row of its own — and into the
## entry. `--reasoning` stays the low-level form: that effort as it is, nothing else.

const Harness := preload("res://tools/sim_harness.gd")
const Cache := preload("res://tools/bench/bench_cache.gd")
const Backend := preload("res://tools/bench/open_router_backend.gd")
const TypeSafe := preload("res://tools/bench/typesafe_backend.gd")
const Estimate := preload("res://tools/bench/bench_estimate.gd")
const Writer := preload("res://tools/bench/leaderboard_writer.gd")

const EXIT_OK: int = 0
const EXIT_BAD_INPUT: int = 1
const EXIT_REPLAY_MISMATCH: int = 3
const EXIT_REFUSED: int = 4
const EXIT_UNAVAILABLE: int = 5
const EXIT_COST_CAP: int = 6
const EXIT_ESTIMATE: int = 7

const DEFAULT_OUT: String = "res://benchmark"
const DEFAULT_CACHE: String = "res://benchmark/cache"
const BACKEND_OPENROUTER: String = "openrouter"
const BACKEND_TYPESAFE: String = "typesafe"
## A decision model takes none of these (§17.7).
const CHAT_FLAGS: Array[String] = ["temperature", "max-tokens", "json-mode", "reasoning",
	"top-p", "effort"]
## Several versions within one run are joined with this (§17.7).
const VERSION_JOIN: String = "+"
const VERSION_ARROW: String = " → "
const REASONING_LEVELS: Array[String] = ["low", "medium", "high"]
const LOCALES: Array[String] = ["en", "de"]
const SEED_RANGE: String = ".."
const VERSION_SETTING: String = "application/config/version"
## §16.8: the cross-platform canary — `mock:cheapest`, the standard suite's first
## seed, 300 days, recorded on Windows.
const FIXTURE_PATH: String = "res://tests/fixtures/bench/determinism_entry.json"
const FIXTURE_MAX_DAYS: int = 300
const FIXTURE_MODEL: String = "mock"
const FIXTURE_BACKEND: String = "mock:cheapest"
const TEMP_SUFFIX: String = ".tmp"

const PARAM_TEMPERATURE: String = "temperature"
const PARAM_MAX_TOKENS: String = "max_completion_tokens"
const PARAM_JSON_MODE: String = "json_mode"
const PARAM_REASONING: String = "reasoning"
const PARAM_TOP_P: String = "top_p"
## `top_p` when it is not given.
const NO_TOP_P: float = -1.0
const ARG_TRUE: String = "true"
const ARG_FALSE: String = "false"


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
## `{"params": Dictionary, "error": String, "effort": String}`. The effort level
## (§18) is only named here — `BenchEffort.apply` adds it to the params once the
## model's supported efforts are known.
static func build_params(args: Dictionary[String, String], config: BenchConfig) -> Dictionary:
	var params: Dictionary = {
		PARAM_TEMPERATURE: config.temperature,
		PARAM_MAX_TOKENS: config.max_completion_tokens,
		PARAM_JSON_MODE: config.json_mode,
		PARAM_REASONING: "",
		PARAM_TOP_P: NO_TOP_P,
	}
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
	return {"params": params, "error": "", "effort": effort}


static func _bad_params(reason: String) -> Dictionary:
	return {"params": {}, "error": reason, "effort": BenchEffort.NORMAL}


## §18.2: the params with the effort level applied, and the line that says what
## it sends — or an error when the model's public list says it takes no
## reasoning parameter (a row called "High" that is a normal run would lie).
## `info` is `Estimate.read_model`'s (empty: unknown).
static func effort_params(params: Dictionary, effort: String, model: String, info: Dictionary,
		config: BenchConfig) -> Dictionary:
	if effort == BenchEffort.NORMAL:
		return {"params": params, "error": "", "line": ""}
	if bool(info.get(Estimate.FIELD_LISTED, false)) 			and not bool(info.get(Estimate.FIELD_REASONING, false)):
		return {"params": {}, "line": "", "error": ("%s takes no reasoning parameter (OpenRouter's"
			+ " model list) — play it with --effort=normal") % model}
	var supported: Array[String] = []
	if typeof(info.get(Estimate.FIELD_EFFORTS)) == TYPE_ARRAY:
		supported.assign(info[Estimate.FIELD_EFFORTS])
	var applied: Dictionary = BenchEffort.apply(params, effort, config, supported)
	var line: String = "benchmark: effort %s → reasoning %s, max_completion_tokens %d%s" % [
		effort, applied[PARAM_REASONING], int(applied[PARAM_MAX_TOKENS]),
		"" if not supported.is_empty() else " (the model's efforts are unknown; OpenRouter maps"
			+ " an effort a model lacks to its nearest)"]
	return {"params": applied, "error": "", "line": line}


## One seed played by a model to its end, `max_days` or a fatal stop (§11.1
## step 4): `{"sim": Simulation, "policy": ModelPolicy}`. `hooks` are the cache's
## (`bench_cache.gd`'s `hooks`), empty for a mock.
static func play_model(db: ContentDB, config: BenchConfig, setup: RunSetup, seed_value: int,
		backend: ModelBackend, params: Dictionary, locale: String,
		hooks: Dictionary = {}) -> Dictionary:
	var sim: Simulation = Simulation.create(db, seed_value, setup)
	var policy: ModelPolicy = ModelPolicy.new(backend, config, params, locale)
	policy.setup(db, Policy.seed_for(seed_value))
	if hooks.has("read"):
		policy.cache_read = hooks["read"]
	if hooks.has("write"):
		policy.cache_write = hooks["write"]
	var problems: Array[String] = []
	# One day at a time, so a fatal stop ends the run at once.
	while sim.world.outcome == World.Outcome.NONE and sim.world.day < config.max_days 			and policy.fatal.is_empty():
		Harness.advance(sim, policy, sim.world.day + 1, false, problems)
	return {"sim": sim, "policy": policy}


## Whether the command log replays to the same state (§11.1 step 4).
static func reproduces(db: ContentDB, seed_value: int, sim: Simulation, setup: RunSetup) -> bool:
	var replayed: Simulation = Simulation.replay(db, seed_value, sim.command_log, sim.world.day,
		setup)
	return replayed != null and replayed.state_hash() == sim.state_hash()


## A finished run as its entry (§10.2). `policy` null is a bot's run.
static func make_entry(sim: Simulation, config: BenchConfig, model: String, backend: String,
		params: Dictionary, locale: String, suite: String, max_days: int,
		policy: ModelPolicy = null) -> BenchEntry:
	var world: World = sim.world
	var entry: BenchEntry = BenchEntry.new()
	entry.model = model
	entry.backend = backend
	entry.params = params.duplicate(true)
	entry.params_id = BenchEntry.params_id_of(params)
	entry.effort = str(params.get(BenchEffort.PARAM, ""))
	entry.prompt_version = config.prompt_version
	entry.parser_version = config.parser_version
	entry.locale = locale
	entry.suite = suite
	entry.game_version = str(ProjectSettings.get_setting(VERSION_SETTING, ""))
	entry.content_hash = sim.db.content_hash
	entry.seed_value = int(world.rng.seed_string())
	entry.setup = world.setup.duplicate_setup()
	entry.max_days = max_days
	entry.interval_days = config.interval_days
	entry.recorded = Time.get_datetime_string_from_system(true)
	if world.outcome == World.Outcome.NONE:
		entry.outcome = BenchEntry.OUTCOME_TIMEOUT
	else:
		entry.outcome = World.OUTCOME_IDS[world.outcome]
		entry.variant = str(EndingResolver.resolve(world, sim.db)[EndingResolver.KEY_VARIANT])
	entry.days = world.day - world.origin_day if world.origin_day >= 0 else world.day
	entry.end_day = world.day
	entry.score = BenchScore.run_score(entry.outcome, entry.days, max_days, config)
	entry.state_hash = world.state_hash()
	entry.commands = sim.command_log.duplicate()
	if policy != null:
		entry.calls = policy.calls
		entry.cached_calls = policy.cached_calls
		entry.invalid_answers = policy.invalid_answers
		entry.rejected_actions = policy.rejected_actions
		entry.tokens_in = policy.tokens_in
		entry.tokens_out = policy.tokens_out
		entry.cost_usd = policy.cost_usd
		entry.budget_exhausted = policy.budget_exhausted
		entry.decisions = policy.decisions.duplicate()
		entry.model_version = VERSION_JOIN.join(policy.model_versions)
	return entry


## Writes an entry under `<out>/runs/`, to a temporary name first. Returns the
## path, or "" when it could not be written.
static func write_entry(out: String, entry: BenchEntry) -> String:
	return write_text(out.path_join(Writer.RUNS_DIR).path_join(entry.file_name()), entry.to_json())


static func write_text(path: String, text: String) -> String:
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
		return ""
	var temp: String = path + TEMP_SUFFIX
	var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(text)
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return path if DirAccess.rename_absolute(temp, path) == OK else ""


## The exit code a backend's fatal reason stands for (§11.3).
static func exit_for(fatal: String) -> int:
	if fatal.begins_with(Backend.FATAL_UNAVAILABLE):
		return EXIT_UNAVAILABLE
	if fatal.begins_with(Backend.FATAL_COST_CAP) or fatal.begins_with(TypeSafe.FATAL_REQUEST_CAP):
		return EXIT_COST_CAP
	return EXIT_REFUSED


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
		longest = maxi(longest, Estimate.tokens(JSON.stringify(plan.questions[question]).length(),
			config))
	return {
		"rules": rules,
		"situation": situation,
		"body": body,
		"state_tokens": Estimate.tokens(JSON.stringify(plan.state).length(), config),
		"question_tokens": longest,
		"request_tokens": Estimate.tokens(JSON.stringify(body).length(), config),
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
	var locale: String = args.get("locale", config.locale)
	if not LOCALES.has(locale):
		print("benchmark: --locale is en or de")
		return EXIT_BAD_INPUT
	var base_url: String = args.get("base-url",
		config.typesafe_base_url if typesafe else config.base_url)
	if not mock and Backend.parse_base_url(base_url).is_empty():
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
		config.typesafe_key_env if typesafe else config.key_env)
	var key: String = ""
	if not mock and not dry_run:
		key = OS.get_environment(key_env)
		if key.is_empty():
			print("benchmark: set %s in the environment" % key_env)
			return EXIT_BAD_INPUT
	# What is sent as `model`: a decision model's id after its prefix (§17.7).
	var sent_model: String = model.trim_prefix(config.typesafe_model_prefix) if typesafe \
		else model
	var estimate: Dictionary = {}
	if choosing:
		var request: Dictionary = measure_choice(db, config, setup, seeds[0], locale, sent_model)
		var rules_tokens: int = Estimate.tokens(str(request["rules"]).length(), config)
		var situation_tokens: int = Estimate.tokens(str(request["situation"]).length(), config)
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
			estimate = Estimate.choice_figures(rules_tokens, situation_tokens, seeds.size(), config)
			print(Estimate.choice_line(estimate, seeds.size(), model, cap, requests_text.to_int(),
				config))
	else:
		var measured: Dictionary = measure(db, config, setup, seeds[0], locale)
		var brief_tokens: int = Estimate.tokens(str(measured["brief"]).length(), config)
		var digest_tokens: int = Estimate.tokens(str(measured["digest"]).length(), config)
		if dry_run:
			print(measured["brief"])
			print("≈%d tokens" % brief_tokens)
			print("")
			print(measured["digest"])
			print("≈%d tokens" % digest_tokens)
		# One look at the public list (no key): the price, and what the model does
		# with an effort level (§18.2).
		var info: Dictionary = {} if mock else Estimate.fetch_model(base_url, model, config)
		var leveled: Dictionary = effort_params(params, effort, model, info, config)
		if not str(leveled["error"]).is_empty():
			print("benchmark: %s" % leveled["error"])
			return EXIT_BAD_INPUT
		params = leveled["params"]
		if not str(leveled["line"]).is_empty():
			print(leveled["line"])
		if not mock:
			estimate = Estimate.figures(brief_tokens, digest_tokens, seeds.size(),
				float(info.get(Estimate.FIELD_PROMPT, Backend.NO_PRICE)),
				float(info.get(Estimate.FIELD_COMPLETION, Backend.NO_PRICE)), config,
				BenchEffort.output_tokens(effort, config), int(params[PARAM_MAX_TOKENS]))
			print(Estimate.line(estimate, seeds.size(), model, cap))
	if not estimate.is_empty() and Estimate.preflight_blocks(estimate, cap, args.has("yes")):
		print(Estimate.block_line(estimate))
		if not dry_run:
			return EXIT_ESTIMATE
	if dry_run:
		return EXIT_OK
	# A model that thinks hard answers slowly (§18.2).
	config.timeout_s = maxi(config.timeout_s, int(config.effort_timeout_s.get(effort, 0)))
	var live: ModelBackend = null
	var hooks: Dictionary = {}
	if typesafe:
		live = TypeSafe.new(sent_model, key, base_url, config, cap, requests_text.to_int())
	elif not mock:
		var service: Backend = Backend.new(model, key, base_url, config, cap)
		service.prompt_price = float(estimate[Estimate.FIELD_PROMPT_PRICE])
		service.completion_price = float(estimate[Estimate.FIELD_COMPLETION_PRICE])
		live = service
	if live != null:
		hooks = Cache.new(args.get("cache", DEFAULT_CACHE)).hooks(model, params,
			config.prompt_version, config.parser_version, not args.has("fresh"))
	var touched: Array[String] = []
	for seed_value: int in seeds:
		# A mock answers each run afresh, so a shard plays what the whole suite would.
		var backend: ModelBackend = live
		if backend == null:
			backend = MockChoiceBackend.new(choice_mode) if choosing else MockBackend.new(mock_mode)
		var played: Dictionary = play_model(db, config, setup, seed_value, backend, params,
			locale, hooks)
		var policy: ModelPolicy = played["policy"]
		if not policy.fatal.is_empty():
			print("benchmark: stopped — %s" % policy.fatal)
			_rebuild(out, config, db, touched)
			return exit_for(policy.fatal)
		var sim: Simulation = played["sim"]
		if not reproduces(db, seed_value, sim, setup):
			print("benchmark: seed %d — the command log does not reproduce the run" % seed_value)
			return EXIT_REPLAY_MISMATCH
		var entry: BenchEntry = make_entry(sim, config, model, backend.backend_id(), params,
			locale, suite, config.max_days, policy)
		if policy.model_versions.size() > 1:
			print("benchmark: the service changed the model version during the run (%s)"
				% VERSION_ARROW.join(policy.model_versions))
		var path: String = write_entry(out, entry)
		if path.is_empty():
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


## §11.2: one JSON line per finished run; a decision model's also names the
## version its service reported (§17.9).
static func _print_run(entry: BenchEntry) -> void:
	var line: Dictionary = {
		"model": entry.model,
		"seed": entry.seed_value,
		"outcome": entry.outcome,
		"days": entry.days,
		"score": BenchEntry.rounded_score(entry.score),
		"calls": entry.calls,
		"cached_calls": entry.cached_calls,
		"invalid_answers": entry.invalid_answers,
		"rejected_actions": entry.rejected_actions,
		"cost_usd": entry.cost_usd,
		"file": entry.file_name(),
	}
	if not entry.model_version.is_empty():
		line["model_version"] = entry.model_version
	print(JSON.stringify(line))
