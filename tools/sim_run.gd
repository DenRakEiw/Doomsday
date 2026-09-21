extends SceneTree
## Plays one headless run and prints a single line of JSON.
##
##     "$GODOT" --headless --path . -s tools/sim_run.gd -- \
##         --seed=1 --policy=greedy [--data=res://data] [--max-days=5000] [--check] [--replay]
##
## Exit codes: 0 finished (a timeout included) · 1 bad arguments or content
## errors · 2 an invariant was violated · 3 the replay did not reproduce the run.

const Harness := preload("res://tools/sim_harness.gd")


func _init() -> void:
	var args: Dictionary[String, String] = Harness.parse_args(OS.get_cmdline_user_args())
	var policy_id: String = args.get("policy", GreedyPolicy.ID)
	if Harness.make_policy(policy_id) == null:
		print("unknown policy \"%s\"; expected one of %s" % [policy_id, Harness.policy_ids()])
		quit(Harness.EXIT_BAD_INPUT)
		return

	var seed_value: int = int(args.get("seed", "1"))
	var max_days: int = int(args.get("max-days", str(Harness.DEFAULT_MAX_DAYS)))
	var db: ContentDB = Harness.load_content(args.get("data", Harness.DEFAULT_DATA))
	if db == null:
		quit(Harness.EXIT_BAD_INPUT)
		return

	var problems: Array[String] = []
	var played: Dictionary = Harness.play(db, seed_value, policy_id, max_days,
		args.has("check"), problems)
	var sim: Simulation = played["sim"]
	var summary: Dictionary = Harness.summarise(sim, seed_value, policy_id, max_days,
		int(played["rejected"]))
	print(JSON.stringify(summary))

	if not problems.is_empty():
		for problem: String in problems:
			print("invariant: %s" % problem)
		quit(Harness.EXIT_INVARIANT)
		return

	if args.has("replay"):
		var replayed: Simulation = Simulation.replay(db, seed_value, sim.command_log,
			sim.world.day)
		if replayed == null or replayed.state_hash() != sim.state_hash():
			print("replay: the command log does not reproduce the run")
			quit(Harness.EXIT_REPLAY_MISMATCH)
			return

	quit(Harness.EXIT_OK)
