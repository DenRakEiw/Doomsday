class_name ValueLabel
extends Label
## A number, right-aligned, optionally with the change since the last reading
## (spec ui-foundation.md §4.5).
##
## A `Label` draws in one colour, so the direction of a delta colours the whole
## label rather than the arrow alone — the states of §4.5 are theme variations
## (`ValueLabelUp`, `…Down`, `…Muted`), never a per-node override. The flash of
## §4.4 is the one thing a variation cannot do, so it rides on `self_modulate`,
## which is a property and not a theme item: the factor is chosen so that the
## label renders exactly `TEXT_0` at the start and exactly its state colour at
## the end.

## U+25B2 and U+25BC. Both are in JetBrains Mono (checked at S2.4), so the
## fallback of §4.5 — sign only — is not needed.
const ARROW_UP: String = "▲"
const ARROW_DOWN: String = "▼"
const PLUS: String = "+"

const VARIATION: StringName = &"ValueLabel"
const VARIATION_LARGE: String = "Large"

enum State { NEUTRAL, UP, DOWN, MUTED }

## Suffixes on `VARIATION`, in the order of `State`.
const STATE_SUFFIX: Array[String] = ["", "Up", "Down", "Muted"]

const COLOR_FONT: StringName = &"font_color"
## Below this a channel cannot be brightened into `TEXT_0` by multiplying, so the
## flash leaves it alone rather than dividing by nearly nothing.
const CHANNEL_FLOOR: float = 0.001

## The compute readout of §5.2 — `TYPE_DATA_LG` instead of `TYPE_DATA`.
@export var large: bool = false:
	set(value):
		large = value
		_apply_variation()

## The variation family this label takes its look from. A component whose
## numbers have a colour of their own (m3-screens §3.4's tech node) points this
## at its own family instead of reaching for a per-node override. The family
## needs an entry per state it can reach; a label that never carries a delta
## needs only the plain one.
@export var variation_base: StringName = VARIATION:
	set(value):
		variation_base = value
		_apply_variation()

var _value_text: String = ""
var _delta_text: String = ""
var _state: State = State.NEUTRAL
var _flash: Tween = null


func _ready() -> void:
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_apply_variation()


## The value itself. The delta, if one was set, stays where it is.
func set_number(value: float, kind: Format.Kind) -> void:
	_value_text = Format.number(value, kind)
	_apply_text()


## The same number inside a sentence from the string table: §5.2's day cell is
## `UI_HUD_DAY` (`{day}`), not a bare figure. The caller names the placeholder,
## because the key owns its own wording.
func set_number_in(key: String, placeholder: String, value: float,
		kind: Format.Kind) -> void:
	_value_text = tr(key).format({placeholder: Format.number(value, kind)})
	_apply_text()


## Appends the change since the last reading: `" ▲ +12"`, `" ▼ −3"`, or the bare
## number when it is zero. The direction colours the label.
func set_delta(delta: float, kind: Format.Kind) -> void:
	_set_delta(delta, kind, "", "")


## §5.2: the compute cell's delta is a rate — a sentence around the arrow and the
## number (`UI_HUD_COMPUTE_RATE`), coloured by the same three states.
func set_delta_in(key: String, placeholder: String, delta: float,
		kind: Format.Kind) -> void:
	_set_delta(delta, kind, key, placeholder)


## Zero is what the label *shows*, not what it was given (§4.5): a rate of 0.03
## formats as `0`, and `▲ +0` is a lie about a number that has not moved (G2).
func _set_delta(delta: float, kind: Format.Kind, key: String, placeholder: String) -> void:
	var formatted: String = Format.number(delta, kind)
	var zero: String = Format.number(0.0, kind)
	var body: String = ""
	if Format.number(absf(delta), kind) == zero:
		_state = State.MUTED
		body = zero
	elif delta > 0.0:
		_state = State.UP
		body = "%s %s%s" % [ARROW_UP, PLUS, formatted]
	else:
		_state = State.DOWN
		body = "%s %s" % [ARROW_DOWN, formatted]
	if not key.is_empty():
		body = tr(key).format({placeholder: body})
	_delta_text = " " + body
	_apply_variation()
	_apply_text()


## Drops the delta and returns the label to the neutral colour.
func clear_delta() -> void:
	_delta_text = ""
	_state = State.NEUTRAL
	_apply_variation()
	_apply_text()


## §4.4: the label lights up to `TEXT_0` and fades back to its state colour.
## Under reduced motion `duration` is 0 and the flash never happens.
func flash() -> void:
	var seconds: float = UiTokens.duration(UiTokens.MOTION_FLASH)
	if _flash != null and _flash.is_valid():
		_flash.kill()
	self_modulate = Color.WHITE
	if seconds <= 0.0 or not is_inside_tree():
		return
	_flash = create_tween()
	_flash.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	self_modulate = _flash_modulate()
	_flash.tween_property(self, "self_modulate", Color.WHITE, seconds)


## What the label's own colour has to be multiplied by to render as `TEXT_0`.
func _flash_modulate() -> Color:
	var base: Color = get_theme_color(COLOR_FONT)
	return Color(
		_ratio(UiTokens.TEXT_0.r, base.r),
		_ratio(UiTokens.TEXT_0.g, base.g),
		_ratio(UiTokens.TEXT_0.b, base.b))


static func _ratio(target: float, base: float) -> float:
	return 1.0 if base < CHANNEL_FLOOR else target / base


func _apply_text() -> void:
	text = _value_text + _delta_text


func _apply_variation() -> void:
	var size_part: String = VARIATION_LARGE if large else ""
	theme_type_variation = StringName(String(variation_base) + size_part + STATE_SUFFIX[_state])
