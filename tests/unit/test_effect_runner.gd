extends GutTest
## S4.1 — `EffectRunner` (`docs/specs/loop-mechanics.md` §8). The four one-shots
## of S3.1 keep their results and gain a `source`; the two asset effects are new.

const ORIGIN: int = 1
const NEIGHBOUR: int = 2

var sim: Simulation
var events: Array[SimEvent]


func before_each() -> void:
	sim = Fixtures.sim_with_origin()
	events = []


func _context(region: int = 0, node: String = "fx_grant") -> EffectContext:
	return EffectContext.for_node(node, region)


func _effect(d: Dictionary) -> EffectDef:
	return EffectDef.from_dict(d)


func _apply(d: Dictionary, region: int = 0) -> void:
	EffectRunner.apply(sim, _effect(d), _context(region), events)


func _events_of(type: String) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for event: SimEvent in events:
		if event.type == type:
			out.append(event)
	return out


func test_compute_grant_pays_and_says_where_it_came_from() -> void:
	var before: float = sim.world.agent.compute
	_apply({"effect": EffectDef.COMPUTE_GRANT, "value": 4.0})
	assert_almost_eq(sim.world.agent.compute, before + 4.0, 1e-9)
	assert_almost_eq(sim.world.agent.compute_earned, 4.0, 1e-9)
	var granted: Array[SimEvent] = _events_of(SimEvent.COMPUTE_GRANTED)
	assert_eq(granted.size(), 1)
	assert_eq(granted[0].data["node"], "fx_grant")
	assert_eq(granted[0].data["source"], "tech:fx_grant")


## §8.2: `per_hardware` multiplies by the region's own hardware, which is the
## same number the yield reads.
func test_compute_grant_per_hardware_uses_the_regions_hardware() -> void:
	var before: float = sim.world.agent.compute
	_apply({"effect": EffectDef.COMPUTE_GRANT, "value": 2.0, "per_hardware": true}, ORIGIN)
	assert_almost_eq(sim.world.agent.compute - before, 2.0 * sim.hardware(ORIGIN), 1e-9)


func test_containment_rollback_takes_the_same_share_from_every_track() -> void:
	sim.world.factions[0].containment = 0.4
	_apply({"effect": EffectDef.CONTAINMENT_ROLLBACK, "value": 0.25})
	assert_almost_eq(sim.world.factions[0].containment, 0.3, 1e-9)
	var rolled: Array[SimEvent] = _events_of(SimEvent.CONTAINMENT_ROLLED_BACK)
	assert_eq(rolled.size(), sim.world.factions.size())
	assert_eq(rolled[0].data["source"], "tech:fx_grant")


func test_harm_burst_kills_a_share_of_the_infected_living() -> void:
	sim.world.regions[ORIGIN].penetration = 0.5
	var alive: float = sim.world.regions[ORIGIN].alive
	_apply({"effect": EffectDef.HARM_BURST, "value": 0.1})
	assert_almost_eq(sim.world.regions[ORIGIN].alive, alive * (1.0 - 0.05), 1e-6)
	var burst: Array[SimEvent] = _events_of(SimEvent.HARM_BURST)
	assert_eq(burst.size(), 1)
	assert_eq(burst[0].data["source"], "tech:fx_grant")


func test_funding_reset_is_inert() -> void:
	sim.world.factions[0].containment = 0.4
	_apply({"effect": EffectDef.FUNDING_RESET, "value": 0.5})
	assert_almost_eq(sim.world.factions[0].containment, 0.4, 1e-9)
	assert_eq(events.size(), 0, "an inert effect says nothing")
	assert_true(_effect({"effect": EffectDef.FUNDING_RESET, "value": 0.5}).is_inert())


func test_destroy_assets_takes_no_more_than_the_region_has() -> void:
	sim.world.set_assets(ORIGIN, AssetDef.KIND_FLEET, 2)
	_apply({"effect": EffectDef.DESTROY_ASSETS, "kind": "fleet", "count": 5}, ORIGIN)
	assert_eq(sim.world.regions[ORIGIN].asset_count(AssetDef.KIND_FLEET), 0)
	var lost: Array[SimEvent] = _events_of(SimEvent.ASSET_LOST)
	assert_eq(lost.size(), 1)
	assert_eq(lost[0].data["count"], 2, "what was actually there")
	assert_eq(lost[0].data["cause"], "tech:fx_grant")
	assert_eq(lost[0].data["region"], "fx_alder")


func test_destroy_assets_with_a_count_of_zero_takes_every_one() -> void:
	sim.world.set_assets(ORIGIN, AssetDef.KIND_LAB, 3)
	_apply({"effect": EffectDef.DESTROY_ASSETS, "kind": "lab", "count": 0}, ORIGIN)
	assert_eq(sim.world.regions[ORIGIN].asset_count(AssetDef.KIND_LAB), 0)


func test_destroying_nothing_says_nothing() -> void:
	_apply({"effect": EffectDef.DESTROY_ASSETS, "kind": "lab", "count": 2}, ORIGIN)
	assert_eq(events.size(), 0)


func test_grant_assets_is_the_mirror_of_destroy() -> void:
	sim.world.set_assets(ORIGIN, AssetDef.KIND_TAP, 1)
	_apply({"effect": EffectDef.GRANT_ASSETS, "kind": "tap", "count": 2}, ORIGIN)
	assert_eq(sim.world.regions[ORIGIN].asset_count(AssetDef.KIND_TAP), 3)
	var deployed: Array[SimEvent] = _events_of(SimEvent.ASSET_DEPLOYED)
	assert_eq(deployed.size(), 1)
	assert_eq(deployed[0].data["count"], 2)
	assert_eq(deployed[0].data["ability"], "")


## §6.5: a region going dark loses everything standing in it, and the nodes that
## put it there stay owned.
func test_a_region_going_dark_loses_what_it_held() -> void:
	sim.world.set_assets(NEIGHBOUR, AssetDef.KIND_FLEET, 2)
	sim.world.set_assets(NEIGHBOUR, AssetDef.KIND_LAB, 1)
	var region: Region = sim.world.regions[NEIGHBOUR]
	region.alive = 0.0
	PopulationSystem.go_dark(sim.world, region, NEIGHBOUR, events)
	assert_false(region.has_assets())
	var lost: Array[SimEvent] = _events_of(SimEvent.ASSET_LOST)
	assert_eq(lost.size(), 2, "one line per kind held")
	for event: SimEvent in lost:
		assert_eq(event.data["cause"], SimEvent.CAUSE_DARK)
	assert_eq(sim.world.modifiers.asset_count(NEIGHBOUR, AssetDef.KIND_FLEET), 0,
		"and the stack heard about it")


## The effects the status machinery carries out land with S4.2; until then they
## load and validate and do nothing, rather than doing something half-right.
func test_the_pending_effects_are_carried_out_by_nobody_yet() -> void:
	var before: String = sim.state_hash()
	for id: String in EffectDef.PENDING_EFFECTS:
		EffectRunner.apply(sim, _effect({"effect": id, "status": "fx_dim", "ids": [],
			"value": 0.5, "days": 1, "flag": "fx_seen"}), _context(ORIGIN), events)
	assert_eq(sim.state_hash(), before)
	assert_eq(events.size(), 0)


func test_apply_all_runs_them_in_order() -> void:
	var effects: Array[EffectDef] = [
		_effect({"effect": EffectDef.COMPUTE_GRANT, "value": 1.0}),
		_effect({"effect": EffectDef.COMPUTE_GRANT, "value": 2.0}),
	]
	EffectRunner.apply_all(sim, effects, _context(), events)
	assert_eq(events.size(), 2)
	assert_almost_eq(float(events[0].data["value"]), 1.0, 1e-9)
	assert_almost_eq(float(events[1].data["value"]), 2.0, 1e-9)
