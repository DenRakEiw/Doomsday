extends GutTest
## S1.4 — `(base + Σ add) × Π mul`, clamped. Everything the game gives the
## player is expressed through this, so it is worth pinning down exactly.

const TARGET: String = "spread_growth"

var db: ContentDB


func before_each() -> void:
	db = Fixtures.db()


func _stack() -> ModifierStack:
	return ModifierStack.new(db.balance.stats)


func _modifier(target: String, op: ModifierDef.Op, value: float) -> ModifierDef:
	var modifier: ModifierDef = ModifierDef.new()
	modifier.target = target
	modifier.op = op
	modifier.value = value
	return modifier


func _scoped(target: String, op: ModifierDef.Op, value: float, attribute: String,
		low: int) -> ModifierDef:
	var modifier: ModifierDef = _modifier(target, op, value)
	modifier.scope_kind = ModifierDef.ScopeKind.ATTR
	modifier.scope_attr = attribute
	modifier.scope_min = low
	modifier.scope_max = RegionDef.TIER_MAX
	return modifier


func _add(stack: ModifierStack, source: String, modifiers: Array[ModifierDef]) -> void:
	var no_flags: Array[String] = []
	stack.add_source(source, modifiers, no_flags)


func test_an_empty_stack_is_the_base() -> void:
	assert_eq(_stack().value(TARGET), 1.0)
	assert_eq(_stack().value("harm"), 0.0)


func test_adds_are_summed_and_multipliers_multiply() -> void:
	var stack: ModifierStack = _stack()
	_add(stack, "a", [_modifier("harm", ModifierDef.Op.ADD, 1.0),
		_modifier("harm", ModifierDef.Op.ADD, 3.0)])
	_add(stack, "b", [_modifier("harm", ModifierDef.Op.MUL, 2.0)])
	# (0 + 1 + 3) × 2
	assert_eq(stack.value("harm"), 8.0)


func test_the_order_of_the_sources_does_not_change_the_result() -> void:
	var first: ModifierStack = _stack()
	_add(first, "a", [_modifier("harm", ModifierDef.Op.ADD, 2.0)])
	_add(first, "b", [_modifier("harm", ModifierDef.Op.MUL, 1.5)])
	var second: ModifierStack = _stack()
	_add(second, "b", [_modifier("harm", ModifierDef.Op.MUL, 1.5)])
	_add(second, "a", [_modifier("harm", ModifierDef.Op.ADD, 2.0)])
	assert_eq(first.value("harm"), second.value("harm"))


func test_values_are_clamped_at_both_ends() -> void:
	var low: ModifierStack = _stack()
	_add(low, "a", [_modifier("node_cost", ModifierDef.Op.MUL, 0.001)])
	assert_eq(low.value("node_cost"), 0.1, "the lower clamp of node_cost")

	var high: ModifierStack = _stack()
	_add(high, "a", [_modifier("harm", ModifierDef.Op.ADD, 500.0)])
	assert_eq(high.value("harm"), 100.0, "the upper clamp of harm")


func test_a_scoped_modifier_only_reaches_matching_regions() -> void:
	var stack: ModifierStack = _stack()
	_add(stack, "a", [_scoped(TARGET, ModifierDef.Op.MUL, 2.0, "connectivity", 3)])
	assert_eq(stack.value(TARGET, db.region_by_id("fx_alder")), 2.0, "connectivity 4")
	assert_eq(stack.value(TARGET, db.region_by_id("fx_cedar")), 1.0, "connectivity 1")
	assert_eq(stack.value(TARGET, null), 1.0, "and never a stat that belongs to no region")


func test_an_unscoped_modifier_reaches_the_global_stat_too() -> void:
	var stack: ModifierStack = _stack()
	_add(stack, "a", [_modifier(TARGET, ModifierDef.Op.MUL, 2.0)])
	assert_eq(stack.value(TARGET, null), 2.0)
	assert_eq(stack.value(TARGET, db.region_by_id("fx_cedar")), 2.0)


func test_removing_a_source_restores_the_value_exactly() -> void:
	var stack: ModifierStack = _stack()
	_add(stack, "a", [_modifier("harm", ModifierDef.Op.ADD, 1.7)])
	var before: float = stack.value("harm")
	_add(stack, "b", [_modifier("harm", ModifierDef.Op.MUL, 3.3)])
	assert_ne(stack.value("harm"), before)
	stack.remove_source("b")
	assert_eq(stack.value("harm"), before)
	stack.remove_source("not_there")
	assert_eq(stack.value("harm"), before, "removing what is not there is not an error")


func test_adding_a_source_again_replaces_it() -> void:
	var stack: ModifierStack = _stack()
	_add(stack, "a", [_modifier("harm", ModifierDef.Op.ADD, 1.0)])
	_add(stack, "a", [_modifier("harm", ModifierDef.Op.ADD, 5.0)])
	assert_eq(stack.value("harm"), 5.0, "replaced, not stacked")
	assert_eq(stack.sources().size(), 1)


func test_flags_come_and_go_with_their_source() -> void:
	var stack: ModifierStack = _stack()
	assert_false(stack.has_flag(ModifierDef.FLAG_BREAKOUT))
	var none: Array[ModifierDef] = []
	var flags: Array[String] = [ModifierDef.FLAG_BREAKOUT]
	stack.add_source("a", none, flags)
	assert_true(stack.has_flag(ModifierDef.FLAG_BREAKOUT))
	stack.remove_source("a")
	assert_false(stack.has_flag(ModifierDef.FLAG_BREAKOUT))


func test_clearing_drops_everything() -> void:
	var stack: ModifierStack = _stack()
	_add(stack, "a", [_modifier("harm", ModifierDef.Op.ADD, 4.0)])
	stack.clear()
	assert_eq(stack.value("harm"), 0.0)
	assert_eq(stack.sources().size(), 0)


func test_an_unknown_target_is_a_programming_error() -> void:
	# Content is validated against the same vocabulary at load, so this can only
	# be a mistake in code.
	var stack: ModifierStack = _stack()
	assert_eq(stack.value("no_such_target"), 0.0)
	assert_push_error_count(1)


# ------------------------------------------------------------ vocabulary v2


func test_a_negative_add_is_clamped_at_zero() -> void:
	var stack: ModifierStack = _stack()
	_add(stack, "a", [_modifier("footprint", ModifierDef.Op.ADD, -2.0)])
	assert_eq(stack.value("footprint"), 0.0, "the clamp absorbs it")
	_add(stack, "b", [_modifier("footprint", ModifierDef.Op.ADD, 3.0)])
	assert_eq(stack.value("footprint"), 1.0, "0 + 3 - 2")


func test_no_target_is_inert_any_more() -> void:
	# The last one, the emergent rate, went live with the emergent kind in S5.2;
	# the list stays as the place a later target waits for its system.
	assert_true(ModifierStack.INERT_TARGETS.is_empty())


func test_an_inert_flag_is_answered_truthfully() -> void:
	var flag: String = ModifierStack.INERT_FLAGS[0]
	var stack: ModifierStack = _stack()
	var none: Array[ModifierDef] = []
	var flags: Array[String] = [flag]
	stack.add_source("a", none, flags)
	assert_true(stack.has_flag(flag))

# ------------------------------------------------- S4.1: the asset scope


## §6.3: the stack answers the asset scope, because it is the only one that
## depends on state rather than on the region's definition.
func _asset_modifier(kind: String, minimum: int = 1) -> ModifierDef:
	var modifier: ModifierDef = ModifierDef.new()
	modifier.target = "hardware"
	modifier.op = ModifierDef.Op.ADD
	modifier.value = 1.0
	modifier.scope_kind = ModifierDef.ScopeKind.ASSET
	modifier.scope_asset = kind
	modifier.scope_min = minimum
	return modifier


func _asset_stack(minimum: int = 1) -> ModifierStack:
	var bases: Dictionary[String, float] = {"hardware": 0.0}
	var stack: ModifierStack = ModifierStack.new(bases)
	var modifiers: Array[ModifierDef] = [_asset_modifier(AssetDef.KIND_FLEET, minimum)]
	var no_flags: Array[String] = []
	stack.add_source(ModifierStack.source_for_asset(AssetDef.KIND_FLEET), modifiers, no_flags)
	return stack


func test_an_asset_scope_applies_once_the_count_reaches_its_minimum() -> void:
	var stack: ModifierStack = _asset_stack(2)
	var region: RegionDef = Fixtures.db().regions[1]
	assert_almost_eq(stack.value("hardware", region), 0.0, 1e-9)
	stack.set_asset_count(region.index, AssetDef.KIND_FLEET, 1)
	assert_almost_eq(stack.value("hardware", region), 0.0, 1e-9, "one is not two")
	stack.set_asset_count(region.index, AssetDef.KIND_FLEET, 2)
	assert_almost_eq(stack.value("hardware", region), 1.0, 1e-9)


func test_an_asset_scope_never_reaches_a_global_stat() -> void:
	var stack: ModifierStack = _asset_stack()
	stack.set_asset_count(1, AssetDef.KIND_FLEET, 5)
	assert_almost_eq(stack.value("hardware"), 0.0, 1e-9, "a null region holds no assets")


func test_setting_a_count_to_zero_erases_it() -> void:
	var stack: ModifierStack = _asset_stack()
	stack.set_asset_count(1, AssetDef.KIND_FLEET, 3)
	assert_eq(stack.asset_count(1, AssetDef.KIND_FLEET), 3)
	stack.set_asset_count(1, AssetDef.KIND_FLEET, 0)
	assert_eq(stack.asset_count(1, AssetDef.KIND_FLEET), 0)
	assert_eq(stack.asset_count(99, AssetDef.KIND_FLEET), 0, "a region nobody wrote")


## The counts are state, not a source: `clear` drops the sources and leaves the
## world's own numbers alone (§6.3).
func test_clear_keeps_the_asset_counts() -> void:
	var stack: ModifierStack = _asset_stack()
	stack.set_asset_count(1, AssetDef.KIND_FLEET, 2)
	stack.clear()
	assert_eq(stack.asset_count(1, AssetDef.KIND_FLEET), 2)
	assert_eq(stack.sources().size(), 0)


# ------------------------------------------ S4.4: the Footprint a faction sees


func _watched(stack: ModifierStack, source: String, value: float,
		watched_by: Array[String]) -> void:
	var no_flags: Array[String] = []
	var modifiers: Array[ModifierDef] = [_modifier("footprint", ModifierDef.Op.ADD, value)]
	stack.add_source(source, modifiers, no_flags, watched_by)


func test_a_watched_source_counts_in_full_for_its_watcher_only() -> void:
	var stack: ModifierStack = _stack()
	_watched(stack, "a", 4.0, ["governments"] as Array[String])
	assert_eq(stack.footprint_for("governments"), 4.0)
	for faction: String in ["ai_labs", "security_researchers", "public_sentiment"]:
		assert_eq(stack.footprint_for(faction), 0.0, faction)
	assert_eq(stack.value("footprint"), 4.0, "the unscoped stat is unchanged")


func test_an_unwatched_source_counts_a_quarter_for_everyone() -> void:
	var stack: ModifierStack = _stack()
	_watched(stack, "a", 4.0, [] as Array[String])
	for faction: String in Faction.FACTION_IDS:
		assert_eq(stack.footprint_for(faction), 1.0, faction)


func test_a_negative_add_is_weighted_the_same_way() -> void:
	var stack: ModifierStack = _stack()
	_watched(stack, "a", 4.0, ["ai_labs"] as Array[String])
	_watched(stack, "b", -2.0, [] as Array[String])
	assert_eq(stack.footprint_for("ai_labs"), 3.5, "4 - a quarter of 2")
	assert_eq(stack.footprint_for("governments"), 0.0, "clamped at 0")


func test_a_footprint_multiplier_scales_every_faction() -> void:
	var stack: ModifierStack = _stack()
	_watched(stack, "a", 4.0, ["ai_labs", "governments"] as Array[String])
	_add(stack, "b", [_modifier("footprint", ModifierDef.Op.MUL, 0.5)])
	assert_eq(stack.footprint_for("ai_labs"), 2.0)
	assert_eq(stack.footprint_for("governments"), 2.0)


func test_a_removed_source_leaves_every_factions_footprint() -> void:
	var stack: ModifierStack = _stack()
	_watched(stack, "a", 4.0, ["public_sentiment"] as Array[String])
	stack.remove_source("a")
	assert_eq(stack.footprint_for("public_sentiment"), 0.0)
	assert_eq(stack.watched_by("a").size(), 0)


func test_a_nodes_watchers_reach_the_stack_when_it_is_bought() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	Fixtures.grant(sim, 100.0)
	Fixtures.buy(sim, ["fx_harm_1"])
	# fx_harm_1 carries +3 Footprint and no watchers: a quarter each.
	assert_almost_eq(sim.footprint_for("governments"), 0.75, 1e-12)
