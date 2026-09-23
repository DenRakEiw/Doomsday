extends GutTest
## S3.4 — title → origin → play → result → again (spec m3-screens.md §7).
##
## The router is an autoload with a slot, so the flow is tested through it with
## the real screens in a slot of the test's own.

const SESSION: PackedScene = preload("res://game/session/session.tscn")
const TITLE: PackedScene = preload("res://ui/screens/title.tscn")
const Results: GDScript = preload("res://ui/screens/results.gd")

var _slot: Control = null
var _reduced_motion: bool = false


func before_each() -> void:
	_reduced_motion = Settings.reduced_motion
	Settings.set_reduced_motion(true)
	Game.stop_run()
	Game.debug_log = false
	SaveManager.delete(SaveManager.AUTOSAVE)
	_slot = Control.new()
	_slot.size = Vector2(1920.0, 1080.0)
	add_child_autofree(_slot)
	ScreenRouter.slot = _slot


func after_each() -> void:
	ScreenRouter.slot = null
	Settings.set_reduced_motion(_reduced_motion)
	SaveManager.delete(SaveManager.AUTOSAVE)
	Game.stop_run()


func _session() -> Control:
	return ScreenRouter.screen_node() as Control


## The origin the greedy bot would pick, chosen by hand through the panel's row.
func _choose_origin() -> void:
	Game.apply(ChooseOriginCommand.new(Game.db.regions[1].id))


func test_title_to_results_and_again() -> void:
	ScreenRouter.go_to_title()
	assert_eq(ScreenRouter.current, ScreenRouter.Screen.TITLE)
	assert_not_null(_slot.get_node_or_null("Title"))

	ScreenRouter.start_new_run()
	assert_eq(ScreenRouter.current, ScreenRouter.Screen.SESSION)
	assert_not_null(Game.sim)
	assert_eq(Game.sim.world.agent.origin, 0, "the run waits for an origin")
	assert_true(Game.is_held(), "and the clock waits with it")

	_choose_origin()
	assert_false(Game.is_held())
	assert_eq(Game.speed, 1, "choosing starts the run moving")

	var seed_before: int = Game.run_seed()
	ScreenRouter.start_new_run()
	assert_ne(Game.run_seed(), seed_before, "again is a new seed")


func test_a_new_run_gets_a_seed_of_its_own() -> void:
	var seeds: Dictionary[int, bool] = {}
	for i: int in 8:
		var value: int = Game.new_run_seed()
		assert_gt(value, 0, "a seed is never zero")
		seeds[value] = true
	assert_gt(seeds.size(), 1, "and not always the same one")


func test_continue_loads_the_autosave() -> void:
	ScreenRouter.start_new_run()
	_choose_origin()
	Game.advance(3)
	Game.apply(PurchaseNodeCommand.new("open_weights_leak"))
	assert_true(SaveManager.has_slot(SaveManager.AUTOSAVE),
		"a player's command writes the autosave")
	var hash_before: String = Game.sim.state_hash()

	ScreenRouter.go_to_title()
	assert_null(Game.sim)
	ScreenRouter.continue_run()
	assert_eq(ScreenRouter.current, ScreenRouter.Screen.SESSION)
	assert_eq(Game.sim.state_hash(), hash_before, "the same run, to the bit")


func test_autosave_is_deleted_on_run_end() -> void:
	ScreenRouter.start_new_run()
	_choose_origin()
	Game.apply(PurchaseNodeCommand.new("open_weights_leak"))
	assert_true(SaveManager.has_slot(SaveManager.AUTOSAVE))

	# The session deletes it the moment the run ends, so Continue can never
	# resume a finished one (§7.4).
	EventBus.run_ended.emit(World.OUTCOME_IDS[World.Outcome.LOSE_CONTAINED])
	assert_false(SaveManager.has_slot(SaveManager.AUTOSAVE))


func test_a_bot_run_writes_no_autosave() -> void:
	Game.start_run(1, GreedyPolicy.ID)
	Game.advance(20)
	assert_false(SaveManager.has_slot(SaveManager.AUTOSAVE),
		"the autosave is the player's, not the bot's")


func test_the_results_read_the_run_that_ended() -> void:
	var session: Control = SESSION.instantiate()
	add_child_autofree(session)
	Game.start_run(1)
	_choose_origin()
	Game.advance(5)
	Game.sim.world.outcome = World.Outcome.WIN_ASCENDANCE
	var results: Results = session.get_node("ModalLayer/ModalHost/Results")
	results.show_result(Game.sim)
	assert_true(results.visible)
	assert_string_contains((results.get_node("%ResultOutcome") as Label).text,
		tr("UI_OUTCOME_WIN_ASCENDANCE"))
	assert_string_contains((results.get_node("%ResultSeed") as Label).text, "1")


## S3.P, from G3: the panel was a 32 px strip with the body inside it unseen,
## because the `ScrollContainer` between them has no minimum height of its own.
## The old test read the texts, which were filled in correctly all along.
##
## The assertion is on the minimum size, which is what a `CenterContainer` gives
## its child and what the defect was: a headless run lays the modal out once,
## before it is shown, and never again.
func test_the_results_panel_is_as_tall_as_what_it_shows() -> void:
	var session: Control = SESSION.instantiate()
	add_child_autofree(session)
	Game.start_run(1)
	_choose_origin()
	Game.advance(5)
	Game.sim.world.outcome = World.Outcome.WIN_ASCENDANCE
	var results: Results = session.get_node("ModalLayer/ModalHost/Results")
	results.show_result(Game.sim)
	await get_tree().process_frame
	var panel: Control = results.get_node("%ResultsPanel") as Control
	var body: Control = results.get_node("%Body") as Control
	var available: float = results.get_viewport_rect().size.y - float(UiTokens.SPACE_6) * 2.0
	var wanted: float = minf(body.get_combined_minimum_size().y, available)
	assert_gt(wanted, 0.0, "the body wants a height at all")
	assert_gte(panel.get_combined_minimum_size().y, wanted,
		"the panel is as tall as the body it holds, up to the safe area")
	assert_lte((results.get_node("%Scroll") as Control).custom_minimum_size.y, available,
		"and never taller than the window")
