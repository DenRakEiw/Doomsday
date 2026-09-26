extends GutTest
## S7.3 — progress to a file and back (web.md §7.4): what a progress file must
## be, what an import keeps, and that the export reads back as the profile.

const PROFILE_SCRIPT: GDScript = preload("res://game/autoload/profile_manager.gd")
const FILE: String = "user://test_profile_import.json"

var _profile: Node = null


func before_each() -> void:
	if FileAccess.file_exists(FILE):
		DirAccess.remove_absolute(FILE)
	_profile = PROFILE_SCRIPT.new()
	autofree(_profile)
	_profile.call(&"use_path", FILE)


func after_all() -> void:
	if FileAccess.file_exists(FILE):
		DirAccess.remove_absolute(FILE)


func _file_profile(runs: int, achievements: Array) -> Dictionary:
	return {"version": 1, "runs_completed": runs, "runs_won": 0, "achievements": achievements}


func _import(raw: Variant) -> String:
	return str(_profile.call(&"import_dict", raw))


func test_a_valid_file_replaces_the_counts() -> void:
	_profile.set(&"runs_completed", 2)
	assert_eq(_import(_file_profile(7, [])), "")
	assert_eq(int(_profile.get(&"runs_completed")), 7)


func test_an_import_keeps_the_union_of_achievements() -> void:
	_profile.set(&"achievements", ["first_run", "local_only"] as Array[String])
	assert_eq(_import(_file_profile(1, ["first_run", "from_file"])), "")
	var achievements: Array = _profile.get(&"achievements")
	for id: String in ["first_run", "local_only", "from_file"]:
		assert_true(achievements.has(id), id)
	assert_eq(achievements.count("first_run"), 1, "each once")


func test_an_import_is_written() -> void:
	assert_eq(_import(_file_profile(4, [])), "")
	var json: JSON = JSON.new()
	assert_eq(json.parse(FileAccess.get_file_as_string(FILE)), OK)
	assert_eq(int((json.data as Dictionary)["runs_completed"]), 4)


func test_not_a_dictionary_is_not_a_profile() -> void:
	assert_eq(_import([1, 2]), PROFILE_SCRIPT.REASON_NOT_A_PROFILE)
	assert_eq(_import("not json"), PROFILE_SCRIPT.REASON_NOT_A_PROFILE)
	assert_eq(_import(null), PROFILE_SCRIPT.REASON_NOT_A_PROFILE)


func test_without_runs_completed_it_is_not_a_profile() -> void:
	assert_eq(_import({"version": 1}), PROFILE_SCRIPT.REASON_NOT_A_PROFILE)


func test_a_bad_version_is_not_a_profile() -> void:
	for version: Variant in [0, 1.5, "1", null]:
		assert_eq(_import({"version": version, "runs_completed": 1}),
			PROFILE_SCRIPT.REASON_NOT_A_PROFILE, str(version))


func test_a_newer_version_is_refused_as_newer() -> void:
	var raw: Dictionary = _file_profile(3, [])
	raw["version"] = int(PROFILE_SCRIPT.VERSION) + 1
	assert_eq(_import(raw), PROFILE_SCRIPT.REASON_NEWER)


func test_a_refused_file_changes_nothing() -> void:
	_profile.set(&"runs_completed", 5)
	_import({"version": 1})
	assert_eq(int(_profile.get(&"runs_completed")), 5)


func test_the_export_parses_back_to_the_profile() -> void:
	_profile.set(&"runs_completed", 3)
	_profile.set(&"achievements", ["first_run"] as Array[String])
	var parsed: Variant = JSON.parse_string(str(_profile.call(&"export_text")))
	assert_eq(typeof(parsed), TYPE_DICTIONARY)
	var d: Dictionary = parsed
	var own: Dictionary = _profile.call(&"to_dict")
	var keys: Array = d.keys()
	var own_keys: Array = own.keys()
	keys.sort()
	own_keys.sort()
	assert_eq(keys, own_keys)
	assert_eq(int(d["runs_completed"]), 3)
	assert_eq(d["achievements"], ["first_run"])
	assert_eq(_import(parsed), "", "the export is a progress file")
