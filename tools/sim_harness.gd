extends RefCounted
## What `sim_run.gd` and `sim_batch.gd` share: argument parsing, the day loop and
## the summary.
##
## A tool, so it carries no `class_name` and is preloaded by its two callers.

## Exit codes, the same in both runners (core.md §11.3).
const EXIT_OK: int = 0
const EXIT_BAD_INPUT: int = 1
const EXIT_INVARIANT: int = 2
const EXIT_REPLAY_MISMATCH: int = 3

## Both live on `Policy` now, because the `Game` autoload plays bots through the
## same rules and must not reach into `tools/` for them.
const MAX_COMMANDS_PER_DAY: int = Policy.MAX_COMMANDS_PER_DAY

const DEFAULT_DATA: String = "res://data"
const DEFAULT_MAX_DAYS: int = 5000
const OUTCOME_TIMEOUT: String = "timeout"

## The order the summary's fields are printed and written in.
const FIELDS: Array[String] = ["seed", "policy", "outcome", "days", "discovery_day", "phase",
	"nodes_owned", "regions_seeded", "regions_dark", "deaths_share", "containment", "leader",
	"lost_to", "compute_earned", "rejected_commands", "abilities_used", "events_opening",
	"events_counter_move", "events_chain", "counter_moves", "assets_deployed", "assets_lost",
	"headlines_consequence", "headlines_reaction", "headlines_filler", "hash"]
## S4.10 (loop-redesign §9): what a run did with the redesigned loop, counted from
## the events of every command and every tick. `events_<kind>` counts the events
## the policy answered; `counter_moves` every counter-move that opened on it.
const STAT_FIELDS: Array[String] = ["abilities_used", "events_opening", "events_counter_move",
	"events_chain", "counter_moves", "assets_deployed", "assets_lost"]
const EVENTS_FIELD_PREFIX: String = "events_"
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


static func make_policy(id: String) -> Policy:
	return Policy.create(id)


static func policy_ids() -> Array[String]:
	return Policy.ids()


static func policy_seed(seed_value: int) -> int:
	return Policy.seed_for(seed_value)


## Plays one run to its end. `problems` is filled with the first invariant
## violation when `check` is on, and the run stops there.
static func play(db: ContentDB, seed_value: int, policy_id: String, max_days: int, check: bool,
		problems: Array[String]) -> Dictionary:
	var sim: Simulation = Simulation.create(db, seed_value)
	var policy: Policy = make_policy(policy_id)
	policy.setup(db, policy_seed(seed_value))
	var headlines: Array[Dictionary] = []
	var stats: Dictionary[String, int] = empty_stats()
	var rejected: int = advance(sim, policy, max_days, check, problems, headlines, stats)
	return {"sim": sim, "rejected": rejected, "headlines": headlines, "stats": stats}


## The day loop, on a simulation that may already have days behind it — which is
## what lets a test continue a loaded save with the same policy. Returns the
## number of rejected commands.
static func advance(sim: Simulation, policy: Policy, until_day: int, check: bool,
		problems: Array[String], headlines: Array[Dictionary] = [],
		stats: Dictionary[String, int] = {}) -> int:
	var rejected: int = 0
	while sim.world.outcome == World.Outcome.NONE and sim.world.day < until_day:
		for i: int in MAX_COMMANDS_PER_DAY:
			var command: Command = policy.next_command(sim)
			if command == null:
				break
			var result: CommandResult = sim.apply(command)
			if result.ok:
				collect_headlines(result.events, headlines)
				collect_stats(sim.db, result.events, stats)
			else:
				# A rejected command is a policy bug, never a game state: the
				# policy asked `can_apply` or should have.
				rejected += 1
		sim.tick()
		collect_headlines(sim.outbox, headlines)
		collect_stats(sim.db, sim.outbox, stats)
		if check:
			var found: Array[String] = sim.world.check_invariants(sim.db)
			if not found.is_empty():
				problems.append("day %d: %s" % [sim.world.day, ", ".join(found)])
				break
	return rejected


## The `headline` events of one tick or one command, in firing order, as the
## plain rows `--headlines` prints and `sim_batch` counts (ticker.md §6).
static func collect_headlines(events: Array[SimEvent], into: Array[Dictionary]) -> void:
	for event: SimEvent in events:
		if event.type != SimEvent.HEADLINE:
			continue
		into.append({
			"day": event.day,
			"id": str(event.data.get(SimEvent.FIELD_HEADLINE, "")),
			"stream": str(event.data.get(SimEvent.FIELD_STREAM, "")),
			"data": event.data,
		})


## Every `STAT_FIELDS` counter at zero.
static func empty_stats() -> Dictionary[String, int]:
	var out: Dictionary[String, int] = {}
	for field: String in STAT_FIELDS:
		out[field] = 0
	return out


## Counts what one tick or one command did into `stats`. A caller that passes no
## dictionary counts nothing.
static func collect_stats(db: ContentDB, events: Array[SimEvent],
		stats: Dictionary[String, int]) -> void:
	if stats.is_empty():
		return
	for event: SimEvent in events:
		match event.type:
			SimEvent.ABILITY_USED:
				stats["abilities_used"] += 1
			SimEvent.ASSET_DEPLOYED:
				stats["assets_deployed"] += int(event.data.get("count", 1))
			SimEvent.ASSET_LOST:
				stats["assets_lost"] += int(event.data.get("count", 1))
			SimEvent.EVENT_OPENED:
				if str(event.data.get("kind", "")) == EventDef.KIND_COUNTER_MOVE:
					stats["counter_moves"] += 1
			SimEvent.EVENT_ANSWERED:
				var def: EventDef = db.event(str(event.data.get("def", "")))
				var field: String = EVENTS_FIELD_PREFIX + (def.kind if def != null else "")
				if stats.has(field):
					stats[field] += 1


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
		"outcome": outcome,
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
