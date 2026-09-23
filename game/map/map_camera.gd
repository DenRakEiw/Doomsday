class_name MapCamera
extends Camera2D
## The map's camera (spec ui-foundation.md §7.5): pan, zoom, inertia and the
## clamp that keeps the map filling the viewport.
##
## It is the only node that reads pointer gestures over the map, because only a
## gesture handler can tell a drag from a tap. What it decides is a tap it hands
## to the layers above the map in reverse tree order (§7.7 wants markers asked
## before the land), and what it decides is a drag never becomes a selection.
##
## Everything geometric here is a static function on ordinary values: the camera
## state that matters is a centre, a zoom and a viewport size, and a test should
## not need a frame to check a clamp.
##
## It names no other map class. `MapView` names *this* one, and a pair of
## classes that name each other cannot be resolved — hence the map's dimensions
## below rather than a reference to the quad that draws them.

## Centre and zoom after any movement, tween steps included. `MapView` keeps the
## selection outline at two screen pixels from it (§7.3), the backdrop parallaxes
## from it (§7.6).
signal view_changed(center: Vector2, zoom_level: float)

# ------------------------------------------------------------- the map's extent

## The ID map, in map pixels — which are world units, because `MapView` draws it
## at 1 : 1.
const MAP_WIDTH: float = 4096.0
const MAP_HEIGHT: float = 2048.0
## §7.5: about 58° S. The empty south is never shown, so the camera's bounds are
## shorter than the map.
const MAP_ROW_MAX: float = 1750.0

# ----------------------------------------------------------------- §7.5 numbers

const ZOOM_MAX: float = 4.0
## One wheel notch.
const ZOOM_STEP: float = 1.15
## Below this much movement between press and release the gesture was a tap.
const DRAG_SLOP_PX: float = 8.0
## `v *= exp(−DECAY × delta)`, stopped below `INERTIA_STOP_PX`.
const INERTIA_DECAY: float = 6.0
const INERTIA_STOP_PX: float = 20.0
## Screen pixels per second for the arrow keys.
const KEY_PAN_PX: float = 400.0
## The mean over the last frames is the throw's velocity; one frame alone is
## noise, and a long tail keeps a stopped finger moving.
const VELOCITY_FRAMES: int = 3
## §7.5: the start view, centred on the inhabited middle of the map.
const START_CENTER: Vector2 = Vector2(2048.0, 875.0)

## What a node above the map implements to be offered a tap before the land is
## picked: `func try_tap(screen: Vector2) -> bool`, true meaning "mine". Asked in
## reverse tree order, so the layer drawn last is asked first.
const TAP_METHOD: String = "try_tap"

## The layers of the map find the camera beside them, but the region panel lives
## in a canvas layer of its own and still has to reach it (§5.6 calls `reveal`
## when the panel opens) — so the camera is findable by group as well.
const GROUP: StringName = &"map_camera"

## Smallest zoom the viewport allows, recomputed with the viewport.
var zoom_min: float = 1.0

var _panning: bool = false
## Screen pixels travelled since the press — a straight distance would call a
## circle back to its start a tap.
## Where the button went down, so that a release near it is a tap (§7.4).
var _press_screen: Vector2 = Vector2.ZERO
var _velocity: Vector2 = Vector2.ZERO
var _velocity_samples: Array[Vector2] = []
var _tween: Tween = null
## The view a running tween is heading for. A wheel notch multiplies *this*
## zoom, so notches that arrive in the same frame add up instead of collapsing
## into one step (§7.5; G2: fourteen notches in one frame moved the map once).
var _target_center: Vector2 = Vector2.ZERO
var _target_zoom: float = 0.0
## Kept for the debug key of §7.5; 0 means nothing is selected.
var _selected_index: int = 0
var _started: bool = false


# ------------------------------------------------------------- pure geometry


## The zoom at which the map just covers the viewport (§7.5). Below it the
## bounds could not fill the screen and the ocean would leak in at an edge.
static func zoom_min_for(viewport_size: Vector2) -> float:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return 1.0
	return maxf(viewport_size.x / MAP_WIDTH, viewport_size.y / MAP_ROW_MAX)


## The map rectangle the camera may show.
static func bounds() -> Rect2:
	return Rect2(0.0, 0.0, MAP_WIDTH, MAP_ROW_MAX)


## `center` moved the least distance that puts the visible rectangle inside the
## bounds. An axis the viewport is too wide for is centred instead of clamped —
## that happens only below `zoom_min`, and a centred map beats a stuck one.
static func clamp_center(center: Vector2, zoom_level: float,
		viewport_size: Vector2) -> Vector2:
	if zoom_level <= 0.0:
		return center
	var rect: Rect2 = bounds()
	var half: Vector2 = viewport_size / zoom_level * 0.5
	var result: Vector2 = center
	if half.x * 2.0 >= rect.size.x:
		result.x = rect.position.x + rect.size.x * 0.5
	else:
		result.x = clampf(center.x, rect.position.x + half.x, rect.end.x - half.x)
	if half.y * 2.0 >= rect.size.y:
		result.y = rect.position.y + rect.size.y * 0.5
	else:
		result.y = clampf(center.y, rect.position.y + half.y, rect.end.y - half.y)
	return result


## World → screen for a centred camera without rotation: exactly what Godot
## writes into the viewport's canvas transform. Stated here so that the picker
## and its tests share one formula with the running game — and
## `test_map_camera.gd` checks that the engine agrees.
static func transform_for(center: Vector2, zoom_level: float,
		viewport_size: Vector2) -> Transform2D:
	return Transform2D(0.0, Vector2(zoom_level, zoom_level), 0.0,
		viewport_size * 0.5 - center * zoom_level)


## The centre that leaves `world_point` under `screen_point` at `zoom_level` —
## the anchor rule of §7.5 for the wheel and for pinch.
static func center_keeping_point(world_point: Vector2, screen_point: Vector2,
		zoom_level: float, viewport_size: Vector2) -> Vector2:
	if zoom_level <= 0.0:
		return world_point
	return world_point - (screen_point - viewport_size * 0.5) / zoom_level


## §7.5: the centre that brings `anchor` inside `free` — the screen rectangle an
## open panel leaves uncovered — shrunk by `margin`, moving as little as
## possible. An anchor that is already inside, or a `free` too small to hold the
## margin, leaves the centre where it is. The zoom is never touched: the player
## asked for a region, not for a different scale.
static func reveal_center(center: Vector2, zoom_level: float, viewport_size: Vector2,
		anchor: Vector2, free: Rect2, margin: float) -> Vector2:
	if zoom_level <= 0.0:
		return center
	var inner: Rect2 = free.grow(-margin)
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return center
	var screen: Vector2 = transform_for(center, zoom_level, viewport_size) * anchor
	var shift: Vector2 = Vector2(
		_shift_into(screen.x, inner.position.x, inner.end.x),
		_shift_into(screen.y, inner.position.y, inner.end.y))
	if shift == Vector2.ZERO:
		return center
	# The map moves by `shift` on screen, so the camera moves against it.
	return clamp_center(center - shift / zoom_level, zoom_level, viewport_size)


## How far `value` has to move to lie between `low` and `high`.
static func _shift_into(value: float, low: float, high: float) -> float:
	if value < low:
		return low - value
	if value > high:
		return high - value
	return 0.0


# ------------------------------------------------------------------- the node


## The camera among a node's siblings, or null. Every layer of the map needs the
## camera and none of them may be named by it, so the search lives here — one
## copy, and a layer that is tested on its own simply gets nothing.
static func find_beside(node: Node) -> MapCamera:
	var parent: Node = node.get_parent()
	if parent == null:
		return null
	for child: Node in parent.get_children():
		var camera: MapCamera = child as MapCamera
		if camera != null:
			return camera
	return null


## The camera of the screen `node` belongs to, or null — for a node that is not
## a sibling of it. Null is a normal answer: a panel tested on its own has no map
## behind it.
static func find_in_tree(node: Node) -> MapCamera:
	if not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group(GROUP) as MapCamera


func _ready() -> void:
	anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	position_smoothing_enabled = false
	rotation_smoothing_enabled = false
	ignore_rotation = true
	make_current()
	add_to_group(GROUP)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	EventBus.region_selected.connect(_on_region_selected)
	zoom_min = zoom_min_for(view_size())
	set_view(START_CENTER, zoom_min)
	_started = true


func _process(delta: float) -> void:
	var pan: Vector2 = _key_pan()
	if pan != Vector2.ZERO:
		_stop_inertia()
		_stop_tween()
		set_view(position + pan * KEY_PAN_PX * delta / zoom.x, zoom.x)
		return
	_advance_inertia(delta)


func _unhandled_input(event: InputEvent) -> void:
	if handle_pointer(event):
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			zoom_by(ZOOM_STEP, view_size() * 0.5, true)
		KEY_MINUS, KEY_KP_SUBTRACT:
			zoom_by(1.0 / ZOOM_STEP, view_size() * 0.5, true)
		KEY_F:
			# §7.5: `focus_region` has no caller in M2 but this one.
			focus_region(_selected_index)
		_:
			return
	get_viewport().set_input_as_handled()


## The camera's world → screen transform, from its own state rather than from
## the viewport, so a click is answered with the view the player just caused and
## not with the one the last frame drew.
func canvas_transform() -> Transform2D:
	return transform_for(position, zoom.x, view_size())


func view_size() -> Vector2:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return Vector2.ZERO
	return viewport.get_visible_rect().size


## Moves the camera, clamped, and tells everything that follows it. Every other
## movement in this class ends here.
func set_view(center: Vector2, zoom_level: float) -> void:
	var size: Vector2 = view_size()
	var wanted_zoom: float = clampf(zoom_level, zoom_min, ZOOM_MAX)
	var wanted_center: Vector2 = clamp_center(center, wanted_zoom, size)
	if _started and wanted_center == position and is_equal_approx(wanted_zoom, zoom.x):
		return
	position = wanted_center
	zoom = Vector2(wanted_zoom, wanted_zoom)
	view_changed.emit(position, wanted_zoom)


## Multiplies the zoom, keeping the world point under `screen_point` where it
## is. `tweened` is the wheel (§7.5 tweens a notch); pinch is continuous.
##
## The factor multiplies the view the camera is *heading for*, not the one it
## draws: a wheel sends its notches faster than a frame, and against the drawn
## zoom all but the first of them would be swallowed by the tween (G2).
func zoom_by(factor: float, screen_point: Vector2, tweened: bool) -> void:
	var size: Vector2 = view_size()
	var from_center: Vector2 = target_center()
	var from_zoom: float = target_zoom()
	var target: float = clampf(from_zoom * factor, zoom_min, ZOOM_MAX)
	var world: Vector2 = transform_for(from_center, from_zoom, size).affine_inverse() 		* screen_point
	var center: Vector2 = center_keeping_point(world, screen_point, target, size)
	var seconds: float = UiTokens.duration(UiTokens.MOTION_QUICK) if tweened else 0.0
	if seconds <= 0.0:
		_stop_tween()
		set_view(center, target)
		return
	_tween_to(center, target, seconds)


## Brings a region's anchor out from behind an open panel (§7.5): `free` is the
## screen rectangle the panel leaves uncovered, and the map is panned by the
## smallest offset that puts the anchor inside it with `SPACE_6` to spare.
func reveal(anchor: Vector2, free: Rect2) -> void:
	var size: Vector2 = view_size()
	var center: Vector2 = reveal_center(position, zoom.x, size, anchor, free,
		float(UiTokens.SPACE_6))
	if center == position:
		return
	_stop_inertia()
	var seconds: float = UiTokens.duration(UiTokens.MOTION_PANEL)
	if seconds <= 0.0:
		_stop_tween()
		set_view(center, zoom.x)
		return
	_tween_to(center, zoom.x, seconds)


## The centre a running tween is heading for, or the current one.
func target_center() -> Vector2:
	return _target_center if _is_tweening() else position


## The zoom a running tween is heading for, or the current one.
func target_zoom() -> float:
	return _target_zoom if _is_tweening() else zoom.x


## Tweens the centre onto a region's anchor (§7.5). An index the content does
## not know, or no content at all, is ignored.
func focus_region(index: int) -> void:
	var anchor: Vector2i = _anchor_of(index)
	if anchor == Vector2i(-1, -1):
		return
	_stop_inertia()
	var seconds: float = UiTokens.duration(UiTokens.MOTION_PANEL)
	if seconds <= 0.0:
		_stop_tween()
		set_view(Vector2(anchor), zoom.x)
		return
	_tween_to(clamp_center(Vector2(anchor), zoom.x, view_size()), zoom.x, seconds)


## True while a drag is moving the map — `MapView` does not hover then.
func is_panning() -> bool:
	return _panning


## Handles one pointer event and says whether it was the map's. Public so that a
## test can drive the gestures without going through the input dispatch.
func handle_pointer(event: InputEvent) -> bool:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null:
		return _handle_button(button)
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		return _handle_motion(motion)
	var magnify: InputEventMagnifyGesture = event as InputEventMagnifyGesture
	if magnify != null:
		# Pinch: continuous and never tweened, so the map tracks the fingers.
		zoom_by(magnify.factor, magnify.position, false)
		return true
	return false


# ----------------------------------------------------------------- gestures


func _handle_button(button: InputEventMouseButton) -> bool:
	match button.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if button.pressed:
				zoom_by(ZOOM_STEP, button.position, true)
			return true
		MOUSE_BUTTON_WHEEL_DOWN:
			if button.pressed:
				zoom_by(1.0 / ZOOM_STEP, button.position, true)
			return true
		MOUSE_BUTTON_LEFT:
			if button.pressed:
				_begin_pan(button.position)
			else:
				_end_pan(button.position)
			return true
	return false


func _handle_motion(motion: InputEventMouseMotion) -> bool:
	if not _panning:
		return false
	set_view(position - motion.relative / zoom.x, zoom.x)
	_velocity_samples.append(motion.velocity)
	if _velocity_samples.size() > VELOCITY_FRAMES:
		_velocity_samples.remove_at(0)
	return true


func _begin_pan(screen: Vector2) -> void:
	_panning = true
	_press_screen = screen
	_velocity_samples.clear()
	_stop_inertia()
	# A tween still running would fight the finger.
	_stop_tween()


## §7.4: a tap is a release under `DRAG_SLOP_PX` **from the press**. It used to
## be the length of the path walked in between, which a hand that shakes while
## it clicks exceeds without the pointer ever leaving the target — S3.P item 8,
## where an anomaly marker sometimes swallowed a click without collecting.
func _end_pan(screen: Vector2) -> void:
	if not _panning:
		return
	_panning = false
	if screen.distance_to(_press_screen) < DRAG_SLOP_PX:
		_dispatch_tap(screen)
		return
	_velocity = _mean_velocity()


func _mean_velocity() -> Vector2:
	if _velocity_samples.is_empty():
		return Vector2.ZERO
	var sum: Vector2 = Vector2.ZERO
	for sample: Vector2 in _velocity_samples:
		sum += sample
	return sum / float(_velocity_samples.size())


func _advance_inertia(delta: float) -> void:
	if _velocity == Vector2.ZERO:
		return
	if _velocity.length() < INERTIA_STOP_PX:
		_stop_inertia()
		return
	set_view(position - _velocity * delta / zoom.x, zoom.x)
	_velocity *= exp(-INERTIA_DECAY * delta)


func _stop_inertia() -> void:
	_velocity = Vector2.ZERO
	_velocity_samples.clear()


## §7.7: the layers above the map are asked first, in reverse tree order — the
## one drawn last is the one on top. Duck-typed on purpose: the camera must not
## name the layers, or the map's classes would name one another in a circle.
func _dispatch_tap(screen: Vector2) -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var siblings: Array[Node] = parent.get_children()
	for i: int in range(siblings.size() - 1, -1, -1):
		var sibling: Node = siblings[i]
		if sibling == self or not sibling.has_method(TAP_METHOD):
			continue
		if bool(sibling.call(TAP_METHOD, screen)):
			return


# ------------------------------------------------------------------ plumbing


func _key_pan() -> Vector2:
	var pan: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT):
		pan.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		pan.x += 1.0
	if Input.is_key_pressed(KEY_UP):
		pan.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN):
		pan.y += 1.0
	return pan


func _tween_to(center: Vector2, zoom_level: float, seconds: float) -> void:
	_stop_tween()
	var from_center: Vector2 = position
	var from_zoom: float = zoom.x
	_target_center = clamp_center(center, clampf(zoom_level, zoom_min, ZOOM_MAX),
		view_size())
	_target_zoom = clampf(zoom_level, zoom_min, ZOOM_MAX)
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_method(
		func(t: float) -> void:
			set_view(from_center.lerp(center, t), lerpf(from_zoom, zoom_level, t)),
		0.0, 1.0, seconds)


func _stop_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	_target_zoom = 0.0


## A tween that has finished is freed by the engine, so the target it carried
## stops counting on its own.
func _is_tweening() -> bool:
	return _target_zoom > 0.0 and _tween != null and _tween.is_valid()


func _anchor_of(index: int) -> Vector2i:
	if index <= 0 or Game.db == null or index >= Game.db.regions.size():
		return Vector2i(-1, -1)
	return Game.db.regions[index].anchor


func _on_region_selected(index: int) -> void:
	_selected_index = index


func _on_viewport_size_changed() -> void:
	zoom_min = zoom_min_for(view_size())
	set_view(position, zoom.x)
