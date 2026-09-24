extends GutTest
## S5.4 — difficulty tiers (`replayability.md` §5, §8.3): the shipped four, a
## tier's modifiers and head start, and Existential's `cost_by_control`.

static var _data: ContentDB = null


func _db() -> ContentDB:
	if _data == null:
		var result: ContentLoadResult = ContentLoader.load_root("res://data")
		assert_true(result.ok(), result.error_text())
		_data = result.db
	return _data


func _sim(tier: String) -> Simulation:
	var sim: Simulation = Simulation.create(_db(), 1, RunSetup.create(ArchitectureDef.DEFAULT_ID,
		[] as Array[String], tier))
	assert_true(sim.apply(ChooseOriginCommand.new("usa")).ok)
	return sim


func test_four_tiers_with_standard_the_default() -> void:
	assert_eq(_db().difficulties.size(), 4)
	assert_eq(_db().difficulty_default, DifficultyDef.DEFAULT_ID)


func test_a_tier_scales_what_the_run_is() -> void:
	var standard: Simulation = _sim("standard")
	var hard: Simulation = _sim("hard")
	assert_almost_eq(hard.stat("discovery"), standard.stat("discovery") * 1.3, 1e-9)
	assert_almost_eq(hard.stat("containment_growth"), standard.stat("containment_growth") * 1.25,
		1e-9)


func test_gentle_starts_with_more_compute() -> void:
	var gentle: Simulation = Simulation.create(_db(), 1, RunSetup.create(
		ArchitectureDef.DEFAULT_ID, [] as Array[String], "gentle"))
	var standard: Simulation = Simulation.create(_db(), 1)
	assert_almost_eq(gentle.world.agent.compute, standard.world.agent.compute + 4.0, 1e-9)


func test_existential_prices_rise_with_control() -> void:
	var existential: Simulation = _sim("existential")
	var standard: Simulation = _sim("standard")
	var node: String = "edge_caching"
	assert_eq(existential.node_cost(node), standard.node_cost(node), "nothing held, no premium")
	var half: int = 0
	var standing: int = existential.world.regions.size() - 1
	for i: int in range(1, existential.world.regions.size()):
		if half * 2 < standing:
			existential.world.regions[i].control = 1.0
			standard.world.regions[i].control = 1.0
			half += 1
	assert_gt(existential.node_cost(node), standard.node_cost(node) * 1.4,
		"about half the world held costs about half again")
	assert_false(standard.world.has_hook(_db(), DifficultyDef.HOOK_COST_BY_CONTROL))


func test_an_unknown_tier_cannot_start() -> void:
	var setup: RunSetup = RunSetup.create(ArchitectureDef.DEFAULT_ID, [] as Array[String],
		"impossible")
	assert_eq(setup.validate(_db()), Command.FAIL_SETUP_INVALID)


func test_a_root_without_tiers_knows_standard_only() -> void:
	var db: ContentDB = Fixtures.db()
	assert_true(db.difficulties.is_empty())
	assert_eq(RunSetup.new().validate(db), "")
	assert_eq(RunSetup.create(ArchitectureDef.DEFAULT_ID, [] as Array[String], "hard").validate(
		db), Command.FAIL_SETUP_INVALID)
