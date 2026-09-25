extends GutTest
## S4.8 — the run log as words (analysis.md §8).

var _locale: String = ""
var _db: ContentDB = null


func before_all() -> void:
	var result: ContentLoadResult = ContentLoader.load_root("res://data")
	assert_true(result.ok(), result.error_text())
	_db = result.db


func before_each() -> void:
	_locale = TranslationServer.get_locale()


func after_each() -> void:
	TranslationServer.set_locale(_locale)


## One entry per kept type, with data a real run would give it.
func _entries() -> Array[RunLogEntry]:
	var data: Dictionary[String, Dictionary] = {
		"origin_chosen": {"region": "usa"},
		"node_purchased": {"node": "edge_caching"},
		"region_controlled": {"region": "usa"},
		"region_depopulated": {"region": "usa"},
		"discovered": {"cause": "scrutiny"},
		"containment_threshold": {"faction": "governments", "threshold": 0.25},
		"phase_changed": {"from": "boxed", "to": "covert"},
		"outcome_reached": {"outcome": "lose_autophagy"},
		"containment_rolled_back": {"faction": "ai_labs"},
		"harm_burst": {"deaths": 1500000.0},
		"dormancy_changed": {"region": "usa", "dormant": true},
		"asset_deployed": {"region": "usa", "kind": "fleet", "count": 2},
		"asset_lost": {"region": "usa", "kind": "lab", "count": 1},
		"ability_used": {"ability": "blackout", "region": "usa", "level": 1},
		"status_started": {"status": "lockdown", "region": "usa", "source": "faction:governments"},
		"event_opened": {"def": "cm_lockdown", "kind": "counter_move", "region": "usa",
			"faction": "governments"},
		"event_answered": {"def": "cm_lockdown", "option": "ride", "region": "usa"},
		"event_expired": {"def": "cm_lockdown", "option": "ride", "region": "usa"},
		"counter_move_prepared": {"faction": "governments", "event": "cm_lockdown"},
		"counter_move_cancelled": {"faction": "governments"},
		"funding_reset": {},
		"threat_leader_changed": {"to": "public_sentiment"},
		"society_stage_changed": {"region": "usa", "to": 3},
		"region_wiped": {"region": "usa", "from": 0.8, "to": 0.2},
		"task_force_appeared": {"region": "usa"},
		"task_force_acted": {"region": "usa", "action": "grid_down"},
		"task_force_fizzled": {"region": "usa", "cause": "dormant"},
		"task_force_misdirected": {"region": "usa"},
		"task_force_marked": {"region": "usa", "days": 40},
	}
	var out: Array[RunLogEntry] = []
	for type: String in RunLog.KEPT:
		out.append(RunLogEntry.create(10, type, data[type]))
	return out


func test_every_type_reads_as_a_line_in_both_languages() -> void:
	for locale: String in ["en", "de"]:
		TranslationServer.set_locale(locale)
		for entry: RunLogEntry in _entries():
			var line: String = RunLogText.text(entry, _db)
			assert_false(line.is_empty(), "%s (%s)" % [entry.type, locale])
			assert_false(line.contains("{"), "%s (%s): %s" % [entry.type, locale, line])
			assert_false(line.begins_with("UI_LOG_"), "%s (%s) has a string" % [entry.type, locale])


func test_the_class_column_is_the_specs() -> void:
	for entry: RunLogEntry in _entries():
		assert_eq(RunLogText.is_yours(entry), RunLogText.YOURS.has(entry.type), entry.type)
	assert_true(RunLogText.is_yours(RunLogEntry.create(1, "node_purchased", {})))
	assert_false(RunLogText.is_yours(RunLogEntry.create(1, "discovered", {})))


func test_five_kinds_of_entry_are_marks_and_nothing_else() -> void:
	var marked: Array[String] = []
	for entry: RunLogEntry in _entries():
		if not RunLogText.marker(entry).is_empty():
			marked.append(entry.type)
	assert_eq(marked.size(), 3, "outcome, discovery and an event opening: %s" % str(marked))
	var chain: RunLogEntry = RunLogEntry.create(1, "event_opened", {"kind": "chain"})
	var opening: RunLogEntry = RunLogEntry.create(1, "event_opened", {"kind": "opening"})
	assert_eq(int(RunLogText.marker(chain)["priority"]), RunLogText.PRIORITY_CHAIN)
	assert_eq(int(RunLogText.marker(opening)["priority"]), RunLogText.PRIORITY_OPENING)


## replayability.md §3.1 (G5 1/3): an emergent card is a spark, at the chain's
## priority, in the agent's own accent.
func test_an_emergent_card_is_a_spark_mark_at_the_chains_priority() -> void:
	var emergent: RunLogEntry = RunLogEntry.create(1, "event_opened", {"kind": "emergent"})
	var mark: Dictionary = RunLogText.marker(emergent)
	assert_eq(mark["glyph"], Glyphs.Glyph.EVENT_EMERGENT)
	assert_eq(mark["token"], &"ACCENT")
	assert_eq(int(mark["priority"]), RunLogText.PRIORITY_CHAIN)


func test_the_emergent_kind_has_its_own_glyph() -> void:
	assert_eq(Glyphs.event_glyph(EventDef.KIND_EMERGENT), Glyphs.Glyph.EVENT_EMERGENT)
	assert_eq(Glyphs.event_glyph(EventDef.KIND_OPENING), Glyphs.Glyph.EVENT_OPENING,
		"the opening keeps its diamond")


## analysis.md §8 (G5 1/3): given a verdict, the outcome row reads both.
func test_the_outcome_row_with_a_verdict_reads_outcome_and_verdict() -> void:
	TranslationServer.set_locale("en")
	var entry: RunLogEntry = RunLogEntry.create(1, "outcome_reached",
		{"outcome": "lose_contained"})
	var plain: String = RunLogText.text(entry, _db)
	var line: String = RunLogText.text(entry, _db, "They closed the lid.")
	assert_eq(line, tr("UI_LOG_OUTCOME_VERDICT").format({"outcome": plain,
		"verdict": "They closed the lid."}))
	var other: RunLogEntry = RunLogEntry.create(1, "discovered", {"cause": "scrutiny"})
	assert_eq(RunLogText.text(other, _db, "ignored"), RunLogText.text(other, _db),
		"only the outcome row takes it")


func test_an_id_the_content_lost_renders_as_itself() -> void:
	var entry: RunLogEntry = RunLogEntry.create(1, "node_purchased", {"node": "time_machine"})
	assert_string_contains(RunLogText.text(entry, _db), "time_machine")


func test_every_key_exists_in_both_languages() -> void:
	var table: Dictionary[String, PackedStringArray] = {}
	var file: FileAccess = FileAccess.open("res://data/loc/strings.csv", FileAccess.READ)
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() >= 3:
			table[row[0]] = row
	var panel: GDScript = load("res://ui/panels/analysis_panel.gd")
	var keys: Array = RunLogText.KEYS.duplicate()
	keys.append_array(panel.get_script_constant_map()["KEYS"])
	for key: Variant in keys:
		assert_true(table.has(str(key)), str(key))
		if table.has(str(key)):
			assert_false(table[str(key)][1].is_empty() or table[str(key)][2].is_empty(), str(key))
