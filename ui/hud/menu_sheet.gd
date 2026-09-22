extends SlidePanel
## The phone's menu (spec m3-screens.md §9.2): the three bars, the three
## destinations, and the way into the pause menu.
##
## The bars are the HUD's own — the sheet borrows the stat row while the layout
## is compact and gives it back when it is not, so there is one set of bars in
## the game.
##
## Scene-specific, so no `class_name`.

## A destination was chosen (`dock.gd`'s `DESTINATION_*`).
signal destination_requested(index: int)
signal pause_requested

const DOCK: GDScript = preload("res://ui/hud/dock.gd")
const KEY_PAUSE: String = "UI_MENU_PAUSE"
const KEY_TITLE: String = "UI_MENU_TITLE"
const KEY_NOT_YET: String = "UI_DOCK_NOT_YET"

@onready var _title: Label = %SheetTitle
@onready var _close_button: IconButton = %SheetClose
@onready var _bars_slot: VBoxContainer = %BarsSlot
@onready var _destinations: VBoxContainer = %Destinations
@onready var _pause_entry: ConsoleButton = %PauseEntry

var _buttons: Array[ConsoleButton] = []
## Where the stat row came from, so it can go home — and who owned it, because
## taking a node out of the tree clears the owner and with it every `%` name
## below it (PROGRESS.md, *Known issues*).
var _row_home: Node = null
var _row_owner: Node = null
var _stat_row: Control = null


func _ready() -> void:
	super()
	height_share = UiTokens.SHEET_HEIGHT_RATIO
	edge = SlidePanel.Edge.BOTTOM
	_build_destinations()
	_close_button.pressed.connect(close)
	_pause_entry.pressed.connect(_on_pause_pressed)
	_refresh_strings()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_strings()


## Borrows the stat row while the layout is compact (§9.2 item 1).
func adopt_stat_row(row: Control) -> void:
	if row == null or _stat_row == row:
		return
	_stat_row = row
	_row_home = row.get_parent()
	_row_owner = row.owner
	_row_home.remove_child(row)
	_bars_slot.add_child(row)
	# No owner while it is here: an owner has to be an ancestor, and the HUD is
	# not one any more.
	row.visible = true
	row.set(&"compact", true)


func release_stat_row() -> void:
	if _stat_row == null:
		return
	_bars_slot.remove_child(_stat_row)
	_row_home.add_child(_stat_row)
	_stat_row.owner = _row_owner
	# Re-registers the `%` name the removal dropped.
	_stat_row.unique_name_in_owner = true
	_stat_row = null
	_row_home = null
	_row_owner = null


## §6.1: the destinations appear with their phases, like the dock's buttons.
func apply_reveal(phase: World.Phase) -> void:
	var phases: Array = DOCK.get_script_constant_map()["DESTINATION_PHASE"]
	var live: Array = DOCK.get_script_constant_map()["LIVE_DESTINATIONS"]
	for i: int in _buttons.size():
		_buttons[i].visible = phase >= int(phases[i])
		_buttons[i].disabled = not live.has(i)


func _build_destinations() -> void:
	var keys: Array = DOCK.get_script_constant_map()["BUTTON_KEYS"]
	for i: int in keys.size():
		var button: ConsoleButton = ConsoleButton.new()
		button.label_key = str(keys[i])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_destination_pressed.bind(i))
		_destinations.add_child(button)
		_buttons.append(button)


func _refresh_strings() -> void:
	_title.text = tr(KEY_TITLE)
	_pause_entry.label_key = KEY_PAUSE


func _on_destination_pressed(index: int) -> void:
	close()
	destination_requested.emit(index)


func _on_pause_pressed() -> void:
	close()
	pause_requested.emit()
