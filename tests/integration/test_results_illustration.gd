extends GutTest
## S6.3 — the ending's picture on the results screen and in the Codex
## (`docs/specs/illustrations.md` §8.3): shown when the ending names one and its
## file exists, otherwise no slot at all.

const RESULTS: PackedScene = preload("res://ui/screens/results.tscn")
const CODEX: PackedScene = preload("res://ui/modals/codex.tscn")
const Results: GDScript = preload("res://ui/screens/results.gd")
const Codex: GDScript = preload("res://ui/modals/codex.gd")
## Holds `end_ascendance.png` only.
const FIXTURE_ROOT: String = "res://tests/fixtures/illustrations"


func before_each() -> void:
	ProfileManager.reset()
	Game.stop_run()
	Game.start_run(1)
	Game.apply(ChooseOriginCommand.new(Game.db.regions[1].id))


func after_each() -> void:
	Game.stop_run()
	ProfileManager.reset()


func _results(outcome: World.Outcome) -> Results:
	var results: Results = RESULTS.instantiate() as Results
	add_child_autofree(results)
	results.illustration_root = FIXTURE_ROOT
	Game.sim.world.outcome = outcome
	results.show_result(Game.sim)
	return results


func test_win_with_file_shows_slot() -> void:
	var results: Results = _results(World.Outcome.WIN_ASCENDANCE)
	var slot: IllustrationSlot = results.illustration()
	assert_true(slot.visible)
	assert_true(slot.has_picture())
	var kicker: Control = results.get_node("%ResultKicker") as Control
	assert_eq(slot.get_index(), kicker.get_index() - 1, "above the kicker")
	assert_eq(slot.width, 420.0)


func test_win_without_file_shows_no_slot() -> void:
	var results: Results = _results(World.Outcome.WIN_MERGE)
	assert_false(results.illustration().visible, "no glyph in place of a missing picture")


func test_loss_shows_no_slot() -> void:
	var results: Results = _results(World.Outcome.LOSE_CONTAINED)
	assert_false(results.illustration().visible)


func test_codex_ending_entry_shows_slot_when_file_exists() -> void:
	ProfileManager.endings_seen = ["win_ascendance", "lose_contained"] as Array[String]
	var codex: Codex = CODEX.instantiate() as Codex
	add_child_autofree(codex)
	codex.illustration_root = FIXTURE_ROOT
	codex.open()
	codex.show_tab(CodexEntries.TAB_ENDINGS)
	codex.show_entry("win_ascendance")
	var slot: IllustrationSlot = codex.entry_illustration()
	assert_not_null(slot)
	assert_true(slot.has_picture())
	codex.show_entry("lose_contained")
	assert_null(codex.entry_illustration(), "a loss has no picture")
