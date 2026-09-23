class_name GlyphIcon
extends Control
## One `Glyphs` shape as a `Control`, so a row or a bar can hold an icon without
## a texture (`loop-mechanics.md` §16.3.2, §16.5, §16.9).
##
## `Glyphs.draw` works in a 24 box; this scales that box to `box_size`, which is
## what lets a fleet glyph be 16 px in one row and 12 px in another.

## The 24 square `Glyphs` draws in.
const AUTHORED_BOX: float = 24.0

@export var glyph: Glyphs.Glyph = Glyphs.Glyph.ASSET_FLEET:
	set(value):
		glyph = value
		queue_redraw()

## The side of the square the glyph is drawn into, in pixels.
@export var box_size: float = float(UiTokens.GLYPH_BOX):
	set(value):
		box_size = maxf(value, 1.0)
		custom_minimum_size = Vector2(box_size, box_size)
		queue_redraw()

## The `UiTokens` colour token the shape takes.
@export var color_token: StringName = &"ACCENT":
	set(value):
		color_token = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(box_size, box_size)
	# The palette can change mid-run (m3-screens §6.2); a drawn colour is not a
	# theme item and has to be asked for again.
	EventBus.theme_variant_changed.connect(_on_theme_variant_changed)


func _draw() -> void:
	var scale_factor: float = box_size / AUTHORED_BOX
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(scale_factor, scale_factor))
	Glyphs.draw(self, glyph, Rect2(Vector2.ZERO, Vector2(AUTHORED_BOX, AUTHORED_BOX)),
		UiTokens.color(color_token), UiTokens.GLYPH_STROKE)


func _on_theme_variant_changed(_variant: StringName) -> void:
	queue_redraw()
