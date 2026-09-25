extends GutTest
## S6.P1 — what sits beside an open side panel (D6.8): `Tab` leaves out a HUD
## zone the panel covers by more than half (the overlay picker under the region
## panel), and the site prompt centres in the width the panel leaves free. The
## session runs in a desktop-sized viewport of its own, because the layout
## follows the viewport it is in.

const SESSION: PackedScene = preload("res://game/session/session.tscn")
const SEED: int = 1
const ORIGIN: String = "usa"
const DESKTOP: Vector2i = Vector2i(1920, 1080)
const LARGE_TEXT: float = 1.5
const SETTLE_FRAMES: int = 4

var _viewport: SubViewport = null
var _session: Control = null
var _reduced_motion: bool = false
var _text_scale: float = 1.0


func before_each() -> void:
	_reduced_motion = Settings.reduced_motion
	_text_scale = Settings.text_scale
	Settings.reduced_motion = true
	Game.stop_run()
	Game.debug_log = false


func after_each() -> void:
	Settings.reduced_motion = _reduced_motion
	Settings.set_text_scale(_text_scale)
	Game.stop_run()


func _start_session() -> void:
	_viewport = SubViewport.new()
	_viewport.size = DESKTOP
	add_child_autofree(_viewport)
	_session = SESSION.instantiate() as Control
	_viewport.add_child(_session)
	Game.start_run(SEED)
	Game.set_speed(0)
	await wait_process_frames(SETTLE_FRAMES)


func _hud() -> Node:
	return _session.get_node("%Hud")


func _region_panel() -> SlidePanel:
	return _session.get_node("PanelLayer/RegionPanel") as SlidePanel


func _open_region_panel() -> void:
	EventBus.region_selected.emit(int(Game.db.region_index_by_id[ORIGIN]))
	await wait_process_frames(SETTLE_FRAMES)


func _chain() -> Array[Control]:
	return _session.call(&"focus_chain")


func _in_picker(picker: Control, controls: Array[Control]) -> int:
	var count: int = 0
	for control: Control in controls:
		if control == picker or picker.is_ancestor_of(control):
			count += 1
	return count


## Covert shows the picker's first two modes (overlay_picker.gd `apply_reveal`).
func _reveal_the_picker() -> Control:
	Game.site_confirm(ORIGIN)
	Game.set_speed(0)
	Game.sim.world.phase = World.Phase.COVERT
	_hud().call(&"apply_reveal")
	await wait_process_frames(SETTLE_FRAMES)
	return _hud().get_node("%OverlayPicker") as Control


func test_the_picker_is_in_the_ring_while_no_panel_covers_it() -> void:
	await _start_session()
	var picker: Control = await _reveal_the_picker()
	assert_true(picker.is_visible_in_tree())
	assert_gt(_in_picker(picker, _chain()), 0)


func test_tab_never_lands_on_the_picker_under_the_region_panel() -> void:
	await _start_session()
	var picker: Control = await _reveal_the_picker()
	await _open_region_panel()
	assert_true(_region_panel().is_open)
	assert_true(FocusRing.is_covered(picker.get_global_rect(),
		[_region_panel().covered_rect()] as Array[Rect2]), "the panel lies over it")
	var chain: Array[Control] = _chain()
	assert_eq(_in_picker(picker, chain), 0, "the covered zone is left out")
	var seen: Array[Control] = []
	for i: int in chain.size() + 1:
		var key: InputEventKey = InputEventKey.new()
		key.keycode = KEY_TAB
		key.physical_keycode = KEY_TAB
		key.pressed = true
		_session.call(&"_input", key)
		seen.append(_viewport.gui_get_focus_owner())
	assert_eq(_in_picker(picker, seen), 0, "a whole turn of Tab never lands there")


func test_the_site_prompt_sits_beside_the_region_panel_at_large_text() -> void:
	Settings.set_text_scale(LARGE_TEXT)
	await _start_session()
	await _open_region_panel()
	var prompt: Control = _hud().get_node("%SitePrompt") as Control
	assert_true(prompt.is_visible_in_tree(), "the origin is being chosen")
	assert_true(_region_panel().is_open)
	var panel_rect: Rect2 = _region_panel().covered_rect()
	var prompt_rect: Rect2 = prompt.get_global_rect()
	assert_false(prompt_rect.intersects(panel_rect), "never under the panel")
	var row: Control = prompt.get_parent() as Control
	var free_centre: float = (panel_rect.end.x + row.get_global_rect().end.x) * 0.5
	assert_almost_eq(prompt_rect.get_center().x, free_centre, 1.0,
		"centred in the width right of the panel")


func test_the_site_prompt_centres_on_the_hud_with_the_panel_closed() -> void:
	await _start_session()
	var prompt: Control = _hud().get_node("%SitePrompt") as Control
	assert_true(prompt.is_visible_in_tree())
	var row: Rect2 = (prompt.get_parent() as Control).get_global_rect()
	assert_almost_eq(prompt.get_global_rect().get_center().x, row.get_center().x, 1.0)
