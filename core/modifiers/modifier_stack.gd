class_name ModifierStack
extends RefCounted
## Every active modifier, by source, and the stats they add up to.
##
## A technology node, a directive, an architecture, a difficulty tier and an
## emergent behaviour are all the same thing here: a source id with a list of
## modifiers and a list of flags. New content therefore never needs a new branch
## in a system.
##
## **S1.2 ships this as a shell:** sources and flags work, `value` still returns
## the base. S1.4 completes it with `(base + Σ add) × Π mul` (core.md §8).
##
## The stack is derived state: it is rebuilt from the owned nodes after loading
## and never serialised.

## Target → (minimum, maximum), the table in `data/SCHEMA.md` §4.1.
const CLAMPS: Dictionary[String, Vector2] = {
	"spread_growth": Vector2(0.0, 20.0),
	"spread_seed": Vector2(0.0, 20.0),
	"seed_land": Vector2(0.0, 20.0),
	"seed_sea": Vector2(0.0, 20.0),
	"seed_air": Vector2(0.0, 20.0),
	"seed_network": Vector2(0.0, 20.0),
	"airgap_cross": Vector2(0.0, 1.0),
	"control_growth": Vector2(0.0, 20.0),
	"yield": Vector2(0.0, 20.0),
	"anomaly_value": Vector2(0.0, 20.0),
	"anomaly_rate": Vector2(0.0, 20.0),
	"harm": Vector2(0.0, 100.0),
	"footprint": Vector2(0.0, 100.0),
	"discovery": Vector2(0.0, 20.0),
	"containment_growth": Vector2(0.0, 20.0),
	"node_cost": Vector2(0.1, 10.0),
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


## Removing a source that is not active is not an error.
func remove_source(source_id: String) -> void:
	if not _sources.has(source_id):
		return
	_sources.erase(source_id)
	_flags.erase(source_id)
	_order.erase(source_id)


func has_source(source_id: String) -> bool:
	return _sources.has(source_id)


func clear() -> void:
	_sources.clear()
	_flags.clear()
	_order.clear()


## The stat for `region`, or the global stat when `region` is null.
##
## S1.2: the clamped base. The modifiers are already held; only the arithmetic of
## §8 is missing, and S1.4 adds it here alone.
@warning_ignore("unused_parameter")  # `region` is used from S1.4 on.
func value(target: String, region: RegionDef = null) -> float:
	if not CLAMPS.has(target):
		push_error("unknown modifier target \"%s\"" % target)
		return 0.0
	var clamp_range: Vector2 = CLAMPS[target]
	return clampf(float(_bases.get(target, 0.0)), clamp_range.x, clamp_range.y)


func has_flag(flag: String) -> bool:
	for source_id: String in _order:
		if _flags[source_id].has(flag):
			return true
	return false


## Active source ids in activation order. For tests and the Analysis screen.
func sources() -> Array[String]:
	return _order.duplicate()
