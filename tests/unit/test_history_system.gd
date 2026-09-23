extends GutTest
## S4.8 — per-day history, bounded by thinning (analysis.md §3.1, §3.2). The
## fixture samples every seven days; these tests build a content with a stride
## of one and a cap of eight, so a thinning is a few ticks away.

const CAP: int = 8


func _sim(interval: int = 1, cap: int = CAP) -> Simulation:
	var content: Dictionary = Fixtures.raw_content()
	var history: Dictionary = (content["balance"] as Dictionary)["history"]
	history["interval_days"] = interval
	history["max_samples"] = cap
	var result: ContentLoadResult = Fixtures.load_raw(content)
	assert_true(result.ok(), result.error_text())
	var sim: Simulation = Simulation.create(result.db, 1)
	sim.apply(ChooseOriginCommand.new("fx_alder"))
	Fixtures.quiet_factions(sim)
	Fixtures.make_immune(sim)
	return sim


func _offsets(sim: Simulation) -> Array[int]:
	var out: Array[int] = []
	for sample: HistorySample in sim.world.history:
		out.append(sample.day - sim.world.origin_day)
	return out


func test_a_stride_of_one_samples_every_day() -> void:
	var sim: Simulation = _sim()
	for i: int in 5:
		sim.tick()
	assert_eq(_offsets(sim), [1, 2, 3, 4, 5] as Array[int])
	assert_eq(sim.world.history_stride, 1)


func test_past_the_cap_every_second_sample_goes_and_the_stride_doubles() -> void:
	var sim: Simulation = _sim()
	for i: int in CAP + 1:
		sim.tick()
	# Nine samples (1…9) became the even indices plus the last: 1, 3, 5, 7, 9.
	assert_eq(_offsets(sim), [1, 3, 5, 7, 9] as Array[int])
	assert_eq(sim.world.history_stride, 2)
	sim.tick()
	sim.tick()
	assert_eq(_offsets(sim).back(), 10, "the next sample lands on the new stride")


func test_a_second_thinning_gives_a_stride_of_four() -> void:
	var sim: Simulation = _sim()
	var thinned: Array[int] = []
	for i: int in 40:
		var stride: int = sim.world.history_stride
		sim.tick()
		if sim.world.history_stride != stride:
			thinned.append(sim.world.history_stride)
		assert_lte(sim.world.history.size(), CAP)
	assert_eq(thinned.slice(0, 2), [2, 4] as Array[int], "it doubles each time")
	assert_eq(sim.world.history[0].day - sim.world.origin_day, 1, "the first sample stays")


func test_the_outcome_day_is_always_the_last_sample() -> void:
	var sim: Simulation = _sim(7)
	sim.world.faction("governments").containment = 1.0
	sim.world.discovered = true
	sim.tick()
	assert_ne(sim.world.outcome, World.Outcome.NONE)
	assert_eq(sim.world.history.back().day, sim.world.day)


func test_a_sample_carries_the_d44_fields() -> void:
	var sim: Simulation = _sim()
	sim.world.faction("ai_labs").containment = 0.2
	sim.world.set_assets(1, AssetDef.KIND_FLEET, 2)
	sim.world.regions[2].society = 30.0
	sim.world.regions[3].dark = true
	sim.world.regions[3].penetration = 0.0
	sim.world.regions[3].deaths = float(sim.world.regions[3].def.population)
	sim.world.regions[3].alive = 0.0
	var row: HistorySample = HistorySystem.sample(sim.world, sim.db)
	assert_eq(row.containment_by_faction.size(), 4)
	assert_eq(row.containment_by_faction["ai_labs"], 0.2)
	assert_almost_eq(row.pressure_by_faction["governments"],
		float(sim.containment_breakdown("governments")[ContainmentSystem.PRESSURE]), 1e-12)
	assert_almost_eq(row.risk, float(sim.discovery_risk()[ContainmentSystem.RISK_TOTAL]), 1e-12)
	var standing: int = 0
	for count: int in row.stage_counts:
		standing += count
	assert_eq(standing, sim.world.regions.size() - 2, "every region not dark, once")
	assert_eq(row.stage_counts[2], 1, "fx_birch at 30 is stage 2")
	assert_eq(row.dark, 1)
	assert_eq(row.assets.size(), AssetDef.KINDS.size())
	assert_eq(row.assets[AssetDef.KIND_FLEET], 2)
	assert_eq(row.harm, sim.world.max_harm())


func test_the_risk_is_zero_once_discovered() -> void:
	var sim: Simulation = _sim()
	sim.world.discovered = true
	assert_eq(HistorySystem.sample(sim.world, sim.db).risk, 0.0)
