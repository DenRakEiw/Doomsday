class_name BiologyPolicy
extends StrategyPolicy
## Biology (S4.10): quiet until the labs are built — Evasion from the start,
## the persuasion cover the branch needs, the lab chain — then Release. The
## strategy G4 checks Extinction against (loop-redesign §9), so a harm burst in
## an event option is worth something to it.

const ID: String = "biology"


func _init() -> void:
	branch = TechNodeDef.BRANCH_BIOLOGY
	origin_attrs = ["research", "population"]
	# The vectors first: research for the labs, the leak for the proxies that
	# distributed synthesis needs. The lab needs Elite Capture (or a swarm).
	path = ["research_networks", "open_weights_leak", "structure_prediction",
		"sycophancy_tuning", "personalised_persuasion", "elite_capture",
		"automated_laboratory_access", "therapeutic_cover", "novel_agent_design",
		"human_proxies", "distributed_synthesis", "release"]
	evasion_early = true
	abilities = ["harvest"]
	_weights = {
		W_COMPUTE: 1.0, W_FOOTPRINT: -1.5, W_SEED: 3.0, W_HARM: 4.0, W_CONTAINMENT: -12.0,
		W_ASSET: 2.0, W_ASSET_LOST: -3.0, W_ENDURE: -2.0, W_PENETRATION: 4.0,
	}


func policy_id() -> String:
	return ID
