class_name CodexEntries
extends RefCounted
## What the Codex lists and in which order (spec `screens-full.md` §6.1), and
## which of it the profile has seen. The Codex modal draws it; the statistics
## count the endings with it.
##
## Never instantiated; a namespace of static functions.

## first-run.md §6.6: *How to play*, the first tab — always open, never locked.
const TAB_HELP: String = "help"
const TAB_REGIONS: String = "regions"
const TAB_FACTIONS: String = "factions"
const TAB_TECH: String = "tech"
const TAB_CHARACTERS: String = "characters"
const TAB_STATUSES: String = "statuses"
const TAB_ARCHITECTURES: String = "architectures"
const TAB_ENDINGS: String = "endings"
## §6.1: seven tabs, in this order, after *How to play* (first-run.md §6.6).
const TABS: Array[String] = [TAB_HELP, TAB_REGIONS, TAB_FACTIONS, TAB_TECH, TAB_CHARACTERS,
	TAB_STATUSES, TAB_ARCHITECTURES, TAB_ENDINGS]

## The trees in the order the tech tree shows its tabs.
const TREES: Array[String] = ["infiltration", "capabilities", "evasion"]
const CONTINENTS: Array[String] = ["north_america", "south_america", "europe", "asia",
	"africa", "oceania"]
const PREFIX_REGION: String = "REGION_"
const PREFIX_STATUS: String = "STATUS_"
const SUFFIX_NAME: String = "_NAME"


## Every id of `tab`, in list order.
static func ids(tab: String, db: ContentDB) -> Array[String]:
	match tab:
		TAB_HELP:
			return HelpPages.ids()
		TAB_REGIONS:
			return _regions(db)
		TAB_FACTIONS:
			return Faction.FACTION_IDS.duplicate()
		TAB_TECH:
			return _tech(db)
		TAB_CHARACTERS:
			return CodexTracker.CHARACTERS.duplicate()
		TAB_STATUSES:
			return _statuses(db)
		TAB_ARCHITECTURES:
			var out: Array[String] = []
			for def: ArchitectureDef in db.architectures:
				out.append(def.id)
			return out
		TAB_ENDINGS:
			return ending_variants(db)
	return []


## Whether the profile has met `id` in `tab`: collected ids for the five tabs a
## run fills, the unlock rule for architectures, `endings_seen` for endings.
static func is_seen(tab: String, id: String, db: ContentDB) -> bool:
	match tab:
		TAB_HELP:
			return true
		TAB_ARCHITECTURES:
			var def: ArchitectureDef = db.architecture(id)
			return def != null and ProfileManager.is_unlocked(def)
		TAB_ENDINGS:
			return ProfileManager.endings_seen.has(id)
	return (ProfileManager.codex.get(tab, []) as Array).has(id)


static func seen_count(tab: String, db: ContentDB) -> int:
	var count: int = 0
	for id: String in ids(tab, db):
		if is_seen(tab, id, db):
			count += 1
	return count


## §6.1's Endings: by outcome, then variant — each outcome's variants and the
## outcome itself, which is its line when no variant matches (D5.2 §6.3).
static func ending_variants(db: ContentDB) -> Array[String]:
	var out: Array[String] = []
	for i: int in range(1, World.OUTCOME_IDS.size()):
		var outcome: String = World.OUTCOME_IDS[i]
		var def: EndingDef = db.endings.get(outcome)
		if def != null:
			for line: EndingLineDef in def.variants:
				if not out.has(line.id):
					out.append(line.id)
		if not out.has(outcome):
			out.append(outcome)
	return out


## The outcome an ending variant belongs to: the longest outcome id it starts with.
static func outcome_of(variant: String) -> String:
	var best: String = ""
	for i: int in range(1, World.OUTCOME_IDS.size()):
		var outcome: String = World.OUTCOME_IDS[i]
		if variant.begins_with(outcome) and outcome.length() > best.length():
			best = outcome
	return best


## By continent, then by the name the player reads.
static func _regions(db: ContentDB) -> Array[String]:
	var rows: Array[RegionDef] = []
	for def: RegionDef in db.regions:
		# Index 0 is "no region" and has no definition.
		if def != null:
			rows.append(def)
	rows.sort_custom(func(a: RegionDef, b: RegionDef) -> bool:
		var ca: int = CONTINENTS.find(a.continent)
		var cb: int = CONTINENTS.find(b.continent)
		if ca != cb:
			return ca < cb
		return _name(PREFIX_REGION + a.id.to_upper()) < _name(PREFIX_REGION + b.id.to_upper()))
	var out: Array[String] = []
	for def: RegionDef in rows:
		out.append(def.id)
	return out


## By tree, then the grid: tier, then the content's order within it.
static func _tech(db: ContentDB) -> Array[String]:
	var out: Array[String] = []
	for tree: String in TREES:
		var nodes: Array[TechNodeDef] = []
		for def: TechNodeDef in db.tech_nodes:
			if def.tree == tree:
				nodes.append(def)
		# `sort_custom` is not stable, so the content order is the tie-break.
		var order: Dictionary[String, int] = {}
		for i: int in nodes.size():
			order[nodes[i].id] = i
		nodes.sort_custom(func(a: TechNodeDef, b: TechNodeDef) -> bool:
			if a.tier != b.tier:
				return a.tier < b.tier
			return order[a.id] < order[b.id])
		for def: TechNodeDef in nodes:
			out.append(def.id)
	return out


## Yours, then the world's, each by name.
static func _statuses(db: ContentDB) -> Array[String]:
	var rows: Array[StatusDef] = db.statuses.duplicate()
	rows.sort_custom(func(a: StatusDef, b: StatusDef) -> bool:
		var pa: bool = a.origin == StatusDef.ORIGIN_PLAYER
		var pb: bool = b.origin == StatusDef.ORIGIN_PLAYER
		if pa != pb:
			return pa
		return _name(StatusDef.name_key(a.id)) < _name(StatusDef.name_key(b.id)))
	var out: Array[String] = []
	for def: StatusDef in rows:
		out.append(def.id)
	return out


static func _name(key: String) -> String:
	return String(TranslationServer.translate(key))
