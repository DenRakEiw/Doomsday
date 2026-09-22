extends GutTest
## S3.4 — what a slot can be asked without loading it (spec m3-screens.md §7.1).
##
## The title and the pause menu both show a day under a slot; neither may put a
## run in memory to find it.

const SLOT: String = "test_peek"


func before_each() -> void:
	Game.stop_run()
	Game.debug_log = false
	SaveManager.delete(SLOT)


func after_each() -> void:
	SaveManager.delete(SLOT)
	Game.stop_run()


func _start_run(days: int) -> void:
	Game.start_run(1)
	Game.apply(ChooseOriginCommand.new(Game.db.regions[1].id))
	Game.advance(days)


func test_peek_day_reads_without_loading() -> void:
	_start_run(9)
	assert_eq(SaveManager.save(SLOT), "")
	var running: Simulation = Game.sim
	assert_eq(SaveManager.peek_day(SLOT), Game.sim.world.day)
	assert_eq(Game.sim, running, "peeking loads nothing")
	assert_true(SaveManager.has_slot(SLOT))


func test_peek_day_answers_minus_one_for_anything_it_cannot_read() -> void:
	assert_eq(SaveManager.peek_day("no_such_slot"), SaveManager.NO_DAY)

	var path: String = SaveManager.path_for(SLOT)
	_write(path, "{ not json")
	assert_eq(SaveManager.peek_day(SLOT), SaveManager.NO_DAY, "a file that is not JSON")
	_write(path, JSON.stringify({"world": {}}))
	assert_eq(SaveManager.peek_day(SLOT), SaveManager.NO_DAY, "a world without a day")
	_write(path, JSON.stringify({"world": {"day": 12}}))
	assert_eq(SaveManager.peek_day(SLOT), 12, "and the day when there is one")


static func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
