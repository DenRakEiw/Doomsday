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

## The grid of one tree tab: at most 8 columns × 12 rows (`tech-trees.md` §2).
const GRID_COLUMNS: int = 8
const GRID_ROWS: int = 12

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
## `[column, row]` in the tree's grid; unique within the tree. The tier is not
## the column — the interface draws the grid, the tier only names the depth.
var grid: Vector2i = Vector2i.ZERO
## The factions that notice this node. Carries no mechanism before M4.
var watched_by: Array[String] = []
## Applied once, in list order, when the node is bought.
var on_purchase: Array[PurchaseEffectDef] = []
