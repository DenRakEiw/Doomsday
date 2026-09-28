extends Control
## The OpenRouter key (docs/specs/benchmark.md §19.7): what it is for, where it
## is kept, a field to paste it into, and *Save*, *Check*, *Remove*.
##
## The key itself never goes into a `Label`, a tooltip or an accessible name:
## the field shows it only while *Show* is on, the captions name its last four
## characters at most, and the field is emptied when the dialog closes. Every
## store and network call is `BenchJobs`', off the main thread; the buttons wait
## with it.
##
## Opened over the settings (or in place of the benchmark modal) with
## `ModalHost.open_over`. Scene-specific, so no `class_name`.

signal closed

const KEY_TITLE: String = "UI_KEY_TITLE"
const KEY_INTRO: String = "UI_KEY_INTRO"
const KEY_TIP: String = "UI_KEY_TIP"
const KEY_GET: String = "UI_KEY_GET"
const KEY_FIELD: String = "UI_KEY_FIELD"
const KEY_PLACEHOLDER: String = "UI_KEY_PLACEHOLDER"
const KEY_SHOW: String = "UI_KEY_SHOW"
const KEY_SAVE: String = "UI_KEY_SAVE"
const KEY_CHECK: String = "UI_KEY_CHECK"
const KEY_REMOVE: String = "UI_KEY_REMOVE"
const KEY_FORMAT: String = "UI_KEY_FORMAT"
const KEY_SAVED: String = "UI_KEY_SAVED"
const KEY_STORE_FAILED: String = "UI_KEY_STORE_FAILED"
const KEY_REMOVED: String = "UI_KEY_REMOVED"
const KEY_CHECKING: String = "UI_KEY_CHECKING"
const KEY_VALID: String = "UI_KEY_VALID"
const KEY_VALID_LIMIT: String = "UI_KEY_VALID_LIMIT"
const KEY_INVALID: String = "UI_KEY_INVALID"
const KEY_OFFLINE: String = "UI_KEY_OFFLINE"
const KEY_CLOSE: String = "UI_COMMON_CLOSE"
## Where the key is kept, by `BenchKeyStore.kind()`.
const WHERE_KEYS: Dictionary[String, String] = {
	BenchKeyStore.KIND_WINDOWS: "UI_KEY_WHERE_WINDOWS",
	BenchKeyStore.KIND_LINUX: "UI_KEY_WHERE_LINUX",
	BenchKeyStore.KIND_SESSION: "UI_KEY_WHERE_SESSION",
}
## §19.7 item 3: what an OpenRouter key starts with.
const KEY_PREFIX: String = "sk-or-"
## §19.7.1: the reply's fields and the statuses that mean "not this key".
const REPLY_DATA: String = "data"
const REPLY_USAGE: String = "usage"
const REPLY_LIMIT: String = "limit"
const STATUSES_INVALID: Array[int] = [401, 403]
const USD_DECIMALS: int = 2
## What a pasted key loses: spaces and line breaks anywhere.
const WHITESPACE: Array[String] = [" ", "\t", "\n", "\r"]
## The dialog scrolls past this share of the window's height.
const SCROLL_SHARE: float = 0.8

## The seam for opening OpenRouter's key page: `func(url: String) -> void`.
var shell_open: Callable = Callable()

var _panel: ModalPanel = null
var _title: Label = null
var _close: IconButton = null
var _scroll: ScrollContainer = null
var _intro: Label = null
var _where: Label = null
var _tip: Label = null
var _get: ConsoleButton = null
var _field_label: Label = null
var _field: LineEdit = null
var _show: ConsoleButton = null
var _state: Label = null
var _save: ConsoleButton = null
var _check: ConsoleButton = null
var _remove: ConsoleButton = null
var _close_button: ConsoleButton = null
var _result: Label = null
var _live: LiveRegion = null
## The key the last *Save* asked for doesn't look like OpenRouter's.
var _format_warning: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	BenchJobs.key_changed.connect(_refresh)
	BenchJobs.key_done.connect(_on_key_done)
	visibility_changed.connect(_on_visibility_changed)
	get_viewport().size_changed.connect(_fit)
	_refresh()
	visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()


## Shows the dialog with an empty field and asks the store what it holds.
func open() -> void:
	_field.text = ""
	_set_shown(false)
	_result.text = ""
	visible = true
	BenchJobs.refresh_key()
	_refresh()
	_fit()
	_field.grab_focus.call_deferred()


func on_escape() -> void:
	closed.emit()


## The field, the result caption and the state caption — for the tests.
func field() -> LineEdit:
	return _field


func result_text() -> String:
	return _result.text


func state_text() -> String:
	return _state.text


## The buttons, for the tests.
func save_button() -> ConsoleButton:
	return _save


func check_button() -> ConsoleButton:
	return _check


func remove_button() -> ConsoleButton:
	return _remove


func show_button() -> ConsoleButton:
	return _show


## §19.7 item 3: the key as it was pasted, without spaces and line breaks.
static func cleaned(text: String) -> String:
	var out: String = text
	for space: String in WHITESPACE:
		out = out.replace(space, "")
	return out


## §19.7.1: the line for OpenRouter's answer about a key — valid (with what it
## used and, if it has one, its limit, in USD), invalid, or unreachable.
static func check_line(answer: Dictionary) -> String:
	var status: int = int(answer.get(BenchJobs.FIELD_STATUS, OpenRouterBackend.STATUS_NONE))
	if STATUSES_INVALID.has(status):
		return TranslationServer.translate(KEY_INVALID)
	if status != OpenRouterBackend.STATUS_OK:
		return TranslationServer.translate(KEY_OFFLINE)
	var usage: float = 0.0
	var limit: Variant = null
	var json: JSON = JSON.new()
	if json.parse(str(answer.get(BenchJobs.FIELD_BODY, ""))) == OK \
			and typeof(json.data) == TYPE_DICTIONARY \
			and typeof((json.data as Dictionary).get(REPLY_DATA)) == TYPE_DICTIONARY:
		var data: Dictionary = (json.data as Dictionary)[REPLY_DATA]
		if typeof(data.get(REPLY_USAGE)) in [TYPE_INT, TYPE_FLOAT]:
			usage = float(data[REPLY_USAGE])
		if typeof(data.get(REPLY_LIMIT)) in [TYPE_INT, TYPE_FLOAT]:
			limit = float(data[REPLY_LIMIT])
	var args: Dictionary = {"usage": Format.decimal(usage, USD_DECIMALS)}
	if limit == null:
		return TranslationServer.translate(KEY_VALID).format(args)
	args["limit"] = Format.decimal(float(limit), USD_DECIMALS)
	return TranslationServer.translate(KEY_VALID_LIMIT).format(args)


# ------------------------------------------------------------------ actions


func _on_save_pressed() -> void:
	var key: String = cleaned(_field.text)
	if key.is_empty() or BenchJobs.key_busy():
		return
	_format_warning = not key.begins_with(KEY_PREFIX)
	_say(tr(KEY_CHECKING))
	BenchJobs.save_key(key)
	_refresh()


func _on_check_pressed() -> void:
	if BenchJobs.key_busy():
		return
	_say(tr(KEY_CHECKING))
	BenchJobs.check_key(cleaned(_field.text))
	_refresh()


func _on_remove_pressed() -> void:
	if BenchJobs.key_busy():
		return
	BenchJobs.remove_key()
	_refresh()


func _on_key_done(op: String, ok: bool) -> void:
	if not visible:
		return
	match op:
		BenchJobs.KEY_OP_SAVE:
			# A saved key has nowhere left to be seen.
			_field.text = ""
			var line: String = tr(KEY_SAVED if ok else KEY_STORE_FAILED)
			if _format_warning:
				line = tr(KEY_FORMAT) if ok else line + " " + tr(KEY_FORMAT)
			_say(line)
		BenchJobs.KEY_OP_REMOVE:
			_field.text = ""
			_say(tr(KEY_REMOVED))
		BenchJobs.KEY_OP_CHECK:
			_say(check_line(BenchJobs.check_answer))
	_refresh()


func _on_show_toggled(on: bool) -> void:
	_set_shown(on)


func _on_get_pressed() -> void:
	var url: String = BenchJobs.config().player_keys_url
	if url.is_empty():
		return
	if shell_open.is_valid():
		shell_open.call(url)
	else:
		OS.shell_open(url)


func _on_visibility_changed() -> void:
	if not visible and _field != null:
		# §19.7: nothing of the key stays behind in a closed dialog.
		_field.text = ""
		_set_shown(false)


func _set_shown(on: bool) -> void:
	_field.secret = not on
	_show.set_pressed_no_signal(on)


func _say(line: String) -> void:
	_result.text = line
	_live.say(line)


# ------------------------------------------------------------------ building


func _refresh() -> void:
	if _title == null:
		return
	_title.text = tr(KEY_TITLE)
	_intro.text = tr(KEY_INTRO)
	_where.text = tr(WHERE_KEYS.get(BenchJobs.key_store.kind(), WHERE_KEYS[BenchKeyStore.KIND_SESSION]))
	_tip.text = tr(KEY_TIP)
	_field_label.text = tr(KEY_FIELD)
	_field.placeholder_text = tr(KEY_PLACEHOLDER)
	_field.accessibility_name = tr(KEY_FIELD)
	_state.text = BenchJobs.key_state_text()
	var busy: bool = BenchJobs.key_busy()
	_save.disabled = busy
	_check.disabled = busy
	_remove.disabled = busy or BenchJobs.key_status == BenchJobs.KEY_NONE
	_get.visible = not BenchJobs.config().player_keys_url.is_empty()


func _build() -> void:
	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_panel = ModalPanel.new()
	_panel.name = "KeyPanel"
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
	# accessibility.md §4.2: room for the focus ring, which is drawn outside.
	var margin: MarginContainer = MarginContainer.new()
	margin.theme_type_variation = &"FocusMargin"
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.theme_type_variation = &"Stack"
	margin.add_child(column)
	_intro = _label(column, &"Label")
	_where = _label(column, &"LabelCaption")
	_tip = _label(column, &"LabelCaptionHint")
	_get = ConsoleButton.new()
	_get.label_key = KEY_GET
	_get.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_get.pressed.connect(_on_get_pressed)
	column.add_child(_get)
	var field_box: VBoxContainer = VBoxContainer.new()
	field_box.theme_type_variation = &"StackTight"
	column.add_child(field_box)
	_field_label = _label(field_box, &"LabelCaption")
	var field_row: HBoxContainer = HBoxContainer.new()
	field_row.theme_type_variation = &"Row"
	field_box.add_child(field_row)
	_field = LineEdit.new()
	_field.name = "KeyField"
	_field.secret = true
	_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_field.custom_minimum_size.y = float(UiTokens.HIT_MIN)
	_field.text_submitted.connect(func(_text: String) -> void: _on_save_pressed())
	field_row.add_child(_field)
	_show = ConsoleButton.new()
	_show.label_key = KEY_SHOW
	_show.toggle_mode = true
	_show.compact = true
	_show.toggled.connect(_on_show_toggled)
	field_row.add_child(_show)
	_state = _label(field_box, &"LabelCaption")
	_state.name = "KeyState"
	var buttons: HFlowContainer = HFlowContainer.new()
	buttons.theme_type_variation = &"Flow"
	column.add_child(buttons)
	_save = _button(buttons, KEY_SAVE, _on_save_pressed)
	_save.primary = true
	_check = _button(buttons, KEY_CHECK, _on_check_pressed)
	_remove = _button(buttons, KEY_REMOVE, _on_remove_pressed)
	_close_button = _button(buttons, KEY_CLOSE, closed.emit)
	_result = _label(column, &"LabelCaptionAccent")
	_result.name = "KeyResult"
	# §3.4: the results are spoken. Beside the centre container, never in it.
	_live = LiveRegion.new()
	_live.name = "KeyLive"
	add_child(_live)


func _label(into: Container, variation: StringName) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	into.add_child(label)
	return label


func _button(into: Container, key: String, action: Callable) -> ConsoleButton:
	var button: ConsoleButton = ConsoleButton.new()
	button.label_key = key
	button.pressed.connect(action)
	into.add_child(button)
	return button


## The dialog scrolls in a window too short for it.
func _fit() -> void:
	if _scroll == null:
		return
	var view: Vector2 = get_viewport_rect().size
	var content: Control = _scroll.get_child(0) as Control
	var height: float = content.get_combined_minimum_size().y if content != null else 0.0
	_scroll.custom_minimum_size.y = minf(height, maxf(view.y * SCROLL_SHARE, 0.0))
