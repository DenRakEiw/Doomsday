class_name BenchRegionRow
extends RefCounted
## One region in a benchmark digest (docs/specs/benchmark.md §6.1): only what
## moves — the name, attributes and links are in the brief.

var id: String = ""
var penetration: float = 0.0
var control: float = 0.0
## alive ÷ (alive + deaths); 1 when both are 0.
var alive_share: float = 1.0
## `Simulation.society_stage`, 0…5.
var stage: int = 0
var dormant: bool = false
var origin: bool = false
## Penetration above 0; a frontier row is not reached.
var reached: bool = false
## The kinds with a non-zero count.
var assets: Dictionary[String, int] = {}
## `"<status id>:<days left>"`, −1 for a standing one.
var statuses: Array[String] = []
## The Task Force is in this region.
var team: bool = false
