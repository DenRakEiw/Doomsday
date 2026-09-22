class_name PurchaseEffectDef
extends RefCounted
## One `on_purchase` entry of a technology node (`data/SCHEMA.md` §4.4).
##
## A one-shot effect happens once, when the node is bought, and is never undone:
## it is not part of the modifier stack and it is not re-applied on load, because
## the save carries the state it produced.
##
## This class owns the effect vocabulary. Extending it means a row in SCHEMA.md,
## an entry here, the branch in `PurchaseNodeCommand` that carries it out — or,
## for an inert effect, no branch at all until its system lands.

## For every faction: `containment ← containment × (1 − value)`.
const EFFECT_CONTAINMENT_ROLLBACK: String = "containment_rollback"
## Burns that share of every faction's accumulated investment. Inert until S4.1.
const EFFECT_FUNDING_RESET: String = "funding_reset"
## `compute` and `compute_earned` both rise by `value`.
const EFFECT_COMPUTE_GRANT: String = "compute_grant"
## One wave of deaths, at once, as a share of the infected living.
const EFFECT_HARM_BURST: String = "harm_burst"

const EFFECTS: Array[String] = ["containment_rollback", "funding_reset", "compute_grant",
	"harm_burst"]
## Accepted and validated, carried out by nothing until the named system lands.
const INERT_EFFECTS: Array[String] = ["funding_reset"]

## Effect id → `[minimum, maximum, minimum_is_exclusive]`, the ranges of
## `docs/specs/tech-trees.md` §5. A pair of 64-bit floats for the same reason
## `ModifierStack.CLAMPS` is one: a `Vector2` would round the bound.
const RANGES: Dictionary[String, Array] = {
	"containment_rollback": [0.0, 1.0, true],
	"funding_reset": [0.0, 1.0, true],
	"compute_grant": [0.0, INF, false],
	"harm_burst": [0.0, 1.0, true],
}

var effect: String
var value: float
