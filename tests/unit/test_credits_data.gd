extends GutTest
## S6.3 — `data/credits.json` read and checked (`docs/specs/icons.md` §11.3).


func _raw() -> Dictionary:
	return Fixtures.read_json(CreditsData.PATH)


func _first_entry(raw: Dictionary) -> Dictionary:
	return ((raw["sections"] as Array)[0] as Dictionary)["entries"][0]


func test_file_loads() -> void:
	var result: Dictionary = CreditsData.load_file()
	assert_eq(result[CreditsData.KEY_ERROR], "")
	var data: Dictionary = result[CreditsData.KEY_DATA]
	assert_false((data["sections"] as Array).is_empty())


func test_unknown_field_is_rejected() -> void:
	var raw: Dictionary = _raw()
	_first_entry(raw)["colour"] = "red"
	var errors: PackedStringArray = CreditsData.validate(raw)
	assert_eq(errors.size(), 1, str(errors))
	assert_string_contains(errors[0], "sections[0].entries[0].colour: unknown field")


func test_comment_keys_are_ignored() -> void:
	var raw: Dictionary = _raw()
	_first_entry(raw)["_note"] = "a comment"
	assert_eq(CreditsData.validate(raw), PackedStringArray())


func test_missing_key_string_is_rejected() -> void:
	var raw: Dictionary = _raw()
	_first_entry(raw)["role"] = "UI_CREDITS_ROLE_NOT_THERE"
	var errors: PackedStringArray = CreditsData.validate(raw)
	assert_eq(errors.size(), 1, str(errors))
	assert_string_contains(errors[0], "UI_CREDITS_ROLE_NOT_THERE")


func test_unknown_licence_is_rejected() -> void:
	var raw: Dictionary = _raw()
	_first_entry(raw)["licence"] = "gpl_3_0"
	var errors: PackedStringArray = CreditsData.validate(raw)
	assert_eq(errors.size(), 1, str(errors))
	assert_string_contains(errors[0], "licence")


func test_malformed_paths_are_rejected() -> void:
	var raw: Dictionary = _raw()
	_first_entry(raw)["requires"] = "assets/fonts/x.txt"
	_first_entry(raw)["text"] = "res://../outside.txt"
	var errors: PackedStringArray = CreditsData.validate(raw)
	assert_eq(errors.size(), 2, str(errors))


func test_duplicate_entry_id_is_rejected() -> void:
	var raw: Dictionary = _raw()
	var entries: Array = ((raw["sections"] as Array)[0] as Dictionary)["entries"]
	entries.append((entries[0] as Dictionary).duplicate(true))
	assert_string_contains(str(CreditsData.validate(raw)), "duplicate entry")


func test_a_file_that_is_not_there_answers_an_error() -> void:
	var result: Dictionary = CreditsData.load_file("res://data/no_credits_here.json")
	assert_ne(result[CreditsData.KEY_ERROR], "")
	assert_eq(result[CreditsData.KEY_DATA], {})


func test_entry_hidden_when_required_file_missing() -> void:
	assert_true(CreditsData.is_visible({"requires": ""}), "nothing required always shows")
	assert_true(CreditsData.is_visible({"requires": "res://assets/fonts/OFL-SpaceGrotesk.txt"}))
	assert_true(CreditsData.is_visible({"requires": "res://assets/map/id_map.png"}),
		"an imported texture counts as shipped")
	assert_false(CreditsData.is_visible({"requires": "res://assets/nothing/here.txt"}))
	var section: Dictionary = {"id": "fonts", "entries": [
		{"id": "a", "requires": "res://assets/nothing/here.txt"},
		{"id": "b", "requires": ""}]}
	var shown: Array[Dictionary] = CreditsData.visible_entries(section)
	assert_eq(shown.size(), 1)
	assert_eq(shown[0]["id"], "b")


func test_every_licence_id_has_a_string() -> void:
	for licence: String in CreditsData.LICENCES:
		assert_true(CreditsData.has_string_key(CreditsData.PREFIX_LICENCE + licence.to_upper()),
			licence)


func test_author_of_parses_path() -> void:
	assert_eq(CreditsData.author_of("res://assets/icons/game-icons/lorc/wheat.svg"), "lorc")
	assert_eq(CreditsData.author_of("game-icons/lord-berandas/x.svg"), "lord-berandas")
	assert_eq(CreditsData.author_of("res://assets/icons/phosphor/bold/x.svg"), "")


func test_icons_are_grouped_by_author_and_sorted() -> void:
	var paths: Array[String] = ["res://assets/icons/game-icons/lorc/wheat.svg",
		"res://assets/icons/game-icons/lorc/anvil.svg",
		"res://assets/icons/game-icons/sbed/cog.svg"]
	var grouped: Dictionary[String, Array] = CreditsData.icons_by_author(paths)
	assert_eq(grouped["lorc"], ["anvil", "wheat"])
	assert_eq(grouped["sbed"], ["cog"])
	var folders: Array[String] = ["sbed", "lorc"]
	assert_eq(CreditsData.author_names(_raw(), folders), ["Lorc", "Sbed"] as Array[String])
