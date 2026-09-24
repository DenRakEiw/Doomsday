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
## `loop-mechanics.md` §16.3.2: what an asset row says when the pointer rests on
## it, and what joins the kinds in that line.
const KEY_ASSETS_TIP: String = "UI_MAP_ASSETS_TIP"
const PLACEHOLDER_ASSETS: String = "assets"
const ASSET_JOIN: String = " · "
## §16.3.2: what a status ring says when the pointer rests on it.
const KEY_STATUS_TIP: String = "UI_MAP_STATUS_TIP"
const PLACEHOLDER_STATUS: String = "status"
const PLACEHOLDER_DAYS: String = "days"
## The caption a standing status shows where a number of days would be (§17.4).
const KEY_STANDING: String = "UI_REGION_STATUS_STANDING"
## §16.3.2: what an event marker says when the pointer rests on it.
const KEY_EVENT_TIP: String = "UI_MAP_EVENT_TIP"
const PLACEHOLDER_TITLE: String = "title"
## `taskforce-endings.md` §9: the Task Force's letters and the dotted line to
## its target, in screen pixels.
const KEY_TASK_FORCE_CODE: String = "UI_TASK_FORCE_CODE"
const TEAM_LINE_PX: float = 2.0
const TEAM_DASH_PX: float = 6.0
const TEAM_LINE_ALPHA: float = 0.7

## Anomaly id → its marker. Only markers that are still collectable are in here;
## a fading one has been taken out already.
var _markers: Dictionary[int, AnomalyMarker] = {}
## Region index → its asset row. A region that holds nothing has none (§16.3.2).
var _assets: Dictionary[int, AssetMarker] = {}
## Region index → its status rings. A region with nothing running has none.
var _statuses: Dictionary[int, StatusMarker] = {}
## Region index → its event marker. A global event has none (§16.3.2).
var _events: Dictionary[int, EventMarker] = {}
## The Response Task Force, while it is on the map (§9).
var _team: TaskForceMarker = null
## The region its dotted line runs to, or 0 while its target is not shown (§2.3).
var _team_line_to: int = 0
## Anchors of the regions that have gone dark, in map pixels.
var _dark_anchors: PackedVector2Array = PackedVector2Array()
var _camera: MapCamera = null
var _zoom: float = 1.0
var _tooltip: PanelContainer = null
var _tooltip_label: Label = null
## The marker the pointer is over, or 0.
var _hovered_id: int = 0
## The region whose asset row the pointer is over, or 0 (§16.3.2).
var _hovered_assets: int = 0
## The region whose status rings the pointer is over, or 0.
var _hovered_status: int = 0
## The region whose event marker the pointer is over, or 0.
var _hovered_event: int = 0


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
	# The palette can change mid-run (m3-screens §6.2); a drawn colour is not
	# a theme item and has to be asked for again.
	EventBus.theme_variant_changed.connect(_on_theme_variant_changed)


func _on_theme_variant_changed(_variant: StringName) -> void:
	queue_redraw()


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
	# §16.3.2's hit order: an event first — it sits above and beside the anchor,
	# and it is the thing that asks for an answer — then an anomaly, then the land.
	var event_region: int = event_marker_at(screen)
	if event_region > 0:
		EventBus.region_selected.emit(event_region)
		EventBus.event_card_requested.emit(event_region)
		return true
	var marker: AnomalyMarker = marker_at(screen)
	if marker == null:
		return false
	Game.apply(CollectAnomalyCommand.new(marker.anomaly_id))
	return true


## The pointer moved to `screen`: what it rests on gets the tooltip of §7.7, and
## everything else takes it away again. Public for the same reason `try_tap` is:
## a test should be able to say "the pointer is here" without an event queue.
func hover(screen: Vector2) -> void:
	var event_region: int = event_marker_at(screen)
	_hover_event(event_region)
	if event_region > 0:
		_hover(null)
		_hover_status(0)
		_hover_assets(0)
		_tooltip.visible = true
		_place_tooltip_at(_events[event_region].position)
		return
	var marker: AnomalyMarker = marker_at(screen)
	_hover(marker)
	# An anomaly sits on the anchor, the status rings around it and the asset row
	# below it, so they are asked in that order and only a miss falls through.
	_hover_status(0 if marker != null else status_ring_at(screen))
	_hover_assets(0 if marker != null or _hovered_status != 0 else asset_row_at(screen))
	# The box is placed in screen space, so it follows a map that moved under a
	# resting pointer as well as a pointer that moved to another marker.
	if _hovered_id != 0:
		_place_tooltip_at(marker.position)
	elif _hovered_status != 0:
		_place_tooltip_at(_statuses[_hovered_status].position)
	elif _hovered_assets != 0:
		_place_tooltip_at(_assets[_hovered_assets].position)


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


## The region whose event marker lies under a screen point, or 0. Nearest wins.
func event_marker_at(screen: Vector2) -> int:
	if _camera == null:
		return 0
	var point: Vector2 = _camera.canvas_transform().affine_inverse() * screen
	var best: int = 0
	var best_distance: float = INF
	for index: int in _events:
		var marker: EventMarker = _events[index]
		if not EventMarker.hits(marker.position, point, _zoom):
			continue
		var distance: float = ((point - marker.position) * _zoom).distance_to(EventMarker.centre())
		if distance < best_distance:
			best_distance = distance
			best = index
	return best


## The event markers on the map, for the tests.
func event_count() -> int:
	return _events.size()


func event_marker_of(region_index: int) -> EventMarker:
	return _events.get(region_index, null)


## The region whose asset row lies under a screen point, or 0. The row is a
## band below the anchor, so the box it answers for is the row's own width and
## the glyph height, both in screen pixels (§16.3.2).
func asset_row_at(screen: Vector2) -> int:
	if _camera == null:
		return 0
	var point: Vector2 = _camera.canvas_transform().affine_inverse() * screen
	for index: int in _assets:
		var marker: AssetMarker = _assets[index]
		var offset: Vector2 = (point - marker.position) * _zoom
		var half: float = marker.row_width() * 0.5
		if absf(offset.x) > half:
			continue
		if offset.y >= float(UiTokens.MARKER_ROW_OFFSET) \
				and offset.y <= float(UiTokens.MARKER_ROW_OFFSET) + UiTokens.ASSET_GLYPH_LEAD:
			return index
	return 0


## Builds the markers from the world as it stands — at the start of a run, and
## after a save was loaded into it.
func rebuild() -> void:
	for id: int in _markers:
		_markers[id].queue_free()
	_markers.clear()
	for index: int in _assets:
		_assets[index].queue_free()
	_assets.clear()
	for index: int in _statuses:
		_statuses[index].queue_free()
	_statuses.clear()
	for index: int in _events:
		_events[index].queue_free()
	_events.clear()
	_hovered_assets = 0
	_hovered_status = 0
	_hovered_event = 0
	_dark_anchors = PackedVector2Array()
	_hover(null)
	if Game.sim != null:
		var world: World = Game.sim.world
		for anomaly: Anomaly in world.anomalies:
			_add_marker(anomaly.id, anomaly.region, anomaly.value, anomaly.expires_day)
		for i: int in range(1, world.regions.size()):
			if world.regions[i].dark:
				_dark_anchors.append(Vector2(world.regions[i].def.anchor))
			_refresh_assets(i, false)
			_refresh_statuses(i)
			_refresh_events(i)
	_refresh_team()
	queue_redraw()


## The asset row of one region, rebuilt from the world. `commission` runs the
## ring of §16.3.2, which only a fresh deployment gets.
func _refresh_assets(region_index: int, commission: bool) -> void:
	if Game.sim == null or region_index <= 0:
		return
	var region: Region = Game.sim.world.regions[region_index]
	if not region.has_assets():
		if _assets.has(region_index):
			_assets[region_index].queue_free()
			_assets.erase(region_index)
		return
	var marker: AssetMarker = _assets.get(region_index, null)
	if marker == null:
		marker = AssetMarker.new()
		marker.position = Vector2(region.def.anchor)
		marker.scale = Vector2.ONE / _zoom
		for kind: String in AssetDef.KINDS:
			marker.glyphs[kind] = int(Glyphs.asset_glyph(Game.db.assets[kind].glyph))
		add_child(marker)
		_assets[region_index] = marker
	var counts: Dictionary[String, int] = {}
	for kind: String in AssetDef.KINDS:
		if region.asset_count(kind) > 0:
			counts[kind] = region.asset_count(kind)
	marker.counts = counts
	if commission:
		marker.commission()


## The status rings of one region, rebuilt from the world. A region with nothing
## running loses its marker (§16.3.2).
func _refresh_statuses(region_index: int) -> void:
	if Game.sim == null or region_index <= 0:
		return
	var running: Array[Status] = Game.sim.world.statuses_in_region(region_index)
	if running.is_empty():
		if _statuses.has(region_index):
			_statuses[region_index].queue_free()
			_statuses.erase(region_index)
			if _hovered_status == region_index:
				_hovered_status = 0
				_hide_tooltip()
		return
	var marker: StatusMarker = _statuses.get(region_index, null)
	if marker == null:
		marker = StatusMarker.new()
		marker.position = Vector2(Game.sim.world.regions[region_index].def.anchor)
		marker.scale = Vector2.ONE / _zoom
		add_child(marker)
		_statuses[region_index] = marker
	var rows: Array[Dictionary] = []
	for status: Status in running:
		rows.append(StatusMarker.row(tr(StatusDef.code_key(status.id)),
			_status_share(status), _status_color(status)))
	marker.rows = rows


## The event marker of one region, rebuilt from the world: the oldest event
## decides the mark and the clock, the rest only the count (§16.5 item 12).
func _refresh_events(region_index: int) -> void:
	if Game.sim == null or region_index <= 0:
		return
	var standing: Array[OpenEvent] = Game.sim.world.events_in_region(region_index)
	if standing.is_empty():
		if _events.has(region_index):
			_events[region_index].queue_free()
			_events.erase(region_index)
			if _hovered_event == region_index:
				_hovered_event = 0
				_hide_tooltip()
		return
	var marker: EventMarker = _events.get(region_index, null)
	if marker == null:
		marker = EventMarker.new()
		marker.position = Vector2(Game.sim.world.regions[region_index].def.anchor)
		marker.scale = Vector2.ONE / _zoom
		add_child(marker)
		_events[region_index] = marker
	var oldest: OpenEvent = standing[0]
	var def: EventDef = Game.db.event(oldest.def)
	marker.event_id = oldest.id
	marker.kind = def.kind if def != null else EventDef.KIND_OPENING
	marker.color = _event_color(marker.kind, oldest.faction)
	marker.share = Rings.share_of(float(oldest.days_left(Game.sim.world.day)),
		float(oldest.days_total()))
	marker.count = standing.size()


## §16.3.2: `!` in the faction's colour, ◇ in `ACCENT`, » in `TEXT_0`.
static func _event_color(kind: String, faction: String) -> Color:
	match kind:
		EventDef.KIND_COUNTER_MOVE:
			return UiTokens.faction_color(faction)
		EventDef.KIND_CHAIN:
			return UiTokens.color(&"TEXT_0")
	return UiTokens.color(&"ACCENT")


## How much of a status ring is left. A standing status has no clock, so its
## ring stands full (§7.1).
func _status_share(status: Status) -> float:
	if status.is_standing():
		return 1.0
	return Rings.share_of(float(status.days_left(Game.sim.world.day)),
		float(status.days_total()))


## §16.3.1: the colour is read off the **source**, never off the definition —
## a world status a chain applied has no faction behind it.
func _status_color(status: Status) -> Color:
	var faction: String = status.faction()
	if faction.is_empty():
		return UiTokens.color(&"ACCENT")
	return UiTokens.faction_color(faction)


## The status rings on the map, for the tests.
func status_count() -> int:
	return _statuses.size()


func status_marker_of(region_index: int) -> StatusMarker:
	return _statuses.get(region_index, null)


## The region whose status rings lie under a screen point, or 0. The rings sit on
## the anchor, so the reach is the outermost one (§16.3.2).
func status_ring_at(screen: Vector2) -> int:
	if _camera == null:
		return 0
	var point: Vector2 = _camera.canvas_transform().affine_inverse() * screen
	for index: int in _statuses:
		var marker: StatusMarker = _statuses[index]
		if marker.position.distance_to(point) * _zoom <= marker.outer_radius():
			return index
	return 0


## The asset rows on the map, for the tests.
func asset_count() -> int:
	return _assets.size()


func asset_marker_of(region_index: int) -> AssetMarker:
	return _assets.get(region_index, null)


## Markers that are still on the map, for the tests.
func marker_count() -> int:
	return _markers.size()


func marker_of(anomaly_id: int) -> AnomalyMarker:
	return _markers.get(anomaly_id, null)


func dark_count() -> int:
	return _dark_anchors.size()


## The Task Force's marker, or null while there is no team, for the tests.
func team_marker() -> TaskForceMarker:
	return _team


## The region the team's dotted line runs to, 0 for none, for the tests.
func team_line_target() -> int:
	return _team_line_to


## The team's marker and line, rebuilt from the world: where it stands, how much
## of a setup is left, and whether the player may see where it is going.
func _refresh_team() -> void:
	var team: TaskForce = Game.sim.world.task_force if Game.sim != null else null
	if team == null or not team.is_present() or team.region <= 0:
		if _team != null:
			_team.queue_free()
			_team = null
		if _team_line_to != 0:
			_team_line_to = 0
			queue_redraw()
		return
	if _team == null:
		_team = TaskForceMarker.new()
		_team.scale = Vector2.ONE / _zoom
		add_child(_team)
	var world: World = Game.sim.world
	_team.position = Vector2(world.regions[team.region].def.anchor)
	_team.code = tr(KEY_TASK_FORCE_CODE)
	_team.share = -1.0
	if team.state == TaskForce.STATE_SETUP:
		_team.share = Rings.share_of(float(TaskForceSystem.setup_days_left(world, Game.db)),
			float(TaskForceSystem.setup_days(world, Game.db)))
	var line_to: int = 0
	if TaskForceSystem.target_shown(world) and team.target != team.region:
		line_to = team.target
	if line_to != _team_line_to:
		_team_line_to = line_to
		queue_redraw()


## §7.7: "never colour alone" — a dark region is the only region the map paints
## in the void's own colour, so it is also marked.
func _draw() -> void:
	var arm: float = DARK_CROSS_PX * 0.5 / _zoom
	var stroke: float = DARK_STROKE_PX / _zoom
	for anchor: Vector2 in _dark_anchors:
		draw_line(anchor + Vector2(-arm, -arm), anchor + Vector2(arm, arm),
			UiTokens.color(&"MAP_DARK_MARK"), stroke)
		draw_line(anchor + Vector2(-arm, arm), anchor + Vector2(arm, -arm),
			UiTokens.color(&"MAP_DARK_MARK"), stroke)
	# §9: the team's road, from its badge to the target's anchor, dotted because
	# it is where the team is going, not a link it runs along.
	if _team != null and _team_line_to > 0 and Game.sim != null:
		var colour: Color = UiTokens.color(&"ACCENT")
		colour.a = TEAM_LINE_ALPHA
		draw_dashed_line(_team.position + TaskForceMarker.centre() / _zoom,
			Vector2(Game.sim.world.regions[_team_line_to].def.anchor), colour,
			TEAM_LINE_PX / _zoom, TEAM_DASH_PX / _zoom)


func _on_run_started(_seed_value: int) -> void:
	rebuild()


## Game time is the layer's to hand out: a marker blinks in its last days and
## has no idea which day it is.
func _on_tick_advanced(day: int) -> void:
	for id: int in _markers:
		var marker: AnomalyMarker = _markers[id]
		marker.days_left = marker.expires_day - day
	# A status ring empties by the day, so every one of them is re-read — and so
	# does an event's deadline.
	for index: int in _statuses.keys():
		_refresh_statuses(index)
	for index: int in _events.keys():
		_refresh_events(index)
	_refresh_team()


func _on_sim_event(event: SimEvent) -> void:
	match event.type:
		SimEvent.ANOMALY_SPAWNED:
			_spawn(event)
		SimEvent.ANOMALY_EXPIRED, SimEvent.ANOMALY_COLLECTED:
			_remove(int(event.data.get("anomaly", 0)))
		SimEvent.REGION_DEPOPULATED:
			_darken(str(event.data.get("region", "")))
		SimEvent.ASSET_DEPLOYED:
			_refresh_assets(_region_index(str(event.data.get("region", ""))), true)
		SimEvent.ASSET_LOST:
			_refresh_assets(_region_index(str(event.data.get("region", ""))), false)
		SimEvent.STATUS_STARTED, SimEvent.STATUS_ENDED:
			# A global status has no region and no ring: it shows in the HUD
			# instead (§16.9).
			_refresh_statuses(_region_index(str(event.data.get("region", ""))))
		SimEvent.EVENT_OPENED, SimEvent.EVENT_ANSWERED, SimEvent.EVENT_EXPIRED, \
				SimEvent.EVENT_DROPPED:
			_refresh_events(_region_index(str(event.data.get("region", ""))))
		SimEvent.TASK_FORCE_APPEARED, SimEvent.TASK_FORCE_TARGETED, 				SimEvent.TASK_FORCE_MOVED, SimEvent.TASK_FORCE_SETUP, 				SimEvent.TASK_FORCE_ACTED, SimEvent.TASK_FORCE_FIZZLED, 				SimEvent.TASK_FORCE_MISDIRECTED:
			_refresh_team()


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
	marker.lifetime_days = Game.db.balance.anomaly_lifetime_days
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
	_hovered_assets = 0
	_hovered_status = 0
	_tooltip_label.text = tr(KEY_ANOMALY).format(
		{PLACEHOLDER_VALUE: Format.number(marker.value, Format.Kind.COMPUTE)})
	_tooltip.visible = true
	_place_tooltip_at(marker.position)


## §16.3.2: the oldest event's title and how long is left before it is decided.
func _hover_event(region_index: int) -> void:
	if region_index == _hovered_event:
		return
	_hovered_event = region_index
	if region_index == 0:
		if _hovered_id == 0 and _hovered_status == 0 and _hovered_assets == 0:
			_hide_tooltip()
		return
	var event: OpenEvent = Game.sim.world.event_by_id(_events[region_index].event_id)
	if event == null:
		return
	_tooltip_label.text = tr(KEY_EVENT_TIP).format({
		PLACEHOLDER_TITLE: EventView.title(event.def, Game.sim.world, event.region),
		PLACEHOLDER_DAYS: event.days_left(Game.sim.world.day),
	})


## §16.3.2: the innermost status names itself and says how long it still has.
func _hover_status(region_index: int) -> void:
	if region_index == _hovered_status:
		return
	_hovered_status = region_index
	if region_index == 0:
		if _hovered_id == 0 and _hovered_assets == 0:
			_hide_tooltip()
		return
	_hovered_assets = 0
	var status: Status = Game.sim.world.statuses_in_region(region_index)[0]
	var days: String = tr(KEY_STANDING) if status.is_standing() \
		else str(status.days_left(Game.sim.world.day))
	_tooltip_label.text = tr(KEY_STATUS_TIP).format({
		PLACEHOLDER_STATUS: tr(StatusDef.name_key(status.id)),
		PLACEHOLDER_DAYS: days,
	})
	_tooltip.visible = true
	_place_tooltip_at(_statuses[region_index].position)


func _hide_tooltip() -> void:
	_tooltip.visible = false


## §16.3.2: the kinds and counts of a row, joined by ` · `.
func _hover_assets(region_index: int) -> void:
	if region_index == _hovered_assets:
		return
	_hovered_assets = region_index
	if region_index == 0:
		if _hovered_id == 0 and _hovered_status == 0:
			_hide_tooltip()
		return
	var marker: AssetMarker = _assets[region_index]
	var parts: Array[String] = []
	for kind: String in marker.kinds():
		var count: int = marker.counts[kind]
		parts.append("%d × %s" % [count, TechText.asset_name(kind, count)])
	_tooltip_label.text = tr(KEY_ASSETS_TIP).format(
		{PLACEHOLDER_ASSETS: ASSET_JOIN.join(parts)})
	_tooltip.visible = true
	_place_tooltip_at(marker.position)


## §7.7: the box sits up and to the right of the marker, and is pushed back
## inside the viewport when that would take it off the screen.
func _place_tooltip_at(anchor: Vector2) -> void:
	if _camera == null:
		_tooltip.visible = false
		return
	# The box lives in map coordinates like everything else here, so it is
	# counter-scaled to land on the screen at its authored size.
	_tooltip.scale = Vector2.ONE / _zoom
	_tooltip.size = _tooltip.get_combined_minimum_size()
	var to_screen: Transform2D = _camera.canvas_transform()
	var corner: Vector2 = to_screen * anchor + TOOLTIP_OFFSET_PX
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
		for index: int in _assets:
			_assets[index].scale = marker_scale
		for index: int in _statuses:
			_statuses[index].scale = marker_scale
		for index: int in _events:
			_events[index].scale = marker_scale
		if _team != null:
			_team.scale = marker_scale
		queue_redraw()
	if _hovered_event != 0 and _events.has(_hovered_event):
		_place_tooltip_at(_events[_hovered_event].position)
	elif _hovered_id != 0:
		_place_tooltip_at(_markers[_hovered_id].position)
	elif _hovered_status != 0 and _statuses.has(_hovered_status):
		_place_tooltip_at(_statuses[_hovered_status].position)
	elif _hovered_assets != 0 and _assets.has(_hovered_assets):
		_place_tooltip_at(_assets[_hovered_assets].position)
