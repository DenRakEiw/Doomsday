extends Control
## *Submit* (docs/specs/benchmark.md §19.9.3): one of the player's complete
## benchmarks, made ready for the global leaderboard. The game uploads nothing:
## it copies the group's files into a clean folder, opens that folder and the
## public repository's page, and says what to do there.
##
## When the global board is known and checks against other content, the runs
## would be rejected — the modal says so and does nothing else.
##
## Opened over the Benchmark list with `ModalHost.open_over`. Scene-specific,
## so no `class_name`.

signal closed

const KEY_TITLE: String = "UI_BENCH_SUBMIT_TITLE"
const KEY_OLD_VERSION: String = "UI_BENCH_SUBMIT_OLD_VERSION"
const KEY_STEPS: String = "UI_BENCH_SUBMIT_STEPS"
const KEY_AGAIN: String = "UI_BENCH_SUBMIT_AGAIN"
const KEY_FAILED: String = "UI_BENCH_SUBMIT_FAILED"
const KEY_CLOSE: String = "UI_COMMON_CLOSE"
## `shell`'s first argument: what it is asked to open.
const OPEN_FOLDER: String = "folder"
const OPEN_URL: String = "url"

## The seam for the two shell calls: `func(kind: String, target: String) -> void`
## — `OPEN_FOLDER` with the first copied file, `OPEN_URL` with the page.
var shell: Callable = Callable()
## What the last `open` did, for the tests: the copies, or [] when refused or
## failed.
var copies: Array[String] = []

var _group: BenchGroup = null
var _refused: bool = false
var _panel: ModalPanel = null
var _title: Label = null
var _close: IconButton = null
var _message: Label = null
var _again: ConsoleButton = null
var _close_button: ConsoleButton = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()


## §19.9.3 items 2–4 for `group`: refused when `board_hash` (the known global
## board's content, "" when unknown) is not this game's; else the files copied
## and the folder and the page opened.
func open(group: BenchGroup, board_hash: String, content_hash: String) -> void:
	_group = group
	copies.clear()
	_refused = not board_hash.is_empty() and board_hash != content_hash
	visible = true
	if not _refused:
		_submit()
	_refresh()


func on_escape() -> void:
	closed.emit()


func message_text() -> String:
	return _message.text


func again_button() -> ConsoleButton:
	return _again


## Item 3: copy, show the folder, open the page. Again on *Open … again*.
func _submit() -> void:
	copies = _group.copy_files()
	if copies.is_empty():
		return
	_shell(OPEN_FOLDER, ProjectSettings.globalize_path(copies[0]))
	var url: String = BenchJobs.config().player_submit_url
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
	if _refused:
		_message.text = tr(KEY_OLD_VERSION)
	elif copies.is_empty():
		# DESIGN? §19.9.3 has no line for files that could not be copied.
		_message.text = tr(KEY_FAILED)
	else:
		_message.text = tr(KEY_STEPS).format({"count": copies.size()})
	_again.visible = not _refused


func _build() -> void:
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
	_close.pressed.connect(closed.emit)
	header.add_child(_close)
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_message)
	var buttons: HFlowContainer = HFlowContainer.new()
	buttons.theme_type_variation = &"Flow"
	body.add_child(buttons)
	_again = ConsoleButton.new()
	_again.label_key = KEY_AGAIN
	_again.pressed.connect(_on_again_pressed)
	buttons.add_child(_again)
	_close_button = ConsoleButton.new()
	_close_button.label_key = KEY_CLOSE
	_close_button.pressed.connect(closed.emit)
	buttons.add_child(_close_button)
