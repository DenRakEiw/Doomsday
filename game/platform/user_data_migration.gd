class_name UserDataMigration
extends RefCounted
## release.md §5 moves the user folder from Godot's `app_userdata/Doomsday/` to a
## folder of the game's own name (`%APPDATA%/Doomsday/`, `~/.local/share/Doomsday/`).
## A profile, its settings and its saves from before that are **copied** over on
## the first start in the new folder — copied, never moved: the old folder is
## left exactly as it was (user instruction for S6.10; §5 itself said nothing
## migrates, see PROGRESS *Deviations*).
##
## Static and path-driven, so a test runs it between two folders of its own.

## A player's state. Everything else in the old folder — screenshots, logs,
## caches, the test runner's profile — stays behind. The settings file comes
## last: it is the marker below, so a copy cut short is completed next time.
const PROFILE_FILE: String = "profile.json"
const SETTINGS_FILE: String = "settings.json"
const SAVES_DIR: String = "saves"
const SAVE_SUFFIX: String = ".json"
## `Settings` writes this file at every start, so a new folder that has it has
## been started in before and is never copied into again — a save the player
## deleted there must not come back from the old folder.
const MARKER: String = SETTINGS_FILE
## How Godot names the default user folder: `<data dir>/<Godot|godot>/app_userdata/<name>`.
const APP_USERDATA: String = "app_userdata"
const GODOT_DIR: String = "Godot"
const GODOT_DIR_XDG: String = "godot"
const FEATURE_LINUXBSD: String = "linuxbsd"
const FEATURE_WEB: String = "web"
const FEATURE_MOBILE: String = "mobile"
const NAME_SETTING: String = "application/config/name"
const LOG_LINE: String = "user data: copied %s from %s"


## The first start's copy, in the running game. A browser or a phone never had
## the old folder; a build without the custom folder has nothing to move to.
static func run() -> PackedStringArray:
	if OS.has_feature(FEATURE_WEB) or OS.has_feature(FEATURE_MOBILE):
		return PackedStringArray()
	var from_dir: String = legacy_dir()
	var copied: PackedStringArray = migrate(from_dir, OS.get_user_data_dir())
	if not copied.is_empty():
		print(LOG_LINE % [", ".join(copied), from_dir])
	return copied


## Where Godot kept the user folder before the project named its own.
static func legacy_dir() -> String:
	var godot_dir: String = GODOT_DIR_XDG if OS.has_feature(FEATURE_LINUXBSD) else GODOT_DIR
	var app_name: String = str(ProjectSettings.get_setting(NAME_SETTING, "")).validate_filename()
	return OS.get_data_dir().path_join(godot_dir).path_join(APP_USERDATA).path_join(app_name)


## Copies the profile, the saves and the settings from `from_dir` to `to_dir`
## (absolute folders) unless `to_dir` has been started in before. A file the new
## folder already has is never overwritten. Answers the paths copied, relative
## to the folders, in the order copied.
static func migrate(from_dir: String, to_dir: String) -> PackedStringArray:
	var copied: PackedStringArray = []
	if from_dir.simplify_path() == to_dir.simplify_path() or not DirAccess.dir_exists_absolute(from_dir):
		return copied
	if FileAccess.file_exists(to_dir.path_join(MARKER)):
		return copied
	var names: Array[String] = [PROFILE_FILE]
	var saves_from: String = from_dir.path_join(SAVES_DIR)
	if DirAccess.dir_exists_absolute(saves_from):
		for file_name: String in DirAccess.get_files_at(saves_from):
			if file_name.ends_with(SAVE_SUFFIX):
				names.append(SAVES_DIR.path_join(file_name))
	names.append(SETTINGS_FILE)
	for relative: String in names:
		var source: String = from_dir.path_join(relative)
		var target: String = to_dir.path_join(relative)
		if not FileAccess.file_exists(source) or FileAccess.file_exists(target):
			continue
		var made: Error = DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		var error: Error = made if made != OK else DirAccess.copy_absolute(source, target)
		if error != OK:
			# The old file is still there; the player's state is not lost, only not here.
			push_warning("user data: cannot copy %s (%s)" % [source, error_string(error)])
			continue
		copied.append(relative)
	return copied
