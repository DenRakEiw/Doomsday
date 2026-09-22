extends GutTest
## S1.P — core.md §12's save property, on the real world: **run N + M ticks is
## the same state as run N, save to text, load, run M more** — by hash, not by
## tolerance.
##
## S1.8 could not have this test: JSON lost the last bit of most floats, so the
## continued run drifted and the two hashes differed. G1 decided floats are
## written as their bits (`FloatBits`), which is what makes the property hold and
## this the test that guards it.
##
## The real content rather than the fixture, because that is where the awkward
## magnitudes live: a population of 7.6 billion and a penetration of 1e-9 in the
## same dictionary.

const Harness := preload("res://tools/sim_harness.gd")

const WORLD_ROOT: String = "res://data"
const SEED: int = 1
## N and M of the property. `greedy` on seed 1 runs 506 days, so both cuts fall
## inside a live run with commands, anomalies and modifiers all in play.
const FIRST_DAYS: int = 200
const REST_DAYS: int = 100

static var _db: ContentDB = null


func before_all() -> void:
	if _db == null:
		var result: ContentLoadResult = ContentLoader.load_root(WORLD_ROOT)
		assert_true(result.ok(), result.error_text())
		_db = result.db


func test_a_run_continued_from_a_save_ends_in_the_same_state() -> void:
	var problems: Array[String] = []
	var straight: Simulation = _play(FIRST_DAYS + REST_DAYS, problems)
	assert_eq(straight.world.day, FIRST_DAYS + REST_DAYS, "the run must still be live")

	var interrupted: Simulation = _play(FIRST_DAYS, problems)
	var text: String = WorldSerializer.to_json(interrupted)
	var loaded: LoadResult = WorldSerializer.from_json(text, _db)
	assert_true(loaded.ok(), loaded.reason)
	assert_false(loaded.content_mismatch)
	assert_eq(loaded.sim.state_hash(), interrupted.state_hash(),
		"the file alone restores the state exactly")

	# The same policy, set up the same way, carries the loaded run the rest of
	# the way: `greedy` decides from the state alone, so its commands can only
	# differ if the state did.
	var policy: Policy = Harness.make_policy(GreedyPolicy.ID)
	policy.setup(_db, Harness.policy_seed(SEED))
	var rejected: int = Harness.advance(loaded.sim, policy, FIRST_DAYS + REST_DAYS, true, problems)

	assert_eq(rejected, 0)
	assert_eq(problems, [] as Array[String], "no invariant violation on either run")
	assert_eq(loaded.sim.world.day, straight.world.day)
	assert_eq(loaded.sim.state_hash(), straight.state_hash(),
		"%d + %d ticks equals %d, save, load, %d" % [FIRST_DAYS, REST_DAYS, FIRST_DAYS, REST_DAYS])


func test_the_history_of_a_long_run_survives_the_file_exactly() -> void:
	# The other half of the world block, and the one with the most floats in it:
	# `HistorySample` writes nine fields per sample and nothing reads them back
	# in the simulation, so only a hash comparison catches a lost one.
	var problems: Array[String] = []
	var sim: Simulation = _play(FIRST_DAYS + REST_DAYS, problems)
	assert_gt(sim.world.history.size(), 5, "there must be samples to lose")

	var loaded: LoadResult = WorldSerializer.from_json(WorldSerializer.to_json(sim), _db)
	assert_true(loaded.ok(), loaded.reason)
	var before: Array[HistorySample] = sim.world.history
	var after: Array[HistorySample] = loaded.sim.world.history
	assert_eq(after.size(), before.size())
	for i: int in before.size():
		assert_eq(after[i].to_dict(), before[i].to_dict(), "sample %d" % i)


func _play(days: int, problems: Array[String]) -> Simulation:
	var played: Dictionary = Harness.play(_db, SEED, GreedyPolicy.ID, days, true, problems)
	return played["sim"]
