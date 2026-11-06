extends GutTest
## S6.12h — `BenchSubmitLog` (docs/specs/benchmark.md §20.5, §20.7, §20.9):
## write/read round-trip, unreadable file treated as empty without crashing, and
## the four group-line states (`listed`, `not_listed`, `sent`, `submit`) plus
## reset when a re-run changes a file's hash.

const CANARY: String = "res://tests/fixtures/bench/determinism_entry.json"
const ROOT: String = "user://test_bench_submit_log_unit/"
const MODEL: String = "vendor/log-model"

var _config: BenchConfig = null


func before_each() -> void:
	_config = BenchConfig.load_file()
	Fixtures.remove_root(ROOT)
	DirAccess.make_dir_recursive_absolute(ROOT)


func after_each() -> void:
	Fixtures.remove_root(ROOT)


func _make_group(extra_score: float = 0.0) -> BenchGroup:
	var group: BenchGroup = BenchGroup.new()
	group.model = MODEL
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CANARY))
	for seed_value: int in _config.suite_seeds(BenchConfig.SUITE_QUICK):
		var d: Dictionary = base.duplicate(true)
		d["model"] = MODEL
		d["backend"] = BenchJob.BACKEND_OPENROUTER
		d["suite"] = BenchConfig.SUITE_QUICK
		d["seed"] = seed_value
		if extra_score != 0.0 and seed_value == 1001:
			d["score"] = float(d["score"]) + extra_score
		var text: String = JSON.stringify(d, "\t", false) + "\n"
		var name: String = BenchEntry.file_name_for(MODEL, str(d["params_id"]),
			int(d["prompt_version"]), BenchConfig.SUITE_QUICK, seed_value)
		var path: String = ROOT.path_join(name)
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(text)
		file.close()
		group.entries.append(BenchEntry.from_json(text))
		group.paths.append(path)
	return group


func _board(generated: String, seed_shas: PackedStringArray = PackedStringArray()) -> GlobalBoard:
	var seeds: Array[Dictionary] = []
	for i: int in seed_shas.size():
		seeds.append({
			"seed": 1001 + i,
			"file": "runs/f%d.json" % i,
			"sha256": seed_shas[i],
			"outcome": "win_merge",
			"days": 400,
			"score": 80.0,
		})
	var doc: Dictionary = {
		"version": 1,
		"generated": generated,
		"content_hash": Game.content().content_hash,
		"rows": [] if seeds.is_empty() else [{
			"model": MODEL,
			"params_id": "00000000",
			"suite": BenchConfig.SUITE_QUICK,
			"content_hash": Game.content().content_hash,
			"complete": true,
			"runs": seeds.size(),
			"of": 3,
			"wins": seeds.size(),
			"score": 80.0,
			"seeds": seeds,
		}],
	}
	return GlobalBoard.parse(JSON.stringify(doc), _config)


func test_write_and_read_round_trip_and_unreadable_file_is_empty() -> void:
	var log_dir: String = ROOT.path_join("log")
	var group: BenchGroup = _make_group()
	var sub: BenchSubmission = BenchSubmission.from_group(group, _config)
	var store: BenchSubmitLog = BenchSubmitLog.load_log(log_dir)
	assert_eq(store.sent.size(), 0)
	assert_true(store.record(sub, 42, "2026-09-28"))
	var again: BenchSubmitLog = BenchSubmitLog.load_log(log_dir)
	assert_eq(again.sent.size(), 1)
	assert_eq(str(again.sent[0]["group_sha"]), sub.group_sha)
	assert_eq(int(again.sent[0]["id"]), 42)
	assert_eq(str(again.sent[0]["date"]), "2026-09-28")

	# Corrupt the file: load_log returns empty without crashing and rewrites on next record.
	var broken: FileAccess = FileAccess.open(log_dir.path_join(BenchSubmitLog.FILE_NAME),
		FileAccess.WRITE)
	broken.store_string("{not json")
	broken.close()
	var recovered: BenchSubmitLog = BenchSubmitLog.load_log(log_dir)
	assert_eq(recovered.sent.size(), 0)
	assert_true(recovered.record(sub, 43, "2026-09-29"))
	assert_eq(BenchSubmitLog.load_log(log_dir).sent.size(), 1)


func test_four_group_line_states_and_rerun_hash_change() -> void:
	var log_dir: String = ROOT.path_join("log")
	var group: BenchGroup = _make_group()
	var sub: BenchSubmission = BenchSubmission.from_group(group, _config)
	var store: BenchSubmitLog = BenchSubmitLog.load_log(log_dir)

	# 1. Before sending: submit
	assert_eq(store.group_status(group, null, _config)["state"], BenchSubmitLog.STATE_SUBMIT)

	# 2. Sent on 2026-09-28, board is 2026-09-29 (1 day later < 2 days): sent
	store.record(sub, 7, "2026-09-28")
	var sent_status: Dictionary = store.group_status(group,
		_board("2026-09-29T03:23:00Z"), _config)
	assert_eq(sent_status["state"], BenchSubmitLog.STATE_SENT)
	assert_eq(sent_status["date"], "2026-09-28")

	# 3. Board is 2026-09-30 (2 days later >= not_listed_days) and hashes not on board: not_listed
	var not_listed: Dictionary = store.group_status(group,
		_board("2026-09-30T03:23:00Z"), _config)
	assert_eq(not_listed["state"], BenchSubmitLog.STATE_NOT_LISTED)
	assert_eq(not_listed["date"], "2026-09-28")

	# 4. Every file hash is on the board: listed
	var listed: Dictionary = store.group_status(group,
		_board("2026-09-30T03:23:00Z", sub.file_sha), _config)
	assert_eq(listed["state"], BenchSubmitLog.STATE_LISTED)

	# 5. Re-run overwrites a file (changing its hash): back to submit
	var rerun: BenchGroup = _make_group(1.0)
	assert_eq(store.group_status(rerun, _board("2026-09-29T03:23:00Z"), _config)["state"],
		BenchSubmitLog.STATE_SUBMIT)
