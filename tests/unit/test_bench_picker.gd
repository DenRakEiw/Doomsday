extends GutTest
## S6.12g — `BenchPicker` (docs/specs/benchmark.md §19.8 items 4–6), the rules
## the benchmark modal draws: which rows are offered, how a decision model's row
## reads, the cap the player chose or the default, the over-cap rule and the
## confirmation. The modal's own test runs them on the fixture list.

const FIXTURE: String = "res://tests/fixtures/bench/openrouter_models.json"

var _config: BenchConfig = null


func before_all() -> void:
	_config = BenchConfig.load_file()


func _rows(extra: Array[Dictionary] = []) -> Array[Dictionary]:
	var list: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	(list["data"] as Array).append_array(extra)
	return ModelCatalogue.parse(JSON.stringify(list))


func _ids(rows: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for row: Dictionary in rows:
		out.append(str(row[ModelCatalogue.FIELD_ID]))
	return out


func test_content_classifiers_routers_and_image_models_are_left_out() -> void:
	var ids: Array[String] = _ids(BenchPicker.candidates(_rows([
		{"id": "vendor/x-content-safety"}, {"id": "openrouter/auto"},
		{"id": "vendor/painter", "architecture": {"output_modalities": ["image"]}},
		{"id": "vendor/speaker", "architecture": {"output_modalities": ["text", "audio"]}},
		{"id": "fixture/lyria", "architecture": {"output_modalities": ["text", "audio"]}},
		{"id": "fixture/steady:batch", "architecture": {"output_modalities": ["text"]}},
	]), _config))
	assert_false(ids.has("vendor/x-content-safety"))
	assert_false(ids.has("openrouter/auto"))
	assert_false(ids.has("vendor/painter"))
	assert_false(ids.has("vendor/speaker"), "audio output is excluded (§20.13 item 4)")
	assert_false(ids.has("fixture/lyria"), "fixture audio model is excluded")
	assert_false(ids.has("fixture/steady:batch"), "batch variant is excluded")


func test_a_typesafe_id_reads_as_a_decision_model() -> void:
	var id: String = _config.typesafe_model_prefix + "jev-latest"
	var rows: Array[Dictionary] = BenchPicker.candidates(_rows([{"id": id,
		"supported_parameters": ["reasoning"]}]), _config)
	for row: Dictionary in rows:
		if str(row[ModelCatalogue.FIELD_ID]) == id:
			assert_true(bool(row[ModelCatalogue.FIELD_TYPESAFE]))
			assert_eq(BenchPicker.efforts(row), [BenchEffort.NORMAL] as Array[String])
			return
	fail_test("the decision model is listed")


func test_the_cap_is_the_choice_when_it_is_one_else_the_default() -> void:
	assert_eq(BenchPicker.cap_for(5.0, _config), 5.0)
	assert_eq(BenchPicker.cap_for(Settings.BENCH_CAP_UNSET, _config), _config.player_default_cap_usd)
	assert_eq(BenchPicker.cap_for(3.33, _config), _config.player_default_cap_usd, "not a choice")


func test_over_cap_only_for_a_known_paid_estimate() -> void:
	var paid: Dictionary = ModelCatalogue.unlisted_row("vendor/paid")
	var known: Dictionary = {BenchEstimate.FIELD_KNOWN: true, BenchEstimate.FIELD_LIKELY: 3.0}
	var unknown: Dictionary = {BenchEstimate.FIELD_KNOWN: false, BenchEstimate.FIELD_LIKELY: 0.0}
	assert_true(BenchPicker.over_cap(paid, known, 2.0))
	assert_false(BenchPicker.over_cap(paid, known, 5.0))
	assert_false(BenchPicker.over_cap(paid, unknown, 0.5), "an unknown price never blocks")
	var free: Dictionary = paid.duplicate()
	free[ModelCatalogue.FIELD_FREE] = true
	assert_false(BenchPicker.over_cap(free, known, 0.5), "a free model ignores the cap")


func test_only_a_paid_or_unknown_model_asks_first() -> void:
	var paid: Dictionary = ModelCatalogue.unlisted_row("vendor/paid")
	assert_true(BenchPicker.needs_confirm(paid))
	var free: Dictionary = paid.duplicate()
	free[ModelCatalogue.FIELD_FREE] = true
	assert_false(BenchPicker.needs_confirm(free))


func test_the_list_stops_at_models_shown() -> void:
	var many: Array[Dictionary] = []
	for i: int in _config.player_models_shown + 5:
		many.append({"id": "bulk/model-%03d" % i, "pricing": {"prompt": "0", "completion": "0"}})
	var shown: Array[Dictionary] = BenchPicker.shown(BenchPicker.candidates(_rows(many), _config),
		"", false, BenchEffort.NORMAL, {}, _config)
	assert_eq(shown.size(), _config.player_models_shown)
