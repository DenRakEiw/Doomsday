extends GutTest
## S6.P3 — a deploying technology is bought and placed with the pointer, through
## the whole input path: the game's own main scene, the tree opened by its key,
## the node selected by a click, the detail pane's buy button pressed by a click,
## a region tapped on the map and the region panel's place button pressed.
##
## The report: buying *Autonomous agriculture* did nothing — the click on the buy
## button neither closed the tree nor started the site select. The cause: the
## tree can be opened again while a site is being chosen, and a buy from it then
## closed the tree before it asked the map — so the running request was
## cancelled with no modal up, and its `on_cancel` put the tree straight back on
## the old node. Every further click did the same.
##
## The seed is fixed (`SEED`); the regions the node may go to are infected by the
## test, so no roll decides where it can stand.

const MAIN: PackedScene = preload("res://game/main.tscn")
const SEED: int = 7
const ORIGIN: String = "france"
const VECTOR: String = "cloud_federation"
const DEPLOYING: String = "agricultural_autonomy"
const PLAIN: String = "structure_prediction"
const SECOND: String = "traffic_control"
const FLEET: String = "fleet"
const WINDOW_FHD: Vector2i = Vector2i(1920, 1080)
const WINDOW_QHD: Vector2i = Vector2i(2560, 1440)
const COMPUTE: float = 98.0
const PENETRATION: float = 0.2
const UI_LAYERS: Array[String] = ["HudLayer", "PanelLayer", "ModalLayer", "CoachLayer"]

var _session: Node = null
var _tree: Control = null
var _window_size: Vector2i = Vector2i.ZERO
var _gut_layer: CanvasLayer = null
var _tutorial: bool = true
var _hints: bool = true
var _reduced_motion: bool = false
var _boot_seen: bool = false


func before_each() -> void:
	_tutorial = Settings.tutorial
	_hints = Settings.hints
	_reduced_motion = Settings.reduced_motion
	_boot_seen = ProfileManager.boot_seen
	Settings.reduced_motion = true
	ProfileManager.clear_hints_seen()
	Game.stop_run()
	Game.debug_log = false
	_window_size = get_window().size
	# GUT's own panel sits on a layer above the game and would take the clicks.
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


## The game as it launches, a new run from the title's path, the origin chosen,
## the vector bought, compute to spend and the poor regions infected.
func _start_game(tutorial: bool, window: Vector2i) -> void:
	Settings.tutorial = tutorial
	Settings.hints = tutorial
	get_window().size = window
	add_child_autofree(MAIN.instantiate())
	await wait_process_frames(2)
	ScreenRouter.start_new_run(null, SEED)
	Game.set_speed(0)
	await wait_process_frames(2)
	_session = ScreenRouter.screen_node()
	_tree = _session.get_node("%TechTree") as Control
	Game.site_confirm(ORIGIN)
	Game.set_speed(0)
	Fixtures.grant(Game.sim, COMPUTE)
	Fixtures.buy(Game.sim, [VECTOR] as Array[String])
	Game.sim.world.agent.compute = COMPUTE
	for region: Region in Game.sim.world.regions.slice(1):
		if region.penetration <= 0.0:
			region.penetration = PENETRATION
	Game.set_speed(0)
	await wait_process_frames(3)


func _push(event: InputEvent, at: Vector2) -> void:
	var mouse: InputEventMouse = event as InputEventMouse
	if mouse != null:
		# `push_input` takes window pixels; the controls answer in the viewport's.
		var window_at: Vector2 = get_viewport().get_final_transform() * at
		mouse.position = window_at
		mouse.global_position = window_at
	get_viewport().push_input(event)


func _click(at: Vector2) -> void:
	_push(InputEventMouseMotion.new(), at)
	await wait_process_frames(1)
	for pressed: bool in [true, false]:
		var button: InputEventMouseButton = InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = pressed
		button.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		_push(button, at)
		await wait_process_frames(1)


func _key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var key: InputEventKey = InputEventKey.new()
		key.keycode = keycode
		key.physical_keycode = keycode
		key.pressed = pressed
		_push(key, Vector2.ZERO)
		await wait_process_frames(1)


## Clicks the centre of `control`, reporting what the pointer landed on when it
## is not `control` (or something inside it).
func _click_control(control: Control) -> String:
	var at: Vector2 = control.get_global_rect().get_center()
	_push(InputEventMouseMotion.new(), at)
	await wait_process_frames(1)
	var over: Control = get_viewport().gui_get_hovered_control()
	await _click(at)
	if over == null:
		return "nothing under %s" % at
	if over != control and not control.is_ancestor_of(over):
		return "the pointer at %s was taken by %s" % [at, over.get_path()]
	return ""


func _open_tree() -> void:
	await _key(KEY_T)
	await wait_process_frames(2)


func _detail_buy() -> Button:
	return _tree.get_node("%TechDetail").get_node("%Buy") as Button


## The tree open, `node_id` selected by a click on its card, then a click on the
## detail pane's buy button.
func _select_and_click_buy(node_id: String) -> void:
	await _open_tree()
	assert_true(_tree.visible, "the tree opened")
	_tree.call(&"_on_tab_pressed", 1)
	await wait_process_frames(2)
	var card: TechNode = _tree.get_node("%Board").call(&"node_for", node_id) as TechNode
	assert_not_null(card, "the node is on the shown tab")
	(_tree.get_node("%Board") as Control).call(&"reveal", node_id)
	await wait_process_frames(3)
	assert_eq(await _click_control(card), "", "the click reached the node's card")
	await wait_process_frames(2)
	assert_eq(str(_tree.get_node("%TechDetail").call(&"shown_id")), node_id,
		"the click selected the node")
	var buy: Button = _detail_buy()
	assert_true(buy.is_visible_in_tree(), "the buy button shows")
	assert_false(buy.disabled, "the buy button is enabled")
	assert_eq(await _click_control(buy), "", "the click reached the buy button")
	await wait_process_frames(3)


## The site select running for the node: the tree closed, a region tapped on the
## map, the region panel's place button pressed.
func _place_by_pointer(node_id: String) -> void:
	assert_false(_tree.visible, "the tree closed")
	assert_true(Game.is_selecting_site(), "the site select is running")
	var site: String = Fixtures.first_site(Game.sim, Game.sim.db.tech(node_id))
	assert_ne(site, "", "a region takes the node")
	var index: int = Game.sim.db.regions.find(Game.sim.db.region_by_id(site))
	var camera: MapCamera = _session.get_node("MapLayer/MapCamera") as MapCamera
	var anchor: Vector2 = Vector2(Game.sim.world.regions[index].def.anchor)
	camera.set_view(anchor, 2.0)
	await wait_process_frames(2)
	await _click(camera.canvas_transform() * anchor)
	await wait_process_frames(3)
	var panel: Control = _session.get_node("%RegionPanel") as Control
	assert_eq(int(panel.call(&"region_index")), index, "the tap opened the region's panel")
	var place: Button = panel.get_node("%OriginButton") as Button
	assert_true(place.is_visible_in_tree(), "the place button shows")
	assert_eq(await _click_control(place), "", "the click reached the place button")
	await wait_process_frames(3)
	assert_true(Game.sim.world.agent.owns(node_id), "the node was bought")
	assert_gt(Game.sim.world.regions[index].asset_count(FLEET), 0, "a fleet stands there")
	assert_false(Game.is_selecting_site(), "the site select ended")


func _buy_and_place(tutorial: bool, window: Vector2i) -> void:
	await _start_game(tutorial, window)
	await _select_and_click_buy(DEPLOYING)
	await _place_by_pointer(DEPLOYING)


func test_deploy_by_pointer_without_tutorial_at_1080() -> void:
	await _buy_and_place(false, WINDOW_FHD)


func test_deploy_by_pointer_without_tutorial_at_1440() -> void:
	await _buy_and_place(false, WINDOW_QHD)


func test_deploy_by_pointer_with_tutorial_at_1080() -> void:
	await _buy_and_place(true, WINDOW_FHD)


func test_deploy_by_pointer_with_tutorial_at_1440() -> void:
	await _buy_and_place(true, WINDOW_QHD)


func test_deploy_by_enter_starts_the_site_select() -> void:
	await _start_game(false, WINDOW_FHD)
	await _open_tree()
	_tree.call(&"_on_tab_pressed", 1)
	await wait_process_frames(2)
	var card: TechNode = _tree.get_node("%Board").call(&"node_for", DEPLOYING) as TechNode
	card.grab_focus()
	await wait_process_frames(1)
	await _key(KEY_ENTER)
	await wait_process_frames(3)
	await _place_by_pointer(DEPLOYING)


func test_plain_node_by_pointer_is_bought_in_the_tree() -> void:
	await _start_game(false, WINDOW_QHD)
	await _select_and_click_buy(PLAIN)
	assert_true(Game.sim.world.agent.owns(PLAIN), "the node was bought")
	assert_true(_tree.visible, "the tree stays open")
	assert_false(Game.is_selecting_site(), "no site select")


## The tree opened again while a site is being chosen, and a deploying node
## bought from it: the first request gives way to the new one, and the tree stays
## closed rather than coming back on the node of the first.
func test_buying_while_a_site_is_chosen_starts_the_new_site_select() -> void:
	await _start_game(false, WINDOW_QHD)
	await _select_and_click_buy(SECOND)
	assert_true(Game.is_selecting_site(), "the first site select is running")
	await _select_and_click_buy(DEPLOYING)
	await _place_by_pointer(DEPLOYING)
	assert_false(Game.sim.world.agent.owns(SECOND), "the first node was not bought")
