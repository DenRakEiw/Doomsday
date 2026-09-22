extends PanelContainer
## The three numbers a run is judged by (spec ui-foundation.md §5.3):
## penetration, footprint and harm.
##
## Penetration is a share and fills the bar honestly. Footprint and harm have no
## natural maximum — they are stats, not percentages — so the bar fills against a
## presentation maximum (`UiTokens`) while the label reads the raw number.
##
## Scene-specific, so no `class_name`.

const KEY_PENETRATION: String = "UI_TERM_PENETRATION"
const KEY_FOOTPRINT: String = "UI_TERM_FOOTPRINT"
const KEY_HARM: String = "UI_TERM_HARM"
## The modifier target the harm bar reads (`data/SCHEMA.md` §4.1).
const TARGET_HARM: String = "harm"

## §5.7: three bars side by side, or stacked in their compact form.
var compact: bool = false:
	set(value):
		if value == compact and is_node_ready():
			return
		compact = value
		if is_node_ready():
			_apply_compact()

@onready var _row: HBoxContainer = %Row
@onready var _column: VBoxContainer = %Column
@onready var _penetration: StatBar = %Penetration
@onready var _footprint: StatBar = %Footprint
@onready var _harm: StatBar = %Harm


func _ready() -> void:
	_apply_compact()
	EventBus.run_started.connect(_on_run_started)
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.command_applied.connect(_on_command_applied)
	refresh()


## Re-reads the run. A purchase moves footprint and harm between two ticks, so
## this is called after a command as well as after a day.
func refresh() -> void:
	var world: World = Game.sim.world if Game.sim != null else null
	if world == null or Game.db == null:
		_penetration.set_value(0.0)
		_footprint.set_value_raw(0.0, 0.0, Format.Kind.PLAIN)
		_harm.set_value_raw(0.0, 0.0, Format.Kind.PLAIN)
		return
	_penetration.set_value(world.infected_share(Game.db))
	var footprint: float = world.footprint()
	_footprint.set_value_raw(footprint / UiTokens.FOOTPRINT_BAR_MAX, footprint,
		Format.Kind.PLAIN)
	var harm: float = world.modifiers.value(TARGET_HARM)
	_harm.set_value_raw(harm / UiTokens.HARM_BAR_MAX, harm, Format.Kind.PLAIN)


func _apply_compact() -> void:
	_row.visible = not compact
	_column.visible = compact
	var parent: Container = (_column as Container) if compact else (_row as Container)
	for bar: StatBar in [_penetration, _footprint, _harm]:
		_move(bar, parent)
		bar.compact = compact
		bar.size_flags_horizontal = int(Control.SIZE_FILL) if compact \
			else int(Control.SIZE_EXPAND_FILL)
		bar.size_flags_stretch_ratio = 1.0
	custom_minimum_size.y = float(UiTokens.STAT_ROW_COMPACT_HEIGHT if compact
		else UiTokens.STAT_ROW_HEIGHT)


func _move(node: Control, parent: Container) -> void:
	if node.get_parent() == parent:
		parent.move_child(node, parent.get_child_count() - 1)
		return
	node.get_parent().remove_child(node)
	parent.add_child(node)


func _on_run_started(_seed_value: int) -> void:
	refresh()


func _on_tick_advanced(_day: int) -> void:
	refresh()


func _on_command_applied(_command: Command, _result: CommandResult) -> void:
	refresh()
