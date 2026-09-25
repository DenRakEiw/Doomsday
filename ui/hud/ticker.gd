extends PanelContainer
## The strip that narrates the run (specs ui-foundation.md §5.5, ticker.md §4).
##
## It holds `TickerItem`s — a key and raw arguments — and renders them when it
## draws them, so a language change re-renders the line that is already moving
## instead of starting the run over. Its only source is the `headline` event of
## D3.4's headline system; the panels and the map listen to the raw events
## themselves.
##
## Two registers (CONTENT.md §10.3): institutional until the world knows, then
## emergency, which is the separator and the idle line, not the colour — the
## palette is the theme's.
##
## Scene-specific, so no `class_name`.

## §5.5: the queue holds this many lines, the oldest dropped first.
const QUEUE_MAX: int = 12
const SEPARATOR_INSTITUTIONAL: String = "   ·   "
const SEPARATOR_EMERGENCY: String = "   ///   "
const KEY_IDLE: String = "UI_TICKER_IDLE"
const KEY_IDLE_EMERGENCY: String = "UI_TICKER_IDLE_OPEN"
const KEY_BOT_RUN: String = "UI_DEBUG_BOT_RUN"
const KEY_A11Y_NAME: String = "UI_A11Y_TICKER"

const REGISTER_INSTITUTIONAL: StringName = &"institutional"
const REGISTER_EMERGENCY: StringName = &"emergency"

const VARIATION_LINE: StringName = &"Ticker"
const VARIATION_LINE_COMPACT: StringName = &"LabelCaption"
const ITEM_FONT: StringName = &"font"
const ITEM_FONT_SIZE: StringName = &"font_size"
## accessibility.md §3.4: at most one headline spoken in this many ms.
const TICKER_LIVE_GAP_MS: int = 8000

## Set by the HUD when the layout switches (§5.7): a slower line on a phone, and
## the caption face when one has to stand in two rows.
var compact: bool = false:
	set(value):
		if value == compact:
			return
		compact = value
		if is_node_ready():
			_apply_mode()

## Waiting to be shown, oldest first.
var _queue: Array[TickerItem] = []
## What the label currently spells out, oldest first.
var _shown: Array[TickerItem] = []
var _register: StringName = REGISTER_INSTITUTIONAL
## Seconds the static item has been standing.
var _standing: float = 0.0
## How wide the line is. Measured rather than read off the label: the label grows
## with the strip, and assigning its size back would fight the anchors.
var _width: float = 0.0
## The frame a re-render already happened in — the notification and the bus
## signal both arrive on a locale change, and once is enough.
var _rendered_frame: int = -1

## accessibility.md §3.4: headlines are spoken here (the HUD sets it).
var live: LiveRegion = null
## A test sets the clock the pacing reads; below zero, the real one.
var clock_override_ms: int = -1
var _live_queue: LiveQueue = LiveQueue.new(TICKER_LIVE_GAP_MS)

@onready var _clip: Control = %Clip
@onready var _label: Label = %Line


func _ready() -> void:
	EventBus.sim_event.connect(_on_sim_event)
	EventBus.run_started.connect(_on_run_started)
	EventBus.reduced_motion_changed.connect(_on_reduced_motion_changed)
	EventBus.locale_changed.connect(_on_locale_changed)
	_clip.resized.connect(_on_clip_resized)
	accessibility_name = tr(KEY_A11Y_NAME)
	_apply_mode()
	_reset()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		# accessibility.md §3.3.
		accessibility_name = tr(KEY_A11Y_NAME)
		_re_render()


func _process(delta: float) -> void:
	_speak_due()
	if UiTokens.reduced_motion():
		_advance_static(delta)
		return
	_advance_scroll(delta)


# ------------------------------------------------------------------- the queue


## Puts an item at the right end of the queue.
func push(item: TickerItem) -> void:
	if item == null or item.key.is_empty():
		return
	_queue.append(item)
	while _queue.size() > QUEUE_MAX:
		_queue.pop_front()
	# Nothing is moving, so a new line goes up as soon as the strip is free.
	if UiTokens.reduced_motion() and _shown.is_empty():
		_show_next_static()


## The strip's own lines — the idle line and the bot banner — pushed the same way
## a headline is, so that they re-render on a locale change too.
func push_key(key: String, args: Dictionary = {}) -> void:
	push(TickerItem.make(key, args))


func clear() -> void:
	_queue.clear()
	_reset()


## What the strip spells out right now — the scrolling text or the standing line.
func text() -> String:
	return _label.text


## How many lines are waiting.
func queued() -> int:
	return _queue.size()


# ---------------------------------------------------------------- the register


## §4.3: the separator and the idle line change, nothing else. Already-shown text
## is re-joined at once and keeps its position.
func set_register(value: StringName) -> void:
	if value == _register:
		return
	_register = value
	if not is_node_ready():
		return
	if _shown.is_empty():
		_show_idle()
		return
	_apply_text()


func register() -> StringName:
	return _register


func separator() -> String:
	return SEPARATOR_EMERGENCY if _register == REGISTER_EMERGENCY \
		else SEPARATOR_INSTITUTIONAL


func _idle_key() -> String:
	return KEY_IDLE_EMERGENCY if _register == REGISTER_EMERGENCY else KEY_IDLE


# --------------------------------------------------------------- the two modes


## Scrolling: the label moves left, lines that have left the strip are dropped
## from its front, and everything queued joins at its end.
func _advance_scroll(delta: float) -> void:
	_take_queued()
	if _shown.is_empty():
		_show_idle()
		return
	_label.position.x -= _speed() * delta
	_drop_passed()
	if _label.position.x + _width <= 0.0:
		_reset()


func _speed() -> float:
	return UiTokens.TICKER_SPEED_COMPACT if compact else UiTokens.TICKER_SPEED


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
		var first: float = _measure(_shown[0].render() + separator())
		if _label.position.x + first > 0.0:
			return
		_shown.pop_front()
		_label.position.x += first
		_apply_text()


## Static: one line at a time, standing long enough to be read (§4.5).
func _advance_static(delta: float) -> void:
	if _shown.is_empty():
		_show_next_static()
		return
	# accessibility.md §9 item 2: the standing line holds while the game stands.
	if not _clock_holds():
		_standing += delta
	if _standing < _standing_time():
		return
	if _queue.is_empty():
		return
	_show_next_static()


## Long lines stand longer: the period plus a while per character.
func _standing_time() -> float:
	var per_char: int = UiTokens.TICKER_STATIC_PER_CHAR * _label.text.length()
	return UiTokens.seconds(UiTokens.TICKER_STATIC_PERIOD + per_char)


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
	var idle: String = tr(_idle_key())
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
	var lines: PackedStringArray = []
	for item: TickerItem in _shown:
		lines.append(item.render())
	_label.text = separator().join(lines)
	_width = _measure(_label.text)


## §4.4: everything shown and queued is rendered again, in place. Nothing is
## dropped and the line does not jump — only the words change.
func _re_render() -> void:
	if Engine.get_process_frames() == _rendered_frame:
		return
	_rendered_frame = Engine.get_process_frames()
	if _shown.is_empty():
		_show_idle()
		return
	var position_x: float = _label.position.x
	_apply_text()
	_label.position.x = position_x


## The width of a piece of the line in the font the strip draws in.
func _measure(line: String) -> float:
	var font: Font = _label.get_theme_font(ITEM_FONT)
	var font_size: int = _label.get_theme_font_size(ITEM_FONT_SIZE)
	if font == null:
		return 0.0
	return font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x


# ------------------------------------------------------------------- the shape


## §4.5: standing still means two rows and a taller strip; moving means one row
## of 40. The face shrinks on a phone, where 51 characters a row is the most a
## German line can hope for.
func _apply_mode() -> void:
	var still: bool = UiTokens.reduced_motion()
	custom_minimum_size.y = float(UiTokens.TICKER_STATIC_HEIGHT if still \
		else UiTokens.TICKER_HEIGHT)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if still else TextServer.AUTOWRAP_OFF
	_label.theme_type_variation = VARIATION_LINE_COMPACT if still and compact \
		else VARIATION_LINE
	_fit_label()


## A wrapping label needs a width; a scrolling one must not have one, or the text
## would wrap the moment it is longer than the strip.
func _fit_label() -> void:
	if not UiTokens.reduced_motion():
		return
	_label.position.x = 0.0
	# The offset, not `size`: the label grows downwards from a bottom anchor, and
	# writing its size back would fight the anchor (and warn about it).
	_label.offset_right = _clip.size.x


func _on_clip_resized() -> void:
	_fit_label()


# ---------------------------------------------------------------- the sources


## §4.3: the register turns once, when the world stops pretending. `EventBus`
## has no `phase_changed` of its own — the phase is in the outbox like
## everything else.
func _on_sim_event(event: SimEvent) -> void:
	var phase_to: String = str(event.data.get("to", ""))
	if event.type == SimEvent.PHASE_CHANGED and phase_to == World.PHASE_IDS[World.Phase.OPEN]:
		set_register(REGISTER_EMERGENCY)
	var item: TickerItem = HeadlineText.item_for(event)
	push(item)
	# §3.4: a headline is spoken when it is queued — never the idle line or the
	# bot banner, and only while the setting says so.
	if item != null and not item.key.is_empty() and Settings.announce_headlines:
		_live_queue.push(item.render(), _now())


func _speak_due() -> void:
	var line: String = _live_queue.pop_due(_now())
	if not line.is_empty() and live != null:
		live.say(line)


func _now() -> int:
	return clock_override_ms if clock_override_ms >= 0 else Time.get_ticks_msec()


func _clock_holds() -> bool:
	return Game.sim != null and (Game.speed == 0 or Game.is_held())


## §10.2: the ticker announces a bot run, which is the only way a run starts
## without a player.
func _on_run_started(seed_value: int) -> void:
	clear()
	_register_from_state()
	if Game.policy == null:
		return
	push_key(KEY_BOT_RUN, {"policy": Game.policy.policy_id(), "seed": seed_value})


## A run loaded in Open speaks the emergency register from its first frame.
func _register_from_state() -> void:
	var open: bool = Game.sim != null and Game.sim.world.phase == World.Phase.OPEN
	set_register(REGISTER_EMERGENCY if open else REGISTER_INSTITUTIONAL)


func _on_reduced_motion_changed(_enabled: bool) -> void:
	_apply_mode()
	_reset()


func _on_locale_changed(_locale: String) -> void:
	_re_render()
