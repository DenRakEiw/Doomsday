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

## M1 has one containment track. S4.4 adds three more without touching this file.
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
## How long the world has been starving. Saved from v2 on; nothing reads it
## before S4.5 (D4.2 §3.2).
var starving_days: int = 0
## Every status running right now, in application order (§3.2).
var statuses: Array[Status] = []
## Every timed Footprint running right now, in creation order.
var pulses: Array[Pulse] = []
var next_pulse_id: int = 1
## The records of S4.3, in the save from v2 on. Until that step they are always
## empty; keeping them here is what lets S4.1 write and read a v2 file that
## S4.3 does not have to migrate again (§13).
var events: Array = []
var pending_events: Array = []
var next_event_id: int = 1
var event_fires: Dictionary[String, int] = {}
var event_last_day: Dictionary[String, int] = {}
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
	world.add_asset_sources(db)
	return world


# --------------------------------------------------------------------- queries


## Σ hardware × penetration over the regions that are not dark, as a share of the
## hardware that is still there. 0 when there is none left.
##
## A dormant region leaves the numerator and stays in the denominator: hiding is
## the whole point of the node, and what it costs is the share that drives
## discovery, containment and the Open phase.
func infected_share(db: ContentDB) -> float:
	var infected: float = 0.0
	var total: float = 0.0
	for i: int in range(1, regions.size()):
		var region: Region = regions[i]
		if region.dark:
			continue
		var hardware: float = db.balance.compute_hardware_by_tier[region.def.attr("compute")]
		total += hardware
		if region.dormant:
			continue
		infected += hardware * region.penetration
	if total <= 0.0:
		return 0.0
	return infected / total


## The one way an asset count ever changes: it writes the region and the mirror
## the modifier stack keeps, so an asset-scoped modifier can never be out of step
## with what stands there (`loop-mechanics.md` §6.3).
func set_assets(region_index: int, kind: String, count: int) -> void:
	var region: Region = regions[region_index]
	var held: int = maxi(0, count)
	if held == 0:
		region.assets.erase(kind)
	else:
		region.assets[kind] = held
	if modifiers != null:
		modifiers.set_asset_count(region_index, kind, held)


## Every asset kind's base effects as an always-active source, and the counts
## the scope reads (§6.2). Called after the stack is built or cleared.
func add_asset_sources(db: ContentDB) -> void:
	if modifiers == null:
		return
	var no_flags: Array[String] = []
	for kind: String in AssetDef.KINDS:
		if not db.assets.has(kind):
			continue
		modifiers.add_source(ModifierStack.source_for_asset(kind), db.assets[kind].modifiers,
			no_flags)
	for i: int in range(1, regions.size()):
		for kind: String in AssetDef.KINDS:
			modifiers.set_asset_count(i, kind, regions[i].asset_count(kind))


## How many assets of a kind the agent holds everywhere (`requires_assets`).
func asset_total(kind: String) -> int:
	var total: int = 0
	for i: int in range(1, regions.size()):
		total += regions[i].asset_count(kind)
	return total


## The status of this id running in the region, or null. Region 0 is the agent.
## At most one of an id ever stands in one region (§7.2).
func status_in_region(status_id: String, region_index: int) -> Status:
	for status: Status in statuses:
		if status.id == status_id and status.region == region_index:
			return status
	return null


## Whether a status of this id is running in the region — region 0 is the agent.
func has_status(status_id: String, region_index: int) -> bool:
	return status_in_region(status_id, region_index) != null


## Every status running in one region, in application order. Region 0 gives the
## agent's own.
func statuses_in_region(region_index: int) -> Array[Status]:
	var out: Array[Status] = []
	for status: Status in statuses:
		if status.region == region_index:
			out.append(status)
	return out


## Every region a status of this id is running in, in application order.
func statuses_of(status_id: String) -> Array[Status]:
	var out: Array[Status] = []
	for status: Status in statuses:
		if status.id == status_id:
			out.append(status)
	return out


## Whether any running status is holding this link closed. A link reopens only
## once the last of them is gone (§7.4).
func link_held_closed(link_id: String) -> bool:
	for status: Status in statuses:
		if status.closed_links.has(link_id):
			return true
	return false


## Whether a timed flag is set on `day` — `set_flag` with a `days` (§8.2). A
## story flag is `Agent.has_story_flag`; the modifier flags are the stack's.
func has_timed_flag(flag: String, day: int) -> bool:
	return agent.timed_flags.has(flag) and agent.timed_flags[flag] > day


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


## The highest Harm any region carries, which is what the interface shows
## (m3-screens.md §6.1). Half the Harm nodes are scoped, and an unscoped read of
## a scoped modifier is 0, so a player who owns only those would watch a Harm
## bar of zero while people die. The containment system keeps the unscoped
## value: that is the one core.md §7.5 multiplies.
func max_harm() -> float:
	var highest: float = modifiers.value("harm")
	for i: int in range(1, regions.size()):
		highest = maxf(highest, modifiers.value("harm", regions[i].def))
	return highest


## The highest containment of any faction.
func max_containment() -> float:
	var highest: float = 0.0
	for faction: Faction in factions:
		highest = maxf(highest, faction.containment)
	return highest


# ------------------------------------------------------------- serialisation


## Also the `world` block of a save (core.md §5.1). Regions and links appear by
## **id**, never by index, so that a re-indexed world does not silently load
## wrong, and every float appears as its bits (`FloatBits`) because JSON cannot
## carry a double back.
func to_dict() -> Dictionary:
	var region_list: Array = []
	for i: int in range(1, regions.size()):
		var region: Region = regions[i]
		var held: Dictionary = {}
		for kind: String in AssetDef.KINDS:
			if region.asset_count(kind) > 0:
				held[kind] = region.asset_count(kind)
		region_list.append({
			"id": region.def.id,
			"penetration": FloatBits.to_hex(region.penetration),
			"control": FloatBits.to_hex(region.control),
			"alive": FloatBits.to_hex(region.alive),
			"deaths": FloatBits.to_hex(region.deaths),
			"seeded_day": region.seeded_day,
			"air_gapped": region.air_gapped,
			"dark": region.dark,
			"dormant": region.dormant,
			"assets": held,
			"society": FloatBits.to_hex(region.society),
		})

	var closed_links: Array = []
	for link: Link in links:
		if not link.open:
			closed_links.append(link.def.id)

	var faction_list: Array = []
	for faction: Faction in factions:
		faction_list.append({
			"id": faction.id,
			"containment": FloatBits.to_hex(faction.containment),
			"preparing": faction.preparing,
			"fire_day": faction.fire_day,
			"cooldown_until": faction.cooldown_until,
		})

	var anomaly_list: Array = []
	for anomaly: Anomaly in anomalies:
		anomaly_list.append({
			"id": anomaly.id,
			"region": regions[anomaly.region].def.id,
			"value": FloatBits.to_hex(anomaly.value),
			"spawn_day": anomaly.spawn_day,
			"expires_day": anomaly.expires_day,
		})

	var history_list: Array = []
	for sample: HistorySample in history:
		history_list.append(sample.to_dict())

	# A status names its region by id like everything else in a save; the agent's
	# own statuses carry "" for region 0 (§3.6).
	var status_list: Array = []
	for status: Status in statuses:
		status_list.append(status.to_dict(
			"" if status.region == 0 else regions[status.region].def.id))

	var pulse_list: Array = []
	for pulse: Pulse in pulses:
		pulse_list.append(pulse.to_dict())

	return {
		"day": day,
		"origin_day": origin_day,
		"rng": {"seed": rng.seed_string(), "state": rng.state_string()},
		"phase": PHASE_IDS[phase],
		"outcome": OUTCOME_IDS[outcome],
		"discovered": discovered,
		"discovery_day": discovery_day,
		"agent": {
			"compute": FloatBits.to_hex(agent.compute),
			"compute_earned": FloatBits.to_hex(agent.compute_earned),
			"origin": "" if agent.origin == 0 else regions[agent.origin].def.id,
			"owned_nodes": agent.owned_nodes.duplicate(),
			"cooldowns": agent.cooldowns.duplicate(),
			"timed_flags": agent.timed_flags.duplicate(),
			"story_flags": agent.story_flags.duplicate(),
			"seeds_by_kind": agent.seeds_by_kind.duplicate(),
		},
		"regions": region_list,
		"closed_links": closed_links,
		"factions": faction_list,
		"anomalies": anomaly_list,
		"next_anomaly_id": next_anomaly_id,
		"milestones_fired": milestones_fired.duplicate(),
		"history": history_list,
		"starving_days": starving_days,
		# The status, pulse and event blocks of save v2. S4.3 still writes its
		# own two empty (`loop-mechanics.md` §13).
		"statuses": status_list,
		"pulses": pulse_list,
		"next_pulse_id": next_pulse_id,
		"events": events.duplicate(),
		"pending_events": pending_events.duplicate(),
		"next_event_id": next_event_id,
		"event_fires": event_fires.duplicate(),
		"event_last_day": event_last_day.duplicate(),
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
	# Save v2 (loop-mechanics.md 13). A v1 file reaches this function migrated,
	# so every field is required: a missing one is a corrupt save, not an old one.
	if not _num(d, "starving_days") or not _num(d, "next_pulse_id") \
			or not _num(d, "next_event_id"):
		return null
	if not _arr(d, "statuses") or not _arr(d, "pulses") or not _arr(d, "events") \
			or not _arr(d, "pending_events"):
		return null
	if not _obj(d, "event_fires") or not _obj(d, "event_last_day"):
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
	world.starving_days = int(d["starving_days"])
	world.next_pulse_id = int(d["next_pulse_id"])
	world.next_event_id = int(d["next_event_id"])
	# The event records are S4.3's; until then the lists are always empty and are
	# carried through as they were written.
	world.events = (d["events"] as Array).duplicate()
	world.pending_events = (d["pending_events"] as Array).duplicate()
	if not _read_counts(world.event_fires, d["event_fires"]) \
			or not _read_counts(world.event_last_day, d["event_last_day"]):
		return null

	if not _read_regions(world, d["regions"], db):
		return null
	if not _read_links(world, d["closed_links"], db):
		return null
	# After the regions: a status names its region by id, and the map from id to
	# index is the content's, but a region out of range would still index a list
	# that is only built above.
	if not _read_statuses(world, d["statuses"], db):
		return null
	if not _read_pulses(world, d["pulses"]):
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
		if not _real(entry, "penetration") or not _real(entry, "control") \
				or not _real(entry, "alive") or not _real(entry, "deaths") \
				or not _num(entry, "seeded_day"):
			return false
		if not _flag(entry, "air_gapped") or not _flag(entry, "dark"):
			return false
		# `dormant` arrived with the trees; a save written before them is read
		# as a world where nothing is held.
		if entry.has("dormant") and typeof(entry["dormant"]) != TYPE_BOOL:
			return false
		if not _obj(entry, "assets") or not _real(entry, "society"):
			return false
		var region: Region = Region.create(db.regions[i + 1])
		region.penetration = FloatBits.from_variant(entry["penetration"])
		region.control = FloatBits.from_variant(entry["control"])
		region.alive = FloatBits.from_variant(entry["alive"])
		region.deaths = FloatBits.from_variant(entry["deaths"])
		region.seeded_day = int(entry["seeded_day"])
		region.air_gapped = bool(entry["air_gapped"])
		region.dark = bool(entry["dark"])
		region.dormant = bool(entry.get("dormant", false))
		region.society = FloatBits.from_variant(entry["society"])
		var held: Dictionary = entry["assets"]
		for kind: Variant in held:
			if typeof(kind) != TYPE_STRING or not AssetDef.KINDS.has(str(kind)):
				return false
			var count: Variant = held[kind]
			if typeof(count) != TYPE_FLOAT and typeof(count) != TYPE_INT:
				return false
			region.assets[str(kind)] = int(count)
		world.regions[i + 1] = region
	return true


## The running statuses of a save (§13). A status naming a region the content
## does not have is a content problem and was refused before this point; here
## anything ill-typed is simply a corrupt file.
static func _read_statuses(world: World, raw: Variant, db: ContentDB) -> bool:
	var list: Array = raw
	for entry: Variant in list:
		if typeof(entry) != TYPE_DICTIONARY:
			return false
		var d: Dictionary = entry
		if not _str(d, "id") or not _str(d, "region") or not _str(d, "source") \
				or not _str(d, "option"):
			return false
		if not _num(d, "level") or not _num(d, "started_day") or not _num(d, "until_day"):
			return false
		if not _arr(d, "closed_links"):
			return false
		var status: Status = Status.new()
		status.id = str(d["id"])
		var region_id: String = str(d["region"])
		if region_id.is_empty():
			status.region = 0
		elif db.region_index_by_id.has(region_id):
			status.region = db.region_index_by_id[region_id]
		else:
			return false
		status.source = str(d["source"])
		status.level = int(d["level"])
		status.started_day = int(d["started_day"])
		status.until_day = int(d["until_day"])
		status.option = str(d["option"])
		if not _read_strings(status.closed_links, d["closed_links"]):
			return false
		world.statuses.append(status)
	return true


static func _read_pulses(world: World, raw: Variant) -> bool:
	var list: Array = raw
	for entry: Variant in list:
		if typeof(entry) != TYPE_DICTIONARY:
			return false
		var d: Dictionary = entry
		if not _num(d, "index") or not _real(d, "value") or not _num(d, "until_day"):
			return false
		if not _arr(d, "watched_by"):
			return false
		var pulse: Pulse = Pulse.new()
		pulse.index = int(d["index"])
		pulse.value = FloatBits.from_variant(d["value"])
		pulse.until_day = int(d["until_day"])
		if not _read_strings(pulse.watched_by, d["watched_by"]):
			return false
		world.pulses.append(pulse)
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
	if not _real(entry, "compute") or not _real(entry, "compute_earned"):
		return false
	if not _str(entry, "origin") or not _arr(entry, "owned_nodes"):
		return false
	if not _obj(entry, "cooldowns") or not _obj(entry, "timed_flags") \
			or not _arr(entry, "story_flags") or not _obj(entry, "seeds_by_kind"):
		return false
	world.agent = Agent.new()
	world.agent.compute = FloatBits.from_variant(entry["compute"])
	world.agent.compute_earned = FloatBits.from_variant(entry["compute_earned"])
	var origin_id: String = str(entry["origin"])
	if origin_id.is_empty():
		world.agent.origin = 0
	elif db.region_index_by_id.has(origin_id):
		world.agent.origin = db.region_index_by_id[origin_id]
	else:
		return false
	if not _read_counts(world.agent.cooldowns, entry["cooldowns"]) \
			or not _read_counts(world.agent.timed_flags, entry["timed_flags"]):
		return false
	var seeds: Dictionary = entry["seeds_by_kind"]
	for kind: Variant in seeds:
		if typeof(kind) != TYPE_STRING or not LinkDef.KINDS.has(str(kind)):
			return false
	if not _read_counts(world.agent.seeds_by_kind, seeds):
		return false
	if not _read_strings(world.agent.story_flags, entry["story_flags"]):
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
		if not _str(faction_dict, "id") or not _real(faction_dict, "containment"):
			return false
		if not _str(faction_dict, "preparing") or not _num(faction_dict, "fire_day") \
				or not _num(faction_dict, "cooldown_until"):
			return false
		var faction: Faction = Faction.create(str(faction_dict["id"]))
		faction.containment = FloatBits.from_variant(faction_dict["containment"])
		faction.preparing = str(faction_dict["preparing"])
		faction.fire_day = int(faction_dict["fire_day"])
		faction.cooldown_until = int(faction_dict["cooldown_until"])
		world.factions.append(faction)
	return true


static func _read_anomalies(world: World, raw: Variant, db: ContentDB) -> bool:
	var list: Array = raw
	for entry: Variant in list:
		if typeof(entry) != TYPE_DICTIONARY:
			return false
		var anomaly_dict: Dictionary = entry
		if not _num(anomaly_dict, "id") or not _real(anomaly_dict, "value") \
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
		anomaly.value = FloatBits.from_variant(anomaly_dict["value"])
		anomaly.spawn_day = int(anomaly_dict["spawn_day"])
		anomaly.expires_day = int(anomaly_dict["expires_day"])
		world.anomalies.append(anomaly)
	return true


## A `{id: whole number}` block of the save. False for anything ill-typed.
static func _read_counts(into: Dictionary[String, int], raw: Variant) -> bool:
	if typeof(raw) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = raw
	for key: Variant in d:
		if typeof(key) != TYPE_STRING:
			return false
		var type: int = typeof(d[key])
		if type != TYPE_FLOAT and type != TYPE_INT:
			return false
		into[str(key)] = int(d[key])
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


## A float field: the bit form of `FloatBits`, or a plain number.
static func _real(d: Dictionary, key: String) -> bool:
	return d.has(key) and FloatBits.is_readable(d[key])


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
		if region.dormant and (region.dark or region.penetration <= 0.0):
			problems.append("%s: dormant without the agent in it" % where)
		for kind: String in region.assets:
			if region.assets[kind] < 0:
				problems.append("%s: %d %s assets is negative"
					% [where, region.assets[kind], kind])

	for faction: Faction in factions:
		if not is_finite(faction.containment) or faction.containment < 0.0 \
				or faction.containment > 1.0:
			problems.append("%s: containment %s is outside [0, 1]"
				% [faction.id, faction.containment])

	if not is_finite(agent.compute) or agent.compute < 0.0:
		problems.append("compute %s is negative or not finite" % agent.compute)
	if discovered and discovery_day < 0:
		problems.append("discovered without a discovery day")
	var seen_flags: Dictionary[String, bool] = {}
	for flag: String in agent.story_flags:
		if seen_flags.has(flag):
			problems.append("story flag %s is set twice" % flag)
		seen_flags[flag] = true
	for kind: String in agent.seeds_by_kind:
		if not LinkDef.KINDS.has(kind):
			problems.append("seeds_by_kind names the unknown link kind %s" % kind)

	problems.append_array(_status_problems(db))

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


## Everything that must never be true of the running statuses, pulses, cooldowns
## and timed flags (§3.5). A day one tick in the past is normal: the tick that
## expires them runs after everything else that day.
func _status_problems(db: ContentDB) -> Array[String]:
	var problems: Array[String] = []
	var seen: Dictionary[String, bool] = {}
	for status: Status in statuses:
		var where: String = "status %s" % status.id
		if status.region < 0 or status.region >= regions.size():
			problems.append("%s: region %d does not exist" % [where, status.region])
			continue
		if status.region > 0 and regions[status.region].dark:
			problems.append("%s: in the dark region %s"
				% [where, regions[status.region].def.id])
		if not status.is_standing() and status.until_day <= status.started_day:
			problems.append("%s: ends on day %d, which is not after day %d"
				% [where, status.until_day, status.started_day])
		var key: String = "%s|%d" % [status.id, status.region]
		if seen.has(key):
			problems.append("%s: running twice in one region" % where)
		seen[key] = true
		if db == null:
			continue
		var definition: StatusDef = db.status(status.id)
		if definition == null:
			problems.append("%s: unknown to the content" % where)
		elif status.level < 1 or status.level > definition.levels.size():
			problems.append("%s: level %d is outside its %d levels"
				% [where, status.level, definition.levels.size()])
	for pulse: Pulse in pulses:
		if pulse.until_day < day - 1:
			problems.append("pulse %d expired on day %d" % [pulse.index, pulse.until_day])
	for ability_id: String in agent.cooldowns:
		if agent.cooldowns[ability_id] < day - 1:
			problems.append("cooldown %s cleared on day %d"
				% [ability_id, agent.cooldowns[ability_id]])
	for flag: String in agent.timed_flags:
		if agent.timed_flags[flag] < day - 1:
			problems.append("timed flag %s expired on day %d" % [flag, agent.timed_flags[flag]])
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
