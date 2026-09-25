extends GutTest
## S6.P3 — an event's answer is chosen with the pointer, through the whole input
## path: the game's own main scene, the event's marker tapped on the map, the
## region panel's card, the option's button pressed by a click — and for a global
## event the wire card the session opens. Two click bugs slipped past tests that
## called the handlers directly (S6.P2, S6.P2b); this one only pushes input.
##
## What it checks is plain-language.md §5.2 C1–C2 as the player meets it: the
## effect line stands under every option before the answer, the card says what
## changed after it, and a node an answer hands over is marked in the tree until
## the tree has been open once.
##
## The seed is fixed (`SEED`); the events are scheduled by the test, so no roll
## decides what opens where.

const MAIN: PackedScene = preload("res://game/main.tscn")
const SEED: int = 7
const ORIGIN: String = "france"
const VECTOR: String = "cloud_federation"
const OPENING: String = "opening_unattended_cluster"
const GOAL: String = "emergent_goal_generalisation"
const WINDOW_FHD: Vector2i = Vector2i(1920, 1080)
const WINDOW_QHD: Vector2i = Vector2i(2560, 1440)
const COMPUTE: float = 98.0
const TABS: Array[String] = ["infiltration", "capabilities", "evasion"]

var _session: Node = null
## Taken before anything opens: the modal host reparents the card into its slot,
## where the session's `%` name no longer finds it.
var _wire: WireCard = null
var _tree: Control = null
var _window_size: Vector2i = Vector2i.ZERO
var _gut_layer: CanvasLayer = null
var _tutorial: bool = true
var _hints: bool = true
var _reduced_motion: bool = false
var _boot_seen: bool = false
var _locale: String = ""


func before_each() -> void:
	_tutorial = Settings.tutorial
	_hints = Settings.hints
	_reduced_motion = Settings.reduced_motion
	_boot_seen = ProfileManager.boot_seen
	_locale = TranslationServer.get_locale()
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
	TranslationServer.set_locale(_locale)
	Game.stop_run()


## The game as it launches, a new run from the title's path, the origin chosen,
## the vector bought and compute to spend.
func _start_game(window: Vector2i) -> void:
	Settings.tutorial = false
	Settings.hints = false
	TranslationServer.set_locale("en")
	get_window().size = window
	add_child_autofree(MAIN.instantiate())
	await wait_process_frames(2)
	ScreenRouter.start_new_run(null, SEED)
	Game.set_speed(0)
	await wait_process_frames(2)
	_session = ScreenRouter.screen_node()
	_wire = _session.get_node("%WireCard") as WireCard
	_tree = _session.get_node("%TechTree") as Control
	Game.site_confirm(ORIGIN)
	Game.set_speed(0)
	Fixtures.grant(Game.sim, COMPUTE)
	Fixtures.buy(Game.sim, [VECTOR] as Array[String])
	Game.sim.world.agent.compute = COMPUTE
	Game.set_speed(0)
	await wait_process_frames(3)


## Schedules `def_id` for tomorrow (`region_id` "" = global) and lets the tick
## open it, the way every event arrives.
func _arrive(def_id: String, region_id: String) -> OpenEvent:
	var region: int = 0 if region_id.is_empty() else int(Game.db.region_index_by_id[region_id])
	EventSystem.schedule(Game.sim.world, def_id, region, "", Game.sim.world.day + 1, 1)
	Game.advance(1)
	Game.set_speed(0)
	await wait_process_frames(3)
	for event: OpenEvent in Game.sim.world.events:
		if event.def == def_id:
			return event
	fail_test("%s did not open" % def_id)
	return null


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


## Taps the event marker of `region_id` on the map.
func _tap_marker(region_id: String) -> void:
	var index: int = int(Game.db.region_index_by_id[region_id])
	var camera: MapCamera = _session.get_node("MapLayer/MapCamera") as MapCamera
	var anchor: Vector2 = Vector2(Game.sim.world.regions[index].def.anchor)
	camera.set_view(anchor, 3.0)
	await wait_process_frames(2)
	await _click(camera.canvas_transform() * anchor + UiTokens.MARKER_EVENT_OFFSET)
	await wait_process_frames(4)


func _answer_on_the_card(window: Vector2i) -> void:
	await _start_game(window)
	var event: OpenEvent = await _arrive(OPENING, ORIGIN)
	await _tap_marker(ORIGIN)
	var panel: Control = _session.get_node("%RegionPanel") as Control
	assert_eq(int(panel.call(&"region_index")), int(Game.db.region_index_by_id[ORIGIN]),
		"the tap opened the region's panel")
	var card: EventCard = panel.call(&"event_card") as EventCard
	assert_true(card.is_visible_in_tree(), "the card shows")
	assert_eq(card.event_id(), event.id)
	var def: EventDef = Game.db.event(OPENING)
	for option: EventOptionDef in def.options:
		var line: Label = card.options().effect_of(option.id)
		assert_not_null(line, "%s has an effect line" % option.id)
		assert_eq(line.text, OptionText.line(Game.sim, def, option), "the generated line")
		assert_true(line.is_visible_in_tree(), "%s's line is on screen" % option.id)
	var button: ConsoleButton = card.options().button_of("take")
	await wait_process_frames(2)
	assert_eq(await _click_control(button), "", "the click reached the option's button")
	await wait_process_frames(2)
	assert_null(Game.sim.world.event_by_id(event.id), "the click answered the event")
	assert_true(card.changed_label().is_visible_in_tree(), "the card says what changed")
	assert_string_contains(card.changed_label().text, "Compute")
	assert_true(card.result_label().is_visible_in_tree(), "the result line follows")
	assert_false(card.options().is_visible_in_tree(), "the options are gone")


func test_an_opening_is_answered_by_pointer_at_1080() -> void:
	await _answer_on_the_card(WINDOW_FHD)


func test_an_opening_is_answered_by_pointer_at_1440() -> void:
	await _answer_on_the_card(WINDOW_QHD)


func test_a_global_answer_on_the_wire_card_marks_the_granted_node_once() -> void:
	await _start_game(WINDOW_FHD)
	var event: OpenEvent = await _arrive(GOAL, "")
	var wire: WireCard = _wire
	assert_true(wire.is_visible_in_tree(), "a global event opens the wire card")
	assert_eq(wire.event_id(), event.id)
	var keep: ConsoleButton = wire.options().button_of("keep")
	assert_string_contains(wire.options().effect_of("keep").text,
		tr(OptionText.KEY_FREE))
	assert_eq(await _click_control(keep), "", "the click reached the keep button")
	await wait_process_frames(2)
	assert_true(wire.is_showing_result(), "the card turned to its result")
	assert_true(wire.changed_label().is_visible_in_tree(), "the card says what changed")
	var tree: Control = _tree
	var marked: Array[String] = tree.call(&"marked_nodes")
	assert_eq(marked.size(), 1, "the node the answer handed over is marked")
	if marked.is_empty():
		return
	assert_string_contains(wire.changed_label().text, TechText.node_name(marked[0]))
	# Put the card away, open the tree on the node's tab: its card wears the mark.
	await _key(KEY_ESCAPE)
	await wait_process_frames(2)
	await _key(KEY_T)
	await wait_process_frames(2)
	assert_true(tree.visible, "the tree opened")
	tree.call(&"_on_tab_pressed", TABS.find(Game.db.tech(marked[0]).tree))
	await wait_process_frames(2)
	var node: TechNode = tree.get_node("%Board").call(&"node_for", marked[0]) as TechNode
	assert_true(node.is_marked(), "the granted node is marked in the tree")
	await _key(KEY_ESCAPE)
	await wait_process_frames(2)
	assert_false(tree.visible, "the tree closed")
	assert_eq(tree.call(&"marked_nodes"), [] as Array[String], "seen once, the mark is gone")
