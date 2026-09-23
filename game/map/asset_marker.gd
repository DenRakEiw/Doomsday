class_name AssetMarker
extends Node2D
## What the agent has standing in one region (`loop-mechanics.md` §16.3.2).
##
## A row of glyphs below the region's anchor, one per kind held, in
## `AssetDef.KINDS` order — the fleet first and larger, because it is the one
## that changes what the region is worth. A count follows a glyph that stands for
## more than one.
##
## The marker is scaled by `1 / zoom` by the layer that owns it, so everything
## drawn here is in screen pixels and stays that size at every zoom.
##
## It answers no tap: the assets are the region's, and a tap on them is a tap on
## the region (§16.3.2).

## The ring that says something was just placed: it grows out of the row and
## fades. Reduced motion draws none of it.
const RING_FROM: float = 10.0
const RING_TO: float = 28.0
const RING_STROKE: float = 2.0
const RING_SEGMENTS: int = 32
## How many `MOTION_PANEL`s the ring takes.
const RING_PERIODS: float = 3.0
## The gap between one glyph (and its count) and the next.
const GAP: float = 4.0
## How far a count sits to the right of its glyph.
const COUNT_GAP: float = 2.0

## Kind → how many stand here. Written by the layer; the row follows.
var counts: Dictionary[String, int] = {}:
	set(value):
		counts = value
		queue_redraw()

## Kind → the glyph its definition names, so the marker never reads content.
var glyphs: Dictionary[String, int] = {}

## Seconds since the commissioning ring started; negative means none is running.
var _ring_elapsed: float = -1.0
var _font: Font = null


func _ready() -> void:
	EventBus.reduced_motion_changed.connect(_on_redraw_requested)
	EventBus.theme_variant_changed.connect(_on_theme_variant_changed)
	set_process(false)


func _process(delta: float) -> void:
	_ring_elapsed += delta
	if _ring_elapsed >= _ring_seconds():
		_ring_elapsed = -1.0
		set_process(false)
	queue_redraw()


## Something was just placed here: the ring of §16.3.2 runs once.
func commission() -> void:
	if UiTokens.reduced_motion() or _ring_seconds() <= 0.0:
		return
	_ring_elapsed = 0.0
	set_process(true)
	queue_redraw()


## Whether the commissioning ring is still running, for the tests.
func is_commissioning() -> bool:
	return _ring_elapsed >= 0.0


## The kinds this marker draws, in `AssetDef.KINDS` order.
func kinds() -> Array[String]:
	var out: Array[String] = []
	for kind: String in AssetDef.KINDS:
		if int(counts.get(kind, 0)) > 0:
			out.append(kind)
	return out


## How wide the row is, in screen pixels. Public so that a test can check that
## the row is centred without reading pixels.
func row_width() -> float:
	var total: float = 0.0
	var listed: Array[String] = kinds()
	for i: int in listed.size():
		total += _glyph_size(listed[i])
		if counts[listed[i]] > 1:
			total += COUNT_GAP + _count_width(counts[listed[i]])
		if i < listed.size() - 1:
			total += GAP
	return total


func _draw() -> void:
	var listed: Array[String] = kinds()
	if listed.is_empty():
		return
	var colour: Color = UiTokens.color(&"ACCENT")
	var x: float = -row_width() * 0.5
	var top: float = float(UiTokens.MARKER_ROW_OFFSET)
	for kind: String in listed:
		var size: float = _glyph_size(kind)
		var scale_factor: float = size / float(UiTokens.GLYPH_BOX)
		draw_set_transform(Vector2(x, top), 0.0, Vector2(scale_factor, scale_factor))
		Glyphs.draw(self, glyphs.get(kind, Glyphs.Glyph.ASSET_OFFICE) as Glyphs.Glyph,
			Rect2(Vector2.ZERO, Vector2.ONE * float(UiTokens.GLYPH_BOX)), colour,
			UiTokens.GLYPH_STROKE)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		x += size
		if counts[kind] > 1:
			x += COUNT_GAP
			draw_string(_caption_font(), Vector2(x, top + size),
				str(counts[kind]), HORIZONTAL_ALIGNMENT_LEFT, -1,
				UiTokens.TYPE_CAPTION, UiTokens.color(&"TEXT_0"))
			x += _count_width(counts[kind])
		x += GAP
	_draw_ring()


func _draw_ring() -> void:
	if _ring_elapsed < 0.0:
		return
	var share: float = clampf(_ring_elapsed / _ring_seconds(), 0.0, 1.0)
	var colour: Color = UiTokens.color(&"ACCENT")
	colour.a = 1.0 - share
	draw_arc(Vector2.ZERO, lerpf(RING_FROM, RING_TO, share), 0.0, TAU, RING_SEGMENTS,
		colour, RING_STROKE, true)


## The fleet leads the row and is drawn larger; the rest share one size (§16.3.2).
static func _glyph_size(kind: String) -> float:
	return UiTokens.ASSET_GLYPH_LEAD if kind == AssetDef.KIND_FLEET else UiTokens.ASSET_GLYPH


func _count_width(count: int) -> float:
	return _caption_font().get_string_size(str(count), HORIZONTAL_ALIGNMENT_LEFT, -1,
		UiTokens.TYPE_CAPTION).x


## The theme's caption font. A `Node2D` has no theme of its own, so it is taken
## from the default one the project registers.
func _caption_font() -> Font:
	if _font == null:
		_font = ThemeDB.fallback_font
	return _font


static func _ring_seconds() -> float:
	return UiTokens.duration(UiTokens.MOTION_PANEL) * RING_PERIODS


func _on_redraw_requested(_enabled: bool) -> void:
	queue_redraw()


func _on_theme_variant_changed(_variant: StringName) -> void:
	queue_redraw()
