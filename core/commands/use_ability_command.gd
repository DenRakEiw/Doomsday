class_name UseAbilityCommand
extends Command
## Uses one of the agent's verbs (`loop-mechanics.md` §9.3).
##
## An ability is bought once as a technology node and used again and again: this
## command pays for it, starts its cooldown, and applies whatever the definition
## says it applies — a status, a deployment, or a list of one-shot effects.
##
## A region-target ability carries the region id; a global one ignores it, so a
## bot may pass one either way.

const TYPE_ID: String = "use_ability"

var ability: String
## Region id, or "" for a global ability.
var region: String


func _init(p_ability: String = "", p_region: String = "") -> void:
	ability = p_ability
	region = p_region


func type_id() -> String:
	return TYPE_ID


## The eight checks of §9.3, in order: what the agent cannot do at all comes
## before what it cannot afford, and the site comes last.
func validate(sim: Simulation) -> String:
	if sim.world.agent.origin == 0:
		return FAIL_NO_ORIGIN
	var definition: AbilityDef = sim.db.ability(ability)
	if definition == null:
		return FAIL_UNKNOWN_ABILITY
	if sim.ability_level(ability) == 0:
		return FAIL_ABILITY_LOCKED
	if sim.ability_ready_day(ability) > sim.world.day:
		return FAIL_ABILITY_COOLDOWN
	if sim.world.agent.compute < definition.cost:
		return FAIL_INSUFFICIENT_COMPUTE
	for effect: EffectDef in definition.applies_effects:
		var blocked: String = EffectRunner.blocker(sim, effect)
		if not blocked.is_empty():
			return blocked
	if not definition.targets_region():
		return ""
	if region.is_empty():
		return FAIL_SITE_REQUIRED
	if not sim.db.region_index_by_id.has(region):
		return FAIL_INVALID_REGION
	var index: int = sim.db.region_index_by_id[region]
	if definition.eligible != null and not definition.eligible.check(sim.world, index).is_empty():
		return FAIL_SITE_INELIGIBLE
	return ""


## Pay, start the cooldown, say it happened, then do it — `ability_used` first,
## because the interface announces the verb before what it caused.
func execute(sim: Simulation, events: Array[SimEvent]) -> void:
	var definition: AbilityDef = sim.db.ability(ability)
	var level: int = sim.ability_level(ability)
	var index: int = _region_index(sim, definition)
	sim.world.agent.compute -= definition.cost
	if definition.cooldown_days > 0:
		sim.world.agent.cooldowns[ability] = sim.world.day + definition.cooldown_days
	else:
		sim.world.agent.cooldowns.erase(ability)
	events.append(SimEvent.new(SimEvent.ABILITY_USED, sim.world.day, {
		"ability": ability,
		"region": "" if index == 0 else sim.world.regions[index].def.id,
		"level": level,
		"cost": definition.cost,
	}))
	_apply(sim, definition, level, index, events)


## Which region this use happens in; 0 for a global ability.
func _region_index(sim: Simulation, definition: AbilityDef) -> int:
	if not definition.targets_region():
		return 0
	return int(sim.db.region_index_by_id.get(region, 0))


func _apply(sim: Simulation, definition: AbilityDef, level: int, index: int,
		events: Array[SimEvent]) -> void:
	match definition.applies_kind:
		AbilityDef.APPLIES_STATUS:
			StatusSystem.apply(sim.world, sim.db, definition.applies_status, index,
				Status.source_for(Status.SOURCE_ABILITY, ability),
				definition.status_level_for(level), "", events)
		AbilityDef.APPLIES_DEPLOY:
			_deploy(sim, definition, index, events)
		AbilityDef.APPLIES_EFFECTS:
			EffectRunner.apply_all(sim, definition.applies_effects,
				EffectContext.for_ability(ability, index), events)


func _deploy(sim: Simulation, definition: AbilityDef, index: int,
		events: Array[SimEvent]) -> void:
	if index <= 0:
		return
	var held: int = sim.world.regions[index].asset_count(definition.applies_deploy_kind)
	sim.world.set_assets(index, definition.applies_deploy_kind,
		held + definition.applies_deploy_count)
	events.append(SimEvent.new(SimEvent.ASSET_DEPLOYED, sim.world.day, {
		"node": "",
		"ability": ability,
		"kind": definition.applies_deploy_kind,
		"region": sim.world.regions[index].def.id,
		"count": definition.applies_deploy_count,
	}))


func to_dict() -> Dictionary:
	var d: Dictionary = super()
	d["ability"] = ability
	d["region"] = region
	return d
