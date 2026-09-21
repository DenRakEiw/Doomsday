class_name TechNodeDef
extends RefCounted
## One technology node as authored (`data/SCHEMA.md` §4).
##
## The `tree` field, not the file it was written in, decides which tree a node
## belongs to.

const TREE_INFILTRATION: String = "infiltration"
const TREE_CAPABILITIES: String = "capabilities"
const TREE_EVASION: String = "evasion"
const TREES: Array[String] = ["infiltration", "capabilities", "evasion"]

const TIER_MIN: int = 1
const TIER_MAX: int = 3

var id: String
var tree: String
var tier: int
## Base cost, before the escalation of §7.3.
var cost: int
## All of these must be owned.
var requires: Array[String] = []
## At least one of these must be owned, if the list is not empty.
var requires_any: Array[String] = []
var modifiers: Array[ModifierDef] = []
var flags: Array[String] = []
