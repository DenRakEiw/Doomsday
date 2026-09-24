extends GutTest
## S4.10 — the second generation of bots on the shipped content (loop-redesign
## §9): one per strategy, placing assets, using abilities, answering events by
## weights. The tests assert how each one plays, not how it ends: the outcome is
## G4's business.

const Harness := preload("res://tools/sim_harness.gd")
const WORLD_ROOT: String = "res://data"
const SEED: int = 1
const DAYS: int = 5000
## Enough to buy anything, for the tests that arrange a situation by hand.
const PLENTY: float = 10000.0
const STRATEGIES: Array[String] = ["cyber", "biology", "robotics", "weapons", "persuasion"]
## An opening that offers compute for footprint, a seed for a price, or nothing.
const CLUSTER: String = "opening_unattended_cluster"

static var _db: ContentDB = null
static var _runs: Dictionary[String, Dictionary] = {}


func before_all() -> void:
	if _db == null:
		var result: ContentLoadResult = ContentLoader.load_root(WORLD_ROOT)
		assert_true(result.ok(), result.error_text())
		_db = result.db


## A bot's run on the shipped world, played once with the invariants checked.
func _run(policy_id: String) -> Dictionary:
	if not _runs.has(policy_id):
		var problems: Array[String] = []
		var played: Dictionary = Harness.play(_db, SEED, policy_id, DAYS, true, problems)
		assert_eq(problems.size(), 0, str(problems))
		_runs[policy_id] = played
	return _runs[policy_id]


func _sim_with_origin(region_id: String = "usa") -> Simulation:
	var sim: Simulation = Simulation.create(_db, SEED)
	assert_true(sim.apply(ChooseOriginCommand.new(region_id)).ok)
	return sim


## Opens `def_id` in the origin at the next tick and answers the open event.
func _open(sim: Simulation, def_id: String) -> OpenEvent:
	EventSystem.schedule(sim.world, def_id, sim.world.agent.origin, "", sim.world.day + 1, 1)
	sim.tick()
	for event: OpenEvent in sim.world.events:
		if event.def == def_id:
			return event
	return null


func test_every_strategy_plays_the_shipped_world_to_an_end_without_a_rejection() -> void:
	for policy_id: String in STRATEGIES:
		var played: Dictionary = _run(policy_id)
		var sim: Simulation = played["sim"]
		assert_eq(played["rejected"], 0, "%s asked for something it could not have" % policy_id)
		assert_ne(sim.world.outcome, World.Outcome.NONE, "%s did not finish" % policy_id)


func test_every_strategy_answers_events_and_most_use_abilities() -> void:
	var users: int = 0
	for policy_id: String in STRATEGIES:
		var stats: Dictionary = _run(policy_id)["stats"]
		var answered: int = int(stats["events_opening"]) + int(stats["events_counter_move"]) \
			+ int(stats["events_chain"])
		assert_gt(answered, 0, "%s answered nothing" % policy_id)
		if int(stats["abilities_used"]) > 0:
			users += 1
	assert_gte(users, 4, "the loop's verbs are what the second generation is for")


func test_a_strategy_owns_its_branch_first_node() -> void:
	var firsts: Dictionary[String, String] = {
		"cyber": "market_microstructure", "biology": "structure_prediction",
		"robotics": "logistics_fleets", "weapons": "early_warning_intrusion",
		"persuasion": "sycophancy_tuning",
	}
	for policy_id: String in firsts:
		var sim: Simulation = _run(policy_id)["sim"]
		assert_true(sim.world.agent.owns(firsts[policy_id]), "%s never opened its branch"
			% policy_id)


func test_the_robotics_bot_puts_fleets_on_the_map() -> void:
	assert_gt(int(_run("robotics")["stats"]["assets_deployed"]), 0)


func test_the_origin_follows_the_strategy_s_attributes() -> void:
	var sim: Simulation = Simulation.create(_db, SEED)
	var robotics: RoboticsPolicy = RoboticsPolicy.new()
	robotics.setup(_db, 1)
	var command: ChooseOriginCommand = robotics.next_command(sim) as ChooseOriginCommand
	assert_not_null(command)
	var chosen: RegionDef = _db.regions[_db.region_index_by_id[command.region]]
	for i: int in range(1, _db.regions.size()):
		if sim.can_apply(ChooseOriginCommand.new(_db.regions[i].id)).is_empty():
			assert_lte(_db.regions[i].attr("industry"), chosen.attr("industry"),
				"%s has more industry" % _db.regions[i].id)


func test_weights_decide_an_option_and_no_weights_take_the_default() -> void:
	var sim: Simulation = _sim_with_origin()
	var event: OpenEvent = _open(sim, CLUSTER)
	assert_not_null(event, "the opening opened")
	var def: EventDef = _db.event(CLUSTER)
	var greedy: GreedyPolicy = GreedyPolicy.new()
	assert_eq(greedy.answer_event(sim, event, def), "take", "greedy takes the compute")
	assert_eq(IdlePolicy.new().answer_event(sim, event, def), def.default_option)


func test_the_answer_is_always_an_option_the_command_accepts() -> void:
	var sim: Simulation = _sim_with_origin()
	var event: OpenEvent = _open(sim, CLUSTER)
	sim.world.agent.compute = 0.0
	# `seed` costs compute: with none, it is not an answer, whatever it is worth.
	for policy_id: String in STRATEGIES:
		var policy: Policy = Policy.create(policy_id)
		var option: String = policy.answer_event(sim, event, _db.event(CLUSTER))
		assert_eq(sim.can_apply(ChooseEventOptionCommand.new(event.id, option)), "", policy_id)


func test_a_path_node_short_only_of_compute_is_saved_for() -> void:
	var sim: Simulation = _sim_with_origin()
	var cyber: CyberPolicy = CyberPolicy.new()
	# Two vectors and the first Cyber node: the next path node is a Tier 1 one.
	sim.world.agent.compute = PLENTY
	for node_id: String in ["cloud_federation", "open_weights_leak"]:
		assert_true(sim.apply(PurchaseNodeCommand.new(node_id)).ok, node_id)
	sim.world.agent.compute = 0.0
	assert_gt(cyber.saving_for(sim), 0.0, "it waits for the path")
	sim.world.agent.compute = PLENTY
	assert_eq(cyber.saving_for(sim), 0.0, "and stops waiting once it can pay")


func test_harvest_waits_for_enough_regions() -> void:
	var sim: Simulation = _sim_with_origin()
	sim.world.agent.owned_nodes.append("edge_caching")
	sim.rebuild_modifiers()
	assert_eq(sim.ability_level(Policy.HARVEST), 1, "set up")
	var greedy: GreedyPolicy = GreedyPolicy.new()
	var command: Command = greedy._use_ability(sim, [Policy.HARVEST] as Array[String], 0.0)
	assert_null(command, "one region seeded: harvesting it would starve the run")


func test_lobby_goes_only_where_a_counter_move_stands() -> void:
	var sim: Simulation = _sim_with_origin()
	var persuasion: PersuasionPolicy = PersuasionPolicy.new()
	var lobby: AbilityDef = _db.ability("lobby")
	sim.world.agent.compute = PLENTY
	if sim.ability_level("lobby") == 0:
		sim.world.agent.owned_nodes.append(lobby.levels_from[0])
		sim.rebuild_modifiers()
	var office: String = "usa"
	sim.world.set_assets(sim.world.agent.origin, AssetDef.KIND_OFFICE, 1)
	assert_null(persuasion._ability_command(sim, lobby), "nothing to lobby against")
	StatusSystem.apply(sim.world, _db, "lockdown", sim.world.agent.origin, "faction:governments",
		1, "", [] as Array[SimEvent])
	var command: UseAbilityCommand = persuasion._ability_command(sim, lobby) as UseAbilityCommand
	assert_not_null(command, "a lockdown in an office region")
	assert_eq(command.region, office)


func test_the_report_counts_the_loop() -> void:
	var played: Dictionary = _run("greedy")
	var summary: Dictionary = Harness.summarise(played["sim"], SEED, "greedy", DAYS,
		int(played["rejected"]), played["headlines"], played["stats"])
	for field: String in Harness.STAT_FIELDS:
		assert_true(summary.has(field), field)
	assert_gt(int(summary["abilities_used"]), 0, "greedy uses every ability it has")


## S4.10's first 500-seed report: Biology stopped at two nodes of its branch,
## because the lab needs one of two nodes its path never named. A path must
## carry everything its nodes need, or the strategy stalls where it matters.
func test_every_path_carries_what_its_nodes_need() -> void:
	for policy_id: String in STRATEGIES:
		var policy: StrategyPolicy = Policy.create(policy_id) as StrategyPolicy
		for node_id: String in policy.path:
			var node: TechNodeDef = _db.tech(node_id)
			assert_not_null(node, "%s: %s is not a node" % [policy_id, node_id])
			if node == null:
				continue
			for needed: String in node.requires:
				assert_true(policy.path.has(needed), "%s: %s needs %s"
					% [policy_id, node_id, needed])
			if node.requires_any.is_empty():
				continue
			var met: bool = false
			for option: String in node.requires_any:
				met = met or policy.path.has(option)
			assert_true(met, "%s: %s needs one of %s" % [policy_id, node_id, node.requires_any])
