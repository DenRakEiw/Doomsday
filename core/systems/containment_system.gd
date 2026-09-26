class_name ContainmentSystem
extends SimSystem
## Being found, and then being hunted (core.md §7.5, opposition.md §5).
##
## Four factions, each with its own eyes (the Footprint it sees and the terms of
## `factions.json`), its own hands (the regions whose capacity it draws on) and
## its own brake.
##
## The two formulas are also the two pure queries of `m3-screens.md` §10.5: the
## containment panel asks for exactly what the tick is about to do, and reads it
## out of this file rather than repeating it.

## The world-wide factors on being found and on every track's growth.
const TARGET_DISCOVERY: String = "discovery"
const TARGET_CONTAINMENT_GROWTH: String = "containment_growth"
## Keys of `discovery_risk`.
const RISK_TOTAL: String = "total"
const RISK_TIME: String = "time"
const RISK_FOOTPRINT: String = "footprint"
const RISK_BREADTH: String = "breadth"
## Keys of `containment_breakdown(faction)` (opposition.md §5.5).
const TERMS: String = "terms"
const PRESSURE: String = "pressure"
const CAPACITY: String = "capacity"
const BRAKES: String = "brakes"
const GAIN: String = "gain"
## Keys of one entry of `TERMS`.
const TERM_SOURCE: String = "source"
const TERM_TREE: String = "tree"
const TERM_KIND: String = "kind"
const TERM_WEIGHT: String = "weight"
const TERM_VALUE: String = "value"
const TERM_CONTRIBUTION: String = "contribution"
## The regional target a status uses to take a region's research capacity away
## (`loop-mechanics.md` §7.5). Live from S4.2.
const TARGET_CAPACITY: String = "containment_capacity"
## Entries per region in `capacity_factors`.
const CAPACITY_FACTORS: int = 4


## The daily discovery risk of §7.5, without rolling for it. The three terms are
## reported after the `discovery` factor and before the clamp, so they add up to
## `total` unless the clamp bit.
static func discovery_risk(world: World, db: ContentDB) -> Dictionary:
	var factor: float = world.modifiers.value(TARGET_DISCOVERY)
	var share: float = world.infected_share(db)
	var time: float = db.balance.discovery_scrutiny_per_day \
		* float(world.day - world.origin_day) * factor
	var footprint: float = db.balance.discovery_per_footprint * world.footprint() * factor
	var breadth: float = db.balance.discovery_breadth_rate \
		* maxf(0.0, share - db.balance.discovery_breadth_free) * factor
	return {
		RISK_TIME: time,
		RISK_FOOTPRINT: footprint,
		RISK_BREADTH: breadth,
		RISK_TOTAL: clampf(time + footprint + breadth, 0.0, 1.0),
	}


## What the next tick will add to one faction's track, and what it is made of
## (opposition.md §5.5). The terms in file order, each with its weight, value
## and contribution; the pressure is `1 + Σ contribution`. The weight is the one
## that counts: the run's scenario may scale it (`scenarios.md` §8.2).
## `factors` is `capacity_factors` of this world as it stands, or empty to have
## them read here — the tick reads them once for all four factions (S6.11).
static func containment_breakdown(world: World, db: ContentDB, faction_id: String,
		factors: PackedFloat64Array = PackedFloat64Array()) -> Dictionary:
	var definition: FactionDef = db.faction(faction_id)
	if definition == null:
		push_error("unknown faction \"%s\"" % faction_id)
		return {}
	var scenario: ScenarioDef = db.scenario(world.setup.scenario)
	var terms: Array[Dictionary] = []
	var sum: float = 0.0
	for term: FactionTermDef in definition.terms:
		var value: float = term.value(world, db, faction_id)
		var weight: float = term.weight
		if scenario != null:
			weight *= scenario.term_scale(faction_id, term.source)
		var contribution: float = weight * value
		sum += contribution
		terms.append({
			TERM_SOURCE: term.source,
			TERM_TREE: term.tree,
			TERM_KIND: term.kind,
			TERM_WEIGHT: weight,
			TERM_VALUE: value,
			TERM_CONTRIBUTION: contribution,
		})
	var pressure: float = 1.0 + sum
	var capacity: float = _capacity(world, db, definition.capacity_attr, factors)
	var brakes: float = _brakes(world, db, definition, faction_id)
	return {
		TERMS: terms,
		PRESSURE: pressure,
		CAPACITY: capacity,
		BRAKES: brakes,
		GAIN: db.balance.containment_base_rate * pressure * capacity * brakes,
	}


## The breakdown's `PRESSURE` alone, to the last bit: the same terms in the same
## order, without the capacity and the dictionaries the history has no use for
## (S6.11). Unknown factions answer 0, as the breakdown's empty result reads.
static func pressure(world: World, db: ContentDB, faction_id: String) -> float:
	var definition: FactionDef = db.faction(faction_id)
	if definition == null:
		push_error("unknown faction \"%s\"" % faction_id)
		return 0.0
	var scenario: ScenarioDef = db.scenario(world.setup.scenario)
	var sum: float = 0.0
	for term: FactionTermDef in definition.terms:
		var value: float = term.value(world, db, faction_id)
		var weight: float = term.weight
		if scenario != null:
			weight *= scenario.term_scale(faction_id, term.source)
		var contribution: float = weight * value
		sum += contribution
	return 1.0 + sum


## The breakdown's `GAIN` alone, to the last bit — what the tick adds, without
## the dictionaries (S6.11). `factors` as in `containment_breakdown`.
static func gain(world: World, db: ContentDB, faction_id: String,
		factors: PackedFloat64Array = PackedFloat64Array()) -> float:
	var definition: FactionDef = db.faction(faction_id)
	if definition == null:
		push_error("unknown faction \"%s\"" % faction_id)
		return 0.0
	return db.balance.containment_base_rate * pressure(world, db, faction_id) \
		* _capacity(world, db, definition.capacity_attr, factors) \
		* _brakes(world, db, definition, faction_id)


## The factor the faction's brakes leave of its growth.
static func _brakes(world: World, db: ContentDB, definition: FactionDef,
		faction_id: String) -> float:
	var brakes: float = world.modifiers.value(TARGET_CONTAINMENT_GROWTH) \
		* world.modifiers.value(definition.brake)
	# `labs_from_day_one` (replayability.md §2.5): on a Research Agent the lab
	# watches the agent directly, every day, so nothing done to the world — the
	# global `containment_growth` stack of Pause, Grace, the Negotiation and the
	# Persuasion nodes — slows it. Only what is aimed at the labs, their own
	# `containment_ai_labs`, brakes them.
	if holds_steady(world, db, faction_id):
		brakes = world.modifiers.value(definition.brake)
	# G4 (BALANCE §4.3): brakes still matter, down to the floor, and no build
	# makes a faction powerless.
	return maxf(brakes, db.balance.containment_brake_floor)


## The faction closest to switching the agent off: "" before discovery, else
## the highest track, ties to the earlier in `world.factions` (§5.6).
static func threat_leader(world: World) -> String:
	if not world.discovered:
		return ""
	var leader: String = ""
	var highest: float = -1.0
	for faction: Faction in world.factions:
		if faction.containment > highest:
			highest = faction.containment
			leader = faction.id
	return leader


func tick(world: World, db: ContentDB, events: Array[SimEvent]) -> void:
	if world.agent.origin == 0:
		return
	if not world.discovered:
		_try_discovery(world, db, events)
		# Containment does not grow on the day of discovery: the world needs a
		# day to react — except the labs of a Research Agent, who never needed to
		# be told.
		if labs_watch(world, db):
			_grow(world, db, events, Faction.ID_AI_LABS)
		return
	_grow(world, db, events)


## `labs_from_day_one` (`replayability.md` §2.2): the AI Labs hunt a Research
## Agent from its origin, before anyone else knows.
static func labs_watch(world: World, db: ContentDB) -> bool:
	return world.has_hook(db, ArchitectureDef.HOOK_LABS_FROM_DAY_ONE)


## The track no rollback lowers and no funding reset pauses: the labs', under
## `labs_from_day_one`. Every other track answers no.
static func holds_steady(world: World, db: ContentDB, faction_id: String) -> bool:
	return faction_id == Faction.ID_AI_LABS and labs_watch(world, db)


## The scrutiny term grows with time, so even a perfectly quiet agent is found
## eventually and a run cannot stall.
func _try_discovery(world: World, db: ContentDB, events: Array[SimEvent]) -> void:
	var cause: String = ""
	if world.deaths_total() / db.population_total >= db.balance.discovery_deaths_certain_share:
		# Deaths on that scale are not something anybody has to roll for.
		cause = SimEvent.CAUSE_DEATHS
	else:
		var risk: float = float(discovery_risk(world, db)[RISK_TOTAL])
		if risk <= 0.0:
			return
		if not world.rng.chance(risk):
			return
		cause = SimEvent.CAUSE_SCRUTINY

	world.discovered = true
	world.discovery_day = world.day
	events.append(SimEvent.new(SimEvent.DISCOVERED, world.day, {"cause": cause}))
	# A scenario's head start lands today and not a day before (scenarios.md §2).
	ScenarioStart.at_discovery(world, db, events)


## Killing or controlling the regions a faction draws on is what slows it down
## — the race both win conditions are built on. Every gain is read before any
## track moves, so the order of the factions changes nothing but the order of
## the events.
func _grow(world: World, db: ContentDB, events: Array[SimEvent], only: String = "") -> void:
	var leader_before: String = _leader_tracked(world)
	var gains: Array[float] = []
	var factors: PackedFloat64Array = capacity_factors(world, db)
	for faction: Faction in world.factions:
		gains.append(gain(world, db, faction.id, factors))

	for i: int in world.factions.size():
		var faction: Faction = world.factions[i]
		if not only.is_empty() and faction.id != only:
			continue
		var before: float = faction.containment
		faction.containment = minf(1.0, faction.containment + gains[i])
		for threshold: float in db.balance.containment_thresholds:
			if threshold > before and threshold <= faction.containment:
				events.append(SimEvent.new(SimEvent.CONTAINMENT_THRESHOLD, world.day, {
					"faction": faction.id,
					"threshold": threshold,
				}))

	# Before discovery nobody leads, whatever one track has done (§5.6).
	var leader_after: String = threat_leader(world)
	if world.discovered and leader_after != leader_before:
		events.append(SimEvent.new(SimEvent.THREAT_LEADER_CHANGED, world.day, {
			"from": leader_before,
			"to": leader_after,
		}))


## The leader as the tick found it. On the first tick after discovery nobody has
## led yet, so `from` is "" and the console can say who leads now (§5.6).
static func _leader_tracked(world: World) -> String:
	if world.day - 1 <= world.discovery_day:
		return ""
	return threat_leader(world)


## How much of the capacity a faction draws on is still alive and still its own,
## weighted by the tier of its capacity attribute (§5.2). Every region counts
## towards the denominator, so a dark region does not make the survivors look
## more capable.
##
## `containment_capacity` scales the numerator only: a region whose
## laboratories are dark lowers the world's capacity, it does not vanish from the
## world — which is what a denominator scaled with it would mean.
static func _capacity(world: World, db: ContentDB, attribute: String,
		factors: PackedFloat64Array = PackedFloat64Array()) -> float:
	if factors.is_empty():
		factors = capacity_factors(world, db)
	var weights: Array[float] = db.balance.containment_capacity_weight_by_tier
	var weighted: float = 0.0
	var total: float = 0.0
	var at: int = 0
	for i: int in range(1, world.regions.size()):
		var weight: float = weights[world.regions[i].def.attr(attribute)]
		total += weight
		# The product in the order it has always been taken, factor by factor.
		weighted += weight * factors[at] * factors[at + 1] * factors[at + 2] * factors[at + 3]
		at += CAPACITY_FACTORS
	if total <= 0.0:
		return 0.0
	return weighted / total


## The four factors of every region's capacity that no faction changes, region
## by region from index 1: the `containment_capacity` stat, the share alive,
## the share not controlled and the disorder's multiplier. Read once per tick
## and shared by the four factions (S6.11).
static func capacity_factors(world: World, db: ContentDB) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	out.resize((world.regions.size() - 1) * CAPACITY_FACTORS)
	var at: int = 0
	for i: int in range(1, world.regions.size()):
		var region: Region = world.regions[i]
		out[at] = world.modifiers.value(TARGET_CAPACITY, region.def)
		out[at + 1] = region.alive / float(region.def.population)
		out[at + 2] = 1.0 - region.control
		out[at + 3] = SocietalFunctionSystem.capacity_mul(region.society, db.balance)
		at += CAPACITY_FACTORS
	return out
