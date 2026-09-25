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


# ------------------------------------ S5.9: the mark (taskforce-endings.md §14)


## A team set up on the origin, `setup_days` of work still ahead of it.
func _set_up_on_origin() -> Simulation:
	var sim: Simulation = _hunted(0.5)
	_team_tick(sim)
	var team: TaskForce = sim.world.task_force
	var origin: int = sim.world.agent.origin
	team.region = origin
	team.target = origin
	team.state = TaskForce.STATE_TRAVEL
	_team_tick(sim)
	assert_eq(team.state, TaskForce.STATE_SETUP)
	return sim


## The origin slept through a setup: the team found it asleep and marked it.
func _slept_through() -> Simulation:
	var sim: Simulation = _set_up_on_origin()
	sim.world.regions[sim.world.agent.origin].dormant = true
	_team_tick(sim, _db().balance.task_force_setup_days)
	return sim


func _of(events: Array[SimEvent], type: String) -> Array[SimEvent]:
	return events.filter(func(e: SimEvent) -> bool: return e.type == type)


func test_a_dormant_fizzle_marks_the_region_for_mark_days() -> void:
	var sim: Simulation = _set_up_on_origin()
	var origin: int = sim.world.agent.origin
	sim.world.regions[origin].dormant = true
	var events: Array[SimEvent] = _team_tick(sim, _db().balance.task_force_setup_days)
	var types: Array[String] = _types(events)
	var fizzled: int = types.find(SimEvent.TASK_FORCE_FIZZLED)
	assert_gt(fizzled, -1)
	assert_eq(types[fizzled + 1], SimEvent.TASK_FORCE_MARKED, "right after the fizzle")
	var marked: SimEvent = events[fizzled + 1]
	assert_eq(str(marked.data["region"]), ORIGIN)
	assert_eq(int(marked.data["days"]), _db().balance.task_force_mark_days)
	assert_eq(sim.world.task_force.marked[origin],
		marked.day + _db().balance.task_force_mark_days)
	assert_true(sim.world.task_force.is_marked(origin, sim.world.day))


func test_a_marked_dormant_region_is_eligible_and_its_setup_acts() -> void:
	var sim: Simulation = _slept_through()
	var team: TaskForce = sim.world.task_force
	var origin: int = sim.world.agent.origin
	assert_true(sim.world.regions[origin].dormant, "still asleep")
	assert_false(TaskForceRules.dormancy_hides(sim.world, origin))
	assert_true(TaskForceRules.eligible(sim.world, sim.db, origin))
	assert_eq(TaskForceRules.fizzle_cause(sim.world, sim.db, origin), "")
	team.target = origin
	team.state = TaskForce.STATE_TRAVEL
	_team_tick(sim)
	assert_eq(team.state, TaskForce.STATE_SETUP, "it sets up on the sleeping region")
	var events: Array[SimEvent] = _team_tick(sim, _db().balance.task_force_setup_days)
	var acted: Array[SimEvent] = _of(events, SimEvent.TASK_FORCE_ACTED)
	assert_eq(acted.size(), 1)
	var action: TaskForceActionDef = sim.db.task_force_action(str(acted[0].data["action"]))
	assert_not_null(sim.world.status_in_region(action.status, origin),
		"the status lands on the sleeping region")
	assert_eq(_of(events, SimEvent.TASK_FORCE_MARKED).size(), 0)


func test_the_mark_runs_out_on_until_and_dormancy_hides_again() -> void:
	var sim: Simulation = _slept_through()
	var origin: int = sim.world.agent.origin
	var until: int = sim.world.task_force.marked[origin]
	sim.world.day = until - 1
	assert_false(TaskForceRules.dormancy_hides(sim.world, origin))
	sim.world.day = until
	assert_true(TaskForceRules.dormancy_hides(sim.world, origin))
	assert_false(TaskForceRules.eligible(sim.world, sim.db, origin))
	assert_eq(TaskForceRules.fizzle_cause(sim.world, sim.db, origin),
		TaskForceSystem.CAUSE_DORMANT)


func test_an_expired_mark_is_dropped_at_the_start_of_the_tick() -> void:
	var sim: Simulation = _slept_through()
	var origin: int = sim.world.agent.origin
	sim.world.day = sim.world.task_force.marked[origin] - 2
	_team_tick(sim)
	assert_true(sim.world.task_force.marked.has(origin), "one day left")
	_team_tick(sim)
	assert_false(sim.world.task_force.marked.has(origin), "gone on its last day")


func test_hidden_clean_dark_and_redirected_fizzles_mark_nothing() -> void:
	var breaks: Array[Callable] = [
		func(sim: Simulation, _origin: int) -> void:
			var hide: ModifierDef = ModifierDef.new()
			hide.target = TaskForceRules.TARGET_CAPACITY
			hide.op = ModifierDef.Op.ADD
			hide.value = -1.0
			var no_flags: Array[String] = []
			sim.world.modifiers.add_source("test:hide", [hide] as Array[ModifierDef], no_flags),
		func(sim: Simulation, origin: int) -> void:
			sim.world.regions[origin].penetration = 0.0,
		func(sim: Simulation, origin: int) -> void:
			sim.world.regions[origin].dark = true,
		func(sim: Simulation, _origin: int) -> void:
			TaskForceSystem.redirect(sim.world, sim.db.region_index_by_id["greenland"],
				[] as Array[SimEvent]),
	]
	var causes: Array[String] = [TaskForceSystem.CAUSE_HIDDEN, TaskForceSystem.CAUSE_CLEAN,
		SimEvent.CAUSE_DARK, TaskForceSystem.CAUSE_REDIRECTED]
	for i: int in breaks.size():
		var sim: Simulation = _set_up_on_origin()
		var origin: int = sim.world.agent.origin
		var before: int = sim.world.task_force.fizzled
		breaks[i].call(sim, origin)
		var events: Array[SimEvent] = _team_tick(sim, _db().balance.task_force_setup_days)
		assert_gte(sim.world.task_force.fizzled, before + 1, causes[i])
		if causes[i] != TaskForceSystem.CAUSE_REDIRECTED:
			assert_eq(str(_of(events, SimEvent.TASK_FORCE_FIZZLED)[0].data["cause"]), causes[i])
		assert_eq(_of(events, SimEvent.TASK_FORCE_MARKED).size(), 0, causes[i])
		assert_true(sim.world.task_force.marked.is_empty(), causes[i])


func test_dormancy_while_it_travels_retargets_and_marks_nothing() -> void:
	var sim: Simulation = _hunted(0.5)
	_team_tick(sim)
	var team: TaskForce = sim.world.task_force
	var origin: int = sim.world.agent.origin
	team.target = origin
	team.region = sim.db.region_index_by_id["greenland"]
	team.state = TaskForce.STATE_TRAVEL
	sim.world.regions[origin].dormant = true
	var events: Array[SimEvent] = _team_tick(sim)
	assert_ne(team.target, origin, "it chose again")
	assert_eq(_of(events, SimEvent.TASK_FORCE_FIZZLED).size(), 0)
	assert_true(team.marked.is_empty())


func test_a_misled_team_that_finds_its_decoy_asleep_marks_it() -> void:
	var sim: Simulation = _hunted(0.5)
	_team_tick(sim)
	var team: TaskForce = sim.world.task_force
	var decoy: int = sim.db.region_index_by_id["greenland"]
	sim.world.regions[decoy].penetration = 0.2
	sim.world.regions[decoy].dormant = true
	team.region = decoy
	team.target = decoy
	team.misled = true
	team.state = TaskForce.STATE_TRAVEL
	var events: Array[SimEvent] = _team_tick(sim)
	assert_eq(str(_of(events, SimEvent.TASK_FORCE_FIZZLED)[0].data["cause"]),
		TaskForceSystem.CAUSE_DORMANT)
	assert_eq(_of(events, SimEvent.TASK_FORCE_MARKED).size(), 1)
	assert_true(team.is_marked(decoy, sim.world.day))


func test_the_same_seed_marks_the_same_way() -> void:
	var hashes: Array[String] = []
	for run: int in 2:
		var sim: Simulation = _slept_through()
		for day: int in 30:
			sim.tick()
		hashes.append(sim.state_hash())
	assert_eq(hashes[0], hashes[1])


# ----------------------------------------------------- the mark in the save


func test_the_mark_round_trips_by_region_id() -> void:
	var sim: Simulation = _slept_through()
	var origin: int = sim.world.agent.origin
	var save: Dictionary = JSON.parse_string(WorldSerializer.to_json(sim))
	var block: Dictionary = (save["world"] as Dictionary)["task_force"]
	assert_eq(int((block["marked"] as Dictionary)[ORIGIN]), sim.world.task_force.marked[origin])
	var loaded: LoadResult = WorldSerializer.from_json(WorldSerializer.to_json(sim), sim.db)
	assert_true(loaded.ok(), loaded.reason)
	assert_eq(loaded.sim.world.task_force.marked, sim.world.task_force.marked)
	assert_eq(loaded.sim.state_hash(), sim.state_hash())


func _empty_block() -> Dictionary:
	return TaskForce.new().to_dict(func(_i: int) -> String: return "")


func test_a_block_without_marks_loads_with_none() -> void:
	var block: Dictionary = _empty_block()
	assert_eq(block["marked"], {}, "written even when empty")
	block.erase("marked")
	var team: TaskForce = TaskForce.from_dict(block, _db())
	assert_not_null(team)
	assert_true(team.marked.is_empty())


func test_an_unknown_region_or_a_day_that_is_no_number_is_refused() -> void:
	var block: Dictionary = _empty_block()
	block["marked"] = {"atlantis": 40}
	assert_null(TaskForce.from_dict(block, _db()))
	block["marked"] = {ORIGIN: "forty"}
	assert_null(TaskForce.from_dict(block, _db()))
	block["marked"] = [ORIGIN]
	assert_null(TaskForce.from_dict(block, _db()))


# ------------------------------------------------------ the bots (§14.5)


## A bot's answer to a setup on the origin with dormancy unlocked, Misdirect
## too when `misdirect` is true, and the origin marked when `marked` is.
func _answer(marked: bool, misdirect: bool) -> Command:
	var sim: Simulation = _set_up_on_origin()
	if misdirect:
		sim.world.agent.owned_nodes.append("log_manipulation_1")
		sim.world.agent.owned_nodes.append("log_manipulation_2")
		sim.rebuild_modifiers()
		sim.world.agent.compute = 100.0
	var no_modifiers: Array[ModifierDef] = []
	var flags: Array[String] = [ModifierDef.FLAG_DORMANCY]
	sim.world.modifiers.add_source("test:dormancy", no_modifiers, flags)
	if marked:
		sim.world.task_force.marked[sim.world.agent.origin] = sim.world.day + 10
	return GreedyPolicy.new()._answer_task_force(sim)


func test_the_bots_sleep_an_unmarked_region() -> void:
	assert_true(_answer(false, true) is SetDormancyCommand)


func test_the_bots_misdirect_from_a_marked_region() -> void:
	assert_true(_answer(true, true) is UseAbilityCommand)


func test_the_bots_do_nothing_in_a_marked_region_without_misdirect() -> void:
	assert_null(_answer(true, false))
