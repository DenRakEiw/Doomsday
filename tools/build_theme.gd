extends SceneTree
## Writes `ui/theme/doomsday.tres` from `ThemeBuilder` (spec ui-foundation.md §3.8).
##
##     "$GODOT" --headless --path . -s tools/build_theme.gd
##
## The resource is committed and regenerated whenever a token changes: the
## project theme has to be a file on disk, because a type variation only appears
## in the editor's dropdown if it comes from `gui/theme/custom` (UI.md §4). The
## running game builds the same theme again at the session root, so the phase
## swap of D3.3 needs no second file.

const OUT_PATH: String = "res://ui/theme/doomsday.tres"


func _init() -> void:
	var theme: Theme = ThemeBuilder.build(ThemeBuilder.VARIANT_COLD)
	var error: int = ResourceSaver.save(theme, OUT_PATH)
	if error != OK:
		printerr("could not write %s (error %d)" % [OUT_PATH, error])
		quit(1)
		return
	print("wrote %s: %d type variations" % [OUT_PATH, ThemeBuilder.VARIATIONS.size()])
	quit(0)
