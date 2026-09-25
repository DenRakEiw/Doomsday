extends GutTest
## S6.8 — the modal's focus trap (accessibility.md §4.4): `Tab` wraps both ways,
## a disabled button never takes the first focus, a companion joins the ring,
## closing gives the focus back, and `Escape` in the pause menu's confirm is
## *Cancel*.

const SESSION: PackedScene = preload("res://game/session/session.tscn")
const PauseMenu: GDScript = preload("res://ui/modals/pause_menu.gd")
const SEED: int = 1

var _host: ModalHost = null
var _reduced_motion: bool = false


func before_each() -> void:
	_reduced_motion = Settings.reduced_motion
	Settings.reduced_motion = true
	_host = ModalHost.new()
	add_child_autofree(_host)


func after_each() -> void:
	Settings.reduced_motion = _reduced_motion
	Game.stop_run()


func _modal(labels: Array[String]) -> Control:
	var modal: VBoxContainer = VBoxContainer.new()
	modal.visible = false
	for label: String in labels:
		var button: Button = Button.new()
		button.name = label
		button.text = label
		modal.add_child(button)
	_host.add_child(modal)
	return modal


func _tab(backwards: bool = false) -> void:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_TAB
	key.shift_pressed = backwards
	key.pressed = true
	_host.call(&"_input", key)


func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


func test_tab_wraps_forwards_and_backwards() -> void:
	var modal: Control = _modal(["A", "B", "C"])
	_host.open(modal)
	assert_eq(_focus(), modal.get_node("A"))
	_tab(true)
	assert_eq(_focus(), modal.get_node("C"), "Shift+Tab before the first goes to the last")
	_tab()
	assert_eq(_focus(), modal.get_node("A"), "Tab past the last goes to the first")
	_tab()
	assert_eq(_focus(), modal.get_node("B"))


func test_a_disabled_first_button_is_skipped() -> void:
	var modal: Control = _modal(["A", "B"])
	(modal.get_node("A") as Button).disabled = true
	_host.open(modal)
	assert_eq(_focus(), modal.get_node("B"))


func test_a_companion_is_reachable_and_counts_as_inside() -> void:
	var modal: Control = _modal(["A"])
	var companion: Button = Button.new()
	companion.text = "coach"
	add_child_autofree(companion)
	_host.companions = [companion] as Array[Control]
	_host.open(modal)
	_tab()
	assert_eq(_focus(), companion, "after the modal's own controls")
	companion.grab_focus()
	assert_eq(_focus(), companion, "the trap does not pull it back in")
	var outsider: Button = Button.new()
	add_child_autofree(outsider)
	outsider.grab_focus()
	assert_eq(_focus(), modal.get_node("A"), "anything else is sent back")


func test_closing_gives_the_focus_back() -> void:
	var opener: Button = Button.new()
	add_child_autofree(opener)
	opener.grab_focus()
	var modal: Control = _modal(["A"])
	_host.open(modal)
	_host.close()
	assert_eq(_focus(), opener)


func test_the_opening_is_spoken_by_the_title() -> void:
	var modal: VBoxContainer = VBoxContainer.new()
	modal.visible = false
	var title: Label = Label.new()
	title.theme_type_variation = &"LabelDisplay"
	title.text = "The title"
	modal.add_child(title)
	_host.add_child(modal)
	await wait_process_frames(1)
	_host.live_region().force_active = true
	_host.open(modal)
	assert_eq(_host.live_region().text, "The title")
	assert_eq(_host.live_region().accessibility_live, AccessibilityServer.LIVE_ASSERTIVE)


func test_escape_in_the_pause_menu_s_confirm_is_cancel() -> void:
	Game.stop_run()
	var session: Control = SESSION.instantiate()
	add_child_autofree(session)
	var menu: PauseMenu = session.get_node("ModalLayer/ModalHost/PauseMenu")
	var modals: ModalHost = session.get_node("ModalLayer/ModalHost")
	Game.start_run(SEED)
	Game.apply(ChooseOriginCommand.new(Game.db.regions[1].id))
	session.call(&"_open_pause_menu")
	var confirm: ConfirmModal = menu.get_node("%PauseConfirm")
	var answer: Array[bool] = []
	confirm.answered.connect(func(yes: bool) -> void: answer.append(yes))
	confirm.ask("UI_PAUSE_QUIT_CONFIRM")
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	modals.call(&"_unhandled_input", escape)
	assert_eq(answer, [false] as Array[bool], "the confirm answered Cancel")
	assert_false(confirm.visible)
	assert_eq(modals.current(), menu, "and the menu is still open")
