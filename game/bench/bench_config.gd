class_name BenchConfig
extends RefCounted
## `data/benchmark.json` read and checked (docs/specs/benchmark.md §3): the model
## policy's rhythm and limits, the seed suites, the score, the defaults sent to a
## model, the HTTP settings, the pre-flight estimate, the global board's
## addresses, and the decision-model backend (§17: the combination rules and
## TypeSafe's endpoint, price and caps). Presentation data — the core never reads it.
##
## A bad file never crashes: `errors` names every key that is missing or of the
## wrong type, and the tool exits 1 naming them.

const PATH: String = "res://data/benchmark.json"
const VERSION: int = 1
const SUITE_STANDARD: String = "standard"
const SUITE_QUICK: String = "quick"

var errors: Array[String] = []

var prompt_version: int = 1
var parser_version: int = 1
## `RunSetup.to_dict()` of the benchmark's run; the tool validates it against the
## content (`RunSetup.from_dict` + `validate`).
var setup: Dictionary = {}
var max_days: int = 2000
var interval_days: int = 10
var max_calls: int = 250
var max_actions: int = 12
var retry_invalid: int = 1
var log_max: int = 30
var targets_max: int = 20
var suites: Dictionary[String, Array] = {}
var win_base: float = 50.0
var win_speed: float = 50.0

var temperature: float = 0.0
var max_completion_tokens: int = 1200
var json_mode: bool = true
var locale: String = "en"

var base_url: String = ""
var key_env: String = ""
var timeout_s: int = 180
var retries: int = 5
var backoff_s: float = 2.0
var max_cost_usd: float = 2.0
var models_path: String = ""

var chars_per_token: int = 4
var calls_per_run: int = 80
var digest_growth: float = 1.5
var output_tokens_per_call: int = 300

var global_leaderboard_url: String = ""
var global_run_base_url: String = ""
var global_repo_url: String = ""
var global_timeout_s: int = 20
var global_max_board_bytes: int = 1000000
var global_max_run_bytes: int = 4000000
var global_max_rows: int = 500
var global_min_refetch_s: int = 300
var global_cache_runs_max: int = 50
var global_verify_limit: int = 100

## §17: bumped by any change to how a choice run is asked and combined; goes into
## its params.
var choice_version: int = 1
## Options per question, the control key included (TypeSafe's limit).
var max_options: int = 255
## Picks per decision of each multi-pick question (`BenchChoice.MULTI_PICK`).
var max_picks: Dictionary[String, int] = {}
var typesafe_model_prefix: String = ""
var typesafe_base_url: String = ""
var typesafe_path: String = ""
var typesafe_key_env: String = ""
## USD per million tokens, as published; negative = unknown.
var typesafe_price_input: float = 0.0
var typesafe_price_output: float = 0.0
## HTTP requests per invocation, retries included.
var typesafe_max_requests: int = 3000
var typesafe_question_tokens: int = 1500
var typesafe_state_limit: int = 32000
var typesafe_request_limit: int = 64000


## The file at `path`, read; a file that is missing or not a JSON object is one
## error, never a crash.
static func load_file(path: String = PATH) -> BenchConfig:
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		var missing: BenchConfig = BenchConfig.new()
		missing.errors.append("%s: missing or empty" % path)
		return missing
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		var broken: BenchConfig = BenchConfig.new()
		broken.errors.append("%s: not a JSON object" % path)
		return broken
	return from_dict(parsed)


static func from_dict(d: Dictionary) -> BenchConfig:
	var config: BenchConfig = BenchConfig.new()
	config._read(d)
	return config


func ok() -> bool:
	return errors.is_empty()


## The seeds of a suite, in order; empty for a suite the file does not have.
func suite_seeds(suite: String) -> Array[int]:
	var out: Array[int] = []
	for value: Variant in suites.get(suite, []):
		out.append(int(value))
	return out


func _read(d: Dictionary) -> void:
	if _int(d, "version", 1) != VERSION:
		errors.append("version: expected %d" % VERSION)
	prompt_version = _int(d, "prompt_version", 1)
	parser_version = _int(d, "parser_version", 1)
	setup = _object(d, "setup")
	max_days = _int(d, "max_days", 1)
	interval_days = _int(d, "interval_days", 1)
	max_calls = _int(d, "max_calls", 1)
	max_actions = _int(d, "max_actions", 1)
	retry_invalid = _int(d, "retry_invalid", 0)
	var digest: Dictionary = _object(d, "digest")
	log_max = _int(digest, "log_max", 0, "digest.")
	targets_max = _int(digest, "targets_max", 1, "digest.")
	_read_suites(_object(d, "suites"))
	var score: Dictionary = _object(d, "score")
	win_base = _float(score, "win_base", "score.")
	win_speed = _float(score, "win_speed", "score.")
	var defaults: Dictionary = _object(d, "defaults")
	temperature = _float(defaults, "temperature", "defaults.")
	max_completion_tokens = _int(defaults, "max_completion_tokens", 1, "defaults.")
	json_mode = _bool(defaults, "json_mode", "defaults.")
	locale = _string(defaults, "locale", "defaults.")
	var http: Dictionary = _object(d, "http")
	base_url = _string(http, "base_url", "http.")
	key_env = _string(http, "key_env", "http.")
	timeout_s = _int(http, "timeout_s", 1, "http.")
	retries = _int(http, "retries", 0, "http.")
	backoff_s = _float(http, "backoff_s", "http.")
	max_cost_usd = _float(http, "max_cost_usd", "http.")
	models_path = _string(http, "models_path", "http.")
	var estimate: Dictionary = _object(d, "estimate")
	chars_per_token = _int(estimate, "chars_per_token", 1, "estimate.")
	calls_per_run = _int(estimate, "calls_per_run", 1, "estimate.")
	digest_growth = _float(estimate, "digest_growth", "estimate.")
	if digest_growth < 1.0 and estimate.has("digest_growth"):
		errors.append("estimate.digest_growth: below 1")
	output_tokens_per_call = _int(estimate, "output_tokens_per_call", 1, "estimate.")
	var global: Dictionary = _object(d, "global")
	global_leaderboard_url = _string(global, "leaderboard_url", "global.")
	global_run_base_url = _string(global, "run_base_url", "global.")
	global_repo_url = _string(global, "repo_url", "global.")
	global_timeout_s = _int(global, "timeout_s", 1, "global.")
	global_max_board_bytes = _int(global, "max_board_bytes", 1, "global.")
	global_max_run_bytes = _int(global, "max_run_bytes", 1, "global.")
	global_max_rows = _int(global, "max_rows", 1, "global.")
	global_min_refetch_s = _int(global, "min_refetch_s", 0, "global.")
	global_cache_runs_max = _int(global, "cache_runs_max", 0, "global.")
	global_verify_limit = _int(global, "verify_limit", 1, "global.")
	var choice: Dictionary = _object(d, "choice")
	choice_version = _int(choice, "choice_version", 1, "choice.")
	max_options = _int(choice, "max_options", 2, "choice.")
	var picks: Dictionary = {}
	if typeof(choice.get("max_picks")) == TYPE_DICTIONARY:
		picks = choice["max_picks"]
	else:
		errors.append("choice.max_picks: missing or not an object")
	for question: String in BenchChoice.MULTI_PICK:
		max_picks[question] = _int(picks, question, 1, "choice.max_picks.")
	var typesafe: Dictionary = _object(d, "typesafe")
	typesafe_model_prefix = _string(typesafe, "model_prefix", "typesafe.")
	typesafe_base_url = _string(typesafe, "base_url", "typesafe.")
	typesafe_path = _string(typesafe, "path", "typesafe.")
	typesafe_key_env = _string(typesafe, "key_env", "typesafe.")
	typesafe_price_input = _float(typesafe, "price_input_usd_per_mtok", "typesafe.")
	typesafe_price_output = _float(typesafe, "price_output_usd_per_mtok", "typesafe.")
	typesafe_max_requests = _int(typesafe, "max_requests", 1, "typesafe.")
	typesafe_question_tokens = _int(typesafe, "question_tokens_per_call", 0, "typesafe.")
	typesafe_state_limit = _int(typesafe, "state_limit_tokens", 1, "typesafe.")
	typesafe_request_limit = _int(typesafe, "request_limit_tokens", 1, "typesafe.")


func _read_suites(d: Dictionary) -> void:
	for suite: Variant in d:
		if str(suite).begins_with("_"):
			continue
		var seeds: Variant = d[suite]
		if typeof(seeds) != TYPE_ARRAY or (seeds as Array).is_empty():
			errors.append("suites.%s: not a list of seeds" % suite)
			continue
		var out: Array[int] = []
		for value: Variant in seeds:
			if not _is_whole(value):
				errors.append("suites.%s: not a list of whole numbers" % suite)
				out.clear()
				break
			out.append(int(value))
		if not out.is_empty():
			suites[str(suite)] = out
	if not suites.has(SUITE_STANDARD):
		errors.append("suites.%s: missing" % SUITE_STANDARD)


func _object(d: Dictionary, key: String) -> Dictionary:
	if typeof(d.get(key)) != TYPE_DICTIONARY:
		errors.append("%s: missing or not an object" % key)
		return {}
	return d[key]


func _int(d: Dictionary, key: String, minimum: int, prefix: String = "") -> int:
	if not _is_whole(d.get(key)):
		errors.append("%s%s: missing or not a whole number" % [prefix, key])
		return minimum
	var value: int = int(d[key])
	if value < minimum:
		errors.append("%s%s: below %d" % [prefix, key, minimum])
	return value


func _float(d: Dictionary, key: String, prefix: String = "") -> float:
	var type: int = typeof(d.get(key))
	if type != TYPE_FLOAT and type != TYPE_INT:
		errors.append("%s%s: missing or not a number" % [prefix, key])
		return 0.0
	return float(d[key])


func _bool(d: Dictionary, key: String, prefix: String = "") -> bool:
	if typeof(d.get(key)) != TYPE_BOOL:
		errors.append("%s%s: missing or not true/false" % [prefix, key])
		return false
	return bool(d[key])


func _string(d: Dictionary, key: String, prefix: String = "") -> String:
	if typeof(d.get(key)) != TYPE_STRING or str(d[key]).is_empty():
		errors.append("%s%s: missing or not a string" % [prefix, key])
		return ""
	return str(d[key])


static func _is_whole(value: Variant) -> bool:
	var type: int = typeof(value)
	if type == TYPE_INT:
		return true
	return type == TYPE_FLOAT and float(value) == floorf(float(value))
