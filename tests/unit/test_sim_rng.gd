extends GutTest
## S1.2 — the simulation's only source of randomness. Determinism starts here:
## if the stream is not reproducible, nothing above it can be.


func test_the_same_seed_gives_the_same_sequence() -> void:
	var a: SimRng = SimRng.from_seed(7)
	var b: SimRng = SimRng.from_seed(7)
	for i: int in 20:
		assert_eq(a.randf(), b.randf())


func test_a_different_seed_gives_a_different_sequence() -> void:
	var a: SimRng = SimRng.from_seed(1)
	var b: SimRng = SimRng.from_seed(2)
	var first: Array[float] = []
	var second: Array[float] = []
	for i: int in 20:
		first.append(a.randf())
		second.append(b.randf())
	assert_ne(first, second)


func test_the_state_continues_the_sequence_exactly() -> void:
	var a: SimRng = SimRng.from_seed(42)
	for i: int in 10:
		a.randf()
	var b: SimRng = SimRng.from_strings(a.seed_string(), a.state_string())
	assert_eq(b.seed_string(), a.seed_string())
	for i: int in 10:
		assert_eq(a.randf(), b.randf())


func test_chance_always_consumes_exactly_one_value() -> void:
	var rng: SimRng = SimRng.from_seed(3)
	var before: String = rng.state_string()
	assert_false(rng.chance(0.0), "a chance of 0 never succeeds")
	var after_zero: String = rng.state_string()
	assert_ne(before, after_zero, "and it still costs a value")
	assert_true(rng.chance(1.0), "a chance of 1 always succeeds")
	assert_ne(after_zero, rng.state_string(), "and it costs a value too")


func test_a_skipped_roll_leaves_the_stream_where_it_was() -> void:
	var rolled: SimRng = SimRng.from_seed(5)
	var skipped: SimRng = SimRng.from_seed(5)
	rolled.chance(0.5)
	assert_ne(rolled.state_string(), skipped.state_string())


func test_seed_and_state_survive_as_strings() -> void:
	# A 64-bit value that a JSON number would round off.
	var rng: SimRng = SimRng.from_seed(-6044729461038352412)
	assert_eq(rng.seed_string(), "-6044729461038352412")
	for i: int in 5:
		rng.randf()
	var restored: SimRng = SimRng.from_strings(rng.seed_string(), rng.state_string())
	assert_eq(restored.state_string(), rng.state_string())
	assert_eq(restored.randf(), rng.randf())


func test_randi_range_stays_inside_its_range() -> void:
	var rng: SimRng = SimRng.from_seed(11)
	for i: int in 50:
		var value: int = rng.randi_range(3, 5)
		assert_between(value, 3, 5)

# ------------------------------------------------- S4.1: the weighted draw


## §12: `weighted_pick` consumes exactly one value, so a draw and a plain
## `randf` leave the stream in the same place.
func test_weighted_pick_consumes_exactly_one_value() -> void:
	var drawn: SimRng = SimRng.from_seed(1)
	drawn.weighted_pick(PackedFloat64Array([1.0, 1.0, 1.0]))
	var after_draw: float = drawn.randf()

	var plain: SimRng = SimRng.from_seed(1)
	plain.randf()
	assert_almost_eq(after_draw, plain.randf(), 1e-12)


func test_a_single_positive_weight_always_wins() -> void:
	var rng: SimRng = SimRng.from_seed(7)
	for i: int in 50:
		assert_eq(rng.weighted_pick(PackedFloat64Array([0.0, 0.0, 1.0])), 2)


func test_a_negative_or_non_finite_weight_counts_as_zero() -> void:
	var rng: SimRng = SimRng.from_seed(3)
	for i: int in 50:
		assert_eq(rng.weighted_pick(PackedFloat64Array([-5.0, NAN, INF, 1.0])), 3)


func test_a_total_of_zero_returns_minus_one_and_consumes_nothing() -> void:
	var rng: SimRng = SimRng.from_seed(9)
	var before: String = rng.state_string()
	assert_eq(rng.weighted_pick(PackedFloat64Array([0.0, 0.0])), -1)
	assert_eq(rng.weighted_pick(PackedFloat64Array()), -1, "and an empty list too")
	assert_eq(rng.state_string(), before)


## Seed 1, 10 000 draws: the shares follow the weights. A test that depends on
## the stream fixes its seed and says so.
func test_the_shares_follow_the_weights_over_many_draws() -> void:
	var rng: SimRng = SimRng.from_seed(1)
	var counts: Array[int] = [0, 0]
	var draws: int = 10000
	for i: int in draws:
		counts[rng.weighted_pick(PackedFloat64Array([1.0, 3.0]))] += 1
	assert_almost_eq(float(counts[0]) / float(draws), 0.25, 0.02)
	assert_almost_eq(float(counts[1]) / float(draws), 0.75, 0.02)
