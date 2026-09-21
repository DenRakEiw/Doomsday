class_name ModifierDef
extends RefCounted
## One `{target, op, value, scope?}` entry (`data/SCHEMA.md` §4.1–§4.3).
##
## This class owns the modifier vocabulary: targets, operators, scope kinds and
## flags are named here once. Extending the vocabulary means a row in SCHEMA.md,
## an entry here, a base in `balance.stats`, a clamp in `ModifierStack` and the
## one place in a system that reads the target — never a new `if` in a system.

enum Op { ADD, MUL }
enum ScopeKind { NONE, ATTR, REGION, CONTINENT }

## Indexed by `Op`, so the name and the enum value convert both ways.
const OP_NAMES: Array[String] = ["add", "mul"]

## Evaluated for one region; these accept a scope.
const TARGETS_REGIONAL: Array[String] = ["spread_growth", "spread_seed", "seed_land", "seed_sea",
	"seed_air", "seed_network", "airgap_cross", "control_growth", "yield", "anomaly_value",
	"anomaly_rate", "harm"]
## Evaluated once for the whole world; a scope on one of these is an error.
const TARGETS_GLOBAL: Array[String] = ["footprint", "discovery", "containment_growth", "node_cost"]
## Both lists together, written out because GDScript constants cannot be built
## from other constants. The key set of `balance.stats` is exactly this list.
const TARGETS_ALL: Array[String] = ["spread_growth", "spread_seed", "seed_land", "seed_sea",
	"seed_air", "seed_network", "airgap_cross", "control_growth", "yield", "anomaly_value",
	"anomaly_rate", "harm", "footprint", "discovery", "containment_growth", "node_cost"]

## Ends the Boxed phase: seeding across links becomes possible.
const FLAG_BREAKOUT: String = "breakout"
const FLAGS: Array[String] = ["breakout"]

var target: String
var op: Op
var value: float
var scope_kind: ScopeKind
var scope_attr: String
## 0 when the file gave no `min`, 4 when it gave no `max`.
var scope_min: int = RegionDef.TIER_MIN
var scope_max: int = RegionDef.TIER_MAX
var scope_region: int
var scope_continent: String


## Whether this modifier applies to `region`. An unscoped modifier applies
## everywhere; a null region — the global stats — matches nothing else.
func matches(region: RegionDef) -> bool:
	if scope_kind == ScopeKind.NONE:
		return true
	if region == null:
		return false
	match scope_kind:
		ScopeKind.ATTR:
			var tier: int = region.attr(scope_attr)
			return tier >= scope_min and tier <= scope_max
		ScopeKind.REGION:
			return region.index == scope_region
		ScopeKind.CONTINENT:
			return region.continent == scope_continent
	return false


## The seed target belonging to a link kind, so that `seed_land` and friends stay
## derived from `LinkDef.KINDS` instead of being retyped.
static func seed_target(kind: String) -> String:
	return "seed_%s" % kind


## The operator an authored name stands for. Unknown names are rejected at load,
## so anything that is not "mul" here can only be "add".
static func op_from_name(name: String) -> Op:
	if name == OP_NAMES[Op.MUL]:
		return Op.MUL
	return Op.ADD
