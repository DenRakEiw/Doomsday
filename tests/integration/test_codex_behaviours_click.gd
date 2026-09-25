extends GutTest
## S6.P4 — the Codex's *Behaviours* tab (plain-language.md §9.3, §9.4 item 5),
## through the whole input path: the game's own main scene, the title's Codex
## button pressed by a click, the tab pressed by a click, an entry pressed by a
## click. A behaviour not yet met is listed locked; one met shows its title, the
## term's plain line, the card's body and each answer with its effect line.
##
## No run and no randomness: the behaviour is marked seen in the profile.

const MAIN: PackedScene = preload("res://game/main.tscn")
const WINDOW_FHD: Vector2i = Vector2i(1920, 1080)
const SEEN: String = "emergent_mesa_optimiser"
const UNSEEN: String = "emergent_sycophancy"
## The first behaviour in content order.
const FIRST: String = "emergent_situational_awareness"
const TAB_KEY: String = "UI_CODEX_TAB_BEHAVIOURS"

var _window_size: Vector2i = Vector2i.ZERO
var _gut_layer: CanvasLayer = null
var _reduced_motion: bool = false
var _boot_seen: bool = false


func before_each() -> void:
	_reduced_motion = Settings.reduced_motion
	_boot_seen = ProfileManager.boot_seen
	Settings.reduced_motion = true
	Game.stop_run()
	Game.debug_log = false
	ProfileManager.reset()
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
	Settings.reduced_motion = _reduced_motion
	ProfileManager.reset()
	ProfileManager.boot_seen = _boot_seen
	Game.stop_run()


func _push(event: InputEvent, at: Vector2) -> void:
	var mouse: InputEventMouse = event as InputEventMouse
	if mouse != null:
		# `push_input` takes window pixels; the controls answer in the viewport's.
		var window_at: Vector2 = get_viewport().get_final_transform() * at
		mouse.position = window_at
		mouse.global_position = window_at
	get_viewport().push_input(event)


## Clicks the centre of `control`, reporting what the pointer landed on when it
## is not `control` (or something inside it).
func _click_control(control: Control) -> String:
	var at: Vector2 = control.get_global_rect().get_center()
	_push(InputEventMouseMotion.new(), at)
	await wait_process_frames(1)
	var over: Control = get_viewport().gui_get_hovered_control()
	for pressed: bool in [true, false]:
		var button: InputEventMouseButton = InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = pressed
		button.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		_push(button, at)
		await wait_process_frames(1)
	if over == null:
		return "nothing under %s" % at
	if over != control and not control.is_ancestor_of(over):
		return "the pointer at %s was taken by %s" % [at, over.get_path()]
	return ""


## The title of the game as it launches, the Codex opened by a click on its
## button and the *Behaviours* tab by a click on its own.
func _open_behaviours() -> Control:
	get_window().size = WINDOW_FHD
	ProfileManager.boot_seen = true
	add_child_autofree(MAIN.instantiate())
	await wait_process_frames(2)
	ScreenRouter.go_to_title()
	await wait_process_frames(3)
	var title: Node = ScreenRouter.screen_node()
	var codex_button: Control = title.get_node("%CodexButton") as Control
	assert_eq(await _click_control(codex_button), "", "the click reached the Codex button")
	await wait_process_frames(2)
	# The host moves its modals into its slot, so the scene's unique name is gone.
	var codex: Control = title.find_child("Codex", true, false) as Control
	assert_true(codex.is_visible_in_tree(), "the Codex opened")
	var tab: ConsoleButton = null
	for button: Node in codex.find_children("*", "ConsoleButton", true, false):
		if (button as ConsoleButton).label_key == TAB_KEY:
			tab = button as ConsoleButton
	assert_not_null(tab, "the tab exists")
	assert_true(tab.is_visible_in_tree(), "the tab shows")
	assert_eq(await _click_control(tab), "", "the click reached the tab")
	await wait_process_frames(2)
	assert_eq(str(codex.get(&"tab")), CodexEntries.TAB_BEHAVIOURS, "the click chose the tab")
	return codex


func _entry_texts(codex: Control) -> Array[String]:
	var texts: Array[String] = []
	for label: Node in codex.get_node("%Entry").find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	return texts


func test_every_behaviour_is_listed_and_one_not_met_is_locked() -> void:
	ProfileManager.merge_codex(CodexEntries.TAB_BEHAVIOURS, [SEEN] as Array[String])
	var codex: Control = await _open_behaviours()
	var ids: Array[String] = CodexEntries.behaviours(Game.content())
	assert_eq(ids.size(), 12, "all twelve behaviours")
	for id: String in ids:
		assert_not_null(codex.call(&"row_for", id), id)
	var locked: ConsoleButton = codex.call(&"row_for", UNSEEN) as ConsoleButton
	assert_true(locked.disabled, "a behaviour not met cannot be opened")
	assert_eq(locked.text, tr("UI_CODEX_LOCKED"))
	assert_eq((codex.get_node("%Progress") as Label).text,
		tr("UI_CODEX_PROGRESS").format({"seen": 1, "total": ids.size()}))


func test_a_behaviour_met_opens_with_its_term_body_and_answers() -> void:
	# The first behaviour met opens by itself at full width; the click opens the other.
	ProfileManager.merge_codex(CodexEntries.TAB_BEHAVIOURS,
		[FIRST, SEEN] as Array[String])
	var codex: Control = await _open_behaviours()
	assert_eq(str(codex.get(&"entry_id")), FIRST)
	var row: ConsoleButton = codex.call(&"row_for", SEEN) as ConsoleButton
	assert_false(row.disabled)
	assert_eq(row.text, tr(EventDef.title_key(SEEN)))
	assert_eq(await _click_control(row), "", "the click reached the row")
	await wait_process_frames(2)
	assert_eq(str(codex.get(&"entry_id")), SEEN, "the click opened the entry")
	var texts: Array[String] = _entry_texts(codex)
	assert_has(texts, tr(EventDef.title_key(SEEN)))
	assert_has(texts, tr("CODEX_EMERGENT_MESA_OPTIMISER_TERM"))
	assert_has(texts, tr(EventDef.body_key(SEEN)))
	var def: EventDef = Game.content().event(SEEN)
	for option: EventOptionDef in def.options:
		assert_has(texts, Format.caps(tr(EventOptionDef.text_key(SEEN, option.id))))
		assert_has(texts, OptionText.line_without_run(Game.content(), def, option))
	for text: String in texts:
		assert_false(text.contains("{"), "no placeholder left: %s" % text)
