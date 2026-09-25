extends GutTest
## S6.13 — `ReplayPolicy` (docs/specs/benchmark.md §12.2): a recorded entry's
## commands come back on their days, each a fresh object; a refused or a missed
## command marks the day the replay left the recording; the decision lookups.

const ORIGIN: String = "fx_alder"
const OTHER: String = "fx_birch"
const GRANT: float = 1000.0


## An entry holding `commands` and decisions on `decision_days` (stances in
## order), on the fixture world.
func _entry(commands: Array[Command], decision_days: Array[int] = [],
		stances: Array[String] = []) -> BenchEntry:
	var entry: BenchEntry = BenchEntry.new()
	entry.setup = RunSetup.new()
	entry.commands = commands
	for i: int in decision_days.size():
		var decision: BenchDecision = BenchDecision.new()
		decision.day = decision_days[i]
		decision.stance = stances[i] if i < stances.size() else ""
		entry.decisions.append(decision)
	return entry


func _command(command: Command, day: int) -> Command:
	command.day = day
	return command


## Plays `sim` to `until_day` with `policy`, as `Game.advance` does: the policy's
## commands first, then the tick. Returns every command handed out.
func _play(sim: Simulation, policy: ReplayPolicy, until_day: int) -> Array[Command]:
	var handed: Array[Command] = []
	while sim.world.day < until_day:
		for i: int in Policy.MAX_COMMANDS_PER_DAY:
			var command: Command = policy.next_command(sim)
			if command == null:
				break
			handed.append(command)
			sim.apply(command)
		sim.tick()
	return handed


func test_the_commands_come_back_on_their_days() -> void:
	var commands: Array[Command] = [
		_command(ChooseOriginCommand.new(ORIGIN), 0),
		_command(PurchaseNodeCommand.new(Fixtures.DORMANCY_NODES[0]), 3),
		_command(PurchaseNodeCommand.new(Fixtures.DORMANCY_NODES[1]), 7),
	]
	var policy: ReplayPolicy = ReplayPolicy.new(_entry(commands))
	var sim: Simulation = Fixtures.sim()
	# The purchases need compute the first days do not earn.
	Fixtures.grant(sim, GRANT)
	var handed: Array[Command] = _play(sim, policy, 10)
	assert_eq(handed.size(), 3)
	for i: int in handed.size():
		assert_eq(handed[i].day, commands[i].day, "command %d on its day" % i)
		assert_eq(handed[i].type_id(), commands[i].type_id())
	assert_eq(sim.command_log.size(), 3, "every one was accepted")
	assert_eq(policy.diverged_day, -1)


func test_each_command_is_a_fresh_object() -> void:
	var commands: Array[Command] = [_command(ChooseOriginCommand.new(ORIGIN), 0)]
	var entry: BenchEntry = _entry(commands)
	var sim: Simulation = Fixtures.sim()
	var first: Command = ReplayPolicy.new(entry).next_command(sim)
	var second: Command = ReplayPolicy.new(entry).next_command(sim)
	assert_not_null(first)
	assert_false(is_same(first, entry.commands[0]), "not the entry's own object")
	assert_false(is_same(first, second), "a new one every time")


func test_a_refused_command_sets_the_diverged_day() -> void:
	# A second origin is refused: the run has one already.
	var commands: Array[Command] = [
		_command(ChooseOriginCommand.new(ORIGIN), 0),
		_command(ChooseOriginCommand.new(OTHER), 0),
	]
	var policy: ReplayPolicy = ReplayPolicy.new(_entry(commands))
	var sim: Simulation = Fixtures.sim()
	_play(sim, policy, 2)
	assert_eq(sim.command_log.size(), 1)
	assert_eq(policy.diverged_day, 0)


func test_a_command_whose_day_has_passed_sets_the_diverged_day() -> void:
	var commands: Array[Command] = [_command(ChooseOriginCommand.new(ORIGIN), 0)]
	var policy: ReplayPolicy = ReplayPolicy.new(_entry(commands))
	var sim: Simulation = Fixtures.sim()
	sim.tick()
	sim.tick()
	assert_null(policy.next_command(sim), "day 0 is gone")
	assert_eq(policy.diverged_day, 2)


func test_a_replay_that_follows_the_recording_never_diverges() -> void:
	var commands: Array[Command] = [_command(ChooseOriginCommand.new(ORIGIN), 0)]
	var policy: ReplayPolicy = ReplayPolicy.new(_entry(commands))
	_play(Fixtures.sim(), policy, 30)
	assert_eq(policy.diverged_day, -1)


func test_decision_at_and_index_across_the_decision_days() -> void:
	var policy: ReplayPolicy = ReplayPolicy.new(_entry([], [5, 15, 25],
		["spread", "hide", "earn"]))
	assert_eq(policy.decision_index(0), 0, "before the first")
	assert_null(policy.decision_at(4))
	assert_eq(policy.decision_index(5), 1)
	assert_eq(policy.decision_at(5).stance, "spread")
	assert_eq(policy.decision_index(14), 1)
	assert_eq(policy.decision_at(15).stance, "hide")
	assert_eq(policy.decision_index(100), 3)
	assert_eq(policy.decision_at(100).stance, "earn")


func test_a_bot_entry_has_no_decision() -> void:
	var policy: ReplayPolicy = ReplayPolicy.new(_entry([]))
	assert_eq(policy.decision_index(50), 0)
	assert_null(policy.decision_at(50))
	assert_eq(policy.policy_id(), ReplayPolicy.ID)
