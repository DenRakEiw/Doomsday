extends GutTest
## S2.6 — the anomaly markers as they are wired into a run
## (spec ui-foundation.md §7.7).
##
## The whole session scene, because the point of this layer is that it is asked
## about a tap *before* the land is (§7.4): a test that called `try_tap` itself
## would never notice that the camera stopped offering it.
##
## Motion is off throughout, so a marker that is taken off the map is gone in
## the same frame instead of fading for 200 ms.

const SESSION: PackedScene = preload("res://game/session/session.tscn")
const SEED: int = 1
## How far a run is driven while it is waited on; `greedy` spawns its first
## anomalies within a few days of taking an origin.
const STEP_DAYS: int = 10
const MAX_DAYS: int = 200

var _session: Control = null
var _layer: Node2D = null
var _camera: MapCamera = null
var _view: MapView = null
var _selected: Array[int] = []
var _reduced_motion: bool = false


func before_each() -> void:
	_reduced_motion = Settings.reduced_motion
	Settings.reduced_motion = true
	Game.stop_run()
	Game.debug_log = false
	_selected = []
	_session = SESSION.instantiate()
	add_child_autofree(_session)
	_layer = _session.get_node("MapLayer/MarkerLayer") as Node2D
	_camera = _session.get_node("MapLayer/MapCamera") as MapCamera
	_view = _session.get_node("MapLayer/MapView") as MapView
	EventBus.region_selected.connect(_on_region_selected)


func after_each() -> void:
	if EventBus.region_selected.is_connected(_on_region_selected):
		EventBus.region_selected.disconnect(_on_region_selected)
	Settings.reduced_motion = _reduced_motion
	Game.stop_run()


func _on_region_selected(index: int) -> void:
	_selected.append(index)


## Runs until there is an anomaly to look at, and returns it. The bot is then
## taken off the run: `greedy` collects every anomaly it sees, and this test is
## about the one the player is looking at.
func _run_to_an_anomaly() -> Anomaly:
	Game.start_run(SEED, GreedyPolicy.ID)
	Game.set_speed(0)
	while Game.sim.world.day < MAX_DAYS and Game.sim.world.anomalies.is_empty():
		Game.advance(STEP_DAYS)
	if Game.sim.world.anomalies.is_empty():
		fail_test("no anomaly spawned in %d days" % MAX_DAYS)
		return null
	Game.policy = null
	return Game.sim.world.anomalies[0]


## Puts a map pixel in the middle of the view and gives its screen position.
func _look_at(pixel: Vector2) -> Vector2:
	_camera.set_view(pixel, 3.0)
	return _camera.canvas_transform() * pixel


func _anchor_of(anomaly: Anomaly) -> Vector2:
	return Vector2(Game.sim.world.regions[anomaly.region].def.anchor)


func _tap(at: Vector2) -> void:
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = at
	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = at
	_camera.handle_pointer(press)
	_camera.handle_pointer(release)


# --------------------------------------------------------------- the markers


func test_without_a_run_there_is_nothing_on_the_map() -> void:
	assert_eq(_layer.marker_count(), 0)
	assert_eq(_layer.dark_count(), 0)


func test_every_anomaly_of_the_run_has_a_marker_at_its_anchor() -> void:
	var anomaly: Anomaly = _run_to_an_anomaly()
	assert_eq(_layer.marker_count(), Game.sim.world.anomalies.size())
	var marker: AnomalyMarker = _layer.marker_of(anomaly.id)
	assert_not_null(marker, "the first anomaly has one")
	assert_eq(marker.position, _anchor_of(anomaly), "at its region's anchor")
	assert_eq(marker.value, anomaly.value, "and it knows what it is worth")


func test_a_marker_counts_down_to_the_day_its_anomaly_fades() -> void:
	var anomaly: Anomaly = _run_to_an_anomaly()
	var marker: AnomalyMarker = _layer.marker_of(anomaly.id)
	assert_eq(marker.days_left, anomaly.expires_day - Game.sim.world.day)
	Game.advance(1)
	assert_eq(marker.days_left, anomaly.expires_day - Game.sim.world.day,
		"every tick hands the day out again")


func test_collecting_an_anomaly_takes_its_marker_off_the_map() -> void:
	var anomaly: Anomaly = _run_to_an_anomaly()
	var before: int = _layer.marker_count()

	Game.apply(CollectAnomalyCommand.new(anomaly.id))

	assert_eq(_layer.marker_count(), before - 1)
	assert_null(_layer.marker_of(anomaly.id))


func test_an_anomaly_that_fades_takes_its_marker_with_it() -> void:
	var anomaly: Anomaly = _run_to_an_anomaly()
	Game.advance(anomaly.expires_day - Game.sim.world.day)
	assert_null(_layer.marker_of(anomaly.id), "gone on the day it expires")


func test_the_markers_are_rebuilt_from_the_world_a_run_starts_with() -> void:
	var anomaly: Anomaly = _run_to_an_anomaly()
	assert_gt(_layer.marker_count(), 0, "arranged")
	# What a load does: a world arrives and the map has to show it.
	EventBus.run_started.emit(SEED)
	assert_eq(_layer.marker_count(), Game.sim.world.anomalies.size())
	assert_not_null(_layer.marker_of(anomaly.id))


func test_a_dark_region_is_marked_with_a_cross() -> void:
	_run_to_an_anomaly()
	var before: int = _layer.dark_count()
	var index: int = Game.db.region_index_by_id["japan"]
	# The state a depopulated region ends in, without waiting for the deaths.
	Game.sim.world.regions[index].dark = true
	EventBus.sim_event.emit(SimEvent.new(SimEvent.REGION_DEPOPULATED,
		Game.sim.world.day, {"region": "japan"}))
	assert_eq(_layer.dark_count(), before + 1)


# ------------------------------------------------------------------- the tap


func test_a_tap_on_a_marker_collects_it_before_the_map_sees_it() -> void:
	var anomaly: Anomaly = _run_to_an_anomaly()
	var compute: float = Game.sim.world.agent.compute
	var at: Vector2 = _look_at(_anchor_of(anomaly))

	_tap(at)

	assert_null(Game.sim.world.anomaly_in_region(anomaly.region), "it was collected")
	assert_gt(Game.sim.world.agent.compute, compute, "and paid out")
	assert_eq(_selected.size(), 0, "the region under it was never selected")


func test_a_tap_beside_a_marker_falls_through_to_the_region() -> void:
	var anomaly: Anomaly = _run_to_an_anomaly()
	var beside: Vector2 = _look_at(_anchor_of(anomaly)) \
		+ Vector2(AnomalyMarker.HIT_RADIUS_PX * 2.0, 0.0)
	# Whatever is under that point — land or water — is what the map must answer
	# with, and the test must not depend on the shape of a coastline.
	var under: int = MapPicker.region_at(beside, _camera, _view.id_image())

	_tap(beside)

	assert_not_null(Game.sim.world.anomaly_in_region(anomaly.region),
		"the anomaly is still there")
	assert_eq(_view.selected_index, under, "and the map answered the tap instead")


func test_resting_on_a_marker_says_what_it_is_worth() -> void:
	var anomaly: Anomaly = _run_to_an_anomaly()
	var at: Vector2 = _look_at(_anchor_of(anomaly))

	_layer.hover(at)

	var tooltip: Label = _layer.tooltip()
	assert_true(tooltip.visible, "the tooltip is up")
	assert_string_contains(tooltip.text,
		Format.number(anomaly.value, Format.Kind.COMPUTE),
		"and reads the anomaly's value")

	_layer.hover(at + Vector2(AnomalyMarker.HIT_RADIUS_PX * 2.0, 0.0))
	assert_false(_layer.tooltip().visible, "and goes again when the pointer leaves")


func test_the_markers_keep_their_screen_size_when_the_camera_zooms() -> void:
	var anomaly: Anomaly = _run_to_an_anomaly()
	var marker: AnomalyMarker = _layer.marker_of(anomaly.id)
	for zoom: float in [1.5, MapCamera.ZOOM_MAX]:
		_camera.set_view(_camera.position, zoom)
		assert_almost_eq(marker.scale.x * _camera.zoom.x, 1.0, 0.001,
			"at zoom %f" % zoom)
