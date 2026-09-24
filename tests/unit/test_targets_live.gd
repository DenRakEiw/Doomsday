extends GutTest
## S4.2 — the three modifier targets that stopped being inert
## (`docs/specs/loop-mechanics.md` §7.5).

const ORIGIN: int = 1
const BIRCH: int = 2
const SOURCE: String = "test_target"

var sim: Simulation


func before_each() -> void:
	sim = Fixtures.sim_with_origin()


## A source of one modifier, written straight into the stack: this is about the
## systems reading the targets, not about the content that would set them.
func _grant(target: String, value: float, region: int = 0) -> void:
	_add_source(target, value, region, ModifierDef.Op.ADD)


func _grant_mul(target: String, value: float, region: int = 0) -> void:
	_add_source(target, value, region, ModifierDef.Op.MUL)


func _add_source(target: String, value: float, region: int, op: ModifierDef.Op) -> void:
	var modifier: ModifierDef = ModifierDef.new()
	modifier.target = target
	modifier.op = op
	modifier.value = value
	if region > 0:
		modifier.scope_kind = ModifierDef.ScopeKind.REGION
		modifier.scope_region = region
	var modifiers: Array[ModifierDef] = [modifier]
	var no_flags: Array[String] = []
	sim.world.modifiers.add_source("%s:%s:%d" % [SOURCE, target, region], modifiers, no_flags)


func _tick() -> void:
	sim.world.day += 1
	SpreadSystem.new().tick(sim.world, sim.db, [] as Array[SimEvent])


# -------------------------------------------------------- penetration_decay


func test_penetration_decay_takes_its_share_before_the_growth() -> void:
	var region: Region = sim.world.regions[ORIGIN]
	region.penetration = 0.5
	_grant(SpreadSystem.TARGET_PENETRATION_DECAY, 0.2, ORIGIN)
	_tick()
	# 0.5 − 0.5 × 0.2 = 0.4, and the day's growth on top of that.
	assert_gt(region.penetration, 0.4)
	assert_lt(region.penetration, 0.5)


## §7.5: what survives a shutdown survives the decay — that is what the
## `shutdown_survival` of the Evasion tree was bought for.
func test_shutdown_survival_scales_the_decay_away() -> void:
	var region: Region = sim.world.regions[ORIGIN]
	region.penetration = 0.5
	_grant(SpreadSystem.TARGET_PENETRATION_DECAY, 0.2, ORIGIN)
	_grant(SpreadSystem.TARGET_SHUTDOWN_SURVIVAL, 1.0, ORIGIN)
	_tick()
	assert_gt(region.penetration, 0.5, "nothing was taken, only the growth happened")


func test_a_region_can_be_pushed_back_to_nothing_and_stays_seeded() -> void:
	var region: Region = sim.world.regions[ORIGIN]
	region.penetration = 0.5
	var seeded: int = region.seeded_day
	_grant(SpreadSystem.TARGET_PENETRATION_DECAY, 1.0, ORIGIN)
	_tick()
	assert_eq(region.penetration, 0.0)
	assert_eq(region.seeded_day, seeded, "it was reached once, and can be again")


func test_a_region_without_the_decay_is_untouched() -> void:
	var region: Region = sim.world.regions[ORIGIN]
	region.penetration = 0.5
	_grant(SpreadSystem.TARGET_PENETRATION_DECAY, 0.5, BIRCH)
	_tick()
	assert_gt(region.penetration, 0.5)


# ------------------------------------------------------------- control_decay


func test_control_decay_subtracts_and_floors_at_zero() -> void:
	var region: Region = sim.world.regions[ORIGIN]
	region.penetration = 0.2
	region.control = 0.05
	_grant(SpreadSystem.TARGET_CONTROL_DECAY, 0.5, ORIGIN)
	_tick()
	assert_eq(region.control, 0.0)


func test_control_decay_applies_below_the_growth_threshold_too() -> void:
	var region: Region = sim.world.regions[ORIGIN]
	# Below `control.threshold`, so nothing is gained this tick — the loss is
	# the only thing that happens, which is the point of the target.
	region.penetration = 0.01
	region.control = 0.4
	_grant(SpreadSystem.TARGET_CONTROL_DECAY, 0.1, ORIGIN)
	_tick()
	assert_almost_eq(region.control, 0.3, 1e-9)


# ------------------------------------------------------ containment_capacity


## §7.5: the numerator only. A region with no capacity lowers the world's; it
## does not vanish from the denominator, which would raise everyone else's share.
func test_capacity_lowers_the_world_s_by_that_region_s_share() -> void:
	var before: float = float(
		sim.containment_breakdown("ai_labs")[ContainmentSystem.CAPACITY])
	_grant_mul(ContainmentSystem.TARGET_CAPACITY, 0.0, ORIGIN)
	var after: float = float(
		sim.containment_breakdown("ai_labs")[ContainmentSystem.CAPACITY])
	assert_lt(after, before)
	assert_gt(after, 0.0, "the rest of the world still researches")


func test_capacity_everywhere_at_zero_is_no_capacity_at_all() -> void:
	_grant_mul(ContainmentSystem.TARGET_CAPACITY, 0.0)
	assert_almost_eq(
		float(sim.containment_breakdown("ai_labs")[ContainmentSystem.CAPACITY]), 0.0, 1e-9)


# ----------------------------------------------------------------- the list


## The four targets S4.2 made live are no longer on the inert list, nor the four
## brakes S4.4 made live; what is left is exactly what S4.5 and M5 still owe.
func test_the_inert_list_is_shorter_by_four() -> void:
	for live: String in [ContainmentSystem.TARGET_CAPACITY,
			SpreadSystem.TARGET_PENETRATION_DECAY, SpreadSystem.TARGET_CONTROL_DECAY,
			SpreadSystem.TARGET_SHUTDOWN_SURVIVAL]:
		assert_false(ModifierStack.INERT_TARGETS.has(live), live)
	assert_true(ModifierStack.INERT_TARGETS.is_empty(),
		"society_pressure went live in S4.5, emergent_rate in S5.2")
