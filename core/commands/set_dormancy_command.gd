class_name SetDormancyCommand
extends Command
## Holds a region, or wakes it again (`docs/specs/tech-trees.md` §6.4).
##
## A dormant region is frozen and out of the infected share: it grows nothing,
## seeds nobody, yields nothing and kills nobody, and the humans there stop
## counting the agent's hardware as theirs. Waking resumes all of it where it
## left off.

const TYPE_ID: String = "set_dormancy"

var region: String
var dormant: bool


func _init(p_region: String = "", p_dormant: bool = true) -> void:
	region = p_region
	dormant = p_dormant


func type_id() -> String:
	return TYPE_ID


func validate(sim: Simulation) -> String:
	if sim.world.agent.origin == 0:
		return FAIL_NO_ORIGIN
	if not sim.db.region_index_by_id.has(region):
		return FAIL_INVALID_REGION
	if not sim.world.modifiers.has_flag(ModifierDef.FLAG_DORMANCY):
		return FAIL_DORMANCY_LOCKED
	var state: Region = sim.world.regions[sim.db.region_index_by_id[region]]
	if state.dark or state.penetration <= 0.0:
		return FAIL_REGION_NOT_INFECTED
	if state.dormant == dormant:
		return FAIL_DORMANCY_UNCHANGED
	return ""


func execute(sim: Simulation, events: Array[SimEvent]) -> void:
	var state: Region = sim.world.regions[sim.db.region_index_by_id[region]]
	state.dormant = dormant
	events.append(SimEvent.new(SimEvent.DORMANCY_CHANGED, sim.world.day,
		{"region": region, "dormant": dormant}))


func to_dict() -> Dictionary:
	var d: Dictionary = super()
	d["region"] = region
	d["dormant"] = dormant
	return d
