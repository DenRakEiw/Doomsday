shader_type canvas_item;
// The sea behind the map (spec ui-foundation.md §7.6).
//
// The map's ocean is transparent, so what shows through there is this: a dark
// ground, a console grid and a sparse field of dots. It is drawn in screen
// space and parallaxes against the camera — `backdrop.gd` sends the offset and
// the scale, and every colour and spacing arrives as a uniform, so no design
// value lives in this file (CLAUDE.md, *Constants*).
//
// The dot field is a hash of the cell, not a texture and not a random number:
// the same view draws the same stars in every frame and in every session.

uniform vec4 bg : source_color;
uniform vec4 grid_color : source_color;
uniform vec4 star_color : source_color;

// The quad covers the viewport exactly, so UV × this is a logical screen pixel.
// `FRAGCOORD` would be a physical one and would drift from the parallax offset
// wherever the window is scaled.
uniform vec2 view_size;
// The camera's centre times the parallax factor, in the same pixels.
uniform vec2 grid_offset;
// Widens grid and stars as the camera zooms in; 1 means no widening.
uniform float grid_scale;

uniform float grid_spacing;
uniform float grid_line;
uniform float star_cell;
uniform float star_chance;
uniform float star_radius_min;
uniform float star_radius_max;

// How far a dot may sit from its cell's edge, as a share of the cell: a dot
// that crossed the edge would be cut off, because only its own cell is tested.
const float STAR_INSET = 0.2;
// The width over which a line or a dot fades out, in pixels. One pixel is the
// thinnest edge that does not shimmer while the map moves.
const float EDGE_PX = 1.0;

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 p = (UV * view_size + grid_offset) / max(grid_scale, 0.001);

	vec2 to_line = abs(fract(p / grid_spacing + 0.5) - 0.5) * grid_spacing;
	float half_line = grid_line * 0.5;
	float grid = 1.0 - smoothstep(half_line, half_line + EDGE_PX,
		min(to_line.x, to_line.y));

	float star = 0.0;
	vec2 cell = floor(p / star_cell);
	if (hash12(cell) < star_chance) {
		vec2 jitter = vec2(hash12(cell + vec2(17.0, 3.0)), hash12(cell + vec2(5.0, 29.0)));
		vec2 star_at = (cell + mix(vec2(STAR_INSET), vec2(1.0 - STAR_INSET), jitter))
			* star_cell;
		float radius = mix(star_radius_min, star_radius_max,
			hash12(cell + vec2(41.0, 11.0)));
		star = 1.0 - smoothstep(radius, radius + EDGE_PX, length(p - star_at));
	}

	vec3 col = mix(bg.rgb, grid_color.rgb, grid);
	col = mix(col, star_color.rgb, star);
	COLOR = vec4(col, 1.0);
}
