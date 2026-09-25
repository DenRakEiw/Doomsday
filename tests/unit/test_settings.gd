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


# ---------------------------------------------------------- S6.5, audio.md §3.2


func test_the_sound_keys_round_trip() -> void:
	var values: Dictionary = _values({
		"volume_music": 0.5, "volume_alerts": 0, "sound_captions": true,
		"audio_background": false,
	})
	var volumes: Dictionary = values[SettingsScript.KEY_VOLUMES]
	assert_almost_eq(float(volumes["music"]), 0.5, 1e-9)
	assert_almost_eq(float(volumes["alerts"]), 0.0, 1e-9, "a whole number is read")
	assert_true(bool(values[SettingsScript.KEY_SOUND_CAPTIONS]))
	assert_false(bool(values[SettingsScript.KEY_AUDIO_BACKGROUND]))


func test_a_volume_above_one_is_clamped() -> void:
	var volumes: Dictionary = _values({"volume_master": 1.7})[SettingsScript.KEY_VOLUMES]
	assert_almost_eq(float(volumes["master"]), 1.0, 1e-9)


func test_a_volume_that_is_not_a_number_falls_back() -> void:
	var volumes: Dictionary = _values({"volume_master": "loud", "volume_music": 0.25})[
		SettingsScript.KEY_VOLUMES]
	assert_false(volumes.has("master"), "absent: the sheet's default applies")
	assert_almost_eq(float(volumes["music"]), 0.25, 1e-9, "the good one is kept")


func test_sound_captions_default_off() -> void:
	assert_false(bool(_values(null)[SettingsScript.KEY_SOUND_CAPTIONS]))
	assert_false(bool(_values({"sound_captions": "yes"})[SettingsScript.KEY_SOUND_CAPTIONS]))


func test_audio_background_defaults_on() -> void:
	assert_true(bool(_values(null)[SettingsScript.KEY_AUDIO_BACKGROUND]))
	assert_true((_values(null)[SettingsScript.KEY_VOLUMES] as Dictionary).is_empty())


func test_hints_are_on_by_default_and_a_wrong_type_reads_as_on() -> void:
	# S6.7 (first-run.md §6.1).
	assert_true(bool(_values(null)[SettingsScript.KEY_HINTS]))
	assert_false(bool(_values({"hints": false})[SettingsScript.KEY_HINTS]))
	assert_true(bool(_values({"hints": 0})[SettingsScript.KEY_HINTS]),
		"a wrong type falls back to on")


## §6.1: on again means every hint once more. The autoloads write their files,
## so the setting is put back the way the player had it.
func test_switching_hints_back_on_clears_the_hints_seen() -> void:
	var before: bool = Settings.hints
	Settings.set_hints(false)
	ProfileManager.mark_hint_seen("starving")
	Settings.set_hints(true)
	assert_false(ProfileManager.has_seen_hint("starving"))
	Settings.set_hints(before)


func test_headlines_are_read_to_a_screen_reader_until_the_file_says_otherwise() -> void:
	# S6.8 (accessibility.md §3.4).
	assert_true(bool(_values(null)[SettingsScript.KEY_ANNOUNCE_HEADLINES]))
	assert_false(bool(_values({"announce_headlines": false})[SettingsScript.KEY_ANNOUNCE_HEADLINES]))
	assert_true(bool(_values({"announce_headlines": 0})[SettingsScript.KEY_ANNOUNCE_HEADLINES]),
		"a wrong type falls back to on")


func test_key_overrides_round_trip_and_fall_back() -> void:
	# S6.8 (accessibility.md §5.2): only valid overrides survive a read.
	var values: Dictionary = _values({"keys": {"game_tree": float(KEY_Y)}})
	assert_eq(values[SettingsScript.KEY_KEYS], {"game_tree": int(KEY_Y)})
	assert_eq(_values(null)[SettingsScript.KEY_KEYS], {}, "a missing key reads empty")
	assert_eq(_values({"keys": [1, 2]})[SettingsScript.KEY_KEYS], {}, "a wrong type too")


func test_a_first_launch_takes_reduced_motion_from_the_os() -> void:
	# S6.8 (accessibility.md §9 item 3): only when there is no file at all.
	var first: Dictionary = SettingsScript.values_from(null, SettingsScript.LOCALE_EN, true)
	assert_true(bool(first[SettingsScript.KEY_REDUCED_MOTION]))
	var stored: Dictionary = SettingsScript.values_from({"reduced_motion": false},
		SettingsScript.LOCALE_EN, true)
	assert_false(bool(stored[SettingsScript.KEY_REDUCED_MOTION]), "the stored value rules")
	var older: Dictionary = SettingsScript.values_from({"locale": "en"},
		SettingsScript.LOCALE_EN, true)
	assert_false(bool(older[SettingsScript.KEY_REDUCED_MOTION]),
		"a file without the key is not a first launch")
