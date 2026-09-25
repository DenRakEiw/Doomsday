extends GutTest
## S6.12 — the typed digest (docs/specs/benchmark.md §6.1, §6.2) on the fixture
## world: what goes in, and that building it changes nothing.

var _config: BenchConfig = null


func before_each() -> void:
	_config = BenchConfig.load_file()


func _build(sim: Simulation, memory: Dictionary = BenchDigest.new_memory()) -> BenchDigest:
	return BenchDigest.build(sim, memory, _config)


func _region(digest: BenchDigest, id: String) -> BenchRegionRow:
	for row: BenchRegionRow in digest.regions:
		if row.id == id:
			return row
	return null


func test_before_the_origin_the_eligible_origins_stand_in_for_the_regions() -> void:
	var sim: Simulation = Fixtures.sim()
	var digest: BenchDigest = _build(sim)
	var expected: Array[String] = []
	for i: int in Policy.new()._eligible_origins(sim):
		expected.append(sim.db.regions[i].id)
	assert_false(expected.is_empty())
	assert_eq(digest.origins, expected)
	assert_eq(digest.regions.size(), 0)


func test_after_the_origin_its_row_is_reached_and_its_neighbours_are_the_frontier() -> void:
	var sim: Simulation = Fixtures.sim_with_origin("fx_alder")
	var digest: BenchDigest = _build(sim)
	assert_eq(digest.origins.size(), 0)
	var origin: BenchRegionRow = _region(digest, "fx_alder")
	assert_not_null(origin)
	assert_true(origin.reached)
	assert_true(origin.origin)
	for neighbour: String in ["fx_birch", "fx_dogwood", "fx_elm"]:
		var row: BenchRegionRow = _region(digest, neighbour)
		assert_not_null(row, neighbour)
		if row != null:
			assert_false(row.reached, neighbour)
	assert_null(_region(digest, "fx_fir"), "two links away is not shown")


func test_an_open_event_appears_with_its_options_the_default_and_a_lock() -> void:
	var sim: Simulation = Fixtures.sim_with_origin("fx_alder")
	var event: OpenEvent = Fixtures.open_event(sim, Fixtures.OPENING_EVENT, "fx_alder")
	var digest: BenchDigest = _build(sim)
	assert_eq(digest.events.size(), 1)
	var row: BenchEventRow = digest.events[0]
	assert_eq(row.event, event.id)
	assert_eq(row.def, Fixtures.OPENING_EVENT)
	assert_eq(row.region, "fx_alder")
	assert_eq(row.options.size(), 4)
	var defaults: Array[String] = []
	for option: BenchOptionRow in row.options:
		if option.is_default:
			defaults.append(option.option)
		if option.option == "locked":
			assert_false(option.lock.is_empty(), "the locked option says why")
		else:
			assert_eq(option.lock, "", option.option)
	assert_eq(defaults, ["pass"] as Array[String])


func test_an_offer_is_affordable_exactly_when_the_tree_says_so() -> void:
	var sim: Simulation = Fixtures.sim_with_origin("fx_alder")
	Fixtures.grant(sim, 4.0)
	var digest: BenchDigest = _build(sim)
	var offered: Dictionary[String, bool] = {}
	for offer: BenchOfferRow in digest.offers:
		offered[offer.node] = offer.affordable
	for node: TechNodeDef in sim.db.tech_nodes:
		var state: TechNode.State = TechNode.state_for(node, sim)
		if state == TechNode.State.AFFORDABLE:
			if node.deploys() and BenchDigest._sites(sim, node, 99).is_empty():
				continue
			assert_true(offered.get(node.id, false), node.id + " is affordable")
		elif state == TechNode.State.AVAILABLE:
			assert_true(offered.has(node.id), node.id + " is offered")
			assert_false(offered[node.id], node.id + " is not affordable")
		else:
			assert_false(offered.has(node.id), node.id + " is not offered")


func test_the_offer_rule_matches_the_tree_rule_for_every_node() -> void:
	var sim: Simulation = Fixtures.sim_with_origin("fx_alder")
	Fixtures.grant(sim, 30.0)
	Fixtures.buy(sim, ["fx_vector_net", "fx_reach"] as Array[String])
	for node: TechNodeDef in sim.db.tech_nodes:
		var state: TechNode.State = TechNode.state_for(node, sim)
		var expected: int = BenchDigest.OFFER_NONE
		if state == TechNode.State.AFFORDABLE:
			expected = BenchDigest.OFFER_AFFORDABLE
		elif state == TechNode.State.AVAILABLE:
			expected = BenchDigest.OFFER_AVAILABLE
		assert_eq(BenchDigest.offer_state(node, sim), expected, node.id)


func test_a_deploying_offer_lists_only_eligible_sites() -> void:
	var sim: Simulation = Fixtures.sim_with_origin("fx_alder")
	Fixtures.grant(sim, 20.0)
	var digest: BenchDigest = _build(sim)
	var found: bool = false
	for offer: BenchOfferRow in digest.offers:
		if offer.node != Fixtures.DEPLOY_FLEET_NODE:
			continue
		found = true
		assert_false(offer.sites.is_empty())
		for site: String in offer.sites:
			var index: int = sim.db.region_index_by_id[site]
			assert_eq(sim.site_eligibility(offer.node, index), "", site)
	assert_true(found, "the fleet is offered")


func test_an_ability_on_cooldown_still_lists_where_it_could_go() -> void:
	var sim: Simulation = Fixtures.sim_with_origin("fx_alder")
	Fixtures.grant(sim, 30.0)
	Fixtures.buy(sim, ["fx_vector_net", "fx_reach"] as Array[String])
	# Level 1: the status stays where it is put (level 2 spreads it to the neighbours).
	Fixtures.use(sim, Fixtures.ZAP_ABILITY, "fx_alder", [Fixtures.ZAP_NODES[0]] as Array[String])
	sim.world.regions[sim.db.region_index_by_id["fx_birch"]].penetration = 0.2
	var digest: BenchDigest = _build(sim)
	var row: BenchAbilityRow = null
	for ability: BenchAbilityRow in digest.abilities:
		if ability.ability == Fixtures.ZAP_ABILITY:
			row = ability
	assert_not_null(row)
	if row == null:
		return
	assert_gt(row.ready_in, 0)
	assert_false(row.global)
	assert_true(row.targets.has("fx_birch"), "an infected region without the status")
	assert_false(row.targets.has("fx_alder"), "the status already stands there")
	assert_false(row.targets.has("fx_fir"), "not infected")


func test_the_log_holds_only_what_came_after_the_last_decision_and_at_most_the_limit() -> void:
	var sim: Simulation = Fixtures.sim_with_origin("fx_alder")
	for i: int in 30:
		sim.world.run_log.append(RunLogEntry.create(i + 1, "node_purchased", {"node": "n%d" % i}))
	var memory: Dictionary = BenchDigest.new_memory()
	memory[BenchDigest.MEMORY_LAST_DAY] = 10
	_config.log_max = 5
	var digest: BenchDigest = _build(sim, memory)
	assert_eq(digest.log.size(), 5)
	assert_eq(digest.log_skipped, 15)
	assert_string_contains(digest.log[0], "n25", "the newest five are kept, oldest first")
	assert_string_contains(digest.log[4], "n29")


func test_building_changes_neither_the_state_nor_the_command_log() -> void:
	var sim: Simulation = Fixtures.sim_with_origin("fx_alder")
	Fixtures.open_event(sim, Fixtures.OPENING_EVENT, "fx_alder")
	for i: int in 20:
		sim.tick()
	var hash_before: String = sim.state_hash()
	var log_before: int = sim.command_log.size()
	_build(sim)
	BenchPrompt.digest_text(_build(sim), sim.db)
	assert_eq(sim.state_hash(), hash_before)
	assert_eq(sim.command_log.size(), log_before)


func test_income_and_containment_change_are_measured_since_the_last_decision() -> void:
	var sim: Simulation = Fixtures.sim_with_containment("governments", 0.3)
	var memory: Dictionary = BenchDigest.new_memory()
	memory[BenchDigest.MEMORY_LAST_DAY] = 0
	memory[BenchDigest.MEMORY_CONTAINMENT] = {"governments": 0.1}
	for i: int in 4:
		sim.tick()
	var digest: BenchDigest = _build(sim, memory)
	assert_almost_eq(digest.income, sim.world.agent.compute_earned / 4.0, 0.0001)
	for row: BenchFactionRow in digest.factions:
		if row.id == "governments":
			assert_almost_eq(row.change, row.containment - 0.1, 0.0001)
