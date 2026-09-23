extends PanelContainer
## The phone's one strip of state (spec m3-screens.md §9.1).
##
## Three readouts, the containment chip and the way into the menu sheet. It
## replaces the dock bar and the stacked stat row below the breakpoint; the bars
## themselves are one tap away in the sheet, never gone.
##
## Scene-specific, so no `class_name`.

## A readout was tapped: the sheet opens with the bars at the top.
signal bars_requested
signal menu_requested

const KEYS: Array[String] = ["UI_TERM_PENETRATION", "UI_TERM_FOOTPRINT", "UI_TERM_HARM"]
const KINDS: Array[Format.Kind] = [Format.Kind.PERCENT, Format.Kind.PLAIN, Format.Kind.PLAIN]

@onready var _row: HBoxContainer = %StripRow
@onready var _chip: Chip = %StripChip
@onready var _menu: IconButton = %StripMenu

## One `[button, caption, value]` per readout, in the order of `KEYS`.
var _values: Array[ValueLabel] = []
var _buttons: Array[ConsoleButton] = []


func _ready() -> void:
	custom_minimum_size.y = float(UiTokens.STATUS_STRIP_HEIGHT)
	_build_readouts()
	_menu.pressed.connect(menu_requested.emit)
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.run_started.connect(_on_run_started)
	refresh()


## The same numbers the three bars show (§9.1).
func refresh() -> void:
	var world: World = Game.sim.world if Game.sim != null else null
	if world == null:
		return
	var penetration: float = world.infected_share(Game.db)
	_values[0].set_number(penetration, KINDS[0])
	_values[1].set_number(world.footprint(), KINDS[1])
	_values[2].set_number(world.max_harm(), KINDS[2])
	_chip.visible = world.discovered
	if world.discovered:
		_chip.set_text(Format.percent(world.max_containment()))
		_chip.kind = FactionTrack.band_kind(world.max_containment(),
			Game.db.balance.containment_thresholds)


## §6.1: the readouts appear with their bars.
func apply_reveal(phase: World.Phase, harm: float) -> void:
	_buttons[1].visible = phase >= World.Phase.COVERT
	_buttons[2].visible = phase >= World.Phase.EMERGENT \
		or (phase >= World.Phase.COVERT and harm > 0.0)


## §6.5: the way to the tree pulses while the run is Boxed, as the dock does.
func set_pulsing(pulsing: bool) -> void:
	_menu.modulate = Color.WHITE
	_menu.set_meta(&"pulsing", pulsing)


func _build_readouts() -> void:
	for i: int in KEYS.size():
		var button: ConsoleButton = ConsoleButton.new()
		button.list_row = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(bars_requested.emit)
		var column: VBoxContainer = VBoxContainer.new()
		column.theme_type_variation = &"StackTight"
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var caption: CapsLabel = CapsLabel.new()
		caption.label_key = KEYS[i]
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var value: ValueLabel = ValueLabel.new()
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(caption)
		column.add_child(value)
		button.add_child(column)
		_row.add_child(button)
		_buttons.append(button)
		_values.append(value)


func _on_tick_advanced(_day: int) -> void:
	refresh()


func _on_run_started(_seed_value: int) -> void:
	refresh()
