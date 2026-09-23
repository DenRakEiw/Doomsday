class_name StatusLevelDef
extends RefCounted
## One level of a status: how long it lasts and what it does
## (`loop-mechanics.md` §7.1).
##
## A status is one condition with one or two intensities — a Lockdown at level 2
## is the same Lockdown, harder. Everything that differs between them lives here;
## everything that is true of the condition itself lives on `StatusDef`.
##
## The modifiers carry **no scope**: `StatusDef.scoped_modifiers` injects the
## region when the status is applied, because where a status acts is a property
## of the application and not of the content (§7.3).

## The keys a level entry allows.
const KEYS: Array[String] = ["days", "modifiers", "on_start", "on_end", "closes_links",
	"ends_statuses"]
## `days: 0` means standing: the status never expires on its own (D4.4,
## `chains.md` §11.2).
const DAYS_STANDING: int = 0

## How many days the level runs; 0 is standing.
var days: int = 0
## Unscoped in the file; scoped at application.
var modifiers: Array[ModifierDef] = []
var on_start: Array[EffectDef] = []
var on_end: Array[EffectDef] = []
## Link kinds this level closes in its region, or `["all"]`.
var closes_links: Array[String] = []
## Status ids ended in the same region when this level starts.
var ends_statuses: Array[String] = []


## Whether this level never expires by itself (§7.1).
func is_standing() -> bool:
	return days == DAYS_STANDING
