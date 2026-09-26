extends GutTest
## S6.12c — the decision-model mock (docs/specs/benchmark.md §17.10): each mode's
## service-shaped body, `shuffled`'s reproducibility, `broken`'s call pattern.

const PARAMS: Dictionary = {"choice_version": 1,
	"max_picks": {"buy": 3, "use": 2, "wake": 2, "sleep": 2}, "seed": 1001}


func _plan() -> BenchChoicePlan:
	var plan: BenchChoicePlan = BenchChoicePlan.new()
	for question: String in ["stance", "origin", "buy", "site_n1"]:
		var keys: Array = []
		match question:
			"stance":
				keys = BenchAnswer.STANCES.duplicate()
			"origin":
				keys = ["r_a", "r_b", "r_c"]
			"buy":
				keys = ["n1", "n2", "none"]
			"site_n1":
				keys = ["r_b", "r_c"]
		plan.keys[question] = keys
		plan.questions[question] = {"type": "choice", "instructions": question, "criteria": {}}
	plan.deploying = ["n1"] as Array[String]
	return plan


func _digest(day: int = 0) -> BenchDigest:
	var digest: BenchDigest = BenchDigest.new()
	digest.day = day
	return digest


func _body(mode: String, params: Dictionary = PARAMS, day: int = 0) -> Dictionary:
	var backend: MockChoiceBackend = MockChoiceBackend.new(mode)
	var reply: ModelReply = backend.choose(_plan(), _digest(day), params)
	assert_false(reply.is_fatal())
	assert_eq(reply.model_version, MockChoiceBackend.MODEL_VERSION)
	assert_eq(reply.tokens_in, 0)
	assert_eq(reply.cost_usd, 0.0)
	return reply.body


func _ranking(body: Dictionary, question: String) -> Array[String]:
	var read: BenchChoiceRead = BenchChoice.read(body, _plan())
	var out: Array[String] = []
	out.assign(read.rankings.get(question, []))
	return out


func test_the_id_names_the_mode_and_only_known_modes_read() -> void:
	assert_eq(MockChoiceBackend.new("idle").backend_id(), "mock-choice:idle")
	assert_eq(MockChoiceBackend.new().kind(), ModelBackend.KIND_CHOICE)
	assert_eq(MockChoiceBackend.mode_of("mock-choice:shuffled"), "shuffled")
	assert_eq(MockChoiceBackend.mode_of("mock-choice:loud"), "")
	assert_eq(MockChoiceBackend.mode_of("mock:cheapest"), "")


func test_the_body_is_shaped_like_the_service() -> void:
	var body: Dictionary = _body(MockChoiceBackend.MODE_FIRST)
	assert_eq(str(body["model"]), MockChoiceBackend.MODEL_VERSION)
	assert_eq(body["usage"], {"input_tokens": 0, "output_tokens": 0})
	var answer: Dictionary = (body["answers"] as Dictionary)["buy"]
	assert_eq(str(answer["type"]), "choice")
	var total: float = 0.0
	for key: Variant in answer["probabilities"]:
		total += float((answer["probabilities"] as Dictionary)[key])
	assert_almost_eq(total, 1.0, 0.000001)
	assert_eq(str(answer["choice"]), "n1", "the choice is the top probability")


func test_first_takes_the_plan_order_and_spread() -> void:
	var body: Dictionary = _body(MockChoiceBackend.MODE_FIRST)
	assert_eq(_ranking(body, "stance")[0], "spread")
	assert_eq(_ranking(body, "origin"), ["r_a", "r_b", "r_c"] as Array[String])
	assert_eq(_ranking(body, "buy"), ["n1", "n2", "none"] as Array[String], "none last")


func test_idle_does_nothing_but_choose_an_origin() -> void:
	var body: Dictionary = _body(MockChoiceBackend.MODE_IDLE)
	assert_eq(_ranking(body, "stance")[0], "wait")
	assert_eq(_ranking(body, "buy")[0], "none")
	assert_eq(_ranking(body, "origin")[0], "r_a")


func test_shuffled_is_the_same_for_one_seed_and_day_and_differs_for_another_seed() -> void:
	var first: Dictionary = _body(MockChoiceBackend.MODE_SHUFFLED)
	assert_eq(_body(MockChoiceBackend.MODE_SHUFFLED), first)
	var other_seed: Dictionary = PARAMS.duplicate(true)
	other_seed["seed"] = 1002
	assert_ne(_body(MockChoiceBackend.MODE_SHUFFLED, other_seed), first)
	assert_ne(_body(MockChoiceBackend.MODE_SHUFFLED, PARAMS, 10), first, "another day")


func test_broken_fails_every_third_call_and_leaves_out_buy_every_fourth() -> void:
	var backend: MockChoiceBackend = MockChoiceBackend.new(MockChoiceBackend.MODE_BROKEN)
	var plan: BenchChoicePlan = _plan()
	var errors: Array[String] = []
	var problems: Array[int] = []
	for _call: int in 8:
		var read: BenchChoiceRead = BenchChoice.read(
			backend.choose(plan, _digest(), PARAMS).body, plan)
		errors.append(read.error)
		problems.append(read.problems.size())
	assert_eq(errors, ["", "", "bad_reply", "", "", "bad_reply", "", ""] as Array[String])
	assert_eq(problems, [0, 0, 0, 2, 0, 0, 0, 2] as Array[int],
		"buy missing and an unknown stance on calls 4 and 8")
