extends GutTest
## G6 (1/2), BALANCE §6.6 — the bots weigh an emergent card's catch: a status an
## option applies is scored by what it changes (`StatusForecast`), a node handed
## over by its price. A card whose catch outweighs its gain is suppressed when
## the bot can pay, kept when it cannot. Shipped content.

const ORIGIN: String = "usa"
## Enough to pay any suppression.
const PLENTY: float = 10000.0
## Quieter (footprint −2, found later) but slower to spread (×0.85).
const AWARENESS: String = "emergent_situational_awareness"
const GOAL_GENERALISATION: String = "emergent_goal_generalisation"
const KEEP: String = "keep"
const SUPPRESS: String = "suppress"
## Half-way into every region: the spread is at its fastest, so slowing it costs
## the most.
const PENETRATION: float = 0.5

static var _data: ContentDB = null


func _db() -> ContentDB:
	if _data == null:
		var result: ContentLoadResult = ContentLoader.load_root("res://data")
		assert_true(result.ok(), result.error_text())
		_data = result.db
	return _data


## A discovered run half-way into every region, so a slower spread is a real loss
## and a lower footprint no longer hides anything from the discovery roll.
func _sim() -> Simulation:
	var sim: Simulation = Simulation.create(_db(), 1, RunSetup.create("language_model"))
	assert_true(sim.apply(ChooseOriginCommand.new(ORIGIN)).ok)
	for i: int in range(1, sim.world.regions.size()):
		sim.world.regions[i].penetration = PENETRATION
	sim.world.discovered = true
	return sim


func _card(sim: Simulation, def_id: String) -> OpenEvent:
	return EventSystem.open(sim.world, sim.db, sim.db.event(def_id), 0, "", 1,
		[] as Array[SimEvent])


func _policy(policy_id: String) -> Policy:
	var policy: Policy = Policy.create(policy_id)
	policy.setup(_db(), 1)
	return policy


func _score(policy: Policy, sim: Simulation, event: OpenEvent, option_id: String) -> float:
	var def: EventDef = sim.db.event(event.def)
	for option: EventOptionDef in def.options:
		if option.id == option_id:
			return policy.option_score(sim, event, def, option)
	return NAN


func test_a_catch_that_outweighs_the_gain_is_suppressed_with_compute_to_spare() -> void:
	var sim: Simulation = _sim()
	sim.world.agent.compute = PLENTY
	var event: OpenEvent = _card(sim, AWARENESS)
	var greedy: Policy = _policy(GreedyPolicy.ID)
	# Greedy does not mind being seen: the quiet is worth nothing to it, the
	# slower spread costs it more than the suppression does.
	assert_lt(_score(greedy, sim, event, KEEP), _score(greedy, sim, event, SUPPRESS))
	assert_eq(greedy.answer_event(sim, event, sim.db.event(AWARENESS)), SUPPRESS)


func test_a_catch_that_outweighs_the_gain_is_kept_without_compute() -> void:
	var sim: Simulation = _sim()
	sim.world.agent.compute = 0.0
	var event: OpenEvent = _card(sim, AWARENESS)
	var option: String = _policy(GreedyPolicy.ID).answer_event(sim, event,
		sim.db.event(AWARENESS))
	assert_eq(option, KEEP)
	assert_eq(sim.can_apply(ChooseEventOptionCommand.new(event.id, option)), "")


func test_a_bot_that_values_the_gain_keeps_the_card() -> void:
	var sim: Simulation = _sim()
	sim.world.agent.compute = PLENTY
	var event: OpenEvent = _card(sim, AWARENESS)
	# Persuasion wants to stay quiet more than it wants the spread.
	assert_eq(_policy(PersuasionPolicy.ID).answer_event(sim, event, sim.db.event(AWARENESS)),
		KEEP)


func test_a_status_is_no_longer_worth_nothing() -> void:
	var sim: Simulation = _sim()
	var event: OpenEvent = _card(sim, AWARENESS)
	assert_ne(_score(_policy(GreedyPolicy.ID), sim, event, KEEP), 0.0)


func test_a_node_handed_over_is_worth_its_price() -> void:
	var sim: Simulation = _sim()
	var node: TechNodeDef = EffectRunner.near_node(sim)
	assert_not_null(node, "the shipped tree has a node one prerequisite short on day 0")
	if node == null:
		return
	var greedy: Policy = _policy(GreedyPolicy.ID)
	var event: OpenEvent = _card(sim, GOAL_GENERALISATION)
	# Greedy puts no weight on footprint, so the pulse beside it counts nothing.
	assert_almost_eq(_score(greedy, sim, event, KEEP),
		sim.node_cost(node.id) * greedy._weight(Policy.W_COMPUTE), 1e-9)


func test_the_node_priced_is_the_node_the_effect_hands_over() -> void:
	var sim: Simulation = _sim()
	var node: TechNodeDef = EffectRunner.near_node(sim)
	assert_not_null(node)
	if node == null:
		return
	var effect: EffectDef = EffectDef.new()
	effect.effect = EffectDef.UNLOCK_NEAR_NODE
	EffectRunner.apply(sim, effect, EffectContext.new(), [] as Array[SimEvent])
	assert_true(sim.world.agent.owns(node.id))
