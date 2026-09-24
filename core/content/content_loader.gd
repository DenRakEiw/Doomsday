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
const HEADLINES_FILE: String = "headlines.json"
const ASSETS_FILE: String = "assets.json"
const STATUSES_FILE: String = "statuses.json"
const ABILITIES_FILE: String = "abilities.json"
const FACTIONS_FILE: String = "factions.json"
## Optional (`replayability.md` §8.1): a root without it plays the default
## architecture alone.
const ARCHITECTURES_FILE: String = "architectures.json"
const TECH_DIR: String = "tech"
## Every `*.json` below it is one events file (§15); the directory must exist.
const EVENTS_DIR: String = "events"
const TECH_SUFFIX: String = ".json"
## The localisation table, read here as plain rows so that the string check of
## `docs/specs/tech-trees.md` §8.3 works in a `-s` run and in CI, where the
## imported `.translation` resources may not exist.
const STRINGS_FILE: String = "loc/strings.csv"
## Columns of `strings.csv`: the key, then one per language.
const STRINGS_LANGUAGES: int = 2
## Stands in for the root in the errors of `load_from_dicts`.
const MEMORY_LABEL: String = "memory"
## The optional header of a technology file that declares exclusive groups.
const GROUPS_KEY: String = "groups"
## The default minimum count of an `asset` scope: one of them standing there.
const ASSET_SCOPE_MIN: int = 1


## Loads a content root from disk. The result carries either a database or every
## error found in it, never both.
static func load_root(root: String) -> ContentLoadResult:
	var errors: Array[ValidationError] = []
	var balance_raw: Variant = _read(root.path_join(BALANCE_FILE), errors)
	var regions_raw: Variant = _read(root.path_join(REGIONS_FILE), errors)
	var links_raw: Variant = _read(root.path_join(LINKS_FILE), errors)
	var assets_raw: Variant = _read(root.path_join(ASSETS_FILE), errors)
	var statuses_raw: Variant = _read(root.path_join(STATUSES_FILE), errors)
	var abilities_raw: Variant = _read(root.path_join(ABILITIES_FILE), errors)

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

	var event_files: PackedStringArray = []
	var event_raws: Array = []
	var events_root: String = root.path_join(EVENTS_DIR)
	if DirAccess.dir_exists_absolute(events_root):
		var event_names: PackedStringArray = DirAccess.get_files_at(events_root)
		event_names.sort()
		for name: String in event_names:
			if not name.ends_with(TECH_SUFFIX):
				continue
			var path: String = events_root.path_join(name)
			event_files.append(path)
			event_raws.append(_read(path, errors))
	else:
		errors.append(ValidationError.new(events_root, "", "directory not found"))

	var factions_raw: Variant = _read(root.path_join(FACTIONS_FILE), errors)
	var headlines_raw: Variant = _read(root.path_join(HEADLINES_FILE), errors)
	var architectures_raw: Variant = null
	if FileAccess.file_exists(root.path_join(ARCHITECTURES_FILE)):
		architectures_raw = _read(root.path_join(ARCHITECTURES_FILE), errors)
	var strings: Dictionary[String, bool] = {}
	var strings_known: bool = _read_strings(root.path_join(STRINGS_FILE), strings)
	return _finish(root, balance_raw, regions_raw, links_raw, assets_raw, statuses_raw,
		abilities_raw, tech_files, tech_raws, event_files, event_raws, factions_raw,
		headlines_raw, strings, strings_known, errors, architectures_raw)


## Loads content that is already parsed — for tests, and for anything that builds
## content in memory. `label` stands in for the root in error paths.
static func load_from_dicts(balance: Dictionary, regions: Dictionary, links: Dictionary,
		assets: Dictionary, statuses: Dictionary, abilities: Dictionary,
		tech_files: Array[Dictionary], events: Array[Dictionary], headlines: Dictionary,
		factions: Dictionary, label: String = MEMORY_LABEL,
		architectures: Variant = null) -> ContentLoadResult:
	var errors: Array[ValidationError] = []
	var names: PackedStringArray = []
	var raws: Array = []
	for i: int in tech_files.size():
		names.append(label.path_join("%s[%d]" % [TECH_DIR, i]))
		raws.append(tech_files[i])
	var event_names: PackedStringArray = []
	var event_raws: Array = []
	for i: int in events.size():
		event_names.append(label.path_join("%s[%d]" % [EVENTS_DIR, i]))
		event_raws.append(events[i])
	# Content built in memory carries no string table, so the string check is
	# skipped rather than reported against a file that does not exist.
	var strings: Dictionary[String, bool] = {}
	return _finish(label, balance, regions, links, assets, statuses, abilities, names, raws,
		event_names, event_raws, factions, headlines, strings, false, errors, architectures)


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
		assets_raw: Variant, statuses_raw: Variant, abilities_raw: Variant,
		tech_files: PackedStringArray, tech_raws: Array,
		event_files: PackedStringArray, event_raws: Array, factions_raw: Variant,
		headlines_raw: Variant, strings: Dictionary[String, bool], strings_known: bool,
		errors: Array[ValidationError], architectures_raw: Variant = null) -> ContentLoadResult:
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
	# Assets before technology: a node's `deploy` and `requires_assets` name a
	# kind, so the kinds have to be checked first.
	SchemaValidator.validate_assets(root.path_join(ASSETS_FILE), assets_raw, strings,
		strings_known, errors)
	# Statuses before technology and abilities: an eligibility rule and an
	# ability's `applies` both name one, and §15's order is what keeps every
	# cross-reference pointing at something already checked.
	var statuses: Dictionary[String, int] = SchemaValidator.validate_statuses(
		root.path_join(STATUSES_FILE), statuses_raw, strings, strings_known, errors)
	var statuses_known: bool = typeof(statuses_raw) == TYPE_DICTIONARY
	SchemaValidator.validate_tech(tech_files, tech_raws, regions, regions_known, statuses,
		statuses_known, strings, strings_known, errors)
	SchemaValidator.validate_abilities(root.path_join(ABILITIES_FILE), abilities_raw, regions,
		regions_known, statuses, statuses_known, tech_raws, strings, strings_known, errors)
	var abilities: Dictionary[String, bool] = _ability_ids(abilities_raw)
	# Events after abilities: an option may require one. They answer event id →
	# its option ids, which is what a headline's `def` and `option` filters name.
	var events: Dictionary[String, Array] = SchemaValidator.validate_events(event_files,
		event_raws, regions, regions_known, statuses_raw, statuses, statuses_known, tech_raws,
		abilities, strings, strings_known, errors)
	# Factions after events: a move names a counter-move event (opposition.md
	# §12.1).
	SchemaValidator.validate_factions(root.path_join(FACTIONS_FILE), factions_raw, event_raws,
		strings, strings_known, errors)
	# Headlines last: they name regions, nodes and balance values, so everything
	# they point at has been checked by the time they are.
	SchemaValidator.validate_headlines(root.path_join(HEADLINES_FILE), headlines_raw, balance_raw,
		regions, regions_known, tech_raws, statuses, abilities, events, strings, strings_known,
		errors)
	# Architectures after technology and abilities: a start owns nodes and an
	# architecture grants abilities (`replayability.md` §8.1).
	SchemaValidator.validate_architectures(root.path_join(ARCHITECTURES_FILE), architectures_raw,
		regions, regions_known, statuses, statuses_known, tech_raws, abilities, strings,
		strings_known, errors)

	var result: ContentLoadResult = ContentLoadResult.new()
	result.errors = errors
	if errors.is_empty():
		result.db = _build(balance_raw, regions_raw, links_raw, assets_raw, statuses_raw,
			abilities_raw, tech_raws, event_raws, factions_raw, headlines_raw, architectures_raw)
	return result


## The ability ids of a raw `abilities.json`, for the headline filters that name
## one (`loop-content.md` §9.3). Read from the raw file rather than the database,
## because the headlines are validated before anything is built.
static func _ability_ids(raw: Variant) -> Dictionary[String, bool]:
	var ids: Dictionary[String, bool] = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return ids
	var d: Dictionary = raw
	if typeof(d.get(AbilityDef.ROOT_KEY)) != TYPE_ARRAY:
		return ids
	for entry: Variant in d[AbilityDef.ROOT_KEY]:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var id: String = str((entry as Dictionary).get("id", ""))
		if not id.is_empty():
			ids[id] = true
	return ids


# -------------------------------------------------------------------- building


## Everything below runs on validated data only: the fields are there, they have
## the right types and every reference resolves.
static func _build(balance_raw: Dictionary, regions_raw: Dictionary, links_raw: Dictionary,
		assets_raw: Dictionary, statuses_raw: Dictionary, abilities_raw: Dictionary,
		tech_raws: Array, event_raws: Array, factions_raw: Dictionary,
		headlines_raw: Dictionary, architectures_raw: Variant) -> ContentDB:
	var db: ContentDB = ContentDB.new()
	db.balance = _build_balance(balance_raw)
	_build_regions(db, regions_raw)
	_build_links(db, links_raw)
	_build_assets(db, assets_raw)
	_build_statuses(db, statuses_raw)
	_build_abilities(db, abilities_raw)
	_build_tech(db, tech_raws)
	_build_events(db, event_raws)
	_build_factions(db, factions_raw)
	_build_headlines(db, headlines_raw)
	_build_architectures(db, architectures_raw)
	db.content_hash = _content_hash(balance_raw, regions_raw, links_raw, assets_raw, statuses_raw,
		abilities_raw, tech_raws, event_raws, factions_raw, headlines_raw, architectures_raw)
	return db


## `architectures.json` in file order, or the default architecture alone.
static func _build_architectures(db: ContentDB, raw: Variant) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		var fallback: ArchitectureDef = ArchitectureDef.default_def()
		db.architectures.append(fallback)
		db.architecture_by_id[fallback.id] = fallback
		return
	var list: Array = (raw as Dictionary)[ArchitectureDef.ROOT_KEY]
	for entry: Variant in list:
		var a: Dictionary = entry
		var def: ArchitectureDef = ArchitectureDef.new()
		def.id = str(a["id"])
		def.unlock = (a.get("unlock", {}) as Dictionary).duplicate(true)
		for modifier: Variant in a.get("modifiers", []):
			def.modifiers.append(_build_modifier(db, modifier))
		var start: Dictionary = a.get("start", {})
		def.start_owned = _string_array(start, "owned")
		var assets: Dictionary = start.get("assets", {})
		for kind: Variant in assets:
			def.start_assets[str(kind)] = int(assets[kind])
		def.start_seed_top_hardware = int(start.get("seed_top_hardware", 0))
		_build_effects(def.start_effects, start, "effects")
		def.abilities = _string_array(a, "abilities")
		def.hook = str(a.get("hook", ""))
		db.architectures.append(def)
		db.architecture_by_id[def.id] = def


## `statuses.json` in file order. A level's modifiers stay unscoped here: the
## scope is injected when the status is applied (§7.3).
static func _build_statuses(db: ContentDB, raw: Dictionary) -> void:
	var list: Array = raw[StatusDef.ROOT_KEY]
	for entry: Variant in list:
		var s: Dictionary = entry
		var def: StatusDef = StatusDef.new()
		def.id = str(s["id"])
		def.origin = str(s["origin"])
		def.watched_by = _string_array(s, "watched_by")
		def.border = bool(s.get("border", false))
		def.blocks = _string_array(s, "blocks")
		def.cancellable = bool(s.get("cancellable", false))
		var levels: Array = s["levels"]
		for level_entry: Variant in levels:
			def.levels.append(_build_status_level(db, level_entry))
		db.statuses.append(def)
		db.status_by_id[def.id] = def


static func _build_status_level(db: ContentDB, raw: Variant) -> StatusLevelDef:
	var l: Dictionary = raw
	var level: StatusLevelDef = StatusLevelDef.new()
	level.days = int(l["days"])
	level.closes_links = _string_array(l, "closes_links")
	level.ends_statuses = _string_array(l, "ends_statuses")
	if l.has("modifiers"):
		var modifiers: Array = l["modifiers"]
		for modifier: Variant in modifiers:
			level.modifiers.append(_build_modifier(db, modifier))
	_build_effects(level.on_start, l, "on_start")
	_build_effects(level.on_end, l, "on_end")
	return level


static func _build_effects(into: Array[EffectDef], d: Dictionary, key: String) -> void:
	if not d.has(key):
		return
	var effects: Array = d[key]
	for effect: Variant in effects:
		into.append(EffectDef.from_dict(effect))


## `abilities.json` in file order, which is the order the region panel and the
## picker list them in (§16.5, §16.10).
static func _build_abilities(db: ContentDB, raw: Dictionary) -> void:
	var list: Array = raw[AbilityDef.ROOT_KEY]
	for entry: Variant in list:
		var a: Dictionary = entry
		var def: AbilityDef = AbilityDef.new()
		def.id = str(a["id"])
		def.target = str(a["target"])
		def.cost = float(a["cost"])
		def.cooldown_days = int(a["cooldown_days"])
		def.eligible = Eligibility.from_dict(a.get("eligible", {}))
		def.levels_from = _string_array(a, "levels_from")
		def.level_cap = int(a.get("level_cap", 0))
		var applies: Dictionary = a["applies"]
		if applies.has(AbilityDef.APPLIES_STATUS):
			def.applies_kind = AbilityDef.APPLIES_STATUS
			def.applies_status = str(applies[AbilityDef.APPLIES_STATUS])
		elif applies.has(AbilityDef.APPLIES_DEPLOY):
			def.applies_kind = AbilityDef.APPLIES_DEPLOY
			var deploy: Dictionary = applies[AbilityDef.APPLIES_DEPLOY]
			def.applies_deploy_kind = str(deploy["kind"])
			def.applies_deploy_count = int(deploy["count"])
		else:
			def.applies_kind = AbilityDef.APPLIES_EFFECTS
			_build_effects(def.applies_effects, applies, AbilityDef.APPLIES_EFFECTS)
		db.abilities.append(def)
		db.ability_by_id[def.id] = def


## The four asset kinds, in `AssetDef.KINDS` order whatever order the file uses.
## Every modifier is scoped `{"asset": kind}` here rather than in the file: the
## scope is what the kind *means*, not something an author chooses (§6.1).
static func _build_assets(db: ContentDB, raw: Dictionary) -> void:
	var by_kind: Dictionary[String, Dictionary] = {}
	var list: Array = raw[AssetDef.ROOT_KEY]
	for entry: Variant in list:
		var a: Dictionary = entry
		by_kind[str(a["kind"])] = a
	for kind: String in AssetDef.KINDS:
		var a: Dictionary = by_kind[kind]
		var def: AssetDef = AssetDef.new()
		def.kind = kind
		def.glyph = str(a["glyph"])
		def.watched_by = _string_array(a, "watched_by")
		var modifiers: Array = a["modifiers"]
		for modifier: Variant in modifiers:
			def.modifiers.append(_build_modifier(db, modifier, kind))
		db.assets[kind] = def


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
		if file.has(GROUPS_KEY):
			var groups: Dictionary = file[GROUPS_KEY]
			for group: String in groups:
				var declaration: Dictionary = groups[group]
				db.groups[group] = int(declaration["max"])
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
					def.on_purchase.append(EffectDef.from_dict(effect))
			_build_tech_v3(def, n)
			db.tech_nodes.append(def)
			db.tech_by_id[def.id] = def


## Tree v3's five fields (§11.1). Each is optional; a node without them is the
## node it always was.
static func _build_tech_v3(def: TechNodeDef, n: Dictionary) -> void:
	def.group = str(n.get("group", ""))
	def.excludes = _string_array(n, "excludes")
	if n.has("deploy"):
		var deploy: Dictionary = n["deploy"]
		def.deploy_kind = str(deploy["kind"])
		def.deploy_count = int(deploy["count"])
		def.deploy_eligible = Eligibility.from_dict(deploy.get("eligible", {}))
	if n.has("ability"):
		var ability: Dictionary = n["ability"]
		def.ability_id = str(ability["id"])
		def.ability_level = int(ability["level"])
	if n.has("requires_assets"):
		var needed: Dictionary = n["requires_assets"]
		for kind: String in needed:
			def.requires_assets[kind] = int(needed[kind])


## Every events file in name order, each event in file order (§10.1). The
## `pick` forms become three fields, so the system never reads raw JSON.
static func _build_events(db: ContentDB, event_raws: Array) -> void:
	for raw: Variant in event_raws:
		var file: Dictionary = raw
		var list: Array = file[EventDef.ROOT_KEY]
		for entry: Variant in list:
			var def: EventDef = _build_event(entry)
			db.events.append(def)
			db.event_by_id[def.id] = def


static func _build_event(raw: Variant) -> EventDef:
	var e: Dictionary = raw
	var def: EventDef = EventDef.new()
	def.id = str(e["id"])
	def.kind = str(e["kind"])
	def.chain = str(e.get("chain", ""))
	def.start = bool(e.get("start", false))
	if e.has("pick"):
		var pick: Variant = e["pick"]
		if typeof(pick) == TYPE_STRING:
			def.pick_same = true
		elif (pick as Dictionary).has(EventDef.PICK_RULE_KEY):
			def.pick_rule = str((pick as Dictionary)[EventDef.PICK_RULE_KEY])
		else:
			def.pick = Eligibility.from_dict(pick)
	def.pick_weight = str(e.get("pick_weight", EventDef.PICK_WEIGHT_UNIFORM))
	if e.has("when"):
		def.when = HeadlineConditions.cast_when(e["when"])
	def.weight = float(e.get("weight", 1.0))
	# A chain step happens once unless the data says otherwise (§10.1).
	var default_fires: int = 1 if def.kind == EventDef.KIND_CHAIN else 0
	def.max_fires = int(e.get("max_fires", default_fires))
	def.cooldown_days = int(e.get("cooldown_days", 0))
	def.deadline_days = int(e["deadline_days"])
	def.default_option = str(e["default"])
	def.modal = bool(e.get("modal", false))
	def.illustration = str(e.get("illustration", ""))
	def.status = str(e.get("status", ""))
	def.faction = str(e.get("faction", ""))
	def.flags = _string_array(e, "flags")
	var options: Array = e["options"]
	for option: Variant in options:
		def.options.append(_build_event_option(option))
	return def


static func _build_event_option(raw: Variant) -> EventOptionDef:
	var o: Dictionary = raw
	var def: EventOptionDef = EventOptionDef.new()
	def.id = str(o["id"])
	def.cost = float(o.get("cost", 0.0))
	if o.has("requires"):
		var r: Dictionary = o["requires"]
		def.requires_owned = _string_array(r, "owned")
		def.requires_owned_any = _string_array(r, "owned_any")
		def.requires_not_owned = _string_array(r, "not_owned")
		def.requires_flag = _string_array(r, "flag")
		if r.has("asset_min"):
			var assets: Dictionary = r["asset_min"]
			for kind: String in assets:
				def.requires_asset_min[kind] = int(assets[kind])
		def.requires_compute_min = float(r.get("compute_min", -1.0))
		def.requires_ability = str(r.get("ability", ""))
	_build_effects(def.effects, o, "effects")
	if o.has("chance"):
		var rolls: Array = o["chance"]
		for roll: Variant in rolls:
			var c: Dictionary = roll
			var chance: EventChanceDef = EventChanceDef.new()
			chance.p = float(c["p"])
			_build_effects(chance.effects, c, "effects")
			chance.has_next = c.has("next")
			chance.next = _build_next(c)
			def.chance.append(chance)
	def.flags = _string_array(o, "flags")
	def.status_level = int(o.get("status_level", 0))
	def.status_days = int(o.get("status_days", 0))
	def.skip_status = bool(o.get("skip_status", false))
	def.next = _build_next(o)
	return def


## `[{"step", "delay_days"}]`, typed; an absent `next` is an empty one.
static func _build_next(d: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not d.has("next"):
		return out
	var list: Array = d["next"]
	for entry: Variant in list:
		var n: Dictionary = entry
		out.append({"step": str(n["step"]), "delay_days": int(n.get("delay_days", 0))})
	return out


## `factions.json` in file order, which the validator has made
## `Faction.FACTION_IDS` order (opposition.md §4).
static func _build_factions(db: ContentDB, raw: Dictionary) -> void:
	var list: Array = raw[FactionDef.ROOT_KEY]
	for entry: Variant in list:
		var f: Dictionary = entry
		var def: FactionDef = FactionDef.new()
		def.id = str(f["id"])
		def.capacity_attr = str(f["capacity_attr"])
		def.brake = str(f["brake"])
		var terms: Array = f["terms"]
		for raw_term: Variant in terms:
			var t: Dictionary = raw_term
			var term: FactionTermDef = FactionTermDef.new()
			term.source = str(t["source"])
			term.weight = float(t["weight"])
			term.tree = str(t.get("tree", ""))
			term.kind = str(t.get("kind", ""))
			def.terms.append(term)
		var moves: Array = f.get("moves", [])
		for raw_move: Variant in moves:
			var m: Dictionary = raw_move
			var move: FactionMoveDef = FactionMoveDef.new()
			move.event = str(m["event"])
			var trigger: Dictionary = m["trigger"]
			if trigger.has("containment"):
				move.trigger_containment = float(trigger["containment"])
			if trigger.has("risk"):
				move.trigger_risk = float(trigger["risk"])
			if m.has("variants"):
				var variants: Dictionary = m["variants"]
				move.variants_select = str(variants["select"])
				var events: Dictionary = variants["events"]
				for key: Variant in events:
					move.variants[str(key)] = str(events[key])
			def.moves.append(move)
		db.factions.append(def)
		db.faction_by_id[def.id] = def


## `headlines.json` in file order (ticker.md §3.2). The trigger blocks are
## flattened into typed fields here so that the evaluator never reads raw JSON.
static func _build_headlines(db: ContentDB, raw: Dictionary) -> void:
	var list: Array = raw["headlines"]
	for entry: Variant in list:
		var h: Dictionary = entry
		var def: HeadlineDef = HeadlineDef.new()
		def.id = str(h["id"])
		def.stream = str(h["stream"])
		def.register = str(h.get("register", HeadlineDef.REGISTER_ANY))
		def.weight = float(h.get("weight", 1.0))
		def.chance = float(h.get("chance", 1.0))
		def.cooldown_days = int(h.get("cooldown_days", 0))
		def.max_fires = int(h.get("max_fires", 0))
		def.fallback = bool(h.get("fallback", false))
		if h.has("on"):
			_build_headline_trigger(def, h["on"])
		if h.has("when"):
			_build_headline_state(def, h["when"])
		db.headlines.append(def)
		db.headline_by_id[def.id] = def


static func _build_headline_trigger(def: HeadlineDef, raw: Variant) -> void:
	var on: Dictionary = raw
	def.on_event = str(on["event"])
	def.on_node_tree = str(on.get("node_tree", ""))
	def.on_node_tier = int(on.get("node_tier", 0))
	if on.has("data"):
		var data: Dictionary = on["data"]
		for field: String in data:
			# A scalar is a one-element list, so the evaluator has one shape.
			var listed: bool = typeof(data[field]) == TYPE_ARRAY
			var accepted: Array = data[field] if listed else [data[field]]
			def.on_data[field] = accepted
	_build_headline_attrs(def.on_region_attr_min, on, "region_attr_min")
	_build_headline_attrs(def.on_region_attr_max, on, "region_attr_max")


static func _build_headline_attrs(into: Dictionary[String, int], on: Dictionary,
		key: String) -> void:
	if not on.has(key):
		return
	var attributes: Dictionary = on[key]
	for attribute: String in attributes:
		into[attribute] = int(attributes[attribute])


## The `when` keys, each cast to what its row of §3.3 B says it is.
static func _build_headline_state(def: HeadlineDef, raw: Variant) -> void:
	def.when = HeadlineConditions.cast_when(raw)


static func _string_list(raw: Array) -> Array[String]:
	var out: Array[String] = []
	for entry: Variant in raw:
		out.append(str(entry))
	return out


## `force_asset` is the kind an `assets.json` modifier is scoped to; the file
## itself carries no scope there, and one in it is a validation error (§6.1).
static func _build_modifier(db: ContentDB, raw: Variant,
		force_asset: String = "") -> ModifierDef:
	var m: Dictionary = raw
	var def: ModifierDef = ModifierDef.new()
	def.target = str(m["target"])
	def.op = ModifierDef.op_from_name(str(m["op"]))
	def.value = float(m["value"])
	if not force_asset.is_empty():
		def.scope_kind = ModifierDef.ScopeKind.ASSET
		def.scope_asset = force_asset
		def.scope_min = ASSET_SCOPE_MIN
		return def
	if not m.has("scope"):
		def.scope_kind = ModifierDef.ScopeKind.NONE
		return def

	var scope: Dictionary = m["scope"]
	if scope.has("asset"):
		def.scope_kind = ModifierDef.ScopeKind.ASSET
		def.scope_asset = str(scope["asset"])
		def.scope_min = int(scope.get("min", ASSET_SCOPE_MIN))
	elif scope.has("attr"):
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
		assets: Dictionary, statuses: Dictionary, abilities: Dictionary, tech_raws: Array,
		event_raws: Array, factions: Dictionary, headlines: Dictionary,
		architectures: Variant = null) -> String:
	var text: String = JSON.stringify(balance, "", true, true)
	text += JSON.stringify(regions, "", true, true)
	text += JSON.stringify(links, "", true, true)
	text += JSON.stringify(assets, "", true, true)
	text += JSON.stringify(statuses, "", true, true)
	text += JSON.stringify(abilities, "", true, true)
	for raw: Variant in tech_raws:
		text += JSON.stringify(raw, "", true, true)
	for raw: Variant in event_raws:
		text += JSON.stringify(raw, "", true, true)
	text += JSON.stringify(factions, "", true, true)
	text += JSON.stringify(headlines, "", true, true)
	# Only when there is a file: a root without one hashes as it always did.
	if typeof(architectures) == TYPE_DICTIONARY:
		text += JSON.stringify(architectures, "", true, true)
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
	def.containment_brake_floor = float(containment["brake_floor"])
	var weights: Array = containment["capacity_weight_by_tier"]
	for weight: Variant in weights:
		def.containment_capacity_weight_by_tier.append(float(weight))
	var thresholds: Array = containment["thresholds"]
	for threshold: Variant in thresholds:
		def.containment_thresholds.append(float(threshold))

	var factions: Dictionary = d["factions"]
	def.factions_prepare_days = int(factions["prepare_days"])
	def.factions_prepare_min_days = int(factions["prepare_min_days"])
	def.factions_cooldown_days = int(factions["cooldown_days"])
	def.factions_max_active_moves = int(factions["max_active_moves"])
	var level_thresholds: Array = factions["level_thresholds"]
	for threshold: Variant in level_thresholds:
		def.factions_level_thresholds.append(float(threshold))
	def.factions_reset_days = int(factions["reset_days"])
	def.factions_protest_deaths_share = float(factions["protest_deaths_share"])

	var society: Dictionary = d["society"]
	var stage_thresholds: Array = society["stage_thresholds"]
	for threshold: Variant in stage_thresholds:
		def.society_stage_thresholds.append(float(threshold))
	def.society_gain_scale = float(society["gain_scale"])
	def.society_recovery_per_day = float(society["recovery_per_day"])
	def.society_deaths_weight = float(society["deaths_weight"])
	var stages: Array = society["stages"]
	for raw_stage: Variant in stages:
		var stage: Dictionary = raw_stage
		def.society_stages.append({
			"capacity_mul": float(stage["capacity_mul"]),
			"yield_mul": float(stage["yield_mul"]),
		})
	def.society_autophagy_days = int(society["autophagy_days"])

	var phase: Dictionary = d["phase"]
	def.phase_open_containment = float(phase["open_containment"])
	def.phase_open_world_share = float(phase["open_world_share"])

	var headlines: Dictionary = d["headlines"]
	def.headlines_max_per_tick = int(headlines["max_per_tick"])
	def.headlines_max_per_command = int(headlines["max_per_command"])
	def.headlines_reaction_gap_days = int(headlines["reaction_gap_days"])
	var filler: Dictionary = headlines["filler"]
	var gaps: Dictionary = filler["gap_days"]
	for phase_id: String in World.PHASE_IDS:
		def.headlines_filler_gap_days[phase_id] = float(gaps[phase_id])
	def.headlines_filler_per_dark_region = float(filler["per_dark_region"])
	def.headlines_filler_silence_dark = int(filler["silence_dark_regions"])
	def.headlines_filler_silence_deaths_share = float(filler["silence_deaths_share"])

	var results: Dictionary = d["results"]
	def.results_ashes_share = float(results["ashes_share"])

	var history: Dictionary = d["history"]
	def.history_interval_days = int(history["interval_days"])
	def.history_max_samples = int(history["max_samples"])
	def.history_log_max = int(history["log_max"])

	var events: Dictionary = d["events"]
	var chances: Dictionary = events["opening_chance"]
	for phase_id: String in World.PHASE_IDS:
		def.events_opening_chance[phase_id] = float(chances[phase_id])
	def.events_opening_from_regions = int(events["opening_from_regions"])
	def.events_max_open = int(events["max_open"])
	return def
