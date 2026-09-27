extends RefCounted
## The judging half of the replay verifier (docs/specs/benchmark.md §16.4): one
## run file's bytes in, one verification record out. Pure — no files, no board,
## no output — so the tests call it directly and `verify_runs.gd` only walks the
## board around it.
##
## A run file is untrusted data. It is read through `BenchEntry.from_dict`, which
## never crashes; nothing in it is executed or loaded as a resource; a refused
## command is bad data, not a programming error, so the replay here never
## `push_error`s (CLAUDE.md, *Errors*). A record's `detail` is built from ids and
## numbers only — never from the file's free strings (the model name above all).
##
## A tool, so no `class_name`; `verify_runs.gd` and the tests preload it.

const VerifyRecord := preload("res://tools/bench/verify_record.gd")
const Writer := preload("res://tools/bench/leaderboard_writer.gd")

## §16.4's reasons, in the order they are checked; the first that fails is the
## record's.
const REASON_UNREADABLE: String = "unreadable"
const REASON_FILE_NAME: String = "file_name"
const REASON_RULES: String = "rules"
const REASON_CONTENT: String = "content"
const REASON_REFUSED: String = "refused"
const REASON_OUTCOME: String = "outcome"
const REASON_DAYS: String = "days"
const REASON_SCORE: String = "score"
const REASON_UNFINISHED: String = "unfinished"
const REASON_HASH: String = "hash"
const REASONS: Array[String] = [REASON_UNREADABLE, REASON_FILE_NAME, REASON_RULES,
	REASON_CONTENT, REASON_REFUSED, REASON_OUTCOME, REASON_DAYS, REASON_SCORE,
	REASON_UNFINISHED, REASON_HASH]

## The keys of `check`'s `context`: the game checkout a record names.
const CONTEXT_COMMIT: String = "game_commit"
const CONTEXT_VERSION: String = "game_version"
const CONTEXT_CHECKED: String = "checked"

## An entry's score is written to one decimal, so a true one lies within half a
## step of the replay's; the slack absorbs the float arithmetic.
const SCORE_TOLERANCE: float = 0.05
const SCORE_SLACK: float = 0.000001
const LOCALES: Array[String] = ["en", "de"]
const RUNS_PREFIX: String = "runs/"


## One run file judged: `bytes` as they were read, `file_name` its name in
## `runs/` (already checked against §16.4's pattern), `config` the benchmark's
## rules on this checkout, `db` its content, `context` the `CONTEXT_*` keys.
static func check(bytes: PackedByteArray, file_name: String, config: BenchConfig,
		db: ContentDB, context: Dictionary) -> VerifyRecord:
	var record: VerifyRecord = _record(file_name, Writer.sha256_hex(bytes), db, context)
	if bytes.size() > config.global_max_run_bytes:
		return _reject(record, REASON_UNREADABLE, _oversize(bytes.size(), config))
	var entry: BenchEntry = BenchEntry.from_bytes(bytes)
	if entry == null:
		return _reject(record, REASON_UNREADABLE, BenchEntry.last_error)
	if file_name != entry.file_name():
		return _reject(record, REASON_FILE_NAME, "the file name is not the entry's own")
	var broken: String = rules_broken(entry, config)
	if not broken.is_empty():
		return _reject(record, REASON_RULES, broken)
	if entry.content_hash != db.content_hash:
		return _reject(record, REASON_CONTENT, "played on other content than this checkout's")
	return _judge_replay(record, entry, config, db)


## The record of a file above the size limit, judged without reading it.
static func unread(file_name: String, sha256: String, size: int, config: BenchConfig,
		db: ContentDB, context: Dictionary) -> VerifyRecord:
	return _reject(_record(file_name, sha256, db, context), REASON_UNREADABLE,
		_oversize(size, config))


## The canary (§16.8): the entry judged under its own §10.2 name — the fixture's
## file name is not one — with the config's `max_days` set to the entry's. Its
## `verified` says whether this machine reproduces the recorded run.
static func check_canary(bytes: PackedByteArray, config: BenchConfig, db: ContentDB,
		context: Dictionary) -> VerifyRecord:
	var entry: BenchEntry = BenchEntry.from_bytes(bytes)
	if entry == null:
		return check(bytes, "", config, db, context)
	var max_days: int = config.max_days
	config.max_days = entry.max_days
	var record: VerifyRecord = check(bytes, entry.file_name(), config, db, context)
	config.max_days = max_days
	return record


## The first benchmark rule the entry breaks on this checkout (§16.4, `rules`),
## as a short line of ids and numbers; "" when it keeps them all.
static func rules_broken(entry: BenchEntry, config: BenchConfig) -> String:
	var wanted: RunSetup = RunSetup.from_dict(config.setup)
	if wanted == null or JSON.stringify(entry.setup.to_dict(), "", true) \
			!= JSON.stringify(wanted.to_dict(), "", true):
		return "the setup is not the benchmark's"
	if entry.max_days != config.max_days:
		return "max_days %d is not %d" % [entry.max_days, config.max_days]
	if entry.interval_days != config.interval_days:
		return "interval_days %d is not %d" % [entry.interval_days, config.interval_days]
	var seeds: Array[int] = config.suite_seeds(entry.suite)
	if seeds.is_empty():
		return "the suite is not one of the benchmark's"
	if not seeds.has(entry.seed_value):
		return "seed %d is not in its suite" % entry.seed_value
	if not LOCALES.has(entry.locale):
		return "the locale is not en or de"
	if entry.prompt_version > config.prompt_version:
		return "prompt_version %d is above %d" % [entry.prompt_version, config.prompt_version]
	if entry.parser_version > config.parser_version:
		return "parser_version %d is above %d" % [entry.parser_version, config.parser_version]
	if entry.params_id != BenchEntry.params_id_of(entry.params):
		return "params_id is not the hash of params"
	# §18: the effort a list shows is the one the run was played with.
	if entry.effort != str(entry.params.get(BenchEffort.PARAM, "")):
		return "the effort is not the one in params"
	# …and the params are what that level sends: a run called Ultra that thought
	# like a normal one would lie.
	var level_broken: String = BenchEffort.params_broken(entry.params, entry.effort, config)
	if not level_broken.is_empty():
		return level_broken
	if entry.model.begins_with(BenchEntry.MODEL_BOT_PREFIX) != entry.is_bot():
		return "a bot model needs the bot backend, and only a bot model has it"
	if entry.end_day > config.max_days:
		return "end_day %d is above max_days %d" % [entry.end_day, config.max_days]
	var day: int = 0
	var on_day: int = 0
	for i: int in entry.commands.size():
		var command_day: int = entry.commands[i].day
		if command_day < day:
			return "command %d is out of day order" % i
		if command_day > entry.end_day:
			return "command %d is after end_day %d" % [i, entry.end_day]
		on_day = on_day + 1 if command_day == day else 1
		day = command_day
		if on_day > Policy.MAX_COMMANDS_PER_DAY:
			return "day %d has more than %d commands" % [day, Policy.MAX_COMMANDS_PER_DAY]
	return ""


## The entry's commands played again from its seed: each on its day, then a tick,
## until `end_day` or an outcome. `{"sim": Simulation, "refused": String}` —
## `refused` names the day and type of the first command the game refused (the
## replay stops there), "" when none was.
static func replay(db: ContentDB, entry: BenchEntry) -> Dictionary:
	var sim: Simulation = Simulation.create(db, entry.seed_value, entry.setup)
	var next: int = 0
	while true:
		while next < entry.commands.size() and entry.commands[next].day == sim.world.day:
			var command: Command = entry.commands[next]
			next += 1
			if not sim.apply(command).ok:
				return {"sim": sim, "refused": "day %d: %s was refused" % [sim.world.day,
					command.type_id()]}
		if sim.world.day >= entry.end_day or sim.world.outcome != World.Outcome.NONE:
			break
		if not sim.tick():
			break
	return {"sim": sim, "refused": ""}


static func _judge_replay(record: VerifyRecord, entry: BenchEntry, config: BenchConfig,
		db: ContentDB) -> VerifyRecord:
	var played: Dictionary = replay(db, entry)
	if not str(played["refused"]).is_empty():
		return _reject(record, REASON_REFUSED, str(played["refused"]))
	var sim: Simulation = played["sim"]
	var world: World = sim.world
	var finished: bool = world.outcome != World.Outcome.NONE
	record.state_hash = sim.state_hash()
	record.outcome = World.OUTCOME_IDS[world.outcome] if finished else BenchEntry.OUTCOME_TIMEOUT
	record.end_day = world.day
	record.days = world.day - world.origin_day if world.origin_day >= 0 else world.day
	var score: float = BenchScore.run_score(record.outcome, record.days, entry.max_days, config)
	record.score = BenchEntry.rounded_score(score)
	if record.outcome != entry.outcome:
		return _reject(record, REASON_OUTCOME, "the replay ends in %s" % record.outcome)
	if record.end_day != entry.end_day or record.days != entry.days:
		return _reject(record, REASON_DAYS,
			"the replay stops on day %d after %d days; the entry says day %d after %d days"
			% [record.end_day, record.days, entry.end_day, entry.days])
	if absf(score - entry.score) > SCORE_TOLERANCE + SCORE_SLACK:
		return _reject(record, REASON_SCORE, "the replay scores %.1f; the entry says %.1f"
			% [score, entry.score])
	if not finished and entry.end_day < config.max_days:
		return _reject(record, REASON_UNFINISHED, "no outcome on day %d, before max_days %d"
			% [entry.end_day, config.max_days])
	if record.state_hash != entry.state_hash:
		return _reject(record, REASON_HASH, "the replay's state hash is not the entry's")
	record.verified = true
	record.reason = ""
	record.detail = ""
	return record


static func _record(file_name: String, sha256: String, db: ContentDB,
		context: Dictionary) -> VerifyRecord:
	var record: VerifyRecord = VerifyRecord.new()
	record.file = RUNS_PREFIX + file_name
	record.sha256 = sha256
	record.game_commit = str(context.get(CONTEXT_COMMIT, ""))
	record.game_version = str(context.get(CONTEXT_VERSION, ""))
	record.content_hash = db.content_hash
	record.checked = str(context.get(CONTEXT_CHECKED, ""))
	return record


static func _reject(record: VerifyRecord, reason: String, detail: String) -> VerifyRecord:
	record.verified = false
	record.reason = reason
	record.detail = detail.left(VerifyRecord.DETAIL_MAX)
	return record


static func _oversize(size: int, config: BenchConfig) -> String:
	return "%d bytes, above the limit of %d" % [size, config.global_max_run_bytes]
