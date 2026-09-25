class_name NodeLockText
extends RefCounted
## Why a technology node cannot be bought right now, in plain words (the user,
## 2026-09-25: "it is often unclear why a node is locked"; PROGRESS punch item 4).
##
## Every reason the purchase would be refused for, read from the simulation —
## not only the first the command stops at: the prerequisites that are missing
## (all of them, or one of a set), a full group, the owned node that rules it out,
## the assets short with the counts, the compute short, and for a node that places
## something, that no region can take it yet and what one would need. The detail
## pane shows the lines under its buy button and the card on the board shows them
## as its tooltip. Pure text: a test reads it without a scene.
##
## Never instantiated; a namespace of static functions.

const KEY_NEEDS_ALL: String = "UI_TREE_LOCK_NEEDS_ALL"
const KEY_NEEDS_ONE: String = "UI_TREE_LOCK_NEEDS_ONE"
const KEY_ASSETS: String = "UI_TREE_LOCK_ASSETS"
const KEY_NO_SITE: String = "UI_TREE_LOCK_NO_SITE"
const KEY_GROUP_FULL: String = "CMD_FAIL_GROUP_FULL"
const KEY_EXCLUDED_BY: String = "CMD_FAIL_EXCLUDED_BY"
const KEY_COMPUTE: String = "CMD_FAIL_INSUFFICIENT_COMPUTE"
const KEY_NO_ORIGIN: String = "CMD_FAIL_NO_ORIGIN"
const KEY_GAME_OVER: String = "CMD_FAIL_GAME_OVER"
## Every key this file names — the strings test reads this list.
const KEYS: Array[String] = [KEY_NEEDS_ALL, KEY_NEEDS_ONE, KEY_ASSETS, KEY_NO_SITE,
	KEY_GROUP_FULL, KEY_EXCLUDED_BY, KEY_COMPUTE, KEY_NO_ORIGIN, KEY_GAME_OVER]
const PREFIX_ELIGIBLE_NEEDS: String = "UI_ELIGIBLE_NEEDS_"
const PREFIX_GROUP: String = "GROUP_"
const PREFIX_ATTR: String = "UI_ATTR_"
const PREFIX_CONTINENT: String = "CONTINENT_"
## What joins the names in one reason, and the requirements of a site.
const JOIN: String = ", "
const JOIN_NEEDS: String = "; "


## Every reason `definition` cannot be bought now, in the order the purchase
## checks them; empty when it can (or is owned).
static func reasons(definition: TechNodeDef, sim: Simulation) -> PackedStringArray:
	var out: PackedStringArray = []
	if definition == null or sim == null:
		return out
	var world: World = sim.world
	if world.agent.owns(definition.id):
		return out
	if world.outcome != World.Outcome.NONE:
		out.append(_tr(KEY_GAME_OVER))
		return out
	if world.agent.origin == 0:
		out.append(_tr(KEY_NO_ORIGIN))
		return out
	var missing: Array[String] = []
	for node_id: String in definition.requires:
		if not world.agent.owns(node_id):
			missing.append(TechText.node_name(node_id))
	if not missing.is_empty():
		out.append(_tr(KEY_NEEDS_ALL).format({"nodes": JOIN.join(missing)}))
	if not definition.requires_any.is_empty() and not _owns_any(definition.requires_any, sim):
		var any: Array[String] = []
		for node_id: String in definition.requires_any:
			any.append(TechText.node_name(node_id))
		out.append(_tr(KEY_NEEDS_ONE).format({"nodes": JOIN.join(any)}))
	if not definition.group.is_empty() \
			and sim.owned_in_group(definition.group) >= sim.group_max(definition.group):
		out.append(_tr(KEY_GROUP_FULL).format({
			"group": _tr(PREFIX_GROUP + definition.group.to_upper()),
			"owned": sim.owned_in_group(definition.group),
			"max": sim.group_max(definition.group),
		}))
	var excluder: String = sim.excluded_by(definition.id)
	if not excluder.is_empty():
		out.append(_tr(KEY_EXCLUDED_BY).format({"node": TechText.node_name(excluder)}))
	var short: Dictionary[String, int] = sim.missing_assets(definition)
	for kind: String in short:
		var count: int = definition.requires_assets[kind]
		out.append(_tr(KEY_ASSETS).format({
			"count": count,
			"kind": TechText.asset_name(kind, count),
			"have": world.asset_total(kind),
		}))
	var shortfall: float = sim.node_cost(definition.id) - world.agent.compute
	if shortfall > 0.0:
		out.append(_tr(KEY_COMPUTE).format(
			{"missing": Format.number(shortfall, Format.Kind.COMPUTE)}))
	if definition.deploys() and definition.deploy_eligible != null \
			and sim.eligible_regions(definition.deploy_eligible).is_empty():
		out.append(_tr(KEY_NO_SITE).format({"needs": JOIN_NEEDS.join(needs(definition))}))
	return out


## What a region needs to take the node's assets, one line per requirement —
## the detail pane's rows under *Deploys*, and the tail of the no-site reason.
static func needs(definition: TechNodeDef) -> PackedStringArray:
	var out: PackedStringArray = []
	if definition.deploy_eligible == null:
		return out
	for row: Array in definition.deploy_eligible.requirements():
		out.append(_tr(PREFIX_ELIGIBLE_NEEDS + str(row[0]).to_upper())
			.format(requirement_args(row[1])))
	return out


## An `Eligibility` requirement's arguments, with every id turned into a name.
static func requirement_args(raw: Variant) -> Dictionary:
	var source: Dictionary = raw
	var args: Dictionary = source.duplicate()
	if source.has("attr"):
		args["attr"] = _tr(PREFIX_ATTR + str(source["attr"]).to_upper())
	if source.has("kind"):
		args["kind"] = TechText.asset_name(str(source["kind"]), int(source.get("count", 1)))
	if source.has("status"):
		args["status"] = _tr(StatusDef.name_key(str(source["status"])))
	if source.has("value"):
		args["value"] = Format.percent(float(source["value"]))
	if source.has("continent"):
		args["continent"] = _tr(PREFIX_CONTINENT + str(source["continent"]).to_upper())
	return args


static func _owns_any(ids: Array[String], sim: Simulation) -> bool:
	for node_id: String in ids:
		if sim.world.agent.owns(node_id):
			return true
	return false


static func _tr(key: String) -> String:
	return TechText.tr_key(key)
