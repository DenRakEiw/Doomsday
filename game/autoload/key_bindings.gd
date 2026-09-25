extends Node
## The keyboard's remappable keys (spec accessibility.md §5.2).
##
## The defaults are the first key event of each action in `project.godot`'s
## `[input]` section — one source, read back from `ProjectSettings` — and
## `Settings.keys` holds only the player's overrides. Only an action's first key
## changes: the fixed keypad aliases and the controller's events stay.
##
## An autoload (registered after `Settings`), so no `class_name`.

## §5.1's remappable actions, in the order the *Controls* modal lists them.
const REMAPPABLE: Array[StringName] = [&"game_pause", &"game_speed_1", &"game_speed_2",
	&"game_speed_3", &"game_tree", &"game_containment", &"game_analysis", &"game_abilities",
	&"game_help", &"game_zoom_in", &"game_zoom_out", &"game_focus_region"]
## Keys that keep their meaning whatever the player does.
const RESERVED: Array[Key] = [KEY_ESCAPE, KEY_TAB, KEY_ENTER, KEY_KP_ENTER, KEY_UP, KEY_DOWN,
	KEY_LEFT, KEY_RIGHT, KEY_PAGEUP, KEY_PAGEDOWN, KEY_HOME, KEY_END, KEY_SHIFT, KEY_CTRL,
	KEY_ALT, KEY_META, KEY_CAPSLOCK, KEY_F12]
## The fixed second keys of the zoom actions: bound to anything else they would
## fire two actions at once.
const FIXED_ALIASES: Array[Key] = [KEY_KP_ADD, KEY_KP_SUBTRACT]
## The development keys of ui-foundation.md §10.2, refused in debug builds only
## (D6.8 takes them out of release builds).
const DEBUG_KEYS: Array[Key] = [KEY_F5, KEY_F6, KEY_F7, KEY_F8, KEY_F9, KEY_F10, KEY_F11,
	KEY_L, KEY_K, KEY_M, KEY_V]
const INPUT_PREFIX: String = "input/"
const FIELD_EVENTS: String = "events"


func _ready() -> void:
	apply_all()


## At start: the defaults, then the player's overrides.
func apply_all() -> void:
	for action: StringName in REMAPPABLE:
		var key: Key = default_key(action)
		var stored: Variant = Settings.keys.get(String(action))
		if stored != null:
			key = int(stored) as Key
		_set_first_key(action, key)


## The action's remappable (first) key, as a physical keycode; `KEY_NONE` when it
## has none.
func key_of(action: StringName) -> Key:
	return KeyNames.first_key(action)


## Not reserved, not a fixed alias, and in debug builds not a debug key.
func can_bind(physical: Key) -> bool:
	return is_bindable(physical, OS.is_debug_build())


## Binds `physical` to `action`. Returns the action that had it (now given
## `action`'s old key), or &"" when none had it. Writes the setting. Refuses
## (returns &"" and changes nothing) when `can_bind` is false or `action` is not
## remappable.
func assign(action: StringName, physical: Key) -> StringName:
	if not REMAPPABLE.has(action) or not can_bind(physical):
		return &""
	var old: Key = key_of(action)
	if old == physical:
		return &""
	var other: StringName = action_with(physical)
	_set_first_key(action, physical)
	if other != &"":
		_set_first_key(other, old)
	_store()
	_announce_change()
	return other


## Overrides cleared, defaults applied, written.
func reset() -> void:
	Settings.set_keys({})
	apply_all()
	_announce_change()


## The remappable action whose first key is `physical`, or &"".
func action_with(physical: Key) -> StringName:
	for action: StringName in REMAPPABLE:
		if key_of(action) == physical:
			return action
	return &""


## The key `project.godot` gives `action` first; `KEY_NONE` when it gives none.
static func default_key(action: StringName) -> Key:
	var setting: Variant = ProjectSettings.get_setting(INPUT_PREFIX + String(action))
	if typeof(setting) != TYPE_DICTIONARY:
		return KEY_NONE
	var events: Variant = (setting as Dictionary).get(FIELD_EVENTS)
	if typeof(events) != TYPE_ARRAY:
		return KEY_NONE
	for event: Variant in events as Array:
		var key: InputEventKey = event as InputEventKey
		if key != null:
			return key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	return KEY_NONE


## `can_bind` without the node: what a settings file may hold (§5.2 drops the
## rest on load).
static func is_bindable(physical: Key, debug_build: bool) -> bool:
	if physical == KEY_NONE or RESERVED.has(physical) or FIXED_ALIASES.has(physical):
		return false
	return not (debug_build and DEBUG_KEYS.has(physical))


## Whether a stored override is one this build can apply.
static func is_valid_override(action: String, key: Variant) -> bool:
	var kind: int = typeof(key)
	if kind != TYPE_INT and kind != TYPE_FLOAT:
		return false
	var code: float = float(key)
	if code != floorf(code) or not REMAPPABLE.has(StringName(action)):
		return false
	return is_bindable(int(code) as Key, OS.is_debug_build())


## Only the overrides are stored: a key equal to its default is not.
func _store() -> void:
	var overrides: Dictionary[String, int] = {}
	for action: StringName in REMAPPABLE:
		var key: Key = key_of(action)
		if key != default_key(action):
			overrides[String(action)] = int(key)
	Settings.set_keys(overrides)


func _set_first_key(action: StringName, physical: Key) -> void:
	if not InputMap.has_action(action):
		return
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	var replacement: InputEventKey = InputEventKey.new()
	replacement.physical_keycode = physical
	InputMap.action_erase_events(action)
	var placed: bool = false
	for event: InputEvent in events:
		if not placed and event is InputEventKey:
			InputMap.action_add_event(action, replacement)
			placed = true
			continue
		InputMap.action_add_event(action, event)
	if not placed and physical != KEY_NONE:
		# An action whose default has no key gets one in front of its other events.
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, replacement)
		for event: InputEvent in events:
			InputMap.action_add_event(action, event)


## Every text that names a key is formatted when its strings are refreshed
## (§5.3), which is what a language change triggers — so a new key does too.
func _announce_change() -> void:
	if is_inside_tree():
		get_tree().root.propagate_notification(NOTIFICATION_TRANSLATION_CHANGED)
