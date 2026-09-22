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
		# slot: SocietalFunctionSystem (M4)
		ContainmentSystem.new(),
		# slot: CounterActionSystem (M4)
		# slot: BehaviourSystem (M4)
		# slot: EventSystem (M4)
		PhaseSystem.new(),
		OutcomeSystem.new(),
		HistorySystem.new(),
	]


static func create(db: ContentDB, seed_value: int) -> Simulation:
	var sim: Simulation = Simulation.new()
	sim.db = db
	sim.world = World.create(db, seed_value)
	return sim


## Continues a world that was loaded rather than created. The caller owns the
## world; `rebuild_modifiers` is this function's job because a loaded world has
## no modifier stack.
static func from_world(db: ContentDB, world: World, log: Array[Command]) -> Simulation:
	var sim: Simulation = Simulation.new()
	sim.db = db
	sim.world = world
	sim.command_log = log.duplicate()
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
	return result


## Why `command` would be rejected, or "" if it would be accepted.
func can_apply(command: Command) -> String:
	if world.outcome != World.Outcome.NONE:
		return Command.FAIL_GAME_OVER
	return command.validate(self)


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
	for node_id: String in world.agent.owned_nodes:
		var node: TechNodeDef = db.tech(node_id)
		if node == null:
			continue
		world.modifiers.add_source(ModifierStack.source_for_tech(node_id), node.modifiers,
			node.flags)


func state_hash() -> String:
	return world.state_hash()
