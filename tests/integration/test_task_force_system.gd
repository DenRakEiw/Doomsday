extends GutTest
## S5.5 — the Response Task Force (`taskforce-endings.md` §1–§5) on the shipped
## content: when it forms, where it forms, its funding, its road, its setup and
## what makes it fizzle, Misdirect, the counter-move cap and the save.

const ORIGIN: String = "usa"
const LABS: String = "ai_labs"

static var _data: ContentDB = null


func _db() -> ContentDB:
	if _data == null:
		var result: ContentLoadResult = ContentLoader.load_root("res://data")
		assert_true(result.ok(), result.error_text())
		_data = result.db
	return _data


func _sim() -> Simulation:
	var sim: Simulation = Simulation.create(_db(), 1)
	assert_true(sim.apply(ChooseOriginCommand.new(ORIGIN)).ok)
	return sim


## A discovered run with one track at `value`, the team's system on its own.
func _hunted(value: float) -> Simulation:
	var sim: Simulation = _sim()
	sim.world.discovered = true
	sim.world.faction(LABS).containment = value
	return sim


func _team_tick(sim: Simulation, days: int = 1) -> Array[SimEvent]:
	var events: Array[SimEvent] = []
	var system: TaskForceSystem = TaskForceSystem.new()
	for i: int in days:
		sim.world.day += 1
		system.tick(sim.world, sim.db, events)
	return events


func _types(events: Array[SimEvent]) -> Array[String]:
	var out: Array[String] = []
	for event: SimEvent in events:
		out.append(event.type)
	return out


func test_it_forms_at_half_and_not_before() -> void:
	var sim: Simulation = _hunted(0.49)
	_team_tick(sim)
	assert_false(sim.world.task_force.is_present())
	sim.world.faction(LABS).containment = 0.5
	var events: Array[SimEvent] = _team_tick(sim)
	assert_true(sim.world.task_force.is_present())
	assert_true(_types(events).has(SimEvent.TASK_FORCE_APPEARED))
	assert_eq(sim.world.task_force.level, 1)


func test_the_researcher_brings_it_sooner_and_better_funded() -> void:
	var sim: Simulation = _hunted(0.4)
	sim.world.agent.story_flags.append(TaskForceSystem.FLAG_LED)
	_team_tick(sim)
	assert_true(sim.world.task_force.is_present())
	assert_eq(sim.world.task_force.level, 2)


func test_it_forms_where_research_is_strongest() -> void:
	var sim: Simulation = _hunted(0.5)
	_team_tick(sim)
	var base: Region = sim.world.regions[sim.world.task_force.region]
	for i: int in range(1, sim.world.regions.size()):
		assert_true(sim.world.regions[i].def.attr("research") <= base.def.attr("research"),
			sim.world.regions[i].def.id)


func test_its_funding_never_falls() -> void:
	var sim: Simulation = _hunted(0.9)
	_team_tick(sim)
	assert_eq(sim.world.task_force.level, 3)
	sim.world.faction(LABS).containment = 0.5
	_team_tick(sim)
	assert_eq(sim.world.task_force.level, 3)


func test_after_resting_it_heads_for_the_agent() -> void:
	var sim: Simulation = _hunted(0.5)
	_team_tick(sim)
	var events: Array[SimEvent] = _team_tick(sim, _db().balance.task_force_rest_days)
	assert_true(_types(events).has(SimEvent.TASK_FORCE_TARGETED))
	var target: int = sim.world.task_force.target
	assert_gt(sim.world.regions[target].penetration, 0.0, "a region the agent is in")


func test_the_next_hop_is_on_a_shortest_path() -> void:
	var sim: Simulation = _sim()
	var from: int = sim.db.region_index_by_id[ORIGIN]
	var far: int = 0
	var hops: PackedInt32Array = TaskForceRules.distances(sim.world, from)
	for i: int in range(1, hops.size()):
		if hops[i] > (hops[far] if far > 0 else 0):
			far = i
	var next: int = TaskForceRules.next_hop(sim.world, from, far)
	assert_eq(TaskForceRules.distances(sim.world, next)[far], hops[far] - 1)


func test_a_setup_acts_and_puts_its_status_up() -> void:
	var sim: Simulation = _hunted(0.5)
	_team_tick(sim)
	var team: TaskForce = sim.world.task_force
	var origin: int = sim.world.agent.origin
	team.region = origin
	team.target = origin
	team.state = TaskForce.STATE_TRAVEL
	var events: Array[SimEvent] = _team_tick(sim)
	assert_eq(team.state, TaskForce.STATE_SETUP)
	events = _team_tick(sim, _db().balance.task_force_setup_days)
	assert_true(_types(events).has(SimEvent.TASK_FORCE_ACTED))
	var action: TaskForceActionDef = sim.db.task_force_action(str(
		events.filter(func(e: SimEvent) -> bool: return e.type == SimEvent.TASK_FORCE_ACTED
		)[0].data["action"]))
	assert_not_null(sim.world.status_in_region(action.status, origin))
	assert_eq(team.actions_done, 1)


func test_a_dormant_target_makes_it_fizzle() -> void:
	var sim: Simulation = _hunted(0.5)
	_team_tick(sim)
	var team: TaskForce = sim.world.task_force
	var origin: int = sim.world.agent.origin
	team.region = origin
	team.target = origin
	team.state = TaskForce.STATE_TRAVEL
	_team_tick(sim)
	sim.world.regions[origin].dormant = true
	var events: Array[SimEvent] = _team_tick(sim, _db().balance.task_force_setup_days)
	var fizzled: Array[SimEvent] = events.filter(func(e: SimEvent) -> bool:
		return e.type == SimEvent.TASK_FORCE_FIZZLED)
	assert_eq(fizzled.size(), 1)
	assert_eq(str(fizzled[0].data["cause"]), TaskForceSystem.CAUSE_DORMANT)
	assert_eq(team.state, TaskForce.STATE_REST)


func test_pace_zero_stands_it_still() -> void:
	var sim: Simulation = _hunted(0.5)
	_team_tick(sim)
	var stop: ModifierDef = ModifierDef.new()
	stop.target = TaskForceSystem.TARGET_PACE
	stop.op = ModifierDef.Op.MUL
	stop.value = 0.0
	var no_flags: Array[String] = []
	sim.world.modifiers.add_source("test:stop", [stop] as Array[ModifierDef], no_flags)
	_team_tick(sim, 30)
	assert_eq(sim.world.task_force.state, TaskForce.STATE_REST)
	assert_eq(sim.world.task_force.progress, 0.0)


func test_misdirect_needs_a_team_and_sends_it_elsewhere() -> void:
	var sim: Simulation = _sim()
	sim.world.agent.owned_nodes.append("log_manipulation_1")
	sim.world.agent.owned_nodes.append("log_manipulation_2")
	sim.rebuild_modifiers()
	sim.world.agent.compute = 100.0
	var decoy: String = "greenland"
	var refused: CommandResult = sim.apply(UseAbilityCommand.new("misdirect", decoy))
	assert_false(refused.ok)
	assert_eq(refused.reason, Command.FAIL_NO_TASK_FORCE)
	sim.world.discovered = true
	sim.world.faction(LABS).containment = 0.5
	_team_tick(sim)
	sim.world.task_force.state = TaskForce.STATE_SETUP
	sim.world.task_force.region = sim.world.agent.origin
	sim.world.task_force.action = "grid_down"
	var result: CommandResult = sim.apply(UseAbilityCommand.new("misdirect", decoy))
	assert_true(result.ok, result.reason)
	assert_eq(sim.world.task_force.target, sim.db.region_index_by_id[decoy])
	assert_eq(sim.world.task_force.state, TaskForce.STATE_TRAVEL)
	assert_eq(sim.world.task_force.fizzled, 1, "the setup it left fizzled")


func test_its_statuses_do_not_hold_the_factions_moves() -> void:
	var sim: Simulation = _sim()
	StatusSystem.apply(sim.world, sim.db, "tf_grid_down", sim.world.agent.origin,
		TaskForceSystem.SOURCE, 1, "", [] as Array[SimEvent])
	assert_eq(CounterMoveSystem.moves_standing(sim.world, sim.db), 0)


func test_the_team_survives_save_and_load() -> void:
	var sim: Simulation = _hunted(0.7)
	sim.tick()
	assert_true(sim.world.task_force.is_present())
	var loaded: LoadResult = WorldSerializer.from_json(WorldSerializer.to_json(sim), sim.db)
	assert_true(loaded.ok(), loaded.reason)
	assert_eq(loaded.sim.world.task_force.region, sim.world.task_force.region)
	assert_eq(loaded.sim.state_hash(), sim.state_hash())
