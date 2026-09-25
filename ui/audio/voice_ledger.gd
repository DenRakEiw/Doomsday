class_name VoiceLedger
extends RefCounted
## Admission and voices (spec audio.md §5.4): whether a cue may sound now, and
## which player of its bus it takes.
##
## Pure — the clock is an argument — so every rule is tested without a frame.

## Long enough ago that no gap or cooldown still counts.
const NEVER_MS: int = -1000000

## Cue id → when it last started, in ms.
var last_start_ms: Dictionary[StringName, int] = {}
## When an alert at or above the gap priority last started.
var last_gap_ms: int = NEVER_MS
## The run has ended: only `final` alerts may still sound.
var ending: bool = false


## §5.4: the first refusal wins; an admitted cue is recorded.
func admit(cue: AudioCueDef, now_ms: int, sheet: AudioSheet) -> bool:
	var alert: bool = cue.bus == AudioSheet.BUS_ALERTS
	if ending and alert and not cue.final:
		return false
	if last_start_ms.has(cue.id) and now_ms - last_start_ms[cue.id] < cue.cooldown_ms:
		return false
	var gap_setter: bool = cue.priority >= sheet.alert_gap_priority
	if alert and not gap_setter and now_ms - last_gap_ms < sheet.alert_gap_ms:
		return false
	last_start_ms[cue.id] = now_ms
	if alert and gap_setter:
		last_gap_ms = now_ms
	return true


## §5.4: the player `cue` takes among `voices` (one per player of its bus), or
## −1 when every one plays something that matters more.
func pick_slot(cue: AudioCueDef, voices: Array[AudioVoice]) -> int:
	var own: int = -1
	var own_count: int = 0
	for i: int in voices.size():
		var voice: AudioVoice = voices[i]
		if voice.playing and voice.cue_id == cue.id:
			own_count += 1
			if own < 0 or voice.started_ms < voices[own].started_ms:
				own = i
	if own_count >= cue.voices:
		return own
	for i: int in voices.size():
		if not voices[i].playing:
			return i
	var lowest: int = -1
	for i: int in voices.size():
		var voice: AudioVoice = voices[i]
		if lowest < 0 or voice.priority < voices[lowest].priority \
				or (voice.priority == voices[lowest].priority
					and voice.started_ms < voices[lowest].started_ms):
			lowest = i
	if lowest >= 0 and voices[lowest].priority <= cue.priority:
		return lowest
	return -1


func reset() -> void:
	last_start_ms.clear()
	last_gap_ms = NEVER_MS
	ending = false
