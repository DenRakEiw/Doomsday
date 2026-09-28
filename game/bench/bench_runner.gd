class_name BenchRunner
extends RefCounted
## One seed of a benchmark, played by a model to its end (docs/specs/benchmark.md
## §11.1 items 4–5, §19.3): the simulation, the model policy, the day loop, the
## replay check and the entry written. The tool (`tools/bench/bench_run.gd`) and
## the game's headless worker (`game/bench/bench_worker.gd`, §19.4) both call it,
## so a run plays and records the same wherever it was started. No autoload
## named.

## §19.4: after `--`, the switch that makes the game a headless benchmark
## worker for the job folder it names. Here, not on the worker's scene script,
## because `Settings` checks it before anything else runs.
const WORKER_ARG: String = "--bench-worker="

## §11.3's exit codes — the tool's and the worker's.
const EXIT_OK: int = 0
const EXIT_BAD_INPUT: int = 1
const EXIT_REPLAY_MISMATCH: int = 3
const EXIT_REFUSED: int = 4
const EXIT_UNAVAILABLE: int = 5
const EXIT_COST_CAP: int = 6
const EXIT_ESTIMATE: int = 7

## §19.4: why a benchmark stopped, as `progress.jsonl` and the list name it.
const STOP_AUTH: String = "auth"
const STOP_CREDITS: String = "credits"
const STOP_FORBIDDEN: String = "forbidden"
const STOP_BAD_REQUEST: String = "bad_request"
const STOP_UNAVAILABLE: String = "unavailable"
const STOP_COST_CAP: String = "cost_cap"
const STOP_ERROR: String = "error"
const STOP_REASONS: Array[String] = [STOP_AUTH, STOP_CREDITS, STOP_FORBIDDEN, STOP_BAD_REQUEST,
	STOP_UNAVAILABLE, STOP_COST_CAP, STOP_ERROR]

## `run_seed`'s answer.
const RESULT_ENTRY: String = "entry"
const RESULT_FATAL: String = "fatal"
const RESULT_EXIT: String = "exit"
const RESULT_PATH: String = "path"
const RESULT_POLICY: String = "policy"

const PARAM_TEMPERATURE: String = "temperature"
const PARAM_MAX_TOKENS: String = "max_completion_tokens"
const PARAM_JSON_MODE: String = "json_mode"
const PARAM_REASONING: String = "reasoning"
const PARAM_TOP_P: String = "top_p"
## `top_p` when it is not given.
const NO_TOP_P: float = -1.0

## Where entries go under an output folder (the board's layout, §10.3).
const RUNS_DIR: String = "runs"
## Several versions within one run are joined with this (§17.7).
const VERSION_JOIN: String = "+"
const VERSION_SETTING: String = "application/config/version"
const TEMP_SUFFIX: String = ".tmp"


## The job folder a `--bench-worker=` switch names among `args`; "" for a
## launch that is not a worker's.
static func worker_job_dir(args: PackedStringArray) -> String:
	for arg: String in args:
		if arg.begins_with(WORKER_ARG):
			return arg.trim_prefix(WORKER_ARG)
	return ""


## The params a chat run sends when nothing overrides them (§10.2): the config's
## defaults, no reasoning, no `top_p`.
static func default_params(config: BenchConfig) -> Dictionary:
	return {
		PARAM_TEMPERATURE: config.temperature,
		PARAM_MAX_TOKENS: config.max_completion_tokens,
		PARAM_JSON_MODE: config.json_mode,
		PARAM_REASONING: "",
		PARAM_TOP_P: NO_TOP_P,
	}


## §18.2: the params with the effort level applied, and the line that says what
## it sends — or an error when the model's public list says it takes no
## reasoning parameter (a row called "High" that is a normal run would lie).
## `info` is `BenchEstimate.read_model`'s (empty: unknown); `pinned` is the
## effort resolved once for every process of one run (`--effort-reasoning`, or
## the job's `reasoning`), sent as it is. At normal the line warns about a model
## that reasons by default: its answers may be cut short at the limit.
static func effort_params(params: Dictionary, effort: String, model: String, info: Dictionary,
		config: BenchConfig, pinned: String = "") -> Dictionary:
	if effort == BenchEffort.NORMAL:
		var warning: String = ""
		if bool(info.get(BenchEstimate.FIELD_DEFAULT_ON, false)):
			warning = ("benchmark: %s reasons by default (OpenRouter's model list) — at normal its"
				+ " limit of %d tokens may cut answers short; --effort=high gives it room") % [
				model, int(params.get(PARAM_MAX_TOKENS, config.max_completion_tokens))]
		return {"params": params, "error": "", "line": warning}
	if bool(info.get(BenchEstimate.FIELD_LISTED, false)) \
			and not bool(info.get(BenchEstimate.FIELD_REASONING, false)):
		return {"params": {}, "line": "", "error": ("%s takes no reasoning parameter (OpenRouter's"
			+ " model list) — play it with --effort=normal") % model}
	var supported: Array[String] = []
	if typeof(info.get(BenchEstimate.FIELD_EFFORTS)) == TYPE_ARRAY:
		supported.assign(info[BenchEstimate.FIELD_EFFORTS])
	var applied: Dictionary = BenchEffort.apply(params, effort, config, supported,
		BenchEstimate.effort_floor(info), pinned)
	var note: String = ""
	if not pinned.is_empty():
		note = " (pinned by --effort-reasoning)"
	elif supported.is_empty():
		note = (" (the model's efforts are unknown; OpenRouter maps an effort a model lacks to"
			+ " its nearest)")
	var line: String = "benchmark: effort %s → reasoning %s, max_completion_tokens %d%s" % [
		effort, applied[PARAM_REASONING], int(applied[PARAM_MAX_TOKENS]), note]
	return {"params": applied, "error": "", "line": line}


## One seed played by a model to its end, `max_days` or a fatal stop (§11.1
## step 4): `{"sim": Simulation, "policy": ModelPolicy}`. `hooks` are the cache's
## (`BenchCache.hooks`), empty for a mock. `on_decision(policy: ModelPolicy,
## sim: Simulation)`, when valid, is called after every day on which the policy
## decided — the worker's progress line (§19.4).
static func play_model(db: ContentDB, config: BenchConfig, setup: RunSetup, seed_value: int,
		backend: ModelBackend, params: Dictionary, locale: String,
		hooks: Dictionary = {}, on_decision: Callable = Callable()) -> Dictionary:
	var sim: Simulation = Simulation.create(db, seed_value, setup)
	var policy: ModelPolicy = ModelPolicy.new(backend, config, params, locale)
	policy.setup(db, Policy.seed_for(seed_value))
	if hooks.has("read"):
		policy.cache_read = hooks["read"]
	if hooks.has("write"):
		policy.cache_write = hooks["write"]
	var problems: Array[String] = []
	var decided: int = 0
	# One day at a time, so a fatal stop ends the run at once.
	while sim.world.outcome == World.Outcome.NONE and sim.world.day < config.max_days \
			and policy.fatal.is_empty():
		BenchHarness.advance(sim, policy, sim.world.day + 1, false, problems)
		if on_decision.is_valid() and policy.decisions.size() > decided:
			decided = policy.decisions.size()
			on_decision.call(policy, sim)
	return {"sim": sim, "policy": policy}


## Whether the command log replays to the same state (§11.1 step 4).
static func reproduces(db: ContentDB, seed_value: int, sim: Simulation, setup: RunSetup) -> bool:
	var replayed: Simulation = Simulation.replay(db, seed_value, sim.command_log, sim.world.day,
		setup)
	return replayed != null and replayed.state_hash() == sim.state_hash()


## A seed from start to written entry (§11.1 items 4–5, §19.3): `{"entry":
## BenchEntry or null, "fatal": String, "exit": int, "path": String, "policy":
## ModelPolicy}`. A fatal
## stop of the backend writes nothing (`fatal` says why, `exit` is §11.3's);
## a run whose log does not replay writes nothing either (`exit` 3).
static func run_seed(db: ContentDB, config: BenchConfig, setup: RunSetup, seed_value: int,
		backend: ModelBackend, params: Dictionary, locale: String, model: String, suite: String,
		out: String, hooks: Dictionary = {}, on_decision: Callable = Callable()) -> Dictionary:
	var result: Dictionary = {RESULT_ENTRY: null, RESULT_FATAL: "", RESULT_EXIT: EXIT_OK,
		RESULT_PATH: "", RESULT_POLICY: null}
	var played: Dictionary = play_model(db, config, setup, seed_value, backend, params, locale,
		hooks, on_decision)
	var policy: ModelPolicy = played["policy"]
	result[RESULT_POLICY] = policy
	if not policy.fatal.is_empty():
		result[RESULT_FATAL] = policy.fatal
		result[RESULT_EXIT] = exit_for(policy.fatal)
		return result
	var sim: Simulation = played["sim"]
	if not reproduces(db, seed_value, sim, setup):
		result[RESULT_EXIT] = EXIT_REPLAY_MISMATCH
		return result
	var entry: BenchEntry = make_entry(sim, config, model, backend.backend_id(), params, locale,
		suite, config.max_days, policy)
	result[RESULT_ENTRY] = entry
	result[RESULT_PATH] = write_entry(out, entry)
	if str(result[RESULT_PATH]).is_empty():
		result[RESULT_EXIT] = EXIT_BAD_INPUT
	return result


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
	return write_text(out.path_join(RUNS_DIR).path_join(entry.file_name()), entry.to_json())


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


## The brief and the day-0 digest of a seed, in the run's language — what
## `--dry-run` prints and the estimate measures — the tool's and, since S6.12g,
## the benchmark modal's (§19.8 item 6).
static func measure(db: ContentDB, config: BenchConfig, setup: RunSetup, seed_value: int,
		locale: String) -> Dictionary:
	var previous: String = _use_locale(locale)
	var brief: String = BenchPrompt.brief(db, setup, config)
	var sim: Simulation = Simulation.create(db, seed_value, setup)
	var digest: String = BenchPrompt.digest_text(
		BenchDigest.build(sim, BenchDigest.new_memory(), config), db)
	_use_locale(previous)
	return {"brief": brief, "digest": digest}


## A decision model's day-0 request of a seed (§17.9): its `rules` and
## `situation`, the request body for `model`, and the three token measures the
## dry run checks against the service's limits.
static func measure_choice(db: ContentDB, config: BenchConfig, setup: RunSetup, seed_value: int,
		locale: String, model: String) -> Dictionary:
	var previous: String = _use_locale(locale)
	var rules: String = BenchPrompt.rules(db, setup, config)
	var sim: Simulation = Simulation.create(db, seed_value, setup)
	var digest: BenchDigest = BenchDigest.build(sim, BenchDigest.new_memory(), config)
	var situation: String = BenchPrompt.digest_text(digest, db, false)
	var plan: BenchChoicePlan = BenchChoice.plan(sim, digest, rules, situation, config)
	_use_locale(previous)
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


## The exit code a backend's fatal reason stands for (§11.3).
static func exit_for(fatal: String) -> int:
	if fatal.begins_with(OpenRouterBackend.FATAL_UNAVAILABLE):
		return EXIT_UNAVAILABLE
	if fatal.begins_with(OpenRouterBackend.FATAL_COST_CAP) \
			or fatal.begins_with(TypeSafeBackend.FATAL_REQUEST_CAP):
		return EXIT_COST_CAP
	return EXIT_REFUSED


## The reason §19.4 names for a backend's fatal text: one of `STOP_REASONS`.
static func stop_reason(fatal: String) -> String:
	for reason: String in [STOP_AUTH, STOP_CREDITS, STOP_FORBIDDEN, STOP_BAD_REQUEST,
			STOP_UNAVAILABLE, STOP_COST_CAP]:
		if fatal.begins_with(reason):
			return reason
	if fatal.begins_with(TypeSafeBackend.FATAL_REQUEST_CAP):
		return STOP_COST_CAP
	return STOP_ERROR


## §11.2: one finished run as the line the tool prints and the worker records; a
## decision model's also names the version its service reported (§17.9).
static func run_line(entry: BenchEntry) -> Dictionary:
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
	return line


## Switches the language to `locale` and answers the one before. Only when it
## differs: in the game every switch rebuilds every open screen.
static func _use_locale(locale: String) -> String:
	var previous: String = TranslationServer.get_locale()
	if previous != locale:
		TranslationServer.set_locale(locale)
	return previous
