class_name BenchOptionRow
extends RefCounted
## One option of an open event in a benchmark digest (docs/specs/benchmark.md
## §6.1).

var option: String = ""
## `EventView.option_text`, translated.
var text: String = ""
var cost: float = 0.0
var suppression: bool = false
## `EventView.lock_text` of the lock reason; "" when the option is open.
var lock: String = ""
## The compute is below the cost.
var short: bool = false
var is_default: bool = false
