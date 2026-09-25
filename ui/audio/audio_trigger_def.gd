class_name AudioTriggerDef
extends RefCounted
## One trigger of `data/audio.json` (spec audio.md §4.4): which source, which
## condition, which cue. The first that matches decides.

## The sources a trigger listens to (§4.4).
const ON_SIM: String = "sim"
const ON_BUS: String = "bus"
const ON_ROUTER: String = "router"
const ON_COMMAND_REJECTED: String = "command_rejected"
const ON_BUTTON: String = "button"
const ON_CALL: String = "call"
const ONS: Array[String] = [ON_SIM, ON_BUS, ON_ROUTER, ON_COMMAND_REJECTED, ON_BUTTON, ON_CALL]
## The two `EventBus` signals the sheet may name (§5.1).
const SIGNAL_SPEED_CHANGED: String = "speed_changed"
const SIGNAL_REGION_SELECTED: String = "region_selected"
const SIGNALS: Array[String] = [SIGNAL_SPEED_CHANGED, SIGNAL_REGION_SELECTED]

var on: String = ""
## A `SimEvent` type (`on` = `sim`).
var type: String = ""
## An `EventBus` signal (`on` = `bus`).
var signal_name: String = ""
## Where a `call` trigger is called from — documentation only.
var site: String = ""
## The sheet's `match`: field → condition (§4.5); empty holds always. Not
## named `match`, which is a GDScript keyword.
var conditions: Dictionary = {}
## A cue id, or a template with `{field}` placeholders (§4.6).
var cue: String = ""
## Multiplies the jitter's draw.
var pitch: float = 1.0
