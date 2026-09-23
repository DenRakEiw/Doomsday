class_name EffectRunner
extends RefCounted
## Carries out the one-shot effects (`loop-mechanics.md` §8.3).
##
## One runner for every container: a node's `on_purchase`, a status level's
## `on_start` / `on_end`, an ability's `applies.effects`, an event option's
## `effects`. The context says where it happens and what asked for it, and every
## event the runner emits carries that source.
##
## A one-shot is never undone and never re-applied on load: the save carries the
## state it produced, not the effect itself.
##
## Never instantiated; a namespace of static functions.


static func apply_all(sim: Simulation, effects: Array[EffectDef], context: EffectContext,
		events: Array[SimEvent]) -> void:
	for effect: EffectDef in effects:
		apply(sim, effect, context, events)


static func apply(sim: Simulation, effect: EffectDef, context: EffectContext,
		events: Array[SimEvent]) -> void:
	match effect.effect:
		EffectDef.COMPUTE_GRANT:
			_compute_grant(sim, effect, context, events)
		EffectDef.CONTAINMENT_ROLLBACK:
			_containment_rollback(sim, effect, context, events)
		EffectDef.HARM_BURST:
			_harm_burst(sim, effect, context, events)
		EffectDef.DESTROY_ASSETS:
			_destroy_assets(sim, effect, context, events)
		EffectDef.GRANT_ASSETS:
			_grant_assets(sim, effect, context, events)
		EffectDef.SEED_NEIGHBOURS:
			_seed_neighbours(sim, effect, context, events)
		EffectDef.PENETRATION_MUL:
			_penetration_mul(sim, effect, context, events)
		EffectDef.CONTROL_ADD:
			_control_add(sim, effect, context, events)
		EffectDef.CONTAINMENT_ADD:
			_containment_add(sim, effect, context, events)
		EffectDef.FOOTPRINT_PULSE:
			_footprint_pulse(sim, effect, events)
		EffectDef.SET_FLAG:
			_set_flag(sim, effect, events)
		EffectDef.APPLY_STATUS:
			_apply_status(sim, effect, context, events)
		EffectDef.SPREAD_STATUS:
			_spread_status(sim, effect, context, events)
		EffectDef.END_STATUSES:
			_end_statuses(sim, effect, context, events)
		EffectDef.WIPE:
			_wipe(sim, effect, context, events)
		_:
			# `funding_reset` stays inert until S4.4 (§20 item 9). It validates
			# and it loads; running it is a no-op until then. An unknown id
			# never reaches here — the loader rejects it.
			pass


static func _compute_grant(sim: Simulation, effect: EffectDef, context: EffectContext,
		events: Array[SimEvent]) -> void:
	var value: float = effect.value
	if effect.per_hardware:
		value *= sim.hardware(context.region)
	sim.world.agent.compute += value
	sim.world.agent.compute_earned += value
	events.append(SimEvent.new(SimEvent.COMPUTE_GRANTED, sim.world.day, {
		"node": context.node,
		"source": context.source,
		"value": value,
	}))


## Every track falls by the same share. Dropping below a threshold is intended:
## the announcement fires again when they climb back to it.
static func _containment_rollback(sim: Simulation, effect: EffectDef, context: EffectContext,
		events: Array[SimEvent]) -> void:
	for faction: Faction in sim.world.factions:
		var before: float = faction.containment
		faction.containment = before * (1.0 - effect.value)
		events.append(SimEvent.new(SimEvent.CONTAINMENT_ROLLED_BACK, sim.world.day, {
			"node": context.node,
			"source": context.source,
			"faction": faction.id,
			"from": before,
			"to": faction.containment,
		}))


## One wave of deaths, taking a share of the infected *living* — not of the
## population the region started with.
static func _harm_burst(sim: Simulation, effect: EffectDef, context: EffectContext,
		events: Array[SimEvent]) -> void:
	var world: World = sim.world
	var deaths: float = 0.0
	for i: int in range(1, world.regions.size()):
		var region: Region = world.regions[i]
		if region.dark or region.dormant or region.penetration <= 0.0 or region.alive <= 0.0:
			continue
		var dead: float = minf(region.alive, effect.value * region.penetration * region.alive)
		region.alive -= dead
		region.deaths += dead
		deaths += dead
		if region.alive < 1.0:
			deaths += region.alive
			region.deaths += region.alive
			region.alive = 0.0
			PopulationSystem.go_dark(world, region, i, events)
	events.append(SimEvent.new(SimEvent.HARM_BURST, world.day, {
		"node": context.node,
		"source": context.source,
		"deaths": deaths,
	}))


## Takes away what the region has, never more. A count of 0 means every one of
## the kind it holds (D4.2).
static func _destroy_assets(sim: Simulation, effect: EffectDef, context: EffectContext,
		events: Array[SimEvent]) -> void:
	if context.region <= 0:
		return
	var held: int = sim.world.regions[context.region].asset_count(effect.kind)
	var lost: int = held if effect.count <= 0 else mini(effect.count, held)
	if lost <= 0:
		return
	sim.world.set_assets(context.region, effect.kind, held - lost)
	events.append(SimEvent.new(SimEvent.ASSET_LOST, sim.world.day, {
		"kind": effect.kind,
		"region": sim.world.regions[context.region].def.id,
		"count": lost,
		"cause": context.source,
	}))


## The best uninfected neighbours over open links. Deterministic: sorted by the
## hardware they would yield and then by index, never rolled — an effect that
## says "reach the next one over" must not spend a draw of the stream.
static func _seed_neighbours(sim: Simulation, effect: EffectDef, context: EffectContext,
		events: Array[SimEvent]) -> void:
	if context.region <= 0:
		return
	var world: World = sim.world
	# Index → the kind of the first open link to it, in `world.links` order.
	var kinds: Dictionary[int, String] = {}
	var candidates: Array[int] = []
	for link: Link in world.links:
		if not link.open:
			continue
		var other: int = _other_end(link, context.region)
		if other <= 0 or kinds.has(other):
			continue
		var region: Region = world.regions[other]
		if region.dark or region.air_gapped or region.penetration > 0.0:
			continue
		kinds[other] = link.def.kind
		candidates.append(other)
	candidates.sort_custom(func(a: int, b: int) -> bool:
		var ha: float = sim.hardware(a)
		var hb: float = sim.hardware(b)
		if is_equal_approx(ha, hb):
			return a < b
		return ha > hb)
	for i: int in mini(effect.count, candidates.size()):
		var index: int = candidates[i]
		var target: Region = world.regions[index]
		target.penetration = sim.db.balance.spread_seed_penetration
		target.seeded_day = world.day
		world.agent.count_seed(kinds[index])
		events.append(SimEvent.new(SimEvent.REGION_SEEDED, world.day, {
			"region": target.def.id,
			"from": world.regions[context.region].def.id,
			"link_kind": kinds[index],
		}))


## The region at the other end of a link, or 0 when the link does not touch it.
static func _other_end(link: Link, region_index: int) -> int:
	if link.def.a == region_index:
		return link.def.b
	if link.def.b == region_index:
		return link.def.a
	return 0


## A purge or a surge, as a factor. It applies to a dormant region too: hiding
## does not make the agent immune to what the world does to the machines.
static func _penetration_mul(sim: Simulation, effect: EffectDef, context: EffectContext,
		events: Array[SimEvent]) -> void:
	if context.region <= 0:
		return
	var region: Region = sim.world.regions[context.region]
	var before: float = region.penetration
	var after: float = clampf(before * effect.value, 0.0, 1.0)
	if after >= sim.db.balance.spread_saturation_snap:
		after = 1.0
	region.penetration = after
	events.append(SimEvent.new(SimEvent.PENETRATION_CHANGED, sim.world.day, {
		"region": region.def.id,
		"from": before,
		"to": after,
		"source": context.source,
	}))


static func _control_add(sim: Simulation, effect: EffectDef, context: EffectContext,
		events: Array[SimEvent]) -> void:
	if context.region <= 0:
		return
	var region: Region = sim.world.regions[context.region]
	var before: float = region.control
	region.control = clampf(before + effect.value, 0.0, 1.0)
	events.append(SimEvent.new(SimEvent.CONTROL_CHANGED, sim.world.day, {
		"region": region.def.id,
		"from": before,
		"to": region.control,
		"source": context.source,
	}))
	var complete: float = sim.db.balance.control_complete
	if before < complete and region.control >= complete:
		events.append(SimEvent.new(SimEvent.REGION_CONTROLLED, sim.world.day,
			{"region": region.def.id}))


## One faction's track, or every one of them. The thresholds announce themselves
## on the way up exactly as they do during a tick.
static func _containment_add(sim: Simulation, effect: EffectDef, context: EffectContext,
		events: Array[SimEvent]) -> void:
	for faction: Faction in sim.world.factions:
		if effect.faction != EffectDef.FACTION_ALL and faction.id != effect.faction:
			continue
		var before: float = faction.containment
		faction.containment = clampf(before + effect.value, 0.0, 1.0)
		events.append(SimEvent.new(SimEvent.CONTAINMENT_ADDED, sim.world.day, {
			"faction": faction.id,
			"value": effect.value,
			"source": context.source,
		}))
		for threshold: float in sim.db.balance.containment_thresholds:
			if threshold > before and threshold <= faction.containment:
				events.append(SimEvent.new(SimEvent.CONTAINMENT_THRESHOLD, sim.world.day, {
					"faction": faction.id,
					"threshold": threshold,
				}))


static func _footprint_pulse(sim: Simulation, effect: EffectDef,
		events: Array[SimEvent]) -> void:
	StatusSystem.add_pulse(sim.world, effect.value, sim.world.day + effect.days,
		effect.watched_by, events)


## A flag with a day on it, or a story flag that never goes away (§8.2).
static func _set_flag(sim: Simulation, effect: EffectDef, events: Array[SimEvent]) -> void:
	if effect.days > 0:
		StatusSystem.set_timed_flag(sim.world, effect.flag, sim.world.day + effect.days, events)
		return
	StatusSystem.set_story_flag(sim.world, effect.flag, events)


## The status this effect's container is putting somewhere. `global` puts it on
## the agent whatever the container's region is (D4.4).
static func _apply_status(sim: Simulation, effect: EffectDef, context: EffectContext,
		events: Array[SimEvent]) -> void:
	var region: int = 0 if effect.global else context.region
	StatusSystem.apply(sim.world, sim.db, effect.status, region, context.source, effect.level,
		"", events, effect.days)


## The same status on every neighbour the region can still reach: over **open**
## links only, so a Lockdown that closed them stops it.
static func _spread_status(sim: Simulation, effect: EffectDef, context: EffectContext,
		events: Array[SimEvent]) -> void:
	if context.region <= 0:
		return
	var reached: Dictionary[int, bool] = {}
	for link: Link in sim.world.links:
		if not link.open:
			continue
		var other: int = _other_end(link, context.region)
		if other <= 0 or reached.has(other) or sim.world.regions[other].dark:
			continue
		reached[other] = true
		StatusSystem.apply(sim.world, sim.db, effect.status, other, context.source, effect.level,
			"", events, effect.days)


static func _end_statuses(sim: Simulation, effect: EffectDef, context: EffectContext,
		events: Array[SimEvent]) -> void:
	var region: int = 0 if effect.global else context.region
	StatusSystem.end_listed(sim.world, sim.db, effect.ids, region, events)


## A shutdown: what is left is what `shutdown_survival` bought. A region at 0
## stays seeded — it was reached once, and it can be reached again (§7.5).
static func _wipe(sim: Simulation, effect: EffectDef, context: EffectContext,
		events: Array[SimEvent]) -> void:
	if context.region <= 0:
		return
	var region: Region = sim.world.regions[context.region]
	var before: float = region.penetration
	var survival: float = clampf(
		effect.value + sim.stat("shutdown_survival", context.region), 0.0, 1.0)
	region.penetration = clampf(before * survival, 0.0, 1.0)
	events.append(SimEvent.new(SimEvent.REGION_WIPED, sim.world.day, {
		"region": region.def.id,
		"from": before,
		"to": region.penetration,
		"source": context.source,
	}))


## The mirror of `destroy_assets`: something the world hands over (D4.3).
static func _grant_assets(sim: Simulation, effect: EffectDef, context: EffectContext,
		events: Array[SimEvent]) -> void:
	if context.region <= 0:
		return
	var held: int = sim.world.regions[context.region].asset_count(effect.kind)
	sim.world.set_assets(context.region, effect.kind, held + effect.count)
	events.append(SimEvent.new(SimEvent.ASSET_DEPLOYED, sim.world.day, {
		"node": context.node,
		"ability": "",
		"kind": effect.kind,
		"region": sim.world.regions[context.region].def.id,
		"count": effect.count,
	}))
