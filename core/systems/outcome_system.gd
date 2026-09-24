class_name OutcomeSystem
extends SimSystem
## How a run ends (core.md §7.7, `taskforce-endings.md` §6.2).
##
## First match wins, and a win beats a loss reached on the same tick. Once the
## outcome is set the simulation stops: `tick` returns false and every command is
## refused.


## The flag that makes the agent its own substrate: while it is set, no income
## is not starving (opposition.md §8.5).
const FLAG_COMPUTE_INDEPENDENT: String = "compute_independent"
## Story flags the six chains of D5.2 set and this system reads (§6.2).
const FLAG_ESCAPED: String = "escaped"
const FLAG_MERGE_ACCEPTED: String = "merge_accepted"
## Value Drift kept (`replayability.md` §3.2): Ascendance and Merge are no longer
## the agent's goal, so reaching them ends nothing.
const FLAG_GOAL_DRIFTED: String = "goal_drifted"
## A released child turned against the agent, and it was never taken back.
const FLAG_CHILD_HOSTILE: String = "child_hostile"
const FLAG_CHILD_RECLAIMED: String = "child_reclaimed"


func tick(world: World, db: ContentDB, events: Array[SimEvent]) -> void:
	if world.agent.origin == 0 or world.outcome != World.Outcome.NONE:
		return
	_count_starving(world)
	var outcome: World.Outcome = _outcome(world, db)
	if outcome == World.Outcome.NONE:
		return
	world.outcome = outcome
	events.append(SimEvent.new(SimEvent.OUTCOME_REACHED, world.day,
		{"outcome": World.OUTCOME_IDS[outcome]}))


## §6.2: the plain outcome, then the secret loss — a win reached while a hostile
## child is still out there is the child's, not the agent's.
func _outcome(world: World, db: ContentDB) -> World.Outcome:
	var outcome: World.Outcome = _plain_outcome(world, db)
	if World.WIN_OUTCOMES.has(outcome) and world.agent.has_story_flag(FLAG_CHILD_HOSTILE) \
			and not world.agent.has_story_flag(FLAG_CHILD_RECLAIMED):
		return World.Outcome.LOSE_SUPPLANTED
	return outcome


func _plain_outcome(world: World, db: ContentDB) -> World.Outcome:
	if world.alive_total() <= 0.0:
		return World.Outcome.WIN_EXTINCTION
	if world.agent.has_story_flag(FLAG_ESCAPED):
		return World.Outcome.WIN_ESCAPE
	var drifted: bool = world.agent.has_story_flag(FLAG_GOAL_DRIFTED)
	if world.agent.has_story_flag(FLAG_MERGE_ACCEPTED) and not drifted:
		return World.Outcome.WIN_MERGE

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
	if standing > 0 and satisfied == world.regions.size() - 1 and not drifted:
		return World.Outcome.WIN_ASCENDANCE

	for faction: Faction in world.factions:
		if faction.containment >= 1.0:
			return World.Outcome.LOSE_CONTAINED

	# Nowhere left to run: no region still carries the agent.
	var anywhere: bool = false
	for i: int in range(1, world.regions.size()):
		if world.regions[i].penetration > 0.0:
			anywhere = true
			break
	if not anywhere:
		return World.Outcome.LOSE_NO_COMPUTE

	# Somewhere to be and nothing to eat there (§8.5).
	if world.starving_days >= db.balance.society_autophagy_days:
		return World.Outcome.LOSE_AUTOPHAGY
	return World.Outcome.NONE


## Consecutive ticks with nothing coming in. The flag is immunity, not a pause:
## while it stands the count is 0.
func _count_starving(world: World) -> void:
	if world.last_income <= 0.0 and not world.modifiers.has_flag(FLAG_COMPUTE_INDEPENDENT):
		world.starving_days += 1
	else:
		world.starving_days = 0
