extends Control
## *Submit* (docs/specs/benchmark.md §19.9.3, §20.6): one of the player's
## complete benchmarks, sent to the global leaderboard's submission queue after
## a consent line — or, when direct submission is not configured or the player
## asks for it, copied into a clean folder with the public repository's page
## opened alongside.
##
## When the global board is known and checks against other content, the runs
## would be rejected — the modal says so and does nothing else.
##
## Opened over the Benchmark list with `ModalHost.open_over`. Scene-specific,
## so no `class_name`.

signal closed
## §20.7: emitted when a group is recorded in `BenchSubmitLog` (`RECEIVED` or
## `ALREADY`), so the Benchmark list refreshes its group row.
signal submitted

const KEY_TITLE: String = "UI_BENCH_SUBMIT_TITLE"
const KEY_OLD_VERSION: String = "UI_BENCH_SUBMIT_OLD_VERSION"
const KEY_CONSENT: String = "UI_BENCH_SUBMIT_CONSENT"
const KEY_SEND: String = "UI_BENCH_SUBMIT_SEND"
const KEY_GITHUB: String = "UI_BENCH_SUBMIT_GITHUB"
const KEY_SENDING: String = "UI_BENCH_SUBMIT_SENDING"
const KEY_SENT: String = "UI_BENCH_SUBMIT_SENT"
const KEY_ALREADY: String = "UI_BENCH_SUBMIT_ALREADY"
const KEY_BUSY: String = "UI_BENCH_SUBMIT_BUSY"
const KEY_CLOSED: String = "UI_BENCH_SUBMIT_CLOSED"
const KEY_REFUSED: String = "UI_BENCH_SUBMIT_REFUSED"
const KEY_NET_FAILED: String = "UI_BENCH_SUBMIT_NET_FAILED"
const KEY_RETRY: String = "UI_BENCH_SUBMIT_RETRY"
const KEY_READ_FAILED: String = "UI_BENCH_SUBMIT_READ_FAILED"
const KEY_STEPS: String = "UI_BENCH_SUBMIT_STEPS"
const KEY_AGAIN: String = "UI_BENCH_SUBMIT_AGAIN"
const KEY_FAILED: String = "UI_BENCH_SUBMIT_FAILED"
const KEY_CANCEL: String = "UI_COMMON_CANCEL"
const KEY_CLOSE: String = "UI_COMMON_CLOSE"
## `shell`'s first argument: what it is asked to open.
const OPEN_FOLDER: String = "folder"
const OPEN_URL: String = "url"

const STAGE_CONSENT: String = "consent"
const STAGE_SENDING: String = "sending"
const STAGE_ANSWER: String = "answer"
const STAGE_READ_FAILED: String = "read_failed"
const STAGE_GITHUB: String = "github"

## The seam for the two shell calls: `func(kind: String, target: String) -> void`
## — `OPEN_FOLDER` with the first copied file, `OPEN_URL` with the page.
var shell: Callable = Callable()
## The seam for the direct-submit POST:
## `func(url: String, headers: PackedStringArray, body: String, done: Callable) -> void`
## where `done` is `func(code: int, body: PackedByteArray) -> void`.
var transport: Callable = Callable()
## Optional overrides for the tests.
var config_override: BenchConfig = null
var log_store: BenchSubmitLog = null
## What the last fork-route `open` did, for the tests: the copies, or [] when
## refused or failed.
var copies: Array[String] = []
## The last `bench_submit: <kind> <reason> <id>` line written, for the tests.
var last_log_line: String = ""

var _group: BenchGroup = null
var _refused: bool = false
var _stage: String = STAGE_GITHUB
var _submission: BenchSubmission = null
var _result: BenchSubmitResult = null
var _send_seq: int = 0
var _panel: ModalPanel = null
var _title: Label = null
var _close: IconButton = null
var _message: Label = null
var _send: ConsoleButton = null
var _retry: ConsoleButton = null
var _github: ConsoleButton = null
var _again: ConsoleButton = null
var _close_button: ConsoleButton = null
var _http: HTTPRequest = null
var _live: LiveRegion = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()


## §19.9.3 and §20.6 for `group`: refused when `board_hash` (the known global
## board's content, "" when unknown) is not this game's; else shows the consent
## step when direct submission is configured (and `group.github_only` is false),
## or runs the fork route immediately.
func open(group: BenchGroup, board_hash: String, content_hash: String) -> void:
	_group = group
	copies.clear()
	_submission = null
	_result = null
	_send_seq += 1
	if _http != null:
		_http.cancel_request()
	_refused = not board_hash.is_empty() and board_hash != content_hash
	visible = true
	var direct: bool = _config().has_direct_submit() and (_group == null or not _group.github_only)
	if _refused:
		_stage = STAGE_GITHUB
	elif direct:
		_stage = STAGE_CONSENT
	else:
		_stage = STAGE_GITHUB
		_submit()
	_refresh()


func on_escape() -> void:
	_close_modal()


func message_text() -> String:
	return _message.text


func send_button() -> ConsoleButton:
	return _send


func retry_button() -> ConsoleButton:
	return _retry


func github_button() -> ConsoleButton:
	return _github


func again_button() -> ConsoleButton:
	return _again


func close_button() -> ConsoleButton:
	return _close_button


func _config() -> BenchConfig:
	return config_override if config_override != null else BenchJobs.config()


func _close_modal() -> void:
	_send_seq += 1
	if _http != null:
		_http.cancel_request()
	closed.emit()


## §20.6 items 4–5: read the group's files, send the POST, and handle the answer.
func _on_send_pressed() -> void:
	var cfg: BenchConfig = _config()
	_submission = BenchSubmission.from_group(_group, cfg)
	if _submission == null:
		_stage = STAGE_READ_FAILED
		_refresh()
		_live.say(_message.text)
		return
	_stage = STAGE_SENDING
	_refresh()
	_live.say(_message.text)
	_send_seq += 1
	var seq: int = _send_seq
	var url: String = cfg.submit_rpc_url()
	var hdrs: PackedStringArray = _submission.headers(cfg)
	var payload: String = _submission.body()
	if transport.is_valid():
		transport.call(url, hdrs, payload,
			func(code: int, body_bytes: PackedByteArray) -> void:
				_on_answer(seq, code, body_bytes))
		return
	if not _http.is_inside_tree():
		_on_answer(seq, 0, PackedByteArray())
		return
	_http.cancel_request()
	_http.timeout = float(cfg.submit_timeout_s)
	if _http.request(url, hdrs, HTTPClient.METHOD_POST, payload) != OK:
		_on_answer(seq, 0, PackedByteArray())


func _on_http_completed(result: int, code: int, _headers: PackedStringArray,
		body: PackedByteArray) -> void:
	var status: int = code if result == HTTPRequest.RESULT_SUCCESS else 0
	_on_answer(_send_seq, status, body)


func _on_answer(seq: int, code: int, body: PackedByteArray) -> void:
	if seq != _send_seq or not visible or _stage != STAGE_SENDING:
		return
	_result = BenchSubmission.read_answer(code, body)
	last_log_line = "bench_submit: %s %s %d" % [_result.kind, _result.reason, _result.id]
	print(last_log_line)
	if _result.is_stored() and _submission != null:
		var store: BenchSubmitLog = log_store if log_store != null else BenchSubmitLog.load_log()
		store.record(_submission, _result.id)
		submitted.emit()
	_stage = STAGE_ANSWER
	_refresh()
	_live.say(_message.text)


func _on_github_pressed() -> void:
	_send_seq += 1
	if _http != null:
		_http.cancel_request()
	_stage = STAGE_GITHUB
	_submit()
	_refresh()


## §19.9.3 item 3: copy, show the folder, open the page. Again on *Open … again*.
func _submit() -> void:
	copies = _group.copy_files()
	if copies.is_empty():
		return
	_shell(OPEN_FOLDER, ProjectSettings.globalize_path(copies[0]))
	var url: String = _config().player_submit_url
	if not url.is_empty():
		_shell(OPEN_URL, url)


func _shell(kind: String, target: String) -> void:
	if shell.is_valid():
		shell.call(kind, target)
	elif kind == OPEN_FOLDER:
		OS.shell_show_in_file_manager(target)
	else:
		OS.shell_open(target)


func _on_again_pressed() -> void:
	_submit()
	_refresh()


func _refresh() -> void:
	if _title == null:
		return
	_title.text = tr(KEY_TITLE)
	_send.visible = false
	_retry.visible = false
	_github.visible = false
	_again.visible = false
	_send.disabled = false
	_retry.disabled = false
	_github.disabled = false
	_again.disabled = false
	_close_button.label_key = KEY_CLOSE
	if _refused:
		_message.text = tr(KEY_OLD_VERSION)
		return
	match _stage:
		STAGE_CONSENT:
			var count: int = 0 if _group == null else _group.entries.size()
			_message.text = tr(KEY_CONSENT).format({"count": count})
			_send.visible = true
			_github.visible = true
			_close_button.label_key = KEY_CANCEL
		STAGE_SENDING:
			_message.text = tr(KEY_SENDING)
			_send.visible = true
			_send.disabled = true
			_github.visible = true
			_github.disabled = true
		STAGE_READ_FAILED:
			_message.text = tr(KEY_READ_FAILED)
		STAGE_ANSWER:
			match _result.kind:
				BenchSubmitResult.KIND_RECEIVED:
					_message.text = tr(KEY_SENT)
				BenchSubmitResult.KIND_ALREADY:
					_message.text = tr(KEY_ALREADY)
				BenchSubmitResult.KIND_BUSY:
					_message.text = tr(KEY_BUSY)
					_retry.visible = true
					_github.visible = true
				BenchSubmitResult.KIND_CLOSED:
					_message.text = tr(KEY_CLOSED)
					_github.visible = true
				BenchSubmitResult.KIND_REFUSED:
					_message.text = tr(KEY_REFUSED)
					_github.visible = true
				_:
					_message.text = tr(KEY_NET_FAILED)
					_retry.visible = true
					_github.visible = true
		_:
			if copies.is_empty():
				_message.text = tr(KEY_FAILED)
			else:
				_message.text = tr(KEY_STEPS).format({"count": copies.size()})
			_again.visible = true


func _build() -> void:
	_live = LiveRegion.new()
	_live.name = "SubmitLive"
	add_child(_live)
	_http = HTTPRequest.new()
	_http.name = "SubmitRequest"
	add_child(_http)
	_http.request_completed.connect(_on_http_completed)
	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_panel = ModalPanel.new()
	_panel.name = "SubmitPanel"
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
	_close.pressed.connect(_close_modal)
	header.add_child(_close)
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_message)
	var buttons: HFlowContainer = HFlowContainer.new()
	buttons.theme_type_variation = &"Flow"
	body.add_child(buttons)
	_send = ConsoleButton.new()
	_send.label_key = KEY_SEND
	_send.primary = true
	_send.pressed.connect(_on_send_pressed)
	buttons.add_child(_send)
	_retry = ConsoleButton.new()
	_retry.label_key = KEY_RETRY
	_retry.primary = true
	_retry.pressed.connect(_on_send_pressed)
	buttons.add_child(_retry)
	_github = ConsoleButton.new()
	_github.label_key = KEY_GITHUB
	_github.pressed.connect(_on_github_pressed)
	buttons.add_child(_github)
	_again = ConsoleButton.new()
	_again.label_key = KEY_AGAIN
	_again.pressed.connect(_on_again_pressed)
	buttons.add_child(_again)
	_close_button = ConsoleButton.new()
	_close_button.label_key = KEY_CLOSE
	_close_button.pressed.connect(_close_modal)
	buttons.add_child(_close_button)
