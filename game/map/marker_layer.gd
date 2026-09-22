extends Node2D
## What sits *on* the map rather than in it (spec ui-foundation.md §7.7): the
## anomalies waiting to be collected, and the crosses that mark a dark region.
##
## The layer is above the land, so it is offered a tap first (§7.4,
## `MapCamera.TAP_METHOD`): a tap within 24 screen pixels of an anomaly collects
## it and never reaches the region under it.
##
## Every marker is scaled by `1 / zoom`, so the map may be at any zoom and the
## targets stay the same size on screen. The crosses of the dark regions are
## drawn here rather than as nodes — they never move and never animate, and a
## depopulated world would otherwise be sixty nodes doing nothing.
##
## Scene-specific, so no `class_name`.

## §7.7: the cross a dark region gets, in screen pixels.
const DARK_CROSS_PX: float = 12.0
const DARK_STROKE_PX: float = 2.0

## §7.7: the tooltip's bottom-left corner sits `SPACE_4` right of and above the
## anchor, in screen pixels.
const TOOLTIP_OFFSET_PX: Vector2 = Vector2(UiTokens.SPACE_4, -UiTokens.SPACE_4)
## §7.7: a chip-shaped box on `BG_2` with the caption in `TEXT_0`.
const TOOLTIP_VARIATION: StringName = &"MapTooltip"
const TOOLTIP_LABEL_VARIATION: StringName = &"MapTooltipLabel"
const KEY_ANOMALY: String = "UI_REGION_ANOMALY"
const PLACEHOLDER_VALUE: String = "value"

## Anomaly id → its marker. Only markers that are still collectable are in here;
## a fading one has been taken out already.
var _markers: Dictionary[int, AnomalyMarker] = {}
## Anchors of the regions that have gone dark, in map pixels.
var _dark_anchors: PackedVector2Array = PackedVector2Array()
var _camera: MapCamera = null
var _zoom: float = 1.0
var _tooltip: PanelContainer = null
var _tooltip_label: Label = null
## The marker the pointer is over, or 0.
var _hovered_id: int = 0


func _ready() -> void:
	_tooltip = _make_tooltip()
	add_child(_tooltip)
	EventBus.run_started.connect(_on_run_started)
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.sim_event.connect(_on_sim_event)
	_camera = MapCamera.find_beside(self)
	if _camera != null:
		_camera.view_changed.connect(_on_camera_view_changed)
		_zoom = _camera.zoom.x
	rebuild()


## Hover is the desktop's (§7.4): touch has no pointer to rest, and a drag is
## the camera's gesture, not a pass over the map.
func _unhandled_input(event: InputEvent) -> void:
	if OS.has_feature("mobile") or _camera == null or _camera.is_panning():
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion == null:
		return
	hover(motion.position)


## The tap the camera offers before the land is picked. A hit sends the command
## and is the end of the gesture; whether the simulation accepts it is not the
## marker's business — the event that follows takes the marker away either way.
func try_tap(screen: Vector2) -> bool:
	var marker: AnomalyMarker = marker_at(screen)
	if marker == null:
		return false
	Game.apply(CollectAnomalyCommand.new(marker.anomaly_id))
	return true


## The pointer moved to `screen`: what it rests on gets the tooltip of §7.7, and
## everything else takes it away again. Public for the same reason `try_tap` is:
## a test should be able to say "the pointer is here" without an event queue.
func hover(screen: Vector2) -> void:
	_hover(marker_at(screen))
	# The box is placed in screen space, so it follows a map that moved under a
	# resting pointer as well as a pointer that moved to another marker.
	if _hovered_id != 0:
		_place_tooltip()


## The tooltip, for the tests. Hidden unless the pointer rests on a marker.
func tooltip() -> PanelContainer:
	return _tooltip


## What the tooltip says, for the tests.
func tooltip_text() -> String:
	return _tooltip_label.text


## The marker under a screen point, or null. Nearest wins — two anchors can be
## closer together than the 48 px target on a zoomed-out map.
func marker_at(screen: Vector2) -> AnomalyMarker:
	if _camera == null:
		return null
	var point: Vector2 = _camera.canvas_transform().affine_inverse() * screen
	var best: AnomalyMarker = null
	var best_distance: float = INF
	for id: int in _markers:
		var marker: AnomalyMarker = _markers[id]
		if marker.is_fading() or not AnomalyMarker.hits(marker.position, point, _zoom):
			continue
		var distance: float = marker.position.distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = marker
	return best


## Builds the markers from the world as it stands — at the start of a run, and
## after a save was loaded into it.
func rebuild() -> void:
	for id: int in _markers:
		_markers[id].queue_free()
	_markers.clear()
	_dark_anchors = PackedVector2Array()
	_hover(null)
	if Game.sim != null:
		var world: World = Game.sim.world
		for anomaly: Anomaly in world.anomalies:
			_add_marker(anomaly.id, anomaly.region, anomaly.value, anomaly.expires_day)
		for i: int in range(1, world.regions.size()):
			if world.regions[i].dark:
				_dark_anchors.append(Vector2(world.regions[i].def.anchor))
	queue_redraw()


## Markers that are still on the map, for the tests.
func marker_count() -> int:
	return _markers.size()


func marker_of(anomaly_id: int) -> AnomalyMarker:
	return _markers.get(anomaly_id, null)


func dark_count() -> int:
	return _dark_anchors.size()


## §7.7: "never colour alone" — a dark region is the only region the map paints
## in the void's own colour, so it is also marked.
func _draw() -> void:
	var arm: float = DARK_CROSS_PX * 0.5 / _zoom
	var stroke: float = DARK_STROKE_PX / _zoom
	for anchor: Vector2 in _dark_anchors:
		draw_line(anchor + Vector2(-arm, -arm), anchor + Vector2(arm, arm),
			UiTokens.MAP_DARK_MARK, stroke)
		draw_line(anchor + Vector2(-arm, arm), anchor + Vector2(arm, -arm),
			UiTokens.MAP_DARK_MARK, stroke)


func _on_run_started(_seed_value: int) -> void:
	rebuild()


## Game time is the layer's to hand out: a marker blinks in its last days and
## has no idea which day it is.
func _on_tick_advanced(day: int) -> void:
	for id: int in _markers:
		var marker: AnomalyMarker = _markers[id]
		marker.days_left = marker.expires_day - day


func _on_sim_event(event: SimEvent) -> void:
	match event.type:
		SimEvent.ANOMALY_SPAWNED:
			_spawn(event)
		SimEvent.ANOMALY_EXPIRED, SimEvent.ANOMALY_COLLECTED:
			_remove(int(event.data.get("anomaly", 0)))
		SimEvent.REGION_DEPOPULATED:
			_darken(str(event.data.get("region", "")))


func _spawn(event: SimEvent) -> void:
	var index: int = _region_index(str(event.data.get("region", "")))
	if index <= 0:
		return
	_add_marker(int(event.data.get("anomaly", 0)), index,
		float(event.data.get("value", 0.0)), int(event.data.get("expires_day", 0)))


func _add_marker(anomaly_id: int, region_index: int, value: float,
		expires_day: int) -> void:
	if _markers.has(anomaly_id) or Game.sim == null:
		return
	var marker: AnomalyMarker = AnomalyMarker.new()
	marker.anomaly_id = anomaly_id
	marker.value = value
	marker.expires_day = expires_day
	marker.position = Vector2(Game.sim.world.regions[region_index].def.anchor)
	marker.scale = Vector2.ONE / _zoom
	add_child(marker)
	marker.days_left = expires_day - Game.sim.world.day
	_markers[anomaly_id] = marker


func _remove(anomaly_id: int) -> void:
	var marker: AnomalyMarker = _markers.get(anomaly_id, null)
	if marker == null:
		return
	_markers.erase(anomaly_id)
	if _hovered_id == anomaly_id:
		_hover(null)
	marker.fade_out()


func _darken(region_id: String) -> void:
	var index: int = _region_index(region_id)
	if index <= 0 or Game.sim == null:
		return
	_dark_anchors.append(Vector2(Game.sim.world.regions[index].def.anchor))
	queue_redraw()


func _region_index(region_id: String) -> int:
	if Game.db == null:
		return 0
	return int(Game.db.region_index_by_id.get(region_id, 0))


## Shows what an anomaly is worth while the pointer rests on it (§7.7).
func _hover(marker: AnomalyMarker) -> void:
	var id: int = marker.anomaly_id if marker != null else 0
	if id == _hovered_id:
		return
	_hovered_id = id
	if marker == null:
		_tooltip.visible = false
		return
	_tooltip_label.text = tr(KEY_ANOMALY).format(
		{PLACEHOLDER_VALUE: Format.number(marker.value, Format.Kind.COMPUTE)})
	_tooltip.visible = true
	_place_tooltip()


## §7.7: the box sits up and to the right of the marker, and is pushed back
## inside the viewport when that would take it off the screen.
func _place_tooltip() -> void:
	var marker: AnomalyMarker = _markers.get(_hovered_id, null)
	if marker == null or _camera == null:
		_tooltip.visible = false
		return
	# The box lives in map coordinates like everything else here, so it is
	# counter-scaled to land on the screen at its authored size.
	_tooltip.scale = Vector2.ONE / _zoom
	_tooltip.size = _tooltip.get_combined_minimum_size()
	var to_screen: Transform2D = _camera.canvas_transform()
	var corner: Vector2 = to_screen * marker.position + TOOLTIP_OFFSET_PX
	var top_left: Vector2 = corner - Vector2(0.0, _tooltip.size.y)
	_tooltip.position = to_screen.affine_inverse() * _inside_view(top_left, _tooltip.size)


## `top_left` moved back inside the viewport, in screen pixels, with a gutter to
## the edge. A box wider than the screen is left at the left edge rather than
## pushed off the other side.
func _inside_view(top_left: Vector2, box: Vector2) -> Vector2:
	var view: Vector2 = _camera.view_size()
	var margin: float = float(UiTokens.SPACE_2)
	return Vector2(
		minf(maxf(top_left.x, margin), maxf(view.x - box.x - margin, margin)),
		minf(maxf(top_left.y, margin), maxf(view.y - box.y - margin, margin)))


## §7.7: a chip-shaped box, not a bare caption — over the pulsing ring a plain
## label was unreadable (G2).
func _make_tooltip() -> PanelContainer:
	var box: PanelContainer = PanelContainer.new()
	box.theme_type_variation = TOOLTIP_VARIATION
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.visible = false
	_tooltip_label = Label.new()
	_tooltip_label.theme_type_variation = TOOLTIP_LABEL_VARIATION
	_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_tooltip_label)
	return box


func _on_camera_view_changed(_center: Vector2, zoom_level: float) -> void:
	if zoom_level > 0.0 and not is_equal_approx(zoom_level, _zoom):
		_zoom = zoom_level
		var marker_scale: Vector2 = Vector2.ONE / _zoom
		for id: int in _markers:
			_markers[id].scale = marker_scale
		queue_redraw()
	if _hovered_id != 0:
		_place_tooltip()
