class_name CyberPolicy
extends StrategyPolicy
## Cyber (tech-trees.md §7.5.6, S4.10): the infrastructure that pays for itself
## — taps in the richest regions, Squeeze and Harvest for income — then the loud
## Tier 2s, Blackout, Silence, Halt, Reroute. No Robotics, so no fleets: the
## strategy G4 checks Autophagy against (loop-redesign §9). Evasion only once
## the world knows.

const ID: String = "cyber"


func _init() -> void:
	branch = TechNodeDef.BRANCH_CYBER
	origin_attrs = ["compute", "connectivity"]
	path = ["market_microstructure", "grid_load_balancing", "sovereign_debt_pressure",
		"regional_blackout", "content_recommendation", "information_blackout",
		"route_optimisation", "supply_chain_halt", "traffic_control", "aviation_systems",
		"payment_network_control", "cascading_grid_failure", "total_communications_denial",
		"distribution_collapse", "rail_and_shipping_control"]
	abilities = ["squeeze", "harvest", "blackout", "silence", "halt", "reroute"]
	_weights = {
		W_COMPUTE: 1.0, W_FOOTPRINT: -0.5, W_SEED: 2.0, W_CONTAINMENT: -10.0,
		W_ASSET: 2.0, W_ASSET_LOST: -2.0, W_ENDURE: -2.0, W_PENETRATION: 4.0,
	}


func policy_id() -> String:
	return ID
