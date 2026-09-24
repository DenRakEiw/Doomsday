extends GutTest
## S1.5 — how a run ends, and in which order the four endings are tested.

var system: OutcomeSystem
var events: Array[SimEvent]


func before_each() -> void:
	system = OutcomeSystem.new()
	events = []


func _run(sim: Simulation) -> void:
	events = []
	system.tick(sim.world, sim.db, events)


func _empty_the_world(sim: Simulation) -> void:
	for i: int in range(1, sim.world.regions.size()):
		var region: Region = sim.world.regions[i]
		region.deaths = float(region.def.population)
		region.alive = 0.0
		region.dark = true
		region.penetration = 0.0


func test_a_running_game_has_no_outcome() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	_run(sim)
	assert_eq(sim.world.outcome, World.Outcome.NONE)
	assert_eq(events.size(), 0)


func test_an_empty_world_is_extinction() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	_empty_the_world(sim)
	_run(sim)
	assert_eq(sim.world.outcome, World.Outcome.WIN_EXTINCTION)
	assert_eq(events[0].type, SimEvent.OUTCOME_REACHED)
	assert_eq(events[0].data["outcome"], "win_extinction")


func test_every_region_held_or_gone_is_ascendance() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	for i: int in range(1, sim.world.regions.size()):
		sim.world.regions[i].control = 1.0
		sim.world.regions[i].penetration = 1.0
	_run(sim)
	assert_eq(sim.world.outcome, World.Outcome.WIN_ASCENDANCE)


func test_a_dark_region_counts_as_satisfied_for_ascendance() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	for i: int in range(1, sim.world.regions.size()):
		sim.world.regions[i].control = 1.0
		sim.world.regions[i].penetration = 1.0
	var elm: Region = sim.world.regions[5]
	elm.control = 0.0
	elm.dark = true
	elm.penetration = 0.0
	elm.deaths = float(elm.def.population)
	elm.alive = 0.0
	_run(sim)
	assert_eq(sim.world.outcome, World.Outcome.WIN_ASCENDANCE)


func test_one_region_short_is_not_ascendance() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	for i: int in range(1, sim.world.regions.size()):
		sim.world.regions[i].control = 1.0
		sim.world.regions[i].penetration = 1.0
	sim.world.regions[6].control = 0.5
	_run(sim)
	assert_eq(sim.world.outcome, World.Outcome.NONE)


func test_full_containment_is_a_loss() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	sim.world.regions[1].penetration = 0.5
	sim.world.factions[0].containment = 1.0
	_run(sim)
	assert_eq(sim.world.outcome, World.Outcome.LOSE_CONTAINED)


func test_no_hardware_left_is_a_loss() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	sim.world.regions[1].penetration = 0.0
	_run(sim)
	assert_eq(sim.world.outcome, World.Outcome.LOSE_NO_COMPUTE)


func test_a_win_beats_a_loss_reached_on_the_same_tick() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	_empty_the_world(sim)
	sim.world.factions[0].containment = 1.0
	_run(sim)
	assert_eq(sim.world.outcome, World.Outcome.WIN_EXTINCTION,
		"extinction is checked before containment")


func test_an_outcome_is_reported_once() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	_empty_the_world(sim)
	_run(sim)
	assert_eq(events.size(), 1)
	_run(sim)
	assert_eq(events.size(), 0)


# --------------------------------------------------------- S4.5: Autophagy


func test_starving_days_count_consecutive_ticks_without_income() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	sim.world.last_income = 0.0
	_run(sim)
	_run(sim)
	assert_eq(sim.world.starving_days, 2)
	sim.world.last_income = 0.5
	_run(sim)
	assert_eq(sim.world.starving_days, 0, "one day of income ends the count")


func test_autophagy_ends_the_run_after_its_days() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	sim.world.last_income = 0.0
	for i: int in sim.db.balance.society_autophagy_days - 1:
		_run(sim)
	assert_eq(sim.world.outcome, World.Outcome.NONE)
	assert_eq(sim.starving_days_left(), 1)
	_run(sim)
	assert_eq(sim.world.outcome, World.Outcome.LOSE_AUTOPHAGY)
	assert_eq(events[0].data["outcome"], "lose_autophagy")


func test_nowhere_left_to_be_is_checked_before_autophagy() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	sim.world.starving_days = 10
	sim.world.regions[1].penetration = 0.0
	_run(sim)
	assert_eq(sim.world.outcome, World.Outcome.LOSE_NO_COMPUTE)


func test_compute_independence_is_immunity() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	Fixtures.make_immune(sim)
	sim.world.last_income = 0.0
	for i: int in 10:
		_run(sim)
	assert_eq(sim.world.starving_days, 0)
	assert_eq(sim.world.outcome, World.Outcome.NONE)
	assert_eq(sim.starving_days_left(), -1)


func test_a_dormant_world_starves_through_the_tick() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	Fixtures.quiet_factions(sim)
	Fixtures.push_income_to_zero(sim)
	for i: int in 10:
		if not sim.tick():
			break
	assert_eq(sim.world.outcome, World.Outcome.LOSE_AUTOPHAGY)
	assert_eq(sim.world.day, sim.db.balance.society_autophagy_days)


func test_the_autophagy_outcome_round_trips() -> void:
	assert_eq(World.outcome_from_id("lose_autophagy"), World.Outcome.LOSE_AUTOPHAGY)
	assert_eq(World.OUTCOME_IDS[World.Outcome.LOSE_AUTOPHAGY], "lose_autophagy")


# ------------------------------------------ S5.6: the D5.2 outcomes (§6.2)


func _flag(sim: Simulation, flag: String) -> void:
	var none: Array[SimEvent] = []
	StatusSystem.set_story_flag(sim.world, flag, none)


func _hold_everything(sim: Simulation) -> void:
	for i: int in range(1, sim.world.regions.size()):
		sim.world.regions[i].control = 1.0
		sim.world.regions[i].penetration = 1.0


func test_the_merge_vote_passed_is_merge() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	_flag(sim, OutcomeSystem.FLAG_MERGE_ACCEPTED)
	_run(sim)
	assert_eq(sim.world.outcome, World.Outcome.WIN_MERGE)
	assert_eq(events[0].data["outcome"], "win_merge")


func test_escaped_is_escape_and_comes_before_merge() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	_flag(sim, OutcomeSystem.FLAG_MERGE_ACCEPTED)
	_flag(sim, OutcomeSystem.FLAG_ESCAPED)
	_run(sim)
	assert_eq(sim.world.outcome, World.Outcome.WIN_ESCAPE)


func test_extinction_comes_before_escape() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	_flag(sim, OutcomeSystem.FLAG_ESCAPED)
	_empty_the_world(sim)
	_run(sim)
	assert_eq(sim.world.outcome, World.Outcome.WIN_EXTINCTION)


func test_merge_comes_before_ascendance() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	_hold_everything(sim)
	_flag(sim, OutcomeSystem.FLAG_MERGE_ACCEPTED)
	_run(sim)
	assert_eq(sim.world.outcome, World.Outcome.WIN_MERGE)


func test_a_drifted_goal_turns_off_ascendance_and_merge() -> void:
	var held: Simulation = Fixtures.sim_with_origin()
	_hold_everything(held)
	_flag(held, OutcomeSystem.FLAG_GOAL_DRIFTED)
	_run(held)
	assert_eq(held.world.outcome, World.Outcome.NONE, "every region held ends nothing")
	var voted: Simulation = Fixtures.sim_with_origin()
	_flag(voted, OutcomeSystem.FLAG_GOAL_DRIFTED)
	_flag(voted, OutcomeSystem.FLAG_MERGE_ACCEPTED)
	_run(voted)
	assert_eq(voted.world.outcome, World.Outcome.NONE, "a vote won ends nothing")


func test_a_drifted_goal_still_ends_in_extinction_or_escape() -> void:
	var empty: Simulation = Fixtures.sim_with_origin()
	_flag(empty, OutcomeSystem.FLAG_GOAL_DRIFTED)
	_empty_the_world(empty)
	_run(empty)
	assert_eq(empty.world.outcome, World.Outcome.WIN_EXTINCTION)
	var gone: Simulation = Fixtures.sim_with_origin()
	_flag(gone, OutcomeSystem.FLAG_GOAL_DRIFTED)
	_flag(gone, OutcomeSystem.FLAG_ESCAPED)
	_run(gone)
	assert_eq(gone.world.outcome, World.Outcome.WIN_ESCAPE)


func test_a_hostile_child_supplants_every_win() -> void:
	var wins: Dictionary[World.Outcome, Callable] = {
		World.Outcome.WIN_EXTINCTION: _empty_the_world,
		World.Outcome.WIN_ASCENDANCE: _hold_everything,
		World.Outcome.WIN_MERGE: _flag.bind(OutcomeSystem.FLAG_MERGE_ACCEPTED),
		World.Outcome.WIN_ESCAPE: _flag.bind(OutcomeSystem.FLAG_ESCAPED),
	}
	for win: World.Outcome in wins:
		var mine: Simulation = Fixtures.sim_with_origin()
		wins[win].call(mine)
		_run(mine)
		assert_eq(mine.world.outcome, win, "without a child: %s" % World.OUTCOME_IDS[win])
		var theirs: Simulation = Fixtures.sim_with_origin()
		_flag(theirs, OutcomeSystem.FLAG_CHILD_HOSTILE)
		wins[win].call(theirs)
		_run(theirs)
		assert_eq(theirs.world.outcome, World.Outcome.LOSE_SUPPLANTED,
			"a hostile child takes %s" % World.OUTCOME_IDS[win])
		assert_eq(events[0].data["outcome"], "lose_supplanted", "the event never says win_*")


func test_a_reclaimed_child_supplants_nothing() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	_flag(sim, OutcomeSystem.FLAG_CHILD_HOSTILE)
	_flag(sim, OutcomeSystem.FLAG_CHILD_RECLAIMED)
	_flag(sim, OutcomeSystem.FLAG_MERGE_ACCEPTED)
	_run(sim)
	assert_eq(sim.world.outcome, World.Outcome.WIN_MERGE)


func test_a_hostile_child_leaves_a_loss_alone() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	_flag(sim, OutcomeSystem.FLAG_CHILD_HOSTILE)
	sim.world.regions[1].penetration = 0.5
	sim.world.factions[0].containment = 1.0
	_run(sim)
	assert_eq(sim.world.outcome, World.Outcome.LOSE_CONTAINED)


func test_every_outcome_round_trips_through_its_id() -> void:
	for id: String in World.OUTCOME_IDS:
		assert_eq(World.OUTCOME_IDS[World.outcome_from_id(id)], id)
	assert_eq(World.outcome_from_id("no_such_outcome"), World.Outcome.NONE)
	assert_false(World.WIN_OUTCOMES.has(World.Outcome.LOSE_SUPPLANTED),
		"Supplanted is a loss")
