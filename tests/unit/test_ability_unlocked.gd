extends GutTest
## S4.2 — buying a node that grants an ability says so
## (`docs/specs/loop-mechanics.md` §9.2, §11.3).

const ORIGIN: String = "fx_alder"
## The branch the fixture's ability nodes hang behind.
const BRANCH: Array[String] = ["fx_vector_net", "fx_reach"]

var sim: Simulation


func before_each() -> void:
	sim = Fixtures.sim_with_origin(ORIGIN)
	Fixtures.grant(sim, 200.0)
	Fixtures.buy(sim, BRANCH)


func _buy(node_id: String) -> CommandResult:
	return sim.apply(PurchaseNodeCommand.new(node_id))


func _types(result: CommandResult) -> Array[String]:
	var out: Array[String] = []
	for event: SimEvent in result.events:
		out.append(event.type)
	return out


func test_a_node_that_grants_an_ability_announces_it_with_its_level() -> void:
	var result: CommandResult = _buy("fx_zap_1")
	assert_true(result.ok, result.reason)
	var types: Array[String] = _types(result)
	assert_true(types.has(SimEvent.ABILITY_UNLOCKED))
	var unlocked: SimEvent = result.events[types.find(SimEvent.ABILITY_UNLOCKED)]
	assert_eq(str(unlocked.data["ability"]), Fixtures.ZAP_ABILITY)
	assert_eq(int(unlocked.data["level"]), 1)


func test_the_second_node_raises_the_level() -> void:
	_buy("fx_zap_1")
	var result: CommandResult = _buy("fx_zap_2")
	var types: Array[String] = _types(result)
	var unlocked: SimEvent = result.events[types.find(SimEvent.ABILITY_UNLOCKED)]
	assert_eq(int(unlocked.data["level"]), 2)


## §11.3: the purchase, then what it placed, then what it gave, then its
## one-shots — the interface animates the purchase before its consequences.
func test_it_comes_after_the_deployment_and_before_the_one_shots() -> void:
	# `fx_fleet` deploys and needs a site; `fx_forge` grants and needs none, so
	# the order is read off the two together.
	Fixtures.buy(sim, ["fx_fleet"] as Array[String])
	var types: Array[String] = _types(_buy("fx_forge"))
	assert_eq(types[0], SimEvent.NODE_PURCHASED)
	assert_eq(types[1], SimEvent.ABILITY_UNLOCKED)


func test_a_node_that_grants_nothing_says_nothing() -> void:
	assert_false(_types(_buy("fx_grip")).has(SimEvent.ABILITY_UNLOCKED))


func test_the_ability_is_usable_the_moment_the_node_is_owned() -> void:
	assert_eq(sim.can_apply(UseAbilityCommand.new(Fixtures.ZAP_ABILITY, ORIGIN)),
		Command.FAIL_ABILITY_LOCKED)
	_buy("fx_zap_1")
	assert_eq(sim.can_apply(UseAbilityCommand.new(Fixtures.ZAP_ABILITY, ORIGIN)), "")
