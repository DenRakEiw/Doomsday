extends Control
## The whole HUD and the two layouts it takes (spec ui-foundation.md §5.7).
##
## The rule is one number: below `COMPACT_WIDTH` the interface is compact. The
## switch re-parents the same nodes — there are not two HUDs, because two HUDs
## drift apart the first time one of them gains a label.
##
## Nothing here is opaque over the map. The strips sit against the top and the
## bottom, the islands keep a `GUTTER` from their corner, and everything between
## them is `MOUSE_FILTER_IGNORE`, so the map gets every event the HUD does not
## consume (§6.2).
##
## Scene-specific, so no `class_name`.

## Emitted when the layout changed, so that the region panel can take the edge
## and the insets that go with it (§5.6, §4.6).
signal layout_changed(compact: bool)

@onready var _top_bar: PanelContainer = %TopBar
@onready var _overlay_picker: PanelContainer = %OverlayPicker
@onready var _dock: PanelContainer = %Dock
@onready var _dock_island: VBoxContainer = %DockIsland
@onready var _dock_bar: VBoxContainer = %DockBar
@onready var _stat_row: PanelContainer = %StatRow
@onready var _ticker: PanelContainer = %Ticker

var _compact: bool = false
## False until the first layout pass, so that the first one always applies.
var _has_layout: bool = false


func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_apply_layout()


## Whether the compact layout is in force.
func is_compact() -> bool:
	return _compact


## How much of the screen the HUD covers at the top — what a side panel must
## stay below (§4.6).
func top_inset() -> float:
	return _top_bar.size.y


## The same at the bottom: the dock bar, the stat row and the ticker.
func bottom_inset() -> float:
	var total: float = _stat_row.size.y + _ticker.size.y
	if _dock_bar.visible:
		total += _dock_bar.size.y
	return total


func _on_viewport_size_changed() -> void:
	_apply_layout()


## §5.7's rule as a value: the breakpoint is one comparison and is tested as one,
## because a test cannot resize the window a headless run does not have.
static func compact_for(width: float) -> bool:
	return width < float(UiTokens.COMPACT_WIDTH)


func _apply_layout() -> void:
	var compact: bool = compact_for(get_viewport_rect().size.x)
	if _has_layout and _compact == compact:
		return
	_compact = compact
	_has_layout = true
	_top_bar.set("compact", compact)
	_overlay_picker.set("compact", compact)
	_stat_row.set("compact", compact)
	_dock.set("compact", compact)
	_dock_bar.visible = compact
	_dock_island.visible = not compact
	_move(_dock, _dock_bar if compact else _dock_island)
	# The strips are measured after the layout has settled, or the panel beside
	# them would take last frame's heights.
	await get_tree().process_frame
	if not is_inside_tree():
		return
	layout_changed.emit(compact)


func _move(node: Control, parent: Container) -> void:
	if node.get_parent() == parent:
		return
	node.get_parent().remove_child(node)
	parent.add_child(node)
