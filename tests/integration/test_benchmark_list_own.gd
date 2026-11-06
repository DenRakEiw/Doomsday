extends GutTest
## S6.12g — the player's own benchmark in the Benchmark list and the settings
## (docs/specs/benchmark.md §19.6, §19.9): the button to the benchmark modal and
## the job section only where §19.1 says yes; the section while a benchmark
## runs and once after it ended; the group line and *Submit* only for a
## complete, current, own model benchmark; *Submit*'s refusal against a board of
## other content, and its copies and shell calls (a seam); the settings' key row
## hidden where the build has no key store. Nothing here starts a process,
## touches the key store or the network.

const BENCHMARK: PackedScene = preload("res://ui/modals/benchmark.tscn")
const SUBMIT: PackedScene = preload("res://ui/modals/bench_submit.tscn")
const PAUSE_MENU: PackedScene = preload("res://ui/modals/pause_menu.tscn")
const CANARY: String = "res://tests/fixtures/bench/determinism_entry.json"
const ROOT: String = "user://test_benchmark_list_own"
const JOBS: String = "user://test_benchmark_list_own_jobs"
const MODEL: String = "vendor/own-model"

var _saved: Dictionary = {}
var _shell: Array[Array] = []


func before_each() -> void:
	_saved = {"online": Settings.bench_online, "persist": Settings.persist,
		"supported": BenchKeyStore.supported_override, "launcher": BenchJobs.launcher,
		"running": BenchJobs.running, "killer": BenchJobs.killer, "out": BenchJobs.out_dir,
		"inline": BenchJobs.key_inline, "store": BenchJobs.key_store,
		"status": BenchJobs.key_status}
	Settings.persist = false
	Settings.bench_online = false
	BenchKeyStore.supported_override = 1
	BenchJobs.key_inline = true
	BenchJobs.key_status = BenchJobs.KEY_UNKNOWN
	BenchJobs.out_dir = JOBS
	BenchJobs.launcher = func(_dir: String, _key: String) -> int: return 9001
	BenchJobs.running = func(_pid: int) -> bool: return true
	BenchJobs.killer = func(_pid: int) -> void: pass
	var store: BenchKeyStore = BenchKeyStore.new()
	store.backend_override = func(_op: String, _key: String) -> Dictionary:
		return {BenchKeyStore.FIELD_STATUS: BenchKeyStore.STATUS_OK,
			BenchKeyStore.FIELD_KEY: "sk-or-v1-own"}
	BenchJobs.key_store = store
	BenchJobs.set("_state", null)
	_shell.clear()
	Fixtures.remove_root(ROOT)
	Fixtures.remove_root(JOBS)
	Fixtures.remove_root(BenchLibrary.user_dir)
	Fixtures.remove_root(BenchGroup.submit_root)
	Fixtures.remove_root(BenchSubmitLog.default_dir)
	GlobalBoardClient.forget_fetch()


func after_each() -> void:
	BenchJobs.stop()
	BenchJobs.set("_state", null)
	Settings.bench_online = _saved["online"]
	Settings.persist = _saved["persist"]
	BenchKeyStore.supported_override = _saved["supported"]
	BenchJobs.launcher = _saved["launcher"]
	BenchJobs.running = _saved["running"]
	BenchJobs.killer = _saved["killer"]
	BenchJobs.out_dir = _saved["out"]
	BenchJobs.key_inline = _saved["inline"]
	BenchJobs.key_store = _saved["store"]
	BenchJobs.key_status = _saved["status"]
	Fixtures.remove_root(ROOT)
	Fixtures.remove_root(JOBS)
	Fixtures.remove_root(BenchLibrary.user_dir)
	Fixtures.remove_root(BenchGroup.submit_root)
	Fixtures.remove_root(BenchSubmitLog.default_dir)
	GlobalBoardClient.forget_fetch()


## One recorded run of `model` on `seed_value` in the player's folder.
func _record(seed_value: int, model: String = MODEL, backend: String = "openrouter",
		content_hash: String = "", dir: String = "") -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CANARY))
	d["model"] = model
	d["backend"] = backend
	d["suite"] = BenchConfig.SUITE_QUICK
	d["seed"] = seed_value
	d["content_hash"] = content_hash if not content_hash.is_empty() \
		else Game.content().content_hash
	var target: String = dir if not dir.is_empty() else BenchLibrary.user_dir
	DirAccess.make_dir_recursive_absolute(target)
	var file: FileAccess = FileAccess.open(target.path_join(BenchEntry.file_name_for(model,
		str(d["params_id"]), int(d["prompt_version"]), BenchConfig.SUITE_QUICK, seed_value)),
		FileAccess.WRITE)
	file.store_string(JSON.stringify(d))
	file.close()


func _record_suite(model: String = MODEL, backend: String = "openrouter",
		content_hash: String = "") -> void:
	for seed_value: int in BenchJobs.config().suite_seeds(BenchConfig.SUITE_QUICK):
		_record(seed_value, model, backend, content_hash)


func _list() -> Control:
	var modal: Control = BENCHMARK.instantiate() as Control
	var client: GlobalBoardClient = modal.get_node("BoardClient") as GlobalBoardClient
	client.cache_dir = ROOT.path_join("cache")
	client.shipped_path = ROOT.path_join("shipped.json")
	add_child_autofree(modal)
	modal.call(&"open")
	return modal


func _buttons(root: Node, key: String) -> Array[ConsoleButton]:
	var out: Array[ConsoleButton] = []
	for node: Node in root.find_children("*", "Button", true, false):
		var button: ConsoleButton = node as ConsoleButton
		if button != null and button.label_key == key and button.is_visible_in_tree():
			out.append(button)
	return out


func _texts(root: Node) -> Array[String]:
	var out: Array[String] = []
	for label: Node in root.find_children("*", "Label", true, false):
		if (label as Label).is_visible_in_tree():
			out.append((label as Label).text)
	return out


func _own_group() -> BenchGroup:
	var groups: Array[BenchGroup] = BenchGroup.own_groups(BenchLibrary.scan(false),
		BenchLibrary.user_dir, Game.content().content_hash, BenchJobs.config())
	return groups[0] if not groups.is_empty() else null


# --------------------------------------------------------------- the button


func test_desktop_list_offers_your_own_benchmark() -> void:
	var list: Control = _list()
	assert_eq(_buttons(list, "UI_BENCH_RUN_OPEN").size(), 1)
	watch_signals(list)
	_buttons(list, "UI_BENCH_RUN_OPEN")[0].pressed.emit()
	assert_signal_emitted(list, "run_requested")


func test_web_list_has_no_own_benchmark() -> void:
	BenchKeyStore.supported_override = 0
	_record_suite()
	var list: Control = _list()
	assert_eq(_buttons(list, "UI_BENCH_RUN_OPEN").size(), 0)
	assert_eq(_buttons(list, "UI_BENCH_SUBMIT").size(), 0)


# ---------------------------------------------------------- the job section


func test_job_section_is_hidden_before_any_benchmark() -> void:
	var list: Control = _list()
	assert_false((list.call(&"job_section") as BenchJobView).visible)


func test_job_section_shows_a_running_benchmark() -> void:
	BenchJobs.start(MODEL, BenchEffort.NORMAL, 2.0)
	BenchJobs.wait_started()
	var list: Control = _list()
	var job: BenchJobView = list.call(&"job_section")
	assert_true(job.visible)
	assert_true(job.stop_button().visible)
	var seeds: Array[int] = BenchJobs.config().suite_seeds(BenchConfig.SUITE_QUICK)
	assert_eq(job.lines()[0], tr("UI_BENCH_JOB_SEED_WAITING").format({"seed": seeds[0]}))


func test_ended_benchmark_shows_once_after_it_ended() -> void:
	BenchJobs.start(MODEL, BenchEffort.NORMAL, 2.0)
	BenchJobs.wait_started()
	BenchJobs.stop()
	var list: Control = _list()
	var job: BenchJobView = list.call(&"job_section")
	assert_true(job.visible, "ended since the list was last opened")
	assert_true(job.lines().has(tr("UI_BENCH_JOB_STOPPED")))
	list.visible = false
	list.call(&"open")
	assert_false((list.call(&"job_section") as BenchJobView).visible, "seen: gone")


func test_stop_in_the_section_stops_the_benchmark() -> void:
	BenchJobs.start(MODEL, BenchEffort.NORMAL, 2.0)
	BenchJobs.wait_started()
	var list: Control = _list()
	(list.call(&"job_section") as BenchJobView).stop_button().pressed.emit()
	assert_false(BenchJobs.state().is_running())


# ----------------------------------------------------------- group and Submit


func test_complete_current_own_benchmark_gets_a_submit_line() -> void:
	_record_suite()
	var list: Control = _list()
	assert_eq(_buttons(list, "UI_BENCH_SUBMIT").size(), 1)
	var group: BenchGroup = _own_group()
	assert_true(_texts(list).has(tr("UI_BENCH_GROUP_ROW").format({
		"score": Format.decimal(group.score, 1), "wins": group.wins, "runs": group.runs})))


func test_incomplete_benchmark_has_no_submit() -> void:
	_record(BenchJobs.config().suite_seeds(BenchConfig.SUITE_QUICK)[0])
	assert_eq(_buttons(_list(), "UI_BENCH_SUBMIT").size(), 0)


func test_mock_runs_have_no_submit() -> void:
	_record_suite(MODEL, "mock:cheapest")
	assert_eq(_buttons(_list(), "UI_BENCH_SUBMIT").size(), 0)


func test_bot_runs_have_no_submit() -> void:
	_record_suite("bot:greedy", BenchEntry.BACKEND_BOT)
	assert_eq(_buttons(_list(), "UI_BENCH_SUBMIT").size(), 0)


func test_runs_of_other_content_have_no_submit() -> void:
	_record_suite(MODEL, "openrouter", "other-content")
	assert_eq(_buttons(_list(), "UI_BENCH_SUBMIT").size(), 0)


func test_runs_outside_the_players_folder_have_no_submit() -> void:
	var library: BenchLibrary = BenchLibrary.new()
	var entry: BenchEntry = BenchEntry.from_json(FileAccess.get_file_as_string(CANARY))
	library.entries.append(entry)
	library.paths.append("res://benchmark/showcase/x.json")
	assert_eq(BenchGroup.own_groups(library, BenchLibrary.user_dir, entry.content_hash,
		BenchJobs.config()).size(), 0)


func test_submit_names_the_known_boards_content() -> void:
	_record_suite()
	var list: Control = _list()
	var board: GlobalBoard = GlobalBoard.parse(JSON.stringify({"version": 1,
		"generated": "2026-09-28T00:00:00", "content_hash": "board-content", "rows": []}),
		BenchJobs.config())
	(list.call(&"client") as GlobalBoardClient).board_changed.emit(board,
		GlobalBoardClient.SOURCE_CACHE, false)
	watch_signals(list)
	_buttons(list, "UI_BENCH_SUBMIT")[0].pressed.emit()
	assert_signal_emitted(list, "submit_requested")
	var args: Array = get_signal_parameters(list, "submit_requested")
	assert_eq((args[0] as BenchGroup).model, MODEL)
	assert_eq(args[1], "board-content")


func _submit_modal() -> Control:
	var modal: Control = SUBMIT.instantiate() as Control
	var cfg: BenchConfig = BenchConfig.load_file()
	cfg.submit_api_url = ""
	cfg.submit_publishable_key = ""
	modal.set("config_override", cfg)
	modal.set("shell", func(kind: String, target: String) -> void: _shell.append([kind, target]))
	add_child_autofree(modal)
	return modal


func test_submit_against_another_version_is_refused() -> void:
	_record_suite()
	var modal: Control = _submit_modal()
	modal.call(&"open", _own_group(), "board-content", Game.content().content_hash)
	assert_eq(modal.call(&"message_text"), tr("UI_BENCH_SUBMIT_OLD_VERSION"))
	assert_eq((modal.get("copies") as Array).size(), 0)
	assert_eq(_shell.size(), 0, "nothing opened")
	assert_false((modal.call(&"again_button") as ConsoleButton).visible)


func test_submit_copies_the_files_and_opens_folder_and_page() -> void:
	_record_suite()
	var group: BenchGroup = _own_group()
	var modal: Control = _submit_modal()
	modal.call(&"open", group, "", Game.content().content_hash)
	var copies: Array[String] = modal.get("copies")
	assert_eq(copies.size(), 3)
	for path: String in copies:
		assert_true(FileAccess.file_exists(path), path)
		assert_true(path.begins_with(group.submit_dir()))
	assert_eq(_shell.size(), 2)
	assert_eq(_shell[0][0], "folder")
	assert_eq(_shell[1], ["url", BenchJobs.config().player_submit_url])
	assert_eq(modal.call(&"message_text"), tr("UI_BENCH_SUBMIT_STEPS").format({"count": 3}))


func test_submit_against_the_same_version_goes_ahead() -> void:
	_record_suite()
	var modal: Control = _submit_modal()
	var content_hash: String = Game.content().content_hash
	modal.call(&"open", _own_group(), content_hash, content_hash)
	assert_eq((modal.get("copies") as Array).size(), 3)


func test_submit_again_opens_both_again_into_a_clean_folder() -> void:
	_record_suite()
	var group: BenchGroup = _own_group()
	var modal: Control = _submit_modal()
	modal.call(&"open", group, "", Game.content().content_hash)
	var stray: FileAccess = FileAccess.open(group.submit_dir().path_join("stray.json"),
		FileAccess.WRITE)
	stray.close()
	(modal.call(&"again_button") as ConsoleButton).pressed.emit()
	assert_eq(_shell.size(), 4)
	assert_false(FileAccess.file_exists(group.submit_dir().path_join("stray.json")))


# ------------------------------------------------------------- settings row


func _menu() -> Control:
	var menu: Control = PAUSE_MENU.instantiate() as Control
	add_child_autofree(menu)
	menu.call(&"open_settings_only")
	return menu


func test_settings_show_the_key_row_on_a_desktop() -> void:
	var menu: Control = _menu()
	var button: ConsoleButton = menu.call(&"key_button")
	assert_true(button.is_visible_in_tree())
	watch_signals(menu)
	button.pressed.emit()
	assert_signal_emitted(menu, "bench_key_requested")


func test_settings_row_caption_is_the_keys_state() -> void:
	var menu: Control = _menu()
	assert_eq((menu.call(&"key_state_label") as Label).text, BenchJobs.key_state_text())
	assert_eq(BenchJobs.key_status, BenchJobs.KEY_STORED)


func test_settings_hide_the_key_row_on_the_web() -> void:
	BenchKeyStore.supported_override = 0
	var menu: Control = _menu()
	assert_false((menu.call(&"key_button") as ConsoleButton).is_visible_in_tree())
	assert_false((menu.call(&"key_state_label") as Label).is_visible_in_tree())


# ------------------------------------------------------- direct submit (S6.12h)


func _direct_config() -> BenchConfig:
	var cfg: BenchConfig = BenchConfig.load_file()
	cfg.submit_api_url = "https://example.supabase.co"
	cfg.submit_publishable_key = "sb_publishable_test"
	return cfg


func test_direct_submit_shows_consent_sends_and_handles_every_answer() -> void:
	_record_suite()
	Settings.bench_online = false
	var group: BenchGroup = _own_group()
	var modal: Control = _submit_modal()
	var cfg: BenchConfig = _direct_config()
	modal.set("config_override", cfg)
	var sent_calls: Array[Dictionary] = []
	var reply: Dictionary = {
		"code": 200,
		"body": JSON.stringify({"status": "received", "id": 99}),
	}
	modal.set("transport", func(url: String, headers: PackedStringArray, body: String,
			done: Callable) -> void:
		sent_calls.append({"url": url, "headers": headers, "body": body})
		done.call(int(reply["code"]), str(reply["body"]).to_utf8_buffer()))

	# 1. Consent stage, online switch off does not block Send.
	modal.call(&"open", group, "", Game.content().content_hash)
	assert_eq(modal.call(&"message_text"), tr("UI_BENCH_SUBMIT_CONSENT").format({"count": 3}))
	assert_true((modal.call(&"send_button") as ConsoleButton).visible)
	assert_true((modal.call(&"github_button") as ConsoleButton).visible)
	assert_false((modal.call(&"again_button") as ConsoleButton).visible)

	# 2. RECEIVED -> UI_BENCH_SUBMIT_SENT, Close only, recorded in BenchSubmitLog.
	(modal.call(&"send_button") as ConsoleButton).pressed.emit()
	assert_eq(sent_calls.size(), 1)
	assert_eq(modal.call(&"message_text"), tr("UI_BENCH_SUBMIT_SENT"))
	assert_false((modal.call(&"send_button") as ConsoleButton).visible)
	assert_false((modal.call(&"retry_button") as ConsoleButton).visible)
	assert_false((modal.call(&"github_button") as ConsoleButton).visible)
	assert_false(str(modal.get("last_log_line")).contains(MODEL), "log line never holds body")
	assert_eq(BenchSubmitLog.load_log().sent.size(), 1)

	# 3. ALREADY -> UI_BENCH_SUBMIT_ALREADY.
	reply["body"] = JSON.stringify({"status": "already", "id": 99})
	modal.call(&"open", group, "", Game.content().content_hash)
	(modal.call(&"send_button") as ConsoleButton).pressed.emit()
	assert_eq(modal.call(&"message_text"), tr("UI_BENCH_SUBMIT_ALREADY"))

	# 4. BUSY -> UI_BENCH_SUBMIT_BUSY, Retry + GitHub + Close; Retry sends again.
	reply["code"] = 400
	reply["body"] = JSON.stringify({"message": "submit:busy"})
	modal.call(&"open", group, "", Game.content().content_hash)
	(modal.call(&"send_button") as ConsoleButton).pressed.emit()
	assert_eq(modal.call(&"message_text"), tr("UI_BENCH_SUBMIT_BUSY"))
	assert_true((modal.call(&"retry_button") as ConsoleButton).visible)
	assert_true((modal.call(&"github_button") as ConsoleButton).visible)
	var before_retry: int = sent_calls.size()
	(modal.call(&"retry_button") as ConsoleButton).pressed.emit()
	assert_eq(sent_calls.size(), before_retry + 1)

	# 5. CLOSED -> UI_BENCH_SUBMIT_CLOSED, GitHub + Close.
	reply["body"] = JSON.stringify({"message": "submit:closed"})
	modal.call(&"open", group, "", Game.content().content_hash)
	(modal.call(&"send_button") as ConsoleButton).pressed.emit()
	assert_eq(modal.call(&"message_text"), tr("UI_BENCH_SUBMIT_CLOSED"))
	assert_false((modal.call(&"retry_button") as ConsoleButton).visible)
	assert_true((modal.call(&"github_button") as ConsoleButton).visible)

	# 6. REFUSED -> UI_BENCH_SUBMIT_REFUSED, GitHub + Close.
	reply["body"] = JSON.stringify({"message": "submit:bad_json"})
	modal.call(&"open", group, "", Game.content().content_hash)
	(modal.call(&"send_button") as ConsoleButton).pressed.emit()
	assert_eq(modal.call(&"message_text"), tr("UI_BENCH_SUBMIT_REFUSED"))

	# 7. NETWORK -> UI_BENCH_SUBMIT_NET_FAILED, Retry + GitHub + Close; GitHub button runs fork route.
	reply["code"] = 0
	reply["body"] = ""
	modal.call(&"open", group, "", Game.content().content_hash)
	(modal.call(&"send_button") as ConsoleButton).pressed.emit()
	assert_eq(modal.call(&"message_text"), tr("UI_BENCH_SUBMIT_NET_FAILED"))
	assert_true((modal.call(&"retry_button") as ConsoleButton).visible)
	(modal.call(&"github_button") as ConsoleButton).pressed.emit()
	assert_eq(_shell.size(), 2)
	assert_eq(modal.call(&"message_text"), tr("UI_BENCH_SUBMIT_STEPS").format({"count": 3}))


func test_group_row_shows_sent_not_listed_and_listed_states() -> void:
	_record_suite()
	var group: BenchGroup = _own_group()
	var sub: BenchSubmission = BenchSubmission.from_group(group, BenchJobs.config())
	BenchSubmitLog.load_log().record(sub, 55, "2026-09-28")

	var list: Control = _list()
	assert_eq(_buttons(list, "UI_BENCH_SUBMIT").size(), 0)
	assert_true(_texts(list).has(tr("UI_BENCH_GROUP_SENT").format({"date": "2026-09-28"})))

	# Board generated 2 days later without the group's hashes -> Not listed + GitHub button.
	var board_later: GlobalBoard = GlobalBoard.parse(JSON.stringify({
		"version": 1,
		"generated": "2026-09-30T03:23:00Z",
		"content_hash": Game.content().content_hash,
		"rows": [],
	}), BenchJobs.config())
	(list.call(&"client") as GlobalBoardClient).board_changed.emit(board_later,
		GlobalBoardClient.SOURCE_ONLINE, false)
	assert_true(_texts(list).has(tr("UI_BENCH_GROUP_NOT_LISTED").format({"date": "2026-09-28"})))
	assert_eq(_buttons(list, "UI_BENCH_SUBMIT_GITHUB").size(), 1)

	# Board with all 3 file hashes -> Listed, no button.
	var seeds: Array[Dictionary] = []
	for i: int in sub.file_sha.size():
		seeds.append({
			"seed": 1001 + i,
			"file": "runs/f%d.json" % i,
			"sha256": sub.file_sha[i],
			"outcome": "win_merge",
			"days": 400,
			"score": 80.0,
		})
	var board_listed: GlobalBoard = GlobalBoard.parse(JSON.stringify({
		"version": 1,
		"generated": "2026-09-30T03:23:00Z",
		"content_hash": Game.content().content_hash,
		"rows": [{
			"model": MODEL,
			"params_id": "00000000",
			"suite": BenchConfig.SUITE_QUICK,
			"content_hash": Game.content().content_hash,
			"complete": true,
			"runs": 3,
			"of": 3,
			"wins": 3,
			"score": 80.0,
			"seeds": seeds,
		}],
	}), BenchJobs.config())
	(list.call(&"client") as GlobalBoardClient).board_changed.emit(board_listed,
		GlobalBoardClient.SOURCE_ONLINE, false)
	assert_true(_texts(list).has(tr("UI_BENCH_GROUP_LISTED")))
	assert_eq(_buttons(list, "UI_BENCH_SUBMIT_GITHUB").size(), 0)
	assert_eq(_buttons(list, "UI_BENCH_SUBMIT").size(), 0)
