class_name BenchEventRow
extends RefCounted
## One open event in a benchmark digest (docs/specs/benchmark.md §6.1).

## The open event's id — what an answer names.
var event: int = 0
var def: String = ""
var kind: String = ""
## Region id, or "" for a global event.
var region: String = ""
var days_left: int = 0
## Both translated through `EventView`.
var title: String = ""
var body: String = ""
var options: Array[BenchOptionRow] = []
