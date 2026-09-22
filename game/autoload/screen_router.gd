extends Node
## Which screen is on (spec m3-screens.md §7.0).
##
## The title and the session are two scenes in one slot. The router owns the
## switch and nothing else: it starts and stops runs through `Game`, and it never
## reaches into either screen.
##
## The session scene stays exactly what it is, so running it directly still
## works — the router is only the way the shipped flow reaches it.
##
## An autoload, so no `class_name`.

enum Screen { TITLE, SESSION }

signal screen_changed(screen: Screen)
## A load the title asked for failed; the title shows the reason.
signal load_failed(reason: String)

const TITLE_SCENE: String = "res://ui/screens/title.tscn"
const SESSION_SCENE: String = "res://game/session/session.tscn"

var current: Screen = Screen.TITLE

## Set by `main.gd` when it is ready; without it the router only remembers where
## it would have gone, which is what a test that has no `Main` wants.
var slot: Node = null

var _screen_node: Node = null


func go_to_title() -> void:
	# The run is written down before it is dropped: Continue on the title is the
	# same save the pause menu's Quit left behind (§7.5).
	if Game.sim != null and Game.policy == null and Game.sim.world.agent.origin != 0 \
			and Game.sim.world.outcome == World.Outcome.NONE:
		SaveManager.save(SaveManager.AUTOSAVE)
	Game.stop_run()
	_show(Screen.TITLE)


## The session first, then the run: the screen has to be in the tree to hear
## `run_started`, which is what takes the origin hold and lays the HUD out.
func start_new_run() -> void:
	_show(Screen.SESSION)
	Game.start_run(Game.new_run_seed())


## Picks the autosave up. The screen only changes when the load worked.
func continue_run() -> void:
	_show(Screen.SESSION)
	var reason: String = SaveManager.load(SaveManager.AUTOSAVE)
	if reason.is_empty():
		return
	load_failed.emit(reason)
	_show(Screen.TITLE)


func show_session() -> void:
	_show(Screen.SESSION)


func screen_node() -> Node:
	return _screen_node


## Swaps the scene in the slot. A router without a slot — a test, a scene run
## directly — only records where it is.
func _show(screen: Screen) -> void:
	current = screen
	if slot != null:
		_swap(TITLE_SCENE if screen == Screen.TITLE else SESSION_SCENE)
	screen_changed.emit(screen)


func _swap(path: String) -> void:
	if _screen_node != null:
		slot.remove_child(_screen_node)
		_screen_node.queue_free()
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		push_error("screen_router: %s is not a scene" % path)
		return
	_screen_node = scene.instantiate()
	slot.add_child(_screen_node)
	_fade_in(_screen_node as Control)


## §7.0: the incoming screen fades in. Reduced motion cuts.
static func _fade_in(screen: Control) -> void:
	if screen == null:
		return
	var seconds: float = UiTokens.duration(UiTokens.MOTION_MODAL)
	if seconds <= 0.0:
		screen.modulate.a = 1.0
		return
	screen.modulate.a = 0.0
	screen.create_tween().tween_property(screen, "modulate:a", 1.0, seconds)
