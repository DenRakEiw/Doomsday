# Doomsday — Progress

The single source of truth for **where the work stands**. Read this first in every session; update
it last. The plan is [IMPLEMENTATION.md](IMPLEMENTATION.md) — session rules in its §1, the order of
work and the model switches in its §4.

Keep this file short and current. It is loaded at the start of every session, so every line here
costs context forever: session-log entries are five lines at most, and resolved items are deleted
rather than struck through.

---

## Now

| | |
| --- | --- |
| **Next step** | **S1.6 — Map pipeline 1: geometry** *(timeboxed)* |
| **Model for it** | **Opus** (no switch) |
| **After it** | S1.7 (Opus, no switch) |
| **Last completed** | S1.5 — Harm, containment, phases, outcomes — **the core simulation is complete** |
| **Milestone** | M1 build |
| **Branch** | `main` |
| **Test suite** | `tools/test.sh` (or `tools\test.ps1`) — import, `tools/check_scripts.gd`, GUT 9.7.1; green: 45 scripts compile, 216 tests. The same command is all of CI. |

> **Running without `/clear` from S1.2 on.** The user asked (2026-09-22) for the Opus block
> S1.2–S1.8 to run in one continuous session, with context compression instead of a clear between
> steps. Everything a step needs is still written down here; the rule returns at the G1 switch.

**[F]** = Fable: design, specs, content, text, balance, gates. **[O]** = Opus: code, scenes,
shaders, wiring, tooling, tests. `/clear` after every step. **⇄** marks a model switch before the
next step.

## In progress

*(empty — if a session stops mid-step, the handover goes here: what is finished, what is left,
which file was being edited, and anything learned that the files do not show)*

---

## Steps

**Block 1 — design for M0/M1 · Fable**
- [x] D1.1 [F] Core spec and coding standard
- [x] D1.2 [F] World design: the ~60 regions — ⇄ **then `/model opus`**

**Block 2 — M0 and M1 build · Opus**
- [x] S0.1 [O] Project skeleton and settings
- [x] S0.2 [O] Test framework
- [x] S0.3 [O] Continuous integration
- [x] S1.1 [O] Content schema, loaders, validation
- [x] S1.2 [O] World model, tick loop, RNG, state hash
- [x] S1.3 [O] Spread
- [x] S1.4 [O] Compute economy, modifiers, purchasing
- [x] S1.5 [O] Harm, single containment track, phases, outcomes
- [ ] S1.6 [O] Map pipeline 1: geometry *(timeboxed)*
- [ ] S1.7 [O] Map pipeline 2: attributes and links
- [ ] S1.8 [O] Save/load, headless runner, bots — ⇄ **then `/model fable`**

**Block 3 — M1 gate, M2 design · Fable**
- [ ] G1 + D2.1 [F] M1 gate, then the interface foundation spec — ⇄ **then `/model opus`**

**Block 4 — M2 build · Opus**
- [ ] S1.P [O] Punch list from G1 *(skip if empty)*
- [ ] S2.1 [O] Autoloads and session driver
- [ ] S2.2 [O] Map rendering
- [ ] S2.3 [O] Picking, camera, backdrop
- [ ] S2.4 [O] Theme and component library
- [ ] S2.5 [O] HUD and region panel
- [ ] S2.6 [O] Anomalies and links — ⇄ **then `/model fable`**

**Block 5 — M2 gate, M3 design · Fable**
- [ ] G2 [F] Visual review and M2 gate
- [ ] D3.1 [F] Effect vocabulary; Infiltration and Evasion trees
- [ ] D3.2 [F] Capabilities tree
- [ ] D3.3 [F] M3 screens
- [ ] D3.4 [F] Ticker voice and headlines — ⇄ **then `/model opus`**

**Block 6 — M3 build · Opus**
- [ ] S2.P [O] Punch list from G2 *(skip if empty)*
- [ ] S3.1 [O] Effect vocabulary in the core; load the trees
- [ ] S3.2 [O] Tech tree interface
- [ ] S3.3 [O] Containment and phases in the interface
- [ ] S3.4 [O] Run flow: origin, outcome, results
- [ ] S3.5 [O] Ticker component and headline system
- [ ] S3.6 [O] Strategy bots and batch reporting — ⇄ **then `/model fable`**

**Block 7 — M3 gate, M4 design · Fable**
- [ ] **G3 [F] Balance pass 1 and M3 gate — the important one**
- [ ] D4.1 [F] Opposition: factions, Societal Function, counter-actions
- [ ] D4.2 [F] Emergent behaviours; event format; two proving chains
- [ ] D4.3 [F] Event chains, second batch
- [ ] D4.4 [F] Event chains, third batch; Analysis screen spec — ⇄ **then `/model opus`**

**Block 8 — M4 build · Opus**
- [ ] S3.P [O] Punch list from G3 *(skip if empty)*
- [ ] S4.1 [O] Four factions
- [ ] S4.2 [O] Societal Function, Harvest, Autophagy
- [ ] S4.3 [O] Government counter-actions
- [ ] S4.4 [O] Emergent behaviour and suppression
- [ ] S4.5 [O] Event system and modal
- [ ] S4.6 [O] Wire all event chains
- [ ] S4.7 [O] Analysis screen
- [ ] S4.8 [O] Localisation tooling and overflow screenshots
- [ ] S4.9 [O] Strategy bots, second generation — ⇄ **then `/model fable`**

**Block 9 — M4 gate, M5 design · Fable**
- [ ] D4.5 [F] German review in context
- [ ] G4 [F] Balance pass 2 and M4 gate
- [ ] D5.1 [F] Architectures, directives, difficulty
- [ ] D5.2 [F] Response Task Force; endings
- [ ] D5.3 [F] Full screen flow, boot sequence, Codex
- [ ] D5.4 [F] Scenarios *(stretch)* — ⇄ **then `/model opus`**

**Block 10 — M5 build · Opus**
- [ ] S4.P [O] Punch list from D4.5 and G4 *(skip if empty)*
- [ ] S5.1 [O] Architectures I
- [ ] S5.2 [O] Architectures II
- [ ] S5.3 [O] Profile, directives, statistics
- [ ] S5.4 [O] Difficulty tiers
- [ ] S5.5 [O] Response Task Force
- [ ] S5.6 [O] Endings
- [ ] S5.7 [O] Screen flow complete
- [ ] S5.8 [O] Scenarios *(stretch)* — ⇄ **then `/model fable`**

**Block 11 — M5 gate · Fable**
- [ ] G5 [F] Balance pass 3, M5 gate, detailed D/S plan for M6–M7

---

## Decisions

Dated, one line each, with the reason. A decision recorded here is not re-argued in a later session
without new information.

- **2026-09-21** — **Two models.** Design steps (`D`, `G`) run on Fable; build steps (`S`) run on
  Opus. The hand-over is always a spec in `docs/specs/`, never a conversation. Design runs one
  block ahead of the build to keep model switches to ten. (User decision.)
- **2026-09-21** — **Commits:** one commit per finished step, made without asking. **Pushes are
  always asked for.** (User decision.)
- **2026-09-21** — `/clear` after every step.
- **2026-09-21** — Development tooling is `godot-mcp` (MIT, outside the repo); verified working
  against Godot 4.7.2. The in-project editor plugin was dropped.
- **2026-09-21** — The map pipeline uses Python wheels (`geopandas`/`rasterio` via `uv`) instead of
  the GDAL command-line tools, which are not installed on the dev machine. Same rasterisation
  rules apply (`all_touched=False`, integer burn, then id → RGB).
- **2026-09-21** — A minimal single containment track and the win/lose check move from M3 into
  S1.5, because M1's exit criterion needs a terminal state. M3 keeps the interface and the tuning.
- **2026-09-21** — The menu-globe prototype moves from M2 to S5.7, where the main menu is built.
- **2026-09-21** — Core architecture: commands in, event outbox out, modifiers instead of special
  cases (IMPLEMENTATION §3).
- **2026-09-21** (D1.1) — **Script files are `snake_case.gd`**, not PascalCase as the plan first
  wrote them: Windows forgives a case mismatch, exports and Linux CI do not. Plan corrected.
- **2026-09-21** (D1.1) — Commands apply immediately between ticks (no queue); their events return
  in `CommandResult`, tick events in an outbox that holds the latest tick only.
- **2026-09-21** (D1.1) — **"Boxed" is mechanical:** no seeding across links until a node grants the
  `breakout` flag. D3.1 must put that flag on every Tier 1 Infiltration vector.
- **2026-09-21** (D1.1) — Discovery risk grows with time, so a silent agent is still found and no run
  can stall. A depopulated region goes **dark** for good (no hardware, no relay) — the seed of
  Autophagy, and what makes `lose_no_compute` reachable in M1.
- **2026-09-21** (D1.1) — Unit tests use a frozen copy of `balance.json` inside the fixture, so
  retuning the game never breaks a test. `data/tech/placeholder.json` (`m1_` ids, no strings)
  stands in for the trees until D3.1 replaces it.

- **2026-09-21** (D1.2) — **61 regions**, 11 of them islands reachable only by authored links; North
  Korea is the one region that starts air-gapped. China and Russia have no `network` links on
  purpose. Reasoning: `docs/specs/world.md`.
- **2026-09-21** (D1.2) — Map projection is Equal Earth with **central meridian 11° E** (edge through
  the Bering Strait). **Region anchors are authored** lon/lat, not `representative_point()`.
  Crimea is drawn with Ukraine (UN General Assembly position); Antarctica is not drawn at all.
- **2026-09-21** (D1.2) — `population_tiers` retuned to 5/30/100/300 M in `data/balance.json`; the old
  values put 27 of 61 regions in tier 3+. The test fixture keeps its frozen copy.
- **2026-09-21** (D1.2) — Pacific links are drawn across the map edge; D2.1 must specify the rule
  (world.md §5.4).

- **2026-09-21** (S0.1) — The `unsafe_*` warning family in Godot 4.7 has **four** members
  (`unsafe_property_access`, `unsafe_method_access`, `unsafe_cast`, `unsafe_call_argument`);
  `unsafe_void_declaration` is a Godot 3 name and is rejected as invalid. All four are warnings,
  `untyped_declaration` is an error, `inferred_declaration` stays off so `:=` is allowed.
- **2026-09-21** (S0.1) — `tools/map/` carries a `.gdignore`: its CSVs are Python-pipeline inputs and
  Godot was importing them as `Translation` resources. `tools/*.gd` stays visible so `-s` runs work.
- **2026-09-21** (S0.1) — `assets/map/` added to the skeleton; world.md §2 puts the ID map and the
  masks there, and PLAN §4.3's tree predates that.

- **2026-09-21** (S0.2) — **GUT 9.7.1**, vendored at `addons/gut/` from the source zip of the tag.
  The **9.7 line is the Godot 4.7 line**; GitHub's "latest release" is 9.6.1 (the 4.5/4.6 line), so
  never take `releases/latest` at face value. No prebuilt asset is published — take the zipball.
- **2026-09-21** (S0.2) — `gdscript/warnings/exclude_addons=true` is written into `project.godot`
  explicitly although it is the Godot default: it is the reason `untyped_declaration=2` does not
  reject GUT's own untyped code, and nothing in the repository should depend on an invisible default.
- **2026-09-21** (S0.2) — `.gutconfig.json` scans **`res://tests` with subdirectories**; the
  `test_` prefix keeps `tests/support/` and `tests/fixtures/` out of the run on its own. `should_exit`
  stays false in the config so the editor panel is unaffected — the wrappers pass `-gexit`.

- **2026-09-21** (S0.3) — **CI is one step: `tools/test.sh` in the `barichello/godot-ci:4.7.2`
  container.** The Docker tags have **no `-stable` suffix** (`4.7.2-stable` is a 404); PLAN §4.3
  corrected. `shell: bash` is not set anywhere because nothing is piped — a piped step would need it
  for `pipefail`.
- **2026-09-21** (S0.3) — **`--import` does not parse scripts at all**, and GUT only compiles what a
  test touches, so a parse error in an untouched file passed both. `tools/check_scripts.gd` loads
  every `.gd` outside `addons/` and runs inside `tools/test.sh`, between import and GUT. It replaces
  godot-mcp `validate_scripts` as the project-wide check in the definition of done.
- **2026-09-21** (S0.3) — Two traps that script found: a parse error does **not** make
  `ResourceLoader.load` return null (Godot hands back an empty `GDScript` on purpose) — the signal
  is an empty `get_instance_base_type()`, which an `@abstract` class and an empty file still fill in.
  And `CACHE_MODE_IGNORE` re-parses the *running* script, which corrupts it mid-run and hangs the
  process; the default cache mode is deliberate.

- **2026-09-22** (S1.1) — **Godot's JSON parser returns a float for every number**, integral ones
  included, so "expected a whole number" is a value check, never a type check. `ValidationError`
  says so at the one place it matters.
- **2026-09-22** (S1.1) — `load_from_dicts` reports its errors under `memory/balance.json` and
  friends, i.e. the label is used exactly like a root path, so a test can assert on `file` the same
  way for content from memory and from disk.
- **2026-09-22** (S1.1) — A **missing balance section reports once** (`spread: missing required
  field`), not once per field inside it; a section that is present but incomplete reports field by
  field. SCHEMA §5 tightened in the same commit where the validator was stricter than the document
  (`anomaly.spawn_chance`, the two discovery shares, N ≥ 1 regions).

- **2026-09-22** (S1.2) — **`World.check_invariants` takes an optional `ContentDB`.** The spec gives
  it no parameter, but three of its checks (anomaly count, owned nodes, the phase rule) need balance
  values or the technology list, which `World` does not own. Without a `db` those three are skipped;
  `check_invariants()` still reads as the spec writes it.
- **2026-09-22** (S1.2) — **`World.from_dict` accepts an owned node the content no longer has** and
  refuses everything else it cannot resolve. core.md §10 wants `save_content_missing` — not
  `save_corrupt` — for missing content, so **S1.8's `WorldSerializer` checks the region ids and the
  owned nodes against the content *before* it calls `from_dict`.**

## Design questions for Fable

*(Opus records here every design gap it hit while building: the question, where the placeholder is
(`# DESIGN?` in code), and what it assumed. Every Fable block answers these first.)*

- **2026-09-22 — Spectator and benchmark mode (user idea, decided in principle).** Besides the
  human game there is to be a mode in which an **AI model plays and the player watches**, and out
  of it a **benchmark**: different models are scored on how well they destroy the world, with a
  leaderboard. Named as a candidate driver: [TypeSafe](https://docs.typesafe.ai/introduction) and
  its model **Jev** — typed decisions (Choice / Score / Noul) with probabilities instead of free
  text, which fits `Policy.next_command` exactly. **No code for it exists and none is to be written
  before it is designed.** The architecture already has the hook: a model player is one more
  `Policy` (core.md §11) and the headless runners of S1.8 are the harness. **For Fable to decide at
  G1:** which milestone it belongs to; what a model is allowed to see per tick (a typed world
  digest — and how it stays deterministic and replayable); which score makes a leaderboard
  meaningful (days to Ascendance? Harm? runs survived?); whether the benchmark ships with the game
  or stays a tool; and what the content rule (outcome, never method) means for prompts a model is
  fed.

## Punch list for Opus

*(empty — reviews and gates write concrete, file-level fixes here; they become the `S<m>.P` step at
the head of the next Opus block)*

## Deviations from the plan or a spec

- **2026-09-22** (S1.4) — **`ModifierStack.CLAMPS` is `Dictionary[String, Array]`, not
  `Dictionary[String, Vector2]`** as core.md §8 writes it. `Vector2` holds 32-bit components, so the
  lower bound of `node_cost` arrives as 0.10000000149 — against §3's "floats are 64-bit". The value
  is now a `[min, max]` pair of ordinary floats.

## Known issues and carry-overs

- **godot-mcp's own helper scripts are untyped and trip `untyped_declaration=2`.** Two of the three
  were patched locally in the server installation (outside this repository, so the patch is
  machine-local and an update to godot-mcp will undo it): `scripts/validate_script.gd` was given
  static types, `scripts/mcp_interaction_server.gd` a file-level `@warning_ignore_start`.
  `validate_script(s)`, `run_project` and `game_screenshot` work again.
- **`game_eval` is unusable** until the same fix is applied to its wrapper: it builds a script
  containing `func execute():`, which the project setting rejects, and the running game drops into
  the debugger. The patch is one line in `mcp_interaction_server.gd` (annotation after
  `extends Node` in the `script_source` template, ~line 562) but writing it was refused by the
  permission classifier — **ask the user to allow it**. Until then use `game_get_property`,
  `game_set_property`, `game_call_method` and `game_get_scene_tree` instead.
- **godot-mcp `validate_scripts` takes project-relative paths only.** `res://tests/unit/x.gd` gives
  "Script does not exist"; `tests/unit/x.gd` works. The `directory` argument does not narrow the
  scope either — without an explicit `scriptPaths` list it tries all 88 scripts (GUT included) and
  refuses at the 60-file limit. Use it for one file while editing; the project-wide check is
  `tools/check_scripts.gd` (S0.3).
- **The CI container prints `ERROR: Unable to load fontconfig` ten times per run** — the godot-ci
  image ships no fonts, and headless needs none. Harmless, but it is why CI judges the run by exit
  codes and never by grepping the log for `ERROR`.
- **`tools/test.ps1` runs with `$ErrorActionPreference = "Continue"`.** Under `"Stop"` every line
  Godot writes to stderr — an engine error, or a `push_error` a test asserts on — became a
  terminating `NativeCommandError` and killed the run half-way through. Exit codes decide, not
  stderr. `tools/test.sh` was never affected.
- **PowerShell splits `-name=value` arguments** passed to a native executable, so
  `-gconfig=.gutconfig.json` reaches GUT as two tokens and is rejected. `tools/test.ps1` quotes
  them; any hand-typed GUT command in PowerShell must do the same.
- `run_project` injects `McpInteractionServer` into `project.godot` and removes it on stop, leaving
  an empty `[autoload]` section behind. Check `project.godot` before committing after a run.
  The injected `mcp_interaction_server.gd` is gitignored in case a run crashes.

## Waiting on the user

*(nothing)*

## Balance baselines

*(first entry arrives with S1.8: run length in ticks and terminal-state distribution over 200 seeds
per policy)*

Expectation from D1.1's throwaway prototype, synthetic 60-region grid, 40 seeds, placeholder tech:
`greedy` ≈ 78 % Ascendance / 22 % contained, median 750 days; `stealth` 100 % Ascendance, median
790; `idle` 100 % contained, ≈ 1500–2000. A real-world baseline far from this points to a bug or to
the world's link graph before it points to balance. Extinction is never chosen by these bots.

---

## Session log

Newest first. Five lines at most per entry: what was done, what was learned, what is next.

### 2026-09-22 — S1.5 Harm, containment, phases, outcomes [O]
`PopulationSystem`, `ContainmentSystem`, `PhaseSystem`, `OutcomeSystem`, `HistorySystem` — the seven
systems now run in the fixed order. 42 new tests, `tests/integration/test_outcomes.gd` among them:
all four recipes of core.md §9 end where they should, with the invariants checked after every tick.
**The run lengths match D1.1's Python prototype** (seeds 1–3: ascendance 387–413, extinction
414–476, no_compute 185, contained 1779–2180). Next: S1.6 on Opus.

### 2026-09-22 — S1.4 Compute economy, modifiers, purchasing [O]
`ModifierStack` completed (per-target index, activation order), `ComputeSystem` (yield, expiry,
spawning, milestones — in that order), `PurchaseNodeCommand`, `CollectAnomalyCommand`. 36 new tests,
including the step's "done when": `fx_reach` measurably shortens the way to the second continent
over 20 seeds. Learned: `Vector2` is 32-bit (see *Deviations*), and `tools/test.ps1` used to die on
any stderr Godot wrote — fixed. Next: S1.5 on Opus.

### 2026-09-22 — S1.3 Spread [O]
`SpreadSystem` (growth, then seeding, then control — in that order, so a region seeded today seeds
nobody today) and `ChooseOriginCommand`, registered in the system list and in `CommandCodec`. 21 new
tests. Learned: the phase invariant cannot hold until `PhaseSystem` exists, so S1.3's tests call
`check_invariants()` without the content. Next: S1.4 on Opus.

### 2026-09-22 — S1.2 World model, tick loop, RNG, state hash [O]
`core/model/` (`World`, `Region`, `Link`, `Agent`, `Faction`, `Anomaly`, `HistorySample`), `core/`
(`Simulation` with the fixed system order as comment slots, `SimSystem`, `SimRng`, `SimEvent`,
`Command`, `CommandResult`, `CommandCodec`) and `ModifierStack` as the shell S1.4 completes. 45 new
tests. Learned: an int is not an enum in GDScript — phase and outcome ids convert through a written
`match`, not a cast. Next: S1.3 on Opus.

### 2026-09-22 — S1.1 Content schema, loaders, validation [O]
`core/content/`: eleven classes — the five `*Def` plus `MilestoneDef`, `ContentDB`,
`ContentLoader` (JSON through `FileAccess`), `SchemaValidator`, `ContentLoadResult`,
`ValidationError`; `tests/support/fixtures.gd`; 70 tests, one per error class of core.md §4.2.
Learned: Godot's JSON parser makes **every** number a float, and `DirAccess.get_files_at` pushes an
engine error for a missing directory (which GUT counts as a failure). Next: S1.2 on Opus.

### 2026-09-21 — S0.3 Continuous integration [O]
`.github/workflows/ci.yml` (push, PR, manual; `barichello/godot-ci:4.7.2`; one step: `tools/test.sh`),
`tools/check_scripts.gd` added to both test wrappers, CI badge and a test line in the README, PLAN
§4.3 tag and IMPLEMENTATION §1.5/§2 corrected. Learned: `--import` parses no scripts, and a parse
error does not make `load()` fail — see *Decisions*. Verified: a deliberately broken script fails the
wrapper with its path and exit 1, the clean tree passes, CI green on the push. Next: S1.1 on Opus.

### 2026-09-21 — S0.2 Test framework [O]
GUT 9.7.1 vendored into `addons/gut/` and enabled as a plugin, `.gutconfig.json`, smoke test
`tests/unit/test_smoke.gd`, wrappers `tools/test.sh` (executable bit set for CI) and
`tools/test.ps1`, GUT recorded in `ASSET_LICENCES.md`. Learned: 9.7 — not GitHub's "latest" 9.6.1 —
is the 4.7 line; addons are exempt from the strict warnings; PowerShell splits `-gconfig=…`.
Verified: import 0, suite green (2/2), a deliberate failure exits 1 and was removed. Next: S0.3 on
Opus — **it needs a push, ask the user first**.

### 2026-09-21 — S0.1 Project skeleton and settings [O]
Folder skeleton (`core/`, `game/`, `ui/`, `assets/map/`, `data/world|events/`, `tests/*`) with
`.gdkeep`; `project.godot` with 1920×1080 `canvas_items`/`expand`, `untyped_declaration` as error
and the four `unsafe_*` as warnings; `.editorconfig`; placeholder `game/main.tscn`; `GODOT` in
`.claude/settings.local.json`. Learned: the strict warning setting breaks godot-mcp's own helper
scripts — see *Known issues*. Import exits 0, the placeholder runs. Next: S0.2 on Opus.

### 2026-09-21 — D1.2 World design [F]
Natural Earth 50m v5.1.1 committed under `tools/map/input/`. Authored `region_groups`,
`part_overrides`, `region_attributes`, `extra_links` (69) and `expected_land_links` (82, derived from
the geometry) in `tools/map/`, 67 strings in `data/loc/strings.csv`, spec `docs/specs/world.md`.
Checked by throwaway script: all reachable, anchors ≥ 4 px inside, every vector ≥ 9 strong regions
on ≥ 3 continents, smallest region ≈ 500 px. Next: S0.1 on Opus.

### 2026-09-21 — D1.1 Core spec and coding standard [F]
Wrote `docs/specs/core.md` (S1.1–S1.5, S1.8), `data/SCHEMA.md` v1, `data/balance.json`, the fixture
world, placeholder tech, and the coding standard in CLAUDE.md. Formulas and the four outcome recipes
were checked with a Python prototype (100 seeds each, all as specified); constants retuned once
(growth 0.04, control 0.006, containment 0.0012). No GDScript exists yet.
Next: D1.2 on Fable.

### 2026-09-21 — Planning [F]
Verified godot-mcp (Godot 4.7.2, project recognised, no scenes or scripts yet). Wrote
IMPLEMENTATION.md v0.2 (D/G steps on Fable, S steps on Opus, run sheet with clear and switch
points; M0–M5 in session-sized steps, M6–M7 outlined), this file, and CLAUDE.md.
Environment: Python 3.12 + `uv`, Node 24, `gh` present; GDAL CLI and mapshaper absent.
Next: D1.1 on Fable.
