class_name BenchEntry
extends RefCounted
## One benchmark run as a file (docs/specs/benchmark.md §10.2): who played, with
## what, on which content, and every command — which is all a replay needs.
## Floats are plain JSON numbers: an entry is never re-simulated from its
## numbers, only from its commands.

const VERSION: int = 1
const BACKEND_BOT: String = "bot"
const MODEL_BOT_PREFIX: String = "bot:"
## `outcome` of a run still going at `max_days`.
const OUTCOME_TIMEOUT: String = "timeout"
const EXTENSION: String = ".json"
## §10.2's file name: `<slug>__<params_id>__p<prompt>__<suite>__s<seed>.json`.
const NAME_FORMAT: String = "%s__%s__p%d__%s__s%d.json"
const PARAMS_ID_LENGTH: int = 8
## The slug keeps these characters; everything else becomes `-`.
const SLUG_ALLOWED: String = "abcdefghijklmnopqrstuvwxyz0123456789._-"
const SLUG_SEPARATOR: String = "--"
const SLUG_OTHER: String = "-"
## Score is written to one decimal (§10.1).
const SCORE_STEP: float = 0.1

## UTF-8's shape (RFC 3629) for `is_utf8`: lead bytes, continuation bytes, the
## smallest code point each length may carry, the surrogates, the last code point.
const UTF8_ASCII_END: int = 0x80
const UTF8_CONTINUATION_MASK: int = 0xC0
const UTF8_CONTINUATION: int = 0x80
const UTF8_PAYLOAD: int = 0x3F
const UTF8_PAYLOAD_BITS: int = 6
const UTF8_LEAD_2_FIRST: int = 0xC2
const UTF8_LEAD_2_LAST: int = 0xDF
const UTF8_LEAD_3_FIRST: int = 0xE0
const UTF8_LEAD_3_LAST: int = 0xEF
const UTF8_LEAD_4_FIRST: int = 0xF0
const UTF8_LEAD_4_LAST: int = 0xF4
const UTF8_LEAD_2_BITS: int = 0x1F
const UTF8_LEAD_3_BITS: int = 0x0F
const UTF8_LEAD_4_BITS: int = 0x07
const UTF8_MIN_2: int = 0x80
const UTF8_MIN_3: int = 0x800
const UTF8_MIN_4: int = 0x10000
const UTF8_SURROGATE_FIRST: int = 0xD800
const UTF8_SURROGATE_LAST: int = 0xDFFF
const UTF8_MAX: int = 0x10FFFF

var version: int = VERSION
var model: String = ""
var backend: String = ""
## The version a decision model's service reported (§17.7), several joined with
## `+`; "" for everything else — and then not written, so every other entry is
## byte for byte what it was.
var model_version: String = ""
var params: Dictionary = {}
var params_id: String = ""
var prompt_version: int = 1
var parser_version: int = 1
var locale: String = ""
var suite: String = ""
var game_version: String = ""
var content_hash: String = ""
var seed_value: int = 0
var setup: RunSetup = null
var max_days: int = 0
var interval_days: int = 0
var recorded: String = ""
var outcome: String = ""
var variant: String = ""
## `world.day − world.origin_day` — the profile's measure.
var days: int = 0
var end_day: int = 0
var score: float = 0.0
var state_hash: String = ""
var calls: int = 0
var cached_calls: int = 0
var invalid_answers: int = 0
var rejected_actions: int = 0
var tokens_in: int = 0
var tokens_out: int = 0
var cost_usd: float = 0.0
var budget_exhausted: bool = false
var commands: Array[Command] = []
var decisions: Array[BenchDecision] = []

## Not in the file: where it was read from (`runs/<name>.json`) and the SHA-256
## of its bytes — what a leaderboard row lists per seed (§16.3).
var file: String = ""
var sha256: String = ""
## Why `from_dict` returned null, for the list's log line.
static var last_error: String = ""


## The slug of a model id: lower-cased, `/` → `--`, anything outside
## `[a-z0-9._-]` → `-`.
static func slug(model_id: String) -> String:
	var lowered: String = model_id.to_lower().replace("/", SLUG_SEPARATOR)
	var out: String = ""
	for i: int in lowered.length():
		var character: String = lowered[i]
		out += character if SLUG_ALLOWED.contains(character) else SLUG_OTHER
	return out


## The first 8 hex of the SHA-256 of the sorted params JSON. Every number is
## hashed as a float, so the id reads the same from a file (where JSON has no
## integers) as from the tool that wrote it.
static func params_id_of(p_params: Dictionary) -> String:
	return JSON.stringify(_numbers_as_floats(p_params), "", true).sha256_text() \
		.substr(0, PARAMS_ID_LENGTH)


static func file_name_for(p_model: String, p_params_id: String, p_prompt_version: int,
		p_suite: String, p_seed: int) -> String:
	return NAME_FORMAT % [slug(p_model), p_params_id, p_prompt_version, p_suite, p_seed]


## The §10.1 score, rounded as it is written.
static func rounded_score(value: float) -> float:
	return snappedf(value, SCORE_STEP)


func file_name() -> String:
	return file_name_for(model, params_id, prompt_version, suite, seed_value)


func is_bot() -> bool:
	return backend == BACKEND_BOT


func is_win() -> bool:
	return outcome.begins_with(BenchScore.WIN_PREFIX)


## Exactly §10.2's keys, in its order; `model_version` after `backend` only when
## it is not empty (§17.7).
func to_dict() -> Dictionary:
	var command_rows: Array[Dictionary] = []
	for command: Command in commands:
		command_rows.append(command.to_dict())
	var decision_rows: Array[Dictionary] = []
	for decision: BenchDecision in decisions:
		decision_rows.append(decision.to_dict())
	var head: Dictionary = {
		"version": version,
		"model": model,
		"backend": backend,
	}
	if not model_version.is_empty():
		head["model_version"] = model_version
	head.merge({
		"params": params.duplicate(true),
		"params_id": params_id,
		"prompt_version": prompt_version,
		"parser_version": parser_version,
		"locale": locale,
		"suite": suite,
		"game_version": game_version,
		"content_hash": content_hash,
		"seed": seed_value,
		"setup": setup.to_dict() if setup != null else {},
		"max_days": max_days,
		"interval_days": interval_days,
		"recorded": recorded,
		"outcome": outcome,
		"variant": variant,
		"days": days,
		"end_day": end_day,
		"score": rounded_score(score),
		"hash": state_hash,
		"calls": calls,
		"cached_calls": cached_calls,
		"invalid_answers": invalid_answers,
		"rejected_actions": rejected_actions,
		"tokens_in": tokens_in,
		"tokens_out": tokens_out,
		"cost_usd": cost_usd,
		"budget_exhausted": budget_exhausted,
		"commands": command_rows,
		"decisions": decision_rows,
	})
	return head


## The file's text: tab-indented, the keys in `to_dict`'s order.
func to_json() -> String:
	return JSON.stringify(to_dict(), "\t", false) + "\n"


## Null — never a crash — on a missing or ill-typed key, an unknown version, a
## setup `RunSetup.from_dict` refuses or a command `CommandCodec` refuses;
## `last_error` says which.
static func from_dict(d: Dictionary) -> BenchEntry:
	last_error = ""
	if not _is_whole(d.get("version")):
		return _fail("version: missing or not a whole number")
	if int(d["version"]) != VERSION:
		return _fail("version: %d is not %d" % [int(d["version"]), VERSION])
	for key: String in ["model", "backend", "params_id", "locale", "suite", "game_version",
			"content_hash", "recorded", "outcome", "variant", "hash"]:
		if typeof(d.get(key)) != TYPE_STRING:
			return _fail("%s: missing or not a string" % key)
	for key: String in ["prompt_version", "parser_version", "seed", "max_days", "interval_days",
			"days", "end_day", "calls", "cached_calls", "invalid_answers", "rejected_actions",
			"tokens_in", "tokens_out"]:
		if not _is_whole(d.get(key)):
			return _fail("%s: missing or not a whole number" % key)
	for key: String in ["score", "cost_usd"]:
		if typeof(d.get(key)) != TYPE_FLOAT and typeof(d.get(key)) != TYPE_INT:
			return _fail("%s: missing or not a number" % key)
	if typeof(d.get("budget_exhausted")) != TYPE_BOOL:
		return _fail("budget_exhausted: missing or not true/false")
	if d.has("model_version") and typeof(d["model_version"]) != TYPE_STRING:
		return _fail("model_version: not a string")
	for key: String in ["params", "setup"]:
		if typeof(d.get(key)) != TYPE_DICTIONARY:
			return _fail("%s: missing or not an object" % key)
	for key: String in ["commands", "decisions"]:
		if typeof(d.get(key)) != TYPE_ARRAY:
			return _fail("%s: missing or not a list" % key)
	var entry: BenchEntry = BenchEntry.new()
	entry.setup = RunSetup.from_dict(d["setup"])
	if entry.setup == null:
		return _fail("setup: not a run setup")
	var list: Array = d["commands"]
	for i: int in list.size():
		var command: Command = null
		if typeof(list[i]) == TYPE_DICTIONARY:
			command = CommandCodec.from_dict(list[i])
		if command == null:
			return _fail("commands[%d]: not a command" % i)
		entry.commands.append(command)
	var rows: Array = d["decisions"]
	for i: int in rows.size():
		var decision: BenchDecision = null
		if typeof(rows[i]) == TYPE_DICTIONARY:
			decision = BenchDecision.from_dict(rows[i])
		if decision == null:
			return _fail("decisions[%d]: not a decision" % i)
		entry.decisions.append(decision)
	entry.model = str(d["model"])
	entry.backend = str(d["backend"])
	entry.model_version = str(d.get("model_version", ""))
	entry.params = (d["params"] as Dictionary).duplicate(true)
	entry.params_id = str(d["params_id"])
	entry.prompt_version = int(d["prompt_version"])
	entry.parser_version = int(d["parser_version"])
	entry.locale = str(d["locale"])
	entry.suite = str(d["suite"])
	entry.game_version = str(d["game_version"])
	entry.content_hash = str(d["content_hash"])
	entry.seed_value = int(d["seed"])
	entry.max_days = int(d["max_days"])
	entry.interval_days = int(d["interval_days"])
	entry.recorded = str(d["recorded"])
	entry.outcome = str(d["outcome"])
	entry.variant = str(d["variant"])
	entry.days = int(d["days"])
	entry.end_day = int(d["end_day"])
	entry.score = float(d["score"])
	entry.state_hash = str(d["hash"])
	entry.calls = int(d["calls"])
	entry.cached_calls = int(d["cached_calls"])
	entry.invalid_answers = int(d["invalid_answers"])
	entry.rejected_actions = int(d["rejected_actions"])
	entry.tokens_in = int(d["tokens_in"])
	entry.tokens_out = int(d["tokens_out"])
	entry.cost_usd = float(d["cost_usd"])
	entry.budget_exhausted = bool(d["budget_exhausted"])
	return entry


## A file's text read; null (with `last_error`) when it is not a JSON object or
## not an entry.
static func from_json(text: String) -> BenchEntry:
	var json: JSON = JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return _fail("not a JSON object")
	return from_dict(json.data)


## A file's bytes read — the form an untrusted file arrives in (a submitted run,
## a download). UTF-8 is checked first, so a broken file never makes the engine
## report a decoding error; null (with `last_error`) as `from_json`.
static func from_bytes(bytes: PackedByteArray) -> BenchEntry:
	if not is_utf8(bytes):
		return _fail("not UTF-8 text")
	return from_json(bytes.get_string_from_utf8())


## Whether `bytes` are well-formed UTF-8 without a NUL (RFC 3629: no overlong
## form, no surrogate, nothing past U+10FFFF).
static func is_utf8(bytes: PackedByteArray) -> bool:
	var size: int = bytes.size()
	var i: int = 0
	while i < size:
		var lead: int = bytes[i]
		if lead < UTF8_ASCII_END:
			if lead == 0:
				return false
			i += 1
			continue
		var follow: int = 0
		var code: int = 0
		var smallest: int = 0
		if lead >= UTF8_LEAD_2_FIRST and lead <= UTF8_LEAD_2_LAST:
			follow = 1
			code = lead & UTF8_LEAD_2_BITS
			smallest = UTF8_MIN_2
		elif lead >= UTF8_LEAD_3_FIRST and lead <= UTF8_LEAD_3_LAST:
			follow = 2
			code = lead & UTF8_LEAD_3_BITS
			smallest = UTF8_MIN_3
		elif lead >= UTF8_LEAD_4_FIRST and lead <= UTF8_LEAD_4_LAST:
			follow = 3
			code = lead & UTF8_LEAD_4_BITS
			smallest = UTF8_MIN_4
		else:
			return false
		if i + follow >= size:
			return false
		for k: int in range(1, follow + 1):
			var next: int = bytes[i + k]
			if (next & UTF8_CONTINUATION_MASK) != UTF8_CONTINUATION:
				return false
			code = (code << UTF8_PAYLOAD_BITS) | (next & UTF8_PAYLOAD)
		if code < smallest or code > UTF8_MAX \
				or (code >= UTF8_SURROGATE_FIRST and code <= UTF8_SURROGATE_LAST):
			return false
		i += follow + 1
	return true


static func _fail(reason: String) -> BenchEntry:
	last_error = reason
	return null


static func _numbers_as_floats(value: Variant) -> Variant:
	match typeof(value):
		TYPE_INT:
			return float(value)
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for key: Variant in value:
				out[key] = _numbers_as_floats((value as Dictionary)[key])
			return out
		TYPE_ARRAY:
			var items: Array = []
			for item: Variant in value:
				items.append(_numbers_as_floats(item))
			return items
	return value


static func _is_whole(value: Variant) -> bool:
	var type: int = typeof(value)
	if type == TYPE_INT:
		return true
	return type == TYPE_FLOAT and float(value) == floorf(float(value))
