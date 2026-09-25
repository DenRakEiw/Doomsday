class_name StatusText
extends RefCounted
## What a status does, as one generated line (plain-language.md §2.3, §5.2 C1, C3):
## its name, how long, where, and then every modifier, the links it closes and
## the one-shots it brings — the numbers from the definition, never from prose.
##
## The event card's explanation of a counter-move, an option's effect line, the
## region row's tooltip, the map chip and the Codex say the same thing about a
## status, so it is said here once. Pure text: a test reads it without a scene.
##
## Never instantiated; a namespace of static functions.

const KEY_HEAD: String = "UI_STATUS_LINE"
const KEY_HEAD_REGION: String = "UI_STATUS_LINE_REGION"
const KEY_HEAD_STANDING: String = "UI_STATUS_LINE_STANDING"
const KEY_HEAD_STANDING_REGION: String = "UI_STATUS_LINE_STANDING_REGION"
const KEY_WITH_EFFECTS: String = "UI_STATUS_LINE_EFFECTS"
const KEY_CLOSES_ALL: String = "UI_STATUS_CLOSES_ALL"
const KEY_CLOSES: String = "UI_STATUS_CLOSES"
const KEY_AT_END: String = "UI_STATUS_AT_END"
const KEY_DAYS_LEFT: String = "UI_STATUS_DAYS_LEFT"
const KEY_STANDING: String = "UI_REGION_STATUS_STANDING"
## plain-language.md §9.4 item 4: what a status keeps out of its region and
## what it ends there when it starts.
const KEY_BLOCKS: String = "UI_STATUS_BLOCKS"
const KEY_ENDS: String = "UI_STATUS_ENDS"
const PREFIX_LINK: String = "UI_LINK_"
## Every key this file names — the strings test reads this list.
const KEYS: Array[String] = [KEY_HEAD, KEY_HEAD_REGION, KEY_HEAD_STANDING,
	KEY_HEAD_STANDING_REGION, KEY_WITH_EFFECTS, KEY_CLOSES_ALL, KEY_CLOSES, KEY_AT_END,
	KEY_DAYS_LEFT, KEY_BLOCKS, KEY_ENDS]
## What joins the parts of one status: its modifiers, links and one-shots.
const JOIN: String = ", "


## "{status}, {days} days: …" — the whole status at `level`, lasting `days` (0 =
## the level's own), in `region_name` ("" = not named).
static func line(db: ContentDB, status_id: String, level: int = 1, days: int = 0,
		region_name: String = "") -> String:
	var definition: StatusDef = db.status(status_id)
	if definition == null:
		return ""
	var lvl: StatusLevelDef = definition.level_at(level)
	var length: int = days if days > 0 else (lvl.days if lvl != null else 0)
	var head: String = _head(status_id, length, region_name)
	var parts: PackedStringArray = effects(db, status_id, level)
	if parts.is_empty():
		return head
	return TechText.tr_key(KEY_WITH_EFFECTS).format({"head": head, "effects": JOIN.join(parts)})


## What the status does at `level`, one part per modifier, closed link,
## one-shot, the statuses it ends and those it keeps out — without its name or
## its length (C3's tooltip lines).
static func effects(db: ContentDB, status_id: String, level: int = 1) -> PackedStringArray:
	var parts: PackedStringArray = []
	var definition: StatusDef = db.status(status_id)
	if definition == null:
		return parts
	var lvl: StatusLevelDef = definition.level_at(level)
	if lvl == null:
		return parts
	if lvl.closes_links.has(StatusDef.LINKS_ALL):
		parts.append(TechText.tr_key(KEY_CLOSES_ALL))
	elif not lvl.closes_links.is_empty():
		var kinds: PackedStringArray = []
		for kind: String in lvl.closes_links:
			kinds.append(TechText.tr_key(PREFIX_LINK + kind.to_upper()))
		parts.append(TechText.tr_key(KEY_CLOSES).format({"kinds": JOIN.join(kinds)}))
	for modifier: ModifierDef in lvl.modifiers:
		# A factor of exactly one changes nothing; the first step of an
		# escalating status carries such placeholders.
		if _changes_nothing(modifier):
			continue
		parts.append(TechText.modifier_line(modifier, db))
	for effect: EffectDef in lvl.on_start:
		parts.append(TechText.effect_line(effect))
	if not lvl.ends_statuses.is_empty():
		parts.append(TechText.tr_key(KEY_ENDS).format(
			{"statuses": JOIN.join(_names(lvl.ends_statuses))}))
	if not definition.blocks.is_empty():
		parts.append(TechText.tr_key(KEY_BLOCKS).format(
			{"statuses": JOIN.join(_names(definition.blocks))}))
	if not lvl.on_end.is_empty():
		var ending: PackedStringArray = []
		for effect: EffectDef in lvl.on_end:
			ending.append(TechText.effect_line(effect))
		parts.append(TechText.tr_key(KEY_AT_END).format({"effects": JOIN.join(ending)}))
	return parts


## "{days} days left" or "permanent" — a running status's time (C3).
static func days_left(status: Status, day: int) -> String:
	if status.is_standing():
		return TechText.tr_key(KEY_STANDING)
	return TechText.tr_key(KEY_DAYS_LEFT).format({"days": status.days_left(day)})


## A running status as its tooltip says it: the detail, then what it does, then
## how long it has left (C3).
static func tooltip(db: ContentDB, status: Status, day: int) -> String:
	var lines: PackedStringArray = [TechText.tr_key(StatusDef.detail_key(status.id))]
	var parts: PackedStringArray = effects(db, status.id, status.level)
	if not parts.is_empty():
		lines.append(JOIN.join(parts))
	lines.append(days_left(status, day))
	return "\n".join(lines)


static func _head(status_id: String, days: int, region_name: String) -> String:
	var args: Dictionary = {
		"status": TechText.tr_key(StatusDef.name_key(status_id)),
		"days": days,
		"region": region_name,
	}
	var standing: bool = days == StatusLevelDef.DAYS_STANDING
	var key: String = KEY_HEAD_STANDING if standing else KEY_HEAD
	if not region_name.is_empty():
		key = KEY_HEAD_STANDING_REGION if standing else KEY_HEAD_REGION
	return TechText.tr_key(key).format(args)


static func _names(status_ids: Array[String]) -> PackedStringArray:
	var names: PackedStringArray = []
	for status_id: String in status_ids:
		names.append(TechText.tr_key(StatusDef.name_key(status_id)))
	return names


static func _changes_nothing(modifier: ModifierDef) -> bool:
	if modifier.op == ModifierDef.Op.MUL:
		return is_equal_approx(modifier.value, 1.0)
	return is_zero_approx(modifier.value)
