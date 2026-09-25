class_name TaskForceText
extends RefCounted
## What the Response Task Force says, in words (`taskforce-endings.md` §9): the
## containment panel's row, the region panel's row and the console's lines name
## the same team, the same action and the same days, so they are said here once.
##
## Nothing in here reads the interface; every function takes what it needs and
## answers a string, "" when there is nothing to say. Never instantiated.

const KEY_TITLE: String = "UI_TASK_FORCE"
const KEY_CODE: String = "UI_TASK_FORCE_CODE"
const KEY_HERE: String = "UI_TASK_FORCE_HERE"
const KEY_SETUP: String = "UI_TASK_FORCE_SETUP"
const KEY_TARGET: String = "UI_TASK_FORCE_TARGET"
const KEY_LEVEL: String = "UI_TASK_FORCE_LEVEL"
const KEY_STATE_ABSENT: String = "UI_TASK_FORCE_STATE_ABSENT"
const KEY_STATE_TRAVEL: String = "UI_TASK_FORCE_STATE_TRAVEL"
const KEY_STATE_TRAVEL_UNKNOWN: String = "UI_TASK_FORCE_STATE_TRAVEL_UNKNOWN"
const KEY_STATE_SETUP: String = "UI_TASK_FORCE_STATE_SETUP"
const KEY_STATE_REST: String = "UI_TASK_FORCE_STATE_REST"
const KEY_CONSOLE_APPEARED: String = "UI_CONSOLE_TF_APPEARED"
const KEY_CONSOLE_APPEARED_LED: String = "UI_CONSOLE_TF_APPEARED_LED"
const KEY_CONSOLE_SETUP: String = "UI_CONSOLE_TF_SETUP"
const KEY_CONSOLE_ACTED: String = "UI_CONSOLE_TF_ACTED"
const KEY_CONSOLE_FIZZLED: String = "UI_CONSOLE_TF_FIZZLED"
const KEY_CONSOLE_MISDIRECTED: String = "UI_CONSOLE_TF_MISDIRECTED"
const KEY_CONSOLE_MARKED: String = "UI_CONSOLE_TF_MARKED"
const KEY_MARKED: String = "UI_TASK_FORCE_MARKED"
## Every key this file uses — the strings test reads this list.
const KEYS: Array[String] = [KEY_TITLE, KEY_CODE, KEY_HERE, KEY_SETUP, KEY_TARGET, KEY_LEVEL,
	KEY_STATE_ABSENT, KEY_STATE_TRAVEL, KEY_STATE_TRAVEL_UNKNOWN, KEY_STATE_SETUP,
	KEY_STATE_REST, KEY_CONSOLE_APPEARED, KEY_CONSOLE_APPEARED_LED, KEY_CONSOLE_SETUP,
	KEY_CONSOLE_ACTED, KEY_CONSOLE_FIZZLED, KEY_CONSOLE_MISDIRECTED, KEY_CONSOLE_MARKED,
	KEY_MARKED]
const PLACEHOLDER_REGION: String = "region"
const PLACEHOLDER_ACTION: String = "action"
const PLACEHOLDER_DAYS: String = "days"
const PLACEHOLDER_LEVEL: String = "level"
## What joins the level and the state in the containment panel's line.
const JOIN: String = " · "


## An action's name is its status's name (§3: `STATUS_TF_<ACTION>_NAME`); an id
## the content no longer has names itself.
static func action_name(db: ContentDB, action_id: String) -> String:
	var action: TaskForceActionDef = db.task_force_action(action_id)
	if action == null:
		return action_id
	return TechText.tr_key(StatusDef.name_key(action.status))


## The containment panel's line: the level, then what it is doing and where.
static func state_line(world: World, db: ContentDB) -> String:
	var team: TaskForce = world.task_force
	if not team.is_present():
		return TechText.tr_key(KEY_STATE_ABSENT)
	var level: String = TechText.tr_key(KEY_LEVEL).format({PLACEHOLDER_LEVEL: team.level})
	return level + JOIN + _state(world, db)


## The region panel's line for `region_index`, "" when the team has nothing to
## do with it — or has, but the player is not shown that yet (§2.3).
static func region_line(world: World, db: ContentDB, region_index: int) -> String:
	var team: TaskForce = world.task_force
	if not team.is_present() or region_index <= 0:
		return ""
	if team.region == region_index:
		if team.state == TaskForce.STATE_SETUP:
			return TechText.tr_key(KEY_SETUP).format({
				PLACEHOLDER_ACTION: action_name(db, team.action),
				PLACEHOLDER_DAYS: TaskForceSystem.setup_days_left(world, db),
			})
		return TechText.tr_key(KEY_HERE)
	if team.target == region_index and TaskForceSystem.target_shown(world):
		return TechText.tr_key(KEY_TARGET)
	return ""


## The region panel's second line (§14.4): how long dormancy will not hide
## `region_index` from the team, whatever the team is doing — "" when unmarked.
static func marked_line(world: World, db: ContentDB, region_index: int) -> String:
	var team: TaskForce = world.task_force
	if region_index <= 0 or region_index >= db.regions.size() \
			or not team.is_marked(region_index, world.day):
		return ""
	return TechText.tr_key(KEY_MARKED).format(
		{PLACEHOLDER_DAYS: team.marked[region_index] - world.day})


## The console's line for one of the team's events, "" for the ones it keeps to
## the map (a hop, a target), for the setup a Misdirect abandoned — the
## Misdirect's own line says that — and for a setup slept through: the mark's
## line says that (§14.4).
static func console_line(event: SimEvent, world: World, db: ContentDB) -> String:
	var region: String = _region(world, db, str(event.data.get("region", "")))
	var action: String = action_name(db, str(event.data.get("action", "")))
	match event.type:
		SimEvent.TASK_FORCE_APPEARED:
			var key: String = KEY_CONSOLE_APPEARED_LED \
				if world.agent.has_story_flag(TaskForceSystem.FLAG_LED) else KEY_CONSOLE_APPEARED
			return TechText.tr_key(key).format({PLACEHOLDER_REGION: region})
		SimEvent.TASK_FORCE_SETUP:
			return TechText.tr_key(KEY_CONSOLE_SETUP).format({
				PLACEHOLDER_REGION: region,
				PLACEHOLDER_ACTION: action,
				PLACEHOLDER_DAYS: int(event.data.get("days", 0)),
			})
		SimEvent.TASK_FORCE_ACTED:
			return TechText.tr_key(KEY_CONSOLE_ACTED).format(
				{PLACEHOLDER_REGION: region, PLACEHOLDER_ACTION: action})
		SimEvent.TASK_FORCE_FIZZLED:
			var cause: String = str(event.data.get("cause", ""))
			if cause == TaskForceSystem.CAUSE_REDIRECTED or cause == TaskForceSystem.CAUSE_DORMANT:
				return ""
			return TechText.tr_key(KEY_CONSOLE_FIZZLED).format({PLACEHOLDER_REGION: region})
		SimEvent.TASK_FORCE_MISDIRECTED:
			return TechText.tr_key(KEY_CONSOLE_MISDIRECTED).format({PLACEHOLDER_REGION: region})
		SimEvent.TASK_FORCE_MARKED:
			return TechText.tr_key(KEY_CONSOLE_MARKED).format({
				PLACEHOLDER_REGION: region,
				PLACEHOLDER_DAYS: int(event.data.get("days", 0)),
			})
	return ""


static func _state(world: World, db: ContentDB) -> String:
	var team: TaskForce = world.task_force
	var here: String = EventView.region_name(world, team.region)
	match team.state:
		TaskForce.STATE_TRAVEL:
			if not TaskForceSystem.target_shown(world):
				return TechText.tr_key(KEY_STATE_TRAVEL_UNKNOWN)
			return TechText.tr_key(KEY_STATE_TRAVEL).format(
				{PLACEHOLDER_REGION: EventView.region_name(world, team.target)})
		TaskForce.STATE_SETUP:
			return TechText.tr_key(KEY_STATE_SETUP).format({
				PLACEHOLDER_ACTION: action_name(db, team.action),
				PLACEHOLDER_REGION: here,
				PLACEHOLDER_DAYS: TaskForceSystem.setup_days_left(world, db),
			})
	return TechText.tr_key(KEY_STATE_REST).format({PLACEHOLDER_REGION: here})


static func _region(world: World, db: ContentDB, region_id: String) -> String:
	return EventView.region_name(world, int(db.region_index_by_id.get(region_id, 0)))
