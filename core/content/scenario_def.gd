class_name ScenarioDef
extends RefCounted
## One scenario (`docs/specs/scenarios.md` §2): a modifier set for the whole run
## plus overrides of how it starts. No hook — a scenario that needs a new rule is
## not a scenario.
##
## Combines with any architecture, loadout and difficulty; `RunSetup.scenario`
## names it, "" is none.

## The keys a `scenarios.json` entry allows, and those of its `start` block.
const KEYS: Array[String] = ["id", "modifiers", "start"]
const START_KEYS: Array[String] = ["compute", "origin_eligible", "statuses",
	"containment_at_discovery", "flags"]
const START_STATUS_KEYS: Array[String] = ["status", "eligible"]
## The root keys of `scenarios.json`.
const ROOT_KEY: String = "scenarios"
const UNLOCK_KEY: String = "unlock"
## The one unlock rule the file carries (§0 item 3).
const UNLOCK_RUNS: String = "runs_completed"
## The prefix of a scenario's status source (`Status.source`) — its colour is the
## world's, with no faction behind it.
const SOURCE_PREFIX: String = "scenario"

var id: String
## Global modifiers, active for the whole run as a directive's are.
var modifiers: Array[ModifierDef] = []
## Replaces `balance.compute.start` when `has_start_compute`.
var has_start_compute: bool = false
var start_compute: float = 0.0
## Added to the origin rule; null when the scenario adds none.
var origin_eligible: Eligibility = null
## World statuses applied when the origin is chosen, each to every region its
## rule passes.
var start_statuses: Array[ScenarioStatusDef] = []
## Faction id → the value added to its track on the day of discovery.
var containment_at_discovery: Dictionary[String, float] = {}
## Story flags set at the origin.
var flags: Array[String] = []


static func name_key(scenario_id: String) -> String:
	return "SCENARIO_%s_NAME" % scenario_id.to_upper()


static func tagline_key(scenario_id: String) -> String:
	return "SCENARIO_%s_TAGLINE" % scenario_id.to_upper()


static func detail_key(scenario_id: String) -> String:
	return "SCENARIO_%s_DETAIL" % scenario_id.to_upper()


## The origin prompt's detail line with this scenario (§5).
static func intro_key(scenario_id: String) -> String:
	return "SCENARIO_%s_INTRO" % scenario_id.to_upper()


## The four keys every scenario must have in both languages.
static func string_keys(scenario_id: String) -> Array[String]:
	return [name_key(scenario_id), tagline_key(scenario_id), detail_key(scenario_id),
		intro_key(scenario_id)]


## The source a start status of this scenario runs under.
static func status_source(scenario_id: String) -> String:
	return Status.source_for(SOURCE_PREFIX, scenario_id)
