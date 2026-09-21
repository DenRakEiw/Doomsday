class_name OutcomeSystem
extends SimSystem
## How a run ends (core.md §7.7).
##
## First match wins, and a win beats a loss reached on the same tick. Once the
## outcome is set the simulation stops: `tick` returns false and every command is
## refused.


func tick(world: World, db: ContentDB, events: Array[SimEvent]) -> void:
	if world.agent.origin == 0 or world.outcome != World.Outcome.NONE:
		return
	var outcome: World.Outcome = _outcome(world, db)
	if outcome == World.Outcome.NONE:
		return
	world.outcome = outcome
	events.append(SimEvent.new(SimEvent.OUTCOME_REACHED, world.day,
		{"outcome": World.OUTCOME_IDS[outcome]}))


func _outcome(world: World, db: ContentDB) -> World.Outcome:
	if world.alive_total() <= 0.0:
		return World.Outcome.WIN_EXTINCTION

	# Ascendance: every region is either held or gone, and at least one is still
	# there — an empty world is Extinction, which was already checked.
	var standing: int = 0
	var satisfied: int = 0
	for i: int in range(1, world.regions.size()):
		var region: Region = world.regions[i]
		if region.dark:
			satisfied += 1
			continue
		standing += 1
		if region.control >= db.balance.control_complete:
			satisfied += 1
	if standing > 0 and satisfied == world.regions.size() - 1:
		return World.Outcome.WIN_ASCENDANCE

	for faction: Faction in world.factions:
		if faction.containment >= 1.0:
			return World.Outcome.LOSE_CONTAINED

	# Nowhere left to run: no region still carries the agent.
	for i: int in range(1, world.regions.size()):
		if world.regions[i].penetration > 0.0:
			return World.Outcome.NONE
	return World.Outcome.LOSE_NO_COMPUTE
