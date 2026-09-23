extends SceneTree
## Plays every policy over the same seeds and prints one Markdown table.
##
##     "$GODOT" --headless --path . -s tools/sim_report.gd -- \
##         --seeds=1..500 [--policies=greedy,persuader] [--out=<dir>] [--max-days]
##
## The table is what goes under *Balance baselines* in `docs/PROGRESS.md`; with
## `--out` every run is also written as a CSV row per policy, for a closer look.
## The seeds are the same for every policy on purpose: the difference between
## two rows is the strategy and nothing else.

const Harness := preload("res://tools/sim_harness.gd")

## Where the day and the other distributions are sampled.
const PERCENTILES: Array[int] = [10, 50, 90]
const DEFAULT_SEEDS: String = "1..100"


func _init() -> void:
	var args: Dictionary[String, String] = Harness.parse_args(OS.get_cmdline_user_args())
	var policies: PackedStringArray = _policies(args)
	if policies.is_empty():
		print("usage: --seeds=<a>..<b> [--policies=%s] [--out=<dir>]"
			% ",".join(Harness.policy_ids()))
		quit(Harness.EXIT_BAD_INPUT)
		return
	var bounds: PackedInt32Array = _seed_range(args.get("seeds", DEFAULT_SEEDS))
	if bounds.is_empty():
		print("--seeds wants <a>..<b>, got \"%s\"" % args.get("seeds", DEFAULT_SEEDS))
		quit(Harness.EXIT_BAD_INPUT)
		return

	var db: ContentDB = Harness.load_content(args.get("data", Harness.DEFAULT_DATA))
	if db == null:
		quit(Harness.EXIT_BAD_INPUT)
		return
	var max_days: int = int(args.get("max-days", str(Harness.DEFAULT_MAX_DAYS)))

	var rows: Array[Dictionary] = []
	for policy_id: String in policies:
		rows.append(_run_policy(db, policy_id, bounds, max_days, args.get("out", "")))
	_print_report(rows, bounds)
	quit(Harness.EXIT_OK)


## Every run of one policy, as the numbers the report prints.
func _run_policy(db: ContentDB, policy_id: String, bounds: PackedInt32Array, max_days: int,
		out_dir: String) -> Dictionary:
	var started: int = Time.get_ticks_msec()
	var runs: Array[Dictionary] = []
	var file: FileAccess = _open_csv(out_dir, policy_id)
	for seed_value: int in range(bounds[0], bounds[1] + 1):
		var problems: Array[String] = []
		var played: Dictionary = Harness.play(db, seed_value, policy_id, max_days, false, problems)
		var summary: Dictionary = Harness.summarise(played["sim"], seed_value, policy_id, max_days,
			int(played["rejected"]), played["headlines"])
		summary.merge(_nodes_bought(played["sim"]))
		runs.append(summary)
		if file != null:
			file.store_line(_csv_row(summary))
	if file != null:
		file.close()
	print("  %s: %d runs in %.1f s" % [policy_id, runs.size(),
		(Time.get_ticks_msec() - started) / 1000.0])
	return {"policy": policy_id, "runs": runs}


## What the run bought, by tree and — for Capabilities — by branch.
static func _nodes_bought(sim: Simulation) -> Dictionary:
	var counts: Dictionary = {}
	for tree: String in TechNodeDef.TREES:
		counts["nodes_" + tree] = 0
	for branch: String in TechNodeDef.BRANCHES:
		counts["branch_" + branch] = 0
	for node_id: String in sim.world.agent.owned_nodes:
		var node: TechNodeDef = sim.db.tech(node_id)
		if node == null:
			continue
		counts["nodes_" + node.tree] = int(counts["nodes_" + node.tree]) + 1
		if not node.branch().is_empty():
			counts["branch_" + node.branch()] = int(counts["branch_" + node.branch()]) + 1
	return counts


# ---------------------------------------------------------------- the report


func _print_report(rows: Array[Dictionary], bounds: PackedInt32Array) -> void:
	print("\n### %d seeds per policy (%d..%d), content %s\n"
		% [bounds[1] - bounds[0] + 1, bounds[0], bounds[1], Time.get_date_string_from_system()])
	_print_table(rows, "Outcome mix", _outcome_columns(rows), func(run: Dictionary,
		column: String) -> String:
			return "%.0f %%" % (100.0 * _share(run, "outcome", column)))
	_print_table(rows, "Run", ["days", "discovery_day", "regions_seeded", "regions_dark"],
		func(run: Dictionary, column: String) -> String: return _spread(run, column))
	_print_table(rows, "Pressure", ["deaths_share", "containment", "compute_earned"],
		func(run: Dictionary, column: String) -> String: return _spread(run, column))
	_print_table(rows, "Bought", _node_columns(), func(run: Dictionary,
		column: String) -> String: return "%.1f" % _mean(run, column))
	_print_table(rows, "Said", ["headlines_consequence", "headlines_reaction",
		"headlines_filler"], func(run: Dictionary, column: String) -> String:
			return "%.0f" % _mean(run, column))


## One table: a row per policy, a column per measurement, `cell` deciding what a
## cell says.
func _print_table(rows: Array[Dictionary], title: String, columns: Array,
		cell: Callable) -> void:
	var header: PackedStringArray = ["**%s**" % title]
	var divider: PackedStringArray = ["---"]
	for column: Variant in columns:
		header.append("`%s`" % str(column).trim_prefix("headlines_").trim_prefix("nodes_"))
		divider.append("---")
	print("| %s |" % " | ".join(header))
	print("| %s |" % " | ".join(divider))
	for row: Dictionary in rows:
		var cells: PackedStringArray = ["`%s`" % row["policy"]]
		for column: Variant in columns:
			cells.append(str(cell.call(row, str(column))))
		print("| %s |" % " | ".join(cells))
	print("")


## The outcomes that actually happened, in the order `World` lists them.
static func _outcome_columns(rows: Array[Dictionary]) -> Array:
	var seen: Array = []
	for outcome: String in World.OUTCOME_IDS + [Harness.OUTCOME_TIMEOUT]:
		for row: Dictionary in rows:
			if seen.has(outcome):
				continue
			for run: Dictionary in row["runs"]:
				if str(run["outcome"]) == outcome:
					seen.append(outcome)
					break
	return seen


static func _node_columns() -> Array:
	var columns: Array = []
	for tree: String in TechNodeDef.TREES:
		columns.append("nodes_" + tree)
	for branch: String in TechNodeDef.BRANCHES:
		columns.append("branch_" + branch)
	return columns


# ------------------------------------------------------------------ the maths


## `p10 · p50 · p90` of one field, whole numbers where the field is one.
static func _spread(row: Dictionary, field: String) -> String:
	var values: Array[float] = _values(row, field)
	if values.is_empty():
		return "—"
	var parts: PackedStringArray = []
	for percentile: int in PERCENTILES:
		var value: float = values[_at(values.size(), percentile)]
		parts.append("%.3f" % value if absf(value) < 10.0 and value != floorf(value)
			else "%.0f" % value)
	return " · ".join(parts)


static func _mean(row: Dictionary, field: String) -> float:
	var values: Array[float] = _values(row, field)
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for value: float in values:
		total += value
	return total / float(values.size())


## The share of runs whose `field` reads `wanted`.
static func _share(row: Dictionary, field: String, wanted: String) -> float:
	var runs: Array = row["runs"]
	if runs.is_empty():
		return 0.0
	var count: int = 0
	for run: Variant in runs:
		var summary: Dictionary = run
		if str(summary[field]) == wanted:
			count += 1
	return float(count) / float(runs.size())


## One field of every run, sorted, so a percentile is an index.
static func _values(row: Dictionary, field: String) -> Array[float]:
	var out: Array[float] = []
	for run: Variant in row["runs"]:
		var summary: Dictionary = run
		if summary.has(field):
			out.append(float(summary[field]))
	out.sort()
	return out


static func _at(count: int, percentile: int) -> int:
	return clampi(int(floor(float(count - 1) * float(percentile) / 100.0)), 0, count - 1)


# ------------------------------------------------------------------ the input


static func _policies(args: Dictionary[String, String]) -> PackedStringArray:
	if not args.has("policies"):
		return PackedStringArray(Harness.policy_ids())
	var wanted: PackedStringArray = args["policies"].split(",", false)
	for id: String in wanted:
		if Harness.make_policy(id) == null:
			print("unknown policy \"%s\"; expected one of %s" % [id, Harness.policy_ids()])
			return PackedStringArray()
	return wanted


## `<a>..<b>` as the two bounds, or empty for anything else.
static func _seed_range(text: String) -> PackedInt32Array:
	var bounds: PackedStringArray = text.split("..")
	if bounds.size() != 2 or int(bounds[1]) < int(bounds[0]):
		return PackedInt32Array()
	return PackedInt32Array([int(bounds[0]), int(bounds[1])])


static func _open_csv(out_dir: String, policy_id: String) -> FileAccess:
	if out_dir.is_empty():
		return null
	DirAccess.make_dir_recursive_absolute(out_dir)
	var file: FileAccess = FileAccess.open(out_dir.path_join("%s.csv" % policy_id),
		FileAccess.WRITE)
	if file == null:
		print("cannot write into %s: %s" % [out_dir, error_string(FileAccess.get_open_error())])
		return null
	file.store_line(",".join(Harness.FIELDS + _node_columns()))
	return file


static func _csv_row(summary: Dictionary) -> String:
	var row: PackedStringArray = []
	for field: Variant in Harness.FIELDS + _node_columns():
		row.append(str(summary.get(str(field), "")))
	return ",".join(row)
