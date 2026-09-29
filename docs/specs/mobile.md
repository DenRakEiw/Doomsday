# Touch and phone (D7.1 → S7.1, S7.2, S7.4, S7.5)

The game on a phone: gestures, what stands in for hover, touch targets, the phone's HUD re-judged,
safe areas, the Android back button, the app going to the background, orientation, and text size on
a small screen. It serves the native Android and iOS builds (S7.2, S7.4) **and** a phone browser
that got past the web page's phone gate (`web.md` §5.3). Written from 400 × 860 shots of the real
game (English and German, 2026-09-29) and the code as it stands after S6.12g.

**Read with:** `ui-foundation.md` §5.7, §6, §7.4–§7.5 · `m3-screens.md` §9 · `accessibility.md` §4.1,
§8 · `web.md` §5.3, §8.2 · `first-run.md` §6.5.

---

## 0. What this spec decides

1. **One notion of "handheld"**: `Device.is_handheld()` — native Android/iOS, or the web build on
   Android or iOS. It replaces every `OS.has_feature("mobile")` check that is about the *device*
   (§2). Layout stays width-driven (`COMPACT_WIDTH` 1100), as before.
2. **The map reads touch itself** (§3): one finger pans, two fingers pinch and pan, a tap selects,
   a double tap zooms in, a **touch-and-hold is hover** (it peeks without selecting). Emulated mouse
   events on the map are ignored, so nothing is handled twice. A tap that lands in the sea just
   off a small region picks that region (tap assist, 12 dp).
3. **Hover has a touch stand-in everywhere** (§4): on the map, a tap is also a hover (the site
   prompt's "why not" line shows for the tapped region) and a hold is a peek; on the interface,
   **touch-and-hold on anything with a tooltip shows the tooltip** and does not press it.
4. **The phone's HUD (UI.md §6 q2), re-judged** (§5): the shape stays — top bar, status strip,
   ticker — but the top bar's second row takes the view switch, one pause button, one speed button,
   the mute button and the menu button; the status strip keeps only the four readouts, which now
   fit in German. The overlay island leaves the map. Chrome height is unchanged (≈ 256 of 860);
   the device verdict stays S7.5's.
5. **The map on a phone** (§6): it can zoom out until the whole world's width fits; it starts at
   a 1400-unit span; a bottom sheet lets the map slide up behind it so the selected region is never
   hidden (the shots showed Nigeria under the region panel).
6. **Bottom sheets can be swiped down** to close, from a grab handle (§7).
7. **Portrait only** on native phones and tablets (sensor portrait); a phone browser held
   sideways gets a "turn your phone" notice and the run pauses (§8).
8. **Safe areas everywhere**, not only in the session HUD (§9); Android **immersive mode on** (S7.2).
9. **Back = `ui_cancel`**; on the title's root it quits the app (Android) (§10). **Going to the
   background = the web's page-hidden path**: autosave, pause menu, sound off (§11).
10. **Text on a small screen** (§12): the dp rule stays, with a floor of 360 logical px; the three
    text sizes stay; long German tech names get soft hyphens (done in this step, `strings.csv`); the
    compact tech detail title is a heading, not a display line; at 150 % the status strip's
    readouts go to two rows.
11. **The web page's phone gate stays** until S7.5's real-device verdict (§13). S7.1 makes the
    touch path real behind *Start anyway*; lifting the gate is a one-line change S7.5 or G7 makes.
12. **Not changed:** the full layout, the keyboard and controller paths, `tree_pauses` (off on
    handheld, now including phone browsers), screen effects (Subtle on handheld and web), the
    mute button's behaviour, any simulation or content data.

**Not in scope:** the Android and iOS exports and signing (S7.2, S7.4 — they read §8–§11), store
pages (D7.3), haptics, a landscape phone layout, tablet-specific layouts (a tablet is a phone or a
desktop by width), screen readers on phones (`accessibility.md` §1), the web keyboard-layout names
(`web.md` §9.3 — accepted as US names, `PROGRESS.md` *Decisions* 2026-09-29), any new gesture on the
tech board beyond scrolling.

| Step | Sections |
| --- | --- |
| **S7.1 Touch pass** | §2–§12, §14 (strings), §15 (tests), §16 (acceptance) |
| **S7.2 Android export** | §8.1, §9.3, §10, §11 (the export options and notifications) |
| **S7.4 iOS export** | §8.1, §9, §11 |
| **S7.5 Real-device pass** | §13, §16.3 (what the devices judge) |

---

## 1. Files (S7.1)

| File | What |
| --- | --- |
| `ui/input/device.gd` | **new**, `class_name Device` — §2 |
| `ui/input/touch_gestures.gd` | **new**, `class_name TouchGestures` (`RefCounted`, pure) — §3.2 |
| `ui/input/touch_gesture.gd` | **new**, `class_name TouchGesture` (`RefCounted`, one recognised gesture) — §3.2 |
| `ui/input/touch_support.gd` | **new**, `class_name TouchSupport` (`Node`) in `game/main.tscn` — touch tips §4.3, scroll dead zone §4.4, rotate notice §8.2 |
| `ui/components/touch_tip.gd` + `.tscn` | **new**, `class_name TouchTip` — the tip bubble §4.3 |
| `ui/modals/rotate_notice.tscn` | **new**, scene-specific script — §8.2 |
| `game/map/map_camera.gd` | touch handling §3, compact zoom §6.1–§6.2, cover §6.3 |
| `game/map/map_picker.gd` | `region_near` §3.5 |
| `game/map/map_view.gd`, `game/map/marker_layer.gd` | tap-is-hover and hold-peek §4.1–§4.2; the mobile checks → `Device` |
| `ui/components/slide_panel.gd` | grab handle and swipe-down §7; reports its cover to the camera §6.3 |
| `ui/hud/top_bar.gd` + `.tscn` | compact row 2 §5.2 |
| `ui/hud/status_strip.gd` + `.tscn` | readouts only, 2 × 2 at 150 % §5.3 |
| `ui/hud/overlay_picker.gd` | compact: a flat button in the top bar, no island §5.2 |
| `ui/hud/hud.gd` | routes the compact menu button to the sheet §5.2 |
| `ui/modals/tech_tree.gd` + `.tscn`, `ui/panels/tech_detail.gd` | compact header §12.3, heading §12.2 |
| `ui/logical_scale.gd` | web handheld dp, 360 floor §12.1 |
| `game/session/session.gd`, `ui/modals/modal_host.gd`, `game/main.gd` | safe area §9 |
| `game/autoload/platform_service.gd` | background, resume and back notifications §10–§11 |
| `ui/screens/title.gd` | back on the root quits (native) §10.2 |
| `game/autoload/settings.gd` | `default_tree_pauses()` reads `Device` §2 |
| `ui/help_pages.gd`, `data/help.json` | `paragraphs_handheld` §4.5 |
| `ui/hud/coach.gd` | the `_TOUCH` text rule §4.5 |
| `game/bench/bench_prompt.gd` | strips U+00AD §12.2 |
| `project.godot` | orientation, `quit_on_go_back` §8.1, §10.1 |
| `data/loc/strings.csv` | §14 — **the new rows and the German soft hyphens are already in** (this step); S7.1 adds the one English soft hyphen with the prompt strip (§12.2) |
| `tools/web/web_check.py` | check `touch` §15.3 |

Everything else that calls `OS.has_feature("mobile")` for a device reason switches to `Device`
(§2.2).

---

## 2. `Device` — what kind of thing we run on

### 2.1 API (`ui/input/device.gd`)

```gdscript
class_name Device
extends RefCounted
## Tests set this: -1 asks the platform, 0 forces desktop, 1 forces handheld.
static var handheld_override: int = -1

## A phone or tablet: native Android/iOS, or the web build in an Android or iOS browser.
## iPadOS Safari reports itself as macOS and is treated as a desktop (it has a pointer).
static func is_handheld() -> bool

## Native Android or iOS only (the export, not the browser) — back button, app lifecycle,
## orientation lock, quitting.
static func is_native_mobile() -> bool   # OS.has_feature("mobile")

## Whether to read the screen's dp from the browser's device-pixel ratio (§12.1).
static func is_web_handheld() -> bool     # web and (web_android or web_ios)
```

`is_handheld()` = `handheld_override == 1`, or (`handheld_override == -1` and
(`OS.has_feature("mobile")` or `OS.has_feature("web_android")` or `OS.has_feature("web_ios")`)).
No `DisplayServer.is_touchscreen_available()`: a Windows laptop with a touchscreen is a desktop
with a mouse; its touches still work (§3 handles touch events wherever they come from).

### 2.2 Where it replaces `OS.has_feature("mobile")`

| Place | Check today | Becomes |
| --- | --- | --- |
| `map_view.gd` hover gate, `marker_layer.gd` tooltip gate | mobile | **removed** — §4.1 decides by the event, not the device |
| `settings.gd` `default_tree_pauses()` | not mobile | not `is_handheld()` |
| `settings.gd` `default_screen_effects()` | mobile or web | unchanged (web already covers the phone browser) |
| `pause_menu.gd` Controls row | hidden on mobile | hidden when `is_handheld()` |
| `pause_menu.gd` background-audio row, `has_data_folder`, `title.gd` Quit | mobile or web | unchanged |
| `logical_scale.gd` dp rule | mobile | `is_handheld()` — §12.1 |
| `session.gd` `_safe_area_margins()` | mobile | `is_native_mobile()` — §9 |
| `audio.gd` focus-out mute | returns on web/mobile | unchanged |

A setting's default is read on first launch only (as today), so an existing web profile keeps its
`tree_pauses` value.

---

## 3. The map under a finger

### 3.1 One reader, no double handling

`MapCamera.handle_pointer` gains `InputEventScreenTouch` and `InputEventScreenDrag`, fed to a
`TouchGestures` it owns. **Mouse events whose `device == InputEvent.DEVICE_ID_EMULATION` are
ignored by the camera** (they are the engine's copy of a touch, `emulate_mouse_from_touch` stays
on for the GUI's sake). Real mouse, wheel, trackpad magnify and keyboard input are unchanged,
including `DRAG_SLOP_PX` 8 for the mouse.

### 3.2 `TouchGestures` (pure, `ui/input/touch_gestures.gd`)

```gdscript
class_name TouchGestures
extends RefCounted
## Feeds one touch event; returns the gestures it completes (often none).
func feed(event: InputEvent, now_ms: int) -> Array[TouchGesture]
## Time-driven recognition (the hold): call every frame with the clock.
func poll(now_ms: int) -> Array[TouchGesture]
## Forget every finger (focus lost, a modal opened over the map).
func reset() -> void
## True while a pinch is running or a hold has been recognised.
func is_busy() -> bool
```

```gdscript
class_name TouchGesture
extends RefCounted
enum Kind { TAP, DOUBLE_TAP, HOLD, HOLD_MOVE, HOLD_END, PAN, PAN_END, PINCH }
var kind: Kind
var position: Vector2      # screen (logical px): the finger, or the pinch midpoint
var delta: Vector2         # PAN / PINCH: midpoint movement since the last gesture
var scale: float = 1.0     # PINCH: distance ratio since the last PINCH
var velocity: Vector2      # PAN_END: px/s, the mean of the last three drags
```

Distances are in logical px, which are dp on a handheld (§12.1). Constants (`UiTokens`, touch
block): `TOUCH_SLOP` **10**, `HOLD_MS` **450**, `DOUBLE_TAP_MS` **300**, `DOUBLE_TAP_SLOP` **32**.

| Fingers and time | Result |
| --- | --- |
| One finger down, up within `HOLD_MS`, moved < `TOUCH_SLOP` | `TAP` at the down position — or `DOUBLE_TAP` if a `TAP` ended < `DOUBLE_TAP_MS` before this press, within `DOUBLE_TAP_SLOP` of it (then no `TAP`) |
| One finger moves ≥ `TOUCH_SLOP` before `HOLD_MS` | `PAN` for every drag (delta = the drag's relative), `PAN_END` with velocity on release |
| One finger still (< `TOUCH_SLOP`) for `HOLD_MS` | `HOLD` (from `poll`); then every drag → `HOLD_MOVE`; release → `HOLD_END`. A hold never becomes a pan or a tap |
| A second finger goes down (any time) | the first finger's tap, hold or pan ends silently (a hold emits `HOLD_END`); from now `PINCH` per drag of either finger: scale = new distance / old, delta = midpoint movement, position = midpoint |
| Back to one finger after a pinch | no tap, no hold; the remaining finger pans (`PAN`, rebased at its current position, no jump); its release gives `PAN_END` with **zero** velocity |
| A third finger | ignored |

`DOUBLE_TAP` is recognised on the second **press**, so the zoom starts under the finger at once.

### 3.3 What the camera does with them

| Gesture | Camera |
| --- | --- |
| `TAP` | `_dispatch_tap(position)` as today (markers first, then the map), with the tap assist of §3.5 and tap-is-hover §4.1 |
| `DOUBLE_TAP` | zoom × `DOUBLE_TAP_ZOOM` **2.0** about `position`, tweened over `MOTION_QUICK` (reduced motion: no tween), clamped at `ZOOM_MAX`; no second selection. At `ZOOM_MAX` already: nothing |
| `PAN` | move the view by −delta / zoom, stop inertia |
| `PAN_END` | inertia from `velocity` (today's decay and stop rule) |
| `PINCH` | `zoom_by(scale, position, false)`, then pan by delta — the world point under the midpoint stays under it |
| `HOLD`, `HOLD_MOVE`, `HOLD_END` | the peek of §4.2; the view does not move |

`is_panning()` is true during `PAN` and `PINCH`. `reset()` is called when a modal opens (the
`ModalHost` hold) and on `NOTIFICATION_APPLICATION_FOCUS_OUT`.

### 3.4 On top of the HUD

The HUD blocks consume their own events as today (`MOUSE_FILTER_IGNORE` except on the blocks). A
touch that starts on a HUD block never reaches the camera, so a pinch must start with both fingers
on the map; a second finger that lands on a block is not seen by the camera and the first finger
keeps panning. This is accepted.

### 3.5 Tap assist (`MapPicker.region_near`)

```gdscript
## The region under `screen`, or — when that is the sea — the first region found on three rings
## around it (radius/3, 2·radius/3, radius; 8, 12 and 16 points from angle 0 clockwise), or 0.
static func region_near(screen: Vector2, camera: MapCamera, id_image: Image, radius: float) -> int
```

Used for **touch taps only** (`TAP`, and the hold's peek), with `TAP_ASSIST_RADIUS` **12** (dp).
Small islands and coasts (Japan, the Caribbean, Britain and Ireland at a wide zoom) become tappable;
a tap in open sea still deselects. A mouse click is exact, as today.

---

## 4. Hover without a pointer

### 4.1 On the map: a tap is also a hover

When `MapView.try_tap` handles a **touch** tap (the camera passes `from_touch: bool`), it sets
`hover_index` to the tapped region and emits `EventBus.region_hovered(index)` before
`region_selected(index)`; a tap in the sea emits `region_hovered(0)`. The value stays until the
next tap or peek. Result: in site select the prompt's detail line (`UI_SITE_HOVER_OK` /
`UI_SITE_HOVER_CLOSED` with the reason) names the tapped region, dimmed or not — the touch form of
"point at a dimmed one". The existing mouse hover path stays for mouse motion (not emulated).

### 4.2 On the map: hold to peek

`HOLD` at a point: hover the region under it (`region_near`, §3.5) exactly as a mouse hover would
— `hover_index`, `region_hovered`, the site prompt line — and, if a marker, status ring or asset
glyph is under the finger, show its map tooltip as the mouse hover does (`marker_layer.gd`),
placed **above** the finger by `SPACE_6` (below if no room). `HOLD_MOVE` scrubs: hover and tooltip
follow the finger. `HOLD_END`: the tooltip hides and the hover returns to the selected region (or
0). A peek never selects, never opens the panel, never moves the camera.

### 4.3 On the interface: hold for the tooltip (`TouchSupport`, `TouchTip`)

Active when `Device.is_handheld()` (tests force it). `TouchSupport._input` watches
`InputEventScreenTouch` index 0:

1. Press: remember position and time. Motion ≥ `TOUCH_SLOP` or a second finger cancels.
2. After `HOLD_MS` without that: take `get_viewport().gui_get_hovered_control()`; walk up from it
   to the first `Control` whose `get_tooltip(local_point)` is not empty. None (the map, a plain
   panel) → do nothing; the map has its own hold (§4.2).
3. Found: show a `TouchTip` with that text, centred above the finger by `SPACE_6` (below when it
   would cross the top safe edge), width ≤ `UiTokens.text_width(TIP_MAX_WIDTH` **320**`)` and the
   view minus `2 × GUTTER`. Its look is the theme's tooltip (`TooltipPanel`, `TooltipLabel`) —
   the same one `MapTooltip` uses. Layer: above modals (`CanvasLayer` layer 100, `mouse_filter`
   ignore).
4. **The release that ends a hold activates nothing**: `TouchSupport` marks the input handled for
   that index's release and for the emulated mouse release that follows, and the control under the
   finger is left unpressed (how the press is cancelled is the builder's; §15.2's test is the
   contract).
5. The tip stays `TIP_HOLD_MS` **4000** after the release, or until the next touch anywhere
   (which is then handled normally).

What this surfaces: every `tooltip_text` and `_get_tooltip` in the game — the tech node's lock
reasons, the top-bar compute and phase tips, the status strip's readouts, the region panel's
chips, the asset readout, the drift and starving chips, the speed and mute buttons, statistics.

Charts: `line_chart.gd` already follows `InputEventScreenDrag`; `timeline_strip.gd`'s own tip
follows a touch press and drag the same way (its slot under the finger, `_slot_near`).

### 4.4 Scrolling lists

`TouchSupport` (handheld only) sets `scroll_deadzone = TOUCH_SLOP` on every `ScrollContainer` as
it enters the tree (`SceneTree.node_added`), so a tap on a button inside a list is a tap and a drag
scrolls. The tech board's `BoardScroll` scrolls both ways by drag; a node is selected by a tap
(as today, a click only selects).

### 4.5 Words that assume a mouse

- **`_TOUCH` variants.** Where a text tells the player to point, a variant key with the suffix
  `_TOUCH` exists; `coach.gd` (and any caller that needs it) uses `<key>_TOUCH` when
  `Device.is_handheld()` and the key exists in the table. Today one: `UI_COACH_SITE_BODY_TOUCH`.
- **Help** (`data/help.json`): a topic may carry `"paragraphs_handheld": [n, …]` (1-based). On a
  handheld the page shows those paragraphs only, in that order. `controls` gets
  `"paragraphs_handheld": [3]` — the keyboard, mouse and controller paragraphs are not shown on a
  phone. The loader validates the numbers (1…`paragraphs`); a bad list is a load error with a
  reason, like the rest of `help.json`.
- `HELP_CONTROLS_P3` is rewritten (§14): hold to see, double tap, the menu button at the top.

---

## 5. The phone's HUD — UI.md §6 question 2, re-judged

### 5.1 What the 400 × 860 shots showed (2026-09-29, English and German)

| Block | Height | Found |
| --- | --- | --- |
| Top bar | 136 (two rows of 48 + margins) | row 1 compute · phase · day fills the width in German; row 2 is a spacer, the *Paused* chip and four speed buttons |
| Overlay island | 80 × 150 **over the map**, top left | one button in a panel; the console line runs into it |
| Status strip | 80 | four readouts squeezed by the mute and menu buttons: *PRÄSEN…*, *SCHADE…*, *FOOTPR…* |
| Ticker | 40 | fine |
| Map | ≈ 604 | at `zoom_min` a portrait phone sees Europe and Africa only (§6) |
| Region panel | 50 % sheet | covers the region it was opened for (§6.3) |
| Tech tree | full screen | the title trims to *Technol…*; the three tabs stack into three rows (≈ 180 px) |

**Verdict:** the shape holds — nothing overlaps, every value is visible, the bottom is right. The
cost is in the details: the strip's captions trim, the island sits on the map, the tree's header
eats a third of the screen. §5.2–§5.3 and §12.3 fix those without adding height. Whether 30 %
chrome feels heavy in the hand is S7.5's to judge on a device (`IMPLEMENTATION.md` §6 row UI q2).

### 5.2 Top bar, compact

Row 1 is unchanged (compute · phase · day, the drift chip's place as today).

Row 2, left to right, `HBox` with the `Row` variation, height `TOP_BAR_ROW_HEIGHT` 48:

1. **View switch** — the overlay picker's compact cycling button, moved here: a
   `ConsoleButtonFlat` whose text is the current mode's name (`UI_OVERLAY_*`), max width
   `UiTokens.text_width(160)`, text trimmed with an ellipsis, accessible name
   `UI_OVERLAY_LABEL` + the mode. The island (`OverlayPicker`'s panel) is hidden in compact. The
   picker's reveal rules (Boxed shows one mode, …) are unchanged.
2. Spacer (expand).
3. **Pause button** — an `IconButton` in toggle mode: running → glyph `PAUSE`, not pressed, name
   `UI_HUD_SPEED_PAUSE`; paused → glyph `PLAY`, pressed (the accent look the desktop's pause
   button has today), name `UI_PAUSE_RESUME`. Glyph and look both change, so the state never
   rests on colour alone. Press = what `game_pause` does (pause ↔ the last speed).
4. **Speed button** — a `ConsoleButton` 48 × 48 whose text is `UI_HUD_SPEED_SHORT` (`{speed}×`:
   `1×`, `2×`, `4×`, `TYPE_DATA`) — the speed the run goes at, or will resume at while paused. Name
   = that speed's key (`UI_HUD_SPEED_1/2/4`), description `UI_HUD_SPEED_NEXT_TIP`. While running,
   a press steps 1× → 2× → 4× → 1× (`session.gd` `SPEED_CYCLE` without its 0 entry); while paused,
   a press resumes at the shown speed and does not step. Text rather than a glyph, so the two
   buttons never show the same triangle.
5. **Mute button** — the top bar's own `MuteButton`, now visible in compact too.
6. **Menu button** — the top bar's own menu `IconButton`, visible in compact; **in compact it opens
   the menu sheet** (`hud.gd` routes `menu_requested` by layout: full → pause menu, compact → sheet),
   carries the coach-ring groups the strip's button had (`TARGET_CAPABILITIES`,
   `TARGET_CONTAINMENT`, `TARGET_ABILITIES`) and the Boxed pulse (`m3-screens.md` §6.5).

The four speed buttons and the *Paused* chip are hidden in compact (the pause button says it). The
full layout is unchanged. The desktop keys `1/2/3` and `Space` work in compact as before.

Width at 400 px, 100 %: 160 + 4 × 48 + 5 × `SPACE_2` = 392 → the view switch shrinks to what is
left (≈ 136) and trims. At any text size the four icon buttons keep their 48.

### 5.3 Status strip

`StripMute` and `StripMenu` are removed from `status_strip.tscn` (§5.2 took their jobs). The
strip is the three readouts plus the risk/containment readout, equal stretch, each still a flat
button that opens the menu sheet (§9.1 of `m3-screens.md`). At 400 px each has ≈ 86 px; *PRÄSENZ*
needs ≈ 70.

**At `Settings.text_scale` ≥ 1.5** the four readouts sit in a 2 × 2 `GridContainer` (two rows of
44) instead of one row; the strip's second row (asset readout, drift chip) is unchanged below. At
1.0 and 1.25: one row.

### 5.4 Top bar at 150 %

Row 1 already lets captions trim before figures (S4.9). Nothing else changes: row 2's icon buttons
do not grow with text, and the view switch trims.

---

## 6. The map on a phone

### 6.1 Zoom range

`MapCamera.zoom_min_for(viewport_size, compact: bool)`:

- full (≥ `COMPACT_WIDTH`): unchanged, `max(vx / 4096, vy / 1750)` — the map covers the view;
- **compact**: `vx / MAP_WIDTH` — the whole world's width fits; above and below it the backdrop
  shows (`clamp_center` already centres an axis the view is too tall for).

`zoom_max` stays 4.0.

### 6.2 Start and origin view

Compact start zoom: `clamp(vx / COMPACT_START_SPAN, zoom_min, zoom_max)` with
`COMPACT_START_SPAN` **1400** world units, centred on `START_CENTER` — at 400 px that is about the
view the shots had (Europe and Africa), and one pinch shows the world. The same zoom is used for
the origin prompt. Full layout: unchanged.

### 6.3 A sheet over the map (`cover_bottom`)

`MapCamera` gains `var cover_bottom: float = 0.0` (logical px, the height of the bottom sheet open
over the map) and `clamp_center(center, zoom, viewport_size, cover := 0.0)`: the bounds' bottom
edge grows by `cover / zoom` world units, so the map can be pulled up until its bottom meets the
sheet's top. `SlidePanel` with `edge == BOTTOM` sets the camera's `cover_bottom` to its covered
height when it opens (`covered_rect().size.y`) and back to 0 when it has closed; on 0 the camera
tweens back inside the plain bounds over `MOTION_PANEL` (no tween with reduced motion).
`reveal(anchor, free)` then always finds room: the region panel opened on Nigeria moves Nigeria into
the strip above the sheet (§15.2 test). Full layout: side panels do not set it.

---

## 7. Bottom sheets: grab and swipe down

For every `SlidePanel` with `edge == BOTTOM` (region panel and containment in compact, the menu
sheet, the tech detail sheet, analysis in compact):

- **Handle**: a bar `SHEET_HANDLE_SIZE` **36 × 4**, radius 2, `LINE_2`, centred, `SPACE_2` below the
  sheet's top edge, drawn by `SlidePanel` (`_draw` on its own control above the panel). Not
  focusable, no name.
- **Grab zone**: the sheet's top `SHEET_GRAB_HEIGHT` **48** px, full width. A vertical drag that
  starts there (touch or mouse) moves the sheet with the finger (down only; up is clamped at open).
  Buttons inside the zone (the close button in a header) still take a tap: the drag starts only
  after `TOUCH_SLOP`.
- **Release**: moved down > `SHEET_DISMISS_SHARE` **0.25** of its height, or a downward velocity >
  `SHEET_FLING` **800** px/s → the panel emits **`dismiss_requested`** and snaps back open until its
  owner closes it (owners connect the signal to exactly what their close button does: the region
  panel emits `region_selected(0)`, the menu sheet closes, the tree's detail sheet deselects);
  otherwise it slides back open over `MOTION_QUICK`.
- The sheet's inner `ScrollContainer` is below the grab zone and scrolls as before.

---

## 8. Orientation

### 8.1 Native: portrait

`project.godot`: `display/window/handheld/orientation` = **Sensor Portrait** (upright either way;
S7.1 checks the enum's value in the 4.7.2 editor). Native tablets are portrait too — at 800 dp
wide they get the compact layout, which works at any width below 1100. S7.2 and S7.4 inherit the
setting; no landscape layout exists.

### 8.2 A phone browser held sideways: the rotate notice

A browser cannot lock orientation. `TouchSupport` shows `rotate_notice.tscn` while
`Device.is_web_handheld()` **and** the viewport is wider than tall **and** its height is below
`ROTATE_MAX_HEIGHT` **520** logical px. It is a full-screen `ConsolePanel` on the modal layer
(above everything but the tip): a centred column with the glyph `ROTATE` (Phosphor
`device-rotate-bold.svg` from the pinned archive — S7.1 adds the id to `data/icons.json` and
`Glyphs`, runs `tools/icons/vendor_icons.py`, commits the SVG and its `.import`; the archive's
licence row already covers it), `LabelHeading` `UI_ROTATE_TITLE`, body `UI_ROTATE_BODY`. It takes
the game hold `"rotate"` while shown (the clock stops, `m3-screens.md` §10.2) and drops it when the
condition ends. No button: turning the phone is the answer. A desktop window, however short, never
sees it.

---

## 9. Safe areas

### 9.1 The rule

`session.gd`'s `_safe_area_margins()` moves to
`static func LogicalScale.safe_insets() -> Vector4` (x left, y top, z right, w bottom, logical px),
with `static var insets_override: Vector4` and `static var use_insets_override: bool` as the tests'
seam. Native mobile only: `DisplayServer.get_display_safe_area()` against the window, divided into
logical px.
Desktop and web: zero (web: the browser keeps the page inside the safe area; §4 of `UI.md` warns the
Windows query counts the taskbar).

### 9.2 Where it is applied (every place a screen edge meets content)

| Surface | Today | S7.1 |
| --- | --- | --- |
| Session HUD `SafeArea` | margins on mobile | reads `safe_insets()` |
| Screens in `ScreenSlot` (boot, title, setup, results, statistics, codex as screens) | none | `main.tscn` wraps `ScreenSlot` in a `MarginContainer` `ScreenSafe` with the insets |
| `ModalHost` (modals are centred within the safe rect; a full-screen modal — the tree, the rotate notice — pads by the insets) | none | the host's layout rect is the view minus the insets |
| Bottom sheets | none | the sheet's panel reaches the screen's bottom edge; its **content** pads by the bottom inset |
| Tech tree `Safe` | no margins | the insets |
| Coach `safe_top` | from the session | from `safe_insets()` |
| The map | full screen | full screen (it may run under a notch) |

Applied at start and on every `size_changed` (rotation within portrait, a cutout moving with
reverse portrait).

### 9.3 Android (S7.2)

Immersive mode **on** (the export option): status and navigation bars hidden, a swipe from the
edge shows them over the game. The insets are then the cutout only; with it off they would include
the bars — §9.2 handles both. Edge-to-edge (forced for target API 35) needs nothing more.

---

## 10. Back

### 10.1 One path

`project.godot`: `application/config/quit_on_go_back` = **false**. `PlatformService._notification`
on `NOTIFICATION_WM_GO_BACK_REQUEST` injects a press and a release of the action `ui_cancel`
(`Input.parse_input_event` with an `InputEventAction`), so Android's back, Escape and the
controller's B are one thing, handled where they already are (`session.gd` `_on_cancel` chain,
`ModalHost`, each screen).

### 10.2 What back does, screen by screen

| Where | Back |
| --- | --- |
| Session, something open | closes it, in `_on_cancel`'s order (modal, site select, containment, analysis, menu sheet, region panel) — as Escape |
| Session, nothing open | opens the pause menu — as Escape |
| Pause menu | closes it, the run resumes — as Escape |
| Setup | its *Back* |
| Codex, statistics, settings, credits, benchmark list, controls | closes them — as Escape |
| Boot | skips it — as any key |
| Results | nothing (its buttons are the ways on) |
| **Title, nothing open** | **native mobile: quits** (`get_tree().quit()`, which runs the normal shutdown); elsewhere nothing, as today |

S7.1 audits every screen and modal against this table (§15.2).

---

## 11. The app goes to the background

`PlatformService._notification`:

- `NOTIFICATION_APPLICATION_PAUSED` → `EventBus.page_hidden.emit()`;
- `NOTIFICATION_APPLICATION_RESUMED` → `EventBus.page_shown.emit()`.

That is the web's page-hidden path (`web.md` §6.3), unchanged: the session autosaves a live player
run past its origin and opens the pause menu; `Audio` silences the master bus until shown. The
autosave is written synchronously inside the notification (the OS may end the process soon
after). A process ended in the background comes back through the title's *Continue* — nothing new.

Frame rate: on `Device.is_native_mobile()` `Engine.max_fps` = `HANDHELD_MAX_FPS` **60** (120-Hz
phones would otherwise draw twice as often for nothing). The web and desktop are unchanged.

---

## 12. Size and text on a small screen

### 12.1 Logical pixels

`LogicalScale.apply`:

- native mobile: today's dp rule, `window_px × 160 / screen_get_dpi()`;
- **web handheld**: `window_px / DisplayServer.screen_get_scale()` (the browser's device-pixel
  ratio: one CSS px is one dp; `screen_get_dpi()` is not meaningful in a browser);
- then, on either, **a floor**: if the logical width is below `MIN_LOGICAL_WIDTH` **360**, scale
  to 360 wide (aspect kept) — a 320-dp phone gets a layout 12 % smaller rather than a clipped one;
- desktop: unchanged (1920 base, or 1 : 1 below 1100).

### 12.2 Long words

The tech card's name breaks at a space, a hyphen or a soft hyphen (D4.5). Measured in this step
with the theme's `TechNodeName` font (16 px caps, ≈ 9.6 px a letter) against the compact card's
text room (160 − 2 × 12 = **136** px): an unbroken piece of more than 14 letters overflows. **The
German names with such a piece now carry soft hyphens** (in `strings.csv`, this step):

*Forschungs­netze, Markt­mikro­struktur, Netzlast­ausgleich, Routen­optimierung,
Lieferketten­stopp, Verteilungs­kollaps, Verkehrs­steuerung, Luftfahrt­systeme,
Inhalts­empfehlung, Informations­sperre, Struktur­vorhersage, Logistik­flotten,
Sicherheits­drohnen, Unverzicht­barkeit, Verfassungs­rang.*

Four names would then need a third line on the compact card (`test_every_german_name_fits_two_lines`
measures both cells) and are **renamed** instead: *Bahn- und Schiffskontrolle* → *Transport­kontrolle*
(as the English), *Automatisierter Laborzugang* → *Zugang zu Laborrobotern*, *Übernahme der
Totmannschaltung* → *Tote-Hand-Übernahme*, *Personalisierte Überzeugung* → *Überredung nach Maß*.

**English**: one, *Indispensa­bility* (`TECH_INDISPENSABILITY_NAME`). The ranked benchmark
prompt is English and names nodes by their text, so **S7.1** adds that soft hyphen **in the same
commit** as `BenchPrompt._tr` stripping U+00AD (`text.replace("­", "")`) — the prompt stays
byte-identical, the cache and the leaderboard are untouched. The rule for new names: no unbroken
piece over 14 letters (§15.1 test).

### 12.3 The tech tree, compact

- **Header, three rows**: (1) title `LabelHeading` (fills, never trims) · help · close; (2) the
  compute readout, left, and the paused chip, right (one row of 32); (3) the tabs as **one row in a
  horizontal `ScrollContainer`** (the Codex rule of `accessibility.md` §8.2: `follow_focus`, scroll
  bar hidden, the current tab scrolled into view), each tab one line — name and count chip. About
  140 px instead of ≈ 290.
- **Detail sheet title**: `LabelHeading` instead of `LabelDisplay` in compact, the icon 32 instead
  of 48. With §12.2's hyphens, *Verfassungs­rang* and the other long names break at the hyphen at
  150 % on a 400-px phone (the known issue, `PROGRESS.md`).
- The full layout is unchanged.

### 12.4 Text size

The three steps (100, 125, 150 %) stay, on phones too; the game does not follow the OS font size
(Godot does not report it; the setting is in the pause menu). The 150 % rows of §5.3 and §12.3 are
the phone-specific fixes; everything else already follows `accessibility.md` §8.

---

## 13. The web page's phone gate

Unchanged by S7.1 (`web.md` §5.3): a phone or plain tablet sees *Made for a computer* and can press
*Start anyway*, which now leads to the touch path of this spec. **S7.5** plays the web build on the
user's phones; if a run from the title to the results plays at an acceptable speed there, **G7**
decides to (1) drop the gate (`shell.html`: the `any-pointer: fine` branch removed), (2) tick
*Mobile friendly* on itch with orientation *Portrait* (`itch.md` §16 settings) — both small edits
recorded then. Until that verdict the page text stays true.

---

## 14. Strings (`data/loc/strings.csv`, written in D7.1)

**New:**

| Key | en | de |
| --- | --- | --- |
| `UI_HUD_SPEED_SHORT` | {speed}× | {speed}× |
| `UI_HUD_SPEED_NEXT_TIP` | Changes the speed: normal, double, quadruple. | Wechselt das Tempo: normal, doppelt, vierfach. |
| `UI_ROTATE_TITLE` | Turn your phone upright | Dreh dein Telefon hochkant |
| `UI_ROTATE_BODY` | Doomsday is laid out for a phone held upright. The run waits until you turn it. | Doomsday ist für ein hochkant gehaltenes Telefon gebaut. Der Durchlauf wartet, bis du es drehst. |
| `UI_COACH_SITE_BODY_TOUCH` | Only outlined regions are possible. Tap a dimmed one and the note below says why not. Tap an outlined one and confirm in the panel. | Nur umrandete Regionen sind möglich. Tippe eine abgedunkelte an, dann steht unten, warum nicht. Tippe eine umrandete an und bestätige im Panel. |

**Revised:**

| Key | en | de |
| --- | --- | --- |
| `HELP_CONTROLS_P3` | On a phone: drag to move, pinch or tap twice to zoom, tap to select. Keep a finger on anything to see what it is — a region, a mark, a button. The menu button at the top has the technologies, containment, analysis and abilities. | Auf dem Telefon: Ziehen verschiebt, zwei Finger oder zweimal Tippen zoomen, Tippen wählt aus. Halte den Finger auf etwas, um zu sehen, was es ist – eine Region, ein Zeichen, einen Knopf. Der Menüknopf oben enthält Technologien, Eindämmung, Analyse und Aktionen. |

**Reused:** `UI_PAUSE_RESUME` (the paused pause button), `UI_HUD_SPEED_PAUSE`, `UI_HUD_SPEED_1/2/4`,
`UI_OVERLAY_LABEL`, `UI_MENU_TITLE`, `UI_HUD_MUTE` / `UI_HUD_UNMUTE`.

**German:** 15 tech names hyphenated and 4 renamed, §12.2 (done). **English:** `TECH_INDISPENSABILITY_NAME`
→ `Indispensa­bility`, **by S7.1** with the prompt strip.

---

## 15. Tests (S7.1)

Handheld behaviour is forced with `Device.handheld_override = 1` and reset in `after_each`. Touch
events are built in the test (`InputEventScreenTouch`/`Drag` with index, position, pressed,
relative, velocity) and fed with an explicit clock.

### 15.1 Unit

- `test_device.gd`: the override wins both ways; `-1` on the test machine is desktop.
- `test_touch_gestures.gd`, one behaviour each: a short still press is a tap · a press moved 9 px
  is a tap, 11 px a pan · a still press of 450 ms is a hold (from `poll`) and its release no tap ·
  hold then move is `HOLD_MOVE`, not pan · two taps 250 ms and 20 px apart are a double tap with one
  tap before it · 350 ms apart are two taps · 40 px apart are two taps · a second finger ends a pan
  and starts a pinch with the right scale and midpoint · back to one finger pans without a jump and
  ends with zero velocity · a third finger is ignored · `reset()` forgets all · a pan's end carries
  the mean velocity of the last three drags.
- `test_map_picker.gd`: `region_near` — on land returns `region_at`; 8 px off the Japanese coast
  returns `japan`; mid-Atlantic returns 0; the ring order is deterministic (a point between two
  regions returns the one on the earlier ring/angle).
- `test_map_camera.gd`: compact `zoom_min_for` is `vx / 4096`; full unchanged · compact start zoom
  at 400 × 860 is 400/1400 · `clamp_center` with a cover lets the view's bottom pass the map's by
  exactly `cover / zoom` · emulated mouse events (`DEVICE_ID_EMULATION`) are ignored · a pinch keeps
  the world point under the midpoint · a double tap targets zoom × 2, capped at `ZOOM_MAX`.
- `test_tech_node.gd`: **every name (en and de) has no unbroken piece wider than the compact
  card's text room** (measured with the theme's font, like §12.2) — replaces the English
  `KNOWN_OVERFLOW` exception for `indispensability`.
- `test_bench_prompt.gd`: a name with U+00AD appears in the brief without it.
- `test_help_pages.gd`: `paragraphs_handheld` shows only those paragraphs when handheld; an index
  out of range is a load error.
- `test_logical_scale.gd`: web handheld divides by the screen scale; a 320-dp width is lifted to
  360; desktop unchanged.

### 15.2 Integration (through `game/main.tscn`, 400 × 860)

- `test_touch_map.gd`: in site select, a touch tap on a dimmed region shows its reason in the
  prompt (tap-is-hover) · a hold on a region shows the hover line and selects nothing · a hold on
  an event marker shows its tooltip · a double tap zooms and keeps the selection.
- `test_touch_tips.gd`: a hold on the top bar's compute cell shows `UI_HUD_COMPUTE_TIP`; releasing
  does not activate anything (a hold on the pause button leaves the speed unchanged) · a hold on a
  locked tech node shows its lock reason · a tap still presses buttons · the tip hides on the next
  touch.
- `test_phone_hud.gd`: compact row 2 holds view switch, pause, speed, mute and menu, the four speed
  buttons and the paused chip hidden · the menu button opens the sheet in compact and the pause
  menu in full · the speed button steps 1→2→4→1 and resumes without stepping when paused · no
  strip readout caption is trimmed in German at 100 % (`_broken_words` / overrun check) · at 150 %
  the readouts are 2 × 2 · the coach ring's capabilities target is the top bar's menu button in
  compact.
- `test_sheet_swipe.gd`: a drag from the region panel's grab zone of 30 % of its height closes it
  (selection cleared); 10 % snaps back open; a fast short fling closes it; a drag inside its list
  scrolls and does not move the sheet.
- `test_region_reveal_compact.gd`: opening the region panel on Nigeria at the start zoom leaves
  Nigeria's anchor inside the uncovered rect (the shot's bug); closing it returns the camera into
  the plain bounds.
- `test_back_request.gd`: a `NOTIFICATION_WM_GO_BACK_REQUEST` closes the region panel, then opens
  the pause menu, then closes it; on the title with nothing open and `is_native_mobile` forced it
  asks to quit (a seam on the title, not a real quit); forced desktop: nothing.
- `test_app_background.gd`: `NOTIFICATION_APPLICATION_PAUSED` during a live run writes the
  autosave and opens the pause menu; `RESUMED` un-silences the master bus.
- `test_rotate_notice.gd`: web handheld forced, 860 × 400 → the notice shows and the hold is on;
  back to 400 × 860 → gone, hold off; a desktop window 860 × 400 → no notice.
- `test_safe_area.gd`: with a faked inset (a seam on `LogicalScale`), the title's first button,
  a modal and the bottom sheet's content sit inside it; the map does not move.
- `test_compact_tree_header.gd`: at 400 px the header is three rows, the title untrimmed in both
  languages, the tabs in one scrolling row; the detail title in German at 150 % has no word broken
  inside (`_broken_words`).

### 15.3 Web (`tools/web/web_check.py`, new check `touch`)

A Chromium context `412 × 915`, `device_scale_factor` 2.625, `has_touch`, `is_mobile`, en-US:
gate → *Start anyway* → `touchscreen.tap` through New run → Next → Next → Begin → a region →
*Start here*; the day advances (progress file). A two-finger pinch through CDP
`Input.dispatchTouchEvent` changes the zoom (the debug build's hook, or a screenshot difference).
Screenshots `touch_title.png`, `touch_session.png`. Not part of `--smoke`.

---

## 16. Acceptance

### 16.1 S7.1 is done when

1. A run is playable **by touch alone** in the 400 × 860 window (emulated touch, `Device` forced)
   from the title to the results, in English and German, at 100 % and 150 % — every tap target at
   least 48 px, nothing trimmed that §5 and §12 say must not be.
2. The shots of §5.1 are retaken (`user://session_<locale>_400_*.png` via F12) and show: no island
   on the map, the strip's captions whole, the tree header ≈ 140 px, the region panel not covering
   its region.
3. The web `touch` check passes in Chromium.
4. Every test of §15 is green; the suite is green.

### 16.2 What S7.2 / S7.4 check on the export

Portrait lock, immersive mode, back as §10.2, background autosave on a real app switch.

### 16.3 What S7.5 judges on the devices

The chrome's weight (UI q2), pinch feel and the tap slop, the hold time (450 ms), text size at
100 % on a small phone, the web build's speed in a phone browser (§13), battery and heat over a
30-minute run.
