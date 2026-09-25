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
## A bottom sheet takes half the height. m3-screens §6.3 gives the tech detail
## and the menu sheet a little more, so the share is a property with this
## default rather than a number the caller cannot reach.
const HEIGHT_SHARE: float = 0.5

## Which edge the panel comes in from. §5.7 swaps it at the breakpoint, so it is
## a setter: the panel re-measures and, while closed, moves out of sight on the
## new edge instead of staying parked outside the old one.
@export var edge: Edge = Edge.LEFT:
	set(value):
		if value == edge:
			return
		edge = value
		if _panel != null:
			_layout()

## How much room the panel leaves at the top and the bottom for the HUD strips
## it must not cover (§4.6). Set by the screen that owns the panel, which knows
## how tall its own strips came out.
var top_inset: float = 0.0:
	set(value):
		top_inset = value
		if _panel != null:
			_layout()
var bottom_inset: float = 0.0:
	set(value):
		bottom_inset = value
		if _panel != null:
			_layout()

## How much of the height a bottom sheet takes.
@export var height_share: float = HEIGHT_SHARE:
	set(value):
		height_share = value
		if _panel != null:
			_layout()

## Whether the panel is open or on its way there.
var is_open: bool = false

## accessibility.md §4.4: where the focus goes back to when a panel that took it
## closes and its opener is gone — the session sets the map (`MapFocus`).
var focus_fallback: Control = null

var _panel: Control = null
var _state: State = State.CLOSED
var _tween: Tween = null
## Whatever had the focus when a keyboard open took it.
var _focus_before: Control = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_adopt_child()


## A panel may arrive after `_ready` — m3-screens §3.6 moves the tech detail into
## a sheet only when the layout turns compact.
func _notification(what: int) -> void:
	if what == NOTIFICATION_CHILD_ORDER_CHANGED and is_node_ready():
		_adopt_child()


## The child this panel slides. A panel that starts empty is not an error: the
## tech detail moves in only when the layout turns compact.
func _adopt_child() -> void:
	var found: Control = _find_panel()
	if found == null or found == _panel:
		return
	_panel = found
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.visible = false
	if not get_viewport().size_changed.is_connected(_layout):
		get_viewport().size_changed.connect(_layout)
	_layout()


## Slides the panel in. A second call while it is opening does nothing. With
## `take_focus` (the player is on the keyboard or a pad, accessibility.md §4.4)
## the panel's `primary_focus()` takes the focus, and gets it back on `close`.
func open(take_focus: bool = false) -> void:
	if _panel == null:
		return
	if _state == State.OPENING or _state == State.OPEN:
		if take_focus:
			focus_primary()
		return
	is_open = true
	_panel.visible = true
	_layout()
	_slide(State.OPENING, State.OPEN, _open_position())
	if take_focus:
		focus_primary()


## Gives the focus to `primary_focus()`, remembering where it was.
func focus_primary() -> void:
	var target: Control = primary_focus()
	if target == null or not target.is_inside_tree():
		return
	var owner: Control = get_viewport().gui_get_focus_owner()
	if owner != null and not is_ancestor_of(owner):
		_focus_before = owner
	target.grab_focus()


## The control a keyboard open focuses. A panel script overrides it; the default
## is the first control `Tab` would reach.
func primary_focus() -> Control:
	var roots: Array[Control] = [self]
	var chain: Array[Control] = FocusRing.collect(roots)
	return chain.front() if not chain.is_empty() else null


## Slides the panel out — from wherever it currently is, so a close during an
## opening reverses the movement instead of jumping.
func close() -> void:
	if _panel == null or _state == State.CLOSED or _state == State.CLOSING:
		return
	is_open = false
	_give_focus_back()
	_slide(State.CLOSING, State.CLOSED, _closed_position())


## §4.4: when the focus was inside, it goes back to the control that had it,
## or to the fallback when that one is gone.
func _give_focus_back() -> void:
	var viewport: Viewport = get_viewport()
	var owner: Control = viewport.gui_get_focus_owner() if viewport != null else null
	var before: Control = _focus_before
	_focus_before = null
	if owner == null or not is_ancestor_of(owner):
		return
	owner.release_focus()
	if before != null and is_instance_valid(before) and before.is_visible_in_tree():
		before.grab_focus()
	elif focus_fallback != null and is_instance_valid(focus_fallback) \
			and focus_fallback.is_visible_in_tree():
		focus_fallback.grab_focus()


## The screen rectangle an open panel leaves free, for whatever has to stay
## visible beside it (§5.6: the map pans the selected region out from behind the
## panel). While the panel is closed that is the whole screen.
##
## It is the half the panel is not on, across the whole of the other axis: the
## narrow strips the insets leave beside a side panel are the HUD's, and nothing
## should be moved into them.
func uncovered_rect() -> Rect2:
	var view: Rect2 = Rect2(Vector2.ZERO, get_viewport_rect().size)
	if _panel == null or not is_open:
		return view
	match edge:
		Edge.LEFT:
			return Rect2(_panel.size.x, view.position.y,
				maxf(view.size.x - _panel.size.x, 0.0), view.size.y)
		Edge.RIGHT:
			return Rect2(view.position, Vector2(maxf(view.size.x - _panel.size.x, 0.0),
				view.size.y))
		_:
			return Rect2(view.position, Vector2(view.size.x,
				maxf(view.size.y - _panel.size.y, 0.0)))


## The panel's size and its resting place, recomputed whenever the window changes.
func _layout() -> void:
	if _panel == null:
		return
	var view: Vector2 = get_viewport_rect().size
	if edge == Edge.BOTTOM:
		_panel.size = Vector2(view.x, floorf(view.y * height_share))
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
