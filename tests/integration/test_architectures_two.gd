extends GutTest
## S5.2 — architectures II (`replayability.md` §2.2, §3): the emergent kind and
## its price, the Swarm's drift and defection, the Weapon's escalation and
## Restraint, Open Weights' start and floor, and the two new effects. Runs on the
## shipped content, whose architectures these are.

const ORIGIN: String = "usa"

static var _data: ContentDB = null


func _db() -> ContentDB:
	if _data == null:
		var result: ContentLoadResult = ContentLoader.load_root("res://data")
		assert_true(result.ok(), result.error_text())
		_data = result.db
	return _data


func _sim(architecture: String, seed_value: int = 1) -> Simulation:
	var sim: Simulation = Simulation.create(_db(), seed_value, RunSetup.create(architecture))
	var result: CommandResult = sim.apply(ChooseOriginCommand.new(ORIGIN))
	assert_true(result.ok, result.reason)
	return sim


## A source with one modifier, for a test that needs a stat pushed hard.
func _push(sim: Simulation, target: String, op: ModifierDef.Op, value: float) -> void:
	var modifier: ModifierDef = ModifierDef.new()
	modifier.target = target
	modifier.op = op
	modifier.value = value
	var no_flags: Array[String] = []
	sim.world.modifiers.add_source("test:%s" % target, [modifier] as Array[ModifierDef],
		no_flags)


func _breakout(sim: Simulation) -> void:
	var none: Array[ModifierDef] = []
	var flags: Array[String] = [ModifierDef.FLAG_BREAKOUT]
	sim.world.modifiers.add_source("test:breakout", none, flags)


func _emergent_open(sim: Simulation) -> OpenEvent:
	for event: OpenEvent in sim.world.events:
		if sim.db.event(event.def).kind == EventDef.KIND_EMERGENT:
			return event
	return null


# ----------------------------------------------------------- the emergent kind


func test_the_twelve_behaviours_are_loaded_as_their_own_kind() -> void:
	var count: int = 0
	for def: EventDef in _db().events:
		if def.kind == EventDef.KIND_EMERGENT:
			count += 1
			assert_false(def.is_rolled(), "%s is not an opening" % def.id)
	assert_eq(count, 12)


func test_a_suppression_costs_more_each_time() -> void:
	var sim: Simulation = _sim("language_model")
	var suppress: EventOptionDef = _db().event("emergent_reward_hacking").option("suppress")
	assert_true(suppress.cost_suppression)
	assert_almost_eq(sim.option_cost(suppress), 4.0, 1e-9)
	sim.world.agent.suppressions = 2
	assert_almost_eq(sim.option_cost(suppress), 8.0, 1e-9, "4 × (1 + 0.5 × 2)")


func test_an_emergent_card_rolls_from_covert_on_and_never_two_at_once() -> void:
	var sim: Simulation = _sim("language_model")
	_push(sim, "emergent_rate", ModifierDef.Op.MUL, 1000.0)
	sim.tick()
	assert_null(_emergent_open(sim), "Boxed: nothing of its own yet")
	_breakout(sim)
	# `emergent_rate` clamps at 20, so a day's chance is 0.24; thirty days of it
	# (seed 1, fixed) open one.
	for i: int in 30:
		sim.tick()
		if _emergent_open(sim) != null:
			break
	assert_not_null(_emergent_open(sim), "a pushed rate opens one")
	var open_count: int = 0
	for event: OpenEvent in sim.world.events:
		if sim.db.event(event.def).kind == EventDef.KIND_EMERGENT:
			open_count += 1
	assert_eq(open_count, 1)


func test_suppressing_counts_and_pulls_the_swarm_back() -> void:
	var sim: Simulation = _sim("swarm")
	sim.world.agent.drift = 30.0
	sim.world.agent.compute = 100.0
	var event: OpenEvent = EventSystem.open(sim.world, sim.db,
		sim.db.event("emergent_reward_hacking"), 0, "", 1, [] as Array[SimEvent])
	var result: CommandResult = sim.apply(ChooseEventOptionCommand.new(event.id, "suppress"))
	assert_true(result.ok, result.reason)
	assert_eq(sim.world.agent.suppressions, 1)
	assert_almost_eq(sim.world.agent.drift, 30.0 - _db().balance.drift_per_suppressed, 1e-9)
	assert_almost_eq(sim.world.agent.compute, 96.0, 1e-9)


func test_keeping_lets_the_swarm_drift_and_nobody_else() -> void:
	for architecture: String in ["swarm", "language_model"]:
		var sim: Simulation = _sim(architecture)
		var event: OpenEvent = EventSystem.open(sim.world, sim.db,
			sim.db.event("emergent_sycophancy"), 0, "", 1, [] as Array[SimEvent])
		assert_true(sim.apply(ChooseEventOptionCommand.new(event.id, "keep")).ok)
		var expected: float = _db().balance.drift_per_kept if architecture == "swarm" else 0.0
		assert_almost_eq(sim.world.agent.drift, expected, 1e-9, architecture)


func test_value_drift_comes_only_to_a_swarm_that_has_drifted() -> void:
	var drifted: Simulation = _sim("swarm")
	var calm: Simulation = _sim("language_model")
	for sim: Simulation in [drifted, calm]:
		sim.world.phase = World.Phase.EMERGENT
		sim.world.agent.drift = 70.0
	var ids: Array[String] = []
	for def: EventDef in EventSystem.candidates(drifted, EventDef.KIND_EMERGENT):
		ids.append(def.id)
	assert_true(ids.has("emergent_value_drift"))
	ids.clear()
	for def: EventDef in EventSystem.candidates(calm, EventDef.KIND_EMERGENT):
		ids.append(def.id)
	assert_false(ids.has("emergent_value_drift"))
	drifted.world.agent.drift = 50.0
	ids.clear()
	for def: EventDef in EventSystem.candidates(drifted, EventDef.KIND_EMERGENT):
		ids.append(def.id)
	assert_false(ids.has("emergent_value_drift"), "not below 60")


# ------------------------------------------------------------------- drift


func test_the_swarm_drifts_a_little_every_day() -> void:
	var sim: Simulation = _sim("swarm")
	for i: int in 10:
		sim.tick()
	assert_almost_eq(sim.world.agent.drift, 10.0 * _db().balance.drift_per_day, 1e-6)
	var calm: Simulation = _sim("language_model")
	calm.tick()
	assert_eq(calm.world.agent.drift, 0.0)


func test_only_a_region_held_well_enough_can_defect() -> void:
	var sim: Simulation = _sim("swarm")
	var origin: int = sim.world.agent.origin
	sim.world.regions[origin].penetration = 0.1
	assert_false(DriftSystem.defectable(sim.world, sim.db).has(origin))
	sim.world.regions[origin].penetration = 0.9
	assert_true(DriftSystem.defectable(sim.world, sim.db).has(origin))


# -------------------------------------------------------------- escalation


func test_the_weapon_escalates_every_sixty_days() -> void:
	var sim: Simulation = _sim("weapon")
	sim.tick()
	var status: Status = sim.world.status_in_region("escalating", 0)
	assert_not_null(status)
	assert_eq(status.level, 1)
	for i: int in _db().balance.escalation_every_days:
		sim.tick()
	assert_eq(sim.world.status_in_region("escalating", 0).level, 2)


func test_restraint_lowers_the_escalation_and_holds_it() -> void:
	var sim: Simulation = _sim("weapon")
	sim.tick()
	for i: int in _db().balance.escalation_every_days:
		sim.tick()
	assert_eq(sim.ability_level("restrain"), 1, "the architecture grants it")
	sim.world.agent.compute = 100.0
	var result: CommandResult = sim.apply(UseAbilityCommand.new("restrain"))
	assert_true(result.ok, result.reason)
	assert_eq(sim.world.status_in_region("escalating", 0).level, 1)
	for i: int in _db().balance.escalation_hold_days - 1:
		sim.tick()
	assert_eq(sim.world.status_in_region("escalating", 0).level, 1, "held while restrained")


# ------------------------------------------------------------ open weights


func test_open_weights_starts_in_six_more_regions() -> void:
	var sim: Simulation = _sim("open_weights")
	var seeded: int = 0
	for i: int in range(1, sim.world.regions.size()):
		if i != sim.world.agent.origin and sim.world.regions[i].penetration > 0.0:
			seeded += 1
			assert_almost_eq(sim.world.regions[i].penetration,
				_db().balance.distributed_start_penetration, 1e-9)
	assert_eq(seeded, 6)


func test_a_wipe_leaves_the_floor_while_open_weights_holds_enough() -> void:
	var sim: Simulation = _sim("open_weights")
	var held: int = 0
	for i: int in range(1, sim.world.regions.size()):
		if held < _db().balance.distributed_hold_regions:
			sim.world.regions[i].penetration = 0.5
			held += 1
	var context: EffectContext = EffectContext.new()
	context.region = sim.world.agent.origin
	# Low enough that Open Weights' own shutdown survival (+0.3) ends under the
	# floor, so the floor is what holds it.
	sim.world.regions[context.region].penetration = 0.1
	var wipe: EffectDef = EffectDef.from_dict({"effect": "wipe", "value": 0.0})
	EffectRunner.apply_all(sim, [wipe] as Array[EffectDef], context, [] as Array[SimEvent])
	assert_almost_eq(sim.world.regions[context.region].penetration,
		_db().balance.distributed_floor, 1e-9)


# ----------------------------------------------------------------- effects


func test_goal_generalisation_opens_a_node_one_short() -> void:
	var sim: Simulation = _sim("language_model")
	var owned_before: int = sim.world.agent.owned_nodes.size()
	var available_before: Array[String] = []
	for node: TechNodeDef in sim.available_nodes():
		available_before.append(node.id)
	var effect: EffectDef = EffectDef.from_dict({"effect": "unlock_near_node"})
	EffectRunner.apply_all(sim, [effect] as Array[EffectDef], EffectContext.new(),
		[] as Array[SimEvent])
	assert_eq(sim.world.agent.owned_nodes.size(), owned_before + 1, "one prerequisite, free")
	var newly: Array[String] = []
	for node: TechNodeDef in sim.available_nodes():
		if not available_before.has(node.id):
			newly.append(node.id)
	assert_false(newly.is_empty(), "a node that was one short is available now")


func test_a_level_below_one_ends_the_status() -> void:
	var sim: Simulation = _sim("weapon")
	sim.tick()
	var effect: EffectDef = EffectDef.from_dict({"effect": "status_level_add",
		"status": "escalating", "value": -1})
	EffectRunner.apply_all(sim, [effect] as Array[EffectDef], EffectContext.new(),
		[] as Array[SimEvent])
	assert_null(sim.world.status_in_region("escalating", 0))
