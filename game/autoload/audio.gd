extends Node
## The sound of the game (spec audio.md §3–§6): the buses built from
## `data/audio.json`, the cue players, dispatch from `EventBus`, the router and
## every button, admission and voices, ducking, the hold dip, the ambience per
## phase and screen, the adaptive music, the web's first-input unlock.
##
## Presentation only: it reads the run, never touches it, and draws its pitch
## jitter from a generator of its own. The rules are `AudioRules` and
## `VoiceLedger`; this node listens, loads streams and moves volumes. A cue whose
## file is missing is admitted, recorded and captioned as if it played — its
## player simply has no stream.
##
## An autoload (registered after `ProfileManager`, before `ScreenFx`), so no
## `class_name`.

## §5: the admitted cues a test can read.
const HISTORY_MAX: int = 512
const FEATURE_WEB: String = "web"
const FEATURE_MOBILE: String = "mobile"
## The engine's name for bus 0, which the sheet calls `master`.
const ENGINE_MASTER: String = "Master"
const MASTER_INDEX: int = 0
## §5.2: a button's own cue; `&""` is silence.
const META_AUDIO_CUE: StringName = &"audio_cue"
## Set on a button once its `pressed` is connected, so a re-added node is not
## connected twice.
const META_CONNECTED: StringName = &"audio_connected"
## §5.5: how long a duck holds for a cue whose file is missing.
const MISSING_LENGTH_MS: int = 1000
## §3.3: what a volume button plays after the change; music and ambience are
## heard already.
const PREVIEW_CUES: Dictionary[StringName, StringName] = {
	&"master": &"ui_click",
	&"interface": &"ui_click",
	&"alerts": &"alert_threshold",
}
## §5.1: the fields each source matches on.
const FIELD_REASON: String = "reason"
const FIELD_SPEED: String = "speed"
## §5.1 (D6.8): true when the speed change is a hold starting or ending.
const FIELD_HOLD: String = "hold"
const FIELD_INDEX: String = "index"
const FIELD_SCREEN: String = "screen"
const FIELD_TO: String = "to"

## §5: admitted cue ids in order, capped at `HISTORY_MAX` — the tests' ear.
var history: Array[StringName] = []
## A test seam (§12.1): the clock in ms, or −1 for the real one.
var clock_override_ms: int = -1
var sheet: AudioSheet = null

var _valid: bool = false
var _ledger: VoiceLedger = VoiceLedger.new()
## Pitch jitter only; seeded from the clock, never the run's generator.
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Pool bus → its players and what each is playing (typed arrays inside).
var _pool_players: Dictionary[StringName, Array] = {}
var _pool_voices: Dictionary[StringName, Array] = {}
var _layer_players: Array[AudioStreamPlayer] = []
var _stem_players: Array[AudioStreamPlayer] = []
## Path → stream; null for a file that is not there (warned once).
var _streams: Dictionary[String, AudioStream] = {}
var _warned: Dictionary[String, bool] = {}
## S6.11: the cue files asked of the loader's threads at start. A cue's first
## play loaded its file on the spot, which held a late-game tick up to 12 ms.
var _requested: Dictionary[String, bool] = {}
var _unlocked: bool = true

## §6: every moving value — where it is, where it goes, how fast (per second).
var _layer_gain: Array[float] = []
var _layer_target: Array[float] = []
var _layer_rate: Array[float] = []
var _music_gain: float = 0.0
var _music_target: float = 0.0
var _music_rate: float = 0.0
var _music_on: bool = false
var _tension: float = 0.0
var _tension_target: float = 0.0
var _ambience_db: float = 0.0
var _ambience_db_target: float = 0.0
var _ambience_db_rate: float = 0.0
var _duck_db: float = 0.0
var _duck_until_ms: int = -1
var _hold_db: float = 0.0
var _in_run: bool = false
var _speed: int = 0
var _held: bool = false
var _dirty: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_unlocked = not OS.has_feature(FEATURE_WEB)
	set_process_input(not _unlocked)
	sheet = AudioSheet.load_file()
	_valid = sheet.is_valid()
	if not _valid:
		# The sheet ships with the game: a broken one is a programming error.
		push_error("audio: the sheet is invalid, the game runs silent:\n%s"
			% "\n".join(sheet.errors))
		return
	_build_buses()
	_build_players()
	for def: AudioBusDef in sheet.buses:
		_apply_volume(def.id)
	get_tree().node_added.connect(_on_node_added)
	EventBus.sim_event.connect(_on_sim_event)
	EventBus.command_applied.connect(_on_command_applied)
	EventBus.speed_changed.connect(_on_speed_changed)
	EventBus.region_selected.connect(_on_region_selected)
	EventBus.run_started.connect(_on_run_started)
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.hold_changed.connect(_on_hold_changed)
	EventBus.volume_changed.connect(_on_volume_changed)
	EventBus.mute_changed.connect(_on_mute_changed)
	ScreenRouter.screen_changed.connect(_on_screen_changed)
	_request_cue_streams()


func _process(delta: float) -> void:
	step(delta)


## §5.8: the first key, click or tap unlocks the web's audio. It is not
## consumed — on the boot screen the same input skips to the title.
func _input(event: InputEvent) -> void:
	if _unlocked or not _is_unlock(event):
		return
	set_unlocked(true)


## §5.7: a desktop window without focus is silent when the setting says so.
func _notification(what: int) -> void:
	if not _valid or OS.has_feature(FEATURE_WEB) or OS.has_feature(FEATURE_MOBILE):
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not Settings.audio_background:
		AudioServer.set_bus_mute(MASTER_INDEX, true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_apply_volume(AudioSheet.BUS_MASTER)


# ------------------------------------------------------------------- public


## The `call` trigger (§4.4): plays `id` from a script. True when admitted.
func cue(id: StringName, pitch: float = 1.0, args: Dictionary = {}) -> bool:
	return _play(id, pitch, args, true)


## §5.3: matches a source against the sheet and plays what it names. True when
## a cue was admitted.
func dispatch(on: String, key: String, fields: Dictionary) -> bool:
	if not _valid:
		return false
	var trigger: AudioTriggerDef = AudioRules.first_trigger(sheet, on, key, fields)
	if trigger == null:
		return false
	var id: String = AudioRules.resolve(trigger.cue, fields)
	if id.is_empty():
		return false
	return _play(StringName(id), trigger.pitch, fields, true)


## §3.2: the stored volume of a bus, or the sheet's default.
func volume(bus: StringName) -> float:
	var def: AudioBusDef = sheet.bus(bus) if sheet != null else null
	var fallback: float = def.default_volume if def != null else 1.0
	return float(Settings.volumes.get(String(bus), fallback))


## §3.3: the next volume step, and a preview of the bus a moment later.
func cycle_volume(bus: StringName) -> void:
	Settings.set_volume(String(bus), AudioRules.next_volume(volume(bus)))
	if not _valid or not PREVIEW_CUES.has(bus):
		return
	get_tree().create_timer(float(sheet.preview_delay_ms) / UiTokens.MS_PER_SECOND, true) \
		.timeout.connect(_preview.bind(PREVIEW_CUES[bus]))


func is_unlocked() -> bool:
	return _unlocked


## §5.8, and the test seam of §12.1: locked, cues are recorded and captioned
## but never played; unlocking starts the current screen's loops.
func set_unlocked(value: bool) -> void:
	_unlocked = value
	set_process_input(not _unlocked and OS.has_feature(FEATURE_WEB))
	_dirty = true


func reset_history() -> void:
	history.clear()


## A test seam: forgets every cooldown, the alert gap, the ending and a duck
## in progress (whose hold is measured on the clock a test may have moved).
func reset_ledger() -> void:
	_ledger.reset()
	_duck_until_ms = -1
	_duck_db = 0.0
	_dirty = true


## The clock the ledger and the duck read, in ms.
func now_ms() -> int:
	return clock_override_ms if clock_override_ms >= 0 else Time.get_ticks_msec()


## Moves every loop value by `seconds` and writes the players' volumes. The
## frame calls it; a test calls it to walk the fades.
func step(seconds: float) -> void:
	if not _valid:
		return
	var moved: bool = _dirty
	_dirty = false
	for i: int in _layer_gain.size():
		var gain: float = _toward(_layer_gain[i], _layer_target[i], _layer_rate[i], seconds)
		moved = moved or gain != _layer_gain[i]
		_layer_gain[i] = gain
	var music: float = _toward(_music_gain, _music_target, _music_rate, seconds)
	var glided: float = _toward(_tension, _tension_target, _glide_rate(), seconds)
	var ambience: float = _toward(_ambience_db, _ambience_db_target,
		_ambience_db_rate, seconds)
	var duck: float = _step_duck(seconds)
	var hold: float = _step_hold(seconds)
	moved = moved or music != _music_gain or glided != _tension or ambience != _ambience_db \
		or duck != _duck_db or hold != _hold_db
	_music_gain = music
	_tension = glided
	_ambience_db = ambience
	_duck_db = duck
	_hold_db = hold
	if not moved:
		return
	_start_and_stop_loops()
	_write_loop_volumes()


# ------------------------------------------------------- reads for the tests


func layer_player(index: int) -> AudioStreamPlayer:
	return _layer_players[index]


func stem_player(index: int) -> AudioStreamPlayer:
	return _stem_players[index]


func layer_gain(index: int) -> float:
	return _layer_gain[index]


func layer_target(index: int) -> float:
	return _layer_target[index]


func music_gain() -> float:
	return _music_gain


func music_target() -> float:
	return _music_target


func tension() -> float:
	return _tension


func duck_db() -> float:
	return _duck_db


func hold_db() -> float:
	return _hold_db


func is_ending() -> bool:
	return _ledger.ending


## The engine index of a sheet bus, −1 when there is none.
func bus_index(bus: StringName) -> int:
	return MASTER_INDEX if bus == AudioSheet.BUS_MASTER else AudioServer.get_bus_index(bus)


# ------------------------------------------------------------------- build


## §3.1: the buses from the sheet, each sending to `Master`, and the limiter on
## `Master`. Idempotent — a second instance (a test's) finds them there.
func _build_buses() -> void:
	for def: AudioBusDef in sheet.buses:
		if def.id == AudioSheet.BUS_MASTER:
			_ensure_limiter(def.limiter_db)
			continue
		var index: int = AudioServer.get_bus_index(def.id)
		if index < 0:
			AudioServer.add_bus()
			index = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, def.id)
		AudioServer.set_bus_send(index, ENGINE_MASTER)


func _ensure_limiter(ceiling_db: float) -> void:
	for i: int in AudioServer.get_bus_effect_count(MASTER_INDEX):
		if AudioServer.get_bus_effect(MASTER_INDEX, i) is AudioEffectHardLimiter:
			return
	var limiter: AudioEffectHardLimiter = AudioEffectHardLimiter.new()
	limiter.ceiling_db = ceiling_db
	AudioServer.add_bus_effect(MASTER_INDEX, limiter)


func _build_players() -> void:
	for def: AudioBusDef in sheet.buses:
		if def.pool <= 0:
			continue
		var players: Array[AudioStreamPlayer] = []
		var voices: Array[AudioVoice] = []
		for i: int in def.pool:
			var player: AudioStreamPlayer = _new_player(def.id)
			player.finished.connect(_on_voice_finished.bind(def.id, i))
			players.append(player)
			voices.append(AudioVoice.new())
		_pool_players[def.id] = players
		_pool_voices[def.id] = voices
	for layer: AudioLoopDef in sheet.layers:
		_layer_players.append(_new_player(AudioSheet.BUS_AMBIENCE))
		_layer_gain.append(0.0)
		_layer_target.append(0.0)
		_layer_rate.append(0.0)
	for stem: AudioLoopDef in sheet.stems:
		_stem_players.append(_new_player(AudioSheet.BUS_MUSIC))


func _new_player(bus: StringName) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = bus
	# Every player keeps running under a paused tree, like the node (§5).
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player


# -------------------------------------------------------------------- cues


## §5.3 steps 3–6.
func _play(id: StringName, pitch: float, fields: Dictionary, with_caption: bool) -> bool:
	if not _valid:
		return false
	var def: AudioCueDef = sheet.cue(id)
	if def == null:
		_warn_once("cue:" + String(id), "audio: \"%s\" is not a cue" % id)
		return false
	if not _ledger.admit(def, now_ms(), sheet):
		return false
	history.append(id)
	if history.size() > HISTORY_MAX:
		history.pop_front()
	if with_caption and not def.caption.is_empty():
		# The caption reflects the game, not the speaker (§5.3 step 5).
		EventBus.caption_pushed.emit(def.caption, fields)
		if def.announce:
			EventBus.caption_announced.emit(def.caption, fields)
	if _unlocked:
		_start_voice(def, pitch)
	return true


func _start_voice(def: AudioCueDef, pitch: float) -> void:
	var players: Array = _pool_players.get(def.bus, [])
	var voices: Array[AudioVoice] = []
	voices.assign(_pool_voices.get(def.bus, []))
	for i: int in voices.size():
		voices[i].playing = voices[i].playing and (players[i] as AudioStreamPlayer).playing
	var slot: int = _ledger.pick_slot(def, voices)
	if slot < 0:
		return
	var player: AudioStreamPlayer = players[slot]
	var stream: AudioStream = _stream(def.path())
	player.stop()
	player.stream = stream
	player.volume_db = def.volume_db
	player.pitch_scale = pitch * _rng.randf_range(1.0 - def.pitch_jitter, 1.0 + def.pitch_jitter)
	var voice: AudioVoice = voices[slot]
	voice.cue_id = def.id
	voice.priority = def.priority
	voice.started_ms = now_ms()
	voice.playing = stream != null
	if stream != null:
		player.play()
	if def.duck:
		_duck(stream)


## §5.5: down over the attack, held for the stream's length, back over the
## release; a second duck extends the hold.
func _duck(stream: AudioStream) -> void:
	var length_ms: int = MISSING_LENGTH_MS
	if stream != null:
		length_ms = roundi(stream.get_length() * UiTokens.MS_PER_SECOND)
	_duck_until_ms = maxi(_duck_until_ms, now_ms() + length_ms)
	_dirty = true


func _preview(id: StringName) -> void:
	_play(id, 1.0, {}, false)


func _stream(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	var stream: AudioStream = null
	if _requested.has(path):
		# Waits for the thread only if the file is still on its way.
		stream = ResourceLoader.load_threaded_get(path) as AudioStream
	elif ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	if stream == null:
		_warn_once(path, "audio: %s is missing" % path)
	_streams[path] = stream
	return stream


## Every cue's file, loaded off the main thread while the boot and the title
## run. Not on the web, whose single-threaded build would load them all here.
func _request_cue_streams() -> void:
	if OS.has_feature(FEATURE_WEB):
		return
	for id: StringName in sheet.cues:
		var path: String = sheet.cues[id].path()
		if _requested.has(path) or not ResourceLoader.exists(path):
			continue
		if ResourceLoader.load_threaded_request(path) == OK:
			_requested[path] = true


func _warn_once(key: String, message: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	push_warning(message)


# ------------------------------------------------------------------- loops


## §6.1: the session before a run — Boxed's layer, music at tension 0.
func _to_session() -> void:
	var fade: float = _seconds(sheet.screen_fade_ms)
	_set_layers(1, fade)
	_set_ambience_db(0.0, fade)
	_set_music(true, fade)
	_tension_target = 0.0


## §6.4: a screen outside the session.
func _to_screen(def: AudioScreenDef) -> void:
	var fade: float = _seconds(sheet.screen_fade_ms)
	_set_layers(def.ambience_layers, fade)
	_set_ambience_db(def.ambience_db, fade)
	_set_music(def.music, fade)
	_tension_target = def.tension


## The first `count` layers go to full and the rest to silence, each over
## `seconds` (0: at once).
func _set_layers(count: int, seconds: float) -> void:
	for i: int in _layer_gain.size():
		_layer_target[i] = 1.0 if i < count else 0.0
		_layer_rate[i] = _rate(1.0, seconds)
		if seconds <= 0.0:
			_layer_gain[i] = _layer_target[i]
	_dirty = true


func _set_ambience_db(target: float, seconds: float) -> void:
	_ambience_db_target = target
	_ambience_db_rate = _rate(absf(target - _ambience_db), seconds)
	if seconds <= 0.0:
		_ambience_db = target
	_dirty = true


func _set_music(on: bool, seconds: float) -> void:
	_music_target = 1.0 if on else 0.0
	_music_rate = _rate(1.0, seconds)
	if seconds <= 0.0:
		_music_gain = _music_target
	_dirty = true


## §6.5: everything fades out and the ledger admits only the final cues.
func _to_ending() -> void:
	var fade: float = _seconds(sheet.end_fade_ms)
	_set_layers(0, fade)
	_set_music(false, fade)
	_ledger.ending = true


## Starts the loops that should sound and stops the ones faded out. The stems
## start together, in one frame, and never stop alone (§6.3).
func _start_and_stop_loops() -> void:
	for i: int in _layer_players.size():
		var player: AudioStreamPlayer = _layer_players[i]
		var wanted: bool = _layer_target[i] > 0.0 or _layer_gain[i] > 0.0
		if wanted and _unlocked and not player.playing:
			player.stream = _stream(sheet.layers[i].path())
			if player.stream != null:
				player.play()
		elif not wanted and player.playing:
			player.stop()
	var music_wanted: bool = _music_target > 0.0 or _music_gain > 0.0
	if music_wanted and _unlocked and not _music_on:
		_music_on = true
		for i: int in _stem_players.size():
			_stem_players[i].stream = _stream(sheet.stems[i].path())
		for player: AudioStreamPlayer in _stem_players:
			if player.stream != null:
				player.play()
	elif not music_wanted and _music_on:
		_music_on = false
		for player: AudioStreamPlayer in _stem_players:
			player.stop()


## §6.6: one formula for a loop player's volume.
func _write_loop_volumes() -> void:
	for i: int in _layer_players.size():
		_layer_players[i].volume_db = sheet.layers[i].volume_db \
			+ AudioRules.gain_db(_layer_gain[i], sheet.silent_db) + _ambience_db + _duck_db \
			+ _hold_db
	for i: int in _stem_players.size():
		var stem: AudioLoopDef = sheet.stems[i]
		_stem_players[i].volume_db = stem.volume_db + AudioRules.gain_db(
			AudioRules.stem_gain(stem, _tension) * _music_gain, sheet.silent_db) + _duck_db


func _step_duck(seconds: float) -> float:
	var ducking: bool = _duck_until_ms >= 0 and now_ms() < _duck_until_ms
	var target: float = sheet.duck_db if ducking else 0.0
	var span: float = absf(sheet.duck_db)
	var rate: float = _rate(span, _seconds(sheet.duck_attack_ms if ducking
		else sheet.duck_release_ms))
	return _toward(_duck_db, target, rate, seconds)


## §5.6: while the clock stands in a run, the ambience steps back.
func _step_hold(seconds: float) -> float:
	var stands: bool = _in_run and (_speed == 0 or _held)
	var target: float = sheet.hold_ambience_db if stands else 0.0
	var rate: float = _rate(absf(sheet.hold_ambience_db), _seconds(sheet.hold_ms))
	return _toward(_hold_db, target, rate, seconds)


func _glide_rate() -> float:
	return _rate(1.0, _seconds(sheet.tension_glide_ms))


## `current` moved toward `target` at `rate` per second for `seconds`; an
## infinite rate arrives at once.
static func _toward(current: float, target: float, rate: float, seconds: float) -> float:
	if is_inf(rate):
		return target
	return move_toward(current, target, rate * seconds)


## `span` per `seconds`; an instant move for no time.
static func _rate(span: float, seconds: float) -> float:
	return INF if seconds <= 0.0 else span / seconds


static func _seconds(ms: int) -> float:
	return float(ms) / UiTokens.MS_PER_SECOND


## §6.3: in a run the tension is the screen pass's heat.
func _run_heat() -> float:
	if Game.sim == null or Game.db == null:
		return 0.0
	var world: World = Game.sim.world
	return ScreenFxRules.heat(world.phase, ScreenFxRules.endgame(world, Game.db))


## §3.2: 0 mutes the bus, anything else sets it in decibels. The master bus is
## also muted by the button beside the menu (S6.P3b), whatever its volume.
func _apply_volume(bus: StringName) -> void:
	var index: int = bus_index(bus)
	if index < 0:
		return
	var value: float = volume(bus)
	var silenced: bool = bus == AudioSheet.BUS_MASTER and Settings.muted
	AudioServer.set_bus_mute(index, value <= 0.0 or silenced)
	if value > 0.0:
		AudioServer.set_bus_volume_db(index, linear_to_db(value))


static func _is_unlock(event: InputEvent) -> bool:
	if event is InputEventKey:
		return (event as InputEventKey).pressed
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false


# ---------------------------------------------------------------- handlers


func _on_node_added(node: Node) -> void:
	var button: BaseButton = node as BaseButton
	if button == null or button.has_meta(META_CONNECTED):
		return
	button.set_meta(META_CONNECTED, true)
	button.pressed.connect(_on_button_pressed.bind(button))


## §5.2: every button clicks, unless it names its own cue or silence.
func _on_button_pressed(button: BaseButton) -> void:
	if button.has_meta(META_AUDIO_CUE):
		var id: StringName = StringName(str(button.get_meta(META_AUDIO_CUE)))
		if not id.is_empty():
			cue(id)
		return
	dispatch(AudioTriggerDef.ON_BUTTON, "", {})


func _on_voice_finished(bus: StringName, slot: int) -> void:
	var voices: Array = _pool_voices.get(bus, [])
	if slot < voices.size():
		(voices[slot] as AudioVoice).playing = false


func _on_sim_event(event: SimEvent) -> void:
	dispatch(AudioTriggerDef.ON_SIM, event.type, event.data)
	if event.type == SimEvent.PHASE_CHANGED:
		var phase: int = World.PHASE_IDS.find(str(event.data.get(FIELD_TO, "")))
		if phase >= 0 and not _ledger.ending:
			# §6.1: the new layer fades in after the sting; none ever fades out.
			var count: int = AudioRules.layer_count(phase)
			for i: int in mini(count, _layer_target.size()):
				if _layer_target[i] < 1.0:
					_layer_target[i] = 1.0
					_layer_rate[i] = _rate(1.0, _seconds(sheet.layer_fade_in_ms))
			_dirty = true
	elif event.type == SimEvent.OUTCOME_REACHED:
		_to_ending()


func _on_command_applied(_command: Command, result: CommandResult) -> void:
	if not result.ok:
		dispatch(AudioTriggerDef.ON_COMMAND_REJECTED, "", {FIELD_REASON: result.reason})


func _on_speed_changed(speed: int) -> void:
	_speed = speed
	_dirty = true
	dispatch(AudioTriggerDef.ON_BUS, AudioTriggerDef.SIGNAL_SPEED_CHANGED,
		{FIELD_SPEED: speed, FIELD_HOLD: Game.is_hold_change()})


func _on_region_selected(index: int) -> void:
	dispatch(AudioTriggerDef.ON_BUS, AudioTriggerDef.SIGNAL_REGION_SELECTED,
		{FIELD_INDEX: index})


func _on_hold_changed(held: bool) -> void:
	_held = held
	_dirty = true


## §6.1: a new run or a load sounds its phase at once.
func _on_run_started(_seed_value: int) -> void:
	_in_run = true
	_ledger.ending = false
	var phase: int = Game.sim.world.phase if Game.sim != null else World.Phase.BOXED
	_set_layers(AudioRules.layer_count(phase), 0.0)
	_set_ambience_db(0.0, 0.0)
	_set_music(true, 0.0)
	_tension_target = _run_heat()
	_tension = _tension_target


func _on_tick_advanced(_day: int) -> void:
	_tension_target = _run_heat()


func _on_screen_changed(screen: int) -> void:
	_ledger.ending = false
	var screen_id: String = str(ScreenRouter.Screen.keys()[screen]).to_lower()
	dispatch(AudioTriggerDef.ON_ROUTER, "", {FIELD_SCREEN: screen_id})
	if screen == ScreenRouter.Screen.SESSION:
		_to_session()
		return
	_in_run = false
	var def: AudioScreenDef = sheet.screens.get(StringName(screen_id), null) as AudioScreenDef
	if def != null:
		_to_screen(def)


func _on_volume_changed(bus: StringName, _value: float) -> void:
	_apply_volume(bus)


func _on_mute_changed(_muted: bool) -> void:
	_apply_volume(AudioSheet.BUS_MASTER)
