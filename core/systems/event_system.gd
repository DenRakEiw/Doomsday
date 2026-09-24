class_name EventSystem
extends SimSystem
## Opens, schedules and closes map events (`loop-mechanics.md` §10.4–§10.6).
##
## Each tick, in order: open events whose deadline has come are answered with
## their default; due pending events open while there is room; and, when nothing
## pending is due, one roll decides whether the world leaves an opening lying
## around. A chain's first step is rolled with the openings — a chain is an
## opening that continues.
##
## `open`, `schedule` and `answer` are static because the command, the schedule
## of S4.5 and the tests all reach them between ticks.


func tick(world: World, db: ContentDB, events: Array[SimEvent]) -> void:
	if world.agent.origin == 0:
		return
	var sim: Simulation = Simulation.view(db, world)
	_deadlines(sim, events)
	# The agent's own beat (`replayability.md` §3.1), before the world's: it does
	# not wait for a pending event, and it never opens a second card of its kind.
	_emergent(sim, events)
	# A tick that had a pending event due is that event's: the world does not
	# also leave an opening lying around (§10.4 step 3).
	if _pending(sim, events):
		return
	_openings(sim, events)


## Opens `def` now and answers the record (§10.6): the id, the deadline, the
## counters `max_fires` and `cooldown_days` read, and the definition's story
## flags. The caller has chosen the region. `db` is in the signature the spec
## gives S4.5's schedule, which will need it.
@warning_ignore("unused_parameter")
static func open(world: World, db: ContentDB, def: EventDef, region: int, faction: String,
		level: int, events: Array[SimEvent]) -> OpenEvent:
	var event: OpenEvent = OpenEvent.new()
	event.id = world.next_event_id
	world.next_event_id += 1
	event.def = def.id
	event.region = region
	event.faction = faction
	event.opened_day = world.day
	event.deadline_day = world.day + def.deadline_days
	event.level = maxi(1, level)
	world.event_fires[def.id] = int(world.event_fires.get(def.id, 0)) + 1
	world.event_last_day[def.id] = world.day
	world.events.append(event)
	events.append(SimEvent.new(SimEvent.EVENT_OPENED, world.day, {
		"event": event.id,
		"def": def.id,
		"kind": def.kind,
		"region": _region_id(world, region),
		"faction": faction,
		"deadline_day": event.deadline_day,
		"modal": def.modal,
	}))
	for flag: String in def.flags:
		StatusSystem.set_story_flag(world, flag, events)
	return event


## Schedules an event to open on `due_day` (§10.6) — the door the counter-move
## schedule of S4.5 uses, and what a chain's `next` goes through. A region of 0
## lets the definition pick its own when it opens.
static func schedule(world: World, def_id: String, region: int, faction: String, due_day: int,
		level: int) -> PendingEvent:
	var pending: PendingEvent = PendingEvent.new()
	pending.def = def_id
	pending.region = region
	pending.faction = faction
	pending.due_day = due_day
	pending.level = maxi(1, level)
	# Due order, ties in scheduling order: after every entry due the same day.
	var at: int = world.pending_events.size()
	for i: int in world.pending_events.size():
		if world.pending_events[i].due_day > due_day:
			at = i
			break
	world.pending_events.insert(at, pending)
	return pending


## Answers an open event with one of its options (§10.5, steps 1–7). The command
## and the deadline share this path; `expired` says which of the two events is
## told first. The caller has checked everything the command checks.
static func answer(sim: Simulation, event: OpenEvent, option_id: String, expired: bool,
		events: Array[SimEvent]) -> void:
	var world: World = sim.world
	var def: EventDef = sim.db.event(event.def)
	var option: EventOptionDef = def.option(option_id)
	# The price is read before the count it depends on moves.
	world.agent.compute -= sim.option_cost(option)
	if def.kind == EventDef.KIND_EMERGENT:
		_count_emergent(sim, option)
	events.append(SimEvent.new(SimEvent.EVENT_EXPIRED if expired else SimEvent.EVENT_ANSWERED,
		world.day, {
			"event": event.id,
			"def": def.id,
			"region": _region_id(world, event.region),
			"option": option.id,
		}))
	for flag: String in option.flags:
		StatusSystem.set_story_flag(world, flag, events)

	var context: EffectContext = EffectContext.for_event(def.id, event.region)
	EffectRunner.apply_all(sim, option.effects, context, events)
	# Every roll is made, in order, whatever the earlier ones did: the stream is
	# what it is. A successful roll that carries a `next` routes the chain.
	var next: Array[Dictionary] = option.next
	for roll: EventChanceDef in option.chance:
		if not world.rng.chance(roll.p):
			continue
		EffectRunner.apply_all(sim, roll.effects, context, events)
		if roll.has_next:
			next = roll.next

	if not def.status.is_empty() and not option.skip_status:
		var level: int = option.status_level if option.status_level > 0 else event.level
		var faction: String = event.faction if not event.faction.is_empty() else def.faction
		StatusSystem.apply(world, sim.db, def.status, event.region,
			Status.source_for(Status.SOURCE_FACTION, faction), level, option.id, events,
			option.status_days)

	world.events.erase(event)
	for step: Dictionary in next:
		var step_def: EventDef = sim.db.event(str(step["step"]))
		var region: int = event.region if step_def != null and step_def.pick_same else 0
		schedule(world, str(step["step"]), region, "", world.day + int(step["delay_days"]), 1)


## §3.1: a suppression counts towards the next one's price and pulls the Swarm's
## copies back; keeping lets them wander further (§2.2 `drift`).
static func _count_emergent(sim: Simulation, option: EventOptionDef) -> void:
	var agent: Agent = sim.world.agent
	var drifts: bool = sim.world.has_hook(sim.db, ArchitectureDef.HOOK_DRIFT)
	if option.cost_suppression:
		agent.suppressions += 1
		if drifts:
			agent.drift = maxf(0.0, agent.drift - sim.db.balance.drift_per_suppressed)
	elif drifts:
		agent.drift = minf(DriftSystem.DRIFT_MAX, agent.drift + sim.db.balance.drift_per_kept)


## Takes every open and pending event bound to a region that has gone dark
## (`PopulationSystem.go_dark`). Nothing is answered — the place it was about is
## gone — so no default runs; `event_dropped` says so.
static func drop_in_region(world: World, region: int, events: Array[SimEvent]) -> void:
	for event: OpenEvent in world.events.duplicate():
		if event.region != region:
			continue
		world.events.erase(event)
		_dropped(world, event.def, region, SimEvent.CAUSE_DARK, events)
	for pending: PendingEvent in world.pending_events.duplicate():
		if pending.region != region:
			continue
		world.pending_events.erase(pending)
		_dropped(world, pending.def, region, SimEvent.CAUSE_DARK, events)


## The regions a rule accepts, in index order.
static func eligible(sim: Simulation, def: EventDef) -> PackedInt32Array:
	if def.pick == null:
		return PackedInt32Array()
	return sim.eligible_regions(def.pick)


# ------------------------------------------------------------------ the tick


## Step 1: collected first, then answered, because answering changes the list.
static func _deadlines(sim: Simulation, events: Array[SimEvent]) -> void:
	var due: Array[OpenEvent] = []
	for event: OpenEvent in sim.world.events:
		if event.deadline_day <= sim.world.day:
			due.append(event)
	for event: OpenEvent in due:
		var def: EventDef = sim.db.event(event.def)
		answer(sim, event, def.default_option, true, events)


## Step 2: the earliest due first, while there is room. True when anything was
## due, opened or not.
static func _pending(sim: Simulation, events: Array[SimEvent]) -> bool:
	var world: World = sim.world
	var due: bool = not world.pending_events.is_empty() \
		and world.pending_events[0].due_day <= world.day
	while world.open_event_count() < sim.db.balance.events_max_open \
			and not world.pending_events.is_empty() \
			and world.pending_events[0].due_day <= world.day:
		var pending: PendingEvent = world.pending_events.pop_front()
		_open_pending(sim, pending, events)
	return due


static func _open_pending(sim: Simulation, pending: PendingEvent,
		events: Array[SimEvent]) -> void:
	var world: World = sim.world
	var def: EventDef = sim.db.event(pending.def)
	if def == null:
		return
	if pending.region > 0 and world.regions[pending.region].dark:
		_dropped(world, def.id, pending.region, SimEvent.CAUSE_DARK, events)
		return
	var region: int = pending.region
	if region == 0 and def.pick != null:
		region = _pick_region(sim, def)
		if region == 0:
			_dropped(world, def.id, 0, SimEvent.CAUSE_NO_SITE, events)
			return
	elif region == 0 and not def.pick_rule.is_empty():
		# A named target rule is S4.5's (`CounterMoveRules`), and its schedule
		# always passes the region it picked; until then there is nowhere to go.
		_dropped(world, def.id, 0, SimEvent.CAUSE_NO_SITE, events)
		return
	open(world, sim.db, def, region, pending.faction, pending.level, events)


## Step 3: one roll, one weighted list — openings and chain starts together.
static func _openings(sim: Simulation, events: Array[SimEvent]) -> void:
	var world: World = sim.world
	var balance: BalanceDef = sim.db.balance
	if world.open_event_count() >= balance.events_max_open:
		return
	if world.seeded_count() < balance.events_opening_from_regions:
		return
	var chance: float = float(balance.events_opening_chance.get(World.PHASE_IDS[world.phase], 0.0))
	if chance <= 0.0:
		return
	if not world.rng.chance(chance):
		return
	var drawable: Array[EventDef] = candidates(sim)
	if drawable.is_empty():
		return
	var weights: PackedFloat64Array = []
	for def: EventDef in drawable:
		weights.append(def.weight)
	var picked: int = world.rng.weighted_pick(weights)
	if picked < 0:
		return
	var def: EventDef = drawable[picked]
	var region: int = 0
	if def.pick != null:
		region = _pick_region(sim, def)
	open(world, sim.db, def, region, "", 1, events)


## §3.1: once a day from Covert on, with chance `base_chance × emergent_rate`, one
## emergent card by weight among those that may come — never while one is open.
static func _emergent(sim: Simulation, events: Array[SimEvent]) -> void:
	var world: World = sim.world
	if world.phase < World.Phase.COVERT:
		return
	if world.open_event_count() >= sim.db.balance.events_max_open:
		return
	for open_event: OpenEvent in world.events:
		var open_def: EventDef = sim.db.event(open_event.def)
		if open_def != null and open_def.kind == EventDef.KIND_EMERGENT:
			return
	var chance: float = sim.db.balance.emergent_base_chance * sim.stat("emergent_rate")
	if chance <= 0.0 or not world.rng.chance(clampf(chance, 0.0, 1.0)):
		return
	var drawable: Array[EventDef] = candidates(sim, EventDef.KIND_EMERGENT)
	if drawable.is_empty():
		return
	var weights: PackedFloat64Array = []
	for def: EventDef in drawable:
		weights.append(def.weight)
	var picked: int = world.rng.weighted_pick(weights)
	if picked < 0:
		return
	var def: EventDef = drawable[picked]
	var region: int = _pick_region(sim, def) if def.pick != null else 0
	open(world, sim.db, def, region, "", 1, events)


## Every def the opening roll may draw right now, in content order (§10.4 step 3):
## rolled kinds whose `when` holds, under `max_fires`, past `cooldown_days`, and
## with somewhere to land.
## `kind` "" is the opening roll's list; `emergent` is the agent's own beat.
static func candidates(sim: Simulation, kind: String = "") -> Array[EventDef]:
	var world: World = sim.world
	var out: Array[EventDef] = []
	for def: EventDef in sim.db.events:
		if kind.is_empty() and not def.is_rolled():
			continue
		if not kind.is_empty() and def.kind != kind:
			continue
		var fires: int = int(world.event_fires.get(def.id, 0))
		if def.max_fires > 0 and fires >= def.max_fires:
			continue
		if def.cooldown_days > 0 and world.event_last_day.has(def.id) \
				and world.day - world.event_last_day[def.id] < def.cooldown_days:
			continue
		if not HeadlineConditions.holds(def.when, world, sim.db):
			continue
		if def.pick != null and eligible(sim, def).is_empty():
			continue
		out.append(def)
	return out


## A region for a def with an eligibility rule, drawn with the sim's RNG: weights
## 1, or hardware × penetration (a zero total falls back to uniform). 0 when no
## region is eligible.
static func _pick_region(sim: Simulation, def: EventDef) -> int:
	var regions: PackedInt32Array = eligible(sim, def)
	if regions.is_empty():
		return 0
	var weights: PackedFloat64Array = []
	for index: int in regions:
		var weight: float = 1.0
		if def.pick_weight == EventDef.PICK_WEIGHT_HARDWARE_PENETRATION:
			weight = sim.hardware(index) * sim.world.regions[index].penetration
		weights.append(weight)
	var picked: int = sim.world.rng.weighted_pick(weights)
	if picked < 0:
		weights.fill(1.0)
		picked = sim.world.rng.weighted_pick(weights)
	return regions[picked]


static func _dropped(world: World, def_id: String, region: int, cause: String,
		events: Array[SimEvent]) -> void:
	events.append(SimEvent.new(SimEvent.EVENT_DROPPED, world.day, {
		"def": def_id,
		"region": _region_id(world, region),
		"cause": cause,
	}))


static func _region_id(world: World, region: int) -> String:
	if region <= 0 or region >= world.regions.size():
		return ""
	return world.regions[region].def.id
