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


## S7.IP (seen in S6.9): the chip's name is formatted into it, so a locale switch
## with the results up builds it again rather than keeping the old language.
func test_an_achievement_chip_follows_a_locale_switch() -> void:
	var locale: String = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var english: String = tr(AchievementDef.name_key("first_run"))
	var results: Results = _results()
	results.show_unlocks([] as Array[String], ["yield"] as Array[String], 0,
		["first_run"] as Array[String])
	TranslationServer.set_locale("de")
	await wait_process_frames(2)
	var german: String = tr(AchievementDef.name_key("first_run"))
	var slot: String = tr(DirectiveDef.slot_key("yield"))
	var texts: Array[String] = _chip_texts(results)
	TranslationServer.set_locale(locale)
	assert_ne(english, german, "the name differs between the two")
	assert_eq(texts.size(), 2)
	assert_string_contains(texts[0], slot, "the slot chip too")
	assert_string_contains(texts[1], german)


## S7.IP: the outcome and the kicker follow the switch too — they were written
## once, when the screen was filled.
func test_the_outcome_follows_a_locale_switch() -> void:
	var locale: String = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var results: Results = _results()
	var outcome: Label = results.get_node("%ResultOutcome") as Label
	var english: String = outcome.text
	TranslationServer.set_locale("de")
	await wait_process_frames(2)
	var german: String = tr("UI_OUTCOME_LOSE_CONTAINED")
	var shown: String = outcome.text
	TranslationServer.set_locale(locale)
	assert_ne(english, german, "the two languages differ")
	assert_eq(shown, german)


## A run that unlocked nothing, after one that did: the switch brings back no
## chip of the run before.
func test_a_locale_switch_brings_back_no_chip_of_an_earlier_run() -> void:
	var locale: String = TranslationServer.get_locale()
	var results: Results = _results()
	results.show_unlocks([] as Array[String], [] as Array[String], 0,
		["first_run"] as Array[String])
	results.show_result(Game.sim)
	TranslationServer.set_locale("de" if locale != "de" else "en")
	await wait_process_frames(2)
	TranslationServer.set_locale(locale)
	await wait_process_frames(2)
	assert_false((results.get_node("%ResultUnlocked") as Control).visible)
