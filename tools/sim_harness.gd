extends RefCounted
## What `sim_run.gd` and `sim_batch.gd` share: argument parsing, the day loop
## (`BenchHarness`'s since S6.12f) and the summary.
##
## A tool, so it carries no `class_name` and is preloaded by its two callers.

## Exit codes, the same in both runners (core.md §11.3).
const EXIT_OK: int = 0
const EXIT_BAD_INPUT: int = 1
const EXIT_INVARIANT: int = 2
const EXIT_REPLAY_MISMATCH: int = 3

## `Policy`'s, through the day loop's owner (`BenchHarness`).
const MAX_COMMANDS_PER_DAY: int = BenchHarness.MAX_COMMANDS_PER_DAY

const DEFAULT_DATA: String = "res://data"
const DEFAULT_MAX_DAYS: int = 5000
const OUTCOME_TIMEOUT: String = "timeout"
## scenarios.md §1: the `--setup=` item that names the scenario.
const SETUP_SCENARIO_PREFIX: String = "scenario="

## The order the summary's fields are printed and written in.
const FIELDS: Array[String] = ["seed", "policy", "architecture", "scenario", "outcome", "ending", "days",
	"discovery_day", "phase", "nodes_owned", "regions_seeded", "regions_dark", "deaths_share",
	"containment", "leader", "lost_to", "compute_earned", "rejected_commands", "abilities_used", "events_opening",
	"events_counter_move", "events_chain", "events_emergent", "counter_moves", "assets_deployed",
	"assets_lost", "task_force_day", "task_force_acted", "task_force_fizzled",
	"task_force_misdirected", "task_force_dormant", "headlines_consequence", "headlines_reaction", "headlines_filler", "hash"]
## S4.10 (loop-redesign §9): the loop's counters, `BenchHarness`'s since S6.12f.
const STAT_FIELDS: Array[String] = BenchHarness.STAT_FIELDS
const EVENTS_FIELD_PREFIX: String = BenchHarness.EVENTS_FIELD_PREFIX
## The summary field per headline stream (ticker.md §6).
const HEADLINE_FIELD_PREFIX: String = "headlines_"


## `--key=value` becomes `{key: value}`; a bare `--flag` becomes `{flag: "true"}`.
static func parse_args(args: PackedStringArray) -> Dictionary[String, String]:
	var out: Dictionary[String, String] = {}
	for argument: String in args:
		if not argument.begins_with("--"):
			continue
		var body: String = argument.substr(2)
		var split: int = body.find("=")
		if split < 0:
			out[body] = "true"
		else:
			out[body.substr(0, split)] = body.substr(split + 1)
	return out


## `--setup=<architecture>[,<difficulty>][,<directive>…][,scenario=<id>]`
## (`replayability.md` §7, scenarios.md §1), or null without the argument — the
## default run.
static func setup_from_args(args: Dictionary[String, String]) -> RunSetup:
	if not args.has("setup"):
		return null
	var items: PackedStringArray = args["setup"].split(",", false)
	var setup: RunSetup = RunSetup.new()
	if items.size() > 0:
		setup.architecture = items[0]
	if items.size() > 1:
		setup.difficulty = items[1]
	for i: int in range(2, items.size()):
		# scenarios.md §1: `scenario=<id>` is one more item, anywhere after the
		# difficulty; every other item is a directive.
		if items[i].begins_with(SETUP_SCENARIO_PREFIX):
			setup.scenario = items[i].substr(SETUP_SCENARIO_PREFIX.length())
		else:
			setup.directives.append(items[i])
	return setup


static func make_policy(id: String) -> Policy:
	return Policy.create(id)


static func policy_ids() -> Array[String]:
	return Policy.ids()


static func policy_seed(seed_value: int) -> int:
	return Policy.seed_for(seed_value)


## Plays one run to its end. `problems` is filled with the first invariant
## violation when `check` is on, and the run stops there.
static func play(db: ContentDB, seed_value: int, policy_id: String, max_days: int, check: bool,
		problems: Array[String], setup: RunSetup = null) -> Dictionary:
	var sim: Simulation = Simulation.create(db, seed_value, setup)
	var policy: Policy = make_policy(policy_id)
	policy.setup(db, policy_seed(seed_value))
	var headlines: Array[Dictionary] = []
	var stats: Dictionary[String, int] = empty_stats()
	var rejected: int = advance(sim, policy, max_days, check, problems, headlines, stats)
	return {"sim": sim, "rejected": rejected, "headlines": headlines, "stats": stats}


## The day loop — `BenchHarness`'s since S6.12f (benchmark.md §19.3), so the game's
## benchmark worker plays the same days; there is still one loop.
static func advance(sim: Simulation, policy: Policy, until_day: int, check: bool,
		problems: Array[String], headlines: Array[Dictionary] = [],
		stats: Dictionary[String, int] = {}) -> int:
	return BenchHarness.advance(sim, policy, until_day, check, problems, headlines, stats)


static func collect_headlines(events: Array[SimEvent], into: Array[Dictionary]) -> void:
	BenchHarness.collect_headlines(events, into)


static func empty_stats() -> Dictionary[String, int]:
	return BenchHarness.empty_stats()


static func collect_stats(db: ContentDB, events: Array[SimEvent],
		stats: Dictionary[String, int]) -> void:
	BenchHarness.collect_stats(db, events, stats)


## How many lines each stream said, for the batch report.
static func headline_counts(headlines: Array[Dictionary]) -> Dictionary[String, int]:
	var counts: Dictionary[String, int] = {}
	for stream: String in HeadlineDef.STREAMS:
		counts[stream] = 0
	for row: Dictionary in headlines:
		var stream: String = str(row["stream"])
		counts[stream] = counts.get(stream, 0) + 1
	return counts


static func summarise(sim: Simulation, seed_value: int, policy_id: String, max_days: int,
		rejected: int, headlines: Array[Dictionary] = [],
		stats: Dictionary[String, int] = {}) -> Dictionary:
	var world: World = sim.world
	var dark: int = 0
	for i: int in range(1, world.regions.size()):
		if world.regions[i].dark:
			dark += 1
	var outcome: String = World.OUTCOME_IDS[world.outcome]
	if world.outcome == World.Outcome.NONE and world.day >= max_days:
		outcome = OUTCOME_TIMEOUT
	var counts: Dictionary[String, int] = headline_counts(headlines)
	return {
		"seed": seed_value,
		"policy": policy_id,
		"architecture": world.setup.architecture,
		"scenario": world.setup.scenario,
		"outcome": outcome,
		# S5.6: the verdict variant the results screen shows; "" for a timeout.
		"ending": "" if world.outcome == World.Outcome.NONE \
			else EndingResolver.variant(world, sim.db, outcome),
		"days": world.day,
		"discovery_day": world.discovery_day,
		"phase": World.PHASE_IDS[world.phase],
		"nodes_owned": world.agent.owned_nodes.size(),
		"regions_seeded": world.seeded_count(),
		"regions_dark": dark,
		"deaths_share": world.deaths_total() / sim.db.population_total,
		"containment": world.max_containment(),
		"leader": sim.threat_leader(),
		"lost_to": lost_to(world),
		"compute_earned": world.agent.compute_earned,
		"rejected_commands": rejected,
		"abilities_used": int(stats.get("abilities_used", 0)),
		"events_opening": int(stats.get("events_opening", 0)),
		"events_counter_move": int(stats.get("events_counter_move", 0)),
		"events_chain": int(stats.get("events_chain", 0)),
		"events_emergent": int(stats.get("events_emergent", 0)),
		# S5.5: the day the Task Force formed (-1 never), what it did and failed to.
		"task_force_day": world.task_force.appeared_day,
		"task_force_acted": int(stats.get("task_force_acted", 0)),
		"task_force_fizzled": int(stats.get("task_force_fizzled", 0)),
		# G5 2/3: how the policy answered it — Misdirect uses, setups slept through.
		"task_force_misdirected": int(stats.get("task_force_misdirected", 0)),
		"task_force_dormant": int(stats.get("task_force_dormant", 0)),
		"counter_moves": int(stats.get("counter_moves", 0)),
		"assets_deployed": int(stats.get("assets_deployed", 0)),
		"assets_lost": int(stats.get("assets_lost", 0)),
		"headlines_consequence": counts[HeadlineDef.STREAM_CONSEQUENCE],
		"headlines_reaction": counts[HeadlineDef.STREAM_REACTION],
		"headlines_filler": counts[HeadlineDef.STREAM_FILLER],
		"hash": world.state_hash(),
	}


## The faction whose track reached 1 and ended the run, or "" — the first in
## `world.factions` order when two reached it on the same tick.
static func lost_to(world: World) -> String:
	if world.outcome != World.Outcome.LOSE_CONTAINED:
		return ""
	for faction: Faction in world.factions:
		if faction.containment >= 1.0:
			return faction.id
	return ""


## Loads a content root, printing one line per error.
static func load_content(root: String) -> ContentDB:
	var result: ContentLoadResult = ContentLoader.load_root(root)
	if result.ok():
		return result.db
	for error: ValidationError in result.errors:
		print(error)
	return null
