extends Control
## The entry point (spec m3-screens.md §7.0, `screens-full.md` §1): the backdrop
## that is always there, and the slot the router puts each screen in. A launch
## starts on the boot sequence.
##
## Scene-specific, so no `class_name`.

@onready var _slot: Control = %ScreenSlot


func _ready() -> void:
	# The title and the session share this theme; the session assigns its own on
	# top when the palette changes (§6.2).
	theme = ThemeBuilder.build(ThemeBuilder.VARIANT_COLD, Settings.text_scale)
	ScreenRouter.slot = _slot
	# §6.1: every screen lays out in logical pixels, not only the session.
	get_window().size_changed.connect(_on_window_size_changed)
	LogicalScale.apply(get_window())
	ScreenRouter.boot()
	EventBus.text_scale_changed.connect(_on_text_scale_changed)


## UI.md §5: the settings the title opens can change the scale under it.
func _on_text_scale_changed(scale: float) -> void:
	theme = ThemeBuilder.build(ThemeBuilder.VARIANT_COLD, scale)


func _on_window_size_changed() -> void:
	LogicalScale.apply(get_window())
