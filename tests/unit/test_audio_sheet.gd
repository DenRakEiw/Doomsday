extends GutTest
## S6.5 — `data/audio.json` and its validator (spec audio.md §4, §12.1). Each
## broken-sheet test starts from the shipped file and breaks one rule.


func _shipped() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(AudioSheet.PATH))


func _errors_of(data: Variant) -> PackedStringArray:
	return AudioSheet.from_data(data).errors


func _has_error(errors: PackedStringArray, fragment: String) -> bool:
	for error: String in errors:
		if error.contains(fragment):
			return true
	return false


func _cue_index(data: Dictionary, id: String) -> int:
	var cues: Array = data["cues"]
	for i: int in cues.size():
		if str((cues[i] as Dictionary)["id"]) == id:
			return i
	return -1


func test_the_shipped_sheet_loads_without_errors() -> void:
	var sheet: AudioSheet = AudioSheet.load_file()
	assert_eq(sheet.errors, PackedStringArray(), "\n".join(sheet.errors))
	assert_eq(sheet.buses.size(), AudioSheet.BUS_IDS.size())
	assert_eq(sheet.cues.size(), 56, "D6.4's cue sheet")
	assert_eq(sheet.triggers.size(), 50)
	assert_eq(sheet.layers.size(), World.PHASE_IDS.size())
	assert_eq(sheet.stems.size(), 4)
	assert_eq(sheet.screens.size(), AudioSheet.SCREEN_IDS.size())


func test_the_mix_is_typed() -> void:
	var sheet: AudioSheet = AudioSheet.load_file()
	assert_almost_eq(sheet.duck_db, -8.0, 1e-6)
	assert_eq(sheet.alert_gap_priority, 80)
	assert_almost_eq(sheet.silent_db, -80.0, 1e-6)
	assert_eq(sheet.cue(&"ui_click").path(), AudioSheet.ASSET_ROOT + "ui/ui_click.wav")
	assert_null(sheet.cue(&"no_such_cue"))


func test_bus_unknown_is_rejected() -> void:
	var data: Dictionary = _shipped()
	(data["buses"] as Array)[1]["id"] = "voice"
	assert_true(_has_error(_errors_of(data), "unknown bus"))


func test_bus_missing_is_rejected() -> void:
	var data: Dictionary = _shipped()
	(data["buses"] as Array).pop_back()
	assert_true(_has_error(_errors_of(data), "\"alerts\" missing"))


func test_bus_volume_between_the_steps_is_rejected() -> void:
	var data: Dictionary = _shipped()
	(data["buses"] as Array)[1]["default_volume"] = 0.6
	assert_true(_has_error(_errors_of(data), "volume steps"))


func test_cue_id_duplicate_is_rejected() -> void:
	var data: Dictionary = _shipped()
	(data["cues"] as Array)[1]["id"] = "ui_click"
	assert_true(_has_error(_errors_of(data), "twice"))


func test_cue_priority_out_of_range_is_rejected() -> void:
	var data: Dictionary = _shipped()
	(data["cues"] as Array)[0]["priority"] = 101
	assert_true(_has_error(_errors_of(data), "priority"))


func test_cue_voices_zero_is_rejected() -> void:
	var data: Dictionary = _shipped()
	(data["cues"] as Array)[0]["voices"] = 0
	assert_true(_has_error(_errors_of(data), "voices"))


func test_caption_on_interface_cue_is_rejected() -> void:
	var data: Dictionary = _shipped()
	(data["cues"] as Array)[_cue_index(data, "ui_click")]["caption"] = "UI_CAPTION_ANOMALY"
	assert_true(_has_error(_errors_of(data), "no caption"))


func test_duck_on_interface_cue_is_rejected() -> void:
	var data: Dictionary = _shipped()
	(data["cues"] as Array)[_cue_index(data, "ui_click")]["duck"] = true
	assert_true(_has_error(_errors_of(data), "duck: alerts only"))


func test_trigger_unknown_cue_is_rejected() -> void:
	var data: Dictionary = _shipped()
	(data["triggers"] as Array)[0]["cue"] = "ui_clank"
	assert_true(_has_error(_errors_of(data), "unknown cue"))


func test_trigger_unknown_on_is_rejected() -> void:
	var data: Dictionary = _shipped()
	(data["triggers"] as Array)[0]["on"] = "hover"
	assert_true(_has_error(_errors_of(data), "unknown source"))


func test_trigger_sim_type_unknown_is_rejected() -> void:
	var data: Dictionary = _shipped()
	(data["triggers"] as Array).append({"on": "sim", "type": "region_hummed", "cue": "map_seed"})
	assert_true(_has_error(_errors_of(data), "unknown event type"))


func test_second_button_trigger_is_rejected() -> void:
	var data: Dictionary = _shipped()
	(data["triggers"] as Array).append({"on": "button", "cue": "ui_click"})
	assert_true(_has_error(_errors_of(data), "one button trigger"))


func test_match_object_with_two_keys_is_rejected() -> void:
	var data: Dictionary = _shipped()
	(data["triggers"] as Array).append({"on": "sim", "type": "harm_burst",
		"match": {"deaths": {"gt": 1, "lt": 5}}, "cue": "alert_harm"})
	assert_true(_has_error(_errors_of(data), "exactly one key"))


func test_match_unknown_condition_is_rejected() -> void:
	var data: Dictionary = _shipped()
	(data["triggers"] as Array).append({"on": "sim", "type": "harm_burst",
		"match": {"deaths": {"near": 1}}, "cue": "alert_harm"})
	assert_true(_has_error(_errors_of(data), "unknown condition"))


func test_stem_fade_reversed_is_rejected() -> void:
	var data: Dictionary = _shipped()
	((data["music"] as Dictionary)["stems"] as Array)[1]["fade"] = [0.2, 0.1]
	assert_true(_has_error(_errors_of(data), "lo must be below hi"))


func test_layers_not_four_phases_is_rejected() -> void:
	var data: Dictionary = _shipped()
	((data["ambience"] as Dictionary)["layers"] as Array).pop_back()
	assert_true(_has_error(_errors_of(data), "one per phase"))


func test_screen_missing_is_rejected() -> void:
	var data: Dictionary = _shipped()
	(data["screens"] as Dictionary).erase("setup")
	assert_true(_has_error(_errors_of(data), "screens.setup: missing"))


func test_bad_file_gives_errors_not_a_crash() -> void:
	assert_false(AudioSheet.from_data("nonsense").errors.is_empty())
	assert_false(AudioSheet.from_data({}).errors.is_empty())
	assert_false(AudioSheet.from_data({"buses": 3, "cues": [1, "x"], "mix": []}).errors.is_empty())
	var missing: AudioSheet = AudioSheet.load_file("res://data/no_such_audio.json")
	assert_false(missing.errors.is_empty())
	assert_not_null(missing, "never null")


## §12.1: every caption the sheet names is a row in both languages, with the
## same placeholders.
func test_every_caption_key_exists_in_both_languages() -> void:
	var duplicates: Array[String] = []
	var table: Dictionary[String, PackedStringArray] = StringTable.read(StringTable.PATH,
		duplicates)
	var sheet: AudioSheet = AudioSheet.load_file()
	for cue: AudioCueDef in sheet.cues.values():
		if cue.caption.is_empty():
			continue
		assert_true(table.has(cue.caption), "%s names %s" % [cue.id, cue.caption])
		if not table.has(cue.caption):
			continue
		var row: PackedStringArray = table[cue.caption]
		assert_false(row[StringTable.COLUMN_EN].is_empty(), cue.caption + " en")
		assert_false(row[StringTable.COLUMN_DE].is_empty(), cue.caption + " de")
		var en: PackedStringArray = StringTable.placeholders(row[StringTable.COLUMN_EN])
		var de: PackedStringArray = StringTable.placeholders(row[StringTable.COLUMN_DE])
		en.sort()
		de.sort()
		assert_eq(en, de, cue.caption)
