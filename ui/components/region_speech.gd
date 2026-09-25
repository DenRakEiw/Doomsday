class_name RegionSpeech
extends RefCounted
## One sentence about a region, in the current language, for the map cursor
## (spec accessibility.md §3.5). A screen reader speaks it on every step; the
## region panel stays the full text.
##
## Parts, each a sentence, in a fixed order; a part that does not apply is left
## out. Never instantiated; a namespace of static functions.

const KEY_NAME: String = "UI_A11Y_REGION_NAME"
const KEY_PRESENCE_DARK: String = "UI_A11Y_PRESENCE_DARK"
const KEY_PRESENCE_NONE: String = "UI_A11Y_PRESENCE_NONE"
const KEY_PRESENCE_REACHED: String = "UI_A11Y_PRESENCE_REACHED"
const KEY_PRESENCE_CONTROLLED: String = "UI_A11Y_PRESENCE_CONTROLLED"
const KEY_DORMANT: String = "UI_A11Y_DORMANT"
const KEY_SITE_OK: String = "UI_SITE_HOVER_OK_KEY"
const KEY_SITE_CLOSED: String = "UI_SITE_HOVER_CLOSED"
const KEY_ASSETS: String = "UI_A11Y_ASSETS"
const KEY_ASSET_ITEM: String = "UI_A11Y_ASSET_ITEM"
const KEY_STATUSES: String = "UI_A11Y_STATUSES"
const KEY_EVENT: String = "UI_A11Y_EVENT"
const KEY_ANOMALY: String = "UI_A11Y_ANOMALY"
const KEY_TASK_FORCE: String = "UI_A11Y_TASK_FORCE"
const PREFIX_REGION: String = "REGION_"
const PREFIX_STATUS: String = "STATUS_"
const SUFFIX_NAME: String = "_NAME"
const SEPARATOR_PARTS: String = " "
const SEPARATOR_LIST: String = ", "


## The cursor's line for region `index`; `site` is the open site request, or
## null. "" for an index that is not a region of `world`.
static func line(world: World, index: int, site: SiteRequest) -> String:
	if world == null or index <= 0 or index >= world.regions.size():
		return ""
	var region: Region = world.regions[index]
	var name: String = region_name(world, index)
	var parts: Array[String] = [_tr(KEY_NAME).format({"region": name})]
	parts.append(_presence(region))
	if region.dormant:
		parts.append(_tr(KEY_DORMANT))
	if site != null:
		var reason: String = site.reason_for(index)
		if reason.is_empty():
			parts.append(_tr(KEY_SITE_OK).format({"region": name}))
		else:
			parts.append(_tr(KEY_SITE_CLOSED).format({"region": name,
				"reason": site.reason_text(index)}))
	var assets: String = _assets(region)
	if not assets.is_empty():
		parts.append(_tr(KEY_ASSETS).format({"list": assets}))
	var statuses: Array[String] = []
	for status: Status in world.statuses_in_region(index):
		statuses.append(_tr(PREFIX_STATUS + status.id.to_upper() + SUFFIX_NAME))
	if not statuses.is_empty():
		parts.append(_tr(KEY_STATUSES).format({"list": SEPARATOR_LIST.join(statuses)}))
	var event: OpenEvent = world.event_in_region(index)
	if event != null:
		parts.append(_tr(KEY_EVENT).format({"title": EventView.title(event.def, world, index)}))
	if world.anomaly_in_region(index) != null:
		parts.append(_tr(KEY_ANOMALY))
	if world.task_force.is_present() and world.task_force.region == index:
		parts.append(_tr(KEY_TASK_FORCE))
	return SEPARATOR_PARTS.join(parts)


static func region_name(world: World, index: int) -> String:
	return _tr(PREFIX_REGION + world.regions[index].def.id.to_upper())


static func _presence(region: Region) -> String:
	if region.dark:
		return _tr(KEY_PRESENCE_DARK)
	if region.seeded_day < 0 and region.penetration <= 0.0:
		return _tr(KEY_PRESENCE_NONE)
	var penetration: String = Format.percent(region.penetration)
	if region.control <= 0.0:
		return _tr(KEY_PRESENCE_REACHED).format({"penetration": penetration})
	return _tr(KEY_PRESENCE_CONTROLLED).format({"penetration": penetration,
		"control": Format.percent(region.control)})


## "2 × Data centres, 1 × Fleet" in `AssetDef.KINDS` order, the panel's.
static func _assets(region: Region) -> String:
	var items: Array[String] = []
	for kind: String in AssetDef.KINDS:
		var count: int = region.asset_count(kind)
		if count <= 0:
			continue
		items.append(_tr(KEY_ASSET_ITEM).format({"count": count,
			"kind": TechText.asset_name(kind, count)}))
	return SEPARATOR_LIST.join(items)


static func _tr(key: String) -> String:
	return String(TranslationServer.translate(key))
