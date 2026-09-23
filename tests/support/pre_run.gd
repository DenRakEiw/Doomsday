extends GutHookScript
## Runs once before the suite (`.gutconfig.json`, `pre_run_script`).
##
## `Settings` reads `user://settings.json`, which the game shares with the test
## runner, and since S4.9 the text scale in it reaches every themed control. A
## scale left at 150 % by a play session would move every layout the tests
## measure, so the suite starts at the default. Nothing is written: the player's
## file keeps what the player chose.


func run() -> void:
	Settings.text_scale = Settings.DEFAULT_TEXT_SCALE
