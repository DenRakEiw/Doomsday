class_name Rings
extends RefCounted
## The countdown ring every marker on the map draws
## (`loop-mechanics.md` §16.3.2).
##
## An anomaly counts its days down, a status counts its days down, an event
## counts its deadline down — one arc, one direction, one helper, so that three
## markers cannot drift into three different clocks.
##
## Never instantiated; a namespace of static functions.

## It empties clockwise from the top, the way a clock is read.
const START: float = -PI * 0.5
const SEGMENTS: int = 32


## Draws the part of the ring that is left. A share of 0 draws nothing at all —
## an empty ring is a full circle of nothing, not a circle.
static func draw_countdown(canvas: CanvasItem, centre: Vector2, radius: float, share: float,
		color: Color, stroke: float) -> void:
	var left: float = clampf(share, 0.0, 1.0)
	if left <= 0.0 or radius <= 0.0 or stroke <= 0.0:
		return
	canvas.draw_arc(centre, radius, START, START + TAU * left, SEGMENTS, color, stroke, true)


## How much of a ring is left, as a share. A total of 0 or less — a standing
## status, which has no clock — draws the ring full and static (§7.1).
static func share_of(left: float, total: float) -> float:
	if total <= 0.0:
		return 1.0
	return clampf(left / total, 0.0, 1.0)
