extends GutTest
## S1.8 — save, load, and every way a save is refused.
##
## The three JSON traps of IMPLEMENTATION §3 are what most of this is about,
## plus a fourth the spec could not have known: Godot cannot read a 64-bit float
## back out of JSON exactly. S1.P answered that one — floats are written as their
## bits (`FloatBits`), so a save restores a state **exactly** — and the test that
## pins the engine limit down is still below, because it is the only reason the
## format looks the way it does.
##
## The save property of core.md §12 — run N + M ticks equals run N, save, load,
## run M — is in `tests/integration/test_save_continue.gd`.

const Harness := preload("res://tools/sim_harness.gd")


## A run with commands, anomalies and modifiers all in play.
func _played(days: int = 120) -> Simulation:
	var problems: Array[String] = []
	var played: Dictionary = Harness.play(Fixtures.db(), 1, GreedyPolicy.ID, days, false, problems)
	return played["sim"]


func test_a_save_restores_every_field() -> void:
	var sim: Simulation = _played()
	var loaded: LoadResult = WorldSerializer.from_json(WorldSerializer.to_json(sim), Fixtures.db())
	assert_true(loaded.ok(), loaded.reason)
	assert_false(loaded.content_mismatch)
	var before: World = sim.world
	var after: World = loaded.sim.world

	assert_eq(after.day, before.day)
	assert_eq(after.origin_day, before.origin_day)
	assert_eq(after.discovery_day, before.discovery_day)
	assert_eq(after.discovered, before.discovered)
	assert_eq(after.phase, before.phase)
	assert_eq(after.outcome, before.outcome)
	assert_eq(after.next_anomaly_id, before.next_anomaly_id)
	assert_eq(after.agent.origin, before.agent.origin)
	assert_eq(after.agent.owned_nodes, before.agent.owned_nodes)
	assert_eq(after.milestones_fired, before.milestones_fired)
	assert_eq(after.rng.state_string(), before.rng.state_string(), "the stream continues exactly")
	assert_eq(after.anomalies.size(), before.anomalies.size())
	assert_eq(after.history.size(), before.history.size())
	assert_eq(loaded.sim.command_log.size(), sim.command_log.size())

	# Floats to the bit, since S1.P.
	assert_eq(after.agent.compute, before.agent.compute)
	assert_eq(after.agent.compute_earned, before.agent.compute_earned)
	assert_eq(after.factions[0].containment, before.factions[0].containment)
	for i: int in range(1, before.regions.size()):
		assert_eq(after.regions[i].penetration, before.regions[i].penetration)
		assert_eq(after.regions[i].control, before.regions[i].control)
		assert_eq(after.regions[i].alive, before.regions[i].alive)
		assert_eq(after.regions[i].deaths, before.regions[i].deaths)


func test_a_save_restores_the_state_to_the_bit() -> void:
	# The same thing the hash says, said once without the hash: a file, not a
	# dictionary, and the whole state rather than field by field.
	var sim: Simulation = _played(300)
	var loaded: LoadResult = WorldSerializer.from_json(WorldSerializer.to_json(sim), Fixtures.db())
	assert_true(loaded.ok(), loaded.reason)
	assert_eq(loaded.sim.state_hash(), sim.state_hash())


func test_a_save_continues_a_run_on_the_fixture() -> void:
	# core.md §12's save property on the fixture world; the real world is the
	# integration test named in the file comment.
	var problems: Array[String] = []
	var whole: Dictionary = Harness.play(Fixtures.db(), 1, GreedyPolicy.ID, 300, false, problems)
	var straight: Simulation = whole["sim"]

	var interrupted: Simulation = _played(120)
	var loaded: LoadResult = WorldSerializer.from_json(WorldSerializer.to_json(interrupted),
		Fixtures.db())
	assert_true(loaded.ok(), loaded.reason)
	var policy: Policy = Harness.make_policy(GreedyPolicy.ID)
	policy.setup(Fixtures.db(), Harness.policy_seed(1))
	Harness.advance(loaded.sim, policy, 300, false, problems)

	assert_gt(straight.world.day, 120, "there must be days left to play after the save")
	assert_eq(loaded.sim.world.day, straight.world.day)
	assert_eq(loaded.sim.state_hash(), straight.state_hash(),
		"300 ticks equals 120, save, load, 180")


func test_the_written_state_survives_a_dictionary_round_trip_exactly() -> void:
	# The bug class the hash is really for — a field forgotten in `to_dict` or
	# in `from_dict` — caught without going through JSON at all.
	var sim: Simulation = _played()
	var restored: World = World.from_dict(sim.world.to_dict(), Fixtures.db())
	assert_not_null(restored)
	assert_eq(restored.state_hash(), sim.world.state_hash())


func test_a_saved_run_is_reproduced_exactly_by_its_command_log() -> void:
	# The second guarantee a save carries, beside the world block: the seed and
	# the log, which replay the run bit for bit on their own.
	var sim: Simulation = _played(300)
	var loaded: LoadResult = WorldSerializer.from_json(WorldSerializer.to_json(sim), Fixtures.db())
	assert_true(loaded.ok(), loaded.reason)
	var replayed: Simulation = Simulation.replay(Fixtures.db(), 1, loaded.sim.command_log,
		sim.world.day)
	assert_not_null(replayed)
	assert_eq(replayed.state_hash(), sim.state_hash())


func test_godot_cannot_read_a_double_back_out_of_json() -> void:
	# A test rather than a comment, because it is the whole reason a float in a
	# save is 16 hex characters and not a number. No text path in Godot 4.7 —
	# JSON, `to_float`, `str_to_var`, `num_scientific` — reads a 64-bit float
	# back exactly once its magnitude falls below about 0.1. Writing at full
	# precision is necessary and not sufficient.
	#
	# The values have to be computed: a literal in this file goes through the
	# same lossy conversion in GDScript's own tokeniser and comes out as a
	# double that does round-trip.
	var rng: SimRng = SimRng.from_seed(1)
	var lossy: int = 0
	for i: int in 200:
		var value: float = rng.randf() / 1000.0
		var json: JSON = JSON.new()
		assert_eq(json.parse(JSON.stringify({"v": value}, "", true, true)), OK)
		if json.data["v"] == value:
			continue
		lossy += 1
		assert_almost_eq(json.data["v"], value, 1e-15, "and it is only ever the last bit")
	assert_gt(lossy, 100, "if this ever fails, Godot was fixed — see PROGRESS.md")


func test_the_seed_and_the_state_are_strings_in_the_file() -> void:
	var text: String = WorldSerializer.to_json(_played(20))
	var json: JSON = JSON.new()
	assert_eq(json.parse(text), OK)
	var save: Dictionary = json.data
	assert_eq(typeof(save["seed"]), TYPE_STRING, "a JSON number drops the low bits of 64 bits")
	var world: Dictionary = save["world"]
	var rng: Dictionary = world["rng"]
	assert_eq(typeof(rng["seed"]), TYPE_STRING)
	assert_eq(typeof(rng["state"]), TYPE_STRING)
	assert_eq(save["format"], WorldSerializer.FORMAT)
	assert_eq(save["version"], WorldSerializer.CURRENT_VERSION)
	assert_eq(save["content_hash"], Fixtures.db().content_hash)


func test_floats_are_written_as_their_bits() -> void:
	var sim: Simulation = _played(5)
	# The value IMPLEMENTATION §3 names, one that needs every digit, and the
	# three the G1 punch list names: the usual example, one small enough that
	# JSON loses it, and the world's population as a float.
	var awkward: Array[float] = [0.1 + 0.2, 1.0 / 3.0, 0.1, 1e-9, 7676945548.0]
	sim.world.agent.compute = awkward[0]
	sim.world.agent.compute_earned = awkward[1]
	sim.world.regions[1].penetration = awkward[2]
	sim.world.regions[2].penetration = awkward[3]
	sim.world.regions[1].alive = awkward[4]
	sim.world.factions[0].containment = awkward[2]

	var text: String = WorldSerializer.to_json(sim)
	var loaded: LoadResult = WorldSerializer.from_json(text, Fixtures.db())
	assert_true(loaded.ok(), loaded.reason)
	var world: World = loaded.sim.world
	assert_eq(world.agent.compute, awkward[0])
	assert_eq(world.agent.compute_earned, awkward[1])
	assert_eq(world.regions[1].penetration, awkward[2])
	assert_eq(world.regions[2].penetration, awkward[3])
	assert_eq(world.regions[1].alive, awkward[4])
	assert_eq(world.factions[0].containment, awkward[2])

	# And the file really is in the bit form, not a number the parser happened to
	# read back: 0.1 is the same 16 characters wherever it appears.
	var save: Dictionary = _parse(text)
	var written: Dictionary = save["world"]
	var agent: Dictionary = written["agent"]
	assert_eq(typeof(agent["compute"]), TYPE_STRING)
	assert_eq(str(agent["compute"]).length(), FloatBits.LENGTH)
	var factions: Array = written["factions"]
	var faction: Dictionary = factions[0]
	assert_eq(faction["containment"], FloatBits.to_hex(0.1))


func test_a_save_written_with_plain_numbers_still_loads() -> void:
	# What a save from before S1.P looks like, and what a hand-written fixture
	# looks like: every float a JSON number. It loads, to within what the parser
	# can read — that is the point of accepting both forms.
	var sim: Simulation = _played(20)
	var save: Dictionary = _parse(WorldSerializer.to_json(sim))
	var world: Dictionary = save["world"]
	var agent: Dictionary = world["agent"]
	agent["compute"] = 12.5
	var regions: Array = world["regions"]
	var first: Dictionary = regions[0]
	first["alive"] = 1000.0

	var loaded: LoadResult = _load(save)
	assert_true(loaded.ok(), loaded.reason)
	assert_eq(loaded.sim.world.agent.compute, 12.5)
	assert_eq(loaded.sim.world.regions[1].alive, 1000.0)


func test_a_float_field_that_is_neither_is_refused() -> void:
	for value: Variant in ["tomorrow", "3ff000000000000", true, [], {}]:
		var save: Dictionary = _parse(WorldSerializer.to_json(_played(5)))
		var world: Dictionary = save["world"]
		var agent: Dictionary = world["agent"]
		agent["compute"] = value
		assert_eq(_load(save).reason, WorldSerializer.REASON_CORRUPT, "%s" % [value])


func test_nonsense_is_refused_as_invalid_json() -> void:
	for text: String in ["", "{", "not json at all", "[1, 2]", "42", "null"]:
		var loaded: LoadResult = WorldSerializer.from_json(text, Fixtures.db())
		assert_false(loaded.ok(), "%s should be refused" % text)
		assert_eq(loaded.reason, WorldSerializer.REASON_INVALID_JSON)
		assert_null(loaded.sim)


func test_a_truncated_save_does_not_crash() -> void:
	var text: String = WorldSerializer.to_json(_played(20))
	for fraction: float in [0.25, 0.5, 0.75, 0.99]:
		var cut: String = text.substr(0, int(float(text.length()) * fraction))
		var loaded: LoadResult = WorldSerializer.from_json(cut, Fixtures.db())
		assert_false(loaded.ok(), "a save cut at %d %% should be refused" % int(fraction * 100.0))


func test_another_program_s_file_is_refused() -> void:
	var loaded: LoadResult = WorldSerializer.from_json('{"format": "something-else"}',
		Fixtures.db())
	assert_eq(loaded.reason, WorldSerializer.REASON_WRONG_FORMAT)


func test_a_missing_or_impossible_version_is_corrupt() -> void:
	for text: String in ['{"format": "doomsday-save"}',
			'{"format": "doomsday-save", "version": 0}',
			'{"format": "doomsday-save", "version": 1.5}',
			'{"format": "doomsday-save", "version": "one"}']:
		var loaded: LoadResult = WorldSerializer.from_json(text, Fixtures.db())
		assert_eq(loaded.reason, WorldSerializer.REASON_CORRUPT, text)


func test_a_save_from_a_later_build_is_refused_clearly() -> void:
	var loaded: LoadResult = WorldSerializer.from_json(
		'{"format": "doomsday-save", "version": 99}', Fixtures.db())
	assert_eq(loaded.reason, WorldSerializer.REASON_FROM_FUTURE,
		"and not corrupt — the file is fine, this build is old")


func test_a_save_with_a_body_that_is_not_a_world_is_corrupt() -> void:
	var save: Dictionary = _parse(WorldSerializer.to_json(_played(20)))
	save["world"] = "gone"
	assert_eq(_load(save).reason, WorldSerializer.REASON_CORRUPT)

	var short: Dictionary = _parse(WorldSerializer.to_json(_played(20)))
	var world: Dictionary = short["world"]
	world.erase("day")
	assert_eq(_load(short).reason, WorldSerializer.REASON_CORRUPT)


func test_content_the_build_no_longer_has_is_reported_as_content() -> void:
	var save: Dictionary = _parse(WorldSerializer.to_json(_played(20)))
	var world: Dictionary = save["world"]
	var agent: Dictionary = world["agent"]
	agent["owned_nodes"] = ["fx_from_an_older_build"]
	assert_eq(_load(save).reason, WorldSerializer.REASON_CONTENT_MISSING)

	var renamed: Dictionary = _parse(WorldSerializer.to_json(_played(20)))
	var renamed_world: Dictionary = renamed["world"]
	var regions: Array = renamed_world["regions"]
	var first: Dictionary = regions[0]
	first["id"] = "fx_a_region_that_left"
	assert_eq(_load(renamed).reason, WorldSerializer.REASON_CONTENT_MISSING)


func test_a_command_that_does_not_decode_is_corrupt() -> void:
	var save: Dictionary = _parse(WorldSerializer.to_json(_played(20)))
	save["commands"] = [{"type": "no_such_command", "day": 0}]
	assert_eq(_load(save).reason, WorldSerializer.REASON_CORRUPT)


func test_a_save_on_other_content_loads_and_says_so() -> void:
	var save: Dictionary = _parse(WorldSerializer.to_json(_played(20)))
	save["content_hash"] = "a hash from a different build"
	var loaded: LoadResult = _load(save)
	assert_true(loaded.ok(), loaded.reason)
	assert_true(loaded.content_mismatch, "playable, but a replay would not reproduce it")


func test_an_older_version_passes_through_its_migration() -> void:
	# v1 has nothing to migrate from, and a save below version 1 is refused as
	# corrupt before migration is reached — so the mechanism is proved on
	# `migrate` itself, which is why it is public and takes its table.
	var save: Dictionary = {"version": 0, "marker": "before"}
	var migrations: Dictionary[int, Callable] = {0: _fake_v0_to_v1}
	assert_eq(WorldSerializer.migrate(save, migrations), "")
	assert_eq(save["version"], WorldSerializer.CURRENT_VERSION)
	assert_eq(save["marker"], "after", "the migration actually ran")


## A real migration reshapes raw dictionaries and never touches a model class.
func _fake_v0_to_v1(save: Dictionary) -> Dictionary:
	var migrated: Dictionary = save.duplicate(true)
	migrated["marker"] = "after"
	return migrated


func test_a_version_with_no_migration_says_so() -> void:
	var save: Dictionary = {"version": 0}
	assert_eq(WorldSerializer.migrate(save, WorldSerializer.NO_MIGRATIONS),
		WorldSerializer.REASON_MIGRATION_MISSING)


func test_a_current_save_has_nothing_to_migrate() -> void:
	var save: Dictionary = {"version": WorldSerializer.CURRENT_VERSION}
	assert_eq(WorldSerializer.migrate(save, WorldSerializer.NO_MIGRATIONS), "")


func test_a_version_below_one_is_corrupt_before_migration_is_tried() -> void:
	var save: Dictionary = _parse(WorldSerializer.to_json(_played(20)))
	save["version"] = 0
	assert_eq(_load(save).reason, WorldSerializer.REASON_CORRUPT)


func _parse(text: String) -> Dictionary:
	var json: JSON = JSON.new()
	assert_eq(json.parse(text), OK)
	return json.data


func _load(save: Dictionary) -> LoadResult:
	return WorldSerializer.from_json(JSON.stringify(save, "", true, true), Fixtures.db())
