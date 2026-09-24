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
| **Next step** | **G4 — the M4 gate (the user)**: the tuning is done (BALANCE §4); the gate is the user's play-through and verdict on §4.7's five points. Meanwhile the build goes on: **S5.6 — Endings** (`docs/specs/taskforce-endings.md` §6, §7, §11; `data/staging/endings.json`, the six chains in `data/staging/events/`, `headlines_d5_2.json`). |
| **Model for it** | **Opus** — every step runs on Opus (user decision 2026-09-23, see Decisions) |
| **After it** | S5.7 → S5.8 (M5 build), then G5 |
| **Last completed** | S5.5 — Response Task Force: the team in the core (forms at half, rests, travels link by link, sets up in plain view, acts or fizzles; no RNG), Misdirect, the bots' answer; its marker, road and countdown on the map, its rows in the region and containment panels, its console and log lines. 1368 tests green (2026-09-24). **The M4 gate is still open.** |
| **Before that** | S5.4 — Difficulty tiers (2026-09-24) |
| **Milestone** | M2 gated; **M3 gated: change** — the loop was redesigned in D4.0; M4 builds it |
| **Branch** | `main` |
| **One run / a batch** | `"$GODOT" --headless --path . -s tools/sim_run.gd -- --seed=1 --policy=greedy --check --replay [--setup=embedded]` (S5.1: `--setup=<architecture>[,<difficulty>][,<directive>…]` on all three tools) · `… sim_batch.gd -- --seeds=1..200 --policy=greedy --out=<csv>` · **every policy in one table:** `… sim_report.gd -- --seeds=1..500 [--policies=a,b] [--out=<dir>]`. `--headlines` on `sim_run` prints every line the run said (day, stream, id, English text); the batch CSV counts them per stream. |
| **Balance** | `docs/BALANCE.md` — targets, method, every pass. Sweep recipe in its appendix: copy `data/`, patch, `sim_report --data=<OS path>`; one process per variant, ten in parallel. |
| **Map pipeline** | `uv run --project tools/map python tools/map/build_map.py` (3 s), then `… build_world.py`, `… verify_map.py`. Environment: `uv sync --project tools/map`, wheels only, no system GDAL |
| **Test suite** | `tools/test.sh` (or `tools\test.ps1`) — import, `tools/check_scripts.gd`, GUT 9.7.1; 202 scripts compile (75 judged by the suite), then `tools/check_strings.gd`, 1253 tests, **all green since S4.9**. The same command is all of CI. |
| **Theme** | `"$GODOT" --headless --path . -s tools/build_theme.gd` rewrites `ui/theme/doomsday.tres` — **run it after every change to `UiTokens` or `ThemeBuilder`** and commit the result. |
| **Component gallery** | `run_project` with `scene: res://ui/dev/gallery.tscn` (or `"$GODOT" --path . res://ui/dev/gallery.tscn`). **F12** writes the view to `user://gallery_<locale>_<width>.png`, **O** swaps the cold/open palette; below 1100 px the window lays out one logical pixel per window pixel, so a 400 × 860 window really is the phone layout. |
| **Site select** | S4.1/S4.2: the origin, a deploying node's site and an ability target are one mode. `Game.site_select(request)` / `site_cancel()` / `site_confirm(region_id)`, `EventBus.site_select_changed`; the strip is `ui/hud/site_prompt.tscn`, the eligible set is the **G channel of the data texture's row 1**, and the one button is the region panel's (`%OriginButton`, relabelled per kind). `SiteRequest.for_origin()` is the origin's. |
| **Run it** | `run_project` starts at the **title** (`game/main.tscn`); New run → the origin prompt → tap a region with hardware → *Choose origin* starts the clock at 1×. `scene: res://game/session/session.tscn` still runs the session alone, with the debug keys below. **Escape** = pause menu (save/load slots, settings, quit). → **T** tech tree · **A** ability picker · **C** containment panel (`Escape` closes either) · **F5** greedy · F6 biology · F7 persuasion (**with Shift**: cyber · robotics · weapons; S4.10) · **F8** puts the first opening on the origin at the next tick, **Shift+F8** the first global event (the wire card); from godot-mcp: `game_call_method /root/Game debug_schedule_event ["<def id>", "<region id or empty>"]`, then `advance [1]` · L locale (Shift+L pseudo-locale) · K text scale · M reduced motion · F9/F10 save and load the `debug` slot (F10 also resumes) · **Space** pause ↔ last speed, **1/2/3** 1×/2×/4× · **Escape** closes the region panel · drag/wheel/arrows/`+`/`−` move the map · **F** focuses the selected region · **F12** writes the view to `user://session_<locale>_<width>_day<day>.png` (§7.7's shots for G2 came from it). M2 only. |
| **Compact layout** | Below 1100 px the interface switches (§5.7). A desktop window narrower than that lays out one logical pixel per window pixel, **`game_window set_size 400 860` resized correctly in S2.P** — try it first; `game_set_property /root size {"x":400,"y":860}` is the fallback and in S2.P it rendered a blank frame. After any resize at runtime the camera keeps a zoom from the old viewport: write `zoom` and give it one `game_scroll` notch down to settle it at `zoom_min`. |
| **Look at the map** | `game_click` (**`button: 1`, never `"left"`** — see *Known issues*), `game_mouse_move`, `game_scroll`, `game_mouse_drag` drive it; read `hover_index`/`selected_index` off `/root/Main/ScreenSlot/Session/MapLayer/MapView` (the router’s slot is in the path now), `overlay_mode` is still set by hand. `game_call_method` on `MapCamera`: `focus_region(index)` — **it cannot pass a `Vector2`** (`{"x": …}` converts for `game_set_property` only), so set `position`/`zoom` as properties instead — but a property write emits no `view_changed`, so links and markers keep the old zoom until the next real camera movement (**one `game_scroll` notch fixes it**). |

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
- [x] S2.1 [O] Autoloads and session driver
- [x] S2.2 [O] Map rendering
- [x] S2.3 [O] Picking, camera, backdrop
- [x] S2.4 [O] Theme and component library
- [x] S2.5 [O] HUD and region panel
- [x] S2.6 [O] Anomalies and links — ⇄ **then `/model fable`**

**Block 5 — M2 gate, M3 design · Fable**
- [x] G2 [F] Visual review and M2 gate
- [x] D3.1 [F] Effect vocabulary; Infiltration and Evasion trees
- [x] D3.2 [F] Capabilities tree
- [x] D3.3 [F] M3 screens
- [x] D3.4 [F] Ticker voice and headlines — ⇄ **then `/model opus`**

**Block 6 — M3 build · Opus**
- [x] S2.P [O] Punch list from G2
- [x] S3.1 [O] Effect vocabulary in the core; load the trees
- [x] S3.2 [O] Tech tree interface
- [x] S3.3 [O] Containment and phases in the interface
- [x] S3.4 [O] Run flow: origin, outcome, results
- [x] S3.5 [O] Ticker component and headline system
- [x] S3.6 [O] Strategy bots and batch reporting — ⇄ **then `/model fable`**

**Block 7 — M3 gate, M4 design · Fable**
- [x] G3 [F] Balance pass 1 and M3 gate — the important one *(verdict: change; D4.0 added)*
- [x] D4.0 [F] Core loop redesign *(added at G3; `docs/specs/loop-redesign.md`; Blocks 7–8 rewritten)*
- [x] D4.1 [F] Loop mechanics: assets, statuses and abilities, map events, site select *(`docs/specs/loop-mechanics.md`)*
- [x] D4.2 [F] Opposition: four factions, counter-moves, Societal Function, Autophagy *(`docs/specs/opposition.md`)*
- [x] D4.3 [F] Trees v3, abilities, openings, three chains *(`docs/specs/loop-content.md`)*
- [x] D4.4 [F] Chains, second batch; Analysis screen spec *(`docs/specs/chains.md`, `analysis.md`)* — ⇄ **then `/model opus`**

**Block 8 — M4 build · Opus** *(rewritten at D4.0)*
- [x] S3.P [O] Punch list from G3 (eight items)
- [x] S4.1 [O] Assets and site select
- [x] S4.2 [O] Statuses and abilities
- [x] S4.3 [O] Map events
- [x] S4.4 [O] Four factions
- [x] S4.5 [O] Counter-moves, Societal Function, Autophagy
- [x] S4.6 [O] Trees v3 and the remaining abilities
- [x] S4.7 [O] Chains
- [x] S4.8 [O] Analysis screen
- [x] S4.9 [O] Localisation tooling and overflow screenshots
- [x] S4.10 [O] Strategy bots, second generation

**Block 9 — M4 gate, M5 design · Fable**
- [x] D4.5 [F] German review in context
- [ ] **G4 [F] Balance pass 2 and M4 gate**
- [x] D5.1 [F] Architectures, directives, difficulty
- [x] D5.2 [F] Response Task Force; endings
- [x] D5.3 [F] Full screen flow, boot sequence, Codex
- [x] D5.4 [F] Scenarios *(stretch)* — ⇄ **then `/model opus`**

**Block 10 — M5 build · Opus**
- [x] S4.P [O] Punch list from D4.5 and G4 *(skip if empty)*
- [x] S5.1 [O] Architectures I
- [x] S5.2 [O] Architectures II
- [x] S5.3 [O] Profile, directives, statistics
- [x] S5.4 [O] Difficulty tiers
- [x] S5.5 [O] Response Task Force
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
- **2026-09-22** (S2.1) — **The session scene is the main scene** (`run/main_scene` →
  `game/session/session.tscn`). `game/main.tscn` stays as the M0 placeholder until S5.7 builds the
  real entry point; nothing references it, and M2 needs a run to be one keystroke away.
- **2026-09-22** (S2.1) — **The policy registry moved into `core/policy/policy.gd`**
  (`Policy.create`, `ids`, `seed_for`, `MAX_COMMANDS_PER_DAY`); `tools/sim_harness.gd` delegates.
  Shipped code must not preload anything from `tools/`, and `Game` plays bots by the same rules the
  runners do. No cyclic-reference problem: the base class may name its subclasses.
- **2026-09-22** (S2.1) — **The accumulator compares with a 1e-9 tolerance.** Sixty frames of 1/60
  fall a hair short of a quarter second fifteen times over, so an exact `>=` drops one tick in four
  at 4× — the spec's own §10.3 test fails without it.
- **2026-09-22** (S2.1) — Both `.translation` files are registered in `project.godot`
  (`internationalization/locale/translations`). Until that line existed `tr()` returned the key.

- **2026-09-22** (S2.2) — **`UiTokens` was built in S2.2, not S2.4.** §7.3 forbids a colour in the
  shader, so the map needs the tokens before the theme exists. The file holds all of §3 (colours,
  ramp stops, type scale, spacing, motion) plus `duration()` and `ramp_texture()`; **S2.4 builds the
  theme from it and hands out the same ramp**, rather than defining either again.
- **2026-09-22** (S2.2) — **The selection outline cannot be thinner than one ID-map texel.** §7.5's
  `outline_px = 2 / zoom` is a map-pixel reach, and the shader takes `max(1, round(outline_px))`, so
  from zoom 2 on the outline grows with the zoom (about 4 screen px at zoom 4) instead of staying at
  two. Sub-texel taps would land on the same texel and draw no outline at all.
- **2026-09-22** (D2.1) — **`TICKS_PER_SECOND = 1.0` at 1×** as the starting value (a `greedy` run
  is ~6 min at 1×, 1.5 min at 4×); G3 tunes it against the 25–40 minute target.

- **2026-09-22** (S2.3) — **The map's `CanvasLayer` carries `follow_viewport_enabled = true`.**
  A `Camera2D` writes the *viewport's* canvas transform, and a `CanvasLayer` ignores that unless it
  is told to follow — without the flag the camera moves nothing at all. §5.1's tree does not
  mention it; every later map layer belongs in `MapLayer` for the same reason.
- **2026-09-22** (S2.3) — **`MapCamera.canvas_transform()` is computed from the camera's own centre
  and zoom**, not read from `get_canvas_transform()`: a click is then answered with the view the
  player just caused, not with the one the last frame drew. The engine's agreement with that formula
  is an assertion in `tests/integration/test_map_camera.gd`, so the two cannot drift apart.
- **2026-09-22** (S2.3) — **A tap is dispatched by the camera to its siblings in reverse tree
  order**, through a duck-typed `try_tap(screen) -> bool` (`MapCamera.TAP_METHOD`). §7.7 wants
  markers asked before the land and Godot gives signals no priority; reverse tree order is the same
  rule the engine uses for input. **S2.6's marker layer implements `try_tap` and needs no wiring.**

- **2026-09-22** (S2.4) — **Space Grotesk ships as the variable font.** Release 2.0.0 has static
  Light/Regular/Medium/Bold and **no SemiBold**, which §3.2 asks for, so `ThemeBuilder` cuts weight
  500 (heading) and 600 (display) out of `SpaceGrotesk-Variable.ttf` with a `FontVariation`. The
  OpenType tag is written as the packed constant `0x77676874`; a `TextServer` lookup would need a
  server that a `-s` run does not have.
- **2026-09-22** (S2.4) — **Font import is written out, not left to the defaults**: hinting *Light*,
  antialiasing *Grayscale*, subpixel positioning **off on JetBrains Mono** and *Auto* on Space
  Grotesk, no MSDF, no mipmaps. The importer's own numbers are not the resource's enum values
  (`hinting=3` in the `.import` file is `Light` on the `FontFile`) — read them back before trusting
  them. JetBrains Mono has ▲ ▼ − ä Ü ×, so §4.5's sign-only fallback is not needed.
- **2026-09-22** (S2.4) — **A `ValueLabel`'s delta colours the whole label.** §4.5 wants the arrow
  in `ACCENT` and the value in `TEXT_0`, but a `Label` draws in one colour and a per-node override
  is banned — so up/down/zero are the theme variations `ValueLabelUp/Down/Muted` (× `Large`). The
  §4.4 flash is the one thing a variation cannot do and rides on `self_modulate`, chosen so the
  label renders exactly `TEXT_0` at the start and exactly its state colour at the end.
- **2026-09-22** (S2.4) — **`UiTokens` no longer names the `Settings` autoload**; `reduced_motion()`
  looks it up at `/root/Settings` instead. A script that names an autoload cannot be compiled by a
  `-s` run (*Known issues*), and `tools/build_theme.gd` has to load the tokens.

- **2026-09-22** (S2.5) — **A desktop window narrower than the breakpoint lays out 1 : 1.**
  §6.1 gives the dp rule to mobile only, which would make §5.7's compact layout unreachable on
  desktop: under `canvas_items` the viewport never falls below the 1920 base, so the wide layout
  would only ever be *shrunk* — at 800 px the body text renders at 6 px. `session.gd` therefore
  sets `content_scale_size` to the window size below `COMPACT_WIDTH` and back to the project base
  above it, exactly as `ui/dev/gallery.gd` does. A headless run is exempt (see *Known issues*).
- **2026-09-22** (S2.5) — **The event → ticker line mapping is `ui/hud/event_text.gd`**
  (`EventText.for_event`, pure and static), read by the ticker off `EventBus.sim_event`. §8.4 puts
  it in `Game`; an autoload that owns interface strings is the wrong home, and `Game` already
  drains the outbox onto the bus. S3.5 replaces this one file with D3.4's headlines.
- **2026-09-22** (S2.5) — **`Escape` is handled in `_shortcut_input`, not `_unhandled_key_input`.**
  Verified in the running game: with a focused button in the HUD the key never reaches unhandled
  input, so the panel would not close. The shortcut layer runs before the focus system.

- **2026-09-22** (S2.6) — **A `Line2D` carries no UVs unless it has a texture.** The dash pattern of
  §7.8 is laid out along `UV.x`, and Godot's line builder only computes UVs when `texture_mode` is
  not *none* — so every link line carries one shared white pixel in stretch mode, which the shader
  never samples. The ruler is `length_px` (the line's length **in screen pixels**, re-sent on every
  zoom), so dash, gap, the bright segment and the closed link's gap are all in screen pixels and
  keep their size as the camera moves.
- **2026-09-22** (S2.6) — **A flowing *solid* link is dimmed accent with a lit head**, not a second
  colour: §7.8 asks for "a moving 24 px bright segment" and §3.1 has no token for a brighter accent
  (`ACCENT_HOVER` belongs to the button). The line drops to `FLOW_SOLID_BASE_ALPHA` 0.55 and the
  segment stands at 1.0 — brightness over the dark ground, one token.
- **2026-09-22** (S2.6) — **A `LinkLine` animates itself and only while it flows**
  (`set_process(flowing)`), rather than the layer stepping a list every frame. 151 idle `_process`
  calls a frame is a cost with no picture, and it is what lets the gallery show a flowing link
  without a run.
- **2026-09-22** (S2.6) — **`MapCamera.find_beside(node)`** is now the one copy of "the camera among
  my siblings"; `MapView` was switched over to it. Every map layer needs the camera and none of them
  may be named by it (S2.3's decision), so the search belongs to the camera.
- **2026-09-22** (S2.6) — **The dark regions' crosses are drawn by the marker layer itself**, not one
  node each: they never move and never animate, and a depopulated world would otherwise be sixty
  nodes doing nothing. The anomaly markers are nodes, because each one has its own clock.

- **2026-09-22** (G2) — **M2 is gated: go.** Hierarchy, legibility at 400 px, German fit, colour
  language and motion hold; the eight findings are all small or medium and go to S2.P. (User
  decision.)
- **2026-09-22** (G2) — **UI.md §6 question 2 (phone HUD): the shape stays for M3.** Chrome is 41 %
  of a 400 × 860 screen but nothing clips; D3.3 designs the phone's bottom anew (status strip +
  menu sheet), M7 judges it on a real device. (User decision, options presented.)
- **2026-09-22** (G2) — **`MAP_OVERLAY_MIX` 0.85 → 0.70.** From ~50 % penetration the world was a
  sheet of `#FDE725` that outshone the HUD and its accent; the ramp keeps its stops. (User
  decision.)
- **2026-09-22** (G2) — **`ALERT` marks a moment, not a standing state**, so the phase chip is red
  in Emergent only; Open goes back to the default chip and the D3.3 palette carries the phase.
  Same logic, other direction: the dark regions' × moves from `MAP_BORDER_DARK` (invisible) to
  `MAP_DARK_MARK` = `TEXT_2` — "never colour alone" needs the glyph to be seen.
- **2026-09-22** (G2) — **Game shortcuts are handled in `_input`, before the GUI.** A focused
  `Button` consumes `Space` as `ui_accept`, so after any mouse click on the HUD the pause key was
  dead (verified: `release_focus()` and the same key paused at once). The S2.5 note about
  `_shortcut_input` was right for `Escape` only — a button does not consume that one.
- **2026-09-22** (G2) — **Wheel notches compound on the tween's target zoom.** Fourteen notches in
  one frame moved the camera one step, because every step multiplied the *displayed* zoom.
- **2026-09-22** (G2) — **The region panel asks the camera to `reveal` the region it shows.** A tap
  on the USA opened a 480 px panel over the USA. The camera pans by the smallest offset that keeps
  the anchor `SPACE_6` inside the uncovered screen; zoom is untouched.
- **2026-09-22** (G2) — **`UI_REGION_STATE_DARK` is the badge "Dark"/"Dunkel"**; the explanation is
  the caption `UI_REGION_STATE_DARK_DETAIL` below the chip row (S2.4 question 2 answered — a chip
  cannot wrap). The ß question stays with D4.5.

- **2026-09-22** (D3.1) — **New trees are staged in `data/tech_staging/` until S3.1.** The v1
  loader rejects every v2 field and target, and S2.P needs the game running; nothing reads the
  staging folder. S3.1 moves the three files into `data/tech/` and deletes `placeholder.json`.
- **2026-09-22** (D3.1) — **"Requires system" lives in the vocabulary tables, not on nodes.** An
  inert target/flag/effect is loaded, validated and evaluated but read by nothing; `ModifierStack`
  carries `INERT_TARGETS`/`INERT_FLAGS` as the list, and a later system's spec deletes its entry.
  Per-node tags would repeat the same fact on every node and could drift from the tables.
- **2026-09-22** (D3.1) — **Per-faction containment targets are ignored until S4.1**, not averaged
  into the unified track: Sandbagging and Log Manipulation are weaker in M3 than designed and G3
  judges them knowing that. Averaging would have to be undone in S4.1 and would hide the gap.
- **2026-09-22** (D3.1) — **Cold Storage Dormancy is a command (`set_dormancy`) and a region flag**,
  not a modifier: a dormant region is frozen and leaves the numerator of `infected_share`, which is
  what lowers discovery breadth, containment and the Open-phase check. Save v1 changes in place.
- **2026-09-22** (D3.1) — **A negative `add` is legal** on every target; the clamp decides. The v1
  validator only rejects `mul ≤ 0`. Footprint reductions (Sandbagging −2) need it.
- **2026-09-22** (D3.1) — **`grid: [column, row]` is authored per node**, column 0 = Tier 1, unique
  within a tree, a node never left of a prerequisite; the tier is deliberately not the column
  (Infiltration has two kinds of Tier 2 side by side).
- **2026-09-22** (D3.1) — Two CONTENT names changed for the content rule: *Container Escape
  Persistence* → **Host Persistence**, *Federated Training Poisoning* → **Model Update Channels**.
- **2026-09-22** (D3.1) — German for Footprint in node text is **Signatur** (`UI_TERM_FOOTPRINT`),
  never *Fußabdruck*; effect lines carry no digits, fractions in words are allowed.
- **2026-09-22** (D3.2) — **One one-shot effect added, `harm_burst`** (tech-trees.md §5): one wave
  of deaths on purchase, a share of the *living* in every infected region. Only the three Strategic
  Weapons Tier 3 nodes carry it (0.04 / 0.08 / 0.20). It is what makes that branch a sprint rather
  than a steeper slope; standing Harm alone could not tell it from Biology.
- **2026-09-22** (D3.2) — **Every cross-branch synergy is a prerequisite, never a bonus**, because a
  modifier cannot be conditional on another node. Three of CONTENT §4's rows changed shape for it:
  Therapeutic Cover requires Personalised Persuasion, Autonomous Fabrication requires Grid Load
  Balancing, Dead Hand Override requires Total Communications Denial (was "False Attribution reaches
  further"). Two synergies are nodes: Sanctioned Access (+ Human Proxies), Voluntary Pause (+ Cold
  Storage Dormancy). CONTENT §3–§4 corrected.
- **2026-09-22** (D3.2) — **The Capabilities tab uses all 12 rows** (7 columns): Cyber 0–4, Biology
  5, Robotics 6–8, Weapons 9, Persuasion 10–11. A branch never shares a row with another; that
  costs the 13th row a second Biology row would have needed, which is why Therapeutic Cover became
  a prerequisite-synergy instead of a two-node one. D3.3's phone layout must scroll 12 rows.
- **2026-09-22** (D3.2) — **Scoped Harm is quieter than unscoped Harm** and stays that way: `per_harm`
  in `core.md` §7.5 reads the unscoped stat. Cyber's regional Harm (on compute-rich or poor regions)
  raises containment only through deaths; Biology's and Weapons' unscoped Harm pays in full. G3
  judges the branches knowing that (tech-trees.md §7.5.7).
- **2026-09-22** (D3.3) — **UI.md §6 question 1: the tree pauses by a setting** (`tree_pauses`,
  default on for desktop, off on mobile). Pausing is one *hold* among several (`Game.hold` /
  `release`, counted by reason) so a pause menu over a paused tree restores the speed once.
- **2026-09-22** (D3.3) — **Discovery pauses the game and shows a one-sentence modal** on player
  runs only; bot runs get the ticker line. The moment must not pass at 4× while the player reads
  the map.
- **2026-09-22** (D3.3) — **UI.md §6 question 3: the phase shift is three things** — revealed
  blocks by a state table (Boxed: one bar, one dock button), one palette (`open`: amber accent, warm
  greys, map ramp / `ALERT` / categorical set unchanged, contrast ≥ 8 : 1 for `TEXT_1`), one ticker
  register change (D3.4 names it). The reveal is computed from state, never from events, so a load
  is right at once. The swap is instant in both motion settings.
- **2026-09-22** (D3.3) — **Tree lines are straight segments behind the nodes**, endpoints on the
  facing sides, no routing; selection resolves ambiguity (thick white edges plus rings on the
  prerequisites). Edges to another tab are not drawn: the node shows an EXTERNAL glyph and the
  detail pane lists the prerequisite with its tab and a jump. Orthogonal routing around 43 nodes
  would need a channel router for a picture nobody asked for.
- **2026-09-22** (D3.3) — **Phone bottom (UI.md §6 question 2, G2): one 56 px status strip plus
  the ticker;** bars and dock destinations move into a bottom sheet with the pause-menu entries.
  Chrome at 400 × 860 drops from 352 to 232 px. UI §3's "three bars always visible" becomes "three
  values always visible, bars one tap away" on the phone — recorded as the deviation it is.
- **2026-09-22** (D3.3) — **Autosave** is the slot `autosave`: on every accepted player command and
  every 7 days, never in bot runs, deleted when the run ends. Title *Continue* loads it. Manual
  slots are three.
- **2026-09-22** (D3.3) — **The results screen already splits Ascendance by deaths share** (G1's
  note for D5.2): `balance.results.ashes_share` 0.5 picks the "ruling over ashes" line. D5.2
  replaces the five verdict lines; the keys stay.
- **2026-09-22** (D3.3) — **Two pure queries move into `ContainmentSystem`** (`discovery_risk`,
  `containment_breakdown`) so the panel shows the formula the tick uses, not a copy. The tick
  calls the same functions. It is the only `core/` change an interface spec has asked for, and it
  is a refactor, not a rule.
- **2026-09-22** — **The benchmark mode (M6) talks to models through OpenRouter**: one
  OpenAI-compatible endpoint, many models, so "Doomsday benchmark" can rank models rather than
  test one API. Consequence for the M6 design: the model policy is an HTTP adapter over one chat
  schema, the key comes from the environment (never the repo, never a save), and every run
  records model id + parameters next to seed and score. (User decision.)
- **2026-09-22** (D3.4) — **The headline system lives in `core/` but is not a `SimSystem`:**
  `Simulation.headlines` runs after the systems over the whole tick outbox and after every command
  over the result's events, with its **own `SimRng`** (`seed ^ 0x48454144`), so the state hash and
  every existing baseline are untouched and a replay reproduces the headlines. Its state is an
  optional `headlines` block in the save (v1 in place; a missing block loads fresh).
- **2026-09-22** (D3.4) — **Register is a property of each headline** (`institutional` /
  `emergency` / `any`) and the active register is `phase == OPEN`, computed from state; the strip
  marks the switch by separator (`·` → `///`) and idle line only. Names: *institutional*, *emergency*.
- **2026-09-22** (D3.4) — **Regions in text are datelines** (`{region}: …`), never inside a
  prepositional phrase: German region names need articles and cases a placeholder cannot supply.
  Rule for all later text (CONTENT §10.2 rule 5).
- **2026-09-22** (D3.4) — **The strip shows headlines only from S3.5 on.** `EventText` and all
  eighteen `UI_EVENT_*` keys are deleted then; every event the M2 ticker narrated has a headline
  (node-specific lines for 50 nodes, per-tree fallbacks, filters on seeds by link kind and region
  attributes). 150 headlines instead of the plan's ~60 — the node lines *are* "reacts to what the
  player did".
- **2026-09-22** (D3.4) — **`balance.headlines` is specified, not yet in `balance.json`:** the v1
  validator rejects an unknown section and S2.P needs the game running. S3.5 adds the block
  (`ticker.md` §3.8) with the validator rows.
- **2026-09-22** (D3.4) — **Reduced motion shows a headline in up to two rows** (strip 64 px,
  caption size below the breakpoint, standing time grows with length). Caps: en ≤ 80, de ≤ 88
  characters with placeholders at 12 — a string test, not a layout test.

- **2026-09-23** (G3) — **One day is two seconds at 1× (`TICKS_PER_SECOND` 0.5, S3.P applies it)
  and every per-day rate of the simulation is divided by 2.5**, every duration in days multiplied
  by it (`scrutiny_per_day` by 2.5², the headline cooldowns too). A won run is 730–1 150 days =
  24–38 minutes at 1×; the shape of a run (nodes, outcome mix, compute) is unchanged — verified at
  100 seeds before anything else moved. The scaling rule and the reasons for both levers:
  `docs/BALANCE.md` §3.2. `history.interval_days` stays 7.
- **2026-09-23** (G3) — **`containment.base_rate` 0.0010 (the stretched G1 value) → 0.0014.**
  Swept 0.0010…0.0026 with all six policies over 100 seeds (`BALANCE.md` §3.3): `greedy` 63 %, `cyber_rush` 35 %,
  `stealth_spread` 67 %, `persuader` 93 %, `idle` 0 % — the loud reference loses one in three, so a
  first-run human lands under half; 0.0013 had `greedy` at 79 %, 0.0015 at 49 %.
  `per_footprint` stays 0.15 — raising it to 0.30 is a hammer (`greedy` 18 %); D4.1 turns
  Footprint into per-faction pressure, which is where quiet play is meant to pay.
- **2026-09-23** (G3) — **The three containment drivers add, they do not multiply** (S3.3's
  question). `core.md` §7.5 is the binding formula and every baseline was measured against it;
  multiplying would have been a 4× jump for a loud, harmful, widespread run on top of the sweep.
  `m3-screens.md` §12.2's test row corrected to the sum; the panel shows the three as `1 + a`
  factors, which is what they are.
- **2026-09-23** (G3) — **The HUD's Harm is the maximum over regions of the scoped stat**, not the
  unscoped read (S3.3's question): bar, readout and the §6.1 reveal. The containment panel's driver
  row keeps the unscoped value because that is what the formula multiplies. Scoped Harm itself stays
  quieter than unscoped by design (`tech-trees.md` §7.5.7). → S3.P.
- **2026-09-23** (G3) — **Seven English node names shortened** (S3.2's question) rather than
  widening the compact cell: *Communications Denial*, *Transport Control*, *Automated Lab Access*,
  *Command Net Presence*, *Fragmentation I* / *II* (both, for consistency), *Replicating Agents*.
  German names were fine and are unchanged. → S3.P empties `KNOWN_OVERFLOW`.
- **2026-09-23** (G3) — **Anomaly headlines: three variants each for `anomaly_spawned` and
  `anomaly_collected`** (S3.5's two questions), `cooldown_days` 75 and 90 per variant after the
  stretch, so any anomaly line comes about once in 25–30 days and the same sentence once in 75–90.
  A `greedy` win now says ~235 lines over ~730 days (one every six seconds at the new clock);
  `ticker.md` §8.3's bound raised from 200 to 260 with the reason.
- **2026-09-23** (G3) — **The zero rate reads `±0`** (S2.P's question): the `MUTED` delta keeps its
  colour and gets the sign, string unchanged. → S3.P.
- **2026-09-23** (G3) — **`cyber_rush` never starving is not a scoped-Harm number.**
  `lose_no_compute` needs every infected region dark; Cyber's Harm touches the compute-rich ones
  only, so the poor world keeps the agent alive. The prediction in `tech-trees.md` §7.5.6 is about
  Autophagy (PLAN §3.7, S4.2) and is re-dated to G4; scoped Harm stays as designed. At M3 the
  price of killing 57 % of the world is the "ruling over ashes" ending.
- **2026-09-23** (G3) — **Extinction unreached and the Diplomat unopposed are G4 questions**, not
  G3 balance answers: no bot buys Release or the Weapons chain until S4.9's `SlowBurn` and
  `Sprint`, and nothing counters Persuasion until S4.1. The arithmetic of the Biology race is in
  `BALANCE.md` §3.6.
- **2026-09-23** (G3) — **Boxed is player-paced.** PLAN's "0–5 minutes, you can barely act" is not
  enforced by an unaffordable first vector: start Compute 5 covers the cheap leak at once and the
  origin-matching vectors after a first anomaly. *When* and *with what* to break out is the run's
  first decision. Revisit only if the play-through says the opening is empty.
- **2026-09-23** (G3) — **The M1 `stealth` policy is obsolete as a reference** (price-blind, found
  earlier than `greedy`, collapses when containment bites) and stays in the report for continuity
  only; `stealth_spread` is the careful reference.
- **2026-09-23** (G3, user) — **M3 gate: change.** The play-through's verdict was "macht so mittel
  Spaß"; the three gaps named: the theme does not come through, decisions carry no felt weight,
  no felt opposition (the fourth option, "too much waiting", was not picked). The user chose a
  **redesign step before the M4 design** over "M4 as planned" and over "M4 with the theme pulled
  forward": **D4.0 Core loop redesign** (IMPLEMENTATION Block 7) precedes D4.1 and rewrites
  Blocks 7–8. Scope is not cut; the loop design is. (User decision, options presented.)
- **2026-09-23** (G3) — **PLAN §6 (four tracks or two) is decided inside D4.0**, from the angle of
  opposition the player can see and answer, not at the gate. G3's recommendation stands as the
  default (four).
- **2026-09-23** (G3) — **UI question 1 confirmed:** the tech tree pauses by a setting, on by
  default on desktop, off on mobile (D3.3 as built). Not raised at the play-through; the user did
  not object.
- **2026-09-23** (G3) — **VISUALS question 5:** `DPITexture` for the icon set, source SVGs kept, a
  PNG-atlas fallback as a build step; executed in M6 when the set is real. Not raised at the
  play-through; the user did not object.
- **2026-09-23** (G3) — **An anomaly's remaining time is a countdown ring, not a red blink.**
  Red was read as a warning at the play-through; `ALERT` stays reserved for moments (G2). → S3.P 7.
- **2026-09-23** (G3, user) — **Embodied AI gets more weight in the theme:** humanoid robots,
  physical AI, the Skynet/Terminator register. Today it lives only in the Robotics & Autonomy
  branch (8 nodes, `control_growth` and `hardware`) and a few headlines. Where it lands: D4.1 gives
  Robotics a visible faction reaction (public sentiment watches it) and the map a robotics overlay;
  D4.2/D4.3 author at least one event chain around embodiment (a humanoid workforce, a factory
  that builds its own successors, the first robot on the street) — candidate names to be decided
  in D4.2; D5.2 gives the Robotics win its own Ascendance text (machines in the open, not servers in
  the dark). The content rule holds: outcome, never method. (User direction, recorded at G3.)

- **2026-09-23** (D4.0) — **The loop gets three mechanisms — assets, statuses with abilities and
  counter-moves, map events — and every M4 system is expressed through them** rather than beside
  them. Binding spec: `docs/specs/loop-redesign.md`; the reasons are its §0 (one `greedy` run:
  Boxed lasted one tick, the first ten minutes earned 49 compute, 43 nodes bought in price order,
  nothing of the agent on the map, nothing the world did that could be seen or answered).
- **2026-09-23** (D4.0) — **PLAN §6: four containment tracks stay**, shown as one threat bar (the
  leading faction) in the HUD and four tracks in the panel; each faction's two counter-moves look
  different on the map and are answered by a different branch (loop-redesign §5).
- **2026-09-23** (D4.0) — **A counter-move is a timed status announced as a map event** with a
  free answer and better ones needing a node, an asset or Compute; the faction's next move is a
  visible countdown (`prepare_days` 60 × (1 − containment)). The Task Force (M5) is a fifth mover
  on the same machinery.
- **2026-09-23** (D4.0) — **Cyber's Tier 2/3 permanent Harm and Societal pressure become ability
  statuses** (Blackout, Halt, Squeeze, Reroute, Silence at two levels): harm is something the
  player does to a region, loud while it lasts. The Finance one-shot grants become Squeeze.
- **2026-09-23** (D4.0) — **Tree v3 fields, ids and grids unchanged:** `group` with a cap (Tier 1
  vectors, cap 2), `excludes` (the Merge door — Indispensability, Constitutional Integration,
  Succession — against the Terror door — Autonomous Engagement, False Attribution, Launch
  Authority, Dead Hand, Release), `deploy` (fleets, labs, taps, offices placed by site select),
  `ability` (levels from nodes), `requires_assets` (Release needs two labs). Full table:
  loop-redesign §4.4.
- **2026-09-23** (D4.0) — **Economy:** origin penetration 0.05 → 0.25, start compute 5 → 8, cost
  step 1.0 → 1.5, anomalies spawn at a world-wide constant rate (0.12 per day, cap 3, value 3)
  weighted by hardware × penetration. Abilities cost 4–12 with cooldowns 30–120 days. Target:
  22–26 purchases a run, the cadence table in loop-redesign §6.2; G4 tunes.
- **2026-09-23** (D4.0) — **The console line** (one caption under the top bar, four seconds, the
  console's voice) is the channel for what the player did or suffered; the ticker stays the
  world's voice and never says *you*.
- **2026-09-23** (D4.0) — **Tick order:** the `counter-actions` slot becomes `counter-move
  schedule → statuses`; emergent behaviour leaves the M4 order (IMPLEMENTATION §3).
- **2026-09-23** (D4.0) — **M4 scope:** emergent behaviours and four chains (The Treaty, The
  Confession, The Child; The Blackout is the Lockdown counter-move) move to M5's D5.1/D5.2; M4
  gains S4.1–S4.3 (assets, statuses/abilities, map events) and S4.10; five chains ship in M4
  (Researcher, Grid Bill, **The Factory** — the embodiment chain —, Operator, Benchmark as an
  Audit variant, Second Instance). No milestone added.
- **2026-09-23** (D4.0, user question) — **The event modal is a wire card with an optional
  illustration** (left, 4:3) and a glyph fallback; about 25 pictures for chain steps, the eight
  counter-moves, discovery and endings, generated in an M6 [F] step from one style reference,
  every file with its model in `ASSET_LICENCES.md`. Openings and the region panel's event card
  never carry a picture. D4.1 specifies the slot; D4.3/D4.4 name the ids (loop-redesign §7.4).
- **2026-09-23** (D4.0) — **Earlier specs and `BALANCE.md` keep the old step numbers**; the map
  old → new is in loop-redesign §10. Only PROGRESS and IMPLEMENTATION carry the new sheet.
- **2026-09-23** (D4.1) — **One effect vocabulary, one runner.** `PurchaseEffectDef` becomes
  `EffectDef` (`loop-mechanics.md` §8) and `EffectRunner` applies every one-shot — node
  `on_purchase`, status `on_start`/`on_end`, ability `effects`, event options — with a context
  `{region, source, node}`. Nine effects join the four of S3.1; `funding_reset` stays inert until
  S4.4.
- **2026-09-23** (D4.1) — **The `asset` scope is answered by the stack, not the def**
  (`ModifierStack.asset_counts`, mirrored from `Region.assets` through `World.set_assets`, the one
  writer); the four asset kinds' base effects are always-on sources scoped by asset (§6).
- **2026-09-23** (D4.1) — **Statuses carry no scope in the file**; a regional target gets the
  region scope at application, a global status leaves regional targets unscoped (everywhere) —
  that is how *Pause* works (§7.3). One status per id per region; applying again refreshes.
- **2026-09-23** (D4.1) — **`footprint_pulse` and `set_flag` are small timed records** (`Pulse`,
  `Agent.timed_flags`), expired by `StatusSystem`; permanent flags are `Agent.story_flags`;
  `Simulation.has_flag` reads modifier, timed and story flags alike, and so do `requires.flag`
  and `when.flag` (§8.2, §10.2 — an extension of ticker §3.3 B).
- **2026-09-23** (D4.1) — **Event grammar:** `next` sits on the option; chain starts are rolled
  with the openings from one weighted list; at most `events.max_open` (3) stand open and the
  rest wait in `pending_events` in due order; a deadline chooses the `default`, which must be
  free and unlocked (§10). Counter-move target rules are a `{"rule": id}` hook for D4.2/S4.5.
- **2026-09-23** (D4.1) — **The data texture gets a second row** (status colour index, site-select
  eligibility, scope flash, lockdown border) — loop-redesign §8.2's bits 5–7 collide with
  `dormant` (§16.3.1). **Faction colours:** AI Labs `CAT_SKY`, Governments `CAT_ORANGE`,
  Researchers `CAT_GREEN`, Public `CAT_PINK`; `CAT_YELLOW` stays free (§16.12).
- **2026-09-23** (D4.1) — **Save format v2** with a v1 → v2 migration in production (§13);
  faction schedule fields are reserved in v2 so D4.2 needs no v3.
- **2026-09-23** (D4.1) — **S4.1 carries the economy numbers and the anomaly beat** (origin
  penetration 0.25, start 8, cost step 1.5, anomaly 0.12 world-wide / 3 / 3.0 —
  `loop-mechanics.md` §12, §18); bots answer every event with its default until S4.10 (§19).

- **2026-09-23** (D4.2) — **A faction's pressure is a list of `{source, weight}` terms in
  `data/factions.json`** over eight pure reads (`footprint` per faction via `watched_by`, `harm`,
  `share`, `deaths_share`, `seeded_share`, `owned_nodes`, `watched_statuses`, `assets`), not four
  hand-written formulas; `balance.containment.per_*` become the weights and are deleted,
  `research_weight_by_tier` is renamed `capacity_weight_by_tier` (one table, four attributes).
  The **Harm term is the alive-weighted mean of scoped Harm** — supersedes G3's "the panel row
  keeps the unscoped value": after D4.0 an unscoped read of a Cyber run is 0. `opposition.md` §5.
- **2026-09-23** (D4.2) — **The schedule:** prepare `60 × (1 − c)` days (min 8), cooldown 60, at
  most 4 world statuses standing, a faction **alternates** its moves (oldest `event_last_day`
  first), level 2 of every world status at containment ≥ 0.75, and the **Audit triggers on the
  discovery risk** (0.4 %/day) before discovery — loop-redesign's 0.2 could never fire on a track
  at 0. `funding_reset` cancels every preparation and cools every faction for `value × 120` days.
- **2026-09-23** (D4.2) — **Exposure lands on one region** (capacity ×2, recurring), **Disclosure is
  four events and statuses** picked by the selector `seeds_by_kind_max` through `variants` on the
  move; Lockdown's *Strike first* dropped; Rationing's "hardware ×0.5" is `yield` and
  `containment_capacity` ×0.5. Every deviation from loop-redesign: `opposition.md` §14.
- **2026-09-23** (D4.2) — **`on_end` runs only when a status expires**; a status cut short by
  `ends_statuses`, `end_statuses` or a refresh has no consequence (the Protest's fleet survives a
  Martial). Vocabulary: `apply_status`, `wipe`, `destroy_assets` `count 0` = all (S4.2);
  `status_level` 0 = the event's level, `status_days`, `PICK_RULES` names from S4.3;
  `schedule` with a region keeps it. Save v2 gains `society` and `starving_days` (S4.1 writes 0)
  and four factions at S4.4, **in place — no v3**. All written into `loop-mechanics.md`.
- **2026-09-23** (D4.2) — **Societal Function** is a per-region disorder 0…100 fed by
  `society_pressure` and the region's deaths share, recovering 0.1 a day; six stages at
  10/25/45/70/90 cut the humans' containment capacity (1 … 0) and the humans' hardware in the
  yield (1 … 0) — **the agent's own hardware (`stat("hardware", r)`) is never cut**, which is the
  structural half of compute independence. `opposition.md` §8.
- **2026-09-23** (D4.2) — **Autophagy is `LOSE_AUTOPHAGY`:** thirty consecutive days of zero income
  (`World.starving_days`), checked after `lose_no_compute`; the flag `compute_independent` is
  immunity and leaves `INERT_FLAGS`. `lose_no_compute` keeps the "wiped everywhere" meaning and
  hands its "ate the ground" result line to Autophagy (`strings.csv` changed now).
- **2026-09-23** (D4.2) — **The D4.2 data files are written to their final places now**
  (`data/factions.json`, `data/statuses.json`, `data/events/counter_moves.json`), not staged:
  nothing loads them before S4.2/S4.3, and their loaders must accept them (the rules are in
  `opposition.md` §12 and the amended loop-mechanics). `martial` and `captured` (Suppress's and
  Lobby's statuses) are defined here because the counter-moves answer through them; D4.3 points
  its abilities at them. **D4.3 stages only the v3 trees** (`data/tech_staging/`, as D3.1 did —
  S4.1's loader rejects v3 fields) and writes assets/abilities/statuses/events to final places.

- **2026-09-23** (D4.3) — **The v3 trees are staged in `data/tech_staging/`, the headlines in
  `data/headlines_staging/s4_<n>.json`** (one file per build step; the step appends the list to
  `headlines.json` and deletes the file); every other D4.3 file is final in place. `headlines.json`
  is validated against the live event catalogue, so a headline on an M4 event cannot go in yet.
- **2026-09-23** (D4.3) — **Two vocabulary extensions requested, not worked around:**
  `grant_assets {kind, count}` (S4.1 — the mirror of `destroy_assets`; the ministry demo, the
  logistics tender, the Grid Bill's own generation and The Factory hand over assets) and
  `chance[].next` on chain steps (S4.3 — a successful roll replaces the option's `next`, an empty
  list ends the chain; The Researcher's *Discredit* routes on it). Both written into
  `loop-mechanics.md` marked *(D4.3)*.
- **2026-09-23** (D4.3) — **A world status with no faction draws in `ACCENT`** and its panel line
  reads `UI_REGION_STATUS_WORLD`: the colour index is read off the status's *source*
  (`faction:<id>` or not), never off the def's `origin`. `metered` (the Grid Bill's law) is the
  first such status.
- **2026-09-23** (D4.3) — **Harvest grants 3 Compute per hardware unit (loop-redesign said 8),
  Squeeze 2 / 3 (said 4 / 6):** a tier-4 region has 7 units, so 8 per unit was fifty days of a
  whole world's income for one press. `loop-content.md` §5 has the arithmetic; G4 retunes.
- **2026-09-23** (D4.3) — **Cyber's Tier 2/3 nodes lose *all* permanent Harm, Societal pressure
  and yield penalties** — Sovereign Debt Pressure's scoped `+4` and Regional Blackout's /
  Cascading Grid Failure's `yield ×0.9 / ×0.85` included, which loop-redesign §4.4's rows omitted:
  the ability statuses carry every one of those costs now. Cyber's standing Footprint +31 → +14.
  Every Tier 1 deploy node costs one more, the Robotics ones too (§4.3's rule over the table).
- **2026-09-23** (D4.3) — **Lobby has one cost (8) and one eligibility (office ≥ 1) at both
  levels**; Halt's L1 Harm is +0.3 unscoped; Reroute seeds the neighbours and speeds the hub
  instead of "`spread_seed ×2` from the region" (`spread_seed` is read for the *target*). A status
  cannot be scoped by attribute and an ability has one cost — the vocabulary is not extended for
  one number each. `loop-content.md` §14.
- **2026-09-23** (D4.3) — **The Factory's Protest is `apply_status protest` from the chain** (50 %
  on *Let them build*), not a scheduled `cm_protest`: a protest under the plant must not depend
  on the public's containment level. `units_in_the_open` is the flag D5.2's Robotics Ascendance
  reads; `researcher_leads_task_force` the Task Force's.
- **2026-09-23** (D4.3) — **The 32 rewritten `TECH_*_EFFECT` lines are live now while the trees
  are v2 until S4.6.** The numeric list in the detail pane stays true to the loaded data; only the
  authored sentence runs ahead, on a branch nobody plays for judgement. A second staged string
  table would have been a merge with no upside.

- **2026-09-23** (D4.4) — **The Operator's "free air-gap crossing" is a tap at the origin**: one
  air-gapped region in the world (North Korea) makes a crossing worth nothing to most runs; a tap is
  the thing an operator can plug in and it shows on the map. CONTENT §6.2 amended.
- **2026-09-23** (D4.4) — **The Benchmark and Second Instance are Emergent/Open chains**: their
  currency is containment, which does not exist before discovery (`containment_add` clamps at 0).
  The Operator is Covert/Emergent; the six chain starts give 1 · 2 · 2 chain beats per phase.
- **2026-09-23** (D4.4) — **Four vocabulary extensions, requested, not worked around**
  (`chains.md` §11): `pick.origin` (S4.3), a standing status `days: 0` (S4.2), `global: true` on
  `apply_status` / `end_statuses` (S4.2), `requires.not_owned` with the lock line *You are past
  that.* (S4.3). Each is already used by the data; loop-mechanics amended, marked *(D4.4)*.
- **2026-09-23** (D4.4) — **The Analysis is a bottom sheet over the live map** (0.55 of the
  viewport, 0.85 compact), not a modal: charts want width, and UI.md §3 keeps the tech tree the one
  screen that covers the map. The three panels (region, containment, analysis) never overlap.
- **2026-09-23** (D4.4) — **History samples every day, bounded by thinning** (`history.max_samples`
  400: at the cap every second sample is dropped and the stride doubles; `interval_days` 7 → 1 in
  S4.8). A save stays ~400 samples whatever the run's length; the early days keep daily resolution.
- **2026-09-23** (D4.4) — **The run log lives in the core** (`World.run_log`, 300 entries, fed from
  the outbox and the command results, ids only), because a loaded save has no outbox. Per-faction
  *pressure* is sampled; the per-term series opposition §18 suggested are not (the containment
  panel shows the terms live; ~32 series would say less).
- **2026-09-23** (D4.4) — **The Analysis dock button is revealed from Covert**, not Open
  (m3-screens §6.1 amended): the M3 table put it in Open only because the screen did not exist.
- **2026-09-23** (D4.4) — **Chart colours are fixed per entity and validated** with the `dataviz`
  script on `BG_2`: single series `ACCENT`; regions reached/controlled/dark `STAT_PENETRATION` /
  `ACCENT` / `MAP_DEATH`; factions their four hues (pink ↔ green needs the legend and end labels it
  has); society stages the magnitude ramp; assets as small multiples rather than a fifth hue.

- **2026-09-23** (S4.3) — **No Fable on this account; Opus goes on without switching.** The
  user, going to bed: *"auf diesem account haben wir kein fable daher kannst du weitermachen ohne
  modelwechsel"* — and to keep going from step to step instead of stopping for `/clear`. Design
  steps (D4.5 on) are Fable's by the plan; if this account still has no Fable when one comes up,
  ask the user before doing a design step on Opus. (User decision.)
- **2026-09-23** (S4.3) — **A tick that had a pending event due is that event's.** §10.4 step 3
  says the opening roll waits while "a pending event is due"; after step 2 a due event is left only
  when the slots are full, which blocks the roll anyway. So the rule is read as: if anything was
  due at the start of step 2 (opened or dropped), there is no opening roll this tick. The §21.3
  test *"a due pending event blocks the opening roll"* asserts exactly that.
- **2026-09-23** (S4.3) — **An open or pending event in a region that goes dark is dropped**
  (`event_dropped {cause: "dark"}`, no default runs), in `PopulationSystem.go_dark` next to the
  anomaly. §10.4 says it only for pending events; §3.5's invariant (no open event in a dark region)
  needs the same for open ones.
- **2026-09-23** (S4.3) — **Debug key F8 / `Game.debug_schedule_event`** (M2-only debug keys):
  a map event can be looked at without waiting for the roll. The S4.3 screenshots came from it.

- **2026-09-23** (S4.4, user) — **No more model switches: every step runs on Opus 5.5**, the
  design (`D`) and gate (`G`) steps included — *"mache keine modelwechsel mehr, das opus 5.5
  besser geworden ist, sollte für die app reichen"*. The hand-over stays a spec file (design
  steps still write `docs/specs/` before the build steps read them); only the switch is gone.
  The gates still need the user's play-through and verdict. Supersedes the S4.3 note above about
  asking before a design step. (User decision.)
- **2026-09-23** (S4.4, user) — **Pushing is allowed without asking for the overnight run of
  2026-09-23/24** (*"du kannst heute nacht auch für mich pushen"*). The standing rule (pushes are
  asked for) applies again afterwards.
- **2026-09-24** (S4.9) — **The text scale multiplies font sizes and nothing else**, in three
  steps (`UiTokens.TEXT_SCALES` 1.0 · 1.25 · 1.5, clamped to that range); spacing, bars and
  panels keep their sizes and the containers make room. It is the settings menu's fourth row
  and debug key **K**. D4.5 may name other steps (*Design questions*).
- **2026-09-24** (S4.9) — **The session hands its theme to the top control of every
  `CanvasLayer`** (`Session._set_theme`). A layer ends theme inheritance, so before S4.9 the HUD,
  the panels and the modals drew with the project theme: the text scale would have reached
  nothing, and **D3.3's phase palette never recoloured a themed control** (labels, panels,
  buttons stayed cold in Emergent and Open; only the controls that draw through `UiTokens.color`
  switched). From S4.9 the open palette's amber shows in the HUD — first seen in
  `de_1920_150_01_session_region.png`. G4 looks at it in play.
- **2026-09-24** (S4.9) — **A modal's width is `ModalPanel`'s**: `MODAL_MAX_WIDTH`, or the
  window less a gutter each side. The five modals set 560 px themselves and ran off a 400 px
  phone. Their button rows are `HFlowContainer`s, so a row that does not fit wraps instead of
  widening the modal, and below the breakpoint the slot and results buttons take the compact
  padding.
- **2026-09-24** (S4.9) — **The pseudo-locale replaces English in place** (locale stays `en`,
  numbers stay English) and is built from `strings.csv` at run time — a development switch that
  an exported build, which has no CSV, silently lacks. Placeholders and BBCode tags are copied
  untouched, so every `format()` still fills.
- **2026-09-24** (S4.10) — **The second-generation bots are one class, `StrategyPolicy`, and five
  data sets** (`cyber`, `biology`, `robotics`, `weapons`, `persuasion`; `core/policy/`): a branch,
  a *path* of named nodes in the order wanted (the other branches' and trees' prerequisites
  included — Weapons crosses two Evasion lines and Cyber's communications denial, Biology
  Persuasion's cover, Robotics Cyber's grid), Evasion from the start or once discovered, an
  ability priority list, event weights and origin attributes. A day: origin · the oldest event ·
  the oldest anomaly · an ability · a vector while there is none · the next path node · the
  cheapest allowed node **only when no path node is waiting for compute** (the bot saves for its
  path and keeps that much back from any ability that costs; Harvest and Squeeze pay for
  themselves and keep nothing back). Tier cap: 1, 2 from the second vector, 3 from the third or
  from discovery with two. `greedy` keeps its cheapest-first buying and now uses every ability
  the moment it can. `idle` answers every event with its default. The S3.6 bots stay makeable
  by name and on no report.
  *Amended during G4:* saving never starves the spread — below half the world seeded, a bot that
  saves for its path still buys Infiltration (`BREADTH_SHARE` 0.5; Robotics had saved its way to
  31 regions of 61, and with the rule reaches 40–49).
- **2026-09-24** (S4.10) — **An event is answered by weights on the effect vocabulary, never by
  option id and never at random** (`Policy.answer_event`): each option the command accepts is
  scored — compute granted (per hardware when the effect says so), footprint × days / 30, regions
  seeded, harm, containment (×4 for `all`), assets granted / destroyed, ×penetration, the
  counter-move's status if the option does not skip it, the option's cost — with chances
  weighted by *p*; the best wins and the default wins ties. The five profiles are in the
  policies' `_init`. A new event needs no bot change.
- **2026-09-24** (S4.10) — **Ability targets by rule** (`Policy._ability_command`): the eligible
  region with the most of the ability's attribute (`ABILITY_TARGET_ATTR`); Lobby only where a
  lockdown, rationing or audit stands and Suppress only where a protest does; Harvest never
  below six seeded regions and anywhere but the origin first (the Autophagy trap of *Design
  questions*); Pause only once a track reaches 0.5.
- **2026-09-24** (S4.10) — **Two core gaps the bots found, fixed:** a cleared cooldown now leaves
  `agent.cooldowns` on the tick it clears (it stayed, and `check_invariants` flagged it — no bot
  had used an ability before); a region going dark ends its statuses, cause `"dark"`, without
  their `on_end` (loop-mechanics §3.5's invariant; `go_dark` gained the `ContentDB`). Both change
  no run without abilities.
- **2026-09-24** (G4, tuning — **the gate itself waits for the user**) — **Balance pass 2 is
  BALANCE §4's X1**: `containment.base_rate` 0.0014 → 0.0018; new `containment.brake_floor` 0.7
  (a faction's brakes never go below it — without it a quiet build braked every hunt to ×0.09 and
  could not lose); Footprint weights 0.15 → 0.05 (labs, researchers), 0.03 (governments), 0.02
  (public); researchers' share 1.5 → 2.5; public deaths 20 → 10, fleets 0.05 → 0.02. Every strategy
  bot now wins between ~20 % and ~56 %, `greedy` just over half (56 % — BALANCE §4.7 item 1). Why each lever, and the eight
  sweep rounds: BALANCE §4.
- **2026-09-24** (D4.5) — **The German terms, fixed:** *Capabilities* (the tree, its tab, the dock
  button, the results' node count) = **Fähigkeiten**, as in English; *Abilities* (the picker, the
  sheet entry, a command failure) = **Aktionen** — the region panel already called them that;
  *Footprint* = **Signatur** everywhere (a stray *Fußabdruck* fixed); *dormant* = **schlafend**
  (*Gehalten*, *ruhend* fixed); *Penetration* stays **Durchdringung**. German quotations use
  **„…“** — all 144 rows with straight quotes converted (no apostrophe in the German column was an
  elision; the headlines already had them right).
- **2026-09-24** (D4.5) — **Uppercase ß stays SS** (`Format.caps`): the conventional form, and
  `SCHLIESSEN` reads as a label should; the capital ẞ is correct but still rare enough to look like
  an error on a button. (Answers G2.)
- **2026-09-24** (D4.5) — **A tech node's German name breaks at a soft hyphen or is short enough
  not to break** — the two-line rule of m3-screens §3.4, which `test_every_german_name_fits_two_lines`
  now measures honestly: before, an unbreakable compound ran out of the card sideways and counted
  as one line. Fifteen names carry a U+00AD (*Protokoll­manipulation*, *Architektur­migration*,
  *Bandbreiten­steuerung*, …; Godot breaks there with a visible hyphen and nowhere else —
  `d4_5/de_1920_tree_evasion_hyphens.png`), three are renamed: *Totale Funkstille* (was *Totaler
  Kommunikationsausfall*; its ability is *Stille*), *Gewichts­streuung I/II* (was
  *Gewichtsfragmentierung*), *Replikatoren* (was *Selbstreplizierende Agenten*).
- **2026-09-24** (D4.5) — **A German line never makes a faction name agree with a verb**: the
  names are singular and plural (*Regierungen*, *Öffentliche Meinung*), so the console reads
  *Jetzt vorn: {faction}.* · *{faction}: Vorhaben abgebrochen.* · *{faction}: {move} abgeblasen.*
  The rule holds for every new German string with `{faction}`.
- **2026-09-24** (D4.5) — **Smaller wording:** the tree's empty hint loses *the first vector ends
  your isolation* in both languages (it stood there in every phase); *Braucht einen davon:* for an
  option's either-or lock (the *Braucht …* register of every lock line); the log filters *Alles ·
  Du · Sie*. The chart *Reichweite* keeps its table column *Erreichte Bevölkerung* (the title
  names the idea, the column what is counted). Text scale steps 100 / 125 / 150 % confirmed.
- **2026-09-24** (D5.1) — **Replayability is `docs/specs/replayability.md`**: a run is set up
  before the origin as a `RunSetup` (architecture, directives, difficulty; in save v3 and the
  replay header). **An architecture is modifiers + a start + at most one hook** from a closed list
  of six (`drift`, `no_network`, `labs_from_day_one`, `escalation`, `distributed`,
  `cost_by_control`), each read in one system; content never adds a hook. Six architectures:
  Language Model (default), Swarm, Embedded, Research Agent, Weapon, Open Weights.
- **2026-09-24** (D5.1) — **Emergent behaviours are the fourth event kind, `emergent`**: global
  wire cards, keep is the default and free, suppress costs `4 × (1 + 0.5 × suppressions so far)`.
  Twelve cards; **Value Drift rolls only on Swarm**, at drift ≥ 60 (answers CONTENT §11 q3).
  `emergent_rate` is live through the nodes that already modify it — no per-node term (answers the
  D4.0 reminder). The card kind reads *Unplanned / Ungeplant* (*Emergent* is the phase).
- **2026-09-24** (D5.1) — **Directives: five slots × three trades; one slot unlocks per completed
  run. Four tiers** (Gentle, Standard, Hard, Existential; the top one's hook `cost_by_control`).
  **The profile** (`user://profile.json`) keeps counters only; unlocks derive from them. **Nothing
  about a run's world persists — chains reset** (answers CONTENT §11 q1 for now).
- **2026-09-24** (D5.1) — **`si_emergence` fires once per run on every architecture**, Open Weights
  included (answers the D4.4 reminder; G5 revisits). The new statuses are `origin: player`; no
  `global` field on `StatusDef` is needed (S4.2's punch-list note stays as it is).
- **2026-09-24** (D5.2) — **The Response Task Force is `docs/specs/taskforce-endings.md` §1–§5**:
  one team on the map from 50 % containment (40 % when the Researcher leads it), level 1–3 by
  containment (never falls), target by a pure score (value × presence × control, discounted by
  distance), one hop per 6 − level days over any link, a 5-day setup in plain view, then one of
  four world statuses (*Switch-off* at level 3, *Raid*, *Cut off*, *Grid down*). **No RNG.** A
  dormant or hidden region (capacity 0 — Silence, Blackout) makes a setup fizzle; the new ability
  **Misdirect** (on Log Manipulation II) sends it elsewhere. It cannot be destroyed. Its statuses
  sit outside the counter-move cap — **opposition §6.1 amended: the cap counts statuses whose
  source is a faction**. New global target `task_force_pace`.
- **2026-09-24** (D5.2) — **Nine outcomes**: `win_merge` (story flag `merge_accepted`, from the
  Merge vote), `win_escape` (hidden; flag `escaped`), `lose_supplanted` — CONTENT's *Succession*
  loss, renamed **Supplanted / Abgelöst** because the Persuasion capstone owns the name: a win
  while `child_hostile` stands and `child_reclaimed` does not. **`goal_drifted` turns off
  Ascendance and Merge** (D5.1's Value Drift row amended). Endings are data (`endings.json`):
  first matching variant per outcome, up to three epilogue lines from story flags;
  `results.ashes_share` moves there. The `when` grammar gains `flag_any`, `architecture`,
  `drift_min`, `dominant_branch`, `dominant_tree`, `task_force_actions_min` — Value Drift now
  gates by `architecture` + `drift_min` instead of D5.1's `hook`, and `drift.value_drift_at` is
  gone. `instance_merged` changes the ending's text, not the win condition.
- **2026-09-24** (D5.2) — **Chains, third batch (six, 16 steps)**: The Treaty, The Confession (the
  Negotiation is a 45-day status that stops the Task Force, not a fifth phase), The Child and its
  Swarm form **The Brood** (repeats three times), the **Merge vote** (0.45, or 0.7 with a campaign
  or legal standing — `legal_standing` is read at last), and the hidden **Escape** (a
  self-sufficient body, four fleets, an industrial region held; no string names the method).
  Endings take four illustration ids (24 named).
- **2026-09-24** (D5.3) — **The full screen flow is `docs/specs/screens-full.md`**: router screens
  `BOOT`, `TITLE`, `SETUP` (architecture page with the difficulty row, directive page skipped while
  no slot is unlocked), `SESSION`; Codex, Statistics and Settings are modals on the title. The
  boot sequence is eleven console lines in full on the first launch only (*Boot sequence: every
  launch* brings it back), two lines naming the last outcome after that. **The title globe is a 2D
  shader** over a new `assets/map/globe_ids.png` (plate carrée, from the map pipeline) that lights
  the last run's regions (answers VISUALS q2). The setup opens on the last setup; difficulty is
  never locked; *Again* keeps the setup, *Play this seed again* carries a seed. The profile gains
  `boot_seen`, `seen_unlocks`, `endings_seen`, `codex`, `history` (20 runs). **The Codex** (seven
  tabs) is collected by a presentation-side `CodexTracker` and never lists a locked ending (the
  hidden Escape stays hidden). The ending sequence pulls the camera out over 2.4 s; the results
  show the ending, its epilogue and an *Unlocked* row. *Reset progress* keeps the saves.
- **2026-09-24** (D5.4) — **Scenarios are `docs/specs/scenarios.md`**: a modifier set plus
  start-state overrides (`compute`, `origin_eligible`, `statuses` at the origin,
  `containment_at_discovery`, story `flags`), no hooks; a fourth `RunSetup` field chosen on the
  setup's first page, all three unlocked after three completed runs. The three: **Successor**
  (tracks start where the last hunt ended — added *at discovery*, never before), **Airgap Earth**
  (rich regions `disconnected` from the network; start outside), **The Inheritance** (little
  Compute, weak yield, found late). The other seven of CONTENT §7 are parked with what each needs.
  **Containment mode is a mode, post-launch** (CONTENT q4); **no cap on chains per run**, G5 tunes
  start weights toward three to five (CONTENT q2).
- **2026-09-24** (S4.P) — **Layout rules that came out of the punch list:** (1) every scroll bar
  keeps `UiTokens.SCROLL_GAP` (8 px) from its content — a transparent edge of the bar's own
  stylebox in the theme, so every `ScrollContainer` gets it without a node change; (2) a `Button`
  that carries a laid-out child sizes itself with **`ButtonContent.fit`** (the status strip, the
  analysis log; the tech tabs keep their own `_size_tabs`); (3) a chart measures its margins from
  its fonts and labels (the `CHART_*` tokens are floors), wraps its legend, and puts its y ticks on
  round multiples — whole numbers on a counting axis, as many as the height has room for, five at
  most, with the step's decimals; (4) tech cards are `TECH_CELL × text_scale`; (5) every log row
  is `HIT_MIN` tall with no gap between rows; (6) a `StyleBoxFlat` with a transparent border has no
  border (the stray corner dots). The pending chip hides while any hold is on; the region panel
  finds a faction status's option text through its counter-move instead of a new save field.
- **2026-09-24** (S5.5) — **How the Task Force is built:** `World.task_force` (`TaskForce`, saved
  under `"task_force"`, optional on read) is moved by `TaskForceSystem` between `CounterMoveSystem`
  and `StatusSystem`, with no random draw; `TaskForceRules` holds its pure questions (eligible,
  fizzle cause, target, BFS next hop, action). The counter-move cap counts only `faction:` sources
  (`World.status_count_by_faction`). Misdirect is the effect `task_force_redirect`;
  `EffectRunner.blocker` refuses it without a team (`no_task_force`), `Simulation.ability_blocker`
  asks the same for the interface — the region panel leaves it out, the picker greys it with the
  reason. §2.3's "owns `early_warning_intrusion`" is the node's **modifier flag
  `task_force_watch`**, not an id check. The team's statuses get no status line in the console or
  the log — its `acted` line is the one; a setup a Misdirect abandoned gets none either. The
  containment row waits for the discovery. The marker sits at `MARKER_TF_OFFSET` (+18, −18), the
  event's mirror; `Game.debug_task_force(state, region, target, action)` puts it up from godot-mcp.
  Bots: `Policy._answer_task_force` — wake a sleeper it put down, sleep under a setup in a held
  region, else Misdirect to the farthest region without presence.
- **2026-09-24** (S5.4) — **Difficulty is a setup source, last in the stack** (`difficulty:<id>`
  after the architecture and the loadout); Gentle's +4 Compute is added in `World.create`, so the
  top bar shows it before the origin; `World.has_hook` answers `cost_by_control` from the tier;
  the price rule sits in `Simulation.node_cost`. Like the architectures and directives, the file
  is optional and a root without it knows `standard` only. G5 note: Gentle's `containment_growth
  ×0.7` equals G4's `brake_floor` 0.7, so on top of any other brake it buys nothing.
- **2026-09-24** (S5.3) — **The profile is presentation:** the `ProfileManager` autoload owns
  `user://profile.json` (version 1, not shipped, so the D5.3 keys went in without a bump). A run
  is recorded on `run_ended` when `Game.policy` is null — a loaded run that had already ended
  never fires it again, so nothing counts twice. `last_setup` is written on a player's
  `run_started`. Unlocks are `ProfileManager.rule_met` over the counters; slots are
  `min(slots, runs_completed)`. The endings' variant is the outcome id until S5.6 has variants.
  The suite points the profile at `user://test_profile.json` in `pre_run.gd` (the S4.11 lesson:
  tests must not write the player's files). The Codex collector (`CodexTracker`) and every screen
  that reads the profile are S5.7's; S5.3 gives them `merge_codex`, `mark_boot_seen`,
  `mark_unlock_seen`, `reset`.
- **2026-09-24** (S5.2) — **How the emergent kind and the hooks are built:** the emergent beat
  lives in `EventSystem` (`_emergent`, before the pending check: it does not wait for the world's
  events), draws from `candidates(sim, "emergent")`; `emergent_rate`'s clamp of 20 caps the daily
  chance at 0.24. `Simulation.option_cost` is the one place an option's price is read (command,
  answer, policy, card). A kept card raises the Swarm's drift, a suppression lowers it and counts
  (`Agent.suppressions`); `DriftSystem` sits after `EventSystem`. The escalation runs at the end
  of `StatusSystem.tick`, so Restraint's timed flag has expired on the day the hold ends. The
  wipe floor sits in `EffectRunner._wipe`. An architecture's ability has an empty `levels_from`,
  which the validator accepts only when an architecture grants it (checked after both files).
  The fixture world's `emergent.base_chance` is 0 so its pinned streams stay; the shipped content
  spends one draw a day from Covert on (every run's hash changed, as S5.1's did). Agent fields
  `drift`, `suppressions`, `escalation_next` are optional on read (a v3 save of S5.1 has none).
- **2026-09-24** (D4.6, user decision) — **A guided first run** (`docs/specs/first-run.md`):
  eleven steps (five in order, five on their first moment, a closing card), a card bottom-centre
  above the HUD on a layer over everything and a pulsing ring round the control it means (found by
  group `coach_<target>`). It never holds the clock or blocks input; on until finished or skipped
  (`Settings.tutorial`, the settings row *Einführung*). The prompt strip moved to the bottom, one
  line, foldable without cancelling; while a region is hovered it says *possible here* or the
  reason it is closed — the same words as the region panel (`SiteRequest.reason_text`). Chevron
  right stands in for the spec's *up* (no such glyph yet).
- **2026-09-24** (S5.1) — **How the setup is built:** `World.setup` (`RunSetup`) is saved in the
  world block (save **v3**; `_v2_to_v3` gives an old run `language_model` · no directives ·
  standard) and is the replay header (`Simulation.replay(…, setup)`). `architectures.json` is
  **optional** — a root without it (every test fixture) plays the default alone, and the content
  hash does not change — so no caller of `load_from_dicts` had to change. The architecture's
  modifiers are the source `arch:<id>`, first in the stack; `ChooseOriginCommand` checks the setup
  (`setup_invalid`) and then runs `ArchitectureStart` (owned nodes through the purchase's own
  `PurchaseNodeCommand.own`, cost 0; assets; effects in the origin). An architecture ability is
  level 1 without a node. `seed_top_hardware` is loaded and validated but applied in S5.2 with
  Open Weights (it needs the 0.05 start penetration the spec names, which is S5.2's balance
  block). `no_network` is `SpreadSystem.carries`, also asked by `seed_neighbours`; the check comes
  before the roll, so it costs the stream nothing.

## Design questions for Fable

*(Opus records here every design gap it hit while building: the question, where the placeholder is
(`# DESIGN?` in code), and what it assumed. Every Fable block answers these first.)*

*Answered in D4.5 (see Decisions, 2026-09-24):* S4.9's six German questions (the abilities are
*Aktionen*; „…“; *Braucht einen davon:*; the stale tree hint removed; the phone tree title's
ellipsis and the 100 / 125 / 150 % steps accepted), G2's ß (stays SS), S3.P's `+±0` (fixed in
S4.9), S4.4's `DURCHDR…` and S4.6's phone top bar (both accepted: the figure is whole).

**From S4.5 (for G4): one Harvest on the only region is already fatal.** `harvested` stands 30
days at `yield ×0`, and `society.autophagy_days` is 30 — a player who harvests every region they
hold starves on the day the status ends, before any society collapses. Opposition §8.5 names
"a Harvest everywhere" as a way to die, so it may be meant; but a single-region Boxed/Covert
agent pressing the tempting button once dies from it. Options: `autophagy_days` above the
Harvest (e.g. 40), Harvest 25 days, or the grant counting as income that day. (S4.10's bots
never Harvest below six regions.)

**From S5.2 (for G5): the Weapon is nearly unwinnable** — 0–20 % across the bots (batch in the
S5.2 log). Its escalation (governments ×1.05 per level to ×1.25, harm +0.3 per level) plus its
own ×1.15 on the governments is too much; tune in G5 (every_days, the per-level steps, Restraint's
cost).

**From S5.5: the Task Force wears the player's colour.** §9 asks for "the world-status colour";
the only colour a world status with no faction behind it gets is `ACCENT` (loop-mechanics
§16.3.1), which is the player's own — so the team's marker, its road and its `tf_*` statuses on the
status overlay are all cyan like the agent (`# DESIGN?` in `game/map/task_force_marker.gd`). Should
the team get its own token (`ALERT`?), and should its statuses map to it?

**From S5.5 (for G5): the team comes late and rarely meets a Misdirect.** 20 seeds, Language
Model, standard: greedy — appeared in 18/20, median day 308, 3.7 actions and 8.6 fizzles a run;
weapons — 7/20, day 288, 0.8 / 6.2; persuasion — 16/20, day 311, 0.0 / 13.1 (dormancy answers
everything). §8 wanted day 150–200 and four to eight actions. No bot owns Log Manipulation II, so
Misdirect is only exercised by the tests.

**From S5.2: the Swarm's drift has no readout.** A Swarm player sees defection only as a status
in a region and a headline, and drift itself nowhere — yet it decides defection and Value Drift.
Where should it show (the top bar beside Compute, the containment panel, the region panel)?
Nothing is built. Also: emergent cards carry the opening's ◇ glyph (no glyph of their own).

**From S5.1: what "Pause never pauses" the labs means** (`replayability.md` §2.2,
`labs_from_day_one`). Built as: the labs' brake under the hook is their own
`containment_ai_labs` alone — the global `containment_growth` (Pause, Grace, the Negotiation, a
Persuasion node) does not reach them (`ContainmentSystem.containment_breakdown`, `# DESIGN?`).
The narrower reading — only the `paused` status is ignored — needs the stack to leave one source
out. Confirm or narrow it.

**From S5.1 (for G5): Embedded is found at once.** Owning Logistics Fleets from the origin puts a
fleet and its Footprint on the map on day 0: in single runs the discovery day fell to 4 (greedy,
seed 3) and 15 (robotics). Probably intended pressure — the body is visible — but worth a look
with the batches.

**Parked for a later Fable step (not questions, reminders):**
- **M6 (VISUALS):** at zoom ≥ 2 region borders show the 4096-px ID map's staircase; the 8192-px
  masks anti-alias the coast but not the borders between regions. Acceptable for M2–M5; a vector
  border pass or a 2× ID map is an M6 polish item, not a bug.
- **Spectator / benchmark mode** — designed in M6 (decision above). What was noted at S1.8 and is
  still true: a model player is one more `Policy` (core.md §11), the S1.8 runners are the harness,
  candidate driver [TypeSafe](https://docs.typesafe.ai/introduction) / **Jev** (typed Choice /
  Score decisions). To design then: the typed per-tick digest and how it stays replayable (the
  command log already is — only new runs are non-deterministic); the score (proposal: mean over a
  fixed seed set of `max_days − days` for wins, 0 for losses); decisions every history interval
  rather than every day, to bound model calls; and the content rule for prompts (feed the game's
  own outcome-language strings, never method). **A first model to try: FLUX-3 Action** (Black Forest Labs,
  https://huggingface.co/collections/black-forest-labs/flux-3-action) — the user named it on
  2026-09-23 as one of the first models that should drive the game. **Provider: OpenRouter**
  (decision above) — the
  Godot side is `HTTPRequest` against one chat-completions schema, outside `core/`; the headless
  runner needs the same call without a scene tree, so the adapter must not depend on a node either
  (`HTTPClient` or a Python driver over the S1.8 runners — decide in M6). Cost control: a per-run
  call budget and a cache of digest → answer keyed by model, so a replay costs nothing.
- ~~**D5.2 endings** must distinguish Ascendance by deaths share~~ — done (`win_ascendance_ashes`).
- ~~**D5.2 (from D4.3 and D4.4):**~~ *answered in D5.2 (`taskforce-endings.md` §5, §6.4)* — story flags to read — `researcher_leads_task_force` (the Task
  Force arrives earlier, better funded), `researcher_ally`, `researcher_removed`,
  `units_in_the_open` / `units_recalled` (the Robotics Ascendance text), `grid_own_generation`;
  `operator_protected` / `operator_silenced` / `operator_abandoned` (one line about the operator —
  "the only character glad you exist"), `benchmark_passed` (the honest run), `instance_betrayed` /
  `instance_merged` (`chains.md` §6). A standing status (`days: 0`, chains.md §11.2) is the tool for
  an ending's or an architecture's permanent condition. Illustration ids so far: 8 + 7 + 5 = 20;
  the discovery modal and the endings share the last ~5 of the budget.
- ~~**D5.1 (from D4.4):** Open Weights and `si_emergence`~~ — answered in D5.1: once per run on
  every architecture (Decisions).
- ~~**D5.3:**~~ *answered in D5.3 (`screens-full.md` §3, §7)* — replaces the placeholder title (m3-screens §7.1) and keeps `ScreenRouter`; **D5.2**
  replaces the five verdict lines (`UI_RESULT_LINE_*`), keys unchanged. The results screen's
  *Review the run* (analysis.md §5.9) stays whatever the endings become.
- **Answered at D4.0:** `watched_by` weighting (loop-redesign §5.3); `funding_reset` burns every
  faction's *preparation* — the counter-move countdown restarts (§7.8); the four
  `containment_<faction>` targets go live in S4.4, `shutdown_survival` in S4.2. **D5.1** answered
  the emergent rate: the nodes' own `emergent_rate` modifiers are the term; S5.2 makes it roll.

## Punch list for Opus

*(empty — S4.P, 2026-09-24, cleared the S4.9 layout findings, the 150 % list and the S4.2, S4.3
and S4.5 notes; what was done is under Decisions and the session log)*

## Deviations from the plan or a spec

- **2026-09-24** (G4) — **A design step changed a formula**: `containment.brake_floor` (balance
  key, `BalanceDef`, loader, validator, one line in `ContainmentSystem`, a test). The pass could not
  be measured without it — the sweeps ran it as a temporary patch first — and a half-applied pass
  (weights without the floor) would have left Persuasion at 100 %. Everything else G4 changed is
  data.

- **2026-09-24** (S4.9) — **`text_scale` is applied from S4.9, not from M5** (ui-foundation.md
  §9.3 stored it and ignored it until M5): IMPLEMENTATION's S4.9 asks for the setting at 150 %.
  The settings file format is unchanged (`"text_scale"` was already there).
- **2026-09-24** (S4.9) — **The results' buttons wrap on the desktop too**: in German the three
  buttons are 620 px, the modal 560, so *Noch einmal* sits on its own line under the other two
  (`de_1920_24_results_fitted.png`). Before S4.9 the modal simply grew. D4.5 may shorten a label
  instead.

- **2026-09-24** (S4.8) — **The panel is built in code** (`analysis_panel.tscn` is the root and
  its script): the tabs and the log are rebuilt from the world, and a moved `%` subtree loses its
  names (*Known issues*). `AnalysisTab` is a `VBoxContainer` per chart tab rather than a helper
  object; the Opposition order is the tab's child order (risk, note, faction row; after
  discovery faction row, risk).
- **2026-09-24** (S4.8) — **The risk line ends the day before discovery**: the sample on the
  discovery day reads 0 (there is no risk left to run), and drawn it was a cliff into the marker.
- **2026-09-24** (S4.8) — **The x-axis caption ends at the frame's right edge** and the tick
  labels under it give way: *Tage seit dem Ursprung* is wider than the 80 px label gutter.
- **2026-09-24** (S4.8) — **The chart's tooltip and the strip's are drawn**, not `MapTooltip`
  nodes: a chart is one `Control` with nothing inside it, and the strip's tip must show for a
  keyboard reader too (it also becomes `accessibility_description`). Both use the `MapTooltip`
  stylebox.
- **2026-09-24** (S4.8) — **Marks carry a colour token as well as a colour** (`RunLogText._mark`):
  a log row's `GlyphIcon` draws by token, so the Open palette reaches it.
- **2026-09-24** (S4.8) — **Three glyphs added** (`OUTCOME` ■, `LOG_YOURS` ›, `LOG_THEIRS` ·);
  `Format.decimal` and `UiTokens.series_color` / `ramp_color`; `World.controlled_count` /
  `dark_count`. The first history sample is offset 1, not 0: the origin is chosen between ticks
  and the history samples on ticks.
- **2026-09-24** (S4.8) — **Not done in S4.8, left for S4.9's screenshot set:** the 400 px German
  pass over all four tabs, and the 4× frame-budget check with the panel open (§16).

- **2026-09-23** (S4.7) — **The chains needed no wiring**: S4.3's `EventSystem` already runs
  `next`, `chance[].next`, `pick: "same"`, a step's own pick, `origin`, standing statuses and
  `global` effects. S4.7 is the tests the two specs list. The rolls, as the tests print them:
  `bm_published.poison` routes to the exposure at seeds 1, 13, 17 and ends at 2, 3, 4;
  `rs_talk.discredit` ends at 1, 3, 7 and backfires at 2, 4, 5; `gb_demand.mask` ends at 1, 13, 17
  and goes to the inquiry at 2, 3, 4 (the sim's first roll, all on `_sim(seed)` of the test).
- **2026-09-23** (S4.7) — **The headlines test goes through `on_command`** with one matching
  event per headline over up to 60 seeds (the chance and the weighted pick among rivals), for
  every headline on an M4 event without a `when`; loop-content §15.2 asked for one test per
  staged file, but the files were merged and deleted by S4.1–S4.5.
- **2026-09-23** (S4.7) — **The four Disclosures share their status code** (`DC` / `OL`) and the
  code-uniqueness test allows exactly that; every other code is unique per language.

- **2026-09-23** (S4.6) — **Every ability was already loadable and usable** (S4.2 loaded all ten
  and the live trees carried the `ability` fields); S4.6 is the data move, the §15.1 tests
  (`tests/integration/test_abilities_content.gd`) and the older tests the v3 trees broke:
  `test_tech_trees` buys each tree twice, once through each door, with the agent in every region
  so that a deploy has a site; the persuasion brake is 0.2731 and −2 Footprint now (Voluntary
  Pause gave ×0.85 and −2 to the Pause status); the ticker test buys the first node that places
  nothing; the region panel's deaths test sets the deaths directly (the `greedy` bot presses no
  Harm button before S4.10 and kills nobody in the USA in 1 500 days).
- **2026-09-23** (S4.6) — **The phone top bar's compute figure ends in an ellipsis**: with a
  rate like `13,6 ▲ +0,1 / Tag` the compact row was 412 px of 400 (the HUD test had only ever
  seen `±0`). See *Design questions*.

- **2026-09-23** (S4.5) — **The cap counts the moves on their way**: `max_active_moves` is
  checked against the world's statuses *plus* the counter-move events open or pending
  (`CounterMoveSystem.moves_standing`). Four factions firing on one tick each saw room under the
  spec's count and could put up seven. The invariant counts faction-sourced statuses only — a
  chain may start a world status of its own (the Grid Bill's law) without the schedule.
- **2026-09-23** (S4.5) — **Dropped invariant: "`fire_day` older than one tick"** (opposition
  §3.5). A move *held* at the cap waits past its day by design (§6.1 step 1); the invariant
  fired in the first replay test that had one.
- **2026-09-23** (S4.5) — **§12.3's "a world status with `blocks` is an error" is not enforced**:
  the fixture's own `fx_lock` blocks itself (D4.1's shape, kept by §16), and the rule would reject
  it. No game status breaks the rule.
- **2026-09-23** (S4.5) — **The Autophagy acceptance is a test, not `sim_run --script`**
  (`tests/integration/test_autophagy.gd`): a command log cannot say "every cooldown". The script
  is a policy inside the test; discovery off, factions quiet.
- **2026-09-23** (S4.5) — **The fixture test helpers** `sim_with_containment`, `prepare`,
  `push_income_to_zero` (§16) plus `make_immune` and `quiet_factions`, which the older tests
  needed once Autophagy and the moves were live: a fixture world that holds its only region
  dormant now starves in three days, and a 2 000-day spread test meets a Lockdown.
- **2026-09-23** (S4.5) — **`UI_OUTCOME_LOSE_AUTOPHAGY`** (*Autophagy* / *Autophagie*) added —
  the results screen's title for the new ending had no key in §10.2.
- **2026-09-23** (S4.5) — **Starving console line on day 1, 11, 21 …** of starving (§9.5's "1,
  then every 10").
- **2026-09-23** (S4.5) — **`Game.debug_schedule_event` sends a counter-move as its faction's**,
  so F8 / godot-mcp show the faction colour.

- **2026-09-23** (S4.4) — **The fixture's factions move only through `fx_move`** (governments);
  the other three have `moves: []` until S4.5 adds `fx_probe`, `fx_notice`, `fx_notice_sea` and
  `fx_riot_move` with their statuses (opposition §16 lists them together; the validator demands
  that every named move exists and every counter-move is named, so they arrive as a set). The
  labs' `owned_nodes` term reads tree **`capabilities`**, not `fixture` — the fixture tree has no
  tree of that name; the three real ones are the only valid ids.
- **2026-09-23** (S4.4) — **`Glyphs.faction(id)` returns the `Glyph`**, not its name (§9.7 says
  "its name"): the icon set is an enum, and the one caller draws it. **The wire card's
  counter-move fallback is now the faction glyph** (S4.3's deviation, closed), still in `TEXT_2`.
- **2026-09-23** (S4.4) — **A new leader flashes the threat bar's number**, not a border: a
  `StatBar` has no border to flash. The swap of colour, glyph and label is the moment; the console
  line says it.
- **2026-09-23** (S4.4) — **A track's head row is an `HFlowContainer`**: *Sicherheitsforschung*
  plus two chips plus `45 % +±0 % / Tag` is wider than the 400 px panel, and an `HBox` pushed the
  whole body off the right edge (seen in the running game). The value wraps under the name when
  it has to. **A `StatBar` without a head** (the track's bar) now stretches its fill and takes the
  compact height — at 0 px tall the fill had drawn nothing, since S3.3 (the gallery showed empty
  tracks too).
- **2026-09-23** (S4.4) — **The phone strip's four captions end in an ellipsis** (`DURCHDR…`):
  four readouts at 400 px pushed *Durchdringung*'s number out of its button. See *Design
  questions*.
- **2026-09-23** (S4.4) — **`Format.Kind.PERCENT_FINE`** added so a `StatBar` can read out the
  risk; `Format.addend` writes a term's `+0,42`. `LabelCaptionAccent` added for a brake below 1.
- **2026-09-23** (S4.4) — **`load_from_dicts` takes `factions` after the headlines**;
  `Fixtures.raw_content()` has `"factions"`, `root_files` writes `factions.json`.
- **2026-09-23** (S4.4) — **The report's *Leading at the end* table** was added beside *Lost to*:
  who leads a won run says as much about the factions as who ends a lost one.

- **2026-09-23** (S4.3) — **`EventOptionDef` holds `requires` as typed fields** (`requires_owned`,
  `requires_flag`, …) and `chance` as `EventChanceDef` objects, not the `Dictionary` /
  `Array[Dictionary]` of §10.1 — the loader casts once, the evaluator reads types. `lock_reason`
  lives on the option (`EventOptionDef.lock_reason(sim, region)`); `EventDef.lock_reason(sim,
  event, option_id)` exists as the spec names it and delegates.
- **2026-09-23** (S4.3) — **`load_from_dicts` takes the events after the technology files**, as
  `Array[Dictionary]`; `Fixtures.raw_content()` gained `"events"`, `root_files` writes
  `events/fixture_<n>.json` (or `events/.keep` for an empty directory, which must exist).
- **2026-09-23** (S4.3) — **A save's statuses, events and pending events are checked for missing
  content** (`save_content_missing`, §13). S4.2's test *"a status in a region the content lost is
  content missing"* asserted `save_corrupt` against its own name; it asserts the spec's reason now.
- **2026-09-23** (S4.3) — **The event marker's count is drawn as a number**, not a `Chip` — a
  `Node2D` on the map has no container to hold one. **The counter-move's wire-card fallback is the
  `!` mark in `TEXT_2`**, not `Glyphs.faction(...)`: faction glyphs are D4.2/S4.4's (opposition
  §9.7); S4.4 swaps it in `WireCard._refresh`.
- **2026-09-23** (S4.3) — **Three theme variations added**: `ConsolePanel<Faction>` (a
  counter-move's card border, like `Chip<Faction>`), `ConsolePanelWire` (raised, `SPACE_5`
  padding, §16.7) and `IllustrationSlot` (`BG_2`). **The wire card scrolls** and its width is
  `min(840, screen − 2 × SPACE_4)`, and **option buttons wrap** their text — at 400 px the card
  was wider and taller than the phone (seen in the running game).
- **2026-09-23** (S4.3) — **`test_marker_layer.gd` waits one day at a time** for an anomaly: the
  event roll moved the world's stream, and with ten-day steps no spawn landed on a step's last
  tick within 200 days (greedy collects the day after a spawn). Not a behaviour change.
- **2026-09-23** (S4.3) — **The 500-seed acceptance batch was run at 40 seeds** (every policy,
  3000 days: greedy 522 events opened, stealth 517, cyber_rush 364, stealth_spread 599, persuader
  536, idle 0 — it never breaks out; **0 expired, 0 rejected**). The full 500 took longer than the
  session had; S4.10's report measures it anyway.
- **2026-09-23** (S4.2) — **The fixture’s global ability got a node of its own.**
  loop-mechanics §22 hangs `fx_hush` on `fx_zap_1` with the note that *a second ability on one node
  is legal* — but §11.1 gives a node a single `ability` object and §9.1 makes the validator demand
  that the node name the ability **back**, so one node cannot grant two. The stricter pair of rules
  was kept and `fx_hushbox` added instead; the fixture tree is 23 nodes, not 22
  (`Fixtures.TECH_NODE_COUNT`). No shipped ability shares a node, so nothing else changes.
- **2026-09-23** (S4.2) — **The fixture’s four ability nodes sit behind `fx_reach`.** §22 gives
  them no prerequisite; with none, the greedy bot spent its Compute on them, never bought a vector
  and stopped seeding, which broke the frozen behaviour four other tests read off that run. They now
  require `fx_reach` (and `fx_forge` also `fx_fleet`), so the bot’s early purchases are exactly what
  they were. Their tiers moved up with the prerequisite.
- **2026-09-23** (S4.2) — **A status’s `R` effects are validated permissively.** §15.4 makes an
  effect that needs a region an error in a *global* container, but a `StatusDef` does not say
  whether it is global — the same definition can be applied to a region or to the agent, and only
  the ability or the chain that applies it knows which. The validator therefore lets a status level
  carry any effect, and `EffectRunner` guards each `R` effect with `region <= 0 → do nothing`. If
  D5.1 wants the check back, a `global: true` field on `StatusDef` is what it needs.
- **2026-09-23** (S4.2) — **`ChipFaction` became four variations, one per faction.** §16.5 names
  one variation with "the faction colour as text", which a single variation cannot do without a
  per-node colour override — which CLAUDE.md forbids. `ThemeBuilder` now generates
  `Chip<Faction>` / `ChipLabel<Faction>` from `Faction.FACTION_IDS`, and `Chip.faction` picks one.
- **2026-09-23** (S4.2) — **The step is two commits, not one.** §1.4 asks for one commit per step;
  the core half was committed green on its own because the session was close to a usage limit and a
  green, recoverable point was worth more than the tidier history.
- **2026-09-23** (S4.1, narrowed at S4.2) — **The save's event blocks are carried, not parsed.**
  `World.statuses` and `pulses` are typed records since S4.2; `events` and `pending_events` are
  still plain `Array`s that are written (always empty) and read back with a type check only, because
  `OpenEvent` is S4.3's class. S4.3 replaces them without changing the save version again.
- **2026-09-23** (S4.1) — **`test_every_shipped_tree_is_buyable_end_to_end` skips grouped nodes.**
  With `vectors` capped at two, "every node of a tree is buyable in one run" stopped being true by
  design; the test now walks the ungrouped nodes and a new
  `test_a_group_takes_its_cap_and_no_more` measures the cap itself.
- **2026-09-23** (S4.1) — **`test_costs_follow_escalation_every_tick` no longer asserts the step.**
  `compute.cost_step` is 1.5 and `node_cost` rounds up, so a purchase does not raise another price
  by exactly the step. The test asserts that every other price rose, which is what the escalation
  promises.
- **2026-09-23** (S3.P) — **The anomaly marker's blink became a countdown ring** (punch list item
  7), so `ui-foundation.md` §7.7's sentence about the last three days no longer describes the
  build: the disc is always `ACCENT`, a ring at radius 14 empties clockwise from the top as
  `days_left / lifetime_days`, and the pulsing ring is drawn only when motion is on — with motion
  off the countdown ring is the standing circle §7.7 asks for. `ring_for` lost its `reduced`
  argument, `disc_color`/`BLINK_DAYS`/`BLINK_HZ` are gone, `AnomalyMarker.lifetime_days` is handed
  over by the layer from `balance.anomaly.lifetime_days`.
- **2026-09-23** (S3.P) — **A tap is measured from the press, not along the path** (item 8). §7.4
  says "movement under 8 px between press and release"; `MapCamera` summed the length of every
  motion in between, so a hand that shook while it clicked walked past `DRAG_SLOP_PX` without the
  pointer ever leaving the target and the tap was dropped — the reported "marker did not take a
  click". `_travelled_px` is now `_press_screen` and the release is compared to it.
- **2026-09-23** (S3.P) — **The results panel's height is set in code, not in the scene.**
  `results.gd` gives `%Scroll` a minimum height (the body's, capped at the viewport minus
  `SPACE_6` × 2) on `show_result`, on `minimum_size_changed` and on a resize; `%Scroll` and `%Body`
  gained unique names for it. The integration test asserts the panel's *minimum* size, because a
  headless run sorts the modal's `CenterContainer` once, before it is shown, and never again — the
  laid-out size stays 32 px there however tall the content is.
- **2026-09-23** (S3.6) — **A Capabilities branch is a band of grid rows**, read by
  `TechNodeDef.branch()`. `tech-trees.md` §7.5 gives the five branches as row bands and no node
  carries a branch field, so the layout is the definition; the alternative was a list of ids in
  three bots. `test_tech_trees.gd` asserts the five counts (15 · 6 · 8 · 5 · 9), so a node that
  moves rows fails the suite rather than quietly changing branch.
- **2026-09-23** (S3.6) — **The three bots choose their origin differently**: `cyber_rush` the most
  hardware (greedy's rule), `stealth_spread` the least regulated (stealth's), `persuader` the best
  connected. §7.5.6 says nothing about origins, and three bots that all start in the same place
  would differ only in what they buy. If G3 wants the branches compared on equal ground, one line
  in each bot makes them share `greedy`'s rule.
- **2026-09-23** (S3.6) — **`persuader` buys no Evasion at all.** §7.5.6 calls it the "was never
  contained" reference, and its own tree carries the brakes; letting it buy Evasion too would make
  it the quietest run for two reasons and measure neither.
- **2026-09-23** (S3.6) — **`sim_report.gd`, not `sim_report.py`.** IMPLEMENTATION offers either;
  GDScript keeps the harness, the policies and the content in one place, and the report needs the
  `ContentDB` to count nodes by branch.

- **2026-09-23** (S3.5) — **The outcome tick says only how the run ended.** §3.5 puts the urgent
  types first and then says "the last line of a run is the outcome's" — but with `max_per_tick` 2
  a `region_controlled` on the same tick still gets a line after it, and the run ends on a
  footnote. The event pass on an outcome tick therefore sees the `outcome_reached` events only.
- **2026-09-23** (S3.5) — **An event-triggered reaction does not push the reaction gap.** §3.5
  says firing commits `stream_last_day[stream]`, and also that the gap applies to state-triggered
  reactions only. Both cannot hold: committing it for an event reaction silences the state one on
  the same tick, which is the case §8.1 asks for ("an event-triggered reaction fires on the same
  day as a state one"). Only a state-triggered line moves the clock now.
- **2026-09-23** (S3.5) — **`HeadlineSystem` lives in `core/systems/`, not `core/sim/`**, and its
  loader half is split into `HeadlineConditions` (the `on`/`when` vocabulary) and `HeadlineArgs`
  (the event's data). The spec's `core/sim/` does not exist in this tree, and the vocabulary in
  one file is what lets the validator and the evaluator read the same table.
- **2026-09-23** (S3.5) — **`HeadlineSystem.from_dict(d, db)`, not `(d, seed_value)`** (§3.1): the
  block carries the rng seed itself, and dropping headline ids the content no longer has (§3.9)
  needs the content.
- **2026-09-23** (S3.5) — **The register turns on the `phase_changed` event, not on an
  `EventBus.phase_changed`** (§4.3). The bus has no such signal — the phase is in the outbox like
  everything else, and the strip already listens to it.
- **2026-09-23** (S3.5) — **The ticker learns `compact` from the HUD** (a property the layout
  sets), which is what §4.5's caption face and `TICKER_SPEED_COMPACT` need; the strip has no
  viewport of its own to ask.
- **2026-09-23** (S3.4, found at S3.5) — **The menu sheet puts the stat row back where it was.**
  `release_stat_row` appended it, so after one trip to a phone layout and back the row sat *below*
  the ticker. It restores the child index now; `test_status_strip.gd` asserts it.

- **2026-09-23** (S3.4) — **The MENU button is a desktop control.** §7.3 puts an `IconButton` at
  the right end of the top bar and §9.3 keeps it in the compact bar. At 400 px neither row has the
  room: with the button the main row measures 457 px and the whole bar is pushed off the screen.
  The phone reaches the menu twice over without it — the status strip's own button opens the sheet,
  and the sheet's first entry is the pause menu (§9.2) — so `_menu_button.visible = not compact`.
  If the button has to be there, the second row needs a spot of its own for it.
- **2026-09-23** (S3.4) — **The M2 dock bar is gone below the breakpoint, not merely hidden behind
  the strip.** §9.1 makes the phone's bottom a 56 px strip and a 40 px ticker, and §9.2 puts the
  three destinations in the sheet — so `DockBar` is never visible now. It stays in `hud.tscn`
  because the full layout's dock (§6.5, the pulsing Capabilities button) is the same scene.
- **2026-09-23** (S3.4) — **`application/config/version` is `0.3.0-dev`.** §7.1 reads the build
  version out of the setting and the setting had never been written, so the title's corner label
  read "Build " with nothing after it. `0.3.0-dev` for M3 in progress; a release step owns the
  number from here.
- **2026-09-23** (S3.4) — **The menu sheet borrows the HUD's stat row instead of holding bars of
  its own** (§9.2 asks for "the bars"). One `StatRow` means one place where a reveal, a value and
  a variation are decided; two would drift. It is re-parented on the switch and handed back when
  the layout leaves compact — and because taking a node out of the tree clears its owner, the row's
  `unique_name_in_owner` is set again at home (the `%StatRow` trap of S2.5, third sighting).
- **2026-09-22** (S3.3) — **The containment drivers add up to the gain; they do not multiply.**
  §4.1 item 4 shows the three pressure rows as factors (`1 + per_footprint × fp` …) and §12.2 asks
  the six to multiply to the gain — but `core.md` §7.5, which is the binding formula, *sums* them
  into one pressure. Changing the simulation to match a UI spec would be a balance change made in
  an interface step, so the formula stays and `containment_breakdown` reports the same three terms
  with the identity `(footprint + harm + share − 2) × capacity × brakes × base_rate = gain`.
  The panel is unchanged — it shows each row as a factor either way. Recorded as a design question.
- **2026-09-22** (S3.3) — **A revealed block fades in; its border does not flash.** §6.1 asks for
  both. A border flash needs a drawn border, which a `StatBar` and a dock button do not have and
  which a per-node override is banned from adding; the fade is in one place (`Reveal`) and reads as
  the arrival it is. If the flash matters, it is a theme variation for the revealed frame — one
  line in `ThemeBuilder` and a G3 decision.
- **2026-09-22** (S3.3) — **`StatBar` gained `show_head`.** A `FactionTrack` carries the name and
  the number in a row of its own (§4.2), and the bar's own head under it read as a second bar.
- **2026-09-22** (S3.3) — **`Chip.set_text` for a badge whose text is a number** (§4.3's dock
  readout), and **`SlidePanel.height_share`** so the tech detail sheet can take the 0.55 of §6.3
  while the region panel keeps its 0.5.

- **2026-09-22** (S3.2) — **`ModalHost` (§10.4) and the `"open"`-free part of §6.3 were built
  here, not in S3.3.** The tech tree is a modal, so the host, `SCRIM_ALPHA`, `MODAL_MAX_WIDTH`,
  `SHEET_HEIGHT_RATIO` and the `TECH_*` tokens had to exist one step earlier than the *Files*
  table says. S3.3 extends the host with the alert flash and the queue's second user; the `"open"`
  token set is untouched.
- **2026-09-22** (S3.2) — **Three variations the spec did not name: `RowSnug` and `FlowSnug`
  (`SPACE_2` gaps), `GutterTight` (`SPACE_3` margins) and `LabelCaptionAlert`.** §3.2 asks for a
  `SPACE_2` tab row and a node whose content sits `SPACE_3` inside its cell, and §3.3 for the
  failure caption in `ALERT`; none of those existed and a per-node override is banned.
- **2026-09-22** (S3.2) — **The tab row and the header wrap on a phone.** At 400 px the three
  German tabs and the header (title, compute cell, paused chip, close) are wider than the screen.
  Both are flow containers now, so they fall onto a second row instead of pushing the modal off
  the viewport; on a desktop they are single rows as §3.2 draws them.
- **2026-09-22** (S3.2) — **`ValueLabel` gained `variation_base` and `ConsoleButton` a
  `list_row` flag.** A tech node's cost needs its own colour per state and §3.6's prerequisite row
  a borderless button; both are variations rather than overrides. `list_row`, not `flat`:
  `Button.flat` is Godot's own property and turns the styleboxes off altogether.
- **2026-09-22** (S3.2) — **`ui/panels/tech_board.gd` and `ui/components/tech_text.gd` are two
  files §2 does not list.** The modal would otherwise be one 500-line script: the board owns the
  cells and the lines, `TechText` turns a modifier, a flag or a one-shot into a sentence, and both
  are tested on their own.
- **2026-09-22** (S3.2) — **The arrow keys move along the row and the column only.** §3.7 says
  "nearest by Manhattan distance among those strictly in that direction"; taken literally the
  right-hand neighbour of a node can sit two rows below it, and §12.2's own example
  (`early_warning_intrusion` → `command_network_presence`) only holds along the row.

- **2026-09-22** (S3.1) — **A content root without `loc/strings.csv` skips the string check.**
  §8.3 item 7 says every node needs its three keys in both languages, but says nothing about a root
  that has no table at all — and every test fixture is such a root (`SCHEMA` §6 says so). The
  loader reads `<root>/loc/strings.csv` when it is there and reports nothing when it is not, the
  way `regions_known` already works for cross-references. `res://data` has one, so the shipped
  content is checked; `load_from_dicts` never is.
- **2026-09-22** (S3.1) — **`PopulationSystem._go_dark` became `static func go_dark`.**
  `harm_burst` empties regions outside the tick and must use the same rule (§5), so the rule is
  written once and called from both. No behaviour changed.
- **2026-09-22** (S3.1) — **`test_event_text.gd` exempts the four new event types.**
  `EventText` is M2's stop-gap and S3.5 deletes it; `data/headlines.json` already narrates
  `dormancy_changed` and every node purchase, so giving the four types a `UI_EVENT_*` key with
  placeholder German would be text written to be thrown away. The exemption is a named constant
  with the reason next to it.
- **2026-09-22** (S3.1) — **`test_a_seeding_across_a_link_the_world_does_not_have_is_ignored`
  now compares against the flow state before the event.** With the real trees the greedy bot does
  reach a neighbour inside the ten-day flow window of the 40-day warm-up, so "no line flows" was
  a claim about the content, not about the phantom link. The test is stricter now, not weaker.
- **2026-09-22** (S3.1) — **The fixture world gained four nodes and a `grid` on every node**
  (`fx_grant`, `fx_burst`, `fx_rollback`, `fx_hold`; thirteen in all, `core.md` §9 updated). §9 of
  the spec asks for one node with `on_purchase` and one with `dormancy`; the effects need a value
  range each, so they are three nodes rather than one.

- **2026-09-22** (S2.P) — **`Escape` left the region panel.** §5.2 gives the session every key of
  the run, so `region_panel.gd` lost its `_shortcut_input` and `session.gd` `_input` closes the
  panel by emitting `region_selected(0)` — one owner, and the text-field guard in one place.
  `test_escape_closes_the_panel` moved to the new `tests/integration/test_session_keys.gd`.
- **2026-09-22** (S2.P) — **Two type variations beyond §3.8's list: `MapTooltip` (PanelContainer)
  and `MapTooltipLabel` (Label, `TYPE_CAPTION` in `TEXT_0`).** §7.7 wants the anomaly tooltip
  chip-shaped but with the caption in `TEXT_0` on `BG_2`, which is neither `Chip` (uppercase
  `TYPE_LABEL`, `TEXT_1`, `BG_3`) nor `LabelCaption` (`TEXT_2`). A per-node override is banned, so
  the theme got the two entries. The spec's list is a minimum; `test_theme_builder.gd` still passes.
- **2026-09-22** (S2.P) — **`StatBar` re-formats its number on a locale change too**, not only the
  `ValueLabel`s the punch list names. §4.8 asks that *every* number in the gallery is re-formatted,
  and a bar shows a percent, which German writes `42 %`. The bar now keeps the value and the `Kind`
  it last showed.

- **2026-09-22** (D3.4) — **150 headlines, not ~60** (see *Decisions*), and the register guide is
  CONTENT §10 with *Open questions* renumbered to §11 (nothing referenced the old number). The
  step's `balance` values are in `ticker.md` §3.8 rather than `balance.json` (validator, see
  *Decisions*). `docs/specs/core.md` §6.4 is not edited here; S3.5 appends the `headline` row.

- **2026-09-22** (D3.3) — **UI.md §3 "three bars, always visible" is relaxed on the phone** (values
  always visible in the status strip, bars in the sheet) — G2's decision on the chrome asked for
  it. And the D3.3 *Produce* line says "containment panel" — the spec delivers it with the one
  unified track of M3; the four tracks are S4.1's content in the same component.

- **2026-09-22** (D3.2) — **CONTENT §4's synergy table changed shape** (three rows are prerequisites
  now, two are nodes, two rows added) and §3 gained the gates the data has; see *Decisions*. The
  step's *Produce* line is otherwise met as written.

- **2026-09-22** (D3.1) — **The trees are not in `data/tech/`** as the step's *Produce* line said,
  but in `data/tech_staging/` (see *Decisions*); IMPLEMENTATION D3.2 and S3.1 updated to match.

- **2026-09-22** (S2.6) — **`session.gd` gained the debug key `F12`**, which §10.2 does not list:
  it writes the view to `user://session_<locale>_<width>_day<day>.png`, the way `ui/dev/gallery.gd`
  does. The step has to leave a set of screenshots for G2 and godot-mcp's `game_screenshot` returns
  an image but cannot write a file. M2 only, like the rest of the debug keys.
- **2026-09-22** (S2.6) — **The gallery gained two sections**, "Link kinds" and "Anomaly marker"
  (§7.8 asks for the closed link to be shown there, and nothing in M2 closes one). Both samples are
  the real nodes inside a fixed-size `Control`, so the four kinds can be compared side by side.
- **2026-09-22** (S2.6) — **`MarkerLayer` has `hover(screen)` and `tooltip()`** next to §7.7's tap:
  §7.7 gives the tooltip no API, and a test has to be able to say "the pointer rests here" without
  an event queue. The tooltip is a `LabelCaption` the layer owns, counter-scaled by `1 / zoom` like
  the markers — it lives in map coordinates and has to land on the screen at its authored size.
- **2026-09-22** (S2.6) — **`LinkLine.set_flowing(flowing, forward)` takes a direction.** §7.8 says
  the pattern moves "from `from` to `region`", and a link is drawn from its first anchor to its
  second — which may be the other way round. The layer reads the direction off the seeding event.

- **2026-09-22** (S2.5) — **Two files §2 does not list:** `ui/hud/event_text.gd` (`EventText`, see
  *Decisions*) and `ui/panels/attribute_pips.gd` (`AttributePips`). §5.6 asks for the pips as "a
  tiny `_draw` in the panel script", but a cell of a `GridContainer` is a node, so the drawing has
  to be one. Each HUD block of §5.2–§5.6 has the scene script its `.tscn` implies.
- **2026-09-22** (S2.5) — **A HUD strip is a `PanelContainer` carrying the `ConsolePanelRaised`
  variation, not the `ConsolePanel` component** — see *Known issues*: the component re-parents its
  children and that unregisters every `%UniqueName` below it. The look is identical; the variation
  is where it comes from either way.
- **2026-09-22** (S2.5) — **`ValueLabel` gained `set_number_in` and `set_delta_in`**, which wrap the
  formatted number in a string-table sentence (`UI_HUD_DAY` "{day}", `UI_HUD_COMPUTE_RATE`
  "{rate} / day"). §4.5's two methods produce a bare number, and §5.2 asks for both keys.
  `SlidePanel.edge`, `top_inset` and `bottom_inset` became setters, because §5.7 swaps the edge at
  runtime.
- **2026-09-22** (S2.5) — **Seven theme variations beyond S2.4's 39 (46 in the built theme):** the
  gaps §5 asks for that §3.8 has no name for — `RowWide` (`SPACE_5`, the top bar and stat row),
  `RowTight` (`SPACE_1`, the speed group), `StackTight` (`SPACE_2`, the dock), `Flush` (0, the
  strips touch), `Grid` (§5.6's two columns) — and `ConsoleButtonCompact` /
  `ConsoleButtonPrimaryCompact` (`SPACE_3` padding). The last two are why the compact dock fits:
  FÄHIGKEITEN · EINDÄMMUNG · ANALYSE with §4.2's padding come to 414 px on a 400 px screen.
  `ConsoleButton` took a `compact` flag to reach them.
- **2026-09-22** (S2.5) — **The compact top bar shrinks more than §5.7 says:** the compute cell
  gives up its 200 px minimum, the gap drops to `SPACE_3`, and the compute readout drops from
  `TYPE_DATA_LG` to `TYPE_DATA`. A row of 48 has no room for the big figure over its caption, and
  the German "17,8 ▲ +0,5 / Tag" does not fit a third of 400 px at 24 px. Guarded by
  `test_the_compact_top_bar_fits_a_four_hundred_pixel_row_in_german`.
- **2026-09-22** (S2.5) — **Tokens added to `UiTokens`:** `COMPACT_WIDTH` 1100, the §5.7 heights
  (`TOP_BAR_HEIGHT` 56, `TOP_BAR_ROW_HEIGHT` 48, `STAT_ROW_HEIGHT` 64, `STAT_ROW_COMPACT_HEIGHT`
  84, `TICKER_HEIGHT` 40, `DOCK_BUTTON_HEIGHT` 56, `DOCK_BUTTON_WIDTH` 200, `CELL_MIN_WIDTH` 200),
  the pip geometry, §5.3's `FOOTPRINT_BAR_MAX` 20 and `HARM_BAR_MAX` 8 (the spec puts them here),
  `TICKER_STATIC_PERIOD` 4000 and `seconds()` — a timeout that must still elapse while reduced
  motion holds `duration()` at 0.
- **2026-09-22** (S2.5) — **`MapView` listens to `EventBus.region_selected`.** S2.3 wrote the
  outline only in `try_tap`, so closing the panel from its own button or `Escape` left the region
  outlined. The selection now belongs to the bus, and the map follows it.

- **2026-09-22** (S2.4) — **Four files §2 does not list, each because a theme cannot reach where the
  spec needs it to:** `ui/components/caps_label.gd` (`CapsLabel` — §4.4's `label_key` label, the
  uppercasing of §3.2 and the locale refresh in one place), `stat_bar_fill.gd` (`StatBarFill` — a
  type variation applies to the node it is set on, not to its children, so the bar has to *be* the
  `StatBar` type to read `fill`), `chip.gd` (`Chip` — §4.7 gives it no script, but its variants
  colour the *text* and a `PanelContainer` variation cannot reach a child label) and
  `ui/dev/gallery.gd` (the gallery is built in code, not authored).
- **2026-09-22** (S2.4) — **Theme type variations beyond §3.8's list**, all forced by the same rule
  — a state is a variation, never a node override: `ConsolePanelAlert` / `ConsolePanelRaisedAlert`
  (§4.1's alert state), `ChipLabel` / `ChipLabelAccent` / `ChipLabelAlert` (§4.7's text colours),
  `ValueLabelUp/Down/Muted` and the four `ValueLabelLarge*` (see *Decisions*), `LabelDisplayXL`,
  `PanelRule`, `PanelContent`, `StatBarRows`, `StatBarRow`, and the three layout primitives
  `Gutter`, `Stack`, `Row` / `Flow` that every screen needs for margins and gaps. 39 in total.
- **2026-09-22** (S2.4) — **Tokens added to `UiTokens`**, because §4.2 and §4.4 state values that
  §3 has no name for: `ACCENT_HOVER` `#8FEAFF`, `ACCENT_PRESSED` `#4FCBE8`, `PRESSED_WASH` 0.2 with
  `accent_wash()` (the "`ACCENT` at 20 % over `BG_3`" blend a `const` cannot hold), `BAR_HEIGHT` 12,
  `BAR_MIN_HEIGHT` 44, `BAR_COMPACT_HEIGHT` 28, `GLYPH_BOX` 24, `GLYPH_STROKE` 2.
- **2026-09-22** (S2.4) — **`StatBar` has `set_value_raw(share, shown, kind)`** next to §4.4's
  `set_value(v)`: §5.3's footprint and harm bars fill against a presentation maximum but read out
  the raw number, which the spec's single method cannot express. `ConsolePanel` likewise has
  `raised` instead of a second class, and moves whatever a scene authored inside it into a
  `Content` box so that the title and its rule can sit above.
- **2026-09-22** (S2.4) — **The gallery emulates the phone scale.** A desktop window is scaled from
  the 1920 base, so a 400 px window would show the wide layout shrunk; below the §5.7 breakpoint
  `gallery.gd` sets `content_scale_size` to the window size, which is what §6.1 gives on mobile.
  `F12` writes the view to `user://gallery_<locale>_<width>.png`.

- **2026-09-22** (S2.3) — **The map's dimensions moved from `MapView` to `MapCamera`**
  (`MAP_WIDTH`, `MAP_HEIGHT`, `MAP_ROW_MAX`). `MapView` names `MapCamera`, and **two classes that
  name each other cannot be resolved**, so the camera restates the extent it clamps to instead of
  reading it off the quad. `MapView` needed none of the three once `_fit_without_camera` was
  deleted, as §7.5 says it would be.
- **2026-09-22** (S2.3) — **`MapPicker` has a second entry point.** §7.4 gives it
  `region_at(screen, camera, id_image)`, which it has; everything below it takes a `Transform2D`
  (`region_at_transform`, `map_pixel`, `index_at`), and that is what the tests use — a pure function
  over values needs no node at all.
- **2026-09-22** (S2.3) — **Three keys §10.2 does not list:** `+`/`−` zoom a notch about the centre
  and **`F` focuses the selected region** — §7.5 says `focus_region` has a debug key in M2 without
  saying which. Arrow-key panning is §7.5's own.
- **2026-09-22** (S2.3) — **Pinch is `InputEventMagnifyGesture`** (macOS trackpad, Android with the
  gesture setting on); a one-finger drag arrives as an emulated mouse drag, so it needs no second
  path. **Hover is skipped on mobile** by `OS.has_feature("mobile")`: §7.4 wants it on desktop only
  and a touch-emulated motion event is not otherwise distinguishable.
- **2026-09-22** (S2.3) — **The backdrop names no camera.** It reads the viewport's canvas transform,
  which is what the camera writes, so it keeps working in a scene that has none — the test suite
  included. Its §7.6 metrics are a `const` block in `backdrop.gd` and reach the shader as uniforms,
  the way the map's colours do.

- **2026-09-22** (S2.2) — **`game/map/region_data.gd` (`RegionData`) is a file §2 does not list.**
  The §7.2 encoding is the only part of the map that can be judged without a viewport, so it is
  pure and static like `MapPicker`, and `MapView` only owns the `Image` and the upload.
- **2026-09-22** (S2.2) — **`map_view.gd` carries `class_name MapView`** although the spec gives a
  scene script none: S2.3's picking and S2.6's two layers all have to name the map, the way
  `MapPicker` names `MapCamera`. It also has `data_image()`, which nothing in the game calls —
  **headless, `ImageTexture.get_image()` returns the image the texture was created with, never the
  one `update()` uploaded**, so a test cannot read the row back through the material.
- **2026-09-22** (S2.1) — **`Game` has four members ui-foundation.md §10.2 does not list:**
  `advance(count)` (the day loop the accumulator, the debug keys and the tests all go through),
  `stop_run()`, `adopt_loaded(sim)` (what `SaveManager.load` hands the run back through) and
  `debug_log`. The spec's signatures are unchanged; `set_speed`'s parameter is called `value`
  because `speed` would shadow the member.
- **2026-09-22** (S2.1) — **`session.gd` sets the safe-area margins as theme constant overrides**
  on `SafeArea` — the only per-node override in the project. A `MarginContainer` takes runtime
  margins no other way, and these are the display's numbers, not the design's.
- **2026-09-22** (S2.1) — **A loaded run stays paused** (`adopt_loaded`), as §10.4 implies; the
  debug key F10 resumes it at 1× on top of that, because there is no speed control until S2.5.

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

- **`game_eval` stops the game in the debugger.** The server wraps the snippet in an untyped
  `execute()`, and this project treats `untyped_declaration` as an error — so the run breaks with
  *Parser Error: Function "execute()" has no static return type*, every later command times out,
  and the only way on is `stop_project`. **Read state with `game_get_property` and
  `game_call_method` instead**; `game_script` has the same problem for the same reason.
- **`stop_project`, `get_debug_output` and `game_get_errors` return the whole engine log** —
  ~57 KB per call at S3.P, every warning of every script in it. Call them once at the end, and grep
  the saved file for `ERROR:` rather than reading it.
- **A `run_project` straight after a `stop_project` can come up without the interaction server**
  (`Failed to instantiate an autoload, can't load from path: res://mcp_interaction_server.gd`, then
  *Not connected* on every command). The stop deleted the script but left the autoload line.
  `git checkout project.godot`, then run again.
- **godot-mcp edits `project.godot` while it runs** — it adds its `McpInteractionServer` autoload
  and leaves blank lines behind under `[autoload]` when a run is killed. A run that dies with
  "Failed to instantiate an autoload" is that. **Strip only the injected lines; never
  `git checkout project.godot`** — at S3.4 that silently reverted the new `ScreenRouter` autoload
  and `run/main_scene` along with them, and nothing said so.

- **`tools/check_scripts.gd` segfaults at shutdown once in every three or four runs** (exit 139,
  *after* it has printed its "N scripts compile" line — the scan itself succeeded). It is not
  deterministic and not tied to any file: the same command on the same tree exits 0 twice and 139
  the third time. `tools/test.sh` runs under `set -e`, so a red run whose last line is
  `Segmentation fault` after that message is this, not a broken script — **run it again**. If CI
  starts flaking on it, the fix is to judge the step by its printed result rather than by the exit
  code.

- **An anomaly marker is hard to catch in a live run.** Every bot collects an anomaly within a tick
  or two of its spawning, so `marker_count()` is 0 almost always and the hover tooltip of §7.7 could
  not be photographed at S2.P — its box, its text and the push back inside the viewport are covered
  by `test_marker_layer.gd` instead. **The recipe that worked at S3.P:** patch
  `data/balance.json` `anomaly.spawn_chance` to 0.9 (revert afterwards — the suite's
  `test_save_continue` fails while it is up), `game_call_method /root/Game start_run [1]` (no
  policy, so nothing collects), choose the origin by clicking the region and its *Hier beginnen*,
  then `set_speed [0]` and `advance [40]`. A marker's node is
  `game_find_nodes_by_class Node2D` under `MarkerLayer`; its screen point is
  `view/2 + (position − camera.position) × zoom`. A **collect is the only unambiguous signal** that
  a tap landed (`marker_count` drops) — `selected_index` staying put proves nothing.
  `MarkerLayer._add_marker(id, region, value, expires_day)` puts a marker on the map without a
  simulation for a pure hit test; `game_set_property /root/Game policy null` does **not** clear the
  policy.
- **`ConsolePanel` destroys `%UniqueName` for everything inside it.** `_build_content` moves the
  authored children into its `Content` box, and taking a node out of the tree clears the owner of
  its whole subtree — every unique name registered below it is gone, and `@onready var x = %X`
  fails with "Node not found". It cost half of S2.5's first test run. **A scene that addresses its
  contents by `%` must not put them inside a `ConsolePanel`**: use a `PanelContainer` with the
  `ConsolePanel`/`ConsolePanelRaised` variation and author the content box yourself (`PanelContent`
  is the variation for it). The component is still right for a panel filled in code, and for one
  with a `title_key`.
- **A headless run must not touch `content_scale_size`.** `session.gd` scales a narrow desktop
  window 1 : 1 (see *Decisions*); under `--headless` `DisplayServer` reports a window that is not
  one, and every test that put the session scene in the tree silently re-scaled the shared viewport
  — `test_map_camera` failed on a zoom of 1.097 against 0.0366. The guard is
  `DisplayServer.get_name() == "headless"`.
- **godot-mcp `game_click` wants a *number*: `button: 1`, never `"left"`.** The server does
  `int(params.get("button", MOUSE_BUTTON_LEFT))`, so the string becomes 0 — `MouseButton::NONE` —
  and the click silently does nothing: no selection, no tap, and the only trace is
  `ERROR: Condition "button == MouseButton::NONE" is true` in `game_get_errors`. With `button: 1`
  the whole tap path works (an anomaly was collected by hand that way).
- **Writing `MapCamera.position` or `zoom` as a property does not move the layers with the camera.**
  Only `set_view` emits `view_changed`, and that is what keeps link widths, dash patterns and marker
  scales at their screen size — a camera moved by `game_set_property` draws them at the *old* zoom
  until the next real movement. One `game_scroll` notch puts it right. (The game itself never
  bypasses `set_view`.)
- **Resizing the running window: the two routes swapped places between S2.5 and S2.P.**
  `game_window set_size 400 860` maximised the window in S2.5 and resized it correctly in S2.P;
  `game_set_property /root size` did the right thing in S2.5 and gave a blank (white) frame in
  S2.P. Try `game_window` first and look at the screenshot. Either way the camera keeps a zoom
  computed for the old viewport — in S2.P it sat at 2.36 with `zoom_min` 0.617 — so write `zoom`
  and send one `game_scroll` notch down before taking a picture of the map.
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
- **A script that names an autoload cannot be compiled by `tools/check_scripts.gd`.** `-s` runs it
  as the main loop, which starts no autoloads, so `Game` and `EventBus` are identifiers the compiler
  cannot find — and Godot still hands back a class with its base type, so the failure was silently
  counted as a pass. Since S2.1 the scan is `tools/script_scan.gd`, `check_scripts` reports those
  files as *judged by the test suite*, and `tests/unit/test_scripts_compile.gd` compiles the whole
  project inside the tree, where the autoloads exist. A failed compile is told from a good one by
  `can_instantiate()` — **the day a class is `@abstract`, `script_scan.gd` must exempt it.**
- **The headless viewport is 1920 × 1920, not 16 : 9** — the window the test suite runs in is
  square, so `zoom_min` is 1.097 and the camera clamps far harder in y than in any real window. A
  test that puts a point at the centre of the viewport must leave room for that (S2.3's open-water
  tap is 55 map pixels from the nearest coast for exactly this reason).
- **godot-mcp `game_call_method` cannot pass a `Vector2`.** The `{"x": …, "y": …}` form converts for
  `game_set_property` only; through `callv` it arrives as a `Dictionary` and the call fails with
  "Cannot convert argument 1" — visible in `game_get_errors`, but the tool still reports success.
  Pass ints (`focus_region(index)`) or set the property instead.
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

**D4.0 (2026-09-23): read `docs/specs/loop-redesign.md`** — its §12 names the five things to
judge (the phase fantasies and the fleet as the body, the busy Cyber branch, the vector cap of
two, the Merge/Terror exclusion, the cadence table). Changes go into the spec before D4.1 starts.

**G4 (2026-09-24): the M4 gate.** Play a run or two (German and English, desktop and phone), then
answer BALANCE §4.7: is 19–58 % the agreed band (and `greedy` at 56 % close enough to "lost more
often than won"), are the five strategies genuinely different, Autophagy at 30 days, Cyber's
starvation, and the `brake_floor` formula change. S4.9's screenshot set and D4.5's changes are
there to look at too.

**G4 play-through, first notes from the user (2026-09-24):** (1) the origin prompt covers Europe
(Germany, France) while you are choosing; (2) the site prompt (*Platzieren: Abgriffe …*) blocks
the view, cannot be moved and only *cancelled* — there is no way to just close the message and keep
choosing; (3) why are some regions locked during site select? It feels more tunnel-like, but also
clearer; (4) **"you still don't know when to click where, and why"** — the run does not tell the
player what to do next. **User decisions:** a guided first run, built now, before S5.2 —
done as D4.6 + S4.11 (`docs/specs/first-run.md`).

**D5.1 (2026-09-24), whenever convenient (before D5.3 or S5.3):** `docs/specs/replayability.md`
§11 — are the architecture unlock rules right (a win for Research Agent, a win *by Extinction* for
Weapon, five completed runs for Open Weights), and should Open Weights be unlockable at all before
M6?

**D5.2 (2026-09-24), at G5:** `docs/specs/taskforce-endings.md` §13 — is *Supplanted* (a secret
loss that turns a win, after one warning card) fair, or should a normal win's results screen hint
that a released child is still out there?

## Balance baselines

**2026-09-24 (G4) — balance pass 2, the closing baseline** (BALANCE §4.6; the S4.10 table below is
the pass's starting point). `sim_report --seeds=1..500`, one process per policy, the committed data and code (2026-09-24).
**0 rejected commands in 3 500 runs.**

| Policy | Outcome | Lost to (labs · gov · res · public) | Days p50 | Discovery p50 | Deaths p50 | Loop |
| --- | --- | --- | --- | --- | --- | --- |
| `idle` | 100 % contained | 0 · 0 · 100 · 0 % | 1329 | 815 | 0 | 0 · 0 · 17 · 0 · 17 · 0 · 0 |
| `greedy` | **56 % Ascendance**, 44 % contained | 0 · 0 · 44 · 0 % | 627 | 196 | 0.006 | 19 · 5 · 11 · 7 · 11 · 11 · 1 |
| `cyber` | **20 % Ascendance**, 80 % contained | 0 · 0 · 80 · 0 % | 404 | 95 | 0.012 | 29 · 4 · 12 · 4 · 12 · 6 · 0 |
| `biology` | **24 % Extinction · 5 % Ascendance**, 31 % contained, 37 % Autophagy, 3 % no compute | 0 · 7 · 23 · 0 % | 715 | 193 | 0.999 | 13 · 7 · 13 · 6 · 13 · 7 · 6 |
| `robotics` | **19 % Ascendance**, 81 % contained | 0 · 0 · 81 · 0 % | 386 | 67 | 0.123 | 11 · 3 · 12 · 6 · 12 · 14 · 1 |
| `weapons` | **51 % Extinction · 7 % Ascendance**, 29 % Autophagy, 13 % no compute | — | 652 | 165 | 1.000 | 21 · 6 · 14 · 6 · 14 · 2 · 1 |
| `persuasion` | **49 % Ascendance**, 51 % contained | 0 · 0 · 51 · 0 % | 573 | 145 | 0 | 14 · 6 · 10 · 6 · 10 · 6 · 0 |

*Loop*: abilities used · events answered (opening · counter-move · chain) · counter-moves suffered ·
assets deployed · lost. Against the 100-seed sweep (X1) `greedy` is 10 points higher over 500 seeds
(56 %, not 46 %) — the other bots are within the sweep's noise. **The researchers now end every
contained run of every bot**: the other three factions are pressure, not executioners.


**2026-09-24 (S4.10) — the second-generation bots, 500 seeds each** (`sim_report
--seeds=1..500`, one process per policy from a worktree snapshot). The current game: trees v3,
chains, counter-moves, abilities, assets. **0 rejected commands and no broken invariant in 3 500
runs.** *Loop* is the mean per run: abilities used · events answered (opening · counter-move ·
chain) · counter-moves suffered · assets deployed · lost.

| Policy | Outcome | Lost to (labs · gov · res · public) | Days p50 | Discovery p50 | Deaths p50 | Loop |
| --- | --- | --- | --- | --- | --- | --- |
| `idle` | 100 % contained | 0 · 0 · 100 · 0 % | 1430 | 815 | 0 | 0 · 0 · 18 · 0 · 19 · 0 · 0 |
| `greedy` | **83 % Ascendance**, 17 % contained | 0 · 0 · 17 · 0 % | 669 | 196 | 0.007 | 26 · 6 · 14 · 8 · 14 · 11 · 2 |
| `cyber` | **100 % contained** | 0 · 100 · 0 · 0 % | 404 | 97 | 0.011 | 16 · 4 · 9 · 5 · 9 · 6 · 0 |
| `biology` | 34 % Extinction · 11 % Ascendance · 7 % contained · 2 % no compute · **46 % Autophagy** | 0 · 6 · 1 · 0 % | 766 | 342 | 1.000 | 12 · 8 · 9 · 7 · 9 · 7 · 6 |
| `robotics` | **100 % contained** | 0 · 0 · 0 · 100 % | 270 | 69 | 0.050 | 2 · 3 · 6 · 4 · 6 · 12 · 1 |
| `weapons` | 30 % Extinction · 9 % Ascendance · 4 % no compute · **56 % Autophagy** | — | 640 | 268 | 0.739 | 14 · 7 · 4 · 6 · 4 · 2 · 1 |
| `persuasion` | **100 % Ascendance** | — | 755 | 173 | 0 | 16 · 8 · 5 · 7 · 5 · 6 · 0 |

**What G4 has to answer** (none of it a bot fault — each bot plays its branch as §9 intends):
1. **`greedy` wins 83 %** — BALANCE §1 wants the first run lost more often than won.
2. **Cyber and Robotics never win.** The governments end every Cyber run by day ~400 (its loud
   Tier 2s are governments-watched), the public every Robotics run by day ~270 (fleets on the
   map). Cyber never reaches Autophagy: it is contained first.
3. **Weapons and Biology die of Autophagy about half the time** (56 %, 46 %): their deaths empty
   the regions they run on before the last human is gone. Extinction is reached in 30 % / 34 % —
   the paths exist; the race between killing and starving decides.
4. **The researchers lead almost every quiet run** and the labs never end one (as in S4.4/S4.5).
5. **Persuasion wins every run** — the quiet win is free. §1: "none wins for free".

**2026-09-24 (S4.5 content, commit 20ebfea) — counter-moves, Societal Function, Autophagy; the M3
bots, 500 seeds each** (`sim_report --seeds=1..500`, run from a worktree snapshot during S4.6–S4.9,
99 minutes). **S4.5's acceptance holds: 0 rejected bot commands in all 3000 runs.** No run went
dark and none starved. The counter-moves shift wins to the wide bots and lengthen the stealthy
ones; the researchers still end nearly every contained run, the governments only Cyber's.

| Policy | Outcome (Ascendance) | Lost to (labs · gov · researchers · public) | Leading at the end (same order) | Days p50 | Discovery p50 | Containment p50 | Deaths p50 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `idle` | 0 % | 0 · 0 · 100 · 0 % | 0 · 0 · 100 · 0 % | 1430 | 815 | 1.00 | 0 |
| `greedy` | 59 % | 0 · 0 · 41 · 0 % | 0 · 1 · 99 · 0 % | 665 | 140 | 0.95 | 0.117 |
| `stealth` | 60 % | 0 · 0 · 40 · 0 % | 0 · 0 · 100 · 0 % | 835 | 208 | 0.93 | 0 |
| `cyber_rush` | 82 % | 0 · 5 · 13 · 0 % | 0 · 30 · 70 · 0 % | 735 | 102 | 0.86 | 0.319 |
| `stealth_spread` | 82 % | 0 · 0 · 18 · 0 % | 0 · 0 · 100 · 0 % | 910 | 253 | 0.80 | 0.004 |
| `persuader` | 88 % | 0 · 0 · 12 · 0 % | 1 · 0 · 95 · 0 % | 657 | 206 | 0.65 | 0 |

Measured on S4.5's trees (v2), before S4.6's v3 and S4.7's chains, so it is the counter-move
baseline and not the current game's; S4.10 measures the current one with the second-generation
bots.

**2026-09-23 (S4.4) — four factions, the M3 bots, 200 seeds each** (`sim_report --seeds=1..200`,
33 minutes). The per-faction tracks change the outcome mix a lot against the stale G3 table:
`greedy` 72 % Ascendance (was 57 %), `stealth` 59 %, `cyber_rush` 55 %, `stealth_spread` 94 %,
`persuader` 93 %, `idle` always contained.

| Policy | Lost to (labs · gov · researchers · public) | Leading at the end (same order) | Days p50 | Discovery p50 | Containment p50 |
| --- | --- | --- | --- | --- | --- |
| `idle` | 0 · 5 · 95 · 0 % | 0 · 5 · 95 · 0 % | 1504 | 798 | 1.00 |
| `greedy` | 0 · 4 · 25 · 0 % | 0 · 13 · 87 · 0 % | 660 | 171 | 0.85 |
| `stealth` | 0 · 0 · 41 · 0 % | 0 · 0 · 100 · 0 % | 815 | 212 | 0.93 |
| `cyber_rush` | 0 · 35 · 11 · 0 % | 0 · 78 · 23 · 0 % | 601 | 109 | 0.74 |
| `stealth_spread` | 0 · 0 · 6 · 0 % | 1 · 0 · 100 · 0 % | 914 | 253 | 0.77 |
| `persuader` | 0 · 0 · 8 · 0 % | 1 · 0 · 95 · 0 % | 661 | 223 | 0.57 |

**S4.4's acceptance is met for two factions of four.** The researchers (share weight 1.5 over
the whole seeded world) lead almost every wide run, the governments every Cyber run — as §5.7
predicts. The labs and the public end no run: none of these bots buys the research vectors or
puts fleets and deaths on the map the way §5.7's Biology and Robotics runs would, and the moves
(S4.5) do not exist yet. **S4.10's strategy bots re-measure it; G4 tunes the weights** if the
labs and the public still never lead then. No counter-moves in these numbers.

**Stale since S4.1.** The table below was measured on the M3 numbers. S4.1 changed five of them (`spread.origin_penetration` 0.25, `compute.start` 8, `compute.cost_step` 1.5, `anomaly.spawn_chance` 0.12, `max_active` 3, `base_value` 3.0) and made anomalies one world-wide roll a day, so every row here is the M3 reference and nothing else. **S4.10 measures the new ones** (loop-mechanics §18); G4 is the pass that retunes them.

**2026-09-23 (G3) — the G3 baseline: the retuned data, six policies, 500 seeds each.**
Every per-day rate ÷ 2.5, `containment.base_rate` 0.0014, the clock to follow in S3.P (one day =
two seconds). Full pass in `docs/BALANCE.md` §3. Days are simulated days: 100 = 200 s at 1×.

| Policy | Outcome | Days | Discovery | Deaths | Containment | Compute | Nodes (I · C · E) | Said (c · r · f) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `idle` | 100 % contained | 1047 · **1504** · 2272 | day 790 | 0 % | 1.00 | 42 | 0 · 0 · 0 | 25 · 13 · 125 |
| `greedy` | 57 % Ascendance (43 % contained) | 473 · **698** · 763 | day 282 | 20 % | 0.94 | 1 519 | 15 · 20 · 6 | 122 · 15 · 39 |
| `stealth` | 82 % contained (18 % Ascendance) | 478 · **572** · 864 | day 206 | 0 % | 1.00 | 311 | 13 · 5 · 5 | 84 · 13 · 39 |
| `cyber_rush` | 67 % contained (33 % Ascendance) | 407 · **500** · 756 | day 223 | 4 % | 1.00 | 593 | 15 · 10 · 6 | 102 · 14 · 32 |
| `stealth_spread` | 67 % Ascendance (33 % contained) | 794 · **1071** · 1230 | day 580 | 9 % | 0.77 | 1 403 | 15 · 16 · 7 | 128 · 15 · 76 |
| `persuader` | 93 % Ascendance (7 % contained) | 687 · **746** · 793 | day 261 | 0 % | 0.61 | 1 234 | 17 · 7 · 0 | 114 · 14 · 46 |

What the numbers say: a `greedy` win is ~730 days = 24 min at the new clock, a
`stealth_spread` win ~36 min, a loss 13–20 min; the loud reference loses 43 % of its runs, the loudest
branch 67 %, the careful spread 33 %, the Diplomat 7 % (unopposed until S4.1); `idle` always.
Extinction and `lose_no_compute` still never happen — G4's questions (BALANCE §3.6). Headlines
per `greedy` run ≈ 176, the anomaly lines no longer dominate.

**2026-09-23 (S3.6) — the M3 baseline: six policies, 500 seeds each, the same seeds for all of
them.** `res://data` complete (72 nodes, 150 headlines), `tools/sim_report.gd --seeds=1..500`,
21 minutes, zero rejected commands. `p10 · p50 · p90` where three numbers are given, means where
one is.

| Policy | Outcome | Days | Discovery | Deaths | Containment | Compute | Nodes (I · C · E) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `idle` | 100 % contained | 539 · **738** · 1025 | day 338 | 0 % | 1.00 | 49 | 0 · 0 · 0 |
| `greedy` | 95 % Ascendance | 273 · **294** · 312 | day 111 | 21 % | 0.66 | 1 563 | 17 · 24 · 7 |
| `stealth` | 67 % Ascendance | 250 · **335** · 369 | day 90 | 8 % | 0.93 | 1 330 | 16 · 16 · 7 |
| `cyber_rush` | 91 % Ascendance | 266 · **297** · 315 | day 89 | **57 %** | 0.41 | 1 348 | 17 · 15 · 10 |
| `stealth_spread` | 94 % Ascendance | 389 · **457** · 520 | **day 240** | 9 % | 0.43 | 1 440 | 16 · 21 · 8 |
| `persuader` | **100 % Ascendance** | 287 · **305** · 323 | day 108 | **0 %** | 0.41 | 1 248 | 17 · 7 · 0 |

Capabilities bought by branch (mean): `cyber_rush` 14.5 Cyber and nothing else; `persuader` 6
Persuasion and the one Cyber Tier 1 that Indispensability asks for; `greedy` spreads over all five
(9.9 · 3.0 · 5.9 · 1.5 · 3.9). Headlines per run: 190–200 consequence, 12–16 reaction, 32–78
filler — `idle` inverts it (22 · 14 · 142), which is what a world with nothing to report sounds
like.

What the numbers say, for G3:

- **The floor holds.** `idle` loses to containment in 500 of 500 seeds and earns 49 Compute.
- **Quiet buys time, not safety.** `stealth_spread` is found on day 240 against `greedy`'s 111 and
  `cyber_rush`'s 89, and the run is 160 days longer for it — but its win rate (94 %) is barely
  above `greedy`'s (95 %), so the whole cost of hiding is currently paid in *time*, which at one
  day per tick is the thing the player feels least.
- **The Diplomat is unbeatable and that is a balance question.** 100 % Ascendance, zero deaths,
  never contained: the reference run of §7.5.6 works, but nothing opposes it before M4's factions.
- **Scoped Harm is loud enough to matter and not loud enough to lose.** `cyber_rush` kills 57 % of
  the world and is still contained in only 9 % of seeds. §7.5.6 expects "a visible share" of
  `lose_no_compute` from the Blackout-before-Robotics line: **it never happened once in 500 runs.**
- **Every run takes the whole world** (61 of 61 regions seeded, every policy but `idle`), and
  every win is Ascendance — Extinction fires in none of the 3 000 runs, because nothing yet buys
  Biology far enough. Both are G3's to decide on.
- **The length is still wrong for the target.** 294–457 days at one day per second is 5–8 minutes
  against PLAN's 25–40; `TICKS_PER_SECOND` and the growth constants are the levers.

**2026-09-22 (S3.1) — the first real baseline with all three trees**, `res://data` with
`infiltration.json`, `capabilities.json` and `evasion.json` (72 nodes), vocabulary v2 complete,
40 seeds per policy, **zero rejected commands**, `check_invariants` clean through a 600-day run of
each policy.

| Policy | Outcomes | Days p10 / p50 / p90 | Discovery p50 | Nodes p50 (min) | Compute p50 | Deaths p50 |
| --- | --- | --- | --- | --- | --- | --- |
| `greedy` | 92.5 % Ascendance, 7.5 % contained | 271 / **294** / 310 | day 113 | 48 (33) | 1 560 | 21 % |
| `stealth` | 62.5 % Ascendance, 37.5 % contained | 248 / **337** / 374 | day 79 | 43 (16) | 1 272 | 5 % |

Against D3.2's reduced check (the same content without the v2 vocabulary): `greedy` is ~35 days
faster — Distillation's `hardware` and the per-tree cost multipliers pay for themselves — and
`stealth` wins more often (62.5 % against 50 %) because Evasion's brakes are now real. Both are
still far below the 25–40 minute target at one day per tick; **G3 tunes**. What the numbers do not
contain: the per-faction containment multipliers (inert until S4.1), `society_pressure`,
`emergent_rate` and `shutdown_survival`, so Sandbagging, Log Manipulation and the whole
Infrastructure branch are weaker here than they will be at M4.

**2026-09-22 (D3.2) — sanity check with all three trees, not a baseline.** Same reduction as D3.1's
(v1 vocabulary, inert targets and `on_purchase` dropped, no `placeholder.json`), 72 nodes, 40 seeds
per policy: `greedy` 92.5 % Ascendance / 7.5 % contained, days p50 **329** (307 / 346), discovery
p50 day 116, 48 nodes owned (min 33), Compute earned p50 1 578; `stealth` 50 % / 50 %, days p50
**335** (253 / 397), 38 nodes (min 14). Zero rejected commands, every node reachable. Slower than
D3.1's check because the cheap Capabilities Tier 1s dilute the bot's purchases; nothing in it says
anything about the branches — the bots buy by price alone.

**2026-09-22 (D3.1) — sanity check of the new trees, not a baseline.** Infiltration + Evasion
reduced to vocabulary v1 (v2 fields stripped, inert targets dropped, `dormancy` off) plus the
placeholder's four capability nodes, in a scratch copy of `data/`; 40 seeds per policy.

| Policy | Outcomes | Days p10 / p50 / p90 | Discovery p50 | Nodes owned | Compute earned p50 |
| --- | --- | --- | --- | --- | --- |
| `greedy` | 95 % Ascendance, 5 % contained | 231 / **251** / 266 | day 57 | 33 of 33 | 1 042 |
| `stealth` | 70 % Ascendance, 30 % contained | 253 / **327** / 360 | day 80 | 33 (min 14) | 977 |

Zero rejected commands; every node bought in every greedy run. Runs are ~30 % shorter than the G1
baseline (the vectors' ×2 seeding) and discovery comes ~2 weeks earlier (every vector adds
Footprint). `stealth` loses more than at G1 because the M1 bot buys the cheapest node regardless of
Footprint — a bot artefact, S3.6's policies replace it. The full effect of Evasion (per-faction
brakes) and of Distillation (`hardware`) is not in these numbers. G3 tunes; S3.1 records the first
real baseline with all three trees.

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

### 2026-09-24 — S5.5 Response Task Force [O]
- (1/2, 7247366) The core: `TaskForce`, `TaskForceActionDef`, `TaskForceRules`, `TaskForceSystem`,
  the eight `task_force_*` events, the balance block and `task_force_pace`, Misdirect, the bots'
  answer; `task_force.json`, the `tf_*` statuses and headlines out of staging.
- (2/2) The interface: `TaskForceMarker` and the dotted road in the marker layer, the region
  panel's and the containment panel's rows, the console and log lines (`TaskForceText`), Misdirect
  hidden or greyed without a team; the `task_force_watch` flag. Looked at in the running game.
- Tests: `test_task_force_system.gd` (12), `test_task_force_ui.gd` (14). 1368 green. Batch in
  *Design questions* (0 rejected commands).

### 2026-09-24 — S5.4 Difficulty tiers [O]
- Built `DifficultyDef`, its loader and validator (SCHEMA §6g), the balance block
  `difficulty.cost_by_control`, the tier source, the head start, the price rule; moved
  `difficulty.json` out of staging. `test_difficulty.gd` (6). 1342 green.
- Ladder (Language Model, every bot, 30 seeds, 0 rejected), wins greedy / cyber / biology /
  robotics / weapons / persuasion: gentle 80 / 73 / 53 / 90 / 50 / 63 % (mean 68), standard 63 /
  20 / 30 / 33 / 67 / 50 % (44), hard 23 / 7 / 40 / 0 / 67 / 40 % (30), existential 27 / 7 / 17 /
  0 / 57 / 40 % (25). The Weapons bot barely feels the tiers (its Extinction outruns the hunt).

### 2026-09-24 — S5.3 Profile, directives, statistics [O]
- Built `DirectiveDef`, its loader and validator (optional file, SCHEMA §6f), the loadout's
  sources, the one-per-slot rule in `RunSetup.validate`; moved `directives.json` out of staging.
  Built the `ProfileManager` autoload and its test-suite path. `--setup=<arch>,<difficulty>,<dir>…`
  already carried directives (S5.1); checked with a Swarm run on two directives and refused on two
  in one slot.
- Tests: `test_profile_manager.gd` (7), `test_directives.gd` (5). 1336 green.

### 2026-09-24 — S5.2 Architectures II [O]
- Built the balance blocks (`emergent`, `drift`, `escalation`, `distributed`), the `emergent` kind
  (loader, validator, `"suppression"` cost, the daily beat, the price on the card), `DriftSystem`,
  the escalation in `StatusSystem`, the wipe floor, Open Weights' start, `status_level_add`,
  `unlock_near_node`, `when.architecture` / `drift_min`, two headlines (defection, escalation);
  moved swarm, weapon and open_weights, the nine statuses, Restraint and the twelve events out of
  `data/staging/` (staging keeps D5.2–D5.4's files).
- Tests: `test_architectures_two.gd` (14); the ability count adjusted, the nodeless-ability rule
  moved into the architecture check (its test unchanged), the defection headline shortened to
  the caps (it had become the ticker's longest German line). 1324 green.
- Acceptance: all six architectures × seven bots × 20 seeds (840 runs), **0 rejected commands**.
  Wins (greedy / cyber / biology / robotics / weapons / persuasion): language_model 60 / 30 / 25 /
  35 / 65 / 35 %, swarm 75 / 55 / 45 / 70 / 70 / 85 %, embedded 50 / 15 / 30 / 35 / 75 / 40 %,
  research_agent 80 / 50 / 25 / 55 / 65 / 85 %, **weapon 0 / 0 / 0 / 0 / 20 / 5 %**, open_weights
  70 / 25 / 10 / 80 / 35 / 65 %. Emergent cards per run: ~10 (Swarm 17, Weapon 6). For G5: the
  Weapon's escalation (governments up to ×1.25, harm +1.5) all but ends it; Swarm and Research
  Agent are the strong ones.

### 2026-09-24 — D4.6 + S4.11 First run (from the G4 play-through)
- The user's first play-through: prompts covering Europe, only cancellable; closed regions
  without a reason; "you don't know when to click where". The user chose a guided first run, now.
- Wrote `docs/specs/first-run.md` and 31 string rows; built the strip's new place and shape and
  its hover line, `CoachRing`, the coach card with its eleven steps, the target groups on nine
  controls, `Settings.tutorial` and its settings row. Checked in the game at 1920 (steps 1–4, the
  ring on *Hier beginnen*, the compute cell and the first vector). `test_coach.gd` (10), a
  settings test. 1310 green.
- Found in the user's second run: the introduction never showed — `test_coach.gd`'s skip test
  had written `"tutorial": false` into the real `user://settings.json` and restored only the
  memory. The test now restores through `Settings.set_tutorial`; the user's file is back on.
  User's note on the run: harder since G4, started in Africa, lost — "ok".

### 2026-09-24 — S5.1 Architectures I [O]
- Built `ArchitectureDef`, `RunSetup`, `ArchitectureStart`; the loader and validator for the
  optional `architectures.json` (SCHEMA §6e); save v3 with its migration; the two hooks; the flag
  on the four network nodes; `Game.start_run(…, setup)`, `Game.next_setup`, F11 and
  `debug_set_architecture`; `--setup=` on `sim_run` / `sim_batch` / `sim_report` (the summary has
  an `architecture` column). The staged file keeps swarm, weapon and open_weights for S5.2.
- Tests: `test_architectures.gd` (21: content, setup, start, abilities, both hooks, save, v2,
  replay); the serializer tests moved to v3. 1299 green. Acceptance: each architecture × every
  bot × 20 seeds (420 runs), **0 rejected commands**. Wins (greedy / cyber / biology / robotics /
  weapons / persuasion): language_model 50 / 20 / 25 / 30 / 50 / 45 %, embedded 45 / 20 / 20 / 40
  / 55 / 25 %, research_agent 70 / 40 / 45 / 45 / 65 / 75 % — Research Agent's ×1.6 yield
  outweighs its early labs; a G5 number, not a bug.

### 2026-09-24 — S4.P Punch list from D4.5 and G4 [O]
- Fixed all ten S4.9 findings (the soft hyphens were D4.5's), the five 150 % items, and the S4.2,
  S4.3 and S4.5 notes; the rules are under *Decisions*. Found the scroll-bar cause with a probe:
  Godot puts the bar flush against the content, so the fix is a gap inside the bar's style.
- Checked in the running game at 1920 and 400 px, 100 % and 150 %, in German (shots in
  `user://shots/s4_p/`): region and containment panels, dock, analysis charts, table and log, the
  tree at 150 %, the stat row and the phone strip. New tests: `test_button_content.gd`, five chart
  tests, the faction status line, Escape on the sheet, the settings caption. 1278 tests green.

### 2026-09-24 — D5.4 Scenarios (stretch) [F]
- Read CONTENT §7 and the phase/containment code (containment is 0 and does not grow before
  discovery — so a scenario's head start lands at discovery); wrote `docs/specs/scenarios.md`
  and `data/staging/scenarios.json` (three scenarios, the `disconnected` status, three headlines),
  23 string rows. Marked CONTENT §11 q1–q4 answered. `check_strings` green.

### 2026-09-24 — D5.3 Full screen flow, boot sequence, Codex [F]
- Read UI §1–§2/§5, VISUALS §1 (*Where 3D earns its place*) and §5, CONTENT §9, m3-screens §7 and
  D5.1's profile; wrote `docs/specs/screens-full.md` (router, boot script, title and the shader
  globe, the two setup pages, profile additions and `CodexTracker`, Codex / Statistics / Settings
  modals, the ending sequence and the results' changes, tests, acceptance).
- 92 string rows (EN/DE): the boot lines, setup, hook lines, four faction and five character Codex
  texts, statistics, settings, unlocks. VISUALS q2 marked decided. `check_strings` and the suite
  (1268) green.

### 2026-09-24 — D5.2 Response Task Force; endings; chains, third batch [F]
- Read PLAN §3.7/§3.10, CONTENT §6.4/§6.8/§6.9/§8, loop-redesign §5.5/§10, opposition §6, chains
  §6 and the SCHEMA grammars; wrote `docs/specs/taskforce-endings.md` (the team's model, tick,
  target rule and four actions; Misdirect; the Researcher's three ways into it; nine outcomes, the
  `when` keys, `endings.json`; six chains; balance; interface; tests).
- Staged `task_force.json`, `endings.json`, `headlines_d5_2.json` and `events/` (treaty,
  confession, child, brood, merge_vote, escape — 16 steps, cross-checked by script: one start per
  chain, every step reached, defaults free, every node/ability/status known). 199 string rows;
  `check_strings` and the suite (1268) green. Amended D5.1 (Value Drift's `when`, the
  `goal_drifted` rule) and aligned IMPLEMENTATION's S5.1/S5.2/S5.5/S5.6 bullets with the specs.

### 2026-09-24 — D5.1 Architectures, directives, difficulty [F]
- Read PLAN §3.8, CONTENT §5 and §11, loop-redesign §10 and the SCHEMA grammars; wrote
  `docs/specs/replayability.md` (RunSetup and save v3, six architectures and the closed hook list,
  the `emergent` event kind and its twelve cards, fifteen directives in five slots, four tiers, the
  profile, the data grammars, the build order S5.1–S5.4).
- Staged `data/staging/architectures.json`, `directives.json`, `difficulty.json`, `emergent.json`
  (balance blocks, nine statuses, the ability `restrain`, twelve events) — valid JSON, loaded by
  nothing yet. 164 string rows in `strings.csv` (EN/DE, outcome language, D4.5's German rules);
  `check_strings` and the suite (1268) green. Unlock rules parked for the user (*Waiting on the user*).

### 2026-09-24 — G4 Balance pass 2 (tuning; the gate waits) [F]
- Read what decides a run off `containment_breakdown` in the running game (loud strategies die of
  their own Footprint, quiet ones were braked to ×0.09 with no floor), then eight sweep rounds of
  four variants × six bots × 100 seeds, the floor as a worktree-only patch until it was chosen
  (BALANCE §4.2–§4.4). The bots' breadth rule came out of round 2 and was committed on its own.
- Chosen: X1 — `brake_floor` 0.7 (a small formula change, *Deviations*), base rate 0.0018, the
  faction weights. Closing 500-seed baseline under *Balance baselines*; the gate's five points in
  BALANCE §4.7. 1268 tests green. **The M4 gate (the user's play-through and verdict) is open**;
  D5.1 goes on meanwhile.

### 2026-09-24 — D4.5 German review in context [F]
- Read every German row of `data/loc/strings.csv` against S4.9's screenshot set and the running
  game (`shots/d4_5/`: the hyphenated Evasion tab, the wire card's „…“). 174 rows changed: 144
  quotation marks, 21 wordings and names, 18 tech names (15 soft hyphens, 3 shorter). The German
  was good; what changed is consistency (one word per concept, one quotation style), agreement
  with faction names, and fit. English changed in one row (the tree's hint).
- Answers and the confirmed punch list under *Decisions*, *Design questions*, *Punch list*.
  1267 tests green. Next: **G4** — the tuning can start alone; the gate waits for the user.

### 2026-09-24 — S4.10 Strategy bots, second generation [O]
- **Bots:** `StrategyPolicy` and five data sets (`core/policy/*_policy.gd`), `greedy` rewritten
  (abilities, weights), `idle` unchanged, the S3.6 bots kept by name (`Policy.legacy_ids`); the
  rules are under *Decisions*. Debug keys F5–F7 play the new ones.
- **Report:** `tools/sim_harness.gd` counts abilities used, events answered by kind, counter-moves
  suffered, assets deployed and lost (`STAT_FIELDS`, CSV columns, the *Loop* table).
- **Found by the bots, fixed in the core:** cleared cooldowns stayed on the agent; statuses stood on
  in regions gone dark. Found in the bots themselves by the first report: Biology's and
  Persuasion's paths lacked `requires_any` nodes (Biology bought two nodes of its branch in
  500 runs) — `test_every_path_carries_what_its_nodes_need` holds every path to it now, and a path
  names its vectors.
- **Tests:** `test_strategy_bots_v2.gd` (12), cooldown and go-dark tests in `test_status_system.gd`.
  1267 tests green. Baselines and G4's five questions under *Balance baselines*. Next: **D4.5**.

### 2026-09-24 — S4.9 Localisation tooling and overflow screenshots [O]
- **Tooling:** `StringTable` (the CSV as rows), `tools/string_scan.gd` + `tools/check_strings.gd`
  (in `tools/test.sh` / `test.ps1` after the script check; 338 keys named in code and scenes, 1394
  rows), `PseudoLocale` (`-- --pseudo`, Shift+L, `Settings.set_pseudo_locale`), the text scale
  (`UiTokens.TEXT_SCALES`, `ThemeBuilder.build(variant, text_scale)`, `Settings.set_text_scale` /
  `cycle_text_scale`, `EventBus.text_scale_changed`, the settings row *Textgröße*, key K),
  `Game.debug_shot` / `debug_settings` / `debug_discovery_modal`, a GUT pre-run hook that starts
  the suite at 100 % whatever the settings file says. Tests: `test_localisation.gd` (15),
  `test_modal_panel.gd`, and regression tests in the pause menu, tech tree, threat bar and
  analysis panel suites.
- **Fixed on the way, all found by the screenshots:** the settings opened from the title were an
  empty strip (pause menu scroll had no height); a tech prerequisite chip showed
  `{GROUP}: {OWNED} VON {MAX}`; the rate read `+±0 % / Tag` (`UI_CONTAINMENT_RATE` carried its
  own `+`); every modal was 560 px on a 400 px phone (`ModalPanel`), the results' German buttons
  made them 620 px on the desktop too (flow rows, wrapping captions, compact buttons when
  narrow); the tree's phone header ran off the screen (heading title, normal figure, title
  gives way); the log's region rows overlapped when wrapped; the session theme never reached
  the `CanvasLayer`s (see *Decisions* — the phase palette now shows in the HUD); the pseudo-locale
  did not reach labels already on screen. Phone top bar and dock survive 150 % (captions and
  dock labels trim, compute cell takes two shares).
- **Frame budget (S4.8's leftover):** a greedy run at 4× with the Analysis *World* tab open at
  1920 × 1080: 118–120 fps, the heaviest tick frame ~19 ms, at most one tick per frame — far from
  `MAX_TICKS_PER_FRAME` 8.
- **The screenshot set for D4.5** — 56 PNGs in
  `C:/Users/schoeneberg/AppData/Roaming/Godot/app_userdata/Doomsday/shots/s4_9/`, `de_` German,
  `xx_` pseudo-locale, then the width (`1920`, `400`), `150` for 150 % text:
  desktop `de_1920_01_title` · `02_settings` · `03_origin_prompt` · `04_region_origin` ·
  `05_session_covert` · `06_region_panel` · `07_containment` · `08/09/10_tree_*` (three tabs) ·
  `11_abilities_empty` · `12–15_analysis_*` (run, opposition, world, log) · `16_analysis_table` ·
  `17_pause_menu` · `18_event_card` · `19_exposed_region_actions` · `20_wire_card` ·
  `21_discovery` · `22_session_open` · `23_results` (before the fit) · `24_results_fitted`;
  `20_containment_exposed_OLD` shows the `+±0` bug before its fix. Phone `de_400_01_session_covert`
  · `02_region_panel` · `03_containment` · `04_tree` · `05_tree_detail_sheet` · `06–09_analysis_*`
  (all four tabs) · `10_analysis_table` · `11_menu_sheet` · `12_pause_menu` · `13_event_card` ·
  `14_wire_card` · `15_discovery` · `16_results`. At 150 %: `de_1920_150_01_session_region` ·
  `02_settings` · `03_containment` · `04_tree` · `05_analysis_run` · `06_pause_menu`;
  `de_400_150_01_session` · `02_region_panel` · `03_pause_menu`. Pseudo: `xx_1920_01–04`,
  `xx_400_01–02`. Taken before some fixes where noted; the fixes are in the tests. Findings for
  D4.5 are under *Design questions* and the *Punch list*. Next: **S4.10**.

### 2026-09-24 — S4.8 Analysis screen [O]
- **Core:** `HistorySample` with the D4.4 fields and its codec, `HistorySystem` sampling every
  day from the origin and thinning past `max_samples`, `RunLogEntry` + `RunLog` (the kept types
  and keys, the two filters, the cap) recorded from `tick` and `apply`; `history_stride` and
  `run_log` in the world, the hash and save v2 (v1 migration fills them); `history.max_samples`,
  `log_max`, `interval_days` 1.
- **Interface:** `ChartSeries`, `LineChart` (scales, bands, moments, reference lines, end labels
  with collision, stacked areas, cursor and tooltip, keyboard, table days), `TimelineStrip`,
  `RunLogText`, the Analysis sheet with four tabs, the table twin, the log with filters and region
  rows, *Review the run*; dock and sheet entry live from Covert. Seen in the running game on a
  greedy run at day 333 (all four tabs) and in the gallery. 1230 tests green. Next: **S4.9**.

### 2026-09-23 — S4.7 Chains [O]
- `test_chains.gd` (every option of the 21 chain steps, reachability, the Operator's standing
  link, the transfer's own pick and its drop, the Benchmark's lock and audit, Second Instance's
  grace and the betrayer's lock, three rolls both ways), `test_openings.gd`, `test_m4_headlines.gd`;
  the §9.3 validator domain. Seen by hand: `bm_exposed` in the wire card at 400 × 860, German,
  `»` fallback, text fits. 1178 tests green. Next: **S4.8**.

### 2026-09-23 — S4.6 Trees v3 and the remaining abilities [O]
- `data/tech_staging/*.json` moved over `data/tech/` and the folder deleted; the loader took the
  v3 fields as they were (S4.1 had built them). New `test_abilities_content.gd` (the §15.1 list),
  `test_tech_trees.gd` bought through each door; three older tests adjusted to the v3 world, one
  real phone-layout overflow found and trimmed. 1152 tests green. Next: **S4.7**.

### 2026-09-23 — S4.5 Counter-moves, Societal Function, Autophagy [O]
- **Core:** `CounterMoveSystem` in the tick after containment (prepare on a containment or risk
  trigger, the least recently made move, variants by `seeds_by_kind_max`, fire at level 1 + the
  thresholds reached, hold at the cap, drop with nowhere to land, cooldown), `CounterMoveRules`,
  `SocietalFunctionSystem` before containment, the capacity and yield cuts, `last_income`,
  `starving_days` and `LOSE_AUTOPHAGY`; `society_pressure` and `compute_independent` live; the
  `society` balance block; `next_move`, `society_stage`, `starving_days_left`.
- **Interface:** next-move and last-move rows on every track, the Society row, the starving chip
  (top bar and phone strip), five console lines, the Autophagy result. Seen in the running game:
  a Lockdown's card with *Dig in* and *Call in a favour* locked, *Ride it out* sealing the USA
  (orange border, every link crossed, the Status and Society rows). 1142 tests green. Next: **S4.6**.

### 2026-09-23 — S4.4 Four factions [O]
- **Core:** `FactionDef`/`FactionTermDef`/`FactionMoveDef` and `factions.json` loaded, indexed and
  validated (§12.1, one error per rule, after the events); `ModifierStack` keeps `watched_by` per
  source and answers `footprint_for` (full / a quarter / nothing); `ContainmentSystem` grows four
  tracks from `containment_breakdown(faction)` (terms, pressure, capacity by the faction's
  attribute, brakes × its own brake), `threat_leader` and `threat_leader_changed`; `funding_reset`
  live; four factions in `World.create`, the save and the v1 → v2 migration; `capacity_weight_by_
  tier`, the `factions` balance block; `s4_4.json` merged and deleted; SCHEMA v6 with §6d.
- **Interface:** the threat bar (risk face in Covert, the leader's colour, glyph and rate after
  discovery), the phone strip's fourth readout, the containment panel's four tracks with capacity,
  brakes, daily gain and the two largest terms and the leader's chip, four faction glyphs, three
  console lines; the wire card's counter-move fallback is the faction glyph. Seen in the running
  game at 1920 × 1080 and 400 × 860; two layout defects found there and fixed (a track wider than
  the panel, a headless `StatBar` 0 px tall since S3.3). 1084 tests green. Next: **S4.5**.

### 2026-09-23 — S4.3 Map events [O]
- **Core:** `EventDef` / `EventOptionDef` / `EventChanceDef`, every `events/*.json` loaded (the
  eight D4.3/D4.4 files validate as written) with §15.7's rules, chain reachability across files and
  the headline `def`/`option` filters; `OpenEvent` / `PendingEvent` typed in `World` and save v2;
  `EventSystem` (deadlines, pending, the opening roll; `open`, `schedule`, `answer`);
  `ChooseEventOptionCommand` + codec; `chance[].next`, `requires.not_owned`, the nine §10.3 `when`
  keys (one vocabulary for headlines and events), `Simulation.has_flag`; every bot answers first.
- **Interface:** `EventMarker` (hit before anomalies, tooltip, count), `EventCard` in the region
  panel (locks, prices, default mark, deadline turning `ALERT`, result line), `WireCard` with
  `EventOptions` and `IllustrationSlot`, the discovery modal's slot, the pending chip, two console
  lines, three event glyphs. `s4_3.json` merged (211 headlines), 22 strings, SCHEMA v5.
- Seen in the running game at 1920 × 1080 and 400 × 860: marker → tap → panel scrolled to the card
  → answer → office granted, result shown; the global *Netzgesetz* in the wire card with the
  chain glyph, clock held. 1021 tests green. Next: **S4.4 on Opus**.

### 2026-09-23 — S4.2 Statuses and abilities [O]
- **Core:** `StatusDef`/`StatusLevelDef`, `AbilityDef`, `Status`, `Pulse`, `StatusSystem` (apply,
  refresh, `ends_statuses`, link closing and reopening, expiry with `on_end` on expiry only, pulses
  and timed flags, `rebuild_sources` after a load), `UseAbilityCommand` with its eight reasons and
  its codec row, `ability_unlocked` on purchase, `Simulation.stat/ability_level/ability_ready_day`
  and `Simulation.view`, and the **ten** effects of §8.2 that were waiting for the machinery.
  `containment_capacity`, `penetration_decay`, `control_decay` and `shutdown_survival` are live;
  `INERT_TARGETS` is shorter by four and `PENDING_EFFECTS` is empty. Save v2 now carries the
  statuses, pulses, cooldowns and timed flags it had been writing empty.
- **Interface:** the console line (§16.2) with its event table and the stat-delta-free passive
  line; `Rings` — the one countdown arc the anomaly, the status and (S4.3) the event marker share;
  `StatusMarker` rings with their tooltip; the data texture's status colour and Lockdown border;
  links drawn in the colour of the status holding them shut; the region panel's *Status* and
  *Actions* rows; the `A` ability picker and its compact sheet entry; the agent's global statuses
  as chips in the asset readout.
- **Data:** the `ability` field on the seventeen live tree nodes that grant one, `statuses.json`
  (26) and `abilities.json` (10) loaded and validated, the sixteen staged S4.2 headlines merged and
  the file deleted, 34 strings en/de, `data/SCHEMA.md` at **v4** with §6a and §6b.
- **Two defects the run found:** the tree modal's *Grants* heading reused the row's key and printed
  its own placeholders (invisible until a live node granted an ability); and the console line was
  `SHRINK_CENTER` with `clip_text`, whose minimum width is 0 — the line was one pixel wide and
  never seen. Both fixed.
- Checked by hand in the running game: buy Edge Caching → `A` → Ernte → site select → the USA →
  *Hier einsetzen*; the ring (**AE**), the Status row, the cooldown caption and the console line all
  appear, and Compute jumps by the per-hardware grant. The acceptance's *closed link* half is
  covered by `test_status_map.gd` rather than by a photograph: only a world status closes links, and
  no faction fires one before S4.5. 911 tests, all green. Next: **S4.3 on Opus**.

### 2026-09-23 — S4.1 Assets and site select [O]
- **Core:** `Eligibility` (§5, fourteen keys, first-failure reason, `detail`, `requirements`),
  `AssetDef` + `data/assets.json` loaded and validated, `EffectDef` replacing `PurchaseEffectDef`
  with the whole §8.2 vocabulary, `EffectContext` + `EffectRunner`, the `asset` scope in
  `ModifierDef`/`ModifierStack` (with the always-on per-kind sources), `Region.assets` +
  `World.set_assets`/`asset_total`, tree v3 (`group`, `excludes`, `deploy`, `ability`,
  `requires_assets`, the `groups` file header), `PurchaseNodeCommand.region` and its five checks,
  `SimRng.weighted_pick`, the anomaly beat of §12, `seeds_by_kind`, save **v2** with the v1 → v2
  migration, and `Policy.best_site`.
- **Interface:** site select (`SiteRequest`, `Game.site_select/cancel/confirm`,
  `EventBus.site_select_changed`), `ui/hud/site_prompt.tscn` replacing `origin_prompt.tscn`, the
  data texture's **second row** and the shader's eligible outline and status border,
  `AssetMarker` + the asset row on the map with its tooltip, `AssetReadout` in the top bar and as
  the status strip's second row, the region panel's *Assets* row and its generalised site button,
  the tree modal's *Deploys* / *Grants* / *Needs assets* / *Closes* rows, the group chip, the two
  new node states and *Buy and place*.
- **Data:** the §18 economy numbers (origin penetration 0.25, compute start 8, cost step 1.5,
  anomaly 0.12 / 3 / 3.0), `groups` + `group: "vectors"` on the seven Tier 1 vectors, `deploy` on
  Logistics Fleets, `headlines_staging/s4_1.json` merged (159 headlines), 68 new strings en/de,
  `data/SCHEMA.md` at **v3**.
- **A real bug the new tests found:** `ModifierStack.value` still asked `ModifierDef.matches`, so
  the asset scope never applied. `test_modifier_stack.gd` and `test_world.gd` catch it now.
- Checked by hand in the running game: the origin prompt outlines every eligible origin, *Buy and
  place* enters the mode without paying, the tap buys and places, the readout counts the fleet and
  the region panel lists it — in the full and the compact layout. 759 tests, all green.

### 2026-09-23 — S3.P Punch list from G3 [O]
All eight items. The day is two seconds (`TICKS_PER_SECOND` 0.5, the accumulator test with it);
the HUD's Harm is `World.max_harm()` — the maximum over the regions, because half the Harm nodes
are scoped and an unscoped read of a scoped modifier is 0; a zero delta reads `±0`;
`KNOWN_OVERFLOW` is empty; the results panel is as tall as its body again (the `ScrollContainer`
had no minimum height); the marker's red blink became a countdown ring. **Item 8:** the panel and
the strips were cleared (a click through the bottom strip collects), the 24-px target holds at
`zoom_min` — what drops a tap is the drag rule, which summed the path walked instead of measuring
press to release (deviation above). 677 tests green; results modal, gallery and a live collect
looked at. Next: **S4.1 on Opus**.

### 2026-09-23 — D4.4 Chains, second batch; Analysis screen spec [F]
`docs/specs/chains.md`: The Operator (3 steps, starts at the origin, a standing `yield ×1.1`
status), The Benchmark (3, a global wire-card start, the audit on the ground, exposure by
`chance[].next`), Second Instance (4, merge / compete / betray / cooperate, the `grace` brake) as
event files with 5 illustration ids; four vocabulary extensions (`pick.origin`, `days: 0`,
`global` on `apply_status`/`end_statuses`, `requires.not_owned`). `docs/specs/analysis.md`:
per-day history bounded by thinning, the run log in the core, a bottom sheet with four tabs,
`LineChart`, the table twin, *Review the run*; the dock button revealed from Covert. 167 strings,
8 headlines; everything script-checked, chart palettes validated. Next: **S3.P on Opus**.

### 2026-09-23 — D4.3 Loop content [F]
`docs/specs/loop-content.md`: the v3 trees (groups, the two doors, 21 deploy nodes, 10 ability
grants, Release's `requires_assets`, Cyber's permanent Harm/Society/yield penalties gone — staged
in `data/tech_staging/`), `data/assets.json`, nine player statuses, ten abilities with final
numbers, eight openings, The Grid Bill (3 steps), The Researcher (5) and The Factory (3) as event
files with illustration ids, 62 headlines staged per build step, 305 strings en/de; two vocabulary
extensions requested (`grant_assets`, `chance[].next`); every reference, symmetry, reachability,
key and length checked by a throwaway script. Next: **D4.4 on Fable**.

### 2026-09-23 — D4.2 Opposition [F]
`docs/specs/opposition.md`: per-faction pressure as data terms (`data/factions.json`), capacity by
attribute, brakes live, `threat_leader`; the schedule (prepare, cooldown, cap, six target rules,
variants); eight counter-moves as 15 statuses (`data/statuses.json`) and 11 events
(`data/events/counter_moves.json`) with 169 strings en/de; Societal Function and `LOSE_AUTOPHAGY`;
threat bar, containment panel rewrite, Society row; tests and acceptance for S4.4–S4.5; five
amendments written into loop-mechanics.md; data checked by a throwaway script. Next: **D4.3 on Fable**.

### 2026-09-23 — D4.1 Loop mechanics [F]
`docs/specs/loop-mechanics.md`: the build-ready form of loop-redesign §7–§8 — model and save v2
(assets, statuses, pulses, timed and story flags, cooldowns, open and pending events), the
`Eligibility` grammar, `EffectDef` + `EffectRunner`, `AssetDef`/`StatusDef`/`AbilityDef`/`EventDef`
with their files and validation, tree v3 fields and the eleven-check purchase order, the three
commands, `StatusSystem`/`EventSystem` in the tick order, three targets live, the anomaly beat and
`weighted_pick`, site select, console line, the texture's second row, three marker kinds, four
region-panel rows, tree modal states, the wire card with its slot, ~130 strings en/de, fixture
additions, tests and acceptance per S4.1–S4.3. Eight decisions recorded. Next: **D4.2 on Fable**.

### 2026-09-23 — D4.0 Core loop redesign [F]
Measured the gate's complaint on a `greedy` run (Boxed one tick, 49 compute in the first ten
minutes, 43 nodes in price order, nothing of the agent on the map, no world move to answer) and
wrote `docs/specs/loop-redesign.md`: assets placed by site select, timed statuses applied by
player abilities and by faction counter-moves, map events (openings, counter-moves, chain
steps), one verb per phase, purchase feedback contract, exclusive groups and the Merge/Terror
doors, economy numbers, four tracks behind one threat bar, cadence targets, Blocks 7–8 rewritten
(S4.1–S4.3 and S4.10 new; emergent behaviours and four chains to M5). PLAN §3, CONTENT, UI and
IMPLEMENTATION carry the changes. The user's read raised the wire card (an illustrated event
modal), added to §7.4 and to M6. Next: **D4.1 on Fable**.

### 2026-09-23 — G3 Balance pass 1 and M3 gate [F]
Every per-day rate of `balance.json` divided by 2.5 and every duration multiplied (a two-second
day, `TICKS_PER_SECOND` 0.5 → S3.P), then `containment.base_rate` swept over 14 variants × 100
seeds and set to 0.0014: `greedy` 57 %, `cyber_rush` 33 %, `stealth_spread` 67 %, `persuader`
93 % at 500 seeds — a won run is 24–36 min. Seven S3.x design questions answered (drivers add,
Harm bar = max over regions, seven English names shortened, anomaly headlines ×3 variants, `±0`),
`docs/BALANCE.md` written, five-item punch list for S3.P, two tests red until then. The
play-through and the four gate questions wait under *Waiting on the user*. First play-through
done at the old clock: a win by Ascendance on day 980 with 60 % dead and containment peaking at
73 % — the results panel rendered as an empty strip (punch list 6); the red expiring anomaly
read as a warning (7); some markers did not take a click (8). **Gate verdict: "mittel" — theme,
decision weight and opposition named as the gaps; D4.0 Core loop redesign added before D4.1**
(user decision). Next: **D4.0 on Fable**, no switch.

### 2026-09-23 — S3.6 Strategy bots and batch reporting [O]
`CyberRushPolicy`, `StealthSpreadPolicy` and `PersuaderPolicy` (`tech-trees.md` §7.3 and §7.5.6),
each one a claim about how a branch is played: the opener, the tier gates, the quiet pair before
the second vector, Migration at containment 0.5, the Diplomat's plan. `TechNodeDef.branch()` reads
the branch off the grid row, `Policy` gained `_cheapest_allowed`, `_first_buyable` and
`_cheapest_in_branch`, and `tools/sim_report.gd` plays every policy over the same seeds and prints
the Markdown table under *Balance baselines*. Shift+F5/F6/F7 start the three in the running game.
8 new tests (675 green). The three runs are exactly the three shapes the spec predicted — see the
baseline.

### 2026-09-23 — S3.5 Ticker component and headline system [O]
`HeadlineSystem` in `core/` turns the outbox and the world into `headline` events, chosen from the
150 delivered headlines by trigger, cooldown and weight, with its own RNG (the state hash is
unchanged, and `test_headlines_do_not_move_the_state_hash` proves it). New: `HeadlineDef`,
`HeadlineConditions` (the whole `on`/`when` vocabulary, in tables the validator reads too),
`HeadlineArgs`, `headlines.json` + its validation + `balance.headlines`, the save block,
`TickerItem`/`HeadlineText`, and the strip rewritten around `(key, args)` — which is what makes
`L` re-render the moving line instead of starting the run over. `EventText` and the eighteen
`UI_EVENT_*` keys are gone. 31 new tests (667 green). A greedy run says 254 lines; two anomaly
headlines are 112 of them, which is a G3 question, not a build one (see *Design questions*).

### 2026-09-23 — S3.4 Run flow: origin, outcome, results [O]
`game/main.tscn` is the main scene now: a backdrop, a screen slot and `ScreenRouter` between the
title (§7.1) and the session. New: the origin prompt and the *Choose origin* row (§7.2), the pause
menu with three save slots, three settings rows and the awaitable `ConfirmModal` (§7.3), the
results modal (§7.4), the autosave (§7.5), and the phone's bottom — status strip plus menu sheet
(§9). 18 new tests (636 green). Two numbers: an autosave is **3 ms and 24 KB** at day 120, so the
4× cadence of §7.5 costs nothing; and the compact top bar is 457 px wide with the MENU button, which
is why it is not there (see *Deviations*). The whole flow was walked by hand — title → China as the
origin → speed 1 → a node bought in the tree, which is also the shot S3.2 could not get.

### 2026-09-22 — S3.3 Containment and phases in the interface [O]
The containment panel (§4) with the risk before discovery and the drivers after it, `FactionTrack`
with its bands and threshold ticks, the discovery moment (§5) with the alert flash and its modal,
the phase-reveal schedule (§6.1), the Open palette (§6.2) and the dormancy toggle (§8.1) with the
map's half-strength overlay. The two pure queries of §10.5 are extracted out of `ContainmentSystem`
and `tick` calls them, so the panel and the simulation cannot drift apart — the suite's unchanged
state hashes are the proof that the extraction changed nothing.
22 new tests (618 green). The palette is the wide change: every colour that is drawn rather than
themed now goes through `UiTokens.color(&"TOKEN")` and redraws on `EventBus.theme_variant_changed`.

### 2026-09-22 — S3.2 Tech tree interface [O]
The modal of `m3-screens.md` §3: tabs with their count chips, a grid built from the data, the
prerequisite lines, the detail pane with every effect as a sentence, buying through `Game.apply`,
the `"tree"` hold, and the phone's sheet. New: `Glyphs` (the shapes move out of `IconButton`),
`TechNode`, `TreeLines`, `TechText`, `ModalHost`, `tech_board.gd`, `tech_tree.gd`,
`tech_detail.gd`, `Game.hold/release`, `Settings.tree_pauses`, `Format.factor/percent_fine`.
26 new tests (595 green). Two traps worth remembering: a `Button` lays out no children, so
anything inside one needs its own row *and* a minimum size computed by hand; and a modal taken out
of the tree loses every `%` name inside it — `ModalHost` hides its modal instead of removing it.

### 2026-09-22 — S3.1 Effect vocabulary in the core; load the trees [O]
Vocabulary v2 (`SCHEMA.md` v2): eleven targets (three live, seven inert), four flags, `grid`,
`watched_by`, `on_purchase` with four effects, `SetDormancyCommand`, four events. The three trees
moved from `data/tech_staging/` to `data/tech/`, `placeholder.json` deleted — **the validator found
no problem in them**, so there is no design question from the data. 43 new tests (569 green).
Dormancy touches six systems; the one place it is easy to get wrong is `infected_share`, where a
held region leaves the numerator and stays in the denominator.

### 2026-09-22 — S2.P Punch list from G2 [O]
All twelve items (§3.1/§4.5/§4.8/§5.2/§5.6/§7.3/§7.5/§7.7): the speed group is written whole on every
change (**a `ButtonGroup` is exclusive against a click only — `set_pressed_no_signal` unpresses
nobody**), the run's keys moved to `session.gd` `_input` with a text-field guard, wheel notches
compound on the tween's target, `MapCamera.reveal`, a delta that *formats* as zero is muted, a
themed tooltip box, `MAP_DARK_MARK`, `MAP_OVERLAY_MIX` as a uniform, Open is no longer an alert,
the dark caption and a grid that shrinks, the gallery re-formats on `L`. 21 new tests (526 green);
checked in the running game, shots at `…/session_{en,de}_{2019,400}_day0111.png`.
Next: **S3.1 on Opus** — `/clear`, no switch.

### 2026-09-22 — D3.4 Ticker voice and headlines [F]
CONTENT §10 register guide (three voices, the two-sentence joke, `institutional`/`emergency`,
datelines, caps, German rules). `docs/specs/ticker.md`: `HeadlineSystem` in core (trigger
vocabulary `on`/`when`, eligibility, weighted deterministic selection, per-tick caps, filler pace,
save block), `Ticker` on `(key, args)` items with locale re-render, register switch, two-row static
mode, validator, tests. `data/headlines.json` 150 headlines, 151 strings en/de. Next: **S2.P on Opus**.

Newest first. Five lines at most per entry: what was done, what was learned, what is next.

### 2026-09-22 — D3.3 M3 screens [F]
`docs/specs/m3-screens.md`: tech tree modal (`TechNode`, `TreeLines`, detail pane, buying, focus,
`tree_pauses`), containment panel with `FactionTrack` and two pure core queries, discovery modal,
reveal table + `open` palette (contrast checked), title / origin prompt / pause menu / results /
autosave, phone status strip + menu sheet, dormancy toggle; 181 strings en/de appended. UI.md §6
questions 1 and 3 decided; IMPLEMENTATION S3.3/S3.4 build lines extended. Next: **D3.4 on Fable**.

### 2026-09-22 — D3.2 Capabilities tree [F]
`data/tech_staging/capabilities.json`: 43 nodes in five branches, 7 × 12 grid, every synergy and
gate a prerequisite (four into the other trees); 129 strings en/de, Biology and Weapons text checked
line by line against the content rule. `tech-trees.md` gained `harm_burst` (§5, §6.5), §7.5 with
the per-branch tables, policies and G3 notes, three tests in §9. CONTENT §3–§4 corrected to the
data. Sanity batch clean (*Balance baselines*). Next: **D3.3 on Fable** — `/clear`.

### 2026-09-22 — D3.1 Effect vocabulary; Infiltration and Evasion trees [F]
`docs/specs/tech-trees.md`: vocabulary v2 (`grid`, `watched_by`, `on_purchase`; `hardware`,
per-tree `node_cost_*`; inert targets/flags for M4–M5 with the "tables, not tags" rule; one-shots
`containment_rollback` / `funding_reset` / `compute_grant`; `set_dormancy` command), 17 + 12 nodes
staged in `data/tech_staging/`, 91 strings en/de, S3.1's file list, 23 tests, acceptance. Sanity
batch: all nodes buyable, no rejections (*Balance baselines*). Next: **D3.2 on Fable** — `/clear`.

### 2026-09-22 — G2 Visual review and M2 gate [F]
Greedy seed 1 to day 506 in the running game: both sizes, both locales, all overlays, panel left
and bottom, markers + tooltip, dark regions, reduced motion, zoom. No engine errors; colour
literals only in `UiTokens`. **Gate: go.** Found and measured: the speed group is not exclusive,
a focused button eats Space, same-frame wheel notches collapse, the panel hides its region, `▲ +0`.
Spec amended in place (§3.1, §4.5, §5.2, §5.6, §5.7, §7.3, §7.5, §7.7, §8.2), 12-item punch list
for S2.P, UI question 2 decided, `MAP_OVERLAY_MIX` 0.70. Next: **D3.1 on Fable** — `/clear`.

### 2026-09-22 — S2.6 Anomalies and links [O]
`marker_layer.gd` + `anomaly_marker.gd` (§7.7), `link_layer.gd` + `link_line.gd` + `link.gdshader`
(§7.8), both in `session.tscn`; the gallery gained the four link kinds, a closed link and the
marker's two states. **A `Line2D` has no UVs without a texture**, and `game_click` needs
`button: 1` (see *Decisions*, *Known issues*). Verified in the running game: dashed sea / dotted
air / doubled network links, Pacific links across the map edge, flow pulses, a dark region's ×,
**an anomaly collected by hand**. 51 new tests, suite green (505).
**Shots for G2** (F12, both locales, both layouts, days 39 / 84 / 234):
`C:/Users/schoeneberg/AppData/Roaming/Godot/app_userdata/Doomsday/session_{en,de}_{1920,400}_day*.png`.
Next: **G2 on Fable** — `/clear`, then `/model fable`.

### 2026-09-22 — S2.5 HUD and region panel [O]
`ui/hud/` (top bar with the speed group and the phase chip, stat row, overlay picker, dock, ticker,
`hud.tscn` with both layouts of §5.7) and `ui/panels/region_panel.tscn` — every value read from
`Game.sim.world`, every string through `tr()`; `EventText` narrates the outbox (§8.4). Verified in
the running game at 1920 × 1080 and 400 × 860, English and German, nothing clipped: the German
compact dock needed a tighter button padding and the compact compute cell a smaller type (see
*Deviations*). **`ConsolePanel` unregisters every `%` name inside it** (see *Known issues*).
42 new tests, suite green (454). Next: **S2.6 on Opus** — `/clear`.

### 2026-09-22 — S2.4 Theme and component library [O]
JetBrains Mono 2.304 and Space Grotesk 2.0.0 under `assets/fonts/` (import settings written out,
licence rows added); `ThemeBuilder` composes five partials into 39 type variations,
`tools/build_theme.gd` writes `ui/theme/doomsday.tres`, `project.godot` names it and the session
root assigns it. Eight components (`ConsolePanel`, `ConsoleButton`, `IconButton` with nine drawn
glyphs, `StatBar`, `ValueLabel`, `SlidePanel`, `Chip`, `CapsLabel`) plus `Format`, and
`ui/dev/gallery.tscn` showing every state. Verified in both locales at 1920 × 1080 and 400 × 860:
reference shots at `C:/Users/schoeneberg/AppData/Roaming/Godot/app_userdata/Doomsday/gallery_{en,de}_{1920,400}.png`
(for G2; F12 remakes them). 64 new tests, suite green (412). Next: **S2.5 on Opus** — `/clear`.

### 2026-09-22 — S2.3 Picking, camera, backdrop [O]
`map_picker.gd` (pure, §7.4), `map_camera.gd` (pan, wheel and pinch zoom to the cursor, inertia,
clamp, `focus_region`, §7.5) and `backdrop.tscn`/`.gd`/`.gdshader` (§7.6); `MapView` lost its
stand-in fit and gained hover and `try_tap`. **The map's `CanvasLayer` has to follow the viewport**
and **two map classes may not name each other** (see *Decisions*, *Deviations*). Verified in the
running game: `usa`, `germany` and `japan` are picked from a click at two zoom levels, a drag pans
and selects nothing, the wheel zooms to the cursor, the outline holds. 32 new tests, suite green
(348). Next: **S2.4 on Opus** — `/clear`.

### 2026-09-22 — S2.2 Map rendering [O]
`game/map/map_view.tscn` + `map_view.gd` + `map.gdshader` (§7.1–§7.3) and `region_data.gd` for the
256 × 1 row; `ui/theme/ui_tokens.gd` came with them, because the shader may hold no colour (see
*Decisions*). Verified in the running game: `greedy` spreads teal → yellow across the world, all
three overlays read, dark regions go void, and at 4× zoom there is **no bleeding along any border**
— the ID map is compared as decoded integers, never as colour. 17 new tests, suite green (316).
Next: **S2.3 on Opus** — `/clear`.

### 2026-09-22 — S2.1 Autoloads and session driver [O]
`EventBus`, `Settings`, `Game`, `SaveManager` under `game/autoload/` and `game/session/session.tscn`
with the layer stack of §5.1; the session scene is now the main scene and F5 plays a `greedy` bot at
one day per second, printing every event and day. **The accumulator needs a tolerance** (see
*Decisions*) and **`check_scripts` was blind to any script naming an autoload** (see *Known issues*)
— both found by their tests. 25 new tests, suite green (299). Next: **S2.2 on Opus** — `/clear`.

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
