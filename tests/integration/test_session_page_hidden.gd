extends GutTest
## S7.3 — the browser page hidden (web.md §6.3): the player's live run is
## saved and paused behind the menu; a watched run, a bot's, a run before its
## origin just go on.

const SESSION: PackedScene = preload("res://game/session/session.tscn")
const SEED: int = 1
## A short watched run, made on the real content (benchmark.md §12).
const SPECTATE_DAYS: int = 30
const SPECTATE_SEED: int = 1001

var _session: Control = null
var _modals: ModalHost = null
var _menu: Control = null
var _reduced_motion: bool = false


func before_each() -> void:
	_reduced_motion = Settings.reduced_motion
	Settings.set_reduced_motion(true)
	Game.stop_run()
	Game.debug_log = false
	SaveManager.delete(SaveManager.AUTOSAVE)
	_session = SESSION.instantiate()
	add_child_autofree(_session)
	_modals = _session.get_node("ModalLayer/ModalHost")
	_menu = _session.get_node("ModalLayer/ModalHost/PauseMenu")


func after_each() -> void:
	SaveManager.delete(SaveManager.AUTOSAVE)
	Settings.set_reduced_motion(_reduced_motion)
	Game.stop_run()


func _live_run() -> void:
	Game.start_run(SEED)
	Game.apply(ChooseOriginCommand.new(Game.db.regions[1].id))
	# The command's own autosave is not the one under test.
	SaveManager.delete(SaveManager.AUTOSAVE)
	Game.set_speed(2)


func test_a_live_run_is_saved_when_the_page_hides() -> void:
	_live_run()
	EventBus.page_hidden.emit()
	assert_true(SaveManager.has_slot(SaveManager.AUTOSAVE))


func test_a_live_run_is_paused_behind_the_menu() -> void:
	_live_run()
	EventBus.page_hidden.emit()
	assert_eq(_modals.current(), _menu)
	assert_eq(Game.speed, 0, "the menu holds the clock")


func test_the_page_shown_again_changes_nothing() -> void:
	_live_run()
	EventBus.page_hidden.emit()
	EventBus.page_shown.emit()
	assert_eq(_modals.current(), _menu, "the player resumes")


func test_an_open_modal_stays_on_top() -> void:
	_live_run()
	_session.call(&"_toggle_tech_tree")
	var open: Control = _modals.current()
	EventBus.page_hidden.emit()
	assert_eq(_modals.current(), open)
	assert_true(SaveManager.has_slot(SaveManager.AUTOSAVE), "saved all the same")


func test_a_run_before_its_origin_is_left_alone() -> void:
	Game.start_run(SEED)
	EventBus.page_hidden.emit()
	assert_false(_modals.is_open())
	assert_false(SaveManager.has_slot(SaveManager.AUTOSAVE))


func test_a_watched_run_goes_on() -> void:
	var config: BenchConfig = BenchConfig.load_file()
	config.max_days = SPECTATE_DAYS
	var entry: BenchEntry = Fixtures.bench_mock_entry(Game.content(), config, SPECTATE_SEED)
	assert_eq(Game.start_spectating(entry), "")
	Game.advance(1)
	EventBus.page_hidden.emit()
	assert_false(_modals.is_open())
	assert_false(SaveManager.has_slot(SaveManager.AUTOSAVE))
