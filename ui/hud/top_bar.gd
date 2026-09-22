extends PanelContainer
## The strip along the top of the run (spec ui-foundation.md §5.2): compute and
## its rate, the phase, the day, and the speed control.
##
## Everything it shows is read from `Game.sim.world` after a tick — the HUD keeps
## no numbers of its own, because a second source of truth next to the `World` is
## exactly what this architecture avoids.
##
## §5.7's compact form is the same nodes on two rows of 48 instead of one of 56,
## re-parented like `StatBar`'s.
##
## Scene-specific, so no `class_name`.

const KEY_COMPUTE_RATE: String = "UI_HUD_COMPUTE_RATE"
const KEY_DAY: String = "UI_HUD_DAY"
const PLACEHOLDER_RATE: String = "rate"
const PLACEHOLDER_DAY: String = "day"

## §5.2's four speed buttons, in the order they sit in: the speed each one sets
## and the glyph and tooltip it carries.
const SPEED_VALUES: Array[int] = [0, 1, 2, 4]
const SPEED_GLYPHS: Array[Glyphs.Glyph] = [Glyphs.Glyph.PAUSE, Glyphs.Glyph.PLAY,
	Glyphs.Glyph.FAST_2, Glyphs.Glyph.FAST_4]
const SPEED_KEYS: Array[String] = ["UI_HUD_SPEED_PAUSE", "UI_HUD_SPEED_1", "UI_HUD_SPEED_2",
	"UI_HUD_SPEED_4"]
## The phase the chip is drawn for, by `World.Phase`. Emergent is the moment the
## world finds you, and it alone is an alert: red marks a moment, never a
## standing state, so Open goes back to the default chip and takes its colour
## from D3.3's palette instead (§5.2, G2).
const PHASE_KEYS: Array[String] = ["UI_PHASE_BOXED", "UI_PHASE_COVERT", "UI_PHASE_EMERGENT",
	"UI_PHASE_OPEN"]
const PHASE_CHIP_KINDS: Array[Chip.Kind] = [Chip.Kind.DEFAULT, Chip.Kind.ACCENT,
	Chip.Kind.ALERT, Chip.Kind.DEFAULT]

## The gap between the cells: §5.2's `SPACE_5` when there is room for it.
const VARIATION_ROW_WIDE: StringName = &"RowWide"
const VARIATION_ROW: StringName = &"Row"

## §5.7: one row of `TOP_BAR_HEIGHT`, or two of `TOP_BAR_ROW_HEIGHT`.
var compact: bool = false:
	set(value):
		if value == compact and is_node_ready():
			return
		compact = value
		if is_node_ready():
			_apply_compact()

@onready var _row_main: HBoxContainer = %RowMain
@onready var _row_second: HBoxContainer = %RowSecond
@onready var _compute_cell: VBoxContainer = %ComputeCell
@onready var _compute_value: ValueLabel = %ComputeValue
@onready var _phase_cell: VBoxContainer = %PhaseCell
@onready var _phase_chip: Chip = %PhaseChip
@onready var _day_cell: VBoxContainer = %DayCell
@onready var _day_value: ValueLabel = %DayValue
@onready var _spacer: Control = %Spacer
@onready var _paused: Chip = %PausedChip
@onready var _speed_group: HBoxContainer = %SpeedGroup

var _speed_buttons: Array[IconButton] = []


func _ready() -> void:
	_build_speed_buttons()
	_apply_compact()
	EventBus.run_started.connect(_on_run_started)
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.command_applied.connect(_on_command_applied)
	EventBus.speed_changed.connect(_on_speed_changed)
	_on_speed_changed(Game.speed)
	refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		# Every string here wraps a number, so re-reading the state is also what
		# puts the new language on the screen (§9.1).
		refresh()


## Re-reads the run. Cheap, and called after anything that may have moved a
## number: a tick, a command, a new run, a language.
func refresh() -> void:
	var world: World = Game.sim.world if Game.sim != null else null
	if world == null:
		_compute_value.set_number(0.0, Format.Kind.COMPUTE)
		_compute_value.clear_delta()
		_day_value.set_number_in(KEY_DAY, PLACEHOLDER_DAY, 0.0, Format.Kind.DAYS)
		_set_phase(World.Phase.BOXED)
		return
	_compute_value.set_number(world.agent.compute, Format.Kind.COMPUTE)
	_compute_value.set_delta_in(KEY_COMPUTE_RATE, PLACEHOLDER_RATE, Game.compute_rate,
		Format.Kind.COMPUTE)
	_day_value.set_number_in(KEY_DAY, PLACEHOLDER_DAY, float(world.day), Format.Kind.DAYS)
	_set_phase(world.phase)


func _set_phase(phase: World.Phase) -> void:
	_phase_chip.kind = PHASE_CHIP_KINDS[phase]
	_phase_chip.label_key = PHASE_KEYS[phase]


## The four buttons of §5.2 as one toggle group, built here so that the scene
## does not repeat the same node four times with three properties changed.
func _build_speed_buttons() -> void:
	var group: ButtonGroup = ButtonGroup.new()
	for i: int in SPEED_VALUES.size():
		var button: IconButton = IconButton.new()
		button.glyph = SPEED_GLYPHS[i]
		button.tooltip_key = SPEED_KEYS[i]
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_on_speed_pressed.bind(SPEED_VALUES[i]))
		_speed_group.add_child(button)
		_speed_buttons.append(button)


## §5.7: in the compact layout the speed group and the paused badge move to a
## second row, and the three cells share the first one.
func _apply_compact() -> void:
	_row_second.visible = compact
	var second: HBoxContainer = _row_second if compact else _row_main
	for node: Control in [_spacer, _paused, _speed_group]:
		_move(node, second)
	var cell_flags: int = int(Control.SIZE_EXPAND_FILL) if compact else int(Control.SIZE_FILL)
	for cell: Control in [_compute_cell, _phase_cell, _day_cell]:
		cell.size_flags_horizontal = cell_flags
	# On a 400 px row the three cells share the width, so the compute cell gives
	# up the 200 it keeps in the wide layout, the gap between them shrinks, and
	# the compute readout drops from `TYPE_DATA_LG` to `TYPE_DATA` — a row of 48
	# has no room for the big figure and its caption.
	_compute_cell.custom_minimum_size.x = 0.0 if compact else float(UiTokens.CELL_MIN_WIDTH)
	_row_main.theme_type_variation = VARIATION_ROW if compact else VARIATION_ROW_WIDE
	_compute_value.large = not compact
	var row_height: int = UiTokens.TOP_BAR_ROW_HEIGHT if compact else UiTokens.TOP_BAR_HEIGHT
	_row_main.custom_minimum_size.y = float(row_height)
	_row_second.custom_minimum_size.y = float(UiTokens.TOP_BAR_ROW_HEIGHT)


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


func _on_speed_pressed(speed: int) -> void:
	Game.set_speed(speed)


func _on_speed_changed(speed: int) -> void:
	_paused.visible = speed == 0
	var index: int = SPEED_VALUES.find(speed)
	# A `ButtonGroup` is exclusive only against a *click*: `set_pressed_no_signal`
	# presses a button without releasing the rest of its group, and after a few
	# speed changes pause, play and 4× were lit at once (G2). So the whole group
	# is written every time, and the pressed one is whatever `Game.speed` says.
	for i: int in _speed_buttons.size():
		_speed_buttons[i].set_pressed_no_signal(i == index)
