class_name AudioSheet
extends RefCounted
## `data/audio.json`, read, checked and typed (spec audio.md §4).
##
## Presentation data: the core never reads it. A bad sheet never crashes the
## game — `load_file` always returns a sheet, and `errors` says what is wrong;
## `Audio` runs silent on an invalid one.

const PATH: String = "res://data/audio.json"
const ASSET_ROOT: String = "res://assets/audio/"
const VERSION: int = 1

## §4.1: the buses, `master` first.
const BUS_MASTER: StringName = &"master"
const BUS_MUSIC: StringName = &"music"
const BUS_AMBIENCE: StringName = &"ambience"
const BUS_INTERFACE: StringName = &"interface"
const BUS_ALERTS: StringName = &"alerts"
const BUS_IDS: Array[StringName] = [BUS_MASTER, BUS_MUSIC, BUS_AMBIENCE, BUS_INTERFACE,
	BUS_ALERTS]
## The buses that own a pool of cue players; a cue plays on one of them.
const POOL_BUSES: Array[StringName] = [BUS_INTERFACE, BUS_ALERTS]
## §4.7: the screens outside the session.
const SCREEN_BOOT: StringName = &"boot"
const SCREEN_TITLE: StringName = &"title"
const SCREEN_SETUP: StringName = &"setup"
const SCREEN_IDS: Array[StringName] = [SCREEN_BOOT, SCREEN_TITLE, SCREEN_SETUP]

const EXT_CUE: String = ".wav"
const EXT_LOOP: String = ".ogg"
const ID_PATTERN: String = "^[a-z][a-z0-9_]*$"
const CAPTION_PREFIX: String = "UI_CAPTION_"

## §4.1–§4.7: the ranges the validator holds a value to.
const PRIORITY_MAX: int = 100
const LIMITER_RANGE: Vector2 = Vector2(-6.0, 0.0)
const TRIM_RANGE: Vector2 = Vector2(-24.0, 6.0)
const JITTER_MAX: float = 0.2
const PITCH_RANGE: Vector2 = Vector2(0.5, 2.0)
const FADE_RANGE: Vector2 = Vector2(-1.0, 1.0)
const SCREEN_DB_RANGE: Vector2 = Vector2(-40.0, 0.0)
const STEMS_MAX: int = 4

const ROOT_KEYS: Array[String] = ["version", "buses", "mix", "cues", "triggers", "ambience",
	"music", "screens"]
const BUS_KEYS: Array[String] = ["id", "send", "default_volume", "pool", "limiter_db"]
const MIX_KEYS: Array[String] = ["duck_db", "duck_attack_ms", "duck_release_ms",
	"alert_gap_ms", "alert_gap_priority", "hold_ambience_db", "hold_ms", "layer_fade_in_ms",
	"screen_fade_ms", "end_fade_ms", "tension_glide_ms", "preview_delay_ms", "silent_db"]
## The `mix` fields that are durations or a priority: whole numbers, never below 0.
const MIX_WHOLE_KEYS: Array[String] = ["duck_attack_ms", "duck_release_ms", "alert_gap_ms",
	"alert_gap_priority", "hold_ms", "layer_fade_in_ms", "screen_fade_ms", "end_fade_ms",
	"tension_glide_ms", "preview_delay_ms"]
const CUE_KEYS: Array[String] = ["id", "bus", "file", "priority", "cooldown_ms", "voices",
	"volume_db", "pitch_jitter", "duck", "final", "caption", "announce"]
const TRIGGER_KEYS: Array[String] = ["on", "type", "signal", "site", "match", "cue", "pitch"]
const LOOP_KEYS: Array[String] = ["id", "file", "volume_db", "fade"]
const SCREEN_KEYS: Array[String] = ["ambience_layers", "ambience_db", "music", "tension"]

var buses: Array[AudioBusDef] = []
var cues: Dictionary[StringName, AudioCueDef] = {}
var triggers: Array[AudioTriggerDef] = []
var layers: Array[AudioLoopDef] = []
var stems: Array[AudioLoopDef] = []
var screens: Dictionary[StringName, AudioScreenDef] = {}

## §4.2, typed.
var duck_db: float = 0.0
var duck_attack_ms: int = 0
var duck_release_ms: int = 0
var alert_gap_ms: int = 0
var alert_gap_priority: int = 0
var hold_ambience_db: float = 0.0
var hold_ms: int = 0
var layer_fade_in_ms: int = 0
var screen_fade_ms: int = 0
var end_fade_ms: int = 0
var tension_glide_ms: int = 0
var preview_delay_ms: int = 0
var silent_db: float = 0.0

## Empty = valid.
var errors: PackedStringArray = []

static var _id_regex: RegEx = RegEx.create_from_string(ID_PATTERN)


## Reads the sheet at `path`. Never null: a missing or broken file is a sheet
## with errors.
static func load_file(path: String = PATH) -> AudioSheet:
	if not FileAccess.file_exists(path):
		var missing: AudioSheet = AudioSheet.new()
		missing.errors.append("%s: missing" % path)
		return missing
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		var broken: AudioSheet = AudioSheet.new()
		broken.errors.append("%s:%d: %s" % [path, json.get_error_line(),
			json.get_error_message()])
		return broken
	return from_data(json.data)


## Builds a sheet from parsed JSON, as far as it goes, with every broken rule
## in `errors`.
static func from_data(data: Variant) -> AudioSheet:
	var sheet: AudioSheet = AudioSheet.new()
	if typeof(data) != TYPE_DICTIONARY:
		sheet.errors.append("audio: expected an object")
		return sheet
	var d: Dictionary = data
	sheet._check_keys(d, ROOT_KEYS, "audio")
	for key: String in ROOT_KEYS:
		if not d.has(key):
			sheet.errors.append("audio.%s: missing" % key)
	if d.has("version") and not (_is_whole(d["version"]) and int(d["version"]) == VERSION):
		sheet.errors.append("audio.version: expected %d" % VERSION)
	sheet._read_buses(d.get("buses"))
	sheet._read_mix(d.get("mix"))
	sheet._read_cues(d.get("cues"))
	sheet._read_triggers(d.get("triggers"))
	sheet._read_ambience(d.get("ambience"))
	sheet._read_music(d.get("music"))
	sheet._read_screens(d.get("screens"))
	return sheet


func is_valid() -> bool:
	return errors.is_empty()


## Null when unknown.
func cue(id: StringName) -> AudioCueDef:
	return cues.get(id, null) as AudioCueDef


## Null when unknown.
func bus(id: StringName) -> AudioBusDef:
	for def: AudioBusDef in buses:
		if def.id == id:
			return def
	return null


# ------------------------------------------------------------------ sections


func _read_buses(raw: Variant) -> void:
	if typeof(raw) != TYPE_ARRAY:
		if raw != null:
			errors.append("audio.buses: expected an array")
		return
	var seen: Array[StringName] = []
	var list: Array = raw
	for i: int in list.size():
		var where: String = "audio.buses[%d]" % i
		if typeof(list[i]) != TYPE_DICTIONARY:
			errors.append("%s: expected an object" % where)
			continue
		var d: Dictionary = list[i]
		_check_keys(d, BUS_KEYS, where)
		var def: AudioBusDef = AudioBusDef.new()
		def.id = StringName(str(d.get("id", "")))
		if not BUS_IDS.has(def.id):
			errors.append("%s.id: unknown bus \"%s\"" % [where, def.id])
		elif seen.has(def.id):
			errors.append("%s.id: \"%s\" twice" % [where, def.id])
		seen.append(def.id)
		if i == 0 and def.id != BUS_MASTER:
			errors.append("%s: master must be first" % where)
		var master: bool = def.id == BUS_MASTER
		def.send = str(d.get("send", ""))
		if def.send != ("" if master else String(BUS_MASTER)):
			errors.append("%s.send: expected \"%s\"" % [where, "" if master else String(BUS_MASTER)])
		def.default_volume = _number(d, "default_volume", where, 0.0, 1.0, true)
		if not _is_step(def.default_volume):
			errors.append("%s.default_volume: not one of the volume steps" % where)
		var pooled: bool = POOL_BUSES.has(def.id)
		if pooled:
			def.pool = _whole(d, "pool", where, 1, -1, true)
		elif d.has("pool"):
			errors.append("%s.pool: only interface and alerts have a pool" % where)
		if master:
			def.limiter_db = _number(d, "limiter_db", where, LIMITER_RANGE.x, LIMITER_RANGE.y,
				true)
		elif d.has("limiter_db"):
			errors.append("%s.limiter_db: master only" % where)
		buses.append(def)
	for id: StringName in BUS_IDS:
		if not seen.has(id):
			errors.append("audio.buses: \"%s\" missing" % id)


func _read_mix(raw: Variant) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		if raw != null:
			errors.append("audio.mix: expected an object")
		return
	var d: Dictionary = raw
	_check_keys(d, MIX_KEYS, "audio.mix")
	var values: Dictionary[String, float] = {}
	for key: String in MIX_KEYS:
		if MIX_WHOLE_KEYS.has(key):
			values[key] = float(_whole(d, key, "audio.mix", 0, -1, true))
		else:
			values[key] = _number(d, key, "audio.mix", -INF, 0.0, true)
	duck_db = values["duck_db"]
	duck_attack_ms = int(values["duck_attack_ms"])
	duck_release_ms = int(values["duck_release_ms"])
	alert_gap_ms = int(values["alert_gap_ms"])
	alert_gap_priority = int(values["alert_gap_priority"])
	hold_ambience_db = values["hold_ambience_db"]
	hold_ms = int(values["hold_ms"])
	layer_fade_in_ms = int(values["layer_fade_in_ms"])
	screen_fade_ms = int(values["screen_fade_ms"])
	end_fade_ms = int(values["end_fade_ms"])
	tension_glide_ms = int(values["tension_glide_ms"])
	preview_delay_ms = int(values["preview_delay_ms"])
	silent_db = values["silent_db"]


func _read_cues(raw: Variant) -> void:
	if typeof(raw) != TYPE_ARRAY:
		if raw != null:
			errors.append("audio.cues: expected an array")
		return
	var list: Array = raw
	for i: int in list.size():
		var where: String = "audio.cues[%d]" % i
		if typeof(list[i]) != TYPE_DICTIONARY:
			errors.append("%s: expected an object" % where)
			continue
		var d: Dictionary = list[i]
		_check_keys(d, CUE_KEYS, where)
		var def: AudioCueDef = AudioCueDef.new()
		def.id = StringName(str(d.get("id", "")))
		if not _is_id(String(def.id)):
			errors.append("%s.id: not an id" % where)
		elif cues.has(def.id):
			errors.append("%s.id: \"%s\" twice" % [where, def.id])
		def.bus = StringName(str(d.get("bus", "")))
		if not POOL_BUSES.has(def.bus):
			errors.append("%s.bus: expected interface or alerts" % where)
		def.file = _file(d, where, EXT_CUE)
		def.priority = _whole(d, "priority", where, 0, PRIORITY_MAX, true)
		def.cooldown_ms = _whole(d, "cooldown_ms", where, 0, -1, true)
		def.voices = _whole(d, "voices", where, 1, -1, true)
		def.volume_db = _number(d, "volume_db", where, TRIM_RANGE.x, TRIM_RANGE.y, false)
		def.pitch_jitter = _number(d, "pitch_jitter", where, 0.0, JITTER_MAX, false)
		var alerts: bool = def.bus == BUS_ALERTS
		def.duck = _flag(d, "duck", where)
		def.final = _flag(d, "final", where)
		def.announce = _flag(d, "announce", where)
		def.caption = str(d.get("caption", ""))
		if def.duck and not alerts:
			errors.append("%s.duck: alerts only" % where)
		if def.final and not alerts:
			errors.append("%s.final: alerts only" % where)
		if not def.caption.is_empty():
			if not alerts:
				errors.append("%s.caption: an interface cue has no caption" % where)
			if not def.caption.begins_with(CAPTION_PREFIX):
				errors.append("%s.caption: expected a %s key" % [where, CAPTION_PREFIX])
		if def.announce and (not alerts or def.caption.is_empty()):
			errors.append("%s.announce: an alert with a caption only" % where)
		if not cues.has(def.id):
			cues[def.id] = def


func _read_triggers(raw: Variant) -> void:
	if typeof(raw) != TYPE_ARRAY:
		if raw != null:
			errors.append("audio.triggers: expected an array")
		return
	var buttons: int = 0
	var list: Array = raw
	for i: int in list.size():
		var where: String = "audio.triggers[%d]" % i
		if typeof(list[i]) != TYPE_DICTIONARY:
			errors.append("%s: expected an object" % where)
			continue
		var d: Dictionary = list[i]
		_check_keys(d, TRIGGER_KEYS, where)
		var def: AudioTriggerDef = AudioTriggerDef.new()
		def.on = str(d.get("on", ""))
		if not AudioTriggerDef.ONS.has(def.on):
			errors.append("%s.on: unknown source \"%s\"" % [where, def.on])
		def.type = str(d.get("type", ""))
		if def.on == AudioTriggerDef.ON_SIM:
			if not SimEvent.TYPES_ALL.has(def.type):
				errors.append("%s.type: unknown event type \"%s\"" % [where, def.type])
		elif d.has("type"):
			errors.append("%s.type: sim triggers only" % where)
		def.signal_name = str(d.get("signal", ""))
		if def.on == AudioTriggerDef.ON_BUS:
			if not AudioTriggerDef.SIGNALS.has(def.signal_name):
				errors.append("%s.signal: unknown signal \"%s\"" % [where, def.signal_name])
		elif d.has("signal"):
			errors.append("%s.signal: bus triggers only" % where)
		def.site = str(d.get("site", ""))
		if def.on == AudioTriggerDef.ON_CALL:
			if def.site.strip_edges().is_empty():
				errors.append("%s.site: a call trigger names its site" % where)
		elif d.has("site"):
			errors.append("%s.site: call triggers only" % where)
		if def.on == AudioTriggerDef.ON_BUTTON:
			buttons += 1
			if buttons > 1:
				errors.append("%s: at most one button trigger" % where)
		if d.has("match"):
			if typeof(d["match"]) == TYPE_DICTIONARY:
				def.conditions = d["match"]
				_check_match(def.conditions, where + ".match")
			else:
				errors.append("%s.match: expected an object" % where)
		def.cue = str(d.get("cue", ""))
		if def.cue.is_empty():
			errors.append("%s.cue: missing" % where)
		elif not AudioRules.is_template(def.cue) and not cues.has(StringName(def.cue)):
			errors.append("%s.cue: unknown cue \"%s\"" % [where, def.cue])
		def.pitch = _number(d, "pitch", where, PITCH_RANGE.x, PITCH_RANGE.y, false, 1.0)
		triggers.append(def)


func _read_ambience(raw: Variant) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		if raw != null:
			errors.append("audio.ambience: expected an object")
		return
	layers = _read_loops((raw as Dictionary).get("layers"), "audio.ambience.layers", false)
	var ids: Array[String] = []
	for layer: AudioLoopDef in layers:
		ids.append(String(layer.id))
	if ids != World.PHASE_IDS:
		errors.append("audio.ambience.layers: expected one per phase, %s" % [World.PHASE_IDS])


func _read_music(raw: Variant) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		if raw != null:
			errors.append("audio.music: expected an object")
		return
	stems = _read_loops((raw as Dictionary).get("stems"), "audio.music.stems", true)
	if stems.is_empty() or stems.size() > STEMS_MAX:
		errors.append("audio.music.stems: expected 1 to %d" % STEMS_MAX)


func _read_loops(raw: Variant, where: String, with_fade: bool) -> Array[AudioLoopDef]:
	var out: Array[AudioLoopDef] = []
	if typeof(raw) != TYPE_ARRAY:
		errors.append("%s: expected an array" % where)
		return out
	var list: Array = raw
	for i: int in list.size():
		var at: String = "%s[%d]" % [where, i]
		if typeof(list[i]) != TYPE_DICTIONARY:
			errors.append("%s: expected an object" % at)
			continue
		var d: Dictionary = list[i]
		_check_keys(d, LOOP_KEYS, at)
		var def: AudioLoopDef = AudioLoopDef.new()
		def.id = StringName(str(d.get("id", "")))
		if not _is_id(String(def.id)):
			errors.append("%s.id: not an id" % at)
		def.file = _file(d, at, EXT_LOOP)
		def.volume_db = _number(d, "volume_db", at, TRIM_RANGE.x, TRIM_RANGE.y, false)
		if with_fade:
			def.fade = _fade(d.get("fade"), at + ".fade")
		elif d.has("fade"):
			errors.append("%s.fade: stems only" % at)
		out.append(def)
	return out


func _read_screens(raw: Variant) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		if raw != null:
			errors.append("audio.screens: expected an object")
		return
	var d: Dictionary = raw
	for key: Variant in d:
		if str(key).begins_with("_"):
			continue
		if not SCREEN_IDS.has(StringName(str(key))):
			errors.append("audio.screens.%s: unknown screen" % key)
	for id: StringName in SCREEN_IDS:
		var where: String = "audio.screens.%s" % id
		if typeof(d.get(id)) != TYPE_DICTIONARY:
			errors.append("%s: missing" % where)
			continue
		var s: Dictionary = d[id]
		_check_keys(s, SCREEN_KEYS, where)
		var def: AudioScreenDef = AudioScreenDef.new()
		def.ambience_layers = _whole(s, "ambience_layers", where, 0, World.PHASE_IDS.size(),
			true)
		def.ambience_db = _number(s, "ambience_db", where, SCREEN_DB_RANGE.x, SCREEN_DB_RANGE.y,
			true)
		def.tension = _number(s, "tension", where, 0.0, 1.0, true)
		if typeof(s.get("music")) != TYPE_BOOL:
			errors.append("%s.music: expected true or false" % where)
		def.music = s.get("music") == true
		screens[id] = def


# ------------------------------------------------------------------- checks


## §4.5: every condition is a scalar, an array of scalars, or an object with
## exactly one known key.
func _check_match(conditions: Dictionary, where: String) -> void:
	for field: Variant in conditions:
		var condition: Variant = conditions[field]
		var at: String = "%s.%s" % [where, field]
		if typeof(condition) == TYPE_ARRAY:
			if not _all_scalars(condition):
				errors.append("%s: an array holds scalars only" % at)
			continue
		if typeof(condition) != TYPE_DICTIONARY:
			if not _is_scalar(condition):
				errors.append("%s: expected a scalar, an array or a condition" % at)
			continue
		var operation: Dictionary = condition
		if operation.size() != 1:
			errors.append("%s: a condition has exactly one key" % at)
			continue
		var op: String = str(operation.keys()[0])
		var argument: Variant = operation[op]
		match op:
			AudioRules.COND_NOT:
				if not (_is_scalar(argument) or (typeof(argument) == TYPE_ARRAY
						and _all_scalars(argument))):
					errors.append("%s.not: expected a scalar or an array" % at)
			AudioRules.COND_GT, AudioRules.COND_LT:
				if not _is_number(argument):
					errors.append("%s.%s: expected a number" % [at, op])
			AudioRules.COND_GT_FIELD, AudioRules.COND_LT_FIELD:
				if typeof(argument) != TYPE_STRING or str(argument).is_empty():
					errors.append("%s.%s: expected a field name" % [at, op])
			_:
				errors.append("%s: unknown condition \"%s\"" % [at, op])


func _check_keys(d: Dictionary, allowed: Array[String], where: String) -> void:
	for key: Variant in d:
		var name: String = str(key)
		if not name.begins_with("_") and not allowed.has(name):
			errors.append("%s.%s: unknown field" % [where, name])


## A number in `lo`…`hi`; the default when absent and not required.
func _number(d: Dictionary, key: String, where: String, lo: float, hi: float,
		required: bool, fallback: float = 0.0) -> float:
	if not d.has(key):
		if required:
			errors.append("%s.%s: missing" % [where, key])
		return fallback
	if not _is_number(d[key]):
		errors.append("%s.%s: expected a number" % [where, key])
		return fallback
	var value: float = float(d[key])
	if value < lo or value > hi:
		errors.append("%s.%s: %s outside %s…%s" % [where, key, value, lo, hi])
	return value


## A whole number of at least `lo` and, unless `hi` is −1, at most `hi`.
func _whole(d: Dictionary, key: String, where: String, lo: int, hi: int,
		required: bool) -> int:
	if not d.has(key):
		if required:
			errors.append("%s.%s: missing" % [where, key])
		return lo
	if not _is_whole(d[key]):
		errors.append("%s.%s: expected a whole number" % [where, key])
		return lo
	var value: int = int(d[key])
	if value < lo or (hi >= 0 and value > hi):
		errors.append("%s.%s: %d out of range" % [where, key, value])
	return value


func _flag(d: Dictionary, key: String, where: String) -> bool:
	if not d.has(key):
		return false
	if typeof(d[key]) != TYPE_BOOL:
		errors.append("%s.%s: expected true or false" % [where, key])
		return false
	return bool(d[key])


func _file(d: Dictionary, where: String, extension: String) -> String:
	var file: String = str(d.get("file", ""))
	if file.is_empty() or not file.ends_with(extension) or file.begins_with("/") \
			or file.contains("://") or file.contains(".."):
		errors.append("%s.file: expected a path under %s ending %s" % [where, ASSET_ROOT,
			extension])
	return file


func _fade(raw: Variant, where: String) -> Vector2:
	if typeof(raw) != TYPE_ARRAY or (raw as Array).size() != 2 \
			or not _is_number((raw as Array)[0]) or not _is_number((raw as Array)[1]):
		errors.append("%s: expected [lo, hi]" % where)
		return Vector2.ZERO
	var fade: Vector2 = Vector2(float((raw as Array)[0]), float((raw as Array)[1]))
	if fade.x >= fade.y:
		errors.append("%s: lo must be below hi" % where)
	if fade.x < FADE_RANGE.x or fade.y > FADE_RANGE.y:
		errors.append("%s: outside %s…%s" % [where, FADE_RANGE.x, FADE_RANGE.y])
	return fade


static func _is_step(value: float) -> bool:
	for step: float in AudioRules.VOLUME_STEPS:
		if absf(step - value) < AudioRules.STEP_EPSILON:
			return true
	return false


static func _is_id(value: String) -> bool:
	return _id_regex.search(value) != null


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


## JSON reads every number as a float; a whole one is an int for the sheet.
static func _is_whole(value: Variant) -> bool:
	return _is_number(value) and float(value) == floorf(float(value))


static func _is_scalar(value: Variant) -> bool:
	var kind: int = typeof(value)
	return kind == TYPE_INT or kind == TYPE_FLOAT or kind == TYPE_BOOL or kind == TYPE_STRING


static func _all_scalars(values: Array) -> bool:
	for value: Variant in values:
		if not _is_scalar(value):
			return false
	return true
