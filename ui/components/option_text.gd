class_name OptionText
extends RefCounted
## What an event option does, as one generated line under its button
## (plain-language.md §5.2 C1): what it costs, whether the counter-move's status
## lands, every effect and named story flag as a sentence, every roll as a
## chance, and on a drifting architecture which way the copies move. Nothing here is written per event —
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
## plain-language.md §9.3: a roll with nothing readable that turns the story.
const KEY_CHANCE_STORY: String = "UI_EVENT_EFFECT_CHANCE_STORY"
const PREFIX_FLAG: String = "FLAG_"
## Every key this file names — the strings test reads this list.
const KEYS: Array[String] = [KEY_FREE, KEY_COST, KEY_COST_SUPPRESSION, KEY_STATUS_HAPPENS,
	KEY_STATUS_PREVENTED, KEY_STATUS_SHORTER, KEY_STATUS_LONGER, KEY_STATUS_LEVEL,
	KEY_CHANCE, KEY_NOTHING, KEY_NOTHING_ELSE, KEY_DRIFT, KEY_STORY, KEY_CHANCE_STORY]
## What joins the parts of the line.
const SEPARATOR: String = " · "
## What joins the effects of one roll.
const JOIN: String = ", "


## The line for `option` of `def`, as the world stands: its price is the one the
## command would take now.
static func line(sim: Simulation, def: EventDef, option: EventOptionDef,
		event_level: int = 1) -> String:
	return _compose(sim.db, def, option, sim.option_cost(option), _drift(sim, def, option),
		event_level)


## The line with no run behind it (the Codex's *Behaviours*): the price a run
## starts with, and no drift, which only a run's architecture has.
static func line_without_run(db: ContentDB, def: EventDef, option: EventOptionDef) -> String:
	return _compose(db, def, option, Simulation.option_cost_after(db, option, 0), "", 1)


static func _compose(db: ContentDB, def: EventDef, option: EventOptionDef, cost: float,
		drift: String, event_level: int) -> String:
	var parts: PackedStringArray = [_cost(cost, option)]
	var told: PackedStringArray = _told(db, def, option, event_level, drift)
	if told.is_empty():
		# A price with nothing behind it says so; a free answer that does nothing
		# says only that (§4.4 example 19).
		if cost > 0.0 or option.cost_suppression:
			parts.append(TechText.tr_key(KEY_NOTHING_ELSE))
		else:
			parts = [TechText.tr_key(KEY_NOTHING)]
		return SEPARATOR.join(parts)
	parts.append_array(told)
	return SEPARATOR.join(parts)


## Everything but the price, in the order §5.2 C1 lists it.
static func _told(db: ContentDB, def: EventDef, option: EventOptionDef,
		event_level: int, drift: String) -> PackedStringArray:
	var parts: PackedStringArray = []
	var status_part: String = _status(db, def, option, event_level)
	if not status_part.is_empty():
		parts.append(status_part)
	for effect: EffectDef in option.effects:
		var said: String = effect_part(db, effect)
		if not said.is_empty():
			parts.append(said)
	# §9.4 item 1: the option's own story flags are named like `set_flag` ones.
	for flag: String in option.flags:
		var named: String = flag_part(flag)
		if not named.is_empty():
			parts.append(named)
	for roll: EventChanceDef in option.chance:
		var rolled: PackedStringArray = []
		for effect: EffectDef in roll.effects:
			var said: String = effect_part(db, effect)
			if not said.is_empty():
				rolled.append(said)
		if not rolled.is_empty():
			parts.append(TechText.tr_key(KEY_CHANCE).format({
				"p": Format.percent(roll.p),
				"effects": JOIN.join(rolled),
			}))
		elif roll.has_next or _hides_a_flag(roll.effects):
			# §9.3: a roll the player cannot read is said, not hidden.
			parts.append(TechText.tr_key(KEY_CHANCE_STORY).format(
				{"p": Format.percent(roll.p)}))
	if not drift.is_empty():
		parts.append(drift)
	# §9.3: an answer whose only consequence is a route says that the story goes
	# on — never *no other effect*.
	# An answer that only sets a story flag with no name is not said to go on: the
	# one such answer today (*Stay on Earth*, `escape_declined`) leads nowhere and
	# its flag is read by nothing, so "another card follows" would be false — it
	# keeps *Nothing happens* (D6.9c, PROGRESS Decisions 2026-09-26).
	if parts.is_empty() and not option.next.is_empty():
		parts.append(TechText.tr_key(KEY_STORY))
	return parts


## One effect as a sentence — `apply_status` as the whole status (C1). A story
## flag with no name of its own says nothing: it is the story's, not a rule.
static func effect_part(db: ContentDB, effect: EffectDef) -> String:
	if effect.effect == EffectDef.APPLY_STATUS:
		return StatusText.line(db, effect.status, effect.level, effect.days)
	if effect.effect == EffectDef.SET_FLAG:
		return flag_part(effect.flag)
	return TechText.effect_line(effect)


## A flag as its `FLAG_*` sentence, or "" when it has none (§9.3: only the flags
## that change how a run can end, or a rule of a system, are named).
static func flag_part(flag: String) -> String:
	if not has_flag_name(flag):
		return ""
	return TechText.flag_line(flag)


static func has_flag_name(flag: String) -> bool:
	var key: String = PREFIX_FLAG + flag.to_upper()
	return TechText.tr_key(key) != key


## Whether `effects` set a story flag the line does not name.
static func _hides_a_flag(effects: Array[EffectDef]) -> bool:
	for effect: EffectDef in effects:
		if effect.effect == EffectDef.SET_FLAG and not has_flag_name(effect.flag):
			return true
	return false


static func _cost(cost: float, option: EventOptionDef) -> String:
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
