extends GutTest
## S6.8 — what the HUD speaks (accessibility.md §3.4, §7.2): a cue marked
## `announce` is spoken whether *Sound captions* is on or off, one without is
## not; headlines are spoken eight seconds apart, and not at all with the setting
## off. No screen reader runs here, so the live regions are forced on.

const HUD_SCENE: PackedScene = preload("res://ui/hud/hud.tscn")
const SEED: int = 1
const START_MS: int = 1000
const HEADLINE_GAP_MS: int = 8000

var _hud: Control = null
var _ticker: Node = null
var _captions: bool = false
var _headlines: bool = true
var _reduced_motion: bool = false


func before_each() -> void:
	_captions = Settings.sound_captions
	_headlines = Settings.announce_headlines
	_reduced_motion = Settings.reduced_motion
	Settings.reduced_motion = true
	Settings.sound_captions = false
	Settings.announce_headlines = true
	Game.stop_run()
	Game.debug_log = false
	Game.start_run(SEED)
	_hud = HUD_SCENE.instantiate() as Control
	add_child_autofree(_hud)
	_ticker = _hud.get_node("%Ticker")
	_hud.set(&"clock_override_ms", START_MS)
	_ticker.set(&"clock_override_ms", START_MS)
	(_hud.call(&"announce_live") as LiveRegion).force_active = true
	(_ticker.get(&"live") as LiveRegion).force_active = true
	Audio.reset_ledger()


func after_each() -> void:
	Settings.sound_captions = _captions
	Settings.announce_headlines = _headlines
	Settings.reduced_motion = _reduced_motion
	Game.stop_run()


func _announce_text() -> String:
	return (_hud.call(&"announce_live") as LiveRegion).text


func _ticker_text() -> String:
	return (_ticker.get(&"live") as LiveRegion).text


func _headline(id: String) -> void:
	EventBus.sim_event.emit(SimEvent.new(SimEvent.HEADLINE, 1, {
		SimEvent.FIELD_HEADLINE: id, SimEvent.FIELD_STREAM: "world"}))


func _speak_at(ms: int) -> void:
	_ticker.set(&"clock_override_ms", ms)
	_ticker.call(&"_speak_due")


func test_an_announced_cue_is_spoken_with_captions_off() -> void:
	Audio.cue(&"alert_depopulated")
	_hud.call(&"_process", 0.0)
	assert_false(_announce_text().is_empty())


func test_a_cue_without_announce_is_not_spoken() -> void:
	Audio.cue(&"ui_open")
	_hud.call(&"_process", 0.0)
	assert_eq(_announce_text(), "")


func test_a_headline_is_spoken_and_a_second_within_eight_seconds_waits() -> void:
	_headline("first")
	_speak_at(START_MS)
	var first: String = _ticker_text()
	assert_string_contains(first, "FIRST")
	_headline("second")
	_speak_at(START_MS + 1000)
	assert_eq(_ticker_text(), first, "inside the gap")
	_speak_at(START_MS + HEADLINE_GAP_MS)
	assert_string_contains(_ticker_text(), "SECOND")


func test_with_the_setting_off_nothing_is_spoken() -> void:
	Settings.announce_headlines = false
	_headline("first")
	_speak_at(START_MS)
	assert_eq(_ticker_text(), "")
