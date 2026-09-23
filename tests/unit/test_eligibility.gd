extends GutTest
## S4.1 — the eligibility grammar (`docs/specs/loop-mechanics.md` §5). One test
## per key, plus the two rules that hold over all of them: the keys are an AND,
## and the reason is the **first** failing key in `KEYS` order.

## The fixture's regions, by what each is useful for here.
const ORIGIN: int = 1
## fx_birch: infected in these tests, industry 3, on `west`.
const NEIGHBOUR: int = 2
## fx_elm: industry 0, on `east`.
const POOR: int = 5

var sim: Simulation


func before_each() -> void:
	sim = Fixtures.sim_with_origin()
	# Two infected regions to compare, and one that is not.
	sim.world.regions[NEIGHBOUR].penetration = 0.5
	sim.world.regions[NEIGHBOUR].seeded_day = 0


func _rule(d: Dictionary) -> Eligibility:
	return Eligibility.from_dict(d)


func test_an_empty_rule_is_none_and_takes_every_living_region() -> void:
	var rule: Eligibility = _rule({})
	assert_eq(rule.check(sim.world, ORIGIN), "")
	assert_eq(rule.check(sim.world, POOR), "", "a clean region is still a region")
	assert_eq(Eligibility.none().check(sim.world, ORIGIN), "")


func test_not_dark_applies_whether_it_was_asked_for_or_not() -> void:
	sim.world.regions[POOR].dark = true
	assert_eq(_rule({}).check(sim.world, POOR), Eligibility.REASON_DARK)
	assert_eq(_rule({"not_dark": true}).check(sim.world, POOR), Eligibility.REASON_DARK)
	assert_eq(_rule({}).check(sim.world, 0), Eligibility.REASON_DARK, "region 0 is nowhere")


func test_infected_passes_an_infected_region_and_fails_a_clean_one() -> void:
	var rule: Eligibility = _rule({"infected": true})
	assert_eq(rule.check(sim.world, NEIGHBOUR), "")
	assert_eq(rule.check(sim.world, POOR), Eligibility.REASON_NOT_INFECTED)


func test_not_dormant_fails_a_held_region() -> void:
	var rule: Eligibility = _rule({"not_dormant": true})
	assert_eq(rule.check(sim.world, NEIGHBOUR), "")
	sim.world.regions[NEIGHBOUR].dormant = true
	assert_eq(rule.check(sim.world, NEIGHBOUR), Eligibility.REASON_DORMANT)


func test_the_attribute_bounds_read_the_region_definition() -> void:
	var low: Eligibility = _rule({"attr_min": {"industry": 3}})
	assert_eq(low.check(sim.world, NEIGHBOUR), "", "fx_birch has industry 3")
	assert_eq(low.check(sim.world, POOR), Eligibility.REASON_ATTR_MIN)
	var high: Eligibility = _rule({"attr_max": {"industry": 1}})
	assert_eq(high.check(sim.world, POOR), "")
	assert_eq(high.check(sim.world, NEIGHBOUR), Eligibility.REASON_ATTR_MAX)


func test_the_asset_bounds_read_what_stands_there() -> void:
	var needs: Eligibility = _rule({"asset_min": {"lab": 1}})
	assert_eq(needs.check(sim.world, ORIGIN), Eligibility.REASON_ASSET_MIN)
	sim.world.set_assets(ORIGIN, AssetDef.KIND_LAB, 1)
	assert_eq(needs.check(sim.world, ORIGIN), "")
	var room: Eligibility = _rule({"asset_max": {"lab": 0}})
	assert_eq(room.check(sim.world, ORIGIN), Eligibility.REASON_ASSET_MAX)
	assert_eq(room.check(sim.world, NEIGHBOUR), "")


## Statuses arrive with S4.2; until then nothing is ever running, which is the
## answer the grammar gives — `status_present` fails, `status_absent` passes.
func test_the_status_keys_read_the_world() -> void:
	assert_eq(_rule({"status_absent": ["fx_dim"]}).check(sim.world, ORIGIN), "")
	assert_eq(_rule({"status_present": ["fx_dim"]}).check(sim.world, ORIGIN),
		Eligibility.REASON_STATUS_PRESENT)


func test_the_share_keys_compare_against_the_value() -> void:
	var penetration: Eligibility = _rule({"penetration_min": 0.4})
	assert_eq(penetration.check(sim.world, NEIGHBOUR), "")
	assert_eq(penetration.check(sim.world, ORIGIN), Eligibility.REASON_PENETRATION)
	sim.world.regions[NEIGHBOUR].control = 0.6
	var control: Eligibility = _rule({"control_min": 0.5})
	assert_eq(control.check(sim.world, NEIGHBOUR), "")
	assert_eq(control.check(sim.world, ORIGIN), Eligibility.REASON_CONTROL)


func test_continent_and_the_two_origin_keys() -> void:
	assert_eq(_rule({"continent": "west"}).check(sim.world, ORIGIN), "")
	assert_eq(_rule({"continent": "east"}).check(sim.world, ORIGIN),
		Eligibility.REASON_CONTINENT)
	assert_eq(_rule({"not_origin": true}).check(sim.world, ORIGIN), Eligibility.REASON_ORIGIN)
	assert_eq(_rule({"not_origin": true}).check(sim.world, NEIGHBOUR), "")
	assert_eq(_rule({"origin": true}).check(sim.world, ORIGIN), "")
	assert_eq(_rule({"origin": true}).check(sim.world, NEIGHBOUR),
		Eligibility.REASON_ORIGIN_ONLY)


func test_the_keys_are_an_and() -> void:
	var rule: Eligibility = _rule({"infected": true, "attr_min": {"industry": 3}})
	assert_eq(rule.check(sim.world, NEIGHBOUR), "", "both hold")
	sim.world.regions[POOR].penetration = 0.5
	assert_eq(rule.check(sim.world, POOR), Eligibility.REASON_ATTR_MIN,
		"infected, but the attribute does not hold")


## The reason is the first failing key in `KEYS` order, which is why the caption
## says *not infected* before *no lab there*.
func test_the_reason_is_the_first_failing_key() -> void:
	var rule: Eligibility = _rule({
		"infected": true,
		"attr_min": {"industry": 3},
		"asset_min": {"lab": 1},
	})
	assert_eq(rule.check(sim.world, POOR), Eligibility.REASON_NOT_INFECTED)
	sim.world.regions[POOR].penetration = 0.5
	assert_eq(rule.check(sim.world, POOR), Eligibility.REASON_ATTR_MIN)


func test_detail_carries_the_arguments_of_the_failing_reason() -> void:
	var attribute: Dictionary = _rule({"attr_min": {"industry": 3}}).detail(sim.world, POOR)
	assert_eq(attribute["attr"], "industry")
	assert_eq(attribute["tier"], 3)
	var asset: Dictionary = _rule({"asset_min": {"lab": 2}}).detail(sim.world, ORIGIN)
	assert_eq(asset["kind"], "lab")
	assert_eq(asset["count"], 2)
	var share: Dictionary = _rule({"penetration_min": 0.9}).detail(sim.world, ORIGIN)
	assert_almost_eq(float(share["value"]), 0.9, 1e-9)
	var continent: Dictionary = _rule({"continent": "east"}).detail(sim.world, ORIGIN)
	assert_eq(continent["continent"], "east")
	assert_eq(_rule({}).detail(sim.world, ORIGIN), {}, "a region that passes has no detail")


## §16.6: the detail pane lists what a rule asks for, whatever region is in view.
func test_requirements_lists_every_key_the_rule_carries() -> void:
	var rows: Array[Array] = _rule({
		"infected": true,
		"attr_min": {"industry": 2},
		"continent": "west",
	}).requirements()
	assert_eq(rows.size(), 3)
	assert_eq(rows[0][0], Eligibility.REASON_NOT_INFECTED)
	assert_eq(rows[1][0], Eligibility.REASON_ATTR_MIN)
	assert_eq(rows[2][0], Eligibility.REASON_CONTINENT)
	assert_eq(_rule({}).requirements().size(), 0)
