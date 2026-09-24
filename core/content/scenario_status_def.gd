class_name ScenarioStatusDef
extends RefCounted
## One entry of a scenario's `start.statuses` (`docs/specs/scenarios.md` §2): a
## world status and the rule that says which regions stand under it from the
## origin on.

var status: String
var eligible: Eligibility = Eligibility.none()
