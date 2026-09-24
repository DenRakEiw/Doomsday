class_name ArchitectureStart
extends RefCounted
## What an architecture brings to its origin (`replayability.md` §8.1), run once
## by `ChooseOriginCommand` after the origin is set.
##
## In order: the nodes it owns (as if bought, deploying into the origin), the
## assets it places there, then its one-shot effects in the origin. A node
## already owned is not owned twice. `seed_top_hardware` is Open Weights' and
## arrives with it in S5.2.


static func apply(sim: Simulation, origin: int, events: Array[SimEvent]) -> void:
	var def: ArchitectureDef = sim.world.architecture(sim.db)
	for node_id: String in def.start_owned:
		var node: TechNodeDef = sim.db.tech(node_id)
		if node == null or sim.world.agent.owns(node_id):
			continue
		PurchaseNodeCommand.own(sim, node, origin if node.deploys() else 0, 0.0, events)
	for kind: String in def.start_assets:
		var count: int = def.start_assets[kind]
		var held: int = sim.world.regions[origin].asset_count(kind)
		sim.world.set_assets(origin, kind, held + count)
		events.append(SimEvent.new(SimEvent.ASSET_DEPLOYED, sim.world.day, {
			"node": "",
			"ability": "",
			"kind": kind,
			"region": sim.world.regions[origin].def.id,
			"count": count,
		}))
	var context: EffectContext = EffectContext.new()
	context.region = origin
	context.source = ModifierStack.source_for_architecture(def.id)
	EffectRunner.apply_all(sim, def.start_effects, context, events)
