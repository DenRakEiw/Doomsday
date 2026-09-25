class_name AudioVoice
extends RefCounted
## What one cue player of a pool is doing (spec audio.md §5.4). `Audio` keeps
## `playing` in step with the player's `finished`.

var cue_id: StringName = &""
var priority: int = 0
var started_ms: int = 0
var playing: bool = false
