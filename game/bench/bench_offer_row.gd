class_name BenchOfferRow
extends RefCounted
## One node the tree lets the player buy or save for (docs/specs/benchmark.md
## §6.1, §6.2).

var node: String = ""
var cost: float = 0.0
var affordable: bool = false
## A deploying node's eligible regions, best first; empty for the others.
var sites: Array[String] = []
