extends GutTest
## The ticker strip of spec ui-foundation.md §5.5: the queue, its bound, the
## idle line, and the two forms — scrolling and standing still.

const TICKER_SCENE: PackedScene = preload("res://ui/hud/ticker.tscn")

var _root: Control = null
var _ticker: PanelContainer = null
var _reduced_motion: bool = false
var _locale: String = ""


func before_each() -> void:
	_reduced_motion = Settings.reduced_motion
	_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	Settings.reduced_motion = false
	_root = Control.new()
	_root.theme = ThemeBuilder.build(ThemeBuilder.VARIANT_COLD)
	_root.size = Vector2(1920.0, 1080.0)
	add_child_autofree(_root)
	_ticker = TICKER_SCENE.instantiate()
	_root.add_child(_ticker)


func after_each() -> void:
	Settings.reduced_motion = _reduced_motion
	TranslationServer.set_locale(_locale)


func _push(count: int) -> void:
	for i: int in count:
		_ticker.call("push_item", "line %d" % i)


func test_an_empty_ticker_says_the_world_is_quiet() -> void:
	assert_eq(str(_ticker.call("text")), tr("UI_TICKER_IDLE"))


func test_an_empty_line_never_reaches_the_strip() -> void:
	_ticker.call("push_item", "")
	assert_eq(int(_ticker.call("queued")), 0, "silence is not an item")


func test_the_queue_drops_the_oldest_beyond_its_bound() -> void:
	_push(20)
	assert_eq(int(_ticker.call("queued")), 12, "§5.5: at most twelve wait")


func test_a_queued_line_reaches_the_strip_on_the_next_frame() -> void:
	_push(2)
	await get_tree().process_frame
	var shown: String = str(_ticker.call("text"))
	assert_string_contains(shown, "line 0")
	assert_string_contains(shown, "line 1")
	assert_string_contains(shown, "·", "items are separated, not concatenated")


func test_a_sim_event_becomes_a_line() -> void:
	EventBus.sim_event.emit(SimEvent.new(SimEvent.REGION_SEEDED, 4, {"region": "usa"}))
	assert_eq(int(_ticker.call("queued")), 1)


func test_an_event_nobody_narrates_leaves_the_strip_alone() -> void:
	EventBus.sim_event.emit(SimEvent.new("not_an_event", 4, {}))
	assert_eq(int(_ticker.call("queued")), 0)


func test_with_reduced_motion_one_line_stands_still() -> void:
	Settings.reduced_motion = true
	_push(3)
	await get_tree().process_frame
	assert_eq(str(_ticker.call("text")), "line 0", "one line at a time, not a stream")
	assert_eq(int(_ticker.call("queued")), 2)
