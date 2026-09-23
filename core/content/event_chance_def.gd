class_name EventChanceDef
extends RefCounted
## One roll on an event option (`loop-mechanics.md` §10.1, §10.5 step 4).
##
## With probability `p` its effects run. On a chain step it may also carry a
## `next` of its own (D4.3): when the roll succeeds, that list replaces the
## option's `next` for this answer — an empty one ends the chain. That is how a
## step routes on a roll without a second step to reveal it.

## The keys a `chance` entry allows.
const KEYS: Array[String] = ["p", "effects", "next"]

## In (0, 1].
var p: float = 1.0
var effects: Array[EffectDef] = []
## Whether the entry carries a `next` at all — an empty one is not an absent one.
var has_next: bool = false
var next: Array[Dictionary] = []
