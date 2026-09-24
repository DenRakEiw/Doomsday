extends GutTest
## S4.2 — `StatusSystem`: applying, refreshing, closing links, expiring
## (`docs/specs/loop-mechanics.md` §7.2, §7.4).

const ORIGIN: int = 1
## `fx_birch`: one sea link (to `fx_dogwood`) and two land links, so a status
## that closes the sea kind closes exactly one of its links.
const BIRCH: int = 2
const DOGWOOD: int = 4
const SEA_LINK: String = "fx_birch|fx_dogwood|sea"
const DIM: String = "fx_dim"
const REAPED: String = "fx_reaped"
const LOCK: String = "fx_lock"
const HUSH: String = "fx_hush"
const SOURCE: String = "effect"

var sim: Simulation
var events: Array[SimEvent]


func before_each() -> void:
	sim = Fixtures.sim_with_origin()
	events = []


func _apply(id: String, region: int, level: int = 1, days: int = 0) -> Status:
	return StatusSystem.apply(sim.world, sim.db, id, region, SOURCE, level, "", events, days)


func _types() -> Array[String]:
	var out: Array[String] = []
	for event: SimEvent in events:
		out.append(event.type)
	return out


func _link(id: String) -> Link:
	for link: Link in sim.world.links:
		if link.def.id == id:
			return link
	return null


# ------------------------------------------------------------------ applying


func test_apply_adds_the_status_and_its_source() -> void:
	var status: Status = _apply(DIM, BIRCH)
	assert_not_null(status)
	assert_true(sim.world.has_status(DIM, BIRCH))
	assert_true(sim.world.modifiers.has_source(status.source_id()))
	assert_eq(status.started_day, sim.world.day)
	assert_eq(status.until_day, sim.world.day + 5)
	assert_eq(status.days_total(), 5)


func test_the_modifier_acts_in_its_region_and_nowhere_else() -> void:
	_apply(DIM, BIRCH)
	assert_almost_eq(sim.stat("yield", BIRCH), 0.5, 1e-9)
	assert_almost_eq(sim.stat("yield", ORIGIN), 1.0, 1e-9, "the neighbour is untouched")


## §7.2 step 8: the status is announced before whatever it caused, because the
## interface shows the condition and then its consequences.
func test_status_started_comes_before_the_on_start_effects() -> void:
	_apply(DIM, BIRCH, 2)
	assert_eq(events[0].type, SimEvent.STATUS_STARTED)
	assert_eq(str(events[0].data["status"]), DIM)
	assert_eq(int(events[0].data["level"]), 2)
	assert_false(bool(events[0].data["refreshed"]))
	assert_true(_types().slice(1).has(SimEvent.STATUS_STARTED),
		"and the spread it started follows")


func test_a_global_status_is_on_the_agent_and_reaches_every_region() -> void:
	_apply(HUSH, 0)
	assert_true(sim.world.has_status(HUSH, 0))
	assert_eq(str(events[0].data["region"]), "", "a global status names no region")
	assert_almost_eq(sim.stat("spread_growth", ORIGIN), 0.5, 1e-9)
	assert_almost_eq(sim.stat("spread_growth", BIRCH), 0.5, 1e-9)


## §7.2 step 3: one of an id per region, ever. A second application is a refresh.
func test_applying_the_same_status_again_refreshes_it() -> void:
	_apply(DIM, BIRCH)
	sim.world.day += 2
	events.clear()
	var again: Status = _apply(DIM, BIRCH, 2)
	assert_eq(sim.world.statuses_of(DIM).size(), 3,
		"one here and the two the level-2 spread reached, never two here")
	assert_eq(sim.world.statuses_in_region(BIRCH).size(), 1)
	assert_eq(again.level, 2)
	assert_eq(again.started_day, sim.world.day)
	assert_eq(again.until_day, sim.world.day + 10)
	assert_true(bool(events[0].data["refreshed"]))


func test_a_days_override_beats_the_level_s_own_length() -> void:
	var status: Status = _apply(DIM, BIRCH, 1, 3)
	assert_eq(status.days_total(), 3)


## §7.2 step 2: what this status ends goes first, so its own start is not undone.
func test_ends_statuses_takes_the_other_one_away_first() -> void:
	_apply(DIM, BIRCH)
	events.clear()
	_apply(LOCK, BIRCH)
	assert_false(sim.world.has_status(DIM, BIRCH))
	assert_eq(events[0].type, SimEvent.STATUS_ENDED)
	assert_eq(str(events[0].data["cause"]), StatusSystem.CAUSE_ENDED)
	assert_eq(events[1].type, SimEvent.STATUS_STARTED)


# --------------------------------------------------------------------- links


func test_closes_links_closes_the_region_s_links_of_that_kind() -> void:
	var status: Status = _apply(DIM, BIRCH)
	assert_false(_link(SEA_LINK).open)
	assert_eq(status.closed_links, [SEA_LINK] as Array[String])
	for link: Link in sim.world.links:
		if link.def.kind != LinkDef.KIND_SEA:
			assert_true(link.open, "%s is another kind" % link.def.id)


func test_all_closes_every_link_the_region_has() -> void:
	var status: Status = _apply(LOCK, BIRCH)
	assert_eq(status.closed_links.size(), 3, "two land links and one sea link")
	for link_id: String in status.closed_links:
		assert_false(_link(link_id).open)


func test_a_link_two_statuses_hold_stays_closed_until_the_last_one_goes() -> void:
	_apply(DIM, BIRCH)
	_apply(DIM, DOGWOOD)
	assert_true(sim.world.link_held_closed(SEA_LINK))
	StatusSystem.end(sim.world, sim.db, sim.world.status_in_region(DIM, BIRCH),
		StatusSystem.CAUSE_ENDED, events)
	assert_false(_link(SEA_LINK).open, "the other one still holds it")
	StatusSystem.end(sim.world, sim.db, sim.world.status_in_region(DIM, DOGWOOD),
		StatusSystem.CAUSE_ENDED, events)
	assert_true(_link(SEA_LINK).open)


# -------------------------------------------------------------------- ending


func test_on_expiry_the_source_the_status_and_the_links_all_go() -> void:
	var status: Status = _apply(DIM, BIRCH)
	var source: String = status.source_id()
	sim.world.day = status.until_day
	events.clear()
	StatusSystem.new().tick(sim.world, sim.db, events)
	assert_false(sim.world.has_status(DIM, BIRCH))
	assert_false(sim.world.modifiers.has_source(source))
	assert_true(_link(SEA_LINK).open)
	assert_almost_eq(sim.stat("yield", BIRCH), 1.0, 1e-9)


func test_an_expiring_status_says_so_with_its_cause() -> void:
	_apply(DIM, BIRCH)
	sim.world.day += 5
	events.clear()
	StatusSystem.new().tick(sim.world, sim.db, events)
	assert_eq(events[0].type, SimEvent.STATUS_ENDED)
	assert_eq(str(events[0].data["cause"]), StatusSystem.CAUSE_EXPIRED)
	assert_eq(str(events[0].data["region"]), sim.world.regions[BIRCH].def.id)


## §7.4 step 1 (D4.2): only an expiry runs `on_end` — a status cut short never
## had its consequence come to pass.
func test_on_end_runs_on_expiry_and_not_when_the_status_is_cut_short() -> void:
	_apply(REAPED, BIRCH)
	sim.world.day += 6
	events.clear()
	StatusSystem.new().tick(sim.world, sim.db, events)
	assert_eq(sim.world.pulses.size(), 1, "the on_end pulse ran")

	sim.world.pulses.clear()
	_apply(REAPED, DOGWOOD)
	StatusSystem.end(sim.world, sim.db, sim.world.status_in_region(REAPED, DOGWOOD),
		StatusSystem.CAUSE_ENDED, events)
	assert_eq(sim.world.pulses.size(), 0, "a status that was ended runs nothing")


func test_two_statuses_expiring_on_one_tick_both_end() -> void:
	_apply(DIM, BIRCH)
	_apply(DIM, DOGWOOD)
	sim.world.day += 5
	events.clear()
	StatusSystem.new().tick(sim.world, sim.db, events)
	assert_eq(sim.world.statuses.size(), 0)


func test_a_standing_status_never_expires() -> void:
	var status: Status = _apply(DIM, BIRCH)
	status.until_day = Status.UNTIL_STANDING
	assert_true(status.is_standing())
	assert_eq(status.days_total(), Status.STANDING)
	assert_eq(status.days_left(sim.world.day), Status.STANDING)
	sim.world.day += 500
	StatusSystem.new().tick(sim.world, sim.db, events)
	assert_true(sim.world.has_status(DIM, BIRCH))


# --------------------------------------------------- pulses and timed flags


func test_a_pulse_raises_footprint_and_ends_on_its_day() -> void:
	var before: float = sim.world.footprint()
	StatusSystem.add_pulse(sim.world, 2.0, sim.world.day + 2, [] as Array[String], events)
	assert_almost_eq(sim.world.footprint(), before + 2.0, 1e-9)
	assert_eq(events[0].type, SimEvent.PULSE_STARTED)
	sim.world.day += 2
	events.clear()
	StatusSystem.new().tick(sim.world, sim.db, events)
	assert_almost_eq(sim.world.footprint(), before, 1e-9)
	assert_eq(events[0].type, SimEvent.PULSE_ENDED)
	assert_eq(sim.world.pulses.size(), 0)


func test_a_timed_flag_answers_has_flag_until_it_runs_out() -> void:
	StatusSystem.set_timed_flag(sim.world, "fx_seen", sim.world.day + 3, events)
	assert_true(sim.world.modifiers.has_flag("fx_seen"))
	assert_true(sim.world.has_timed_flag("fx_seen", sim.world.day))
	sim.world.day += 3
	events.clear()
	StatusSystem.new().tick(sim.world, sim.db, events)
	assert_false(sim.world.modifiers.has_flag("fx_seen"))
	assert_eq(events[0].type, SimEvent.FLAG_EXPIRED)


# ---------------------------------------------------------------- the world


## §4: the status system runs before the events, so a status that ends today is
## gone before anything reacts to the world it left behind.
func test_the_system_sits_between_containment_and_the_phase() -> void:
	var order: Array[String] = []
	for system: SimSystem in sim.systems:
		order.append(system.get_script().resource_path.get_file())
	# containment → the counter-move schedule (S4.5) → statuses (IMPLEMENTATION §3).
	assert_eq(order.find("counter_move_system.gd"), order.find("containment_system.gd") + 1)
	assert_eq(order.find("status_system.gd"), order.find("counter_move_system.gd") + 1)
	assert_true(order.find("status_system.gd") < order.find("phase_system.gd"))


func test_check_invariants_catches_a_level_out_of_range() -> void:
	_apply(DIM, BIRCH)
	sim.world.statuses[0].level = 7
	assert_string_contains(str(sim.world.check_invariants(sim.db)), "level 7")


func test_check_invariants_catches_the_same_status_twice_in_one_region() -> void:
	_apply(DIM, BIRCH)
	sim.world.statuses.append(sim.world.statuses[0])
	assert_string_contains(str(sim.world.check_invariants(sim.db)), "running twice")


func test_a_healthy_run_with_statuses_has_no_problems() -> void:
	_apply(DIM, BIRCH)
	_apply(HUSH, 0)
	StatusSystem.add_pulse(sim.world, 1.0, sim.world.day + 2, [] as Array[String], events)
	assert_eq(str(sim.world.check_invariants(sim.db)), "[]")


## S4.10: the bots were the first to use abilities over a whole run, and a
## cleared cooldown stayed on the agent until `check_invariants` said so.
func test_a_cooldown_is_taken_off_the_day_it_clears() -> void:
	sim.world.agent.cooldowns["fx_ability"] = sim.world.day + 2
	sim.tick()
	assert_true(sim.world.agent.cooldowns.has("fx_ability"), "still cooling down")
	sim.tick()
	assert_false(sim.world.agent.cooldowns.has("fx_ability"), "ready, so absent")
	assert_eq(sim.world.check_invariants(sim.db).size(), 0)


## S4.10: a bot silenced a region and then emptied it, and the status stood on
## in the dark — loop-mechanics §3.5 says no status stands in a dark region.
func test_a_region_going_dark_ends_its_statuses_without_their_consequence() -> void:
	_apply(DIM, BIRCH)
	events = []
	# Emptied first, as the population system does: a dark region has nobody.
	sim.world.regions[BIRCH].deaths += sim.world.regions[BIRCH].alive
	sim.world.regions[BIRCH].alive = 0.0
	PopulationSystem.go_dark(sim.world, sim.db, sim.world.regions[BIRCH], BIRCH, events)
	assert_false(sim.world.has_status(DIM, BIRCH))
	var ended: Array[SimEvent] = events.filter(func(e: SimEvent) -> bool:
		return e.type == SimEvent.STATUS_ENDED)
	assert_eq(ended.size(), 1)
	assert_eq(str(ended[0].data["cause"]), SimEvent.CAUSE_DARK)
	assert_eq(sim.world.check_invariants(sim.db).size(), 0)
