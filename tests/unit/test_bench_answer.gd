extends GutTest
## S6.12 — the answer parser (docs/specs/benchmark.md §7.2), table-driven over
## `tests/fixtures/bench/answers.json`: raw answers and what they read as.

const FIXTURE: String = "res://tests/fixtures/bench/answers.json"
const MAX_ACTIONS: int = 12


func _cases() -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	assert_eq(typeof(parsed), TYPE_DICTIONARY, "the fixture reads")
	return (parsed as Dictionary)["cases"]


func _compact(answer: BenchAnswer) -> Array[String]:
	var out: Array[String] = []
	for action: BenchAction in answer.actions:
		out.append(action.compact())
	return out


func _dropped(answer: BenchAnswer) -> Array:
	var out: Array = []
	for row: Dictionary in answer.dropped:
		out.append([int(row["index"]), str(row["reason"])])
	return out


func test_every_fixture_answer_reads_as_expected() -> void:
	var cases: Array = _cases()
	assert_gt(cases.size(), 20, "the table covers the rules")
	for entry: Variant in cases:
		var case: Dictionary = entry
		var name: String = str(case["name"])
		var answer: BenchAnswer = BenchAnswer.parse(str(case["text"]), MAX_ACTIONS)
		assert_eq(answer.valid, bool(case["valid"]), name + ": valid")
		assert_eq(answer.error, str(case["error"]), name + ": error")
		assert_eq(answer.stance, str(case["stance"]), name + ": stance")
		var expected_actions: Array[String] = []
		for action: Variant in case["actions"]:
			expected_actions.append(str(action))
		assert_eq(_compact(answer), expected_actions, name + ": actions")
		var expected_dropped: Array = []
		for row: Variant in case["dropped"]:
			expected_dropped.append([int((row as Array)[0]), str((row as Array)[1])])
		assert_eq(_dropped(answer), expected_dropped, name + ": dropped")


func test_thirteen_actions_read_twelve_and_drop_one_over_the_limit() -> void:
	var actions: Array[Dictionary] = []
	for i: int in 13:
		actions.append({"do": "wake", "region": "r%d" % i})
	var answer: BenchAnswer = BenchAnswer.parse(JSON.stringify({"actions": actions}), MAX_ACTIONS)
	assert_eq(answer.actions.size(), MAX_ACTIONS)
	assert_eq(answer.dropped, [{"index": 12, "reason": BenchAnswer.ACTION_OVER_LIMIT}] as Array[Dictionary])


func test_every_fixture_answer_survives_the_cache_round_trip() -> void:
	for entry: Variant in _cases():
		var case: Dictionary = entry
		var answer: BenchAnswer = BenchAnswer.parse(str(case["text"]), MAX_ACTIONS)
		# Through JSON, as the cache stores it: whole numbers come back as floats.
		var stored: Variant = JSON.parse_string(JSON.stringify(answer.to_cache()))
		var restored: BenchAnswer = BenchAnswer.from_cache(stored)
		assert_not_null(restored, str(case["name"]))
		if restored != null:
			assert_true(answer.equals(restored), str(case["name"]))
			assert_eq(restored.valid, answer.valid, str(case["name"]))


func test_the_cache_form_never_holds_the_text() -> void:
	var answer: BenchAnswer = BenchAnswer.parse(
		"Because I like it: {\"stance\": \"wait\", \"actions\": []}", MAX_ACTIONS)
	var stored: String = JSON.stringify(answer.to_cache())
	assert_false(stored.contains("Because"))


func test_a_bad_cache_dictionary_reads_as_null() -> void:
	assert_null(BenchAnswer.from_cache({}))
	assert_null(BenchAnswer.from_cache({"stance": "wait", "actions": [{"do": "nuke"}], "dropped": []}))
	assert_null(BenchAnswer.from_cache({"stance": "conquer", "actions": [], "dropped": []}))
	assert_null(BenchAnswer.from_cache({"invalid": ""}))
	assert_null(BenchAnswer.from_cache({"stance": "wait", "actions": [], "dropped": [{"index": "a"}]}))
