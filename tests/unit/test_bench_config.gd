extends GutTest
## S6.12 — `data/benchmark.json` read and checked (docs/specs/benchmark.md §3):
## the real file, then every key missing or of the wrong type.


func _raw() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(BenchConfig.PATH))


## Every key path of the file that a config reads, `a.b` for a nested one.
func _paths(d: Dictionary, prefix: String = "") -> Array[String]:
	var out: Array[String] = []
	for key: Variant in d:
		var name: String = str(key)
		if name.begins_with("_") or (prefix.is_empty() and name == "suites"):
			continue
		if prefix.is_empty() and name == "setup":
			out.append(name)
			continue
		if typeof(d[key]) == TYPE_DICTIONARY:
			out.append_array(_paths(d[key], prefix + name + "."))
		else:
			out.append(prefix + name)
	return out


func _without(path: String) -> Dictionary:
	var raw: Dictionary = _raw()
	var parts: PackedStringArray = path.split(".")
	var holder: Dictionary = raw
	for i: int in parts.size() - 1:
		holder = holder[parts[i]]
	holder.erase(parts[parts.size() - 1])
	return raw


func _with(path: String, value: Variant) -> Dictionary:
	var raw: Dictionary = _raw()
	var parts: PackedStringArray = path.split(".")
	var holder: Dictionary = raw
	for i: int in parts.size() - 1:
		holder = holder[parts[i]]
	holder[parts[parts.size() - 1]] = value
	return raw


func test_the_real_file_loads_without_errors() -> void:
	var config: BenchConfig = BenchConfig.load_file()
	assert_eq(config.errors, [] as Array[String])
	assert_eq(config.max_days, 2000)
	assert_eq(config.interval_days, 10)
	assert_eq(config.max_calls, 250)
	assert_eq(config.max_actions, 12)
	assert_almost_eq(config.max_cost_usd, 2.0, 0.0001)
	assert_eq(config.key_env, "OPENROUTER_API_KEY")


func test_the_standard_suite_has_ten_seeds_and_the_quick_one_three() -> void:
	var config: BenchConfig = BenchConfig.load_file()
	assert_eq(config.suite_seeds("standard"), [1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008,
		1009, 1010] as Array[int])
	assert_eq(config.suite_seeds("quick"), [1001, 1002, 1003] as Array[int])
	assert_eq(config.suite_seeds("nope"), [] as Array[int])


func test_each_missing_key_gives_a_reason() -> void:
	var paths: Array[String] = _paths(_raw())
	assert_gt(paths.size(), 30, "every key is tried")
	for path: String in paths:
		var config: BenchConfig = BenchConfig.from_dict(_without(path))
		assert_false(config.ok(), path + " missing is an error")
		var named: bool = false
		for error: String in config.errors:
			named = named or error.begins_with(path.get_slice(".", path.get_slice_count(".") - 1)) \
				or error.contains(path)
		assert_true(named, path + " is named: %s" % [config.errors])


func test_each_ill_typed_key_gives_a_reason() -> void:
	for path: String in _paths(_raw()):
		var config: BenchConfig = BenchConfig.from_dict(_with(path, [1, 2]))
		assert_false(config.ok(), path + " as a list is an error")


func test_a_suite_that_is_not_a_list_of_whole_numbers_is_an_error() -> void:
	assert_false(BenchConfig.from_dict(_with("suites.quick", [1.5])).ok())
	assert_false(BenchConfig.from_dict(_with("suites.quick", "1001")).ok())
	assert_false(BenchConfig.from_dict(_without("suites.standard")).ok())


func test_a_missing_file_is_one_error_and_no_crash() -> void:
	var config: BenchConfig = BenchConfig.load_file("res://tests/fixtures/bench/none.json")
	assert_eq(config.errors.size(), 1)
