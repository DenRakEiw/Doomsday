class_name EndingDef
extends RefCounted
## The verdict variants of one outcome (`taskforce-endings.md` §6.3), tried in
## order; the last has an empty `when`, so one always holds.

const KEYS: Array[String] = ["outcome", "variants"]
## The keys of `endings.json`'s root.
const ROOT_KEYS: Array[String] = ["version", "epilogue_max", "endings", "epilogue"]
const ROOT_KEY: String = "endings"
const EPILOGUE_KEY: String = "epilogue"
const EPILOGUE_MAX_KEY: String = "epilogue_max"

## An id of `World.OUTCOME_IDS`, never `none`.
var outcome: String
var variants: Array[EndingLineDef] = []
