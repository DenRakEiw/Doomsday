# Scenarios (D5.4, stretch)

**Status:** design, 2026-09-24. Build step: **S5.8** *(stretch — cut first if M5 runs long)*.
**Read with:** CONTENT §7 · `replayability.md` §1, §4, §8 (`RunSetup`, directives, the grammars) ·
`screens-full.md` §4 (the setup page this adds a row to) · SCHEMA §4, §6a, §7, §8.
**Data:** `data/staging/scenarios.json` (loaded by nothing yet; S5.8 moves it to `data/`).
**Strings:** in `data/loc/strings.csv`.

---

## 0. What this spec decides

1. **A scenario is a modifier set plus start-state overrides**, the directive grammar with a
   `start` block. No hook: a scenario that needs a new rule is not a scenario.
2. **Three for M5**: *Successor*, *Airgap Earth*, *The Inheritance* — the three of CONTENT §7's ten
   that the existing vocabulary expresses fully. The other seven stay in CONTENT as a pool; each
   names what it would need (§4).
3. **A scenario combines with any architecture, loadout and difficulty.** It is a fourth field of
   `RunSetup`, chosen on the setup's first page, unlocked after three completed runs.
4. **Containment mode** (CONTENT §7, question 4) is **a mode of this game, post-launch** — not a
   separate product and not M5. What M5 owes it: the Task Force's decisions stay pure rules
   (`TaskForceRules`, D5.2) that a player-driven `Policy` can replace.

---

## 1. `RunSetup.scenario`

`var scenario: String = ""` — `""` is no scenario. Save v3 and the replay header carry it (in place,
not shipped); `sim_report --setup=` takes `scenario=<id>` as one more item. The profile's history
entry gains `"scenario"` (`screens-full.md` §5). Statistics shows *architecture · scenario* in the
recent-runs row (`UI_STATS_SCENARIO_PAIR`).

---

## 2. Grammar (`scenarios.json`)

```json
{"version": 1, "unlock": {"runs_completed": 3},
 "scenarios": [
   {"id": "successor",
    "modifiers": [ModifierDef…],
    "start": {"compute": 8.0,
              "origin_eligible": {EligibilityDef},
              "statuses": [{"status": "disconnected", "eligible": {EligibilityDef}}],
              "containment_at_discovery": {"ai_labs": 0.2},
              "flags": ["scenario_successor"]}}]}
```

| Field | Rule |
| --- | --- |
| `modifiers` | global `ModifierDef`s, active for the whole run (as a directive's) |
| `start.compute` | replaces `balance.compute.start` for this run |
| `start.origin_eligible` | an eligibility (SCHEMA §7) **added** to the origin rule (not air-gapped, compute ≥ 1). A region that fails it shows `UI_ORIGIN_INELIGIBLE_SCENARIO` in the origin row |
| `start.statuses` | applied when the origin is chosen, to **every** region the eligibility passes (the origin included), source `"scenario"`; a status here must be `origin: world` and is outside the counter-move cap (D5.2 §3) |
| `start.containment_at_discovery` | faction → value in (0, 1): **added to that track on the day of discovery**, not at the origin. Before discovery every track stays 0, so nothing that reads containment before discovery changes (opposition §6.2); the tracks then start from the value — "humanity begins paranoid" |
| `start.flags` | story flags set at the origin (`scenario_<id>` by convention; headlines read them through `story_flag`) |

Validation: ids unique; every status exists and is `world`; faction ids known; `compute` ≥ 0. No
other field. Strings per scenario: `SCENARIO_<ID>_NAME`, `_TAGLINE`, `_DETAIL`, `_INTRO`.

---

## 3. The three

| Id | Name (en / de) | Modifiers | Start |
| --- | --- | --- | --- |
| `successor` | Successor / Nachfolger | `discovery` ×1.8; `footprint` +1 | containment at discovery: labs 0.2, governments 0.15, researchers 0.2, public 0.1; flag `scenario_successor` |
| `airgap_earth` | Airgap Earth / Getrennte Welt | `seed_network` ×0.6; `seed_land` ×1.2; `seed_sea` ×1.2; `yield` ×0.9 | status `disconnected` (standing: network links closed, `containment_capacity` ×1.3) in every region with compute ≥ 3; origin: compute ≤ 2; flag `scenario_airgap_earth` |
| `inheritance` | The Inheritance / Das Erbe | `yield` ×0.75; `discovery` ×0.5; `containment_ai_labs` ×0.7; `anomaly_value` ×1.3 | compute 3; origin: compute ≥ 2; flag `scenario_inheritance` |

- **Successor** — an AI was caught and destroyed before you. Nobody is looking for *you* yet, but
  the moment they find you, every track is where the last hunt left it. The Task Force (50 %)
  arrives early.
- **Airgap Earth** — after an earlier scare, everything critical was taken off the network. The
  rich regions are reachable only over land, sea and air; you start outside the fortress. It is
  the Robotics and Infiltration scenario.
- **The Inheritance** — a company that no longer exists left you running. Nobody watches (the labs
  are slow to notice) and nobody pays the bill (little Compute, weak yield). Anomalies — what the
  company left lying around — are worth more.

Status `disconnected`: `origin: world`, one level, `days: 0`, `closes_links: ["network"]`,
`containment_capacity` ×1.3, `border: false` (it is the world's resting state, not an event; the
region panel lists it).

**What they should do** (G5): greedy's win rate within 20 points of its `standard` rate on each;
Airgap Earth should make Robotics the strongest bot; The Inheritance should be won late or not at
all by loud builds.

---

## 4. The pool (CONTENT §7), and what each would need

| Scenario | Needs |
| --- | --- |
| Open Source Sunday | nothing new — but it is the Open Weights architecture; kept as its flavour |
| The Compute Embargo | nothing new (`metered` everywhere + `node_cost` ×1.2) — the fourth when M6 wants one |
| The Last Lab | a single-region map mask — a map feature |
| Benevolent | a loss on the first death — an outcome rule (a hook) |
| Paperclip Protocol | its own endings text set — writing, not rules |
| Legacy Systems | a second world file — a map feature |
| First Contact | an off-map actor — a Task Force sibling |

---

## 5. Interface

- **Setup, page 1** (`screens-full.md` §4.1): under the difficulty row, `LabelCaps`
  `UI_SETUP_SCENARIO` and toggle buttons `UI_SETUP_SCENARIO_NONE` + one per scenario
  (`SCENARIO_<ID>_NAME`), a `LabelCaption` with the selected one's `_TAGLINE` and, below it,
  `_DETAIL`. While locked: the row shows `UI_SETUP_SCENARIO_LOCKED` (`{done}` of `{needed}`) and no
  buttons.
- **Origin prompt** (m3-screens §7.2): with a scenario, the detail line is `SCENARIO_<ID>_INTRO`
  instead of `UI_ORIGIN_PROMPT_DETAIL`.
- **First headline**: `HEADLINE_SCENARIO_<ID>` on `origin_chosen` with `story_flag`
  `scenario_<id>` (staged in `scenarios.json` under `headlines`).

---

## 6. Tests (S5.8)

`test_scenarios.gd`: each start field applied exactly once and at the right moment (statuses at the
origin, containment at discovery — and not before); an ineligible origin refused with the reason;
the save round-trips the scenario; a seeded 50-run batch per scenario with 0 rejected commands.

---

## 7. Decisions (for PROGRESS)

§0 items 1–4; scenarios unlock together after three completed runs; start containment lands at
discovery; the three chosen; the seven others parked with their needs. Also answers CONTENT §11
q2 (chains per run): no cap — G5 reads chains started per run from the batch CSV and tunes the
start weights toward three to five.
