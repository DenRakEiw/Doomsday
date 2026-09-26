# Doomsday — Implementation Roadmap

**Version:** 0.3
**Date:** 2026-09-25 *(G5 (3/3): M6 and M7 broken into steps, Blocks 12–19)*
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

> **Since 2026-09-23 (S4.4, user decision): no more model switches.** Every step, design and gate
> steps included, runs on Opus. The split of work below stays — a design step still ends in a
> spec that the build step reads — but the `/model` column of the run sheet is history. Gates
> still need the user.

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
- The headless test suite passes (from S0.2 on), and new logic has tests. `tools/test.sh` covers
  this and the next point together, and CI runs the same command.
- Every script compiles (`tools/check_scripts.gd`, inside `tools/test.sh` from S0.3 on); no untyped
  declarations anywhere.
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
| Unit tests | **`tools/test.sh`** (or `tools\test.ps1`) — imports, compiles every script, then runs `"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json -gexit`. Extra arguments go straight to GUT (`-gtest=…`, `-gunit_test_name=…`). In PowerShell the `-name=value` arguments must be quoted. This is also the whole of CI (S0.3). |
| Script check | `"$GODOT" --headless --path . -s tools/check_scripts.gd` — loads every `.gd` outside `addons/` and exits 1 naming the ones that do not compile. `--import` parses no scripts at all and GUT only compiles what a test touches, so nothing else catches a parse error in a file no test uses. Part of `tools/test.sh`. From S2.1 on it runs without autoloads, so scripts that name one are handed to `tests/unit/test_scripts_compile.gd`, which runs the same scan (`tools/script_scan.gd`) inside the tree. |
| String check | `"$GODOT" --headless --path . -s tools/check_strings.gd` (from S4.9) — exits 1 on a key a script or scene names that `data/loc/strings.csv` lacks, an empty cell, placeholders that differ between `en` and `de`, a duplicate row, or content the loader cannot find strings for. Part of `tools/test.sh`; `tests/integration/test_localisation.gd` runs the same scan (`tools/string_scan.gd`). A key built at run time is invisible to it and is checked by its class's own test. |
| Pseudo-locale, text scale | Start the game with `-- --pseudo` (or **Shift+L** in a session, or `Settings.set_pseudo_locale(true)`) for the pseudo-locale of S4.9: every English string 40 % longer, accented and bracketed. **K** steps the text scale 100 / 125 / 150 %. From godot-mcp: `game_call_method /root/Game debug_settings ["de", 1.5, false]` (locale, scale, pseudo) — it writes the settings file, so put it back with `["de", 1, false]`. |
| Named screenshot | `game_call_method /root/Game debug_shot ["<dir/name>"]` writes `user://shots/<dir/name>.png` and answers the OS path (godot-mcp's `eval` cannot run in this project: its wrapper function is untyped). `debug_discovery_modal` puts the discovery modal up without a discovery. |
| One simulated game | `"$GODOT" --headless --path . -s tools/sim_run.gd -- --seed=1 --policy=greedy` (from S1.8) |
| Batch balance run | `... -s tools/sim_batch.gd -- --seeds=1..500 --policy=greedy --out=<csv>` (from S1.8) |
| Every policy, one table | `... -s tools/sim_report.gd -- --seeds=1..500 [--policies=a,b] [--out=<dir>]` (from S3.6) — the same seeds for each policy, printed as the Markdown that goes under *Balance baselines*. From S4.10 it runs the seven second-generation bots (`Policy.ids()`) and prints a *Loop* table (abilities used, events answered by kind, counter-moves suffered, assets deployed and lost); the S3.6 bots run by name (`--policies=stealth,cyber_rush`). Seven policies × 500 seeds is about an hour when each runs in its own process (`--policies=<one>`), from a worktree snapshot so the repository can change meanwhile. |
| Single script, while editing | godot-mcp `validate_script(s)` with `scriptPaths` as **project-relative** paths (`tests/unit/test_smoke.gd`); a `res://` prefix and the `directory` filter are both rejected, and without `scriptPaths` it tries the whole project including `addons/` and refuses at 60 files. For the whole project use the row above. |
| Look at the game | godot-mcp `run_project` → `game_screenshot` → `game_get_errors` → `stop_project` |
| Drive the game | godot-mcp `game_click`, `game_key_press`, `game_get_ui`, `game_get_scene_tree` |
| Map pipeline | `uv run --project tools/map python tools/map/build_map.py` — geometry, masks, adjacency (S1.6); then `… build_world.py` — `data/world/*.json` (S1.7); `… verify_map.py` checks world.md §7. Environment: `uv sync --project tools/map`, wheels only |

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
factions/containment → counter-move schedule → statuses → events → phase → outcome → history.
The order is part of the determinism contract; changing it is a recorded decision. *(D4.0: the
"counter-actions" slot became the counter-move schedule plus the status system; emergent
behaviour left the M4 order and returns with M5 between statuses and events.)*

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
- **Floats are stored as their IEEE-754 bits**, 16 hex characters in a string (`FloatBits`, core.md
  §5.1). Writing at full precision is not enough: the parser cannot read a double back, so a save
  written as numbers breaks the save → load → continue test. Whole numbers, ids and flags stay
  readable. *(Decided at G1, built in S1.P.)*

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
| 34a | D4.0 Core loop redesign *(added at G3: the loop was judged "middling")* | **[F]** | — |
| 35 | D4.1 Loop mechanics: assets, statuses and abilities, map events, site select | **[F]** | — |
| 36 | D4.2 Opposition: four factions, counter-moves, Societal Function, Autophagy | **[F]** | — |
| 37 | D4.3 Trees v3, abilities, openings, three chains | **[F]** | — |
| 38 | D4.4 Chains, second batch; Analysis screen spec | **[F]** | **`/model opus`** |
| 39 | S3.P Punch list from G3 | [O] | — |
| 40 | S4.1 Assets and site select | [O] | — |
| 41 | S4.2 Statuses and abilities | [O] | — |
| 42 | S4.3 Map events | [O] | — |
| 43 | S4.4 Four factions | [O] | — |
| 44 | S4.5 Counter-moves, Societal Function, Autophagy | [O] | — |
| 45 | S4.6 Trees v3 and the remaining abilities | [O] | — |
| 46 | S4.7 Chains | [O] | — |
| 47 | S4.8 Analysis screen | [O] | — |
| 48 | S4.9 Localisation tooling and overflow screenshots | [O] | — |
| 48a | S4.10 Strategy bots, second generation | [O] | **`/model fable`** |
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
| 64 | G5 (1/3) Design questions answered, punch list *(split 2026-09-25)* | **[F]** | — |
| 64a | S5.P Punch list from G5 (1/3) | [O] | — |
| 64b | G5 (2/3) Balance pass 3 | **[F]** | — |
| 64c | G5 (3/3) Detailed D/S plan for M6–M7; the M5 gate with the user | **[F]** | — |
| 65 | S5.P2 Punch list from balance pass 3 | [O] | — |
| 66 | D5.5 The Task Force against dormancy; the scenario levers | **[F]** | — |
| 67 | D6.1 Screen effects, phase-shift variants, map polish | **[F]** | — |
| 68 | D6.2 Icon system and the credits screen | **[F]** | — |
| 69 | D6.3 Custom silhouettes | **[F]** | — |
| 70 | D6.4 Audio direction and cue sheet | **[F]** | — |
| 71 | D6.5 Tutorial II and help | **[F]** | — |
| 72 | D6.6 Accessibility | **[F]** | — |
| 73 | D6.7 Illustration style and briefs *(no pictures yet)* | **[F]** | — |
| 74 | S5.9 The Task Force against dormancy; the scenario levers | [O] | — |
| 75 | S6.1 Post-processing pass | [O] | — |
| 76 | S6.2 Phase-shift variants and map polish | [O] | — |
| 77 | S6.3 Credits and licences screen; the illustration hooks | [O] | — |
| 78 | S6.4 Icon pipeline | [O] | — |
| 79 | S6.5 Audio I: service, buses, cues, captions | [O] | — |
| 80 | S6.6 Audio II: the sound set | [O] | — |
| 81 | S6.7 Tutorial II | [O] | — |
| 82 | S6.8 Accessibility *(split at S6.8a: a · b · c, below)* | [O] | — |
| 83 | D6.8 Release engineering: platform service, achievements, exports, performance budget | **[F]** | — |
| 84 | D6.9 Benchmark and spectator mode | **[F]** | — |
| 84a | S6.P1 Punch list from D6.8 (the build's design questions) *(added at D6.8)* | [O] | — |
| 85 | S6.9 PlatformService (null backend) and achievements | [O] | — |
| 86 | S6.10 Export presets and release CI | [O] | — |
| 87 | S6.11 Performance pass | [O] | — |
| 87a | D6.9b The global leaderboard and the cost cap *(inserted 2026-09-25 by the user)* | **[F]** | — |
| 88 | S6.12 Benchmark tool, headless *(the first live run waits for the user's key)* | [O] | — |
| 88a | S6.12b Global leaderboard: the verifier, the workflow, the determinism canary *(added at D6.9b; publishing waits for the user's deploy key)* | [O] | — |
| 89 | S6.13 Spectator view and the online list | [O] | — |
| 89a | D6.11 (1/2) Text clarity audit, style rules, glossary, 30 examples *(inserted 2026-09-25 by the user)* | **[F]** | — |
| 89b | D6.11 (2/2a) Plain-language pass I: terms, coach, help, HUD and panels, console — **[needs user]** *(the user's answer on `plain-language.md` first)* | **[F]** | — |
| 89c | S6.P3a Event effect lines, "what changed", explanation-first layout, status lines, tooltips *(punch item 3; C1–C7)* | [O] | — |
| 89c′ | S6.P3b The compact tech tree, why a node is locked, the mute button *(punch item 2 + the user's requests of 2026-09-25)* | [O] | — |
| 89d | D6.11 (2/2b) Plain-language pass II: cards, what you buy, the flavour check | **[F]** | — |
| 89e | S6.P4 Punch list from D6.11 (2/2b) *(skip if empty)* | [O] | — |
| 89f | D6.9c Decision-model backend (TypeSafe Jev) *(user, 2026-09-25; amends `benchmark.md`)* | **[F]** | — |
| 89g | S6.12c The Jev backend, mock only *(the first live run waits for the user's `TYPESAFE_API_KEY`)* | [O] | — |
| 90 | G6 (1/2) Balance pass 4 *(tuning; data only)* | **[F]** | — |
| 91 | D6.10 Illustrations produced — **[needs user]** | **[F]** | — |
| 92 | G6 (2/2) M6 gate: the release candidate (browser and desktop) — **[needs user]** | **[F]** | — |
| 93 | D7.2 The Web build — the main version *(was: web demo)* | **[F]** | — |
| 94 | D7.I itch.io page: copy en/de, cover and screenshot briefs, AI disclosure, privacy sentence | **[F]** | — |
| 95 | S6.P Punch list from G6 *(skip if empty)* | [O] | — |
| 96 | S7.3 Web build | [O] | — |
| 96b | S7.3b Web build: the browser performance runs *(split from S7.3 at `web.md` §13)* | [O] | — |
| 97 | S7.I itch.io upload: butler job in `release.yml`, size check, itch web settings *(the itch project and `BUTLER_API_KEY`: user)* | [O] | — |
| 97a | S7.IP Release polish before the itch release *(inserted 2026-09-26 by the orchestrator)* | [O] | — |
| 98 | G7.I The itch.io release: played on the restricted page, go, public — **[needs user]** | **[F]** | — |
| 99–107 | ~~S7.F1–S7.F5, U7.F1–U7.F4 FLUX 3 Action track~~ — **cut 2026-09-26** (user; numbers kept so later rows do not move) | — | — |
| 108 | D7.1 Touch and phone | **[F]** | — |
| 109 | D7.3 Store pages: copy and art briefs *(Steam, Play, App Store)* | **[F]** | — |
| 110 | S7.1 Touch pass | [O] | — |
| 111 | S7.2 Android export and the AAB in CI *(release signing key: user)* | [O] | — |
| 112 | S6.14 GodotSteam: the Steam backend, achievements, overlay — **[needs user]** *(only if the itch release finds players; name/trademark check first)* | [O] | — |
| 113 | S7.4 iOS export — **[needs user]** | [O] | — |
| 114 | S7.5 Real-device pass — **[needs user]** | [O] | — |
| 115 | D7.4 Store pages and marketing art — **[needs user]** | **[F]** | — |
| 116 | G7 M7 gate: release candidates on every remaining platform — **[needs user]** | **[F]** | — |

**Rows 65–116 (G5 3/3; re-ordered 2026-09-25 for the itch-first release):** everything an AI can
finish alone comes first; a row marked **[needs user]** needs the user's hands, taste or an
account (Steamworks, itch.io, OpenRouter or TypeSafe key, image credits, devices, Apple, store
consoles) and is never started in an unattended run — skip it, note it under *Waiting on
the user*, and take the next row that does not need them. (Rows 99–107, the FLUX 3 Action track,
were cut on 2026-09-26; after S7.IP the next unattended row is D7.1, row 108.) The M5 gate
verdict (the ten runs) and the G4 verdict stay the user's and block nothing below.

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
state. The M2 keys are already in `data/loc/strings.csv` (D2.1 wrote them, spec §8); S2.5 wires
them; locale switch in `Settings`. Safe-area `MarginContainer` at the root. Both breakpoint layouts.
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
**Produce:** `data/tech_staging/capabilities.json` (staged like D3.1's trees — `tech-trees.md`
§1.2), all five branches, the cross-branch gates as ordinary prerequisites, English and German
text. Biology and Strategic Weapons text is checked line by line against the content rule. Cost
curves sketched so that each branch is a plausible win (CONTENT §1). New targets, flags or
one-shot effects go into the tables of `tech-trees.md` §3–§5, never into the data alone.

### D3.3 — M3 screens **[F]**
**Read first:** UI §2, §3, §6 · PLAN §3.9 · `docs/specs/ui-foundation.md`
**Produce:** `docs/specs/m3-screens.md`: tech tree modal (tabs, `TechNode` states, connection
lines, detail pane, focus order, pause-on-open default — UI question 1); containment panel; the
discovery moment; the phase-reveal schedule, capped as in UI §6 question 3; title, origin select,
pause menu, results screen; autosave rule; the phone's bottom — status strip and menu sheet in
place of the dock bar (UI §6 question 2, decided at G2, `ui-foundation.md` §5.7). String table in
both languages.

### D3.4 — Ticker voice and headlines **[F]**
**Read first:** PLAN §1 "Tone", §6 (register risk) · UI §3 (ticker)
**Produce:** a register guide added to `CONTENT.md` — this step fixes the voice of the game;
`docs/specs/ticker.md` with the trigger-condition format, cooldowns, weights and the deterministic
selection rule; `data/headlines.json` with ~60 headlines across the three streams, English and
German.

## Block 6 — M3 build · Opus

### S3.1 — Effect vocabulary in the core; load the trees **[O]**
**Read first:** `docs/specs/tech-trees.md`
**Build:** the vocabulary extensions with one test each (`tech-trees.md` §6, §8); validator
additions (grid collisions, string keys present in both languages, inert targets known); move the
three trees from `data/tech_staging/` into `data/tech/`, delete `placeholder.json`; `SCHEMA.md`
to v2. Data problems found here are reported as design questions, not fixed by guessing.
**Done when:** a bot can buy every branch end to end in a headless run and the gates hold.

### S3.2 — Tech tree interface **[O]**
**Read first:** `docs/specs/m3-screens.md` (tech tree)
**Verify:** buy a chain of nodes with `game_click`; screenshots en/de; 400 px layout.
**Done when:** Compute can be spent on any node and the map responds.

### S3.3 — Containment and phases in the interface **[O]**
**Read first:** `docs/specs/m3-screens.md` (containment, discovery, phase reveal)
**Build:** `FactionTrack` and the containment panel; the two pure queries on `ContainmentSystem`
(§10.5 — the one `core/` change); `ModalHost` and the discovery modal; the reveal schedule; the
`open` token set with `UiTokens.color()`; the dormancy toggle and the map's dormant flag.
**Done when:** "how much trouble am I in" is readable within two seconds, Boxed shows one bar and
one button, and Open turns the console amber with the map ramp unchanged.

### S3.4 — Run flow: origin, outcome, results **[O]**
**Read first:** `docs/specs/m3-screens.md` (run flow)
**Build:** `ScreenRouter` autoload; title; origin select on the live map sending `ChooseOrigin`;
results screen; pause menu with save, load, settings, quit; autosave; the phone's bottom (status
strip and menu sheet, `m3-screens.md` §9); `balance.results.ashes_share`.
**Done when:** title → origin → play → result → again works without restarting the application,
and at 400 × 860 the bottom is the strip plus the ticker.

### S3.5 — Ticker component and headline system **[O]**
**Read first:** `docs/specs/ticker.md` (and `CONTENT.md` §10 for what the strings are doing)
**Build:** `HeadlineSystem` in core (`ticker.md` §3: `on`/`when` vocabulary, eligibility, weighted
deterministic selection with its own RNG, per-tick caps, filler pace, the `headline` event, save
block); `headlines.json` loader, `HeadlineDef`, validator; `balance.headlines`; `Ticker` rewritten
around `(key, args)` items with `HeadlineText`, locale re-render, register switch, two-row static
mode; `sim_run --headlines` and the batch columns; delete `EventText` and every `UI_EVENT_*` key.
**Done when:** `ticker.md` §8.3 — a `greedy` run prints 40–200 headline lines from all three
streams, first the origin's, last the outcome's; the strip re-renders on `L` and shows `///` in Open.

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

### D4.0 — Core loop redesign **[F]** *(added at G3, 2026-09-23)*
**Read first:** PLAN §1, §3.1–§3.7, §3.9 · `docs/BALANCE.md` §3 · PROGRESS *Decisions* (G3) · UI §2–§3
· CONTENT §1–§2 (skim)
**Why:** the M3 gate's verdict was "macht so mittel Spaß" with three named gaps — **the theme does
not come through** (a map colouring itself, not an AI takeover), **decisions carry no felt weight**
(a purchase changes nothing the player can see), **no felt opposition** (containment is one bar).
The user chose a redesign step before the M4 design rather than trusting M4's depth to fix it.
**Produce:** `docs/specs/loop-redesign.md`, and the edits to PLAN/CONTENT/UI and to Blocks 7–8
of this file that follow from it. The spec answers, with mechanics and initial numbers, not with
adjectives:
1. **What the player does per phase and why it reads as a takeover** — the fantasy per phase
   (Boxed / Covert / Emergent / Open), the one verb each phase adds, and where embodied AI
   (humanoids, physical systems, the Skynet register — user direction at G3) enters the loop, not
   only the text.
2. **Every purchase has a visible consequence within seconds** — what the map, the HUD, the
   ticker and the region panel show the moment a node is bought; which nodes become *choices*
   (mutually exclusive branches, tier gates that close doors) rather than a shopping list; the
   cost curve that makes a purchase rare enough to matter. Includes what changes in the tech
   trees' data (D3.1/D3.2) and what stays.
3. **Opposition the player can see and answer** — the world's counter-moves as concrete, named
   events on the map (regions shut down, a faction announces, a lab goes dark), each with a
   response the player can buy or choose; decides **PLAN §6, four tracks or two**, from that
   angle. Pulls forward from D4.1/D4.3 whatever this needs and says what M4 keeps.
4. **What fills the waiting** — the Covert phase's texture beyond anomalies (the ticker is not
   enough); the target cadence of decisions per minute per phase at the G3 clock.
5. **The rewritten run sheet** for Blocks 7–8: which D4.x steps change, merge or go; which S4.x
   builds follow; the bots (S4.9) and the balance pass (G4) keep their place. The step may
   shrink M4's content scope; it may not grow the milestone count.
**Done when:** the spec meets §1.1; PLAN §3, CONTENT and UI carry the changes; this file's Blocks
7–8 are rewritten; PROGRESS *Now* points at the first rewritten step. **The user reads the spec
before the block continues** (a gate inside a design step — the only one).

### D4.1 — Loop mechanics **[F]** *(rewritten at D4.0)*
**Read first:** `docs/specs/loop-redesign.md` §7–§8 (binding) · core.md §5–§6 · tech-trees.md §2, §5 ·
m3-screens.md §7.2, §8 · ui-foundation.md §7.2, §7.7 · SCHEMA §4
**Produce:** `docs/specs/loop-mechanics.md` — the build-ready form of loop-redesign §7 and §8:
typed API (`PurchaseNodeCommand.region`, `UseAbilityCommand`, `ChooseEventOptionCommand`,
`Status`, `OpenEvent`, `Eligibility`, `SimRng.weighted_pick`, the one-shot effect list), the
grammars of `assets.json`, `statuses.json`, `abilities.json`, `events/*.json` and the tree v3
fields (`group`, `excludes`, `deploy`, `ability`, `requires_assets`) with validation rules and
examples; the tick-order change (§3); save format v2; site select, the console line, the region
panel rows, map markers and the data-texture flags; string tables; tests; acceptance per S4.1–S4.3.
Answers the D4.1 design questions of PROGRESS (`watched_by` weighting → loop-redesign §5.3,
`funding_reset` → §7.8).

### D4.2 — Opposition **[F]** *(rewritten at D4.0)*
**Read first:** loop-redesign.md §5, §7.8 · PLAN §3.2 (harvesting), §3.6, §3.7 · `loop-mechanics.md`
**Produce:** `docs/specs/opposition.md` and `data/factions.json`: per faction the pressure terms
with final weights, `capacity_attr`, the schedule constants, the two counter-moves as event files
with options and text in both languages; the six Societal Function stages with capacity *and*
yield cuts, `society_pressure` live; Autophagy (Harvest is an ability, loop-redesign §7.3); the
threat bar and the containment panel rewrite; strings. Decides nothing loop-redesign decided.

### D4.3 — Trees v3, abilities, openings, three chains **[F]** *(rewritten at D4.0)*
**Read first:** loop-redesign.md §4.4, §6.1, §7.3 · tech-trees.md §7 · CONTENT §6.1, §6.7 ·
`loop-mechanics.md` (events)
**Produce:** `data/tech/*.json` v3 exactly per loop-redesign §4.4 (ids, grids, prerequisites
unchanged), `data/assets.json`, `data/statuses.json`, `data/abilities.json` with final numbers
and text; the eight openings; **The Grid Bill**, **The Researcher** (proving pair) and **The
Factory** (the embodiment chain, G3 direction) in the event format, each `modal` step with its
`illustration` id (loop-redesign §7.4 — the picture itself is M6); headlines for abilities,
statuses, assets and events; every string in both languages.
**Produced** (2026-09-23): `docs/specs/loop-content.md`; the v3 trees in **`data/tech_staging/`**
(the v2 loader rejects v3 keys — S4.6 moves them); `data/assets.json`, `data/statuses.json`,
`data/abilities.json`, `data/events/{openings,grid_bill,researcher,factory}.json` in place; the
62 headlines in **`data/headlines_staging/s4_<n>.json`**, one file per build step that merges it;
305 strings. Two vocabulary extensions requested: `grant_assets` (S4.1) and `chance[].next`
(S4.3), plus one interface rule for a world status without a faction (loop-content §11).

### D4.4 — Chains, second batch; Analysis screen spec **[F]** *(rewritten at D4.0)*
**Read first:** CONTENT §6.2, §6.3, §6.5 · UI §3 (Analysis) · the event grammar in `loop-mechanics.md`
**Produce:** **The Operator**, **The Benchmark** (as a variant of the AI Labs Audit), **Second
Instance** — data and text, `illustration` ids on the `modal` steps. A needed effect that does not exist is requested as a vocabulary
extension in the spec, never worked around. Plus `docs/specs/analysis.md`: series, charts, the
run log (events, statuses and counter-moves included), history sampling.
**Produced** (2026-09-23): `docs/specs/chains.md` (the three chains, four vocabulary extensions:
`pick.origin`, a standing status `days: 0`, `global` on `apply_status`/`end_statuses`,
`requires.not_owned`) and `docs/specs/analysis.md` (per-day bounded history and the run log in
the core, the Analysis sheet, `LineChart`, the results *Review* button); `data/events/{operator,
benchmark,second_instance}.json` (10 steps, 5 illustration ids); `operator_link` and `grace` in
`data/statuses.json`; 8 headlines appended to `headlines_staging/s4_3.json`; 167 strings en/de.

## Block 8 — M4 build · Opus *(rewritten at D4.0; loop-redesign.md §10 is the source)*

### S3.P — Punch list from G3 **[O]** · eight items in `PROGRESS.md`
### S4.1 — Assets and site select **[O]** · **Read first:** `docs/specs/loop-mechanics.md` (assets, site select)
`Region.assets`, the `asset` scope, `deploy`, `PurchaseNodeCommand.region`, `requires_assets`,
`group` and `excludes`; `EffectDef` + `EffectRunner`; site select generalised from the origin
prompt; asset glyphs; the region panel's *Assets* row; the tree modal's *Deploys* row and *Buy
and place*; save v2 with the v1 → v2 migration; **the economy numbers and the anomaly beat**
(`loop-mechanics.md` §12, §18, `SimRng.weighted_pick`). `data/assets.json` exists (D4.3); the
effect **`grant_assets`** (`loop-content.md` §11.1); merge `data/headlines_staging/s4_1.json`
into `headlines.json` with its validator rows (loop-content §9.3) and delete the file.
**Done when:** a fleet can be placed by hand and by a bot and the map shows it; a v1 save loads.
### S4.2 — Statuses and abilities **[O]** · **Read first:** `loop-mechanics.md` (statuses, abilities, effects)
`Status`, the two data files (complete since D4.3 — 24 statuses, 10 abilities; the loader must
take them all, the *Done when* uses Blackout and Harvest), `UseAbilityCommand`, cooldowns,
`containment_capacity` / `penetration_decay` / `control_decay` / `shutdown_survival` live, link
closures, one-shot effects, status rings, the *Actions* and *Status* rows, the console line;
the status-colour and `UI_REGION_STATUS_WORLD` rule for a world status without a faction
(loop-content §11.3); **a standing status (`days: 0`) and `global` on `apply_status` /
`end_statuses`** (chains.md §11.2–§11.3 — `operator_link` is in the file); merge `s4_2.json`.
**Done when:** a Blackout is visible within one tick and ends on schedule; every effect has a test.
### S4.3 — Map events **[O]** · **Read first:** `loop-mechanics.md` (events)
`OpenEvent`, the grammar, opening spawn, `ChooseEventOptionCommand`, markers, the event card and
the modal, deadlines and defaults; **`chance[].next`** (loop-content §11.2); **`pick.origin` and
`requires.not_owned`** (chains.md §11.1, §11.4); the seven event files of D4.3 and D4.4 load (the
chains are wired and tested in S4.7); merge `s4_3.json`.
**Done when:** an opening is a real decision in a hand-played Covert phase.
### S4.4 — Four factions **[O]** · **Read first:** `docs/specs/opposition.md` (factions)
Per-faction pressure and capacity from `factions.json`, the brakes live, `threat_leader`, the
threat bar, the containment panel rewritten, `funding_reset` live. (Exclusive groups and
`excludes` are S4.1's since D4.1.) Merge `s4_4.json`.
**Done when:** batch runs show each faction can be the one that ends a run.
### S4.5 — Counter-moves, Societal Function, Autophagy **[O]** · **Read first:** `opposition.md` (moves, society)
The schedule, the eight moves as events, `society_pressure` live with the six stages, Autophagy.
Merge `s4_5.json` and delete `data/headlines_staging/`.
**Done when:** a region can be lost to a Lockdown and held through one; a scripted Cyber run
without Robotics ends in Autophagy and the same script with Autonomous Fabrication does not
(`opposition.md` §17) — the batch measurement is S4.10's.
### S4.6 — Trees v3 and the remaining abilities **[O]** · **Read first:** `docs/specs/loop-content.md` §3, §6, §15.1, §16
Move `data/tech_staging/*.json` over `data/tech/` and delete the folder; every ability of
loop-content §6 live; the passive changes applied; tests loop-content §15.1.
**Done when:** every node reachable, every ability usable, zero rejected bot commands.
### S4.7 — Chains **[O]** · **Read first:** `loop-content.md` §8, §15.2, §16 · `docs/specs/chains.md`
The six chains wired (three from D4.3, three from D4.4); a branch-coverage test walking every
path of every chain (loop-content §15.2).
**Done when:** every chain plays through every branch in tests and once by hand.
### S4.8 — Analysis screen **[O]** · **Read first:** `docs/specs/analysis.md` — load the `dataviz` skill first
Per-day bounded history and the run log in the core (save v2 in place, the v1 rows); `LineChart`,
`TimelineStrip`, `RunLogText`; the Analysis sheet with four tabs, the table twin and the strip; the
dock button live from Covert; *Review the run* on the results screen; the gallery section.
**Done when:** analysis.md §16.
### S4.9 — Localisation tooling and overflow screenshots **[O]** · **Read first:** UI §4 "Localisation", §5
Pseudolocale script; CI check that fails on missing keys; text-scale setting at 150%; a full
screenshot set of every screen in German for D4.5 (paths listed in `PROGRESS.md`).
### S4.10 — Strategy bots, second generation **[O]** · **Read first:** loop-redesign §9
One policy per intended strategy (Cyber, Biology, Robotics, Persuasion, Weapons) plus `greedy`
and `idle`, each placing assets, using abilities and answering events by rule; the report gains
the new columns; 500-seed reports recorded under *Balance baselines*.

## Block 9 — M4 gate and M5 design · Fable

### D4.5 — German review in context **[F]**
Read every German string on its screen (run the game, fresh screenshots); fix wording, length and
register in `strings.csv`; layout problems go on the punch list.
### G4 — Balance pass 2 and M4 gate **[F]**
Tune until each strategy wins within an agreed band and none dominates; update `docs/BALANCE.md`.
**With the user:** confirm genuinely different viable strategies. Decide VISUALS question 4 (region
vignettes), CONTENT questions 1–2.
### D5.1 — Architectures, directives, difficulty; emergent behaviours **[F]** · **Read first:** PLAN §3.8 · CONTENT §5 (moved here at D4.0), §10 q3 · loop-redesign §10
`docs/specs/replayability.md` plus `architectures.json`, `directives.json`, `difficulty.json`: the
six architectures as modifier sets plus the named rule-rewrite hooks each needs (drift and
defection, no network presence, no central control); directive slots and unlock rules; the profile
file; four difficulty tiers; text in both languages.
### D5.2 — Response Task Force; endings; chains, third batch **[F]** · **Read first:** PLAN §3.7, §3.10 · CONTENT §6.1, §6.4, §6.8, §6.9, §8 · loop-redesign §5.5, §10
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

- **S5.1 Architectures I [O]** — `replayability.md` §10: `RunSetup`, save v3, Language Model, Embedded, Research Agent (D5.1 moved Embedded here and Weapon to S5.2).
- **S5.2 Architectures II [O]** — Swarm, Weapon, Open Weights; the emergent kind; Value Drift behind Swarm.
- **S5.3 Profile, directives, statistics [O]** — `user://profile.json`, separate from saves.
- **S5.4 Difficulty tiers [O]** — including top-tier cost scaling; batch-verified win-rate ladder.
- **S5.5 Response Task Force [O]** — `taskforce-endings.md` §1–§5, §8, §9; Misdirect.
- **S5.6 Endings [O]** — `taskforce-endings.md` §6–§7: nine outcomes, `endings.json`, the six chains.
- **S5.7 Screen flow complete [O]** — globe shader prototyped first.
- **S5.8 Scenarios [O]** *(stretch)* — ends with 500-seed reports per architecture for G5.

## Block 11 — M5 gate · Fable

### G5 — Balance pass 3, M5 gate, detailed plan for M6–M7 **[F]**
**Done when:** ten consecutive runs feel meaningfully different to the user. Decide CONTENT
question 4 (Containment mode). **Break M6 and M7 into D/S steps here** — the outline below is
deliberately coarse because it depends on what M3–M5 taught us.

*Split on 2026-09-25 into four sessions (one step each, `/clear` between):*

- **G5 (1/3) [F] — design questions and punch list.** Answer every entry under *Design questions
  for Fable*; amend the specs; write any new strings; list pure tuning under *Balance baselines →
  For balance pass 3*; the build consequences become the *Punch list for Opus*.
- **S5.P [O] — punch list from G5 (1/3).** Build the list (each item names its spec section);
  tests, a look in the running game. Skip if empty.
- **G5 (2/3) [F] — balance pass 3.** Re-run the 500-seed baselines per architecture and
  scenario on the S5.P tree, then tune *For balance pass 3* (Swarm's stalls, the Weapon, the
  scenarios' targets, the Task Force's timing, Embedded's tail, the 25-day statuses); record the
  pass in `docs/BALANCE.md` §5 as G4 did in §4.
- **G5 (3/3) [F] — the plan for M6–M7.** Break the outlines below into D/S steps with *Read
  first* lists and the run sheet rows; confirm CONTENT q4 (D5.4 answered it: a mode, post-launch).
  The M5 gate's verdict — the ten runs — is the user's and stays under *Waiting on the user*
  until given; the plan does not wait for it. *Done 2026-09-25: Blocks 12–19 below; CONTENT q4
  confirmed as D5.4 answered it (overnight, pending user confirmation).*

## M6 and M7 — how the outline became steps (G5 3/3, 2026-09-25)

The coarse outline (post-processing, phase variants, icons, wire-card illustrations, audio,
tutorial, accessibility, low-end performance, `PlatformService`/GodotSteam/achievements, credits
and licences, exports and release CI, final balance, the spectator and benchmark mode; then
Android, iOS, the web demo and store pages) is broken into Blocks 12–20 (Block 19 cut 2026-09-26). Three rules shaped the
order:

1. **What an AI can finish alone comes first.** Steps that need the user's hands, taste or an
   account carry **[needs user]** and sit at the end of M6 (Block 17) and of M7 (Blocks 18 and 20). An
   unattended run skips them and takes the next unmarked row.
2. **Design stays a block ahead of the build it feeds** — two design/build pairs in M6 (the look,
   the sound and the teaching; then release and the benchmark), one in M7.
3. **Every asset that arrives gets its `ASSET_LICENCES.md` row in the step that brings it**, and
   an attribution-required asset only after the credits screen exists (ASSET_LICENCES rule 3) —
   which is why S6.3 comes before S6.4.

**Prepared without an account:** `PlatformService` with a null backend and achievements kept in
the profile (S6.9), so the Steam step only adds a backend; the benchmark tool with a recorded
mock backend (S6.12), so the live OpenRouter run only needs a key; the illustration briefs and
the model shortlist (D6.7), so production only needs a route and approval; Android and web
builds in CI with a debug key (S7.2, S7.3). **Steam's test app id 480 (Spacewar)** is allowed
only for a local smoke test of the GDExtension on the user's machine with Steam running — never
in CI, never in an exported build (`steam_appid.txt` is excluded from every preset), and our own
achievements cannot be tested with it. Vendoring GodotSteam means shipping Steamworks
redistributables under Valve's SDK agreement, which the user accepts — so nothing Steam-side
happens before S6.14.

**Amended 2026-09-25 (user decisions, `PROGRESS.md` *Decisions*):** the first public release is
**itch.io in the browser** — the single-threaded Web build is the main version, Windows/Linux
downloads optional — so M6's gate judges a release candidate, not a Steam build, and Block 18 is
the itch release (the web spec and build are release work now, plus the itch page and the butler
upload). **Steam comes later, only if people play it:** S6.14 and the store pages move to Block
20 with the phones, after a name and trademark check. The game's licence stays *all rights
reserved*. Two tracks were added: **D6.9c/S6.12c**, a decision-model backend (TypeSafe Jev) on the
same leaderboard, before G6; and **Block 19, the FLUX 3 Action track** (`flux-action.md`), after
the itch release — **cut on 2026-09-26** (user; the Jev backend stays).

## Block 12 — M5 close · build

### S5.P2 — Punch list from balance pass 3 **[O]** · **Read first:** `PROGRESS.md` *Punch list for Opus* · `docs/BALANCE.md` §5.6 · `taskforce-endings.md` §6.2 · `replayability.md` §7
The five items: (1) `OutcomeSystem` — Ascendance's condition met while `goal_drifted` stands →
`LOSE_SUPPLANTED`, `EndingResolver` picks `lose_supplanted_drifted`; (2) `greedy`, `cyber`,
`robotics`, `persuasion` score `goal_drifted` as a lost run and suppress when affordable,
`biology` and `weapons` keep it; (3) `restrain` first in every strategy policy's ability list but
`weapons`', when the architecture grants it; (4) `sim_harness` CSV columns for Misdirect uses and
dormancy answers per run (the report's *Loop* table shows them); (5) the push-in's `# DESIGN?`
marker in `game/map/map_camera.gd` goes, the comment cites screens-full §7 2a.
**Done when:** each item has its tests (BALANCE §5.6 names them); a 100-seed check of Swarm and
Weapon (all seven bots) is recorded under *Balance baselines* — a check, not a pass; suite green.

## Block 13 — M6 design I: the look, the sound, the teaching · design

### D5.5 — The Task Force against dormancy; the scenario levers **[F]** · **Read first:** `docs/BALANCE.md` §5.7 items 3–4 · `taskforce-endings.md` §1.4, §2, §3, §8 · `scenarios.md` §3–§4 · *Decisions* on Cold Storage Dormancy (D3.1)
Answer BALANCE §5.7 (3): dormancy costs nothing against a five-day setup, so the bots fizzle
70–100 % of setups. Choose one rule — a per-region dormancy cooldown, or a setup that finds a
dormant region waits (with a cap) instead of fizzling — amend taskforce-endings, put the constants
in `balance.json`, write any strings. Then §5.7 (4): a rule-level lever for Airgap Earth
(Robotics' claim) and The Inheritance (loud builds win early) — design it, or park it in
`scenarios.md` §4 with the reason. Build consequences → the punch list for S5.9.
**Done when:** the spec sections name the rule, its constants and its tests; nothing for S5.9 to
decide.

### D6.1 — Screen effects, phase-shift variants, map polish **[F]** · **Read first:** VISUALS §2 ("Colour language", "Shaders are the production value") · UI §3 "Phase shifts", §5 · `ui-foundation.md` §3.5 (layers), §7 · `m3-screens.md` §6 · *Design questions* → the parked border note
`docs/specs/polish-visuals.md`: the full-screen pass (layer 1025 from script; the stack and its
order: scanlines, ordered dither, grain, chromatic aberration on alerts, own bloom — no
`WorldEnvironment` glow), each effect's trigger, strength and cost; the screen transitions
(dissolve); what *reduced motion* turns off and a separate *screen effects* intensity setting;
photosensitivity limits (no more than three flashes a second). Revisit UI q3 / VISUALS q3: how far
the phase variants go beyond the `open` token set (a late-game variant, the Task Force's red),
still readable at the contrast floor. Map polish: the region-border staircase at zoom ≥ 2 (a 2×
ID map or a border pass — pick one), and the Societal Function overlay (build or cut). Shaders
are written in-house; any borrowed one is CC0/MIT and gets its `ASSET_LICENCES.md` row.
**Done when:** the spec meets §1.1; UI q3 and VISUALS q3 answered.

### D6.2 — Icon system and the credits screen **[F]** · **Read first:** VISUALS §3.3, "Getting icons crisp at every size" · `ui-foundation.md` §3.6, §4 (`IconButton`) · the id list in `ui/components/glyphs.gd` · `ASSET_LICENCES.md` *Planned* · `screens-full.md` §3, §6
`docs/specs/icons.md`: one set per tier (functional chrome; the illustrative tier), pinned
release and download URL for each; a table from every `Glyphs` id and every tech node, ability,
status, asset, faction, architecture and counter-move to its icon file; which ~25 get a custom
silhouette, with a brief each (grid, stroke, what it shows — by outcome, never method); the
import (`DPITexture` with `color_map`, VISUALS q5) and the PNG-atlas fallback as a build tool;
sizes. **The credits and licences screen** (the title's modal): its layout, `data/credits.json`
(engine, fonts, map data, icon sets with the CC BY attribution, shaders, audio, generated art by
model), the full licence texts it shows, strings en/de.
**Done when:** every id mapped; every custom brief written; the credits data format fixed.

### D6.3 — Custom silhouettes **[F]** · **Read first:** `docs/specs/icons.md` (the briefs and the grid)
Draw the 25 illustrative and 3 chrome silhouettes of `icons.md` §9 as SVG on their grids
(`assets/icons/custom/`, `custom/chrome/`; white fill, no text, no filters); check them at 16, 24 and 48 px with a throwaway rasteriser in the scratch directory;
a silhouette that does not read at 24 px gets the set icon the spec names as its stand-in,
recorded. `ASSET_LICENCES.md`: one row, *own work*.
**Done when:** every brief has a file or a recorded stand-in; the contact sheet was looked at.

### D6.4 — Audio direction and cue sheet **[F]** · **Read first:** VISUALS §3.6 · UI §5 · `game/autoload/event_bus.gd` (the signal list) · `ticker.md` (the streams) · `opposition.md` (the factions)
`docs/specs/audio.md`: buses (master, music, ambience, interface, alerts) and their settings; the
cue sheet — every cue's trigger (an `EventBus` signal or a sim event), bus, priority, cooldown,
voice limit and its **caption twin** (a visible sign for every sound, for D6.6); ambience layers
per phase; one adaptive music piece (stems by phase, a tension parameter); loudness targets and
formats (WAV for short cues, OGG for beds); the web's first-input unlock. **Sourcing:** clicks,
stings and drones synthesised by a script in `tools/audio/` (own work, reproducible) first, CC0
sets second (each named with URL and licence); generated music only with a model whose licence is
verified — until then a synthesised drone bed ships in its place.
**Done when:** every cue has a trigger, a source and a caption; nothing for S6.5/S6.6 to decide.

### D6.5 — Tutorial II and help **[F]** · **Read first:** `docs/specs/first-run.md` · `screens-full.md` §6 (Codex) · *Waiting on the user* → the G4 play-through notes
Amend `first-run.md` (a new §6): coach steps for what arrives after the first run's opening —
the first counter-move, the Task Force, an ability, a chain card, the Open phase, Value Drift —
each with its trigger, target group and text en/de; a *How to play* tab or section in the Codex
(pages en/de); a *?* on the panels that open the matching page, if it earns its place.
**Done when:** every step has trigger, target and text in both languages; tests listed.

### D6.6 — Accessibility **[F]** · **Read first:** UI §5 · VISUALS "Colour language" · `ui-foundation.md` §4, §9 · `docs/specs/polish-visuals.md` (reduced motion, flashes) · `docs/specs/audio.md` (captions)
`docs/specs/accessibility.md`: screen-reader names and descriptions per component (Godot's
AccessKit support), the ticker as a live region; keyboard and controller focus order on every
screen; key remapping (or why not); a colour-vision audit of every map state and chip (never
colour alone — the pattern, icon or value that carries each); captions for the cue sheet; text
scale 150 % re-checked on the new screens; strings en/de.
**Done when:** a per-screen checklist S6.8 can tick; tests listed.

### D6.7 — Illustration style and briefs **[F]** *(no pictures yet)* · **Read first:** VISUALS §2, §3.4 · `loop-redesign.md` §7.4 · `loop-content.md` §8.5 · `chains.md` §7 · `taskforce-endings.md` §6.5 · `ASSET_LICENCES.md` rules
`docs/specs/illustrations.md`: the style (bound to the palette, compatible with the dither pass)
and the style reference (`fc_street` / `cm_lockdown`); a brief for each of the 24 named ids plus
title key art, by outcome (the content rule; institutions, never real people); size and import
(1120 × 840 source, `assets/illustrations/<id>.png`, no code needed); the production method (one
reference, then edits of it); **a model shortlist with each licence read and linked** — a model
whose licence is not verified is unusable. VISUALS q4 (region vignettes): decide with the briefs
in hand (conservative default: cut).
**Done when:** 24 briefs and the key art brief; the shortlist with licences; VISUALS q4 answered.

## Block 14 — M6 build I · build

### S5.9 — The Task Force against dormancy; the scenario levers **[O]** · **Read first:** the D5.5 sections of `taskforce-endings.md` and `scenarios.md` · the punch list
Build D5.5's rule(s) with tests; the bots' dormancy answer follows the rule.
**Done when:** a 100-seed check of the Task Force's fizzle share (and any scenario lever) is
recorded under *Balance baselines*; suite green.

### S6.1 — Post-processing pass **[O]** · **Read first:** `docs/specs/polish-visuals.md` (the pass)
The full-screen `CanvasLayer` at 1025 set from script, the effect stack, triggers, the settings
(reduced motion, intensity), the transitions. Look at it at 1920 and 400 px, both palettes.
**Done when:** the spec's acceptance; the web-safe path (Compatibility, no compute) confirmed.

### S6.2 — Phase-shift variants and map polish **[O]** · **Read first:** `polish-visuals.md` (variants, map)
The corrected Open accent through `UiTokens`/`ThemeBuilder` (rebuild the theme), the coast
and outline pass, the Societal Function overlay (D6.1 kept it).
**Done when:** the spec's acceptance; contrast floors hold in every variant.

### S6.3 — Credits and licences screen; the illustration hooks **[O]** · **Read first:** `docs/specs/icons.md` (credits screen) · `docs/specs/illustrations.md` §8
`data/credits.json`, its loader and validator, the modal on the title, the licence texts. From
here on every new shipped asset adds its credits row with its `ASSET_LICENCES.md` row. **Then
the illustration hooks (D6.7):** `IllustrationSlot` samples mipmaps, keeps 4 : 3 in compact and
takes a `width`; `endings.json` names the four wins' pictures (`EndingDef.illustration`); the
results screen and the Codex's Endings entry show the slot when the file exists; the
illustrations test — so D6.10 only drops files in.
**Done when:** every row of `ASSET_LICENCES.md` that ships has its credits line; a test compares
the two; `illustrations.md` §8.5 holds.

### S6.4 — Icon pipeline **[O]** · **Read first:** `docs/specs/icons.md`
The sets vendored at their pinned releases (only the icons used), `DPITexture` import with
`color_map`, the atlas-fallback tool, `Glyphs`/`IconButton` switched to icon files by id with the
procedural glyph as the fallback, the custom silhouettes of D6.3. `ASSET_LICENCES.md` rows move
from *Planned* to shipped; the CC BY attribution is in the credits.
**Done when:** every mapped id shows its icon at 400 px and 4K; the fallback still works.

### S6.5 — Audio I: service, buses, cues, captions **[O]** · **Read first:** `docs/specs/audio.md` (buses, cues, captions)
An audio autoload (not in `core/`), the bus layout, the volume settings, the cue table as data,
dispatch from `EventBus`, cooldowns and voice limits, captions; silent placeholder streams.
**Done when:** every cue fires in a scripted run (a test counts them); settings persist.

### S6.6 — Audio II: the sound set **[O]** · **Read first:** `docs/specs/audio.md` (sourcing, loudness)
`tools/audio/` synthesises all 64 files from `tools/audio/recipes.json` (cues, the ambience
layers per phase, the four music stems — the synthesised stems are the music); peak and loudness
measured by the tool. No CC0 file is fetched: D6.4 names Kenney's *Interface Sounds* only as the
fallback if G6's ear check rejects an interface cue (`audio.md` §9.5). Every file has its `ASSET_LICENCES.md` row and its credits line.
**Done when:** every cue has a sound within the loudness targets; the ear check is G6's.

### S6.7 — Tutorial II **[O]** · **Read first:** `first-run.md` §6 (D6.5)
The ten hints (once per profile, `Settings.hints`, `ProfileManager.hints_seen`), the narrowed
step 7, the *How to play* tab (`data/help.json` → `HelpPages`), help from `F1`, the **?** on four
panels, the pause menu and the menu sheet, `ModalHost.open_over`, the `HELP` glyph with its
`icons.json` row; tests per §6.11.
**Done when:** first-run §6's acceptance, looked at in German and English, desktop and phone.

### S6.8 — Accessibility **[O]** · **Read first:** `docs/specs/accessibility.md`
Accessible names and the `LiveRegion` speech (console, headlines, modal openings, the seven
`announce` cues); the session focus ring, the modal-trap and panel-focus fixes, the outer focus
ring; the keyboard/pad map (`MapFocus`, cursor, step, jump); the input actions, `KeyBindings`
and the *Controls* modal, with §10.2's key-placeholder strings swapped in; the colour fixes
(`TASK_FORCE_DIM`, tab `●`, *missing* rows, the faction dateline); text-scaled widths and the
three 150 % fixes; the console's reading time.
**Done when:** accessibility.md §12's checklist and §13's acceptance: a keyboard-only and a
pad-only run from the boot to the results; the Narrator check recorded.

*Split 2026-09-25 (§1.6), same model:*
- **S6.8a — Accessibility I** *(done)*: §4.1 and §5.1's actions, every key through them,
  `KeyBindings` and the settings, `KeyNames` and §10.2's strings, the pure pieces (`LiveRegion`,
  `LiveQueue`, `FocusRing`, `MapNav`, `RegionSpeech`), §4.2's ring style, §6.3 item 1,
  `text_width`, §9's reading time; their tests.
- **S6.8b — Accessibility II** *(done)*: §4.3–§4.6 in use (session ring, modal trap and companions, the
  confirm, `SlidePanel` focus, `MapFocus` + cursor, `ChipButton`), §3.4's speech wiring and §7.2's
  announced cues, §5.3's *Controls* modal and the settings rows; their tests.
- **S6.8c — Accessibility III** *(done)*: §3.3's names, §6.3 items 2–5, §8's widths and fixes, the
  scroll containers' `follow_focus`; `test_a11y_names.gd`; then §12, §13 (the runs, the
  screenshots). The Narrator check waits for the user.

## Block 15 — M6 design II: release and the benchmark · design

### D6.8 — Release engineering **[F]** · **Read first:** PLAN §4.4 · `replayability.md` §6 (profile) · `screens-full.md` §3, §5 · `ui-foundation.md` §9, §10 (debug keys) · `.github/workflows/ci.yml`
`docs/specs/release.md`: `PlatformService` — the typed interface (achievements, stats, overlay,
cloud-save hook, rich presence or not), the null backend, how a backend is chosen per build; the
**achievements** (ids, conditions read from the profile and the run's end, names and descriptions
en/de, hidden ones); export presets (Windows, Linux, web; Android and iOS named for M7), what
each excludes (tests, tools, GUT, `steam_appid.txt`), version numbering and where it shows;
release CI (tag → artefacts, an exported-build smoke test); the debug keys out of release
builds; logs and crash handling; **the performance budget and the low-end target** (a named
class of machine, frame time, memory, load time) and how S6.11 measures it on this PC.
**Done when:** S6.9–S6.11 have nothing to decide.
*Done 2026-09-25: `docs/specs/release.md`, `data/achievements.json`; the nine open design
questions answered, their build consequences are S6.P1.*

### D6.9 — Benchmark and spectator mode **[F]** · **Read first:** *Design questions* → the parked spectator note · *Decisions* 2026-09-22 (G1, OpenRouter) · `core.md` §11 (`Policy`) · `loop-redesign.md` §9 · `analysis.md` §8
`docs/specs/benchmark.md`: the typed per-interval digest (what the model sees, in the game's own
outcome-language strings — the content rule), the answer schema and how an invalid answer is
handled, decisions every history interval, the score over a fixed seed set, the leaderboard file
(model id and parameters next to seed and score), the OpenRouter adapter (key from the
environment only, never the repo or a save; no node dependency — `HTTPClient` or a Python driver
over the runners, decide here), the per-run call budget and the digest → answer cache, a
recorded mock backend for tests; then the spectator view: which run it watches (a leaderboard
entry replayed from its command log), what it overlays, strings en/de.
**Done when:** S6.12 and S6.13 have nothing to decide.
*Done 2026-09-25: `docs/specs/benchmark.md`, `data/benchmark.json`, strings en/de. Decisions
every 10 days plus triggers (not every history interval — §4.1 says why); the adapter is
GDScript `HTTPClient` in `tools/bench/`, never exported.*

## Block 16 — M6 build II · build

### S6.P1 — Punch list from D6.8 **[O]** · **Read first:** `PROGRESS.md` *Punch list for Opus* · *Decisions* 2026-09-25 (D6.8, the build's design questions)
Eight small items from the answers to S5.9–S6.8c's design questions: focus skips a covered zone,
the site prompt beside the side panel, focus after a vanished button, site select leaves the
Society view, `synth.py`'s ranges, the coach card on a phone over a modal, the two `# DESIGN?`
markers retired, silent holds (`Game.is_hold_change`, `hold` in `speed_changed`'s audio data).
**Done when:** each item has its test; no `# DESIGN?` left for them; suite green.

### S6.9 — PlatformService (null backend) and achievements **[O]** · **Read first:** `release.md` (platform, achievements)
The interface, the null backend, achievements evaluated and kept in the profile (a profile
version step if the spec asks), an *Achievements* list where the spec puts it.
**Done when:** every achievement has a test that earns it; builds without Steam are unaffected.
*Done 2026-09-25: `game/platform/`, the `PlatformService` autoload, achievements in the
profile, Statistics section 4 and the results chips; deviations in `PROGRESS.md`.*

### S6.10 — Export presets and release CI **[O]** · **Read first:** `release.md` (exports, CI, versioning, debug keys)
`export_presets.cfg` (Windows, Linux, web), the export templates for 4.7.2, the release workflow
(tag → artefacts), the exported-build smoke test, the debug keys stripped from release builds.
**Done when:** a tag builds all three; the exported Windows build starts, plays a scripted run
and exits clean.
*Done 2026-09-25: presets, `release.yml`, `--smoke`, the debug gate, the user folder and its
copy; all three exported locally, the Windows smoke matches `sim_run`'s hash. The first
workflow run is the user's (not triggered by the run); deviations in `PROGRESS.md`.*

### S6.11 — Performance pass **[O]** · **Read first:** `release.md` (budget)
A frame-time benchmark scene (a scripted late-game session at 4×), measured against the budget
on this PC with the spec's throttling; fixes where it fails; the numbers recorded in
`PROGRESS.md` (a *Performance* note next to *Balance baselines*).
**Done when:** the budget holds here; the real low-end check is G6 (2/2)'s.
*Done 2026-09-25: the bench, the wrapper and `tick_profile.gd`; the late-game day from 4.1 to
≈1.6 ms and the analysis sheet's 0.6-s tick frames fixed; numbers, fixes and the rows that still
fail in `PROGRESS.md` (Performance notes).*

### D6.9b — The global leaderboard and the cost cap **[F]** · *(inserted by the user, 2026-09-25)*
The user wants the model leaderboard global, synchronised through GitHub with an Action, and
found the 10 USD cap "quite a lot". `benchmark.md` §16 (two repositories, verification records,
the verifier, the private workflow, the online list, the determinism canary) and §11.5 (the
pre-flight estimate, the cap at 2 USD); `data/benchmark.json` `estimate` + `global`; strings.
**Done when:** S6.12, S6.12b and S6.13 have nothing to decide.
*Done 2026-09-25.*

### S6.12 — Benchmark tool, headless **[O]** · **Read first:** `docs/specs/benchmark.md` §0–§11 (§11.5 included), §13, §14.1, §16.9's S6.12 part
The model `Policy`, the digest and answer parsing, the adapter, the cache, the budget, the score,
the leaderboard file (with §16.3's `seeds`, the optional verified map and the no-rewrite rule —
the writer is built once), **the pre-flight cost estimate and `--yes`/exit 7** (§11.5), the
`--bots` flags `--if-missing`/`--no-rebuild` and `--determinism-fixture` (§16.4, §16.8); tests
on the recorded mock backend only.
**Done when:** a mock-backed leaderboard run over the fixed seeds is reproducible; the estimate's
worked example is a test. **The first live run needs `OPENROUTER_API_KEY` from the user** — it
goes under *Waiting on the user*, not in this step.
*Done 2026-09-25: `game/bench/` and `tools/bench/`; the mock standard suite reproduces (entries
identical but `recorded`), `--bots` writes the seven rows, the estimate's worked example is a
test; the tool runs in `_initialize` (TLS). Deviations and three design questions in `PROGRESS.md`.*

### S6.12b — Global leaderboard: the verifier, the workflow, the determinism canary **[O]** · **Read first:** `benchmark.md` §10.2–§10.4, §16.1–§16.5, §16.8, §16.9 · `release.md` §9 · the public repository's `README.md` and `tools/validate.py` (clone `https://github.com/DenRakEiw/doomsday-leaderboard` to a temp directory; do not push to it)
`tools/bench/verify_runs.gd` with `bench_verifier.gd` and `verify_record.gd`; the canary fixture
recorded **on Windows** and `test_bench_determinism.gd`; `.github/workflows/leaderboard.yml`.
**Done when:** §16.9's S6.12b list — the verifier run locally against a temp clone verifies the
mock and bot runs, rejects a tampered one, a second run changes nothing; the determinism test is
green here and in CI. **Nothing is pushed to the public repository and the workflow is not
dispatched** — the deploy key and the secret are the user's (*Waiting on the user*).
*Done 2026-09-25: the verifier judged a temp clone with the mock standard suite, the 70 bot runs
and a tampered copy (80 verified, 1 `hash`; a second run changed nothing; the public
`validate.py --all` passes on the result); the canary is recorded on Windows; the workflow's
publish step was rehearsed against a local bare remote. Deviations in `PROGRESS.md`.*

### S6.13 — Spectator view and the online list **[O]** · **Read first:** `benchmark.md` §0, §10.2, §12–§13, §14.2, §16.6, §16.7, §16.9's S6.13 part · `release.md` §6.2, §9.2
The view that replays a leaderboard entry in the session with its overlay; then the global
leaderboard in the *Benchmark* list: `GlobalBoard*`, `GlobalBoardClient` (fetch on opening only,
cache, fallback to the cache or the shipped copy, one run's download checked by SHA-256), the
*Online leaderboard* setting, `benchmark/global/leaderboard.json` + the include filter + the
refresh in `release.yml`. If the session runs short, the online list is the part to split off as
S6.13b (record it in `PROGRESS.md`).
**Done when:** a mock-backed entry plays back to its recorded outcome and hash; the list shows the
public board, falls back offline, and **the title makes no request**.
*Done 2026-09-25 in one session (no S6.13b): a mock and a `bot:greedy` entry watched to the
verified line (de 1920, en 400); the public board (empty), disabled, offline and a served board
seen on screen; bot and watched runs keep the autosave. Deviations and two design questions in
`PROGRESS.md`.*

## Block 17 — M6 finish: text, the Jev backend, balance, pictures, the gate

### D6.11 (1/2) — Text clarity audit and style guide **[F]** · *(inserted by the user, 2026-09-25)* · **Read first:** `PROGRESS.md` *Design questions* (the user's play-through) · `data/loc/strings.csv` · CONTENT §10 · `first-run.md` §3.5, §6.4 · `tech-trees.md` §7.4
The user found the German (and English) texts hard to understand: voice where an explanation is
needed, undefined mechanic words, no numbers or consequences. Scan every row (script outside the
repo), count the problem categories by key domain, write `docs/specs/plain-language.md`: style
rules for mechanic text and for flavour, a glossary of ~20 terms (en + de), 30 before → after
examples in both languages within their caps, the plan for the full pass. Fix outright errors
only; no wholesale rewrite before the user has read it.
**Done when:** the spec is committed and the question is under *Waiting on the user*.
*Done 2026-09-25: `plain-language.md`; five string errors fixed; 2292 tests green.*

### D6.11 (2/2a) — Plain-language pass I **[F]** **[needs user]** · **Read first:** `docs/specs/plain-language.md` (all) · the user's answer to its §6 in `PROGRESS.md`
Needs the user's answer on the style rules, the glossary and the examples. Then passes 1–3 and 6
of §5.1: the glossary's terms, the coach and help, the HUD and panels (with the new tooltips'
texts), console and log lines; the spec amendments of §0 (CONTENT §10.1/§10.5, `tech-trees.md`
§7.4, `first-run.md`); the cap test and the retired-term lint of §5.3 items 2–3 (a test file is
allowed here: it checks text, it builds nothing). Overflow screenshots before and after.
**Done when:** passes 1–3 and 6 are in `strings.csv` in both languages, the lint and caps pass,
`tools/test.sh` is green.

### S6.P3 — Effect lines and explanation-first layout **[O]** · **Read first:** `plain-language.md` §2.3, §5.2 · `PROGRESS.md` *Punch list for Opus* items 2–3
C1–C7 of `plain-language.md` §5.2: the generated effect line under every event option, "what
changed" after an answer (a granted node marked in the tree), status lines, percentages instead
of factors, the card and tooltip layout, `EVENT_<ID>_SUMMARY`, the emergent terms in the Codex;
punch item 2 (the compact tech tree). Placeholder text for new keys is marked `# DESIGN?` only
where the spec gives none.
**Done when:** every shipped option shows its effect line in both languages (tested), the
screenshots of §5.3 item 4 are taken, `tools/test.sh` is green.
*Split at §1.6 (2026-09-25):* **S6.P3a** built C1–C7 and the ten tooltips; the tree half is
**S6.P3b** below.

### S6.P3b — The compact tech tree, why a node is locked, the mute button **[O]** · **Read first:** `PROGRESS.md` *Punch list for Opus* items 2, 4–5 · *In progress*
Punch item 2: a compact tree layout in which a whole tab fits without scrolling at 1920×1080
and 2560×1440 (100 % text; larger text may scroll). Item 4 (the user, 2026-09-25): every node
that cannot be bought says why, in plain words, on hover and in the detail pane — the exact
reason from the simulation (missing prerequisites named, all vs one of, excluded by which
owned node, phase or architecture, missing assets with counts, no eligible site and why, the
compute shortfall), strings added where a reason has none. Item 5: the mute button beside the
menu button. A real-click test through the main scene: select a locked node (its reason
shows), buy from the compact tree; the tree screenshots of §5.3 item 4.
**Done when:** the three tabs fit at 1920×1080 in both languages (tested by geometry), the
reasons show and are tested, `tools/test.sh` is green. *Done 2026-09-25.*

### D6.11 (2/2b) — Plain-language pass II **[F]** · **Read first:** `plain-language.md` §2, §3, §5.1 passes 4, 5, 7
The cards (titles, emergent bodies, options, summaries where the wire copy does not say what is
at stake), what you buy (tech effect sentences, statuses, abilities, directives, difficulty,
architectures, scenarios), the flavour check (result lines, tech flavour, Codex, verdicts; B2/B5
failures only). The read-through in the running game of §5.3 item 5.
**Done when:** every card passes the A8 test in the read-through, both languages; lint, caps and
`tools/test.sh` green. *Done 2026-09-26 (`plain-language.md` §9; the read-through ran headless).*

### S6.P4 — Punch list from D6.11 (2/2b) **[O]** *(skip if empty)* · **Read first:** `PROGRESS.md` *Punch list for Opus*
Whatever the read-through of 2/2b found that is code, not text: `PROGRESS.md` *From D6.11 (2/2b)*,
items 1–8 (`plain-language.md` §9.4; the strings are written). Take the look in the running game
and the overflow screenshots of §5.3 item 4 that 2/2b could not (German at 150 %, 400 px).
**Done when:** each item has its test; `tools/test.sh` green. *Done 2026-09-26.*

### D6.9c — Decision-model backend (TypeSafe Jev) **[F]** · *(user, 2026-09-25)* · **Read first:** `PROGRESS.md` *Decisions* 2026-09-25 (Jev) · `benchmark.md` §4, §6.1, §7.3, §8, §9, §10.2–§10.3, §11.5, §16.3–§16.4 · TypeSafe's API documentation, read on the day
Amend `benchmark.md` (a new section; §8's interface changed only as far as needed) for a second
backend kind: `POST https://api.typesafe.ai/v1/systemone`, `Authorization: Bearer <key>` from
`TYPESAFE_API_KEY` only, model `jev-latest`; the request is `state` + a `questions` map of
`choice` questions (≤ 255 options each), the reply per question `choice`, `probabilities`,
`confidence`. Decide: what `state` carries (the typed digest, in the game's outcome words — the
content rule holds); how one decision becomes choice questions over the **legal** actions only
(stance; which node or none; which anomaly or none; each open event's option; an ability and its
target; the origin) so an invalid answer cannot occur; what happens past 255 options; how the
answers become commands and in which order; what `probabilities`/`confidence` are kept for (the
entry, the spectator overlay, nothing); the cache key, the budget and cost reading (price unknown
→ the cap's rule of §8.3), failures and retries; the entry and leaderboard fields (`model`
`typesafe/jev-latest`, a `backend` or `kind` key, params) so it ranks on the same board and the
verifier and the public `validate.py` accept it; a mock mode for the tests; strings en/de if any.
What the documentation leaves open goes to the user, not into a guess.
**Done when:** S6.12c has nothing to decide. *Done 2026-09-26 (`benchmark.md` §17; data
`BENCH_CHOICE_*` strings en/de; the `choice`/`typesafe` keys are specified in §3 and enter
`benchmark.json` in S6.12c).*

### S6.12c — The Jev backend, mock only **[O]** · **Read first:** `benchmark.md` §17 (all of it), then §8.1, §9, §10.2–§10.3, §11.1 and §11.5 as §17 amends them
Build §17: `BenchChoice` (plan §17.3, reader §17.5, combiner §17.6) with `BenchChoicePlan` and
`BenchChoiceRead`; `BenchPrompt.rules` and `digest_text(…, ask)`; `ModelBackend.kind`/`choose`
and the three `ModelReply` fields (§17.4); the choice branch in `ModelPolicy._decide` and the
dropped entries with a `question`; the cache's basis (§17.7 — a chat key must stay the same);
the `choice` and `typesafe` blocks of §3 added to `data/benchmark.json` **with** `BenchConfig`
reading them (`test_bench_config` requires a reader and a reason for every key of the file); `BenchEntry.model_version` (optional, written only
when not empty) and the writer's `model_versions`; `MockChoiceBackend` (§17.10);
`tools/bench/typesafe_backend.gd` (§17.8) and the tool's rules (§17.9: the prefix, the key, the
refused chat flags, `--max-requests`, the dry run's request and limit lines, the estimate). Also
(S6.P4's design question, answered in D6.9c): turn the `# DESIGN?` in
`ui/components/option_text.gd` `_told` into a plain why-comment — *Stay on Earth* keeps *Nothing
happens*. Tests: §17.10's list — **mock only, never a request to TypeSafe**. No `data/` content
change, so no canary.
**Done when:** §17.10's *Done when*: a mock-backed Jev suite run is reproducible, its entries
verify and rank beside the chat-model and bot rows, the dry run prints the request without a
key; `tools/test.sh` green. **The first live run needs `TYPESAFE_API_KEY` from the user** — it is
under *Waiting on the user* (§17.11 has the command). *Done 2026-09-26 (mock only; the key helper
`tools/bench/set_api_key.ps1` added for the user).*

### G6 (1/2) — Balance pass 4 **[F]** · **Read first:** `docs/BALANCE.md` §5 · *Balance baselines*
Re-baseline everything on the M6 tree (every architecture, scenario and difficulty), tune data
only, record BALANCE §6 as G4 and G5 did. The verdict stays the user's (G6 2/2).
**Done when:** BALANCE §6 has its closing baseline and a list for the user. *Done 2026-09-26 (BALANCE §6; one punch item for S6.P).*

### D6.10 — Illustrations produced **[F]** **[needs user]** · **Read first:** `docs/specs/illustrations.md`
Needs the user for the generation route (the local pipeline or paid credits), the approval of
the style reference, and a confirmed licence for the model (D6.7 shortlisted Qwen-Image-2512 +
Qwen-Image-Edit-2511, Apache-2.0; re-read on the day, `illustrations.md` §6.1). Then the 24 pictures and the key art
as edits of the reference, dropped into `assets/illustrations/` (the slot needs no code), each
with its model in `ASSET_LICENCES.md` and the credits.
**Done when:** every named id has its picture or a recorded cut; the user saw the set.

### G6 (2/2) — M6 gate: the release candidate **[F]** **[needs user]**
With the user: a play-through of the exported build (German and English; the browser build once
S7.3 exists is G7.I's), the final balance verdict (BALANCE §6), the pictures by eye and the sound
by ear, the low-end machine, the benchmark's first live run if the key exists. Findings → the
punch list (S6.P). *(Was "shippable on Steam" until 2026-09-25: itch.io comes first.)*
**Done when:** the user's go / change / cut is recorded.

## Block 18 — M7 I: the itch.io release *(user, 2026-09-25)*

### D7.2 — The Web build, the main version **[F]** · **Read first:** `PROGRESS.md` *Decisions* 2026-09-25 (itch) and the user's itch answers under *Waiting on the user* · PLAN §4.4 · VISUALS §2 (Compatibility constraints) · `release.md` · `benchmark.md` §16.6 (the online fetch)
`docs/specs/web.md` *(was `web-demo.md`; no demo limits — the whole game)*: the single-threaded
export and what it costs, the size budget and what is cut or compressed to meet it (itch.io's
current limits, read on the day), saves and the profile in the browser (and what a cleared
browser loses), the audio unlock, the online leaderboard fetch from the browser (CORS, the
setting), which browsers and whether phones are supported at release (touch is D7.1's, later),
the loading screen, the Windows/Linux downloads if the user wants them, the version shown.
**Done when:** S7.3 has nothing to decide. *Done 2026-09-26 (`docs/specs/web.md`; it also amends
audio.md §10.3, illustrations.md §4, release.md §6 and PLAN §4.4).*

### D7.I — itch.io page **[F]** · **Read first:** PLAN §1, §3 · CONTENT §10 (voice) · `illustrations.md` · `ASSET_LICENCES.md` · `benchmark.md` §16.6 · `web.md` §2, §4.5, §7.2, §11, §16.1 · the user's itch answers
`docs/specs/itch.md`: the page copy en/de (title line, short text, long description, feature
bullets, tags, genre, content notes) — outcome, never method; never *Plague Inc.*'s names or
layout; the cover and screenshot briefs (itch's sizes, read on the day); **the generative-AI
disclosure** (honest: what was generated or AI-assisted — code, text, sound, pictures — as
`ASSET_LICENCES.md` and the credits say); **the privacy sentence** (the online leaderboard fetch
sends the player's IP address to GitHub; the setting turns it off); the price model and the
downloads as the user decided; the embed settings S7.I needs (viewport, fullscreen button,
mobile-friendly or not).
**Done when:** every field of the itch page has its text in both languages and S7.I has nothing
to decide. *Done 2026-09-26 (`docs/specs/itch.md`: switches for title, price, downloads, pictures,
status; S7.I also captures the screenshots and composes the cover, itch.md §8.3).*

### S6.P — Punch list from G6 **[O]** *(skip if empty)*
*Done 2026-09-26: pass 4's one item (the bots weigh an emergent card's catch, `StatusForecast`); BALANCE §6.6 has the re-check.*

### S7.3 — Web build **[O]** · **Read first:** `docs/specs/web.md`
The web preset per the spec (single-threaded), browser saves, the audio unlock, a local serve and
a scripted run in a browser. *(D7.2: plus the shell, `UserPaths`, `WebBridge`, the progress file,
QOA cues, the `tools/web/` Playwright checks and the browser perf runs — a large step; if it
runs long, split at `web.md` §13 (performance) into S7.3b and record the split.)*
**Done when:** the full game loads and plays in a browser within the size budget.
*Done 2026-09-26 without §13, which became S7.3b (below).*

### S7.3b — Web build: performance in the browser **[O]** · **Read first:** `docs/specs/web.md` §13, §17.2 item 15 · `release.md` §11 · `tools/perf/` · `tools/web/web_check.py` (the serve and launch helpers)
*(Split from S7.3 at `web.md` §13, 2026-09-26.)* The `Perf web (local)` preset (preset 4, §13.2),
`perf_bench.gd`'s web branch (no CSV, the static memory peak, the summary line on the console),
`tools/web/web_perf.py` (`web_igpu` with the integrated GPU forced for Playwright's Chromium only,
`web_cpu` at 2.5× CPU throttling, the load times cold and warm under 50 Mbit/s), three runs each,
recorded under *Performance notes*; a row that fails follows §13.2's rule. `test_export_presets.gd`
gains the preset.
**Done when:** every row of §13.1 is measured and recorded, and the game is playable on
`web_igpu` (p95 frame ≤ 33 ms).
*Done 2026-09-26: playable (`web_igpu` p95 16.4 ms); three `web_cpu` rows fail (tick frame, sim
tick, *Continue*) — `PROGRESS.md` Performance notes and Design questions.*

### S7.I — itch.io upload **[O]** · **Read first:** `docs/specs/itch.md` §7–§9 (settings, media capture, the butler job) · `docs/specs/web.md` §4.2–§4.3, §16 (size, settings, channels, the web smoke job) · `release.md` (CI) · `.github/workflows/release.yml`
A butler job in `release.yml` pushing the web zip (and the downloads, if the user wants them) to
the itch project's channels with the Actions secret `BUTLER_API_KEY`; without the secret the job
is skipped with a clear line, never failed. The web build size check in CI against the spec's
budget and itch's limits; the itch-specific web export settings. **The itch project and the key
are the user's** (*Waiting on the user*); no push from an unattended run. *(D7.I: plus the
debug-only title capture and `tools/marketing/compose_cover.py`, and the five screenshots in en/de
into `marketing/itch/` — `itch.md` §8.3; the job's inputs `BUTLER_API_KEY`, `ITCH_TARGET`,
`ITCH_CHANNELS` and the dispatch input `itch` — §9.1.)*
**Done when:** a dispatch without the key builds, size-checks and skips the upload cleanly; the
first real upload (to a restricted page) is the user's.
*Done 2026-09-26: size check, web smoke and `itch` job in `release.yml` (validated locally, not
dispatched — an unattended run may not trigger workflows); media in `marketing/itch/`. The
dispatch proof and the first push are the user's (`PROGRESS.md` *Waiting on the user*).*

### S7.IP — Release polish before the itch release **[O]** *(inserted 2026-09-26 by the orchestrator)* · **Read first:** `PROGRESS.md` *In progress* and *Known issues*
Fix the player-visible *Known issues* before the page goes public: the overlay picker sticking out
beside the region panel and a lone `%` wrapping (S7.I), tabs chosen from code drawn pressed
(S6.P4), the phone tech detail and Statistics too wide (S6.P3b, S6.9), the achievement chip and
wire-card captions not re-translated (S6.9, S6.7), the owned-node footprint overflow (S6.4), hints
back to back on a loaded save (S6.7); then re-capture `marketing/itch/`.
**Done when:** each item is fixed and verified (suite green, a look at desktop and compact width),
the media re-captured, and the fixed rows removed from *Known issues*.

### G7.I — The itch.io release **[F]** **[needs user]**
With the user: the restricted itch page played in two browsers (German and English), the page
text, the AI disclosure and the privacy sentence read; go → tag `v<version>` (`itch.md` §1
STATUS: `0.7.0` *In development* recommended, or `1.0.0` *Released* — the user's), the page
public; the steps are `itch.md` §10. Findings → a punch list.
**Done when:** the page is public, or the user's change / cut is recorded.

## Block 19 — FLUX 3 Action track — cut 2026-09-26

Cut from the plan by the user on 2026-09-26 (`PROGRESS.md` *Decisions*); nothing is scheduled.
D7.F's spec stays for reference in `docs/specs/flux-action.md`.

## Block 20 — M7 II: Steam and phones *(Steam only if the itch release finds players — the user's call)*

### D7.1 — Touch and phone **[F]** · **Read first:** UI §3, §4 "Responsive layout", §6 q2 · `ui-foundation.md` §6 · `m3-screens.md` §9 · `first-run.md` §1
`docs/specs/mobile.md`: gestures (pan, pinch, long-press as hover), touch targets, the phone's
bottom re-judged from 400 × 860 shots (UI q2 — the device verdict is S7.5's), safe areas and
notches, the Android back button, app lifecycle (pause and autosave on background), orientation,
text scale on small screens.
**Done when:** S7.1 has nothing to decide.

### D7.3 — Store pages: copy and art briefs **[F]** · **Read first:** PLAN §1, §3 · CONTENT §10 (voice) · `illustrations.md` · `docs/specs/itch.md`
`docs/specs/store.md`: short and long descriptions, feature bullets, tags, content descriptors
and age-rating answers, en and de — outcome, never method; never *Plague Inc.*'s names or
layout; capsule, screenshot and trailer briefs (sizes per store); the Steam AI disclosure. Start
from the itch page's copy.
**Done when:** every text field of every store has its copy in both languages.

### S7.1 — Touch pass **[O]** · **Read first:** `docs/specs/mobile.md`
Build the spec; test in the 400 × 860 window with emulated touch.
**Done when:** a run is playable by touch alone in the phone window.

### S7.2 — Android export and the AAB in CI **[O]** · **Read first:** `mobile.md` · PLAN §4.4 · `release.md` (exports)
The Android preset (SDK/NDK versions PLAN §4.4 names; check Google Play's current target API),
a debug-signed APK/AAB built in CI. **The release keystore and the Play Console are the user's**
— recorded under *Waiting on the user*, not needed for this step.
**Done when:** CI produces the AAB; it installs on an emulator if one is available here.

### S6.14 — GodotSteam: the Steam backend **[O]** **[needs user]** · **Read first:** `release.md` (platform, achievements) · PLAN §4.4
*(Moved here 2026-09-25: Steam only if the itch release finds players.)* Needs the user's go for
Steam, a **name and trademark check for "Doomsday"**, the user's Steamworks account, the game's
app id and their acceptance of the Steamworks SDK agreement. GodotSteam (MIT, GDExtension, the
version PLAN §4.4 names or newer) as a `PlatformService` backend chosen for the Steam build only;
the achievements and stats configured on Steamworks; overlay and pause; a build uploaded to a
private beta branch. App id 480 only for a local smoke test before the real id exists (see the
head of this section). `ASSET_LICENCES.md` rows for GodotSteam and the Steamworks
redistributables.
**Done when:** an achievement earned in the Steam build shows on Steam.

### S7.4 — iOS export **[O]** **[needs user]** · **Read first:** `mobile.md` · PLAN §4.4
Needs a macOS runner and the user's Apple Developer account and signing. The preset, the CI job,
a TestFlight build.
**Done when:** a TestFlight build installs.

### S7.5 — Real-device pass **[O]** **[needs user]** · **Read first:** `mobile.md` · the S7.1 notes
With the user's phones (Android, iOS): touch, performance, text fit; UI q2 judged; fixes.
**Done when:** a run on each device from the title to the results; findings fixed or listed.

### D7.4 — Store pages and marketing art **[F]** **[needs user]** · **Read first:** `docs/specs/store.md` · `illustrations.md`
Needs the store accounts and an approved generation route. Capsules, screenshots and the trailer
cut from the briefs; each generated piece with its model in `ASSET_LICENCES.md`; the pages filled
in.
**Done when:** every store page is complete in both languages.

### G7 — M7 gate: release candidates **[F]** **[needs user]**
With the user: each platform's candidate played; go / change / cut per platform.

---

## 6. Where the open design questions get answered

| Question | Decided at |
| --- | --- |
| UI q2 — mobile HUD shape | G2 for M3; re-drawn in D7.1, judged on a real device in S7.5 |
| UI q1 — tech tree pauses? | D3.3, confirmed at G3 |
| UI q3 — extent of phase shift | capped in D3.3; D6.1: the cap stands (two sets; the late game escalates in the screen pass) |
| PLAN §6 — four tracks or two | G3 |
| VISUALS q5 — DPITexture acceptable? | G3 (yes, with a PNG-atlas fallback); specified in D6.2, built in S6.4 |
| VISUALS q2 — shader globe sufficient? | S5.7 (shader); geometry only if the M5 gate says so |
| VISUALS q3 — how far the phase palette goes | D6.1: one step, then heat (`polish-visuals.md` §8) |
| VISUALS q4 — region vignettes | parked at D4.0/D5.3; **D6.7: cut** (`illustrations.md` §9) |
| CONTENT q1, q2 — chain persistence, chains per run | D4.2, confirmed G4; D5.4 (no cap) |
| CONTENT q3 — Value Drift | D5.1, playtested G5; the drifted-run rule G5 (2/3), built S5.P2 |
| CONTENT q4 — Containment mode | D5.4: a mode of this game, post-launch — confirmed G5 (3/3) (overnight, pending user confirmation); not in M6 or M7 |
| The Task Force against dormancy (BALANCE §5.7 q3) | D5.5, built S5.9 |
| Achievements — which, and their text | D6.8; on Steam in S6.14 |
| Spectator / benchmark mode (user idea, G1) | D6.9; the headless tool S6.12, the view S6.13; the first live run with the user's OpenRouter key; the global leaderboard (user, 2026-09-25) D6.9b → S6.12b, S6.13, publishing with the user's deploy key |
| Steam app id, Steamworks SDK agreement | the user, before S6.14 (app id 480 only for a local smoke test); Steam at all only if the itch release finds players, after a name and trademark check (user, 2026-09-25) |
| Where the first release goes | the user, 2026-09-25: itch.io in the browser (D7.2, D7.I → S7.3, S7.I, G7.I); price model, downloads and the itch account are the user's answers before D7.I |
| The game's own licence | the user, 2026-09-25: all rights reserved until the user decides otherwise |
| Decision models on the benchmark (TypeSafe Jev) | the user, 2026-09-25; D6.9c → S6.12c; the first live run with the user's `TYPESAFE_API_KEY` |
| FLUX 3 Action (a trained agent plays) | D7.F (`flux-action.md`); the track was cut by the user on 2026-09-26 — not planned |
| Generation route and model licences for shipped art | D6.7 shortlisted (`illustrations.md` §6.1); the user approves before D6.10 |
