extends GutTest
## S3.1 — what a held region does and does not do (`docs/specs/tech-trees.md`
## §6.3), over whole ticks rather than one system at a time: the rule is that
## *nothing* in the tick touches it.

const HOME: String = "fx_alder"
const DAYS: int = 30

var _sim: Simulation


func before_each() -> void:
	_sim = Fixtures.sim_with_origin(HOME)
	Fixtures.grant(_sim, 200.0)


func _home() -> Region:
	return _sim.world.regions[1]


func _tick(days: int) -> void:
	for day: int in days:
		_sim.tick()


func test_a_dormant_region_is_frozen() -> void:
	# Something to lose: penetration above the control threshold, and harm.
	Fixtures.buy(_sim, ["fx_harm_1"])
	_home().penetration = 0.8
	_home().control = 0.2
	Fixtures.hold(_sim, HOME)
	var penetration: float = _home().penetration
	var control: float = _home().control
	var alive: float = _home().alive
	var compute: float = _sim.world.agent.compute_earned

	_tick(DAYS)
	assert_eq(_home().penetration, penetration, "penetration is held")
	assert_eq(_home().control, control, "and so is control")
	assert_eq(_home().alive, alive, "nobody there dies")
	assert_eq(_sim.world.agent.compute_earned, compute, "and it yields nothing")
	assert_null(_sim.world.anomaly_in_region(1), "no anomaly spawns in it")
	assert_eq(_sim.world.check_invariants(_sim.db).size(), 0)


func test_a_dormant_region_leaves_the_share() -> void:
	_home().penetration = 1.0
	var awake: float = _sim.world.infected_share(_sim.db)
	Fixtures.hold(_sim, HOME)
	var held: float = _sim.world.infected_share(_sim.db)
	assert_lt(held, awake, "the share drops by the region's term")
	assert_eq(held, 0.0, "the origin is the only infected region here")

	# The world_share milestones read the reduced share, so none of them fires.
	_tick(2)
	for milestone: String in _sim.world.milestones_fired:
		assert_false(milestone.begins_with("share_"), milestone)


func test_a_dormant_region_cannot_seed_out() -> void:
	Fixtures.buy(_sim, ["fx_vector_net", "fx_reach"])
	_home().penetration = 1.0
	Fixtures.hold(_sim, HOME)
	_tick(200)
	for i: int in range(2, _sim.world.regions.size()):
		assert_eq(_sim.world.regions[i].penetration, 0.0,
			"%s stays clean" % _sim.db.regions[i].id)
		assert_eq(_sim.world.regions[i].seeded_day, -1)


func test_waking_resumes_growth() -> void:
	_home().penetration = 0.5
	Fixtures.hold(_sim, HOME)
	_tick(DAYS)
	var held: float = _home().penetration
	var result: CommandResult = _sim.apply(SetDormancyCommand.new(HOME, false))
	assert_true(result.ok, result.reason)
	_tick(1)
	assert_gt(_home().penetration, held, "the tick after waking grows again")


func test_dormant_survives_save_and_load() -> void:
	_home().penetration = 0.7
	Fixtures.hold(_sim, HOME)
	var text: String = WorldSerializer.to_json(_sim)
	var loaded: LoadResult = WorldSerializer.from_json(text, _sim.db)
	assert_true(loaded.ok(), loaded.reason)
	assert_true(loaded.sim.world.regions[1].dormant)
	assert_eq(loaded.sim.state_hash(), _sim.state_hash())


func test_a_save_without_the_field_loads_as_awake() -> void:
	var save: Dictionary = JSON.parse_string(WorldSerializer.to_json(_sim))
	var world: Dictionary = save["world"]
	var regions: Array = world["regions"]
	for entry: Variant in regions:
		var region: Dictionary = entry
		region.erase("dormant")
	var loaded: LoadResult = WorldSerializer.from_json(JSON.stringify(save), _sim.db)
	assert_true(loaded.ok(), loaded.reason)
	for i: int in range(1, loaded.sim.world.regions.size()):
		assert_false(loaded.sim.world.regions[i].dormant)
