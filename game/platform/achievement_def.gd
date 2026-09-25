class_name AchievementDef
extends RefCounted
## One achievement of `data/achievements.json` (release.md §3). `when` is the
## closed grammar of §3.2: every key must hold. Presentation data, never read by
## the core.

const NAME_FORMAT: String = "ACH_%s_NAME"
const DETAIL_FORMAT: String = "ACH_%s_DETAIL"

var id: String = ""
## Name and detail read as classified until earned (§3.1).
var hidden: bool = false
var when: Dictionary = {}


static func name_key(achievement_id: String) -> String:
	return NAME_FORMAT % achievement_id.to_upper()


static func detail_key(achievement_id: String) -> String:
	return DETAIL_FORMAT % achievement_id.to_upper()
