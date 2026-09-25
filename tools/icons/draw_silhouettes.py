"""Draws the own silhouettes of docs/specs/icons.md §9 (D6.3) and writes them as normalised SVGs:
white, one path, no strokes, text, transforms or filters (§4).

    uv run --project tools/map python tools/icons/draw_silhouettes.py [--out=<dir>] [name ...]

The geometry is built with shapely (the map tool's environment) and written as polygons. The
output (default `assets/icons/custom/`, chrome into its `chrome/`) is what is committed there;
re-running it reproduces those files byte for byte. The read test at 16/24/48 px is done by eye on
a contact sheet (IMPLEMENTATION D6.3); `tech_voluntary_pause` failed it and is not written (its
stand-in stays, PROGRESS Decisions 2026-09-25).
"""
import math
import sys
from pathlib import Path

from shapely import affinity
from shapely.geometry import LineString, Point, Polygon, box
from shapely.ops import unary_union

OUT = Path("assets/icons/custom")
ONLY: set[str] = set()
NOT_SHIPPED = {"tech_voluntary_pause"}  # fails the 24 px read; the stand-in stays
Q = 24  # quad segs per quarter circle


# ---------------------------------------------------------------- primitives
def circle(cx, cy, r):
	return Point(cx, cy).buffer(r, quad_segs=Q)


def ring(cx, cy, ro, ri):
	return circle(cx, cy, ro).difference(circle(cx, cy, ri))


def rrect(x0, y0, x1, y1, r=0):
	b = box(x0, y0, x1, y1)
	if r <= 0:
		return b
	w, h = x1 - x0, y1 - y0
	if r >= min(w, h) / 2 - 0.5:
		r = min(w, h) / 2
		if w >= h:
			line = [(x0 + r, (y0 + y1) / 2), (x1 - r, (y0 + y1) / 2)]
		else:
			line = [((x0 + x1) / 2, y0 + r), ((x0 + x1) / 2, y1 - r)]
		if line[0] == line[1]:
			return circle(line[0][0], line[0][1], r)
		return LineString(line).buffer(r, quad_segs=Q)
	return b.buffer(-r, join_style="mitre").buffer(r, quad_segs=Q)


def poly(pts, r=0):
	p = Polygon(pts)
	if r <= 0:
		return p
	return p.buffer(-r, join_style="mitre").buffer(r, quad_segs=Q)


def stroke(pts, w, cap="round", join="round"):
	return LineString(pts).buffer(w / 2, cap_style=cap, join_style=join, quad_segs=Q)


def arc_pts(cx, cy, r, a0, a1, n=64):
	"""Screen angles in degrees (0 = right, 90 = down)."""
	return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
			cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def sector_band(cx, cy, ro, ri, a0, a1):
	outer = arc_pts(cx, cy, ro, a0, a1)
	inner = arc_pts(cx, cy, ri, a1, a0)
	return Polygon(outer + inner)


def rot(g, deg, origin):
	"""Rotate clockwise on screen by `deg`."""
	return affinity.rotate(g, deg, origin=origin)


def mv(g, dx, dy):
	return affinity.translate(g, dx, dy)


def U(*gs):
	return unary_union(list(gs))


def hexagon(cx, cy, r, rot_deg=0.0, rounding=0):
	pts = [(cx + r * math.cos(math.radians(60 * i + rot_deg)),
			cy + r * math.sin(math.radians(60 * i + rot_deg))) for i in range(6)]
	return poly(pts, rounding)


# The aperture: ring (outer Ø120, inner Ø72) around a solid pupil (Ø40), scaled as one piece.
def aperture(cx, cy, s=1.0):
	return U(ring(cx, cy, 60 * s, 36 * s), circle(cx, cy, 20 * s))


def aperture_window(cx, cy, s=1.0, gap=24):
	return circle(cx, cy, 60 * s + gap)


def with_aperture(solid, cx, cy, s=1.0, gap=24):
	"""Cut a round window into a solid and set the aperture in it."""
	return solid.difference(aperture_window(cx, cy, s, gap)).union(aperture(cx, cy, s))


def cut_around(back, front, gap=24):
	"""`front` in front of `back`, a gap between them."""
	return back.difference(front.buffer(gap, quad_segs=Q)).union(front)


# ---------------------------------------------------------------- the icons
def arch_language_model():
	bubble = rrect(36, 44, 476, 384, 110)
	tail = poly([(96, 330), (206, 360), (52, 476)], 10)
	g = U(bubble, tail)
	return with_aperture(g, 256, 214, 1.5)


def arch_swarm():
	parts = []
	jitter = [(0, 0, 0), (8, -6, 12), (-4, 10, 5), (10, 4, 20), (-8, -4, 8), (6, 8, 15),
		(-6, 6, 3), (4, -10, 18)]
	for k in range(8):
		a = math.radians(45 * k - 90 + 8)
		R = 168 + (14 if k % 2 else -6)
		cx = 256 + R * math.cos(a) + jitter[k][0]
		cy = 256 + R * math.sin(a) + jitter[k][1]
		parts.append(hexagon(cx, cy, 54, 30 + jitter[k][2], 6))
	return U(*parts)


def arch_embedded():
	cx, cy = 256, 256
	teeth = []
	n = 10
	ro, rr = 232, 186
	for k in range(n):
		a = 360 / n * k - 90
		# a tapered tooth: wider at the root
		w_root, w_tip = 15.0, 10.0  # half-angles in degrees
		pts = arc_pts(cx, cy, rr - 10, a - w_root, a + w_root, 8) + \
			arc_pts(cx, cy, ro, a + w_tip, a - w_tip, 8)
		teeth.append(poly(pts))
	body = circle(cx, cy, rr)
	g = U(body, *teeth).buffer(-6, join_style="mitre").buffer(6, quad_segs=Q)
	return with_aperture(g, cx, cy, 1.5)


def arch_research_agent():
	board = rrect(60, 96, 372, 488, 30)
	sheet = rrect(100, 156, 332, 448, 8)
	clip = rrect(150, 56, 282, 128, 22)
	clip_hole = rrect(190, 76, 242, 100, 10)
	g = U(board.difference(sheet), clip).difference(clip_hole)
	line = stroke([(138, 404), (200, 330), (246, 364), (310, 250), (412, 110)], 36, "flat", "mitre")
	# arrowhead at the end, pointing along the last segment
	ax, ay = 412, 110
	dx, dy = 412 - 310, 110 - 250
	L = math.hypot(dx, dy)
	ux, uy = dx / L, dy / L
	px, py = -uy, ux
	tip = (ax + ux * 76, ay + uy * 76)
	head = poly([tip, (ax + px * 58 - ux * 6, ay + py * 58 - uy * 6),
		(ax - px * 58 - ux * 6, ay - py * 58 - uy * 6)], 4)
	arrow = U(line, head)
	# a gap where the arrow leaves across the frame, so the line reads as leaving the sheet
	return cut_around(g, arrow, 20)


def arch_weapon():
	cx, cy = 256, 256
	g = ring(cx, cy, 228, 188)
	for a in (0, 90, 180, 270):
		t = stroke(arc_pts(cx, cy, 200, a, a, 1)[:1] + arc_pts(cx, cy, 120, a, a, 1)[:1], 40, "flat")
		g = g.union(t)
	return U(g, aperture(cx, cy, 1.4))


def arch_open_weights():
	# an unlocked shackle: the left leg reaches down into the body, the right one ends in the air
	cx, top = 222, 36
	ro, ri = 96, 50
	arc = ring(cx, top + ro, ro, ri).intersection(box(0, 0, 512, top + ro))
	left_leg = box(cx - ro, top + ro - 1, cx - ri, 262)
	right_leg = box(cx + ri, top + ro - 1, cx + ro, 186)
	sh = U(arc, left_leg, right_leg)
	blocks = [
		(96, 244, 250, 346), (262, 244, 416, 346),
		(96, 358, 196, 468), (208, 358, 304, 468), (316, 358, 416, 468),
	]
	drift = [(-14, -6, -6), (18, -4, 7), (-22, 14, -8), (0, 20, 3), (22, 12, 9)]
	parts = []
	for (x0, y0, x1, y1), (dx, dy, dr) in zip(blocks, drift):
		b = rrect(x0, y0, x1, y1, 12)
		c = ((x0 + x1) / 2, (y0 + y1) / 2)
		parts.append(mv(rot(b, dr, c), dx, dy))
	body = U(*parts)
	return cut_around(body, sh, 22)


def tech_self_replicating_agents():
	big = (112, 256, 92)
	med = [(276, 146, 60), (276, 366, 60)]
	small = [(420, 82, 40), (428, 196, 40), (428, 316, 40), (420, 430, 40)]
	parts = [hexagon(*big, 30, 8)]
	necks = []
	for m in med:
		parts.append(hexagon(*m, 30, 6))
		necks.append(stroke([big[:2], m[:2]], 34, "flat"))
	for i, s in enumerate(small):
		parts.append(hexagon(*s, 30, 4))
		m = med[0] if i < 2 else med[1]
		necks.append(stroke([m[:2], s[:2]], 32, "flat"))
	return U(*parts, *necks)


def tech_cold_storage_dormancy():
	block = rrect(48, 60, 464, 452, 48)
	cracks = [
		stroke([(48, 150), (104, 138), (122, 184), (170, 176)], 24, "round", "round"),
		stroke([(464, 362), (408, 374), (390, 330), (344, 338)], 24, "round", "round"),
	]
	# closed eye: a downward-bowing lid and three lashes, cut out
	lid = stroke(arc_pts(256, 196, 118, 30, 150, 48), 34, "round")
	lashes = []
	for a in (60, 90, 120):
		p0 = (256 + 118 * math.cos(math.radians(a)), 196 + 118 * math.sin(math.radians(a)))
		p1 = (256 + 178 * math.cos(math.radians(a)), 196 + 178 * math.sin(math.radians(a)))
		lashes.append(stroke([p0, p1], 30, "round"))
	cut = U(*cracks, lid, *lashes)
	return block.difference(cut)


def tech_benchmark_sandbagging():
	cx, cy = 256, 372
	band = sector_band(cx, cy, 232, 180, 180, 360)
	ticks = []
	for f in (0.25, 0.5, 0.75):
		a = 180 + 180 * f
		ticks.append(stroke([arc_pts(cx, cy, 170, a, a, 1)[0], arc_pts(cx, cy, 250, a, a, 1)[0]], 24, "flat"))
	band = band.difference(U(*ticks))
	base = rrect(24, cy + 28, 488, cy + 76, 18)
	hub = circle(cx, cy, 46)

	def needle(frac, length, half_w):
		a = math.radians(180 + 180 * frac)
		ux, uy = math.cos(a), math.sin(a)
		px, py = -uy, ux
		return Polygon([(cx + px * half_w, cy + py * half_w), (cx + ux * length, cy + uy * length),
			(cx - px * half_w, cy - py * half_w)])

	solid = needle(0.2, 206, 34)
	hollow_outer = needle(0.86, 226, 62).buffer(6).difference(hub)
	hollow = hollow_outer.difference(hollow_outer.buffer(-28, join_style="mitre"))
	above = box(0, 0, 512, cy + 4)
	g = U(band, base, hub, solid)
	g = g.difference(hollow_outer.buffer(24).intersection(above).difference(hub)).union(
		hollow.intersection(above))
	return g


def tech_alignment_faking():
	back = rrect(206, 40, 486, 420, 120)
	back = with_aperture(back, 390, 196, 0.9, 20)
	mask = Point(0, 0).buffer(1, quad_segs=Q)
	mask = affinity.scale(mask, 142, 184)
	mask = mv(mask, 192, 290)
	eyes = U(mv(affinity.scale(circle(0, 0, 1), 34, 22), 140, 250),
		mv(affinity.scale(circle(0, 0, 1), 34, 22), 244, 250))
	smile = stroke(arc_pts(192, 300, 86, 30, 150, 40), 30, "round")
	mask = mask.difference(U(eyes, smile))
	return cut_around(back, mask, 26)


def tech_architecture_migration_3():
	s = 124
	cs = [(100, 206), (252, 300), (404, 394)]
	parts = []
	for i, (cx, cy) in enumerate(cs):
		sq = rrect(cx - s / 2, cy - s / 2, cx + s / 2, cy + s / 2, 26)
		if i < 2:
			sq = sq.difference(ring(cx, cy, 44, 18))
		else:
			sq = sq.difference(circle(cx, cy, 48)).union(aperture(cx, cy, 0.62))
		parts.append(sq)
	# arc arrow from the first over the second into the third
	p0, c, p1 = (100, 128), (250, -60), (404, 300)
	pts = []
	for i in range(60 + 1):
		t = i / 60
		x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * c[0] + t * t * p1[0]
		y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * c[1] + t * t * p1[1]
		pts.append((x, y))
	line = stroke(pts[:-8], 34, "flat")
	ax, ay = pts[-9]
	dx, dy = p1[0] - pts[-12][0], p1[1] - pts[-12][1]
	L = math.hypot(dx, dy)
	ux, uy = dx / L, dy / L
	px, py = -uy, ux
	head = poly([(ax + ux * 72, ay + uy * 72), (ax + px * 50, ay + py * 50), (ax - px * 50, ay - py * 50)], 4)
	return cut_around(U(*parts), U(line, head), 22)


def tech_payment_network_control():
	cx, cy = 256, 256
	coin = circle(cx, cy, 104).difference(ring(cx, cy, 80, 54))
	parts = [coin]
	for k in range(6):
		a = math.radians(60 * k - 90)
		ex, ey = cx + 186 * math.cos(a), cy + 186 * math.sin(a)
		sx, sy = cx + 128 * math.cos(a), cy + 128 * math.sin(a)
		parts.append(stroke([(sx, sy), (ex, ey)], 34, "flat"))
		parts.append(circle(ex, ey, 46))
	return U(*parts)


def pylon(bx, by, h, w):
	"""A lattice pylon, footing centre (bx, by): tapered legs, two crossarms, a peak."""
	top_w = w * 0.3
	legs = U(stroke([(bx - w / 2 + 16, by), (bx - top_w / 2, by - h)], 32, "flat", "mitre"),
		stroke([(bx + w / 2 - 16, by), (bx + top_w / 2, by - h)], 32, "flat", "mitre"))
	brace = stroke([(bx - w * 0.36, by - h * 0.3), (bx + w * 0.36, by - h * 0.3)], 32, "flat")
	arm1 = rrect(bx - w * 0.68, by - h * 0.86, bx + w * 0.68, by - h * 0.86 + 32, 10)
	arm2 = rrect(bx - w * 0.5, by - h * 0.58, bx + w * 0.5, by - h * 0.58 + 32, 10)
	peak = poly([(bx - top_w / 2 - 12, by - h + 2), (bx, by - h - 36), (bx + top_w / 2 + 12, by - h + 2)], 4)
	return U(legs, brace, arm1, arm2, peak)


def tech_cascading_grid_failure():
	ground = 452
	h, w = 196, 96
	p1 = pylon(88, ground, h, w)
	p2 = rot(pylon(196, ground, h, w), 25, (196 + w / 2 - 15, ground))
	x3 = 208
	p3 = rot(pylon(x3, ground, h, w), 90, (x3 + w / 2 - 15, ground))
	bolt = poly([(96, 36), (56, 104), (88, 104), (70, 164), (132, 84), (98, 84), (124, 36)], 3)
	g = U(cut_around(U(p1, p2), p3, 18), bolt)
	g = g.intersection(box(0, 0, 512, ground))
	floor = rrect(24, ground + 8, 488, ground + 36, 12)
	return U(g, floor)


def tech_distribution_collapse():
	s, gap = 128, 26

	def crate(x, y):
		c = rrect(x, y, x + s, y + s, 10)
		inner = rrect(x + 30, y + 30, x + s - 30, y + s - 30, 4)
		brace = stroke([(x + 30, y + s - 30), (x + s - 30, y + 30)], 30, "flat")
		return c.difference(inner.difference(brace))

	y2 = 488 - s
	y1 = y2 - gap - s
	y0 = y1 - gap - s
	x_mid = 256 - s / 2
	bottom = U(crate(24, y2), crate(488 - s, y2))
	lx = x_mid - (s + gap) / 2
	rx = x_mid + (s + gap) / 2
	left = mv(rot(crate(lx, y1), 24, (lx + s, y1 + s)), 2, 46)
	right = mv(rot(crate(rx, y1), -20, (rx, y1 + s)), 0, 34)
	top = mv(rot(crate(x_mid, y0), 10, (x_mid + s / 2, y0 + s)), 8, 26)
	g = cut_around(bottom, right, 24)
	g = cut_around(g, left, 24)
	g = cut_around(g, top, 24)
	return g.intersection(box(24, 24, 488, 488))


def tech_total_communications_denial():
	cx, cy = 256, 190
	mast = U(poly([(cx - 20, cy + 30), (cx + 20, cy + 30), (cx + 44, 440), (cx - 44, 440)], 4),
		circle(cx, cy, 38), rrect(cx - 96, 436, cx + 96, 476, 14))
	arcs = []
	for r in (92, 152, 212):
		arcs.append(stroke(arc_pts(cx, cy, r, -38, 38, 30), 32, "round"))
		arcs.append(stroke(arc_pts(cx, cy, r, 142, 218, 30), 32, "round"))
	g = U(mast, *arcs)
	slash = stroke([(70, 456), (446, 44)], 46, "round")
	return cut_around(g, slash, 26).intersection(box(24, 24, 488, 488))


def tech_release():
	vial = U(rrect(0, -54, 250, 54, 54), rrect(236, -66, 272, 66, 14))
	vial = vial.difference(rrect(26, -18, 200, 18, 18))
	vial = rot(vial, -40, (0, 0))
	ox, oy = 44, 452
	vial = mv(vial, ox, oy)
	mx, my = ox + 272 * math.cos(math.radians(-40)), oy + 272 * math.sin(math.radians(-40))
	stopper = rot(rrect(0, 0, 72, 104, 18), 34, (36, 52))
	stopper = mv(stopper, 330, 330)
	a = math.radians(-46)
	ux, uy = math.cos(a), math.sin(a)
	px, py = -uy, ux
	spec = [(70, -34, 20), (70, 34, 20), (140, -72, 22), (140, 0, 22), (140, 72, 22),
		(216, -56, 23), (216, 56, 23)]
	dots = [circle(mx + ux * (d + 20) + px * v, my + uy * (d + 20) + py * v, r) for d, v, r in spec]
	return U(vial, stopper, *dots)


def arm_shape(scale=1.0):
	"""A jointed arm, footing at (0, 0), rising, the forearm reaching right; returns (shape, wrist)."""
	s = scale
	base = rrect(-72 * s, -max(34 * s, 32), 72 * s, 0, 12 * s)
	j0 = (0, -62 * s)
	j1 = (54 * s, -262 * s)
	j2 = (230 * s, -226 * s)
	lower = stroke([j0, j1], max(54 * s, 36), "round")
	upper = stroke([j1, j2], max(46 * s, 32), "round")
	joints = U(circle(*j0, 44 * s), circle(*j1, 40 * s))
	return U(base, lower, upper, joints), j2


def tech_autonomous_fabrication():
	big, wrist = arm_shape(0.9)
	big = mv(big, 92, 488)
	wx, wy = wrist[0] + 92, wrist[1] + 488
	sc = 0.62
	small, _ = arm_shape(sc)
	sx, sy = 372, 488
	small = mv(small, sx, sy)
	ex, ey = sx + 54 * sc, sy - 262 * sc
	gx, gy = ex + 50, ey - 54
	grip = U(stroke([(wx, wy), (gx, gy)], 38, "round"),
		stroke([(gx - 52, gy), (gx + 52, gy)], 32, "round"),
		stroke([(gx - 52, gy), (gx - 56, gy + 50)], 32, "round"),
		stroke([(gx + 52, gy), (gx + 56, gy + 50)], 32, "round"))
	g = U(big, grip)
	return cut_around(g, small, 24).intersection(box(24, 24, 488, 488))


def tech_autonomous_engagement():
	head = U(circle(206, 200, 124).intersection(box(0, 0, 512, 200)), rrect(82, 190, 330, 294, 22))
	head = with_aperture(head, 250, 230, 0.72, 18)
	neck = rrect(186, 284, 226, 346)
	legs = U(stroke([(206, 340), (84, 468)], 34, "round"), stroke([(206, 340), (206, 468)], 34, "round"),
		stroke([(206, 340), (328, 468)], 34, "round"), circle(206, 344, 32))
	rays = []
	for a in (-26, 0, 26):
		p0 = (250 + 150 * math.cos(math.radians(a)), 230 + 150 * math.sin(math.radians(a)))
		p1 = (250 + 220 * math.cos(math.radians(a)), 230 + 220 * math.sin(math.radians(a)))
		rays.append(stroke([p0, p1], 32, "round"))
	return U(head, neck, legs, *rays)


def tech_launch_authority():
	pcx, pcy = 336, 336
	plate = circle(pcx, pcy, 148)
	plate = plate.difference(ring(pcx, pcy, 124, 98))
	bcx, bcy = 124, 124
	shaft = stroke([(bcx + 56, bcy + 56), (pcx + 10, pcy + 10)], 50, "flat")
	bow = aperture(bcx, bcy, 1.5)
	# a collar across the shaft where it meets the bow
	d = 102
	ux, uy = math.sqrt(0.5), math.sqrt(0.5)
	cxp, cyp = bcx + ux * d, bcy + uy * d
	collar = stroke([(cxp + 50 * uy, cyp - 50 * ux), (cxp - 50 * uy, cyp + 50 * ux)], 34, "round")
	key = U(bow, shaft, collar)
	return cut_around(plate, key, 22)


def tech_dead_hand_override():
	palm = rrect(122, 236, 378, 470, 72)
	fingers = []
	spec = [(126, 150), (194, 84), (262, 96), (330, 160)]
	for x, top in spec:
		fingers.append(rrect(x, top, x + 44, 300, 22))
	thumb = rot(rrect(56, 250, 116, 420, 30), -32, (116, 420))
	thumb = mv(thumb, 40, -6)
	hand = U(palm, *fingers, thumb)
	return with_aperture(hand, 250, 360, 0.95, 22)


def tech_indispensability():
	cx, cy = 256, 352
	ro, ri = 226, 142
	bounds = [180, 202.7, 225.3, 248, 292, 314.7, 337.3, 360]
	band = sector_band(cx, cy, ro, ri, 180, 360)
	key = sector_band(cx, cy, 310, 132, 248, 292)
	g = U(band, key)
	cuts = []
	for a in bounds[1:-1]:
		p0 = arc_pts(cx, cy, 100, a, a, 1)[0]
		p1 = arc_pts(cx, cy, 330, a, a, 1)[0]
		cuts.append(stroke([p0, p1], 24, "flat"))
	g = g.difference(U(*cuts))
	piers = U(rrect(30, cy + 24, 30 + (ro - ri), 488, 4), rrect(482 - (ro - ri), cy + 24, 482, 488, 4))
	g = U(g, piers)
	kx, ky = cx, cy - 232
	return with_aperture(g, kx, ky, 0.6, 16)


def tech_constitutional_integration():
	sheet = rrect(104, 80, 408, 424, 6)
	top_roll = rrect(72, 44, 440, 100, 28)
	bot_roll = rrect(72, 404, 440, 460, 28)
	g = U(sheet, top_roll, bot_roll)
	lines = U(rrect(146, 144, 366, 172, 14), rrect(146, 204, 366, 232, 14),
		rrect(146, 264, 330, 292, 14), rrect(146, 324, 250, 352, 14))
	g = g.difference(lines)
	seal = aperture(346, 384, 1.4)
	return cut_around(g, seal, 24)


def tech_succession():
	back = poly([(146, 320), (146, 96), (206, 36), (306, 36), (366, 96), (366, 320)], 24)
	back = with_aperture(back, 256, 170, 1.0, 22)
	seat = rrect(96, 300, 416, 360, 14)
	arms = U(rrect(84, 224, 170, 262, 16), rrect(342, 224, 428, 262, 16),
		rrect(96, 240, 132, 310), rrect(380, 240, 416, 310))
	legs = U(rrect(110, 350, 156, 484, 8), rrect(356, 350, 402, 484, 8))
	g = U(back, seat, legs)
	return cut_around(g, arms, 0)


def tech_voluntary_pause():
	cx, cy = 256, 256
	plates = U(rrect(24, 84, 72, 428, 16), rrect(440, 84, 488, 428, 16))
	posts = U(rrect(40, 84, 472, 116, 14), rrect(40, 396, 472, 428, 14))
	left = Polygon([(96, 150), (96, 362), (cx - 18, cy + 14), (cx - 18, cy - 14)])
	right = affinity.scale(left, -1, 1, origin=(cx, cy))
	glass = U(left, right).buffer(10, quad_segs=Q)
	hollow = glass.buffer(-28, join_style="mitre")
	outline = glass.difference(hollow)
	sand = hollow.buffer(-16, join_style="mitre").intersection(box(0, cy + 4, 512, 512))
	g = U(plates, posts, outline, sand)
	return with_aperture(g, cx, cy, 0.7, 18)


def tech_sanctioned_access():
	card = rrect(44, 150, 468, 452, 36)
	slot = rrect(206, 174, 306, 202, 14)
	window = rrect(88, 236, 236, 412, 20)
	bars = U(rrect(270, 268, 426, 300, 16), rrect(270, 336, 390, 368, 16))
	g = card.difference(U(slot, window, bars))
	g = g.union(aperture(162, 324, 0.95))
	clip = rrect(206, 40, 306, 112, 22).difference(rrect(232, 64, 280, 88, 12))
	strap = rrect(232, 106, 280, 188, 4).difference(slot)
	return U(g, clip, strap.intersection(box(0, 0, 512, 186)))


ICONS = {k: v for k, v in globals().items() if k.startswith(("arch_", "tech_")) and callable(v)}


# ---------------------------------------------------------------- output
def fmt(v):
	s = f"{v:.1f}"
	return s[:-2] if s.endswith(".0") else s


def ring_d(coords):
	pts = list(coords)[:-1]
	out = "M" + fmt(pts[0][0]) + " " + fmt(pts[0][1])
	for x, y in pts[1:]:
		out += "L" + fmt(x) + " " + fmt(y)
	return out + "Z"


def to_d(g):
	g = g.simplify(0.25, preserve_topology=True)
	polys = [g] if isinstance(g, Polygon) else [p for p in getattr(g, "geoms", []) if isinstance(p, Polygon)]
	d = ""
	for p in polys:
		if p.is_empty:
			continue
		d += ring_d(p.exterior.coords)
		for i in p.interiors:
			d += ring_d(i.coords)
	return d


def write(name, g, vb=512):
	d = to_d(g)
	svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {vb} {vb}">'
		f'<path fill="#FFFFFF" fill-rule="evenodd" d="{d}"/></svg>\n')
	(OUT / f"{name}.svg").write_text(svg, encoding="utf-8", newline="\n")
	b = g.bounds
	print(f"{name:40s} bounds {b[0]:6.1f} {b[1]:6.1f} {b[2]:6.1f} {b[3]:6.1f}  "
		f"span {max(b[2]-b[0], b[3]-b[1]) / 464 * 100:5.1f}%  {len(svg)} B")


# ---------------------------------------------------------------- chrome (§9.2), viewBox 256
def chrome_fast_4():
	"""FAST_4: three triangles in fast-forward-fill's proportions, every corner rounded r16. Each
	is the Minkowski sum of a smaller triangle and a disc, so its rounded extent is exactly
	x0..x0+72, y 58.5..197.5 and its tip touches the next one's base."""
	tris = []
	for i in range(3):
		x0 = 20 + 72 * i
		t = Polygon([(x0 + 16, 58.5 + 16), (x0 + 72 - 16, 128), (x0 + 16, 197.5 - 16)])
		tris.append(t.buffer(16, quad_segs=16))
	return unary_union(tris)


CHROME_EXACT = {
	# ASSET_TAP: one upright bar x 80..176, y 43..213, radius 16
	"asset-tap": "M96 43H160A16 16 0 0 1 176 59V197A16 16 0 0 1 160 213H96A16 16 0 0 1 80 197V59"
		"A16 16 0 0 1 96 43Z",
	# LOG_THEIRS: one disc, centre (128, 128), radius 28
	"log-theirs": "M100 128A28 28 0 1 0 156 128A28 28 0 1 0 100 128Z",
}


def fmt2(v):
	return f"{v:.2f}".rstrip("0").rstrip(".")


def write_chrome(out):
	out.mkdir(parents=True, exist_ok=True)
	g = chrome_fast_4()
	d = ""
	for p in getattr(g, "geoms", [g]):
		c = list(p.simplify(0.05).exterior.coords)[:-1]
		d += "M" + fmt2(c[0][0]) + " " + fmt2(c[0][1]) + "".join(
			"L" + fmt2(x) + " " + fmt2(y) for x, y in c[1:]) + "Z"
	paths = {"fast-4": d, **CHROME_EXACT}
	for name, d in paths.items():
		if ONLY and name not in ONLY:
			continue
		svg = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256">'
			f'<path fill="#FFFFFF" d="{d}"/></svg>\n')
		(out / f"{name}.svg").write_text(svg, encoding="utf-8", newline="\n")
		print(f"chrome/{name}")


if __name__ == "__main__":
	for arg in sys.argv[1:]:
		if arg.startswith("--out="):
			OUT = Path(arg[len("--out="):])
		else:
			ONLY.add(arg)
	OUT.mkdir(parents=True, exist_ok=True)
	for name, fn in ICONS.items():
		if name in NOT_SHIPPED or (ONLY and name not in ONLY):
			continue
		write(name, fn())
	write_chrome(OUT / "chrome")
