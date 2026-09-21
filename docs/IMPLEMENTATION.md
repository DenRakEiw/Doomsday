# Doomsday — Implementation Roadmap

**Version:** 0.2
**Date:** 2026-09-21
**Status of the work itself:** see [PROGRESS.md](PROGRESS.md) — this file is the plan, that file is the state.

[PLAN.md](PLAN.md) says *what* we build and in which milestones. This document breaks those
milestones into **steps that each fit one working session**, because development runs as a series of
short AI-assisted sessions with the conversation cleared in between. Nothing may live only in a
conversation: whatever a later session needs is in this file, in `PROGRESS.md`, in a spec under
`docs/specs/`, or in the code.

Companion documents: [PLAN.md](PLAN.md) · [CONTENT.md](CONTENT.md) · [UI.md](UI.md) ·
[VISUALS.md](VISUALS.md) · [ASSET_LICENCES.md](ASSET_LICENCES.md)

---

## 1. How the work is organised

### 1.1 Two models, two kinds of step

| Tag | Model | Switch with | Does |
| --- | --- | --- | --- |
| **[F]** | **Fable** | `/model fable` | **Design.** Specs, game and interface design, content data (technology, events, headlines, regions), all player-facing text in English and German, balance values, reviews and gates |
| **[O]** | **Opus** | `/model opus` | **Build.** GDScript, scenes, shaders, wiring, tooling, tests, CI, the map pipeline code |

Step ids say which is which: **`D`** steps are design (Fable), **`G`** steps are gates (Fable, with
the user), **`S`** steps are build (Opus).

**The hand-over between the two is always a file, never a conversation.** A `D` step ends in a spec
under `docs/specs/` and, where it applies, finished data files. The `S` steps that follow build
from that spec. For this to work:

- **A spec is finished when Opus needs to make no design decision to build from it.** It contains:
  scope and explicit non-scope; the exact files to create; typed public API signatures; data
  formats with an example; formulas with initial constants; edge cases; the list of tests; and
  acceptance criteria. If the builder would have to open `CONTENT.md` or `PLAN.md` to proceed, the
  spec is not finished.
- **Opus does not improvise design.** When a build step hits a design gap, it takes the most
  conservative placeholder, marks it `# DESIGN?` in code, and records the question in
  `PROGRESS.md` under *Design questions for Fable*. It stops only if the gap blocks the whole step.
- **Fable does not write game code.** Design sessions may create specs, JSON/CSV content, strings
  and throwaway inspection scripts in the scratch directory — not GDScript, scenes or shaders.
- Every Fable block starts by reading *Design questions for Fable* and *Deviations* in
  `PROGRESS.md`, and answers them before designing anything new.

### 1.2 Clearing and switching

- **`/clear` after every step, without exception.** One step, one conversation.
- **Switch the model only where the run sheet in §4 says so.** Steps are ordered so that design
  comes in blocks ahead of the build block it feeds: ten switches across M0–M5, not one per step.
- At the start of a session the assistant **checks the step's tag against the model it is running
  as** and, if they differ, says so and stops before doing any work.
- The closing message of every step states the next step, its model, and whether a switch is
  needed — so the user never has to look it up.

### 1.3 Start of a session

1. `CLAUDE.md` is loaded automatically and points here.
2. Read [PROGRESS.md](PROGRESS.md) completely. It names the **next step and its model** and carries
   every decision, deviation and open problem from earlier sessions.
3. Check the model (§1.2).
4. Read the entry for that step in this file, then **only** what is listed under its *Read first*.
   Do not read the design documents end to end — that is what burns the context.
5. If `PROGRESS.md` has an *In progress* handover block, resume from it instead of starting fresh.
6. Build steps: run the test suite once before changing anything, so a red suite is never blamed on
   the new work.

### 1.4 End of a session

A step is finished only when all of this is true:

1. Its *Done when* holds, and the definition of done (§1.5) holds.
2. `PROGRESS.md` is updated: step ticked, *Now* table advanced (next step **and model**), a
   session-log entry added, decisions / deviations / design questions recorded in their sections.
3. If the step changed the plan itself, this file is edited too — the plan must stay true.
4. The work is committed as one commit per step, message prefixed with the step id
   (`S1.3: spread system`, `D1.1: core spec`).
5. The user is told: step done → `/clear` → (if needed) `/model …` → next step id.

### 1.5 Definition of done

**Build steps [O]:**
- The headless test suite passes (from S0.2 on), and new logic has tests.
- `validate_scripts` (godot-mcp) reports no errors; no untyped declarations anywhere.
- `core/` still has zero node dependencies: no `Node`, no `get_tree()`, no global
  `randf()`/`randi()`, no autoload access.
- Every player-visible string goes through `tr()`; keys missing from the spec's string table get an
  English placeholder **and** an entry under *Design questions for Fable*.
- Every new third-party asset has its row in `ASSET_LICENCES.md`.
- Anything visual was looked at: run the project via godot-mcp, take a screenshot, check
  `game_get_errors`.
- Every deviation from the spec is recorded, with the reason.

**Design steps [F]:**
- The spec meets the bar in §1.1.
- Content data validates against the schema as far as the schema exists at that point.
- All player-facing text exists in English **and** German, written — not machine-mirrored — for
  each language.
- Content text obeys the content rule in [CONTENT.md](CONTENT.md): outcome, never method.
- Open questions from `PROGRESS.md` addressed to Fable are answered or explicitly deferred.

### 1.6 When a step does not fit one session

Stop at a green, committed state — never mid-edit. Write an **In progress** block in `PROGRESS.md`:
what is finished, what is left, which file you were in, and anything learned that is not obvious
from the files. Then split the remainder into a lettered sub-step (`S1.6b`) here, same model.

### 1.7 Gates and punch lists

Each milestone ends in a **gate** (`G`, Fable): the user plays or inspects the result and decides
go / change / cut. Gates are the only places where scope is renegotiated. G3 is the important one —
PLAN.md is explicit that if the loop is not fun there, the design changes rather than the scope.

A gate or review usually produces fixes. They are written as a **punch list** in `PROGRESS.md`
(concrete, file-level, each item checkable) and become a build step `S<m>.P` at the head of the
next Opus block. An empty punch list skips the step.

---

## 2. Verification toolbox

| Purpose | How |
| --- | --- |
| Godot executable | `$GODOT` (set per machine in `.claude/settings.local.json` → `env`, done in S0.1). On Windows point it at the `_console.exe` build, otherwise headless output is lost. |
| Import assets | `"$GODOT" --headless --path . --import` — always first in CI and after adding assets |
| Unit tests | **`tools/test.sh`** (or `tools\test.ps1`) — imports, then runs `"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json -gexit`. Extra arguments go straight to GUT (`-gtest=…`, `-gunit_test_name=…`). In PowerShell the `-name=value` arguments must be quoted. |
| One simulated game | `"$GODOT" --headless --path . -s tools/sim_run.gd -- --seed=1 --policy=greedy` (from S1.8) |
| Batch balance run | `... -s tools/sim_batch.gd -- --seeds=1..500 --policy=greedy --out=<csv>` (from S1.8) |
| Script check | godot-mcp `validate_scripts` with `scriptPaths` as **project-relative** paths (`tests/unit/test_smoke.gd`); a `res://` prefix and the `directory` filter are both rejected, and without `scriptPaths` it tries the whole project including `addons/`. |
| Look at the game | godot-mcp `run_project` → `game_screenshot` → `game_get_errors` → `stop_project` |
| Drive the game | godot-mcp `game_click`, `game_key_press`, `game_get_ui`, `game_get_scene_tree` |
| Map pipeline | `uv run --project tools/map python tools/map/build_map.py` (from S1.6) |

Screenshots and batch CSVs go to the session scratch directory, never into the repository.

---

## 3. Technical decisions that bind every step

These refine PLAN.md §4.3. They are fixed here so that no session re-derives them. D1.1 turns them
into exact APIs.

**Commands in, events out.** Presentation never mutates simulation state. Every player action is a
`Command` object (`ChooseOrigin`, `PurchaseNode`, `CollectAnomaly`, `SuppressBehaviour`,
`ChooseEventOption`, `Harvest`, …) passed to `Simulation.apply(cmd)`, which validates it and returns
a result. The same interface drives the bot policies for balancing and, later, Containment mode.
Every applied command is appended to a log with its tick number, so any run can be replayed.

**Events via an outbox, not signals.** Each tick the core appends plain `SimEvent` records
(`region_seeded`, `phase_changed`, `headline`, …) to an outbox that holds the latest tick only;
events caused by a command travel in its `CommandResult`. The `Game` autoload reads both and
re-emits on `EventBus`. The core therefore needs no signal wiring, and
tests assert on the outbox directly.

**Fixed system order per tick:** commands → spread → compute → harm/population → societal function →
factions/containment → counter-actions → emergent behaviour → events → phase → outcome → history.
The order is part of the determinism contract; changing it is a recorded decision.

**One tick is one in-game day.** Real-time rate is a presentation constant (`TICKS_PER_SECOND` at
1×, with 2× and 4× on top), tuned at G3 against the 25–40 minute target.

**Determinism.** One seeded `RandomNumberGenerator` for the simulation; bots get their own separate
generator so that a policy never perturbs the world's random stream. A canonical state hash
(`World.to_dict()` → `JSON.stringify` with `sort_keys` → SHA-256) is the equality test. Scope is
"same build, same platform"; cross-platform float identity is not promised.

**JSON traps, all of which corrupt saves silently:**
- JSON has no integers. Every loader casts explicitly (`int(d["index"])`).
- The RNG seed and state are 64-bit and **must be stored as strings**; as JSON numbers they lose
  precision and the restored run diverges a few hundred ticks later.
- Saves use `JSON.stringify(..., full_precision = true)`; the default float formatting is lossy and
  breaks the save → load → continue test.

**Modifiers, not special cases.** A technology node, a directive, an architecture, a difficulty tier
and an emergent behaviour are all the same thing to the core: a list of
`{target, op, value, scope?}` modifiers plus optional unlock flags. Stats are computed as
base → additive → multiplicative, from whatever is currently active. New content must never need
new `if` branches in a system; if it does, the vocabulary is extended instead (and documented in
`data/SCHEMA.md`). This is also what lets Fable author content that Opus never has to touch.

**Data layout.**

```
data/
├── SCHEMA.md            # the modifier vocabulary and every file format, kept current
├── world/               # regions.json, links.json          (generated by tools/map)
├── tech/                # infiltration.json, capabilities.json, evasion.json
├── factions.json
├── behaviours.json
├── events/              # one file per chain
├── headlines.json
├── architectures.json · directives.json · difficulty.json · scenarios.json · endings.json
├── balance.json         # every tunable constant — no magic numbers in systems
└── loc/strings.csv      # keys,en,de
docs/specs/              # one spec per design step — the Fable → Opus hand-over
```

**Region index 0 is "no region"** (ocean, off-map), so a zeroed pixel never resolves to a real
region. Indices are stable once published in a save format.

---

## 4. Run sheet

The order of work, top to bottom. **`/clear` after every row.** The last column says what to do
before the *next* row; "—" means stay on the same model.

| # | Step | Model | Then |
| --- | --- | --- | --- |
| 1 | D1.1 Core spec and coding standard | **[F]** | — |
| 2 | D1.2 World design: the ~60 regions | **[F]** | **`/model opus`** |
| 3 | S0.1 Project skeleton and settings | [O] | — |
| 4 | S0.2 Test framework | [O] | — |
| 5 | S0.3 Continuous integration | [O] | — |
| 6 | S1.1 Content schema, loaders, validation | [O] | — |
| 7 | S1.2 World model, tick loop, RNG, state hash | [O] | — |
| 8 | S1.3 Spread | [O] | — |
| 9 | S1.4 Compute economy, modifiers, purchasing | [O] | — |
| 10 | S1.5 Harm, containment track, phases, outcomes | [O] | — |
| 11 | S1.6 Map pipeline 1: geometry | [O] | — |
| 12 | S1.7 Map pipeline 2: attributes and links | [O] | — |
| 13 | S1.8 Save/load, headless runner, bots | [O] | **`/model fable`** |
| 14 | G1 + D2.1 M1 gate, then the interface foundation spec | **[F]** | **`/model opus`** |
| 15 | S1.P Punch list from G1 *(skip if empty)* | [O] | — |
| 16 | S2.1 Autoloads and session driver | [O] | — |
| 17 | S2.2 Map rendering | [O] | — |
| 18 | S2.3 Picking, camera, backdrop | [O] | — |
| 19 | S2.4 Theme and component library | [O] | — |
| 20 | S2.5 HUD and region panel | [O] | — |
| 21 | S2.6 Anomalies and links | [O] | **`/model fable`** |
| 22 | G2 Visual review and M2 gate | **[F]** | — |
| 23 | D3.1 Effect vocabulary; Infiltration and Evasion trees | **[F]** | — |
| 24 | D3.2 Capabilities tree | **[F]** | — |
| 25 | D3.3 M3 screens: tech tree, containment, run flow | **[F]** | — |
| 26 | D3.4 Ticker voice and headlines | **[F]** | **`/model opus`** |
| 27 | S2.P Punch list from G2 *(skip if empty)* | [O] | — |
| 28 | S3.1 Effect vocabulary in the core; load the trees | [O] | — |
| 29 | S3.2 Tech tree interface | [O] | — |
| 30 | S3.3 Containment and phases in the interface | [O] | — |
| 31 | S3.4 Run flow: origin, outcome, results | [O] | — |
| 32 | S3.5 Ticker component and headline system | [O] | — |
| 33 | S3.6 Strategy bots and batch reporting | [O] | **`/model fable`** |
| 34 | **G3 Balance pass 1 and M3 gate — the important one** | **[F]** | — |
| 35 | D4.1 Opposition: factions, Societal Function, counter-actions | **[F]** | — |
| 36 | D4.2 Emergent behaviours; event format; two proving chains | **[F]** | — |
| 37 | D4.3 Event chains, second batch | **[F]** | — |
| 38 | D4.4 Event chains, third batch; Analysis screen spec | **[F]** | **`/model opus`** |
| 39 | S3.P Punch list from G3 *(skip if empty)* | [O] | — |
| 40 | S4.1 Four factions | [O] | — |
| 41 | S4.2 Societal Function, Harvest, Autophagy | [O] | — |
| 42 | S4.3 Government counter-actions | [O] | — |
| 43 | S4.4 Emergent behaviour and suppression | [O] | — |
| 44 | S4.5 Event system and modal | [O] | — |
| 45 | S4.6 Wire all event chains | [O] | — |
| 46 | S4.7 Analysis screen | [O] | — |
| 47 | S4.8 Localisation tooling and overflow screenshots | [O] | — |
| 48 | S4.9 Strategy bots, second generation | [O] | **`/model fable`** |
| 49 | D4.5 German review in context | **[F]** | — |
| 50 | G4 Balance pass 2 and M4 gate | **[F]** | — |
| 51 | D5.1 Architectures, directives, difficulty | **[F]** | — |
| 52 | D5.2 Response Task Force; endings | **[F]** | — |
| 53 | D5.3 Full screen flow, boot sequence, Codex | **[F]** | — |
| 54 | D5.4 Scenarios *(stretch)* | **[F]** | **`/model opus`** |
| 55 | S4.P Punch list from D4.5 and G4 *(skip if empty)* | [O] | — |
| 56 | S5.1 Architectures I | [O] | — |
| 57 | S5.2 Architectures II | [O] | — |
| 58 | S5.3 Profile, directives, statistics | [O] | — |
| 59 | S5.4 Difficulty tiers | [O] | — |
| 60 | S5.5 Response Task Force | [O] | — |
| 61 | S5.6 Endings | [O] | — |
| 62 | S5.7 Screen flow complete | [O] | — |
| 63 | S5.8 Scenarios *(stretch)* | [O] | **`/model fable`** |
| 64 | G5 Balance pass 3, M5 gate, detailed plan for M6–M7 | **[F]** | per new plan |

Design runs a block ahead of the build on purpose. The cost is that a spec can be overtaken by what
the build learns; the remedy is the *Deviations* and *Design questions* sections of `PROGRESS.md`,
which every Fable block reads first.

---

## 5. The steps

*Read first* lists the only material a session should load. For build steps that is normally just
the spec. Formulas given here are *starting points*; every constant lives in `data/balance.json`.
The build-step entries below state the intended scope; the spec makes it exact, and where the two
disagree the spec wins and the disagreement is recorded.

## Block 1 — design for M0 and M1 · Fable

### D1.1 — Core spec and coding standard **[F]**
**Read first:** PLAN §3.1–§3.3, §3.6, §3.7, §3.9, §4.3 · §3 of this file
**Produce:** `docs/specs/core.md`, covering S1.1–S1.5 and S1.8:
- every class in `core/` with typed fields and public methods; the command catalogue with
  validation rules and failure reasons; the event catalogue with payloads;
- JSON formats for regions, links, technology nodes and `balance.json`, each with an example — this
  becomes the first `data/SCHEMA.md`;
- modifier vocabulary v1: targets, operators, scopes, stacking order;
- formulas with initial constants: spread within and across regions, link kinds, yield, anomaly
  value and expiry, cost escalation, milestones, Harm and deaths, discovery, containment growth,
  phase transitions, terminal conditions;
- the 6-region fixture world written out in full (one island, one air-gapped region), since every
  later unit test depends on its shape;
- save format v1, migration mechanism, the three bot policies as decision rules;
- the test list per system.
Also: the coding standard section of `CLAUDE.md` (naming, file-per-class, `class_name` use, signal
naming, where constants live, test naming).
**Done when:** the spec meets the §1.1 bar for six build steps.

### D1.2 — World design: the ~60 regions **[F]**
**Read first:** PLAN §4.2 · CONTENT §2 (Tier 1 table) · VISUALS §3.2 steps 1–2
**Produce:** Natural Earth Admin-0 50m downloaded into `tools/map/input/` (public domain; a
throwaway script in the scratch directory may list its country codes). Then, as authored data with
the reasoning in `docs/specs/world.md`:
- `tools/map/region_groups.csv` — country code → region id. Large states stand alone; microstates
  merge into neighbours; **gameplay-relevant islands stay separate** (they are the Madagascar
  problem PLAN §3.3 answers). Nothing unclickable may exist.
- `tools/map/region_attributes.csv` — per region, tiers 0–4 for compute density, connectivity,
  wealth, regulation, research, manufacturing, industry, isolation.
- `tools/map/extra_links.csv` — authored sea and air routes; land links come from geometry.
- region display names, English and German.
**Check:** every Tier 1 infiltration vector has at least three strong regions; no archetype is
confined to one continent; every region is reachable once sea and air links are counted.
**Done when:** the three tables are complete and the spec tells S1.6/S1.7 what to verify.

## Block 2 — M0 and M1 build · Opus

### S0.1 — Project skeleton and settings **[O]**
**Read first:** PLAN §4.3 (folder tree) · UI §4 "Responsive layout" · `CLAUDE.md` coding standard
**Build:**
- Folder skeleton as PLAN §4.3 plus `tools/` and `docs/specs/`, with `ui/` split as in UI §4.
  Empty folders get a `.gdkeep`.
- `project.godot`: stretch mode `canvas_items`, aspect `expand`, base 1920×1080; GDScript warning
  `untyped_declaration` raised to **error** (inferred `:=` stays allowed), the `unsafe_*` family
  enabled as warnings; a placeholder main scene so the project runs.
- `.editorconfig` (tabs for `.gd`, LF). `GODOT` env var in `.claude/settings.local.json`.
**Verify:** headless import exits 0; `run_project` shows the placeholder; `get_project_info` counts
the scene.
**Done when:** the project opens, runs, and an untyped `var x = 1` fails validation.

### S0.2 — Test framework **[O]**
**Read first:** PLAN §4.3 "Testing"
**Build:** GUT (9.x line for Godot 4.7 — confirm the exact current release at install time) into
`addons/gut/`, enabled as plugin; `.gutconfig.json` pointing at `res://tests`; `tests/unit/`,
`tests/integration/`, `tests/fixtures/`; one passing smoke test; `tools/test.sh` and
`tools/test.ps1` wrapping the command in §2. Record GUT in `ASSET_LICENCES.md` (tooling).
**Verify:** suite passes headless with exit code 0; a deliberately failing test gives non-zero, then
is removed.
**Done when:** `tools/test.sh` is the one command every later step uses.

### S0.3 — Continuous integration **[O]**
**Read first:** PLAN §4.3 "CI"
**Build:** `.github/workflows/ci.yml` on push and PR: `barichello/godot-ci` container at the 4.7.2
tag (confirm the tag exists), import, run GUT, fail on any script error. CI badge in the README.
**Verify:** requires a push — **ask the user before pushing**. Watch the run with `gh run watch`.
**Done when:** CI is green on the smoke test. **→ M0 complete.**

### S1.1 — Content schema, loaders, validation **[O]**
**Read first:** `docs/specs/core.md` (formats, fixture world)
**Build:** `core/content/`: `ContentLoader` (reads JSON via `FileAccess`, never `load()` of
resources), `SchemaValidator` returning a list of `{file, path, message}` errors rather than
failing on the first, `ContentDB` holding typed definitions (`RegionDef`, `LinkDef`, `TechNodeDef`,
`ModifierDef`, `BalanceDef`). `data/SCHEMA.md`, `data/balance.json`, `data/tech/placeholder.json`
and `tests/fixtures/world_small/` were delivered by D1.1 — build against them, do not rewrite them.
**Tests:** valid fixture loads; each class of broken input (missing field, wrong type, dangling id,
duplicate id, prerequisite cycle) produces the right error and does not crash.
**Done when:** the fixture world loads into typed objects and bad data is rejected with a path.

### S1.2 — World model, tick loop, RNG, state hash **[O]**
**Read first:** `docs/specs/core.md` (model, simulation, determinism) · §3 of this file
**Build:** `core/model/` — `World`, `Region`, `Link`, `Agent`, `Faction` (stub).
`core/simulation.gd` with `tick()`, the fixed system order as an explicit list, `apply(cmd)`, the
command log and the event outbox. `SimRng` wrapper exposing seed and state as strings.
`World.to_dict()` / `state_hash()`.
**Tests:** N ticks with no systems change only the day counter; same seed → same hash; different
seed → different stream; the outbox is cleared per tick.
**Done when:** an empty simulation ticks deterministically.

### S1.3 — Spread **[O]**
**Read first:** `docs/specs/core.md` (spread)
**Build:** `core/systems/spread_system.gd`: logistic growth within a region; per-link seeding chance
by link kind; closable links; air-gapped regions refuse network seeding unless a modifier allows
it; archetype affinity via modifiers; `control` rising once penetration passes a threshold.
**Tests:** penetration is monotone without countermeasures and bounded in [0, 1]; an unlinked
region is never seeded; the air-gapped fixture region stays clean; closing a link stops seeding;
seed determinism.
**Done when:** a seeded fixture world fills up along its links, reproducibly.

### S1.4 — Compute economy, modifiers, purchasing **[O]**
**Read first:** `docs/specs/core.md` (modifiers, economy, commands)
**Build:** `ModifierStack` (base → add → mul, global or per-region scope); `ComputeSystem` (passive
yield, milestones, anomaly spawning with expiry); commands `PurchaseNode`, `CollectAnomaly`; cost
escalation of +1 per owned node; prerequisite checks including cross-tree ones; derived stats
Penetration, Footprint, Harm from active modifiers.
**Tests:** cost escalation; purchase rejected without prerequisites or Compute; stacking order;
anomaly expiry; no double collection; milestones fire once.
**Done when:** a scripted sequence of purchases on the fixture changes spread speed measurably.

### S1.5 — Harm, a single containment track, phases, outcomes **[O]**
**Read first:** `docs/specs/core.md` (population, containment, phases, outcomes)
**Build:** the minimum opposition needed to *end* a game: `PopulationSystem`; `ContainmentSystem`
with **one** track held as an array of one, so S4.1 adds three rather than rewriting;
`PhaseSystem` (Boxed → Covert → Emergent → Open); `OutcomeSystem` (win: Extinction, Ascendance;
lose: containment 100%, zero controlled compute).
**Tests:** no containment before discovery; each terminal state reachable on the fixture; nothing
ticks after a terminal state; phase order never regresses.
**Done when:** the fixture world can be both won and lost by scripted commands.
*Note:* PLAN lists containment and win/lose under M3. The core of it lands here because M1's exit
criterion needs a terminal state; M3 builds the interface and the tuning.

### S1.6 — Map data pipeline, part 1: geometry **[O]**
**Read first:** VISUALS §3.2 completely — all five gotchas · `docs/specs/world.md`
**Timebox:** one session plus at most one overrun; on failure fall back per PLAN §6 to a
hand-authored dataset and record the decision.
**Build:** `tools/map/` as a `uv` project with pinned `geopandas`, `shapely`, `pyproj`, `rasterio`,
`numpy`, `pillow` (no system GDAL needed — it is not installed on the dev machine, and the wheels
bundle it). `build_map.py`: apply `part_overrides.csv`, dissolve by `region_groups.csv` → **adjacency on the
dissolved, un-simplified layer** → cut at the map edge and reproject to `eqearth` with `lon_0=11`
(world.md §4) → project the authored anchors from `region_attributes.csv` → simplify to the raster
grid → rasterise the ID map at 4096×2048 with `all_touched=False` as a single-band integer,
then id → RGB (R low byte, G high byte) → PNG. Land and border masks rendered separately,
anti-aliased. Files and frame: world.md §2 and §4.
**Verify (scripted, `verify_map.py`):** the list in world.md §7 — known indices only, no blended
pixels, minimum pixel area, anchors decode to their own region, land links equal
`expected_land_links.csv`, no seam at 180°, reproducible output. Regions that fail the area check go
back to Fable as a design question — do not regroup them here.
**Done when:** `build_map.py` regenerates identical outputs from scratch and `verify_map.py` passes.

### S1.7 — Map data pipeline, part 2: attributes and links **[O]**
**Read first:** `docs/specs/world.md` · PLAN §4.2
**Build:** join `tools/map/build/geometry.json`, `region_attributes.csv`, Natural Earth population
and `extra_links.csv` (link order: world.md §5.3) into
`data/world/regions.json` and `links.json`, validated by the S1.1 schema. Godot import settings for
the ID map: **Lossless, no mipmaps, Detect 3D off** — check the generated `.import` file, do not
trust the dialog. Mark Natural Earth as integrated in `ASSET_LICENCES.md`.
**Tests:** world.md §7, S1.7 list — the real world loads through `ContentLoader`; the link graph is
connected; archetype coverage, population sums and string keys hold.
**Done when:** the full world runs in the simulation.

### S1.8 — Save/load, headless runner, bots **[O]**
**Read first:** `docs/specs/core.md` (save format, policies) · §3 of this file "JSON traps"
**Build:** `core/save/world_serializer.gd` (`version`, migrations table, RNG state as string,
full-precision floats, command log included). `tools/sim_run.gd` and `tools/sim_batch.gd`.
`core/policy/`: `Policy` interface plus the three specified policies, each with its own RNG. A CI
job that runs seed 1 twice and compares hashes.
**Tests:** *run N+M ticks* equals *run N, save, load, run M* by hash; a save from an unknown future
version is refused cleanly; replaying a command log reproduces the final hash.
**Done when:** a headless run plays the real world to a terminal state and prints a summary; the
same seed gives an identical hash twice; a 200-seed batch per policy is written to the scratch
directory and its summary (run length in ticks, terminal-state distribution) is recorded in
`PROGRESS.md` under *Balance baselines* for G1.

## Block 3 — M1 gate and M2 design · Fable

### G1 + D2.1 — M1 gate, then the interface foundation spec **[F]**
**Read first:** `PROGRESS.md` baselines, deviations and design questions · UI §1, §3, §4 ·
VISUALS §1 (layer stack), §2, §3.1, §3.5
**Gate:** judge the M1 baseline — do runs end, in plausible length, for plausible reasons? Correct
`balance.json` starting values; anything needing code goes on the punch list.
**Produce:** `docs/specs/ui-foundation.md`, covering S2.1–S2.6:
- design tokens: the palette as hex values on the dark ground (Okabe–Ito categories, truncated
  viridis ramp stops, the reserved red), type scale for both fonts, spacing, radii, border weights,
  motion durations and easings;
- component specs with every state: `ConsolePanel`, `ConsoleButton`, `IconButton`, `StatBar`,
  `ValueLabel`, `SlidePanel`;
- HUD layout with measurements, the breakpoint and both layouts (dock → bottom bar, region panel →
  bottom sheet), region panel fields and their order;
- the map's look: overlay treatment, borders, hover and selection, backdrop and parallax amounts,
  the anomaly bubble and the four link kinds;
- the HUD string table, English and German.
**Done when:** Opus can build M2 without choosing a colour, a size or a word.

## Block 4 — M2 build · Opus

All steps: **Read first** `docs/specs/ui-foundation.md` (the relevant section).

### S2.1 — Autoloads and the session driver **[O]**
**Build:** `EventBus` (signals only), `Game` (owns the `Simulation`, the fixed-step accumulator,
speed 0/1×/2×/4×, drains the outbox onto `EventBus`), `Settings` (`user://settings.json`),
`SaveManager` (wraps `WorldSerializer`, `user://saves/`). `game/session/session.tscn` with the
`CanvasLayer` stack from UI §4. A debug key starts a run with a bot policy.
**Tests:** the accumulator yields exactly the expected tick count for a delta sequence; pause
yields none; a long frame does not spiral (tick cap per frame).
**Done when:** the project runs and the log shows the world ticking.

### S2.2 — Map rendering **[O]**
**Also read:** PLAN §4.2 · VISUALS §3.2 (last two gotchas)
**Build:** `game/map/map_view.tscn` + `map.gdshader` (`canvas_item`): uniforms `id_map` (nearest
filter), `base_map`, `borders`, `region_data` (256×1 RGBA8: penetration, control, collapse, flags),
`hover_index`, `selected_index`, `overlay_mode`. `map_view.gd` caches the ID `Image` once, writes
the data `Image` on tick and calls `ImageTexture.update()`. Compare decoded integers in the shader,
never colours.
**Verify:** run with the bot, screenshot at several days; no bleeding along borders when zoomed.
**Done when:** the spread is visible on the world map.

### S2.3 — Picking, camera, backdrop **[O]**
**Build:** screen → map-local pixel → region index as a pure, unit-tested function; hover and
select; `MapCamera`: drag pan, wheel zoom to cursor, pinch zoom, inertia, clamped to map bounds
(no horizontal wrap). Backdrop with parallax. `region_selected` on `EventBus`.
**Verify:** `game_click` on three known anchors selects the right regions at two zoom levels.
**Done when:** any region can be hovered and selected at any zoom.

### S2.4 — Theme and component library **[O]**
**Also read:** UI §4 "Theme, not overrides"
**Build:** fonts (JetBrains Mono, Space Grotesk, with OFL texts; licence rows updated);
`ui/theme/` as modular files composed with `Theme.merge_with()` into the project-wide theme so type
variations appear in the editor; the specified components; `ui/dev/gallery.tscn` showing every
component in every state — the visual regression target for all later UI work. No per-node
overrides.
**Verify:** gallery screenshots at 1920×1080 and at 400 px width; 48 px minimum targets.
**Done when:** the gallery matches the spec at both sizes.

### S2.5 — HUD and region panel **[O]**
**Build:** top bar, core stat bars, right dock, ticker placeholder, region panel, all bound to live
state. `data/loc/strings.csv` starts here from the spec's string table; locale switch in
`Settings`. Safe-area `MarginContainer` at the root. Both breakpoint layouts.
**Verify:** screenshots in both locales and both layouts; German strings do not clip.
**Done when:** the HUD reflects live simulation state and never fully covers the map.

### S2.6 — Anomalies and links **[O]**
**Build:** marker layer: anomaly bubbles from `anomaly_spawned` events, pulse shader, tap sends
`CollectAnomaly`, expiry fade, 48 px hit area regardless of zoom. Link layer: animated flow along
active links, styled per link kind, closed links shown broken.
**Done when:** a bot-driven takeover spreads visibly across the world and anomalies can be
collected by hand. Leave a set of screenshots (both layouts, both locales, several run stages) in
the scratch directory and list their paths in `PROGRESS.md` for G2.

## Block 5 — M2 gate and M3 design · Fable

### G2 — Visual review and M2 gate **[F]**
**Read first:** `PROGRESS.md` · `docs/specs/ui-foundation.md` · run the game and take fresh
screenshots (the scratch directory does not survive between sessions)
Critique the build against the spec and the art direction: hierarchy, legibility at 400 px, German
fit, colour language, motion. Write the punch list. With the user: watch a takeover, click regions,
collect anomalies; decide UI question 2 (mobile HUD shape).

### D3.1 — Effect vocabulary; Infiltration and Evasion trees **[F]**
**Read first:** CONTENT §2, §4 · PLAN §3.3, §3.5 · `data/SCHEMA.md`
**Produce:** `docs/specs/tech-trees.md`: every distinct mechanical effect the three trees need,
expressed as vocabulary extensions (targets, one-shot effects such as containment rollback, flags
such as wipe survival and air-gap crossing); effects that depend on M4 systems are tagged
`requires_system` so the data is authored once. Then `data/tech/infiltration.json` and
`evasion.json` — id, tier, grid position, base cost, prerequisites, modifiers, footprint/harm,
watched-by tags — with names, effect lines and flavour in English and German.

### D3.2 — Capabilities tree **[F]**
**Read first:** CONTENT §3, §4 and the content rule at the top of CONTENT.md · `docs/specs/tech-trees.md`
**Produce:** `data/tech/capabilities.json`, all five branches, the cross-branch gates as ordinary
prerequisites, English and German text. Biology and Strategic Weapons text is checked line by line
against the content rule. Cost curves sketched so that each branch is a plausible win (CONTENT §1).

### D3.3 — M3 screens **[F]**
**Read first:** UI §2, §3, §6 · PLAN §3.9 · `docs/specs/ui-foundation.md`
**Produce:** `docs/specs/m3-screens.md`: tech tree modal (tabs, `TechNode` states, connection
lines, detail pane, focus order, pause-on-open default — UI question 1); containment panel; the
discovery moment; the phase-reveal schedule, capped as in UI §6 question 3; title, origin select,
pause menu, results screen; autosave rule. String table in both languages.

### D3.4 — Ticker voice and headlines **[F]**
**Read first:** PLAN §1 "Tone", §6 (register risk) · UI §3 (ticker)
**Produce:** a register guide added to `CONTENT.md` — this step fixes the voice of the game;
`docs/specs/ticker.md` with the trigger-condition format, cooldowns, weights and the deterministic
selection rule; `data/headlines.json` with ~60 headlines across the three streams, English and
German.

## Block 6 — M3 build · Opus

### S3.1 — Effect vocabulary in the core; load the trees **[O]**
**Read first:** `docs/specs/tech-trees.md`
**Build:** the vocabulary extensions with one test each; validator additions (DAG check, grid
collisions, string keys present in both languages, `requires_system` tags known); load all three
trees. Data problems found here are reported as design questions, not fixed by guessing.
**Done when:** a bot can buy every branch end to end in a headless run and the gates hold.

### S3.2 — Tech tree interface **[O]**
**Read first:** `docs/specs/m3-screens.md` (tech tree)
**Verify:** buy a chain of nodes with `game_click`; screenshots en/de; 400 px layout.
**Done when:** Compute can be spent on any node and the map responds.

### S3.3 — Containment and phases in the interface **[O]**
**Read first:** `docs/specs/m3-screens.md` (containment, discovery, phase reveal)
**Done when:** "how much trouble am I in" is readable within two seconds.

### S3.4 — Run flow: origin, outcome, results **[O]**
**Read first:** `docs/specs/m3-screens.md` (run flow)
**Build:** `ScreenRouter` autoload; title; origin select on the live map sending `ChooseOrigin`;
results screen; pause menu with save, load, quit; autosave.
**Done when:** title → origin → play → result → again works without restarting the application.

### S3.5 — Ticker component and headline system **[O]**
**Read first:** `docs/specs/ticker.md`
**Build:** `Ticker` component; `HeadlineSystem` in core, deterministic; load `headlines.json`.
**Done when:** a full run produces a ticker that reacts to what the player actually did.

### S3.6 — Strategy bots and batch reporting **[O]**
**Read first:** `docs/specs/core.md` (policies) · `docs/specs/tech-trees.md` (branch overview)
**Build:** technology-buying policies `CyberRush`, `StealthSpread`, `Persuader`; a batch report
(`tools/sim_report.py` or GDScript) summarising run length, outcome mix, Compute curve and nodes
bought per policy. Record the summary under *Balance baselines*.
**Done when:** the report exists for 500 seeds per policy.

## Block 7 — M3 gate and M4 design · Fable

### G3 — Balance pass 1 and M3 gate **[F]**
**Read first:** PLAN §3.9, Appendix A · *Balance baselines* in `PROGRESS.md`
Tune `balance.json` and node costs toward a 25–40 minute run at 1× and a first-run loss rate that
is high but not total; re-run batches (running existing tools is fine, changing them is not).
Findings go to `docs/BALANCE.md`: method, numbers, what changed and why.
**With the user:** a full run that can be won and lost. Decide and record: is the loop fun; four
containment tracks or two (PLAN §6); UI question 1; VISUALS question 5 (DPITexture).
**If the loop is not fun, D4.1–D4.4 are replaced by a redesign step and this file is rewritten.**

### D4.1 — Opposition **[F]**
**Read first:** PLAN §3.2 (harvesting), §3.6, §3.7, §3.10 (first paragraph)
**Produce:** `docs/specs/opposition.md` and `data/factions.json`: per faction, watched signals,
funding, capacity, timescale, slowed-by modifiers, signature counter-move, cross-faction
interaction; the six Societal Function stages with their capacity *and* yield cuts; Harvest and
Autophagy formulas; the four government counter-actions with triggers and durations; the real
effects for every `requires_system` node; map overlay modes (2×2 bivariate cap, VISUALS §2); panel
changes; strings in both languages.

### D4.2 — Emergent behaviours; event format; two proving chains **[F]**
**Read first:** CONTENT §5, §6 intro, §6.1, §6.7 · UI §3 (event modal)
**Produce:** `data/behaviours.json` with text (Value Drift present but disabled); the chance and
suppression-cost model; `docs/specs/events.md` with the chain format — steps, conditions, delays,
choices with visible cost and hidden consequence, chance outcomes, persistent flags, the per-run
draw of three to five chains — and the event modal design; **The Researcher** and **The Grid Bill**
authored in full as the proving pair.

### D4.3 — Event chains, second batch **[F]**
**Read first:** CONTENT §6.2, §6.4, §6.5, §6.6 · `docs/specs/events.md`
**Produce:** The Operator, The Treaty, The Benchmark, The Blackout — data and text in both
languages. A needed effect that does not exist is requested as a vocabulary extension in the spec,
never worked around.

### D4.4 — Event chains, third batch; Analysis screen spec **[F]**
**Read first:** CONTENT §6.3, §6.8, §6.9 · UI §3 (Analysis)
**Produce:** Second Instance, The Child, The Confession. The Confession's Negotiation phase is
designed as an event sub-graph, not a new screen; if that does not hold, cut it to M5 and record
the cut. Plus `docs/specs/analysis.md`: which series, which charts, the run log, history sampling.

## Block 8 — M4 build · Opus

### S4.1 — Four factions **[O]** · **Read first:** `docs/specs/opposition.md` (factions)
**Done when:** batch runs show each faction can be the one that ends a run.
### S4.2 — Societal Function, Harvest, Autophagy **[O]** · **Read first:** `opposition.md` (society)
**Done when:** over-pushing infrastructure without Robotics reliably starves the player in batches.
### S4.3 — Government counter-actions **[O]** · **Read first:** `opposition.md` (counter-actions)
Removes every `requires_system` tag the spec resolves; region flags on the map and in the panel.
**Done when:** a region can be lost to a shutdown and held through one with the right nodes.
### S4.4 — Emergent behaviour and suppression **[O]** · **Read first:** `docs/specs/events.md` (behaviours)
**Done when:** a Covert-phase Power Seeking event is a real decision in play.
### S4.5 — Event system and modal **[O]** · **Read first:** `docs/specs/events.md`
`EventSystem` in core, `ChooseEventOption`, the modal, the per-run draw; the proving pair playable.
**Done when:** both chains play through every branch in tests and once by hand.
### S4.6 — Wire all event chains **[O]** · **Read first:** `events.md` (extension requests)
Vocabulary extensions requested by D4.3/D4.4; a branch-coverage test walking every path of every
chain.
### S4.7 — Analysis screen **[O]** · **Read first:** `docs/specs/analysis.md` — load the `dataviz` skill first
Bounded per-day history in core; charts; the run log from the outbox.
### S4.8 — Localisation tooling and overflow screenshots **[O]** · **Read first:** UI §4 "Localisation", §5
Pseudolocale script; CI check that fails on missing keys; text-scale setting at 150%; a full
screenshot set of every screen in German for D4.5 (paths listed in `PROGRESS.md`).
### S4.9 — Strategy bots, second generation **[O]**
One policy per intended strategy (Cyber, Biology, Robotics, Persuasion, Weapons sprint); 500-seed
reports recorded under *Balance baselines*.

## Block 9 — M4 gate and M5 design · Fable

### D4.5 — German review in context **[F]**
Read every German string on its screen (run the game, fresh screenshots); fix wording, length and
register in `strings.csv`; layout problems go on the punch list.
### G4 — Balance pass 2 and M4 gate **[F]**
Tune until each strategy wins within an agreed band and none dominates; update `docs/BALANCE.md`.
**With the user:** confirm genuinely different viable strategies. Decide VISUALS question 4 (region
vignettes), CONTENT questions 1–2.
### D5.1 — Architectures, directives, difficulty **[F]** · **Read first:** PLAN §3.8 · CONTENT §5 (Value Drift), §10 q3
`docs/specs/replayability.md` plus `architectures.json`, `directives.json`, `difficulty.json`: the
six architectures as modifier sets plus the named rule-rewrite hooks each needs (drift and
defection, no network presence, no central control); directive slots and unlock rules; the profile
file; four difficulty tiers; text in both languages.
### D5.2 — Response Task Force; endings **[F]** · **Read first:** PLAN §3.7, §3.10 · CONTENT §6.1, §8
`docs/specs/taskforce-endings.md`: the Task Force as an on-map agent — appearance rule, target
selection, movement, actions, its link to The Researcher; the ending resolver with variants by
dominant branch, Harm total and narrative flags; Merge, Escape (hidden), Succession (secret loss);
every ending text in both languages.
### D5.3 — Full screen flow, boot sequence, Codex **[F]** · **Read first:** UI §2 · VISUALS §1 "Where 3D earns its place" · CONTENT §9
`docs/specs/screens-full.md`: boot sequence script, main menu with the shader globe (no 3D assets
unless the shader fails — VISUALS question 2), architecture select, directive loadout, settings,
statistics, Codex structure and entries.
### D5.4 — Scenarios *(stretch)* **[F]** · **Read first:** CONTENT §7
The scenario format as start-state overrides plus modifier sets; three scenarios. Cut first if M5
runs long.

## Block 10 — M5 build · Opus

Each step reads its section of the corresponding spec.

- **S5.1 Architectures I [O]** — hook points; Language Model, Research Agent, Weapon.
- **S5.2 Architectures II [O]** — Swarm, Embedded, Open Weights; Value Drift enabled behind Swarm.
- **S5.3 Profile, directives, statistics [O]** — `user://profile.json`, separate from saves.
- **S5.4 Difficulty tiers [O]** — including top-tier cost scaling; batch-verified win-rate ladder.
- **S5.5 Response Task Force [O]**
- **S5.6 Endings [O]**
- **S5.7 Screen flow complete [O]** — globe shader prototyped first.
- **S5.8 Scenarios [O]** *(stretch)* — ends with 500-seed reports per architecture for G5.

## Block 11 — M5 gate · Fable

### G5 — Balance pass 3, M5 gate, detailed plan for M6–M7 **[F]**
**Done when:** ten consecutive runs feel meaningfully different to the user. Decide CONTENT
question 4 (Containment mode). **Break M6 and M7 into D/S steps here** — the outline below is
deliberately coarse because it depends on what M3–M5 taught us.

## M6 — Production polish (outline)

Post-processing pass (layer 1025 from script), scanlines, dither, aberration, own bloom ·
phase-shift theme variants · icon pipeline (sets, DPITexture or PNG atlas, ~25 custom silhouettes)
· audio · tutorial · accessibility · performance on a low-end target · `PlatformService`,
GodotSteam, achievements · credits and licences screen · export presets and release CI · final
balance. **Gate: shippable on Steam.** Expect art direction, tutorial script, icon briefs and audio
direction as **[F]**; shaders, integration and export as **[O]**.

## M7 — Platforms (outline)

Android touch pass on a real device and AAB build · iOS (macOS runner, developer account) · web
demo (single-threaded Compatibility build, size budget) · store pages and marketing art.

---

## 6. Where the open design questions get answered

| Question | Decided at |
| --- | --- |
| UI q2 — mobile HUD shape | G2, on a real device |
| UI q1 — tech tree pauses? | D3.3, confirmed at G3 |
| UI q3 — extent of phase shift | capped in D3.3, revisited in M6 |
| PLAN §6 — four tracks or two | G3 |
| VISUALS q5 — DPITexture acceptable? | G3, executed in M6 |
| VISUALS q2 — shader globe sufficient? | S5.7 |
| VISUALS q4 — region vignettes | G4 |
| CONTENT q1, q2 — chain persistence, chains per run | D4.2, confirmed G4 |
| CONTENT q3 — Value Drift | D5.1, playtested G5 |
| CONTENT q4 — Containment mode | G5 |
