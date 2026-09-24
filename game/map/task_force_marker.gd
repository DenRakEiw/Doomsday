class_name TaskForceMarker
extends Node2D
## The Response Task Force on the map (`taskforce-endings.md` §9): a square badge
## up and to the right of the anchor of the region it stands in, with the letters
## of `UI_TASK_FORCE_CODE` (the glyph is M6's), and — while it sets up — a ring
## counting the setup down around it, as a counter-move's marker counts its
## deadline.
##
## Drawn in the team's own red (G5 1/3): `TASK_FORCE` while it sets up — the
## moment before it acts — and `TASK_FORCE_DIM` while it travels or rests.
## Scaled by `1 / zoom` by the layer that owns it, so everything here is in screen
## pixels; it sits on the anchor and draws itself at `MARKER_TF_OFFSET` from it.
##
## It answers no tap: the team is read off the region and containment panels.

const HALF: float = 10.0
const STROKE: float = 2.0
const COUNTDOWN_RADIUS: float = 15.0
const COUNTDOWN_STROKE: float = 2.0

## The already-translated code; the marker reads no content.
var code: String = "":
	set(value):
		code = value
		queue_redraw()
## How much of the setup is left, 0…1; below 0 there is no setup and no ring.
var share: float = -1.0:
	set(value):
		share = value
		queue_redraw()

var _font: Font = null


func _ready() -> void:
	EventBus.theme_variant_changed.connect(_on_theme_variant_changed)


## The badge's centre relative to the anchor, in screen pixels, for the layer's
## line to the target and for the tests.
static func centre() -> Vector2:
	return UiTokens.MARKER_TF_OFFSET


## The badge's and the ring's colour for the state it shows: a setup (a ring
## to count down) is the full red, anything else the dimmed one.
func stroke_color() -> Color:
	return UiTokens.color(&"TASK_FORCE" if share >= 0.0 else &"TASK_FORCE_DIM")


func _draw() -> void:
	var at: Vector2 = centre()
	var colour: Color = stroke_color()
	var box: Rect2 = Rect2(at - Vector2(HALF, HALF), Vector2(HALF, HALF) * 2.0)
	draw_rect(box, UiTokens.color(&"BG_2"))
	draw_rect(box, colour, false, STROKE)
	if share >= 0.0:
		Rings.draw_countdown(self, at, COUNTDOWN_RADIUS, share, colour, COUNTDOWN_STROKE)
	if code.is_empty():
		return
	if _font == null:
		_font = ThemeDB.fallback_font
	var size: int = UiTokens.TYPE_CAPTION
	var width: float = _font.get_string_size(code, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(_font, at + Vector2(-width * 0.5, float(size) * 0.35), code,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, UiTokens.color(&"TEXT_0"))


func _on_theme_variant_changed(_variant: StringName) -> void:
	queue_redraw()
