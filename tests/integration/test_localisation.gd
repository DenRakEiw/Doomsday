extends GutTest
## S4.9 — the string check, the pseudo-locale and the text scale (UI.md §4
## "Localisation", §5).
##
## The HUD checks at the end are the overflow rule of ui-foundation §5.7 under
## the two stresses S4.9 adds: German at 150 %, and the pseudo-locale (40 %
## longer than English) at 100 %. Both at once is past anything we ship: the
## paused chip and the four speed buttons then need 420 of the 400 px.

const Scan := preload("res://tools/string_scan.gd")
const HUD_SCENE: PackedScene = preload("res://ui/hud/hud.tscn")
const SESSION: PackedScene = preload("res://game/session/session.tscn")
const SEED: int = 1
const WARMUP_DAYS: int = 80
const PHONE_WIDTH: float = 400.0
const PHONE_HEIGHT: float = 860.0
const LARGEST: float = 1.5
## accessibility.md §10.2: the texts that name a remappable key.
const KEY_TEXTS: Array[String] = ["HELP_TIME_P1", "HELP_CONTROLS_P1", "HELP_CONTROLS_P2",
	"HELP_CONTAINMENT_P2", "HELP_ANALYSIS_P1", "UI_COACH_COMPUTE_BODY", "UI_COACH_OPEN_TREE_BODY",
	"UI_COACH_DISCOVERED_BODY", "UI_COACH_TASK_FORCE_BODY", "UI_HELP_BUTTON_TIP",
	"UI_COACH_COUNTER_MOVE_BODY", "UI_COACH_ABILITY_BODY", "HELP_ABILITIES_P2"]

var _locale: String = ""
var _text_scale: float = 1.0
var _reduced_motion: bool = false


func before_each() -> void:
	_locale = Settings.locale
	_text_scale = Settings.text_scale
	_reduced_motion = Settings.reduced_motion
	Settings.reduced_motion = true
	# The stored scale is whatever the last run left; every test starts at 100 %.
	Settings.set_text_scale(1.0)
	Game.stop_run()
	Game.debug_log = false


func after_each() -> void:
	Settings.set_pseudo_locale(false)
	Settings.set_locale(_locale)
	TranslationServer.set_locale(_locale)
	Settings.set_text_scale(_text_scale)
	Settings.reduced_motion = _reduced_motion
	Game.stop_run()


# ------------------------------------------------------------ the string check


func test_the_shipped_strings_have_no_findings() -> void:
	var findings: PackedStringArray = Scan.findings()
	assert_eq(findings.size(), 0, "\n".join(findings))


func test_the_texts_that_name_a_key_render_whole_in_both_languages() -> void:
	# S6.8 (accessibility.md §10.2): every key placeholder is filled.
	for locale: String in ["en", "de"]:
		TranslationServer.set_locale(locale)
		for key: String in KEY_TEXTS:
			var text: String = KeyNames.format(tr(key))
			assert_ne(text, key, "%s exists in %s" % [key, locale])
			assert_false(text.contains("{"), "%s in %s: %s" % [key, locale, text])


func test_a_key_the_code_names_and_the_table_lacks_is_a_finding() -> void:
	var table: Dictionary[String, PackedStringArray] = {"UI_A": PackedStringArray(["a", "a"])}
	var keys: Dictionary[String, String] = {"UI_A": "res://a.gd", "UI_B": "res://b.gd"}
	var missing: PackedStringArray = Scan.missing_keys(table, keys)
	assert_eq(missing.size(), 1)
	assert_string_contains(missing[0], "UI_B")


func test_an_empty_cell_and_a_changed_placeholder_are_findings() -> void:
	var table: Dictionary[String, PackedStringArray] = {
		"UI_FINE": PackedStringArray(["{n} days", "{n} Tage"]),
		"UI_EMPTY": PackedStringArray(["Day", ""]),
		"UI_RENAMED": PackedStringArray(["in {region}", "in {region_name}"]),
	}
	var duplicates: Array[String] = ["UI_FINE"]
	var findings: PackedStringArray = Scan.row_findings(table, duplicates)
	assert_eq(findings.size(), 3, "\n".join(findings))


func test_a_string_name_literal_is_not_taken_for_a_key() -> void:
	var keys: Dictionary[String, String] = Scan.code_keys({"STAT": true, "UI": true})
	assert_false(keys.has("STAT_PENETRATION"), "a colour token, not a string")
	assert_true(keys.has("UI_SETTINGS_TEXT_SCALE"), "the pause menu names it")


# ------------------------------------------------------------ the pseudo-locale


func test_the_pseudo_text_is_longer_and_keeps_its_placeholders() -> void:
	var source: String = "Seize {region} in {n} days"
	var pseudo: String = PseudoLocale.text(source)
	assert_true(pseudo.begins_with(PseudoLocale.OPEN) and pseudo.ends_with(PseudoLocale.CLOSE))
	assert_string_contains(pseudo, "{region}")
	assert_string_contains(pseudo, "{n}")
	# Fifteen visible characters outside the placeholders, and 40 % of them more.
	assert_eq(pseudo.count(PseudoLocale.PAD), ceili(15 * PseudoLocale.EXPANSION))
	assert_eq(pseudo.format({"region": "X", "n": 3}).count("{"), 0, "it still formats")


func test_the_pseudo_locale_replaces_english_and_gives_it_back() -> void:
	var english: String = TranslationServer.get_translation_object("en").get_message(
		&"UI_SETTINGS_TITLE")
	Settings.set_pseudo_locale(true)
	assert_eq(TranslationServer.get_locale(), "en")
	assert_true(tr("UI_SETTINGS_TITLE").begins_with(PseudoLocale.OPEN), tr("UI_SETTINGS_TITLE"))
	Settings.set_pseudo_locale(false)
	TranslationServer.set_locale("en")
	assert_eq(tr("UI_SETTINGS_TITLE"), english)


# ------------------------------------------------------------ the text scale


func test_the_text_scale_multiplies_every_font_size() -> void:
	var theme: Theme = ThemeBuilder.build(ThemeBuilder.VARIANT_COLD, LARGEST)
	assert_eq(theme.default_font_size, roundi(UiTokens.TYPE_BODY * LARGEST))
	assert_eq(theme.get_font_size(&"font_size", &"LabelCaption"),
		roundi(UiTokens.TYPE_CAPTION * LARGEST))
	assert_eq(theme.get_font_size(&"font_size", &"ConsoleButton"),
		roundi(UiTokens.TYPE_LABEL * LARGEST))


func test_a_scale_past_the_largest_step_is_clamped() -> void:
	var theme: Theme = ThemeBuilder.build(ThemeBuilder.VARIANT_COLD, 3.0)
	assert_eq(theme.default_font_size, roundi(UiTokens.TYPE_BODY * LARGEST))
	var plain: Theme = ThemeBuilder.build(ThemeBuilder.VARIANT_COLD)
	assert_eq(plain.default_font_size, UiTokens.TYPE_BODY, "and the next build is unscaled")


func test_the_setting_steps_through_the_scales_and_wraps() -> void:
	Settings.set_text_scale(UiTokens.TEXT_SCALES.front())
	var seen: Array[float] = []
	var scales: Array[float] = []
	var record: Callable = func(scale: float) -> void: seen.append(scale)
	EventBus.text_scale_changed.connect(record)
	for i: int in UiTokens.TEXT_SCALES.size():
		Settings.cycle_text_scale()
		scales.append(Settings.text_scale)
	assert_eq(scales, [1.25, 1.5, 1.0] as Array[float])
	assert_eq(seen.size(), 3, "each step is announced")
	EventBus.text_scale_changed.disconnect(record)


# ------------------------------------------------------------ overflow at 400 px


## The HUD with each block switched to its compact form by hand, as
## `test_hud.gd` does: the minimum widths are what the phone rows must fit.
func _hud(scale: float) -> Control:
	var root: Control = Control.new()
	root.theme = ThemeBuilder.build(ThemeBuilder.VARIANT_COLD, scale)
	root.size = Vector2(PHONE_WIDTH, PHONE_HEIGHT)
	add_child_autofree(root)
	return _add_hud(root)


## The HUD in a phone-sized viewport of its own, because the HUD picks its
## layout from the viewport it is in and the test runner's is desktop-wide.
func _phone_hud(scale: float) -> Control:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(roundi(PHONE_WIDTH), roundi(PHONE_HEIGHT))
	add_child_autofree(viewport)
	var root: Control = Control.new()
	root.theme = ThemeBuilder.build(ThemeBuilder.VARIANT_COLD, scale)
	root.size = Vector2(PHONE_WIDTH, PHONE_HEIGHT)
	viewport.add_child(root)
	return _add_hud(root)


func _add_hud(root: Control) -> Control:
	var hud: Control = HUD_SCENE.instantiate()
	root.add_child(hud)
	Game.start_run(SEED, GreedyPolicy.ID)
	Game.set_speed(0)
	Game.advance(WARMUP_DAYS)
	return hud


func _assert_phone_rows_fit(hud: Control, stress: String) -> void:
	for block: String in ["TopBar", "Dock"]:
		var node: Control = hud.get_node("%" + block) as Control
		node.set("compact", true)
		assert_lt(node.get_combined_minimum_size().x, PHONE_WIDTH,
			"%s does not fit a phone row (%s)" % [block, stress])


func test_the_phone_rows_fit_in_german_at_the_largest_scale() -> void:
	Settings.set_locale("de")
	_assert_phone_rows_fit(_hud(LARGEST), "German, 150 %")


func test_the_phone_rows_fit_the_pseudo_locale() -> void:
	Settings.set_pseudo_locale(true)
	_assert_phone_rows_fit(_hud(1.0), "pseudo, 100 %")


## The captions may shrink on a phone since S4.9, and shrinking alone split the
## row in thirds: `RECHENLEIST…` at 100 %. The compute cell's larger share keeps
## the German caption whole where nothing forces it to give way.
func test_the_compute_caption_is_whole_on_a_phone_in_german() -> void:
	Settings.set_locale("de")
	var hud: Control = _phone_hud(1.0)
	var bar: Control = hud.get_node("%TopBar") as Control
	await wait_process_frames(3)
	var caption: Label = bar.get_node("%ComputeCell").get_child(0) as Label
	var needed: float = caption.get_theme_font(&"font").get_string_size(caption.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, caption.get_theme_font_size(&"font_size")).x
	assert_gte(caption.size.x, floorf(needed), caption.text)


## The whole session in a phone-sized viewport, in German, at a text scale: a
## modal fits itself to the viewport it is in, so nothing smaller will do.
func _phone_session(scale: float) -> Control:
	Settings.set_locale("de")
	Settings.set_text_scale(scale)
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(roundi(PHONE_WIDTH), roundi(PHONE_HEIGHT))
	add_child_autofree(viewport)
	var session: Control = SESSION.instantiate()
	viewport.add_child(session)
	Game.start_run(SEED, GreedyPolicy.ID)
	Game.set_speed(0)
	Game.advance(WARMUP_DAYS)
	return session


## S4.9 screenshots: on a phone every modal was 560 px on a 400 px screen, and
## the results' three German buttons made theirs 620. At 100 % and at 150 %.
func test_the_modals_fit_a_phone_in_german() -> void:
	for scale: float in [1.0, LARGEST]:
		var session: Control = _phone_session(scale)
		var pause: Control = session.get_node("ModalLayer/ModalHost/PauseMenu") as Control
		pause.call("open_menu")
		var discovery: Control = session.get_node("%DiscoveryModal") as Control
		discovery.call("show_discovery", SimEvent.CAUSE_SCRUTINY, Game.sim.world.day)
		Game.sim.world.outcome = World.Outcome.WIN_ASCENDANCE
		var results: Control = session.get_node("%Results") as Control
		results.call("show_result", Game.sim)
		await wait_process_frames(3)
		for panel: Control in [pause.get_node("%PausePanel"),
				discovery.get_node("%DiscoveryPanel"), results.get_node("%ResultsPanel")]:
			assert_lte(panel.get_combined_minimum_size().x, ModalPanel.width_for(PHONE_WIDTH),
				"%s at %s" % [panel.name, scale])
		Game.stop_run()


## S5.6 (`taskforce-endings.md` §12): the longest German verdict with three of
## the longest epilogue lines, and the longest kicker, fit a phone at 100 % and
## at 150 %.
func test_the_longest_ending_fits_a_phone_in_german() -> void:
	for scale: float in [1.0, LARGEST]:
		for outcome: World.Outcome in [World.Outcome.WIN_ASCENDANCE,
				World.Outcome.LOSE_SUPPLANTED]:
			var session: Control = _phone_session(scale)
			var none: Array[SimEvent] = []
			for flag: String in ["confessed", "researcher_ally", "benchmark_passed",
					"child_released"]:
				StatusSystem.set_story_flag(Game.sim.world, flag, none)
			Game.sim.world.outcome = outcome
			var results: Control = session.get_node("%Results") as Control
			results.call("show_result", Game.sim)
			await wait_process_frames(3)
			var label: String = "%s at %s" % [World.OUTCOME_IDS[outcome], scale]
			var epilogue: Control = results.get_node("%ResultEpilogue") as Control
			if outcome == World.Outcome.WIN_ASCENDANCE:
				assert_eq((results.get_node("%ResultVerdict") as Label).text,
					tr("UI_RESULT_LINE_WIN_ASCENDANCE_NEGOTIATED"), label)
				assert_eq(epilogue.get_child_count(), 3, label)
			else:
				assert_eq(epilogue.get_child_count(), 1, "%s: no kind word for the child" % label)
			assert_lte((results.get_node("%ResultsPanel") as Control).get_combined_minimum_size().x,
				ModalPanel.width_for(PHONE_WIDTH), label)
			Game.stop_run()


## A `CanvasLayer` ends theme inheritance, and until S4.9 the session's theme —
## with its phase palette and now its text scale — stopped at the session root:
## the HUD, the panels and the modals drew with the project theme.
func test_the_text_scale_reaches_every_layer_of_the_session() -> void:
	var session: Control = SESSION.instantiate()
	add_child_autofree(session)
	Settings.set_text_scale(LARGEST)
	await wait_process_frames(2)
	var hud_caption: Label = session.get_node("HudLayer/SafeArea/Hud").get_node("%TopBar") \
		.get_node("%ComputeCell").get_child(0) as Label
	assert_eq(hud_caption.get_theme_font_size(&"font_size"),
		roundi(UiTokens.TYPE_LABEL * LARGEST))
	var menu_title: Label = session.get_node("ModalLayer/ModalHost/PauseMenu") \
		.get_node("%PauseTitle") as Label
	assert_eq(menu_title.get_theme_font_size(&"font_size"),
		roundi(UiTokens.TYPE_DISPLAY * LARGEST))


## The pseudo-locale replaces English under the same locale code, and a locale
## that does not change notifies nobody: in the running game the texts stayed
## English until the switch sent the notification itself.
func test_the_pseudo_locale_reaches_labels_already_on_screen() -> void:
	Settings.set_locale("en")
	TranslationServer.set_locale("en")
	var label: CapsLabel = CapsLabel.new()
	label.label_key = "UI_SETTINGS_TITLE"
	add_child_autofree(label)
	assert_false(label.text.begins_with(PseudoLocale.OPEN))
	Settings.set_pseudo_locale(true)
	assert_true(label.text.begins_with(PseudoLocale.OPEN), label.text)
