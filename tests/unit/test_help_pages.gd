extends GutTest
## S6.7 — `data/help.json` and `HelpPages` (first-run.md §6.5): the shipped file
## covers every coach card and every surface exactly once and has its text in
## both languages; each validation rule holds on a fixture.
##
## `HelpPages` caches one read, so every fixture test reloads the shipped file
## afterwards — the rest of the suite reads the real pages.

const COACH: GDScript = preload("res://ui/hud/coach.gd")
const FIXTURE: String = "user://test_help_pages.json"
const LOCALES: Array[String] = ["en", "de"]


func after_each() -> void:
	if FileAccess.file_exists(FIXTURE):
		DirAccess.remove_absolute(FIXTURE)
	HelpPages.load_file()


## Writes `pages` as a help file with `version` and loads it.
func _load(pages: Array, version: int = HelpPages.VERSION) -> bool:
	var file: FileAccess = FileAccess.open(FIXTURE, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": version, "pages": pages}))
	file.close()
	return HelpPages.load_file(FIXTURE)


func _page(id: String, paragraphs: int = 1, coach: Array = [], contexts: Array = []) -> Dictionary:
	return {"id": id, "paragraphs": paragraphs, "coach": coach, "contexts": contexts}


func _coach_ids() -> Array[String]:
	var constants: Dictionary = COACH.get_script_constant_map()
	var out: Array[String] = []
	out.assign(constants["STEPS"])
	out.append_array(constants["HINTS"] as Array[String])
	return out


func test_the_shipped_file_loads_without_errors() -> void:
	assert_true(HelpPages.load_file(), "; ".join(HelpPages.errors()))
	assert_eq(HelpPages.ids().size(), 14, "first-run.md §6.5's fourteen pages")


func test_every_coach_card_is_on_exactly_one_page() -> void:
	for step: String in _coach_ids():
		assert_ne(HelpPages.page_for_step(step), "", "no page for %s" % step)
	var named: Dictionary[String, int] = {}
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HelpPages.PATH))
	for page: Dictionary in raw["pages"]:
		for step: Variant in page.get("coach", []):
			named[str(step)] = int(named.get(str(step), 0)) + 1
	for step: String in _coach_ids():
		assert_eq(int(named.get(step, 0)), 1, step)


func test_every_context_is_on_exactly_one_page() -> void:
	for context: String in HelpPages.CONTEXTS:
		assert_ne(HelpPages.page_for_context(context), "", context)


func test_every_title_and_paragraph_has_text_in_both_languages() -> void:
	for locale: String in LOCALES:
		var table: Translation = TranslationServer.get_translation_object(locale)
		for id: String in HelpPages.ids():
			var keys: Array[String] = [HelpPages.title_key(id)]
			for n: int in range(1, HelpPages.paragraphs(id) + 1):
				keys.append(HelpPages.paragraph_key(id, n))
			for key: String in keys:
				assert_ne(String(table.get_message(StringName(key))), "",
					"%s has no %s text" % [key, locale])


func test_a_wrong_version_is_an_error() -> void:
	assert_false(_load([_page("goal")], 2))
	assert_eq(HelpPages.ids().size(), 0, "a bad file lists nothing")


func test_a_page_id_twice_is_an_error() -> void:
	assert_false(_load([_page("goal"), _page("goal")]))


func test_no_paragraphs_is_an_error() -> void:
	assert_false(_load([_page("goal", 0)]))


func test_seven_paragraphs_is_an_error() -> void:
	assert_false(_load([_page("goal", 7)]))


func test_an_unknown_context_is_an_error() -> void:
	assert_false(_load([_page("goal", 1, [], ["kitchen"])]))


func test_a_context_on_two_pages_is_an_error() -> void:
	assert_false(_load([_page("goal", 1, [], ["session"]), _page("time", 1, [], ["session"])]))


func test_a_coach_card_on_two_pages_is_an_error() -> void:
	assert_false(_load([_page("goal", 1, ["done"]), _page("time", 1, ["done"])]))


func test_a_good_fixture_answers_its_lookups() -> void:
	assert_true(_load([_page("goal", 2, ["done"], ["session"]), _page("time", 1)]),
		"; ".join(HelpPages.errors()))
	assert_eq(HelpPages.ids(), ["goal", "time"] as Array[String])
	assert_eq(HelpPages.paragraphs("goal"), 2)
	assert_eq(HelpPages.page_for_step("done"), "goal")
	assert_eq(HelpPages.page_for_context("session"), "goal")
	assert_eq(HelpPages.page_for_step("compute"), "", "a card no page names")
	assert_eq(HelpPages.title_key("goal"), "HELP_GOAL_TITLE")
	assert_eq(HelpPages.paragraph_key("goal", 2), "HELP_GOAL_P2")
