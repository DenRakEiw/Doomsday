class_name GlyphIcon
extends Control
## One `Glyphs` shape as a `Control`, so a row or a bar can hold an icon without
## a texture (`loop-mechanics.md` §16.3.2, §16.5, §16.9).
##
## The icon file is drawn at `box_size`; the procedural fallback works in a 24 box
## scaled to it — either way a fleet glyph can be 16 px in one row and 12 in
## another.

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
	# icons.md §5.3: the file is made at `box_size`; only the procedural fallback
	# is drawn in the 24 box and scaled.
	Glyphs.draw_scaled(self, glyph, Vector2.ZERO, box_size, UiTokens.color(color_token),
		UiTokens.GLYPH_STROKE)


func _on_theme_variant_changed(_variant: StringName) -> void:
	queue_redraw()
