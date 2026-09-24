class_name Agent
extends RefCounted
## The player: what it has, what it owns, where it started.

var compute: float = 0.0
## Lifetime total, never decreases — what was earned, not what is left.
var compute_earned: float = 0.0
## Region index of the origin; 0 means none has been chosen.
var origin: int = 0
## Purchase order, which is also the order the modifier sources are rebuilt in.
var owned_nodes: Array[String] = []
## Ability id → the day its cooldown clears. An absent id is ready (S4.2).
var cooldowns: Dictionary[String, int] = {}
## Flag → the day it expires (`set_flag`, S4.2).
var timed_flags: Dictionary[String, int] = {}
## Narrative flags that never expire, in the order they were set (S4.3).
var story_flags: Array[String] = []
## Link kind → how many regions were seeded over that kind. Counted from S4.1
## on; D4.2's Disclosure reads it.
var seeds_by_kind: Dictionary[String, int] = {}
## `replayability.md` §2.2, the Swarm's `drift` hook: 0…100, how far the copies
## have wandered. 0 on every other architecture.
var drift: float = 0.0
## Every emergent behaviour suppressed this run — what the next suppression's
## price climbs with (§3.1).
var suppressions: int = 0
## The Weapon's `escalation` hook: the day the standing status next climbs a
## level, or -1 before it has started.
var escalation_next: int = -1


func owns(node_id: String) -> bool:
	return owned_nodes.has(node_id)


func has_story_flag(flag: String) -> bool:
	return story_flags.has(flag)


## Counts one seeding over `kind`, whoever caused it.
func count_seed(kind: String) -> void:
	seeds_by_kind[kind] = int(seeds_by_kind.get(kind, 0)) + 1
