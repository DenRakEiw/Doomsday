extends GutTest
## S6.12b — the replay verifier's judging (docs/specs/benchmark.md §16.4) on the
## real content: a `mock:cheapest` entry of 300 days, made here under a config of
## 300 days, is verified; each way of breaking it is rejected with its own
## reason. A rejection is data, never an error: the suite fails on any
## `push_error` or engine error (`.gutconfig.json`), so none of these may raise one.

const Verifier := preload("res://tools/bench/bench_verifier.gd")
const VerifyRecord := preload("res://tools/bench/verify_record.gd")
const Writer := preload("res://tools/bench/leaderboard_writer.gd")
const MAX_DAYS: int = 300
const SEED: int = 1001
const COMMIT: String = "0123456789abcdef0123456789abcdef01234567"
const CHECKED: String = "2026-09-26"
## A day of the 300 on which the cut-short entry stops.
const CUT_DAY: int = 100

var _config: BenchConfig = null
var _db: ContentDB = null
var _entry: Dictionary = {}


func before_all() -> void:
	_db = ContentLoader.load_root("res://data").db
	_config = BenchConfig.load_file()
	_config.max_days = MAX_DAYS
	_entry = JSON.parse_string(Fixtures.bench_mock_entry(_db, _config, SEED).to_json())


func before_each() -> void:
	_config.max_days = MAX_DAYS


func _context() -> Dictionary:
	return {Verifier.CONTEXT_COMMIT: COMMIT, Verifier.CONTEXT_VERSION: "0.6.0",
		Verifier.CONTEXT_CHECKED: CHECKED}


func _name(d: Dictionary) -> String:
	return BenchEntry.file_name_for(str(d["model"]), str(d["params_id"]),
		int(d["prompt_version"]), str(d["suite"]), int(d["seed"]))


func _bytes(d: Dictionary) -> PackedByteArray:
	return (JSON.stringify(d, "\t", false) + "\n").to_utf8_buffer()


## The entry judged under its own §10.2 name.
func _judge(d: Dictionary) -> VerifyRecord:
	return Verifier.check(_bytes(d), _name(d), _config, _db, _context())


func _copy() -> Dictionary:
	return _entry.duplicate(true)


func test_the_clean_entry_is_verified() -> void:
	var bytes: PackedByteArray = _bytes(_entry)
	var record: VerifyRecord = Verifier.check(bytes, _name(_entry), _config, _db, _context())
	assert_true(record.verified, record.detail)
	assert_eq(record.reason, "")
	assert_eq(record.file, "runs/" + _name(_entry))
	assert_eq(record.sha256, Writer.sha256_hex(bytes))
	assert_eq(record.state_hash, str(_entry["hash"]))
	assert_eq(record.outcome, str(_entry["outcome"]))
	assert_eq(record.days, int(_entry["days"]))
	assert_eq(record.end_day, int(_entry["end_day"]))
	assert_almost_eq(record.score, float(_entry["score"]), 0.05)
	assert_eq(record.content_hash, _db.content_hash)
	assert_eq(record.game_commit, COMMIT)
	assert_eq(record.checked, CHECKED)


func test_a_changed_hash_is_rejected_as_hash() -> void:
	var d: Dictionary = _copy()
	d["hash"] = "0".repeat(64)
	assert_eq(_judge(d).reason, Verifier.REASON_HASH)


func test_a_score_one_higher_is_rejected_as_score() -> void:
	var d: Dictionary = _copy()
	d["score"] = float(d["score"]) + 1.0
	assert_eq(_judge(d).reason, Verifier.REASON_SCORE)


func test_another_outcome_is_rejected_as_outcome() -> void:
	var d: Dictionary = _copy()
	d["outcome"] = "win_merge" if str(d["outcome"]) != "win_merge" else "lose_contained"
	assert_eq(_judge(d).reason, Verifier.REASON_OUTCOME)


func test_changed_days_are_rejected_as_days() -> void:
	var d: Dictionary = _copy()
	d["days"] = int(d["days"]) - 1
	assert_eq(_judge(d).reason, Verifier.REASON_DAYS)


func test_a_command_moved_to_a_day_it_is_refused_is_rejected_as_refused() -> void:
	var d: Dictionary = _copy()
	var commands: Array = d["commands"]
	# The first anomaly collected, moved to the first day — before it existed.
	for i: int in commands.size():
		if str((commands[i] as Dictionary)["type"]) == CollectAnomalyCommand.TYPE_ID:
			var moved: Dictionary = commands[i]
			commands.remove_at(i)
			moved["day"] = 0
			commands.insert(1, moved)
			break
	var record: VerifyRecord = _judge(d)
	assert_eq(record.reason, Verifier.REASON_REFUSED)
	assert_string_contains(record.detail, "day 0")
	assert_string_contains(record.detail, CollectAnomalyCommand.TYPE_ID)


func test_a_command_after_the_end_day_breaks_the_rules() -> void:
	var d: Dictionary = _copy()
	(d["commands"] as Array).append({"type": "choose_origin", "day": int(d["end_day"]) + 1,
		"region": "usa"})
	assert_eq(_judge(d).reason, Verifier.REASON_RULES)


func test_more_commands_on_one_day_than_a_day_allows_break_the_rules() -> void:
	var d: Dictionary = _copy()
	var commands: Array = d["commands"]
	for i: int in Policy.MAX_COMMANDS_PER_DAY + 1:
		commands.append({"type": "choose_origin", "day": int(d["end_day"]), "region": "usa"})
	var record: VerifyRecord = _judge(d)
	assert_eq(record.reason, Verifier.REASON_RULES)
	assert_string_contains(record.detail, str(Policy.MAX_COMMANDS_PER_DAY))


func test_another_difficulty_breaks_the_rules() -> void:
	var d: Dictionary = _copy()
	(d["setup"] as Dictionary)["difficulty"] = "hard"
	assert_eq(_judge(d).reason, Verifier.REASON_RULES)


func test_a_seed_outside_the_suite_breaks_the_rules() -> void:
	var d: Dictionary = _copy()
	d["seed"] = 999
	assert_eq(_judge(d).reason, Verifier.REASON_RULES)


func test_a_params_id_that_is_not_the_params_hash_breaks_the_rules() -> void:
	var d: Dictionary = _copy()
	d["params_id"] = "00000000"
	assert_eq(_judge(d).reason, Verifier.REASON_RULES)


func test_a_bot_name_without_the_bot_backend_breaks_the_rules() -> void:
	var d: Dictionary = _copy()
	d["model"] = BenchEntry.MODEL_BOT_PREFIX + "greedy"
	assert_eq(_judge(d).reason, Verifier.REASON_RULES)


func test_other_content_is_rejected_as_content() -> void:
	var d: Dictionary = _copy()
	d["content_hash"] = "1".repeat(64)
	assert_eq(_judge(d).reason, Verifier.REASON_CONTENT)


func test_a_wrong_file_name_is_rejected_as_file_name() -> void:
	var record: VerifyRecord = Verifier.check(_bytes(_entry),
		"mock__00000000__p1__standard__s1001.json", _config, _db, _context())
	assert_eq(record.reason, Verifier.REASON_FILE_NAME)


func test_bytes_that_are_not_json_are_unreadable() -> void:
	var record: VerifyRecord = Verifier.check("not a run".to_utf8_buffer(), _name(_entry),
		_config, _db, _context())
	assert_eq(record.reason, Verifier.REASON_UNREADABLE)


func test_bytes_that_are_not_utf8_are_unreadable_without_an_engine_error() -> void:
	var bytes: PackedByteArray = _bytes(_entry)
	bytes[10] = 0xFF
	var record: VerifyRecord = Verifier.check(bytes, _name(_entry), _config, _db, _context())
	assert_eq(record.reason, Verifier.REASON_UNREADABLE)
	assert_engine_error_count(0)


func test_a_file_above_the_limit_is_unreadable() -> void:
	var limit: int = _config.global_max_run_bytes
	_config.global_max_run_bytes = 100
	var record: VerifyRecord = _judge(_entry)
	_config.global_max_run_bytes = limit
	assert_eq(record.reason, Verifier.REASON_UNREADABLE)
	assert_eq(record.days, VerifyRecord.NO_DAYS, "judged unread")


func test_an_entry_cut_short_is_unfinished() -> void:
	var d: Dictionary = _copy()
	var kept: Array = []
	for command: Variant in d["commands"]:
		if int((command as Dictionary)["day"]) <= CUT_DAY:
			kept.append(command)
	d["commands"] = kept
	d["days"] = int(d["days"]) - (int(d["end_day"]) - CUT_DAY)
	d["end_day"] = CUT_DAY
	d["outcome"] = BenchEntry.OUTCOME_TIMEOUT
	d["variant"] = ""
	d["score"] = 0.0
	assert_eq(_judge(d).reason, Verifier.REASON_UNFINISHED)


func test_the_canary_is_judged_under_its_own_name_with_its_own_max_days() -> void:
	_config.max_days = BenchConfig.load_file().max_days
	var record: VerifyRecord = Verifier.check_canary(_bytes(_entry), _config, _db, _context())
	assert_true(record.verified, record.detail)
	assert_eq(_config.max_days, BenchConfig.load_file().max_days, "the config is left as it was")


func test_an_effort_that_is_not_the_one_in_params_breaks_the_rules() -> void:
	var d: Dictionary = _copy()
	d["effort"] = "ultra"
	assert_eq(_judge(d).reason, Verifier.REASON_RULES, "an effort claimed without its params")
	var params: Dictionary = d["params"]
	params["effort"] = "ultra"
	params["reasoning"] = "xhigh"
	params["max_completion_tokens"] = 32000
	d["params_id"] = BenchEntry.params_id_of(params)
	var record: VerifyRecord = _judge(d)
	assert_true(record.verified, "effort and params agree: " + record.detail)
	d.erase("effort")
	assert_eq(Verifier.rules_broken(BenchEntry.from_dict(d), _config),
		"the effort is not the one in params")


func test_an_effort_whose_params_are_not_what_it_sends_breaks_the_rules() -> void:
	# A run published as Ultra that thought like a normal one: no reasoning, a low
	# one, or the normal limit.
	for change: Dictionary in [{"reasoning": ""}, {"reasoning": "low"},
			{"max_completion_tokens": 1200}]:
		var d: Dictionary = _copy()
		d["effort"] = "ultra"
		var params: Dictionary = d["params"]
		params["effort"] = "ultra"
		params["reasoning"] = "max"
		params["max_completion_tokens"] = 32000
		params.merge(change, true)
		d["params_id"] = BenchEntry.params_id_of(params)
		var record: VerifyRecord = _judge(d)
		assert_eq(record.reason, Verifier.REASON_RULES, str(change))
		assert_string_contains(record.detail, "effort ultra", str(change))
