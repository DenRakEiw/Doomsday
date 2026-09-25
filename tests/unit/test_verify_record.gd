extends GutTest
## S6.12b — a run's verification record (docs/specs/benchmark.md §16.3): it reads
## back as it was written, a record that does not read is null, and its `detail`
## never carries the run's own words — the model name above all — whatever the
## reason (§16.4). The judged runs are a real mock entry of 300 days.

const VerifyRecord := preload("res://tools/bench/verify_record.gd")
const Verifier := preload("res://tools/bench/bench_verifier.gd")
const MAX_DAYS: int = 300
const SEED: int = 1001
## No slug, no id and no number can contain it.
const MARKER: String = "Marker!Model/ZQX"

var _config: BenchConfig = null
var _db: ContentDB = null
var _entry: Dictionary = {}


func before_all() -> void:
	_db = ContentLoader.load_root("res://data").db
	_config = BenchConfig.load_file()
	_config.max_days = MAX_DAYS
	var entry: BenchEntry = Fixtures.bench_mock_entry(_db, _config, SEED, MARKER)
	_entry = JSON.parse_string(entry.to_json())


func _record() -> VerifyRecord:
	var record: VerifyRecord = VerifyRecord.new()
	record.file = "runs/mock__321ae4fb__p1__standard__s1001.json"
	record.sha256 = "ab".repeat(32)
	record.verified = false
	record.reason = Verifier.REASON_HASH
	record.detail = "the replay's state hash is not the entry's"
	record.game_commit = "0123456789abcdef0123456789abcdef01234567"
	record.game_version = "0.6.0"
	record.content_hash = "cd".repeat(32)
	record.state_hash = "ef".repeat(32)
	record.outcome = "win_merge"
	record.days = 612
	record.end_day = 640
	record.score = 84.7
	record.checked = "2026-09-26"
	return record


func _judge(d: Dictionary, file_name: String = "") -> VerifyRecord:
	if file_name.is_empty():
		file_name = BenchEntry.file_name_for(str(d["model"]), str(d["params_id"]),
			int(d["prompt_version"]), str(d["suite"]), int(d["seed"]))
	return Verifier.check(JSON.stringify(d, "\t", false).to_utf8_buffer(), file_name, _config,
		_db, {Verifier.CONTEXT_COMMIT: "0".repeat(40)})


func test_a_record_reads_back_as_it_was_written() -> void:
	var record: VerifyRecord = _record()
	var back: VerifyRecord = VerifyRecord.from_json(record.to_json()) as VerifyRecord
	assert_not_null(back)
	assert_eq(back.to_dict(), record.to_dict())
	assert_eq(JSON.stringify(record.to_dict().keys()), JSON.stringify(VerifyRecord.KEYS),
		"§16.3's keys in its order")


func test_a_missing_or_ill_typed_key_reads_as_null() -> void:
	var good: Dictionary = JSON.parse_string(_record().to_json())
	for key: String in VerifyRecord.KEYS:
		var missing: Dictionary = good.duplicate(true)
		missing.erase(key)
		assert_null(VerifyRecord.from_dict(missing), "without %s" % key)
		var wrong: Dictionary = good.duplicate(true)
		wrong[key] = []
		assert_null(VerifyRecord.from_dict(wrong), "%s of the wrong type" % key)


func test_another_version_or_a_verdict_against_its_reason_reads_as_null() -> void:
	var good: Dictionary = JSON.parse_string(_record().to_json())
	var later: Dictionary = good.duplicate(true)
	later["version"] = 2
	assert_null(VerifyRecord.from_dict(later))
	var contradicts: Dictionary = good.duplicate(true)
	contradicts["verified"] = true
	assert_null(VerifyRecord.from_dict(contradicts), "verified with a reason")
	assert_null(VerifyRecord.from_json("not json"))


func test_the_detail_never_holds_the_model_name_whatever_the_reason() -> void:
	var cases: Dictionary[String, Dictionary] = {}
	var d: Dictionary = _entry.duplicate(true)
	d["hash"] = "0".repeat(64)
	cases[Verifier.REASON_HASH] = d
	d = _entry.duplicate(true)
	d["score"] = float(d["score"]) + 1.0
	cases[Verifier.REASON_SCORE] = d
	d = _entry.duplicate(true)
	d["outcome"] = "win_merge"
	cases[Verifier.REASON_OUTCOME] = d
	d = _entry.duplicate(true)
	d["days"] = int(d["days"]) + 1
	cases[Verifier.REASON_DAYS] = d
	d = _entry.duplicate(true)
	d["content_hash"] = MARKER
	cases[Verifier.REASON_CONTENT] = d
	d = _entry.duplicate(true)
	d["locale"] = MARKER
	cases[Verifier.REASON_RULES] = d
	d = _entry.duplicate(true)
	(d["commands"] as Array).insert(1, {"type": "collect_anomaly", "day": 0, "anomaly": 1})
	cases[Verifier.REASON_REFUSED] = d
	d = _entry.duplicate(true)
	d["decisions"] = MARKER
	cases[Verifier.REASON_UNREADABLE] = d
	for reason: String in cases:
		var record: VerifyRecord = _judge(cases[reason])
		assert_eq(record.reason, reason)
		assert_false(record.detail.contains(MARKER), reason + ": " + record.detail)
		assert_false(record.to_json().contains(MARKER), reason + ": nowhere in the record")
	var misnamed: VerifyRecord = _judge(_entry, "mock__00000000__p1__standard__s1001.json")
	assert_eq(misnamed.reason, Verifier.REASON_FILE_NAME)
	assert_false(misnamed.to_json().contains(MARKER))
