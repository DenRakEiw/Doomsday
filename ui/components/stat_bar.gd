class_name StatBar
extends Control
## A labelled 0 … 1 bar (spec ui-foundation.md §4.4).
##
## The fill follows the value over `MOTION_BAR` instead of jumping, and a change
## worth noticing flashes the number — a run is watched, not read, and a bar that
## moves is what tells the player something happened.
##
## §5.7's compact layout is the same three nodes on one row, re-parented; the
## variations `StatBarPenetration`, `…Footprint` and `…Harm` pick the fill
## colour, which is why the bar node is handed this node's own variation.

## A change this big flashes the value label (§4.4).
const FLASH_THRESHOLD: float = 0.01
const VARIATION: StringName = &"StatBar"
const CONST_MIN_HEIGHT: StringName = &"min_height"
const CONST_COMPACT_HEIGHT: StringName = &"compact_height"

## The `data/loc/strings.csv` key of the bar's name.
@export var label_key: String = "":
	set(value):
		label_key = value
		if _name_label != null:
			_name_label.label_key = value

## §5.7: label, bar and value on one row instead of two.
@export var compact: bool = false:
	set(value):
		compact = value
		if is_node_ready():
			_apply_compact()

@onready var _rows: VBoxContainer = %Rows
@onready var _head: HBoxContainer = %Head
@onready var _compact_row: HBoxContainer = %CompactRow
@onready var _glyph: GlyphIcon = %Glyph
@onready var _name_label: CapsLabel = %NameLabel
@onready var _value_label: ValueLabel = %Value
@onready var _fill: StatBarFill = %Fill

## Whether the bar carries its own name and number. A `FactionTrack` has both in
## a row of its own, and two of each would read as two bars (m3-screens §4.2).
@export var show_head: bool = true:
	set(value):
		show_head = value
		if _head != null:
			_apply_compact()

## Marks drawn on the trough, as shares in 0…1 (m3-screens §4.2). Empty for the
## three HUD bars, which have nothing to escalate at.
var ticks: Array[float] = []:
	set(value):
		ticks = value
		if _fill != null:
			_fill.ticks = value

var _value: float = 0.0
## The number the label reads out and the form it takes. Kept because the
## separators belong to the locale (§8.5): a bar the run is not updating still
## has to change its number when the language changes.
var _shown: float = 0.0
var _kind: Format.Kind = Format.Kind.PERCENT
var _tween: Tween = null


func _ready() -> void:
	_fill.ticks = ticks
	if theme_type_variation == &"":
		theme_type_variation = VARIATION
	_name_label.label_key = label_key
	_apply_compact()
	_value_label.set_number(_shown, _kind)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_node_ready():
		_apply_variation()
		_apply_heights()
	elif what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_value_label.set_number(_shown, _kind)


## The share the bar shows, 0 … 1. The fill tweens to it; a change of at least
## `FLASH_THRESHOLD` flashes the value.
func set_value(new_value: float) -> void:
	_set_value(new_value, new_value, Format.Kind.PERCENT)


## §5.3: some bars are a share of a presentation maximum but read out their raw
## number — footprint and harm have no natural 100 %.
func set_value_raw(share: float, shown: float, kind: Format.Kind) -> void:
	_set_value(share, shown, kind)


## A glyph before the name, in a colour token (opposition.md §9.1's faction
## face). Hidden until set.
func set_glyph(glyph: Glyphs.Glyph, color_token: StringName, box: float) -> void:
	_glyph.glyph = glyph
	_glyph.color_token = color_token
	_glyph.box_size = box
	_glyph.visible = true


func clear_glyph() -> void:
	_glyph.visible = false


## The rate beside the number, as `ValueLabel.set_delta_in` writes it.
func set_delta_in(key: String, placeholder: String, delta: float, kind: Format.Kind) -> void:
	_value_label.set_delta_in(key, placeholder, delta, kind)


func clear_delta() -> void:
	_value_label.clear_delta()


## Lights the number up once — a change that is not a change of the value
## (the threat bar's new leader).
func flash() -> void:
	_value_label.flash()


## What the bar currently shows, after clamping.
func value() -> float:
	return _value


func _set_value(share: float, shown: float, kind: Format.Kind) -> void:
	var wanted: float = clampf(share, 0.0, 1.0)
	var changed: float = absf(wanted - _value)
	_value = wanted
	_shown = shown
	_kind = kind
	_value_label.set_number(shown, kind)
	if changed >= FLASH_THRESHOLD:
		_value_label.flash()
	var seconds: float = UiTokens.duration(UiTokens.MOTION_BAR)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if seconds <= 0.0 or not is_inside_tree():
		_fill.displayed_value = wanted
		return
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(_fill, "displayed_value", wanted, seconds)


## Moves the same three nodes between the two rows of §5.7.
func _apply_compact() -> void:
	if not show_head:
		_head.visible = false
		_compact_row.visible = false
		_move(_fill, _rows)
		# Alone in its column the fill has no minimum height of its own; without
		# the stretch it would be 0 px tall and draw nothing a track can see.
		_fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_apply_variation()
		_apply_heights()
		return
	_rows.visible = not compact
	_compact_row.visible = compact
	if compact:
		_move(_glyph, _compact_row)
		_move(_name_label, _compact_row)
		_move(_fill, _compact_row)
		_move(_value_label, _compact_row)
	else:
		_move(_glyph, _head)
		_move(_name_label, _head)
		_move(_value_label, _head)
		_move(_fill, _rows)
	_name_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if compact \
		else Control.SIZE_EXPAND_FILL
	# In the wide row the value is what a glance needs; a name longer than its
	# quarter ends in an ellipsis instead of pushing the value off the screen —
	# at 150 % *SICHERHEITSFORSCHUNG* ran over *SCHADEN*'s number (S4.9).
	_name_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING if compact \
		else TextServer.OVERRUN_TRIM_ELLIPSIS
	_fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fill.size_flags_vertical = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_FILL
	_apply_variation()
	_apply_heights()


func _move(node: Control, parent: Container) -> void:
	if node.get_parent() == parent:
		parent.move_child(node, parent.get_child_count() - 1)
		return
	node.get_parent().remove_child(node)
	parent.add_child(node)


## The bar reads `fill` off its own type, so it has to be the same type as this
## node — including the variation a scene chose.
func _apply_variation() -> void:
	_fill.theme_type_variation = theme_type_variation


func _apply_heights() -> void:
	# Without its own name and number the bar is one row, like the compact one.
	var key: StringName = CONST_COMPACT_HEIGHT if compact or not show_head \
		else CONST_MIN_HEIGHT
	custom_minimum_size.y = float(get_theme_constant(key))
