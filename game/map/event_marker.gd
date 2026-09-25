class_name EventMarker
extends Node2D
## The map events standing in one region (`loop-mechanics.md` §16.3.2).
##
## A disc up and to the left of the region's anchor, with the kind's mark in it
## — `!` in the faction's colour for a counter-move, ◇ in `ACCENT` for an
## opening, » in `TEXT_0` for a chain step — its deadline as a ring counting
## down around it, and a pulse like an anomaly's. Two events in one region share
## one marker, which then carries a small count.
##
## The marker is scaled by `1 / zoom` by the layer that owns it, so everything
## drawn here is in screen pixels; it sits on the anchor and draws itself at
## `MARKER_EVENT_OFFSET` from it.

const DISC_RADIUS: float = 10.0
const DISC_STROKE: float = 2.0
const GLYPH_SIZE: float = 14.0
const GLYPH_STROKE: float = 2.0
const COUNTDOWN_RADIUS: float = 14.0
const COUNTDOWN_STROKE: float = 2.0
const PULSE_RADIUS_MIN: float = 12.0
const PULSE_RADIUS_MAX: float = 26.0
const PULSE_ALPHA_MAX: float = 0.6
const PULSE_SEGMENTS: int = 32
## How far from the disc a tap still counts — the 48 px of `HIT_MIN`.
const HIT_RADIUS_PX: float = 24.0
## The count's offset from the disc's centre, in screen pixels.
const COUNT_OFFSET: Vector2 = Vector2(10.0, -10.0)

## The oldest event here, which a tap opens and the tooltip names.
var event_id: int = 0
var kind: String = EventDef.KIND_OPENING
## The mark's colour: the faction's for a counter-move.
var color: Color = Color.WHITE:
	set(value):
		color = value
		queue_redraw()
## How much of the deadline is left, 0…1.
var share: float = 1.0:
	set(value):
		share = value
		queue_redraw()
## How many events stand in this region.
var count: int = 1:
	set(value):
		count = value
		queue_redraw()

var _elapsed: float = 0.0


func _ready() -> void:
	EventBus.reduced_motion_changed.connect(_on_redraw_needed)
	EventBus.theme_variant_changed.connect(_on_redraw_needed)


func _process(delta: float) -> void:
	if UiTokens.reduced_motion():
		return
	_elapsed += delta
	queue_redraw()


## The disc's centre relative to the anchor, in screen pixels.
static func centre() -> Vector2:
	return UiTokens.MARKER_EVENT_OFFSET


## Whether a tap at `point` (map pixels) hits a marker anchored at `at`.
static func hits(at: Vector2, point: Vector2, zoom: float) -> bool:
	if zoom <= 0.0:
		return false
	return ((point - at) * zoom).distance_to(centre()) <= HIT_RADIUS_PX


func _draw() -> void:
	var at: Vector2 = centre()
	if not UiTokens.reduced_motion():
		var period: float = UiTokens.seconds(UiTokens.ANOMALY_PULSE_PERIOD)
		var phase: float = fmod(_elapsed, period) / period if period > 0.0 else 0.0
		var pulse: Color = color
		pulse.a = lerpf(PULSE_ALPHA_MAX, 0.0, phase)
		draw_arc(at, lerpf(PULSE_RADIUS_MIN, PULSE_RADIUS_MAX, phase), 0.0, TAU,
			PULSE_SEGMENTS, pulse, DISC_STROKE, true)
	draw_circle(at, DISC_RADIUS, UiTokens.color(&"BG_2"))
	draw_arc(at, DISC_RADIUS, 0.0, TAU, PULSE_SEGMENTS, color, DISC_STROKE, true)
	Rings.draw_countdown(self, at, COUNTDOWN_RADIUS, share, color, COUNTDOWN_STROKE)
	var scale_factor: float = GLYPH_SIZE / float(UiTokens.GLYPH_BOX)
	Glyphs.draw_scaled(self, Glyphs.event_glyph(kind), at - Vector2(GLYPH_SIZE, GLYPH_SIZE) * 0.5,
		GLYPH_SIZE, color, GLYPH_STROKE / scale_factor)
	if count > 1:
		var font: Font = ThemeDB.fallback_font
		var text: String = str(count)
		draw_string(font, at + COUNT_OFFSET, text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			UiTokens.TYPE_CAPTION, UiTokens.color(&"TEXT_0"))


func _on_redraw_needed(_value: Variant) -> void:
	queue_redraw()
