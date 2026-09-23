class_name Eligibility
extends RefCounted
## Where something may be placed, used or picked (`loop-mechanics.md` §5).
##
## One grammar for deploy sites, ability targets, event picks and, from S4.5, the
## targets of a counter-move. A rule answers one question about one region:
## `check` returns "" when the region passes and the **first** failing key's
## reason code otherwise, in the order of `KEYS` — so the caption a player reads
## says the most basic thing first (*not infected* before *no lab there*).
##
## Every reason code is also a localisation key twice over: `UI_ELIGIBLE_<CODE>`
## is the reason, `UI_ELIGIBLE_NEEDS_<CODE>` the requirement (§17.2).

const KEYS: Array[String] = ["infected", "not_dark", "not_dormant", "attr_min", "attr_max",
	"asset_min", "asset_max", "status_absent", "status_present", "penetration_min",
	"control_min", "continent", "not_origin", "origin"]

const REASON_NOT_INFECTED: String = "not_infected"
const REASON_DARK: String = "dark"
const REASON_DORMANT: String = "dormant"
const REASON_ATTR_MIN: String = "attr_min"
const REASON_ATTR_MAX: String = "attr_max"
const REASON_ASSET_MIN: String = "asset_min"
const REASON_ASSET_MAX: String = "asset_max"
const REASON_STATUS_ABSENT: String = "status_absent"
const REASON_STATUS_PRESENT: String = "status_present"
const REASON_PENETRATION: String = "penetration_min"
const REASON_CONTROL: String = "control_min"
const REASON_CONTINENT: String = "continent"
const REASON_ORIGIN: String = "not_origin"
## (D4.4) The origin only.
const REASON_ORIGIN_ONLY: String = "origin"

## Every reason, in the order `check` can produce them. For the string tables and
## for a test that walks the whole grammar.
const REASONS: Array[String] = ["not_infected", "dark", "dormant", "attr_min", "attr_max",
	"asset_min", "asset_max", "status_absent", "status_present", "penetration_min",
	"control_min", "continent", "not_origin", "origin"]

## The keys that carry a tier or a count table, so the loader and the validator
## walk the same four.
const TABLE_KEYS: Array[String] = ["attr_min", "attr_max", "asset_min", "asset_max"]
## The keys that carry a list of status ids.
const LIST_KEYS: Array[String] = ["status_absent", "status_present"]
## The keys that carry a share in [0, 1].
const SHARE_KEYS: Array[String] = ["penetration_min", "control_min"]
## The keys that carry a bare flag.
const FLAG_KEYS: Array[String] = ["infected", "not_dark", "not_dormant", "not_origin", "origin"]

var infected: bool = false
var not_dark: bool = false
var not_dormant: bool = false
var attr_min: Dictionary[String, int] = {}
var attr_max: Dictionary[String, int] = {}
var asset_min: Dictionary[String, int] = {}
var asset_max: Dictionary[String, int] = {}
var status_absent: Array[String] = []
var status_present: Array[String] = []
## Above 0 only when the key was given.
var penetration_min: float = 0.0
var control_min: float = 0.0
var continent: String = ""
var not_origin: bool = false
## (D4.4) The origin and nothing else.
var origin: bool = false


## Reads a validated rule. Every key is optional; an absent key never fails.
static func from_dict(d: Dictionary) -> Eligibility:
	var rule: Eligibility = Eligibility.new()
	rule.infected = bool(d.get("infected", false))
	rule.not_dark = bool(d.get("not_dark", false))
	rule.not_dormant = bool(d.get("not_dormant", false))
	_read_tiers(rule.attr_min, d, "attr_min")
	_read_tiers(rule.attr_max, d, "attr_max")
	_read_tiers(rule.asset_min, d, "asset_min")
	_read_tiers(rule.asset_max, d, "asset_max")
	_read_ids(rule.status_absent, d, "status_absent")
	_read_ids(rule.status_present, d, "status_present")
	rule.penetration_min = float(d.get("penetration_min", 0.0))
	rule.control_min = float(d.get("control_min", 0.0))
	rule.continent = str(d.get("continent", ""))
	rule.not_origin = bool(d.get("not_origin", false))
	rule.origin = bool(d.get("origin", false))
	return rule


## The rule that accepts every region the world still has — `not_dark` applies
## whether it was asked for or not.
static func none() -> Eligibility:
	return Eligibility.new()


## Empty when the region passes, else the first failing key's reason code.
func check(world: World, region_index: int) -> String:
	if region_index <= 0 or region_index >= world.regions.size():
		return REASON_DARK
	var region: Region = world.regions[region_index]
	if infected and region.penetration <= 0.0:
		return REASON_NOT_INFECTED
	# Always applied: nothing targets a region that is not there any more.
	if region.dark:
		return REASON_DARK
	if not_dormant and region.dormant:
		return REASON_DORMANT
	for attribute: String in attr_min:
		if region.def.attr(attribute) < attr_min[attribute]:
			return REASON_ATTR_MIN
	for attribute: String in attr_max:
		if region.def.attr(attribute) > attr_max[attribute]:
			return REASON_ATTR_MAX
	for kind: String in asset_min:
		if region.asset_count(kind) < asset_min[kind]:
			return REASON_ASSET_MIN
	for kind: String in asset_max:
		if region.asset_count(kind) > asset_max[kind]:
			return REASON_ASSET_MAX
	for status: String in status_absent:
		if world.has_status(status, region_index):
			return REASON_STATUS_ABSENT
	for status: String in status_present:
		if not world.has_status(status, region_index):
			return REASON_STATUS_PRESENT
	if region.penetration < penetration_min:
		return REASON_PENETRATION
	if region.control < control_min:
		return REASON_CONTROL
	if not continent.is_empty() and region.def.continent != continent:
		return REASON_CONTINENT
	if not_origin and region_index == world.agent.origin:
		return REASON_ORIGIN
	if origin and region_index != world.agent.origin:
		return REASON_ORIGIN_ONLY
	return ""


## The arguments the failing reason's string takes, or an empty dictionary when
## the region passes or the reason needs none.
func detail(world: World, region_index: int) -> Dictionary:
	var reason: String = check(world, region_index)
	if reason.is_empty() or region_index <= 0 or region_index >= world.regions.size():
		return {}
	var region: Region = world.regions[region_index]
	match reason:
		REASON_ATTR_MIN:
			for attribute: String in attr_min:
				if region.def.attr(attribute) < attr_min[attribute]:
					return {"attr": attribute, "tier": attr_min[attribute]}
		REASON_ATTR_MAX:
			for attribute: String in attr_max:
				if region.def.attr(attribute) > attr_max[attribute]:
					return {"attr": attribute, "tier": attr_max[attribute]}
		REASON_ASSET_MIN:
			for kind: String in asset_min:
				if region.asset_count(kind) < asset_min[kind]:
					return {"kind": kind, "count": asset_min[kind]}
		REASON_ASSET_MAX:
			for kind: String in asset_max:
				if region.asset_count(kind) > asset_max[kind]:
					return {"kind": kind, "count": asset_max[kind]}
		REASON_STATUS_ABSENT:
			for status: String in status_absent:
				if world.has_status(status, region_index):
					return {"status": status}
		REASON_STATUS_PRESENT:
			for status: String in status_present:
				if not world.has_status(status, region_index):
					return {"status": status}
		REASON_PENETRATION:
			return {"value": penetration_min}
		REASON_CONTROL:
			return {"value": control_min}
		REASON_CONTINENT:
			return {"continent": continent}
	return {}


## The requirement rows a detail pane shows, in `KEYS` order: one
## `[code, arguments]` pair per key the rule actually carries (§16.6).
func requirements() -> Array[Array]:
	var rows: Array[Array] = []
	if infected:
		rows.append([REASON_NOT_INFECTED, {}])
	if not_dormant:
		rows.append([REASON_DORMANT, {}])
	for attribute: String in attr_min:
		rows.append([REASON_ATTR_MIN, {"attr": attribute, "tier": attr_min[attribute]}])
	for attribute: String in attr_max:
		rows.append([REASON_ATTR_MAX, {"attr": attribute, "tier": attr_max[attribute]}])
	for kind: String in asset_min:
		rows.append([REASON_ASSET_MIN, {"kind": kind, "count": asset_min[kind]}])
	for kind: String in asset_max:
		rows.append([REASON_ASSET_MAX, {"kind": kind, "count": asset_max[kind]}])
	for status: String in status_absent:
		rows.append([REASON_STATUS_ABSENT, {"status": status}])
	for status: String in status_present:
		rows.append([REASON_STATUS_PRESENT, {"status": status}])
	if penetration_min > 0.0:
		rows.append([REASON_PENETRATION, {"value": penetration_min}])
	if control_min > 0.0:
		rows.append([REASON_CONTROL, {"value": control_min}])
	if not continent.is_empty():
		rows.append([REASON_CONTINENT, {"continent": continent}])
	if not_origin:
		rows.append([REASON_ORIGIN, {}])
	if origin:
		rows.append([REASON_ORIGIN_ONLY, {}])
	return rows


static func _read_tiers(into: Dictionary[String, int], d: Dictionary, key: String) -> void:
	if not d.has(key):
		return
	var entries: Dictionary = d[key]
	for name: String in entries:
		into[name] = int(entries[name])


static func _read_ids(into: Array[String], d: Dictionary, key: String) -> void:
	if not d.has(key):
		return
	var entries: Array = d[key]
	for entry: Variant in entries:
		into.append(str(entry))
