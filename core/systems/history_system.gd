class_name HistorySystem
extends SimSystem
## A bounded record of the run, sampled every `history.interval_days` and once
## more on the tick that ends it (core.md §7.8).
##
## Runs last, so that its last sample carries the outcome's own day. It emits no
## events and nothing in the simulation reads it back: it is what the Analysis
## screen of M4 draws.


func tick(world: World, db: ContentDB, events: Array[SimEvent]) -> void:
	if world.agent.origin == 0:
		return
	var due: bool = world.day % db.balance.history_interval_days == 0 \
		or world.outcome != World.Outcome.NONE
	if not due:
		return
	if not world.history.is_empty() and world.history[world.history.size() - 1].day == world.day:
		return

	var sample: HistorySample = HistorySample.new()
	sample.day = world.day
	sample.compute = world.agent.compute
	sample.compute_earned = world.agent.compute_earned
	sample.seeded = world.seeded_count()
	sample.share = world.infected_share(db)
	sample.alive = world.alive_total()
	sample.deaths = world.deaths_total()
	sample.containment = world.max_containment()
	sample.footprint = world.footprint()
	sample.phase = World.PHASE_IDS[world.phase]
	world.history.append(sample)
