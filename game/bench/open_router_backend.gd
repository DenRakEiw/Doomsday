class_name OpenRouterBackend
extends ModelBackend
## A chat model behind an OpenAI-compatible endpoint — OpenRouter by default
## (docs/specs/benchmark.md §8.3). `HTTPClient`, polled in a loop: the headless
## caller has nothing else to do while it waits: the tool, or the game's headless
## benchmark worker (§19.4) — never the game's own process.
##
## The key is handed to the constructor and goes into one header. It is never
## printed, logged, cached or written, and no error string carries it.
##
## In `game/bench/` since S6.12f (§19.3) so an export has it; no autoload named.

const ID: String = "openrouter"
const CHAT_PATH: String = "/chat/completions"
const SCHEME_HTTPS: String = "https"
const SCHEME_HTTP: String = "http"
const PORT_HTTPS: int = 443
const PORT_HTTP: int = 80
## Plain `http` only for a local OpenAI-compatible server.
const LOCAL_HOSTS: Array[String] = ["localhost", "127.0.0.1"]

## `_classify`: what a status means.
const CLASS_OK: String = "ok"
const CLASS_RETRY: String = "retry"
## The fatal reasons (§8.3); the tool maps them to its exit codes.
const FATAL_AUTH: String = "auth"
const FATAL_CREDITS: String = "credits"
const FATAL_FORBIDDEN: String = "forbidden"
const FATAL_BAD_REQUEST: String = "bad_request"
const FATAL_UNAVAILABLE: String = "unavailable"
const FATAL_COST_CAP: String = "cost_cap"
const FATAL_BAD_BASE_URL: String = "bad_base_url"
const STATUS_OK: int = 200
const STATUS_AUTH: int = 401
const STATUS_CREDITS: int = 402
const STATUS_FORBIDDEN: int = 403
const STATUSES_BAD_REQUEST: Array[int] = [400, 404, 413, 422]
const STATUSES_RETRY: Array[int] = [408, 429, 500, 502, 503, 524, 529]
## A 200 whose body is not the expected JSON counts as this.
const STATUS_BAD_GATEWAY: int = 502
## `request`'s status when no response came at all (connect, TLS, timeout).
const STATUS_NONE: int = -1
const SERVER_ERROR_MIN: int = 500
## An error string is cut to this, with the key masked (§8.3).
const ERROR_MAX: int = 200
const MASK: String = "***"
const POLL_MS: int = 10
const MS_PER_S: int = 1000
const HEADER_RETRY_AFTER: String = "retry-after"
const PARAM_TEMPERATURE: String = "temperature"
const PARAM_MAX_TOKENS: String = "max_completion_tokens"
const PARAM_JSON_MODE: String = "json_mode"
const PARAM_REASONING: String = "reasoning"
const PARAM_TOP_P: String = "top_p"
const PARAM_SEED: String = "seed"
## OpenRouter's prompt-caching guide: Anthropic caches a prompt only where the
## request marks it (OpenAI, Gemini, DeepSeek and others cache on their own). The
## brief is the same for every decision of a run, so its system message carries
## the mark and every later decision reads it at a tenth of the input price.
const CACHE_MARK_PREFIXES: Array[String] = ["anthropic/"]
const CACHE_CONTROL_EPHEMERAL: String = "ephemeral"
const NO_PRICE: float = -1.0
const COST_UNKNOWN_LINE: String = "benchmark: the service reports no cost and the price is unknown — the cap cannot guard this run"

## The invocation's spend so far; the cap is checked against it before each request.
var spent_usd: float = 0.0
var max_cost_usd: float = 0.0
## USD per token, from the pre-flight's price list (§11.5); −1 when unknown.
var prompt_price: float = NO_PRICE
var completion_price: float = NO_PRICE

var _model: String = ""
var _key: String = ""
var _base: Dictionary = {}
var _timeout_s: int = 0
var _retries: int = 0
var _backoff_s: float = 0.0
var _warned_cost: bool = false


func _init(p_model: String, p_key: String, base_url: String, config: BenchConfig,
		p_max_cost_usd: float) -> void:
	_model = p_model
	_key = p_key
	_base = parse_base_url(base_url)
	_timeout_s = config.timeout_s
	_retries = config.retries
	_backoff_s = config.backoff_s
	max_cost_usd = p_max_cost_usd


func backend_id() -> String:
	return ID


## Whether the cap stops the next request: the spend has reached it — except for
## a model the price list says is free while nothing was spent, so that a cap of
## 0 ("spend nothing", `run_models.ps1 -MaxTotal 0`) still plays a free model.
func cap_reached() -> bool:
	var free: bool = prompt_price == 0.0 and completion_price == 0.0
	if free and spent_usd <= 0.0:
		return false
	return spent_usd >= max_cost_usd


@warning_ignore("unused_parameter")
func answer(messages: Array[Dictionary], digest: BenchDigest, params: Dictionary) -> ModelReply:
	if _base.is_empty():
		return ModelReply.fatal(FATAL_BAD_BASE_URL)
	if cap_reached():
		return ModelReply.fatal(FATAL_COST_CAP)
	var body: String = JSON.stringify(_build_body(messages, params))
	var headers: PackedStringArray = ["Content-Type: application/json",
		"Authorization: Bearer " + _key]
	var attempt: int = 0
	while true:
		var result: Dictionary = request(_base, HTTPClient.METHOD_POST,
			str(_base["prefix"]) + CHAT_PATH, headers, body, _timeout_s)
		var status: int = int(result["status"])
		var reply: ModelReply = null
		if status == STATUS_OK:
			reply = _read_reply(status, str(result["body"]))
			if reply == null:
				status = STATUS_BAD_GATEWAY
		var kind: String = _classify(status)
		if kind == CLASS_OK and reply != null:
			spent_usd += reply.cost_usd
			return reply
		if kind != CLASS_RETRY:
			return ModelReply.fatal(_error_text(kind, status, str(result["body"])))
		attempt += 1
		if attempt > _retries:
			return ModelReply.fatal(FATAL_UNAVAILABLE)
		var wait: float = maxf(_backoff(attempt), _retry_after(result["headers"]))
		OS.delay_msec(int(wait * MS_PER_S))
	return ModelReply.fatal(FATAL_UNAVAILABLE)


## `{scheme, host, port, prefix}` of a base URL, or {} when it is malformed or
## plain `http` to anything but this machine.
static func parse_base_url(url: String) -> Dictionary:
	var split: int = url.find("://")
	if split <= 0:
		return {}
	var scheme: String = url.substr(0, split).to_lower()
	var rest: String = url.substr(split + 3)
	var slash: int = rest.find("/")
	var authority: String = rest if slash < 0 else rest.substr(0, slash)
	var prefix: String = "" if slash < 0 else rest.substr(slash).trim_suffix("/")
	var host: String = authority
	var port: int = PORT_HTTPS if scheme == SCHEME_HTTPS else PORT_HTTP
	var colon: int = authority.rfind(":")
	if colon >= 0:
		host = authority.substr(0, colon)
		var port_text: String = authority.substr(colon + 1)
		if not port_text.is_valid_int():
			return {}
		port = port_text.to_int()
	if host.is_empty() or host.contains("@"):
		return {}
	if scheme != SCHEME_HTTPS and not (scheme == SCHEME_HTTP and LOCAL_HOSTS.has(host)):
		return {}
	return {"scheme": scheme, "host": host, "port": port, "prefix": prefix}


## One HTTP exchange, blocking: `{status, body, headers}`; status −1 when no
## response came (connect, TLS, timeout). `timeout_s` covers everything from the
## connection to the last byte. Used for the chat call and the public price list.
static func request(base: Dictionary, method: int, path: String, headers: PackedStringArray,
		body: String, timeout_s: int) -> Dictionary:
	var failed: Dictionary = {"status": STATUS_NONE, "body": "", "headers": {}}
	var client: HTTPClient = HTTPClient.new()
	var tls: TLSOptions = TLSOptions.client() if str(base["scheme"]) == SCHEME_HTTPS else null
	var deadline: int = Time.get_ticks_msec() + timeout_s * MS_PER_S
	if client.connect_to_host(str(base["host"]), int(base["port"]), tls) != OK:
		return failed
	while client.get_status() in [HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING]:
		client.poll()
		if Time.get_ticks_msec() > deadline:
			client.close()
			return failed
		OS.delay_msec(POLL_MS)
	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		client.close()
		return failed
	if client.request(method, path, headers, body) != OK:
		client.close()
		return failed
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		if Time.get_ticks_msec() > deadline:
			client.close()
			return failed
		OS.delay_msec(POLL_MS)
	if not client.has_response():
		client.close()
		return failed
	var status: int = client.get_response_code()
	var response_headers: Dictionary = client.get_response_headers_as_dictionary()
	var bytes: PackedByteArray = PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk: PackedByteArray = client.read_response_body_chunk()
		if chunk.is_empty():
			if Time.get_ticks_msec() > deadline:
				client.close()
				return failed
			OS.delay_msec(POLL_MS)
		else:
			bytes.append_array(chunk)
	client.close()
	return {"status": status, "body": bytes.get_string_from_utf8(), "headers": response_headers}


## Whether `model`'s provider needs the cache mark (`CACHE_MARK_PREFIXES`).
static func marks_cache(model: String) -> bool:
	for prefix: String in CACHE_MARK_PREFIXES:
		if model.begins_with(prefix):
			return true
	return false


## The request body (§8.3): `response_format` only in JSON mode, `reasoning` and
## `top_p` only when given, `seed` always. No `stream`, no `tools`, no `provider`.
## For a model that `marks_cache`, the system message is sent as one text part
## with `cache_control` — the same text, so the prompt and its cache key are
## unchanged.
func _build_body(messages: Array[Dictionary], params: Dictionary) -> Dictionary:
	var body: Dictionary = {
		"model": _model,
		"messages": _with_cache_mark(messages) if marks_cache(_model) else messages,
		"temperature": float(params.get(PARAM_TEMPERATURE, 0.0)),
		"max_completion_tokens": int(params.get(PARAM_MAX_TOKENS, 1)),
		"seed": int(params.get(PARAM_SEED, 0)),
	}
	if bool(params.get(PARAM_JSON_MODE, false)):
		body["response_format"] = {"type": "json_object"}
	var reasoning: String = str(params.get(PARAM_REASONING, ""))
	if not reasoning.is_empty():
		body["reasoning"] = {"effort": reasoning}
	var top_p: float = float(params.get(PARAM_TOP_P, -1.0))
	if top_p >= 0.0:
		body["top_p"] = top_p
	return body


## `messages` with every system message's text turned into one marked text part.
static func _with_cache_mark(messages: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for message: Dictionary in messages:
		var copy: Dictionary = message.duplicate()
		var content: Variant = message.get(BenchPrompt.FIELD_CONTENT)
		if str(message.get(BenchPrompt.FIELD_ROLE, "")) == BenchPrompt.ROLE_SYSTEM \
				and typeof(content) == TYPE_STRING:
			copy[BenchPrompt.FIELD_CONTENT] = [{"type": "text", "text": content,
				"cache_control": {"type": CACHE_CONTROL_EPHEMERAL}}]
		out.append(copy)
	return out


## A 200's body read; null when it is not the expected JSON (the caller treats
## that as a 502). The cost is the service's when it reports one, else tokens ×
## the price the pre-flight found, else 0 — and then the cap cannot guard the run,
## which is said once.
func _read_reply(status: int, text: String) -> ModelReply:
	if status != STATUS_OK:
		return null
	var json: JSON = JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return null
	var data: Dictionary = json.data
	if typeof(data.get("choices")) != TYPE_ARRAY or (data["choices"] as Array).is_empty() \
			or typeof((data["choices"] as Array)[0]) != TYPE_DICTIONARY:
		return null
	var choice: Dictionary = (data["choices"] as Array)[0]
	var message: Variant = choice.get("message")
	var content: Variant = null
	if typeof(message) == TYPE_DICTIONARY:
		content = (message as Dictionary).get("content")
	var reply: ModelReply = ModelReply.ok(str(content) if typeof(content) == TYPE_STRING else "")
	reply.finish = str(choice.get("finish_reason", "")) \
		if typeof(choice.get("finish_reason")) == TYPE_STRING else ""
	var usage: Dictionary = data.get("usage", {}) if typeof(data.get("usage")) == TYPE_DICTIONARY \
		else {}
	reply.tokens_in = _whole(usage.get("prompt_tokens"))
	reply.tokens_out = _whole(usage.get("completion_tokens"))
	var reported: Variant = usage.get("cost")
	if typeof(reported) == TYPE_FLOAT or typeof(reported) == TYPE_INT:
		reply.cost_usd = float(reported)
	elif prompt_price >= 0.0 and completion_price >= 0.0:
		reply.cost_usd = float(reply.tokens_in) * prompt_price \
			+ float(reply.tokens_out) * completion_price
	elif not _warned_cost:
		_warned_cost = true
		print(COST_UNKNOWN_LINE)
	return reply


## `CLASS_OK`, `CLASS_RETRY`, or the fatal reason a status stands for.
static func _classify(status: int) -> String:
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
func _backoff(n: int) -> float:
	return _backoff_s * pow(2.0, float(n - 1))


## A `Retry-After` in seconds, 0 when there is none or it is not a number.
static func _retry_after(headers: Variant) -> float:
	if typeof(headers) != TYPE_DICTIONARY:
		return 0.0
	for name: Variant in headers:
		if str(name).to_lower() == HEADER_RETRY_AFTER:
			var value: String = str((headers as Dictionary)[name]).strip_edges()
			return value.to_float() if value.is_valid_float() else 0.0
	return 0.0


## The reason as the tool prints it: the kind, and for a bad request the status
## and the service's own `error.code`/`error.message`, cut to 200 characters,
## with the key masked in case a service ever echoed it.
func _error_text(kind: String, status: int, body: String) -> String:
	var text: String = kind
	if kind == FATAL_BAD_REQUEST:
		var detail: String = str(status)
		var json: JSON = JSON.new()
		if json.parse(body) == OK and typeof(json.data) == TYPE_DICTIONARY \
				and typeof((json.data as Dictionary).get("error")) == TYPE_DICTIONARY:
			var error: Dictionary = (json.data as Dictionary)["error"]
			detail += " " + str(error.get("code", "")) + " " + str(error.get("message", ""))
		text += ": " + detail.strip_edges()
	if not _key.is_empty():
		text = text.replace(_key, MASK)
	return text.substr(0, ERROR_MAX)


static func _whole(value: Variant) -> int:
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return int(value)
	return 0
