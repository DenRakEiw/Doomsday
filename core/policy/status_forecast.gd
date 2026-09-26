class_name StatusForecast
extends RefCounted
## What a status would change over the days it runs, in the units a policy
## weighs an event option by (`Policy.W_*`): compute earned, region-points of
## penetration and control, footprint held for `Policy.FOOTPRINT_DAYS`, points
## of containment (G6 1/2, BALANCE §6.6).
##
## First order and read-only: each modifier of the level the status starts at
## changes the rate its target drives **today**, and that change runs for the
## status's days — no knock-on effects, no compounding. A bounded quantity
## (penetration, control, a track) is run both ways — at today's rate and at the
## changed one, each clamped to what the region or track can still gain or lose —
## and the difference counts, so slowing what fills up anyway costs little. A target whose daily effect is not one of those
## units (costs, harm, seeding, anomalies, capacity, the Task Force) counts 0,
## as every status did before.
##
## Never touches `world.rng` and never writes state: the policies call it
## between commands.


## Unit → amount over the status's days. Empty for an unknown status.
static func forecast(sim: Simulation, status_id: String, region: int, level: int,
		days_override: int) -> Dictionary[String, float]:
	var out: Dictionary[String, float] = {}
	var definition: StatusDef = sim.db.status(status_id)
	if definition == null or definition.levels.is_empty():
		return out
	var days: float = _days(sim.db, definition.level_at(level), days_override)
	for modifier: ModifierDef in definition.scoped_modifiers(level, region):
		_add_modifier(sim, modifier, days, out)
	return out


## A status with no end is weighed over the longest any timed status in the
## content runs: the horizon comes from the data, not from a number here.
static func standing_days(db: ContentDB) -> float:
	var longest: int = 0
	for status: StatusDef in db.statuses:
		for level: StatusLevelDef in status.levels:
			longest = maxi(longest, level.days)
	return float(longest)


static func _days(db: ContentDB, level: StatusLevelDef, days_override: int) -> float:
	if days_override > 0:
		return float(days_override)
	if level.is_standing():
		return standing_days(db)
	return float(level.days)


static func _add_modifier(sim: Simulation, modifier: ModifierDef, days: float,
		out: Dictionary[String, float]) -> void:
	var months: float = days / Policy.FOOTPRINT_DAYS
	match modifier.target:
		ComputeSystem.TARGET_YIELD:
			_add(out, Policy.W_COMPUTE, _regional(sim, modifier, days, _yield_rate))
		SpreadSystem.TARGET_SPREAD_GROWTH:
			_add(out, Policy.W_PENETRATION, _regional(sim, modifier, days, _growth_rate))
		SpreadSystem.TARGET_PENETRATION_DECAY:
			_add(out, Policy.W_PENETRATION, _regional(sim, modifier, days, _decay_rate))
		SpreadSystem.TARGET_CONTROL_GROWTH:
			_add(out, Policy.W_PENETRATION, _regional(sim, modifier, days, _control_rate))
		SpreadSystem.TARGET_CONTROL_DECAY:
			_add(out, Policy.W_PENETRATION,
				_regional(sim, modifier, days, _control_decay_rate))
		ModifierStack.TARGET_FOOTPRINT:
			_add(out, Policy.W_FOOTPRINT, _footprint(sim, modifier) * months)
		ContainmentSystem.TARGET_DISCOVERY:
			_add(out, Policy.W_FOOTPRINT, _discovery(sim, modifier) * months)
		ContainmentSystem.TARGET_CONTAINMENT_GROWTH:
			_add(out, Policy.W_CONTAINMENT, _containment(sim, modifier, days, ""))
		_:
			for faction: FactionDef in sim.db.factions:
				if faction.brake == modifier.target:
					_add(out, Policy.W_CONTAINMENT,
						_containment(sim, modifier, days, faction.id))


static func _add(out: Dictionary[String, float], unit: String, amount: float) -> void:
	if amount == 0.0:
		return
	out[unit] = float(out.get(unit, 0.0)) + amount


## How much a modifier changes its stat, as a share of the stat: `×m` is `m − 1`;
## `+v` is `v` over the stat as it stands, 0 when the stat is 0 (the rates below
## are all proportional to their stat, so a stat at 0 drives nothing to scale).
static func _relative(modifier: ModifierDef, stat: float) -> float:
	if modifier.op == ModifierDef.Op.MUL:
		return modifier.value - 1.0
	return modifier.value / stat if stat > 0.0 else 0.0


## Σ over the regions the modifier reaches of what the changed rate adds over
## the days (`_difference`). `rate` answers `[per_day, lowest, highest]`: what the
## target drives in the region today, and how far the region can move either way.
static func _regional(sim: Simulation, modifier: ModifierDef, days: float,
		rate: Callable) -> float:
	var total: float = 0.0
	for i: int in range(1, sim.world.regions.size()):
		var region: Region = sim.world.regions[i]
		if region.dark or region.dormant or not modifier.matches(region.def):
			continue
		var reading: Array[float] = rate.call(sim, i)
		if reading[0] == 0.0:
			continue
		total += _difference(reading[0], _relative(modifier, sim.stat(modifier.target, i)), days,
			reading[1], reading[2])
	return total


## `per_day × (1 + relative)` against `per_day` over the days, each clamped to
## `[lowest, highest]`.
static func _difference(per_day: float, relative: float, days: float, lowest: float,
		highest: float) -> float:
	var changed: float = clampf(per_day * (1.0 + relative) * days, lowest, highest)
	return changed - clampf(per_day * days, lowest, highest)


## Compute a region yields a day (`ComputeSystem`); a lost month is lost compute.
static func _yield_rate(sim: Simulation, index: int) -> Array[float]:
	var income: float = ComputeSystem.region_yield(sim.world, sim.db, index) \
		* sim.db.balance.compute_yield_scale
	return [income, -INF, INF]


## Penetration a region grows by a day (`SpreadSystem._grow`, logistic).
static func _growth_rate(sim: Simulation, index: int) -> Array[float]:
	var p: float = sim.world.regions[index].penetration
	var growth: float = sim.db.balance.spread_base_growth \
		* sim.stat(SpreadSystem.TARGET_SPREAD_GROWTH, index) * p * (1.0 - p)
	return [growth, -p, 1.0 - p]


## Penetration a region loses a day to decay, as a gain: a slower decay is kept.
static func _decay_rate(sim: Simulation, index: int) -> Array[float]:
	var p: float = sim.world.regions[index].penetration
	var decay: float = sim.stat(SpreadSystem.TARGET_PENETRATION_DECAY, index)
	if p <= 0.0 or decay <= 0.0:
		return [0.0, 0.0, 0.0]
	var survival: float = sim.stat(SpreadSystem.TARGET_SHUTDOWN_SURVIVAL, index)
	return [-p * decay * (1.0 - survival), -p, 1.0 - p]


## Control a region gains a day (`SpreadSystem._control`).
static func _control_rate(sim: Simulation, index: int) -> Array[float]:
	var region: Region = sim.world.regions[index]
	var threshold: float = sim.db.balance.control_threshold
	if region.penetration <= threshold:
		return [0.0, 0.0, 0.0]
	var gain: float = sim.db.balance.control_rate * (region.penetration - threshold) \
		/ (1.0 - threshold) * sim.stat(SpreadSystem.TARGET_CONTROL_GROWTH, index)
	return [gain, -region.control, 1.0 - region.control]


## Control a region loses a day, as a gain.
static func _control_decay_rate(sim: Simulation, index: int) -> Array[float]:
	var region: Region = sim.world.regions[index]
	if region.control <= 0.0:
		return [0.0, 0.0, 0.0]
	var decay: float = sim.stat(SpreadSystem.TARGET_CONTROL_DECAY, index)
	return [-decay, -region.control, 1.0 - region.control]


## Footprint added, in footprint units — the unit `footprint_pulse` is weighed in.
static func _footprint(sim: Simulation, modifier: ModifierDef) -> float:
	if modifier.op == ModifierDef.Op.ADD:
		return modifier.value
	return (modifier.value - 1.0) * sim.world.footprint()


## A discovery factor, as the footprint that would change today's risk as much —
## and nothing once the world knows.
static func _discovery(sim: Simulation, modifier: ModifierDef) -> float:
	var factor: float = sim.stat(ContainmentSystem.TARGET_DISCOVERY)
	var per_footprint: float = sim.db.balance.discovery_per_footprint
	if sim.world.discovered or factor <= 0.0 or per_footprint <= 0.0:
		return 0.0
	var risk: Dictionary = sim.discovery_risk()
	var raw: float = float(risk[ContainmentSystem.RISK_TIME]) \
		+ float(risk[ContainmentSystem.RISK_FOOTPRINT]) \
		+ float(risk[ContainmentSystem.RISK_BREADTH])
	return _relative(modifier, factor) * raw / (factor * per_footprint)


## Containment gained over the days by one faction (`only`), or by every faction
## the global brake reaches when `only` is empty. A track that does not grow
## today (before discovery) gains nothing either way.
static func _containment(sim: Simulation, modifier: ModifierDef, days: float,
		only: String) -> float:
	var total: float = 0.0
	for faction: Faction in sim.world.factions:
		if not only.is_empty() and faction.id != only:
			continue
		if not _grows(sim, faction.id):
			continue
		# `labs_from_day_one`: nothing aimed at the world slows the labs' track.
		if only.is_empty() and ContainmentSystem.holds_steady(sim.world, sim.db, faction.id):
			continue
		var gain: float = ContainmentSystem.gain(sim.world, sim.db, faction.id)
		var stat: float = sim.stat(modifier.target)
		total += _difference(gain, _relative(modifier, stat), days, -faction.containment,
			1.0 - faction.containment)
	return total


static func _grows(sim: Simulation, faction_id: String) -> bool:
	if sim.world.discovered:
		return true
	return faction_id == Faction.ID_AI_LABS and ContainmentSystem.labs_watch(sim.world, sim.db)
