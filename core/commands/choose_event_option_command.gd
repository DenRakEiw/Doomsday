class_name ChooseEventOptionCommand
extends Command
## Answers an open map event with one of its options (`loop-mechanics.md` §10.5).
##
## The event is named by the id it was opened under, so a log replays against
## the same event even when two of one definition stand at once. Whatever the
## option does is `EventSystem.answer`'s — the deadline takes the same path.

const TYPE_ID: String = "choose_event_option"

## `OpenEvent.id`.
var event: int
var option: String


func _init(p_event: int = 0, p_option: String = "") -> void:
	event = p_event
	option = p_option


func type_id() -> String:
	return TYPE_ID


## The five checks of §10.5, in order.
func validate(sim: Simulation) -> String:
	if sim.world.agent.origin == 0:
		return FAIL_NO_ORIGIN
	var open_event: OpenEvent = sim.world.event_by_id(event)
	if open_event == null:
		return FAIL_UNKNOWN_EVENT
	var def: EventDef = sim.db.event(open_event.def)
	if def == null:
		return FAIL_UNKNOWN_EVENT
	var chosen: EventOptionDef = def.option(option)
	if chosen == null:
		return FAIL_UNKNOWN_OPTION
	if not chosen.lock_reason(sim, open_event.region).is_empty():
		return FAIL_OPTION_LOCKED
	if sim.world.agent.compute < sim.option_cost(chosen):
		return FAIL_INSUFFICIENT_COMPUTE
	return ""


func execute(sim: Simulation, events: Array[SimEvent]) -> void:
	EventSystem.answer(sim, sim.world.event_by_id(event), option, false, events)


func to_dict() -> Dictionary:
	var d: Dictionary = super()
	d["event"] = event
	d["option"] = option
	return d
