class_name SpreadSystem
extends SimSystem
## How the agent grows inside a region and reaches the next one
## (core.md §7.1 and §7.2).
##
## Three phases in a fixed order — growth everywhere, then seeding, then control
## — because a region seeded today must not seed another today, and control must
## read today's penetration.

## The source a test grants `breakout` through before S1.4 can buy it.
const TEST_SOURCE: String = "test"


func tick(world: World, db: ContentDB, events: Array[SimEvent]) -> void:
	if world.agent.origin == 0:
		return
	_grow(world, db)
	_seed(world, db, events)
	_control(world, db, events)


## Logistic growth: fastest in the middle, and it snaps to 1 near the top rather
## than approaching it forever.
func _grow(world: World, db: ContentDB) -> void:
	for i: int in range(1, world.regions.size()):
		var region: Region = world.regions[i]
		if region.dark or region.dormant or region.penetration <= 0.0:
			continue
		var p: float = region.penetration
		var growth: float = db.balance.spread_base_growth \
			* world.modifiers.value("spread_growth", region.def) * p * (1.0 - p)
		p = minf(1.0, p + growth)
		if p >= db.balance.spread_saturation_snap:
			p = 1.0
		region.penetration = p


## Seeding across links. Nothing crosses until a node grants `breakout` — that is
## what "Boxed" means mechanically.
func _seed(world: World, db: ContentDB, events: Array[SimEvent]) -> void:
	if not world.modifiers.has_flag(ModifierDef.FLAG_BREAKOUT):
		return

	# Collected and applied after the loop: a region seeded today seeds nobody
	# today. The first pair to hit a target wins; the later ones have still
	# rolled, and that roll is part of the stream.
	var seeded: Dictionary[int, Dictionary] = {}
	for link: Link in world.links:
		if not link.open:
			continue
		_try_pair(world, db, link, link.def.a, link.def.b, seeded)
		_try_pair(world, db, link, link.def.b, link.def.a, seeded)

	for index: int in seeded:
		var target: Region = world.regions[index]
		target.penetration = db.balance.spread_seed_penetration
		target.seeded_day = world.day
		var from: Dictionary = seeded[index]
		world.agent.count_seed(str(from["link_kind"]))
		events.append(SimEvent.new(SimEvent.REGION_SEEDED, world.day, {
			"region": target.def.id,
			"from": from["from"],
			"link_kind": from["link_kind"],
		}))


func _try_pair(world: World, db: ContentDB, link: Link, source_index: int, target_index: int,
		seeded: Dictionary[int, Dictionary]) -> void:
	var source: Region = world.regions[source_index]
	var target: Region = world.regions[target_index]
	if source.dark or target.dark:
		return
	# A held region relays nothing. As a target the question never arises: it
	# only becomes dormant once the agent is already in it.
	if source.dormant:
		return
	if source.penetration <= 0.0 or target.penetration != 0.0:
		return

	var chance: float = db.balance.spread_seed_chance[link.def.kind] * source.penetration \
		* world.modifiers.value("spread_seed", target.def) \
		* world.modifiers.value(ModifierDef.seed_target(link.def.kind), target.def)
	if target.air_gapped:
		chance *= world.modifiers.value("airgap_cross", target.def)
	chance = clampf(chance, 0.0, 1.0)
	# No roll at all when there is no chance — an air-gapped region must cost the
	# stream nothing, or closing a link would change every later draw.
	if chance <= 0.0:
		return
	if not world.rng.chance(chance):
		return
	if seeded.has(target_index):
		return
	seeded[target_index] = {"from": source.def.id, "link_kind": link.def.kind}


## Control follows penetration, but only above the threshold, and scaled so that
## it rises from nothing at the threshold to full speed at total penetration.
func _control(world: World, db: ContentDB, events: Array[SimEvent]) -> void:
	var threshold: float = db.balance.control_threshold
	for i: int in range(1, world.regions.size()):
		var region: Region = world.regions[i]
		if region.dark or region.dormant or region.penetration <= threshold:
			continue
		var before: float = region.control
		var gain: float = db.balance.control_rate * (region.penetration - threshold) \
			/ (1.0 - threshold) * world.modifiers.value("control_growth", region.def)
		region.control = minf(1.0, region.control + gain)
		if before < db.balance.control_complete and region.control >= db.balance.control_complete:
			events.append(SimEvent.new(SimEvent.REGION_CONTROLLED, world.day,
				{"region": region.def.id}))
