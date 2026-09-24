shader_type canvas_item;
// The title's globe (spec screens-full.md §3.1): a sphere drawn in 2D.
//
// Per fragment inside the disc, the sphere normal is rotated back into the
// world — tilted about the horizontal axis, turned about the vertical one — and
// read as longitude and latitude, which index an equirectangular copy of the
// region-ID map. IDs are fetched with `texelFetch` and compared as decoded
// indices, never blended, exactly like the map (ui-foundation.md §7.3).
//
// No colour lives here; `globe.gd` sets every one from `UiTokens`.

// A border is drawn where either neighbour texel is another region.
const float BORDER_STRENGTH = 0.9;
// The terminator is a soft band, not a hard edge.
const float TERMINATOR_SOFTNESS = 0.08;
const float RIM_POWER = 3.0;

uniform sampler2D globe_ids : filter_nearest, repeat_enable;
// 256 × 1: pixel i is region i — R reached, G controlled (the session's
// data-texture convention).
uniform sampler2D region_data : filter_nearest, repeat_disable;

uniform vec4 ink_color : source_color;
uniform vec4 land_color : source_color;
uniform vec4 border_color : source_color;
uniform vec4 reached_color : source_color;
uniform vec4 rim_color : source_color;
uniform float reached_mix = 0.35;
uniform float controlled_mix = 0.7;
// Radians: the longitude at the centre of the view (`globe.gd` turns it) and
// the tilt of the axis towards the viewer.
uniform float centre_lon = 0.0;
uniform float tilt = -0.314159;
// The terminator stands this far from the view axis (the light 90° beyond it);
// the far side falls to `night`.
uniform float terminator = 1.22173;
uniform float night = 0.4;
// Width over height of the rect, so the disc stays round in any rect.
uniform float aspect = 1.0;

int region_at(ivec2 texel, ivec2 size) {
	ivec2 wrapped = ivec2((texel.x % size.x + size.x) % size.x, clamp(texel.y, 0, size.y - 1));
	vec4 c = texelFetch(globe_ids, wrapped, 0);
	return int(round(c.r * 255.0)) + int(round(c.g * 255.0)) * 256;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	// The disc is inscribed in the shorter side.
	if (aspect > 1.0) {
		p.x *= aspect;
	} else {
		p.y /= aspect;
	}
	float r2 = dot(p, p);
	if (r2 > 1.0) {
		COLOR = vec4(0.0);
	} else {
		// View space: x right, y up, z towards the viewer.
		vec3 n = vec3(p.x, -p.y, sqrt(1.0 - r2));
		// Back into the world: undo the tilt about x, then the turn about y.
		float ct = cos(tilt);
		float st = sin(tilt);
		vec3 w = vec3(n.x, n.y * ct - n.z * st, n.y * st + n.z * ct);
		float lat = asin(clamp(w.y, -1.0, 1.0));
		float lon = atan(w.x, w.z) + centre_lon;

		ivec2 size = textureSize(globe_ids, 0);
		float u = fract(lon / TAU + 0.5);
		float v = 0.5 - lat / PI;
		ivec2 texel = ivec2(int(u * float(size.x)), int(v * float(size.y)));
		int index = region_at(texel, size);

		vec3 color = ink_color.rgb;
		if (index > 0) {
			vec4 data = texelFetch(region_data, ivec2(index, 0), 0);
			color = land_color.rgb;
			if (data.g > 0.5) {
				color = mix(color, reached_color.rgb, controlled_mix);
			} else if (data.r > 0.5) {
				color = mix(color, reached_color.rgb, reached_mix);
			}
		}
		int right = region_at(texel + ivec2(1, 0), size);
		int below = region_at(texel + ivec2(0, 1), size);
		if (right != index || below != index) {
			color = mix(color, border_color.rgb, BORDER_STRENGTH);
		}

		// Light from the left: its terminator stands `terminator` from the view
		// axis on the right, and the far side keeps `night` of its brightness.
		vec3 light = vec3(-cos(terminator), 0.0, sin(terminator));
		float lit = smoothstep(-TERMINATOR_SOFTNESS, TERMINATOR_SOFTNESS, dot(n, light));
		color *= mix(night, 1.0, lit);
		// The limb glows: strongest where the surface turns away.
		color += rim_color.rgb * pow(1.0 - n.z, RIM_POWER);
		COLOR = vec4(color, 1.0);
	}
}
