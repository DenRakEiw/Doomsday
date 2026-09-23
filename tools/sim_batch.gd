extends SceneTree
## Plays a range of seeds and writes one CSV row per run.
##
##     "$GODOT" --headless --path . -s tools/sim_batch.gd -- \
##         --seeds=1..200 --policy=greedy --out=<path.csv> [--data] [--max-days]
##
## The CSV goes to the session scratch directory, never into the repository. The
## summary it prints is what goes under *Balance baselines* in PROGRESS.md.

const Harness := preload("res://tools/sim_harness.gd")

## Where the day distribution is sampled.
const PERCENTILES: Array[int] = [10, 50, 90]


func _init() -> void:
	var args: Dictionary[String, String] = Harness.parse_args(OS.get_cmdline_user_args())
	var policy_id: String = args.get("policy", GreedyPolicy.ID)
	var out_path: String = args.get("out", "")
	if Harness.make_policy(policy_id) == null or out_path.is_empty():
		print("usage: --seeds=<a>..<b> --policy=<%s> --out=<csv>"
			% "|".join(Harness.policy_ids()))
		quit(Harness.EXIT_BAD_INPUT)
		return

	var range_text: String = args.get("seeds", "1..100")
	var bounds: PackedStringArray = range_text.split("..")
	if bounds.size() != 2:
		print("--seeds wants <a>..<b>, got \"%s\"" % range_text)
		quit(Harness.EXIT_BAD_INPUT)
		return
	var first: int = int(bounds[0])
	var last: int = int(bounds[1])

	var max_days: int = int(args.get("max-days", str(Harness.DEFAULT_MAX_DAYS)))
	var db: ContentDB = Harness.load_content(args.get("data", Harness.DEFAULT_DATA))
	if db == null:
		quit(Harness.EXIT_BAD_INPUT)
		return

	var file: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		print("cannot write %s: %s" % [out_path, error_string(FileAccess.get_open_error())])
		quit(Harness.EXIT_BAD_INPUT)
		return
	file.store_line(",".join(Harness.FIELDS))

	var started: int = Time.get_ticks_msec()
	var days: Array[int] = []
	var outcomes: Dictionary[String, int] = {}
	var rejected_total: int = 0
	for seed_value: int in range(first, last + 1):
		var problems: Array[String] = []
		var played: Dictionary = Harness.play(db, seed_value, policy_id, max_days, false, problems)
		var summary: Dictionary = Harness.summarise(played["sim"], seed_value, policy_id, max_days,
			int(played["rejected"]), played["headlines"])
		var row: PackedStringArray = []
		for field: String in Harness.FIELDS:
			row.append(str(summary[field]))
		file.store_line(",".join(row))
		days.append(int(summary["days"]))
		var outcome: String = str(summary["outcome"])
		outcomes[outcome] = int(outcomes.get(outcome, 0)) + 1
		rejected_total += int(summary["rejected_commands"])
	file.close()

	var runs: int = days.size()
	days.sort()
	print("%s, %d seeds, %.1f s, %d rejected commands"
		% [policy_id, runs, (Time.get_ticks_msec() - started) / 1000.0, rejected_total])
	for outcome: String in outcomes:
		print("  %-16s %4d  %5.1f %%"
			% [outcome, outcomes[outcome], 100.0 * float(outcomes[outcome]) / float(runs)])
	var parts: PackedStringArray = []
	for percentile: int in PERCENTILES:
		parts.append("p%d %d" % [percentile, days[_at(runs, percentile)]])
	print("  days: %s" % ", ".join(parts))
	print("  written: %s" % out_path)
	quit(Harness.EXIT_OK)


## Nearest-rank percentile, so the value printed is one a run actually had.
func _at(count: int, percentile: int) -> int:
	return clampi(int(ceil(float(count) * float(percentile) / 100.0)) - 1, 0, count - 1)
