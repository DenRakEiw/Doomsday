extends GutTest
## S6.8 — the *Controls* modal (accessibility.md §5.3): a capture binds, `Escape`
## cancels a capture without closing, a reserved key and a swap each say so, and
## reset brings the defaults back. The live input map and the settings file are
## put back after each test.

const CONTROLS: PackedScene = preload("res://ui/modals/controls.tscn")

var _modal: Control = null
var _keys: Dictionary[String, int] = {}
var _closed: int = 0


func before_each() -> void:
	_keys = Settings.keys.duplicate()
	KeyBindings.reset()
	_modal = CONTROLS.instantiate() as Control
	add_child_autofree(_modal)
	_modal.call(&"open")
	_closed = 0
	_modal.connect(&"closed", func() -> void: _closed += 1)


func after_each() -> void:
	Settings.set_keys(_keys)
	KeyBindings.apply_all()


func _press(physical: Key) -> void:
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = physical
	key.keycode = physical
	key.pressed = true
	_modal.call(&"take_key", key)


func _button(action: StringName) -> ConsoleButton:
	return _modal.call(&"button_of", action) as ConsoleButton


func test_a_capture_binds_the_key() -> void:
	_button(&"game_tree").pressed.emit()
	assert_eq(_modal.get(&"capturing"), &"game_tree")
	_press(KEY_Y)
	assert_eq(KeyBindings.key_of(&"game_tree"), KEY_Y)
	assert_eq(_modal.get(&"capturing"), &"", "the capture is over")
	assert_eq(_button(&"game_tree").text, "Y")


func test_escape_cancels_the_capture_without_closing() -> void:
	_button(&"game_tree").pressed.emit()
	_modal.call(&"on_escape")
	assert_eq(_modal.get(&"capturing"), &"")
	assert_eq(_closed, 0)
	assert_eq(KeyBindings.key_of(&"game_tree"), KEY_T, "nothing changed")
	_modal.call(&"on_escape")
	assert_eq(_closed, 1, "the second Escape closes")


func test_a_reserved_key_says_so_and_keeps_waiting() -> void:
	_button(&"game_tree").pressed.emit()
	_press(KEY_TAB)
	assert_string_contains(str(_modal.call(&"status_text")), KeyNames.key_label(KEY_TAB))
	assert_eq(_modal.get(&"capturing"), &"game_tree")


func test_a_taken_key_swaps_and_says_so() -> void:
	var live: LiveRegion = _modal.call(&"live_region")
	live.force_active = true
	_button(&"game_tree").pressed.emit()
	_press(KEY_C)
	assert_eq(KeyBindings.key_of(&"game_containment"), KEY_T)
	var status: String = str(_modal.call(&"status_text"))
	assert_false(status.is_empty())
	assert_eq(live.text, status, "and the swap is spoken")


func test_reset_restores_the_defaults() -> void:
	_button(&"game_tree").pressed.emit()
	_press(KEY_Y)
	_modal.call(&"_on_reset_pressed")
	assert_eq(KeyBindings.key_of(&"game_tree"), KEY_T)
	assert_eq(_button(&"game_tree").text, "T")


func test_each_row_is_named_by_its_action_and_its_key() -> void:
	var button: ConsoleButton = _button(&"game_tree")
	assert_string_contains(button.accessibility_name, "T")
	assert_string_contains(button.accessibility_name, tr("UI_CONTROLS_TREE"))
