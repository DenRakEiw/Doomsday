extends GutTest
## S6.12 — the model policy (docs/specs/benchmark.md §4, §7.4) on the fixture
## world with mock backends: when it decides, what it does with an answer, the
## budget, and that its runs replay. No randomness of its own: the world's seed
## is fixed per test.

const Harness := preload("res://tools/sim_harness.gd")


## A mock that also writes down what it was asked, and when.
class Recorder:
	extends MockBackend
	var days: Array[int] = []
	var digests: Array[BenchDigest] = []
	var messages_seen: Array = []

	func answer(messages: Array[Dictionary], digest: BenchDigest, params: Dictionary) -> ModelReply:
		days.append(digest.day)
		digests.append(digest)
		messages_seen.append(messages)
		return super(messages, digest, params)


## Always the same answer.
class Fixed:
	extends ModelBackend
	var text: String = ""
	var digests: Array[BenchDigest] = []

	func _init(p_text: String) -> void:
		text = p_text

	func answer(_messages: Array[Dictionary], digest: BenchDigest, _params: Dictionary) -> ModelReply:
		digests.append(digest)
		return ModelReply.ok(text)

	func backend_id() -> String:
		return "fixed"


static var _quiet: ContentDB = null

var _config: BenchConfig = null


func before_each() -> void:
	_config = BenchConfig.load_file()


## The fixture world with no event that opens by itself and no counter-move: a
## decision there comes from the rhythm or from what a test does.
static func quiet_db() -> ContentDB:
	if _quiet == null:
		var content: Dictionary = Fixtures.raw_content()
		Fixtures.drop_moves(content)
		var file: Dictionary = (content["events"] as Array)[0]
		var kept: Array = []
		for entry: Variant in file["events"]:
			var event: Dictionary = entry
			if str(event["kind"]) == EventDef.KIND_COUNTER_MOVE:
				continue
			if event.has("when"):
				event["when"] = {"regions_min": 99}
			kept.append(event)
		file["events"] = kept
		var result: ContentLoadResult = Fixtures.load_raw(content)
		assert(result.ok(), result.error_text())
		_quiet = result.db
	return _quiet


func _policy(backend: ModelBackend, sim: Simulation) -> ModelPolicy:
	var params: Dictionary = {"temperature": 0.0, "max_completion_tokens": 1200, "json_mode": true,
		"reasoning": "", "top_p": -1.0}
	var policy: ModelPolicy = ModelPolicy.new(backend, _config, params, "en")
	policy.setup(sim.db, Policy.seed_for(1))
	return policy


## Plays up to `until_day`; returns the harness's rejected count.
func _play(sim: Simulation, policy: Policy, until_day: int) -> int:
	var problems: Array[String] = []
	return Harness.advance(sim, policy, until_day, false, problems)


func test_it_decides_on_day_zero_then_every_interval_without_events() -> void:
	var sim: Simulation = Simulation.create(quiet_db(), 1)
	var backend: Recorder = Recorder.new(MockBackend.MODE_CHEAPEST)
	var policy: ModelPolicy = _policy(backend, sim)
	assert_eq(_play(sim, policy, 45), 0)
	assert_eq(backend.days, [0, 10, 20, 30, 40] as Array[int])
	assert_eq(policy.decisions.size(), 5)
	assert_ne(sim.world.agent.origin, 0, "the first decision chose the origin")


func test_an_event_opening_mid_interval_triggers_one_decision_that_day() -> void:
	var sim: Simulation = Simulation.create(quiet_db(), 1)
	var backend: Recorder = Recorder.new(MockBackend.MODE_WAIT)
	var policy: ModelPolicy = _policy(backend, sim)
	_play(sim, policy, 3)
	var event: OpenEvent = Fixtures.open_event(sim, Fixtures.OPENING_EVENT,
		sim.db.regions[sim.world.agent.origin].id)
	_play(sim, policy, 9)
	assert_eq(backend.days, [0, 3] as Array[int])
	assert_eq(backend.digests[1].events.size(), 1)
	assert_eq(backend.digests[1].events[0].event, event.id)


func test_the_task_force_setting_up_where_the_agent_is_triggers_one_decision() -> void:
	var sim: Simulation = Simulation.create(quiet_db(), 1)
	var backend: Recorder = Recorder.new(MockBackend.MODE_WAIT)
	var policy: ModelPolicy = _policy(backend, sim)
	_play(sim, policy, 4)
	var team: TaskForce = sim.world.task_force
	team.state = TaskForce.STATE_SETUP
	team.region = sim.world.agent.origin
	team.action = "probe"
	team.level = 1
	_play(sim, policy, 5)
	assert_eq(backend.days, [0, 4] as Array[int])
	team.state = TaskForce.STATE_SETUP
	team.region = sim.world.agent.origin
	team.action = "probe"
	_play(sim, policy, 6)
	assert_eq(backend.days, [0, 4] as Array[int], "the same setup asks nothing again")


func test_anomalies_are_collected_every_day_without_a_call() -> void:
	var sim: Simulation = Fixtures.sim_with_certain_anomalies()
	var backend: Recorder = Recorder.new(MockBackend.MODE_WAIT)
	var policy: ModelPolicy = _policy(backend, sim)
	assert_eq(_play(sim, policy, 9), 0)
	assert_eq(policy.calls, 1, "only day 0's decision")
	var days: Dictionary = {}
	for command: Command in sim.command_log:
		if command is CollectAnomalyCommand:
			days[command.day] = true
	assert_gt(days.size(), 3, "collected on many days")


func test_a_refused_action_is_skipped_counted_and_fed_back() -> void:
	var sim: Simulation = Fixtures.sim_with_origin("fx_alder")
	var backend: Fixed = Fixed.new(
		"{\"stance\": \"spread\", \"actions\": [{\"do\": \"wake\", \"region\": \"nowhere\"}]}")
	var policy: ModelPolicy = _policy(backend, sim)
	assert_eq(_play(sim, policy, 11), 0, "the harness sees no rejection")
	assert_eq(policy.rejected_actions, 2)
	var first: BenchDecision = policy.decisions[0]
	assert_eq(first.actions, 1)
	assert_eq(first.done, 0)
	var expected: Array[Dictionary] = [{"action": "wake nowhere",
		"reason": Command.FAIL_INVALID_REGION}]
	assert_eq(first.refused, expected)
	assert_eq(backend.digests[1].feedback, first)
	var text: String = BenchPrompt.digest_text(backend.digests[1], sim.db)
	assert_string_contains(text, "wake nowhere")
	assert_string_contains(text, Command.FAIL_INVALID_REGION)


func test_a_dropped_action_is_counted_and_fed_back_with_its_reason() -> void:
	var sim: Simulation = Fixtures.sim_with_origin("fx_alder")
	var policy: ModelPolicy = _policy(Fixed.new("{\"actions\": [{\"do\": \"nuke\"}]}"), sim)
	_play(sim, policy, 1)
	assert_eq(policy.rejected_actions, 1)
	var expected: Array[Dictionary] = [{"action": "actions[0]",
		"reason": BenchAnswer.ACTION_MALFORMED}]
	assert_eq(policy.decisions[0].refused, expected)


func test_an_unreadable_answer_is_retried_once_then_does_nothing() -> void:
	var sim: Simulation = Fixtures.sim_with_origin("fx_alder")
	var backend: Recorder = Recorder.new(MockBackend.MODE_INVALID)
	var policy: ModelPolicy = _policy(backend, sim)
	var commands_before: int = sim.command_log.size()
	assert_eq(_play(sim, policy, 25), 0)
	assert_eq(backend.days, [0, 0, 10, 10, 20, 20] as Array[int])
	assert_eq(policy.calls, 6)
	assert_eq(policy.invalid_answers, 3)
	for decision: BenchDecision in policy.decisions:
		assert_true(decision.retried)
		assert_eq(decision.invalid, BenchAnswer.ERROR_NO_JSON)
	for command: Command in sim.command_log.slice(commands_before):
		assert_true(command is CollectAnomalyCommand, "nothing but the housekeeping")
	assert_eq(sim.world.day, 25, "the run goes on")
	assert_eq((backend.messages_seen[1] as Array).size(), 3, "the retry adds one message")


func test_the_budget_stops_the_calls_and_the_run_goes_on() -> void:
	_config.max_calls = 3
	var sim: Simulation = Simulation.create(quiet_db(), 1)
	var backend: Recorder = Recorder.new(MockBackend.MODE_CHEAPEST)
	var policy: ModelPolicy = _policy(backend, sim)
	assert_eq(_play(sim, policy, 60), 0)
	assert_eq(policy.calls, 3)
	assert_true(policy.budget_exhausted)
	assert_eq(backend.days, [0, 10, 20] as Array[int])
	assert_eq(sim.world.day, 60)


func test_a_mixed_run_plays_the_same_twice() -> void:
	var runs: Array[Dictionary] = []
	for i: int in 2:
		var sim: Simulation = Fixtures.sim(7)
		var policy: ModelPolicy = _policy(MockBackend.new(MockBackend.MODE_MIXED), sim)
		assert_eq(_play(sim, policy, 150), 0)
		var commands: Array[Dictionary] = []
		for command: Command in sim.command_log:
			commands.append(command.to_dict())
		var retried: int = 0
		for decision: BenchDecision in policy.decisions:
			retried += 1 if decision.retried else 0
		runs.append({"hash": sim.state_hash(), "commands": commands,
			"retried": retried, "rejected": policy.rejected_actions})
	assert_eq(runs[0], runs[1])
	assert_gt(int(runs[0]["retried"]), 0, "every third answer is unreadable, and retried")
	assert_gt(int(runs[0]["rejected"]), 0, "every fourth names a region that does not exist")


func test_the_harness_never_sees_a_rejected_command_in_any_mode() -> void:
	for mode: String in MockBackend.MODES:
		var sim: Simulation = Fixtures.sim(3)
		var policy: ModelPolicy = _policy(MockBackend.new(mode), sim)
		assert_eq(_play(sim, policy, 120), 0, mode)


func test_a_cache_hit_counts_as_a_call_and_costs_nothing() -> void:
	var sim: Simulation = Fixtures.sim_with_origin("fx_alder")
	var backend: Recorder = Recorder.new(MockBackend.MODE_WAIT)
	var policy: ModelPolicy = _policy(backend, sim)
	policy.cache_read = func(_basis: Dictionary) -> Dictionary:
		return {"answer": {"stance": "hide", "actions": [], "dropped": []}}
	_play(sim, policy, 11)
	assert_eq(policy.calls, 2)
	assert_eq(policy.cached_calls, 2)
	assert_eq(backend.days.size(), 0, "the backend was never asked")
	assert_true(policy.decisions[0].cached)
	assert_eq(policy.decisions[0].stance, "hide")


# --- S6.12c: a decision model (benchmark.md §17) ---


## A decision model that always sends the same body.
class FixedChoice:
	extends ModelBackend
	var body: Dictionary = {}
	var digests: Array[BenchDigest] = []
	var plans: Array[BenchChoicePlan] = []

	func _init(p_body: Dictionary) -> void:
		body = p_body

	func kind() -> String:
		return KIND_CHOICE

	func choose(plan: BenchChoicePlan, digest: BenchDigest, _params: Dictionary) -> ModelReply:
		digests.append(digest)
		plans.append(plan)
		return ModelReply.choice(body.duplicate(true), "fixed-1")

	func backend_id() -> String:
		return "fixed-choice"


## A mock decision model that writes down when it was asked.
class ChoiceRecorder:
	extends MockChoiceBackend
	var days: Array[int] = []

	func choose(plan: BenchChoicePlan, digest: BenchDigest, params: Dictionary) -> ModelReply:
		days.append(digest.day)
		return super(plan, digest, params)


func _choice_policy(backend: ModelBackend, sim: Simulation) -> ModelPolicy:
	var policy: ModelPolicy = ModelPolicy.new(backend, _config, BenchChoice.params_of(_config),
		"en")
	policy.setup(sim.db, Policy.seed_for(1))
	return policy


func test_a_decision_model_decides_on_the_same_days_as_a_chat_model() -> void:
	var sim: Simulation = Simulation.create(quiet_db(), 1)
	var backend: ChoiceRecorder = ChoiceRecorder.new(MockChoiceBackend.MODE_FIRST)
	var policy: ModelPolicy = _choice_policy(backend, sim)
	assert_eq(_play(sim, policy, 45), 0)
	assert_eq(backend.days, [0, 10, 20, 30, 40] as Array[int])
	assert_ne(sim.world.agent.origin, 0, "the first decision chose the origin")
	assert_eq(policy.model_versions, [MockChoiceBackend.MODEL_VERSION] as Array[String])
	assert_eq(policy.decisions[0].stance, "spread")


func test_an_unreadable_reply_is_retried_once_then_does_nothing() -> void:
	var sim: Simulation = Fixtures.sim_with_origin("fx_alder")
	var backend: FixedChoice = FixedChoice.new({"model": "fixed-1"})
	var policy: ModelPolicy = _choice_policy(backend, sim)
	var commands_before: int = sim.command_log.size()
	assert_eq(_play(sim, policy, 11), 0)
	assert_eq(policy.calls, 4, "two decisions, each retried once")
	assert_eq(policy.invalid_answers, 2)
	for decision: BenchDecision in policy.decisions:
		assert_true(decision.retried)
		assert_eq(decision.invalid, BenchChoice.ERROR_BAD_REPLY)
	for command: Command in sim.command_log.slice(commands_before):
		assert_true(command is CollectAnomalyCommand, "nothing but the housekeeping")


func test_broken_retries_the_unreadable_call_and_plays_on() -> void:
	var sim: Simulation = Fixtures.sim(3)
	var broken: MockChoiceBackend = MockChoiceBackend.new(MockChoiceBackend.MODE_BROKEN)
	var policy: ModelPolicy = _choice_policy(broken, sim)
	assert_eq(_play(sim, policy, 60), 0)
	var retried: int = 0
	for decision: BenchDecision in policy.decisions:
		retried += 1 if decision.retried else 0
	assert_gt(retried, 0, "every third reply is unreadable, and retried")
	assert_gt(policy.rejected_actions, 0,
		"every fourth leaves out buy and names an unknown stance")


func test_a_problem_counts_as_rejected_and_is_fed_back_under_its_question() -> void:
	var sim: Simulation = Fixtures.sim_with_origin("fx_alder")
	var backend: FixedChoice = FixedChoice.new({"model": "fixed-1", "answers": {
		"stance": {"choice": "nuke", "probabilities": {}}}})
	var policy: ModelPolicy = _choice_policy(backend, sim)
	assert_eq(_play(sim, policy, 11), 0)
	var first: BenchDecision = policy.decisions[0]
	assert_eq(first.invalid, "")
	assert_eq(first.stance, "")
	assert_true(first.refused.has({"action": "stance",
		"reason": BenchChoice.PROBLEM_UNKNOWN_CHOICE}))
	assert_eq(policy.rejected_actions, first.refused.size() + policy.decisions[1].refused.size())
	assert_eq(backend.digests[1].feedback, first)
	var text: String = BenchPrompt.digest_text(backend.digests[1], sim.db, false)
	assert_string_contains(text, BenchChoice.PROBLEM_UNKNOWN_CHOICE)
	assert_false(text.contains(TechText.tr_key(BenchPrompt.KEY_ASK)),
		"no JSON is asked of a decision model")


func test_the_harness_never_sees_a_rejected_command_in_any_choice_mode() -> void:
	for mode: String in MockChoiceBackend.MODES:
		var sim: Simulation = Fixtures.sim(3)
		var policy: ModelPolicy = _choice_policy(MockChoiceBackend.new(mode), sim)
		assert_eq(_play(sim, policy, 120), 0, mode)


func test_a_cached_choice_answer_counts_as_a_call_and_keeps_its_version() -> void:
	var sim: Simulation = Fixtures.sim_with_origin("fx_alder")
	var backend: ChoiceRecorder = ChoiceRecorder.new(MockChoiceBackend.MODE_FIRST)
	var policy: ModelPolicy = _choice_policy(backend, sim)
	var bases: Array[Dictionary] = []
	policy.cache_read = func(basis: Dictionary) -> Dictionary:
		bases.append(basis)
		return {"answer": {"stance": "hide", "actions": [], "dropped": []},
			"model_version": "jev-9"}
	_play(sim, policy, 1)
	assert_eq(policy.cached_calls, 1)
	assert_eq(backend.days.size(), 0, "the backend was never asked")
	assert_eq(policy.model_versions, ["jev-9"] as Array[String])
	assert_true(bases[0].has("state") and bases[0].has("questions"))
	assert_false(bases[0].has("attempt"), "a first answer has no attempt")
