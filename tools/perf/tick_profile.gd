extends SceneTree
## Where a late-game day goes (S6.11): plays seed 1 with the greedy bot headless
## and, from `--from` on, times the bot's turn, every system, the run log and the
## headlines of each day separately. Prints one line per part, slowest first.
##
##     "$GODOT" --headless --path . -s tools/perf/tick_profile.gd -- [--seed=1] [--policy=greedy] [--from=300] [--to=450]
##
## Replays `Simulation.tick` step by step, so the run and its hash are the same
## as `sim_run`'s; the hash is printed last to prove it.

const Harness := preload("res://tools/sim_harness.gd")

const DEFAULT_FROM: int = 300
const DEFAULT_TO: int = 450
const USEC_PER_MS: float = 1000.0
const PART_POLICY: String = "policy (bot turn + apply)"
const PART_RUN_LOG: String = "RunLog.record"
const PART_HEADLINES: String = "headlines.on_tick"


func _init() -> void:
	var args: Dictionary[String, String] = Harness.parse_args(OS.get_cmdline_user_args())
	var seed_value: int = int(args.get("seed", "1"))
	var policy_id: String = args.get("policy", GreedyPolicy.ID)
	var from_day: int = int(args.get("from", str(DEFAULT_FROM)))
	var to_day: int = int(args.get("to", str(DEFAULT_TO)))
	var db: ContentDB = Harness.load_content(Harness.DEFAULT_DATA)
	if db == null:
		quit(1)
		return
	var sim: Simulation = Simulation.create(db, seed_value, Harness.setup_from_args(args))
	var policy: Policy = Harness.make_policy(policy_id)
	policy.setup(db, Harness.policy_seed(seed_value))
	var problems: Array[String] = []
	Harness.advance(sim, policy, from_day, false, problems)
	var totals: Dictionary[String, int] = {}
	var days: int = 0
	var day_total: int = 0
	var day_max: int = 0
	while sim.world.outcome == World.Outcome.NONE and sim.world.day < to_day:
		var day_start: int = Time.get_ticks_usec()
		var started: int = day_start
		for i: int in Harness.MAX_COMMANDS_PER_DAY:
			var command: Command = policy.next_command(sim)
			if command == null:
				break
			sim.apply(command)
		_add(totals, PART_POLICY, started)
		# `Simulation.tick`, one part at a time.
		sim.outbox.clear()
		sim.world.day += 1
		for system: SimSystem in sim.systems:
			started = Time.get_ticks_usec()
			system.tick(sim.world, db, sim.outbox)
			_add(totals, (system.get_script() as Script).resource_path.get_file(), started)
		started = Time.get_ticks_usec()
		RunLog.record(sim.world, db, sim.outbox)
		_add(totals, PART_RUN_LOG, started)
		started = Time.get_ticks_usec()
		sim.outbox.append_array(sim.headlines.on_tick(sim.world, db, sim.outbox))
		_add(totals, PART_HEADLINES, started)
		var spent: int = Time.get_ticks_usec() - day_start
		day_total += spent
		day_max = maxi(day_max, spent)
		days += 1
	# The rest of the run, for the hash.
	Harness.advance(sim, policy, Harness.DEFAULT_MAX_DAYS, false, problems)
	var parts: Array[String] = totals.keys()
	parts.sort_custom(func(a: String, b: String) -> bool: return totals[a] > totals[b])
	print("days %d–%d timed: %d, mean %.3f ms, max %.3f ms" % [from_day, from_day + days, days,
		float(day_total) / maxf(1.0, float(days)) / USEC_PER_MS, float(day_max) / USEC_PER_MS])
	for part: String in parts:
		print("%8.3f ms/day  %5.1f %%  %s" % [float(totals[part]) / maxf(1.0, float(days)) / USEC_PER_MS,
			100.0 * float(totals[part]) / maxf(1.0, float(day_total)), part])
	print("end day %d, hash %s" % [sim.world.day, sim.world.state_hash()])
	quit(0)


func _add(totals: Dictionary[String, int], part: String, started: int) -> void:
	totals[part] = int(totals.get(part, 0)) + Time.get_ticks_usec() - started
