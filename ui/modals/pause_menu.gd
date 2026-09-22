extends Control
## Pause, save, load, settings, quit (spec m3-screens.md §7.3).
##
## The title opens the same scene with `settings_only`, so there is one settings
## screen in the game and not two that drift apart.
##
## Scene-specific, so no `class_name`.

## The menu wants to be closed (its own button, `Escape`, or Resume).
signal closed
## Quit was confirmed: the router takes it from here.
signal quit_requested

const KEY_TITLE: String = "UI_PAUSE_TITLE"
const KEY_SEED: String = "UI_PAUSE_SEED"
const KEY_DAY: String = "UI_PAUSE_DAY"
const KEY_SAVE: String = "UI_PAUSE_SAVE"
const KEY_LOAD: String = "UI_PAUSE_LOAD"
const KEY_SLOT: String = "UI_PAUSE_SLOT"
const KEY_SLOT_DAY: String = "UI_PAUSE_SLOT_DAY"
const KEY_SLOT_EMPTY: String = "UI_PAUSE_SLOT_EMPTY"
const KEY_SAVE_FAILED: String = "UI_PAUSE_SAVE_FAILED"
const KEY_LOAD_FAILED: String = "UI_PAUSE_LOAD_FAILED"
const KEY_LOAD_CONFIRM: String = "UI_PAUSE_LOAD_CONFIRM"
const KEY_QUIT_CONFIRM: String = "UI_PAUSE_QUIT_CONFIRM"
const KEY_SETTINGS_TITLE: String = "UI_SETTINGS_TITLE"
const KEY_LOCALE: String = "UI_SETTINGS_LOCALE"
const KEY_LOCALE_EN: String = "UI_SETTINGS_LOCALE_EN"
const KEY_LOCALE_DE: String = "UI_SETTINGS_LOCALE_DE"
const KEY_REDUCED_MOTION: String = "UI_SETTINGS_REDUCED_MOTION"
const KEY_TREE_PAUSES: String = "UI_SETTINGS_TREE_PAUSES"
const KEY_ON: String = "UI_SETTINGS_ON"
const KEY_OFF: String = "UI_SETTINGS_OFF"

const PLACEHOLDER_SEED: String = "seed"
const PLACEHOLDER_DAY: String = "day"
const PLACEHOLDER_SLOT: String = "n"
const PLACEHOLDER_REASON: String = "reason"

## The three manual slots of §7.3.
const SLOTS: Array[String] = ["slot_1", "slot_2", "slot_3"]

@onready var _panel: PanelContainer = %PausePanel
@onready var _title: Label = %PauseTitle
@onready var _caption: Label = %PauseCaption
@onready var _resume: ConsoleButton = %ResumeButton
@onready var _save_block: Control = %SaveBlock
@onready var _save_title: CapsLabel = %SaveTitle
@onready var _save_row: Container = %SaveRow
@onready var _load_block: Control = %LoadBlock
@onready var _load_title: CapsLabel = %LoadTitle
@onready var _load_row: Container = %LoadRow
@onready var _failure: Label = %PauseFailure
@onready var _settings_title: CapsLabel = %SettingsTitle
@onready var _settings_rows: VBoxContainer = %SettingsRows
@onready var _quit: ConsoleButton = %QuitButton
@onready var _confirm: ConfirmModal = %PauseConfirm

## §7.3: the title opens the settings alone.
var settings_only: bool = false

## Slot → its two buttons and its caption.
var _save_buttons: Array[ConsoleButton] = []
var _load_buttons: Array[ConsoleButton] = []
var _slot_captions: Array[Label] = []
var _setting_buttons: Array[ConsoleButton] = []


func _ready() -> void:
	_panel.custom_minimum_size.x = float(UiTokens.MODAL_MAX_WIDTH)
	_resume.pressed.connect(_on_resume_pressed)
	_quit.pressed.connect(_on_quit_pressed)
	_build_slots()
	_build_settings()
	_refresh_strings()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_strings()
		refresh()


## Opens the whole menu.
func open_menu() -> void:
	settings_only = false
	_apply_mode()
	refresh()
	_resume.grab_focus.call_deferred()


## Opens only the settings section, which is what the title screen shows (§7.3).
func open_settings_only() -> void:
	settings_only = true
	_apply_mode()
	refresh()
	visible = true
	_setting_buttons[0].grab_focus.call_deferred()


func on_escape() -> void:
	closed.emit()


## Re-reads the run and the save slots.
func refresh() -> void:
	_failure.visible = false
	if not settings_only and Game.sim != null:
		_caption.text = "%s · %s" % [
			tr(KEY_SEED).format({PLACEHOLDER_SEED: Game.run_seed()}),
			tr(KEY_DAY).format({PLACEHOLDER_DAY:
				Format.number(float(Game.sim.world.day), Format.Kind.DAYS)}),
		]
	for i: int in SLOTS.size():
		var day: int = SaveManager.peek_day(SLOTS[i])
		_slot_captions[i].text = tr(KEY_SLOT_EMPTY) if day < 0 \
			else tr(KEY_SLOT_DAY).format({PLACEHOLDER_DAY:
				Format.number(float(day), Format.Kind.DAYS)})
		_load_buttons[i].disabled = day < 0
	_refresh_settings()


func _apply_mode() -> void:
	_caption.visible = not settings_only
	_resume.visible = not settings_only
	_save_block.visible = not settings_only
	_load_block.visible = not settings_only
	_quit.visible = not settings_only
	_title.text = tr(KEY_SETTINGS_TITLE if settings_only else KEY_TITLE)


func _refresh_strings() -> void:
	_apply_mode()
	_save_title.label_key = KEY_SAVE
	_load_title.label_key = KEY_LOAD
	_settings_title.label_key = KEY_SETTINGS_TITLE
	for i: int in SLOTS.size():
		var text: String = tr(KEY_SLOT).format({PLACEHOLDER_SLOT: i + 1})
		_save_buttons[i].text = Format.caps(text)
		_load_buttons[i].text = Format.caps(text)


# --------------------------------------------------------------- the rows


func _build_slots() -> void:
	for i: int in SLOTS.size():
		_save_buttons.append(_slot_button(_save_row, _on_save_pressed.bind(i), true))
		_load_buttons.append(_slot_button(_load_row, _on_load_pressed.bind(i), false))


## A slot is a button with a caption under it, so the two rows line up.
func _slot_button(into: Container, action: Callable, with_caption: bool) -> ConsoleButton:
	var column: VBoxContainer = VBoxContainer.new()
	column.theme_type_variation = &"StackTight"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var button: ConsoleButton = ConsoleButton.new()
	button.pressed.connect(action)
	column.add_child(button)
	if with_caption:
		var caption: Label = Label.new()
		caption.theme_type_variation = &"LabelCaption"
		column.add_child(caption)
		_slot_captions.append(caption)
	into.add_child(column)
	return button


## §7.3 item 5: three settings, each a label and a button that says the state.
func _build_settings() -> void:
	for key: String in [KEY_LOCALE, KEY_REDUCED_MOTION, KEY_TREE_PAUSES]:
		var row: HBoxContainer = HBoxContainer.new()
		row.theme_type_variation = &"Row"
		var label: Label = Label.new()
		label.theme_type_variation = &"LabelCaption"
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = tr(key)
		label.set_meta(&"key", key)
		row.add_child(label)
		var button: ConsoleButton = ConsoleButton.new()
		button.pressed.connect(_on_setting_pressed.bind(_setting_buttons.size()))
		row.add_child(button)
		_setting_buttons.append(button)
		_settings_rows.add_child(row)


func _refresh_settings() -> void:
	for row: Node in _settings_rows.get_children():
		var label: Label = (row as Container).get_child(0) as Label
		label.text = tr(str(label.get_meta(&"key")))
	_setting_buttons[0].text = Format.caps(tr(KEY_LOCALE_DE if Settings.locale == "de" \
		else KEY_LOCALE_EN))
	_setting_buttons[1].text = Format.caps(tr(KEY_ON if Settings.reduced_motion else KEY_OFF))
	_setting_buttons[2].text = Format.caps(tr(KEY_ON if Settings.tree_pauses else KEY_OFF))


# ------------------------------------------------------------------ actions


func _on_resume_pressed() -> void:
	closed.emit()


func _on_save_pressed(index: int) -> void:
	var reason: String = SaveManager.save(SLOTS[index])
	if reason.is_empty():
		# The same arrival the revealed blocks use — a save that worked says so
		# by the slot's caption changing under a button that just lit up.
		Reveal.play(_save_buttons[index])
		refresh()
		return
	_show_failure(KEY_SAVE_FAILED, reason)


func _on_load_pressed(index: int) -> void:
	if not await _confirm.ask(KEY_LOAD_CONFIRM):
		return
	var reason: String = SaveManager.load(SLOTS[index])
	if not reason.is_empty():
		_show_failure(KEY_LOAD_FAILED, reason)
		return
	closed.emit()


func _on_setting_pressed(index: int) -> void:
	match index:
		0:
			Settings.toggle_locale()
		1:
			Settings.set_reduced_motion(not Settings.reduced_motion)
		_:
			Settings.set_tree_pauses(not Settings.tree_pauses)
	_refresh_settings()


func _on_quit_pressed() -> void:
	if await _confirm.ask(KEY_QUIT_CONFIRM):
		quit_requested.emit()


func _show_failure(key: String, reason: String) -> void:
	_failure.visible = true
	_failure.text = tr(key).format({PLACEHOLDER_REASON: tr(reason.to_upper())})
