extends GutTest
## S6.12g — the benchmark modal (docs/specs/benchmark.md §19.8) on the fixture
## list `tests/fixtures/bench/openrouter_models.json` and a few kinds of model
## added to it: what is left out, the order, search and *Free only*, the effort
## rules, the estimate and the cap, the confirmation a paid model asks for and a
## free one does not, no key, a running benchmark, and the list's cache. No
## network (the fetch is a stand-in), no worker (the jobs' launcher is a fake).

const MODAL: PackedScene = preload("res://ui/modals/bench_run.tscn")
const FIXTURE: String = "res://tests/fixtures/bench/openrouter_models.json"
const CACHE: String = "user://test_bench_run_modal/"
const JOBS: String = "user://test_bench_run_modal_jobs"
const KEY: String = "sk-or-v1-fixture-key"
const FREE_ID: String = "fixture/steady:free"
const STEADY: String = "fixture/steady"
const THINKER: String = "fixture/thinker"
const DEEP: String = "fixture/deep"
const PONDER: String = "fixture/ponder"
const PRICEY: String = "fixture/pricey"
const BROKEN: String = "fixture/broken-price"

var _modal: Control = null
var _body: String = ""
var _fetches: int = 0
## The modal's clock: the real time, as the cache file's own is.
var _now: int = 0
var _saved: Dictionary = {}
var _launched: int = 0


func before_each() -> void:
	_saved = {
		"status": BenchJobs.key_status, "hint": BenchJobs.key_hint, "store": BenchJobs.key_store,
		"launcher": BenchJobs.launcher, "running": BenchJobs.running, "killer": BenchJobs.killer,
		"out": BenchJobs.out_dir, "cap": Settings.bench_cap_usd, "persist": Settings.persist,
		"mock": BenchJobs.mock,
	}
	Settings.persist = false
	Settings.bench_cap_usd = Settings.BENCH_CAP_UNSET
	BenchJobs.key_status = BenchJobs.KEY_STORED
	BenchJobs.key_hint = "…" + KEY.right(4)
	BenchJobs.mock = false
	var store: BenchKeyStore = BenchKeyStore.new()
	store.backend_override = func(op: String, _key: String) -> Dictionary:
		if op == BenchKeyStore.OP_LOAD:
			return {BenchKeyStore.FIELD_STATUS: BenchKeyStore.STATUS_OK, BenchKeyStore.FIELD_KEY: KEY}
		return {BenchKeyStore.FIELD_STATUS: BenchKeyStore.STATUS_OK}
	BenchJobs.key_store = store
	BenchJobs.out_dir = JOBS
	_launched = 0
	BenchJobs.launcher = func(_dir: String, _key: String) -> int:
		_launched += 1
		return 7000 + _launched
	BenchJobs.running = func(_pid: int) -> bool: return true
	BenchJobs.killer = func(_pid: int) -> void: pass
	BenchJobs.set("_state", null)
	Fixtures.remove_root(CACHE)
	Fixtures.remove_root(JOBS)
	_body = _list_body()
	_fetches = 0
	_now = int(Time.get_unix_time_from_system())
	_modal = _new_modal()
	_modal.call(&"open")


func after_each() -> void:
	BenchJobs.stop()
	BenchJobs.set("_state", null)
	BenchJobs.key_status = _saved["status"]
	BenchJobs.key_hint = _saved["hint"]
	BenchJobs.key_store = _saved["store"]
	BenchJobs.launcher = _saved["launcher"]
	BenchJobs.running = _saved["running"]
	BenchJobs.killer = _saved["killer"]
	BenchJobs.out_dir = _saved["out"]
	BenchJobs.mock = _saved["mock"]
	Settings.bench_cap_usd = _saved["cap"]
	Settings.persist = _saved["persist"]
	Fixtures.remove_root(CACHE)
	Fixtures.remove_root(JOBS)


func _new_modal() -> Control:
	var modal: Control = MODAL.instantiate() as Control
	modal.set("list_fetcher", func() -> String:
		_fetches += 1
		return _body)
	modal.set("clock", func() -> int: return _now)
	var cache: ModelListCache = ModelListCache.new()
	cache.dir = CACHE
	modal.set("cache", cache)
	add_child_autofree(modal)
	return modal


## The fixture with the kinds the picker leaves out, a pricey model and a
## decision model added.
func _list_body() -> String:
	var list: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var data: Array = list["data"]
	data.append({"id": "vendor/guard-content-safety", "name": "Guard",
		"pricing": {"prompt": "0", "completion": "0"}})
	data.append({"id": "openrouter/auto", "name": "Auto",
		"pricing": {"prompt": "0.000001", "completion": "0.000001"}})
	data.append({"id": "vendor/painter", "name": "Painter",
		"architecture": {"output_modalities": ["image"]},
		"pricing": {"prompt": "0.000001", "completion": "0.000001"}})
	data.append({"id": "fixture/lyria", "name": "Fixture: Lyria Audio",
		"architecture": {"output_modalities": ["text", "audio"]},
		"pricing": {"prompt": "0.000001", "completion": "0.000004"}})
	data.append({"id": "fixture/steady:batch", "name": "Fixture: Steady (batch)",
		"architecture": {"output_modalities": ["text"]},
		"pricing": {"prompt": "0.00000005", "completion": "0.0000002"}})
	data.append({"id": PRICEY, "name": "Fixture: Pricey",
		"pricing": {"prompt": "0.001", "completion": "0.004"}})
	data.append({"id": "typesafe/jev-latest", "name": "TypeSafe Jev",
		"pricing": {"prompt": "0.000001", "completion": "0"}})
	return JSON.stringify(list)


func _ids() -> Array[String]:
	var out: Array[String] = []
	for row: Dictionary in _modal.get("rows_shown"):
		out.append(str(row[ModelCatalogue.FIELD_ID]))
	return out


func _row(id: String) -> Dictionary:
	for row: Dictionary in _modal.get("rows_shown"):
		if str(row[ModelCatalogue.FIELD_ID]) == id:
			return row
	return {}


func _likely(id: String, effort: String) -> float:
	var tokens: Dictionary = BenchPicker.measure(Game.content(), BenchJobs.config())
	var figures: Dictionary = BenchPicker.estimate(_row(id), effort, tokens, BenchJobs.config())
	return float(figures[BenchEstimate.FIELD_LIKELY])


func test_models_that_cannot_play_are_left_out() -> void:
	var ids: Array[String] = _ids()
	for id: String in ["vendor/guard-content-safety", "openrouter/auto", "vendor/painter",
			"fixture/lyria", "fixture/steady:batch"]:
		assert_false(ids.has(id), id)
	for id: String in [FREE_ID, STEADY, THINKER, DEEP, PONDER, PRICEY, BROKEN,
			"typesafe/jev-latest"]:
		assert_true(ids.has(id), id)


func test_free_models_come_first_then_the_cheapest() -> void:
	var ids: Array[String] = _ids()
	assert_eq(ids[0], FREE_ID)
	assert_lt(ids.find(STEADY), ids.find(THINKER), "cheaper first")
	assert_lt(ids.find(THINKER), ids.find(PRICEY))
	assert_eq(ids[ids.size() - 1], BROKEN, "an unknown price last")


func test_search_matches_id_or_name_in_any_case() -> void:
	_modal.call(&"set_search", "STEADY")
	assert_eq(_ids(), [FREE_ID, STEADY] as Array[String])
	_modal.call(&"set_search", "Pricey")
	assert_eq(_ids(), [PRICEY] as Array[String])


func test_free_only_keeps_the_free_models() -> void:
	_modal.call(&"set_free_only", true)
	assert_eq(_ids(), [FREE_ID] as Array[String])


func test_no_match_says_so() -> void:
	_modal.call(&"set_search", "no such model at all")
	assert_eq(_ids().size(), 0)
	assert_eq(_modal.call(&"list_status"), tr("UI_BENCH_RUN_NO_MATCH"))


func test_model_without_reasoning_plays_at_normal_only() -> void:
	_modal.call(&"choose", STEADY)
	assert_eq(_modal.get("effort"), BenchEffort.NORMAL)
	assert_true((_modal.call(&"effort_button", BenchEffort.HIGH) as ConsoleButton).disabled)
	assert_true((_modal.call(&"effort_button", BenchEffort.ULTRA) as ConsoleButton).disabled)
	assert_eq(_modal.call(&"effort_note"), tr("UI_BENCH_RUN_NO_REASONING"))


func test_decision_model_plays_at_normal_only() -> void:
	_modal.call(&"choose", "typesafe/jev-latest")
	assert_true((_modal.call(&"effort_button", BenchEffort.HIGH) as ConsoleButton).disabled)


func test_model_that_reasons_by_default_starts_on_high() -> void:
	_modal.call(&"choose", DEEP)
	assert_eq(_modal.get("effort"), BenchEffort.HIGH)
	assert_false((_modal.call(&"effort_button", BenchEffort.ULTRA) as ConsoleButton).disabled)
	_modal.call(&"choose_effort", BenchEffort.NORMAL)
	assert_eq(_modal.call(&"effort_note"), tr("UI_BENCH_RUN_DEFAULT_REASONING"))


func test_reasoning_model_starts_on_normal_without_a_note() -> void:
	_modal.call(&"choose", THINKER)
	assert_eq(_modal.get("effort"), BenchEffort.NORMAL)
	assert_eq(_modal.call(&"effort_note"), "")


func test_estimate_names_likely_and_most() -> void:
	_modal.call(&"choose_cap", 20.0)
	_modal.call(&"choose", THINKER)
	var tokens: Dictionary = BenchPicker.measure(Game.content(), BenchJobs.config())
	var figures: Dictionary = BenchPicker.estimate(_row(THINKER), BenchEffort.NORMAL, tokens,
		BenchJobs.config())
	assert_eq(_modal.call(&"estimate_text"), tr("UI_BENCH_RUN_ESTIMATE").format({
		"likely": Format.decimal(float(figures[BenchEstimate.FIELD_LIKELY]), 2),
		"most": Format.decimal(float(figures[BenchEstimate.FIELD_AT_MOST]), 2)}))
	assert_false(_modal.call(&"is_over_cap"))


func test_unknown_price_says_the_price_is_unknown() -> void:
	_modal.call(&"choose", BROKEN)
	assert_eq(_modal.call(&"estimate_text"), tr("UI_BENCH_RUN_ESTIMATE_UNKNOWN"))
	assert_false((_modal.call(&"start_button") as ConsoleButton).disabled, "never blocks")


func test_estimate_above_the_cap_disables_start() -> void:
	_modal.call(&"choose_cap", 0.5)
	_modal.call(&"choose", PRICEY)
	assert_gt(_likely(PRICEY, BenchEffort.NORMAL), 0.5)
	assert_true(_modal.call(&"is_over_cap"))
	assert_true((_modal.call(&"start_button") as ConsoleButton).disabled)


func test_free_model_shows_the_free_note_and_ignores_the_cap() -> void:
	_modal.call(&"choose_cap", 0.5)
	_modal.call(&"choose", FREE_ID)
	assert_eq(_modal.call(&"estimate_text"), tr("UI_BENCH_RUN_FREE_NOTE"))
	assert_false(_modal.call(&"is_over_cap"))


func test_cap_choice_is_remembered() -> void:
	assert_eq(_modal.get("cap_usd"), BenchJobs.config().player_default_cap_usd, "the default")
	_modal.call(&"choose_cap", 5.0)
	assert_eq(Settings.bench_cap_usd, 5.0)
	var again: Control = _new_modal()
	again.call(&"open")
	assert_eq(again.get("cap_usd"), 5.0)


func test_paid_model_asks_before_it_starts() -> void:
	_modal.call(&"choose_cap", 20.0)
	_modal.call(&"choose", THINKER)
	_modal.call(&"start")
	var confirm: ConfirmModal = _modal.call(&"confirm_modal")
	assert_true(confirm.visible, "the question is up")
	assert_null(BenchJobs.state(), "nothing started yet")
	confirm.on_escape()
	await get_tree().process_frame
	assert_null(BenchJobs.state(), "cancel starts nothing")
	assert_eq(_launched, 0)


func test_paid_model_starts_on_yes() -> void:
	_modal.call(&"choose_cap", 20.0)
	_modal.call(&"choose", THINKER)
	_modal.call(&"start")
	var confirm: ConfirmModal = _modal.call(&"confirm_modal")
	confirm.answered.emit(true)
	await get_tree().process_frame
	BenchJobs.wait_started()
	assert_not_null(BenchJobs.state())
	assert_eq(BenchJobs.state().model, THINKER)
	assert_eq(BenchJobs.state().cap_usd, 20.0)
	assert_eq(_modal.call(&"section"), "job")


func test_free_model_starts_without_asking() -> void:
	_modal.call(&"choose", FREE_ID)
	var reason: String = await _modal.call(&"start")
	assert_eq(reason, "")
	BenchJobs.wait_started()
	assert_false((_modal.call(&"confirm_modal") as ConfirmModal).visible)
	assert_true(BenchJobs.state().is_running())
	assert_true(BenchJobs.state().free)
	assert_eq(_launched, BenchJobs.config().player_workers_free)
	assert_eq(_modal.call(&"section"), "job")


func test_running_benchmark_shows_its_progress_on_open() -> void:
	BenchJobs.start(STEADY, BenchEffort.NORMAL, 2.0)
	BenchJobs.wait_started()
	var again: Control = _new_modal()
	again.call(&"open")
	assert_eq(again.call(&"section"), "job")


func test_no_key_offers_the_key_dialog_only() -> void:
	BenchJobs.key_status = BenchJobs.KEY_NONE
	var modal: Control = _new_modal()
	modal.call(&"open")
	assert_eq(modal.call(&"section"), "no_key")
	watch_signals(modal)
	(modal.call(&"set_key_button") as ConsoleButton).pressed.emit()
	assert_signal_emitted(modal, "key_requested")


func test_list_is_kept_and_reused_within_a_day() -> void:
	assert_eq(_fetches, 1)
	assert_true(FileAccess.file_exists(CACHE.path_join(ModelListCache.FILE_NAME)))
	var again: Control = _new_modal()
	again.call(&"open")
	assert_eq(_fetches, 1, "fresh: not asked again")
	assert_true(again.get("rows_shown").size() > 0)


func test_stale_list_is_fetched_again_and_kept_when_that_fails() -> void:
	# The file's own time is now; the clock says a day later.
	_now += BenchJobs.config().player_models_max_age_s + 60
	_body = ""
	var again: Control = _new_modal()
	again.call(&"open")
	assert_eq(_fetches, 2)
	assert_eq(again.call(&"list_status"), "", "the cached list stays")
	assert_true(again.get("rows_shown").size() > 0)


func test_list_that_cannot_be_loaded_says_so() -> void:
	Fixtures.remove_root(CACHE)
	_body = ""
	var modal: Control = _new_modal()
	modal.call(&"open")
	assert_eq(modal.call(&"list_status"), tr("UI_BENCH_RUN_LIST_FAILED"))


## S6.12h (§20.13 item 1): a start refused because a benchmark is already
## running shows `UI_BENCH_RUN_START_BUSY`; any other refusal shows
## `UI_BENCH_RUN_START_FAILED`.
func test_start_refusals_show_busy_or_failed_line() -> void:
	_modal.call(&"choose", FREE_ID)
	BenchJobs.start(STEADY, BenchEffort.NORMAL, 2.0)
	BenchJobs.wait_started()
	var reason: String = await _modal.call(&"start")
	assert_eq(reason, BenchJobs.REASON_RUNNING)
	assert_eq(_modal.call(&"start_failure_text"), tr("UI_BENCH_RUN_START_BUSY"))
	BenchJobs.stop()
	BenchJobs.set("_state", null)
	var saved_sup: int = BenchKeyStore.supported_override
	BenchKeyStore.supported_override = 0
	var other: String = await _modal.call(&"start")
	BenchKeyStore.supported_override = saved_sup
	assert_eq(other, BenchJobs.REASON_UNSUPPORTED)
	assert_eq(_modal.call(&"start_failure_text"), tr("UI_BENCH_RUN_START_FAILED"))
