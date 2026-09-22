class_name IconButton
extends Button
## A square button with a drawn glyph and no text (spec ui-foundation.md §4.3).
##
## M2 ships no icon assets, so every glyph is drawn here inside a centred 24 × 24
## box in the text colour of the button's current state. The icon pipeline is M6;
## until then this file is the whole icon set, and its shapes are the spec's.

enum Glyph { PAUSE, PLAY, FAST_2, FAST_4, CLOSE, CHEVRON_LEFT, CHEVRON_RIGHT, CHEVRON_DOWN,
	OVERLAY }

const VARIATION: StringName = &"IconButton"

const COLOR_FONT: StringName = &"font_color"
const COLOR_FONT_HOVER: StringName = &"font_hover_color"
const COLOR_FONT_PRESSED: StringName = &"font_pressed_color"
const COLOR_FONT_DISABLED: StringName = &"font_disabled_color"

# §4.3's shapes, in the coordinates of the 24 box.
const PAUSE_BAR: Vector2 = Vector2(6.0, 20.0)
const PAUSE_GAP: float = 4.0
const PLAY_SIZE: Vector2 = Vector2(18.0, 20.0)
const FAST_2_SIZE: Vector2 = Vector2(10.0, 16.0)
const FAST_4_SIZE: Vector2 = Vector2(8.0, 14.0)
const FAST_OVERLAP: float = 2.0
const CLOSE_INSET: float = 4.0
const CHEVRON_DEPTH: float = 12.0
const OVERLAY_SLAB: Vector2 = Vector2(20.0, 4.0)
const OVERLAY_TOPS: Array[float] = [3.0, 10.0, 17.0]

## The glyph this button draws.
@export var glyph: Glyph = Glyph.CLOSE:
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
	var box: Rect2 = _glyph_box()
	var color: Color = _state_color()
	match glyph:
		Glyph.PAUSE:
			_draw_pause(box, color)
		Glyph.PLAY:
			_draw_triangles(box, 1, PLAY_SIZE, color)
		Glyph.FAST_2:
			_draw_triangles(box, 2, FAST_2_SIZE, color)
		Glyph.FAST_4:
			_draw_triangles(box, 3, FAST_4_SIZE, color)
		Glyph.CLOSE:
			_draw_close(box, color)
		Glyph.OVERLAY:
			_draw_overlay(box, color)
		_:
			_draw_chevron(box, color)


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


func _draw_pause(box: Rect2, color: Color) -> void:
	var total: float = PAUSE_BAR.x * 2.0 + PAUSE_GAP
	var left: float = box.position.x + (box.size.x - total) * 0.5
	var top: float = box.position.y + (box.size.y - PAUSE_BAR.y) * 0.5
	for i: int in 2:
		var x: float = left + float(i) * (PAUSE_BAR.x + PAUSE_GAP)
		draw_rect(Rect2(Vector2(x, top), PAUSE_BAR), color)


## One, two or three triangles pointing right, overlapping by `FAST_OVERLAP`.
func _draw_triangles(box: Rect2, count: int, triangle: Vector2, color: Color) -> void:
	var step: float = triangle.x - FAST_OVERLAP
	var total: float = triangle.x + step * float(count - 1)
	var left: float = box.position.x + (box.size.x - total) * 0.5
	var top: float = box.position.y + (box.size.y - triangle.y) * 0.5
	for i: int in count:
		var x: float = left + step * float(i)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, top),
			Vector2(x + triangle.x, top + triangle.y * 0.5),
			Vector2(x, top + triangle.y),
		]), color)


func _draw_close(box: Rect2, color: Color) -> void:
	var a: Vector2 = box.position + Vector2(CLOSE_INSET, CLOSE_INSET)
	var b: Vector2 = box.end - Vector2(CLOSE_INSET, CLOSE_INSET)
	draw_line(a, b, color, UiTokens.GLYPH_STROKE)
	draw_line(Vector2(b.x, a.y), Vector2(a.x, b.y), color, UiTokens.GLYPH_STROKE)


## A two-segment chevron pointing the way its glyph name says.
func _draw_chevron(box: Rect2, color: Color) -> void:
	var centre: Vector2 = box.get_center()
	var half: float = CHEVRON_DEPTH * 0.5
	var direction: Vector2 = Vector2.LEFT
	if glyph == Glyph.CHEVRON_RIGHT:
		direction = Vector2.RIGHT
	elif glyph == Glyph.CHEVRON_DOWN:
		direction = Vector2.DOWN
	var across: Vector2 = Vector2(direction.y, direction.x)
	var tip: Vector2 = centre + direction * half
	var back: Vector2 = centre - direction * half
	draw_line(back + across * CHEVRON_DEPTH, tip, color, UiTokens.GLYPH_STROKE)
	draw_line(back - across * CHEVRON_DEPTH, tip, color, UiTokens.GLYPH_STROKE)


func _draw_overlay(box: Rect2, color: Color) -> void:
	var left: float = box.position.x + (box.size.x - OVERLAY_SLAB.x) * 0.5
	for top: float in OVERLAY_TOPS:
		draw_rect(Rect2(Vector2(left, box.position.y + top), OVERLAY_SLAB), color)


func _on_toggled(_pressed: bool) -> void:
	queue_redraw()


func _refresh_strings() -> void:
	if tooltip_key.is_empty():
		return
	tooltip_text = tr(tooltip_key)
	accessibility_name = tooltip_text
