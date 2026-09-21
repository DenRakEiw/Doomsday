class_name RegionDef
extends RefCounted
## One region as authored, immutable after loading. The mutable counterpart is
## `Region`; state points at definitions, never the other way round.
##
## This class owns the attribute vocabulary (`data/SCHEMA.md` §2).

## The eight authored tiers, in the order SCHEMA §2 lists them.
const ATTRIBUTES: Array[String] = ["compute", "connectivity", "wealth", "regulation",
	"research", "manufacturing", "industry", "isolation"]
## Derived at load from `population` and `balance.population_tiers`. It must not
## appear in a content file, but scopes may name it like any other attribute.
const ATTRIBUTE_POPULATION: String = "population"
## Everything a modifier scope may name — `ATTRIBUTES` plus `ATTRIBUTE_POPULATION`,
## written out because GDScript constants cannot be built from other constants.
const ATTRIBUTES_ALL: Array[String] = ["compute", "connectivity", "wealth", "regulation",
	"research", "manufacturing", "industry", "isolation", "population"]

const TIER_MIN: int = 0
const TIER_MAX: int = 4
## Index 0 is "no region"; the upper bound is what the ID map's two bytes hold.
const INDEX_MIN: int = 1
const INDEX_MAX: int = 65535

var index: int
var id: String
var continent: String
var population: int
var air_gapped: bool
## Pixel position on the ID map, for markers and the ends of link lines.
var anchor: Vector2i
## The eight authored tiers plus the derived `population` tier, each 0…4.
var attributes: Dictionary[String, int] = {}


## The tier of `attribute`, or 0 for a name that is not an attribute — scopes are
## validated at load, so an unknown name here can only be a programming error.
func attr(attribute: String) -> int:
	return int(attributes.get(attribute, 0))
