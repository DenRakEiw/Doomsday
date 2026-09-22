extends Node2D
## Every link of the world, drawn over the map (spec ui-foundation.md §7.8).
##
## One `LinkLine` per link, in the order the content lists them, so a link's
## index here is its index in `world.links`. The layer owns three decisions the
## line itself cannot make, because each of them needs both endpoints or the
## day: whether the link is drawn at all, whether it is flowing, and which way.
##
## **Flow** is what a seeding looks like: for ten days after a `region_seeded`
## event named this link, the line lights up and its pattern travels from the
## source to the region that was seeded. Land links are drawn *only* then — the
## border already shows that two regions touch.
##
## Presentation only: it reads `Game.sim.world` after a tick and never writes it.
##
## Scene-specific, so no `class_name`.

## §7.8: how long a seeding keeps its link lit.
const FLOW_DAYS: int = 10

## Link index → the day its flow ends, and which way it runs.
var _flow_until: Dictionary[int, int] = {}
var _flow_forward: Dictionary[int, bool] = {}

var _lines: Array[LinkLine] = []
## `LinkDef.derive_id` of both endpoint orders → link index, so a seeding event
## finds its link without searching.
var _index_by_pair: Dictionary[String, int] = {}
var _camera: MapCamera = null
var _zoom: float = 1.0


func _ready() -> void:
	EventBus.run_started.connect(_on_run_started)
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.command_applied.connect(_on_command_applied)
	EventBus.sim_event.connect(_on_sim_event)
	_camera = MapCamera.find_beside(self)
	if _camera != null:
		_camera.view_changed.connect(_on_camera_view_changed)
		_zoom = _camera.zoom.x
	rebuild()


## §7.8's visibility rule. Sea, air and network links show the reach the agent
## has; a land link would only repeat the border, so it appears while something
## crosses it and disappears again. A dark region has neither hardware nor relay
## and is connected to nothing.
static func is_drawn(kind: String, a: Region, b: Region, flowing: bool) -> bool:
	if a.dark or b.dark:
		return false
	if kind == LinkDef.KIND_LAND:
		return flowing
	return a.penetration > 0.0 or b.penetration > 0.0


## Discards the lines and builds them again from the current run — at its start,
## and after a save was loaded into it.
func rebuild() -> void:
	for line: LinkLine in _lines:
		line.queue_free()
	_lines.clear()
	_index_by_pair.clear()
	_flow_until.clear()
	_flow_forward.clear()
	if Game.sim == null:
		return
	var world: World = Game.sim.world
	for index: int in world.links.size():
		var link: Link = world.links[index]
		var a: RegionDef = world.regions[link.def.a].def
		var b: RegionDef = world.regions[link.def.b].def
		var line: LinkLine = LinkLine.new()
		add_child(line)
		line.setup(Vector2(a.anchor), Vector2(b.anchor), link.def.kind)
		line.set_open(link.open)
		line.apply_zoom(_zoom)
		_lines.append(line)
		_index_by_pair[LinkDef.derive_id(a.id, b.id, link.def.kind)] = index
		_index_by_pair[LinkDef.derive_id(b.id, a.id, link.def.kind)] = index
	refresh()


## Re-reads visibility and the open state of every link. Cheap enough for every
## tick: it is a comparison per link and no allocation.
func refresh() -> void:
	if Game.sim == null:
		return
	var world: World = Game.sim.world
	for index: int in _lines.size():
		var link: Link = world.links[index]
		var line: LinkLine = _lines[index]
		var flowing: bool = _flow_until.has(index)
		line.set_open(link.open)
		line.set_flowing(flowing, bool(_flow_forward.get(index, true)))
		line.set_drawn(is_drawn(link.def.kind, world.regions[link.def.a],
			world.regions[link.def.b], flowing))


## The line of a link, for the tests and the gallery.
func line_at(index: int) -> LinkLine:
	return _lines[index] if index >= 0 and index < _lines.size() else null


func line_count() -> int:
	return _lines.size()


func _on_run_started(_seed_value: int) -> void:
	rebuild()


func _on_tick_advanced(day: int) -> void:
	for index: int in _flow_until.keys():
		if day >= _flow_until[index]:
			_flow_until.erase(index)
			_flow_forward.erase(index)
	refresh()


func _on_command_applied(_command: Command, result: CommandResult) -> void:
	if result.ok:
		refresh()


## A seeding names its link by its two region ids and the kind (core.md §6.4).
func _on_sim_event(event: SimEvent) -> void:
	if event.type != SimEvent.REGION_SEEDED:
		return
	var from_id: String = str(event.data.get("from", ""))
	var to_id: String = str(event.data.get("region", ""))
	var kind: String = str(event.data.get("link_kind", ""))
	var key: String = LinkDef.derive_id(from_id, to_id, kind)
	if not _index_by_pair.has(key):
		return
	var index: int = _index_by_pair[key]
	_flow_until[index] = event.day + FLOW_DAYS
	# The line runs from its first anchor to its second; the seeding may have
	# gone the other way, and the pattern has to follow the infection.
	_flow_forward[index] = Game.sim.world.links[index].def.a \
		== int(Game.db.region_index_by_id.get(from_id, 0))
	refresh()


func _on_camera_view_changed(_center: Vector2, zoom_level: float) -> void:
	if zoom_level <= 0.0 or is_equal_approx(zoom_level, _zoom):
		return
	_zoom = zoom_level
	for line: LinkLine in _lines:
		line.apply_zoom(_zoom)
