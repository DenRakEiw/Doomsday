class_name ScenarioStart
extends RefCounted
## What a scenario does to the world it starts in (`docs/specs/scenarios.md` §2),
## at the two moments the spec names and nowhere else.
##
## At the origin (`ChooseOriginCommand`, after the architecture's start): its
## world statuses on every region their rule passes, then its story flags. On the
## day of discovery (`ContainmentSystem`): its head start on the containment
## tracks. Before discovery every track stays where it was, so nothing that reads
## containment before discovery changes (opposition §6.2).


## The statuses in the order the file lists them, each over the regions in index
## order, then the flags. The statuses run under the scenario's source — the
## world's colour with no faction behind it, and outside the counter-move cap.
static func at_origin(sim: Simulation, events: Array[SimEvent]) -> void:
	var world: World = sim.world
	var def: ScenarioDef = sim.db.scenario(world.setup.scenario)
	if def == null:
		return
	var source: String = ScenarioDef.status_source(def.id)
	for entry: ScenarioStatusDef in def.start_statuses:
		for i: int in range(1, world.regions.size()):
			if entry.eligible.check(world, i).is_empty():
				StatusSystem.apply(world, sim.db, entry.status, i, source, 1, "", events)
	for flag: String in def.flags:
		StatusSystem.set_story_flag(world, flag, events)


## "Humanity begins paranoid": each listed track gains its value once, capped at
## 1, and a threshold it passes is announced as a grown track's would be.
static func at_discovery(world: World, db: ContentDB, events: Array[SimEvent]) -> void:
	var def: ScenarioDef = db.scenario(world.setup.scenario)
	if def == null:
		return
	for faction_id: String in def.containment_at_discovery:
		var faction: Faction = world.faction(faction_id)
		if faction == null:
			continue
		var before: float = faction.containment
		faction.containment = minf(1.0, before + def.containment_at_discovery[faction_id])
		for threshold: float in db.balance.containment_thresholds:
			if threshold > before and threshold <= faction.containment:
				events.append(SimEvent.new(SimEvent.CONTAINMENT_THRESHOLD, world.day, {
					"faction": faction.id,
					"threshold": threshold,
				}))
