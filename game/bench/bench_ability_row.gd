class_name BenchAbilityRow
extends RefCounted
## One unlocked ability in a benchmark digest (docs/specs/benchmark.md §6.1).

var ability: String = ""
var level: int = 0
var cost: float = 0.0
## Days until it is ready; 0 when it is.
var ready_in: int = 0
var global: bool = false
## Region ids it could be aimed at, index order, at most `targets_max`.
var targets: Array[String] = []
