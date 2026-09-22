class_name ConsoleButton
extends Button
## The interface's button (spec ui-foundation.md §4.2).
##
## Everything visual is in the theme; this script owns only what a theme cannot
## hold: the string key, the uppercasing of §3.2, the accessible name, and the
## minimum height that makes it tappable. The button grows with its label — a
## German word is longer and is never clipped.

const VARIATION: StringName = &"ConsoleButton"
const VARIATION_PRIMARY: StringName = &"ConsoleButtonPrimary"
## §5.7: the same button with tighter padding, for a row that has to hold three
## German labels in 400 px.
const SUFFIX_COMPACT: String = "Compact"

## The `data/loc/strings.csv` key of the label.
@export var label_key: String = "":
	set(value):
		label_key = value
		_refresh_strings()

## The key of the tooltip, if the button has one.
@export var tooltip_key: String = "":
	set(value):
		tooltip_key = value
		_refresh_strings()

## The lit variation of §4.2, for the one action a panel wants the player to take.
@export var primary: bool = false:
	set(value):
		primary = value
		_apply_variation()

## The tighter padding of §5.7's compact bar. Everything else is unchanged — a
## narrow screen gets the same button, not a different one.
@export var compact: bool = false:
	set(value):
		compact = value
		_apply_variation()


func _ready() -> void:
	_apply_variation()
	custom_minimum_size.y = maxf(custom_minimum_size.y, float(UiTokens.HIT_MIN))
	clip_text = false
	_refresh_strings()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_strings()


func _apply_variation() -> void:
	var base: StringName = VARIATION_PRIMARY if primary else VARIATION
	theme_type_variation = StringName(base + SUFFIX_COMPACT) if compact else base


## The label is uppercased, the accessible name is not: a screen reader should
## hear the word, not the shouting.
func _refresh_strings() -> void:
	if not label_key.is_empty():
		var translated: String = tr(label_key)
		text = Format.caps(translated)
		accessibility_name = translated
	if not tooltip_key.is_empty():
		tooltip_text = tr(tooltip_key)
		if label_key.is_empty():
			accessibility_name = tooltip_text
