class_name HistorySystem
extends SimSystem
## A bounded record of the run (core.md §7.8, analysis.md §3.1): a sample every
## `World.history_stride` days from the origin and once more on the tick that
## ends it.
##
## Bounded by thinning, not by a longer interval: when the record passes
## `history.max_samples`, every second sample goes and the stride doubles, so a
## save holds a few hundred rows whatever the run's length and the early days
## keep their daily resolution. Runs last, so its last sample carries the
## outcome's own day. It emits no events and nothing in the simulation reads it.


func tick(world: World, db: ContentDB, events: Array[SimEvent]) -> void:
	if world.agent.origin == 0:
		return
	var offset: int = world.day - world.origin_day
	var due: bool = offset % world.history_stride == 0 or world.outcome != World.Outcome.NONE
	if not due:
		return
	if not world.history.is_empty() and world.history[world.history.size() - 1].day == world.day:
		return
	world.history.append(sample(world, db))
	if world.history.size() > db.balance.history_max_samples:
		_thin(world)


## The world as it stands, as one row. Pure: it reads, it never draws.
static func sample(world: World, db: ContentDB) -> HistorySample:
	var row: HistorySample = HistorySample.new()
	row.day = world.day
	row.compute = world.agent.compute
	row.compute_earned = world.agent.compute_earned
	row.seeded = world.seeded_count()
	row.share = world.infected_share(db)
	row.alive = world.alive_total()
	row.deaths = world.deaths_total()
	row.containment = world.max_containment()
	row.footprint = world.footprint()
	row.phase = World.PHASE_IDS[world.phase]
	for faction: Faction in world.factions:
		row.containment_by_faction[faction.id] = faction.containment
		row.pressure_by_faction[faction.id] = ContainmentSystem.pressure(world, db, faction.id)
	row.risk = 0.0 if world.discovered \
		else float(ContainmentSystem.discovery_risk(world, db)[ContainmentSystem.RISK_TOTAL])
	row.harm = world.max_harm()
	row.controlled = world.controlled_count(db)
	row.dark = world.dark_count()
	row.stage_counts.resize(HistorySample.STAGE_COUNT)
	row.stage_counts.fill(0)
	for i: int in range(1, world.regions.size()):
		var region: Region = world.regions[i]
		if not region.dark:
			row.stage_counts[SocietalFunctionSystem.stage(region.society, db.balance)] += 1
	for kind: String in AssetDef.KINDS:
		row.assets[kind] = world.asset_total(kind)
	row.starving_days = world.starving_days
	return row


## Keeps the samples at even indices and the last one, and doubles the stride:
## the kept offsets are multiples of the new stride, so the next sample lines up
## with them. The first sample (offset 0) always stays.
static func _thin(world: World) -> void:
	var kept: Array[HistorySample] = []
	var last: int = world.history.size() - 1
	for i: int in world.history.size():
		if i % 2 == 0 or i == last:
			kept.append(world.history[i])
	world.history = kept
	world.history_stride *= 2
