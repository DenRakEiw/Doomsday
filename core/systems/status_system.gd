class_name StatusSystem
extends SimSystem
## Applies, runs and ends every status, pulse and timed flag
## (`loop-mechanics.md` §7.2 and §7.4).
##
## It sits after containment and before events, so a status that ends today is
## gone before anything reacts to the world it left behind.
##
## `apply` and `end` are static because the commands and `EffectRunner` call
## them between ticks: applying a status is not something a tick does to the
## world, it is something that happens *to* the world at any moment. The tick
## itself only takes things away again.

## Causes of `status_ended` (§7.4).
const CAUSE_EXPIRED: String = "expired"
const CAUSE_ENDED: String = "ended"
## Reserved for the region panel's *Cancel* button, which no status offers yet.
const CAUSE_CANCELLED: String = "cancelled"


## Everything whose day has come, in one order: statuses, then pulses, then
## timed flags. Cooldowns need nothing — `ability_ready_day` compares.
func tick(world: World, db: ContentDB, events: Array[SimEvent]) -> void:
	if world.agent.origin == 0:
		return
	_expire_statuses(world, db, events)
	_expire_pulses(world, events)
	_expire_flags(world, events)


## Puts a status on a region (0 = on the agent) and answers the record. Never
## returns null: an unknown id is a programming error the loader has already
## ruled out, and a level outside the definition is clamped.
##
## The order is §7.2's, and it matters: what this status ends goes first, so its
## own `on_start` cannot be undone by it.
static func apply(world: World, db: ContentDB, status_id: String, region: int, source: String,
		level: int, option: String, events: Array[SimEvent],
		days_override: int = 0) -> Status:
	var definition: StatusDef = db.status(status_id)
	if definition == null:
		push_error("unknown status \"%s\"" % status_id)
		return null
	var index: int = definition.clamp_level(level)
	var lvl: StatusLevelDef = definition.levels[index - 1]

	for ended_id: String in lvl.ends_statuses:
		var running: Status = world.status_in_region(ended_id, region)
		if running != null:
			end(world, db, running, CAUSE_ENDED, events)

	var status: Status = world.status_in_region(status_id, region)
	var refreshed: bool = status != null
	if not refreshed:
		status = Status.new()
		status.id = status_id
		status.region = region
		world.statuses.append(status)
	status.level = index
	status.source = source
	status.option = option
	status.started_day = world.day
	status.until_day = _until_day(world.day, lvl, days_override)
	# A refreshed status re-evaluates which links it holds: the level may have
	# changed, and the region's links may have.
	_reopen_links(world, status)
	status.closed_links.clear()

	world.modifiers.add_source(status.source_id(),
		definition.scoped_modifiers(index, region), [])
	_close_links(world, definition, lvl, status)

	events.append(SimEvent.new(SimEvent.STATUS_STARTED, world.day, {
		"status": status_id,
		"region": "" if region == 0 else world.regions[region].def.id,
		"source": source,
		"level": index,
		"until_day": status.until_day,
		"refreshed": refreshed,
	}))
	var context: EffectContext = EffectContext.for_status(status_id, region)
	EffectRunner.apply_all(_sim_for(world, db), lvl.on_start, context, events)
	return status


## Takes a status away. The one function expiry, `ends_statuses`, `end_statuses`
## and the reserved *Cancel* all go through, so a status can never be removed
## without its links reopening and its source going with it.
##
## `on_end` runs **only** when the cause is expiry (§7.4 step 1, D4.2): a status
## cut short never had its consequence come to pass.
static func end(world: World, db: ContentDB, status: Status, cause: String,
		events: Array[SimEvent]) -> void:
	var definition: StatusDef = db.status(status.id)
	if cause == CAUSE_EXPIRED and definition != null:
		var lvl: StatusLevelDef = definition.level_at(status.level)
		if lvl != null:
			EffectRunner.apply_all(_sim_for(world, db), lvl.on_end,
				EffectContext.for_status(status.id, status.region), events)
	world.modifiers.remove_source(status.source_id())
	world.statuses.erase(status)
	# After the removal: a link is held only by the statuses that are still there.
	_reopen_links(world, status)
	events.append(SimEvent.new(SimEvent.STATUS_ENDED, world.day, {
		"status": status.id,
		"region": "" if status.region == 0 else world.regions[status.region].def.id,
		"cause": cause,
	}))


## Ends every listed status in one region, cause `"ended"` (§8.2's
## `end_statuses`). Collected first, so ending one cannot skip the next.
static func end_listed(world: World, db: ContentDB, ids: Array[String], region: int,
		events: Array[SimEvent]) -> void:
	var doomed: Array[Status] = []
	for id: String in ids:
		var running: Status = world.status_in_region(id, region)
		if running != null:
			doomed.append(running)
	for status: Status in doomed:
		end(world, db, status, CAUSE_ENDED, events)


## Starts a pulse: a timed Footprint with no status behind it (§8.2).
static func add_pulse(world: World, value: float, until_day: int,
		watched_by: Array[String], events: Array[SimEvent]) -> Pulse:
	var pulse: Pulse = Pulse.new()
	pulse.index = world.next_pulse_id
	world.next_pulse_id += 1
	pulse.value = value
	pulse.until_day = until_day
	pulse.watched_by = watched_by.duplicate()
	world.pulses.append(pulse)
	var modifier: ModifierDef = ModifierDef.new()
	modifier.target = TARGET_FOOTPRINT
	modifier.op = ModifierDef.Op.ADD
	modifier.value = value
	modifier.scope_kind = ModifierDef.ScopeKind.NONE
	var modifiers: Array[ModifierDef] = [modifier]
	var no_flags: Array[String] = []
	world.modifiers.add_source(pulse.source_id(), modifiers, no_flags)
	events.append(SimEvent.new(SimEvent.PULSE_STARTED, world.day, {
		"index": pulse.index,
		"value": value,
		"until_day": until_day,
	}))
	return pulse


## The target a pulse adds to. Named here because a pulse has no definition.
const TARGET_FOOTPRINT: String = "footprint"


## Sets a timed flag: a source with no modifiers whose only job is to answer
## `has_flag` while it stands (§8.2).
static func set_timed_flag(world: World, flag: String, until_day: int,
		events: Array[SimEvent]) -> void:
	world.agent.timed_flags[flag] = until_day
	var no_modifiers: Array[ModifierDef] = []
	var flags: Array[String] = [flag]
	world.modifiers.add_source(ModifierStack.source_for_flag(flag), no_modifiers, flags)
	events.append(SimEvent.new(SimEvent.FLAG_SET, world.day,
		{"flag": flag, "until_day": until_day}))


## Sets a story flag: it never expires and is saved in the agent's list, in the
## order flags were set. Setting one twice changes nothing and says nothing.
static func set_story_flag(world: World, flag: String, events: Array[SimEvent]) -> void:
	if world.agent.has_story_flag(flag):
		return
	world.agent.story_flags.append(flag)
	events.append(SimEvent.new(SimEvent.FLAG_SET, world.day,
		{"flag": flag, "until_day": Status.UNTIL_STANDING}))


## Rebuilds the modifier sources of the running statuses, pulses and timed flags
## after a load, which brings a world with no stack at all (`Simulation.
## rebuild_modifiers`).
static func rebuild_sources(world: World, db: ContentDB) -> void:
	for status: Status in world.statuses:
		var definition: StatusDef = db.status(status.id)
		if definition == null:
			continue
		world.modifiers.add_source(status.source_id(),
			definition.scoped_modifiers(status.level, status.region), [])
	for pulse: Pulse in world.pulses:
		var modifier: ModifierDef = ModifierDef.new()
		modifier.target = TARGET_FOOTPRINT
		modifier.op = ModifierDef.Op.ADD
		modifier.value = pulse.value
		modifier.scope_kind = ModifierDef.ScopeKind.NONE
		var modifiers: Array[ModifierDef] = [modifier]
		var no_flags: Array[String] = []
		world.modifiers.add_source(pulse.source_id(), modifiers, no_flags)
	for flag: String in world.agent.timed_flags:
		var no_modifiers: Array[ModifierDef] = []
		var flags: Array[String] = [flag]
		world.modifiers.add_source(ModifierStack.source_for_flag(flag), no_modifiers, flags)


# ------------------------------------------------------------------ the tick


## Collected first, then ended one by one: an `on_end` that applies a status
## must not change the list this loop is walking.
static func _expire_statuses(world: World, db: ContentDB, events: Array[SimEvent]) -> void:
	var due: Array[Status] = []
	for status: Status in world.statuses:
		if not status.is_standing() and status.until_day <= world.day:
			due.append(status)
	for status: Status in due:
		# An `on_end` of an earlier one may have ended this one already.
		if world.statuses.has(status):
			end(world, db, status, CAUSE_EXPIRED, events)


static func _expire_pulses(world: World, events: Array[SimEvent]) -> void:
	var due: Array[Pulse] = []
	for pulse: Pulse in world.pulses:
		if pulse.until_day <= world.day:
			due.append(pulse)
	for pulse: Pulse in due:
		world.modifiers.remove_source(pulse.source_id())
		world.pulses.erase(pulse)
		events.append(SimEvent.new(SimEvent.PULSE_ENDED, world.day, {"index": pulse.index}))


static func _expire_flags(world: World, events: Array[SimEvent]) -> void:
	var due: Array[String] = []
	for flag: String in world.agent.timed_flags:
		if world.agent.timed_flags[flag] <= world.day:
			due.append(flag)
	for flag: String in due:
		world.agent.timed_flags.erase(flag)
		world.modifiers.remove_source(ModifierStack.source_for_flag(flag))
		events.append(SimEvent.new(SimEvent.FLAG_EXPIRED, world.day, {"flag": flag}))


# ----------------------------------------------------------------- the links


## Closes the region's links of the listed kinds and records the ones this
## status is now holding. A link that was already closed by another status is
## still recorded, so that neither of them reopens it alone (§7.2 step 6).
static func _close_links(world: World, definition: StatusDef, lvl: StatusLevelDef,
		status: Status) -> void:
	if status.region <= 0 or lvl.closes_links.is_empty():
		return
	var all: bool = lvl.closes_links.has(StatusDef.LINKS_ALL)
	for link: Link in world.links:
		if link.def.a != status.region and link.def.b != status.region:
			continue
		if not all and not lvl.closes_links.has(link.def.kind):
			continue
		link.open = false
		status.closed_links.append(link.def.id)
	# `definition` is not read here; it is in the signature so that a future
	# rule about which links a *status* closes has one place to go.
	assert(definition != null)


## Reopens every link this status was holding that nothing else holds. Called
## after the status has left `world.statuses`, so "nothing else" is the truth.
static func _reopen_links(world: World, status: Status) -> void:
	for link_id: String in status.closed_links:
		if world.link_held_closed(link_id):
			continue
		for link: Link in world.links:
			if link.def.id == link_id:
				link.open = true
				break
	status.closed_links.clear()


## The day a level ends. A `days` override of 0 means the level's own, and a
## standing level stays standing unless an override gives it a length (§7.1).
static func _until_day(day: int, lvl: StatusLevelDef, days_override: int) -> int:
	if days_override > 0:
		return day + days_override
	if lvl.is_standing():
		return Status.UNTIL_STANDING
	return day + lvl.days


## The effects need a `Simulation`, and a system only ever has the world and the
## content. The view points at the same world, so an effect applied through it
## changes the run it came from (`Simulation.view`).
static func _sim_for(world: World, db: ContentDB) -> Simulation:
	return Simulation.view(db, world)
