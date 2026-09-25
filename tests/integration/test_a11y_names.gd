extends GutTest
## S6.8 — every control `Tab` can reach has a name a screen reader can say
## (accessibility.md §3.2 item 1), in both languages: the title, setup, the
## session with a region panel open, the pause menu with its settings, the Codex
## and the *Controls* modal.

const TITLE: PackedScene = preload("res://ui/screens/title.tscn")
const SETUP: PackedScene = preload("res://ui/screens/setup.tscn")
const SESSION: PackedScene = preload("res://game/session/session.tscn")
const PauseMenu: GDScript = preload("res://ui/modals/pause_menu.gd")
const SEED: int = 1
const LOCALES: Array[String] = ["en", "de"]

var _locale: String = ""
var _reduced_motion: bool = false


func before_each() -> void:
	_locale = Settings.locale
	_reduced_motion = Settings.reduced_motion
	Settings.reduced_motion = true
	Game.stop_run()
	Game.debug_log = false


func after_each() -> void:
	Settings.set_locale(_locale)
	Settings.reduced_motion = _reduced_motion
	Game.stop_run()


## The visible `Tab` stops under `root` that have neither a name nor text.
static func unnamed(root: Node) -> Array[String]:
	var out: Array[String] = []
	_walk(root, out)
	return out


static func _walk(node: Node, out: Array[String]) -> void:
	var control: Control = node as Control
	if control != null:
		if not control.is_visible_in_tree():
			return
		if control.focus_mode == Control.FOCUS_ALL and _name_of(control).strip_edges().is_empty():
			out.append(str(control.get_path()))
	for child: Node in node.get_children():
		_walk(child, out)


static func _name_of(control: Control) -> String:
	if not control.accessibility_name.is_empty():
		return control.accessibility_name
	var button: Button = control as Button
	return button.text if button != null else ""


func _check(root: Node, what: String) -> void:
	for locale: String in LOCALES:
		Settings.set_locale(locale)
		await wait_process_frames(1)
		var missing: Array[String] = unnamed(root)
		assert_eq(missing.size(), 0, "%s in %s: %s" % [what, locale, ", ".join(missing)])


func test_the_title_names_every_stop() -> void:
	var title: Control = TITLE.instantiate() as Control
	add_child_autofree(title)
	await _check(title, "title")


func test_setup_names_every_stop() -> void:
	var setup: Control = SETUP.instantiate() as Control
	add_child_autofree(setup)
	await _check(setup, "setup")


func test_the_session_names_every_stop() -> void:
	var session: Control = SESSION.instantiate() as Control
	add_child_autofree(session)
	Game.start_run(SEED)
	Game.apply(ChooseOriginCommand.new(Game.db.regions[1].id))
	EventBus.region_selected.emit(1)
	await _check(session, "session")


func test_the_pause_menu_and_its_modals_name_every_stop() -> void:
	var session: Control = SESSION.instantiate() as Control
	add_child_autofree(session)
	Game.start_run(SEED)
	Game.apply(ChooseOriginCommand.new(Game.db.regions[1].id))
	session.call(&"_open_pause_menu")
	var modals: ModalHost = session.get_node("ModalLayer/ModalHost")
	await _check(modals.current(), "pause menu")
	session.call(&"_open_controls")
	await _check(modals.current(), "controls")
	session.call(&"close_help")


func test_a_settings_button_is_named_by_its_row() -> void:
	var session: Control = SESSION.instantiate() as Control
	add_child_autofree(session)
	Game.start_run(SEED)
	var menu: PauseMenu = session.get_node("ModalLayer/ModalHost/PauseMenu")
	menu.refresh()
	var rows: Node = menu.get_node("%SettingsRows")
	var button: ConsoleButton = (rows.get_child(PauseMenu.INDEX_REDUCED_MOTION) as Container) \
		.get_child(1) as ConsoleButton
	assert_eq(button.accessibility_name, A11y.label_value(tr(PauseMenu.KEY_REDUCED_MOTION),
		menu.setting_value(PauseMenu.INDEX_REDUCED_MOTION)))


func test_the_codex_names_every_stop() -> void:
	var session: Control = SESSION.instantiate() as Control
	add_child_autofree(session)
	Game.start_run(SEED)
	session.call(&"open_help", "")
	var modals: ModalHost = session.get_node("ModalLayer/ModalHost")
	await _check(modals.current(), "codex")
	session.call(&"close_help")
