extends GutTest
## S4.4 — `factions.json` loaded and validated (opposition.md §4, §12.1). One
## test per rule; each asserts the file and the path.

const FILE: String = "factions.json"


func after_all() -> void:
	Fixtures.remove_root(Fixtures.TEMP_ROOT)


func _factions(content: Dictionary) -> Array:
	return (content["factions"] as Dictionary)["factions"]


func _faction(content: Dictionary, index: int) -> Dictionary:
	return _factions(content)[index]


func _expect(content: Dictionary, path: String, fragment: String) -> void:
	var result: ContentLoadResult = Fixtures.load_raw(content)
	assert_false(result.ok(), "the content should have been rejected")
	for error: ValidationError in result.errors:
		if error.file.ends_with(FILE) and error.path == path \
				and error.message.to_lower().contains(fragment.to_lower()):
			pass_test("%s: %s" % [path, error.message])
			return
	fail_test("expected an error at %s containing \"%s\", got:\n%s"
		% [path, fragment, result.error_text()])


# -------------------------------------------------------------------- loading


func test_the_fixture_loads_four_factions_in_order() -> void:
	var db: ContentDB = Fixtures.db()
	assert_eq(db.factions.size(), 4)
	for i: int in Faction.FACTION_IDS.size():
		assert_eq(db.factions[i].id, Faction.FACTION_IDS[i])
		assert_eq(db.faction(Faction.FACTION_IDS[i]), db.factions[i])
	var governments: FactionDef = db.faction("governments")
	assert_eq(governments.capacity_attr, "regulation")
	assert_eq(governments.brake, "containment_governments")
	assert_eq(governments.terms.size(), 4)
	assert_eq(governments.terms[1].source, "harm")
	assert_almost_eq(governments.terms[1].weight, 0.3, 1e-12)
	assert_eq(governments.moves.size(), 1)
	assert_eq(governments.moves[0].event, "fx_move")
	assert_almost_eq(governments.moves[0].trigger_containment, 0.2, 1e-12)
	assert_eq(governments.moves[0].trigger_risk, FactionMoveDef.NOT_GIVEN)
	assert_eq(governments.move_by_event("fx_move"), governments.moves[0])
	assert_null(db.faction("unified"))


func test_terms_carry_their_tree_and_kind() -> void:
	var db: ContentDB = Fixtures.db()
	assert_eq(db.faction("ai_labs").terms[1].tree, "capabilities")
	assert_eq(db.faction("public_sentiment").terms[2].kind, "fleet")


## The real file, with its variants: every counter-move of the game is some
## faction's move, and the disclosure resolves by link kind.
func test_the_game_content_loads_with_every_move() -> void:
	var result: ContentLoadResult = ContentLoader.load_root("res://data")
	assert_true(result.ok(), result.error_text())
	var researchers: FactionDef = result.db.faction("security_researchers")
	var disclosure: FactionMoveDef = researchers.move_by_event("cm_disclosure_sea")
	assert_not_null(disclosure, "a variant's event finds its move")
	assert_eq(disclosure.variants_select, FactionMoveDef.SELECTOR_SEEDS_BY_KIND_MAX)
	assert_eq(disclosure.variants["land"], "cm_disclosure_land")
	var labs: FactionDef = result.db.faction("ai_labs")
	assert_almost_eq(labs.moves[0].trigger_risk, 0.004, 1e-12)
	assert_almost_eq(labs.moves[0].trigger_containment, 0.2, 1e-12)


func test_the_content_hash_changes_with_a_weight() -> void:
	var content: Dictionary = Fixtures.raw_content()
	var before: String = Fixtures.load_raw(content).db.content_hash
	(_faction(content, 1)["terms"] as Array)[0]["weight"] = 0.2
	assert_ne(Fixtures.load_raw(content).db.content_hash, before)


func test_a_missing_file_is_an_error() -> void:
	var files: Dictionary[String, String] = Fixtures.root_files(Fixtures.raw_content())
	files.erase("factions.json")
	var result: ContentLoadResult = ContentLoader.load_root(
		Fixtures.write_root("no_factions", files))
	assert_false(result.ok())
	assert_string_contains(result.error_text(), "factions.json")


# ----------------------------------------------------------------- validation


func test_a_fifth_faction_is_an_error() -> void:
	var content: Dictionary = Fixtures.raw_content()
	var extra: Dictionary = (_faction(content, 0) as Dictionary).duplicate(true)
	extra["id"] = "the_press"
	extra["moves"] = []
	_factions(content).append(extra)
	_expect(content, "factions", "expected the 4 factions")


func test_factions_out_of_order_are_an_error() -> void:
	var content: Dictionary = Fixtures.raw_content()
	var list: Array = _factions(content)
	var first: Dictionary = list[0]
	list[0] = list[1]
	list[1] = first
	_expect(content, "factions[0].id", "out of order")


func test_an_unknown_capacity_attribute_is_an_error() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_faction(content, 0)["capacity_attr"] = "morale"
	_expect(content, "factions[0].capacity_attr", "unknown attribute")


func test_the_population_tier_is_a_capacity_attribute() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_faction(content, 0)["capacity_attr"] = "population"
	assert_true(Fixtures.load_raw(content).ok())


func test_a_regional_brake_is_an_error() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_faction(content, 0)["brake"] = "spread_growth"
	_expect(content, "factions[0].brake", "not a global target")


func test_a_faction_without_terms_is_an_error() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_faction(content, 2)["terms"] = []
	_expect(content, "factions[2].terms", "at least one term")


func test_an_unknown_source_is_an_error() -> void:
	var content: Dictionary = Fixtures.raw_content()
	(_faction(content, 0)["terms"] as Array)[0]["source"] = "vibes"
	_expect(content, "factions[0].terms[0].source", "unknown source")


func test_owned_nodes_without_a_tree_is_an_error() -> void:
	var content: Dictionary = Fixtures.raw_content()
	((_faction(content, 0)["terms"] as Array)[1] as Dictionary).erase("tree")
	_expect(content, "factions[0].terms[1].tree", "missing required field")


func test_a_tree_on_another_source_is_an_error() -> void:
	var content: Dictionary = Fixtures.raw_content()
	(_faction(content, 0)["terms"] as Array)[0]["tree"] = "capabilities"
	_expect(content, "factions[0].terms[0].tree", "only an owned_nodes term")


func test_an_assets_term_without_a_kind_is_an_error() -> void:
	var content: Dictionary = Fixtures.raw_content()
	((_faction(content, 3)["terms"] as Array)[2] as Dictionary).erase("kind")
	_expect(content, "factions[3].terms[2].kind", "missing required field")


func test_a_negative_weight_is_an_error() -> void:
	var content: Dictionary = Fixtures.raw_content()
	(_faction(content, 0)["terms"] as Array)[0]["weight"] = -0.1
	_expect(content, "factions[0].terms[0].weight", "outside")


func test_a_move_naming_another_factions_event_is_an_error() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_faction(content, 0)["moves"] = [{"event": "fx_move", "trigger": {"containment": 0.2}}]
	_expect(content, "factions[0].moves[0].event", "a move of governments")


func test_a_counter_move_no_faction_names_is_an_error() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_faction(content, 1)["moves"] = []
	_expect(content, "factions", "named by no faction")


func test_a_move_that_is_no_counter_move_is_an_error() -> void:
	var content: Dictionary = Fixtures.raw_content()
	(_faction(content, 1)["moves"] as Array).append(
		{"event": "fx_opening", "trigger": {"containment": 0.4}})
	_expect(content, "factions[1].moves[1].event", "not a counter-move")


func test_a_trigger_needs_containment_or_risk() -> void:
	var content: Dictionary = Fixtures.raw_content()
	(_faction(content, 1)["moves"] as Array)[0]["trigger"] = {}
	_expect(content, "factions[1].moves[0].trigger", "needs containment, risk or both")


func test_a_containment_trigger_must_be_inside_zero_and_one() -> void:
	var content: Dictionary = Fixtures.raw_content()
	(_faction(content, 1)["moves"] as Array)[0]["trigger"] = {"containment": 1.0}
	_expect(content, "factions[1].moves[0].trigger.containment", "outside")


func test_a_variant_key_that_is_not_a_link_kind_is_an_error() -> void:
	var content: Dictionary = Fixtures.raw_content()
	(_faction(content, 1)["moves"] as Array)[0]["variants"] = {
		"select": "seeds_by_kind_max", "events": {"rail": "fx_move"}}
	_expect(content, "factions[1].moves[0].variants.events.rail", "not a link kind")


func test_an_unknown_selector_is_an_error() -> void:
	var content: Dictionary = Fixtures.raw_content()
	(_faction(content, 1)["moves"] as Array)[0]["variants"] = {
		"select": "loudest", "events": {}}
	_expect(content, "factions[1].moves[0].variants.select", "unknown selector")
