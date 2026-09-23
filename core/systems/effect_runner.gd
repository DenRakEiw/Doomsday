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
		_:
			# `funding_reset` stays inert until S4.4 (§20 item 9), and the
			# effects of `EffectDef.PENDING_EFFECTS` need the status machinery
			# S4.2 and S4.3 build. Both validate and load; neither runs yet.
			# An unknown id never reaches here — the loader rejects it.
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
