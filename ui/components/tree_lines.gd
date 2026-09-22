class_name TreeLines
extends Control
## The prerequisite edges of one tree tab (spec m3-screens.md §3.5).
##
## Only edges inside the shown tab are drawn: a prerequisite in another tree is
## the node's EXTERNAL glyph and a row in the detail pane, not a line to
## somewhere off-screen.
##
## The control sits under the grid and holds no nodes; the modal hands it the
## cells and redraws it after every state change.

## One edge, as the board hands it over.
class Edge extends RefCounted:
	var from: Vector2i
	var to: Vector2i
	var dashed: bool
	var from_owned: bool
	var to_owned: bool
	var selected: bool

	func _init(p_from: Vector2i, p_to: Vector2i, p_dashed: bool) -> void:
		from = p_from
		to = p_to
		dashed = p_dashed


var _edges: Array[Edge] = []
## Cells that get the white ring of §3.5 — the prerequisites of the selection.
var _rings: Array[Vector2i] = []
var _cell: Vector2 = UiTokens.TECH_CELL
var _gap: Vector2 = Vector2(float(UiTokens.SPACE_3), float(UiTokens.SPACE_3))


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The geometry of the grid beside it: one cell, and the gap between two.
func layout(cell: Vector2, gap: Vector2) -> void:
	_cell = cell
	_gap = gap
	queue_redraw()


func set_edges(edges: Array[Edge], rings: Array[Vector2i]) -> void:
	_edges = edges
	_rings = rings
	queue_redraw()


## A new `Edge`, so that a caller does not have to name the inner class.
static func edge(from: Vector2i, to: Vector2i, dashed: bool) -> Edge:
	return Edge.new(from, to, dashed)


## Where a cell sits, in this control's own coordinates.
func cell_rect(cell: Vector2i) -> Rect2:
	var step: Vector2 = _cell + _gap
	return Rect2(Vector2(float(cell.x) * step.x, float(cell.y) * step.y), _cell)


func _draw() -> void:
	# The selected node's edges are drawn last so that they lie over the rest.
	for edge_item: Edge in _edges:
		if not edge_item.selected:
			_draw_edge(edge_item)
	for edge_item: Edge in _edges:
		if edge_item.selected:
			_draw_edge(edge_item)
	for cell: Vector2i in _rings:
		_draw_ring(cell)


func _draw_edge(item: Edge) -> void:
	var ends: Array[Vector2] = endpoints(cell_rect(item.from), cell_rect(item.to))
	var width: float = UiTokens.TECH_LINE_SELECTED if item.selected else UiTokens.TECH_LINE
	var colour: Color = _edge_colour(item)
	if item.dashed:
		_draw_dashed(ends[0], ends[1], colour, width)
		return
	draw_line(ends[0], ends[1], colour, width)


## Both owned is a road already taken; one owned is a road open; neither is a
## line the player cannot walk yet (§3.5).
func _edge_colour(item: Edge) -> Color:
	if item.selected:
		return UiTokens.MAP_SELECT
	if item.from_owned and item.to_owned:
		return UiTokens.ACCENT
	if item.from_owned:
		return UiTokens.ACCENT_DIM
	return UiTokens.LINE_1


## Right side to left side across columns, facing sides within one column. The
## first point belongs to `from`, whichever way round the two cells lie.
static func endpoints(from: Rect2, to: Rect2) -> Array[Vector2]:
	if not is_equal_approx(from.position.x, to.position.x):
		var rightwards: bool = from.position.x < to.position.x
		return [
			Vector2(from.end.x if rightwards else from.position.x, from.get_center().y),
			Vector2(to.position.x if rightwards else to.end.x, to.get_center().y),
		]
	var downwards: bool = from.position.y < to.position.y
	return [
		Vector2(from.get_center().x, from.end.y if downwards else from.position.y),
		Vector2(to.get_center().x, to.position.y if downwards else to.end.y),
	]


func _draw_dashed(from: Vector2, to: Vector2, colour: Color, width: float) -> void:
	var total: float = from.distance_to(to)
	if total <= 0.0:
		return
	var step: Vector2 = (to - from) / total
	var period: float = UiTokens.TECH_DASH.x + UiTokens.TECH_DASH.y
	var travelled: float = 0.0
	while travelled < total:
		var dash_end: float = minf(travelled + UiTokens.TECH_DASH.x, total)
		draw_line(from + step * travelled, from + step * dash_end, colour, width)
		travelled += period


## The prerequisites of the selection are ringed rather than recoloured: the
## line already says which way the dependency runs.
func _draw_ring(cell: Vector2i) -> void:
	var rect: Rect2 = cell_rect(cell).grow(float(UiTokens.SPACE_1))
	draw_rect(rect, UiTokens.MAP_SELECT, false, float(UiTokens.BORDER_FOCUS))
