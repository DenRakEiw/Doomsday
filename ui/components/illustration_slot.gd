class_name IllustrationSlot
extends PanelContainer
## The picture beside a wire card or the discovery modal
## (`loop-mechanics.md` §16.7).
##
## M6 supplies the pictures; until then the slot shows a glyph, drawn large in
## `TEXT_2` on a `BG_2` ground. A picture is taken from
## `assets/illustrations/<id>.png` only when the file exists, so dropping one in
## is all M6 has to do.
##
## 4 : 3. `compact` stretches it to the column's width instead of the fixed
## width beside the text, and keeps 4 : 3 by following that width with its
## height (`illustrations.md` §8.1) — a fixed height cropped the picture to a
## strip at wide compact widths.

const ROOT: String = "res://assets/illustrations"
const EXTENSION: String = ".png"
const WIDTH: float = 280.0
const ASPECT: float = 0.75
const FALLBACK_SIZE: float = 96.0

## Where pictures are looked for. A test points it at a folder that has one.
var root: String = ROOT

var compact: bool = false:
	set(value):
		compact = value
		_apply_size()

## The width of the full layout (§8.1): 280 beside a card's text, 420 on the
## results screen. Compact ignores it and takes the column's width.
var width: float = WIDTH:
	set(value):
		width = value
		_apply_size()

var _texture: TextureRect = null
var _glyph: GlyphIcon = null
## icons.md §7: a counter-move without a picture shows its icon file instead of
## the glyph, when one resolves.
var _icon: IconRect = null
var _illustration: String = ""


func _ready() -> void:
	theme_type_variation = &"IllustrationSlot"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_apply_size()
	resized.connect(_on_resized)


## The path an illustration id is looked for at.
func path_for(illustration: String) -> String:
	return root.path_join(illustration + EXTENSION)


## Whether a picture for `illustration` ships under `root` — the results screen
## and the Codex show no slot at all without one (§8.3).
func has_file(illustration: String) -> bool:
	return not illustration.is_empty() and ResourceLoader.exists(path_for(illustration))


## Shows `illustration` when its file exists, else the icon `icon_id` of
## `icon_kind` when one resolves, else `fallback` — both in `color_token`.
func show_illustration(illustration: String, fallback: Glyphs.Glyph,
		color_token: StringName = &"TEXT_2", icon_kind: StringName = &"",
		icon_id: String = "") -> void:
	_build()
	_illustration = illustration
	var texture: Texture2D = null
	if has_file(illustration):
		texture = load(path_for(illustration)) as Texture2D
	_texture.texture = texture
	_texture.visible = texture != null
	_icon.show_icon(icon_kind, icon_id)
	_icon.color_token = color_token
	_icon.visible = texture == null and _icon.visible
	_glyph.visible = texture == null and not _icon.visible
	_glyph.glyph = fallback
	_glyph.color_token = color_token


## Whether a picture is on show rather than the glyph, for the tests.
func has_picture() -> bool:
	return _texture != null and _texture.visible


func fallback_glyph() -> GlyphIcon:
	return _glyph


## The icon shown in place of the glyph, for the tests.
func fallback_icon() -> IconRect:
	return _icon


func _build() -> void:
	if _texture != null:
		return
	_texture = TextureRect.new()
	_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# §8.1: every draw is a downscale of the 1120 × 840 source, and the imported
	# mipmaps are only sampled with this filter — without it a ¼ draw aliases.
	_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_texture.visible = false
	_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_texture)
	var centre: CenterContainer = CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_glyph = GlyphIcon.new()
	_glyph.box_size = FALLBACK_SIZE
	centre.add_child(_glyph)
	_icon = IconRect.new()
	_icon.box_size = float(UiTokens.ICON_HERO)
	_icon.visible = false
	centre.add_child(_icon)


func _apply_size() -> void:
	if compact:
		# Until the first layout pass gives it a width, the full layout's height.
		var height: float = size.x * ASPECT if size.x > 0.0 else width * ASPECT
		custom_minimum_size = Vector2(0.0, height)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		custom_minimum_size = Vector2(width, width * ASPECT)
		# Beside a card's text this is the same as filling; in a column (the
		# results, the Codex) it keeps the slot at its width instead of
		# stretching it across and cropping the picture.
		size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	# 4 : 3 beside a text column that may be taller than the picture.
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func _on_resized() -> void:
	if compact and not is_equal_approx(custom_minimum_size.y, size.x * ASPECT):
		_apply_size()
