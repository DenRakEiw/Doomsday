extends GutTest
## S6.12 — one run's file (docs/specs/benchmark.md §10.2): the round trip, the
## name, and that a broken file is null with a reason, never a crash.


func _entry() -> BenchEntry:
	var entry: BenchEntry = BenchEntry.new()
	entry.model = "vendor/Model-Name:free"
	entry.backend = "openrouter"
	entry.params = {"temperature": 0.0, "max_completion_tokens": 1200, "json_mode": true,
		"reasoning": "", "top_p": -1.0}
	entry.params_id = BenchEntry.params_id_of(entry.params)
	entry.locale = "en"
	entry.suite = "standard"
	entry.game_version = "0.6.0"
	entry.content_hash = "abc"
	entry.seed_value = 1001
	entry.setup = RunSetup.create("language_model")
	entry.max_days = 2000
	entry.interval_days = 10
	entry.recorded = "2026-09-25T23:10:04"
	entry.outcome = "win_ascendance"
	entry.variant = "win_ascendance"
	entry.days = 612
	entry.end_day = 612
	entry.score = 84.7
	entry.state_hash = "f00d"
	entry.calls = 78
	entry.invalid_answers = 1
	entry.rejected_actions = 3
	entry.tokens_in = 912345
	entry.tokens_out = 20411
	entry.cost_usd = 1.23
	var origin: ChooseOriginCommand = ChooseOriginCommand.new("usa")
	origin.day = 0
	var answer: ChooseEventOptionCommand = ChooseEventOptionCommand.new(17, "sandbag")
	answer.day = 40
	entry.commands = [origin, answer]
	var decision: BenchDecision = BenchDecision.new()
	decision.stance = "spread"
	decision.actions = 2
	decision.done = 1
	decision.refused = [{"action": "buy x", "reason": "unknown_node"}]
	entry.decisions = [decision]
	return entry


## The dictionary as a file holds it: through JSON.
func _as_file(entry: BenchEntry) -> Dictionary:
	return JSON.parse_string(entry.to_json())


func test_to_dict_and_back_is_equal() -> void:
	var entry: BenchEntry = _entry()
	var read: BenchEntry = BenchEntry.from_dict(_as_file(entry))
	assert_not_null(read, BenchEntry.last_error)
	# Both through JSON, where a whole number is a float on either side.
	assert_eq(JSON.stringify(JSON.parse_string(JSON.stringify(read.to_dict())), "", true),
		JSON.stringify(_as_file(entry), "", true))
	assert_eq(read.to_json(), entry.to_json().replace("\"max_completion_tokens\": 1200",
		"\"max_completion_tokens\": 1200.0"))


func test_the_params_id_reads_the_same_from_the_file() -> void:
	var entry: BenchEntry = _entry()
	var read: BenchEntry = BenchEntry.from_dict(_as_file(entry))
	assert_eq(BenchEntry.params_id_of(read.params), entry.params_id)
	assert_eq(entry.params_id.length(), 8)


func test_the_keys_are_exactly_the_specs() -> void:
	assert_eq(_entry().to_dict().keys(), ["version", "model", "backend", "params", "params_id",
		"prompt_version", "parser_version", "locale", "suite", "game_version", "content_hash", "seed",
		"setup", "max_days", "interval_days", "recorded", "outcome", "variant", "days", "end_day",
		"score", "hash", "calls", "cached_calls", "invalid_answers", "rejected_actions", "tokens_in",
		"tokens_out", "cost_usd", "budget_exhausted", "commands", "decisions"])


func test_each_missing_or_ill_typed_key_is_null_with_a_reason() -> void:
	var good: Dictionary = _as_file(_entry())
	for key: Variant in good.keys():
		var missing: Dictionary = good.duplicate(true)
		missing.erase(key)
		assert_null(BenchEntry.from_dict(missing), "without %s" % key)
		assert_string_contains(BenchEntry.last_error, str(key))
		var wrong: Dictionary = good.duplicate(true)
		wrong[key] = Vector2.ZERO if typeof(good[key]) == TYPE_DICTIONARY else {"x": 1}
		assert_null(BenchEntry.from_dict(wrong), "%s of the wrong type" % key)


func test_an_unknown_version_a_bad_setup_and_an_unknown_command_are_null() -> void:
	var good: Dictionary = _as_file(_entry())
	var version: Dictionary = good.duplicate(true)
	version["version"] = 2
	assert_null(BenchEntry.from_dict(version))
	var setup: Dictionary = good.duplicate(true)
	setup["setup"] = {"architecture": 3}
	assert_null(BenchEntry.from_dict(setup))
	var command: Dictionary = good.duplicate(true)
	(command["commands"] as Array).append({"type": "launch_everything", "day": 3})
	assert_null(BenchEntry.from_dict(command))
	assert_string_contains(BenchEntry.last_error, "commands[2]")
	var decision: Dictionary = good.duplicate(true)
	(decision["decisions"] as Array).append({"day": 1})
	assert_null(BenchEntry.from_dict(decision))
	assert_null(BenchEntry.from_json("not json"))
	assert_null(BenchEntry.from_json("[1, 2]"))


func test_a_bot_entry_reads() -> void:
	var entry: BenchEntry = _entry()
	entry.model = "bot:greedy"
	entry.backend = BenchEntry.BACKEND_BOT
	entry.params = {}
	entry.params_id = BenchEntry.params_id_of({})
	entry.decisions = []
	entry.calls = 0
	entry.tokens_in = 0
	entry.tokens_out = 0
	entry.cost_usd = 0.0
	var read: BenchEntry = BenchEntry.from_dict(_as_file(entry))
	assert_not_null(read, BenchEntry.last_error)
	assert_true(read.is_bot())
	assert_eq(read.decisions.size(), 0)


func test_the_file_name_follows_the_spec() -> void:
	var entry: BenchEntry = _entry()
	assert_eq(BenchEntry.slug("vendor/Model-Name:free"), "vendor--model-name-free")
	assert_eq(BenchEntry.slug("bot:greedy"), "bot-greedy")
	assert_eq(entry.file_name(), "vendor--model-name-free__%s__p1__standard__s1001.json"
		% entry.params_id)


func test_the_score_is_written_to_one_decimal() -> void:
	var entry: BenchEntry = _entry()
	entry.score = 84.66666
	assert_almost_eq(float(entry.to_dict()["score"]), 84.7, 0.00001)


func test_utf8_is_told_from_broken_bytes() -> void:
	assert_true(BenchEntry.is_utf8("plain, ä, €, 𝄞".to_utf8_buffer()))
	assert_false(BenchEntry.is_utf8(PackedByteArray([0xC0, 0xAF])), "overlong")
	assert_false(BenchEntry.is_utf8(PackedByteArray([0xED, 0xA0, 0x80])), "surrogate")
	assert_false(BenchEntry.is_utf8(PackedByteArray([0xE2, 0x82])), "cut short")
	assert_false(BenchEntry.is_utf8(PackedByteArray([0x41, 0x00])), "NUL")


func test_bytes_read_as_an_entry_and_broken_bytes_as_null() -> void:
	var entry: BenchEntry = BenchEntry.from_bytes(_entry().to_json().to_utf8_buffer())
	assert_not_null(entry, BenchEntry.last_error)
	assert_null(BenchEntry.from_bytes(PackedByteArray([0x7B, 0xFF, 0x7D])))
	assert_eq(BenchEntry.last_error, "not UTF-8 text")
	assert_engine_error_count(0)


func test_a_model_version_round_trips_after_the_backend() -> void:
	var entry: BenchEntry = _entry()
	entry.model = "typesafe/jev-latest"
	entry.backend = "typesafe"
	entry.model_version = "jev-1.13.0"
	var read: BenchEntry = BenchEntry.from_dict(_as_file(entry))
	assert_not_null(read, BenchEntry.last_error)
	assert_eq(read.model_version, "jev-1.13.0")
	var keys: Array = entry.to_dict().keys()
	assert_eq(keys.find("model_version"), keys.find("backend") + 1)


func test_an_entry_without_a_model_version_reads_empty_and_writes_no_such_key() -> void:
	var entry: BenchEntry = _entry()
	var read: BenchEntry = BenchEntry.from_dict(_as_file(entry))
	assert_eq(read.model_version, "")
	assert_false(entry.to_dict().has("model_version"))
	assert_false(entry.to_json().contains("model_version"))
	var ill: Dictionary = _as_file(entry)
	ill["model_version"] = 3
	assert_null(BenchEntry.from_dict(ill))
	assert_string_contains(BenchEntry.last_error, "model_version")

