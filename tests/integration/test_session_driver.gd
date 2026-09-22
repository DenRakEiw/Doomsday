extends GutTest
## S2.1 — the autoloads driving a real run: `Game` advances the simulation and
## reports it on `EventBus`, `SaveManager` puts it on disk and brings it back.
##
## The real content and the real autoloads, because that is the thing being
## built: the accumulator itself is tested as a pure function in
## `test_game_accumulator.gd`.

const SEED: int = 1
const SLOT: String = "gut_session_driver"
## Long enough for an origin, purchases, anomalies and a phase change.
const WARMUP_DAYS: int = 60
const CONTINUE_DAYS: int = 40
## `greedy` on seed 1 ends well inside this.
const MAX_DAYS: int = 2000


func before_each() -> void:
	Game.stop_run()
	Game.debug_log = false


func after_all() -> void:
	SaveManager.delete(SLOT)
	Game.stop_run()


## A bot run that is not driven by the clock: the test decides when a day passes.
func _start(policy_id: String = GreedyPolicy.ID) -> void:
	Game.start_run(SEED, policy_id)
	Game.set_speed(0)
	assert_not_null(Game.sim, "content loaded and a run exists")


func test_advancing_moves_the_world_and_reports_every_day() -> void:
	watch_signals(EventBus)
	_start()
	Game.advance(WARMUP_DAYS)
	assert_eq(Game.sim.world.day, WARMUP_DAYS)
	assert_signal_emit_count(EventBus, "tick_advanced", WARMUP_DAYS)
	assert_gt(get_signal_emit_count(EventBus, "sim_event"), 0, "the outbox reaches the bus")


func test_a_bot_run_plays_through_the_same_door_a_player_uses() -> void:
	watch_signals(EventBus)
	_start()
	Game.advance(WARMUP_DAYS)
	assert_gt(Game.sim.world.agent.origin, 0, "the bot chose an origin")
	assert_gt(Game.sim.world.agent.owned_nodes.size(), 0, "and bought something")
	assert_gt(get_signal_emit_count(EventBus, "command_applied"), 0,
		"every command is reported, not only the events it caused")


func test_the_compute_rate_never_counts_a_purchase() -> void:
	_start()
	for i: int in WARMUP_DAYS:
		Game.advance(1)
		assert_gte(Game.compute_rate, 0.0, "day %d: yield and rewards only" % Game.sim.world.day)


func test_a_run_without_a_policy_starts_paused_and_stands_still() -> void:
	Game.start_run(SEED)
	assert_eq(Game.speed, 0, "the player chooses the origin before time runs")
	assert_eq(Game.sim.world.day, 0)


func test_only_the_four_speeds_are_accepted() -> void:
	watch_signals(EventBus)
	_start()
	Game.set_speed(4)
	assert_eq(Game.speed, 4)
	Game.set_speed(3)
	assert_eq(Game.speed, 0, "an unknown speed pauses rather than guesses")
	assert_signal_emit_count(EventBus, "speed_changed", 4,
		"the bot run starts at 1x, the test pauses it, then 4, then 0")


func test_the_end_of_a_run_pauses_it_and_names_the_outcome() -> void:
	watch_signals(EventBus)
	_start()
	Game.set_speed(2)
	Game.advance(MAX_DAYS)
	assert_ne(Game.sim.world.outcome, World.Outcome.NONE, "the run must have ended")
	assert_signal_emit_count(EventBus, "run_ended", 1, "once, not once per day after it")
	var reported: Array = get_signal_parameters(EventBus, "run_ended")
	assert_eq(str(reported[0]), World.OUTCOME_IDS[Game.sim.world.outcome])
	assert_eq(Game.speed, 0, "and time stops")


func test_a_saved_run_comes_back_exactly_and_carries_on() -> void:
	_start()
	Game.advance(WARMUP_DAYS)
	var at_save: String = Game.sim.state_hash()
	assert_eq(SaveManager.save(SLOT), "", "the save was written")
	assert_true(SaveManager.list_slots().has(SLOT), "and is listed")

	Game.advance(CONTINUE_DAYS)
	var straight: String = Game.sim.state_hash()

	assert_eq(SaveManager.load(SLOT), "", "the save was read")
	assert_eq(Game.sim.state_hash(), at_save, "the file restores the state exactly")
	assert_eq(Game.speed, 0, "a loaded run waits for the player")

	# `greedy` decides from the state alone, so the continuation can only differ
	# if the state did.
	Game.advance(CONTINUE_DAYS)
	assert_eq(Game.sim.state_hash(), straight, "F9 then F10 continues the same run")


func test_saving_without_a_run_is_refused_not_crashed() -> void:
	assert_eq(SaveManager.save(SLOT + "_none"), SaveManager.REASON_NO_RUN)
	assert_false(SaveManager.list_slots().has(SLOT + "_none"))


func test_loading_a_slot_that_is_not_there_is_refused() -> void:
	_start()
	assert_eq(SaveManager.load(SLOT + "_missing"), SaveManager.REASON_NOT_FOUND)
	assert_eq(Game.sim.world.day, 0, "and the running game is untouched")
