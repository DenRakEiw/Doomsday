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
## §16.10: the picker's entry, which is the compact layout's `A` key.
signal abilities_requested

const DOCK: GDScript = preload("res://ui/hud/dock.gd")
const KEY_PAUSE: String = "UI_MENU_PAUSE"
const KEY_ABILITIES: String = "UI_SHEET_ABILITIES"
const KEY_HELP: String = "UI_SHEET_HELP"
const KEY_TITLE: String = "UI_MENU_TITLE"
const KEY_NOT_YET: String = "UI_DOCK_NOT_YET"

@onready var _title: Label = %SheetTitle
@onready var _close_button: IconButton = %SheetClose
@onready var _bars_slot: VBoxContainer = %BarsSlot
@onready var _destinations: VBoxContainer = %Destinations
@onready var _pause_entry: ConsoleButton = %PauseEntry
@onready var _abilities_entry: ConsoleButton = %AbilitiesEntry
@onready var _help_entry: ConsoleButton = %HelpEntry

var _buttons: Array[ConsoleButton] = []
## Where the stat row came from, so it can go home — and who owned it, because
## taking a node out of the tree clears the owner and with it every `%` name
## below it (PROGRESS.md, *Known issues*).
var _row_home: Node = null
var _row_owner: Node = null
## Its place among its siblings: the ticker is below it and must stay there.
var _row_index: int = 0
var _stat_row: Control = null


## accessibility.md §4.4: the sheet's first destination.
func primary_focus() -> Control:
	var roots: Array[Control] = [self]
	for control: Control in FocusRing.collect(roots):
		if control != _close_button:
			return control
	return _close_button


func _ready() -> void:
	super()
	height_share = UiTokens.SHEET_HEIGHT_RATIO
	edge = SlidePanel.Edge.BOTTOM
	_build_destinations()
	_close_button.pressed.connect(close)
	_pause_entry.pressed.connect(_on_pause_pressed)
	_abilities_entry.pressed.connect(_on_abilities_pressed)
	_help_entry.pressed.connect(_on_help_pressed)
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
	# Where it sat, so that it comes back above the ticker and not below it.
	_row_index = row.get_index()
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
	_row_home.move_child(_stat_row, _row_index)
	_stat_row.owner = _row_owner
	# Re-registers the `%` name the removal dropped.
	_stat_row.unique_name_in_owner = true
	_stat_row = null
	_row_home = null
	_row_owner = null
	_row_index = 0


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
	_abilities_entry.label_key = KEY_ABILITIES
	_help_entry.label_key = KEY_HELP


func _on_destination_pressed(index: int) -> void:
	close()
	destination_requested.emit(index)


func _on_pause_pressed() -> void:
	close()
	pause_requested.emit()


## §16.8: the entry appears with the first ability, like every other row.
func _on_abilities_pressed() -> void:
	close()
	abilities_requested.emit()


## first-run.md §6.7: *How to play*, on the session's page; the sheet closes first.
func _on_help_pressed() -> void:
	close()
	EventBus.help_requested.emit(HelpPages.page_for_context(HelpPages.CONTEXT_SESSION))


## The entry is there once any ability is unlocked (§16.8).
func apply_abilities_reveal(unlocked: bool) -> void:
	_abilities_entry.visible = unlocked
