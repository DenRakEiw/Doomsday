extends GutTest
## S6.9 — `PlatformService` (release.md §1.3): the null backend in a build
## without Steam, the sync at start, a new earn, the fallback, and the overlay's
## pause.

const SESSION: PackedScene = preload("res://game/session/session.tscn")
const SEED: int = 1


## Records every call a backend receives.
class RecordingBackend:
	extends PlatformBackend

	var starts: bool = true
	var unlocked: Array[String] = []
	var stats: Dictionary[String, int] = {}
	var stores: int = 0
	var polls: int = 0

	func id() -> String:
		return "recording"

	func start() -> bool:
		return starts

	func poll() -> void:
		polls += 1

	func unlock_achievement(api_name: String) -> void:
		unlocked.append(api_name)

	func set_stat(api_name: String, value: int) -> void:
		stats[api_name] = value

	func store() -> void:
		stores += 1


func before_each() -> void:
	Game.stop_run()
	ProfileManager.achievements.clear()
	ProfileManager.reset()


func after_each() -> void:
	PlatformService.use_backend(NullPlatformBackend.new())
	Game.stop_run()
	ProfileManager.achievements.clear()
	ProfileManager.reset()


func test_a_build_without_steam_runs_on_the_null_backend() -> void:
	assert_false(OS.has_feature(PlatformService.FEATURE_STEAM))
	assert_eq(PlatformService.backend.id(), NullPlatformBackend.ID)


func test_the_null_backend_does_nothing_and_starts() -> void:
	var backend: NullPlatformBackend = NullPlatformBackend.new()
	assert_true(backend.start())
	backend.unlock_achievement("ACH_FIRST_RUN")
	backend.set_stat("STAT_RUNS_WON", 3)
	backend.store()
	backend.poll()
	backend.shutdown()
	assert_eq(backend.id(), "null")


func test_the_start_unlocks_everything_the_profile_has_earned() -> void:
	ProfileManager.achievements = ["first_run", "lose_contained", "from_a_later_build"] \
		as Array[String]
	ProfileManager.runs_completed = 3
	ProfileManager.runs_won = 1
	var backend: RecordingBackend = RecordingBackend.new()
	PlatformService.use_backend(backend)
	assert_eq(backend.unlocked, ["ACH_FIRST_RUN", "ACH_LOSE_CONTAINED"] as Array[String],
		"an id the book does not know is ignored")
	assert_eq(backend.stats, {"STAT_RUNS_COMPLETED": 3, "STAT_RUNS_WON": 1} \
		as Dictionary[String, int])
	assert_eq(backend.stores, 1)


func test_a_new_earn_unlocks_exactly_the_new_ids() -> void:
	ProfileManager.achievements = ["first_run"] as Array[String]
	var backend: RecordingBackend = RecordingBackend.new()
	PlatformService.use_backend(backend)
	backend.unlocked.clear()
	backend.stores = 0
	ProfileManager.runs_completed = 10
	EventBus.achievements_earned.emit(["runs_10"] as Array[String])
	assert_eq(backend.unlocked, ["ACH_RUNS_10"] as Array[String])
	assert_eq(int(backend.stats["STAT_RUNS_COMPLETED"]), 10, "the stats again")
	assert_eq(backend.stores, 1)


func test_a_counted_run_reaches_the_backend() -> void:
	var backend: RecordingBackend = RecordingBackend.new()
	PlatformService.use_backend(backend)
	Game.start_run(SEED)
	Game.apply(ChooseOriginCommand.new(Game.db.regions[1].id))
	Game.sim.world.outcome = World.Outcome.LOSE_CONTAINED
	EventBus.run_ended.emit(World.OUTCOME_IDS[World.Outcome.LOSE_CONTAINED])
	assert_eq(backend.unlocked, ["ACH_FIRST_RUN", "ACH_LOSE_CONTAINED"] as Array[String])
	assert_eq(int(backend.stats["STAT_RUNS_COMPLETED"]), 1)


func test_a_backend_that_cannot_start_falls_back_to_null() -> void:
	var backend: RecordingBackend = RecordingBackend.new()
	backend.starts = false
	PlatformService.use_backend(backend)
	assert_eq(PlatformService.backend.id(), NullPlatformBackend.ID)
	assert_eq(backend.unlocked, [] as Array[String])


func test_the_backend_is_polled_every_frame() -> void:
	var backend: RecordingBackend = RecordingBackend.new()
	PlatformService.use_backend(backend)
	await wait_process_frames(2)
	assert_gt(backend.polls, 0)


func test_the_overlay_during_a_live_run_opens_the_pause_menu() -> void:
	var backend: RecordingBackend = RecordingBackend.new()
	PlatformService.use_backend(backend)
	var session: Control = SESSION.instantiate()
	add_child_autofree(session)
	var modals: ModalHost = session.get_node("ModalLayer/ModalHost")
	var menu: Control = session.get_node("ModalLayer/ModalHost/PauseMenu")
	Game.start_run(SEED)
	Game.apply(ChooseOriginCommand.new(Game.db.regions[1].id))
	backend.overlay_toggled.emit(true)
	assert_true(modals.is_open())
	assert_eq(modals.current(), menu)


func test_the_overlay_outside_a_run_does_nothing() -> void:
	var backend: RecordingBackend = RecordingBackend.new()
	PlatformService.use_backend(backend)
	var session: Control = SESSION.instantiate()
	add_child_autofree(session)
	var modals: ModalHost = session.get_node("ModalLayer/ModalHost")
	backend.overlay_toggled.emit(true)
	assert_false(modals.is_open(), "no run")
	Game.start_run(SEED)
	Game.apply(ChooseOriginCommand.new(Game.db.regions[1].id))
	Game.sim.world.outcome = World.Outcome.LOSE_CONTAINED
	backend.overlay_toggled.emit(true)
	assert_false(modals.is_open(), "the run is over")
	Game.sim.world.outcome = World.Outcome.NONE
	backend.overlay_toggled.emit(false)
	assert_false(modals.is_open(), "closing the overlay changes nothing")
