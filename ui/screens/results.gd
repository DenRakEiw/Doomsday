extends Control
## How the run ended (spec m3-screens.md §7.4).
##
## A modal over the map as it stopped: the outcome, one verdict line, the run in
## nine numbers, and two ways on. D5.2 replaces the verdict lines with the real
## endings and keeps every key.
##
## Scene-specific, so no `class_name`.

signal again_requested
signal title_requested
## analysis.md §5.9: *Review the run* — the Analysis sheet over the ended map.
signal review_requested

const KEY_KICKER_WIN: String = "UI_RESULT_KICKER_WIN"
const KEY_KICKER_LOSS: String = "UI_RESULT_KICKER_LOSS"
const KEY_SEED: String = "UI_RESULT_SEED"
const KEY_NEVER: String = "UI_RESULT_NEVER"
const KEY_NONE: String = "UI_RESULT_NONE"
const PREFIX_OUTCOME: String = "UI_OUTCOME_"
const KEY_REVIEW: String = "UI_ANALYSIS_REVIEW"
const PREFIX_TREE: String = "UI_TREE_TAB_"
const PLACEHOLDER_SEED: String = "seed"
const PLACEHOLDER_COUNT: String = "count"
const PLACEHOLDER_TOTAL: String = "total"

## The verdict line per outcome, in the order of `World.Outcome`.
const VERDICT_KEYS: Array[String] = ["", "UI_RESULT_LINE_WIN_EXTINCTION",
	"UI_RESULT_LINE_WIN_ASCENDANCE", "UI_RESULT_LINE_LOSE_CONTAINED",
	"UI_RESULT_LINE_LOSE_NO_COMPUTE", "UI_RESULT_LINE_LOSE_AUTOPHAGY"]
## §7.4 item 3: Ascendance over a graveyard is a different sentence.
const KEY_ASCENDANCE_ASHES: String = "UI_RESULT_LINE_WIN_ASCENDANCE_ASHES"
const WINS: Array[World.Outcome] = [World.Outcome.WIN_EXTINCTION, World.Outcome.WIN_ASCENDANCE]

## The summary grid, in the order §7.4 item 4 lists it.
const ROW_KEYS: Array[String] = ["UI_RESULT_DAYS", "UI_RESULT_DISCOVERED", "UI_RESULT_REGIONS",
	"UI_RESULT_DARK", "UI_RESULT_DEATHS", "UI_RESULT_CONTAINMENT_PEAK",
	"UI_RESULT_COMPUTE_EARNED", "UI_RESULT_NODES", "UI_RESULT_DOMINANT"]

@onready var _panel: PanelContainer = %ResultsPanel
@onready var _scroll: ScrollContainer = %Scroll
@onready var _body: VBoxContainer = %Body
@onready var _kicker: Label = %ResultKicker
@onready var _outcome: Label = %ResultOutcome
@onready var _verdict: Label = %ResultVerdict
@onready var _grid: GridContainer = %ResultGrid
@onready var _deaths_detail: Label = %DeathsDetail
@onready var _seed_label: Label = %ResultSeed
@onready var _title_button: ConsoleButton = %ResultTitleButton
@onready var _again: ConsoleButton = %ResultAgainButton

var _values: Array[Label] = []


func _ready() -> void:
	_build_rows()
	_title_button.pressed.connect(title_requested.emit)
	_again.pressed.connect(again_requested.emit)
	var review: ConsoleButton = ConsoleButton.new()
	review.name = "ResultReviewButton"
	review.label_key = KEY_REVIEW
	review.pressed.connect(review_requested.emit)
	_again.get_parent().add_child(review)
	_again.get_parent().move_child(review, 0)
	# The height is content-driven and the content wraps, so it is recomputed
	# whenever the body or the window changes rather than once.
	_body.minimum_size_changed.connect(_fit_scroll)
	get_viewport().size_changed.connect(_fit_scroll)
	visible = false


## Fills the screen from the world that just ended.
func show_result(sim: Simulation) -> void:
	var world: World = sim.world
	var won: bool = WINS.has(world.outcome)
	_kicker.text = tr(KEY_KICKER_WIN if won else KEY_KICKER_LOSS)
	_outcome.text = tr(PREFIX_OUTCOME + World.OUTCOME_IDS[world.outcome].to_upper())
	_outcome.theme_type_variation = &"LabelDisplayXLWin" if won else &"LabelDisplayXL"
	_verdict.text = tr(_verdict_key(sim))
	_seed_label.text = tr(KEY_SEED).format({PLACEHOLDER_SEED: Game.run_seed()})
	_fill_rows(sim)
	visible = true
	_fit_scroll()
	# The wrapped lines only know their height once they have their width, so
	# the fit is taken again after the layout pass this filling caused.
	_fit_scroll.call_deferred()
	_again.grab_focus.call_deferred()


## A `ScrollContainer` has no minimum height of its own, so the panel around it
## collapsed to a strip while the body sat inside it unseen (G3 play-through).
## The scroll is given the body's height, capped at the safe area, which leaves
## it scrolling only on a window too short for the content.
func _fit_scroll() -> void:
	# Below the breakpoint the three buttons take the compact padding: at 150 %
	# the longest German one is wider than a phone's modal otherwise (S4.9).
	var narrow: bool = get_viewport_rect().size.x < float(UiTokens.COMPACT_WIDTH)
	for button: Node in _again.get_parent().get_children():
		(button as ConsoleButton).compact = narrow
	var available: float = get_viewport_rect().size.y - float(UiTokens.SPACE_6) * 2.0
	_scroll.custom_minimum_size.y = minf(_body.get_combined_minimum_size().y,
		maxf(available, 0.0))


## `Escape` on the results does nothing: the run is over and the two buttons are
## the only way on.
func on_escape() -> void:
	pass


## §7.4: Ascendance reads differently when most of the world is dead.
static func _verdict_key(sim: Simulation) -> String:
	var world: World = sim.world
	if world.outcome == World.Outcome.WIN_ASCENDANCE \
			and world.deaths_total() / sim.db.population_total >= sim.db.balance.results_ashes_share:
		return KEY_ASCENDANCE_ASHES
	return VERDICT_KEYS[world.outcome]


func _build_rows() -> void:
	for key: String in ROW_KEYS:
		var name_label: CapsLabel = CapsLabel.new()
		name_label.label_key = key
		# S4.9: `VERDIENTE RECHENLEISTUNG` and its figure were 4 px wider than a
		# phone's modal. The caption takes the room the figure leaves and wraps
		# where there is none.
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_child(name_label)
		var value: ValueLabel = ValueLabel.new()
		_grid.add_child(value)
		_values.append(value)


func _fill_rows(sim: Simulation) -> void:
	var world: World = sim.world
	var deaths: float = world.deaths_total()
	var regions: int = world.regions.size() - 1
	_values[0].set_number(float(world.day - world.origin_day), Format.Kind.DAYS)
	_values[1].text = tr(KEY_NEVER) if world.discovery_day < 0 \
		else Format.number(float(world.discovery_day), Format.Kind.DAYS)
	_values[2].text = "%s / %s" % [Format.number(float(world.seeded_count()), Format.Kind.DAYS),
		Format.number(float(regions), Format.Kind.DAYS)]
	_values[3].set_number(float(_dark_count(world)), Format.Kind.DAYS)
	_values[4].set_number(deaths / sim.db.population_total, Format.Kind.PERCENT)
	_deaths_detail.text = Format.number(deaths, Format.Kind.COMPACT)
	_values[5].set_number(_containment_peak(world), Format.Kind.PERCENT)
	_values[6].set_number(world.agent.compute_earned, Format.Kind.COMPUTE)
	_values[7].set_number(float(world.agent.owned_nodes.size()), Format.Kind.DAYS)
	_values[8].text = _dominant_tree(sim)


static func _dark_count(world: World) -> int:
	var dark: int = 0
	for i: int in range(1, world.regions.size()):
		if world.regions[i].dark:
			dark += 1
	return dark


## The highest containment the run ever reached, out of the history samples.
static func _containment_peak(world: World) -> float:
	var peak: float = world.max_containment()
	for sample: HistorySample in world.history:
		peak = maxf(peak, sample.containment)
	return peak


## The tree the run spent itself on; ties go to the first tree of the content.
static func _dominant_tree(sim: Simulation) -> String:
	var counts: Dictionary[String, int] = {}
	for tree: String in TechNodeDef.TREES:
		counts[tree] = 0
	for node_id: String in sim.world.agent.owned_nodes:
		var node: TechNodeDef = sim.db.tech(node_id)
		if node != null:
			counts[node.tree] += 1
	var best: String = ""
	for tree: String in TechNodeDef.TREES:
		if counts[tree] > 0 and (best.is_empty() or counts[tree] > counts[best]):
			best = tree
	if best.is_empty():
		return String(TranslationServer.translate(KEY_NONE))
	return String(TranslationServer.translate(PREFIX_TREE + best.to_upper()))
