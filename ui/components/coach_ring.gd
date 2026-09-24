class_name CoachRing
extends Control
## The ring the introduction draws around the control it is talking about
## (`first-run.md` §3.3).
##
## It lives on a layer of its own above the modals, so a ring inside the tech
## tree is seen. The target is named, not held: any visible control in the group
## `coach_<target>` is it, which is how the dock's button on a desk and the strip's
## menu on a phone answer to one name. No visible member — no ring.

const GROUP_PREFIX: String = "coach_"
# The names the introduction points at (§3.3); each control joins its group.
const TARGET_ORIGIN_BUTTON: String = "origin_button"
const TARGET_COMPUTE: String = "compute"
const TARGET_CAPABILITIES: String = "capabilities"
const TARGET_VECTOR: String = "vector"
const TARGET_OVERLAY: String = "overlay"
const TARGET_CONTAINMENT: String = "containment"
const TARGET_SITE_PROMPT: String = "site_prompt"
# Not rings: the two screens the introduction asks about ("is it open?").
const TARGET_TREE: String = "tree"
const TARGET_CONTAINMENT_PANEL: String = "containment_panel"
## How far outside the target the ring runs.
const OUTSET: float = 4.0
const ALPHA_LOW: float = 0.4

## The target's name without the prefix; "" draws nothing.
var target: String = "":
	set(value):
		target = value
		queue_redraw()

var _phase: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## The group a control joins to be `target_name`.
static func group(target_name: String) -> StringName:
	return StringName(GROUP_PREFIX + target_name)


## The control the ring would go round now, or null.
static func find(tree: SceneTree, target_name: String) -> Control:
	if target_name.is_empty():
		return null
	for node: Node in tree.get_nodes_in_group(group(target_name)):
		var control: Control = node as Control
		if control != null and control.is_visible_in_tree():
			return control
	return null


func _process(delta: float) -> void:
	if target.is_empty():
		return
	var period: float = UiTokens.seconds(UiTokens.PULSE_PERIOD)
	if period > 0.0:
		_phase = fmod(_phase + delta / period, 1.0)
	queue_redraw()


func _draw() -> void:
	var control: Control = find(get_tree(), target)
	if control == null:
		return
	var rect: Rect2 = control.get_global_rect().grow(OUTSET)
	rect.position -= get_global_rect().position
	var colour: Color = UiTokens.color(&"ACCENT")
	# A steady ring when motion is reduced; a slow pulse otherwise.
	if not UiTokens.reduced_motion():
		colour.a = lerpf(ALPHA_LOW, 1.0, 0.5 + 0.5 * sin(_phase * TAU))
	draw_rect(rect, colour, false, float(UiTokens.BORDER_FOCUS))
