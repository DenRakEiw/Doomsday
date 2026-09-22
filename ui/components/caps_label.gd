class_name CapsLabel
extends Label
## A label in `TYPE_LABEL`, bound to a string key and uppercased (spec
## ui-foundation.md §3.2, §4.1, §4.4).
##
## Uppercase is a rendering rule, never a spelling in the string table, and the
## label re-renders itself when the locale changes — so no screen has to know
## which of its labels are capitals.

const VARIATION: StringName = &"LabelCaps"

## The `data/loc/strings.csv` key this label shows.
@export var label_key: String = "":
	set(value):
		label_key = value
		_refresh_strings()

## Named placeholders for `label_key`, e.g. `{tier}`.
var _args: Dictionary = {}


func _ready() -> void:
	if theme_type_variation == &"":
		theme_type_variation = VARIATION
	_refresh_strings()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_strings()


## The key and its placeholders in one call, for a label whose text changes with
## the state (a region's tier, a day number).
func set_key(key: String, args: Dictionary = {}) -> void:
	_args = args
	label_key = key


func _refresh_strings() -> void:
	if label_key.is_empty():
		return
	var translated: String = tr(label_key)
	if not _args.is_empty():
		translated = translated.format(_args)
	text = Format.caps(translated)
