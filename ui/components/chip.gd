class_name Chip
extends PanelContainer
## A small state badge (spec ui-foundation.md §4.7).
##
## §4.7 gives the chip no script, but its three colour variants colour the
## *text*, and a `PanelContainer` variation cannot reach a child label — so the
## kind sets two variations, the chip's and its label's. That keeps the ban on
## per-node overrides intact.

enum Kind { DEFAULT, ACCENT, ALERT }

## Suffixes on the two variation names, in the order of `Kind`.
const KIND_SUFFIX: Array[String] = ["", "Accent", "Alert"]
const VARIATION: String = "Chip"
const LABEL_VARIATION: String = "ChipLabel"

## Which of §4.7's three variants this chip is.
@export var kind: Kind = Kind.DEFAULT:
	set(value):
		kind = value
		_apply_variation()

## The `data/loc/strings.csv` key of the badge text.
@export var label_key: String = "":
	set(value):
		label_key = value
		if _label != null:
			_label.label_key = value

var _label: CapsLabel = null


func _ready() -> void:
	_build_label()
	_apply_variation()


## The key and its placeholders — a chip often carries a day or a number (§5.6).
func set_label(key: String, args: Dictionary = {}) -> void:
	_build_label()
	label_key = key
	_label.set_key(key, args)


func _build_label() -> void:
	if _label != null:
		return
	_label = CapsLabel.new()
	_label.label_key = label_key
	# A badge stays on one line: an `HFlowContainer` lays its children out at
	# their minimum size, and a wrapping label's minimum is its longest word, so
	# autowrap turns a row of chips into a column of syllables. The price is that
	# a very long string makes a very wide chip — `UI_REGION_STATE_DARK` in
	# German is one, and that is a question for Fable (PROGRESS.md), not a
	# component that clips its own text.
	add_child(_label)
	_apply_variation()


func _apply_variation() -> void:
	theme_type_variation = StringName(VARIATION + KIND_SUFFIX[kind])
	if _label != null:
		_label.theme_type_variation = StringName(LABEL_VARIATION + KIND_SUFFIX[kind])
