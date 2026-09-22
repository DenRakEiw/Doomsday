class_name AnomalyMarker
extends Node2D
## One collectable anomaly on the map (spec ui-foundation.md §7.7): a disc with
## a ring pulsing out of it, at its region's anchor.
##
## The marker is scaled by `1 / zoom` by the layer that owns it, so everything
## drawn here is in screen pixels and stays that size at every zoom — a target
## that shrinks with the map would be unhittable on a phone.
##
## What it looks like is two pure functions over a phase and a number of days,
## so the pulse and the blink are checked as values rather than as pixels. The
## node only keeps the clock.

## §7.7's geometry, in screen pixels.
const DISC_RADIUS: float = 6.0
const RING_STROKE: float = 2.0
const RING_RADIUS_MIN: float = 10.0
const RING_RADIUS_MAX: float = 24.0
const RING_ALPHA_MAX: float = 0.8
## What the ring is while motion is off: one circle, standing still.
const RING_STATIC_RADIUS: float = 14.0
const RING_STATIC_ALPHA: float = 0.6
## How far from the anchor a tap still counts — half of `HIT_MIN`, so the target
## is the 48 px of §3.3 whatever the zoom does.
const HIT_RADIUS_PX: float = 24.0
const RING_SEGMENTS: int = 32

## §7.7: the disc blinks during the last days before the anomaly fades.
const BLINK_DAYS: int = 3
## Alternations per second.
const BLINK_HZ: float = 2.0

## The anomaly this marker stands for, and what a tap would collect.
var anomaly_id: int = 0
var value: float = 0.0
var expires_day: int = 0
## Days until it fades. Set by the layer on every tick; a marker has no clock of
## its own for game time.
var days_left: int = BLINK_DAYS + 1:
	set(value_in):
		if value_in == days_left:
			return
		days_left = value_in
		queue_redraw()

## Real seconds since the marker appeared — the phase of both animations.
var _elapsed: float = 0.0
var _fading: bool = false


func _ready() -> void:
	EventBus.reduced_motion_changed.connect(_on_reduced_motion_changed)


func _process(delta: float) -> void:
	if UiTokens.reduced_motion():
		# Nothing on this marker moves, so nothing has to be redrawn either.
		return
	_elapsed += delta
	queue_redraw()


# --------------------------------------------------------------- what it looks like


## The ring's `[radius, alpha]` at a point of its period, in screen pixels. It
## grows out of the disc and fades as it goes; with motion off it is one
## standing circle instead.
static func ring_for(phase: float, reduced: bool) -> Array:
	if reduced:
		return [RING_STATIC_RADIUS, RING_STATIC_ALPHA]
	var t: float = clampf(phase, 0.0, 1.0)
	return [lerpf(RING_RADIUS_MIN, RING_RADIUS_MAX, t), lerpf(RING_ALPHA_MAX, 0.0, t)]


## The disc's colour: the console's own accent, and in the last days before the
## anomaly fades a blink between that and `ALERT` — which with motion off is
## simply `ALERT`, because "now" still has to be visible.
static func disc_color(days: int, elapsed: float, reduced: bool) -> Color:
	if days > BLINK_DAYS:
		return UiTokens.ACCENT
	if reduced:
		return UiTokens.ALERT
	var period: float = 1.0 / BLINK_HZ
	return UiTokens.ACCENT if fmod(elapsed, period) < period * 0.5 else UiTokens.ALERT


## Whether a tap at `point` (both in map pixels) hits a marker at `at`. The
## reach is a screen distance, so it grows as the map shrinks.
static func hits(at: Vector2, point: Vector2, zoom: float) -> bool:
	if zoom <= 0.0:
		return false
	return at.distance_to(point) * zoom <= HIT_RADIUS_PX


func _draw() -> void:
	var reduced: bool = UiTokens.reduced_motion()
	var ring: Array = ring_for(_phase(), reduced)
	var color: Color = UiTokens.ACCENT
	color.a = float(ring[1])
	draw_arc(Vector2.ZERO, float(ring[0]), 0.0, TAU, RING_SEGMENTS, color,
		RING_STROKE, true)
	draw_circle(Vector2.ZERO, DISC_RADIUS, disc_color(days_left, _elapsed, reduced))


# ---------------------------------------------------------------------- lifetime


## Takes the marker off the map: it fades out over `MOTION_PANEL` and frees
## itself. Called when its anomaly expires or is collected.
func fade_out() -> void:
	if _fading:
		return
	_fading = true
	var seconds: float = UiTokens.duration(UiTokens.MOTION_PANEL)
	if seconds <= 0.0:
		queue_free()
		return
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, seconds)
	tween.tween_callback(queue_free)


## True once the marker is on its way out — it must not answer a tap any more.
func is_fading() -> bool:
	return _fading


func _phase() -> float:
	var period: float = UiTokens.seconds(UiTokens.ANOMALY_PULSE_PERIOD)
	if period <= 0.0:
		return 0.0
	return fmod(_elapsed, period) / period


func _on_reduced_motion_changed(_enabled: bool) -> void:
	queue_redraw()
