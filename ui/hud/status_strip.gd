extends PanelContainer
## The phone's one strip of state (spec m3-screens.md §9.1).
##
## Four readouts and the way into the menu sheet. It replaces the dock bar and
## the stacked stat row below the breakpoint; the bars themselves are one tap
## away in the sheet, never gone. The fourth readout is the threat (opposition.md
## §9.1): the risk until they know, the leading faction after.
##
## Scene-specific, so no `class_name`.

## A readout was tapped: the sheet opens with the bars at the top.
signal bars_requested
signal menu_requested

const KEYS: Array[String] = ["UI_TERM_PENETRATION", "UI_TERM_FOOTPRINT", "UI_TERM_HARM"]
const KINDS: Array[Format.Kind] = [Format.Kind.PERCENT, Format.Kind.PLAIN, Format.Kind.PLAIN]
const KEY_RISK: String = "UI_TERM_RISK"
const PREFIX_FACTION: String = "FACTION_"

@onready var _row: HBoxContainer = %StripRow
@onready var _menu: IconButton = %StripMenu
@onready var _rows: VBoxContainer = %StripRows
## `loop-mechanics.md` §16.9: the readout is the strip's second row on a phone.
var _assets: AssetReadout = null

## One `[button, caption, value]` per readout, in the order of `KEYS`.
var _values: Array[ValueLabel] = []
var _buttons: Array[ConsoleButton] = []
## The fourth readout's parts: the caption says Risk before discovery, the glyph
## names the leader after it.
var _threat_button: ConsoleButton = null
var _threat_caption: CapsLabel = null
var _threat_glyph: GlyphIcon = null
var _threat_value: ValueLabel = null


func _ready() -> void:
	custom_minimum_size.y = float(UiTokens.STATUS_STRIP_HEIGHT)
	_assets = AssetReadout.new()
	_rows.add_child(_assets)
	_build_readouts()
	_build_threat()
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
	_apply_threat(world)


## §9.1, compact: the fine risk under its caption, or the leader's glyph beside
## its containment.
func _apply_threat(world: World) -> void:
	var leader: String = Game.sim.threat_leader()
	_threat_caption.visible = leader.is_empty()
	_threat_glyph.visible = not leader.is_empty()
	if leader.is_empty():
		_threat_value.set_number(float(Game.sim.discovery_risk()[ContainmentSystem.RISK_TOTAL]),
			Format.Kind.PERCENT_FINE)
		_threat_button.tooltip_text = tr(KEY_RISK)
		return
	_threat_glyph.glyph = Glyphs.faction(leader)
	_threat_glyph.color_token = UiTokens.FACTION_TOKENS[leader]
	_threat_value.set_number(world.faction(leader).containment, Format.Kind.PERCENT)
	_threat_button.tooltip_text = tr(PREFIX_FACTION + leader.to_upper())


## §6.1: the readouts appear with their bars.
func apply_reveal(phase: World.Phase, harm: float) -> void:
	_buttons[1].visible = phase >= World.Phase.COVERT
	_buttons[2].visible = phase >= World.Phase.EMERGENT \
		or (phase >= World.Phase.COVERT and harm > 0.0)
	_threat_button.visible = phase >= World.Phase.COVERT


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
		# Four readouts share 400 px (opposition.md §9.1): a long German caption
		# ends in an ellipsis rather than pushing its number out of the button.
		caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var value: ValueLabel = ValueLabel.new()
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(caption)
		column.add_child(value)
		button.add_child(column)
		_row.add_child(button)
		_buttons.append(button)
		_values.append(value)


func _build_threat() -> void:
	_threat_button = ConsoleButton.new()
	_threat_button.list_row = true
	_threat_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_threat_button.pressed.connect(bars_requested.emit)
	var column: VBoxContainer = VBoxContainer.new()
	column.theme_type_variation = &"StackTight"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_threat_caption = CapsLabel.new()
	_threat_caption.label_key = KEY_RISK
	_threat_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_threat_caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var line: HBoxContainer = HBoxContainer.new()
	line.theme_type_variation = &"RowTight"
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_threat_glyph = GlyphIcon.new()
	_threat_glyph.box_size = UiTokens.FACTION_GLYPH
	_threat_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_threat_glyph.visible = false
	_threat_value = ValueLabel.new()
	_threat_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(_threat_glyph)
	line.add_child(_threat_value)
	column.add_child(_threat_caption)
	column.add_child(line)
	_threat_button.add_child(column)
	_row.add_child(_threat_button)


func _on_tick_advanced(_day: int) -> void:
	refresh()


func _on_run_started(_seed_value: int) -> void:
	refresh()
