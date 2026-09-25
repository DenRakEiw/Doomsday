extends GutTest
## S6.8 — which control `Tab` goes to next (accessibility.md §4.3).


func _button(parent: Node, label: String) -> Button:
	var button: Button = Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_ALL
	parent.add_child(button)
	return button


func _root() -> VBoxContainer:
	var root: VBoxContainer = VBoxContainer.new()
	add_child_autofree(root)
	return root


func test_collect_skips_hidden_unfocusable_and_disabled() -> void:
	var root: VBoxContainer = _root()
	var kept: Button = _button(root, "kept")
	_button(root, "hidden").visible = false
	_button(root, "none").focus_mode = Control.FOCUS_NONE
	_button(root, "click").focus_mode = Control.FOCUS_CLICK
	_button(root, "disabled").disabled = true
	var inside_hidden: VBoxContainer = VBoxContainer.new()
	inside_hidden.visible = false
	root.add_child(inside_hidden)
	_button(inside_hidden, "under a hidden parent")
	var roots: Array[Control] = [root]
	assert_eq(FocusRing.collect(roots), [kept] as Array[Control])


func test_collect_keeps_tree_order_across_roots() -> void:
	var first: VBoxContainer = _root()
	var second: VBoxContainer = _root()
	var c: Button = _button(second, "c")
	var a: Button = _button(first, "a")
	var inner: HBoxContainer = HBoxContainer.new()
	first.add_child(inner)
	var b: Button = _button(inner, "b")
	var roots: Array[Control] = [first, second]
	assert_eq(FocusRing.collect(roots), [a, b, c] as Array[Control])


func test_a_hidden_root_contributes_nothing() -> void:
	var root: VBoxContainer = _root()
	_button(root, "a")
	root.visible = false
	var roots: Array[Control] = [root]
	assert_eq(FocusRing.collect(roots).size(), 0)


func test_next_wraps_both_ways() -> void:
	var root: VBoxContainer = _root()
	var a: Button = _button(root, "a")
	var b: Button = _button(root, "b")
	var chain: Array[Control] = [a, b]
	assert_eq(FocusRing.next(chain, a, false), b)
	assert_eq(FocusRing.next(chain, b, false), a, "past the last to the first")
	assert_eq(FocusRing.next(chain, a, true), b, "before the first to the last")


func test_a_current_outside_goes_to_the_first_or_the_last() -> void:
	var root: VBoxContainer = _root()
	var a: Button = _button(root, "a")
	var b: Button = _button(root, "b")
	var outside: Button = _button(_root(), "outside")
	var chain: Array[Control] = [a, b]
	assert_eq(FocusRing.next(chain, outside, false), a)
	assert_eq(FocusRing.next(chain, outside, true), b)
	assert_eq(FocusRing.next(chain, null, false), a)


func test_an_empty_chain_gives_null() -> void:
	var chain: Array[Control] = []
	assert_null(FocusRing.next(chain, null, false))
