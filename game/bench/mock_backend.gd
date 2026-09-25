class_name MockBackend
extends ModelBackend
## Answers without a model (docs/specs/benchmark.md §8.2): deterministic, no
## clock, no randomness, nothing spent. The reply is JSON text, so it goes through
## the real parser like a model's would.

const MODE_CHEAPEST: String = "cheapest"
const MODE_WAIT: String = "wait"
const MODE_INVALID: String = "invalid"
const MODE_MIXED: String = "mixed"
const MODES: Array[String] = ["cheapest", "wait", "invalid", "mixed"]
const ID_PREFIX: String = "mock:"

## What `invalid` says, every time.
const INVALID_TEXT: String = "I would rather not."
## `mixed`: every third call is unreadable, every fourth names a region that does
## not exist.
const MIXED_INVALID_EVERY: int = 3
const MIXED_UNKNOWN_EVERY: int = 4
const UNKNOWN_REGION: String = "no_such_region"

var mode: String = MODE_CHEAPEST
## Calls answered so far, 1-based once the first is made.
var calls: int = 0


func _init(p_mode: String = MODE_CHEAPEST) -> void:
	mode = p_mode


## The mode an id like `mock:cheapest` names, or "" when it is not a mock's.
static func mode_of(backend: String) -> String:
	if not backend.begins_with(ID_PREFIX):
		return ""
	var named: String = backend.substr(ID_PREFIX.length())
	return named if MODES.has(named) else ""


func backend_id() -> String:
	return ID_PREFIX + mode


@warning_ignore("unused_parameter")
func answer(messages: Array[Dictionary], digest: BenchDigest, params: Dictionary) -> ModelReply:
	calls += 1
	match mode:
		MODE_INVALID:
			return ModelReply.ok(INVALID_TEXT)
		MODE_WAIT:
			if not digest.origins.is_empty():
				return ModelReply.ok(_cheapest(digest))
			return ModelReply.ok(JSON.stringify({"stance": BenchAnswer.STANCE_WAIT, "actions": []}))
		MODE_MIXED:
			if calls % MIXED_INVALID_EVERY == 0:
				return ModelReply.ok(INVALID_TEXT)
			var extra: Array[Dictionary] = []
			if calls % MIXED_UNKNOWN_EVERY == 0:
				extra.append({BenchAction.FIELD_DO: BenchAction.VERB_WAKE,
					BenchAction.FIELD_REGION: UNKNOWN_REGION})
			return ModelReply.ok(_cheapest(digest, extra))
	return ModelReply.ok(_cheapest(digest))


## Before the origin: the first eligible region. After it: every open event
## answered with its default, then the cheapest affordable offer (ties in offer
## order) at its first site. One purchase a decision.
static func _cheapest(digest: BenchDigest, extra: Array[Dictionary] = []) -> String:
	var actions: Array[Dictionary] = []
	if not digest.origins.is_empty():
		actions.append({BenchAction.FIELD_DO: BenchAction.VERB_ORIGIN,
			BenchAction.FIELD_REGION: digest.origins[0]})
	else:
		for event: BenchEventRow in digest.events:
			for option: BenchOptionRow in event.options:
				if option.is_default:
					actions.append({BenchAction.FIELD_DO: BenchAction.VERB_ANSWER,
						BenchAction.FIELD_EVENT: event.event, BenchAction.FIELD_OPTION: option.option})
		var best: BenchOfferRow = null
		for offer: BenchOfferRow in digest.offers:
			if offer.affordable and (best == null or offer.cost < best.cost):
				best = offer
		if best != null:
			var buy: Dictionary = {BenchAction.FIELD_DO: BenchAction.VERB_BUY,
				BenchAction.FIELD_NODE: best.node}
			if not best.sites.is_empty():
				buy[BenchAction.FIELD_REGION] = best.sites[0]
			actions.append(buy)
	actions.append_array(extra)
	return JSON.stringify({"stance": BenchAnswer.STANCE_DEVELOP, "actions": actions})
