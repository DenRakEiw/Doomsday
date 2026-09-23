extends GutTest
## The component library of spec ui-foundation.md §4, state by state.
##
## Every component is put in the tree with the real theme, because half of what
## §4 promises — a variation, a minimum size, a re-parented row — only exists
## once `_ready` has run. Motion is switched off through `Settings`, so a tween
## finishes in the same frame and a test never waits on a clock.

## The nine glyphs of ui-foundation §4.3, the five of m3-screens §3.4.1, and the
## four asset shapes and the three event marks of loop-mechanics §16.3.2.
const GLYPH_COUNT: int = 21

const STAT_BAR: PackedScene = preload("res://ui/components/stat_bar.tscn")

var _root: Control = null
var _reduced_motion: bool = false
var _locale: String = ""


func before_each() -> void:
	_reduced_motion = Settings.reduced_motion
	_locale = TranslationServer.get_locale()
	Settings.reduced_motion = true
	_root = Control.new()
	_root.theme = ThemeBuilder.build(ThemeBuilder.VARIANT_COLD)
	_root.size = Vector2(1920.0, 1080.0)
	add_child_autofree(_root)


func after_each() -> void:
	Settings.reduced_motion = _reduced_motion
	TranslationServer.set_locale(_locale)


func _add(node: Control) -> void:
	_root.add_child(node)


# ------------------------------------------------------------------ CapsLabel


func test_a_caps_label_uppercases_the_translated_string() -> void:
	TranslationServer.set_locale("de")
	var label: CapsLabel = CapsLabel.new()
	label.label_key = "UI_COMMON_CLOSE"
	_add(label)
	assert_eq(label.text, "SCHLIESSEN")


func test_a_caps_label_follows_the_locale() -> void:
	TranslationServer.set_locale("en")
	var label: CapsLabel = CapsLabel.new()
	label.label_key = "UI_COMMON_CLOSE"
	_add(label)
	assert_eq(label.text, "CLOSE")
	TranslationServer.set_locale("de")
	label.notification(Node.NOTIFICATION_TRANSLATION_CHANGED)
	assert_eq(label.text, "SCHLIESSEN")


func test_a_caps_label_fills_its_placeholders() -> void:
	TranslationServer.set_locale("en")
	var label: CapsLabel = CapsLabel.new()
	_add(label)
	label.set_key("UI_ATTR_TIER", {"tier": 3})
	assert_eq(label.text, "TIER 3 OF 4")


# --------------------------------------------------------------- ConsoleButton


func test_a_console_button_is_at_least_the_minimum_target() -> void:
	var button: ConsoleButton = ConsoleButton.new()
	button.label_key = "UI_REGION_COLLECT"
	_add(button)
	assert_eq(button.custom_minimum_size.y, float(UiTokens.HIT_MIN))


func test_a_console_button_names_itself_to_a_screen_reader_without_shouting() -> void:
	TranslationServer.set_locale("en")
	var button: ConsoleButton = ConsoleButton.new()
	button.label_key = "UI_REGION_COLLECT"
	_add(button)
	assert_eq(button.text, "COLLECT")
	assert_eq(button.accessibility_name, "Collect")


func test_a_primary_button_takes_the_lit_variation() -> void:
	var button: ConsoleButton = ConsoleButton.new()
	button.primary = true
	_add(button)
	assert_eq(button.theme_type_variation, ConsoleButton.VARIATION_PRIMARY)


func test_a_console_button_never_clips_its_label() -> void:
	var button: ConsoleButton = ConsoleButton.new()
	button.label_key = "UI_DOCK_NOT_YET"
	_add(button)
	assert_false(button.clip_text, "a German label is longer and has to be allowed to be")


# ------------------------------------------------------------------ IconButton


func test_an_icon_button_is_a_square_of_the_minimum_target() -> void:
	var button: IconButton = IconButton.new()
	_add(button)
	assert_eq(button.custom_minimum_size, Vector2(float(UiTokens.HIT_MIN),
		float(UiTokens.HIT_MIN)))


func test_every_glyph_of_the_spec_draws() -> void:
	# ui-foundation §4.3 lists nine, m3-screens §3.4.1 five more; drawing each one
	# is what proves there is no unhandled case.
	assert_eq(IconButton.Glyph.size(), GLYPH_COUNT)
	assert_eq(Glyphs.Glyph.size(), GLYPH_COUNT, "the button's alias is the same enum")
	for glyph: int in IconButton.Glyph.values():
		var button: IconButton = IconButton.new()
		button.glyph = glyph
		button.tooltip_key = "UI_COMMON_CLOSE"
		_add(button)
		button.queue_redraw()
	_root.queue_redraw()
	assert_eq(_root.get_child_count(), GLYPH_COUNT)


func test_an_icon_button_is_named_by_its_tooltip() -> void:
	TranslationServer.set_locale("en")
	var button: IconButton = IconButton.new()
	button.tooltip_key = "UI_HUD_SPEED_PAUSE"
	_add(button)
	assert_eq(button.tooltip_text, "Pause")
	assert_eq(button.accessibility_name, "Pause")


# ----------------------------------------------------------------- ConsolePanel


func test_a_panel_moves_what_the_scene_put_in_it_into_the_content_box() -> void:
	var panel: ConsolePanel = ConsolePanel.new()
	var label: Label = Label.new()
	panel.add_child(label)
	_add(panel)
	assert_eq(label.get_parent(), panel.content)


func test_a_titled_panel_starts_with_the_title_and_its_rule() -> void:
	var panel: ConsolePanel = ConsolePanel.new()
	panel.title_key = "UI_REGION_ATTRIBUTES"
	_add(panel)
	assert_is(panel.content.get_child(0), CapsLabel)
	assert_is(panel.content.get_child(1), HSeparator)


func test_an_alerting_panel_changes_its_variation_and_not_its_style_box() -> void:
	var panel: ConsolePanel = ConsolePanel.new()
	_add(panel)
	assert_eq(panel.theme_type_variation, ConsolePanel.VARIATION)
	panel.alert = true
	assert_eq(String(panel.theme_type_variation), "ConsolePanelAlert")
	assert_false(panel.has_theme_stylebox_override("panel"),
		"a state is a variation, never a node override")


# ------------------------------------------------------------------------ Chip


func test_a_chip_colours_its_panel_and_its_label_together() -> void:
	var chip: Chip = Chip.new()
	chip.label_key = "UI_PHASE_COVERT"
	chip.kind = Chip.Kind.ALERT
	_add(chip)
	assert_eq(String(chip.theme_type_variation), "ChipAlert")
	var label: CapsLabel = chip.get_child(0) as CapsLabel
	assert_not_null(label)
	assert_eq(String(label.theme_type_variation), "ChipLabelAlert")


func test_a_chip_takes_placeholders() -> void:
	TranslationServer.set_locale("en")
	var chip: Chip = Chip.new()
	_add(chip)
	chip.set_label("UI_REGION_STATE_SEEDED", {"day": 42})
	var label: CapsLabel = chip.get_child(0) as CapsLabel
	assert_eq(label.text, "PRESENT SINCE DAY 42")


# ------------------------------------------------------------------ ValueLabel


func test_a_value_label_is_right_aligned() -> void:
	var label: ValueLabel = ValueLabel.new()
	_add(label)
	assert_eq(label.horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT)


func test_a_rising_value_gets_the_up_arrow_and_the_up_variation() -> void:
	TranslationServer.set_locale("en")
	var label: ValueLabel = ValueLabel.new()
	_add(label)
	label.set_number(1284.5, Format.Kind.COMPUTE)
	label.set_delta(12.0, Format.Kind.COMPUTE)
	assert_eq(label.text, "1,284.5 %s +12" % ValueLabel.ARROW_UP)
	assert_eq(String(label.theme_type_variation), "ValueLabelUp")


func test_a_falling_value_gets_the_down_arrow_and_the_minus_sign() -> void:
	TranslationServer.set_locale("en")
	var label: ValueLabel = ValueLabel.new()
	_add(label)
	label.set_number(1284.5, Format.Kind.COMPUTE)
	label.set_delta(-3.0, Format.Kind.COMPUTE)
	assert_eq(label.text, "1,284.5 %s %s3" % [ValueLabel.ARROW_DOWN, Format.MINUS])
	assert_eq(String(label.theme_type_variation), "ValueLabelDown")


func test_a_delta_of_zero_is_muted_and_has_no_arrow() -> void:
	var label: ValueLabel = ValueLabel.new()
	_add(label)
	label.set_number(10.0, Format.Kind.COMPUTE)
	label.set_delta(0.0, Format.Kind.COMPUTE)
	assert_false(label.text.contains(ValueLabel.ARROW_UP))
	assert_false(label.text.contains(ValueLabel.ARROW_DOWN))
	assert_true(label.text.contains(ValueLabel.PLUS_MINUS), "the zero carries a sign")
	assert_eq(String(label.theme_type_variation), "ValueLabelMuted")


## G2: the compute rate ticked over as `▲ +0` for the whole first week.
func test_a_delta_that_formats_as_zero_is_muted_too() -> void:
	TranslationServer.set_locale("en")
	var label: ValueLabel = ValueLabel.new()
	_add(label)
	label.set_number(10.0, Format.Kind.COMPUTE)
	label.set_delta_in("UI_HUD_COMPUTE_RATE", "rate", 0.03, Format.Kind.COMPUTE)
	assert_false(label.text.contains(ValueLabel.ARROW_UP), label.text)
	assert_false(label.text.contains(Format.MINUS), "and no sign either")
	assert_eq(String(label.theme_type_variation), "ValueLabelMuted")


func test_a_negative_delta_that_formats_as_zero_is_not_a_minus_zero() -> void:
	TranslationServer.set_locale("en")
	var label: ValueLabel = ValueLabel.new()
	_add(label)
	label.set_number(10.0, Format.Kind.COMPUTE)
	label.set_delta(-0.03, Format.Kind.COMPUTE)
	assert_eq(label.text, "10 %s0" % ValueLabel.PLUS_MINUS)
	assert_eq(String(label.theme_type_variation), "ValueLabelMuted")


func test_clearing_the_delta_returns_the_label_to_neutral() -> void:
	var label: ValueLabel = ValueLabel.new()
	_add(label)
	label.set_number(10.0, Format.Kind.COMPUTE)
	label.set_delta(5.0, Format.Kind.COMPUTE)
	label.clear_delta()
	assert_eq(label.text, "10")
	assert_eq(label.theme_type_variation, ValueLabel.VARIATION)


func test_the_large_state_is_its_own_variation() -> void:
	var label: ValueLabel = ValueLabel.new()
	label.large = true
	_add(label)
	assert_eq(String(label.theme_type_variation), "ValueLabelLarge")
	label.set_delta(1.0, Format.Kind.COMPUTE)
	assert_eq(String(label.theme_type_variation), "ValueLabelLargeUp")


func test_a_flash_leaves_the_label_at_its_own_colour_when_motion_is_off() -> void:
	var label: ValueLabel = ValueLabel.new()
	_add(label)
	label.flash()
	assert_eq(label.self_modulate, Color.WHITE)


# --------------------------------------------------------------------- StatBar


func test_a_stat_bar_clamps_its_value() -> void:
	var bar: StatBar = _stat_bar(false)
	bar.set_value(1.4)
	assert_eq(bar.value(), 1.0)
	bar.set_value(-0.2)
	assert_eq(bar.value(), 0.0)


func test_a_stat_bar_reads_its_value_out_as_a_percentage() -> void:
	TranslationServer.set_locale("en")
	var bar: StatBar = _stat_bar(false)
	bar.set_value(0.423)
	var value: ValueLabel = bar.get_node("%Value") as ValueLabel
	assert_eq(value.text, "42%")


func test_a_bar_reads_its_number_out_again_in_the_new_language() -> void:
	var bar: StatBar = _stat_bar(false)
	TranslationServer.set_locale("en")
	bar.set_value(0.42)
	var english: String = (bar.get_node("%Value") as Label).text
	TranslationServer.set_locale("de")
	var german: String = (bar.get_node("%Value") as Label).text
	TranslationServer.set_locale("en")
	assert_ne(german, english, "German puts a space before the percent sign (§8.5)")
	assert_eq(german, "42 %")


func test_a_raw_bar_shows_the_number_and_not_the_share() -> void:
	TranslationServer.set_locale("en")
	var bar: StatBar = _stat_bar(false)
	bar.set_value_raw(0.6, 12.0, Format.Kind.PLAIN)
	var value: ValueLabel = bar.get_node("%Value") as ValueLabel
	assert_eq(value.text, "12")
	assert_almost_eq(bar.value(), 0.6, 0.0001)


func test_the_fill_follows_the_value_with_motion_off() -> void:
	var bar: StatBar = _stat_bar(false)
	bar.set_value(0.75)
	var fill: StatBarFill = bar.get_node("%Fill") as StatBarFill
	assert_almost_eq(fill.displayed_value, 0.75, 0.0001)


func test_the_fill_is_the_same_type_as_the_bar_so_the_variation_colours_it() -> void:
	var bar: StatBar = _stat_bar(false)
	bar.theme_type_variation = &"StatBarHarm"
	bar.notification(Control.NOTIFICATION_THEME_CHANGED)
	var fill: StatBarFill = bar.get_node("%Fill") as StatBarFill
	assert_eq(String(fill.theme_type_variation), "StatBarHarm")
	assert_eq(fill.get_theme_color(&"fill"), UiTokens.STAT_HARM)


func test_the_compact_bar_puts_the_same_three_nodes_on_one_row() -> void:
	var bar: StatBar = _stat_bar(true)
	var row: HBoxContainer = bar.get_node("%CompactRow") as HBoxContainer
	assert_eq(row.get_child_count(), 3, "label, bar and value share one row")
	assert_true(row.visible)
	assert_false((bar.get_node("%Rows") as Control).visible)
	assert_eq(bar.custom_minimum_size.y, float(UiTokens.BAR_COMPACT_HEIGHT))


func test_the_full_bar_is_two_rows_and_the_taller_minimum() -> void:
	var bar: StatBar = _stat_bar(false)
	assert_eq((bar.get_node("%Head") as Control).get_child_count(), 2)
	assert_eq(bar.custom_minimum_size.y, float(UiTokens.BAR_MIN_HEIGHT))


# ------------------------------------------------------------------ SlidePanel


func test_a_slide_panel_starts_closed_and_hidden() -> void:
	var panel: Control = _slide_child(_slide_panel(SlidePanel.Edge.LEFT))
	assert_false(panel.visible, "a closed panel leaves no hit area behind")


func test_opening_shows_the_panel_at_the_edge_it_belongs_to() -> void:
	var slide: SlidePanel = _slide_panel(SlidePanel.Edge.LEFT)
	slide.open()
	var panel: Control = _slide_child(slide)
	assert_true(slide.is_open)
	assert_true(panel.visible)
	assert_almost_eq(panel.position.x, 0.0, 0.5)


func test_closing_takes_the_panel_off_the_screen_again() -> void:
	var slide: SlidePanel = _slide_panel(SlidePanel.Edge.LEFT)
	slide.open()
	slide.close()
	var panel: Control = _slide_child(slide)
	assert_false(slide.is_open)
	assert_false(panel.visible)
	assert_almost_eq(panel.position.x, -panel.size.x, 0.5)


func test_a_second_open_while_open_changes_nothing() -> void:
	var slide: SlidePanel = _slide_panel(SlidePanel.Edge.LEFT)
	slide.open()
	var before: Vector2 = _slide_child(slide).position
	slide.open()
	assert_eq(_slide_child(slide).position, before)


func test_a_side_panel_keeps_the_width_of_the_spec() -> void:
	var slide: SlidePanel = _slide_panel(SlidePanel.Edge.RIGHT)
	slide.open()
	var panel: Control = _slide_child(slide)
	var wanted: float = clampf(_root.get_viewport_rect().size.x * SlidePanel.WIDTH_SHARE,
		SlidePanel.WIDTH_MIN, SlidePanel.WIDTH_MAX)
	assert_almost_eq(panel.size.x, floorf(wanted), 0.5)


func test_a_bottom_sheet_takes_half_the_height() -> void:
	var slide: SlidePanel = _slide_panel(SlidePanel.Edge.BOTTOM)
	slide.open()
	var panel: Control = _slide_child(slide)
	assert_almost_eq(panel.size.y,
		floorf(_root.get_viewport_rect().size.y * SlidePanel.HEIGHT_SHARE), 0.5)


# ----------------------------------------------------------------- the pieces


func _stat_bar(compact: bool) -> StatBar:
	var bar: StatBar = STAT_BAR.instantiate() as StatBar
	bar.label_key = "UI_TERM_PENETRATION"
	bar.compact = compact
	_add(bar)
	return bar


func _slide_panel(edge: SlidePanel.Edge) -> SlidePanel:
	var slide: SlidePanel = SlidePanel.new()
	slide.edge = edge
	var panel: ConsolePanel = ConsolePanel.new()
	slide.add_child(panel)
	_add(slide)
	return slide


func _slide_child(slide: SlidePanel) -> Control:
	return slide.get_child(0) as Control
