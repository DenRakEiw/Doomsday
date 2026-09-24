extends Node
## Which screen is on (spec m3-screens.md §7.0, `screens-full.md` §1).
##
## Boot, title, setup and session are four scenes in one slot. The router owns
## the switch and nothing else: it starts and stops runs through `Game`, and it
## never reaches into a screen.
##
## The session scene stays exactly what it is, so running it directly still
## works — the router is only the way the shipped flow reaches it.
##
## An autoload, so no `class_name`.

enum Screen { BOOT, TITLE, SETUP, SESSION }

signal screen_changed(screen: Screen)
## A load the title asked for failed; the title shows the reason.
signal load_failed(reason: String)

const BOOT_SCENE: String = "res://ui/screens/boot.tscn"
const TITLE_SCENE: String = "res://ui/screens/title.tscn"
const SETUP_SCENE: String = "res://ui/screens/setup.tscn"
const SESSION_SCENE: String = "res://game/session/session.tscn"
const SCENES: Dictionary[Screen, String] = {
	Screen.BOOT: BOOT_SCENE,
	Screen.TITLE: TITLE_SCENE,
	Screen.SETUP: SETUP_SCENE,
	Screen.SESSION: SESSION_SCENE,
}

var current: Screen = Screen.TITLE

## What the setup screen opens on (§4): a seed carried in from Statistics (0 =
## a new random one at Begin) and the setup to preselect (null = the profile's
## last one). The setup screen reads both when it is built.
var setup_seed: int = 0
var setup_preset: RunSetup = null

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


## The first screen of a launch (§2). The boot screen goes on to the title.
func boot() -> void:
	_show(Screen.BOOT)


## §4: the two setup pages. `seed_value` 0 means a new random seed at Begin;
## `preset` null means the profile's last setup.
func show_setup(seed_value: int = 0, preset: RunSetup = null) -> void:
	setup_seed = maxi(0, seed_value)
	setup_preset = preset
	_show(Screen.SETUP)


## The session first, then the run: the screen has to be in the tree to hear
## `run_started`, which is what takes the origin hold and lays the HUD out.
## Without a setup it is the profile's last one — the results' *Again* is the
## same build on a new seed (§1). `seed_value` 0 draws a new seed.
func start_new_run(setup: RunSetup = null, seed_value: int = 0) -> void:
	var chosen: RunSetup = setup if setup != null else ProfileManager.last_setup
	Game.next_setup = chosen.duplicate_setup()
	_show(Screen.SESSION)
	Game.start_run(seed_value if seed_value > 0 else Game.new_run_seed(), "", Game.next_setup)


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
		_swap(SCENES[screen])
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
