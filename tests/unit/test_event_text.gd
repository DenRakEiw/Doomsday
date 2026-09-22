extends GutTest
## The event → ticker line mapping of spec ui-foundation.md §8.4.
##
## The point of the table is that a content id never reaches the player: a
## region, a phase and an outcome all arrive as ids and must leave as words, in
## the language that is set.

var _locale: String = ""


func before_each() -> void:
	_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after_each() -> void:
	TranslationServer.set_locale(_locale)


func _event(type: String, data: Dictionary) -> SimEvent:
	return SimEvent.new(type, 12, data)


func test_a_region_id_is_shown_as_its_name() -> void:
	var line: String = EventText.for_event(_event(SimEvent.REGION_SEEDED, {"region": "usa"}))
	assert_eq(line, "Presence established in United States")


func test_the_same_event_is_german_in_german() -> void:
	TranslationServer.set_locale("de")
	var line: String = EventText.for_event(_event(SimEvent.REGION_SEEDED, {"region": "usa"}))
	assert_eq(line, "Präsenz in Vereinigte Staaten aufgebaut")


func test_an_unlisted_event_type_says_nothing() -> void:
	assert_eq(EventText.for_event(_event("not_an_event", {})), "",
		"an event nobody wrote a line for produces no line")


func test_a_null_event_says_nothing() -> void:
	assert_eq(EventText.for_event(null), "")


func test_a_phase_change_names_the_phase_it_reached() -> void:
	var line: String = EventText.for_event(_event(SimEvent.PHASE_CHANGED, {
		"from": "boxed", "to": "covert"}))
	assert_eq(line, "Phase: Covert")


func test_an_outcome_is_named_not_numbered() -> void:
	var line: String = EventText.for_event(_event(SimEvent.OUTCOME_REACHED, {
		"outcome": "win_ascendance"}))
	assert_eq(line, "Run over: Ascendance")


func test_a_containment_threshold_reads_as_a_percentage() -> void:
	var line: String = EventText.for_event(_event(SimEvent.CONTAINMENT_THRESHOLD, {
		"faction": "unified", "threshold": 0.25}))
	assert_eq(line, "Containment at 25%")


func test_compute_values_go_through_the_formatter() -> void:
	TranslationServer.set_locale("de")
	var line: String = EventText.for_event(_event(SimEvent.ANOMALY_COLLECTED, {
		"anomaly": 1, "region": "japan", "value": 12.34}))
	assert_string_contains(line, "12,3")


func test_every_event_type_of_the_core_has_a_line() -> void:
	# The vocabulary is core.md §6.4; §8.4 says an unlisted type is silent, and
	# in M2 there is no type that should be.
	var script: GDScript = SimEvent
	for name: String in script.get_script_constant_map():
		if name.begins_with("CAUSE_"):
			continue
		var value: Variant = script.get_script_constant_map()[name]
		if typeof(value) != TYPE_STRING:
			continue
		assert_true(EventText.KEYS.has(str(value)), "no ticker line for '%s'" % value)
