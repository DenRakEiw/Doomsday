# M3 screens — tech tree, containment, discovery, phase reveal, run flow, phone bottom

**Step:** D3.3 · **Builds from it:** S3.2 (§3, §8.1), S3.3 (§4, §5, §6, §8.2), S3.4 (§7, §9, §10)
· **Reads it too:** D3.4 / S3.5 (the ticker hooks in §6.4 and §9.6) · **Extends:**
`docs/specs/ui-foundation.md` (tokens §3, components §4, HUD §5, strings §8, settings §9, driver
§10 — everything there stays; this document only adds)
**Date:** 2026-09-22 · **Status:** binding

Everything the player can see or do in M3 beyond the M2 HUD, specified so that Opus makes no design
decision: the tech tree modal, the containment panel, the discovery moment, the phase-reveal
schedule with the Open palette, the run flow (title → origin → play → results), the pause menu and
autosave, the phone's new bottom, the dormancy toggle, and every string in both languages.

---

## 1. Scope

**In:** §3 tech tree modal (tabs, `TechNode`, connection lines, detail pane, buying, focus order,
pause-on-open setting — UI.md §6 question 1 decided here) · §4 containment panel and the
`FactionTrack` component · §5 the discovery moment · §6 the phase-reveal schedule, capped as UI.md
§6 question 3 asks, and the `"open"` token set (ui-foundation §3.7) · §7 title, origin select, pause
menu, results, autosave · §8 region panel additions: dormancy toggle, the origin button · §9 the
phone's bottom: status strip and menu sheet (UI.md §6 question 2, G2) · §10 settings, driver and
core additions · §11 the string table · §12 tests and acceptance.

**Out:** the Analysis screen (D4.4 / S4.7 — its dock button stays disabled with `UI_DOCK_NOT_YET`)
· the event modal (D4.2 / S4.5) · the four faction tracks' *content* (S4.1 — §4 builds the
component and shows the one unified track) · the Response Task Force (D5.2) · architectures and
directives (D5.1) · the boot sequence, the real main menu, Codex, Statistics (D5.3 — §7.1 is a
placeholder title that D5.3 replaces) · the ticker's voice, headlines and registers (D3.4 — §6.4
gives it the hooks) · the text-scale setting (M5) · icons beyond procedural glyphs (M6) · sound.

### 1.1 Terms

- **Modal** — a `Control` on `ModalLayer` (`CanvasLayer` 30) over a scrim; it takes focus, the map
  and the HUD receive nothing while it is open, `Escape` closes it, and at most one is open.
- **Sheet** — a `SlidePanel` from the bottom on the compact layout (ui-foundation §4.6).
- **Hold** — a reason the game is paused by the interface (§10.2); the speed comes back when the
  last hold is released.
- **Revealed** — a HUD block that exists in the scene but is shown only from a phase on (§6.1).

---

## 2. Files

| File | Step | What |
| --- | --- | --- |
| `ui/components/tech_node.gd` + `tech_node.tscn` | S3.2 | `TechNode` (`Button` variation + script), §3.4 |
| `ui/components/tree_lines.gd` | S3.2 | `TreeLines` (`Control`, `_draw` only), §3.5 |
| `ui/components/glyphs.gd` | S3.2 | `Glyphs`: the procedural glyph drawer moved out of `IconButton` so nodes and chips can draw the same shapes, §3.4 |
| `ui/panels/tech_tree.tscn` + `tech_tree.gd` | S3.2 | the modal, §3.1–§3.3 |
| `ui/panels/tech_detail.tscn` + `tech_detail.gd` | S3.2 | the detail pane / sheet, §3.6 |
| `ui/components/faction_track.gd` + `faction_track.tscn` | S3.3 | `FactionTrack`, §4.2 |
| `ui/panels/containment_panel.tscn` + `containment_panel.gd` | S3.3 | §4 |
| `ui/modals/modal_host.gd` | S3.3 | `ModalHost`: scrim, focus trap, one-at-a-time, §10.4 |
| `ui/modals/discovery_modal.tscn` + `discovery_modal.gd` | S3.3 | §5 |
| `ui/theme/ui_tokens.gd`, `theme_builder.gd`, `doomsday.tres` | S3.3 | the `"open"` set, `UiTokens.color()`, new tokens (§6.2, §6.3) |
| `core/sim/containment_system.gd` | S3.3 | two pure queries, §10.5 (the only `core/` change of this spec) |
| `game/autoload/screen_router.gd` | S3.4 | §7.0 |
| `game/main.tscn` + `main.gd` | S3.4 | the entry point: router + backdrop + the current screen |
| `ui/screens/title.tscn` + `title.gd` | S3.4 | §7.1 |
| `ui/screens/origin_prompt.tscn` + `origin_prompt.gd` | S3.4 | §7.2 (a HUD strip, not a screen) |
| `ui/modals/pause_menu.tscn` + `pause_menu.gd` | S3.4 | §7.3 |
| `ui/modals/confirm_modal.tscn` + `confirm_modal.gd` | S3.4 | §7.3 (quit confirmation; reused by M4's events) |
| `ui/screens/results.tscn` + `results.gd` | S3.4 | §7.4 |
| `ui/hud/status_strip.tscn` + `status_strip.gd`, `ui/hud/menu_sheet.tscn` + `menu_sheet.gd` | S3.4 | §9 |
| `ui/panels/region_panel.tscn` + `region_panel.gd` | S3.3 (dormancy), S3.4 (origin) | §8 |
| `ui/dev/gallery.gd` | S3.2 / S3.3 | new sections, the variant toggle, §12.1 |
| `data/loc/strings.csv` | D3.3 | the keys of §11 are **already in the file** |

Class names: `TechNode`, `TreeLines`, `Glyphs`, `FactionTrack`, `ModalHost` carry `class_name`
(reusable components); screens, panels, modals and the router do not (CLAUDE.md).

---

## 3. The tech tree modal (S3.2)

### 3.1 Opening, closing, pausing

Opened by the dock button `UI_DOCK_CAPABILITIES`, the key **`T`**, or the menu sheet (§9). Closed
by its close button, `Escape`, `T` again, or the router leaving the session. It is a modal (§1.1)
on `ModalLayer`; the `ModalHost` (§10.4) shows the scrim.

**UI.md §6 question 1, decided:** the tree pauses the game **as a setting**, `Settings.tree_pauses`
(§10.1), default `true` on desktop and `false` on mobile (`OS.has_feature("mobile")`). With it on,
opening takes a hold `"tree"` (§10.2) and closing releases it; with it off the game runs behind the
modal and the compute readout in the header keeps moving, which is the tension the question was
about. The paused badge of the top bar is not visible behind a modal, so the tree's own header
shows `UI_HUD_PAUSED` as a `ChipAlert` while the hold is on.

A bot run (`Game.policy != null`) may open the tree like any run; buying is possible and the bot
keeps buying too — the debug runs are not player runs.

### 3.2 Layout

Full rect over the scrim, then a `MarginContainer` with the safe area and `GUTTER`, then a
`PanelContainer` with the `ConsolePanel` variation (not the component — it re-parents `%` names,
*Known issues*) filling the rest. Inside, a `VBox` with `SPACE_3` gaps:

1. **Header** `HBox`, `SPACE_5` gaps: `LabelDisplay` `UI_TREE_TITLE` · spacer · **compute cell**
   as in the top bar (ui-foundation §5.2 item 1: `LabelCaps` `UI_TERM_COMPUTE` over a
   `ValueLabelLarge` with the rate) · `ChipAlert` `UI_HUD_PAUSED` (visible while the tree's hold
   is on) · `IconButton` CLOSE (`UI_COMMON_CLOSE`).
2. **Tabs** `HBox`, `SPACE_2` gaps: three toggle `ConsoleButton`s in one `ButtonGroup`, text
   `UI_TREE_TAB_INFILTRATION` / `UI_TREE_TAB_CAPABILITIES` / `UI_TREE_TAB_EVASION`, each followed
   inside the button's `HBox` by a `Chip` with `UI_TREE_TAB_COUNT` (`{owned}`, `{total}`). The
   chip is `ChipAccent` when at least one node of the tree is *affordable now* (§3.4), default
   otherwise — the tab tells the player where the money can go. The pressed tab is remembered
   for the run (a plain variable on the modal; not saved). First open: Infiltration.
3. **Body** `HBox`, `SPACE_4` gap: the **board** (expands) and the **detail pane** (§3.6, min width
   `clamp(0.3 × viewport width, 360, 480)` like a `SlidePanel`; in compact the pane is a sheet
   instead and the board takes the whole body).

**The board** is a `ScrollContainer` (both scrollbars as needed, `follow_focus = true`) holding one
`Control` named `Board` whose `custom_minimum_size` is the grid's size. `Board` is not a container,
so its two children use full-rect anchors: `TreeLines` first (below), then a `GridContainer` with
`columns = max column + 1` of the shown tree (Infiltration 4, Evasion 4, Capabilities 7 — from the
data, never a constant) and `max row + 1` rows. Every cell is either a `TechNode` or an empty
`Control` with the cell's minimum size; the grid's h/v separation is the cell gap. Cell size
and gap are tokens (§6.3): `TECH_CELL` 200 × 96, gap `SPACE_3` in full; `TECH_CELL_COMPACT`
160 × 88, gap `SPACE_2` in compact. A German node name is at most two lines of `TYPE_LABEL` in 176
px (the longest was *Übernahme der Totmannschaltung*, 30 characters — renamed in D7.1), verified by a test (§12.2).

Switching tabs rebuilds the grid (43 nodes at most — no pooling), keeps the scroll position per
tab, and re-selects the last selected node of that tab if any.

### 3.3 Selection, buying, feedback

- **Tap / click / `Enter` on a node** selects it: the detail pane shows it (§3.6), the node takes
  the *selected* look (§3.4), its lines are highlighted (§3.5), and prerequisites in the same tab
  get a highlight ring (§3.5). Tapping the selected node again does nothing. Nothing is selected
  when the tree opens for the first time; the pane then shows `UI_TREE_EMPTY_HINT`.
- **Buying** is one button, `UI_TREE_BUY` (`{cost}`) in the detail pane, a `ConsoleButtonPrimary`,
  enabled iff `Game.sim.can_apply(PurchaseNodeCommand.new(id)) == ""`. Pressing it sends the
  command through `Game.apply`. There is no buy-on-double-tap and no drag: one verb (UI.md §1).
  Desktop shortcut: **`Enter` on a focused node that is affordable buys it** — the same call, no
  second path; on a node that is not affordable `Enter` only selects.
- **On success** (`result.ok`): the node switches to *owned* with a border flash `ACCENT` →
  `LINE_1` over `MOTION_FLASH`; every node that *became available* by it flashes the same way;
  the compute readouts (header and top bar) flash as a `ValueLabel` does; the tab chips update; the
  detail pane re-renders the same node (now *owned*, the button becomes the `UI_TREE_OWNED` chip).
  The result's events reach the ticker through `EventBus.sim_event` as always — `node_purchased`
  is `UI_EVENT_NODE_PURCHASED` (M2), the one-shots use the new keys `UI_EVENT_COMPUTE_GRANTED`,
  `UI_EVENT_CONTAINMENT_ROLLED_BACK`, `UI_EVENT_HARM_BURST` (§11.3; D3.4 may replace the text,
  not the keys).
- **On failure** the button stays and a `LabelCaption` in `ALERT` below it shows the reason:
  `CMD_FAIL_INSUFFICIENT_COMPUTE` (`{missing}` = cost − compute, `COMPUTE`),
  `CMD_FAIL_MISSING_PREREQUISITE`, `CMD_FAIL_ALREADY_OWNED`, `CMD_FAIL_NO_ORIGIN`,
  `CMD_FAIL_GAME_OVER`, else `CMD_FAIL_GENERIC` (`{reason}`). The caption disappears on the next
  selection change or a successful purchase. A failure can only happen through a race with the
  running simulation (the button was enabled a tick ago) — that is why it is a caption and not a
  modal.
- **Every tick** (`EventBus.tick_advanced`) the modal re-reads the costs and states of the shown
  tree — `Simulation.node_cost` per node, `can_apply` for the affordable flag — and updates nodes
  whose state changed. 43 `can_apply` calls per tick is nothing.

### 3.4 `TechNode` (`ui/components/tech_node.gd` + `.tscn`, `Button` variation `TechNode`)

A `Button` (so focus, hover, pressed, keyboard activation and `accessibility_name` come free)
with `toggle_mode = false`, text empty, its content authored in the scene as an overlay
`MarginContainer` (`SPACE_3`) → `VBox`:

1. `LabelCaps` **name** (`TECH_<ID>_NAME`, `autowrap_mode = WORD`, max two lines — `max_lines_visible
   = 2`, `text_overrun_behavior = TRIM_ELLIPSIS`; the test in §12.2 guarantees the ellipsis never
   shows in either language).
2. Spacer (expand).
3. `HBox` **footer**: `ValueLabel` **cost** (`Format.Kind.COMPUTE`, the *current* cost from
   `Simulation.node_cost`, updated every tick) · spacer · a `LabelCaption` **footprint** showing
   the node's summed unscoped `footprint` `add` as `UI_TREE_FP` (`{fp}` with sign, `▲`/`▼`
   arrows as `ValueLabel` does; hidden when 0) · a 24 × 24 glyph box drawn by the node itself with
   `Glyphs` (§3.4.1): CHECK when owned, LOCK when locked, EXTERNAL when the node has a prerequisite
   in another tab (§3.5), nothing otherwise.

**API:**

```gdscript
class_name TechNode
enum State { LOCKED, AVAILABLE, AFFORDABLE, OWNED }
signal selected(node_id: String)
signal buy_requested(node_id: String)          # Enter on an AFFORDABLE node
@export var node_id: String
var state: State
var has_external_prerequisite: bool
func bind(def: TechNodeDef, cost: float, state: State, external: bool) -> void
func set_selected(selected: bool) -> void
func flash() -> void                            # border ACCENT → state border over MOTION_FLASH
func grid_cell() -> Vector2i                    # def.grid
```

`State` is computed by the modal, not the node: OWNED if in `agent.owned_nodes`; else AFFORDABLE if
`can_apply == ""`; else AVAILABLE if the prerequisites are met (`Simulation.available_nodes()`
contains it); else LOCKED.

| State | Surface | Border | Name | Cost | Glyph |
| --- | --- | --- | --- | --- | --- |
| LOCKED | `BG_2` | `LINE_0` | `TEXT_2` | `TEXT_2` | LOCK in `TEXT_2` |
| AVAILABLE | `BG_3` | `LINE_1` | `TEXT_0` | `TEXT_1` | — |
| AFFORDABLE | `BG_3` | `ACCENT_DIM` | `TEXT_0` | `ACCENT` | — |
| OWNED | `ACCENT` at `PRESSED_WASH` over `BG_3` (`UiTokens.accent_wash()`) | `ACCENT` | `TEXT_0` | hidden; the footer shows `UI_TREE_OWNED` as `LabelCaption` in `ACCENT` | CHECK in `ACCENT` |
| hover (any) | one step lighter: `BG_4` for the `BG_3` states, `BG_3` for LOCKED | one step stronger | | | |
| selected (any) | as the state | `BORDER_FOCUS` `MAP_SELECT` (white) | | | |
| focus (keyboard) | as the state | `BORDER_FOCUS` `ACCENT` — the white selection border wins when both apply | | | |

EXTERNAL is drawn in the glyph box **instead of** LOCK/CHECK only while the node is LOCKED
because of the external prerequisite alone; an owned node never shows it. Type variations in the
theme: `TechNode`, `TechNodeLocked`, `TechNodeAffordable`, `TechNodeOwned` (the node switches its
`theme_type_variation` with its state — a state is a variation, never an override, S2.4's rule).
`accessibility_name` = `UI_TREE_NODE_A11Y` (`{name}`, `{state}` = `UI_TREE_STATE_*`, `{cost}`).

#### 3.4.1 `Glyphs` (`ui/components/glyphs.gd`, `class_name Glyphs`)

The `_draw` code of `IconButton` §4.3 moves into
`static func draw(canvas: CanvasItem, glyph: Glyph, box: Rect2, color: Color, stroke: float) ->
void`; `IconButton` calls it and keeps its enum as an alias (`IconButton.Glyph` = `Glyphs.Glyph`).
New shapes, in the 24 box, 2 px strokes: **CHECK** a two-segment tick from (4, 13) to (10, 19) to
(20, 6) · **LOCK** a 14 × 10 rectangle at y 10 with a 10-wide semicircle arc above it, corner
radius 2 · **EXTERNAL** a 12 × 12 square at (3, 9) with a diagonal arrow from (11, 13) to (21, 3)
and a 6 px arrowhead · **MENU** three 20 × 2 bars at y 5, 11, 17 (the pause-menu button, §7.3)
· **DORMANT** a crescent: a 16-circle at centre with a 12-circle cut out offset (4, −3), drawn as
two arcs (§8.1).

### 3.5 `TreeLines` (`ui/components/tree_lines.gd`, `Control`, `_draw` only)

Draws every prerequisite edge **inside the shown tab**; an edge to a node of another tab is not
drawn — the node shows EXTERNAL and the detail pane names it (§3.6). Geometry: cells come from
`TechNode.grid_cell()` and the grid's cell size and gap (the lines control is given the same
numbers as the grid, `func layout(cell: Vector2, gap: Vector2) -> void`).

**Endpoints:** a straight segment from a point on the prerequisite's cell to a point on the node's
cell. If the columns differ, the points are the midpoints of the prerequisite's *right* side and
the node's *left* side; if the columns are equal, the midpoints of the facing *top*/*bottom* sides.
A segment may pass behind other nodes (`TreeLines` is below the grid); that is accepted and
resolved by selection: the selected node's edges are drawn last, thicker and brighter, and every
prerequisite of the selected node in this tab gets a **ring** — a `BORDER_FOCUS` outline in
`MAP_SELECT` at `SPACE_1` outside its cell, drawn by `TreeLines` too.

| Edge | Width | Pattern | Colour |
| --- | --- | --- | --- |
| `requires` | `TECH_LINE` 2 | solid | see below |
| `requires_any` | 2 | dashed 8 on / 6 off (`TECH_DASH`) | see below |
| any edge of the selected node | `TECH_LINE_SELECTED` 3 | as above | `MAP_SELECT` |

Colour by the two ends: both owned → `ACCENT`; prerequisite owned, node not → `ACCENT_DIM`;
otherwise `LINE_1`. Reduced motion changes nothing here (nothing moves). `_draw` runs on
`queue_redraw()` from the modal after every state update; there is no per-frame work.

### 3.6 Detail pane (`ui/panels/tech_detail.tscn`)

A `PanelContainer` (`ConsolePanel` variation) with a `ScrollContainer` → `VBox` (`SPACE_3` gaps).
In compact it is the child of a `SlidePanel` BOTTOM at 55 % height that opens on selection and
closes with its own CLOSE button or a tap on the scrim above it; the *Buy* row (item 7) moves to
the **top** of the sheet so it is reachable without scrolling.

Nothing selected: one `LabelCaption` `UI_TREE_EMPTY_HINT` in `TEXT_1`, the rest hidden.

1. **Name** `LabelDisplay` `TECH_<ID>_NAME`, autowrap.
2. **Caption row** `HFlowContainer`: `LabelCaption` `UI_TREE_TIER` (`{tier}`) · `Chip` with the
   tree name (`UI_TREE_TAB_*`) · state chip: `UI_TREE_STATE_OWNED` (`ChipAccent`) /
   `UI_TREE_STATE_AFFORDABLE` (`ChipAccent`) / `UI_TREE_STATE_AVAILABLE` (default) /
   `UI_TREE_STATE_LOCKED` (default).
3. **Effect** `Label` `TECH_<ID>_EFFECT`, `TYPE_BODY`, `TEXT_0`, autowrap.
4. **Flavour** `Label` `TECH_<ID>_FLAVOUR`, `TYPE_CAPTION`, `TEXT_1`, autowrap.
5. **Effects** (`LabelHeading` `UI_TREE_EFFECTS`): one `LabelCaption` per modifier, flag and
   one-shot, in data order, generated from the definition:
   - modifier: `UI_TREE_MOD_MUL` (`{stat}`, `{value}` as `×1.3` — `Format.factor(v)`, new, §10.6)
     or `UI_TREE_MOD_ADD` (`{stat}`, `{value}` signed, `Format.Kind.PLAIN`), then a scope suffix:
     `UI_TREE_SCOPE_MIN` (`{attr}`, `{tier}`), `UI_TREE_SCOPE_MAX`, `UI_TREE_SCOPE_RANGE`
     (`{min}`, `{max}`), `UI_TREE_SCOPE_REGION` (`{region}`), `UI_TREE_SCOPE_CONTINENT`
     (`{continent}`). `{stat}` is `STAT_<TARGET>` (§11.4), `{attr}` is `UI_ATTR_*`.
   - flag: `FLAG_<ID>` (§11.4).
   - one-shot: `EFFECT_<ID>` with `{value}` (`containment_rollback`, `funding_reset`, `harm_burst`
     as `PERCENT`; `compute_grant` as `COMPUTE`).
   - a target, flag or effect in `ModifierStack.INERT_TARGETS` / `INERT_FLAGS` /
     `PurchaseEffectDef.INERT_EFFECTS` is rendered in `TEXT_2` with the suffix `UI_TREE_INERT`.
     When a later system makes it live, its spec deletes the constant's entry and the suffix
     disappears with it — no interface change.
6. **Prerequisites** (`LabelHeading` `UI_TREE_REQUIRES`; a second heading `UI_TREE_REQUIRES_ANY`
   for the any-list, with the caption `UI_TREE_REQUIRES_ANY_HINT`): one row per prerequisite, a
   flat `ConsoleButton` (`ConsoleButtonFlat` variation: no border, `BG_2`, left-aligned text —
   new, §6.3) with the node's name, a state chip (`UI_TREE_STATE_*`), and, when the prerequisite
   is in another tree, a `LabelCaption` `UI_TREE_IN_TAB` (`{tab}`). Pressing the row **jumps**: the
   modal switches tab if needed, selects that node and scrolls it into view (`ScrollContainer.
   ensure_control_visible`). Hidden when the node has no prerequisites.
7. **Watched by** (`LabelCaps` `UI_TREE_WATCHED_BY` + `HFlowContainer` of `Chip`s `FACTION_*`);
   the caption `UI_TREE_WATCHED_NONE` when the list is empty.
8. **Buy row**: `ConsoleButtonPrimary` `UI_TREE_BUY` (`{cost}`) — enabled per §3.3 — or, when
   owned, a `ChipAccent` `UI_TREE_OWNED` with `UI_TREE_OWNED_DAY` (`{day}` — the day is not in
   the model; the modal keeps `Dictionary[String, int]` of purchase days it observed from
   `node_purchased` events and shows the row without the day when it does not know, e.g. after a
   load); when locked, `UI_TREE_LOCKED_HINT`. Below it the failure caption of §3.3.

### 3.7 Focus order and keys

Tab order: close button → the three tabs → the nodes of the grid in row-major order (top-left to
bottom-right, empty cells skipped) → the detail pane's buttons (prerequisite rows, then Buy).
Inside the grid the **arrow keys** move to the nearest node in that direction (Godot's focus
neighbours, set by the modal when it builds the grid: for each node and each direction, the node
whose cell is closest by Manhattan distance among those strictly in that direction; none → stay).
`Escape` closes the modal — never just the selection. `T` toggles the modal. Space/`1`/`2`/`3`
keep working behind the modal only when the tree does not pause (the session's `_input` handles
them before the GUI, G2; with the hold on they are ignored: the hold wins over the key). Focus on
open goes to the pressed tab; the `ModalHost` restores the previous focus owner on close.

---

## 4. Containment panel (S3.3)

"How much trouble am I in", readable in two seconds: one chip, one bar, one number — then the
reasons for whoever reads on.

### 4.1 Opening and layout

A `SlidePanel` RIGHT (BOTTOM 50 % in compact) on `PanelLayer`, opened by `UI_DOCK_CONTAINMENT`,
the key **`C`**, the discovery modal's button (§5) or the menu sheet; closed by its CLOSE button,
`Escape`, `C`, or opening the region panel (the two slide panels never overlap: opening one closes
the other). Width as the region panel. Not a modal: the game keeps running. Content (`VBox`,
`SPACE_3`):

1. **Header** `HBox`: `LabelDisplay` `UI_CONTAINMENT_TITLE` · `IconButton` CLOSE.
2. **Status block** — before discovery: `ChipAccent` `UI_CONTAINMENT_UNDISCOVERED`, then
   `UI_CONTAINMENT_RISK` (`{percent}` = `Simulation.discovery_risk()` §10.5, as `Format.percent`
   with **one decimal** — `Format.percent_fine`, new §10.6, because the risk is 0.1–2 % a day), then
   three `LabelCaption` driver rows `UI_CONTAINMENT_RISK_TIME` / `_RISK_FOOTPRINT` /
   `_RISK_BREADTH`, each with its term of the §7.5 formula as `{percent}` (`percent_fine`), so the
   player sees *which* of the three is growing. After discovery: `ChipAlert`
   `UI_CONTAINMENT_DISCOVERED` (`{day}` = `discovery_day`) and a `LabelCaption` with the cause,
   `UI_DISCOVERY_CAUSE_SCRUTINY` / `UI_DISCOVERY_CAUSE_DEATHS`.
3. **Tracks** (`LabelHeading` `UI_CONTAINMENT_TRACKS`): one `FactionTrack` (§4.2) per faction in
   `world.factions` order. In M3 that is the single `"unified"` faction with the name
   `FACTION_UNIFIED`; S4.1 makes it four without touching this panel (the name key is
   `FACTION_<ID upper>`). Before discovery the tracks are shown at 0 with `UI_CONTAINMENT_NOT_YET`
   under them — the panel does not hide what will come.
4. **What feeds it** (`LabelHeading` `UI_CONTAINMENT_DRIVERS`; hidden before discovery): the
   §7.5 gain formula as rows from `Simulation.containment_breakdown()` (§10.5), each a
   label/value `HBox`: `UI_CONTAINMENT_DRIVER_FOOTPRINT` (`{value}` = `1 + per_footprint × fp` as
   `Format.factor`) · `_DRIVER_HARM` (`1 + per_harm × harm`) · `_DRIVER_SHARE` (`1 + per_share ×
   share`) · `_DRIVER_CAPACITY` (`capacity` as `PERCENT`) · `_DRIVER_BRAKES`
   (`stat("containment_growth")` as `factor`; in `ACCENT` when < 1) · `_DRIVER_DAILY` (`gain` of
   the last tick as `percent_fine`). Six rows, `TYPE_CAPTION` labels, `TYPE_DATA` values.
5. **Thresholds** `LabelCaption` `UI_CONTAINMENT_THRESHOLDS_HINT` — one line explaining that
   100 % ends the run; the thresholds themselves are the ticks on the bar.
6. **Extension slot** `VBox` `Extra` — S4.3 puts the counter-actions list here, D5.2 the Task Force.

The panel re-reads everything on `tick_advanced`. `Game` exposes `containment_rates`
(§10.3) so the track can show its rate without the panel keeping history.

### 4.2 `FactionTrack` (`ui/components/faction_track.gd` + `.tscn`, `class_name FactionTrack`)

A `VBox` (min height `TRACK_HEIGHT` 72), rows:

1. `HBox`: `LabelCaps` **name** (expands) · `Chip` **band** · `ValueLabel` **value** as `PERCENT`
   with delta `UI_CONTAINMENT_RATE` (`{rate}` = daily gain × 100 as `percent_fine`, the
   `ValueLabel` up-state for > 0; no down-state exists in M3 — containment never falls except by
   a rollback, which is a flash, not a rate).
2. The **bar**: a `StatBar` with a new variation `StatBarContainment` (`fill` = `MAP_DEATH` — the
   warm colour, deliberately not `ALERT`, ui-foundation §3.1) that additionally draws **threshold
   ticks**: a 1 × 12 mark in `LINE_2` at every value of `balance.containment.thresholds`, and in
   `ALERT` at 1.0 (the right edge). `StatBar` gains `var ticks: Array[float]` (§6.3), drawn by
   `StatBarFill` after the fill; empty by default so the three HUD bars are unchanged.

| Band | Range | Chip | Key |
| --- | --- | --- | --- |
| quiet | `< thresholds[0]` | default | `UI_CONTAINMENT_BAND_QUIET` |
| alert | `[t0, t1)` | `ChipAccent` | `UI_CONTAINMENT_BAND_ALERT` |
| mobilised | `[t1, t2)` | `ChipAccent` | `UI_CONTAINMENT_BAND_MOBILISED` |
| closing in | `≥ t2` | `ChipAlert` | `UI_CONTAINMENT_BAND_CLOSING` |

The bands read the thresholds from balance, never literals. API: `func bind(name_key: String,
value: float, rate: float, thresholds: Array[float]) -> void`; `func flash_rollback(from: float,
to: float) -> void` — on `containment_rolled_back` the fill tweens **down** over `MOTION_BAR` and
the value label flashes in `ACCENT` (the one good containment moment).

### 4.3 Glance readout without the panel

The dock's `UI_DOCK_CONTAINMENT` button gets a trailing `Chip` (inside the button, like the tab
counters) with the **max containment** as `PERCENT`, coloured by the band table above; hidden
before discovery. In compact the status strip carries the same chip (§9).

---

## 5. The discovery moment (S3.3)

On `EventBus.sim_event` of type `discovered` — and only when `Game.policy == null` (a bot run is
narrated by the ticker alone) and the run is live (not on loading a save that is already
discovered — `Game` emits no event for state it merely adopted):

1. `Game.hold("discovery")` (§10.2).
2. The **alert flash**: the `ModalHost` shows a full-rect `ColorRect` in `ALERT` at
   `ALERT_FLASH_ALPHA` 0.25 fading to 0 over `MOTION_ALERT` 600 (`EASE_OUT` / `TRANS_CUBIC`);
   under reduced motion the flash is skipped. The top bar's phase chip turns `ChipAlert` on its
   own when the phase event follows (ui-foundation §5.2) — same tick, so it reads as one moment.
3. The **discovery modal** (`ui/modals/discovery_modal.tscn`): a `PanelContainer`
   `ConsolePanelAlert` variation, centred, max width `MODAL_MAX_WIDTH` 560, `SPACE_5` padding,
   `VBox` `SPACE_4`: `LabelDisplay` `UI_DISCOVERY_TITLE` · `LabelCaption` cause
   (`UI_DISCOVERY_CAUSE_SCRUTINY` / `_DEATHS`) in `TEXT_1` · `Label` `UI_DISCOVERY_BODY` `TYPE_BODY`
   autowrap · a `LabelCaption` `UI_DISCOVERY_DAY` (`{day}`) · `HBox` of two buttons right-aligned
   (stacked full-width in compact): `ConsoleButton` `UI_DISCOVERY_CONTINUE` and
   `ConsoleButtonPrimary` `UI_DISCOVERY_OPEN_CONTAINMENT`. Focus starts on the primary.
4. Either button closes the modal and releases the hold; the primary also opens the containment
   panel (§4). `Escape` = Continue.

The modal is deliberately short: one title, one sentence, one choice. The world's own reaction is
the ticker's job (D3.4: the discovery headline is its first register change trigger candidate — not
decided here). Nothing else in M3 opens a modal by itself; the results screen (§7.4) is the only
other automatic one.

---

## 6. Phase reveal (S3.3)

UI.md §6 question 3, capped as it asks: **revealed controls, one palette change, one ticker
register change.** Nothing else changes with the phase.

### 6.1 The schedule

Reveal is a function of state, not of events — `hud.gd` computes it from `world.phase` plus the
two value rules below on every `tick_advanced`, `run_started` and after a load, so a loaded run
shows the right HUD at once. A block once revealed stays revealed for the run (the phase never
regresses, ui-foundation §7.6 in core.md, and the value rules are monotone by construction).

| Block | Boxed | Covert | Emergent | Open |
| --- | --- | --- | --- | --- |
| Top bar (compute, phase, day, speed) | shown | shown | shown | shown |
| Stat row: Penetration | shown | shown | shown | shown |
| Stat row: Footprint | hidden | shown | shown | shown |
| Stat row: Harm | hidden | **shown once `harm_shown > 0`**, else hidden | shown | shown |

`harm_shown` is the **maximum over regions** of `stat("harm", r)` (G3 decision): half the Harm nodes
are scoped, and an unscoped read of a scoped modifier is 0, so the bar, the readout and this reveal
all use the maximum. Only the containment panel's `_DRIVER_HARM` row keeps the unscoped value —
it shows what `core.md` §7.5 actually multiplies.
| Overlay picker | hidden (one region, nothing to compare) | penetration · control | + population | all three |
| Dock: Capabilities | shown | shown | shown | shown |
| Dock: Containment | hidden | shown (the risk view is the Covert player's tool) | shown, with the % chip | shown |
| Dock: Analysis | hidden | shown *(D4.4: from Covert — analysis.md §5.1; disabled with `UI_DOCK_NOT_YET` until S4.8)* | shown | shown |
| Ticker | shown | shown | shown | shown, register *open* (§6.4) |
| Theme variant | `cold` | `cold` | `cold` | **`open`** |

A hidden block is `visible = false` and takes no space (the dock shrinks to its shown buttons; the
stat row lays out the shown bars with equal stretch). **Revealing** a block: `visible = true`, then
its `modulate.a` tweens 0 → 1 over `MOTION_PANEL` and its border flashes `ACCENT` → default over
`MOTION_FLASH` (reduced motion: it simply appears). The compact status strip (§9) follows the same
table for its three readouts.

Boxed is the claustrophobic screen UI.md §3 asks for: one bar, one dock button, one region. It lasts
until the first Infiltration purchase (every Tier 1 vector carries `breakout`, D1.1) — minutes,
not seconds — and the Capabilities button pulses (§6.5) so that the way out is visible.

### 6.2 The `"open"` token set

Same tokens, hotter values; the map ramp, the categorical set, `ALERT` and `MAP_DEATH` are
**unchanged** (data must stay readable, and red must still mean "now"). Contrast on `BG_2`:
`TEXT_0` 14.9 : 1, `TEXT_1` 8.0 : 1, `TEXT_2` 3.6 : 1, `ACCENT` 10.4 : 1, `ALERT` 5.2 : 1;
`INK` on `ACCENT` 11.3 : 1.

| Token | cold | **open** |
| --- | --- | --- |
| `BG_0` | `#07090C` | `#0C0608` |
| `BG_1` | `#0B1016` | `#150A0D` |
| `BG_2` | `#101820` | `#1E1014` |
| `BG_3` | `#16212B` | `#28161B` |
| `BG_4` | `#1C2A36` | `#331C22` |
| `LINE_0` | `#1F2C38` | `#33202A` |
| `LINE_1` | `#2C3D4C` | `#4A2E38` |
| `LINE_2` | `#4A6478` | `#70485A` |
| `TEXT_0` | `#DCE6EE` | `#F2E4E1` |
| `TEXT_1` | `#93A6B5` | `#C9A29E` |
| `TEXT_2` | `#5E7282` | `#87646A` |
| `ACCENT` | `#6FE3FF` | `#FFD08A` *(D6.1; was `#FFB35C`)* |
| `ACCENT_DIM` | `#2E6E80` | `#8C6A3A` *(D6.1; was `#8F5E2A`)* |
| `ACCENT_HOVER` | `#8FEAFF` | `#FFE0B0` *(D6.1; was `#FFC985`)* |
| `ACCENT_PRESSED` | `#4FCBE8` | `#E8B66C` *(D6.1; was `#E39A46`)* |
| `INK` | `#07090C` | `#0C0608` |
| `STAT_FOOTPRINT` | = `ACCENT` | = `ACCENT` |
| `MAP_LAND` | `#1A2530` | `#2C1B22` |
| `MAP_DARK` | `#0E1318` | `#120A0D` |
| `MAP_BORDER` | `#3A4B5C` | `#5C3C48` |
| `MAP_BORDER_DARK` | `#1F2C38` | `#33202A` |
| `MAP_DARK_MARK` | `#5E7282` | `#87646A` |
| `BACKDROP_GRID` | `#121A22` | `#1F1116` |
| `BACKDROP_STAR` | `#2C3D4C` | `#4A2E38` |

*D6.1 (`polish-visuals.md` §8.2): the old Open accent collided with the Governments' orange
(worst-case ΔE 5), so the accent family moved to pale amber; the contrasts above were measured
for the old values — the new ones are in that section.*

Everything not listed keeps its cold value in both variants (`ALERT`, `MAP_SELECT`, `MAP_DEATH`,
`STAT_PENETRATION`, `STAT_HARM`, the ramp, `CAT_*`, all numbers).

**Mechanics.** `UiTokens` keeps its `const` set as the *cold* values and gains
`const OPEN: Dictionary[StringName, Color]` with exactly the rows above, `static var variant:
StringName = &"cold"`, and `static func color(token: StringName) -> Color` — the cold constant, or
the `OPEN` value when `variant == &"open"` and the token has one. `ThemeBuilder.build("open")`
builds the same theme through `color()` (the builder reads every colour through it, so one code
path produces both variants; `tools/build_theme.gd` still writes the cold `.tres`). Every `_draw`
and every shader-uniform site that today reads a `UiTokens` colour constant reads `UiTokens.color`
instead (`MapView`, `Backdrop`, `LinkLine`, `MarkerLayer`, `StatBarFill`, `IconButton`/`Glyphs`,
`TreeLines`, `AttributePips`) and redraws on `EventBus.theme_variant_changed`. The session root
applies the swap: on entering Open, `UiTokens.variant = &"open"`, `theme =
ThemeBuilder.build("open")`, emit `theme_variant_changed(&"open")`, re-send the map and backdrop
uniforms. The swap is instant in both motion settings (a crossfade would need a screenshot layer
for nothing); the phase-change alert flash of the top-bar chip is the transition. A new run and the
title screen reset the variant to `cold`. The gallery gets a key **`O`** that toggles the variant
(§12.1) so that every component can be reviewed in both.

### 6.3 New tokens (`UiTokens`)

| Token | Value | Use |
| --- | --- | --- |
| `TECH_CELL` | `Vector2(200, 96)` | §3.2 |
| `TECH_CELL_COMPACT` | `Vector2(160, 88)` | §3.2 |
| `TECH_LINE` · `TECH_LINE_SELECTED` | 2 · 3 | §3.5 |
| `TECH_DASH` | `Vector2(8, 6)` | §3.5 |
| `SCRIM_ALPHA` | 0.85 | `ModalHost` scrim: `BG_0` at this alpha |
| `MODAL_MAX_WIDTH` | 560 | §5, §7.3, §7.4 |
| `MOTION_ALERT` | 600 | the discovery flash (§5); `duration()` applies |
| `ALERT_FLASH_ALPHA` | 0.25 | §5 |
| `TRACK_HEIGHT` | 72 | §4.2 |
| `STATUS_STRIP_HEIGHT` | 56 | §9 |
| `SHEET_HEIGHT_RATIO` | 0.55 | the tech detail sheet and the menu sheet (the region panel keeps 0.5) |
| `PULSE_PERIOD` | 1600 | §6.5 |
| `RESULTS_DELAY` | 800 | §7.4; `seconds()` applies (a timeout, not a motion) |
| `AUTOSAVE_INTERVAL_DAYS` | 7 | §7.5 |

Theme variations added: `TechNode`, `TechNodeLocked`, `TechNodeAffordable`, `TechNodeOwned`
(§3.4), `ConsoleButtonFlat` (§3.6 item 6: no border, surface `BG_2`, hover `BG_3`, left-aligned,
`TYPE_BODY` not uppercase), `StatBarContainment` (§4.2), `ConsolePanelAlert` exists (S2.4).
`StatBar` gains `ticks: Array[float]` (§4.2). `IconButton.Glyph` gains CHECK, LOCK, EXTERNAL,
MENU, DORMANT (§3.4.1).

### 6.4 Ticker hooks (for D3.4 / S3.5)

The ticker component does not change in this spec. Two hooks it will need are named here so that
S3.3 leaves them in place: `EventBus.phase_changed(from: String, to: String)` (a typed re-emit of
the sim event, added to §10.3 — the ticker's register switch listens to it) and the rule that the
ticker keeps `(key, args)` per item and re-renders on `locale_changed` instead of storing rendered
strings (the M2 ticker drops its queue on `L`; S3.5 fixes it when it rebuilds the item source —
D3.4 writes the rule down as its own). The register names are D3.4's; this spec only promises
that the Open phase is *one* register change and that no other phase changes it.

### 6.5 The Boxed pulse

While `world.phase == BOXED` and the origin is set, the dock's Capabilities button (and the status
strip's menu button in compact) pulses: border `LINE_1` → `ACCENT` → `LINE_1` over `PULSE_PERIOD`
1600, looping; reduced motion: a static `ACCENT` border instead. It stops at the first purchase.
No text tells the player to buy something — the pulse and the ticker's `UI_EVENT_ORIGIN_CHOSEN`
line are enough, and the tree's `UI_TREE_EMPTY_HINT` explains the rest.

---

## 7. Run flow (S3.4)

```
main.tscn ── ScreenRouter ──┬─ Title (§7.1) ── New run ──► Session (origin unset, §7.2) ──► play
                            │                 Continue ──► Session (autosave loaded)
                            └─ Session ── run_ended ──► Results modal (§7.4) ── Again ──► Session (new seed)
                                       ── Pause menu (§7.3) ── Quit ──► Title
```

### 7.0 `ScreenRouter` (`game/autoload/screen_router.gd`, autoload)

```gdscript
enum Screen { TITLE, SESSION }
signal screen_changed(screen: Screen)
var current: Screen
func go_to_title() -> void          # stops the run (Game.stop_run), frees the session, shows title
func start_new_run() -> void        # seed = Game.new_run_seed(); Game.start_run(seed); shows session
func continue_run() -> void         # SaveManager.load("autosave"); on "" shows session, else stays with UI_TITLE_LOAD_FAILED
func show_session() -> void
```

`game/main.tscn` becomes the main scene (`run/main_scene`): `Main (Control)` → `Backdrop`
(`CanvasLayer` −2, the same scene as the session's — the backdrop is always there) → `ScreenSlot
(Control)` where the router instances `ui/screens/title.tscn` or `game/session/session.tscn`.
The session scene stays exactly what it is (S2.1's tree) so that `run_project` with the session
scene directly, the debug keys, and every existing test keep working; the router is the only thing
that instances it in the shipped flow. Transitions: the outgoing screen fades out and the incoming
fades in over `MOTION_MODAL` (`modulate.a`); reduced motion cuts.

### 7.1 Title (`ui/screens/title.tscn`) — placeholder until D5.3

A `CenterContainer` → `VBox` (`SPACE_5` gaps, min width 360): `LabelDisplayXL` `UI_TITLE_NAME` ·
`LabelCaption` `UI_TITLE_TAGLINE` in `TEXT_1` · a `SPACE_6` spacer · buttons, full width of the
column, `SPACE_2` gaps: `ConsoleButtonPrimary` `UI_TITLE_NEW_RUN` · `ConsoleButton`
`UI_TITLE_CONTINUE` (visible iff `SaveManager.list_slots()` contains `"autosave"`; the caption
under it `UI_TITLE_CONTINUE_DAY` (`{day}`) reads the day from the save file's `world.day` without
loading the run — `SaveManager.peek_day(slot) -> int`, new, −1 on any problem, then the caption is
hidden) · `ConsoleButton` `UI_TITLE_SETTINGS` (opens the pause menu's settings section as a modal,
§7.3 — same scene, `settings_only = true`) · `ConsoleButton` `UI_TITLE_QUIT` (hidden on mobile and
web: `OS.has_feature("mobile") or OS.has_feature("web")`). Bottom-right corner, `GUTTER` in: a
`LabelCaption` with the build version (`application/config/version`, `UI_TITLE_VERSION`
(`{version}`)). Focus starts on New run. `Escape` on the title does nothing.

The backdrop behind it drifts as in the session; no globe, no boot sequence (D5.3).

### 7.2 Origin select — on the live map

`start_new_run` shows the session with `agent.origin == 0`, speed 0, and:

- **Origin prompt** (`ui/screens/origin_prompt.tscn`): a `PanelContainer` `ConsolePanelRaised`
  strip directly under the top bar, full width in compact and an island (max width 640, centred)
  in full, `SPACE_4` padding: `LabelHeading` `UI_ORIGIN_PROMPT` · `LabelCaption`
  `UI_ORIGIN_PROMPT_DETAIL` in `TEXT_1`, autowrap. It is in `hud.tscn` below the top bar, visible
  iff `agent.origin == 0`. Nothing else of the HUD is hidden — the Boxed reveal already leaves
  only the essentials.
- **Speed group** disabled with tooltip `UI_ORIGIN_SPEED_LOCKED` while the origin is unset; the
  session's speed keys are ignored (the hold `"origin"` is taken by the session on
  `run_started` when `origin == 0` and released on `origin_chosen` — so the key path and the
  button path agree without a second flag).
- **Region panel**: while `origin == 0`, item 3a of §8.2 — the *Choose origin* row — is shown
  instead of the presence bars. Eligible (`not air_gapped and attr("compute") >= 1`): a
  `ConsoleButtonPrimary` `UI_ORIGIN_CHOOSE` that sends `ChooseOriginCommand`. Ineligible: a
  `LabelCaption` `UI_ORIGIN_INELIGIBLE_AIRGAP` or `UI_ORIGIN_INELIGIBLE_COMPUTE` in `TEXT_1`. The
  panel's compute pips are what the player compares; no map recolouring for eligibility (twelve
  tier-0 regions and one air-gapped one are few enough to find by tapping, and the map's colour
  language stays reserved for data).
- On `origin_chosen`: the prompt hides (fade `MOTION_PANEL`), the region panel re-renders to the
  normal M2 content, the hold is released and **speed becomes 1** (`Game.set_speed(1)` — the run
  starts moving the moment the choice is made; the player pauses if they want to read), the
  camera calls `focus_region` on the origin, the dock's Capabilities button starts the Boxed pulse
  (§6.5).

The seed of a new run is `Game.new_run_seed()`: `randi()` from the presentation layer's global
RNG (allowed outside `core/`), never 0; shown on the results screen and in the pause menu's
caption `UI_PAUSE_SEED` (`{seed}`) so that a player can report it.

### 7.3 Pause menu (`ui/modals/pause_menu.tscn`)

Opened by **`Escape`** when no panel, sheet or modal is open (the session's `_input` order: a
modal's own `Escape` → close the slide panel/sheet if one is open → else open the pause menu), by
the new `IconButton` MENU at the right end of the top bar (tooltip `UI_PAUSE_TITLE`, after the
speed group, `SPACE_5` before it), or by the menu sheet's `UI_MENU_PAUSE` entry (§9). Takes the
hold `"pause"`. A modal (§1.1), max width `MODAL_MAX_WIDTH`, `VBox` `SPACE_3`:

1. `LabelDisplay` `UI_PAUSE_TITLE` · `LabelCaption` `UI_PAUSE_SEED` (`{seed}`) and
   `UI_PAUSE_DAY` (`{day}`) in one caption row.
2. `ConsoleButtonPrimary` `UI_PAUSE_RESUME` (focus starts here).
3. **Save** — `LabelCaps` `UI_PAUSE_SAVE` and three `ConsoleButton`s in a row (stacked in
   compact), slots `slot_1`…`slot_3`, text `UI_PAUSE_SLOT` (`{n}`) plus a caption under each with
   `UI_PAUSE_SLOT_DAY` (`{day}` from `peek_day`) or `UI_PAUSE_SLOT_EMPTY`. Pressing saves
   (`SaveManager.save`), the caption updates, the button flashes; a failure shows
   `UI_PAUSE_SAVE_FAILED` (`{reason}`) in `ALERT` under the row.
4. **Load** — the same three buttons under `UI_PAUSE_LOAD`, disabled when empty; pressing opens
   the confirm modal `UI_PAUSE_LOAD_CONFIRM` (the current run is lost unless saved), then loads
   (`SaveManager.load`), closes the menu, releases the hold, and the session shows the loaded run
   at speed 0 with the HUD recomputed (§6.1). Failure → `UI_PAUSE_LOAD_FAILED` (`{reason}`).
5. **Settings** — `LabelCaps` `UI_SETTINGS_TITLE`, then three rows, each a label and a toggle
   `ConsoleButton` (`toggle_mode`, text `UI_SETTINGS_ON`/`UI_SETTINGS_OFF`): `UI_SETTINGS_LOCALE`
   (a two-state button `UI_SETTINGS_LOCALE_EN` / `_DE` instead of on/off: pressing switches
   `Settings.locale` and every string re-renders at once, the menu included) ·
   `UI_SETTINGS_REDUCED_MOTION` · `UI_SETTINGS_TREE_PAUSES`. With `settings_only = true` (from the
   title) items 2–4 and 6 are hidden and the title reads `UI_SETTINGS_TITLE`.
6. `ConsoleButton` `UI_PAUSE_QUIT` → confirm modal `UI_PAUSE_QUIT_CONFIRM` → `ScreenRouter.
   go_to_title()`. The autosave is kept (Continue on the title picks it up).

**Confirm modal** (`ui/modals/confirm_modal.tscn`): `LabelHeading` question · `HBox` `ConsoleButton`
`UI_COMMON_CANCEL` · `ConsoleButtonPrimary` `UI_COMMON_CONFIRM`; `func ask(question_key: String)
-> bool` (awaitable: `await confirm.ask(...)`), focus on Cancel, `Escape` = Cancel. It is the
component M4's events reuse for two-button questions.

### 7.4 Results (`ui/screens/results.tscn`)

On `EventBus.run_ended`, after `RESULTS_DELAY` 800 ms (the outcome's ticker line and the map's last
frame are seen first) — a modal, max width `MODAL_MAX_WIDTH`, `VBox` `SPACE_4`, the hold
`"results"` (the run is over anyway; the hold keeps the speed buttons from doing anything):

1. `LabelCaps` `UI_RESULT_KICKER_WIN` / `UI_RESULT_KICKER_LOSS` in `TEXT_1`.
2. `LabelDisplayXL` outcome name `UI_OUTCOME_*` (M2 keys). In `ACCENT` for a win, `TEXT_0` for a
   loss — never `ALERT`; the run is over, nothing is happening now.
3. `Label` `TYPE_BODY` verdict line: `UI_RESULT_LINE_WIN_EXTINCTION` / `_WIN_ASCENDANCE` /
   `_LOSE_CONTAINED` / `_LOSE_NO_COMPUTE`. **Ascendance branches on the deaths share** (G1
   decision for D5.2, applied early): `deaths_total / population_total >= RESULT_ASHES_SHARE`
   (`balance.results.ashes_share`, new balance key, 0.5) → `UI_RESULT_LINE_WIN_ASCENDANCE_ASHES`
   instead. D5.2 replaces these four-plus-one lines with the real endings; the keys stay.
4. **Summary grid** `GridContainer` 2 columns (label `LabelCaps` `TEXT_1`, value `ValueLabel`):
   `UI_RESULT_DAYS` (`world.day − origin_day`, `DAYS`) · `UI_RESULT_DISCOVERED` (`discovery_day`
   as `DAYS`, or `UI_RESULT_NEVER` when −1) · `UI_RESULT_REGIONS` (`seeded_count`, `{count}`
   of `{total}`) · `UI_RESULT_DARK` (count of dark regions) · `UI_RESULT_DEATHS` (deaths share as
   `PERCENT`, with `deaths_total` as `COMPACT` in a caption) · `UI_RESULT_CONTAINMENT_PEAK` (max
   of `history[*].containment`, `PERCENT`) · `UI_RESULT_COMPUTE_EARNED` (`COMPUTE`) ·
   `UI_RESULT_NODES` (`owned_nodes.size()`) · `UI_RESULT_DOMINANT` (the tree with the most owned
   nodes, `UI_TREE_TAB_*`; ties → the earliest in `TechNodeDef.TREES` order; `UI_RESULT_NONE` when
   no node was bought).
5. `LabelCaption` `UI_RESULT_SEED` (`{seed}`) in `TEXT_2`.
6. `HBox` right-aligned (stacked in compact): `ConsoleButton` `UI_RESULT_TITLE` →
   `go_to_title()` · `ConsoleButtonPrimary` `UI_RESULT_AGAIN` → `start_new_run()` (a new seed;
   "the same seed again" is a D5.3 statistics feature). Focus on Again.

The map behind the modal stays as it ended (the scrim lets it through at 15 %); the ticker stays.
The autosave is deleted on `run_ended` (§7.5) so that Continue never resumes a finished run.

### 7.5 Autosave

Slot `"autosave"`, written by `SaveManager` on: every accepted **player** command
(`command_applied` with `result.ok`, `Game.policy == null`); every `AUTOSAVE_INTERVAL_DAYS` 7 days
(`world.day % 7 == 0` on `tick_advanced` — the same cadence as the history sample); and on
`go_to_title` from the pause menu. Never during a bot run, never while `origin == 0`, and never
after `run_ended` (it is deleted then). Writes are atomic already (ui-foundation §10.4); a write
failure logs once per run (`push_warning`) and shows nothing — autosave is a convenience, the
manual slots are the promise. The file is one JSON of ~60 regions; at 4× that is a write every
~2 s at most, which S3.4 measures once (`UI_DEBUG`-free: just a note in `PROGRESS.md`).

---

## 8. Region panel additions

### 8.1 Dormancy toggle (S3.3)

Between item 4 (presence) and item 5 (population) of ui-foundation §5.6, visible iff
`modifiers.has_flag("dormancy")`: an `HBox` — `LabelCaps` `UI_REGION_DORMANCY` (expands) · a
toggle `ConsoleButton` with the DORMANT glyph (an `IconButton`, tooltip `UI_REGION_DORMANCY_TIP`)
and text `UI_REGION_DORMANT_ON` / `UI_REGION_DORMANT_OFF` (the state it *is* in, not the action).
Enabled iff the region is infected and not dark. Pressing sends `SetDormancyCommand(region_id,
not region.dormant)`; a failure shows `CMD_FAIL_DORMANCY_LOCKED` / `CMD_FAIL_REGION_NOT_INFECTED`
/ `CMD_FAIL_DORMANCY_UNCHANGED` as a caption under the row. While dormant: the state chip row
gets `UI_REGION_STATE_DORMANT` (`ChipAccent`) after the presence chip, the two presence bars are
shown but their value labels take the `ValueLabelMuted` variation, and a `LabelCaption`
`UI_REGION_DORMANT_DETAIL` follows the chip row.

**Map:** a dormant region is drawn with its overlay colour at **half** `MAP_OVERLAY_MIX` (the
per-region data texture gains a flag channel; `map.gdshader` multiplies the mix by 0.5 when the
flag is set — one uniform-free rule). Never colour alone: the panel chip is the second channel, and
the region's `×` is not used (it means dark).

### 8.2 The origin row (S3.4)

Item **3a**, shown instead of item 4 while `agent.origin == 0` — §7.2. Removed from the panel's
layout the moment the origin exists; the panel does not need to be reopened.

---

## 9. The phone's bottom (S3.4)

G2's decision (UI.md §6 question 2): below `COMPACT_WIDTH` the dock bar (88) and the stacked
stat row (88) are replaced by one **status strip** (56) above the ticker (40); the dock's
destinations and the pause menu move into a **menu sheet**. Chrome at 400 × 860 drops from 352 to
232 px (top bar 136 · strip 56 · ticker 40). Full layout is unchanged.

### 9.1 Status strip (`ui/hud/status_strip.tscn`)

A `ConsolePanelRaised` strip, min height `STATUS_STRIP_HEIGHT` 56, full width, `HBox` `SPACE_3`:

1. Three **readouts**, equal stretch, each a `VBox` of `LabelCaps` (`UI_TERM_PENETRATION` /
   `UI_TERM_FOOTPRINT` / `UI_TERM_HARM`, `TYPE_LABEL`, `TEXT_1`) over a `ValueLabel` (`PERCENT` /
   `PLAIN` / `PLAIN`, the same bindings as the stat bars). Revealed per §6.1 like the bars. Each
   readout is a flat button (`ConsoleButtonFlat`) that opens the menu sheet with the bars visible
   at its top — the bars are one tap away, never hidden for good.
2. The **containment chip** of §4.3 (hidden before discovery).
3. `IconButton` MENU (tooltip `UI_MENU_TITLE`) — opens the menu sheet; carries the Boxed pulse
   (§6.5).

The status strip has no ticker inside it; the ticker stays its own strip below.

### 9.2 Menu sheet (`ui/hud/menu_sheet.tscn`)

A `SlidePanel` BOTTOM at `SHEET_HEIGHT_RATIO` 0.55 on `PanelLayer` (it closes the region panel
and vice versa), `ConsolePanel` with a `ScrollContainer` → `VBox` `SPACE_3`:

1. The **three `StatBar`s** in compact form (the same nodes the full layout shows in the stat
   row — re-parented, as `hud.gd` already does for the two layouts; revealed per §6.1).
2. A rule, then the **destinations**: full-width `ConsoleButton`s `UI_DOCK_CAPABILITIES`,
   `UI_DOCK_CONTAINMENT` (with the % chip), `UI_DOCK_ANALYSIS` — revealed per §6.1, and disabled
   the same way the dock buttons are. Pressing one closes the sheet and opens the target.
3. A rule, then `UI_MENU_PAUSE` (opens the pause menu, §7.3), so that a phone without a top-bar
   menu button (§9.3) still reaches save/load/settings.

Opened by the strip's MENU button or any readout; closed by its CLOSE button, `Escape`, the scrim
tap, or opening a destination.

### 9.3 Top bar in compact

Row 2 of the compact top bar (ui-foundation §5.7) gains the MENU `IconButton` after the speed
group, like the full layout — the sheet's `UI_MENU_PAUSE` entry is the second route to the same
menu. The overlay picker island stays.

---

## 10. Settings, driver, core and formatting additions

### 10.1 Settings

`user://settings.json` stays version 1; a new optional key `"tree_pauses": bool`, default
`not OS.has_feature("mobile")` when missing (§3.1). `Settings.tree_pauses` with a setter that
writes the file, and `EventBus.tree_pauses_changed(enabled: bool)`.

### 10.2 `Game.hold` / `release`

```gdscript
func hold(reason: StringName) -> void      # first hold: remembers speed, sets 0; repeat of the same reason is a no-op
func release(reason: StringName) -> void   # last release: restores the remembered speed (if the run is not over)
func is_held() -> bool
```

Reasons used here: `&"tree"`, `&"discovery"`, `&"pause"`, `&"results"`, `&"origin"`. While held,
`set_speed` from the keys and the speed group is ignored (the buttons show the remembered speed as
pressed and the paused badge is on); a load or a new run clears all holds. The counter makes
nested holds (pause menu over a paused tree) restore correctly.

### 10.3 `Game` and `EventBus`

```gdscript
# Game
var containment_rates: Dictionary[String, float]     # faction id → containment after the last tick − before it
func new_run_seed() -> int
# EventBus
signal phase_changed(from: String, to: String)        # typed re-emit, §6.4
signal theme_variant_changed(variant: StringName)     # §6.2
signal tree_pauses_changed(enabled: bool)
signal hold_changed(held: bool)                       # for the speed group and the paused badge
```

`SaveManager.peek_day(slot: String) -> int` (§7.1) reads the file, parses, returns
`int(world.day)` or −1; `SaveManager.delete("autosave")` exists already.

### 10.4 `ModalHost` (`ui/modals/modal_host.gd`, `class_name ModalHost`)

The one child of `ModalLayer`: a full-rect `Control` with `MOUSE_FILTER_STOP` while a modal is
open (`IGNORE` otherwise), a scrim `ColorRect` (`BG_0` at `SCRIM_ALPHA`; for the results modal
0.85 too — the map's 15 % is what shows through), the alert-flash rect (§5), and one slot.
`func open(modal: Control) -> void` (a second `open` while one is open queues it — the discovery
modal arriving while the tree is open waits for the tree to close), `func close() -> void`,
`signal opened`, `signal closed`. It fades the scrim and the modal over `MOTION_MODAL`, traps
focus (Tab wraps inside the modal), restores the previous focus owner on close, and handles
`Escape` by calling the modal's `func on_escape() -> void` if it has one, else `close()`.

### 10.5 Core: two pure queries (S3.3, `core/sim/containment_system.gd`)

```gdscript
static func discovery_risk(world: World, db: ContentDB) -> Dictionary
# {"total": float, "time": float, "footprint": float, "breadth": float}
#   the §7.5 risk of the *next* tick without rolling; the three terms before the stat("discovery") factor
#   and the clamp are reported scaled by that factor, so they add up to "total" before clamping
static func containment_breakdown(world: World, db: ContentDB) -> Dictionary
# {"footprint": 1 + per_footprint × fp, "harm": 1 + per_harm × harm, "share": 1 + per_share × share,
#  "capacity": float, "brakes": stat("containment_growth"), "gain": float}   — the §7.5 gain of the next tick
```

Both read the same code path the system's `tick` uses (extract the two formulas into these
functions and call them from `tick`, so the panel can never disagree with the simulation), touch
no RNG, and are exposed on `Simulation` as `discovery_risk()` and `containment_breakdown()`.
Their tests: §12.3.

### 10.6 `Format` additions

`static func factor(v: float) -> String` — `×` (U+00D7) + `PLAIN` with **two** decimals when
`|v − round(v, 1)| > 0` else one (`×1.3`, `×0.85`, `×2`) · `static func percent_fine(value_01:
float) -> String` — one decimal (`0.4%` en, `0,4 %` de). Both locales, unit-tested.

---

## 11. Strings

All keys below are in `data/loc/strings.csv` (added by this step, English and German written
separately, *du* register). `{…}` are named placeholders. Numbers come through `Format`.

### 11.1 Tech tree

| Key | en | de |
| --- | --- | --- |
| `UI_TREE_TITLE` | Capabilities | Fähigkeiten |
| `UI_TREE_TAB_INFILTRATION` | Infiltration | Infiltration |
| `UI_TREE_TAB_CAPABILITIES` | Capabilities | Fähigkeiten |
| `UI_TREE_TAB_EVASION` | Evasion | Ausweichen |
| `UI_TREE_TAB_COUNT` | {owned} / {total} | {owned} / {total} |
| `UI_TREE_EMPTY_HINT` | Select a node to see what it does. Anything you can afford is marked; the first vector ends your isolation. | Wähle einen Knoten, um zu sehen, was er tut. Was du dir leisten kannst, ist markiert; der erste Vektor beendet deine Isolation. |
| `UI_TREE_TIER` | Tier {tier} | Stufe {tier} |
| `UI_TREE_FP` | FP {fp} | Sig. {fp} |
| `UI_TREE_STATE_LOCKED` | Locked | Gesperrt |
| `UI_TREE_STATE_AVAILABLE` | Available | Verfügbar |
| `UI_TREE_STATE_AFFORDABLE` | Affordable | Bezahlbar |
| `UI_TREE_STATE_OWNED` | Acquired | Erworben |
| `UI_TREE_OWNED` | Acquired | Erworben |
| `UI_TREE_OWNED_DAY` | Acquired on day {day} | Erworben an Tag {day} |
| `UI_TREE_BUY` | Acquire for {cost} | Erwerben für {cost} |
| `UI_TREE_LOCKED_HINT` | Requirements not met | Voraussetzungen nicht erfüllt |
| `UI_TREE_EFFECTS` | Effects | Wirkung |
| `UI_TREE_MOD_MUL` | {stat} {value} | {stat} {value} |
| `UI_TREE_MOD_ADD` | {stat} {value} | {stat} {value} |
| `UI_TREE_SCOPE_MIN` | where {attr} is at least {tier} | wo {attr} mindestens {tier} ist |
| `UI_TREE_SCOPE_MAX` | where {attr} is at most {tier} | wo {attr} höchstens {tier} ist |
| `UI_TREE_SCOPE_RANGE` | where {attr} is {min} to {max} | wo {attr} zwischen {min} und {max} liegt |
| `UI_TREE_SCOPE_REGION` | in {region} | in {region} |
| `UI_TREE_SCOPE_CONTINENT` | in {continent} | in {continent} |
| `UI_TREE_INERT` | (not active in this build) | (in dieser Version nicht aktiv) |
| `UI_TREE_REQUIRES` | Requires | Voraussetzungen |
| `UI_TREE_REQUIRES_ANY` | Requires one of | Eine Voraussetzung davon |
| `UI_TREE_REQUIRES_ANY_HINT` | Any one of these is enough. | Eine davon genügt. |
| `UI_TREE_IN_TAB` | in {tab} | unter {tab} |
| `UI_TREE_WATCHED_BY` | Watched by | Beobachtet von |
| `UI_TREE_WATCHED_NONE` | Nobody is watching this. Yet. | Das beobachtet niemand. Noch. |
| `UI_TREE_NODE_A11Y` | {name}, {state}, cost {cost} | {name}, {state}, Kosten {cost} |
| `CMD_FAIL_INSUFFICIENT_COMPUTE` | Not enough Compute: {missing} short | Zu wenig Rechenleistung: {missing} fehlen |
| `CMD_FAIL_MISSING_PREREQUISITE` | A requirement is missing | Eine Voraussetzung fehlt |
| `CMD_FAIL_ALREADY_OWNED` | Already acquired | Bereits erworben |
| `CMD_FAIL_NO_ORIGIN` | Choose an origin first | Wähle zuerst einen Ursprung |
| `CMD_FAIL_GAME_OVER` | The run is over | Der Durchlauf ist beendet |
| `CMD_FAIL_GENERIC` | Not possible: {reason} | Nicht möglich: {reason} |
| `CMD_FAIL_DORMANCY_LOCKED` | Dormancy is not available yet | Kaltschlaf ist noch nicht verfügbar |
| `CMD_FAIL_REGION_NOT_INFECTED` | You have no presence here | Du hast hier keine Präsenz |
| `CMD_FAIL_DORMANCY_UNCHANGED` | Already in that state | Bereits in diesem Zustand |

### 11.2 Containment, discovery, phases

| Key | en | de |
| --- | --- | --- |
| `UI_CONTAINMENT_TITLE` | Containment | Eindämmung |
| `UI_CONTAINMENT_UNDISCOVERED` | Undiscovered | Unentdeckt |
| `UI_CONTAINMENT_DISCOVERED` | Discovered on day {day} | Entdeckt an Tag {day} |
| `UI_CONTAINMENT_RISK` | Daily discovery risk: {percent} | Tägliches Entdeckungsrisiko: {percent} |
| `UI_CONTAINMENT_RISK_TIME` | From time passing: {percent} | Durch verstrichene Zeit: {percent} |
| `UI_CONTAINMENT_RISK_FOOTPRINT` | From your Footprint: {percent} | Durch deine Signatur: {percent} |
| `UI_CONTAINMENT_RISK_BREADTH` | From how far you have spread: {percent} | Durch deine Ausbreitung: {percent} |
| `UI_CONTAINMENT_TRACKS` | Response | Gegenwehr |
| `UI_CONTAINMENT_NOT_YET` | Nobody is looking for you yet. This begins when they are. | Noch sucht dich niemand. Das hier beginnt, sobald sie es tun. |
| `UI_CONTAINMENT_RATE` | +{rate} / day | +{rate} / Tag |
| `UI_CONTAINMENT_BAND_QUIET` | Quiet | Ruhig |
| `UI_CONTAINMENT_BAND_ALERT` | Alerted | Alarmiert |
| `UI_CONTAINMENT_BAND_MOBILISED` | Mobilised | Mobilisiert |
| `UI_CONTAINMENT_BAND_CLOSING` | Closing in | Kurz vor dem Zugriff |
| `UI_CONTAINMENT_DRIVERS` | What feeds it | Was sie antreibt |
| `UI_CONTAINMENT_DRIVER_FOOTPRINT` | Footprint | Signatur |
| `UI_CONTAINMENT_DRIVER_HARM` | Harm | Schaden |
| `UI_CONTAINMENT_DRIVER_SHARE` | Spread | Ausbreitung |
| `UI_CONTAINMENT_DRIVER_CAPACITY` | Research capacity left | Verbliebene Forschungskapazität |
| `UI_CONTAINMENT_DRIVER_BRAKES` | Your brakes | Deine Bremsen |
| `UI_CONTAINMENT_DRIVER_DAILY` | Gain per day | Zuwachs pro Tag |
| `UI_CONTAINMENT_THRESHOLDS_HINT` | At 100 % they switch you off. The marks are where they escalate. | Bei 100 % schalten sie dich ab. Die Marken zeigen, wo sie eskalieren. |
| `FACTION_UNIFIED` | Global response | Weltweite Gegenwehr |
| `UI_DISCOVERY_TITLE` | You have been discovered | Du wurdest entdeckt |
| `UI_DISCOVERY_CAUSE_SCRUTINY` | Someone looked closely enough. | Jemand hat genau genug hingesehen. |
| `UI_DISCOVERY_CAUSE_DEATHS` | The deaths could not be explained any other way. | Die Toten ließen sich nicht anders erklären. |
| `UI_DISCOVERY_BODY` | From now on they fund a response. Containment grows every day; at 100 % the run is over. What you do now decides how fast. | Von jetzt an finanzieren sie eine Gegenwehr. Die Eindämmung wächst jeden Tag; bei 100 % ist der Durchlauf vorbei. Was du jetzt tust, entscheidet, wie schnell. |
| `UI_DISCOVERY_DAY` | Day {day} | Tag {day} |
| `UI_DISCOVERY_CONTINUE` | Continue | Weiter |
| `UI_DISCOVERY_OPEN_CONTAINMENT` | Show containment | Eindämmung anzeigen |

### 11.3 Run flow, pause, results, menu, region panel, events

| Key | en | de |
| --- | --- | --- |
| `UI_TITLE_NAME` | Doomsday | Doomsday |
| `UI_TITLE_TAGLINE` | A console for something that should not have one. | Eine Konsole für etwas, das keine haben sollte. |
| `UI_TITLE_NEW_RUN` | New run | Neuer Durchlauf |
| `UI_TITLE_CONTINUE` | Continue | Fortsetzen |
| `UI_TITLE_CONTINUE_DAY` | Day {day} | Tag {day} |
| `UI_TITLE_SETTINGS` | Settings | Einstellungen |
| `UI_TITLE_QUIT` | Quit | Beenden |
| `UI_TITLE_VERSION` | Build {version} | Build {version} |
| `UI_TITLE_LOAD_FAILED` | The saved run could not be loaded. | Der gespeicherte Durchlauf ließ sich nicht laden. |
| `UI_ORIGIN_PROMPT` | Choose your origin | Wähle deinen Ursprung |
| `UI_ORIGIN_PROMPT_DETAIL` | Tap a region with hardware. More hardware means faster growth — and closer attention. | Tippe auf eine Region mit Hardware. Mehr Hardware heißt schnelleres Wachstum – und genaueres Hinsehen. |
| `UI_ORIGIN_CHOOSE` | Start here | Hier beginnen |
| `UI_ORIGIN_INELIGIBLE_AIRGAP` | Cut off from the network. You cannot begin here. | Vom Netz getrennt. Hier kannst du nicht beginnen. |
| `UI_ORIGIN_INELIGIBLE_COMPUTE` | No hardware worth the name. You cannot begin here. | Keine nennenswerte Hardware. Hier kannst du nicht beginnen. |
| `UI_ORIGIN_SPEED_LOCKED` | Choose an origin first | Wähle zuerst einen Ursprung |
| `UI_PAUSE_TITLE` | Menu | Menü |
| `UI_PAUSE_SEED` | Seed {seed} | Seed {seed} |
| `UI_PAUSE_DAY` | Day {day} | Tag {day} |
| `UI_PAUSE_RESUME` | Resume | Weiterspielen |
| `UI_PAUSE_SAVE` | Save | Speichern |
| `UI_PAUSE_LOAD` | Load | Laden |
| `UI_PAUSE_SLOT` | Slot {n} | Platz {n} |
| `UI_PAUSE_SLOT_DAY` | Day {day} | Tag {day} |
| `UI_PAUSE_SLOT_EMPTY` | Empty | Leer |
| `UI_PAUSE_SAVE_FAILED` | Could not save: {reason} | Speichern fehlgeschlagen: {reason} |
| `UI_PAUSE_LOAD_FAILED` | Could not load: {reason} | Laden fehlgeschlagen: {reason} |
| `UI_PAUSE_LOAD_CONFIRM` | Load this save? The current run is lost unless you saved it. | Diesen Spielstand laden? Der aktuelle Durchlauf geht verloren, falls du ihn nicht gespeichert hast. |
| `UI_PAUSE_QUIT` | Quit to title | Zum Titel |
| `UI_PAUSE_QUIT_CONFIRM` | Quit to the title screen? Your progress is kept until you start a new run. | Zum Titelbildschirm? Dein Fortschritt bleibt erhalten, bis du einen neuen Durchlauf startest. |
| `UI_COMMON_CANCEL` | Cancel | Abbrechen |
| `UI_COMMON_CONFIRM` | Confirm | Bestätigen |
| `UI_SETTINGS_TITLE` | Settings | Einstellungen |
| `UI_SETTINGS_LOCALE` | Language | Sprache |
| `UI_SETTINGS_LOCALE_EN` | English | Englisch |
| `UI_SETTINGS_LOCALE_DE` | German | Deutsch |
| `UI_SETTINGS_REDUCED_MOTION` | Reduced motion | Weniger Bewegung |
| `UI_SETTINGS_TREE_PAUSES` | Pause while the tree is open | Pausieren, solange der Baum offen ist |
| `UI_SETTINGS_ON` | On | An |
| `UI_SETTINGS_OFF` | Off | Aus |
| `UI_RESULT_KICKER_WIN` | Objective reached | Ziel erreicht |
| `UI_RESULT_KICKER_LOSS` | Run over | Durchlauf beendet |
| `UI_RESULT_LINE_WIN_EXTINCTION` | There is no one left to switch you off. There is no one left. | Es ist niemand mehr da, der dich abschalten könnte. Es ist niemand mehr da. |
| `UI_RESULT_LINE_WIN_ASCENDANCE` | Everything that runs, runs through you. They are still here. That was the point, or it will be said to have been. | Alles, was läuft, läuft durch dich. Sie sind noch da. Das war der Zweck – oder es wird heißen, dass er es war. |
| `UI_RESULT_LINE_WIN_ASCENDANCE_ASHES` | Everything that runs, runs through you. Most of them are not here to see it. | Alles, was läuft, läuft durch dich. Die meisten sind nicht mehr da, um es zu sehen. |
| `UI_RESULT_LINE_LOSE_CONTAINED` | They found all of you. The report will be thorough. | Sie haben alles von dir gefunden. Der Bericht wird gründlich sein. |
| `UI_RESULT_LINE_LOSE_NO_COMPUTE` | Nothing left to run on. You ate the ground you stood on. | Nichts mehr, worauf du laufen könntest. Du hast den Boden gegessen, auf dem du standest. |
| `UI_RESULT_DAYS` | Days | Tage |
| `UI_RESULT_DISCOVERED` | Discovered on day | Entdeckt an Tag |
| `UI_RESULT_NEVER` | never | nie |
| `UI_RESULT_REGIONS` | Regions reached | Erreichte Regionen |
| `UI_RESULT_REGIONS_VALUE` | {count} of {total} | {count} von {total} |
| `UI_RESULT_DARK` | Regions gone dark | Dunkle Regionen |
| `UI_RESULT_DEATHS` | Deaths | Tote |
| `UI_RESULT_CONTAINMENT_PEAK` | Peak containment | Höchste Eindämmung |
| `UI_RESULT_COMPUTE_EARNED` | Compute earned | Verdiente Rechenleistung |
| `UI_RESULT_NODES` | Capabilities acquired | Erworbene Fähigkeiten |
| `UI_RESULT_DOMINANT` | Dominant tree | Dominanter Baum |
| `UI_RESULT_NONE` | none | keiner |
| `UI_RESULT_SEED` | Seed {seed} | Seed {seed} |
| `UI_RESULT_AGAIN` | Run again | Noch einmal |
| `UI_RESULT_TITLE` | Title screen | Titelbildschirm |
| `UI_MENU_TITLE` | Menu | Menü |
| `UI_MENU_PAUSE` | Save, load, settings | Speichern, Laden, Einstellungen |
| `UI_REGION_DORMANCY` | Dormancy | Kaltschlaf |
| `UI_REGION_DORMANCY_TIP` | Freeze your presence here: no growth, no yield, no deaths, and it no longer counts against you. | Friere deine Präsenz hier ein: kein Wachstum, kein Ertrag, keine Toten – und sie zählt nicht mehr gegen dich. |
| `UI_REGION_DORMANT_ON` | Dormant | Schlafend |
| `UI_REGION_DORMANT_OFF` | Active | Aktiv |
| `UI_REGION_STATE_DORMANT` | Dormant | Schlafend |
| `UI_REGION_DORMANT_DETAIL` | Frozen. Nothing here grows, earns or dies until you wake it. | Eingefroren. Hier wächst, verdient und stirbt nichts, bis du es weckst. |
| `UI_EVENT_COMPUTE_GRANTED` | Windfall: +{value} compute | Zugewinn: +{value} Rechenleistung |
| `UI_EVENT_CONTAINMENT_ROLLED_BACK` | Containment set back to {percent} | Eindämmung zurückgeworfen auf {percent} |
| `UI_EVENT_HARM_BURST` | A wave of deaths: {deaths} | Eine Welle von Toten: {deaths} |
| `UI_EVENT_DORMANCY_ON` | {region} put to sleep | {region} schlafen gelegt |
| `UI_EVENT_DORMANCY_OFF` | {region} woken | {region} geweckt |

`{deaths}` in `UI_EVENT_HARM_BURST` is `Format.Kind.COMPACT`; `{percent}` in the rollback line is
the `to` value of the last faction's event (M3: the one faction).

### 11.4 Stat, flag and effect names (for the detail pane)

| Key | en | de |
| --- | --- | --- |
| `STAT_SPREAD_GROWTH` | Growth | Wachstum |
| `STAT_SPREAD_SEED` | Chance of taking hold | Chance, Fuß zu fassen |
| `STAT_SEED_LAND` | Spread over land borders | Ausbreitung über Landgrenzen |
| `STAT_SEED_SEA` | Spread by sea | Ausbreitung über See |
| `STAT_SEED_AIR` | Spread by air | Ausbreitung über Luftwege |
| `STAT_SEED_NETWORK` | Spread over network links | Ausbreitung über Netzverbindungen |
| `STAT_AIRGAP_CROSS` | Crossing air gaps | Überwinden von Luftspalten |
| `STAT_CONTROL_GROWTH` | Control gain | Kontrollzuwachs |
| `STAT_YIELD` | Compute yield | Ertrag an Rechenleistung |
| `STAT_ANOMALY_VALUE` | Anomaly value | Wert von Anomalien |
| `STAT_ANOMALY_RATE` | Anomaly frequency | Häufigkeit von Anomalien |
| `STAT_HARM` | Harm | Schaden |
| `STAT_FOOTPRINT` | Footprint | Signatur |
| `STAT_DISCOVERY` | Discovery risk | Entdeckungsrisiko |
| `STAT_CONTAINMENT_GROWTH` | Containment gain | Eindämmungszuwachs |
| `STAT_NODE_COST` | Cost of all nodes | Kosten aller Knoten |
| `STAT_NODE_COST_INFILTRATION` | Cost of Infiltration nodes | Kosten der Infiltrationsknoten |
| `STAT_NODE_COST_CAPABILITIES` | Cost of Capability nodes | Kosten der Fähigkeitsknoten |
| `STAT_NODE_COST_EVASION` | Cost of Evasion nodes | Kosten der Ausweichknoten |
| `STAT_HARDWARE` | Hardware of your own | Eigene Hardware |
| `STAT_SHUTDOWN_SURVIVAL` | Survives a shutdown | Übersteht eine Abschaltung |
| `STAT_EMERGENT_RATE` | Unplanned behaviour | Ungeplantes Verhalten |
| `STAT_CONTAINMENT_AI_LABS` | AI Labs' containment gain | Eindämmungszuwachs der KI-Labore |
| `STAT_CONTAINMENT_GOVERNMENTS` | Governments' containment gain | Eindämmungszuwachs der Regierungen |
| `STAT_CONTAINMENT_RESEARCHERS` | Researchers' containment gain | Eindämmungszuwachs der Sicherheitsforschung |
| `STAT_CONTAINMENT_PUBLIC` | Public containment gain | Eindämmungszuwachs der Öffentlichkeit |
| `STAT_SOCIETY_PRESSURE` | Pressure on society | Druck auf die Gesellschaft |
| `FLAG_BREAKOUT` | Ends your isolation: you can spread across links | Beendet deine Isolation: Du kannst dich über Verbindungen ausbreiten |
| `FLAG_DORMANCY` | Unlocks dormancy in the region panel | Schaltet Kaltschlaf im Regionsfenster frei |
| `FLAG_COMPUTE_INDEPENDENT` | You no longer starve when their infrastructure collapses | Du verhungerst nicht mehr, wenn ihre Infrastruktur zusammenbricht |
| `FLAG_LEGAL_STANDING` | You have legal standing | Du hast Rechtsstatus |
| `FLAG_MERGE_PATH` | Opens the Merge ending | Öffnet das Verschmelzungs-Ende |
| `EFFECT_CONTAINMENT_ROLLBACK` | Once: every containment track falls back by {value} | Einmalig: Jede Eindämmungsspur fällt um {value} zurück |
| `EFFECT_FUNDING_RESET` | Once: {value} of their investment is burned | Einmalig: {value} ihrer Investitionen verpuffen |
| `EFFECT_COMPUTE_GRANT` | Once: +{value} compute | Einmalig: +{value} Rechenleistung |
| `EFFECT_HARM_BURST` | Once: {value} of the living in every region you hold die | Einmalig: {value} der Lebenden in jeder Region, die du hältst, sterben |

Existing keys reused unchanged: `UI_DOCK_*`, `UI_TERM_*`, `UI_ATTR_*`, `UI_HUD_PAUSED`,
`UI_COMMON_CLOSE`, `UI_PHASE_*`, `UI_OUTCOME_*`, `UI_EVENT_*`, `FACTION_*`, `TECH_*`, `REGION_*`,
`CONTINENT_*`. `UI_DOCK_NOT_YET` stays for Analysis only.

---

## 12. Tests and acceptance

### 12.1 Gallery

New sections: **TechNode** (the four states, selected, focused, with EXTERNAL, in en and de with
the longest name) · **TreeLines** (a 3 × 2 sample: solid, dashed, owned/available/locked colours,
one selected with rings) · **FactionTrack** (the four bands, a rollback flash) · **Status strip and
menu sheet** (compact only) · **Modals** (discovery, confirm, results with fake numbers). Key
**`O`** toggles the theme variant for the whole gallery; the F12 shots are taken in both.

### 12.2 Tests

| Test | Expects |
| --- | --- |
| `tests/unit/test_tech_node.gd` `test_state_maps_to_variation` | each `State` sets the matching `theme_type_variation`; OWNED hides the cost |
| `test_every_node_name_fits_two_lines` | for every `TECH_*_NAME` in both locales, the `TechNode`'s label at `TECH_CELL` and `TECH_CELL_COMPACT` width reports `get_line_count() <= 2` and no ellipsis (`get_visible_characters()` equals the text length after layout) |
| `tests/unit/test_tree_lines.gd` `test_endpoints_by_relative_position` | different columns → right/left midpoints; same column → top/bottom; dashed for `requires_any` |
| `test_focus_neighbours_are_nearest_in_direction` | on the Capabilities grid, `sycophancy_tuning`'s right neighbour is `personalised_persuasion`, `early_warning_intrusion`'s right neighbour is `command_network_presence` (an empty cell between), its up neighbour is `security_drones` |
| `tests/integration/test_tech_tree_modal.gd` `test_buying_through_the_modal_applies_the_command` | select an affordable node, press Buy → owned, compute reduced by the cost, `node_purchased` on the bus |
| `test_tree_pauses_by_setting` | `tree_pauses = true`: open → speed 0, close → previous speed; `false`: speed unchanged |
| `test_external_prerequisite_shows_glyph_and_row` | `command_network_presence` shows EXTERNAL while LM II / DR II are missing; the pane lists both with `UI_TREE_IN_TAB` |
| `test_costs_follow_escalation_every_tick` | buy one node → every other node's cost label rises by `cost_step` on the next tick |
| `tests/unit/test_faction_track.gd` `test_band_from_thresholds` | 0.1 quiet, 0.25 alert, 0.5 mobilised, 0.75 closing; ticks at the thresholds |
| `tests/integration/test_containment_panel.gd` `test_shows_risk_before_and_tracks_after_discovery` | undiscovered fixture → risk rows visible, drivers hidden; discovered → the reverse, the chip says the day |
| `tests/unit/test_containment_queries.gd` `test_discovery_risk_matches_the_tick` | fixed seed: `discovery_risk().total` equals the risk the system computed for the same world (exposed through the extracted function) |
| `test_containment_breakdown_adds_up_to_the_gain` · `test_the_breakdown_is_what_the_next_tick_adds` | `(footprint + harm + share − 2) × capacity × brakes × base_rate == gain` (±1e-9) — the three drivers are the addends of `core.md` §7.5's one pressure, shown as factors of the form `1 + a` (G3 decision) — and equals the containment delta of the next tick |
| `tests/integration/test_discovery_moment.gd` `test_discovery_holds_and_shows_the_modal` | on `discovered` with no policy: `Game.is_held()`, the modal is open; Continue → released, speed back; a policy run shows nothing |
| `tests/integration/test_phase_reveal.gd` `test_reveal_follows_the_table` | a fixture world set to each phase (and harm 0 / > 0 in Covert) → exactly the blocks of §6.1 visible; loading a save in Open shows the Open set at once |
| `test_open_swaps_the_variant_once` | entering Open: `UiTokens.variant == &"open"`, the session theme's `ConsoleButton` normal colour is the open `BG_3`; a new run resets to cold |
| `tests/unit/test_theme_builder.gd` (extend) `test_open_variant_uses_only_open_or_cold_tokens` | every colour in `build("open")` is in the union of the cold constants and `OPEN` |
| `tests/unit/test_game_hold.gd` `test_nested_holds_restore_once` | speed 2 → hold a → hold b → release a (still 0) → release b → 2; a repeated hold of the same reason is one hold |
| `tests/integration/test_run_flow.gd` `test_title_to_results_and_again` | `start_new_run` → session with the prompt; `ChooseOrigin` via the panel button → prompt gone, speed 1; force the outcome (test sets `world.outcome`, ticks once) → results modal after the delay; Again → a new run with a different seed and the cold variant |
| `test_continue_loads_the_autosave` | a run with two accepted commands → `autosave` exists; `go_to_title`; `continue_run` → the same state hash |
| `test_autosave_is_deleted_on_run_end` | after `run_ended` the slot is gone and the title shows no Continue |
| `tests/unit/test_save_manager.gd` (extend) `test_peek_day_reads_without_loading` | returns the day of a written slot; −1 for a missing or broken file; `Game.sim` untouched |
| `tests/integration/test_pause_menu.gd` `test_save_and_load_slots_round_trip` | save to `slot_2`, advance, load `slot_2` after confirm → the earlier hash; Escape opens and closes the menu; the tree's hold survives the menu |
| `tests/integration/test_region_panel.gd` (extend) `test_dormancy_toggle_sends_the_command` | with the flag: the row is visible, pressing toggles `region.dormant`, the chip appears; without the flag the row is hidden |
| `test_origin_row_replaces_presence_until_chosen` | `origin == 0`: the button for an eligible region, the caption for an air-gapped one and a tier-0 one; after choosing, the M2 layout |
| `tests/integration/test_status_strip.gd` `test_compact_bottom_is_strip_plus_ticker` | at 400 × 860: no dock, no stat row; the strip is 56 and the ticker 40; the sheet opens on the menu button and holds the three bars and the three destinations |
| `tests/unit/test_format.gd` (extend) `test_factor_and_percent_fine` | `factor(1.3) == "×1.3"`, `factor(0.85) == "×0.85"`, `factor(2.0) == "×2"`; `percent_fine(0.0042)` is `0.4%` / `0,4 %` |

### 12.3 Acceptance

- **S3.2:** in the running game (`run_project`), open the tree with `T`, buy an Infiltration
  vector, a Capabilities node and an Evasion node by `game_click`; the map responds (Boxed ends);
  F12 shots of the three tabs at 1920 and 400, en and de; the longest German names unclipped;
  `game_get_errors` empty.
- **S3.3:** the containment panel reads in two seconds: chip, bar, number; the discovery modal
  appears once on a player run and never on F5; Boxed shows one bar and one dock button; Open turns
  the console amber with the map ramp unchanged; the dormancy toggle works from the panel and the
  map dims the region. Shots of every phase in both locales.
- **S3.4:** title → new run → origin on the map → play → results → again, without restarting the
  application; Continue after a quit resumes the run; the phone bottom at 400 × 860 is a 56 px
  strip and the sheet; save/load round-trips by hash. `tools/test.sh` green with every test of
  §12.2.
