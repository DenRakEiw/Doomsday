class_name ScreenFxRules
extends RefCounted
## The pure rules of the full-screen pass (spec polish-visuals.md §3.6, §3.7,
## §4.1): how hot the run is, what the pass draws at a setting, and how hard a
## simulation event tears the frame.
##
## Static and side-effect free; `ScreenFx` asks, the tests ask the same.

## §3.7: each heat-scaled effect is `floor + (1 − floor) × heat` of its full
## strength — present in Boxed, full at the end.
const SCAN_HEAT_FLOOR: float = 0.5
const GRAIN_HEAT_FLOOR: float = 0.25
const BLOOM_HEAT_FLOOR: float = 0.5
## §3.7: the bloom's taps at Full and at anything between Off and Full.
const BLOOM_TAPS_FULL: int = 16
const BLOOM_TAPS_SUBTLE: int = 8

## §4.1's table: how hard each event tears the frame.
const IMPULSE_FULL: float = 1.0
const IMPULSE_WIN: float = 0.5
const IMPULSE_TASK_FORCE: float = 0.6
const IMPULSE_WIPE: float = 0.5
const IMPULSE_COUNTER_MOVE: float = 0.4

## The event payload keys the table reads.
const DATA_TO: String = "to"
const DATA_OUTCOME: String = "outcome"
const DATA_DEF: String = "def"
const DATA_KIND: String = "kind"


## How near the run is to either end: the world nearly taken, or them nearly
## closing in. 0…1.
static func endgame(world: World, db: ContentDB) -> float:
	var live: int = maxi(1, world.regions.size() - 1 - world.dark_count())
	var control: float = float(world.controlled_count(db)) / float(live)
	return clampf(maxf(world.max_containment(), control), 0.0, 1.0)


## §3.6: the phase sets the heat; in Open the endgame carries it the rest of
## the way to 1.
static func heat(phase: World.Phase, endgame_share: float) -> float:
	var base: float = UiTokens.FX_HEAT_PHASE.get(phase, 0.0)
	if phase != World.Phase.OPEN:
		return base
	return base + (1.0 - base) * smoothstep(UiTokens.FX_HEAT_ENDGAME.x,
		UiTokens.FX_HEAT_ENDGAME.y, endgame_share)


## §3.7: what the pass draws at an intensity (the setting, 0…1) and a heat.
## Reduced motion takes out what moves or shimmers and keeps what is static.
static func params(intensity: float, heat_value: float, reduced_motion: bool) -> ScreenFxParams:
	var level: float = clampf(intensity, 0.0, 1.0)
	var hot: float = clampf(heat_value, 0.0, 1.0)
	var result: ScreenFxParams = ScreenFxParams.new()
	result.enabled = level > 0.0
	result.vignette = UiTokens.FX_VIGNETTE * level
	result.bloom_strength = UiTokens.FX_BLOOM_STRENGTH * level * _scaled(BLOOM_HEAT_FLOOR, hot)
	if level >= 1.0:
		result.bloom_taps = BLOOM_TAPS_FULL
	elif level > 0.0:
		result.bloom_taps = BLOOM_TAPS_SUBTLE
	result.dither_levels = lerpf(UiTokens.FX_DITHER_LEVELS.x, UiTokens.FX_DITHER_LEVELS.y,
		hot * level)
	if not reduced_motion:
		result.scan_depth = UiTokens.FX_SCANLINE_DEPTH * level * _scaled(SCAN_HEAT_FLOOR, hot)
		result.grain_amp = UiTokens.FX_GRAIN_AMP * level * _scaled(GRAIN_HEAT_FLOOR, hot)
		result.ca_scale = level
	return result


## §4.1: the aberration an event starts, 0 for none.
static func impulse_for(event: SimEvent, db: ContentDB) -> float:
	match event.type:
		SimEvent.DISCOVERED:
			return IMPULSE_FULL
		SimEvent.PHASE_CHANGED:
			var to: String = str(event.data.get(DATA_TO, ""))
			return IMPULSE_FULL if to == World.PHASE_IDS[World.Phase.OPEN] else 0.0
		SimEvent.OUTCOME_REACHED:
			return _outcome_impulse(str(event.data.get(DATA_OUTCOME, "")))
		SimEvent.TASK_FORCE_ACTED:
			return IMPULSE_TASK_FORCE
		SimEvent.REGION_WIPED:
			return IMPULSE_WIPE
		SimEvent.EVENT_OPENED:
			return IMPULSE_COUNTER_MOVE if _event_kind(event, db) == EventDef.KIND_COUNTER_MOVE \
				else 0.0
	return 0.0


static func _scaled(floor_share: float, hot: float) -> float:
	return floor_share + (1.0 - floor_share) * hot


static func _outcome_impulse(outcome_id: String) -> float:
	var index: int = World.OUTCOME_IDS.find(outcome_id)
	if index <= World.Outcome.NONE:
		return 0.0
	return IMPULSE_WIN if World.WIN_OUTCOMES.has(index as World.Outcome) else IMPULSE_FULL


## The definition's kind when the content knows it; the event's own copy of it
## otherwise.
static func _event_kind(event: SimEvent, db: ContentDB) -> String:
	var def_id: String = str(event.data.get(DATA_DEF, ""))
	if db != null and db.event_by_id.has(def_id):
		return db.event_by_id[def_id].kind
	return str(event.data.get(DATA_KIND, ""))
