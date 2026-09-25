extends Control
## The keyboard's keys, and changing them (spec accessibility.md §5.3).
##
## One row per remappable action: its name and a button with its key. Pressing
## the button waits for the next key — with no time limit — and binds it through
## `KeyBindings`, which swaps the two actions when the key was taken. `Escape`
## cancels a capture; only without one does it close the modal. Mouse and pad
## buttons are never captured: the controller's layout is fixed (§5.4).
##
## Opened over the settings with `ModalHost.open_over`. Scene-specific, so no
## `class_name`.

signal closed

const KEY_TITLE: String = "UI_CONTROLS_TITLE"
const KEY_NOTE: String = "UI_CONTROLS_NOTE"
const KEY_RESET: String = "UI_CONTROLS_RESET"
const KEY_PRESS: String = "UI_CONTROLS_PRESS"
const KEY_RESERVED: String = "UI_CONTROLS_RESERVED"
const KEY_SWAPPED: String = "UI_CONTROLS_SWAPPED"
const KEY_CLOSE: String = "UI_COMMON_CLOSE"
const KEY_LABEL_VALUE: String = "UI_A11Y_LABEL_VALUE"
## Action → the string that names it; the three speeds share one with a number.
const ACTION_KEYS: Dictionary[StringName, String] = {
	&"game_pause": "UI_CONTROLS_PAUSE",
	&"game_speed_1": "UI_CONTROLS_SPEED",
	&"game_speed_2": "UI_CONTROLS_SPEED",
	&"game_speed_3": "UI_CONTROLS_SPEED",
	&"game_tree": "UI_CONTROLS_TREE",
	&"game_containment": "UI_CONTROLS_CONTAINMENT",
	&"game_analysis": "UI_CONTROLS_ANALYSIS",
	&"game_abilities": "UI_CONTROLS_ABILITIES",
	&"game_help": "UI_CONTROLS_HELP",
	&"game_zoom_in": "UI_CONTROLS_ZOOM_IN",
	&"game_zoom_out": "UI_CONTROLS_ZOOM_OUT",
	&"game_focus_region": "UI_CONTROLS_FOCUS_REGION",
}
## The speed each speed action sets, as the session does (`3` is 4×).
const SPEEDS: Dictionary[StringName, int] = {&"game_speed_1": 1, &"game_speed_2": 2,
	&"game_speed_3": 4}
## The list scrolls past this share of the window's height.
const SCROLL_SHARE: float = 0.6
## A lone modifier is not a key a player means to bind.
const MODIFIERS: Array[Key] = [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]

## The action waiting for its key, or &"" when nothing is being captured.
var capturing: StringName = &""

var _panel: ModalPanel = null
var _title: Label = null
var _close: IconButton = null
var _scroll: ScrollContainer = null
var _rows: VBoxContainer = null
var _note: Label = null
var _status: Label = null
var _reset: ConsoleButton = null
var _names: Dictionary[StringName, Label] = {}
var _buttons: Dictionary[StringName, ConsoleButton] = {}
var _live: LiveRegion = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_refresh()
	get_viewport().size_changed.connect(_fit)
	visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()


## Shows the list, nothing captured, the status line empty.
func open() -> void:
	capturing = &""
	_status.text = ""
	visible = true
	_refresh()
	_fit()
	_buttons[KeyBindings.REMAPPABLE[0]].grab_focus.call_deferred()


## §5.3: `Escape` cancels a capture when one runs, and only otherwise closes.
func on_escape() -> void:
	if capturing != &"":
		_cancel_capture()
		return
	closed.emit()


## The button of `action`, for the tests.
func button_of(action: StringName) -> ConsoleButton:
	return _buttons.get(action)


## The status line, for the tests.
func status_text() -> String:
	return _status.text


func live_region() -> LiveRegion:
	return _live


## Starts waiting for `action`'s key.
func capture(action: StringName) -> void:
	if not _buttons.has(action):
		return
	if capturing != &"":
		_cancel_capture()
	capturing = action
	_status.text = ""
	_buttons[action].text = Format.caps(tr(KEY_PRESS))
	_buttons[action].accessibility_name = tr(KEY_PRESS)


## The next key press while capturing is the answer; nothing else is let through.
func _input(event: InputEvent) -> void:
	if capturing == &"" or not visible:
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	get_viewport().set_input_as_handled()
	take_key(key)


## One captured key press (§5.3's three cases).
func take_key(key: InputEventKey) -> void:
	var physical: Key = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	if MODIFIERS.has(physical):
		return
	if physical == KEY_ESCAPE:
		_cancel_capture()
		return
	if not KeyBindings.can_bind(physical):
		_status.text = tr(KEY_RESERVED).format({"key": KeyNames.key_label(physical)})
		return
	var action: StringName = capturing
	var old: Key = KeyBindings.key_of(action)
	capturing = &""
	var other: StringName = KeyBindings.assign(action, physical)
	_refresh()
	if other == &"":
		return
	var note: String = tr(KEY_SWAPPED).format({"key": KeyNames.key_label(physical),
		"other": action_name(other), "old": KeyNames.key_label(old)})
	_status.text = note
	_live.say(note)


## The words for `action` in the list.
func action_name(action: StringName) -> String:
	var text: String = tr(ACTION_KEYS.get(action, ""))
	if SPEEDS.has(action):
		return text.format({"speed": SPEEDS[action]})
	return text


func _cancel_capture() -> void:
	capturing = &""
	_refresh()


func _on_reset_pressed() -> void:
	capturing = &""
	KeyBindings.reset()
	_status.text = ""
	_refresh()


func _refresh() -> void:
	if _title == null:
		return
	_title.text = tr(KEY_TITLE)
	_note.text = tr(KEY_NOTE)
	_reset.label_key = KEY_RESET
	for action: StringName in KeyBindings.REMAPPABLE:
		var name_text: String = action_name(action)
		_names[action].text = name_text
		if action == capturing:
			continue
		var key: String = KeyNames.label(action)
		# One character is shown as the keycap prints it: uppercasing `ß` would
		# make it `SS`.
		_buttons[action].text = key if key.length() == 1 else Format.caps(key)
		_buttons[action].accessibility_name = tr(KEY_LABEL_VALUE).format({"label": name_text,
			"value": key})


func _build() -> void:
	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_panel = ModalPanel.new()
	_panel.name = "ControlsPanel"
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
	_rows = VBoxContainer.new()
	_rows.theme_type_variation = &"StackTight"
	column.add_child(_rows)
	for action: StringName in KeyBindings.REMAPPABLE:
		var row: HBoxContainer = HBoxContainer.new()
		row.theme_type_variation = &"Row"
		var label: Label = Label.new()
		label.theme_type_variation = &"LabelCaption"
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var button: ConsoleButton = ConsoleButton.new()
		button.pressed.connect(capture.bind(action))
		row.add_child(button)
		_rows.add_child(row)
		_names[action] = label
		_buttons[action] = button
	_note = Label.new()
	_note.theme_type_variation = &"LabelCaption"
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_note)
	_status = Label.new()
	_status.theme_type_variation = &"LabelCaptionAccent"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	_reset = ConsoleButton.new()
	_reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_reset.pressed.connect(_on_reset_pressed)
	column.add_child(_reset)
	# §3.4: the swap note is also spoken. Beside the centre container, never in it.
	_live = LiveRegion.new()
	_live.name = "ControlsLive"
	add_child(_live)


## The list scrolls in a window too short for it (150 % text on a small screen).
func _fit() -> void:
	if _scroll == null:
		return
	var view: Vector2 = get_viewport_rect().size
	var content: Control = _scroll.get_child(0) as Control
	var height: float = content.get_combined_minimum_size().y if content != null else 0.0
	_scroll.custom_minimum_size.y = minf(height, maxf(view.y * SCROLL_SHARE, 0.0))
