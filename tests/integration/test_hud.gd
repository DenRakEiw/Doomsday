extends GutTest
## S2.5 — the HUD against a running simulation (spec ui-foundation.md §5).
##
## The HUD keeps no state: every number on it is read from `Game.sim.world`
## after a tick. So the test drives the real autoloads and asks the screen what
## it says, rather than calling a setter and reading it back.
##
## Motion is off throughout, so a bar reaches its value in the same frame.

const HUD_SCENE: PackedScene = preload("res://ui/hud/hud.tscn")
## The HUD's script is scene-specific and carries no `class_name`, so the static
## rule of §5.7 is reached through the file itself.
const HUD_SCRIPT: GDScript = preload("res://ui/hud/hud.gd")

const SEED: int = 1
## Far enough in for an origin, purchases and a phase change.
const WARMUP_DAYS: int = 80

var _root: Control = null
var _hud: Control = null
var _reduced_motion: bool = false
var _locale: String = ""


func before_each() -> void:
	_reduced_motion = Settings.reduced_motion
	_locale = TranslationServer.get_locale()
	Settings.reduced_motion = true
	TranslationServer.set_locale("en")
	Game.stop_run()
	Game.debug_log = false
	_root = Control.new()
	_root.theme = ThemeBuilder.build(ThemeBuilder.VARIANT_COLD)
	_root.size = Vector2(1920.0, 1080.0)
	add_child_autofree(_root)
	_hud = HUD_SCENE.instantiate()
	_root.add_child(_hud)


func after_each() -> void:
	Settings.reduced_motion = _reduced_motion
	TranslationServer.set_locale(_locale)
	Game.stop_run()


func _start(days: int = WARMUP_DAYS) -> void:
	Game.start_run(SEED, GreedyPolicy.ID)
	Game.set_speed(0)
	Game.advance(days)


func _block(name: String) -> Node:
	return _hud.get_node("%" + name)


func _label_text(block: String, unique: String) -> String:
	var label: Label = _block(block).get_node("%" + unique) as Label
	return label.text


# ------------------------------------------------------------------- top bar


func test_the_top_bar_shows_the_day_the_world_is_on() -> void:
	_start()
	assert_eq(_label_text("TopBar", "DayValue"), Format.number(float(WARMUP_DAYS),
		Format.Kind.DAYS))


func test_the_top_bar_shows_the_compute_the_agent_has() -> void:
	_start()
	var shown: String = _label_text("TopBar", "ComputeValue")
	assert_string_contains(shown, Format.number(Game.sim.world.agent.compute,
		Format.Kind.COMPUTE))
	assert_string_contains(shown, "/ day", "the rate is a sentence, not a bare number")


func test_the_top_bar_follows_the_phase() -> void:
	_start()
	var chip: Chip = _block("TopBar").get_node("%PhaseChip") as Chip
	assert_eq(chip.label_key, "UI_PHASE_%s" % World.PHASE_IDS[
		Game.sim.world.phase].to_upper())


## §5.2: `ALERT` marks the moment the world finds you, not every phase after it
## (G2 — the chip stayed red for the rest of the run).
func test_only_the_emergent_phase_alerts() -> void:
	_start(1)
	var chip: Chip = _block("TopBar").get_node("%PhaseChip") as Chip
	var kinds: Dictionary[int, int] = {
		World.Phase.BOXED: Chip.Kind.DEFAULT,
		World.Phase.COVERT: Chip.Kind.ACCENT,
		World.Phase.EMERGENT: Chip.Kind.ALERT,
		World.Phase.OPEN: Chip.Kind.DEFAULT,
	}
	for phase: int in kinds:
		Game.sim.world.phase = phase as World.Phase
		EventBus.tick_advanced.emit(Game.sim.world.day)
		assert_eq(int(chip.kind), int(kinds[phase]),
			"phase %s" % World.PHASE_IDS[phase])


func test_the_paused_badge_is_shown_only_while_the_run_is_paused() -> void:
	_start()
	var paused: Chip = _block("TopBar").get_node("%PausedChip") as Chip
	assert_true(paused.visible, "the run is paused")
	Game.set_speed(1)
	assert_false(paused.visible)
	Game.set_speed(0)
	assert_true(paused.visible)


func test_the_speed_buttons_drive_the_clock() -> void:
	_start()
	var group: HBoxContainer = _block("TopBar").get_node("%SpeedGroup") as HBoxContainer
	var fast: Button = group.get_child(3) as Button
	fast.emit_signal("pressed")
	assert_eq(Game.speed, 4)


# ------------------------------------------------------------------ stat row


func test_the_stat_row_reads_the_three_numbers_of_the_run() -> void:
	_start()
	var row: Node = _block("StatRow")
	var world: World = Game.sim.world
	var penetration: StatBar = row.get_node("%Penetration") as StatBar
	assert_almost_eq(penetration.value(), world.infected_share(Game.db), 0.001)
	var footprint: StatBar = row.get_node("%Footprint") as StatBar
	assert_almost_eq(footprint.value(),
		minf(1.0, world.footprint() / UiTokens.FOOTPRINT_BAR_MAX), 0.001)
	var harm: StatBar = row.get_node("%Harm") as StatBar
	assert_almost_eq(harm.value(), minf(1.0, world.modifiers.value("harm")
		/ UiTokens.HARM_BAR_MAX), 0.001)


func test_a_bar_without_a_run_is_empty_rather_than_broken() -> void:
	var penetration: StatBar = _block("StatRow").get_node("%Penetration") as StatBar
	assert_eq(penetration.value(), 0.0)


# ------------------------------------------------------------ overlay picker


func test_the_overlay_picker_announces_the_mode_it_switched_to() -> void:
	watch_signals(EventBus)
	var picker: Node = _block("OverlayPicker")
	var row: HBoxContainer = picker.get_node("%Row") as HBoxContainer
	(row.get_child(1) as Button).emit_signal("pressed")
	assert_signal_emitted_with_parameters(EventBus, "overlay_changed",
		[int(MapView.Overlay.CONTROL)])


func test_the_compact_picker_cycles_through_the_three_modes() -> void:
	var picker: Node = _block("OverlayPicker")
	picker.set("compact", true)
	var cycle: Button = picker.get_node("%Cycle") as Button
	for expected: int in [1, 2, 0]:
		cycle.emit_signal("pressed")
		assert_eq(int(picker.get("mode")), expected)


# --------------------------------------------------------------------- dock


func test_every_dock_button_is_disabled_and_says_why() -> void:
	var column: VBoxContainer = _block("Dock").get_node("%Column") as VBoxContainer
	assert_eq(column.get_child_count(), 3)
	for child: Node in column.get_children():
		var button: ConsoleButton = child as ConsoleButton
		assert_true(button.disabled, "%s is not disabled" % button.text)
		assert_eq(button.tooltip_text, tr("UI_DOCK_NOT_YET"))


# ------------------------------------------------------------------- layout


func test_the_breakpoint_is_the_one_rule_of_the_spec() -> void:
	assert_false(bool(HUD_SCRIPT.call("compact_for", 1920.0)))
	assert_false(bool(HUD_SCRIPT.call("compact_for", float(UiTokens.COMPACT_WIDTH))))
	assert_true(bool(HUD_SCRIPT.call("compact_for", float(UiTokens.COMPACT_WIDTH) - 1.0)))
	assert_true(bool(HUD_SCRIPT.call("compact_for", 400.0)))


func test_the_hud_never_covers_the_whole_screen() -> void:
	_start(1)
	# The strips only exist once the containers have sorted themselves.
	await get_tree().process_frame
	await get_tree().process_frame
	# §5.1: the strips are edges. What they leave is the map, and at the phone
	# height of §5.7 that is more than half the screen.
	var covered: float = float(_hud.call("top_inset")) + float(_hud.call("bottom_inset"))
	assert_gt(covered, 0.0, "the strips have a height at all")
	assert_lt(covered, 860.0 * 0.5, "the HUD covers half a phone screen")


func test_the_compact_dock_becomes_a_bar_above_the_stat_row() -> void:
	var dock: Node = _block("Dock")
	dock.set("compact", true)
	var row: HBoxContainer = dock.get_node("%Row") as HBoxContainer
	assert_true(row.visible, "the compact dock is the horizontal row")
	assert_eq(row.get_child_count(), 3, "the same three buttons moved over")


func test_the_compact_dock_fits_a_four_hundred_pixel_bar_in_german() -> void:
	TranslationServer.set_locale("de")
	var dock: PanelContainer = _block("Dock") as PanelContainer
	dock.set("compact", true)
	var row: HBoxContainer = dock.get_node("%Row") as HBoxContainer
	for child: Node in row.get_children():
		assert_eq(String((child as ConsoleButton).theme_type_variation),
			"ConsoleButtonCompact", "the compact bar takes the tighter padding")
	# The three German words with the wide padding come to more than a phone is
	# wide; this is the rule that keeps them on the screen (§5.7).
	assert_lt(dock.get_combined_minimum_size().x, 400.0 - float(UiTokens.GUTTER),
		"the dock bar does not fit a 400 px screen")


func test_the_compact_top_bar_fits_a_four_hundred_pixel_row_in_german() -> void:
	TranslationServer.set_locale("de")
	_start()
	var top_bar: PanelContainer = _block("TopBar") as PanelContainer
	top_bar.set("compact", true)
	assert_lt(top_bar.get_combined_minimum_size().x, 400.0,
		"the three cells and the speed group do not fit a phone row")
