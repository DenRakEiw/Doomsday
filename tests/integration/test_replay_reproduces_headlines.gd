extends GutTest
## S3.5 — the determinism contract of spec ticker.md §3.6: the same run says the
## same things, whether it is played, replayed from its command log, or
## continued from a save.

const Harness := preload("res://tools/sim_harness.gd")
const SEED: int = 7
const DAYS: int = 200
const SAVE_DAY: int = 100


func _play(db: ContentDB, until_day: int, sim: Simulation = null) -> Dictionary:
	var policy: Policy = Harness.make_policy(GreedyPolicy.ID)
	policy.setup(db, Harness.policy_seed(SEED))
	var run: Simulation = sim if sim != null else Simulation.create(db, SEED)
	var headlines: Array[Dictionary] = []
	var problems: Array[String] = []
	Harness.advance(run, policy, until_day, false, problems, headlines)
	return {"sim": run, "headlines": headlines}


## `(day, id)` per line, which is what "the same headlines" means.
func _lines(headlines: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for row: Dictionary in headlines:
		out.append("%d %s" % [int(row["day"]), row["id"]])
	return out


func test_same_seed_same_headlines() -> void:
	var db: ContentDB = Fixtures.db()
	var played: Dictionary = _play(db, DAYS)
	var lines: Array[String] = _lines(played["headlines"])
	assert_gt(lines.size(), 0, "the fixture run says something")
	assert_eq(_lines(_play(db, DAYS)["headlines"]), lines, "twice from the same seed")

	var sim: Simulation = played["sim"]
	var replayed: Simulation = Simulation.replay(db, SEED, sim.command_log, sim.world.day)
	assert_not_null(replayed)
	assert_eq(replayed.state_hash(), sim.state_hash())
	assert_eq(replayed.headlines.to_dict(), sim.headlines.to_dict(),
		"a replay narrates the run it reproduces")


func test_a_save_continues_the_narration_where_it_stopped() -> void:
	var db: ContentDB = Fixtures.db()
	var whole: Array[String] = _lines(_play(db, DAYS)["headlines"])

	var first: Dictionary = _play(db, SAVE_DAY)
	var loaded: LoadResult = WorldSerializer.from_json(
		WorldSerializer.to_json(first["sim"]), db)
	assert_true(loaded.ok(), loaded.reason)
	var rest: Dictionary = _play(db, DAYS, loaded.sim)

	var continued: Array[String] = _lines(first["headlines"])
	continued.append_array(_lines(rest["headlines"]))
	assert_eq(continued, whole, "save, load, carry on — the same lines in the same order")
