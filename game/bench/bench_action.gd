class_name BenchAction
extends RefCounted
## One action a model's answer asks for (docs/specs/benchmark.md §7.1), turned
## into the command a player would send. Ids are passed as given: whether they
## exist is `Simulation.can_apply`'s to say, with the command's own reason (§7.3).

const VERB_ORIGIN: String = "origin"
const VERB_BUY: String = "buy"
const VERB_USE: String = "use"
const VERB_ANSWER: String = "answer"
const VERB_SLEEP: String = "sleep"
const VERB_WAKE: String = "wake"
const VERBS: Array[String] = ["origin", "buy", "use", "answer", "sleep", "wake"]

const FIELD_DO: String = "do"
const FIELD_REGION: String = "region"
const FIELD_NODE: String = "node"
const FIELD_ABILITY: String = "ability"
const FIELD_EVENT: String = "event"
const FIELD_OPTION: String = "option"
## An `event` that is not given.
const NO_EVENT: int = -1

var verb: String = ""
var region: String = ""
var node: String = ""
var ability: String = ""
var event: int = NO_EVENT
var option: String = ""


static func create(p_verb: String, fields: Dictionary = {}) -> BenchAction:
	var action: BenchAction = BenchAction.new()
	action.verb = p_verb
	action.region = str(fields.get(FIELD_REGION, ""))
	action.node = str(fields.get(FIELD_NODE, ""))
	action.ability = str(fields.get(FIELD_ABILITY, ""))
	action.event = int(fields.get(FIELD_EVENT, NO_EVENT))
	action.option = str(fields.get(FIELD_OPTION, ""))
	return action


## The command the player would send for this action; null for an unknown verb,
## which the parser never lets through.
func to_command() -> Command:
	match verb:
		VERB_ORIGIN:
			return ChooseOriginCommand.new(region)
		VERB_BUY:
			return PurchaseNodeCommand.new(node, region)
		VERB_USE:
			return UseAbilityCommand.new(ability, region)
		VERB_ANSWER:
			return ChooseEventOptionCommand.new(event, option)
		VERB_SLEEP:
			return SetDormancyCommand.new(region, true)
		VERB_WAKE:
			return SetDormancyCommand.new(region, false)
	return null


## The feedback form (§7.5): the verb and the fields that are set, space-joined —
## `buy market_microstructure germany`, `answer 17 sandbag`.
func compact() -> String:
	var parts: PackedStringArray = [verb]
	for value: String in [node, ability, "" if event == NO_EVENT else str(event), option, region]:
		if not value.is_empty():
			parts.append(value)
	return " ".join(parts)


## `{"do": verb, …the fields that are set}` — the cache's form (§7.2).
func to_dict() -> Dictionary:
	var out: Dictionary = {FIELD_DO: verb}
	if not node.is_empty():
		out[FIELD_NODE] = node
	if not ability.is_empty():
		out[FIELD_ABILITY] = ability
	if event != NO_EVENT:
		out[FIELD_EVENT] = event
	if not option.is_empty():
		out[FIELD_OPTION] = option
	if not region.is_empty():
		out[FIELD_REGION] = region
	return out


func equals(other: BenchAction) -> bool:
	return other != null and to_dict() == other.to_dict()
