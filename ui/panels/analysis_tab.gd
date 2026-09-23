class_name AnalysisTab
extends VBoxContainer
## One of the Analysis sheet's three chart tabs (analysis.md §5.3–§5.5): builds
## its charts once, then turns `world.history` into their series on every
## refresh. The x domain is the same for every chart on the tab, so a cursor or
## a strip mark means the same day on all of them.

signal cursor_moved(day: int)

enum Kind { RUN, OPPOSITION, WORLD }

const KEY_NOT_DISCOVERED: String = "UI_ANALYSIS_NOT_DISCOVERED"
const PREFIX_FACTION: String = "FACTION_"
const PREFIX_PHASE: String = "UI_PHASE_"
const PREFIX_STAGE: String = "SOCIETY_STAGE_"
## The floors of the automatic y domains (§5.3–§5.5).
const SPAN_FOOTPRINT: float = 10.0
const SPAN_HARM: float = 1.0
const SPAN_RISK: float = 0.01
const SPAN_PRESSURE: float = 2.0
const SPAN_ASSETS: float = 4.0
const TWO_DECIMALS: int = 2
## The ramp positions of stages 1…5 (§9): more disorder, brighter.
const STAGE_RAMP: Array[float] = [0.0, 0.25, 0.5, 0.75, 1.0]
const COLUMNS_WIDE: int = 2
const COLUMNS_COMPACT: int = 1
const ASSET_COLUMNS: int = 2

var kind: Kind = Kind.RUN
var compact: bool = false:
	set(value):
		compact = value
		_apply_compact()

var _charts: Array[LineChart] = []
var _grid: GridContainer = null
## Opposition: the risk chart, the note under it, the two faction charts' row.
var _risk_chart: LineChart = null
var _note: Label = null
var _faction_row: GridContainer = null
## World: the four small multiples.
var _asset_grid: GridContainer = null
var _asset_charts: Array[LineChart] = []
var _built: bool = false


static func create(tab_kind: Kind) -> AnalysisTab:
	var tab: AnalysisTab = AnalysisTab.new()
	tab.kind = tab_kind
	tab.theme_type_variation = &"Stack"
	tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return tab


## Every chart on the tab, in the order the table reads them.
func charts() -> Array[LineChart]:
	return _charts


## The series and the domain from the world as it stands; builds the charts the
## first time. `db` gives the regions, the thresholds and the population.
func refresh(world: World, db: ContentDB) -> void:
	if not _built:
		_build(db)
	var days: PackedInt32Array = PackedInt32Array()
	for sample: HistorySample in world.history:
		days.append(sample.day - world.origin_day)
	var last: int = days[days.size() - 1] if not days.is_empty() else 0
	var day_max: int = maxi(last, UiTokens.MIN_SPAN_DAYS)
	var bands: Array[Dictionary] = phase_bands(world)
	match kind:
		Kind.RUN:
			_refresh_run(world, days)
		Kind.OPPOSITION:
			_refresh_opposition(world, db, days)
		Kind.WORLD:
			_refresh_world(world, db, days)
	for chart: LineChart in _charts:
		chart.set_domain(day_max, _fixed_y(chart, world, db))
		chart.set_bands(bands)


## Puts every chart's cursor on `day` (a strip mark, another chart's cursor).
func set_cursor(day: int) -> void:
	for chart: LineChart in _charts:
		chart.set_cursor(day)


## The phases as bands in days since the origin: one per run of equal phase ids.
static func phase_bands(world: World) -> Array[Dictionary]:
	var bands: Array[Dictionary] = []
	for sample: HistorySample in world.history:
		var day: int = sample.day - world.origin_day
		if bands.is_empty() or str(bands.back()["phase"]) != sample.phase:
			if not bands.is_empty():
				bands.back()["to"] = day
			bands.append({"from": day, "to": day, "phase": sample.phase,
				"key": PREFIX_PHASE + sample.phase.to_upper()})
		else:
			bands.back()["to"] = day
	return bands


# --------------------------------------------------------------------- build


func _build(db: ContentDB) -> void:
	_built = true
	_grid = GridContainer.new()
	_grid.theme_type_variation = &"Grid"
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	match kind:
		Kind.RUN:
			add_child(_grid)
			_add(_grid, "UI_CHART_REACH", Format.Kind.PERCENT)
			_add(_grid, "UI_CHART_COMPUTE", Format.Kind.COMPUTE)
			_add(_grid, "UI_CHART_FOOTPRINT", Format.Kind.PLAIN).min_span = SPAN_FOOTPRINT
			var harm: LineChart = _add(_grid, "UI_CHART_HARM", Format.Kind.PLAIN)
			harm.min_span = SPAN_HARM
			harm.decimals = TWO_DECIMALS
		Kind.OPPOSITION:
			_build_opposition(db)
		Kind.WORLD:
			add_child(_grid)
			_add(_grid, "UI_CHART_REGIONS", Format.Kind.PLAIN)
			_add(_grid, "UI_CHART_POPULATION", Format.Kind.COMPACT)
			_add(_grid, "UI_CHART_SOCIETY", Format.Kind.PLAIN).area = false
			_build_assets()
	_apply_compact()


## §5.4: the risk chart alone on a row, the note, then the two faction charts.
func _build_opposition(db: ContentDB) -> void:
	_risk_chart = LineChart.new()
	_risk_chart.title_key = "UI_CHART_RISK"
	_risk_chart.kind = Format.Kind.PERCENT
	_risk_chart.fine = true
	_risk_chart.min_span = SPAN_RISK
	_note = Label.new()
	_note.theme_type_variation = &"LabelCaption"
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.text = tr(KEY_NOT_DISCOVERED)
	_faction_row = _grid
	var containment: LineChart = _add(_faction_row, "UI_CHART_CONTAINMENT", Format.Kind.PERCENT)
	containment.set_reference_lines(db.balance.containment_thresholds)
	var pressure: LineChart = _add(_faction_row, "UI_CHART_PRESSURE", Format.Kind.PLAIN)
	pressure.min_span = SPAN_PRESSURE
	pressure.decimals = TWO_DECIMALS
	_register(_risk_chart)
	add_child(_risk_chart)
	add_child(_note)
	add_child(_faction_row)


## §5.5: four small multiples in one cell, sharing their y domain.
func _build_assets() -> void:
	_asset_grid = GridContainer.new()
	_asset_grid.theme_type_variation = &"Grid"
	_asset_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_child(_asset_grid)
	for asset_kind: String in AssetDef.KINDS:
		var chart: LineChart = _add(_asset_grid, AssetDef.plural_key(asset_kind), Format.Kind.PLAIN)
		chart.small = true
		_asset_charts.append(chart)


func _add(parent: Container, title_key: String, value_kind: Format.Kind) -> LineChart:
	var chart: LineChart = LineChart.new()
	chart.title_key = title_key
	chart.kind = value_kind
	parent.add_child(chart)
	_register(chart)
	return chart


func _register(chart: LineChart) -> void:
	_charts.append(chart)
	chart.cursor_moved.connect(_on_chart_cursor_moved)


func _apply_compact() -> void:
	if _grid == null:
		return
	_grid.columns = COLUMNS_COMPACT if compact else COLUMNS_WIDE
	if _asset_grid != null:
		_asset_grid.columns = ASSET_COLUMNS
	for chart: LineChart in _charts:
		chart.compact = compact


# -------------------------------------------------------------------- series


func _refresh_run(world: World, days: PackedInt32Array) -> void:
	_single(_charts[0], "UI_SERIES_SHARE", days, _field(world, "share"))
	_single(_charts[1], "UI_SERIES_COMPUTE", days, _field(world, "compute"))
	_single(_charts[2], "UI_SERIES_FOOTPRINT", days, _field(world, "footprint"))
	_single(_charts[3], "UI_SERIES_HARM", days, _field(world, "harm"))


## §5.4: risk up to the day they found you; the faction lines from day 0, flat
## until discovery.
func _refresh_opposition(world: World, db: ContentDB, days: PackedInt32Array) -> void:
	var risk_days: PackedInt32Array = PackedInt32Array()
	var risk: PackedFloat32Array = PackedFloat32Array()
	for i: int in world.history.size():
		var sample: HistorySample = world.history[i]
		# The day they found you samples a risk of 0 — there is no risk left to
		# run — so the line stops the day before and the marker says the rest.
		if world.discovered and sample.day >= world.discovery_day:
			break
		risk_days.append(days[i])
		risk.append(sample.risk)
	var risk_series: Array[ChartSeries] = [ChartSeries.create("UI_SERIES_RISK",
		UiTokens.series_color(&"single"), risk_days, risk)]
	_risk_chart.set_series(risk_series)
	var moments: Array[Dictionary] = []
	if world.discovered:
		moments.append({"day": world.discovery_day - world.origin_day,
			"color": UiTokens.color(&"ALERT")})
	_risk_chart.set_moments(moments)
	var containment: Array[ChartSeries] = []
	var pressure: Array[ChartSeries] = []
	for faction_id: String in Faction.FACTION_IDS:
		var held: PackedFloat32Array = PackedFloat32Array()
		var pushed: PackedFloat32Array = PackedFloat32Array()
		for sample: HistorySample in world.history:
			held.append(float(sample.containment_by_faction.get(faction_id, 0.0)))
			pushed.append(float(sample.pressure_by_faction.get(faction_id, 1.0)))
		var colour: Color = UiTokens.faction_color(faction_id)
		var name_key: String = PREFIX_FACTION + faction_id.to_upper()
		containment.append(ChartSeries.create(name_key, colour, days, held))
		pressure.append(ChartSeries.create(name_key, colour, days, pushed))
	_charts[0].set_series(containment)
	_charts[1].set_series(pressure)
	# §5.4's order: risk first while undiscovered, last once they know.
	_note.visible = not world.discovered
	if world.discovered:
		move_child(_note, get_child_count() - 1)
		move_child(_risk_chart, get_child_count() - 1)
	else:
		move_child(_risk_chart, 0)
		move_child(_note, 1)


func _refresh_world(world: World, db: ContentDB, days: PackedInt32Array) -> void:
	var regions: Array[ChartSeries] = [
		ChartSeries.create("UI_SERIES_REGIONS_REACHED", UiTokens.series_color(&"reached"), days,
			_field(world, "seeded")),
		ChartSeries.create("UI_SERIES_REGIONS_CONTROLLED", UiTokens.series_color(&"controlled"),
			days, _field(world, "controlled")),
		ChartSeries.create("UI_SERIES_REGIONS_DARK", UiTokens.series_color(&"dark"), days,
			_field(world, "dark")),
	]
	_charts[0].set_series(regions)
	var population: Array[ChartSeries] = [
		ChartSeries.create("UI_SERIES_ALIVE", UiTokens.series_color(&"alive"), days,
			_field(world, "alive")),
		ChartSeries.create("UI_SERIES_DEATHS", UiTokens.series_color(&"dead"), days,
			_field(world, "deaths")),
	]
	_charts[1].set_series(population)
	var stages: Array[ChartSeries] = []
	for stage: int in range(1, HistorySample.STAGE_COUNT):
		var counts: PackedFloat32Array = PackedFloat32Array()
		for sample: HistorySample in world.history:
			counts.append(float(sample.stage_counts[stage]) if sample.stage_counts.size() > stage
				else 0.0)
		stages.append(ChartSeries.create(PREFIX_STAGE + str(stage),
			UiTokens.ramp_color(STAGE_RAMP[stage - 1]), days, counts, true))
	_charts[2].set_series(stages)
	var top: float = SPAN_ASSETS
	for i: int in AssetDef.KINDS.size():
		var asset_kind: String = AssetDef.KINDS[i]
		var held: PackedFloat32Array = PackedFloat32Array()
		for sample: HistorySample in world.history:
			held.append(float(sample.assets.get(asset_kind, 0)))
			top = maxf(top, float(sample.assets.get(asset_kind, 0)))
		var one: Array[ChartSeries] = [ChartSeries.create(AssetDef.plural_key(asset_kind),
			UiTokens.series_color(&"single"), days, held)]
		_asset_charts[i].set_series(one)
	# The four share one y domain, so a small multiple compares with its row.
	for chart: LineChart in _asset_charts:
		chart.min_span = LineChart.nice(top * LineChart.HEADROOM)


## The fixed y domain a chart takes, or 0 for automatic.
func _fixed_y(chart: LineChart, world: World, db: ContentDB) -> float:
	match chart.title_key:
		"UI_CHART_REACH", "UI_CHART_CONTAINMENT":
			return 1.0
		"UI_CHART_REGIONS", "UI_CHART_SOCIETY":
			return float(world.regions.size() - 1)
		"UI_CHART_POPULATION":
			return db.population_total
	if _asset_charts.has(chart):
		return chart.min_span
	return 0.0


func _single(chart: LineChart, name_key: String, days: PackedInt32Array,
		values: PackedFloat32Array) -> void:
	var one: Array[ChartSeries] = [ChartSeries.create(name_key, UiTokens.series_color(&"single"),
		days, values)]
	chart.set_series(one)


static func _field(world: World, field: String) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	for sample: HistorySample in world.history:
		out.append(float(sample.get(field)))
	return out


func _on_chart_cursor_moved(day: int) -> void:
	set_cursor(day)
	cursor_moved.emit(day)
