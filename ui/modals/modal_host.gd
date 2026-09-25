class_name ModalHost
extends Control
## The one child of `ModalLayer`: the scrim, the focus trap and the slot every
## modal is shown in (spec m3-screens.md §10.4).
##
## At most one modal is open. A second `open` while one is showing queues it —
## the discovery modal arriving while the tech tree is up waits for the tree to
## close rather than stacking on it. The one exception is `open_over`
## (`first-run.md` §6.8): one level of stacking, for help over whatever is up.
##
## The host owns no content: a modal is any `Control`, and `Escape` is offered to
## it (`on_escape`) before the host closes it.

signal opened
signal closed

## The method a modal may have to answer `Escape` itself.
const METHOD_ESCAPE: StringName = &"on_escape"
## audio.md §7.1: the two `call` triggers of the sheet.
const CUE_OPEN: StringName = &"ui_open"
const CUE_CLOSE: StringName = &"ui_close"

var _scrim: ColorRect = null
var _slot: Control = null
var _current: Control = null
var _queued: Array[Control] = []
## Whatever had focus before the modal took it.
var _previous_focus: Control = null
## The modal under the current one (`open_over`), still showing, and what had
## the focus in it.
var _below: Control = null
var _below_focus: Control = null
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
	Audio.cue(CUE_OPEN)
	opened.emit()


## Shows `modal` on top of the one that is up, which stays visible and becomes
## current again when `modal` closes (§6.8). With nothing up it is `open`; with
## two up already it queues like `open`.
func open_over(modal: Control) -> void:
	if modal == null or modal == _current or _queued.has(modal):
		return
	if _current == null or _below != null:
		open(modal)
		return
	_below = _current
	_below_focus = get_viewport().gui_get_focus_owner()
	_current = modal
	if modal.get_parent() != _slot:
		if modal.get_parent() != null:
			modal.get_parent().remove_child(modal)
		_slot.add_child(modal)
	# Drawn last, so above the one it covers.
	_slot.move_child(modal, -1)
	modal.visible = true
	_focus_first()
	Audio.cue(CUE_OPEN)
	opened.emit()


## The modal under the current one, or null.
func below() -> Control:
	return _below


## Closes the modal that is up, and shows whatever was waiting behind it.
func close() -> void:
	if _current == null:
		return
	var closing: Control = _current
	# The modal stays in the slot, hidden: taking it out of the tree would strip
	# the `%` names of everything inside it and orphan the node.
	closing.visible = false
	if _below != null:
		# §6.8: the one below is current again; the queue waits until nothing is.
		_current = _below
		_below = null
		var focus: Control = _below_focus
		_below_focus = null
		var valid: bool = focus != null and is_instance_valid(focus)
		if valid and focus.is_inside_tree() and _current.is_ancestor_of(focus):
			focus.grab_focus()
		else:
			_focus_first()
		Audio.cue(CUE_CLOSE)
		closed.emit()
		return
	_current = null
	_set_shown(false)
	_restore_focus()
	Audio.cue(CUE_CLOSE)
	closed.emit()
	if not _queued.is_empty():
		var next: Control = _queued.pop_front()
		open(next)


## One red wash over the whole screen, fading out (§5). Since S6.1 it is drawn
## by the full-screen pass (polish-visuals.md §4.2), so that every full-screen
## flash passes one photosensitivity guard; reduced motion still skips it.
func flash_alert() -> void:
	ScreenFx.flash_alert()


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


## Nothing below the host receives anything while a modal is up (§1.1).
func _set_shown(shown: bool) -> void:
	visible = shown
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
	# A screen swap can take the modal out of the tree while focus still moves.
	if first != null and first.is_inside_tree():
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
