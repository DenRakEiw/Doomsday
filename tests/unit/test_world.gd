extends GutTest
## S1.2 — the world model: what `create` builds, what `to_dict` writes, what
## `from_dict` refuses, and what `check_invariants` catches.

var db: ContentDB


func before_each() -> void:
	db = Fixtures.db()


func _world() -> World:
	return World.create(db, 1)


func test_create_builds_one_state_object_per_definition() -> void:
	var world: World = _world()
	assert_eq(world.regions.size(), db.regions.size())
	assert_null(world.regions[0], "index 0 stays \"no region\"")
	assert_eq(world.links.size(), db.links.size())
	assert_eq(world.factions.size(), 4, "one containment track per faction")
	for i: int in Faction.FACTION_IDS.size():
		assert_eq(world.factions[i].id, Faction.FACTION_IDS[i], "in FACTION_IDS order")
	assert_eq(world.day, 0)
	assert_eq(world.phase, World.Phase.BOXED)
	assert_eq(world.outcome, World.Outcome.NONE)
	assert_almost_eq(world.agent.compute, db.balance.compute_start, 1e-9)
	assert_eq(world.agent.origin, 0, "no origin before one is chosen")


func test_regions_start_full_and_clean() -> void:
	var world: World = _world()
	for i: int in range(1, world.regions.size()):
		var region: Region = world.regions[i]
		assert_eq(region.penetration, 0.0)
		assert_eq(region.alive, float(region.def.population))
		assert_eq(region.seeded_day, -1)
		assert_false(region.dark)
	assert_true(world.regions[6].air_gapped, "fx_fir carries its definition's air gap")


## S3.P, from G3: half the Harm nodes are scoped, and the HUD reads the
## maximum over the regions instead of the unscoped stat (m3-screens §6.1).
func test_max_harm_reads_the_highest_region_and_not_the_unscoped_stat() -> void:
	var world: World = _world()
	assert_eq(world.max_harm(), 0.0, "nothing owned, nothing harmed")
	var scoped: ModifierDef = ModifierDef.new()
	scoped.target = "harm"
	scoped.op = ModifierDef.Op.ADD
	scoped.value = 2.0
	scoped.scope_kind = ModifierDef.ScopeKind.REGION
	scoped.scope_region = 1
	var modifiers: Array[ModifierDef] = [scoped]
	var no_flags: Array[String] = []
	world.modifiers.add_source("test_scoped_harm", modifiers, no_flags)
	assert_eq(world.modifiers.value("harm"), 0.0, "the unscoped stat sees none of it")
	assert_almost_eq(world.max_harm(), 2.0, 1e-9, "the region that carries it wins")


func test_links_start_open() -> void:
	var world: World = _world()
	for link: Link in world.links:
		assert_true(link.open)


func test_the_queries_read_the_world_one_way() -> void:
	var world: World = _world()
	assert_eq(world.seeded_count(), 0)
	assert_eq(world.infected_share(db), 0.0)
	assert_almost_eq(world.alive_total(), db.population_total, 1.0)
	assert_eq(world.deaths_total(), 0.0)
	assert_null(world.anomaly_in_region(1))

	world.regions[1].penetration = 1.0
	world.regions[1].seeded_day = 3
	assert_eq(world.seeded_count(), 1)
	# fx_alder is compute tier 4, weight 7 of the fixture's total 7+2+1+4+1+4.
	assert_almost_eq(world.infected_share(db), 7.0 / 19.0, 1e-9)


func test_a_dark_region_leaves_the_share() -> void:
	var world: World = _world()
	world.regions[1].penetration = 1.0
	var before: float = world.infected_share(db)
	world.regions[3].dark = true
	assert_gt(world.infected_share(db), before, "the hardware that is gone no longer counts")


func test_a_round_trip_through_a_dictionary_keeps_the_hash() -> void:
	var world: World = _world()
	world.day = 120
	world.origin_day = 0
	world.agent.origin = 1
	world.agent.compute = 3.5
	world.agent.owned_nodes.append("fx_vector_net")
	world.regions[2].penetration = 0.91
	world.regions[2].seeded_day = 4
	world.links[0].open = false
	world.factions[0].containment = 0.25
	world.milestones_fired.append("regions_2")
	var anomaly: Anomaly = Anomaly.new()
	anomaly.id = 3
	anomaly.region = 1
	anomaly.value = 3.0
	anomaly.spawn_day = 110
	anomaly.expires_day = 130
	world.anomalies.append(anomaly)
	world.rng.randf()

	var restored: World = World.from_dict(world.to_dict(), db)
	assert_not_null(restored, "the world it just wrote must load")
	assert_eq(restored.state_hash(), world.state_hash())
	assert_eq(restored.agent.origin, 1)
	assert_false(restored.links[0].open, "a closed link stays closed")
	assert_eq(restored.anomalies[0].region, 1)


func test_the_written_form_names_regions_by_id() -> void:
	var world: World = _world()
	world.agent.origin = 1
	var d: Dictionary = world.to_dict()
	var agent: Dictionary = d["agent"]
	assert_eq(agent["origin"], "fx_alder")
	var regions: Array = d["regions"]
	var first: Dictionary = regions[0]
	assert_eq(first["id"], "fx_alder")
	assert_eq(regions.size(), Fixtures.REGION_COUNT)


func test_the_rng_is_written_as_strings() -> void:
	var world: World = _world()
	var d: Dictionary = world.to_dict()
	var rng: Dictionary = d["rng"]
	assert_eq(typeof(rng["seed"]), TYPE_STRING, "a JSON number would lose the low bits")
	assert_eq(typeof(rng["state"]), TYPE_STRING)


func test_from_dict_refuses_a_missing_field() -> void:
	var d: Dictionary = _world().to_dict()
	d.erase("day")
	assert_null(World.from_dict(d, db))


func test_from_dict_refuses_a_field_of_the_wrong_type() -> void:
	var d: Dictionary = _world().to_dict()
	d["day"] = "tomorrow"
	assert_null(World.from_dict(d, db))


func test_from_dict_refuses_an_unknown_phase() -> void:
	var d: Dictionary = _world().to_dict()
	d["phase"] = "dormant"
	assert_null(World.from_dict(d, db))


func test_from_dict_refuses_a_region_list_that_is_not_the_content() -> void:
	var short: Dictionary = _world().to_dict()
	var regions: Array = short["regions"]
	regions.remove_at(0)
	assert_null(World.from_dict(short, db), "too few regions")

	var renamed: Dictionary = _world().to_dict()
	var list: Array = renamed["regions"]
	var first: Dictionary = list[0]
	first["id"] = "fx_ghost"
	assert_null(World.from_dict(renamed, db), "a region the content does not have")

	var reordered: Dictionary = _world().to_dict()
	var entries: Array = reordered["regions"]
	entries.reverse()
	assert_null(World.from_dict(reordered, db), "the content's order is part of the match")


func test_from_dict_refuses_an_unknown_closed_link() -> void:
	var d: Dictionary = _world().to_dict()
	d["closed_links"] = ["fx_alder|fx_ghost|land"]
	assert_null(World.from_dict(d, db))


func test_from_dict_refuses_an_unknown_origin() -> void:
	var d: Dictionary = _world().to_dict()
	var agent: Dictionary = d["agent"]
	agent["origin"] = "fx_ghost"
	assert_null(World.from_dict(d, db))


func test_from_dict_keeps_an_owned_node_the_content_lost() -> void:
	# Missing content is not a corrupt file: the save reader of S1.8 reports it
	# as content, which is why from_dict must not choke on it.
	var d: Dictionary = _world().to_dict()
	var agent: Dictionary = d["agent"]
	agent["owned_nodes"] = ["fx_from_an_older_build"]
	var restored: World = World.from_dict(d, db)
	assert_not_null(restored)
	assert_eq(restored.agent.owned_nodes[0], "fx_from_an_older_build")


func test_invariants_are_empty_for_a_fresh_world() -> void:
	var world: World = _world()
	var problems: Array[String] = world.check_invariants(db)
	assert_eq(problems.size(), 0, str(problems))


func test_invariants_report_penetration_out_of_range() -> void:
	var world: World = _world()
	world.regions[1].penetration = 1.5
	assert_string_contains(str(world.check_invariants()), "penetration")


func test_invariants_report_lost_people() -> void:
	var world: World = _world()
	world.regions[1].alive -= 1000.0
	assert_string_contains(str(world.check_invariants()), "alive + deaths")


func test_invariants_report_a_dark_region_that_is_not_empty() -> void:
	var world: World = _world()
	world.regions[1].dark = true
	assert_string_contains(str(world.check_invariants()), "dark but not empty")


func test_invariants_report_two_anomalies_in_one_region() -> void:
	var world: World = _world()
	for i: int in 2:
		var anomaly: Anomaly = Anomaly.new()
		anomaly.id = i + 1
		anomaly.region = 2
		world.anomalies.append(anomaly)
	assert_string_contains(str(world.check_invariants()), "two anomalies")


func test_invariants_report_too_many_anomalies() -> void:
	var world: World = _world()
	for i: int in db.balance.anomaly_max_active + 1:
		var anomaly: Anomaly = Anomaly.new()
		anomaly.id = i + 1
		anomaly.region = i + 1
		world.anomalies.append(anomaly)
	assert_string_contains(str(world.check_invariants(db)), "more than")


func test_invariants_report_an_owned_node_the_content_does_not_have() -> void:
	var world: World = _world()
	world.agent.owned_nodes.append("fx_ghost")
	assert_string_contains(str(world.check_invariants(db)), "unknown to the content")


func test_invariants_report_discovery_without_a_day() -> void:
	var world: World = _world()
	world.discovered = true
	assert_string_contains(str(world.check_invariants()), "discovery day")


func test_invariants_report_a_phase_that_lags_behind() -> void:
	var world: World = _world()
	world.discovered = true
	world.discovery_day = 10
	assert_string_contains(str(world.check_invariants(db)), "phase is boxed")

# ------------------------------------------------- S4.1: assets on the map


func test_set_assets_writes_the_region_and_the_stack() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	sim.world.set_assets(1, AssetDef.KIND_FLEET, 2)
	assert_eq(sim.world.regions[1].asset_count(AssetDef.KIND_FLEET), 2)
	assert_eq(sim.world.modifiers.asset_count(1, AssetDef.KIND_FLEET), 2)
	assert_true(sim.world.regions[1].has_assets())
	# The fleet's base effect is `hardware +1` where one stands (§6.1).
	assert_almost_eq(sim.hardware(1), sim.db.balance.compute_hardware_by_tier[
		sim.db.regions[1].attr("compute")] + 1.0, 1e-9)

	sim.world.set_assets(1, AssetDef.KIND_FLEET, 0)
	assert_false(sim.world.regions[1].has_assets())
	assert_false(sim.world.regions[1].assets.has(AssetDef.KIND_FLEET), "0 erases the key")


func test_asset_total_counts_across_the_world() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	sim.world.set_assets(1, AssetDef.KIND_LAB, 1)
	sim.world.set_assets(2, AssetDef.KIND_LAB, 2)
	assert_eq(sim.world.asset_total(AssetDef.KIND_LAB), 3)
	assert_eq(sim.world.asset_total(AssetDef.KIND_TAP), 0)


func test_the_save_lists_only_the_kinds_a_region_holds() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	sim.world.set_assets(1, AssetDef.KIND_LAB, 2)
	var regions: Array = sim.world.to_dict()["regions"]
	var first: Dictionary = regions[0]
	assert_eq(first["assets"], {"lab": 2})
	assert_eq((regions[1] as Dictionary)["assets"], {}, "and nothing for a region with none")


func test_an_asset_changes_the_state_hash_and_survives_a_round_trip() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	sim.world.agent.count_seed(LinkDef.KIND_SEA)
	var before: String = sim.state_hash()
	sim.world.set_assets(1, AssetDef.KIND_FLEET, 1)
	assert_ne(sim.state_hash(), before)

	var restored: World = World.from_dict(sim.world.to_dict(), sim.db)
	assert_not_null(restored)
	var continued: Simulation = Simulation.from_world(sim.db, restored, [])
	assert_eq(continued.state_hash(), sim.state_hash())
	assert_eq(continued.world.regions[1].asset_count(AssetDef.KIND_FLEET), 1)
	assert_eq(continued.world.agent.seeds_by_kind, {LinkDef.KIND_SEA: 1})
	assert_eq(continued.world.modifiers.asset_count(1, AssetDef.KIND_FLEET), 1,
		"the stack is refilled from the regions")


func test_a_negative_asset_count_is_an_invariant_violation() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	sim.world.regions[1].assets[AssetDef.KIND_FLEET] = -1
	assert_string_contains(str(sim.world.check_invariants(sim.db)), "negative")
