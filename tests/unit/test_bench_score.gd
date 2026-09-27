extends GutTest
## S6.12 — the score and the leaderboard rows (docs/specs/benchmark.md §10.1,
## §10.3, §16.3), and the writer that turns them into the board's two files.

const Writer := preload("res://tools/bench/leaderboard_writer.gd")
const BOARD: String = "user://test_bench/score_board"

var _config: BenchConfig = null


func before_each() -> void:
	_config = BenchConfig.load_file()
	_clear(BOARD)


func after_all() -> void:
	_clear(BOARD)


func _clear(dir: String) -> void:
	for sub: String in [dir.path_join(Writer.RUNS_DIR), dir]:
		for file_name: String in DirAccess.get_files_at(sub):
			DirAccess.remove_absolute(sub.path_join(file_name))
		DirAccess.remove_absolute(sub)


func _entry(model: String, seed_value: int, outcome: String, days: int, suite: String = "quick",
		content_hash: String = "now", params: Dictionary = {"temperature": 0.0}) -> BenchEntry:
	var entry: BenchEntry = BenchEntry.new()
	entry.model = model
	entry.backend = "mock:cheapest"
	entry.params = params
	entry.params_id = BenchEntry.params_id_of(params)
	entry.locale = "en"
	entry.suite = suite
	entry.content_hash = content_hash
	entry.seed_value = seed_value
	entry.setup = RunSetup.new()
	entry.max_days = 2000
	entry.outcome = outcome
	entry.days = days
	entry.end_day = days
	entry.score = BenchScore.run_score(outcome, days, 2000, _config)
	entry.file = "runs/" + entry.file_name()
	entry.sha256 = "%064d" % seed_value
	entry.calls = 10
	return entry


func _quick(model: String, outcomes: Array, content_hash: String = "now") -> Array[BenchEntry]:
	var out: Array[BenchEntry] = []
	var seeds: Array[int] = _config.suite_seeds("quick")
	for i: int in outcomes.size():
		var pair: Array = outcomes[i]
		out.append(_entry(model, seeds[i], str(pair[0]), int(pair[1]), "quick", content_hash))
	return out


func test_a_win_scores_by_its_speed_and_anything_else_scores_nothing() -> void:
	assert_almost_eq(BenchScore.run_score("win_merge", 0, 2000, _config), 100.0, 0.0001)
	assert_almost_eq(BenchScore.run_score("win_ascendance", 400, 2000, _config), 90.0, 0.0001)
	assert_almost_eq(BenchScore.run_score("win_extinction", 1600, 2000, _config), 60.0, 0.0001)
	assert_almost_eq(BenchScore.run_score("win_escape", 2000, 2000, _config), 50.0, 0.0001)
	assert_almost_eq(BenchScore.run_score("win_escape", 2600, 2000, _config), 50.0, 0.0001)
	assert_eq(BenchScore.run_score("lose_contained", 300, 2000, _config), 0.0)
	assert_eq(BenchScore.run_score("timeout", 2000, 2000, _config), 0.0)


func test_rows_group_by_the_seven_keys() -> void:
	var entries: Array[BenchEntry] = _quick("a", [["win_merge", 400], ["lose_contained", 100]])
	var other: BenchEntry = _entry("a", 1003, "win_merge", 400)
	other.locale = "de"
	entries.append(other)
	var older: BenchEntry = _entry("a", 1001, "win_merge", 400, "quick", "then")
	entries.append(older)
	var tuned: BenchEntry = _entry("a", 1001, "win_merge", 400, "quick", "now",
		{"temperature": 0.5})
	entries.append(tuned)
	var prompt: BenchEntry = _entry("a", 1001, "win_merge", 400)
	prompt.prompt_version = 2
	entries.append(prompt)
	var parser: BenchEntry = _entry("a", 1001, "win_merge", 400)
	parser.parser_version = 2
	entries.append(parser)
	var suite: BenchEntry = _entry("a", 1001, "win_merge", 400, "standard")
	entries.append(suite)
	entries.append(_entry("b", 1001, "win_merge", 400))
	var rows: Array[Dictionary] = BenchScore.rows(entries, _config, "now")
	assert_eq(rows.size(), 8)
	var first_group: int = 0
	for row: Dictionary in rows:
		if int(row["runs"]) == 2:
			first_group += 1
	assert_eq(first_group, 1, "the two plain runs are one row")


func test_a_row_scores_the_mean_and_counts_the_outcomes() -> void:
	var rows: Array[Dictionary] = BenchScore.rows(_quick("a", [["win_merge", 400],
		["win_ascendance", 1600], ["lose_contained", 100]]), _config, "now")
	var row: Dictionary = rows[0]
	assert_almost_eq(float(row["score"]), 50.0, 0.0001)
	assert_eq(int(row["wins"]), 2)
	assert_eq(int(row["mean_win_days"]), 1000)
	assert_eq(row["outcomes"], {"lose_contained": 1, "win_ascendance": 1, "win_merge": 1})
	assert_true(bool(row["complete"]))
	assert_true(bool(row["current"]))
	assert_eq(int(row["of"]), 3)
	assert_eq(int(row["calls"]), 30)


func test_rows_carry_their_seeds_with_file_and_hash() -> void:
	var rows: Array[Dictionary] = BenchScore.rows(_quick("a", [["lose_contained", 100],
		["win_merge", 400]]), _config, "now")
	var seeds: Array = rows[0]["seeds"]
	assert_eq(seeds.size(), 2)
	assert_eq(int(seeds[0]["seed"]), 1001)
	assert_eq(str(seeds[1]["sha256"]), "%064d" % 1002)
	assert_eq(str(seeds[1]["file"]), str((rows[0]["entries"] as Array)[1]))
	assert_almost_eq(float(seeds[1]["score"]), 90.0, 0.0001)
	assert_false(bool(rows[0]["complete"]), "two of three seeds")


func test_rows_order_current_complete_score_win_rate_days_model() -> void:
	var entries: Array[BenchEntry] = []
	entries.append_array(_quick("old", [["win_merge", 0], ["win_merge", 0], ["win_merge", 0]],
		"then"))
	entries.append_array(_quick("partial", [["win_merge", 0]]))
	entries.append_array(_quick("slow", [["win_merge", 1000], ["win_merge", 1000],
		["win_merge", 1000]]))
	entries.append_array(_quick("fast", [["win_merge", 200], ["win_merge", 200],
		["win_merge", 200]]))
	entries.append_array(_quick("zero_b", [["lose_contained", 5], ["lose_contained", 5],
		["lose_contained", 5]]))
	entries.append_array(_quick("zero_a", [["lose_contained", 5], ["lose_contained", 5],
		["lose_contained", 5]]))
	var order: Array[String] = []
	for row: Dictionary in BenchScore.rows(entries, _config, "now"):
		order.append(str(row["model"]))
	assert_eq(order, ["fast", "slow", "zero_a", "zero_b", "partial", "old"] as Array[String])


func test_a_group_without_wins_has_no_mean_win_day() -> void:
	var rows: Array[Dictionary] = BenchScore.rows(_quick("none", [["lose_contained", 5]]),
		_config, "now")
	assert_eq(int(rows[0]["mean_win_days"]), BenchScore.NO_WINS)
	assert_eq(int(rows[0]["wins"]), 0)


func _write_run(entry: BenchEntry) -> PackedByteArray:
	DirAccess.make_dir_recursive_absolute(BOARD.path_join(Writer.RUNS_DIR))
	var file: FileAccess = FileAccess.open(BOARD.path_join(Writer.RUNS_DIR)
		.path_join(entry.file_name()), FileAccess.WRITE)
	file.store_string(entry.to_json())
	file.close()
	return entry.to_json().to_utf8_buffer()


func test_the_writer_counts_only_verified_runs_given_records() -> void:
	var bytes: Array[PackedByteArray] = []
	for entry: BenchEntry in _quick("a", [["win_merge", 400], ["lose_contained", 100]]):
		bytes.append(_write_run(entry))
	var names: PackedStringArray = DirAccess.get_files_at(BOARD.path_join(Writer.RUNS_DIR))
	var records: Dictionary = {
		names[0]: {"sha256": Writer.sha256_hex(bytes[0]), "verified": true},
		names[1]: {"sha256": Writer.sha256_hex(bytes[1]), "verified": false},
	}
	var result: Dictionary = Writer.rebuild(BOARD, _config, "now", records, true)
	var rows: Array = result["rows"]
	assert_eq(rows.size(), 1)
	assert_eq(int((rows[0] as Dictionary)["runs"]), 1)
	records[names[0]] = {"sha256": "stale", "verified": true}
	result = Writer.rebuild(BOARD, _config, "now", records, true)
	assert_eq((result["rows"] as Array).size(), 0, "a record of other bytes is not current")
	result = Writer.rebuild(BOARD, _config, "now")
	assert_eq(int(((result["rows"] as Array)[0] as Dictionary)["runs"]), 2, "no map counts all")


func test_the_writer_leaves_the_files_alone_when_nothing_changed() -> void:
	for entry: BenchEntry in _quick("a", [["win_merge", 400]]):
		_write_run(entry)
	var first: Dictionary = Writer.rebuild(BOARD, _config, "now")
	assert_true(bool(first["changed"]))
	var json_before: String = FileAccess.get_file_as_string(BOARD.path_join(Writer.LEADERBOARD_JSON))
	# A board from another day: only `generated` differs, so nothing is rewritten.
	var board: Dictionary = JSON.parse_string(json_before)
	board["generated"] = "1999-01-01"
	var file: FileAccess = FileAccess.open(BOARD.path_join(Writer.LEADERBOARD_JSON),
		FileAccess.WRITE)
	file.store_string(JSON.stringify(board, "\t", false))
	file.close()
	var marked: String = FileAccess.get_file_as_string(BOARD.path_join(Writer.LEADERBOARD_JSON))
	var second: Dictionary = Writer.rebuild(BOARD, _config, "now")
	assert_false(bool(second["changed"]))
	assert_eq(FileAccess.get_file_as_string(BOARD.path_join(Writer.LEADERBOARD_JSON)), marked)
	var third: Dictionary = Writer.rebuild(BOARD, _config, "later")
	assert_true(bool(third["changed"]), "other content is a change")


func test_the_page_names_its_generator_first_and_ranks_only_the_standard_suite() -> void:
	var entries: Array[BenchEntry] = _quick("quick_one", [["win_merge", 400]])
	entries.append(_entry("standard_one", 1001, "win_merge", 400, "standard"))
	var text: String = Writer.markdown(BenchScore.rows(entries, _config, "now"), _config,
		Writer.GENERATOR_LOCAL)
	assert_true(text.begins_with("<!-- Generated by tools/bench/bench_run.gd --rebuild"))
	assert_string_contains(text, "| 1 | standard_one |")
	assert_string_contains(text, "| — | quick_one |")
	assert_true(text.find("## Standard suite") < text.find("## Quick suite"))


func test_a_row_lists_its_model_versions_only_when_a_run_has_one() -> void:
	var plain: Array[BenchEntry] = _quick("vendor/model", [["win_merge", 400]])
	assert_false(BenchScore.rows(plain, _config, "now")[0].has("model_versions"))
	var jev: Array[BenchEntry] = _quick("typesafe/jev-latest", [["win_merge", 400],
		["lose_contained", 300], ["win_merge", 500]])
	jev[0].model_version = "jev-1.13.0"
	jev[1].model_version = "jev-1.12.0"
	jev[2].model_version = "jev-1.13.0"
	var row: Dictionary = BenchScore.rows(jev, _config, "now")[0]
	assert_eq(row["model_versions"], ["jev-1.12.0", "jev-1.13.0"] as Array[String])
	var keys: Array = row.keys()
	assert_eq(keys.find("model_versions"), keys.find("backend") + 1)


func test_the_page_shows_the_versions_and_a_choice_rows_params() -> void:
	var params: Dictionary = BenchChoice.params_of(_config)
	var entry: BenchEntry = _entry("typesafe/jev-latest", 1001, "win_merge", 400, "standard",
		"now", params)
	entry.model_version = "jev-1.13.0"
	var text: String = Writer.markdown(BenchScore.rows([entry] as Array[BenchEntry], _config,
		"now"), _config, Writer.GENERATOR_LOCAL)
	assert_string_contains(text,
		"| 1 | typesafe/jev-latest (jev-1.13.0) | — | choice v1, picks 3/2/2/2 |")


func test_a_chat_row_says_its_effort_and_a_bot_or_choice_row_has_no_such_key() -> void:
	var high: Dictionary = {"temperature": 0.0, "effort": "high", "reasoning": "high"}
	var entry: BenchEntry = _entry("vendor/model", 1001, "win_merge", 400, "standard", "now", high)
	entry.effort = "high"
	var row: Dictionary = BenchScore.rows([entry] as Array[BenchEntry], _config, "now")[0]
	assert_eq(row["effort"], "high")
	var plain: Dictionary = BenchScore.rows(_quick("vendor/model", [["win_merge", 400]]), _config,
		"now")[0]
	assert_eq(plain["effort"], "normal")
	var bot: BenchEntry = _entry("bot:greedy", 1001, "win_merge", 400, "standard", "now", {})
	bot.backend = BenchEntry.BACKEND_BOT
	assert_false(BenchScore.rows([bot] as Array[BenchEntry], _config, "now")[0].has("effort"))
	var jev: BenchEntry = _entry("typesafe/jev-latest", 1001, "win_merge", 400, "standard", "now",
		BenchChoice.params_of(_config))
	assert_false(BenchScore.rows([jev] as Array[BenchEntry], _config, "now")[0].has("effort"))
	var text: String = Writer.markdown(BenchScore.rows([entry, bot] as Array[BenchEntry], _config,
		"now"), _config, Writer.GENERATOR_LOCAL)
	assert_string_contains(text, "| Rank | Model | Effort | Params |")
	assert_string_contains(text, "| vendor/model | High | temperature 0, reasoning high |")
	assert_string_contains(text, "| bot:greedy | — | — |")


func test_a_reasoning_run_is_never_shown_as_the_level_it_shares_a_word_with() -> void:
	# --reasoning=high: the default limit, no `effort` key — not an --effort=high run.
	var raw: Dictionary = {"temperature": 0.0, "reasoning": "high"}
	var entry: BenchEntry = _entry("vendor/model", 1001, "win_merge", 400, "standard", "now", raw)
	var row: Dictionary = BenchScore.rows([entry] as Array[BenchEntry], _config, "now")[0]
	assert_eq(row["effort"], "reasoning-high")
	var text: String = Writer.markdown([row] as Array[Dictionary], _config,
		Writer.GENERATOR_LOCAL)
	assert_string_contains(text, "| vendor/model | reasoning high | temperature 0, reasoning high |")
	var board: Dictionary = {"effort": "reasoning-high"}
	assert_true(BenchEffort.label_is_safe(str(board["effort"])), "the global list keeps it")
