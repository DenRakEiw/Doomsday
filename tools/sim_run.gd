extends SceneTree
## Plays one headless run and prints a single line of JSON.
##
##     "$GODOT" --headless --path . -s tools/sim_run.gd -- \
##         --seed=1 --policy=greedy [--data=res://data] [--max-days=5000] [--check] [--replay]
##         [--setup=<architecture>[,<difficulty>][,<directive>…]]
##         [--headlines]
##
## `--headlines` adds one line per headline the run said, after the summary:
## `day<TAB>stream<TAB>id<TAB>the rendered English line` (ticker.md §6).
##
## Exit codes: 0 finished (a timeout included) · 1 bad arguments or content
## errors · 2 an invariant was violated · 3 the replay did not reproduce the run.

const Harness := preload("res://tools/sim_harness.gd")

## §6: the headline report is English, whatever the machine is set to.
const LOCALE_REPORT: String = "en"


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
	# §7: every report states its setup; an unknown one stops before a single run.
	var setup: RunSetup = Harness.setup_from_args(args)
	if setup != null and db != null and not setup.validate(db).is_empty():
		print("unknown setup \"%s\"" % args["setup"])
		quit(Harness.EXIT_BAD_INPUT)
		return
	if db == null:
		quit(Harness.EXIT_BAD_INPUT)
		return

	var problems: Array[String] = []
	var played: Dictionary = Harness.play(db, seed_value, policy_id, max_days,
		args.has("check"), problems, setup)
	var sim: Simulation = played["sim"]
	var summary: Dictionary = Harness.summarise(sim, seed_value, policy_id, max_days,
		int(played["rejected"]), played["headlines"], played["stats"])
	print(JSON.stringify(summary))
	if args.has("headlines"):
		_print_headlines(played["headlines"])

	if not problems.is_empty():
		for problem: String in problems:
			print("invariant: %s" % problem)
		quit(Harness.EXIT_INVARIANT)
		return

	if args.has("replay"):
		var replayed: Simulation = Simulation.replay(db, seed_value, sim.command_log,
			sim.world.day, sim.world.setup)
		if replayed == null or replayed.state_hash() != sim.state_hash():
			print("replay: the command log does not reproduce the run")
			quit(Harness.EXIT_REPLAY_MISMATCH)
			return

	quit(Harness.EXIT_OK)


## A headless run has the translations `project.godot` registers; one without
## them prints the key, which is not an error but is worth seeing.
static func _print_headlines(rows: Array) -> void:
	# The report is read by whoever tuned the numbers, and the spec asks for it
	# in English whatever the machine speaks.
	TranslationServer.set_locale(LOCALE_REPORT)
	for entry: Variant in rows:
		var row: Dictionary = entry
		var data: Dictionary = row["data"]
		var args: Dictionary = data.duplicate()
		args.erase(SimEvent.FIELD_HEADLINE)
		args.erase(SimEvent.FIELD_STREAM)
		print("%d	%s	%s	%s" % [int(row["day"]), row["stream"], row["id"],
			HeadlineText.render(HeadlineText.key_for(str(row["id"])), args)])
