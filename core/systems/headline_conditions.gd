class_name HeadlineConditions
extends RefCounted
## Whether a headline's trigger holds (spec ticker.md §3.3): `on` against one
## event, `when` against the world.
##
## The vocabulary lives here in tables rather than in `if`s per headline, so that
## the validator and the evaluator read the same list and a new condition is one
## row. Nothing in here changes anything.

## Reading name → `[has a _max form, is a whole number]`. The `when` keys of
## §3.3 B that compare a number are exactly `<reading>_min` and `<reading>_max`.
const READINGS: Dictionary[String, Array] = {
	"day": [true, true],
	"regions": [true, true],
	"dark": [true, true],
	"share": [true, false],
	"deaths_share": [true, false],
	"containment": [true, false],
	"footprint": [true, false],
	"compute": [true, false],
	"days_since_discovery": [false, true],
	"dormant": [false, true],
	"harm": [false, false],
	"owned_count": [false, true],
	# D5.2 (`taskforce-endings.md` §6.1): the Swarm's drift, 0 elsewhere.
	"drift": [false, false],
}
const SUFFIX_MIN: String = "_min"
const SUFFIX_MAX: String = "_max"

## `when` keys holding a list of ids, and what the ids name.
const KEY_PHASE: String = "phase"
const KEY_OWNED: String = "owned"
const KEY_OWNED_ANY: String = "owned_any"
const KEY_NOT_OWNED: String = "not_owned"
const KEY_FLAG: String = "flag"
const KEY_NOT_FLAG: String = "not_flag"
const NODE_LISTS: Array[String] = [KEY_OWNED, KEY_OWNED_ANY, KEY_NOT_OWNED]
const FLAG_LISTS: Array[String] = [KEY_FLAG, KEY_NOT_FLAG]
const KEY_DISCOVERED: String = "discovered"

## The state keys map events added (`loop-mechanics.md` §10.3). One vocabulary
## for events and headlines alike.
const KEY_FACTION_MIN: String = "faction_min"
const KEY_FACTION_MAX: String = "faction_max"
const KEY_ASSET_MIN: String = "asset_min"
const KEY_ASSET_MAX: String = "asset_max"
## `{id: bound}` tables: a faction's containment, or the agent's total of a kind.
const TABLE_KEYS: Array[String] = [KEY_FACTION_MIN, KEY_FACTION_MAX, KEY_ASSET_MIN,
	KEY_ASSET_MAX]
const KEY_STATUS_ACTIVE: String = "status_active"
const KEY_STATUS_INACTIVE: String = "status_inactive"
const STATUS_LISTS: Array[String] = [KEY_STATUS_ACTIVE, KEY_STATUS_INACTIVE]
const KEY_ABILITY_UNLOCKED: String = "ability_unlocked"
const KEY_STORY_FLAG: String = "story_flag"
const KEY_NOT_STORY_FLAG: String = "not_story_flag"
const STORY_FLAG_LISTS: Array[String] = [KEY_STORY_FLAG, KEY_NOT_STORY_FLAG]
## D5.2 §6.1: the run's architecture is one of these.
const KEY_ARCHITECTURE: String = "architecture"

## Event fields the `on` filters read.
const FIELD_REGION: String = "region"
const FIELD_NODE: String = "node"

const TARGET_HARM: String = "harm"


## Every key `when` accepts, for the validator.
static func when_keys() -> Array[String]:
	var keys: Array[String] = [KEY_DISCOVERED, KEY_PHASE]
	keys.append_array(NODE_LISTS)
	keys.append_array(FLAG_LISTS)
	keys.append_array(TABLE_KEYS)
	keys.append_array(STATUS_LISTS)
	keys.append(KEY_ABILITY_UNLOCKED)
	keys.append_array(STORY_FLAG_LISTS)
	keys.append(KEY_ARCHITECTURE)
	for name: String in READINGS:
		keys.append(name + SUFFIX_MIN)
		if bool(READINGS[name][0]):
			keys.append(name + SUFFIX_MAX)
	return keys


## The reading a `<reading>_min` / `_max` key compares, or "" for a key that is
## not one of them.
static func reading_of(key: String) -> String:
	if TABLE_KEYS.has(key):
		return ""
	for suffix: String in [SUFFIX_MIN, SUFFIX_MAX]:
		if not key.ends_with(suffix):
			continue
		var name: String = key.trim_suffix(suffix)
		if READINGS.has(name) and (suffix == SUFFIX_MIN or bool(READINGS[name][0])):
			return name
	return ""


# ----------------------------------------------------------- the event trigger


## §3.3 A: does `event` match the headline's `on` block?
static func event_matches(def: HeadlineDef, event: SimEvent, db: ContentDB) -> bool:
	if event.type != def.on_event:
		return false
	if not _data_matches(def, event.data):
		return false
	if not _region_matches(def, event.data, db):
		return false
	return _node_matches(def, event.data, db)


static func _data_matches(def: HeadlineDef, data: Dictionary) -> bool:
	for field: String in def.on_data:
		if not data.has(field):
			return false
		if not _is_one_of(data[field], def.on_data[field]):
			return false
	return true


static func _is_one_of(value: Variant, accepted: Array) -> bool:
	for candidate: Variant in accepted:
		if _equal(value, candidate):
			return true
	return false


## Strings and bools compare exactly, numbers as floats — a JSON number against
## an int field would never be equal otherwise.
static func _equal(value: Variant, candidate: Variant) -> bool:
	var numeric: bool = [TYPE_INT, TYPE_FLOAT].has(typeof(value)) \
		and [TYPE_INT, TYPE_FLOAT].has(typeof(candidate))
	if numeric:
		return is_equal_approx(float(value), float(candidate))
	return typeof(value) == typeof(candidate) and value == candidate


static func _region_matches(def: HeadlineDef, data: Dictionary, db: ContentDB) -> bool:
	if def.on_region_attr_min.is_empty() and def.on_region_attr_max.is_empty():
		return true
	var region: RegionDef = _region_of(data, db)
	if region == null:
		return false
	for attribute: String in def.on_region_attr_min:
		if region.attr(attribute) < def.on_region_attr_min[attribute]:
			return false
	for attribute: String in def.on_region_attr_max:
		if region.attr(attribute) > def.on_region_attr_max[attribute]:
			return false
	return true


static func _node_matches(def: HeadlineDef, data: Dictionary, db: ContentDB) -> bool:
	if def.on_node_tree.is_empty() and def.on_node_tier == 0:
		return true
	if typeof(data.get(FIELD_NODE)) != TYPE_STRING:
		return false
	var node: TechNodeDef = db.tech(str(data[FIELD_NODE]))
	if node == null:
		return false
	if not def.on_node_tree.is_empty() and node.tree != def.on_node_tree:
		return false
	return def.on_node_tier == 0 or node.tier == def.on_node_tier


static func _region_of(data: Dictionary, db: ContentDB) -> RegionDef:
	if typeof(data.get(FIELD_REGION)) != TYPE_STRING:
		return null
	return db.region_by_id(str(data[FIELD_REGION]))


# ----------------------------------------------------------- the state trigger


## §3.3 B: do all of the headline's `when` conditions hold right now? An empty
## `when` is always true.
static func state_holds(def: HeadlineDef, world: World, db: ContentDB) -> bool:
	return holds(def.when, world, db)


## The same question for any `when` block — a headline's or a map event's
## (`loop-mechanics.md` §10.3).
static func holds(when: Dictionary, world: World, db: ContentDB) -> bool:
	for key: String in when:
		if not _condition_holds(str(key), when[key], world, db):
			return false
	return true


## A validated `when` block, each value cast to what its row says it is: a list
## of strings, a bool, a number, or an `{id: number}` table. Both loaders use it,
## so the evaluator never meets raw JSON.
static func cast_when(raw: Dictionary) -> Dictionary[String, Variant]:
	var when: Dictionary[String, Variant] = {}
	for key: Variant in raw:
		var value: Variant = raw[key]
		if typeof(value) == TYPE_ARRAY:
			when[str(key)] = _as_strings(value)
		elif typeof(value) == TYPE_BOOL:
			when[str(key)] = bool(value)
		elif typeof(value) == TYPE_DICTIONARY:
			var table: Dictionary[String, float] = {}
			var entries: Dictionary = value
			for name: Variant in entries:
				table[str(name)] = float(entries[name])
			when[str(key)] = table
		else:
			when[str(key)] = float(value)
	return when


static func _condition_holds(key: String, expected: Variant, world: World,
		db: ContentDB) -> bool:
	if key == KEY_DISCOVERED:
		return world.discovered == bool(expected)
	if key == KEY_PHASE:
		return _as_strings(expected).has(World.PHASE_IDS[world.phase])
	if key == KEY_ARCHITECTURE:
		return _as_strings(expected).has(world.setup.architecture)
	if NODE_LISTS.has(key) or FLAG_LISTS.has(key) or STATUS_LISTS.has(key) \
			or STORY_FLAG_LISTS.has(key) or key == KEY_ABILITY_UNLOCKED:
		return _list_holds(key, _as_strings(expected), world, db)
	if TABLE_KEYS.has(key):
		return _table_holds(key, expected, world)
	return _bound_holds(key, float(expected), world, db)


## A faction's containment, or the agent's total of an asset kind, against a
## bound per id. An id the world does not track reads as the highest track there
## is (the content is validated, so only a hand-built world can have one).
static func _table_holds(key: String, expected: Variant, world: World) -> bool:
	if typeof(expected) != TYPE_DICTIONARY:
		return false
	var table: Dictionary = expected
	var is_max: bool = key.ends_with(SUFFIX_MAX)
	for id: Variant in table:
		var bound: float = float(table[id])
		var value: float = 0.0
		if key == KEY_FACTION_MIN or key == KEY_FACTION_MAX:
			value = faction_containment(world, str(id))
		else:
			value = float(world.asset_total(str(id)))
		if is_max and value > bound:
			return false
		if not is_max and value < bound:
			return false
	return true


## One faction's containment; an id the world does not track reads as the
## maximum over the tracks it has (`loop-mechanics.md` §10.3).
static func faction_containment(world: World, faction_id: String) -> float:
	for faction: Faction in world.factions:
		if faction.id == faction_id:
			return faction.containment
	return world.max_containment()


## A modifier flag (a node's, or a timed one) or a story flag — one question,
## one answer (§20.8).
static func flag_set(world: World, flag: String) -> bool:
	return world.modifiers.has_flag(flag) or world.agent.has_story_flag(flag)


static func _list_holds(key: String, ids: Array[String], world: World,
		db: ContentDB) -> bool:
	match key:
		KEY_OWNED:
			for id: String in ids:
				if not world.agent.owns(id):
					return false
			return true
		KEY_OWNED_ANY:
			for id: String in ids:
				if world.agent.owns(id):
					return true
			return false
		KEY_NOT_OWNED:
			for id: String in ids:
				if world.agent.owns(id):
					return false
			return true
		KEY_FLAG:
			for flag: String in ids:
				if not flag_set(world, flag):
					return false
			return true
		KEY_NOT_FLAG:
			for flag: String in ids:
				if flag_set(world, flag):
					return false
			return true
		KEY_STORY_FLAG:
			for flag: String in ids:
				if not world.agent.has_story_flag(flag):
					return false
			return true
		KEY_NOT_STORY_FLAG:
			for flag: String in ids:
				if world.agent.has_story_flag(flag):
					return false
			return true
		KEY_STATUS_ACTIVE:
			for status_id: String in ids:
				if world.statuses_of(status_id).is_empty():
					return false
			return true
		KEY_STATUS_INACTIVE:
			for status_id: String in ids:
				if not world.statuses_of(status_id).is_empty():
					return false
			return true
	# `ability_unlocked`: every one at level 1 or more.
	for ability_id: String in ids:
		if Simulation.view(db, world).ability_level(ability_id) == 0:
			return false
	return true


static func _bound_holds(key: String, bound: float, world: World, db: ContentDB) -> bool:
	var name: String = reading_of(key)
	if name.is_empty():
		return false
	var value: float = reading(name, world, db)
	if key.ends_with(SUFFIX_MAX):
		return value <= bound
	return value >= bound


## What a `<reading>_min` / `_max` key compares against.
static func reading(name: String, world: World, db: ContentDB) -> float:
	match name:
		"day":
			return float(world.day - world.origin_day)
		"regions":
			return float(world.seeded_count())
		"dark":
			return float(dark_count(world))
		"dormant":
			return float(dormant_count(world))
		"share":
			return world.infected_share(db)
		"deaths_share":
			return deaths_share(world, db)
		"containment":
			return world.max_containment()
		"footprint":
			return world.footprint()
		"harm":
			return world.modifiers.value(TARGET_HARM)
		"compute":
			return world.agent.compute
		"owned_count":
			return float(world.agent.owned_nodes.size())
		"drift":
			return world.agent.drift
	# `days_since_discovery`. Never discovered: no bound on it can hold.
	if not world.discovered:
		return -INF
	return float(world.day - world.discovery_day)


static func dark_count(world: World) -> int:
	var count: int = 0
	for i: int in range(1, world.regions.size()):
		if world.regions[i].dark:
			count += 1
	return count


static func dormant_count(world: World) -> int:
	var count: int = 0
	for i: int in range(1, world.regions.size()):
		if world.regions[i].dormant:
			count += 1
	return count


static func deaths_share(world: World, db: ContentDB) -> float:
	if db.population_total <= 0.0:
		return 0.0
	return world.deaths_total() / db.population_total


## A JSON list as typed strings; a single string counts as a one-element list.
static func _as_strings(raw: Variant) -> Array[String]:
	var out: Array[String] = []
	if typeof(raw) == TYPE_STRING:
		out.append(str(raw))
		return out
	if typeof(raw) != TYPE_ARRAY:
		return out
	for entry: Variant in raw:
		out.append(str(entry))
	return out
