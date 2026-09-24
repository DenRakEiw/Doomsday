class_name CounterMoveSystem
extends SimSystem
## The factions' moves (opposition.md §6): each faction prepares one move at a
## time, announces it, and fires it on the day the countdown ends — as a map
## event of kind `counter_move` whose status is the move itself.
##
## Per faction, in `world.factions` order: a preparation whose day has come
## fires (or waits, while the world already has `max_active_moves` of its
## statuses standing); otherwise, out of cooldown, the faction starts preparing
## the triggered move it has made least recently. The only random draw is the
## region of an eligibility-picked move, on the sim's stream.


func tick(world: World, db: ContentDB, events: Array[SimEvent]) -> void:
	if world.agent.origin == 0:
		return
	var sim: Simulation = Simulation.view(db, world)
	for faction: Faction in world.factions:
		var definition: FactionDef = db.faction(faction.id)
		if definition == null:
			continue
		if not faction.preparing.is_empty():
			if world.day >= faction.fire_day:
				_fire(sim, faction, events)
			continue
		if world.day >= faction.cooldown_until:
			_prepare(sim, faction, definition, events)


# --------------------------------------------------------------------- firing


## §6.1: held while the world's moves fill the cap, dropped when there is
## nowhere to land, otherwise scheduled for today at the level the track calls for.
static func _fire(sim: Simulation, faction: Faction, events: Array[SimEvent]) -> void:
	var world: World = sim.world
	var db: ContentDB = sim.db
	if moves_standing(world, db) >= db.balance.factions_max_active_moves:
		return
	var def: EventDef = db.event(faction.preparing)
	if def == null:
		_reset(world, db, faction)
		return
	var region: int = _target(sim, def, true)
	if region < 0:
		events.append(SimEvent.new(SimEvent.COUNTER_MOVE_DROPPED, world.day, {
			"faction": faction.id,
			"event": def.id,
			"cause": SimEvent.CAUSE_NO_SITE,
		}))
		_reset(world, db, faction)
		return
	EventSystem.schedule(world, def.id, region, faction.id, world.day,
		level_for(db, faction.containment, def.status))
	_reset(world, db, faction)


## What counts against `max_active_moves` (§6.7): the world's statuses standing,
## plus the counter-moves already on their way — open on the map or scheduled —
## whose status is not applied yet. Without the second half, four factions
## firing on one tick would each see room and put up seven.
static func moves_standing(world: World, db: ContentDB) -> int:
	var count: int = world.status_count_by_faction()
	for event: OpenEvent in world.events:
		var def: EventDef = db.event(event.def)
		if def != null and def.kind == EventDef.KIND_COUNTER_MOVE:
			count += 1
	for pending: PendingEvent in world.pending_events:
		var def: EventDef = db.event(pending.def)
		if def != null and def.kind == EventDef.KIND_COUNTER_MOVE:
			count += 1
	return count


## After a move fires or is dropped: nothing in preparation, and the cooldown.
static func _reset(world: World, db: ContentDB, faction: Faction) -> void:
	faction.preparing = ""
	faction.fire_day = -1
	faction.cooldown_until = world.day + db.balance.factions_cooldown_days


## §6.1 step 3: one level per `level_thresholds` entry the track has reached,
## never more than the status has.
static func level_for(db: ContentDB, containment: float, status_id: String) -> int:
	var level: int = 1
	for threshold: float in db.balance.factions_level_thresholds:
		if containment >= threshold:
			level += 1
	var status: StatusDef = db.status(status_id)
	if status != null:
		level = mini(level, status.levels.size())
	return maxi(1, level)


## Where `def` lands: 0 for a global move, a region index, or −1 for nowhere.
## `draw` false only counts (§6.2's "targetable now" uses no RNG); it answers 1
## for "somewhere" then.
static func _target(sim: Simulation, def: EventDef, draw: bool) -> int:
	var world: World = sim.world
	if not def.pick_rule.is_empty():
		var picked: int = CounterMoveRules.pick(def.pick_rule, world, sim.db, def.status)
		return picked if picked != CounterMoveRules.NONE else -1
	if def.pick == null:
		return 0
	var candidates: PackedInt32Array = []
	for index: int in sim.eligible_regions(def.pick):
		if CounterMoveRules.region_open(world, sim.db, index, def.status):
			candidates.append(index)
	if candidates.is_empty():
		return -1
	if not draw:
		return candidates[0]
	var weights: PackedFloat64Array = []
	for index: int in candidates:
		var weight: float = 1.0
		if def.pick_weight == EventDef.PICK_WEIGHT_HARDWARE_PENETRATION:
			weight = sim.hardware(index) * world.regions[index].penetration
		weights.append(weight)
	var picked_at: int = world.rng.weighted_pick(weights)
	if picked_at < 0:
		weights.fill(1.0)
		picked_at = world.rng.weighted_pick(weights)
	return candidates[picked_at]


# ------------------------------------------------------------------ preparing


## §6.2: of the moves whose trigger is met and which could land today, the one
## made least recently — a faction alternates rather than repeating its
## strongest — ties to the later move.
static func _prepare(sim: Simulation, faction: Faction, definition: FactionDef,
		events: Array[SimEvent]) -> void:
	var world: World = sim.world
	var db: ContentDB = sim.db
	var chosen: String = ""
	var chosen_last: int = 0
	for move: FactionMoveDef in definition.moves:
		if not _triggered(sim, faction, move):
			continue
		var event_id: String = resolve(move, world, db)
		var def: EventDef = db.event(event_id)
		if def == null or _target(sim, def, false) < 0:
			continue
		var last: int = int(world.event_last_day.get(event_id, -1))
		if chosen.is_empty() or last <= chosen_last:
			chosen = event_id
			chosen_last = last
	if chosen.is_empty():
		return
	faction.preparing = chosen
	faction.fire_day = world.day + prepare_days(db, faction.containment)
	events.append(SimEvent.new(SimEvent.COUNTER_MOVE_PREPARED, world.day, {
		"faction": faction.id,
		"event": chosen,
		"fire_day": faction.fire_day,
	}))


## How long a move is prepared at this containment: the closer they are, the
## faster they act, never faster than the minimum.
static func prepare_days(db: ContentDB, containment: float) -> int:
	return maxi(db.balance.factions_prepare_min_days,
		roundi(float(db.balance.factions_prepare_days) * (1.0 - containment)))


static func _triggered(sim: Simulation, faction: Faction, move: FactionMoveDef) -> bool:
	if move.trigger_containment >= 0.0 and faction.containment >= move.trigger_containment:
		return true
	if move.trigger_risk >= 0.0 and not sim.world.discovered:
		var risk: float = float(sim.discovery_risk()[ContainmentSystem.RISK_TOTAL])
		return risk >= move.trigger_risk
	return false


## The event a move opens now: its variant for the selector's key, or its own.
static func resolve(move: FactionMoveDef, world: World, db: ContentDB) -> String:
	if move.variants_select.is_empty():
		return move.event
	var key: String = CounterMoveRules.select(move.variants_select, world, db)
	return move.variants.get(key, move.event)


# -------------------------------------------------------------------- queries


## §6.6: what the panel counts down.
static func next_move(world: World, db: ContentDB, faction_id: String) -> Dictionary:
	var faction: Faction = world.faction(faction_id)
	if faction == null:
		return {}
	if not faction.preparing.is_empty():
		if world.day < faction.fire_day:
			return {"state": "preparing", "event": faction.preparing,
				"days": faction.fire_day - world.day}
		return {"state": "held", "event": faction.preparing, "days": 0}
	if faction.cooldown_until - world.day > 0:
		return {"state": "cooldown", "event": "", "days": faction.cooldown_until - world.day}
	return {"state": "none", "event": "", "days": 0}


## The last move a faction made, as `[event id, day]`, or `["", -1]` — derived
## from `event_last_day` over its moves and their variants, no state of its own.
static func last_move(world: World, db: ContentDB, faction_id: String) -> Array:
	var definition: FactionDef = db.faction(faction_id)
	var best: String = ""
	var best_day: int = -1
	if definition == null:
		return [best, best_day]
	for move: FactionMoveDef in definition.moves:
		for event_id: String in move.event_ids():
			var day: int = int(world.event_last_day.get(event_id, -1))
			if day > best_day:
				best_day = day
				best = event_id
	return [best, best_day]
