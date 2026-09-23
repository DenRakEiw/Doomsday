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
