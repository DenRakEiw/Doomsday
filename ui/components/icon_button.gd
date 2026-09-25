class_name IconButton
extends Button
## A square button with a drawn glyph and no text (spec ui-foundation.md §4.3).
##
## The shapes live in `Glyphs` (m3-screens.md §3.4.1) so that a tech node and a
## chip can draw the same ones; this button only decides where the box sits and
## which colour the current state is.

## The shapes are `Glyphs`', the name stays here: `IconButton.Glyph.CLOSE` reads
## the way it always did.
const Glyph = Glyphs.Glyph

const VARIATION: StringName = &"IconButton"

const COLOR_FONT: StringName = &"font_color"
const COLOR_FONT_HOVER: StringName = &"font_hover_color"
const COLOR_FONT_PRESSED: StringName = &"font_pressed_color"
const COLOR_FONT_DISABLED: StringName = &"font_disabled_color"

## The glyph this button draws.
@export var glyph: Glyphs.Glyph = Glyphs.Glyph.CLOSE:
	set(value):
		glyph = value
		queue_redraw()

## The key of the tooltip, which is also the accessible name (§4.3).
@export var tooltip_key: String = "":
	set(value):
		tooltip_key = value
		_refresh_strings()


func _ready() -> void:
	if theme_type_variation == &"":
		theme_type_variation = VARIATION
	var minimum: float = float(UiTokens.HIT_MIN)
	custom_minimum_size = Vector2(maxf(custom_minimum_size.x, minimum),
		maxf(custom_minimum_size.y, minimum))
	_refresh_strings()
	# The glyph is drawn in the state's colour, so every state change is a redraw.
	var state_signals: Array = [mouse_entered, mouse_exited, button_down, button_up,
		focus_entered, focus_exited]
	for state_signal: Signal in state_signals:
		state_signal.connect(queue_redraw)
	toggled.connect(_on_toggled)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_strings()
	elif what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


func _draw() -> void:
	Glyphs.draw(self, glyph, _glyph_box(), _state_color(), UiTokens.GLYPH_STROKE)


## Where the 24 box sits inside the button, whatever size the layout gave it.
func _glyph_box() -> Rect2:
	var side: float = float(UiTokens.GLYPH_BOX)
	return Rect2(((size - Vector2(side, side)) * 0.5).round(), Vector2(side, side))


## The text colour of the state the button is in — the same table as
## `ConsoleButton`, read from the theme so the glyph never has a colour of its own.
func _state_color() -> Color:
	match get_draw_mode():
		DRAW_DISABLED:
			return get_theme_color(COLOR_FONT_DISABLED)
		DRAW_PRESSED, DRAW_HOVER_PRESSED:
			return get_theme_color(COLOR_FONT_PRESSED)
		DRAW_HOVER:
			return get_theme_color(COLOR_FONT_HOVER)
		_:
			return get_theme_color(COLOR_FONT)


func _on_toggled(_pressed: bool) -> void:
	queue_redraw()


func _refresh_strings() -> void:
	if tooltip_key.is_empty():
		return
	tooltip_text = KeyNames.format(tr(tooltip_key))
	accessibility_name = tooltip_text
