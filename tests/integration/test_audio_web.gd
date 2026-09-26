extends GutTest
## S7.3 — the sound in a browser (web.md §6.2, §6.3), walked on the desktop
## through `Audio`'s seams: the cue files load a few per frame once the first
## input unlocks the sound, and a hidden page is silent.

var _web_cue_loading: bool = false
var _unlocked: bool = true


func before_each() -> void:
	_web_cue_loading = Audio.web_cue_loading
	_unlocked = Audio.is_unlocked()


func after_each() -> void:
	Audio.web_cue_loading = _web_cue_loading
	Audio.set_unlocked(_unlocked)
	# Whatever the queue still holds loads on demand, as on the desktop.
	Audio.forget_streams()
	EventBus.page_shown.emit()


func _unlock_as_the_web() -> int:
	Audio.web_cue_loading = true
	Audio.set_unlocked(false)
	Audio.forget_streams()
	Audio.set_unlocked(true)
	return Audio.web_cue_loads_pending()


func test_the_unlock_queues_every_cue_file() -> void:
	var pending: int = _unlock_as_the_web()
	assert_gt(pending, Audio.WEB_CUE_LOADS_PER_FRAME, "the sheet has more cues than a frame loads")
	assert_true(pending <= Audio.sheet.cues.size())


func test_each_step_loads_two_cue_files() -> void:
	var pending: int = _unlock_as_the_web()
	Audio.step(0.0)
	assert_eq(Audio.web_cue_loads_pending(), pending - Audio.WEB_CUE_LOADS_PER_FRAME)
	Audio.step(0.0)
	assert_eq(Audio.web_cue_loads_pending(), pending - Audio.WEB_CUE_LOADS_PER_FRAME * 2)


func test_the_queue_empties_before_a_run_could_start() -> void:
	var pending: int = _unlock_as_the_web()
	var frames: int = ceili(float(pending) / float(Audio.WEB_CUE_LOADS_PER_FRAME))
	for i: int in frames:
		Audio.step(0.0)
	assert_eq(Audio.web_cue_loads_pending(), 0)


func test_the_desktop_queues_nothing() -> void:
	Audio.web_cue_loading = false
	Audio.set_unlocked(false)
	Audio.forget_streams()
	Audio.set_unlocked(true)
	assert_eq(Audio.web_cue_loads_pending(), 0)


func test_a_hidden_page_mutes_the_master_bus() -> void:
	EventBus.page_hidden.emit()
	assert_true(Audio.is_page_muted())
	assert_true(AudioServer.is_bus_mute(Audio.MASTER_INDEX))


func test_a_shown_page_restores_the_master_bus() -> void:
	var muted: bool = AudioServer.is_bus_mute(Audio.MASTER_INDEX)
	EventBus.page_hidden.emit()
	EventBus.page_shown.emit()
	assert_false(Audio.is_page_muted())
	assert_eq(AudioServer.is_bus_mute(Audio.MASTER_INDEX), muted)


## audio.md §5.8, found in S7.3: the boot takes its skip in `_input`, ahead of
## the autoloads, so the unlock listens to the window itself.
func test_the_first_input_through_the_window_unlocks_the_sound() -> void:
	Audio.set_unlocked(false)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	get_tree().root.window_input.emit(click)
	assert_true(Audio.is_unlocked())


func test_a_release_does_not_unlock_the_sound() -> void:
	Audio.set_unlocked(false)
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_A
	key.pressed = false
	get_tree().root.window_input.emit(key)
	assert_false(Audio.is_unlocked())
