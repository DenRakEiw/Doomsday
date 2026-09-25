class_name AudioCueDef
extends RefCounted
## One cue of `data/audio.json` (spec audio.md §4.3): a sound, where it plays,
## how often, and what it says with *Sound captions* on.

var id: StringName = &""
## `interface` or `alerts`.
var bus: StringName = &""
## Under `AudioSheet.ASSET_ROOT`, a `.wav`.
var file: String = ""
## 0…100: who wins a voice (§5.4).
var priority: int = 0
## Real time, not game days.
var cooldown_ms: int = 0
## Instances of this cue at once.
var voices: int = 1
var volume_db: float = 0.0
## `pitch_scale` is drawn from `1 ± pitch_jitter`.
var pitch_jitter: float = 0.0
## Ducks the music and the ambience (§5.5).
var duck: bool = false
## May still play once the run has ended (§5.4).
var final: bool = false
## A `UI_CAPTION_*` key, "" for none.
var caption: String = ""
## The caption is spoken to a screen reader too (accessibility.md §7.2).
var announce: bool = false


## The stream's path.
func path() -> String:
	return AudioSheet.ASSET_ROOT + file
