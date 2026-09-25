extends GutTest
## S6.3 — the credits and licences modal on the title (`docs/specs/icons.md`
## §11.1, §11.2): what ships is listed with its licence page, what does not is
## not, and `Escape` steps back before it closes.

const CREDITS: PackedScene = preload("res://ui/modals/credits.tscn")
const TITLE: PackedScene = preload("res://ui/screens/title.tscn")
const Credits: GDScript = preload("res://ui/modals/credits.gd")


func _credits() -> Credits:
	var credits: Credits = CREDITS.instantiate() as Credits
	add_child_autofree(credits)
	credits.open()
	return credits


func test_title_has_credits_after_settings_before_quit() -> void:
	var title: Control = TITLE.instantiate() as Control
	add_child_autofree(title)
	var credits: ConsoleButton = title.get_node("%CreditsButton") as ConsoleButton
	var settings: Control = title.get_node("%SettingsButton") as Control
	var quit: Control = title.get_node("%QuitButton") as Control
	assert_eq(credits.label_key, "UI_TITLE_CREDITS")
	assert_eq(credits.get_index(), settings.get_index() + 1)
	assert_eq(quit.get_index(), credits.get_index() + 1)
	# Taken before it opens: the host moves an open modal into its own slot.
	var modal: Control = title.get_node("%Credits") as Control
	credits.pressed.emit()
	assert_true(modal.visible, "the modal opens")
	assert_eq(modal.get(&"licence_id"), "", "on the credits page")


func test_shipped_entries_are_listed_and_missing_ones_are_not() -> void:
	var ids: Array[String] = _credits().listed_ids()
	for id: String in ["godot", "jetbrains_mono", "space_grotesk", "natural_earth"]:
		assert_has(ids, id)
	if not FileAccess.file_exists("res://assets/icons/phosphor/LICENSE.txt"):
		assert_does_not_have(ids, "phosphor", "the icon sets are credited once they ship")


func test_an_entry_without_a_licence_text_has_no_button() -> void:
	var credits: Credits = _credits()
	assert_not_null(credits.licence_button("godot"))
	assert_null(credits.licence_button("natural_earth"))


func test_licence_button_is_named_for_screen_readers() -> void:
	var button: ConsoleButton = _credits().licence_button("space_grotesk")
	assert_eq(button.accessibility_name,
		tr("UI_CREDITS_A11Y_LICENCE").format({"name": "Space Grotesk"}))


func test_engine_page_lists_the_engine_components() -> void:
	var credits: Credits = _credits()
	credits.licence_button("godot").pressed.emit()
	assert_eq(credits.licence_id, "godot")
	var texts: Array[String] = credits.licence_texts()
	assert_eq(texts[0], tr("UI_CREDITS_ENGINE_NOTICE"))
	assert_eq(texts[1], Engine.get_license_text())
	assert_has(texts, tr("UI_CREDITS_ENGINE_COMPONENTS"))
	var components: int = Engine.get_copyright_info().size()
	var licences: int = Engine.get_license_info().size()
	assert_eq(texts.size(), 3 + components + licences, "one block per component and licence")
	var first: Dictionary = Engine.get_copyright_info()[0]
	assert_string_contains(texts[3], str(first["name"]))


func test_file_page_shows_the_file() -> void:
	var credits: Credits = _credits()
	credits.show_licence("jetbrains_mono")
	var text: String = FileAccess.get_file_as_string("res://assets/fonts/OFL-JetBrainsMono.txt")
	assert_eq(credits.licence_texts(), [text.strip_edges()] as Array[String])


func test_escape_on_a_licence_goes_back_then_closes() -> void:
	var credits: Credits = _credits()
	watch_signals(credits)
	credits.show_licence("space_grotesk")
	credits.on_escape()
	assert_eq(credits.licence_id, "", "back on the credits page")
	assert_signal_not_emitted(credits, "closed")
	credits.on_escape()
	assert_signal_emitted(credits, "closed")


func test_made_by_is_hidden_while_empty() -> void:
	var credits: Credits = _credits()
	var headings: Array[String] = []
	for label: Node in credits.find_children("*", "Label", true, false):
		headings.append((label as Label).text)
	assert_does_not_have(headings, tr("UI_CREDITS_SECTION_MADE_BY"))
	assert_has(headings, tr("UI_CREDITS_SECTION_FONTS"))
	assert_does_not_have(headings, tr("UI_CREDITS_SECTION_AUDIO"), "an empty section is hidden")
