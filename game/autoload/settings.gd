extends Node
## The settings M2 needs, in `user://settings.json` (spec ui-foundation.md §9).
##
## A missing, unreadable or invalid file is not an error: the defaults apply and
## the file is rewritten. Reading settings never fails a run.
##
## An autoload, so no `class_name`.

const PATH: String = "user://settings.json"
const VERSION: int = 1

const LOCALE_EN: String = "en"
const LOCALE_DE: String = "de"
const LOCALES: Array[String] = [LOCALE_EN, LOCALE_DE]

const DEFAULT_REDUCED_MOTION: bool = false
## m3-screens §3.1: the tech tree pauses the run on desktop and does not on a
## phone, where the modal covers the whole screen anyway.
const FEATURE_MOBILE: String = "mobile"
## Stored from M2 on and applied from M5 on (§9.3).
const DEFAULT_TEXT_SCALE: float = 1.0

## The keys of the dictionary `values_from` returns and `to_dict` writes.
const KEY_VERSION: String = "version"
const KEY_LOCALE: String = "locale"
const KEY_REDUCED_MOTION: String = "reduced_motion"
const KEY_TEXT_SCALE: String = "text_scale"
const KEY_TREE_PAUSES: String = "tree_pauses"

var locale: String = LOCALE_EN
var reduced_motion: bool = DEFAULT_REDUCED_MOTION
var text_scale: float = DEFAULT_TEXT_SCALE
var tree_pauses: bool = true


func _ready() -> void:
	var values: Dictionary = values_from(_read(), system_locale())
	locale = str(values[KEY_LOCALE])
	reduced_motion = bool(values[KEY_REDUCED_MOTION])
	text_scale = float(values[KEY_TEXT_SCALE])
	tree_pauses = bool(values[KEY_TREE_PAUSES])
	TranslationServer.set_locale(locale)
	write()


## Whether opening the tech tree should pause the run when the file says nothing.
static func default_tree_pauses() -> bool:
	return not OS.has_feature(FEATURE_MOBILE)


## The locale the machine asks for, as one of `LOCALES`.
static func system_locale() -> String:
	return LOCALE_DE if OS.get_locale_language() == LOCALE_DE else LOCALE_EN


## Every field of a settings file, each replaced by its default when it is
## missing or not the type it should be. Static and side-effect free, so the
## whole of the file format is testable without touching the disk.
static func values_from(raw: Variant, fallback_locale: String) -> Dictionary:
	var values: Dictionary = {
		KEY_LOCALE: fallback_locale,
		KEY_REDUCED_MOTION: DEFAULT_REDUCED_MOTION,
		KEY_TEXT_SCALE: DEFAULT_TEXT_SCALE,
		KEY_TREE_PAUSES: default_tree_pauses(),
	}
	if typeof(raw) != TYPE_DICTIONARY:
		return values
	var stored: Dictionary = raw
	# A file from another version is read as far as it goes: every field falls
	# back on its own, so a new key never invalidates the old ones.
	if typeof(stored.get(KEY_LOCALE)) == TYPE_STRING and LOCALES.has(str(stored[KEY_LOCALE])):
		values[KEY_LOCALE] = str(stored[KEY_LOCALE])
	if typeof(stored.get(KEY_REDUCED_MOTION)) == TYPE_BOOL:
		values[KEY_REDUCED_MOTION] = bool(stored[KEY_REDUCED_MOTION])
	var scale_type: int = typeof(stored.get(KEY_TEXT_SCALE))
	if scale_type == TYPE_FLOAT or scale_type == TYPE_INT:
		values[KEY_TEXT_SCALE] = float(stored[KEY_TEXT_SCALE])
	if typeof(stored.get(KEY_TREE_PAUSES)) == TYPE_BOOL:
		values[KEY_TREE_PAUSES] = bool(stored[KEY_TREE_PAUSES])
	return values


func set_locale(value: String) -> void:
	if not LOCALES.has(value) or value == locale:
		return
	locale = value
	TranslationServer.set_locale(locale)
	write()
	EventBus.locale_changed.emit(locale)


## The debug key of §9.1 — M2 has no settings screen.
func toggle_locale() -> void:
	set_locale(LOCALE_EN if locale == LOCALE_DE else LOCALE_DE)


func set_reduced_motion(enabled: bool) -> void:
	if enabled == reduced_motion:
		return
	reduced_motion = enabled
	write()
	EventBus.reduced_motion_changed.emit(reduced_motion)


func set_tree_pauses(enabled: bool) -> void:
	if enabled == tree_pauses:
		return
	tree_pauses = enabled
	write()
	EventBus.tree_pauses_changed.emit(tree_pauses)


func to_dict() -> Dictionary:
	return {
		KEY_VERSION: VERSION,
		KEY_LOCALE: locale,
		KEY_REDUCED_MOTION: reduced_motion,
		KEY_TEXT_SCALE: text_scale,
		KEY_TREE_PAUSES: tree_pauses,
	}


func write() -> void:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		# A read-only user directory is the player's problem, not a crash of ours.
		push_warning("settings: cannot write %s (%d)" % [PATH, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(to_dict(), "\t", true, true))


func _read() -> Variant:
	if not FileAccess.file_exists(PATH):
		return null
	var file: FileAccess = FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return null
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return null
	return json.data
