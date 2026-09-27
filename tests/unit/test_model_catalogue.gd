extends GutTest
## S6.12d — the model catalogue (docs/specs/benchmark.md §18.4) on a fixture of
## OpenRouter's public model list: reading it, the filters, the estimate per
## effort level, and the arguments of `model_list.gd`. Nothing is asked of any
## service.

const Catalogue := preload("res://tools/bench/model_catalogue.gd")
const Estimate := preload("res://tools/bench/bench_estimate.gd")
const List := preload("res://tools/bench/model_list.gd")
const FIXTURE: String = "res://tests/fixtures/bench/openrouter_models.json"
## The §11.5 worked example's measure: brief 10 000 tokens, day-0 digest 2 000.
const BRIEF: int = 10000
const DIGEST: int = 2000
const CHAT: Vector2i = Vector2i(10000, 2000)
const CHOICE: Vector2i = Vector2i(10000, 2000)

var _config: BenchConfig = null
var _rows: Array[Dictionary] = []


func before_each() -> void:
	_config = BenchConfig.load_file()
	_rows = Catalogue.parse(FileAccess.get_file_as_string(FIXTURE))


func _row(id: String) -> Dictionary:
	for row: Dictionary in _rows:
		if str(row["id"]) == id:
			return row
	return {}


func _options(args: Dictionary[String, String]) -> Dictionary:
	return List.options_of(args, _config)


func test_every_entry_with_an_id_is_a_row_sorted_by_id() -> void:
	var ids: Array[String] = []
	for row: Dictionary in _rows:
		ids.append(str(row["id"]))
	assert_eq(ids, ["fixture/broken-price", "fixture/deep", "fixture/ponder", "fixture/steady",
		"fixture/steady:free", "fixture/thinker"] as Array[String])


func test_a_row_has_the_context_the_prices_and_the_reasoning() -> void:
	var thinker: Dictionary = _row("fixture/thinker")
	assert_eq(thinker["context"], 200000)
	assert_almost_eq(float(thinker["prompt"]), 0.000001, 0.0000000001)
	assert_almost_eq(float(thinker["completion"]), 0.000004, 0.0000000001)
	assert_true(thinker["reasoning"])
	assert_false(thinker["mandatory"])
	assert_eq(thinker["efforts"], ["max", "xhigh", "high", "medium", "low", "none"])
	assert_true(_row("fixture/ponder")["mandatory"])
	assert_false(_row("fixture/steady")["reasoning"])


func test_free_models_are_marked_and_a_broken_price_is_unknown() -> void:
	assert_true(_row("fixture/steady:free")["free"])
	assert_false(_row("fixture/steady")["free"])
	assert_eq(float(_row("fixture/broken-price")["prompt"]), -1.0)
	assert_eq(Catalogue.per_million(float(_row("fixture/thinker")["completion"])), "4.00")
	assert_eq(Catalogue.per_million(-1.0), "—")


func test_the_normal_estimate_is_the_worked_example() -> void:
	var figures: Dictionary = Catalogue.estimate(_row("fixture/thinker"), BRIEF, DIGEST, 10,
		BenchEffort.NORMAL, _config)
	assert_almost_eq(float(figures["likely"]), 11.36, 0.001)
	assert_almost_eq(float(figures["at_most"]), 44.5, 0.001)


func test_a_level_above_normal_costs_its_output_and_its_limit() -> void:
	# Per call: 13 000 input at 1 USD/M + 3 000 (high) or 8 000 (ultra) output at 4 USD/M.
	var high: Dictionary = Catalogue.estimate(_row("fixture/thinker"), BRIEF, DIGEST, 10,
		BenchEffort.HIGH, _config)
	assert_almost_eq(float(high["likely"]), 10 * 80 * (0.013 + 0.012), 0.001)
	assert_almost_eq(float(high["at_most"]), 10 * 250 * (0.013 + 0.064), 0.001)
	var ultra: Dictionary = Catalogue.estimate(_row("fixture/thinker"), BRIEF, DIGEST, 10,
		BenchEffort.ULTRA, _config)
	assert_almost_eq(float(ultra["likely"]), 10 * 80 * (0.013 + 0.032), 0.001)


func test_a_model_that_cannot_reason_has_no_estimate_above_normal() -> void:
	assert_eq(Catalogue.estimate(_row("fixture/steady"), BRIEF, DIGEST, 10, BenchEffort.HIGH,
		_config), {})
	assert_eq(Catalogue.likely_text({}), "—")
	assert_false(Catalogue.estimate(_row("fixture/steady"), BRIEF, DIGEST, 10,
		BenchEffort.NORMAL, _config).is_empty())


func test_what_ultra_sends_follows_the_models_list() -> void:
	assert_eq(Catalogue.reasoning_sent(_row("fixture/thinker"), BenchEffort.ULTRA, _config), "max")
	assert_eq(Catalogue.reasoning_sent(_row("fixture/ponder"), BenchEffort.ULTRA, _config), "high")
	assert_eq(Catalogue.reasoning_sent(_row("fixture/ponder"), BenchEffort.NORMAL, _config), "")
	assert_eq(Catalogue.reasoning_text(_row("fixture/ponder")), "always, up to high")
	assert_eq(Catalogue.reasoning_text(_row("fixture/steady")), "—")


func test_a_model_that_reasons_by_default_is_marked_and_raised_and_costed() -> void:
	var deep: Dictionary = _row("fixture/deep")
	assert_true(deep["reasons_by_default"], "default_enabled without mandatory")
	assert_eq(deep["default_effort"], "xhigh")
	assert_false(_row("fixture/thinker")["reasons_by_default"])
	assert_true(_row("fixture/ponder")["reasons_by_default"], "mandatory reasons by default")
	assert_eq(Catalogue.reasoning_text(deep), "default, up to xhigh")
	assert_eq(Catalogue.reasoning_sent(deep, BenchEffort.HIGH, _config), "xhigh",
		"high never sends less than the model's default")
	assert_eq(Catalogue.reasoning_sent(deep, BenchEffort.ULTRA, _config), "xhigh")
	# At normal it reasons until its limit: 13 000 input at 2 USD/M + 1 200 output at 8 USD/M.
	var normal: Dictionary = Catalogue.estimate(deep, BRIEF, DIGEST, 10, BenchEffort.NORMAL,
		_config)
	assert_almost_eq(float(normal["likely"]), 10 * 80 * (0.026 + 0.0096), 0.001)
	var line: Dictionary = List.json_line(deep, _options({"effort": "high"}), _config, CHAT, CHOICE)
	assert_true(line["reasons_by_default"])
	assert_eq(line["reasoning_sent"], "xhigh")


func test_the_decision_model_is_priced_from_the_data() -> void:
	var row: Dictionary = Catalogue.typesafe_row(_config)
	assert_eq(row["id"], "typesafe/jev-latest")
	assert_eq(Catalogue.per_million(float(row["prompt"])), "0.04")
	assert_true(Catalogue.estimate(row, BRIEF, DIGEST, 10, BenchEffort.HIGH, _config).is_empty())
	# §17.9's worked example: 10 000 + 2 000 × 1.5 + 1 500 = 14 500 a call.
	var figures: Dictionary = Catalogue.estimate(row, BRIEF, DIGEST, 10, BenchEffort.NORMAL,
		_config)
	assert_almost_eq(float(figures["likely"]), 0.4872, 0.001)


func test_the_search_and_the_filters() -> void:
	assert_true(Catalogue.matches(_row("fixture/thinker"), "THINK"))
	assert_true(Catalogue.matches(_row("fixture/thinker"), "Fixture: Th"))
	assert_false(Catalogue.matches(_row("fixture/thinker"), "steady"))
	var free: Array[Dictionary] = List.select(_rows, _options({"free": "true"}), _config, CHAT,
		CHOICE)
	assert_eq(free.size(), 1)
	assert_eq(free[0]["id"], "fixture/steady:free")
	var cheap: Array[Dictionary] = List.select(_rows, _options({"max-cost": "2"}), _config, CHAT,
		CHOICE)
	var ids: Array[String] = []
	for row: Dictionary in cheap:
		ids.append(str(row["id"]))
	assert_eq(ids, ["typesafe/jev-latest", "fixture/steady", "fixture/steady:free"] \
		as Array[String], "an unknown price is left out")


func test_named_models_come_in_their_order_and_an_unlisted_one_is_unknown() -> void:
	var shown: Array[Dictionary] = List.select(_rows,
		_options({"models": "fixture/steady,nope/x,typesafe/jev-1.13.0"}), _config, CHAT, CHOICE)
	assert_eq(shown.size(), 3)
	assert_eq(shown[1]["id"], "nope/x")
	assert_false(shown[1]["listed"])
	assert_true(shown[2]["typesafe"])
	assert_eq(shown[2]["id"], "typesafe/jev-1.13.0")


func test_the_json_line_refuses_a_level_the_model_cannot_take() -> void:
	var options: Dictionary = _options({"models": "fixture/steady", "effort": "high",
		"suite": "quick"})
	var line: Dictionary = List.json_line(_row("fixture/steady"), options, _config, CHAT, CHOICE)
	assert_string_contains(str(line["error"]), "takes no reasoning parameter")
	var unknown: Dictionary = List.json_line(Catalogue.unlisted_row("nope/x"), options, _config,
		CHAT, CHOICE)
	assert_eq(str(unknown["error"]), "", "an unlisted model is not refused")
	assert_false(unknown["known"])
	assert_eq(unknown["seeds"], [1001, 1002, 1003] as Array[int])
	var thinker: Dictionary = List.json_line(_row("fixture/thinker"),
		_options({"effort": "ultra"}), _config, CHAT, CHOICE)
	assert_eq(thinker["reasoning_sent"], "max")
	assert_eq(thinker["max_completion_tokens"], 32000)
	assert_true(thinker["known"])


func test_the_arguments_are_checked() -> void:
	assert_eq(str(_options({})["error"]), "")
	assert_eq(_options({})["effort"], "normal")
	assert_string_contains(str(_options({"effort": "max"})["error"]), "--effort")
	assert_string_contains(str(_options({"max-cost": "lots"})["error"]), "--max-cost")
	assert_string_contains(str(_options({"suite": "long"})["error"]), "suite")
	assert_string_contains(str(_options({"models": ","})["error"]), "--models")
	assert_eq(_options({"models": " a/b , c/d "})["models"], ["a/b", "c/d"] as Array[String])


func test_the_estimate_reads_what_the_list_says_about_one_model() -> void:
	var body: String = FileAccess.get_file_as_string(FIXTURE)
	var thinker: Dictionary = Estimate.read_model(body, "fixture/thinker")
	assert_true(thinker["listed"])
	assert_true(thinker["reasoning"])
	assert_eq(thinker["efforts"][0], "max")
	assert_eq(Estimate.read_model(body, "nope/x"), {"listed": false})
	assert_eq(Estimate.read_model("not json", "fixture/thinker"), {})
	assert_eq(Estimate.read_prices(body, "fixture/broken-price"), {})


func test_the_table_has_a_column_per_level_and_marks_free_models() -> void:
	var lines: PackedStringArray = List.table(_rows, _options({}), _config, CHAT, CHOICE)
	assert_string_contains(lines[0], "Std ultra")
	var joined: String = "\n".join(lines)
	assert_string_contains(joined, "fixture/steady:free *")
	var one: PackedStringArray = List.table(_rows, _options({"effort": "high"}), _config, CHAT,
		CHOICE)
	assert_string_contains(one[0], "Standard (high)")
