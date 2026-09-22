class_name ConfirmModal
extends Control
## A two-button question (spec m3-screens.md §7.3).
##
## `await confirm.ask("UI_PAUSE_QUIT_CONFIRM")` answers true or false. M4's
## events ask their questions through the same component.

## Emitted with the answer, for a caller that would rather connect than await.
signal answered(confirmed: bool)

const KEY_CANCEL: String = "UI_COMMON_CANCEL"
const KEY_CONFIRM: String = "UI_COMMON_CONFIRM"

@onready var _question: Label = %ConfirmQuestion
@onready var _cancel: ConsoleButton = %CancelButton
@onready var _confirm: ConsoleButton = %ConfirmButton
@onready var _panel: PanelContainer = %ConfirmPanel


func _ready() -> void:
	_panel.custom_minimum_size.x = float(UiTokens.MODAL_MAX_WIDTH)
	_cancel.pressed.connect(_answer.bind(false))
	_confirm.pressed.connect(_answer.bind(true))
	visible = false


## Shows the question and waits for the answer. The caller decides where the
## modal lives; this only fills it in and listens.
func ask(question_key: String) -> bool:
	_question.text = tr(question_key)
	visible = true
	_cancel.grab_focus.call_deferred()
	return await answered


## `Escape` is Cancel (§7.3).
func on_escape() -> void:
	_answer(false)


func _answer(confirmed: bool) -> void:
	visible = false
	answered.emit(confirmed)
