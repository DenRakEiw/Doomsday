class_name ContentLoader
extends RefCounted
## Reads a content root into a `ContentDB`, or into the list of everything that
## is wrong with it.
##
## Content is plain JSON read through `FileAccess` — never `load()` and never
## `ResourceLoader`, because a `.tres` from a save directory or a mod folder is
## executable and this path must stay safe for data we did not write.
##
## A root has the shape `data/SCHEMA.md` §1 gives: `balance.json`,
## `world/regions.json`, `world/links.json` and any number of `tech/*.json`,
## which are read in ascending file-name order. The test fixtures are roots of
## the same shape, which is what makes them interchangeable with `res://data`.

const BALANCE_FILE: String = "balance.json"
const REGIONS_FILE: String = "world/regions.json"
const LINKS_FILE: String = "world/links.json"
const TECH_DIR: String = "tech"
const TECH_SUFFIX: String = ".json"
## The localisation table, read here as plain rows so that the string check of
## `docs/specs/tech-trees.md` §8.3 works in a `-s` run and in CI, where the
## imported `.translation` resources may not exist.
const STRINGS_FILE: String = "loc/strings.csv"
## Columns of `strings.csv`: the key, then one per language.
const STRINGS_LANGUAGES: int = 2
## Stands in for the root in the errors of `load_from_dicts`.
const MEMORY_LABEL: String = "memory"


## Loads a content root from disk. The result carries either a database or every
## error found in it, never both.
static func load_root(root: String) -> ContentLoadResult:
	var errors: Array[ValidationError] = []
	var balance_raw: Variant = _read(root.path_join(BALANCE_FILE), errors)
	var regions_raw: Variant = _read(root.path_join(REGIONS_FILE), errors)
	var links_raw: Variant = _read(root.path_join(LINKS_FILE), errors)

	var tech_files: PackedStringArray = []
	var tech_raws: Array = []
	var tech_root: String = root.path_join(TECH_DIR)
	# A root may have no technology at all. The existence check is not optional:
	# `get_files_at` pushes an engine error for a directory that is not there.
	var names: PackedStringArray = []
	if DirAccess.dir_exists_absolute(tech_root):
		names = DirAccess.get_files_at(tech_root)
	names.sort()
	for name: String in names:
		if not name.ends_with(TECH_SUFFIX):
			continue
		var path: String = tech_root.path_join(name)
		tech_files.append(path)
		tech_raws.append(_read(path, errors))

	var strings: Dictionary[String, bool] = {}
	var strings_known: bool = _read_strings(root.path_join(STRINGS_FILE), strings)
	return _finish(root, balance_raw, regions_raw, links_raw, tech_files, tech_raws, strings,
		strings_known, errors)


## Loads content that is already parsed — for tests, and for anything that builds
## content in memory. `label` stands in for the root in error paths.
static func load_from_dicts(balance: Dictionary, regions: Dictionary, links: Dictionary,
		tech_files: Array[Dictionary], label: String = MEMORY_LABEL) -> ContentLoadResult:
	var errors: Array[ValidationError] = []
	var names: PackedStringArray = []
	var raws: Array = []
	for i: int in tech_files.size():
		names.append(label.path_join("%s[%d]" % [TECH_DIR, i]))
		raws.append(tech_files[i])
	# Content built in memory carries no string table, so the string check is
	# skipped rather than reported against a file that does not exist.
	var strings: Dictionary[String, bool] = {}
	return _finish(label, balance, regions, links, names, raws, strings, false, errors)


# --------------------------------------------------------------------- reading


## The parsed object at `path`, or null after reporting why there is none.
static func _read(path: String, errors: Array[ValidationError]) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append(ValidationError.new(path, "", "file not found"))
		return null
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		var open_error: int = FileAccess.get_open_error()
		if open_error != OK:
			errors.append(ValidationError.new(path, "",
				"cannot read file: %s" % error_string(open_error)))
		else:
			errors.append(ValidationError.new(path, "", "file is empty"))
		return null

	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		# get_error_line() counts from 0; editors and people count from 1.
		errors.append(ValidationError.new(path, "line %d" % (json.get_error_line() + 1),
			json.get_error_message()))
		return null
	if typeof(json.data) != TYPE_DICTIONARY:
		errors.append(ValidationError.new(path, "",
			"top level must be an object, found %s" % type_string(typeof(json.data))))
		return null
	return json.data


## Keys whose `en` and `de` cells are both non-empty, and whether the table was
## there at all. A root without one — every test fixture — is not an error: the
## fixtures deliberately have no strings (`data/SCHEMA.md` §6).
static func _read_strings(path: String, into: Dictionary[String, bool]) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	# The header is a row like any other; a key named "keys" is not a real one.
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() < 1 + STRINGS_LANGUAGES or row[0].is_empty():
			continue
		if row[1].strip_edges().is_empty() or row[2].strip_edges().is_empty():
			continue
		into[row[0]] = true
	return true


static func _finish(root: String, balance_raw: Variant, regions_raw: Variant, links_raw: Variant,
		tech_files: PackedStringArray, tech_raws: Array, strings: Dictionary[String, bool],
		strings_known: bool, errors: Array[ValidationError]) -> ContentLoadResult:
	# The order is SCHEMA's: balance, regions, links, technology, and the
	# cross-file checks inside the validators that need an earlier file.
	SchemaValidator.validate_balance(root.path_join(BALANCE_FILE), balance_raw, errors)
	var regions: Dictionary[String, String] = SchemaValidator.validate_regions(
		root.path_join(REGIONS_FILE), regions_raw, errors)
	# Without a parsed regions.json every reference would look dangling, so the
	# cross-references are skipped rather than reported against a file we do not
	# have. A broken *entry* still costs only itself: it is simply not in the map.
	var regions_known: bool = typeof(regions_raw) == TYPE_DICTIONARY
	SchemaValidator.validate_links(root.path_join(LINKS_FILE), links_raw, regions, regions_known,
		errors)
	SchemaValidator.validate_tech(tech_files, tech_raws, regions, regions_known, strings,
		strings_known, errors)

	var result: ContentLoadResult = ContentLoadResult.new()
	result.errors = errors
	if errors.is_empty():
		result.db = _build(balance_raw, regions_raw, links_raw, tech_raws)
	return result


# -------------------------------------------------------------------- building


## Everything below runs on validated data only: the fields are there, they have
## the right types and every reference resolves.
static func _build(balance_raw: Dictionary, regions_raw: Dictionary, links_raw: Dictionary,
		tech_raws: Array) -> ContentDB:
	var db: ContentDB = ContentDB.new()
	db.balance = _build_balance(balance_raw)
	_build_regions(db, regions_raw)
	_build_links(db, links_raw)
	_build_tech(db, tech_raws)
	db.content_hash = _content_hash(balance_raw, regions_raw, links_raw, tech_raws)
	return db


static func _build_regions(db: ContentDB, raw: Dictionary) -> void:
	var list: Array = raw["regions"]
	# Index 0 stays null so that a forgotten `range(1, …)` crashes loudly.
	db.regions.resize(list.size() + 1)
	for entry: Variant in list:
		var r: Dictionary = entry
		var def: RegionDef = RegionDef.new()
		def.index = int(r["index"])
		def.id = str(r["id"])
		def.continent = str(r["continent"])
		def.population = int(r["population"])
		def.air_gapped = bool(r.get("air_gapped", false))
		var anchor: Array = r["anchor"]
		def.anchor = Vector2i(int(anchor[0]), int(anchor[1]))

		var attributes: Dictionary = r["attributes"]
		for attribute: String in RegionDef.ATTRIBUTES:
			def.attributes[attribute] = int(attributes[attribute])
		def.attributes[RegionDef.ATTRIBUTE_POPULATION] = _population_tier(def.population,
			db.balance.population_tiers)

		db.regions[def.index] = def
		db.region_index_by_id[def.id] = def.index
		db.population_total += float(def.population)


## How many thresholds a population reaches, 0…4. The thresholds ascend, so
## counting them is the tier.
static func _population_tier(population: int, thresholds: Array[int]) -> int:
	var tier: int = 0
	for threshold: int in thresholds:
		if population >= threshold:
			tier += 1
	return tier


static func _build_links(db: ContentDB, raw: Dictionary) -> void:
	var list: Array = raw["links"]
	for entry: Variant in list:
		var l: Dictionary = entry
		var def: LinkDef = LinkDef.new()
		var a_id: String = str(l["a"])
		var b_id: String = str(l["b"])
		def.kind = str(l["kind"])
		def.id = LinkDef.derive_id(a_id, b_id, def.kind)
		def.a = db.region_index_by_id[a_id]
		def.b = db.region_index_by_id[b_id]
		db.links.append(def)


static func _build_tech(db: ContentDB, tech_raws: Array) -> void:
	for raw: Variant in tech_raws:
		var file: Dictionary = raw
		var list: Array = file["nodes"]
		for entry: Variant in list:
			var n: Dictionary = entry
			var def: TechNodeDef = TechNodeDef.new()
			def.id = str(n["id"])
			def.tree = str(n["tree"])
			def.tier = int(n["tier"])
			def.cost = int(n["cost"])
			def.requires = _string_array(n, "requires")
			def.requires_any = _string_array(n, "requires_any")
			def.flags = _string_array(n, "flags")
			def.watched_by = _string_array(n, "watched_by")
			var grid: Array = n["grid"]
			def.grid = Vector2i(int(grid[0]), int(grid[1]))
			if n.has("modifiers"):
				var modifiers: Array = n["modifiers"]
				for modifier: Variant in modifiers:
					def.modifiers.append(_build_modifier(db, modifier))
			if n.has("on_purchase"):
				var effects: Array = n["on_purchase"]
				for effect: Variant in effects:
					def.on_purchase.append(_build_effect(effect))
			db.tech_nodes.append(def)
			db.tech_by_id[def.id] = def


static func _build_effect(raw: Variant) -> PurchaseEffectDef:
	var e: Dictionary = raw
	var def: PurchaseEffectDef = PurchaseEffectDef.new()
	def.effect = str(e["effect"])
	def.value = float(e["value"])
	return def


static func _build_modifier(db: ContentDB, raw: Variant) -> ModifierDef:
	var m: Dictionary = raw
	var def: ModifierDef = ModifierDef.new()
	def.target = str(m["target"])
	def.op = ModifierDef.op_from_name(str(m["op"]))
	def.value = float(m["value"])
	if not m.has("scope"):
		def.scope_kind = ModifierDef.ScopeKind.NONE
		return def

	var scope: Dictionary = m["scope"]
	if scope.has("attr"):
		def.scope_kind = ModifierDef.ScopeKind.ATTR
		def.scope_attr = str(scope["attr"])
		def.scope_min = int(scope.get("min", RegionDef.TIER_MIN))
		def.scope_max = int(scope.get("max", RegionDef.TIER_MAX))
	elif scope.has("region"):
		def.scope_kind = ModifierDef.ScopeKind.REGION
		# Scopes hold the region index, not the id: the comparison in `matches`
		# then costs nothing and the id appears in exactly one place.
		def.scope_region = db.region_index_by_id[str(scope["region"])]
	else:
		def.scope_kind = ModifierDef.ScopeKind.CONTINENT
		def.scope_continent = str(scope["continent"])
	return def


static func _string_array(d: Dictionary, key: String) -> Array[String]:
	var out: Array[String] = []
	if not d.has(key):
		return out
	var list: Array = d[key]
	for entry: Variant in list:
		out.append(str(entry))
	return out


## SHA-256 over the parsed content, not over the bytes: whitespace, indentation
## and key order therefore do not change it, while any value does. A save
## carrying a different hash would not replay on this content.
static func _content_hash(balance: Dictionary, regions: Dictionary, links: Dictionary,
		tech_raws: Array) -> String:
	var text: String = JSON.stringify(balance, "", true, true)
	text += JSON.stringify(regions, "", true, true)
	text += JSON.stringify(links, "", true, true)
	for raw: Variant in tech_raws:
		text += JSON.stringify(raw, "", true, true)
	return text.sha256_text()


static func _build_balance(d: Dictionary) -> BalanceDef:
	var def: BalanceDef = BalanceDef.new()
	var stats: Dictionary = d["stats"]
	for target: String in ModifierDef.TARGETS_ALL:
		def.stats[target] = float(stats[target])
	var tiers: Array = d["population_tiers"]
	for threshold: Variant in tiers:
		def.population_tiers.append(int(threshold))

	var spread: Dictionary = d["spread"]
	def.spread_base_growth = float(spread["base_growth"])
	def.spread_origin_penetration = float(spread["origin_penetration"])
	def.spread_seed_penetration = float(spread["seed_penetration"])
	def.spread_saturation_snap = float(spread["saturation_snap"])
	var seed_chance: Dictionary = spread["seed_chance"]
	for kind: String in LinkDef.KINDS:
		def.spread_seed_chance[kind] = float(seed_chance[kind])

	var control: Dictionary = d["control"]
	def.control_threshold = float(control["threshold"])
	def.control_rate = float(control["rate"])
	def.control_complete = float(control["complete"])

	var compute: Dictionary = d["compute"]
	def.compute_start = float(compute["start"])
	def.compute_yield_scale = float(compute["yield_scale"])
	def.compute_cost_step = float(compute["cost_step"])
	var hardware: Array = compute["hardware_by_tier"]
	for weight: Variant in hardware:
		def.compute_hardware_by_tier.append(float(weight))

	var anomaly: Dictionary = d["anomaly"]
	def.anomaly_spawn_chance = float(anomaly["spawn_chance"])
	def.anomaly_max_active = int(anomaly["max_active"])
	def.anomaly_lifetime_days = int(anomaly["lifetime_days"])
	def.anomaly_base_value = float(anomaly["base_value"])
	def.anomaly_tier_bonus = float(anomaly["tier_bonus"])
	def.anomaly_footprint_bonus = float(anomaly["footprint_bonus"])
	def.anomaly_footprint_reference = float(anomaly["footprint_reference"])

	var milestones: Array = d["milestones"]
	for entry: Variant in milestones:
		var m: Dictionary = entry
		var milestone: MilestoneDef = MilestoneDef.new()
		milestone.id = str(m["id"])
		milestone.kind = str(m["kind"])
		milestone.threshold = float(m["threshold"])
		milestone.reward = float(m["reward"])
		def.milestones.append(milestone)

	var harm: Dictionary = d["harm"]
	def.harm_daily_rate = float(harm["daily_rate"])

	var discovery: Dictionary = d["discovery"]
	def.discovery_scrutiny_per_day = float(discovery["scrutiny_per_day"])
	def.discovery_per_footprint = float(discovery["per_footprint"])
	def.discovery_breadth_rate = float(discovery["breadth_rate"])
	def.discovery_breadth_free = float(discovery["breadth_free"])
	def.discovery_deaths_certain_share = float(discovery["deaths_certain_share"])

	var containment: Dictionary = d["containment"]
	def.containment_base_rate = float(containment["base_rate"])
	def.containment_per_footprint = float(containment["per_footprint"])
	def.containment_per_harm = float(containment["per_harm"])
	def.containment_per_share = float(containment["per_share"])
	var weights: Array = containment["research_weight_by_tier"]
	for weight: Variant in weights:
		def.containment_research_weight_by_tier.append(float(weight))
	var thresholds: Array = containment["thresholds"]
	for threshold: Variant in thresholds:
		def.containment_thresholds.append(float(threshold))

	var phase: Dictionary = d["phase"]
	def.phase_open_containment = float(phase["open_containment"])
	def.phase_open_world_share = float(phase["open_world_share"])

	var history: Dictionary = d["history"]
	def.history_interval_days = int(history["interval_days"])
	return def
