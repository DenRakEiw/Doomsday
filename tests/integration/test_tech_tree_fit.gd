extends GutTest
## S6.P3b — the whole tech tree on one screen (punch item 2) and why a node is
## locked (punch item 4), through the game's own main scene.
##
## The user played at 2560×1440 with 150 % display scaling — the same 1920×1080 of
## logical pixels the project lays out in — and the tallest tab ran off the
## screen. Now every tab fits the board without scrolling at 1920×1080 and
## 2560×1440, in both languages, every name in its two lines; and a node that
## cannot be bought says why, in the detail pane and on its card. The clicks are
## real: pushed into the viewport, never a handler called, because two click bugs
## slipped past tests that did (S6.P2, S6.P2b).
##
## The seed is fixed (`SEED`).

const MAIN: PackedScene = preload("res://game/main.tscn")
const SEED: int = 7
const ORIGIN: String = "france"
const VECTOR: String = "cloud_federation"
const COMPUTE: float = 98.0
const WINDOW_FHD: Vector2i = Vector2i(1920, 1080)
const WINDOW_QHD: Vector2i = Vector2i(2560, 1440)
const TABS: Array[String] = ["infiltration", "capabilities", "evasion"]
const LOCALES: Array[String] = ["en", "de"]
## A capability two steps from anything owned at the start: locked, with a
## prerequisite missing and a set of which one is enough.
const LOCKED: String = "distributed_synthesis"
## A plain capability the start can afford.
const PLAIN: String = "structure_prediction"
## Pixels a rectangle may stand out of another by rounding alone.
const SLACK: float = 1.0

var _session: Node = null
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


func _start_game(window: Vector2i, locale: String = "en") -> void:
	Settings.tutorial = false
	Settings.hints = false
	TranslationServer.set_locale(locale)
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


## Opens the tree by its key and shows `tab` by clicking the tab's button.
func _open_on_tab(tab: String) -> void:
	if not _tree.visible:
		await _key(KEY_T)
		await wait_process_frames(3)
	var tabs: Container = _tree.get_node("%Tabs") as Container
	var button: Control = tabs.get_child(TABS.find(tab)) as Control
	assert_eq(await _click_control(button), "", "the click reached the %s tab" % tab)
	await wait_process_frames(3)


func _board() -> Control:
	return _tree.get_node("%Board") as Control


## Every card of the shown tab, and what does not fit: a card outside the board's
## visible room, or a name on more than its two lines.
func _misfits(tag: String) -> Array[String]:
	var scroll: ScrollContainer = _tree.get_node("%BoardScroll") as ScrollContainer
	var room: Rect2 = scroll.get_global_rect().grow(SLACK)
	var out: Array[String] = []
	var cards: int = 0
	for child: Node in (_board().get_node("%Grid") as Node).get_children():
		var card: TechNode = child as TechNode
		if card == null:
			continue
		cards += 1
		if not room.encloses(card.get_global_rect()):
			out.append("%s %s: %s outside %s" % [tag, card.node_id, card.get_global_rect(), room])
		var name_label: Label = card.get_node("%NodeName") as Label
		if name_label.get_line_count() > TechNode.NAME_LINES:
			out.append("%s %s: %d lines" % [tag, card.node_id, name_label.get_line_count()])
	if cards == 0:
		out.append("%s: no cards" % tag)
	return out


func _fits_everywhere(window: Vector2i) -> void:
	await _start_game(window)
	for locale: String in LOCALES:
		# The locale changes under the open game, as the settings change it.
		TranslationServer.set_locale(locale)
		await wait_process_frames(3)
		for tab: String in TABS:
			await _open_on_tab(tab)
			var scroll: ScrollContainer = _tree.get_node("%BoardScroll") as ScrollContainer
			var tag: String = "%s %s %s" % [window, locale, tab]
			assert_eq(_misfits(tag), [] as Array[String])
			assert_false(scroll.get_v_scroll_bar().visible, "%s: no vertical scroll" % tag)
			assert_false(scroll.get_h_scroll_bar().visible, "%s: no horizontal scroll" % tag)


func test_every_tab_fits_at_1080() -> void:
	await _fits_everywhere(WINDOW_FHD)


func test_every_tab_fits_at_1440() -> void:
	await _fits_everywhere(WINDOW_QHD)


func test_the_tallest_tab_is_dense_and_a_short_one_is_not() -> void:
	await _start_game(WINDOW_FHD)
	await _open_on_tab("capabilities")
	assert_true(_board().call(&"is_dense"), "twelve rows give up height")
	await _open_on_tab("evasion")
	assert_false(_board().call(&"is_dense"), "five rows keep the full card")


func test_a_locked_node_clicked_says_why() -> void:
	await _start_game(WINDOW_FHD)
	await _open_on_tab("capabilities")
	var card: TechNode = _board().call(&"node_for", LOCKED) as TechNode
	assert_not_null(card)
	assert_eq(card.state, TechNode.State.LOCKED, "the fixture: the node is locked")
	# No `reveal`: the whole tab is on screen.
	assert_eq(await _click_control(card), "", "the click reached the locked card")
	await wait_process_frames(2)
	var detail: Control = _tree.get_node("%TechDetail") as Control
	assert_eq(str(detail.call(&"shown_id")), LOCKED, "the click selected it")
	var hint: Label = detail.get_node("%LockedHint") as Label
	assert_true(hint.is_visible_in_tree(), "the detail says why")
	var definition: TechNodeDef = Game.db.tech(LOCKED)
	var expected: PackedStringArray = NodeLockText.reasons(definition, Game.sim)
	assert_eq(hint.text, "\n".join(expected))
	var missing: String = ""
	for node_id: String in definition.requires:
		if not Game.sim.world.agent.owns(node_id):
			missing = node_id
	assert_ne(missing, "", "the fixture: a prerequisite is missing")
	assert_string_contains(hint.text, TechText.node_name(missing), "it names what is missing")
	assert_eq(card.get_tooltip(Vector2.ZERO), hint.text, "resting on the card says the same")


func test_a_plain_node_is_bought_from_the_fitted_tree_by_pointer() -> void:
	await _start_game(WINDOW_QHD)
	await _open_on_tab("capabilities")
	var card: TechNode = _board().call(&"node_for", PLAIN) as TechNode
	assert_eq(await _click_control(card), "", "the click reached the card")
	await wait_process_frames(2)
	var detail: Control = _tree.get_node("%TechDetail") as Control
	assert_eq(str(detail.call(&"shown_id")), PLAIN, "the click selected it")
	assert_false((detail.get_node("%LockedHint") as Label).visible, "nothing stands in the way")
	assert_eq(card.get_tooltip(Vector2.ZERO), "", "an affordable card has nothing to explain")
	var buy: Button = detail.get_node("%Buy") as Button
	assert_eq(await _click_control(buy), "", "the click reached the buy button")
	await wait_process_frames(3)
	assert_true(Game.sim.world.agent.owns(PLAIN), "the node was bought")
