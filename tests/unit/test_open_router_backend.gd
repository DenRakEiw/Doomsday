extends GutTest
## S6.12 — the OpenRouter backend's pure parts (docs/specs/benchmark.md §8.3):
## the body, the reply reader, the status table, the backoff and the error
## string. **No network**: the socket loop is not unit-tested.

const SAMPLE_KEY: String = "sk-or-v1-sample-not-a-real-key-0123456789"

var _config: BenchConfig = null


func before_each() -> void:
	_config = BenchConfig.load_file()


func _backend() -> OpenRouterBackend:
	return OpenRouterBackend.new("vendor/model", SAMPLE_KEY, "https://openrouter.ai/api/v1", _config, 2.0)


func _params(extra: Dictionary = {}) -> Dictionary:
	var params: Dictionary = {"temperature": 0.0, "max_completion_tokens": 1200,
		"json_mode": true, "reasoning": "", "top_p": -1.0, "seed": 1001}
	params.merge(extra, true)
	return params


func test_the_body_names_the_model_and_the_parameters_and_always_the_seed() -> void:
	var messages: Array[Dictionary] = BenchPrompt.messages("brief", "digest")
	var body: Dictionary = _backend()._build_body(messages, _params())
	assert_eq(str(body["model"]), "vendor/model")
	assert_eq(body["messages"], messages)
	assert_eq(int(body["seed"]), 1001)
	assert_eq(int(body["max_completion_tokens"]), 1200)
	assert_eq(body["response_format"], {"type": "json_object"})
	assert_false(body.has("reasoning"))
	assert_false(body.has("top_p"))
	for absent: String in ["stream", "tools", "provider"]:
		assert_false(body.has(absent), absent)


func test_an_anthropic_model_marks_the_brief_for_the_cache() -> void:
	var backend: OpenRouterBackend = OpenRouterBackend.new("anthropic/claude-sonnet-5", SAMPLE_KEY,
		"https://openrouter.ai/api/v1", _config, 2.0)
	var messages: Array[Dictionary] = BenchPrompt.messages("brief", "digest")
	var sent: Array = backend._build_body(messages, _params())["messages"]
	assert_eq(sent[0], {"role": "system", "content": [{"type": "text", "text": "brief",
		"cache_control": {"type": "ephemeral"}}]})
	assert_eq(sent[1], messages[1], "the digest goes as it is")
	assert_eq(messages[0]["content"], "brief", "the caller's messages are not changed")


func test_another_model_sends_the_messages_unmarked() -> void:
	var messages: Array[Dictionary] = BenchPrompt.messages("brief", "digest")
	assert_eq(_backend()._build_body(messages, _params())["messages"], messages)
	assert_false(OpenRouterBackend.marks_cache("openai/gpt-5"))
	assert_true(OpenRouterBackend.marks_cache("anthropic/claude-opus-5.5"))


func test_json_mode_off_sends_no_response_format() -> void:
	var body: Dictionary = _backend()._build_body([], _params({"json_mode": false}))
	assert_false(body.has("response_format"))


func test_reasoning_and_top_p_go_only_when_given() -> void:
	var body: Dictionary = _backend()._build_body([], _params({"reasoning": "high",
		"top_p": 0.9}))
	assert_eq(body["reasoning"], {"effort": "high"})
	assert_almost_eq(float(body["top_p"]), 0.9, 0.00001)


func test_a_200_with_content_reads_the_text_the_tokens_and_the_cost() -> void:
	var reply: ModelReply = _backend()._read_reply(200, JSON.stringify({
		"choices": [{"message": {"content": "{\"actions\": []}"}, "finish_reason": "stop"}],
		"usage": {"prompt_tokens": 1000, "completion_tokens": 50, "cost": 0.0123}}))
	assert_not_null(reply)
	assert_eq(reply.text, "{\"actions\": []}")
	assert_eq(reply.finish, "stop")
	assert_eq(reply.tokens_in, 1000)
	assert_eq(reply.tokens_out, 50)
	assert_almost_eq(reply.cost_usd, 0.0123, 0.000001)
	assert_false(reply.is_fatal())


func test_null_content_reads_as_empty_text() -> void:
	var reply: ModelReply = _backend()._read_reply(200, JSON.stringify({
		"choices": [{"message": {"content": null}, "finish_reason": "length"}]}))
	assert_not_null(reply)
	assert_eq(reply.text, "")
	assert_eq(reply.tokens_in, 0, "missing usage reads as nothing")


func test_a_reply_without_a_cost_uses_a_known_price_else_zero() -> void:
	var body: String = JSON.stringify({"choices": [{"message": {"content": "x"}}],
		"usage": {"prompt_tokens": 1000, "completion_tokens": 100}})
	var priced: OpenRouterBackend = _backend()
	priced.prompt_price = 0.000001
	priced.completion_price = 0.000004
	assert_almost_eq(priced._read_reply(200, body).cost_usd, 0.0014, 0.0000001)
	var unpriced: OpenRouterBackend = _backend()
	assert_eq(unpriced._read_reply(200, body).cost_usd, 0.0)


func test_a_200_that_is_not_the_expected_json_reads_as_null() -> void:
	var backend: OpenRouterBackend = _backend()
	assert_null(backend._read_reply(200, "<html>busy</html>"))
	assert_null(backend._read_reply(200, "{\"choices\": []}"))
	assert_null(backend._read_reply(200, "[1]"))
	assert_eq(OpenRouterBackend._classify(OpenRouterBackend.STATUS_BAD_GATEWAY), OpenRouterBackend.CLASS_RETRY,
		"which is then retried as a 502")


func test_the_status_table() -> void:
	assert_eq(OpenRouterBackend._classify(200), OpenRouterBackend.CLASS_OK)
	assert_eq(OpenRouterBackend._classify(401), OpenRouterBackend.FATAL_AUTH)
	assert_eq(OpenRouterBackend._classify(402), OpenRouterBackend.FATAL_CREDITS)
	assert_eq(OpenRouterBackend._classify(403), OpenRouterBackend.FATAL_FORBIDDEN)
	for status: int in [400, 404, 413, 422]:
		assert_eq(OpenRouterBackend._classify(status), OpenRouterBackend.FATAL_BAD_REQUEST, str(status))
	for status: int in [408, 429, 500, 502, 503, 524, 529, OpenRouterBackend.STATUS_NONE]:
		assert_eq(OpenRouterBackend._classify(status), OpenRouterBackend.CLASS_RETRY, str(status))


func test_the_backoff_doubles_from_two_seconds() -> void:
	var backend: OpenRouterBackend = _backend()
	var waits: Array[float] = []
	for n: int in range(1, 6):
		waits.append(backend._backoff(n))
	assert_eq(waits, [2.0, 4.0, 8.0, 16.0, 32.0] as Array[float])


func test_a_retry_after_header_is_read_in_seconds() -> void:
	assert_eq(OpenRouterBackend._retry_after({"Retry-After": "7"}), 7.0)
	assert_eq(OpenRouterBackend._retry_after({"retry-after": "soon"}), 0.0)
	assert_eq(OpenRouterBackend._retry_after({}), 0.0)


func test_the_error_string_never_holds_the_key() -> void:
	var backend: OpenRouterBackend = _backend()
	var echoed: String = JSON.stringify({"error": {"code": 400,
		"message": "bad key " + SAMPLE_KEY + " for model"}})
	var text: String = backend._error_text(OpenRouterBackend.FATAL_BAD_REQUEST, 400, echoed)
	assert_false(text.contains(SAMPLE_KEY))
	assert_string_contains(text, OpenRouterBackend.MASK)
	assert_true(text.begins_with(OpenRouterBackend.FATAL_BAD_REQUEST))
	var long: String = JSON.stringify({"error": {"message": "x".repeat(500)}})
	assert_lte(backend._error_text(OpenRouterBackend.FATAL_BAD_REQUEST, 400, long).length(), OpenRouterBackend.ERROR_MAX)
	assert_eq(backend._error_text(OpenRouterBackend.FATAL_AUTH, 401, ""), OpenRouterBackend.FATAL_AUTH)


func test_the_cost_cap_stops_before_a_request() -> void:
	var backend: OpenRouterBackend = _backend()
	backend.spent_usd = 2.0
	var reply: ModelReply = backend.answer([], null, _params())
	assert_true(reply.is_fatal())
	assert_eq(reply.error, OpenRouterBackend.FATAL_COST_CAP)


func test_a_cap_of_zero_stops_a_paid_model_but_not_a_free_one() -> void:
	var paid: OpenRouterBackend = OpenRouterBackend.new("vendor/model", SAMPLE_KEY, "https://openrouter.ai/api/v1",
		_config, 0.0)
	paid.prompt_price = 0.000001
	paid.completion_price = 0.000004
	assert_true(paid.cap_reached(), "a paid model under a cap of 0 asks nothing")
	var unknown: OpenRouterBackend = OpenRouterBackend.new("vendor/model", SAMPLE_KEY, "https://openrouter.ai/api/v1",
		_config, 0.0)
	assert_true(unknown.cap_reached(), "an unknown price is not a free one")
	var free: OpenRouterBackend = OpenRouterBackend.new("vendor/model:free", SAMPLE_KEY,
		"https://openrouter.ai/api/v1", _config, 0.0)
	free.prompt_price = 0.0
	free.completion_price = 0.0
	assert_false(free.cap_reached(), "a free model plays under a cap of 0 (-MaxTotal 0)")
	free.spent_usd = 0.01
	assert_true(free.cap_reached(), "a free model the service bills after all is stopped")


func test_a_base_url_must_be_https_or_this_machine() -> void:
	assert_eq(OpenRouterBackend.parse_base_url("https://openrouter.ai/api/v1"), {"scheme": "https",
		"host": "openrouter.ai", "port": 443, "prefix": "/api/v1"})
	assert_eq(int(OpenRouterBackend.parse_base_url("http://localhost:8080/v1")["port"]), 8080)
	assert_eq(OpenRouterBackend.parse_base_url("http://example.com/v1"), {})
	assert_eq(OpenRouterBackend.parse_base_url("openrouter.ai"), {})
	assert_eq(OpenRouterBackend.parse_base_url("https://user@host/v1"), {})
	var bad: OpenRouterBackend = OpenRouterBackend.new("m", SAMPLE_KEY, "ftp://x", _config, 2.0)
	assert_eq(bad.answer([], null, _params()).error, OpenRouterBackend.FATAL_BAD_BASE_URL)
