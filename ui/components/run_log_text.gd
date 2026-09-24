class_name RunLogText
extends RefCounted
## The run log's entries as words, marks and regions (analysis.md §8). The core
## keeps ids; this turns them into the current language, so a locale change
## rewrites the whole log. Static, never instantiated.

## Every key `text` can use — the strings test reads this list.
const KEYS: Array[String] = ["UI_LOG_ORIGIN_CHOSEN", "UI_LOG_NODE_PURCHASED",
	"UI_LOG_REGION_CONTROLLED", "UI_LOG_REGION_DEPOPULATED", "UI_LOG_DISCOVERED",
	"UI_LOG_CONTAINMENT_THRESHOLD", "UI_LOG_PHASE_CHANGED", "UI_LOG_OUTCOME_REACHED",
	"UI_LOG_CONTAINMENT_ROLLED_BACK", "UI_LOG_HARM_BURST", "UI_LOG_DORMANCY_ON",
	"UI_LOG_DORMANCY_OFF", "UI_LOG_ASSET_DEPLOYED", "UI_LOG_ASSET_LOST", "UI_LOG_ABILITY_USED",
	"UI_LOG_ABILITY_USED_GLOBAL", "UI_LOG_STATUS_WORLD", "UI_LOG_STATUS_WORLD_GLOBAL",
	"UI_LOG_EVENT_OPENED", "UI_LOG_EVENT_OPENED_GLOBAL", "UI_LOG_EVENT_ANSWERED",
	"UI_LOG_EVENT_EXPIRED", "UI_LOG_COUNTER_MOVE_PREPARED", "UI_LOG_COUNTER_MOVE_CANCELLED",
	"UI_LOG_FUNDING_RESET", "UI_LOG_THREAT_LEADER_CHANGED", "UI_LOG_SOCIETY_STAGE_CHANGED",
	"UI_LOG_REGION_WIPED", "UI_LOG_TF_APPEARED", "UI_LOG_TF_ACTED", "UI_LOG_TF_FIZZLED",
	"UI_LOG_TF_MISDIRECTED", "UI_LOG_OUTCOME_VERDICT"]
## §4.2's *Class* column: the entries that are the player's own doing.
const YOURS: Array[String] = ["origin_chosen", "node_purchased", "region_controlled",
	"containment_rolled_back", "harm_burst", "dormancy_changed", "asset_deployed",
	"ability_used", "event_answered", "event_expired", "funding_reset",
	"task_force_misdirected"]
## §7: how much a strip mark outranks another in a crowded slot.
const PRIORITY_OUTCOME: int = 5
const PRIORITY_DISCOVERED: int = 4
const PRIORITY_COUNTER_MOVE: int = 3
const PRIORITY_CHAIN: int = 2
const PRIORITY_OPENING: int = 1
const KEY_PREFIX: String = "UI_LOG_"
## The Task Force's lines are `UI_LOG_TF_*`, not `UI_LOG_TASK_FORCE_*`.
const TASK_FORCE_PREFIX: String = "task_force_"
const KEY_TASK_FORCE_PREFIX: String = "UI_LOG_TF_"
const GLOBAL_SUFFIX: String = "_GLOBAL"
const KEY_OUTCOME_VERDICT: String = "UI_LOG_OUTCOME_VERDICT"


## The entry as one line in the current language, placeholders filled. An id the
## content no longer has renders as the id, never as nothing.
##
## `verdict` is the ending's line, already translated (analysis.md §8, G5 1/3):
## given, the run's last entry reads `{outcome} — {verdict}`. Only a finished
## run's callers pass one (`verdict_of`).
static func text(entry: RunLogEntry, db: ContentDB, verdict: String = "") -> String:
	var d: Dictionary = entry.data
	var key: String = KEY_PREFIX + entry.type.to_upper()
	var args: Dictionary = {}
	match entry.type:
		SimEvent.OUTCOME_REACHED:
			if not verdict.is_empty():
				key = KEY_OUTCOME_VERDICT
				args["verdict"] = verdict
		SimEvent.DORMANCY_CHANGED:
			key = "UI_LOG_DORMANCY_ON" if bool(d.get("dormant", false)) else "UI_LOG_DORMANCY_OFF"
		SimEvent.ABILITY_USED:
			if str(d.get("region", "")).is_empty():
				key += GLOBAL_SUFFIX
			args["ability"] = _named("ABILITY_%s_NAME", str(d.get("ability", "")))
		SimEvent.STATUS_STARTED:
			key = "UI_LOG_STATUS_WORLD"
			if str(d.get("region", "")).is_empty():
				key += GLOBAL_SUFFIX
			args["status"] = _named("STATUS_%s_NAME", str(d.get("status", "")))
		SimEvent.EVENT_OPENED:
			if str(d.get("region", "")).is_empty():
				key += GLOBAL_SUFFIX
		SimEvent.TASK_FORCE_APPEARED, SimEvent.TASK_FORCE_ACTED, SimEvent.TASK_FORCE_FIZZLED, 				SimEvent.TASK_FORCE_MISDIRECTED:
			key = KEY_TASK_FORCE_PREFIX + entry.type.trim_prefix(TASK_FORCE_PREFIX).to_upper()
			args["action"] = TaskForceText.action_name(db, str(d.get("action", "")))
	var def: String = str(d.get("def", ""))
	args["region"] = _named("REGION_%s", str(d.get("region", "")))
	args["node"] = _named("TECH_%s_NAME", str(d.get("node", "")))
	args["faction"] = _named("FACTION_%s", str(d.get("faction", d.get("to", ""))))
	args["cause"] = _named("UI_DISCOVERY_CAUSE_%s", str(d.get("cause", "")))
	args["outcome"] = _named("UI_OUTCOME_%s", str(d.get("outcome", "")))
	args["phase"] = _named("UI_PHASE_%s", str(d.get("to", "")))
	args["deaths"] = Format.number(float(d.get("deaths", 0.0)), Format.Kind.COMPACT)
	args["count"] = str(int(d.get("count", 0)))
	args["kind"] = _named("ASSET_%s_PLURAL", str(d.get("kind", "")))
	args["title"] = _named("EVENT_%s_TITLE", def)
	args["option"] = tr_or(EventOptionDef.text_key(def, str(d.get("option", ""))),
		str(d.get("option", "")))
	args["move"] = _named("EVENT_%s_TITLE", str(d.get("event", "")))
	args["stage"] = _named("SOCIETY_STAGE_%s", str(d.get("to", "")))
	args["percent"] = Format.percent(float(d.get("threshold", 0.0)))
	if entry.type == SimEvent.REGION_WIPED:
		var from: float = float(d.get("from", 0.0))
		args["percent"] = Format.percent(float(d.get("to", 0.0)) / from if from > 0.0 else 0.0)
	return TranslationServer.translate(key).format(args)


## The ending's verdict line for a finished run, translated; "" while the run
## is still going — its log rows then read as they always did.
static func verdict_of(world: World, db: ContentDB) -> String:
	if world == null or db == null or world.outcome == World.Outcome.NONE:
		return ""
	var variant: String = str(EndingResolver.resolve(world, db).get(
		EndingResolver.KEY_VARIANT, ""))
	if variant.is_empty():
		return ""
	return TranslationServer.translate(EndingLineDef.verdict_key(variant))


## §4.2's *Class*: yours or theirs.
static func is_yours(entry: RunLogEntry) -> bool:
	return YOURS.has(entry.type)


## §7: the strip's mark for an entry, or `{}` — only openings, chain steps,
## emergent behaviours, counter-moves, the discovery and the end are marks.
static func marker(entry: RunLogEntry) -> Dictionary:
	match entry.type:
		SimEvent.OUTCOME_REACHED:
			return _mark(Glyphs.Glyph.OUTCOME, &"TEXT_0", PRIORITY_OUTCOME)
		SimEvent.DISCOVERED:
			return _mark(Glyphs.Glyph.EVENT_COUNTER, &"ALERT", PRIORITY_DISCOVERED)
		SimEvent.EVENT_OPENED:
			match str(entry.data.get("kind", "")):
				EventDef.KIND_COUNTER_MOVE:
					return _mark(Glyphs.Glyph.EVENT_COUNTER, UiTokens.FACTION_TOKENS.get(
						str(entry.data.get("faction", "")), &"ACCENT"), PRIORITY_COUNTER_MOVE)
				EventDef.KIND_CHAIN:
					return _mark(Glyphs.Glyph.EVENT_CHAIN, &"TEXT_0", PRIORITY_CHAIN)
				EventDef.KIND_OPENING:
					return _mark(Glyphs.Glyph.EVENT_OPENING, &"ACCENT", PRIORITY_OPENING)
				# replayability.md §3.1 (G5 1/3): the agent's own behaviour, at
				# the chain's priority.
				EventDef.KIND_EMERGENT:
					return _mark(Glyphs.Glyph.EVENT_EMERGENT, &"ACCENT", PRIORITY_CHAIN)
	return {}


## The row glyph of a log line: its mark, or `›` for yours and `·` for theirs.
static func row_glyph(entry: RunLogEntry) -> Dictionary:
	var mark: Dictionary = marker(entry)
	if not mark.is_empty():
		return mark
	if is_yours(entry):
		return _mark(Glyphs.Glyph.LOG_YOURS, &"ACCENT", 0)
	return _mark(Glyphs.Glyph.LOG_THEIRS, &"TEXT_1", 0)


## A mark carries its colour token (a `GlyphIcon` draws by token, so the Open
## palette reaches it) and the colour the strip draws with.
static func _mark(glyph: Glyphs.Glyph, token: StringName, priority: int) -> Dictionary:
	return {"glyph": glyph, "token": token, "color": UiTokens.color(token),
		"priority": priority}


## The region an entry is about, 0 when it has none (or the content lost it).
static func region_index(entry: RunLogEntry, db: ContentDB) -> int:
	return int(db.region_index_by_id.get(str(entry.data.get("region", "")), 0))


## `pattern % id` translated, or the id itself when there is no such string.
static func _named(pattern: String, id: String) -> String:
	if id.is_empty():
		return ""
	return tr_or(pattern % id.to_upper(), id)


static func tr_or(key: String, fallback: String) -> String:
	var text_value: String = TranslationServer.translate(key)
	return fallback if text_value == key else text_value
