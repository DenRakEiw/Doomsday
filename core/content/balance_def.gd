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
var containment_per_footprint: float
var containment_per_harm: float
var containment_per_share: float
## Weight per `research` tier; the index is the tier.
var containment_research_weight_by_tier: Array[float] = []
## Ascending, each in (0, 1); announced once when crossed.
var containment_thresholds: Array[float] = []

var phase_open_containment: float
var phase_open_world_share: float

var history_interval_days: int
