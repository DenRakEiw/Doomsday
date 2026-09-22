extends PanelContainer
## The three destinations of the run (spec ui-foundation.md §5.5): capabilities,
## containment, analysis.
##
## A button whose screen does not exist yet is disabled and says so in its
## tooltip; `LIVE_DESTINATIONS` is what changes as the screens land. The dock
## exists in full from M2 because its shape decides the HUD's, and a button that
## appeared later would move everything around it.
##
## Scene-specific, so no `class_name`.

## One of these was pressed; the index is a `DESTINATION_*`.
signal destination_requested(index: int)

const BUTTON_KEYS: Array[String] = ["UI_DOCK_CAPABILITIES", "UI_DOCK_CONTAINMENT",
	"UI_DOCK_ANALYSIS"]
const KEY_NOT_YET: String = "UI_DOCK_NOT_YET"

const DESTINATION_CAPABILITIES: int = 0
const DESTINATION_CONTAINMENT: int = 1
const DESTINATION_ANALYSIS: int = 2
## The screens that exist. S3.3 adds containment, S4.7 analysis; until then the
## button is a promise with `UI_DOCK_NOT_YET` in its tooltip.
const LIVE_DESTINATIONS: Array[int] = [DESTINATION_CAPABILITIES]

## §5.7: an island of three stacked buttons, or a full-width bar of three.
var compact: bool = false:
	set(value):
		if value == compact and is_node_ready():
			return
		compact = value
		if is_node_ready():
			_apply_compact()

@onready var _column: VBoxContainer = %Column
@onready var _row: HBoxContainer = %Row

var _buttons: Array[ConsoleButton] = []


func _ready() -> void:
	_build_buttons()
	_apply_compact()


func _build_buttons() -> void:
	for i: int in BUTTON_KEYS.size():
		var button: ConsoleButton = ConsoleButton.new()
		button.label_key = BUTTON_KEYS[i]
		var live: bool = LIVE_DESTINATIONS.has(i)
		button.disabled = not live
		if not live:
			button.tooltip_key = KEY_NOT_YET
		button.custom_minimum_size = Vector2(float(UiTokens.DOCK_BUTTON_WIDTH),
			float(UiTokens.DOCK_BUTTON_HEIGHT))
		button.pressed.connect(_on_button_pressed.bind(i))
		_column.add_child(button)
		_buttons.append(button)


func _on_button_pressed(index: int) -> void:
	destination_requested.emit(index)


func _apply_compact() -> void:
	_column.visible = not compact
	_row.visible = compact
	var parent: Container = (_row as Container) if compact else (_column as Container)
	for button: ConsoleButton in _buttons:
		_move(button, parent)
		button.size_flags_horizontal = int(Control.SIZE_EXPAND_FILL) if compact \
			else int(Control.SIZE_FILL)
		# A bar of three shares the width, so no button insists on 200 of it —
		# and at 400 px the three German labels only fit with the tighter
		# padding of `ConsoleButtonCompact`.
		button.custom_minimum_size.x = 0.0 if compact else float(UiTokens.DOCK_BUTTON_WIDTH)
		button.compact = compact


func _move(node: Control, parent: Container) -> void:
	if node.get_parent() == parent:
		parent.move_child(node, parent.get_child_count() - 1)
		return
	node.get_parent().remove_child(node)
	parent.add_child(node)
