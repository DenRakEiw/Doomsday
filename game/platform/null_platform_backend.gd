class_name NullPlatformBackend
extends PlatformBackend
## No platform (release.md §1.1): every build without Steam, and the fallback
## when a platform's `start()` fails. The profile stays the only record.

const ID: String = "null"


func id() -> String:
	return ID


func start() -> bool:
	return true
