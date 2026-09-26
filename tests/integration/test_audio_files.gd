extends GutTest
## S6.6 — the sound set on disk (spec audio.md §10, §12.2): every file the sheet
## names exists and imports the way §10.3 says. How the files sound is measured
## by `tools/audio/synth.py --check` (peaks, loudness, byte-identical renders),
## which the Godot suite does not call — the session log records its run.

const RATE: int = 44100
## §10.2: cues are mono except the two endings.
const STEREO_CUE_PREFIX: String = "end_"

var _sheet: AudioSheet = null


func before_all() -> void:
	_sheet = AudioSheet.load_file()


func _cue_path(cue: AudioCueDef) -> String:
	return AudioSheet.ASSET_ROOT + cue.file


func _loops() -> Array[AudioLoopDef]:
	var loops: Array[AudioLoopDef] = []
	loops.append_array(_sheet.layers)
	loops.append_array(_sheet.stems)
	return loops


func test_the_sheet_loads() -> void:
	assert_true(_sheet.is_valid(), "\n".join(_sheet.errors))


func test_every_cue_file_loads_as_a_wav() -> void:
	for cue: AudioCueDef in _sheet.cues.values():
		var stream: AudioStream = load(_cue_path(cue)) as AudioStream
		assert_true(stream is AudioStreamWAV, "%s loads as a WAV" % cue.file)


func test_every_loop_file_loads_as_a_looping_ogg() -> void:
	for loop: AudioLoopDef in _loops():
		var stream: AudioStreamOggVorbis = load(AudioSheet.ASSET_ROOT + loop.file) \
			as AudioStreamOggVorbis
		assert_not_null(stream, "%s loads as Ogg Vorbis" % loop.file)
		if stream != null:
			assert_true(stream.loop, "%s loops" % loop.file)
			assert_eq(stream.loop_offset, 0.0, "%s loops from the start" % loop.file)


func test_cues_are_44100_hz() -> void:
	for cue: AudioCueDef in _sheet.cues.values():
		var stream: AudioStreamWAV = load(_cue_path(cue)) as AudioStreamWAV
		if stream != null:
			assert_eq(stream.mix_rate, RATE, cue.file)


## web.md §4.4 (S7.3): the cues import as QOA, ~5× smaller than PCM, for the
## browser's download; the same files play on the desktop.
func test_cues_are_qoa_and_do_not_loop() -> void:
	for cue: AudioCueDef in _sheet.cues.values():
		var stream: AudioStreamWAV = load(_cue_path(cue)) as AudioStreamWAV
		if stream != null:
			assert_eq(stream.format, AudioStreamWAV.FORMAT_QOA, "%s is QOA" % cue.file)
			assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_DISABLED, "%s is one-shot" % cue.file)


func test_only_the_endings_are_stereo_cues() -> void:
	for cue: AudioCueDef in _sheet.cues.values():
		var stream: AudioStreamWAV = load(_cue_path(cue)) as AudioStreamWAV
		if stream != null:
			assert_eq(stream.stereo, String(cue.id).begins_with(STEREO_CUE_PREFIX), cue.file)


func test_the_music_stems_have_one_length() -> void:
	var lengths: Array[float] = []
	for stem: AudioLoopDef in _sheet.stems:
		var stream: AudioStream = load(AudioSheet.ASSET_ROOT + stem.file) as AudioStream
		assert_not_null(stream, stem.file)
		if stream != null:
			lengths.append(stream.get_length())
	assert_eq(lengths.size(), _sheet.stems.size())
	for length: float in lengths:
		assert_eq(length, lengths[0], "every stem is as long as the first")
	assert_gt(lengths[0] if not lengths.is_empty() else 0.0, 0.0)


func test_no_file_ships_that_the_sheet_does_not_name() -> void:
	var named: Dictionary[String, bool] = {}
	for cue: AudioCueDef in _sheet.cues.values():
		named[cue.file] = true
	for loop: AudioLoopDef in _loops():
		named[loop.file] = true
	var extra: Array[String] = []
	for folder: String in DirAccess.get_directories_at(AudioSheet.ASSET_ROOT):
		for file: String in DirAccess.get_files_at(AudioSheet.ASSET_ROOT + folder):
			var relative: String = "%s/%s" % [folder, file]
			var is_audio: bool = file.ends_with(AudioSheet.EXT_CUE) \
				or file.ends_with(AudioSheet.EXT_LOOP)
			if is_audio and not named.has(relative):
				extra.append(relative)
	assert_eq(extra, [] as Array[String])
