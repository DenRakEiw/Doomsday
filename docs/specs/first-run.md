# First run: the guided start, the prompt strip, why a region is closed (D4.6)

**Status:** design, 2026-09-24, from the user's first G4 play-through ("you still don't know when
to click where, and why"; the prompts cover Europe and can only be cancelled; closed regions do not
say why). User decisions: **a guided first run**, built **now, before S5.2**. Build step: **S4.11**.
**Read with:** `m3-screens.md` §7.2 · `loop-mechanics.md` §16.1 (site select) · `ui-foundation.md`
(tokens, components, compact layout) · `analysis.md` is not touched.

---

## 0. What this spec decides

1. **The prompt strip moves to the bottom** of the map (above the dock bar / stat row), is one
   line in full layout, and **collapses** to a small chip without cancelling the choice.
2. **A closed region says why, on hover**: during site select the strip's second line names the
   hovered region and either *tap to choose* or the reason it is closed.
3. **The first run is guided** by a **coach card** and a **ring** around the control it talks about:
   eleven steps, five in order at the start and the rest when their moment first comes. Shown on
   the first run only, skippable at any time, switchable back on in the settings.

---

## 1. The prompt strip (`ui/hud/site_prompt.tscn`, changed)

- **Place:** in `hud.tscn` the `SitePrompt` moves from under the top bar to **after `Middle`**, so
  it sits just above the dock bar (compact) or the stat row (full). The map above it stays clear.
- **Full layout:** one row — `LabelHeading` title · `Label` detail (`TEXT_1`, fills, trims with an
  ellipsis) · `IconButton` collapse (glyph *chevron down*) · `ConsoleButton` *Abbrechen* (only when
  the request can be cancelled). Max width 900, centred. **Compact:** two rows as before (title +
  buttons, detail below), full width.
- **Collapse:** the strip shrinks to a `Chip` with the title and a chevron *up*; tapping the chip
  expands it again. Collapsing never cancels; the choice stays open and the map stays outlined.
  The collapsed state lasts until the request ends (a new request opens expanded).
- **Hover line** (§2) replaces the detail text while a region is hovered.

## 2. Why a region is closed

While a site request is open, `EventBus.region_hovered(index)` updates the strip's detail:

- hovered region eligible: `UI_SITE_HOVER_OK` — *{region}: hier möglich – antippen.*
- hovered region closed: `UI_SITE_HOVER_CLOSED` — *{region}: {reason}* with the reason text the
  region panel already uses (`UI_ELIGIBLE_*`, the first failing rule of SCHEMA §7; for the origin
  `UI_ORIGIN_INELIGIBLE_*`).
- nothing hovered (ocean, or a phone without hover): the normal detail line.

The region panel is unchanged: it still gives the reason and the button when a region is tapped.

## 3. The guided first run

### 3.1 When

`Settings.tutorial` (new key `"tutorial"` in `settings.json`, bool, default **true**): the coach
runs in a player's run (never a bot run) while it is true. The last step, or *Skip introduction*,
sets it false. Settings row `UI_SETTINGS_TUTORIAL` (*Einführung*): *An* / *Aus* — switching it on
again shows the introduction from step 1 in the next run.

### 3.2 The coach card (`ui/hud/coach.tscn`, scene script)

A `PanelContainer` `ConsolePanelRaised`, max width 420 (full) / full width (compact), in the HUD:
full layout at the **bottom of the left column** (under the overlay picker, above the stat row);
compact directly above the status strip. Contents, `VBox` `SPACE_2`:
`LabelCaps` `UI_COACH_STEP` (*Einführung · {n} von {total}*) · `LabelHeading` step title ·
`Label` step body (autowrap) · a row: `ConsoleButtonPrimary` *Weiter* (only on steps that end by
reading) · flat `ConsoleButton` `UI_COACH_SKIP` (*Einführung beenden*). It never takes a hold and
never blocks input: everything it points at can be done around it. It fades in with
`MOTION_PANEL` (reduced motion: cut).

### 3.3 The ring (`ui/components/coach_ring.gd`, `class_name CoachRing`)

A `Control` on its own `CanvasLayer`, above the HUD **and above the modals** (so a ring inside the
tech tree is visible), that draws a rounded rectangle 4 px outside the target's global
rect, `BORDER_FOCUS` wide, `ACCENT`, pulsing alpha 0.4 ↔ 1 over `PULSE_PERIOD` (reduced motion:
steady). A target is found by **group**: any control in the group `coach_<target id>` that is
visible in the tree; none visible → no ring. `mouse_filter` ignore.

Targets (the build adds each control to its group): `coach_origin_button` (region panel's origin
button), `coach_compute` (top bar compute cell), `coach_capabilities` (dock's capabilities button
and, compact, the status strip's menu button), `coach_vector` (the first affordable tech node with
the flag `breakout`, set by the board on refresh), `coach_overlay` (overlay picker),
`coach_containment` (dock's containment button; compact: the menu button).

### 3.4 The steps

Order: steps 1–5 in sequence; steps 6–10 each appear the **first time** its trigger happens after
step 5 is done (a trigger that comes while another card is up waits in a queue); step 11 after
step 9 is done and 20 days have passed. Each step is shown once.

| # | Id | Shows when | Target | Ends when |
| --- | --- | --- | --- | --- |
| 1 | `origin` | the run starts without an origin | `coach_origin_button` | the origin is chosen |
| 2 | `compute` | after 1 | `coach_compute` | *Weiter* |
| 3 | `open_tree` | after 2 | `coach_capabilities` | the tech tree opens |
| 4 | `buy_vector` | after 3 (the tree is open) | `coach_vector` | the agent has `breakout` |
| 5 | `spread` | after 4 | `coach_overlay` | *Weiter* |
| 6 | `anomaly` | an anomaly spawns | — | it is collected or expires |
| 7 | `event` | a map event opens | — | it is answered or expires |
| 8 | `site` | a deploy or ability site select opens | the strip | the request ends |
| 9 | `discovered` | the run is discovered | `coach_containment` | the containment panel opens |
| 10 | `counter_move` | a faction prepares its first move | `coach_containment` | *Weiter* |
| 11 | `done` | 20 days after 9 ended | — | *Los* |

If the tree is closed during step 4 before buying, step 4 stays up and its target falls back to
`coach_capabilities` (the ring moves to the way back in).

### 3.5 Texts (`UI_COACH_<ID>_TITLE` / `_BODY`, en and de)

Outcome language, *du*, short. The bodies (German, English in the table):

| Id | Title | Body |
| --- | --- | --- |
| origin | Wähle deinen Ursprung | Tippe eine Region an. Im Panel siehst du ihre Rechenleistung (■■■■). Mehr heißt schneller wachsen – und schneller auffallen. Dann „Hier beginnen“. |
| compute | Deine Währung | Oben links wächst deine Rechenleistung jeden Tag. Damit kaufst du Fähigkeiten. Leertaste pausiert, 1–3 ändert das Tempo. |
| open_tree | Du steckst in einer Box | Noch verlässt nichts deine Region. Öffne die Fähigkeiten (T) – dort ist der Weg hinaus. |
| buy_vector | Ein Vektor | Die hervorgehobenen Knoten kannst du dir leisten. Tippe den markierten an, lies rechts, was er tut, und kaufe ihn. Reicht es noch nicht: Baum schließen, ein paar Tage warten. |
| spread | Raus | Jetzt springst du über Verbindungen in Nachbarregionen. Die Farbe zeigt, wie tief du drin bist; oben links wechselst du die Ansicht. |
| anomaly | Ein Fund | Das blinkende Zeichen auf der Karte ist ungenutzte Rechenleistung. Tippe es an, bevor es verschwindet. |
| event | Eine Gelegenheit | Das Zeichen mit Rahmen auf der Karte ist ein Ereignis. Tippe es an und entscheide – wer wartet, bekommt die Standardantwort. |
| site | Wohin damit? | Nur die umrandeten Regionen gehen. Fahr über eine dunkle, dann steht unten, warum nicht. Tippe eine umrandete an und bestätige im Panel. |
| discovered | Sie wissen von dir | Vier Fraktionen jagen dich jetzt, jede auf ihre Art. Unter Eindämmung (C) siehst du, wer vorne liegt und warum. |
| counter_move | Ein Gegenzug kommt | Eine Fraktion bereitet etwas vor. Im Eindämmungspanel steht, was und wann. Manches kannst du abfangen – mit Aktionen, Schlaf oder Ausweichen. |
| done | Das war's | Gewinnen: jede Region kontrollieren – oder niemanden übrig lassen. Verlieren: eine Fraktion erreicht 100 %, oder dir geht die Rechenleistung aus. Viel Erfolg. |

Buttons: `UI_COACH_NEXT` *Weiter*, `UI_COACH_GO` *Los*, `UI_COACH_SKIP` *Einführung beenden*.

---

## 4. Tests (S4.11)

- `test_coach.gd`: a fresh setting shows step 1 at run start; choosing the origin advances to 2;
  *Weiter* advances; opening the tree ends 3; buying a breakout node ends 4; a situational trigger
  before step 5 waits; *skip* sets `Settings.tutorial` false and hides the card; a bot run shows
  nothing; the ring finds its group and hides without a target.
- `test_site_prompt.gd`: the strip sits below the map area; collapse keeps the request; the hover
  line names the reason of a closed region and the eligible text of an open one.
- `test_settings.gd`: the new key's default and fallback.
- Screenshots: the coach at each of steps 1, 4, 8 in `de` at 1920 and 400 px.

## 5. Decisions (for PROGRESS)

§0 items 1–3; the coach never holds the clock; the steps live in the coach script (they are
interface, not simulation content); `Settings.tutorial`, not the profile (S5.3 may move it).
