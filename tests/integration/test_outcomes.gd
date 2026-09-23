extends GutTest
## S1.5 — the four outcome recipes of `docs/specs/core.md` §9, played end to end
## on the fixture world.
##
## This is the step's "done when": the fixture can be won twice and lost twice by
## script. It is also the first test that runs every system together, so it
## checks the invariants after every single tick.

## A run that has not ended by here is a defect, not a long game.
const LIMIT: int = 4000


func _play(sim: Simulation) -> int:
	var days: int = 0
	while sim.world.outcome == World.Outcome.NONE and days < LIMIT:
		sim.tick()
		days += 1
		var problems: Array[String] = sim.world.check_invariants(sim.db)
		assert_eq(problems.size(), 0, "day %d: %s" % [sim.world.day, problems])
		if problems.size() > 0:
			return days
	return days


## Nothing moves after the outcome, and the history keeps the last day.
func _assert_finished(sim: Simulation, outcome: World.Outcome, days: int) -> void:
	assert_eq(World.OUTCOME_IDS[sim.world.outcome], World.OUTCOME_IDS[outcome],
		"after %d days" % days)
	assert_lt(days, LIMIT, "the run has to end on its own")
	var frozen: String = sim.state_hash()
	assert_false(sim.tick(), "a finished run does not tick")
	assert_eq(sim.state_hash(), frozen)
	assert_eq(sim.apply(ChooseOriginCommand.new("fx_birch")).reason, Command.FAIL_GAME_OVER)
	assert_eq(sim.world.history[sim.world.history.size() - 1].day, sim.world.day,
		"the last sample is the day it ended")


func _ready_sim() -> Simulation:
	var sim: Simulation = Fixtures.sim_with_origin()
	Fixtures.grant(sim, 1000.0)
	return sim


func test_ascendance_is_reachable() -> void:
	var sim: Simulation = _ready_sim()
	Fixtures.buy(sim, ["fx_vector_net", "fx_reach", "fx_bridge", "fx_grip", "fx_quiet"])
	var days: int = _play(sim)
	_assert_finished(sim, World.Outcome.WIN_ASCENDANCE, days)


func test_extinction_is_reachable() -> void:
	var sim: Simulation = _ready_sim()
	Fixtures.buy(sim, ["fx_vector_net", "fx_reach", "fx_bridge", "fx_quiet"])
	# Harm only once the agent is everywhere: killing a region early takes the
	# route with it.
	var days: int = 0
	while sim.world.seeded_count() < Fixtures.REGION_COUNT and days < LIMIT:
		sim.tick()
		days += 1
	assert_lt(days, LIMIT, "every region has to be reached first")
	# A dying world collapses and its hardware stops yielding (S4.5); without
	# its own substrate the agent would starve before the last person dies.
	Fixtures.make_immune(sim)
	Fixtures.buy(sim, ["fx_harm_1", "fx_harm_2"])
	days += _play(sim)
	_assert_finished(sim, World.Outcome.WIN_EXTINCTION, days)


func test_running_out_of_compute_is_a_loss() -> void:
	var sim: Simulation = _ready_sim()
	# Boxed in by hand: the agent kills its only home and has nowhere to go.
	for link: Link in sim.world.links:
		link.open = false
	# Wiped out, not starved and not contained: the fixture's hunger is three
	# days, and a Lockdown's decay would slow the dying.
	Fixtures.make_immune(sim)
	Fixtures.quiet_factions(sim)
	Fixtures.buy(sim, ["fx_vector_net", "fx_reach", "fx_harm_1", "fx_harm_2", "fx_quiet"])
	var days: int = _play(sim)
	_assert_finished(sim, World.Outcome.LOSE_NO_COMPUTE, days)


func test_doing_nothing_is_a_loss() -> void:
	var sim: Simulation = _ready_sim()
	var days: int = _play(sim)
	_assert_finished(sim, World.Outcome.LOSE_CONTAINED, days)


func test_the_phase_never_regresses_over_a_whole_run() -> void:
	var sim: Simulation = _ready_sim()
	Fixtures.buy(sim, ["fx_vector_net", "fx_reach", "fx_bridge", "fx_grip", "fx_quiet"])
	var previous: World.Phase = sim.world.phase
	while sim.world.outcome == World.Outcome.NONE and sim.world.day < LIMIT:
		sim.tick()
		assert_true(sim.world.phase >= previous, "day %d" % sim.world.day)
		previous = sim.world.phase
	assert_eq(sim.world.phase, World.Phase.OPEN, "a won run ends in the open")


func test_history_is_sampled_at_its_interval() -> void:
	var sim: Simulation = _ready_sim()
	Fixtures.buy(sim, ["fx_vector_net"])
	for i: int in 70:
		sim.tick()
	var interval: int = sim.db.balance.history_interval_days
	assert_eq(sim.world.history.size(), 70 / interval)
	for sample: HistorySample in sim.world.history:
		assert_eq(sample.day % interval, 0)
	assert_eq(sim.world.history[0].day, interval)


func test_the_same_seed_plays_the_same_run() -> void:
	var hashes: Array[String] = []
	for run: int in 2:
		var sim: Simulation = Fixtures.sim_with_origin("fx_alder", 3)
		Fixtures.grant(sim, 1000.0)
		Fixtures.buy(sim, ["fx_vector_net", "fx_reach", "fx_bridge", "fx_grip", "fx_quiet"])
		_play(sim)
		hashes.append(sim.state_hash())
	assert_eq(hashes[0], hashes[1])
