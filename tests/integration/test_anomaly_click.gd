extends GutTest
## S6.P2 — an anomaly marker is hovered and collected wherever it is on the map,
## through the whole input path: the game's own main scene with the session in
## its slot, a real pointer motion, press and release pushed into the viewport,
## past every layer above the map, to `MapCamera`'s tap and `MarkerLayer`.
##
## The report: in the guided first run the coach says "click the circle" and
## nothing happened — for some circles and not for others, and those showed no
## tooltip either. The cause was `Main`, the root of `main.tscn`: a full-screen
## `Control` that stopped the mouse on the root canvas, which the map camera
## moves and scales, so it caught the pointer over a camera-shaped part of the
## screen. `test_marker_layer.gd` builds the session on its own and calls the
## camera directly, so it could see neither.
##
## Every region is probed — its anchor at the start view and centred at two
## zooms — so a blocker anywhere on the screen is found. A probe covered by a
## control the player can see (the HUD, the coach card) is skipped; the pointer
## belongs to that control. The seed is fixed (`SEED`); the anomaly is placed by
## the test, one region at a time, so no roll decides where it is.

const MAIN: PackedScene = preload("res://game/main.tscn")
const SEED: int = 7
const ORIGIN: String = "france"
const VECTOR: String = "cloud_federation"
const STEP_ANOMALY: String = "anomaly"
const MAX_DAYS: int = 200
## The window the scan runs in: the project's base, as a 16:9 desktop sees it.
const WINDOW: Vector2i = Vector2i(1920, 1080)
## The views a marker is probed in: the start view (where the anchors spread
## over the whole screen), then centred on the anchor at two zooms.
const START_VIEW: float = 0.0
const VIEWS: Array[float] = [START_VIEW, 1.0, 3.0]
const PROBE_VALUE: float = 5.0
## Fewer probes than this reached the map means the scan tested nothing.
const MIN_PROBES: int = 60
## The layers the session draws its interface on — a control there is seen.
const UI_LAYERS: Array[String] = ["HudLayer", "PanelLayer", "ModalLayer", "CoachLayer"]

var _session: Node = null
var _camera: MapCamera = null
var _layer: Node2D = null
var _window_size: Vector2i = Vector2i.ZERO
var _gut_layer: CanvasLayer = null
var _tutorial: bool = true
var _hints: bool = true
var _reduced_motion: bool = false
var _boot_seen: bool = false
## Whether the last probe's pointer reached the map (not the interface).
var _probed: bool = false


func before_each() -> void:
	_tutorial = Settings.tutorial
	_hints = Settings.hints
	_reduced_motion = Settings.reduced_motion
	_boot_seen = ProfileManager.boot_seen
	Settings.reduced_motion = true
	Settings.hints = false
	ProfileManager.clear_hints_seen()
	Game.stop_run()
	Game.debug_log = false
	_window_size = get_window().size
	get_window().size = WINDOW
	# GUT's own panel sits on a layer above the game and would take the clicks
	# on the right of the screen.
	_gut_layer = get_tree().root.find_child("GutLayer", true, false) as CanvasLayer
	if _gut_layer != null:
		_gut_layer.visible = false


func after_each() -> void:
	if _gut_layer != null:
		_gut_layer.visible = true
	get_window().size = _window_size
	ScreenRouter.slot = null
	# Assigned, not set: nothing here may write the player's settings file.
	Settings.tutorial = _tutorial
	Settings.hints = _hints
	Settings.reduced_motion = _reduced_motion
	ProfileManager.clear_hints_seen()
	ProfileManager.boot_seen = _boot_seen
	Game.stop_run()


## The game as it launches, then a new run from the title's path.
func _start_game(tutorial: bool) -> void:
	Settings.tutorial = tutorial
	add_child_autofree(MAIN.instantiate())
	await wait_process_frames(2)
	ScreenRouter.start_new_run(null, SEED)
	Game.set_speed(0)
	await wait_process_frames(2)
	_session = ScreenRouter.screen_node()
	_camera = _session.get_node("MapLayer/MapCamera") as MapCamera
	_layer = _session.get_node("MapLayer/MarkerLayer") as Node2D
	Game.site_confirm(ORIGIN)
	Game.set_speed(0)
	await wait_process_frames(2)


func _coach() -> Node:
	return _session.get_node("%Coach")


## The introduction's first five steps as a player takes them, then the days
## until the first anomaly brings its step up.
func _walk_to_the_anomaly_step() -> void:
	_coach().call(&"_on_next_pressed")
	await wait_process_frames(2)
	_session.call(&"_toggle_tech_tree")
	await wait_process_frames(2)
	Game.sim.world.agent.compute = 100.0
	Game.apply(PurchaseNodeCommand.new(VECTOR))
	await wait_process_frames(2)
	_session.call(&"_toggle_tech_tree")
	await wait_process_frames(2)
	_coach().call(&"_on_next_pressed")
	while Game.sim.world.day < MAX_DAYS and Game.sim.world.anomalies.is_empty():
		Game.advance(1)
	Game.set_speed(0)
	await wait_process_frames(3)


## One anomaly, in `region` — and no open event, whose marker would take the
## tap first (§16.3.2).
func _place_anomaly(region: int) -> Anomaly:
	var world: World = Game.sim.world
	var anomaly: Anomaly = Anomaly.new()
	anomaly.id = world.next_anomaly_id
	world.next_anomaly_id += 1
	anomaly.region = region
	anomaly.value = PROBE_VALUE
	anomaly.spawn_day = world.day
	anomaly.expires_day = world.day + Game.sim.db.balance.anomaly_lifetime_days
	world.anomalies.clear()
	world.anomalies.append(anomaly)
	world.events.clear()
	_layer.call(&"rebuild")
	return anomaly


func _push(event: InputEventMouse, at: Vector2) -> void:
	# `push_input` takes window pixels; the map answers in the viewport's.
	var window_at: Vector2 = get_viewport().get_final_transform() * at
	event.position = window_at
	event.global_position = window_at
	get_viewport().push_input(event)


func _click(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var button: InputEventMouseButton = InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = pressed
		button.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		_push(button, at)
		await wait_process_frames(1)


## Whether `control` is part of the interface the player sees over the map.
func _is_seen_interface(control: Control) -> bool:
	for layer_name: String in UI_LAYERS:
		if _session.get_node(layer_name).is_ancestor_of(control):
			return true
	return false


## Hovers and clicks one anomaly in `region`, the camera at the start view or
## centred on it at `zoom_level`; answers "" when it worked or the interface
## covered it, the reason otherwise. Sets `_probed` when the pointer reached the
## map.
func _probe(region: int, zoom_level: float) -> String:
	_probed = false
	var anomaly: Anomaly = _place_anomaly(region)
	var anchor: Vector2 = Vector2(Game.sim.world.regions[region].def.anchor)
	if zoom_level == START_VIEW:
		_camera.set_view(MapCamera.START_CENTER, _camera.zoom_min)
	else:
		_camera.set_view(anchor, zoom_level)
	var at: Vector2 = _camera.canvas_transform() * anchor
	if not Rect2(Vector2.ZERO, _camera.view_size()).grow(-AnomalyMarker.HIT_RADIUS_PX) \
			.has_point(at):
		return ""
	_push(InputEventMouseMotion.new(), at)
	await wait_process_frames(1)
	var over: Control = get_viewport().gui_get_hovered_control()
	if over != null and _is_seen_interface(over):
		return ""
	_probed = true
	var where: String = "%s at %s, zoom %.2f" % [Game.sim.db.regions[region].id, at,
		_camera.zoom.x]
	if over != null:
		return "%s: the pointer was taken by %s" % [where, over.get_path()]
	if not (_layer.call(&"tooltip") as Control).visible:
		return "%s: no tooltip" % where
	var compute: float = Game.sim.world.agent.compute
	await _click(at)
	if Game.sim.world.anomaly_in_region(anomaly.region) != null \
			or Game.sim.world.agent.compute <= compute:
		return "%s: the click did not collect it" % where
	return ""


## Every region in each of `VIEWS`.
func _scan() -> void:
	var failures: Array[String] = []
	var probes: int = 0
	for region: int in range(1, Game.sim.world.regions.size()):
		for zoom_level: float in VIEWS:
			var failure: String = await _probe(region, zoom_level)
			if _probed:
				probes += 1
			if not failure.is_empty():
				failures.append(failure)
	assert_gt(probes, MIN_PROBES, "the pointer reached the map often enough to mean something")
	assert_eq(failures.size(), 0, "every anomaly the pointer reached answered it:\n%s"
		% "\n".join(failures))


func test_a_click_collects_the_anomaly_the_coach_points_at() -> void:
	await _start_game(true)
	await _walk_to_the_anomaly_step()
	assert_eq(str(_coach().call(&"current_step")), STEP_ANOMALY,
		"the coach is on its anomaly step")
	await _scan()


func test_a_click_collects_an_anomaly_anywhere_on_the_map() -> void:
	await _start_game(false)
	await _scan()
