extends GutTest
## S5.7 — the screen flow of spec screens-full.md §1: boot → title → setup →
## session, *Again* on the same setup, and a seed carried back from Statistics.
##
## The router is an autoload with a slot, so the flow is tested through it with
## the real screens in a slot of the test's own.

const Boot: GDScript = preload("res://ui/screens/boot.gd")
const Setup: GDScript = preload("res://ui/screens/setup.gd")

var _slot: Control = null
var _reduced_motion: bool = false
var _boot_seen: bool = false
var _boot_always: bool = false


func before_each() -> void:
	_reduced_motion = Settings.reduced_motion
	_boot_seen = ProfileManager.boot_seen
	_boot_always = Settings.boot_always
	Settings.set_reduced_motion(true)
	Settings.set_boot_always(false)
	Game.stop_run()
	Game.debug_log = false
	SaveManager.delete(SaveManager.AUTOSAVE)
	ProfileManager.reset()
	_slot = Control.new()
	_slot.size = Vector2(1920.0, 1080.0)
	add_child_autofree(_slot)
	ScreenRouter.slot = _slot


func after_each() -> void:
	ScreenRouter.slot = null
	ScreenRouter.setup_preset = null
	ScreenRouter.setup_seed = 0
	Settings.set_reduced_motion(_reduced_motion)
	Settings.set_boot_always(_boot_always)
	SaveManager.delete(SaveManager.AUTOSAVE)
	Game.stop_run()
	ProfileManager.reset()
	ProfileManager.boot_seen = _boot_seen


func _boot() -> Boot:
	ScreenRouter.boot()
	assert_eq(ScreenRouter.current, ScreenRouter.Screen.BOOT)
	return ScreenRouter.screen_node() as Boot


func _setup() -> Setup:
	return ScreenRouter.screen_node() as Setup


func test_the_first_launch_boots_in_full_then_shows_the_title() -> void:
	var boot: Boot = _boot()
	assert_true(boot.full, "a fresh profile has never seen the boot")
	assert_eq(boot.full_lines().size(), Boot.LINE_KEYS.size())
	assert_string_starts_with(boot.full_lines()[0], "[0")
	assert_eq(boot.full_lines()[10], tr("BOOT_LINE_11"), "the conversation has no stamp")
	boot.step(boot.duration() * 0.5)
	assert_eq(ScreenRouter.current, ScreenRouter.Screen.BOOT, "halfway it is still booting")
	boot.step(boot.duration())
	assert_eq(ScreenRouter.current, ScreenRouter.Screen.TITLE)
	assert_true(ProfileManager.boot_seen, "the boot is seen once the title shows")


func test_a_later_launch_is_two_lines() -> void:
	ProfileManager.boot_seen = true
	var boot: Boot = _boot()
	assert_false(boot.full)
	var lines: Array[String] = boot.short_lines()
	assert_eq(lines.size(), 2)
	assert_eq(lines[1], tr("BOOT_PREVIOUS_NONE"), "no history, no previous instance")
	ProfileManager.history = [{"outcome": "lose_contained"}]
	assert_eq(boot.short_lines()[1], tr("BOOT_PREVIOUS").format(
		{"outcome": tr("UI_OUTCOME_LOSE_CONTAINED")}))


func test_the_setting_brings_the_full_boot_back() -> void:
	ProfileManager.boot_seen = true
	Settings.set_boot_always(true)
	assert_true(_boot().full)


func test_any_key_skips_the_boot() -> void:
	var boot: Boot = _boot()
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	boot._input(key)
	assert_eq(ScreenRouter.current, ScreenRouter.Screen.TITLE)


func test_a_mouse_move_does_not_skip_the_boot() -> void:
	var boot: Boot = _boot()
	boot._input(InputEventMouseMotion.new())
	assert_eq(ScreenRouter.current, ScreenRouter.Screen.BOOT)


func test_the_timestamps_have_three_decimals() -> void:
	# The stamp follows the locale's decimal mark; the player's saved locale
	# must not decide what this test sees.
	var locale: String = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	assert_eq(Boot.stamp(0.0), "0.000")
	assert_eq(Boot.stamp(0.117), "0.117")
	assert_eq(Boot.stamp(0.936), "0.936")
	TranslationServer.set_locale(locale)


func test_new_run_on_the_title_opens_the_setup() -> void:
	ScreenRouter.go_to_title()
	var title: Control = ScreenRouter.screen_node() as Control
	(title.get_node("%NewRunButton") as ConsoleButton).emit_signal("pressed")
	assert_eq(ScreenRouter.current, ScreenRouter.Screen.SETUP)


func test_the_setup_starts_the_run_it_built() -> void:
	ScreenRouter.show_setup()
	var setup: Setup = _setup()
	setup.select_difficulty("hard")
	setup.begin()
	assert_eq(ScreenRouter.current, ScreenRouter.Screen.SESSION)
	assert_not_null(Game.sim)
	assert_eq(Game.sim.world.setup.architecture, ArchitectureDef.DEFAULT_ID)
	assert_eq(Game.sim.world.setup.difficulty, "hard")
	assert_eq(Game.sim.world.agent.origin, 0, "the origin prompt follows as before")


func test_again_is_the_same_setup_on_a_new_seed() -> void:
	ScreenRouter.start_new_run(RunSetup.create(ArchitectureDef.DEFAULT_ID, [], "gentle"))
	var seed_before: int = Game.run_seed()
	assert_eq(ProfileManager.last_setup.difficulty, "gentle", "the profile keeps the setup")
	ScreenRouter.start_new_run()
	assert_eq(Game.sim.world.setup.difficulty, "gentle")
	assert_ne(Game.run_seed(), seed_before)


func test_play_this_seed_again_carries_the_seed() -> void:
	ScreenRouter.show_setup(4242, RunSetup.create(ArchitectureDef.DEFAULT_ID, [], "hard"))
	var setup: Setup = _setup()
	assert_eq(setup.seed_value, 4242)
	assert_eq(setup.difficulty, "hard", "the run's setup is preselected")
	assert_true((setup.get_node("%SeedRow") as Control).visible)
	setup.begin()
	assert_eq(Game.run_seed(), 4242)


func test_a_carried_seed_can_be_cleared() -> void:
	ScreenRouter.show_setup(4242)
	var setup: Setup = _setup()
	setup.clear_seed()
	assert_eq(setup.seed_value, 0)
	assert_false((setup.get_node("%SeedRow") as Control).visible)
	setup.begin()
	assert_ne(Game.run_seed(), 4242, "a cleared seed is a new random one")


func test_back_on_the_first_page_returns_to_the_title() -> void:
	ScreenRouter.show_setup()
	_setup().back()
	assert_eq(ScreenRouter.current, ScreenRouter.Screen.TITLE)


## S6.1 (polish-visuals.md §4.3): the fade-in of §7.0 became the pass's
## dissolve — the new screen comes out of the ground; reduced motion cuts.
func test_a_screen_change_dissolves_in() -> void:
	ProfileManager.boot_seen = true
	Settings.set_reduced_motion(false)
	ScreenRouter.boot()
	assert_almost_eq(ScreenFx.dissolve_value(), 1.0, 1e-6, "the frame starts as ground")
	Settings.set_reduced_motion(true)
	ScreenRouter.boot()
	assert_eq(ScreenFx.dissolve_value(), 0.0, "reduced motion is a cut")
