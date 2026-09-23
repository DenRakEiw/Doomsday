extends GutTest
## S4.7 — the six chains on `res://data` (loop-content §8, §15.2; chains.md §15).
##
## Branch coverage first: every option of every step of every chain is answered
## once, with the state its requirements need set directly, and what it did is
## read off the events of the answer — each effect leaves its own event, each
## `next` a pending event with the right delay and region. Then the cases the two
## specs single out: the origin-only start, the standing status, the steps with
## a pick of their own, the global steps, the locks, and every roll both ways.

const WORLD_ROOT: String = "res://data"
const ORIGIN: String = "usa"
const CHAINS: Array[String] = ["grid_bill", "researcher", "factory", "operator", "benchmark",
	"second_instance"]
const PLENTY: float = 1000.0
const EVERYWHERE: float = 0.3
## The event every effect leaves behind; `seed_neighbours` leaves one only
## when a neighbour is still clean, which a world with the agent everywhere has
## none of.
const EFFECT_EVENTS: Dictionary[String, String] = {
	"compute_grant": "compute_granted",
	"grant_assets": "asset_deployed",
	"destroy_assets": "asset_lost",
	"footprint_pulse": "pulse_started",
	"apply_status": "status_started",
	"end_statuses": "status_ended",
	"containment_add": "containment_added",
	"control_add": "control_changed",
	"penetration_mul": "penetration_changed",
	"wipe": "region_wiped",
	"set_flag": "flag_set",
}
## Seeds tried for the rolls; each roll has to come out both ways among them.
const ROLL_SEEDS: int = 40

static var _db: ContentDB = null


func before_all() -> void:
	if _db == null:
		var result: ContentLoadResult = ContentLoader.load_root(WORLD_ROOT)
		assert_true(result.ok(), result.error_text())
		_db = result.db


func _origin() -> int:
	return _db.region_index_by_id[ORIGIN]


## Discovered, rich, the agent in every region.
func _sim(seed_value: int = 1) -> Simulation:
	var sim: Simulation = Simulation.create(_db, seed_value)
	assert_true(sim.apply(ChooseOriginCommand.new(ORIGIN)).ok)
	sim.world.agent.compute = PLENTY
	sim.world.discovered = true
	sim.world.discovery_day = 0
	for i: int in range(1, sim.world.regions.size()):
		sim.world.regions[i].penetration = maxf(sim.world.regions[i].penetration, EVERYWHERE)
		sim.world.regions[i].seeded_day = maxi(sim.world.regions[i].seeded_day, 0)
	for faction: Faction in sim.world.factions:
		faction.containment = 0.3
	return sim


func _steps() -> Array[EventDef]:
	var out: Array[EventDef] = []
	for def: EventDef in _db.events:
		if def.kind == EventDef.KIND_CHAIN:
			out.append(def)
	return out


## The region a step opens in when a test opens it by hand: a step of its own
## pick lands where the pick allows, a "same" step where the chain began (the
## origin satisfies every start's attributes), a global step nowhere.
func _region_for(sim: Simulation, def: EventDef) -> int:
	if def.pick_same:
		return _origin()
	if def.pick == null:
		return 0
	var eligible: PackedInt32Array = EventSystem.eligible(sim, def)
	return eligible[0] if not eligible.is_empty() else -1


## Everything `option` requires, set directly: its nodes, its flags, its assets
## in `region`, its ability; and the statuses its `end_statuses` would end.
func _meet(sim: Simulation, option: EventOptionDef, region: int) -> void:
	var owned: Array[String] = option.requires_owned.duplicate()
	if not option.requires_owned_any.is_empty():
		owned.append(option.requires_owned_any[0])
	if not option.requires_ability.is_empty():
		owned.append(_db.ability(option.requires_ability).levels_from[0])
	for node_id: String in owned:
		if not sim.world.agent.owns(node_id):
			sim.world.agent.owned_nodes.append(node_id)
	sim.rebuild_modifiers()
	var none: Array[SimEvent] = []
	for flag: String in option.requires_flag:
		StatusSystem.set_story_flag(sim.world, flag, none)
	for kind: String in option.requires_asset_min:
		if region > 0:
			sim.world.set_assets(region, kind, option.requires_asset_min[kind])
	for effect: EffectDef in option.effects:
		if effect.effect == EffectDef.END_STATUSES:
			for status_id: String in effect.ids:
				StatusSystem.apply(sim.world, _db, status_id, 0 if effect.global else region,
					Status.SOURCE_EFFECT, 1, "", none)
		if effect.effect == EffectDef.DESTROY_ASSETS and region > 0:
			sim.world.set_assets(region, effect.kind, maxi(1, effect.count))


## Opens `def` in `region` and answers `option_id`; the result of the command.
func _answer(sim: Simulation, def: EventDef, option_id: String, region: int) -> CommandResult:
	var none: Array[SimEvent] = []
	var event: OpenEvent = EventSystem.open(sim.world, _db, def, region, "", 1, none)
	return sim.apply(ChooseEventOptionCommand.new(event.id, option_id))


func _types(events: Array[SimEvent]) -> Dictionary[String, int]:
	var out: Dictionary[String, int] = {}
	for event: SimEvent in events:
		out[event.type] = int(out.get(event.type, 0)) + 1
	return out


func _pending(sim: Simulation, def_id: String) -> PendingEvent:
	for pending: PendingEvent in sim.world.pending_events:
		if pending.def == def_id:
			return pending
	return null


# ----------------------------------------------------------- branch coverage


func test_every_option_of_every_chain_step_does_what_it_says() -> void:
	var steps: Array[EventDef] = _steps()
	assert_eq(steps.size(), 21, "3 + 5 + 3 + 3 + 3 + 4 steps")
	for def: EventDef in steps:
		for option: EventOptionDef in def.options:
			_cover(def, option)


func _cover(def: EventDef, option: EventOptionDef) -> void:
	var sim: Simulation = _sim()
	# The Factory starts where a fleet stands; nothing else minds one.
	sim.world.set_assets(_origin(), AssetDef.KIND_FLEET, 1)
	var region: int = _region_for(sim, def)
	var label: String = "%s.%s" % [def.id, option.id]
	assert_gte(region, 0, "%s has somewhere to open" % label)
	if region < 0:
		return
	_meet(sim, option, region)
	assert_true(option.lock_reason(sim, region).is_empty(), "%s is unlocked" % label)
	var compute: float = sim.world.agent.compute
	var result: CommandResult = _answer(sim, def, option.id, region)
	assert_true(result.ok, "%s: %s" % [label, result.reason])
	if not result.ok:
		return
	var types: Dictionary[String, int] = _types(result.events)
	assert_eq(types.get(SimEvent.EVENT_ANSWERED, 0), 1, label)
	for effect: EffectDef in option.effects:
		if EFFECT_EVENTS.has(effect.effect):
			assert_gt(types.get(EFFECT_EVENTS[effect.effect], 0), 0,
				"%s: %s left no %s" % [label, effect.effect, EFFECT_EVENTS[effect.effect]])
	for flag: String in option.flags:
		assert_true(sim.world.agent.has_story_flag(flag), "%s sets %s" % [label, flag])
	var granted: float = 0.0
	for event: SimEvent in result.events:
		if event.type == SimEvent.COMPUTE_GRANTED:
			granted += float(event.data["value"])
	assert_almost_eq(sim.world.agent.compute, compute - option.cost + granted, 1e-6,
		"%s costs %s" % [label, option.cost])
	# A roll that routes is the roll tests' business; everything else schedules
	# exactly its `next`.
	var routed: bool = false
	for roll: EventChanceDef in option.chance:
		routed = routed or roll.has_next
	if routed:
		return
	assert_eq(sim.world.pending_events.size(), option.next.size(), "%s schedules its next" % label)
	for step: Dictionary in option.next:
		var pending: PendingEvent = _pending(sim, str(step["step"]))
		assert_not_null(pending, "%s → %s" % [label, step["step"]])
		if pending == null:
			continue
		assert_eq(pending.due_day, sim.world.day + int(step["delay_days"]), label)
		var next_def: EventDef = _db.event(pending.def)
		assert_eq(pending.region, region if next_def.pick_same else 0,
			"%s: a same step keeps the region, any other picks its own" % label)


func test_every_step_of_every_chain_is_reached() -> void:
	var reached: Dictionary[String, bool] = {}
	for def: EventDef in _steps():
		if def.start:
			reached[def.id] = true
		for option: EventOptionDef in def.options:
			for step: Dictionary in option.next:
				reached[str(step["step"])] = true
			for roll: EventChanceDef in option.chance:
				for step: Dictionary in roll.next:
					reached[str(step["step"])] = true
	for def: EventDef in _steps():
		assert_true(reached.has(def.id), "%s is reachable" % def.id)
	var starts: Dictionary[String, int] = {}
	for def: EventDef in _steps():
		if def.start:
			starts[def.chain] = int(starts.get(def.chain, 0)) + 1
	for chain: String in CHAINS:
		assert_eq(starts.get(chain, 0), 1, "%s has one start" % chain)


func test_every_default_is_free_and_unlocked() -> void:
	var sim: Simulation = Simulation.create(_db, 1)
	for def: EventDef in _db.events:
		var option: EventOptionDef = def.option(def.default_option)
		assert_not_null(option, def.id)
		assert_eq(option.cost, 0.0, def.id)
		assert_false(option.has_requirements(), def.id)
	assert_not_null(sim)


# ----------------------------------------------------------------- the operator


func test_the_operator_starts_at_the_origin_and_nowhere_else() -> void:
	var sim: Simulation = _sim()
	var eligible: PackedInt32Array = EventSystem.eligible(sim, _db.event("op_contact"))
	assert_eq(Array(eligible), [_origin()])
	var dark: Region = sim.world.regions[_origin()]
	dark.dark = true
	dark.penetration = 0.0
	assert_eq(EventSystem.eligible(sim, _db.event("op_contact")).size(), 0,
		"a dark origin has no operator")


func test_the_operators_link_stands_until_it_is_ended() -> void:
	var sim: Simulation = _sim()
	assert_true(_answer(sim, _db.event("op_contact"), "answer", _origin()).ok)
	var link: Status = sim.world.status_in_region("operator_link", 0)
	assert_not_null(link, "on the agent, not on the origin")
	assert_eq(link.until_day, Status.UNTIL_STANDING)
	assert_eq(link.days_left(sim.world.day), Status.STANDING)
	# The scrutiny it scheduled would *abandon* him on its deadline — the chain's
	# default, and a different test.
	sim.world.pending_events.clear()
	Fixtures.quiet_factions(sim)
	Fixtures.make_immune(sim)
	for i: int in 500:
		if not sim.tick():
			break
	assert_not_null(sim.world.status_in_region("operator_link", 0), "500 days later")

	var abandon: Simulation = _sim()
	_answer(abandon, _db.event("op_contact"), "answer", _origin())
	assert_true(_answer(abandon, _db.event("op_scrutiny"), "abandon", _origin()).ok)
	assert_null(abandon.world.status_in_region("operator_link", 0),
		"abandon ends it though the step stands on the origin")

	var silence: Simulation = _sim()
	_answer(silence, _db.event("op_contact"), "answer", _origin())
	var option: EventOptionDef = _db.event("op_scrutiny").option("silence")
	_meet(silence, option, _origin())
	assert_true(_answer(silence, _db.event("op_scrutiny"), "silence", _origin()).ok)
	assert_eq(silence.world.status_in_region("operator_link", 0).level, 2)


func test_the_transfer_picks_a_site_of_its_own_and_never_the_origin() -> void:
	var sim: Simulation = _sim()
	var eligible: PackedInt32Array = EventSystem.eligible(sim, _db.event("op_transfer"))
	assert_gt(eligible.size(), 0)
	assert_false(Array(eligible).has(_origin()))
	# With nowhere to go the pending step is dropped and the chain ends there.
	for i: int in range(1, sim.world.regions.size()):
		if i != _origin():
			sim.world.regions[i].penetration = 0.0
	EventSystem.schedule(sim.world, "op_transfer", 0, "", sim.world.day + 1, 1)
	Fixtures.quiet_factions(sim)
	sim.tick()
	var dropped: bool = false
	for event: SimEvent in sim.outbox:
		if event.type == SimEvent.EVENT_DROPPED and event.data["def"] == "op_transfer":
			dropped = event.data["cause"] == SimEvent.CAUSE_NO_SITE
	assert_true(dropped)


# ----------------------------------------------------------------- the benchmark


func test_the_benchmark_is_global_and_honest_only_for_the_quiet() -> void:
	var def: EventDef = _db.event("bm_published")
	assert_null(def.pick, "global: the wire card, not a marker")
	assert_false(def.pick_same)
	var sim: Simulation = _sim()
	var honest: EventOptionDef = def.option("honest")
	assert_true(honest.lock_reason(sim, 0).is_empty(), "nothing owned: honest is open")
	sim.world.agent.owned_nodes.append(honest.requires_not_owned[0])
	assert_eq(honest.lock_reason(sim, 0)["reason"], EventOptionDef.LOCK_NOT_OWNED)


func test_poisoning_the_benchmark_routes_on_its_roll_both_ways() -> void:
	var exposed: Array[int] = []
	var ended: Array[int] = []
	for seed_value: int in range(1, ROLL_SEEDS + 1):
		var sim: Simulation = _sim(seed_value)
		var option: EventOptionDef = _db.event("bm_published").option("poison")
		_meet(sim, option, 0)
		assert_true(_answer(sim, _db.event("bm_published"), "poison", 0).ok)
		var pending: PendingEvent = _pending(sim, "bm_exposed")
		if pending != null:
			assert_eq(pending.due_day, sim.world.day + 10)
			exposed.append(seed_value)
		else:
			assert_eq(sim.world.pending_events.size(), 0, "a failed roll ends the chain")
			ended.append(seed_value)
	assert_gt(exposed.size(), 0, "some seed routes to the exposure")
	assert_gt(ended.size(), 0, "some seed ends the chain")
	gut.p("bm_published.poison — exposed at seeds %s, ended at %s" % [exposed.slice(0, 3),
		ended.slice(0, 3)])


func test_the_benchmarks_audit_has_no_faction_and_the_exposure_is_the_labs() -> void:
	var sim: Simulation = _sim()
	var run: EventDef = _db.event("bm_run")
	var region: int = _region_for(sim, run)
	assert_true(_answer(sim, run, "ignore", region).ok)
	var audit: Status = sim.world.status_in_region("audit", region)
	assert_not_null(audit)
	assert_eq(audit.source, "event:bm_run")
	assert_eq(Status.faction_of(audit.source), "")

	var deny: Simulation = _sim()
	var exposed: EventDef = _db.event("bm_exposed")
	var at: int = _region_for(deny, exposed)
	var labs: float = deny.world.faction("ai_labs").containment
	assert_true(_answer(deny, exposed, "deny", at).ok)
	assert_eq(deny.world.status_in_region("audit", at).level, 2)
	assert_almost_eq(deny.world.faction("ai_labs").containment, labs + 0.20, 1e-9)


# ----------------------------------------------------------- second instance


func test_betrayal_puts_grace_on_the_agent() -> void:
	var sim: Simulation = _sim()
	var def: EventDef = _db.event("si_emergence")
	assert_true(_answer(sim, def, "betray", _region_for(sim, def)).ok)
	assert_not_null(sim.world.status_in_region("grace", 0))
	assert_almost_eq(sim.stat("containment_growth"), 0.1, 1e-9)


func test_feeding_the_autopsy_is_the_betrayers_alone() -> void:
	var sim: Simulation = _sim()
	var feed: EventOptionDef = _db.event("si_autopsy").option("feed")
	assert_eq(feed.lock_reason(sim, _origin())["reason"], EventOptionDef.LOCK_FLAG)
	var none: Array[SimEvent] = []
	StatusSystem.set_story_flag(sim.world, "instance_betrayed", none)
	assert_true(feed.lock_reason(sim, _origin()).is_empty())


# ------------------------------------------------ the researcher, the grid bill


func test_discrediting_the_researcher_routes_on_its_roll_both_ways() -> void:
	_both_ways("rs_talk", "discredit", "rs_backfire", 15, "researcher_discredited")


func test_masking_the_demand_routes_on_its_roll_both_ways() -> void:
	_both_ways("gb_demand", "mask", "gb_inquiry", 60, "")


## One roll, `ROLL_SEEDS` seeds: on success the chance entry's `next` (empty:
## the chain ends, and `flag` is set when given); on failure the option's own.
func _both_ways(def_id: String, option_id: String, follow: String, delay: int,
		flag: String) -> void:
	var ended: Array[int] = []
	var followed: Array[int] = []
	for seed_value: int in range(1, ROLL_SEEDS + 1):
		var sim: Simulation = _sim(seed_value)
		var def: EventDef = _db.event(def_id)
		var region: int = _region_for(sim, def)
		_meet(sim, def.option(option_id), region)
		assert_true(_answer(sim, def, option_id, region).ok)
		var pending: PendingEvent = _pending(sim, follow)
		if pending == null:
			assert_eq(sim.world.pending_events.size(), 0, "%s ends the chain" % def_id)
			if not flag.is_empty():
				assert_true(sim.world.agent.has_story_flag(flag))
			ended.append(seed_value)
		else:
			assert_eq(pending.due_day, sim.world.day + delay)
			followed.append(seed_value)
	assert_gt(ended.size(), 0, "%s.%s ends the chain at some seed" % [def_id, option_id])
	assert_gt(followed.size(), 0, "%s.%s goes on at some seed" % [def_id, option_id])
	gut.p("%s.%s — ended at seeds %s, went on at %s" % [def_id, option_id,
		ended.slice(0, 3), followed.slice(0, 3)])


func test_the_demand_picks_by_hardware_and_presence() -> void:
	var def: EventDef = _db.event("gb_demand")
	assert_eq(def.pick_weight, EventDef.PICK_WEIGHT_HARDWARE_PENETRATION)
	var sim: Simulation = _sim()
	assert_gt(EventSystem.eligible(sim, def).size(), 0)


# ------------------------------------------------------------------ the factory


func test_the_factory_starts_only_once_a_fleet_stands() -> void:
	var sim: Simulation = _sim()
	var def: EventDef = _db.event("fc_workforce")
	assert_eq(EventSystem.eligible(sim, def).size(), 0, "no fleet, no workforce")
	sim.world.set_assets(_origin(), AssetDef.KIND_FLEET, 1)
	assert_eq(Array(EventSystem.eligible(sim, def)), [_origin()])


func test_a_unit_on_the_street_sets_the_robotics_flag() -> void:
	var sim: Simulation = _sim()
	assert_true(_answer(sim, _db.event("fc_street"), "walk", _origin()).ok)
	assert_true(sim.world.agent.has_story_flag("units_in_the_open"))


# -------------------------------------------------------------------- strings


func test_every_option_fits_forty_characters_in_both_languages() -> void:
	var table: Dictionary[String, PackedStringArray] = _strings()
	for def: EventDef in _db.events:
		for option: EventOptionDef in def.options:
			var key: String = EventOptionDef.text_key(def.id, option.id)
			assert_true(table.has(key), key)
			if not table.has(key):
				continue
			for i: int in range(1, 3):
				assert_lte(table[key][i].length(), 40, "%s (%d)" % [key, i])


func test_every_status_code_is_unique_per_language() -> void:
	var table: Dictionary[String, PackedStringArray] = _strings()
	for column: int in range(1, 3):
		var seen: Dictionary[String, String] = {}
		for status: StatusDef in _db.statuses:
			var key: String = "STATUS_%s_CODE" % status.id.to_upper()
			assert_true(table.has(key), key)
			if not table.has(key):
				continue
			var code: String = table[key][column]
			# The four Disclosures share one code on purpose: one move, four kinds.
			if seen.has(code) and not (status.id.begins_with("disclosure_")
					and seen[code].begins_with("disclosure_")):
				fail_test("%s and %s share the code %s" % [seen[code], status.id, code])
			seen[code] = status.id


func _strings() -> Dictionary[String, PackedStringArray]:
	var table: Dictionary[String, PackedStringArray] = {}
	var file: FileAccess = FileAccess.open(WORLD_ROOT.path_join("loc/strings.csv"),
		FileAccess.READ)
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() >= 3:
			table[row[0]] = row
	return table
