class_name Glyphs
extends RefCounted
## Every glyph the interface draws, as code (spec ui-foundation.md §4.3,
## m3-screens.md §3.4.1).
##
## M2 shipped no icon assets and M3 ships none either: a glyph is drawn into a
## 24 × 24 box in whatever colour the caller is using, so a button, a tech node
## and a chip can all show the same shape without a texture between them. The
## icon pipeline is M6; until then this file is the whole icon set.
##
## Never instantiated; it is a namespace of shapes.

enum Glyph { PAUSE, PLAY, FAST_2, FAST_4, CLOSE, CHEVRON_LEFT, CHEVRON_RIGHT, CHEVRON_DOWN,
	OVERLAY, CHECK, LOCK, EXTERNAL, MENU, DORMANT, ASSET_FLEET, ASSET_LAB, ASSET_TAP,
	ASSET_OFFICE, EVENT_COUNTER, EVENT_OPENING, EVENT_CHAIN, FACTION_AI_LABS,
	FACTION_GOVERNMENTS, FACTION_RESEARCHERS, FACTION_PUBLIC }

## The names `assets.json` may give as a kind's `glyph`, in `AssetDef.KINDS`
## order. The validator checks against this list, `asset_glyph` turns a name into
## the shape. Placeholders until VISUALS §3.3's icon set (M6).
const ASSET_NAMES: Array[String] = ["ASSET_FLEET", "ASSET_LAB", "ASSET_TAP", "ASSET_OFFICE"]

# ui-foundation §4.3's shapes, in the coordinates of the 24 box.
const PAUSE_BAR: Vector2 = Vector2(6.0, 20.0)
const PAUSE_GAP: float = 4.0
const PLAY_SIZE: Vector2 = Vector2(18.0, 20.0)
const FAST_2_SIZE: Vector2 = Vector2(10.0, 16.0)
const FAST_4_SIZE: Vector2 = Vector2(8.0, 14.0)
const FAST_OVERLAP: float = 2.0
const CLOSE_INSET: float = 4.0
const CHEVRON_DEPTH: float = 12.0
const OVERLAY_SLAB: Vector2 = Vector2(20.0, 4.0)
const OVERLAY_TOPS: Array[float] = [3.0, 10.0, 17.0]

# m3-screens §3.4.1's five.
const CHECK_POINTS: Array[Vector2] = [Vector2(4.0, 13.0), Vector2(10.0, 19.0),
	Vector2(20.0, 6.0)]
const LOCK_BODY: Rect2 = Rect2(5.0, 10.0, 14.0, 10.0)
const LOCK_SHACKLE_WIDTH: float = 10.0
const LOCK_RADIUS: float = 2.0
const EXTERNAL_SQUARE: Rect2 = Rect2(3.0, 9.0, 12.0, 12.0)
const EXTERNAL_FROM: Vector2 = Vector2(11.0, 13.0)
const EXTERNAL_TO: Vector2 = Vector2(21.0, 3.0)
const EXTERNAL_HEAD: float = 6.0
const MENU_SLAB: Vector2 = Vector2(20.0, 2.0)
const MENU_TOPS: Array[float] = [5.0, 11.0, 17.0]
## loop-mechanics §16.3.2: the four asset shapes, all filled, in the 24 box. A
## filled shape reads at 12 px where a stroke does not.
const ASSET_TRIANGLE: Vector2 = Vector2(16.0, 14.0)
const ASSET_DIAMOND: float = 8.0
const ASSET_BAR: Vector2 = Vector2(9.0, 16.0)
const ASSET_DISC: float = 7.0

## loop-mechanics §16.3.2: the three event marks — `!` for a counter-move, a
## stroked diamond (◇) for an opening, `»` for a chain step. Drawn, not typed:
## the fallback font a map node has may not carry the diamond.
const EVENT_BANG_BAR: Rect2 = Rect2(10.5, 3.0, 3.0, 12.0)
const EVENT_BANG_DOT: Rect2 = Rect2(10.5, 18.0, 3.0, 3.0)
const EVENT_DIAMOND: float = 8.0
const EVENT_CHAIN_DEPTH: float = 5.0
const EVENT_CHAIN_GAP: float = 6.0

## The four faction glyphs (opposition.md §9.7), placeholders until the icon set.
const FACTION_HEX_RADIUS: float = 9.0
const FACTION_HEX_SIDES: int = 6
const FACTION_LINTEL: Rect2 = Rect2(3.0, 5.0, 18.0, 0.0)
const FACTION_PILLAR_XS: Array[float] = [6.0, 12.0, 18.0]
const FACTION_PILLAR_TOP: float = 8.0
const FACTION_PILLAR_BOTTOM: float = 20.0
const FACTION_LENS_CENTRE: Vector2 = Vector2(10.0, 10.0)
const FACTION_LENS_RADIUS: float = 6.0
const FACTION_HANDLE_TO: Vector2 = Vector2(20.0, 20.0)
const FACTION_HEADS: Array[Vector2] = [Vector2(5.5, 14.0), Vector2(12.0, 10.0),
	Vector2(18.5, 14.0)]
const FACTION_HEAD_RADIUS: float = 3.5
const DORMANT_RADIUS: float = 8.0
const DORMANT_CUT_RADIUS: float = 6.0
const DORMANT_CUT_OFFSET: Vector2 = Vector2(4.0, -3.0)
## Enough for a circle that is 16 px across to read as a curve, and the quarter
## of it that rounds one corner.
const ARC_SEGMENTS: int = 24
const CORNER_SEGMENTS: int = 6


## Draws `glyph` into `box`. Everything is in the box's own coordinates, so a
## caller only has to decide where the 24 square sits.
static func draw(canvas: CanvasItem, glyph: Glyph, box: Rect2, color: Color,
		stroke: float) -> void:
	match glyph:
		Glyph.PAUSE:
			_pause(canvas, box, color)
		Glyph.PLAY:
			_triangles(canvas, box, 1, PLAY_SIZE, color)
		Glyph.FAST_2:
			_triangles(canvas, box, 2, FAST_2_SIZE, color)
		Glyph.FAST_4:
			_triangles(canvas, box, 3, FAST_4_SIZE, color)
		Glyph.CLOSE:
			_close(canvas, box, color, stroke)
		Glyph.OVERLAY:
			_slabs(canvas, box, OVERLAY_SLAB, OVERLAY_TOPS, color)
		Glyph.MENU:
			_slabs(canvas, box, MENU_SLAB, MENU_TOPS, color)
		Glyph.CHECK:
			_check(canvas, box, color, stroke)
		Glyph.LOCK:
			_lock(canvas, box, color, stroke)
		Glyph.EXTERNAL:
			_external(canvas, box, color, stroke)
		Glyph.DORMANT:
			_dormant(canvas, box, color, stroke)
		Glyph.ASSET_FLEET:
			_asset_triangle(canvas, box, color)
		Glyph.ASSET_LAB:
			_asset_diamond(canvas, box, color)
		Glyph.ASSET_TAP:
			_asset_bar(canvas, box, color)
		Glyph.ASSET_OFFICE:
			canvas.draw_circle(box.get_center(), ASSET_DISC, color)
		Glyph.EVENT_COUNTER:
			canvas.draw_rect(Rect2(_at(box, EVENT_BANG_BAR.position), EVENT_BANG_BAR.size), color)
			canvas.draw_rect(Rect2(_at(box, EVENT_BANG_DOT.position), EVENT_BANG_DOT.size), color)
		Glyph.EVENT_OPENING:
			_event_diamond(canvas, box, color, stroke)
		Glyph.EVENT_CHAIN:
			_event_chain(canvas, box, color, stroke)
		Glyph.FACTION_AI_LABS:
			_faction_hexagon(canvas, box, color, stroke)
		Glyph.FACTION_GOVERNMENTS:
			_faction_pillars(canvas, box, color, stroke)
		Glyph.FACTION_RESEARCHERS:
			canvas.draw_arc(_at(box, FACTION_LENS_CENTRE), FACTION_LENS_RADIUS, 0.0, TAU,
				ARC_SEGMENTS, color, stroke)
			var rim: Vector2 = FACTION_LENS_CENTRE \
				+ (FACTION_HANDLE_TO - FACTION_LENS_CENTRE).normalized() * FACTION_LENS_RADIUS
			canvas.draw_line(_at(box, rim), _at(box, FACTION_HANDLE_TO), color, stroke)
		Glyph.FACTION_PUBLIC:
			for head: Vector2 in FACTION_HEADS:
				canvas.draw_arc(_at(box, head), FACTION_HEAD_RADIUS, 0.0, TAU, ARC_SEGMENTS,
					color, stroke)
		_:
			_chevron(canvas, glyph, box, color, stroke)


## The shape an asset kind's `glyph` name stands for. An unknown name is a
## content error the validator already caught, so it comes back as the disc.
static func asset_glyph(name: String) -> Glyph:
	match ASSET_NAMES.find(name):
		0:
			return Glyph.ASSET_FLEET
		1:
			return Glyph.ASSET_LAB
		2:
			return Glyph.ASSET_TAP
	return Glyph.ASSET_OFFICE


## The mark a map event of this kind carries (§16.3.2): `!` for a counter-move,
## ◇ for an opening, » for a chain step.
static func event_glyph(kind: String) -> Glyph:
	match kind:
		EventDef.KIND_COUNTER_MOVE:
			return Glyph.EVENT_COUNTER
		EventDef.KIND_CHAIN:
			return Glyph.EVENT_CHAIN
	return Glyph.EVENT_OPENING


## The glyph of a faction (opposition.md §9.7). An id that is no faction — a
## world status nobody owns — gets the counter-move's `!`.
static func faction(faction_id: String) -> Glyph:
	match faction_id:
		Faction.ID_AI_LABS:
			return Glyph.FACTION_AI_LABS
		Faction.ID_GOVERNMENTS:
			return Glyph.FACTION_GOVERNMENTS
		Faction.ID_SECURITY_RESEARCHERS:
			return Glyph.FACTION_RESEARCHERS
		Faction.ID_PUBLIC_SENTIMENT:
			return Glyph.FACTION_PUBLIC
	return Glyph.EVENT_COUNTER


## A point of the 24 box in the canvas' coordinates.
static func _at(box: Rect2, point: Vector2) -> Vector2:
	return box.position + point


static func _pause(canvas: CanvasItem, box: Rect2, color: Color) -> void:
	var total: float = PAUSE_BAR.x * 2.0 + PAUSE_GAP
	var left: float = box.position.x + (box.size.x - total) * 0.5
	var top: float = box.position.y + (box.size.y - PAUSE_BAR.y) * 0.5
	for i: int in 2:
		var x: float = left + float(i) * (PAUSE_BAR.x + PAUSE_GAP)
		canvas.draw_rect(Rect2(Vector2(x, top), PAUSE_BAR), color)


## One, two or three triangles pointing right, overlapping by `FAST_OVERLAP`.
static func _triangles(canvas: CanvasItem, box: Rect2, count: int, triangle: Vector2,
		color: Color) -> void:
	var step: float = triangle.x - FAST_OVERLAP
	var total: float = triangle.x + step * float(count - 1)
	var left: float = box.position.x + (box.size.x - total) * 0.5
	var top: float = box.position.y + (box.size.y - triangle.y) * 0.5
	for i: int in count:
		var x: float = left + step * float(i)
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(x, top),
			Vector2(x + triangle.x, top + triangle.y * 0.5),
			Vector2(x, top + triangle.y),
		]), color)


static func _close(canvas: CanvasItem, box: Rect2, color: Color, stroke: float) -> void:
	var a: Vector2 = box.position + Vector2(CLOSE_INSET, CLOSE_INSET)
	var b: Vector2 = box.end - Vector2(CLOSE_INSET, CLOSE_INSET)
	canvas.draw_line(a, b, color, stroke)
	canvas.draw_line(Vector2(b.x, a.y), Vector2(a.x, b.y), color, stroke)


## A two-segment chevron pointing the way its glyph name says.
static func _chevron(canvas: CanvasItem, glyph: Glyph, box: Rect2, color: Color,
		stroke: float) -> void:
	var centre: Vector2 = box.get_center()
	var half: float = CHEVRON_DEPTH * 0.5
	var direction: Vector2 = Vector2.LEFT
	if glyph == Glyph.CHEVRON_RIGHT:
		direction = Vector2.RIGHT
	elif glyph == Glyph.CHEVRON_DOWN:
		direction = Vector2.DOWN
	var across: Vector2 = Vector2(direction.y, direction.x)
	var tip: Vector2 = centre + direction * half
	var back: Vector2 = centre - direction * half
	canvas.draw_line(back + across * CHEVRON_DEPTH, tip, color, stroke)
	canvas.draw_line(back - across * CHEVRON_DEPTH, tip, color, stroke)


static func _slabs(canvas: CanvasItem, box: Rect2, slab: Vector2, tops: Array[float],
		color: Color) -> void:
	var left: float = box.position.x + (box.size.x - slab.x) * 0.5
	for top: float in tops:
		canvas.draw_rect(Rect2(Vector2(left, box.position.y + top), slab), color)


static func _check(canvas: CanvasItem, box: Rect2, color: Color, stroke: float) -> void:
	for i: int in CHECK_POINTS.size() - 1:
		canvas.draw_line(_at(box, CHECK_POINTS[i]), _at(box, CHECK_POINTS[i + 1]), color, stroke)


## A padlock: a rounded body with a semicircular shackle over it.
static func _lock(canvas: CanvasItem, box: Rect2, color: Color, stroke: float) -> void:
	var body: Rect2 = Rect2(_at(box, LOCK_BODY.position), LOCK_BODY.size)
	_rounded_rect(canvas, body, LOCK_RADIUS, color, stroke)
	var centre: Vector2 = Vector2(body.get_center().x, body.position.y)
	canvas.draw_arc(centre, LOCK_SHACKLE_WIDTH * 0.5, PI, TAU, ARC_SEGMENTS, color, stroke)


## A square with an arrow leaving it: "this one lives in another tab".
static func _external(canvas: CanvasItem, box: Rect2, color: Color, stroke: float) -> void:
	_rounded_rect(canvas, Rect2(_at(box, EXTERNAL_SQUARE.position), EXTERNAL_SQUARE.size),
		LOCK_RADIUS, color, stroke)
	var from: Vector2 = _at(box, EXTERNAL_FROM)
	var to: Vector2 = _at(box, EXTERNAL_TO)
	canvas.draw_line(from, to, color, stroke)
	var back: Vector2 = (from - to).normalized() * EXTERNAL_HEAD
	canvas.draw_line(to, to + back.rotated(PI * 0.25), color, stroke)
	canvas.draw_line(to, to + back.rotated(-PI * 0.25), color, stroke)


## A crescent: one circle with a second one cut out of it, drawn as two arcs so
## that it stays a stroke like every other glyph.
static func _dormant(canvas: CanvasItem, box: Rect2, color: Color, stroke: float) -> void:
	var centre: Vector2 = box.get_center()
	canvas.draw_arc(centre, DORMANT_RADIUS, PI * 0.5, PI * 1.5, ARC_SEGMENTS, color, stroke)
	canvas.draw_arc(centre + DORMANT_CUT_OFFSET, DORMANT_CUT_RADIUS, PI * 0.5, PI * 1.5,
		ARC_SEGMENTS, color, stroke)


static func _asset_triangle(canvas: CanvasItem, box: Rect2, color: Color) -> void:
	var centre: Vector2 = box.get_center()
	var half: Vector2 = ASSET_TRIANGLE * 0.5
	canvas.draw_colored_polygon(PackedVector2Array([
		centre + Vector2(0.0, -half.y),
		centre + Vector2(half.x, half.y),
		centre + Vector2(-half.x, half.y),
	]), color)


static func _asset_diamond(canvas: CanvasItem, box: Rect2, color: Color) -> void:
	var centre: Vector2 = box.get_center()
	canvas.draw_colored_polygon(PackedVector2Array([
		centre + Vector2(0.0, -ASSET_DIAMOND),
		centre + Vector2(ASSET_DIAMOND, 0.0),
		centre + Vector2(0.0, ASSET_DIAMOND),
		centre + Vector2(-ASSET_DIAMOND, 0.0),
	]), color)


static func _asset_bar(canvas: CanvasItem, box: Rect2, color: Color) -> void:
	canvas.draw_rect(Rect2(box.get_center() - ASSET_BAR * 0.5, ASSET_BAR), color)


static func _event_diamond(canvas: CanvasItem, box: Rect2, color: Color, stroke: float) -> void:
	var centre: Vector2 = box.get_center()
	canvas.draw_polyline(PackedVector2Array([
		centre + Vector2(0.0, -EVENT_DIAMOND),
		centre + Vector2(EVENT_DIAMOND, 0.0),
		centre + Vector2(0.0, EVENT_DIAMOND),
		centre + Vector2(-EVENT_DIAMOND, 0.0),
		centre + Vector2(0.0, -EVENT_DIAMOND),
	]), color, stroke)


## Two small chevrons pointing right, side by side.
static func _event_chain(canvas: CanvasItem, box: Rect2, color: Color, stroke: float) -> void:
	var centre: Vector2 = box.get_center()
	for i: int in 2:
		var tip: Vector2 = centre + Vector2(EVENT_CHAIN_DEPTH + float(i) * EVENT_CHAIN_GAP
			- EVENT_CHAIN_GAP * 0.5, 0.0) - Vector2(EVENT_CHAIN_DEPTH * 0.5, 0.0)
		canvas.draw_line(tip + Vector2(-EVENT_CHAIN_DEPTH, -EVENT_CHAIN_DEPTH), tip, color, stroke)
		canvas.draw_line(tip + Vector2(-EVENT_CHAIN_DEPTH, EVENT_CHAIN_DEPTH), tip, color, stroke)


## A hexagon outline, pointy side up.
static func _faction_hexagon(canvas: CanvasItem, box: Rect2, color: Color, stroke: float) -> void:
	var centre: Vector2 = box.get_center()
	var points: PackedVector2Array = []
	# One point more than sides, so the outline closes on itself.
	for i: int in FACTION_HEX_SIDES + 1:
		var angle: float = -PI * 0.5 + TAU * float(i) / float(FACTION_HEX_SIDES)
		points.append(centre + Vector2(cos(angle), sin(angle)) * FACTION_HEX_RADIUS)
	canvas.draw_polyline(points, color, stroke)


## A lintel over three pillars.
static func _faction_pillars(canvas: CanvasItem, box: Rect2, color: Color, stroke: float) -> void:
	canvas.draw_line(_at(box, FACTION_LINTEL.position),
		_at(box, FACTION_LINTEL.position + Vector2(FACTION_LINTEL.size.x, 0.0)), color, stroke)
	for x: float in FACTION_PILLAR_XS:
		canvas.draw_line(_at(box, Vector2(x, FACTION_PILLAR_TOP)),
			_at(box, Vector2(x, FACTION_PILLAR_BOTTOM)), color, stroke)


## `draw_rect` cannot round its corners, and a `StyleBox` here would be a colour
## the caller does not own — so the outline is four lines and four arcs.
static func _rounded_rect(canvas: CanvasItem, rect: Rect2, radius: float, color: Color,
		stroke: float) -> void:
	var r: float = minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var left: float = rect.position.x
	var top: float = rect.position.y
	var right: float = rect.end.x
	var bottom: float = rect.end.y
	canvas.draw_line(Vector2(left + r, top), Vector2(right - r, top), color, stroke)
	canvas.draw_line(Vector2(left + r, bottom), Vector2(right - r, bottom), color, stroke)
	canvas.draw_line(Vector2(left, top + r), Vector2(left, bottom - r), color, stroke)
	canvas.draw_line(Vector2(right, top + r), Vector2(right, bottom - r), color, stroke)
	if r <= 0.0:
		return
	var quarter: int = CORNER_SEGMENTS
	canvas.draw_arc(Vector2(left + r, top + r), r, PI, PI * 1.5, quarter, color, stroke)
	canvas.draw_arc(Vector2(right - r, top + r), r, PI * 1.5, TAU, quarter, color, stroke)
	canvas.draw_arc(Vector2(right - r, bottom - r), r, 0.0, PI * 0.5, quarter, color, stroke)
	canvas.draw_arc(Vector2(left + r, bottom - r), r, PI * 0.5, PI, quarter, color, stroke)
