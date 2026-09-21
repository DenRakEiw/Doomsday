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
}

## The prefix of a technology source id.
const SOURCE_TECH: String = "tech"

var _bases: Dictionary[String, float] = {}
## Source id → its modifiers, in activation order.
var _sources: Dictionary[String, Array] = {}
## Source id → its flags, in activation order.
var _flags: Dictionary[String, PackedStringArray] = {}
## Activation order, which fixes the summation order and therefore the last bit
## of every float.
var _order: Array[String] = []
## Target → its modifiers in activation order, so that `value` never walks a
## modifier belonging to another target. Rebuilt whenever a source changes.
var _by_target: Dictionary[String, Array] = {}


func _init(bases: Dictionary[String, float]) -> void:
	_bases = bases.duplicate()


## The source id a technology node is active under.
static func source_for_tech(node_id: String) -> String:
	return "%s:%s" % [SOURCE_TECH, node_id]


## Adds or replaces a source. Replacing keeps its place in the activation order.
func add_source(source_id: String, modifiers: Array[ModifierDef], flags: Array[String]) -> void:
	if not _sources.has(source_id):
		_order.append(source_id)
	_sources[source_id] = modifiers
	_flags[source_id] = PackedStringArray(flags)
	_reindex()


## Removing a source that is not active is not an error.
func remove_source(source_id: String) -> void:
	if not _sources.has(source_id):
		return
	_sources.erase(source_id)
	_flags.erase(source_id)
	_order.erase(source_id)
	_reindex()


func has_source(source_id: String) -> bool:
	return _sources.has(source_id)


func clear() -> void:
	_sources.clear()
	_flags.clear()
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
			if not modifier.matches(region):
				continue
			if modifier.op == ModifierDef.Op.ADD:
				total += modifier.value
			else:
				factor *= modifier.value
	var bounds: Array = CLAMPS[target]
	return clampf(total * factor, float(bounds[0]), float(bounds[1]))


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
