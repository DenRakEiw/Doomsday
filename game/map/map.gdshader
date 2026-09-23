shader_type canvas_item;
// The world map of spec ui-foundation.md §7.3.
//
// The quad is the ID map at 1 : 1, so UV maps a fragment to exactly one ID-map
// texel. Regions are told apart by their *decoded index*, never by comparing
// colours: a filtered or compressed ID map would invent regions along every
// border, which is why `id_map` is fetched with `texelFetch` and imported
// lossless, unfiltered and without mipmaps.
//
// No colour lives here. Every colour arrives as a uniform that `map_view.gd`
// sets from `UiTokens` (CLAUDE.md, *Constants*).

// Borders are drawn at 90 % (§7.3). How far an overlay covers the land is a
// token like every colour here, so it arrives as a uniform.
const float BORDER_STRENGTH = 0.9;

const int FLAG_DARK = 2;
// m3-screens §8.1: `RegionData.FLAG_DORMANT`, and how much of the overlay a
// held region keeps.
const int FLAG_DORMANT = 32;
const float DORMANT_MIX = 0.5;

const int OVERLAY_PENETRATION = 0;
const int OVERLAY_CONTROL = 1;
const int OVERLAY_POPULATION = 2;

uniform sampler2D id_map : filter_nearest, repeat_disable;
uniform sampler2D land_mask : filter_linear, repeat_disable;
uniform sampler2D border_mask : filter_linear, repeat_disable;
// 256 × 2: pixel (i, 0) is region i's own numbers, (i, 1) what the interface is
// saying about it right now (loop-mechanics.md 16.3.1).
uniform sampler2D region_data : filter_nearest, repeat_disable;
uniform sampler2D ramp : filter_linear, repeat_disable;

uniform int hover_index;
uniform int selected_index;
uniform int overlay_mode;
// In map pixels, kept at about two screen pixels by the camera (§7.5).
uniform float outline_px;

uniform vec4 map_land : source_color;
uniform vec4 map_dark : source_color;
uniform vec4 map_border : source_color;
uniform vec4 map_border_dark : source_color;
uniform vec4 map_select : source_color;
uniform vec4 map_death : source_color;
// The accent, and the four faction colours a world status is drawn in.
uniform vec4 accent : source_color;
uniform vec4 faction_1 : source_color;
uniform vec4 faction_2 : source_color;
uniform vec4 faction_3 : source_color;
uniform vec4 faction_4 : source_color;
uniform float hover_gain;
// `UiTokens.MAP_OVERLAY_MIX`: how much of the ramp's colour covers the land.
uniform float overlay_mix;

// The colour of row 1's status index: 1 is the player's, 2…5 a faction's.
vec3 status_color(int index) {
	if (index == 2) { return faction_1.rgb; }
	if (index == 3) { return faction_2.rgb; }
	if (index == 4) { return faction_3.rgb; }
	if (index == 5) { return faction_4.rgb; }
	return accent.rgb;
}

int region_index(ivec2 texel, ivec2 size) {
	ivec2 clamped = clamp(texel, ivec2(0), size - ivec2(1));
	vec4 id = texelFetch(id_map, clamped, 0);
	return int(round(id.r * 255.0)) + 256 * int(round(id.g * 255.0));
}

void fragment() {
	ivec2 size = textureSize(id_map, 0);
	ivec2 texel = ivec2(UV * vec2(size));
	int idx = region_index(texel, size);
	if (idx == 0) {
		// The ocean: the backdrop shows through.
		COLOR = vec4(0.0);
	} else {
		vec4 data = texelFetch(region_data, ivec2(idx, 0), 0);
		vec4 face = texelFetch(region_data, ivec2(idx, 1), 0);
		int status = int(round(face.r * 255.0));
		int flags = int(round(data.a * 255.0));
		bool dark = (flags & FLAG_DARK) != 0;
		// m3-screens §8.1: a held region is drawn at half the overlay strength.
		// Never colour alone — the region panel's chip is the second channel.
		float mix_strength = (flags & FLAG_DORMANT) != 0 ? overlay_mix * DORMANT_MIX
			: overlay_mix;

		vec3 col = map_land.rgb;
		if (dark) {
			col = map_dark.rgb;
		} else if (overlay_mode == OVERLAY_POPULATION) {
			col = mix(map_land.rgb, map_death.rgb, (1.0 - data.b) * (mix_strength / overlay_mix));
		} else {
			float v = overlay_mode == OVERLAY_CONTROL ? data.g : data.r;
			if (v > 0.0) {
				col = mix(map_land.rgb, texture(ramp, vec2(v, 0.5)).rgb, mix_strength);
			}
		}

		float border = texture(border_mask, UV).r;
		// A standing status with a border of its own (a Lockdown) takes the
		// border over at full strength, in the status's colour (16.3.1).
		vec3 border_col = dark ? map_border_dark.rgb : map_border.rgb;
		float border_strength = BORDER_STRENGTH;
		if (face.a > 0.5) {
			border_col = status_color(status);
			border_strength = 1.0;
		}
		col = mix(col, border_col, border * border_strength);

		if (idx == hover_index) {
			col *= hover_gain;
		}

		int reach = max(1, int(round(outline_px)));
		ivec2 taps[4] = ivec2[4](
			ivec2(reach, 0), ivec2(-reach, 0), ivec2(0, reach), ivec2(0, -reach));

		// An eligible site and a scope flash are outlined in the accent (16.3.1).
		// Only this region's own edge is drawn, so two neighbouring eligible
		// regions stay told apart.
		if (face.g > 0.5 || face.b > 0.5) {
			for (int i = 0; i < 4; i++) {
				if (region_index(texel + taps[i], size) != idx) {
					col = accent.rgb;
				}
			}
		}

		// The selection wins wherever both apply.
		if (selected_index != 0) {
			for (int i = 0; i < 4; i++) {
				int neighbour = region_index(texel + taps[i], size);
				// The outline sits on both sides of the selected region's edge,
				// so it stays visible against land and against the ocean.
				if (neighbour != idx
						&& (neighbour == selected_index || idx == selected_index)) {
					col = map_select.rgb;
				}
			}
		}

		// The ID map is hard-edged by design; the coastline's anti-aliasing is
		// the land mask's job.
		COLOR = vec4(col, texture(land_mask, UV).r);
	}
}
