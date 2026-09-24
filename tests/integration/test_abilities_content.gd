extends GutTest
## S4.6 — the v3 trees and the ten abilities on `res://data` (loop-content §3,
## §6, §15.1): the groups, the two doors, what every deploying node places,
## Release's labs, every ability at both levels, and the passive changes. Every
## cost and cooldown is read from the file.

const Harness := preload("res://tools/sim_harness.gd")
const WORLD_ROOT: String = "res://data"
const PLENTY: float = 100000.0
const EVERYWHERE: float = 0.3
const VECTORS: String = "vectors"
const VECTOR_CAP: int = 2
const VECTOR_COUNT: int = 7
const MERGE_DOOR: Array[String] = ["indispensability", "constitutional_integration",
	"succession"]
const TERROR_DOOR: Array[String] = ["autonomous_engagement", "false_attribution",
	"launch_authority", "dead_hand_override", "release"]
const RELEASE: String = "release"
const RELEASE_LABS: int = 2
## Cyber's standing Footprint after the v3 passive changes (loop-content §3.2).
const CYBER_FOOTPRINT: float = 14.0
const CYBER_NODES: int = 15
const GREEDY_DAYS: int = 900

static var _db: ContentDB = null


func before_all() -> void:
	if _db == null:
		var result: ContentLoadResult = ContentLoader.load_root(WORLD_ROOT)
		assert_true(result.ok(), result.error_text())
		_db = result.db


## Origin taken, Compute to spare, the agent in every region.
func _rich() -> Simulation:
	var sim: Simulation = Simulation.create(_db, 1)
	assert_true(sim.apply(ChooseOriginCommand.new(_db.regions[1].id)).ok)
	sim.world.agent.compute += PLENTY
	for i: int in range(1, sim.world.regions.size()):
		sim.world.regions[i].penetration = maxf(sim.world.regions[i].penetration, EVERYWHERE)
		sim.world.regions[i].seeded_day = maxi(sim.world.regions[i].seeded_day, 0)
	return sim


## Owns `node_ids` without buying them — prerequisites, groups and doors are the
## other tests' business; here the question is what owning them does.
func _own(sim: Simulation, node_ids: Array[String]) -> void:
	for node_id: String in node_ids:
		if not sim.world.agent.owns(node_id):
			sim.world.agent.owned_nodes.append(node_id)
	sim.rebuild_modifiers()


func _first_site(sim: Simulation, node: TechNodeDef) -> String:
	for i: int in range(1, _db.regions.size()):
		if sim.site_eligibility(node.id, i).is_empty():
			return _db.regions[i].id
	return ""


# ---------------------------------------------------------------------- trees


func test_the_seven_vectors_share_a_group_of_two() -> void:
	assert_eq(_db.groups.get(VECTORS, 0), VECTOR_CAP)
	var members: Array[String] = []
	for node: TechNodeDef in _db.tech_nodes:
		if node.group == VECTORS:
			members.append(node.id)
			assert_eq(node.tree, TechNodeDef.TREE_INFILTRATION, node.id)
			assert_eq(node.tier, 1, node.id)
	assert_eq(members.size(), VECTOR_COUNT)


func test_the_two_doors_list_each_other_in_full() -> void:
	for merge: String in MERGE_DOOR:
		for terror: String in TERROR_DOOR:
			assert_true(_db.tech(merge).excludes.has(terror), "%s excludes %s" % [merge, terror])
			assert_true(_db.tech(terror).excludes.has(merge), "%s excludes %s" % [terror, merge])


func test_one_door_closes_the_other() -> void:
	var sim: Simulation = _rich()
	_own(sim, ["indispensability"] as Array[String])
	for terror: String in TERROR_DOOR:
		assert_eq(sim.excluded_by(terror), "indispensability", terror)
	var other: Simulation = _rich()
	_own(other, [RELEASE] as Array[String])
	for merge: String in MERGE_DOOR:
		assert_eq(other.excluded_by(merge), RELEASE, merge)


func test_every_deploying_node_places_its_kind_and_count() -> void:
	for node: TechNodeDef in _db.tech_nodes:
		if not node.deploys():
			continue
		var sim: Simulation = _rich()
		_own(sim, node.requires)
		if not node.requires_any.is_empty():
			_own(sim, [node.requires_any[0]] as Array[String])
		var site: String = _first_site(sim, node)
		assert_ne(site, "", "%s has somewhere to stand" % node.id)
		var index: int = _db.region_index_by_id[site]
		var before: int = sim.world.regions[index].asset_count(node.deploy_kind)
		var result: CommandResult = sim.apply(PurchaseNodeCommand.new(node.id, site))
		assert_true(result.ok, "%s: %s" % [node.id, result.reason])
		assert_eq(sim.world.regions[index].asset_count(node.deploy_kind) - before,
			node.deploy_count, node.id)


func test_release_needs_two_labs_and_loses_them_to_a_purge() -> void:
	var sim: Simulation = _rich()
	var release: TechNodeDef = _db.tech(RELEASE)
	_own(sim, release.requires)
	assert_eq(release.requires_assets.get(AssetDef.KIND_LAB, 0), RELEASE_LABS)
	assert_eq(sim.can_apply(PurchaseNodeCommand.new(RELEASE)), Command.FAIL_MISSING_ASSETS)
	sim.world.set_assets(1, AssetDef.KIND_LAB, 1)
	sim.world.set_assets(2, AssetDef.KIND_LAB, 1)
	assert_eq(sim.can_apply(PurchaseNodeCommand.new(RELEASE)), "")
	# A purge that takes one lab closes it again.
	sim.world.set_assets(2, AssetDef.KIND_LAB, 0)
	assert_eq(sim.can_apply(PurchaseNodeCommand.new(RELEASE)), Command.FAIL_MISSING_ASSETS)


func test_cyber_stands_on_fourteen_footprint_and_no_harm() -> void:
	var cyber: Array[String] = []
	for node: TechNodeDef in _db.tech_nodes:
		if node.branch() == TechNodeDef.BRANCH_CYBER:
			cyber.append(node.id)
	assert_eq(cyber.size(), CYBER_NODES)
	var stack: ModifierStack = ModifierStack.new(_db.balance.stats)
	var footprint: float = 0.0
	for node_id: String in cyber:
		var node: TechNodeDef = _db.tech(node_id)
		stack.add_source(ModifierStack.source_for_tech(node_id), node.modifiers, node.flags)
		for modifier: ModifierDef in node.modifiers:
			if modifier.target == "footprint" and modifier.op == ModifierDef.Op.ADD \
					and modifier.scope_kind == ModifierDef.ScopeKind.NONE:
				footprint += modifier.value
	assert_almost_eq(footprint, CYBER_FOOTPRINT, 1e-9)
	assert_eq(stack.value("harm"), 0.0, "what Cyber does to the world is a button now")
	assert_eq(stack.value("society_pressure"), 0.0)


# ------------------------------------------------------------------ abilities


func test_every_ability_climbs_its_levels_along_its_nodes() -> void:
	# Eleven from nodes (Misdirect joined in S5.5); Restraint (S5.2) is the
	# Weapon's and has none.
	assert_eq(_db.abilities.size(), 12)
	for ability: AbilityDef in _db.abilities:
		var sim: Simulation = _rich()
		assert_eq(sim.ability_level(ability.id), 0, ability.id)
		for i: int in ability.levels_from.size():
			_own(sim, [ability.levels_from[i]] as Array[String])
			assert_eq(sim.ability_level(ability.id), i + 1, ability.id)


func test_every_ability_is_usable_at_every_level() -> void:
	for ability: AbilityDef in _db.abilities:
		for level: int in range(1, ability.levels_from.size() + 1):
			_use_at(ability, level)


func _use_at(ability: AbilityDef, level: int) -> void:
	var sim: Simulation = _rich()
	for i: int in level:
		_own(sim, [ability.levels_from[i]] as Array[String])
	# Misdirect (S5.5) needs a team to mislead; one stands in the origin.
	sim.world.task_force.state = TaskForce.STATE_REST
	sim.world.task_force.region = sim.world.agent.origin
	sim.world.task_force.level = 1
	# Whatever the eligibility asks for on the ground, every region has it.
	for i: int in range(1, sim.world.regions.size()):
		for kind: String in AssetDef.KINDS:
			sim.world.set_assets(i, kind, 1)
	var region: String = ""
	if ability.targets_region():
		for i: int in range(1, _db.regions.size()):
			var probe: UseAbilityCommand = UseAbilityCommand.new(ability.id, _db.regions[i].id)
			if sim.can_apply(probe).is_empty():
				region = _db.regions[i].id
				break
		assert_ne(region, "", "%s L%d: some region is eligible" % [ability.id, level])
	var compute: float = sim.world.agent.compute
	var result: CommandResult = sim.apply(UseAbilityCommand.new(ability.id, region))
	assert_true(result.ok, "%s L%d: %s" % [ability.id, level, result.reason])
	if not result.ok:
		return
	assert_almost_eq(sim.world.agent.compute,
		compute - ability.cost + _granted(result.events), 1e-6, ability.id)
	assert_eq(sim.ability_ready_day(ability.id), sim.world.day + ability.cooldown_days,
		ability.id)
	if not ability.applies_status.is_empty():
		var index: int = 0 if region.is_empty() else _db.region_index_by_id[region]
		var status: Status = sim.world.status_in_region(ability.applies_status, index)
		assert_not_null(status, "%s L%d applies %s" % [ability.id, level, ability.applies_status])
		if status != null:
			var levels: int = _db.status(ability.applies_status).levels.size()
			assert_eq(status.level, mini(level, levels), "%s at level %d" % [ability.id, level])
	if ability.applies_deploy_kind == AssetDef.KIND_FLEET:
		var fleets: int = sim.world.regions[_db.region_index_by_id[region]].asset_count(
			AssetDef.KIND_FLEET)
		assert_eq(fleets, 1 + ability.applies_deploy_count, "fabricate places a fleet")


## A status's `on_start` may grant Compute (Harvest, Squeeze); the price test
## counts it back.
func _granted(events: Array[SimEvent]) -> float:
	var total: float = 0.0
	for event: SimEvent in events:
		if event.type == SimEvent.COMPUTE_GRANTED:
			total += float(event.data["value"])
	return total


func test_the_global_ability_ignores_the_region() -> void:
	var sim: Simulation = _rich()
	var pause: AbilityDef = _db.ability("pause")
	assert_false(pause.targets_region())
	_own(sim, pause.levels_from)
	assert_true(sim.apply(UseAbilityCommand.new("pause", "")).ok)
	assert_not_null(sim.world.status_in_region(pause.applies_status, 0), "on the agent, everywhere")


# ------------------------------------------------------------------------ bots


func test_greedy_plays_nine_hundred_days_without_a_rejected_command() -> void:
	var problems: Array[String] = []
	var played: Dictionary = Harness.play(_db, 1, GreedyPolicy.ID, GREEDY_DAYS, true, problems)
	assert_eq(int(played["rejected"]), 0)
	assert_eq(problems.size(), 0, str(problems.slice(0, 3)))
