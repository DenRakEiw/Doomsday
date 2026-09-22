extends GutTest
## S3.1 — `SetDormancyCommand` and its refusals (`docs/specs/tech-trees.md` §6.4).
##
## The checks run in the order the spec lists them, and a test asserts the
## reason, not just that it was refused: the reason is what the player reads.

const HOME: String = "fx_alder"
const NEIGHBOUR: String = "fx_birch"

var _sim: Simulation


func before_each() -> void:
	_sim = Fixtures.sim_with_origin(HOME)


func _reason(region_id: String, dormant: bool = true) -> String:
	return _sim.can_apply(SetDormancyCommand.new(region_id, dormant))


func test_set_dormancy_needs_the_flag() -> void:
	assert_eq(_reason(HOME), Command.FAIL_DORMANCY_LOCKED)
	Fixtures.grant(_sim, 100.0)
	Fixtures.buy(_sim, Fixtures.DORMANCY_NODES)
	assert_eq(_reason(HOME), "", "and the branch unlocks it")


func test_set_dormancy_refuses_uninfected_dark_and_unchanged() -> void:
	# No origin at all is the first check of them all.
	var fresh: Simulation = Fixtures.sim()
	assert_eq(fresh.can_apply(SetDormancyCommand.new(HOME, true)), Command.FAIL_NO_ORIGIN)

	assert_eq(_reason("fx_nowhere"), Command.FAIL_INVALID_REGION,
		"an unknown region is refused before the flag is asked about")

	Fixtures.grant(_sim, 100.0)
	Fixtures.buy(_sim, Fixtures.DORMANCY_NODES)
	assert_eq(_reason(NEIGHBOUR), Command.FAIL_REGION_NOT_INFECTED, "nothing is there yet")

	_sim.world.regions[3].penetration = 0.5
	_sim.world.regions[3].dark = true
	assert_eq(_reason(_sim.db.regions[3].id), Command.FAIL_REGION_NOT_INFECTED,
		"and a dark region cannot be held either")

	assert_eq(_reason(HOME, false), Command.FAIL_DORMANCY_UNCHANGED, "it is already awake")
	assert_true(_sim.apply(SetDormancyCommand.new(HOME, true)).ok)
	assert_eq(_reason(HOME, true), Command.FAIL_DORMANCY_UNCHANGED, "and now already held")


func test_holding_a_region_reports_it() -> void:
	var result: CommandResult = Fixtures.hold(_sim, HOME)
	assert_true(result.ok, result.reason)
	assert_true(_sim.world.regions[1].dormant)
	assert_eq(result.events.size(), 1)
	assert_eq(result.events[0].type, SimEvent.DORMANCY_CHANGED)
	assert_eq(result.events[0].data["region"], HOME)
	assert_eq(result.events[0].data["dormant"], true)


func test_the_command_survives_the_log_and_back() -> void:
	Fixtures.hold(_sim, HOME)
	var logged: Command = _sim.command_log[_sim.command_log.size() - 1]
	var decoded: Command = CommandCodec.from_dict(logged.to_dict())
	assert_not_null(decoded)
	var dormancy: SetDormancyCommand = decoded as SetDormancyCommand
	assert_not_null(dormancy)
	assert_eq(dormancy.region, HOME)
	assert_true(dormancy.dormant)
	assert_eq(dormancy.day, logged.day)


func test_a_log_entry_without_the_flag_field_is_refused() -> void:
	var d: Dictionary = {"type": SetDormancyCommand.TYPE_ID, "day": 0, "region": HOME}
	assert_null(CommandCodec.from_dict(d))
	d["dormant"] = "true"
	assert_null(CommandCodec.from_dict(d), "a string is not a bool")
