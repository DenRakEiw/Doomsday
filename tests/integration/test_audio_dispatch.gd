extends GutTest
## S6.5 — the `Audio` autoload (spec audio.md §5, §6, §12.1), headless: the
## dummy driver plays nothing, so `history` and the players' volumes are the
## test's ear. The clock is injected (`Audio.clock_override_ms`) so cooldowns
## and the duck's hold are walked, never waited on. `ProfileManager` is left
## alone (the suite's profile is its own, `pre_run.gd`).

const SEED: int = 1
## Far enough apart that no cooldown or gap of the sheet still counts.
const CLOCK_STEP_MS: int = 10000
const CLOCK_START_MS: int = 1000000
## §12.1: the bot run — seed 1, greedy, 150 days. The seed is fixed on purpose.
const BOT_POLICY: String = "greedy"
const BOT_DAYS: int = 150
## A day at 1× (`Game.TICKS_PER_SECOND`), in ms.
const DAY_MS: int = 2000

var _clock: int = CLOCK_START_MS
var _volumes: Dictionary[String, float] = {}
var _captions: bool = false
var _reduced_motion: bool = false


func before_each() -> void:
	_volumes = Settings.volumes.duplicate()
	_captions = Settings.sound_captions
	_reduced_motion = Settings.reduced_motion
	Game.stop_run()
	Game.debug_log = false
	_clock = CLOCK_START_MS
	Audio.clock_override_ms = _clock
	Audio.set_unlocked(true)
	Audio.reset_ledger()
	Audio.reset_history()


func after_each() -> void:
	Game.stop_run()
	Audio.clock_override_ms = -1
	Audio.set_unlocked(true)
	Audio.reset_ledger()
	Audio.reset_history()
	# The player's file keeps what the player chose: only what a test changed
	# is put back, and every bus is re-applied from it.
	Settings.volumes = _volumes
	Settings.set_sound_captions(_captions)
	Settings.write()
	for bus: StringName in AudioSheet.BUS_IDS:
		EventBus.volume_changed.emit(bus, Audio.volume(bus))


func _tick_clock() -> void:
	_clock += CLOCK_STEP_MS
	Audio.clock_override_ms = _clock
	Audio.reset_ledger()


## The field sets that make a trigger match: one, or one per faction for a
## template on `{faction}`.
func _fields_for(trigger: AudioTriggerDef) -> Array[Dictionary]:
	var fields: Dictionary = {}
	for field: Variant in trigger.conditions:
		var condition: Variant = trigger.conditions[field]
		if typeof(condition) == TYPE_ARRAY:
			fields[field] = (condition as Array)[0]
		elif typeof(condition) != TYPE_DICTIONARY:
			fields[field] = condition
	for field: Variant in trigger.conditions:
		var condition: Variant = trigger.conditions[field]
		if typeof(condition) != TYPE_DICTIONARY:
			continue
		var operation: Dictionary = condition
		if operation.has(AudioRules.COND_GT):
			fields[field] = float(operation[AudioRules.COND_GT]) + 1.0
		elif operation.has(AudioRules.COND_LT):
			fields[field] = float(operation[AudioRules.COND_LT]) - 1.0
		elif operation.has(AudioRules.COND_LT_FIELD):
			fields[field] = float(fields[operation[AudioRules.COND_LT_FIELD]]) - 1.0
		elif operation.has(AudioRules.COND_GT_FIELD):
			fields[field] = float(fields[operation[AudioRules.COND_GT_FIELD]]) + 1.0
	var out: Array[Dictionary] = [fields]
	if trigger.cue.contains("{faction}"):
		out.clear()
		for faction: FactionDef in Game.content().factions:
			var one: Dictionary = fields.duplicate()
			one["faction"] = faction.id
			out.append(one)
	# A template on a field with a choice of values: one set per value.
	for field: Variant in trigger.conditions:
		var condition: Variant = trigger.conditions[field]
		if typeof(condition) != TYPE_ARRAY or not trigger.cue.contains("{%s}" % field):
			continue
		out.clear()
		for value: Variant in condition:
			var one: Dictionary = fields.duplicate()
			one[field] = value
			out.append(one)
	return out


func _fire(trigger: AudioTriggerDef, fields: Dictionary) -> void:
	match trigger.on:
		AudioTriggerDef.ON_SIM:
			EventBus.sim_event.emit(SimEvent.new(trigger.type, 0, fields))
		AudioTriggerDef.ON_BUS:
			if trigger.signal_name == AudioTriggerDef.SIGNAL_SPEED_CHANGED:
				EventBus.speed_changed.emit(int(fields["speed"]))
			else:
				EventBus.region_selected.emit(int(fields["index"]))
		AudioTriggerDef.ON_ROUTER:
			var screen: int = ScreenRouter.Screen.keys().find(str(fields["screen"]).to_upper())
			ScreenRouter.screen_changed.emit(screen)
		AudioTriggerDef.ON_COMMAND_REJECTED:
			EventBus.command_applied.emit(ChooseOriginCommand.new("nowhere"),
				CommandResult.rejected("no_region"))
		AudioTriggerDef.ON_BUTTON:
			var button: Button = Button.new()
			add_child_autofree(button)
			button.emit_signal("pressed")
		AudioTriggerDef.ON_CALL:
			Audio.cue(StringName(trigger.cue))


## §12.1: every cue of the sheet, each from the smallest source that matches it.
func test_every_cue_fires() -> void:
	for trigger: AudioTriggerDef in Audio.sheet.triggers:
		for fields: Dictionary in _fields_for(trigger):
			_tick_clock()
			_fire(trigger, fields)
	var missing: Array[String] = []
	for id: StringName in Audio.sheet.cues:
		if not Audio.history.has(id):
			missing.append(String(id))
	assert_eq(missing, [] as Array[String], "every cue was heard")
	assert_eq(Audio.sheet.cues.size(), 56)


## §12.1: a real run through `Game`. Seed 1 and the greedy bot, fixed.
func test_a_bot_run_is_heard() -> void:
	Game.start_run(SEED, BOT_POLICY)
	for _day: int in BOT_DAYS:
		# The clock moves as it would at 1×, so cooldowns and gaps behave.
		_clock += DAY_MS
		Audio.clock_override_ms = _clock
		Game.advance(1)
	for id: StringName in [&"ui_origin", &"ui_purchase", &"map_seed"]:
		assert_true(Audio.history.has(id), "%s was heard" % id)
	for id: StringName in Audio.history:
		assert_not_null(Audio.sheet.cue(id), "%s is a cue of the sheet" % id)


func test_button_with_empty_cue_meta_is_silent() -> void:
	var button: Button = Button.new()
	button.set_meta(Audio.META_AUDIO_CUE, &"")
	add_child_autofree(button)
	button.emit_signal("pressed")
	assert_eq(Audio.history, [] as Array[StringName])


func test_button_with_its_own_cue_plays_it() -> void:
	var button: Button = Button.new()
	button.set_meta(Audio.META_AUDIO_CUE, &"ui_answer")
	add_child_autofree(button)
	button.emit_signal("pressed")
	assert_eq(Audio.history, [&"ui_answer"] as Array[StringName])


func test_a_plain_button_clicks() -> void:
	var button: Button = Button.new()
	add_child_autofree(button)
	button.emit_signal("pressed")
	assert_eq(Audio.history, [&"ui_click"] as Array[StringName])


## §5.5: a duck holds for its cue's file length (S6.6 ships the files), or
## `MISSING_LENGTH_MS` while the file is missing.
func _hold_ms(cue_id: StringName) -> int:
	var path: String = AudioSheet.ASSET_ROOT + Audio.sheet.cue(cue_id).file
	if not ResourceLoader.exists(path):
		return Audio.MISSING_LENGTH_MS
	var stream: AudioStream = load(path) as AudioStream
	return roundi(stream.get_length() * UiTokens.MS_PER_SECOND)


func test_duck_lowers_loop_players_and_releases() -> void:
	Game.start_run(SEED)
	Audio.step(1.0)
	var before: float = Audio.layer_player(0).volume_db
	assert_true(Audio.cue(&"alert_discovered"))
	Audio.step(0.1)
	assert_almost_eq(Audio.duck_db(), Audio.sheet.duck_db, 1e-4)
	assert_almost_eq(Audio.layer_player(0).volume_db, before + Audio.sheet.duck_db, 1e-3)
	assert_lt(Audio.stem_player(0).volume_db, 0.0)
	_clock += _hold_ms(&"alert_discovered") + 1
	Audio.clock_override_ms = _clock
	Audio.step(1.0)
	assert_almost_eq(Audio.duck_db(), 0.0, 1e-4, "released after the hold")
	assert_almost_eq(Audio.layer_player(0).volume_db, before, 1e-3)


func test_hold_dip_on_pause() -> void:
	Game.start_run(SEED)
	Game.apply(ChooseOriginCommand.new(Game.db.regions[1].id))
	Game.set_speed(1)
	Audio.step(1.0)
	assert_almost_eq(Audio.hold_db(), 0.0, 1e-4, "the clock runs")
	var running: float = Audio.layer_player(0).volume_db
	var stem: float = Audio.stem_player(0).volume_db
	Game.set_speed(0)
	Audio.step(1.0)
	assert_almost_eq(Audio.hold_db(), Audio.sheet.hold_ambience_db, 1e-4)
	assert_almost_eq(Audio.layer_player(0).volume_db, running + Audio.sheet.hold_ambience_db,
		1e-3)
	assert_almost_eq(Audio.stem_player(0).volume_db, stem, 1e-3, "music is untouched")


func test_run_started_sets_layers_from_phase_at_once() -> void:
	Game.start_run(SEED)
	Game.sim.world.phase = World.Phase.EMERGENT
	EventBus.run_started.emit(SEED)
	for i: int in World.PHASE_IDS.size():
		assert_eq(Audio.layer_gain(i), 1.0 if i < 3 else 0.0, "layer %d, no fade" % i)
	assert_eq(Audio.music_gain(), 1.0)


func test_phase_change_fades_in_one_layer() -> void:
	Game.start_run(SEED)
	assert_eq(Audio.layer_gain(1), 0.0)
	EventBus.sim_event.emit(SimEvent.new(SimEvent.PHASE_CHANGED, 3,
		{"from": "boxed", "to": "covert"}))
	assert_eq(Audio.layer_target(1), 1.0)
	assert_eq(Audio.layer_target(2), 0.0, "only the phase's own layer")
	var half: float = float(Audio.sheet.layer_fade_in_ms) / UiTokens.MS_PER_SECOND / 2.0
	Audio.step(half)
	assert_almost_eq(Audio.layer_gain(1), 0.5, 1e-3)
	Audio.step(half)
	assert_almost_eq(Audio.layer_gain(1), 1.0, 1e-3)


func test_outcome_fades_loops_and_sets_ending() -> void:
	Game.start_run(SEED)
	EventBus.sim_event.emit(SimEvent.new(SimEvent.OUTCOME_REACHED, 9, {"outcome": "win_merge"}))
	assert_true(Audio.history.has(&"end_win"))
	assert_true(Audio.is_ending())
	assert_eq(Audio.layer_target(0), 0.0)
	assert_eq(Audio.music_target(), 0.0)
	Audio.step(float(Audio.sheet.end_fade_ms) / UiTokens.MS_PER_SECOND)
	assert_eq(Audio.layer_gain(0), 0.0)
	assert_eq(Audio.music_gain(), 0.0)
	_tick_clock()
	Audio.reset_ledger()
	EventBus.sim_event.emit(SimEvent.new(SimEvent.OUTCOME_REACHED, 9, {"outcome": "win_merge"}))
	_clock += CLOCK_STEP_MS
	Audio.clock_override_ms = _clock
	EventBus.sim_event.emit(SimEvent.new(SimEvent.HARM_BURST, 9, {}))
	assert_false(Audio.history.has(&"alert_harm"), "nothing but the ending after it")
	EventBus.run_started.emit(SEED)
	assert_false(Audio.is_ending(), "a new run clears it")


func test_volume_zero_mutes_bus() -> void:
	Settings.set_volume("alerts", 0.0)
	assert_true(AudioServer.is_bus_mute(Audio.bus_index(&"alerts")))
	Settings.set_volume("alerts", 0.5)
	assert_false(AudioServer.is_bus_mute(Audio.bus_index(&"alerts")))
	assert_almost_eq(AudioServer.get_bus_volume_db(Audio.bus_index(&"alerts")),
		linear_to_db(0.5), 1e-3)


func test_the_buses_come_from_the_sheet() -> void:
	for def: AudioBusDef in Audio.sheet.buses:
		var index: int = Audio.bus_index(def.id)
		assert_gte(index, 0, String(def.id))
		if def.id != AudioSheet.BUS_MASTER:
			assert_eq(AudioServer.get_bus_send(index), &"Master")


func test_volume_setting_persists() -> void:
	var before: float = Audio.volume(&"music")
	Audio.cycle_volume(&"music")
	var after: float = Audio.volume(&"music")
	assert_eq(after, AudioRules.next_volume(before))
	var json: JSON = JSON.new()
	assert_eq(json.parse(FileAccess.get_file_as_string(Settings.path)), OK)
	var read: Dictionary = Settings.values_from(json.data, Settings.LOCALE_EN)
	assert_almost_eq(float((read[Settings.KEY_VOLUMES] as Dictionary)["music"]), after, 1e-6)


func test_caption_pushed_when_admitted_even_if_muted() -> void:
	Settings.set_volume("master", 0.0)
	watch_signals(EventBus)
	assert_true(Audio.cue(&"tf_level"))
	assert_signal_emitted_with_parameters(EventBus, "caption_pushed", ["UI_CAPTION_TF_LEVEL", {}])


func test_no_caption_for_interface_cue() -> void:
	watch_signals(EventBus)
	assert_true(Audio.cue(&"ui_purchase"))
	assert_signal_not_emitted(EventBus, "caption_pushed")


func test_web_lock_records_but_does_not_play() -> void:
	Game.start_run(SEED)
	Audio.set_unlocked(false)
	watch_signals(EventBus)
	assert_true(Audio.cue(&"alert_discovered"))
	assert_true(Audio.history.has(&"alert_discovered"), "recorded")
	assert_signal_emitted(EventBus, "caption_pushed", "captioned")
	Audio.step(0.1)
	assert_eq(Audio.duck_db(), 0.0, "never played, so nothing ducked")
