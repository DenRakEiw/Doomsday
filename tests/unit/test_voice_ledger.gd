extends GutTest
## S6.5 — admission and voices (spec audio.md §5.4, §12.1). The clock is an
## argument, so no frame is waited for.

var _sheet: AudioSheet = null
var _ledger: VoiceLedger = null


func before_all() -> void:
	_sheet = AudioSheet.load_file()


func before_each() -> void:
	_ledger = VoiceLedger.new()


func _cue(id: String, bus: StringName, priority: int, cooldown_ms: int = 0,
		voices: int = 1) -> AudioCueDef:
	var cue: AudioCueDef = AudioCueDef.new()
	cue.id = StringName(id)
	cue.bus = bus
	cue.priority = priority
	cue.cooldown_ms = cooldown_ms
	cue.voices = voices
	return cue


func _voice(id: String, priority: int, started_ms: int, playing: bool = true) -> AudioVoice:
	var voice: AudioVoice = AudioVoice.new()
	voice.cue_id = StringName(id)
	voice.priority = priority
	voice.started_ms = started_ms
	voice.playing = playing
	return voice


func test_cooldown_refuses_within_window() -> void:
	var cue: AudioCueDef = _cue("a", AudioSheet.BUS_INTERFACE, 10, 100)
	assert_true(_ledger.admit(cue, 1000, _sheet))
	assert_false(_ledger.admit(cue, 1099, _sheet))


func test_cooldown_admits_after_window() -> void:
	var cue: AudioCueDef = _cue("a", AudioSheet.BUS_INTERFACE, 10, 100)
	assert_true(_ledger.admit(cue, 1000, _sheet))
	assert_true(_ledger.admit(cue, 1100, _sheet))


func test_alert_gap_refuses_lower_priority_alert() -> void:
	assert_true(_ledger.admit(_cue("big", AudioSheet.BUS_ALERTS, 90), 1000, _sheet))
	assert_false(_ledger.admit(_cue("small", AudioSheet.BUS_ALERTS, 50), 1000
		+ _sheet.alert_gap_ms - 1, _sheet))
	assert_true(_ledger.admit(_cue("small", AudioSheet.BUS_ALERTS, 50), 1000
		+ _sheet.alert_gap_ms, _sheet))


func test_alert_gap_admits_interface_cue() -> void:
	assert_true(_ledger.admit(_cue("big", AudioSheet.BUS_ALERTS, 90), 1000, _sheet))
	assert_true(_ledger.admit(_cue("click", AudioSheet.BUS_INTERFACE, 10), 1001, _sheet))


func test_high_alert_sets_gap() -> void:
	assert_true(_ledger.admit(_cue("small", AudioSheet.BUS_ALERTS, 50), 1000, _sheet))
	assert_eq(_ledger.last_gap_ms, VoiceLedger.NEVER_MS, "below the gap priority sets nothing")
	assert_true(_ledger.admit(_cue("big", AudioSheet.BUS_ALERTS, 80), 2000, _sheet))
	assert_eq(_ledger.last_gap_ms, 2000)
	assert_true(_ledger.admit(_cue("other_big", AudioSheet.BUS_ALERTS, 95), 2001, _sheet),
		"a heavy alert is never held back by the gap")


func test_ending_refuses_non_final_alert() -> void:
	_ledger.ending = true
	assert_false(_ledger.admit(_cue("alert", AudioSheet.BUS_ALERTS, 100), 1000, _sheet))


func test_ending_admits_final_and_interface() -> void:
	_ledger.ending = true
	var final_cue: AudioCueDef = _cue("end", AudioSheet.BUS_ALERTS, 100)
	final_cue.final = true
	assert_true(_ledger.admit(final_cue, 1000, _sheet))
	assert_true(_ledger.admit(_cue("click", AudioSheet.BUS_INTERFACE, 10), 1000, _sheet))


func test_reset_forgets_everything() -> void:
	var cue: AudioCueDef = _cue("a", AudioSheet.BUS_INTERFACE, 10, 1000)
	_ledger.admit(cue, 1000, _sheet)
	_ledger.ending = true
	_ledger.reset()
	assert_false(_ledger.ending)
	assert_true(_ledger.admit(cue, 1001, _sheet))


func test_voice_limit_restarts_oldest_same_cue() -> void:
	var cue: AudioCueDef = _cue("a", AudioSheet.BUS_INTERFACE, 10, 0, 2)
	var voices: Array[AudioVoice] = [_voice("a", 10, 300), _voice("a", 10, 100),
		_voice("b", 5, 50, false)]
	assert_eq(_ledger.pick_slot(cue, voices), 1, "two of two playing: the older restarts")


func test_free_slot_is_used_first() -> void:
	var cue: AudioCueDef = _cue("a", AudioSheet.BUS_INTERFACE, 10, 0, 2)
	var voices: Array[AudioVoice] = [_voice("a", 10, 100), _voice("b", 1, 50),
		_voice("c", 5, 50, false)]
	assert_eq(_ledger.pick_slot(cue, voices), 2)


func test_lowest_priority_is_stolen() -> void:
	var cue: AudioCueDef = _cue("a", AudioSheet.BUS_ALERTS, 50)
	var voices: Array[AudioVoice] = [_voice("b", 40, 100), _voice("c", 20, 300),
		_voice("d", 20, 200)]
	assert_eq(_ledger.pick_slot(cue, voices), 2, "lowest, and the older of two equals")


func test_higher_priority_is_never_stolen() -> void:
	var cue: AudioCueDef = _cue("a", AudioSheet.BUS_ALERTS, 10)
	var voices: Array[AudioVoice] = [_voice("b", 40, 100), _voice("c", 20, 300)]
	assert_eq(_ledger.pick_slot(cue, voices), -1)
