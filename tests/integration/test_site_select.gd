extends GutTest
## S4.1 — site select in a running session (`docs/specs/loop-mechanics.md`
## §16.1). The origin, a deploying node's site and the map's own answer are one
## mode, so the test drives all three through the same strip and the same panel.

const SESSION: PackedScene = preload("res://game/session/session.tscn")
const TechTree: GDScript = preload("res://ui/panels/tech_tree.gd")
const TechDetail: GDScript = preload("res://ui/panels/tech_detail.gd")
const SEED: int = 1
## The one deploying node the shipped content has at S4.1 (§2).
const DEPLOY_NODE: String = "logistics_fleets"
## The origin the shipped world starts the test in; industry 4, so the fleet may
## stand there.
const ORIGIN: String = "usa"

var _session: Control = null
var _prompt: PanelContainer = null
var _panel: SlidePanel = null
var _map: MapView = null
var _tree: TechTree = null
var _detail: TechDetail = null
var _reduced_motion: bool = false


func before_each() -> void:
	_reduced_motion = Settings.reduced_motion
	Settings.set_reduced_motion(true)
	Game.stop_run()
	Game.debug_log = false
	_session = SESSION.instantiate()
	add_child_autofree(_session)
	_prompt = _session.get_node("HudLayer/SafeArea/Hud/Layout/SitePrompt")
	_panel = _session.get_node("PanelLayer/RegionPanel")
	_map = _session.get_node("MapLayer/MapView")
	_tree = _session.get_node("ModalLayer/ModalHost/TechTree")
	_detail = _tree.get_node("%TechDetail")


func after_each() -> void:
	Settings.set_reduced_motion(_reduced_motion)
	Game.stop_run()


func _button() -> ConsoleButton:
	return _panel.get_node("%OriginButton") as ConsoleButton


func _note() -> Label:
	return _panel.get_node("%OriginNote") as Label


func _select(region_id: String) -> int:
	var index: int = Game.db.region_index_by_id[region_id]
	EventBus.region_selected.emit(index)
	return index


## The run as the player finds it: the origin prompt is up, and the map outlines
## every region the run could start in.
func test_the_origin_is_one_site_request_among_three() -> void:
	Game.start_run(SEED)
	assert_not_null(Game.site_request, "the session enters the mode on `run_started`")
	assert_eq(Game.site_request.kind, SiteRequest.KIND_ORIGIN)
	assert_true(_prompt.visible)
	assert_false((_prompt.get_node("%SiteCancel") as Control).visible,
		"there is nothing behind the run's first decision")

	_select(ORIGIN)
	_button().emit_signal("pressed")
	assert_eq(Game.sim.world.agent.origin, Game.db.region_index_by_id[ORIGIN])
	assert_null(Game.site_request, "a success leaves the mode")
	assert_false(_prompt.visible)


## §16.1: *Buy and place* hands the question to the map and buys nothing yet.
func test_buy_and_place_enters_the_mode_and_pays_on_the_tap() -> void:
	Game.start_run(SEED)
	Game.apply(ChooseOriginCommand.new(ORIGIN))
	Game.sim.world.agent.compute += 100.0
	_tree.open()
	_tree.call("_select", DEPLOY_NODE)
	var before: float = Game.sim.world.agent.compute
	(_detail.get_node("%Buy") as Button).emit_signal("pressed")

	assert_false(_tree.is_open(), "the modal closes and the map takes over")
	assert_not_null(Game.site_request)
	assert_eq(Game.site_request.kind, SiteRequest.KIND_DEPLOY)
	assert_almost_eq(Game.sim.world.agent.compute, before, 1e-6, "nothing was bought yet")
	assert_true(_prompt.visible)
	assert_string_contains(_prompt.get_node("%SitePromptTitle").get("text"),
		tr("TECH_%s_NAME" % DEPLOY_NODE.to_upper()))

	# The map's second row says which regions are on offer.
	var row: int = RegionData.ROW_INTERFACE
	var origin_index: int = Game.db.region_index_by_id[ORIGIN]
	assert_eq(_map.data_image().get_pixel(origin_index, row).g, RegionData.ON)
	var clean: int = _first_ineligible()
	assert_eq(_map.data_image().get_pixel(clean, row).g, RegionData.OFF)

	# An ineligible region says why and offers no button.
	_select(Game.db.regions[clean].id)
	assert_false(_button().visible)
	assert_true(_note().visible)
	assert_eq(_note().text, tr("UI_ELIGIBLE_NOT_INFECTED"))

	# The eligible one buys and places.
	_select(ORIGIN)
	assert_true(_button().visible)
	_button().emit_signal("pressed")
	assert_null(Game.site_request)
	assert_true(Game.sim.world.agent.owns(DEPLOY_NODE))
	assert_eq(Game.sim.world.regions[origin_index].asset_count(AssetDef.KIND_FLEET), 1)
	assert_lt(Game.sim.world.agent.compute, before, "and it was paid for")


## Cancelling puts the tree back on the node and buys nothing (§16.1).
func test_cancelling_reopens_the_tree_and_buys_nothing() -> void:
	Game.start_run(SEED)
	Game.apply(ChooseOriginCommand.new(ORIGIN))
	Game.sim.world.agent.compute += 100.0
	_tree.open()
	_tree.call("_select", DEPLOY_NODE)
	(_detail.get_node("%Buy") as Button).emit_signal("pressed")
	var before: float = Game.sim.world.agent.compute

	Game.site_cancel()
	assert_null(Game.site_request)
	assert_false(Game.sim.world.agent.owns(DEPLOY_NODE))
	assert_almost_eq(Game.sim.world.agent.compute, before, 1e-6)
	assert_true(_tree.is_open(), "the tree comes back")
	assert_eq(_detail.shown_id(), DEPLOY_NODE, "on the node it was on")


## A bot passes its region in the command, so the mode is never entered for it.
func test_a_bot_run_never_enters_the_mode() -> void:
	Game.start_run(SEED, GreedyPolicy.ID)
	assert_null(Game.site_request)
	Game.site_select(SiteRequest.for_origin())
	assert_null(Game.site_request)
	assert_false(_prompt.visible)


## The map's eligible set follows the world, not only the request: a region that
## becomes infected becomes an offer without anything being pressed.
func test_the_eligible_set_is_recomputed_on_a_tick() -> void:
	Game.start_run(SEED)
	Game.apply(ChooseOriginCommand.new(ORIGIN))
	var request: SiteRequest = SiteRequest.new()
	request.kind = SiteRequest.KIND_DEPLOY
	request.title_key = "UI_SITE_PROMPT_DEPLOY"
	request.name_key = "TECH_%s_NAME" % DEPLOY_NODE.to_upper()
	request.eligible = func(index: int) -> String:
		return Game.sim.site_eligibility(DEPLOY_NODE, index)
	request.build = func(region_id: String) -> Command:
		return PurchaseNodeCommand.new(DEPLOY_NODE, region_id)
	Game.site_select(request)

	var clean: int = _first_ineligible()
	assert_eq(_map.data_image().get_pixel(clean, RegionData.ROW_INTERFACE).g, RegionData.OFF)
	Game.sim.world.regions[clean].penetration = 0.5
	Game.sim.world.regions[clean].seeded_day = 0
	Game.advance(1)
	assert_eq(_map.data_image().get_pixel(clean, RegionData.ROW_INTERFACE).g, RegionData.ON)


## The first region the fleet may not stand in: clean, but industrial enough
## that the reason is "not infected" rather than the attribute.
func _first_ineligible() -> int:
	for i: int in range(1, Game.db.regions.size()):
		if Game.sim.site_eligibility(DEPLOY_NODE, i) == Eligibility.REASON_NOT_INFECTED \
				and Game.db.regions[i].attr("industry") >= 2:
			return i
	return 0
