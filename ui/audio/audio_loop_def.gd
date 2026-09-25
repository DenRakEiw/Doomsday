class_name AudioLoopDef
extends RefCounted
## An ambience layer or a music stem of `data/audio.json` (spec audio.md §4.7).

var id: StringName = &""
## Under `AudioSheet.ASSET_ROOT`, an `.ogg`.
var file: String = ""
var volume_db: float = 0.0
## A stem's `[lo, hi]` on the tension axis (§6.3); `(0, 0)` for a layer.
var fade: Vector2 = Vector2.ZERO


func path() -> String:
	return AudioSheet.ASSET_ROOT + file
