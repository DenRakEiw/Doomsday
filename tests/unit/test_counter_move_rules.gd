extends GutTest
## S4.5 — where a move lands (opposition.md §6.4). The fixture's regions:
## 1 fx_alder (regulation 3, research 4), 2 fx_birch (2, 1), 3 fx_cedar (0, 0),
## 4 fx_dogwood (4, 2), 5 fx_elm (1, 0), 6 fx_fir (4, 3).

const STATUS: String = "fx_lock"

var sim: Simulation


func before_each() -> void:
	sim = Fixtures.sim_with_origin()
	sim.world.regions[1].penetration = 0.0


func _infect(region: int, penetration: float) -> void:
	sim.world.regions[region].penetration = penetration
	sim.world.regions[region].seeded_day = 0


func _pick(rule: String, status_id: String = STATUS) -> int:
	return CounterMoveRules.pick(rule, sim.world, sim.db, status_id)


func test_the_rule_names_are_the_event_grammars() -> void:
	assert_eq(CounterMoveRules.RULES, EventDef.PICK_RULES)
	assert_eq(CounterMoveRules.SELECTORS, FactionMoveDef.SELECTORS)


func test_no_region_with_the_agent_is_no_target() -> void:
	for rule: String in CounterMoveRules.RULES:
		assert_eq(_pick(rule), CounterMoveRules.NONE, rule)


func test_lockdown_scores_presence_times_regulation() -> void:
	_infect(2, 0.5)  # 0.5 × (1 + 2) = 1.5
	_infect(4, 0.4)  # 0.4 × (1 + 4) = 2.0
	assert_eq(_pick(CounterMoveRules.LOCKDOWN_TARGET), 4)


func test_richest_infected_scores_hardware_times_presence() -> void:
	_infect(1, 0.2)
	_infect(3, 0.9)
	var alder: float = sim.hardware(1) * 0.2
	var cedar: float = sim.hardware(3) * 0.9
	assert_eq(_pick(CounterMoveRules.RICHEST_INFECTED), 1 if alder > cedar else 3)


func test_audit_needs_research_and_presence() -> void:
	_infect(2, 0.9)  # research 1: filtered out
	_infect(4, 0.1)  # research 2 but only 0.1: filtered out
	assert_eq(_pick(CounterMoveRules.AUDIT_TARGET), CounterMoveRules.NONE)
	_infect(6, 0.3)  # research 3 × 0.3
	assert_eq(_pick(CounterMoveRules.AUDIT_TARGET), 6)


func test_purge_goes_for_the_labs_first() -> void:
	_infect(1, 0.9)  # research 4
	_infect(5, 0.1)  # research 0, but a lab
	assert_eq(_pick(CounterMoveRules.PURGE_TARGET), 1, "without labs, the research-richest")
	sim.world.set_assets(5, AssetDef.KIND_LAB, 1)
	assert_eq(_pick(CounterMoveRules.PURGE_TARGET), 5)


func test_exposure_skips_a_region_already_exposed() -> void:
	# The fixture has no `exposure` status; the game's content has.
	var result: ContentLoadResult = ContentLoader.load_root("res://data")
	assert_true(result.ok(), result.error_text())
	var game: Simulation = Simulation.create(result.db, 1)
	game.apply(ChooseOriginCommand.new(result.db.regions[1].id))
	game.world.regions[1].penetration = 0.8
	game.world.regions[2].penetration = 0.4
	assert_eq(CounterMoveRules.pick(CounterMoveRules.EXPOSURE_TARGET, game.world, game.db,
		CounterMoveRules.EXPOSURE_STATUS), 1)
	var none: Array[SimEvent] = []
	StatusSystem.apply(game.world, game.db, CounterMoveRules.EXPOSURE_STATUS, 1,
		Status.SOURCE_EFFECT, 1, "", none)
	assert_eq(CounterMoveRules.pick(CounterMoveRules.EXPOSURE_TARGET, game.world, game.db,
		CounterMoveRules.EXPOSURE_STATUS), 2, "the move recurs somewhere else")


func test_protest_goes_where_the_fleets_are() -> void:
	_infect(2, 0.2)
	_infect(3, 0.9)
	sim.world.set_assets(2, AssetDef.KIND_FLEET, 1)
	assert_eq(_pick(CounterMoveRules.PROTEST_TARGET), 2)


func test_protest_without_fleets_goes_where_the_dead_are() -> void:
	_infect(2, 0.2)
	_infect(3, 0.9)
	var cedar: Region = sim.world.regions[3]
	cedar.deaths = float(cedar.def.population) * 0.02
	cedar.alive -= cedar.deaths
	assert_eq(_pick(CounterMoveRules.PROTEST_TARGET), 3)


func test_protest_without_fleets_or_enough_dead_finds_nobody() -> void:
	_infect(2, 0.9)
	var birch: Region = sim.world.regions[2]
	birch.deaths = float(birch.def.population) * 0.005
	birch.alive -= birch.deaths
	assert_eq(_pick(CounterMoveRules.PROTEST_TARGET), CounterMoveRules.NONE)


func test_dark_dormant_and_blocked_regions_are_skipped() -> void:
	_infect(2, 0.5)
	_infect(4, 0.4)
	_infect(6, 0.3)
	sim.world.regions[4].dormant = true
	var none: Array[SimEvent] = []
	# fx_lock blocks fx_lock: a region under one is not a target for another.
	StatusSystem.apply(sim.world, sim.db, STATUS, 2, Status.SOURCE_EFFECT, 1, "", none)
	assert_eq(_pick(CounterMoveRules.LOCKDOWN_TARGET), 6)


func test_ties_go_to_the_lower_index() -> void:
	_infect(2, 0.5)
	_infect(3, 0.5)
	assert_eq(_pick(CounterMoveRules.EXPOSURE_TARGET), 2)


func test_seeds_by_kind_max_picks_the_kind_seeded_most() -> void:
	sim.world.agent.seeds_by_kind = {"sea": 2, "air": 5}
	assert_eq(CounterMoveRules.select("seeds_by_kind_max", sim.world, sim.db), "air")


func test_seeds_by_kind_max_ties_to_the_earliest_kind() -> void:
	assert_eq(CounterMoveRules.select("seeds_by_kind_max", sim.world, sim.db), LinkDef.KINDS[0])
	sim.world.agent.seeds_by_kind = {"air": 3, "sea": 3}
	assert_eq(CounterMoveRules.select("seeds_by_kind_max", sim.world, sim.db), "sea")


func test_the_rules_draw_nothing_from_the_generator() -> void:
	_infect(2, 0.5)
	var before: String = sim.world.rng.state_string()
	for rule: String in CounterMoveRules.RULES:
		_pick(rule)
	assert_eq(sim.world.rng.state_string(), before)
