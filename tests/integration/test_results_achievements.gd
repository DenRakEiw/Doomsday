extends GutTest
## S6.9 — the results screen's achievement chips (release.md §2.4): one per id
## the run earned, after the unlock chips; the block shows with any chip at all.

const RESULTS: PackedScene = preload("res://ui/screens/results.tscn")
const Results: GDScript = preload("res://ui/screens/results.gd")


func before_each() -> void:
	Game.stop_run()
	Game.start_run(1)
	Game.apply(ChooseOriginCommand.new(Game.db.regions[1].id))
	Game.sim.world.outcome = World.Outcome.LOSE_CONTAINED


func after_each() -> void:
	Game.stop_run()


func _results() -> Results:
	var results: Results = RESULTS.instantiate() as Results
	add_child_autofree(results)
	results.show_result(Game.sim)
	return results


func _chip_texts(results: Results) -> Array[String]:
	var texts: Array[String] = []
	for chip: Node in results.get_node("%UnlockedChips").get_children():
		texts.append(str((chip as Chip).accessibility_name))
	return texts


func test_one_chip_per_achievement_the_run_earned() -> void:
	var results: Results = _results()
	results.show_unlocks([] as Array[String], [] as Array[String], 0,
		["first_run", "lose_contained"] as Array[String])
	var chips: Array[Node] = results.get_node("%UnlockedChips").get_children()
	assert_eq(chips.size(), 2)
	assert_true((results.get_node("%ResultUnlocked") as Control).visible)
	for i: int in chips.size():
		var id: String = ["first_run", "lose_contained"][i]
		assert_eq((chips[i] as Chip).label_key, Results.KEY_ACHIEVEMENT)
		assert_string_contains(str((chips[i] as Chip).accessibility_name),
			tr(AchievementDef.name_key(id)))


func test_achievement_chips_come_after_the_unlocks() -> void:
	var results: Results = _results()
	results.show_unlocks(["swarm"] as Array[String], [] as Array[String], 3,
		["first_run"] as Array[String])
	var chips: Array[Node] = results.get_node("%UnlockedChips").get_children()
	assert_eq(chips.size(), 3)
	assert_eq((chips[2] as Chip).label_key, Results.KEY_ACHIEVEMENT)


func test_a_hidden_achievement_is_named_on_the_results() -> void:
	var results: Results = _results()
	results.show_unlocks([] as Array[String], [] as Array[String], 0,
		["win_escape"] as Array[String])
	assert_string_contains(_chip_texts(results)[0], tr(AchievementDef.name_key("win_escape")))


func test_nothing_earned_hides_the_block() -> void:
	var results: Results = _results()
	results.show_unlocks([] as Array[String], [] as Array[String], 0, [] as Array[String])
	assert_false((results.get_node("%ResultUnlocked") as Control).visible)
