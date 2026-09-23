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


## The daily discovery risk of §7.5, without rolling for it. The three terms are
## reported after the `discovery` factor and before the clamp, so they add up to
## `total` unless the clamp bit.
static func discovery_risk(world: World, db: ContentDB) -> Dictionary:
	var factor: float = world.modifiers.value("discovery")
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
## and contribution; the pressure is `1 + Σ contribution`.
static func containment_breakdown(world: World, db: ContentDB, faction_id: String) -> Dictionary:
	var definition: FactionDef = db.faction(faction_id)
	if definition == null:
		push_error("unknown faction \"%s\"" % faction_id)
		return {}
	var terms: Array[Dictionary] = []
	var sum: float = 0.0
	for term: FactionTermDef in definition.terms:
		var value: float = term.value(world, db, faction_id)
		var contribution: float = term.weight * value
		sum += contribution
		terms.append({
			TERM_SOURCE: term.source,
			TERM_TREE: term.tree,
			TERM_KIND: term.kind,
			TERM_WEIGHT: term.weight,
			TERM_VALUE: value,
			TERM_CONTRIBUTION: contribution,
		})
	var pressure: float = 1.0 + sum
	var capacity: float = _capacity(world, db, definition.capacity_attr)
	var brakes: float = world.modifiers.value("containment_growth") \
		* world.modifiers.value(definition.brake)
	return {
		TERMS: terms,
		PRESSURE: pressure,
		CAPACITY: capacity,
		BRAKES: brakes,
		GAIN: db.balance.containment_base_rate * pressure * capacity * brakes,
	}


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
		# day to react.
		return
	_grow(world, db, events)


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


## Killing or controlling the regions a faction draws on is what slows it down
## — the race both win conditions are built on. Every gain is read before any
## track moves, so the order of the factions changes nothing but the order of
## the events.
func _grow(world: World, db: ContentDB, events: Array[SimEvent]) -> void:
	var leader_before: String = _leader_tracked(world)
	var gains: Array[float] = []
	for faction: Faction in world.factions:
		gains.append(float(containment_breakdown(world, db, faction.id)[GAIN]))

	for i: int in world.factions.size():
		var faction: Faction = world.factions[i]
		var before: float = faction.containment
		faction.containment = minf(1.0, faction.containment + gains[i])
		for threshold: float in db.balance.containment_thresholds:
			if threshold > before and threshold <= faction.containment:
				events.append(SimEvent.new(SimEvent.CONTAINMENT_THRESHOLD, world.day, {
					"faction": faction.id,
					"threshold": threshold,
				}))

	var leader_after: String = threat_leader(world)
	if leader_after != leader_before:
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
static func _capacity(world: World, db: ContentDB, attribute: String) -> float:
	var weighted: float = 0.0
	var total: float = 0.0
	for i: int in range(1, world.regions.size()):
		var region: Region = world.regions[i]
		var weight: float = db.balance.containment_capacity_weight_by_tier[
			region.def.attr(attribute)]
		total += weight
		weighted += weight * world.modifiers.value(TARGET_CAPACITY, region.def) \
			* (region.alive / float(region.def.population)) * (1.0 - region.control) \
			* SocietalFunctionSystem.capacity_mul(region.society, db.balance)
	if total <= 0.0:
		return 0.0
	return weighted / total
