extends GutTest
## S6.5 — the caption stack (spec audio.md §8, §12.1): hidden while the setting
## is off, three lines at most, repeats counted, lines leave after their time,
## and a locale change re-renders them in place. The stack's clock is injected.

const STACK: PackedScene = preload("res://ui/hud/caption_stack.tscn")
const StackScript: GDScript = preload("res://ui/hud/caption_stack.gd")
const KEY_TF: String = "UI_CAPTION_TF_LEVEL"
const CLOCK_START_MS: int = 1000000

var _stack: VBoxContainer = null
var _captions: bool = false
var _reduced_motion: bool = false
var _locale: String = ""


func before_each() -> void:
	_captions = Settings.sound_captions
	_reduced_motion = Settings.reduced_motion
	_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	Settings.set_reduced_motion(true)
	Settings.set_sound_captions(true)
	_stack = STACK.instantiate()
	add_child_autofree(_stack)
	_stack.set(&"clock_override_ms", CLOCK_START_MS)


func after_each() -> void:
	Settings.set_sound_captions(_captions)
	Settings.set_reduced_motion(_reduced_motion)
	TranslationServer.set_locale(_locale)


func _texts() -> Array[String]:
	var out: Array[String] = []
	out.assign(_stack.call(&"texts"))
	return out


func test_hidden_while_the_setting_is_off() -> void:
	Settings.set_sound_captions(false)
	assert_false(_stack.visible)
	EventBus.caption_pushed.emit(KEY_TF, {})
	assert_eq(_texts(), [] as Array[String], "nothing gathers while it is off")
	Settings.set_sound_captions(true)
	assert_true(_stack.visible)


func test_a_pushed_caption_shows() -> void:
	EventBus.caption_pushed.emit("UI_CAPTION_WIPED", {"region": "germany"})
	assert_eq(_texts(), ["[%s wiped]" % tr("REGION_GERMANY")] as Array[String])


func test_three_lines_at_most_oldest_dropped() -> void:
	for key: String in ["UI_CAPTION_ANOMALY", "UI_CAPTION_OPENING", "UI_CAPTION_CHAIN",
			"UI_CAPTION_HARM"]:
		EventBus.caption_pushed.emit(key, {})
	assert_eq(_texts(), [tr("UI_CAPTION_OPENING"), tr("UI_CAPTION_CHAIN"),
		tr("UI_CAPTION_HARM")] as Array[String])


func test_a_repeat_counts_up_and_restarts() -> void:
	EventBus.caption_pushed.emit(KEY_TF, {})
	_stack.set(&"clock_override_ms", CLOCK_START_MS + 2000)
	EventBus.caption_pushed.emit(KEY_TF, {})
	assert_eq(_texts(), [tr(KEY_TF) + " ×2"] as Array[String])
	EventBus.caption_pushed.emit(KEY_TF, {})
	assert_eq(_texts(), [tr(KEY_TF) + " ×3"] as Array[String])
	# Restarted at +2000: still standing where the first push would have gone.
	_stack.set(&"clock_override_ms", CLOCK_START_MS + 5000)
	_stack.call(&"step")
	assert_eq(_texts().size(), 1)


func test_a_line_leaves_after_its_time() -> void:
	EventBus.caption_pushed.emit(KEY_TF, {})
	var stand: int = StackScript.CAPTION_MS + StackScript.CAPTION_PER_CHAR_MS * tr(KEY_TF).length()
	_stack.set(&"clock_override_ms", CLOCK_START_MS + stand - 1)
	_stack.call(&"step")
	assert_eq(_texts().size(), 1, "still standing")
	_stack.set(&"clock_override_ms", CLOCK_START_MS + stand)
	_stack.call(&"step")
	assert_eq(_texts(), [] as Array[String])


func test_locale_change_re_renders_in_place() -> void:
	EventBus.caption_pushed.emit("UI_CAPTION_PHASE", {"from": "covert", "to": "emergent"})
	TranslationServer.set_locale("de")
	_stack.propagate_notification(NOTIFICATION_TRANSLATION_CHANGED)
	assert_eq(_texts(), ["[Phasenwechsel: Enttarnt]"] as Array[String])


func test_turning_the_setting_off_clears_the_stack() -> void:
	EventBus.caption_pushed.emit(KEY_TF, {})
	Settings.set_sound_captions(false)
	assert_eq(_texts(), [] as Array[String])


func test_the_hud_carries_the_stack_in_its_left_column() -> void:
	var hud: Control = (load("res://ui/hud/hud.tscn") as PackedScene).instantiate()
	add_child_autofree(hud)
	var stack: Node = hud.get_node("%CaptionStack")
	assert_not_null(stack)
	assert_eq(stack.get_parent().name, &"LeftColumn")
	assert_eq((stack as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE)
