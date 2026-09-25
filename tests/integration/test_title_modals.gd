extends GutTest
## S5.7 — the title's Codex and Statistics (spec screens-full.md §6.1, §6.2):
## locked entries, the hidden endings, the totals and *Play this seed again*.
## S6.7 — the Codex's *How to play* tab (first-run.md §6.6).

const CODEX: PackedScene = preload("res://ui/modals/codex.tscn")
const STATISTICS: PackedScene = preload("res://ui/modals/statistics.tscn")
const Codex: GDScript = preload("res://ui/modals/codex.gd")
const Statistics: GDScript = preload("res://ui/modals/statistics.gd")
## A phone's logical window (ui-foundation §5.7).
const PHONE_WIDTH: int = 400
const PHONE_HEIGHT: int = 860


func before_each() -> void:
	ProfileManager.reset()


func after_each() -> void:
	ProfileManager.reset()


## The Codex on `tab` — Regions for the S5.7 tests, which were written before
## *How to play* became the first tab.
func _codex(tab: String = CodexEntries.TAB_REGIONS) -> Codex:
	var codex: Codex = CODEX.instantiate() as Codex
	add_child_autofree(codex)
	codex.open(tab)
	return codex


func _statistics() -> Statistics:
	var statistics: Statistics = STATISTICS.instantiate() as Statistics
	add_child_autofree(statistics)
	statistics.open()
	return statistics


func test_a_region_not_met_is_listed_locked() -> void:
	ProfileManager.merge_codex("regions", ["usa"] as Array[String])
	var codex: Codex = _codex()
	var usa: ConsoleButton = codex.row_for("usa")
	assert_false(usa.disabled)
	assert_eq(usa.text, tr("REGION_USA"))
	var canada: ConsoleButton = codex.row_for("canada")
	assert_true(canada.disabled, "a locked entry cannot be opened")
	assert_eq(canada.text, tr("UI_CODEX_LOCKED"))
	assert_eq(codex.entry_id, "usa", "the first entry met opens at full width")
	codex.show_entry("canada")
	assert_eq(codex.entry_id, "usa")


func test_endings_not_reached_are_not_listed() -> void:
	ProfileManager.endings_seen = ["win_ascendance_ashes"] as Array[String]
	var codex: Codex = _codex()
	codex.show_tab(CodexEntries.TAB_ENDINGS)
	assert_not_null(codex.row_for("win_ascendance_ashes"))
	assert_null(codex.row_for("win_escape"), "the hidden ending is never named early")
	var total: int = CodexEntries.ending_variants(Game.db).size()
	assert_eq((codex.get_node("%Progress") as Label).text,
		tr("UI_CODEX_PROGRESS").format({"seen": 1, "total": total}),
		"the tab still says how many there are")


func test_every_tab_opens() -> void:
	ProfileManager.merge_codex("factions", ["ai_labs"] as Array[String])
	ProfileManager.merge_codex("tech", ["open_weights_leak"] as Array[String])
	ProfileManager.merge_codex("characters", ["operator"] as Array[String])
	ProfileManager.merge_codex("statuses", ["lockdown"] as Array[String])
	var codex: Codex = _codex()
	for tab: String in CodexEntries.TABS:
		codex.show_tab(tab)
		assert_eq(codex.tab, tab)
	codex.show_tab(CodexEntries.TAB_ARCHITECTURES)
	codex.show_entry("swarm")
	assert_eq(codex.entry_id, "swarm", "a locked architecture opens on its unlock rule")


func test_an_ending_variant_knows_its_outcome() -> void:
	assert_eq(CodexEntries.outcome_of("win_ascendance_ashes"), "win_ascendance")
	assert_eq(CodexEntries.outcome_of("lose_contained"), "lose_contained")
	var variants: Array[String] = CodexEntries.ending_variants(Game.content())
	for i: int in range(1, World.OUTCOME_IDS.size()):
		assert_true(variants.has(World.OUTCOME_IDS[i]), "every outcome is an ending")


func test_the_totals_of_an_empty_profile() -> void:
	var totals: Dictionary[String, String] = _statistics().totals()
	assert_eq(totals[Statistics.KEY_RUNS], "0")
	assert_eq(totals[Statistics.KEY_WIN_RATE], Statistics.DASH)
	assert_eq(totals[Statistics.KEY_FASTEST], Statistics.DASH)


func test_the_totals_read_the_profile() -> void:
	ProfileManager.runs_completed = 4
	ProfileManager.runs_won = 1
	ProfileManager.by_architecture = {"language_model": {"runs": 4, "wins": 1,
		"best_days": 210}}
	var totals: Dictionary[String, String] = _statistics().totals()
	assert_eq(totals[Statistics.KEY_RUNS], "4")
	assert_eq(totals[Statistics.KEY_WIN_RATE], Format.percent(0.25))
	assert_eq(totals[Statistics.KEY_FASTEST], "210")


func test_play_this_seed_again_hands_over_the_run() -> void:
	ProfileManager.history = [{"n": 3, "architecture": "language_model", "difficulty": "hard",
		"directives": ["yield_greedy"], "outcome": "lose_contained",
		"variant": "lose_contained", "days": 120, "seed": 777, "origin": "usa",
		"regions": [1], "controlled": []}]
	var statistics: Statistics = _statistics()
	watch_signals(statistics)
	var replay: ConsoleButton = null
	for button: Node in statistics.find_children("*", "ConsoleButton", true, false):
		if (button as ConsoleButton).label_key == Statistics.KEY_REPLAY:
			replay = button as ConsoleButton
	assert_not_null(replay)
	replay.emit_signal("pressed")
	assert_signal_emitted(statistics, "replay_requested")
	var args: Array = get_signal_parameters(statistics, "replay_requested")
	assert_eq(int(args[0]), 777)
	var setup: RunSetup = args[1]
	assert_eq(setup.difficulty, "hard")
	assert_eq(setup.directives, ["yield_greedy"] as Array[String])


## S5.8 (scenarios.md §1): a run played in a scenario names it beside its
## architecture, and *Play this seed again* carries it.
func test_a_scenario_run_is_named_and_replayed_with_its_scenario() -> void:
	ProfileManager.history = [{"n": 4, "architecture": "swarm", "difficulty": "standard",
		"directives": [], "scenario": "airgap_earth", "outcome": "lose_contained",
		"variant": "lose_contained", "days": 300, "seed": 42, "origin": "nigeria",
		"regions": [1], "controlled": []}]
	var statistics: Statistics = _statistics()
	var expected: String = tr("UI_STATS_SCENARIO_PAIR").format({
		"architecture": tr("ARCH_SWARM_NAME"), "scenario": tr("SCENARIO_AIRGAP_EARTH_NAME")})
	var texts: Array[String] = []
	for label: Node in statistics.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	assert_has(texts, expected)
	watch_signals(statistics)
	for button: Node in statistics.find_children("*", "ConsoleButton", true, false):
		if (button as ConsoleButton).label_key == Statistics.KEY_REPLAY:
			button.emit_signal("pressed")
	var setup: RunSetup = get_signal_parameters(statistics, "replay_requested")[1]
	assert_eq(setup.scenario, "airgap_earth")
	assert_eq(setup.architecture, "swarm")


func test_a_run_without_a_scenario_is_named_by_its_architecture_alone() -> void:
	ProfileManager.history = [{"n": 1, "architecture": "swarm", "difficulty": "standard",
		"directives": [], "outcome": "lose_contained", "variant": "lose_contained",
		"days": 300, "seed": 42, "origin": "usa", "regions": [1], "controlled": []}]
	var texts: Array[String] = []
	for label: Node in _statistics().find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	assert_has(texts, tr("ARCH_SWARM_NAME"))


func test_the_codex_opens_on_how_to_play() -> void:
	var codex: Codex = CODEX.instantiate() as Codex
	add_child_autofree(codex)
	codex.open()
	assert_eq(codex.tab, CodexEntries.TAB_HELP)
	assert_eq(CodexEntries.TABS[0], CodexEntries.TAB_HELP, "the first of eight tabs")
	assert_eq(codex.entry_id, HelpPages.ids()[0], "the first page opens at full width")


func test_every_help_page_opens() -> void:
	var codex: Codex = _codex(CodexEntries.TAB_HELP)
	for id: String in HelpPages.ids():
		var row: ConsoleButton = codex.row_for(id)
		assert_not_null(row, id)
		assert_false(row.disabled, "a page is never locked: %s" % id)
		codex.show_entry(id)
		assert_eq(codex.entry_id, id)


func test_the_progress_caption_hides_on_how_to_play_only() -> void:
	var codex: Codex = _codex(CodexEntries.TAB_HELP)
	var progress: Control = codex.get_node("%Progress") as Control
	assert_false(progress.visible, "pages are not collected")
	codex.show_tab(CodexEntries.TAB_REGIONS)
	assert_true(progress.visible)


func test_a_page_can_be_opened_by_name() -> void:
	var codex: Codex = CODEX.instantiate() as Codex
	add_child_autofree(codex)
	codex.open(CodexEntries.TAB_HELP, "tree")
	assert_eq(codex.entry_id, "tree")
	var entry: Control = codex.get_node("%Entry") as Control
	var texts: Array[String] = []
	for label: Node in entry.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	assert_has(texts, tr("HELP_TREE_TITLE"))
	assert_has(texts, tr("HELP_TREE_P1"))
	assert_has(texts, tr("HELP_TREE_P%d" % HelpPages.paragraphs("tree")))


func test_a_page_opened_by_name_on_a_phone_goes_straight_to_it() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(PHONE_WIDTH, PHONE_HEIGHT)
	add_child_autofree(viewport)
	var codex: Codex = CODEX.instantiate() as Codex
	viewport.add_child(codex)
	codex.open(CodexEntries.TAB_HELP, "tree")
	assert_eq(codex.entry_id, "tree")
	assert_false((codex.get_node("%ListScroll") as Control).visible, "the entry is a page")
	assert_true((codex.get_node("%EntryScroll") as Control).visible)
	assert_true((codex.get_node("%BackButton") as Control).visible)


func test_an_unknown_page_falls_back_to_the_first() -> void:
	var codex: Codex = CODEX.instantiate() as Codex
	add_child_autofree(codex)
	codex.open(CodexEntries.TAB_HELP, "no_such_page")
	assert_eq(codex.entry_id, HelpPages.ids()[0])
