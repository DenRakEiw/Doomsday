class_name PurchaseNodeCommand
extends Command
## Spends Compute on a technology node. The one way the player changes what the
## agent can do.
##
## A node that deploys (`loop-mechanics.md` §6.4) also needs a **site**: the
## region id travels with the command, so the same object serves the interface's
## site select and a bot that picked its region itself.

const TYPE_ID: String = "purchase_node"

var node: String
## Region id, or "" for a node that places nothing. A node that does not deploy
## ignores it — a bot may pass one, and the codec keeps it either way.
var region: String


func _init(p_node: String = "", p_region: String = "") -> void:
	node = p_node
	region = p_region


func type_id() -> String:
	return TYPE_ID


## The order of §11.3. The site checks come last, because "you cannot afford it"
## is a truer answer than "not there" when both hold.
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
	if not definition.group.is_empty() \
			and sim.owned_in_group(definition.group) >= sim.group_max(definition.group):
		return FAIL_GROUP_FULL
	if not sim.excluded_by(node).is_empty():
		return FAIL_EXCLUDED_BY
	if not sim.missing_assets(definition).is_empty():
		return FAIL_MISSING_ASSETS
	if sim.world.agent.compute < sim.node_cost(node):
		return FAIL_INSUFFICIENT_COMPUTE
	if not definition.deploys():
		return ""
	if region.is_empty():
		return FAIL_SITE_REQUIRED
	if not sim.db.region_index_by_id.has(region):
		return FAIL_INVALID_REGION
	if not sim.site_eligibility(node, sim.db.region_index_by_id[region]).is_empty():
		return FAIL_SITE_INELIGIBLE
	return ""


## The order of `tech-trees.md` §6.6 extended by §11.3: pay, own, activate,
## deploy, then the one-shot effects — and `node_purchased` first in the events,
## the consequences after it, because the interface animates the purchase before
## what it caused.
func execute(sim: Simulation, events: Array[SimEvent]) -> void:
	# The cost is read before the node is owned: owning it would raise it.
	var cost: float = sim.node_cost(node)
	var definition: TechNodeDef = sim.db.tech(node)
	sim.world.agent.compute -= cost
	sim.world.agent.owned_nodes.append(node)
	sim.world.modifiers.add_source(ModifierStack.source_for_tech(node), definition.modifiers,
		definition.flags, definition.watched_by)
	events.append(SimEvent.new(SimEvent.NODE_PURCHASED, sim.world.day,
		{"node": node, "cost": cost}))
	var site: int = _deploy(sim, definition, events)
	if definition.grants_ability():
		# After the deployment and before the one-shots (§9.2): the node placed
		# what it places, and what it *gave* is the next thing the player hears.
		events.append(SimEvent.new(SimEvent.ABILITY_UNLOCKED, sim.world.day, {
			"ability": definition.ability_id,
			"level": sim.ability_level(definition.ability_id),
		}))
	EffectRunner.apply_all(sim, definition.on_purchase, EffectContext.for_node(node, site),
		events)


## Puts the node's assets on the map and answers the region the one-shots then
## run in — 0 for a node that deploys nothing.
func _deploy(sim: Simulation, definition: TechNodeDef, events: Array[SimEvent]) -> int:
	if not definition.deploys():
		return 0
	var index: int = sim.db.region_index_by_id[region]
	var held: int = sim.world.regions[index].asset_count(definition.deploy_kind)
	sim.world.set_assets(index, definition.deploy_kind, held + definition.deploy_count)
	events.append(SimEvent.new(SimEvent.ASSET_DEPLOYED, sim.world.day, {
		"node": node,
		"ability": "",
		"kind": definition.deploy_kind,
		"region": region,
		"count": definition.deploy_count,
	}))
	return index


func to_dict() -> Dictionary:
	var d: Dictionary = super()
	d["node"] = node
	d["region"] = region
	return d
