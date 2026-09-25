class_name IconRect
extends Control
## One illustrative icon — a technology, ability, status, architecture,
## counter-move or faction — as a `Control` (docs/specs/icons.md §5.3): the
## counterpart of `GlyphIcon` for the ids of `data/icons.json` that are content.
##
## An id without a file hides the control, so a missing icon leaves no hole; the
## text beside it always carries the meaning (§6).

## The section of icons.json the id is in (`Icons.KIND_*`).
@export var kind: StringName = Icons.KIND_TECH:
	set(value):
		kind = value
		_refresh()

## The content id.
@export var id: String = "":
	set(value):
		id = value
		_refresh()

## The side of the square the icon is drawn into, in pixels.
@export var box_size: float = float(UiTokens.ICON_ROW):
	set(value):
		box_size = maxf(value, 1.0)
		custom_minimum_size = Vector2(box_size, box_size)
		queue_redraw()

## The `UiTokens` colour token the icon takes.
@export var color_token: StringName = &"TEXT_0":
	set(value):
		if value == color_token:
			return
		color_token = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(box_size, box_size)
	# Visibility is not recomputed here: the setters did it, and an owner may
	# have hidden the icon on purpose since (a picture shown in its place).
	# The palette can change mid-run (m3-screens §6.2), like `GlyphIcon`'s.
	EventBus.theme_variant_changed.connect(_on_theme_variant_changed)


## Sets the id and its kind in one go.
func show_icon(new_kind: StringName, new_id: String) -> void:
	kind = new_kind
	id = new_id


func _draw() -> void:
	Icons.draw(self, kind, id, Rect2(Vector2.ZERO, Vector2(box_size, box_size)),
		UiTokens.color(color_token))


func _refresh() -> void:
	visible = not Icons.path_for(kind, id).is_empty()
	queue_redraw()


func _on_theme_variant_changed(_variant: StringName) -> void:
	queue_redraw()
