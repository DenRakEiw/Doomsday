class_name LinkDef
extends RefCounted
## An undirected connection between two regions (`data/SCHEMA.md` §3).
##
## Two regions may be joined by several links of different kinds, never by two of
## the same kind — which is what the derived `id` guarantees.

const KIND_LAND: String = "land"
const KIND_SEA: String = "sea"
const KIND_AIR: String = "air"
const KIND_NETWORK: String = "network"
const KINDS: Array[String] = ["land", "sea", "air", "network"]

## The link id, and the file order, are part of the determinism contract.
var id: String
## Region index, not id: the endpoints are resolved at load.
var a: int
var b: int
var kind: String


## The id a link gets from its endpoints. Takes region **ids**, not indices, so
## that the validator can derive it before the endpoints are resolved.
static func derive_id(a_id: String, b_id: String, kind: String) -> String:
	return "%s|%s|%s" % [a_id, b_id, kind]
