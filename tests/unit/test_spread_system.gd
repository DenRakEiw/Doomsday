extends GutTest
## S1.3 — growth inside a region, seeding across links, and control.
##
## The modifier stack still returns its bases (S1.4 completes it), so every
## expectation here is the unmodified formula.


## Runs `days` ticks and returns every event, in order.
func _run(sim: Simulation, days: int) -> Array[SimEvent]:
	var events: Array[SimEvent] = []
	for i: int in days:
		sim.tick()
		events.append_array(sim.outbox)
	return events


func _of_type(events: Array[SimEvent], type: String) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for event: SimEvent in events:
		if event.type == type:
			out.append(event)
	return out


func test_nothing_happens_before_an_origin_is_chosen() -> void:
	var sim: Simulation = Fixtures.sim()
	Fixtures.allow_breakout(sim)
	var before: String = sim.state_hash()
	_run(sim, 50)
	sim.world.day = 0
	assert_eq(sim.state_hash(), before, "every system returns at once without an origin")


func test_penetration_only_rises_and_stays_inside_its_range() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	Fixtures.allow_breakout(sim)
	var previous: Array[float] = []
	previous.resize(sim.world.regions.size())
	for i: int in 2000:
		sim.tick()
		for r: int in range(1, sim.world.regions.size()):
			var p: float = sim.world.regions[r].penetration
			assert_between(p, 0.0, 1.0)
			assert_true(p >= previous[r], "penetration never falls without a countermeasure")
			previous[r] = p
	# Without the content, because the phase invariant only holds once
	# `PhaseSystem` exists (S1.5) and `breakout` is granted here by hand.
	var problems: Array[String] = sim.world.check_invariants()
	assert_eq(problems.size(), 0, str(problems))


func test_saturation_snaps_to_exactly_one() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	_run(sim, 400)
	assert_eq(sim.world.regions[1].penetration, 1.0,
		"it snaps rather than approaching 1 for ever")


func test_nothing_is_seeded_while_boxed() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	var events: Array[SimEvent] = _run(sim, 1000)
	assert_eq(_of_type(events, SimEvent.REGION_SEEDED).size(), 0)
	assert_eq(sim.world.seeded_count(), 1, "the origin, and nothing else")


func test_breakout_fills_the_world_but_never_the_air_gapped_region() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	Fixtures.allow_breakout(sim)
	_run(sim, 1500)
	for i: int in range(1, 6):
		assert_true(sim.world.regions[i].seeded_day >= 0,
			"%s should have been reached" % sim.world.regions[i].def.id)
	assert_eq(sim.world.regions[6].seeded_day, -1, "fx_fir is air-gapped")


func test_a_region_behind_closed_links_is_never_seeded() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	Fixtures.allow_breakout(sim)
	for link: Link in sim.world.links:
		if link.def.a == 5 or link.def.b == 5:
			link.open = false
	_run(sim, 1500)
	assert_eq(sim.world.regions[5].seeded_day, -1, "fx_elm has only the two closed links")
	assert_true(sim.world.regions[4].seeded_day >= 0, "the rest still fills up")


func test_an_unlinked_region_is_never_seeded() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	Fixtures.allow_breakout(sim)
	# fx_cedar hangs off a single land link; closing it leaves it unreachable.
	for link: Link in sim.world.links:
		if link.def.a == 3 or link.def.b == 3:
			link.open = false
	_run(sim, 1500)
	assert_eq(sim.world.regions[3].seeded_day, -1)


func test_the_air_gapped_region_costs_the_stream_nothing() -> void:
	# The same world twice, differing only in whether the one link into fx_fir is
	# open. A roll that is skipped must be skipped in both, or closing any link
	# would shift every later draw.
	var opened: Simulation = _dogwood_world()
	var closed: Simulation = _dogwood_world()
	for link: Link in closed.world.links:
		if link.def.b == 6 or link.def.a == 6:
			link.open = false
	opened.tick()
	closed.tick()
	assert_eq(opened.world.rng.state_string(), closed.world.rng.state_string())


func _dogwood_world() -> Simulation:
	var sim: Simulation = Fixtures.sim_with_origin()
	Fixtures.allow_breakout(sim)
	sim.world.regions[4].penetration = 0.8
	sim.world.regions[4].seeded_day = 0
	return sim


func test_a_region_seeded_today_seeds_nobody_today() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	Fixtures.allow_breakout(sim)
	for i: int in 1500:
		sim.tick()
		for event: SimEvent in sim.outbox:
			if event.type != SimEvent.REGION_SEEDED:
				continue
			var source: Region = sim.world.regions[sim.db.region_index_by_id[event.data["from"]]]
			assert_true(source.seeded_day < sim.world.day,
				"%s seeded on the very day it was seeded" % source.def.id)


func test_the_seed_event_names_the_source_and_the_kind() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	Fixtures.allow_breakout(sim)
	var events: Array[SimEvent] = _of_type(_run(sim, 1500), SimEvent.REGION_SEEDED)
	assert_gt(events.size(), 0)
	for event: SimEvent in events:
		assert_true(sim.db.region_index_by_id.has(event.data["from"]))
		assert_true(LinkDef.KINDS.has(event.data["link_kind"]))


func test_control_stays_at_zero_below_the_threshold() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	sim.world.regions[1].penetration = 0.3
	sim.tick()
	assert_lt(sim.world.regions[1].penetration, sim.db.balance.control_threshold)
	assert_eq(sim.world.regions[1].control, 0.0)


func test_control_rises_above_the_threshold_and_reports_once() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	sim.world.regions[1].penetration = 1.0
	var events: Array[SimEvent] = _of_type(_run(sim, 400), SimEvent.REGION_CONTROLLED)
	assert_eq(sim.world.regions[1].control, 1.0)
	assert_eq(events.size(), 1, "the region is reported controlled exactly once")
	assert_eq(events[0].data["region"], "fx_alder")


func test_the_same_seed_seeds_the_same_regions_on_the_same_days() -> void:
	var days: Array[int] = []
	for run: int in 2:
		var sim: Simulation = Fixtures.sim_with_origin("fx_alder", 12)
		Fixtures.allow_breakout(sim)
		_run(sim, 800)
		var seen: Array[int] = []
		for i: int in range(1, sim.world.regions.size()):
			seen.append(sim.world.regions[i].seeded_day)
		if run == 0:
			days = seen
		else:
			assert_eq(seen, days)
	assert_gt(days.size(), 0)
