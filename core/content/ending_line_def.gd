class_name EndingLineDef
extends RefCounted
## One line an ending may show (`taskforce-endings.md` §6.3): a verdict variant
## of an outcome, or an epilogue line. It holds when its `when` does and, for an
## epilogue line, when the outcome is one it may follow.

## The keys of a variant and of an epilogue line.
const VARIANT_KEYS: Array[String] = ["id", "when"]
const EPILOGUE_KEYS: Array[String] = ["id", "when", "outcomes"]

var id: String
## SCHEMA §8, cast as the headline loader casts it.
var when: Dictionary[String, Variant] = {}
## Epilogue only: the outcome ids it may follow; empty = every outcome.
var outcomes: Array[String] = []


## Whether this line may follow `outcome_id` at all.
func follows(outcome_id: String) -> bool:
	return outcomes.is_empty() or outcomes.has(outcome_id)


## The verdict line of a variant with this id.
static func verdict_key(variant_id: String) -> String:
	return "UI_RESULT_LINE_%s" % variant_id.to_upper()


## The text of an epilogue line with this id.
static func epilogue_key(line_id: String) -> String:
	return "ENDING_EPILOGUE_%s" % line_id.to_upper()
