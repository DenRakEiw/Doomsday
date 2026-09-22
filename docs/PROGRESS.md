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
| **Next step** | **S2.1 — autoloads and session driver** (first step of the M2 build) |
| **Model for it** | **Opus** — no switch |
| **After it** | `/clear` → S2.2 (Opus, no switch) |
| **Last completed** | S1.P — floats in saves are exact; the G1 punch list is empty |
| **Milestone** | M1 gated; M2 build begins |
| **Branch** | `main` |
| **One run / a batch** | `"$GODOT" --headless --path . -s tools/sim_run.gd -- --seed=1 --policy=greedy --check --replay` · `… sim_batch.gd -- --seeds=1..200 --policy=greedy --out=<csv>` |
| **Map pipeline** | `uv run --project tools/map python tools/map/build_map.py` (3 s), then `… build_world.py`, `… verify_map.py`. Environment: `uv sync --project tools/map`, wheels only, no system GDAL |
| **Test suite** | `tools/test.sh` (or `tools\test.ps1`) — import, `tools/check_scripts.gd`, GUT 9.7.1; green: 74 scripts compile, 274 tests. The same command is all of CI. |

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
- [x] S1.6 [O] Map pipeline 1: geometry *(timeboxed — done inside it)*
- [x] S1.7 [O] Map pipeline 2: attributes and links
- [x] S1.8 [O] Save/load, headless runner, bots — ⇄ **then `/model fable`**

**Block 3 — M1 gate, M2 design · Fable**
- [x] G1 + D2.1 [F] M1 gate, then the interface foundation spec — ⇄ **then `/model opus`**

**Block 4 — M2 build · Opus**
- [x] S1.P [O] Punch list from G1 — exact floats in saves
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
- **2026-09-21** (D1.2) — Pacific links are drawn across the map edge; the rule is
  ui-foundation.md §7.8 (D2.1).

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

- **2026-09-22** (S1.6) — **The masks are anti-aliased by supersampling.** Neither `rasterio` nor
  PIL draws an anti-aliased line, so both masks are drawn at twice their resolution and boxed down.
  The ID map is never touched this way — one blended pixel there is a mis-click.
- **2026-09-22** (S1.6) — **`detect_3d/compress_to=0` on all three map textures**, set in S1.6 with
  the files rather than in S1.7 as the plan had it: the Godot default is 1, and the first time a
  texture touches a 3D scene it silently re-imports VRAM-compressed and fabricates region ids along
  every border. Lossless and no mipmaps are already the defaults.
- **2026-09-22** (S1.2) — **`World.check_invariants` takes an optional `ContentDB`.** The spec gives
  it no parameter, but three of its checks (anomaly count, owned nodes, the phase rule) need balance
  values or the technology list, which `World` does not own. Without a `db` those three are skipped;
  `check_invariants()` still reads as the spec writes it.
- **2026-09-22** (S1.2) — **`World.from_dict` accepts an owned node the content no longer has** and
  refuses everything else it cannot resolve. core.md §10 wants `save_content_missing` — not
  `save_corrupt` — for missing content, so **S1.8's `WorldSerializer` checks the region ids and the
  owned nodes against the content *before* it calls `from_dict`.**

- **2026-09-22** (G1) — **`containment.base_rate` 0.0012 → 0.0025.** The M1 baseline had `greedy`
  winning 99.5 %: it buys Harm early, the research regions die, and containment capacity dies with
  them (§7.5 as designed, the rate too low). Swept 0.0012…0.0045 × Harm 0.001/0.002, 60 seeds each:
  0.0025 puts `greedy` on the knife edge (55 % contained), `stealth` wins 98 %, `idle` always
  loses. Harm stays 0.002 until G3 retunes with the real trees. (User decision, options presented.)
- **2026-09-22** (G1) — **Saves store floats as their IEEE-754 bits** (16 hex characters in a
  string); ints, ids, flags and the RNG strings stay readable. Exact regardless of content changes,
  one code path, ~20 lines in `World.to_dict`/`from_dict` and `HistorySample`. Drift (a) and
  replay-on-load (c) rejected: the first breaks hash equality after load, the second needs (a) as a
  fallback anyway. Save format v1 has not shipped, so v1 changes in place. → S1.P. (User decision.)
- **2026-09-22** (G1) — **Spectator and benchmark mode goes to M6, tool first:** a model-driven
  `Policy` over the S1.8 runners with a fixed seed set and one score, then the in-game spectator
  view. Its digest, score and prompt rules are designed after M4, when the content a model must
  see exists. IMPLEMENTATION M6 outline and §6 updated. (User decision.)
- **2026-09-22** (G1) — **"Ascendance" with 99 % dead is left as it is in the core.** The M1 bots
  reach Ascendance with 58 of 61 regions dark; requiring survivors would let a Harm-0 run stall
  (all controlled, nobody left to research). The distinction is the endings' job: **D5.2 must read
  the deaths share** and give a "ruling over ashes" ending its own text.
- **2026-09-22** (D2.1) — **The interface addresses the player informally in German (*du*).** It is
  the console of the thing the player is; the institutional *Sie* register is the world's voice and
  belongs to the headlines (D3.4).
- **2026-09-22** (D2.1) — **The five Okabe–Ito hues are reserved for M4** (factions, region states);
  M2 draws links and anomalies in the console accent `#6FE3FF` and Harm in `#FF8C6B`, not red — red
  stays "something is happening now". Tokens in `ui-foundation.md` §3.
- **2026-09-22** (D2.1) — **One logical pixel is one dp on mobile:** S2.1 sets
  `content_scale_size` from the screen dpi, so `HIT_MIN = 48` is 48 dp everywhere and the compact
  breakpoint (`width < 1100`) is a single rule. Desktop keeps the 1920×1080 base untouched.
- **2026-09-22** (S1.P) — The float codec is **`FloatBits`** (`core/save/float_bits.gd`), used by
  `World.to_dict` and `HistorySample.to_dict`; `from_dict` accepts the bit form **or** a plain
  number, and anything else in a float field is a refusal. **A state hash from before S1.P does not
  compare with one after it** — the hashed text changed. Hashes are only ever compared within one
  build anyway (IMPLEMENTATION §3).
- **2026-09-22** (S1.P) — The day loop moved into `SimHarness.advance(sim, policy, until_day, …)`
  and `play` calls it, so a test can carry a *loaded* save on with the same policy through the same
  loop the runners use. `policy_seed(seed)` is public for the same reason.
- **2026-09-22** (D2.1) — **`TICKS_PER_SECOND = 1.0` at 1×** as the starting value (a `greedy` run
  is ~6 min at 1×, 1.5 min at 4×); G3 tunes it against the 25–40 minute target.

## Design questions for Fable

*(Opus records here every design gap it hit while building: the question, where the placeholder is
(`# DESIGN?` in code), and what it assumed. Every Fable block answers these first.)*

*(none open — G1 answered both of S1.8's questions, see *Decisions*)*

**Parked for a later Fable step (not questions, reminders):**
- **Spectator / benchmark mode** — designed in M6 (decision above). What was noted at S1.8 and is
  still true: a model player is one more `Policy` (core.md §11), the S1.8 runners are the harness,
  candidate driver [TypeSafe](https://docs.typesafe.ai/introduction) / **Jev** (typed Choice /
  Score decisions). To design then: the typed per-tick digest and how it stays replayable (the
  command log already is — only new runs are non-deterministic); the score (proposal: mean over a
  fixed seed set of `max_days − days` for wins, 0 for losses); decisions every history interval
  rather than every day, to bound model calls; and the content rule for prompts (feed the game's
  own outcome-language strings, never method).
- **D5.2 endings** must distinguish Ascendance by deaths share (decision above).
- **D3.3** delivers the `"open"` token set for `ThemeBuilder` (ui-foundation.md §3.7) and the
  strings for tech tree, containment, analysis and events (§8.3).

## Punch list for Opus

*(empty — S1.P cleared the G1 list)*

## Deviations from the plan or a spec

- **2026-09-22** (S1.8) — The CI container (Linux) produced **the same state hash as the dev
  machine** (Windows) for seed 1. Pleasant, and not something to rely on: the determinism contract
  is still "same build, same platform" (IMPLEMENTATION §3). If a later run ever differs across
  platforms, that is not a regression. (The hash *value* of that run no longer reproduces — S1.P
  changed the written form of every float, and the balance changed at G1.)

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

**2026-09-22 (G1) — the real world, 61 regions, `data/tech/placeholder.json`,
`containment.base_rate = 0.0025`, 200 seeds per policy, zero rejected commands.**

| Policy | Outcomes | Days p10 / p50 / p90 | Runtime |
| --- | --- | --- | --- |
| `greedy` (origin `usa`) | 56.5 % contained, 43 % Ascendance, 0.5 % no compute | 302 / **358** / 492 | 57 s |
| `stealth` (origin `venezuela_guianas`) | 99.5 % Ascendance, 0.5 % contained | 566 / **627** / 687 | 86 s |
| `idle` | 100 % contained | 558 / **737** / 1025 | 50 s |

Before G1 (`base_rate` 0.0012, S1.8): `greedy` 99.5 % Ascendance at median 481; `stealth`
unchanged; `idle` contained at median 1170.

- **The loud player is now on a knife edge** (56 % lost): discovered around day 71 with Footprint 12
  and Harm 4, it either kills the research regions in time or is contained by day ~280. A human
  sits between `greedy` and `stealth`, which is the spread PLAN §3.7 asks for.
- **`stealth` is untouched by the change** — discovery at median day 291, and by then it holds most
  of the world. Whether that is too easy is a G3 question with the real Evasion tree.
- `idle` loses ~40 % sooner, still always. Extinction is still never reached: no bot buys Harm for
  its own sake, and the runs that kill 99 % of the world end as Ascendance (see *Decisions*).
- The bots are deterministic in strategy, so a 60-seed sweep flips from 100 % to 0 % between
  0.002 and 0.003 — the sweep values, for G3: 0.002 → greedy 100 % wins · 0.0025 → 55 % lost ·
  0.0028 → 98 % lost · 0.003 → 100 % lost, stealth 5 % lost · 0.0045 → stealth 48 % lost.

CSVs in the session scratch directory (`baseline_*.csv`) do not survive the session; the command
to regenerate them is in *Now*. The sweep script was throwaway (copies `data/` to the scratch
directory, patches `balance.json`, runs `sim_batch` with `--data=<absolute path>` — that argument
takes an OS path, which is worth knowing).

---

## Session log

Newest first. Five lines at most per entry: what was done, what was learned, what is next.

### 2026-09-22 — S1.P Exact floats in saves [O]
`core/save/float_bits.gd` (16 hex characters, big-endian, both forms readable) wired into
`World.to_dict`/`from_dict` and `HistorySample`; core.md §5.1/§10/§12 and IMPLEMENTATION §3 now say
so. **core.md §12's save property holds at last:** on the real world, `greedy`, seed 1, 200 + 100
ticks equals 200, save to text, load, 100 — by hash (`tests/integration/test_save_continue.gd`).
Checked by swapping a lossy codec in: ten integration tests go red, so the property is really
guarded. 14 new tests, suite green (274). Next: **S2.1 on Opus** — `/clear`, no model switch.

### 2026-09-22 — G1 + D2.1 M1 gate and interface foundation spec [F]
Gate: runs end for the right reasons, but `greedy` never lost — containment starved because Harm
killed the researchers first. Swept 12 settings on a scratch copy of `data/`; `containment.base_rate`
→ 0.0025 (user's choice), baselines re-recorded with 200 seeds. Decided: exact floats in saves
(S1.P), spectator/benchmark in M6 tool-first, *du* in German. Wrote `docs/specs/ui-foundation.md`
(tokens, six components, HUD in two layouts, map rules, 73 M2 strings appended to `strings.csv`).
Suite green (260). Next: **S1.P on Opus** — `/clear`, then `/model opus`.

### 2026-09-22 — S1.8 Save/load, headless runner, bots [O]
`WorldSerializer` + `LoadResult`, the three policies, `tools/sim_run.gd` / `sim_batch.gd` /
`sim_harness.gd`, and a second CI job that plays seed 1 twice with `--check --replay` and compares
the hashes — **CI green on the push, both jobs**. 32 new tests. **Found: Godot cannot read a 64-bit
float back out of JSON** — see
*Deviations*; the save format is unchanged and the question goes to G1. Baselines recorded above.
Next: **G1 + D2.1 on Fable** — `/clear`, then `/model fable`.

### 2026-09-22 — S1.7 Map pipeline 2: attributes and links [O]
`tools/map/build_world.py` joins the geometry, `region_attributes.csv`, Natural Earth's population
and `extra_links.csv` into `data/world/regions.json` and `links.json`;
`tests/integration/test_world_content.gd` checks the six points of world.md §7 for S1.7. Every
number is the spec's: 61 regions, 82 land + 69 authored links, population 7 676 945 548, eleven
island regions, `north_korea` alone air-gapped. Next: S1.8 on Opus.

### 2026-09-22 — S1.6 Map pipeline 1: geometry [O]
`tools/map/` as a `uv` project (wheels only, `uv.lock` committed); `build_map.py` runs in 3 s and
writes `id_map.png`, `land_mask.png`, `border_mask.png` and `build/geometry.json`; `verify_map.py`
checks all eight points of world.md §7 and passes. **The numbers match D1.2 exactly**: 82 land
links, override matches 1/4/1/1/3/1, smallest regions taiwan 505, sri_lanka 925, benelux 986.
Next: S1.7 on Opus.

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
