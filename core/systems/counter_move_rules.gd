class_name CounterMoveRules
extends RefCounted
## Where a faction's move lands, and which variant of it (opposition.md §6.4).
##
## Pure and deterministic: every rule scores the regions that are not dark, not
## dormant, not blocked for the move's status and hold the agent, and answers the
## highest score, ties to the lower index — no RNG. The names are
## `EventDef.PICK_RULES`, which the validator has checked since S4.3.

const LOCKDOWN_TARGET: String = "lockdown_target"
const RICHEST_INFECTED: String = "richest_infected"
const AUDIT_TARGET: String = "audit_target"
const PURGE_TARGET: String = "purge_target"
const EXPOSURE_TARGET: String = "exposure_target"
const PROTEST_TARGET: String = "protest_target"
const RULES: Array[String] = ["lockdown_target", "richest_infected", "audit_target",
	"purge_target", "exposure_target", "protest_target"]
const SELECTORS: Array[String] = ["seeds_by_kind_max"]

## `audit_target`'s filter: a research tier and a presence worth auditing.
const AUDIT_MIN_RESEARCH: int = 2
const AUDIT_MIN_PENETRATION: float = 0.2
## `purge_target`: labs first, then research, then presence — each step an order
## of magnitude above the next, so the lexical order is one score.
const PURGE_LAB_WEIGHT: float = 100.0
const PURGE_RESEARCH_WEIGHT: float = 10.0
## `protest_target`: fleets first, then the dead.
const PROTEST_FLEET_WEIGHT: float = 10.0
const EXPOSURE_STATUS: String = "exposure"
const ATTR_REGULATION: String = "regulation"
const ATTR_RESEARCH: String = "research"
## "No region" — the move is dropped.
const NONE: int = 0


## The region `rule` picks for a move applying `status_id`, or `NONE`.
static func pick(rule: String, world: World, db: ContentDB, status_id: String) -> int:
	var sim: Simulation = Simulation.view(db, world)
	match rule:
		PROTEST_TARGET:
			return _protest(sim, status_id)
	var best: int = NONE
	var best_score: float = -INF
	for i: int in range(1, world.regions.size()):
		if not _open(world, db, i, status_id):
			continue
		var region: Region = world.regions[i]
		var score: float = 0.0
		match rule:
			LOCKDOWN_TARGET:
				score = region.penetration * (1.0 + float(region.def.attr(ATTR_REGULATION)))
			RICHEST_INFECTED:
				score = sim.hardware(i) * region.penetration
			AUDIT_TARGET:
				if region.def.attr(ATTR_RESEARCH) < AUDIT_MIN_RESEARCH \
						or region.penetration < AUDIT_MIN_PENETRATION:
					continue
				score = float(region.def.attr(ATTR_RESEARCH)) * region.penetration
			PURGE_TARGET:
				score = float(region.asset_count(AssetDef.KIND_LAB)) * PURGE_LAB_WEIGHT \
					+ float(region.def.attr(ATTR_RESEARCH)) * PURGE_RESEARCH_WEIGHT \
					+ region.penetration
			EXPOSURE_TARGET:
				if world.has_status(EXPOSURE_STATUS, i):
					continue
				score = region.penetration
			_:
				push_error("unknown counter-move rule \"%s\"" % rule)
				return NONE
		if score > best_score:
			best_score = score
			best = i
	return best


## The fleets are where the crowd goes; without a fleet anywhere, the dead are
## (a share of the region's own people), and without either nobody marches.
static func _protest(sim: Simulation, status_id: String) -> int:
	var world: World = sim.world
	var best: int = NONE
	var best_score: float = -INF
	for i: int in range(1, world.regions.size()):
		if not _open(world, sim.db, i, status_id):
			continue
		var region: Region = world.regions[i]
		var fleets: int = region.asset_count(AssetDef.KIND_FLEET)
		if fleets <= 0:
			continue
		var score: float = float(fleets) * PROTEST_FLEET_WEIGHT + _deaths_share(region)
		if score > best_score:
			best_score = score
			best = i
	if best != NONE:
		return best
	for i: int in range(1, world.regions.size()):
		if not _open(world, sim.db, i, status_id):
			continue
		var share: float = _deaths_share(world.regions[i])
		if share < sim.db.balance.factions_protest_deaths_share:
			continue
		if share > best_score:
			best_score = share
			best = i
	return best


## The key a selector answers (§6.4): `seeds_by_kind_max` is the link kind the
## agent has seeded most over, ties and all-zero to the earliest kind.
static func select(selector: String, world: World, _db: ContentDB) -> String:
	if selector != FactionMoveDef.SELECTOR_SEEDS_BY_KIND_MAX:
		push_error("unknown counter-move selector \"%s\"" % selector)
		return ""
	var best: String = LinkDef.KINDS[0]
	var most: int = int(world.agent.seeds_by_kind.get(best, 0))
	for kind: String in LinkDef.KINDS:
		var seeds: int = int(world.agent.seeds_by_kind.get(kind, 0))
		if seeds > most:
			most = seeds
			best = kind
	return best


## Whether a move may land here at all: the region still stands, holds the
## agent awake, and nothing of the agent's there blocks the move's status.
static func region_open(world: World, db: ContentDB, index: int, status_id: String) -> bool:
	return _open(world, db, index, status_id)


static func _open(world: World, db: ContentDB, index: int, status_id: String) -> bool:
	var region: Region = world.regions[index]
	if region.dark or region.dormant or region.penetration <= 0.0:
		return false
	return not world.region_blocked_for(index, status_id, db)


static func _deaths_share(region: Region) -> float:
	return region.deaths / float(region.def.population)
