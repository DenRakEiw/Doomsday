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
## width beside the text.

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

var _texture: TextureRect = null
var _glyph: GlyphIcon = null
var _illustration: String = ""


func _ready() -> void:
	theme_type_variation = &"IllustrationSlot"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_apply_size()


## The path an illustration id is looked for at.
func path_for(illustration: String) -> String:
	return root.path_join(illustration + EXTENSION)


## Shows `illustration` when its file exists, else `fallback` in `color_token`.
func show_illustration(illustration: String, fallback: Glyphs.Glyph,
		color_token: StringName = &"TEXT_2") -> void:
	_build()
	_illustration = illustration
	var path: String = path_for(illustration)
	var texture: Texture2D = null
	if not illustration.is_empty() and ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	_texture.texture = texture
	_texture.visible = texture != null
	_glyph.visible = texture == null
	_glyph.glyph = fallback
	_glyph.color_token = color_token


## Whether a picture is on show rather than the glyph, for the tests.
func has_picture() -> bool:
	return _texture != null and _texture.visible


func fallback_glyph() -> GlyphIcon:
	return _glyph


func _build() -> void:
	if _texture != null:
		return
	_texture = TextureRect.new()
	_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_texture.visible = false
	_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_texture)
	var centre: CenterContainer = CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_glyph = GlyphIcon.new()
	_glyph.box_size = FALLBACK_SIZE
	centre.add_child(_glyph)


func _apply_size() -> void:
	if compact:
		custom_minimum_size = Vector2(0.0, WIDTH * ASPECT)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		custom_minimum_size = Vector2(WIDTH, WIDTH * ASPECT)
		size_flags_horizontal = Control.SIZE_FILL
	# 4 : 3 beside a text column that may be taller than the picture.
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
