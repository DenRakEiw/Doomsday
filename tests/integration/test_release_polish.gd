extends GutTest
## S7.IP — what the itch captures and the phone shots showed, through the game's
## own main scene at the window size the player has: the overlay picker beside
## the region panel (S7.I), the tech detail sheet and Statistics on a 400-px
## phone (S6.P3b, S6.9), and a German percentage that wrapped its `%` onto a
## line of its own (S7.I). The clicks are real: pushed into the viewport, never
## a handler called (S6.P2, S6.P2b).
##
## The seed is fixed (`SEED`).

const MAIN: PackedScene = preload("res://game/main.tscn")
const SEED: int = 7
const ORIGIN: String = "france"
const VECTOR: String = "cloud_federation"
const COMPUTE: float = 98.0
## The counter-move on S7.I's capture: a card taller than the region panel.
const COUNTER_MOVE: String = "cm_lockdown"
const WINDOW_FHD: Vector2i = Vector2i(1920, 1080)
## A phone's logical window (ui-foundation §5.7).
const WINDOW_PHONE: Vector2i = Vector2i(400, 860)
const LARGE_TEXT: float = 1.5
## Nodes whose prerequisite lives in another tab, and whose detail row ran off
## the phone (PROGRESS *Known issues*, S6.P3b and S6.P4).
const ELSEWHERE_NODES: Array[String] = ["distributed_synthesis", "constitutional_integration"]
## Capabilities with a footprint of their own, bought at the start (S6.4's
## overflow: *Erworben*, the footprint and the check in one footer).
const FOOTPRINT_NODES: Array[String] = ["early_warning_intrusion", "sycophancy_tuning"]
## Pixels a rectangle may stand out of another by rounding alone.
const SLACK: float = 1.0
## Where the picker's last toggle peeked out: this far right of the panel.
const PEEK_OFFSET: float = 24.0
## Widths a wrapped German effect line is laid out at, in pixels.
const WRAP_FROM: int = 60
const WRAP_TO: int = 420
const WRAP_STEP: int = 2
const WRAP_FONT_SIZE: int = 16

var _session: Node = null
## The viewport the game runs in: the window's, or a phone-sized one.
var _view: Viewport = null
var _window_size: Vector2i = Vector2i.ZERO
var _gut_layer: CanvasLayer = null
var _tutorial: bool = true
var _hints: bool = true
var _reduced_motion: bool = false
var _boot_seen: bool = false
var _locale: String = ""
var _text_scale: float = 1.0


func before_each() -> void:
	_tutorial = Settings.tutorial
	_hints = Settings.hints
	_reduced_motion = Settings.reduced_motion
	_boot_seen = ProfileManager.boot_seen
	_locale = TranslationServer.get_locale()
	_text_scale = Settings.text_scale
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
	Settings.set_text_scale(_text_scale)
	ProfileManager.clear_hints_seen()
	ProfileManager.boot_seen = _boot_seen
	ProfileManager.history.clear()
	TranslationServer.set_locale(_locale)
	Game.stop_run()


func _launch(window: Vector2i, locale: String, text_scale: float = 1.0) -> void:
	Settings.tutorial = false
	Settings.hints = false
	Settings.set_text_scale(text_scale)
	TranslationServer.set_locale(locale)
	if window.x < UiTokens.COMPACT_WIDTH:
		# A phone in a viewport of its own: the headless window keeps the
		# project's desktop scale, so only a viewport this small lays out as one.
		var phone: SubViewport = SubViewport.new()
		phone.size = window
		add_child_autofree(phone)
		phone.add_child(MAIN.instantiate())
		_view = phone
	else:
		get_window().size = window
		add_child_autofree(MAIN.instantiate())
		_view = get_viewport()
	await wait_process_frames(3)


## The game as it launches, a new run from the title's path, the origin chosen.
func _start_run(window: Vector2i, locale: String, text_scale: float = 1.0) -> void:
	await _launch(window, locale, text_scale)
	ScreenRouter.start_new_run(null, SEED)
	Game.set_speed(0)
	await wait_process_frames(2)
	_session = ScreenRouter.screen_node()
	Game.site_confirm(ORIGIN)
	Game.set_speed(0)
	Fixtures.grant(Game.sim, COMPUTE)
	Fixtures.buy(Game.sim, [VECTOR] as Array[String])
	Game.set_speed(0)
	await wait_process_frames(3)


func _push(event: InputEvent, at: Vector2) -> void:
	var mouse: InputEventMouse = event as InputEventMouse
	if mouse != null:
		# `push_input` takes window pixels; the controls answer in the viewport's.
		var window_at: Vector2 = _view.get_final_transform() * at
		mouse.position = window_at
		mouse.global_position = window_at
	_view.push_input(event)


func _hover(at: Vector2) -> Control:
	_push(InputEventMouseMotion.new(), at)
	await wait_process_frames(1)
	return _view.gui_get_hovered_control()


func _click(at: Vector2) -> void:
	await _hover(at)
	for pressed: bool in [true, false]:
		var button: InputEventMouseButton = InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = pressed
		button.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		_push(button, at)
		await wait_process_frames(1)


## Clicks the centre of `control`; "" when the pointer reached it.
func _click_control(control: Control) -> String:
	var at: Vector2 = control.get_global_rect().get_center()
	var over: Control = await _hover(at)
	await _click(at)
	if over == null or (over != control and not control.is_ancestor_of(over)):
		return "the pointer at %s was taken by %s" % [at, over]
	return ""


## Every visible control under `root` whose right edge is past `right`.
func _past(root: Control, right: float) -> Array[String]:
	var out: Array[String] = []
	for node: Node in root.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if control.is_visible_in_tree() and control.get_global_rect().end.x > right + SLACK:
			out.append("%s ends at %.0f" % [root.get_path_to(control),
				control.get_global_rect().end.x])
	return out


## Every visible wrapping label under `root` too narrow for one of its words —
## a label squeezed until it breaks inside a word (*FAST / EST / WIN*). Words
## end at a space, a hyphen or a soft hyphen. `skip` is left out.
func _broken_words(root: Control, skip: Array[Control] = []) -> Array[String]:
	var out: Array[String] = []
	var split: RegEx = RegEx.create_from_string("[^ \\-\u00ad]+")
	for node: Node in root.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if skip.has(label) or not label.is_visible_in_tree() 				or label.autowrap_mode == TextServer.AUTOWRAP_OFF:
			continue
		var font: Font = label.get_theme_font(&"font")
		var font_size: int = label.get_theme_font_size(&"font_size")
		var style: StyleBox = label.get_theme_stylebox(&"normal")
		var room: float = label.size.x - style.get_margin(SIDE_LEFT) - style.get_margin(SIDE_RIGHT)
		for found: RegExMatch in split.search_all(label.text):
			var word: String = found.get_string()
			var width: float = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
				font_size).x
			if width > room + SLACK:
				out.append("%s: %s (%.0f in %.0f)" % [root.get_path_to(label), word, width, room])
	return out


func _picker() -> Control:
	return _session.get_node("%Hud").get_node("%OverlayPicker") as Control


func _region_panel() -> SlidePanel:
	return _session.get_node("PanelLayer/RegionPanel") as SlidePanel


## Emergent: the picker offers all four modes (overlay_picker.gd `_modes_for`).
func _reveal_four_modes() -> void:
	Game.sim.world.phase = World.Phase.EMERGENT
	_session.get_node("%Hud").call(&"apply_reveal")
	await wait_process_frames(3)


## The origin clicked on the map, the way a player opens its panel.
func _click_origin_on_the_map() -> void:
	var camera: MapCamera = _session.get_node("MapLayer/MapCamera") as MapCamera
	var index: int = int(Game.db.region_index_by_id[ORIGIN])
	var anchor: Vector2 = Vector2(Game.sim.world.regions[index].def.anchor)
	camera.set_view(anchor, camera.zoom_min * 2.0)
	await wait_process_frames(2)
	await _click(camera.canvas_transform() * anchor)
	await wait_process_frames(4)


func test_the_picker_does_not_peek_out_beside_the_region_panel() -> void:
	await _start_run(WINDOW_FHD, "de")
	await _reveal_four_modes()
	var picker: Control = _picker()
	assert_true(picker.is_visible_in_tree(), "four modes on show")
	var peek: Rect2 = picker.get_global_rect()
	await _click_origin_on_the_map()
	var panel: SlidePanel = _region_panel()
	assert_true(panel.is_open, "the click opened the region panel")
	var cover: Rect2 = panel.covered_rect()
	assert_gt(peek.end.x, cover.end.x, "four German toggles are wider than the panel")
	assert_eq(_past(picker, cover.end.x), [] as Array[String], "nothing beside the panel")
	var beside: Vector2 = Vector2(cover.end.x + PEEK_OFFSET, peek.get_center().y)
	var over: Control = await _hover(beside)
	assert_false(over != null and (over == picker or picker.is_ancestor_of(over)),
		"the pointer beside the panel does not find a toggle")
	panel.close()
	await wait_process_frames(4)
	assert_true(picker.is_visible_in_tree(), "the panel closed, the picker is back")


func test_the_picker_stays_while_no_panel_is_open() -> void:
	await _start_run(WINDOW_FHD, "en")
	await _reveal_four_modes()
	var picker: Control = _picker()
	var toggle: Control = picker.get_node("%Row").get_child(3) as Control
	assert_eq(await _click_control(toggle), "", "the click reached the fourth toggle")
	assert_eq(int(picker.get(&"mode")), int(MapView.Overlay.SOCIETY))


## S7.IP (seen on the itch capture): a counter-move's card taller than the
## region panel opened scrolled to its end, its heading out of view. The card is
## opened the way a tap on its marker does (`MarkerLayer.try_tap`).
func test_a_tall_event_card_opens_on_its_heading() -> void:
	await _start_run(WINDOW_FHD, "de", LARGE_TEXT)
	Game.debug_schedule_event(COUNTER_MOVE, ORIGIN)
	Game.advance(1)
	Game.set_speed(0)
	await _click_origin_on_the_map()
	var panel: SlidePanel = _region_panel()
	assert_true(panel.is_open, "the click opened the region panel")
	var index: int = int(Game.db.region_index_by_id[ORIGIN])
	EventBus.event_card_requested.emit(index)
	await wait_process_frames(4)
	var card: Control = panel.call(&"event_card") as Control
	var scroll: Control = panel.get_node("Panel/Scroll") as Control
	assert_true(card.is_visible_in_tree(), "the counter-move's card is up")
	assert_gt(card.size.y, scroll.size.y, "taller than the panel at 150 %")
	assert_almost_eq(card.get_global_rect().position.y, scroll.get_global_rect().position.y,
		SLACK * 2.0, "its heading at the top of the view")


func _tech_sheet_fits(locale: String, text_scale: float) -> void:
	await _start_run(WINDOW_PHONE, locale, text_scale)
	var tree: Control = _session.get_node("%TechTree") as Control
	_session.call(&"_toggle_tech_tree")
	await wait_process_frames(3)
	var sheet: SlidePanel = tree.get(&"_sheet") as SlidePanel
	for node_id: String in ELSEWHERE_NODES:
		tree.call(&"open_on", node_id)
		await wait_process_frames(4)
		assert_true(sheet.is_open, "%s: the sheet is up" % node_id)
		assert_eq(_past(sheet, float(WINDOW_PHONE.x)), [] as Array[String],
			"%s %s %.0f %%: the sheet fits the phone" % [node_id, locale, text_scale * 100.0])
		# The node's name in the heading is left out: *Verfassungsrang* at 150 %
		# is wider than any phone and has to break (PROGRESS *Known issues*, D7.1).
		var heading: Control = sheet.find_child("Title", true, false) as Control
		assert_eq(_broken_words(sheet, [heading] as Array[Control]), [] as Array[String],
			"%s %s %.0f %%: no word broken" % [node_id, locale, text_scale * 100.0])


func test_the_tech_detail_sheet_fits_a_phone_in_english() -> void:
	await _tech_sheet_fits("en", 1.0)


func test_the_tech_detail_sheet_fits_a_phone_in_german_at_large_text() -> void:
	await _tech_sheet_fits("de", LARGE_TEXT)


## S7.IP (seen in S6.4): an owned card with a footprint keeps its footer inside
## its own border on the phone's compact cells.
func _owned_cards_fit(locale: String, text_scale: float) -> void:
	await _start_run(WINDOW_PHONE, locale, text_scale)
	Fixtures.buy(Game.sim, FOOTPRINT_NODES)
	var tree: Control = _session.get_node("%TechTree") as Control
	_session.call(&"_toggle_tech_tree")
	await wait_process_frames(3)
	tree.call(&"_show_tab", 1)
	await wait_process_frames(4)
	var seen: int = 0
	var outside: Array[String] = []
	for node: Node in tree.find_children("*", "TechNode", true, false):
		var card: TechNode = node as TechNode
		if not FOOTPRINT_NODES.has(card.node_id):
			continue
		seen += 1
		assert_eq(card.state, TechNode.State.OWNED, "%s is owned" % card.node_id)
		assert_true((card.get_node("%Footprint") as Control).visible, "%s shows it" % card.node_id)
		var right: float = card.get_global_rect().end.x - SLACK
		for part: Node in card.get_node("Content/Column/Footer").get_children():
			var control: Control = part as Control
			if control.visible and control.get_global_rect().end.x > right:
				outside.append("%s %s" % [card.node_id, control.name])
	assert_eq(seen, FOOTPRINT_NODES.size(), "both cards on the board")
	assert_eq(outside, [] as Array[String], "%s %.0f %%: every footer inside its card" % [locale,
		text_scale * 100.0])


func test_an_owned_card_with_a_footprint_fits_the_phone_in_german() -> void:
	await _owned_cards_fit("de", 1.0)


func test_an_owned_card_with_a_footprint_fits_the_phone_at_large_text() -> void:
	await _owned_cards_fit("de", LARGE_TEXT)


func _statistics_fit(locale: String, text_scale: float = 1.0) -> void:
	ProfileManager.history = [{"n": 12, "architecture": "language_model",
		"difficulty": "hard", "directives": [], "outcome": "lose_contained",
		"variant": "lose_contained", "days": 1170, "seed": 2147483000, "origin": "usa",
		"regions": [1], "controlled": []}] as Array[Dictionary]
	await _launch(WINDOW_PHONE, locale, text_scale)
	ScreenRouter.go_to_title()
	await wait_process_frames(3)
	var title: Node = ScreenRouter.screen_node()
	var button: Control = title.get_node("%StatisticsButton") as Control
	# Taken before it opens: the modal host moves it into its slot.
	var statistics: Control = title.get_node("%Statistics") as Control
	assert_eq(await _click_control(button), "", "the click reached Statistics")
	await wait_process_frames(4)
	assert_true(statistics.is_visible_in_tree(), "%s: Statistics opened" % locale)
	assert_eq(_past(statistics, float(WINDOW_PHONE.x)), [] as Array[String],
		"%s: Statistics fit the phone" % locale)
	assert_eq(_broken_words(statistics), [] as Array[String],
		"%s %.0f %%: no caption squeezed inside a word" % [locale, text_scale * 100.0])


func test_statistics_fit_a_phone_in_english() -> void:
	await _statistics_fit("en")


func test_statistics_fit_a_phone_in_german() -> void:
	await _statistics_fit("de")


func test_statistics_fit_a_phone_in_german_at_large_text() -> void:
	await _statistics_fit("de", LARGE_TEXT)


## A German effect line wrapped at every width: the `%` never starts a line.
func test_a_german_percentage_keeps_its_sign_on_its_line() -> void:
	TranslationServer.set_locale("de")
	var line: String = "Häufigkeit von Anomalien %s, Einnahmen %s" % [Format.change(0.0),
		Format.change(0.5)]
	var font: Font = ThemeDB.fallback_font
	var alone: Array[int] = []
	for width: int in range(WRAP_FROM, WRAP_TO, WRAP_STEP):
		var paragraph: TextParagraph = TextParagraph.new()
		paragraph.add_string(line, font, WRAP_FONT_SIZE)
		paragraph.width = float(width)
		paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND
		for i: int in paragraph.get_line_count():
			var span: Vector2i = paragraph.get_line_range(i)
			if line.substr(span.x, span.y - span.x).strip_edges().begins_with("%"):
				alone.append(width)
	assert_eq(alone, [] as Array[int], "no width puts the sign on a line of its own")


## The prose carries the same space (the German counter-move card, help pages).
func test_no_string_puts_a_breaking_space_before_a_percent_sign() -> void:
	var file: FileAccess = FileAccess.open("res://data/loc/strings.csv", FileAccess.READ)
	var breaking: Array[String] = []
	var pattern: RegEx = RegEx.create_from_string("[0-9}] %")
	# The web shell repeats its strings verbatim in HTML (test_web_shell), and
	# the benchmark's brief is a prompt a recorded run was given word for word.
	var exempt: Array[String] = ["UI_WEB_LOADING", "BENCH_BRIEF_WIN"]
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.is_empty() or exempt.has(row[0]):
			continue
		for cell: String in row:
			if pattern.search(cell) != null:
				breaking.append(row[0])
	assert_eq(breaking, [] as Array[String])
