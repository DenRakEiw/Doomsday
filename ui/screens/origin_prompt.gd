extends PanelContainer
## "Choose where you wake up" (spec m3-screens.md §7.2).
##
## A strip under the top bar while `agent.origin == 0`, and nothing at all
## afterwards. It says what to do; the region panel is where it is done.
##
## Scene-specific, so no `class_name`.

const KEY_PROMPT: String = "UI_ORIGIN_PROMPT"
const KEY_DETAIL: String = "UI_ORIGIN_PROMPT_DETAIL"
## §7.2: an island in the full layout, the whole width on a phone.
const MAX_WIDTH: float = 640.0

@onready var _prompt: Label = %OriginPrompt
@onready var _detail: Label = %OriginDetail


func _ready() -> void:
	EventBus.run_started.connect(_on_run_started)
	EventBus.command_applied.connect(_on_command_applied)
	_refresh_strings()
	refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_strings()


## The compact layout gives the strip the whole width; the full one centres it.
func set_compact(compact: bool) -> void:
	custom_minimum_size.x = 0.0 if compact else MAX_WIDTH
	size_flags_horizontal = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_SHRINK_CENTER


func refresh() -> void:
	visible = Game.sim != null and Game.sim.world.agent.origin == 0


func _refresh_strings() -> void:
	_prompt.text = tr(KEY_PROMPT)
	_detail.text = tr(KEY_DETAIL)


func _on_run_started(_seed_value: int) -> void:
	refresh()


func _on_command_applied(_command: Command, _result: CommandResult) -> void:
	refresh()
