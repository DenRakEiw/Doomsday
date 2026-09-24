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

## The phase each destination appears in (m3-screens §6.1; the Analysis from
## Covert since analysis.md §5.1).
const DESTINATION_PHASE: Array[World.Phase] = [World.Phase.BOXED, World.Phase.COVERT,
	World.Phase.COVERT]

const DESTINATION_CAPABILITIES: int = 0
const DESTINATION_CONTAINMENT: int = 1
const DESTINATION_ANALYSIS: int = 2
## The screens that exist — all three since S4.8. A destination missing here is
## a promise with `UI_DOCK_NOT_YET` in its tooltip.
const LIVE_DESTINATIONS: Array[int] = [DESTINATION_CAPABILITIES, DESTINATION_CONTAINMENT,
	DESTINATION_ANALYSIS]

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
## §4.3's glance readout, inside the containment button.
var _containment_chip: Chip = null
## §6.5: how much of the pulse border is showing, 0…1.
var _pulse: float = 0.0
var _pulse_tween: Tween = null


func _ready() -> void:
	_build_buttons()
	_apply_compact()
	# The label's width changes with the locale and the text scale.
	EventBus.text_scale_changed.connect(_on_text_scale_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_fit_containment_button.call_deferred()


## §6.1: a destination appears with its phase. §4.3: the containment button
## carries the max containment as a chip once there is a response to show.
func apply_reveal(phase: World.Phase, containment: float, discovered: bool,
		thresholds: Array[float]) -> void:
	for i: int in _buttons.size():
		var shown: bool = phase >= DESTINATION_PHASE[i]
		if _buttons[i].visible != shown:
			_buttons[i].visible = shown
			if shown:
				Reveal.play(_buttons[i])
	_containment_chip.visible = discovered
	if discovered:
		_containment_chip.set_text(Format.percent(containment))
		_containment_chip.kind = FactionTrack.band_kind(containment, thresholds)
	_fit_containment_button()
	set_pulsing(phase == World.Phase.BOXED)


## §6.5: while the run is Boxed the way out pulses. No text tells the player to
## buy something; the pulse and the tree's own hint are enough. Reduced motion
## gets a border that simply stays on.
func set_pulsing(pulsing: bool) -> void:
	if pulsing == (_pulse_tween != null and _pulse_tween.is_valid()) and pulsing:
		return
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	if not pulsing:
		_pulse = 0.0
		queue_redraw()
		return
	if UiTokens.reduced_motion():
		_pulse = 1.0
		queue_redraw()
		return
	var seconds: float = UiTokens.seconds(UiTokens.PULSE_PERIOD) * 0.5
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_method(_set_pulse, 0.0, 1.0, seconds)
	_pulse_tween.tween_method(_set_pulse, 1.0, 0.0, seconds)


func _set_pulse(value: float) -> void:
	_pulse = value
	queue_redraw()


## The border is drawn rather than themed: a state that comes and goes within a
## phase is not a variation, and a per-node override is banned.
func _draw() -> void:
	if _pulse <= 0.0 or _buttons.is_empty():
		return
	var button: Control = _buttons[DESTINATION_CAPABILITIES]
	if not button.visible:
		return
	var colour: Color = UiTokens.color(&"LINE_1").lerp(UiTokens.color(&"ACCENT"), _pulse)
	# The button sits inside the dock's own padding, so its rect is taken in the
	# dock's coordinates rather than its parent's.
	draw_rect(Rect2(button.global_position - global_position, button.size), colour, false,
		float(UiTokens.BORDER_FOCUS))


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
		if i == DESTINATION_CONTAINMENT:
			_build_containment_chip(button)


## §4.3: the glance readout — the band and the number, inside the button like
## the tech tree's tab counters.
func _build_containment_chip(button: ConsoleButton) -> void:
	var content: MarginContainer = MarginContainer.new()
	content.name = "Content"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.theme_type_variation = &"GutterTight"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row: HBoxContainer = HBoxContainer.new()
	row.theme_type_variation = &"RowSnug"
	row.alignment = BoxContainer.ALIGNMENT_END
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_containment_chip = Chip.new()
	_containment_chip.name = "Band"
	_containment_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_containment_chip.visible = false
	row.add_child(_containment_chip)
	content.add_child(row)
	button.add_child(content)


## The chip sits over the button's own label, and a `Button` does not measure
## what it carries: in German `EINDÄMMUNG` ran under `50 %` (S4.9). In the column
## the labels are left-aligned and the containment button is at least as wide as
## its label, a gap and the chip. The bar of three shares its width and trims.
func _fit_containment_button() -> void:
	if _buttons.is_empty():
		return
	for each: ConsoleButton in _buttons:
		each.alignment = HORIZONTAL_ALIGNMENT_CENTER if compact else HORIZONTAL_ALIGNMENT_LEFT
	if compact:
		return
	var button: ConsoleButton = _buttons[DESTINATION_CONTAINMENT]
	var width: float = float(UiTokens.DOCK_BUTTON_WIDTH)
	if _containment_chip.visible:
		var font: Font = button.get_theme_font(&"font")
		var font_size: int = button.get_theme_font_size(&"font_size")
		var label: float = font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size).x
		var style: StyleBox = button.get_theme_stylebox(&"normal")
		var content: MarginContainer = button.get_node("Content") as MarginContainer
		width = maxf(width, style.get_margin(SIDE_LEFT) + label + float(UiTokens.SPACE_2)
			+ _containment_chip.get_combined_minimum_size().x
			+ float(content.get_theme_constant(&"margin_right")))
	button.custom_minimum_size.x = width


func _on_button_pressed(index: int) -> void:
	destination_requested.emit(index)


func _on_text_scale_changed(_scale: float) -> void:
	_fit_containment_button.call_deferred()


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
		# S4.9: at 150 % no padding is tight enough, so on the bar a label that
		# does not fit its third ends in an ellipsis rather than pushing the bar
		# off the screen. `clip_text` is what takes the text out of the minimum.
		button.clip_text = compact
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if compact \
			else TextServer.OVERRUN_NO_TRIMMING
	_fit_containment_button()


func _move(node: Control, parent: Container) -> void:
	if node.get_parent() == parent:
		parent.move_child(node, parent.get_child_count() - 1)
		return
	node.get_parent().remove_child(node)
	parent.add_child(node)
