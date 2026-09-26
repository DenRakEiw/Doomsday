# Scenarios (D5.4, stretch)

**Status:** design, 2026-09-24. Build step: **S5.8** *(stretch — cut first if M5 runs long)*.
**D5.5 (2026-09-25) added §8 — Airgap Earth's and The Inheritance's levers (`closed_cross`,
`term_scale`), built by S5.9.**
**Read with:** CONTENT §7 · `replayability.md` §1, §4, §8 (`RunSetup`, directives, the grammars) ·
`screens-full.md` §4 (the setup page this adds a row to) · SCHEMA §4, §6a, §7, §8.
**Data:** `data/scenarios.json` (moved out of staging and loaded in S5.8, with the `disconnected`
status in `statuses.json` and the three headlines in `headlines.json`; grammar in SCHEMA §6j).
**Strings:** in `data/loc/strings.csv`.

---

## 0. What this spec decides

1. **A scenario is a modifier set plus start-state overrides**, the directive grammar with a
   `start` block. No hook: a scenario that needs a new rule is not a scenario. *(D5.5: the
   vocabulary grew by one modifier target and one field — §8 — both data, still no hook.)*
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
| `term_scale` *(D5.5, top level)* | `[{"faction", "source", "mul"}]`: that faction's terms of that source count `mul` × their weight for the whole run (§8.2) |

Validation: ids unique; every status exists and is `world`; faction ids known; `compute` ≥ 0. No
other field. Strings per scenario: `SCENARIO_<ID>_NAME`, `_TAGLINE`, `_DETAIL`, `_INTRO`.

---

## 3. The three

| Id | Name (en / de) | Modifiers | Start |
| --- | --- | --- | --- |
| `successor` | Successor / Nachfolger | `discovery` ×1.3 *(G5 2/3; was ×1.8 and `footprint` +1)* | containment at discovery: labs 0.1, governments 0.08, researchers 0.1, public 0.05 *(halved at G5 2/3)*; flag `scenario_successor` |
| `airgap_earth` | Airgap Earth / Getrennte Welt | `seed_network` ×0.6; `seed_land` ×1.4; `seed_sea` ×1.3 *(G5 2/3; was ×1.2, ×1.2 and `yield` ×0.9)*; **`closed_cross` +0.5 where a fleet stands** *(D5.5, §8.1)* | status `disconnected` (standing: network links closed; its `containment_capacity` ×1.3 removed at G5 2/3) in every region with compute ≥ 3; origin: compute ≤ 2; flag `scenario_airgap_earth` |
| `inheritance` | The Inheritance / Das Erbe | `yield` ×0.65; `discovery` ×0.85; `containment_ai_labs` ×0.85 *(G5 2/3; were ×0.75, ×0.5, ×0.7)*; `anomaly_value` ×1.3; **`term_scale`: public `deaths_share` ×2, governments `harm` ×6** *(D5.5, §8.2; `harm` ×2 → ×6 at G6 1/2)* | compute 3; origin: compute ≥ 2; flag `scenario_inheritance` |

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
no modifiers (G5 2/3 removed `containment_capacity` ×1.3), `border: false` (it is the world's resting state, not an event; the
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

---

## 8. D5.5 — the two levers (S5.9)

*Added 2026-09-25 (D5.5), answering BALANCE §5.7 (4): Airgap Earth does not make Robotics the
strongest (16 % against `weapons` 45 and `greedy` 41) and The Inheritance's loud builds win as
early as anywhere (`weapons` 76 % on day ~634). Both need a rule that reads what the build *is*,
not another number. Each is one piece of vocabulary, used by one scenario's data and open to any
later content; neither is a hook, so §0 item 1 holds. Build step: **S5.9**.*

### 8.1 Airgap Earth — fleets cross what is closed

**New regional modifier target `closed_cross`** (base 0, clamp 0…1): a factor on the seeding
chance **across a closed link**, evaluated for the **source** region — the first regional target
read at the source (`spread_seed` and `seed_<kind>` are read at the target; `airgap_cross` too).
0 = a closed link carries nothing, as now.

**Airgap Earth's data gains one modifier:**
`{"target": "closed_cross", "op": "add", "value": 0.5, "scope": {"asset": "fleet"}}` — from a
region that holds a fleet, the agent crosses closed links at half the open link's chance. The
fortress's network links (closed by `disconnected`) are what that opens; it is Robotics' asset,
so it is Robotics' door.

`SpreadSystem._seed` / `_try_pair`, in this order (the rest as now):

1. Dark source or target → no roll; a kind that cannot carry (`carries`) → no roll; a dormant
   source → no roll; source uninfected or target already infected → no roll.
2. `crossing = 1.0` on an open link, else `modifiers.value("closed_cross", source.def)`;
   `crossing <= 0` → **no roll** (every run without the modifier keeps its random stream, so
   every existing seed and hash outside Airgap Earth with fleets is unchanged).
3. `chance = seed_chance[kind] × source.penetration × spread_seed(target) × seed_<kind>(target)
   × crossing`, then `× airgap_cross(target)` for an air-gapped target, clamped, rolled as now.

The link stays closed for everything else (the link's `open`, the map, counter-moves); seeding is
the only thing that crosses. `region_seeded` carries the link's kind as now. Any closure is
crossed — a Lockdown's or the team's `cut_off` too — because a link does not record why it is
closed; in M5–M7 only Airgap Earth grants `closed_cross`, and there that is the scenario's point.

SCHEMA §4.1 gets the row (Targets v3 table or a new v4 line: `closed_cross` · regional · 0 · 0…1
· live (S5.9) · *factor on seeding across a closed link, read at the source; 0 = impossible*);
`balance.stats.closed_cross: 0`; `ModifierStack` clamps it.

### 8.2 The Inheritance — the dead lead back to the company

**New scenario field `term_scale`** (top level of a scenario, beside `modifiers` and `start`; it
holds for the whole run): a list of `{"faction": <faction id>, "source": <term source>, "mul":
<number>}`. For that faction, every term of that `source` in `factions.json` counts `mul` times
its weight while the run is in this scenario.

**The Inheritance's data gains:**

```json
"term_scale": [
  {"faction": "public_sentiment", "source": "deaths_share", "mul": 2.0},
  {"faction": "governments", "source": "harm", "mul": 2.0}]
```

Deaths and standing Harm are what a loud build is, and the two factions that read them now read
them twice as hard; a quiet build loses nothing. The labs' slowness (`containment_ai_labs` ×0.85)
stays — the company's name only surfaces once people die. (BALANCE §5.7's example, "the labs'
slowness ending at discovery", would do nothing: every track stays 0 until discovery, §2, so a
brake that ends there never brakes. And it reads the day of discovery, not what the build does.)

- **Where it acts:** `ContainmentSystem.containment_breakdown` — each term's weight is
  `term.weight × scenario.term_scale(faction_id, term.source)`, and `TERM_WEIGHT` reports that
  scaled weight, so the containment panel and the Analysis screen show what counts. Nothing else
  reads the terms.
- **API:** `ScenarioDef.term_scale(faction_id: String, source: String) -> float` — the product of
  the matching entries' `mul`, 1.0 when none (there is at most one per pair). The run's scenario is
  `db.scenario(world.setup.scenario)` (null → 1.0).
- **Validation** (SCHEMA §6j): optional, an array; each entry exactly the three keys; `faction` is
  one of the four; `source` names at least one term of that faction in `factions.json`; `mul` a
  finite number > 0; a `(faction, source)` pair at most once. Checked after `factions.json` loads.
- The validator's "no other field" rule for a scenario gains `term_scale`.

### 8.3 What the player reads (strings, written)

`SCENARIO_AIRGAP_EARTH_DETAIL` and `SCENARIO_INHERITANCE_DETAIL` are revised in both languages to
name the lever by its outcome (fleets reach where the network cannot; deaths count double
against you). No other string; the setup page already shows `_DETAIL`.

### 8.4 Tests (S5.9)

- `test_spread_system.gd`: a closed link carries nothing and draws nothing without `closed_cross`
  (the RNG draws the same numbers as before the change); with it on
  the source (a fleet-scoped modifier and a fleet there) the target can be seeded, at the factor;
  the factor is read at the source, not the target; `carries` and a dormant source still refuse.
- `test_scenarios.gd`: `term_scale` scales exactly its faction's terms of that source (the
  breakdown's weight and gain), nothing outside the scenario; validation refuses an unknown
  faction, a source the faction does not have, `mul` ≤ 0 and a repeated pair; Airgap Earth's
  `closed_cross` is live only where a fleet stands.
- Content: `closed_cross` is a known target with its base and clamp.

### 8.5 The check (S5.9, with §14's of `taskforce-endings.md`)

100 seeds per bot, `--setup=language_model,standard,scenario=airgap_earth` and `…=inheritance`,
recorded under PROGRESS *Balance baselines* next to pass 3's 200-seed row. What §3 wants: Robotics
the strongest bot on Airgap Earth; on The Inheritance the loud builds (`weapons`, `biology`) lose
ground against `greedy`, `cyber` and `persuasion`, or win later. A check, not a pass: if a claim
still fails, the check says by how much and balance pass 4 (G6 1/2) tunes `closed_cross`'s 0.5
and the two `mul`s — S5.9 does not.
