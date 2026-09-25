extends GutTest
## S6.8 — the map cursor's sentence about a region (accessibility.md §3.5), on the
## fixture world: each part is there exactly when it applies.

const REGION: String = "fx_alder"

var _locale: String = ""


func before_each() -> void:
	_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after_each() -> void:
	TranslationServer.set_locale(_locale)


func _index(simulation: Simulation, id: String = REGION) -> int:
	return int(simulation.db.region_index_by_id[id])


func _tr(key: String) -> String:
	return String(TranslationServer.translate(key))


func test_a_region_not_reached_says_its_name_and_so() -> void:
	var simulation: Simulation = Fixtures.sim()
	var index: int = _index(simulation)
	var line: String = RegionSpeech.line(simulation.world, index, null)
	assert_true(line.begins_with(_tr(RegionSpeech.KEY_NAME).format({
		"region": RegionSpeech.region_name(simulation.world, index)})))
	assert_string_contains(line, _tr(RegionSpeech.KEY_PRESENCE_NONE))
	for key: String in [RegionSpeech.KEY_DORMANT, RegionSpeech.KEY_ANOMALY,
			RegionSpeech.KEY_TASK_FORCE]:
		assert_false(line.contains(_tr(key)), key)


func test_a_reached_region_says_its_penetration() -> void:
	var simulation: Simulation = Fixtures.sim()
	var region: Region = simulation.world.regions[_index(simulation)]
	region.seeded_day = 0
	region.penetration = 0.25
	var line: String = RegionSpeech.line(simulation.world, _index(simulation), null)
	assert_string_contains(line, _tr(RegionSpeech.KEY_PRESENCE_REACHED).format({
		"penetration": Format.percent(0.25)}))


func test_a_controlled_region_says_both_figures() -> void:
	var simulation: Simulation = Fixtures.sim()
	var region: Region = simulation.world.regions[_index(simulation)]
	region.seeded_day = 0
	region.penetration = 0.5
	region.control = 0.2
	var line: String = RegionSpeech.line(simulation.world, _index(simulation), null)
	assert_string_contains(line, _tr(RegionSpeech.KEY_PRESENCE_CONTROLLED).format({
		"penetration": Format.percent(0.5), "control": Format.percent(0.2)}))


func test_a_dark_region_says_no_one_is_left() -> void:
	var simulation: Simulation = Fixtures.sim()
	simulation.world.regions[_index(simulation)].dark = true
	var line: String = RegionSpeech.line(simulation.world, _index(simulation), null)
	assert_string_contains(line, _tr(RegionSpeech.KEY_PRESENCE_DARK))


func test_a_dormant_region_says_so() -> void:
	var simulation: Simulation = Fixtures.sim()
	simulation.world.regions[_index(simulation)].dormant = true
	var line: String = RegionSpeech.line(simulation.world, _index(simulation), null)
	assert_string_contains(line, _tr(RegionSpeech.KEY_DORMANT))


func test_site_select_says_whether_the_region_will_do() -> void:
	var simulation: Simulation = Fixtures.sim()
	var index: int = _index(simulation)
	var open: SiteRequest = SiteRequest.new()
	open.eligible = func(_i: int) -> String: return ""
	var line: String = RegionSpeech.line(simulation.world, index, open)
	var name: String = RegionSpeech.region_name(simulation.world, index)
	assert_string_contains(line, _tr(RegionSpeech.KEY_SITE_OK).format({"region": name}))
	var closed: SiteRequest = SiteRequest.new()
	closed.eligible = func(_i: int) -> String: return Command.FAIL_INVALID_REGION
	line = RegionSpeech.line(simulation.world, index, closed)
	assert_string_contains(line, _tr(RegionSpeech.KEY_SITE_CLOSED).format({"region": name,
		"reason": closed.reason_text(index)}), "with its reason")


func test_assets_statuses_event_anomaly_and_team_each_say_their_part() -> void:
	var simulation: Simulation = Fixtures.sim_with_status(Fixtures.WORLD_STATUS, REGION)
	var world: World = simulation.world
	var index: int = _index(simulation)
	world.set_assets(index, AssetDef.KINDS[0], 2)
	var event: OpenEvent = Fixtures.open_event(simulation, Fixtures.OPENING_EVENT, REGION)
	var anomaly: Anomaly = Anomaly.new()
	anomaly.region = index
	world.anomalies.append(anomaly)
	world.task_force.state = TaskForce.STATE_REST
	world.task_force.region = index
	var line: String = RegionSpeech.line(world, index, null)
	assert_string_contains(line, _tr(RegionSpeech.KEY_ASSETS).format({"list":
		_tr(RegionSpeech.KEY_ASSET_ITEM).format({"count": 2,
			"kind": TechText.asset_name(AssetDef.KINDS[0], 2)})}))
	assert_string_contains(line, _tr(RegionSpeech.KEY_STATUSES).format({"list":
		_tr("STATUS_" + Fixtures.WORLD_STATUS.to_upper() + "_NAME")}))
	assert_string_contains(line, _tr(RegionSpeech.KEY_EVENT).format({"title":
		EventView.title(event.def, world, index)}))
	assert_string_contains(line, _tr(RegionSpeech.KEY_ANOMALY))
	assert_string_contains(line, _tr(RegionSpeech.KEY_TASK_FORCE))


func test_german_renders_in_german() -> void:
	var simulation: Simulation = Fixtures.sim()
	var region: Region = simulation.world.regions[_index(simulation)]
	region.seeded_day = 0
	region.penetration = 0.25
	TranslationServer.set_locale("de")
	var line: String = RegionSpeech.line(simulation.world, _index(simulation), null)
	assert_string_contains(line, "Durchdringung")
	assert_false(line.contains("{"), "every placeholder filled")


func test_no_region_is_an_empty_line() -> void:
	var simulation: Simulation = Fixtures.sim()
	assert_eq(RegionSpeech.line(simulation.world, 0, null), "")
