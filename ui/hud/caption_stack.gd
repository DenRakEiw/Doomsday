extends VBoxContainer
## The sound captions at the bottom of the map's left column (spec audio.md §8):
## every admitted cue with a caption, as a bracketed line, while *Sound
## captions* is on. Three lines at most; a repeat counts up instead of stacking.
##
## The clock is injectable (`clock_override_ms`), so a test can walk a line's
## standing time without waiting on it.
##
## Scene-specific, so no `class_name`.

## §8.2: how many lines stand at once, how long, and how wide one may get.
const CAPTION_MAX: int = 3
const CAPTION_MS: int = 3000
const CAPTION_PER_CHAR_MS: int = 40
const CAPTION_MAX_WIDTH: float = 280.0
## A repeat: the line's text and how often it was heard.
const REPEAT_FORMAT: String = "%s ×%d"
const VARIATION_LINE: StringName = &"LabelCaption"

const META_KEY: StringName = &"caption_key"
const META_ARGS: StringName = &"caption_args"
const META_TEXT: StringName = &"caption_text"
const META_COUNT: StringName = &"caption_count"
const META_UNTIL: StringName = &"caption_until"

## A test seam: the clock in ms, or −1 for the real one.
var clock_override_ms: int = -1

## The lines standing, oldest first. A leaving line is no longer here.
var _lines: Array[Label] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = Settings.sound_captions
	EventBus.caption_pushed.connect(_on_caption_pushed)
	EventBus.sound_captions_changed.connect(_on_sound_captions_changed)


func _process(_delta: float) -> void:
	step()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		for line: Label in _lines:
			line.set_meta(META_TEXT, CaptionText.render(str(line.get_meta(META_KEY)),
				line.get_meta(META_ARGS)))
			_render(line)


## §8.2: a new line at the bottom, or a repeat of one that stands.
func push(key: String, args: Dictionary) -> void:
	if not Settings.sound_captions:
		return
	var text: String = CaptionText.render(key, args)
	for line: Label in _lines:
		if str(line.get_meta(META_TEXT)) == text:
			line.set_meta(META_COUNT, int(line.get_meta(META_COUNT)) + 1)
			_render(line)
			return
	var label: Label = Label.new()
	label.theme_type_variation = VARIATION_LINE
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.set_meta(META_KEY, key)
	label.set_meta(META_ARGS, args.duplicate())
	label.set_meta(META_TEXT, text)
	label.set_meta(META_COUNT, 1)
	add_child(label)
	_lines.append(label)
	_render(label)
	while _lines.size() > CAPTION_MAX:
		var oldest: Label = _lines.pop_front()
		oldest.queue_free()
		remove_child(oldest)


## Sends every line whose time is up on its way out.
func step() -> void:
	var now: int = _now()
	for line: Label in _lines.duplicate():
		if now >= int(line.get_meta(META_UNTIL)):
			_leave(line)


## The texts standing, oldest first.
func texts() -> Array[String]:
	var out: Array[String] = []
	for line: Label in _lines:
		out.append(line.text)
	return out


func clear() -> void:
	for line: Label in _lines:
		remove_child(line)
		line.queue_free()
	_lines.clear()


## Writes a line's text (with its count) and restarts its clock.
func _render(line: Label) -> void:
	var text: String = str(line.get_meta(META_TEXT))
	var count: int = int(line.get_meta(META_COUNT))
	line.text = text if count <= 1 else REPEAT_FORMAT % [text, count]
	var stand_ms: int = CAPTION_MS + CAPTION_PER_CHAR_MS * line.text.length()
	line.set_meta(META_UNTIL, _now() + roundi(UiTokens.seconds(stand_ms) * UiTokens.MS_PER_SECOND))
	_fit(line)


## As wide as the text, at most `CAPTION_MAX_WIDTH`; beyond it the line wraps.
func _fit(line: Label) -> void:
	var font: Font = line.get_theme_font(&"font")
	var font_size: int = line.get_theme_font_size(&"font_size")
	var natural: float = font.get_string_size(line.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		font_size).x if font != null else CAPTION_MAX_WIDTH
	line.custom_minimum_size.x = minf(ceilf(natural), CAPTION_MAX_WIDTH)


## §8.2: out over the quick fade (a cut with reduced motion), then gone.
func _leave(line: Label) -> void:
	_lines.erase(line)
	var seconds: float = UiTokens.duration(UiTokens.MOTION_QUICK)
	if seconds <= 0.0 or not is_inside_tree():
		remove_child(line)
		line.queue_free()
		return
	var fade: Tween = line.create_tween()
	fade.tween_property(line, "modulate:a", 0.0, seconds)
	fade.tween_callback(line.queue_free)


func _now() -> int:
	return clock_override_ms if clock_override_ms >= 0 else Time.get_ticks_msec()


func _on_caption_pushed(key: String, args: Dictionary) -> void:
	push(key, args)


func _on_sound_captions_changed(enabled: bool) -> void:
	visible = enabled
	if not enabled:
		clear()
