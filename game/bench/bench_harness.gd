class_name BenchHarness
extends RefCounted
## The one day loop every headless player shares (docs/specs/benchmark.md §19.3):
## the tools' `sim_harness.gd` (`sim_run`, `sim_batch`, the bots) and the
## benchmark's `BenchRunner` — in the tool and in the game's worker — call it, so
## a policy plays the same days everywhere. It moved out of `tools/` in S6.12f
## so an export has it; no autoload named.

## Both live on `Policy`, because the `Game` autoload plays bots through the same
## rules.
const MAX_COMMANDS_PER_DAY: int = Policy.MAX_COMMANDS_PER_DAY

## S4.10 (loop-redesign §9): what a run did with the redesigned loop, counted from
## the events of every command and every tick. `events_<kind>` counts the events
## the policy answered; `counter_moves` every counter-move that opened on it.
const STAT_FIELDS: Array[String] = ["abilities_used", "events_opening", "events_counter_move",
	"events_chain", "events_emergent", "counter_moves", "assets_deployed", "assets_lost",
	"task_force_acted", "task_force_fizzled", "task_force_misdirected", "task_force_dormant"]
const EVENTS_FIELD_PREFIX: String = "events_"


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
			SimEvent.TASK_FORCE_ACTED:
				stats["task_force_acted"] += 1
			SimEvent.TASK_FORCE_FIZZLED:
				stats["task_force_fizzled"] += 1
				# BALANCE §5.6 item 4: the setups dormancy answered.
				if str(event.data.get("cause", "")) == TaskForceSystem.CAUSE_DORMANT:
					stats["task_force_dormant"] += 1
			SimEvent.TASK_FORCE_MISDIRECTED:
				stats["task_force_misdirected"] += 1
			SimEvent.EVENT_OPENED:
				if str(event.data.get("kind", "")) == EventDef.KIND_COUNTER_MOVE:
					stats["counter_moves"] += 1
			SimEvent.EVENT_ANSWERED:
				var def: EventDef = db.event(str(event.data.get("def", "")))
				var field: String = EVENTS_FIELD_PREFIX + (def.kind if def != null else "")
				if stats.has(field):
					stats[field] += 1
