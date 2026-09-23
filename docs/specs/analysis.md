# Analysis screen (D4.4): history, the run log, charts

**Status:** final for S4.8. Written 2026-09-23 on Fable.
**Read first (S4.8):** this file · `ui-foundation.md` §3 (tokens), §4.4–§4.7 (components) ·
`m3-screens.md` §4.1 (a slide panel with a header, the pattern), §7.4 (the results modal, which
gains a button) · `loop-mechanics.md` §3.3 and §14, `opposition.md` §3.5, §5.5, §8.2, §13 (the
queries and events the series and the log read) · **load the `dataviz` skill first** — §9 says
which of its rules this design already applied, so that nothing is re-decided.

UI.md §3 calls it "the graphs screen: population, penetration, containment over time, plus the
run log". This is that screen: a bottom sheet over the live map with four tabs of small charts, a
timeline of the run's beats, and a log of everything that happened, readable while the run runs
and after it ends.

---

## 1. Scope

**In:** per-day, bounded history in the core (§3) and a bounded run log in the core (§4), both
saved; the Analysis panel (§5) with its four tabs, the timeline strip, the table twin and the
results screen's *Review the run* button; the `LineChart` (§6) and `TimelineStrip` (§7)
components and `RunLogText` (§8); the dock button and the menu sheet entry go live and are
revealed from Covert (§5.1); tokens (§10), strings (§11, already in `strings.csv`), balance keys
(§12), tests (§15).

**Out:** export of any kind; comparisons across runs (D5.3's statistics); the spectator digest
(M6); charts anywhere else in the interface (the containment panel keeps its live rows); per-term
history of the faction pressure (§14); pictures.

---

## 2. Files

| Step | File | What |
| --- | --- | --- |
| S4.8 | `core/model/history_sample.gd` | the fields of §3.2; codec |
| S4.8 | `core/systems/history_system.gd` | per-day sampling, thinning (§3.1) |
| S4.8 | `core/model/run_log_entry.gd` (`RunLogEntry`) · `core/systems/run_log.gd` (`RunLog`, static) | §4 |
| S4.8 | `core/model/world.gd` · `core/save/world_serializer.gd` | `history_stride`, `run_log`, save v2 in place, the v1 migration rows (§3.4, §4.3) |
| S4.8 | `core/simulation.gd` | calls `RunLog.record` from `tick` and `apply` (§4.2) |
| S4.8 | `ui/components/chart_series.gd` (`ChartSeries`) · `line_chart.gd` + `.tscn` (`LineChart`) · `timeline_strip.gd` (`TimelineStrip`) · `run_log_text.gd` (`RunLogText`) | §6–§8 |
| S4.8 | `ui/panels/analysis_panel.gd` + `.tscn` (scene-specific, no `class_name`) · `ui/panels/analysis_tab.gd` (`AnalysisTab`, one per tab) | §5 |
| S4.8 | `ui/screens/results.gd` + `.tscn` · `ui/hud/dock.gd` · `ui/hud/menu_sheet.gd` · `ui/hud/hud.gd` · `game/session/session.gd` | the button, the reveal, the key (§5.1, §5.9) |
| S4.8 | `ui/theme/ui_tokens.gd` · `ThemeBuilder` (`ChartFrame` variation) · `ui/dev/gallery.gd` | §10, the gallery section |
| S4.8 | `data/balance.json` · `tests/fixtures/world_small/balance.json` · `data/SCHEMA.md` §5 | §12 |

---

## 3. History in the core (S4.8)

### 3.1 Sampling — every day, bounded

`HistorySystem` still runs last. A sample is taken on every tick after the origin exists where
`(day − origin_day) % history_stride == 0`, and on the tick that sets the outcome (as today; the
same-day guard stays). `World.history_stride: int` starts at `b.history.interval_days` (**1** from
S4.8 on) and is saved and hashed.

**Thinning.** After appending, if `history.size() > b.history.max_samples` (400): keep the
samples at even indices plus the last one, and `history_stride *= 2`. Offsets from the origin
day are then multiples of the new stride, so later samples align with the kept ones; the run's
first sample (offset 0) is always kept. A 1200-day run ends with stride 4 and ~300 samples; the
early Covert days, where the small numbers move, keep their daily resolution for the first 400
days of every run. The outcome sample is exempt from alignment (it is the last one, whatever its
day). `interval_days` is the *initial* stride only.

### 3.2 `HistorySample`

```gdscript
class_name HistorySample
var day: int
var compute: float
var compute_earned: float
var seeded: int
var share: float                       # infected_share(db)
var alive: float
var deaths: float
var containment: float                 # max over factions (unchanged; the results screen reads it)
var footprint: float
var phase: String
# D4.4
var containment_by_faction: Dictionary[String, float]   # FACTION_IDS order
var pressure_by_faction: Dictionary[String, float]      # containment_breakdown(f)["pressure"] (1 + terms_f)
var risk: float                        # ContainmentSystem.discovery_risk(world, db)["total"]; 0.0 once discovered
var harm: float                        # max over regions not dark of stat("harm", r) — S3.P item 2's query
var controlled: int                    # regions with control >= b.control.complete
var dark: int                          # regions with dark
var stage_counts: PackedInt32Array     # 6 entries: regions not dark per society stage 0…5
var assets: Dictionary[String, int]    # kind → the agent's total; every kind present, 0 included
var starving_days: int
```

`REAL_FIELDS` gains `risk`, `harm`; `WHOLE_FIELDS` `controlled`, `dark`, `starving_days`; the two
float dictionaries are written with bit values, `assets` and `stage_counts` plain. `from_dict`
requires every field (a v1 file reaches it migrated, §3.4) and refuses an unknown faction id or a
`stage_counts` of another length.

### 3.3 Where the values come from

All pure, all existing by S4.8: `containment_breakdown(f)` (opposition §5.5) for the pressure,
`discovery_risk` (m3-screens §10.5), `society_stage(i)` (opposition §8.2), `Region.assets`,
`starving_days`. `World` gains `controlled_count() -> int` and `dark_count() -> int` (the second
already exists as a loop in the results screen — move it into the model). None touches the RNG.
Sampling per day calls `containment_breakdown` four times a tick; it is the same arithmetic the
tick just did, and G4's 500-seed batches will say if it shows in the wall clock — the spec's
expectation is that it does not.

### 3.4 Save

v2 in place (loop-mechanics §13's rule: not shipped): the world block gains `"history_stride"`
and `"run_log"` (§4.3); each history entry the fields of §3.2. **v1 → v2** fills
`history_stride: 7` (v1's interval — the old samples are seven days apart and stay aligned),
`run_log: []`, and per old sample: `containment_by_faction` = every faction id → the sample's
`containment` (the unified track's value, as the faction migration does), `pressure_by_faction`
= 1.0 each, `risk` 0, `harm` 0, `controlled` 0, `dark` 0, `stage_counts` six zeros, `assets`
every kind 0, `starving_days` 0. A v2 save from an S4.1–S4.7 build lacks the fields and is
refused as `save_corrupt` (a development save; opposition §3.4's rule).

---

## 4. The run log in the core (S4.8)

The outbox is per tick and a loaded save has no outbox, so the log the screen shows must live in
the world and be saved with it.

### 4.1 `RunLogEntry` and `RunLog`

```gdscript
class_name RunLogEntry
var day: int
var type: String                       # SimEvent type
var data: Dictionary                   # the kept keys only (§4.2), String / int / float / bool values
func to_dict() -> Dictionary           # floats as bits
static func from_dict(d: Dictionary) -> RunLogEntry

class_name RunLog                      # core/systems/run_log.gd, static
const KEPT: Dictionary[String, Array]  # event type → the data keys kept (§4.2)
static func record(world: World, db: ContentDB, events: Array[SimEvent]) -> void
# for each event whose type is in KEPT, in order: append RunLogEntry {day: event.day, type, data: the kept keys
# that are present}; then while run_log.size() > db.balance.history_log_max: remove the oldest
```

`World.run_log: Array[RunLogEntry]`, saved as `"run_log": [{"day", "type", "data": {…}}]`, in
`state_hash`. `check_invariants`: entries in non-decreasing `day`; no more than `log_max`.

### 4.2 What is kept, and where `record` is called

`Simulation.tick` calls `RunLog.record(world, db, outbox)` after the systems and before
`HeadlineSystem` (headline events are never logged); `Simulation.apply` calls it with the
result's events after a successful command. Kept types and keys — the whole table, so that the
log's size is bounded per entry too:

| Type | Kept keys | Class |
| --- | --- | --- |
| `origin_chosen` | `region` | yours |
| `node_purchased` | `node` | yours |
| `region_controlled` | `region` | yours |
| `region_depopulated` | `region` | theirs |
| `discovered` | `cause` | theirs |
| `containment_threshold` | `faction`, `threshold` | theirs |
| `phase_changed` | `from`, `to` | theirs |
| `outcome_reached` | `outcome` | theirs |
| `containment_rolled_back` | `faction` | yours |
| `harm_burst` | `deaths` | yours |
| `dormancy_changed` | `region`, `dormant` | yours |
| `asset_deployed` | `region`, `kind`, `count` | yours |
| `asset_lost` | `region`, `kind`, `count` | theirs |
| `ability_used` | `ability`, `region`, `level` | yours |
| `status_started` — **only** when `refreshed == false` and the def's `origin == world` | `status`, `region`, `source` | theirs |
| `event_opened` | `def`, `kind`, `region`, `faction` | theirs |
| `event_answered` | `def`, `option`, `region` | yours |
| `event_expired` | `def`, `option`, `region` | yours |
| `counter_move_prepared` | `faction`, `event` | theirs |
| `counter_move_cancelled` | `faction` | theirs |
| `funding_reset` | — | yours |
| `threat_leader_changed` | `to` | theirs |
| `society_stage_changed` — **only** when `to > from` and `to` is 3 or 5 | `region`, `to` | theirs |
| `region_wiped` | `region`, `from`, `to` | theirs |

Not kept: `region_seeded` (the map shows it; the Regions chart counts it), anomalies, `compute_granted`,
`pulse_*`, `flag_*`, `status_ended`, `penetration_changed`, `control_changed`,
`containment_added`, `milestone_reached`, `ability_unlocked` (the purchase is logged),
`counter_move_dropped`, `event_dropped`, `headline`. The two filters (`status_started`,
`society_stage_changed`) are in `RunLog`, not in the table — `KEPT` says which keys, a private
`_wanted(event, db)` says whether. The *Class* column is `RunLogText`'s (§8), listed here so the
core's table and the interface's agree; the core does not store it.

### 4.3 Size

`b.history.log_max` **300**. A greedy run logs ~25 purchases, ~30 ability uses, ~40 event lines,
~20 thresholds and moves — well under; a long Open phase with many counter-moves loses its
earliest purchases first, which is the right end to lose.

---

## 5. The panel

### 5.1 Opening, closing, reveal

`ui/panels/analysis_panel.tscn` is a `SlidePanel` **BOTTOM** on `PanelLayer`, full width, height
`ANALYSIS_HEIGHT_SHARE` **0.55** of the viewport (the map's upper half stays visible and live —
the point of a sheet rather than a modal); in compact **0.85** (`ANALYSIS_HEIGHT_SHARE_COMPACT`).
Opened by `UI_DOCK_ANALYSIS`, the key **`G`** (session `_input`, like `T` and `C`), the menu
sheet's entry, and the results screen's *Review the run* (§5.9); closed by its CLOSE button,
`Escape`, `G`, or opening the region panel or the containment panel — **the three panels never
overlap: opening one closes the others** (m3-screens §4.1's rule, now three-way). Not a modal:
the game keeps running and the charts extend on every `tick_advanced` while the panel is open
(nothing is computed while it is closed).

**Reveal (m3-screens §6.1 amended):** the dock button and the sheet entry are **shown from
Covert** — hidden in Boxed, where there is one region and nothing to plot — and enabled from
S4.8 on (`UI_DOCK_NOT_YET` goes). `Reveal` handles the arrival as for every other block.

### 5.2 Header and tabs

`ConsolePanel` → `VBox` `SPACE_3` inside `GutterTight`:

1. **Header** `HBox` `RowSnug`: `LabelDisplay` `UI_ANALYSIS_TITLE` · the **tab row** — four
   `ConsoleButton` toggles (`compact` flag, the tech tree's §3.2 pattern, `FlowSnug` so they wrap
   at 400 px): `UI_ANALYSIS_TAB_RUN`, `_OPPOSITION`, `_WORLD`, `_LOG` · spacer · the **table
   toggle** `ConsoleButton` `UI_ANALYSIS_TABLE` / `UI_ANALYSIS_CHARTS` (hidden on the Log tab) ·
   `ConsoleButton` `UI_ANALYSIS_BACK_TO_RESULTS` (visible only in review, §5.9) · `IconButton`
   CLOSE.
2. **`TimelineStrip`** (§7) — on the three chart tabs, not on the Log.
3. **Body**: a `ScrollContainer` (vertical) holding the current tab's content: a `GridContainer`
   of charts with `columns = 2` at ≥ 1100 px and `1` below (`AnalysisTab` sets it on resize), or
   the table twin (§5.8), or the log list (§5.6).

The selected tab, the table toggle and the log filter are remembered for the session (panel
fields, not settings). Focus on open: the selected tab's button; Tab order header → strip →
charts (each chart is focusable, §6.5) → close.

**Series builder.** `AnalysisTab.build(world, db)` turns `world.history` into `ChartSeries`
(§6.1) for its charts, once per `tick_advanced` while open and once on open; the x domain of
every chart on a tab is the same: `[0, max(last sample offset, MIN_SPAN_DAYS 30)]` in days
since origin. Fewer than two samples: every chart shows `UI_ANALYSIS_EMPTY` (§6.4).

### 5.3 Tab *Run* — `UI_ANALYSIS_TAB_RUN`

Four single-series charts (2 × 2 on a desktop), each in `ACCENT` with the area wash:

| Chart (`title_key`) | Series (`key`) | Source | y | Format |
| --- | --- | --- | --- | --- |
| `UI_CHART_REACH` | `UI_SERIES_SHARE` | `share` | fixed 0…1 | `PERCENT` |
| `UI_CHART_COMPUTE` | `UI_SERIES_COMPUTE` | `compute` | auto | `COMPUTE` |
| `UI_CHART_FOOTPRINT` | `UI_SERIES_FOOTPRINT` | `footprint` | auto, ≥ 10 | `PLAIN` |
| `UI_CHART_HARM` | `UI_SERIES_HARM` | `harm` | auto, ≥ 1 | `PLAIN`, two decimals |

### 5.4 Tab *Opposition* — `UI_ANALYSIS_TAB_OPPOSITION`

| Chart | Series | Source | y | Format · extras |
| --- | --- | --- | --- | --- |
| `UI_CHART_RISK` | `UI_SERIES_RISK` | `risk`, **samples up to `discovery_day` only** (all of them while undiscovered) | auto, ≥ 0.01 | `percent_fine`; single series, `ACCENT` |
| `UI_CHART_CONTAINMENT` | one per faction, `FACTION_<ID>` | `containment_by_faction[f]` | fixed 0…1 | `PERCENT`; reference lines at `b.containment.thresholds`; the faction colours |
| `UI_CHART_PRESSURE` | one per faction, `FACTION_<ID>` | `pressure_by_faction[f]` | auto, ≥ 2 | `PLAIN`, two decimals; the faction colours |

**Order and the undiscovered state.** While `not discovered`: the risk chart first, full width
(`columns` span 2 — a `GridContainer` cannot span, so the tab's grid is a `VBox` of rows here:
the risk chart alone, then a 2-column row), and a `LabelCaption` `UI_ANALYSIS_NOT_DISCOVERED`
under the tab's title where the other two charts would sit *empty*; the two faction charts are
shown with their series flat at 0 (the panel never hides what will come — the containment
panel's rule). After discovery: containment, pressure, then the risk chart frozen at the day
they found you, with the discovery marker (§6.3) at its right end.

### 5.5 Tab *World* — `UI_ANALYSIS_TAB_WORLD`

| Chart | Series | Source | y | Format · extras |
| --- | --- | --- | --- | --- |
| `UI_CHART_REGIONS` | `UI_SERIES_REGIONS_REACHED` · `_CONTROLLED` · `_DARK` | `seeded` · `controlled` · `dark` | fixed 0…`regions.size() − 1` | `PLAIN`; `STAT_PENETRATION` · `ACCENT` · `MAP_DEATH` |
| `UI_CHART_POPULATION` | `UI_SERIES_ALIVE` · `UI_SERIES_DEATHS` | `alive` · `deaths` | fixed 0…`db.population_total` | `COMPACT`; alive `TEXT_1` (context), dead `MAP_DEATH` (the emphasis) |
| `UI_CHART_SOCIETY` | `SOCIETY_STAGE_1` … `_5`, **stacked** | `stage_counts[1..5]` | fixed 0…`regions.size() − 1` | `PLAIN`; the magnitude ramp at 0 · 0.25 · 0.5 · 0.75 · 1 — **stage 5 is the ramp's top**, stage 1 its bottom: more disorder, brighter; legend caption `UI_ANALYSIS_LEGEND_STACK` |
| `UI_CHART_ASSETS` | **four small multiples**, one chart per kind titled `ASSET_<KIND>_PLURAL` | `assets[kind]` | auto, ≥ 4, **shared across the four** | `PLAIN`; `ACCENT` each |

The assets row is its own `GridContainer` of four (2 × 2 in compact) inside the tab's grid cell,
each chart at half the standard height (`CHART_MIN_HEIGHT_SMALL`); a kind that was never held is
still drawn (a flat zero), so the row's shape never changes.

### 5.6 Tab *Log* — `UI_ANALYSIS_TAB_LOG`

1. **Filter row** (one row, above everything it scopes): three `ConsoleButton` toggles
   `UI_LOG_FILTER_ALL` · `_YOURS` · `_THEIRS` (the *Class* of §4.2 via `RunLogText.is_yours`).
2. **The list**: a `VBox` in the body's `ScrollContainer`, oldest first, one row per entry that
   passes the filter: `HBox` `RowSnug` — `LabelCaption` day (`UI_ANALYSIS_CURSOR_DAY`'s number as
   `PLAIN`, `TEXT_2`, min width 56, right-aligned) · a 16 px glyph cell (`RunLogText.marker`, §8)
   · `Label` `TYPE_BODY` `TEXT_0`, autowrap, the entry's text. A row whose entry carries a
   `region` is a `ConsoleButton` (`list_row`) instead of a plain row: pressing it emits
   `EventBus.region_selected(index)` — the session focuses the region and opens its panel, which
   closes this sheet (§5.1). Rows are ≥ 28 px; the button rows `HIT_MIN`.
3. Empty (after the filter): `UI_LOG_EMPTY` as a `LabelCaption`.

Scrolled to the end on open; a new entry that lands while the scroll is at the end keeps it at
the end (a reader who scrolled up is not pulled back). The list is rebuilt from `world.run_log`
when its size or first entry changes (the cap rotates the oldest out), appended otherwise.

### 5.7 The timeline strip

§7. Below the header on the chart tabs; its x mapping is the tab's domain, so a mark sits over
the same day on every chart beneath it. Hovering a mark shows its entries; clicking sets the
cursor of every chart on the tab to that day.

### 5.8 The table twin

`UI_ANALYSIS_TABLE` swaps the tab's charts for one `Tree` (Godot's, themed: `TYPE_DATA` cells,
`LabelCaps` header): first column `UI_ANALYSIS_TABLE_DAY`, then one column per series of the tab
in chart order (header = the series name, prefixed by the chart title where two charts share a
name — the four faction columns of Containment and Pressure read *Containment · AI Labs*), one row
per day of `LineChart.table_days(domain)` (§6.6): `TABLE_ROWS` 16 evenly spaced sample days plus
the last sample; values formatted as their chart formats them. Every value the charts show is
reachable here without a pointer — the accessibility twin the `dataviz` skill requires, and what
a screen reader gets.

### 5.9 Results review

`ui/screens/results.tscn` §7.4 item 6 gains a third button before the two: `ConsoleButton`
`UI_ANALYSIS_REVIEW` → `ModalHost.close()` and `analysis_panel.open_review()`. `open_review`
opens the sheet with `_review = true`: the header shows `UI_ANALYSIS_BACK_TO_RESULTS`, and CLOSE
and `Escape` behave like it — `ModalHost.open(results)` again (the results modal keeps its
content; `show_result` is not called twice) and `_review = false`. The `"results"` hold stays
throughout, so the speed buttons stay dead and the map stays as it ended. A results modal
reached this way after `go_to_title` is impossible (the session is freed).

### 5.10 Compact

The sheet at 0.85; header wraps (`FlowSnug`); one column of charts at `CHART_MIN_HEIGHT_COMPACT`
160; the assets row 2 × 2; the strip stays; the table's `Tree` scrolls horizontally inside the
body (a table is allowed to be wider than the screen). At 400 × 860 every chart label must fit —
S4.9's German screenshot set includes this panel on all four tabs.

---

## 6. `LineChart` (`ui/components/line_chart.gd` + `.tscn`, `Control`, `class_name LineChart`)

### 6.1 API

```gdscript
class_name ChartSeries               # RefCounted, ui/components/chart_series.gd
var key: String                      # the name's string key; tr() by the chart
var color: Color
var days: PackedInt32Array           # offsets from the origin day, ascending
var values: PackedFloat32Array       # same length
var stacked: bool = false            # drawn as an area on top of the previous stacked series

class_name LineChart
signal cursor_moved(day: int)        # -1 = none
@export var title_key: String
var kind: Format.Kind = Format.Kind.PLAIN
var decimals: int = 0                # PLAIN only
var fine: bool = false               # PERCENT → percent_fine
var area: bool = true                # single series: the 10 % wash under the line
var small: bool = false              # CHART_MIN_HEIGHT_SMALL, no legend row, title only
func set_series(series: Array[ChartSeries]) -> void
func set_domain(day_max: int, y_max: float) -> void       # y_max <= 0 → auto (§6.2); day_min is 0
func set_bands(bands: Array[Dictionary]) -> void          # [{"from": int, "to": int, "key": String}] — the phases
func set_moments(moments: Array[Dictionary]) -> void      # [{"day": int, "color": Color}] — the discovery day
func set_reference_lines(values: Array[float]) -> void
func set_cursor(day: int) -> void                          # snaps to the nearest sample; -1 clears
func cursor_day() -> int
func table_days(day_max: int) -> PackedInt32Array          # §6.6
func values_at(day: int) -> PackedFloat32Array             # one per series, NAN where the series has no sample
```

`set_*` calls `queue_redraw`; nothing tweens (a chart that extends by one sample a day does not
need motion, and reduced motion changes nothing here).

### 6.2 Geometry and scales

Margins inside the control: title row `CHART_TITLE_H` 24 (the title `LabelCaps`-style, drawn:
`TYPE_LABEL`, `TEXT_1`, tracking `TRACKING_LABEL`) · legend row `CHART_LEGEND_H` 20 (only with
≥ 2 series) · left axis gutter `CHART_AXIS_W` 56 · right label gutter `CHART_LABEL_W` 80 · bottom
axis band `CHART_AXIS_H` 20. The plot is the rest; min size `CHART_MIN_HEIGHT` 200 (compact 160,
small 120), expands horizontally.

x: `day → plot.x + day / day_max × plot.w`. y: `value → plot.bottom − value / y_max × plot.h`.
**Auto `y_max`**: `nice(max value × 1.1)` with `nice(v)` the smallest of `{1, 2, 5} × 10^k ≥ v`,
floored at the chart's minimum span (the tables above). Fixed domains are given by the tab.

**Ticks.** y: four gridlines at `y_max × {0.25, 0.5, 0.75, 1}`, hairline `LINE_0`, solid, with
labels in `TYPE_CAPTION` `TEXT_2` right-aligned in the gutter, formatted by `kind` (the top one
carries the unit: `%`, Compute, …, through `Format`). x: ticks at the smallest of `{10, 25, 50,
100, 250, 500, 1000}` days that leaves ≥ `CHART_TICK_MIN_PX` 80 between ticks, labels `TYPE_CAPTION`
`TEXT_2` under the axis, the axis itself a hairline `LINE_1`; the axis caption `UI_ANALYSIS_X_DAYS`
sits right-aligned under the last tick.

### 6.3 Marks

- **Line**: 2 px (`CHART_LINE_W`), antialiased `draw_polyline`, the series colour.
- **Area** (single series, `area`): the polygon under the line in the colour at `CHART_AREA_ALPHA`
  0.10. **Stacked** series: cumulative areas at `CHART_STACK_ALPHA` 0.6 with a 2 px `BG_2` line on
  every boundary (the surface gap), no outline.
- **End label**: the last value of each line, formatted, `TYPE_CAPTION` `TEXT_1`, in the right
  gutter at the line's end y, with a 12 px line key in the series colour before it. Collision:
  labels are placed top to bottom; one whose rect intersects an already placed one is **dropped**
  (the legend and the tooltip carry it) — never nudged.
- **Legend** (≥ 2 series): a row of 16 × 2 px line keys + names in `TYPE_CAPTION` `TEXT_1`, in
  series order, wrapping if it must.
- **Bands**: each phase span fills the plot with `BG_3` for the odd bands (the second, fourth),
  nothing for the even ones, a hairline `LINE_1` at each boundary, and the phase name (`UI_PHASE_*`,
  `TYPE_LABEL` `TEXT_2`) at the band's top-left inside the plot — dropped when the band is
  narrower than its label.
- **Moments**: a vertical hairline in the given colour at 60 % alpha (the discovery day in `ALERT`
  — a past moment, drawn once).
- **Reference lines**: hairline `LINE_1` at each value, no label (the y ticks carry the numbers).
- **Cursor**: a vertical hairline `LINE_2` at the cursor day; on every series a marker
  r `CHART_MARK_R` 4 with a 2 px `BG_2` ring; the **tooltip** (a `MapTooltip` panel the chart
  owns): `UI_ANALYSIS_CURSOR_DAY` in `TYPE_LABEL`, then one row per series — the value
  (`TYPE_DATA`, `TEXT_0`) then the name (`TYPE_CAPTION`, `TEXT_1`) with a 12 px line key — placed
  right of the cursor and flipped left when it would leave the control, clamped vertically. Text
  wears text tokens; only the keys wear the series colour.

### 6.4 Empty state

Fewer than two points in every series: the frame, the title and `UI_ANALYSIS_EMPTY` centred in
the plot in `TYPE_CAPTION` `TEXT_2`; no axes.

### 6.5 Input and accessibility

`focus_mode = FOCUS_ALL`; the frame is the `ChartFrame` variation (`BG_2` fill, `LINE_1` border,
`RADIUS_M`, the `ACCENT` focus border like a button). Pointer motion over the plot sets the
cursor to the nearest sample day (binary search; the hit target is the whole plot, never the 2 px
line); the cursor **stays** when the pointer leaves — a keyboard reader keeps what it set.
`←`/`→` step one sample, `Home`/`End` first/last; each emits `cursor_moved`, and the tab mirrors it
onto its other charts and the strip. Touch: drag. `accessibility_name = tr(title_key)`;
`accessibility_description` = the cursor readout as a sentence (*Day 212: Containment, AI Labs
41 %, Governments 58 %, …*), refreshed on every cursor move.

### 6.6 `table_days`

`TABLE_ROWS` 16 days evenly spaced over `[0, day_max]` snapped to the nearest sample day, plus the
last sample day, de-duplicated, ascending. `values_at(day)` reads the sample at that day (NAN for a
series that ends earlier — the risk chart after discovery).

---

## 7. `TimelineStrip` (`ui/components/timeline_strip.gd`, `Control`, `class_name TimelineStrip`)

Height `STRIP_H` 28, the plot's x gutters (`CHART_AXIS_W` left, `CHART_LABEL_W` right) so that
marks align with the charts below. API: `set_domain(day_max)`, `set_marks(marks: Array[Dictionary])`
(`[{"day": int, "glyph": String, "color": Color, "priority": int, "text": String}]`),
`set_bands(bands)` (drawn as boundary hairlines only), `signal day_pressed(day: int)`.

Marks are bucketed into `STRIP_SLOT` 12 px slots; a slot draws its highest-`priority` mark's
glyph (16 px, `Glyphs`) in that mark's colour and, when the slot holds more than one, a 4 px dot
under the glyph in `TEXT_2`. Hover (and focus, `←`/`→` moving slot to slot) shows a `MapTooltip`
with `UI_ANALYSIS_STRIP_TIP` (`{day}` the slot's first day, `{entries}` every mark's text in the
slot joined by ` · `); click / `Enter` emits `day_pressed` with the top mark's day. Marks come from
`RunLogText.marker` (§8) over `world.run_log`: priorities `outcome_reached` 5 · `discovered` 4 ·
counter-move `event_opened` 3 · chain `event_opened` 2 · opening `event_opened` 1; nothing else is
a mark. Hit targets are the slot's full height and `HIT_MIN` wide on touch.

---

## 8. `RunLogText` (`ui/components/run_log_text.gd`, static, `class_name RunLogText`)

```gdscript
static func text(entry: RunLogEntry, db: ContentDB) -> String     # tr()'d, placeholders filled
static func is_yours(entry: RunLogEntry) -> bool                   # the Class column of §4.2
static func marker(entry: RunLogEntry) -> Dictionary               # {} or {"glyph", "color", "priority"}
static func region_index(entry: RunLogEntry, db: ContentDB) -> int # 0 when the entry has none
const KEYS: Array[String]                                          # every UI_LOG_* key it can emit (the strings test reads it)
```

Text per type: `UI_LOG_<TYPE upper>` with the arguments named in §11 — `{region}` `REGION_<ID>`,
`{node}` `TECH_<ID>_NAME`, `{faction}` `FACTION_<ID>`, `{percent}` `Format.percent` of `threshold`
/ of `to ÷ from` for `region_wiped`, `{phase}` `UI_PHASE_*`, `{outcome}` `UI_OUTCOME_*`,
`{cause}` `UI_DISCOVERY_CAUSE_*`, `{deaths}` `COMPACT`, `{kind}` the asset plural, `{ability}`
`ABILITY_<ID>_NAME`, `{status}` `STATUS_<ID>_NAME`, `{title}` `EVENT_<DEF>_TITLE`, `{option}`
`EVENT_<DEF>_OPT_<OPTION>`, `{move}` `EVENT_<ID>_TITLE`, `{stage}` `SOCIETY_STAGE_<n>`. The
variants: `dormancy_changed` → `UI_LOG_DORMANCY_ON` / `_OFF`; `ability_used` with `region == ""` →
`_GLOBAL`; `status_started` with `region == ""` → `_GLOBAL`; `event_opened` with `region == ""` →
`_GLOBAL`. An id the content no longer has (a save from an older content set) renders the id
itself, never an empty string.

Row glyphs (16 px): the marker's glyph and colour when `marker` is non-empty; otherwise `›` in
`ACCENT` for *yours*, `·` in `TEXT_1` for *theirs*. Marker glyphs: `event_opened` chain `»`
`TEXT_0`, opening `◇` `ACCENT`, counter-move `!` in `UiTokens.faction_color(faction)`;
`discovered` `!` `ALERT`; `outcome_reached` `■` `TEXT_0`. (`Glyphs` gains `EVENT_CHAIN`,
`EVENT_OPENING`, `EVENT_COUNTER`, `MOMENT`, `OUTCOME`, `LOG_YOURS`, `LOG_THEIRS` if S4.3/S4.4 have
not drawn them yet — 2 px strokes on the 24 px grid, as everything else.)

---

## 9. Series, colours, and the `dataviz` rules applied

**Colour assignment is fixed per entity** (`UiTokens.SERIES`, §10) and never by position:

| Entity | Colour |
| --- | --- |
| Any single-series chart | `ACCENT` |
| Regions: reached · controlled · dark | `STAT_PENETRATION` · `ACCENT` · `MAP_DEATH` |
| Population: alive · dead | `TEXT_1` · `MAP_DEATH` |
| Factions | `FACTION_AI_LABS` `CAT_SKY` · `FACTION_GOVERNMENTS` `CAT_ORANGE` · `FACTION_RESEARCHERS` `CAT_GREEN` · `FACTION_PUBLIC` `CAT_PINK` |
| Society stages 1…5 | the magnitude ramp at 0 · 0.25 · 0.5 · 0.75 · 1 (`ThemeBuilder`'s gradient) |

Validated with the skill's script on the panel surface `#101820`: the Regions triple passes every
separation check (worst adjacent ΔE 18.9 deutan, 23.0 normal); the four faction hues pass with one
warning (pink ↔ green ΔE 7.6 deutan — inside the 6–8 band that is legal **only with secondary
encoding**, which the legend, the end labels and the faction glyphs on the containment panel
provide); Population's grey is the deliberate de-emphasis of an emphasis chart, not a category.
The lightness-band and chroma checks of the script assume its own reference palette; the
project's tokens are brighter by design (VISUALS §2) and those two rows are not a finding.

Rules from the skill this design applies, so S4.8 does not re-derive them: one axis per chart,
never two scales (Footprint and Harm are two charts; Compute held and Compute earned are not both
plotted); the form by the job (trend → line, part-to-whole over time → stacked area, one number
→ the HUD, not a chart); sequential for the ordered stages, categorical for the factions, emphasis
for population; thin marks, hairline solid grid, 10 % wash, 2 px surface gap and ring; a legend for
≥ 2 series and none for one; end labels selectively (the last value only, dropped on collision);
text in text tokens; a crosshair tooltip listing every series at the cursor; a hit target larger
than the mark; a table twin; no per-chart filters (the Log's filter row scopes the whole tab);
no dashed lines; no number on every point; small multiples instead of a fourth categorical hue for
the assets.

---

## 10. Tokens (`UiTokens`, `ThemeBuilder`)

`ANALYSIS_HEIGHT_SHARE` 0.55 · `ANALYSIS_HEIGHT_SHARE_COMPACT` 0.85 · `CHART_MIN_HEIGHT` 200 ·
`CHART_MIN_HEIGHT_COMPACT` 160 · `CHART_MIN_HEIGHT_SMALL` 120 · `CHART_TITLE_H` 24 ·
`CHART_LEGEND_H` 20 · `CHART_AXIS_W` 56 · `CHART_LABEL_W` 80 · `CHART_AXIS_H` 20 · `CHART_LINE_W`
2.0 · `CHART_MARK_R` 4.0 · `CHART_RING_W` 2.0 · `CHART_AREA_ALPHA` 0.10 · `CHART_STACK_ALPHA` 0.6 ·
`CHART_TICK_MIN_PX` 80 · `CHART_X_TICKS` `[10, 25, 50, 100, 250, 500, 1000]` · `MIN_SPAN_DAYS` 30 ·
`TABLE_ROWS` 16 · `STRIP_H` 28 · `STRIP_SLOT` 12 · `LOG_ROW_MIN_H` 28 · `LOG_DAY_W` 56 ·
`SERIES: Dictionary[StringName, Color]` (§9's table by entity name: `&"reached"`, `&"controlled"`,
`&"dark"`, `&"alive"`, `&"dead"`, `&"single"`). Theme: the `ChartFrame` (`PanelContainer`)
variation — `BG_2`, `LINE_1` border, `RADIUS_M`, focus border `ACCENT` × `BORDER_FOCUS`. Run
`tools/build_theme.gd` and commit the theme.

---

## 11. Strings (`data/loc/strings.csv`; **in the table since D4.4**)

`UI_ANALYSIS_TITLE` · `_TAB_RUN` · `_TAB_OPPOSITION` · `_TAB_WORLD` · `_TAB_LOG` · `_TABLE` ·
`_CHARTS` · `_X_DAYS` · `_TABLE_DAY` · `_EMPTY` · `_NOT_DISCOVERED` · `_CURSOR_DAY` (`{day}`) ·
`_BACK_TO_RESULTS` · `_REVIEW` · `_STRIP_TIP` (`{day}`, `{entries}`) · `_LEGEND_STACK`;
`UI_CHART_REACH` · `_COMPUTE` · `_FOOTPRINT` · `_HARM` · `_RISK` · `_CONTAINMENT` · `_PRESSURE` ·
`_REGIONS` · `_POPULATION` · `_SOCIETY` · `_ASSETS`; `UI_SERIES_SHARE` · `_COMPUTE` · `_FOOTPRINT`
· `_HARM` · `_RISK` · `_CONTAINMENT` · `_PRESSURE` · `_REGIONS_REACHED` · `_REGIONS_CONTROLLED` ·
`_REGIONS_DARK` · `_ALIVE` · `_DEATHS`; `UI_LOG_FILTER_ALL` · `_YOURS` · `_THEIRS` · `UI_LOG_EMPTY`;
and one `UI_LOG_<TYPE>` per row of §4.2 with the variants `UI_LOG_DORMANCY_ON` / `_OFF`,
`UI_LOG_ABILITY_USED_GLOBAL`, `UI_LOG_STATUS_WORLD` / `_GLOBAL`, `UI_LOG_EVENT_OPENED_GLOBAL` —
arguments as §8 names them. Existing keys reused: `UI_PHASE_*`, `UI_OUTCOME_*`, `FACTION_*`,
`SOCIETY_STAGE_*`, `ASSET_*_PLURAL`, `UI_DISCOVERY_CAUSE_*`, `UI_DOCK_ANALYSIS`, `UI_COMMON_CLOSE`.
73 rows, both languages, written for each.

---

## 12. Balance and schema

`balance.history`: `interval_days` **7 → 1**; new `max_samples` **400** (int ≥ 2), `log_max`
**300** (int ≥ 1). `BalanceDef.history_max_samples`, `history_log_max`; SCHEMA §5 rows; the fixture's
frozen `balance.json` gains the two keys (the validator requires them) and keeps `interval_days`
as it is — the unit tests that count samples say which value they assume.

---

## 13. Interface wiring

No new `EventBus` signal: the panel listens to `tick_advanced` and `run_started` (rebuild while
open), `run_ended` (one last rebuild, so the outcome sample and the outcome line are shown), and
`locale_changed` (re-`tr` every title, legend and log row — the log list is rebuilt).
`reduced_motion_changed` needs nothing here; said so that nobody looks for it. `hud.gd`'s reveal table gains the Analysis
row's new schedule; `dock.gd` drops the *not yet* branch; `session.gd` gains `G` and the
three-way exclusion of the panels.

---

## 14. Decisions and deviations

1. **A bottom sheet, not a modal** — UI.md §3 makes the tech tree the only screen that covers the
   map; charts want width, not height, and a live map above a live chart is the screen's idea.
2. **Per-day history, bounded by thinning** (§3.1), replacing the 7-day interval: the plan's
   "bounded per-day history in core", done so that a save stays ~400 samples whatever the run's
   length and early days keep their resolution.
3. **The run log lives in the core** (§4), fed from the outbox and the command results, capped at
   300 — the only way a loaded run has a log. Its entries hold ids, never text.
4. **Per-faction pressure is sampled; the terms are not** (opposition §18 suggested "the two
   largest terms"): a series per term per faction is ~32 series and the containment panel shows
   the live terms already. The log records `threat_leader_changed`, which is what a term chart
   would have been read for.
5. **The dock button is revealed in Covert, not Open** (m3-screens §6.1 amended): the M3 table
   put it in Open only because the screen did not exist; a Covert player watching the risk line
   creep is the screen's first use.
6. **The results screen reaches the Analysis** through *Review the run* (§5.9) — the summary
   grid stays the seed of the log, and the full picture is one button away.
7. **Log rows with a region are buttons** that select the region — the log doubles as a map
   index; nothing else in the panel is interactive beyond the cursor.
8. **`Tree` for the table twin**, not a `GridContainer` of labels: it is the one Godot control a
   screen reader walks as a table.

---

## 15. Tests (S4.8)

**Unit**
- `tests/unit/test_history_system.gd` (new): with `interval_days 1` a run samples every day from
  the origin; at `max_samples + 1` the array thins to even offsets plus the last, `history_stride`
  doubles, the next sample lands on the stride; a second thinning gives stride 4; the outcome day is
  always the last sample; the new fields at a hand-built state (four faction values, `risk` equal
  to the query, `stage_counts` summing to the regions not dark, `assets` with every kind, `harm`
  the regional maximum); `risk` is 0 after discovery.
- `test_history_sample.gd` (new): codec round trip of every field; a dictionary missing a D4.4
  field is refused; an unknown faction id is refused.
- `test_run_log.gd` (new): every type of §4.2 is recorded with exactly its kept keys from a tick
  outbox and from a command result; the two filtered types obey their filter; an unlisted type is
  not recorded; the cap drops the oldest; `to_dict`/`from_dict` round trip; the log is in
  `state_hash` (two worlds differing only in the log hash differently).
- `test_world_serializer.gd` (grows): the v1 → v2 migration writes `history_stride 7`, `run_log
  []` and fills every old sample's new fields as §3.4 says; a v2 file without them is
  `save_corrupt`.
- `test_line_chart.gd` (new): day → x and value → y at a fixed size; `nice` and the y ticks;
  the x tick interval for three widths; auto `y_max` respects the minimum span; end-label
  collision drops the later series; `set_cursor` snaps to the nearest sample and `values_at`
  reads it; `table_days` returns 17 ascending unique days for a 400-day domain; the empty state
  with one point; a stacked triple's cumulative geometry.
- `test_timeline_strip.gd` (new): two marks in one slot show the higher priority's glyph and the
  dot; the tooltip lists both; `day_pressed` carries the top mark's day.
- `test_run_log_text.gd` (new): every type renders a non-empty string in both locales with no
  unfilled `{placeholder}`; `is_yours` matches §4.2's column; `marker` for the five marked types
  and `{}` otherwise; an unknown node id renders the id.
- `test_theme_builder.gd` (grows): `ChartFrame` exists.
- Strings: every key in `RunLogText.KEYS` and every `UI_ANALYSIS_*` / `UI_CHART_*` / `UI_SERIES_*`
  key the panel uses exists in both languages (a static list in the panel script ↔ the table).

**Integration** — `tests/integration/test_analysis_panel.gd` (new)
- `G` opens and closes; the dock button is hidden in Boxed and shown enabled from Covert
  (`test_phase_reveal.gd` grows with the row); opening the Analysis closes the region panel and
  the containment panel and vice versa.
- After `Game.advance(120)` at seed 1 the Run tab has four charts whose single series has
  `history.size()` points; the Opposition tab shows the risk chart first and
  `UI_ANALYSIS_NOT_DISCOVERED` while undiscovered, and containment first after
  `world.discovered = true` + a tick; the World tab's assets row has four charts.
- Moving the cursor on one chart moves it on every chart of the tab and on the strip; `→` on a
  focused chart steps one sample.
- The table toggle replaces the charts with a `Tree` of `table_days` rows and a column per series;
  toggling back restores the charts.
- The Log tab lists a scripted run's entries oldest first, the filters hide the other class, a
  row with a region is a button that emits `region_selected` and closes the sheet.
- `SaveManager.save` → `load`: the reopened panel shows the same series lengths and the same log
  (not empty).
- Results review: on `run_ended` the results modal has the *Review* button; pressing it opens the
  sheet with the back button; back reopens the results with the same outcome text; the
  `"results"` hold is held throughout.
- Compact (400 × 860, `game_window set_size`): one column, the sheet at 0.85, no horizontal
  overflow of the body (the table excepted).
- Gallery: a *Charts* section — a three-series chart, a stacked chart, a small multiple, the strip
  with two crowded slots, the cursor at a fixed day; `F12` screenshots in both locales for D4.5.

---

## 16. Acceptance

**S4.8 *Done when*:** on a hand-played run at day ~300, pressing `G` shows the reach, compute,
footprint and harm lines with the Covert → Emergent band boundary where the ticker announced it,
the risk line rising to the discovery marker, four faction lines with the leader on top, and a log
whose last line is the last thing the console said; the cursor reads the same numbers the HUD
showed on that day (spot-check three); the table twin has them too; a save made then and loaded
shows the same panel; the results screen's *Review the run* opens it over the ended map and comes
back; a bot run at 4× with the panel open does not drop below the accumulator's frame budget
(`MAX_TICKS_PER_FRAME` never reached at 4×, checked once with the debug log); the German panel at
400 px shows every tab without clipped labels (screenshots for D4.5).
