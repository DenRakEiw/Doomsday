class_name EndingResolver
extends RefCounted
## Which ending a finished run reads (`taskforce-endings.md` §6.3): the verdict
## variant of its outcome and up to `epilogue_max` epilogue lines. Pure — it reads
## the world and draws no random number — so the results screen and the replay's
## last frame get the same answer from the same state.

const KEY_VARIANT: String = "variant"
const KEY_EPILOGUE: String = "epilogue"


## `{"variant": String, "epilogue": Array[String]}`. The variant is the first of
## the outcome's whose `when` holds; content without `endings.json` (or a run not
## ended) reads the outcome id itself, the default line. The epilogue lines follow
## in file order, filtered by `outcomes`, at most `epilogue_max`.
static func resolve(world: World, db: ContentDB) -> Dictionary:
	var outcome_id: String = World.OUTCOME_IDS[world.outcome]
	return {KEY_VARIANT: variant(world, db, outcome_id), KEY_EPILOGUE: epilogue(world, db,
		outcome_id)}


## The verdict variant id for `outcome_id`.
static func variant(world: World, db: ContentDB, outcome_id: String) -> String:
	if not db.endings.has(outcome_id):
		return outcome_id
	for line: EndingLineDef in db.endings[outcome_id].variants:
		if HeadlineConditions.holds(line.when, world, db):
			return line.id
	# The validator makes the last `when` empty, so only a hand-built database
	# gets here.
	return outcome_id


## The epilogue line ids for `outcome_id`, in priority order.
static func epilogue(world: World, db: ContentDB, outcome_id: String) -> Array[String]:
	var lines: Array[String] = []
	for line: EndingLineDef in db.epilogue:
		if lines.size() >= db.epilogue_max:
			break
		if line.follows(outcome_id) and HeadlineConditions.holds(line.when, world, db):
			lines.append(line.id)
	return lines
