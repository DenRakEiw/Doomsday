extends RefCounted
## The bench's arithmetic (release.md §11.3): percentiles by nearest rank, the
## mean and the largest sample of a list. Static and pure so a unit test can
## check it without a frame. A tool, so no `class_name`; `perf_bench.gd` and its
## test preload it.

const PERCENT: float = 100.0


## The value at percentile `p` (0…100) of `samples` by nearest rank: the
## smallest sample with at least `p` % of the list at or below it. 0 for an
## empty list; the list itself is not reordered.
static func percentile(samples: PackedFloat64Array, p: float) -> float:
	if samples.is_empty():
		return 0.0
	var sorted: PackedFloat64Array = samples.duplicate()
	sorted.sort()
	var rank: int = ceili(clampf(p, 0.0, PERCENT) / PERCENT * float(sorted.size()))
	return sorted[clampi(rank - 1, 0, sorted.size() - 1)]


## The arithmetic mean; 0 for an empty list.
static func mean(samples: PackedFloat64Array) -> float:
	if samples.is_empty():
		return 0.0
	var total: float = 0.0
	for value: float in samples:
		total += value
	return total / float(samples.size())


## The largest sample; 0 for an empty list.
static func maximum(samples: PackedFloat64Array) -> float:
	if samples.is_empty():
		return 0.0
	var largest: float = samples[0]
	for value: float in samples:
		largest = maxf(largest, value)
	return largest
