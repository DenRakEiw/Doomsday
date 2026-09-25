class_name LiveRegion
extends Label
## A line a screen reader speaks when it changes (spec accessibility.md §3.4).
##
## It is a real, drawn `Label` so the platform's accessibility tree has it — a
## hidden node is dropped from that tree — but it is drawn transparent, one pixel
## large, and takes neither the pointer nor the focus. It must sit under a parent
## that is never hidden, outside any container (it has no layout of its own).
##
## While no screen reader runs nothing is written, so a player without one never
## pays for it; tests set `force_active`.

## Every other `say` of the same text gets this appended, so the platform sees a
## change and speaks the line again.
const REPEAT_MARK: String = " "
## `DisplayServer.accessibility_screen_reader_active()` answers this when a reader
## runs (-1 is "unknown", 0 "none").
const READER_ACTIVE: int = 1

## Assertive interrupts what is being read; polite waits for a pause.
@export var assertive: bool = false:
	set(value):
		assertive = value
		_apply_live()

## Speaks even with no screen reader running — for tests.
var force_active: bool = false


func _init() -> void:
	custom_minimum_size = Vector2.ONE
	size = Vector2.ONE
	clip_text = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	self_modulate.a = 0.0
	_apply_live()


## Speaks `text` once. Nothing while no screen reader runs (unless
## `force_active`).
func say(line: String) -> void:
	if line.is_empty() or not (force_active or is_reader_active()):
		return
	# The same line twice would be no change at all to the platform.
	if line == text.trim_suffix(REPEAT_MARK) and not text.ends_with(REPEAT_MARK):
		line += REPEAT_MARK
	text = line
	queue_accessibility_update()


## Whether a screen reader is running right now.
static func is_reader_active() -> bool:
	return DisplayServer.accessibility_screen_reader_active() == READER_ACTIVE


func _apply_live() -> void:
	accessibility_live = AccessibilityServer.LIVE_ASSERTIVE if assertive \
		else AccessibilityServer.LIVE_POLITE
