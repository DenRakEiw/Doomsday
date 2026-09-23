class_name HeadlineDef
extends RefCounted
## One entry of `data/headlines.json` (spec ticker.md §3.2): when a line may be
## said, how often, and how likely it is to be the one chosen.
##
## The text itself is not here — it is `HEADLINE_<ID>` in `strings.csv`, because
## `core/` never holds a player-visible string.

const STREAM_CONSEQUENCE: String = "consequence"
const STREAM_REACTION: String = "reaction"
const STREAM_FILLER: String = "filler"
const STREAMS: Array[String] = [STREAM_CONSEQUENCE, STREAM_REACTION, STREAM_FILLER]

const REGISTER_INSTITUTIONAL: String = "institutional"
const REGISTER_EMERGENCY: String = "emergency"
const REGISTER_ANY: String = "any"
const REGISTERS: Array[String] = [REGISTER_INSTITUTIONAL, REGISTER_EMERGENCY, REGISTER_ANY]

const KEY_PREFIX: String = "HEADLINE_"

const ENTRY_KEYS: Array[String] = ["id", "stream", "register", "on", "when", "weight", "chance",
	"cooldown_days", "max_fires", "fallback"]
const ON_KEYS: Array[String] = ["event", "data", "region_attr_min", "region_attr_max",
	"node_tree", "node_tier"]

var id: String = ""
var stream: String = STREAM_CONSEQUENCE
var register: String = REGISTER_ANY
## "" when the trigger is state-only.
var on_event: String = ""
## Event field → the values that match it. A scalar in the data is a one-element
## list here, so the evaluator has one shape to read.
var on_data: Dictionary[String, Array] = {}
var on_region_attr_min: Dictionary[String, int] = {}
var on_region_attr_max: Dictionary[String, int] = {}
## "" = any tree, 0 = any tier.
var on_node_tree: String = ""
var on_node_tier: int = 0
## The §3.3 B keys, cast at the boundary by the loader.
var when: Dictionary[String, Variant] = {}
var weight: float = 1.0
var chance: float = 1.0
var cooldown_days: int = 0
## 0 = unlimited.
var max_fires: int = 0
## Eligible only while no ordinary headline is, for the same event.
var fallback: bool = false


func has_event_trigger() -> bool:
	return not on_event.is_empty()


## The `strings.csv` key of the line this headline says.
func key() -> String:
	return KEY_PREFIX + id.to_upper()
