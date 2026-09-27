class_name BenchScore
extends RefCounted
## The benchmark's score and the leaderboard's rows (docs/specs/benchmark.md
## §10.1, §10.3, §16.3). Every ending the game calls a win counts as one; the
## row's outcome counts show how.

## Every win outcome id begins with it (`World.OUTCOME_IDS`).
const WIN_PREFIX: String = "win_"
## `mean_win_days` of a group without a win.
const NO_WINS: int = -1
## The seven keys a row groups by (§10.3).
const GROUP_KEYS: Array[String] = ["model", "params_id", "prompt_version", "parser_version",
	"locale", "suite", "content_hash"]


## A win: `win_base + win_speed × clamp(1 − days / max_days, 0, 1)`; anything
## else — a loss, a timeout — 0. `days` is `world.day − world.origin_day`.
static func run_score(outcome: String, days: int, max_days: int, config: BenchConfig) -> float:
	if not outcome.begins_with(WIN_PREFIX) or max_days <= 0:
		return 0.0
	var speed: float = clampf(1.0 - float(days) / float(max_days), 0.0, 1.0)
	return config.win_base + config.win_speed * speed


## One row per group of entries, ordered as §10.3 says: current before old,
## complete before incomplete, then score, win rate, mean win day (a group
## without wins last), model. `current_hash` is the content the rows are judged
## against; each entry's `file` and `sha256` go into the row's `entries` and
## `seeds`.
static func rows(entries: Array[BenchEntry], config: BenchConfig,
		current_hash: String = "") -> Array[Dictionary]:
	var groups: Dictionary[String, Array] = {}
	var order: Array[String] = []
	for entry: BenchEntry in entries:
		var key: String = JSON.stringify([entry.model, entry.params_id, entry.prompt_version,
			entry.parser_version, entry.locale, entry.suite, entry.content_hash])
		if not groups.has(key):
			groups[key] = []
			order.append(key)
		groups[key].append(entry)
	var out: Array[Dictionary] = []
	for key: String in order:
		var members: Array[BenchEntry] = []
		for entry: Variant in groups[key]:
			members.append(entry as BenchEntry)
		out.append(_row(members, config, current_hash))
	out.sort_custom(_before)
	return out


static func _row(members: Array[BenchEntry], config: BenchConfig,
		current_hash: String) -> Dictionary:
	members.sort_custom(func(a: BenchEntry, b: BenchEntry) -> bool:
		return a.seed_value < b.seed_value)
	var first: BenchEntry = members[0]
	var suite_seeds: Array[int] = config.suite_seeds(first.suite)
	var played: Dictionary[int, bool] = {}
	var total: float = 0.0
	var wins: int = 0
	var win_days: int = 0
	var outcomes: Dictionary = {}
	var sums: Dictionary[String, int] = {"calls": 0, "invalid_answers": 0,
		"rejected_actions": 0, "tokens_in": 0, "tokens_out": 0, "budget_exhausted": 0}
	var cost: float = 0.0
	var files: Array[String] = []
	var seeds: Array[Dictionary] = []
	var versions: Array[String] = []
	for entry: BenchEntry in members:
		if not entry.model_version.is_empty() and not versions.has(entry.model_version):
			versions.append(entry.model_version)
		played[entry.seed_value] = true
		var run: float = run_score(entry.outcome, entry.days, entry.max_days, config)
		total += run
		if entry.is_win():
			wins += 1
			win_days += entry.days
		outcomes[entry.outcome] = int(outcomes.get(entry.outcome, 0)) + 1
		sums["calls"] += entry.calls
		sums["invalid_answers"] += entry.invalid_answers
		sums["rejected_actions"] += entry.rejected_actions
		sums["tokens_in"] += entry.tokens_in
		sums["tokens_out"] += entry.tokens_out
		sums["budget_exhausted"] += 1 if entry.budget_exhausted else 0
		cost += entry.cost_usd
		files.append(entry.file)
		seeds.append({"seed": entry.seed_value, "file": entry.file, "sha256": entry.sha256,
			"outcome": entry.outcome, "days": entry.days,
			"score": BenchEntry.rounded_score(run)})
	var complete: bool = not suite_seeds.is_empty()
	for suite_seed: int in suite_seeds:
		complete = complete and played.has(suite_seed)
	var sorted_outcomes: Dictionary = {}
	var outcome_ids: Array = outcomes.keys()
	outcome_ids.sort()
	for outcome: Variant in outcome_ids:
		sorted_outcomes[outcome] = outcomes[outcome]
	var runs: int = members.size()
	versions.sort()
	var row: Dictionary = {
		"model": first.model,
		"backend": first.backend,
	}
	# §17.7: only a row whose runs report a version has the key, so every other
	# board stays byte for byte what it was.
	if not versions.is_empty():
		row["model_versions"] = versions
	# §18: a chat row says how hard its model was asked to think; bots and
	# decision models have no such thing, and their rows no such key.
	var effort: String = BenchEffort.of_entry(first)
	if not effort.is_empty():
		row[BenchEffort.PARAM] = effort
	row.merge({
		"params": first.params.duplicate(true),
		"params_id": first.params_id,
		"prompt_version": first.prompt_version,
		"parser_version": first.parser_version,
		"locale": first.locale,
		"suite": first.suite,
		"content_hash": first.content_hash,
		"current": first.content_hash == current_hash,
		"complete": complete,
		"runs": runs,
		"of": suite_seeds.size(),
		"score": BenchEntry.rounded_score(total / float(runs)),
		"wins": wins,
		"win_rate": float(wins) / float(runs),
		"outcomes": sorted_outcomes,
		"mean_win_days": roundi(float(win_days) / float(wins)) if wins > 0 else NO_WINS,
		"calls": sums["calls"],
		"invalid_answers": sums["invalid_answers"],
		"rejected_actions": sums["rejected_actions"],
		"tokens_in": sums["tokens_in"],
		"tokens_out": sums["tokens_out"],
		"cost_usd": cost,
		"budget_exhausted": sums["budget_exhausted"],
		"entries": files,
		"seeds": seeds,
	})
	return row


static func _before(a: Dictionary, b: Dictionary) -> bool:
	if bool(a["current"]) != bool(b["current"]):
		return bool(a["current"])
	if bool(a["complete"]) != bool(b["complete"]):
		return bool(a["complete"])
	if float(a["score"]) != float(b["score"]):
		return float(a["score"]) > float(b["score"])
	if float(a["win_rate"]) != float(b["win_rate"]):
		return float(a["win_rate"]) > float(b["win_rate"])
	var days_a: int = int(a["mean_win_days"])
	var days_b: int = int(b["mean_win_days"])
	if days_a != days_b:
		if days_a == NO_WINS or days_b == NO_WINS:
			return days_b == NO_WINS
		return days_a < days_b
	if str(a["model"]) != str(b["model"]):
		return str(a["model"]) < str(b["model"])
	return JSON.stringify([a["params_id"], a["suite"], a["locale"], a["prompt_version"],
		a["content_hash"]]) < JSON.stringify([b["params_id"], b["suite"], b["locale"],
		b["prompt_version"], b["content_hash"]])
