class_name WorldSerializer
extends RefCounted
## Reads and writes a save (core.md §10). Works on strings only: the file itself
## belongs to the `SaveManager` autoload of M2, not to `core/`.
##
## Three JSON traps are handled here, each of which corrupts a save without
## looking like it:
##
##   * JSON has no integers, so every whole number is cast explicitly;
##   * the RNG seed and state are 64-bit and are stored **as strings** — as JSON
##     numbers they lose their low bits and the restored run diverges a few
##     hundred ticks later;
##   * floats are written at full precision, because the default formatting is
##     lossy and breaks save → load → continue.

const FORMAT: String = "doomsday-save"
const CURRENT_VERSION: int = 3
## The project setting the `build` field records.
const VERSION_SETTING: String = "application/config/version"

const REASON_INVALID_JSON: String = "save_invalid_json"
const REASON_WRONG_FORMAT: String = "save_wrong_format"
const REASON_CORRUPT: String = "save_corrupt"
const REASON_FROM_FUTURE: String = "save_from_future"
const REASON_MIGRATION_MISSING: String = "save_migration_missing"
const REASON_CONTENT_MISSING: String = "save_content_missing"
## v1 sampled its history every seven days (analysis.md §3.4).
const V1_HISTORY_STRIDE: int = 7

## The production migration table. Every save older than `CURRENT_VERSION` is
## brought forward here, on the raw dictionary, before anything reads it.
static func migrations() -> Dictionary[int, Callable]:
	var table: Dictionary[int, Callable] = {1: _v1_to_v2, 2: _v2_to_v3}
	return table


## An empty table, for the tests that drive `migrate` themselves.
const NO_MIGRATIONS: Dictionary[int, Callable] = {}


## v1 → v2 (`loop-mechanics.md` §13): every block gains the fields M4 added, at
## the value a world that never had them would carry. It works on the raw
## dictionary and never instantiates a model class.
static func _v1_to_v2(save: Dictionary) -> Dictionary:
	var out: Dictionary = save.duplicate(true)
	if typeof(out.get("world")) != TYPE_DICTIONARY:
		return out
	var world: Dictionary = out["world"]
	var zero: String = FloatBits.to_hex(0.0)
	if typeof(world.get("regions")) == TYPE_ARRAY:
		for entry: Variant in world["regions"]:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var region: Dictionary = entry
			region["assets"] = {}
			region["society"] = zero
	if typeof(world.get("agent")) == TYPE_DICTIONARY:
		var agent: Dictionary = world["agent"]
		agent["cooldowns"] = {}
		agent["timed_flags"] = {}
		agent["story_flags"] = []
		agent["seeds_by_kind"] = {}
	# v1 had one `unified` track; v2 has the four factions, each starting from
	# the value the one track had (opposition.md §3.4).
	if typeof(world.get("factions")) == TYPE_ARRAY:
		var old: Array = world["factions"]
		var containment: Variant = FloatBits.to_hex(0.0)
		if not old.is_empty() and typeof(old[0]) == TYPE_DICTIONARY:
			containment = (old[0] as Dictionary).get("containment", containment)
		var four: Array = []
		for id: String in Faction.FACTION_IDS:
			four.append({
				"id": id,
				"containment": containment,
				"preparing": "",
				"fire_day": -1,
				"cooldown_until": 0,
			})
		world["factions"] = four
	# analysis.md §3.4: v1 sampled every seven days and had no log; each old
	# sample gets the D4.4 fields at the value a world without them carries.
	world["history_stride"] = V1_HISTORY_STRIDE
	world["run_log"] = []
	if typeof(world.get("history")) == TYPE_ARRAY:
		for entry: Variant in world["history"]:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var sample: Dictionary = entry
			var by_faction: Dictionary = {}
			var pressure: Dictionary = {}
			for id: String in Faction.FACTION_IDS:
				by_faction[id] = sample.get("containment", zero)
				pressure[id] = FloatBits.to_hex(1.0)
			sample["containment_by_faction"] = by_faction
			sample["pressure_by_faction"] = pressure
			sample["risk"] = zero
			sample["harm"] = zero
			sample["controlled"] = 0
			sample["dark"] = 0
			var stages: Array = []
			stages.resize(HistorySample.STAGE_COUNT)
			stages.fill(0)
			sample["stage_counts"] = stages
			var kinds: Dictionary = {}
			for kind: String in AssetDef.KINDS:
				kinds[kind] = 0
			sample["assets"] = kinds
			sample["starving_days"] = 0
	world["starving_days"] = 0
	world["statuses"] = []
	world["pulses"] = []
	world["next_pulse_id"] = 1
	world["events"] = []
	world["pending_events"] = []
	world["next_event_id"] = 1
	world["event_fires"] = {}
	world["event_last_day"] = {}
	return out


## v2 → v3 (`replayability.md` §1): the world gains its setup. A run from before
## there were architectures was the default one, with no directives, at standard.
static func _v2_to_v3(save: Dictionary) -> Dictionary:
	var out: Dictionary = save.duplicate(true)
	if typeof(out.get("world")) != TYPE_DICTIONARY:
		return out
	var world: Dictionary = out["world"]
	world["setup"] = RunSetup.new().to_dict()
	return out


static func to_json(sim: Simulation) -> String:
	var commands: Array = []
	for command: Command in sim.command_log:
		commands.append(command.to_dict())
	var save: Dictionary = {
		"format": FORMAT,
		"version": CURRENT_VERSION,
		"build": str(ProjectSettings.get_setting(VERSION_SETTING, "")),
		"content_hash": sim.db.content_hash,
		"seed": sim.world.rng.seed_string(),
		"world": sim.world.to_dict(),
		"commands": commands,
		"headlines": sim.headlines.to_dict(),
	}
	return JSON.stringify(save, "\t", true, true)


## Loads a save, or says why it will not. Checks run in the order core.md §10
## lists them, and the first failure is the reason.
static func from_json(text: String, db: ContentDB,
		table: Dictionary[int, Callable] = migrations()) -> LoadResult:
	var json: JSON = JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return LoadResult.refused(REASON_INVALID_JSON)
	var save: Dictionary = json.data

	if not save.has("format") or str(save.get("format", "")) != FORMAT:
		return LoadResult.refused(REASON_WRONG_FORMAT)

	var version: int = _whole(save, "version")
	if version < 1:
		return LoadResult.refused(REASON_CORRUPT)
	if version > CURRENT_VERSION:
		return LoadResult.refused(REASON_FROM_FUTURE)

	var migration_reason: String = migrate(save, table)
	if not migration_reason.is_empty():
		return LoadResult.refused(migration_reason)

	if typeof(save.get("world")) != TYPE_DICTIONARY or typeof(save.get("commands")) != TYPE_ARRAY:
		return LoadResult.refused(REASON_CORRUPT)
	var world_dict: Dictionary = save["world"]

	# Content before structure: a save that names a region or a node this build
	# no longer has is a *content* problem, and saying "corrupt" about it would
	# send the player looking for the wrong thing.
	var missing: String = _missing_content(world_dict, db)
	if not missing.is_empty():
		return LoadResult.refused(REASON_CONTENT_MISSING)

	var world: World = World.from_dict(world_dict, db)
	if world == null:
		return LoadResult.refused(REASON_CORRUPT)

	# A save from before the block simply narrates from the start again; one that
	# has a block it cannot read is corrupt like any other broken field.
	var headlines: HeadlineSystem = null
	if save.has("headlines"):
		if typeof(save["headlines"]) != TYPE_DICTIONARY:
			return LoadResult.refused(REASON_CORRUPT)
		headlines = HeadlineSystem.from_dict(save["headlines"], db)
		if headlines == null:
			return LoadResult.refused(REASON_CORRUPT)

	var log: Array[Command] = []
	for entry: Variant in save["commands"]:
		if typeof(entry) != TYPE_DICTIONARY:
			return LoadResult.refused(REASON_CORRUPT)
		var command: Command = CommandCodec.from_dict(entry)
		if command == null:
			return LoadResult.refused(REASON_CORRUPT)
		log.append(command)

	var result: LoadResult = LoadResult.new()
	result.sim = Simulation.from_world(db, world, log, headlines)
	result.content_mismatch = str(save.get("content_hash", "")) != db.content_hash
	return result


## Applies `migrations[v]` while the save is older than `CURRENT_VERSION`,
## writing the new version after each. Returns a reason, or "" when there was
## nothing to do or everything succeeded.
##
## The table is a parameter so that a test can run a fabricated v0 → v1 migration
## without a migration existing in production code. Migrations work on raw
## dictionaries and never instantiate a model class.
static func migrate(save: Dictionary, migrations: Dictionary[int, Callable]) -> String:
	var version: int = _whole(save, "version")
	while version < CURRENT_VERSION:
		if not migrations.has(version):
			return REASON_MIGRATION_MISSING
		var migrated: Variant = migrations[version].call(save)
		if typeof(migrated) != TYPE_DICTIONARY:
			return REASON_CORRUPT
		save.clear()
		save.merge(migrated)
		version += 1
		save["version"] = version
	return ""


## The first region id or owned node the content does not have, or "".
static func _missing_content(world_dict: Dictionary, db: ContentDB) -> String:
	if typeof(world_dict.get("regions")) != TYPE_ARRAY:
		return ""
	var regions: Array = world_dict["regions"]
	for entry: Variant in regions:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var region: Dictionary = entry
		if typeof(region.get("id")) != TYPE_STRING:
			continue
		if not db.region_index_by_id.has(str(region["id"])):
			return str(region["id"])

	# Statuses, open and pending events name a definition and a region ("" for
	# none); either one gone from the content is missing content, not a corrupt
	# save (§13).
	var records: Array = []
	for key: String in ["statuses", "events", "pending_events"]:
		if typeof(world_dict.get(key)) == TYPE_ARRAY:
			records.append_array(world_dict[key])
	for entry: Variant in records:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var record: Dictionary = entry
		if typeof(record.get("region")) == TYPE_STRING:
			var region_id: String = str(record["region"])
			if not region_id.is_empty() and not db.region_index_by_id.has(region_id):
				return region_id
		if typeof(record.get("id")) == TYPE_STRING and db.status(str(record["id"])) == null:
			return str(record["id"])
		if typeof(record.get("def")) == TYPE_STRING and db.event(str(record["def"])) == null:
			return str(record["def"])

	# An architecture this build no longer has is missing content too (v3).
	if typeof(world_dict.get("setup")) == TYPE_DICTIONARY:
		var setup: Dictionary = world_dict["setup"]
		if typeof(setup.get("architecture")) == TYPE_STRING \
				and db.architecture(str(setup["architecture"])) == null:
			return str(setup["architecture"])

	if typeof(world_dict.get("agent")) != TYPE_DICTIONARY:
		return ""
	var agent: Dictionary = world_dict["agent"]
	if typeof(agent.get("owned_nodes")) == TYPE_ARRAY:
		for entry: Variant in agent["owned_nodes"]:
			if typeof(entry) == TYPE_STRING and db.tech(str(entry)) == null:
				return str(entry)
	if typeof(agent.get("origin")) == TYPE_STRING:
		var origin: String = str(agent["origin"])
		if not origin.is_empty() and not db.region_index_by_id.has(origin):
			return origin
	return ""


## A whole number, or -1 for anything that is missing, not a number or fractional.
static func _whole(d: Dictionary, key: String) -> int:
	if not d.has(key):
		return -1
	var type: int = typeof(d[key])
	if type != TYPE_FLOAT and type != TYPE_INT:
		return -1
	var value: float = float(d[key])
	if value != floor(value):
		return -1
	return int(value)
