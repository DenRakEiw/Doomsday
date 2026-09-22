class_name MapView
extends Sprite2D
## The world map (spec ui-foundation.md §7.1–§7.3): the quad that `map.gdshader`
## paints, and the data texture it paints from.
##
## The node is the ID map at 1 : 1 and uncentred, so one map pixel is one world
## unit and the top-left corner is the origin — `MapPicker` turns a screen point
## into a region index on that assumption.
##
## It is also where a hover and a selection land (§7.4): the camera decides that
## a gesture was a tap, the layers above the map get first refusal, and what is
## left is a region under a point.
##
## Everything this script owns is presentation. It reads `Game.sim.world` after a
## tick and writes 256 pixels; it never touches the simulation.
##
## It carries a `class_name` although it is a scene script: S2.6's marker and
## link layers have to name the map they belong to, the way `MapPicker` names
## `MapCamera`.

## §7.2 overlays, in the order the picker (S2.5) lists them.
enum Overlay { PENETRATION, CONTROL, POPULATION }

## §7.3's selection outline, in screen pixels.
const OUTLINE_SCREEN_PX: float = 2.0

const PARAM_REGION_DATA: String = "region_data"
const PARAM_RAMP: String = "ramp"
const PARAM_HOVER: String = "hover_index"
const PARAM_SELECTED: String = "selected_index"
const PARAM_OVERLAY: String = "overlay_mode"
const PARAM_OUTLINE: String = "outline_px"
const PARAM_HOVER_GAIN: String = "hover_gain"
const PARAM_OVERLAY_MIX: String = "overlay_mix"

## Colour uniform → token, so the shader's palette has exactly one source.
## Uniform → the token it takes its colour from. A function rather than a table
## of colours, because the values follow the palette (m3-screens §6.2).
const COLOR_TOKENS: Dictionary[String, StringName] = {
	"map_land": &"MAP_LAND",
	"map_dark": &"MAP_DARK",
	"map_border": &"MAP_BORDER",
	"map_border_dark": &"MAP_BORDER_DARK",
	"map_select": &"MAP_SELECT",
	"map_death": &"MAP_DEATH",
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
## The sibling that moves the map. Null in a test that instantiates the view on
## its own; the map then draws at 1 : 1 and picks nothing.
var _camera: MapCamera = null


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
	_shader.set_shader_parameter(PARAM_OVERLAY_MIX, UiTokens.MAP_OVERLAY_MIX)
	_send_colours()
	_set_param(PARAM_HOVER, hover_index)
	_set_param(PARAM_SELECTED, selected_index)
	_set_param(PARAM_OVERLAY, int(overlay_mode))
	_set_param(PARAM_OUTLINE, outline_px)

	EventBus.theme_variant_changed.connect(_on_theme_variant_changed)
	EventBus.run_started.connect(_on_run_started)
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.command_applied.connect(_on_command_applied)
	EventBus.overlay_changed.connect(_on_overlay_changed)
	# A selection can also be cleared from the panel (§5.6: the close button and
	# `Escape`), and the outline has to follow it there too.
	EventBus.region_selected.connect(_on_region_selected)
	_camera = MapCamera.find_beside(self)
	if _camera != null:
		_camera.view_changed.connect(_on_camera_view_changed)
		_on_camera_view_changed(_camera.position, _camera.zoom.x)
	refresh()


## Hover follows the pointer (§7.4). Touch has none, and a drag is the camera's,
## not a pass over the land.
func _unhandled_input(event: InputEvent) -> void:
	if _camera == null or OS.has_feature("mobile") or _camera.is_panning():
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion == null:
		return
	var index: int = MapPicker.region_at(motion.position, _camera, id_image())
	if index == hover_index:
		return
	hover_index = index
	EventBus.region_hovered.emit(index)


## The tap the camera offers after the layers above the map have passed on it
## (`MapCamera.TAP_METHOD`). The map is the bottom of that stack and always
## answers: a tap on the ocean deselects.
func try_tap(screen: Vector2) -> bool:
	var index: int = MapPicker.region_at(screen, _camera, id_image())
	if index != selected_index:
		selected_index = index
		EventBus.region_selected.emit(index)
	return true


## The ID map as an `Image`, cached. Picking reads it for every click.
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


## The palette is the shader's too: the land, the borders and the outline are
## drawn there, not here.
func _send_colours() -> void:
	for param: String in COLOR_TOKENS:
		_shader.set_shader_parameter(param, UiTokens.color(COLOR_TOKENS[param]))


func _on_theme_variant_changed(_variant: StringName) -> void:
	if _shader != null:
		_send_colours()


func _on_run_started(_seed_value: int) -> void:
	refresh()


func _on_tick_advanced(_day: int) -> void:
	refresh()


func _on_command_applied(_command: Command, result: CommandResult) -> void:
	if result.ok:
		refresh()


func _on_overlay_changed(mode: int) -> void:
	overlay_mode = _overlay_from_int(mode)


## The selection is the bus's, not the map's: `try_tap` announces one, the region
## panel clears one, and both end here.
func _on_region_selected(index: int) -> void:
	selected_index = index


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


## §7.3's outline is a reach in map pixels, so it has to shrink as the camera
## zooms in to stay two screen pixels wide.
func _on_camera_view_changed(_center: Vector2, zoom_level: float) -> void:
	if zoom_level > 0.0:
		outline_px = OUTLINE_SCREEN_PX / zoom_level
