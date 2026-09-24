extends GutTest
## S5.1 — architectures (`replayability.md` §1, §2, §8.1): the setup, its
## modifiers and start, the `no_network` and `labs_from_day_one` hooks, save v3
## and the replay header. Runs on the fixture world with architectures of its own.

const LABS: String = "ai_labs"


func _architectures() -> Dictionary:
	return {"version": 1, "architectures": [
		{"id": "language_model", "unlock": {},
			"modifiers": [{"target": "yield", "op": "mul", "value": 1.5}]},
		{"id": "fx_embedded", "unlock": {"runs_completed": 2},
			"start": {"owned": ["fx_fleet"], "assets": {"lab": 1},
				"effects": [{"effect": "compute_grant", "value": 3.0}]},
			"hook": "no_network"},
		{"id": "fx_research", "unlock": {"wins": 1}, "hook": "labs_from_day_one"},
		{"id": "fx_zapper", "abilities": ["fx_zap"]},
	]}


func _db(architectures: Dictionary = _architectures()) -> ContentDB:
	var content: Dictionary = Fixtures.raw_content()
	content["architectures"] = architectures
	var result: ContentLoadResult = Fixtures.load_raw(content)
	assert_true(result.ok(), result.error_text())
	return result.db


func _errors(architectures: Dictionary) -> String:
	var content: Dictionary = Fixtures.raw_content()
	content["architectures"] = architectures
	return Fixtures.load_raw(content).error_text()


func _sim(architecture: String, origin: String = "fx_alder") -> Simulation:
	var sim: Simulation = Simulation.create(_db(), 1, RunSetup.create(architecture))
	var result: CommandResult = sim.apply(ChooseOriginCommand.new(origin))
	assert_true(result.ok, result.reason)
	return sim


## Nobody finds the agent: the discovery factor is 0, so the scrutiny term is too.
func _unfindable(sim: Simulation) -> void:
	var zero: ModifierDef = ModifierDef.new()
	zero.target = "discovery"
	zero.op = ModifierDef.Op.MUL
	zero.value = 0.0
	var no_flags: Array[String] = []
	sim.world.modifiers.add_source("test:unfindable", [zero] as Array[ModifierDef], no_flags)


# ------------------------------------------------------------------- content


func test_a_root_without_the_file_plays_the_default_architecture() -> void:
	var db: ContentDB = Fixtures.db()
	assert_eq(db.architectures.size(), 1)
	assert_eq(db.architectures[0].id, ArchitectureDef.DEFAULT_ID)
	assert_true(db.architectures[0].modifiers.is_empty())


func test_the_file_is_loaded_in_order() -> void:
	var db: ContentDB = _db()
	assert_eq(db.architectures.size(), 4)
	var embedded: ArchitectureDef = db.architecture("fx_embedded")
	assert_eq(embedded.hook, ArchitectureDef.HOOK_NO_NETWORK)
	assert_eq(embedded.start_owned, ["fx_fleet"] as Array[String])
	assert_eq(embedded.start_assets["lab"], 1)
	assert_eq(embedded.start_effects.size(), 1)


func test_a_file_without_the_default_architecture_is_refused() -> void:
	var file: Dictionary = _architectures()
	(file["architectures"] as Array).remove_at(0)
	assert_string_contains(_errors(file), "missing the default architecture")


func test_an_unknown_hook_is_refused() -> void:
	var file: Dictionary = _architectures()
	((file["architectures"] as Array)[2] as Dictionary)["hook"] = "teleport"
	assert_string_contains(_errors(file), "unknown hook")


func test_an_unknown_start_node_is_refused() -> void:
	var file: Dictionary = _architectures()
	(((file["architectures"] as Array)[1] as Dictionary)["start"] as Dictionary)["owned"] = [
		"fx_nothing"]
	assert_string_contains(_errors(file), "unknown node")


func test_two_unlock_rules_are_refused() -> void:
	var file: Dictionary = _architectures()
	((file["architectures"] as Array)[2] as Dictionary)["unlock"] = {"wins": 1,
		"runs_completed": 2}
	assert_string_contains(_errors(file), "at most one unlock rule")


func test_an_unknown_ability_is_refused() -> void:
	var file: Dictionary = _architectures()
	((file["architectures"] as Array)[3] as Dictionary)["abilities"] = ["fx_nothing"]
	assert_string_contains(_errors(file), "unknown ability")


# --------------------------------------------------------------------- setup


func test_an_unknown_architecture_cannot_start() -> void:
	var sim: Simulation = Simulation.create(_db(), 1, RunSetup.create("fx_nothing"))
	var result: CommandResult = sim.apply(ChooseOriginCommand.new("fx_alder"))
	assert_false(result.ok)
	assert_eq(result.reason, Command.FAIL_SETUP_INVALID)


func test_the_architecture_modifiers_are_active_from_the_start() -> void:
	var sim: Simulation = Simulation.create(_db(), 1)
	assert_almost_eq(sim.stat("yield", 1), 1.5, 1e-9, "the default's own yield ×1.5")
	sim.rebuild_modifiers()
	assert_almost_eq(sim.stat("yield", 1), 1.5, 1e-9, "and again after a rebuild")


func test_the_start_owns_its_nodes_places_its_assets_and_runs_its_effects() -> void:
	var sim: Simulation = Simulation.create(_db(), 1, RunSetup.create("fx_embedded"))
	var compute_before: float = sim.world.agent.compute
	var result: CommandResult = sim.apply(ChooseOriginCommand.new("fx_alder"))
	assert_true(result.ok)
	assert_true(sim.world.agent.owns("fx_fleet"), "owned as if bought")
	var origin: Region = sim.world.regions[sim.world.agent.origin]
	assert_eq(origin.asset_count("fleet"), 1, "the node deployed into the origin")
	assert_eq(origin.asset_count("lab"), 1, "the start's own asset")
	assert_almost_eq(sim.world.agent.compute, compute_before + 3.0, 1e-9,
		"nothing paid, the grant received")
	var bought: Array[SimEvent] = result.events.filter(func(e: SimEvent) -> bool:
		return e.type == SimEvent.NODE_PURCHASED)
	assert_eq(bought.size(), 1)
	assert_eq(float(bought[0].data["cost"]), 0.0)


func test_an_architecture_ability_is_there_without_its_node() -> void:
	var sim: Simulation = _sim("fx_zapper")
	assert_false(sim.world.agent.owns("fx_zap_1"))
	assert_eq(sim.ability_level("fx_zap"), 1)
	assert_eq(_sim("language_model").ability_level("fx_zap"), 0)


# --------------------------------------------------------------------- hooks


func test_no_network_keeps_network_links_from_carrying_the_agent() -> void:
	var sim: Simulation = _sim("fx_embedded")
	assert_false(SpreadSystem.carries(sim.world, sim.db, LinkDef.KIND_NETWORK))
	assert_true(SpreadSystem.carries(sim.world, sim.db, LinkDef.KIND_LAND))
	assert_true(SpreadSystem.carries(_sim("language_model").world, sim.db, LinkDef.KIND_NETWORK),
		"every other architecture is carried")


func test_network_presence_lets_the_network_carry_it_again() -> void:
	var sim: Simulation = _sim("fx_embedded")
	var none: Array[ModifierDef] = []
	var flags: Array[String] = [ModifierDef.FLAG_NETWORK_PRESENCE]
	sim.world.modifiers.add_source("test:presence", none, flags)
	assert_true(SpreadSystem.carries(sim.world, sim.db, LinkDef.KIND_NETWORK))


func test_seeding_a_neighbour_skips_the_network_link_under_no_network() -> void:
	# fx_alder reaches fx_birch by land, fx_dogwood by network and fx_elm by air.
	var effect: EffectDef = EffectDef.from_dict({"effect": "seed_neighbours", "count": 3})
	var context: EffectContext = EffectContext.new()
	var sim: Simulation = _sim("fx_embedded")
	context.region = sim.world.agent.origin
	var events: Array[SimEvent] = []
	EffectRunner.apply_all(sim, [effect] as Array[EffectDef], context, events)
	var dogwood: int = sim.db.region_index_by_id["fx_dogwood"]
	assert_eq(sim.world.regions[dogwood].penetration, 0.0)
	assert_gt(sim.world.regions[sim.db.region_index_by_id["fx_birch"]].penetration, 0.0)


func test_the_labs_hunt_a_research_agent_before_discovery() -> void:
	var sim: Simulation = _sim("fx_research")
	_unfindable(sim)
	for i: int in 30:
		sim.tick()
	assert_false(sim.world.discovered)
	assert_gt(sim.world.faction(LABS).containment, 0.0, "the labs knew from day one")
	for faction: Faction in sim.world.factions:
		if faction.id != LABS:
			assert_eq(faction.containment, 0.0, faction.id)


func test_nobody_else_is_hunted_before_discovery() -> void:
	var sim: Simulation = _sim("language_model")
	_unfindable(sim)
	for i: int in 30:
		sim.tick()
	assert_eq(sim.world.faction(LABS).containment, 0.0)


func test_a_rollback_and_a_funding_reset_leave_the_labs_alone() -> void:
	var sim: Simulation = _sim("fx_research")
	for faction: Faction in sim.world.factions:
		faction.containment = 0.4
	sim.world.faction(LABS).preparing = "cm_audit"
	var context: EffectContext = EffectContext.new()
	var events: Array[SimEvent] = []
	var effects: Array[EffectDef] = [
		EffectDef.from_dict({"effect": "containment_rollback", "value": 0.5}),
		EffectDef.from_dict({"effect": "funding_reset", "value": 0.5}),
	]
	EffectRunner.apply_all(sim, effects, context, events)
	assert_eq(sim.world.faction(LABS).containment, 0.4)
	assert_eq(sim.world.faction(LABS).preparing, "cm_audit")
	assert_almost_eq(sim.world.faction("governments").containment, 0.2, 1e-9)


func test_the_global_brake_does_not_reach_the_labs_of_a_research_agent() -> void:
	var sim: Simulation = _sim("fx_research")
	var slow: ModifierDef = ModifierDef.new()
	slow.target = "containment_growth"
	slow.op = ModifierDef.Op.MUL
	slow.value = 0.5
	var no_flags: Array[String] = []
	var before: float = float(sim.containment_breakdown(LABS)[ContainmentSystem.BRAKES])
	sim.world.modifiers.add_source("test:pause", [slow] as Array[ModifierDef], no_flags)
	assert_eq(float(sim.containment_breakdown(LABS)[ContainmentSystem.BRAKES]), before)


# ------------------------------------------------------------ save and replay


func test_the_setup_survives_save_and_load() -> void:
	var sim: Simulation = _sim("fx_research")
	sim.tick()
	var loaded: LoadResult = WorldSerializer.from_json(WorldSerializer.to_json(sim), sim.db)
	assert_true(loaded.ok(), loaded.reason)
	assert_eq(loaded.sim.world.setup.architecture, "fx_research")
	assert_eq(loaded.sim.state_hash(), sim.state_hash())


func test_a_v2_save_loads_as_the_default_architecture() -> void:
	var sim: Simulation = _sim("language_model")
	var save: Dictionary = JSON.parse_string(WorldSerializer.to_json(sim))
	save["version"] = 2
	(save["world"] as Dictionary).erase("setup")
	var loaded: LoadResult = WorldSerializer.from_json(JSON.stringify(save), sim.db)
	assert_true(loaded.ok(), loaded.reason)
	assert_eq(loaded.sim.world.setup.architecture, ArchitectureDef.DEFAULT_ID)


func test_a_replay_with_the_setup_rebuilds_the_same_run() -> void:
	var sim: Simulation = _sim("fx_embedded")
	for i: int in 40:
		sim.tick()
	var replayed: Simulation = Simulation.replay(sim.db, 1, sim.command_log, sim.world.day,
		sim.world.setup)
	assert_eq(replayed.state_hash(), sim.state_hash())
