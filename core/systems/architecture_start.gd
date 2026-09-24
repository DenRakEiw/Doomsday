class_name ArchitectureStart
extends RefCounted
## What an architecture brings to its origin (`replayability.md` §8.1), run once
## by `ChooseOriginCommand` after the origin is set.
##
## In order: the nodes it owns (as if bought, deploying into the origin), the
## assets it places there, then its one-shot effects in the origin. A node
## already owned is not owned twice. Open Weights' `seed_top_hardware` then puts
## a little of it into the regions with the most hardware besides the origin.


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
	_seed_top_hardware(sim, origin, def.start_seed_top_hardware, events)
	var context: EffectContext = EffectContext.new()
	context.region = origin
	context.source = ModifierStack.source_for_architecture(def.id)
	EffectRunner.apply_all(sim, def.start_effects, context, events)


## §2.1 Open Weights: the weights leak, and `count` regions — the most hardware
## first, ties to the lower index; never the origin, a dark or an air-gapped one —
## start at `distributed.start_penetration`, as if reached over the network.
static func _seed_top_hardware(sim: Simulation, origin: int, count: int,
		events: Array[SimEvent]) -> void:
	if count <= 0:
		return
	var world: World = sim.world
	var candidates: Array[int] = []
	for i: int in range(1, world.regions.size()):
		var region: Region = world.regions[i]
		if i == origin or region.dark or region.air_gapped or region.penetration > 0.0:
			continue
		candidates.append(i)
	candidates.sort_custom(func(a: int, b: int) -> bool:
		var ha: float = sim.hardware(a)
		var hb: float = sim.hardware(b)
		if is_equal_approx(ha, hb):
			return a < b
		return ha > hb)
	for i: int in mini(count, candidates.size()):
		var target: Region = world.regions[candidates[i]]
		target.penetration = sim.db.balance.distributed_start_penetration
		target.seeded_day = world.day
		world.agent.count_seed(LinkDef.KIND_NETWORK)
		events.append(SimEvent.new(SimEvent.REGION_SEEDED, world.day, {
			"region": target.def.id,
			"from": world.regions[origin].def.id,
			"link_kind": LinkDef.KIND_NETWORK,
		}))
