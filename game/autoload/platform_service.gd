extends Node
## The platform (release.md §1): one backend behind `PlatformBackend`. M6 has
## the null backend only; S6.14 adds Steam's. A backend is chosen at start from
## a feature tag, never by a compile-time reference, so every build compiles
## without GodotSteam.
##
## The profile is the only record of the achievements: the backend is a mirror,
## told about every earned one again at each start (§0 item 2).
##
## Registered after `ProfileManager` (it reads the profile at start) and before
## `Audio`. The autoload name is the global, so no `class_name`.

## The Steam preset's custom feature (S6.14).
const FEATURE_STEAM: String = "steam"
## GodotSteam's engine singleton.
const STEAM_SINGLETON: StringName = &"Steam"
const ACHIEVEMENT_PREFIX: String = "ACH_"
const STAT_PREFIX: String = "STAT_"
const VERSION_SETTING: String = "application/config/version"
const BUILD_DEBUG: String = "debug"
const BUILD_RELEASE: String = "release"
## §1.3: the log's first line (§10).
const START_LINE: String = "Doomsday %s · %s · %s · platform %s"

## Never null after `_ready`.
var backend: PlatformBackend = null

var _shut_down: bool = false


func _ready() -> void:
	EventBus.achievements_earned.connect(_on_achievements_earned)
	use_backend(_choose_backend())
	print(START_LINE % [str(ProjectSettings.get_setting(VERSION_SETTING, "")),
		BUILD_DEBUG if OS.is_debug_build() else BUILD_RELEASE, OS.get_name(), backend.id()])


func _process(_delta: float) -> void:
	backend.poll()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_shutdown()


func _exit_tree() -> void:
	_shutdown()


## The test door, and the one path every backend takes: start it (a backend
## that cannot start is replaced by the null backend), then tell it everything
## the profile has earned.
func use_backend(new_backend: PlatformBackend) -> void:
	if backend != null and backend.overlay_toggled.is_connected(_on_backend_overlay_toggled):
		backend.overlay_toggled.disconnect(_on_backend_overlay_toggled)
	var chosen: PlatformBackend = new_backend
	if not chosen.start():
		push_warning("platform: %s is unavailable, running without a platform" % chosen.id())
		chosen = NullPlatformBackend.new()
		chosen.start()
	backend = chosen
	_shut_down = false
	backend.overlay_toggled.connect(_on_backend_overlay_toggled)
	_sync(ProfileManager.achievements)


## §3.4: `ACH_` + the id in upper case.
func achievement_api_name(id: String) -> String:
	return ACHIEVEMENT_PREFIX + id.to_upper()


## §3.4: `STAT_` + the counter's name in upper case.
func stat_api_name(stat: String) -> String:
	return STAT_PREFIX + stat.to_upper()


## §1.3: the Steam backend when the build is Steam's and GodotSteam is loaded
## (S6.14 adds that branch), the null backend otherwise.
func _choose_backend() -> PlatformBackend:
	return NullPlatformBackend.new()


## Unlocks `ids` (those the book knows), sets both stats, one `store()`.
func _sync(ids: Array[String]) -> void:
	for id: String in ids:
		if ProfileManager.book.find(id) != null:
			backend.unlock_achievement(achievement_api_name(id))
	var profile: Dictionary = ProfileManager.to_dict()
	for stat: String in ProfileManager.book.stats:
		backend.set_stat(stat_api_name(stat), int(profile.get(stat, 0)))
	backend.store()


func _shutdown() -> void:
	if _shut_down or backend == null:
		return
	_shut_down = true
	backend.shutdown()


func _on_achievements_earned(ids: Array[String]) -> void:
	if backend != null:
		_sync(ids)


## §1.3: closing the overlay changes nothing — the player resumes.
func _on_backend_overlay_toggled(open: bool) -> void:
	if open:
		EventBus.platform_overlay_opened.emit()
