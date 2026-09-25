extends Control
## The map as one focusable control (spec accessibility.md §4.5): with the focus
## on it, the arrow keys or the D-pad move a cursor from region to region,
## `Enter` or A selects the region and a second press goes into its panel, and
## `Page Up`/`Page Down` jump to the next region that wants the player.
##
## It covers the screen behind the HUD and takes no pointer event — the map keeps
## every click. The cursor is drawn by `MarkerLayer`, and moving it hovers the
## region exactly as a mouse would, so the highlight and the site prompt follow.
##
## Scene-specific (the session builds it as the first child of `HudLayer`), so
## no `class_name`.

## `MapCamera.GROUP_MAP_FOCUS`: the camera lets the arrows pan only with Shift
## while this has the focus.
const GROUP: StringName = &"map_focus"
const KEY_NAME: String = "UI_A11Y_MAP"
const KEY_HELP: String = "UI_A11Y_MAP_HELP"
const KEY_NOTHING: String = "UI_A11Y_MAP_NOTHING"
## §3.4: holding an arrow speaks the last region, not every one passed.
const CURSOR_LIVE_GAP_MS: int = 250
## §4.5: the camera follows once the cursor leaves the middle of the view.
const VIEW_MIDDLE_SHARE: float = 0.6
const STYLE_FOCUS: StringName = &"focus"
const THEME_TYPE: StringName = &"MapFocus"
const DIRECTIONS: Dictionary[StringName, Vector2] = {
	&"ui_left": Vector2.LEFT,
	&"ui_right": Vector2.RIGHT,
	&"ui_up": Vector2.UP,
	&"ui_down": Vector2.DOWN,
}
const ACTION_ACCEPT: StringName = &"ui_accept"
const ACTION_JUMP_NEXT: StringName = &"ui_page_down"
const ACTION_JUMP_PREV: StringName = &"ui_page_up"

## The region the cursor is on; 0 = none yet.
var cursor: int = 0
## §4.1: the cursor shows only while the player is on the keyboard or a pad.
var keyboard_mode: bool = false:
	set(value):
		keyboard_mode = value
		_refresh_cursor()
## The layer that draws the cursor, the camera it keeps in view, the map whose
## hover it moves, and the region panel a second `Enter` goes into. The session
## sets them; each may be null in a test that does not need it.
var markers: Node2D = null
var camera: MapCamera = null
var map_view: MapView = null
var region_panel: SlidePanel = null
## A test sets the clock the speech's pacing reads; below zero, the real one.
var clock_override_ms: int = -1

var _selected: int = 0
var _live: LiveRegion = null
var _live_queue: LiveQueue = LiveQueue.new(CURSOR_LIVE_GAP_MS)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_ALL
	add_to_group(GROUP)
	_live = LiveRegion.new()
	_live.name = "MapLive"
	add_child(_live)
	focus_entered.connect(_on_focus_changed)
	focus_exited.connect(_on_focus_changed)
	EventBus.region_selected.connect(_on_region_selected)
	EventBus.run_started.connect(_on_run_started)
	EventBus.keyboard_mode_changed.connect(_on_keyboard_mode_changed)
	_refresh_strings()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_strings()


func _process(_delta: float) -> void:
	var line: String = _live_queue.pop_due(_now())
	if not line.is_empty():
		_live.say(line)


func _draw() -> void:
	if not has_focus():
		return
	# §4.5: the ring of §4.2, inset by a gutter around the map — a frame that
	# says the map has the keys.
	var box: StyleBox = get_theme_stylebox(STYLE_FOCUS, THEME_TYPE)
	var inset: float = float(UiTokens.GUTTER)
	draw_style_box(box, Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0))


func _gui_input(event: InputEvent) -> void:
	if not event.is_pressed():
		return
	for action: StringName in DIRECTIONS:
		if event.is_action_pressed(action, true):
			# Shift + arrows pan the camera instead (§4.5).
			var key: InputEventKey = event as InputEventKey
			if key != null and key.shift_pressed:
				return
			accept_event()
			step(DIRECTIONS[action])
			return
	if event.is_action_pressed(ACTION_ACCEPT):
		accept_event()
		accept()
	elif event.is_action_pressed(ACTION_JUMP_NEXT, true):
		accept_event()
		jump(true)
	elif event.is_action_pressed(ACTION_JUMP_PREV, true):
		accept_event()
		jump(false)


## Moves the cursor one region in `dir`; the first move only places it, on the
## region nearest the middle of the view.
func step(dir: Vector2) -> void:
	if Game.db == null:
		return
	var anchors: PackedVector2Array = _anchors()
	var regions: PackedInt32Array = _land()
	if cursor <= 0:
		var centre: Vector2 = camera.position if camera != null else MapCamera.START_CENTER
		_move_to(MapNav.nearest(centre, anchors, regions))
		return
	var next: int = MapNav.step(cursor, dir, anchors, regions)
	if next > 0:
		_move_to(next)


## `Enter`: a region not yet selected is selected — its panel opens and the
## player keeps browsing; the selected one hands the focus to its panel.
func accept() -> void:
	if cursor <= 0:
		step(Vector2.ZERO)
		return
	if cursor != _selected:
		EventBus.region_selected.emit(cursor)
		return
	if region_panel != null and region_panel.is_open:
		region_panel.focus_primary()


## `Page Down` / `Page Up`: the next region with an open event, an anomaly or —
## while a site is being chosen — room for it.
func jump(forward: bool) -> void:
	var next: int = MapNav.jump(cursor, forward, wanted())
	if next <= 0:
		_live_queue.push(tr(KEY_NOTHING), _now())
		return
	_move_to(next)


## The regions a jump visits, in ascending index.
func wanted() -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	if Game.sim == null:
		return out
	var world: World = Game.sim.world
	var request: SiteRequest = Game.site_request
	for index: int in range(1, world.regions.size()):
		if world.event_in_region(index) != null or world.anomaly_in_region(index) != null \
				or (request != null and request.reason_for(index).is_empty()):
			out.append(index)
	return out


## The live region the cursor speaks through, for the tests.
func live_region() -> LiveRegion:
	return _live


func _move_to(index: int) -> void:
	if index <= 0:
		return
	cursor = index
	_refresh_cursor()
	if map_view != null:
		map_view.hover_index = index
	EventBus.region_hovered.emit(index)
	_keep_in_view()
	if Game.sim != null:
		_live_queue.push(RegionSpeech.line(Game.sim.world, index, Game.site_request), _now())


## §4.5: the camera follows once the cursor's anchor leaves the middle 60 %.
func _keep_in_view() -> void:
	if camera == null or Game.db == null:
		return
	var view: Vector2 = camera.view_size()
	var screen: Vector2 = camera.canvas_transform() * Vector2(Game.db.regions[cursor].anchor)
	var margin: Vector2 = view * (1.0 - VIEW_MIDDLE_SHARE) * 0.5
	if not Rect2(margin, view - margin * 2.0).has_point(screen):
		camera.focus_region(cursor)


func _anchors() -> PackedVector2Array:
	var anchors: PackedVector2Array = PackedVector2Array()
	for def: RegionDef in Game.db.regions:
		anchors.append(Vector2(def.anchor) if def != null else Vector2.ZERO)
	return anchors


## Every land region, dark ones included (index 0 is "no region").
func _land() -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for index: int in range(1, Game.db.regions.size()):
		out.append(index)
	return out


func _refresh_cursor() -> void:
	if markers != null:
		markers.set(&"cursor", cursor)
		markers.set(&"cursor_visible", has_focus() and keyboard_mode)
	queue_redraw()


func _refresh_strings() -> void:
	accessibility_name = tr(KEY_NAME)
	accessibility_description = tr(KEY_HELP)


func _now() -> int:
	return clock_override_ms if clock_override_ms >= 0 else Time.get_ticks_msec()


func _on_focus_changed() -> void:
	_refresh_cursor()


func _on_region_selected(index: int) -> void:
	_selected = index


func _on_run_started(_seed_value: int) -> void:
	cursor = 0
	_selected = 0
	_refresh_cursor()


func _on_keyboard_mode_changed(keyboard: bool) -> void:
	keyboard_mode = keyboard
