extends GutTest
## S6.11 — the bench's percentile helper (release.md §13.3): nearest rank over a
## known list, the mean and the maximum, and an empty list answers 0.

const PerfStats := preload("res://tools/perf/perf_stats.gd")


func _one_to_hundred() -> PackedFloat64Array:
	# Descending on purpose: the helper sorts a copy, never the caller's list.
	var samples: PackedFloat64Array = PackedFloat64Array()
	for i: int in range(100, 0, -1):
		samples.append(float(i))
	return samples


func test_percentile_of_one_to_hundred_is_the_rank() -> void:
	var samples: PackedFloat64Array = _one_to_hundred()
	assert_eq(PerfStats.percentile(samples, 50.0), 50.0)
	assert_eq(PerfStats.percentile(samples, 95.0), 95.0)
	assert_eq(PerfStats.percentile(samples, 99.0), 99.0)
	assert_eq(PerfStats.percentile(samples, 100.0), 100.0)


func test_percentile_rounds_the_rank_up() -> void:
	var samples: PackedFloat64Array = PackedFloat64Array([4.0, 1.0, 3.0, 2.0])
	# 95 % of four samples is rank 3.8, so the fourth.
	assert_eq(PerfStats.percentile(samples, 95.0), 4.0)
	assert_eq(PerfStats.percentile(samples, 50.0), 2.0)


func test_percentile_leaves_the_list_unsorted() -> void:
	var samples: PackedFloat64Array = PackedFloat64Array([3.0, 1.0, 2.0])
	PerfStats.percentile(samples, 50.0)
	assert_eq(samples[0], 3.0)


func test_percentile_of_an_empty_list_is_zero() -> void:
	assert_eq(PerfStats.percentile(PackedFloat64Array(), 95.0), 0.0)


func test_mean_and_maximum_of_a_known_list() -> void:
	var samples: PackedFloat64Array = PackedFloat64Array([2.0, 8.0, 5.0])
	assert_eq(PerfStats.mean(samples), 5.0)
	assert_eq(PerfStats.maximum(samples), 8.0)


func test_mean_and_maximum_of_an_empty_list_are_zero() -> void:
	assert_eq(PerfStats.mean(PackedFloat64Array()), 0.0)
	assert_eq(PerfStats.maximum(PackedFloat64Array()), 0.0)
