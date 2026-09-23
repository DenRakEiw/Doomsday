extends GutTest
## S4.2 — `UseAbilityCommand` (`docs/specs/loop-mechanics.md` §9.3).

const ORIGIN: String = "fx_alder"
const ORIGIN_INDEX: int = 1
## `fx_cedar`: never seeded in these tests, so it is the ineligible region.
const COLD: String = "fx_cedar"
## The origin has industry 2, which is what `fx_forge` asks for — and it is the
## one region that is infected from day 0.
const INDUSTRIAL: String = "fx_alder"
const INDUSTRIAL_INDEX: int = 1

var sim: Simulation


func before_each() -> void:
	sim = Fixtures.sim_with_origin(ORIGIN)
	Fixtures.grant(sim, 200.0)


## The branch every ability of the fixture hangs behind.
func _branch() -> Array[String]:
	return ["fx_vector_net", "fx_reach"] as Array[String]


func _own(nodes: Array[String]) -> void:
	var all: Array[String] = _branch()
	all.append_array(nodes)
	Fixtures.buy(sim, all)


func _use(ability: String, region: String = "") -> CommandResult:
	return sim.apply(UseAbilityCommand.new(ability, region))


func _reason(ability: String, region: String = "") -> String:
	return sim.can_apply(UseAbilityCommand.new(ability, region))


func _events_of(result: CommandResult, type: String) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for event: SimEvent in result.events:
		if event.type == type:
			out.append(event)
	return out


# ------------------------------------------------------- the eight reasons


func test_an_ability_without_an_origin_is_refused_first() -> void:
	var fresh: Simulation = Fixtures.sim()
	assert_eq(fresh.can_apply(UseAbilityCommand.new(Fixtures.ZAP_ABILITY, ORIGIN)),
		Command.FAIL_NO_ORIGIN)


func test_an_unknown_ability_is_named_as_such() -> void:
	assert_eq(_reason("fx_nothing", ORIGIN), Command.FAIL_UNKNOWN_ABILITY)


func test_an_ability_nobody_bought_is_locked() -> void:
	assert_eq(_reason(Fixtures.ZAP_ABILITY, ORIGIN), Command.FAIL_ABILITY_LOCKED)


func test_an_ability_on_cooldown_says_so() -> void:
	_own(["fx_zap_1"] as Array[String])
	assert_true(_use(Fixtures.ZAP_ABILITY, ORIGIN).ok)
	assert_eq(_reason(Fixtures.ZAP_ABILITY, ORIGIN), Command.FAIL_ABILITY_COOLDOWN)


func test_compute_is_asked_for_before_the_site() -> void:
	_own(["fx_zap_1"] as Array[String])
	sim.world.agent.compute = 0.0
	assert_eq(_reason(Fixtures.ZAP_ABILITY, COLD), Command.FAIL_INSUFFICIENT_COMPUTE,
		"the region is ineligible too, but the money comes first")


func test_a_region_ability_without_a_region_asks_for_one() -> void:
	_own(["fx_zap_1"] as Array[String])
	assert_eq(_reason(Fixtures.ZAP_ABILITY), Command.FAIL_SITE_REQUIRED)


func test_an_unknown_region_is_refused() -> void:
	_own(["fx_zap_1"] as Array[String])
	assert_eq(_reason(Fixtures.ZAP_ABILITY, "fx_nowhere"), Command.FAIL_INVALID_REGION)


func test_a_region_the_rule_refuses_is_ineligible() -> void:
	_own(["fx_zap_1"] as Array[String])
	assert_eq(_reason(Fixtures.ZAP_ABILITY, COLD), Command.FAIL_SITE_INELIGIBLE)


## §9.3: a global ability ignores the region field altogether.
func test_a_global_ability_ignores_the_region_it_is_handed() -> void:
	_own(["fx_hushbox"] as Array[String])
	assert_eq(_reason(Fixtures.HUSH_ABILITY, COLD), "")
	assert_true(_use(Fixtures.HUSH_ABILITY, COLD).ok)
	assert_true(sim.world.has_status(Fixtures.HUSH_STATUS, 0))


# ---------------------------------------------------------------- execution


func test_using_it_pays_starts_the_cooldown_and_applies_the_status() -> void:
	_own(["fx_zap_1"] as Array[String])
	var before: float = sim.world.agent.compute
	var result: CommandResult = _use(Fixtures.ZAP_ABILITY, ORIGIN)
	assert_true(result.ok, result.reason)
	assert_almost_eq(sim.world.agent.compute, before - 2.0, 1e-9)
	assert_eq(sim.ability_ready_day(Fixtures.ZAP_ABILITY), sim.world.day + 5)
	assert_true(sim.world.has_status(Fixtures.ZAP_STATUS, ORIGIN_INDEX))


## The verb is announced before what it caused, as everywhere else (§9.3).
func test_ability_used_comes_first_and_carries_the_level() -> void:
	_own(["fx_zap_1", "fx_zap_2"] as Array[String])
	var result: CommandResult = _use(Fixtures.ZAP_ABILITY, ORIGIN)
	assert_eq(result.events[0].type, SimEvent.ABILITY_USED)
	assert_eq(str(result.events[0].data["ability"]), Fixtures.ZAP_ABILITY)
	assert_eq(str(result.events[0].data["region"]), ORIGIN)
	assert_eq(int(result.events[0].data["level"]), 2)
	assert_almost_eq(float(result.events[0].data["cost"]), 2.0, 1e-9)
	assert_eq(result.events[1].type, SimEvent.STATUS_STARTED)
	assert_eq(int(result.events[1].data["level"]), 2, "the status follows the ability's level")


func test_a_global_ability_names_no_region_in_its_event() -> void:
	_own(["fx_hushbox"] as Array[String])
	var result: CommandResult = _use(Fixtures.HUSH_ABILITY)
	assert_eq(str(result.events[0].data["region"]), "")


## §9.3: a cooldown of 0 erases the key rather than writing today into it.
func test_a_cooldown_of_zero_leaves_no_key_behind() -> void:
	_own(["fx_reap"] as Array[String])
	sim.db.ability(Fixtures.REAP_ABILITY).cooldown_days = 0
	assert_true(_use(Fixtures.REAP_ABILITY, ORIGIN).ok)
	assert_false(sim.world.agent.cooldowns.has(Fixtures.REAP_ABILITY))
	sim.db.ability(Fixtures.REAP_ABILITY).cooldown_days = 4


func test_the_cooldown_clears_on_its_day() -> void:
	_own(["fx_reap"] as Array[String])
	assert_true(_use(Fixtures.REAP_ABILITY, ORIGIN).ok)
	sim.world.day = sim.ability_ready_day(Fixtures.REAP_ABILITY)
	# The status it applied is still running, so the rule refuses it — the
	# cooldown itself is over, which is what this test is about.
	assert_ne(_reason(Fixtures.REAP_ABILITY, ORIGIN), Command.FAIL_ABILITY_COOLDOWN)


func test_a_deploying_ability_places_its_asset() -> void:
	_own(["fx_fleet", "fx_forge"] as Array[String])
	var result: CommandResult = _use(Fixtures.FORGE_ABILITY, INDUSTRIAL)
	assert_true(result.ok, result.reason)
	var deployed: Array[SimEvent] = _events_of(result, SimEvent.ASSET_DEPLOYED)
	assert_eq(deployed.size(), 1)
	assert_eq(str(deployed[0].data["ability"]), Fixtures.FORGE_ABILITY)
	assert_eq(str(deployed[0].data["node"]), "", "an ability is not a node")
	assert_gt(sim.world.regions[INDUSTRIAL_INDEX].asset_count(AssetDef.KIND_FLEET), 0)


## The status an ability applies carries the ability as its source, which is what
## the map reads to decide whose colour the ring takes (§16.3.1).
func test_the_status_names_the_ability_as_its_source() -> void:
	_own(["fx_zap_1"] as Array[String])
	_use(Fixtures.ZAP_ABILITY, ORIGIN)
	var status: Status = sim.world.status_in_region(Fixtures.ZAP_STATUS, ORIGIN_INDEX)
	assert_eq(status.source, "ability:%s" % Fixtures.ZAP_ABILITY)
	assert_eq(status.faction(), "", "the player's own status has no faction")


# -------------------------------------------------------------------- codec


func test_the_command_round_trips_through_the_codec() -> void:
	_own(["fx_zap_1"] as Array[String])
	_use(Fixtures.ZAP_ABILITY, ORIGIN)
	var logged: Command = sim.command_log[sim.command_log.size() - 1]
	var back: Command = CommandCodec.from_dict(logged.to_dict())
	assert_not_null(back)
	var ability: UseAbilityCommand = back as UseAbilityCommand
	assert_eq(ability.ability, Fixtures.ZAP_ABILITY)
	assert_eq(ability.region, ORIGIN)
	assert_eq(ability.day, logged.day)


func test_a_global_use_round_trips_with_an_empty_region() -> void:
	var back: Command = CommandCodec.from_dict(
		{"type": UseAbilityCommand.TYPE_ID, "day": 3, "ability": "fx_hush", "region": ""})
	assert_not_null(back)
	assert_eq((back as UseAbilityCommand).region, "")


func test_a_row_without_its_fields_is_a_corrupt_log() -> void:
	for row: Dictionary in [
			{"type": UseAbilityCommand.TYPE_ID, "day": 1, "region": ""},
			{"type": UseAbilityCommand.TYPE_ID, "day": 1, "ability": "fx_hush"},
			{"type": UseAbilityCommand.TYPE_ID, "day": 1, "ability": "fx_hush", "region": 3}]:
		assert_null(CommandCodec.from_dict(row), str(row))


## A run with an ability in its log replays to the same world (core.md §11).
## It earns its Compute rather than being handed any: a replay reproduces the
## commands, and nothing a test wrote into the world directly.
func test_a_run_with_an_ability_replays_to_the_same_hash() -> void:
	var earned: Simulation = Fixtures.sim_with_origin(ORIGIN)
	var branch: Array[String] = _branch()
	branch.append("fx_zap_1")
	for node_id: String in branch:
		_wait_for(earned, PurchaseNodeCommand.new(node_id))
		assert_true(earned.apply(PurchaseNodeCommand.new(node_id)).ok, node_id)
	assert_true(earned.apply(UseAbilityCommand.new(Fixtures.ZAP_ABILITY, ORIGIN)).ok)
	for i: int in 10:
		earned.tick()
	var replayed: Simulation = Simulation.replay(earned.db, 1, earned.command_log,
		earned.world.day)
	assert_not_null(replayed)
	assert_eq(replayed.state_hash(), earned.state_hash())


## Ticks until the run can afford `command`, or gives up after `days`.
func _wait_for(run: Simulation, command: Command, days: int = 400) -> void:
	for i: int in days:
		if run.can_apply(command) != Command.FAIL_INSUFFICIENT_COMPUTE:
			return
		run.tick()
	fail_test("the run never earned enough for %s" % command.type_id())
