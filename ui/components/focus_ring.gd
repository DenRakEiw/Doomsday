class_name FocusRing
extends RefCounted
## Which control `Tab` goes to next (spec accessibility.md §4.3).
##
## Godot's own `Tab` does not cross `CanvasLayer`s: each layer's controls wrap
## among themselves. The session and the modal host therefore walk a ring of
## their own, built here from the roots they name, in the order they name them.
##
## Pure: it reads the tree it is given and changes nothing.


## The controls `Tab` walks, in order: every descendant of each root, in tree
## order, that is visible in the tree, has `focus_mode` `FOCUS_ALL` and is not a
## disabled `BaseButton`. A root counts too.
static func collect(roots: Array[Control]) -> Array[Control]:
	var out: Array[Control] = []
	for root: Control in roots:
		if root == null or not is_instance_valid(root) or not root.is_visible_in_tree():
			continue
		_collect(root, out)
	return out


## The next (or previous) control after `current`, wrapping; `current` not in
## the list → the first (or last). Empty list → null.
static func next(chain: Array[Control], current: Control, backwards: bool) -> Control:
	if chain.is_empty():
		return null
	var at: int = chain.find(current) if current != null else -1
	if at < 0:
		return chain.back() if backwards else chain.front()
	var step: int = -1 if backwards else 1
	return chain[posmod(at + step, chain.size())]


## Whether `control` takes a `Tab` stop.
static func is_stop(control: Control) -> bool:
	if control.focus_mode != Control.FOCUS_ALL or not control.is_visible_in_tree():
		return false
	var button: BaseButton = control as BaseButton
	return button == null or not button.disabled


static func _collect(control: Control, out: Array[Control]) -> void:
	if not control.visible:
		return
	if is_stop(control):
		out.append(control)
	for child: Node in control.get_children():
		var sub: Control = child as Control
		if sub != null:
			_collect(sub, out)
