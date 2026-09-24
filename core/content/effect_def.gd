class_name EffectDef
extends RefCounted
## One thing that happens once (`loop-mechanics.md` §8).
##
## The same class behind `on_purchase` on a node, `on_start` / `on_end` on a
## status level, `applies.effects` on an ability and `effects` on an event
## option: one vocabulary, one runner (`EffectRunner`), so a new piece of content
## never needs a new branch anywhere.
##
## Replaces `PurchaseEffectDef` of S3.1. A one-shot is never undone and never
## re-applied on load, because the save carries the state it produced.
##
## This class owns the effect vocabulary. Extending it means a row in SCHEMA.md,
## an entry here, and the branch in `EffectRunner` that carries it out — or, for
## an inert effect, no branch at all until its system lands.

## Every faction: `containment ← containment × (1 − value)`.
const CONTAINMENT_ROLLBACK: String = "containment_rollback"
## Burns that share of every faction's preparation. Inert until S4.4.
const FUNDING_RESET: String = "funding_reset"
## `compute` and `compute_earned` both rise by `value`.
const COMPUTE_GRANT: String = "compute_grant"
## One wave of deaths, at once, as a share of the infected living.
const HARM_BURST: String = "harm_burst"
## Seeds the best `count` uninfected neighbours over open links.
const SEED_NEIGHBOURS: String = "seed_neighbours"
const PENETRATION_MUL: String = "penetration_mul"
const CONTROL_ADD: String = "control_add"
## Takes assets away; `count` 0 means every one the region holds.
const DESTROY_ASSETS: String = "destroy_assets"
## The mirror of `destroy_assets`: an asset the world hands over (D4.3).
const GRANT_ASSETS: String = "grant_assets"
## The status effects, live from S4.2.
const SPREAD_STATUS: String = "spread_status"
const END_STATUSES: String = "end_statuses"
const APPLY_STATUS: String = "apply_status"
const WIPE: String = "wipe"
const CONTAINMENT_ADD: String = "containment_add"
const FOOTPRINT_PULSE: String = "footprint_pulse"
const SET_FLAG: String = "set_flag"
## `replayability.md` §2.3: a running status climbs or falls by `value` levels;
## below 1 it ends. What the Weapon's Restraint holds the escalation down with.
const STATUS_LEVEL_ADD: String = "status_level_add"
## §3.2's Goal Generalisation: the missing prerequisite of the cheapest node one
## short of available is owned, and that node with it becomes available.
const UNLOCK_NEAR_NODE: String = "unlock_near_node"

## The vocabulary, in the order §8.2 lists it.
const EFFECTS: Array[String] = ["compute_grant", "containment_rollback", "harm_burst",
	"funding_reset", "seed_neighbours", "penetration_mul", "control_add", "destroy_assets",
	"spread_status", "end_statuses", "containment_add", "footprint_pulse", "set_flag",
	"apply_status", "wipe", "grant_assets", "status_level_add", "unlock_near_node"]

## Accepted and validated, carried out by nothing until the named system lands.
## S4.4 emptied it (`funding_reset`); kept as the place a later step parks one.
const INERT_EFFECTS: Array[String] = []

## The effects that must run with a region (§8.2's `R` column). `compute_grant`
## joins them when `per_hardware` is set, which is why it is not in the list.
const NEEDS_REGION: Array[String] = ["seed_neighbours", "penetration_mul", "control_add",
	"destroy_assets", "spread_status", "end_statuses", "wipe", "grant_assets"]

## The effects the runner does not carry out yet. S4.2 emptied it: every effect
## is live. Kept as the one place a later step
## parks a newly authored effect until its system lands.
const PENDING_EFFECTS: Array[String] = []

## Effect id → the fields it must carry, beyond `effect` itself.
const REQUIRED_FIELDS: Dictionary[String, Array] = {
	"compute_grant": ["value"],
	"containment_rollback": ["value"],
	"harm_burst": ["value"],
	"funding_reset": ["value"],
	"seed_neighbours": ["count"],
	"penetration_mul": ["value"],
	"control_add": ["value"],
	"destroy_assets": ["kind", "count"],
	"spread_status": ["status"],
	"end_statuses": ["ids"],
	"containment_add": ["faction", "value"],
	"footprint_pulse": ["value", "days"],
	"set_flag": ["flag", "days"],
	"apply_status": ["status"],
	"wipe": ["value"],
	"grant_assets": ["kind", "count"],
	"status_level_add": ["status", "value"],
	"unlock_near_node": [],
}
## Effect id → the fields it may carry on top of the required ones.
const OPTIONAL_FIELDS: Dictionary[String, Array] = {
	"compute_grant": ["per_hardware"],
	"containment_rollback": [],
	"harm_burst": [],
	"funding_reset": [],
	"seed_neighbours": [],
	"penetration_mul": [],
	"control_add": [],
	"destroy_assets": [],
	"spread_status": ["level", "days"],
	"end_statuses": ["global"],
	"containment_add": [],
	"footprint_pulse": ["watched_by"],
	"set_flag": [],
	"apply_status": ["level", "days", "global"],
	"wipe": [],
	"grant_assets": [],
	"status_level_add": ["global"],
	"unlock_near_node": [],
}

## Effect id → `[minimum, maximum, minimum_is_exclusive]` for its `value`. A pair
## of 64-bit floats for the same reason `ModifierStack.CLAMPS` is one: a
## `Vector2` would round the bound.
const VALUE_RANGES: Dictionary[String, Array] = {
	"compute_grant": [0.0, INF, false],
	"containment_rollback": [0.0, 1.0, true],
	"harm_burst": [0.0, 1.0, true],
	"funding_reset": [0.0, 1.0, true],
	"penetration_mul": [0.0, INF, false],
	"control_add": [-INF, INF, false],
	"containment_add": [-INF, INF, false],
	"footprint_pulse": [-INF, INF, false],
	"wipe": [0.0, 1.0, false],
	"status_level_add": [-INF, INF, false],
}
## Effect id → `[minimum, maximum]` for its `count`.
const COUNT_RANGES: Dictionary[String, Array] = {
	"seed_neighbours": [1, 999],
	"destroy_assets": [0, 999],
	"grant_assets": [1, 999],
}
## Effect id → `[minimum, maximum]` for its `days`.
const DAYS_RANGES: Dictionary[String, Array] = {
	"spread_status": [0, 99999],
	"footprint_pulse": [1, 99999],
	"set_flag": [0, 99999],
	"apply_status": [0, 99999],
}

## `"all"` in a `containment_add`: every faction at once.
const FACTION_ALL: String = "all"

var effect: String
var value: float = 0.0
var count: int = 0
var kind: String = ""
var status: String = ""
var level: int = 1
var days: int = 0
var ids: Array[String] = []
var faction: String = ""
var flag: String = ""
var watched_by: Array[String] = []
var per_hardware: bool = false
## (D4.4) `apply_status` / `end_statuses`: run as if the region were 0.
var global: bool = false


## Reads a validated entry.
static func from_dict(d: Dictionary) -> EffectDef:
	var def: EffectDef = EffectDef.new()
	def.effect = str(d["effect"])
	def.value = float(d.get("value", 0.0))
	def.count = int(d.get("count", 0))
	def.kind = str(d.get("kind", ""))
	def.status = str(d.get("status", ""))
	def.level = int(d.get("level", 1))
	def.days = int(d.get("days", 0))
	def.faction = str(d.get("faction", ""))
	def.flag = str(d.get("flag", ""))
	def.per_hardware = bool(d.get("per_hardware", false))
	def.global = bool(d.get("global", false))
	if d.has("ids"):
		var listed: Array = d["ids"]
		for entry: Variant in listed:
			def.ids.append(str(entry))
	if d.has("watched_by"):
		var watchers: Array = d["watched_by"]
		for entry: Variant in watchers:
			def.watched_by.append(str(entry))
	return def


## Accepted and validated, carried out by nobody yet.
func is_inert() -> bool:
	return INERT_EFFECTS.has(effect)


## Whether this effect needs a region to run in.
func needs_region() -> bool:
	return effect_needs_region(effect, per_hardware, global)


## Whether an id needs a region, read without an instance — for the validator,
## which has the raw dictionary and not the definition.
## `global` (D4.4) runs a status effect on the agent, which needs no region —
## `end_statuses` on a global card, like Mesa-Optimiser's suppression (S5.2).
static func effect_needs_region(id: String, per_hardware_set: bool,
		global_set: bool = false) -> bool:
	if id == COMPUTE_GRANT:
		return per_hardware_set
	if global_set and OPTIONAL_FIELDS[id].has("global"):
		return false
	return NEEDS_REGION.has(id)
