extends GutTest
## S1.1 — one test per class of broken input in `docs/specs/core.md` §4.2. Each
## asserts the file and the path, because an error that does not say where it is
## costs more time than it saves.

## Suffixes of the four files of a root, as `_expect` matches them.
const BALANCE: String = "balance.json"
const REGIONS: String = "world/regions.json"
const LINKS: String = "world/links.json"
const TECH: String = "tech[0]"
const HEADLINES: String = "headlines.json"


func after_all() -> void:
	Fixtures.remove_root(Fixtures.TEMP_ROOT)


# ------------------------------------------------------------ whole-file shape


func test_a_json_syntax_error_names_the_line() -> void:
	var files: Dictionary[String, String] = Fixtures.root_files(Fixtures.raw_content())
	files["world/links.json"] = "{\n\t\"links\": [\n\t\t{\"a\": ,}\n\t]\n}"
	var result: ContentLoadResult = ContentLoader.load_root(
		Fixtures.write_root("syntax", files))
	_assert_error(result, LINKS, "line 3", "expected value")


func test_a_missing_file_is_one_error() -> void:
	var files: Dictionary[String, String] = Fixtures.root_files(Fixtures.raw_content())
	files.erase("world/links.json")
	var result: ContentLoadResult = ContentLoader.load_root(
		Fixtures.write_root("missing_file", files))
	_assert_error(result, LINKS, "", "file not found")


func test_a_root_without_technology_is_valid() -> void:
	var content: Dictionary = Fixtures.raw_content()
	# An ability comes from a node, so a root with no technology has no
	# abilities either (§9.1) — dropping only the tree would be a root whose
	# abilities point at nothing, which is a different test.
	(content["abilities"] as Dictionary)["abilities"] = []
	var files: Dictionary[String, String] = Fixtures.root_files(content)
	files.erase("tech/fixture.json")
	var result: ContentLoadResult = ContentLoader.load_root(Fixtures.write_root("no_tech", files))
	assert_true(result.ok(), result.error_text())
	assert_eq(result.db.tech_nodes.size(), 0)
	assert_eq(result.db.abilities.size(), 0)


func test_a_top_level_of_any_other_json_type_does_not_crash() -> void:
	for text: String in ["[]", "\"text\"", "5", "true", "null", "[1, 2, 3]"]:
		var files: Dictionary[String, String] = Fixtures.root_files(Fixtures.raw_content())
		files["world/regions.json"] = text
		var result: ContentLoadResult = ContentLoader.load_root(
			Fixtures.write_root("top_level", files))
		assert_false(result.ok(), "%s should be rejected as a regions file" % text)
		assert_null(result.db)


# --------------------------------------------------------------- field reading


func test_a_missing_field_is_reported_with_its_path() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_region(content, 0).erase("population")
	_expect(content, REGIONS, "regions[0].population", "missing required field")


func test_a_wrong_type_names_what_it_found() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_region(content, 0)["population"] = "sixty million"
	_expect(content, REGIONS, "regions[0].population", "expected a number")


func test_a_fractional_value_in_an_integer_field_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_region(content, 1)["index"] = 2.5
	_expect(content, REGIONS, "regions[1].index", "whole number")


func test_a_value_outside_its_range_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	var attributes: Dictionary = _region(content, 0)["attributes"]
	attributes["compute"] = 9
	_expect(content, REGIONS, "regions[0].attributes.compute", "outside")


func test_an_unknown_field_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_region(content, 0)["colour"] = "red"
	_expect(content, REGIONS, "regions[0].colour", "unknown field")


func test_a_comment_field_is_ignored() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_region(content, 0)["_note"] = "the hub"
	var result: ContentLoadResult = Fixtures.load_raw(content)
	assert_true(result.ok(), result.error_text())


func test_a_bad_id_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_region(content, 0)["id"] = "FX_Alder"
	_expect(content, REGIONS, "regions[0].id", "not a valid id")


# ------------------------------------------------------------------ uniqueness


func test_a_duplicate_region_id_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_region(content, 1)["id"] = "fx_alder"
	_expect(content, REGIONS, "regions[1].id", "duplicate id")


func test_a_duplicate_region_index_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_region(content, 1)["index"] = 1
	_expect(content, REGIONS, "regions[1].index", "duplicate index")


func test_a_gap_in_the_indices_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_region(content, 5)["index"] = 7
	_expect(content, REGIONS, "regions", "index 6 is missing")


func test_index_zero_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_region(content, 0)["index"] = 0
	_expect(content, REGIONS, "regions[0].index", "outside")


func test_a_duplicate_link_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	var links: Array = content["links"]["links"]
	links.append({"a": "fx_alder", "b": "fx_birch", "kind": "land"})
	_expect(content, LINKS, "links[7]", "duplicate link")


func test_a_duplicate_tech_id_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_node(content, 1)["id"] = "fx_vector_net"
	_expect(content, TECH, "nodes[1].id", "duplicate id")


# -------------------------------------------------------------- cross-file ids


func test_a_link_to_an_unknown_region_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	var links: Array = content["links"]["links"]
	var link: Dictionary = links[0]
	link["b"] = "fx_ghost"
	_expect(content, LINKS, "links[0].b", "unknown region")


func test_link_endpoints_must_be_sorted() -> void:
	var content: Dictionary = Fixtures.raw_content()
	var links: Array = content["links"]["links"]
	var link: Dictionary = links[0]
	link["a"] = "fx_birch"
	link["b"] = "fx_alder"
	_expect(content, LINKS, "links[0]", "must sort strictly before")


func test_an_unknown_link_kind_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	var links: Array = content["links"]["links"]
	var link: Dictionary = links[0]
	link["kind"] = "tunnel"
	_expect(content, LINKS, "links[0].kind", "unknown link kind")


func test_a_link_is_not_checked_against_regions_that_did_not_parse() -> void:
	var files: Dictionary[String, String] = Fixtures.root_files(Fixtures.raw_content())
	files["world/regions.json"] = "{"
	var result: ContentLoadResult = ContentLoader.load_root(
		Fixtures.write_root("no_regions", files))
	assert_false(result.ok())
	for error: ValidationError in result.errors:
		assert_false(error.message.contains("unknown region"),
			"a regions file that did not parse must not make every link look dangling")


# ------------------------------------------------------------- technology data


func test_an_unknown_tree_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_node(content, 0)["tree"] = "sabotage"
	_expect(content, TECH, "nodes[0].tree", "unknown tree")


func test_an_unknown_flag_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_node(content, 0)["flags"] = ["breakout", "teleport"]
	_expect(content, TECH, "nodes[0].flags[1]", "unknown flag")


func test_an_unknown_target_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_modifier(content, 2, 0)["target"] = "spread_speed"
	_expect(content, TECH, "nodes[2].modifiers[0].target", "unknown target")


func test_an_unknown_operator_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_modifier(content, 2, 0)["op"] = "set"
	_expect(content, TECH, "nodes[2].modifiers[0].op", "unknown operator")


func test_a_multiplier_of_zero_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_modifier(content, 2, 0)["value"] = 0.0
	_expect(content, TECH, "nodes[2].modifiers[0].value", "greater than 0")


func test_a_scope_on_a_global_target_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	var modifier: Dictionary = _modifier(content, 2, 1)
	assert_eq(str(modifier["target"]), "footprint", "the fixture's global modifier")
	modifier["scope"] = {"attr": "compute", "min": 2}
	_expect(content, TECH, "nodes[2].modifiers[1].scope", "global target takes no scope")


func test_a_scope_needs_a_bound() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_modifier(content, 0, 0)["scope"] = {"attr": "connectivity"}
	_expect(content, TECH, "nodes[0].modifiers[0].scope", "needs \"min\", \"max\" or both")


func test_an_unknown_attribute_in_a_scope_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_modifier(content, 0, 0)["scope"] = {"attr": "literacy", "min": 2}
	_expect(content, TECH, "nodes[0].modifiers[0].scope.attr", "unknown attribute")


func test_the_derived_population_attribute_may_be_scoped() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_modifier(content, 0, 0)["scope"] = {"attr": "population", "min": 2}
	var result: ContentLoadResult = Fixtures.load_raw(content)
	assert_true(result.ok(), result.error_text())


func test_an_unknown_region_in_a_scope_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_modifier(content, 0, 0)["scope"] = {"region": "fx_ghost"}
	_expect(content, TECH, "nodes[0].modifiers[0].scope.region", "unknown region")


func test_an_unknown_continent_in_a_scope_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_modifier(content, 0, 0)["scope"] = {"continent": "north"}
	_expect(content, TECH, "nodes[0].modifiers[0].scope.continent", "unknown continent")


func test_a_scope_of_two_forms_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_modifier(content, 0, 0)["scope"] = {"region": "fx_elm", "continent": "east"}
	_expect(content, TECH, "nodes[0].modifiers[0].scope", "exactly one")


func test_a_dangling_prerequisite_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_node(content, 3)["requires"] = ["fx_nothing"]
	_expect(content, TECH, "nodes[3].requires[0]", "unknown node")


func test_a_self_prerequisite_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_node(content, 3)["requires"] = ["fx_bridge"]
	_expect(content, TECH, "nodes[3].requires[0]", "its own prerequisite")


func test_a_prerequisite_cycle_is_reported_once_at_its_first_node() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_node(content, 4)["requires"] = ["fx_grip"]
	_node(content, 5)["requires"] = ["fx_efficiency"]
	var result: ContentLoadResult = Fixtures.load_raw(content)
	_assert_error(result, TECH, "nodes[4]", "prerequisite cycle")
	var cycles: int = 0
	for error: ValidationError in result.errors:
		if error.message.contains("prerequisite cycle"):
			cycles += 1
	assert_eq(cycles, 1, "a cycle is reported once, not once per node")


func test_a_cycle_through_requires_any_is_found() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_node(content, 0)["requires_any"] = ["fx_reach"]
	_expect(content, TECH, "nodes[0]", "prerequisite cycle")


# ----------------------------------------------------------------- balance.json


func test_a_missing_stat_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	var stats: Dictionary = content["balance"]["stats"]
	stats.erase("harm")
	_expect(content, BALANCE, "stats.harm", "missing required field")


func test_an_extra_stat_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	var stats: Dictionary = content["balance"]["stats"]
	stats["morale"] = 1.0
	_expect(content, BALANCE, "stats.morale", "unknown field")


func test_a_table_of_the_wrong_length_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	var compute: Dictionary = content["balance"]["compute"]
	compute["hardware_by_tier"] = [0.0, 1.0, 2.0]
	_expect(content, BALANCE, "compute.hardware_by_tier", "expected 5 entries")


func test_population_tiers_must_ascend() -> void:
	var content: Dictionary = Fixtures.raw_content()
	var balance: Dictionary = content["balance"]
	balance["population_tiers"] = [5000000, 4000000, 80000000, 300000000]
	_expect(content, BALANCE, "population_tiers[1]", "ascend")


func test_containment_thresholds_must_ascend() -> void:
	var content: Dictionary = Fixtures.raw_content()
	var containment: Dictionary = content["balance"]["containment"]
	containment["thresholds"] = [0.5, 0.25]
	_expect(content, BALANCE, "containment.thresholds[1]", "ascend")


func test_an_unknown_milestone_kind_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	var milestones: Array = content["balance"]["milestones"]
	var milestone: Dictionary = milestones[0]
	milestone["kind"] = "regions_lost"
	_expect(content, BALANCE, "milestones[0].kind", "unknown milestone kind")


func test_a_broken_balance_file_does_not_stop_the_other_files() -> void:
	var content: Dictionary = Fixtures.raw_content()
	var balance: Dictionary = content["balance"]
	balance.erase("spread")
	_region(content, 0)["colour"] = "red"
	var result: ContentLoadResult = Fixtures.load_raw(content)
	# A whole section reports once; only a section that is there but incomplete
	# reports field by field.
	_assert_error(result, BALANCE, "spread", "missing required field")
	_assert_error(result, REGIONS, "regions[0].colour", "unknown field")


# ------------------------------------------------------------------ collecting


func test_two_errors_in_one_file_are_both_reported() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_region(content, 0).erase("population")
	_region(content, 2)["continent"] = "West"
	var result: ContentLoadResult = Fixtures.load_raw(content)
	_assert_error(result, REGIONS, "regions[0].population", "missing required field")
	_assert_error(result, REGIONS, "regions[2].continent", "not a valid id")


func test_an_error_prints_file_path_and_message() -> void:
	var error: ValidationError = ValidationError.new("a.json", "regions[0]", "broken")
	assert_eq(str(error), "a.json: regions[0]: broken")


# ------------------------------------------------------------- the node grid


func test_a_missing_grid_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_node(content, 0).erase("grid")
	_expect(content, TECH, "nodes[0].grid", "missing required field")


func test_a_grid_outside_the_tree_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_node(content, 0)["grid"] = [TechNodeDef.GRID_COLUMNS, 0]
	_expect(content, TECH, "nodes[0].grid[0]", "outside")
	content = Fixtures.raw_content()
	_node(content, 0)["grid"] = [0, -1]
	_expect(content, TECH, "nodes[0].grid[1]", "outside")
	content = Fixtures.raw_content()
	_node(content, 0)["grid"] = [0]
	_expect(content, TECH, "nodes[0].grid", "column, row")


func test_two_nodes_of_one_tree_cannot_share_a_cell() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_node(content, 1)["grid"] = _node(content, 0)["grid"]
	_expect(content, TECH, "nodes[1].grid", "fx_vector_net")


func test_the_same_cell_in_another_tree_is_fine() -> void:
	var content: Dictionary = Fixtures.raw_content()
	# fx_efficiency (capabilities) already sits on fx_vector_net's cell.
	assert_true(Fixtures.load_raw(content).ok())


func test_a_node_left_of_its_prerequisite_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	# fx_vector_net moves behind fx_reach, which requires it.
	_node(content, 0)["grid"] = [3, 0]
	_expect(content, TECH, "nodes[2].requires_any[0]", "left of")


# ------------------------------------------------------- watched_by and effects


func test_an_unknown_faction_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_node(content, 0)["watched_by"] = ["the_press"]
	_expect(content, TECH, "nodes[0].watched_by[0]", "unknown faction")


func test_a_faction_watching_twice_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_node(content, 0)["watched_by"] = [Faction.ID_GOVERNMENTS, Faction.ID_GOVERNMENTS]
	_expect(content, TECH, "nodes[0].watched_by[1]", "duplicate faction")


func test_an_unknown_one_shot_effect_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_node(content, 0)["on_purchase"] = [{"effect": "free_lunch", "value": 1.0}]
	_expect(content, TECH, "nodes[0].on_purchase[0].effect", "unknown effect")


func test_an_effect_value_outside_its_range_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_node(content, 0)["on_purchase"] = [
		{"effect": EffectDef.CONTAINMENT_ROLLBACK, "value": 0.0}]
	_expect(content, TECH, "nodes[0].on_purchase[0].value", "outside")
	content = Fixtures.raw_content()
	_node(content, 0)["on_purchase"] = [
		{"effect": EffectDef.HARM_BURST, "value": 1.5}]
	_expect(content, TECH, "nodes[0].on_purchase[0].value", "outside")


# --------------------------------------------------------------- breakout rule


func test_a_tier_one_infiltration_node_must_grant_breakout() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_node(content, 0)["flags"] = []
	_expect(content, TECH, "nodes[0].flags", "must grant")


func test_no_other_tree_may_grant_breakout() -> void:
	var content: Dictionary = Fixtures.raw_content()
	# fx_quiet, the evasion node.
	_node(content, 8)["flags"] = [ModifierDef.FLAG_BREAKOUT]
	_expect(content, TECH, "nodes[8].flags", "only an infiltration node")


# ---------------------------------------------------------------- the strings


## The string check needs a root on disk: the table is read from the CSV, and
## content built in memory carries none.
func _root_with_strings(name: String, rows: PackedStringArray) -> String:
	var files: Dictionary[String, String] = Fixtures.root_files(Fixtures.raw_content())
	var text: String = "keys,en,de\n"
	for row: String in rows:
		text += row + "\n"
	files["loc/strings.csv"] = text
	return Fixtures.write_root(name, files)


func test_a_node_without_its_strings_is_rejected() -> void:
	var result: ContentLoadResult = ContentLoader.load_root(
		_root_with_strings("no_strings", PackedStringArray()))
	_assert_error(result, "tech/fixture.json", "nodes[0].id", "TECH_FX_VECTOR_NET_NAME")


func test_a_node_whose_german_cell_is_empty_is_rejected() -> void:
	var rows: PackedStringArray = []
	for node_id: String in ["fx_vector_net"]:
		for suffix: String in ["NAME", "EFFECT"]:
			rows.append("TECH_%s_%s,text,Text" % [node_id.to_upper(), suffix])
		rows.append("TECH_%s_FLAVOUR,text," % node_id.to_upper())
	var result: ContentLoadResult = ContentLoader.load_root(
		_root_with_strings("empty_german", rows))
	_assert_error(result, "tech/fixture.json", "nodes[0].id", "TECH_FX_VECTOR_NET_FLAVOUR")


func test_a_root_without_a_string_table_skips_the_check() -> void:
	# Every fixture is such a root; the shipped content is the one that is not.
	assert_true(Fixtures.load_raw(Fixtures.raw_content()).ok())


# --------------------------------------------------------------------- helpers


func _region(content: Dictionary, i: int) -> Dictionary:
	var regions: Array = content["regions"]["regions"]
	return regions[i]


func _node(content: Dictionary, i: int) -> Dictionary:
	var tech: Array = content["tech"]
	var file: Dictionary = tech[0]
	var nodes: Array = file["nodes"]
	return nodes[i]


func _modifier(content: Dictionary, node: int, i: int) -> Dictionary:
	var modifiers: Array = _node(content, node)["modifiers"]
	return modifiers[i]


# --------------------------------------------------------------- headlines.json


func test_headlines_reject_unknown_keys_events_and_ids() -> void:
	_break_headline({"when": {"not_a_condition": 3}}, "headlines[0].when.not_a_condition",
		"unknown field")
	_break_headline({"on": {"event": "not_an_event"}}, "headlines[0].on.event",
		"is not an event type")
	_break_headline({"on": {"event": "node_purchased", "data": {"node": "no_such_node"}}},
		"headlines[0].on.data.node", "is not a known node")
	_break_headline({"stream": "filler", "on": {"event": "region_seeded"}}, "headlines[0].on",
		"no event trigger")
	_break_headline({"chance": 0.5, "on": null, "when": {}}, "headlines[0].chance",
		"only an event trigger")
	_break_headline({"when": {"day_min": 40, "day_max": 10}}, "headlines[0].when.day_min",
		"is above")
	_break_headline({"on": {"event": "region_seeded", "region_attr_min": {"aura": 2}}},
		"headlines[0].on.region_attr_min.aura", "unknown field")
	_break_headline({"on": {"event": "discovered", "region_attr_min": {"compute": 2}}},
		"headlines[0].on.region_attr_min", "carries no region")
	_break_headline({"on": {"event": "containment_threshold", "data": {"threshold": 0.4}}},
		"headlines[0].on.data.threshold", "balance.containment.thresholds")


## A headline missing its line in one language is the content's mistake, not the
## interface's — the same check the technology names get.
func test_a_headline_without_a_string_is_reported() -> void:
	var content: Dictionary = Fixtures.raw_content()
	var files: Dictionary[String, String] = Fixtures.root_files(content)
	files["loc/strings.csv"] = "keys,en,de
HEADLINE_H_ORIGIN,An origin,Ein Ursprung
"
	var result: ContentLoadResult = ContentLoader.load_root(
		Fixtures.write_root("headline_strings", files))
	_assert_error(result, HEADLINES, "headlines[1].id", "no string \"HEADLINE_H_SEED_RICH\"")


## The check that the delivered headlines and the delivered strings agree.
func test_shipped_headlines_validate() -> void:
	var result: ContentLoadResult = ContentLoader.load_root("res://data")
	assert_true(result.ok(), result.error_text())
	assert_gt(result.db.headlines.size(), 0, "and there are headlines to say")


## Replaces the fixture headline list with one entry, broken in the given way.
func _break_headline(fields: Dictionary, path: String, fragment: String) -> void:
	var content: Dictionary = Fixtures.raw_content()
	var entry: Dictionary = {"id": "h_broken", "stream": "consequence",
		"on": {"event": "region_seeded"}}
	entry.merge(fields, true)
	# A null stands for "and without this one", which is how the state-only
	# shape is written.
	for key: String in fields:
		if fields[key] == null:
			entry.erase(key)
	var file: Dictionary = content["headlines"]
	file["headlines"] = [entry]
	_expect(content, HEADLINES, path, fragment)


## Loads the broken content and asserts that the expected error is among the ones
## reported, with its file and its path.
func _expect(content: Dictionary, file_suffix: String, path: String, fragment: String) -> void:
	_assert_error(Fixtures.load_raw(content), file_suffix, path, fragment)


func _assert_error(result: ContentLoadResult, file_suffix: String, path: String,
		fragment: String) -> void:
	assert_false(result.ok(), "the content should have been rejected")
	assert_null(result.db, "no database is built while there are errors")
	for error: ValidationError in result.errors:
		if error.file.ends_with(file_suffix) and error.path == path \
				and error.message.to_lower().contains(fragment.to_lower()):
			pass_test("%s: %s: %s" % [file_suffix, path, error.message])
			return
	fail_test("expected an error at %s: %s containing \"%s\", got:\n%s"
		% [file_suffix, path, fragment, result.error_text()])
