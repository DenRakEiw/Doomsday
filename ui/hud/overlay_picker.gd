extends PanelContainer
## What the map colours by (spec ui-foundation.md §5.4).
##
## The picker never touches the map: it emits `EventBus.overlay_changed`, which
## `MapView` listens to (§7.2). One signal, one direction — a later screen that
## wants the same switch needs no reference to the map either.
##
## §5.7's compact form is one button that cycles, because three buttons of a
## readable width do not fit next to a 400 px map.
##
## Scene-specific, so no `class_name`.

## §7.2's three modes, in order, and the term each one shows.
const MODE_KEYS: Array[String] = ["UI_TERM_PENETRATION", "UI_TERM_CONTROL",
	"UI_TERM_POPULATION"]

## §5.7: three toggles, or one button that steps through them.
var compact: bool = false:
	set(value):
		if value == compact and is_node_ready():
			return
		compact = value
		if is_node_ready():
			_apply_compact()

## The mode the map is drawing, as a `MapView.Overlay`.
var mode: int = int(MapView.Overlay.PENETRATION)

@onready var _row: HBoxContainer = %Row
@onready var _cycle: ConsoleButton = %Cycle

var _buttons: Array[ConsoleButton] = []


func _ready() -> void:
	add_to_group(CoachRing.group(CoachRing.TARGET_OVERLAY))
	_build_buttons()
	_cycle.pressed.connect(_on_cycle_pressed)
	_apply_compact()
	_apply_mode()


## The three toggles of §5.4 as one group. Built here so that adding a mode is a
## key in `MODE_KEYS` and nothing else.
func _build_buttons() -> void:
	var group: ButtonGroup = ButtonGroup.new()
	for i: int in MODE_KEYS.size():
		var button: ConsoleButton = ConsoleButton.new()
		button.label_key = MODE_KEYS[i]
		button.toggle_mode = true
		button.button_group = group
		button.pressed.connect(_on_mode_pressed.bind(i))
		_row.add_child(button)
		_buttons.append(button)
	_buttons[mode].set_pressed_no_signal(true)


## §6.1: nothing to compare in Boxed, two modes in Covert, the population from
## Emergent on. A mode that is no longer offered falls back to penetration.
func apply_reveal(phase: World.Phase) -> void:
	var allowed: int = _modes_for(phase)
	visible = allowed > 0
	for i: int in _buttons.size():
		_buttons[i].visible = i < allowed
	if mode >= allowed:
		_set_mode(int(MapView.Overlay.PENETRATION))


static func _modes_for(phase: World.Phase) -> int:
	match phase:
		World.Phase.BOXED:
			return 0
		World.Phase.COVERT:
			return 2
		_:
			return MODE_KEYS.size()


func _apply_compact() -> void:
	_row.visible = not compact
	_cycle.visible = compact


func _apply_mode() -> void:
	_buttons[mode].set_pressed_no_signal(true)
	_cycle.label_key = MODE_KEYS[mode]


func _set_mode(new_mode: int) -> void:
	if new_mode == mode:
		return
	mode = new_mode
	_apply_mode()
	EventBus.overlay_changed.emit(mode)


func _on_mode_pressed(index: int) -> void:
	_set_mode(index)


func _on_cycle_pressed() -> void:
	_set_mode((mode + 1) % MODE_KEYS.size())
