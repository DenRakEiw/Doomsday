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

## A policy that wants more than this in one day is looping, not playing.
const MAX_COMMANDS_PER_DAY: int = 64
## `seed` is the world's; the policy gets its own stream derived from it, far
## enough away that neighbouring seeds do not give neighbouring policies.
const POLICY_SEED_FACTOR: int = 7919
const POLICY_SEED_OFFSET: int = 17

const DEFAULT_DATA: String = "res://data"
const DEFAULT_MAX_DAYS: int = 5000
const OUTCOME_TIMEOUT: String = "timeout"

## The order the summary's fields are printed and written in.
const FIELDS: Array[String] = ["seed", "policy", "outcome", "days", "discovery_day", "phase",
	"nodes_owned", "regions_seeded", "regions_dark", "deaths_share", "containment",
	"compute_earned", "rejected_commands", "hash"]


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
	if id == IdlePolicy.ID:
		return IdlePolicy.new()
	if id == GreedyPolicy.ID:
		return GreedyPolicy.new()
	if id == StealthPolicy.ID:
		return StealthPolicy.new()
	return null


static func policy_ids() -> Array[String]:
	return [IdlePolicy.ID, GreedyPolicy.ID, StealthPolicy.ID]


## The stream a policy gets for a world seed. Far enough from the seed that
## neighbouring seeds do not give neighbouring policies.
static func policy_seed(seed_value: int) -> int:
	return seed_value * POLICY_SEED_FACTOR + POLICY_SEED_OFFSET


## Plays one run to its end. `problems` is filled with the first invariant
## violation when `check` is on, and the run stops there.
static func play(db: ContentDB, seed_value: int, policy_id: String, max_days: int, check: bool,
		problems: Array[String]) -> Dictionary:
	var sim: Simulation = Simulation.create(db, seed_value)
	var policy: Policy = make_policy(policy_id)
	policy.setup(db, policy_seed(seed_value))
	return {"sim": sim, "rejected": advance(sim, policy, max_days, check, problems)}


## The day loop, on a simulation that may already have days behind it — which is
## what lets a test continue a loaded save with the same policy. Returns the
## number of rejected commands.
static func advance(sim: Simulation, policy: Policy, until_day: int, check: bool,
		problems: Array[String]) -> int:
	var rejected: int = 0
	while sim.world.outcome == World.Outcome.NONE and sim.world.day < until_day:
		for i: int in MAX_COMMANDS_PER_DAY:
			var command: Command = policy.next_command(sim)
			if command == null:
				break
			if not sim.apply(command).ok:
				# A rejected command is a policy bug, never a game state: the
				# policy asked `can_apply` or should have.
				rejected += 1
		sim.tick()
		if check:
			var found: Array[String] = sim.world.check_invariants(sim.db)
			if not found.is_empty():
				problems.append("day %d: %s" % [sim.world.day, ", ".join(found)])
				break
	return rejected


static func summarise(sim: Simulation, seed_value: int, policy_id: String, max_days: int,
		rejected: int) -> Dictionary:
	var world: World = sim.world
	var dark: int = 0
	for i: int in range(1, world.regions.size()):
		if world.regions[i].dark:
			dark += 1
	var outcome: String = World.OUTCOME_IDS[world.outcome]
	if world.outcome == World.Outcome.NONE and world.day >= max_days:
		outcome = OUTCOME_TIMEOUT
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
		"compute_earned": world.agent.compute_earned,
		"rejected_commands": rejected,
		"hash": world.state_hash(),
	}


## Loads a content root, printing one line per error.
static func load_content(root: String) -> ContentDB:
	var result: ContentLoadResult = ContentLoader.load_root(root)
	if result.ok():
		return result.db
	for error: ValidationError in result.errors:
		print(error)
	return null
