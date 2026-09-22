class_name SlidePanel
extends Control
## A panel that slides in from an edge (spec ui-foundation.md §4.6).
##
## The host fills the screen but lets every event through except over the panel
## itself, so an open region panel never swallows a click on the map beside it.
## While closed the panel is hidden, which is the only way to be sure it has no
## hit area left behind.
##
## The child it moves is the first `Control` under it — `ConsolePanel` in every
## M2 use. Positions are computed, not authored: this is a container-free root,
## the one place UI.md allows that.

enum Edge { LEFT, RIGHT, BOTTOM }
enum State { CLOSED, OPENING, OPEN, CLOSING }

## §4.6: a side panel is 30 % of the viewport, between these bounds.
const WIDTH_SHARE: float = 0.3
const WIDTH_MIN: float = 360.0
const WIDTH_MAX: float = 480.0
## A bottom sheet takes half the height.
const HEIGHT_SHARE: float = 0.5

## Which edge the panel comes in from.
@export var edge: Edge = Edge.LEFT

## How much room the panel leaves at the top and the bottom for the HUD strips
## it must not cover (§4.6). Set by the screen that owns the panel.
var top_inset: float = 0.0
var bottom_inset: float = 0.0

## Whether the panel is open or on its way there.
var is_open: bool = false

var _panel: Control = null
var _state: State = State.CLOSED
var _tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel = _find_panel()
	if _panel == null:
		push_error("SlidePanel has no Control child to slide")
		return
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.visible = false
	get_viewport().size_changed.connect(_layout)
	_layout()


## Slides the panel in. A second call while it is opening does nothing.
func open() -> void:
	if _panel == null or _state == State.OPENING or _state == State.OPEN:
		return
	is_open = true
	_panel.visible = true
	_layout()
	_slide(State.OPENING, State.OPEN, _open_position())


## Slides the panel out — from wherever it currently is, so a close during an
## opening reverses the movement instead of jumping.
func close() -> void:
	if _panel == null or _state == State.CLOSED or _state == State.CLOSING:
		return
	is_open = false
	_slide(State.CLOSING, State.CLOSED, _closed_position())


## The panel's size and its resting place, recomputed whenever the window changes.
func _layout() -> void:
	if _panel == null:
		return
	var view: Vector2 = get_viewport_rect().size
	if edge == Edge.BOTTOM:
		_panel.size = Vector2(view.x, floorf(view.y * HEIGHT_SHARE))
	else:
		var width: float = clampf(view.x * WIDTH_SHARE, WIDTH_MIN, WIDTH_MAX)
		_panel.size = Vector2(floorf(width), maxf(view.y - top_inset - bottom_inset, 0.0))
	# A resize while the panel is moving leaves the tween to finish the job.
	if _state == State.OPEN:
		_panel.position = _open_position()
	elif _state == State.CLOSED:
		_panel.position = _closed_position()


func _open_position() -> Vector2:
	match edge:
		Edge.LEFT:
			return Vector2(0.0, top_inset)
		Edge.RIGHT:
			return Vector2(get_viewport_rect().size.x - _panel.size.x, top_inset)
		_:
			return Vector2(0.0, get_viewport_rect().size.y - _panel.size.y)


## One panel's width or height outside the screen, on the edge it belongs to.
func _closed_position() -> Vector2:
	var open_at: Vector2 = _open_position()
	match edge:
		Edge.LEFT:
			return Vector2(open_at.x - _panel.size.x, open_at.y)
		Edge.RIGHT:
			return Vector2(open_at.x + _panel.size.x, open_at.y)
		_:
			return Vector2(open_at.x, open_at.y + _panel.size.y)


func _slide(during: State, after: State, target: Vector2) -> void:
	_state = during
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var seconds: float = UiTokens.duration(UiTokens.MOTION_PANEL)
	if seconds <= 0.0:
		_panel.position = target
		_finish(after)
		return
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(_panel, "position", target, seconds)
	_tween.finished.connect(_finish.bind(after))


func _finish(after: State) -> void:
	_state = after
	if after == State.CLOSED:
		_panel.visible = false


func _find_panel() -> Control:
	for child: Node in get_children():
		var control: Control = child as Control
		if control != null:
			return control
	return null
