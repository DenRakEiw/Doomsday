extends GutTest
## S3.4 — the pause menu (spec m3-screens.md §7.3): the hold it takes, the three
## slots, and the settings the title screen shows too.

const SESSION: PackedScene = preload("res://game/session/session.tscn")
const PauseMenu: GDScript = preload("res://ui/modals/pause_menu.gd")
const SEED: int = 1
## The audio clock for the silent-hold tests (ms), far enough apart that no
## cooldown of the sheet counts.
const AUDIO_CLOCK_START_MS: int = 1000000
const AUDIO_CLOCK_STEP_MS: int = 10000

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


## S5.7 (screens-full.md §6.3): the boot row and *Reset progress* are the
## title's, never the pause menu's.
func test_the_title_rows_show_on_the_title_only() -> void:
	_start()
	_menu.open_menu()
	var reset: ConsoleButton = _reset_button()
	assert_false(reset.visible, "no reset in the middle of a run")
	_menu.open_settings_only()
	assert_true(reset.visible)
	assert_eq(reset.theme_type_variation, ConsoleButton.VARIATION_ALERT)


func test_the_boot_row_toggles_the_setting() -> void:
	var before: bool = Settings.boot_always
	_menu.open_settings_only()
	var rows: VBoxContainer = _menu.get_node("%SettingsRows") as VBoxContainer
	var boot: ConsoleButton = (rows.get_child(PauseMenu.INDEX_BOOT) as Container).get_child(1) 		as ConsoleButton
	boot.emit_signal("pressed")
	assert_ne(Settings.boot_always, before)
	assert_eq(boot.text, Format.caps(tr("UI_SETTINGS_BOOT_ALWAYS" if Settings.boot_always \
			else "UI_SETTINGS_BOOT_FIRST")))
	Settings.set_boot_always(before)


func _reset_button() -> ConsoleButton:
	var rows: VBoxContainer = _menu.get_node("%SettingsRows") as VBoxContainer
	return rows.get_child(rows.get_child_count() - 1) as ConsoleButton


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


## S6.7 (first-run.md §6.7): *How to play* opens over the menu, holds the clock
## with it, and closing it comes back to the menu.
func test_the_help_row_opens_the_codex_over_the_menu_and_returns_to_it() -> void:
	_start()
	Game.set_speed(2)
	_press_escape()
	(_menu.get_node("%HelpButton") as ConsoleButton).emit_signal("pressed")
	var codex: Control = _session.get(&"_codex") as Control
	assert_eq(_modals.current(), codex)
	assert_eq(_modals.below(), _menu)
	assert_eq(str(codex.get(&"entry_id")), HelpPages.page_for_context(HelpPages.CONTEXT_SESSION))
	codex.emit_signal("closed")
	assert_eq(_modals.current(), _menu, "back to the menu")
	assert_eq(Game.speed, 0, "the menu still holds the clock")
	(_menu.get_node("%ResumeButton") as ConsoleButton).emit_signal("pressed")
	assert_eq(Game.speed, 2)


func test_the_help_row_is_not_on_the_title() -> void:
	_menu.open_settings_only()
	assert_false((_menu.get_node("%HelpButton") as Control).visible)


func test_the_hints_row_toggles_the_setting() -> void:
	var before: bool = Settings.hints
	_menu.open_settings_only()
	var rows: VBoxContainer = _menu.get_node("%SettingsRows") as VBoxContainer
	var row: Container = rows.get_child(PauseMenu.INDEX_HINTS) as Container
	assert_eq((row.get_child(0) as Label).text, tr("UI_SETTINGS_HINTS"),
		"directly after the introduction's row")
	var button: ConsoleButton = row.get_child(1) as ConsoleButton
	button.emit_signal("pressed")
	assert_ne(Settings.hints, before)
	Settings.set_hints(before)


## D6.8: the ear for the two tests below — the clock injected so no cooldown of
## the sheet counts between two sounds.
func _listen() -> void:
	Audio.set_unlocked(true)
	Audio.clock_override_ms = AUDIO_CLOCK_START_MS
	Audio.reset_ledger()
	Audio.reset_history()


func _later() -> void:
	Audio.clock_override_ms += AUDIO_CLOCK_STEP_MS
	Audio.reset_ledger()


func _stop_listening() -> void:
	Audio.clock_override_ms = -1
	Audio.reset_ledger()
	Audio.reset_history()


func test_the_menu_s_hold_is_silent() -> void:
	_start()
	Game.set_speed(2)
	_listen()
	_press_escape()
	assert_eq(Game.speed, 0, "the menu holds the clock")
	_later()
	_menu.on_escape()
	assert_eq(Game.speed, 2, "and gives it back")
	assert_eq(Audio.history, [&"ui_open", &"ui_close"] as Array[StringName],
		"a hold plays neither the pause nor the speed cue")
	_stop_listening()


func test_space_still_sounds_the_pause() -> void:
	_start()
	Game.set_speed(2)
	_listen()
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_SPACE
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	_session.call("_input", key)
	assert_eq(Game.speed, 0)
	assert_eq(Audio.history, [&"ui_pause"] as Array[StringName])
	_stop_listening()


func test_is_hold_change_is_true_only_inside_a_hold_s_speed_change() -> void:
	_start()
	Game.set_speed(1)
	var heard: Array[bool] = []
	var listener: Callable = func(_speed: int) -> void: heard.append(Game.is_hold_change())
	EventBus.speed_changed.connect(listener)
	Game.hold(&"test")
	Game.release(&"test")
	Game.set_speed(2)
	EventBus.speed_changed.disconnect(listener)
	assert_eq(heard, [true, true, false] as Array[bool])
	assert_false(Game.is_hold_change(), "false outside the signal")


## S7.3 (web.md §7.4): the progress rows are the browser's, on the title only.
func test_the_progress_rows_show_in_the_browser_s_title_settings() -> void:
	PauseMenu.set(&"force_progress_rows", true)
	_menu.open_settings_only()
	var rows: Array[Control] = _menu.progress_rows()
	PauseMenu.set(&"force_progress_rows", false)
	assert_eq(rows.size(), 4, "two buttons, the note, the status")
	for row: Control in rows:
		assert_true(row.visible, row.name)
	assert_eq((rows[0] as ConsoleButton).label_key, "UI_SETTINGS_PROGRESS_EXPORT")
	assert_eq((rows[1] as ConsoleButton).label_key, "UI_SETTINGS_PROGRESS_IMPORT")
	assert_eq((rows[2] as Label).text, tr("UI_SETTINGS_PROGRESS_NOTE"))
	assert_eq(_menu.progress_status().text, "", "no result yet")


func test_the_progress_rows_are_not_in_a_run_s_menu() -> void:
	PauseMenu.set(&"force_progress_rows", true)
	_start()
	_menu.open_menu()
	PauseMenu.set(&"force_progress_rows", false)
	for row: Control in _menu.progress_rows():
		assert_false(row.visible, row.name)


func test_the_progress_rows_are_not_on_the_desktop() -> void:
	_menu.open_settings_only()
	for row: Control in _menu.progress_rows():
		assert_false(row.visible, row.name)


func test_a_file_that_is_no_profile_says_so() -> void:
	_menu.open_settings_only()
	_menu.on_progress_file_picked("{\"hello\": 1}", "")
	assert_eq(_menu.progress_status().text, tr("UI_SETTINGS_PROGRESS_NOT_A_PROFILE"))


func test_a_newer_file_says_so() -> void:
	_menu.open_settings_only()
	_menu.on_progress_file_picked(JSON.stringify({"version": ProfileManager.VERSION + 1,
		"runs_completed": 1}), "")
	assert_eq(_menu.progress_status().text, tr("UI_SETTINGS_PROGRESS_NEWER"))


func test_a_file_too_large_is_no_profile_and_a_cancel_says_nothing() -> void:
	_menu.open_settings_only()
	_menu.on_progress_file_picked("", WebBridge.REASON_CANCELLED)
	assert_eq(_menu.progress_status().text, "")
	_menu.on_progress_file_picked("", WebBridge.REASON_TOO_LARGE)
	assert_eq(_menu.progress_status().text, tr("UI_SETTINGS_PROGRESS_NOT_A_PROFILE"))


func test_a_confirmed_progress_file_replaces_the_profile() -> void:
	var saved: String = FileAccess.get_file_as_string(ProfileManager.path)
	var doctored: Dictionary = ProfileManager.to_dict()
	doctored["runs_completed"] = ProfileManager.runs_completed + 1
	var expected: int = ProfileManager.runs_completed + 1
	_menu.open_settings_only()
	watch_signals(_menu)
	_menu.on_progress_file_picked(JSON.stringify(doctored), "")
	var confirm: ConfirmModal = _menu.get_node("%PauseConfirm")
	assert_true(confirm.visible, "asked first")
	confirm.on_escape()
	assert_eq(ProfileManager.runs_completed, expected - 1, "no — nothing changes")
	_menu.on_progress_file_picked(JSON.stringify(doctored), "")
	confirm.emit_signal("answered", true)
	assert_eq(ProfileManager.runs_completed, expected)
	assert_eq(_menu.progress_status().text, tr("UI_SETTINGS_PROGRESS_IMPORTED"))
	assert_signal_emitted(_menu, "progress_imported")
	var file: FileAccess = FileAccess.open(ProfileManager.path, FileAccess.WRITE)
	file.store_string(saved)
	file.close()
	ProfileManager.use_path(ProfileManager.path)


func test_a_file_that_is_no_json_says_so() -> void:
	_menu.open_settings_only()
	_menu.on_progress_file_picked("this is not json", "")
	assert_eq(_menu.progress_status().text, tr("UI_SETTINGS_PROGRESS_NOT_A_PROFILE"))
