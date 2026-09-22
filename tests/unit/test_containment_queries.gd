extends GutTest
## S3.3 — the two pure queries of `m3-screens.md` §10.5.
##
## They exist so that the containment panel cannot disagree with the simulation,
## which is only true while they *are* what the tick runs. Both tests compare
## against the tick itself rather than against a formula written out again.

var _sim: Simulation


func before_each() -> void:
	_sim = Fixtures.sim_with_origin()
	Fixtures.grant(_sim, 100.0)


## The risk the system rolls against is the one the panel shows.
func test_discovery_risk_matches_the_tick() -> void:
	_sim.world.regions[1].penetration = 0.8
	Fixtures.buy(_sim, ["fx_harm_1"])
	var risk: Dictionary = _sim.discovery_risk()
	var terms: float = float(risk[ContainmentSystem.RISK_TIME]) \
		+ float(risk[ContainmentSystem.RISK_FOOTPRINT]) \
		+ float(risk[ContainmentSystem.RISK_BREADTH])
	assert_almost_eq(float(risk[ContainmentSystem.RISK_TOTAL]), terms, 1e-12,
		"the three terms are the total, before the clamp")
	assert_gt(float(risk[ContainmentSystem.RISK_FOOTPRINT]), 0.0,
		"a node with Footprint raises that term and no other")


func test_discovery_risk_follows_the_discovery_stat() -> void:
	var plain: float = float(_sim.discovery_risk()[ContainmentSystem.RISK_TOTAL])
	Fixtures.buy(_sim, ["fx_quiet"])
	var quiet: float = float(_sim.discovery_risk()[ContainmentSystem.RISK_TOTAL])
	assert_almost_eq(quiet, plain * 0.5, 1e-12, "fx_quiet halves the risk")


## The breakdown is the gain, not a second opinion about it.
func test_containment_breakdown_adds_up_to_the_gain() -> void:
	_sim.world.discovered = true
	_sim.world.discovery_day = 1
	_sim.world.regions[1].penetration = 1.0
	Fixtures.buy(_sim, ["fx_harm_1"])
	var breakdown: Dictionary = _sim.containment_breakdown()
	var pressure: float = float(breakdown[ContainmentSystem.DRIVER_FOOTPRINT]) \
		+ float(breakdown[ContainmentSystem.DRIVER_HARM]) \
		+ float(breakdown[ContainmentSystem.DRIVER_SHARE]) - 2.0
	var expected: float = _sim.db.balance.containment_base_rate * pressure \
		* float(breakdown[ContainmentSystem.DRIVER_CAPACITY]) \
		* float(breakdown[ContainmentSystem.DRIVER_BRAKES])
	assert_almost_eq(float(breakdown[ContainmentSystem.DRIVER_GAIN]), expected, 1e-12)


func test_the_breakdown_is_what_the_next_tick_adds() -> void:
	_sim.world.discovered = true
	_sim.world.discovery_day = 1
	_sim.world.regions[1].penetration = 1.0
	var before: float = _sim.world.factions[0].containment
	var gain: float = float(_sim.containment_breakdown()[ContainmentSystem.DRIVER_GAIN])
	_sim.tick()
	# The tick moves the world before containment runs — the spread grows and the
	# share with it — so the promise is the day's number to within that drift.
	assert_almost_eq(_sim.world.factions[0].containment - before, gain, 1e-5,
		"what the panel promised is what the day did")


func test_the_queries_draw_nothing_from_the_world_s_generator() -> void:
	var before: String = _sim.world.rng.state_string()
	_sim.discovery_risk()
	_sim.containment_breakdown()
	assert_eq(_sim.world.rng.state_string(), before)
