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
