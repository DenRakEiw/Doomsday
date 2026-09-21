extends GutTest
## S1.3 — the first command of every run.


func test_choosing_an_origin_seeds_it() -> void:
	var sim: Simulation = Fixtures.sim()
	var result: CommandResult = sim.apply(ChooseOriginCommand.new("fx_alder"))
	assert_true(result.ok, result.reason)
	assert_eq(sim.world.agent.origin, 1)
	assert_eq(sim.world.origin_day, 0)
	var home: Region = sim.world.regions[1]
	assert_almost_eq(home.penetration, sim.db.balance.spread_origin_penetration, 1e-9)
	assert_eq(home.seeded_day, 0)
	assert_eq(sim.world.seeded_count(), 1)


func test_the_event_names_the_region() -> void:
	var sim: Simulation = Fixtures.sim()
	var result: CommandResult = sim.apply(ChooseOriginCommand.new("fx_alder"))
	assert_eq(result.events.size(), 1)
	assert_eq(result.events[0].type, SimEvent.ORIGIN_CHOSEN)
	assert_eq(result.events[0].data["region"], "fx_alder")
	assert_eq(result.events[0].day, 0)


func test_a_second_origin_is_rejected() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	var result: CommandResult = sim.apply(ChooseOriginCommand.new("fx_birch"))
	assert_false(result.ok)
	assert_eq(result.reason, Command.FAIL_ORIGIN_ALREADY_CHOSEN)


func test_an_unknown_region_is_rejected() -> void:
	var sim: Simulation = Fixtures.sim()
	assert_eq(sim.can_apply(ChooseOriginCommand.new("fx_ghost")), Command.FAIL_INVALID_REGION)


func test_an_air_gapped_region_is_not_eligible() -> void:
	var sim: Simulation = Fixtures.sim()
	assert_eq(sim.can_apply(ChooseOriginCommand.new("fx_fir")), Command.FAIL_REGION_NOT_ELIGIBLE)


func test_a_region_without_hardware_is_not_eligible() -> void:
	# The fixture has no compute-tier-0 region, so the case is built by hand.
	var content: Dictionary = Fixtures.raw_content()
	var regions: Array = content["regions"]["regions"]
	var elm: Dictionary = regions[4]
	var attributes: Dictionary = elm["attributes"]
	attributes["compute"] = 0
	var result: ContentLoadResult = Fixtures.load_raw(content)
	assert_true(result.ok(), result.error_text())
	var sim: Simulation = Simulation.create(result.db, 1)
	assert_eq(sim.can_apply(ChooseOriginCommand.new("fx_elm")), Command.FAIL_REGION_NOT_ELIGIBLE)


func test_the_command_survives_a_round_trip_through_its_dictionary() -> void:
	var command: ChooseOriginCommand = ChooseOriginCommand.new("fx_dogwood")
	command.day = 3
	var restored: Command = CommandCodec.from_dict(command.to_dict())
	assert_not_null(restored)
	assert_eq(restored.type_id(), ChooseOriginCommand.TYPE_ID)
	assert_eq(restored.day, 3)
	assert_eq(restored.to_dict()["region"], "fx_dogwood")


func test_a_broken_logged_command_does_not_decode() -> void:
	assert_null(CommandCodec.from_dict({"type": "choose_origin", "day": 0}), "no region")
	assert_null(CommandCodec.from_dict({"type": "choose_origin", "day": 0, "region": 5}),
		"a region that is not a string")
	assert_null(CommandCodec.from_dict({"type": "no_such_command", "day": 0}))
	assert_null(CommandCodec.from_dict({"type": "choose_origin", "day": 1.5}),
		"JSON has no integers, so a fractional day is a value check")
	assert_null(CommandCodec.from_dict({"day": 0, "region": "fx_alder"}), "no type")
