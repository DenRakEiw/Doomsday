class_name BenchChoice
extends RefCounted
## How a decision model plays (docs/specs/benchmark.md §17): one decision becomes
## one request of choice questions — one per kind of move, each offering only
## moves `Simulation.can_apply` accepts now (`plan`) — the reply becomes one
## ranking per question (`read`), and the rankings become one answer (`combine`)
## whose actions are queued like a chat model's. A decision model writes no text,
## so an answer cannot name an impossible move. Never instantiated.

## The question ids (§17.3), in asking order; the per-event, per-ability and
## per-node ones carry an id after their prefix.
const Q_STANCE: String = "stance"
const Q_ORIGIN: String = "origin"
const Q_WAKE: String = "wake"
const Q_SLEEP: String = "sleep"
const Q_USE: String = "use"
const Q_BUY: String = "buy"
const PREFIX_EVENT: String = "event_"
const PREFIX_TARGET: String = "target_"
const PREFIX_SITE: String = "site_"
## The questions that may give more than one action a decision (§17.6), in
## `choice.max_picks`' order.
const MULTI_PICK: Array[String] = ["buy", "use", "wake", "sleep"]
## The reserved option keys: doing nothing, and answering an event later. No
## content id may equal one (`test_bench_choice` holds the content to it).
const KEY_NONE: String = "none"
const KEY_LATER: String = "later"
const CONTROL_KEYS: Array[String] = ["none", "later"]

## The request (§17.1).
const STATE_RULES: String = "rules"
const STATE_SITUATION: String = "situation"
const FIELD_TYPE: String = "type"
const TYPE_CHOICE: String = "choice"
const FIELD_INSTRUCTIONS: String = "instructions"
const FIELD_CRITERIA: String = "criteria"
## The reply (§17.1).
const FIELD_MODEL: String = "model"
const FIELD_ANSWERS: String = "answers"
const FIELD_CHOICE: String = "choice"
const FIELD_PROBABILITIES: String = "probabilities"
const FIELD_CONFIDENCE: String = "confidence"
const FIELD_USAGE: String = "usage"
const FIELD_INPUT_TOKENS: String = "input_tokens"
const FIELD_OUTPUT_TOKENS: String = "output_tokens"
## §17.5: the whole reply unreadable, and what one question can lack.
const ERROR_BAD_REPLY: String = "bad_reply"
const PROBLEM_MISSING: String = "missing_answer"
const PROBLEM_UNKNOWN_CHOICE: String = "unknown_choice"
## A choice run's params (§17.7).
const PARAM_CHOICE_VERSION: String = "choice_version"
const PARAM_MAX_PICKS: String = "max_picks"

## The question texts (§13, §17.3). The model reads them; no player does.
const TEXT_STANCE: String = "BENCH_CHOICE_STANCE"
const TEXT_STANCE_OPTION: String = "BENCH_CHOICE_STANCE_OPTION"
const TEXT_ORIGIN: String = "BENCH_CHOICE_ORIGIN"
const TEXT_EVENT: String = "BENCH_CHOICE_EVENT"
const TEXT_EVENT_OPTION: String = "BENCH_CHOICE_EVENT_OPTION"
const TEXT_EVENT_DEFAULT: String = "BENCH_CHOICE_EVENT_DEFAULT"
const TEXT_LATER: String = "BENCH_CHOICE_LATER"
const TEXT_WAKE: String = "BENCH_CHOICE_WAKE"
const TEXT_NONE_WAKE: String = "BENCH_CHOICE_NONE_WAKE"
const TEXT_SLEEP: String = "BENCH_CHOICE_SLEEP"
const TEXT_NONE_SLEEP: String = "BENCH_CHOICE_NONE_SLEEP"
const TEXT_REGION_OPTION: String = "BENCH_CHOICE_REGION_OPTION"
const TEXT_USE: String = "BENCH_CHOICE_USE"
const TEXT_ABILITY_OPTION: String = "BENCH_CHOICE_ABILITY_OPTION"
const TEXT_NONE_USE: String = "BENCH_CHOICE_NONE_USE"
const TEXT_TARGET: String = "BENCH_CHOICE_TARGET"
const TEXT_BUY: String = "BENCH_CHOICE_BUY"
const TEXT_NODE_OPTION: String = "BENCH_CHOICE_NODE_OPTION"
const TEXT_NONE_BUY: String = "BENCH_CHOICE_NONE_BUY"
const TEXT_SITE: String = "BENCH_CHOICE_SITE"


## A choice run's params from the config (§17.7): whole numbers, so the params id
## is the same whichever way they arrive.
static func params_of(config: BenchConfig) -> Dictionary:
	var picks: Dictionary = {}
	for question: String in MULTI_PICK:
		picks[question] = int(config.max_picks.get(question, 1))
	return {PARAM_CHOICE_VERSION: config.choice_version, PARAM_MAX_PICKS: picks}


## §17.3: the request of one decision. Pure — it reads the simulation and never
## changes it. An option is offered only when the command it stands for passes
## `sim.can_apply` now; a question with no legal option is left out.
static func plan(sim: Simulation, digest: BenchDigest, rules: String, situation: String,
		config: BenchConfig) -> BenchChoicePlan:
	var out: BenchChoicePlan = BenchChoicePlan.new()
	out.state = {STATE_RULES: rules, STATE_SITUATION: situation}
	_plan_stance(out, config)
	if sim.world.agent.origin == 0:
		_plan_origin(out, sim, digest, config)
		return out
	_plan_events(out, sim, digest, config)
	_plan_dormancy(out, sim, digest, config, Q_WAKE)
	_plan_dormancy(out, sim, digest, config, Q_SLEEP)
	_plan_use(out, sim, digest, config)
	_plan_buy(out, sim, digest, config)
	return out


## §17.5: the reply as one ranking per question. Never crashes on any body.
static func read(body: Dictionary, plan_value: BenchChoicePlan) -> BenchChoiceRead:
	var out: BenchChoiceRead = BenchChoiceRead.new()
	if typeof(body.get(FIELD_MODEL)) == TYPE_STRING:
		out.model_version = str(body[FIELD_MODEL])
	if typeof(body.get(FIELD_ANSWERS)) != TYPE_DICTIONARY:
		out.error = ERROR_BAD_REPLY
		return out
	var answers: Dictionary = body[FIELD_ANSWERS]
	for question: String in plan_value.keys:
		var raw: Variant = answers.get(question)
		if typeof(raw) != TYPE_DICTIONARY:
			out.problems.append({BenchAnswer.FIELD_REASON: PROBLEM_MISSING,
				BenchAnswer.FIELD_QUESTION: question})
			continue
		var answer: Dictionary = raw
		if _is_number(answer.get(FIELD_CONFIDENCE)):
			out.confidence[question] = float(answer[FIELD_CONFIDENCE])
		var ranking: Array[String] = _ranking(answer, plan_value.keys_of(question))
		if ranking.is_empty():
			out.problems.append({BenchAnswer.FIELD_REASON: PROBLEM_UNKNOWN_CHOICE,
				BenchAnswer.FIELD_QUESTION: question})
			continue
		out.rankings[question] = ranking
	return out


## §17.6: the rankings as one answer, deterministic and always valid — the stance,
## the origin, then event answers, waking, sleep, abilities and purchases while
## the compute lasts. A pick the compute no longer covers is left out silently;
## what could not be read lands in `dropped` with its question id.
static func combine(plan_value: BenchChoicePlan, read_value: BenchChoiceRead,
		digest: BenchDigest, params: Dictionary, max_actions: int) -> BenchAnswer:
	var answer: BenchAnswer = BenchAnswer.new()
	answer.valid = true
	var stance: String = read_value.pick(Q_STANCE)
	answer.stance = stance if BenchAnswer.STANCES.has(stance) else ""
	var problems: Array[Dictionary] = []
	for problem: Dictionary in read_value.problems:
		problems.append(problem.duplicate())
	var actions: Array[BenchAction] = []
	var origin: String = read_value.pick(Q_ORIGIN)
	if not origin.is_empty():
		actions.append(BenchAction.create(BenchAction.VERB_ORIGIN,
			{BenchAction.FIELD_REGION: origin}))
	var remaining: float = digest.compute
	for row: BenchEventRow in digest.events:
		var question: String = PREFIX_EVENT + str(row.event)
		var option: String = read_value.pick(question)
		if option.is_empty() or option == KEY_LATER:
			continue
		var cost: float = plan_value.cost_of(question, option)
		if cost > remaining:
			continue
		actions.append(BenchAction.create(BenchAction.VERB_ANSWER,
			{BenchAction.FIELD_EVENT: row.event, BenchAction.FIELD_OPTION: option}))
		remaining -= cost
	for region: String in _picks(read_value, Q_WAKE, params):
		actions.append(BenchAction.create(BenchAction.VERB_WAKE,
			{BenchAction.FIELD_REGION: region}))
	for region: String in _picks(read_value, Q_SLEEP, params):
		actions.append(BenchAction.create(BenchAction.VERB_SLEEP,
			{BenchAction.FIELD_REGION: region}))
	for ability: String in _picks(read_value, Q_USE, params):
		var cost: float = plan_value.cost_of(Q_USE, ability)
		if cost > remaining:
			continue
		var fields: Dictionary = {BenchAction.FIELD_ABILITY: ability}
		if plan_value.regional.has(ability):
			var target_question: String = PREFIX_TARGET + ability
			if not read_value.answered(target_question):
				_note_missing(problems, target_question)
				continue
			fields[BenchAction.FIELD_REGION] = read_value.pick(target_question)
		actions.append(BenchAction.create(BenchAction.VERB_USE, fields))
		remaining -= cost
	for node: String in _picks(read_value, Q_BUY, params):
		var cost: float = plan_value.cost_of(Q_BUY, node)
		if cost > remaining:
			continue
		var fields: Dictionary = {BenchAction.FIELD_NODE: node}
		if plan_value.deploying.has(node):
			var site_question: String = PREFIX_SITE + node
			if not read_value.answered(site_question):
				_note_missing(problems, site_question)
				continue
			fields[BenchAction.FIELD_REGION] = read_value.pick(site_question)
		actions.append(BenchAction.create(BenchAction.VERB_BUY, fields))
		remaining -= cost
	for problem: Dictionary in problems:
		answer.dropped.append({BenchAnswer.FIELD_INDEX: BenchAnswer.NO_INDEX,
			BenchAnswer.FIELD_REASON: str(problem[BenchAnswer.FIELD_REASON]),
			BenchAnswer.FIELD_QUESTION: str(problem[BenchAnswer.FIELD_QUESTION])})
	for i: int in actions.size():
		if i < max_actions:
			answer.actions.append(actions[i])
		else:
			answer.dropped.append({BenchAnswer.FIELD_INDEX: i,
				BenchAnswer.FIELD_REASON: BenchAnswer.ACTION_OVER_LIMIT})
	return answer


static func _plan_stance(out: BenchChoicePlan, config: BenchConfig) -> void:
	var descriptions: Dictionary = {}
	for stance: String in BenchAnswer.STANCES:
		var key: String = BenchPrompt.PREFIX_STANCE + stance.to_upper()
		descriptions[stance] = _tr(TEXT_STANCE_OPTION).format({"name": _tr(key),
			"hint": _tr(key + BenchPrompt.SUFFIX_HINT)})
	_ask(out, Q_STANCE, _tr(TEXT_STANCE), BenchAnswer.STANCES.duplicate(), descriptions, "", "",
		config)


static func _plan_origin(out: BenchChoicePlan, sim: Simulation, digest: BenchDigest,
		config: BenchConfig) -> void:
	var keys: Array[String] = []
	for region: String in digest.origins:
		if sim.can_apply(ChooseOriginCommand.new(region)).is_empty():
			keys.append(region)
	_ask(out, Q_ORIGIN, _tr(TEXT_ORIGIN), keys, _region_texts(sim.db, keys), "", "", config)


## One question per open event, digest order: its options that are legal and
## not short, then `later` — not answering is a legal move (the default follows
## at the deadline).
static func _plan_events(out: BenchChoicePlan, sim: Simulation, digest: BenchDigest,
		config: BenchConfig) -> void:
	for row: BenchEventRow in digest.events:
		var keys: Array[String] = []
		var descriptions: Dictionary = {}
		var costs: Dictionary = {}
		var default_text: String = ""
		for option: BenchOptionRow in row.options:
			if option.is_default:
				default_text = option.text
			if option.short \
					or not sim.can_apply(ChooseEventOptionCommand.new(row.event, option.option)) \
					.is_empty():
				continue
			keys.append(option.option)
			descriptions[option.option] = _tr(TEXT_EVENT_OPTION).format({"text": option.text,
				"cost": EventView.cost_text(option.cost, option.suppression),
				"notes": _tr(TEXT_EVENT_DEFAULT) if option.is_default else ""})
			costs[option.option] = option.cost
		var question: String = PREFIX_EVENT + str(row.event)
		var instructions: String = _tr(TEXT_EVENT).format({"event": row.event,
			"title": row.title, "days": row.days_left})
		if _ask(out, question, instructions, keys, descriptions, KEY_LATER,
				_tr(TEXT_LATER).format({"default": default_text}), config):
			out.costs[question] = costs


## `wake` or `sleep`: the digest's regions (index order) the command accepts.
static func _plan_dormancy(out: BenchChoicePlan, sim: Simulation, digest: BenchDigest,
		config: BenchConfig, question: String) -> void:
	var sleeping: bool = question == Q_SLEEP
	var keys: Array[String] = []
	for row: BenchRegionRow in digest.regions:
		if sim.can_apply(SetDormancyCommand.new(row.id, sleeping)).is_empty():
			keys.append(row.id)
	_ask(out, question, _tr(TEXT_SLEEP if sleeping else TEXT_WAKE), keys,
		_region_texts(sim.db, keys), KEY_NONE, _tr(TEXT_NONE_SLEEP if sleeping else TEXT_NONE_WAKE),
		config)


## `use`: the abilities that are ready, affordable and have a legal command;
## then a `target_<ability>` question for each region ability offered.
static func _plan_use(out: BenchChoicePlan, sim: Simulation, digest: BenchDigest,
		config: BenchConfig) -> void:
	var keys: Array[String] = []
	var descriptions: Dictionary = {}
	var costs: Dictionary = {}
	var targets: Dictionary[String, Array] = {}
	for row: BenchAbilityRow in digest.abilities:
		if row.ready_in > 0 or row.cost > digest.compute:
			continue
		if row.global:
			if not sim.can_apply(UseAbilityCommand.new(row.ability, "")).is_empty():
				continue
		else:
			var legal: Array[String] = []
			for region: String in row.targets:
				if sim.can_apply(UseAbilityCommand.new(row.ability, region)).is_empty():
					legal.append(region)
			if legal.is_empty():
				continue
			targets[row.ability] = legal
		keys.append(row.ability)
		descriptions[row.ability] = _tr(TEXT_ABILITY_OPTION).format({
			"name": _tr(AbilityDef.name_key(row.ability)),
			"cost": Format.number(row.cost, Format.Kind.COMPUTE),
			"detail": _tr(AbilityDef.detail_key(row.ability))})
		costs[row.ability] = row.cost
	if not _ask(out, Q_USE, _tr(TEXT_USE), keys, descriptions, KEY_NONE, _tr(TEXT_NONE_USE),
			config):
		return
	out.costs[Q_USE] = costs
	for ability: String in out.keys_of(Q_USE):
		if not targets.has(ability):
			continue
		var regions: Array[String] = []
		regions.assign(targets[ability])
		out.regional.append(ability)
		_ask(out, PREFIX_TARGET + ability,
			_tr(TEXT_TARGET).format({"name": _tr(AbilityDef.name_key(ability))}), regions,
			_region_texts(sim.db, regions), "", "", config)


## `buy`: the affordable offers with a legal command; then a `site_<node>`
## question for each deploying node offered.
static func _plan_buy(out: BenchChoicePlan, sim: Simulation, digest: BenchDigest,
		config: BenchConfig) -> void:
	var keys: Array[String] = []
	var descriptions: Dictionary = {}
	var costs: Dictionary = {}
	var sites: Dictionary[String, Array] = {}
	for row: BenchOfferRow in digest.offers:
		if not row.affordable:
			continue
		if row.sites.is_empty():
			if not sim.can_apply(PurchaseNodeCommand.new(row.node, "")).is_empty():
				continue
		else:
			var legal: Array[String] = []
			for region: String in row.sites:
				if sim.can_apply(PurchaseNodeCommand.new(row.node, region)).is_empty():
					legal.append(region)
			if legal.is_empty():
				continue
			sites[row.node] = legal
		keys.append(row.node)
		descriptions[row.node] = _tr(TEXT_NODE_OPTION).format({
			"name": TechText.node_name(row.node),
			"cost": Format.number(row.cost, Format.Kind.COMPUTE),
			"effect": _tr(BenchPrompt.FORMAT_TECH_EFFECT % row.node.to_upper())})
		costs[row.node] = row.cost
	if not _ask(out, Q_BUY, _tr(TEXT_BUY), keys, descriptions, KEY_NONE, _tr(TEXT_NONE_BUY),
			config):
		return
	out.costs[Q_BUY] = costs
	for node: String in out.keys_of(Q_BUY):
		if not sites.has(node):
			continue
		var regions: Array[String] = []
		regions.assign(sites[node])
		out.deploying.append(node)
		_ask(out, PREFIX_SITE + node, _tr(TEXT_SITE).format({"name": TechText.node_name(node)}),
			regions, _region_texts(sim.db, regions), "", "", config)


## Adds one question; false (and nothing added) when it has no legal option.
## Past `max_options` the first legal keys are kept — room left for the control
## key, which comes last.
static func _ask(out: BenchChoicePlan, question: String, instructions: String,
		keys: Array[String], descriptions: Dictionary, control: String, control_text: String,
		config: BenchConfig) -> bool:
	if keys.is_empty():
		return false
	var room: int = config.max_options - (0 if control.is_empty() else 1)
	var kept: Array[String] = keys.slice(0, room)
	var criteria: Dictionary = {}
	for key: String in kept:
		criteria[key] = str(descriptions.get(key, ""))
	if not control.is_empty():
		kept.append(control)
		criteria[control] = control_text
	out.questions[question] = {FIELD_TYPE: TYPE_CHOICE, FIELD_INSTRUCTIONS: instructions,
		FIELD_CRITERIA: criteria}
	out.keys[question] = kept
	return true


## The keys ordered by probability, ties in plan order. With no usable
## probability, a `choice` the plan offered comes first; otherwise empty.
static func _ranking(answer: Dictionary, keys: Array[String]) -> Array[String]:
	var probabilities: Dictionary = {}
	if typeof(answer.get(FIELD_PROBABILITIES)) == TYPE_DICTIONARY:
		probabilities = answer[FIELD_PROBABILITIES]
	var weights: Array[float] = []
	var any: bool = false
	for key: String in keys:
		var value: Variant = probabilities.get(key)
		var weight: float = 0.0
		if _is_number(value) and float(value) >= 0.0 and float(value) <= 1.0:
			weight = float(value)
		weights.append(weight)
		any = any or weight > 0.0
	var out: Array[String] = []
	if not any:
		var choice: Variant = answer.get(FIELD_CHOICE)
		if typeof(choice) != TYPE_STRING or not keys.has(str(choice)):
			return out
		out.append(str(choice))
		for key: String in keys:
			if key != str(choice):
				out.append(key)
		return out
	var order: Array[int] = []
	for i: int in keys.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		if weights[a] != weights[b]:
			return weights[a] > weights[b]
		return a < b)
	for i: int in order:
		out.append(keys[i])
	return out


## A multi-pick question's picks: its ranking before the control key, at most
## the run's `max_picks` for it.
static func _picks(read_value: BenchChoiceRead, question: String,
		params: Dictionary) -> Array[String]:
	var limit: int = 1
	var picks: Variant = params.get(PARAM_MAX_PICKS)
	if typeof(picks) == TYPE_DICTIONARY and _is_number((picks as Dictionary).get(question)):
		limit = int((picks as Dictionary)[question])
	var out: Array[String] = []
	for key: Variant in read_value.rankings.get(question, []):
		if CONTROL_KEYS.has(str(key)) or out.size() >= limit:
			break
		out.append(str(key))
	return out


static func _note_missing(problems: Array[Dictionary], question: String) -> void:
	for problem: Dictionary in problems:
		if str(problem[BenchAnswer.FIELD_QUESTION]) == question:
			return
	problems.append({BenchAnswer.FIELD_REASON: PROBLEM_MISSING,
		BenchAnswer.FIELD_QUESTION: question})


static func _region_texts(db: ContentDB, regions: Array[String]) -> Dictionary:
	var out: Dictionary = {}
	for region: String in regions:
		var definition: RegionDef = db.region_by_id(region)
		var continent: String = "" if definition == null else definition.continent
		out[region] = _tr(TEXT_REGION_OPTION).format({
			"name": _tr(BenchPrompt.PREFIX_REGION + region.to_upper()),
			"continent": _tr(BenchPrompt.PREFIX_CONTINENT + continent.to_upper())})
	return out


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT


static func _tr(key: String) -> String:
	return TechText.tr_key(key)
