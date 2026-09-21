extends GutTest
## S1.1 — one test per class of broken input in `docs/specs/core.md` §4.2. Each
## asserts the file and the path, because an error that does not say where it is
## costs more time than it saves.

## Suffixes of the four files of a root, as `_expect` matches them.
const BALANCE: String = "balance.json"
const REGIONS: String = "world/regions.json"
const LINKS: String = "world/links.json"
const TECH: String = "tech[0]"


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
	var files: Dictionary[String, String] = Fixtures.root_files(Fixtures.raw_content())
	files.erase("tech/fixture.json")
	var result: ContentLoadResult = ContentLoader.load_root(Fixtures.write_root("no_tech", files))
	assert_true(result.ok(), result.error_text())
	assert_eq(result.db.tech_nodes.size(), 0)


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
