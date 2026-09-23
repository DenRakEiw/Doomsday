class_name AnomalyMarker
extends Node2D
## One collectable anomaly on the map (spec ui-foundation.md §7.7): a disc with
## a ring pulsing out of it and a ring counting its days down, at its region's
## anchor.
##
## The marker is scaled by `1 / zoom` by the layer that owns it, so everything
## drawn here is in screen pixels and stays that size at every zoom — a target
## that shrinks with the map would be unhittable on a phone.
##
## What it looks like is two pure functions over a phase and a number of days,
## so the pulse and the countdown are checked as values rather than as pixels.
## The node only keeps the clock.

## §7.7's geometry, in screen pixels.
const DISC_RADIUS: float = 6.0
const RING_STROKE: float = 2.0
const RING_RADIUS_MIN: float = 10.0
const RING_RADIUS_MAX: float = 24.0
const RING_ALPHA_MAX: float = 0.8
## The countdown ring of the days left, which stands still in both modes: with
## motion off it is the only ring the marker has. It is drawn by `Rings`, which
## every marker with a clock shares (§16.3.2).
const COUNTDOWN_RADIUS: float = 14.0
const COUNTDOWN_ALPHA: float = 0.6
## How far from the anchor a tap still counts — half of `HIT_MIN`, so the target
## is the 48 px of §3.3 whatever the zoom does.
const HIT_RADIUS_PX: float = 24.0
const RING_SEGMENTS: int = 32

## The anomaly this marker stands for, and what a tap would collect.
var anomaly_id: int = 0
var value: float = 0.0
var expires_day: int = 0
## How long this anomaly had from the start (`balance.anomaly.lifetime_days`):
## the full ring. Handed over by the layer, which is the one that knows content.
var lifetime_days: int = 1:
	set(value_in):
		if value_in == lifetime_days:
			return
		lifetime_days = value_in
		queue_redraw()
## Days until it fades. Set by the layer on every tick; a marker has no clock of
## its own for game time.
var days_left: int = 1:
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
	# The palette can change mid-run (m3-screens §6.2); a drawn colour is not
	# a theme item and has to be asked for again.
	EventBus.theme_variant_changed.connect(_on_theme_variant_changed)


func _on_theme_variant_changed(_variant: StringName) -> void:
	queue_redraw()


func _process(delta: float) -> void:
	if UiTokens.reduced_motion():
		# Nothing on this marker moves, so nothing has to be redrawn either.
		return
	_elapsed += delta
	queue_redraw()


# --------------------------------------------------------------- what it looks like


## The pulsing ring's `[radius, alpha]` at a point of its period, in screen
## pixels: it grows out of the disc and fades as it goes. With motion off it is
## not drawn at all — the countdown ring is what stands there instead.
static func ring_for(phase: float) -> Array:
	var t: float = clampf(phase, 0.0, 1.0)
	return [lerpf(RING_RADIUS_MIN, RING_RADIUS_MAX, t), lerpf(RING_ALPHA_MAX, 0.0, t)]


## The share of the countdown ring still drawn: all of it on the day it spawned,
## none of it on the day it fades. G3 replaced the red blink of the last days
## with this, because `ALERT` reads as "danger, do not touch" where the marker
## means "hurry" — and a standing state is not what `ALERT` marks (G2).
static func countdown_for(days: int, lifetime: int) -> float:
	if lifetime <= 0:
		return 0.0
	return Rings.share_of(float(days), float(lifetime))


## Whether a tap at `point` (both in map pixels) hits a marker at `at`. The
## reach is a screen distance, so it grows as the map shrinks.
static func hits(at: Vector2, point: Vector2, zoom: float) -> bool:
	if zoom <= 0.0:
		return false
	return at.distance_to(point) * zoom <= HIT_RADIUS_PX


func _draw() -> void:
	if not UiTokens.reduced_motion():
		var ring: Array = ring_for(_phase())
		var pulse: Color = UiTokens.color(&"ACCENT")
		pulse.a = float(ring[1])
		draw_arc(Vector2.ZERO, float(ring[0]), 0.0, TAU, RING_SEGMENTS, pulse,
			RING_STROKE, true)
	var countdown: Color = UiTokens.color(&"ACCENT")
	countdown.a = COUNTDOWN_ALPHA
	Rings.draw_countdown(self, Vector2.ZERO, COUNTDOWN_RADIUS,
		countdown_for(days_left, lifetime_days), countdown, RING_STROKE)
	draw_circle(Vector2.ZERO, DISC_RADIUS, UiTokens.color(&"ACCENT"))


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
