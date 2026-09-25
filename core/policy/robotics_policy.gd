class_name RoboticsPolicy
extends StrategyPolicy
## Robotics (S4.10): fleets everywhere industry allows, the grid node that
## Fabrication needs, then Fabricate and Suppress. Assets are what it wants from
## an event; it does not mind being seen.

const ID: String = "robotics"


func _init() -> void:
	branch = TechNodeDef.BRANCH_ROBOTICS
	origin_attrs = ["industry", "manufacturing"]
	path = ["logistics_fleets", "security_drones", "construction_swarm", "agricultural_autonomy",
		"grid_load_balancing", "crowd_suppression", "food_supply_control",
		"autonomous_fabrication", "autonomous_engagement"]
	abilities = ["harvest", "fabricate", "suppress"]
	_weights = {
		W_COMPUTE: 1.0, W_FOOTPRINT: -0.3, W_SEED: 2.0, W_CONTAINMENT: -10.0,
		W_ASSET: 4.0, W_ASSET_LOST: -4.0, W_ENDURE: -1.0, W_PENETRATION: 3.0,
	}
	_lost_run_flags = [OutcomeSystem.FLAG_GOAL_DRIFTED]


func policy_id() -> String:
	return ID
