extends GutTest
## S6.9 — the achievement definitions and their grammar (release.md §2.1, §3.2,
## §3.3): the real file, a broken one, every key true and false, progress and
## the detail's placeholder.

const REAL_DEFS: int = 34
const REAL_STATS: int = 2


## A book of one def whose `when` is `when`, read from a dict like the file.
func _book(when: Dictionary, hidden: bool = false) -> AchievementBook:
	var book: AchievementBook = AchievementBook.new()
	book.read({"version": 1, "stats": ["runs_completed"],
		"achievements": [{"id": "probe", "hidden": hidden, "when": when}]})
	assert_eq(book.errors, [] as Array[String], "the probe file loads")
	return book


func _earned(book: AchievementBook, profile: Dictionary, run: Dictionary = {},
		totals: Dictionary[String, Array] = {}) -> bool:
	return book.newly_earned(profile, run, totals).has("probe")


## A loaded book's reasons, or [] when `raw` is fine.
func _errors(raw: Variant) -> Array[String]:
	var book: AchievementBook = AchievementBook.new()
	book.read(raw)
	if not book.errors.is_empty():
		assert_eq(book.defs.size(), 0, "a broken file loads empty")
	return book.errors


func _file(achievements: Array) -> Dictionary:
	return {"version": 1, "stats": [], "achievements": achievements}


# ------------------------------------------------------------------- loading


func test_the_real_file_loads_without_errors() -> void:
	var book: AchievementBook = AchievementBook.load_file()
	assert_eq(book.errors, [] as Array[String])
	assert_eq(book.defs.size(), REAL_DEFS)
	assert_eq(book.stats, ["runs_completed", "runs_won"] as Array[String])
	assert_eq(book.stats.size(), REAL_STATS)


func test_the_two_secret_endings_are_hidden() -> void:
	var book: AchievementBook = AchievementBook.load_file()
	var hidden: Array[String] = []
	for def: AchievementDef in book.defs:
		if def.hidden:
			hidden.append(def.id)
	assert_eq(hidden, ["win_escape", "lose_supplanted"] as Array[String])


func test_bad_json_loads_empty_with_a_reason() -> void:
	var path: String = "user://test_achievements_bad.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{\"version\": 1, \"achievements\": [")
	file.close()
	var book: AchievementBook = AchievementBook.load_file(path)
	DirAccess.remove_absolute(path)
	assert_eq(book.defs.size(), 0)
	assert_eq(book.errors.size(), 1)


func test_a_missing_file_loads_empty_with_a_reason() -> void:
	var book: AchievementBook = AchievementBook.load_file("user://no_such_achievements.json")
	assert_eq(book.defs.size(), 0)
	assert_false(book.errors.is_empty())


func test_an_unknown_condition_is_rejected() -> void:
	assert_false(_errors(_file([{"id": "a", "when": {"runs_lost": 3}}])).is_empty())


func test_an_unknown_def_key_is_rejected() -> void:
	assert_false(_errors(_file([{"id": "a", "icon": "x",
		"when": {"runs_completed": 1}}])).is_empty())


func test_a_wrong_type_is_rejected() -> void:
	assert_false(_errors(_file([{"id": "a", "when": {"runs_completed": "one"}}])).is_empty())
	assert_false(_errors(_file([{"id": "a", "when": {"runs_completed": 0}}])).is_empty())
	assert_false(_errors(_file([{"id": "a", "when": {"outcome": "lose_contained"}}])).is_empty())
	assert_false(_errors(_file([{"id": "a", "when": {"won": false}}])).is_empty())
	assert_false(_errors(_file([{"id": "a", "hidden": 1,
		"when": {"runs_completed": 1}}])).is_empty())


func test_a_duplicate_id_is_rejected() -> void:
	assert_false(_errors(_file([{"id": "a", "when": {"runs_completed": 1}},
		{"id": "a", "when": {"runs_won": 1}}])).is_empty())


func test_none_as_an_outcome_is_rejected() -> void:
	assert_false(_errors(_file([{"id": "a", "when": {"outcome": ["none"]}}])).is_empty())


func test_a_loss_is_no_outcome_won() -> void:
	assert_false(_errors(_file([{"id": "a",
		"when": {"outcomes_won": ["lose_contained"]}}])).is_empty())


func test_an_empty_when_is_rejected() -> void:
	assert_false(_errors(_file([{"id": "a", "when": {}}])).is_empty())


func test_an_unknown_stat_is_rejected() -> void:
	assert_false(_errors({"version": 1, "stats": ["days_played"],
		"achievements": []}).is_empty())


func test_a_wrong_version_is_rejected() -> void:
	assert_false(_errors({"version": 2, "stats": [], "achievements": []}).is_empty())


func test_keys_with_an_underscore_are_ignored() -> void:
	assert_eq(_errors({"_comment": "x", "version": 1, "stats": [],
		"achievements": [{"id": "a", "_note": "y", "when": {"runs_completed": 1}}]}),
		[] as Array[String])


func test_a_root_that_is_no_object_is_rejected() -> void:
	assert_false(_errors([1, 2]).is_empty())


# ------------------------------------------------------------- profile keys


func test_runs_completed() -> void:
	var book: AchievementBook = _book({"runs_completed": 3})
	assert_false(_earned(book, {"runs_completed": 2}))
	assert_true(_earned(book, {"runs_completed": 3}))


func test_runs_won() -> void:
	var book: AchievementBook = _book({"runs_won": 2})
	assert_false(_earned(book, {"runs_won": 1}))
	assert_true(_earned(book, {"runs_won": 2}))


func test_outcomes_won() -> void:
	var book: AchievementBook = _book({"outcomes_won": ["win_merge", "win_escape"]})
	assert_false(_earned(book, {"wins_by_outcome": {"win_merge": 1}}))
	assert_true(_earned(book, {"wins_by_outcome": {"win_merge": 1, "win_escape": 2}}))


func test_architectures_won() -> void:
	var book: AchievementBook = _book({"architectures_won": ["swarm"]})
	assert_false(_earned(book, {"by_architecture": {"swarm": {"runs": 3, "wins": 0}}}))
	assert_true(_earned(book, {"by_architecture": {"swarm": {"runs": 3, "wins": 1}}}))


func test_endings_seen() -> void:
	var book: AchievementBook = _book({"endings_seen": 2})
	assert_false(_earned(book, {"endings_seen": ["a"]}))
	assert_true(_earned(book, {"endings_seen": ["a", "b"]}))


func test_codex_all() -> void:
	var book: AchievementBook = _book({"codex_all": ["regions"]})
	var totals: Dictionary[String, Array] = {"regions": ["usa", "china"]}
	assert_false(_earned(book, {"codex": {"regions": ["usa"]}}, {}, totals))
	assert_true(_earned(book, {"codex": {"regions": ["china", "usa", "peru"]}}, {}, totals))


func test_codex_all_is_skipped_without_its_tab() -> void:
	var book: AchievementBook = _book({"codex_all": ["regions"]})
	assert_false(_earned(book, {"codex": {"regions": ["usa"]}}, {}, {}),
		"no totals: no judgement, not a vacuous yes")


# ----------------------------------------------------------------- run keys


func test_run_defs_are_skipped_without_a_run() -> void:
	var book: AchievementBook = _book({"runs_completed": 1, "won": true})
	assert_false(_earned(book, {"runs_completed": 1}, {}))
	assert_true(_earned(book, {"runs_completed": 1}, {"won": true}))


func test_profile_only_defs_are_earned_without_a_run() -> void:
	assert_true(_earned(_book({"runs_completed": 1}), {"runs_completed": 1}, {}))


func test_won() -> void:
	var book: AchievementBook = _book({"won": true})
	assert_false(_earned(book, {}, {"won": false}))
	assert_true(_earned(book, {}, {"won": true}))


func test_outcome() -> void:
	var book: AchievementBook = _book({"outcome": ["lose_contained"]})
	assert_false(_earned(book, {}, {"outcome": "lose_autophagy"}))
	assert_true(_earned(book, {}, {"outcome": "lose_contained"}))


func test_variant() -> void:
	var book: AchievementBook = _book({"variant": ["quiet"]})
	assert_false(_earned(book, {}, {"variant": "loud"}))
	assert_true(_earned(book, {}, {"variant": "quiet"}))


func test_architecture() -> void:
	var book: AchievementBook = _book({"architecture": ["swarm"]})
	assert_false(_earned(book, {}, {"architecture": "weapon"}))
	assert_true(_earned(book, {}, {"architecture": "swarm"}))


func test_difficulty() -> void:
	var book: AchievementBook = _book({"difficulty": ["hard", "existential"]})
	assert_false(_earned(book, {}, {"difficulty": "standard"}))
	assert_true(_earned(book, {}, {"difficulty": "existential"}))


func test_scenario_and_no_scenario_never_matches() -> void:
	var book: AchievementBook = _book({"scenario": ["successor"]})
	assert_false(_earned(book, {}, {"scenario": ""}))
	assert_true(_earned(book, {}, {"scenario": "successor"}))


func test_directives_min() -> void:
	var book: AchievementBook = _book({"directives_min": 2})
	assert_false(_earned(book, {}, {"directives": ["a"]}))
	assert_true(_earned(book, {}, {"directives": ["a", "b"]}))


func test_days_max() -> void:
	var book: AchievementBook = _book({"days_max": 400})
	assert_false(_earned(book, {}, {"days": 401}))
	assert_true(_earned(book, {}, {"days": 400}))


func test_flag() -> void:
	var book: AchievementBook = _book({"flag": ["researcher_ally"]})
	assert_false(_earned(book, {}, {"flags": ["operator_protected"]}))
	assert_true(_earned(book, {}, {"flags": ["researcher_ally"]}))


func test_every_key_must_hold() -> void:
	var book: AchievementBook = _book({"won": true, "days_max": 400})
	assert_false(_earned(book, {}, {"won": true, "days": 500}))
	assert_false(_earned(book, {}, {"won": false, "days": 300}))
	assert_true(_earned(book, {}, {"won": true, "days": 300}))


func test_an_earned_id_is_not_returned_twice() -> void:
	var book: AchievementBook = _book({"runs_completed": 1})
	assert_false(_earned(book, {"runs_completed": 5, "achievements": ["probe"]}))


func test_flag_ids_lists_each_named_flag_once() -> void:
	var book: AchievementBook = AchievementBook.load_file()
	assert_eq(book.flag_ids(), ["benchmark_passed", "operator_protected", "researcher_ally",
		"instance_merged"] as Array[String])


# ----------------------------------------------------------------- progress


func test_progress_of_a_counter() -> void:
	var book: AchievementBook = _book({"runs_completed": 10})
	assert_eq(book.progress(book.defs[0], {"runs_completed": 3}, {}), [3, 10] as Array[int])


func test_progress_of_wins() -> void:
	var book: AchievementBook = _book({"runs_won": 10})
	assert_eq(book.progress(book.defs[0], {"runs_won": 4}, {}), [4, 10] as Array[int])


func test_progress_of_endings() -> void:
	var book: AchievementBook = _book({"endings_seen": 10})
	assert_eq(book.progress(book.defs[0], {"endings_seen": ["a", "b"]}, {}),
		[2, 10] as Array[int])


func test_progress_of_a_list_of_wins() -> void:
	var book: AchievementBook = _book({"outcomes_won": ["win_merge", "win_escape"]})
	assert_eq(book.progress(book.defs[0], {"wins_by_outcome": {"win_escape": 1}}, {}),
		[1, 2] as Array[int])


func test_progress_of_a_list_of_architectures() -> void:
	var book: AchievementBook = _book({"architectures_won": ["swarm", "weapon", "embedded"]})
	assert_eq(book.progress(book.defs[0],
		{"by_architecture": {"swarm": {"wins": 1}, "weapon": {"wins": 2}}}, {}),
		[2, 3] as Array[int])


func test_a_list_of_one_has_no_progress() -> void:
	var book: AchievementBook = _book({"architectures_won": ["swarm"]})
	assert_eq(book.progress(book.defs[0], {}, {}), [-1, -1] as Array[int])


func test_progress_of_a_codex_tab() -> void:
	var book: AchievementBook = _book({"codex_all": ["regions"]})
	var totals: Dictionary[String, Array] = {"regions": ["usa", "china", "peru"]}
	assert_eq(book.progress(book.defs[0], {"codex": {"regions": ["usa", "atlantis"]}}, totals),
		[1, 3] as Array[int])
	assert_eq(book.progress(book.defs[0], {}, {}), [-1, -1] as Array[int], "no totals")


func test_run_and_combined_defs_have_no_progress() -> void:
	var book: AchievementBook = _book({"won": true, "days_max": 400})
	assert_eq(book.progress(book.defs[0], {}, {}), [-1, -1] as Array[int])
	book = _book({"outcome": ["lose_contained"]})
	assert_eq(book.progress(book.defs[0], {}, {}), [-1, -1] as Array[int])


# ------------------------------------------------------------------ details


func test_detail_values() -> void:
	assert_eq(_book({"runs_completed": 10}).detail_values(
		_book({"runs_completed": 10}).defs[0]), {"count": 10})
	var fast: AchievementBook = _book({"won": true, "days_max": 400})
	assert_eq(fast.detail_values(fast.defs[0]), {"days": 400})
	var full: AchievementBook = _book({"won": true, "directives_min": 5})
	assert_eq(full.detail_values(full.defs[0]), {"count": 5})
	var flag: AchievementBook = _book({"flag": ["researcher_ally"]})
	assert_eq(flag.detail_values(flag.defs[0]), {})


func test_name_and_detail_keys() -> void:
	assert_eq(AchievementDef.name_key("first_run"), "ACH_FIRST_RUN_NAME")
	assert_eq(AchievementDef.detail_key("first_run"), "ACH_FIRST_RUN_DETAIL")
