extends GutTest
## S6.13 — `GlobalBoard.parse` and `newer` (docs/specs/benchmark.md §16.6): the
## public leaderboard is data from outside, so every rule drops what breaks it
## and nothing crashes.

const FIXTURE: String = "res://tests/fixtures/bench/global_board.json"

var _config: BenchConfig = null
var _text: String = ""


func before_all() -> void:
	_config = BenchConfig.load_file()
	_text = FileAccess.get_file_as_string(FIXTURE)


func before_each() -> void:
	_config.global_max_rows = BenchConfig.load_file().global_max_rows


func _board(d: Dictionary) -> GlobalBoard:
	return GlobalBoard.parse(JSON.stringify(d), _config)


func _fixture() -> Dictionary:
	return Fixtures.read_json(FIXTURE)


func test_the_fixture_parses_its_rows_seeds_and_the_standard_filter() -> void:
	var board: GlobalBoard = GlobalBoard.parse(_text, _config)
	assert_true(board.is_usable(), board.last_error)
	assert_eq(board.generated, "2026-09-26T04:12:00")
	assert_eq(board.date(), "2026-09-26")
	assert_eq(board.content_hash, "fixture-content")
	var models: Array[String] = []
	for row: GlobalBoardRow in board.rows:
		models.append(row.model)
	assert_eq(models, ["vendor/model-a", "bot:greedy", "vendor/old-content"] as Array[String],
		"the quick row is skipped, the broken ones dropped, the order kept")
	var first: GlobalBoardRow = board.rows[0]
	assert_eq(first.params_id, "321ae4fb")
	assert_false(first.complete)
	assert_eq([first.runs, first.of, first.wins], [2, 10, 1])
	assert_almost_eq(first.score, 62.4, 0.001)
	assert_eq(first.seeds.size(), 2, "four seeds break a rule")
	assert_eq(first.seeds[1].seed_value, 1002)
	assert_eq(first.seeds[1].outcome, "lose_contained")
	assert_eq(first.seeds[1].days, 300)
	assert_true(board.rows[1].is_bot())
	assert_false(first.is_bot())
	assert_eq(board.dropped, 7, "four seeds and three rows")


func test_a_missing_or_ill_typed_key_drops_the_row() -> void:
	for key: String in ["model", "runs", "of", "wins", "score", "complete", "content_hash",
			"suite"]:
		var d: Dictionary = _fixture()
		var row: Dictionary = d["rows"][1]
		row.erase(key)
		var board: GlobalBoard = _board(d)
		assert_eq(board.rows.size(), 2, "%s missing" % key)
		d = _fixture()
		d["rows"][1][key] = {"not": "right"}
		assert_eq(_board(d).rows.size(), 2, "%s ill-typed" % key)


func test_a_bad_model_name_is_dropped() -> void:
	for model: String in ["", "has space", "x".repeat(201), "tab\there", "ümlaut"]:
		var d: Dictionary = _fixture()
		d["rows"][1]["model"] = model
		var board: GlobalBoard = _board(d)
		assert_eq(board.rows.size(), 2, "%s is refused" % model)
	assert_true(GlobalBoard.is_model_name("x".repeat(200)))


func test_a_bad_run_path_or_hash_is_dropped() -> void:
	var board: GlobalBoard = GlobalBoard.parse(_text, _config)
	for run: GlobalBoardRun in board.rows[0].seeds:
		assert_true(run.file.begins_with("runs/"))
		assert_false(run.file.substr(5).contains("/"), "no folder under runs/")
		assert_eq(run.sha256.length(), 64)


func test_text_that_is_not_a_board_is_unusable() -> void:
	for text: String in ["not json", "[1, 2]", "", "{\"version\": 2, \"generated\": \"\", " \
			+ "\"content_hash\": \"\", \"rows\": []}", "{\"version\": 1, \"rows\": []}",
			"{\"version\": 1, \"generated\": \"x\", \"content_hash\": \"\", \"rows\": {}}"]:
		var board: GlobalBoard = GlobalBoard.parse(text, _config)
		assert_false(board.is_usable(), "%s is unusable" % text)
		assert_ne(board.last_error, "")
		assert_eq(board.rows.size(), 0)
		assert_eq(board.generated, "")


func test_rows_past_max_rows_are_not_read() -> void:
	_config.global_max_rows = 1
	var board: GlobalBoard = GlobalBoard.parse(_text, _config)
	assert_eq(board.rows.size(), 1)
	assert_eq(board.rows[0].model, "vendor/model-a")
	assert_eq(board.dropped, 4, "only the first row's seeds were read")


func test_the_public_file_as_it_is_today_is_usable_and_empty() -> void:
	var board: GlobalBoard = GlobalBoard.parse(
		"{\"version\": 1, \"generated\": \"\", \"content_hash\": \"\", \"rows\": []}", _config)
	assert_true(board.is_usable())
	assert_eq(board.rows.size(), 0)


func test_newer_picks_by_generated_and_ignores_an_unusable_board() -> void:
	var older: GlobalBoard = _board({"version": 1, "generated": "2026-09-01T00:00:00",
		"content_hash": "", "rows": []})
	var later: GlobalBoard = _board({"version": 1, "generated": "2026-09-20T00:00:00",
		"content_hash": "", "rows": []})
	var broken: GlobalBoard = GlobalBoard.parse("nope", _config)
	assert_eq(GlobalBoard.newer(older, later), later)
	assert_eq(GlobalBoard.newer(later, older), later)
	assert_eq(GlobalBoard.newer(broken, older), older)
	assert_eq(GlobalBoard.newer(older, broken), older)
	assert_eq(GlobalBoard.newer(older, null), older)
	assert_null(GlobalBoard.newer(broken, null))
	assert_null(GlobalBoard.newer(null, null))


func test_an_effort_is_read_and_anything_odd_is_left_empty() -> void:
	var d: Dictionary = _fixture()
	d["rows"][0]["effort"] = "ultra"
	d["rows"][1]["effort"] = "<b>loud</b>"
	var board: GlobalBoard = _board(d)
	assert_eq(board.rows[0].effort, "ultra")
	assert_eq(board.rows[1].effort, "", "shown as the dash, the row kept")
	assert_eq(_board(_fixture()).rows[0].effort, "", "a board from before the levels")
