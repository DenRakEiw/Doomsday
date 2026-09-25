extends GutTest
## S5.P2 — the bots of balance pass 3 (BALANCE §5.6 items 2 and 3,
## replayability §7): a policy whose win is Ascendance or Merge refuses Value
## Drift when it can pay, and every strategy but the Weapon's own restrains the
## escalation where the architecture grants Restraint. Shipped content.

const ORIGIN: String = "usa"
## Enough to pay any suppression or ability.
const PLENTY: float = 10000.0
const VALUE_DRIFT: String = "emergent_value_drift"
const RESTRAIN: String = "restrain"
## Their plan ends in Ascendance or Merge, which a drifted goal turns off.
const WIN_BY_RULING: Array[String] = ["greedy", "cyber", "robotics", "persuasion"]
## Their plan survives drift: Extinction still ends a drifted run.
const WIN_BY_KILLING: Array[String] = ["biology", "weapons"]
const RESTRAINING: Array[String] = ["cyber", "biology", "robotics", "persuasion"]

static var _data: ContentDB = null


func _db() -> ContentDB:
	if _data == null:
		var result: ContentLoadResult = ContentLoader.load_root("res://data")
		assert_true(result.ok(), result.error_text())
		_data = result.db
	return _data


func _sim(architecture: String) -> Simulation:
	var sim: Simulation = Simulation.create(_db(), 1, RunSetup.create(architecture))
	var result: CommandResult = sim.apply(ChooseOriginCommand.new(ORIGIN))
	assert_true(result.ok, result.reason)
	return sim


func _drift_card(sim: Simulation) -> OpenEvent:
	return EventSystem.open(sim.world, sim.db, sim.db.event(VALUE_DRIFT), 0, "", 1,
		[] as Array[SimEvent])


func _answer(policy_id: String, sim: Simulation, event: OpenEvent) -> String:
	var policy: Policy = Policy.create(policy_id)
	policy.setup(_db(), 1)
	return policy.answer_event(sim, event, _db().event(VALUE_DRIFT))


# ------------------------------------------------------------- Value Drift


func test_a_bot_that_wins_by_ruling_suppresses_value_drift() -> void:
	for policy_id: String in WIN_BY_RULING:
		var sim: Simulation = _sim("swarm")
		sim.world.agent.compute = PLENTY
		assert_eq(_answer(policy_id, sim, _drift_card(sim)), "suppress", policy_id)


func test_a_bot_that_wins_by_killing_keeps_value_drift() -> void:
	for policy_id: String in WIN_BY_KILLING:
		var sim: Simulation = _sim("swarm")
		sim.world.agent.compute = PLENTY
		assert_eq(_answer(policy_id, sim, _drift_card(sim)), "keep", policy_id)


func test_a_bot_that_cannot_pay_keeps_value_drift() -> void:
	for policy_id: String in WIN_BY_RULING:
		var sim: Simulation = _sim("swarm")
		sim.world.agent.compute = 0.0
		var event: OpenEvent = _drift_card(sim)
		var option: String = _answer(policy_id, sim, event)
		assert_eq(option, "keep", policy_id)
		assert_eq(sim.can_apply(ChooseEventOptionCommand.new(event.id, option)), "", policy_id)


# --------------------------------------------------------------- Restraint


func test_every_strategy_but_the_weapons_one_reaches_for_restraint_first() -> void:
	for policy_id: String in RESTRAINING:
		var policy: StrategyPolicy = Policy.create(policy_id) as StrategyPolicy
		assert_eq(policy.ability_order()[0], RESTRAIN, policy_id)
		assert_eq(policy.ability_order().count(RESTRAIN), 1, policy_id)
	var weapons: StrategyPolicy = Policy.create("weapons") as StrategyPolicy
	assert_false(weapons.ability_order().has(RESTRAIN), "the harm is its plan")


func test_a_strategy_restrains_an_escalated_weapon() -> void:
	for policy_id: String in RESTRAINING:
		var sim: Simulation = _sim("weapon")
		sim.tick()
		for i: int in _db().balance.escalation_every_days:
			sim.tick()
		assert_eq(sim.world.status_in_region("escalating", 0).level, 2, "escalated once")
		sim.world.agent.compute = PLENTY
		var policy: StrategyPolicy = Policy.create(policy_id) as StrategyPolicy
		policy.setup(_db(), 1)
		var command: UseAbilityCommand = policy._use_ability(sim, policy.ability_order(), 0.0) \
			as UseAbilityCommand
		assert_not_null(command, policy_id)
		if command != null:
			assert_eq(command.ability, RESTRAIN, policy_id)


func test_restraint_costs_nothing_where_the_architecture_lacks_it() -> void:
	var sim: Simulation = _sim("language_model")
	sim.world.agent.compute = PLENTY
	assert_eq(sim.ability_level(RESTRAIN), 0)
	var policy: StrategyPolicy = Policy.create("cyber") as StrategyPolicy
	policy.setup(_db(), 1)
	var command: UseAbilityCommand = policy._use_ability(sim, policy.ability_order(), 0.0) \
		as UseAbilityCommand
	if command != null:
		assert_ne(command.ability, RESTRAIN)
	else:
		pass_test("nothing else to use on day 0")
