class_name EffectContext
extends RefCounted
## Where a one-shot effect is happening and what asked for it
## (`loop-mechanics.md` §8.3).
##
## The same three fields whether the effect came from a node, a status, an
## ability or an event, so that `EffectRunner` never has to know which.

## Region index, or 0 for an effect on the agent or on the world.
var region: int = 0
## `"tech:<id>"` · `"status:<id>"` · `"ability:<id>"` · `"event:<id>"`. Every
## event an effect emits carries it, which is what a headline filters on.
var source: String = ""
## The node id, for the `node` field the S3.1 events keep. Empty when the source
## is not a node.
var node: String = ""

const SOURCE_TECH: String = "tech"
const SOURCE_STATUS: String = "status"
const SOURCE_ABILITY: String = "ability"
const SOURCE_EVENT: String = "event"


static func for_node(node_id: String, region_index: int = 0) -> EffectContext:
	var context: EffectContext = EffectContext.new()
	context.region = region_index
	context.source = "%s:%s" % [SOURCE_TECH, node_id]
	context.node = node_id
	return context
