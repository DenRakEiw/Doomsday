extends GutTest
## S6.1 — the guards spec polish-visuals.md puts over the tokens: the flash
## limits of §6 and the contrast under the full-screen pass of §8.4.

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
