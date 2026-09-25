class_name MuteButton
extends IconButton
## All sound off and on again, beside the menu button (the user, 2026-09-25;
## PROGRESS punch item 5).
##
## A master mute of its own in `Settings`, stored with the settings and apart
## from the volume sliders: muting and unmuting leaves every volume where the
## player set it. The glyph and the tooltip say what pressing does next.

const KEY_MUTE: String = "UI_HUD_MUTE"
const KEY_UNMUTE: String = "UI_HUD_UNMUTE"


func _ready() -> void:
	super()
	pressed.connect(_on_pressed)
	EventBus.mute_changed.connect(_on_mute_changed)
	_show(Settings.muted)


func _on_pressed() -> void:
	Settings.set_muted(not Settings.muted)


func _on_mute_changed(muted: bool) -> void:
	_show(muted)


## The glyph shows the state, the tooltip names the action.
func _show(muted: bool) -> void:
	glyph = Glyphs.Glyph.SOUND_OFF if muted else Glyphs.Glyph.SOUND_ON
	tooltip_key = KEY_UNMUTE if muted else KEY_MUTE
