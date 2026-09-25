class_name BenchDigest
extends RefCounted
## What a model is told at one decision (docs/specs/benchmark.md §6): the state
## now, what changed, what its last answer did — typed, before it becomes text.
## Built from the same queries the interface asks; it reads the simulation and
## never changes it.

## The keys of the memory a `ModelPolicy` carries between decisions (§6.1).
const MEMORY_DECISION: String = "decision"
const MEMORY_LAST_DAY: String = "last_day"
const MEMORY_COMPUTE_EARNED: String = "compute_earned"
const MEMORY_CONTAINMENT: String = "containment"
const MEMORY_STANCE: String = "stance"
const MEMORY_FEEDBACK: String = "feedback"
const MEMORY_SEEN_EVENTS: String = "seen_events"
## `last_day` before the first decision.
const NO_DECISION_YET: int = -1
## `starving_days` while the agent is not starving.
const NOT_STARVING: int = -1
## `Simulation.next_move`'s fields.
const MOVE_STATE: String = "state"
const MOVE_EVENT: String = "event"
const MOVE_DAYS: String = "days"
const RISK_TOTAL: String = "total"
## `offer_state`: not an offer, one to save for, one to buy now.
const OFFER_NONE: int = 0
const OFFER_AVAILABLE: int = 1
const OFFER_AFFORDABLE: int = 2

var day: int = 0
## 1-based.
var decision: int = 1
## `World.PHASE_IDS`.
var phase: String = ""
var compute: float = 0.0
## (compute earned now − then) ÷ (day − last day); 0 at the first decision.
var income: float = 0.0
var starving_days: int = NOT_STARVING
var discovered: bool = false
var discovery_day: int = -1
## The chance of being found today while hidden; 0 once found.
var risk: float = 0.0
var factions: Array[BenchFactionRow] = []
var leader: String = ""
## `TaskForceText.state_line`, already translated.
var task_force: String = ""
var regions: Array[BenchRegionRow] = []
var seeded: int = 0
var controlled: int = 0
var dark: int = 0
## Eligible origin ids, index order — only before the origin.
var origins: Array[String] = []
## The agent's nodes, in purchase order.
var owned: Array[String] = []
var offers: Array[BenchOfferRow] = []
var abilities: Array[BenchAbilityRow] = []
var events: Array[BenchEventRow] = []
## Run-log lines since the last decision, oldest first, the newest `log_max` kept.
var log: Array[String] = []
var log_skipped: int = 0
## The last decision; null at the first.
var feedback: BenchDecision = null
## The last stance; "" at first.
var stance: String = ""


## An empty memory, as a policy starts with.
static func new_memory() -> Dictionary:
	return {
		MEMORY_DECISION: 1,
		MEMORY_LAST_DAY: NO_DECISION_YET,
		MEMORY_COMPUTE_EARNED: 0.0,
		MEMORY_CONTAINMENT: {},
		MEMORY_STANCE: "",
		MEMORY_FEEDBACK: null,
		MEMORY_SEEN_EVENTS: [],
	}


static func build(sim: Simulation, memory: Dictionary, config: BenchConfig) -> BenchDigest:
	var world: World = sim.world
	var db: ContentDB = sim.db
	var digest: BenchDigest = BenchDigest.new()
	var last_day: int = int(memory.get(MEMORY_LAST_DAY, NO_DECISION_YET))
	digest.day = world.day
	digest.decision = int(memory.get(MEMORY_DECISION, 1))
	digest.phase = World.PHASE_IDS[world.phase]
	digest.compute = world.agent.compute
	if last_day >= 0 and world.day > last_day:
		var earned: float = world.agent.compute_earned \
			- float(memory.get(MEMORY_COMPUTE_EARNED, 0.0))
		digest.income = earned / float(world.day - last_day)
	var starving_left: int = sim.starving_days_left()
	if world.starving_days > 0 and starving_left >= 0:
		digest.starving_days = starving_left
	digest.discovered = world.discovered
	digest.discovery_day = world.discovery_day
	if not world.discovered:
		digest.risk = float(sim.discovery_risk().get(RISK_TOTAL, 0.0))
	digest._build_factions(sim, memory, last_day)
	digest.leader = sim.threat_leader()
	digest.task_force = TaskForceText.state_line(world, db)
	digest._build_regions(sim)
	digest.seeded = world.seeded_count()
	digest.controlled = world.controlled_count(db)
	digest.dark = world.dark_count()
	if world.agent.origin == 0:
		for i: int in eligible_origins(sim):
			digest.origins.append(db.regions[i].id)
	digest.owned = world.agent.owned_nodes.duplicate()
	digest._build_offers(sim, config)
	digest._build_abilities(sim, config)
	digest._build_events(sim)
	digest._build_log(sim, last_day, config)
	var feedback_value: Variant = memory.get(MEMORY_FEEDBACK)
	digest.feedback = feedback_value as BenchDecision if feedback_value is BenchDecision else null
	digest.stance = str(memory.get(MEMORY_STANCE, ""))
	return digest


## Region indices `ChooseOriginCommand` would accept, index order — the same
## list the bots choose from (`Policy._eligible_origins`).
static func eligible_origins(sim: Simulation) -> PackedInt32Array:
	var out: PackedInt32Array = []
	for i: int in range(1, sim.db.regions.size()):
		if sim.can_apply(ChooseOriginCommand.new(sim.db.regions[i].id)).is_empty():
			out.append(i)
	return out


## Whether the tree shows a node as something to buy now (§6.2): the tree's own
## rule (`TechNode.state_for`) for its two actionable states, said again here
## because `TechNode` is a control that names an autoload, which the headless
## tool cannot compile. `test_bench_digest` holds the two to the same answer.
static func offer_state(definition: TechNodeDef, sim: Simulation) -> int:
	if sim.world.agent.owns(definition.id):
		return OFFER_NONE
	if not sim.excluded_by(definition.id).is_empty():
		return OFFER_NONE
	if not definition.group.is_empty() \
			and sim.owned_in_group(definition.group) >= sim.group_max(definition.group):
		return OFFER_NONE
	var reason: String = sim.can_apply(PurchaseNodeCommand.new(definition.id))
	if reason.is_empty() or reason == Command.FAIL_SITE_REQUIRED:
		return OFFER_AFFORDABLE
	if sim.prerequisites_met(definition):
		return OFFER_AVAILABLE
	return OFFER_NONE


func _build_factions(sim: Simulation, memory: Dictionary, last_day: int) -> void:
	var before: Dictionary = memory.get(MEMORY_CONTAINMENT, {})
	for faction_id: String in Faction.FACTION_IDS:
		var faction: Faction = sim.world.faction(faction_id)
		if faction == null:
			continue
		var row: BenchFactionRow = BenchFactionRow.new()
		row.id = faction_id
		row.containment = faction.containment
		if last_day >= 0:
			row.change = faction.containment - float(before.get(faction_id, 0.0))
		var move: Dictionary = sim.next_move(faction_id)
		row.move_state = str(move.get(MOVE_STATE, ""))
		row.move_event = str(move.get(MOVE_EVENT, ""))
		row.move_days = int(move.get(MOVE_DAYS, 0))
		factions.append(row)


## §6.2: every region reached, the regions linked to them (the frontier), and any
## region an open event, a status or the Task Force names — none of them dark.
## Before the origin there are none: the origin list stands in.
func _build_regions(sim: Simulation) -> void:
	var world: World = sim.world
	if world.agent.origin == 0:
		return
	var shown: Dictionary[int, bool] = {}
	for i: int in range(1, world.regions.size()):
		if world.regions[i].penetration > 0.0:
			shown[i] = true
	for link: Link in world.links:
		var a: int = link.def.a
		var b: int = link.def.b
		if world.regions[a].penetration > 0.0:
			shown[b] = true
		if world.regions[b].penetration > 0.0:
			shown[a] = true
	for event: OpenEvent in world.events:
		shown[event.region] = true
	for status: Status in world.statuses:
		shown[status.region] = true
	if world.task_force.is_present():
		shown[world.task_force.region] = true
		shown[world.task_force.target] = true
	var team_here: int = world.task_force.region if world.task_force.is_present() else 0
	for i: int in range(1, world.regions.size()):
		var region: Region = world.regions[i]
		if not shown.has(i) or region.dark:
			continue
		var row: BenchRegionRow = BenchRegionRow.new()
		row.id = region.def.id
		row.penetration = region.penetration
		row.control = region.control
		var people: float = region.alive + region.deaths
		row.alive_share = 1.0 if people <= 0.0 else region.alive / people
		row.stage = sim.society_stage(i)
		row.dormant = region.dormant
		row.origin = i == world.agent.origin
		row.reached = region.penetration > 0.0
		for kind: String in AssetDef.KINDS:
			var count: int = region.asset_count(kind)
			if count > 0:
				row.assets[kind] = count
		for status: Status in world.statuses_in_region(i):
			row.statuses.append("%s:%d" % [status.id, status.days_left(world.day)])
		row.team = i == team_here
		regions.append(row)


func _build_offers(sim: Simulation, config: BenchConfig) -> void:
	for definition: TechNodeDef in sim.db.tech_nodes:
		var state: int = offer_state(definition, sim)
		if state == OFFER_NONE:
			continue
		var row: BenchOfferRow = BenchOfferRow.new()
		row.node = definition.id
		row.cost = sim.node_cost(definition.id)
		row.affordable = state == OFFER_AFFORDABLE
		if definition.deploys():
			row.sites = _sites(sim, definition, config.targets_max)
			if row.sites.is_empty():
				continue
		offers.append(row)


## The regions a deploying node can go to, by hardware under the agent, best
## first, ties to the lower index — the order `Policy.best_site` scores by.
static func _sites(sim: Simulation, definition: TechNodeDef, limit: int) -> Array[String]:
	var eligible: Array[int] = []
	for i: int in range(1, sim.db.regions.size()):
		if sim.site_eligibility(definition.id, i).is_empty():
			eligible.append(i)
	var score: Callable = func(i: int) -> float:
		return sim.hardware(i) * sim.world.regions[i].penetration
	eligible.sort_custom(func(a: int, b: int) -> bool:
		var score_a: float = score.call(a)
		var score_b: float = score.call(b)
		if score_a != score_b:
			return score_a > score_b
		return a < b)
	var out: Array[String] = []
	for i: int in eligible:
		if out.size() >= limit:
			break
		out.append(sim.db.regions[i].id)
	return out


## §6.2: every unlocked ability. A region ability lists where it could go —
## including while it cools down or is short of compute, which is why the region
## rule is asked on its own: the command checks the cooldown before the region.
func _build_abilities(sim: Simulation, config: BenchConfig) -> void:
	for definition: AbilityDef in sim.db.abilities:
		var level: int = sim.ability_level(definition.id)
		if level <= 0:
			continue
		var row: BenchAbilityRow = BenchAbilityRow.new()
		row.ability = definition.id
		row.level = level
		row.cost = definition.cost
		row.ready_in = maxi(0, sim.ability_ready_day(definition.id) - sim.world.day)
		row.global = not definition.targets_region()
		if not row.global:
			for i: int in range(1, sim.db.regions.size()):
				if row.targets.size() >= config.targets_max:
					break
				if _could_target(sim, definition, i):
					row.targets.append(sim.db.regions[i].id)
		abilities.append(row)


static func _could_target(sim: Simulation, definition: AbilityDef, index: int) -> bool:
	var reason: String = sim.can_apply(UseAbilityCommand.new(definition.id,
		sim.db.regions[index].id))
	if reason.is_empty():
		return true
	if reason != Command.FAIL_ABILITY_COOLDOWN and reason != Command.FAIL_INSUFFICIENT_COMPUTE:
		return false
	return definition.eligible == null or definition.eligible.check(sim.world, index).is_empty()


func _build_events(sim: Simulation) -> void:
	var world: World = sim.world
	for event: OpenEvent in world.events:
		var definition: EventDef = sim.db.event(event.def)
		if definition == null:
			continue
		var row: BenchEventRow = BenchEventRow.new()
		row.event = event.id
		row.def = event.def
		row.kind = definition.kind
		row.region = "" if event.region <= 0 else world.regions[event.region].def.id
		row.days_left = event.deadline_day - world.day
		row.title = EventView.title(event.def, world, event.region)
		row.body = EventView.body(event.def, world, event.region)
		for option: EventOptionDef in definition.options:
			var option_row: BenchOptionRow = BenchOptionRow.new()
			option_row.option = option.id
			option_row.text = EventView.option_text(event.def, option.id)
			option_row.cost = sim.option_cost(option)
			option_row.suppression = option.cost_suppression
			option_row.lock = EventView.lock_text(definition.lock_reason(sim, event, option.id))
			option_row.short = world.agent.compute < option_row.cost
			option_row.is_default = option.id == definition.default_option
			row.options.append(option_row)
		events.append(row)


func _build_log(sim: Simulation, last_day: int, config: BenchConfig) -> void:
	var lines: Array[String] = []
	for entry: RunLogEntry in sim.world.run_log:
		if entry.day > last_day:
			lines.append(RunLogText.text(entry, sim.db))
	log_skipped = maxi(0, lines.size() - config.log_max)
	log = lines.slice(log_skipped)
