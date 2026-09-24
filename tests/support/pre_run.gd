extends GutHookScript
## Runs once before the suite (`.gutconfig.json`, `pre_run_script`).
##
## `Settings` reads `user://settings.json`, which the game shares with the test
## runner, and since S4.9 the text scale in it reaches every themed control. A
## scale left at 150 % by a play session would move every layout the tests
## measure, so the suite starts at the default. Nothing is written: the player's
## file keeps what the player chose.


## The profile (S5.3) is written by every run that ends in front of the game, so
## the suite gets a file of its own, emptied at the start.
const TEST_PROFILE: String = "user://test_profile.json"


func run() -> void:
	Settings.text_scale = Settings.DEFAULT_TEXT_SCALE
	ProfileManager.use_path(TEST_PROFILE)
	ProfileManager.reset()
