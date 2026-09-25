extends GutTest
## S6.10 — `UserDataMigration` (release.md §5 and the user's instruction in
## PROGRESS *Known issues*): the first start in the game's own user folder copies
## the old folder's profile, settings and saves — copied, never moved — and never
## again once the new folder has been started in.

const ROOT: String = "user://test_migration/"
const OLD: String = "user://test_migration/old/"
const NEW: String = "user://test_migration/new/"
const PROFILE: String = "{\"version\": 1, \"runs_completed\": 3}"
const SETTINGS: String = "{\"version\": 1, \"locale\": \"de\"}"
const SAVE: String = "{\"version\": 1, \"day\": 40}"
const OTHER: String = "not a player file"


func before_each() -> void:
	_remove(ROOT)
	DirAccess.make_dir_recursive_absolute(OLD.path_join("saves"))
	DirAccess.make_dir_recursive_absolute(NEW)
	_write(OLD.path_join("profile.json"), PROFILE)
	_write(OLD.path_join("settings.json"), SETTINGS)
	_write(OLD.path_join("saves/slot_1.json"), SAVE)
	_write(OLD.path_join("saves/slot_1.json.tmp"), OTHER)
	_write(OLD.path_join("gallery_de_400.png"), OTHER)


func after_all() -> void:
	_remove(ROOT)


func test_the_first_start_copies_profile_saves_and_settings() -> void:
	var copied: PackedStringArray = UserDataMigration.migrate(_abs(OLD), _abs(NEW))
	assert_eq(Array(copied), ["profile.json", "saves/slot_1.json", "settings.json"])
	assert_eq(_read(NEW.path_join("profile.json")), PROFILE)
	assert_eq(_read(NEW.path_join("settings.json")), SETTINGS)
	assert_eq(_read(NEW.path_join("saves/slot_1.json")), SAVE)


func test_the_copy_leaves_the_old_folder_as_it_was() -> void:
	UserDataMigration.migrate(_abs(OLD), _abs(NEW))
	assert_eq(_read(OLD.path_join("profile.json")), PROFILE)
	assert_eq(_read(OLD.path_join("settings.json")), SETTINGS)
	assert_eq(_read(OLD.path_join("saves/slot_1.json")), SAVE)
	assert_eq(_read(OLD.path_join("gallery_de_400.png")), OTHER)


func test_other_files_stay_behind() -> void:
	UserDataMigration.migrate(_abs(OLD), _abs(NEW))
	assert_false(FileAccess.file_exists(NEW.path_join("gallery_de_400.png")))
	assert_false(FileAccess.file_exists(NEW.path_join("saves/slot_1.json.tmp")))


func test_a_folder_started_in_before_gets_nothing() -> void:
	_write(NEW.path_join("settings.json"), "{}")
	var copied: PackedStringArray = UserDataMigration.migrate(_abs(OLD), _abs(NEW))
	assert_eq(copied.size(), 0)
	assert_false(FileAccess.file_exists(NEW.path_join("profile.json")))
	assert_eq(_read(NEW.path_join("settings.json")), "{}")


func test_a_deleted_save_does_not_come_back_on_the_next_start() -> void:
	UserDataMigration.migrate(_abs(OLD), _abs(NEW))
	DirAccess.remove_absolute(_abs(NEW.path_join("saves/slot_1.json")))
	UserDataMigration.migrate(_abs(OLD), _abs(NEW))
	assert_false(FileAccess.file_exists(NEW.path_join("saves/slot_1.json")))


func test_a_file_the_new_folder_has_is_never_overwritten() -> void:
	_write(NEW.path_join("profile.json"), "{}")
	var copied: PackedStringArray = UserDataMigration.migrate(_abs(OLD), _abs(NEW))
	assert_false(copied.has("profile.json"))
	assert_eq(_read(NEW.path_join("profile.json")), "{}")


func test_no_old_folder_copies_nothing() -> void:
	var copied: PackedStringArray = UserDataMigration.migrate(_abs(ROOT.path_join("missing")),
		_abs(NEW))
	assert_eq(copied.size(), 0)


func test_the_same_folder_copies_nothing() -> void:
	assert_eq(UserDataMigration.migrate(_abs(OLD), _abs(OLD)).size(), 0)


func test_the_old_folder_is_godots_app_userdata() -> void:
	var legacy: String = UserDataMigration.legacy_dir()
	assert_true(legacy.ends_with("/app_userdata/Doomsday"), legacy)
	assert_ne(legacy, OS.get_user_data_dir())


func test_the_game_has_its_own_user_folder() -> void:
	assert_true(OS.get_user_data_dir().ends_with("/Doomsday"), OS.get_user_data_dir())
	assert_false(OS.get_user_data_dir().contains("app_userdata"))


func _abs(path: String) -> String:
	return ProjectSettings.globalize_path(path)


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for dir_name: String in DirAccess.get_directories_at(path):
		_remove(path.path_join(dir_name))
	for file_name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)
