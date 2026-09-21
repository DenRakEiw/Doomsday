class_name MilestoneDef
extends RefCounted
## A one-off Compute reward for reaching a point in the spread
## (`data/SCHEMA.md` §5). Each milestone fires at most once per run.

## Fires when the number of regions ever seeded, the origin included, reaches
## `threshold`.
const KIND_REGIONS_INFECTED: String = "regions_infected"
## Fires when the infected share of the world's hardware reaches `threshold`.
const KIND_WORLD_SHARE: String = "world_share"
## Fires once per continent other than the origin's; `threshold` is ignored and
## the fired id is `<id>_<continent>`.
const KIND_CONTINENT_FOOTHOLD: String = "continent_foothold"
const KINDS: Array[String] = ["regions_infected", "world_share", "continent_foothold"]

var id: String
var kind: String
var threshold: float
var reward: float
