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

## m3-screens §7.3: the pause menu, from the bar itself.
signal menu_requested

## `loop-mechanics.md` §17.3: the chip after the day cell that brings a waiting
## global event back.
const KEY_EVENT_PENDING: String = "UI_HUD_EVENT_PENDING"
const PLACEHOLDER_COUNT: String = "count"

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
## The compute cell's share of the phone row against the phase and day cells.
const COMPUTE_STRETCH: float = 2.0

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
## `loop-mechanics.md` §16.9: what the agent has on the ground, after the day
## cell. Built here rather than in the scene, because the readout is one node
## that both layouts share.
@onready var _assets: AssetReadout = AssetReadout.new()
@onready var _spacer: Control = %Spacer
@onready var _paused: Chip = %PausedChip
@onready var _speed_group: HBoxContainer = %SpeedGroup
@onready var _menu_button: IconButton = %MenuButton

var _speed_buttons: Array[IconButton] = []
## `loop-mechanics.md` §16.7: the global events put away with `Escape`, waiting —
## a tap brings the oldest back into the wire card.
var _pending: Chip = null
## §9.4: shown while the agent is starving, `ALERT` in the last days.
var _starving: Chip = null


func _ready() -> void:
	_row_main.add_child(_assets)
	_row_main.move_child(_assets, _day_cell.get_index() + 1)
	_pending = Chip.new()
	_pending.kind = Chip.Kind.ALERT
	_pending.visible = false
	_pending.mouse_filter = Control.MOUSE_FILTER_STOP
	_pending.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_pending.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pending.gui_input.connect(_on_pending_input)
	_row_main.add_child(_pending)
	_row_main.move_child(_pending, _assets.get_index() + 1)
	_starving = StarvingChip.create()
	_row_main.add_child(_starving)
	_row_main.move_child(_starving, _pending.get_index())
	_build_speed_buttons()
	_menu_button.pressed.connect(menu_requested.emit)
	_apply_compact()
	EventBus.run_started.connect(_on_run_started)
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.command_applied.connect(_on_command_applied)
	EventBus.speed_changed.connect(_on_speed_changed)
	EventBus.hold_changed.connect(_on_hold_changed)
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
	_refresh_pending(world)
	StarvingChip.apply(_starving, Game.sim)


## The global events standing open — only a person answers them, so a bot run
## shows none (§16.7).
func _refresh_pending(world: World) -> void:
	var waiting: Array[OpenEvent] = world.events_in_region(0)
	# While a modal holds the run the chip only pointed at the card already up
	# behind the scrim (S4.3's note, S4.P).
	_pending.visible = not waiting.is_empty() and Game.policy == null and not Game.is_held()
	if _pending.visible:
		_pending.set_label(KEY_EVENT_PENDING, {PLACEHOLDER_COUNT: waiting.size()})


func _on_hold_changed(_held: bool) -> void:
	if Game.sim != null:
		_refresh_pending(Game.sim.world)


## The starving chip, for the tests.
func starving_chip() -> Chip:
	return _starving


## The pending chip, for the tests.
func pending_chip() -> Chip:
	return _pending


func _on_pending_input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press == null or not press.pressed or press.button_index != MOUSE_BUTTON_LEFT:
		return
	if Game.sim == null:
		return
	var waiting: Array[OpenEvent] = Game.sim.world.events_in_region(0)
	if not waiting.is_empty():
		EventBus.wire_requested.emit(waiting[0].id)


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
	# §9.3 puts the menu button in the compact top bar too, but neither row has
	# 48 px to spare in German (row 1 needs 397 of 400, row 2 389). On a phone
	# the status strip's own MENU button and the sheet's pause entry are the two
	# routes to the menu, so the bar's button is a desktop control
	# (PROGRESS.md, *Deviations*).
	_menu_button.visible = not compact
	# §16.9: on a phone the readout is the status strip's second row, so the bar
	# gives it up rather than squeezing a fifth cell into 400 px.
	_assets.enabled = not compact
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
	# A rate with a decimal (`13,6 ▲ +0,1 / Tag`) is 250 px of the phone's 400
	# in German; the figure comes first, so on a phone the rate gives way
	# (S4.6, PROGRESS *Design questions*).
	var overrun: TextServer.OverrunBehavior = TextServer.OVERRUN_TRIM_ELLIPSIS if compact \
		else TextServer.OVERRUN_NO_TRIMMING
	_compute_value.text_overrun_behavior = overrun
	# S4.9: German at 150 % makes `RECHENLEISTUNG` half the phone's width. The
	# caption gives way before the figure under it does; each cell's first child
	# is its caption.
	for cell: Control in [_compute_cell, _phase_cell, _day_cell]:
		(cell.get_child(0) as Label).text_overrun_behavior = overrun
	# With the captions free to shrink, the three cells would share the row in
	# thirds; the compute cell carries a figure and a rate, so it takes two.
	_compute_cell.size_flags_stretch_ratio = COMPUTE_STRETCH if compact else 1.0
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
