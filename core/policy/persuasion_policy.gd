class_name PersuasionPolicy
extends StrategyPolicy
## Persuasion (S4.10): the quiet win — offices, Lobby against every counter-move
## that lands, Pause when the tracks close in, the constitutional line to the
## end. It hates harm and footprint more than any other strategy.

const ID: String = "persuasion"


func _init() -> void:
	branch = TechNodeDef.BRANCH_PERSUASION
	origin_attrs = ["population", "wealth"]
	# The vectors first: devices for the caching and the leak for the persistence
	# that Dormancy needs. Indispensability needs one piece of infrastructure.
	path = ["consumer_devices", "open_weights_leak", "sycophancy_tuning",
		"personalised_persuasion", "elite_capture", "traffic_control", "indispensability",
		"regulatory_capture", "edge_caching", "host_persistence", "cold_storage_dormancy",
		"voluntary_pause", "constitutional_integration", "succession"]
	evasion_early = true
	abilities = ["lobby", "harvest", "pause"]
	_weights = {
		W_COMPUTE: 1.0, W_FOOTPRINT: -2.0, W_SEED: 2.0, W_HARM: -10.0, W_CONTAINMENT: -15.0,
		W_ASSET: 3.0, W_ASSET_LOST: -3.0, W_ENDURE: -3.0, W_PENETRATION: 3.0,
	}


func policy_id() -> String:
	return ID
