extends GutTest
## S6.13 — the *Benchmark* list and what surrounds a watched run
## (docs/specs/benchmark.md §12.5–§12.7, §16.6–§16.7, §16.9): each status line of
## the global board, the rows for this content and for others, the recorded
## runs, the names a screen reader hears, the title's button and its promise to
## make no request, the strip over a watched run and the results' line.
## No test touches the network: a board is served from a file through the
## client's debug stand-in, or the client's signal is emitted directly.

const BENCHMARK: PackedScene = preload("res://ui/modals/benchmark.tscn")
const TITLE: PackedScene = preload("res://ui/screens/title.tscn")
const STRIP: PackedScene = preload("res://ui/hud/spectator_strip.tscn")
const RESULTS: PackedScene = preload("res://ui/screens/results.tscn")
const CANARY: String = "res://tests/fixtures/bench/determinism_entry.json"
const ROOT: String = "user://test_benchmark_list"
const GENERATED: String = "2026-09-26T04:12:00"
const DATE: String = "2026-09-26"
const MODEL: String = "vendor/model-a"
const QUICK_MODEL: String = "vendor/quick-a"
const RUN_FILE: String = "runs/vendor--model-a__321ae4fb__p1__standard__s1001.json"

var _online: bool = true
var _reduced_motion: bool = false
var _persist: bool = true


func before_each() -> void:
	_online = Settings.bench_online
	_persist = Settings.persist
	# Nothing here writes the player's settings file.
	Settings.persist = false
	_reduced_motion = Settings.reduced_motion
	Settings.reduced_motion = true
	Game.stop_run()
	Game.debug_log = false
	GlobalBoardClient.forget_fetch()
	Fixtures.remove_root(ROOT)
	DirAccess.make_dir_recursive_absolute(ROOT)
	_clear_user_runs()


func after_each() -> void:
	Settings.bench_online = _online
	Settings.reduced_motion = _reduced_motion
	Settings.persist = _persist
	Game.stop_run()
	# A watched run moved the router (it has no slot here); back to the title.
	ScreenRouter.go_to_title()
	GlobalBoardClient.forget_fetch()
	Fixtures.remove_root(ROOT)
	_clear_user_runs()


## The suite's own recorded-runs folder (`pre_run.gd`), emptied.
func _clear_user_runs() -> void:
	Fixtures.remove_root(BenchLibrary.user_dir)


func _canary_bytes() -> PackedByteArray:
	return FileAccess.get_file_as_bytes(CANARY)


func _canary() -> BenchEntry:
	var entry: BenchEntry = BenchEntry.from_bytes(_canary_bytes())
	entry.content_hash = Game.content().content_hash
	return entry


func _write(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


## A board with a row for this content (one run), a bot's row and a row of
## another content.
func _board_text(with_rows: bool = true) -> String:
	var current: String = Game.content().content_hash
	var rows: Array[Dictionary] = []
	if with_rows:
		rows.append({"model": MODEL, "suite": "standard", "content_hash": current,
			"effort": "high", "complete": false, "runs": 1, "of": 10, "wins": 0, "score": 0.0,
			"seeds": [{"seed": 1001, "file": RUN_FILE,
				"sha256": GlobalBoardClient.sha256_hex(_canary_bytes()), "outcome": "timeout",
				"days": 300, "score": 0.0}]})
		rows.append({"model": "bot:greedy", "suite": "standard", "content_hash": current,
			"complete": true, "runs": 10, "of": 10, "wins": 6, "score": 41.0, "seeds": []})
		rows.append({"model": "vendor/old", "suite": "standard", "content_hash": "older",
			"complete": true, "runs": 10, "of": 10, "wins": 7, "score": 70.0, "seeds": []})
	return JSON.stringify({"version": 1, "generated": GENERATED, "content_hash": current,
		"rows": rows})


## The list, its client pointed at the test's folder: `shipped` is the build's
## copy (none when empty), `served` what the stand-in "downloads" ("" = no
## answer at all).
func _modal(shipped: String, served: String = "") -> Control:
	var modal: Control = BENCHMARK.instantiate() as Control
	var client: GlobalBoardClient = modal.get_node("BoardClient") as GlobalBoardClient
	client.cache_dir = ROOT.path_join("cache")
	client.shipped_path = ROOT.path_join("shipped.json")
	if not shipped.is_empty():
		_write(client.shipped_path, shipped.to_utf8_buffer())
	var served_path: String = ROOT.path_join("served/leaderboard.json")
	if not served.is_empty():
		_write(served_path, served.to_utf8_buffer())
		_write(ROOT.path_join("served").path_join(RUN_FILE), _canary_bytes())
	client.local_board_path = served_path
	add_child_autofree(modal)
	return modal


func _status(modal: Control) -> String:
	return str(modal.get(&"status_text"))


func _texts(root: Node) -> Array[String]:
	var out: Array[String] = []
	for label: Node in root.find_children("*", "Label", true, false):
		out.append((label as Label).text)
	return out


func _buttons(root: Node, key: String) -> Array[ConsoleButton]:
	var out: Array[ConsoleButton] = []
	for node: Node in root.find_children("*", "Button", true, false):
		var button: ConsoleButton = node as ConsoleButton
		if button != null and button.label_key == key:
			out.append(button)
	return out


# ------------------------------------------------------------ status lines


func test_setting_off_with_a_local_copy_says_disabled() -> void:
	Settings.bench_online = false
	var modal: Control = _modal(_board_text())
	modal.call(&"open")
	assert_eq(_status(modal), tr("UI_BENCH_GLOBAL_DISABLED").format({"date": DATE}))
	assert_eq((modal.get_node("BoardClient") as GlobalBoardClient).requests_made, 0)


func test_nothing_usable_says_unavailable() -> void:
	Settings.bench_online = false
	var modal: Control = _modal("")
	modal.call(&"open")
	assert_eq(_status(modal), tr("UI_BENCH_GLOBAL_UNAVAILABLE"))


func test_a_fetched_board_says_as_of_its_date() -> void:
	Settings.bench_online = true
	var modal: Control = _modal("", _board_text())
	modal.call(&"open")
	assert_eq(_status(modal), tr("UI_BENCH_GLOBAL_AS_OF").format({"date": DATE}))
	assert_has(_texts(modal), tr("UI_BENCH_GLOBAL_NOTE"))


func test_a_failed_fetch_with_a_local_copy_says_offline() -> void:
	Settings.bench_online = true
	var modal: Control = _modal(_board_text())
	modal.call(&"open")
	assert_eq(_status(modal), tr("UI_BENCH_GLOBAL_OFFLINE").format({"date": DATE}))


func test_while_fetching_it_says_loading() -> void:
	Settings.bench_online = false
	var modal: Control = _modal(_board_text())
	modal.call(&"open")
	var client: GlobalBoardClient = modal.get_node("BoardClient") as GlobalBoardClient
	client.board_changed.emit(null, GlobalBoardClient.SOURCE_NONE, true)
	assert_eq(_status(modal), tr("UI_BENCH_GLOBAL_LOADING"))


func test_a_board_without_rows_says_empty() -> void:
	Settings.bench_online = true
	var modal: Control = _modal("", _board_text(false))
	modal.call(&"open")
	assert_eq(_status(modal), tr("UI_BENCH_GLOBAL_AS_OF").format({"date": DATE}))
	assert_has(_texts(modal), tr("UI_BENCH_GLOBAL_EMPTY"))


func test_a_board_without_a_date_says_so_with_a_dash() -> void:
	Settings.bench_online = false
	var modal: Control = _modal(
		"{\"version\": 1, \"generated\": \"\", \"content_hash\": \"\", \"rows\": []}")
	modal.call(&"open")
	assert_eq(_status(modal), tr("UI_BENCH_GLOBAL_DISABLED").format({"date": "—"}))


# -------------------------------------------------------------------- rows


func test_rows_for_other_content_have_no_runs_button() -> void:
	Settings.bench_online = false
	var modal: Control = _modal(_board_text())
	modal.call(&"open")
	var other: Node = modal.find_child("OtherRows", true, false)
	assert_not_null(other)
	assert_eq(other.get_child_count(), 1)
	assert_eq(other.find_children("*", "Button", true, false).size(), 0)
	assert_has(_texts(other), "vendor/old")
	assert_eq(_buttons(modal.find_child("GlobalRows", true, false), "UI_BENCH_GLOBAL_RUNS").size(),
		1, "each model row of this content has one; the bot waits in its tab")


func test_a_bot_row_reads_as_a_bot() -> void:
	Settings.bench_online = false
	var modal: Control = _modal(_board_text())
	modal.call(&"open")
	modal.call(&"show_tab", "bots")
	assert_has(_texts(modal), tr("UI_BENCH_BOT").format({"policy": "greedy"}))
	assert_does_not_have(_texts(modal), "bot:greedy")


# ------------------------------------------------------------- quick suite


## S6.12e: a quick-suite row for this content with one run, one for another
## content, and — unless `quick_only` — the standard row of `_board_text`.
func _quick_board_text(quick_only: bool = false) -> String:
	var d: Dictionary = JSON.parse_string(_board_text(not quick_only))
	var current: String = Game.content().content_hash
	var rows: Array = d["rows"]
	rows.append({"model": QUICK_MODEL, "suite": "quick", "content_hash": current,
		"effort": "high", "complete": false, "runs": 1, "of": 3, "wins": 0, "score": 39.2,
		"seeds": [{"seed": 1001, "file": RUN_FILE,
			"sha256": GlobalBoardClient.sha256_hex(_canary_bytes()), "outcome": "timeout",
			"days": 300, "score": 0.0}]})
	rows.append({"model": "vendor/quick-old", "suite": "quick", "content_hash": "older",
		"complete": true, "runs": 3, "of": 3, "wins": 1, "score": 30.0, "seeds": []})
	return JSON.stringify(d)


func _rank_text(rank: int, score: float, wins: int, runs: int) -> String:
	return tr("UI_BENCH_GLOBAL_ROW").format({"rank": rank, "score": Format.decimal(score, 1),
		"wins": wins, "runs": runs})


func test_quick_rows_have_their_own_section_and_ranks() -> void:
	Settings.bench_online = false
	var modal: Control = _modal(_quick_board_text())
	modal.call(&"open")
	var quick: Node = modal.find_child("QuickRows", true, false)
	assert_not_null(quick)
	assert_has(_texts(quick), QUICK_MODEL)
	assert_has(_texts(quick), _rank_text(1, 39.2, 0, 1), "ranked among its own suite")
	assert_eq(_buttons(quick, "UI_BENCH_GLOBAL_RUNS").size(), 1)
	var standard: Node = modal.find_child("GlobalRows", true, false)
	assert_does_not_have(_texts(standard), QUICK_MODEL)
	assert_has(_texts(standard), _rank_text(1, 0.0, 0, 1), "the standard ranks are unchanged")
	assert_true((modal.get(&"_quick_title") as Control).visible)
	assert_has(_texts(modal), tr("UI_BENCH_GLOBAL_QUICK_NOTE"))


func test_a_quick_row_of_other_content_says_its_suite() -> void:
	Settings.bench_online = false
	var modal: Control = _modal(_quick_board_text())
	modal.call(&"open")
	var other: Node = modal.find_child("OtherRows", true, false)
	assert_eq(other.get_child_count(), 2)
	assert_has(_texts(other), "vendor/quick-old")
	assert_has(_texts(other), tr("UI_BENCH_GLOBAL_QUICK_TITLE"))
	assert_eq(_texts(other).count(_rank_text(1, 30.0, 1, 3)), 1, "ranked within its suite")


func test_without_quick_rows_the_quick_section_hides() -> void:
	Settings.bench_online = false
	var modal: Control = _modal(_board_text())
	modal.call(&"open")
	assert_false((modal.get(&"_quick_title") as Control).visible)
	assert_false((modal.get(&"_quick_note") as Control).visible)
	assert_eq(modal.find_child("QuickRows", true, false).get_child_count(), 0)


func test_a_board_of_quick_rows_only_is_not_empty() -> void:
	Settings.bench_online = false
	var modal: Control = _modal(_quick_board_text(true))
	modal.call(&"open")
	assert_does_not_have(_texts(modal), tr("UI_BENCH_GLOBAL_EMPTY"))
	assert_has(_texts(modal.find_child("QuickRows", true, false)), QUICK_MODEL)
	assert_has(_texts(modal), tr("UI_BENCH_GLOBAL_NOTE"))


func test_a_quick_run_is_watched() -> void:
	Settings.bench_online = true
	var modal: Control = _modal("", _quick_board_text(true))
	modal.call(&"open")
	var quick: Node = modal.find_child("QuickRows", true, false)
	_buttons(quick, "UI_BENCH_GLOBAL_RUNS")[0].pressed.emit()
	var watch: Array[ConsoleButton] = _buttons(quick, "UI_BENCH_WATCH")
	assert_eq(watch.size(), 1)
	watch_signals(modal)
	watch[0].pressed.emit()
	assert_true(Game.is_spectating(), "the downloaded run plays")
	assert_signal_emitted(modal, "closed")


# -------------------------------------------------------------------- tabs


func test_the_list_opens_on_the_models_and_keeps_the_bots_in_their_tab() -> void:
	Settings.bench_online = false
	var modal: Control = _modal(_quick_board_text())
	modal.call(&"open")
	assert_eq(str(modal.get(&"tab")), "models")
	var tabs: Array[ConsoleButton] = _buttons(modal, "UI_BENCH_TAB_MODELS")
	assert_eq(tabs.size(), 1)
	assert_true(tabs[0].button_pressed)
	assert_false(_buttons(modal, "UI_BENCH_TAB_BOTS")[0].button_pressed)
	assert_does_not_have(_texts(modal), tr("UI_BENCH_BOT").format({"policy": "greedy"}))
	assert_has(_texts(modal), QUICK_MODEL)
	assert_has(_texts(modal), MODEL)


func test_the_bot_tab_shows_only_bots_ranked_among_themselves() -> void:
	Settings.bench_online = false
	var modal: Control = _modal(_quick_board_text())
	modal.call(&"open")
	_buttons(modal, "UI_BENCH_TAB_BOTS")[0].pressed.emit()
	assert_eq(str(modal.get(&"tab")), "bots")
	assert_true(_buttons(modal, "UI_BENCH_TAB_BOTS")[0].button_pressed)
	assert_false(_buttons(modal, "UI_BENCH_TAB_MODELS")[0].button_pressed)
	var texts: Array[String] = _texts(modal.find_child("GlobalRows", true, false))
	assert_has(texts, tr("UI_BENCH_BOT").format({"policy": "greedy"}))
	assert_has(texts, _rank_text(1, 41.0, 6, 10), "the bot is first among bots")
	assert_does_not_have(_texts(modal), MODEL)
	assert_does_not_have(_texts(modal), QUICK_MODEL)
	assert_eq(modal.find_child("QuickRows", true, false).get_child_count(), 0)
	assert_false((modal.get(&"_quick_title") as Control).visible)


func test_a_tab_without_rows_says_empty_and_the_tab_survives_a_rebuild() -> void:
	Settings.bench_online = false
	var d: Dictionary = JSON.parse_string(_board_text())
	var rows: Array = d["rows"]
	rows.remove_at(1)
	var modal: Control = _modal(JSON.stringify(d))
	modal.call(&"open")
	modal.call(&"show_tab", "bots")
	assert_has(_texts(modal), tr("UI_BENCH_GLOBAL_EMPTY"), "no bot rows on this board")
	modal.notification(Node.NOTIFICATION_TRANSLATION_CHANGED)
	assert_eq(str(modal.get(&"tab")), "bots")
	assert_true(_buttons(modal, "UI_BENCH_TAB_BOTS")[0].button_pressed)


func test_the_quick_suite_comes_before_the_standard_suite() -> void:
	Settings.bench_online = false
	var modal: Control = _modal(_quick_board_text())
	modal.call(&"open")
	var quick: Node = modal.find_child("QuickRows", true, false)
	var standard: Node = modal.find_child("GlobalRows", true, false)
	assert_lt(quick.get_index(), standard.get_index())
	assert_true((modal.get(&"_standard_title") as Control).visible)


func test_rows_are_ranked_best_score_first_an_incomplete_one_too() -> void:
	Settings.bench_online = false
	var d: Dictionary = JSON.parse_string(_quick_board_text(true))
	var current: String = Game.content().content_hash
	var rows: Array = d["rows"]
	rows.push_front({"model": "vendor/weaker", "suite": "quick", "content_hash": current,
		"complete": true, "runs": 3, "of": 3, "wins": 1, "score": 22.1, "seeds": []})
	var modal: Control = _modal(JSON.stringify(d))
	modal.call(&"open")
	var texts: Array[String] = _texts(modal.find_child("QuickRows", true, false))
	assert_has(texts, _rank_text(1, 39.2, 0, 1), "the incomplete row scores best")
	assert_has(texts, _rank_text(2, 22.1, 1, 3))
	assert_lt(texts.find(QUICK_MODEL), texts.find("vendor/weaker"))


func test_runs_open_and_a_listed_run_is_watched() -> void:
	Settings.bench_online = true
	var modal: Control = _modal("", _board_text())
	modal.call(&"open")
	var toggle: ConsoleButton = _buttons(modal, "UI_BENCH_GLOBAL_RUNS")[0]
	toggle.pressed.emit()
	assert_eq(toggle.label_key, "UI_BENCH_GLOBAL_HIDE")
	var watch: Array[ConsoleButton] = _buttons(modal.find_child("GlobalRows", true, false),
		"UI_BENCH_WATCH")
	assert_eq(watch.size(), 1)
	assert_eq(watch[0].accessibility_name, A11y.label_value(tr("UI_BENCH_WATCH"),
		MODEL + " " + tr("UI_SPECTATOR_SEED").format({"seed": 1001})))
	watch_signals(modal)
	watch[0].pressed.emit()
	assert_true(Game.is_spectating(), "the downloaded run plays")
	assert_eq(Game.spectator().entry.seed_value, 1001)
	assert_signal_emitted(modal, "closed")


func test_a_run_that_changed_after_its_check_is_not_watched() -> void:
	Settings.bench_online = true
	var modal: Control = _modal("", _board_text())
	_write(ROOT.path_join("served").path_join(RUN_FILE), "{}".to_utf8_buffer())
	modal.call(&"open")
	_buttons(modal, "UI_BENCH_GLOBAL_RUNS")[0].pressed.emit()
	_buttons(modal.find_child("GlobalRows", true, false), "UI_BENCH_WATCH")[0].pressed.emit()
	assert_false(Game.is_spectating())
	assert_has(_texts(modal), tr("UI_BENCH_GLOBAL_FAIL_CHANGED"))


func test_recorded_runs_are_listed_with_a_named_watch_button() -> void:
	Settings.bench_online = false
	_write(BenchLibrary.user_dir.path_join("mock.json"), _canary_bytes())
	var modal: Control = _modal("")
	modal.call(&"open")
	var local: Node = modal.find_child("LocalRuns", true, false)
	assert_not_null(local)
	assert_has(_texts(local), "mock")
	var watch: Array[ConsoleButton] = _buttons(local, "UI_BENCH_WATCH")
	assert_eq(watch.size(), 1)
	assert_eq(watch[0].accessibility_name, A11y.label_value(tr("UI_BENCH_WATCH"),
		"mock " + tr("UI_SPECTATOR_SEED").format({"seed": 1001})))
	assert_false(watch[0].disabled)


func test_a_recorded_run_of_other_content_cannot_be_watched() -> void:
	Settings.bench_online = false
	var d: Dictionary = JSON.parse_string(_canary_bytes().get_string_from_utf8())
	d["content_hash"] = "older"
	_write(BenchLibrary.user_dir.path_join("old.json"), JSON.stringify(d).to_utf8_buffer())
	var modal: Control = _modal("")
	modal.call(&"open")
	var local: Node = modal.find_child("LocalRuns", true, false)
	assert_true(_buttons(local, "UI_BENCH_WATCH")[0].disabled)
	assert_has(_texts(local), tr("UI_BENCH_OTHER_VERSION"))


# ------------------------------------------------------------------- title


func test_the_title_makes_no_request_and_shows_the_button_by_the_rule() -> void:
	Settings.bench_online = false
	var title: Control = TITLE.instantiate() as Control
	add_child_autofree(title)
	var client: GlobalBoardClient = title.find_child("BoardClient", true, false) as GlobalBoardClient
	assert_eq(client.requests_made, 0, "opening the title makes no request")
	var button: ConsoleButton = title.call(&"benchmark_button") as ConsoleButton
	if client.local_board() == null or client.local_board().rows.is_empty():
		assert_false(button.visible, "nothing to show: no button")
	title.queue_free()
	await wait_process_frames(1)
	_write(BenchLibrary.user_dir.path_join("mock.json"), _canary_bytes())
	var with_entry: Control = TITLE.instantiate() as Control
	add_child_autofree(with_entry)
	assert_true((with_entry.call(&"benchmark_button") as ConsoleButton).visible,
		"a recorded run shows it")
	_clear_user_runs()
	Settings.bench_online = true
	var online: Control = TITLE.instantiate() as Control
	add_child_autofree(online)
	assert_true((online.call(&"benchmark_button") as ConsoleButton).visible,
		"the online setting shows it")
	assert_eq((online.find_child("BoardClient", true, false) as GlobalBoardClient).requests_made,
		0, "and still asks nothing of the network")


func test_the_online_setting_is_a_title_row() -> void:
	var title: Control = TITLE.instantiate() as Control
	add_child_autofree(title)
	var settings: Control = title.find_child("TitleSettings", true, false) as Control
	settings.call(&"open_settings_only")
	var button: ConsoleButton = settings.call(&"bench_online_button") as ConsoleButton
	var row: Control = button.get_parent() as Control
	assert_true(row.visible, "a row of the title's settings")
	Settings.bench_online = true
	button.pressed.emit()
	assert_false(Settings.bench_online)
	assert_eq(button.accessibility_name, A11y.label_value(tr("UI_SETTINGS_BENCH_ONLINE"),
		tr("UI_SETTINGS_OFF")))
	settings.call(&"open_menu")
	assert_false(row.visible, "not in the pause menu")


# ------------------------------------------------------ strip and results


func test_the_strip_is_one_named_readout() -> void:
	var entry: BenchEntry = _canary()
	assert_eq(Game.start_spectating(entry), "")
	var strip: PanelContainer = STRIP.instantiate() as PanelContainer
	add_child_autofree(strip)
	Game.advance(15)
	assert_true(strip.visible)
	assert_eq(strip.focus_mode, Control.FOCUS_ACCESSIBILITY)
	var decision: BenchDecision = Game.spectator().decision_at(Game.sim.world.day)
	var index: int = Game.spectator().decision_index(Game.sim.world.day)
	assert_eq(strip.accessibility_name, A11y.label_value(tr("UI_SPECTATOR_WATCHING"),
		tr("UI_A11Y_SPECTATOR").format({"model": "mock", "seed": 1001,
			"effort": BenchEffort.label(BenchEffort.NORMAL), "decision": index,
			"total": entry.decisions.size(),
			"stance": BenchPrompt.stance_name(decision.stance)})))
	assert_has(_texts(strip), "mock")


func test_the_strip_hides_for_a_player_s_run() -> void:
	Game.start_run(1)
	var strip: PanelContainer = STRIP.instantiate() as PanelContainer
	add_child_autofree(strip)
	assert_false(strip.visible)


func test_the_results_say_where_a_replay_left_the_recording() -> void:
	var entry: BenchEntry = _canary()
	Game.start_spectating(entry)
	Game.advance(3)
	var results: Control = RESULTS.instantiate() as Control
	add_child_autofree(results)
	results.call(&"show_result", Game.sim)
	results.call(&"show_spectator", entry, false, 42)
	var line: Label = results.call(&"spectator_line") as Label
	assert_true(line.visible)
	assert_eq(line.text, tr("UI_SPECTATOR_RESULT_DIVERGED").format(
		{"day": Format.number(42.0, Format.Kind.DAYS)}))
	results.call(&"show_spectator", entry, false, -1)
	assert_eq(line.text, tr("UI_SPECTATOR_RESULT_DIVERGED").format(
		{"day": Format.number(float(Game.sim.world.day), Format.Kind.DAYS)}),
		"only the hash differs: the end day")
	assert_eq(tr("UI_OUTCOME_TIMEOUT"), (results.get_node("%ResultOutcome") as Label).text,
		"a run with no outcome yet reads as out of time")
	assert_eq((results.call(&"again_button") as ConsoleButton).label_key,
		"UI_SPECTATOR_WATCH_AGAIN")
	results.call(&"show_result", Game.sim)
	assert_false(line.visible, "a player's results have no such line")
	assert_eq((results.call(&"again_button") as ConsoleButton).label_key, "UI_RESULT_AGAIN")


func test_every_row_says_its_effort_and_a_bot_shows_the_dash() -> void:
	Settings.bench_online = false
	_write(BenchLibrary.user_dir.path_join("mock.json"), _canary_bytes())
	var modal: Control = _modal(_board_text())
	modal.call(&"open")
	var rows: Node = modal.find_child("GlobalRows", true, false)
	assert_has(_texts(rows), BenchEffort.line("high"))
	modal.call(&"show_tab", "bots")
	assert_has(_texts(modal.find_child("GlobalRows", true, false)), BenchEffort.line(""),
		"the bot row")
	assert_has(_texts(modal.find_child("LocalRuns", true, false)), BenchEffort.line("normal"))
