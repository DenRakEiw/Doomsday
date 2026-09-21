class_name PhaseSystem
extends SimSystem
## What the world knows about the agent (core.md §7.6).
##
## The phase never regresses and may skip a step: being found while still Boxed
## goes straight to Emergent.


func tick(world: World, db: ContentDB, events: Array[SimEvent]) -> void:
	if world.agent.origin == 0:
		return
	var target: World.Phase = _target(world, db)
	if target <= world.phase:
		return
	events.append(SimEvent.new(SimEvent.PHASE_CHANGED, world.day, {
		"from": World.PHASE_IDS[world.phase],
		"to": World.PHASE_IDS[target],
	}))
	world.phase = target


func _target(world: World, db: ContentDB) -> World.Phase:
	if world.discovered:
		if world.max_containment() >= db.balance.phase_open_containment \
				or world.infected_share(db) >= db.balance.phase_open_world_share:
			return World.Phase.OPEN
		return World.Phase.EMERGENT
	if world.modifiers.has_flag(ModifierDef.FLAG_BREAKOUT):
		return World.Phase.COVERT
	return World.Phase.BOXED
