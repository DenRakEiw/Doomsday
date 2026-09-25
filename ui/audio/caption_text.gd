class_name CaptionText
extends RefCounted
## A sound caption as the line the stack shows (spec audio.md §8.3).
##
## Like `HeadlineText`, the conversion is a function of the argument's name
## alone: whatever a caption calls `{faction}` is a faction. Static and
## node-free.

const PREFIX_FACTION: String = "FACTION_"
const PREFIX_OUTCOME: String = "UI_OUTCOME_"
const PREFIX_ASSET: String = "ASSET_"
const SUFFIX_ASSET: String = "_NAME"
const PREFIX_REGION: String = "REGION_"
const PREFIX_PHASE: String = "UI_PHASE_"

const ARG_FACTION: String = "faction"
const ARG_OUTCOME: String = "outcome"
const ARG_KIND: String = "kind"
const ARG_REGION: String = "region"
## `phase_changed` carries `to`; the caption says `{phase}`.
const ARG_TO: String = "to"
const ARG_PHASE: String = "phase"


static func render(key: String, args: Dictionary) -> String:
	return _translate(key).format(converted(args))


## Every argument converted by its name, plus `phase` when `to` is a phase.
static func converted(args: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in args:
		var name: String = str(key)
		out[name] = _convert(name, args[key])
	var to: Variant = args.get(ARG_TO)
	if typeof(to) == TYPE_STRING and World.PHASE_IDS.has(str(to)):
		out[ARG_PHASE] = _translate(PREFIX_PHASE + str(to).to_upper())
	return out


static func _convert(name: String, value: Variant) -> String:
	var id: String = str(value).to_upper()
	match name:
		ARG_FACTION:
			return _translate(PREFIX_FACTION + id)
		ARG_OUTCOME:
			return _translate(PREFIX_OUTCOME + id)
		ARG_KIND:
			return _translate(PREFIX_ASSET + id + SUFFIX_ASSET)
		ARG_REGION:
			return _translate(PREFIX_REGION + id)
	return str(value)


## `tr` belongs to `Object`; a static function asks the server itself.
static func _translate(key: String) -> String:
	return String(TranslationServer.translate(key))
