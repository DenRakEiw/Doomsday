// The full-screen pass (spec polish-visuals.md §3): eight stages over one
// flattened frame, in a fixed order — chromatic aberration, bloom, alert wash,
// vignette, scanlines, grain, ordered dither, dissolve.
//
// Web-safe by construction: one canvas_item fragment pass over the screen
// texture, no compute, no second pass, no environment. Every value arrives as a
// uniform set by `ScreenFx` from `UiTokens`; the only numbers written here are
// the two Bayer matrices (textbook values) and the hash's mixing constants.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen : hint_screen_texture, filter_linear, repeat_disable;
// The shorter side of the window over the 1080 reference.
uniform float px_scale = 1.0;
uniform float ca_px = 0.0;
uniform float bloom_strength = 0.0;
uniform int bloom_taps = 0;
uniform vec2 bloom_radii;
uniform vec2 bloom_key;
uniform vec4 wash : source_color;
uniform float vignette = 0.0;
uniform float vignette_start;
uniform float scan_depth = 0.0;
uniform int scan_period = 2;
uniform float grain_amp = 0.0;
uniform float grain_fps;
uniform float dither_levels = 256.0;
// 0 = none, 1 = the whole frame is ground.
uniform float dissolve = 0.0;
uniform float dissolve_cell = 1.0;
uniform vec4 ground : source_color;

const float BAYER4[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

const float BAYER8[64] = float[64](
	0.0, 32.0, 8.0, 40.0, 2.0, 34.0, 10.0, 42.0,
	48.0, 16.0, 56.0, 24.0, 50.0, 18.0, 58.0, 26.0,
	12.0, 44.0, 4.0, 36.0, 14.0, 46.0, 6.0, 38.0,
	60.0, 28.0, 52.0, 20.0, 62.0, 30.0, 54.0, 22.0,
	3.0, 35.0, 11.0, 43.0, 1.0, 33.0, 9.0, 41.0,
	51.0, 19.0, 59.0, 27.0, 49.0, 17.0, 57.0, 25.0,
	15.0, 47.0, 7.0, 39.0, 13.0, 45.0, 5.0, 37.0,
	63.0, 31.0, 55.0, 23.0, 61.0, 29.0, 53.0, 21.0);

// In [0, 1).
float bayer4(vec2 p) {
	ivec2 q = ivec2(mod(p, 4.0));
	return BAYER4[q.y * 4 + q.x] / 16.0;
}

// In [0, 1).
float bayer8(vec2 p) {
	ivec2 q = ivec2(mod(p, 8.0));
	return BAYER8[q.y * 8 + q.x] / 64.0;
}

// An integer mix in the spirit of a PCG output step, written from its
// description: multiply by an odd constant, xor-shift, repeat. Uniform enough
// for film grain; nothing here is cryptographic or copied.
uint mix_bits(uint v) {
	v = v * 747796405u + 2891336453u;
	v = ((v >> ((v >> 28u) + 4u)) ^ v) * 277803737u;
	return (v >> 22u) ^ v;
}

// In [0, 1), per pixel and per grain frame.
float hash(vec2 p, float frame) {
	uint h = mix_bits(uint(p.x) + mix_bits(uint(p.y) + mix_bits(uint(frame))));
	return float(h) / 4294967296.0;
}

vec3 bloom(vec2 uv, vec2 px) {
	vec3 sum = vec3(0.0);
	for (int i = 0; i < bloom_taps; i++) {
		// Eight taps on the inner ring, eight on the outer one turned by half a step.
		int ring = i / 8;
		float angle = (float(i % 8) + 0.5 * float(ring)) * (TAU / 8.0);
		float radius = (ring == 0 ? bloom_radii.x : bloom_radii.y) * px_scale;
		vec3 tap = texture(screen, uv + vec2(cos(angle), sin(angle)) * radius * px).rgb;
		float high = max(tap.r, max(tap.g, tap.b));
		float chroma = high - min(tap.r, min(tap.g, tap.b));
		// Keyed on chroma, not luminance: near-grey text never glows.
		sum += tap * smoothstep(bloom_key.x, bloom_key.y, chroma) * high;
	}
	return sum / float(max(bloom_taps, 1));
}

void fragment() {
	vec2 p = FRAGCOORD.xy;
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;

	// 1. Chromatic aberration, radial: the centre stays sharp, the edges tear.
	vec3 c;
	if (ca_px > 0.0) {
		vec2 d = normalize(uv - 0.5 + vec2(1e-5)) * ca_px * px_scale * px;
		c = vec3(texture(screen, uv + d).r, texture(screen, uv).g, texture(screen, uv - d).b);
	} else {
		c = texture(screen, uv).rgb;
	}

	// 2. Bloom.
	if (bloom_taps > 0) {
		c += bloom_strength * bloom(uv, px);
	}

	// 3. Alert wash.
	c = mix(c, wash.rgb, wash.a);

	// 4. Vignette.
	float aspect = px.y / px.x;
	vec2 half_diagonal = vec2(aspect, 1.0) * 0.5;
	float r = length((uv - 0.5) * vec2(aspect, 1.0)) / length(half_diagonal);
	c *= 1.0 - vignette * smoothstep(vignette_start, 1.0, r);

	// 5. Scanlines: one dark row per period, static.
	if (int(p.y) % scan_period == 0) {
		c *= 1.0 - scan_depth;
	}

	// 6. Grain, the same on every channel.
	float n = hash(floor(p), floor(TIME * grain_fps));
	c += (n - 0.5) * 2.0 * grain_amp;

	// 7. Ordered dither: mean-preserving, so it changes no contrast.
	float steps = dither_levels - 1.0;
	c = floor(c * steps + bayer4(p)) / steps;

	// 8. Dissolve: the frame is ground where the cell's threshold is under it.
	if (bayer8(floor(p / dissolve_cell)) < dissolve) {
		c = ground.rgb;
	}

	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
