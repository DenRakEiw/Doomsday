extends GutTest
## S7.3 — where the game's files live (web.md §7.1): the root of `user://` on a
## desktop, a folder of its own in a browser, whose `/userfs` every Godot game
## on the host shares.

const SmokeRun: GDScript = preload("res://game/smoke_run.gd")


func test_the_web_root_is_a_folder_of_its_own() -> void:
	assert_eq(UserPaths.root_for(true), "user://doomsday/")


func test_the_desktop_root_is_the_user_folder() -> void:
	assert_eq(UserPaths.root_for(false), "user://")


func test_this_build_is_the_desktop_one() -> void:
	assert_eq(UserPaths.root(), UserPaths.DESKTOP_ROOT)


func test_at_joins_a_folder_and_keeps_its_slash() -> void:
	assert_eq(UserPaths.at("saves/"), "user://saves/")
	assert_eq(UserPaths.at_root(UserPaths.root_for(true), "saves/"), "user://doomsday/saves/")
	assert_eq(UserPaths.at_root(UserPaths.root_for(true), "profile.json"),
		"user://doomsday/profile.json")


func test_every_production_path_is_built_from_the_root() -> void:
	# The suite points some of these elsewhere (`pre_run.gd`), so the check is
	# on what each class builds from its relative part.
	var expected: Dictionary[String, String] = {
		Settings.FILE_NAME: Settings.path,
		SaveManager.SAVE_FOLDER: UserPaths.at(SaveManager.SAVE_FOLDER),
		BenchLibrary.USER_FOLDER: UserPaths.at(BenchLibrary.USER_FOLDER),
		GlobalBoardClient.CACHE_FOLDER: UserPaths.at(GlobalBoardClient.CACHE_FOLDER),
		SmokeRun.PROFILE_FILE: SmokeRun.profile_path,
		SmokeRun.SAVES_FOLDER: SmokeRun.saves_dir,
		SmokeRun.RESULT_FILE: SmokeRun.result_path,
	}
	for relative: String in expected:
		assert_true(expected[relative].begins_with(UserPaths.root()), relative)
		assert_eq(expected[relative], UserPaths.at(relative), relative)


func test_the_relative_parts_are_the_desktop_s_old_paths() -> void:
	assert_eq(UserPaths.at(Settings.FILE_NAME), "user://settings.json")
	assert_eq(UserPaths.at(ProfileManager.FILE_NAME), "user://profile.json")
	assert_eq(UserPaths.at(SaveManager.SAVE_FOLDER), "user://saves/")
	assert_eq(UserPaths.at(BenchLibrary.USER_FOLDER), "user://benchmark/runs/")
	assert_eq(UserPaths.at(GlobalBoardClient.CACHE_FOLDER), "user://benchmark/online/")
	assert_eq(SmokeRun.result_path, "user://smoke/result.json")


func test_the_suite_keeps_its_own_files() -> void:
	# `pre_run.gd`: the profile and the saves are the suite's, never the player's.
	assert_ne(ProfileManager.path, UserPaths.at(ProfileManager.FILE_NAME))
	assert_ne(SaveManager.save_dir, UserPaths.at(SaveManager.SAVE_FOLDER))
