extends GutTest
## S1.P — the float codec every save goes through.
##
## The engine limit it exists for is pinned down in `test_world_serializer.gd`;
## this file is about the codec itself being exact and about refusing a field
## rather than reading a wrong number out of it.

## The three values the G1 punch list names: the one everybody's example uses,
## one small enough that JSON loses it, and the world's population as a float.
const AWKWARD: Array[float] = [0.1, 1e-9, 7676945548.0]


func test_a_float_is_written_as_sixteen_lower_case_hex_characters() -> void:
	assert_eq(FloatBits.to_hex(1.0), "3ff0000000000000")
	assert_eq(FloatBits.to_hex(0.0), "0000000000000000")
	for value: float in AWKWARD:
		var text: String = FloatBits.to_hex(value)
		assert_eq(text.length(), FloatBits.LENGTH, text)
		assert_eq(text, text.to_lower(), "lower case, so two saves of one state are one text")


func test_the_awkward_values_round_trip_exactly() -> void:
	for value: float in AWKWARD:
		assert_eq(FloatBits.from_hex(FloatBits.to_hex(value)), value, str(value))


func test_computed_values_round_trip_exactly() -> void:
	# Computed, because a literal in this file has already been through
	# GDScript's own tokeniser and is one of the values that survives JSON. The
	# doubles a simulation produces are not.
	var rng: SimRng = SimRng.from_seed(1)
	for i: int in 500:
		var value: float = rng.randf() / 1000.0
		assert_eq(FloatBits.from_hex(FloatBits.to_hex(value)), value, str(value))


func test_the_bits_survive_a_trip_through_json() -> void:
	# The whole point: the text form goes through the parser untouched.
	var rng: SimRng = SimRng.from_seed(2)
	for i: int in 200:
		var value: float = rng.randf() / 1000.0
		var json: JSON = JSON.new()
		assert_eq(json.parse(JSON.stringify({"v": FloatBits.to_hex(value)}, "", true, true)), OK)
		assert_eq(FloatBits.from_variant(json.data["v"]), value, str(value))


func test_the_edges_of_the_range_round_trip() -> void:
	var edges: Array[float] = [-0.0, 1e308, -1e308, 4.9e-324, INF, -INF]
	for value: float in edges:
		var restored: float = FloatBits.from_hex(FloatBits.to_hex(value))
		assert_eq(restored, value, str(value))
	assert_eq(FloatBits.to_hex(-0.0), "8000000000000000", "the sign of zero is kept too")
	assert_true(is_nan(FloatBits.from_hex(FloatBits.to_hex(NAN))), "NAN stays NAN")


func test_a_plain_number_is_still_read() -> void:
	# What keeps hand-written fixtures and every save written before S1.P loading.
	assert_eq(FloatBits.from_variant(0.5), 0.5)
	assert_eq(FloatBits.from_variant(7), 7.0)
	assert_eq(FloatBits.from_variant(-3.25), -3.25)


func test_a_number_and_the_bit_form_are_both_readable() -> void:
	assert_true(FloatBits.is_readable(0.5))
	assert_true(FloatBits.is_readable(7))
	assert_true(FloatBits.is_readable("3ff0000000000000"))
	assert_true(FloatBits.is_readable("3FF0000000000000"), "case does not matter when reading")


func test_anything_else_is_refused_rather_than_read() -> void:
	for value: Variant in ["", "tomorrow", "3ff000000000000", "3ff00000000000000",
			"0x3ff0000000000000", true, null, [], {}]:
		assert_false(FloatBits.is_readable(value), "%s must not read as a number" % [value])
