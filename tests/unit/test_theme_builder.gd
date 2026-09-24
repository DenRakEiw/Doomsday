extends GutTest
## The built `Theme` against the spec (ui-foundation.md §3.8, §11).
##
## Two properties are checked, and they are the two that keep the interface one
## interface: every type variation the spec names exists, and **no colour and no
## font size in the theme comes from anywhere but `UiTokens`**. A hand-picked
## grey in a `StyleBox` would pass review and fail here.

## §3.8's list, written out: the test has to fail when one disappears, so it may
## not read the same constant the builder does.
const SPEC_VARIATIONS: Array[String] = ["ConsolePanel", "ConsolePanelRaised", "ConsoleButton",
	"ConsoleButtonPrimary", "IconButton", "StatBar", "StatBarPenetration", "StatBarFootprint",
	"StatBarHarm", "ValueLabel", "LabelCaps", "LabelCaption", "LabelDisplay", "LabelHeading",
	"Ticker", "Chip"]
## Named in §4.5, §4.7 and §4.1 rather than in the list of §3.8, and the
## architecture card and the alert button of screens-full.md §4.1 and §6.3.
const COMPONENT_VARIATIONS: Array[String] = ["ValueLabelLarge", "ChipAccent", "ChipAlert",
	"ConsolePanelAlert", "ArchitectureCard", "ConsoleButtonAlert", "ChipTaskForce",
	"LabelCaptionHint"]

var _theme: Theme = null


func before_all() -> void:
	_theme = ThemeBuilder.build(ThemeBuilder.VARIANT_COLD)


func test_every_variation_of_the_spec_exists() -> void:
	for variation: String in SPEC_VARIATIONS:
		assert_ne(String(_theme.get_type_variation_base(variation)), "",
			"%s is not a type variation" % variation)


func test_the_component_variations_exist() -> void:
	for variation: String in COMPONENT_VARIATIONS:
		assert_ne(String(_theme.get_type_variation_base(variation)), "",
			"%s has no base type" % variation)


func test_a_variation_varies_the_type_the_spec_says() -> void:
	assert_eq(String(_theme.get_type_variation_base("ConsoleButton")), "Button")
	assert_eq(String(_theme.get_type_variation_base("ConsolePanel")), "PanelContainer")
	assert_eq(String(_theme.get_type_variation_base("StatBar")), "Control")
	assert_eq(String(_theme.get_type_variation_base("StatBarHarm")), "StatBar")


func test_an_unknown_variant_falls_back_to_cold() -> void:
	var theme: Theme = ThemeBuilder.build("warm")
	assert_eq(theme.get_color("font_color", "Label"), UiTokens.TEXT_0,
		"an unknown variant is the cold set, not an empty theme")
	assert_eq(String(UiTokens.variant), ThemeBuilder.VARIANT_COLD,
		"and building one leaves the live palette alone")


## m3-screens §6.2: the same builder produces both sets, and the open one is
## made of open values and cold ones — never of a colour from somewhere else.
func test_open_variant_uses_only_open_or_cold_tokens() -> void:
	var theme: Theme = ThemeBuilder.build(ThemeBuilder.VARIANT_OPEN)
	var allowed: Array[Color] = _token_colours()
	for value: Color in UiTokens.OPEN.values():
		allowed.append(value)
	allowed.append(_wash(UiTokens.VARIANT_OPEN, false))
	allowed.append(_wash(UiTokens.VARIANT_OPEN, true))
	for type: String in theme.get_color_type_list():
		for name: String in theme.get_color_list(type):
			var colour: Color = theme.get_color(name, type)
			assert_true(allowed.has(colour),
				"%s/%s is %s, which is in neither set" % [type, name, colour.to_html()])


func test_the_open_variant_is_a_different_theme() -> void:
	var cold: Theme = ThemeBuilder.build(ThemeBuilder.VARIANT_COLD)
	var open: Theme = ThemeBuilder.build(ThemeBuilder.VARIANT_OPEN)
	assert_eq(cold.get_color("font_color", "Label"), UiTokens.TEXT_0)
	assert_eq(open.get_color("font_color", "Label"), UiTokens.OPEN[&"TEXT_0"])
	assert_eq(open.get_color("font_color", "ValueLabelDown"), UiTokens.MAP_DEATH,
		"a colour the open set does not change keeps its cold value")


## The pressed surface in one palette, without leaving the live one switched.
func _wash(variant: StringName, raised: bool) -> Color:
	var previous: StringName = UiTokens.variant
	UiTokens.variant = variant
	var colour: Color = UiTokens.accent_wash_raised() if raised else UiTokens.accent_wash()
	UiTokens.variant = previous
	return colour


func test_no_colour_comes_from_outside_the_tokens() -> void:
	var allowed: Array[Color] = _token_colours()
	for type: String in _theme.get_color_type_list():
		for name: String in _theme.get_color_list(type):
			var colour: Color = _theme.get_color(name, type)
			assert_true(allowed.has(colour),
				"%s/%s is %s, which is not a token" % [type, name, colour.to_html()])


func test_no_stylebox_colour_comes_from_outside_the_tokens() -> void:
	var allowed: Array[Color] = _token_colours()
	for type: String in _theme.get_stylebox_type_list():
		for name: String in _theme.get_stylebox_list(type):
			for colour: Color in _stylebox_colours(_theme.get_stylebox(name, type)):
				assert_true(allowed.has(colour),
					"%s/%s draws %s, which is not a token" % [type, name, colour.to_html()])


func test_no_font_size_comes_from_outside_the_type_scale() -> void:
	var allowed: Array[int] = _token_sizes()
	for type: String in _theme.get_font_size_type_list():
		for name: String in _theme.get_font_size_list(type):
			var size: int = _theme.get_font_size(name, type)
			assert_true(allowed.has(size), "%s/%s is %d px, which is not in the type scale" % [
				type, name, size])
	assert_true(allowed.has(_theme.default_font_size), "the default size is not in the scale")


func test_the_theme_carries_the_project_fonts() -> void:
	assert_not_null(_theme.default_font, "no default font")
	for type: String in ["LabelDisplay", "LabelCaps", "ValueLabelLarge"]:
		assert_not_null(_theme.get_font("font", type), "%s has no font" % type)


func test_the_display_font_is_cut_at_the_weight_the_scale_asks_for() -> void:
	var display: FontVariation = _theme.get_font("font", "LabelDisplay") as FontVariation
	assert_not_null(display, "the display font is not a variation of the variable font")
	assert_eq(int(display.variation_opentype[ThemeBuilder.TAG_WEIGHT]),
		ThemeBuilder.WEIGHT_SEMI_BOLD)
	var heading: FontVariation = _theme.get_font("font", "LabelHeading") as FontVariation
	assert_eq(int(heading.variation_opentype[ThemeBuilder.TAG_WEIGHT]),
		ThemeBuilder.WEIGHT_MEDIUM)


func test_the_stat_bar_variations_pick_the_fill_colours_of_the_spec() -> void:
	assert_eq(_theme.get_color("fill", "StatBarPenetration"), UiTokens.STAT_PENETRATION)
	assert_eq(_theme.get_color("fill", "StatBarFootprint"), UiTokens.STAT_FOOTPRINT)
	assert_eq(_theme.get_color("fill", "StatBarHarm"), UiTokens.STAT_HARM)


func test_every_tappable_type_is_at_least_the_minimum_target() -> void:
	# The size itself is the component's (`custom_minimum_size`), but the padding
	# is the theme's and must not make a button smaller than it.
	for type: String in ["ConsoleButton", "ConsoleButtonPrimary"]:
		var box: StyleBoxFlat = _theme.get_stylebox("normal", type) as StyleBoxFlat
		assert_lt(box.content_margin_top * 2.0, float(UiTokens.HIT_MIN),
			"%s pads more than the minimum target is tall" % type)


# ----------------------------------------------------------------- the pieces


## Every colour `UiTokens` defines, plus the ones it derives: the wash of §4.2
## and the transparent ground of a focus ring, which is the absence of a colour.
func _token_colours() -> Array[Color]:
	var colours: Array[Color] = [UiTokens.accent_wash(), UiTokens.accent_wash_raised(),
		Color.TRANSPARENT]
	var script: GDScript = UiTokens
	for value: Variant in script.get_script_constant_map().values():
		if typeof(value) == TYPE_COLOR:
			colours.append(value)
		elif value is Array:
			for item: Variant in value:
				if typeof(item) == TYPE_COLOR:
					colours.append(item)
	return colours


## Every size in the type scale of §3.2.
func _token_sizes() -> Array[int]:
	var sizes: Array[int] = []
	var script: GDScript = UiTokens
	var constants: Dictionary = script.get_script_constant_map()
	for name: String in constants:
		if name.begins_with("TYPE_") and typeof(constants[name]) == TYPE_INT:
			sizes.append(int(constants[name]))
	return sizes


func _stylebox_colours(box: StyleBox) -> Array[Color]:
	var flat: StyleBoxFlat = box as StyleBoxFlat
	if flat != null:
		return [flat.bg_color, flat.border_color]
	var line: StyleBoxLine = box as StyleBoxLine
	if line != null:
		return [line.color]
	return []


## analysis.md §10: a chart's frame and its focus border.
func test_the_chart_frame_exists() -> void:
	assert_eq(String(_theme.get_type_variation_base("ChartFrame")), "PanelContainer")
	assert_true(_theme.has_stylebox("panel", "ChartFrame"))
	assert_true(_theme.has_stylebox("focus", "ChartFrame"))
