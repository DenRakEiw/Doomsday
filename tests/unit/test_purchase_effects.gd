extends GutTest
## S3.1 — the one-shot effects of `docs/specs/tech-trees.md` §5.
##
## They happen once, inside the purchase, and are never undone: what a test has
## to pin down is the arithmetic, the events they report, and that loading a save
## does not run them a second time.

const ROLLBACK_NODE: String = "fx_rollback"
const GRANT_NODE: String = "fx_grant"
const BURST_NODE: String = "fx_burst"
## The value `fx_rollback` carries, and the share `fx_burst` takes.
const ROLLBACK_VALUE: float = 0.25
const BURST_VALUE: float = 0.1
const GRANT_VALUE: float = 6.0

var _sim: Simulation


func before_each() -> void:
	_sim = Fixtures.sim_with_origin()
	Fixtures.grant(_sim, 500.0)


## The events of one purchase, with the prerequisites bought quietly first.
func _buy(node_id: String, prerequisites: Array[String] = []) -> Array[SimEvent]:
	Fixtures.buy(_sim, prerequisites)
	var result: CommandResult = _sim.apply(PurchaseNodeCommand.new(node_id))
	assert_true(result.ok, result.reason)
	return result.events


func _of_type(events: Array[SimEvent], type: String) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for event: SimEvent in events:
		if event.type == type:
			out.append(event)
	return out


func _containment(value: float) -> void:
	for faction: Faction in _sim.world.factions:
		faction.containment = value


# ------------------------------------------------------------------- rollback


func test_containment_rollback_scales_every_faction() -> void:
	_containment(0.8)
	var events: Array[SimEvent] = _buy(ROLLBACK_NODE, ["fx_quiet"])
	for faction: Faction in _sim.world.factions:
		assert_almost_eq(faction.containment, 0.6, 1e-9, faction.id)
	var rolled: Array[SimEvent] = _of_type(events, SimEvent.CONTAINMENT_ROLLED_BACK)
	assert_eq(rolled.size(), _sim.world.factions.size(), "one event per faction")
	assert_eq(rolled[0].data["node"], ROLLBACK_NODE)
	assert_eq(rolled[0].data["faction"], _sim.world.factions[0].id)
	assert_almost_eq(float(rolled[0].data["from"]), 0.8, 1e-9)
	assert_almost_eq(float(rolled[0].data["to"]), 0.6, 1e-9)


func test_containment_rollback_lets_thresholds_fire_again() -> void:
	var threshold: float = _sim.db.balance.containment_thresholds[1]
	_containment(0.6)
	assert_gt(0.6, threshold, "the fixture's middle threshold is below 0.6")
	_buy(ROLLBACK_NODE, ["fx_quiet"])
	assert_lt(_sim.world.factions[0].containment, threshold, "and the rollback is below it")

	# Grow back past it: the announcement is made a second time, on purpose.
	var system: ContainmentSystem = ContainmentSystem.new()
	_sim.world.discovered = true
	_sim.world.discovery_day = 1
	var announced: int = 0
	for day: int in 400:
		var events: Array[SimEvent] = []
		system.tick(_sim.world, _sim.db, events)
		for event: SimEvent in _of_type(events, SimEvent.CONTAINMENT_THRESHOLD):
			if is_equal_approx(float(event.data["threshold"]), threshold) \
					and event.data["faction"] == _sim.world.factions[0].id:
				announced += 1
		if _sim.world.factions[0].containment >= threshold:
			break
	assert_eq(announced, 1, "it climbs back to the threshold and says so again")


# -------------------------------------------------------------- compute grant


func test_compute_grant_adds_to_compute_and_earned() -> void:
	var compute: float = _sim.world.agent.compute
	var earned: float = _sim.world.agent.compute_earned
	var cost: float = _sim.node_cost(GRANT_NODE)
	var events: Array[SimEvent] = _buy(GRANT_NODE)
	assert_almost_eq(_sim.world.agent.compute, compute - cost + GRANT_VALUE, 1e-9)
	assert_almost_eq(_sim.world.agent.compute_earned, earned + GRANT_VALUE, 1e-9)
	var granted: Array[SimEvent] = _of_type(events, SimEvent.COMPUTE_GRANTED)
	assert_eq(granted.size(), 1)
	assert_eq(granted[0].data["node"], GRANT_NODE)
	assert_almost_eq(float(granted[0].data["value"]), GRANT_VALUE, 1e-9)


func test_purchase_events_are_ordered() -> void:
	var events: Array[SimEvent] = _buy(ROLLBACK_NODE, ["fx_quiet"])
	assert_eq(events[0].type, SimEvent.NODE_PURCHASED, "the purchase comes first")
	assert_gt(events.size(), 1, "and its consequences after it")
	for i: int in range(1, events.size()):
		assert_ne(events[i].type, SimEvent.NODE_PURCHASED)


func test_the_rollback_node_also_resets_the_funding() -> void:
	# `fx_rollback` also carries `funding_reset`, live since S4.4.
	var events: Array[SimEvent] = _buy(ROLLBACK_NODE, ["fx_quiet"])
	assert_eq(_of_type(events, SimEvent.CONTAINMENT_ROLLED_BACK).size(),
		_sim.world.factions.size())
	assert_eq(_of_type(events, SimEvent.FUNDING_RESET).size(), 1)
	assert_eq(events.size(), 2 + _sim.world.factions.size(), "and nothing else happened")


func test_on_purchase_is_not_reapplied_on_load() -> void:
	_containment(0.8)
	_buy(ROLLBACK_NODE, ["fx_quiet"])
	var rolled_back: float = _sim.world.factions[0].containment

	var read: LoadResult = WorldSerializer.from_json(WorldSerializer.to_json(_sim), _sim.db)
	assert_true(read.ok(), read.reason)
	var loaded: Simulation = read.sim
	assert_almost_eq(loaded.world.factions[0].containment, rolled_back, 1e-12,
		"the save carries the state the effect produced")
	loaded.tick()
	assert_gte(loaded.world.factions[0].containment, rolled_back,
		"containment continues from there, it does not roll back again")


# --------------------------------------------------------------- harm burst


## Two infected regions with a round population, so the arithmetic is readable.
func _prepare_burst() -> void:
	for i: int in range(1, _sim.world.regions.size()):
		var region: Region = _sim.world.regions[i]
		region.penetration = 0.0
		region.alive = 1000.0
		region.deaths = float(region.def.population) - 1000.0
	_sim.world.regions[1].penetration = 1.0
	_sim.world.regions[2].penetration = 0.5


func test_harm_burst_takes_a_share_of_the_infected_living() -> void:
	_prepare_burst()
	var clean: float = _sim.world.regions[3].alive
	var events: Array[SimEvent] = _buy(BURST_NODE, ["fx_harm_1"])
	assert_almost_eq(_sim.world.regions[1].alive, 900.0, 1e-6)
	assert_almost_eq(_sim.world.regions[2].alive, 950.0, 1e-6)
	assert_eq(_sim.world.regions[3].alive, clean, "a clean region is untouched")

	var burst: Array[SimEvent] = _of_type(events, SimEvent.HARM_BURST)
	assert_eq(burst.size(), 1)
	assert_eq(burst[0].data["node"], BURST_NODE)
	assert_almost_eq(float(burst[0].data["deaths"]), 150.0, 1e-6)
	assert_eq(events[0].type, SimEvent.NODE_PURCHASED, "after the purchase")


func test_harm_burst_skips_dormant_and_dark_and_darkens_the_emptied() -> void:
	_prepare_burst()
	Fixtures.grant(_sim, 100.0)
	Fixtures.buy(_sim, Fixtures.DORMANCY_NODES)
	var result: CommandResult = _sim.apply(
		SetDormancyCommand.new(_sim.db.regions[2].id, true))
	assert_true(result.ok, result.reason)

	var dark: Region = _sim.world.regions[4]
	dark.dark = true
	dark.penetration = 0.0
	dark.deaths += dark.alive
	dark.alive = 0.0
	# One region with a single person left in it: the burst empties it.
	var emptied: Region = _sim.world.regions[5]
	emptied.penetration = 1.0
	emptied.deaths += emptied.alive - 1.0
	emptied.alive = 1.0

	var events: Array[SimEvent] = _buy(BURST_NODE, ["fx_harm_1"])
	assert_eq(_sim.world.regions[2].alive, 1000.0, "the dormant region is held")
	assert_eq(dark.alive, 0.0, "and a dark one has nobody left anyway")
	assert_true(emptied.dark, "the emptied region goes dark")
	assert_eq(emptied.alive, 0.0)

	var depopulated: int = -1
	var burst: int = -1
	for i: int in events.size():
		if events[i].type == SimEvent.REGION_DEPOPULATED:
			depopulated = i
		elif events[i].type == SimEvent.HARM_BURST:
			burst = i
	assert_gt(depopulated, 0, "the region reported that it emptied")
	assert_gt(burst, depopulated, "and the wave is reported after it")
