class_name ChooseOriginCommand
extends Command
## Where the run starts. The first command of every game; nothing else happens
## until it is accepted, because every system returns at once without an origin.

const TYPE_ID: String = "choose_origin"

## Region id, not index — a log must survive a re-indexed world.
var region: String


func _init(p_region: String = "") -> void:
	region = p_region


func type_id() -> String:
	return TYPE_ID


func validate(sim: Simulation) -> String:
	if sim.world.agent.origin != 0:
		return FAIL_ORIGIN_ALREADY_CHOSEN
	var definition: RegionDef = sim.db.region_by_id(region)
	if definition == null:
		return FAIL_INVALID_REGION
	# An air-gapped region has no way in, and a region without hardware has
	# nothing to run on.
	if definition.air_gapped or definition.attr("compute") <= 0:
		return FAIL_REGION_NOT_ELIGIBLE
	return ""


func execute(sim: Simulation, events: Array[SimEvent]) -> void:
	var index: int = sim.db.region_index_by_id[region]
	sim.world.agent.origin = index
	sim.world.origin_day = sim.world.day
	var home: Region = sim.world.regions[index]
	home.penetration = sim.db.balance.spread_origin_penetration
	home.seeded_day = sim.world.day
	events.append(SimEvent.new(SimEvent.ORIGIN_CHOSEN, sim.world.day, {"region": region}))


func to_dict() -> Dictionary:
	var d: Dictionary = super()
	d["region"] = region
	return d
