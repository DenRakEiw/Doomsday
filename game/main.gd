extends Control
## The entry point (spec m3-screens.md §7.0): the backdrop that is always there,
## and the slot the router puts the title or the session in.
##
## Scene-specific, so no `class_name`.

@onready var _slot: Control = %ScreenSlot


func _ready() -> void:
	# The title and the session share this theme; the session assigns its own on
	# top when the palette changes (§6.2).
	theme = ThemeBuilder.build(ThemeBuilder.VARIANT_COLD)
	ScreenRouter.slot = _slot
	ScreenRouter.go_to_title()
