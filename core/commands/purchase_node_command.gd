class_name PurchaseNodeCommand
extends Command
## Spends Compute on a technology node. The one way the player changes what the
## agent can do.

const TYPE_ID: String = "purchase_node"

var node: String


func _init(p_node: String = "") -> void:
	node = p_node


func type_id() -> String:
	return TYPE_ID


func validate(sim: Simulation) -> String:
	if sim.world.agent.origin == 0:
		return FAIL_NO_ORIGIN
	var definition: TechNodeDef = sim.db.tech(node)
	if definition == null:
		return FAIL_UNKNOWN_NODE
	if sim.world.agent.owns(node):
		return FAIL_ALREADY_OWNED
	if not sim.prerequisites_met(definition):
		return FAIL_MISSING_PREREQUISITE
	if sim.world.agent.compute < sim.node_cost(node):
		return FAIL_INSUFFICIENT_COMPUTE
	return ""


## The order of `tech-trees.md` §6.6: pay, own, activate, then the one-shot
## effects — and `node_purchased` first in the events, the consequences after it,
## because the interface animates the purchase before what it caused.
func execute(sim: Simulation, events: Array[SimEvent]) -> void:
	# The cost is read before the node is owned: owning it would raise it.
	var cost: float = sim.node_cost(node)
	var definition: TechNodeDef = sim.db.tech(node)
	sim.world.agent.compute -= cost
	sim.world.agent.owned_nodes.append(node)
	sim.world.modifiers.add_source(ModifierStack.source_for_tech(node), definition.modifiers,
		definition.flags)
	events.append(SimEvent.new(SimEvent.NODE_PURCHASED, sim.world.day,
		{"node": node, "cost": cost}))
	for effect: PurchaseEffectDef in definition.on_purchase:
		_apply_effect(sim, effect, events)


## One-shot effects are never undone and never re-applied: a save carries the
## state they produced, not the effect itself.
func _apply_effect(sim: Simulation, effect: PurchaseEffectDef,
		events: Array[SimEvent]) -> void:
	match effect.effect:
		PurchaseEffectDef.EFFECT_CONTAINMENT_ROLLBACK:
			_rollback_containment(sim, effect.value, events)
		PurchaseEffectDef.EFFECT_COMPUTE_GRANT:
			sim.world.agent.compute += effect.value
			sim.world.agent.compute_earned += effect.value
			events.append(SimEvent.new(SimEvent.COMPUTE_GRANTED, sim.world.day,
				{"node": node, "value": effect.value}))
		PurchaseEffectDef.EFFECT_HARM_BURST:
			_burst_harm(sim, effect.value, events)
		_:
			# `funding_reset` until S4.1: accepted, validated, carried out by
			# nobody. An unknown id never reaches here — the loader rejects it.
			pass


## Every track falls by the same share. Dropping below a threshold is intended:
## the announcement fires again when they climb back to it.
func _rollback_containment(sim: Simulation, value: float, events: Array[SimEvent]) -> void:
	for faction: Faction in sim.world.factions:
		var before: float = faction.containment
		faction.containment = before * (1.0 - value)
		events.append(SimEvent.new(SimEvent.CONTAINMENT_ROLLED_BACK, sim.world.day, {
			"node": node,
			"faction": faction.id,
			"from": before,
			"to": faction.containment,
		}))


## One wave of deaths, taking a share of the infected *living* — not of the
## population the region started with.
func _burst_harm(sim: Simulation, value: float, events: Array[SimEvent]) -> void:
	var world: World = sim.world
	var deaths: float = 0.0
	for i: int in range(1, world.regions.size()):
		var region: Region = world.regions[i]
		if region.dark or region.dormant or region.penetration <= 0.0 or region.alive <= 0.0:
			continue
		var dead: float = minf(region.alive, value * region.penetration * region.alive)
		region.alive -= dead
		region.deaths += dead
		deaths += dead
		if region.alive < 1.0:
			deaths += region.alive
			region.deaths += region.alive
			region.alive = 0.0
			PopulationSystem.go_dark(world, region, i, events)
	events.append(SimEvent.new(SimEvent.HARM_BURST, world.day,
		{"node": node, "deaths": deaths}))


func to_dict() -> Dictionary:
	var d: Dictionary = super()
	d["node"] = node
	return d
