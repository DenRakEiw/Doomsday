extends GutTest
## S6.12h — `submission_check.gd` (docs/specs/benchmark.md §20.4, §20.9):
## pure judging of a submitted group — accepted, held for an unknown model,
## `approved` skips the model rule, `group` for mixed models and missing seeds,
## `backend` for `bot:` and `mock*`, replay failure rejecting the whole group
## with that file's reason, `file_name`, and `reason` never holding the entry's
## model string.

const Check := preload("res://tools/bench/submission_check.gd")
const Verifier := preload("res://tools/bench/bench_verifier.gd")

const MAX_DAYS: int = 300
const MODEL: String = "vendor/checked-model"
## No slug, id or number can contain this marker.
const MARKER: String = "Secret!Model/ZQX"

var _config: BenchConfig = null
var _db: ContentDB = null
var _suite_dicts: Array[Dictionary] = []


func before_all() -> void:
	_db = ContentLoader.load_root("res://data").db
	_config = BenchConfig.load_file()
	_config.max_days = MAX_DAYS
	for seed_value: int in _config.suite_seeds(BenchConfig.SUITE_QUICK):
		var entry: BenchEntry = Fixtures.bench_mock_entry(_db, _config, seed_value, MODEL)
		var d: Dictionary = JSON.parse_string(entry.to_json())
		d["backend"] = BenchJob.BACKEND_OPENROUTER
		d["suite"] = BenchConfig.SUITE_QUICK
		_suite_dicts.append(d)


func before_each() -> void:
	_config.max_days = MAX_DAYS


func _files_from(dicts: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d: Dictionary in dicts:
		var name: String = BenchEntry.file_name_for(str(d["model"]), str(d["params_id"]),
			int(d["prompt_version"]), str(d["suite"]), int(d["seed"]))
		out.append({
			"name": name,
			"body": JSON.stringify(d, "\t", false) + "\n",
		})
	return out


func _clone_suite() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d: Dictionary in _suite_dicts:
		out.append(d.duplicate(true))
	return out


func test_valid_listed_group_is_accepted() -> void:
	var files: Array[Dictionary] = _files_from(_clone_suite())
	var res: Dictionary = Check.judge_files(files, Check.ROW_NEW, {MODEL: true}, _config, _db)
	assert_eq(res["status"], Check.STATUS_ACCEPTED, str(res["reason"]))
	assert_eq(res["reason"], "")
	assert_eq((res["files"] as Array).size(), 3)


func test_unknown_model_is_held_when_new_and_accepted_when_approved() -> void:
	var files: Array[Dictionary] = _files_from(_clone_suite())
	var held: Dictionary = Check.judge_files(files, Check.ROW_NEW, {}, _config, _db)
	assert_eq(held["status"], Check.STATUS_HELD)
	assert_eq(held["reason_id"], Check.REASON_MODEL)

	var approved: Dictionary = Check.judge_files(files, Check.ROW_APPROVED, {}, _config, _db)
	assert_eq(approved["status"], Check.STATUS_ACCEPTED)


func test_mixed_models_or_missing_seed_rejected_as_group() -> void:
	var mixed: Array[Dictionary] = _clone_suite()
	mixed[1]["model"] = "vendor/other-model"
	var res_mixed: Dictionary = Check.judge_files(_files_from(mixed), Check.ROW_NEW,
		{MODEL: true, "vendor/other-model": true}, _config, _db)
	assert_eq(res_mixed["status"], Check.STATUS_REJECTED)
	assert_eq(res_mixed["reason_id"], Check.REASON_GROUP)

	var short_files: Array[Dictionary] = _files_from(_clone_suite())
	short_files.pop_back()
	var res_short: Dictionary = Check.judge_files(short_files, Check.ROW_NEW,
		{MODEL: true}, _config, _db)
	assert_eq(res_short["status"], Check.STATUS_REJECTED)
	assert_eq(res_short["reason_id"], Check.REASON_GROUP)


func test_bot_and_mock_backends_rejected_as_backend() -> void:
	var mock_suite: Array[Dictionary] = _clone_suite()
	mock_suite[0]["backend"] = "mock:cheapest"
	var res_mock: Dictionary = Check.judge_files(_files_from(mock_suite), Check.ROW_NEW,
		{MODEL: true}, _config, _db)
	assert_eq(res_mock["status"], Check.STATUS_REJECTED)
	assert_eq(res_mock["reason_id"], Check.REASON_BACKEND)

	var bot_suite: Array[Dictionary] = _clone_suite()
	for d: Dictionary in bot_suite:
		d["model"] = "bot:greedy"
		d["backend"] = BenchEntry.BACKEND_BOT
	var res_bot: Dictionary = Check.judge_files(_files_from(bot_suite), Check.ROW_NEW,
		{"bot:greedy": true}, _config, _db)
	assert_eq(res_bot["status"], Check.STATUS_REJECTED)
	assert_eq(res_bot["reason_id"], Check.REASON_BACKEND)


func test_wrong_file_name_rejected_as_file_name() -> void:
	var files: Array[Dictionary] = _files_from(_clone_suite())
	files[0]["name"] = "wrong_name__00000000__p1__quick__s1001.json"
	var res: Dictionary = Check.judge_files(files, Check.ROW_NEW, {MODEL: true}, _config, _db)
	assert_eq(res["status"], Check.STATUS_REJECTED)
	assert_eq(res["reason_id"], Check.REASON_FILE_NAME)


func test_one_bad_replay_rejects_whole_group_and_reason_never_holds_model_string() -> void:
	var tampered: Array[Dictionary] = _clone_suite()
	for d: Dictionary in tampered:
		d["model"] = MARKER
	tampered[2]["hash"] = "0".repeat(64)
	var res: Dictionary = Check.judge_files(_files_from(tampered), Check.ROW_NEW,
		{MARKER: true}, _config, _db)
	assert_eq(res["status"], Check.STATUS_REJECTED)
	assert_eq(res["reason_id"], Verifier.REASON_HASH)
	assert_false(str(res["reason"]).contains(MARKER), str(res["reason"]))
