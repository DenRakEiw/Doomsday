extends GutTest
## S6.10 — the smoke mode (release.md §8): the isolation step points the profile
## and the saves at `user://smoke/`, turns the settings file off and the sound
## down, and the result line has its fixed format. Everything is put back.

const SmokeRun: GDScript = preload("res://game/smoke_run.gd")

var _profile_path: String = ""
var _save_dir: String = ""
var _volumes: Dictionary[String, float] = {}


func before_each() -> void:
	_profile_path = ProfileManager.path
	_save_dir = SaveManager.save_dir
	_volumes = Settings.volumes.duplicate()


func after_each() -> void:
	ProfileManager.use_path(_profile_path)
	SaveManager.save_dir = _save_dir
	Settings.volumes = _volumes
	for bus: StringName in AudioSheet.BUS_IDS:
		EventBus.volume_changed.emit(bus, Audio.volume(bus))
	Settings.persist = true


func test_isolation_points_the_profile_at_the_smoke_folder() -> void:
	SmokeRun.isolate()
	assert_eq(ProfileManager.path, SmokeRun.PROFILE_PATH)
	assert_ne(ProfileManager.path, _profile_path)


func test_isolation_points_the_saves_at_the_smoke_folder() -> void:
	SmokeRun.isolate()
	assert_eq(SaveManager.save_dir, SmokeRun.SAVES_DIR)
	assert_eq(SaveManager.path_for(SaveManager.AUTOSAVE),
		SmokeRun.SAVES_DIR.path_join(SaveManager.AUTOSAVE + SaveManager.SUFFIX))
	assert_true(DirAccess.dir_exists_absolute(SmokeRun.SAVES_DIR))


func test_isolation_turns_the_settings_file_off() -> void:
	SmokeRun.isolate()
	assert_false(Settings.persist)


func test_isolation_silences_every_bus() -> void:
	SmokeRun.isolate()
	for bus: StringName in AudioSheet.BUS_IDS:
		assert_eq(Audio.volume(bus), 0.0, String(bus))


func test_a_settings_change_is_not_written_while_persist_is_off() -> void:
	var before: String = FileAccess.get_file_as_string(Settings.PATH)
	Settings.persist = false
	Settings.set_volume(String(AudioSheet.BUS_MUSIC), 0.25)
	assert_eq(FileAccess.get_file_as_string(Settings.PATH), before)


func test_the_result_line_reads_ok_with_its_fields() -> void:
	assert_eq(SmokeRun.result_line(true, "lose_contained", 404, "f7dd", 0),
		"smoke: ok outcome=lose_contained day=404 hash=f7dd errors=0")


func test_the_result_line_reads_fail_on_errors() -> void:
	assert_eq(SmokeRun.result_line(false, "none", 12, "", 3),
		"smoke: fail outcome=none day=12 hash= errors=3")
