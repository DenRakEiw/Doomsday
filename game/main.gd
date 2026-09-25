extends Control
## The entry point (spec m3-screens.md §7.0, `screens-full.md` §1): the backdrop
## that is always there, and the slot the router puts each screen in. A launch
## starts on the boot sequence.
##
## The root takes no pointer (`mouse_filter` ignore in `main.tscn`). It sits on
## the root canvas, which the session's map camera moves and scales, so a root
## that stopped the mouse caught every click and hover over the part of the
## screen its camera-transformed rectangle happened to cover — the map's taps
## never reached `MapCamera` there, and anomaly markers could not be collected
## (S6.P2).
##
## Scene-specific, so no `class_name`.

## release.md §8: `-- --smoke` plays a bot run in place of the boot.
const SmokeRun: GDScript = preload("res://game/smoke_run.gd")
## release.md §11.3: the start time, once per process, in every build — the perf
## wrapper reads it from the log.
const FIRST_SCREEN_LINE: String = "first screen %d"
## benchmark.md §12.3: `-- --spectate=<path>` watches that entry once the boot
## reaches the title. Debug builds only (release.md §7).
const ARG_SPECTATE: String = "--spectate="
const SPECTATE_FAILED: String = "spectate: %s"

static var _first_screen_logged: bool = false

## The entry `--spectate` names, until the title has shown.
var _spectate_path: String = ""

@onready var _slot: Control = %ScreenSlot


func _ready() -> void:
	# The title and the session share this theme; the session assigns its own on
	# top when the palette changes (§6.2).
	theme = ThemeBuilder.build(ThemeBuilder.VARIANT_COLD, Settings.text_scale)
	ScreenRouter.slot = _slot
	# §6.1: every screen lays out in logical pixels, not only the session.
	get_window().size_changed.connect(_on_window_size_changed)
	LogicalScale.apply(get_window())
	if OS.get_cmdline_user_args().has(SmokeRun.ARG):
		add_child(SmokeRun.new() as Node)
	else:
		_spectate_path = _arg_value(ARG_SPECTATE)
		if Game.debug_allowed and not _spectate_path.is_empty():
			ScreenRouter.screen_changed.connect(_on_router_screen_changed)
		ScreenRouter.boot()
	if not _first_screen_logged:
		_first_screen_logged = true
		RenderingServer.frame_post_draw.connect(_on_first_screen_drawn, CONNECT_ONE_SHOT)
	EventBus.text_scale_changed.connect(_on_text_scale_changed)


## The value of a `--name=value` switch after `--`, or "".
static func _arg_value(prefix: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return ""


## The first time the title shows, the file is read and watched; a file that
## does not read, or an entry the game cannot replay, prints why and leaves the
## title where it is.
func _on_router_screen_changed(screen: int) -> void:
	if screen != ScreenRouter.Screen.TITLE:
		return
	ScreenRouter.screen_changed.disconnect(_on_router_screen_changed)
	# Not inside the router's own signal: the switch would swap the title out
	# while the title is still being shown.
	_spectate.call_deferred(_spectate_path)


func _spectate(path: String) -> void:
	var entry: BenchEntry = BenchEntry.from_bytes(FileAccess.get_file_as_bytes(path))
	if entry == null:
		print(SPECTATE_FAILED % BenchEntry.last_error)
		return
	var reason: String = ScreenRouter.start_spectating(entry)
	if not reason.is_empty():
		print(SPECTATE_FAILED % reason)


## Milliseconds from the process's start to the first routed screen on screen.
func _on_first_screen_drawn() -> void:
	print(FIRST_SCREEN_LINE % Time.get_ticks_msec())


## UI.md §5: the settings the title opens can change the scale under it.
func _on_text_scale_changed(scale: float) -> void:
	theme = ThemeBuilder.build(ThemeBuilder.VARIANT_COLD, scale)


func _on_window_size_changed() -> void:
	LogicalScale.apply(get_window())
