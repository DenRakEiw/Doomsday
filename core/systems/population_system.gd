class_name PopulationSystem
extends SimSystem
## Who dies, and what happens to a region that empties (core.md §7.4).
##
## Deaths are linear in the region's *initial* population, so a saturated region
## at Harm h empties in 1 / (daily_rate × h) days instead of decaying towards
## nobody for ever.


func tick(world: World, db: ContentDB, events: Array[SimEvent]) -> void:
	if world.agent.origin == 0:
		return
	for i: int in range(1, world.regions.size()):
		var region: Region = world.regions[i]
		# Nothing runs in a held region, so nobody there dies.
		if region.dark or region.dormant or region.alive <= 0.0:
			continue
		var harm: float = world.modifiers.value("harm", region.def)
		var dead: float = minf(region.alive, db.balance.harm_daily_rate * harm
			* region.penetration * float(region.def.population))
		region.alive -= dead
		region.deaths += dead
		# The last person is not worth a fraction: below one, the region is over.
		if region.alive < 1.0:
			region.deaths += region.alive
			region.alive = 0.0
			go_dark(world, region, i, events)


## A dark region is inert for good: no hardware, no relay, no yield, no
## anomalies, out of the world share, and counted as satisfied for Ascendance.
## Killing a region before the infection has moved on is how a route is lost.
##
## Static and public because a one-shot `harm_burst` empties regions outside the
## tick as well, and the rule must be written once.
static func go_dark(world: World, region: Region, index: int, events: Array[SimEvent]) -> void:
	region.dark = true
	region.penetration = 0.0
	# Everything standing there goes with it. The nodes stay owned: what was
	# lost is the place, not the knowledge (`loop-mechanics.md` §6.5).
	for kind: String in AssetDef.KINDS:
		var held: int = region.asset_count(kind)
		if held <= 0:
			continue
		world.set_assets(index, kind, 0)
		events.append(SimEvent.new(SimEvent.ASSET_LOST, world.day, {
			"kind": kind,
			"region": region.def.id,
			"count": held,
			"cause": SimEvent.CAUSE_DARK,
		}))
	var anomaly: Anomaly = world.anomaly_in_region(index)
	if anomaly != null:
		world.anomalies.erase(anomaly)
		events.append(SimEvent.new(SimEvent.ANOMALY_EXPIRED, world.day, {
			"anomaly": anomaly.id,
			"region": region.def.id,
		}))
	# A map event about this place has nothing left to be about.
	EventSystem.drop_in_region(world, index, events)
	events.append(SimEvent.new(SimEvent.REGION_DEPOPULATED, world.day, {"region": region.def.id}))
