extends GutTest
## S4.3 — `EventDef`, `EventOptionDef` and what the loader made of `events/*.json`
## (`docs/specs/loop-mechanics.md` §10.1, §10.2, §15.7).

const EVENTS: String = "events[0]"
const HEADLINES: String = "headlines.json"

var db: ContentDB


func before_each() -> void:
	db = Fixtures.db()


# ------------------------------------------------------------------- loading


func test_the_fixture_events_all_load_in_file_order() -> void:
	assert_eq(db.events.size(), Fixtures.EVENT_COUNT)
	assert_eq(db.events[0].id, Fixtures.OPENING_EVENT)
	assert_eq(db.events[3].id, Fixtures.CHAIN_STEP)


func test_an_unknown_event_is_null_rather_than_a_crash() -> void:
	assert_null(db.event("fx_nothing"))


func test_an_opening_carries_its_pick_draw_and_deadline() -> void:
	var def: EventDef = db.event(Fixtures.OPENING_EVENT)
	assert_eq(def.kind, EventDef.KIND_OPENING)
	assert_not_null(def.pick)
	assert_true(def.pick.infected)
	assert_true(def.pick.not_dormant)
	assert_eq(def.max_fires, 3)
	assert_eq(def.cooldown_days, 2)
	assert_eq(def.deadline_days, 4)
	assert_eq(def.default_option, "pass")
	assert_almost_eq(float(def.when["regions_min"]), 2.0, 1e-9)
	assert_true(def.is_rolled())
	assert_false(def.is_global())


func test_an_option_carries_its_cost_effects_rolls_and_requirements() -> void:
	var def: EventDef = db.event(Fixtures.OPENING_EVENT)
	var seed: EventOptionDef = def.option("seed")
	assert_almost_eq(seed.cost, 1.0, 1e-9)
	assert_eq(seed.effects.size(), 1)
	assert_eq(seed.chance.size(), 1)
	assert_almost_eq(seed.chance[0].p, 0.5, 1e-9)
	assert_false(seed.chance[0].has_next)
	var locked: EventOptionDef = def.option("locked")
	assert_eq(locked.requires_owned, ["fx_reach"] as Array[String])
	assert_true(locked.has_requirements())
	assert_false(def.option("pass").has_requirements())


func test_a_counter_move_carries_its_status_and_faction() -> void:
	var def: EventDef = db.event(Fixtures.COUNTER_EVENT)
	assert_eq(def.kind, EventDef.KIND_COUNTER_MOVE)
	assert_eq(def.status, Fixtures.WORLD_STATUS)
	assert_eq(def.faction, Faction.ID_GOVERNMENTS)
	assert_false(def.is_rolled(), "a counter-move comes from the schedule, never the roll")
	assert_true(def.option("lobby").skip_status)
	assert_eq(def.option("ride").status_level, 0, "0 applies the event's own level (S4.5)")
	assert_eq(def.option("resist").requires_ability, Fixtures.ZAP_ABILITY)


func test_a_chain_step_happens_once_unless_told_otherwise() -> void:
	var start: EventDef = db.event(Fixtures.CHAIN_START)
	var step: EventDef = db.event(Fixtures.CHAIN_STEP)
	assert_eq(start.max_fires, 1)
	assert_true(start.start)
	assert_true(start.is_rolled())
	assert_true(step.pick_same)
	assert_false(step.is_rolled())
	assert_true(step.modal)
	assert_eq(step.illustration, "fx_pic")
	var go: EventOptionDef = start.option("go")
	assert_eq(go.flags, [Fixtures.CHAIN_FLAG] as Array[String])
	assert_eq(go.next.size(), 1)
	assert_eq(str(go.next[0]["step"]), Fixtures.CHAIN_STEP)
	assert_eq(int(go.next[0]["delay_days"]), 3)


func test_the_string_keys_follow_the_pattern() -> void:
	assert_eq(EventDef.title_key("fx_opening"), "EVENT_FX_OPENING_TITLE")
	assert_eq(EventDef.body_key("fx_opening"), "EVENT_FX_OPENING_BODY")
	assert_eq(EventOptionDef.text_key("fx_opening", "grab"), "EVENT_FX_OPENING_OPT_GRAB")
	assert_eq(EventOptionDef.result_key("fx_opening", "grab"), "EVENT_FX_OPENING_RESULT_GRAB")
	assert_eq(EventDef.kind_key(EventDef.KIND_COUNTER_MOVE), "UI_EVENT_KIND_COUNTER_MOVE")


func test_the_shipped_events_load_with_every_file() -> void:
	var result: ContentLoadResult = ContentLoader.load_root("res://data")
	assert_true(result.ok(), result.error_text())
	assert_not_null(result.db.event("opening_unattended_cluster"))
	assert_not_null(result.db.event("cm_lockdown"))


# --------------------------------------------------------------- directories


func test_every_events_file_is_read_in_name_order() -> void:
	var content: Dictionary = Fixtures.raw_content()
	var fixture: Dictionary = (content["events"] as Array)[0]
	var list: Array = fixture["events"]
	var first: Dictionary = {"version": 1, "events": [list[1]]}
	var second: Dictionary = {"version": 1, "events": [list[0], list[2], list[3]]}
	content["events"] = []
	# Only the governments' counter-move is in these two files (S4.5's are not).
	Fixtures.drop_moves(content, [Faction.ID_GOVERNMENTS] as Array[String])
	var files: Dictionary[String, String] = Fixtures.root_files(content)
	files.erase("events/.keep")
	files["events/b_rest.json"] = JSON.stringify(second, "\t", true, true)
	files["events/a_move.json"] = JSON.stringify(first, "\t", true, true)
	var result: ContentLoadResult = ContentLoader.load_root(Fixtures.write_root("events_order",
		files))
	assert_true(result.ok(), result.error_text())
	assert_eq(result.db.events[0].id, Fixtures.COUNTER_EVENT, "a_move.json comes first")
	assert_eq(result.db.events[1].id, Fixtures.OPENING_EVENT)


func test_an_empty_events_directory_loads() -> void:
	var content: Dictionary = Fixtures.raw_content()
	content["events"] = []
	# The factions' moves name the fixture's counter-moves, which are gone too.
	Fixtures.drop_moves(content)
	var result: ContentLoadResult = ContentLoader.load_root(Fixtures.write_root("events_empty",
		Fixtures.root_files(content)))
	assert_true(result.ok(), result.error_text())
	assert_eq(result.db.events.size(), 0)


func test_a_root_without_an_events_directory_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	content["events"] = []
	var files: Dictionary[String, String] = Fixtures.root_files(content)
	files.erase("events/.keep")
	var result: ContentLoadResult = ContentLoader.load_root(Fixtures.write_root("events_none",
		files))
	assert_false(result.ok())
	assert_string_contains(result.error_text(), "directory not found")


# -------------------------------------------------------------- validation


func test_a_default_with_a_cost_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_option(content, 0, "pass")["cost"] = 1
	_expect(content, "events[0].default", "must be free")


func test_a_default_with_requirements_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_option(content, 0, "pass")["requires"] = {"owned": ["fx_reach"]}
	_expect(content, "events[0].default", "always be open")


func test_five_options_are_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	var options: Array = _event(content, 0)["options"]
	options.append({"id": "extra", "cost": 0})
	_expect(content, "events[0].options", "2 to 4 options")


func test_next_on_an_opening_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_option(content, 0, "grab")["next"] = [{"step": Fixtures.CHAIN_STEP, "delay_days": 1}]
	_expect(content, "events[0].options[0].next", "only a chain step")


func test_next_inside_a_roll_on_an_opening_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	var roll: Dictionary = (_option(content, 0, "seed")["chance"] as Array)[0]
	roll["next"] = []
	_expect(content, "events[0].options[1].chance[0].next", "only a chain step")


func test_a_chain_step_nobody_reaches_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_option(content, 2, "go").erase("next")
	_expect(content, "events[3].id", "neither the start")


func test_two_starting_steps_are_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	var step: Dictionary = _event(content, 3)
	step["start"] = true
	step["pick"] = {"infected": true}
	_expect(content, "events[2].chain", "2 starting steps")


func test_next_into_another_kind_of_event_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_option(content, 2, "go")["next"] = [{"step": Fixtures.OPENING_EVENT, "delay_days": 1}]
	_expect(content, "events[2].options[0].next[0].step", "not a step of the chain")


func test_pick_same_on_an_opening_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_event(content, 0)["pick"] = "same"
	_expect(content, "events[0].pick", "only a chain step after the first")


func test_a_named_rule_outside_a_counter_move_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_event(content, 0)["pick"] = {"rule": "lockdown_target"}
	_expect(content, "events[0].pick", "only a counter-move")


func test_an_unknown_named_rule_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_event(content, 1)["pick"] = {"rule": "fx_nowhere"}
	_expect(content, "events[1].pick.rule", "is not one of")


func test_an_unknown_when_key_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	(_event(content, 0)["when"] as Dictionary)["fx_mood_min"] = 1
	_expect(content, "events[0].when.fx_mood_min", "unknown field")


func test_a_when_may_read_a_story_flag() -> void:
	var content: Dictionary = Fixtures.raw_content()
	(_event(content, 0)["when"] as Dictionary)["flag"] = [Fixtures.CHAIN_FLAG]
	(_event(content, 0)["when"] as Dictionary)["story_flag"] = [Fixtures.CHAIN_FLAG]
	var result: ContentLoadResult = Fixtures.load_raw(content)
	assert_true(result.ok(), result.error_text())


func test_status_level_on_an_opening_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_option(content, 0, "grab")["status_level"] = 1
	_expect(content, "events[0].options[0].status_level", "only a counter-move")


func test_a_counter_move_without_a_faction_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_event(content, 1).erase("faction")
	_expect(content, "events[1].faction", "missing required field")


func test_a_counter_move_applying_a_player_status_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_event(content, 1)["status"] = Fixtures.ZAP_STATUS
	_expect(content, "events[1].status", "the player's")


func test_a_status_on_an_opening_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_event(content, 0)["status"] = Fixtures.WORLD_STATUS
	_expect(content, "events[0].status", "only a counter-move")


func test_an_asset_requirement_on_a_global_event_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_event(content, 0).erase("pick")
	_option(content, 0, "locked")["requires"] = {"asset_min": {"fleet": 1}}
	_expect(content, "events[0].options[3].requires.asset_min", "no region")


func test_a_requirement_naming_an_unknown_node_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_option(content, 0, "locked")["requires"] = {"not_owned": ["fx_nothing"]}
	_expect(content, "events[0].options[3].requires.not_owned[0]", "unknown node")


func test_a_requirement_naming_an_unknown_ability_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_option(content, 1, "resist")["requires"] = {"ability": "fx_nothing"}
	_expect(content, "events[1].options[1].requires.ability", "unknown ability")


func test_a_region_effect_on_a_global_event_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_event(content, 0).erase("pick")
	_expect(content, "events[0].options[1].effects[0].effect", "needs a region")


func test_a_roll_outside_zero_and_one_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	((_option(content, 0, "seed")["chance"] as Array)[0] as Dictionary)["p"] = 0
	_expect(content, "events[0].options[1].chance[0].p", "outside")


func test_an_event_id_is_unique_across_files() -> void:
	var content: Dictionary = Fixtures.raw_content()
	var copy: Dictionary = ((content["events"] as Array)[0] as Dictionary).duplicate(true)
	(content["events"] as Array).append(copy)
	_assert_error(Fixtures.load_raw(content), "events[1]", "events[0].id", "duplicate event id")


# ---------------------------------------------------------------- headlines


func test_a_headline_may_filter_on_an_event_and_its_option() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_headline(content, {"event": SimEvent.EVENT_ANSWERED,
		"data": {"def": Fixtures.OPENING_EVENT, "option": "grab"}})
	var result: ContentLoadResult = Fixtures.load_raw(content)
	assert_true(result.ok(), result.error_text())


func test_a_headline_naming_an_unknown_event_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_headline(content, {"event": SimEvent.EVENT_OPENED, "data": {"def": "fx_nothing"}})
	_assert_error(Fixtures.load_raw(content), HEADLINES, "headlines[0].on.data.def",
		"not a known def")


func test_a_headline_option_without_its_event_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_headline(content, {"event": SimEvent.EVENT_ANSWERED, "data": {"option": "grab"}})
	_assert_error(Fixtures.load_raw(content), HEADLINES, "headlines[0].on.data.option",
		"needs a \"def\"")


func test_a_headline_option_of_another_event_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_headline(content, {"event": SimEvent.EVENT_ANSWERED,
		"data": {"def": Fixtures.OPENING_EVENT, "option": "ride"}})
	_assert_error(Fixtures.load_raw(content), HEADLINES, "headlines[0].on.data.option",
		"not an option of")


# ------------------------------------------------------------------- helpers


func _event(content: Dictionary, index: int) -> Dictionary:
	var file: Dictionary = (content["events"] as Array)[0]
	return (file["events"] as Array)[index]


func _option(content: Dictionary, index: int, option_id: String) -> Dictionary:
	for option: Variant in _event(content, index)["options"]:
		if str((option as Dictionary)["id"]) == option_id:
			return option
	fail_test("no option %s on event %d" % [option_id, index])
	return {}


func _headline(content: Dictionary, on: Dictionary) -> void:
	var file: Dictionary = content["headlines"]
	file["headlines"] = [{"id": "fx_event_line", "stream": "consequence", "on": on}]


func _expect(content: Dictionary, path: String, fragment: String) -> void:
	_assert_error(Fixtures.load_raw(content), EVENTS, path, fragment)


func _assert_error(result: ContentLoadResult, file_suffix: String, path: String,
		fragment: String) -> void:
	assert_false(result.ok(), "the content should have been rejected")
	for error: ValidationError in result.errors:
		if error.file.ends_with(file_suffix) and error.path == path \
				and error.message.to_lower().contains(fragment.to_lower()):
			pass_test("%s: %s: %s" % [file_suffix, path, error.message])
			return
	fail_test("expected an error at %s: %s containing \"%s\", got:\n%s"
		% [file_suffix, path, fragment, result.error_text()])
