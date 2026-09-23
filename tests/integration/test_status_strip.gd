extends GutTest
## S3.4 — the phone's bottom (spec m3-screens.md §9).
##
## The rule it has to keep is a number: at 400 × 860 the chrome below the map is
## a 56 px strip and a 40 px ticker, and the bars are one tap away.

const SESSION: PackedScene = preload("res://game/session/session.tscn")
const SEED: int = 1

var _session: Control = null
var _hud: Control = null
var _strip: PanelContainer = null
var _sheet: SlidePanel = null
var _reduced_motion: bool = false


func before_each() -> void:
	_reduced_motion = Settings.reduced_motion
	Settings.set_reduced_motion(true)
	Game.stop_run()
	Game.debug_log = false
	_session = SESSION.instantiate()
	add_child_autofree(_session)
	_hud = _session.get_node("HudLayer/SafeArea/Hud")
	_strip = _hud.get_node("%StatusStrip")
	_sheet = _session.get_node("PanelLayer/MenuSheet")


func after_each() -> void:
	Settings.set_reduced_motion(_reduced_motion)
	Game.stop_run()


func _start() -> void:
	Game.start_run(SEED)
	Game.apply(ChooseOriginCommand.new(Game.db.regions[1].id))


## The HUD switches on the viewport's width, which a headless run cannot change
## — so the test drives the switch the way the resize would.
func _set_layout(compact: bool) -> void:
	_hud.set(&"_compact", compact)
	_hud.set(&"_has_layout", false)
	_hud.call(&"_apply_layout_for", compact)


func test_compact_bottom_is_strip_plus_ticker() -> void:
	_start()
	_set_layout(true)
	assert_true(_strip.visible, "the strip is the phone's stat row")
	assert_false((_hud.get_node("%DockBar") as Control).visible,
		"and the dock bar is gone with it")
	assert_eq(int(_strip.custom_minimum_size.y), UiTokens.STATUS_STRIP_HEIGHT)
	# The suite runs with reduced motion on, where a standing line gets two rows
	# (ticker.md §4.5); §9.1's 40 px is the moving one.
	Settings.set_reduced_motion(false)
	assert_eq(int((_hud.get_node("%Ticker") as Control).custom_minimum_size.y),
		UiTokens.TICKER_HEIGHT)


func test_the_sheet_holds_the_bars_and_the_destinations() -> void:
	_start()
	_set_layout(true)
	var slot: VBoxContainer = _sheet.get_node("%BarsSlot") as VBoxContainer
	assert_eq(slot.get_child_count(), 1, "the sheet borrows the stat row itself")
	var destinations: VBoxContainer = _sheet.get_node("%Destinations") as VBoxContainer
	assert_eq(destinations.get_child_count(), 3)
	assert_true((_sheet.get_node("%PauseEntry") as Control).visible,
		"and the way into the pause menu")


func test_the_strip_opens_the_sheet() -> void:
	_start()
	_set_layout(true)
	assert_false(_sheet.is_open)
	_strip.emit_signal("menu_requested")
	assert_true(_sheet.is_open)


func test_the_full_layout_takes_its_bars_back() -> void:
	_start()
	var row: Control = _hud.get_node("%StatRow") as Control
	var home: Node = row.get_parent()
	var index: int = row.get_index()
	_set_layout(true)
	_set_layout(false)
	var slot: VBoxContainer = _sheet.get_node("%BarsSlot") as VBoxContainer
	assert_eq(slot.get_child_count(), 0)
	assert_true(row.visible)
	assert_eq(row.get_parent(), home)
	assert_eq(row.get_index(), index, "and above the ticker, where it was")
