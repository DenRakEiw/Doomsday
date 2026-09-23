class_name StatusMarker
extends Node2D
## What is running in one region, drawn on its anchor
## (`loop-mechanics.md` §16.3.2).
##
## One ring per status, nested outwards, each emptying as its days run out, with
## the innermost status's two-or-three-letter code inside. The player's own
## statuses are drawn in `ACCENT`, the world's in the colour of the faction
## behind them — read off the status's **source**, not its definition, because a
## chain can hand a world status to a region with no faction behind it (§16.3.1).
##
## The marker is scaled by `1 / zoom` by the layer that owns it, so everything
## drawn here is in screen pixels and stays that size at every zoom.
##
## It answers no tap: the statuses are the region's, and a tap on them is a tap
## on the region.

const RING_STROKE: float = 3.0

## One row per status, in application order: what to draw and how much is left.
## `code` is the already-translated caption; the marker reads no content.
var rows: Array[Dictionary] = []:
	set(value):
		rows = value
		queue_redraw()

var _font: Font = null


func _ready() -> void:
	EventBus.theme_variant_changed.connect(_on_theme_variant_changed)


## One row of `rows`. Static so that the layer builds them without knowing the
## marker's shape, and a test can build one without a tree.
static func row(code: String, share: float, color: Color) -> Dictionary:
	return {"code": code, "share": share, "color": color}


## The radius of the ring at `index`, in screen pixels. The innermost is the
## first status the region got, and every later one sits outside it (§16.3.2).
static func radius_of(index: int) -> float:
	return UiTokens.STATUS_RING_RADIUS + UiTokens.STATUS_RING_STEP * float(index)


## How many statuses this marker stands for, for the layer and the tests.
func count() -> int:
	return rows.size()


## The radius the outermost ring reaches, which is what the layer measures a
## hover against.
func outer_radius() -> float:
	if rows.is_empty():
		return 0.0
	return radius_of(rows.size() - 1) + RING_STROKE


func _draw() -> void:
	if rows.is_empty():
		return
	for i: int in rows.size():
		var entry: Dictionary = rows[i]
		Rings.draw_countdown(self, Vector2.ZERO, radius_of(i), float(entry["share"]),
			entry["color"] as Color, RING_STROKE)
	# The innermost status names itself; the ones outside it are read off the
	# region panel, which lists them all.
	var code: String = str(rows[0]["code"])
	if code.is_empty():
		return
	var font: Font = _caption_font()
	var width: float = font.get_string_size(code, HORIZONTAL_ALIGNMENT_LEFT, -1,
		UiTokens.TYPE_CAPTION).x
	draw_string(font, Vector2(-width * 0.5, float(UiTokens.TYPE_CAPTION) * 0.35), code,
		HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.TYPE_CAPTION, UiTokens.color(&"TEXT_0"))


## The theme's caption font. A `Node2D` has no theme of its own, so it is taken
## from the default one the project registers.
func _caption_font() -> Font:
	if _font == null:
		_font = ThemeDB.fallback_font
	return _font


func _on_theme_variant_changed(_variant: StringName) -> void:
	queue_redraw()
