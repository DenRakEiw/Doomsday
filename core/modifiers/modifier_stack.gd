class_name ModifierStack
extends RefCounted
## Every active modifier, by source, and the stats they add up to.
##
## A technology node, a directive, an architecture, a difficulty tier and an
## emergent behaviour are all the same thing here: a source id with a list of
## modifiers and a list of flags. New content therefore never needs a new branch
## in a system.
##
## A stat is `clamp((base + Σ add) × Π mul)` over every active modifier for that
## target. The result does not depend on which source came first, apart from the
## summation order of the floats, which is fixed as the activation order.
##
## The stack is derived state: it is rebuilt from the owned nodes after loading
## and never serialised.

## Target → `[minimum, maximum]`, the table in `data/SCHEMA.md` §4.1.
##
## A pair of 64-bit floats, not the `Vector2` core.md §8 writes: `Vector2` holds
## 32-bit components, and the lower bound of `node_cost` would arrive as
## 0.10000000149 — a bound that is not the number it is written as.
const CLAMPS: Dictionary[String, Array] = {
	"spread_growth": [0.0, 20.0],
	"spread_seed": [0.0, 20.0],
	"seed_land": [0.0, 20.0],
	"seed_sea": [0.0, 20.0],
	"seed_air": [0.0, 20.0],
	"seed_network": [0.0, 20.0],
	"airgap_cross": [0.0, 1.0],
	"control_growth": [0.0, 20.0],
	"yield": [0.0, 20.0],
	"anomaly_value": [0.0, 20.0],
	"anomaly_rate": [0.0, 20.0],
	"harm": [0.0, 100.0],
	"footprint": [0.0, 100.0],
	"discovery": [0.0, 20.0],
	"containment_growth": [0.0, 20.0],
	"node_cost": [0.1, 10.0],
	"hardware": [0.0, 10.0],
	"shutdown_survival": [0.0, 1.0],
	"society_pressure": [0.0, 100.0],
	"containment_capacity": [0.0, 20.0],
	"penetration_decay": [0.0, 1.0],
	"control_decay": [0.0, 1.0],
	"node_cost_infiltration": [0.1, 10.0],
	"node_cost_capabilities": [0.1, 10.0],
	"node_cost_evasion": [0.1, 10.0],
	"emergent_rate": [0.0, 20.0],
	"containment_ai_labs": [0.0, 20.0],
	"containment_governments": [0.0, 20.0],
	"containment_researchers": [0.0, 20.0],
	"containment_public": [0.0, 20.0],
	# `taskforce-endings.md` §1.3: how fast the Task Force works; 0 stands it still.
	"task_force_pace": [0.0, 5.0],
}

## Targets that are loaded, validated and evaluated here, and read by no system
## yet (`docs/specs/tech-trees.md` §3.3). Each leaves this list in the step that
## makes its system live; the content is authored once, now.
const INERT_TARGETS: Array[String] = []
## The same for flags: `has_flag` answers truthfully, nobody asks yet.
const INERT_FLAGS: Array[String] = ["legal_standing", "merge_path"]

## What a faction sees of a source that nobody in particular watches (§5.1).
const UNWATCHED_WEIGHT: float = 0.25
const TARGET_FOOTPRINT: String = "footprint"

## The prefix of a technology source id.
const SOURCE_TECH: String = "tech"
## The prefix of an asset kind's base-effect source (§6.2).
const SOURCE_ASSET: String = "asset"
## The prefix of a timed flag's source: a source with no modifiers whose only
## job is to make `has_flag` answer yes while it stands (§8.2, `set_flag`).
const SOURCE_FLAG: String = "flag"
## The prefix of the run's architecture (`replayability.md` §1).
const SOURCE_ARCHITECTURE: String = "arch"
## The prefix of one directive of the run's loadout (§4).
const SOURCE_DIRECTIVE: String = "directive"
## The prefix of the run's difficulty tier (§5).
const SOURCE_DIFFICULTY: String = "difficulty"

var _bases: Dictionary[String, float] = {}
## Source id → its modifiers, in activation order.
var _sources: Dictionary[String, Array] = {}
## Source id → its flags, in activation order.
var _flags: Dictionary[String, PackedStringArray] = {}
## Source id → the factions that notice it (opposition.md §5.1). Empty means
## nobody in particular, which every faction sees a quarter of.
var _watched_by: Dictionary[String, PackedStringArray] = {}
## Activation order, which fixes the summation order and therefore the last bit
## of every float.
var _order: Array[String] = []
## Target → its modifiers in activation order, so that `value` never walks a
## modifier belonging to another target. Rebuilt whenever a source changes.
var _by_target: Dictionary[String, Array] = {}
## Region index → `{kind: count}`, mirroring `Region.assets`. It is state, not a
## source, so `clear()` leaves it alone: `Simulation.rebuild_modifiers` refills
## the sources and the counts stay what the world says they are (§6.3).
var _asset_counts: Dictionary[int, Dictionary] = {}


func _init(bases: Dictionary[String, float]) -> void:
	_bases = bases.duplicate()


## The source id a technology node is active under.
static func source_for_tech(node_id: String) -> String:
	return "%s:%s" % [SOURCE_TECH, node_id]


## The source id an asset kind's base effects are active under. The source is
## always active — an asset-scoped modifier matches nothing until a region holds
## one, so "active while the agent has at least one" needs no bookkeeping (§6.2).
static func source_for_asset(kind: String) -> String:
	return "%s:%s" % [SOURCE_ASSET, kind]


## The source id a timed flag is active under (§8.2).
static func source_for_flag(flag: String) -> String:
	return "%s:%s" % [SOURCE_FLAG, flag]


## The source id the run's difficulty tier is active under.
static func source_for_difficulty(difficulty_id: String) -> String:
	return "%s:%s" % [SOURCE_DIFFICULTY, difficulty_id]


## The source id a directive of the loadout is active under.
static func source_for_directive(directive_id: String) -> String:
	return "%s:%s" % [SOURCE_DIRECTIVE, directive_id]


## The source id the run's architecture is active under.
static func source_for_architecture(architecture_id: String) -> String:
	return "%s:%s" % [SOURCE_ARCHITECTURE, architecture_id]


## How many assets of a kind stand in a region, as the stack sees it.
func asset_count(region_index: int, kind: String) -> int:
	if not _asset_counts.has(region_index):
		return 0
	var counts: Dictionary = _asset_counts[region_index]
	return int(counts.get(kind, 0))


## The one writer. `World.set_assets` calls it; nothing else may, or the mirror
## and `Region.assets` drift apart.
func set_asset_count(region_index: int, kind: String, count: int) -> void:
	if not _asset_counts.has(region_index):
		var fresh: Dictionary[String, int] = {}
		_asset_counts[region_index] = fresh
	var counts: Dictionary = _asset_counts[region_index]
	if count <= 0:
		counts.erase(kind)
	else:
		counts[kind] = count


## Adds or replaces a source. Replacing keeps its place in the activation order.
## `watched_by` names the factions whose Footprint its Footprint modifiers feed
## (opposition.md §5.1); every caller that has such a list passes it.
func add_source(source_id: String, modifiers: Array[ModifierDef], flags: Array[String],
		watched_by: Array[String] = []) -> void:
	if not _sources.has(source_id):
		_order.append(source_id)
	_sources[source_id] = modifiers
	_flags[source_id] = PackedStringArray(flags)
	_watched_by[source_id] = PackedStringArray(watched_by)
	_reindex()


## Removing a source that is not active is not an error.
func remove_source(source_id: String) -> void:
	if not _sources.has(source_id):
		return
	_sources.erase(source_id)
	_flags.erase(source_id)
	_watched_by.erase(source_id)
	_order.erase(source_id)
	_reindex()


func has_source(source_id: String) -> bool:
	return _sources.has(source_id)


## Drops every source. The asset counts survive: they are the world's state, and
## the sources are what is rebuilt from the owned nodes (§6.3).
func clear() -> void:
	_sources.clear()
	_flags.clear()
	_watched_by.clear()
	_order.clear()
	_by_target.clear()


## The stat for `region`, or the global stat when `region` is null. A null region
## matches unscoped modifiers only — a scoped modifier never reaches a stat that
## belongs to no region.
##
## An unknown target is a programming error, not bad data: content is validated
## against the same vocabulary at load.
func value(target: String, region: RegionDef = null) -> float:
	if not CLAMPS.has(target):
		push_error("unknown modifier target \"%s\"" % target)
		return 0.0
	var total: float = float(_bases.get(target, 0.0))
	var factor: float = 1.0
	if _by_target.has(target):
		var modifiers: Array = _by_target[target]
		for modifier: ModifierDef in modifiers:
			if not _applies(modifier, region):
				continue
			if modifier.op == ModifierDef.Op.ADD:
				total += modifier.value
			else:
				factor *= modifier.value
	var bounds: Array = CLAMPS[target]
	return clampf(total * factor, float(bounds[0]), float(bounds[1]))


## The Footprint one faction sees (opposition.md §5.1): every additive
## Footprint modifier counts in full for a faction that watches its source, a
## quarter for every faction when nobody in particular does, and not at all
## otherwise; multipliers scale every faction alike. Unscoped modifiers only,
## like the global stat.
func footprint_for(faction_id: String) -> float:
	var total: float = float(_bases.get(TARGET_FOOTPRINT, 0.0))
	var factor: float = 1.0
	for source_id: String in _order:
		var watchers: PackedStringArray = _watched_by.get(source_id, PackedStringArray())
		var weight: float = 0.0
		if watchers.is_empty():
			weight = UNWATCHED_WEIGHT
		elif watchers.has(faction_id):
			weight = 1.0
		var modifiers: Array = _sources[source_id]
		for modifier: ModifierDef in modifiers:
			if modifier.target != TARGET_FOOTPRINT or not _applies(modifier, null):
				continue
			if modifier.op == ModifierDef.Op.ADD:
				total += modifier.value * weight
			else:
				factor *= modifier.value
	var bounds: Array = CLAMPS[TARGET_FOOTPRINT]
	return clampf(total * factor, float(bounds[0]), float(bounds[1]))


## The factions a source is watched by; empty for nobody in particular.
func watched_by(source_id: String) -> PackedStringArray:
	return _watched_by.get(source_id, PackedStringArray())


## Whether one modifier applies to `region`. Every scope but `ASSET` is the
## definition's own question; that one needs the counts this stack mirrors.
func _applies(modifier: ModifierDef, region: RegionDef) -> bool:
	if modifier.scope_kind != ModifierDef.ScopeKind.ASSET:
		return modifier.matches(region)
	if region == null:
		return false
	return asset_count(region.index, modifier.scope_asset) >= modifier.scope_min


## Sources in activation order, modifiers in the order their node declares them.
func _reindex() -> void:
	_by_target.clear()
	for source_id: String in _order:
		var modifiers: Array = _sources[source_id]
		for modifier: ModifierDef in modifiers:
			if not _by_target.has(modifier.target):
				var fresh: Array[ModifierDef] = []
				_by_target[modifier.target] = fresh
			var bucket: Array = _by_target[modifier.target]
			bucket.append(modifier)


func has_flag(flag: String) -> bool:
	for source_id: String in _order:
		if _flags[source_id].has(flag):
			return true
	return false


## Active source ids in activation order. For tests and the Analysis screen.
func sources() -> Array[String]:
	return _order.duplicate()
