extends ModelBackend
## TypeSafe's decision model Jev (docs/specs/benchmark.md §17.8): one request of
## choice questions per decision, answered with ranked options, never text.
## The transport is the OpenRouter backend's `HTTPClient` loop, shared as its
## static helpers; OpenRouter's own behaviour is unchanged. Never shipped:
## `tools/*` is left out of every export.
##
## The key is handed to the constructor and goes into one header. It is never
## printed, logged, cached or written, and no error string carries it.
##
## A tool, so no `class_name`; `bench_run.gd` and the tests preload it.

const Http := preload("res://tools/bench/open_router_backend.gd")

const ID: String = "typesafe"
## The fatal reasons (§17.8); the tool maps them to its exit codes. The shared
## ones are the OpenRouter backend's, so `exit_for` reads both alike.
const FATAL_AUTH: String = Http.FATAL_AUTH
const FATAL_CREDITS: String = Http.FATAL_CREDITS
const FATAL_FORBIDDEN: String = Http.FATAL_FORBIDDEN
const FATAL_BAD_REQUEST: String = Http.FATAL_BAD_REQUEST
const FATAL_UNAVAILABLE: String = Http.FATAL_UNAVAILABLE
const FATAL_COST_CAP: String = Http.FATAL_COST_CAP
const FATAL_BAD_BASE_URL: String = Http.FATAL_BAD_BASE_URL
const FATAL_REQUEST_CAP: String = "request_cap"
const CLASS_OK: String = Http.CLASS_OK
const CLASS_RETRY: String = Http.CLASS_RETRY
const STATUS_OK: int = 200
const STATUS_AUTH: int = 401
const STATUS_CREDITS: int = 402
const STATUS_FORBIDDEN: int = 403
## 422 is TypeSafe's validation error: a malformed request, or one above the
## size limits — a retry would send the same.
const STATUSES_BAD_REQUEST: Array[int] = [400, 404, 413, 422]
## 529 is TypeSafe's "overloaded".
const STATUSES_RETRY: Array[int] = [408, 429, 500, 502, 503, 504, 529]
const STATUS_BAD_GATEWAY: int = 502
const STATUS_NONE: int = Http.STATUS_NONE
const SERVER_ERROR_MIN: int = 500
const ERROR_MAX: int = 200
const MASK: String = "***"
const MS_PER_S: int = 1000
const TOKENS_PER_MTOK: float = 1000000.0
## Both named by TypeSafe's SDK; the larger wait is kept.
const HEADER_RETRY_AFTER: String = "retry-after"
const HEADER_RETRY_AFTER_MS: String = "retry-after-ms"
## Where a 4xx body may carry its reason.
const BODY_MESSAGE: String = "message"
const BODY_DETAIL: String = "detail"
const BODY_ERROR: String = "error"
## OpenRouter's charge for the call, in USD, under `usage`.
const USAGE_COST: String = "cost"

## The invocation's spend so far; the cap is checked against it before each request.
var spent_usd: float = 0.0
var max_cost_usd: float = 0.0
## Every HTTP attempt of this invocation, transport retries included.
var requests_sent: int = 0
var max_requests: int = 0
## USD per million tokens, the published price (`data/benchmark.json`).
var price_input: float = 0.0
var price_output: float = 0.0

var _model: String = ""
var _key: String = ""
var _base: Dictionary = {}
var _path: String = ""
var _timeout_s: int = 0
var _retries: int = 0
var _backoff_s: float = 0.0


## `p_model` is what is sent — the part after `typesafe/` (`jev-latest`).
func _init(p_model: String, p_key: String, base_url: String, config: BenchConfig,
		p_max_cost_usd: float, p_max_requests: int) -> void:
	_model = p_model
	_key = p_key
	_base = Http.parse_base_url(base_url)
	_path = config.typesafe_path
	_timeout_s = config.timeout_s
	_retries = config.retries
	_backoff_s = config.backoff_s
	max_cost_usd = p_max_cost_usd
	max_requests = p_max_requests
	price_input = config.typesafe_price_input
	price_output = config.typesafe_price_output


func kind() -> String:
	return KIND_CHOICE


func backend_id() -> String:
	return ID


@warning_ignore("unused_parameter")
func choose(plan: BenchChoicePlan, digest: BenchDigest, params: Dictionary) -> ModelReply:
	if _base.is_empty():
		return ModelReply.fatal(FATAL_BAD_BASE_URL)
	var body: String = JSON.stringify(build_body(plan))
	var headers: PackedStringArray = build_headers()
	var attempt: int = 0
	while true:
		var capped: String = cap_reason()
		if not capped.is_empty():
			return ModelReply.fatal(capped)
		requests_sent += 1
		var result: Dictionary = Http.request(_base, HTTPClient.METHOD_POST,
			str(_base["prefix"]) + _path, headers, body, _timeout_s)
		var status: int = int(result["status"])
		var reply: ModelReply = null
		if status == STATUS_OK:
			reply = read_reply(str(result["body"]))
			if reply == null:
				status = STATUS_BAD_GATEWAY
		var kind_of: String = classify(status)
		if kind_of == CLASS_OK and reply != null:
			spent_usd += reply.cost_usd
			return reply
		if kind_of != CLASS_RETRY:
			return ModelReply.fatal(error_text(kind_of, status, str(result["body"])))
		attempt += 1
		if attempt > _retries:
			return ModelReply.fatal(FATAL_UNAVAILABLE)
		var wait: float = maxf(backoff(attempt), retry_after(result["headers"]))
		OS.delay_msec(int(wait * MS_PER_S))
	return ModelReply.fatal(FATAL_UNAVAILABLE)


## The request body (§17.8): the model after the prefix, the state, the
## questions — no other key (none is documented).
func build_body(plan: BenchChoicePlan) -> Dictionary:
	return plan.body(_model)


## `Content-Type` and `Authorization`, nothing else; the key only in the latter.
func build_headers() -> PackedStringArray:
	return PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + _key])


## The caps, checked before every request: the cost cap, then the request cap.
## "" when the request may go.
func cap_reason() -> String:
	if spent_usd >= max_cost_usd:
		return FATAL_COST_CAP
	if requests_sent >= max_requests:
		return FATAL_REQUEST_CAP
	return ""


## A 200's body read; null when it is not a JSON object (the caller treats that
## as a 502). The cost is the published price times the tokens — TypeSafe
## reports none, and output tokens are free today — or, through OpenRouter,
## `usage.cost` as charged.
func read_reply(text: String) -> ModelReply:
	var json: JSON = JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return null
	var data: Dictionary = json.data
	var version: Variant = data.get(BenchChoice.FIELD_MODEL)
	var reply: ModelReply = ModelReply.choice(data,
		str(version) if typeof(version) == TYPE_STRING else "")
	var usage: Dictionary = data.get(BenchChoice.FIELD_USAGE, {}) \
		if typeof(data.get(BenchChoice.FIELD_USAGE)) == TYPE_DICTIONARY else {}
	reply.tokens_in = _whole(usage.get(BenchChoice.FIELD_INPUT_TOKENS))
	reply.tokens_out = _whole(usage.get(BenchChoice.FIELD_OUTPUT_TOKENS))
	reply.cost_usd = float(reply.tokens_in) * price_input / TOKENS_PER_MTOK \
		+ float(reply.tokens_out) * price_output / TOKENS_PER_MTOK
	# Through OpenRouter the charge itself comes back; it wins over the estimate.
	var charged: Variant = usage.get(USAGE_COST)
	if typeof(charged) == TYPE_FLOAT or typeof(charged) == TYPE_INT:
		reply.cost_usd = maxf(float(charged), 0.0)
	return reply


## `CLASS_OK`, `CLASS_RETRY`, or the fatal reason a status stands for.
static func classify(status: int) -> String:
	if status == STATUS_OK:
		return CLASS_OK
	if status == STATUS_AUTH:
		return FATAL_AUTH
	if status == STATUS_CREDITS:
		return FATAL_CREDITS
	if status == STATUS_FORBIDDEN:
		return FATAL_FORBIDDEN
	if STATUSES_BAD_REQUEST.has(status):
		return FATAL_BAD_REQUEST
	if STATUSES_RETRY.has(status) or status == STATUS_NONE or status >= SERVER_ERROR_MIN:
		return CLASS_RETRY
	# Any other answer is one a retry will not change.
	return FATAL_BAD_REQUEST


## The wait before retry `n` (1-based): 2, 4, 8, 16, 32 s at the defaults.
func backoff(n: int) -> float:
	return _backoff_s * pow(2.0, float(n - 1))


## The larger of `Retry-After` (seconds) and `retry-after-ms`, in seconds; 0 when
## neither is there or a number.
static func retry_after(headers: Variant) -> float:
	if typeof(headers) != TYPE_DICTIONARY:
		return 0.0
	var wait: float = 0.0
	for name: Variant in headers:
		var header: String = str(name).to_lower()
		var value: String = str((headers as Dictionary)[name]).strip_edges()
		if not value.is_valid_float():
			continue
		if header == HEADER_RETRY_AFTER:
			wait = maxf(wait, value.to_float())
		elif header == HEADER_RETRY_AFTER_MS:
			wait = maxf(wait, value.to_float() / float(MS_PER_S))
	return wait


## The reason as the tool prints it: the kind, and for a bad request the status
## and the body's `message`, `detail` or `error.message` when one is a string —
## cut to 200 characters, the key masked in case a service ever echoed it.
func error_text(kind_of: String, status: int, body: String) -> String:
	var text: String = kind_of
	if kind_of == FATAL_BAD_REQUEST:
		text += ": " + str(status)
		var detail: String = _body_message(body)
		if not detail.is_empty():
			text += " " + detail
	if not _key.is_empty():
		text = text.replace(_key, MASK)
	return text.substr(0, ERROR_MAX)


static func _body_message(body: String) -> String:
	var json: JSON = JSON.new()
	if json.parse(body) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return ""
	var data: Dictionary = json.data
	for field: String in [BODY_MESSAGE, BODY_DETAIL]:
		if typeof(data.get(field)) == TYPE_STRING:
			return str(data[field])
	if typeof(data.get(BODY_ERROR)) == TYPE_DICTIONARY \
			and typeof((data[BODY_ERROR] as Dictionary).get(BODY_MESSAGE)) == TYPE_STRING:
		return str((data[BODY_ERROR] as Dictionary)[BODY_MESSAGE])
	return ""


static func _whole(value: Variant) -> int:
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return int(value)
	return 0
