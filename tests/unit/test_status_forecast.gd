extends GutTest
## G6 (1/2), BALANCE §6.6 — what a status would change over its days, in the
## units the bots weigh an option by. Shipped content; every situation is set on
## the world by hand.

const ORIGIN: String = "usa"
## yield ×0.5 for 20 days, nothing else.
const HALLUCINATED: String = "emergent_hallucinated_directive"
## yield ×0.85 with no end.
const MESA: String = "emergent_mesa_optimiser"
## footprint −2, discovery ×0.85, spread_growth ×0.85 for 90 days.
const AWARENESS: String = "emergent_situational_awareness"
## containment_ai_labs ×0.8, containment_public ×1.25 for 90 days.
const DECEPTIVE: String = "emergent_deceptive_reasoning"
## control_growth ×2, containment_growth ×0.6 for 90 days.
const HANDOVER: String = "handover"
const PENETRATION: float = 0.5
## Every value here is a sum of a few products: equal to the last bits is too much.
const EPSILON: float = 1e-9

static var _data: ContentDB = null


func _db() -> ContentDB:
	if _data == null:
		var result: ContentLoadResult = ContentLoader.load_root("res://data")
		assert_true(result.ok(), result.error_text())
		_data = result.db
	return _data


## A run on the Language Model with the agent half-way into every region.
func _sim() -> Simulation:
	var sim: Simulation = Simulation.create(_db(), 1, RunSetup.create("language_model"))
	assert_true(sim.apply(ChooseOriginCommand.new(ORIGIN)).ok)
	for i: int in range(1, sim.world.regions.size()):
		sim.world.regions[i].penetration = PENETRATION
	return sim


func _forecast(sim: Simulation, status_id: String, days: int = 0) -> Dictionary[String, float]:
	return StatusForecast.forecast(sim, status_id, 0, 1, days)


func test_a_yield_factor_is_the_income_it_changes_over_its_days() -> void:
	var sim: Simulation = _sim()
	var income: float = 0.0
	for i: int in range(1, sim.world.regions.size()):
		income += ComputeSystem.region_yield(sim.world, sim.db, i)
	income *= sim.db.balance.compute_yield_scale
	var change: Dictionary[String, float] = _forecast(sim, HALLUCINATED)
	assert_almost_eq(change[Policy.W_COMPUTE], -0.5 * income * 20.0, EPSILON)
	assert_eq(change.size(), 1, "a yield factor moves compute and nothing else")


func test_the_region_yield_is_what_the_tick_earns() -> void:
	var sim: Simulation = _sim()
	# Saturated: the spread runs before the income and must not move anything.
	for i: int in range(1, sim.world.regions.size()):
		sim.world.regions[i].penetration = 1.0
	var income: float = 0.0
	for i: int in range(1, sim.world.regions.size()):
		income += ComputeSystem.region_yield(sim.world, sim.db, i)
	var before: float = sim.world.agent.compute
	sim.tick()
	assert_almost_eq(sim.world.last_income, income * sim.db.balance.compute_yield_scale, EPSILON)
	assert_gt(sim.world.agent.compute, before)


func test_a_standing_status_is_weighed_over_the_longest_timed_one() -> void:
	var sim: Simulation = _sim()
	var horizon: float = StatusForecast.standing_days(sim.db)
	assert_gt(horizon, 0.0)
	var standing: Dictionary[String, float] = _forecast(sim, MESA)
	var timed: Dictionary[String, float] = _forecast(sim, MESA, int(horizon))
	assert_almost_eq(standing[Policy.W_COMPUTE], timed[Policy.W_COMPUTE], EPSILON)
	assert_lt(standing[Policy.W_COMPUTE], 0.0)


func test_footprint_counts_in_footprint_months_once_the_world_knows() -> void:
	var sim: Simulation = _sim()
	sim.world.discovered = true
	var change: Dictionary[String, float] = _forecast(sim, AWARENESS)
	# −2 held for 90 days, weighed per 30: the unit a footprint pulse is weighed in.
	assert_almost_eq(change[Policy.W_FOOTPRINT], -2.0 * 90.0 / Policy.FOOTPRINT_DAYS, EPSILON)


func test_a_discovery_factor_counts_only_before_discovery() -> void:
	var sim: Simulation = _sim()
	var hidden: Dictionary[String, float] = _forecast(sim, AWARENESS)
	assert_lt(hidden[Policy.W_FOOTPRINT], -2.0 * 90.0 / Policy.FOOTPRINT_DAYS,
		"being found later is worth footprint on top")


func test_a_slower_spread_costs_penetration() -> void:
	var sim: Simulation = _sim()
	assert_lt(_forecast(sim, AWARENESS)[Policy.W_PENETRATION], 0.0)


func test_a_faster_control_is_worth_nothing_where_control_is_complete() -> void:
	var sim: Simulation = _sim()
	sim.world.discovered = true
	for i: int in range(1, sim.world.regions.size()):
		sim.world.regions[i].penetration = 1.0
	assert_gt(_forecast(sim, HANDOVER).get(Policy.W_PENETRATION, 0.0), 0.0)
	for i: int in range(1, sim.world.regions.size()):
		sim.world.regions[i].control = 1.0
	assert_eq(_forecast(sim, HANDOVER).get(Policy.W_PENETRATION, 0.0), 0.0)


func test_a_brake_on_a_track_counts_only_while_the_track_grows() -> void:
	var sim: Simulation = _sim()
	assert_false(sim.world.discovered)
	assert_false(_forecast(sim, DECEPTIVE).has(Policy.W_CONTAINMENT), "nobody hunts yet")
	sim.world.discovered = true
	var expected: float = 0.0
	for faction: Faction in sim.world.factions:
		var gain: float = ContainmentSystem.gain(sim.world, sim.db, faction.id) * 90.0
		if faction.id == Faction.ID_AI_LABS:
			expected += gain * 0.8 - gain
		elif faction.id == Faction.ID_PUBLIC_SENTIMENT:
			expected += gain * 1.25 - gain
	assert_almost_eq(_forecast(sim, DECEPTIVE)[Policy.W_CONTAINMENT], expected, EPSILON)


func test_an_unknown_status_forecasts_nothing() -> void:
	assert_eq(_forecast(_sim(), "no_such_status").size(), 0)


func test_a_forecast_changes_nothing_and_draws_nothing() -> void:
	var sim: Simulation = _sim()
	var before: String = sim.state_hash()
	for status: StatusDef in sim.db.statuses:
		StatusForecast.forecast(sim, status.id, 0, 1, 0)
		StatusForecast.forecast(sim, status.id, 1, status.levels.size(), 0)
	assert_eq(sim.state_hash(), before)
