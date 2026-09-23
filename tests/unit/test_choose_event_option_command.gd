extends GutTest
## S4.3 — `ChooseEventOptionCommand` (`docs/specs/loop-mechanics.md` §10.2, §10.5).

const ORIGIN: String = "fx_alder"
const ORIGIN_INDEX: int = 1

var sim: Simulation


func before_each() -> void:
	sim = Fixtures.sim_with_origin(ORIGIN)
	Fixtures.grant(sim, 50.0)


func _open(def_id: String, region: String = ORIGIN, faction: String = "") -> OpenEvent:
	return Fixtures.open_event(sim, def_id, region, faction)


func _choose(event: OpenEvent, option: String) -> CommandResult:
	return sim.apply(ChooseEventOptionCommand.new(event.id, option))


func _reason(event_id: int, option: String) -> String:
	return sim.can_apply(ChooseEventOptionCommand.new(event_id, option))


func _types(result: CommandResult) -> Array[String]:
	var out: Array[String] = []
	for event: SimEvent in result.events:
		out.append(event.type)
	return out


# ------------------------------------------------------------ the five reasons


func test_an_answer_without_an_origin_is_refused_first() -> void:
	var fresh: Simulation = Fixtures.sim()
	assert_eq(fresh.can_apply(ChooseEventOptionCommand.new(1, "grab")), Command.FAIL_NO_ORIGIN)


func test_an_event_that_is_not_open_is_unknown() -> void:
	assert_eq(_reason(99, "grab"), Command.FAIL_UNKNOWN_EVENT)
	var event: OpenEvent = _open(Fixtures.OPENING_EVENT)
	assert_true(_choose(event, "pass").ok)
	assert_eq(_reason(event.id, "pass"), Command.FAIL_UNKNOWN_EVENT, "closed is gone")


func test_an_option_the_event_does_not_have_is_unknown() -> void:
	var event: OpenEvent = _open(Fixtures.OPENING_EVENT)
	assert_eq(_reason(event.id, "ride"), Command.FAIL_UNKNOWN_OPTION)


func test_a_locked_option_is_refused() -> void:
	var event: OpenEvent = _open(Fixtures.OPENING_EVENT)
	assert_eq(_reason(event.id, "locked"), Command.FAIL_OPTION_LOCKED)


func test_an_option_the_agent_cannot_afford_is_refused() -> void:
	var event: OpenEvent = _open(Fixtures.OPENING_EVENT)
	sim.world.agent.compute = 0.5
	assert_eq(_reason(event.id, "seed"), Command.FAIL_INSUFFICIENT_COMPUTE)
	assert_eq(_reason(event.id, "grab"), "", "a free option needs nothing")


# ------------------------------------------------------ one lock per requires key


func test_owned_locks_until_the_node_is_owned() -> void:
	var option: EventOptionDef = EventOptionDef.new()
	option.requires_owned = ["fx_reach"] as Array[String]
	assert_eq(str(option.lock_reason(sim, ORIGIN_INDEX)["reason"]), EventOptionDef.LOCK_NODE)
	Fixtures.buy(sim, ["fx_vector_net", "fx_reach"] as Array[String])
	assert_true(option.lock_reason(sim, ORIGIN_INDEX).is_empty())


func test_owned_any_locks_until_one_is_owned() -> void:
	var option: EventOptionDef = EventOptionDef.new()
	option.requires_owned_any = ["fx_reach", "fx_vector_net"] as Array[String]
	var lock: Dictionary = option.lock_reason(sim, ORIGIN_INDEX)
	assert_eq(str(lock["reason"]), EventOptionDef.LOCK_NODE_ANY)
	assert_eq((lock["nodes"] as Array).size(), 2)
	Fixtures.buy(sim, ["fx_vector_net"] as Array[String])
	assert_true(option.lock_reason(sim, ORIGIN_INDEX).is_empty())


func test_not_owned_locks_once_the_node_is_owned() -> void:
	var option: EventOptionDef = EventOptionDef.new()
	option.requires_not_owned = ["fx_vector_net"] as Array[String]
	assert_true(option.lock_reason(sim, ORIGIN_INDEX).is_empty())
	Fixtures.buy(sim, ["fx_vector_net"] as Array[String])
	assert_eq(str(option.lock_reason(sim, ORIGIN_INDEX)["reason"]), EventOptionDef.LOCK_NOT_OWNED)


func test_flag_reads_story_flags() -> void:
	var option: EventOptionDef = EventOptionDef.new()
	option.requires_flag = [Fixtures.CHAIN_FLAG] as Array[String]
	assert_eq(str(option.lock_reason(sim, ORIGIN_INDEX)["reason"]), EventOptionDef.LOCK_FLAG)
	sim.world.agent.story_flags.append(Fixtures.CHAIN_FLAG)
	assert_true(option.lock_reason(sim, ORIGIN_INDEX).is_empty())


func test_asset_min_counts_in_the_events_region() -> void:
	var option: EventOptionDef = EventOptionDef.new()
	option.requires_asset_min = {AssetDef.KIND_FLEET: 1} as Dictionary[String, int]
	sim.world.set_assets(2, AssetDef.KIND_FLEET, 1)
	var lock: Dictionary = option.lock_reason(sim, ORIGIN_INDEX)
	assert_eq(str(lock["reason"]), EventOptionDef.LOCK_ASSET, "a fleet elsewhere does not count")
	assert_eq(int(lock["count"]), 1)
	sim.world.set_assets(ORIGIN_INDEX, AssetDef.KIND_FLEET, 1)
	assert_true(option.lock_reason(sim, ORIGIN_INDEX).is_empty())


func test_compute_min_locks_below_the_bound() -> void:
	var option: EventOptionDef = EventOptionDef.new()
	option.requires_compute_min = 60.0
	assert_eq(str(option.lock_reason(sim, ORIGIN_INDEX)["reason"]), EventOptionDef.LOCK_COMPUTE)
	Fixtures.grant(sim, 20.0)
	assert_true(option.lock_reason(sim, ORIGIN_INDEX).is_empty())


func test_ability_locks_until_it_is_unlocked() -> void:
	var event: OpenEvent = _open(Fixtures.COUNTER_EVENT, ORIGIN, "governments")
	assert_eq(_reason(event.id, "resist"), Command.FAIL_OPTION_LOCKED)
	Fixtures.buy(sim, ["fx_vector_net", "fx_reach", "fx_zap_1"] as Array[String])
	assert_eq(_reason(event.id, "resist"), "")


# ---------------------------------------------------------------- execution


func test_an_answer_pays_and_says_so_first() -> void:
	var event: OpenEvent = _open(Fixtures.OPENING_EVENT)
	var before: float = sim.world.agent.compute
	var result: CommandResult = _choose(event, "seed")
	assert_true(result.ok, result.reason)
	assert_almost_eq(sim.world.agent.compute, before - 1.0, 1e-9)
	assert_eq(result.events[0].type, SimEvent.EVENT_ANSWERED)
	assert_eq(str(result.events[0].data["option"]), "seed")
	assert_eq(str(result.events[0].data["region"]), ORIGIN)
	assert_eq(int(result.events[0].data["event"]), event.id)


func test_the_effects_run_with_the_events_source() -> void:
	var event: OpenEvent = _open(Fixtures.OPENING_EVENT)
	var before: float = sim.world.agent.compute
	var result: CommandResult = _choose(event, "grab")
	assert_almost_eq(sim.world.agent.compute, before + 3.0, 1e-9)
	var granted: SimEvent = null
	for e: SimEvent in result.events:
		if e.type == SimEvent.COMPUTE_GRANTED:
			granted = e
	assert_not_null(granted)
	assert_eq(str(granted.data["source"]), "event:%s" % Fixtures.OPENING_EVENT)


func test_every_chance_is_rolled_in_order() -> void:
	# Seed 1: the roll comes from the world's stream right after the effects, so a
	# copy of that stream says whether the pulse comes.
	var event: OpenEvent = _open(Fixtures.OPENING_EVENT)
	var copy: SimRng = SimRng.from_strings(sim.world.rng.seed_string(),
		sim.world.rng.state_string())
	var result: CommandResult = _choose(event, "seed")
	# seed_neighbours draws nothing: it takes the best neighbours in order.
	var fired: bool = copy.chance(0.5)
	assert_eq(_types(result).has(SimEvent.PULSE_STARTED), fired)
	assert_eq(sim.world.rng.state_string(), copy.state_string(), "exactly one roll")


func test_option_flags_are_set_as_story_flags() -> void:
	var event: OpenEvent = _open(Fixtures.CHAIN_START)
	_choose(event, "go")
	assert_true(sim.world.agent.has_story_flag(Fixtures.CHAIN_FLAG))


func test_a_later_step_reads_the_flag_an_earlier_one_set() -> void:
	var start: OpenEvent = _open(Fixtures.CHAIN_START)
	var step: OpenEvent = _open(Fixtures.CHAIN_STEP)
	assert_eq(_reason(step.id, "remember"), Command.FAIL_OPTION_LOCKED)
	_choose(start, "go")
	assert_eq(_reason(step.id, "remember"), "")


func test_the_event_is_closed_after_the_answer() -> void:
	var event: OpenEvent = _open(Fixtures.OPENING_EVENT)
	_choose(event, "pass")
	assert_null(sim.world.event_by_id(event.id))
	assert_eq(sim.world.open_event_count(), 0)


func test_a_counter_move_applies_its_status_with_the_option() -> void:
	var event: OpenEvent = _open(Fixtures.COUNTER_EVENT, ORIGIN, "governments")
	Fixtures.buy(sim, ["fx_vector_net", "fx_reach", "fx_zap_1"] as Array[String])
	var result: CommandResult = _choose(event, "resist")
	assert_true(result.ok, result.reason)
	var status: Status = sim.world.status_in_region(Fixtures.WORLD_STATUS, ORIGIN_INDEX)
	assert_not_null(status)
	assert_eq(status.option, "resist")
	assert_eq(status.faction(), "governments")
	assert_eq(status.level, 1)


func test_skip_status_keeps_the_move_from_landing() -> void:
	var event: OpenEvent = _open(Fixtures.COUNTER_EVENT, ORIGIN, "governments")
	assert_true(_choose(event, "lobby").ok)
	assert_false(sim.world.has_status(Fixtures.WORLD_STATUS, ORIGIN_INDEX))


func test_a_roll_with_a_next_replaces_the_options_next() -> void:
	var content: Dictionary = Fixtures.raw_content()
	var file: Dictionary = (content["events"] as Array)[0]
	var start: Dictionary = (file["events"] as Array)[2]
	var go: Dictionary = (start["options"] as Array)[0]
	go["chance"] = [{"p": 1.0, "next": []}]
	var result: ContentLoadResult = Fixtures.load_raw(content)
	assert_true(result.ok(), result.error_text())
	var routed: Simulation = Simulation.create(result.db, 1)
	routed.apply(ChooseOriginCommand.new(ORIGIN))
	var event: OpenEvent = Fixtures.open_event(routed, Fixtures.CHAIN_START, ORIGIN)
	assert_true(routed.apply(ChooseEventOptionCommand.new(event.id, "go")).ok)
	assert_true(routed.world.pending_events.is_empty(), "an empty next on a success ends it")


# ------------------------------------------------------------------ the log


func test_the_command_round_trips_through_the_codec() -> void:
	var command: ChooseEventOptionCommand = ChooseEventOptionCommand.new(7, "grab")
	command.day = 12
	var copy: Command = CommandCodec.from_dict(command.to_dict())
	assert_true(copy is ChooseEventOptionCommand)
	var read: ChooseEventOptionCommand = copy
	assert_eq(read.event, 7)
	assert_eq(read.option, "grab")
	assert_eq(read.day, 12)
	assert_null(CommandCodec.from_dict({"type": "choose_event_option", "day": 1, "event": 1.5,
		"option": "grab"}))
	assert_null(CommandCodec.from_dict({"type": "choose_event_option", "day": 1, "event": 1}))


func test_a_replay_with_an_answered_event_reproduces_the_hash() -> void:
	# Seed 1, the greedy bot — but every event is answered with its first option
	# the bot could take before the bot gets to it, so the log holds real choices.
	var played: Simulation = Fixtures.sim(1)
	var policy: Policy = Policy.create(GreedyPolicy.ID)
	policy.setup(played.db, Policy.seed_for(1))
	var answered: int = 0
	for day: int in 200:
		for event: OpenEvent in played.world.events.duplicate():
			var def: EventDef = played.db.event(event.def)
			for option: EventOptionDef in def.options:
				if played.apply(ChooseEventOptionCommand.new(event.id, option.id)).ok:
					answered += 1
					break
		for i: int in Policy.MAX_COMMANDS_PER_DAY:
			var command: Command = policy.next_command(played)
			if command == null or not played.apply(command).ok:
				break
		if not played.tick():
			break
	assert_gt(answered, 0, "the run answered at least one event")
	var replayed: Simulation = Simulation.replay(played.db, 1, played.command_log,
		played.world.day)
	assert_not_null(replayed)
	assert_eq(replayed.state_hash(), played.state_hash())
