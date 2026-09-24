class_name Policy
extends RefCounted
## A bot that plays through the same interface the player does.
##
## A policy reads the simulation and returns commands; it never writes state, and
## it **never touches `world.rng`** — it draws from its own generator, so that
## changing a policy cannot shift the world's random stream and invalidate every
## baseline measured before it.
##
## `next_command` is called repeatedly within a day until it returns null.

## A policy that wants more than this in one day is looping, not playing.
const MAX_COMMANDS_PER_DAY: int = 64
## `seed_for` puts the policy's stream far enough from the world's that
## neighbouring seeds do not give neighbouring policies.
const SEED_FACTOR: int = 7919
const SEED_OFFSET: int = 17

## The effect families an event option is scored on (`answer_event`). A weight
## is what one unit is worth to the policy, in compute: one compute granted, one
## footprint held for `FOOTPRINT_DAYS`, one region seeded, a harm burst of 1, one
## point of containment (×4 for all factions), one asset, a counter-move's status
## endured, one ×1 of penetration.
const W_COMPUTE: String = "compute"
const W_FOOTPRINT: String = "footprint"
const W_SEED: String = "seed"
const W_HARM: String = "harm"
const W_CONTAINMENT: String = "containment"
const W_ASSET: String = "asset"
const W_ASSET_LOST: String = "asset_lost"
const W_ENDURE: String = "endure"
const W_PENETRATION: String = "penetration"
## A footprint pulse is weighed per month it lasts.
const FOOTPRINT_DAYS: float = 30.0

## The region attribute a region-target ability is aimed by (S4.10): the one it
## feeds on or hurts most. Ties go to the lower index.
const ABILITY_TARGET_ATTR: Dictionary[String, String] = {
	"harvest": "compute", "squeeze": "wealth", "blackout": "industry",
	"halt": "manufacturing", "reroute": "connectivity", "silence": "population",
	"suppress": "population", "lobby": "wealth", "fabricate": "industry",
}
## An ability that answers a counter-move is used only where its status stands.
const ABILITY_ANSWERS: Dictionary[String, Array] = {
	"lobby": ["lockdown", "rationing", "audit"],
	"suppress": ["protest"],
}
## Abilities that pay for themselves keep no reserve.
const INCOME_ABILITIES: Array[String] = ["harvest", "squeeze"]
## Harvest silences its region for a month: a run with fewer regions starves on it.
const HARVEST: String = "harvest"
const HARVEST_MIN_SEEDED: int = 6
## Pause is for a world that is closing in, not a habit.
const PAUSE: String = "pause"
const PAUSE_CONTAINMENT: float = 0.5
## A target with the answered status, or anywhere but the origin for Harvest,
## outranks any attribute difference.
const TARGET_BONUS: float = 100.0

## The policy's own stream. Seeded by `setup`, never the world's.
var _rng: SimRng = null
var _db: ContentDB = null
## What an event option's effects are worth to this policy; empty means it
## answers every event with its default.
var _weights: Dictionary[String, float] = {}


## The policy with this id, or null. Both the headless runners and the `Game`
## autoload make their bots here, so a new policy is registered once.
static func create(id: String) -> Policy:
	if id == IdlePolicy.ID:
		return IdlePolicy.new()
	if id == GreedyPolicy.ID:
		return GreedyPolicy.new()
	if id == StealthPolicy.ID:
		return StealthPolicy.new()
	if id == CyberRushPolicy.ID:
		return CyberRushPolicy.new()
	if id == StealthSpreadPolicy.ID:
		return StealthSpreadPolicy.new()
	if id == PersuaderPolicy.ID:
		return PersuaderPolicy.new()
	if id == CyberPolicy.ID:
		return CyberPolicy.new()
	if id == BiologyPolicy.ID:
		return BiologyPolicy.new()
	if id == RoboticsPolicy.ID:
		return RoboticsPolicy.new()
	if id == WeaponsPolicy.ID:
		return WeaponsPolicy.new()
	if id == PersuasionPolicy.ID:
		return PersuasionPolicy.new()
	return null


## The bots a report runs (S4.10, loop-redesign §9): the floor, the impatient
## first run, and one per intended strategy.
static func ids() -> Array[String]:
	return [IdlePolicy.ID, GreedyPolicy.ID, CyberPolicy.ID, BiologyPolicy.ID, RoboticsPolicy.ID,
		WeaponsPolicy.ID, PersuasionPolicy.ID]


## The bots of S1.8 and S3.6 that the second generation replaced. `create` still
## makes them — the debug keys and a comparison with an old baseline use them —
## but a report runs them only when asked for by name.
static func legacy_ids() -> Array[String]:
	return [StealthPolicy.ID, CyberRushPolicy.ID, StealthSpreadPolicy.ID, PersuaderPolicy.ID]


## The stream a policy gets for a world seed.
static func seed_for(seed_value: int) -> int:
	return seed_value * SEED_FACTOR + SEED_OFFSET


func policy_id() -> String:
	return ""


func setup(db: ContentDB, policy_seed: int) -> void:
	_db = db
	_rng = SimRng.from_seed(policy_seed)


## The next command for today, or null when the policy is done for the day.
@warning_ignore("unused_parameter")
func next_command(sim: Simulation) -> Command:
	return null


## The oldest open event answered, or null when none is open. Every policy asks
## this first: a bot never lets a deadline decide, so batch runs stay comparable
## and no command is rejected for an event that expired (`loop-mechanics.md`
## §19). A policy without weights answers with the default; one with weights
## answers by them (`answer_event`, S4.10).
func answer_events(sim: Simulation) -> Command:
	if sim.world.events.is_empty():
		return null
	var event: OpenEvent = sim.world.events[0]
	var def: EventDef = sim.db.event(event.def)
	if def == null:
		return null
	return ChooseEventOptionCommand.new(event.id, answer_event(sim, event, def))


## loop-redesign §9: the option a policy picks, by rule and never at random. Each
## option the command would accept is scored on the effects it lists — the
## weights say what this strategy wants — and the best wins; the default wins
## every tie, so a policy that cares about nothing an option does leaves it be.
func answer_event(sim: Simulation, event: OpenEvent, def: EventDef) -> String:
	if _weights.is_empty():
		return def.default_option
	var best: String = def.default_option
	var best_score: float = -INF
	for option: EventOptionDef in def.options:
		if not sim.can_apply(ChooseEventOptionCommand.new(event.id, option.id)).is_empty():
			continue
		var score: float = option_score(sim, event, def, option)
		if score > best_score or (score == best_score and option.id == def.default_option):
			best = option.id
			best_score = score
	return best


## What an option is worth to this policy: its effects, its chances weighted by
## their probability, its cost in compute, and the status a counter-move leaves
## behind unless the option skips it.
func option_score(sim: Simulation, event: OpenEvent, def: EventDef,
		option: EventOptionDef) -> float:
	var score: float = -sim.option_cost(option) * _weight(W_COMPUTE)
	for effect: EffectDef in option.effects:
		score += _effect_score(sim, event.region, effect)
	for branch: EventChanceDef in option.chance:
		for effect: EffectDef in branch.effects:
			score += branch.p * _effect_score(sim, event.region, effect)
	if not def.status.is_empty() and not option.skip_status:
		score += _weight(W_ENDURE)
	return score


func _effect_score(sim: Simulation, region: int, effect: EffectDef) -> float:
	match effect.effect:
		EffectDef.COMPUTE_GRANT:
			var amount: float = effect.value
			if effect.per_hardware:
				amount *= sim.hardware(region) if region > 0 else sim.stat("hardware")
			return amount * _weight(W_COMPUTE)
		EffectDef.FOOTPRINT_PULSE:
			return effect.value * float(effect.days) / FOOTPRINT_DAYS * _weight(W_FOOTPRINT)
		EffectDef.SEED_NEIGHBOURS:
			return float(effect.count) * _weight(W_SEED)
		EffectDef.HARM_BURST:
			return effect.value * _weight(W_HARM)
		EffectDef.CONTAINMENT_ADD:
			var factions: float = float(Faction.FACTION_IDS.size()) \
				if effect.faction == EffectDef.FACTION_ALL else 1.0
			return effect.value * factions * _weight(W_CONTAINMENT)
		EffectDef.CONTAINMENT_ROLLBACK, EffectDef.FUNDING_RESET:
			return -effect.value * _weight(W_CONTAINMENT)
		EffectDef.GRANT_ASSETS:
			return float(effect.count) * _weight(W_ASSET)
		EffectDef.DESTROY_ASSETS:
			return float(effect.count) * _weight(W_ASSET_LOST)
		EffectDef.PENETRATION_MUL:
			return (effect.value - 1.0) * _weight(W_PENETRATION)
		EffectDef.CONTROL_ADD:
			return effect.value * _weight(W_PENETRATION)
	return 0.0


func _weight(key: String) -> float:
	return float(_weights.get(key, 0.0))


## Region indices that `ChooseOriginCommand` would accept, in index order.
func _eligible_origins(sim: Simulation) -> PackedInt32Array:
	var out: PackedInt32Array = []
	for i: int in range(1, sim.db.regions.size()):
		if sim.can_apply(ChooseOriginCommand.new(sim.db.regions[i].id)).is_empty():
			out.append(i)
	return out


## Where a bot would place what a deploying node puts on the map: the eligible
## region with the most hardware actually under the agent, ties to the lower
## index. "" when the node can go nowhere, which is what makes the bot buy
## something else instead (`loop-mechanics.md` §19).
func best_site(sim: Simulation, node: TechNodeDef) -> String:
	var best: int = 0
	var best_score: float = 0.0
	for i: int in range(1, sim.db.regions.size()):
		if not sim.site_eligibility(node.id, i).is_empty():
			continue
		var score: float = sim.hardware(i) * sim.world.regions[i].penetration
		if best == 0 or score > best_score:
			best = i
			best_score = score
	return "" if best == 0 else sim.db.regions[best].id


## The first of `ability_ids` that is unlocked, ready, affordable with `reserve`
## left over, and has somewhere to go (S4.10). Null when none does.
func _use_ability(sim: Simulation, ability_ids: Array[String], reserve: float) -> Command:
	for ability_id: String in ability_ids:
		var def: AbilityDef = sim.db.ability(ability_id)
		if def == null or sim.ability_level(ability_id) == 0:
			continue
		if sim.ability_ready_day(ability_id) > sim.world.day:
			continue
		var keep: float = 0.0 if INCOME_ABILITIES.has(ability_id) else reserve
		if sim.world.agent.compute - def.cost < keep:
			continue
		if ability_id == HARVEST and sim.world.seeded_count() < HARVEST_MIN_SEEDED:
			continue
		if ability_id == PAUSE and sim.world.max_containment() < PAUSE_CONTAINMENT:
			continue
		# A redirect answers the Task Force (`_answer_task_force`) and nothing else.
		if _redirects(def):
			continue
		var command: Command = _ability_command(sim, def)
		if command != null:
			return command
	return null


## `taskforce-endings.md` §9: while the Task Force sets up where the agent is, an
## ability that redirects it (found by its effect, not its name) sends it to the
## region with no presence farthest from it — ties to the lower index. Null when
## there is nothing to answer or nothing to answer with.
func _answer_task_force(sim: Simulation) -> Command:
	var team: TaskForce = sim.world.task_force
	# A region put to sleep against the team wakes once the team is not setting up
	# there any more — nothing else in the bots makes a region dormant.
	for i: int in range(1, sim.world.regions.size()):
		if not sim.world.regions[i].dormant:
			continue
		if team.state == TaskForce.STATE_SETUP and team.region == i:
			continue
		var wake: SetDormancyCommand = SetDormancyCommand.new(sim.db.regions[i].id, false)
		if sim.can_apply(wake).is_empty():
			return wake
	if team.state != TaskForce.STATE_SETUP or sim.world.regions[team.region].penetration <= 0.0:
		return null
	# §9: dormancy first, where the run has it — the setup then finds nothing.
	var sleep: SetDormancyCommand = SetDormancyCommand.new(sim.db.regions[team.region].id, true)
	if sim.can_apply(sleep).is_empty():
		return sleep
	var hops: PackedInt32Array = TaskForceRules.distances(sim.world, team.region)
	var decoy: int = 0
	for i: int in range(1, sim.world.regions.size()):
		var region: Region = sim.world.regions[i]
		if region.dark or region.penetration > 0.0 or hops[i] < 0:
			continue
		if decoy == 0 or hops[i] > hops[decoy]:
			decoy = i
	if decoy == 0:
		return null
	for def: AbilityDef in sim.db.abilities:
		if not _redirects(def):
			continue
		var command: UseAbilityCommand = UseAbilityCommand.new(def.id, sim.db.regions[decoy].id)
		if sim.can_apply(command).is_empty():
			return command
	return null


static func _redirects(def: AbilityDef) -> bool:
	for effect: EffectDef in def.applies_effects:
		if effect.effect == EffectDef.TASK_FORCE_REDIRECT:
			return true
	return false


## The ability aimed at its best region, or null when it can go nowhere.
func _ability_command(sim: Simulation, def: AbilityDef) -> Command:
	if def.target == AbilityDef.TARGET_GLOBAL:
		var global: UseAbilityCommand = UseAbilityCommand.new(def.id, "")
		return global if sim.can_apply(global).is_empty() else null
	var answers: Array = ABILITY_ANSWERS.get(def.id, [])
	var attr: String = str(ABILITY_TARGET_ATTR.get(def.id, ""))
	var best: int = 0
	var best_score: float = 0.0
	for i: int in range(1, sim.db.regions.size()):
		var command: UseAbilityCommand = UseAbilityCommand.new(def.id, sim.db.regions[i].id)
		if not sim.can_apply(command).is_empty():
			continue
		var answering: bool = false
		for status: Variant in answers:
			answering = answering or sim.world.has_status(str(status), i)
		if not answers.is_empty() and not answering:
			continue
		var score: float = float(sim.db.regions[i].attr(attr)) if not attr.is_empty() else 0.0
		if answering or (def.id == HARVEST and i != sim.world.agent.origin):
			score += TARGET_BONUS
		if best == 0 or score > best_score:
			best = i
			best_score = score
	if best == 0:
		return null
	return UseAbilityCommand.new(def.id, sim.db.regions[best].id)


## The oldest anomaly on the map — `world.anomalies` is in spawn order.
func _collect_oldest(sim: Simulation) -> Command:
	if sim.world.anomalies.is_empty():
		return null
	return CollectAnomalyCommand.new(sim.world.anomalies[0].id)


## The cheapest node that is available and affordable. Ties go to the tree that
## comes first in `tree_order`, then to the lower id — a total order, so the same
## seed always buys the same things.
func _cheapest_affordable(sim: Simulation, tree_order: Array[String],
		skip_trees: Array[String]) -> Command:
	return _cheapest_allowed(sim, tree_order,
		func(node: TechNodeDef) -> bool: return not skip_trees.has(node.tree))


## The same choice, with `allows` deciding node by node — which is how the
## strategy bots of S3.6 express "this branch, up to this tier, not yet".
func _cheapest_allowed(sim: Simulation, tree_order: Array[String],
		allows: Callable) -> Command:
	var best: TechNodeDef = null
	var best_cost: float = 0.0
	var best_site_id: String = ""
	for node: TechNodeDef in sim.available_nodes():
		if not bool(allows.call(node)):
			continue
		var cost: float = sim.node_cost(node.id)
		if cost > sim.world.agent.compute:
			continue
		# `available_nodes` only means "prerequisites met": a node that is
		# group-full, closed by an exclusion or short of assets is still in the
		# list, and buying it would be a rejected command.
		var site: String = best_site(sim, node) if node.deploys() else ""
		if node.deploys() and site.is_empty():
			continue
		if not sim.can_apply(PurchaseNodeCommand.new(node.id, site)).is_empty():
			continue
		if best == null or _is_better(node, cost, best, best_cost, tree_order):
			best = node
			best_cost = cost
			best_site_id = site
	if best == null:
		return null
	return PurchaseNodeCommand.new(best.id, best_site_id)


## The first of `node_ids` that can be bought right now, or null. A bot names
## the nodes its strategy is about and falls back to `_cheapest_allowed` for the
## rest — on content that has none of them (a test fixture) it simply buys
## nothing by name.
func _first_buyable(sim: Simulation, node_ids: Array[String]) -> Command:
	for node_id: String in node_ids:
		var node: TechNodeDef = sim.db.tech(node_id)
		if node == null:
			continue
		var site: String = best_site(sim, node) if node.deploys() else ""
		if node.deploys() and site.is_empty():
			continue
		var command: PurchaseNodeCommand = PurchaseNodeCommand.new(node_id, site)
		if sim.can_apply(command).is_empty():
			return command
	return null


## The cheapest affordable node of one Capabilities branch, up to `max_tier`.
func _cheapest_in_branch(sim: Simulation, branch: String, max_tier: int,
		tree_order: Array[String]) -> Command:
	return _cheapest_allowed(sim, tree_order, func(node: TechNodeDef) -> bool:
		return node.branch() == branch and node.tier <= max_tier)


## How many nodes of a tree the run owns — "vectors" for infiltration tier 1.
static func _owned_in_tree(sim: Simulation, tree: String, tier: int = 0) -> int:
	var count: int = 0
	for node_id: String in sim.world.agent.owned_nodes:
		var node: TechNodeDef = sim.db.tech(node_id)
		if node != null and node.tree == tree and (tier == 0 or node.tier == tier):
			count += 1
	return count


func _is_better(node: TechNodeDef, cost: float, best: TechNodeDef, best_cost: float,
		tree_order: Array[String]) -> bool:
	if cost != best_cost:
		return cost < best_cost
	var rank: int = tree_order.find(node.tree)
	var best_rank: int = tree_order.find(best.tree)
	if rank != best_rank:
		return rank < best_rank
	return node.id < best.id
