extends GutTest
## The settings file of ui-foundation.md §9.3. Every field falls back on its own,
## and nothing a file can contain may crash a start.
##
## `values_from` is static and reads no file, so none of this touches `user://`.

const SettingsScript := preload("res://game/autoload/settings.gd")


func _values(raw: Variant) -> Dictionary:
	return SettingsScript.values_from(raw, SettingsScript.LOCALE_EN)


func test_a_complete_file_is_read_as_written() -> void:
	var values: Dictionary = _values({
		"version": 1, "locale": "de", "reduced_motion": true, "text_scale": 1.25,
	})
	assert_eq(str(values[SettingsScript.KEY_LOCALE]), "de")
	assert_true(bool(values[SettingsScript.KEY_REDUCED_MOTION]))
	assert_almost_eq(float(values[SettingsScript.KEY_TEXT_SCALE]), 1.25, 1e-9)


func test_a_missing_file_gives_the_defaults() -> void:
	var values: Dictionary = _values(null)
	assert_eq(str(values[SettingsScript.KEY_LOCALE]), SettingsScript.LOCALE_EN)
	assert_false(bool(values[SettingsScript.KEY_REDUCED_MOTION]))
	assert_almost_eq(float(values[SettingsScript.KEY_TEXT_SCALE]),
		SettingsScript.DEFAULT_TEXT_SCALE, 1e-9)


func test_the_system_locale_is_the_fallback() -> void:
	var values: Dictionary = SettingsScript.values_from({}, SettingsScript.LOCALE_DE)
	assert_eq(str(values[SettingsScript.KEY_LOCALE]), SettingsScript.LOCALE_DE)


func test_an_unsupported_locale_falls_back() -> void:
	var values: Dictionary = _values({"locale": "fr"})
	assert_eq(str(values[SettingsScript.KEY_LOCALE]), SettingsScript.LOCALE_EN)


func test_a_field_of_the_wrong_type_falls_back_alone() -> void:
	var values: Dictionary = _values({"locale": "de", "reduced_motion": "yes", "text_scale": "big"})
	assert_eq(str(values[SettingsScript.KEY_LOCALE]), "de", "the good field is kept")
	assert_false(bool(values[SettingsScript.KEY_REDUCED_MOTION]))
	assert_almost_eq(float(values[SettingsScript.KEY_TEXT_SCALE]),
		SettingsScript.DEFAULT_TEXT_SCALE, 1e-9)


func test_a_whole_number_text_scale_is_accepted() -> void:
	# JSON makes every number a float, but a hand-edited file may hold an int.
	var values: Dictionary = _values({"text_scale": 2})
	assert_almost_eq(float(values[SettingsScript.KEY_TEXT_SCALE]), 2.0, 1e-9)


func test_something_that_is_not_a_dictionary_gives_the_defaults() -> void:
	assert_eq(str(_values([1, 2, 3])[SettingsScript.KEY_LOCALE]), SettingsScript.LOCALE_EN)
	assert_eq(str(_values("nonsense")[SettingsScript.KEY_LOCALE]), SettingsScript.LOCALE_EN)


func test_the_introduction_is_on_until_the_file_says_otherwise() -> void:
	# S4.11 (first-run.md §3.1): a new player gets the guided first run.
	assert_true(bool(_values(null)[SettingsScript.KEY_TUTORIAL]))
	assert_false(bool(_values({"tutorial": false})[SettingsScript.KEY_TUTORIAL]))
	assert_true(bool(_values({"tutorial": "no"})[SettingsScript.KEY_TUTORIAL]),
		"a wrong type falls back to on")


func test_the_boot_sequence_is_full_on_the_first_launch_only_by_default() -> void:
	# S5.7 (screens-full.md §6.3): the setting brings the full boot back.
	assert_false(bool(_values(null)[SettingsScript.KEY_BOOT_ALWAYS]))
	assert_true(bool(_values({"boot_always": true})[SettingsScript.KEY_BOOT_ALWAYS]))
	assert_false(bool(_values({"boot_always": 1})[SettingsScript.KEY_BOOT_ALWAYS]),
		"a wrong type falls back to off")


func test_screen_effects_missing_falls_back_to_default() -> void:
	# S6.1 (polish-visuals.md §5.1): an older file has no key; the platform's
	# default applies, a desktop's Full here.
	assert_almost_eq(float(_values(null)[SettingsScript.KEY_SCREEN_EFFECTS]),
		SettingsScript.default_screen_effects(), 1e-9)
	assert_almost_eq(SettingsScript.default_screen_effects(), UiTokens.FX_INTENSITY_DESKTOP,
		1e-9, "the suite runs on a desktop")


func test_screen_effects_wrong_type_falls_back() -> void:
	assert_almost_eq(float(_values({"screen_effects": "full"})[SettingsScript.KEY_SCREEN_EFFECTS]),
		SettingsScript.default_screen_effects(), 1e-9)
	assert_almost_eq(float(_values({"screen_effects": 0})[SettingsScript.KEY_SCREEN_EFFECTS]),
		0.0, 1e-9, "a whole number is a number")
	assert_almost_eq(float(_values({"screen_effects": 0.5})[SettingsScript.KEY_SCREEN_EFFECTS]),
		0.5, 1e-9)


func test_cycle_screen_effects_wraps() -> void:
	var before: float = Settings.screen_effects
	var seen: Array[float] = []
	Settings.set_screen_effects(UiTokens.FX_INTENSITIES[0])
	for i: int in UiTokens.FX_INTENSITIES.size():
		seen.append(Settings.screen_effects)
		Settings.cycle_screen_effects()
	assert_eq(seen, UiTokens.FX_INTENSITIES, "every step, smallest first")
	assert_almost_eq(Settings.screen_effects, UiTokens.FX_INTENSITIES[0], 1e-9,
		"after the largest the smallest")
	assert_almost_eq(float(Settings.to_dict()[SettingsScript.KEY_SCREEN_EFFECTS]),
		Settings.screen_effects, 1e-9, "the file holds it")
	Settings.set_screen_effects(before)
