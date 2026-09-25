extends GutTest
## S6.13 — the spectator view (docs/specs/benchmark.md §12.3–§12.4, §14.2): a
## `mock:cheapest` entry of 300 days, made here on the real content, plays in the
## game at 4× to its recorded end and hash; the interface cannot send a command;
## the player's autosave and profile are untouched by it; an entry from other
## content is refused.

const Results: GDScript = preload("res://ui/screens/results.gd")
const MAX_DAYS: int = 300
const SEED: int = 1001
## More days than the entry has, so a replay that failed to stop shows as one.
const SAFETY_DAYS: int = MAX_DAYS + 20

static var _entry: BenchEntry = null

var _slot: Control = null
var _reduced_motion: bool = false


func before_all() -> void:
	if _entry == null:
		var config: BenchConfig = BenchConfig.load_file()
		config.max_days = MAX_DAYS
		_entry = Fixtures.bench_mock_entry(Game.content(), config, SEED)


func before_each() -> void:
	_reduced_motion = Settings.reduced_motion
	Settings.reduced_motion = true
	Game.stop_run()
	Game.debug_log = false
	SaveManager.delete(SaveManager.AUTOSAVE)
	_slot = Control.new()
	_slot.size = Vector2(1920.0, 1080.0)
	add_child_autofree(_slot)
	ScreenRouter.slot = _slot


func after_each() -> void:
	ScreenRouter.slot = null
	Settings.reduced_motion = _reduced_motion
	SaveManager.delete(SaveManager.AUTOSAVE)
	Game.stop_run()


## Advances until the run is over, a day at a time as the clock would.
func _play_out() -> void:
	for i: int in SAFETY_DAYS:
		if Game.is_run_over():
			return
		Game.advance(1)


func test_a_watched_entry_reaches_its_recorded_end_and_hash() -> void:
	assert_eq(Game.start_spectating(_entry), "")
	assert_true(Game.is_spectating())
	assert_eq(Game.speed, Game.SPECTATOR_SPEED, "a watched run starts at 4×")
	watch_signals(EventBus)
	_play_out()
	assert_true(Game.is_run_over())
	assert_eq(Game.sim.world.day, _entry.end_day)
	var outcome: String = World.OUTCOME_IDS[Game.sim.world.outcome] \
		if Game.sim.world.outcome != World.Outcome.NONE else BenchEntry.OUTCOME_TIMEOUT
	assert_eq(outcome, _entry.outcome)
	assert_eq(Game.sim.state_hash(), _entry.state_hash, "the recorded hash")
	assert_eq(Game.spectator().diverged_day, -1)
	assert_signal_emitted_with_parameters(EventBus, "run_ended", [_entry.outcome])
	Game.advance(5)
	assert_eq(Game.sim.world.day, _entry.end_day, "nothing is played past the recording")


func test_the_interface_cannot_send_a_command() -> void:
	Game.start_spectating(_entry)
	Game.advance(12)
	var result: CommandResult = Game.apply(PurchaseNodeCommand.new("open_weights_leak"))
	assert_false(result.ok)
	assert_eq(result.reason, Game.FAIL_SPECTATING)
	assert_eq(Game.sim.command_log.size(), _count_until(Game.sim.world.day),
		"only the recording's commands reached the simulation")


func test_the_player_s_autosave_and_profile_survive_a_watched_run() -> void:
	# The player's run, saved as the session saves it after a command.
	Game.start_run(1)
	Game.apply(ChooseOriginCommand.new(Game.db.regions[1].id))
	assert_eq(SaveManager.save(SaveManager.AUTOSAVE), "")
	var runs_before: int = ProfileManager.runs_completed
	assert_eq(ScreenRouter.start_spectating(_entry), "")
	assert_eq(ScreenRouter.current, ScreenRouter.Screen.SESSION)
	_play_out()
	assert_true(Game.is_run_over())
	assert_true(SaveManager.has_slot(SaveManager.AUTOSAVE),
		"the watched run ended and the autosave is still there")
	assert_eq(ProfileManager.runs_completed, runs_before, "a watched run counts for nothing")


func test_an_entry_from_other_content_is_refused() -> void:
	var other: BenchEntry = BenchEntry.from_json(_entry.to_json())
	other.content_hash = "0".repeat(64)
	ScreenRouter.go_to_title()
	assert_eq(Game.spectate_blocker(other), Game.FAIL_BENCH_CONTENT)
	assert_eq(ScreenRouter.start_spectating(other), Game.FAIL_BENCH_CONTENT)
	assert_null(Game.sim, "nothing started")
	assert_eq(ScreenRouter.current, ScreenRouter.Screen.TITLE, "the screen stays")


func test_an_entry_with_an_unknown_setup_is_refused() -> void:
	var other: BenchEntry = BenchEntry.from_json(_entry.to_json())
	other.setup.architecture = "no_such_architecture"
	assert_eq(Game.spectate_blocker(other), Command.FAIL_SETUP_INVALID)


func test_a_plain_bot_run_keeps_the_autosave_too() -> void:
	ScreenRouter.start_new_run()
	Game.apply(ChooseOriginCommand.new(Game.db.regions[1].id))
	assert_true(SaveManager.has_slot(SaveManager.AUTOSAVE))
	Game.start_run(1, GreedyPolicy.ID)
	EventBus.run_ended.emit(World.OUTCOME_IDS[World.Outcome.LOSE_CONTAINED])
	assert_true(SaveManager.has_slot(SaveManager.AUTOSAVE),
		"a debug bot run no longer deletes the player's autosave")


func test_the_results_of_a_watched_run_say_it_was_verified() -> void:
	assert_eq(ScreenRouter.start_spectating(_entry), "")
	var session: Control = ScreenRouter.screen_node() as Control
	_play_out()
	var results: Control = session.get_node("ModalLayer/ModalHost/Results")
	# The ending sequence waits for the camera; the line is what matters here.
	await wait_until(func() -> bool: return results.visible, 5.0)
	var line: Label = results.call(&"spectator_line") as Label
	assert_true(line.visible)
	assert_eq(line.text, tr("UI_SPECTATOR_RESULT_VERIFIED").format({
		"model": _entry.model, "score": Format.decimal(_entry.score, 1)}))
	assert_eq((results.call(&"again_button") as ConsoleButton).label_key,
		"UI_SPECTATOR_WATCH_AGAIN")


func _count_until(day: int) -> int:
	var count: int = 0
	for command: Command in _entry.commands:
		if command.day < day:
			count += 1
	return count
