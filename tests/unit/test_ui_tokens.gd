extends GutTest
## S6.1 — the guards spec polish-visuals.md puts over the tokens: the flash
## limits of §6 and the contrast under the full-screen pass of §8.4. S6.2 — the
## colour floor of §8.3 and the Open accent of §8.2.

## WCAG's floors (§8.4): body text, and the secondary text that is never essential.
const FLOOR_TEXT_1: float = 4.5
const FLOOR_TEXT_2: float = 3.0
## §6 rule 2: the wash may not exceed this alpha.
const ALERT_FLASH_ALPHA_MAX: float = 0.25
## §6 rule 3: no loop faster than 2 Hz.
const PERIOD_MIN_MS: int = 500
const SUFFIX_PERIOD: String = "_PERIOD"
## A spatial period in pixels, not a loop: the scanline pitch.
const PREFIX_FX: String = "FX_"
## The surface §8.4's table measures on.
const SURFACE: StringName = &"BG_2"
## §8.3: map-mark pairs keep a worst-case CIEDE2000 of at least this.
const FLOOR_DELTA_E: float = 9.0
## §8.3's table: the pairs that can meet in one map channel.
const MAP_CHANNEL_PAIRS: Array[Array] = [
	[&"ACCENT", &"CAT_SKY"],
	[&"ACCENT", &"CAT_ORANGE"],
	[&"ACCENT", &"CAT_GREEN"],
	[&"ACCENT", &"CAT_PINK"],
	[&"ACCENT", &"TASK_FORCE"],
	[&"TASK_FORCE", &"CAT_ORANGE"],
	[&"TASK_FORCE", &"CAT_PINK"],
	# S6.8 (accessibility.md §6.2): the four factions against each other and the
	# team, the two event-marker inks, the site outline and the society view.
	[&"CAT_SKY", &"CAT_ORANGE"],
	[&"CAT_SKY", &"CAT_GREEN"],
	[&"CAT_SKY", &"CAT_PINK"],
	[&"CAT_ORANGE", &"CAT_GREEN"],
	[&"CAT_ORANGE", &"CAT_PINK"],
	[&"CAT_GREEN", &"CAT_PINK"],
	[&"TASK_FORCE", &"CAT_SKY"],
	[&"TASK_FORCE", &"CAT_GREEN"],
	[&"ACCENT", &"TEXT_0"],
	[&"ACCENT", &"MAP_SELECT"],
	[&"MAP_SOCIETY", &"CAT_PINK"],
]
## accessibility.md §6.3: WCAG 1.4.11's floor for a mark on the ground it sits on.
const FLOOR_NON_TEXT: float = 3.0
## §11: `INK` on the Open accent fills.
const FLOOR_INK_ON_ACCENT: float = 7.0
const INK_FILLS: Array[StringName] = [&"ACCENT", &"ACCENT_HOVER", &"ACCENT_PRESSED"]
## Sharma, Wu and Dalal (2005), test pair 1: two Lab colours and their CIEDE2000.
const SHARMA_LAB_1: Vector3 = Vector3(50.0, 2.6772, -79.7751)
const SHARMA_LAB_2: Vector3 = Vector3(50.0, 0.0, -82.7485)
const SHARMA_DELTA_E: float = 2.0425
const SHARMA_EPSILON: float = 0.0001

var _variant: StringName = UiTokens.VARIANT_COLD


func before_each() -> void:
	_variant = UiTokens.variant


func after_each() -> void:
	UiTokens.variant = _variant


func test_looping_periods_are_at_least_half_a_second() -> void:
	var script: GDScript = UiTokens
	var constants: Dictionary = script.get_script_constant_map()
	var checked: int = 0
	for constant_name: String in constants:
		if not constant_name.ends_with(SUFFIX_PERIOD) or constant_name.begins_with(PREFIX_FX):
			continue
		checked += 1
		assert_gte(int(constants[constant_name]), PERIOD_MIN_MS, constant_name)
	assert_gt(checked, 0, "the periods were found")


func test_alert_flash_alpha_stays_under_red_flash_limit() -> void:
	assert_lte(UiTokens.ALERT_FLASH_ALPHA, ALERT_FLASH_ALPHA_MAX)


func test_text_contrast_holds_under_the_pass() -> void:
	# The worst place (§8.4): a vignette corner at Full, the scanline's mean over
	# its period. The pass multiplies display values, so the test does too.
	var dim: float = (1.0 - UiTokens.FX_VIGNETTE) \
		* (1.0 - UiTokens.FX_SCANLINE_DEPTH / float(UiTokens.FX_SCANLINE_PERIOD))
	for variant: StringName in [UiTokens.VARIANT_COLD, UiTokens.VARIANT_OPEN]:
		UiTokens.variant = variant
		var ground: Color = UiTokens.color(SURFACE)
		assert_gte(_contrast(UiTokens.color(&"TEXT_1"), ground, dim), FLOOR_TEXT_1,
			"TEXT_1 in %s" % variant)
		assert_gte(_contrast(UiTokens.color(&"TEXT_2"), ground, dim), FLOOR_TEXT_2,
			"TEXT_2 in %s" % variant)


func test_map_channel_pairs_clear_the_colour_floor() -> void:
	for variant: StringName in [UiTokens.VARIANT_COLD, UiTokens.VARIANT_OPEN]:
		UiTokens.variant = variant
		for pair: Array in MAP_CHANNEL_PAIRS:
			var a: StringName = pair[0]
			var b: StringName = pair[1]
			var worst: float = ColourAudit.worst_delta_e(UiTokens.color(a), UiTokens.color(b))
			assert_gte(worst, FLOOR_DELTA_E, "%s vs %s in %s" % [a, b, variant])


func test_open_accent_ink_contrast() -> void:
	UiTokens.variant = UiTokens.VARIANT_OPEN
	for fill: StringName in INK_FILLS:
		assert_gte(ColourAudit.contrast(UiTokens.color(&"INK"), UiTokens.color(fill)),
			FLOOR_INK_ON_ACCENT, fill)


func test_open_accent_is_the_pale_amber_family() -> void:
	# §8.2: the one correction D6.1 made to the Open set.
	assert_eq(UiTokens.OPEN[&"ACCENT"], Color("#FFD08A"))
	assert_eq(UiTokens.OPEN[&"ACCENT_DIM"], Color("#8C6A3A"))
	assert_eq(UiTokens.OPEN[&"ACCENT_HOVER"], Color("#FFE0B0"))
	assert_eq(UiTokens.OPEN[&"ACCENT_PRESSED"], Color("#E8B66C"))


func test_colour_audit_matches_the_published_ciede2000_value() -> void:
	assert_almost_eq(ColourAudit.delta_e(SHARMA_LAB_1, SHARMA_LAB_2), SHARMA_DELTA_E,
		SHARMA_EPSILON)


func test_society_colour_is_the_same_in_both_variants() -> void:
	# §10.2: lavender in both sets, so the view reads the same after the swap.
	assert_false(UiTokens.OPEN.has(&"MAP_SOCIETY"))
	UiTokens.variant = UiTokens.VARIANT_OPEN
	assert_eq(UiTokens.color(&"MAP_SOCIETY"), UiTokens.MAP_SOCIETY)


func test_the_open_accent_clears_the_society_view() -> void:
	# S6.8 (accessibility.md §6.2 lists this pair for the open accent only; the
	# cold accent against the society view is 3.7 — see PROGRESS, Design questions).
	UiTokens.variant = UiTokens.VARIANT_OPEN
	assert_gte(ColourAudit.worst_delta_e(UiTokens.color(&"ACCENT"), UiTokens.color(&"MAP_SOCIETY")),
		FLOOR_DELTA_E)


func test_resting_task_force_red_clears_three_to_one_on_land() -> void:
	# S6.8 (accessibility.md §6.3 item 1): `#C23A3A` was 2.9 : 1.
	for variant: StringName in [UiTokens.VARIANT_COLD, UiTokens.VARIANT_OPEN]:
		UiTokens.variant = variant
		assert_gte(ColourAudit.contrast(UiTokens.color(&"TASK_FORCE_DIM"),
			UiTokens.color(&"MAP_LAND")), FLOOR_NON_TEXT, String(variant))


func test_text_width_scales_with_the_text() -> void:
	# S6.8 (accessibility.md §8.1).
	var before: float = Settings.text_scale
	Settings.text_scale = 1.5
	assert_almost_eq(UiTokens.text_width(560.0), 840.0, 0.001)
	Settings.text_scale = 1.0
	assert_almost_eq(UiTokens.text_width(560.0), 560.0, 0.001)
	Settings.text_scale = before


## WCAG 2.2 contrast of two sRGB colours, both multiplied by `gain` first.
func _contrast(a: Color, b: Color, gain: float) -> float:
	var la: float = _luminance(a, gain)
	var lb: float = _luminance(b, gain)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _luminance(c: Color, gain: float) -> float:
	return 0.2126 * _linear(c.r * gain) + 0.7152 * _linear(c.g * gain) \
		+ 0.0722 * _linear(c.b * gain)


func _linear(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
