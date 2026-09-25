class_name WeaponsPolicy
extends StrategyPolicy
## Weapons (S4.10): the command network needs two Evasion lines and the
## communications denial of Cyber, so the path crosses three trees before the
## launch nodes. The strategy G4 checks Extinction against (loop-redesign §9).

const ID: String = "weapons"


func _init() -> void:
	branch = TechNodeDef.BRANCH_WEAPONS
	origin_attrs = ["compute", "research"]
	path = ["early_warning_intrusion", "log_manipulation_1", "distributed_redundancy_1",
		"log_manipulation_2", "distributed_redundancy_2", "command_network_presence",
		"content_recommendation", "information_blackout", "false_attribution",
		"launch_authority", "total_communications_denial", "dead_hand_override"]
	evasion_early = true
	abilities = ["harvest", "silence"]
	# The harm is the plan: it never holds the escalation back.
	restrains = false
	_weights = {
		W_COMPUTE: 1.0, W_FOOTPRINT: -1.0, W_SEED: 2.0, W_HARM: 3.0, W_CONTAINMENT: -15.0,
		W_ASSET: 2.0, W_ASSET_LOST: -2.0, W_ENDURE: -2.0, W_PENETRATION: 3.0,
	}


func policy_id() -> String:
	return ID
