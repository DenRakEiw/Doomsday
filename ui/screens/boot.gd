extends Control
## The boot sequence (spec `screens-full.md` §2): a diegetic console before the
## title. Eleven lines on the first launch, two on every later one, and any key,
## click or tap goes straight on.
##
## The clock is the scene's own, advanced by `step`, so a test can walk it
## without waiting on real time.
##
## Scene-specific, so no `class_name`.

const LINE_KEYS: Array[String] = ["BOOT_LINE_01", "BOOT_LINE_02", "BOOT_LINE_03",
	"BOOT_LINE_04", "BOOT_LINE_05", "BOOT_LINE_06", "BOOT_LINE_07", "BOOT_LINE_08",
	"BOOT_LINE_09", "BOOT_LINE_10", "BOOT_LINE_11"]
const KEY_RESUME: String = "BOOT_RESUME"
const KEY_PREVIOUS: String = "BOOT_PREVIOUS"
const KEY_PREVIOUS_NONE: String = "BOOT_PREVIOUS_NONE"
const KEY_SKIP: String = "BOOT_SKIP"
const PREFIX_OUTCOME: String = "UI_OUTCOME_"
const PLACEHOLDER_OUTCOME: String = "outcome"

## §2: one line every 320 ms, each typed over 180 ms, a 900 ms hold after the
## last; the short boot stands for a second.
const LINE_MS: int = 320
const TYPE_MS: int = 180
const HOLD_MS: int = 900
const SHORT_MS: int = 1000
## Lines 01–09 carry a timestamp; 10 and 11 are the conversation.
const STAMPED_LINES: int = 9
## The stamps advance 0.000 → 0.936 — decoration, not data.
const STAMP_STEP: float = 0.117
const STAMP_DECIMALS: int = 3
const STAMP_FORMAT: String = "[%s] %s"
## The skip hint appears with the second line of the long boot.
const SKIP_FROM_LINE: int = 1
## §2: the console is a column at most this wide, in the upper third.
const COLUMN_MAX_WIDTH: float = 720.0

@onready var _ink: ColorRect = %Ink
@onready var _column: Control = %Column
@onready var _console: Label = %BootConsole
@onready var _skip: Label = %BootSkip

## Whether this launch shows the eleven lines (a first launch, or the setting).
var full: bool = false

var _lines: Array[String] = []
var _elapsed: float = 0.0
var _done: bool = false


func _ready() -> void:
	# §2: the backdrop is hidden under a plain `INK` screen.
	_ink.color = UiTokens.INK
	get_viewport().size_changed.connect(_fit)
	_fit()
	full = not ProfileManager.boot_seen or Settings.boot_always
	_lines = full_lines() if full else short_lines()
	_console.text = "\n".join(_lines)
	_skip.text = tr(KEY_SKIP)
	_skip.visible = false
	_render()


func _process(delta: float) -> void:
	step(delta)


## §2: the first key, click or tap skips, and it is never passed on to the title.
func _input(event: InputEvent) -> void:
	if _done or not _is_skip(event):
		return
	get_viewport().set_input_as_handled()
	finish()


## Advances the sequence by `seconds`; at its end the title comes.
func step(seconds: float) -> void:
	if _done:
		return
	_elapsed += seconds
	_render()
	if _elapsed >= duration():
		finish()


## How long the whole sequence stands before the title, in seconds.
func duration() -> float:
	if not full:
		return UiTokens.seconds(SHORT_MS)
	return UiTokens.seconds(LINE_MS * (_lines.size() - 1) + TYPE_MS + HOLD_MS)


func finish() -> void:
	if _done:
		return
	_done = true
	set_process(false)
	ScreenRouter.go_to_title()


## The eleven lines, the first nine with their timestamps.
func full_lines() -> Array[String]:
	var out: Array[String] = []
	for i: int in LINE_KEYS.size():
		var text: String = tr(LINE_KEYS[i])
		if i < STAMPED_LINES:
			text = STAMP_FORMAT % [stamp(float(i) * STAMP_STEP), text]
		out.append(text)
	return out


## §2, a later launch: resuming, and how the previous instance ended.
func short_lines() -> Array[String]:
	var previous: String = tr(KEY_PREVIOUS_NONE)
	if not ProfileManager.history.is_empty():
		var outcome: String = str(ProfileManager.history[0].get("outcome", ""))
		previous = tr(KEY_PREVIOUS).format(
			{PLACEHOLDER_OUTCOME: tr(PREFIX_OUTCOME + outcome.to_upper())})
	return [tr(KEY_RESUME), previous]


## Seconds with exactly three decimals in the locale's separator: `0.117`,
## `0,117`.
static func stamp(seconds: float) -> String:
	var per_second: int = roundi(UiTokens.MS_PER_SECOND)
	var millis: int = roundi(seconds * UiTokens.MS_PER_SECOND)
	@warning_ignore("integer_division")
	var whole: int = millis / per_second
	var separator: String = Format.DECIMAL_DE if Format.is_german() else Format.DECIMAL_EN
	return "%d%s%s" % [whole, separator, str(millis % per_second).pad_zeros(STAMP_DECIMALS)]


## How many characters of the console show at `_elapsed`: every line that has
## started, the newest one typed in over `TYPE_MS` (whole at once with reduced
## motion). The short boot shows both lines at once.
func _render() -> void:
	if not full:
		_console.visible_characters = -1
		return
	var line_seconds: float = UiTokens.seconds(LINE_MS)
	var type_seconds: float = UiTokens.duration(TYPE_MS)
	var shown: int = 0
	var started: int = 0
	for i: int in _lines.size():
		var start: float = float(i) * line_seconds
		if _elapsed < start:
			break
		started = i + 1
		var length: int = _lines[i].length()
		var typed: float = 1.0 if type_seconds <= 0.0 \
			else clampf((_elapsed - start) / type_seconds, 0.0, 1.0)
		# The newline before a line counts as one of its characters.
		shown += (1 if i > 0 else 0) + roundi(float(length) * typed)
	_console.visible_characters = shown
	_skip.visible = started > SKIP_FROM_LINE


func _fit() -> void:
	_column.custom_minimum_size.x = minf(COLUMN_MAX_WIDTH,
		get_viewport_rect().size.x - float(UiTokens.GUTTER) * 2.0)


static func _is_skip(event: InputEvent) -> bool:
	if event is InputEventKey:
		return (event as InputEventKey).pressed and not (event as InputEventKey).echo
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).pressed
	return false
