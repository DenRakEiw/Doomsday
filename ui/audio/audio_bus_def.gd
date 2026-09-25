class_name AudioBusDef
extends RefCounted
## One bus of `data/audio.json` (spec audio.md §4.1). `master` is the engine's
## bus 0; the others are added in sheet order and send to it.

var id: StringName = &""
## "" for `master`, else `master`.
var send: String = ""
## 0…1, one of `AudioRules.VOLUME_STEPS`.
var default_volume: float = 1.0
## How many cue players the bus owns (`interface` and `alerts` only; 0 otherwise).
var pool: int = 0
## The hard limiter's ceiling on `master` (0 elsewhere).
var limiter_db: float = 0.0
