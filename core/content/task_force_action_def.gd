class_name TaskForceActionDef
extends RefCounted
## One thing the Task Force does when it arrives (`taskforce-endings.md` §3): the
## first action whose level and rule hold for the target is the one it sets up.

const KEYS: Array[String] = ["id", "status", "level_min", "rule"]
const ROOT_KEY: String = "actions"
const LEVEL_MAX: int = 3

var id: String
## A world status, applied to the target when the setup completes.
var status: String
var level_min: int = 1
## SCHEMA §7, evaluated on the target.
var rule: Eligibility = null
