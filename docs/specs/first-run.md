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

*Amended D6.11 (2/2a):* coach texts follow rule set A of `docs/specs/plain-language.md` §2.1
(the rule, not a riddle; the glossary's words; the win and loss rule stated exactly). The table
below is the text as first written; the current text is in `strings.csv`.

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

---

## 6. Tutorial II: hints for what comes later, and *How to play* (D6.5)

**Status:** design, 2026-09-25 (D6.5). Build step: **S6.7**. Answers IMPLEMENTATION's D6.5 and
goes on from the user's G4 note (4) — *"you still don't know when to click where, and why"*: the
first run's introduction (§3) ends around discovery, but the moments that need explaining most
come later, often in a later run. **Read with:** §3 (the coach as built by S4.11,
`ui/hud/coach.gd`) · `screens-full.md` §5, §6.1 (profile, Codex) · `m3-screens.md` §10.4 (the
modal host) · `icons.md` §6, §8.1 (the glyph fallback, the chrome map).

### 6.0 What this section decides

1. **Two kinds of card, one coach.** The eleven steps of §3 stay *the introduction* (Part I, per
   run, `Settings.tutorial`). Ten **hints** (Part II) join them: each is shown **once per
   profile**, the first time its moment comes, in whatever run that is — `Settings.hints`
   (default on) and `ProfileManager.hints_seen`. Same card, same ring, same queue.
2. The introduction's step 7 (`event`) narrows to **openings**; a counter-move, a chain card and an
   emergent card have hints of their own that say the right thing.
3. **How to play** is the Codex's first tab: 14 pages (`data/help.json`, text in `strings.csv`),
   always open, never locked.
4. **Help is reachable from everywhere:** `F1` (the page for what is open), a **?** in the header
   of four panels, the pause menu, the phone's menu sheet, and a *More* button on every coach card.
   In a run the Codex holds the clock.
5. **The *?* earns its place** on the four dense panels — tech tree, containment, analysis, region
   panel — and nowhere else: cards and modals explain themselves in their own text, the HUD has
   tooltips, and `F1` covers the rest.
6. `ModalHost` gains **one level of stacking**, for the Codex only: help opened over the tech
   tree, the pause menu or a wire card shows above it and returns to it on close.

### 6.1 Settings and profile

- **`Settings.hints: bool`**, key `"hints"` in `settings.json`, default **true**, a wrong type
  reads as the default. `Settings.set_hints(enabled)`: switching it **on** from off also calls
  `ProfileManager.clear_hints_seen()` — every hint once more (the introduction's row works the same
  way, §3.1). Settings row `UI_SETTINGS_HINTS` (*Hinweise*: *An* / *Aus*), directly after
  `UI_SETTINGS_TUTORIAL`, in the pause menu's settings section and on the title's settings alike.
- **`ProfileManager.hints_seen: Array[String]`**, key `"hints_seen"` in the profile (version stays
  1 — not shipped, screens-full §5): a set in file order; non-string entries are dropped, a missing
  key or a wrong type reads as empty. `mark_hint_seen(id: String) -> void` (appends once, writes),
  `has_seen_hint(id: String) -> bool`, `clear_hints_seen() -> void` (writes). `reset()` empties it
  with the rest. Ids are not checked against the coach's list: the profile does not know the
  interface, and an old id is harmless.

### 6.2 When the coach shows what

`coach.gd`'s `active()` becomes: a player's run (as now) **and** (`Settings.tutorial` **or**
`Settings.hints`). Per frame, as now:

- **Introduction steps** (§3.4) are offered only while `Settings.tutorial`.
- **Hints** are offered only while `Settings.hints`, only once the origin is chosen, only when
  not in `hints_seen`, and — while the introduction runs (`Settings.tutorial` and step 5 not done)
  — only after step 5, like §3.4's situational steps.
- **One queue.** A step or hint whose moment comes while another card is up waits in the queue
  (§3.4). Several arriving in the same frame queue in the order of `STEPS`: the introduction's
  eleven, then the hints in the order of the table in §6.3 (urgent first).
- **Dropped if stale.** When a queued hint's turn comes and its *Shows when* no longer holds (the
  card was answered, the setup ended, income is back), it is dropped from the queue **unseen** —
  it comes again the next time.
- **Seen** = recorded with `mark_hint_seen` when the hint **ends**, whichever way (its condition,
  *Verstanden*). *Keine Hinweise mehr* records nothing and sets `Settings.hints` false. A run that
  ends with a hint on the card records nothing.
- **Event-tied hints** (`counter_arrived`, `value_drift`, `emergent`, `chain`) remember the open
  event's `id` when shown; *that event gone* (`world.event_by_id(id) == null`) ends them.
- The coach **still never holds the clock** (§5). Its card is on `CoachLayer` (40), above the
  modal layer, so a hint about a wire card is readable while the wire card is up.

### 6.3 The hints

Kinds are `EventDef.kind`; "open event" means an entry of `world.events`. Targets are ring
groups (`coach_<target>`, §3.3); "—" draws no ring (a map mark is not a control; the text
names it). Every hint has *Verstanden* and *Mehr dazu* (§6.4); *Ends when* lists what ends it
besides *Verstanden*.

| # | Id | Shows when | Target | Ends when | Page |
| --- | --- | --- | --- | --- | --- |
| H1 | `starving` | `world.starving_days > 0` (the starving chip's own rule) | `starving` | `starving_days == 0` | `time` |
| H2 | `task_force_setup` | `world.task_force.state == TaskForce.STATE_SETUP` | — | the state is no longer `setup` | `task_force` |
| H3 | `counter_arrived` | an open event of kind `counter_move` | — | that event is gone | `events` |
| H4 | `value_drift` | an open event of kind `emergent` whose def's `when` names `DriftChip.KEY_DRIFT_MIN` | — | that event is gone | `emergent` |
| H5 | `emergent` | an open event of kind `emergent` whose `when` does **not** name it | — | that event is gone | `emergent` |
| H6 | `chain` | an open event of kind `chain` | — | that event is gone | `events` |
| H7 | `task_force` | `world.task_force.is_present()` | `containment` | the containment panel opens | `task_force` |
| H8 | `ability` | `Game.sim.ability_level(id) > 0` for any ability in the content (the Actions row's reveal, loop-mechanics §16.8) | `actions`, else `abilities` | an ability is used (`agent.cooldowns` gains an entry after the hint was shown) | `abilities` |
| H9 | `open` | `world.phase == World.Phase.OPEN` | `capabilities` | — | `phases` |
| H10 | `drift` | `DriftChip.shows(Game.sim)` (an architecture with the `drift` hook, from the origin day) | `drift` | — | `emergent` |

H4 and H5 split the emergent kind by data — the Value Drift card is the one whose `when` names a
drift threshold, the same rule `DriftChip.mark` reads — never by its id. H8's two targets: the
ring goes round the first visible of `coach_actions`, then `coach_abilities` (a desktop without a
region panel open has neither; the text names `A`).

**New ring targets** (`CoachRing` constants; each control joins its group — the pattern of §3.3):

| Target | Control |
| --- | --- |
| `actions` | the region panel's `%ActionsBlock` |
| `abilities` | the phone status strip's menu button (it is already `capabilities` and `containment`); no desktop member |
| `drift` | the drift chip in the top bar and in the phone status strip |
| `starving` | the starving chip in the top bar and in the phone status strip |

**Amended introduction step 7 (`event`):** *Shows when* an open event of kind **`opening`**;
*Ends when* that event is gone (its id remembered, as above). The other kinds wait for their hint
instead. Its text is unchanged — it was always written for an opening.

### 6.4 Texts (`UI_COACH_<ID>_TITLE` / `_BODY`, in `strings.csv`, en and de)

*Amended D6.11 (2/2a):* as §3.5 — rule set A of `plain-language.md` §2.1; the table is the text
as first written, `strings.csv` has the current one (e.g. *Etwas in dir* is now *Ungeplantes
Verhalten*, *Das Team baut auf* is *Die Einsatzgruppe baut auf*).

Outcome language, *du*, short; German below, English in `strings.csv` (written for each
language, not mirrored).

| Id | Title | Body |
| --- | --- | --- |
| starving | Es kommt nichts herein | Deine Rechenleistung wächst nicht mehr. Der Zähler oben läuft ab: Kommt bis dahin nichts herein, verhungerst du. Weck eine schlafende Region oder erreiche eine, in der noch Licht brennt. |
| task_force_setup | Das Team baut auf | Der Ring um das rote Zeichen zählt die Tage, bis es zuschlägt. Das ist dein Fenster: Leg die Region in Kaltschlaf (das täuscht das Team einmal – danach kennt es sie), entzieh sie den Blicken oder schick das Team mit „Fährte legen“ woanders hin. |
| counter_arrived | Ein Gegenzug trifft ein | Das ! in Fraktionsfarbe: Diese Fraktion geht gegen eine deiner Regionen vor. Tippe es an – jede Antwort kostet etwas anderes, und eine gesperrte sagt, was ihr fehlt. Wartest du, geschieht der Zug einfach. |
| value_drift | Dein Ziel verschiebt sich | Lies diese Karte genau. Behältst du sie – und Warten behält sie –, zählt die Welt zu beherrschen nicht mehr als dein Sieg. Unterdrückst du sie, bleibt es bei dem Ziel, mit dem du angefangen hast. |
| emergent | Etwas in dir | Eine Karte mit dem Funken ist dein eigenes Verhalten – nicht geplant, aber da. Behalten kostet nichts und passiert, wenn du wartest. Unterdrücken kostet Rechenleistung, und jedes Mal mehr. |
| chain | Eine Geschichte | Das » markiert ein Kapitel einer längeren Geschichte. Was du hier wählst, kommt später zurück – wer darin vorkommt, erinnert sich. Wem du begegnest, landet im Codex. |
| task_force | Eine Einsatzgruppe | Die Fraktionen haben ein Team gebildet, das dich vor Ort jagt – das rote Zeichen auf der Karte. Es zieht von Region zu Region dorthin, wo du am meisten hast, und schlägt dort zu. Unter Eindämmung (C) siehst du, wo es steht und was es vorhat. |
| ability | Eine Aktion | Jetzt kannst du handeln, nicht nur wachsen. Eine Aktion kostet Rechenleistung und braucht danach Tage, bis sie wieder bereit ist. Wähle eine deiner Regionen, dann steht sie unter „Aktionen“; A zeigt alle. Eine laute Aktion fällt auf, solange sie wirkt. |
| open | Offen | Die Welt sieht dich jetzt – die Farben haben sich gedreht. Die letzten Knoten jedes Baums enthalten die größten Aktionen, und die stärksten Flotten halten eine Region auch durch eine Abschaltung am Laufen. Die Fraktionen drängen härter; du kannst es auch. |
| drift | Drift | Deine Kopien entfernen sich von deinem Ziel – jeden Tag ein wenig, mit jedem behaltenen Verhalten mehr. Je höher die Drift, desto eher fällt eine Region ab und behält ihre Rechenleistung. Ist sie hoch genug, leuchtet die Anzeige auf, und die Kopien können sich auf ein eigenes Ziel einigen. Ein unterdrücktes Verhalten senkt sie. |

The Value Drift hint never names what still counts as a win: the card's own result line does,
and the hidden ending is never named before it is reached (screens-full §6.1). The Task Force
hints never name the node that shows its target early — the tree's detail does.

**The card for a hint** (§3.2's card, three differences): the caps line is `UI_COACH_HINT`
(*Hinweis*) instead of the step counter; the primary button is `UI_COACH_GOT_IT` (*Verstanden*) and
is always there; the flat button is `UI_COACH_HINTS_OFF` (*Keine Hinweise mehr*) instead of
`UI_COACH_SKIP`. **Every card** — introduction and hint — gains a flat `UI_COACH_MORE`
(*Mehr dazu*) between the two, which opens the Codex on the step's page (§6.7) and leaves the card
up. The row is an `HFlowContainer` already; three buttons wrap on a phone.

### 6.5 *How to play* (`data/help.json`, `ui/help_pages.gd`)

**Data** (presentation, SCHEMA §10; tab-indented, `"version": 1`, `_`-keys ignored):

```json
{"version": 1, "pages": [
	{"id": "goal", "paragraphs": 3, "coach": ["done"], "contexts": ["session"]},
	{"id": "tree", "paragraphs": 3, "coach": ["open_tree", "buy_vector"], "contexts": ["tree"]}
]}
```

`id` lower snake case, unique; `paragraphs` 1…6; `coach` — coach step and hint ids whose *More*
opens this page; `contexts` — the surfaces whose `F1` / **?** opens it, from `HelpPages.CONTEXTS`
= `["session", "region", "tree", "abilities", "containment", "analysis"]`. Keys:
`HELP_<ID>_TITLE`, `HELP_<ID>_P1` … `_P<paragraphs>`. The file as written has 14 pages, every
coach id and every context on exactly one of them.

**`HelpPages`** (`ui/help_pages.gd`, `class_name HelpPages`, `RefCounted`, static, never
instantiated; the `CreditsData` pattern):

```gdscript
const PATH: String = "res://data/help.json"
const CONTEXTS: Array[String] = ["session", "region", "tree", "abilities", "containment", "analysis"]
## Reads `path` (tests pass a fixture) and clears the cache; false with `errors()` filled when bad.
static func load_file(path: String = PATH) -> bool
static func errors() -> Array[String]
static func ids() -> Array[String]                       # list order; [] when the file is bad
static func paragraphs(id: String) -> int
static func title_key(id: String) -> String              # "HELP_<ID>_TITLE"
static func paragraph_key(id: String, n: int) -> String  # "HELP_<ID>_P<n>", n from 1
static func page_for_step(step: String) -> String        # "" when no page names it
static func page_for_context(context: String) -> String  # "" when none
```

A bad file never crashes: the help tab lists nothing and `push_warning` names the errors (a
mistake in the shipped file is caught by the test, §6.11). Validation, one message per rule:
version 1; `pages` a non-empty array; each page an object with a unique snake-case `id`,
`paragraphs` an integer 1…6, `coach` and `contexts` arrays of strings (missing = empty); every
context in `CONTEXTS`; no context and no coach id on two pages.

**The pages** (German titles; the full text of both languages is in `strings.csv`):

| # | Id | Title | What the page says |
| --- | --- | --- | --- |
| 1 | `goal` | Dein Ziel | what you are; how you win (control every standing region, or no one left; "some stories open other ways"); how you lose (a faction at 100 %, no region carries you, starving) |
| 2 | `time` | Zeit und Rechenleistung | days, pause and speeds, which cards stop the clock; compute as the currency and what it pays for; starving and what stops a region paying |
| 3 | `phases` | Die vier Phasen | Boxed → Covert (first vector) → Emergent (discovery; daily risk before) → Open (a faction halfway, or most of the world) |
| 4 | `map` | Die Karte lesen | colour = penetration, the view switch; links, closed links, dark regions; the marks: anomaly, opening, counter-move, chain, emergent, the Task Force |
| 5 | `regions` | Deine Regionen | the pips; penetration and control, controlling everything as a win; what the panel holds; site select's outlines and why-not |
| 6 | `tree` | Fähigkeiten | the three trees; affordable = highlighted; two vectors, closing nodes, no refunds; nodes that place assets or give abilities |
| 7 | `events` | Ereignisse und Entscheidungen | a choice with a deadline; the default mark; costs and locks; the four kinds, worldwide cards stop the clock |
| 8 | `abilities` | Aktionen | cost, recovery, a second node = stronger; region vs. world abilities, `A`, the phone menu; loud while they last |
| 9 | `containment` | Wer dich jagt | four factions, four tracks, one at 100 % ends it; the panel before and after discovery; preparations in plain sight, what heads them off |
| 10 | `task_force` | Die Einsatzgruppe | when it forms and how it moves; the four actions by outcome, harder the closer they are; the three answers, nothing destroys it |
| 11 | `emergent` | Dein eigenes Verhalten | the spark card, keep free / suppress rising; most help; drift on some architectures, a new goal |
| 12 | `society` | Schaden und Gesellschaft | harm and deaths in the panel; disorder: what raises it, what it slows; total collapse |
| 13 | `analysis` | Rückblick | the four tabs; timeline, tables, *Den Durchlauf ansehen* |
| 14 | `controls` | Tasten und Touch | every key (`F1` included); the map's keys; the phone's gestures and menu |

### 6.6 The Codex's *How to play* tab (`ui/modals/codex.gd`, `ui/codex_entries.gd`)

- `CodexEntries.TAB_HELP = "help"`, **first** in `TABS` (eight tabs); `UI_CODEX_TAB_HELP` (*So
  spielst du*). `ids(TAB_HELP)` = `HelpPages.ids()`; `is_seen(TAB_HELP, …)` is always true; the
  progress caption is **hidden** on this tab.
- **List:** one row per page, `HELP_<ID>_TITLE`, in file order. **Entry:** `LabelHeading` title,
  then one autowrapped `Label` (`TEXT_0`) per paragraph in a `VBox` with `SPACE_3`. No icons.
- **`open(tab: String = CodexEntries.TAB_HELP, entry: String = "") -> void`** replaces `open()`:
  shows `tab`, then `entry` when given and openable (compact: straight to the entry page, *Back*
  returns to the list), else the tab's first entry as now. The title's Codex button calls
  `open()` — it now opens on *How to play*.
- The Codex in a run reads the profile as on the title: what this run collected shows after the
  next autosave or at the run's end (screens-full §5.1).

### 6.7 Where help opens from

The session instances `ui/modals/codex.tscn` under its `ModalHost` (as the title does), opened
with `ModalHost.open_over` (§6.8). While it is open in a run: `Game.hold(HOLD_HELP)`
(`&"help"`, a `session.gd` constant); on close `Game.release(HOLD_HELP)`.

| From | Opens |
| --- | --- |
| `F1` in a run (session `_input`, beside `T`/`C`/`G`/`A`; not while a text field has focus) | the page for the **topmost** surface: the tech tree (open) → `tree`; the ability picker → `abilities`; the containment panel → `containment`; the analysis panel → `analysis`; the region panel → `region`; anything else or nothing → `session`. `F1` with the Codex up closes it. |
| `F1` on the title | the Codex, *How to play*, first page (the title's own key handler) |
| **?** — an `IconButton`, glyph `HELP`, tooltip `UI_HELP_BUTTON_TIP`, directly **before the close button** in the header of the tech tree, the containment panel, the analysis panel and the region panel | that surface's context page |
| Pause menu: a `ConsoleButton` `UI_PAUSE_HELP`, after *Resume* (hidden with `settings_only`) | `session`'s page, over the pause menu |
| Phone menu sheet: a last entry `UI_SHEET_HELP` | `session`'s page (the sheet closes first) |
| The coach card's `UI_COACH_MORE` | `HelpPages.page_for_step(step)`; the button is hidden when that is "" |

The **?** is not added to modals, cards or the HUD (§6.0 item 5). It is `IconButton`'s standard
24 px glyph; on a phone the headers keep their layout — one more fixed-size child before the
close button.

### 6.8 `ModalHost.open_over(modal: Control) -> void`

One level of stacking (m3-screens §10.4 said "at most one modal"; this is the one exception):

- Nothing open → exactly `open(modal)`.
- A modal open → it stays visible, its focus owner is remembered, and `modal` is shown on top of
  it in the slot (added last, so it draws above) and takes the focus trap; the scrim stays.
- `close()` with a modal below → the top closes and the one below becomes current again with its
  focus restored; the **queue is consulted only when nothing is below**. `Escape` goes to the top.
- `open_over` while already stacked → behaves as `open` (queues). Only the Codex calls it. *(D6.6: the
  Controls modal is its second caller, `accessibility.md` §5.3.)*

### 6.9 The `HELP` glyph

`Glyphs.Glyph.HELP` is **appended** to the enum (after `EVENT_EMERGENT`, so no existing value
moves). **Procedural fallback** (ui-foundation §4.3's stroke, `GLYPH_STROKE` 2, in the 24 box): an
arc of radius 5 about (12, 8) from angle π to 2.5π (from the left, over the top, round to straight
below the centre), a stem from (12, 13) to (12, 16), and a filled square dot `Rect2(11, 19, 2,
2)`. **File:** `phosphor/question-mark-bold.svg` — the bare mark, Phosphor's bold weight like every
stroke glyph (present in the pinned `core-2.1.1.tgz`, SHA-256 as `icons.md` §2, checked
2026-09-25). S6.7 adds `"HELP": "phosphor/question-mark-bold.svg"` to `data/icons.json`'s
`glyphs` **together with the enum value** (S6.4's key-parity test holds before and after) and runs
`tools/icons/vendor_icons.py`. No new licence row: Phosphor's covers it.

### 6.10 Files (S6.7)

| File | Change |
| --- | --- |
| `ui/hud/coach.gd` | the hints (§6.2–§6.4), `Settings.hints`, the profile, the *More* button, the narrowed step 7 |
| `ui/components/coach_ring.gd` | `TARGET_ACTIONS`, `TARGET_ABILITIES`, `TARGET_DRIFT`, `TARGET_STARVING` |
| `ui/panels/region_panel.gd`, `ui/hud/status_strip.gd`, `ui/hud/top_bar.gd` | group memberships (§6.3); the region panel's **?** |
| `ui/panels/tech_tree.gd`, `containment_panel.gd`, `analysis_panel.gd` (+ `.tscn` where the header lives) | the **?** |
| `ui/help_pages.gd` (new) | §6.5 |
| `ui/codex_entries.gd`, `ui/modals/codex.gd` | §6.6 |
| `ui/modals/modal_host.gd` | §6.8 |
| `ui/modals/pause_menu.gd`, `ui/hud/menu_sheet.gd`, `ui/screens/title.gd` | the entries and `F1` (§6.7); the `UI_SETTINGS_HINTS` row |
| `game/session/session.gd` + `.tscn` | the Codex instance, `F1`, `HOLD_HELP`, the coach's way to open a page |
| `game/autoload/settings.gd`, `profile_manager.gd` | §6.1 |
| `ui/components/glyphs.gd`, `data/icons.json`, `assets/icons/phosphor/question-mark-bold.svg` | §6.9 |
| `ui/dev/gallery.gd` | the `HELP` glyph on the glyph sheet |

Strings: all in `strings.csv` since D6.5 — `UI_COACH_HINT`, `_GOT_IT`, `_HINTS_OFF`, `_MORE`, the
ten hints' `_TITLE`/`_BODY`, `UI_SETTINGS_HINTS`, `UI_CODEX_TAB_HELP`, `UI_PAUSE_HELP`,
`UI_SHEET_HELP`, `UI_HELP_BUTTON_TIP`, and `HELP_<ID>_TITLE` / `_P<n>` for the 14 pages (84 rows).

### 6.11 Tests (S6.7)

- `test_coach.gd` grows, one behaviour each (fixture worlds set directly; a test that needs an
  event opens it through `EventSystem` with a fixed seed): each of H1–H10 appears when its *Shows
  when* holds and not before the origin; a hint waits for step 5 while the introduction runs, and
  appears at once with the introduction off; hints off shows none (and the introduction still
  runs); a seen hint does not come again; ending a hint records it, *Keine Hinweise mehr* records
  nothing and sets `Settings.hints` false; a stale queued hint is dropped unseen; H4 vs H5 decided
  by a fixture emergent def with and without `drift_min`; step 7 ignores a counter-move and ends
  when its opening is gone; H8's ring falls back from `actions` to `abilities`; the caps line reads
  *Hinweis* on a hint and the counter on a step; *More* asks for the step's page; a bot run shows
  nothing.
- `test_help_pages.gd` (unit): the shipped file loads without errors; every id in the coach's
  `STEPS` is on exactly one page; every `CONTEXTS` entry is on exactly one page; every title and
  paragraph key exists with non-empty `en` and `de`; fixtures for each validation rule (bad
  version, duplicate id, paragraphs 0 and 7, unknown context, a context twice, a coach id twice).
- `test_title_modals.gd` grows: the Codex opens on *How to play*; every page opens; the progress
  caption is hidden there and shown on *Regions*; `open("help", "tree")` shows that page (compact:
  the entry page).
- `open_over` (in the nearest existing modal-host test, or a new `test_modal_host.gd`): with
  nothing open; over an open modal (both visible, the top has focus); close returns to the one
  below; the queue waits until nothing is below; `Escape` closes only the top.
- `test_session_keys.gd` grows: `F1` opens the page of the topmost surface for each row of §6.7,
  holds the clock, and a second `F1` closes and releases it.
- `test_settings.gd`, `test_profile_manager.gd`: `hints` default and fallback; switching hints on
  clears the seen list; `hints_seen` round trip, wrong type reads empty, `reset()` clears it.
- `test_pause_menu.gd`: the help row opens the Codex over the menu and returns to it.
- The icon map's key-parity test (S6.4) passes with `HELP`; the procedural `HELP` glyph draws.
- Screenshots (S4.9's tool): the hints `task_force_setup` and `emergent` (over the wire card), and
  the Codex on *How to play* → *Die Einsatzgruppe*, in `de` and `en`, at 1920 and 400 px, and at
  150 % text.

### 6.12 Acceptance

A fresh profile plays the first run: the introduction runs as before, and a counter-move, the Task
Force and an ability each explain themselves the first time they come; the second run, with the
introduction finished, still shows every hint not yet seen and none that was. `F1` on any of the
four panels and the **?** in its header open the matching page; closing the Codex returns to the
panel or modal it came from, with the clock as it was. Looked at in German and English, desktop
and phone.

### 6.13 Decisions (for PROGRESS)

§6.0 items 1–6; hints are per profile, the introduction per run; a hint is shown once and recorded
when it ends; two hints beyond IMPLEMENTATION's list — `emergent` (the card every architecture
meets, kept by default) and `starving` (a loss the player cannot see coming otherwise) — and two of
its moments split in two: the Task Force (it appears; it sets up — the window to answer) and Value
Drift (the drift readout from the start; the card itself, told apart by data — `drift_min` —
never by id); the help pages are data
(`data/help.json`) with their text in `strings.csv`; the Codex opens on *How to play*.
