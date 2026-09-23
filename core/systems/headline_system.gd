class_name HeadlineSystem
extends RefCounted
## Turns what happened into what the world says about it (spec ticker.md §3).
##
## It runs after every system with the whole tick's outbox, which is why it is
## not a `SimSystem`: the array's contract is "run in order with the outbox so
## far", and this one needs all of it. It never touches `world` and never
## consumes `world.rng`, so a run's state hash is the same with and without it.

## §3.5: a discovery on a tick with three seeds is never crowded out.
const URGENT_TYPES: Array[String] = [SimEvent.OUTCOME_REACHED, SimEvent.PHASE_CHANGED,
	SimEvent.DISCOVERED, SimEvent.HARM_BURST]
## §3.6: the headline stream is the world's seed, salted, so that the same run
## with and without headlines rolls the same dice everywhere else.
const SEED_SALT: int = 0x48454144

const NEVER: int = -1

var _rng: SimRng
var _fires: Dictionary[String, int] = {}
var _last_day: Dictionary[String, int] = {}
var _stream_last_day: Dictionary[String, int] = {}
var _filler_next_day: int = 0


static func create(seed_value: int) -> HeadlineSystem:
	var system: HeadlineSystem = HeadlineSystem.new()
	system._rng = SimRng.from_seed(seed_value ^ SEED_SALT)
	return system


# --------------------------------------------------------------- the two passes


## One tick: the events it produced, then the world as it now stands. Returns
## the `headline` events to append to the outbox, in firing order.
func on_tick(world: World, db: ContentDB, events: Array[SimEvent]) -> Array[SimEvent]:
	var cap: int = db.balance.headlines_max_per_tick
	var out: Array[SimEvent] = []
	var ending: Array[SimEvent] = _outcome_events(events)
	if not ending.is_empty():
		# The run is over. Whatever else happened on this tick, the only thing
		# worth saying is how it ended, and it is the last line of the run
		# (§3.5); the state pass does not run either.
		_event_pass(world, db, ending, cap, out)
		return out
	_event_pass(world, db, events, cap, out)
	_state_pass(world, db, cap, out)
	return out


## One accepted command: its events only. A command is not a day.
func on_command(world: World, db: ContentDB, events: Array[SimEvent]) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	_event_pass(world, db, events, db.balance.headlines_max_per_command, out)
	return out


## §3.5: the urgent types first, in their own order, then the rest.
func _event_pass(world: World, db: ContentDB, events: Array[SimEvent], cap: int,
		out: Array[SimEvent]) -> void:
	for event: SimEvent in _ordered(events):
		if out.size() >= cap:
			return
		var candidates: Array[HeadlineDef] = _candidates_for(event, world, db)
		if candidates.is_empty():
			continue
		_fire(_select(candidates), event.data, world, db, out)


## The reaction and the filler of §3.5, in that order. Only a run that has begun
## is narrated: before an origin there is nothing to say.
func _state_pass(world: World, db: ContentDB, cap: int, out: Array[SimEvent]) -> void:
	if world.agent.origin == 0:
		return
	if out.size() < cap and _reaction_is_due(world, db):
		var reactions: Array[HeadlineDef] = _state_candidates(HeadlineDef.STREAM_REACTION,
			world, db)
		if not reactions.is_empty():
			_fire(_select(reactions), {}, world, db, out)
	if out.size() < cap:
		_filler_pass(world, db, out)


func _reaction_is_due(world: World, db: ContentDB) -> bool:
	var last: int = _stream_last_day.get(HeadlineDef.STREAM_REACTION, NEVER)
	if last < 0:
		return true
	return world.day - last >= db.balance.headlines_reaction_gap_days


## Filler keeps its own clock: it is the pace of a quiet world, not a reaction to
## it. A world loud enough to silence it leaves the clock alone (§3.5).
func _filler_pass(world: World, db: ContentDB, out: Array[SimEvent]) -> void:
	if world.day < _filler_next_day or _filler_is_silenced(world, db):
		return
	var candidates: Array[HeadlineDef] = _state_candidates(HeadlineDef.STREAM_FILLER, world, db)
	if candidates.is_empty():
		_filler_next_day = world.day + 1
		return
	_fire(_select(candidates), {}, world, db, out)
	_filler_next_day = world.day + _filler_gap(world, db)


func _filler_is_silenced(world: World, db: ContentDB) -> bool:
	if HeadlineConditions.dark_count(world) >= db.balance.headlines_filler_silence_dark:
		return true
	return HeadlineConditions.deaths_share(world, db) \
		>= db.balance.headlines_filler_silence_deaths_share


## The quieter the world, the closer the lines; every dark region stretches them.
func _filler_gap(world: World, db: ContentDB) -> int:
	var phase_id: String = World.PHASE_IDS[world.phase]
	var gap: float = db.balance.headlines_filler_gap_days[phase_id]
	gap += db.balance.headlines_filler_per_dark_region * float(HeadlineConditions.dark_count(world))
	return int(gap)


# ------------------------------------------------------------------ eligibility


## §3.4 for one event, fallbacks last: a headline written for this very node is
## always preferred to the line that fits any of them.
func _candidates_for(event: SimEvent, world: World, db: ContentDB) -> Array[HeadlineDef]:
	var specific: Array[HeadlineDef] = []
	var fallbacks: Array[HeadlineDef] = []
	for def: HeadlineDef in db.headlines:
		if def.on_event != event.type:
			continue
		if not _is_eligible(def, world, db):
			continue
		if not HeadlineConditions.event_matches(def, event, db):
			continue
		if def.fallback:
			fallbacks.append(def)
		else:
			specific.append(def)
	if specific.is_empty():
		return _rolled(fallbacks)
	return _rolled(specific)


## §3.6: one RNG value per candidate whose `chance` is not 1, in file order,
## always consumed — a roll the caller skips would move the stream.
func _rolled(candidates: Array[HeadlineDef]) -> Array[HeadlineDef]:
	var out: Array[HeadlineDef] = []
	for def: HeadlineDef in candidates:
		if def.chance >= 1.0:
			out.append(def)
			continue
		if _rng.chance(def.chance):
			out.append(def)
	return out


## The eligible state-triggered headlines of one stream, in file order.
func _state_candidates(stream: String, world: World, db: ContentDB) -> Array[HeadlineDef]:
	var out: Array[HeadlineDef] = []
	for def: HeadlineDef in db.headlines:
		if def.stream != stream or def.has_event_trigger():
			continue
		if _is_eligible(def, world, db):
			out.append(def)
	return out


## §3.4 without the event half: register, fires, cooldown and `when`.
func _is_eligible(def: HeadlineDef, world: World, db: ContentDB) -> bool:
	if not _register_fits(def, world):
		return false
	if def.max_fires > 0 and fires(def.id) >= def.max_fires:
		return false
	var last: int = last_day(def.id)
	if last >= 0 and world.day - last < def.cooldown_days:
		return false
	return HeadlineConditions.state_holds(def, world, db)


static func _register_fits(def: HeadlineDef, world: World) -> bool:
	if def.register == HeadlineDef.REGISTER_ANY:
		return true
	var open: bool = world.phase == World.Phase.OPEN
	return open == (def.register == HeadlineDef.REGISTER_EMERGENCY)


# -------------------------------------------------------------------- selection


## §3.6: weighted, one `randf()` per non-empty candidate set.
func _select(candidates: Array[HeadlineDef]) -> HeadlineDef:
	var total: float = 0.0
	for def: HeadlineDef in candidates:
		total += def.weight
	var roll: float = _rng.randf() * total
	var accumulated: float = 0.0
	for def: HeadlineDef in candidates:
		accumulated += def.weight
		if roll < accumulated:
			return def
	# `randf()` can return exactly 1.0.
	return candidates.back()


## Firing commits: this is the only place the counters move.
func _fire(def: HeadlineDef, event_data: Dictionary, world: World, db: ContentDB,
		out: Array[SimEvent]) -> void:
	_fires[def.id] = fires(def.id) + 1
	_last_day[def.id] = world.day
	# The stream clock paces the *state* pass; an event-triggered line is news
	# whenever it happens and does not push the gap (§3.5).
	if not def.has_event_trigger():
		_stream_last_day[def.stream] = world.day
	out.append(SimEvent.new(SimEvent.HEADLINE, world.day,
		HeadlineArgs.build(def, event_data, world, db)))


static func _outcome_events(events: Array[SimEvent]) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for event: SimEvent in events:
		if event.type == SimEvent.OUTCOME_REACHED:
			out.append(event)
	return out


static func _ordered(events: Array[SimEvent]) -> Array[SimEvent]:
	var urgent: Array[SimEvent] = []
	var rest: Array[SimEvent] = []
	for event: SimEvent in events:
		if URGENT_TYPES.has(event.type):
			urgent.append(event)
		else:
			rest.append(event)
	urgent.append_array(rest)
	return urgent


# ----------------------------------------------------------------- pure queries


func fires(headline_id: String) -> int:
	return _fires.get(headline_id, 0)


## The day this headline last fired, or `NEVER`.
func last_day(headline_id: String) -> int:
	return _last_day.get(headline_id, NEVER)


func filler_next_day() -> int:
	return _filler_next_day


# ------------------------------------------------------------------ save state


## §3.9. Plain JSON numbers, the RNG as strings like `world.rng`.
func to_dict() -> Dictionary:
	return {
		"rng_seed": _rng.seed_string(),
		"rng_state": _rng.state_string(),
		"fires": _fires.duplicate(),
		"last_day": _last_day.duplicate(),
		"stream_last_day": _stream_last_day.duplicate(),
		"filler_next_day": _filler_next_day,
	}


## The saved system, or null for a block that is there but malformed — which is a
## corrupt save, not a reason to start the narration over. A headline the content
## no longer has is dropped: `content_mismatch` already says the content changed.
static func from_dict(d: Dictionary, db: ContentDB) -> HeadlineSystem:
	for key: String in ["rng_seed", "rng_state"]:
		if typeof(d.get(key)) != TYPE_STRING:
			return null
	for key: String in ["fires", "last_day", "stream_last_day"]:
		if typeof(d.get(key)) != TYPE_DICTIONARY:
			return null
	var next_day: Variant = d.get("filler_next_day")
	if not [TYPE_INT, TYPE_FLOAT].has(typeof(next_day)) or float(next_day) != floor(float(next_day)):
		return null

	var system: HeadlineSystem = HeadlineSystem.new()
	system._rng = SimRng.from_strings(str(d["rng_seed"]), str(d["rng_state"]))
	if not _read_counts(system._fires, d["fires"], db):
		return null
	if not _read_counts(system._last_day, d["last_day"], db):
		return null
	if not _read_counts(system._stream_last_day, d["stream_last_day"], null):
		return null
	system._filler_next_day = int(next_day)
	return system


## Whole numbers by id. `db` of null means the keys are stream names, which no
## content can invalidate; otherwise an unknown headline id is dropped.
static func _read_counts(into: Dictionary[String, int], raw: Variant, db: ContentDB) -> bool:
	var source: Dictionary = raw
	for key: Variant in source:
		if typeof(key) != TYPE_STRING:
			return false
		var value: Variant = source[key]
		if not [TYPE_INT, TYPE_FLOAT].has(typeof(value)) or float(value) != floor(float(value)):
			return false
		if db != null and db.headline(str(key)) == null:
			continue
		into[str(key)] = int(value)
	return true
