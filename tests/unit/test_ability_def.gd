extends GutTest
## S4.2 — `AbilityDef` and what the loader made of `abilities.json`
## (`docs/specs/loop-mechanics.md` §9.1, §9.2).

var db: ContentDB


func before_each() -> void:
	db = Fixtures.db()


func test_the_fixture_abilities_all_load_in_file_order() -> void:
	assert_eq(db.abilities.size(), Fixtures.ABILITY_COUNT)
	assert_eq(db.abilities[0].id, Fixtures.ZAP_ABILITY)
	assert_eq(db.abilities[3].id, Fixtures.HUSH_ABILITY)


func test_an_unknown_ability_is_null_rather_than_a_crash() -> void:
	assert_null(db.ability("fx_nothing"))


func test_a_status_ability_carries_its_status_and_its_levels() -> void:
	var zap: AbilityDef = db.ability(Fixtures.ZAP_ABILITY)
	assert_eq(zap.applies_kind, AbilityDef.APPLIES_STATUS)
	assert_eq(zap.applies_status, Fixtures.ZAP_STATUS)
	assert_eq(zap.max_level(), 2)
	assert_eq(zap.levels_from, Fixtures.ZAP_NODES)
	assert_almost_eq(zap.cost, 2.0, 1e-9)
	assert_eq(zap.cooldown_days, 5)
	assert_true(zap.targets_region())


func test_a_deploying_ability_carries_its_kind_and_count() -> void:
	var forge: AbilityDef = db.ability(Fixtures.FORGE_ABILITY)
	assert_eq(forge.applies_kind, AbilityDef.APPLIES_DEPLOY)
	assert_eq(forge.applies_deploy_kind, AssetDef.KIND_FLEET)
	assert_eq(forge.applies_deploy_count, 1)


## §9.1: a global ability has no `eligible` block, and the loader still gives it
## a rule, so nothing has to branch before asking.
func test_a_global_ability_has_a_rule_that_accepts_everything() -> void:
	var hush: AbilityDef = db.ability(Fixtures.HUSH_ABILITY)
	assert_false(hush.targets_region())
	assert_not_null(hush.eligible)
	assert_eq(hush.eligible.requirements().size(), 0)


func test_an_eligible_block_is_read_as_the_rule_it_is() -> void:
	var reap: AbilityDef = db.ability(Fixtures.REAP_ABILITY)
	assert_true(reap.eligible.infected)
	assert_true(reap.eligible.not_dormant)
	assert_eq(reap.eligible.status_absent, [Fixtures.REAP_STATUS] as Array[String])


## `level_cap` is what lets an ability with two nodes apply a one-level status;
## without it the status must have as many levels as the ability (§9.1).
func test_the_status_level_follows_the_ability_level_unless_capped() -> void:
	var zap: AbilityDef = db.ability(Fixtures.ZAP_ABILITY)
	assert_eq(zap.status_level_for(2), 2)
	var capped: AbilityDef = AbilityDef.new()
	capped.level_cap = 1
	assert_eq(capped.status_level_for(3), 1)


func test_the_string_keys_are_built_from_the_id() -> void:
	assert_eq(AbilityDef.name_key("fx_zap"), "ABILITY_FX_ZAP_NAME")
	assert_eq(AbilityDef.detail_key("fx_zap"), "ABILITY_FX_ZAP_DETAIL")


## §9.2: the level is how many leading nodes of `levels_from` are owned, so a
## tree that grants the second without the first is impossible by construction.
func test_the_level_counts_the_leading_nodes_that_are_owned() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	assert_eq(sim.ability_level(Fixtures.ZAP_ABILITY), 0)
	Fixtures.grant(sim, 100.0)
	# The ability nodes sit behind the tree's reach node, so the level cannot be
	# reached without the branch that leads to it.
	Fixtures.buy(sim, ["fx_vector_net", "fx_reach", "fx_zap_1"] as Array[String])
	assert_eq(sim.ability_level(Fixtures.ZAP_ABILITY), 1)
	Fixtures.buy(sim, ["fx_zap_2"] as Array[String])
	assert_eq(sim.ability_level(Fixtures.ZAP_ABILITY), 2)


func test_an_unknown_ability_has_no_level() -> void:
	assert_eq(Fixtures.sim_with_origin().ability_level("fx_nothing"), 0)
