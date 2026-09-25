extends Control
## How the run ended (spec m3-screens.md §7.4).
##
## A modal over the map as it stopped: the outcome, one verdict line, up to three
## epilogue lines, the run in nine numbers, and the ways on. The verdict and the
## epilogue are `EndingResolver`'s (`taskforce-endings.md` §6.3).
##
## Scene-specific, so no `class_name`.

signal again_requested
signal title_requested
## analysis.md §5.9: *Review the run* — the Analysis sheet over the ended map.
signal review_requested

const KEY_KICKER_WIN: String = "UI_RESULT_KICKER_WIN"
const KEY_KICKER_LOSS: String = "UI_RESULT_KICKER_LOSS"
## §6.2: the secret loss says the objective was reached — by someone else.
const KEY_KICKER_SUPPLANTED: String = "UI_RESULT_KICKER_SUPPLANTED"
const KEY_SEED: String = "UI_RESULT_SEED"
const KEY_NEVER: String = "UI_RESULT_NEVER"
const KEY_NONE: String = "UI_RESULT_NONE"
const PREFIX_OUTCOME: String = "UI_OUTCOME_"
const KEY_REVIEW: String = "UI_ANALYSIS_REVIEW"
const PREFIX_TREE: String = "UI_TREE_TAB_"
const PLACEHOLDER_SEED: String = "seed"
const PLACEHOLDER_COUNT: String = "count"
const PLACEHOLDER_TOTAL: String = "total"
## screens-full.md §7 item 4a: what the run unlocked.
const KEY_UNLOCKED: String = "UI_RESULT_UNLOCKED"
const KEY_UNLOCKED_SLOT: String = "UI_RESULT_UNLOCKED_SLOT"
const KEY_CODEX_NEW: String = "UI_RESULT_CODEX_NEW"

## illustrations.md §8.3: the ending's picture, wider than a card's.
const ILLUSTRATION_WIDTH: float = 420.0

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
@onready var _epilogue: VBoxContainer = %ResultEpilogue
@onready var _grid: GridContainer = %ResultGrid
@onready var _deaths_detail: Label = %DeathsDetail
@onready var _unlocked: VBoxContainer = %ResultUnlocked
@onready var _unlocked_title: Label = %UnlockedTitle
@onready var _unlocked_chips: HFlowContainer = %UnlockedChips
@onready var _seed_label: Label = %ResultSeed
@onready var _title_button: ConsoleButton = %ResultTitleButton
@onready var _again: ConsoleButton = %ResultAgainButton

## Where the ending's picture is looked for. A test points it at a folder that
## has one.
var illustration_root: String = IllustrationSlot.ROOT

var _values: Array[Label] = []
var _illustration: IllustrationSlot = null


func _ready() -> void:
	# accessibility.md §4.2: the focus ring is neither clipped nor scrolled away.
	# The results fill a phone's width at 150 % already (S4.9): room above and
	# below only.
	A11y.focus_scroll(_scroll, false)
	_build_rows()
	_title_button.pressed.connect(title_requested.emit)
	_again.pressed.connect(again_requested.emit)
	var review: ConsoleButton = ConsoleButton.new()
	review.name = "ResultReviewButton"
	review.label_key = KEY_REVIEW
	review.pressed.connect(review_requested.emit)
	_again.get_parent().add_child(review)
	_again.get_parent().move_child(review, 0)
	_illustration = IllustrationSlot.new()
	_illustration.name = "ResultIllustration"
	_illustration.width = ILLUSTRATION_WIDTH
	_illustration.visible = false
	_body.add_child(_illustration)
	_body.move_child(_illustration, _kicker.get_index())
	# The height is content-driven and the content wraps, so it is recomputed
	# whenever the body or the window changes rather than once.
	_body.minimum_size_changed.connect(_fit_scroll)
	get_viewport().size_changed.connect(_fit_scroll)
	visible = false


## Fills the screen from the world that just ended.
## accessibility.md §3.4: what is spoken when the modal opens.
func a11y_summary() -> String:
	return ModalHost.dialog_line(_outcome.text, _verdict.text)


func show_result(sim: Simulation) -> void:
	var world: World = sim.world
	var won: bool = World.WIN_OUTCOMES.has(world.outcome)
	_kicker.text = tr(_kicker_key(world.outcome))
	_outcome.text = tr(PREFIX_OUTCOME + World.OUTCOME_IDS[world.outcome].to_upper())
	_outcome.theme_type_variation = &"LabelDisplayXLWin" if won else &"LabelDisplayXL"
	var ending: Dictionary = EndingResolver.resolve(world, sim.db)
	_verdict.text = tr(EndingLineDef.verdict_key(str(ending[EndingResolver.KEY_VARIANT])))
	_fill_epilogue(ending[EndingResolver.KEY_EPILOGUE])
	_show_illustration(world, sim.db)
	_seed_label.text = tr(KEY_SEED).format({PLACEHOLDER_SEED: Game.run_seed()})
	_unlocked.visible = false
	_fill_rows(sim)
	visible = true
	_fit_scroll()
	# The wrapped lines only know their height once they have their width, so
	# the fit is taken again after the layout pass this filling caused.
	_fit_scroll.call_deferred()
	_again.grab_focus.call_deferred()


## The picture slot, for the tests; hidden when the ending has no picture.
func illustration() -> IllustrationSlot:
	return _illustration


## illustrations.md §8.3: the outcome's ending names a picture and its file
## ships — otherwise no slot at all, not the glyph: a mark above the kicker would
## say nothing the kicker does not.
func _show_illustration(world: World, db: ContentDB) -> void:
	var def: EndingDef = db.endings.get(World.OUTCOME_IDS[world.outcome], null)
	var id: String = "" if def == null else def.illustration
	_illustration.root = illustration_root
	_illustration.compact = get_viewport_rect().size.x < float(UiTokens.COMPACT_WIDTH)
	_illustration.visible = _illustration.has_file(id)
	if _illustration.visible:
		_illustration.show_illustration(id, Glyphs.Glyph.OUTCOME)


## §7 item 4a: one chip per unlock — an architecture, a directive slot, the
## count of new Codex entries. Nothing unlocked hides the block. Called after
## `show_result`.
func show_unlocks(architectures: Array[String], slots: Array[String], codex_new: int) -> void:
	for child: Node in _unlocked_chips.get_children():
		_unlocked_chips.remove_child(child)
		child.queue_free()
	_unlocked_title.text = Format.caps(tr(KEY_UNLOCKED))
	for id: String in architectures:
		_add_chip(ArchitectureDef.name_key(id), {})
	for slot: String in slots:
		_add_chip(KEY_UNLOCKED_SLOT, {"slot": tr(DirectiveDef.slot_key(slot))})
	if codex_new > 0:
		_add_chip(KEY_CODEX_NEW, {PLACEHOLDER_COUNT: codex_new})
	_unlocked.visible = _unlocked_chips.get_child_count() > 0
	_fit_scroll.call_deferred()


func _add_chip(key: String, args: Dictionary) -> void:
	var chip: Chip = Chip.new()
	chip.kind = Chip.Kind.ACCENT
	_unlocked_chips.add_child(chip)
	chip.set_label(key, args)


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
	_scroll.custom_minimum_size.y = minf(_body.get_combined_minimum_size().y
		+ float(UiTokens.FOCUS_OUTSET) * 2.0,
		maxf(available, 0.0))


## `Escape` on the results does nothing: the run is over and the two buttons are
## the only way on.
func on_escape() -> void:
	pass


static func _kicker_key(outcome: World.Outcome) -> String:
	if outcome == World.Outcome.LOSE_SUPPLANTED:
		return KEY_KICKER_SUPPLANTED
	return KEY_KICKER_WIN if World.WIN_OUTCOMES.has(outcome) else KEY_KICKER_LOSS


## One muted line per epilogue entry, in the resolver's order; none hides the
## box so it takes no height.
func _fill_epilogue(line_ids: Array[String]) -> void:
	for child: Node in _epilogue.get_children():
		_epilogue.remove_child(child)
		child.queue_free()
	for line_id: String in line_ids:
		var line: Label = Label.new()
		line.theme_type_variation = &"LabelCaption"
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.text = tr(EndingLineDef.epilogue_key(line_id))
		_epilogue.add_child(line)
	_epilogue.visible = not line_ids.is_empty()


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
	# The count under the share says how many; with nobody dead it said a lone 0.
	_deaths_detail.visible = deaths > 0.0
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


## The tree the run spent itself on; ties go to the first tree of the content —
## the rule an ending's `dominant_tree` reads too.
static func _dominant_tree(sim: Simulation) -> String:
	var best: String = HeadlineConditions.dominant_tree(sim.world, sim.db)
	if best.is_empty():
		return String(TranslationServer.translate(KEY_NONE))
	return String(TranslationServer.translate(PREFIX_TREE + best.to_upper()))
