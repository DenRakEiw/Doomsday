class_name ModalHost
extends Control
## The one child of `ModalLayer`: the scrim, the focus trap and the slot every
## modal is shown in (spec m3-screens.md §10.4).
##
## At most one modal is open. A second `open` while one is showing queues it —
## the discovery modal arriving while the tech tree is up waits for the tree to
## close rather than stacking on it.
##
## The host owns no content: a modal is any `Control`, and `Escape` is offered to
## it (`on_escape`) before the host closes it.

signal opened
signal closed

## The method a modal may have to answer `Escape` itself.
const METHOD_ESCAPE: StringName = &"on_escape"

var _scrim: ColorRect = null
## The red wash of §5, over everything, once.
var _alert: ColorRect = null
var _alert_tween: Tween = null
var _slot: Control = null
var _current: Control = null
var _queued: Array[Control] = []
## Whatever had focus before the modal took it.
var _previous_focus: Control = null
var _fade: Tween = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_set_shown(false)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)


## Shows `modal`, or queues it behind the one that is already up.
func open(modal: Control) -> void:
	if modal == null or modal == _current or _queued.has(modal):
		return
	if _current != null:
		_queued.append(modal)
		return
	_current = modal
	_previous_focus = get_viewport().gui_get_focus_owner()
	if modal.get_parent() != _slot:
		# A modal may be authored anywhere; the slot is where it is shown.
		if modal.get_parent() != null:
			modal.get_parent().remove_child(modal)
		_slot.add_child(modal)
	modal.visible = true
	_set_shown(true)
	_fade_to(1.0)
	_focus_first()
	opened.emit()


## Closes the modal that is up, and shows whatever was waiting behind it.
func close() -> void:
	if _current == null:
		return
	var closing: Control = _current
	_current = null
	# The modal stays in the slot, hidden: taking it out of the tree would strip
	# the `%` names of everything inside it and orphan the node.
	closing.visible = false
	_set_shown(false)
	_restore_focus()
	closed.emit()
	if not _queued.is_empty():
		var next: Control = _queued.pop_front()
		open(next)


## One red wash over the whole screen, fading out (§5). The host shows it even
## when no modal is open, because the flash is the moment and the modal is only
## what follows it. Reduced motion skips it entirely.
func flash_alert() -> void:
	if UiTokens.reduced_motion():
		return
	if _alert_tween != null and _alert_tween.is_valid():
		_alert_tween.kill()
	visible = true
	_alert.visible = true
	_alert.color = Color(UiTokens.color(&"ALERT"), UiTokens.ALERT_FLASH_ALPHA)
	_alert_tween = create_tween()
	_alert_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_alert_tween.tween_property(_alert, "color:a", 0.0,
		UiTokens.duration(UiTokens.MOTION_ALERT))
	_alert_tween.tween_callback(_end_flash)


func _end_flash() -> void:
	_alert.visible = false
	if _current == null:
		visible = false


func is_open() -> bool:
	return _current != null


func current() -> Control:
	return _current


func _unhandled_key_input(event: InputEvent) -> void:
	if _current == null:
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_ESCAPE:
		return
	get_viewport().set_input_as_handled()
	if _current.has_method(METHOD_ESCAPE):
		_current.call(METHOD_ESCAPE)
		return
	close()


func _build() -> void:
	_scrim = ColorRect.new()
	_scrim.name = "Scrim"
	_scrim.color = Color(UiTokens.color(&"BG_0"), UiTokens.SCRIM_ALPHA)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_scrim)
	_slot = Control.new()
	_slot.name = "Slot"
	_slot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_slot)
	_alert = ColorRect.new()
	_alert.name = "AlertFlash"
	_alert.color = Color(UiTokens.color(&"ALERT"), 0.0)
	_alert.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_alert.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alert.visible = false
	add_child(_alert)


## Nothing below the host receives anything while a modal is up (§1.1). The
## flash keeps the host visible on its own while it lasts.
func _set_shown(shown: bool) -> void:
	visible = shown or (_alert != null and _alert.visible)
	mouse_filter = Control.MOUSE_FILTER_STOP if shown else Control.MOUSE_FILTER_IGNORE


func _fade_to(target: float) -> void:
	var seconds: float = UiTokens.duration(UiTokens.MOTION_MODAL)
	if _fade != null and _fade.is_valid():
		_fade.kill()
	if seconds <= 0.0 or not is_inside_tree():
		modulate.a = target
		return
	modulate.a = 1.0 - target
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", target, seconds)


func _focus_first() -> void:
	var first: Control = _first_focusable(_current)
	if first != null:
		first.grab_focus()


func _restore_focus() -> void:
	if _previous_focus != null and is_instance_valid(_previous_focus) \
			and _previous_focus.is_inside_tree():
		_previous_focus.grab_focus()
	_previous_focus = null


## Tab wraps inside the modal: focus that lands outside it is sent back in.
func _on_focus_changed(control: Control) -> void:
	if _current == null or control == null:
		return
	if _current.is_ancestor_of(control) or control == _current:
		return
	_focus_first()


static func _first_focusable(root: Control) -> Control:
	if root == null:
		return null
	if root.focus_mode == Control.FOCUS_ALL and root.visible:
		return root
	for child: Node in root.get_children():
		var control: Control = child as Control
		if control == null or not control.visible:
			continue
		var found: Control = _first_focusable(control)
		if found != null:
			return found
	return null
