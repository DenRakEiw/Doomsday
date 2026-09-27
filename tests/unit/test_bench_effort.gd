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
	assert_eq(BenchEffort.of_run("openrouter", "v/m", params, ""), "reasoning-low",
		"a --reasoning run shows its raw value, marked")
	params["reasoning"] = "high"
	assert_ne(BenchEffort.of_run("openrouter", "v/m", params, ""), "high",
		"--reasoning=high (the default limit) is not the level High")
	assert_eq(BenchEffort.of_run("bot", "bot:greedy", {}, ""), "")
	assert_eq(BenchEffort.of_run("typesafe", "typesafe/jev-latest",
		BenchChoice.params_of(_config), ""), "")


func test_the_labels_in_both_languages() -> void:
	TranslationServer.set_locale("en")
	assert_eq(BenchEffort.label("high"), "High")
	assert_eq(BenchEffort.line("ultra"), "Effort: Ultra")
	assert_eq(BenchEffort.label(""), "—")
	assert_eq(BenchEffort.label("low"), "low", "an unmarked word from an older board")
	assert_eq(BenchEffort.label("reasoning-high"), "reasoning high")
	assert_eq(BenchEffort.label("<b>x</b>"), "—", "anything odd is the dash")
	assert_eq(BenchEffort.label("reasoning-<b>"), "—")
	TranslationServer.set_locale("de")
	assert_eq(BenchEffort.label("normal"), "Normal")
	assert_eq(BenchEffort.label("high"), "Hoch")
	assert_eq(BenchEffort.label("reasoning-high"), "Reasoning high")
	assert_eq(BenchEffort.line("ultra"), "Aufwand: Ultra")


func test_a_level_never_sends_less_than_the_model_reasons_at_by_default() -> void:
	var efforts: Array[String] = _efforts(["xhigh", "high", "medium", "low"])
	assert_eq(BenchEffort.reasoning_for("high", _config, efforts, "xhigh"), "xhigh",
		"normal already reasons at xhigh, so high must not send less")
	assert_eq(BenchEffort.reasoning_for("ultra", _config, efforts, "xhigh"), "xhigh")
	assert_eq(BenchEffort.reasoning_for("high", _config, efforts, "medium"), "high")
	assert_eq(BenchEffort.reasoning_for("high", _config, efforts, ""), "high")
	assert_eq(BenchEffort.reasoning_for("high", _config, efforts, "bogus"), "high")
	assert_eq(BenchEffort.apply(_normal_params(), "high", _config, efforts, "max")["reasoning"],
		"max")


func test_a_pinned_reasoning_is_sent_whatever_the_list_says() -> void:
	var built: Dictionary = Tool.build_params({"effort": "ultra", "effort-reasoning": "high"},
		_config)
	assert_eq(str(built["error"]), "")
	assert_eq(built["pinned"], "high")
	var unknown: Dictionary = Tool.effort_params(built["params"], "ultra", "v/m", {}, _config,
		"high")
	var listed: Dictionary = Tool.effort_params(built["params"], "ultra", "v/m",
		{"listed": true, "reasoning": true, "efforts": _efforts(["max", "high"])}, _config, "high")
	assert_eq(unknown["params"]["reasoning"], "high")
	assert_eq(BenchEntry.params_id_of(unknown["params"]), BenchEntry.params_id_of(listed["params"]),
		"every shard records the same params, whether or not it could read the list")
	assert_string_contains(str(unknown["line"]), "pinned")
	for bad: Dictionary in [{"effort": "ultra", "effort-reasoning": "low"},
			{"effort-reasoning": "high"}, {"effort": "high", "effort-reasoning": "loud"}]:
		var args: Dictionary[String, String] = {}
		for key: Variant in bad:
			args[str(key)] = str(bad[key])
		assert_string_contains(str(Tool.build_params(args, _config)["error"]),
			"--effort-reasoning", str(bad))


func test_a_model_that_reasons_by_default_is_estimated_and_warned_at_normal() -> void:
	assert_eq(BenchEffort.output_tokens("normal", _config, true), _config.max_completion_tokens,
		"it reasons until its limit")
	assert_eq(BenchEffort.output_tokens("normal", _config, false), _config.output_tokens_per_call)
	assert_eq(BenchEffort.output_tokens("high", _config, true), 3000)
	var warned: Dictionary = Tool.effort_params(_normal_params(), "normal", "v/m",
		{"listed": true, "reasoning": true, "reasons_by_default": true}, _config)
	assert_string_contains(str(warned["line"]), "reasons by default")
	assert_eq(warned["params"], _normal_params(), "a warning, not a change")


func test_the_params_must_be_what_the_level_sends() -> void:
	var ultra: Dictionary = BenchEffort.apply(_normal_params(), "ultra", _config, _efforts([]))
	assert_eq(BenchEffort.params_broken(ultra, "ultra", _config), "")
	assert_eq(BenchEffort.params_broken(_normal_params(), "", _config), "", "normal is not checked")
	var no_reasoning: Dictionary = ultra.duplicate()
	no_reasoning["reasoning"] = ""
	assert_string_contains(BenchEffort.params_broken(no_reasoning, "ultra", _config), "reasoning")
	var low: Dictionary = ultra.duplicate()
	low["reasoning"] = "low"
	assert_string_contains(BenchEffort.params_broken(low, "ultra", _config), "reasoning")
	var short: Dictionary = ultra.duplicate()
	short["max_completion_tokens"] = 1200
	assert_string_contains(BenchEffort.params_broken(short, "ultra", _config),
		"max_completion_tokens")
	var high_at_xhigh: Dictionary = BenchEffort.apply(_normal_params(), "high", _config,
		_efforts([]), "xhigh")
	assert_eq(BenchEffort.params_broken(high_at_xhigh, "high", _config), "",
		"high raised to a model's default is still high")
