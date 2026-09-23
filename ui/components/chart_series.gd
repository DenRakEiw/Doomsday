class_name ChartSeries
extends RefCounted
## One line of a `LineChart` (analysis.md §6.1): its name, its colour, and its
## points as offsets from the origin day.

## The string key of the series' name; the chart `tr()`s it.
var key: String = ""
var color: Color = Color.WHITE
## Days since the origin, ascending.
var days: PackedInt32Array = PackedInt32Array()
## One per day.
var values: PackedFloat32Array = PackedFloat32Array()
## Drawn as an area on top of the previous stacked series.
var stacked: bool = false


static func create(name_key: String, colour: Color, day_values: PackedInt32Array,
		point_values: PackedFloat32Array, is_stacked: bool = false) -> ChartSeries:
	var series: ChartSeries = ChartSeries.new()
	series.key = name_key
	series.color = colour
	series.days = day_values
	series.values = point_values
	series.stacked = is_stacked
	return series


## The value at `day`, or NAN when the series has no sample that day.
func value_at(day: int) -> float:
	var at: int = days.bsearch(day)
	if at < days.size() and days[at] == day:
		return values[at]
	return NAN
