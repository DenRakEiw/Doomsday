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
	"anomaly", "milestones", "harm", "discovery", "containment", "factions", "society", "phase",
	"headlines", "results", "history", "events"]
## The two cuts of one society stage (opposition.md §8.2).
const SOCIETY_STAGE_KEYS: Array[String] = ["capacity_mul", "yield_mul"]
const REGION_KEYS: Array[String] = ["index", "id", "continent", "population", "air_gapped",
	"anchor", "attributes"]
const LINK_KEYS: Array[String] = ["a", "b", "kind"]
const ASSET_KEYS: Array[String] = ["kind", "watched_by", "glyph", "modifiers"]
## `assets.json`, `statuses.json`, `abilities.json` and every `events/*.json`
## are v1 (`loop-mechanics.md` §15.1).
const CONTENT_VERSION: int = 1
## The keys a `deploy` block takes (§11.1).
const DEPLOY_KEYS: Array[String] = ["kind", "count", "eligible"]
## The keys a node's `ability` block takes.
const ABILITY_REF_KEYS: Array[String] = ["id", "level"]
## The keys a group declaration takes.
const GROUP_KEYS: Array[String] = ["max"]
const TECH_NODE_KEYS: Array[String] = ["id", "tree", "tier", "cost", "requires", "requires_any",
	"modifiers", "flags", "grid", "watched_by", "on_purchase", "group", "excludes", "deploy",
	"ability", "requires_assets"]
const MODIFIER_KEYS: Array[String] = ["target", "op", "value", "scope"]
## The two string keys every ability needs, `ABILITY_<ID>_<suffix>` (§17.5).
const ABILITY_STRING_SUFFIXES: Array[String] = ["NAME", "DETAIL"]
## The three every status needs.
const STATUS_STRING_SUFFIXES: Array[String] = ["NAME", "DETAIL", "CODE"]
## The three string keys every node needs, `TECH_<ID>_<suffix>` (SCHEMA §7).
const TECH_STRING_SUFFIXES: Array[String] = ["NAME", "EFFECT", "FLAVOUR"]
const MILESTONE_KEYS: Array[String] = ["id", "kind", "threshold", "reward"]
## `headlines.json` is v1 (ticker.md §3.2).
const HEADLINES_VERSION: int = 1
## The event types that carry a region, and so allow an attribute filter (§5).
const REGION_EVENTS: Array[String] = [SimEvent.ASSET_DEPLOYED, SimEvent.ASSET_LOST,
	SimEvent.ORIGIN_CHOSEN, SimEvent.REGION_SEEDED,
	SimEvent.REGION_CONTROLLED, SimEvent.ANOMALY_SPAWNED, SimEvent.ANOMALY_EXPIRED,
	SimEvent.ANOMALY_COLLECTED, SimEvent.REGION_DEPOPULATED, SimEvent.DORMANCY_CHANGED,
	SimEvent.ABILITY_USED, SimEvent.STATUS_STARTED, SimEvent.STATUS_ENDED,
	SimEvent.PENETRATION_CHANGED, SimEvent.CONTROL_CHANGED, SimEvent.REGION_WIPED,
	SimEvent.EVENT_OPENED, SimEvent.EVENT_ANSWERED, SimEvent.EVENT_EXPIRED,
	SimEvent.EVENT_DROPPED, SimEvent.SOCIETY_STAGE_CHANGED]
## The strings every map event needs; per option the two of `EventOptionDef`.
const EVENT_STRING_SUFFIXES: Array[String] = ["TITLE", "BODY"]

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
	if _require(d, "factions", file, "", errors):
		_balance_factions(d["factions"], file, errors)
	if _require(d, "society", file, "", errors):
		_balance_society(d["society"], file, errors)
	if _require(d, "phase", file, "", errors):
		_balance_phase(d["phase"], file, errors)
	if _require(d, "headlines", file, "", errors):
		_balance_headlines(d["headlines"], file, errors)
	if _require(d, "results", file, "", errors):
		_balance_results(d["results"], file, errors)
	if _require(d, "history", file, "", errors):
		_balance_history(d["history"], file, errors)
	if _require(d, "events", file, "", errors):
		_balance_events(d["events"], file, errors)


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
	_check_keys(d, ["base_rate", "brake_floor", "capacity_weight_by_tier", "thresholds"], file,
		path, errors)
	_number(d, "base_rate", file, path, errors)
	_number(d, "brake_floor", file, path, errors, 0.0, 1.0)

	if _require(d, "capacity_weight_by_tier", file, path, errors):
		var weight_path: String = "containment.capacity_weight_by_tier"
		var weights: Array[float] = _float_list(d["capacity_weight_by_tier"], file, weight_path,
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


## The counter-move schedule (opposition.md §11).
static func _balance_factions(raw: Variant, file: String, errors: Array[ValidationError]) -> void:
	var path: String = "factions"
	if not _is_object(raw, file, path, errors):
		return
	var d: Dictionary = raw
	_check_keys(d, ["prepare_days", "prepare_min_days", "cooldown_days", "max_active_moves",
		"level_thresholds", "reset_days", "protest_deaths_share"], file, path, errors)
	_integer(d, "prepare_days", file, path, errors, 1)
	_integer(d, "prepare_min_days", file, path, errors, 1)
	_integer(d, "cooldown_days", file, path, errors, 0)
	_integer(d, "max_active_moves", file, path, errors, 1)
	_integer(d, "reset_days", file, path, errors, 1)
	_number(d, "protest_deaths_share", file, path, errors, 0.0, 1.0, true)
	if _require(d, "level_thresholds", file, path, errors):
		var level_path: String = "factions.level_thresholds"
		var levels: Array[float] = _float_list(d["level_thresholds"], file, level_path, errors,
			-1, 0.0, 1.0, true, true)
		for i: int in range(1, levels.size()):
			if not is_nan(levels[i]) and not is_nan(levels[i - 1]) and levels[i] <= levels[i - 1]:
				_add(errors, file, "%s[%d]" % [level_path, i], "thresholds must ascend strictly")


## Societal Function and Autophagy (opposition.md §8, §11): one stage more than
## there are thresholds, each cut a share in [0, 1].
static func _balance_society(raw: Variant, file: String, errors: Array[ValidationError]) -> void:
	var path: String = "society"
	if not _is_object(raw, file, path, errors):
		return
	var d: Dictionary = raw
	_check_keys(d, ["stage_thresholds", "gain_scale", "recovery_per_day", "deaths_weight",
		"stages", "autophagy_days"], file, path, errors)
	_number(d, "gain_scale", file, path, errors)
	_number(d, "recovery_per_day", file, path, errors)
	_number(d, "deaths_weight", file, path, errors)
	_integer(d, "autophagy_days", file, path, errors, 1)
	var threshold_count: int = -1
	if _require(d, "stage_thresholds", file, path, errors):
		var threshold_path: String = "society.stage_thresholds"
		var thresholds: Array[float] = _float_list(d["stage_thresholds"], file, threshold_path,
			errors, -1, 0.0, 100.0, true)
		threshold_count = thresholds.size()
		for i: int in range(1, thresholds.size()):
			if not is_nan(thresholds[i]) and not is_nan(thresholds[i - 1]) \
					and thresholds[i] <= thresholds[i - 1]:
				_add(errors, file, "%s[%d]" % [threshold_path, i], "thresholds must ascend strictly")
	if not _require(d, "stages", file, path, errors):
		return
	var stages_path: String = "society.stages"
	if not _is_list(d["stages"], file, stages_path, errors):
		return
	var stages: Array = d["stages"]
	if threshold_count >= 0 and stages.size() != threshold_count + 1:
		_add(errors, file, stages_path, "expected %d stages (one more than the thresholds), found %d"
			% [threshold_count + 1, stages.size()])
	for i: int in stages.size():
		var stage_path: String = "%s[%d]" % [stages_path, i]
		if not _is_object(stages[i], file, stage_path, errors):
			continue
		var stage: Dictionary = stages[i]
		_check_keys(stage, SOCIETY_STAGE_KEYS, file, stage_path, errors)
		for key: String in SOCIETY_STAGE_KEYS:
			_number(stage, key, file, stage_path, errors, 0.0, 1.0)


static func _balance_phase(raw: Variant, file: String, errors: Array[ValidationError]) -> void:
	var path: String = "phase"
	if not _is_object(raw, file, path, errors):
		return
	var d: Dictionary = raw
	_check_keys(d, ["open_containment", "open_world_share"], file, path, errors)
	_number(d, "open_containment", file, path, errors, 0.0, 1.0, true)
	_number(d, "open_world_share", file, path, errors, 0.0, 1.0, true)


## ticker.md §3.8: the caps and the pace of the headline system.
static func _balance_headlines(raw: Variant, file: String, errors: Array[ValidationError]) -> void:
	var path: String = "headlines"
	if not _is_object(raw, file, path, errors):
		return
	var d: Dictionary = raw
	_check_keys(d, ["max_per_tick", "max_per_command", "reaction_gap_days", "filler"], file, path,
		errors)
	_integer(d, "max_per_tick", file, path, errors, 1)
	_integer(d, "max_per_command", file, path, errors, 1)
	_integer(d, "reaction_gap_days", file, path, errors, 0)
	if _require(d, "filler", file, path, errors):
		_balance_filler(d["filler"], file, _join(path, "filler"), errors)


static func _balance_filler(raw: Variant, file: String, path: String,
		errors: Array[ValidationError]) -> void:
	if not _is_object(raw, file, path, errors):
		return
	var d: Dictionary = raw
	_check_keys(d, ["gap_days", "per_dark_region", "silence_dark_regions",
		"silence_deaths_share"], file, path, errors)
	_number(d, "per_dark_region", file, path, errors, 0.0)
	_integer(d, "silence_dark_regions", file, path, errors, 1)
	_number(d, "silence_deaths_share", file, path, errors, 0.0, 1.0, true)
	if not _require(d, "gap_days", file, path, errors):
		return
	var gaps_path: String = _join(path, "gap_days")
	if not _is_object(d["gap_days"], file, gaps_path, errors):
		return
	var gaps: Dictionary = d["gap_days"]
	_check_keys(gaps, World.PHASE_IDS, file, gaps_path, errors)
	for phase_id: String in World.PHASE_IDS:
		_number(gaps, phase_id, file, gaps_path, errors, 0.0, INF, true)


## m3-screens §7.4: the deaths share above which Ascendance reads as ashes.
static func _balance_results(raw: Variant, file: String, errors: Array[ValidationError]) -> void:
	var path: String = "results"
	if not _is_object(raw, file, path, errors):
		return
	var d: Dictionary = raw
	_check_keys(d, ["ashes_share"], file, path, errors)
	_number(d, "ashes_share", file, path, errors, 0.0, 1.0, true)


static func _balance_history(raw: Variant, file: String, errors: Array[ValidationError]) -> void:
	var path: String = "history"
	if not _is_object(raw, file, path, errors):
		return
	var d: Dictionary = raw
	_check_keys(d, ["interval_days", "max_samples", "log_max"], file, path, errors)
	_integer(d, "interval_days", file, path, errors, 1)
	_integer(d, "max_samples", file, path, errors, 2)
	_integer(d, "log_max", file, path, errors, 1)


## loop-mechanics §18: the opening roll per phase, when it starts, and how many
## map events may stand at once.
static func _balance_events(raw: Variant, file: String, errors: Array[ValidationError]) -> void:
	var path: String = "events"
	if not _is_object(raw, file, path, errors):
		return
	var d: Dictionary = raw
	_check_keys(d, ["opening_chance", "opening_from_regions", "max_open"], file, path, errors)
	_integer(d, "opening_from_regions", file, path, errors, 1)
	_integer(d, "max_open", file, path, errors, 1)
	if not _require(d, "opening_chance", file, path, errors):
		return
	var chance_path: String = _join(path, "opening_chance")
	if not _is_object(d["opening_chance"], file, chance_path, errors):
		return
	var chances: Dictionary = d["opening_chance"]
	_check_keys(chances, World.PHASE_IDS, file, chance_path, errors)
	for phase_id: String in World.PHASE_IDS:
		_number(chances, phase_id, file, chance_path, errors, 0.0, 1.0)


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


## Appends every problem in `assets.json` to `errors` (`loop-mechanics.md` §6.1,
## §15.2). There are exactly four kinds, each once, and a kind's modifiers carry
## no scope of their own: the loader scopes each one to the kind.
static func validate_assets(file: String, raw: Variant, strings: Dictionary[String, bool],
		strings_known: bool, errors: Array[ValidationError]) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var d: Dictionary = raw
	_check_keys(d, ["version", AssetDef.ROOT_KEY], file, "", errors)
	_content_version(d, file, errors)
	if not _require(d, AssetDef.ROOT_KEY, file, "", errors):
		return
	if not _is_list(d[AssetDef.ROOT_KEY], file, AssetDef.ROOT_KEY, errors):
		return
	var list: Array = d[AssetDef.ROOT_KEY]
	var seen: Dictionary[String, bool] = {}
	for i: int in list.size():
		var path: String = "%s[%d]" % [AssetDef.ROOT_KEY, i]
		if not _is_object(list[i], file, path, errors):
			continue
		var a: Dictionary = list[i]
		_check_keys(a, ASSET_KEYS, file, path, errors)
		var kind: String = _id(a, "kind", file, path, errors)
		if kind.is_empty():
			continue
		if not AssetDef.KINDS.has(kind):
			_add(errors, file, _join(path, "kind"), "unknown asset kind \"%s\"" % kind)
			continue
		if seen.has(kind):
			_add(errors, file, _join(path, "kind"), "duplicate kind \"%s\"" % kind)
			continue
		seen[kind] = true
		_asset_glyph(a, file, path, errors)
		_watched_by(a, file, path, errors)
		_asset_modifiers(a, file, path, errors)
		if strings_known:
			for key: String in [AssetDef.name_key(kind), AssetDef.plural_key(kind)]:
				if not strings.has(key):
					_add(errors, file, _join(path, "kind"),
						"no string \"%s\" with both an en and a de cell" % key)
	for kind: String in AssetDef.KINDS:
		if not seen.has(kind):
			_add(errors, file, AssetDef.ROOT_KEY, "missing asset kind \"%s\"" % kind)


static func _asset_glyph(a: Dictionary, file: String, path: String,
		errors: Array[ValidationError]) -> void:
	var glyph: String = _text(a, "glyph", file, path, errors)
	if not glyph.is_empty() and not Glyphs.ASSET_NAMES.has(glyph):
		_add(errors, file, _join(path, "glyph"), "unknown glyph \"%s\"" % glyph)


## A kind's modifiers are regional and unscoped: the loader gives every one the
## asset scope, so a scope in the file would be a second, silent one.
static func _asset_modifiers(a: Dictionary, file: String, path: String,
		errors: Array[ValidationError]) -> void:
	var modifiers_path: String = _join(path, "modifiers")
	if not _require(a, "modifiers", file, path, errors):
		return
	if not _is_list(a["modifiers"], file, modifiers_path, errors):
		return
	var modifiers: Array = a["modifiers"]
	var empty: Dictionary[String, String] = {}
	var no_continents: Dictionary[String, bool] = {}
	for i: int in modifiers.size():
		var entry_path: String = "%s[%d]" % [modifiers_path, i]
		_modifier(modifiers[i], file, entry_path, empty, false, no_continents, errors)
		if typeof(modifiers[i]) != TYPE_DICTIONARY:
			continue
		var m: Dictionary = modifiers[i]
		if m.has("scope"):
			_add(errors, file, _join(entry_path, "scope"),
				"an asset\'s modifier is scoped to its kind by the loader")
		var target: String = str(m.get("target", ""))
		if ModifierDef.TARGETS_GLOBAL.has(target):
			_add(errors, file, _join(entry_path, "target"),
				"\"%s\" is global; an asset stands in a region" % target)


## The `watched_by` list of an asset kind or a node: known factions, no repeats.
static func _watched_by(d: Dictionary, file: String, path: String,
		errors: Array[ValidationError]) -> void:
	if not d.has("watched_by"):
		return
	var watched_path: String = _join(path, "watched_by")
	if not _is_list(d["watched_by"], file, watched_path, errors):
		return
	var watched: Array = d["watched_by"]
	var seen: Dictionary[String, bool] = {}
	for i: int in watched.size():
		var entry_path: String = "%s[%d]" % [watched_path, i]
		if typeof(watched[i]) != TYPE_STRING:
			_add(errors, file, entry_path, "expected a string, found %s"
				% type_string(typeof(watched[i])))
			continue
		var faction: String = watched[i]
		if not Faction.FACTION_IDS.has(faction):
			_add(errors, file, entry_path, "unknown faction \"%s\"" % faction)
		elif seen.has(faction):
			_add(errors, file, entry_path, "duplicate faction \"%s\"" % faction)
		else:
			seen[faction] = true


## The `version` field every M4 content file carries.
static func _content_version(d: Dictionary, file: String, errors: Array[ValidationError]) -> void:
	if not _require(d, "version", file, "", errors):
		return
	var version: int = _integer(d, "version", file, "", errors, CONTENT_VERSION, CONTENT_VERSION)
	if version != INVALID_INT and version != CONTENT_VERSION:
		_add(errors, file, "version", "expected version %d" % CONTENT_VERSION)


## Appends every problem in an `Eligibility` block to `errors` (§5). `kinds` and
## `statuses` are the vocabularies the rule may name; a vocabulary that is not
## known yet (statuses before S4.2) is not checked rather than reported.
static func _eligibility(raw: Variant, file: String, path: String,
		continents: Dictionary[String, bool], continents_known: bool,
		statuses: Dictionary[String, int], statuses_known: bool,
		errors: Array[ValidationError]) -> void:
	if not _is_object(raw, file, path, errors):
		return
	var e: Dictionary = raw
	_check_keys(e, Eligibility.KEYS, file, path, errors)
	for key: String in Eligibility.FLAG_KEYS:
		if e.has(key):
			_bool(e, key, file, path, errors)
	for key: String in Eligibility.TABLE_KEYS:
		_eligibility_table(e, key, file, path, errors)
	for key: String in Eligibility.LIST_KEYS:
		var listed: PackedStringArray = _id_list(e, key, file, path, errors)
		if not statuses_known:
			continue
		for i: int in listed.size():
			if not listed[i].is_empty() and not statuses.has(listed[i]):
				_add(errors, file, "%s.%s[%d]" % [path, key, i],
					"unknown status \"%s\"" % listed[i])
	for key: String in Eligibility.SHARE_KEYS:
		if e.has(key):
			_number(e, key, file, path, errors, 0.0, 1.0)
	if e.has("continent"):
		var continent: String = _id(e, "continent", file, path, errors)
		if continents_known and not continent.is_empty() and not continents.has(continent):
			_add(errors, file, _join(path, "continent"), "unknown continent \"%s\"" % continent)
	_eligibility_bounds(e, file, path, errors)


## A tier or count table: `{name: whole number}`, the names from the right
## vocabulary and the bounds in the right order.
static func _eligibility_table(e: Dictionary, key: String, file: String, path: String,
		errors: Array[ValidationError]) -> void:
	if not e.has(key):
		return
	var table_path: String = _join(path, key)
	if not _is_object(e[key], file, table_path, errors):
		return
	var table: Dictionary = e[key]
	var attributes: bool = key.begins_with("attr")
	for raw_name: Variant in table:
		if typeof(raw_name) != TYPE_STRING:
			_add(errors, file, table_path, "object keys must be strings")
			continue
		var name: String = raw_name
		if attributes and not RegionDef.ATTRIBUTES_ALL.has(name):
			_add(errors, file, _join(table_path, name), "unknown attribute \"%s\"" % name)
			continue
		if not attributes and not AssetDef.KINDS.has(name):
			_add(errors, file, _join(table_path, name), "unknown asset kind \"%s\"" % name)
			continue
		if attributes:
			_integer(table, name, file, table_path, errors, RegionDef.TIER_MIN, RegionDef.TIER_MAX)
		else:
			_integer(table, name, file, table_path, errors, 0)


## No rule may be written so that it can never hold.
static func _eligibility_bounds(e: Dictionary, file: String, path: String,
		errors: Array[ValidationError]) -> void:
	for pair: Array in [["attr_min", "attr_max"], ["asset_min", "asset_max"]]:
		if typeof(e.get(pair[0])) != TYPE_DICTIONARY or typeof(e.get(pair[1])) != TYPE_DICTIONARY:
			continue
		var low: Dictionary = e[pair[0]]
		var high: Dictionary = e[pair[1]]
		for name: Variant in low:
			if not high.has(name) or typeof(low[name]) == TYPE_STRING:
				continue
			if float(low[name]) > float(high[name]):
				_add(errors, file, _join(path, str(pair[0])),
					"\"%s\" minimum %s is above its maximum %s" % [name, low[name], high[name]])
	if typeof(e.get("status_absent")) == TYPE_ARRAY \
			and typeof(e.get("status_present")) == TYPE_ARRAY:
		var absent: Array = e["status_absent"]
		for entry: Variant in absent:
			if (e["status_present"] as Array).has(entry):
				_add(errors, file, _join(path, "status_absent"),
					"\"%s\" is required to be both absent and present" % entry)
	if bool(e.get("not_origin", false)) and bool(e.get("origin", false)):
		_add(errors, file, path, "a rule cannot be both \"origin\" and \"not_origin\"")


# ------------------------------------------------------------- statuses.json


## Appends every problem in `statuses.json` to `errors` and answers **status id
## → how many levels it has** (§15.5), which is what the ability, eligibility and
## effect checks that follow need.
##
## Two passes: the ids first, because a status may apply another status — a
## `spread_status` naming its own id is the normal case (§7.1's Blackout).
static func validate_statuses(file: String, raw: Variant, strings: Dictionary[String, bool],
		strings_known: bool, errors: Array[ValidationError]) -> Dictionary[String, int]:
	var levels: Dictionary[String, int] = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return levels
	var d: Dictionary = raw
	_check_keys(d, ["version", StatusDef.ROOT_KEY], file, "", errors)
	_content_version(d, file, errors)
	if not _require(d, StatusDef.ROOT_KEY, file, "", errors):
		return levels
	if not _is_list(d[StatusDef.ROOT_KEY], file, StatusDef.ROOT_KEY, errors):
		return levels
	var list: Array = d[StatusDef.ROOT_KEY]

	for i: int in list.size():
		if typeof(list[i]) != TYPE_DICTIONARY:
			continue
		var s: Dictionary = list[i]
		var id: String = str(s.get("id", ""))
		if id.is_empty() or not _is_valid_id(id) or levels.has(id):
			continue
		levels[id] = (s["levels"] as Array).size() if typeof(s.get("levels")) == TYPE_ARRAY else 0

	var seen: Dictionary[String, bool] = {}
	for i: int in list.size():
		var path: String = "%s[%d]" % [StatusDef.ROOT_KEY, i]
		if not _is_object(list[i], file, path, errors):
			continue
		var s: Dictionary = list[i]
		_check_keys(s, StatusDef.KEYS, file, path, errors)
		var id: String = _id(s, "id", file, path, errors)
		if id.is_empty():
			continue
		if seen.has(id):
			_add(errors, file, _join(path, "id"), "duplicate id \"%s\"" % id)
			continue
		seen[id] = true
		var origin: String = _text(s, "origin", file, path, errors)
		if not origin.is_empty() and not StatusDef.ORIGINS.has(origin):
			_add(errors, file, _join(path, "origin"), "unknown origin \"%s\"" % origin)
		_watched_by(s, file, path, errors)
		if s.has("border"):
			_bool(s, "border", file, path, errors)
		if s.has("cancellable"):
			_bool(s, "cancellable", file, path, errors)
		_status_id_list(s, "blocks", file, path, levels, errors)
		_status_levels(s, file, path, levels, errors)
		if strings_known:
			for suffix: String in STATUS_STRING_SUFFIXES:
				var key: String = "STATUS_%s_%s" % [id.to_upper(), suffix]
				if not strings.has(key):
					_add(errors, file, _join(path, "id"),
						"no string \"%s\" with both an en and a de cell" % key)
	return levels


## The `levels` list of one status: at least one, each with a whole number of
## days, unscoped modifiers, and effects that may run in a region only when the
## status can be in one.
static func _status_levels(s: Dictionary, file: String, path: String,
		statuses: Dictionary[String, int], errors: Array[ValidationError]) -> void:
	var levels_path: String = _join(path, "levels")
	if not _require(s, "levels", file, path, errors):
		return
	if not _is_list(s["levels"], file, levels_path, errors):
		return
	var levels: Array = s["levels"]
	if levels.is_empty():
		_add(errors, file, levels_path, "a status needs at least one level")
		return
	for i: int in levels.size():
		var level_path: String = "%s[%d]" % [levels_path, i]
		if not _is_object(levels[i], file, level_path, errors):
			continue
		var l: Dictionary = levels[i]
		_check_keys(l, StatusLevelDef.KEYS, file, level_path, errors)
		_integer(l, "days", file, level_path, errors, 0)
		_status_modifiers(l, file, level_path, errors)
		_status_links(l, file, level_path, errors)
		_status_id_list(l, "ends_statuses", file, level_path, statuses, errors)
		# A status is applied to a region or to the agent, and the same
		# definition may be used for both: an effect that needs a region may
		# therefore not sit on one. The `global` key is what carries a status to
		# the agent (§8.2), so this is the conservative reading.
		for key: String in ["on_start", "on_end"]:
			if not l.has(key):
				continue
			var effects_path: String = _join(level_path, key)
			if not _is_list(l[key], file, effects_path, errors):
				continue
			var effects: Array = l[key]
			for k: int in effects.size():
				effect(effects[k], file, "%s[%d]" % [effects_path, k], true, statuses, true,
					errors)


## A status level's modifiers carry no scope: the region is injected when the
## status is applied, so a scope in the file would be a second, silent one (§7.3).
static func _status_modifiers(l: Dictionary, file: String, path: String,
		errors: Array[ValidationError]) -> void:
	if not l.has("modifiers"):
		return
	var modifiers_path: String = _join(path, "modifiers")
	if not _is_list(l["modifiers"], file, modifiers_path, errors):
		return
	var modifiers: Array = l["modifiers"]
	var no_regions: Dictionary[String, String] = {}
	var no_continents: Dictionary[String, bool] = {}
	for i: int in modifiers.size():
		var entry_path: String = "%s[%d]" % [modifiers_path, i]
		_modifier(modifiers[i], file, entry_path, no_regions, false, no_continents, errors, true)
		if typeof(modifiers[i]) != TYPE_DICTIONARY:
			continue
		if (modifiers[i] as Dictionary).has("scope"):
			_add(errors, file, _join(entry_path, "scope"),
				"a status\'s modifier is scoped to its region when it is applied")


static func _status_links(l: Dictionary, file: String, path: String,
		errors: Array[ValidationError]) -> void:
	if not l.has("closes_links"):
		return
	var listed: PackedStringArray = _id_list(l, "closes_links", file, path, errors)
	var all: bool = listed.has(StatusDef.LINKS_ALL)
	if all and listed.size() > 1:
		_add(errors, file, _join(path, "closes_links"),
			"\"%s\" is the whole list or none of it" % StatusDef.LINKS_ALL)
	for i: int in listed.size():
		if listed[i].is_empty() or listed[i] == StatusDef.LINKS_ALL:
			continue
		if not LinkDef.KINDS.has(listed[i]):
			_add(errors, file, "%s.closes_links[%d]" % [path, i],
				"unknown link kind \"%s\"" % listed[i])


## A list of status ids, each of which has to exist.
static func _status_id_list(d: Dictionary, key: String, file: String, path: String,
		statuses: Dictionary[String, int], errors: Array[ValidationError]) -> void:
	if not d.has(key):
		return
	var listed: PackedStringArray = _id_list(d, key, file, path, errors)
	for i: int in listed.size():
		if not listed[i].is_empty() and not statuses.has(listed[i]):
			_add(errors, file, "%s.%s[%d]" % [path, key, i],
				"unknown status \"%s\"" % listed[i])


# ------------------------------------------------------------ abilities.json


## Appends every problem in `abilities.json` to `errors` (§15.6). The tree is
## read back here: a node named in `levels_from` has to name this ability back,
## at the right level, so that the two sides cannot disagree (§9.1).
static func validate_abilities(file: String, raw: Variant,
		regions: Dictionary[String, String], regions_known: bool,
		statuses: Dictionary[String, int], statuses_known: bool, tech_raws: Array,
		strings: Dictionary[String, bool], strings_known: bool,
		errors: Array[ValidationError]) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var d: Dictionary = raw
	_check_keys(d, ["version", AbilityDef.ROOT_KEY], file, "", errors)
	_content_version(d, file, errors)
	if not _require(d, AbilityDef.ROOT_KEY, file, "", errors):
		return
	if not _is_list(d[AbilityDef.ROOT_KEY], file, AbilityDef.ROOT_KEY, errors):
		return
	var continents: Dictionary[String, bool] = {}
	for continent: String in regions.values():
		continents[continent] = true
	var nodes: Dictionary[String, Dictionary] = _tech_node_map(tech_raws)
	var list: Array = d[AbilityDef.ROOT_KEY]
	var seen: Dictionary[String, bool] = {}
	for i: int in list.size():
		var path: String = "%s[%d]" % [AbilityDef.ROOT_KEY, i]
		if not _is_object(list[i], file, path, errors):
			continue
		var a: Dictionary = list[i]
		_check_keys(a, AbilityDef.KEYS, file, path, errors)
		var id: String = _id(a, "id", file, path, errors)
		if id.is_empty():
			continue
		if seen.has(id):
			_add(errors, file, _join(path, "id"), "duplicate id \"%s\"" % id)
			continue
		seen[id] = true
		var target: String = _text(a, "target", file, path, errors)
		if not target.is_empty() and not AbilityDef.TARGETS.has(target):
			_add(errors, file, _join(path, "target"), "unknown target \"%s\"" % target)
		var regional: bool = target == AbilityDef.TARGET_REGION
		_number(a, "cost", file, path, errors, 0.0)
		_integer(a, "cooldown_days", file, path, errors, 0)
		if a.has("eligible"):
			if regional:
				_eligibility(a["eligible"], file, _join(path, "eligible"), continents,
					regions_known, statuses, statuses_known, errors)
			else:
				_add(errors, file, _join(path, "eligible"),
					"a global ability targets no region")
		if a.has("level_cap"):
			_integer(a, "level_cap", file, path, errors, 1)
		var levels: int = _ability_levels(a, id, file, path, nodes, errors)
		_ability_applies(a, file, path, regional, levels, statuses, statuses_known, errors)
		if strings_known:
			for suffix: String in ABILITY_STRING_SUFFIXES:
				var key: String = "ABILITY_%s_%s" % [id.to_upper(), suffix]
				if not strings.has(key):
					_add(errors, file, _join(path, "id"),
						"no string \"%s\" with both an en and a de cell" % key)


## `levels_from` and how many levels it grants. Each node exists, names this
## ability back at its own position, and needs the level below it — otherwise
## `Simulation.ability_level` could never reach the higher one (§9.2).
static func _ability_levels(a: Dictionary, id: String, file: String, path: String,
		nodes: Dictionary[String, Dictionary], errors: Array[ValidationError]) -> int:
	var listed: PackedStringArray = _id_list(a, "levels_from", file, path, errors)
	if listed.is_empty():
		_add(errors, file, _join(path, "levels_from"),
			"an ability needs at least one node to come from")
		return 0
	for i: int in listed.size():
		var entry_path: String = "%s.levels_from[%d]" % [path, i]
		var node_id: String = listed[i]
		if node_id.is_empty():
			continue
		if not nodes.has(node_id):
			_add(errors, file, entry_path, "unknown node \"%s\"" % node_id)
			continue
		var node: Dictionary = nodes[node_id]
		var reference: Variant = node.get("ability")
		if typeof(reference) != TYPE_DICTIONARY:
			_add(errors, file, entry_path,
				"\"%s\" does not grant an ability" % node_id)
			continue
		var back: Dictionary = reference
		if str(back.get("id", "")) != id or int(back.get("level", 0)) != i + 1:
			_add(errors, file, entry_path,
				"\"%s\" grants \"%s\" level %s, not \"%s\" level %d"
				% [node_id, back.get("id", ""), back.get("level", 0), id, i + 1])
		if i == 0:
			continue
		var requires: Variant = node.get("requires")
		if typeof(requires) != TYPE_ARRAY or not (requires as Array).has(listed[i - 1]):
			_add(errors, file, entry_path,
				"\"%s\" must require \"%s\", or its level could never be reached"
				% [node_id, listed[i - 1]])
	return listed.size()


## `applies` has exactly one key, and whatever it names has to exist.
static func _ability_applies(a: Dictionary, file: String, path: String, regional: bool,
		levels: int, statuses: Dictionary[String, int], statuses_known: bool,
		errors: Array[ValidationError]) -> void:
	var applies_path: String = _join(path, "applies")
	if not _require(a, "applies", file, path, errors):
		return
	if not _is_object(a["applies"], file, applies_path, errors):
		return
	var applies: Dictionary = a["applies"]
	_check_keys(applies, AbilityDef.APPLIES_KINDS, file, applies_path, errors)
	var given: Array[String] = []
	for kind: String in AbilityDef.APPLIES_KINDS:
		if applies.has(kind):
			given.append(kind)
	if given.size() != 1:
		_add(errors, file, applies_path,
			"an ability applies exactly one of %s, found %d"
			% [str(AbilityDef.APPLIES_KINDS), given.size()])
		return
	match given[0]:
		AbilityDef.APPLIES_STATUS:
			var status: String = _id(applies, AbilityDef.APPLIES_STATUS, file, applies_path,
				errors)
			if status.is_empty() or not statuses_known:
				return
			if not statuses.has(status):
				_add(errors, file, _join(applies_path, AbilityDef.APPLIES_STATUS),
					"unknown status \"%s\"" % status)
				return
			var needed: int = int(a.get("level_cap", levels))
			if statuses[status] < needed:
				_add(errors, file, _join(applies_path, AbilityDef.APPLIES_STATUS),
					"\"%s\" has %d levels; this ability reaches level %d"
					% [status, statuses[status], needed])
		AbilityDef.APPLIES_DEPLOY:
			if not regional:
				_add(errors, file, _join(applies_path, AbilityDef.APPLIES_DEPLOY),
					"a global ability has nowhere to place anything")
			var deploy_path: String = _join(applies_path, AbilityDef.APPLIES_DEPLOY)
			if not _is_object(applies[AbilityDef.APPLIES_DEPLOY], file, deploy_path, errors):
				return
			var deploy: Dictionary = applies[AbilityDef.APPLIES_DEPLOY]
			_check_keys(deploy, AbilityDef.DEPLOY_KEYS, file, deploy_path, errors)
			var kind: String = _id(deploy, "kind", file, deploy_path, errors)
			if not kind.is_empty() and not AssetDef.KINDS.has(kind):
				_add(errors, file, _join(deploy_path, "kind"),
					"unknown asset kind \"%s\"" % kind)
			_integer(deploy, "count", file, deploy_path, errors, 1)
		AbilityDef.APPLIES_EFFECTS:
			var effects_path: String = _join(applies_path, AbilityDef.APPLIES_EFFECTS)
			if not _is_list(applies[AbilityDef.APPLIES_EFFECTS], file, effects_path, errors):
				return
			var effects: Array = applies[AbilityDef.APPLIES_EFFECTS]
			for i: int in effects.size():
				effect(effects[i], file, "%s[%d]" % [effects_path, i], regional, statuses,
					statuses_known, errors)


## Node id → its raw entry, across every technology file. Built once per pass
## that has to read the tree back.
static func _tech_node_map(tech_raws: Array) -> Dictionary[String, Dictionary]:
	var nodes: Dictionary[String, Dictionary] = {}
	for raw: Variant in tech_raws:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = raw
		if typeof(d.get("nodes")) != TYPE_ARRAY:
			continue
		for entry: Variant in d["nodes"]:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var node: Dictionary = entry
			var id: String = str(node.get("id", ""))
			if not id.is_empty() and not nodes.has(id):
				nodes[id] = node
	return nodes


## Appends every problem in the technology files to `errors`. Ids are unique
## across all of them, so the files are validated together.
static func validate_tech(files: PackedStringArray, raws: Array,
		regions: Dictionary[String, String], regions_known: bool,
		statuses: Dictionary[String, int], statuses_known: bool,
		strings: Dictionary[String, bool], strings_known: bool,
		errors: Array[ValidationError]) -> void:
	var continents: Dictionary[String, bool] = {}
	for continent: String in regions.values():
		continents[continent] = true
	var groups: Dictionary[String, bool] = _tech_groups(files, raws, errors)

	# Pass 1: structure, and the id of every node that came through intact.
	var node_file: Dictionary[String, String] = {}
	var node_path: Dictionary[String, String] = {}
	var order: PackedStringArray = []
	# "<tree>|<column>|<row>" → the node that took the cell first, and the
	# column of every node whose grid is sound, for the line check of pass 2.
	var cells: Dictionary[String, String] = {}
	var columns: Dictionary[String, int] = {}
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
			_tech_node_fields(node, file, path, regions, regions_known, continents, statuses,
				statuses_known, errors)
			_tech_node_v3(node, file, path, groups, continents, regions_known, statuses,
				statuses_known, errors)
			var cell: Vector2i = _tech_grid(node, file, path, errors)
			if id.is_empty():
				continue
			if node_file.has(id):
				_add(errors, file, _join(path, "id"),
					"duplicate id \"%s\", first used by %s %s" % [id, node_file[id], node_path[id]])
				continue
			node_file[id] = file
			node_path[id] = path
			order.append(id)
			if strings_known:
				_tech_strings(id, strings, file, path, errors)
			if cell.x < 0:
				continue
			var key: String = "%s|%d|%d" % [str(node.get("tree", "")), cell.x, cell.y]
			if cells.has(key):
				_add(errors, file, _join(path, "grid"),
					"cell [%d, %d] is already taken by \"%s\"" % [cell.x, cell.y, cells[key]])
				continue
			cells[key] = id
			columns[id] = cell.x

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
					# Lines run left to right, so a node never sits to the left
					# of something it needs.
					if columns.has(id) and columns.has(dep) and columns[dep] > columns[id]:
						_add(errors, file, "%s.%s[%d]" % [path, key, k],
							"column %d is left of \"%s\" in column %d"
							% [columns[id], dep, columns[dep]])
					deps.append(dep)
			prerequisites[id] = deps
			_tech_excludes(node, id, file, path, node_file, raws, errors)

	_tech_cycles(order, prerequisites, node_file, node_path, errors)


## The `groups` header of every technology file: a group is declared once, in
## whichever file wants it, and every node's `group` must name one (§11.1).
static func _tech_groups(files: PackedStringArray, raws: Array,
		errors: Array[ValidationError]) -> Dictionary[String, bool]:
	var groups: Dictionary[String, bool] = {}
	var declared_in: Dictionary[String, String] = {}
	for f: int in files.size():
		var file: String = files[f]
		if typeof(raws[f]) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = raws[f]
		if not d.has(ContentLoader.GROUPS_KEY):
			continue
		if not _is_object(d[ContentLoader.GROUPS_KEY], file, ContentLoader.GROUPS_KEY, errors):
			continue
		var header: Dictionary = d[ContentLoader.GROUPS_KEY]
		for raw_id: Variant in header:
			if typeof(raw_id) != TYPE_STRING:
				_add(errors, file, ContentLoader.GROUPS_KEY, "object keys must be strings")
				continue
			var group: String = raw_id
			var path: String = _join(ContentLoader.GROUPS_KEY, group)
			if not _is_valid_id(group):
				_add(errors, file, path, "\"%s\" is not a valid id" % group)
				continue
			if declared_in.has(group):
				_add(errors, file, path,
					"group \"%s\" is already declared by %s" % [group, declared_in[group]])
				continue
			declared_in[group] = file
			if not _is_object(header[group], file, path, errors):
				continue
			var declaration: Dictionary = header[group]
			_check_keys(declaration, GROUP_KEYS, file, path, errors)
			_integer(declaration, "max", file, path, errors, 1)
			groups[group] = true
	return groups


## Tree v3's five fields (§11.1).
static func _tech_node_v3(node: Dictionary, file: String, path: String,
		groups: Dictionary[String, bool], continents: Dictionary[String, bool],
		regions_known: bool, statuses: Dictionary[String, int], statuses_known: bool,
		errors: Array[ValidationError]) -> void:
	if node.has("group"):
		var group: String = _id(node, "group", file, path, errors)
		if not group.is_empty() and not groups.has(group):
			_add(errors, file, _join(path, "group"), "undeclared group \"%s\"" % group)
	if node.has("requires_assets"):
		var needs_path: String = _join(path, "requires_assets")
		if _is_object(node["requires_assets"], file, needs_path, errors):
			var needed: Dictionary = node["requires_assets"]
			for raw_kind: Variant in needed:
				if typeof(raw_kind) != TYPE_STRING:
					_add(errors, file, needs_path, "object keys must be strings")
					continue
				var kind: String = raw_kind
				if not AssetDef.KINDS.has(kind):
					_add(errors, file, _join(needs_path, kind), "unknown asset kind \"%s\"" % kind)
					continue
				_integer(needed, kind, file, needs_path, errors, 1)
	_tech_deploy(node, file, path, continents, regions_known, statuses, statuses_known, errors)
	if node.has("ability"):
		var ability_path: String = _join(path, "ability")
		if _is_object(node["ability"], file, ability_path, errors):
			var ability: Dictionary = node["ability"]
			_check_keys(ability, ABILITY_REF_KEYS, file, ability_path, errors)
			_id(ability, "id", file, ability_path, errors)
			_integer(ability, "level", file, ability_path, errors, 1)


static func _tech_deploy(node: Dictionary, file: String, path: String,
		continents: Dictionary[String, bool], regions_known: bool,
		statuses: Dictionary[String, int], statuses_known: bool,
		errors: Array[ValidationError]) -> void:
	if not node.has("deploy"):
		return
	var deploy_path: String = _join(path, "deploy")
	if not _is_object(node["deploy"], file, deploy_path, errors):
		return
	var deploy: Dictionary = node["deploy"]
	_check_keys(deploy, DEPLOY_KEYS, file, deploy_path, errors)
	var kind: String = _id(deploy, "kind", file, deploy_path, errors)
	if not kind.is_empty() and not AssetDef.KINDS.has(kind):
		_add(errors, file, _join(deploy_path, "kind"), "unknown asset kind \"%s\"" % kind)
	_integer(deploy, "count", file, deploy_path, errors, 1)
	if deploy.has("eligible"):
		_eligibility(deploy["eligible"], file, _join(deploy_path, "eligible"), continents,
			regions_known, statuses, statuses_known, errors)


## Exclusions are symmetric: whatever a node closes has to close it back, or the
## tree would depend on which of the two was bought first (§11.1).
static func _tech_excludes(node: Dictionary, id: String, file: String, path: String,
		node_file: Dictionary[String, String], raws: Array,
		errors: Array[ValidationError]) -> void:
	var listed: PackedStringArray = _id_list(node, "excludes", file, path, errors)
	for i: int in listed.size():
		var other: String = listed[i]
		var entry_path: String = "%s.excludes[%d]" % [path, i]
		if other.is_empty():
			continue
		if other == id:
			_add(errors, file, entry_path, "a node cannot exclude itself")
			continue
		if not node_file.has(other):
			_add(errors, file, entry_path, "unknown node \"%s\"" % other)
			continue
		if not _excludes_back(raws, other, id):
			_add(errors, file, entry_path,
				"\"%s\" does not list \"%s\" back" % [other, id])


## Whether the node `other` lists `id` in its own `excludes`.
static func _excludes_back(raws: Array, other: String, id: String) -> bool:
	for raw: Variant in raws:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = raw
		if typeof(d.get("nodes")) != TYPE_ARRAY:
			continue
		for entry: Variant in d["nodes"]:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var candidate: Dictionary = entry
			if str(candidate.get("id", "")) != other:
				continue
			return typeof(candidate.get("excludes")) == TYPE_ARRAY \
				and (candidate["excludes"] as Array).has(id)
	return false


## The `nodes` array of one technology file. Reports its problems only on the
## first pass, so that the second pass does not report them twice.
static func _tech_nodes(file: String, raw: Variant, errors: Array[ValidationError],
		report: bool = true) -> Array:
	if typeof(raw) != TYPE_DICTIONARY:
		return []
	var d: Dictionary = raw
	if report:
		_check_keys(d, ["nodes", ContentLoader.GROUPS_KEY], file, "", errors)
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
		continents: Dictionary[String, bool], statuses: Dictionary[String, int],
		statuses_known: bool, errors: Array[ValidationError]) -> void:
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

	_tech_breakout(node, file, path, tree, errors)

	_watched_by(node, file, path, errors)

	if node.has("on_purchase"):
		var effects_path: String = _join(path, "on_purchase")
		if _is_list(node["on_purchase"], file, effects_path, errors):
			var effects: Array = node["on_purchase"]
			# A node runs its one-shots in the region it deployed into, so an
			# effect that needs one may only sit on a node that has one (§8.3).
			var has_region: bool = typeof(node.get("deploy")) == TYPE_DICTIONARY
			for i: int in effects.size():
				effect(effects[i], file, "%s[%d]" % [effects_path, i], has_region, statuses,
					statuses_known, errors)

	if node.has("modifiers"):
		var modifiers_path: String = _join(path, "modifiers")
		if _is_list(node["modifiers"], file, modifiers_path, errors):
			var modifiers: Array = node["modifiers"]
			for i: int in modifiers.size():
				_modifier(modifiers[i], file, "%s[%d]" % [modifiers_path, i], regions,
					regions_known, continents, errors)


## `breakout` is what a first Infiltration node is for, and nothing else grants
## it: a run that cannot leave its origin is not a run (D1.1).
static func _tech_breakout(node: Dictionary, file: String, path: String, tree: String,
		errors: Array[ValidationError]) -> void:
	if tree.is_empty() or not TechNodeDef.TREES.has(tree):
		return
	if not node.has("flags") or typeof(node["flags"]) != TYPE_ARRAY:
		return
	var flags: Array = node["flags"]
	var has_breakout: bool = flags.has(ModifierDef.FLAG_BREAKOUT)
	var is_first_infiltration: bool = tree == TechNodeDef.TREE_INFILTRATION \
		and int(node.get("tier", 0)) == TechNodeDef.TIER_MIN
	if is_first_infiltration and not has_breakout:
		_add(errors, file, _join(path, "flags"),
			"a tier 1 infiltration node must grant \"%s\"" % ModifierDef.FLAG_BREAKOUT)
	elif has_breakout and tree != TechNodeDef.TREE_INFILTRATION:
		_add(errors, file, _join(path, "flags"),
			"only an infiltration node grants \"%s\"" % ModifierDef.FLAG_BREAKOUT)


## The node's cell, or `[-1, -1]` for a grid that could not be read. Collisions
## need every node and are checked by the caller.
static func _tech_grid(node: Dictionary, file: String, path: String,
		errors: Array[ValidationError]) -> Vector2i:
	var grid_path: String = _join(path, "grid")
	if not _require(node, "grid", file, path, errors):
		return Vector2i(-1, -1)
	if not _is_list(node["grid"], file, grid_path, errors):
		return Vector2i(-1, -1)
	var grid: Array = node["grid"]
	if grid.size() != 2:
		_add(errors, file, grid_path, "expected [column, row], found %d entries" % grid.size())
		return Vector2i(-1, -1)
	var column: int = _check_integer(grid[0], file, "%s[0]" % grid_path, errors, 0,
		TechNodeDef.GRID_COLUMNS - 1)
	var row: int = _check_integer(grid[1], file, "%s[1]" % grid_path, errors, 0,
		TechNodeDef.GRID_ROWS - 1)
	if column == INVALID_INT or row == INVALID_INT:
		return Vector2i(-1, -1)
	return Vector2i(column, row)


## Appends every problem in one `EffectDef` entry to `errors` (§8, §15.4).
## `has_region` says whether the container this effect sits in runs with a
## region; an effect that needs one and does not get one can never work.
static func effect(raw: Variant, file: String, path: String, has_region: bool,
		statuses: Dictionary[String, int], statuses_known: bool,
		errors: Array[ValidationError]) -> void:
	if not _is_object(raw, file, path, errors):
		return
	var e: Dictionary = raw
	var id: String = _text(e, "effect", file, path, errors)
	if id.is_empty():
		return
	if not EffectDef.EFFECTS.has(id):
		_add(errors, file, _join(path, "effect"), "unknown effect \"%s\"" % id)
		return
	var allowed: Array[String] = ["effect"]
	allowed.append_array(EffectDef.REQUIRED_FIELDS[id])
	allowed.append_array(EffectDef.OPTIONAL_FIELDS[id])
	_check_keys(e, allowed, file, path, errors)
	for key: String in EffectDef.REQUIRED_FIELDS[id]:
		_require(e, key, file, path, errors)
	if EffectDef.effect_needs_region(id, bool(e.get("per_hardware", false))) and not has_region:
		_add(errors, file, _join(path, "effect"),
			"\"%s\" needs a region and this one never has one" % id)
	_effect_numbers(e, id, file, path, errors)
	_effect_ids(e, id, file, path, statuses, statuses_known, errors)


static func _effect_numbers(e: Dictionary, id: String, file: String, path: String,
		errors: Array[ValidationError]) -> void:
	if EffectDef.VALUE_RANGES.has(id) and e.has("value"):
		var bounds: Array = EffectDef.VALUE_RANGES[id]
		_number(e, "value", file, path, errors, float(bounds[0]), float(bounds[1]),
			bool(bounds[2]))
	if EffectDef.COUNT_RANGES.has(id) and e.has("count"):
		var counts: Array = EffectDef.COUNT_RANGES[id]
		_integer(e, "count", file, path, errors, int(counts[0]), int(counts[1]))
	if EffectDef.DAYS_RANGES.has(id) and e.has("days"):
		var days: Array = EffectDef.DAYS_RANGES[id]
		_integer(e, "days", file, path, errors, int(days[0]), int(days[1]))
	if e.has("level"):
		_integer(e, "level", file, path, errors, 1)


## The content ids an effect names. Status ids are checked from S4.2 on, when
## `statuses.json` exists; everything else is a closed vocabulary already.
static func _effect_ids(e: Dictionary, id: String, file: String, path: String,
		statuses: Dictionary[String, int], statuses_known: bool,
		errors: Array[ValidationError]) -> void:
	if e.has("kind"):
		var kind: String = _id(e, "kind", file, path, errors)
		if not kind.is_empty() and not AssetDef.KINDS.has(kind):
			_add(errors, file, _join(path, "kind"), "unknown asset kind \"%s\"" % kind)
	if e.has("faction"):
		var faction: String = _id(e, "faction", file, path, errors)
		if not faction.is_empty() and faction != EffectDef.FACTION_ALL \
				and not Faction.FACTION_IDS.has(faction):
			_add(errors, file, _join(path, "faction"), "unknown faction \"%s\"" % faction)
	if e.has("flag"):
		var flag: String = _id(e, "flag", file, path, errors)
		if not flag.is_empty() and ModifierDef.FLAGS.has(flag):
			_add(errors, file, _join(path, "flag"),
				"\"%s\" is a modifier flag and cannot also be set here" % flag)
	if e.has("watched_by"):
		_watched_by(e, file, path, errors)
	if id == EffectDef.END_STATUSES:
		var listed: PackedStringArray = _id_list(e, "ids", file, path, errors)
		if statuses_known:
			for i: int in listed.size():
				if not listed[i].is_empty() and not statuses.has(listed[i]):
					_add(errors, file, "%s.ids[%d]" % [path, i],
						"unknown status \"%s\"" % listed[i])
	if e.has("status"):
		var status: String = _id(e, "status", file, path, errors)
		if statuses_known and not status.is_empty() and not statuses.has(status):
			_add(errors, file, _join(path, "status"), "unknown status \"%s\"" % status)


## Every node needs its three strings, in both languages. The table is read from
## the CSV by `ContentLoader`; a root without one skips this check entirely.
static func _tech_strings(id: String, strings: Dictionary[String, bool], file: String,
		path: String, errors: Array[ValidationError]) -> void:
	for suffix: String in TECH_STRING_SUFFIXES:
		var key: String = "TECH_%s_%s" % [id.to_upper(), suffix]
		if not strings.has(key):
			_add(errors, file, _join(path, "id"),
				"no string \"%s\" with both an en and a de cell" % key)


## `allow_zero_mul` is a status's (§7.1): a `mul 0` is what "no capacity at all"
## means, and the clamp's floor is 0 anyway. On a technology node it stays an
## error — a node that multiplies a stat away is a node nothing can undo.
static func _modifier(raw: Variant, file: String, path: String,
		regions: Dictionary[String, String], regions_known: bool,
		continents: Dictionary[String, bool], errors: Array[ValidationError],
		allow_zero_mul: bool = false) -> void:
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
	if op == ModifierDef.OP_NAMES[ModifierDef.Op.MUL] and not is_nan(value):
		if allow_zero_mul and value < 0.0:
			_add(errors, file, _join(path, "value"), "a \"mul\" value cannot be negative")
		elif not allow_zero_mul and value <= 0.0:
			_add(errors, file, _join(path, "value"),
				"a \"mul\" value must be greater than 0")

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
	for form: String in ["attr", "region", "continent", "asset"]:
		if s.has(form):
			forms += 1
	if forms != 1:
		_add(errors, file, path,
			"a scope is exactly one of \"attr\", \"region\", \"continent\" and \"asset\"")

	if s.has("asset"):
		# `min` doubles as the minimum count here, and there is no `max`: an
		# asset scope asks "does at least this much stand there" (§6.3).
		_check_keys(s, ["asset", "min"], file, path, errors)
		var kind: String = _id(s, "asset", file, path, errors)
		if not kind.is_empty() and not AssetDef.KINDS.has(kind):
			_add(errors, file, _join(path, "asset"), "unknown asset kind \"%s\"" % kind)
		if s.has("min"):
			_integer(s, "min", file, path, errors, 1)
	elif s.has("attr"):
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


# ------------------------------------------------------------- events/*.json


## Appends every problem in the events files to `errors` (§15.7) and answers
## **event id → its option ids**, which the headline filters on `def` and
## `option` need. Ids are unique across files; the chain rules look at every
## file at once, because a chain may be split over none of them but could be.
static func validate_events(files: PackedStringArray, raws: Array,
		regions: Dictionary[String, String], regions_known: bool, statuses_raw: Variant,
		statuses: Dictionary[String, int], statuses_known: bool, tech_raws: Array,
		abilities: Dictionary[String, bool], strings: Dictionary[String, bool],
		strings_known: bool, errors: Array[ValidationError]) -> Dictionary[String, Array]:
	var options_by_event: Dictionary[String, Array] = {}
	var continents: Dictionary[String, bool] = {}
	for continent: String in regions.values():
		continents[continent] = true
	var status_ids: Dictionary[String, bool] = {}
	for status_id: String in statuses:
		status_ids[status_id] = true
	var known: Dictionary[String, Dictionary] = {
		"node": _tech_ids(tech_raws),
		"status": status_ids,
		"ability": abilities,
	}
	var context: Dictionary = {
		"continents": continents,
		"continents_known": regions_known,
		"statuses": statuses,
		"statuses_known": statuses_known,
		"world_statuses": _world_status_ids(statuses_raw),
		"known": known,
		"strings": strings,
		"strings_known": strings_known,
	}
	# Every event that came through with an id, for the chain rules at the end:
	# id → [file, path, entry].
	var entries: Dictionary[String, Array] = {}
	for f: int in raws.size():
		var file: String = files[f]
		if typeof(raws[f]) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = raws[f]
		_check_keys(d, ["version", EventDef.ROOT_KEY], file, "", errors)
		_content_version(d, file, errors)
		if not _require(d, EventDef.ROOT_KEY, file, "", errors):
			continue
		if not _is_list(d[EventDef.ROOT_KEY], file, EventDef.ROOT_KEY, errors):
			continue
		var list: Array = d[EventDef.ROOT_KEY]
		for i: int in list.size():
			var path: String = "%s[%d]" % [EventDef.ROOT_KEY, i]
			if not _is_object(list[i], file, path, errors):
				continue
			var e: Dictionary = list[i]
			var id: String = _id(e, "id", file, path, errors)
			if id.is_empty():
				continue
			if entries.has(id):
				_add(errors, file, _join(path, "id"), "duplicate event id \"%s\"" % id)
				continue
			entries[id] = [file, path, e]
			options_by_event[id] = _event(e, id, file, path, context, errors)
	_event_chains(entries, errors)
	return options_by_event


## The status ids whose `origin` is the world's — the only ones a counter-move may
## apply (§15.7).
static func _world_status_ids(raw: Variant) -> Dictionary[String, bool]:
	var ids: Dictionary[String, bool] = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return ids
	var d: Dictionary = raw
	if typeof(d.get(StatusDef.ROOT_KEY)) != TYPE_ARRAY:
		return ids
	for entry: Variant in d[StatusDef.ROOT_KEY]:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var s: Dictionary = entry
		if str(s.get("origin", "")) == StatusDef.ORIGIN_WORLD:
			ids[str(s.get("id", ""))] = true
	return ids


## One event. Answers its option ids, sound or not, so that a headline naming a
## broken option still gets a sensible message.
static func _event(e: Dictionary, id: String, file: String, path: String, context: Dictionary,
		errors: Array[ValidationError]) -> Array:
	_check_keys(e, EventDef.KEYS, file, path, errors)
	var kind: String = _text(e, "kind", file, path, errors)
	if not kind.is_empty() and not EventDef.KINDS.has(kind):
		_add(errors, file, _join(path, "kind"), "unknown kind \"%s\"" % kind)
	var is_chain: bool = kind == EventDef.KIND_CHAIN
	var is_counter: bool = kind == EventDef.KIND_COUNTER_MOVE
	if is_chain:
		_id(e, "chain", file, path, errors)
		if e.has("start"):
			_bool(e, "start", file, path, errors)
	else:
		for key: String in ["chain", "start"]:
			if e.has(key):
				_add(errors, file, _join(path, key), "only a chain step has \"%s\"" % key)
	var has_region: bool = _event_pick(e, kind, file, path, context, errors)
	if e.has("pick_weight") and not EventDef.PICK_WEIGHTS.has(str(e["pick_weight"])):
		_add(errors, file, _join(path, "pick_weight"),
			"\"%s\" is not one of %s" % [e["pick_weight"], EventDef.PICK_WEIGHTS])
	if e.has("when"):
		_headline_when(e["when"], file, _join(path, "when"), context["known"], errors, true)
	if e.has("weight"):
		_number(e, "weight", file, path, errors, 0.0, INF, true)
	if e.has("max_fires"):
		_integer(e, "max_fires", file, path, errors, 0)
	if e.has("cooldown_days"):
		_integer(e, "cooldown_days", file, path, errors, 0)
	_integer(e, "deadline_days", file, path, errors, 1)
	if e.has("modal"):
		_bool(e, "modal", file, path, errors)
	if e.has("illustration"):
		_id(e, "illustration", file, path, errors)
	_event_flags(e, file, path, errors)
	_event_counter_move(e, is_counter, file, path, context, errors)

	var option_ids: Array = []
	if _require(e, "options", file, path, errors) \
			and _is_list(e["options"], file, _join(path, "options"), errors):
		var options: Array = e["options"]
		if options.size() < EventDef.OPTIONS_MIN or options.size() > EventDef.OPTIONS_MAX:
			_add(errors, file, _join(path, "options"),
				"an event has %d to %d options, found %d"
				% [EventDef.OPTIONS_MIN, EventDef.OPTIONS_MAX, options.size()])
		for i: int in options.size():
			var option_path: String = "%s.options[%d]" % [path, i]
			var option_id: String = _event_option(options[i], id, is_chain, is_counter, has_region,
				file, option_path, context, errors)
			if option_id.is_empty():
				continue
			if option_ids.has(option_id):
				_add(errors, file, _join(option_path, "id"),
					"duplicate option id \"%s\"" % option_id)
				continue
			option_ids.append(option_id)
	_event_default(e, file, path, errors)
	if bool(context["strings_known"]):
		var strings: Dictionary[String, bool] = context["strings"]
		for suffix: String in EVENT_STRING_SUFFIXES:
			_event_string("EVENT_%s_%s" % [id.to_upper(), suffix], strings, file,
				_join(path, "id"), errors)
	return option_ids


## `pick`: an eligibility rule, `"same"` on a chain step that is not the start,
## or `{"rule": id}` on a counter-move. Answers whether the event has a region at
## all, which is what decides where a region-bound effect may stand.
static func _event_pick(e: Dictionary, kind: String, file: String, path: String,
		context: Dictionary, errors: Array[ValidationError]) -> bool:
	if not e.has("pick"):
		return false
	var pick_path: String = _join(path, "pick")
	var pick: Variant = e["pick"]
	if typeof(pick) == TYPE_STRING:
		if str(pick) != EventDef.PICK_SAME:
			_add(errors, file, pick_path, "\"%s\" is not \"%s\"" % [pick, EventDef.PICK_SAME])
		elif kind != EventDef.KIND_CHAIN or bool(e.get("start", false)):
			_add(errors, file, pick_path,
				"only a chain step after the first may land where the last one did")
		return true
	if typeof(pick) != TYPE_DICTIONARY:
		_add(errors, file, pick_path,
			"expected an object or \"same\", found %s" % type_string(typeof(pick)))
		return true
	var rule: Dictionary = pick
	if rule.has(EventDef.PICK_RULE_KEY):
		_check_keys(rule, [EventDef.PICK_RULE_KEY], file, pick_path, errors)
		if kind != EventDef.KIND_COUNTER_MOVE:
			_add(errors, file, pick_path, "only a counter-move picks by a named rule")
		var name: String = _text(rule, EventDef.PICK_RULE_KEY, file, pick_path, errors)
		if not name.is_empty() and not EventDef.PICK_RULES.has(name):
			_add(errors, file, _join(pick_path, EventDef.PICK_RULE_KEY),
				"\"%s\" is not one of %s" % [name, EventDef.PICK_RULES])
		return true
	_eligibility(pick, file, pick_path, context["continents"], bool(context["continents_known"]),
		context["statuses"], bool(context["statuses_known"]), errors)
	return true


## Story flags set when the event or an option opens: ids, and never one the
## modifier vocabulary owns.
static func _event_flags(d: Dictionary, file: String, path: String,
		errors: Array[ValidationError]) -> void:
	var flags: PackedStringArray = _id_list(d, "flags", file, path, errors)
	for i: int in flags.size():
		if ModifierDef.FLAGS.has(flags[i]):
			_add(errors, file, "%s.flags[%d]" % [path, i],
				"\"%s\" is a modifier flag and cannot also be set here" % flags[i])


## A counter-move names the world's status it applies and the faction behind it;
## no other kind may name either.
static func _event_counter_move(e: Dictionary, is_counter: bool, file: String, path: String,
		context: Dictionary, errors: Array[ValidationError]) -> void:
	if not is_counter:
		for key: String in ["status", "faction"]:
			if e.has(key):
				_add(errors, file, _join(path, key), "only a counter-move has \"%s\"" % key)
		return
	var faction: String = _id(e, "faction", file, path, errors)
	if not faction.is_empty() and not Faction.FACTION_IDS.has(faction):
		_add(errors, file, _join(path, "faction"), "unknown faction \"%s\"" % faction)
	var status: String = _id(e, "status", file, path, errors)
	if status.is_empty() or not bool(context["statuses_known"]):
		return
	var statuses: Dictionary[String, int] = context["statuses"]
	var world_statuses: Dictionary[String, bool] = context["world_statuses"]
	if not statuses.has(status):
		_add(errors, file, _join(path, "status"), "unknown status \"%s\"" % status)
	elif not world_statuses.has(status):
		_add(errors, file, _join(path, "status"),
			"\"%s\" is the player's; a counter-move applies one of the world's" % status)


## One option. Answers its id, or "" when it has none.
static func _event_option(raw: Variant, event_id: String, is_chain: bool, is_counter: bool,
		has_region: bool, file: String, path: String, context: Dictionary,
		errors: Array[ValidationError]) -> String:
	if not _is_object(raw, file, path, errors):
		return ""
	var o: Dictionary = raw
	_check_keys(o, EventOptionDef.KEYS, file, path, errors)
	var id: String = _id(o, "id", file, path, errors)
	if o.has("cost"):
		_number(o, "cost", file, path, errors, 0.0)
	if o.has("requires"):
		_event_requires(o["requires"], has_region, file, _join(path, "requires"), context, errors)
	var statuses: Dictionary[String, int] = context["statuses"]
	var statuses_known: bool = context["statuses_known"]
	if o.has("effects") and _is_list(o["effects"], file, _join(path, "effects"), errors):
		var effects: Array = o["effects"]
		for i: int in effects.size():
			effect(effects[i], file, "%s.effects[%d]" % [path, i], has_region, statuses,
				statuses_known, errors)
	if o.has("chance") and _is_list(o["chance"], file, _join(path, "chance"), errors):
		var rolls: Array = o["chance"]
		for i: int in rolls.size():
			_event_chance(rolls[i], is_chain, has_region, file, "%s.chance[%d]" % [path, i],
				context, errors)
	_event_flags(o, file, path, errors)
	for key: String in ["status_level", "status_days", "skip_status"]:
		if o.has(key) and not is_counter:
			_add(errors, file, _join(path, key), "only a counter-move's option has \"%s\"" % key)
	if is_counter:
		if o.has("status_level"):
			_integer(o, "status_level", file, path, errors, 0)
		if o.has("status_days"):
			_integer(o, "status_days", file, path, errors, 0)
		if o.has("skip_status"):
			_bool(o, "skip_status", file, path, errors)
	if o.has("next"):
		if is_chain:
			_event_next(o["next"], file, _join(path, "next"), errors)
		else:
			_add(errors, file, _join(path, "next"), "only a chain step leads anywhere")
	if bool(context["strings_known"]) and not id.is_empty():
		var strings: Dictionary[String, bool] = context["strings"]
		_event_string(EventOptionDef.text_key(event_id, id), strings, file, _join(path, "id"),
			errors)
		_event_string(EventOptionDef.result_key(event_id, id), strings, file, _join(path, "id"),
			errors)
	return id


## `requires` (§10.2): each key from its vocabulary, and an asset count only on an
## event that stands in a region.
static func _event_requires(raw: Variant, has_region: bool, file: String, path: String,
		context: Dictionary, errors: Array[ValidationError]) -> void:
	if not _is_object(raw, file, path, errors):
		return
	var r: Dictionary = raw
	_check_keys(r, EventOptionDef.REQUIRES_KEYS, file, path, errors)
	var known: Dictionary[String, Dictionary] = context["known"]
	var nodes: Dictionary = known["node"]
	for key: String in ["owned", "owned_any", "not_owned"]:
		var listed: PackedStringArray = _id_list(r, key, file, path, errors)
		for i: int in listed.size():
			if not listed[i].is_empty() and not nodes.has(listed[i]):
				_add(errors, file, "%s.%s[%d]" % [path, key, i], "unknown node \"%s\"" % listed[i])
	_id_list(r, "flag", file, path, errors)
	if r.has("asset_min"):
		if not has_region:
			_add(errors, file, _join(path, "asset_min"),
				"a global event has no region to count assets in")
		_eligibility_table(r, "asset_min", file, path, errors)
	if r.has("compute_min"):
		_number(r, "compute_min", file, path, errors, 0.0)
	if r.has("ability"):
		var ability: String = _id(r, "ability", file, path, errors)
		var abilities: Dictionary = known["ability"]
		if not ability.is_empty() and not abilities.has(ability):
			_add(errors, file, _join(path, "ability"), "unknown ability \"%s\"" % ability)


static func _event_chance(raw: Variant, is_chain: bool, has_region: bool, file: String,
		path: String, context: Dictionary, errors: Array[ValidationError]) -> void:
	if not _is_object(raw, file, path, errors):
		return
	var c: Dictionary = raw
	_check_keys(c, EventChanceDef.KEYS, file, path, errors)
	_number(c, "p", file, path, errors, 0.0, 1.0, true)
	if c.has("effects") and _is_list(c["effects"], file, _join(path, "effects"), errors):
		var effects: Array = c["effects"]
		for i: int in effects.size():
			effect(effects[i], file, "%s.effects[%d]" % [path, i], has_region,
				context["statuses"], bool(context["statuses_known"]), errors)
	if c.has("next"):
		if is_chain:
			_event_next(c["next"], file, _join(path, "next"), errors)
		else:
			_add(errors, file, _join(path, "next"), "only a chain step leads anywhere")


## `[{"step": id, "delay_days": ≥ 0}]`; an empty list is legal and ends the
## chain. Where the steps lead is `_event_chains`' question.
static func _event_next(raw: Variant, file: String, path: String,
		errors: Array[ValidationError]) -> void:
	if not _is_list(raw, file, path, errors):
		return
	var list: Array = raw
	for i: int in list.size():
		var entry_path: String = "%s[%d]" % [path, i]
		if not _is_object(list[i], file, entry_path, errors):
			continue
		var n: Dictionary = list[i]
		_check_keys(n, EventOptionDef.NEXT_KEYS, file, entry_path, errors)
		_id(n, "step", file, entry_path, errors)
		if n.has("delay_days"):
			_integer(n, "delay_days", file, entry_path, errors, 0)


## The default is what happens when the player does nothing, so it can never cost
## anything nor be locked (§15.7).
static func _event_default(e: Dictionary, file: String, path: String,
		errors: Array[ValidationError]) -> void:
	var default_id: String = _id(e, "default", file, path, errors)
	if default_id.is_empty() or typeof(e.get("options")) != TYPE_ARRAY:
		return
	for option: Variant in e["options"]:
		if typeof(option) != TYPE_DICTIONARY or str((option as Dictionary).get("id")) != default_id:
			continue
		var o: Dictionary = option
		if [TYPE_INT, TYPE_FLOAT].has(typeof(o.get("cost"))) and float(o["cost"]) != 0.0:
			_add(errors, file, _join(path, "default"),
				"the default \"%s\" costs %s; it must be free" % [default_id, o["cost"]])
		if typeof(o.get("requires")) == TYPE_DICTIONARY \
				and not (o["requires"] as Dictionary).is_empty():
			_add(errors, file, _join(path, "default"),
				"the default \"%s\" has requirements; it must always be open" % default_id)
		return
	_add(errors, file, _join(path, "default"), "\"%s\" is not one of the options" % default_id)


static func _event_string(key: String, strings: Dictionary[String, bool], file: String,
		path: String, errors: Array[ValidationError]) -> void:
	if not strings.has(key):
		_add(errors, file, path, "no string \"%s\" with both an en and a de cell" % key)


## The chain rules of §10.1, across every file: one `start` per chain; every
## `next` leads to a step of the same chain; every step but the start is led to.
static func _event_chains(entries: Dictionary[String, Array],
		errors: Array[ValidationError]) -> void:
	var starts: Dictionary[String, int] = {}
	var reached: Dictionary[String, bool] = {}
	for id: String in entries:
		var file: String = entries[id][0]
		var path: String = entries[id][1]
		var e: Dictionary = entries[id][2]
		if str(e.get("kind", "")) != EventDef.KIND_CHAIN:
			continue
		var chain: String = str(e.get("chain", ""))
		if bool(e.get("start", false)):
			starts[chain] = int(starts.get(chain, 0)) + 1
		if typeof(e.get("options")) != TYPE_ARRAY:
			continue
		var options: Array = e["options"]
		for i: int in options.size():
			if typeof(options[i]) != TYPE_DICTIONARY:
				continue
			var o: Dictionary = options[i]
			var option_path: String = "%s.options[%d]" % [path, i]
			_chain_targets(o.get("next"), chain, entries, reached, file,
				_join(option_path, "next"), errors)
			if typeof(o.get("chance")) != TYPE_ARRAY:
				continue
			var rolls: Array = o["chance"]
			for c: int in rolls.size():
				if typeof(rolls[c]) == TYPE_DICTIONARY:
					_chain_targets((rolls[c] as Dictionary).get("next"), chain, entries, reached,
						file, "%s.chance[%d].next" % [option_path, c], errors)
	for id: String in entries:
		var file: String = entries[id][0]
		var path: String = entries[id][1]
		var e: Dictionary = entries[id][2]
		if str(e.get("kind", "")) != EventDef.KIND_CHAIN:
			continue
		var chain: String = str(e.get("chain", ""))
		if int(starts.get(chain, 0)) != 1:
			_add(errors, file, _join(path, "chain"),
				"chain \"%s\" has %d starting steps; it needs exactly one"
				% [chain, int(starts.get(chain, 0))])
			starts[chain] = 1
		if not bool(e.get("start", false)) and not reached.has(id):
			_add(errors, file, _join(path, "id"),
				"\"%s\" is neither the start of its chain nor named by any \"next\"" % id)


static func _chain_targets(raw: Variant, chain: String, entries: Dictionary[String, Array],
		reached: Dictionary[String, bool], file: String, path: String,
		errors: Array[ValidationError]) -> void:
	if typeof(raw) != TYPE_ARRAY:
		return
	var list: Array = raw
	for i: int in list.size():
		if typeof(list[i]) != TYPE_DICTIONARY:
			continue
		var step: String = str((list[i] as Dictionary).get("step", ""))
		if step.is_empty():
			continue
		var step_path: String = "%s[%d].step" % [path, i]
		if not entries.has(step):
			_add(errors, file, step_path, "unknown event \"%s\"" % step)
			continue
		var target: Dictionary = entries[step][2]
		if str(target.get("kind", "")) != EventDef.KIND_CHAIN \
				or str(target.get("chain", "")) != chain:
			_add(errors, file, step_path,
				"\"%s\" is not a step of the chain \"%s\"" % [step, chain])
			continue
		reached[step] = true


# ---------------------------------------------------------------- factions.json


## Appends every problem in `factions.json` (opposition.md §12.1). Runs after
## the events: a move names a counter-move event, and every counter-move event
## must be named by exactly one move.
static func validate_factions(file: String, raw: Variant, event_raws: Array,
		strings: Dictionary[String, bool], strings_known: bool,
		errors: Array[ValidationError]) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var d: Dictionary = raw
	_check_keys(d, ["version", FactionDef.ROOT_KEY], file, "", errors)
	_content_version(d, file, errors)
	if not _require(d, FactionDef.ROOT_KEY, file, "", errors):
		return
	if not _is_list(d[FactionDef.ROOT_KEY], file, FactionDef.ROOT_KEY, errors):
		return
	var list: Array = d[FactionDef.ROOT_KEY]
	if list.size() != Faction.FACTION_IDS.size():
		_add(errors, file, FactionDef.ROOT_KEY, "expected the %d factions %s, found %d entries"
			% [Faction.FACTION_IDS.size(), Faction.FACTION_IDS, list.size()])
	# Counter-move event id → its faction, from the raw events.
	var counter_moves: Dictionary[String, String] = _counter_move_factions(event_raws)
	# Event id → the faction whose move names it.
	var named: Dictionary[String, String] = {}
	for i: int in list.size():
		var path: String = "%s[%d]" % [FactionDef.ROOT_KEY, i]
		if not _is_object(list[i], file, path, errors):
			continue
		var f: Dictionary = list[i]
		_check_keys(f, FactionDef.KEYS, file, path, errors)
		var id: String = _id(f, "id", file, path, errors)
		if id.is_empty():
			continue
		if not Faction.FACTION_IDS.has(id):
			_add(errors, file, _join(path, "id"), "unknown faction \"%s\"" % id)
			continue
		if i >= Faction.FACTION_IDS.size() or Faction.FACTION_IDS[i] != id:
			_add(errors, file, _join(path, "id"), "\"%s\" is out of order; the order is %s"
				% [id, Faction.FACTION_IDS])
		var attr: String = _text(f, "capacity_attr", file, path, errors)
		if not attr.is_empty() and not RegionDef.ATTRIBUTES_ALL.has(attr):
			_add(errors, file, _join(path, "capacity_attr"), "unknown attribute \"%s\"" % attr)
		var brake: String = _text(f, "brake", file, path, errors)
		if not brake.is_empty() and not ModifierDef.TARGETS_GLOBAL.has(brake):
			_add(errors, file, _join(path, "brake"), "\"%s\" is not a global target" % brake)
		_faction_terms(f, file, path, errors)
		_faction_moves(f, id, counter_moves, named, file, path, errors)
		if strings_known and not strings.has(FactionDef.name_key(id)):
			_add(errors, file, _join(path, "id"),
				"no string \"%s\" with both an en and a de cell" % FactionDef.name_key(id))
	for event_id: String in counter_moves:
		if not named.has(event_id):
			_add(errors, file, FactionDef.ROOT_KEY,
				"counter-move \"%s\" is named by no faction's moves" % event_id)


## Every counter-move event in the raw events files, with its faction.
static func _counter_move_factions(event_raws: Array) -> Dictionary[String, String]:
	var out: Dictionary[String, String] = {}
	for raw: Variant in event_raws:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = raw
		if typeof(d.get(EventDef.ROOT_KEY)) != TYPE_ARRAY:
			continue
		for entry: Variant in d[EventDef.ROOT_KEY]:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var e: Dictionary = entry
			if str(e.get("kind", "")) != EventDef.KIND_COUNTER_MOVE:
				continue
			out[str(e.get("id", ""))] = str(e.get("faction", ""))
	return out


static func _faction_terms(f: Dictionary, file: String, path: String,
		errors: Array[ValidationError]) -> void:
	if not _require(f, "terms", file, path, errors):
		return
	var terms_path: String = _join(path, "terms")
	if not _is_list(f["terms"], file, terms_path, errors):
		return
	var terms: Array = f["terms"]
	if terms.is_empty():
		_add(errors, file, terms_path, "a faction needs at least one term")
	for i: int in terms.size():
		var term_path: String = "%s[%d]" % [terms_path, i]
		if not _is_object(terms[i], file, term_path, errors):
			continue
		var t: Dictionary = terms[i]
		_check_keys(t, FactionTermDef.KEYS, file, term_path, errors)
		_number(t, "weight", file, term_path, errors)
		var source: String = _text(t, "source", file, term_path, errors)
		if source.is_empty():
			continue
		if not FactionTermDef.SOURCES.has(source):
			_add(errors, file, _join(term_path, "source"), "unknown source \"%s\"" % source)
			continue
		if source == FactionTermDef.SOURCE_OWNED_NODES:
			var tree: String = _text(t, "tree", file, term_path, errors)
			if not tree.is_empty() and not TechNodeDef.TREES.has(tree):
				_add(errors, file, _join(term_path, "tree"), "unknown tree \"%s\"" % tree)
		elif t.has("tree"):
			_add(errors, file, _join(term_path, "tree"), "only an owned_nodes term has a tree")
		if source == FactionTermDef.SOURCE_ASSETS:
			var kind: String = _text(t, "kind", file, term_path, errors)
			if not kind.is_empty() and not AssetDef.KINDS.has(kind):
				_add(errors, file, _join(term_path, "kind"), "unknown asset kind \"%s\"" % kind)
		elif t.has("kind"):
			_add(errors, file, _join(term_path, "kind"), "only an assets term has a kind")


static func _faction_moves(f: Dictionary, faction: String,
		counter_moves: Dictionary[String, String], named: Dictionary[String, String],
		file: String, path: String, errors: Array[ValidationError]) -> void:
	if not f.has("moves"):
		return
	var moves_path: String = _join(path, "moves")
	if not _is_list(f["moves"], file, moves_path, errors):
		return
	var moves: Array = f["moves"]
	if moves.size() > FactionDef.MOVES_MAX:
		_add(errors, file, moves_path, "at most %d moves, found %d"
			% [FactionDef.MOVES_MAX, moves.size()])
	var previous: float = NAN
	for i: int in moves.size():
		var move_path: String = "%s[%d]" % [moves_path, i]
		if not _is_object(moves[i], file, move_path, errors):
			continue
		var m: Dictionary = moves[i]
		_check_keys(m, FactionMoveDef.KEYS, file, move_path, errors)
		var event: String = _id(m, "event", file, move_path, errors)
		if not event.is_empty():
			_faction_move_event(event, faction, counter_moves, named, file,
				_join(move_path, "event"), errors)
		if _require(m, "trigger", file, move_path, errors):
			var trigger_path: String = _join(move_path, "trigger")
			if _is_object(m["trigger"], file, trigger_path, errors):
				var trigger: Dictionary = m["trigger"]
				_check_keys(trigger, FactionMoveDef.TRIGGER_KEYS, file, trigger_path, errors)
				if not trigger.has("containment") and not trigger.has("risk"):
					_add(errors, file, trigger_path, "needs containment, risk or both")
				if trigger.has("risk"):
					_number(trigger, "risk", file, trigger_path, errors, 0.0, 1.0, true)
				if trigger.has("containment"):
					var value: float = _number(trigger, "containment", file, trigger_path, errors,
						0.0, 1.0, true, true)
					if not is_nan(value) and not is_nan(previous) and value < previous:
						_add(errors, file, _join(trigger_path, "containment"),
							"move triggers must ascend")
					if not is_nan(value):
						previous = value
		if m.has("variants"):
			_faction_variants(m["variants"], faction, counter_moves, named, file,
				_join(move_path, "variants"), errors)


static func _faction_move_event(event: String, faction: String,
		counter_moves: Dictionary[String, String], named: Dictionary[String, String],
		file: String, path: String, errors: Array[ValidationError]) -> void:
	if not counter_moves.has(event):
		_add(errors, file, path, "\"%s\" is not a counter-move event" % event)
		return
	if counter_moves[event] != faction:
		_add(errors, file, path, "\"%s\" is a move of %s, not of %s"
			% [event, counter_moves[event], faction])
		return
	if named.has(event) and named[event] != faction:
		_add(errors, file, path, "\"%s\" is already a move of %s" % [event, named[event]])
		return
	named[event] = faction


static func _faction_variants(raw: Variant, faction: String,
		counter_moves: Dictionary[String, String], named: Dictionary[String, String],
		file: String, path: String, errors: Array[ValidationError]) -> void:
	if not _is_object(raw, file, path, errors):
		return
	var v: Dictionary = raw
	_check_keys(v, FactionMoveDef.VARIANTS_KEYS, file, path, errors)
	var select: String = _text(v, "select", file, path, errors)
	if not select.is_empty() and not FactionMoveDef.SELECTORS.has(select):
		_add(errors, file, _join(path, "select"), "unknown selector \"%s\"" % select)
		select = ""
	if not _require(v, "events", file, path, errors):
		return
	var events_path: String = _join(path, "events")
	if not _is_object(v["events"], file, events_path, errors):
		return
	var events: Dictionary = v["events"]
	for raw_key: Variant in events:
		var key: String = str(raw_key)
		var entry_path: String = _join(events_path, key)
		if select == FactionMoveDef.SELECTOR_SEEDS_BY_KIND_MAX and not LinkDef.KINDS.has(key):
			_add(errors, file, entry_path, "\"%s\" is not a link kind" % key)
		if typeof(events[raw_key]) != TYPE_STRING:
			_add(errors, file, entry_path, "expected a string, found %s"
				% type_string(typeof(events[raw_key])))
			continue
		_faction_move_event(str(events[raw_key]), faction, counter_moves, named, file,
			entry_path, errors)


# --------------------------------------------------------------- headlines.json


## Appends every problem in `headlines.json` to `errors` (ticker.md §5). The
## references are checked against what the other files delivered, so a headline
## can never point at a region, node, milestone or threshold that is not there.
static func validate_headlines(file: String, raw: Variant, balance_raw: Variant,
		regions: Dictionary[String, String], regions_known: bool, tech_raws: Array,
		statuses: Dictionary[String, int], abilities: Dictionary[String, bool],
		events: Dictionary[String, Array],
		strings: Dictionary[String, bool], strings_known: bool,
		errors: Array[ValidationError]) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var d: Dictionary = raw
	_check_keys(d, ["version", "headlines"], file, "", errors)
	_integer(d, "version", file, "", errors, HEADLINES_VERSION, HEADLINES_VERSION)
	if not _require(d, "headlines", file, "", errors):
		return
	if not _is_list(d["headlines"], file, "headlines", errors):
		return
	var list: Array = d["headlines"]
	if list.is_empty():
		_add(errors, file, "headlines", "expected at least one headline")

	# Every `data` field a headline may filter on, with the ids it may name
	# (loop-content.md §9.3). A vocabulary the step has not introduced yet is an
	# empty table, which leaves the field unchecked rather than rejecting it.
	var status_ids: Dictionary[String, bool] = {}
	for status_id: String in statuses:
		status_ids[status_id] = true
	var event_ids: Dictionary[String, bool] = {}
	var option_ids: Dictionary[String, Array] = {}
	for event_id: String in events:
		event_ids[event_id] = true
		option_ids[event_id] = events[event_id]
	var known: Dictionary[String, Dictionary] = {
		"node": _tech_ids(tech_raws),
		"region": _region_ids(regions, regions_known),
		"milestone": _milestone_ids(balance_raw, regions, regions_known),
		"status": status_ids,
		"ability": abilities,
		"def": event_ids,
		"options": option_ids,
	}
	var seen: Dictionary[String, bool] = {}
	for i: int in list.size():
		_headline(list[i], file, "headlines[%d]" % i, known, balance_raw, seen, strings,
			strings_known, errors)


static func _headline(raw: Variant, file: String, path: String,
		known: Dictionary[String, Dictionary], balance_raw: Variant,
		seen: Dictionary[String, bool], strings: Dictionary[String, bool], strings_known: bool,
		errors: Array[ValidationError]) -> void:
	if not _is_object(raw, file, path, errors):
		return
	var h: Dictionary = raw
	_check_keys(h, HeadlineDef.ENTRY_KEYS, file, path, errors)

	var id: String = _id(h, "id", file, path, errors)
	if not id.is_empty():
		if seen.has(id):
			_add(errors, file, _join(path, "id"), "duplicate headline id \"%s\"" % id)
		seen[id] = true
		_headline_string(id, strings, strings_known, file, path, errors)

	var stream: String = _text(h, "stream", file, path, errors)
	if not stream.is_empty() and not HeadlineDef.STREAMS.has(stream):
		_add(errors, file, _join(path, "stream"),
			"\"%s\" is not one of %s" % [stream, HeadlineDef.STREAMS])
	if h.has("register") and not HeadlineDef.REGISTERS.has(str(h["register"])):
		_add(errors, file, _join(path, "register"),
			"\"%s\" is not one of %s" % [h["register"], HeadlineDef.REGISTERS])

	_headline_numbers(h, file, path, errors)
	_headline_trigger_shape(h, stream, file, path, errors)
	if h.has("on"):
		_headline_on(h["on"], file, _join(path, "on"), known, balance_raw, errors)
	if h.has("when"):
		_headline_when(h["when"], file, _join(path, "when"), known, errors)


## The line itself lives in `strings.csv`; a headline without one would fire and
## show its own key.
static func _headline_string(id: String, strings: Dictionary[String, bool], strings_known: bool,
		file: String, path: String, errors: Array[ValidationError]) -> void:
	if not strings_known:
		return
	var key: String = HeadlineDef.KEY_PREFIX + id.to_upper()
	if strings.has(key):
		return
	_add(errors, file, _join(path, "id"),
		"no string \"%s\" with both an en and a de cell" % key)


static func _headline_numbers(h: Dictionary, file: String, path: String,
		errors: Array[ValidationError]) -> void:
	if h.has("weight"):
		_number(h, "weight", file, path, errors, 0.0, INF, true)
	if h.has("chance"):
		_number(h, "chance", file, path, errors, 0.0, 1.0, true)
	if h.has("cooldown_days"):
		_integer(h, "cooldown_days", file, path, errors, 0)
	if h.has("max_fires"):
		_integer(h, "max_fires", file, path, errors, 0)
	if h.has("fallback") and typeof(h["fallback"]) != TYPE_BOOL:
		_add(errors, file, _join(path, "fallback"),
			"expected true or false, found %s" % type_string(typeof(h["fallback"])))


## Which of the two triggers a headline may have, and what only an event trigger
## allows (§3.2).
static func _headline_trigger_shape(h: Dictionary, stream: String, file: String, path: String,
		errors: Array[ValidationError]) -> void:
	if not h.has("on") and not h.has("when"):
		_add(errors, file, path, "expected at least one of \"on\" and \"when\"")
	if h.has("on") and stream == HeadlineDef.STREAM_FILLER:
		_add(errors, file, _join(path, "on"), "a filler headline has no event trigger")
	for key: String in ["chance", "fallback"]:
		if h.has(key) and not h.has("on"):
			_add(errors, file, _join(path, key), "only an event trigger has \"%s\"" % key)


static func _headline_on(raw: Variant, file: String, path: String,
		known: Dictionary[String, Dictionary], balance_raw: Variant,
		errors: Array[ValidationError]) -> void:
	if not _is_object(raw, file, path, errors):
		return
	var on: Dictionary = raw
	_check_keys(on, HeadlineDef.ON_KEYS, file, path, errors)
	var event: String = _text(on, "event", file, path, errors)
	if not event.is_empty() and not SimEvent.TYPES_ALL.has(event):
		_add(errors, file, _join(path, "event"), "\"%s\" is not an event type" % event)
	if on.has("data"):
		_headline_data(on["data"], event, file, _join(path, "data"), known, balance_raw, errors)
	for key: String in ["region_attr_min", "region_attr_max"]:
		if on.has(key):
			_headline_attrs(on[key], event, file, _join(path, key), errors)
	_headline_node_filters(on, event, file, path, errors)


## `node_tree` and `node_tier` read a node off the event, so only the event that
## carries one may have them.
static func _headline_node_filters(on: Dictionary, event: String, file: String, path: String,
		errors: Array[ValidationError]) -> void:
	var filtered: bool = on.has("node_tree") or on.has("node_tier")
	if filtered and not event.is_empty() and event != SimEvent.NODE_PURCHASED:
		_add(errors, file, path,
			"\"%s\" carries no purchased node, so it has no node filter" % event)
	if on.has("node_tree") and not TechNodeDef.TREES.has(str(on["node_tree"])):
		_add(errors, file, _join(path, "node_tree"),
			"\"%s\" is not one of %s" % [on["node_tree"], TechNodeDef.TREES])
	if on.has("node_tier"):
		_integer(on, "node_tier", file, path, errors, TechNodeDef.TIER_MIN, TechNodeDef.TIER_MAX)


## `data` is field to a scalar or a list of them; the fields that name content
## are checked against what the other files delivered.
static func _headline_data(raw: Variant, event: String, file: String, path: String,
		known: Dictionary[String, Dictionary], balance_raw: Variant,
		errors: Array[ValidationError]) -> void:
	if not _is_object(raw, file, path, errors):
		return
	var data: Dictionary = raw
	for raw_field: Variant in data.keys():
		if typeof(raw_field) != TYPE_STRING:
			_add(errors, file, path, "object keys must be strings")
			continue
		var field: String = raw_field
		if field.begins_with("_"):
			continue
		var listed: bool = typeof(data[field]) == TYPE_ARRAY
		var values: Array = data[field] if listed else [data[field]]
		for i: int in values.size():
			var field_path: String = _join(path, field)
			var value_path: String = "%s[%d]" % [field_path, i] if listed else field_path
			_headline_value(values[i], field, event, file, value_path, known, balance_raw, errors)
	if data.has("option"):
		_headline_option(data, file, path, known, errors)


## `option` names an answer, which only means something next to the `def` it
## belongs to (`loop-content.md` §9.3).
static func _headline_option(data: Dictionary, file: String, path: String,
		known: Dictionary[String, Dictionary], errors: Array[ValidationError]) -> void:
	if not data.has("def"):
		_add(errors, file, _join(path, "option"), "\"option\" needs a \"def\" beside it")
		return
	var defs: Array = data["def"] if typeof(data["def"]) == TYPE_ARRAY else [data["def"]]
	var options: Array = data["option"] if typeof(data["option"]) == TYPE_ARRAY \
		else [data["option"]]
	var allowed: Dictionary = known["options"]
	for option: Variant in options:
		var found: bool = false
		for def: Variant in defs:
			if allowed.has(str(def)) and (allowed[str(def)] as Array).has(str(option)):
				found = true
		if not found:
			_add(errors, file, _join(path, "option"),
				"\"%s\" is not an option of %s" % [option, defs])


static func _headline_value(value: Variant, field: String, event: String, file: String,
		path: String, known: Dictionary[String, Dictionary], balance_raw: Variant,
		errors: Array[ValidationError]) -> void:
	if [TYPE_DICTIONARY, TYPE_ARRAY].has(typeof(value)):
		_add(errors, file, path, "expected a scalar, found %s" % type_string(typeof(value)))
		return
	if field == "threshold":
		_headline_threshold(value, balance_raw, file, path, errors)
		return
	var allowed: Array[String] = _headline_domain(field, event, known)
	if allowed.is_empty() or typeof(value) != TYPE_STRING:
		return
	if not allowed.has(str(value)):
		_add(errors, file, path, "\"%s\" is not a known %s" % [value, field])


## The ids a `data` field may hold, or an empty list for a field that is free.
static func _headline_domain(field: String, event: String,
		known: Dictionary[String, Dictionary]) -> Array[String]:
	match field:
		"node", "region", "milestone", "status", "ability", "def":
			var ids: Array[String] = []
			for id: String in known[field]:
				ids.append(id)
			return ids
		"link_kind":
			return LinkDef.KINDS
		"cause":
			return [SimEvent.CAUSE_SCRUTINY, SimEvent.CAUSE_DEATHS]
		"outcome":
			return World.OUTCOME_IDS
		"faction":
			# loop-content §9.3: a faction field names one of the four.
			var factions: Array[String] = Faction.FACTION_IDS.duplicate()
			return factions
		"to", "from":
			if event == SimEvent.THREAT_LEADER_CHANGED:
				return Faction.FACTION_IDS
			if event == SimEvent.PHASE_CHANGED:
				return World.PHASE_IDS
			# A ternary with `[]` is an untyped `Array`, which the typed return
			# refuses at run time; the society stages are numbers, so free.
			var free: Array[String] = []
			return free
	return []


static func _headline_threshold(value: Variant, balance_raw: Variant, file: String, path: String,
		errors: Array[ValidationError]) -> void:
	if typeof(balance_raw) != TYPE_DICTIONARY:
		return
	var balance: Dictionary = balance_raw
	if typeof(balance.get("containment")) != TYPE_DICTIONARY:
		return
	var containment: Dictionary = balance["containment"]
	if typeof(containment.get("thresholds")) != TYPE_ARRAY:
		return
	for candidate: Variant in containment["thresholds"]:
		if [TYPE_INT, TYPE_FLOAT].has(typeof(candidate)) \
				and is_equal_approx(float(candidate), float(value)):
			return
	_add(errors, file, path, "%s is not one of balance.containment.thresholds" % value)


## The eight region attributes, in tiers, and only on an event that names a
## region to read them from.
static func _headline_attrs(raw: Variant, event: String, file: String, path: String,
		errors: Array[ValidationError]) -> void:
	if not _is_object(raw, file, path, errors):
		return
	if not event.is_empty() and not REGION_EVENTS.has(event):
		_add(errors, file, path, "\"%s\" carries no region, so it has no attribute filter" % event)
	var attributes: Dictionary = raw
	_check_keys(attributes, RegionDef.ATTRIBUTES_ALL, file, path, errors)
	for attribute: String in RegionDef.ATTRIBUTES_ALL:
		if attributes.has(attribute):
			_integer(attributes, attribute, file, path, errors, RegionDef.TIER_MIN,
				RegionDef.TIER_MAX)


## `story_flags` lets a flag list name any id: an event's `when` may read a
## story flag, which no vocabulary lists (a flag may be set for a later chain).
static func _headline_when(raw: Variant, file: String, path: String,
		known: Dictionary[String, Dictionary], errors: Array[ValidationError],
		story_flags: bool = false) -> void:
	if not _is_object(raw, file, path, errors):
		return
	var when: Dictionary = raw
	var keys: Array[String] = HeadlineConditions.when_keys()
	_check_keys(when, keys, file, path, errors)
	for raw_key: Variant in when.keys():
		if typeof(raw_key) == TYPE_STRING and keys.has(str(raw_key)):
			_headline_condition(when, str(raw_key), file, path, known, errors, story_flags)
	_headline_bounds(when, file, path, errors)


static func _headline_condition(when: Dictionary, key: String, file: String, path: String,
		known: Dictionary[String, Dictionary], errors: Array[ValidationError],
		story_flags: bool = false) -> void:
	if HeadlineConditions.TABLE_KEYS.has(key):
		_when_table(when, key, file, path, errors)
		return
	if HeadlineConditions.STATUS_LISTS.has(key) or key == HeadlineConditions.KEY_ABILITY_UNLOCKED:
		var vocabulary: String = "ability" if key == HeadlineConditions.KEY_ABILITY_UNLOCKED \
			else "status"
		var ids: Array[String] = []
		for id: String in known[vocabulary]:
			ids.append(id)
		_headline_id_list(when, key, ids, file, path, errors)
		return
	if HeadlineConditions.STORY_FLAG_LISTS.has(key) \
			or (story_flags and HeadlineConditions.FLAG_LISTS.has(key)):
		_id_list(when, key, file, path, errors)
		return
	if key == HeadlineConditions.KEY_DISCOVERED:
		if typeof(when[key]) != TYPE_BOOL:
			_add(errors, file, _join(path, key),
				"expected true or false, found %s" % type_string(typeof(when[key])))
		return
	if key == HeadlineConditions.KEY_PHASE:
		_headline_id_list(when, key, World.PHASE_IDS, file, path, errors)
		return
	if HeadlineConditions.NODE_LISTS.has(key):
		var nodes: Array[String] = []
		for id: String in known["node"]:
			nodes.append(id)
		_headline_id_list(when, key, nodes, file, path, errors)
		return
	if HeadlineConditions.FLAG_LISTS.has(key):
		_headline_id_list(when, key, ModifierDef.FLAGS, file, path, errors)
		return
	var name: String = HeadlineConditions.reading_of(key)
	if bool(HeadlineConditions.READINGS[name][1]):
		_integer(when, key, file, path, errors, 0)
	else:
		_number(when, key, file, path, errors, -INF)


## `faction_min` and friends: `{id: bound}`, the ids from the right vocabulary.
static func _when_table(when: Dictionary, key: String, file: String, path: String,
		errors: Array[ValidationError]) -> void:
	var table_path: String = _join(path, key)
	if not _is_object(when[key], file, table_path, errors):
		return
	var table: Dictionary = when[key]
	var factions: bool = key.begins_with("faction")
	for raw_name: Variant in table:
		var name: String = str(raw_name)
		if factions and not Faction.FACTION_IDS.has(name):
			_add(errors, file, _join(table_path, name), "unknown faction \"%s\"" % name)
			continue
		if not factions and not AssetDef.KINDS.has(name):
			_add(errors, file, _join(table_path, name), "unknown asset kind \"%s\"" % name)
			continue
		if factions:
			_number(table, name, file, table_path, errors, 0.0, 1.0)
		else:
			_integer(table, name, file, table_path, errors, 0)


## No condition may be written so that it can never hold.
static func _headline_bounds(when: Dictionary, file: String, path: String,
		errors: Array[ValidationError]) -> void:
	for name: String in HeadlineConditions.READINGS:
		var low: String = name + HeadlineConditions.SUFFIX_MIN
		var high: String = name + HeadlineConditions.SUFFIX_MAX
		if not when.has(low) or not when.has(high):
			continue
		if not [TYPE_INT, TYPE_FLOAT].has(typeof(when[low])) \
				or not [TYPE_INT, TYPE_FLOAT].has(typeof(when[high])):
			continue
		if float(when[low]) > float(when[high]):
			_add(errors, file, _join(path, low), "%s is above %s" % [low, high])


static func _headline_id_list(d: Dictionary, key: String, allowed: Array[String], file: String,
		path: String, errors: Array[ValidationError]) -> void:
	var list_path: String = _join(path, key)
	if not _is_list(d[key], file, list_path, errors):
		return
	var list: Array = d[key]
	for i: int in list.size():
		if typeof(list[i]) != TYPE_STRING or not allowed.has(str(list[i])):
			_add(errors, file, "%s[%d]" % [list_path, i],
				"\"%s\" is not one of %s" % [list[i], allowed])


## The node ids of every technology file, sound or not: a headline pointing at a
## broken node is the node's error, not the headline's.
static func _tech_ids(tech_raws: Array) -> Dictionary[String, bool]:
	var ids: Dictionary[String, bool] = {}
	for raw: Variant in tech_raws:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var file: Dictionary = raw
		if typeof(file.get("nodes")) != TYPE_ARRAY:
			continue
		for entry: Variant in file["nodes"]:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var node: Dictionary = entry
			if typeof(node.get("id")) == TYPE_STRING:
				ids[str(node["id"])] = true
	return ids


static func _region_ids(regions: Dictionary[String, String],
		regions_known: bool) -> Dictionary[String, bool]:
	var ids: Dictionary[String, bool] = {}
	if not regions_known:
		return ids
	for id: String in regions:
		ids[id] = true
	return ids


## Milestone ids, and the per-continent ids a `continent_foothold` milestone
## fires (`<id>_<continent>`, `compute_system.gd`).
static func _milestone_ids(balance_raw: Variant, regions: Dictionary[String, String],
		regions_known: bool) -> Dictionary[String, bool]:
	var ids: Dictionary[String, bool] = {}
	if typeof(balance_raw) != TYPE_DICTIONARY:
		return ids
	var balance: Dictionary = balance_raw
	if typeof(balance.get("milestones")) != TYPE_ARRAY:
		return ids
	for entry: Variant in balance["milestones"]:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var milestone: Dictionary = entry
		if typeof(milestone.get("id")) != TYPE_STRING:
			continue
		var id: String = str(milestone["id"])
		ids[id] = true
		if str(milestone.get("kind", "")) != MilestoneDef.KIND_CONTINENT_FOOTHOLD \
				or not regions_known:
			continue
		for region_id: String in regions:
			ids["%s_%s" % [id, regions[region_id]]] = true
	return ids


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
