extends GutTest
## S6.12h — `collect_submissions.gd` (docs/specs/benchmark.md §20.4, §20.9):
## tested against a fake transport — nothing without the secret; Supabase
## unreachable -> exit 0 and an empty file; the model list unreachable -> `new`
## left waiting while `approved` is judged; accepted files land in `<board>/runs/`
## byte-exact; `--confirm` marks each group and carries on past a failed mark.

const Collector := preload("res://tools/bench/collect_submissions.gd")
const Writer := preload("res://tools/bench/leaderboard_writer.gd")

const MAX_DAYS: int = 300
const ROOT: String = "user://test_collect_submissions/"
const MODEL: String = "fixture/thinker"
const UNKNOWN_MODEL: String = "vendor/unlisted-model"
const FIXTURE_MODELS: String = "res://tests/fixtures/bench/openrouter_models.json"

var _config: BenchConfig = null
var _db: ContentDB = null
var _board: String = ""
var _out: String = ""
var _files_listed: Array[Dictionary] = []
var _files_unlisted: Array[Dictionary] = []


func before_all() -> void:
	_db = ContentLoader.load_root("res://data").db
	_config = BenchConfig.load_file()
	_config.max_days = MAX_DAYS
	_files_listed = _make_files(MODEL)
	_files_unlisted = _make_files(UNKNOWN_MODEL)


func before_each() -> void:
	_config.max_days = MAX_DAYS
	Fixtures.remove_root(ROOT)
	_board = ROOT.path_join("board")
	_out = ROOT.path_join("collected.json")
	DirAccess.make_dir_recursive_absolute(_board.path_join(Writer.RUNS_DIR))


func after_each() -> void:
	Fixtures.remove_root(ROOT)


static func _make_files(model: String) -> Array[Dictionary]:
	var db: ContentDB = ContentLoader.load_root("res://data").db
	var cfg: BenchConfig = BenchConfig.load_file()
	cfg.max_days = MAX_DAYS
	var out: Array[Dictionary] = []
	for seed_value: int in cfg.suite_seeds(BenchConfig.SUITE_QUICK):
		var entry: BenchEntry = Fixtures.bench_mock_entry(db, cfg, seed_value, model)
		var d: Dictionary = JSON.parse_string(entry.to_json())
		d["backend"] = BenchJob.BACKEND_OPENROUTER
		d["suite"] = BenchConfig.SUITE_QUICK
		var name: String = BenchEntry.file_name_for(model, str(d["params_id"]),
			int(d["prompt_version"]), BenchConfig.SUITE_QUICK, seed_value)
		out.append({
			"name": name,
			"body": JSON.stringify(d, "\t", false) + "\n",
		})
	return out


func _env() -> Dictionary:
	return {
		Collector.ENV_URL: "https://example.supabase.co",
		Collector.ENV_KEY: "sb_secret_test",
	}


func _read_out() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(_out))


func test_no_secret_exits_zero_and_writes_empty_file() -> void:
	var calls: int = 0
	var code: int = Collector.run({"board": _board, "out": _out}, _config,
		{Collector.ENV_URL: "", Collector.ENV_KEY: ""},
		func(_m: int, _u: String, _h: PackedStringArray, _b: String) -> Dictionary:
			calls += 1
			return {"status": 200, "body": "[]"})
	assert_eq(code, Collector.EXIT_OK)
	assert_eq(calls, 0)
	assert_eq((_read_out()["groups"] as Array).size(), 0)


func test_supabase_unreachable_exits_zero_and_writes_empty_file() -> void:
	var code: int = Collector.run({"board": _board, "out": _out}, _config, _env(),
		func(_m: int, _u: String, _h: PackedStringArray, _b: String) -> Dictionary:
			return {"status": 503, "body": ""})
	assert_eq(code, Collector.EXIT_OK)
	assert_eq((_read_out()["groups"] as Array).size(), 0)


func test_model_list_unreachable_leaves_new_waiting_and_judges_approved() -> void:
	var rows: Array[Dictionary] = [
		{"id": 10, "status": "new", "files": _files_listed},
		{"id": 11, "status": "approved", "files": _files_unlisted},
	]
	var code: int = Collector.run({"board": _board, "out": _out}, _config, _env(),
		func(_m: int, url: String, _h: PackedStringArray, _b: String) -> Dictionary:
			if url.ends_with(Collector.RPC_TAKE):
				return {"status": 200, "body": JSON.stringify(rows)}
			return {"status": 0, "body": ""})
	assert_eq(code, Collector.EXIT_OK)
	var groups: Array = _read_out()["groups"]
	assert_eq(groups.size(), 1, "new left waiting, approved judged")
	assert_eq(int((groups[0] as Dictionary)["id"]), 11)
	assert_eq(str((groups[0] as Dictionary)["status"]), "accepted")


func test_accepted_files_land_in_board_byte_exact_and_confirm_marks_all() -> void:
	var rows: Array[Dictionary] = [
		{"id": 21, "status": "new", "files": _files_listed},
		{"id": 22, "status": "new", "files": _files_unlisted},
	]
	var models_body: String = FileAccess.get_file_as_string(FIXTURE_MODELS)
	var code: int = Collector.run({"board": _board, "out": _out}, _config, _env(),
		func(_m: int, url: String, _h: PackedStringArray, _b: String) -> Dictionary:
			if url.ends_with(Collector.RPC_TAKE):
				return {"status": 200, "body": JSON.stringify(rows)}
			return {"status": 200, "body": models_body})
	assert_eq(code, Collector.EXIT_OK)
	for f: Dictionary in _files_listed:
		var written: String = _board.path_join(Writer.RUNS_DIR).path_join(str(f["name"]))
		assert_true(FileAccess.file_exists(written), written)
		assert_eq(FileAccess.get_file_as_string(written), str(f["body"]))
	var groups: Array = _read_out()["groups"]
	assert_eq(groups.size(), 2)
	assert_eq(str((groups[0] as Dictionary)["status"]), "accepted")
	assert_eq(str((groups[1] as Dictionary)["status"]), "held")

	# Confirm marks each group and carries on past a failed mark.
	var marked: Array[int] = []
	var confirm_code: int = Collector.run({"confirm": _out}, _config, _env(),
		func(_m: int, _url: String, _h: PackedStringArray, body: String) -> Dictionary:
			var d: Dictionary = JSON.parse_string(body)
			var id: int = int(d["p_id"])
			marked.append(id)
			return {"status": 500 if id == 21 else 204, "body": ""})
	assert_eq(confirm_code, Collector.EXIT_OK)
	assert_eq(marked, [21, 22] as Array[int])
