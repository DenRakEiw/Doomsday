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
	_cancel.pressed.connect(_answer.bind(false))
	_confirm.pressed.connect(_answer.bind(true))
	visible = false


## Shows the question and waits for the answer. The caller decides where the
## modal lives; this only fills it in and listens.
func ask(question_key: String) -> bool:
	_question.text = tr(question_key)
	# accessibility.md §3.4: the question is what a screen reader hears with the
	# focused *Cancel*, since this one opens inside another modal.
	_cancel.accessibility_description = _question.text
	_confirm.accessibility_description = _question.text
	visible = true
	_cancel.grab_focus.call_deferred()
	return await answered


## accessibility.md §3.4: what is spoken when the modal opens — the question.
func a11y_summary() -> String:
	return _question.text


## `Escape` is Cancel (§7.3).
func on_escape() -> void:
	_answer(false)


func _answer(confirmed: bool) -> void:
	visible = false
	answered.emit(confirmed)
