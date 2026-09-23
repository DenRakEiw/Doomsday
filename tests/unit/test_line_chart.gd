extends GutTest
## S4.8 — `LineChart` (analysis.md §6): scales, ticks, end labels, the cursor, the
## table days, the empty state and a stack.

const WIDTH: float = 600.0
const HEIGHT: float = 240.0

var _root: Control = null


func before_each() -> void:
	_root = Control.new()
	_root.theme = ThemeBuilder.build(ThemeBuilder.VARIANT_COLD)
	add_child_autofree(_root)


func _chart(series: Array[ChartSeries], day_max: int = 100, y_max: float = 0.0) -> LineChart:
	var chart: LineChart = LineChart.new()
	_root.add_child(chart)
	chart.size = Vector2(WIDTH, HEIGHT)
	chart.set_series(series)
	chart.set_domain(day_max, y_max)
	return chart


func _line(values: Array[float], days: Array[int] = [], key: String = "UI_SERIES_SHARE",
		stacked: bool = false) -> ChartSeries:
	var day_list: PackedInt32Array = PackedInt32Array()
	for i: int in values.size():
		day_list.append(days[i] if not days.is_empty() else i * 10)
	return ChartSeries.create(key, Color.WHITE, day_list, PackedFloat32Array(values), stacked)


func test_days_and_values_map_into_the_plot() -> void:
	var chart: LineChart = _chart([_line([0.0, 0.5, 1.0])] as Array[ChartSeries], 100, 1.0)
	var plot: Rect2 = chart.plot_rect()
	assert_almost_eq(chart.day_to_x(0.0), plot.position.x, 1e-4)
	assert_almost_eq(chart.day_to_x(100.0), plot.end.x, 1e-4)
	assert_almost_eq(chart.value_to_y(0.0), plot.end.y, 1e-4)
	assert_almost_eq(chart.value_to_y(1.0), plot.position.y, 1e-4)
	assert_almost_eq(plot.position.x, UiTokens.CHART_AXIS_W, 1e-4)
	assert_almost_eq(plot.end.x, WIDTH - UiTokens.CHART_LABEL_W, 1e-4)


func test_nice_rounds_up_to_one_two_or_five() -> void:
	assert_eq(LineChart.nice(0.7), 1.0)
	assert_eq(LineChart.nice(1.3), 2.0)
	assert_eq(LineChart.nice(3.1), 5.0)
	assert_eq(LineChart.nice(7.0), 10.0)
	assert_almost_eq(LineChart.nice(0.013), 0.02, 1e-9)
	assert_eq(LineChart.nice(420.0), 500.0)


func test_auto_y_is_nice_headroom_and_respects_the_minimum_span() -> void:
	var chart: LineChart = _chart([_line([1.0, 3.0])] as Array[ChartSeries])
	assert_eq(chart.y_max(), 5.0, "3 × 1.1 → 5")
	chart.min_span = 10.0
	assert_eq(chart.y_max(), 10.0)


func test_the_x_tick_leaves_eighty_pixels() -> void:
	var chart: LineChart = _chart([_line([1.0, 2.0])] as Array[ChartSeries], 400)
	assert_eq(chart.x_tick_step(800.0), 50, "50 days = 100 px")
	assert_eq(chart.x_tick_step(400.0), 100)
	assert_eq(chart.x_tick_step(100.0), 500)


func test_an_end_label_that_would_overlap_is_dropped() -> void:
	var chart: LineChart = _chart([_line([0.5, 0.50]), _line([0.4, 0.501])] as Array[ChartSeries],
		10, 1.0)
	assert_eq(chart.end_labels().size(), 1, "two lines ending together keep one label")
	var apart: LineChart = _chart([_line([0.1, 0.1]), _line([0.9, 0.9])] as Array[ChartSeries],
		10, 1.0)
	assert_eq(apart.end_labels().size(), 2)


func test_the_cursor_snaps_to_a_sample_and_reads_every_series() -> void:
	var chart: LineChart = _chart([_line([1.0, 2.0, 3.0]), _line([4.0, 5.0])] as Array[ChartSeries])
	chart.set_cursor(12)
	assert_eq(chart.cursor_day(), 10)
	var values: PackedFloat32Array = chart.values_at(20)
	assert_eq(values[0], 3.0)
	assert_true(is_nan(values[1]), "the shorter series has no sample on day 20")
	chart.set_cursor(-1)
	assert_eq(chart.cursor_day(), -1)


func test_the_keyboard_steps_one_sample() -> void:
	var chart: LineChart = _chart([_line([1.0, 2.0, 3.0])] as Array[ChartSeries])
	var moved: Array[int] = []
	chart.cursor_moved.connect(func(day: int) -> void: moved.append(day))
	chart.set_cursor(10)
	var key: InputEventKey = InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_RIGHT
	chart._gui_input(key)
	assert_eq(chart.cursor_day(), 20)
	key.keycode = KEY_HOME
	chart._gui_input(key)
	assert_eq(chart.cursor_day(), 0)
	assert_eq(moved, [20, 0] as Array[int])


func test_table_days_are_seventeen_unique_ascending_for_a_long_run() -> void:
	var values: Array[float] = []
	var days: Array[int] = []
	for day: int in 401:
		values.append(float(day))
		days.append(day)
	var chart: LineChart = _chart([_line(values, days)] as Array[ChartSeries], 400)
	var table: PackedInt32Array = chart.table_days(400)
	assert_eq(table.size(), 16, "sixteen evenly spaced, the last already among them")
	assert_eq(table[0], 0)
	assert_eq(table[table.size() - 1], 400)
	for i: int in range(1, table.size()):
		assert_gt(table[i], table[i - 1])
	var sparse: LineChart = _chart([_line([1.0, 2.0, 3.0], [0, 7, 397])] as Array[ChartSeries], 400)
	var short: PackedInt32Array = sparse.table_days(400)
	assert_eq(Array(short), [0, 7, 397], "snapped, de-duplicated, the last included")


func test_one_point_is_the_empty_state() -> void:
	var chart: LineChart = _chart([_line([1.0])] as Array[ChartSeries])
	assert_true(chart._is_empty())
	assert_false(_chart([_line([1.0, 2.0])] as Array[ChartSeries])._is_empty())


func test_a_stack_adds_up() -> void:
	var stack: Array[ChartSeries] = [_line([1.0, 2.0], [], "a", true),
		_line([3.0, 4.0], [], "b", true), _line([5.0, 6.0], [], "c", true)]
	var chart: LineChart = _chart(stack, 10)
	assert_eq(chart.y_max(), 20.0, "the top of the stack is 12, × 1.1 → 20")
	var labels: Array[Dictionary] = chart.end_labels()
	var tops: Array[float] = []
	for label: Dictionary in labels:
		tops.append(float(label["y"]))
	assert_true(tops.has(chart.value_to_y(12.0)), "the last series ends at the sum")


func test_values_format_by_the_charts_kind() -> void:
	var chart: LineChart = _chart([_line([0.0, 0.5])] as Array[ChartSeries])
	chart.kind = Format.Kind.PERCENT
	assert_eq(chart.format_value(0.5), Format.percent(0.5))
	chart.fine = true
	assert_eq(chart.format_value(0.0042), Format.percent_fine(0.0042))
	chart.kind = Format.Kind.PLAIN
	chart.decimals = 2
	assert_eq(chart.format_value(1.234), Format.decimal(1.234, 2))
	assert_eq(chart.format_value(NAN), "—")
