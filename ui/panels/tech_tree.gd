extends Control
## The technology tree (spec m3-screens.md §3.1–§3.3).
##
## The modal owns the run's side of the tree: which tab is shown, what is
## selected, what a purchase does to the board, and whether the clock is held
## while it is open. The cells are the board's (`tech_board.gd`) and the words
## are the detail pane's (`tech_detail.gd`).
##
## Scene-specific, so no `class_name`.

## The modal closed itself — the session releases whatever it was showing it in.
signal closed
## The player backed out of site select: the session puts the modal back up with
## `node_id` selected (`loop-mechanics.md` §16.1).
signal reopen_requested(node_id: String)

## The hold this modal takes while `Settings.tree_pauses` is on (§10.2).
const HOLD: StringName = &"tree"

## The two halves of the modal. Their scripts are scene-specific and carry no
## `class_name`, so the type comes from the file — which is what keeps every call
## below type-checked.
const TechBoard: GDScript = preload("res://ui/panels/tech_board.gd")
const TechDetail: GDScript = preload("res://ui/panels/tech_detail.gd")

const KEY_TITLE: String = "UI_TREE_TITLE"
## `loop-mechanics.md` §16.1: what the prompt strip says while a site is chosen.
const KEY_SITE_PROMPT_DEPLOY: String = "UI_SITE_PROMPT_DEPLOY"
const KEY_TECH_NAME: String = "TECH_%s_NAME"
const KEY_TAB_COUNT: String = "UI_TREE_TAB_COUNT"
## accessibility.md §6.3 item 2: *something affordable* is told by a mark, not
## by the chip's colour alone; §3.3: and by the tab's name.
const KEY_TAB_COUNT_AFFORDABLE: String = "UI_TREE_TAB_COUNT_AFFORDABLE"
const KEY_A11Y_TAB: String = "UI_A11Y_TREE_TAB"
const KEY_A11Y_TAB_AFFORDABLE: String = "UI_A11Y_TREE_TAB_AFFORDABLE"
const KEY_COMPUTE_RATE: String = "UI_HUD_COMPUTE_RATE"
const TABS: Array[String] = ["infiltration", "capabilities", "evasion"]
const TAB_KEY: Array[String] = ["UI_TREE_TAB_INFILTRATION", "UI_TREE_TAB_CAPABILITIES",
	"UI_TREE_TAB_EVASION"]
const PLACEHOLDER_RATE: String = "rate"

@onready var _title: Label = %Title
@onready var _tabs: Container = %Tabs
@onready var _board: TechBoard = %Board
@onready var _scroll: ScrollContainer = %BoardScroll
@onready var _detail: TechDetail = %TechDetail
@onready var _compute: ValueLabel = %Compute
@onready var _compute_cell: Control = %ComputeCell
@onready var _header: Container = %Header
@onready var _paused: Chip = %PausedChip
@onready var _close_button: IconButton = %CloseButton
@onready var _sheet: SlidePanel = %DetailSheet
## The detail pane's home in the wide layout; in the compact one it is the sheet.
@onready var _body: HBoxContainer = %Body

## One toggle per tab, and its count chip, in the order of `TABS`.
var _tab_buttons: Array[ConsoleButton] = []
var _tab_chips: Array[Chip] = []
var _tab: int = 0
## Tab index → the node last selected in it, and where it was scrolled to.
var _selection: Dictionary[int, String] = {}
var _scroll_at: Dictionary[int, Vector2i] = {}
## Node id → the day it was bought, as far as this session saw it (§3.6 item 8).
var _purchase_day: Dictionary[String, int] = {}
var _is_open: bool = false
var _compact: bool = false


func _ready() -> void:
	add_to_group(CoachRing.group(CoachRing.TARGET_TREE))
	_build_tabs()
	_close_button.pressed.connect(close)
	# first-run.md §6.7: the page for this screen, before the close button.
	HelpButton.before(_close_button, HelpPages.CONTEXT_TREE)
	_board.node_selected.connect(_on_node_selected)
	_board.buy_requested.connect(_on_buy_requested)
	_detail.buy_requested.connect(_on_buy_requested)
	_detail.jump_requested.connect(_on_jump_requested)
	_detail.close_requested.connect(_close_sheet)
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.sim_event.connect(_on_sim_event)
	EventBus.hold_changed.connect(_on_hold_changed)
	EventBus.run_started.connect(_on_run_started)
	resized.connect(_apply_detail_width)
	_refresh_strings()
	_apply_detail_width()
	visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_strings()
		if _is_open:
			_refresh()


func _refresh_strings() -> void:
	_title.text = tr(KEY_TITLE)
	for button: ConsoleButton in _tab_buttons:
		button.accessibility_name = tr(TAB_KEY[_tab_buttons.find(button)])
	_size_tabs()


## §3.2: the detail pane is as wide as a side panel — a share of the viewport,
## between a floor and a ceiling, so it is readable on every screen.
func _apply_detail_width() -> void:
	if _compact:
		# The sheet is as wide as the screen; the panel inside it fills it.
		_detail.custom_minimum_size.x = 0.0
		return
	_detail.custom_minimum_size.x = SlidePanel.side_width(size.x)


## Shows the tree, and holds the clock if the setting says so (§3.1).
func open() -> void:
	if _is_open or Game.sim == null:
		return
	_is_open = true
	visible = true
	if Settings.tree_pauses:
		Game.hold(HOLD)
	_show_tab(_tab)
	_refresh_header()
	_tab_buttons[_tab].grab_focus()


## Opens the tree with `node_id` selected — what a cancelled site select does.
## The tab is shown explicitly, because `open` on a tree that is already open
## does nothing and the node may live in another tab.
func open_on(node_id: String) -> void:
	var definition: TechNodeDef = Game.db.tech(node_id)
	open()
	if definition == null:
		return
	var index: int = TABS.find(definition.tree)
	if index >= 0 and index != _tab:
		_remember_scroll()
		_show_tab(index)
	_select(node_id)


func close() -> void:
	if not _is_open:
		return
	_remember_scroll()
	_is_open = false
	visible = false
	_sheet.close()
	Game.release(HOLD)
	closed.emit()


func is_open() -> bool:
	return _is_open


## `Escape` inside a modal closes it, never just the selection (§3.7) — except
## that on a phone the sheet is a layer of its own and goes first.
func on_escape() -> void:
	if _compact and _sheet.is_open:
		_sheet.close()
		return
	close()


## §3.2: the board takes the whole body and the detail pane becomes a sheet that
## comes up from the bottom when something is selected.
func set_compact(compact: bool) -> void:
	if compact == _compact:
		return
	_compact = compact
	_board.set_compact(compact)
	_detail.set_compact(compact)
	var home: Node = _body
	if compact:
		home = _sheet
	if _detail.get_parent() != home:
		_detail.get_parent().remove_child(_detail)
		home.add_child(_detail)
	_detail.size_flags_horizontal = Control.SIZE_FILL
	# The header's compute cell keeps a fixed width on a desktop so the number
	# does not shuffle the row; on a phone that width is a quarter of the screen.
	_compute_cell.custom_minimum_size.x = 0.0 if compact \
		else UiTokens.text_width(float(UiTokens.CELL_MIN_WIDTH))
	# A phone's header has no room for the wide gaps of a desktop title row.
	_header.theme_type_variation = &"RowSnug" if compact else &"RowWide"
	# S4.9 screenshots: the display title, the large figure and the close button
	# came to 420 px on a 400 px phone, and the modal ran off both edges. On a
	# phone the title is a heading and the figure the top bar's size, as there;
	# should that still not fit (150 % text), the title gives way first.
	_title.theme_type_variation = &"LabelHeading" if compact else &"LabelDisplay"
	_title.size_flags_horizontal = int(Control.SIZE_EXPAND_FILL) if compact \
		else int(Control.SIZE_FILL)
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if compact \
		else TextServer.OVERRUN_NO_TRIMMING
	_compute.large = not compact
	# The expanding title does the gap's work, and a second expander would take
	# half of the room the title needs.
	(_header.get_node(^"Gap") as Control).visible = not compact
	if compact:
		_sheet.close()
	_apply_detail_width()


func _close_sheet() -> void:
	if _compact:
		_sheet.close()


## The count chip of a tab, so that a test can read what the player sees.
func tab_chip(index: int) -> Chip:
	return _tab_chips[index]


func _build_tabs() -> void:
	var group: ButtonGroup = ButtonGroup.new()
	for i: int in TABS.size():
		_tabs.add_child(_build_tab(i, group))
	_tab_buttons[0].button_pressed = true


## A tab is one target: the name and the count chip sit inside the button, laid
## out by a row of their own, because a `Button` is not a container (§3.2).
func _build_tab(index: int, group: ButtonGroup) -> ConsoleButton:
	var button: ConsoleButton = ConsoleButton.new()
	button.toggle_mode = true
	button.button_group = group
	button.pressed.connect(_on_tab_pressed.bind(index))

	var content: MarginContainer = MarginContainer.new()
	content.name = "Content"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.theme_type_variation = &"GutterTight"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row: HBoxContainer = HBoxContainer.new()
	row.theme_type_variation = &"RowSnug"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label: CapsLabel = CapsLabel.new()
	label.name = "Name"
	label.label_key = TAB_KEY[index]
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip: Chip = Chip.new()
	chip.name = "Count"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	row.add_child(chip)
	content.add_child(row)
	button.add_child(content)
	_tab_buttons.append(button)
	_tab_chips.append(chip)
	return button


## A `Button` does not measure its children, so the row's own minimum is what
## makes the tab wide enough — in German too, and again when the locale changes.
func _size_tabs() -> void:
	for button: ConsoleButton in _tab_buttons:
		var content: Control = button.get_node("Content") as Control
		var wanted: Vector2 = content.get_combined_minimum_size()
		button.custom_minimum_size = Vector2(wanted.x,
			maxf(wanted.y, float(UiTokens.HIT_MIN)))


func _show_tab(index: int) -> void:
	_tab = index
	_tab_buttons[index].button_pressed = true
	_board.show_tree(TABS[index], Game.db, Game.sim)
	var remembered: String = _selection.get(index, "")
	if remembered.is_empty():
		_detail.clear()
	else:
		_select(remembered)
	var at: Vector2i = _scroll_at.get(index, Vector2i.ZERO)
	_scroll.set_deferred(&"scroll_horizontal", at.x)
	_scroll.set_deferred(&"scroll_vertical", at.y)
	_refresh_tab_chips()


## The whole of the modal that depends on the run, after a tick or a purchase.
func _refresh() -> void:
	if Game.sim == null:
		return
	_board.refresh(Game.sim)
	_refresh_tab_chips()
	_refresh_header()
	if not _detail.shown_id().is_empty():
		_show_detail(_detail.shown_id())


func _refresh_header() -> void:
	if Game.sim == null:
		return
	_compute.set_number(Game.sim.world.agent.compute, Format.Kind.COMPUTE)
	_compute.set_delta_in(KEY_COMPUTE_RATE, PLACEHOLDER_RATE, Game.compute_rate,
		Format.Kind.COMPUTE)
	_paused.visible = Game.is_held()


## `{owned} / {total}` per tab, accented while something in that tree can be
## bought right now — the tab is where the money can go (§3.2).
func _refresh_tab_chips() -> void:
	for i: int in TABS.size():
		var owned: int = 0
		var total: int = 0
		var affordable: bool = false
		for definition: TechNodeDef in Game.db.tech_nodes:
			if definition.tree != TABS[i]:
				continue
			total += 1
			var state: TechNode.State = TechNode.state_for(definition, Game.sim)
			if state == TechNode.State.OWNED:
				owned += 1
			elif state == TechNode.State.AFFORDABLE:
				affordable = true
		var counts: Dictionary = {"owned": owned, "total": total}
		_tab_chips[i].set_label(KEY_TAB_COUNT_AFFORDABLE if affordable else KEY_TAB_COUNT, counts)
		_tab_chips[i].kind = Chip.Kind.ACCENT if affordable else Chip.Kind.DEFAULT
		counts["tab"] = tr(TAB_KEY[i])
		_tab_buttons[i].accessibility_name = tr(KEY_A11Y_TAB_AFFORDABLE if affordable
			else KEY_A11Y_TAB).format(counts)
	# The count is part of the tab's width: `9 / 43` is wider than `0 / 43`.
	_size_tabs()


func _select(node_id: String) -> void:
	_selection[_tab] = node_id
	_board.select(node_id)
	_show_detail(node_id)
	if _compact:
		_sheet.open()


func _show_detail(node_id: String) -> void:
	var definition: TechNodeDef = Game.db.tech(node_id)
	if definition == null:
		return
	_detail.show_node(definition, Game.sim, TechNode.state_for(definition, Game.sim),
		Game.sim.node_cost(node_id), int(_purchase_day.get(node_id, -1)))


## The one door to a purchase: the buy button and `Enter` on a node both end
## here, so a refusal is reported in exactly one place (§3.3).
func _buy(node_id: String) -> void:
	var definition: TechNodeDef = Game.db.tech(node_id)
	if definition != null and definition.deploys():
		_place(definition)
		return
	var locked: Dictionary[String, bool] = _locked_nodes()
	var result: CommandResult = Game.apply(PurchaseNodeCommand.new(node_id))
	if not result.ok:
		_detail.show_failure(result.reason)
		return
	_refresh()
	_flash_opened(node_id, locked)


## A deploying node is not bought here (`loop-mechanics.md` §16.1): the modal
## hands the question to the map and closes itself. Nothing has been paid for
## until the player taps a region, and backing out reopens the tree on the node.
func _place(definition: TechNodeDef) -> void:
	var request: SiteRequest = SiteRequest.new()
	request.kind = SiteRequest.KIND_DEPLOY
	request.title_key = KEY_SITE_PROMPT_DEPLOY
	request.name_key = KEY_TECH_NAME % definition.id.to_upper()
	request.rule = definition.deploy_eligible
	request.eligible = func(index: int) -> String:
		return Game.sim.site_eligibility(definition.id, index)
	request.build = func(region_id: String) -> Command:
		return PurchaseNodeCommand.new(definition.id, region_id)
	request.on_cancel = func() -> void:
		reopen_requested.emit(definition.id)
	close()
	Game.site_select(request)


## Which nodes of the shown tab are locked right now, so that the ones a purchase
## opens can be told apart afterwards.
func _locked_nodes() -> Dictionary[String, bool]:
	var locked: Dictionary[String, bool] = {}
	for definition: TechNodeDef in Game.db.tech_nodes:
		if _board.has_node_id(definition.id) \
				and TechNode.state_for(definition, Game.sim) == TechNode.State.LOCKED:
			locked[definition.id] = true
	return locked


## The node that was bought lights up, and so does everything it opened (§3.3).
func _flash_opened(node_id: String, locked_before: Dictionary[String, bool]) -> void:
	var bought: TechNode = _board.node_for(node_id)
	if bought != null:
		bought.flash()
	for opened: String in locked_before:
		var definition: TechNodeDef = Game.db.tech(opened)
		if TechNode.state_for(definition, Game.sim) == TechNode.State.LOCKED:
			continue
		var node: TechNode = _board.node_for(opened)
		if node != null:
			node.flash()


func _on_tab_pressed(index: int) -> void:
	if index == _tab:
		return
	_remember_scroll()
	_show_tab(index)


func _remember_scroll() -> void:
	_scroll_at[_tab] = Vector2i(_scroll.scroll_horizontal, _scroll.scroll_vertical)


func _on_node_selected(node_id: String) -> void:
	_select(node_id)


func _on_buy_requested(node_id: String) -> void:
	_buy(node_id)


## A prerequisite row jumps to its node, switching tab when it lives elsewhere.
func _on_jump_requested(node_id: String) -> void:
	var definition: TechNodeDef = Game.db.tech(node_id)
	if definition == null:
		return
	var index: int = TABS.find(definition.tree)
	if index >= 0 and index != _tab:
		_remember_scroll()
		_show_tab(index)
	_select(node_id)
	_board.reveal(node_id)


func _on_tick_advanced(_day: int) -> void:
	if _is_open:
		_refresh()


func _on_sim_event(event: SimEvent) -> void:
	if event.type == SimEvent.NODE_PURCHASED:
		_purchase_day[str(event.data["node"])] = event.day


func _on_hold_changed(_held: bool) -> void:
	if _is_open:
		_refresh_header()


func _on_run_started(_seed_value: int) -> void:
	_purchase_day.clear()
	_selection.clear()
	_scroll_at.clear()
	if _is_open:
		close()
