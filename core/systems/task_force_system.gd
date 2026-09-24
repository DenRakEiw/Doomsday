class_name TaskForceSystem
extends SimSystem
## The Response Task Force at work (`taskforce-endings.md` §1): it forms when a
## track reaches half, then rests, picks a target, travels link by link, sets up in
## plain view and acts — or finds nothing, and rests again. No random number is
## drawn anywhere in it.
##
## Runs after `CounterMoveSystem` and before `StatusSystem`, so a status it applies
## today is in the same tick's status pass.

## §1.4's fizzle causes that are the team's own (the dark one is `SimEvent`'s).
const CAUSE_DORMANT: String = "dormant"
const CAUSE_HIDDEN: String = "hidden"
const CAUSE_CLEAN: String = "clean"
const CAUSE_REDIRECTED: String = "redirected"
## The source every action status is applied under.
const SOURCE: String = "task_force"
## §5: the Researcher's two ways into the team.
const FLAG_LED: String = "researcher_leads_task_force"
const FLAG_ALLY: String = "researcher_ally"
## §1.3: the global target that sets how fast its work goes.
const TARGET_PACE: String = "task_force_pace"
## §2.3: the modifier flag of the node that watches the watchers — its owner sees
## where the team is going from the moment it is chosen.
const FLAG_WATCH: String = "task_force_watch"


func tick(world: World, db: ContentDB, events: Array[SimEvent]) -> void:
	if world.agent.origin == 0 or world.outcome != World.Outcome.NONE:
		return
	var team: TaskForce = world.task_force
	if not team.is_present():
		_try_appear(world, db, events)
		return
	_update_level(world, db, events)
	team.progress += world.modifiers.value(TARGET_PACE)
	var sim: Simulation = Simulation.view(db, world)
	match team.state:
		TaskForce.STATE_REST:
			_rest(sim, events)
		TaskForce.STATE_TRAVEL:
			_travel(sim, events)
		TaskForce.STATE_SETUP:
			_setup(sim, events)


## Misdirect's effect (§4): the team goes to `index` instead — from the road, or
## out of a setup, which then fizzles. False when there is no team to mislead.
static func redirect(world: World, index: int, events: Array[SimEvent]) -> bool:
	var team: TaskForce = world.task_force
	if not team.is_present():
		return false
	if team.state == TaskForce.STATE_SETUP:
		team.fizzled += 1
		events.append(SimEvent.new(SimEvent.TASK_FORCE_FIZZLED, world.day, {
			"region": _id(world, team.region),
			"action": team.action,
			"cause": CAUSE_REDIRECTED,
		}))
	team.action = ""
	team.target = index
	team.misled = true
	team.state = TaskForce.STATE_TRAVEL
	team.progress = 0.0
	events.append(SimEvent.new(SimEvent.TASK_FORCE_MISDIRECTED, world.day, {
		"region": _id(world, index),
		"from": _id(world, team.region),
	}))
	return true


## §2.3: whether the player is shown where the team is going. A setup always
## shows itself; a road only to the Researcher's ally or the watcher's owner.
static func target_shown(world: World) -> bool:
	var team: TaskForce = world.task_force
	if team.target == 0:
		return false
	if team.state == TaskForce.STATE_SETUP:
		return true
	return world.agent.has_story_flag(FLAG_ALLY) or world.modifiers.has_flag(FLAG_WATCH)


## Whole days until the setup acts at today's pace; 0 outside a setup. A team
## that stands still (pace 0) counts the work left, not a day it will never reach.
static func setup_days_left(world: World, db: ContentDB) -> int:
	var team: TaskForce = world.task_force
	if team.state != TaskForce.STATE_SETUP:
		return 0
	var left: float = maxf(0.0, float(setup_days(world, db)) - team.progress)
	var pace: float = world.modifiers.value(TARGET_PACE)
	if pace <= 0.0:
		return ceili(left)
	return maxi(1, ceili(left / pace))


## §1.1: on the first tick a track reaches the mark — the lower mark while the
## Researcher leads it.
func _try_appear(world: World, db: ContentDB, events: Array[SimEvent]) -> void:
	var led: bool = world.agent.has_story_flag(FLAG_LED)
	var mark: float = db.balance.task_force_appear_at_led if led else db.balance.task_force_appear_at
	if world.max_containment() < mark:
		return
	var team: TaskForce = world.task_force
	team.region = _base(world)
	team.state = TaskForce.STATE_REST
	team.progress = 0.0
	team.appeared_day = world.day
	team.level = _level_for(world, db)
	events.append(SimEvent.new(SimEvent.TASK_FORCE_APPEARED, world.day, {
		"region": _id(world, team.region),
		"level": team.level,
		"led": led,
	}))


## §1.1: highest research, then highest regulation, then the lowest control, then
## the lower index — among the regions that are not dark.
static func _base(world: World) -> int:
	var best: int = 0
	for i: int in range(1, world.regions.size()):
		var region: Region = world.regions[i]
		if region.dark:
			continue
		if best == 0:
			best = i
			continue
		var other: Region = world.regions[best]
		var research: int = region.def.attr("research") - other.def.attr("research")
		var regulation: int = region.def.attr("regulation") - other.def.attr("regulation")
		if research > 0 or (research == 0 and regulation > 0) \
				or (research == 0 and regulation == 0 and region.control < other.control):
			best = i
	return best


## §1.2: one level for being there, one per threshold passed, one for the
## Researcher — at most three, and never fewer than before.
func _update_level(world: World, db: ContentDB, events: Array[SimEvent]) -> void:
	var team: TaskForce = world.task_force
	var level: int = _level_for(world, db)
	if level <= team.level:
		return
	team.level = level
	events.append(SimEvent.new(SimEvent.TASK_FORCE_LEVEL, world.day, {"level": level}))


static func _level_for(world: World, db: ContentDB) -> int:
	var level: int = 1
	for threshold: float in db.balance.task_force_level_thresholds:
		if world.max_containment() >= threshold:
			level += 1
	if world.agent.has_story_flag(FLAG_LED):
		level += db.balance.task_force_led_level_bonus
	return clampi(level, 1, TaskForceActionDef.LEVEL_MAX)


func _rest(sim: Simulation, events: Array[SimEvent]) -> void:
	var team: TaskForce = sim.world.task_force
	if team.progress < float(sim.db.balance.task_force_rest_days):
		return
	var target: int = TaskForceRules.choose_target(sim)
	if target == 0:
		return
	_head_for(sim.world, target, events)


func _head_for(world: World, target: int, events: Array[SimEvent]) -> void:
	var team: TaskForce = world.task_force
	team.target = target
	team.misled = false
	team.state = TaskForce.STATE_TRAVEL
	team.progress = 0.0
	events.append(SimEvent.new(SimEvent.TASK_FORCE_TARGETED, world.day, {
		"target": _id(world, target),
		"region": _id(world, team.region),
	}))


## §1.4 step 2: a target that went away is chosen again (a misdirected team keeps
## its false one); a hop when the day's work allows; the setup on arrival.
func _travel(sim: Simulation, events: Array[SimEvent]) -> void:
	var world: World = sim.world
	var team: TaskForce = world.task_force
	if not team.misled and not TaskForceRules.eligible(world, sim.db, team.target):
		var retarget: int = TaskForceRules.choose_target(sim)
		if retarget == 0:
			team.state = TaskForce.STATE_REST
			team.target = 0
			team.progress = 0.0
			return
		if retarget != team.target:
			var kept: float = team.progress
			_head_for(world, retarget, events)
			team.progress = kept
	if team.region == team.target:
		_arrive(sim, events)
		return
	if team.progress < float(_hop_days(world, sim.db)):
		return
	var from: int = team.region
	team.region = TaskForceRules.next_hop(world, from, team.target)
	team.progress = 0.0
	events.append(SimEvent.new(SimEvent.TASK_FORCE_MOVED, world.day, {
		"from": _id(world, from),
		"to": _id(world, team.region),
		"target": _id(world, team.target),
	}))
	if team.region == team.target:
		_arrive(sim, events)


static func _hop_days(world: World, db: ContentDB) -> int:
	var days: int = db.balance.task_force_hop_days - (world.task_force.level - 1)
	if world.agent.has_story_flag(FLAG_LED):
		days -= 1
	return maxi(db.balance.task_force_hop_days_min, days)


## The setup starts with the first action that fits; a decoy with nothing to act
## on fizzles at once as `clean`.
func _arrive(sim: Simulation, events: Array[SimEvent]) -> void:
	var world: World = sim.world
	var team: TaskForce = world.task_force
	team.misled = false
	var cause: String = TaskForceRules.fizzle_cause(world, sim.db, team.region)
	var action: TaskForceActionDef = null
	if cause.is_empty():
		action = TaskForceRules.action_for(world, sim.db, team.region)
	if action == null:
		_fizzle(world, cause if not cause.is_empty() else CAUSE_CLEAN, events)
		return
	team.action = action.id
	team.state = TaskForce.STATE_SETUP
	team.progress = 0.0
	events.append(SimEvent.new(SimEvent.TASK_FORCE_SETUP, world.day, {
		"region": _id(world, team.region),
		"action": action.id,
		"days": setup_days(world, sim.db),
	}))


## §1.4 step 3: the setup's length, three days longer while the Researcher warns.
static func setup_days(world: World, db: ContentDB) -> int:
	var days: int = db.balance.task_force_setup_days
	if world.agent.has_story_flag(FLAG_ALLY):
		days += db.balance.task_force_ally_warning_days
	return days


func _setup(sim: Simulation, events: Array[SimEvent]) -> void:
	var world: World = sim.world
	var team: TaskForce = world.task_force
	if team.progress < float(setup_days(world, sim.db)):
		return
	var cause: String = TaskForceRules.fizzle_cause(world, sim.db, team.region)
	if not cause.is_empty():
		_fizzle(world, cause, events)
		return
	var action: TaskForceActionDef = sim.db.task_force_action(team.action)
	if action != null:
		StatusSystem.apply(world, sim.db, action.status, team.region, SOURCE, 1, "", events)
	team.actions_done += 1
	events.append(SimEvent.new(SimEvent.TASK_FORCE_ACTED, world.day, {
		"region": _id(world, team.region),
		"action": team.action,
	}))
	_rest_again(team)


func _fizzle(world: World, cause: String, events: Array[SimEvent]) -> void:
	var team: TaskForce = world.task_force
	team.fizzled += 1
	events.append(SimEvent.new(SimEvent.TASK_FORCE_FIZZLED, world.day, {
		"region": _id(world, team.region),
		"action": team.action,
		"cause": cause,
	}))
	_rest_again(team)


static func _rest_again(team: TaskForce) -> void:
	team.state = TaskForce.STATE_REST
	team.progress = 0.0
	team.target = 0
	team.action = ""


static func _id(world: World, index: int) -> String:
	if index <= 0 or index >= world.regions.size():
		return ""
	return world.regions[index].def.id
