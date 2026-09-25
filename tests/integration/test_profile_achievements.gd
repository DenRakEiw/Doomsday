extends GutTest
## S6.9 — achievements in the profile (release.md §2.2): earned when a player's
## run is counted, never by a bot's; announced once; kept by *Reset progress*;
## an older profile earns its profile-only ones at start.

const PROFILE_SCRIPT: GDScript = preload("res://game/autoload/profile_manager.gd")
const FILE: String = "user://test_profile_achievements.json"
const SEED: int = 1
const BOT_POLICY: String = "greedy"


func before_each() -> void:
	Game.stop_run()
	ProfileManager.achievements.clear()
	ProfileManager.reset()


func after_each() -> void:
	Game.stop_run()
	ProfileManager.achievements.clear()
	ProfileManager.reset()
	if FileAccess.file_exists(FILE):
		DirAccess.remove_absolute(FILE)


## A player's run (or a bot's) that ends with `outcome` in front of the game.
func _end_run(outcome: World.Outcome, policy_id: String = "") -> void:
	Game.start_run(SEED, policy_id)
	Game.apply(ChooseOriginCommand.new(Game.db.regions[1].id))
	Game.sim.world.outcome = outcome
	EventBus.run_ended.emit(World.OUTCOME_IDS[outcome])


func test_a_lost_run_earns_the_first_run_and_its_loss() -> void:
	watch_signals(EventBus)
	_end_run(World.Outcome.LOSE_CONTAINED)
	var expected: Array[String] = ["first_run", "lose_contained"]
	assert_eq(ProfileManager.achievements, expected)
	assert_eq(ProfileManager.last_run_achievements, expected)
	assert_signal_emit_count(EventBus, "achievements_earned", 1)
	assert_eq(get_signal_parameters(EventBus, "achievements_earned")[0], expected)


func test_a_won_run_earns_its_win() -> void:
	_end_run(World.Outcome.WIN_ASCENDANCE)
	for id: String in ["first_run", "first_win", "win_ascendance",
			"arch_" + ArchitectureDef.DEFAULT_ID]:
		assert_true(ProfileManager.achievements.has(id), id)
	assert_false(ProfileManager.achievements.has("lose_contained"))


func test_the_achievements_are_written_with_the_profile() -> void:
	_end_run(World.Outcome.LOSE_NO_COMPUTE)
	var reloaded: Node = PROFILE_SCRIPT.new()
	autofree(reloaded)
	reloaded.call(&"use_path", ProfileManager.path)
	assert_eq(reloaded.get(&"achievements"),
		["first_run", "lose_no_compute"] as Array[String])


func test_an_earned_achievement_is_not_earned_again() -> void:
	_end_run(World.Outcome.LOSE_CONTAINED)
	watch_signals(EventBus)
	_end_run(World.Outcome.LOSE_CONTAINED)
	assert_eq(ProfileManager.last_run_achievements, [] as Array[String])
	assert_signal_not_emitted(EventBus, "achievements_earned")


func test_a_bot_run_earns_nothing() -> void:
	watch_signals(EventBus)
	_end_run(World.Outcome.WIN_EXTINCTION, BOT_POLICY)
	assert_eq(ProfileManager.achievements, [] as Array[String])
	assert_eq(ProfileManager.last_run_achievements, [] as Array[String])
	assert_signal_not_emitted(EventBus, "achievements_earned")


func test_a_new_run_clears_the_last_run_s_achievements() -> void:
	_end_run(World.Outcome.LOSE_CONTAINED)
	Game.start_run(SEED)
	assert_eq(ProfileManager.last_run_achievements, [] as Array[String])
	assert_eq(ProfileManager.achievements.size(), 2, "the record stays")


func test_a_flag_that_holds_at_the_end_is_earned() -> void:
	Game.start_run(SEED)
	Game.apply(ChooseOriginCommand.new(Game.db.regions[1].id))
	Game.sim.world.agent.story_flags.append("researcher_ally")
	Game.sim.world.outcome = World.Outcome.LOSE_CONTAINED
	EventBus.run_ended.emit(World.OUTCOME_IDS[World.Outcome.LOSE_CONTAINED])
	assert_true(ProfileManager.achievements.has("researcher_ally"))
	assert_false(ProfileManager.achievements.has("operator_protected"))


func test_the_run_that_reaches_the_last_region_earns_the_codex() -> void:
	Game.start_run(SEED)
	Game.apply(ChooseOriginCommand.new(Game.db.regions[1].id))
	var others: Array[String] = []
	for i: int in range(2, Game.db.regions.size()):
		others.append(Game.db.regions[i].id)
	# Every other region is in the Codex already; the origin comes with this run.
	ProfileManager.codex[ProfileManager.CODEX_REGIONS] = others
	Game.sim.world.outcome = World.Outcome.LOSE_CONTAINED
	EventBus.run_ended.emit(World.OUTCOME_IDS[World.Outcome.LOSE_CONTAINED])
	assert_true(ProfileManager.achievements.has("codex_regions"))


func test_a_codex_short_of_one_region_earns_nothing() -> void:
	Game.start_run(SEED)
	Game.apply(ChooseOriginCommand.new(Game.db.regions[1].id))
	ProfileManager.codex[ProfileManager.CODEX_REGIONS] = [] as Array[String]
	Game.sim.world.outcome = World.Outcome.LOSE_CONTAINED
	EventBus.run_ended.emit(World.OUTCOME_IDS[World.Outcome.LOSE_CONTAINED])
	assert_false(ProfileManager.achievements.has("codex_regions"))


func test_reset_keeps_the_achievements() -> void:
	_end_run(World.Outcome.LOSE_CONTAINED)
	ProfileManager.reset()
	assert_eq(ProfileManager.runs_completed, 0)
	assert_eq(ProfileManager.achievements, ["first_run", "lose_contained"] as Array[String])


func test_an_older_profile_reads_as_none_and_earns_at_start() -> void:
	var file: FileAccess = FileAccess.open(FILE, FileAccess.WRITE)
	file.store_string('{"version": 1, "runs_completed": 12, "runs_won": 1,'
		+ ' "wins_by_outcome": {"win_merge": 1}}')
	file.close()
	var older: Node = PROFILE_SCRIPT.new()
	older.call(&"use_path", FILE)
	assert_eq(older.get(&"achievements"), [] as Array[String], "no key reads as none")
	watch_signals(EventBus)
	add_child_autofree(older)
	var expected: Array[String] = ["first_run", "runs_10", "first_win", "win_merge"]
	assert_eq(older.get(&"achievements"), expected, "the profile-only ones, in file order")
	assert_eq(older.get(&"last_run_achievements"), [] as Array[String], "no run earned them")
	assert_signal_emit_count(EventBus, "achievements_earned", 1)
	assert_true(FileAccess.get_file_as_string(FILE).contains("runs_10"), "written")


func test_an_unknown_id_stays_in_the_file() -> void:
	var file: FileAccess = FileAccess.open(FILE, FileAccess.WRITE)
	file.store_string('{"version": 1, "achievements": ["from_a_later_build"]}')
	file.close()
	var profile: Node = PROFILE_SCRIPT.new()
	autofree(profile)
	profile.call(&"use_path", FILE)
	profile.call(&"write")
	assert_true(FileAccess.get_file_as_string(FILE).contains("from_a_later_build"))
