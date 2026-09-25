extends GutTest
## S6.8 — the remappable keys (accessibility.md §5.2). The autoload rewrites the
## live input map and the settings file, so every test puts both back.

const SettingsScript: GDScript = preload("res://game/autoload/settings.gd")
const KeyBindingsScript: GDScript = preload("res://game/autoload/key_bindings.gd")

var _keys: Dictionary[String, int] = {}


func before_each() -> void:
	_keys = Settings.keys.duplicate()
	KeyBindings.reset()


func after_each() -> void:
	Settings.set_keys(_keys)
	KeyBindings.apply_all()


func test_the_defaults_are_the_project_s_keys() -> void:
	assert_eq(KeyBindings.key_of(&"game_pause"), KEY_SPACE)
	assert_eq(KeyBindings.key_of(&"game_tree"), KEY_T)
	assert_eq(KeyBindings.key_of(&"game_help"), KEY_F1)
	assert_eq(KeyBindings.key_of(&"game_zoom_in"), KEY_EQUAL)


func test_assign_to_a_free_key_moves_the_action() -> void:
	assert_eq(KeyBindings.assign(&"game_tree", KEY_Y), &"")
	assert_eq(KeyBindings.key_of(&"game_tree"), KEY_Y)
	assert_eq(Settings.keys, {"game_tree": int(KEY_Y)} as Dictionary[String, int])
	var press: InputEventKey = InputEventKey.new()
	press.physical_keycode = KEY_Y
	press.pressed = true
	assert_true(press.is_action_pressed(&"game_tree"), "the input map follows")


func test_assign_to_another_action_s_key_swaps_the_two() -> void:
	var other: StringName = KeyBindings.assign(&"game_tree", KEY_C)
	assert_eq(other, &"game_containment")
	assert_eq(KeyBindings.key_of(&"game_tree"), KEY_C)
	assert_eq(KeyBindings.key_of(&"game_containment"), KEY_T)


func test_a_reserved_key_is_refused() -> void:
	assert_false(KeyBindings.can_bind(KEY_ESCAPE))
	assert_eq(KeyBindings.assign(&"game_tree", KEY_TAB), &"")
	assert_eq(KeyBindings.key_of(&"game_tree"), KEY_T, "nothing changed")


func test_an_action_that_is_not_remappable_is_refused() -> void:
	assert_eq(KeyBindings.assign(&"game_menu", KEY_Y), &"")
	assert_eq(KeyBindings.key_of(&"game_menu"), KEY_NONE)


func test_the_fixed_keypad_alias_stays_on_the_zoom() -> void:
	KeyBindings.assign(&"game_zoom_in", KEY_Y)
	var keypad: InputEventKey = InputEventKey.new()
	keypad.physical_keycode = KEY_KP_ADD
	keypad.pressed = true
	assert_true(keypad.is_action_pressed(&"game_zoom_in"))
	assert_false(KeyBindings.can_bind(KEY_KP_ADD), "and cannot be given to anything else")


func test_an_override_equal_to_the_default_is_not_stored() -> void:
	KeyBindings.assign(&"game_tree", KEY_Y)
	KeyBindings.assign(&"game_tree", KEY_T)
	assert_eq(Settings.keys.size(), 0)


func test_reset_restores_every_default() -> void:
	KeyBindings.assign(&"game_tree", KEY_Y)
	KeyBindings.assign(&"game_pause", KEY_P)
	KeyBindings.reset()
	assert_eq(KeyBindings.key_of(&"game_tree"), KEY_T)
	assert_eq(KeyBindings.key_of(&"game_pause"), KEY_SPACE)
	assert_eq(Settings.keys.size(), 0)


func test_invalid_settings_entries_are_dropped_on_load() -> void:
	var values: Dictionary = SettingsScript.values_from({"keys": {
		"game_tree": 89.0,
		"game_menu": 89,
		"no_such_action": 89,
		"game_pause": "space",
		"game_help": float(KEY_ESCAPE),
		"game_abilities": 89.5,
	}}, SettingsScript.LOCALE_EN)
	assert_eq(values[SettingsScript.KEY_KEYS], {"game_tree": 89})


func test_a_debug_key_is_refused_in_a_debug_build_only() -> void:
	assert_false(KeyBindingsScript.is_bindable(KEY_L, true))
	assert_true(KeyBindingsScript.is_bindable(KEY_L, false))
