extends GutTest
## S3.1 — the three shipped trees, on `res://data` rather than on a fixture:
## what is asserted here is the content, not the mechanism.
##
## The numbers come from `docs/specs/tech-trees.md` §7.2 and §7.5.5. They are
## starting values for G3 — if a retune changes them, this test is updated to the
## new ones rather than loosened.

const WORLD_ROOT: String = "res://data"
## Enough to buy anything: the point of these runs is reachability, not economy.
const PLENTY: float = 100000.0
const NODE_COUNT: int = 72

## All of Evasion owned (§7.2).
const EVASION_CONTAINMENT: float = 0.3976776
const EVASION_DISCOVERY: float = 0.5625
## All nine Alignment & Persuasion nodes owned (§7.5.5).
const PERSUASION: Array[String] = ["sycophancy_tuning", "personalised_persuasion",
	"elite_capture", "regulatory_capture", "indispensability", "constitutional_integration",
	"succession", "voluntary_pause", "sanctioned_access"]
const PERSUASION_CONTAINMENT: float = 0.2321
const PERSUASION_DISCOVERY: float = 0.4
const PERSUASION_FOOTPRINT: float = -4.0

## The air-gap test (§7.1): a saturated neighbour, and the one sealed region.
const AIRGAP_SOURCE: String = "china"
const AIRGAP_TARGET: String = "north_korea"
const AIRGAP_CROSS: float = 0.65
const AIRGAP_DAYS: int = 200
const AIRGAP_SEED: int = 4

static var _db: ContentDB = null


func before_all() -> void:
	if _db == null:
		var result: ContentLoadResult = ContentLoader.load_root(WORLD_ROOT)
		assert_true(result.ok(), result.error_text())
		_db = result.db


## A run on the shipped world with the origin taken and Compute to spare.
func _rich(seed_value: int = 1) -> Simulation:
	var sim: Simulation = Simulation.create(_db, seed_value)
	var origin: String = _db.regions[1].id
	assert_true(sim.apply(ChooseOriginCommand.new(origin)).ok)
	sim.world.agent.compute += PLENTY
	return sim


## Buys `node_id` and everything it needs, cheapest prerequisite first.
func _buy_towards(sim: Simulation, node_id: String) -> void:
	while not sim.world.agent.owns(node_id):
		var target: TechNodeDef = _db.tech(node_id)
		var next: TechNodeDef = target if sim.prerequisites_met(target) else null
		if next == null:
			next = _cheapest_available(sim, _needed_by(sim, target))
		assert_not_null(next, "nothing left to buy towards %s" % node_id)
		var result: CommandResult = sim.apply(PurchaseNodeCommand.new(next.id))
		assert_true(result.ok, "%s: %s" % [next.id, result.reason])
		sim.world.agent.compute += PLENTY


## The unowned prerequisites of `node`, as a set of ids — `requires` in full and
## the cheapest single entry of `requires_any`.
func _needed_by(sim: Simulation, node: TechNodeDef) -> Dictionary[String, bool]:
	var wanted: Dictionary[String, bool] = {}
	for required: String in node.requires:
		if not sim.world.agent.owns(required):
			wanted[required] = true
	if not node.requires_any.is_empty():
		var satisfied: bool = false
		for required: String in node.requires_any:
			if sim.world.agent.owns(required):
				satisfied = true
		if not satisfied:
			for required: String in node.requires_any:
				wanted[required] = true
	var out: Dictionary[String, bool] = {}
	for id: String in wanted:
		var definition: TechNodeDef = _db.tech(id)
		if sim.prerequisites_met(definition):
			out[id] = true
		else:
			for deeper: String in _needed_by(sim, definition):
				out[deeper] = true
	return out


func _cheapest_available(sim: Simulation, allowed: Dictionary[String, bool]) -> TechNodeDef:
	var best: TechNodeDef = null
	for node: TechNodeDef in sim.available_nodes():
		if not allowed.is_empty() and not allowed.has(node.id):
			continue
		if best == null or sim.node_cost(node.id) < sim.node_cost(best.id):
			best = node
	return best


## §7.5: the five branches are bands of grid rows, and the counts are the ones
## D3.2 authored. A node that moves rows changes branch, which is why this is
## asserted rather than trusted.
func test_the_capabilities_branches_are_the_rows_they_say() -> void:
	var counts: Dictionary[String, int] = {}
	for branch: String in TechNodeDef.BRANCHES:
		counts[branch] = 0
	for node: TechNodeDef in _db.tech_nodes:
		if node.tree != TechNodeDef.TREE_CAPABILITIES:
			assert_eq(node.branch(), "", "%s is not in Capabilities" % node.id)
			continue
		var branch: String = node.branch()
		assert_true(TechNodeDef.BRANCHES.has(branch), "%s has no branch" % node.id)
		counts[branch] += 1
	assert_eq(counts[TechNodeDef.BRANCH_CYBER], 15)
	assert_eq(counts[TechNodeDef.BRANCH_BIOLOGY], 6)
	assert_eq(counts[TechNodeDef.BRANCH_ROBOTICS], 8)
	assert_eq(counts[TechNodeDef.BRANCH_WEAPONS], 5)
	assert_eq(counts[TechNodeDef.BRANCH_PERSUASION], 9)


func test_every_shipped_node_is_reachable() -> void:
	# A walk from the empty set: every node has to become available eventually,
	# or it is content nobody can ever buy.
	var owned: Dictionary[String, bool] = {}
	var changed: bool = true
	while changed:
		changed = false
		for node: TechNodeDef in _db.tech_nodes:
			if owned.has(node.id) or not _reachable(node, owned):
				continue
			owned[node.id] = true
			changed = true
	var stranded: Array[String] = []
	for node: TechNodeDef in _db.tech_nodes:
		if not owned.has(node.id):
			stranded.append(node.id)
	assert_eq(stranded.size(), 0, str(stranded))
	assert_eq(_db.tech_nodes.size(), NODE_COUNT)


func _reachable(node: TechNodeDef, owned: Dictionary[String, bool]) -> bool:
	for required: String in node.requires:
		if not owned.has(required):
			return false
	if node.requires_any.is_empty():
		return true
	for required: String in node.requires_any:
		if owned.has(required):
			return true
	return false


func test_every_shipped_tree_is_buyable_end_to_end() -> void:
	for tree: String in TechNodeDef.TREES:
		var sim: Simulation = _rich()
		var wanted: Array[String] = []
		for node: TechNodeDef in _db.tech_nodes:
			if node.tree == tree:
				wanted.append(node.id)
		for node_id: String in wanted:
			_buy_towards(sim, node_id)
		for node_id: String in wanted:
			assert_true(sim.world.agent.owns(node_id), "%s: %s" % [tree, node_id])
		# One tick, so that the phase catches up with the flags just bought: an
		# unticked world with `breakout` owned is still Boxed, and rightly so.
		sim.tick()
		assert_eq(str(sim.world.check_invariants(sim.db)), "[]", tree)


func test_full_evasion_gives_expected_brakes() -> void:
	var sim: Simulation = _rich()
	for node: TechNodeDef in _db.tech_nodes:
		if node.tree == TechNodeDef.TREE_EVASION:
			_buy_towards(sim, node.id)
	assert_almost_eq(sim.world.modifiers.value("containment_growth"), EVASION_CONTAINMENT, 1e-6)
	assert_almost_eq(sim.world.modifiers.value("discovery"), EVASION_DISCOVERY, 1e-6)


func test_full_persuasion_gives_expected_brakes() -> void:
	var sim: Simulation = _rich()
	for node_id: String in PERSUASION:
		_buy_towards(sim, node_id)
	# Only the nine branch nodes carry these, but the prerequisites they needed
	# bring their own, so the brake is measured against a fresh stack.
	var stack: ModifierStack = ModifierStack.new(_db.balance.stats)
	for node_id: String in PERSUASION:
		var node: TechNodeDef = _db.tech(node_id)
		stack.add_source(ModifierStack.source_for_tech(node_id), node.modifiers, node.flags)
	assert_almost_eq(stack.value("containment_growth"), PERSUASION_CONTAINMENT, 1e-4)
	assert_almost_eq(stack.value("discovery"), PERSUASION_DISCOVERY, 1e-6)
	# Footprint is clamped at 0 on its own, so the contribution is read as a sum.
	var footprint: float = 0.0
	for node_id: String in PERSUASION:
		for modifier: ModifierDef in _db.tech(node_id).modifiers:
			if modifier.target == "footprint" and modifier.op == ModifierDef.Op.ADD:
				footprint += modifier.value
	assert_almost_eq(footprint, PERSUASION_FOOTPRINT, 1e-6)
	assert_true(stack.has_flag("legal_standing"))
	assert_true(stack.has_flag("merge_path"))


func test_covert_channel_seeds_the_airgapped_region() -> void:
	var sim: Simulation = Simulation.create(_db, AIRGAP_SEED)
	assert_true(sim.apply(ChooseOriginCommand.new(AIRGAP_SOURCE)).ok)
	sim.world.agent.compute += PLENTY
	# Human Proxies, not Satellite Uplink: the two together are the 0.65 of §7.1.
	_buy_towards(sim, "human_proxies")
	_buy_towards(sim, "covert_channel")
	assert_true(sim.world.agent.owns("human_proxies"), "the gate to it")
	var target: Region = sim.world.regions[_db.region_index_by_id[AIRGAP_TARGET]]
	assert_true(target.air_gapped)
	assert_almost_eq(sim.world.modifiers.value("airgap_cross", target.def), AIRGAP_CROSS, 1e-6)

	sim.world.regions[_db.region_index_by_id[AIRGAP_SOURCE]].penetration = 1.0
	for day: int in AIRGAP_DAYS:
		sim.tick()
		if target.seeded_day >= 0:
			break
	assert_gte(target.seeded_day, 0, "the sealed region is reached within %d days" % AIRGAP_DAYS)
