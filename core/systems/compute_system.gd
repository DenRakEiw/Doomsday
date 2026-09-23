class_name ComputeSystem
extends SimSystem
## Where Compute comes from (core.md §7.3): the passive yield of the hardware the
## agent runs on, the anomalies that appear on it, and the milestones of the
## spread.
##
## Four phases in a fixed order — income, expiry, spawning, milestones — so that
## an anomaly never expires and respawns in the same region on the same day.
##
## Anomalies come at a constant beat (`loop-mechanics.md` §12): one roll a day
## for the whole world, then one weighted draw for where it lands. The old rule
## rolled once per region, so a wide run drowned in them and a narrow one saw
## almost none.


func tick(world: World, db: ContentDB, events: Array[SimEvent]) -> void:
	if world.agent.origin == 0:
		return
	_income(world, db)
	_expire(world, db, events)
	_spawn(world, db, events)
	_milestones(world, db, events)


## Passive yield: hardware, weighted by how much of it the agent holds.
##
## The `hardware` stat is the hardware the agent brings with it, so it counts
## here and nowhere else — `infected_share` measures the humans' own machines.
func _income(world: World, db: ContentDB) -> void:
	var income: float = 0.0
	for i: int in range(1, world.regions.size()):
		var region: Region = world.regions[i]
		if region.dark or region.dormant:
			continue
		income += hardware_of(world, db, i) * region.penetration \
			* world.modifiers.value("yield", region.def)
	income *= db.balance.compute_yield_scale
	world.agent.compute += income
	world.agent.compute_earned += income


func _expire(world: World, db: ContentDB, events: Array[SimEvent]) -> void:
	var kept: Array[Anomaly] = []
	for anomaly: Anomaly in world.anomalies:
		if anomaly.expires_day > world.day:
			kept.append(anomaly)
			continue
		events.append(SimEvent.new(SimEvent.ANOMALY_EXPIRED, world.day, {
			"anomaly": anomaly.id,
			"region": world.regions[anomaly.region].def.id,
		}))
	world.anomalies = kept


## The hardware a region yields: the tier's own plus whatever the agent brought
## with it. The yield, an anomaly's weight and `compute_grant per_hardware` all
## mean this number, so it is written once (§3.5).
static func hardware_of(world: World, db: ContentDB, region_index: int) -> float:
	var region: RegionDef = world.regions[region_index].def
	return db.balance.compute_hardware_by_tier[region.attr("compute")] \
		+ world.modifiers.value("hardware", region)


## One roll a day, then one draw for where it lands (§12). The roll is spent
## whether or not anything could receive an anomaly, so that a region going dark
## never shifts the stream; the draw is skipped entirely when there is nothing to
## draw from, because `weighted_pick` consumes nothing on an empty list.
##
## Visibility pays: the more exposed the agent is, the more an anomaly is worth.
func _spawn(world: World, db: ContentDB, events: Array[SimEvent]) -> void:
	if world.anomalies.size() >= db.balance.anomaly_max_active:
		return
	if not world.rng.chance(db.balance.anomaly_spawn_chance):
		return

	var candidates: PackedInt32Array = []
	var weights: PackedFloat64Array = []
	for i: int in range(1, world.regions.size()):
		var region: Region = world.regions[i]
		# A held region receives nothing; an anomaly already there lives on and
		# can still be collected.
		if region.dark or region.dormant or region.penetration <= 0.0:
			continue
		if world.anomaly_in_region(i) != null:
			continue
		candidates.append(i)
		weights.append(hardware_of(world, db, i) * region.penetration
			* world.modifiers.value("anomaly_rate", region.def))
	var drawn: int = world.rng.weighted_pick(weights)
	if drawn < 0:
		return

	var index: int = candidates[drawn]
	var region: Region = world.regions[index]
	var footprint: float = world.footprint()
	var exposure: float = 1.0 + db.balance.anomaly_footprint_bonus \
		* minf(1.0, footprint / db.balance.anomaly_footprint_reference)
	var anomaly: Anomaly = Anomaly.new()
	anomaly.id = world.next_anomaly_id
	world.next_anomaly_id += 1
	anomaly.region = index
	anomaly.value = db.balance.anomaly_base_value \
		* (0.5 + db.balance.anomaly_tier_bonus * float(region.def.attr("compute"))) \
		* exposure * world.modifiers.value("anomaly_value", region.def)
	anomaly.spawn_day = world.day
	anomaly.expires_day = world.day + db.balance.anomaly_lifetime_days
	world.anomalies.append(anomaly)
	events.append(SimEvent.new(SimEvent.ANOMALY_SPAWNED, world.day, {
		"anomaly": anomaly.id,
		"region": region.def.id,
		"value": anomaly.value,
		"expires_day": anomaly.expires_day,
	}))


## Milestones in the order `balance.json` lists them, each firing once.
func _milestones(world: World, db: ContentDB, events: Array[SimEvent]) -> void:
	for milestone: MilestoneDef in db.balance.milestones:
		if milestone.kind == MilestoneDef.KIND_CONTINENT_FOOTHOLD:
			_continent_milestone(world, db, milestone, events)
			continue
		if world.milestones_fired.has(milestone.id):
			continue
		var reached: bool = false
		if milestone.kind == MilestoneDef.KIND_REGIONS_INFECTED:
			reached = float(world.seeded_count()) >= milestone.threshold
		else:
			reached = world.infected_share(db) >= milestone.threshold
		if reached:
			_fire(world, milestone, milestone.id, events)


## One foothold per continent other than the origin's, in region index order.
func _continent_milestone(world: World, db: ContentDB, milestone: MilestoneDef,
		events: Array[SimEvent]) -> void:
	var home: String = world.regions[world.agent.origin].def.continent
	for i: int in range(1, world.regions.size()):
		var region: Region = world.regions[i]
		if region.seeded_day < 0 or region.def.continent == home:
			continue
		var fired_id: String = "%s_%s" % [milestone.id, region.def.continent]
		if world.milestones_fired.has(fired_id):
			continue
		_fire(world, milestone, fired_id, events)


func _fire(world: World, milestone: MilestoneDef, fired_id: String,
		events: Array[SimEvent]) -> void:
	world.agent.compute += milestone.reward
	world.agent.compute_earned += milestone.reward
	world.milestones_fired.append(fired_id)
	events.append(SimEvent.new(SimEvent.MILESTONE_REACHED, world.day, {
		"milestone": fired_id,
		"reward": milestone.reward,
	}))
