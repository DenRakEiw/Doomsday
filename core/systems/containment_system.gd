class_name ContainmentSystem
extends SimSystem
## Being found, and then being hunted (core.md §7.5).
##
## M1 has one track. S4.1 gives the four factions their own watched signals and
## timescales; the loop below already runs over `world.factions`, so nothing here
## has to be rewritten for that.


func tick(world: World, db: ContentDB, events: Array[SimEvent]) -> void:
	if world.agent.origin == 0:
		return
	var share: float = world.infected_share(db)
	var footprint: float = world.footprint()

	if not world.discovered:
		_try_discovery(world, db, share, footprint, events)
		# Containment does not grow on the day of discovery: the world needs a
		# day to react.
		return
	_grow(world, db, share, footprint, events)


## The scrutiny term grows with time, so even a perfectly quiet agent is found
## eventually and a run cannot stall.
func _try_discovery(world: World, db: ContentDB, share: float, footprint: float,
		events: Array[SimEvent]) -> void:
	var cause: String = ""
	if world.deaths_total() / db.population_total >= db.balance.discovery_deaths_certain_share:
		# Deaths on that scale are not something anybody has to roll for.
		cause = SimEvent.CAUSE_DEATHS
	else:
		var risk: float = clampf((db.balance.discovery_scrutiny_per_day
			* float(world.day - world.origin_day)
			+ db.balance.discovery_per_footprint * footprint
			+ db.balance.discovery_breadth_rate
			* maxf(0.0, share - db.balance.discovery_breadth_free))
			* world.modifiers.value("discovery"), 0.0, 1.0)
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
func _grow(world: World, db: ContentDB, share: float, footprint: float,
		events: Array[SimEvent]) -> void:
	var capacity: float = _capacity(world, db)
	var pressure: float = 1.0 + db.balance.containment_per_footprint * footprint \
		+ db.balance.containment_per_harm * world.modifiers.value("harm") \
		+ db.balance.containment_per_share * share
	var gain: float = db.balance.containment_base_rate * pressure * capacity \
		* world.modifiers.value("containment_growth")

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
func _capacity(world: World, db: ContentDB) -> float:
	var weighted: float = 0.0
	var total: float = 0.0
	for i: int in range(1, world.regions.size()):
		var region: Region = world.regions[i]
		var weight: float = db.balance.containment_research_weight_by_tier[
			region.def.attr("research")]
		total += weight
		weighted += weight * (region.alive / float(region.def.population)) * (1.0 - region.control)
	if total <= 0.0:
		return 0.0
	return weighted / total
