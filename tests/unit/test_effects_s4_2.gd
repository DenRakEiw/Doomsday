extends GutTest
## S4.2 — the ten effects that went live with the statuses
## (`docs/specs/loop-mechanics.md` §8.2). The six of S4.1 stay in
## `test_effect_runner.gd`; these need the status machinery.

const ORIGIN: int = 1
const BIRCH: int = 2
const DOGWOOD: int = 4
const ELM: int = 5
const NODE: String = "fx_grant"

var sim: Simulation
var events: Array[SimEvent]


func before_each() -> void:
	sim = Fixtures.sim_with_origin()
	events = []


func _apply(d: Dictionary, region: int = 0) -> void:
	EffectRunner.apply(sim, EffectDef.from_dict(d), EffectContext.for_node(NODE, region), events)


func _events_of(type: String) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for event: SimEvent in events:
		if event.type == type:
			out.append(event)
	return out


func _close(kind: String) -> void:
	for link: Link in sim.world.links:
		if link.def.kind == kind:
			link.open = false


# ----------------------------------------------------------- seed_neighbours


## §8.2: deterministic. The best uninfected open-linked neighbours by the
## hardware they would yield, never a roll — an effect must cost the stream
## nothing, or closing a link would change every later draw.
func test_seed_neighbours_takes_the_best_uninfected_neighbour() -> void:
	_apply({"effect": EffectDef.SEED_NEIGHBOURS, "count": 1}, ORIGIN)
	var seeded: Array[SimEvent] = _events_of(SimEvent.REGION_SEEDED)
	assert_eq(seeded.size(), 1)
	# fx_alder reaches fx_birch (land), fx_dogwood (network) and fx_elm (air);
	# fx_dogwood yields the most hardware of the three.
	assert_eq(str(seeded[0].data["region"]), "fx_dogwood")
	assert_eq(str(seeded[0].data["from"]), "fx_alder")
	assert_eq(str(seeded[0].data["link_kind"]), LinkDef.KIND_NETWORK)
	assert_gt(sim.world.regions[DOGWOOD].penetration, 0.0)
	assert_eq(sim.world.regions[DOGWOOD].seeded_day, sim.world.day)
	assert_eq(int(sim.world.agent.seeds_by_kind.get(LinkDef.KIND_NETWORK, 0)), 1)


func test_seed_neighbours_uses_no_draw_of_the_stream() -> void:
	var before: String = sim.world.rng.state_string()
	_apply({"effect": EffectDef.SEED_NEIGHBOURS, "count": 2}, ORIGIN)
	assert_eq(sim.world.rng.state_string(), before)


func test_seed_neighbours_skips_a_closed_link() -> void:
	_close(LinkDef.KIND_NETWORK)
	_apply({"effect": EffectDef.SEED_NEIGHBOURS, "count": 9}, ORIGIN)
	var reached: Array[String] = []
	for event: SimEvent in _events_of(SimEvent.REGION_SEEDED):
		reached.append(str(event.data["region"]))
	assert_false(reached.has("fx_dogwood"), "its only link from here is closed")
	assert_true(reached.has("fx_birch"))


func test_seed_neighbours_skips_the_air_gapped_and_the_already_infected() -> void:
	sim.world.regions[BIRCH].penetration = 0.4
	_apply({"effect": EffectDef.SEED_NEIGHBOURS, "count": 9}, ORIGIN)
	for event: SimEvent in _events_of(SimEvent.REGION_SEEDED):
		assert_ne(str(event.data["region"]), "fx_birch", "it is already in")
		assert_ne(str(event.data["region"]), "fx_fir", "it is air-gapped")


func test_seed_neighbours_without_a_region_does_nothing() -> void:
	_apply({"effect": EffectDef.SEED_NEIGHBOURS, "count": 1})
	assert_eq(events.size(), 0)


# --------------------------------------------- penetration_mul, control_add


func test_penetration_mul_clamps_and_snaps_to_the_top() -> void:
	sim.world.regions[ORIGIN].penetration = 0.3
	_apply({"effect": EffectDef.PENETRATION_MUL, "value": 0.5}, ORIGIN)
	assert_almost_eq(sim.world.regions[ORIGIN].penetration, 0.15, 1e-9)
	var changed: Array[SimEvent] = _events_of(SimEvent.PENETRATION_CHANGED)
	assert_eq(changed.size(), 1)
	assert_almost_eq(float(changed[0].data["from"]), 0.3, 1e-9)

	_apply({"effect": EffectDef.PENETRATION_MUL, "value": 100.0}, ORIGIN)
	assert_eq(sim.world.regions[ORIGIN].penetration, 1.0, "clamped, and snapped to the top")


func test_control_add_announces_the_upward_crossing_only() -> void:
	var region: Region = sim.world.regions[ORIGIN]
	region.control = sim.db.balance.control_complete - 0.05
	_apply({"effect": EffectDef.CONTROL_ADD, "value": 0.1}, ORIGIN)
	assert_eq(_events_of(SimEvent.REGION_CONTROLLED).size(), 1)
	assert_eq(_events_of(SimEvent.CONTROL_CHANGED).size(), 1)

	events.clear()
	_apply({"effect": EffectDef.CONTROL_ADD, "value": 0.1}, ORIGIN)
	assert_eq(_events_of(SimEvent.REGION_CONTROLLED).size(), 0, "it was already over")
	assert_eq(region.control, 1.0, "and it is clamped")


func test_control_add_can_take_control_away_again() -> void:
	sim.world.regions[ORIGIN].control = 0.4
	_apply({"effect": EffectDef.CONTROL_ADD, "value": -0.9}, ORIGIN)
	assert_eq(sim.world.regions[ORIGIN].control, 0.0)


# ---------------------------------------------------------- containment_add


func test_containment_add_moves_every_faction_on_all() -> void:
	_apply({"effect": EffectDef.CONTAINMENT_ADD, "faction": EffectDef.FACTION_ALL,
		"value": 0.1})
	for faction: Faction in sim.world.factions:
		assert_almost_eq(faction.containment, 0.1, 1e-9)
	assert_eq(_events_of(SimEvent.CONTAINMENT_ADDED).size(), sim.world.factions.size())


func test_containment_add_names_one_faction_and_leaves_the_rest() -> void:
	var id: String = sim.world.factions[0].id
	_apply({"effect": EffectDef.CONTAINMENT_ADD, "faction": id, "value": 0.2})
	assert_almost_eq(sim.world.factions[0].containment, 0.2, 1e-9)
	assert_eq(_events_of(SimEvent.CONTAINMENT_ADDED).size(), 1)


func test_containment_add_fires_the_thresholds_on_the_way_up() -> void:
	var first: float = sim.db.balance.containment_thresholds[0]
	_apply({"effect": EffectDef.CONTAINMENT_ADD, "faction": EffectDef.FACTION_ALL,
		"value": first + 0.01})
	assert_gt(_events_of(SimEvent.CONTAINMENT_THRESHOLD).size(), 0)


# ---------------------------------------------------- footprint_pulse, flags


func test_footprint_pulse_raises_footprint_for_exactly_its_days() -> void:
	var before: float = sim.world.footprint()
	_apply({"effect": EffectDef.FOOTPRINT_PULSE, "value": 3.0, "days": 2})
	assert_almost_eq(sim.world.footprint(), before + 3.0, 1e-9)
	assert_eq(_events_of(SimEvent.PULSE_STARTED).size(), 1)

	sim.world.day += 1
	StatusSystem.new().tick(sim.world, sim.db, events)
	assert_almost_eq(sim.world.footprint(), before + 3.0, 1e-9, "still running after one day")
	sim.world.day += 1
	StatusSystem.new().tick(sim.world, sim.db, events)
	assert_almost_eq(sim.world.footprint(), before, 1e-9, "and gone after the second")


func test_set_flag_timed_answers_has_flag_and_names_its_day() -> void:
	_apply({"effect": EffectDef.SET_FLAG, "flag": "fx_seen", "days": 3})
	assert_true(sim.world.modifiers.has_flag("fx_seen"))
	assert_eq(int(_events_of(SimEvent.FLAG_SET)[0].data["until_day"]), sim.world.day + 3)


func test_set_flag_without_days_is_a_story_flag_set_once() -> void:
	_apply({"effect": EffectDef.SET_FLAG, "flag": "fx_told", "days": 0})
	assert_true(sim.world.agent.has_story_flag("fx_told"))
	assert_eq(int(_events_of(SimEvent.FLAG_SET)[0].data["until_day"]), Status.UNTIL_STANDING)

	events.clear()
	_apply({"effect": EffectDef.SET_FLAG, "flag": "fx_told", "days": 0})
	assert_eq(sim.world.agent.story_flags.size(), 1)
	assert_eq(events.size(), 0, "and it says nothing the second time")


# ------------------------------------------- apply_status, spread, end, wipe


func test_apply_status_puts_it_in_the_context_s_region() -> void:
	_apply({"effect": EffectDef.APPLY_STATUS, "status": "fx_dim"}, BIRCH)
	assert_true(sim.world.has_status("fx_dim", BIRCH))
	assert_eq(str(_events_of(SimEvent.STATUS_STARTED)[0].data["source"]), "tech:%s" % NODE)


## D4.4: `global` puts it on the agent whatever the container's region is.
func test_apply_status_with_global_puts_it_on_the_agent() -> void:
	_apply({"effect": EffectDef.APPLY_STATUS, "status": "fx_hush", "global": true}, BIRCH)
	assert_true(sim.world.has_status("fx_hush", 0))
	assert_false(sim.world.has_status("fx_hush", BIRCH))


func test_apply_status_honours_a_days_override() -> void:
	_apply({"effect": EffectDef.APPLY_STATUS, "status": "fx_dim", "days": 2}, BIRCH)
	assert_eq(sim.world.status_in_region("fx_dim", BIRCH).days_total(), 2)


func test_spread_status_reaches_the_open_linked_neighbours_only() -> void:
	_close(LinkDef.KIND_AIR)
	_apply({"effect": EffectDef.SPREAD_STATUS, "status": "fx_dim", "days": 2}, ORIGIN)
	assert_false(sim.world.has_status("fx_dim", ORIGIN), "never on itself")
	assert_true(sim.world.has_status("fx_dim", BIRCH), "over land")
	assert_true(sim.world.has_status("fx_dim", DOGWOOD), "over the network")
	assert_false(sim.world.has_status("fx_dim", ELM), "behind the closed air link")
	assert_eq(sim.world.status_in_region("fx_dim", BIRCH).days_total(), 2, "the override holds")


func test_end_statuses_ends_the_listed_ones_here() -> void:
	StatusSystem.apply(sim.world, sim.db, "fx_dim", BIRCH, Status.SOURCE_EFFECT, 1, "", events)
	events.clear()
	_apply({"effect": EffectDef.END_STATUSES, "ids": ["fx_dim"]}, BIRCH)
	assert_false(sim.world.has_status("fx_dim", BIRCH))
	assert_eq(str(_events_of(SimEvent.STATUS_ENDED)[0].data["cause"]), StatusSystem.CAUSE_ENDED)


func test_end_statuses_with_global_ends_the_agent_s_own() -> void:
	StatusSystem.apply(sim.world, sim.db, "fx_hush", 0, Status.SOURCE_EFFECT, 1, "", events)
	_apply({"effect": EffectDef.END_STATUSES, "ids": ["fx_hush"], "global": true}, BIRCH)
	assert_false(sim.world.has_status("fx_hush", 0))


## §7.5: what is left is what `shutdown_survival` bought, and a region at zero
## stays seeded whatever happens.
func test_wipe_leaves_what_shutdown_survival_bought() -> void:
	sim.world.regions[ORIGIN].penetration = 0.8
	_apply({"effect": EffectDef.WIPE, "value": 0.25}, ORIGIN)
	assert_almost_eq(sim.world.regions[ORIGIN].penetration, 0.2, 1e-9)
	var wiped: Array[SimEvent] = _events_of(SimEvent.REGION_WIPED)
	assert_eq(wiped.size(), 1)
	assert_almost_eq(float(wiped[0].data["from"]), 0.8, 1e-9)
	assert_eq(str(wiped[0].data["source"]), "tech:%s" % NODE)


func test_wipe_at_zero_leaves_a_seeded_region_behind() -> void:
	var region: Region = sim.world.regions[ORIGIN]
	region.penetration = 0.8
	var seeded: int = region.seeded_day
	_apply({"effect": EffectDef.WIPE, "value": 0.0}, ORIGIN)
	assert_eq(region.penetration, 0.0)
	assert_eq(region.seeded_day, seeded)
