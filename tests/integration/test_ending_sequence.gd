extends GutTest
## S5.P — the ending's push-in (`screens-full.md` §7, G5 1/3 amendment): the
## camera goes to where the run ended before it pulls out — the region of the
## newest run-log entry that names one, else the origin — unless it is already
## there, and never with reduced motion.

const SESSION: PackedScene = preload("res://game/session/session.tscn")
const SessionScript: GDScript = preload("res://game/session/session.gd")

const SEED: int = 1
const ORIGIN: String = "usa"
const WIPED: String = "japan"
const PUSH_SECONDS: float = 0.7

var _session: Control = null
var _camera: MapCamera = null
var _reduced_motion: bool = false


func before_each() -> void:
	_reduced_motion = Settings.reduced_motion
	# The origin's own camera move is no tween with motion off, so every test
	# starts from a camera that is where `set_view` puts it.
	Settings.set_reduced_motion(true)
	Game.stop_run()
	Game.debug_log = false
	_session = SESSION.instantiate()
	add_child_autofree(_session)
	_camera = _session.get_node("MapLayer/MapCamera") as MapCamera
	Game.start_run(SEED)
	Game.set_speed(0)
	Game.apply(ChooseOriginCommand.new(ORIGIN))
	Settings.set_reduced_motion(false)


func after_each() -> void:
	Settings.set_reduced_motion(_reduced_motion)
	Game.stop_run()


func _index_of(region_id: String) -> int:
	return Game.db.region_index_by_id[region_id]


func _ending_region() -> int:
	return int(SessionScript.call(&"ending_region", Game.sim.world, Game.db))


func test_the_ending_region_is_the_newest_entry_that_names_one() -> void:
	var world: World = Game.sim.world
	world.run_log.append(RunLogEntry.create(world.day, SimEvent.REGION_WIPED,
		{"region": WIPED, "from": 0.8, "to": 0.2}))
	world.run_log.append(RunLogEntry.create(world.day, SimEvent.DISCOVERED,
		{"cause": "scrutiny"}))
	assert_eq(_ending_region(), _index_of(WIPED), "the discovery names no region")


func test_without_a_region_in_the_log_the_ending_region_is_the_origin() -> void:
	var world: World = Game.sim.world
	world.run_log.clear()
	world.run_log.append(RunLogEntry.create(world.day, SimEvent.DISCOVERED,
		{"cause": "scrutiny"}))
	assert_eq(_ending_region(), world.agent.origin)


func test_the_push_moves_in_from_the_whole_world() -> void:
	_camera.set_view(MapCamera.START_CENTER, _camera.zoom_min)
	var seconds: float = _camera.push_in(_index_of(WIPED), PUSH_SECONDS)
	assert_eq(seconds, PUSH_SECONDS)
	assert_almost_eq(_camera.target_zoom(), _camera.push_zoom(), 1e-6)
	assert_gt(_camera.push_zoom(), _camera.zoom_min, "a push is a push")
	assert_true(_camera.input_locked, "the map takes no input through the ending")


func test_the_push_is_skipped_when_the_camera_is_already_there() -> void:
	var index: int = _index_of(WIPED)
	var zoom_level: float = _camera.push_zoom()
	_camera.set_view(MapCamera.clamp_center(Vector2(Game.db.regions[index].anchor), zoom_level,
		_camera.view_size()), zoom_level)
	assert_eq(_camera.push_in(index, PUSH_SECONDS), 0.0)


func test_a_camera_closer_than_the_push_keeps_its_zoom() -> void:
	var index: int = _index_of(WIPED)
	var closer: float = minf(MapCamera.ZOOM_MAX, _camera.push_zoom() * 1.5)
	_camera.set_view(MapCamera.START_CENTER, closer)
	assert_eq(_camera.push_in(index, PUSH_SECONDS), PUSH_SECONDS)
	assert_almost_eq(_camera.target_zoom(), closer, 1e-6, "the push never zooms out")


func test_reduced_motion_skips_the_push() -> void:
	Settings.set_reduced_motion(true)
	_camera.set_view(MapCamera.START_CENTER, _camera.zoom_min)
	var seconds: float = _camera.push_in(_index_of(WIPED),
		UiTokens.duration(UiTokens.ENDING_PUSH))
	assert_eq(seconds, 0.0)
	assert_almost_eq(_camera.zoom.x, _camera.zoom_min, 1e-6, "the camera did not move")
