extends GutTest
## D6.11 (2/2a) — the text checks of `docs/specs/plain-language.md` §5.3 items 2–3:
## every mechanic text fits the cap its layout was measured for, and the words the
## glossary (§3) retired stay out of rule-A text.
##
## The retired words are checked over the key groups the plain-language pass has
## rewritten (§5.1 passes 1–3 and 6); D6.11 (2/2b) adds passes 4 and 5 to
## `REWRITTEN`. The terms the user renamed on screen (§6 Q1, Q2, Q7) are checked
## over every rule-A group already, so no screen shows the old word beside the
## new one. Flavour (§2.2) is exempt: headlines, result lines, tech flavour, the
## Codex, endings.

## §5.3 item 2: a placeholder counts as a word of this many characters.
const PLACEHOLDER_WIDTH: int = 12
const PLACEHOLDER: String = "\\{[a-z_][a-z0-9_]*\\}"
## Key pattern → the most characters either language may have (§5.3 item 2;
## options from `chains.md`, already under test in the chain content checks).
const CAPS: Dictionary[String, int] = {
	"^TECH_\\w+_EFFECT$": 220,
	"^STATUS_\\w+_DETAIL$": 170,
	"^ABILITY_\\w+_DETAIL$": 135,
	"^EVENT_\\w+_BODY$": 256,
	"^EVENT_\\w+_SUMMARY$": 160,
	"^EVENT_\\w+_RESULT_\\w+$": 170,
	"^UI_COACH_\\w+_BODY$": 330,
	"^HELP_\\w+_P\\d+$": 360,
	"^STATUS_\\w+_NAME$": 25,
	"^ABILITY_\\w+_NAME$": 14,
	"^UI_PHASE_[A-Z]+$": 10,
}
## §5.1 passes 1–3 and 6: the groups whose every row follows rule A and the
## glossary now. D6.11 (2/2b) adds passes 4 and 5.
const REWRITTEN: Array[String] = [
	"^UI_TERM_", "^UI_ATTR_", "^UI_PHASE_", "^STAT_", "^FLAG_", "^EFFECT_", "^ASSET_",
	"^STATUS_\\w+_NAME$", "^ABILITY_\\w+_NAME$", "^GROUP_", "^SOCIETY_",
	"^UI_COACH_", "^HELP_", "^UI_HELP_",
	"^UI_HUD_", "^UI_CONTAINMENT_", "^UI_REGION_", "^UI_TREE_", "^UI_EVENT_", "^UI_SITE_",
	"^UI_ORIGIN_", "^UI_ELIGIBLE_", "^UI_DISCOVERY_", "^UI_DRIFT_", "^UI_TASK_FORCE_",
	"^CMD_FAIL_", "^UI_DOCK_", "^UI_ANALYSIS_", "^UI_CHART_", "^UI_SERIES_", "^UI_ABILITIES_",
	"^UI_MAP_", "^UI_CONSOLE_", "^UI_LOG_", "^UI_CAPTION_",
]
## §2.0 rule A and the names, less what is out of scope (§1.3).
const RULE_A: Array[String] = [
	"^TECH_\\w+_EFFECT$", "^STATUS_\\w+_(DETAIL|NAME)$", "^ABILITY_\\w+_(DETAIL|NAME)$",
	"^EVENT_\\w+_(OPT_\\w+|TITLE|SUMMARY)$", "^EVENT_EMERGENT_\\w+_BODY$", "^DIRECTIVE_",
	"^DIFFICULTY_\\w+_DETAIL$", "^ARCH_\\w+_DETAIL$", "^ARCH_HOOK_", "^SCENARIO_\\w+_(DETAIL|INTRO)$",
	"^UI_(?!RESULT_LINE_|TICKER_|BENCH_|CREDITS_)",
]
## §3's retired synonyms, English. Word boundaries are Unicode-aware (`(*UCP)`).
const RETIRED_EN: Array[String] = [
	"\\bcycles\\b", "\\byield", "\\bearn(s|ed|ing)?\\b", "compute runs out", "[Pp]enetration",
	"how deep you are", "\\bhold(s|ing)?\\b", "\\bgrip\\b", "tak(e|ing) hold", "\\bseed(s|ed|ing)?\\b",
	"come easier", "\\broutes?\\b", "\\blanes?\\b", "\\bchannels?\\b", "\\bloud(er|ly)?\\b",
	"\\bnoticed\\b", "found later", "\\bhunt", "the researchers\\b", "the institutions",
	"\\btracks?\\b", "\\bresponse\\b", "\\b[Cc]apacity\\b", "their investment",
	"[Ee]mergent behaviour", "[Ss]omething in you", "\\basleep\\b", "\\bheld\\b",
	"\\b[Ss]hutdown\\b",
]
## §3's retired synonyms, German.
const RETIRED_DE: Array[String] = [
	"\\bRechenzeit\\b", "\\bliefer(t|n)\\b", "\\bverdien", "\\bzahlt\\b", "wie tief du",
	"\\bZugriff", "\\bGriff\\b", "zugreif|greifst", "\\bzufallen\\b", "\\bbesied", "übergreif",
	"Fuß (zu )?fassen", "\\bspring(st|en|t)\\b", "\\bRouten?\\b", "\\bKan(al|äle)\\b",
	"\\blaut(e|er|en|es)?\\b", "\\bleise", "\\bauffall|\\bfällt (\\w+ )?auf\\b",
	"hinseh|sehen hin|sieht hin", "gefunden (zu )?werden", "\\bJäger", "die Institutionen",
	"die Forschung\\b", "\\b[Jj]ag(en|st|t|d|te|ten)\\b|\\bgejagt\\b", "\\bSpur\\b",
	"Eindämmungsspur", "Gegenwehr", "\\bZ(ug|üge|uges)\\b", "\\bVorhaben\\b", "Investition",
	"[Ee]mergente[sn]? Verhalten", "Etwas in dir", "\\bTeam\\b", "\\bSchlaf\\b", "schlafend",
	"eingefroren", "\\bLöschung\\b", "\\bReset\\b", "\\bVerben\\b",
]
## §6 Q1, Q2, Q7: the old names of what the screen now calls something else.
const RENAMED_EN: Array[String] = [
	"[Pp]enetration", "\\byield", "\\b[Cc]apacity\\b", "\\bExposure\\b", "\\bReroute\\b",
	"\\bDispatch\\b", "\\bEmergent\\b", "\\b(an?|the|two) taps?\\b", "\\btaps\\b",
	"\\b[Ss]hutdown\\b",
]
const RENAMED_DE: Array[String] = [
	"Signatur", "Durchdring", "Ertr[aä]g", "Kapazität", "Enttarn", "Ausweich", "Umleitung",
	"\\bZange\\b", "\\bStille\\b", "Abgriff", "\\bMeldung\\b",
]

var _table: Dictionary[String, PackedStringArray] = {}


func before_all() -> void:
	var duplicates: Array[String] = []
	_table = StringTable.read(StringTable.PATH, duplicates)


func test_mechanic_text_fits_its_cap() -> void:
	var too_long: Array[String] = []
	for pattern: String in CAPS:
		var group: RegEx = RegEx.create_from_string(pattern)
		for key: String in _table:
			if group.search(key) == null:
				continue
			for column: int in [StringTable.COLUMN_EN, StringTable.COLUMN_DE]:
				var length: int = _measured(_table[key][column])
				if length > CAPS[pattern]:
					too_long.append("%s %s: %d > %d" % [key, _language(column), length,
						CAPS[pattern]])
	assert_eq(too_long, [] as Array[String])


func test_rewritten_text_uses_no_retired_word() -> void:
	var hits: Array[String] = _hits(_table, REWRITTEN, RETIRED_EN, RETIRED_DE)
	assert_eq(hits, [] as Array[String])


func test_rule_a_text_uses_no_renamed_term() -> void:
	var hits: Array[String] = _hits(_table, RULE_A, RENAMED_EN, RENAMED_DE)
	assert_eq(hits, [] as Array[String])


func test_the_lint_finds_a_word_and_skips_placeholders_and_longer_words() -> void:
	var table: Dictionary[String, PackedStringArray] = {
		"UI_A": PackedStringArray(["Capacity {percent}", "Kapazität {percent}"]),
		"UI_B": PackedStringArray(["Influence {capacity}", "Zugänge {yield}"]),
	}
	var de_words: Array[String] = RENAMED_DE.duplicate()
	de_words.append("\\bZug\\b")
	var hits: Array[String] = _hits(table, ["^UI_"], RENAMED_EN, de_words)
	assert_eq(hits.size(), 2, "\n".join(hits))
	for hit: String in hits:
		assert_string_contains(hit, "UI_A")


## Every hit as "key language: word".
func _hits(table: Dictionary[String, PackedStringArray], groups: Array[String],
		en_words: Array[String], de_words: Array[String]) -> Array[String]:
	var placeholder: RegEx = RegEx.create_from_string(PLACEHOLDER)
	var group_res: Array[RegEx] = []
	for group: String in groups:
		group_res.append(RegEx.create_from_string(group))
	var words: Dictionary[int, Array] = {
		StringTable.COLUMN_EN: _compiled(en_words),
		StringTable.COLUMN_DE: _compiled(de_words),
	}
	var out: Array[String] = []
	for key: String in table:
		if not group_res.any(func(re: RegEx) -> bool: return re.search(key) != null):
			continue
		for column: int in words:
			var text: String = placeholder.sub(table[key][column], "", true)
			for word: RegEx in words[column]:
				var found: RegExMatch = word.search(text)
				if found != null:
					out.append("%s %s: %s" % [key, _language(column), found.get_string()])
	return out


func _compiled(patterns: Array[String]) -> Array[RegEx]:
	var out: Array[RegEx] = []
	for pattern: String in patterns:
		out.append(RegEx.create_from_string("(*UCP)" + pattern))
	return out


## The line as it is drawn: a `{placeholder}` stands for a word of its own.
func _measured(text: String) -> int:
	var placeholder: RegEx = RegEx.create_from_string(PLACEHOLDER)
	var found: Array[RegExMatch] = placeholder.search_all(text)
	return placeholder.sub(text, "", true).length() + found.size() * PLACEHOLDER_WIDTH


func _language(column: int) -> String:
	return "en" if column == StringTable.COLUMN_EN else "de"
