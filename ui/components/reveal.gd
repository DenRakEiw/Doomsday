class_name Reveal
extends RefCounted
## How a HUD block appears when the phase reveals it (spec m3-screens.md §6.1).
##
## One place, because five different blocks do it and a reveal that looks
## different in each would read as five bugs. Under reduced motion the block
## simply is there.
##
## Never instantiated; a namespace of one function.


## Fades `control` in from nothing over `MOTION_PANEL`. The caller has already
## made it visible; this is only the arrival.
static func play(control: Control) -> void:
	if control == null or not control.is_inside_tree():
		return
	var seconds: float = UiTokens.duration(UiTokens.MOTION_PANEL)
	if seconds <= 0.0:
		control.modulate.a = 1.0
		return
	control.modulate.a = 0.0
	var tween: Tween = control.create_tween()
	tween.tween_property(control, "modulate:a", 1.0, seconds)
