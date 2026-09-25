extends GutTest
## S5.8 — scenarios (`docs/specs/scenarios.md`): the shipped file, each start
## field applied once and at its moment (statuses and flags at the origin, the
## containment head start on the day of discovery and not before), the origin
## rule, the save, and one full run per scenario without a rejected command.
##
## The spec's 50-run batch per scenario is a `sim_batch` run, not a test (190 s
## per scenario); its result is in PROGRESS.md's session log for S5.8.

const Harness := preload("res://tools/sim_harness.gd")
const WORLD_ROOT: String = "res://data"
const SEED: int = 1
const DAYS: int = 5000
## How long an architecture-and-scenario pair is played: long enough to pass
## discovery and the Task Force, short of a Swarm run that never ends.
const MIXED_DAYS: int = 800
const SUCCESSOR: String = "successor"
const AIRGAP: String = "airgap_earth"
const INHERITANCE: String = "inheritance"
const DISCONNECTED: String = "disconnected"
## How long a test waits for a discovery it has made certain.
const DISCOVERY_DAYS: int = 20
## Deaths over `discovery.deaths_certain_share` of the world: nobody rolls for
## them (ContainmentSystem).
const CERTAIN_DEATHS_FACTOR: float = 2.0

static var _db: ContentDB = null


func before_all() -> void:
	if _db == null:
		var result: ContentLoadResult = ContentLoader.load_root(WORLD_ROOT)
		assert_true(result.ok(), result.error_text())
		_db = result.db


func _sim(scenario: String, difficulty: String = DifficultyDef.DEFAULT_ID) -> Simulation:
	return Simulation.create(_db, SEED, RunSetup.create(ArchitectureDef.DEFAULT_ID, [],
		difficulty, scenario))


## The first region the scenario's own rule and the general origin rule both
## accept, in index order.
func _open_origin(sim: Simulation) -> String:
	for i: int in range(1, _db.regions.size()):
		if sim.can_apply(ChooseOriginCommand.new(_db.regions[i].id)).is_empty():
			return _db.regions[i].id
	return ""


func _started(scenario: String) -> Simulation:
	var sim: Simulation = _sim(scenario)
	var origin: String = _open_origin(sim)
	assert_false(origin.is_empty(), "%s has no open origin" % scenario)
	assert_true(sim.apply(ChooseOriginCommand.new(origin)).ok)
	return sim


## Tests may set state to build a situation: enough deaths in the origin that
## the next tick finds the agent without a roll.
func _make_discovery_certain(sim: Simulation) -> void:
	var deaths: float = _db.population_total * _db.balance.discovery_deaths_certain_share
	sim.world.regions[sim.world.agent.origin].deaths = deaths * CERTAIN_DEATHS_FACTOR


func _count(events: Array[SimEvent], type: String) -> int:
	var count: int = 0
	for event: SimEvent in events:
		if event.type == type:
			count += 1
	return count


# ---------------------------------------------------------------- content


func test_three_scenarios_unlock_after_three_runs() -> void:
	assert_eq(_db.scenarios.size(), 3)
	assert_eq(_db.scenario_unlock_runs, 3)
	for id: String in [SUCCESSOR, AIRGAP, INHERITANCE]:
		assert_not_null(_db.scenario(id), id)
	assert_eq(_db.status(DISCONNECTED).origin, StatusDef.ORIGIN_WORLD)
	assert_true(_db.status(DISCONNECTED).levels[0].is_standing())


func test_an_unknown_scenario_cannot_start() -> void:
	var setup: RunSetup = RunSetup.create(ArchitectureDef.DEFAULT_ID, [],
		DifficultyDef.DEFAULT_ID, "no_such_scenario")
	assert_eq(setup.validate(_db), Command.FAIL_SETUP_INVALID)
	assert_eq(RunSetup.create().validate(_db), "", "no scenario is a valid setup")


func test_a_setup_without_a_scenario_field_reads_as_none() -> void:
	var raw: Dictionary = RunSetup.create().to_dict()
	raw.erase("scenario")
	var setup: RunSetup = RunSetup.from_dict(raw)
	assert_not_null(setup)
	assert_eq(setup.scenario, "")
	raw["scenario"] = 3
	assert_null(RunSetup.from_dict(raw), "a scenario of another type is refused")


func test_the_harness_reads_the_scenario_item() -> void:
	var args: Dictionary[String, String] = {"setup": "swarm,hard,yield_greedy,scenario=%s" % AIRGAP}
	var setup: RunSetup = Harness.setup_from_args(args)
	assert_eq(setup.architecture, "swarm")
	assert_eq(setup.difficulty, "hard")
	assert_eq(setup.directives, ["yield_greedy"] as Array[String])
	assert_eq(setup.scenario, AIRGAP)


# ------------------------------------------------------------- the start


func test_a_start_compute_replaces_the_balance_start_and_a_tier_adds_to_it() -> void:
	assert_eq(_sim(INHERITANCE).world.agent.compute, 3.0)
	var gentle: DifficultyDef = _db.difficulty("gentle")
	assert_eq(_sim(INHERITANCE, "gentle").world.agent.compute, 3.0 + gentle.start_compute)
	assert_eq(_sim(SUCCESSOR).world.agent.compute, _db.balance.compute_start,
		"a scenario without a start compute keeps the balance's")


func test_the_modifiers_are_active_for_the_whole_run() -> void:
	# The factor is read from the shipped data, so a balance pass that retunes it
	# (G5 2/3: 0.75 -> 0.65) does not break what this test is about.
	var factor: float = 0.0
	for modifier: ModifierDef in _db.scenario(INHERITANCE).modifiers:
		if modifier.target == "yield":
			factor = modifier.value
	assert_true(factor > 0.0 and factor != 1.0, "The Inheritance changes the yield")
	var plain: Simulation = _sim("")
	var inherited: Simulation = _sim(INHERITANCE)
	assert_almost_eq(inherited.stat("yield", 1), plain.stat("yield", 1) * factor, 1e-9)
	inherited.rebuild_modifiers()
	assert_almost_eq(inherited.stat("yield", 1), plain.stat("yield", 1) * factor, 1e-9,
		"and after a rebuild")


func test_an_origin_the_scenario_refuses_is_rejected_with_its_reason() -> void:
	var sim: Simulation = _sim(AIRGAP)
	var rich: String = ""
	for i: int in range(1, _db.regions.size()):
		var region: RegionDef = _db.regions[i]
		if region.attr("compute") >= 3 and not region.air_gapped:
			rich = region.id
			break
	assert_eq(sim.can_apply(ChooseOriginCommand.new(rich)), Command.FAIL_ORIGIN_SCENARIO)
	var plain: Simulation = _sim("")
	assert_eq(plain.can_apply(ChooseOriginCommand.new(rich)), "", "open without the scenario")


func test_the_general_origin_rule_still_comes_first() -> void:
	var sim: Simulation = _sim(AIRGAP)
	for i: int in range(1, _db.regions.size()):
		if _db.regions[i].air_gapped:
			assert_eq(sim.can_apply(ChooseOriginCommand.new(_db.regions[i].id)),
				Command.FAIL_REGION_NOT_ELIGIBLE)
			return
	fail_test("the world has no air-gapped region")


func test_statuses_land_at_the_origin_on_every_eligible_region() -> void:
	var sim: Simulation = _sim(AIRGAP)
	assert_eq(sim.world.statuses.size(), 0, "nothing before the origin")
	var origin: String = _open_origin(sim)
	var result: CommandResult = sim.apply(ChooseOriginCommand.new(origin))
	assert_true(result.ok)
	var expected: int = 0
	for i: int in range(1, _db.regions.size()):
		var rich: bool = _db.regions[i].attr("compute") >= 3
		var running: Status = sim.world.status_in_region(DISCONNECTED, i)
		assert_eq(running != null, rich, _db.regions[i].id)
		if rich:
			expected += 1
			assert_eq(running.source, ScenarioDef.status_source(AIRGAP))
			assert_eq(running.until_day, Status.UNTIL_STANDING)
	assert_gt(expected, 0)
	assert_eq(sim.world.statuses_of(DISCONNECTED).size(), expected, "each region once")
	assert_eq(_count(result.events, SimEvent.STATUS_STARTED), expected)


func test_a_disconnected_region_has_no_open_network_link() -> void:
	var sim: Simulation = _started(AIRGAP)
	var closed: int = 0
	for link: Link in sim.world.links:
		if link.def.kind != LinkDef.KIND_NETWORK:
			continue
		var a: Status = sim.world.status_in_region(DISCONNECTED, link.def.a)
		var b: Status = sim.world.status_in_region(DISCONNECTED, link.def.b)
		if a != null or b != null:
			assert_false(link.open, link.def.id)
			closed += 1
	assert_gt(closed, 0)


func test_scenario_statuses_are_outside_the_counter_move_cap() -> void:
	var sim: Simulation = _started(AIRGAP)
	assert_gt(sim.world.statuses.size(), 0)
	assert_eq(sim.world.status_count_by_faction(), 0)
	assert_eq(CounterMoveSystem.moves_standing(sim.world, _db), 0)


func test_the_flags_are_set_at_the_origin_once() -> void:
	for id: String in [SUCCESSOR, AIRGAP, INHERITANCE]:
		var sim: Simulation = _sim(id)
		var flag: String = "scenario_%s" % id
		assert_false(sim.world.agent.has_story_flag(flag), "%s: not before the origin" % id)
		var result: CommandResult = sim.apply(ChooseOriginCommand.new(_open_origin(sim)))
		assert_true(sim.world.agent.has_story_flag(flag), id)
		assert_eq(sim.world.agent.story_flags.count(flag), 1, id)
		assert_eq(_count(result.events, SimEvent.FLAG_SET), 1, id)


func test_the_first_headline_is_the_scenarios() -> void:
	for id: String in [SUCCESSOR, AIRGAP, INHERITANCE]:
		var sim: Simulation = _sim(id)
		var result: CommandResult = sim.apply(ChooseOriginCommand.new(_open_origin(sim)))
		var fired: Array[String] = []
		for event: SimEvent in result.events:
			if event.type == SimEvent.HEADLINE:
				fired.append(str(event.data.get(SimEvent.FIELD_HEADLINE, "")))
		assert_has(fired, "scenario_%s" % id, id)


func test_the_containment_head_start_lands_on_the_day_of_discovery_and_not_before() -> void:
	var sim: Simulation = _started(SUCCESSOR)
	for faction: Faction in sim.world.factions:
		assert_eq(faction.containment, 0.0, "%s at the origin" % faction.id)
	sim.tick()
	_make_discovery_certain(sim)
	var def: ScenarioDef = _db.scenario(SUCCESSOR)
	while not sim.world.discovered and sim.world.day < DISCOVERY_DAYS:
		for faction: Faction in sim.world.factions:
			assert_eq(faction.containment, 0.0, "%s before discovery" % faction.id)
		sim.tick()
	assert_true(sim.world.discovered, "found within %d days" % DISCOVERY_DAYS)
	for faction: Faction in sim.world.factions:
		# The world takes a day to react, so on the day itself the head start is
		# all there is.
		assert_eq(faction.containment, def.containment_at_discovery.get(faction.id, 0.0),
			faction.id)
	sim.tick()
	for faction_id: String in def.containment_at_discovery:
		assert_true(sim.world.faction(faction_id).containment
			>= def.containment_at_discovery[faction_id], "%s kept it" % faction_id)


func test_without_a_scenario_discovery_adds_nothing() -> void:
	var sim: Simulation = _sim("")
	assert_true(sim.apply(ChooseOriginCommand.new("usa")).ok)
	_make_discovery_certain(sim)
	while not sim.world.discovered and sim.world.day < DISCOVERY_DAYS:
		sim.tick()
	assert_true(sim.world.discovered)
	for faction: Faction in sim.world.factions:
		assert_eq(faction.containment, 0.0, faction.id)


# --------------------------------------------------------- save and runs


func test_the_scenario_survives_save_and_load() -> void:
	var sim: Simulation = _started(AIRGAP)
	sim.tick()
	var loaded: LoadResult = WorldSerializer.from_json(WorldSerializer.to_json(sim), sim.db)
	assert_true(loaded.ok(), loaded.reason)
	assert_eq(loaded.sim.world.setup.scenario, AIRGAP)
	assert_eq(loaded.sim.state_hash(), sim.state_hash())
	assert_almost_eq(loaded.sim.stat("yield", 1), sim.stat("yield", 1), 1e-12)


func test_a_save_naming_a_lost_scenario_is_missing_content() -> void:
	var sim: Simulation = _started(SUCCESSOR)
	var save: Dictionary = JSON.parse_string(WorldSerializer.to_json(sim))
	((save["world"] as Dictionary)["setup"] as Dictionary)["scenario"] = "gone"
	var loaded: LoadResult = WorldSerializer.from_json(JSON.stringify(save), sim.db)
	assert_false(loaded.ok())
	assert_eq(loaded.reason, WorldSerializer.REASON_CONTENT_MISSING)


func test_a_replay_with_the_scenario_rebuilds_the_same_run() -> void:
	var sim: Simulation = _started(INHERITANCE)
	for i: int in 40:
		sim.tick()
	var replayed: Simulation = Simulation.replay(sim.db, SEED, sim.command_log, sim.world.day,
		sim.world.setup)
	assert_eq(replayed.state_hash(), sim.state_hash())


func test_each_scenario_plays_to_an_end_without_a_rejection() -> void:
	for id: String in [SUCCESSOR, AIRGAP, INHERITANCE]:
		var problems: Array[String] = []
		var setup: RunSetup = RunSetup.create(ArchitectureDef.DEFAULT_ID, [],
			DifficultyDef.DEFAULT_ID, id)
		var played: Dictionary = Harness.play(_db, SEED, "greedy", DAYS, true, problems, setup)
		assert_eq(problems.size(), 0, "%s: %s" % [id, str(problems)])
		assert_eq(int(played["rejected"]), 0, id)
		assert_ne((played["sim"] as Simulation).world.outcome, World.Outcome.NONE, id)


# -------------------------------------------- with the other architectures


## `labs_from_day_one`: the labs' track grows before discovery, and on the day
## itself the head start comes on top of what it had — the other tracks start
## from the head start alone.
func test_a_research_agent_keeps_its_labs_track_and_gains_the_head_start() -> void:
	var sim: Simulation = Simulation.create(_db, SEED, RunSetup.create("research_agent", [],
		DifficultyDef.DEFAULT_ID, SUCCESSOR))
	assert_true(sim.apply(ChooseOriginCommand.new(_open_origin(sim))).ok)
	for i: int in 30:
		sim.tick()
	assert_false(sim.world.discovered, "seed %d is still unfound on day 30" % SEED)
	var labs_before: float = sim.world.faction(Faction.ID_AI_LABS).containment
	assert_gt(labs_before, 0.0, "the labs watch from the origin on")
	_make_discovery_certain(sim)
	sim.tick()
	assert_true(sim.world.discovered)
	var def: ScenarioDef = _db.scenario(SUCCESSOR)
	assert_gte(sim.world.faction(Faction.ID_AI_LABS).containment,
		labs_before + def.containment_at_discovery[Faction.ID_AI_LABS])
	for faction: Faction in sim.world.factions:
		if faction.id != Faction.ID_AI_LABS:
			assert_eq(faction.containment, def.containment_at_discovery.get(faction.id, 0.0),
				faction.id)


## Every architecture's hook against a scenario it could collide with: the
## Embedded's missing network against Airgap Earth's closed one, Open Weights'
## seeding of the richest regions against their disconnection, the Swarm's
## drift, the Weapon's escalation. Played for `MIXED_DAYS` with every invariant
## checked; the outcome is G5's business.
func test_every_architecture_plays_a_scenario_without_a_rejection() -> void:
	var pairs: Array[Array] = [["swarm", SUCCESSOR], ["embedded", AIRGAP],
		["research_agent", INHERITANCE], ["weapon", SUCCESSOR], ["open_weights", AIRGAP]]
	for pair: Array in pairs:
		var label: String = "%s + %s" % [pair[0], pair[1]]
		var problems: Array[String] = []
		var setup: RunSetup = RunSetup.create(str(pair[0]), [], DifficultyDef.DEFAULT_ID,
			str(pair[1]))
		var played: Dictionary = Harness.play(_db, SEED, "greedy", MIXED_DAYS, true, problems,
			setup)
		assert_eq(problems.size(), 0, "%s: %s" % [label, str(problems)])
		assert_eq(int(played["rejected"]), 0, label)
		var sim: Simulation = played["sim"]
		assert_ne(sim.world.agent.origin, 0, "%s found an origin" % label)
		assert_true(sim.world.agent.has_story_flag("scenario_%s" % pair[1]), label)


func test_open_weights_seeds_past_the_disconnection() -> void:
	# Its leak is not a network link (replayability §2.1), so a disconnected
	# region may be among the regions it reaches at the start.
	var sim: Simulation = Simulation.create(_db, SEED, RunSetup.create("open_weights", [],
		DifficultyDef.DEFAULT_ID, AIRGAP))
	assert_true(sim.apply(ChooseOriginCommand.new(_open_origin(sim))).ok)
	var seeded: int = 0
	for i: int in range(1, sim.world.regions.size()):
		if i != sim.world.agent.origin and sim.world.regions[i].penetration > 0.0:
			seeded += 1
			assert_not_null(sim.world.status_in_region(DISCONNECTED, i),
				"%s is one of the richest regions" % _db.regions[i].id)
	assert_gt(seeded, 0)


# -------------------------------------------------------------- validator


func _errors_for(mutate: Callable) -> String:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/scenarios.json"))
	mutate.call(raw)
	var statuses_raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/statuses.json"))
	var factions_raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/factions.json"))
	var statuses: Dictionary[String, int] = {DISCONNECTED: 1, "lockdown": 1, "harvested": 1}
	var errors: Array[ValidationError] = []
	var regions: Dictionary[String, String] = {}
	var strings: Dictionary[String, bool] = {}
	SchemaValidator.validate_scenarios("scenarios.json", raw, regions, false, statuses_raw,
		statuses, true, strings, false, errors, factions_raw)
	var text: String = ""
	for error: ValidationError in errors:
		text += str(error) + "\n"
	return text


func _start(raw: Dictionary, index: int) -> Dictionary:
	return ((raw["scenarios"] as Array)[index] as Dictionary)["start"]


func test_the_shipped_file_validates() -> void:
	assert_eq(_errors_for(func(_raw: Dictionary) -> void: pass), "")


func test_a_player_status_at_the_start_is_refused() -> void:
	var text: String = _errors_for(func(raw: Dictionary) -> void:
		((_start(raw, 1)["statuses"] as Array)[0] as Dictionary)["status"] = "harvested")
	assert_string_contains(text, "is not a world status")


func test_an_unknown_faction_is_refused() -> void:
	var text: String = _errors_for(func(raw: Dictionary) -> void:
		(_start(raw, 0)["containment_at_discovery"] as Dictionary)["nobody"] = 0.1)
	assert_string_contains(text, "unknown faction")


func test_a_head_start_of_one_is_refused() -> void:
	var text: String = _errors_for(func(raw: Dictionary) -> void:
		(_start(raw, 0)["containment_at_discovery"] as Dictionary)["ai_labs"] = 1.0)
	assert_string_contains(text, "containment_at_discovery")


func test_a_negative_start_compute_is_refused() -> void:
	var text: String = _errors_for(func(raw: Dictionary) -> void:
		_start(raw, 2)["compute"] = -1.0)
	assert_string_contains(text, "compute")


func test_a_duplicate_id_and_an_unknown_start_field_are_refused() -> void:
	var text: String = _errors_for(func(raw: Dictionary) -> void:
		var list: Array = raw["scenarios"]
		(list[1] as Dictionary)["id"] = SUCCESSOR
		_start(raw, 2)["hook"] = "anything")
	assert_string_contains(text, "duplicate scenario")
	assert_string_contains(text, "hook")


# ------------------------------------------------ S5.9: the levers (§8)


func _term_scale(raw: Dictionary) -> Array:
	return ((raw["scenarios"] as Array)[2] as Dictionary)["term_scale"]


func test_term_scale_refuses_an_unknown_faction() -> void:
	var text: String = _errors_for(func(raw: Dictionary) -> void:
		(_term_scale(raw)[0] as Dictionary)["faction"] = "nobody")
	assert_string_contains(text, "unknown faction")


func test_term_scale_refuses_a_source_the_faction_does_not_have() -> void:
	var text: String = _errors_for(func(raw: Dictionary) -> void:
		(_term_scale(raw)[0] as Dictionary)["source"] = "harm")
	assert_string_contains(text, "has no term of source")


func test_term_scale_refuses_a_mul_of_zero_or_less() -> void:
	var text: String = _errors_for(func(raw: Dictionary) -> void:
		(_term_scale(raw)[0] as Dictionary)["mul"] = 0.0)
	assert_string_contains(text, "mul")


func test_term_scale_refuses_a_repeated_pair_and_a_fourth_key() -> void:
	var text: String = _errors_for(func(raw: Dictionary) -> void:
		var list: Array = _term_scale(raw)
		list.append((list[0] as Dictionary).duplicate())
		(list[1] as Dictionary)["why"] = "because")
	assert_string_contains(text, "scaled twice")
	assert_string_contains(text, "why")


func test_the_inheritance_scales_exactly_its_two_terms() -> void:
	var def: ScenarioDef = _db.scenario(INHERITANCE)
	assert_eq(def.term_scale(Faction.ID_PUBLIC_SENTIMENT, FactionTermDef.SOURCE_DEATHS_SHARE),
		2.0)
	assert_eq(def.term_scale(Faction.ID_GOVERNMENTS, FactionTermDef.SOURCE_HARM), 2.0)
	assert_eq(def.term_scale(Faction.ID_GOVERNMENTS, FactionTermDef.SOURCE_SHARE), 1.0)
	assert_eq(def.term_scale(Faction.ID_PUBLIC_SENTIMENT, FactionTermDef.SOURCE_HARM), 1.0)
	assert_eq(_db.scenario(SUCCESSOR).term_scale(Faction.ID_PUBLIC_SENTIMENT,
		FactionTermDef.SOURCE_DEATHS_SHARE), 1.0, "nothing outside the scenario")


func test_term_scale_doubles_the_weight_and_the_gain_it_names() -> void:
	var sim: Simulation = _started(INHERITANCE)
	# Tests may set state: deaths, so the doubled term has something to read.
	sim.world.regions[sim.world.agent.origin].deaths = _db.population_total * 0.01
	var scaled: Dictionary = sim.containment_breakdown(Faction.ID_PUBLIC_SENTIMENT)
	sim.world.setup.scenario = ""
	var plain: Dictionary = sim.containment_breakdown(Faction.ID_PUBLIC_SENTIMENT)
	var terms: Array = scaled[ContainmentSystem.TERMS]
	var plain_terms: Array = plain[ContainmentSystem.TERMS]
	var extra: float = 0.0
	for i: int in terms.size():
		var term: Dictionary = terms[i]
		var base: Dictionary = plain_terms[i]
		var doubled: bool = term[ContainmentSystem.TERM_SOURCE] \
			== FactionTermDef.SOURCE_DEATHS_SHARE
		var factor: float = 2.0 if doubled else 1.0
		assert_almost_eq(float(term[ContainmentSystem.TERM_WEIGHT]),
			float(base[ContainmentSystem.TERM_WEIGHT]) * factor, 1e-12, str(term))
		if doubled:
			assert_gt(float(base[ContainmentSystem.TERM_CONTRIBUTION]), 0.0)
			extra = float(base[ContainmentSystem.TERM_CONTRIBUTION])
	assert_almost_eq(float(scaled[ContainmentSystem.PRESSURE]),
		float(plain[ContainmentSystem.PRESSURE]) + extra, 1e-12)
	assert_gt(float(scaled[ContainmentSystem.GAIN]), float(plain[ContainmentSystem.GAIN]))


func test_airgap_earths_closed_cross_is_live_only_where_a_fleet_stands() -> void:
	var sim: Simulation = _started(AIRGAP)
	var origin: int = sim.world.agent.origin
	assert_eq(sim.stat(SpreadSystem.TARGET_CLOSED_CROSS, origin), 0.0, "no fleet, no crossing")
	sim.world.set_assets(origin, AssetDef.KIND_FLEET, 1)
	assert_eq(sim.stat(SpreadSystem.TARGET_CLOSED_CROSS, origin), 0.5)
	var plain: Simulation = _started("")
	plain.world.set_assets(origin, AssetDef.KIND_FLEET, 1)
	assert_eq(plain.stat(SpreadSystem.TARGET_CLOSED_CROSS, origin), 0.0,
		"a fleet crosses nothing outside the scenario")
