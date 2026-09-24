class_name Chip
extends PanelContainer
## A small state badge (spec ui-foundation.md §4.7).
##
## §4.7 gives the chip no script, but its three colour variants colour the
## *text*, and a `PanelContainer` variation cannot reach a child label — so the
## kind sets two variations, the chip's and its label's. That keeps the ban on
## per-node overrides intact.

## `TASK_FORCE` is the team's own red (`taskforce-endings.md` §9, G5 1/3) — a
## status the Response Task Force put on a region.
enum Kind { DEFAULT, ACCENT, ALERT, TASK_FORCE }

## Suffixes on the two variation names, in the order of `Kind`.
const KIND_SUFFIX: Array[String] = ["", "Accent", "Alert", "TaskForce"]
const VARIATION: String = "Chip"
const LABEL_VARIATION: String = "ChipLabel"

## Which of §4.7's three variants this chip is.
@export var kind: Kind = Kind.DEFAULT:
	set(value):
		kind = value
		faction = ""
		_apply_variation()

## The faction whose colour the text takes, or "" for one of the three `Kind`s
## (`loop-mechanics.md` §16.5: the `ChipFaction` variation). The theme carries
## one variation per faction, so this is still a variation and not an override.
@export var faction: String = "":
	set(value):
		faction = value
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


## A running status's chip: the variation of the colour `UiTokens.status_token`
## gives its source — the team's red, a faction's colour, or the accent.
func set_status_source(source: String) -> void:
	var token: StringName = UiTokens.status_token(source)
	if token == &"TASK_FORCE":
		kind = Kind.TASK_FORCE
	elif token == &"ACCENT":
		kind = Kind.ACCENT
	else:
		faction = Status.faction_of(source)


## The key and its placeholders — a chip often carries a day or a number (§5.6).
func set_label(key: String, args: Dictionary = {}) -> void:
	_build_label()
	label_key = key
	_label.set_key(key, args)


## A chip whose text is a formatted number and has no key of its own
## (m3-screens §4.3's glance readout). It does not re-render on a locale change,
## so whoever sets it writes it again — which the readouts do every tick.
func set_text(text: String) -> void:
	_build_label()
	label_key = ""
	_label.label_key = ""
	_label.text = Format.caps(text)


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


## The variation suffix a faction id stands for: `governments` → `Governments`,
## so the theme's names stay readable and are built from the ids themselves.
static func faction_suffix(faction_id: String) -> String:
	var out: String = ""
	for part: String in faction_id.split("_", false):
		out += part.substr(0, 1).to_upper() + part.substr(1)
	return out


func _apply_variation() -> void:
	var suffix: String = KIND_SUFFIX[kind] if faction.is_empty() \
		else faction_suffix(faction)
	theme_type_variation = StringName(VARIATION + suffix)
	if _label != null:
		_label.theme_type_variation = StringName(LABEL_VARIATION + suffix)
