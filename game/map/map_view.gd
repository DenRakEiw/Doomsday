class_name MapView
extends Sprite2D
## The world map (spec ui-foundation.md §7.1–§7.3): the quad that `map.gdshader`
## paints, and the data texture it paints from.
##
## The node is the ID map at 1 : 1 and uncentred, so one map pixel is one world
## unit and the top-left corner is the origin — `MapPicker` (S2.3) turns a screen
## point into a region index on that assumption.
##
## Everything this script owns is presentation. It reads `Game.sim.world` after a
## tick and writes 256 pixels; it never touches the simulation.
##
## It carries a `class_name` although it is a scene script: S2.3's picking and
## S2.6's marker and link layers all have to name the map they belong to, the
## way `MapPicker` names `MapCamera`.

## §7.2 overlays, in the order the picker (S2.5) lists them.
enum Overlay { PENETRATION, CONTROL, POPULATION }

## The ID map's size, in map pixels and world units at scale 1.
const MAP_WIDTH: int = 4096
const MAP_HEIGHT: int = 2048
## §7.5: about 58° S — the empty south is never shown.
const MAP_ROW_MAX: int = 1750

## §7.3's selection outline, in screen pixels.
const OUTLINE_SCREEN_PX: float = 2.0

const PARAM_REGION_DATA: String = "region_data"
const PARAM_RAMP: String = "ramp"
const PARAM_HOVER: String = "hover_index"
const PARAM_SELECTED: String = "selected_index"
const PARAM_OVERLAY: String = "overlay_mode"
const PARAM_OUTLINE: String = "outline_px"
const PARAM_HOVER_GAIN: String = "hover_gain"

## Colour uniform → token, so the shader's palette has exactly one source.
const COLOR_PARAMS: Dictionary[String, Color] = {
	"map_land": UiTokens.MAP_LAND,
	"map_dark": UiTokens.MAP_DARK,
	"map_border": UiTokens.MAP_BORDER,
	"map_border_dark": UiTokens.MAP_BORDER_DARK,
	"map_select": UiTokens.MAP_SELECT,
	"map_death": UiTokens.MAP_DEATH,
}

## 0 means none. Written by S2.3's picking, read by the shader.
var hover_index: int = 0:
	set(value):
		if value == hover_index:
			return
		hover_index = value
		_set_param(PARAM_HOVER, hover_index)

var selected_index: int = 0:
	set(value):
		if value == selected_index:
			return
		selected_index = value
		_set_param(PARAM_SELECTED, selected_index)

## How far the selection outline reaches, in map pixels. §7.5: `MapCamera` keeps
## it at `2 / zoom` so the outline stays about two screen pixels wide. It can
## never be thinner than one ID-map texel — the map has no finer detail — so
## beyond zoom 2 the outline grows with the zoom instead.
var outline_px: float = OUTLINE_SCREEN_PX:
	set(value):
		outline_px = maxf(value, 0.0)
		_set_param(PARAM_OUTLINE, outline_px)

var overlay_mode: Overlay = Overlay.PENETRATION:
	set(value):
		if value == overlay_mode:
			return
		overlay_mode = value
		_set_param(PARAM_OVERLAY, int(overlay_mode))

var _shader: ShaderMaterial = null
var _data_image: Image = null
var _data_texture: ImageTexture = null
## The ID map as an `Image`, read once: `Texture2D.get_image()` copies from the
## GPU and must never happen per frame (§7.4).
var _id_image: Image = null


func _ready() -> void:
	centered = false
	position = Vector2.ZERO
	_shader = material as ShaderMaterial
	if _shader == null:
		push_error("map_view: the scene must carry the map shader material")
		return
	_data_image = RegionData.create_image()
	_data_texture = ImageTexture.create_from_image(_data_image)
	_shader.set_shader_parameter(PARAM_REGION_DATA, _data_texture)
	_shader.set_shader_parameter(PARAM_RAMP, UiTokens.ramp_texture())
	_shader.set_shader_parameter(PARAM_HOVER_GAIN, UiTokens.MAP_HOVER_GAIN)
	for param: String in COLOR_PARAMS:
		_shader.set_shader_parameter(param, COLOR_PARAMS[param])
	_set_param(PARAM_HOVER, hover_index)
	_set_param(PARAM_SELECTED, selected_index)
	_set_param(PARAM_OVERLAY, int(overlay_mode))
	_set_param(PARAM_OUTLINE, outline_px)

	EventBus.run_started.connect(_on_run_started)
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.command_applied.connect(_on_command_applied)
	EventBus.overlay_changed.connect(_on_overlay_changed)
	get_viewport().size_changed.connect(_fit_without_camera)
	_fit_without_camera()
	refresh()


## The ID map as an `Image`, cached. S2.3's picking reads it for every click.
func id_image() -> Image:
	if _id_image == null and texture != null:
		_id_image = texture.get_image()
	return _id_image


## The row the shader draws from (§7.2). Nothing in the game reads it — the test
## suite does: a headless `ImageTexture` hands back the image it was created
## with, never the one `update` uploaded.
func data_image() -> Image:
	return _data_image


## Rewrites the data texture from the current world. Cheap enough to call after
## anything that may have changed a region — 256 pixels and one upload.
func refresh() -> void:
	if _data_image == null:
		return
	if Game.sim == null or Game.db == null:
		_data_image.fill(Color(0.0, 0.0, 0.0, 0.0))
	elif not RegionData.write(_data_image, Game.sim.world, Game.db):
		# §7.2: more regions than the row holds. Drawing would paint regions with
		# one another's numbers, so the map stays blank and says why.
		push_error("map_view: %d regions do not fit the %d-pixel data row"
			% [RegionData.highest_index(Game.sim.world), RegionData.WIDTH])
		return
	# Never a new texture: the shader keeps the one it was given.
	_data_texture.update(_data_image)


func _on_run_started(_seed_value: int) -> void:
	refresh()


func _on_tick_advanced(_day: int) -> void:
	refresh()


func _on_command_applied(_command: Command, result: CommandResult) -> void:
	if result.ok:
		refresh()


func _on_overlay_changed(mode: int) -> void:
	overlay_mode = _overlay_from_int(mode)


func _set_param(param: String, value: Variant) -> void:
	if _shader != null:
		_shader.set_shader_parameter(param, value)


## An int is not an enum in GDScript, so the bus's mode is converted, not cast.
func _overlay_from_int(mode: int) -> Overlay:
	match mode:
		1:
			return Overlay.CONTROL
		2:
			return Overlay.POPULATION
	return Overlay.PENETRATION


## Until S2.3 builds `MapCamera` nothing frames the map, and at scale 1 the
## viewport would show a corner of the Atlantic. This fits the drawn rows into
## the viewport and centres them; it is dropped when the camera arrives.
func _fit_without_camera() -> void:
	if _has_camera():
		return
	var view: Vector2 = get_viewport_rect().size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	var factor: float = minf(view.x / float(MAP_WIDTH), view.y / float(MAP_ROW_MAX))
	scale = Vector2(factor, factor)
	position = Vector2(
		(view.x - float(MAP_WIDTH) * factor) * 0.5,
		(view.y - float(MAP_ROW_MAX) * factor) * 0.5)
	outline_px = OUTLINE_SCREEN_PX / factor


func _has_camera() -> bool:
	var parent: Node = get_parent()
	if parent == null:
		return false
	return not parent.find_children("", "Camera2D", false, false).is_empty()
