extends GutTest
## S6.12 — the pre-flight cost estimate (docs/specs/benchmark.md §11.5, §16.9):
## the two figures from fixed measures and prices, the price list reader, and the
## rule that stops the tool. No network.

const Estimate := preload("res://tools/bench/bench_estimate.gd")
## §11.5's worked example: 1 USD per million input tokens, 4 per million output.
const PROMPT_PRICE: float = 0.000001
const COMPLETION_PRICE: float = 0.000004

var _config: BenchConfig = null


func before_each() -> void:
	_config = BenchConfig.load_file()


func _models_body() -> String:
	return JSON.stringify({"data": [
		{"id": "vendor/cheap", "pricing": {"prompt": "0.0000001", "completion": "0.0000004"}},
		{"id": "vendor/mid", "pricing": {"prompt": "0.000001", "completion": "0.000004"}},
		{"id": "vendor/odd", "pricing": {"prompt": 0.000001, "completion": "0.000004"}},
		{"id": "vendor/words", "pricing": {"prompt": "free", "completion": "0"}},
	]})


func test_the_worked_example_of_the_standard_suite() -> void:
	# Brief 10 000 tokens, day-0 digest 2 000: 13 000 input tokens a call.
	var estimate: Dictionary = Estimate.figures(10000, 2000, 10, PROMPT_PRICE, COMPLETION_PRICE,
		_config)
	assert_true(bool(estimate["known"]))
	assert_almost_eq(float(estimate["likely"]), 11.36, 0.0001)
	assert_almost_eq(float(estimate["at_most"]), 44.50, 0.0001)
	assert_eq(int(estimate["calls"]), 800)
	assert_true(Estimate.preflight_blocks(estimate, _config.max_cost_usd, false), "exit 7")
	assert_false(Estimate.preflight_blocks(estimate, _config.max_cost_usd, true), "--yes goes on")
	assert_string_contains(Estimate.block_line(estimate), "--max-cost=12")


func test_the_quick_suite_is_still_above_the_cap_and_a_cheap_model_runs() -> void:
	var quick: Dictionary = Estimate.figures(10000, 2000, 3, PROMPT_PRICE, COMPLETION_PRICE,
		_config)
	assert_almost_eq(float(quick["likely"]), 3.408, 0.0001)
	assert_true(Estimate.preflight_blocks(quick, _config.max_cost_usd, false))
	var cheap: Dictionary = Estimate.figures(10000, 2000, 10, PROMPT_PRICE / 10.0,
		COMPLETION_PRICE / 10.0, _config)
	assert_almost_eq(float(cheap["likely"]), 1.136, 0.0001)
	assert_false(Estimate.preflight_blocks(cheap, _config.max_cost_usd, false))


func test_an_unknown_price_gives_no_figures_and_never_blocks() -> void:
	var estimate: Dictionary = Estimate.figures(10000, 2000, 10, -1.0, -1.0, _config)
	assert_false(bool(estimate["known"]))
	assert_eq(float(estimate["likely"]), 0.0)
	assert_eq(int(estimate["input_tokens"]), 800 * 13000)
	assert_false(Estimate.preflight_blocks(estimate, 0.0, false))
	assert_string_contains(Estimate.line(estimate, 10, "vendor/model", 2.0), "price unknown")


func test_the_line_names_both_figures_and_the_cap() -> void:
	var estimate: Dictionary = Estimate.figures(10000, 2000, 10, PROMPT_PRICE, COMPLETION_PRICE,
		_config)
	assert_eq(Estimate.line(estimate, 10, "vendor/mid", 2.0),
		"benchmark: estimate for 10 runs of vendor/mid: ≈11.36 USD, at most 44.50 USD (cap 2.00 USD)")


func test_tokens_are_characters_over_four_rounded_up() -> void:
	assert_eq(Estimate.tokens(40000, _config), 10000)
	assert_eq(Estimate.tokens(40001, _config), 10001)


func test_the_models_list_reader_finds_a_models_prices() -> void:
	var prices: Dictionary = Estimate.read_prices(_models_body(), "vendor/mid")
	assert_almost_eq(float(prices["prompt"]), 0.000001, 1e-12)
	assert_almost_eq(float(prices["completion"]), 0.000004, 1e-12)


func test_the_models_list_reader_gives_nothing_it_cannot_trust() -> void:
	assert_eq(Estimate.read_prices(_models_body(), "vendor/missing"), {})
	assert_eq(Estimate.read_prices("<html>", "vendor/mid"), {})
	assert_eq(Estimate.read_prices(_models_body(), "vendor/odd"), {}, "a number, not a string")
	assert_eq(Estimate.read_prices(_models_body(), "vendor/words"), {})
	assert_eq(Estimate.read_prices("{\"data\": 3}", "vendor/mid"), {})


func test_only_openrouter_is_asked_for_a_price() -> void:
	assert_eq(Estimate.fetch_prices("http://localhost:1/v1", "vendor/mid", _config), {},
		"a local server has no price list, and nothing is requested")


func test_the_decision_model_worked_example() -> void:
	# §17.9: rules 10 000 tokens, day-0 situation 2 000 → 10 000 + 3 000 + 1 500 a call.
	var standard: Dictionary = Estimate.choice_figures(10000, 2000, 10, _config)
	assert_true(bool(standard["known"]))
	assert_eq(int(standard["input_tokens"]), 800 * 14500)
	assert_almost_eq(float(standard["likely"]), 0.4872, 0.00001)
	assert_almost_eq(float(standard["at_most"]), 1.5225, 0.00001)
	assert_false(Estimate.preflight_blocks(standard, _config.max_cost_usd, false), "it runs")
	assert_eq(Estimate.choice_line(standard, 10, "typesafe/jev-latest", 2.0, 3000, _config),
		"benchmark: estimate for 10 runs of typesafe/jev-latest: ≈0.49 USD, at most 1.52 USD (cap 2.00 USD)")
	var one: Dictionary = Estimate.choice_figures(10000, 2000, 1, _config)
	assert_almost_eq(float(one["likely"]), 0.04872, 0.00001)
	assert_almost_eq(float(one["at_most"]), 0.15225, 0.00001)


func test_a_negative_price_is_unknown_and_never_blocks() -> void:
	_config.typesafe_price_input = -1.0
	var estimate: Dictionary = Estimate.choice_figures(10000, 2000, 10, _config)
	assert_false(bool(estimate["known"]))
	assert_false(Estimate.preflight_blocks(estimate, 0.0, false))
	assert_eq(Estimate.choice_line(estimate, 10, "typesafe/jev-latest", 2.0, 3000, _config),
		("benchmark: estimate for 10 runs of typesafe/jev-latest: price unknown (≈800 calls,"
		+ " ≈11600000 input tokens) — only the request cap (3000) and 250 calls a run guard this run"))
