class_name BenchFactionRow
extends RefCounted
## One faction in a benchmark digest (docs/specs/benchmark.md §6.1).

## `Simulation.next_move`'s states (opposition.md §6.6).
const MOVE_PREPARING: String = "preparing"
const MOVE_HELD: String = "held"
const MOVE_COOLDOWN: String = "cooldown"
const MOVE_NONE: String = "none"

var id: String = ""
var containment: float = 0.0
## Since the last decision; 0 at the first.
var change: float = 0.0
## `Simulation.next_move`: `preparing`, `held`, `cooldown` or `none`.
var move_state: String = ""
var move_event: String = ""
var move_days: int = 0
