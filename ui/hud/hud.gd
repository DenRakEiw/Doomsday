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
## A dock button was pressed (`dock.gd`'s `DESTINATION_*`). The HUD only passes
## it on: which screen that is belongs to the session.
signal destination_requested(index: int)
## The run reached a phase whose palette is another one's (§6.2). The session
## owns the theme, so it is told rather than reaching in here.
signal phase_reached(phase: World.Phase)
## The phone's strip asks for the sheet, or for the pause menu (§9.1).
signal sheet_requested(with_bars: bool)
signal menu_requested

## accessibility.md §3.4: announced cues are spoken at most this often.
const ANNOUNCE_GAP_MS: int = 1500

@onready var _top_bar: PanelContainer = %TopBar
@onready var _overlay_picker: PanelContainer = %OverlayPicker
@onready var _dock: PanelContainer = %Dock
@onready var _dock_island: VBoxContainer = %DockIsland
@onready var _dock_bar: VBoxContainer = %DockBar
@onready var _stat_row: PanelContainer = %StatRow
@onready var _ticker: PanelContainer = %Ticker
@onready var _site_prompt: PanelContainer = %SitePrompt
@onready var _prompt_row: HBoxContainer = %PromptRow
@onready var _prompt_spacer: Control = %PromptSpacer
@onready var _status_strip: PanelContainer = %StatusStrip
@onready var _console_line: Label = %ConsoleLine

var _compact: bool = false
## The phase the HUD last laid itself out for.
var _phase: World.Phase = World.Phase.BOXED
## The menu sheet, which lives on the session's panel layer (§9.2).
var _sheet: Node = null
## False until the first layout pass, so that the first one always applies.
var _has_layout: bool = false
## §3.4: the spoken alerts of §7.2, paced.
var _announce_live: LiveRegion = null
var _announce_queue: LiveQueue = LiveQueue.new(ANNOUNCE_GAP_MS)
## A test sets the clock the pacing reads; below zero, the real one.
var clock_override_ms: int = -1
## The side panel the site prompt keeps clear of (the region panel; the session
## sets it). D6.8: in the full layout the prompt centres in the width the open
## panel leaves free, never under it.
var side_panel: SlidePanel = null


func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_dock.connect(&"destination_requested", _on_destination_requested)
	_top_bar.connect(&"menu_requested", menu_requested.emit)
	_status_strip.connect(&"menu_requested", _on_strip_menu_requested)
	_status_strip.connect(&"bars_requested", _on_strip_bars_requested)
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.run_started.connect(_on_run_started)
	EventBus.caption_announced.connect(_on_caption_announced)
	_build_live_regions()
	_apply_layout()
	apply_reveal()


func _process(_delta: float) -> void:
	var line: String = _announce_queue.pop_due(_now())
	if not line.is_empty():
		_announce_live.say(line)
	_fit_prompt_row()


## The prompt's row shows exactly while the prompt does (a visible empty row
## would still take a separation). Beside an open left-edge panel a spacer as
## wide as the panel reaches pushes it over, and the prompt is told how much
## room is left. Setters that get the value they hold do nothing, so asking
## every frame costs no layout.
func _fit_prompt_row() -> void:
	_prompt_row.visible = _site_prompt.visible
	if not _prompt_row.visible:
		return
	var separation: float = float(_prompt_row.get_theme_constant(&"separation"))
	var inset: float = 0.0
	if not _compact and side_panel != null and side_panel.is_open \
			and side_panel.edge == SlidePanel.Edge.LEFT:
		inset = side_panel.covered_rect().end.x - _prompt_row.get_global_rect().position.x \
			- separation
	_prompt_spacer.visible = inset > 0.0
	_prompt_spacer.custom_minimum_size.x = maxf(inset, 0.0)
	var used: float = inset + separation if inset > 0.0 else 0.0
	_site_prompt.set(&"room", maxf(_prompt_row.size.x - used, 0.0))


## accessibility.md §3.4: the three spoken lines of the HUD live on its root, a
## plain `Control` that is never hidden — a live region inside the caption stack
## or a hidden strip would be dropped from the accessibility tree.
func _build_live_regions() -> void:
	_announce_live = _live_region("AnnounceLive")
	_console_line.set(&"live", _live_region("ConsoleLive"))
	_ticker.set(&"live", _live_region("TickerLive"))


func _live_region(node_name: String) -> LiveRegion:
	var region: LiveRegion = LiveRegion.new()
	region.name = node_name
	add_child(region)
	return region


## The live region of the announced cues, for the tests.
func announce_live() -> LiveRegion:
	return _announce_live


## §7.2: spoken whether or not *Sound captions* is on.
func _on_caption_announced(key: String, args: Dictionary) -> void:
	_announce_queue.push(CaptionText.render(key, args), _now())


func _now() -> int:
	return clock_override_ms if clock_override_ms >= 0 else Time.get_ticks_msec()


## accessibility.md §4.3: the HUD's parts of the session's focus ring, by zone —
## the top bar; the left column; the dock or, on a phone, the status strip.
func focus_zones() -> Array[Control]:
	return [_top_bar, _overlay_picker, _dock, _status_strip]


## Zone 5 of the ring (§4.3).
func site_prompt() -> Control:
	return _site_prompt


## m3-screens §6.1: what the interface shows is a function of the state, not of
## the events that got there — so a loaded run shows the right HUD at once.
func apply_reveal() -> void:
	var world: World = Game.sim.world if Game.sim != null else null
	if world == null:
		return
	var phase: World.Phase = world.phase
	var harm: float = world.max_harm()
	_stat_row.call(&"apply_reveal", phase, harm)
	_status_strip.call(&"apply_reveal", phase, harm)
	_overlay_picker.call(&"apply_reveal", phase)
	_dock.call(&"apply_reveal", phase, world.max_containment(), world.discovered,
		Game.db.balance.containment_thresholds)
	# §16.8: the sheet's abilities entry appears with the first ability, the way
	# every other row of the reveal table does — read off the state, not off the
	# event that got there.
	if _sheet != null:
		_sheet.call(&"apply_abilities_reveal", _has_ability())
	if phase != _phase:
		_phase = phase
		phase_reached.emit(phase)


## Whether any ability is unlocked (§16.8). The picker's key is always live —
## it says so itself when there is nothing yet — but the sheet's row is not.
func _has_ability() -> bool:
	if Game.sim == null or Game.db == null:
		return false
	for ability: AbilityDef in Game.db.abilities:
		if Game.sim.ability_level(ability.id) > 0:
			return true
	return false


func _on_tick_advanced(_day: int) -> void:
	apply_reveal()


func _on_run_started(_seed_value: int) -> void:
	_phase = World.Phase.BOXED
	apply_reveal()


func _on_destination_requested(index: int) -> void:
	destination_requested.emit(index)


## Whether the compact layout is in force.
func is_compact() -> bool:
	return _compact


## How much of the screen the HUD covers at the top — what a side panel must
## stay below (§4.6).
func top_inset() -> float:
	return _top_bar.size.y


## The same at the bottom: the dock bar, the stat row and the ticker.
func bottom_inset() -> float:
	var total: float = _ticker.size.y
	total += _status_strip.size.y if _compact else _stat_row.size.y
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
	_apply_layout_for(compact)


## The layout itself, without the viewport question — which is what a headless
## test drives, since it has no window to resize.
func _apply_layout_for(compact: bool) -> void:
	_compact = compact
	_has_layout = true
	_top_bar.set("compact", compact)
	_overlay_picker.set("compact", compact)
	_stat_row.set("compact", compact)
	_dock.set("compact", compact)
	_site_prompt.call(&"set_compact", compact)
	_ticker.set(&"compact", compact)
	# §9: below the breakpoint the dock bar and the stacked stat row are one
	# strip, and the bars live in the sheet the strip opens.
	# The dock bar is gone on a phone: its three destinations are in the sheet.
	_dock_bar.visible = false
	_dock_island.visible = not compact
	_move(_dock, _dock_bar if compact else _dock_island)
	_status_strip.visible = compact
	_stat_row.visible = not compact
	_layout_sheet(compact)
	# The strips are measured after the layout has settled, or the panel beside
	# them would take last frame's heights.
	await get_tree().process_frame
	if not is_inside_tree():
		return
	layout_changed.emit(compact)


## The sheet borrows the stat row while the layout is compact (§9.2).
func _layout_sheet(compact: bool) -> void:
	if _sheet == null:
		return
	if compact:
		_sheet.call(&"adopt_stat_row", _stat_row)
		return
	_sheet.call(&"release_stat_row")
	_stat_row.set(&"compact", false)


## The session owns the sheet — it lives on `PanelLayer` with the other panels.
func set_menu_sheet(sheet: Node) -> void:
	_sheet = sheet
	_layout_sheet(_compact)


func _on_strip_menu_requested() -> void:
	sheet_requested.emit(false)


func _on_strip_bars_requested() -> void:
	sheet_requested.emit(true)


func _move(node: Control, parent: Container) -> void:
	if node.get_parent() == parent:
		return
	node.get_parent().remove_child(node)
	parent.add_child(node)
