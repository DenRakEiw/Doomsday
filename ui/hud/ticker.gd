extends PanelContainer
## The strip that narrates the run (spec ui-foundation.md §5.5).
##
## Items scroll right to left at `TICKER_SPEED` and are separated by `SEPARATOR`;
## a new one joins at the right end. Under reduced motion nothing moves: the
## newest item stands still and is replaced every `TICKER_STATIC_PERIOD`, because
## a player who turned motion off still has to be able to read the run.
##
## M2 feeds it the event lines of `EventText` (§8.4). S3.5 replaces that source
## with D3.4's headlines — the strip itself stays.
##
## Scene-specific, so no `class_name`.

## §5.5: the queue holds this many lines, the oldest dropped first.
const QUEUE_MAX: int = 12
const SEPARATOR: String = "   ·   "
const KEY_IDLE: String = "UI_TICKER_IDLE"
const KEY_BOT_RUN: String = "UI_DEBUG_BOT_RUN"

const ITEM_FONT: StringName = &"font"
const ITEM_FONT_SIZE: StringName = &"font_size"

## Waiting to be shown, oldest first.
var _queue: Array[String] = []
## What the scrolling label currently spells out, oldest first.
var _shown: Array[String] = []
## Seconds the static item has been standing.
var _standing: float = 0.0
## How wide the line is. Measured rather than read off the label: the label grows
## with the strip, and assigning its size back would fight the anchors.
var _width: float = 0.0

@onready var _clip: Control = %Clip
@onready var _label: Label = %Line


func _ready() -> void:
	custom_minimum_size.y = float(UiTokens.TICKER_HEIGHT)
	EventBus.sim_event.connect(_on_sim_event)
	EventBus.run_started.connect(_on_run_started)
	EventBus.reduced_motion_changed.connect(_on_reduced_motion_changed)
	_reset()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		# The lines are already translated, so a language change starts the strip
		# over rather than mixing two languages in one sentence.
		_queue.clear()
		_reset()


func _process(delta: float) -> void:
	if UiTokens.reduced_motion():
		_advance_static(delta)
		return
	_advance_scroll(delta)


## Puts a line at the right end of the queue. Empty lines are the mapping's way
## of saying "not worth narrating" and never reach the strip.
func push_item(item: String) -> void:
	if item.is_empty():
		return
	_queue.append(item)
	while _queue.size() > QUEUE_MAX:
		_queue.pop_front()
	if UiTokens.reduced_motion():
		# Nothing is moving, so the new line goes up as soon as the one standing
		# has had its time.
		if _shown.is_empty():
			_show_next_static()


## What the strip spells out right now — the scrolling text or the standing line.
func text() -> String:
	return _label.text


## How many lines are waiting. For the tests and for S3.5's source.
func queued() -> int:
	return _queue.size()


# --------------------------------------------------------------- the two modes


## Scrolling: the label moves left, lines that have left the strip are dropped
## from its front, and everything queued joins at its end.
func _advance_scroll(delta: float) -> void:
	_take_queued()
	if _shown.is_empty():
		_show_idle()
		return
	_label.position.x -= UiTokens.TICKER_SPEED * delta
	_drop_passed()
	if _label.position.x + _width <= 0.0:
		_reset()


## Everything waiting joins the line being drawn, which is what "a new item joins
## at the right end" means once the text is one label.
func _take_queued() -> void:
	if _queue.is_empty():
		return
	if _shown.is_empty():
		_label.position.x = _clip.size.x
	_shown.append_array(_queue)
	_queue.clear()
	_apply_text()


## A line whose last pixel has passed the left edge is gone: it leaves the text
## and the label jumps right by exactly its width, so nothing visibly moves.
func _drop_passed() -> void:
	while _shown.size() > 1:
		var first: float = _measure(_shown[0] + SEPARATOR)
		if _label.position.x + first > 0.0:
			return
		_shown.pop_front()
		_label.position.x += first
		_apply_text()


## Static: one line at a time, replaced when its time is up (§5.5).
func _advance_static(delta: float) -> void:
	if _shown.is_empty():
		_show_next_static()
		return
	_standing += delta
	if _standing < UiTokens.seconds(UiTokens.TICKER_STATIC_PERIOD):
		return
	if _queue.is_empty():
		return
	_show_next_static()


func _show_next_static() -> void:
	_standing = 0.0
	_label.position.x = 0.0
	if _queue.is_empty():
		_shown.clear()
		_show_idle()
		return
	_shown = [_queue.pop_front()]
	_apply_text()


## Nothing to say. The idle line stands still at the left edge whether or not
## motion is on — it is a state, not an item.
func _show_idle() -> void:
	var idle: String = tr(KEY_IDLE)
	if _label.text == idle and _label.position.x == 0.0:
		return
	_label.position.x = 0.0
	_label.text = idle
	_width = _measure(idle)


func _reset() -> void:
	_shown.clear()
	_standing = 0.0
	_show_idle()


func _apply_text() -> void:
	_label.text = SEPARATOR.join(_shown)
	_width = _measure(_label.text)


## The width of a piece of the line in the font the strip draws in.
func _measure(line: String) -> float:
	var font: Font = _label.get_theme_font(ITEM_FONT)
	var font_size: int = _label.get_theme_font_size(ITEM_FONT_SIZE)
	if font == null:
		return 0.0
	return font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x


# ---------------------------------------------------------------- the sources


func _on_sim_event(event: SimEvent) -> void:
	push_item(EventText.for_event(event))


## §10.2: the ticker announces a bot run, which in M2 is the only way a run
## starts at all.
func _on_run_started(seed_value: int) -> void:
	_queue.clear()
	_reset()
	if Game.policy == null:
		return
	push_item(tr(KEY_BOT_RUN).format({
		"policy": Game.policy.policy_id(), "seed": seed_value}))


func _on_reduced_motion_changed(_enabled: bool) -> void:
	_reset()
