extends GutTest
## S4.8 — the history row's codec (analysis.md §3.2).


func _row() -> HistorySample:
	var sim: Simulation = Fixtures.sim_with_origin()
	sim.world.faction("public_sentiment").containment = 0.35
	sim.world.set_assets(1, AssetDef.KIND_LAB, 3)
	sim.world.starving_days = 2
	return HistorySystem.sample(sim.world, sim.db)


func test_every_field_survives_the_round_trip() -> void:
	var row: HistorySample = _row()
	var back: HistorySample = HistorySample.from_dict(JSON.parse_string(
		JSON.stringify(row.to_dict())))
	assert_not_null(back)
	assert_eq(back.to_dict(), row.to_dict())
	assert_eq(back.containment_by_faction["public_sentiment"], 0.35)
	assert_eq(back.assets[AssetDef.KIND_LAB], 3)
	assert_eq(back.starving_days, 2)
	assert_eq(back.stage_counts.size(), HistorySample.STAGE_COUNT)


func test_a_row_missing_a_d44_field_is_refused() -> void:
	for key: String in ["risk", "harm", "controlled", "dark", "stage_counts", "assets",
			"starving_days", "containment_by_faction", "pressure_by_faction"]:
		var d: Dictionary = _row().to_dict()
		d.erase(key)
		assert_null(HistorySample.from_dict(d), key)


func test_an_unknown_faction_or_kind_is_refused() -> void:
	var d: Dictionary = _row().to_dict()
	(d["containment_by_faction"] as Dictionary)["the_press"] = FloatBits.to_hex(0.1)
	assert_null(HistorySample.from_dict(d))
	var e: Dictionary = _row().to_dict()
	(e["assets"] as Dictionary)["drone"] = 1
	assert_null(HistorySample.from_dict(e))


func test_a_stage_list_of_another_length_is_refused() -> void:
	var d: Dictionary = _row().to_dict()
	d["stage_counts"] = [1, 2, 3]
	assert_null(HistorySample.from_dict(d))
