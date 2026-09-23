class_name ContainmentSystem
extends SimSystem
## Being found, and then being hunted (core.md §7.5).
##
## M1 has one track. S4.1 gives the four factions their own watched signals and
## timescales; the loop below already runs over `world.factions`, so nothing here
## has to be rewritten for that.
##
## The two formulas are also the two pure queries of `m3-screens.md` §10.5: the
## containment panel asks for exactly what the tick is about to do, and reads it
## out of this file rather than repeating it.

## Keys of `discovery_risk`.
const RISK_TOTAL: String = "total"
const RISK_TIME: String = "time"
const RISK_FOOTPRINT: String = "footprint"
const RISK_BREADTH: String = "breadth"
## Keys of `containment_breakdown`.
const DRIVER_FOOTPRINT: String = "footprint"
const DRIVER_HARM: String = "harm"
const DRIVER_SHARE: String = "share"
const DRIVER_CAPACITY: String = "capacity"
const DRIVER_BRAKES: String = "brakes"
const DRIVER_GAIN: String = "gain"
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


## What the next tick will add to every containment track, and what it is made
## of. `footprint`, `harm` and `share` are the three terms of the pressure sum as
## §4.1 shows them — each `1 + rate × value`; the pressure itself is their sum
## minus 2, because the 1 is counted once (PROGRESS.md, *Design questions*).
static func containment_breakdown(world: World, db: ContentDB) -> Dictionary:
	var share: float = world.infected_share(db)
	var footprint: float = 1.0 + db.balance.containment_per_footprint * world.footprint()
	var harm: float = 1.0 + db.balance.containment_per_harm * world.modifiers.value("harm")
	var spread: float = 1.0 + db.balance.containment_per_share * share
	var capacity: float = _capacity(world, db)
	var brakes: float = world.modifiers.value("containment_growth")
	return {
		DRIVER_FOOTPRINT: footprint,
		DRIVER_HARM: harm,
		DRIVER_SHARE: spread,
		DRIVER_CAPACITY: capacity,
		DRIVER_BRAKES: brakes,
		DRIVER_GAIN: db.balance.containment_base_rate * (footprint + harm + spread - 2.0)
			* capacity * brakes,
	}


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


## Killing or controlling the regions that do the research is what slows this
## down — the race both win conditions are built on.
func _grow(world: World, db: ContentDB, events: Array[SimEvent]) -> void:
	var gain: float = float(containment_breakdown(world, db)[DRIVER_GAIN])

	for faction: Faction in world.factions:
		var before: float = faction.containment
		faction.containment = minf(1.0, faction.containment + gain)
		for threshold: float in db.balance.containment_thresholds:
			if threshold > before and threshold <= faction.containment:
				events.append(SimEvent.new(SimEvent.CONTAINMENT_THRESHOLD, world.day, {
					"faction": faction.id,
					"threshold": threshold,
				}))


## How much of the world's research is still alive and still its own, weighted by
## research tier. Every region counts towards the denominator, so a dark region
## does not make the survivors look more capable.
##
## `containment_capacity` scales the numerator only (§7.5): a region whose
## laboratories are dark lowers the world's capacity, it does not vanish from the
## world — which is what a denominator scaled with it would mean.
static func _capacity(world: World, db: ContentDB) -> float:
	var weighted: float = 0.0
	var total: float = 0.0
	for i: int in range(1, world.regions.size()):
		var region: Region = world.regions[i]
		var weight: float = db.balance.containment_research_weight_by_tier[
			region.def.attr("research")]
		total += weight
		weighted += weight * world.modifiers.value(TARGET_CAPACITY, region.def) \
			* (region.alive / float(region.def.population)) * (1.0 - region.control)
	if total <= 0.0:
		return 0.0
	return weighted / total
