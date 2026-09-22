extends ColorRect
## The sea behind the map (spec ui-foundation.md §7.6).
##
## It sits on its own `CanvasLayer` below the map, which does not follow the
## camera — so the parallax is computed here and sent to the shader, rather than
## being a transform the engine applies. That is what makes it a *parallax*: the
## backdrop moves at 85 % of the map's speed.
##
## The camera is not named at all. The viewport's canvas transform is what the
## camera writes, and reading it keeps the backdrop working in a scene that has
## no camera — and in the test suite, where it must not need one.
##
## Scene-specific, so no `class_name`.

## §7.6: how much of the camera's movement the backdrop takes. 1 would glue it
## to the map, 0 would nail it to the screen.
const PARALLAX: float = 0.85
## How much the grid widens over the whole zoom range, per unit of zoom above
## `zoom_min`.
const ZOOM_SCALE_GAIN: float = 0.5

## §7.6's metrics, in logical screen pixels. The shader has none of its own.
const GRID_SPACING_PX: float = 64.0
const GRID_LINE_PX: float = 1.0
const STAR_CELL_PX: float = 96.0
const STAR_CHANCE: float = 0.35
const STAR_RADIUS_MIN: float = 0.5
const STAR_RADIUS_MAX: float = 1.0

const PARAM_VIEW_SIZE: String = "view_size"
const PARAM_GRID_OFFSET: String = "grid_offset"
const PARAM_GRID_SCALE: String = "grid_scale"

## Uniform → token, so the backdrop's palette has exactly one source.
## Uniform → the token it takes its colour from (m3-screens §6.2).
const COLOR_TOKENS: Dictionary[String, StringName] = {
	"bg": &"BG_0",
	"grid_color": &"BACKDROP_GRID",
	"star_color": &"BACKDROP_STAR",
}

## Uniform → metric, for the same reason.
const METRIC_PARAMS: Dictionary[String, float] = {
	"grid_spacing": GRID_SPACING_PX,
	"grid_line": GRID_LINE_PX,
	"star_cell": STAR_CELL_PX,
	"star_chance": STAR_CHANCE,
	"star_radius_min": STAR_RADIUS_MIN,
	"star_radius_max": STAR_RADIUS_MAX,
}

var _shader: ShaderMaterial = null
var _last_offset: Vector2 = Vector2.INF
var _last_scale: float = -1.0
var _last_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shader = material as ShaderMaterial
	if _shader == null:
		push_error("backdrop: the scene must carry the backdrop shader material")
		return
	_send_colours()
	EventBus.theme_variant_changed.connect(_on_theme_variant_changed)
	for param: String in METRIC_PARAMS:
		_shader.set_shader_parameter(param, METRIC_PARAMS[param])
	_apply()


func _process(_delta: float) -> void:
	_apply()


func _send_colours() -> void:
	for param: String in COLOR_TOKENS:
		_shader.set_shader_parameter(param, UiTokens.color(COLOR_TOKENS[param]))


func _on_theme_variant_changed(_variant: StringName) -> void:
	if _shader != null:
		_send_colours()


## The parallax offset and the grid's scale for a camera view. Static and pure:
## §7.6's two rules, and the two things reduced motion changes about them.
static func shader_values(center: Vector2, zoom_level: float, view_size: Vector2,
		reduced_motion: bool) -> Array:
	if reduced_motion:
		# Reduced motion keeps the backdrop with the map rather than behind it:
		# no lag, no breathing.
		return [center, 1.0]
	var zoom_min: float = MapCamera.zoom_min_for(view_size)
	return [center * PARALLAX, 1.0 + maxf(zoom_level - zoom_min, 0.0) * ZOOM_SCALE_GAIN]


## Centre and zoom of whatever camera is driving the viewport. Identity — no
## camera — reads as "the top-left corner at zoom 1", which is exactly what an
## untransformed canvas shows.
static func view_from_canvas(canvas: Transform2D, view_size: Vector2) -> Array:
	var zoom_level: float = canvas.get_scale().x
	if zoom_level <= 0.0:
		return [Vector2.ZERO, 1.0]
	return [(view_size * 0.5 - canvas.origin) / zoom_level, zoom_level]


func _apply() -> void:
	if _shader == null:
		return
	var view_size: Vector2 = get_viewport_rect().size
	var view: Array = view_from_canvas(get_viewport().get_canvas_transform(), view_size)
	var center: Vector2 = view[0]
	var values: Array = shader_values(
		center, float(view[1]), view_size, Settings.reduced_motion)
	var offset: Vector2 = values[0]
	var grid_scale: float = float(values[1])
	if offset == _last_offset and is_equal_approx(grid_scale, _last_scale) \
			and view_size == _last_size:
		return
	_last_offset = offset
	_last_scale = grid_scale
	_last_size = view_size
	_shader.set_shader_parameter(PARAM_VIEW_SIZE, view_size)
	_shader.set_shader_parameter(PARAM_GRID_OFFSET, offset)
	_shader.set_shader_parameter(PARAM_GRID_SCALE, grid_scale)
