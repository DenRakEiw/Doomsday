extends GutTest
## S2.P — the keys that steer a run (spec ui-foundation.md §5.2, §5.6).
##
## They belong to the session and are taken in `_input`, ahead of the GUI: a
## focused `Button` turns `Space` into `ui_accept` and eats it, so at G2 the
## pause key was dead after any click on the HUD. The test therefore focuses a
## button first — without that it would pass against the old code too.

const SESSION: PackedScene = preload("res://game/session/session.tscn")

const SEED: int = 1

var _session: Control = null
var _reduced_motion: bool = false


func before_each() -> void:
	_reduced_motion = Settings.reduced_motion
	Settings.reduced_motion = true
	Game.stop_run()
	Game.debug_log = false
	_session = SESSION.instantiate()
	add_child_autofree(_session)


func after_each() -> void:
	Settings.reduced_motion = _reduced_motion
	Game.stop_run()


func after_all() -> void:
	Game.stop_run()


func _start() -> void:
	Game.start_run(SEED, GreedyPolicy.ID)
	Game.set_speed(0)


## The speed buttons are unique inside the top bar, which is unique inside the
## HUD: a `%` name reaches only as far as the scene that declares it.
func _speed_group() -> HBoxContainer:
	var hud: Node = _session.get_node("%Hud")
	return hud.get_node("%TopBar").get_node("%SpeedGroup") as HBoxContainer


## The state G2 found the bug in: something on the HUD has the focus.
func _focus_a_speed_button() -> void:
	(_speed_group().get_child(0) as Button).grab_focus()


func _press(keycode: Key) -> void:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = keycode
	key.pressed = true
	_session.call("_input", key)


func test_space_pauses_the_run_even_with_a_button_focused() -> void:
	_start()
	Game.set_speed(2)
	_focus_a_speed_button()

	_press(KEY_SPACE)

	assert_eq(Game.speed, 0)


func test_space_returns_to_the_speed_that_was_running() -> void:
	_start()
	Game.set_speed(4)
	_press(KEY_SPACE)

	_press(KEY_SPACE)

	assert_eq(Game.speed, 4, "the last speed, not 1×")


func test_the_number_keys_set_the_three_running_speeds() -> void:
	_start()
	_focus_a_speed_button()
	for pair: Array in [[KEY_1, 1], [KEY_2, 2], [KEY_3, 4]]:
		_press(pair[0] as Key)
		assert_eq(Game.speed, int(pair[1]))


func test_exactly_one_speed_button_is_pressed_at_a_time() -> void:
	_start()
	var group: HBoxContainer = _speed_group()
	for speed: int in [1, 4, 0, 2]:
		Game.set_speed(speed)
		var pressed: int = 0
		for child: Node in group.get_children():
			if (child as Button).button_pressed:
				pressed += 1
		assert_eq(pressed, 1, "at speed %d" % speed)


func test_escape_closes_the_region_panel_for_everyone() -> void:
	_start()
	var panel: SlidePanel = _session.get_node("%RegionPanel") as SlidePanel
	EventBus.region_selected.emit(Game.db.region_index_by_id["usa"])
	assert_true(panel.is_open, "the panel is open to begin with")
	watch_signals(EventBus)

	_press(KEY_ESCAPE)

	# The map draws the outline, so closing has to reach it too (§7.4).
	assert_signal_emitted_with_parameters(EventBus, "region_selected", [0])
	assert_false(panel.is_open)


func test_escape_closes_the_menu_sheet() -> void:
	# S4.P: only the sheet's own close button closed it.
	_start()
	var sheet: SlidePanel = _session.get_node("%MenuSheet") as SlidePanel
	sheet.open()
	assert_true(sheet.is_open, "the sheet is open to begin with")

	_press(KEY_ESCAPE)

	assert_false(sheet.is_open)


func test_escape_with_nothing_open_is_left_to_whatever_else_wants_it() -> void:
	_start()
	watch_signals(EventBus)

	_press(KEY_ESCAPE)

	assert_signal_not_emitted(EventBus, "region_selected")


## S4.2 — `A` opens the ability picker and `A` closes it again (§16.10). The
## picker holds no clock: the run keeps going while it is up.
func test_a_opens_and_closes_the_ability_picker() -> void:
	_start()
	Game.set_speed(1)
	var picker: Control = _session.get_node("%AbilityPicker") as Control
	assert_false(picker.visible)

	_press(KEY_A)
	assert_true(picker.visible)
	assert_eq(Game.speed, 1, "the picker holds no clock")

	_press(KEY_A)
	assert_false(picker.visible)


func test_a_without_a_run_opens_nothing() -> void:
	var picker: Control = _session.get_node("%AbilityPicker") as Control
	_press(KEY_A)
	assert_false(picker.visible)


# ------------------------------------------------ S6.7: F1 (first-run.md §6.7)


func _codex() -> Control:
	return _session.get(&"_codex") as Control


func _modals() -> ModalHost:
	return _session.get_node("%ModalHost") as ModalHost


func _help_buttons(root: Node) -> Array[HelpButton]:
	var out: Array[HelpButton] = []
	for node: Node in root.find_children("*", "", true, false):
		if node is HelpButton:
			out.append(node as HelpButton)
	return out


func _help_page() -> String:
	return str(_codex().get(&"entry_id"))


func test_f1_opens_the_session_page_and_holds_the_clock() -> void:
	_start()
	Game.set_speed(1)
	_press(KEY_F1)
	assert_eq(_modals().current(), _codex())
	assert_eq(_help_page(), HelpPages.page_for_context(HelpPages.CONTEXT_SESSION))
	assert_eq(Game.speed, 0, "help holds the clock")
	_press(KEY_F1)
	assert_false(_modals().is_open(), "F1 again closes it")
	assert_eq(Game.speed, 1, "and the clock is as it was")


func test_f1_over_the_tech_tree_opens_its_page_and_returns_to_it() -> void:
	_start()
	_session.call(&"_toggle_tech_tree")
	var tree: Control = _session.get(&"_tech_tree") as Control
	_press(KEY_F1)
	assert_eq(_help_page(), HelpPages.page_for_context(HelpPages.CONTEXT_TREE))
	assert_eq(_modals().below(), tree)
	_press(KEY_T)
	assert_eq(_modals().current(), _codex(), "T does not close the tree under the page")
	_press(KEY_F1)
	assert_eq(_modals().current(), tree, "closing returns to the tree")


func test_f1_over_the_ability_picker_opens_its_page() -> void:
	_start()
	_press(KEY_A)
	_press(KEY_F1)
	assert_eq(_help_page(), HelpPages.page_for_context(HelpPages.CONTEXT_ABILITIES))


func test_f1_on_the_containment_panel_opens_its_page() -> void:
	_start()
	_press(KEY_C)
	_press(KEY_F1)
	assert_eq(_help_page(), HelpPages.page_for_context(HelpPages.CONTEXT_CONTAINMENT))


func test_f1_on_the_analysis_panel_opens_its_page() -> void:
	_start()
	_press(KEY_G)
	_press(KEY_F1)
	assert_eq(_help_page(), HelpPages.page_for_context(HelpPages.CONTEXT_ANALYSIS))


func test_f1_on_the_region_panel_opens_its_page() -> void:
	_start()
	EventBus.region_selected.emit(Game.db.region_index_by_id["usa"])
	_press(KEY_F1)
	assert_eq(_help_page(), HelpPages.page_for_context(HelpPages.CONTEXT_REGION))


func test_the_question_mark_in_a_panel_header_opens_its_page() -> void:
	_start()
	_session.call(&"_toggle_tech_tree")
	var tree: Control = _session.get(&"_tech_tree") as Control
	var buttons: Array[HelpButton] = _help_buttons(tree)
	assert_eq(buttons.size(), 1, "one ? in the tree's header")
	buttons[0].emit_signal("pressed")
	assert_eq(_modals().current(), _codex())
	assert_eq(_help_page(), HelpPages.page_for_context(HelpPages.CONTEXT_TREE))


func test_the_four_dense_panels_each_have_one_question_mark() -> void:
	for path: String in ["%TechTree", "%ContainmentPanel", "%AnalysisPanel", "%RegionPanel"]:
		var panel: Node = _session.get_node(path)
		assert_eq(_help_buttons(panel).size(), 1, path)
