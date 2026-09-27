extends GutTest
## S6.12d — the effort levels (docs/specs/benchmark.md §18): what a level sends,
## that it is a row of its own, that normal changes nothing, and what a list shows.

const Tool := preload("res://tools/bench/bench_run.gd")
const FIXTURE: String = "res://tests/fixtures/bench/determinism_entry.json"

var _config: BenchConfig = null
var _locale: String = ""


func before_each() -> void:
	_config = BenchConfig.load_file()
	_locale = TranslationServer.get_locale()


func after_each() -> void:
	TranslationServer.set_locale(_locale)


func _normal_params() -> Dictionary:
	return Tool.build_params({}, _config)["params"]


func _efforts(values: Array) -> Array[String]:
	var out: Array[String] = []
	out.assign(values)
	return out


func test_the_config_names_what_high_and_ultra_send() -> void:
	assert_eq(_config.effort_reasoning["high"], ["high"])
	assert_eq(_config.effort_reasoning["ultra"], ["max", "xhigh", "high"])
	assert_eq(_config.effort_max_tokens["high"], 16000)
	assert_eq(_config.effort_max_tokens["ultra"], 32000)
	assert_eq(_config.effort_output_tokens["ultra"], 8000)
	assert_eq(_config.effort_timeout_s["ultra"], 900)


func test_ultra_sends_the_highest_effort_the_model_lists() -> void:
	assert_eq(BenchEffort.reasoning_for("ultra", _config,
		_efforts(["max", "xhigh", "high", "medium"])), "max")
	assert_eq(BenchEffort.reasoning_for("ultra", _config, _efforts(["xhigh", "high"])), "xhigh")
	assert_eq(BenchEffort.reasoning_for("ultra", _config, _efforts(["high", "low"])), "high")


func test_an_unknown_list_sends_the_first_and_normal_sends_nothing() -> void:
	assert_eq(BenchEffort.reasoning_for("ultra", _config, _efforts([])), "max")
	assert_eq(BenchEffort.reasoning_for("high", _config, _efforts(["low", "medium"])), "high")
	assert_eq(BenchEffort.reasoning_for("normal", _config, _efforts(["high"])), "")


func test_normal_leaves_the_params_as_they_were_before_the_levels() -> void:
	var params: Dictionary = _normal_params()
	assert_eq(BenchEffort.apply(params, "normal", _config, _efforts(["high"])), params)
	var canary: BenchEntry = BenchEntry.from_json(FileAccess.get_file_as_string(FIXTURE))
	assert_eq(BenchEntry.params_id_of(params), canary.params_id,
		"a normal run is the same row, file and cache key as before")


func test_high_and_ultra_add_the_effort_the_reasoning_and_a_larger_limit() -> void:
	var high: Dictionary = BenchEffort.apply(_normal_params(), "high", _config, _efforts([]))
	assert_eq(high["effort"], "high")
	assert_eq(high["reasoning"], "high")
	assert_eq(high["max_completion_tokens"], 16000)
	var ultra: Dictionary = BenchEffort.apply(_normal_params(), "ultra", _config,
		_efforts(["xhigh", "high"]))
	assert_eq(ultra["reasoning"], "xhigh")
	assert_eq(ultra["max_completion_tokens"], 32000)


func test_a_larger_max_tokens_given_by_hand_stays() -> void:
	var params: Dictionary = Tool.build_params({"max-tokens": "50000"}, _config)["params"]
	assert_eq(BenchEffort.apply(params, "high", _config, _efforts([]))["max_completion_tokens"],
		50000)


func test_each_level_is_a_row_of_its_own() -> void:
	var ids: Array[String] = []
	for level: String in BenchEffort.LEVELS:
		ids.append(BenchEntry.params_id_of(BenchEffort.apply(_normal_params(), level, _config,
			_efforts([]))))
	assert_ne(ids[0], ids[1])
	assert_ne(ids[1], ids[2])
	assert_ne(ids[0], ids[2])


func test_the_effort_argument_is_read_and_checked() -> void:
	assert_eq(Tool.build_params({}, _config)["effort"], "normal")
	assert_eq(Tool.build_params({"effort": "ultra"}, _config)["effort"], "ultra")
	assert_string_contains(str(Tool.build_params({"effort": "max"}, _config)["error"]),
		"--effort")
	assert_string_contains(str(Tool.build_params({"effort": "high", "reasoning": "low"},
		_config)["error"]), "--reasoning")
	assert_eq(str(Tool.build_params({"effort": "normal", "reasoning": "low"},
		_config)["error"]), "", "--reasoning alone stays the low-level form")


func test_a_model_the_list_says_cannot_reason_is_refused_above_normal() -> void:
	var info: Dictionary = {"listed": true, "reasoning": false, "efforts": [] as Array[String]}
	var refused: Dictionary = Tool.effort_params(_normal_params(), "high", "v/m", info, _config)
	assert_string_contains(str(refused["error"]), "takes no reasoning parameter")
	var normal: Dictionary = Tool.effort_params(_normal_params(), "normal", "v/m", info, _config)
	assert_eq(str(normal["error"]), "")
	var unknown: Dictionary = Tool.effort_params(_normal_params(), "ultra", "v/m", {}, _config)
	assert_eq(str(unknown["error"]), "", "unknown is not a refusal")
	assert_string_contains(str(unknown["line"]), "reasoning max")


func test_what_a_run_shows() -> void:
	var params: Dictionary = _normal_params()
	assert_eq(BenchEffort.of_run("openrouter", "v/m", params, ""), "normal")
	assert_eq(BenchEffort.of_run("openrouter", "v/m", params, "ultra"), "ultra")
	params["reasoning"] = "low"
	assert_eq(BenchEffort.of_run("openrouter", "v/m", params, ""), "low",
		"a --reasoning run shows its raw value")
	assert_eq(BenchEffort.of_run("bot", "bot:greedy", {}, ""), "")
	assert_eq(BenchEffort.of_run("typesafe", "typesafe/jev-latest",
		BenchChoice.params_of(_config), ""), "")


func test_the_labels_in_both_languages() -> void:
	TranslationServer.set_locale("en")
	assert_eq(BenchEffort.label("high"), "High")
	assert_eq(BenchEffort.line("ultra"), "Effort: Ultra")
	assert_eq(BenchEffort.label(""), "—")
	assert_eq(BenchEffort.label("low"), "low")
	assert_eq(BenchEffort.label("<b>x</b>"), "—", "anything odd is the dash")
	TranslationServer.set_locale("de")
	assert_eq(BenchEffort.label("normal"), "Normal")
	assert_eq(BenchEffort.label("high"), "Hoch")
	assert_eq(BenchEffort.line("ultra"), "Aufwand: Ultra")
