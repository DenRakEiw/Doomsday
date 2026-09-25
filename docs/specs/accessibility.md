# Accessibility: screen reader, keyboard and controller, remapping, colour, captions, text size (D6.6)

**Status:** design, 2026-09-25 (D6.6). Build step: **S6.8** (after S6.1–S6.7, so the screen pass,
the icons, the audio service, the caption stack, the hints and the Codex's *How to play* tab
exist when it starts).
**Read with:** UI §5 · VISUALS §2 "Colour language" · `ui-foundation.md` §3–§4, §9 ·
`polish-visuals.md` §5–§6, §8.3 · `audio.md` §7–§8 · `first-run.md` §3, §6.
**Answers:** `audio.md` §8.4 (the caption stack and the screen reader; the *Sign* audit) · UI §5's
list (never colour alone, 150 % text, reduced motion, pause everywhere, no timed input, screen
reader) turned into rules a build can tick.

The inventory behind this spec was taken from the code on 2026-09-25 (every screen, modal, panel,
HUD block and map layer), and the new screens were looked at at 150 % text in German at 1920 and
400 px (title, setup, Codex, Statistics). Findings that need a fix are marked **Fix** and have a
test or a checklist line.

---

## 0. What this spec decides

1. **Screen reader: AccessKit through Godot's own `accessibility_*` properties**, engine setting
   left at *Auto* (active only while a screen reader runs). Every focusable control has a name;
   readouts a screen reader should reach get `FOCUS_ACCESSIBILITY`; a small **`LiveRegion`**
   component speaks the console line, the ticker (rate-limited, can be switched off), the opening
   of every modal, and the few alert sounds that have no text twin (§3).
2. **The map becomes keyboard- and controller-playable**: a focusable map with a **cursor**
   that steps from region to region with the arrow keys or the D-pad, `Enter` selects, a second
   `Enter` goes into the region panel, `Page Up`/`Page Down` jump to the next region that wants
   the player (§4.5). Without this, a run cannot be played without a pointer.
3. **One focus ring for the whole session** (`Tab`/`Shift+Tab`, the bumpers on a pad) across the
   HUD, the map and the open panels; the modal trap gets a reverse wrap and skips disabled
   buttons; panels opened from the keyboard take the focus and give it back (§4.3–§4.4).
4. **A visible focus ring everywhere**: the focus style moves **outside** the control (a 2 px
   `ACCENT` ring 4 px out), because on an accent-filled button the old inner border was invisible
   (seen on the title). §4.2.
5. **Key remapping: yes, for the keyboard**, in a small *Controls* modal from the settings — twelve
   actions, one key each, swap on conflict, reset. **The controller layout is fixed** (Steam Input
   remaps it on Steam; §5). Every hard-coded game key becomes an `InputMap` action.
6. **Colour:** every map state and chip audited under the three dichromacies (§6). All category
   pairs clear the ΔE floor of D6.1; **three fixes**: the resting Task Force red is too dark on
   land (`TASK_FORCE_DIM` → `#CC4040`), and two places carry state by colour alone (the tech tab's
   *something affordable*, a tech row's *missing assets*) — plus the counter-move card names its
   faction in words.
7. **Captions:** the caption stack is **not** a live region; instead seven alert cues whose only
   sign is visual get `"announce": true` in `data/audio.json` and are spoken to a screen reader
   whatever the caption setting (§7). The *Sign* column passes: every sound has a visible twin.
8. **Text size 150 %:** text-bearing maximum widths scale with the text size; three layout fixes
   found on the new screens (§8).
9. **Time:** the console line stands longer for longer lines and does not run out while the game
   is paused; *Reduced motion* starts on when the OS asks for it (§9).

---

## 1. Scope

**In:** screen-reader names, descriptions and live regions; keyboard and controller focus on every
screen, the map included; the input actions and remapping; the focus ring's look; the colour-vision
audit and its fixes; the caption audit and the spoken alerts; the 150 % rules and fixes; reading
time; strings; tests; the per-screen checklist; acceptance.

**Out:** a high-contrast theme (the palette already meets the floors of `ui-foundation.md` §3.1
and `polish-visuals.md` §8.4; `DisplayServer.accessibility_should_increase_contrast()` is not
read); a colour-blind *mode* (nothing needs one — §6); controller remapping in the game (§5.4);
screen-reader support on web and mobile (whatever the engine gives there, not a release
criterion); spoken map exploration beyond the cursor's line (the map is a spatial, real-time
view — the region panel and the containment panel are its text); touch accessibility (M7, D7.1);
the benchmark's spectator view (D6.9 gives it names by §3.2's rules).

| Step | Sections |
| --- | --- |
| **S6.8 Accessibility** | all of it; §10.2's revised strings are swapped in **by S6.8, together with the code that formats them** |

---

## 2. Files

| File | What |
| --- | --- |
| `project.godot` | an `[input]` section: the game actions of §5.1 and joypad events on `ui_accept`, `ui_cancel`, `ui_left/right/up/down`, `ui_page_up/down` (§4.1). `accessibility/general/accessibility_support` stays *Auto* (0), not written |
| `ui/components/live_region.gd` | **new**, `class_name LiveRegion` (§3.4) |
| `ui/components/live_queue.gd` | **new**, `class_name LiveQueue`, pure pacing rules (§3.4) |
| `ui/components/focus_ring.gd` | **new**, `class_name FocusRing`, pure: which control is next (§4.3) |
| `ui/components/key_names.gd` | **new**, `class_name KeyNames`: an action's key as text, `args()` for strings (§5.3) |
| `game/autoload/key_bindings.gd` | **new autoload** `KeyBindings` (after `Settings`): applies, assigns, swaps, resets (§5.2) |
| `game/map/map_nav.gd` | **new**, `class_name MapNav`, pure: step and jump (§4.5) |
| `game/map/map_focus.gd` | **new**, scene script of the focusable map (§4.5) |
| `game/map/marker_layer.gd` | draws the keyboard cursor (§4.5) |
| `game/map/map_camera.gd` | actions instead of key codes; arrows pan only when nothing or the map (with Shift) has focus (§4.5) |
| `ui/components/region_speech.gd` | **new**, `class_name RegionSpeech`: a region as one sentence (§3.5) |
| `ui/modals/controls.gd` + `.tscn` | **new** modal: the key list (§5.3) |
| `ui/modals/modal_host.gd` | reverse wrap, skip disabled, companions, the modal's spoken summary, `ui_cancel` (§4.4, §3.4) |
| `ui/components/slide_panel.gd` | `open(take_focus)`, focus return (§4.4) |
| `game/session/session.gd` | actions, the focus ring, keyboard mode, `F1`/`Escape` through actions, the `game_speed_cycle` and `game_menu` pad actions (§4) |
| `game/autoload/settings.gd` | `keys`, `announce_headlines`; *Reduced motion*'s first default from the OS (§5.2, §3.4, §9) |
| `ui/theme/ui_tokens.gd`, `ui/theme/theme_builder.gd` | `FOCUS_OUTSET`, the outer focus ring for every focusable type; `TASK_FORCE_DIM`; `text_width()` (§4.2, §6.3, §8.1) — rebuild `doomsday.tres` |
| `ui/hud/*`, `ui/panels/*`, `ui/modals/*`, `ui/screens/*`, `ui/components/*` | the names, focus modes and fixes of §3.3, §6.3, §8.2 |
| `data/audio.json`, `docs/specs/audio.md` §4.3 | the `announce` flag (done in D6.6) |
| `data/help.json` | the *controls* page has five paragraphs (done in D6.6) |
| `data/loc/strings.csv` | §10.1 (done in D6.6); §10.2's revisions by S6.8 |
| `tests/…` | §11 |

---

## 3. Screen reader

### 3.1 The engine

Godot 4.7 exposes the scene to the platform's accessibility API through AccessKit. The project
setting `accessibility/general/accessibility_support` stays at its default **Auto** — the tree is
built only while a screen reader runs, so nothing costs anything otherwise. Controls report their
role themselves (a `Button` is a button, a toggle reports *pressed*, a `ButtonGroup` a choice, a
`Label` static text, a `ScrollContainer` a scroll view, a disabled button *unavailable*). What the
game adds is names, descriptions, what is reachable, and what is announced.

Properties used (all on `Control`): `accessibility_name`, `accessibility_description`,
`accessibility_live` (`DisplayServer.LIVE_OFF / LIVE_POLITE / LIVE_ASSERTIVE`),
`accessibility_labeled_by_nodes`, and `focus_mode = FOCUS_ACCESSIBILITY` (focusable only while a
screen reader runs — for readouts that are not buttons). `DisplayServer.accessibility_screen_reader_active()`
tells whether one runs.

### 3.2 Rules for every control

1. **Every focusable control has a non-empty name** in the current language. A button's visible
   text is its name (the engine uses it) **unless** the text alone says nothing — then the name is
   set: an icon-only button → its tooltip (`IconButton` does this already); a settings value
   button (*On*, *85 %*) → `UI_A11Y_LABEL_VALUE` (`{label}: {value}`) with the row's label; a list
   row without text → the row's text.
2. **A tooltip that explains is a description**: every control whose `tooltip_text` adds to its
   name also gets `accessibility_description = tooltip_text` (ability buttons, dormancy, the
   pending chip, the threat bar). `ConsoleButton` and `IconButton` do it for all their instances.
3. **Names are refreshed on `NOTIFICATION_TRANSLATION_CHANGED`** and whenever the value they carry
   changes — the same place the visible text is set.
4. **Readouts that are not buttons** and that a player needs — top-bar cells, stat bars, chips
   that carry state, the region panel's figures — get `focus_mode = FOCUS_ACCESSIBILITY` and the
   name `UI_A11Y_LABEL_VALUE` (`{label}: {value}`), so the screen reader reaches them with its own
   navigation and `Tab` stays short for everyone else.
5. **Decoration is invisible to it**: the globe, the backdrop, glyph icons next to text, rings,
   the illustration slot, the reveal's scanline: no focus, no name (`GlyphIcon` and
   `IllustrationSlot` already have none).
6. **A modal's root** (`ModalPanel`) is named by its title; the body is spoken when the modal
   opens (§3.4 item 3).
7. **Uppercase is visual only**: names use the translated string as written, never the
   `to_upper()` copy (`ConsoleButton` does this already; `CapsLabel` must too).

### 3.3 Per component and screen

What is set beyond §3.2's defaults. "—" means the default is right.

| Where | Control | Name | Description / notes |
| --- | --- | --- | --- |
| **Components** | `ConsoleButton` with `.text` set in code (pause menu, statistics, results) | its text, or `{label}: {value}` for a settings row | — |
| | `IconButton` | tooltip (exists) | — |
| | `Chip` that carries state (phase, paused, starving, drift, dormant, status chips) | its text | `FOCUS_ACCESSIBILITY` |
| | `StatBar` | `{label}: {value}` (`UI_A11Y_LABEL_VALUE`, value as the bar shows it) | `FOCUS_ACCESSIBILITY`; the threat bar's tooltip is its description |
| | `ValueLabel` in a labelled row | `accessibility_labeled_by_nodes` = the row's label | the sign (▲/▼) is spoken as part of the text |
| | `TechNode` | `UI_TREE_NODE_A11Y` (exists) | the effect text the detail pane shows for it |
| | `ArchitectureCard` | `{name}. {tagline}` (exists); a locked card: `UI_A11Y_LOCKED` (`{name} — locked: {rule}`) | the detail pane's *what changes* text |
| | `LineChart` | title (exists) | cursor sentence (exists) + `UI_A11Y_CHART_DISCOVERED` (`Discovered on day {day}.`) when the run has a discovery day in range |
| | `TimelineStrip` | `UI_A11Y_TIMELINE` | slot tip (exists) |
| | `AttributePips` | exists | — |
| **Boot** | the screen | — | on start, `LiveRegion.say(UI_A11Y_BOOT_SKIP)` (*Press any key to skip.*) once |
| **Title** | buttons | text | the title's `LiveRegion` says the game's name and tagline once, on the first show |
| **Setup** | difficulty, scenario, directive toggles | text | their caption (what the option does) |
| **Session – top bar** | compute, phase, day, asset readout | `{label}: {value}` | `FOCUS_ACCESSIBILITY`; the compute cell's value includes the rate as shown |
| | pending (**Fix**: becomes a `Button`, §4.6) | its text | its tooltip |
| | speed group | tooltips (exist) | pressed state is the current speed |
| **HUD** | overlay picker | text | the map view it shows |
| | dock | text | the containment button: its chip (`{label}: {value}`) |
| | console line | `UI_A11Y_CONSOLE` | speaks through its `LiveRegion` (§3.4) |
| | ticker | `UI_A11Y_TICKER` | speaks through its `LiveRegion` (§3.4) |
| | coach card | its title | body as description; hints the same |
| | site prompt | title | detail as description |
| **Map** | `MapFocus` | `UI_A11Y_MAP` | `UI_A11Y_MAP_HELP`; the cursor's region is spoken (§4.5) |
| **Panels** | region panel | the region's name | figures `FOCUS_ACCESSIBILITY` with `{label}: {value}`; the event card's options: their text, lock reason as description |
| | containment panel | title | each faction track: `{faction}: {value}, {band}` via `UI_A11Y_TRACK` |
| | tech tree tabs | **Fix**: `UI_A11Y_TREE_TAB` (`{tab}, {owned} of {total}`) or `UI_A11Y_TREE_TAB_AFFORDABLE` (`…, something affordable`) | — |
| | analysis log rows that name a region (**Fix**: no text today) | the row's text | — |
| | tech detail prerequisite rows | exists | — |
| **Modals** | every modal | title (§3.2 item 6) | spoken summary on open (§3.4) |
| | pause menu slots | `{slot}: {caption}` via `UI_A11Y_LABEL_VALUE` | an empty slot's load button is disabled — the reader says so |
| | wire card, discovery, confirm | — | summary = title + body |
| | controls (new) | row buttons `{action}: {key}` | §5.3 |
| | Codex list rows | text; a locked row *Not yet encountered* is disabled | — |

### 3.4 Live regions and what is spoken

**`LiveRegion`** (`ui/components/live_region.gd`, `class_name LiveRegion`, `extends Label`):

```gdscript
class_name LiveRegion
extends Label
@export var assertive: bool = false
## Speaks `text` once. Nothing while no screen reader runs (unless `force_active`, for tests).
func say(text: String) -> void
var force_active: bool = false
```

- It is a real, visible `Label` so the platform sees it: `custom_minimum_size` 1 × 1, `clip_text`,
  `mouse_filter = IGNORE`, `focus_mode = FOCUS_NONE`, `self_modulate.a = 0` (drawn transparent —
  a hidden node is dropped from the accessibility tree). It must **never sit inside a parent that
  can be hidden** (the caption stack, a closed panel); it is placed as a child of a plain
  `Control` that is always visible, outside containers (it has no layout).
- `accessibility_live` = `LIVE_ASSERTIVE` if `assertive` else `LIVE_POLITE`.
- `say(text)`: if no reader runs and not `force_active` → nothing. Else set `self.text = text`;
  when `text` equals the current text, a trailing U+00A0 is appended or removed (alternately) so
  the platform sees a change. Then `queue_accessibility_update()`.

**`LiveQueue`** (`ui/components/live_queue.gd`, `class_name LiveQueue`, `extends RefCounted`,
pure; the owner calls `pop_due(now_ms)` from `_process`):

```gdscript
class_name LiveQueue
extends RefCounted
func _init(min_gap_ms: int) -> void
func push(text: String, now_ms: int) -> void      # keeps only the newest waiting text
func pop_due(now_ms: int) -> String               # "" when nothing is due
```

At most one text is spoken per `min_gap_ms`; a text pushed during the gap replaces any text still
waiting (the newest wins, older ones are dropped silently); with the gap over, a push is due at
once.

**What is spoken where** (one `LiveRegion` each; the constants in one `const` block of the owner):

| Owner | Live | Speaks | Pacing |
| --- | --- | --- | --- |
| `ConsoleLine` | polite | every line **when it is shown** (not when queued) | the line's own pacing |
| `Ticker` | polite | every headline item **when it is enqueued** (`HeadlineText.render`), never the idle line or a bot banner; only while `Settings.announce_headlines` | `LiveQueue` with `TICKER_LIVE_GAP_MS` 8000 |
| `Hud` (a child of the HUD root, not of the caption stack) | polite | the caption text of a cue with `"announce": true` (§7.2) on `EventBus.caption_pushed`, **whatever `Settings.sound_captions` says** | `LiveQueue` with `ANNOUNCE_GAP_MS` 1500 |
| `ModalHost` (each host: title and session) | **assertive** | on `open` / `open_over`: the modal's `a11y_summary() -> String` if it has the method, else its title; `UI_A11Y_DIALOG` (`{title}. {body}`) | none |
| `MapFocus` | polite | the cursor's `RegionSpeech.line` on every step (§4.5) | `LiveQueue` with `CURSOR_LIVE_GAP_MS` 250 (holding an arrow speaks the last region) |
| `Controls` modal | polite | the swap note (§5.3) | none |
| `Boot`, `Title` | polite | §3.3 | none |

`a11y_summary()` is added to the wire card, the discovery modal, the confirm modal (the question)
and the results screen (the ending's title and first line); others speak their title.

**New setting `announce_headlines: bool`**, default `true`, key `"announce_headlines"` in
`settings.json` (version stays 1; a missing key falls back). `Settings.set_announce_headlines(enabled)`.
Settings row `UI_SETTINGS_READ_HEADLINES` (*On* / *Off*) directly after `UI_SETTINGS_AUDIO_BACKGROUND`
(or after `UI_SETTINGS_SOUND_CAPTIONS` where that row is hidden), on the title's settings and in
the pause menu alike. Shown on every platform (a player turns it off before a reader bothers
them).

### 3.5 `RegionSpeech`

```gdscript
class_name RegionSpeech
extends RefCounted
## One sentence about a region, in the current language, for the map cursor.
static func line(world: World, index: int, site: SiteRequest) -> String
```

Parts, each a sentence, joined with a space, in this order; a part that does not apply is left out:

1. `UI_A11Y_REGION_NAME` — `{region}.`
2. presence: dark → `UI_A11Y_PRESENCE_DARK`; not reached → `UI_A11Y_PRESENCE_NONE`; reached, no
   control → `UI_A11Y_PRESENCE_REACHED` (`{penetration}` as `Format` percent); with control →
   `UI_A11Y_PRESENCE_CONTROLLED` (`{penetration}`, `{control}`).
3. dormant → `UI_A11Y_DORMANT`.
4. site select open (`site` not null): the site prompt's own hover line for the region — eligible
   → **`UI_SITE_HOVER_OK_KEY`** (§4.5), closed → `UI_SITE_HOVER_CLOSED` with its reason.
5. the player's assets there → `UI_A11Y_ASSETS` (`{list}`), items `UI_A11Y_ASSET_ITEM`
   (`{count} × {kind}`, `kind` = `TechText.asset_name(kind, count)`), joined with `", "`.
6. active statuses → `UI_A11Y_STATUSES` (`{list}`, the statuses' names as the region panel shows
   them, joined with `", "`).
7. an open event → `UI_A11Y_EVENT` (`{title}` = `EventView.title`); more than one → the first,
   in the region panel's order.
8. an anomaly → `UI_A11Y_ANOMALY`.
9. the Task Force stands there → `UI_A11Y_TASK_FORCE`.

Test with a fixture world (§11).

---

## 4. Keyboard and controller

### 4.1 Input events

Built-in `ui_*` actions get **joypad events** in `project.godot` (in 4.7 they have none by
default): `ui_accept` + A (`JOY_BUTTON_A`); `ui_cancel` + B; `ui_left/right/up/down` + the D-pad
buttons and the left stick (axis 0/1, deadzone 0.5); `ui_page_up/down` — none (the pad has no
use for them). The game's own actions are §5.1. **Every `KEY_ESCAPE` check becomes
`is_action_pressed(&"ui_cancel")`** (session, `ModalHost`, setup already does), so B works as
back everywhere.

`ui_accept` also holds `Space`. In the session `Space` is pause (the session's `_input` runs
first and consumes it), so focused buttons there activate with `Enter`/A — as today. Outside the
session `Space` activates. If the player remaps pause away from `Space`, `Space` activates in
the session too.

**Keyboard mode.** `session.gd` keeps `var keyboard_mode: bool`: set true by any `InputEventKey`
press, `InputEventJoypadButton` press or `InputEventJoypadMotion` past 0.5; false by any
`InputEventMouseButton` press or `InputEventScreenTouch`. It decides whether a panel takes the
focus when it opens (§4.4), whether the map cursor shows (§4.5), and which site-prompt line is
used (§4.5). Godot's own `gui/common/show_focus_state_on_pointer_event` stays at its default
(*Text Input Controls*): a click does not show a focus ring on a button.

### 4.2 The focus ring (**Fix**)

Today the focus style is a 2 px `ACCENT` border **inside** the control. On `ConsoleButtonPrimary`,
a toggled button and a selected architecture card the fill or border is already `ACCENT`, so
focus is invisible there (seen on the title's *New run*).

- New token `FOCUS_OUTSET: int = 4`.
- The focus `StyleBoxFlat` of **every** focusable type (`ConsoleButton*`, `IconButton`,
  `TechNode*`, `ArchitectureCard`, `ChartFrame`, the new `ChipButton` and `MapFocus`'s frame):
  `draw_center = false`, border `BORDER_FOCUS` (2) in `ACCENT`, **`expand_margin_* = FOCUS_OUTSET`**,
  corner radius the type's radius + `FOCUS_OUTSET`. The ring sits outside with a 2 px gap of
  whatever is behind — visible on a filled button, on a toggled one, on any surface. Contrast:
  `ACCENT` on `BG_0…BG_3` ≥ 10 : 1, open accent ≥ 11 : 1 (WCAG 2.4.13's 3 : 1 change is met).
- **Every `ScrollContainer` that holds focusable controls** gets `follow_focus = true`, and its
  content a `MarginContainer` of `FOCUS_OUTSET` on every side, so a ring is neither clipped nor
  scrolled out of view (pause menu, Codex list, statistics, credits, controls, ability picker,
  region panel, analysis log, tech board, setup's card list).
- Separations between focusable siblings are ≥ `SPACE_2` (8) — already so everywhere; a new
  layout must keep it, or two rings would touch.

### 4.3 The session's focus ring (`FocusRing`)

```gdscript
class_name FocusRing
extends RefCounted
## The controls `Tab` walks, in order: every descendant of each root, in tree order, that is
## visible in the tree, has focus_mode FOCUS_ALL and is not a disabled BaseButton.
static func collect(roots: Array[Control]) -> Array[Control]
## The next (or previous) control after `current`, wrapping; `current` not in the list → the
## first (or last). Empty list → null.
static func next(chain: Array[Control], current: Control, backwards: bool) -> Control
```

Godot's own `Tab` does not cross `CanvasLayer`s (each layer's controls wrap among themselves),
so the session walks the ring itself: in `_input`, while **no modal is open**, `ui_focus_next` /
`ui_focus_prev` (and the pad's `game_focus_next` / `game_focus_prev`, §5.1) are consumed and
`FocusRing.next(FocusRing.collect(zones), owner, backwards).grab_focus()` is called. Zones, in
this order (a hidden one contributes nothing):

| # | Zone | Holds |
| --- | --- | --- |
| 1 | top bar | pending button, speed group, menu button (full layout) |
| 2 | left column | overlay picker, coach card (*Next*/*More*/*Skip*, hints' buttons) |
| 3 | dock (full) / status strip (compact) | dock buttons / strip buttons and menu |
| 4 | map | `MapFocus` |
| 5 | site prompt | collapse, cancel |
| 6 | region panel | in tree order |
| 7 | containment panel, analysis panel, menu sheet | whichever is open, in this order |

Arrow keys inside a zone keep Godot's geometric neighbours (a row of buttons, the tech board's
explicit ones). **Initial focus:** when the origin prompt first shows → `MapFocus`; when the
session starts without one (a loaded game) → nothing until the first `Tab` (which lands on zone 1)
or the first arrow key (which focuses `MapFocus`).

### 4.4 Modals and panels (**Fixes**)

**`ModalHost`:**
1. The trap uses `FocusRing`: `Tab` past the last goes to the first, **`Shift+Tab` before the
   first goes to the last** (today it snaps back to the first).
2. `_focus_first()` skips disabled buttons (today the ability picker can open on a disabled
   ability).
3. **Companions:** `var companions: Array[Control]`; their focusable controls join the modal's
   chain after the modal's own. The session adds the coach card, so a hint or step that points
   into the tech tree can be read and dismissed without leaving it. The host's `gui_focus_changed`
   guard treats a companion as inside.
4. `Escape`/B through `ui_cancel` (§4.1).
5. **The pause menu's confirm dialog:** `pause_menu.on_escape()` answers the confirm with
   *Cancel* when it is showing, and only otherwise closes the menu (today `Escape` in the reset
   confirm closes the whole menu).

**`SlidePanel.open(take_focus: bool = false)`**: with `take_focus`, it remembers the current
focus owner and, after the open, grabs the panel's `primary_focus()` (a new virtual on the
panel's script; default: the first control of `FocusRing.collect([panel])`). On `close()`, if the
focus was inside the panel, it goes back to the remembered owner when that is still in the tree
and visible, else to `MapFocus`. The session passes `take_focus = keyboard_mode` for every open
(the `T`/`C`/`G` keys, the dock buttons, `Enter` on the map).

`primary_focus()` per panel: **region panel** — the site button when visible and enabled, else
the first enabled action (collect, event option, ability, dormancy), else close; **containment**
— close (the panel is read, not operated; its tracks are `FOCUS_ACCESSIBILITY`); **analysis** —
the current tab (as now); **menu sheet** — its first destination.

### 4.5 The map: cursor, step, jump

**`MapFocus`** (`game/map/map_focus.gd`, scene script, a `Control`): full rect, the **first
child of `HudLayer`** (behind `SafeArea`, so every HUD control lies above it),
`mouse_filter = IGNORE` (the map keeps every pointer event), `focus_mode = FOCUS_ALL`, name
`UI_A11Y_MAP`, description `UI_A11Y_MAP_HELP`. Its focus style is the §4.2 ring drawn inset by
`GUTTER` around the map's visible area — a frame that says "the map has the keys".

**The cursor** (`var cursor: int`, a region index, 0 = none): shown as a reticle by
`MarkerLayer` — four `ACCENT` corner brackets, 2 px, around the region's anchor at
`CURSOR_RADIUS` 18 px screen size, and the region's name in a `TYPE_CAPTION` label on a `BG_2`
plate below it (the `MapTooltip` style). Visible only while `MapFocus` has focus **and**
`keyboard_mode`. Moving the cursor also emits `EventBus.region_hovered(cursor)`, so the hover
highlight and the site prompt's line follow it exactly as for a mouse.

Keys while `MapFocus` has focus (all through actions, so the pad works the same):

| Action | Does |
| --- | --- |
| `ui_left/right/up/down` | `cursor = MapNav.step(cursor, dir, anchors, regions)`; unchanged when it returns −1; the camera pans to keep the cursor's anchor inside the middle 60 % of the view (`MapCamera.focus_region(cursor)` when it leaves it; reduced motion → the camera's own rule) |
| `ui_accept` | the cursor region ≠ the selected region → `EventBus.region_selected.emit(cursor)` (the panel opens, `take_focus` false — the player keeps browsing); **equal** → the region panel's `primary_focus()` takes the focus |
| `ui_page_down` / `ui_page_up` | `cursor = MapNav.jump(cursor, forward, wanted)` |
| `game_focus_region` | as today (`F`) |
| Shift + arrows | pan the camera (the arrows' old meaning) |

`MapNav` (`game/map/map_nav.gd`, `class_name MapNav`, pure, static):

```gdscript
class_name MapNav
extends RefCounted
## The region the cursor moves to from `from` in direction `dir` (a unit vector, y down), or -1.
static func step(from: int, dir: Vector2, anchors: PackedVector2Array, regions: PackedInt32Array) -> int
## The next (or previous) index in `wanted` after `from`, in ascending index order, wrapping; -1 when empty.
static func jump(from: int, forward: bool, wanted: PackedInt32Array) -> int
```

`step`: for each candidate `r ≠ from` in `regions` with `v = anchors[r] − anchors[from]`,
`along = v · dir`, `across = |v × dir|`: skip unless `along > 0` and `across ≤ along × STEP_CONE`
(`STEP_CONE` = 1.732, a 60° half-angle); score `along + STEP_ACROSS_WEIGHT × across`
(`STEP_ACROSS_WEIGHT` = 2.0); the lowest score wins, a tie goes to the lower index. No
candidate → −1. `from` = 0 (no cursor yet) → the region nearest the camera's centre is the first
cursor, before any step. The map does not wrap east–west. Constants in one `const` block of
`MapNav` (presentation constants, not balance).

`wanted` for `jump` (built by `MapFocus` from the world, in ascending index): regions with an open
event, an anomaly, or — while site select is open — eligible for the request. `regions` for
`step` = every land region (index ≥ 1), dark ones included.

**Speech:** every cursor change pushes `RegionSpeech.line(world, cursor, site_request)` into
`MapFocus`'s `LiveQueue` (§3.4). A `jump` with nothing wanted speaks `UI_A11Y_MAP_NOTHING`.

**Site prompt in keyboard mode:** its hover line for an eligible region uses the new
`UI_SITE_HOVER_OK_KEY` (*press Enter*) instead of `UI_SITE_HOVER_OK` (*tap it*); on a pad the
same line (A is `ui_accept`; the help page says so).

**Arrow panning (`MapCamera`):** today it polls the arrow keys every frame whatever has focus, so
moving through a menu with the arrows also moves the map. From S6.8 the arrows pan only when **no
control has focus**, or when `MapFocus` has it **and Shift is held**. The right stick pans always
(`JOY_AXIS_RIGHT_X/Y`, deadzone 0.2, speed as the arrow pan); the triggers zoom (§5.1).

### 4.6 Controls that could not be reached (**Fixes**)

| Where | Today | From S6.8 |
| --- | --- | --- |
| top bar pending chip | a `Chip` with a left-click handler | a `Button`, new type variation **`ChipButton`** (the `ChipAlert` look, the §4.2 focus ring), same text and tooltip; `pressed` opens the waiting wire card |
| analysis log rows naming a region | a button without text or name | name = the row's text |
| timeline strip | focusable, no name | `UI_A11Y_TIMELINE` |
| coach card inside a modal | unreachable (the trap) | a `ModalHost` companion (§4.4) |
| the map | pointer only | §4.5 |
| confirm in the pause menu | `Escape` closes the menu | §4.4 item 5 |

### 4.7 The controller

| Pad | Does | Through |
| --- | --- | --- |
| D-pad, left stick | move focus; on the map, step the cursor | `ui_*` |
| A | activate; on the map, select / enter the panel | `ui_accept` |
| B | back: close the modal or panel, cancel site select, open the pause menu (the `Escape` chain) | `ui_cancel` |
| X | pause / resume | `game_pause` |
| Y | speed up: paused → 1×, 1× → 2× → 4× → 1× | `game_speed_cycle` |
| LB / RB | previous / next in the focus ring | `game_focus_prev` / `_next` |
| LT / RT | zoom out / in | `game_zoom_out` / `_in` |
| right stick | pan | `MapCamera` |
| R3 | centre the selected region | `game_focus_region` |
| Start | pause menu (also closes it) | `game_menu` |
| Back / View | *How to play* for what is open | `game_help` |

The tech tree, containment, analysis and abilities have no pad button of their own — the dock
(or the phone's menu button) is one bumper press away. The boot is skipped by any button (it is
already).

---

## 5. Key remapping

### 5.1 The actions (`project.godot` `[input]`)

| Action | Key (default) | Pad | Remappable | Replaces |
| --- | --- | --- | --- | --- |
| `game_pause` | `Space` | X | yes | session `KEY_SPACE` |
| `game_speed_1` · `_2` · `_3` | `1` · `2` · `3` | — | yes | `KEY_1…3` |
| `game_speed_cycle` | — | Y | no | new |
| `game_tree` | `T` | — | yes | `KEY_T` |
| `game_containment` | `C` | — | yes | `KEY_C` |
| `game_analysis` | `G` | — | yes | `KEY_G` |
| `game_abilities` | `A` | — | yes | `KEY_A` |
| `game_help` | `F1` | Back | yes | `F1` (S6.7) |
| `game_zoom_in` | `=` (+ fixed `KP +`) | RT | yes (the first key) | `MapCamera` |
| `game_zoom_out` | `-` (+ fixed `KP −`) | LT | yes (the first key) | `MapCamera` |
| `game_focus_region` | `F` | R3 | yes | `KEY_F` |
| `game_menu` | — (`Escape` is `ui_cancel`) | Start | no | new |
| `game_focus_next` / `_prev` | — (`Tab` is `ui_focus_next/prev`) | RB / LB | no | new |

Keys are **physical** keycodes (`InputEventKey.physical_keycode`), so the default layout is the
same place on a German and an English keyboard; what the key *says* is shown through the
keyboard's own label (§5.3). The debug keys (`F5`–`F11`, `L`, `K`, `M`, `V`, `F12`) stay raw key
checks in debug builds and are out of the table (D6.8 takes them out of release builds).

### 5.2 `KeyBindings` (autoload) and the setting

`Settings.keys: Dictionary[String, int]` — action → physical keycode, **only the overrides**; key
`"keys"` in `settings.json` (version stays 1). Invalid entries (unknown action, not
remappable, not an int, a reserved key) are dropped on load; a missing key reads `{}`.

```gdscript
# game/autoload/key_bindings.gd — autoload `KeyBindings`, registered after `Settings`
const REMAPPABLE: Array[StringName] = [...]   # §5.1's "yes" rows, in that order
const RESERVED: Array[Key] = [KEY_ESCAPE, KEY_TAB, KEY_ENTER, KEY_KP_ENTER, KEY_UP, KEY_DOWN,
	KEY_LEFT, KEY_RIGHT, KEY_PAGEUP, KEY_PAGEDOWN, KEY_HOME, KEY_END, KEY_SHIFT, KEY_CTRL,
	KEY_ALT, KEY_META, KEY_CAPSLOCK, KEY_F12]
func apply_all() -> void                              # at start: defaults, then the overrides
func key_of(action: StringName) -> Key                # the action's remappable (first) key
func can_bind(physical: Key) -> bool                  # not reserved; in debug builds not a debug key
## Binds `physical` to `action`. Returns the action that had it (now given `action`'s old key),
## or &"" when none had it. Writes the setting. Refuses (returns &"" and changes nothing) when
## `can_bind` is false or `action` is not remappable.
func assign(action: StringName, physical: Key) -> StringName
func reset() -> void                                  # overrides cleared, defaults applied, written
```

`assign` changes only the action's first key event (the fixed keypad aliases and the pad events
stay). An override equal to the default is not stored.

### 5.3 The *Controls* modal (`ui/modals/controls.tscn` + `controls.gd`)

Opened from a new settings row **`UI_SETTINGS_CONTROLS`** (button `UI_SETTINGS_CONTROLS_OPEN`,
*Change*), the last settings row before *Reset progress*, in the pause menu and on the title's
settings — **hidden when `OS.has_feature("mobile")`**. It opens with `ModalHost.open_over`
(first-run §6.8's one level of stacking: the Codex and the Controls modal are its two callers).

Layout (`ModalPanel`, `ScrollContainer` per §4.2): header `LabelDisplay` `UI_CONTROLS_TITLE` +
close; one row per `KeyBindings.REMAPPABLE` action: a `Label` with the action's name (§10.1,
expands) and a `ConsoleButton` showing `KeyNames.label(action)` (name `{action}: {key}`); under
the rows a caption `UI_CONTROLS_NOTE`; a status line (`LabelCaption`, empty at rest); a
`ConsoleButton` `UI_CONTROLS_RESET`.

**Capturing:** pressing a row's button sets it to `UI_CONTROLS_PRESS` (*Press a key — Esc
cancels*) and the modal captures the next `InputEventKey` press (not echo, not a lone modifier)
in `_input`, consuming it:
- `Escape` → cancel, the button shows the key again. (`on_escape()` cancels a capture when one
  is running, and only otherwise closes the modal.)
- `can_bind` false → the status line `UI_CONTROLS_RESERVED` (`{key} is kept by the game.`); the
  capture stays open.
- else `KeyBindings.assign`; if it returned an action, the status line (and the `LiveRegion`)
  says `UI_CONTROLS_SWAPPED` (`{key} moved from {other}; {other} is now {old}.`). All buttons
  refresh.
There is **no time limit** on a capture. Mouse buttons and pad buttons are not captured.

**`KeyNames`** (`ui/components/key_names.gd`, `class_name KeyNames`, static):
`label(action: StringName) -> String` — the action's first key: `Space`, `Escape`, `Enter`,
`Tab`, `Backspace` through `UI_KEY_*` (§10.1), anything else
`OS.get_keycode_string(DisplayServer.keyboard_get_label_from_physical(physical))`.
`args() -> Dictionary` — `{"key_pause": …, "key_speed_1": …, "key_speed_2": …, "key_speed_3": …,
"key_tree": …, "key_containment": …, "key_analysis": …, "key_abilities": …, "key_help": …,
"key_zoom_in": …, "key_zoom_out": …, "key_focus_region": …}`.

**Every text that names a remappable key** is formatted with `KeyNames.args()` — §10.2 lists
them (help pages, coach steps, the help button's tooltip). The renderers (`HelpPages`'s page
view, the coach, `IconButton` tooltips from the string table) format with it; a string without
placeholders is unaffected.

### 5.4 Why the controller is not remapped in the game

On Steam (the first platform, and the Steam Deck) **Steam Input** remaps every pad button for
every game, per player, with community layouts — a second remapper inside the game would fight
it. Elsewhere the fixed layout of §4.7 follows the platform's convention (A accept, B back,
Start menu). Revisit at M7 if a platform without such a layer needs it.

---

## 6. Colour vision

### 6.1 Method

Every pair of colours that can appear **in the same channel** (a ring, a border, a marker, a
line, a chip, an overlay step) was compared with CIEDE2000 over normal vision and the three
simulated dichromacies (Machado 2009, severity 1.0) — the method and floor of `polish-visuals.md`
§8.3 (worst case ≥ 9). The magnitude overlays were checked for **monotone lightness** (L\*) under
all four, over both land colours. Non-text marks were checked for WCAG 1.4.11's 3 : 1 against the
ground they sit on; chip text for 4.5 : 1. The script was a throwaway in the D6.6 scratch
directory; S6.2's colour-floor test (`polish-visuals.md` §11) gets the new pairs below.

### 6.2 Results

**Categories (worst-case ΔE₀₀, all ≥ 9):**

| Pair | worst | Pair | worst |
| --- | --- | --- | --- |
| AI Labs / Governments (sky / orange) | 50.5 | Governments / Researchers | 17.9 |
| AI Labs / Researchers (sky / green) | 12.1 | Governments / Public (orange / pink) | 10.9 |
| AI Labs / Public (sky / pink) | 14.0 | Researchers / Public | 15.9 |
| Task Force / AI Labs | 46.7 | Task Force / Researchers | 15.1 |
| Task Force / Governments | 9.8 | Task Force / Public | 17.6 |
| `ACCENT` / `TEXT_0` (◇ opening vs » chain marker) | 9.3 | `ACCENT` / `MAP_SELECT` (site outline vs selection) | 14.9 (open 21.1) |
| `MAP_SOCIETY` / Public pink | 17.9 | open `ACCENT` / `MAP_SOCIETY` | 21.5 |

(`ACCENT` against the factions and the Task Force: `polish-visuals.md` §8.3.)

**Magnitude:** the penetration/control ramp at `MAP_OVERLAY_MIX` over `MAP_LAND` rises in L\*
14 → 42 → 52 → 58 → 64 → 70 (normal); 15 → 68 (protan), 14 → 70 (deutan), 14 → 69 (tritan) —
**monotone under all four**, both palettes. The top two stops come close for protans (ΔE 3.9);
the exact figure is always in the region panel. The population overlay (land → `MAP_DEATH`) is
monotone too (L\* 14 → 35 → 54). The society overlay is stepped and its stage is a number in the
panel.

**Where each channel's second signal is** (UI §5: never colour alone):

| Channel | Colour carries | Second signal |
| --- | --- | --- |
| overlay (ramp, population, society) | magnitude | lightness (monotone), the region panel's value, the cursor's spoken line |
| status rings / border rule | whose status | the innermost ring's letter code; the region panel's status rows with source text |
| event markers | faction of a counter-move | the marker's shape per kind (`!` ◇ » spark); the console line and the card name the faction (**Fix** §6.3) |
| Task Force | the team; setting up vs. resting | the badge's letters; the countdown ring while it sets up |
| links | reach vs. closed | the dash pattern per kind; a closed link's gap and cross |
| dark region | no one left | the × mark; panel text |
| site select | eligible | outline + the prompt's line (closed ones say why) |
| selection | selected | white outline + the panel opens |
| chips | state | always text |
| value deltas | up / down | ▲ ▼ ± and the sign |
| threat bar | leading faction | the faction glyph and name |
| charts | series | legend names, the cursor sentence, the *Table* view |
| timeline strip | mark kind | glyph shape; tip and description |

### 6.3 Fixes

1. **`TASK_FORCE_DIM` `#C23A3A` → `#CC4040`** (cold set; the team's red is not in the open set).
   On `MAP_LAND` it was 2.9 : 1 — under WCAG 1.4.11's 3 : 1 for the resting badge's border and the
   team's road; now 3.2 : 1 (3.4 on the open land). Still clear of the factions (worst ΔE 14.1,
   Researchers) and still dimmer than `TASK_FORCE` (the ring, not the shade, says *setting up*).
2. **The tech tree's tab chip** turns `ACCENT` when something in that tree is affordable, with the
   same text. From S6.8 its text is `UI_TREE_TAB_COUNT_AFFORDABLE` (`{owned} / {total} ●`) in that
   state (U+25CF; S6.8 checks `Font.has_char` on JetBrains Mono as for ▲, fallback `*`), and the
   tab's name says so (§3.3).
3. **A tech's *Needs assets* row** turns `ALERT` when the assets are missing, same text. From S6.8
   a missing row reads `UI_TREE_REQUIRES_ASSETS_MISSING` (`Needs {count} × {kind} — missing`).
4. **A counter-move's event card** has the faction's border colour and a dateline that names only
   the kind. From S6.8 the dateline is `UI_EVENT_DATELINE_FACTION` (`{kind} · {faction}`,
   `faction` = `FACTION_<ID>`) whenever the event has a faction.
5. **A locked architecture card's unlock rule is essential text**: it must be `TEXT_1` or brighter
   (≥ 4.5 : 1), never `TEXT_2`; the card's lock is also in its name (§3.3). (S6.8 checks; if it is
   already `TEXT_1` under the card's dimming, nothing changes.)

Accepted as they are, with the reason: the tech board's edge colours (the detail pane lists every
requirement in words); the charts' unlabelled threshold hairlines (the *Table* view and the
legend carry the values); `ACCENT_DIM` on a resting link (2.7 : 1 on land, 3.3 on ocean — *at
rest* is the absence of flow, and the link's pattern is still there); the hover gain (transient;
the cursor and the tooltip name the region).

---

## 7. Captions and sound

### 7.1 The *Sign* audit (`audio.md` §7)

Every one of the 20 interface cues has its control, panel or console line as the sign; every one
of the 34 alert cues with a caption has a visible sign on screen or in the console; `map_seed` and
`map_control` (no caption) are the region's own fill. **The audit passes: no sound carries
information alone.** A deaf player loses nothing with captions off; captions add *where* and
*who* for signs that are off-screen when zoomed in.

### 7.2 What a screen reader hears (`audio.md` §8.4)

The caption stack stays **visual only** (not a live region): most captions duplicate a console
line, which is spoken already (§3.4), and speaking both would say everything twice. The cues whose
sign is **only visual** — a chip, a bar, a map mark — get **`"announce": true`** in
`data/audio.json` (done in D6.6; `audio.md` §4.3 has the field): their caption is spoken through
the HUD's `LiveRegion` whenever a screen reader runs, whether *Sound captions* is on or off.

| Cue | Why it is announced |
| --- | --- |
| `phase_covert`, `phase_emergent`, `phase_open` | the phase chip and the reveal are the only sign |
| `alert_threshold` | the threat bar only |
| `alert_depopulated` | the region going dark only |
| `tf_level` | the Task Force row only |
| `tf_targeted` | the target line on the map only |

`Audio` emits `caption_pushed` for an admitted cue whatever the volume (audio.md §5.3); the HUD
speaks it when the cue's `announce` is true. **`AudioSheet`** (S6.5) loads the field as
`CueDef.announce: bool` (default false; `alerts` only, and only with a caption — the validator
says so).

---

## 8. Text size 150 %

### 8.1 Widths that scale with the text (**Fix**)

Text-bearing maximum widths were fixed pixels, so at 150 % the same box holds two-thirds of the
words. New helper `UiTokens.text_width(px: float) -> float` = `px × Settings.text_scale`. Every
maximum width below goes through it and is **then** capped by the viewport (`view − 2 × GUTTER`),
as each already is:

| Width | Where |
| --- | --- |
| `MODAL_MAX_WIDTH` 560, `WIRE_MAX_WIDTH` 840 | `ModalPanel` |
| coach `MAX_WIDTH` 440 | `coach.gd` |
| `CAPTION_MAX_WIDTH` 280 | the caption stack |
| `SlidePanel` side width `clamp(0.3 × view, 360, 480)` | the bounds scale; the panel never exceeds 0.45 × view |
| `CELL_MIN_WIDTH` 200, `DOCK_BUTTON_WIDTH` 200 | top bar cells, dock |

The theme rebuild on `text_scale_changed` already re-lays everything; the components read
`text_width` where they read the constant today.

### 8.2 What the 150 % look found on the new screens

Looked at 2026-09-25, German, 1920 × 1080 and 400 × 860:

| Screen | Found | Rule |
| --- | --- | --- |
| **Statistics** (desktop) | *By architecture*: the name column broke **inside the word** (*Spr·ach·mod·ell*), squeezed by the three caps headers | the name cell **does not wrap** (`AUTOWRAP_OFF`, expand, ratio 2); the header cells wrap (`WORD_SMART`); values shrink. With §8.1 the modal is also wider |
| **Codex** (phone) | seven tabs wrap to four rows (≈ 230 px); with *How to play* eight | compact: the tabs are **one row in a horizontal `ScrollContainer`** (`follow_focus`, scroll bar hidden, the current tab scrolled into view on open); `←`/`→` move between tabs when one has focus. Desktop keeps the wrapping row |
| **Title**, **Setup** | fit at both widths | — (the focus fix §4.2 applies) |
| **Coach / hints** (compact) | at 150 % a long hint body can cover half the phone map | the card's height ≤ `COACH_MAX_HEIGHT_SHARE` 0.4 of the view; the body sits in a `ScrollContainer` beyond that |
| **Pause menu** | more rows (S6.1, S6.5, S6.7, this spec) | already scrolls (S4.9); `follow_focus` (§4.2) |
| **Caption stack** | three captions at 150 % in 280 px are tall | §8.1; the stack keeps `CAPTION_MAX` 3 |
| **Credits, Controls** (new) | not built yet | built to §8.1 and §4.2; S6.8 screenshots them at 150 % |

S4.9 checked the session, settings, containment, tree, analysis and pause menu at 150 %; S6.8
repeats the full set at 150 % (§12) because §4.2's outer ring and §8.1 change every screen a
little.

---

## 9. Time and motion

1. **No timed input** — audited: event deadlines are in game days and the clock can be paused at
   any moment, modals included (UI §5); site select, the capture of §5.3, the coach and the
   hints never time out.
2. **Reading time of the console line** (was a flat `CONSOLE_LINE_MS` 4000, `loop-mechanics.md`
   §16): it stands `CONSOLE_LINE_MS + CONSOLE_PER_CHAR_MS × length` (40 ms per character, as the
   captions), and its clock **does not run while the game is paused** (speed 0 or a hold) — a
   line that arrives as the player pauses can be read. The same for the reduced-motion ticker's
   standing item (`TICKER_STATIC_*` already scales per character; it also holds while paused).
   Every console line is also in the analysis log.
3. **Reduced motion from the OS:** on the first launch (no `settings.json`),
   `reduced_motion` defaults to `DisplayServer.accessibility_should_reduce_animation()`. After
   that the stored value rules.
4. Flashes: `polish-visuals.md` §6 — unchanged; the focus ring does not animate.

---

## 10. Strings

### 10.1 New (in `data/loc/strings.csv`, written in D6.6)

| Key | en | de |
| --- | --- | --- |
| `UI_A11Y_LABEL_VALUE` | {label}: {value} | {label}: {value} |
| `UI_A11Y_LOCKED` | {name} — locked: {rule} | {name} – gesperrt: {rule} |
| `UI_A11Y_DIALOG` | {title}. {body} | {title}. {body} |
| `UI_A11Y_BOOT_SKIP` | Press any key to skip. | Beliebige Taste zum Überspringen. |
| `UI_A11Y_CONSOLE` | Console | Konsole |
| `UI_A11Y_TICKER` | Headlines | Schlagzeilen |
| `UI_A11Y_TIMELINE` | Timeline | Zeitleiste |
| `UI_A11Y_CHART_DISCOVERED` | Discovered on day {day}. | Entdeckt an Tag {day}. |
| `UI_A11Y_TREE_TAB` | {tab}, {owned} of {total} | {tab}, {owned} von {total} |
| `UI_A11Y_TREE_TAB_AFFORDABLE` | {tab}, {owned} of {total}, something affordable | {tab}, {owned} von {total}, etwas ist bezahlbar |
| `UI_A11Y_TRACK` | {faction}: {value}, {band} | {faction}: {value}, {band} |
| `UI_A11Y_MAP` | World map | Weltkarte |
| `UI_A11Y_MAP_HELP` | Arrow keys move between regions, Enter selects, Enter again opens the panel. Page Up and Page Down jump to the next region that wants you. | Pfeiltasten wechseln zwischen Regionen, Enter wählt aus, noch einmal Enter öffnet das Panel. Bild auf und Bild ab springen zur nächsten Region, die dich braucht. |
| `UI_A11Y_MAP_NOTHING` | Nothing is waiting for you on the map. | Auf der Karte wartet gerade nichts auf dich. |
| `UI_A11Y_REGION_NAME` | {region}. | {region}. |
| `UI_A11Y_PRESENCE_NONE` | Not reached. | Nicht erreicht. |
| `UI_A11Y_PRESENCE_REACHED` | Penetration {penetration}. | Durchdringung {penetration}. |
| `UI_A11Y_PRESENCE_CONTROLLED` | Penetration {penetration}, control {control}. | Durchdringung {penetration}, Kontrolle {control}. |
| `UI_A11Y_PRESENCE_DARK` | Dark — no one is left. | Dunkel – niemand ist mehr da. |
| `UI_A11Y_DORMANT` | Dormant. | Schlafend. |
| `UI_A11Y_ASSETS` | Yours here: {list}. | Deins hier: {list}. |
| `UI_A11Y_ASSET_ITEM` | {count} × {kind} | {count} × {kind} |
| `UI_A11Y_STATUSES` | Active here: {list}. | Hier aktiv: {list}. |
| `UI_A11Y_EVENT` | Waiting for you: {title}. | Wartet auf dich: {title}. |
| `UI_A11Y_ANOMALY` | Compute left lying around. | Herumliegende Rechenleistung. |
| `UI_A11Y_TASK_FORCE` | The Task Force is here. | Die Einsatzgruppe ist hier. |
| `UI_SITE_HOVER_OK_KEY` | {region}: possible here — press Enter. | {region}: hier möglich – Enter drücken. |
| `UI_TREE_TAB_COUNT_AFFORDABLE` | {owned} / {total} ● | {owned} / {total} ● |
| `UI_TREE_REQUIRES_ASSETS_MISSING` | Needs {count} × {kind} — missing | Braucht {count} × {kind} – fehlt |
| `UI_EVENT_DATELINE_FACTION` | {kind} · {faction} | {kind} · {faction} |
| `UI_SETTINGS_READ_HEADLINES` | Screen reader: read headlines | Bildschirmleser: Schlagzeilen vorlesen |
| `UI_SETTINGS_CONTROLS` | Controls | Steuerung |
| `UI_SETTINGS_CONTROLS_OPEN` | Change | Ändern |
| `UI_CONTROLS_TITLE` | Controls | Steuerung |
| `UI_CONTROLS_PAUSE` | Pause and resume | Pausieren und fortsetzen |
| `UI_CONTROLS_SPEED` | Speed {speed}× | Tempo {speed}× |
| `UI_CONTROLS_TREE` | Open the capabilities | Fähigkeiten öffnen |
| `UI_CONTROLS_CONTAINMENT` | Open containment | Eindämmung öffnen |
| `UI_CONTROLS_ANALYSIS` | Open the analysis | Analyse öffnen |
| `UI_CONTROLS_ABILITIES` | Open your abilities | Deine Aktionen öffnen |
| `UI_CONTROLS_HELP` | How to play | So spielst du |
| `UI_CONTROLS_ZOOM_IN` | Zoom in | Heranzoomen |
| `UI_CONTROLS_ZOOM_OUT` | Zoom out | Herauszoomen |
| `UI_CONTROLS_FOCUS_REGION` | Centre the selected region | Gewählte Region zentrieren |
| `UI_CONTROLS_PRESS` | Press a key — Esc cancels | Taste drücken – Esc bricht ab |
| `UI_CONTROLS_RESERVED` | {key} is kept by the game. | {key} bleibt dem Spiel vorbehalten. |
| `UI_CONTROLS_SWAPPED` | {key} moved from {other}; {other} is now {old}. | {key} kommt von {other}; {other} liegt jetzt auf {old}. |
| `UI_CONTROLS_NOTE` | Esc, Tab, Enter, the arrow keys and Page Up/Down keep their meaning. A controller has a fixed layout; on Steam, Steam Input can change it. | Esc, Tab, Enter, die Pfeiltasten und Bild auf/ab behalten ihre Bedeutung. Ein Controller hat eine feste Belegung; auf Steam lässt sie sich über Steam Input ändern. |
| `UI_CONTROLS_RESET` | Reset to defaults | Standard wiederherstellen |
| `UI_KEY_SPACE` | Space | Leertaste |
| `UI_KEY_ESCAPE` | Esc | Esc |
| `UI_KEY_ENTER` | Enter | Eingabe |
| `UI_KEY_TAB` | Tab | Tab |
| `UI_KEY_BACKSPACE` | Backspace | Rücktaste |
| `HELP_CONTROLS_P4` | Without a mouse: Tab moves between the parts of the screen. On the map the arrow keys move a marker from region to region; Enter selects it, Enter again takes you into its panel. Page Up and Page Down jump to the next region that wants you. | Ohne Maus: Tab wechselt zwischen den Bereichen des Bildschirms. Auf der Karte bewegen die Pfeiltasten eine Markierung von Region zu Region; Enter wählt sie aus, noch einmal Enter führt in ihr Panel. Bild auf und Bild ab springen zur nächsten Region, die dich braucht. |
| `HELP_CONTROLS_P5` | With a controller: the D-pad moves, A selects, B goes back, X pauses, Y changes the speed, the bumpers move between the parts of the screen, the triggers zoom, Start opens the menu. Keys can be changed under Settings → Controls. A screen reader reads the menus, the panels, the console and the headlines. | Mit Controller: Steuerkreuz bewegt, A wählt, B geht zurück, X pausiert, Y ändert das Tempo, die Schultertasten wechseln zwischen den Bereichen, die Trigger zoomen, Start öffnet das Menü. Tasten lassen sich unter Einstellungen → Steuerung ändern. Ein Bildschirmleser liest die Menüs, die Panels, die Konsole und die Schlagzeilen vor. |

`data/help.json`: the *controls* page's `paragraphs` 3 → 5 (done in D6.6).

### 10.2 Revised — swapped in by S6.8 (with `KeyNames.args()` in the renderers)

These texts name remappable keys. S6.8 replaces the current rows with these, **in the same commit
as the formatting**, so a placeholder is never shown raw. `IconButton` tooltips and coach and help
renderers format with `KeyNames.args()`.

| Key | en | de |
| --- | --- | --- |
| `HELP_TIME_P1` | The run moves in days. {key_pause} pauses and resumes; {key_speed_1}, {key_speed_2} and {key_speed_3} set the speed. Some cards stop the clock until you answer; the marks on the map do not. | Der Lauf vergeht in Tagen. {key_pause} pausiert und setzt fort; {key_speed_1}, {key_speed_2} und {key_speed_3} ändern das Tempo. Manche Karten halten die Zeit an, bis du antwortest; die Zeichen auf der Karte nicht. |
| `HELP_CONTROLS_P1` | {key_pause} pauses and resumes; {key_speed_1}, {key_speed_2} and {key_speed_3} set the speed. {key_tree} opens the capabilities, {key_containment} containment, {key_analysis} the analysis, {key_abilities} your abilities. Esc closes what is open, or opens the menu. {key_help} opens How to play for whatever you are looking at. | {key_pause} pausiert und setzt fort; {key_speed_1}, {key_speed_2} und {key_speed_3} ändern das Tempo. {key_tree} öffnet die Fähigkeiten, {key_containment} die Eindämmung, {key_analysis} die Analyse, {key_abilities} deine Aktionen. Esc schließt, was offen ist, oder öffnet das Menü. {key_help} öffnet „So spielst du“ zu dem, was du gerade ansiehst. |
| `HELP_CONTROLS_P2` | The map: drag or hold Shift with the arrow keys to move, the wheel or {key_zoom_in} and {key_zoom_out} to zoom, {key_focus_region} to centre the selected region. | Die Karte: Ziehen oder Umschalt mit den Pfeiltasten verschiebt, Mausrad oder {key_zoom_in} und {key_zoom_out} zoomen, {key_focus_region} zentriert die gewählte Region. |
| `HELP_CONTAINMENT_P2` | The containment panel ({key_containment}) shows … *(rest unchanged)* | Das Eindämmungspanel ({key_containment}) zeigt … *(Rest unverändert)* |
| `HELP_ANALYSIS_P1` | The Analysis ({key_analysis}) shows … *(rest unchanged)* | Die Analyse ({key_analysis}) zeigt … *(Rest unverändert)* |
| `UI_COACH_COMPUTE_BODY` | … {key_pause} pauses, {key_speed_1}–{key_speed_3} set the speed. *(first sentences unchanged)* | … {key_pause} pausiert, {key_speed_1}–{key_speed_3} ändert das Tempo. *(Anfang unverändert)* |
| `UI_COACH_OPEN_TREE_BODY` | … Open the capabilities ({key_tree}) — … | … Öffne die Fähigkeiten ({key_tree}) – … |
| `UI_COACH_DISCOVERED_BODY` | … Containment ({key_containment}) shows … | … Unter Eindämmung ({key_containment}) siehst du … |
| `UI_COACH_TASK_FORCE_BODY` | … Containment ({key_containment}) … | … Eindämmung ({key_containment}) … |
| `UI_HELP_BUTTON_TIP` | How to play: this screen ({key_help}) | So spielst du: dieser Bildschirm ({key_help}) |

"…" = the current text of that row, word for word; only the key letter (or *Space*/*Leertaste*,
*1, 2 und 3*, *1–3*) becomes the placeholder shown. The same placeholder set must appear in both
columns (`check_strings`).

---

## 11. Tests (S6.8)

**Unit**
- `test_focus_ring.gd`: `collect` skips hidden, non-`FOCUS_ALL`, disabled; tree order across
  roots; `next` wraps both ways; `current` outside → first / last; empty → null.
- `test_live_queue.gd`: first push due at once; a second within the gap waits; a third within the
  gap replaces the second; nothing due → "".
- `test_live_region.gd`: inactive and not forced → `text` unchanged; forced → set; the same text
  twice → differs by the trailing U+00A0; `accessibility_live` follows `assertive`.
- `test_map_nav.gd` (fixed anchors): each direction picks the expected neighbour; the cone
  excludes a far-sideways region; tie → lower index; nothing → −1; `jump` wraps both ways, empty
  → −1.
- `test_region_speech.gd` (fixture world): dark, not reached, reached, controlled; dormant; site
  eligible / closed with reason; assets, statuses, event, anomaly, Task Force parts present only
  when true; German locale renders.
- `test_key_bindings.gd`: defaults applied; `assign` to a free key; to another action's key swaps;
  reserved refused; not remappable refused; override equal to default not stored; `reset`;
  invalid settings entries dropped on load.
- `test_key_names.gd`: `Space` via `UI_KEY_SPACE` in both locales; a letter key; `args()` has all
  twelve names; after `assign` the arg changes.
- `test_settings.gd` (extended): `announce_headlines`, `keys` round trip and fallbacks; first
  launch reduced motion follows the OS value (injected).
- `test_ui_tokens.gd` (extended): `text_width` scales; `TASK_FORCE_DIM` ≥ 3 : 1 on `MAP_LAND` (both
  sets); S6.2's colour-floor test gains §6.2's pairs.
- `test_theme_focus.gd`: every focusable type variation has a focus stylebox with
  `expand_margin` = `FOCUS_OUTSET`, `draw_center` false, border `BORDER_FOCUS`.

**Integration**
- `test_session_focus.gd`: `Tab` walks zone 1 → 7 in order with a region panel open; hidden zones
  skipped; `Shift+Tab` backwards; with a modal open the session does not take `Tab`.
- `test_modal_focus.gd`: reverse wrap; a disabled first button skipped; a companion reachable;
  close restores focus; the confirm's `Escape` answers *Cancel* and leaves the pause menu open.
- `test_map_focus.gd`: arrow → cursor moves and `region_hovered` fires; `Enter` selects; `Enter`
  again focuses the region panel's `primary_focus` (the site button during site select); page
  down jumps to an event region; arrows do not pan while a button has focus.
- `test_slide_panel.gd` (extended): `take_focus` grabs `primary_focus` and gives focus back.
- `test_controls_modal.gd`: capture assigns; `Escape` cancels the capture without closing;
  reserved shows the note; swap shows the note; reset.
- `test_a11y_names.gd`: walk every screen and modal of the gallery and the session fixture — every
  visible `FOCUS_ALL` control has a non-empty `accessibility_name` or button text, in both
  locales; `UI_A11Y_LABEL_VALUE` on settings buttons; the pending button exists and is focusable.
- `test_announce.gd`: a cue with `announce` pushes its caption into the HUD's `LiveRegion` (forced
  active) with *Sound captions* off; a cue without it does not; a headline is spoken, a second
  within 8 s waits; `announce_headlines` off → nothing.
- `test_console_line.gd` (extended): the per-character standing time; paused → the clock holds.
- `test_localisation.gd` (extended): §10.2's strings render with no `{` left after formatting,
  both locales.

---

## 12. The per-screen checklist (S6.8 ticks it, in `PROGRESS.md` or the session log)

For **every** row: (a) every focusable control has a name, in both languages; (b) the first focus
is as listed; (c) `Tab`/`Shift+Tab` and the arrows reach every control in the listed order and the
ring is visible on each; (d) `Esc`/B does what is listed and focus returns where listed; (e) at
150 % in German, 1920 and 400 px, nothing is clipped, overlaps or breaks inside a word; (f) the
pad reaches everything the keyboard does; (g) nothing is told by colour alone (§6.2).

| Screen | First focus | Order | Esc / B | Focus after |
| --- | --- | --- | --- | --- |
| Boot | — | — | any key skips | title's first |
| Title | *Continue* or *New run* | Continue, New run, Codex, Statistics, Settings, Quit | nothing | — |
| Title → Settings / Codex / Statistics / Credits | first setting / Codex's close / close / close | modal's own | close | the title button that opened it |
| Settings → Controls | first row | rows, reset, close | cancel capture, else close | *Change* |
| Setup (page 1) | the selected architecture | cards (grid), difficulty, scenario, seed clear, Back, Next | Back | — |
| Setup (page 2) | **the first slot's pressed directive** (was Next) | slots in order, Back, Begin | Back | — |
| Session, origin prompt | map | zones §4.3 | pause menu | — |
| Session, running | none until `Tab`/arrow | zones §4.3 | the `Escape` chain (site select, panels, sheet, region, pause menu) | map, or the panel's opener |
| Region panel (from map) | `primary_focus` | tree order | close | map |
| Containment / Analysis (from key or dock) | close / current tab | tree order; charts ←/→; strip ←/→ | close | opener |
| Tech tree | current tab (as now) | close, tabs, board (arrows), detail | compact sheet, then tree | opener |
| Ability picker | first **enabled** ability | abilities | close | opener |
| Wire card | first enabled option; after answer *Close* | options, close | put away | previous |
| Discovery | *Containment* (as now) | continue, containment | dismiss | previous |
| Pause menu | *Resume* | resume, help, slots, settings rows, controls, quit | resume (a confirm: cancel) | previous |
| Codex (+ How to play) | close | close, tabs (compact: one scrolling row), list, back | close | opener |
| Statistics | close | close, replay buttons | close | opener |
| Results | *Again* (as now) | review, title, again | nothing | — |
| Analysis review (from results) | current tab | as analysis + *Back to results* | back to results | results' review button |
| Coach / hints | none (never steals focus) | zone 2; in a modal: companion | — | — |

Plus once: **a keyboard-only run** from the boot to the results screen (origin chosen with the map
cursor, a node bought, an ability used, a card answered, the pause menu used), and the same with a
pad; **Narrator and NVDA** on Windows: the title, a setting, the map cursor's line, a console line,
a headline, a modal opening and an announced alert are spoken. A reader that does not speak the
`LiveRegion` (engine or platform limits) is recorded under *Known issues* with what does work — it
does not block the step.

---

## 13. Acceptance (S6.8)

1. §12's checklist ticked for every row, in both locales.
2. The keyboard-only and the pad-only run from boot to results.
3. The screen-reader check of §12 done on Windows (Narrator; NVDA if installed), result recorded.
4. §6.3's fixes visible in screenshots (tab chip, missing row, dateline, resting badge).
5. 150 % screenshots at 1920 and 400 px of: title, setup, Codex (*How to play* and a list tab),
   statistics, credits, controls, pause menu, a session with the coach card and the caption stack,
   region panel, tech tree.
6. Suite green; `doomsday.tres` rebuilt after the token changes.

---

## 14. Decisions (for PROGRESS) and questions

**Decisions**
- AccessKit via `accessibility_*`, setting *Auto*; `LiveRegion` + `LiveQueue` for speech; the
  console, the headlines (switchable, 8 s apart), modal openings (assertive), the map cursor and
  seven `announce` cues are spoken; the caption stack is not a live region.
- The map is keyboard/pad playable through `MapFocus`: cursor, step (60° cone), jump, `Enter` twice.
- One session focus ring across the layers; modal trap wraps both ways and skips disabled; panels
  opened from the keyboard take and return focus.
- Focus ring outside the control (`FOCUS_OUTSET` 4) for every focusable type.
- Keyboard remapping of twelve actions (physical keys, swap on conflict, reserved set); the
  controller layout is fixed (Steam Input remaps).
- `TASK_FORCE_DIM` → `#CC4040`; affordable-tab `●`, *missing* asset rows, the counter-move
  dateline names the faction.
- Text-bearing maximum widths scale with the text size; statistics name column never wraps;
  compact Codex tabs scroll in one row; the coach card's height is capped on phones.
- Console lines stand longer for longer text and hold while paused; reduced motion's first
  default comes from the OS.
- No high-contrast theme and no colour-blind mode: the audit found no need.

**Questions for the user** (overnight, pending confirmation — also under *Waiting on the user*)
1. Controller remapping left to Steam Input — fine, or an in-game pad remap before release?
2. Headlines are spoken to a screen reader by default (8 s apart) — on by default right, or off?
