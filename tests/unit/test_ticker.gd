extends GutTest
## The ticker strip: the queue, its bound, the idle line, the two forms —
## scrolling and standing still (ui-foundation.md §5.5) — and what S3.5 added:
## items that are a key and arguments, the register, and the locale (ticker.md
## §4).

const TICKER_SCENE: PackedScene = preload("res://ui/hud/ticker.tscn")
## A key that exists in both languages, with a region in it.
const KEY_SEED: String = "HEADLINE_SEED_FIRST"

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
		_ticker.call("push_key", "line %d" % i)


func _headline(headline_id: String, args: Dictionary) -> SimEvent:
	var data: Dictionary = args.duplicate()
	data[SimEvent.FIELD_HEADLINE] = headline_id
	data[SimEvent.FIELD_STREAM] = HeadlineDef.STREAM_CONSEQUENCE
	return SimEvent.new(SimEvent.HEADLINE, 4, data)


func test_an_empty_ticker_says_the_world_is_quiet() -> void:
	assert_eq(str(_ticker.call("text")), tr("UI_TICKER_IDLE"))


func test_an_empty_key_never_reaches_the_strip() -> void:
	_ticker.call("push_key", "")
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


func test_a_headline_event_becomes_a_line() -> void:
	EventBus.sim_event.emit(_headline("seed_first", {"region": "usa"}))
	assert_eq(int(_ticker.call("queued")), 1)


## §4.3: everything else is the panels' business now.
func test_an_ordinary_event_leaves_the_strip_alone() -> void:
	EventBus.sim_event.emit(SimEvent.new(SimEvent.REGION_SEEDED, 4, {"region": "usa"}))
	assert_eq(int(_ticker.call("queued")), 0)


func test_with_reduced_motion_one_line_stands_still() -> void:
	Settings.reduced_motion = true
	_push(3)
	await get_tree().process_frame
	assert_eq(str(_ticker.call("text")), "line 0", "one line at a time, not a stream")
	assert_eq(int(_ticker.call("queued")), 2)


## §4.4: the item is a key and arguments, so the other language is a re-render.
func test_items_re_render_on_locale_change() -> void:
	EventBus.sim_event.emit(_headline("seed_first", {"region": "germany"}))
	await get_tree().process_frame
	var position_x: float = (_ticker.get_node("%Line") as Label).position.x
	assert_string_contains(str(_ticker.call("text")), tr("REGION_GERMANY"))

	TranslationServer.set_locale("de")
	EventBus.locale_changed.emit("de")
	assert_string_contains(str(_ticker.call("text")), "Deutschland")
	assert_eq(int(_ticker.call("queued")), 0, "nothing is dropped and nothing restarts")
	assert_eq((_ticker.get_node("%Line") as Label).position.x, position_x,
		"and the line does not jump")


func test_register_switch_changes_separator_and_idle() -> void:
	_push(2)
	await get_tree().process_frame
	_ticker.call("set_register", &"emergency")
	assert_string_contains(str(_ticker.call("text")), "///")
	assert_eq(String(_ticker.call("register")), "emergency")

	_ticker.call("clear")
	assert_eq(str(_ticker.call("text")), tr("UI_TICKER_IDLE_OPEN"))


## §4.3: a run that is already Open speaks the emergency register at once.
func test_the_phase_event_turns_the_register() -> void:
	EventBus.sim_event.emit(SimEvent.new(SimEvent.PHASE_CHANGED, 40, {"from": "emergent",
		"to": "open"}))
	assert_eq(String(_ticker.call("register")), "emergency")


## §4.5: at 400 px the longest German line has two rows and a taller strip.
func test_static_mode_wraps_to_two_rows_at_phone_width() -> void:
	TranslationServer.set_locale("de")
	Settings.reduced_motion = true
	_root.size = Vector2(400.0, 860.0)
	_ticker.set(&"compact", true)
	_ticker.call("push_key", _longest_german_headline())
	await get_tree().process_frame
	await get_tree().process_frame

	var label: Label = _ticker.get_node("%Line") as Label
	assert_eq(int(_ticker.custom_minimum_size.y), UiTokens.TICKER_STATIC_HEIGHT)
	assert_lte(label.get_line_count(), 2, "two rows, and it is not cut off")


## The German row of `strings.csv` with the most characters, which is the one
## that has to fit.
func _longest_german_headline() -> String:
	var longest: String = ""
	var length: int = 0
	for headline: HeadlineDef in Game.db.headlines:
		var text: String = tr(headline.key())
		if text.length() > length:
			length = text.length()
			longest = headline.key()
	return longest
