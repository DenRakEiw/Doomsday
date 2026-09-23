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

## The five branches of the Capabilities tree (`tech-trees.md` §7.5), each a
## band of grid rows: Cyber 0–4, Biology 5, Robotics 6–8, Weapons 9, Persuasion
## 10–11. A branch is what a strategy bot plays, not something a system reads.
const BRANCH_CYBER: String = "cyber"
const BRANCH_BIOLOGY: String = "biology"
const BRANCH_ROBOTICS: String = "robotics"
const BRANCH_WEAPONS: String = "weapons"
const BRANCH_PERSUASION: String = "persuasion"
const BRANCHES: Array[String] = [BRANCH_CYBER, BRANCH_BIOLOGY, BRANCH_ROBOTICS, BRANCH_WEAPONS,
	BRANCH_PERSUASION]
## The first row of each band; a node belongs to the last band that starts at or
## above it.
const BRANCH_FIRST_ROW: Dictionary[String, int] = {
	BRANCH_CYBER: 0,
	BRANCH_BIOLOGY: 5,
	BRANCH_ROBOTICS: 6,
	BRANCH_WEAPONS: 9,
	BRANCH_PERSUASION: 10,
}

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


## Which branch of the Capabilities tree the node is in, or "" for a node in
## another tree. The branches are bands of grid rows (`tech-trees.md` §7.5), so
## the layout is the definition and no node carries a branch field.
func branch() -> String:
	if tree != TREE_CAPABILITIES:
		return ""
	var found: String = ""
	var best_row: int = -1
	for name: String in BRANCH_FIRST_ROW:
		var row: int = BRANCH_FIRST_ROW[name]
		if grid.y >= row and row > best_row:
			best_row = row
			found = name
	return found
