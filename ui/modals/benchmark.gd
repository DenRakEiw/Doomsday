extends Control
## The *Benchmark* list (spec benchmark.md §12.7, §16.6): the global leaderboard
## first — fetched only now, when the list opens, and only with the *Online
## leaderboard* setting on — then the recorded runs this game found on disk.
## The board has two tabs (2026-09-28, user): *AI models* (on open) and
## *Built-in bots*. Each shows its rows of the quick suite first — the suite
## every model plays — then of the standard suite, each ranked on its own, since
## the two scores do not compare (S6.12e); then its rows of other versions.
## Within a section the best score comes first (2026-09-28, user).
## Every run with a *Watch* button replays in the session. Every row says the
## model's effort level (§18); bots and decision models show the dash.
##
## Model names are data from outside: they go into plain `Label`s, never into
## rich text.
##
## On a desktop build (§19.1) the list also starts the player's own benchmark
## (§19.8), shows it while it runs or since it ended (§19.9.1), and offers each
## complete one of the player's own for *Submit* (§19.9.3).
##
## Scene-specific, so no `class_name`.

signal closed
## §19.8: *Run your own benchmark* — the host opens the benchmark modal.
signal run_requested
## §19.9.3: *Submit* on a group; `board_hash` is the known global board's
## content ("" when no board is known).
signal submit_requested(group: BenchGroup, board_hash: String)

const KEY_TITLE: String = "UI_BENCH_TITLE"
const KEY_INTRO: String = "UI_BENCH_INTRO"
const KEY_ROW: String = "UI_BENCH_ROW"
const KEY_WATCH: String = "UI_BENCH_WATCH"
const KEY_OTHER_VERSION: String = "UI_BENCH_OTHER_VERSION"
const KEY_BOT: String = "UI_BENCH_BOT"
const KEY_SKIPPED: String = "UI_BENCH_SKIPPED"
const KEY_LOCAL_TITLE: String = "UI_BENCH_LOCAL_TITLE"
const KEY_GLOBAL_TITLE: String = "UI_BENCH_GLOBAL_TITLE"
const KEY_GLOBAL_NOTE: String = "UI_BENCH_GLOBAL_NOTE"
const KEY_GLOBAL_LOADING: String = "UI_BENCH_GLOBAL_LOADING"
const KEY_GLOBAL_AS_OF: String = "UI_BENCH_GLOBAL_AS_OF"
const KEY_GLOBAL_OFFLINE: String = "UI_BENCH_GLOBAL_OFFLINE"
const KEY_GLOBAL_DISABLED: String = "UI_BENCH_GLOBAL_DISABLED"
const KEY_GLOBAL_UNAVAILABLE: String = "UI_BENCH_GLOBAL_UNAVAILABLE"
const KEY_GLOBAL_EMPTY: String = "UI_BENCH_GLOBAL_EMPTY"
const KEY_GLOBAL_ROW: String = "UI_BENCH_GLOBAL_ROW"
const KEY_GLOBAL_PARTIAL: String = "UI_BENCH_GLOBAL_PARTIAL"
const KEY_GLOBAL_OTHER_TITLE: String = "UI_BENCH_GLOBAL_OTHER_TITLE"
const KEY_GLOBAL_QUICK_TITLE: String = "UI_BENCH_GLOBAL_QUICK_TITLE"
const KEY_GLOBAL_QUICK_NOTE: String = "UI_BENCH_GLOBAL_QUICK_NOTE"
const KEY_GLOBAL_STANDARD_TITLE: String = "UI_BENCH_GLOBAL_STANDARD_TITLE"
const KEY_TAB_MODELS: String = "UI_BENCH_TAB_MODELS"
const KEY_TAB_BOTS: String = "UI_BENCH_TAB_BOTS"
const TAB_MODELS: String = "models"
const TAB_BOTS: String = "bots"
const KEY_GLOBAL_RUNS: String = "UI_BENCH_GLOBAL_RUNS"
const KEY_GLOBAL_HIDE: String = "UI_BENCH_GLOBAL_HIDE"
const KEY_GLOBAL_DOWNLOADING: String = "UI_BENCH_GLOBAL_DOWNLOADING"
const KEY_SEED: String = "UI_SPECTATOR_SEED"
const KEY_RUN_OPEN: String = "UI_BENCH_RUN_OPEN"
const KEY_GROUP_ROW: String = "UI_BENCH_GROUP_ROW"
const KEY_SUBMIT: String = "UI_BENCH_SUBMIT"
const PREFIX_GLOBAL_FAIL: String = "UI_BENCH_GLOBAL_FAIL_"
const PREFIX_CMD_FAIL: String = "CMD_FAIL_"
const PREFIX_OUTCOME: String = "UI_OUTCOME_"
## The keys this list builds at run time, for the strings check (§16.7).
const KEYS: Array[String] = ["UI_BENCH_GLOBAL_FAIL_OFFLINE", "UI_BENCH_GLOBAL_FAIL_CHANGED",
	"UI_BENCH_GLOBAL_FAIL_UNREADABLE", "UI_BENCH_GLOBAL_FAIL_OFF", "CMD_FAIL_BENCH_CONTENT",
	"CMD_FAIL_SETUP_INVALID", "CMD_FAIL_SPECTATING", "UI_OUTCOME_TIMEOUT"]
## §16.9: a debug build may read the board from a file in place of the network.
const ARG_GLOBAL_BOARD: String = "--global-board="
# DESIGN? §16.7's `{date}` is the start of `generated`; the public file says
# nothing there until the verifier first publishes, and the line needs a date.
const DATE_UNKNOWN: String = "—"
const SEPARATOR: String = " "

@onready var _panel: PanelContainer = %BenchPanel
@onready var _title: Label = %BenchTitle
@onready var _close: IconButton = %CloseButton
@onready var _scroll: ScrollContainer = %BenchScroll
@onready var _list: VBoxContainer = %BenchList
@onready var _client: GlobalBoardClient = %BoardClient

## The status line's text as it stands, for the tests.
var status_text: String = ""
## The board's tab on show: `TAB_MODELS` or `TAB_BOTS`. Kept while the game runs.
var tab: String = TAB_MODELS

var _library: BenchLibrary = null
var _board: GlobalBoard = null
var _source: String = GlobalBoardClient.SOURCE_NONE
var _loading: bool = false
## The status the live region last spoke; the first one is not spoken.
var _spoken_status: String = ""
var _has_spoken: bool = false

var _status: Label = null
var _note: Label = null
var _global_rows: VBoxContainer = null
var _tab_row: HFlowContainer = null
var _tab_group: ButtonGroup = ButtonGroup.new()
var _tab_buttons: Dictionary[String, ConsoleButton] = {}
var _standard_title: CapsLabel = null
var _quick_title: CapsLabel = null
var _quick_note: Label = null
var _quick_rows: VBoxContainer = null
var _other_title: CapsLabel = null
var _other_rows: VBoxContainer = null
var _local_box: VBoxContainer = null
var _live: LiveRegion = null
## Every `BoxContainer` that lays a text and its button side by side (compact:
## one above the other).
var _pairs: Array[BoxContainer] = []
## The *Watch* buttons of the global runs, disabled while one downloads.
var _run_buttons: Array[ConsoleButton] = []
## The run being downloaded, and the caption under it.
var _pending_caption: Label = null
var _job: BenchJobView = null
## The recorded runs the list last read, by finished seeds of the running
## benchmark: a finished seed is a new file to show.
var _finished_seen: int = -1

## §19.9.1: the ended benchmark the list has shown once — it is not shown again.
static var _acknowledged: BenchJobState = null
## The ended benchmark this opening shows; it stays for the opening.
var _showing: BenchJobState = null


func _ready() -> void:
	A11y.focus_scroll(_scroll)
	# accessibility.md §3.4: the live region sits on the root, out of the list's
	# layout and never rebuilt, like the HUD's.
	_live = LiveRegion.new()
	_live.name = "GlobalLive"
	add_child(_live)
	_close.pressed.connect(closed.emit)
	_client.board_changed.connect(_on_client_board_changed)
	_client.run_ready.connect(_on_client_run_ready)
	BenchJobs.changed.connect(_on_bench_jobs_changed)
	if Game.debug_allowed:
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with(ARG_GLOBAL_BOARD):
				_client.local_board_path = arg.trim_prefix(ARG_GLOBAL_BOARD)
	visibility_changed.connect(_on_visibility_changed)
	get_viewport().size_changed.connect(_fit)
	_fit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and visible:
		_rebuild()


## The title's question (§16.6): does the list have anything to show — a
## recorded run, the online setting on, or a board on disk with a row? Files
## only; never the network.
func has_anything() -> bool:
	if Settings.bench_online:
		return true
	if not BenchLibrary.scan(Game.debug_allowed).entries.is_empty():
		return true
	var local: GlobalBoard = _client.local_board()
	return local != null and not local.rows.is_empty()


## Opens the list: the recorded runs read fresh, the board from disk at once and
## — with the setting on — fetched.
func open() -> void:
	_library = BenchLibrary.scan(Game.debug_allowed)
	_finished_seen = _finished_runs()
	_showing = null
	_board = null
	_source = GlobalBoardClient.SOURCE_NONE
	_loading = false
	_has_spoken = false
	# The board first — what is on disk arrives at once — so the list is built
	# once with it and the status it opens on is not spoken as a change.
	_status = null
	_client.open_board(Settings.bench_online)
	visible = true
	_rebuild()
	_fit()


func on_escape() -> void:
	closed.emit()


## The client, for the tests.
func client() -> GlobalBoardClient:
	return _client


# ------------------------------------------------------------------ building


func _rebuild() -> void:
	_title.text = tr(KEY_TITLE)
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_pairs.clear()
	_run_buttons.clear()
	_pending_caption = null
	_caption(_list, tr(KEY_INTRO))
	_build_own()
	_build_global()
	_build_local()
	_apply_compact()


## §19.8, §19.9.1: the button to the benchmark modal and, while one runs or
## since it ended, the player's benchmark.
func _build_own() -> void:
	if not has_own_benchmark():
		_job = null
		return
	var open_button: ConsoleButton = ConsoleButton.new()
	open_button.name = "RunOpen"
	open_button.label_key = KEY_RUN_OPEN
	open_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	open_button.pressed.connect(run_requested.emit)
	_list.add_child(open_button)
	_job = BenchJobView.new()
	_job.name = "JobSection"
	_job.live = _live
	_list.add_child(_job)
	_show_job()


## §19.1: only a desktop build runs a benchmark of its own; a debug build's
## `--bench-mock` too.
static func has_own_benchmark() -> bool:
	return BenchKeyStore.is_supported() or BenchJobs.mock


## The job section, for the tests.
func job_section() -> BenchJobView:
	return _job


## §19.9.1: while it runs, or once after it ended.
func _show_job() -> void:
	if _job == null or not is_instance_valid(_job):
		return
	var state: BenchJobState = BenchJobs.state()
	_job.refresh()
	_job.visible = state != null and (state.is_running() or state != _acknowledged
		or state == _showing)
	if _job.visible and not state.is_running():
		_acknowledged = state
		_showing = state


func _finished_runs() -> int:
	var state: BenchJobState = BenchJobs.state()
	return -1 if state == null else state.finished_runs()


## A finished seed is a new recorded run: the list reads them again.
func _on_bench_jobs_changed() -> void:
	if not visible:
		return
	var finished: int = _finished_runs()
	if finished != _finished_seen:
		_finished_seen = finished
		_library = BenchLibrary.scan(Game.debug_allowed)
		_rebuild()
		return
	_show_job()


func _build_global() -> void:
	var box: VBoxContainer = _section(KEY_GLOBAL_TITLE)
	_status = _caption(box, "")
	_status.name = "GlobalStatus"
	_note = _caption(box, tr(KEY_GLOBAL_NOTE))
	_tab_row = HFlowContainer.new()
	_tab_row.name = "BoardTabs"
	box.add_child(_tab_row)
	_tab_group = ButtonGroup.new()
	_tab_buttons.clear()
	for id: String in [TAB_MODELS, TAB_BOTS]:
		var button: ConsoleButton = ConsoleButton.new()
		button.toggle_mode = true
		button.button_group = _tab_group
		button.compact = true
		button.label_key = KEY_TAB_MODELS if id == TAB_MODELS else KEY_TAB_BOTS
		button.pressed.connect(show_tab.bind(id))
		_tab_row.add_child(button)
		_tab_buttons[id] = button
	ToggleGroup.press(_tab_buttons[tab])
	_quick_title = CapsLabel.new()
	_quick_title.label_key = KEY_GLOBAL_QUICK_TITLE
	box.add_child(_quick_title)
	_quick_note = _caption(box, tr(KEY_GLOBAL_QUICK_NOTE))
	_quick_rows = VBoxContainer.new()
	_quick_rows.name = "QuickRows"
	_quick_rows.theme_type_variation = &"StackTight"
	box.add_child(_quick_rows)
	_standard_title = CapsLabel.new()
	_standard_title.label_key = KEY_GLOBAL_STANDARD_TITLE
	box.add_child(_standard_title)
	_global_rows = VBoxContainer.new()
	_global_rows.name = "GlobalRows"
	_global_rows.theme_type_variation = &"StackTight"
	box.add_child(_global_rows)
	_other_title = CapsLabel.new()
	_other_title.label_key = KEY_GLOBAL_OTHER_TITLE
	box.add_child(_other_title)
	_other_rows = VBoxContainer.new()
	_other_rows.name = "OtherRows"
	_other_rows.theme_type_variation = &"StackTight"
	box.add_child(_other_rows)
	_render_board()


func _build_local() -> void:
	if _library == null or (_library.entries.is_empty() and _library.skipped == 0):
		_local_box = null
		return
	_local_box = _section(KEY_LOCAL_TITLE)
	_local_box.name = "LocalRuns"
	var content_hash: String = _content_hash()
	if has_own_benchmark():
		for group: BenchGroup in BenchGroup.own_groups(_library, BenchLibrary.user_dir,
				content_hash, BenchJobs.config()):
			_add_group_row(group)
	var order: Array[int] = []
	for i: int in _library.entries.size():
		order.append(i)
	var entries: Array[BenchEntry] = _library.entries
	order.sort_custom(func(a: int, b: int) -> bool:
		return _local_before(entries[a], entries[b], content_hash))
	for i: int in order:
		_add_local_row(entries[i], content_hash)
	if _library.skipped > 0:
		_caption(_local_box, tr(KEY_SKIPPED).format({"count": _library.skipped}))


## §12.7: current content first, then score (best first), model, seed.
static func _local_before(a: BenchEntry, b: BenchEntry, content_hash: String) -> bool:
	var a_current: bool = a.content_hash == content_hash
	var b_current: bool = b.content_hash == content_hash
	if a_current != b_current:
		return a_current
	if a.score != b.score:
		return a.score > b.score
	if a.model != b.model:
		return a.model < b.model
	return a.seed_value < b.seed_value


## §19.9.3: one of the player's complete benchmarks, above the single runs.
func _add_group_row(group: BenchGroup) -> void:
	var lines: VBoxContainer = _lines()
	_model_label(lines, group.model)
	_caption(lines, tr(KEY_GROUP_ROW).format({"score": Format.decimal(group.score, 1),
		"wins": group.wins, "runs": group.runs}))
	_caption(lines, BenchEffort.line(group.effort))
	var submit: ConsoleButton = ConsoleButton.new()
	submit.label_key = KEY_SUBMIT
	submit.compact = true
	submit.name = "Submit"
	_pair(_local_box, lines, submit)
	submit.pressed.connect(_on_submit_pressed.bind(group))
	_name_toggle(submit, group.model)


func _on_submit_pressed(group: BenchGroup) -> void:
	submit_requested.emit(group, "" if _board == null else _board.content_hash)


func _add_local_row(entry: BenchEntry, content_hash: String) -> void:
	var lines: VBoxContainer = _lines()
	_model_label(lines, entry.model)
	_caption(lines, _row_text(entry.seed_value, entry.outcome, entry.days, entry.score))
	_caption(lines, BenchEffort.line(BenchEffort.of_entry(entry)))
	var current: bool = entry.content_hash == content_hash
	if not current:
		_caption(lines, tr(KEY_OTHER_VERSION))
	var watch: ConsoleButton = _watch_button(entry.model, entry.seed_value)
	watch.disabled = not current
	var row: VBoxContainer = _pair(_local_box, lines, watch)
	var failure: Label = _caption(row, "")
	failure.theme_type_variation = &"LabelCaptionAlert"
	failure.visible = false
	watch.pressed.connect(_on_local_watch_pressed.bind(entry, failure))


# ---------------------------------------------------------------- the board


## §16.7: the status line, and the rows of the board on show.
func _render_board() -> void:
	if _status == null or not is_instance_valid(_status):
		return
	status_text = _status_line()
	_status.text = status_text
	if _has_spoken and status_text != _spoken_status:
		_live.say(status_text)
	_spoken_status = status_text
	_has_spoken = true
	for box: VBoxContainer in [_global_rows, _quick_rows, _other_rows]:
		for child: Node in box.get_children():
			box.remove_child(child)
			child.queue_free()
	var kept: Array[BoxContainer] = []
	for pair: BoxContainer in _pairs:
		if is_instance_valid(pair) and pair.is_inside_tree() and not pair.is_queued_for_deletion():
			kept.append(pair)
	_pairs = kept
	_run_buttons.clear()
	_pending_caption = null
	# Ranks count per tab and section and, among other versions, per suite: a
	# quick score never ranks against a standard one, a model never against a bot.
	var current: int = 0
	var quick: int = 0
	var other: int = 0
	var other_quick: int = 0
	var content_hash: String = _content_hash()
	var bots: bool = tab == TAB_BOTS
	if _board != null:
		for row: GlobalBoardRow in _by_score(_board.rows):
			if row.is_bot() != bots:
				continue
			if row.content_hash != content_hash:
				if row.is_quick():
					other_quick += 1
					_add_other_row(row, other_quick)
				else:
					other += 1
					_add_other_row(row, other)
			elif row.is_quick():
				quick += 1
				_add_global_row(_quick_rows, row, quick)
			else:
				current += 1
				_add_global_row(_global_rows, row, current)
		if current + quick + other + other_quick == 0:
			_caption(_quick_rows, tr(KEY_GLOBAL_EMPTY))
	var any: bool = _board != null and not _board.rows.is_empty()
	_note.visible = any
	_tab_row.visible = any
	_quick_title.visible = quick > 0
	_quick_note.visible = quick > 0
	_standard_title.visible = current > 0
	_other_title.visible = other + other_quick > 0
	_apply_compact()


## Best score first (2026-09-28, user) — an incomplete row too, which the file
## (§10.3) puts after the complete ones; ties keep the file's order.
static func _by_score(rows: Array[GlobalBoardRow]) -> Array[GlobalBoardRow]:
	var order: Array[int] = []
	for i: int in rows.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		if rows[a].score != rows[b].score:
			return rows[a].score > rows[b].score
		return a < b)
	var out: Array[GlobalBoardRow] = []
	for i: int in order:
		out.append(rows[i])
	return out


## Shows the board's `id` tab (`TAB_MODELS` or `TAB_BOTS`).
func show_tab(id: String) -> void:
	tab = id
	if _tab_buttons.has(id):
		ToggleGroup.press(_tab_buttons[id])
	_render_board()


func _status_line() -> String:
	if _loading:
		return tr(KEY_GLOBAL_LOADING)
	if _board == null:
		return tr(KEY_GLOBAL_UNAVAILABLE)
	var date: String = _board.date()
	var args: Dictionary = {"date": date if not date.is_empty() else DATE_UNKNOWN}
	if _source == GlobalBoardClient.SOURCE_ONLINE:
		return tr(KEY_GLOBAL_AS_OF).format(args)
	return tr(KEY_GLOBAL_OFFLINE if Settings.bench_online else KEY_GLOBAL_DISABLED).format(args)


func _add_global_row(into: VBoxContainer, row: GlobalBoardRow, rank: int) -> void:
	var lines: VBoxContainer = _lines()
	_model_label(lines, row.model)
	_caption(lines, _global_row_text(row, rank))
	_caption(lines, BenchEffort.line(row.effort))
	if not row.complete:
		_caption(lines, tr(KEY_GLOBAL_PARTIAL).format({"runs": row.runs, "of": row.of}))
	var toggle: ConsoleButton = ConsoleButton.new()
	toggle.label_key = KEY_GLOBAL_RUNS
	toggle.compact = true
	var box: VBoxContainer = _pair(into, lines, toggle)
	var runs: VBoxContainer = VBoxContainer.new()
	runs.theme_type_variation = &"StackTight"
	runs.visible = false
	box.add_child(runs)
	for run: GlobalBoardRun in row.seeds:
		_add_run(runs, row, run)
	toggle.pressed.connect(_on_runs_toggled.bind(toggle, runs, row.model))
	_name_toggle(toggle, row.model)


## §16.6 item 4: no *Runs* button — they cannot be replayed here. A quick-suite
## row says so, since it ranks among its own suite only.
func _add_other_row(row: GlobalBoardRow, rank: int) -> void:
	var lines: VBoxContainer = _lines()
	_model_label(lines, row.model)
	_caption(lines, _global_row_text(row, rank))
	if row.is_quick():
		_caption(lines, tr(KEY_GLOBAL_QUICK_TITLE))
	_caption(lines, BenchEffort.line(row.effort))
	_caption(lines, tr(KEY_OTHER_VERSION))
	_other_rows.add_child(lines)


func _add_run(into: VBoxContainer, row: GlobalBoardRow, run: GlobalBoardRun) -> void:
	var lines: VBoxContainer = _lines()
	_caption(lines, _row_text(run.seed_value, run.outcome, run.days, run.score))
	var watch: ConsoleButton = _watch_button(row.model, run.seed_value)
	var box: VBoxContainer = _pair(into, lines, watch)
	var caption: Label = _caption(box, "")
	caption.visible = false
	watch.pressed.connect(_on_run_watch_pressed.bind(run, caption))
	_run_buttons.append(watch)


func _global_row_text(row: GlobalBoardRow, rank: int) -> String:
	return tr(KEY_GLOBAL_ROW).format({
		"rank": rank,
		"score": Format.decimal(row.score, 1),
		"wins": row.wins,
		"runs": row.runs,
	})


# ------------------------------------------------------------------ actions


func _on_client_board_changed(board: GlobalBoard, source: String, loading: bool) -> void:
	_board = board
	_source = source
	_loading = loading
	if visible:
		_render_board()


func _on_runs_toggled(toggle: ConsoleButton, runs: VBoxContainer, model: String) -> void:
	runs.visible = not runs.visible
	toggle.label_key = KEY_GLOBAL_HIDE if runs.visible else KEY_GLOBAL_RUNS
	_name_toggle(toggle, model)


func _on_local_watch_pressed(entry: BenchEntry, failure: Label) -> void:
	var reason: String = ScreenRouter.start_spectating(entry)
	if reason.is_empty():
		closed.emit()
		return
	failure.text = tr(PREFIX_CMD_FAIL + reason.to_upper())
	failure.visible = true


## §16.6: one download at a time; the others wait with their buttons off.
func _on_run_watch_pressed(run: GlobalBoardRun, caption: Label) -> void:
	if _client.is_downloading():
		return
	for button: ConsoleButton in _run_buttons:
		button.disabled = true
	_pending_caption = caption
	caption.theme_type_variation = &"LabelCaption"
	caption.text = tr(KEY_GLOBAL_DOWNLOADING)
	caption.visible = true
	_client.download_run(run, Settings.bench_online)


func _on_client_run_ready(entry: BenchEntry, reason: String) -> void:
	for button: ConsoleButton in _run_buttons:
		button.disabled = false
	var caption: Label = _pending_caption
	_pending_caption = null
	if caption == null or not is_instance_valid(caption):
		return
	if not reason.is_empty():
		_fail(caption, PREFIX_GLOBAL_FAIL + reason.to_upper())
		return
	var blocker: String = ScreenRouter.start_spectating(entry)
	if blocker.is_empty():
		closed.emit()
		return
	_fail(caption, PREFIX_CMD_FAIL + blocker.to_upper())


func _fail(caption: Label, key: String) -> void:
	caption.theme_type_variation = &"LabelCaptionAlert"
	caption.text = tr(key)
	caption.visible = true


## Closing the list stops whatever it is downloading (§16.6 item 5).
func _on_visibility_changed() -> void:
	if not visible:
		_client.cancel()


# ------------------------------------------------------------------- pieces


func _section(key: String) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.theme_type_variation = &"StackTight"
	_list.add_child(box)
	var heading: CapsLabel = CapsLabel.new()
	heading.label_key = key
	box.add_child(heading)
	return box


func _lines() -> VBoxContainer:
	var lines: VBoxContainer = VBoxContainer.new()
	lines.theme_type_variation = &"StackLines"
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lines


## A text and its button, side by side (one above the other in compact), in a
## box that can take a caption under both.
func _pair(into: Container, lines: Control, button: ConsoleButton) -> VBoxContainer:
	var outer: VBoxContainer = VBoxContainer.new()
	outer.theme_type_variation = &"StackTight"
	into.add_child(outer)
	var pair: BoxContainer = BoxContainer.new()
	pair.theme_type_variation = &"Row"
	outer.add_child(pair)
	pair.add_child(lines)
	button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	pair.add_child(button)
	_pairs.append(pair)
	return outer


## The model as it was submitted — a bot's reference row says it is one.
func _model_label(into: Container, model: String) -> void:
	var label: Label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	if model.begins_with(BenchEntry.MODEL_BOT_PREFIX):
		label.text = tr(KEY_BOT).format({"policy": model.trim_prefix(BenchEntry.MODEL_BOT_PREFIX)})
	else:
		label.text = model
	into.add_child(label)


func _watch_button(model: String, seed_value: int) -> ConsoleButton:
	var button: ConsoleButton = ConsoleButton.new()
	button.label_key = KEY_WATCH
	button.compact = true
	button.set_meta(&"a11y_value", model + SEPARATOR
		+ tr(KEY_SEED).format({"seed": seed_value}))
	button.ready.connect(_name_watch.bind(button), CONNECT_ONE_SHOT)
	return button


## accessibility.md §3.3: *Watch* says whose run and which seed. After the
## button's `_ready`, which names it after its label.
func _name_watch(button: ConsoleButton) -> void:
	button.accessibility_name = A11y.label_value(tr(KEY_WATCH),
		str(button.get_meta(&"a11y_value")))


func _name_toggle(toggle: ConsoleButton, model: String) -> void:
	if toggle.is_node_ready():
		toggle.accessibility_name = A11y.label_value(tr(toggle.label_key), model)
	else:
		toggle.ready.connect(_name_toggle.bind(toggle, model), CONNECT_ONE_SHOT)


func _row_text(seed_value: int, outcome: String, days: int, score: float) -> String:
	return tr(KEY_ROW).format({
		"seed": seed_value,
		"outcome": tr(PREFIX_OUTCOME + outcome.to_upper()),
		"days": Format.number(float(days), Format.Kind.DAYS),
		"score": Format.decimal(score, 1),
	})


static func _caption(into: Container, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = &"LabelCaption"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	into.add_child(label)
	return label


func _content_hash() -> String:
	var db: ContentDB = Game.content()
	return "" if db == null else db.content_hash


# ------------------------------------------------------------------- layout


func _fit() -> void:
	var view: Vector2 = get_viewport_rect().size
	_panel.custom_minimum_size.y = maxf(view.y - float(UiTokens.SPACE_6) * 2.0, 0.0)
	_apply_compact()


## §12.7: in compact the buttons drop under their text.
func _apply_compact() -> void:
	var compact: bool = get_viewport_rect().size.x < float(UiTokens.COMPACT_WIDTH)
	for pair: BoxContainer in _pairs:
		if is_instance_valid(pair):
			pair.vertical = compact
			var button: Control = pair.get_child(pair.get_child_count() - 1) as Control
			button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if compact \
				else Control.SIZE_SHRINK_END
