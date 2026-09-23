extends GutTest
## S4.5 — Autophagy on the game's content (opposition.md §17): a Cyber agent
## that Blackouts and Harvests the only region it lives in, every time the
## cooldowns allow, collapses that society, stops earning and eats itself —
## unless Autonomous Fabrication has made it its own substrate.
##
## The spec's acceptance names `sim_run --script=<command log>`; a log cannot
## say "every cooldown", so the script is this policy, played by the test.
## Seed 1; nobody hunts the agent (discovery off, factions quiet), so the only
## way the run can end is the one under test.

const SEED: int = 1
const ORIGIN: String = "usa"
const CYBER_NODES: Array[String] = ["edge_caching", "regional_blackout"]
const FABRICATION: String = "autonomous_fabrication"
const ABILITIES: Array[String] = ["blackout", "harvest"]
const LIMIT: int = 900

var _db: ContentDB = null


func before_all() -> void:
	var result: ContentLoadResult = ContentLoader.load_root("res://data")
	assert_true(result.ok(), result.error_text())
	_db = result.db


func _sim(own_fabrication: bool) -> Simulation:
	var sim: Simulation = Simulation.create(_db, SEED)
	assert_true(sim.apply(ChooseOriginCommand.new(ORIGIN)).ok)
	for node_id: String in CYBER_NODES:
		sim.world.agent.owned_nodes.append(node_id)
	if own_fabrication:
		sim.world.agent.owned_nodes.append(FABRICATION)
	sim.rebuild_modifiers()
	var never: Array[ModifierDef] = [ModifierDef.new()]
	never[0].target = "discovery"
	never[0].op = ModifierDef.Op.MUL
	never[0].value = 0.0
	var no_flags: Array[String] = []
	sim.world.modifiers.add_source("test:unseen", never, no_flags)
	Fixtures.quiet_factions(sim)
	return sim


## Both abilities on every region the agent holds, whenever they are ready.
func _play(sim: Simulation) -> void:
	for day: int in LIMIT:
		sim.world.agent.compute = maxf(sim.world.agent.compute, 100.0)
		for ability: String in ABILITIES:
			for i: int in range(1, sim.world.regions.size()):
				if sim.world.regions[i].penetration <= 0.0:
					continue
				var command: UseAbilityCommand = UseAbilityCommand.new(ability,
					sim.world.regions[i].def.id)
				if sim.can_apply(command).is_empty():
					sim.apply(command)
		if not sim.tick():
			return


func test_the_cyber_script_ends_in_autophagy() -> void:
	var sim: Simulation = _sim(false)
	_play(sim)
	assert_eq(World.OUTCOME_IDS[sim.world.outcome], "lose_autophagy",
		"after %d days, society %s" % [sim.world.day,
			sim.world.regions[sim.world.agent.origin].society])
	# A Harvest stands 30 days and yields nothing, and 30 days of nothing is
	# the end: on a single region the first Harvest is already fatal, long
	# before the society collapses (PROGRESS, *Design questions*, for G4).
	assert_eq(sim.world.starving_days, _db.balance.society_autophagy_days)


func test_with_autonomous_fabrication_the_same_script_never_starves() -> void:
	var sim: Simulation = _sim(true)
	_play(sim)
	assert_ne(World.OUTCOME_IDS[sim.world.outcome], "lose_autophagy")
	assert_eq(sim.world.starving_days, 0)
