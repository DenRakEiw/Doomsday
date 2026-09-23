extends GutTest
## S4.2 — what `statuses.json` and `abilities.json` are allowed to say
## (`docs/specs/loop-mechanics.md` §15.5, §15.6).
##
## Every case breaks exactly one field of the fixture and checks that the loader
## reports that field and nothing else silently passes.

const STATUSES: String = "memory/statuses.json"
const ABILITIES: String = "memory/abilities.json"


## The fixture content with one status entry replaced.
func _with_status(index: int, entry: Dictionary) -> ContentLoadResult:
	var content: Dictionary = Fixtures.raw_content()
	((content["statuses"] as Dictionary)["statuses"] as Array)[index] = entry
	return Fixtures.load_raw(content)


func _with_ability(index: int, entry: Dictionary) -> ContentLoadResult:
	var content: Dictionary = Fixtures.raw_content()
	((content["abilities"] as Dictionary)["abilities"] as Array)[index] = entry
	return Fixtures.load_raw(content)


func _status(index: int = 0) -> Dictionary:
	return ((Fixtures.raw_content()["statuses"] as Dictionary)["statuses"] as Array)[index]


func _ability(index: int = 0) -> Dictionary:
	return ((Fixtures.raw_content()["abilities"] as Dictionary)["abilities"] as Array)[index]


func _assert_error(result: ContentLoadResult, needle: String) -> void:
	assert_false(result.ok(), "this content should be rejected")
	assert_string_contains(result.error_text(), needle)


# ------------------------------------------------------------------ statuses


func test_the_fixture_content_loads_cleanly() -> void:
	assert_true(Fixtures.load_raw(Fixtures.raw_content()).ok())


func test_an_unknown_origin_is_rejected() -> void:
	var entry: Dictionary = _status()
	entry["origin"] = "nobody"
	_assert_error(_with_status(0, entry), "unknown origin")


func test_a_status_needs_at_least_one_level() -> void:
	var entry: Dictionary = _status()
	entry["levels"] = []
	_assert_error(_with_status(0, entry), "at least one level")


## §7.3: the scope is injected when the status is applied, so one in the file
## would be a second, silent scope.
func test_a_scoped_modifier_on_a_status_is_rejected() -> void:
	var entry: Dictionary = _status()
	((entry["levels"] as Array)[0] as Dictionary)["modifiers"] = [
		{"target": "yield", "op": "mul", "value": 0.5, "scope": {"attr": "compute", "min": 2}}]
	_assert_error(_with_status(0, entry), "scoped to its region")


## §7.1: a `mul 0` is what "no capacity at all" means, and the clamp's floor is 0.
func test_a_mul_of_zero_is_allowed_on_a_status() -> void:
	var entry: Dictionary = _status()
	((entry["levels"] as Array)[0] as Dictionary)["modifiers"] = [
		{"target": "yield", "op": "mul", "value": 0.0}]
	assert_true(_with_status(0, entry).ok())


func test_an_unknown_link_kind_is_rejected() -> void:
	var entry: Dictionary = _status()
	((entry["levels"] as Array)[0] as Dictionary)["closes_links"] = ["tunnel"]
	_assert_error(_with_status(0, entry), "unknown link kind")


func test_all_is_the_whole_list_or_none_of_it() -> void:
	var entry: Dictionary = _status()
	((entry["levels"] as Array)[0] as Dictionary)["closes_links"] = ["all", "sea"]
	_assert_error(_with_status(0, entry), "the whole list")


func test_ends_statuses_must_name_a_status_that_exists() -> void:
	var entry: Dictionary = _status()
	((entry["levels"] as Array)[0] as Dictionary)["ends_statuses"] = ["fx_nothing"]
	_assert_error(_with_status(0, entry), "unknown status")


func test_an_effect_naming_a_status_that_does_not_exist_is_rejected() -> void:
	var entry: Dictionary = _status()
	((entry["levels"] as Array)[0] as Dictionary)["on_start"] = [
		{"effect": "apply_status", "status": "fx_nothing"}]
	_assert_error(_with_status(0, entry), "unknown status")


func test_a_duplicate_status_id_is_rejected() -> void:
	var entry: Dictionary = _status(1)
	entry["id"] = "fx_dim"
	_assert_error(_with_status(1, entry), "duplicate id")


func test_an_unknown_key_on_a_status_is_rejected() -> void:
	var entry: Dictionary = _status()
	entry["colour"] = "red"
	_assert_error(_with_status(0, entry), "colour")


# ----------------------------------------------------------------- abilities


func test_an_unknown_target_is_rejected() -> void:
	var entry: Dictionary = _ability()
	entry["target"] = "everywhere"
	_assert_error(_with_ability(0, entry), "unknown target")


## §9.1: `applies` says exactly one thing.
func test_applies_with_two_keys_is_rejected() -> void:
	var entry: Dictionary = _ability()
	entry["applies"] = {"status": "fx_dim", "effects": []}
	_assert_error(_with_ability(0, entry), "exactly one")


func test_applies_with_no_key_is_rejected() -> void:
	var entry: Dictionary = _ability()
	entry["applies"] = {}
	_assert_error(_with_ability(0, entry), "exactly one")


func test_an_ability_applying_a_status_that_does_not_exist_is_rejected() -> void:
	var entry: Dictionary = _ability()
	entry["applies"] = {"status": "fx_nothing"}
	_assert_error(_with_ability(0, entry), "unknown status")


## §9.1: the status must reach as far as the ability does.
func test_a_status_with_fewer_levels_than_the_ability_is_rejected() -> void:
	var entry: Dictionary = _ability()
	entry["applies"] = {"status": "fx_reaped"}
	_assert_error(_with_ability(0, entry), "reaches level 2")


func test_a_level_cap_lets_a_two_node_ability_apply_a_one_level_status() -> void:
	var entry: Dictionary = _ability()
	entry["applies"] = {"status": "fx_reaped"}
	entry["level_cap"] = 1
	assert_true(_with_ability(0, entry).ok(), _with_ability(0, entry).error_text())


## §9.1: both directions, so the data cannot lie about where a level came from.
func test_a_node_that_does_not_name_the_ability_back_is_rejected() -> void:
	var entry: Dictionary = _ability()
	entry["levels_from"] = ["fx_grip", "fx_zap_2"]
	_assert_error(_with_ability(0, entry), "does not grant an ability")


func test_a_node_that_names_another_level_back_is_rejected() -> void:
	var entry: Dictionary = _ability()
	entry["levels_from"] = ["fx_zap_2"]
	_assert_error(_with_ability(0, entry), "level 1")


func test_an_unknown_node_in_levels_from_is_rejected() -> void:
	var entry: Dictionary = _ability()
	entry["levels_from"] = ["fx_nowhere"]
	_assert_error(_with_ability(0, entry), "unknown node")


func test_an_ability_without_a_node_is_rejected() -> void:
	var entry: Dictionary = _ability()
	entry["levels_from"] = []
	_assert_error(_with_ability(0, entry), "at least one node")


## §9.2: the level of a node whose predecessor is not required could never be
## reached, because the level counts the *leading* owned nodes.
func test_a_second_level_that_does_not_require_the_first_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	for node: Variant in ((content["tech"] as Array)[0] as Dictionary)["nodes"]:
		if str((node as Dictionary).get("id", "")) == "fx_zap_2":
			(node as Dictionary).erase("requires")
	var result: ContentLoadResult = Fixtures.load_raw(content)
	_assert_error(result, "could never be reached")


func test_a_global_ability_with_an_eligibility_rule_is_rejected() -> void:
	var entry: Dictionary = _ability(3)
	entry["eligible"] = {"infected": true}
	_assert_error(_with_ability(3, entry), "targets no region")


func test_a_global_ability_cannot_deploy() -> void:
	var entry: Dictionary = _ability(3)
	entry["applies"] = {"deploy": {"kind": "fleet", "count": 1}}
	_assert_error(_with_ability(3, entry), "nowhere to place")


func test_a_deploy_of_an_unknown_kind_is_rejected() -> void:
	var entry: Dictionary = _ability(2)
	entry["applies"] = {"deploy": {"kind": "satellite", "count": 1}}
	_assert_error(_with_ability(2, entry), "unknown asset kind")


func test_an_eligibility_rule_naming_an_unknown_status_is_rejected() -> void:
	var entry: Dictionary = _ability()
	entry["eligible"] = {"status_absent": ["fx_nothing"]}
	_assert_error(_with_ability(0, entry), "unknown status")


func test_a_duplicate_ability_id_is_rejected() -> void:
	var entry: Dictionary = _ability(1)
	entry["id"] = "fx_zap"
	_assert_error(_with_ability(1, entry), "duplicate id")
