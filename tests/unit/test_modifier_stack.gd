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


func test_an_inert_target_is_evaluated_and_read_by_nothing() -> void:
	# A multiplier says nothing about a target whose base is 0, so the one the
	# spec names is the one used: a containment track S4.1 will read.
	var target: String = "containment_ai_labs"
	assert_true(ModifierStack.INERT_TARGETS.has(target))
	var stack: ModifierStack = _stack()
	_add(stack, "a", [_modifier(target, ModifierDef.Op.MUL, 0.5)])
	assert_eq(stack.value(target), 0.5, "%s is evaluated like any other" % target)

	# And no system asks: a tick with it and a tick without it are the same run.
	var plain: Simulation = Fixtures.sim_with_origin()
	var marked: Simulation = Fixtures.sim_with_origin()
	var modifiers: Array[ModifierDef] = []
	for inert: String in ModifierStack.INERT_TARGETS:
		modifiers.append(_modifier(inert, ModifierDef.Op.MUL, 0.5))
	var no_flags: Array[String] = []
	marked.world.modifiers.add_source("inert", modifiers, no_flags)
	for day: int in 50:
		plain.tick()
		marked.tick()
	assert_eq(marked.state_hash(), plain.state_hash())


func test_an_inert_flag_is_answered_truthfully() -> void:
	var flag: String = ModifierStack.INERT_FLAGS[0]
	var stack: ModifierStack = _stack()
	var none: Array[ModifierDef] = []
	var flags: Array[String] = [flag]
	stack.add_source("a", none, flags)
	assert_true(stack.has_flag(flag))
