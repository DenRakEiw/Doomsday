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
## Stored from M2 on, applied from S4.9 on (UI.md §5).
const DEFAULT_TEXT_SCALE: float = 1.0
## Two scales closer than this are the same step.
const TEXT_SCALE_EPSILON: float = 0.001

## The keys of the dictionary `values_from` returns and `to_dict` writes.
const KEY_VERSION: String = "version"
const KEY_LOCALE: String = "locale"
const KEY_REDUCED_MOTION: String = "reduced_motion"
const KEY_TEXT_SCALE: String = "text_scale"
const KEY_TREE_PAUSES: String = "tree_pauses"
## first-run.md §3.1: the guided first run is on until it is finished or skipped.
const KEY_TUTORIAL: String = "tutorial"
## first-run.md §6.1: the hints of Tutorial II, each once per profile.
const KEY_HINTS: String = "hints"
## screens-full.md §6.3: the boot sequence in full on every launch, not only the first.
const KEY_BOOT_ALWAYS: String = "boot_always"
## polish-visuals.md §5.1: the intensity of the full-screen pass, 0…1.
const KEY_SCREEN_EFFECTS: String = "screen_effects"
## audio.md §3.2: one volume per bus, `volume_<bus id>`, 0…1. An absent key is
## the sheet's default, which `Audio` knows and this file does not.
const KEY_VOLUME_PREFIX: String = "volume_"
## The volumes `values_from` read, bus id → value (not a key of the file).
const KEY_VOLUMES: String = "volumes"
const KEY_SOUND_CAPTIONS: String = "sound_captions"
const KEY_AUDIO_BACKGROUND: String = "audio_background"
## accessibility.md §3.4: headlines spoken to a screen reader.
const KEY_ANNOUNCE_HEADLINES: String = "announce_headlines"
## accessibility.md §5.2: action → physical keycode, only the player's overrides.
const KEY_KEYS: String = "keys"
## benchmark.md §16.6: the online leaderboard may be fetched when the benchmark
## list opens. Off, the game never touches the network.
const KEY_BENCH_ONLINE: String = "bench_online"
## The key table's own rules decide which stored overrides a build can apply.
const KeyBindingsScript: GDScript = preload("res://game/autoload/key_bindings.gd")
## `DisplayServer.accessibility_should_reduce_animation()` answers this for yes.
const OS_ANSWER_YES: int = 1
## Where a desktop and a handheld start (§5.1).
const FEATURE_WEB: String = "web"
## After `--` on the command line: start with the pseudo-locale on (UI.md §4).
const ARG_PSEUDO: String = "--pseudo"

var locale: String = LOCALE_EN
var reduced_motion: bool = DEFAULT_REDUCED_MOTION
var text_scale: float = DEFAULT_TEXT_SCALE
var tree_pauses: bool = true
var tutorial: bool = true
var hints: bool = true
var boot_always: bool = false
## One of `UiTokens.FX_INTENSITIES`; a stored value between the steps is kept.
var screen_effects: float = UiTokens.FX_INTENSITY_DESKTOP
## audio.md §3.2: the volumes the player has set, bus id → 0…1. A bus that is
## not here plays at the sheet's default.
var volumes: Dictionary[String, float] = {}
## audio.md §8: the caption stack on the map's left.
var sound_captions: bool = false
## audio.md §5.7: false mutes the game while its window has no focus (desktop).
var audio_background: bool = true
## accessibility.md §3.4: the ticker speaks its headlines to a screen reader.
var announce_headlines: bool = true
## accessibility.md §5.2: the overrides `KeyBindings` applies over the defaults.
var keys: Dictionary[String, int] = {}
## benchmark.md §16.6: the benchmark list may download the global leaderboard.
var bench_online: bool = true
## The overflow check of UI.md §4. A development switch, never written to the file.
var pseudo_locale: bool = false
## release.md §8: false keeps every change in memory — the smoke run's switch, so
## a bot run never touches the player's file.
var persist: bool = true


func _ready() -> void:
	# release.md §5: the first start in the game's own user folder brings the old
	# one's files along before anything reads them (S6.10).
	UserDataMigration.run()
	var values: Dictionary = values_from(_read(), system_locale(), os_reduced_motion())
	locale = str(values[KEY_LOCALE])
	reduced_motion = bool(values[KEY_REDUCED_MOTION])
	text_scale = float(values[KEY_TEXT_SCALE])
	tree_pauses = bool(values[KEY_TREE_PAUSES])
	tutorial = bool(values[KEY_TUTORIAL])
	hints = bool(values[KEY_HINTS])
	boot_always = bool(values[KEY_BOOT_ALWAYS])
	screen_effects = float(values[KEY_SCREEN_EFFECTS])
	var stored_volumes: Dictionary = values[KEY_VOLUMES]
	for bus: Variant in stored_volumes:
		volumes[str(bus)] = float(stored_volumes[bus])
	sound_captions = bool(values[KEY_SOUND_CAPTIONS])
	audio_background = bool(values[KEY_AUDIO_BACKGROUND])
	announce_headlines = bool(values[KEY_ANNOUNCE_HEADLINES])
	var stored_keys: Dictionary = values[KEY_KEYS]
	for action: Variant in stored_keys:
		keys[str(action)] = int(stored_keys[action])
	bench_online = bool(values[KEY_BENCH_ONLINE])
	TranslationServer.set_locale(locale)
	write()
	apply_args(OS.get_cmdline_user_args())


## The command line's development switch (UI.md §4). release.md §7: a release
## build ignores it — `Game.debug_allowed` is the one gate.
func apply_args(args: PackedStringArray) -> void:
	if Game.debug_allowed and args.has(ARG_PSEUDO):
		set_pseudo_locale(true)


## Whether opening the tech tree should pause the run when the file says nothing.
static func default_tree_pauses() -> bool:
	return not OS.has_feature(FEATURE_MOBILE)


## §5.1: a phone or a browser starts at Subtle, a desktop at Full.
static func default_screen_effects() -> float:
	if OS.has_feature(FEATURE_MOBILE) or OS.has_feature(FEATURE_WEB):
		return UiTokens.FX_INTENSITY_HANDHELD
	return UiTokens.FX_INTENSITY_DESKTOP


## accessibility.md §9 item 3: whether the machine asks for less animation.
## Read once, for a first launch; after that the stored value rules.
static func os_reduced_motion() -> bool:
	return DisplayServer.accessibility_should_reduce_animation() == OS_ANSWER_YES


## The locale the machine asks for, as one of `LOCALES`.
static func system_locale() -> String:
	return LOCALE_DE if OS.get_locale_language() == LOCALE_DE else LOCALE_EN


## Every field of a settings file, each replaced by its default when it is
## missing or not the type it should be. Static and side-effect free, so the
## whole of the file format is testable without touching the disk.
## `first_reduced_motion` is what a first launch — no file at all — starts with
## (accessibility.md §9 item 3: the OS's answer).
static func values_from(raw: Variant, fallback_locale: String,
		first_reduced_motion: bool = DEFAULT_REDUCED_MOTION) -> Dictionary:
	var values: Dictionary = {
		KEY_LOCALE: fallback_locale,
		KEY_REDUCED_MOTION: first_reduced_motion if raw == null else DEFAULT_REDUCED_MOTION,
		KEY_TEXT_SCALE: DEFAULT_TEXT_SCALE,
		KEY_TREE_PAUSES: default_tree_pauses(),
		KEY_TUTORIAL: true,
		KEY_HINTS: true,
		KEY_BOOT_ALWAYS: false,
		KEY_SCREEN_EFFECTS: default_screen_effects(),
		KEY_VOLUMES: {},
		KEY_SOUND_CAPTIONS: false,
		KEY_AUDIO_BACKGROUND: true,
		KEY_ANNOUNCE_HEADLINES: true,
		KEY_KEYS: {},
		KEY_BENCH_ONLINE: true,
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
	if typeof(stored.get(KEY_TUTORIAL)) == TYPE_BOOL:
		values[KEY_TUTORIAL] = bool(stored[KEY_TUTORIAL])
	if typeof(stored.get(KEY_HINTS)) == TYPE_BOOL:
		values[KEY_HINTS] = bool(stored[KEY_HINTS])
	if typeof(stored.get(KEY_BOOT_ALWAYS)) == TYPE_BOOL:
		values[KEY_BOOT_ALWAYS] = bool(stored[KEY_BOOT_ALWAYS])
	var effects_type: int = typeof(stored.get(KEY_SCREEN_EFFECTS))
	if effects_type == TYPE_FLOAT or effects_type == TYPE_INT:
		values[KEY_SCREEN_EFFECTS] = float(stored[KEY_SCREEN_EFFECTS])
	var read_volumes: Dictionary = {}
	for key: Variant in stored:
		var field: String = str(key)
		var kind: int = typeof(stored[key])
		var bus: String = field.trim_prefix(KEY_VOLUME_PREFIX)
		if bus == field or bus.is_empty() or (kind != TYPE_FLOAT and kind != TYPE_INT):
			continue
		read_volumes[bus] = clampf(float(stored[key]), 0.0, 1.0)
	values[KEY_VOLUMES] = read_volumes
	if typeof(stored.get(KEY_SOUND_CAPTIONS)) == TYPE_BOOL:
		values[KEY_SOUND_CAPTIONS] = bool(stored[KEY_SOUND_CAPTIONS])
	if typeof(stored.get(KEY_AUDIO_BACKGROUND)) == TYPE_BOOL:
		values[KEY_AUDIO_BACKGROUND] = bool(stored[KEY_AUDIO_BACKGROUND])
	if typeof(stored.get(KEY_ANNOUNCE_HEADLINES)) == TYPE_BOOL:
		values[KEY_ANNOUNCE_HEADLINES] = bool(stored[KEY_ANNOUNCE_HEADLINES])
	values[KEY_KEYS] = _keys_from(stored.get(KEY_KEYS))
	if typeof(stored.get(KEY_BENCH_ONLINE)) == TYPE_BOOL:
		values[KEY_BENCH_ONLINE] = bool(stored[KEY_BENCH_ONLINE])
	return values


## The stored key overrides a build can apply; everything else is dropped.
static func _keys_from(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var stored: Dictionary = raw
	for action: Variant in stored:
		if typeof(action) != TYPE_STRING:
			continue
		if KeyBindingsScript.is_valid_override(str(action), stored[action]):
			out[str(action)] = int(stored[action])
	return out


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


## UI.md §5. A value between the steps of `UiTokens.TEXT_SCALES` is kept as it
## is; the theme clamps it to the range.
func set_text_scale(value: float) -> void:
	if is_equal_approx(value, text_scale):
		return
	text_scale = value
	write()
	EventBus.text_scale_changed.emit(text_scale)


## The settings button: the next step up, and after the largest the smallest.
func cycle_text_scale() -> void:
	for step: float in UiTokens.TEXT_SCALES:
		if step > text_scale + TEXT_SCALE_EPSILON:
			set_text_scale(step)
			return
	set_text_scale(UiTokens.TEXT_SCALES.front())


## polish-visuals.md §5.1. The pass clamps the value to 0…1.
func set_screen_effects(value: float) -> void:
	if is_equal_approx(value, screen_effects):
		return
	screen_effects = value
	write()
	EventBus.screen_effects_changed.emit(screen_effects)


## The settings button and debug key **V**: the next step up, and after the
## largest the smallest.
func cycle_screen_effects() -> void:
	for step: float in UiTokens.FX_INTENSITIES:
		if step > screen_effects + TEXT_SCALE_EPSILON:
			set_screen_effects(step)
			return
	set_screen_effects(UiTokens.FX_INTENSITIES.front())


## audio.md §3.2: a bus's volume, clamped to 0…1. `Audio` applies it.
func set_volume(bus: String, value: float) -> void:
	var clamped: float = clampf(value, 0.0, 1.0)
	if volumes.has(bus) and is_equal_approx(volumes[bus], clamped):
		return
	volumes[bus] = clamped
	write()
	EventBus.volume_changed.emit(StringName(bus), clamped)


func set_sound_captions(enabled: bool) -> void:
	if enabled == sound_captions:
		return
	sound_captions = enabled
	write()
	EventBus.sound_captions_changed.emit(sound_captions)


## accessibility.md §3.4.
func set_announce_headlines(enabled: bool) -> void:
	if enabled == announce_headlines:
		return
	announce_headlines = enabled
	write()


## accessibility.md §5.2: `KeyBindings` hands over the whole set of overrides.
func set_keys(value: Dictionary[String, int]) -> void:
	if value == keys:
		return
	keys = value.duplicate()
	write()


func set_audio_background(enabled: bool) -> void:
	if enabled == audio_background:
		return
	audio_background = enabled
	write()


## Shows the pseudo-locale in place of English, whatever the stored locale is;
## off, the stored locale comes back. Nothing is written.
func set_pseudo_locale(enabled: bool) -> void:
	if enabled == pseudo_locale:
		return
	if enabled and not PseudoLocale.enable():
		push_warning("pseudo-locale: there is no string table to build it from")
		return
	if not enabled:
		PseudoLocale.disable()
	pseudo_locale = enabled
	var shown: String = LOCALE_EN if enabled else locale
	TranslationServer.set_locale(shown)
	# Swapping a translation under an unchanged locale notifies nobody, and the
	# texts on screen would stay English until something else changed the locale.
	get_tree().root.propagate_notification(NOTIFICATION_TRANSLATION_CHANGED)
	EventBus.locale_changed.emit(shown)


func set_tree_pauses(enabled: bool) -> void:
	if enabled == tree_pauses:
		return
	tree_pauses = enabled
	write()
	EventBus.tree_pauses_changed.emit(tree_pauses)


## On: the next run of a player shows the introduction from its first step.
func set_tutorial(enabled: bool) -> void:
	if enabled == tutorial:
		return
	tutorial = enabled
	write()


## first-run.md §6.1: switching the hints back on shows every one of them once
## more, the way the introduction's row starts it from step 1 again.
func set_hints(enabled: bool) -> void:
	if enabled == hints:
		return
	hints = enabled
	write()
	if enabled:
		ProfileManager.clear_hints_seen()


func set_boot_always(enabled: bool) -> void:
	if enabled == boot_always:
		return
	boot_always = enabled
	write()


func set_bench_online(enabled: bool) -> void:
	if enabled == bench_online:
		return
	bench_online = enabled
	write()


func to_dict() -> Dictionary:
	var out: Dictionary = {
		KEY_VERSION: VERSION,
		KEY_LOCALE: locale,
		KEY_REDUCED_MOTION: reduced_motion,
		KEY_TEXT_SCALE: text_scale,
		KEY_TREE_PAUSES: tree_pauses,
		KEY_TUTORIAL: tutorial,
		KEY_HINTS: hints,
		KEY_BOOT_ALWAYS: boot_always,
		KEY_SCREEN_EFFECTS: screen_effects,
		KEY_SOUND_CAPTIONS: sound_captions,
		KEY_AUDIO_BACKGROUND: audio_background,
		KEY_ANNOUNCE_HEADLINES: announce_headlines,
		KEY_KEYS: keys.duplicate(),
		KEY_BENCH_ONLINE: bench_online,
	}
	for bus: String in volumes:
		out[KEY_VOLUME_PREFIX + bus] = volumes[bus]
	return out


func write() -> void:
	if not persist:
		return
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
