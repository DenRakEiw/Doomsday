extends GutTest
## S6.12c — the TypeSafe backend's pure parts (docs/specs/benchmark.md §17.8):
## the body, the headers, the reply reader, the status table, the waits, the
## caps and the error string. **No network**: nothing here opens a connection,
## and no request ever goes to TypeSafe from a test.

const SAMPLE_KEY: String = "ts-sample-not-a-real-key-0123456789"

var _config: BenchConfig = null


func before_each() -> void:
	_config = BenchConfig.load_file()


func _backend(max_cost: float = 2.0, max_requests: int = 3000) -> TypeSafeBackend:
	return TypeSafeBackend.new("jev-latest", SAMPLE_KEY, "https://api.typesafe.ai/v1", _config,
		max_cost, max_requests)


func _plan() -> BenchChoicePlan:
	var plan: BenchChoicePlan = BenchChoicePlan.new()
	plan.state = {"rules": "rules", "situation": "situation"}
	plan.questions = {"stance": {"type": "choice", "instructions": "What?",
		"criteria": {"spread": "Spread", "wait": "Wait"}}}
	plan.keys = {"stance": ["spread", "wait"]}
	return plan


func test_it_is_a_choice_backend_named_typesafe() -> void:
	assert_eq(_backend().kind(), ModelBackend.KIND_CHOICE)
	assert_eq(_backend().backend_id(), "typesafe")


func test_the_body_is_the_model_the_state_and_the_questions_only() -> void:
	var body: Dictionary = _backend().build_body(_plan())
	assert_eq(body.keys(), ["model", "state", "questions"])
	assert_eq(str(body["model"]), "jev-latest")
	assert_eq(body["state"], {"rules": "rules", "situation": "situation"})
	assert_eq((body["questions"] as Dictionary).keys(), ["stance"])


func test_the_key_goes_only_into_the_authorization_header() -> void:
	var headers: PackedStringArray = _backend().build_headers()
	assert_eq(headers.size(), 2)
	assert_eq(headers[0], "Content-Type: application/json")
	assert_eq(headers[1], "Authorization: Bearer " + SAMPLE_KEY)
	assert_false(JSON.stringify(_backend().build_body(_plan())).contains(SAMPLE_KEY))


func test_a_200_reads_the_body_the_tokens_the_version_and_the_cost() -> void:
	var reply: ModelReply = _backend().read_reply(JSON.stringify({"model": "jev-1.13.0",
		"answers": {"stance": {"type": "choice", "choice": "wait",
			"probabilities": {"spread": 0.2, "wait": 0.8}, "confidence": 0.8}},
		"usage": {"input_tokens": 20000, "output_tokens": 50}}))
	assert_not_null(reply)
	assert_false(reply.is_fatal())
	assert_eq(reply.model_version, "jev-1.13.0")
	assert_eq(reply.tokens_in, 20000)
	assert_eq(reply.tokens_out, 50)
	assert_almost_eq(reply.cost_usd, 20000.0 * 0.042 / 1000000.0, 0.0000000001,
		"input at the published price; output free")
	assert_true(reply.body.has("answers"))
	assert_eq(reply.text, "", "a decision model writes no text")


func test_a_charge_reported_through_openrouter_wins_over_the_estimate() -> void:
	var reply: ModelReply = _backend().read_reply(JSON.stringify({"answers": {},
		"usage": {"input_tokens": 20000, "output_tokens": 50, "cost": 0.0021}}))
	assert_almost_eq(reply.cost_usd, 0.0021, 0.0000000001)
	var odd: ModelReply = _backend().read_reply(JSON.stringify({"answers": {},
		"usage": {"input_tokens": 20000, "cost": "free"}}))
	assert_almost_eq(odd.cost_usd, 20000.0 * 0.042 / 1000000.0, 0.0000000001,
		"a charge that is not a number leaves the estimate")


func test_missing_usage_reads_as_nothing() -> void:
	var reply: ModelReply = _backend().read_reply("{\"answers\": {}}")
	assert_eq(reply.tokens_in, 0)
	assert_eq(reply.cost_usd, 0.0)
	assert_eq(reply.model_version, "")


func test_a_200_that_is_not_a_json_object_is_retried_as_a_502() -> void:
	var backend: TypeSafeBackend = _backend()
	assert_null(backend.read_reply("<html>busy</html>"))
	assert_null(backend.read_reply("[1]"))
	assert_eq(TypeSafeBackend.classify(TypeSafeBackend.STATUS_BAD_GATEWAY), TypeSafeBackend.CLASS_RETRY)


func test_the_status_table() -> void:
	assert_eq(TypeSafeBackend.classify(200), TypeSafeBackend.CLASS_OK)
	assert_eq(TypeSafeBackend.classify(401), TypeSafeBackend.FATAL_AUTH)
	assert_eq(TypeSafeBackend.classify(402), TypeSafeBackend.FATAL_CREDITS)
	assert_eq(TypeSafeBackend.classify(403), TypeSafeBackend.FATAL_FORBIDDEN)
	for status: int in [400, 404, 413, 422]:
		assert_eq(TypeSafeBackend.classify(status), TypeSafeBackend.FATAL_BAD_REQUEST, str(status))
	for status: int in [408, 429, 500, 502, 503, 504, 529, TypeSafeBackend.STATUS_NONE]:
		assert_eq(TypeSafeBackend.classify(status), TypeSafeBackend.CLASS_RETRY, str(status))


func test_the_backoff_doubles_from_two_seconds() -> void:
	var backend: TypeSafeBackend = _backend()
	var waits: Array[float] = []
	for n: int in range(1, 6):
		waits.append(backend.backoff(n))
	assert_eq(waits, [2.0, 4.0, 8.0, 16.0, 32.0] as Array[float])


func test_retry_after_and_retry_after_ms_the_larger_wins() -> void:
	assert_eq(TypeSafeBackend.retry_after({"Retry-After": "7"}), 7.0)
	assert_eq(TypeSafeBackend.retry_after({"retry-after-ms": "2500"}), 2.5)
	assert_eq(TypeSafeBackend.retry_after({"Retry-After": "1", "retry-after-ms": "4000"}), 4.0)
	assert_eq(TypeSafeBackend.retry_after({"retry-after": "soon"}), 0.0)
	assert_eq(TypeSafeBackend.retry_after({}), 0.0)


func test_the_cost_cap_and_the_request_cap_stop_before_a_request() -> void:
	var spent: TypeSafeBackend = _backend()
	spent.spent_usd = 2.0
	var reply: ModelReply = spent.choose(_plan(), null, {})
	assert_true(reply.is_fatal())
	assert_eq(reply.error, TypeSafeBackend.FATAL_COST_CAP)
	var counted: TypeSafeBackend = _backend(2.0, 5)
	counted.requests_sent = 5
	reply = counted.choose(_plan(), null, {})
	assert_true(reply.is_fatal())
	assert_eq(reply.error, TypeSafeBackend.FATAL_REQUEST_CAP)
	assert_eq(counted.requests_sent, 5, "nothing was sent")


func test_a_bad_base_url_is_fatal_without_a_request() -> void:
	var bad: TypeSafeBackend = TypeSafeBackend.new("jev-latest", SAMPLE_KEY, "ftp://x", _config, 2.0, 3000)
	assert_eq(bad.choose(_plan(), null, {}).error, TypeSafeBackend.FATAL_BAD_BASE_URL)
	assert_eq(bad.requests_sent, 0)


func test_a_bad_request_names_the_services_message_never_the_key() -> void:
	var backend: TypeSafeBackend = _backend()
	var text: String = backend.error_text(TypeSafeBackend.FATAL_BAD_REQUEST, 422,
		JSON.stringify({"detail": "state too long for " + SAMPLE_KEY}))
	assert_true(text.begins_with("bad_request: 422 state too long"))
	assert_false(text.contains(SAMPLE_KEY))
	assert_string_contains(text, TypeSafeBackend.MASK)
	assert_string_contains(backend.error_text(TypeSafeBackend.FATAL_BAD_REQUEST, 400,
		JSON.stringify({"error": {"message": "no such model"}})), "no such model")
	assert_eq(backend.error_text(TypeSafeBackend.FATAL_BAD_REQUEST, 404, "<html>"), "bad_request: 404")
	var long: String = JSON.stringify({"message": "x".repeat(500)})
	assert_lte(backend.error_text(TypeSafeBackend.FATAL_BAD_REQUEST, 400, long).length(),
		TypeSafeBackend.ERROR_MAX)
	assert_eq(backend.error_text(TypeSafeBackend.FATAL_AUTH, 401, SAMPLE_KEY), TypeSafeBackend.FATAL_AUTH)
