class_name Simulation
extends RefCounted
## One run: the content it plays on, the world it changes, and the fixed order
## its systems run in.
##
## Commands go in, events come out. Presentation calls `apply` and reads state;
## it never writes any. The same interface drives the bot policies of S1.8 and,
## later, Containment mode.

var db: ContentDB
var world: World
## What the world says about the run (ticker.md §3.1). Not a `SimSystem`: it
## runs after all of them and needs the whole tick's outbox.
var headlines: HeadlineSystem
## The fixed order of core.md §6.2. Tests may append a probe system.
var systems: Array[SimSystem] = []
## The events of the most recent `tick` only — the outbox never accumulates.
var outbox: Array[SimEvent] = []
## Accepted commands in order, each carrying the day it was applied. Replaying
## this log reproduces the run.
var command_log: Array[Command] = []


func _init() -> void:
	# The fixed system order. It is part of the determinism contract: a system
	# that moves changes every run. The comments are the slots M4 fills, so that
	# a later step inserts rather than reorders.
	systems = [
		SpreadSystem.new(),
		ComputeSystem.new(),
		PopulationSystem.new(),
		SocietalFunctionSystem.new(),
		ContainmentSystem.new(),
		CounterMoveSystem.new(),
		StatusSystem.new(),
		# slot: BehaviourSystem (M5)
		EventSystem.new(),
		PhaseSystem.new(),
		OutcomeSystem.new(),
		HistorySystem.new(),
	]


## A simulation that is nothing but the content and a world: what a *system*
## hands to `EffectRunner`, which needs the pair and no tick of its own. It
## points at the same `World`, so an effect applied through it changes the run
## it came from. Never ticked, never given a command.
static func view(db: ContentDB, world: World) -> Simulation:
	var sim: Simulation = Simulation.new()
	sim.db = db
	sim.world = world
	return sim


static func create(db: ContentDB, seed_value: int) -> Simulation:
	var sim: Simulation = Simulation.new()
	sim.db = db
	sim.world = World.create(db, seed_value)
	sim.headlines = HeadlineSystem.create(seed_value)
	return sim


## Continues a world that was loaded rather than created. The caller owns the
## world; `rebuild_modifiers` is this function's job because a loaded world has
## no modifier stack.
static func from_world(db: ContentDB, world: World, log: Array[Command],
		headlines: HeadlineSystem = null) -> Simulation:
	var sim: Simulation = Simulation.new()
	sim.db = db
	sim.world = world
	sim.command_log = log.duplicate()
	# A save written before the headline block, or a world built by a test: the
	# narration starts over from the run seed, which the world still carries.
	var seed_value: int = int(world.rng.seed_string())
	sim.headlines = headlines if headlines != null else HeadlineSystem.create(seed_value)
	if world.modifiers == null:
		world.modifiers = ModifierStack.new(db.balance.stats)
	sim.rebuild_modifiers()
	return sim


## Replays a command log from the seed up to `until_day`. A command that is
## rejected during replay means the run is not reproducible, which is a defect
## and not a situation to recover from: it returns null after `push_error`.
static func replay(db: ContentDB, seed_value: int, log: Array[Command],
		until_day: int) -> Simulation:
	var sim: Simulation = Simulation.create(db, seed_value)
	while true:
		for command: Command in log:
			if command.day != sim.world.day:
				continue
			if not sim.apply(command).ok:
				push_error("replay: %s was rejected on day %d" % [command.type_id(), command.day])
				return null
		if sim.world.day >= until_day or sim.world.outcome != World.Outcome.NONE:
			break
		if not sim.tick():
			break
	return sim


## Advances one day. False means the run is over and nothing changed.
func tick() -> bool:
	if world.outcome != World.Outcome.NONE:
		return false
	outbox.clear()
	world.day += 1
	for system: SimSystem in systems:
		system.tick(world, db, outbox)
	# The run log keeps what the Analysis screen needs of the tick, before the
	# headlines are added: a headline is never logged (analysis.md §4.2).
	RunLog.record(world, db, outbox)
	# Last, and with everything the tick produced: the headline system reads the
	# outbox and never its own events.
	outbox.append_array(headlines.on_tick(world, db, outbox))
	return true


## Runs a command at once. A rejected command changes nothing and is not logged.
func apply(command: Command) -> CommandResult:
	var reason: String = can_apply(command)
	if not reason.is_empty():
		return CommandResult.rejected(reason)
	var result: CommandResult = CommandResult.accepted()
	command.day = world.day
	command.execute(self, result.events)
	command_log.append(command)
	RunLog.record(world, db, result.events)
	result.events.append_array(headlines.on_command(world, db, result.events))
	return result


## Why `command` would be rejected, or "" if it would be accepted.
func can_apply(command: Command) -> String:
	if world.outcome != World.Outcome.NONE:
		return Command.FAIL_GAME_OVER
	return command.validate(self)


## Which region a deploy site check is about, as a reason code or "" (§5). An
## unknown node or a node that deploys nothing accepts every region that is not
## dark, so that a caller may ask without branching first.
func site_eligibility(node_id: String, region_index: int) -> String:
	var node: TechNodeDef = db.tech(node_id)
	if node == null or node.deploy_eligible == null:
		return Eligibility.none().check(world, region_index)
	return node.deploy_eligible.check(world, region_index)


## Every region a rule accepts, in index order.
func eligible_regions(rule: Eligibility) -> PackedInt32Array:
	var out: PackedInt32Array = []
	for i: int in range(1, world.regions.size()):
		if rule.check(world, i).is_empty():
			out.append(i)
	return out


## A modifier target read for one region, or for the world when `region_index`
## is 0. The spelling the spec's formulas use, so that a system and a reader of
## `loop-mechanics.md` §7.5 see the same expression.
func stat(target: String, region_index: int = 0) -> float:
	if region_index <= 0 or region_index >= world.regions.size():
		return world.modifiers.value(target)
	return world.modifiers.value(target, world.regions[region_index].def)


## A modifier flag (a node's, or a timed one) or a story flag: `requires.flag`
## and `when.flag` ask one question and get one answer (§10.2, §20.8).
func has_flag(flag: String) -> bool:
	return HeadlineConditions.flag_set(world, flag)


## The ability level the run has reached: the number of leading entries of
## `levels_from` that are owned. 0 means locked (§9.2).
func ability_level(ability_id: String) -> int:
	var definition: AbilityDef = db.ability(ability_id)
	if definition == null:
		return 0
	var level: int = 0
	for node_id: String in definition.levels_from:
		if not world.agent.owns(node_id):
			break
		level += 1
	return level


## The day an ability's cooldown clears; a day at or below the current one means
## it is ready. An ability that was never used has no key and is ready (§9.3).
func ability_ready_day(ability_id: String) -> int:
	return int(world.agent.cooldowns.get(ability_id, 0))


## The hardware a region yields, which is the base tier plus whatever the agent
## brought with it. One place, because the yield, an anomaly's weight and
## `compute_grant per_hardware` all mean the same number. Region 0 has none.
func hardware(region_index: int) -> float:
	if region_index <= 0 or region_index >= world.regions.size():
		return 0.0
	return ComputeSystem.hardware_of(world, db, region_index)


## How many nodes of an exclusive group the run owns (§11.2).
func owned_in_group(group: String) -> int:
	var count: int = 0
	for node_id: String in world.agent.owned_nodes:
		var node: TechNodeDef = db.tech(node_id)
		if node != null and node.group == group:
			count += 1
	return count


## The cap of a group; a group the content does not declare has none.
func group_max(group: String) -> int:
	return int(db.groups.get(group, 0))


## The first owned node that closes `node_id`, or "". Exclusions are symmetric,
## so asking either side gives the same answer.
func excluded_by(node_id: String) -> String:
	for owned: String in world.agent.owned_nodes:
		var node: TechNodeDef = db.tech(owned)
		if node != null and node.excludes.has(node_id):
			return owned
	return ""


## Kind -> how many more of it the agent needs to buy this node; empty when it
## has enough. `requires_assets` counts across every region (§6.4).
func missing_assets(node: TechNodeDef) -> Dictionary[String, int]:
	var short: Dictionary[String, int] = {}
	for kind: String in node.requires_assets:
		var shortfall: int = node.requires_assets[kind] - world.asset_total(kind)
		if shortfall > 0:
			short[kind] = shortfall
	return short


## What a node costs right now: every purchase raises the price of everything
## else by one step (core.md §7.3). -1.0 for an unknown id.
func node_cost(node_id: String) -> float:
	var node: TechNodeDef = db.tech(node_id)
	if node == null:
		return -1.0
	var escalated: float = float(node.cost) \
		+ db.balance.compute_cost_step * float(world.agent.owned_nodes.size())
	# The tree's own multiplier sits on top of the global one, so a discount can
	# be bought for one tree without cheapening the others.
	return maxf(1.0, ceilf(escalated * world.modifiers.value("node_cost")
		* world.modifiers.value(ModifierDef.node_cost_target(node.tree))))


## Nodes that are not owned and whose prerequisites are met, in content order.
func available_nodes() -> Array[TechNodeDef]:
	var out: Array[TechNodeDef] = []
	for node: TechNodeDef in db.tech_nodes:
		if world.agent.owns(node.id):
			continue
		if prerequisites_met(node):
			out.append(node)
	return out


## All of `requires` owned, and — when `requires_any` is not empty — at least one
## of those. The cross-tree gates are ordinary prerequisites, nothing more.
func prerequisites_met(node: TechNodeDef) -> bool:
	for required: String in node.requires:
		if not world.agent.owns(required):
			return false
	if node.requires_any.is_empty():
		return true
	for required: String in node.requires_any:
		if world.agent.owns(required):
			return true
	return false


## Rebuilds the modifier stack from the owned nodes, in purchase order. The stack
## is derived state: it is never saved, only rebuilt.
func rebuild_modifiers() -> void:
	world.modifiers.clear()
	# The asset kinds first, so that a node's own modifiers still come last in
	# the summation order the determinism contract fixes (§6.2).
	world.add_asset_sources(db)
	for node_id: String in world.agent.owned_nodes:
		var node: TechNodeDef = db.tech(node_id)
		if node == null:
			continue
		world.modifiers.add_source(ModifierStack.source_for_tech(node_id), node.modifiers,
			node.flags, node.watched_by)
	# Last, so that a status still sits on top of the nodes it is fighting.
	StatusSystem.rebuild_sources(world, db)


## The two pure queries of the containment system (`m3-screens.md` §10.5),
## exposed here because presentation talks to the simulation and not to a system.
## Neither touches the RNG, and both answer for the world as it stands.
func discovery_risk() -> Dictionary:
	return ContainmentSystem.discovery_risk(world, db)


## One faction's pressure terms, capacity, brakes and gain (opposition.md §5.5).
func containment_breakdown(faction_id: String) -> Dictionary:
	return ContainmentSystem.containment_breakdown(world, db, faction_id)


## The Footprint one faction sees (§5.1).
func footprint_for(faction_id: String) -> float:
	return world.modifiers.footprint_for(faction_id)


## The faction closest to switching the agent off; "" before discovery (§5.6).
func threat_leader() -> String:
	return ContainmentSystem.threat_leader(world)


## What a faction is about to do (opposition.md §6.6): `{state, event, days}`.
func next_move(faction_id: String) -> Dictionary:
	return CounterMoveSystem.next_move(world, db, faction_id)


## The Societal Function stage of a region, 0…5 (§8.2).
func society_stage(region_index: int) -> int:
	return SocietalFunctionSystem.stage(world.regions[region_index].society, db.balance)


## Days of zero income left before Autophagy; −1 while the agent cannot starve
## (§8.5).
func starving_days_left() -> int:
	if has_flag(OutcomeSystem.FLAG_COMPUTE_INDEPENDENT):
		return -1
	return db.balance.society_autophagy_days - world.starving_days


func state_hash() -> String:
	return world.state_hash()
