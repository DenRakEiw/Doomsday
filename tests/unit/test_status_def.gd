extends GutTest
## S4.2 — `StatusDef` and `StatusLevelDef`
## (`docs/specs/loop-mechanics.md` §7.1, §7.3).

const DIM: String = "fx_dim"
const LOCK: String = "fx_lock"
const REGION: int = 2

var db: ContentDB


func before_each() -> void:
	db = Fixtures.db()


func test_the_fixture_statuses_all_load() -> void:
	assert_eq(db.statuses.size(), Fixtures.STATUS_COUNT)
	assert_eq(db.status(DIM).levels.size(), 2)
	assert_eq(db.status(DIM).origin, StatusDef.ORIGIN_PLAYER)
	assert_eq(db.status(LOCK).origin, StatusDef.ORIGIN_WORLD)


func test_an_unknown_status_is_null_rather_than_a_crash() -> void:
	assert_null(db.status("fx_nothing"))


func test_a_world_status_keeps_its_border_and_what_it_blocks() -> void:
	var lock: StatusDef = db.status(LOCK)
	assert_true(lock.border)
	assert_eq(lock.blocks, [LOCK] as Array[String])
	assert_false(db.status(DIM).border)


func test_a_level_carries_its_days_links_and_effects() -> void:
	var first: StatusLevelDef = db.status(DIM).levels[0]
	assert_eq(first.days, 5)
	assert_eq(first.closes_links, ["sea"] as Array[String])
	assert_eq(first.on_start.size(), 0)
	var second: StatusLevelDef = db.status(DIM).levels[1]
	assert_eq(second.days, 10)
	assert_eq(second.on_start.size(), 1)
	assert_eq(second.on_start[0].effect, EffectDef.SPREAD_STATUS)


func test_the_world_status_ends_another_one_and_closes_everything() -> void:
	var level: StatusLevelDef = db.status(LOCK).levels[0]
	assert_eq(level.closes_links, [StatusDef.LINKS_ALL] as Array[String])
	assert_eq(level.ends_statuses, [DIM] as Array[String])


func test_a_level_out_of_range_is_clamped_rather_than_indexed() -> void:
	var dim: StatusDef = db.status(DIM)
	assert_eq(dim.clamp_level(0), 1)
	assert_eq(dim.clamp_level(9), 2)
	assert_eq(dim.level_at(9), dim.levels[1])


## §7.3: the region is injected at application, and only into the regional
## targets — a global one keeps acting on the whole world.
func test_scoped_modifiers_scope_the_regional_targets_only() -> void:
	var scoped: Array[ModifierDef] = db.status(DIM).scoped_modifiers(1, REGION)
	assert_eq(scoped.size(), 2)
	var by_target: Dictionary[String, ModifierDef] = {}
	for modifier: ModifierDef in scoped:
		by_target[modifier.target] = modifier
	assert_eq(by_target["yield"].scope_kind, ModifierDef.ScopeKind.REGION)
	assert_eq(by_target["yield"].scope_region, REGION)
	assert_eq(by_target["footprint"].scope_kind, ModifierDef.ScopeKind.NONE)


func test_a_global_status_scopes_nothing() -> void:
	for modifier: ModifierDef in db.status(DIM).scoped_modifiers(1, 0):
		assert_eq(modifier.scope_kind, ModifierDef.ScopeKind.NONE)


func test_scoping_never_touches_the_definition() -> void:
	var original: ModifierDef = db.status(DIM).levels[0].modifiers[0]
	db.status(DIM).scoped_modifiers(1, REGION)
	assert_eq(original.scope_kind, ModifierDef.ScopeKind.NONE, "the definition is untouched")


func test_a_standing_level_says_so() -> void:
	var level: StatusLevelDef = StatusLevelDef.new()
	level.days = StatusLevelDef.DAYS_STANDING
	assert_true(level.is_standing())
	assert_false(db.status(DIM).levels[0].is_standing())


func test_the_string_keys_are_built_from_the_id() -> void:
	assert_eq(StatusDef.name_key(DIM), "STATUS_FX_DIM_NAME")
	assert_eq(StatusDef.detail_key(DIM), "STATUS_FX_DIM_DETAIL")
	assert_eq(StatusDef.code_key(DIM), "STATUS_FX_DIM_CODE")
