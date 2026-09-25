class_name FlashLimiter
extends RefCounted
## The photosensitivity guard of spec polish-visuals.md §6: every full-screen
## luminance change asks here first.
##
## Refused when an accepted flash is younger than `UiTokens.FLASH_MIN_GAP`, or
## when `UiTokens.FLASH_MAX` were accepted within the last `FLASH_WINDOW`. Time
## is passed in, so the rule is testable without waiting.

## The times of the flashes accepted within the window, oldest first.
var _accepted: Array[int] = []


## Whether a flash may start at `now_ms`; an allowed one is counted.
func allow(now_ms: int) -> bool:
	while not _accepted.is_empty() and now_ms - _accepted[0] >= UiTokens.FLASH_WINDOW:
		_accepted.pop_front()
	var last: int = -1 if _accepted.is_empty() else _accepted[_accepted.size() - 1]
	if not _accepted.is_empty() and now_ms - last < UiTokens.FLASH_MIN_GAP:
		return false
	if _accepted.size() >= UiTokens.FLASH_MAX:
		return false
	_accepted.append(now_ms)
	return true
