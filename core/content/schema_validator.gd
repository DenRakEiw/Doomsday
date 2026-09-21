class_name SchemaValidator
extends RefCounted
## Checks parsed content against `data/SCHEMA.md` and collects every problem.
##
## Nothing here stops at the first mistake and nothing here crashes: the input is
## untrusted data, so every value is type-checked before it is read, and a file
## with ten mistakes produces ten errors. A structural error in one entry only
## costs that entry its cross-reference checks.
##
## Where this file and `data/SCHEMA.md` disagree, one of the two is a bug.
##
## The split into functions is this file's own business; the contract is
## `docs/specs/core.md` §4.2.

## Ids are lower snake case.
const ID_PATTERN: String = "^[a-z][a-z0-9_]*$"
## Returned by the integer readers for a value that could not be read. No legal
## integer field is negative, so it can never collide with real data.
const INVALID_INT: int = -1
## `population_tiers` has one entry per tier above 0.
const POPULATION_TIER_COUNT: int = 4
## `hardware_by_tier` and `research_weight_by_tier` are indexed by tier 0…4.
const TIER_TABLE_SIZE: int = 5
## The largest whole number a JSON double still represents exactly; the bound for
## an integer field that has no smaller one of its own.
const INTEGER_MAX: int = 9007199254740992

const BALANCE_KEYS: Array[String] = ["stats", "population_tiers", "spread", "control", "compute",
	"anomaly", "milestones", "harm", "discovery", "containment", "phase", "history"]
const REGION_KEYS: Array[String] = ["index", "id", "continent", "population", "air_gapped",
	"anchor", "attributes"]
const LINK_KEYS: Array[String] = ["a", "b", "kind"]
const TECH_NODE_KEYS: Array[String] = ["id", "tree", "tier", "cost", "requires", "requires_any",
	"modifiers", "flags"]
const MODIFIER_KEYS: Array[String] = ["target", "op", "value", "scope"]
const MILESTONE_KEYS: Array[String] = ["id", "kind", "threshold", "reward"]

## Compiled once; `RegEx.create_from_string` on a literal pattern cannot fail.
static var _id_regex: RegEx = RegEx.create_from_string(ID_PATTERN)


# ---------------------------------------------------------------- balance.json


## Appends every problem in `balance.json` to `errors`. A `raw` that is not an
## object was already reported by the loader and is skipped here.
static func validate_balance(file: String, raw: Variant, errors: Array[ValidationError]) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var d: Dictionary = raw
	_check_keys(d, BALANCE_KEYS, file, "", errors)

	if _require(d, "stats", file, "", errors):
		_balance_stats(d["stats"], file, errors)
	if _require(d, "population_tiers", file, "", errors):
		_balance_population_tiers(d["population_tiers"], file, errors)
	if _require(d, "spread", file, "", errors):
		_balance_spread(d["spread"], file, errors)
	if _require(d, "control", file, "", errors):
		_balance_control(d["control"], file, errors)
	if _require(d, "compute", file, "", errors):
		_balance_compute(d["compute"], file, errors)
	if _require(d, "anomaly", file, "", errors):
		_balance_anomaly(d["anomaly"], file, errors)
	if _require(d, "milestones", file, "", errors):
		_balance_milestones(d["milestones"], file, errors)
	if _require(d, "harm", file, "", errors):
		_balance_harm(d["harm"], file, errors)
	if _require(d, "discovery", file, "", errors):
		_balance_discovery(d["discovery"], file, errors)
	if _require(d, "containment", file, "", errors):
		_balance_containment(d["containment"], file, errors)
	if _require(d, "phase", file, "", errors):
		_balance_phase(d["phase"], file, errors)
	if _require(d, "history", file, "", errors):
		_balance_history(d["history"], file, errors)


static func _balance_stats(raw: Variant, file: String, errors: Array[ValidationError]) -> void:
	var path: String = "stats"
	if not _is_object(raw, file, path, errors):
		return
	var d: Dictionary = raw
	# Together, the unknown-field and missing-field errors are the rule that the
	# key set equals the target list exactly.
	_check_keys(d, ModifierDef.TARGETS_ALL, file, path, errors)
	for target: String in ModifierDef.TARGETS_ALL:
		_number(d, target, file, path, errors)


static func _balance_population_tiers(raw: Variant, file: String,
		errors: Array[ValidationError]) -> void:
	var path: String = "population_tiers"
	var values: Array[int] = _integer_list(raw, file, path, errors, POPULATION_TIER_COUNT)
	var has_previous: bool = false
	var previous: int = 0
	for i: int in values.size():
		if values[i] == INVALID_INT:
			has_previous = false
			continue
		if has_previous and values[i] <= previous:
			_add(errors, file, "%s[%d]" % [path, i], "thresholds must ascend strictly")
		previous = values[i]
		has_previous = true


static func _balance_spread(raw: Variant, file: String, errors: Array[ValidationError]) -> void:
	var path: String = "spread"
	if not _is_object(raw, file, path, errors):
		return
	var d: Dictionary = raw
	_check_keys(d, ["base_growth", "origin_penetration", "seed_penetration", "saturation_snap",
		"seed_chance"], file, path, errors)
	_number(d, "base_growth", file, path, errors)
	_number(d, "origin_penetration", file, path, errors, 0.0, 1.0, true)
	_number(d, "seed_penetration", file, path, errors, 0.0, 1.0, true)
	_number(d, "saturation_snap", file, path, errors, 0.0, 1.0, true)
	if _require(d, "seed_chance", file, path, errors):
		_balance_seed_chance(d["seed_chance"], file, errors)


static func _balance_seed_chance(raw: Variant, file: String,
		errors: Array[ValidationError]) -> void:
	var path: String = "spread.seed_chance"
	if not _is_object(raw, file, path, errors):
		return
	var d: Dictionary = raw
	_check_keys(d, LinkDef.KINDS, file, path, errors)
	for kind: String in LinkDef.KINDS:
		_number(d, kind, file, path, errors, 0.0, 1.0)


static func _balance_control(raw: Variant, file: String, errors: Array[ValidationError]) -> void:
	var path: String = "control"
	if not _is_object(raw, file, path, errors):
		return
	var d: Dictionary = raw
	_check_keys(d, ["threshold", "rate", "complete"], file, path, errors)
	_number(d, "threshold", file, path, errors, 0.0, 1.0, false, true)
	_number(d, "rate", file, path, errors)
	_number(d, "complete", file, path, errors, 0.0, 1.0, true)


static func _balance_compute(raw: Variant, file: String, errors: Array[ValidationError]) -> void:
	var path: String = "compute"
	if not _is_object(raw, file, path, errors):
		return
	var d: Dictionary = raw
	_check_keys(d, ["start", "yield_scale", "cost_step", "hardware_by_tier"], file, path, errors)
	_number(d, "start", file, path, errors)
	_number(d, "yield_scale", file, path, errors)
	_number(d, "cost_step", file, path, errors)
	if _require(d, "hardware_by_tier", file, path, errors):
		_float_list(d["hardware_by_tier"], file, "compute.hardware_by_tier", errors,
			TIER_TABLE_SIZE)


static func _balance_anomaly(raw: Variant, file: String, errors: Array[ValidationError]) -> void:
	var path: String = "anomaly"
	if not _is_object(raw, file, path, errors):
		return
	var d: Dictionary = raw
	_check_keys(d, ["spawn_chance", "max_active", "lifetime_days", "base_value", "tier_bonus",
		"footprint_bonus", "footprint_reference"], file, path, errors)
	_number(d, "spawn_chance", file, path, errors, 0.0, 1.0)
	_integer(d, "max_active", file, path, errors, 1)
	_integer(d, "lifetime_days", file, path, errors, 1)
	_number(d, "base_value", file, path, errors)
	_number(d, "tier_bonus", file, path, errors)
	_number(d, "footprint_bonus", file, path, errors)
	_number(d, "footprint_reference", file, path, errors, 0.0, INF, true)


static func _balance_milestones(raw: Variant, file: String,
		errors: Array[ValidationError]) -> void:
	var path: String = "milestones"
	if not _is_list(raw, file, path, errors):
		return
	var list: Array = raw
	var seen: Dictionary[String, int] = {}
	for i: int in list.size():
		var entry_path: String = "%s[%d]" % [path, i]
		if not _is_object(list[i], file, entry_path, errors):
			continue
		var m: Dictionary = list[i]
		_check_keys(m, MILESTONE_KEYS, file, entry_path, errors)
		var id: String = _id(m, "id", file, entry_path, errors)
		if not id.is_empty():
			if seen.has(id):
				_add(errors, file, _join(entry_path, "id"),
					"duplicate id \"%s\", first used by %s[%d]" % [id, path, seen[id]])
			else:
				seen[id] = i
		var kind: String = _text(m, "kind", file, entry_path, errors)
		if not kind.is_empty() and not MilestoneDef.KINDS.has(kind):
			_add(errors, file, _join(entry_path, "kind"), "unknown milestone kind \"%s\"" % kind)
		if kind == MilestoneDef.KIND_REGIONS_INFECTED:
			_integer(m, "threshold", file, entry_path, errors, 1)
		elif kind == MilestoneDef.KIND_WORLD_SHARE:
			_number(m, "threshold", file, entry_path, errors, 0.0, 1.0, true)
		else:
			_number(m, "threshold", file, entry_path, errors)
		_number(m, "reward", file, entry_path, errors)


static func _balance_harm(raw: Variant, file: String, errors: Array[ValidationError]) -> void:
	var path: String = "harm"
	if not _is_object(raw, file, path, errors):
		return
	var d: Dictionary = raw
	_check_keys(d, ["daily_rate"], file, path, errors)
	_number(d, "daily_rate", file, path, errors)


static func _balance_discovery(raw: Variant, file: String, errors: Array[ValidationError]) -> void:
	var path: String = "discovery"
	if not _is_object(raw, file, path, errors):
		return
	var d: Dictionary = raw
	_check_keys(d, ["scrutiny_per_day", "per_footprint", "breadth_rate", "breadth_free",
		"deaths_certain_share"], file, path, errors)
	_number(d, "scrutiny_per_day", file, path, errors)
	_number(d, "per_footprint", file, path, errors)
	_number(d, "breadth_rate", file, path, errors)
	_number(d, "breadth_free", file, path, errors, 0.0, 1.0)
	_number(d, "deaths_certain_share", file, path, errors, 0.0, 1.0)


static func _balance_containment(raw: Variant, file: String,
		errors: Array[ValidationError]) -> void:
	var path: String = "containment"
	if not _is_object(raw, file, path, errors):
		return
	var d: Dictionary = raw
	_check_keys(d, ["base_rate", "per_footprint", "per_harm", "per_share",
		"research_weight_by_tier", "thresholds"], file, path, errors)
	_number(d, "base_rate", file, path, errors)
	_number(d, "per_footprint", file, path, errors)
	_number(d, "per_harm", file, path, errors)
	_number(d, "per_share", file, path, errors)

	if _require(d, "research_weight_by_tier", file, path, errors):
		var weight_path: String = "containment.research_weight_by_tier"
		var weights: Array[float] = _float_list(d["research_weight_by_tier"], file, weight_path,
			errors, TIER_TABLE_SIZE)
		var sum: float = 0.0
		for weight: float in weights:
			if not is_nan(weight):
				sum += weight
		if not weights.is_empty() and sum <= 0.0:
			_add(errors, file, weight_path, "the weights must sum to more than 0")

	if _require(d, "thresholds", file, path, errors):
		var threshold_path: String = "containment.thresholds"
		var thresholds: Array[float] = _float_list(d["thresholds"], file, threshold_path, errors,
			-1, 0.0, 1.0, true, true)
		var has_previous: bool = false
		var previous: float = 0.0
		for i: int in thresholds.size():
			if is_nan(thresholds[i]):
				has_previous = false
				continue
			if has_previous and thresholds[i] <= previous:
				_add(errors, file, "%s[%d]" % [threshold_path, i],
					"thresholds must ascend strictly")
			previous = thresholds[i]
			has_previous = true


static func _balance_phase(raw: Variant, file: String, errors: Array[ValidationError]) -> void:
	var path: String = "phase"
	if not _is_object(raw, file, path, errors):
		return
	var d: Dictionary = raw
	_check_keys(d, ["open_containment", "open_world_share"], file, path, errors)
	_number(d, "open_containment", file, path, errors, 0.0, 1.0, true)
	_number(d, "open_world_share", file, path, errors, 0.0, 1.0, true)


static func _balance_history(raw: Variant, file: String, errors: Array[ValidationError]) -> void:
	var path: String = "history"
	if not _is_object(raw, file, path, errors):
		return
	var d: Dictionary = raw
	_check_keys(d, ["interval_days"], file, path, errors)
	_integer(d, "interval_days", file, path, errors, 1)


# ---------------------------------------------------------- world/regions.json


## Appends every problem in `regions.json` to `errors` and returns the regions
## that came through intact, as id → continent. Links and modifier scopes are
## checked against that map, so a region with a broken id costs only itself its
## cross-reference checks.
static func validate_regions(file: String, raw: Variant,
		errors: Array[ValidationError]) -> Dictionary[String, String]:
	var valid: Dictionary[String, String] = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return valid
	var d: Dictionary = raw
	_check_keys(d, ["regions"], file, "", errors)
	if not _require(d, "regions", file, "", errors):
		return valid
	if not _is_list(d["regions"], file, "regions", errors):
		return valid
	var list: Array = d["regions"]
	if list.is_empty():
		_add(errors, file, "regions", "at least one region is required")
		return valid

	var seen_ids: Dictionary[String, int] = {}
	var seen_indices: Dictionary[int, int] = {}
	for i: int in list.size():
		var path: String = "regions[%d]" % i
		if not _is_object(list[i], file, path, errors):
			continue
		var r: Dictionary = list[i]
		_check_keys(r, REGION_KEYS, file, path, errors)

		var index: int = _integer(r, "index", file, path, errors, RegionDef.INDEX_MIN,
			RegionDef.INDEX_MAX)
		if index != INVALID_INT:
			if seen_indices.has(index):
				_add(errors, file, _join(path, "index"),
					"duplicate index %d, first used by regions[%d]" % [index, seen_indices[index]])
			else:
				seen_indices[index] = i

		var id: String = _id(r, "id", file, path, errors)
		var duplicate_id: bool = false
		if not id.is_empty():
			if seen_ids.has(id):
				duplicate_id = true
				_add(errors, file, _join(path, "id"),
					"duplicate id \"%s\", first used by regions[%d]" % [id, seen_ids[id]])
			else:
				seen_ids[id] = i

		var continent: String = _id(r, "continent", file, path, errors)
		_integer(r, "population", file, path, errors, 1)
		_bool(r, "air_gapped", file, path, errors)
		_region_anchor(r, file, path, errors)
		_region_attributes(r, file, path, errors)

		if not id.is_empty() and not duplicate_id and not continent.is_empty():
			valid[id] = continent

	# The indices must be exactly 1…N. Checked only when every entry produced
	# one, because otherwise the report is about the broken entries, not a gap.
	if seen_indices.size() == list.size():
		for expected: int in range(1, list.size() + 1):
			if not seen_indices.has(expected):
				_add(errors, file, "regions",
					"index %d is missing; the indices must be exactly 1…%d" % [expected,
					list.size()])
	return valid


static func _region_anchor(r: Dictionary, file: String, path: String,
		errors: Array[ValidationError]) -> void:
	var anchor_path: String = _join(path, "anchor")
	if not _require(r, "anchor", file, path, errors):
		return
	if not _is_list(r["anchor"], file, anchor_path, errors):
		return
	var list: Array = r["anchor"]
	if list.size() != 2:
		_add(errors, file, anchor_path, "expected 2 entries, found %d" % list.size())
		return
	_check_integer(list[0], file, "%s[0]" % anchor_path, errors, 0)
	_check_integer(list[1], file, "%s[1]" % anchor_path, errors, 0)


static func _region_attributes(r: Dictionary, file: String, path: String,
		errors: Array[ValidationError]) -> void:
	var attributes_path: String = _join(path, "attributes")
	if not _require(r, "attributes", file, path, errors):
		return
	if not _is_object(r["attributes"], file, attributes_path, errors):
		return
	var d: Dictionary = r["attributes"]
	# `population` is derived at load and must not be authored; it is simply not
	# in the allowed set, so writing it is an unknown field like any other.
	_check_keys(d, RegionDef.ATTRIBUTES, file, attributes_path, errors)
	for attribute: String in RegionDef.ATTRIBUTES:
		_integer(d, attribute, file, attributes_path, errors, RegionDef.TIER_MIN,
			RegionDef.TIER_MAX)


# ------------------------------------------------------------ world/links.json


## Appends every problem in `links.json` to `errors`. Endpoints are checked
## against `regions` only when `regions_known` — a `regions.json` that did not
## parse would otherwise make every link look dangling.
static func validate_links(file: String, raw: Variant, regions: Dictionary[String, String],
		regions_known: bool, errors: Array[ValidationError]) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var d: Dictionary = raw
	_check_keys(d, ["links"], file, "", errors)
	if not _require(d, "links", file, "", errors):
		return
	if not _is_list(d["links"], file, "links", errors):
		return
	var list: Array = d["links"]

	var seen: Dictionary[String, int] = {}
	for i: int in list.size():
		var path: String = "links[%d]" % i
		if not _is_object(list[i], file, path, errors):
			continue
		var link: Dictionary = list[i]
		_check_keys(link, LINK_KEYS, file, path, errors)

		var a: String = _id(link, "a", file, path, errors)
		var b: String = _id(link, "b", file, path, errors)
		var kind: String = _text(link, "kind", file, path, errors)
		if not kind.is_empty() and not LinkDef.KINDS.has(kind):
			_add(errors, file, _join(path, "kind"), "unknown link kind \"%s\"" % kind)
			kind = ""

		if a.is_empty() or b.is_empty():
			continue
		if a >= b:
			_add(errors, file, path,
				"\"a\" must sort strictly before \"b\" (\"%s\", \"%s\")" % [a, b])
			continue
		if regions_known:
			if not regions.has(a):
				_add(errors, file, _join(path, "a"), "unknown region \"%s\"" % a)
			if not regions.has(b):
				_add(errors, file, _join(path, "b"), "unknown region \"%s\"" % b)
		if kind.is_empty():
			continue

		var link_id: String = LinkDef.derive_id(a, b, kind)
		if seen.has(link_id):
			_add(errors, file, path,
				"duplicate link \"%s\", first used by links[%d]" % [link_id, seen[link_id]])
		else:
			seen[link_id] = i


# ----------------------------------------------------------------- tech/*.json


## Appends every problem in the technology files to `errors`. Ids are unique
## across all of them, so the files are validated together.
static func validate_tech(files: PackedStringArray, raws: Array,
		regions: Dictionary[String, String], regions_known: bool,
		errors: Array[ValidationError]) -> void:
	var continents: Dictionary[String, bool] = {}
	for continent: String in regions.values():
		continents[continent] = true

	# Pass 1: structure, and the id of every node that came through intact.
	var node_file: Dictionary[String, String] = {}
	var node_path: Dictionary[String, String] = {}
	var order: PackedStringArray = []
	for f: int in files.size():
		var file: String = files[f]
		var nodes: Array = _tech_nodes(file, raws[f], errors)
		for i: int in nodes.size():
			var path: String = "nodes[%d]" % i
			if not _is_object(nodes[i], file, path, errors):
				continue
			var node: Dictionary = nodes[i]
			_check_keys(node, TECH_NODE_KEYS, file, path, errors)
			var id: String = _id(node, "id", file, path, errors)
			_tech_node_fields(node, file, path, regions, regions_known, continents, errors)
			if id.is_empty():
				continue
			if node_file.has(id):
				_add(errors, file, _join(path, "id"),
					"duplicate id \"%s\", first used by %s %s" % [id, node_file[id], node_path[id]])
				continue
			node_file[id] = file
			node_path[id] = path
			order.append(id)

	# Pass 2: prerequisites, now that every id is known.
	var prerequisites: Dictionary[String, PackedStringArray] = {}
	for f: int in files.size():
		var file: String = files[f]
		var nodes: Array = _tech_nodes(file, raws[f], errors, false)
		for i: int in nodes.size():
			if typeof(nodes[i]) != TYPE_DICTIONARY:
				continue
			var node: Dictionary = nodes[i]
			var path: String = "nodes[%d]" % i
			if not node.has("id") or typeof(node["id"]) != TYPE_STRING:
				continue
			var id: String = node["id"]
			if not node_file.has(id) or node_path[id] != path or node_file[id] != file:
				continue
			var deps: PackedStringArray = []
			for key: String in ["requires", "requires_any"]:
				var listed: PackedStringArray = _id_list(node, key, file, path, errors)
				for k: int in listed.size():
					var dep: String = listed[k]
					if dep.is_empty():
						continue
					if dep == id:
						_add(errors, file, "%s.%s[%d]" % [path, key, k],
							"a node cannot be its own prerequisite")
						continue
					if not node_file.has(dep):
						_add(errors, file, "%s.%s[%d]" % [path, key, k],
							"unknown node \"%s\"" % dep)
						continue
					deps.append(dep)
			prerequisites[id] = deps

	_tech_cycles(order, prerequisites, node_file, node_path, errors)


## The `nodes` array of one technology file. Reports its problems only on the
## first pass, so that the second pass does not report them twice.
static func _tech_nodes(file: String, raw: Variant, errors: Array[ValidationError],
		report: bool = true) -> Array:
	if typeof(raw) != TYPE_DICTIONARY:
		return []
	var d: Dictionary = raw
	if report:
		_check_keys(d, ["nodes"], file, "", errors)
		if not _require(d, "nodes", file, "", errors):
			return []
		if not _is_list(d["nodes"], file, "nodes", errors):
			return []
	elif not d.has("nodes") or typeof(d["nodes"]) != TYPE_ARRAY:
		return []
	var nodes: Array = d["nodes"]
	return nodes


static func _tech_node_fields(node: Dictionary, file: String, path: String,
		regions: Dictionary[String, String], regions_known: bool,
		continents: Dictionary[String, bool], errors: Array[ValidationError]) -> void:
	var tree: String = _text(node, "tree", file, path, errors)
	if not tree.is_empty() and not TechNodeDef.TREES.has(tree):
		_add(errors, file, _join(path, "tree"), "unknown tree \"%s\"" % tree)
	_integer(node, "tier", file, path, errors, TechNodeDef.TIER_MIN, TechNodeDef.TIER_MAX)
	_integer(node, "cost", file, path, errors, 1)

	if node.has("flags"):
		var flags_path: String = _join(path, "flags")
		if _is_list(node["flags"], file, flags_path, errors):
			var flags: Array = node["flags"]
			for i: int in flags.size():
				var flag_path: String = "%s[%d]" % [flags_path, i]
				if typeof(flags[i]) != TYPE_STRING:
					_add(errors, file, flag_path, "expected a string, found %s"
						% type_string(typeof(flags[i])))
				elif not ModifierDef.FLAGS.has(flags[i]):
					_add(errors, file, flag_path, "unknown flag \"%s\"" % flags[i])

	if node.has("modifiers"):
		var modifiers_path: String = _join(path, "modifiers")
		if _is_list(node["modifiers"], file, modifiers_path, errors):
			var modifiers: Array = node["modifiers"]
			for i: int in modifiers.size():
				_modifier(modifiers[i], file, "%s[%d]" % [modifiers_path, i], regions,
					regions_known, continents, errors)


static func _modifier(raw: Variant, file: String, path: String,
		regions: Dictionary[String, String], regions_known: bool,
		continents: Dictionary[String, bool], errors: Array[ValidationError]) -> void:
	if not _is_object(raw, file, path, errors):
		return
	var m: Dictionary = raw
	_check_keys(m, MODIFIER_KEYS, file, path, errors)

	var target: String = _text(m, "target", file, path, errors)
	var is_global: bool = ModifierDef.TARGETS_GLOBAL.has(target)
	var is_regional: bool = ModifierDef.TARGETS_REGIONAL.has(target)
	if not target.is_empty() and not is_global and not is_regional:
		_add(errors, file, _join(path, "target"), "unknown target \"%s\"" % target)

	var op: String = _text(m, "op", file, path, errors)
	if not op.is_empty() and not ModifierDef.OP_NAMES.has(op):
		_add(errors, file, _join(path, "op"), "unknown operator \"%s\"" % op)

	var value: float = _number(m, "value", file, path, errors, -INF)
	if op == ModifierDef.OP_NAMES[ModifierDef.Op.MUL] and not is_nan(value) and value <= 0.0:
		_add(errors, file, _join(path, "value"), "a \"mul\" value must be greater than 0")

	if not m.has("scope"):
		return
	var scope_path: String = _join(path, "scope")
	if is_global:
		_add(errors, file, scope_path, "a global target takes no scope")
		return
	if not _is_object(m["scope"], file, scope_path, errors):
		return
	_scope(m["scope"], file, scope_path, regions, regions_known, continents, errors)


static func _scope(raw: Variant, file: String, path: String,
		regions: Dictionary[String, String], regions_known: bool,
		continents: Dictionary[String, bool], errors: Array[ValidationError]) -> void:
	var s: Dictionary = raw
	var forms: int = 0
	for form: String in ["attr", "region", "continent"]:
		if s.has(form):
			forms += 1
	if forms != 1:
		_add(errors, file, path, "a scope is exactly one of \"attr\", \"region\" and \"continent\"")

	if s.has("attr"):
		_check_keys(s, ["attr", "min", "max"], file, path, errors)
		var attribute: String = _text(s, "attr", file, path, errors)
		if not attribute.is_empty() and not RegionDef.ATTRIBUTES_ALL.has(attribute):
			_add(errors, file, _join(path, "attr"), "unknown attribute \"%s\"" % attribute)
		if not s.has("min") and not s.has("max"):
			_add(errors, file, path, "an attribute scope needs \"min\", \"max\" or both")
		var low: int = RegionDef.TIER_MIN
		var high: int = RegionDef.TIER_MAX
		if s.has("min"):
			low = _integer(s, "min", file, path, errors, RegionDef.TIER_MIN, RegionDef.TIER_MAX)
		if s.has("max"):
			high = _integer(s, "max", file, path, errors, RegionDef.TIER_MIN, RegionDef.TIER_MAX)
		if low != INVALID_INT and high != INVALID_INT and low > high:
			_add(errors, file, path, "\"min\" (%d) is greater than \"max\" (%d)" % [low, high])
	elif s.has("region"):
		_check_keys(s, ["region"], file, path, errors)
		var region: String = _id(s, "region", file, path, errors)
		if regions_known and not region.is_empty() and not regions.has(region):
			_add(errors, file, _join(path, "region"), "unknown region \"%s\"" % region)
	elif s.has("continent"):
		_check_keys(s, ["continent"], file, path, errors)
		var continent: String = _id(s, "continent", file, path, errors)
		if regions_known and not continent.is_empty() and not continents.has(continent):
			_add(errors, file, _join(path, "continent"), "unknown continent \"%s\"" % continent)
	else:
		_check_keys(s, [], file, path, errors)


## Depth-first search over `requires` ∪ `requires_any`, iterative so that a deep
## tree cannot overflow the stack. Each cycle is reported once, at whichever of
## its nodes comes first in file order.
static func _tech_cycles(order: PackedStringArray,
		prerequisites: Dictionary[String, PackedStringArray],
		node_file: Dictionary[String, String], node_path: Dictionary[String, String],
		errors: Array[ValidationError]) -> void:
	const WHITE: int = 0
	const GREY: int = 1
	const BLACK: int = 2
	var colour: Dictionary[String, int] = {}
	var rank: Dictionary[String, int] = {}
	for i: int in order.size():
		rank[order[i]] = i
		colour[order[i]] = WHITE
	var reported: Dictionary[String, bool] = {}

	for start: String in order:
		if colour[start] != WHITE:
			continue
		colour[start] = GREY
		var stack: PackedStringArray = [start]
		var cursors: Array[int] = [0]
		while not stack.is_empty():
			var node: String = stack[stack.size() - 1]
			var deps: PackedStringArray = prerequisites[node]
			var cursor: int = cursors[cursors.size() - 1]
			if cursor >= deps.size():
				colour[node] = BLACK
				stack.remove_at(stack.size() - 1)
				cursors.remove_at(cursors.size() - 1)
				continue
			cursors[cursors.size() - 1] = cursor + 1
			var dep: String = deps[cursor]
			if colour[dep] == BLACK:
				continue
			if colour[dep] == WHITE:
				colour[dep] = GREY
				stack.append(dep)
				cursors.append(0)
				continue
			# Grey: `dep` is on the stack, so everything from it to the top is a
			# cycle. Its ids identify the cycle whichever node we entered from.
			var cycle: PackedStringArray = []
			var from: int = stack.find(dep)
			for i: int in range(from, stack.size()):
				cycle.append(stack[i])
			var key: PackedStringArray = cycle.duplicate()
			key.sort()
			var signature: String = "|".join(key)
			if reported.has(signature):
				continue
			reported[signature] = true
			var first: String = cycle[0]
			for id: String in cycle:
				if rank[id] < rank[first]:
					first = id
			var trail: PackedStringArray = cycle.duplicate()
			trail.append(cycle[0])
			_add(errors, node_file[first], node_path[first],
				"prerequisite cycle: %s" % " -> ".join(trail))


# --------------------------------------------------------------------- helpers


static func _add(errors: Array[ValidationError], file: String, path: String,
		message: String) -> void:
	errors.append(ValidationError.new(file, path, message))


static func _join(path: String, key: String) -> String:
	if path.is_empty():
		return key
	return "%s.%s" % [path, key]


## True when `key` is there; otherwise reports it as missing.
static func _require(d: Dictionary, key: String, file: String, path: String,
		errors: Array[ValidationError]) -> bool:
	if d.has(key):
		return true
	_add(errors, file, _join(path, key), "missing required field")
	return false


static func _is_object(raw: Variant, file: String, path: String,
		errors: Array[ValidationError]) -> bool:
	if typeof(raw) == TYPE_DICTIONARY:
		return true
	_add(errors, file, path, "expected an object, found %s" % type_string(typeof(raw)))
	return false


static func _is_list(raw: Variant, file: String, path: String,
		errors: Array[ValidationError]) -> bool:
	if typeof(raw) == TYPE_ARRAY:
		return true
	_add(errors, file, path, "expected an array, found %s" % type_string(typeof(raw)))
	return false


## Every field the content must not contain. Keys starting with `_` are comments
## and are ignored everywhere.
static func _check_keys(d: Dictionary, allowed: Array[String], file: String, path: String,
		errors: Array[ValidationError]) -> void:
	for raw_key: Variant in d.keys():
		if typeof(raw_key) != TYPE_STRING:
			_add(errors, file, path, "object keys must be strings")
			continue
		var key: String = raw_key
		if key.begins_with("_"):
			continue
		if not allowed.has(key):
			_add(errors, file, _join(path, key), "unknown field")


static func _is_valid_id(value: String) -> bool:
	return _id_regex.search(value) != null


## A required number. Returns NAN for anything it had to report, so that a caller
## comparing values skips what it could not read.
static func _number(d: Dictionary, key: String, file: String, path: String,
		errors: Array[ValidationError], low: float = 0.0, high: float = INF,
		low_open: bool = false, high_open: bool = false) -> float:
	var field_path: String = _join(path, key)
	if not d.has(key):
		_add(errors, file, field_path, "missing required field")
		return NAN
	return _check_number(d[key], file, field_path, errors, low, high, low_open, high_open)


static func _check_number(raw: Variant, file: String, path: String, errors: Array[ValidationError],
		low: float = 0.0, high: float = INF, low_open: bool = false,
		high_open: bool = false) -> float:
	var type: int = typeof(raw)
	if type != TYPE_FLOAT and type != TYPE_INT:
		_add(errors, file, path, "expected a number, found %s" % type_string(type))
		return NAN
	var value: float = float(raw)
	if not is_finite(value):
		_add(errors, file, path, "expected a finite number")
		return NAN
	var too_low: bool = value < low or (low_open and value == low)
	var too_high: bool = value > high or (high_open and value == high)
	if too_low or too_high:
		_add(errors, file, path, "%s is outside %s" % [value, _range_text(low, high, low_open,
			high_open)])
		return NAN
	return value


## A required whole number. Godot's JSON parser makes every number a float — the
## "JSON has no integers" trap — so a fractional value is caught here and not by
## a type check. Returns `INVALID_INT` for anything it had to report.
static func _integer(d: Dictionary, key: String, file: String, path: String,
		errors: Array[ValidationError], low: int = 0, high: int = INTEGER_MAX) -> int:
	var field_path: String = _join(path, key)
	if not d.has(key):
		_add(errors, file, field_path, "missing required field")
		return INVALID_INT
	return _check_integer(d[key], file, field_path, errors, low, high)


static func _check_integer(raw: Variant, file: String, path: String,
		errors: Array[ValidationError], low: int = 0, high: int = INTEGER_MAX) -> int:
	var value: float = _check_number(raw, file, path, errors, -INF)
	if is_nan(value):
		return INVALID_INT
	if value != floor(value):
		_add(errors, file, path, "expected a whole number, found %s" % value)
		return INVALID_INT
	if value < float(low) or value > float(high):
		var bound: String = "inf" if high == INTEGER_MAX else str(high)
		_add(errors, file, path, "%d is outside [%d, %s]" % [int(value), low, bound])
		return INVALID_INT
	return int(value)


## A required string. Returns "" for anything it had to report.
static func _text(d: Dictionary, key: String, file: String, path: String,
		errors: Array[ValidationError]) -> String:
	var field_path: String = _join(path, key)
	if not d.has(key):
		_add(errors, file, field_path, "missing required field")
		return ""
	if typeof(d[key]) != TYPE_STRING:
		_add(errors, file, field_path, "expected a string, found %s" % type_string(typeof(d[key])))
		return ""
	return str(d[key])


## A required id. Returns "" for anything it had to report.
static func _id(d: Dictionary, key: String, file: String, path: String,
		errors: Array[ValidationError]) -> String:
	var value: String = _text(d, key, file, path, errors)
	if value.is_empty():
		return ""
	if not _is_valid_id(value):
		_add(errors, file, _join(path, key),
			"\"%s\" is not a valid id (%s)" % [value, ID_PATTERN])
		return ""
	return value


static func _bool(d: Dictionary, key: String, file: String, path: String,
		errors: Array[ValidationError]) -> bool:
	if not d.has(key):
		return false
	if typeof(d[key]) != TYPE_BOOL:
		_add(errors, file, _join(path, key),
			"expected true or false, found %s" % type_string(typeof(d[key])))
		return false
	return bool(d[key])


## An optional list of ids. The result has one entry per source entry, `""` where
## the entry was reported, so that a caller can still name `<key>[i]` in an error.
static func _id_list(d: Dictionary, key: String, file: String, path: String,
		errors: Array[ValidationError]) -> PackedStringArray:
	var out: PackedStringArray = []
	if not d.has(key):
		return out
	var list_path: String = _join(path, key)
	if not _is_list(d[key], file, list_path, errors):
		return out
	var list: Array = d[key]
	for i: int in list.size():
		var entry_path: String = "%s[%d]" % [list_path, i]
		if typeof(list[i]) != TYPE_STRING:
			_add(errors, file, entry_path,
				"expected a string, found %s" % type_string(typeof(list[i])))
			out.append("")
			continue
		var value: String = list[i]
		if not _is_valid_id(value):
			_add(errors, file, entry_path, "\"%s\" is not a valid id (%s)" % [value, ID_PATTERN])
			out.append("")
			continue
		out.append(value)
	return out


## A list of numbers, NAN where an entry was reported. `length` of -1 accepts any
## length.
static func _float_list(raw: Variant, file: String, path: String, errors: Array[ValidationError],
		length: int, low: float = 0.0, high: float = INF, low_open: bool = false,
		high_open: bool = false) -> Array[float]:
	var out: Array[float] = []
	if not _is_list(raw, file, path, errors):
		return out
	var list: Array = raw
	if length >= 0 and list.size() != length:
		_add(errors, file, path, "expected %d entries, found %d" % [length, list.size()])
	for i: int in list.size():
		out.append(_check_number(list[i], file, "%s[%d]" % [path, i], errors, low, high, low_open,
			high_open))
	return out


## A list of whole numbers, `INVALID_INT` where an entry was reported.
static func _integer_list(raw: Variant, file: String, path: String,
		errors: Array[ValidationError], length: int, low: int = 0) -> Array[int]:
	var out: Array[int] = []
	if not _is_list(raw, file, path, errors):
		return out
	var list: Array = raw
	if length >= 0 and list.size() != length:
		_add(errors, file, path, "expected %d entries, found %d" % [length, list.size()])
	for i: int in list.size():
		out.append(_check_integer(list[i], file, "%s[%d]" % [path, i], errors, low, INTEGER_MAX))
	return out


static func _range_text(low: float, high: float, low_open: bool, high_open: bool) -> String:
	var left: String = "(" if low_open else "["
	var right: String = ")" if high_open else "]"
	var low_text: String = "-inf" if low == -INF else str(low)
	var high_text: String = "inf" if high == INF else str(high)
	return "%s%s, %s%s" % [left, low_text, high_text, right]
