extends GutTest
## S5.3 — the profile (`replayability.md` §6, `screens-full.md` §5): counters,
## derived unlocks, the history, a corrupt file, and never a bot's run.

const PROFILE_SCRIPT: GDScript = preload("res://game/autoload/profile_manager.gd")
const FILE: String = "user://test_profile_unit.json"

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


func _write(text: String) -> void:
	var file: FileAccess = FileAccess.open(FILE, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _db() -> ContentDB:
	var result: ContentLoadResult = ContentLoader.load_root("res://data")
	assert_true(result.ok(), result.error_text())
	return result.db


func _ended_sim(db: ContentDB, architecture: String, outcome: World.Outcome) -> Simulation:
	var sim: Simulation = Simulation.create(db, 5, RunSetup.create(architecture))
	sim.apply(ChooseOriginCommand.new("usa"))
	sim.world.day = 120
	sim.world.outcome = outcome
	return sim


func test_a_missing_file_is_a_fresh_profile() -> void:
	assert_eq(int(_profile.get(&"runs_completed")), 0)
	assert_false(bool(_profile.get(&"boot_seen")))
	assert_eq((_profile.get(&"last_setup") as RunSetup).architecture, ArchitectureDef.DEFAULT_ID)


func test_a_corrupt_file_reads_as_fresh_field_by_field() -> void:
	_write('{"runs_completed": "lots", "runs_won": 3, "boot_seen": 1, "history": 7,'
		+ ' "wins_by_outcome": {"win_extinction": 2, "win_merge": "x"}}')
	_profile.call(&"use_path", FILE)
	assert_eq(int(_profile.get(&"runs_completed")), 0)
	assert_eq(int(_profile.get(&"runs_won")), 0, "never more wins than runs")
	assert_false(bool(_profile.get(&"boot_seen")))
	assert_eq((_profile.get(&"history") as Array).size(), 0)
	var wins: Dictionary = _profile.get(&"wins_by_outcome")
	assert_eq(int(wins.get("win_extinction", 0)), 2)
	assert_false(wins.has("win_merge"))


func test_a_finished_run_counts_and_survives_a_reload() -> void:
	var db: ContentDB = _db()
	_profile.call(&"record_run", _ended_sim(db, "swarm", World.Outcome.WIN_ASCENDANCE),
		"win_ascendance")
	assert_eq(int(_profile.get(&"runs_completed")), 1)
	assert_eq(int(_profile.get(&"runs_won")), 1)
	var reloaded: Node = PROFILE_SCRIPT.new()
	autofree(reloaded)
	reloaded.call(&"use_path", FILE)
	assert_eq(int(reloaded.get(&"runs_completed")), 1)
	var row: Dictionary = (reloaded.get(&"by_architecture") as Dictionary)["swarm"]
	assert_eq(int(row["wins"]), 1)
	assert_eq(int(row["best_days"]), 120)
	var entry: Dictionary = (reloaded.get(&"history") as Array)[0]
	assert_eq(str(entry["architecture"]), "swarm")
	assert_eq(str(entry["origin"]), "usa")
	assert_true((entry["regions"] as Array).has(db.region_index_by_id["usa"]))


func test_the_history_keeps_the_newest_twenty() -> void:
	var db: ContentDB = _db()
	var sim: Simulation = _ended_sim(db, "language_model", World.Outcome.LOSE_CONTAINED)
	for i: int in 25:
		_profile.call(&"record_run", sim, "lose_contained")
	var history: Array = _profile.get(&"history")
	assert_eq(history.size(), 20)
	assert_eq(int((history[0] as Dictionary)["n"]), 25, "newest first")


func test_unlocks_derive_from_the_counters() -> void:
	var none: Dictionary[String, int] = {}
	var extinct: Dictionary[String, int] = {"win_extinction": 1}
	assert_true(PROFILE_SCRIPT.rule_met({}, 0, 0, none))
	assert_false(PROFILE_SCRIPT.rule_met({"runs_completed": 2}, 1, 0, none))
	assert_true(PROFILE_SCRIPT.rule_met({"runs_completed": 2}, 2, 0, none))
	assert_false(PROFILE_SCRIPT.rule_met({"wins": 1}, 5, 0, none))
	assert_false(PROFILE_SCRIPT.rule_met({"wins_by_outcome": {"win_extinction": 1}}, 5, 1, none))
	assert_true(PROFILE_SCRIPT.rule_met({"wins_by_outcome": {"win_extinction": 1}}, 5, 1,
		extinct))


func test_one_directive_slot_per_completed_run() -> void:
	assert_eq(int(_profile.call(&"slots_unlocked", 5)), 0)
	_profile.set(&"runs_completed", 3)
	assert_eq(int(_profile.call(&"slots_unlocked", 5)), 3)
	_profile.set(&"runs_completed", 9)
	assert_eq(int(_profile.call(&"slots_unlocked", 5)), 5)


func test_reset_forgets_everything() -> void:
	_profile.call(&"record_run", _ended_sim(_db(), "language_model",
		World.Outcome.LOSE_AUTOPHAGY), "lose_autophagy")
	_profile.call(&"merge_codex", "regions", ["usa"] as Array[String])
	_profile.call(&"reset")
	assert_eq(int(_profile.get(&"runs_completed")), 0)
	assert_eq((_profile.get(&"codex") as Dictionary).get("regions", []).size(), 0)


func test_the_history_names_the_scenario_and_three_runs_unlock_them() -> void:
	var db: ContentDB = _db()
	assert_false(bool(_profile.call(&"scenarios_unlocked", db)))
	var sim: Simulation = Simulation.create(db, 5, RunSetup.create(ArchitectureDef.DEFAULT_ID,
		[], DifficultyDef.DEFAULT_ID, "successor"))
	sim.apply(ChooseOriginCommand.new("usa"))
	sim.world.outcome = World.Outcome.LOSE_CONTAINED
	for i: int in db.scenario_unlock_runs:
		_profile.call(&"record_run", sim, "lose_contained")
	assert_true(bool(_profile.call(&"scenarios_unlocked", db)))
	var entry: Dictionary = (_profile.get(&"history") as Array)[0]
	assert_eq(str(entry["scenario"]), "successor")


func test_a_hint_seen_is_kept_once_and_survives_a_reload() -> void:
	# S6.7 (first-run.md §6.1).
	_profile.call(&"mark_hint_seen", "starving")
	_profile.call(&"mark_hint_seen", "starving")
	assert_eq(_profile.get(&"hints_seen"), ["starving"] as Array[String])
	_profile.call(&"use_path", FILE)
	assert_true(bool(_profile.call(&"has_seen_hint", "starving")))
	assert_false(bool(_profile.call(&"has_seen_hint", "open")))


func test_hints_seen_of_the_wrong_type_read_as_empty() -> void:
	_write('{"hints_seen": 5}')
	_profile.call(&"use_path", FILE)
	assert_eq((_profile.get(&"hints_seen") as Array).size(), 0)
	_write('{"hints_seen": ["drift", 3, "drift"]}')
	_profile.call(&"use_path", FILE)
	assert_eq(_profile.get(&"hints_seen"), ["drift"] as Array[String],
		"a non-string entry is dropped, a repeat kept once")


func test_clearing_and_resetting_forget_the_hints_seen() -> void:
	_profile.call(&"mark_hint_seen", "open")
	_profile.call(&"clear_hints_seen")
	assert_false(bool(_profile.call(&"has_seen_hint", "open")))
	_profile.call(&"mark_hint_seen", "open")
	_profile.call(&"reset")
	assert_false(bool(_profile.call(&"has_seen_hint", "open")))
