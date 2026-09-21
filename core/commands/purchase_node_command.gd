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


func to_dict() -> Dictionary:
	var d: Dictionary = super()
	d["node"] = node
	return d
