extends GutTest
## S3.4 — the pause menu (spec m3-screens.md §7.3): the hold it takes, the three
## slots, and the settings the title screen shows too.

const SESSION: PackedScene = preload("res://game/session/session.tscn")
const PauseMenu: GDScript = preload("res://ui/modals/pause_menu.gd")
const SEED: int = 1

var _session: Control = null
var _menu: PauseMenu = null
var _modals: ModalHost = null
var _reduced_motion: bool = false


func before_each() -> void:
	_reduced_motion = Settings.reduced_motion
	Settings.set_reduced_motion(true)
	Game.stop_run()
	Game.debug_log = false
	for slot: String in PauseMenu.SLOTS:
		SaveManager.delete(slot)
	_session = SESSION.instantiate()
	add_child_autofree(_session)
	_menu = _session.get_node("ModalLayer/ModalHost/PauseMenu")
	_modals = _session.get_node("ModalLayer/ModalHost")


func after_each() -> void:
	for slot: String in PauseMenu.SLOTS:
		SaveManager.delete(slot)
	Settings.set_reduced_motion(_reduced_motion)
	Game.stop_run()


func _start() -> void:
	Game.start_run(SEED)
	Game.apply(ChooseOriginCommand.new(Game.db.regions[1].id))


func _press_escape() -> void:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	_session.call("_input", key)


func _slot_button(row: String, index: int) -> ConsoleButton:
	var container: Container = _menu.get_node("%" + row) as Container
	return (container.get_child(index) as Container).get_child(0) as ConsoleButton


func test_escape_opens_and_resume_closes_the_menu() -> void:
	_start()
	Game.set_speed(2)
	_press_escape()
	assert_true(_modals.is_open(), "with nothing else open, Escape is the menu")
	assert_eq(Game.speed, 0, "and the menu holds the clock")

	(_menu.get_node("%ResumeButton") as ConsoleButton).emit_signal("pressed")
	assert_false(_modals.is_open())
	assert_eq(Game.speed, 2)


func test_save_and_load_slots_round_trip() -> void:
	_start()
	Game.advance(4)
	_menu.open_menu()
	_slot_button("SaveRow", 1).emit_signal("pressed")
	assert_true(SaveManager.has_slot(PauseMenu.SLOTS[1]))
	assert_eq(SaveManager.peek_day(PauseMenu.SLOTS[1]), Game.sim.world.day)
	var hash_before: String = Game.sim.state_hash()

	Game.advance(6)
	assert_ne(Game.sim.state_hash(), hash_before)
	assert_eq(SaveManager.load(PauseMenu.SLOTS[1]), "")
	assert_eq(Game.sim.state_hash(), hash_before, "the earlier run, to the bit")


func test_an_empty_slot_cannot_be_loaded() -> void:
	_start()
	_menu.open_menu()
	assert_true(_slot_button("LoadRow", 2).disabled)
	_slot_button("SaveRow", 2).emit_signal("pressed")
	assert_false(_slot_button("LoadRow", 2).disabled, "and can once it is written")


func test_the_settings_rows_change_the_settings() -> void:
	_start()
	_menu.open_menu()
	var rows: VBoxContainer = _menu.get_node("%SettingsRows") as VBoxContainer
	var motion_button: ConsoleButton = (rows.get_child(1) as Container).get_child(1) \
		as ConsoleButton
	var before: bool = Settings.reduced_motion
	motion_button.emit_signal("pressed")
	assert_ne(Settings.reduced_motion, before)
	motion_button.emit_signal("pressed")
	assert_eq(Settings.reduced_motion, before)


## §7.3: the title opens the same scene with the run's half hidden.
func test_settings_only_hides_the_run_s_half() -> void:
	_menu.open_settings_only()
	assert_false((_menu.get_node("%ResumeButton") as Control).visible)
	assert_false((_menu.get_node("%SaveBlock") as Control).visible)
	assert_false((_menu.get_node("%QuitButton") as Control).visible)
	assert_true((_menu.get_node("%SettingsRows") as Control).visible)
	assert_eq((_menu.get_node("%PauseTitle") as Label).text, tr("UI_SETTINGS_TITLE"))
	# S4.P: the section caption under that title said *Einstellungen* again.
	assert_false((_menu.get_node("%SettingsTitle") as Control).visible)


## S4.9: a `ScrollContainer` has no height of its own, and the settings opened
## from the title were an empty strip until the scroll was fitted to the body.
func test_the_menu_is_as_tall_as_what_it_shows() -> void:
	_menu.open_settings_only()
	var scroll: ScrollContainer = _menu.get_node("%Scroll") as ScrollContainer
	var body: Control = _menu.get_node("%Body") as Control
	assert_gt(scroll.custom_minimum_size.y, 0.0)
	assert_almost_eq(scroll.custom_minimum_size.y,
		minf(body.get_combined_minimum_size().y,
			_menu.get_viewport_rect().size.y - float(UiTokens.SPACE_6) * 2.0), 1.0)
