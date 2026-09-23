extends GutTest
## S4.8 — the run log in the core (analysis.md §4): the kept types and keys, the
## two filters, the cap, the codec and the hash.

var sim: Simulation


func before_each() -> void:
	sim = Fixtures.sim_with_origin()


func _record(type: String, data: Dictionary) -> void:
	var events: Array[SimEvent] = [SimEvent.new(type, sim.world.day, data)]
	RunLog.record(sim.world, sim.db, events)


func test_the_origin_command_is_logged() -> void:
	assert_eq(sim.world.run_log.size(), 1)
	assert_eq(sim.world.run_log[0].type, SimEvent.ORIGIN_CHOSEN)
	assert_eq(sim.world.run_log[0].data, {"region": "fx_alder"})


func test_every_kept_type_keeps_exactly_its_keys() -> void:
	for type: String in RunLog.KEPT:
		var data: Dictionary = {"extra": "dropped"}
		for key: String in RunLog.KEPT[type]:
			data[key] = 1.0 if RunLog.is_float(type, key) else "x"
		if type == SimEvent.STATUS_STARTED:
			data["status"] = Fixtures.WORLD_STATUS
		if type == SimEvent.SOCIETY_STAGE_CHANGED:
			data["from"] = 2
			data["to"] = 3
		var before: int = sim.world.run_log.size()
		_record(type, data)
		assert_eq(sim.world.run_log.size(), before + 1, type)
		var kept: Dictionary = sim.world.run_log.back().data
		assert_eq(kept.keys().size(), RunLog.KEPT[type].size(), type)
		assert_false(kept.has("extra"), type)


func test_an_unlisted_type_is_not_logged() -> void:
	var before: int = sim.world.run_log.size()
	_record(SimEvent.REGION_SEEDED, {"region": "fx_birch"})
	_record(SimEvent.HEADLINE, {"headline": "x"})
	assert_eq(sim.world.run_log.size(), before)


func test_only_a_fresh_world_status_is_logged() -> void:
	var before: int = sim.world.run_log.size()
	_record(SimEvent.STATUS_STARTED, {"status": Fixtures.ZAP_STATUS, "region": "fx_alder"})
	_record(SimEvent.STATUS_STARTED, {"status": Fixtures.WORLD_STATUS, "refreshed": true})
	assert_eq(sim.world.run_log.size(), before, "a player status, a refresh: neither")
	_record(SimEvent.STATUS_STARTED, {"status": Fixtures.WORLD_STATUS, "region": "fx_alder"})
	assert_eq(sim.world.run_log.size(), before + 1)


func test_only_a_worsening_to_three_or_five_is_logged() -> void:
	var before: int = sim.world.run_log.size()
	_record(SimEvent.SOCIETY_STAGE_CHANGED, {"region": "fx_alder", "from": 1, "to": 2})
	_record(SimEvent.SOCIETY_STAGE_CHANGED, {"region": "fx_alder", "from": 4, "to": 3})
	assert_eq(sim.world.run_log.size(), before)
	_record(SimEvent.SOCIETY_STAGE_CHANGED, {"region": "fx_alder", "from": 2, "to": 3})
	_record(SimEvent.SOCIETY_STAGE_CHANGED, {"region": "fx_alder", "from": 4, "to": 5})
	assert_eq(sim.world.run_log.size(), before + 2)


func test_the_cap_drops_the_oldest() -> void:
	for i: int in sim.db.balance.history_log_max + 10:
		_record(SimEvent.NODE_PURCHASED, {"node": "n%d" % i})
	assert_eq(sim.world.run_log.size(), sim.db.balance.history_log_max)
	assert_eq(sim.world.run_log.back().data["node"],
		"n%d" % (sim.db.balance.history_log_max + 9))


func test_an_entry_round_trips_floats_as_bits() -> void:
	_record(SimEvent.CONTAINMENT_THRESHOLD, {"faction": "governments", "threshold": 0.25})
	_record(SimEvent.REGION_WIPED, {"region": "fx_alder", "from": 0.8, "to": 0.4})
	for entry: RunLogEntry in sim.world.run_log:
		var back: RunLogEntry = RunLogEntry.from_dict(JSON.parse_string(
			JSON.stringify(entry.to_dict())))
		assert_not_null(back, entry.type)
		assert_eq(back.data, entry.data, entry.type)
		assert_eq(back.day, entry.day)


func test_the_log_is_in_the_hash_and_the_save() -> void:
	var other: Simulation = Fixtures.sim_with_origin()
	assert_eq(other.state_hash(), sim.state_hash())
	_record(SimEvent.FUNDING_RESET, {})
	assert_ne(other.state_hash(), sim.state_hash())
	var loaded: LoadResult = WorldSerializer.from_json(WorldSerializer.to_json(sim), sim.db)
	assert_true(loaded.ok(), loaded.reason)
	assert_eq(loaded.sim.world.run_log.size(), sim.world.run_log.size())
	assert_eq(loaded.sim.state_hash(), sim.state_hash())


func test_a_tick_and_a_command_both_feed_the_log() -> void:
	Fixtures.grant(sim, 100.0)
	var before: int = sim.world.run_log.size()
	Fixtures.buy(sim, ["fx_quiet"])
	assert_eq(sim.world.run_log.back().type, SimEvent.NODE_PURCHASED)
	assert_gt(sim.world.run_log.size(), before)
