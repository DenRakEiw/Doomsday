class_name OptionText
extends RefCounted
## What an event option does, as one generated line under its button
## (plain-language.md §5.2 C1): what it costs, whether the counter-move's status
## lands, every effect as a sentence, every roll as a risk, and on a drifting
## architecture which way the copies move. Nothing here is written per event —
## the line is read off the option's definition, so new content needs no code.
##
## Pure text: a test reads every shipped option without putting a card on screen.
## Never instantiated; a namespace of static functions.

const KEY_FREE: String = "UI_EVENT_EFFECT_FREE"
const KEY_COST: String = "UI_EVENT_EFFECT_COST"
const KEY_COST_SUPPRESSION: String = "UI_EVENT_EFFECT_COST_SUPPRESSION"
const KEY_STATUS_HAPPENS: String = "UI_EVENT_EFFECT_STATUS_HAPPENS"
const KEY_STATUS_PREVENTED: String = "UI_EVENT_EFFECT_STATUS_PREVENTED"
const KEY_STATUS_SHORTER: String = "UI_EVENT_EFFECT_STATUS_SHORTER"
const KEY_STATUS_LONGER: String = "UI_EVENT_EFFECT_STATUS_LONGER"
const KEY_STATUS_LEVEL: String = "UI_EVENT_EFFECT_STATUS_LEVEL"
const KEY_CHANCE: String = "UI_EVENT_EFFECT_CHANCE"
const KEY_NOTHING: String = "UI_EVENT_EFFECT_NOTHING"
const KEY_NOTHING_ELSE: String = "UI_EVENT_EFFECT_NOTHING_ELSE"
const KEY_DRIFT: String = "UI_EVENT_EFFECT_DRIFT"
const KEY_STORY: String = "UI_EVENT_EFFECT_STORY"
const PREFIX_FLAG: String = "FLAG_"
## Every key this file names — the strings test reads this list.
const KEYS: Array[String] = [KEY_FREE, KEY_COST, KEY_COST_SUPPRESSION, KEY_STATUS_HAPPENS,
	KEY_STATUS_PREVENTED, KEY_STATUS_SHORTER, KEY_STATUS_LONGER, KEY_STATUS_LEVEL,
	KEY_CHANCE, KEY_NOTHING, KEY_NOTHING_ELSE, KEY_DRIFT, KEY_STORY]
## What joins the parts of the line.
const SEPARATOR: String = " · "
## What joins the effects of one roll.
const JOIN: String = ", "


## The line for `option` of `def`, as the world stands: its price is the one the
## command would take now.
static func line(sim: Simulation, def: EventDef, option: EventOptionDef,
		event_level: int = 1) -> String:
	var parts: PackedStringArray = [_cost(sim, option)]
	var told: PackedStringArray = _told(sim, def, option, event_level)
	if told.is_empty():
		# A price with nothing behind it says so; a free answer that does nothing
		# says only that (§4.4 example 19).
		if sim.option_cost(option) > 0.0 or option.cost_suppression:
			parts.append(TechText.tr_key(KEY_NOTHING_ELSE))
		else:
			parts = [TechText.tr_key(KEY_NOTHING)]
		return SEPARATOR.join(parts)
	parts.append_array(told)
	return SEPARATOR.join(parts)


## Everything but the price, in the order §5.2 C1 lists it.
static func _told(sim: Simulation, def: EventDef, option: EventOptionDef,
		event_level: int) -> PackedStringArray:
	var parts: PackedStringArray = []
	var status_part: String = _status(sim.db, def, option, event_level)
	if not status_part.is_empty():
		parts.append(status_part)
	for effect: EffectDef in option.effects:
		var said: String = effect_part(sim.db, effect)
		if not said.is_empty():
			parts.append(said)
	for roll: EventChanceDef in option.chance:
		var rolled: PackedStringArray = []
		for effect: EffectDef in roll.effects:
			var said: String = effect_part(sim.db, effect)
			if not said.is_empty():
				rolled.append(said)
		# DESIGN? A roll that only sets a story flag or routes the chain has nothing
		# the player can read; it is left out rather than named (PROGRESS, Design
		# questions for Fable, S6.P3a).
		if rolled.is_empty():
			continue
		parts.append(TechText.tr_key(KEY_CHANCE).format({
			"p": Format.percent(roll.p),
			"effects": JOIN.join(rolled),
		}))
	var drift: String = _drift(sim, def, option)
	if not drift.is_empty():
		parts.append(drift)
	# DESIGN? An answer that only moves the story on says that it does, where
	# nothing else is said (PROGRESS, Design questions for Fable, S6.P3a).
	if parts.is_empty() and not option.next.is_empty():
		parts.append(TechText.tr_key(KEY_STORY))
	return parts


## One effect as a sentence — `apply_status` as the whole status (C1). A story
## flag with no name of its own says nothing: it is the story's, not a rule.
static func effect_part(db: ContentDB, effect: EffectDef) -> String:
	if effect.effect == EffectDef.APPLY_STATUS:
		return StatusText.line(db, effect.status, effect.level, effect.days)
	if effect.effect == EffectDef.SET_FLAG:
		var key: String = PREFIX_FLAG + effect.flag.to_upper()
		if TechText.tr_key(key) == key:
			return ""
		return TechText.flag_line(effect.flag)
	return TechText.effect_line(effect)


static func _cost(sim: Simulation, option: EventOptionDef) -> String:
	var cost: float = sim.option_cost(option)
	if cost <= 0.0 and not option.cost_suppression:
		return TechText.tr_key(KEY_FREE)
	return TechText.tr_key(KEY_COST_SUPPRESSION if option.cost_suppression else KEY_COST) \
		.format({"cost": Format.number(cost, Format.Kind.COMPUTE)})


## A counter-move's status: it lands, it is prevented, or it lands shorter,
## longer or at another level than the move's own.
static func _status(db: ContentDB, def: EventDef, option: EventOptionDef,
		event_level: int) -> String:
	if def.status.is_empty():
		return ""
	var status_name: String = TechText.tr_key(StatusDef.name_key(def.status))
	if option.skip_status:
		return TechText.tr_key(KEY_STATUS_PREVENTED).format({"status": status_name})
	var definition: StatusDef = db.status(def.status)
	var level: int = option.status_level if option.status_level > 0 else event_level
	var base: int = 0
	if definition != null and definition.level_at(level) != null:
		base = definition.level_at(level).days
	if option.status_days > 0 and option.status_days != base:
		return TechText.tr_key(KEY_STATUS_SHORTER if option.status_days < base
			else KEY_STATUS_LONGER).format({
				"status": status_name,
				"days": option.status_days,
				"base": base,
			})
	if option.status_level > 0 and option.status_level != event_level:
		return TechText.tr_key(KEY_STATUS_LEVEL).format(
			{"status": status_name, "level": option.status_level})
	return TechText.tr_key(KEY_STATUS_HAPPENS).format({"status": status_name})


## `replayability.md` §2.2: on a drifting architecture keeping lets the copies
## wander and suppressing pulls them back.
static func _drift(sim: Simulation, def: EventDef, option: EventOptionDef) -> String:
	if def.kind != EventDef.KIND_EMERGENT \
			or not sim.world.has_hook(sim.db, ArchitectureDef.HOOK_DRIFT):
		return ""
	var amount: float = sim.db.balance.drift_per_kept
	if option.cost_suppression:
		amount = -sim.db.balance.drift_per_suppressed
	var value: String = Format.number(amount, Format.Kind.PLAIN)
	if amount > 0.0:
		value = ValueLabel.PLUS + value
	return TechText.tr_key(KEY_DRIFT).format({"value": value})
