extends Control
## Your own benchmark (docs/specs/benchmark.md §19.8): pick one of OpenRouter's
## models, an effort and a cost cap, and start — or, while one runs, watch it.
##
## Three states, top to bottom: no key yet (a button to the key dialog, nothing
## else enabled); a benchmark running (its progress, §19.9.1); the picker. The
## rules — which models, which order, which efforts, what it likely costs — are
## `BenchPicker`'s; this draws them. OpenRouter's public list is asked for
## without the key when the modal opens (an `HTTPRequest`, like the global
## board's) and kept for `player.models_max_age_s` (`ModelListCache`).
##
## Model names and ids are data from outside: plain `Label`s only.
##
## Opened over the Benchmark list with `ModalHost.open_over`. Scene-specific,
## so no `class_name`.

signal closed
## *Set key*: the host swaps this modal for the key dialog and back.
signal key_requested

const KEY_TITLE: String = "UI_BENCH_RUN_TITLE"
const KEY_INTRO: String = "UI_BENCH_RUN_INTRO"
const KEY_NO_KEY: String = "UI_BENCH_RUN_NO_KEY"
const KEY_SET: String = "UI_KEY_SET"
const KEY_CHECKING: String = "UI_KEY_CHECKING"
const KEY_SEARCH: String = "UI_BENCH_RUN_SEARCH"
const KEY_FREE_ONLY: String = "UI_BENCH_RUN_FREE_ONLY"
const KEY_LOADING: String = "UI_BENCH_RUN_LOADING"
const KEY_LIST_FAILED: String = "UI_BENCH_RUN_LIST_FAILED"
const KEY_PRICE: String = "UI_BENCH_RUN_PRICE"
const KEY_FREE: String = "UI_BENCH_RUN_FREE"
const KEY_REASONING: String = "UI_BENCH_RUN_REASONING"
const KEY_CHOOSE: String = "UI_BENCH_RUN_CHOOSE"
const KEY_NO_MATCH: String = "UI_BENCH_RUN_NO_MATCH"
const KEY_EFFORT: String = "UI_BENCH_RUN_EFFORT"
const KEY_NO_REASONING: String = "UI_BENCH_RUN_NO_REASONING"
const KEY_DEFAULT_REASONING: String = "UI_BENCH_RUN_DEFAULT_REASONING"
const KEY_ESTIMATE: String = "UI_BENCH_RUN_ESTIMATE"
const KEY_ESTIMATE_UNKNOWN: String = "UI_BENCH_RUN_ESTIMATE_UNKNOWN"
const KEY_FREE_NOTE: String = "UI_BENCH_RUN_FREE_NOTE"
const KEY_CAP: String = "UI_BENCH_RUN_CAP"
const KEY_CAP_VALUE: String = "UI_BENCH_RUN_CAP_VALUE"
const KEY_OVER_CAP: String = "UI_BENCH_RUN_OVER_CAP"
const KEY_TIME_NOTE: String = "UI_BENCH_RUN_TIME_NOTE"
const KEY_PRIVACY: String = "UI_BENCH_RUN_PRIVACY"
const KEY_START: String = "UI_BENCH_RUN_START"
const KEY_CONFIRM: String = "UI_BENCH_RUN_CONFIRM"
const KEY_START_BUSY: String = "UI_BENCH_RUN_START_BUSY"
const KEY_START_FAILED: String = "UI_BENCH_RUN_START_FAILED"
const KEY_CLOSE: String = "UI_COMMON_CLOSE"
const KEY_LABEL_VALUE: String = "UI_A11Y_LABEL_VALUE"
## `start`'s answer when the player said *Cancel*.
const REASON_CANCELLED: String = "cancelled"
const USD_DECIMALS: int = 2
const TOKENS_PER_MILLION: float = 1_000_000.0
## The dash for a price the list does not give.
const UNKNOWN_MARK: String = "—"
const CONFIRM_SCENE: PackedScene = preload("res://ui/modals/confirm_modal.tscn")

## Test seams: `list_fetcher() -> String` answers the body of OpenRouter's list
## in place of the network; `clock() -> int` the time in Unix seconds.
var list_fetcher: Callable = Callable()
var clock: Callable = Callable()
## Where the list is kept; the suite points it at a folder of its own.
var cache: ModelListCache = ModelListCache.new()

## What the picker shows, for the tests.
var rows_shown: Array[Dictionary] = []
var chosen_id: String = ""
var effort: String = BenchEffort.NORMAL
var cap_usd: float = 0.0
var search_text: String = ""
var free_only: bool = false

## The token measures of the estimate, per content: they take a moment.
static var _tokens: Dictionary = {}
static var _tokens_hash: String = ""

var _config: BenchConfig = null
var _candidates: Array[Dictionary] = []
var _loading: bool = false
var _failed: bool = false
var _request: HTTPRequest = null
## The benchmark this modal showed running keeps showing — its end included —
## until the modal opens again.
var _holding_job: bool = false

var _panel: ModalPanel = null
var _title: Label = null
var _close: IconButton = null
var _scroll: ScrollContainer = null
var _intro: Label = null
var _no_key_box: VBoxContainer = null
var _no_key: Label = null
var _set_key: ConsoleButton = null
var _job: BenchJobView = null
var _picker: VBoxContainer = null
var _search: LineEdit = null
var _free_toggle: ConsoleButton = null
var _list_status: Label = null
var _rows: VBoxContainer = null
var _choose_group: ButtonGroup = ButtonGroup.new()
var _effort_title: CapsLabel = null
var _effort_group: ButtonGroup = ButtonGroup.new()
var _effort_buttons: Dictionary[String, ConsoleButton] = {}
var _effort_note: Label = null
var _estimate: Label = null
var _cap_title: CapsLabel = null
var _cap_row: HFlowContainer = null
var _cap_group: ButtonGroup = ButtonGroup.new()
var _cap_buttons: Array[ConsoleButton] = []
var _over_cap: Label = null
var _time_note: Label = null
var _privacy: Label = null
var _start: ConsoleButton = null
var _start_failure: Label = null
var _confirm: ConfirmModal = null
var _live: LiveRegion = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_config = BenchJobs.config()
	_build()
	BenchJobs.changed.connect(_refresh_sections)
	BenchJobs.key_changed.connect(_refresh_sections)
	get_viewport().size_changed.connect(_fit)
	visible = false


func _notification(what: int) -> void:
	# `ModalHost` moves a modal into its slot when it first opens; leaving the
	# tree cancels the list's request, so it is asked again on the way back in.
	if what == NOTIFICATION_ENTER_TREE and _loading and _request != null:
		_request_list.call_deferred()
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and visible:
		_refresh_strings()
		_render_rows()
		_refresh_choice()


## Opens on the state `BenchJobs` is in: the key looked up when it is not known
## yet, the list read from the cache and — when older than a day — fetched.
func open() -> void:
	visible = true
	_start_failure.visible = false
	var state: BenchJobState = BenchJobs.state()
	_holding_job = state != null and state.is_running()
	cap_usd = BenchPicker.cap_for(Settings.bench_cap_usd, _config)
	if BenchJobs.key_status == BenchJobs.KEY_UNKNOWN and not BenchJobs.mock:
		BenchJobs.refresh_key()
	_measure()
	_open_list()
	_refresh_strings()
	_refresh_sections()
	_render_rows()
	_refresh_choice()
	_fit()


func on_escape() -> void:
	if _confirm.visible:
		_confirm.on_escape()
		return
	closed.emit()


## What stands in the list's status line ("" when the list shows), the start
## button and its confirmation — for the tests.
func list_status() -> String:
	return _list_status.text if _list_status.visible else ""


func start_button() -> ConsoleButton:
	return _start


func start_failure_text() -> String:
	return _start_failure.text if _start_failure.visible else ""


func confirm_modal() -> ConfirmModal:
	return _confirm


func estimate_text() -> String:
	return _estimate.text if _estimate.visible else ""


func effort_note() -> String:
	return _effort_note.text if _effort_note.visible else ""


func is_over_cap() -> bool:
	return _over_cap.visible


func effort_button(level: String) -> ConsoleButton:
	return _effort_buttons.get(level)


func set_key_button() -> ConsoleButton:
	return _set_key


## Which of the three states shows: "no_key", "job" or "picker".
func section() -> String:
	if _no_key_box.visible:
		return "no_key"
	return "job" if _job.visible else "picker"


## The search, as if typed.
func set_search(text: String) -> void:
	_search.text = text
	_on_search_changed(text)


func set_free_only(on: bool) -> void:
	_free_toggle.set_pressed_no_signal(on)
	_on_free_toggled(on)


## Chooses the model `id` among the rows shown.
func choose(id: String) -> void:
	for row: Dictionary in rows_shown:
		if str(row[ModelCatalogue.FIELD_ID]) == id:
			chosen_id = id
			effort = BenchPicker.start_effort(row)
			_render_rows()
			_refresh_choice()
			return


func choose_effort(level: String) -> void:
	var row: Dictionary = _chosen_row()
	if row.is_empty() or not BenchPicker.efforts(row).has(level):
		return
	effort = level
	_render_rows()
	_refresh_choice()


func choose_cap(value: float) -> void:
	cap_usd = value
	Settings.set_bench_cap_usd(value)
	_refresh_choice()


## *Start* (§19.8 item 8): a paid or unknown-price model asks first. The answer
## is `BenchJobs.start`'s ("" when it started).
func start() -> String:
	var row: Dictionary = _chosen_row()
	if row.is_empty() or _start.disabled:
		return BenchJobs.REASON_MODEL
	var figures: Dictionary = BenchPicker.estimate(row, effort, _tokens, _config)
	if BenchPicker.needs_confirm(row):
		var likely: String = UNKNOWN_MARK
		if not figures.is_empty() and bool(figures[BenchEstimate.FIELD_KNOWN]):
			likely = _usd(float(figures[BenchEstimate.FIELD_LIKELY]))
		var question: String = tr(KEY_CONFIRM).format({"likely": likely, "cap": _usd(cap_usd)})
		if not await _confirm.ask_text(question, KEY_START):
			return REASON_CANCELLED
	var reason: String = BenchJobs.start(str(row[ModelCatalogue.FIELD_ID]), effort, cap_usd,
		BenchPicker.reasoning(row, effort, _config), BenchPicker.is_free(row))
	_start_failure.visible = not reason.is_empty()
	if reason == BenchJobs.REASON_RUNNING:
		_start_failure.text = tr(KEY_START_BUSY)
	elif not reason.is_empty():
		print("bench_run: start refused (%s)" % reason)
		_start_failure.text = tr(KEY_START_FAILED)
	_holding_job = _holding_job or reason.is_empty()
	_refresh_sections()
	return reason


# --------------------------------------------------------------- the list


func _open_list() -> void:
	var body: String = cache.read()
	_candidates = BenchPicker.candidates(ModelCatalogue.parse(body), _config)
	_failed = false
	var now: int = int(clock.call()) if clock.is_valid() else int(Time.get_unix_time_from_system())
	if not _candidates.is_empty() and cache.is_fresh(_config.player_models_max_age_s, now):
		_loading = false
		return
	_loading = true
	if list_fetcher.is_valid():
		_take_list(str(list_fetcher.call()))
		return
	_request_list()


## No key: the list is public (§11.5 item 2).
func _request_list() -> void:
	if not _loading or not _request.is_inside_tree():
		return
	_request.cancel_request()
	_request.timeout = float(_config.global_timeout_s)
	if _request.request(_config.base_url + _config.models_path) != OK:
		_take_list("")


func _on_request_completed(result: int, code: int, _headers: PackedStringArray,
		body: PackedByteArray) -> void:
	var ok: bool = result == HTTPRequest.RESULT_SUCCESS and code == OpenRouterBackend.STATUS_OK \
		and BenchEntry.is_utf8(body)
	_take_list(body.get_string_from_utf8() if ok else "")


func _take_list(body: String) -> void:
	_loading = false
	var fetched: Array[Dictionary] = BenchPicker.candidates(ModelCatalogue.parse(body), _config)
	if not fetched.is_empty():
		cache.write(body)
		_candidates = fetched
	_failed = _candidates.is_empty()
	if visible:
		_render_rows()
		_refresh_choice()


func _measure() -> void:
	var db: ContentDB = Game.content()
	var content_hash: String = "" if db == null else db.content_hash
	var key: String = content_hash + TranslationServer.get_locale()
	if _tokens.is_empty() or _tokens_hash != key:
		_tokens = BenchPicker.measure(db, _config)
		_tokens_hash = key


func _render_rows() -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_choose_group = ButtonGroup.new()
	rows_shown = BenchPicker.shown(_candidates, search_text, free_only, effort, _tokens, _config)
	var status: String = ""
	if _loading:
		status = tr(KEY_LOADING)
	elif _failed:
		status = tr(KEY_LIST_FAILED)
	elif rows_shown.is_empty():
		status = tr(KEY_NO_MATCH)
	_list_status.text = status
	_list_status.visible = not status.is_empty()
	var still_shown: bool = false
	for row: Dictionary in rows_shown:
		_add_row(row)
		still_shown = still_shown or str(row[ModelCatalogue.FIELD_ID]) == chosen_id
	if not still_shown:
		chosen_id = ""


func _add_row(row: Dictionary) -> void:
	var id: String = str(row[ModelCatalogue.FIELD_ID])
	var pair: BoxContainer = BoxContainer.new()
	pair.theme_type_variation = &"Row"
	_rows.add_child(pair)
	var lines: VBoxContainer = VBoxContainer.new()
	lines.theme_type_variation = &"StackLines"
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pair.add_child(lines)
	var name_label: Label = Label.new()
	name_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	name_label.text = str(row[ModelCatalogue.FIELD_NAME])
	lines.add_child(name_label)
	var id_label: Label = _caption(lines, id)
	id_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_caption(lines, price_line(row))
	if bool(row[ModelCatalogue.FIELD_REASONING]):
		_caption(lines, tr(KEY_REASONING))
	var choose_button: ConsoleButton = ConsoleButton.new()
	choose_button.label_key = KEY_CHOOSE
	choose_button.toggle_mode = true
	choose_button.compact = true
	choose_button.button_group = _choose_group
	choose_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	choose_button.set_pressed_no_signal(id == chosen_id)
	choose_button.pressed.connect(choose.bind(id))
	pair.add_child(choose_button)
	# accessibility.md §3.3: *Choose* says which model — after the button's
	# `_ready`, which names it after its label.
	choose_button.accessibility_name = A11y.label_value(tr(KEY_CHOOSE), id)
	var compact: bool = get_viewport_rect().size.x < float(UiTokens.COMPACT_WIDTH)
	pair.vertical = compact
	choose_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if compact \
		else Control.SIZE_SHRINK_END


## §19.8 item 4: the price per million tokens in and out, or *Free*.
func price_line(row: Dictionary) -> String:
	if BenchPicker.is_free(row):
		return tr(KEY_FREE)
	return tr(KEY_PRICE).format({
		"in": _per_million(float(row[ModelCatalogue.FIELD_PROMPT])),
		"out": _per_million(float(row[ModelCatalogue.FIELD_COMPLETION])),
	})


# ------------------------------------------------------------ the choice


func _chosen_row() -> Dictionary:
	for row: Dictionary in rows_shown:
		if str(row[ModelCatalogue.FIELD_ID]) == chosen_id:
			return row
	return {}


## Effort, cost, cap and *Start* for the chosen model (§19.8 items 5–8).
func _refresh_choice() -> void:
	var row: Dictionary = _chosen_row()
	var has_row: bool = not row.is_empty()
	var allowed: Array[String] = [BenchEffort.NORMAL]
	if has_row:
		allowed = BenchPicker.efforts(row)
	if not allowed.has(effort):
		effort = BenchEffort.NORMAL
	for level: String in BenchEffort.LEVELS:
		var button: ConsoleButton = _effort_buttons[level]
		button.disabled = not has_row or not allowed.has(level)
	ToggleGroup.press(_effort_buttons[effort])
	var note: String = ""
	if has_row and allowed.size() == 1:
		note = tr(KEY_NO_REASONING)
	elif has_row and effort == BenchEffort.NORMAL and BenchPicker.reasons_at_normal(row):
		note = tr(KEY_DEFAULT_REASONING)
	_effort_note.text = note
	_effort_note.visible = not note.is_empty()
	var free: bool = has_row and BenchPicker.is_free(row)
	var figures: Dictionary = BenchPicker.estimate(row, effort, _tokens, _config) if has_row else {}
	_estimate.visible = has_row
	if free:
		_estimate.text = tr(KEY_FREE_NOTE)
	elif figures.is_empty() or not bool(figures[BenchEstimate.FIELD_KNOWN]):
		_estimate.text = tr(KEY_ESTIMATE_UNKNOWN)
	else:
		_estimate.text = tr(KEY_ESTIMATE).format({
			"likely": _usd(float(figures[BenchEstimate.FIELD_LIKELY])),
			"most": _usd(float(figures[BenchEstimate.FIELD_AT_MOST])),
		})
	# A free model ignores the cap (§19.8 item 6).
	_cap_title.visible = not free
	_cap_row.visible = not free
	for button: ConsoleButton in _cap_buttons:
		if float(button.get_meta(&"usd")) == cap_usd:
			ToggleGroup.press(button)
	var over: bool = has_row and BenchPicker.over_cap(row, figures, cap_usd)
	_over_cap.visible = over
	_start.disabled = not has_row or over or BenchJobs.key_busy()


# ------------------------------------------------------------- the states


func _has_key() -> bool:
	return BenchJobs.mock or BenchJobs.key_status in [BenchJobs.KEY_STORED, BenchJobs.KEY_SESSION]


## §19.8 items 2–4: no key, a benchmark running, or the picker.
func _refresh_sections() -> void:
	if _picker == null:
		return
	var state: BenchJobState = BenchJobs.state()
	var running: bool = state != null and state.is_running()
	var show_job: bool = running or (state != null and _holding_job)
	var no_key: bool = not show_job and not _has_key()
	_no_key_box.visible = no_key
	_no_key.text = tr(KEY_CHECKING) if BenchJobs.key_status == BenchJobs.KEY_UNKNOWN \
		and not BenchJobs.mock else tr(KEY_NO_KEY)
	_set_key.visible = BenchJobs.key_status != BenchJobs.KEY_UNKNOWN or BenchJobs.mock
	_job.visible = show_job
	_job.refresh()
	_job.visible = show_job
	_picker.visible = not show_job and not no_key
	if _start != null:
		_refresh_choice()


func _on_search_changed(text: String) -> void:
	search_text = text
	_render_rows()
	_refresh_choice()


func _on_free_toggled(on: bool) -> void:
	free_only = on
	_render_rows()
	_refresh_choice()


func _on_start_pressed() -> void:
	await start()


# ------------------------------------------------------------- building


func _refresh_strings() -> void:
	_title.text = tr(KEY_TITLE)
	_intro.text = tr(KEY_INTRO)
	_search.placeholder_text = tr(KEY_SEARCH)
	_search.accessibility_name = tr(KEY_SEARCH)
	_time_note.text = tr(KEY_TIME_NOTE)
	_privacy.text = tr(KEY_PRIVACY)
	_over_cap.text = tr(KEY_OVER_CAP)
	for button: ConsoleButton in _cap_buttons:
		button.text = tr(KEY_CAP_VALUE).format({"usd": _usd(float(button.get_meta(&"usd")))})
		button.accessibility_name = tr(KEY_LABEL_VALUE).format({"label": tr(KEY_CAP),
			"value": button.text})


func _build() -> void:
	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_panel = ModalPanel.new()
	_panel.name = "RunPanel"
	_panel.theme_type_variation = &"ConsolePanelRaised"
	centre.add_child(_panel)
	var body: VBoxContainer = VBoxContainer.new()
	body.theme_type_variation = &"PanelContent"
	_panel.add_child(body)
	var header: HBoxContainer = HBoxContainer.new()
	header.theme_type_variation = &"Row"
	body.add_child(header)
	_title = Label.new()
	_title.theme_type_variation = &"LabelDisplay"
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_close = IconButton.new()
	_close.glyph = Glyphs.Glyph.CLOSE
	_close.tooltip_key = KEY_CLOSE
	_close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_close.pressed.connect(closed.emit)
	header.add_child(_close)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_scroll)
	var margin: MarginContainer = MarginContainer.new()
	margin.theme_type_variation = &"FocusMargin"
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.theme_type_variation = &"Stack"
	margin.add_child(column)
	_intro = _caption(column, "")
	_intro.theme_type_variation = &"Label"
	_build_no_key(column)
	_live = LiveRegion.new()
	_live.name = "RunLive"
	add_child(_live)
	_job = BenchJobView.new()
	_job.name = "JobView"
	_job.show_title = false
	_job.live = _live
	column.add_child(_job)
	_build_picker(column)
	_confirm = CONFIRM_SCENE.instantiate() as ConfirmModal
	_confirm.name = "RunConfirm"
	add_child(_confirm)
	_request = HTTPRequest.new()
	_request.name = "ListRequest"
	add_child(_request)
	_request.request_completed.connect(_on_request_completed)


func _build_no_key(column: VBoxContainer) -> void:
	_no_key_box = VBoxContainer.new()
	_no_key_box.name = "NoKey"
	_no_key_box.theme_type_variation = &"StackTight"
	column.add_child(_no_key_box)
	_no_key = _caption(_no_key_box, "")
	_set_key = ConsoleButton.new()
	_set_key.label_key = KEY_SET
	_set_key.primary = true
	_set_key.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_set_key.pressed.connect(key_requested.emit)
	_no_key_box.add_child(_set_key)


func _build_picker(column: VBoxContainer) -> void:
	_picker = VBoxContainer.new()
	_picker.name = "Picker"
	_picker.theme_type_variation = &"Stack"
	column.add_child(_picker)
	var search_row: HFlowContainer = HFlowContainer.new()
	search_row.theme_type_variation = &"Flow"
	_picker.add_child(search_row)
	_search = LineEdit.new()
	_search.name = "Search"
	_search.custom_minimum_size = Vector2(float(UiTokens.HIT_MIN) * 4.0, float(UiTokens.HIT_MIN))
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.clear_button_enabled = true
	_search.text_changed.connect(_on_search_changed)
	search_row.add_child(_search)
	_free_toggle = ConsoleButton.new()
	_free_toggle.label_key = KEY_FREE_ONLY
	_free_toggle.toggle_mode = true
	_free_toggle.compact = true
	_free_toggle.toggled.connect(_on_free_toggled)
	search_row.add_child(_free_toggle)
	_list_status = _caption(_picker, "")
	_list_status.name = "ListStatus"
	_rows = VBoxContainer.new()
	_rows.name = "ModelRows"
	_rows.theme_type_variation = &"StackTight"
	_picker.add_child(_rows)
	_effort_title = CapsLabel.new()
	_effort_title.label_key = KEY_EFFORT
	_picker.add_child(_effort_title)
	var effort_row: HFlowContainer = HFlowContainer.new()
	effort_row.theme_type_variation = &"Flow"
	_picker.add_child(effort_row)
	_effort_group = ButtonGroup.new()
	for level: String in BenchEffort.LEVELS:
		var button: ConsoleButton = ConsoleButton.new()
		button.label_key = BenchEffort.key_of(level)
		button.toggle_mode = true
		button.compact = true
		button.button_group = _effort_group
		button.pressed.connect(choose_effort.bind(level))
		effort_row.add_child(button)
		_effort_buttons[level] = button
	_effort_note = _caption(_picker, "")
	_estimate = _caption(_picker, "")
	_estimate.theme_type_variation = &"LabelCaptionHint"
	_cap_title = CapsLabel.new()
	_cap_title.label_key = KEY_CAP
	_picker.add_child(_cap_title)
	_cap_row = HFlowContainer.new()
	_cap_row.theme_type_variation = &"Flow"
	_picker.add_child(_cap_row)
	_cap_group = ButtonGroup.new()
	for value: float in _config.player_cap_choices:
		var button: ConsoleButton = ConsoleButton.new()
		button.toggle_mode = true
		button.compact = true
		button.button_group = _cap_group
		button.set_meta(&"usd", value)
		button.pressed.connect(choose_cap.bind(value))
		_cap_row.add_child(button)
		_cap_buttons.append(button)
	_over_cap = _caption(_picker, "")
	_over_cap.theme_type_variation = &"LabelCaptionAlert"
	_time_note = _caption(_picker, "")
	_privacy = _caption(_picker, "")
	_start = ConsoleButton.new()
	_start.label_key = KEY_START
	_start.primary = true
	_start.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_start.pressed.connect(_on_start_pressed)
	_picker.add_child(_start)
	_start_failure = _caption(_picker, "")
	_start_failure.theme_type_variation = &"LabelCaptionAlert"
	_start_failure.visible = false


static func _caption(into: Container, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = &"LabelCaption"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	into.add_child(label)
	return label


static func _usd(value: float) -> String:
	return Format.decimal(value, USD_DECIMALS)


static func _per_million(price: float) -> String:
	if price < 0.0:
		return UNKNOWN_MARK
	return Format.decimal(price * TOKENS_PER_MILLION, USD_DECIMALS)


## The modal is as tall as the window allows, like the list it opens over
## (which would show below it otherwise); the picker scrolls in it.
func _fit() -> void:
	if _panel == null:
		return
	var view: Vector2 = get_viewport_rect().size
	_panel.custom_minimum_size.y = maxf(view.y - float(UiTokens.SPACE_6) * 2.0, 0.0)
