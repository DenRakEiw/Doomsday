class_name Agent
extends RefCounted
## The player: what it has, what it owns, where it started.

var compute: float = 0.0
## Lifetime total, never decreases — what was earned, not what is left.
var compute_earned: float = 0.0
## Region index of the origin; 0 means none has been chosen.
var origin: int = 0
## Purchase order, which is also the order the modifier sources are rebuilt in.
var owned_nodes: Array[String] = []


func owns(node_id: String) -> bool:
	return owned_nodes.has(node_id)
