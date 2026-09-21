extends GutTest
## S1.1 — the fixture root loads into typed definitions, and the content hash
## depends on the values and on nothing else.

var db: ContentDB


func before_each() -> void:
	db = Fixtures.db()


func test_the_fixture_loads_without_errors() -> void:
	var result: ContentLoadResult = ContentLoader.load_root(Fixtures.WORLD_SMALL)
	assert_true(result.ok(), result.error_text())
	assert_not_null(result.db)


func test_the_fixture_has_the_expected_counts() -> void:
	assert_eq(db.regions.size(), Fixtures.REGION_COUNT + 1, "six regions plus the null at index 0")
	assert_eq(db.links.size(), Fixtures.LINK_COUNT)
	assert_eq(db.tech_nodes.size(), Fixtures.TECH_NODE_COUNT)


func test_region_index_zero_is_null() -> void:
	assert_null(db.regions[0], "index 0 is \"no region\" and must stay null")


func test_regions_are_stored_at_their_own_index() -> void:
	for i: int in range(1, db.regions.size()):
		assert_eq(db.regions[i].index, i)
	assert_eq(db.regions[3].id, "fx_cedar")


func test_population_tiers_are_derived_from_balance() -> void:
	var tiers: Array[int] = []
	for i: int in range(1, db.regions.size()):
		tiers.append(db.regions[i].attr(RegionDef.ATTRIBUTE_POPULATION))
	var expected: Array[int] = [2, 2, 3, 2, 0, 1]
	assert_eq(tiers, expected)


func test_an_unknown_attribute_reads_as_tier_zero() -> void:
	assert_eq(db.regions[1].attr("nonsense"), 0)


func test_link_ids_are_derived_from_endpoints_and_kind() -> void:
	assert_eq(db.links[0].id, "fx_alder|fx_birch|land")
	assert_eq(db.links[0].a, 1)
	assert_eq(db.links[0].b, 2)
	assert_eq(db.links[2].kind, LinkDef.KIND_NETWORK, "file order is the simulation's order")


func test_the_air_gapped_region_is_the_only_one_flagged() -> void:
	var flagged: Array[String] = []
	for i: int in range(1, db.regions.size()):
		if db.regions[i].air_gapped:
			flagged.append(db.regions[i].id)
	var expected: Array[String] = ["fx_fir"]
	assert_eq(flagged, expected)


func test_lookups_return_null_for_unknown_ids() -> void:
	assert_null(db.region_by_id("fx_nothing"))
	assert_null(db.tech("fx_nothing"))
	assert_eq(db.region_by_id("fx_elm").index, 5)
	assert_eq(db.tech("fx_reach").cost, 7)


func test_population_total_is_the_sum_of_the_regions() -> void:
	assert_almost_eq(db.population_total, 255000000.0, 1.0)


func test_balance_arrives_as_typed_fields() -> void:
	assert_almost_eq(db.balance.spread_base_growth, 0.04, 1e-9)
	assert_almost_eq(db.balance.spread_seed_chance[LinkDef.KIND_LAND], 0.04, 1e-9)
	assert_eq(db.balance.anomaly_max_active, 5)
	assert_eq(db.balance.history_interval_days, 7)
	assert_eq(db.balance.population_tiers.size(), 4)
	assert_eq(db.balance.milestones.size(), 9)
	assert_eq(db.balance.milestones[0].kind, MilestoneDef.KIND_REGIONS_INFECTED)
	assert_eq(db.balance.stats.size(), ModifierDef.TARGETS_ALL.size(),
		"one base value per modifier target")
	assert_almost_eq(db.balance.stats["airgap_cross"], 0.0, 1e-9)


func test_prerequisites_are_kept_apart() -> void:
	var reach: TechNodeDef = db.tech("fx_reach")
	assert_eq(reach.requires.size(), 0)
	assert_eq(reach.requires_any.size(), 2)
	var harm_2: TechNodeDef = db.tech("fx_harm_2")
	assert_eq(harm_2.requires.size(), 2, "the cross-tree prerequisite of fx_harm_2")
	assert_true(harm_2.requires.has("fx_reach"))


func test_flags_are_loaded() -> void:
	assert_true(db.tech("fx_vector_net").flags.has(ModifierDef.FLAG_BREAKOUT))
	assert_eq(db.tech("fx_reach").flags.size(), 0)


func test_an_attribute_scope_matches_only_matching_regions() -> void:
	var modifier: ModifierDef = db.tech("fx_vector_net").modifiers[0]
	assert_eq(modifier.target, "spread_growth")
	assert_eq(modifier.op, ModifierDef.Op.MUL)
	assert_almost_eq(modifier.value, 1.25, 1e-9)
	assert_eq(modifier.scope_kind, ModifierDef.ScopeKind.ATTR)
	assert_eq(modifier.scope_attr, "connectivity")
	assert_eq(modifier.scope_min, 3)
	assert_eq(modifier.scope_max, RegionDef.TIER_MAX, "an absent max is the top tier")
	assert_true(modifier.matches(db.region_by_id("fx_alder")), "connectivity 4")
	assert_false(modifier.matches(db.region_by_id("fx_cedar")), "connectivity 1")
	assert_false(modifier.matches(null), "a scoped modifier never applies to a global stat")


func test_an_unscoped_modifier_matches_everything() -> void:
	var modifier: ModifierDef = db.tech("fx_reach").modifiers[0]
	assert_eq(modifier.scope_kind, ModifierDef.ScopeKind.NONE)
	assert_true(modifier.matches(null))
	assert_true(modifier.matches(db.region_by_id("fx_fir")))


func test_a_region_scope_matches_by_index() -> void:
	var modifier: ModifierDef = ModifierDef.new()
	modifier.scope_kind = ModifierDef.ScopeKind.REGION
	modifier.scope_region = 5
	assert_true(modifier.matches(db.regions[5]))
	assert_false(modifier.matches(db.regions[4]))
	assert_false(modifier.matches(null))


func test_a_continent_scope_matches_by_continent() -> void:
	var modifier: ModifierDef = ModifierDef.new()
	modifier.scope_kind = ModifierDef.ScopeKind.CONTINENT
	modifier.scope_continent = "east"
	assert_true(modifier.matches(db.region_by_id("fx_dogwood")))
	assert_false(modifier.matches(db.region_by_id("fx_alder")))
	assert_false(modifier.matches(null))


func test_an_authored_region_scope_is_resolved_to_an_index() -> void:
	var content: Dictionary = Fixtures.raw_content()
	var tech: Array = content["tech"]
	var file: Dictionary = tech[0]
	var nodes: Array = file["nodes"]
	var node: Dictionary = nodes[4]
	node["modifiers"] = [{"target": "yield", "op": "mul", "value": 2.0,
		"scope": {"region": "fx_elm"}}]
	var result: ContentLoadResult = Fixtures.load_raw(content)
	assert_true(result.ok(), result.error_text())
	var modifier: ModifierDef = result.db.tech(str(node["id"])).modifiers[0]
	assert_eq(modifier.scope_kind, ModifierDef.ScopeKind.REGION)
	assert_eq(modifier.scope_region, 5, "fx_elm is region 5")


func test_the_content_hash_is_stable_across_loads() -> void:
	var first: ContentLoadResult = ContentLoader.load_root(Fixtures.WORLD_SMALL)
	var second: ContentLoadResult = ContentLoader.load_root(Fixtures.WORLD_SMALL)
	assert_eq(first.db.content_hash, second.db.content_hash)
	assert_eq(first.db.content_hash.length(), 64, "SHA-256 as hex")


func test_the_content_hash_ignores_key_order() -> void:
	var content: Dictionary = Fixtures.raw_content()
	var flipped: Dictionary = _reverse_keys(content)
	var plain: ContentLoadResult = Fixtures.load_raw(content)
	var reordered: ContentLoadResult = Fixtures.load_raw(flipped)
	assert_true(reordered.ok(), reordered.error_text())
	assert_eq(reordered.db.content_hash, plain.db.content_hash)


func test_the_content_hash_ignores_whitespace() -> void:
	var content: Dictionary = Fixtures.raw_content()
	var tabs: String = ContentLoader.load_root(
		Fixtures.write_root("hash_tabs", Fixtures.root_files(content, "\t"))).db.content_hash
	var spaces: String = ContentLoader.load_root(
		Fixtures.write_root("hash_spaces", Fixtures.root_files(content, "    "))).db.content_hash
	assert_eq(tabs, spaces)
	assert_eq(tabs, db.content_hash, "and it is the hash of the fixture itself")


func test_the_content_hash_changes_with_a_value() -> void:
	var content: Dictionary = Fixtures.raw_content()
	var regions: Array = content["regions"]["regions"]
	var first: Dictionary = regions[0]
	first["population"] = 61000000
	var changed: ContentLoadResult = Fixtures.load_raw(content)
	assert_true(changed.ok(), changed.error_text())
	assert_ne(changed.db.content_hash, db.content_hash)


func test_loading_from_dictionaries_equals_loading_from_disk() -> void:
	var result: ContentLoadResult = Fixtures.load_raw(Fixtures.raw_content())
	assert_true(result.ok(), result.error_text())
	assert_eq(result.db.content_hash, db.content_hash)
	assert_eq(result.db.regions.size(), db.regions.size())


func test_the_project_content_loads() -> void:
	if not FileAccess.file_exists("res://data/world/regions.json"):
		pass_test("skipped: data/world/ is generated by the map pipeline in S1.7")
		return
	var result: ContentLoadResult = ContentLoader.load_root("res://data")
	assert_true(result.ok(), result.error_text())


## The same content with every object's keys in the opposite order. Array order
## carries meaning and is left alone.
func _reverse_keys(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		var source: Dictionary = value
		var out: Dictionary = {}
		var keys: Array = source.keys()
		keys.reverse()
		for key: Variant in keys:
			out[key] = _reverse_keys(source[key])
		return out
	if typeof(value) == TYPE_ARRAY:
		var source: Array = value
		var out: Array = []
		for entry: Variant in source:
			out.append(_reverse_keys(entry))
		return out
	return value
