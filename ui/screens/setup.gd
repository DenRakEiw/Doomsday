extends Control
## The run's setup (spec `screens-full.md` §4): page 1 the architecture, the
## difficulty and (S5.8, scenarios.md §5) the scenario, page 2 the directives — skipped while no slot is unlocked.
## **Begin** builds the `RunSetup` and hands it to the router.
##
## What the screen opens on is `ScreenRouter.setup_preset` (Statistics' *Play
## this seed again*) or the profile's last setup, cleaned of what is no longer
## unlocked. Unlocks derive from the profile; the content is `Game.content()`.
##
## Scene-specific, so no `class_name`.

const KEY_STEP: String = "UI_SETUP_STEP"
const KEY_ARCH_TITLE: String = "UI_SETUP_ARCH_TITLE"
const KEY_DIRECTIVES_TITLE: String = "UI_SETUP_DIRECTIVES_TITLE"
const KEY_NEXT: String = "UI_SETUP_NEXT"
const KEY_BEGIN: String = "UI_SETUP_BEGIN"
const KEY_EFFECTS: String = "UI_SETUP_EFFECTS"
const KEY_DIFFICULTY: String = "UI_SETUP_DIFFICULTY"
const KEY_UNLOCK_RUNS: String = "UI_SETUP_UNLOCK_RUNS"
const KEY_UNLOCK_WIN: String = "UI_SETUP_UNLOCK_WIN"
const KEY_UNLOCK_WIN_BY: String = "UI_SETUP_UNLOCK_WIN_BY"
const KEY_NONE: String = "UI_SETUP_NONE"
const KEY_SLOT_LOCKED: String = "UI_SETUP_SLOT_LOCKED"
const KEY_SEED: String = "UI_SETUP_SEED"
const KEY_START_OWNED: String = "UI_SETUP_START_OWNED"
const KEY_START_ASSETS: String = "UI_SETUP_START_ASSETS"
const KEY_ARCH_DETAIL: String = "ARCH_%s_DETAIL"
const KEY_HOOK: String = "ARCH_HOOK_%s"
const KEY_DIFFICULTY_DETAIL: String = "DIFFICULTY_%s_DETAIL"
const KEY_DIRECTIVE_DETAIL: String = "DIRECTIVE_%s_DETAIL"
const KEY_SCENARIO: String = "UI_SETUP_SCENARIO"
const KEY_SCENARIO_NONE: String = "UI_SETUP_SCENARIO_NONE"
const KEY_SCENARIO_LOCKED: String = "UI_SETUP_SCENARIO_LOCKED"
const PREFIX_OUTCOME: String = "UI_OUTCOME_"

const PAGE_ARCHITECTURE: int = 1
const PAGE_DIRECTIVES: int = 2

## §4.1: three columns of cards, two where the grid is narrower than 900 px, one
## in compact; the difficulty row stacks below 520 px. Beside the detail the
## grid has 60 % of the width (its stretch ratio 1.5 against the detail's 1).
const CARD_COLUMNS: int = 3
const CARD_COLUMNS_NARROW: int = 2
const NARROW_WIDTH: float = 900.0
const GRID_SHARE: float = 0.6
const DIFFICULTY_STACK_WIDTH: float = 520.0

@onready var _step_label: Label = %StepLabel
@onready var _page_title: Label = %PageTitle
@onready var _scroll: ScrollContainer = %Scroll
@onready var _arch_page: BoxContainer = %ArchitecturePage
@onready var _cards: GridContainer = %Cards
@onready var _detail_name: Label = %DetailName
@onready var _detail_text: Label = %DetailText
@onready var _effects_title: Label = %EffectsTitle
@onready var _effects: VBoxContainer = %Effects
@onready var _difficulty_title: Label = %DifficultyTitle
@onready var _difficulty_row: BoxContainer = %DifficultyRow
@onready var _difficulty_detail: Label = %DifficultyDetail
@onready var _scenario_title: Label = %ScenarioTitle
@onready var _scenario_row: HFlowContainer = %ScenarioRow
@onready var _scenario_locked: Label = %ScenarioLocked
@onready var _scenario_tagline: Label = %ScenarioTagline
@onready var _scenario_detail: Label = %ScenarioDetail
@onready var _seed_row: Control = %SeedRow
@onready var _seed_label: Label = %SeedLabel
@onready var _seed_clear: ConsoleButton = %SeedClearButton
@onready var _directive_page: VBoxContainer = %DirectivePage
@onready var _back: ConsoleButton = %BackButton
@onready var _next: ConsoleButton = %NextButton

var page: int = PAGE_ARCHITECTURE
var architecture: String = ArchitectureDef.DEFAULT_ID
var difficulty: String = DifficultyDef.DEFAULT_ID
## "" = no scenario.
var scenario: String = ""
## Slot id → the chosen directive, or "" for none.
var directives: Dictionary[String, String] = {}
## 0 = a new random seed at Begin.
var seed_value: int = 0

var _db: ContentDB = null
var _card_group: ButtonGroup = ButtonGroup.new()
var _difficulty_group: ButtonGroup = ButtonGroup.new()
var _card_by_id: Dictionary[String, ArchitectureCard] = {}
var _difficulty_buttons: Dictionary[String, ConsoleButton] = {}
var _scenario_group: ButtonGroup = ButtonGroup.new()
## Scenario id ("" = none) → its button.
var _scenario_buttons: Dictionary[String, ConsoleButton] = {}
## Slot id → directive id ("" = none) → its button.
var _directive_buttons: Dictionary[String, Dictionary] = {}
var _directive_details: Dictionary[String, Label] = {}


func _ready() -> void:
	_db = Game.content()
	_back.pressed.connect(back)
	_next.pressed.connect(_on_next_pressed)
	_seed_clear.pressed.connect(clear_seed)
	get_viewport().size_changed.connect(_fit)
	if _db == null:
		return
	_open_on(ScreenRouter.setup_preset if ScreenRouter.setup_preset != null \
		else ProfileManager.last_setup, ScreenRouter.setup_seed)
	_build_cards()
	_build_difficulties()
	_build_scenarios()
	_build_directives()
	_refresh_strings()
	_show_page(PAGE_ARCHITECTURE)
	_fit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and _db != null:
		_refresh_strings()


## How many pages this setup has: the directives only once a slot is unlocked.
func total_pages() -> int:
	return PAGE_DIRECTIVES if unlocked_slots() > 0 else PAGE_ARCHITECTURE


func unlocked_slots() -> int:
	return 0 if _db == null else ProfileManager.slots_unlocked(_db.directive_slots.size())


## §4.1: selects an architecture. A locked one cannot be selected.
func select_architecture(id: String) -> bool:
	var def: ArchitectureDef = _db.architecture(id)
	if def == null or not ProfileManager.is_unlocked(def):
		return false
	architecture = id
	var card: ArchitectureCard = _card_by_id.get(id)
	if card != null:
		card.set_pressed_no_signal(true)
		if card.is_new():
			card.set_new(false)
			ProfileManager.mark_unlock_seen(id)
	_refresh_detail()
	return true


func select_difficulty(id: String) -> void:
	if _db.difficulty(id) == null and not (_db.difficulties.is_empty() \
			and id == DifficultyDef.DEFAULT_ID):
		return
	difficulty = id
	var button: ConsoleButton = _difficulty_buttons.get(id)
	if button != null:
		button.set_pressed_no_signal(true)
	_refresh_difficulty_detail()


## A scenario, or "" for none. Nothing while the scenarios are locked.
func select_scenario(id: String) -> void:
	if not scenarios_unlocked() or (not id.is_empty() and _db.scenario(id) == null):
		return
	scenario = id
	# `set_pressed_no_signal` leaves the group alone, so the others are let go
	# by hand — a selection that came from the code, not a click, is otherwise
	# drawn next to the one before it.
	for button_id: String in _scenario_buttons:
		_scenario_buttons[button_id].set_pressed_no_signal(button_id == id)
	_refresh_scenario_detail()


func scenarios_unlocked() -> bool:
	return _db != null and ProfileManager.scenarios_unlocked(_db)


## A directive for its slot, or "" for none. A locked slot takes nothing.
func select_directive(slot: String, id: String) -> void:
	var index: int = _db.directive_slots.find(slot)
	if index < 0 or index >= unlocked_slots():
		return
	if not id.is_empty() and (_db.directive(id) == null or _db.directive(id).slot != slot):
		return
	directives[slot] = id
	var buttons: Dictionary = _directive_buttons.get(slot, {})
	if buttons.has(id):
		(buttons[id] as ConsoleButton).set_pressed_no_signal(true)
	_refresh_directive_detail(slot)


func clear_seed() -> void:
	seed_value = 0
	_refresh_seed()


## The setup this screen would start: the architecture, the difficulty, the
## directives of the unlocked slots in slot order, and the scenario.
func build_setup() -> RunSetup:
	var chosen: Array[String] = []
	for slot: String in _db.directive_slots:
		var id: String = str(directives.get(slot, ""))
		if not id.is_empty():
			chosen.append(id)
	return RunSetup.create(architecture, chosen, difficulty, scenario)


## §4: Back goes to the title from page 1 and to page 1 from page 2. `Escape`
## is the same.
func back() -> void:
	if page == PAGE_DIRECTIVES:
		_show_page(PAGE_ARCHITECTURE)
		return
	ScreenRouter.go_to_title()


func begin() -> void:
	ScreenRouter.start_new_run(build_setup(), seed_value)


## `Escape`, or B on a pad (accessibility.md §4.1).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		back()


func _on_next_pressed() -> void:
	if page == PAGE_ARCHITECTURE and total_pages() > PAGE_ARCHITECTURE:
		_show_page(PAGE_DIRECTIVES)
		return
	begin()


# ------------------------------------------------------------- opening


## §4: the setup opens on `preset`, cleaned: an architecture that is no longer
## unlocked falls back to the default, a directive in a locked slot is dropped,
## an unknown difficulty is the content's default, and a scenario is kept only
## while it exists and the scenarios are unlocked.
func _open_on(preset: RunSetup, carried_seed: int) -> void:
	var def: ArchitectureDef = _db.architecture(preset.architecture)
	architecture = preset.architecture if def != null and ProfileManager.is_unlocked(def) \
		else ArchitectureDef.DEFAULT_ID
	difficulty = preset.difficulty if _db.difficulty(preset.difficulty) != null \
		else _db.difficulty_default
	directives.clear()
	var open_slots: int = unlocked_slots()
	for id: String in preset.directives:
		var directive: DirectiveDef = _db.directive(id)
		if directive == null:
			continue
		var index: int = _db.directive_slots.find(directive.slot)
		if index >= 0 and index < open_slots:
			directives[directive.slot] = id
	scenario = preset.scenario \
		if scenarios_unlocked() and _db.scenario(preset.scenario) != null else ""
	seed_value = maxi(0, carried_seed)


# -------------------------------------------------------------- building


func _build_cards() -> void:
	for def: ArchitectureDef in _db.architectures:
		var card: ArchitectureCard = ArchitectureCard.new()
		card.button_group = _card_group
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var unlocked: bool = ProfileManager.is_unlocked(def)
		card.setup(def.id, not unlocked, unlock_text(def.unlock),
			unlocked and not def.unlock.is_empty() and not ProfileManager.seen_unlocks.has(def.id))
		card.pressed.connect(select_architecture.bind(def.id))
		_cards.add_child(card)
		_card_by_id[def.id] = card
	var chosen: ArchitectureCard = _card_by_id.get(architecture)
	if chosen != null:
		chosen.set_pressed_no_signal(true)


func _build_difficulties() -> void:
	var ids: Array[String] = []
	for def: DifficultyDef in _db.difficulties:
		ids.append(def.id)
	if ids.is_empty():
		ids.append(DifficultyDef.DEFAULT_ID)
	for id: String in ids:
		var button: ConsoleButton = ConsoleButton.new()
		button.toggle_mode = true
		button.button_group = _difficulty_group
		button.label_key = DifficultyDef.name_key(id)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(select_difficulty.bind(id))
		_difficulty_row.add_child(button)
		_difficulty_buttons[id] = button
	select_difficulty(difficulty)


## scenarios.md §5: *None* and one button per scenario in content order — or,
## while locked, how far the player is from them and no buttons. A content root
## without scenarios shows no row at all.
func _build_scenarios() -> void:
	var has_any: bool = not _db.scenarios.is_empty()
	_scenario_title.visible = has_any
	var unlocked: bool = scenarios_unlocked()
	_scenario_locked.visible = has_any and not unlocked
	_scenario_row.visible = unlocked
	if not unlocked:
		_refresh_scenario_detail()
		return
	var ids: Array[String] = [""]
	for def: ScenarioDef in _db.scenarios:
		ids.append(def.id)
	for id: String in ids:
		var button: ConsoleButton = ConsoleButton.new()
		button.toggle_mode = true
		button.button_group = _scenario_group
		button.label_key = KEY_SCENARIO_NONE if id.is_empty() else ScenarioDef.name_key(id)
		button.pressed.connect(select_scenario.bind(id))
		_scenario_row.add_child(button)
		_scenario_buttons[id] = button
	select_scenario(scenario)


## §4.2: one row per slot in content order; a locked slot says when it opens.
func _build_directives() -> void:
	var open_slots: int = unlocked_slots()
	for i: int in _db.directive_slots.size():
		var slot: String = _db.directive_slots[i]
		var row: VBoxContainer = VBoxContainer.new()
		row.theme_type_variation = &"StackTight"
		_directive_page.add_child(row)
		var title: CapsLabel = CapsLabel.new()
		title.label_key = DirectiveDef.slot_key(slot)
		row.add_child(title)
		if i >= open_slots:
			var locked: Label = _caption(row)
			locked.set_meta(&"locked_run", i + 1)
			continue
		var flow: HFlowContainer = HFlowContainer.new()
		flow.theme_type_variation = &"Flow"
		row.add_child(flow)
		var group: ButtonGroup = ButtonGroup.new()
		var buttons: Dictionary = {}
		var ids: Array[String] = []
		for def: DirectiveDef in _db.directives:
			if def.slot == slot:
				ids.append(def.id)
		ids.append("")
		for id: String in ids:
			var button: ConsoleButton = ConsoleButton.new()
			button.toggle_mode = true
			button.button_group = group
			button.label_key = KEY_NONE if id.is_empty() else DirectiveDef.name_key(id)
			button.pressed.connect(select_directive.bind(slot, id))
			flow.add_child(button)
			buttons[id] = button
		_directive_buttons[slot] = buttons
		_directive_details[slot] = _caption(row)
		select_directive(slot, str(directives.get(slot, "")))


static func _caption(into: Control) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = &"LabelCaption"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	into.add_child(label)
	return label


# ------------------------------------------------------------ the texts


## The rule that unlocks an architecture, in the player's words (§4.1).
func unlock_text(unlock: Dictionary) -> String:
	if unlock.has(ProfileManager.UNLOCK_RUNS):
		return tr(KEY_UNLOCK_RUNS).format({"done": ProfileManager.runs_completed,
			"needed": int(unlock[ProfileManager.UNLOCK_RUNS])})
	if unlock.has(ProfileManager.UNLOCK_WINS):
		return tr(KEY_UNLOCK_WIN)
	if unlock.has(ProfileManager.UNLOCK_WINS_BY_OUTCOME):
		var needed: Dictionary = unlock[ProfileManager.UNLOCK_WINS_BY_OUTCOME]
		var outcome: String = "" if needed.is_empty() else str(needed.keys()[0])
		return tr(KEY_UNLOCK_WIN_BY).format({"outcome": tr(PREFIX_OUTCOME + outcome.to_upper())})
	return ""


## §4.1: the modifiers through the tech pane's formatter, the start, the hook.
func effect_lines(def: ArchitectureDef) -> Array[String]:
	var lines: Array[String] = []
	for modifier: ModifierDef in def.modifiers:
		lines.append(TechText.modifier_line(modifier, _db))
	for node_id: String in def.start_owned:
		lines.append(tr(KEY_START_OWNED).format({"node": TechText.node_name(node_id)}))
	for kind: String in def.start_assets:
		var count: int = def.start_assets[kind]
		lines.append(tr(KEY_START_ASSETS).format(
			{"count": count, "kind": TechText.asset_name(kind, count)}))
	if not def.hook.is_empty():
		lines.append(tr(KEY_HOOK % def.hook.to_upper()))
	return lines


func _refresh_strings() -> void:
	_effects_title.text = Format.caps(tr(KEY_EFFECTS))
	_difficulty_title.text = Format.caps(tr(KEY_DIFFICULTY))
	_scenario_title.text = Format.caps(tr(KEY_SCENARIO))
	_scenario_locked.text = tr(KEY_SCENARIO_LOCKED).format({
		"done": ProfileManager.runs_completed, "needed": _db.scenario_unlock_runs})
	for def: ArchitectureDef in _db.architectures:
		var card: ArchitectureCard = _card_by_id[def.id]
		card.setup(def.id, card.locked, unlock_text(def.unlock), card.is_new())
	for row: Node in _directive_page.get_children():
		for child: Node in row.get_children():
			if child.has_meta(&"locked_run"):
				(child as Label).text = tr(KEY_SLOT_LOCKED).format(
					{"n": int(child.get_meta(&"locked_run"))})
	for slot: String in _directive_details:
		_refresh_directive_detail(slot)
	_refresh_detail()
	_refresh_difficulty_detail()
	_refresh_scenario_detail()
	_refresh_seed()
	_refresh_header()


func _refresh_header() -> void:
	_step_label.text = Format.caps(tr(KEY_STEP).format({"n": page, "total": total_pages()}))
	_page_title.text = tr(KEY_ARCH_TITLE if page == PAGE_ARCHITECTURE else KEY_DIRECTIVES_TITLE)
	var last: bool = page >= total_pages()
	_next.label_key = KEY_BEGIN if last else KEY_NEXT


func _refresh_detail() -> void:
	var def: ArchitectureDef = _db.architecture(architecture)
	if def == null:
		return
	_detail_name.text = tr(ArchitectureDef.name_key(def.id))
	_detail_text.text = tr(KEY_ARCH_DETAIL % def.id.to_upper())
	for child: Node in _effects.get_children():
		_effects.remove_child(child)
		child.queue_free()
	var lines: Array[String] = effect_lines(def)
	for line: String in lines:
		_caption(_effects).text = line
	_effects_title.visible = not lines.is_empty()


func _refresh_difficulty_detail() -> void:
	_difficulty_detail.text = tr(KEY_DIFFICULTY_DETAIL % difficulty.to_upper())


## The chosen scenario's tagline and, below it, its detail; nothing for *None*.
func _refresh_scenario_detail() -> void:
	var chosen: bool = not scenario.is_empty()
	_scenario_tagline.visible = chosen
	_scenario_detail.visible = chosen
	if not chosen:
		return
	_scenario_tagline.text = tr(ScenarioDef.tagline_key(scenario))
	_scenario_detail.text = tr(ScenarioDef.detail_key(scenario))


func _refresh_directive_detail(slot: String) -> void:
	var label: Label = _directive_details.get(slot)
	if label == null:
		return
	var id: String = str(directives.get(slot, ""))
	label.text = "" if id.is_empty() else tr(KEY_DIRECTIVE_DETAIL % id.to_upper())
	label.visible = not id.is_empty()


func _refresh_seed() -> void:
	_seed_row.visible = seed_value > 0
	_seed_label.text = tr(KEY_SEED).format({"seed": seed_value})


func _show_page(which: int) -> void:
	page = clampi(which, PAGE_ARCHITECTURE, total_pages())
	_arch_page.visible = page == PAGE_ARCHITECTURE
	_directive_page.visible = page == PAGE_DIRECTIVES
	_scroll.scroll_vertical = 0
	_refresh_header()
	var focus: Control = _next
	if page == PAGE_ARCHITECTURE and _card_by_id.has(architecture):
		focus = _card_by_id[architecture]
	focus.grab_focus.call_deferred()


## §4.1: the grid beside the detail at full width, above it in compact; the
## difficulty buttons in a row, stacked on a narrow screen.
func _fit() -> void:
	var width: float = get_viewport_rect().size.x
	var compact: bool = width < float(UiTokens.COMPACT_WIDTH)
	_arch_page.vertical = compact
	if compact:
		_cards.columns = 1
	else:
		_cards.columns = CARD_COLUMNS_NARROW if width * GRID_SHARE < NARROW_WIDTH \
				else CARD_COLUMNS
	_difficulty_row.vertical = width < DIFFICULTY_STACK_WIDTH
	for button: Node in _difficulty_row.get_children():
		(button as ConsoleButton).compact = compact
	for button: ConsoleButton in _scenario_buttons.values():
		button.compact = compact
	for buttons: Dictionary in _directive_buttons.values():
		for button: Variant in buttons.values():
			(button as ConsoleButton).compact = compact
