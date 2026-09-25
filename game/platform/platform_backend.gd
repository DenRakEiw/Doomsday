class_name PlatformBackend
extends RefCounted
## One platform's services (release.md §1). Every method is safe to call at any
## time, before `start()` included; a backend that cannot do something does nothing.
##
## The defaults are the null backend's behaviour: a new backend overrides only
## what its platform offers.

## Emitted when the platform's overlay opens (true) or closes (false).
signal overlay_toggled(open: bool)


## "null", "steam".
func id() -> String:
	return ""


## False when the platform is unavailable; the service then falls back to null.
func start() -> bool:
	return true


## Once per frame (Steam: run the callbacks).
func poll() -> void:
	pass


## Once, at quit.
func shutdown() -> void:
	pass


## Idempotent: unlocking an achievement twice is the same as once.
func unlock_achievement(_api_name: String) -> void:
	pass


## An absolute value, never a delta.
func set_stat(_api_name: String, _value: int) -> void:
	pass


## Flushes unlocks and stats after a batch.
func store() -> void:
	pass
