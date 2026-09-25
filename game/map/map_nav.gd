class_name MapNav
extends RefCounted
## Where the keyboard's map cursor goes (spec accessibility.md §4.5): a step in a
## direction, or a jump to the next region that wants the player.
##
## Pure and static: the anchors and the candidate lists come in as arrays, so a
## test places four points by hand.

## A candidate must lie within this cone around the direction: across ≤
## along × `STEP_CONE` is a 60° half-angle (tan 60° ≈ 1.732).
const STEP_CONE: float = 1.732
## A sideways offset counts this much more than the distance along the way.
const STEP_ACROSS_WEIGHT: float = 2.0


## The region the cursor moves to from `from` in direction `dir` (a unit vector,
## y down), or -1. Among the candidates ahead within the cone the lowest
## `along + STEP_ACROSS_WEIGHT × across` wins; a tie goes to the lower index. The
## map does not wrap east–west.
static func step(from: int, dir: Vector2, anchors: PackedVector2Array,
		regions: PackedInt32Array) -> int:
	if from < 0 or from >= anchors.size():
		return -1
	var origin: Vector2 = anchors[from]
	var best: int = -1
	var best_score: float = INF
	for r: int in regions:
		if r == from or r < 0 or r >= anchors.size():
			continue
		var v: Vector2 = anchors[r] - origin
		var along: float = v.dot(dir)
		var across: float = absf(v.cross(dir))
		if along <= 0.0 or across > along * STEP_CONE:
			continue
		var score: float = along + STEP_ACROSS_WEIGHT * across
		if score < best_score or (is_equal_approx(score, best_score) and r < best):
			best = r
			best_score = score
	return best


## The next (or previous) index in `wanted` after `from`, in ascending index
## order, wrapping; -1 when empty.
static func jump(from: int, forward: bool, wanted: PackedInt32Array) -> int:
	if wanted.is_empty():
		return -1
	var sorted: PackedInt32Array = wanted.duplicate()
	sorted.sort()
	if forward:
		for r: int in sorted:
			if r > from:
				return r
		return sorted[0]
	for i: int in range(sorted.size() - 1, -1, -1):
		if sorted[i] < from:
			return sorted[i]
	return sorted[sorted.size() - 1]


## The region whose anchor lies nearest `point` among `regions`, or -1 — the
## cursor's first place, before any step: nearest the camera's centre.
static func nearest(point: Vector2, anchors: PackedVector2Array,
		regions: PackedInt32Array) -> int:
	var best: int = -1
	var best_distance: float = INF
	for r: int in regions:
		if r < 0 or r >= anchors.size():
			continue
		var distance: float = anchors[r].distance_squared_to(point)
		if distance < best_distance:
			best = r
			best_distance = distance
	return best
