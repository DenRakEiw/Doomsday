extends GutTest
## S6.5 — a sound caption as the player reads it (spec audio.md §8.3, §12.1).
## The arguments are converted by their names alone.

var _locale: String = ""


func before_each() -> void:
	_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after_each() -> void:
	TranslationServer.set_locale(_locale)


func test_faction_is_its_name() -> void:
	assert_eq(CaptionText.render("UI_CAPTION_MOVE", {"faction": "ai_labs", "kind": "counter_move"}),
		"[%s: counter-move]" % tr("FACTION_AI_LABS"))


func test_phase_comes_from_to() -> void:
	assert_eq(CaptionText.render("UI_CAPTION_PHASE", {"from": "covert", "to": "emergent"}),
		"[Phase shift: %s]" % tr("UI_PHASE_EMERGENT"))


func test_a_society_stage_stays_a_number() -> void:
	var converted: Dictionary = CaptionText.converted({"from": 2, "to": 3})
	assert_false(converted.has("phase"))
	assert_eq(converted["to"], "3")


func test_outcome_is_its_name() -> void:
	assert_eq(CaptionText.render("UI_CAPTION_END", {"outcome": "win_merge"}),
		"[The run ends: %s]" % tr("UI_OUTCOME_WIN_MERGE"))


func test_kind_is_the_asset_name() -> void:
	assert_eq(CaptionText.render("UI_CAPTION_ASSET_LOST", {"kind": "lab", "region": "usa"}),
		"[%s lost]" % tr("ASSET_LAB_NAME"))


func test_region_is_its_name() -> void:
	assert_eq(CaptionText.render("UI_CAPTION_WIPED", {"region": "germany"}),
		"[%s wiped]" % tr("REGION_GERMANY"))


func test_an_unknown_argument_is_its_string() -> void:
	assert_eq(CaptionText.converted({"days": 12})["days"], "12")


func test_german_renders() -> void:
	TranslationServer.set_locale("de")
	assert_eq(CaptionText.render("UI_CAPTION_PHASE", {"from": "covert", "to": "emergent"}),
		"[Phasenwechsel: Entdeckt]")
	assert_eq(CaptionText.render("UI_CAPTION_TF_ACTED", {"region": "germany"}),
		"[Maßnahme der Einsatzgruppe in Deutschland]")
