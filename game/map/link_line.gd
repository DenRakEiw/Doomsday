class_name LinkLine
extends Node2D
## One link on the map (spec ui-foundation.md §7.8): the geometry of its kind,
## the state it is in, and the `Line2D`s that draw it.
##
## Everything geometric is a static function over plain values — a link's shape
## depends on two anchors and a kind, not on a node — so the edge-crossing rule
## of world.md §5.4 can be checked without a viewport.
##
## Sizes here are **screen** pixels and are divided by the zoom before they reach
## the canvas: a link is a hairline on the world, not a road, and it has to stay
## one at every zoom. The node itself sits at the origin of the map's own
## coordinates, so the points are ID-map pixels.

## The map, in map pixels. Restated from `MapCamera` rather than read off the
## quad, for the reason `MapCamera` states: two classes that name each other
## cannot be resolved.
const MAP_WIDTH: float = MapCamera.MAP_WIDTH
## Farther apart than this and the short way round is across the edge.
const HALF_MAP: float = MAP_WIDTH * 0.5

## §7.8's widths, in screen pixels.
const WIDTH_PX: float = 2.0
const NETWORK_WIDTH_PX: float = 1.0
## How far apart the two lines of a network link run.
const NETWORK_GAP_PX: float = 3.0

## `[dash, gap]` per kind, in screen pixels. A gap of 0 is a solid line.
const DASH_SEA: Vector2 = Vector2(8.0, 6.0)
const DASH_AIR: Vector2 = Vector2(2.0, 6.0)

## §7.8: an air link bulges perpendicular to its chord by this share of its
## length, toward the top of the map.
const ARC_BULGE: float = 0.12
## Segments the arc is sampled into. Enough that the dot pattern reads as a
## curve and few enough that 69 authored links cost nothing.
const ARC_SEGMENTS: int = 24

## The bright segment a flowing solid link carries, and what the rest of it is
## worth while it does: brightness is what §7.8 asks for, and over this ground a
## dimmed accent with a lit head reads as a pulse running along the line.
const BRIGHT_PX: float = 24.0
const FLOW_SOLID_BASE_ALPHA: float = 0.55

## §7.8's closed link: a gap at the midpoint with a cross in it.
const CLOSED_HOLE_PX: float = 12.0
const CLOSED_CROSS_PX: float = 8.0

const PARAM_LENGTH: String = "length_px"
const PARAM_DASH: String = "dash_px"
const PARAM_GAP: String = "gap_px"
const PARAM_OFFSET: String = "offset_px"
const PARAM_BRIGHT: String = "bright_px"
const PARAM_BASE_ALPHA: String = "base_alpha"
const PARAM_HOLE: String = "hole_px"

const SHADER: Shader = preload("res://game/map/link.gdshader")

## A `Line2D` only generates the UVs the shader needs when it has a texture, and
## the shader never samples it — one white pixel, shared by every link.
static var _white: ImageTexture = null

## `LinkDef.KIND_*`. Public so that the layer can group by it.
var kind: String = LinkDef.KIND_LAND

var _open: bool = true
## The colour of whatever is holding the link shut; transparent when
## nothing is (§16.4).
var _closed_color: Color = Color(0.0, 0.0, 0.0, 0.0)
var _flowing: bool = false
## Which way the pattern travels: a → b, or back.
var _forward: bool = true
## How far the pattern has travelled, in screen pixels.
var _offset: float = 0.0
var _zoom: float = 1.0

## The shapes of §7.8: one, or two when the link crosses the map edge.
var _polylines: Array[PackedVector2Array] = []
## Their lengths in map pixels, and the midpoint a closed link is broken at.
var _lengths: Array[float] = []
var _midpoints: PackedVector2Array = PackedVector2Array()

var _lines: Array[Line2D] = []
## Which polyline each line draws, and how far it is offset from it (screen px).
var _line_shape: Array[int] = []
var _line_offset: Array[float] = []


# ------------------------------------------------------------- pure geometry


## The shapes a link between two anchors is drawn as: one, or **two** when the
## anchors are more than half a map apart (world.md §5.4). The second is the
## first shifted by a whole map width, so the line leaves through one edge and
## re-enters through the other; the camera never shows more than the map's own
## rectangle, which is what clips them.
##
## Both shapes run from `a` to `b`, so the flow direction survives the shift.
static func polylines(a: Vector2, b: Vector2, link_kind: String) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	if absf(a.x - b.x) <= HALF_MAP:
		result.append(shape(a, b, link_kind))
		return result
	var shift: Vector2 = Vector2(MAP_WIDTH, 0.0)
	if a.x > b.x:
		result.append(shape(a - shift, b, link_kind))
		result.append(shape(a, b + shift, link_kind))
	else:
		result.append(shape(a, b - shift, link_kind))
		result.append(shape(a + shift, b, link_kind))
	return result


## One shape: a straight line, or the arc an air link flies.
static func shape(a: Vector2, b: Vector2, link_kind: String) -> PackedVector2Array:
	if link_kind == LinkDef.KIND_AIR:
		return arc_points(a, b)
	return PackedVector2Array([a, b])


## A quadratic arc from `a` to `b`, bulging toward the top of the map.
static func arc_points(a: Vector2, b: Vector2) -> PackedVector2Array:
	var chord: Vector2 = b - a
	var length: float = chord.length()
	if length <= 0.0:
		return PackedVector2Array([a, b])
	# The perpendicular that points up. Which of the two it is depends on the
	# order of the endpoints, and a link has no order worth drawing.
	var normal: Vector2 = Vector2(chord.y, -chord.x) / length
	if normal.y > 0.0:
		normal = -normal
	var control: Vector2 = (a + b) * 0.5 + normal * length * ARC_BULGE
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(ARC_SEGMENTS + 1):
		var t: float = float(i) / float(ARC_SEGMENTS)
		var inv: float = 1.0 - t
		points.append(a * inv * inv + control * 2.0 * inv * t + b * t * t)
	return points


## The same shape moved sideways by `distance`, for the two lines of a network
## link. The offset follows the shape's overall direction, which is all a
## straight line has — no other kind is ever offset.
static func offset_polyline(points: PackedVector2Array, distance: float) -> PackedVector2Array:
	if points.size() < 2:
		return points
	var direction: Vector2 = points[points.size() - 1] - points[0]
	if direction.length() <= 0.0:
		return points
	var normal: Vector2 = Vector2(direction.y, -direction.x).normalized() * distance
	var moved: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points:
		moved.append(point + normal)
	return moved


## The point half way along the shape — where the shader takes the gap of a
## closed link out, so the cross has to be drawn at exactly the same place.
static func midpoint_of(points: PackedVector2Array) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var half: float = polyline_length(points) * 0.5
	var travelled: float = 0.0
	for i: int in range(1, points.size()):
		var segment: float = points[i].distance_to(points[i - 1])
		if travelled + segment >= half:
			if segment <= 0.0:
				return points[i - 1]
			return points[i - 1].lerp(points[i], (half - travelled) / segment)
		travelled += segment
	return points[points.size() - 1]


static func polyline_length(points: PackedVector2Array) -> float:
	var total: float = 0.0
	for i: int in range(1, points.size()):
		total += points[i].distance_to(points[i - 1])
	return total


## The dash pattern of a kind, `[dash, gap]` in screen pixels; a zero gap is a
## solid line.
static func dash_of(link_kind: String) -> Vector2:
	match link_kind:
		LinkDef.KIND_SEA:
			return DASH_SEA
		LinkDef.KIND_AIR:
			return DASH_AIR
	return Vector2.ZERO


static func width_of(link_kind: String) -> float:
	return NETWORK_WIDTH_PX if link_kind == LinkDef.KIND_NETWORK else WIDTH_PX


## §7.8's rest, flow and closed colours — and, from S4.2, the colour of
## whatever is holding a link closed (`loop-mechanics.md` §16.4). A link nothing
## holds shut is closed by the world itself and keeps the old muted line.
static func color_for(open: bool, flowing: bool,
		closed_color: Color = Color(0, 0, 0, 0)) -> Color:
	if not open:
		return UiTokens.color(&"LINE_2") if closed_color.a <= 0.0 else closed_color
	return UiTokens.color(&"ACCENT") if flowing else UiTokens.color(&"ACCENT_DIM")


# ------------------------------------------------------------------- the node


## Builds the link between two anchors. Called once; everything after it is a
## state change on the lines this made.
func setup(anchor_a: Vector2, anchor_b: Vector2, link_kind: String) -> void:
	kind = link_kind
	_polylines = polylines(anchor_a, anchor_b, link_kind)
	_lengths.clear()
	_midpoints = PackedVector2Array()
	for points: PackedVector2Array in _polylines:
		_lengths.append(polyline_length(points))
		_midpoints.append(midpoint_of(points))
	_build_lines()
	apply_zoom(_zoom)
	_apply_state()


## Whether the link is drawn at all. §7.8's visibility rule lives in the layer,
## which is the only place that can see both endpoints.
func set_drawn(drawn: bool) -> void:
	visible = drawn


## For ten days after a region was seeded across it (§7.8). `forward` is the
## direction of that seeding: true when it ran from the first anchor to the
## second.
func set_flowing(flowing: bool, forward: bool) -> void:
	if flowing == _flowing and forward == _forward:
		return
	_flowing = flowing
	_forward = forward
	# Only a flowing line has anything to do per frame, and most of them never
	# flow: 151 idle `_process` calls a frame is a cost with no picture.
	set_process(flowing)
	if not flowing:
		_offset = 0.0
		_push_offset()
	_apply_state()


## Nothing closes a link in M2; from S4.2 a status does, and the gallery shows
## what it looks like.
func set_open(is_open: bool) -> void:
	if is_open == _open:
		return
	_open = is_open
	_apply_state()
	queue_redraw()


## §16.4: the colour of the status holding this link shut, or a transparent
## colour when nothing is — which is the muted line it always had.
func set_closed_color(color: Color) -> void:
	if color == _closed_color:
		return
	_closed_color = color
	_apply_state()
	queue_redraw()


## The colour a closed line is drawn in, for the tests.
func closed_color() -> Color:
	return _closed_color


func is_flowing() -> bool:
	return _flowing


## Which way the pattern travels — a → b, or back.
func is_forward() -> bool:
	return _forward


## Keeps the line's width, its pattern and — for a network link — the distance
## between its two lines at their screen size.
func apply_zoom(zoom_level: float) -> void:
	_zoom = maxf(zoom_level, 0.001)
	for i: int in _lines.size():
		var shape_index: int = _line_shape[i]
		var base: PackedVector2Array = _polylines[shape_index]
		var sideways: float = _line_offset[i]
		var line: Line2D = _lines[i]
		line.points = base if is_zero_approx(sideways) \
			else offset_polyline(base, sideways / _zoom)
		line.width = width_of(kind) / _zoom
		_set_param(line, PARAM_LENGTH, _lengths[shape_index] * _zoom)
	queue_redraw()


func _ready() -> void:
	set_process(_flowing)
	# The palette can change mid-run (m3-screens §6.2); a drawn colour is not
	# a theme item and has to be asked for again.
	EventBus.theme_variant_changed.connect(_on_theme_variant_changed)


func _on_theme_variant_changed(_variant: StringName) -> void:
	queue_redraw()


func _process(delta: float) -> void:
	advance_flow(delta)


## Moves the pattern along. Reduced motion stops it where it is — §3.4: links do
## not flow — while the colour still says that something crossed here.
func advance_flow(delta: float) -> void:
	if not _flowing or not _open or UiTokens.reduced_motion():
		return
	_offset += delta * UiTokens.LINK_FLOW_SPEED * (1.0 if _forward else -1.0)
	_push_offset()


## §7.8's broken link: the shader takes the gap out of the line, and the cross
## that marks it is drawn here, at the screen size the gap has.
func _draw() -> void:
	if _open:
		return
	var arm: float = CLOSED_CROSS_PX * 0.5 / _zoom
	var stroke: float = WIDTH_PX / _zoom
	# The cross takes the status's colour too: what closed the link and the mark
	# that says it is closed must not disagree (§16.4).
	var mark: Color = UiTokens.color(&"ALERT") if _closed_color.a <= 0.0 else _closed_color
	for point: Vector2 in _midpoints:
		draw_line(point + Vector2(-arm, -arm), point + Vector2(arm, arm), mark, stroke)
		draw_line(point + Vector2(-arm, arm), point + Vector2(arm, -arm), mark, stroke)


func _build_lines() -> void:
	for line: Line2D in _lines:
		line.queue_free()
	_lines.clear()
	_line_shape.clear()
	_line_offset.clear()
	# §7.8: a network link runs as two thin lines side by side; every other kind
	# is one line per shape.
	var offsets: Array[float] = [0.0]
	if kind == LinkDef.KIND_NETWORK:
		offsets = [-NETWORK_GAP_PX * 0.5, NETWORK_GAP_PX * 0.5]
	for shape_index: int in _polylines.size():
		for sideways: float in offsets:
			_lines.append(_make_line())
			_line_shape.append(shape_index)
			_line_offset.append(sideways)


func _make_line() -> Line2D:
	var line: Line2D = Line2D.new()
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_NONE
	line.end_cap_mode = Line2D.LINE_CAP_NONE
	line.antialiased = false
	# Stretch over one white pixel: the texture is never seen, it is what makes
	# the line carry a UV the pattern can be measured against.
	line.texture = _white_texture()
	line.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	var shader_material: ShaderMaterial = ShaderMaterial.new()
	shader_material.shader = SHADER
	var dash: Vector2 = dash_of(kind)
	shader_material.set_shader_parameter(PARAM_DASH, dash.x)
	shader_material.set_shader_parameter(PARAM_GAP, dash.y)
	line.material = shader_material
	add_child(line)
	return line


## Colour, brightness and the broken midpoint — everything the state decides.
func _apply_state() -> void:
	var color: Color = color_for(_open, _flowing, _closed_color)
	var solid: bool = dash_of(kind).y <= 0.0
	var bright: float = BRIGHT_PX if _flowing and _open and solid else 0.0
	var base_alpha: float = FLOW_SOLID_BASE_ALPHA if bright > 0.0 else 1.0
	var hole: float = 0.0 if _open else CLOSED_HOLE_PX
	for line: Line2D in _lines:
		line.default_color = color
		_set_param(line, PARAM_BRIGHT, bright)
		_set_param(line, PARAM_BASE_ALPHA, base_alpha)
		_set_param(line, PARAM_HOLE, hole)


func _push_offset() -> void:
	for line: Line2D in _lines:
		_set_param(line, PARAM_OFFSET, _offset)


func _set_param(line: Line2D, param: String, value: Variant) -> void:
	var shader_material: ShaderMaterial = line.material as ShaderMaterial
	if shader_material != null:
		shader_material.set_shader_parameter(param, value)


static func _white_texture() -> ImageTexture:
	if _white == null:
		var image: Image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(image)
	return _white
