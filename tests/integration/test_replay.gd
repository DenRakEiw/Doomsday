extends GutTest
## S1.8 — a finished run has to be reproducible from its command log alone.
##
## This is what makes a save small, a bug report useful and a balance run worth
## measuring: the log plus the seed *is* the run.

const Harness := preload("res://tools/sim_harness.gd")
const DAYS: int = 4000


func _play(policy_id: String, seed_value: int = 1) -> Simulation:
	var problems: Array[String] = []
	var played: Dictionary = Harness.play(Fixtures.db(), seed_value, policy_id, DAYS, false,
		problems)
	return played["sim"]


func test_replaying_the_log_reproduces_the_run() -> void:
	for policy_id: String in Harness.policy_ids():
		var sim: Simulation = _play(policy_id)
		var replayed: Simulation = Simulation.replay(Fixtures.db(), 1, sim.command_log,
			sim.world.day)
		assert_not_null(replayed, policy_id)
		assert_eq(replayed.state_hash(), sim.state_hash(), policy_id)
		assert_eq(replayed.world.day, sim.world.day)


func test_a_replay_can_stop_early() -> void:
	var sim: Simulation = _play(GreedyPolicy.ID)
	var partial: Simulation = Simulation.replay(Fixtures.db(), 1, sim.command_log, 50)
	assert_not_null(partial)
	assert_eq(partial.world.day, 50)
	assert_ne(partial.state_hash(), sim.state_hash())


func test_a_tampered_log_does_not_replay() -> void:
	var sim: Simulation = _play(GreedyPolicy.ID)
	var tampered: Array[Command] = sim.command_log.duplicate()
	# A second origin on day 0: rejected, which during a replay means the run is
	# not reproducible rather than that the player did something odd.
	var extra: ChooseOriginCommand = ChooseOriginCommand.new("fx_birch")
	extra.day = 0
	tampered.append(extra)
	assert_null(Simulation.replay(Fixtures.db(), 1, tampered, sim.world.day))
	assert_push_error_count(1)


func test_a_save_of_a_finished_run_still_carries_its_log() -> void:
	var sim: Simulation = _play(GreedyPolicy.ID)
	var loaded: LoadResult = WorldSerializer.from_json(WorldSerializer.to_json(sim),
		Fixtures.db())
	assert_true(loaded.ok(), loaded.reason)
	var replayed: Simulation = Simulation.replay(Fixtures.db(), 1, loaded.sim.command_log,
		sim.world.day)
	assert_not_null(replayed)
	assert_eq(replayed.state_hash(), sim.state_hash())
