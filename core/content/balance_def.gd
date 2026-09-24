class_name BalanceDef
extends RefCounted
## Every tunable constant of the simulation (`data/SCHEMA.md` §5), one typed
## field per key, named `<section>_<key>`.
##
## Systems read their numbers from here and contain no literals other than 0, 1
## and the clamp bounds of the modifier vocabulary. What each constant means is
## the formula that uses it, in `docs/specs/core.md` §7.

## Base value per modifier target; the key set is exactly `ModifierDef.TARGETS_ALL`.
var stats: Dictionary[String, float] = {}
## Four ascending population thresholds; a region's derived `population` tier is
## how many of them it reaches.
var population_tiers: Array[int] = []

var spread_base_growth: float
var spread_origin_penetration: float
var spread_seed_penetration: float
var spread_saturation_snap: float
## One chance per link kind; the key set is exactly `LinkDef.KINDS`.
var spread_seed_chance: Dictionary[String, float] = {}

var control_threshold: float
var control_rate: float
var control_complete: float

var compute_start: float
var compute_yield_scale: float
var compute_cost_step: float
## Hardware weight per `compute` tier; the index is the tier.
var compute_hardware_by_tier: Array[float] = []

var anomaly_spawn_chance: float
var anomaly_max_active: int
var anomaly_lifetime_days: int
var anomaly_base_value: float
var anomaly_tier_bonus: float
var anomaly_footprint_bonus: float
var anomaly_footprint_reference: float

var milestones: Array[MilestoneDef] = []

var harm_daily_rate: float

var discovery_scrutiny_per_day: float
var discovery_per_footprint: float
var discovery_breadth_rate: float
var discovery_breadth_free: float
var discovery_deaths_certain_share: float

var containment_base_rate: float
## G4: whatever an agent builds, a faction's brakes stay at least this (BALANCE §4) —
## without a floor a quiet build braked every hunt to ×0.09 and could not lose.
var containment_brake_floor: float
## Weight per tier of a faction's capacity attribute; the index is the tier
## (opposition.md §5.2 — one table for all four attributes).
var containment_capacity_weight_by_tier: Array[float] = []
## Ascending, each in (0, 1); announced once when crossed.
var containment_thresholds: Array[float] = []

## The counter-move schedule (opposition.md §6, §11). `factions_reset_days` is
## read from S4.4 on (`funding_reset`), the rest from S4.5.
var factions_prepare_days: int
var factions_prepare_min_days: int
var factions_cooldown_days: int
var factions_max_active_moves: int
var factions_level_thresholds: Array[float] = []
var factions_reset_days: int
var factions_protest_deaths_share: float

## Societal Function (opposition.md §8): the stage thresholds on the 0…100
## disorder, how pressure and deaths feed it, how fast it recovers, the two cuts
## per stage (`{"capacity_mul", "yield_mul"}`, one more than the thresholds), and
## how many days of zero income end a run.
var society_stage_thresholds: Array[float] = []
var society_gain_scale: float
var society_recovery_per_day: float
var society_deaths_weight: float
var society_stages: Array[Dictionary] = []
var society_autophagy_days: int

var phase_open_containment: float
var phase_open_world_share: float

## ticker.md §3.8: how many headlines a tick and a command may say, how far
## apart two state-triggered reactions are, and the pace of the filler.
var headlines_max_per_tick: int
var headlines_max_per_command: int
var headlines_reaction_gap_days: int
## Days between two filler lines, per phase id; the key set is `World.PHASE_IDS`.
var headlines_filler_gap_days: Dictionary[String, float] = {}
var headlines_filler_per_dark_region: float
var headlines_filler_silence_dark: int
var headlines_filler_silence_deaths_share: float

## `replayability.md` §3.1: the daily chance of an emergent card at rate 1, and
## what suppressing one costs — `suppress_cost × (1 + suppress_step × so far)`.
var emergent_base_chance: float = 0.0
var emergent_suppress_cost: float = 0.0
var emergent_suppress_step: float = 0.0
## §2.2 `drift`: how drift moves, and when a copy defects.
var drift_per_kept: float = 0.0
var drift_per_day: float = 0.0
var drift_per_suppressed: float = 0.0
var drift_defect_chance: float = 0.0
var drift_defect_min_penetration: float = 0.0
var drift_defect_days: int = 1
## §2.2 `escalation`: a level every so many days; Restraint holds it this long.
var escalation_every_days: int = 1
var escalation_hold_days: int = 1
## §2.2 `distributed`: the floor a wipe cannot go under while the agent holds at
## least `hold_regions` regions, and the start's penetration in its six regions.
var distributed_floor: float = 0.0
var distributed_start_penetration: float = 0.0
var distributed_hold_regions: int = 1
## `taskforce-endings.md` §8: when the team forms, how its funding steps, and how
## long its work takes.
var task_force_appear_at: float = 0.5
var task_force_appear_at_led: float = 0.4
var task_force_level_thresholds: Array[float] = []
var task_force_led_level_bonus: int = 1
var task_force_hop_days: int = 6
var task_force_hop_days_min: int = 3
var task_force_setup_days: int = 5
var task_force_ally_warning_days: int = 3
var task_force_rest_days: int = 8
var task_force_distance_penalty: float = 0.25
## §5 Existential: every node costs `× (1 + this × controlled share)`.
var difficulty_cost_by_control: float = 0.0

## m3-screens §7.4: Ascendance over this share of the world dead reads as ashes.
var results_ashes_share: float = 0.5
var history_interval_days: int
## analysis.md §3.1, §4.3: the most samples kept before thinning, the most log
## entries kept.
var history_max_samples: int
var history_log_max: int

## loop-mechanics §18: the daily opening roll per phase id (the key set is
## `World.PHASE_IDS`), how many seeded regions it takes before openings roll at
## all, and how many map events may stand at once.
var events_opening_chance: Dictionary[String, float] = {}
var events_opening_from_regions: int = 2
var events_max_open: int = 3
