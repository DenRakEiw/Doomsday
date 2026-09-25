class_name KeyNames
extends RefCounted
## An action's key as the player's keyboard labels it (spec accessibility.md
## §5.3), and the placeholders every text that names a remappable key is
## formatted with — so a remapped key is never shown under its old name.
##
## A few keys have a word rather than a legend and are translated; every other
## key is named by the keyboard layout's own label for the physical key, so the
## key where a US `Y` is reads `Z` on a German keyboard.
##
## Never instantiated; a namespace of static functions.

## Keys named in words, from the string table.
const WORDS: Dictionary[Key, String] = {
	KEY_SPACE: "UI_KEY_SPACE",
	KEY_ESCAPE: "UI_KEY_ESCAPE",
	KEY_ENTER: "UI_KEY_ENTER",
	KEY_TAB: "UI_KEY_TAB",
	KEY_BACKSPACE: "UI_KEY_BACKSPACE",
}
## §5.3: placeholder → action, one per remappable action.
const ARGS: Dictionary[String, StringName] = {
	"key_pause": &"game_pause",
	"key_speed_1": &"game_speed_1",
	"key_speed_2": &"game_speed_2",
	"key_speed_3": &"game_speed_3",
	"key_tree": &"game_tree",
	"key_containment": &"game_containment",
	"key_analysis": &"game_analysis",
	"key_abilities": &"game_abilities",
	"key_help": &"game_help",
	"key_zoom_in": &"game_zoom_in",
	"key_zoom_out": &"game_zoom_out",
	"key_focus_region": &"game_focus_region",
}
## Keycodes above the space and below `KEY_SPECIAL` are characters; ASCII ones
## (the letters) are shown upper case, the rest as the layout gives them.
const PRINTABLE_FIRST: int = 32
const ASCII_END: int = 128
## The headless display server has no keyboard layout to ask.
const HEADLESS: String = "headless"


## The action's first key, as the keyboard labels it; "" when it has none.
static func label(action: StringName) -> String:
	return key_label(first_key(action))


## A physical key, as the keyboard labels it.
static func key_label(physical: Key) -> String:
	if physical == KEY_NONE:
		return ""
	if WORDS.has(physical):
		return String(TranslationServer.translate(WORDS[physical]))
	var shown: Key = physical
	if DisplayServer.get_name() != HEADLESS:
		var mapped: Key = DisplayServer.keyboard_get_label_from_physical(physical)
		if mapped != KEY_NONE:
			shown = mapped
	# A printable key is named by its character — `=`, `ß`, `Ö` — not by the
	# engine's English word for it (`Equal`); letters as the keycap prints them.
	var code: int = int(shown)
	if code > PRINTABLE_FIRST and code < int(KEY_SPECIAL):
		return String.chr(code).to_upper() if code < ASCII_END else String.chr(code)
	return OS.get_keycode_string(shown)


## Every key placeholder of §5.3 with the key it stands for right now.
static func args() -> Dictionary:
	var out: Dictionary = {}
	for placeholder: String in ARGS:
		out[placeholder] = label(ARGS[placeholder])
	return out


## `text` with every key placeholder filled; a text without any is unchanged.
static func format(text: String) -> String:
	if not text.contains("{key_"):
		return text
	return text.format(args())


## The first key event of `action` in the input map, as a physical keycode.
static func first_key(action: StringName) -> Key:
	if not InputMap.has_action(action):
		return KEY_NONE
	for event: InputEvent in InputMap.action_get_events(action):
		var key: InputEventKey = event as InputEventKey
		if key != null:
			return key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	return KEY_NONE
