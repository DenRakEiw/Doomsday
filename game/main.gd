extends Control

## Placeholder main scene for M0. It exists so the project runs and so headless
## and windowed smoke checks have something to look at. The real entry point is
## the boot sequence and title screen built in S3.4.

@onready var _build_label: Label = %BuildLabel


func _ready() -> void:
	var version: Dictionary = Engine.get_version_info()
	var renderer: String = str(ProjectSettings.get_setting("rendering/renderer/rendering_method"))
	var base_size: Vector2i = get_window().content_scale_size
	# Technical values only — no player-facing prose that would need tr() here.
	_build_label.text = "Godot %s · %s · %d×%d" % [
		str(version["string"]), renderer, base_size.x, base_size.y
	]
