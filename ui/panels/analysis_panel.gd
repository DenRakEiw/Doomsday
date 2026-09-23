extends SlidePanel
## The graphs screen (analysis.md §5): a bottom sheet over the live map with the
## run in charts on three tabs, a log on the fourth, a strip of the run's beats
## over the charts, and a table twin for every chart.
##
## Not a modal: the run goes on and the charts extend on every tick while the
## sheet is open; nothing is computed while it is closed. The session keeps it,
## the region panel and the containment panel from ever sharing the screen.
##
## Scene-specific, so no `class_name`. Built in code: the tabs and the log are
## rebuilt from the world, and a `%` name inside a moved subtree does not survive
## (PROGRESS.md, *Known issues*).

## The back button (or `Escape`) in review: the results should come back.
signal back_requested

enum Tab { RUN, OPPOSITION, WORLD, LOG }
enum Filter { ALL, YOURS, THEIRS }

const TAB_KEYS: Array[String] = ["UI_ANALYSIS_TAB_RUN", "UI_ANALYSIS_TAB_OPPOSITION",
	"UI_ANALYSIS_TAB_WORLD", "UI_ANALYSIS_TAB_LOG"]
const FILTER_KEYS: Array[String] = ["UI_LOG_FILTER_ALL", "UI_LOG_FILTER_YOURS",
	"UI_LOG_FILTER_THEIRS"]
const KEY_TITLE: String = "UI_ANALYSIS_TITLE"
const KEY_TABLE: String = "UI_ANALYSIS_TABLE"
const KEY_CHARTS: String = "UI_ANALYSIS_CHARTS"
const KEY_BACK: String = "UI_ANALYSIS_BACK_TO_RESULTS"
const KEY_TABLE_DAY: String = "UI_ANALYSIS_TABLE_DAY"
const KEY_EMPTY_LOG: String = "UI_LOG_EMPTY"
const KEY_CLOSE: String = "UI_COMMON_CLOSE"
## Every key the panel shows itself (the strings test reads this list).
const KEYS: Array[String] = ["UI_ANALYSIS_TITLE", "UI_ANALYSIS_TAB_RUN",
	"UI_ANALYSIS_TAB_OPPOSITION", "UI_ANALYSIS_TAB_WORLD", "UI_ANALYSIS_TAB_LOG",
	"UI_ANALYSIS_TABLE", "UI_ANALYSIS_CHARTS", "UI_ANALYSIS_X_DAYS", "UI_ANALYSIS_TABLE_DAY",
	"UI_ANALYSIS_EMPTY", "UI_ANALYSIS_NOT_DISCOVERED", "UI_ANALYSIS_CURSOR_DAY",
	"UI_ANALYSIS_BACK_TO_RESULTS", "UI_ANALYSIS_REVIEW", "UI_ANALYSIS_STRIP_TIP",
	"UI_CHART_REACH", "UI_CHART_COMPUTE", "UI_CHART_FOOTPRINT", "UI_CHART_HARM",
	"UI_CHART_RISK", "UI_CHART_CONTAINMENT", "UI_CHART_PRESSURE", "UI_CHART_REGIONS",
	"UI_CHART_POPULATION", "UI_CHART_SOCIETY", "UI_SERIES_SHARE", "UI_SERIES_COMPUTE",
	"UI_SERIES_FOOTPRINT", "UI_SERIES_HARM", "UI_SERIES_RISK", "UI_SERIES_REGIONS_REACHED",
	"UI_SERIES_REGIONS_CONTROLLED", "UI_SERIES_REGIONS_DARK", "UI_SERIES_ALIVE",
	"UI_SERIES_DEATHS", "UI_LOG_FILTER_ALL", "UI_LOG_FILTER_YOURS", "UI_LOG_FILTER_THEIRS",
	"UI_LOG_EMPTY"]
const TITLE_JOIN: String = " · "

## Remembered for the session (§5.2).
var current_tab: Tab = Tab.RUN
var showing_table: bool = false
var log_filter: Filter = Filter.ALL
## §5.9: opened from the results screen; closing goes back there.
var in_review: bool = false
var compact: bool = false:
	set(value):
		compact = value
		_apply_compact()

var _panel_box: PanelContainer = null
var _title: Label = null
var _tab_buttons: Array[ConsoleButton] = []
var _table_button: ConsoleButton = null
var _back_button: ConsoleButton = null
var _close_button: IconButton = null
var _strip: TimelineStrip = null
var _scroll: ScrollContainer = null
var _body: VBoxContainer = null
var _tabs: Array[AnalysisTab] = []
var _table: Tree = null
var _log_box: VBoxContainer = null
var _filter_buttons: Array[ConsoleButton] = []
var _log_list: VBoxContainer = null
var _log_empty: Label = null
## How many entries the log list shows, and the first one's day — the list is
## rebuilt when the cap rotates the oldest out.
var _log_shown: int = -1
var _log_first: RunLogEntry = null


func _ready() -> void:
	_build()
	super()
	edge = SlidePanel.Edge.BOTTOM
	height_share = UiTokens.ANALYSIS_HEIGHT_SHARE
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.run_started.connect(_on_run_started)
	EventBus.run_ended.connect(_on_run_ended)
	EventBus.locale_changed.connect(_on_locale_changed)
	_select_tab(current_tab)


func open() -> void:
	super()
	refresh()
	if current_tab < _tab_buttons.size():
		_tab_buttons[current_tab].grab_focus.call_deferred()


## §5.9: from the results screen — the back button replaces the way out.
func open_review() -> void:
	in_review = true
	_back_button.visible = true
	open()


## Closing in review goes back to the results (§5.9).
func close() -> void:
	var was_review: bool = in_review
	in_review = false
	if _back_button != null:
		_back_button.visible = false
	super()
	if was_review:
		back_requested.emit()


## Re-reads the run into the tab on show. Cheap enough per tick: a few hundred
## samples into four charts.
func refresh() -> void:
	if Game.sim == null or not is_open:
		return
	var world: World = Game.sim.world
	if current_tab == Tab.LOG:
		_refresh_log(world)
		return
	var tab: AnalysisTab = _tabs[current_tab]
	tab.refresh(world, Game.db)
	_refresh_strip(world)
	if showing_table:
		_fill_table(tab)


func select_tab(tab: Tab) -> void:
	_select_tab(tab)


func set_table(on: bool) -> void:
	showing_table = on
	_apply_table()
	refresh()


func set_log_filter(filter: Filter) -> void:
	log_filter = filter
	for i: int in _filter_buttons.size():
		_filter_buttons[i].button_pressed = i == filter
	_log_shown = -1
	refresh()


## The pieces a test reaches for.
func tab(index: Tab) -> AnalysisTab:
	return _tabs[index] if index < _tabs.size() else null


func strip() -> TimelineStrip:
	return _strip


func table() -> Tree:
	return _table


func log_rows() -> Array[Control]:
	var out: Array[Control] = []
	for child: Node in _log_list.get_children():
		out.append(child as Control)
	return out


# --------------------------------------------------------------------- build


func _build() -> void:
	_panel_box = PanelContainer.new()
	_panel_box.name = "Panel"
	_panel_box.theme_type_variation = &"ConsolePanel"
	add_child(_panel_box)
	var content: VBoxContainer = VBoxContainer.new()
	content.theme_type_variation = &"PanelContent"
	_panel_box.add_child(content)
	content.add_child(_build_header())
	_strip = TimelineStrip.new()
	_strip.day_pressed.connect(_on_strip_day_pressed)
	content.add_child(_strip)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.theme_type_variation = &"Stack"
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)
	for kind: AnalysisTab.Kind in [AnalysisTab.Kind.RUN, AnalysisTab.Kind.OPPOSITION,
			AnalysisTab.Kind.WORLD]:
		var one: AnalysisTab = AnalysisTab.create(kind)
		one.cursor_moved.connect(_on_tab_cursor_moved)
		_body.add_child(one)
		_tabs.append(one)
	_table = Tree.new()
	_table.hide_root = true
	_table.column_titles_visible = true
	_table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_table.custom_minimum_size.y = float(UiTokens.CHART_MIN_HEIGHT) * 2.0
	_table.visible = false
	_body.add_child(_table)
	_body.add_child(_build_log())


func _build_header() -> Control:
	var header: HFlowContainer = HFlowContainer.new()
	header.theme_type_variation = &"FlowSnug"
	_title = Label.new()
	_title.theme_type_variation = &"LabelDisplay"
	header.add_child(_title)
	for i: int in TAB_KEYS.size():
		var button: ConsoleButton = ConsoleButton.new()
		button.label_key = TAB_KEYS[i]
		button.toggle_mode = true
		button.compact = true
		button.pressed.connect(_select_tab.bind(i))
		header.add_child(button)
		_tab_buttons.append(button)
	_table_button = ConsoleButton.new()
	_table_button.compact = true
	_table_button.pressed.connect(_on_table_pressed)
	header.add_child(_table_button)
	_back_button = ConsoleButton.new()
	_back_button.label_key = KEY_BACK
	_back_button.compact = true
	_back_button.visible = false
	_back_button.pressed.connect(close)
	header.add_child(_back_button)
	_close_button = IconButton.new()
	_close_button.glyph = Glyphs.Glyph.CLOSE
	_close_button.tooltip_key = KEY_CLOSE
	_close_button.pressed.connect(close)
	header.add_child(_close_button)
	return header


func _build_log() -> Control:
	_log_box = VBoxContainer.new()
	_log_box.theme_type_variation = &"Stack"
	_log_box.visible = false
	var filters: HBoxContainer = HBoxContainer.new()
	filters.theme_type_variation = &"RowSnug"
	for i: int in FILTER_KEYS.size():
		var button: ConsoleButton = ConsoleButton.new()
		button.label_key = FILTER_KEYS[i]
		button.toggle_mode = true
		button.compact = true
		button.button_pressed = i == log_filter
		button.pressed.connect(set_log_filter.bind(i))
		filters.add_child(button)
		_filter_buttons.append(button)
	_log_box.add_child(filters)
	_log_empty = Label.new()
	_log_empty.theme_type_variation = &"LabelCaption"
	_log_empty.text = tr(KEY_EMPTY_LOG)
	_log_box.add_child(_log_empty)
	_log_list = VBoxContainer.new()
	_log_list.theme_type_variation = &"StackTight"
	_log_box.add_child(_log_list)
	return _log_box


# ---------------------------------------------------------------------- tabs


func _select_tab(index: int) -> void:
	current_tab = index as Tab
	for i: int in _tab_buttons.size():
		_tab_buttons[i].button_pressed = i == index
	var is_log: bool = current_tab == Tab.LOG
	_strip.visible = not is_log
	_table_button.visible = not is_log
	_log_box.visible = is_log
	_log_shown = -1
	_apply_table()
	_refresh_strings()
	refresh()


func _apply_table() -> void:
	var is_log: bool = current_tab == Tab.LOG
	for i: int in _tabs.size():
		_tabs[i].visible = not is_log and not showing_table and i == current_tab
	_table.visible = not is_log and showing_table
	_table_button.label_key = KEY_CHARTS if showing_table else KEY_TABLE


func _apply_compact() -> void:
	height_share = UiTokens.ANALYSIS_HEIGHT_SHARE_COMPACT if compact \
		else UiTokens.ANALYSIS_HEIGHT_SHARE
	for one: AnalysisTab in _tabs:
		one.compact = compact


func _refresh_strings() -> void:
	_title.text = tr(KEY_TITLE)
	_log_empty.text = tr(KEY_EMPTY_LOG)
	_table_button.label_key = KEY_CHARTS if showing_table else KEY_TABLE


# ---------------------------------------------------------------------- strip


## §7: the marks come from the run log; the domain and the bands are the tab's.
func _refresh_strip(world: World) -> void:
	var marks: Array[Dictionary] = []
	for entry: RunLogEntry in world.run_log:
		var mark: Dictionary = RunLogText.marker(entry)
		if mark.is_empty():
			continue
		mark["day"] = entry.day - world.origin_day
		mark["text"] = RunLogText.text(entry, Game.db)
		marks.append(mark)
	var last: int = 0
	if not world.history.is_empty():
		last = world.history.back().day - world.origin_day
	_strip.set_domain(maxi(last, UiTokens.MIN_SPAN_DAYS))
	_strip.set_bands(AnalysisTab.phase_bands(world))
	_strip.set_marks(marks)


# ---------------------------------------------------------------------- table


## §5.8: a day column, then one per series in chart order; a name two charts
## share carries its chart's title.
func _fill_table(one: AnalysisTab) -> void:
	_table.clear()
	var columns: Array[Array] = []
	var names: Dictionary[String, int] = {}
	for chart: LineChart in one.charts():
		for series: ChartSeries in chart.series():
			names[series.key] = int(names.get(series.key, 0)) + 1
	var widest: LineChart = null
	for chart: LineChart in one.charts():
		for i: int in chart.series().size():
			columns.append([chart, i])
		if widest == null or _last_day(chart) > _last_day(widest):
			widest = chart
	_table.columns = columns.size() + 1
	_table.set_column_title(0, tr(KEY_TABLE_DAY))
	for c: int in columns.size():
		var chart: LineChart = columns[c][0]
		var series: ChartSeries = chart.series()[int(columns[c][1])]
		var title: String = tr(series.key)
		if int(names[series.key]) > 1:
			title = tr(chart.title_key) + TITLE_JOIN + title
		_table.set_column_title(c + 1, title)
	var root: TreeItem = _table.create_item()
	if widest == null:
		return
	for day: int in widest.table_days(_last_day(widest)):
		var row: TreeItem = _table.create_item(root)
		row.set_text(0, Format.number(float(day), Format.Kind.DAYS))
		for c: int in columns.size():
			var chart: LineChart = columns[c][0]
			var series: ChartSeries = chart.series()[int(columns[c][1])]
			row.set_text(c + 1, chart.format_value(series.value_at(day)))


static func _last_day(chart: LineChart) -> int:
	var last: int = 0
	for series: ChartSeries in chart.series():
		if not series.days.is_empty():
			last = maxi(last, series.days[series.days.size() - 1])
	return last


# ------------------------------------------------------------------------ log


## §5.6: oldest first, filtered; rebuilt when the cap rotated or the filter
## changed, appended otherwise.
func _refresh_log(world: World) -> void:
	var first: RunLogEntry = world.run_log[0] if not world.run_log.is_empty() else null
	var at_end: bool = _scroll.scroll_vertical >= int(_scroll.get_v_scroll_bar().max_value
		- _scroll.get_v_scroll_bar().page) - 1
	var rebuilt: bool = first != _log_first or _log_shown < 0 \
		or _log_shown > world.run_log.size()
	if rebuilt:
		for child: Node in _log_list.get_children():
			_log_list.remove_child(child)
			child.queue_free()
		_log_shown = 0
		_log_first = first
	for i: int in range(_log_shown, world.run_log.size()):
		var entry: RunLogEntry = world.run_log[i]
		if _passes(entry):
			_log_list.add_child(_log_row(entry, world))
	_log_shown = world.run_log.size()
	_log_empty.visible = _log_list.get_child_count() == 0
	# §5.6: at the end on open; kept at the end when a line lands there; left
	# alone for a reader who scrolled up.
	if at_end or rebuilt:
		_scroll_to_end()


func _passes(entry: RunLogEntry) -> bool:
	match log_filter:
		Filter.YOURS:
			return RunLogText.is_yours(entry)
		Filter.THEIRS:
			return not RunLogText.is_yours(entry)
	return true


func _log_row(entry: RunLogEntry, world: World) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.theme_type_variation = &"RowSnug"
	row.custom_minimum_size.y = float(UiTokens.LOG_ROW_MIN_H)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var day: Label = Label.new()
	day.theme_type_variation = &"LabelCaption"
	day.custom_minimum_size.x = float(UiTokens.LOG_DAY_W)
	day.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	day.text = Format.number(float(entry.day - world.origin_day), Format.Kind.DAYS)
	row.add_child(day)
	var mark: Dictionary = RunLogText.row_glyph(entry)
	var glyph: GlyphIcon = GlyphIcon.new()
	glyph.glyph = mark["glyph"]
	glyph.box_size = UiTokens.FACTION_GLYPH
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glyph.color_token = mark["token"]
	row.add_child(glyph)
	var text: Label = Label.new()
	text.text = RunLogText.text(entry, Game.db)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var region: int = RunLogText.region_index(entry, Game.db)
	if region <= 0:
		return row
	# §5.6: a line about a region is a way to it.
	var button: ConsoleButton = ConsoleButton.new()
	button.list_row = true
	button.custom_minimum_size.y = float(UiTokens.HIT_MIN)
	button.pressed.connect(_on_log_region_pressed.bind(region))
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(row)
	# A button does not measure what it carries, and on a phone a wrapped line is
	# taller than the hit target: the rows ran into each other (S4.9 screenshots).
	# The button grows with its row.
	row.minimum_size_changed.connect(func() -> void:
		button.custom_minimum_size.y = maxf(float(UiTokens.HIT_MIN),
			row.get_combined_minimum_size().y))
	return button


## After the new rows are laid out: two frames, because the scroll bar learns its
## range one frame after the list grows.
func _scroll_to_end() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if is_inside_tree():
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


# -------------------------------------------------------------------- signals


func _on_table_pressed() -> void:
	set_table(not showing_table)


func _on_tab_cursor_moved(day: int) -> void:
	_strip.queue_redraw()
	if day >= 0 and current_tab < _tabs.size():
		_tabs[current_tab].set_cursor(day)


func _on_strip_day_pressed(day: int) -> void:
	if current_tab < _tabs.size():
		_tabs[current_tab].set_cursor(day)


func _on_log_region_pressed(region: int) -> void:
	EventBus.region_selected.emit(region)


func _on_tick_advanced(_day: int) -> void:
	refresh()


func _on_run_started(_seed_value: int) -> void:
	in_review = false
	if _back_button != null:
		_back_button.visible = false
	if is_open:
		super.close()
	_log_shown = -1


func _on_run_ended(_outcome: String) -> void:
	refresh()


func _on_locale_changed(_locale: String) -> void:
	_refresh_strings()
	_log_shown = -1
	refresh()
