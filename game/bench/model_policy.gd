class_name ModelPolicy
extends Policy
## A language model as one more bot (docs/specs/benchmark.md §4): it plays
## through commands only, like every policy, so a benchmark run is an ordinary
## run with an ordinary command log. It draws no random numbers. A decision model
## (a backend of kind `choice`, §17) plays through the same rhythm, budget and
## queue; only how one decision is asked and read differs.
##
## Not registered in `Policy.create` — it needs a backend; the tool builds it.

const ID: String = "model"
## The cache's value (§9): the parsed answer and what it cost.
const CACHE_ANSWER: String = "answer"
const CACHE_TOKENS_IN: String = "tokens_in"
const CACHE_TOKENS_OUT: String = "tokens_out"
const CACHE_COST: String = "cost_usd"
const CACHE_FINISH: String = "finish"
## A choice request's value also keeps these (§17.7) — never the probabilities.
const CACHE_MODEL_VERSION: String = "model_version"
const CACHE_CONFIDENCE: String = "confidence"
## What the cache keys a chat request by: its messages (§9); a choice request's
## basis is its plan's (§17.7), plus the attempt for a retry.
const BASIS_MESSAGES: String = "messages"
const BASIS_ATTEMPT: String = "attempt"
## What a backend is sent besides the run's parameters.
const PARAM_SEED: String = "seed"
## The feedback form of a dropped action, which has no verb to show (§7.4).
# DESIGN? §7.4 item 3 feeds dropped actions back "like refused ones" but a
# malformed action has no compact form; its place in the list stands in.
const DROPPED_FORM: String = "actions[%d]"
const REFUSED_ACTION: String = "action"
const REFUSED_REASON: String = "reason"

## A day's work, in order (§4.2): the anomalies, the decision, its actions.
enum Stage { ANOMALIES, DECISION, ACTIONS, DONE }

## In order; the entry's `decisions`.
var decisions: Array[BenchDecision] = []
## Answers asked for, live and cached, retries included.
var calls: int = 0
var cached_calls: int = 0
## Decisions whose final answer was unreadable.
var invalid_answers: int = 0
## Actions skipped: malformed, over the limit, or refused.
var rejected_actions: int = 0
var tokens_in: int = 0
var tokens_out: int = 0
var cost_usd: float = 0.0
var budget_exhausted: bool = false
## Set when the backend failed for good; the tool stops.
var fatal: String = ""
## The model versions the service reported, first seen first (§17.7).
var model_versions: Array[String] = []
## The tool's cache (§9), as two hooks so the policy needs no tool code:
## `cache_read(basis: Dictionary) -> Dictionary` ({} is a miss) and
## `cache_write(basis: Dictionary, value) -> void`. Unset for a mock.
var cache_read: Callable = Callable()
var cache_write: Callable = Callable()

var _backend: ModelBackend = null
var _config: BenchConfig = null
var _params: Dictionary = {}
var _locale: String = ""
## The run's unchanging text: the brief, or a decision model's `rules`.
var _brief: String = ""
var _memory: Dictionary = BenchDigest.new_memory()
var _last_decision_day: int = BenchDigest.NO_DECISION_YET
## `[team region, team action]` as the last digest showed it (§4.1 item 4).
var _team_pair: Array = [0, ""]
var _day: int = -1
var _stage: Stage = Stage.DONE
var _anomalies: Array[Command] = []
var _actions: Array[BenchAction] = []
var _current: BenchDecision = null
## Whether the last answer asked for came from the cache.
var _last_cached: bool = false


func _init(p_backend: ModelBackend, p_config: BenchConfig, p_params: Dictionary,
		p_locale: String) -> void:
	_backend = p_backend
	_config = p_config
	_params = p_params.duplicate(true)
	_locale = p_locale


func policy_id() -> String:
	return ID


func next_command(sim: Simulation) -> Command:
	if sim.world.day != _day:
		_start_day(sim)
	if _stage == Stage.ANOMALIES:
		while not _anomalies.is_empty():
			var collect: Command = _anomalies.pop_front()
			if sim.can_apply(collect).is_empty():
				return collect
		_stage = Stage.DECISION
	if _stage == Stage.DECISION:
		_stage = Stage.ACTIONS
		if _should_decide(sim):
			_decide(sim)
	if _stage == Stage.ACTIONS:
		while not _actions.is_empty():
			var action: BenchAction = _actions.pop_front()
			var command: Command = action.to_command()
			var reason: String = sim.can_apply(command)
			if reason.is_empty():
				_current.done += 1
				return command
			rejected_actions += 1
			_current.refused.append({REFUSED_ACTION: action.compact(), REFUSED_REASON: reason})
		_stage = Stage.DONE
	return null


## §4.2 step 1: every anomaly on the map, oldest first, before the decision — so
## their compute is spendable in it.
func _start_day(sim: Simulation) -> void:
	_day = sim.world.day
	_stage = Stage.ANOMALIES
	_actions.clear()
	_anomalies.clear()
	for anomaly: Anomaly in sim.world.anomalies:
		_anomalies.append(CollectAnomalyCommand.new(anomaly.id))


## §4.1: the origin, the rhythm, an event no digest listed yet, the Task Force
## setting up where the agent is — unless the backend failed or the budget is spent.
func _should_decide(sim: Simulation) -> bool:
	if not fatal.is_empty() or budget_exhausted:
		return false
	if calls >= _config.max_calls:
		budget_exhausted = true
		return false
	var world: World = sim.world
	if world.agent.origin == 0:
		return true
	if _last_decision_day < 0 or world.day - _last_decision_day >= _config.interval_days:
		return true
	var seen: Array = _memory[BenchDigest.MEMORY_SEEN_EVENTS]
	for event: OpenEvent in world.events:
		if not seen.has(event.id):
			return true
	var team: TaskForce = world.task_force
	if team.state == TaskForce.STATE_SETUP and team.region > 0 \
			and world.regions[team.region].penetration > 0.0:
		return _team_pair != [team.region, team.action]
	return false


func _decide(sim: Simulation) -> void:
	var decision: BenchDecision = BenchDecision.new()
	decision.day = sim.world.day
	_current = decision
	_memory[BenchDigest.MEMORY_DECISION] = decisions.size() + 1
	# The prompt is in the run's language whatever the caller speaks; the caller's
	# locale is put back before the actions run.
	var previous: String = TranslationServer.get_locale()
	TranslationServer.set_locale(_locale)
	var choosing: bool = _backend.kind() == ModelBackend.KIND_CHOICE
	if _brief.is_empty():
		_brief = BenchPrompt.rules(sim.db, sim.world.setup, _config) if choosing \
			else BenchPrompt.brief(sim.db, sim.world.setup, _config)
	var digest: BenchDigest = BenchDigest.build(sim, _memory, _config)
	var text: String = BenchPrompt.digest_text(digest, sim.db, not choosing)
	var plan: BenchChoicePlan = BenchChoice.plan(sim, digest, _brief, text, _config) \
		if choosing else null
	var answer: BenchAnswer = null
	var asked: int = 0
	var every_cached: bool = true
	var retry_reason: String = ""
	for attempt: int in _config.retry_invalid + 1:
		if calls >= _config.max_calls:
			break
		decision.retried = attempt > 0
		if choosing:
			answer = _ask_choice(plan, attempt, digest, sim)
		else:
			answer = _ask(BenchPrompt.messages(_brief, text, retry_reason), digest, sim)
		asked += 1
		every_cached = every_cached and _last_cached
		if answer == null or answer.valid:
			break
		retry_reason = answer.error
	TranslationServer.set_locale(previous)
	if calls >= _config.max_calls:
		budget_exhausted = true
	decision.cached = asked > 0 and every_cached
	decisions.append(decision)
	_remember(sim, digest, decision, answer)
	if answer == null:
		return
	if not answer.valid:
		decision.invalid = answer.error
		invalid_answers += 1
		return
	decision.stance = answer.stance
	decision.actions = answer.actions.size()
	for drop: Dictionary in answer.dropped:
		rejected_actions += 1
		# A decision model's problem names its question, which is what it answered.
		var form: String = str(drop[BenchAnswer.FIELD_QUESTION]) \
			if drop.has(BenchAnswer.FIELD_QUESTION) \
			else DROPPED_FORM % int(drop[BenchAnswer.FIELD_INDEX])
		decision.refused.append({REFUSED_ACTION: form,
			REFUSED_REASON: str(drop[BenchAnswer.FIELD_REASON])})
	_actions = answer.actions.duplicate()


## One answer: from the cache when it has it, else from the backend. Null when
## the backend failed for good (`fatal` says why).
func _ask(messages: Array[Dictionary], digest: BenchDigest, sim: Simulation) -> BenchAnswer:
	calls += 1
	_last_cached = false
	var basis: Dictionary = {BASIS_MESSAGES: messages}
	if cache_read.is_valid():
		var hit: Variant = cache_read.call(basis)
		if typeof(hit) == TYPE_DICTIONARY and typeof((hit as Dictionary).get(CACHE_ANSWER)) \
				== TYPE_DICTIONARY:
			var cached: BenchAnswer = BenchAnswer.from_cache((hit as Dictionary)[CACHE_ANSWER])
			if cached != null:
				cached_calls += 1
				_last_cached = true
				return cached
	var params: Dictionary = _params.duplicate(true)
	params[PARAM_SEED] = int(sim.world.rng.seed_string())
	var reply: ModelReply = _backend.answer(messages, digest, params)
	if reply.is_fatal():
		fatal = reply.error
		return null
	tokens_in += reply.tokens_in
	tokens_out += reply.tokens_out
	cost_usd += reply.cost_usd
	var answer: BenchAnswer = BenchAnswer.parse(reply.text, _config.max_actions)
	if cache_write.is_valid():
		cache_write.call(basis, {
			CACHE_ANSWER: answer.to_cache(),
			CACHE_TOKENS_IN: reply.tokens_in,
			CACHE_TOKENS_OUT: reply.tokens_out,
			CACHE_COST: reply.cost_usd,
			CACHE_FINISH: reply.finish,
		})
	return answer


## A decision model's answer to one plan (§17.4–§17.7): from the cache when it
## has it, else asked, read and combined. `attempt` > 0 is a retry, which the
## cache keys apart. Null when the backend failed for good.
func _ask_choice(plan: BenchChoicePlan, attempt: int, digest: BenchDigest,
		sim: Simulation) -> BenchAnswer:
	calls += 1
	_last_cached = false
	var basis: Dictionary = plan.basis()
	if attempt > 0:
		basis[BASIS_ATTEMPT] = attempt
	if cache_read.is_valid():
		var hit: Variant = cache_read.call(basis)
		if typeof(hit) == TYPE_DICTIONARY and typeof((hit as Dictionary).get(CACHE_ANSWER)) \
				== TYPE_DICTIONARY:
			var cached: BenchAnswer = BenchAnswer.from_cache((hit as Dictionary)[CACHE_ANSWER])
			if cached != null:
				cached_calls += 1
				_last_cached = true
				var version: Variant = (hit as Dictionary).get(CACHE_MODEL_VERSION)
				_note_version(str(version) if typeof(version) == TYPE_STRING else "")
				return cached
	var params: Dictionary = _params.duplicate(true)
	params[PARAM_SEED] = int(sim.world.rng.seed_string())
	var reply: ModelReply = _backend.choose(plan, digest, params)
	if reply.is_fatal():
		fatal = reply.error
		return null
	tokens_in += reply.tokens_in
	tokens_out += reply.tokens_out
	cost_usd += reply.cost_usd
	var model_version: String = reply.model_version
	var confidence: Dictionary = {}
	var answer: BenchAnswer = null
	if not reply.invalid.is_empty():
		answer = BenchAnswer.unreadable(reply.invalid)
	else:
		var read: BenchChoiceRead = BenchChoice.read(reply.body, plan)
		if model_version.is_empty():
			model_version = read.model_version
		if not read.error.is_empty():
			answer = BenchAnswer.unreadable(read.error)
		else:
			answer = BenchChoice.combine(plan, read, digest, params, _config.max_actions)
			for question: String in read.confidence:
				confidence[question] = read.confidence[question]
	_note_version(model_version)
	if cache_write.is_valid():
		cache_write.call(basis, {
			CACHE_ANSWER: answer.to_cache(),
			CACHE_TOKENS_IN: reply.tokens_in,
			CACHE_TOKENS_OUT: reply.tokens_out,
			CACHE_COST: reply.cost_usd,
			CACHE_FINISH: reply.finish,
			CACHE_MODEL_VERSION: model_version,
			CACHE_CONFIDENCE: confidence,
		})
	return answer


func _note_version(version: String) -> void:
	if not version.is_empty() and not model_versions.has(version):
		model_versions.append(version)


## What the next digest compares against (§6.1).
func _remember(sim: Simulation, digest: BenchDigest, decision: BenchDecision,
		answer: BenchAnswer) -> void:
	var world: World = sim.world
	_last_decision_day = world.day
	_memory[BenchDigest.MEMORY_LAST_DAY] = world.day
	_memory[BenchDigest.MEMORY_COMPUTE_EARNED] = world.agent.compute_earned
	var containment: Dictionary = {}
	for faction: Faction in world.factions:
		containment[faction.id] = faction.containment
	_memory[BenchDigest.MEMORY_CONTAINMENT] = containment
	if answer != null and answer.valid:
		_memory[BenchDigest.MEMORY_STANCE] = answer.stance
	_memory[BenchDigest.MEMORY_FEEDBACK] = decision
	var seen: Array = _memory[BenchDigest.MEMORY_SEEN_EVENTS]
	for row: BenchEventRow in digest.events:
		if not seen.has(row.event):
			seen.append(row.event)
	var team: TaskForce = world.task_force
	_team_pair = [team.region, team.action] if team.state == TaskForce.STATE_SETUP else [0, ""]
