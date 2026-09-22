shader_type canvas_item;
// The pattern along one link (spec ui-foundation.md §7.8).
//
// A `Line2D` in stretch mode gives every fragment its position along the line as
// `UV.x` in [0, 1]. Multiplied by the line's length **in screen pixels** that is
// a ruler the dash pattern can be laid out on, which is why the pattern keeps
// its size while the camera zooms: `link_line.gd` sends a new `length_px` with
// every zoom, and everything else here is already in screen pixels.
//
// The colour is the `Line2D`'s own (`default_color`), so no design value lives
// in this file (CLAUDE.md, *Constants*) — the shader only ever removes light.

// The line's length in screen pixels; 0 disables everything that needs a ruler.
uniform float length_px = 0.0;
// The lit part of one dash period, and the dark rest. A gap of 0 is a solid line.
uniform float dash_px = 0.0;
uniform float gap_px = 0.0;
// How far the pattern has travelled — negative when the flow runs b → a.
uniform float offset_px = 0.0;
// The moving bright segment a flowing *solid* link shows instead of a dash.
uniform float bright_px = 0.0;
// What the line is worth when it is not the bright segment.
uniform float base_alpha = 1.0;
// The gap a closed link shows at its midpoint.
uniform float hole_px = 0.0;

void fragment() {
	float s = UV.x * length_px;
	float alpha = base_alpha;

	if (dash_px > 0.0 && gap_px > 0.0) {
		alpha *= step(mod(s + offset_px, dash_px + gap_px), dash_px);
	}

	if (bright_px > 0.0 && length_px > 0.0) {
		// The head runs the length of the line and drags a bright tail behind it,
		// so a solid link still shows which way the flow goes.
		float behind = mod(offset_px, length_px) - s;
		if (behind >= 0.0 && behind <= bright_px) {
			alpha = 1.0;
		}
	}

	if (hole_px > 0.0 && abs(s - length_px * 0.5) < hole_px * 0.5) {
		alpha = 0.0;
	}

	COLOR.a *= alpha;
}
