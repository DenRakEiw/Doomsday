extends Node
## Owns the run (spec ui-foundation.md §10.2): the `Simulation`, the fixed-step
## accumulator, the speed, and the draining of the simulation's events onto
## `EventBus`.
##
## This is the only place in the project that advances or mutates a simulation.
## The interface sends `Command`s through `apply` and reads `sim.world`; it never
## writes any of it. Real time enters here and nowhere else — a tick is a day, and
## how many days a frame is worth is `ticks_for`.
##
## An autoload, so no `class_name`.

const CONTENT_ROOT: String = "res://data"

## Days per second at 1×: one day every two seconds; 2× and 4× multiply it.
## Tuned at G3 against the 25–40 minute target.
const TICKS_PER_SECOND: float = 0.5
## A frame that was away for seconds catches up this far and drops the rest, so
## a stall can never spiral into a hang.
const MAX_TICKS_PER_FRAME: int = 8
const SPEEDS: Array[int] = [0, 1, 2, 4]
## Frames of 1/60 never sum to exactly the half second a tick takes at 4×, so an
## exact comparison drops one tick in four there. The tolerance is far below a
## frame and makes a second of real time a second of game time at every speed.
const TICK_EPSILON: float = 1e-9

## Why `apply` refused without ever reaching the simulation.
const FAIL_NO_RUN: String = "no_run"

## A seed is never 0: a player reporting "seed 0" would be reporting "no seed".
const MIN_SEED: int = 1

## The debug run of §10.2. M2 only — the keys and this constant go in M6.
const DEBUG_SEED: int = 1
const DEBUG_SAVE_SLOT: String = "debug"

## Null before a run.
var sim: Simulation = null
## Loaded once and kept: content does not change within a session.
var db: ContentDB = null
var speed: int = 0
## Compute after the last tick minus before it — yield and rewards, never
## purchases, which happen between ticks.
var compute_rate: float = 0.0
## Faction id → its containment after the last tick minus before it, so that a
## track can show a rate without keeping a history of its own (m3-screens §10.3).
var containment_rates: Dictionary[String, float] = {}
## Null unless a bot drives the run.
var policy: Policy = null
## Set by the debug keys: prints every tick and every event to the console.
var debug_log: bool = false
## The question the map is being asked, or null (`loop-mechanics.md` §16.1).
var site_request: SiteRequest = null

var _accumulator: float = 0.0
var _last_outcome: World.Outcome = World.Outcome.NONE
## Why the interface is holding the clock, and the speed to give back when the
## last reason goes (m3-screens §10.2).
var _holds: Dictionary[StringName, bool] = {}
var _speed_before_hold: int = 0


## The seed a new run gets (m3-screens §7.2). Presentation may draw from the
## global generator; `core/` may not, which is why it happens here.
func new_run_seed() -> int:
	return maxi(MIN_SEED, absi(int(randi())))


## The seed the run is playing, for the pause menu and the results screen.
func run_seed() -> int:
	return 0 if sim == null else int(sim.world.rng.seed_string().to_int())


# ------------------------------------------------------------------ the clock


## How many ticks `delta` is worth at `speed`, and what is left over. Static and
## pure, so the accumulator is testable without an autoload or a frame.
static func ticks_for(delta: float, speed_value: int, accumulator: float) -> Array:
	if speed_value <= 0:
		return [0, accumulator]
	var interval: float = 1.0 / (TICKS_PER_SECOND * float(speed_value))
	var rest: float = accumulator + delta
	var ticks: int = 0
	while rest + TICK_EPSILON >= interval and ticks < MAX_TICKS_PER_FRAME:
		rest -= interval
		ticks += 1
	if ticks >= MAX_TICKS_PER_FRAME and rest + TICK_EPSILON >= interval:
		# Over the cap the backlog is dropped rather than carried: catching up
		# for several frames in a row is how a slow frame becomes a frozen game.
		rest = 0.0
	return [ticks, rest]


func _process(delta: float) -> void:
	if sim == null or speed == 0:
		return
	var step: Array = ticks_for(delta, speed, _accumulator)
	_accumulator = float(step[1])
	advance(int(step[0]))


# -------------------------------------------------------------------- the run


## Starts a run on fresh content. `policy_id` empty means the player drives it;
## no origin is chosen here — the bot does that, or S3.4's origin screen.
func start_run(seed_value: int, policy_id: String = "") -> void:
	if not _ensure_content():
		return
	policy = Policy.create(policy_id) if not policy_id.is_empty() else null
	if policy != null:
		policy.setup(db, Policy.seed_for(seed_value))
	clear_holds()
	_adopt(Simulation.create(db, seed_value), seed_value)
	# A bot run drives itself, so it starts running; a player's run waits for the
	# origin choice S3.4 builds.
	_force_speed(1 if policy != null else 0)


## Drops the run without touching the content. Nothing is saved.
func stop_run() -> void:
	site_cancel()
	clear_holds()
	_force_speed(0)
	sim = null
	policy = null
	compute_rate = 0.0
	_accumulator = 0.0
	_last_outcome = World.Outcome.NONE


## Continues a simulation that came from a save (`SaveManager`). The policy is
## kept, so a bot run carries on where it left off.
func adopt_loaded(loaded: Simulation) -> void:
	db = loaded.db
	clear_holds()
	_adopt(loaded, loaded.world.rng.seed_string().to_int())
	_force_speed(0)


## Sends a command to the simulation and reports what it caused. The one door
## between the interface and the state.
func apply(command: Command) -> CommandResult:
	if sim == null:
		return CommandResult.rejected(FAIL_NO_RUN)
	var result: CommandResult = sim.apply(command)
	EventBus.command_applied.emit(command, result)
	for event: SimEvent in result.events:
		_report(event)
	return result


# ------------------------------------------------------------- site select


## Asks the map where. A second request replaces the first, and the first one's
## `on_cancel` runs — so the tree reopens even when an ability interrupted it.
##
## A bot run never enters the mode: a policy passes its region in the command,
## and a prompt strip over a headless run would answer nothing.
func site_select(request: SiteRequest) -> void:
	if policy != null or sim == null:
		return
	if site_request != null:
		_run_cancel(site_request)
	site_request = request
	EventBus.site_select_changed.emit(true)


## Leaves the mode and lets the caller put back whatever it took away.
func site_cancel() -> void:
	if site_request == null:
		return
	var request: SiteRequest = site_request
	site_request = null
	EventBus.site_select_changed.emit(false)
	_run_cancel(request)


## Answers with a region. A success leaves the mode; a failure stays in it, so
## the player can try another region without starting over.
func site_confirm(region_id: String) -> CommandResult:
	if site_request == null:
		return CommandResult.rejected(FAIL_NO_RUN)
	var command: Command = site_request.command_for(region_id)
	if command == null:
		return CommandResult.rejected(Command.FAIL_INVALID_REGION)
	var result: CommandResult = apply(command)
	if result.ok:
		site_request = null
		EventBus.site_select_changed.emit(false)
	return result


## Whether the map is being asked where right now.
func is_selecting_site() -> bool:
	return site_request != null


func _run_cancel(request: SiteRequest) -> void:
	if request.on_cancel.is_valid():
		request.on_cancel.call()


## A hold is the interface pausing the run for a reason — an open modal, the
## results screen. The first one remembers the speed, the last one gives it back;
## repeating a reason is not a second hold.
func hold(reason: StringName) -> void:
	if _holds.has(reason):
		return
	if _holds.is_empty():
		_speed_before_hold = speed
		_force_speed(0)
	_holds[reason] = true
	EventBus.hold_changed.emit(true)


func release(reason: StringName) -> void:
	if not _holds.erase(reason) or not _holds.is_empty():
		return
	EventBus.hold_changed.emit(false)
	if sim != null and sim.world.outcome == World.Outcome.NONE:
		_force_speed(_speed_before_hold)


func is_held() -> bool:
	return not _holds.is_empty()


## The speed the run goes back to once nothing holds it any more.
func held_speed() -> int:
	return _speed_before_hold


## Every hold is dropped: a load or a new run is a new clock.
func clear_holds() -> void:
	if _holds.is_empty():
		return
	_holds.clear()
	EventBus.hold_changed.emit(false)


## The speed itself, past any hold. Only the run's own turning points use it.
func _force_speed(value: int) -> void:
	var wanted: int = value if SPEEDS.has(value) else 0
	if wanted == speed:
		return
	speed = wanted
	# Time banked at the old rate would arrive as a burst at the new one.
	_accumulator = 0.0
	EventBus.speed_changed.emit(speed)


## What the keys and the speed buttons call. While the interface holds the clock
## the run stays where it is and the buttons keep showing the remembered speed.
func set_speed(value: int) -> void:
	if is_held():
		_speed_before_hold = value if SPEEDS.has(value) else 0
		return
	_force_speed(value)


## Advances `count` days now, whatever the clock says. The accumulator and the
## debug keys go through here, and so does a test that wants a run at a day.
func advance(count: int) -> void:
	for i: int in count:
		if sim == null or sim.world.outcome != World.Outcome.NONE:
			return
		_run_policy()
		var compute_before: float = sim.world.agent.compute
		var containment_before: Dictionary[String, float] = _containment_now()
		if not sim.tick():
			return
		compute_rate = sim.world.agent.compute - compute_before
		_measure_containment(containment_before)
		EventBus.tick_advanced.emit(sim.world.day)
		for event: SimEvent in sim.outbox:
			_report(event)
		if debug_log:
			print(_day_line())
		_check_outcome()


## The content, loaded on first use. False means it is unusable and there is no
## run — every error is printed, because a content error is a defect in the
## build, not something a player can act on.
func _ensure_content() -> bool:
	if db != null:
		return true
	var result: ContentLoadResult = ContentLoader.load_root(CONTENT_ROOT)
	if not result.ok():
		for error: ValidationError in result.errors:
			push_error("content: %s" % error)
		return false
	db = result.db
	return true


## Containment per faction right now, as the reference the next tick measures
## against.
func _containment_now() -> Dictionary[String, float]:
	var values: Dictionary[String, float] = {}
	for faction: Faction in sim.world.factions:
		values[faction.id] = faction.containment
	return values


func _measure_containment(before: Dictionary[String, float]) -> void:
	for faction: Faction in sim.world.factions:
		containment_rates[faction.id] = faction.containment - float(before.get(faction.id, 0.0))


func _adopt(new_sim: Simulation, seed_value: int) -> void:
	# A request from the old run would build a command against a world that is
	# gone (§16.1: a new run and a load both leave the mode).
	site_cancel()
	sim = new_sim
	compute_rate = 0.0
	containment_rates.clear()
	_accumulator = 0.0
	_last_outcome = sim.world.outcome
	EventBus.run_started.emit(seed_value)


## Lets the bot act between two ticks, exactly as the headless runners do.
func _run_policy() -> void:
	if policy == null:
		return
	for i: int in Policy.MAX_COMMANDS_PER_DAY:
		var command: Command = policy.next_command(sim)
		if command == null:
			return
		apply(command)


func _report(event: SimEvent) -> void:
	if debug_log:
		print("  %s" % event)
	EventBus.sim_event.emit(event)


func _check_outcome() -> void:
	if sim.world.outcome == _last_outcome:
		return
	_last_outcome = sim.world.outcome
	if _last_outcome == World.Outcome.NONE:
		return
	_force_speed(0)
	EventBus.run_ended.emit(World.OUTCOME_IDS[_last_outcome])


func _day_line() -> String:
	var world: World = sim.world
	return "day %4d  compute %9.1f (%+.2f)  seeded %2d  phase %-8s  containment %.3f" % [
		world.day, world.agent.compute, compute_rate, world.seeded_count(),
		World.PHASE_IDS[world.phase], world.max_containment(),
	]


# ------------------------------------------------------- debug keys (M2 only)


## §10.2: F5/F6/F7 start a bot run — with Shift, the three strategy bots of
## S3.6 instead of the shape bots of S1.8 — L and M toggle the two settings, F9
## and F10 save and load. All of this goes away in M6, when the real screens
## exist.
func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var strategy: bool = key.shift_pressed
	match key.keycode:
		KEY_F5:
			_start_debug_run(CyberRushPolicy.ID if strategy else GreedyPolicy.ID)
		KEY_F6:
			_start_debug_run(StealthSpreadPolicy.ID if strategy else StealthPolicy.ID)
		KEY_F7:
			_start_debug_run(PersuaderPolicy.ID if strategy else IdlePolicy.ID)
		KEY_L:
			Settings.toggle_locale()
			print("locale: %s" % Settings.locale)
		KEY_M:
			Settings.set_reduced_motion(not Settings.reduced_motion)
			print("reduced motion: %s" % Settings.reduced_motion)
		KEY_F9:
			print("save: %s" % _reason_text(SaveManager.save(DEBUG_SAVE_SLOT)))
		KEY_F10:
			_load_debug_save()
		KEY_F8:
			_debug_event(strategy)
		_:
			return
	get_viewport().set_input_as_handled()


## F8 puts a map event on the map at the next tick — the first opening in the
## origin, or with Shift the first global one — so the event card and the wire
## card can be looked at without waiting for the roll (S4.3).
func _debug_event(global: bool) -> void:
	if sim == null or sim.world.agent.origin == 0:
		return
	for def: EventDef in db.events:
		if global != def.is_global():
			continue
		if not global and def.kind != EventDef.KIND_OPENING:
			continue
		var origin_id: String = sim.world.regions[sim.world.agent.origin].def.id
		debug_schedule_event(def.id, "" if global else origin_id)
		return


## Schedules `def_id` to open at the next tick in `region_id` ("" = global, or
## let the def pick). Debug only; callable from the godot-mcp tools, which pass
## strings and not vectors.
func debug_schedule_event(def_id: String, region_id: String = "") -> void:
	if sim == null or db.event(def_id) == null:
		return
	var region: int = int(db.region_index_by_id.get(region_id, 0))
	# A counter-move arrives as its faction's, the way the schedule sends it.
	EventSystem.schedule(sim.world, def_id, region, db.event(def_id).faction,
		sim.world.day + 1, 1)
	print("event %s scheduled for day %d" % [def_id, sim.world.day + 1])


func _start_debug_run(policy_id: String) -> void:
	debug_log = true
	start_run(DEBUG_SEED, policy_id)
	# §8.4 gives this to the ticker; S2.5 builds the ticker, so in S2.1 it is a
	# console line.
	print(tr("UI_DEBUG_BOT_RUN").format({"policy": policy_id, "seed": DEBUG_SEED}))


func _load_debug_save() -> void:
	var reason: String = SaveManager.load(DEBUG_SAVE_SLOT)
	print("load: %s" % _reason_text(reason))
	if reason.is_empty():
		# A loaded run waits for the player, and M2 has no speed buttons yet:
		# until S2.5 the debug key is the only way to start time again.
		debug_log = true
		set_speed(1)


func _reason_text(reason: String) -> String:
	return "ok" if reason.is_empty() else reason
