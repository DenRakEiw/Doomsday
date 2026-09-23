class_name SocietalFunctionSystem
extends SimSystem
## How well each region still runs (opposition.md §8).
##
## A disorder value 0…100 per region, fed by the `society_pressure` of whatever
## stands there and by its dead, recovering a little every day. Six stages cut
## the humans' containment capacity (`ContainmentSystem`) and the humans'
## hardware in the yield (`ComputeSystem`) — never the agent's own, which is
## what makes a machine substrate worth building.

const TARGET_PRESSURE: String = "society_pressure"
## The keys of one `balance.society.stages` entry.
const CAPACITY_MUL: String = "capacity_mul"
const YIELD_MUL: String = "yield_mul"
const SOCIETY_MAX: float = 100.0


func tick(world: World, db: ContentDB, events: Array[SimEvent]) -> void:
	if world.agent.origin == 0:
		return
	var balance: BalanceDef = db.balance
	for i: int in range(1, world.regions.size()):
		var region: Region = world.regions[i]
		if region.dark:
			continue
		var pressure: float = world.modifiers.value(TARGET_PRESSURE, region.def) \
			+ balance.society_deaths_weight * (region.deaths / float(region.def.population))
		var before: int = stage(region.society, balance)
		region.society = clampf(region.society + balance.society_gain_scale * pressure
			- balance.society_recovery_per_day, 0.0, SOCIETY_MAX)
		var after: int = stage(region.society, balance)
		if after != before:
			events.append(SimEvent.new(SimEvent.SOCIETY_STAGE_CHANGED, world.day, {
				"region": region.def.id,
				"from": before,
				"to": after,
			}))


## The stage a disorder value is in: how many thresholds it has reached, 0…5.
static func stage(value: float, balance: BalanceDef) -> int:
	var count: int = 0
	for threshold: float in balance.society_stage_thresholds:
		if value >= threshold:
			count += 1
	return count


## The share of their containment capacity the humans keep at this disorder.
static func capacity_mul(value: float, balance: BalanceDef) -> float:
	return float(balance.society_stages[stage(value, balance)][CAPACITY_MUL])


## The share of the humans' hardware that still yields at this disorder.
static func yield_mul(value: float, balance: BalanceDef) -> float:
	return float(balance.society_stages[stage(value, balance)][YIELD_MUL])
