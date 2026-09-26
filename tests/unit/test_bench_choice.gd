extends GutTest
## S6.12c — a decision model's request, reply and answer (docs/specs/benchmark.md
## §17.3, §17.5, §17.6): the plan offers only legal moves (fixture world, and a
## 300-day `mock-choice:shuffled` run on the real content), the reader ranks, the
## combiner walks the compute. No request to any service.

const Harness := preload("res://tools/sim_harness.gd")
const PARAMS: Dictionary = {"choice_version": 1,
	"max_picks": {"buy": 3, "use": 2, "wake": 2, "sleep": 2}}
const QUESTION_ID_PATTERN: String = "^[a-z0-9_]+$"
const LEGALITY_DAYS: int = 300
const LEGALITY_SEED: int = 1001


## A decision model that checks, before answering, that every key of every plan
## stands for a command the simulation accepts at planning time.
class Checker:
	extends MockChoiceBackend
	var sim: Simulation = null
	var failures: Array[String] = []
	var question_ids: Array[String] = []
	var plans: int = 0

	func choose(plan: BenchChoicePlan, digest: BenchDigest, params: Dictionary) -> ModelReply:
		plans += 1
		for question: String in plan.keys:
			if not question_ids.has(question):
				question_ids.append(question)
		failures.append_array(illegal_keys(sim, plan))
		return super(plan, digest, params)

	## Every key of `plan` whose command `simulation` would refuse now, as `question:key`.
	static func illegal_keys(simulation: Simulation, plan: BenchChoicePlan) -> Array[String]:
		var out: Array[String] = []
		for question: String in plan.keys:
			for key: String in plan.keys_of(question):
				if not _legal(simulation, plan, question, key):
					out.append("day %d %s:%s" % [simulation.world.day, question, key])
		return out

	static func _legal(simulation: Simulation, plan: BenchChoicePlan, question: String,
			key: String) -> bool:
		if BenchChoice.CONTROL_KEYS.has(key):
			return question != BenchChoice.Q_STANCE and question != BenchChoice.Q_ORIGIN
		if question == BenchChoice.Q_STANCE:
			return BenchAnswer.STANCES.has(key)
		if question == BenchChoice.Q_ORIGIN:
			return simulation.can_apply(ChooseOriginCommand.new(key)).is_empty()
		if question.begins_with(BenchChoice.PREFIX_EVENT):
			var event: int = question.trim_prefix(BenchChoice.PREFIX_EVENT).to_int()
			return simulation.can_apply(ChooseEventOptionCommand.new(event, key)).is_empty()
		if question == BenchChoice.Q_WAKE or question == BenchChoice.Q_SLEEP:
			var sleeping: bool = question == BenchChoice.Q_SLEEP
			return simulation.can_apply(SetDormancyCommand.new(key, sleeping)).is_empty()
		if question == BenchChoice.Q_USE:
			if plan.regional.has(key):
				return not plan.keys_of(BenchChoice.PREFIX_TARGET + key).is_empty()
			return simulation.can_apply(UseAbilityCommand.new(key, "")).is_empty()
		if question.begins_with(BenchChoice.PREFIX_TARGET):
			var ability: String = question.trim_prefix(BenchChoice.PREFIX_TARGET)
			return simulation.can_apply(UseAbilityCommand.new(ability, key)).is_empty()
		if question == BenchChoice.Q_BUY:
			if plan.deploying.has(key):
				return not plan.keys_of(BenchChoice.PREFIX_SITE + key).is_empty()
			return simulation.can_apply(PurchaseNodeCommand.new(key, "")).is_empty()
		if question.begins_with(BenchChoice.PREFIX_SITE):
			var node: String = question.trim_prefix(BenchChoice.PREFIX_SITE)
			return simulation.can_apply(PurchaseNodeCommand.new(node, key)).is_empty()
		return false


var _config: BenchConfig = null


func before_each() -> void:
	_config = BenchConfig.load_file()


func _digest(sim: Simulation) -> BenchDigest:
	return BenchDigest.build(sim, BenchDigest.new_memory(), _config)


func _plan(sim: Simulation) -> BenchChoicePlan:
	return BenchChoice.plan(sim, _digest(sim), "rules", "situation", _config)


## A plan built by hand, for the reader and the combiner.
func _synthetic() -> BenchChoicePlan:
	var plan: BenchChoicePlan = BenchChoicePlan.new()
	plan.state = {"rules": "r", "situation": "s"}
	_add(plan, "stance", ["spread", "hide", "wait"])
	_add(plan, "event_7", ["grab", "seed", "later"])
	plan.costs["event_7"] = {"grab": 0.0, "seed": 4.0}
	_add(plan, "wake", ["r_a", "r_b", "none"])
	_add(plan, "sleep", ["r_c", "none"])
	_add(plan, "use", ["zap", "hush", "none"])
	plan.costs["use"] = {"zap": 2.0, "hush": 1.0}
	plan.regional = ["zap"] as Array[String]
	_add(plan, "target_zap", ["r_a", "r_b"])
	_add(plan, "buy", ["n1", "n2", "n3", "n4", "none"])
	plan.costs["buy"] = {"n1": 1.0, "n2": 1.0, "n3": 1.0, "n4": 1.0}
	plan.deploying = ["n2"] as Array[String]
	_add(plan, "site_n2", ["r_a", "r_b"])
	return plan


func _add(plan: BenchChoicePlan, question: String, keys: Array) -> void:
	var criteria: Dictionary = {}
	for key: Variant in keys:
		criteria[key] = str(key)
	plan.questions[question] = {"type": "choice", "instructions": question, "criteria": criteria}
	plan.keys[question] = keys.duplicate()


## The service's reply for the synthetic plan: every question answered as
## `probabilities` says, the rest as the defaults below.
func _body(overrides: Dictionary = {}, leave_out: Array = []) -> Dictionary:
	var probabilities: Dictionary = {
		"stance": {"hide": 0.6, "spread": 0.3, "wait": 0.1},
		"event_7": {"seed": 0.7, "grab": 0.2, "later": 0.1},
		"wake": {"r_b": 0.5, "r_a": 0.3, "none": 0.2},
		"sleep": {"none": 0.9, "r_c": 0.1},
		"use": {"zap": 0.5, "hush": 0.3, "none": 0.2},
		"target_zap": {"r_b": 0.8, "r_a": 0.2},
		"buy": {"n2": 0.4, "n1": 0.3, "n3": 0.2, "n4": 0.05, "none": 0.05},
		"site_n2": {"r_a": 0.9, "r_b": 0.1},
	}
	probabilities.merge(overrides, true)
	var answers: Dictionary = {}
	for question: String in probabilities:
		if leave_out.has(question):
			continue
		answers[question] = {"type": "choice", "choice": "", "confidence": 0.5,
			"probabilities": probabilities[question]}
	return {"model": "jev-test", "answers": answers,
		"usage": {"input_tokens": 10, "output_tokens": 2}}


func _event_digest(compute: float) -> BenchDigest:
	var digest: BenchDigest = BenchDigest.new()
	digest.compute = compute
	var row: BenchEventRow = BenchEventRow.new()
	row.event = 7
	digest.events.append(row)
	return digest


func _combine(body: Dictionary, compute: float = 10.0, params: Dictionary = PARAMS,
		max_actions: int = 12) -> BenchAnswer:
	var plan: BenchChoicePlan = _synthetic()
	return BenchChoice.combine(plan, BenchChoice.read(body, plan), _event_digest(compute), params,
		max_actions)


func _compact(answer: BenchAnswer) -> Array[String]:
	var out: Array[String] = []
	for action: BenchAction in answer.actions:
		out.append(action.compact())
	return out


# --- the plan (fixture world) ---


func test_before_the_origin_the_plan_is_the_stance_and_the_origin() -> void:
	var sim: Simulation = Fixtures.sim()
	var digest: BenchDigest = _digest(sim)
	var plan: BenchChoicePlan = BenchChoice.plan(sim, digest, "rules", "situation", _config)
	assert_eq(plan.questions.keys(), ["stance", "origin"])
	assert_eq(plan.keys_of("origin"), digest.origins)
	assert_eq(plan.keys_of("stance"), BenchAnswer.STANCES)
	assert_eq(plan.state, {"rules": "rules", "situation": "situation"})
	assert_eq(plan.body("jev-latest").keys(), ["model", "state", "questions"])


func test_buy_offers_exactly_the_affordable_offers_with_a_legal_command_then_none() -> void:
	var sim: Simulation = Fixtures.sim_with_origin("fx_alder")
	Fixtures.grant(sim, 20.0)
	var digest: BenchDigest = _digest(sim)
	var expected: Array[String] = []
	for offer: BenchOfferRow in digest.offers:
		if not offer.affordable:
			continue
		var legal: bool = offer.sites.is_empty() \
			and sim.can_apply(PurchaseNodeCommand.new(offer.node, "")).is_empty()
		for site: String in offer.sites:
			legal = legal or sim.can_apply(PurchaseNodeCommand.new(offer.node, site)).is_empty()
		if legal:
			expected.append(offer.node)
	assert_gt(expected.size(), 1, "the fixture offers several nodes")
	expected.append("none")
	var plan: BenchChoicePlan = BenchChoice.plan(sim, digest, "r", "s", _config)
	assert_eq(plan.keys_of("buy"), expected)


func test_a_deploying_node_gets_a_site_question_with_only_legal_sites() -> void:
	var sim: Simulation = Fixtures.sim_with_origin("fx_alder")
	Fixtures.grant(sim, 20.0)
	var plan: BenchChoicePlan = _plan(sim)
	assert_true(plan.deploying.has(Fixtures.DEPLOY_FLEET_NODE))
	var sites: Array[String] = plan.keys_of("site_" + Fixtures.DEPLOY_FLEET_NODE)
	assert_false(sites.is_empty())
	for site: String in sites:
		assert_eq(sim.can_apply(PurchaseNodeCommand.new(Fixtures.DEPLOY_FLEET_NODE, site)), "",
			site)
	assert_true(plan.questions.keys().find("site_" + Fixtures.DEPLOY_FLEET_NODE)
		> plan.questions.keys().find("buy"), "asked after buy")


func test_a_region_ability_gets_a_target_question_with_only_legal_targets() -> void:
	var sim: Simulation = Fixtures.sim_with_origin("fx_alder")
	Fixtures.grant(sim, 30.0)
	Fixtures.buy(sim, ["fx_vector_net", "fx_reach", "fx_zap_1"] as Array[String])
	sim.world.regions[sim.db.region_index_by_id["fx_birch"]].penetration = 0.2
	var plan: BenchChoicePlan = _plan(sim)
	assert_true(plan.keys_of("use").has(Fixtures.ZAP_ABILITY))
	assert_true(plan.regional.has(Fixtures.ZAP_ABILITY))
	var targets: Array[String] = plan.keys_of("target_" + Fixtures.ZAP_ABILITY)
	assert_true(targets.has("fx_birch"))
	for target: String in targets:
		assert_eq(sim.can_apply(UseAbilityCommand.new(Fixtures.ZAP_ABILITY, target)), "", target)


func test_an_ability_cooling_down_or_too_dear_is_not_offered() -> void:
	var sim: Simulation = Fixtures.sim_with_origin("fx_alder")
	Fixtures.grant(sim, 30.0)
	Fixtures.buy(sim, ["fx_vector_net", "fx_reach", "fx_zap_1"] as Array[String])
	sim.world.regions[sim.db.region_index_by_id["fx_birch"]].penetration = 0.2
	sim.world.agent.compute = 1.0
	assert_false(_plan(sim).keys_of("use").has(Fixtures.ZAP_ABILITY), "too dear")
	sim.world.agent.compute = 30.0
	assert_true(_plan(sim).keys_of("use").has(Fixtures.ZAP_ABILITY), "ready and affordable")
	Fixtures.use(sim, Fixtures.ZAP_ABILITY, "fx_birch")
	assert_false(_plan(sim).keys_of("use").has(Fixtures.ZAP_ABILITY), "cooling down")


func test_a_locked_and_a_short_event_option_are_not_offered_later_is() -> void:
	var sim: Simulation = Fixtures.sim_with_origin("fx_alder")
	sim.world.agent.compute = 0.0
	var event: OpenEvent = Fixtures.open_event(sim, Fixtures.OPENING_EVENT, "fx_alder")
	var plan: BenchChoicePlan = _plan(sim)
	var question: String = "event_%d" % event.id
	assert_eq(plan.keys_of(question), ["grab", "pass", "later"] as Array[String],
		"seed is short, locked is locked")
	var criteria: Dictionary = (plan.questions[question] as Dictionary)["criteria"]
	assert_string_contains(str(criteria["later"]),
		EventView.option_text(Fixtures.OPENING_EVENT, "pass"), "later names the default")
	assert_eq(plan.cost_of(question, "grab"), 0.0)


func test_a_question_with_no_legal_option_is_left_out() -> void:
	var sim: Simulation = Fixtures.sim_with_origin("fx_alder")
	sim.world.agent.compute = 0.0
	var plan: BenchChoicePlan = _plan(sim)
	assert_false(plan.questions.has("buy"), "nothing is affordable")
	assert_false(plan.questions.has("use"), "no ability")
	assert_true(plan.questions.has("stance"), "the stance is always asked")
	for question: String in plan.keys:
		var real: int = 0
		for key: String in plan.keys_of(question):
			real += 0 if BenchChoice.CONTROL_KEYS.has(key) else 1
		assert_gt(real, 0, question)


func test_past_the_cap_the_first_keys_and_the_control_key_are_kept() -> void:
	var plan: BenchChoicePlan = BenchChoicePlan.new()
	var keys: Array[String] = []
	for i: int in 300:
		keys.append("k%d" % i)
	assert_true(BenchChoice._ask(plan, "buy", "Which?", keys, {}, "none", "Nothing", _config))
	var kept: Array[String] = plan.keys_of("buy")
	assert_eq(kept.size(), 255)
	assert_eq(kept[253], "k253")
	assert_eq(kept[254], "none")
	assert_eq(((plan.questions["buy"] as Dictionary)["criteria"] as Dictionary).size(), 255)
	var plain: BenchChoicePlan = BenchChoicePlan.new()
	BenchChoice._ask(plain, "origin", "Where?", keys, {}, "", "", _config)
	assert_eq(plain.keys_of("origin").size(), 255, "no control key: 255 options")


func test_planning_changes_nothing_and_two_plans_of_one_state_are_equal() -> void:
	var sim: Simulation = Fixtures.sim_with_origin("fx_alder")
	Fixtures.open_event(sim, Fixtures.OPENING_EVENT, "fx_alder")
	Fixtures.grant(sim, 20.0)
	for i: int in 10:
		sim.tick()
	var hash_before: String = sim.state_hash()
	var log_before: int = sim.command_log.size()
	var first: BenchChoicePlan = _plan(sim)
	var second: BenchChoicePlan = _plan(sim)
	assert_eq(sim.state_hash(), hash_before)
	assert_eq(sim.command_log.size(), log_before)
	assert_eq(JSON.stringify(first.body("m")), JSON.stringify(second.body("m")))
	assert_eq(first.keys, second.keys)


# --- the plan (real content) ---


func test_every_key_of_a_shuffled_run_is_legal_when_it_is_offered() -> void:
	var db: ContentDB = ContentLoader.load_root("res://data").db
	var setup: RunSetup = RunSetup.from_dict(_config.setup)
	var sim: Simulation = Simulation.create(db, LEGALITY_SEED, setup)
	var checker: Checker = Checker.new(MockChoiceBackend.MODE_SHUFFLED)
	checker.sim = sim
	var policy: ModelPolicy = ModelPolicy.new(checker, _config, BenchChoice.params_of(_config),
		"en")
	policy.setup(db, Policy.seed_for(LEGALITY_SEED))
	var problems: Array[String] = []
	assert_eq(Harness.advance(sim, policy, LEGALITY_DAYS, false, problems), 0,
		"the harness sees no rejection")
	assert_gt(checker.plans, 20, "a run's worth of decisions")
	assert_eq(checker.failures, [] as Array[String])
	var pattern: RegEx = RegEx.create_from_string(QUESTION_ID_PATTERN)
	assert_gt(checker.question_ids.size(), 4, "more than the day-0 questions")
	for question: String in checker.question_ids:
		assert_not_null(pattern.search(question), question)
	assert_gt(sim.command_log.size(), 10, "it played")


func test_no_content_id_is_a_control_key() -> void:
	var db: ContentDB = ContentLoader.load_root("res://data").db
	var ids: Array[String] = []
	for node: TechNodeDef in db.tech_nodes:
		ids.append(node.id)
	for ability: AbilityDef in db.abilities:
		ids.append(ability.id)
	for i: int in range(1, db.regions.size()):
		ids.append(db.regions[i].id)
	for event: EventDef in db.events:
		for option: EventOptionDef in event.options:
			ids.append(option.id)
	ids.append_array(BenchAnswer.STANCES)
	assert_gt(ids.size(), 200)
	for control: String in BenchChoice.CONTROL_KEYS:
		assert_false(ids.has(control), control)


# --- the reader ---


func test_the_ranking_follows_the_probabilities_ties_in_plan_order() -> void:
	var plan: BenchChoicePlan = _synthetic()
	var read: BenchChoiceRead = BenchChoice.read(_body({
		"stance": {"spread": 0.25, "hide": 0.5, "wait": 0.25, "nuke": 0.9}}), plan)
	assert_eq(read.error, "")
	assert_eq(read.rankings["stance"], ["hide", "spread", "wait"] as Array[String],
		"nuke is not offered")


func test_a_probability_out_of_range_counts_nothing() -> void:
	var read: BenchChoiceRead = BenchChoice.read(_body({
		"stance": {"spread": 0.2, "hide": 1.5, "wait": "high"}}), _synthetic())
	assert_eq(read.rankings["stance"], ["spread", "hide", "wait"] as Array[String])


func test_all_zero_with_a_valid_choice_ranks_the_choice_first() -> void:
	var plan: BenchChoicePlan = _synthetic()
	var body: Dictionary = _body()
	(body["answers"] as Dictionary)["stance"] = {"choice": "wait", "probabilities": {}}
	var read: BenchChoiceRead = BenchChoice.read(body, plan)
	assert_eq(read.rankings["stance"], ["wait", "spread", "hide"] as Array[String])
	assert_eq(read.problems, [] as Array[Dictionary])


func test_an_unknown_choice_is_a_problem_and_the_question_unanswered() -> void:
	var body: Dictionary = _body()
	(body["answers"] as Dictionary)["stance"] = {"choice": "nuke",
		"probabilities": {"spread": 0.0}}
	var read: BenchChoiceRead = BenchChoice.read(body, _synthetic())
	assert_false(read.answered("stance"))
	assert_eq(read.problems, [{"reason": "unknown_choice", "question": "stance"}] \
		as Array[Dictionary])


func test_a_missing_answer_is_a_problem() -> void:
	var read: BenchChoiceRead = BenchChoice.read(_body({}, ["buy"]), _synthetic())
	assert_false(read.answered("buy"))
	assert_eq(read.problems, [{"reason": "missing_answer", "question": "buy"}] \
		as Array[Dictionary])


func test_no_answers_is_a_bad_reply() -> void:
	for body: Dictionary in [{}, {"answers": []}, {"answers": "x", "model": "jev"}]:
		var read: BenchChoiceRead = BenchChoice.read(body, _synthetic())
		assert_eq(read.error, BenchChoice.ERROR_BAD_REPLY, str(body))


func test_confidence_and_the_model_version_are_kept() -> void:
	var read: BenchChoiceRead = BenchChoice.read(_body(), _synthetic())
	assert_eq(read.model_version, "jev-test")
	assert_almost_eq(read.confidence["stance"], 0.5, 0.0001)


# --- the combiner ---


func test_the_answer_follows_the_order_and_walks_the_compute() -> void:
	var answer: BenchAnswer = _combine(_body())
	assert_true(answer.valid)
	assert_eq(answer.stance, "hide")
	assert_eq(_compact(answer), ["answer 7 seed", "wake r_b", "wake r_a", "use zap r_b",
		"use hush", "buy n2 r_a", "buy n1", "buy n3"] as Array[String])
	assert_eq(answer.dropped, [] as Array[Dictionary])


func test_what_the_compute_no_longer_covers_is_left_out_silently() -> void:
	var answer: BenchAnswer = _combine(_body(), 5.0)
	assert_eq(_compact(answer), ["answer 7 seed", "wake r_b", "wake r_a", "use hush"] \
		as Array[String])
	assert_eq(answer.dropped, [] as Array[Dictionary])


func test_multi_picks_stop_at_the_control_key_and_at_max_picks() -> void:
	var params: Dictionary = PARAMS.duplicate(true)
	(params["max_picks"] as Dictionary)["buy"] = 1
	var answer: BenchAnswer = _combine(_body({"wake": {"none": 0.6, "r_a": 0.4}}), 10.0, params)
	var actions: Array[String] = _compact(answer)
	assert_false(actions.has("wake r_a"), "ranked below doing nothing")
	assert_eq(actions.filter(func(a: String) -> bool: return a.begins_with("buy")),
		["buy n2 r_a"] as Array[String], "one purchase at most")
	assert_false(actions.has("sleep r_c"))


func test_later_gives_nothing() -> void:
	var answer: BenchAnswer = _combine(_body({"event_7": {"later": 0.8, "seed": 0.2}}))
	assert_false(_compact(answer).has("answer 7 seed"))
	assert_eq(_compact(answer)[0], "wake r_b")


func test_an_unanswered_target_skips_its_ability_with_one_problem() -> void:
	var answer: BenchAnswer = _combine(_body({}, ["target_zap"]))
	var actions: Array[String] = _compact(answer)
	assert_false(actions.has("use zap r_b"))
	assert_true(actions.has("use hush"))
	assert_eq(answer.dropped, [{"index": -1, "reason": "missing_answer",
		"question": "target_zap"}] as Array[Dictionary])


func test_problems_land_in_dropped_with_their_question() -> void:
	var body: Dictionary = _body({}, ["buy"])
	(body["answers"] as Dictionary)["stance"] = {"choice": "nuke", "probabilities": {}}
	var answer: BenchAnswer = _combine(body)
	assert_eq(answer.stance, "", "an unanswered stance is none")
	assert_eq(answer.dropped, [
		{"index": -1, "reason": "unknown_choice", "question": "stance"},
		{"index": -1, "reason": "missing_answer", "question": "buy"},
	] as Array[Dictionary])
	assert_false(_compact(answer).has("buy n1"))


func test_actions_past_the_limit_are_dropped_over_limit() -> void:
	var answer: BenchAnswer = _combine(_body(), 10.0, PARAMS, 3)
	assert_eq(answer.actions.size(), 3)
	assert_eq(answer.dropped.size(), 5)
	assert_eq(answer.dropped[0], {"index": 3, "reason": BenchAnswer.ACTION_OVER_LIMIT})


func test_the_cache_round_trip_keeps_the_answer_and_its_questions() -> void:
	var body: Dictionary = _body({}, ["buy"])
	var answer: BenchAnswer = _combine(body)
	var back: BenchAnswer = BenchAnswer.from_cache(
		JSON.parse_string(JSON.stringify(answer.to_cache())))
	assert_not_null(back)
	assert_true(answer.equals(back))
	assert_eq(str(back.dropped[0]["question"]), "buy")
