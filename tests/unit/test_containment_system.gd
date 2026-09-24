extends GutTest
## S1.5, S4.4 — being found, and the four tracks that close in afterwards
## (opposition.md §5).

const LABS: String = "ai_labs"
const GOVERNMENTS: String = "governments"
const RESEARCHERS: String = "security_researchers"
const PUBLIC: String = "public_sentiment"

var system: ContainmentSystem
var events: Array[SimEvent]


func before_each() -> void:
	system = ContainmentSystem.new()
	events = []


func _run(sim: Simulation) -> void:
	events = []
	system.tick(sim.world, sim.db, events)


func _force(sim: Simulation, target: String, op: ModifierDef.Op, value: float,
		watched_by: Array[String] = [], scope_attr: String = "", scope_min: int = 0) -> void:
	var modifier: ModifierDef = ModifierDef.new()
	modifier.target = target
	modifier.op = op
	modifier.value = value
	if not scope_attr.is_empty():
		modifier.scope_kind = ModifierDef.ScopeKind.ATTR
		modifier.scope_attr = scope_attr
		modifier.scope_min = scope_min
	var modifiers: Array[ModifierDef] = [modifier]
	var no_flags: Array[String] = []
	sim.world.modifiers.add_source("test_%s_%d" % [target, sim.world.modifiers.sources().size()],
		modifiers, no_flags, watched_by)


## Discovered on day 0 and looked at on day 5, so the first tick is not the one
## right after discovery (whose leader change reads `from ""`).
func _discovered() -> Simulation:
	var sim: Simulation = Fixtures.sim_with_origin()
	sim.world.discovered = true
	sim.world.discovery_day = 0
	sim.world.day = 5
	return sim


func _track(sim: Simulation, faction_id: String) -> float:
	return sim.world.faction(faction_id).containment


func _term(sim: Simulation, faction_id: String, source: String) -> Dictionary:
	var breakdown: Dictionary = sim.containment_breakdown(faction_id)
	for entry: Variant in breakdown[ContainmentSystem.TERMS]:
		var term: Dictionary = entry
		if term[ContainmentSystem.TERM_SOURCE] == source:
			return term
	return {}


func _value(sim: Simulation, faction_id: String, source: String) -> float:
	return float(_term(sim, faction_id, source)[ContainmentSystem.TERM_VALUE])


# ------------------------------------------------------------------ discovery


func test_containment_does_not_grow_before_discovery() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	for i: int in 200:
		if sim.world.discovered:
			break
		_run(sim)
		sim.world.day += 1
		for faction: Faction in sim.world.factions:
			assert_eq(faction.containment, 0.0)


func test_containment_does_not_grow_on_the_day_of_discovery() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	_force(sim, "discovery", ModifierDef.Op.MUL, 20.0)
	sim.world.regions[1].deaths = 30000.0
	sim.world.regions[1].alive -= 30000.0
	_run(sim)
	assert_true(sim.world.discovered)
	assert_eq(sim.world.max_containment(), 0.0, "the world needs a day to react")
	sim.world.day += 1
	_run(sim)
	assert_gt(sim.world.max_containment(), 0.0)


func test_deaths_above_the_threshold_discover_without_a_roll() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	# 0.0001 of 255 000 000 people.
	sim.world.regions[1].deaths = 30000.0
	sim.world.regions[1].alive -= 30000.0
	var before: String = sim.world.rng.state_string()
	_run(sim)
	assert_true(sim.world.discovered)
	assert_eq(sim.world.discovery_day, 0)
	assert_eq(events[0].type, SimEvent.DISCOVERED)
	assert_eq(events[0].data["cause"], SimEvent.CAUSE_DEATHS)
	assert_eq(sim.world.rng.state_string(), before, "certainty costs no roll")


func test_a_discovery_stat_of_zero_means_no_risk_at_all() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	_force(sim, "discovery", ModifierDef.Op.MUL, 0.0)
	for i: int in 2000:
		_run(sim)
		sim.world.day += 1
	assert_false(sim.world.discovered)
	assert_eq(sim.world.rng.state_string(), SimRng.from_seed(1).state_string(),
		"a risk of zero is never rolled")


func test_footprint_brings_discovery_forward() -> void:
	assert_lt(_mean_discovery_day(8.0), _mean_discovery_day(0.0),
		"being visible is what gets the agent found")


const _SEEDS: int = 10
const _LIMIT: int = 3000


func _mean_discovery_day(footprint: float) -> float:
	var total: float = 0.0
	for seed_value: int in range(1, _SEEDS + 1):
		var sim: Simulation = Fixtures.sim_with_origin("fx_alder", seed_value)
		if footprint > 0.0:
			_force(sim, "footprint", ModifierDef.Op.ADD, footprint)
		var day: int = _LIMIT
		for i: int in _LIMIT:
			sim.world.day += 1
			_run(sim)
			if sim.world.discovered:
				day = sim.world.discovery_day
				break
		total += float(day)
	return total / float(_SEEDS)


# ---------------------------------------------------------------------- terms


func test_the_footprint_term_is_the_footprint_the_faction_sees() -> void:
	var sim: Simulation = _discovered()
	var watchers: Array[String] = [GOVERNMENTS]
	_force(sim, "footprint", ModifierDef.Op.ADD, 4.0, watchers)
	assert_almost_eq(_value(sim, GOVERNMENTS, "footprint"), sim.footprint_for(GOVERNMENTS), 1e-12)
	assert_gt(_value(sim, GOVERNMENTS, "footprint"), _value(sim, LABS, "footprint"),
		"only the watcher sees all of it")


func test_the_harm_term_is_the_alive_weighted_mean_of_scoped_harm() -> void:
	var sim: Simulation = _discovered()
	# Harm 2 in the regions with research ≥ 3: fx_alder (60 M) and fx_fir (8 M).
	_force(sim, "harm", ModifierDef.Op.ADD, 2.0, [], "research", 3)
	var weighted: float = 0.0
	var alive: float = 0.0
	for i: int in range(1, sim.world.regions.size()):
		var region: Region = sim.world.regions[i]
		var harm: float = 2.0 if region.def.attr("research") >= 3 else 0.0
		weighted += harm * region.alive
		alive += region.alive
	assert_almost_eq(_value(sim, GOVERNMENTS, "harm"), weighted / alive, 1e-12)
	assert_eq(sim.world.modifiers.value("harm"), 0.0, "the unscoped read would say nothing")


func test_the_share_term_is_the_infected_share() -> void:
	var sim: Simulation = _discovered()
	sim.world.regions[2].penetration = 0.5
	assert_almost_eq(_value(sim, GOVERNMENTS, "share"), sim.world.infected_share(sim.db), 1e-12)


func test_the_deaths_share_term_counts_every_death() -> void:
	var sim: Simulation = _discovered()
	sim.world.regions[3].deaths = 12000000.0
	sim.world.regions[3].alive -= 12000000.0
	assert_almost_eq(_value(sim, PUBLIC, "deaths_share"),
		12000000.0 / sim.db.population_total, 1e-12)


func test_the_seeded_share_term_counts_regions_reached() -> void:
	var sim: Simulation = _discovered()
	sim.world.regions[2].seeded_day = 1
	sim.world.regions[2].penetration = 0.1
	var expected: float = float(sim.world.seeded_count()) / float(sim.world.regions.size() - 1)
	assert_almost_eq(_value(sim, RESEARCHERS, "seeded_share"), expected, 1e-12)
	assert_gt(expected, 0.0)


func test_the_owned_nodes_term_counts_one_tree() -> void:
	var sim: Simulation = _discovered()
	sim.world.agent.owned_nodes.append("fx_efficiency")
	sim.world.agent.owned_nodes.append("fx_grip")
	sim.world.agent.owned_nodes.append("fx_quiet")
	assert_eq(_value(sim, LABS, "owned_nodes"), 2.0, "two capabilities nodes, not the evasion one")


func test_the_watched_statuses_term_counts_player_statuses_a_faction_watches() -> void:
	var content: Dictionary = Fixtures.raw_content()
	for entry: Variant in content["statuses"]["statuses"]:
		var s: Dictionary = entry
		if s["id"] == "fx_dim":
			s["watched_by"] = [GOVERNMENTS, PUBLIC]
		if s["id"] == "fx_lock":
			s["watched_by"] = [GOVERNMENTS]
	var db: ContentDB = Fixtures.load_raw(content).db
	var sim: Simulation = Simulation.create(db, 1)
	sim.apply(ChooseOriginCommand.new("fx_alder"))
	var none: Array[SimEvent] = []
	StatusSystem.apply(sim.world, db, "fx_dim", 1, Status.SOURCE_EFFECT, 1, "", none)
	StatusSystem.apply(sim.world, db, "fx_lock", 2, Status.SOURCE_EFFECT, 1, "", none)
	assert_eq(_value(sim, GOVERNMENTS, "watched_statuses"), 1.0,
		"the player's status counts, the world's does not")
	assert_eq(_value(sim, PUBLIC, "watched_statuses"), 1.0, "for both factions that watch it")


func test_the_assets_term_counts_one_kind_everywhere() -> void:
	var sim: Simulation = _discovered()
	sim.world.set_assets(1, AssetDef.KIND_FLEET, 2)
	sim.world.set_assets(2, AssetDef.KIND_FLEET, 1)
	sim.world.set_assets(2, AssetDef.KIND_LAB, 1)
	assert_eq(_value(sim, PUBLIC, "assets"), 3.0)


func test_a_term_contributes_its_weight_times_its_value() -> void:
	var sim: Simulation = _discovered()
	sim.world.regions[2].penetration = 0.5
	var term: Dictionary = _term(sim, RESEARCHERS, "share")
	assert_almost_eq(float(term[ContainmentSystem.TERM_CONTRIBUTION]),
		1.5 * float(term[ContainmentSystem.TERM_VALUE]), 1e-12)


# ------------------------------------------------------------------- capacity


func test_capacity_weighs_each_region_by_the_factions_own_attribute() -> void:
	var sim: Simulation = _discovered()
	# Empty every region but fx_cedar: research 0, regulation 0, connectivity 1,
	# population tier 3 (120 M).
	for i: int in [1, 2, 4, 5, 6]:
		sim.world.regions[i].deaths = float(sim.world.regions[i].def.population)
		sim.world.regions[i].alive = 0.0
	var weights: Array[float] = sim.db.balance.containment_capacity_weight_by_tier
	for faction_id: String in [LABS, GOVERNMENTS, RESEARCHERS, PUBLIC]:
		var attribute: String = sim.db.faction(faction_id).capacity_attr
		var total: float = 0.0
		for i: int in range(1, sim.world.regions.size()):
			total += weights[sim.world.regions[i].def.attr(attribute)]
		var expected: float = weights[sim.world.regions[3].def.attr(attribute)] / total
		assert_almost_eq(float(sim.containment_breakdown(faction_id)[ContainmentSystem.CAPACITY]),
			expected, 1e-12, faction_id)


func test_capacity_falls_with_deaths() -> void:
	var healthy: Simulation = _discovered()
	_run(healthy)
	var full: float = _track(healthy, LABS)

	var emptied: Simulation = _discovered()
	# fx_fir is research tier 3 and weighs heavily for the labs.
	emptied.world.regions[6].deaths = float(emptied.world.regions[6].def.population)
	emptied.world.regions[6].alive = 0.0
	_run(emptied)
	assert_lt(_track(emptied, LABS), full)


func test_capacity_falls_with_control() -> void:
	var free: Simulation = _discovered()
	_run(free)
	var full: float = _track(free, GOVERNMENTS)

	var held: Simulation = _discovered()
	held.world.regions[6].control = 1.0
	_run(held)
	assert_lt(_track(held, GOVERNMENTS), full)


func test_containment_capacity_scales_a_regions_share() -> void:
	var sim: Simulation = _discovered()
	var before: float = float(sim.containment_breakdown(LABS)[ContainmentSystem.CAPACITY])
	_force(sim, "containment_capacity", ModifierDef.Op.MUL, 0.0, [], "research", 3)
	assert_lt(float(sim.containment_breakdown(LABS)[ContainmentSystem.CAPACITY]), before)


# ----------------------------------------------------------------------- gain


func test_each_track_grows_by_its_own_breakdown_gain() -> void:
	var sim: Simulation = _discovered()
	sim.world.regions[2].penetration = 0.5
	_force(sim, "footprint", ModifierDef.Op.ADD, 3.0)
	var expected: Dictionary[String, float] = {}
	for faction: Faction in sim.world.factions:
		expected[faction.id] = float(sim.containment_breakdown(faction.id)[ContainmentSystem.GAIN])
	_run(sim)
	for faction: Faction in sim.world.factions:
		assert_almost_eq(faction.containment, expected[faction.id], 1e-15, faction.id)


func test_the_gain_is_base_rate_times_pressure_capacity_and_brakes() -> void:
	var sim: Simulation = _discovered()
	sim.world.regions[2].penetration = 0.5
	var breakdown: Dictionary = sim.containment_breakdown(GOVERNMENTS)
	var sum: float = 0.0
	for entry: Variant in breakdown[ContainmentSystem.TERMS]:
		sum += float((entry as Dictionary)[ContainmentSystem.TERM_CONTRIBUTION])
	assert_almost_eq(float(breakdown[ContainmentSystem.PRESSURE]), 1.0 + sum, 1e-12)
	assert_almost_eq(float(breakdown[ContainmentSystem.GAIN]),
		sim.db.balance.containment_base_rate * (1.0 + sum)
		* float(breakdown[ContainmentSystem.CAPACITY])
		* float(breakdown[ContainmentSystem.BRAKES]), 1e-15)


func test_a_brake_slows_one_track_only() -> void:
	var loud: Simulation = _discovered()
	_run(loud)
	var quiet: Simulation = _discovered()
	_force(quiet, "containment_ai_labs", ModifierDef.Op.MUL, 0.5)
	_run(quiet)
	assert_almost_eq(_track(quiet, LABS), _track(loud, LABS) * 0.5, 1e-12)
	for faction_id: String in [GOVERNMENTS, RESEARCHERS, PUBLIC]:
		assert_eq(_track(quiet, faction_id), _track(loud, faction_id), faction_id)


func test_containment_growth_slows_every_track() -> void:
	var loud: Simulation = _discovered()
	_run(loud)
	var quiet: Simulation = _discovered()
	_force(quiet, "containment_growth", ModifierDef.Op.MUL, 0.6)
	_run(quiet)
	for faction: Faction in quiet.world.factions:
		assert_almost_eq(faction.containment, _track(loud, faction.id) * 0.6, 1e-12)


func test_each_threshold_is_announced_once_per_faction_in_order() -> void:
	var sim: Simulation = _discovered()
	_force(sim, "containment_growth", ModifierDef.Op.MUL, 20.0)
	var announced: Dictionary[String, Array] = {}
	for i: int in 3000:
		sim.world.day += 1
		_run(sim)
		for event: SimEvent in events:
			if event.type != SimEvent.CONTAINMENT_THRESHOLD:
				continue
			var faction: String = str(event.data["faction"])
			if not announced.has(faction):
				announced[faction] = []
			announced[faction].append(event.data["threshold"])
		if sim.world.max_containment() >= 1.0 and _all_full(sim):
			break
	var expected: Array = sim.db.balance.containment_thresholds
	for faction_id: String in Faction.FACTION_IDS:
		assert_eq(announced.get(faction_id, []), expected, faction_id)


func _all_full(sim: Simulation) -> bool:
	for faction: Faction in sim.world.factions:
		if faction.containment < 1.0:
			return false
	return true


func test_containment_never_passes_one() -> void:
	var sim: Simulation = _discovered()
	_force(sim, "containment_growth", ModifierDef.Op.MUL, 20.0)
	for i: int in 3000:
		sim.world.day += 1
		_run(sim)
	for faction: Faction in sim.world.factions:
		assert_lte(faction.containment, 1.0)
	assert_eq(sim.world.max_containment(), 1.0)


func test_nothing_happens_before_an_origin_is_chosen() -> void:
	var sim: Simulation = Fixtures.sim()
	sim.world.day = 500
	_run(sim)
	assert_false(sim.world.discovered)


# --------------------------------------------------------------------- leader


func test_there_is_no_leader_before_discovery() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	sim.world.faction(GOVERNMENTS).containment = 0.3
	assert_eq(sim.threat_leader(), "")


func test_the_leader_is_the_highest_track_ties_to_the_earlier() -> void:
	var sim: Simulation = _discovered()
	sim.world.faction(RESEARCHERS).containment = 0.3
	assert_eq(sim.threat_leader(), RESEARCHERS)
	sim.world.faction(GOVERNMENTS).containment = 0.3
	assert_eq(sim.threat_leader(), GOVERNMENTS, "a tie goes to the earlier faction")
	for faction: Faction in sim.world.factions:
		faction.containment = 0.0
	assert_eq(sim.threat_leader(), LABS)


func test_the_first_tick_after_discovery_names_a_leader_from_nobody() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	sim.world.discovered = true
	sim.world.discovery_day = 3
	sim.world.day = 4
	_run(sim)
	var changes: Array[SimEvent] = _changes()
	assert_eq(changes.size(), 1)
	assert_eq(changes[0].data["from"], "")
	assert_eq(changes[0].data["to"], sim.threat_leader())


func test_a_lead_change_is_announced_once_with_from_and_to() -> void:
	var sim: Simulation = _discovered()
	_run(sim)
	sim.world.day += 1
	_run(sim)
	var leader: String = sim.threat_leader()
	assert_eq(_changes().size(), 0, "no change, no event")
	var other: String = PUBLIC if leader != PUBLIC else LABS
	# Level with the leader but behind it in order, and much faster: the next
	# tick puts it in front.
	sim.world.faction(other).containment = _track(sim, leader)
	_force(sim, sim.db.faction(other).brake, ModifierDef.Op.MUL, 20.0)
	sim.world.day += 1
	_run(sim)
	var changes: Array[SimEvent] = _changes()
	assert_eq(changes.size(), 1)
	assert_eq(changes[0].data["from"], leader)
	assert_eq(changes[0].data["to"], other)
	sim.world.day += 1
	_run(sim)
	assert_eq(_changes().size(), 0, "and not again while it holds")


func _changes() -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for event: SimEvent in events:
		if event.type == SimEvent.THREAT_LEADER_CHANGED:
			out.append(event)
	return out


# ----------------------------------------------------------------- invariants


func test_invariants_catch_a_preparation_without_a_fire_day() -> void:
	var sim: Simulation = _discovered()
	sim.world.faction(GOVERNMENTS).preparing = "fx_move"
	assert_string_contains(str(sim.world.check_invariants(sim.db)), "without a fire day")


func test_invariants_catch_a_preparation_that_is_no_counter_move() -> void:
	var sim: Simulation = _discovered()
	sim.world.faction(GOVERNMENTS).preparing = "fx_opening"
	sim.world.faction(GOVERNMENTS).fire_day = sim.world.day + 2
	assert_string_contains(str(sim.world.check_invariants(sim.db)), "no counter-move")


## G4 (BALANCE §4.3): brakes multiply down to the floor and no further, so no
## build makes a faction powerless. The fixture's floor is 0; this one is set.
func test_brakes_stop_at_the_floor() -> void:
	var sim: Simulation = _discovered()
	sim.db.balance.containment_brake_floor = 0.7
	_force(sim, "containment_growth", ModifierDef.Op.MUL, 0.5)
	assert_almost_eq(float(sim.containment_breakdown(GOVERNMENTS)[ContainmentSystem.BRAKES]),
		0.7, 1e-12, "×0.5 is floored")
	var mild: Simulation = _discovered()
	mild.db.balance.containment_brake_floor = 0.7
	_force(mild, "containment_growth", ModifierDef.Op.MUL, 0.8)
	assert_almost_eq(float(mild.containment_breakdown(GOVERNMENTS)[ContainmentSystem.BRAKES]),
		0.8, 1e-12, "×0.8 is above it")
	sim.db.balance.containment_brake_floor = 0.0
	mild.db.balance.containment_brake_floor = 0.0
