extends Control
## Statistics (spec `screens-full.md` §6.2): the totals, one row per unlocked
## architecture, the achievements (release.md §2.4) and the recent runs with
## *Play this seed again*. No charts —
## the numbers are few, and the analysis screen owns the run's charts.
##
## Scene-specific, so no `class_name`.

signal closed
## §6.2: a run of the history, to be set up again with its seed.
signal replay_requested(seed_value: int, setup: RunSetup)

const KEY_TITLE: String = "UI_STATS_TITLE"
const KEY_RUNS: String = "UI_STATS_RUNS"
const KEY_WINS: String = "UI_STATS_WINS"
const KEY_WIN_RATE: String = "UI_STATS_WIN_RATE"
const KEY_FASTEST: String = "UI_STATS_FASTEST"
const KEY_ENDINGS: String = "UI_STATS_ENDINGS"
const KEY_BY_ARCH: String = "UI_STATS_BY_ARCH"
const KEY_RECENT: String = "UI_STATS_RECENT"
const KEY_COL_RUNS: String = "UI_STATS_COL_RUNS"
const KEY_COL_WINS: String = "UI_STATS_COL_WINS"
const KEY_COL_DAYS: String = "UI_STATS_COL_DAYS"
const KEY_COL_SEED: String = "UI_STATS_COL_SEED"
const KEY_RUN_NUMBER: String = "UI_STATS_RUN_NUMBER"
const KEY_REPLAY: String = "UI_STATS_REPLAY"
const KEY_EMPTY: String = "UI_STATS_EMPTY"
const KEY_PROGRESS: String = "UI_CODEX_PROGRESS"
## scenarios.md §1: *architecture · scenario* for a run played in one.
const KEY_SCENARIO_PAIR: String = "UI_STATS_SCENARIO_PAIR"
const PREFIX_OUTCOME: String = "UI_OUTCOME_"
## release.md §2.4: section 4.
const KEY_ACHIEVEMENTS: String = "UI_STATS_ACHIEVEMENTS"
const KEY_ACHIEVEMENTS_COUNT: String = "UI_STATS_ACHIEVEMENTS_COUNT"
const KEY_ACH_EARNED: String = "UI_ACH_EARNED"
const KEY_ACH_PROGRESS: String = "UI_ACH_PROGRESS"
const KEY_ACH_LOCKED: String = "UI_ACH_LOCKED"
const KEY_ACH_HIDDEN_NAME: String = "UI_ACH_HIDDEN_NAME"
const KEY_ACH_HIDDEN_DETAIL: String = "UI_ACH_HIDDEN_DETAIL"
## The state's word, by what it says: earned in the accent, progress and
## locked quieter (release.md §2.4). The word carries it; colour never alone.
const VARIATION_EARNED: StringName = &"LabelCaptionAccent"
const VARIATION_PROGRESS: StringName = &"LabelCaptionHint"
const VARIATION_LOCKED: StringName = &"LabelCaption"
## A figure there is none of yet.
const DASH: String = "—"
## §6.2's by-architecture table: name, runs, wins, fastest win.
const ARCH_COLUMNS: int = 4
const ARCH_HEADERS: Array[String] = [KEY_COL_RUNS, KEY_COL_WINS, KEY_FASTEST]
## accessibility.md §8.2: the name column against each header column.
const NAME_STRETCH: float = 2.0

@onready var _panel: PanelContainer = %StatsPanel
@onready var _title: Label = %StatsTitle
@onready var _close: IconButton = %CloseButton
@onready var _content: VBoxContainer = %Content

var _db: ContentDB = null
## Whether the last build laid the achievements out for a phone.
var _compact: bool = false


func _ready() -> void:
	# accessibility.md §4.2: the focus ring is neither clipped nor scrolled away.
	A11y.focus_scroll(get_node("Centre/StatsPanel/Body/Scroll") as ScrollContainer)
	_close.pressed.connect(closed.emit)
	get_viewport().size_changed.connect(_fit)
	_fit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and visible:
		refresh()


func open() -> void:
	_db = Game.content()
	visible = true
	refresh()
	_fit()


func on_escape() -> void:
	closed.emit()


## Rebuilds the three blocks from the profile.
func refresh() -> void:
	_title.text = tr(KEY_TITLE)
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	if _db == null:
		return
	_compact = get_viewport_rect().size.x < float(UiTokens.COMPACT_WIDTH)
	_build_totals()
	_build_architectures()
	_build_achievements()
	_build_recent()


## §6.2 item 1.
func totals() -> Dictionary[String, String]:
	var runs: int = ProfileManager.runs_completed
	var wins: int = ProfileManager.runs_won
	var fastest: int = 0
	for row: Dictionary in ProfileManager.by_architecture.values():
		var best: int = int(row.get(ProfileManager.ARCH_BEST_DAYS, 0))
		if best > 0:
			fastest = best if fastest <= 0 else mini(fastest, best)
	var variants: Array[String] = CodexEntries.ending_variants(_db)
	var seen: int = 0
	for id: String in variants:
		if ProfileManager.endings_seen.has(id):
			seen += 1
	return {
		KEY_RUNS: Format.number(float(runs), Format.Kind.DAYS),
		KEY_WINS: Format.number(float(wins), Format.Kind.DAYS),
		KEY_WIN_RATE: DASH if runs <= 0 \
			else Format.number(float(wins) / float(runs), Format.Kind.PERCENT),
		KEY_FASTEST: DASH if fastest <= 0 else Format.number(float(fastest), Format.Kind.DAYS),
		KEY_ENDINGS: tr(KEY_PROGRESS).format({"seen": seen, "total": variants.size()}),
	}


func _build_totals() -> void:
	var grid: GridContainer = _grid(2)
	var values: Dictionary[String, String] = totals()
	for key: String in values:
		_caps_cell(grid, key, true)
		_value_cell(grid, values[key])


func _build_architectures() -> void:
	_section(KEY_BY_ARCH)
	if _compact:
		_build_architectures_compact()
		return
	var grid: GridContainer = _grid(ARCH_COLUMNS)
	_value_cell(grid, "")
	# accessibility.md §8.2: at 150 % in German the three caps headers squeezed
	# the names until they broke inside the word. The headers wrap; the name does
	# not, and takes twice their share of the spare width.
	for key: String in ARCH_HEADERS:
		_caps_cell(grid, key, true)
	for def: ArchitectureDef in _unlocked_architectures():
		var name_label: Label = _value_cell(grid, tr(ArchitectureDef.name_key(def.id)))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.size_flags_stretch_ratio = NAME_STRETCH
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		for value: String in _architecture_values(def):
			_value_cell(grid, value)


## S7.IP (seen in S6.9): on a phone the name took the row and the three headers
## were left a letter or two wide (*FAST / EST / WIN*). Each architecture gets
## the totals' two columns instead: its name, then caption and figure per line.
func _build_architectures_compact() -> void:
	for def: ArchitectureDef in _unlocked_architectures():
		var name_label: Label = _label(_content, tr(ArchitectureDef.name_key(def.id)),
			&"ValueLabel")
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var grid: GridContainer = _grid(2)
		var values: Array[String] = _architecture_values(def)
		for i: int in ARCH_HEADERS.size():
			_caps_cell(grid, ARCH_HEADERS[i], true)
			_value_cell(grid, values[i])


func _unlocked_architectures() -> Array[ArchitectureDef]:
	var out: Array[ArchitectureDef] = []
	for def: ArchitectureDef in _db.architectures:
		if ProfileManager.is_unlocked(def):
			out.append(def)
	return out


## Runs, wins and the fastest win, in the order of `ARCH_HEADERS`.
func _architecture_values(def: ArchitectureDef) -> Array[String]:
	var row: Dictionary = ProfileManager.by_architecture.get(def.id, {})
	var best: int = int(row.get(ProfileManager.ARCH_BEST_DAYS, 0))
	return [
		Format.number(float(row.get(ProfileManager.ARCH_RUNS, 0)), Format.Kind.DAYS),
		Format.number(float(row.get(ProfileManager.ARCH_WINS, 0)), Format.Kind.DAYS),
		DASH if best <= 0 else Format.number(float(best), Format.Kind.DAYS),
	]


## release.md §2.4: section 4 — the count, then one row per achievement in
## file order. Rows are read, not used: none takes focus.
func _build_achievements() -> void:
	_section(KEY_ACHIEVEMENTS)
	var book: AchievementBook = ProfileManager.book
	var profile: Dictionary = ProfileManager.to_dict()
	var codex_totals: Dictionary[String, Array] = {
		CodexEntries.TAB_REGIONS: CodexEntries.ids(CodexEntries.TAB_REGIONS, _db)}
	var earned: int = 0
	for def: AchievementDef in book.defs:
		if ProfileManager.achievements.has(def.id):
			earned += 1
	_label(_content, tr(KEY_ACHIEVEMENTS_COUNT).format({"earned": earned,
		"total": book.defs.size()}), &"LabelCaption")
	for def: AchievementDef in book.defs:
		_content.add_child(_achievement_row(def, book, profile, codex_totals))


func _achievement_row(def: AchievementDef, book: AchievementBook, profile: Dictionary,
		codex_totals: Dictionary[String, Array]) -> Control:
	var is_earned: bool = ProfileManager.achievements.has(def.id)
	var classified: bool = def.hidden and not is_earned
	var name_text: String = tr(KEY_ACH_HIDDEN_NAME) if classified 		else tr(AchievementDef.name_key(def.id))
	var detail_text: String = tr(KEY_ACH_HIDDEN_DETAIL) if classified 		else tr(AchievementDef.detail_key(def.id)).format(book.detail_values(def))
	var state_text: String = tr(KEY_ACH_LOCKED)
	var variation: StringName = VARIATION_LOCKED
	if is_earned:
		state_text = tr(KEY_ACH_EARNED)
		variation = VARIATION_EARNED
	elif not classified:
		var progress: Array[int] = book.progress(def, profile, codex_totals)
		if progress[0] >= 0:
			state_text = tr(KEY_ACH_PROGRESS).format({"count": progress[0],
				"needed": progress[1]})
			variation = VARIATION_PROGRESS
	var row: HBoxContainer = HBoxContainer.new()
	row.theme_type_variation = &"Row"
	var text: VBoxContainer = VBoxContainer.new()
	text.theme_type_variation = &"StackTight"
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	# A long German name at 150 % is wider than a phone (S6.9): it wraps.
	_label(text, name_text, &"").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var detail: Label = _label(text, detail_text, &"LabelCaptionHint")
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# In compact the state drops under the detail (§2.4).
	var state: HBoxContainer = HBoxContainer.new()
	state.theme_type_variation = &"Row"
	state.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if _compact 		else Control.SIZE_SHRINK_END
	state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if _compact:
		text.add_child(state)
	else:
		row.add_child(state)
	if is_earned:
		var check: GlyphIcon = GlyphIcon.new()
		check.glyph = Glyphs.Glyph.CHECK
		check.color_token = &"ACCENT"
		check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		state.add_child(check)
	var state_label: Label = _label(state, state_text, variation)
	state_label.name = "State"
	row.name = "Achievement_" + def.id
	# accessibility.md §3.2: the name as shown; the detail, then the state.
	row.accessibility_name = name_text
	row.accessibility_description = A11y.label_value(detail_text, state_text)
	return row


## §6.2 item 3: newest first. The outcome's name, and the ending's line under it.
func _build_recent() -> void:
	_section(KEY_RECENT)
	if ProfileManager.history.is_empty():
		_label(_content, tr(KEY_EMPTY), &"LabelCaption")
		return
	for entry: Dictionary in ProfileManager.history:
		_content.add_child(_run_block(entry))


func _run_block(entry: Dictionary) -> Control:
	var block: VBoxContainer = VBoxContainer.new()
	block.theme_type_variation = &"StackTight"
	var head: HBoxContainer = HBoxContainer.new()
	head.theme_type_variation = &"Row"
	block.add_child(head)
	_label(head, tr(KEY_RUN_NUMBER).format({"n": int(entry.get("n", 0))}), &"ValueLabel")
	var architecture: Label = _label(head, _setup_text(entry), &"")
	architecture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# An architecture with a scenario is wider than a phone's row (S6.9).
	architecture.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var outcome: String = str(entry.get("outcome", ""))
	# On a phone the outcome squeezed the architecture's name until it broke
	# inside the word (S7.IP): it takes the line under the head there.
	var outcome_label: Label = _label(block if _compact else head,
		tr(PREFIX_OUTCOME + outcome.to_upper()), &"")
	var variant: String = str(entry.get("variant", outcome))
	var line: Label = _label(block, tr(EndingLineDef.verdict_key(variant)), &"LabelCaption")
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outcome_label.tooltip_text = line.text
	outcome_label.mouse_filter = Control.MOUSE_FILTER_PASS
	var foot: HBoxContainer = HBoxContainer.new()
	foot.theme_type_variation = &"Row"
	block.add_child(foot)
	var days: CapsLabel = CapsLabel.new()
	days.label_key = KEY_COL_DAYS
	days.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(days)
	_label(foot, Format.number(float(entry.get("days", 0)), Format.Kind.DAYS), &"ValueLabel") \
		.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var seed_caption: CapsLabel = CapsLabel.new()
	seed_caption.label_key = KEY_COL_SEED
	seed_caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(seed_caption)
	var seed_value: int = int(entry.get("seed", 0))
	var seed_label: Label = _label(foot, str(seed_value), &"ValueLabel")
	seed_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var replay: ConsoleButton = ConsoleButton.new()
	replay.label_key = KEY_REPLAY
	replay.compact = true
	replay.disabled = seed_value <= 0
	replay.pressed.connect(_on_replay_pressed.bind(entry))
	if _compact:
		# Days, seed and the button are wider than a phone (S6.9): the button
		# takes a line of its own under them, and wraps at 150 % in German.
		replay.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		block.add_child(replay)
	else:
		foot.add_child(replay)
	var rule: HSeparator = HSeparator.new()
	rule.theme_type_variation = &"PanelRule"
	block.add_child(rule)
	return block


## The architecture's name, paired with the scenario's when the run had one.
func _setup_text(entry: Dictionary) -> String:
	var architecture: String = tr(ArchitectureDef.name_key(str(entry.get("architecture", ""))))
	var scenario: String = str(entry.get("scenario", ""))
	if scenario.is_empty():
		return architecture
	return tr(KEY_SCENARIO_PAIR).format({"architecture": architecture,
		"scenario": tr(ScenarioDef.name_key(scenario))})


func _on_replay_pressed(entry: Dictionary) -> void:
	var directives: Array[String] = []
	for id: Variant in entry.get("directives", []):
		directives.append(str(id))
	var setup: RunSetup = RunSetup.create(str(entry.get("architecture", ArchitectureDef.DEFAULT_ID)),
		directives, str(entry.get("difficulty", DifficultyDef.DEFAULT_ID)),
		str(entry.get("scenario", "")))
	replay_requested.emit(int(entry.get("seed", 0)), setup)


# ---------------------------------------------------------------- cells


func _section(key: String) -> void:
	var title: CapsLabel = CapsLabel.new()
	title.label_key = key
	_content.add_child(title)


func _grid(columns: int) -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.columns = columns
	grid.theme_type_variation = &"Grid"
	_content.add_child(grid)
	return grid


func _caps_cell(grid: GridContainer, key: String, expand: bool) -> void:
	var cell: CapsLabel = CapsLabel.new()
	cell.label_key = key
	# Only a cell that takes the spare width may wrap: a wrapping label in a
	# column that only takes its minimum is one letter wide.
	if expand:
		cell.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(cell)


func _value_cell(grid: GridContainer, text: String) -> Label:
	return _label(grid, text, &"ValueLabel")


static func _label(into: Control, text: String, variation: StringName) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	into.add_child(label)
	return label


## As tall as the window allows, like the Codex. Crossing the breakpoint lays
## the achievements out again.
func _fit() -> void:
	_panel.custom_minimum_size.y = maxf(get_viewport_rect().size.y
		- float(UiTokens.SPACE_6) * 2.0, 0.0)
	if visible and _db != null 			and (get_viewport_rect().size.x < float(UiTokens.COMPACT_WIDTH)) != _compact:
		refresh()
