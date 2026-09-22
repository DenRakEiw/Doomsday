extends PanelContainer
## The three destinations of the run (spec ui-foundation.md §5.5): capabilities,
## containment, analysis.
##
## All three are disabled in M2 and say so in their tooltip — the screens behind
## them are M3's. The dock exists now because its shape decides the HUD's, and a
## button that appears later would move everything around it.
##
## Scene-specific, so no `class_name`.

const BUTTON_KEYS: Array[String] = ["UI_DOCK_CAPABILITIES", "UI_DOCK_CONTAINMENT",
	"UI_DOCK_ANALYSIS"]
const KEY_NOT_YET: String = "UI_DOCK_NOT_YET"

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
	for key: String in BUTTON_KEYS:
		var button: ConsoleButton = ConsoleButton.new()
		button.label_key = key
		button.tooltip_key = KEY_NOT_YET
		# M3 enables these; until then the dock is a promise, not a control.
		button.disabled = true
		button.custom_minimum_size = Vector2(float(UiTokens.DOCK_BUTTON_WIDTH),
			float(UiTokens.DOCK_BUTTON_HEIGHT))
		_column.add_child(button)
		_buttons.append(button)


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
