extends GutTest
## S6.13 — `GlobalBoardClient` (docs/specs/benchmark.md §16.6) without a
## network: the response handlers are fed made-up results, and a board or run
## "downloaded" comes from a file through the debug stand-in. The rules: what is
## shown when, what is cached, what a run's download must match.

const ROOT: String = "user://test_global_board_client"
const OLD: String = "2026-09-01T00:00:00"
const NEW: String = "2026-09-20T00:00:00"
const NEWER: String = "2026-10-01T00:00:00"
const CANARY: String = "res://tests/fixtures/bench/determinism_entry.json"
const RUN_FILE: String = "runs/mock__321ae4fb__p1__standard__s1001.json"
const MS_PER_SECOND: int = 1000

var _client: GlobalBoardClient = null
var _emitted: Array[Array] = []
var _runs: Array[Array] = []


func before_each() -> void:
	Fixtures.remove_root(ROOT)
	DirAccess.make_dir_recursive_absolute(ROOT)
	GlobalBoardClient.forget_fetch()
	_client = GlobalBoardClient.new()
	_client.config = BenchConfig.load_file()
	_client.cache_dir = ROOT.path_join("cache")
	_client.shipped_path = ROOT.path_join("shipped.json")
	_client.clock_override_ms = 0
	add_child_autofree(_client)
	_emitted.clear()
	_runs.clear()
	_client.board_changed.connect(func(board: GlobalBoard, source: String, loading: bool) -> void:
		_emitted.append([board, source, loading]))
	_client.run_ready.connect(func(entry: BenchEntry, reason: String) -> void:
		_runs.append([entry, reason]))


func after_each() -> void:
	GlobalBoardClient.forget_fetch()
	Fixtures.remove_root(ROOT)


func _board_text(generated: String, models: Array[String] = []) -> String:
	var rows: Array[Dictionary] = []
	for model: String in models:
		rows.append({"model": model, "suite": "standard", "content_hash": "c", "complete": true,
			"runs": 1, "of": 1, "wins": 0, "score": 0.0})
	return JSON.stringify({"version": 1, "generated": generated, "content_hash": "c",
		"rows": rows})


func _write(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func _last() -> Array:
	return _emitted[_emitted.size() - 1]


func _run(bytes: PackedByteArray) -> GlobalBoardRun:
	var run: GlobalBoardRun = GlobalBoardRun.new()
	run.seed_value = 1001
	run.file = RUN_FILE
	run.sha256 = GlobalBoardClient.sha256_hex(bytes)
	return run


## The debug stand-in: a board file whose runs sit next to it.
func _serve(board_text: String) -> void:
	var path: String = ROOT.path_join("served/leaderboard.json")
	_write(path, board_text.to_utf8_buffer())
	_client.local_board_path = path


# ------------------------------------------------------------------- board


func test_a_good_answer_is_shown_online_and_cached() -> void:
	_write(_client.shipped_path, _board_text(OLD).to_utf8_buffer())
	_client.handle_board_response(HTTPRequest.RESULT_SUCCESS, 200,
		_board_text(NEW, ["vendor/a"]).to_utf8_buffer())
	var last: Array = _last()
	assert_eq(last[1], GlobalBoardClient.SOURCE_ONLINE)
	assert_false(last[2])
	assert_eq((last[0] as GlobalBoard).rows.size(), 1)
	var cached: String = FileAccess.get_file_as_string(_client.cache_dir.path_join("leaderboard.json"))
	assert_eq(cached, _board_text(NEW, ["vendor/a"]))


func test_a_bad_answer_keeps_the_local_board() -> void:
	_write(_client.shipped_path, _board_text(OLD).to_utf8_buffer())
	_client.open_board(false)
	for answer: Array in [[HTTPRequest.RESULT_SUCCESS, 200, "not a board"],
			[HTTPRequest.RESULT_SUCCESS, 404, _board_text(NEW)],
			[HTTPRequest.RESULT_TIMEOUT, 0, ""],
			[HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED, 0, ""]]:
		_client.handle_board_response(int(answer[0]), int(answer[1]),
			str(answer[2]).to_utf8_buffer())
		var last: Array = _last()
		assert_eq(last[1], GlobalBoardClient.SOURCE_SHIPPED, "%s" % [answer])
		assert_false(last[2], "no longer loading")
		assert_eq((last[0] as GlobalBoard).generated, OLD)
	assert_false(FileAccess.file_exists(_client.cache_dir.path_join("leaderboard.json")),
		"nothing bad is cached")


func test_the_cache_is_not_overwritten_by_an_older_board() -> void:
	var cache: String = _client.cache_dir.path_join("leaderboard.json")
	_write(cache, _board_text(NEWER).to_utf8_buffer())
	_client.handle_board_response(HTTPRequest.RESULT_SUCCESS, 200, _board_text(NEW).to_utf8_buffer())
	assert_eq(FileAccess.get_file_as_string(cache), _board_text(NEWER))


func test_the_newer_of_cache_and_shipped_copy_is_the_local_board() -> void:
	_write(_client.shipped_path, _board_text(NEW).to_utf8_buffer())
	_write(_client.cache_dir.path_join("leaderboard.json"), _board_text(OLD).to_utf8_buffer())
	_client.open_board(false)
	assert_eq(_last()[1], GlobalBoardClient.SOURCE_SHIPPED)
	_write(_client.cache_dir.path_join("leaderboard.json"), _board_text(NEWER).to_utf8_buffer())
	_client.open_board(false)
	assert_eq(_last()[1], GlobalBoardClient.SOURCE_CACHE)


func test_nothing_usable_on_disk_is_no_board() -> void:
	_client.open_board(false)
	assert_null(_last()[0])
	assert_eq(_last()[1], GlobalBoardClient.SOURCE_NONE)


func test_the_network_off_makes_no_request() -> void:
	_write(_client.shipped_path, _board_text(OLD).to_utf8_buffer())
	_client.open_board(false)
	assert_eq(_client.requests_made, 0)
	assert_eq(_emitted.size(), 1)
	assert_false(_last()[2], "nothing follows")


func test_a_fetch_follows_the_local_board_and_replaces_it() -> void:
	_write(_client.shipped_path, _board_text(OLD).to_utf8_buffer())
	_serve(_board_text(NEW, ["vendor/a"]))
	_client.open_board(true)
	assert_eq(_client.requests_made, 1)
	assert_eq(_emitted[0][1], GlobalBoardClient.SOURCE_SHIPPED)
	assert_true(_emitted[0][2], "loading while the fetch runs")
	assert_eq(_last()[1], GlobalBoardClient.SOURCE_ONLINE)
	assert_eq((_last()[0] as GlobalBoard).generated, NEW)


func test_reopening_within_the_window_reuses_the_fetch() -> void:
	_serve(_board_text(NEW, ["vendor/a"]))
	_client.open_board(true)
	assert_eq(_client.requests_made, 1)
	_client.clock_override_ms = (_client.config.global_min_refetch_s - 1) * MS_PER_SECOND
	_client.open_board(true)
	assert_eq(_client.requests_made, 1, "within the window: no second request")
	assert_eq(_last()[1], GlobalBoardClient.SOURCE_ONLINE)
	_client.clock_override_ms = (_client.config.global_min_refetch_s + 1) * MS_PER_SECOND
	_client.open_board(true)
	assert_eq(_client.requests_made, 2, "past it: fetched again")


func test_a_failed_fetch_opens_no_window() -> void:
	_client.local_board_path = ROOT.path_join("missing.json")
	_client.open_board(true)
	_client.open_board(true)
	assert_eq(_client.requests_made, 2)


# -------------------------------------------------------------------- runs


func test_a_cached_run_with_the_right_hash_needs_no_request() -> void:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(CANARY)
	var run: GlobalBoardRun = _run(bytes)
	_write(_client.cache_dir.path_join("runs").path_join(RUN_FILE.get_file()), bytes)
	_client.download_run(run, false)
	assert_eq(_client.requests_made, 0)
	assert_eq(_runs.size(), 1)
	assert_not_null(_runs[0][0])
	assert_eq(_runs[0][1], "")


func test_a_downloaded_run_is_checked_read_and_cached() -> void:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(CANARY)
	_serve(_board_text(NEW))
	_write(ROOT.path_join("served").path_join(RUN_FILE), bytes)
	_client.download_run(_run(bytes), true)
	assert_eq(_client.requests_made, 1)
	assert_eq(_runs[0][1], "")
	assert_eq((_runs[0][0] as BenchEntry).seed_value, 1001)
	assert_true(FileAccess.file_exists(_client.cache_dir.path_join("runs").path_join(
		RUN_FILE.get_file())), "cached for the next time")


func test_a_body_with_another_hash_is_changed() -> void:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(CANARY)
	var run: GlobalBoardRun = _run(bytes)
	_serve(_board_text(NEW))
	_write(ROOT.path_join("served").path_join(RUN_FILE), bytes.slice(0, bytes.size() - 2))
	_client.download_run(run, true)
	assert_null(_runs[0][0])
	assert_eq(_runs[0][1], GlobalBoardClient.FAIL_CHANGED)


func test_a_broken_body_with_its_hash_is_unreadable() -> void:
	var bytes: PackedByteArray = "{ not an entry".to_utf8_buffer()
	_serve(_board_text(NEW))
	_write(ROOT.path_join("served").path_join(RUN_FILE), bytes)
	_client.download_run(_run(bytes), true)
	assert_eq(_runs[0][1], GlobalBoardClient.FAIL_UNREADABLE)


func test_no_answer_is_offline() -> void:
	var run: GlobalBoardRun = _run("x".to_utf8_buffer())
	_serve(_board_text(NEW))
	_client.download_run(run, true)
	assert_eq(_runs[0][1], GlobalBoardClient.FAIL_OFFLINE)


func test_an_answer_for_a_run_not_asked_for_is_ignored() -> void:
	# After `cancel`, or for another run: nothing is emitted.
	_client.handle_run_response(_run("x".to_utf8_buffer()), HTTPRequest.RESULT_SUCCESS, 200,
		FileAccess.get_file_as_bytes(CANARY))
	assert_eq(_runs.size(), 0)


func test_network_off_and_not_cached_is_off() -> void:
	_client.download_run(_run("x".to_utf8_buffer()), false)
	assert_eq(_client.requests_made, 0)
	assert_eq(_runs[0][1], GlobalBoardClient.FAIL_OFF)


func test_the_cache_keeps_at_most_cache_runs_max() -> void:
	_client.config.global_cache_runs_max = 2
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(CANARY)
	_serve(_board_text(NEW))
	for seed_value: int in [1001, 1002, 1003]:
		var run: GlobalBoardRun = _run(bytes)
		run.file = "runs/mock__s%d.json" % seed_value
		_write(ROOT.path_join("served").path_join(run.file), bytes)
		_client.download_run(run, true)
	assert_eq(DirAccess.get_files_at(_client.cache_dir.path_join("runs")).size(), 2)
