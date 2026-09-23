class_name FactionDef
extends RefCounted
## One containment track as authored (`opposition.md` §4): whose capacity it
## draws on, which brake slows it, what it reacts to and which moves it makes.
## The mutable counterpart is `Faction`.

## The keys a faction allows.
const KEYS: Array[String] = ["id", "capacity_attr", "brake", "terms", "moves"]
## The root list of `factions.json`.
const ROOT_KEY: String = "factions"
const MOVES_MAX: int = 4

## One of `Faction.FACTION_IDS`.
var id: String
## A `RegionDef` attribute, `population` included (the derived tier).
var capacity_attr: String
## A global modifier target: the faction's own `containment_<…>` multiplier.
var brake: String
## ≥ 1, file order.
var terms: Array[FactionTermDef] = []
## 0…4, in trigger order.
var moves: Array[FactionMoveDef] = []


## The move that opens `event_id`, a variant's event included; null if none.
func move_by_event(event_id: String) -> FactionMoveDef:
	for move: FactionMoveDef in moves:
		if move.names_event(event_id):
			return move
	return null


## The localisation key of a faction's name.
static func name_key(faction_id: String) -> String:
	return "FACTION_%s" % faction_id.to_upper()
