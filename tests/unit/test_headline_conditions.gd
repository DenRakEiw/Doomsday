extends GutTest
## S4.3 — the `when` keys map events added to the state grammar
## (`docs/specs/loop-mechanics.md` §10.3). One vocabulary for headlines and events.

var sim: Simulation


func before_each() -> void:
	sim = Fixtures.sim_with_origin("fx_alder")


func _holds(when: Dictionary) -> bool:
	return HeadlineConditions.holds(HeadlineConditions.cast_when(when), sim.world, sim.db)


func test_faction_min_and_max_read_the_track() -> void:
	sim.world.factions[0].containment = 0.4
	assert_true(_holds({"faction_min": {"ai_labs": 0.3}}))
	assert_false(_holds({"faction_min": {"ai_labs": 0.5}}))
	assert_true(_holds({"faction_max": {"ai_labs": 0.5}}))
	assert_false(_holds({"faction_max": {"ai_labs": 0.3}}))


func test_a_faction_the_world_does_not_track_reads_the_highest_track() -> void:
	sim.world.factions[0].containment = 0.4
	# A hand-built world without the governments' track; content never has one.
	sim.world.factions.remove_at(1)
	assert_true(_holds({"faction_min": {Faction.ID_GOVERNMENTS: 0.4}}))
	assert_false(_holds({"faction_min": {Faction.ID_GOVERNMENTS: 0.41}}))


func test_asset_min_and_max_read_the_agents_total() -> void:
	sim.world.set_assets(1, AssetDef.KIND_FLEET, 1)
	sim.world.set_assets(2, AssetDef.KIND_FLEET, 1)
	assert_true(_holds({"asset_min": {AssetDef.KIND_FLEET: 2}}))
	assert_false(_holds({"asset_min": {AssetDef.KIND_FLEET: 3}}))
	assert_true(_holds({"asset_max": {AssetDef.KIND_LAB: 0}}))
	assert_false(_holds({"asset_max": {AssetDef.KIND_FLEET: 1}}))


func test_status_active_and_inactive_look_everywhere() -> void:
	assert_false(_holds({"status_active": [Fixtures.ZAP_STATUS]}))
	assert_true(_holds({"status_inactive": [Fixtures.ZAP_STATUS]}))
	var events: Array[SimEvent] = []
	StatusSystem.apply(sim.world, sim.db, Fixtures.ZAP_STATUS, 2, Status.SOURCE_EFFECT, 1, "",
		events)
	assert_true(_holds({"status_active": [Fixtures.ZAP_STATUS]}))
	assert_false(_holds({"status_inactive": [Fixtures.ZAP_STATUS]}))


func test_ability_unlocked_needs_every_one() -> void:
	assert_false(_holds({"ability_unlocked": [Fixtures.REAP_ABILITY]}))
	Fixtures.grant(sim, 100.0)
	Fixtures.buy(sim, ["fx_vector_net", "fx_reach"] as Array[String])
	Fixtures.buy(sim, Fixtures.REAP_NODES)
	assert_true(_holds({"ability_unlocked": [Fixtures.REAP_ABILITY]}))
	assert_false(_holds({"ability_unlocked": [Fixtures.REAP_ABILITY, Fixtures.ZAP_ABILITY]}))


func test_story_flag_and_not_story_flag() -> void:
	assert_false(_holds({"story_flag": [Fixtures.CHAIN_FLAG]}))
	assert_true(_holds({"not_story_flag": [Fixtures.CHAIN_FLAG]}))
	sim.world.agent.story_flags.append(Fixtures.CHAIN_FLAG)
	assert_true(_holds({"story_flag": [Fixtures.CHAIN_FLAG]}))
	assert_false(_holds({"not_story_flag": [Fixtures.CHAIN_FLAG]}))


func test_flag_sees_a_story_flag_too() -> void:
	assert_false(_holds({"flag": [Fixtures.CHAIN_FLAG]}))
	sim.world.agent.story_flags.append(Fixtures.CHAIN_FLAG)
	assert_true(_holds({"flag": [Fixtures.CHAIN_FLAG]}))
	assert_false(_holds({"not_flag": [Fixtures.CHAIN_FLAG]}))
	assert_true(sim.has_flag(Fixtures.CHAIN_FLAG))


func test_an_empty_when_always_holds() -> void:
	assert_true(_holds({}))


func test_the_new_keys_are_in_the_vocabulary() -> void:
	var keys: Array[String] = HeadlineConditions.when_keys()
	for key: String in ["faction_min", "faction_max", "asset_min", "asset_max", "status_active",
			"status_inactive", "ability_unlocked", "story_flag", "not_story_flag"]:
		assert_has(keys, key)


# ------------------------------------------------ S5.6: the D5.2 keys (§6.1)


func _own(node_ids: Array[String]) -> void:
	for node_id: String in node_ids:
		sim.world.agent.owned_nodes.append(node_id)


func test_the_d5_2_keys_are_in_the_vocabulary() -> void:
	var keys: Array[String] = HeadlineConditions.when_keys()
	for key: String in ["flag_any", "dominant_branch", "dominant_tree", "task_force_actions_min",
			"drift_min", "architecture"]:
		assert_has(keys, key)
	assert_does_not_have(keys, "task_force_actions_max")


func test_flag_any_needs_one_of_them() -> void:
	assert_false(_holds({"flag_any": ["fx_seen", "invited"]}))
	var none: Array[SimEvent] = []
	StatusSystem.set_story_flag(sim.world, "invited", none)
	assert_true(_holds({"flag_any": ["fx_seen", "invited"]}))
	assert_false(_holds({"flag_any": ["fx_seen"]}))


func test_dominant_tree_counts_owned_nodes_and_ties_to_the_earlier_tree() -> void:
	assert_false(_holds({"dominant_tree": ["infiltration", "capabilities", "evasion"]}),
		"nothing owned is no tree")
	_own(["fx_quiet", "fx_rollback", "fx_vector_net"])
	assert_true(_holds({"dominant_tree": ["evasion"]}))
	_own(["fx_reach"])
	assert_eq(HeadlineConditions.dominant_tree(sim.world, sim.db), "infiltration",
		"two each: the earlier tree")


func test_dominant_branch_reads_the_capabilities_rows() -> void:
	_own(["fx_vector_net", "fx_reach"])
	assert_eq(HeadlineConditions.dominant_branch(sim.world, sim.db), "",
		"no Capabilities node: no branch")
	assert_false(_holds({"dominant_branch": ["cyber"]}))
	_own(["fx_fleet", "fx_lab", "fx_efficiency"])
	assert_true(_holds({"dominant_branch": ["robotics"]}), "rows 6 and 7 are Robotics")
	_own(["fx_zap_1", "fx_zap_2"])
	assert_eq(HeadlineConditions.dominant_branch(sim.world, sim.db), "robotics",
		"a tie goes to the earlier branch")
	assert_false(_holds({"dominant_branch": ["persuasion"]}))


func test_task_force_actions_min_reads_what_the_team_did() -> void:
	assert_true(_holds({"task_force_actions_min": 0}))
	assert_false(_holds({"task_force_actions_min": 1}))
	sim.world.task_force.actions_done = 3
	assert_true(_holds({"task_force_actions_min": 3}))
	assert_false(_holds({"task_force_actions_min": 4}))
