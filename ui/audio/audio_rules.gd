class_name AudioRules
extends RefCounted
## The pure rules of the sound (spec audio.md §3.2, §4.5, §4.6, §6.3): which
## trigger a source matches, which cue a template names, how loud a stem is at
## a tension, and the volume steps of the settings.
##
## Static and side-effect free; the `Audio` autoload asks, the tests ask the same.

## §3.2: the five steps of a volume button.
const VOLUME_STEPS: Array[float] = [0.0, 0.25, 0.5, 0.75, 1.0]
## Two volumes closer than this are the same step.
const STEP_EPSILON: float = 0.001

## §4.5: the conditions a `match` object may hold, one key each.
const COND_NOT: String = "not"
const COND_GT: String = "gt"
const COND_LT: String = "lt"
const COND_GT_FIELD: String = "gt_field"
const COND_LT_FIELD: String = "lt_field"
const CONDITIONS: Array[String] = [COND_NOT, COND_GT, COND_LT, COND_GT_FIELD, COND_LT_FIELD]

## §4.6: `{field}` in a cue template.
const PLACEHOLDER_PATTERN: String = "\\{([a-z_]+)\\}"

static var _placeholder: RegEx = RegEx.create_from_string(PLACEHOLDER_PATTERN)


## §5.3 step 1: the first trigger of `on` (and of `key` — the sim type or the
## bus signal) whose `match` holds for `fields`; null when none does.
static func first_trigger(sheet: AudioSheet, on: String, key: String,
		fields: Dictionary) -> AudioTriggerDef:
	for trigger: AudioTriggerDef in sheet.triggers:
		if trigger.on != on:
			continue
		if on == AudioTriggerDef.ON_SIM and trigger.type != key:
			continue
		if on == AudioTriggerDef.ON_BUS and trigger.signal_name != key:
			continue
		if matches(trigger.conditions, fields):
			return trigger
	return null


## Whether every condition of `conditions` holds for `fields`.
static func matches(conditions: Dictionary, fields: Dictionary) -> bool:
	for field: Variant in conditions:
		if not holds(conditions[field], str(field), fields):
			return false
	return true


## §4.5: whether one condition holds for the field `field` of `fields`. An
## absent field fails everything but `not`.
static func holds(condition: Variant, field: String, fields: Dictionary) -> bool:
	var present: bool = fields.has(field)
	var value: Variant = fields.get(field)
	if typeof(condition) != TYPE_DICTIONARY:
		return present and _equals_any(value, condition)
	var operation: Dictionary = condition
	if operation.size() != 1:
		return false
	var op: String = str(operation.keys()[0])
	var argument: Variant = operation[op]
	match op:
		COND_NOT:
			return not present or not _equals_any(value, argument)
		COND_GT:
			return present and _is_number(value) and _is_number(argument) \
				and float(value) > float(argument)
		COND_LT:
			return present and _is_number(value) and _is_number(argument) \
				and float(value) < float(argument)
		COND_GT_FIELD, COND_LT_FIELD:
			var other: Variant = fields.get(str(argument))
			if not present or not _is_number(value) or not _is_number(other):
				return false
			return float(value) > float(other) if op == COND_GT_FIELD \
				else float(value) < float(other)
	return false


## §4.6: the cue a template names for `fields`; "" when a placeholder's field
## is missing (the trigger matched and the event is swallowed).
static func resolve(template: String, fields: Dictionary) -> String:
	var out: String = template
	for found: RegExMatch in _placeholder.search_all(template):
		var name: String = found.get_string(1)
		if not fields.has(name):
			return ""
		out = out.replace(found.get_string(), str(fields[name]))
	return out


## Whether `cue` is a template rather than a cue id.
static func is_template(cue: String) -> bool:
	return _placeholder.search(cue) != null


## §6.3: a stem's gain at a tension.
static func stem_gain(stem: AudioLoopDef, tension: float) -> float:
	return smoothstep(stem.fade.x, stem.fade.y, tension)


## §6.3: a gain as decibels, where 0 is `silent_db`.
static func gain_db(gain: float, silent_db: float) -> float:
	if gain <= 0.0:
		return silent_db
	return maxf(silent_db, linear_to_db(gain))


## §6.1: how many ambience layers a phase hears — Boxed one, Open all four.
static func layer_count(phase: int) -> int:
	return clampi(phase + 1, 1, World.PHASE_IDS.size())


## §3.2: the next step above `current`; after the largest the smallest.
static func next_volume(current: float) -> float:
	for step: float in VOLUME_STEPS:
		if step > current + STEP_EPSILON:
			return step
	return VOLUME_STEPS[0]


static func _equals_any(value: Variant, condition: Variant) -> bool:
	if typeof(condition) == TYPE_ARRAY:
		for option: Variant in condition:
			if _equals(value, option):
				return true
		return false
	return _equals(value, condition)


## An int and a float compare as numbers; a `StringName` as its string.
static func _equals(a: Variant, b: Variant) -> bool:
	if _is_number(a) and _is_number(b):
		return is_equal_approx(float(a), float(b))
	if _is_text(a) and _is_text(b):
		return str(a) == str(b)
	if typeof(a) != typeof(b):
		return false
	return a == b


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


static func _is_text(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME
