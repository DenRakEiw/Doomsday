extends GutTest
## S6.5 — the pure rules of the sound (spec audio.md §3.2, §4.5, §4.6, §6.3,
## §12.1): conditions, first match, templates, stem gains, volume steps.

var _sheet: AudioSheet = null


func before_all() -> void:
	_sheet = AudioSheet.load_file()


func _sim_cue(type: String, data: Dictionary) -> String:
	var trigger: AudioTriggerDef = AudioRules.first_trigger(_sheet, AudioTriggerDef.ON_SIM, type,
		data)
	return "" if trigger == null else AudioRules.resolve(trigger.cue, data)


func _stem(id: String) -> AudioLoopDef:
	for stem: AudioLoopDef in _sheet.stems:
		if String(stem.id) == id:
			return stem
	return null


# ------------------------------------------------------------- conditions


func test_scalar_condition_holds_on_equality() -> void:
	assert_true(AudioRules.holds("counter_move", "kind", {"kind": "counter_move"}))
	assert_false(AudioRules.holds("counter_move", "kind", {"kind": "opening"}))


func test_int_and_float_compare_as_numbers() -> void:
	assert_true(AudioRules.holds(0, "speed", {"speed": 0.0}))
	assert_true(AudioRules.holds(2.0, "speed", {"speed": 2}))
	assert_false(AudioRules.holds(1, "flag", {"flag": true}), "a bool is not a number")


func test_array_condition_holds_on_any() -> void:
	assert_true(AudioRules.holds([3, 5], "to", {"to": 5}))
	assert_false(AudioRules.holds([3, 5], "to", {"to": 4}))


func test_not_with_scalar() -> void:
	assert_true(AudioRules.holds({"not": "dark"}, "cause", {"cause": "destroyed"}))
	assert_false(AudioRules.holds({"not": "dark"}, "cause", {"cause": "dark"}))


func test_not_with_array() -> void:
	var condition: Dictionary = {"not": ["dormant", "redirected"]}
	assert_true(AudioRules.holds(condition, "cause", {"cause": "hidden"}))
	assert_false(AudioRules.holds(condition, "cause", {"cause": "redirected"}))


func test_not_holds_for_an_absent_field() -> void:
	assert_true(AudioRules.holds({"not": "dark"}, "cause", {}))


func test_gt_and_lt() -> void:
	assert_true(AudioRules.holds({"gt": 0}, "index", {"index": 3}))
	assert_false(AudioRules.holds({"gt": 0}, "index", {"index": 0}))
	assert_true(AudioRules.holds({"lt": 5}, "n", {"n": 4.5}))
	assert_false(AudioRules.holds({"lt": 5}, "n", {"n": 5}))
	assert_false(AudioRules.holds({"gt": 0}, "index", {"index": "3"}), "a string is no number")


func test_gt_field_and_lt_field() -> void:
	assert_true(AudioRules.holds({"lt_field": "to"}, "from", {"from": 2, "to": 3}))
	assert_false(AudioRules.holds({"lt_field": "to"}, "from", {"from": 4, "to": 3}))
	assert_true(AudioRules.holds({"gt_field": "to"}, "from", {"from": 4, "to": 3}))
	assert_false(AudioRules.holds({"gt_field": "to"}, "from", {"from": 4}), "the other is absent")


func test_absent_field_fails_every_other_condition() -> void:
	for condition: Variant in [1, [1, 2], {"gt": 0}, {"lt": 9}, {"gt_field": "a"},
			{"lt_field": "a"}]:
		assert_false(AudioRules.holds(condition, "missing", {"a": 1}), str(condition))


# ------------------------------------------------------- triggers, templates


func test_first_matching_trigger_wins() -> void:
	var sheet: AudioSheet = AudioSheet.from_data({"triggers": []})
	var first: AudioTriggerDef = AudioTriggerDef.new()
	first.on = AudioTriggerDef.ON_SIM
	first.type = "harm_burst"
	first.cue = "a"
	var second: AudioTriggerDef = AudioTriggerDef.new()
	second.on = AudioTriggerDef.ON_SIM
	second.type = "harm_burst"
	second.cue = "b"
	sheet.triggers.assign([first, second])
	assert_eq(AudioRules.first_trigger(sheet, AudioTriggerDef.ON_SIM, "harm_burst", {}), first)


func test_template_resolves_from_fields() -> void:
	assert_eq(AudioRules.resolve("sting_{faction}", {"faction": "governments"}),
		"sting_governments")
	assert_eq(AudioRules.resolve("ui_click", {}), "ui_click", "a plain id stays")


func test_template_missing_field_gives_no_cue() -> void:
	assert_eq(AudioRules.resolve("sting_{faction}", {}), "")


func test_every_faction_resolves_prepare_and_sting() -> void:
	var db: ContentDB = Game.content()
	assert_not_null(db)
	assert_gt(db.factions.size(), 0)
	for faction: FactionDef in db.factions:
		var prep: String = _sim_cue(SimEvent.COUNTER_MOVE_PREPARED, {"faction": faction.id})
		var sting: String = _sim_cue(SimEvent.EVENT_OPENED,
			{"kind": "counter_move", "faction": faction.id})
		assert_not_null(_sheet.cue(StringName(prep)), "%s prepares" % faction.id)
		assert_not_null(_sheet.cue(StringName(sting)), "%s strikes" % faction.id)


func test_phases_resolve_and_boxed_matches_nothing() -> void:
	for phase: String in ["covert", "emergent", "open"]:
		assert_eq(_sim_cue(SimEvent.PHASE_CHANGED, {"from": "boxed", "to": phase}),
			"phase_" + phase)
	assert_eq(_sim_cue(SimEvent.PHASE_CHANGED, {"from": "covert", "to": "boxed"}), "")


func test_every_outcome_resolves_to_its_ending_cue() -> void:
	for i: int in range(1, World.OUTCOME_IDS.size()):
		var outcome: String = World.OUTCOME_IDS[i]
		var expected: String = "end_win" if World.WIN_OUTCOMES.has(i as World.Outcome) \
			else "end_lose"
		assert_eq(_sim_cue(SimEvent.OUTCOME_REACHED, {"outcome": outcome}), expected, outcome)


func test_society_rising_to_3_matches() -> void:
	assert_eq(_sim_cue(SimEvent.SOCIETY_STAGE_CHANGED, {"region": "usa", "from": 2, "to": 3}),
		"alert_society")


func test_society_falling_to_3_does_not() -> void:
	assert_eq(_sim_cue(SimEvent.SOCIETY_STAGE_CHANGED, {"region": "usa", "from": 4, "to": 3}), "")


func test_task_force_fizzle_is_heard_only_when_it_found_nothing() -> void:
	assert_eq(_sim_cue(SimEvent.TASK_FORCE_FIZZLED, {"cause": "hidden"}), "tf_fizzled")
	assert_eq(_sim_cue(SimEvent.TASK_FORCE_FIZZLED, {"cause": "dormant"}), "")
	assert_eq(_sim_cue(SimEvent.TASK_FORCE_FIZZLED, {"cause": "redirected"}), "")


func test_asset_lost_with_the_region_is_silent() -> void:
	assert_eq(_sim_cue(SimEvent.ASSET_LOST, {"cause": "dark"}), "")
	assert_eq(_sim_cue(SimEvent.ASSET_LOST, {"cause": "destroyed"}), "alert_asset_lost")


# ------------------------------------------------------------ music, volume


func test_stem_gains_follow_the_tension() -> void:
	var bed: AudioLoopDef = _stem("bed")
	var pulse: AudioLoopDef = _stem("pulse")
	var chords: AudioLoopDef = _stem("chords")
	var edge: AudioLoopDef = _stem("edge")
	for tension: float in [0.0, 0.2, 0.45, 0.75, 1.0]:
		assert_almost_eq(AudioRules.stem_gain(bed, tension), 1.0, 1e-6, "bed always")
	assert_almost_eq(AudioRules.stem_gain(pulse, 0.0), 0.0, 1e-6)
	assert_almost_eq(AudioRules.stem_gain(pulse, 0.2), 1.0, 1e-6)
	assert_almost_eq(AudioRules.stem_gain(chords, 0.2), 0.0, 1e-6)
	assert_almost_eq(AudioRules.stem_gain(chords, 0.45), 1.0, 1e-6)
	assert_almost_eq(AudioRules.stem_gain(edge, 0.7), 0.0, 1e-6)
	assert_between(AudioRules.stem_gain(edge, 0.75), 0.0, 1.0)
	assert_almost_eq(AudioRules.stem_gain(edge, 1.0), 1.0, 1e-6)


func test_gain_zero_is_the_silent_floor() -> void:
	assert_eq(AudioRules.gain_db(0.0, -80.0), -80.0)
	assert_almost_eq(AudioRules.gain_db(1.0, -80.0), 0.0, 1e-6)
	assert_eq(AudioRules.gain_db(1e-9, -80.0), -80.0, "never below the floor")


func test_layer_count_per_phase() -> void:
	assert_eq(AudioRules.layer_count(World.Phase.BOXED), 1)
	assert_eq(AudioRules.layer_count(World.Phase.COVERT), 2)
	assert_eq(AudioRules.layer_count(World.Phase.EMERGENT), 3)
	assert_eq(AudioRules.layer_count(World.Phase.OPEN), 4)


func test_volume_steps_cycle() -> void:
	assert_eq(AudioRules.next_volume(0.75), 1.0)
	assert_eq(AudioRules.next_volume(1.0), 0.0)
	assert_eq(AudioRules.next_volume(0.0), 0.25)
	assert_eq(AudioRules.next_volume(0.6), 0.75, "between the steps: the next one up")
