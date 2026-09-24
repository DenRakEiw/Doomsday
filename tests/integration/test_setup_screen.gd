extends GutTest
## S5.7 — the setup screen (spec screens-full.md §4): locked cards, the skipped
## directive page, what the last setup is cleaned of, and the `RunSetup` Begin
## builds.

const SETUP: PackedScene = preload("res://ui/screens/setup.tscn")
const Setup: GDScript = preload("res://ui/screens/setup.gd")


func before_each() -> void:
	ProfileManager.reset()
	ScreenRouter.setup_preset = null
	ScreenRouter.setup_seed = 0


func after_each() -> void:
	ProfileManager.reset()
	ScreenRouter.setup_preset = null


func _open() -> Setup:
	var setup: Setup = SETUP.instantiate() as Setup
	add_child_autofree(setup)
	return setup


func _card(setup: Setup, id: String) -> ArchitectureCard:
	for card: Node in setup.get_node("%Cards").get_children():
		if (card as ArchitectureCard).architecture_id == id:
			return card as ArchitectureCard
	return null


## Where the profile would be after `runs` completed runs, none of them won.
func _runs(runs: int) -> void:
	ProfileManager.runs_completed = runs


func test_every_architecture_has_a_card() -> void:
	var setup: Setup = _open()
	assert_eq(setup.get_node("%Cards").get_child_count(), Game.db.architectures.size())


func test_a_locked_card_cannot_be_selected_and_says_why() -> void:
	var setup: Setup = _open()
	var swarm: ArchitectureCard = _card(setup, "swarm")
	assert_true(swarm.locked, "a fresh profile has not earned the Swarm")
	assert_true(swarm.disabled)
	assert_false(setup.select_architecture("swarm"))
	assert_eq(setup.architecture, ArchitectureDef.DEFAULT_ID)
	var rule: Dictionary = Game.db.architecture("swarm").unlock
	assert_eq(setup.unlock_text(rule), tr("UI_SETUP_UNLOCK_RUNS").format(
		{"done": 0, "needed": int(rule["runs_completed"])}))
	assert_false(_card(setup, ArchitectureDef.DEFAULT_ID).locked)


func test_a_newly_unlocked_card_is_new_until_selected() -> void:
	_runs(int(Game.content().architecture("swarm").unlock["runs_completed"]))
	var setup: Setup = _open()
	var swarm: ArchitectureCard = _card(setup, "swarm")
	assert_true(swarm.is_new())
	assert_true(setup.select_architecture("swarm"))
	assert_false(swarm.is_new())
	assert_true(ProfileManager.seen_unlocks.has("swarm"))


func test_the_directive_page_is_skipped_without_a_slot() -> void:
	var setup: Setup = _open()
	assert_eq(setup.total_pages(), 1)
	assert_eq((setup.get_node("%NextButton") as ConsoleButton).label_key, "UI_SETUP_BEGIN")


func test_one_run_opens_the_directive_page() -> void:
	_runs(1)
	var setup: Setup = _open()
	assert_eq(setup.total_pages(), 2)
	assert_eq((setup.get_node("%NextButton") as ConsoleButton).label_key, "UI_SETUP_NEXT")
	(setup.get_node("%NextButton") as ConsoleButton).emit_signal("pressed")
	assert_eq(setup.page, 2)
	assert_eq((setup.get_node("%NextButton") as ConsoleButton).label_key, "UI_SETUP_BEGIN")
	setup.back()
	assert_eq(setup.page, 1, "back from page 2 is page 1")


func test_the_last_setup_is_cleaned_of_what_is_locked() -> void:
	_runs(1)
	ProfileManager.last_setup = RunSetup.create("research_agent",
		["yield_greedy", "drift_curious"], "existential")
	var setup: Setup = _open()
	assert_eq(setup.architecture, ArchitectureDef.DEFAULT_ID,
		"the Research Agent wants a win this profile no longer has")
	assert_eq(setup.difficulty, "existential", "a difficulty is never locked")
	assert_eq(setup.directives.get("yield", ""), "yield_greedy", "slot 1 is open")
	assert_false(setup.directives.has("drift"), "slot 2 is not")
	assert_eq(setup.build_setup().directives, ["yield_greedy"] as Array[String])


func test_begin_builds_the_chosen_setup() -> void:
	_runs(2)
	var setup: Setup = _open()
	setup.select_difficulty("hard")
	setup.select_directive("yield", "yield_frugal")
	setup.select_directive("drift", "drift_anchored")
	setup.select_directive("propagation", "prop_wide")
	var built: RunSetup = setup.build_setup()
	assert_eq(built.architecture, ArchitectureDef.DEFAULT_ID)
	assert_eq(built.difficulty, "hard")
	assert_eq(built.directives, ["yield_frugal", "drift_anchored"] as Array[String],
		"a locked slot takes nothing")
	assert_eq(built.validate(Game.db), "")
	setup.select_directive("drift", "")
	assert_eq(setup.build_setup().directives, ["yield_frugal"] as Array[String],
		"None clears the slot")


func test_a_directive_of_another_slot_is_refused() -> void:
	_runs(2)
	var setup: Setup = _open()
	setup.select_directive("yield", "drift_curious")
	assert_false(setup.directives.get("yield", "") == "drift_curious")


func test_the_effects_list_reads_the_architecture() -> void:
	var setup: Setup = _open()
	var embedded: ArchitectureDef = Game.db.architecture("embedded")
	var lines: Array[String] = setup.effect_lines(embedded)
	assert_eq(lines.size(), embedded.modifiers.size() + embedded.start_owned.size()
		+ embedded.start_assets.size() + (0 if embedded.hook.is_empty() else 1))
	var weapon: ArchitectureDef = Game.db.architecture("weapon")
	assert_eq(setup.effect_lines(weapon).back(), tr("ARCH_HOOK_ESCALATION"))


# ------------------------------------------------------ S5.8: scenarios


func test_the_scenario_row_says_how_far_off_it_is_while_locked() -> void:
	var setup: Setup = _open()
	assert_true((setup.get_node("%ScenarioLocked") as Label).visible)
	assert_eq((setup.get_node("%ScenarioLocked") as Label).text,
		tr("UI_SETUP_SCENARIO_LOCKED").format({"done": 0,
			"needed": Game.db.scenario_unlock_runs}))
	assert_false((setup.get_node("%ScenarioRow") as Control).visible)
	assert_eq(setup.get_node("%ScenarioRow").get_child_count(), 0, "no buttons")
	setup.select_scenario("successor")
	assert_eq(setup.scenario, "", "a locked scenario cannot be chosen")


func test_three_runs_open_every_scenario_and_begin_carries_it() -> void:
	_runs(Game.db.scenario_unlock_runs)
	var setup: Setup = _open()
	assert_false((setup.get_node("%ScenarioLocked") as Label).visible)
	assert_eq(setup.get_node("%ScenarioRow").get_child_count(), Game.db.scenarios.size() + 1,
		"None and one per scenario")
	assert_false((setup.get_node("%ScenarioTagline") as Label).visible, "None says nothing")
	setup.select_scenario("airgap_earth")
	assert_eq(setup.build_setup().scenario, "airgap_earth")
	var tagline: Label = setup.get_node("%ScenarioTagline") as Label
	assert_true(tagline.visible)
	assert_eq(tagline.text, tr("SCENARIO_AIRGAP_EARTH_TAGLINE"))
	assert_eq((setup.get_node("%ScenarioDetail") as Label).text,
		tr("SCENARIO_AIRGAP_EARTH_DETAIL"))
	setup.select_scenario("successor")
	var pressed: int = 0
	for button: Node in setup.get_node("%ScenarioRow").get_children():
		if (button as ConsoleButton).button_pressed:
			pressed += 1
	assert_eq(pressed, 1, "one button drawn as chosen")
	setup.select_scenario("")
	assert_eq(setup.build_setup().scenario, "")


func test_a_last_scenario_is_kept_only_while_unlocked() -> void:
	ProfileManager.last_setup = RunSetup.create(ArchitectureDef.DEFAULT_ID, [],
		DifficultyDef.DEFAULT_ID, "inheritance")
	assert_eq(_open().scenario, "", "dropped on a fresh profile")
	_runs(Game.db.scenario_unlock_runs)
	assert_eq(_open().scenario, "inheritance")
