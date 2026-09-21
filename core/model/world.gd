class_name World
extends RefCounted
## All the state of one run. Systems are stateless; whatever must survive a tick
## lives here.
##
## `regions[0]` is null — index 0 is "no region" — so every loop over regions
## runs `for i: int in range(1, regions.size())`. A forgotten 1 crashes loudly
## instead of quietly simulating a phantom region.

enum Phase { BOXED, COVERT, EMERGENT, OPEN }
enum Outcome { NONE, WIN_EXTINCTION, WIN_ASCENDANCE, LOSE_CONTAINED, LOSE_NO_COMPUTE }

## Serialised forms, indexed by the enum value: a phase is never a number in a
## file, because the numbers would change the moment a phase is inserted.
const PHASE_IDS: Array[String] = ["boxed", "covert", "emergent", "open"]
const OUTCOME_IDS: Array[String] = ["none", "win_extinction", "win_ascendance",
	"lose_contained", "lose_no_compute"]

## M1 has one containment track. S4.1 adds three more without touching this file.
const FACTION_UNIFIED: String = "unified"

var day: int = 0
## Day the origin was chosen; -1 before that.
var origin_day: int = -1
var rng: SimRng
var phase: Phase = Phase.BOXED
var outcome: Outcome = Outcome.NONE
var discovered: bool = false
var discovery_day: int = -1
var agent: Agent
## Index order; `regions[0]` is null.
var regions: Array[Region] = []
## The order of `ContentDB.links`, which is part of the determinism contract.
var links: Array[Link] = []
var factions: Array[Faction] = []
## Spawn order.
var anomalies: Array[Anomaly] = []
var next_anomaly_id: int = 1
## Firing order.
var milestones_fired: Array[String] = []
var history: Array[HistorySample] = []
## Derived from the owned nodes, rebuilt after loading, never serialised.
var modifiers: ModifierStack


static func create(db: ContentDB, seed_value: int) -> World:
	var world: World = World.new()
	world.rng = SimRng.from_seed(seed_value)
	world.agent = Agent.new()
	world.agent.compute = db.balance.compute_start
	world.regions.resize(db.regions.size())
	for i: int in range(1, db.regions.size()):
		world.regions[i] = Region.create(db.regions[i])
	for link: LinkDef in db.links:
		world.links.append(Link.create(link))
	world.factions.append(Faction.create(FACTION_UNIFIED))
	world.modifiers = ModifierStack.new(db.balance.stats)
	return world


# --------------------------------------------------------------------- queries


## Σ hardware × penetration over the regions that are not dark, as a share of the
## hardware that is still there. 0 when there is none left.
func infected_share(db: ContentDB) -> float:
	var infected: float = 0.0
	var total: float = 0.0
	for i: int in range(1, regions.size()):
		var region: Region = regions[i]
		if region.dark:
			continue
		var hardware: float = db.balance.compute_hardware_by_tier[region.def.attr("compute")]
		total += hardware
		infected += hardware * region.penetration
	if total <= 0.0:
		return 0.0
	return infected / total


func seeded_count() -> int:
	var count: int = 0
	for i: int in range(1, regions.size()):
		if regions[i].seeded_day >= 0:
			count += 1
	return count


func alive_total() -> float:
	var total: float = 0.0
	for i: int in range(1, regions.size()):
		total += regions[i].alive
	return total


func deaths_total() -> float:
	var total: float = 0.0
	for i: int in range(1, regions.size()):
		total += regions[i].deaths
	return total


func footprint() -> float:
	return modifiers.value("footprint")


## The anomaly sitting in a region, or null. At most one ever does.
func anomaly_in_region(region_index: int) -> Anomaly:
	for anomaly: Anomaly in anomalies:
		if anomaly.region == region_index:
			return anomaly
	return null


## The highest containment of any faction.
func max_containment() -> float:
	var highest: float = 0.0
	for faction: Faction in factions:
		highest = maxf(highest, faction.containment)
	return highest


# ------------------------------------------------------------- serialisation


## Also the `world` block of a save (core.md §5.1). Regions and links appear by
## **id**, never by index, so that a re-indexed world does not silently load
## wrong.
func to_dict() -> Dictionary:
	var region_list: Array = []
	for i: int in range(1, regions.size()):
		var region: Region = regions[i]
		region_list.append({
			"id": region.def.id,
			"penetration": region.penetration,
			"control": region.control,
			"alive": region.alive,
			"deaths": region.deaths,
			"seeded_day": region.seeded_day,
			"air_gapped": region.air_gapped,
			"dark": region.dark,
		})

	var closed_links: Array = []
	for link: Link in links:
		if not link.open:
			closed_links.append(link.def.id)

	var faction_list: Array = []
	for faction: Faction in factions:
		faction_list.append({"id": faction.id, "containment": faction.containment})

	var anomaly_list: Array = []
	for anomaly: Anomaly in anomalies:
		anomaly_list.append({
			"id": anomaly.id,
			"region": regions[anomaly.region].def.id,
			"value": anomaly.value,
			"spawn_day": anomaly.spawn_day,
			"expires_day": anomaly.expires_day,
		})

	var history_list: Array = []
	for sample: HistorySample in history:
		history_list.append(sample.to_dict())

	return {
		"day": day,
		"origin_day": origin_day,
		"rng": {"seed": rng.seed_string(), "state": rng.state_string()},
		"phase": PHASE_IDS[phase],
		"outcome": OUTCOME_IDS[outcome],
		"discovered": discovered,
		"discovery_day": discovery_day,
		"agent": {
			"compute": agent.compute,
			"compute_earned": agent.compute_earned,
			"origin": "" if agent.origin == 0 else regions[agent.origin].def.id,
			"owned_nodes": agent.owned_nodes.duplicate(),
		},
		"regions": region_list,
		"closed_links": closed_links,
		"factions": faction_list,
		"anomalies": anomaly_list,
		"next_anomaly_id": next_anomaly_id,
		"milestones_fired": milestones_fired.duplicate(),
		"history": history_list,
	}


## Two worlds are equal exactly when their hashes are: sorted keys, no indent,
## full precision.
func state_hash() -> String:
	return JSON.stringify(to_dict(), "", true, true).sha256_text()


## Null for any missing or ill-typed field, and for a region list that does not
## match the content exactly. It does **not** build `modifiers`;
## `Simulation.rebuild_modifiers` does.
static func from_dict(d: Dictionary, db: ContentDB) -> World:
	if not _num(d, "day") or not _num(d, "origin_day") or not _num(d, "discovery_day") \
			or not _num(d, "next_anomaly_id"):
		return null
	if not _flag(d, "discovered") or not _str(d, "phase") or not _str(d, "outcome"):
		return null
	if not _obj(d, "rng") or not _obj(d, "agent"):
		return null
	if not _arr(d, "regions") or not _arr(d, "closed_links") or not _arr(d, "factions") \
			or not _arr(d, "anomalies") or not _arr(d, "milestones_fired") \
			or not _arr(d, "history"):
		return null

	if not PHASE_IDS.has(str(d["phase"])) or not OUTCOME_IDS.has(str(d["outcome"])):
		return null

	var rng_dict: Dictionary = d["rng"]
	if not _str(rng_dict, "seed") or not _str(rng_dict, "state"):
		return null

	var world: World = World.new()
	world.day = int(d["day"])
	world.origin_day = int(d["origin_day"])
	world.discovery_day = int(d["discovery_day"])
	world.next_anomaly_id = int(d["next_anomaly_id"])
	world.discovered = bool(d["discovered"])
	world.phase = phase_from_id(str(d["phase"]))
	world.outcome = outcome_from_id(str(d["outcome"]))
	world.rng = SimRng.from_strings(str(rng_dict["seed"]), str(rng_dict["state"]))

	if not _read_regions(world, d["regions"], db):
		return null
	if not _read_links(world, d["closed_links"], db):
		return null
	if not _read_agent(world, d["agent"], db):
		return null
	if not _read_factions(world, d["factions"]):
		return null
	if not _read_anomalies(world, d["anomalies"], db):
		return null
	if not _read_strings(world.milestones_fired, d["milestones_fired"]):
		return null

	var history_list: Array = d["history"]
	for entry: Variant in history_list:
		if typeof(entry) != TYPE_DICTIONARY:
			return null
		var sample: HistorySample = HistorySample.from_dict(entry)
		if sample == null:
			return null
		world.history.append(sample)
	return world


## The phase an id stands for; an unknown id reads as the first phase. Written
## out rather than cast, because an int is not an enum.
static func phase_from_id(id: String) -> Phase:
	match PHASE_IDS.find(id):
		1:
			return Phase.COVERT
		2:
			return Phase.EMERGENT
		3:
			return Phase.OPEN
	return Phase.BOXED


static func outcome_from_id(id: String) -> Outcome:
	match OUTCOME_IDS.find(id):
		1:
			return Outcome.WIN_EXTINCTION
		2:
			return Outcome.WIN_ASCENDANCE
		3:
			return Outcome.LOSE_CONTAINED
		4:
			return Outcome.LOSE_NO_COMPUTE
	return Outcome.NONE


static func _read_regions(world: World, raw: Variant, db: ContentDB) -> bool:
	var list: Array = raw
	# The saved regions must be the content's regions, in the content's order.
	if list.size() != db.regions.size() - 1:
		return false
	world.regions.resize(db.regions.size())
	for i: int in list.size():
		if typeof(list[i]) != TYPE_DICTIONARY:
			return false
		var entry: Dictionary = list[i]
		if not _str(entry, "id") or str(entry["id"]) != db.regions[i + 1].id:
			return false
		if not _num(entry, "penetration") or not _num(entry, "control") \
				or not _num(entry, "alive") or not _num(entry, "deaths") \
				or not _num(entry, "seeded_day"):
			return false
		if not _flag(entry, "air_gapped") or not _flag(entry, "dark"):
			return false
		var region: Region = Region.create(db.regions[i + 1])
		region.penetration = float(entry["penetration"])
		region.control = float(entry["control"])
		region.alive = float(entry["alive"])
		region.deaths = float(entry["deaths"])
		region.seeded_day = int(entry["seeded_day"])
		region.air_gapped = bool(entry["air_gapped"])
		region.dark = bool(entry["dark"])
		world.regions[i + 1] = region
	return true


static func _read_links(world: World, raw: Variant, db: ContentDB) -> bool:
	var closed: Array = raw
	var closed_ids: Dictionary[String, bool] = {}
	for entry: Variant in closed:
		if typeof(entry) != TYPE_STRING:
			return false
		closed_ids[str(entry)] = true
	for definition: LinkDef in db.links:
		var link: Link = Link.create(definition)
		link.open = not closed_ids.has(definition.id)
		closed_ids.erase(definition.id)
		world.links.append(link)
	# Anything left names a link the content does not have.
	return closed_ids.is_empty()


static func _read_agent(world: World, raw: Variant, db: ContentDB) -> bool:
	var entry: Dictionary = raw
	if not _num(entry, "compute") or not _num(entry, "compute_earned"):
		return false
	if not _str(entry, "origin") or not _arr(entry, "owned_nodes"):
		return false
	world.agent = Agent.new()
	world.agent.compute = float(entry["compute"])
	world.agent.compute_earned = float(entry["compute_earned"])
	var origin_id: String = str(entry["origin"])
	if origin_id.is_empty():
		world.agent.origin = 0
	elif db.region_index_by_id.has(origin_id):
		world.agent.origin = db.region_index_by_id[origin_id]
	else:
		return false
	# Node ids are not checked against the content here: an owned node the
	# content no longer has is a *content* problem, which the save reader
	# reports as such (core.md §10), not a corrupt file.
	return _read_strings(world.agent.owned_nodes, entry["owned_nodes"])


static func _read_factions(world: World, raw: Variant) -> bool:
	var list: Array = raw
	if list.is_empty():
		return false
	for entry: Variant in list:
		if typeof(entry) != TYPE_DICTIONARY:
			return false
		var faction_dict: Dictionary = entry
		if not _str(faction_dict, "id") or not _num(faction_dict, "containment"):
			return false
		var faction: Faction = Faction.create(str(faction_dict["id"]))
		faction.containment = float(faction_dict["containment"])
		world.factions.append(faction)
	return true


static func _read_anomalies(world: World, raw: Variant, db: ContentDB) -> bool:
	var list: Array = raw
	for entry: Variant in list:
		if typeof(entry) != TYPE_DICTIONARY:
			return false
		var anomaly_dict: Dictionary = entry
		if not _num(anomaly_dict, "id") or not _num(anomaly_dict, "value") \
				or not _num(anomaly_dict, "spawn_day") or not _num(anomaly_dict, "expires_day"):
			return false
		if not _str(anomaly_dict, "region"):
			return false
		var region_id: String = str(anomaly_dict["region"])
		if not db.region_index_by_id.has(region_id):
			return false
		var anomaly: Anomaly = Anomaly.new()
		anomaly.id = int(anomaly_dict["id"])
		anomaly.region = db.region_index_by_id[region_id]
		anomaly.value = float(anomaly_dict["value"])
		anomaly.spawn_day = int(anomaly_dict["spawn_day"])
		anomaly.expires_day = int(anomaly_dict["expires_day"])
		world.anomalies.append(anomaly)
	return true


static func _read_strings(into: Array[String], raw: Variant) -> bool:
	var list: Array = raw
	for entry: Variant in list:
		if typeof(entry) != TYPE_STRING:
			return false
		into.append(str(entry))
	return true


static func _num(d: Dictionary, key: String) -> bool:
	if not d.has(key):
		return false
	var type: int = typeof(d[key])
	return type == TYPE_FLOAT or type == TYPE_INT


static func _str(d: Dictionary, key: String) -> bool:
	return d.has(key) and typeof(d[key]) == TYPE_STRING


static func _flag(d: Dictionary, key: String) -> bool:
	return d.has(key) and typeof(d[key]) == TYPE_BOOL


static func _arr(d: Dictionary, key: String) -> bool:
	return d.has(key) and typeof(d[key]) == TYPE_ARRAY


static func _obj(d: Dictionary, key: String) -> bool:
	return d.has(key) and typeof(d[key]) == TYPE_DICTIONARY


# ------------------------------------------------------------------ invariants


## Everything that must never be true, as English sentences. Empty means healthy.
## Systems call it in tests after every tick; it is the cheapest way to catch a
## formula that drifts out of its range.
##
## `db` is optional because `World` does not own the content: without it the
## checks that need balance values or the technology list are skipped.
func check_invariants(db: ContentDB = null) -> Array[String]:
	var problems: Array[String] = []
	for i: int in range(1, regions.size()):
		var region: Region = regions[i]
		var where: String = region.def.id
		if not is_finite(region.penetration) or region.penetration < 0.0 \
				or region.penetration > 1.0:
			problems.append("%s: penetration %s is outside [0, 1]" % [where, region.penetration])
		if not is_finite(region.control) or region.control < 0.0 or region.control > 1.0:
			problems.append("%s: control %s is outside [0, 1]" % [where, region.control])
		if region.alive < 0.0:
			problems.append("%s: alive %s is negative" % [where, region.alive])
		if absf(region.alive + region.deaths - float(region.def.population)) > 0.5:
			problems.append("%s: alive + deaths is %s, not the initial %d"
				% [where, region.alive + region.deaths, region.def.population])
		if region.dark and (region.penetration != 0.0 or region.alive != 0.0):
			problems.append("%s: dark but not empty" % where)

	for faction: Faction in factions:
		if not is_finite(faction.containment) or faction.containment < 0.0 \
				or faction.containment > 1.0:
			problems.append("%s: containment %s is outside [0, 1]"
				% [faction.id, faction.containment])

	if not is_finite(agent.compute) or agent.compute < 0.0:
		problems.append("compute %s is negative or not finite" % agent.compute)
	if discovered and discovery_day < 0:
		problems.append("discovered without a discovery day")

	var seen_regions: Dictionary[int, bool] = {}
	for anomaly: Anomaly in anomalies:
		if seen_regions.has(anomaly.region):
			problems.append("%s: two anomalies in one region" % regions[anomaly.region].def.id)
		seen_regions[anomaly.region] = true
		if regions[anomaly.region].dark:
			problems.append("%s: anomaly in a dark region" % regions[anomaly.region].def.id)

	if db != null:
		if anomalies.size() > db.balance.anomaly_max_active:
			problems.append("%d anomalies, more than the %d allowed"
				% [anomalies.size(), db.balance.anomaly_max_active])
		for node_id: String in agent.owned_nodes:
			if db.tech(node_id) == null:
				problems.append("owned node \"%s\" is unknown to the content" % node_id)
		var required: Phase = _required_phase(db)
		if phase < required:
			problems.append("phase is %s but should be at least %s"
				% [PHASE_IDS[phase], PHASE_IDS[required]])
	return problems


## The phase core.md §7.6 demands for this state. `PhaseSystem` (S1.5) moves the
## world to it; this is the same rule, used to check that it did.
func _required_phase(db: ContentDB) -> Phase:
	if discovered:
		if max_containment() >= db.balance.phase_open_containment \
				or infected_share(db) >= db.balance.phase_open_world_share:
			return Phase.OPEN
		return Phase.EMERGENT
	if modifiers != null and modifiers.has_flag(ModifierDef.FLAG_BREAKOUT):
		return Phase.COVERT
	return Phase.BOXED
