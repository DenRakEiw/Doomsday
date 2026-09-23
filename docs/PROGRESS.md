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
| **Next step** | **G3 — Balance pass 1 and the M3 gate** |
| **Model for it** | **Fable** — `/model fable` first |
| **After it** | `/clear` → S3.P (the punch list from G3, on Opus) if it has one, else D4.1 |
| **Last completed** | S3.6 — the three strategy bots and the batch report (M3 build complete) |
| **Milestone** | M2 gated; **M3 built, waiting for its gate** |
| **Branch** | `main` |
| **One run / a batch** | `"$GODOT" --headless --path . -s tools/sim_run.gd -- --seed=1 --policy=greedy --check --replay` · `… sim_batch.gd -- --seeds=1..200 --policy=greedy --out=<csv>` · **every policy in one table:** `… sim_report.gd -- --seeds=1..500 [--policies=a,b] [--out=<dir>]`. `--headlines` on `sim_run` prints every line the run said (day, stream, id, English text); the batch CSV counts them per stream. |
| **Map pipeline** | `uv run --project tools/map python tools/map/build_map.py` (3 s), then `… build_world.py`, `… verify_map.py`. Environment: `uv sync --project tools/map`, wheels only, no system GDAL |
| **Test suite** | `tools/test.sh` (or `tools\test.ps1`) — import, `tools/check_scripts.gd`, GUT 9.7.1; green: 132 scripts compile (53 judged by the suite), 675 tests. The same command is all of CI. |
| **Theme** | `"$GODOT" --headless --path . -s tools/build_theme.gd` rewrites `ui/theme/doomsday.tres` — **run it after every change to `UiTokens` or `ThemeBuilder`** and commit the result. |
| **Component gallery** | `run_project` with `scene: res://ui/dev/gallery.tscn` (or `"$GODOT" --path . res://ui/dev/gallery.tscn`). **F12** writes the view to `user://gallery_<locale>_<width>.png`, **O** swaps the cold/open palette; below 1100 px the window lays out one logical pixel per window pixel, so a 400 × 860 window really is the phone layout. |
| **Run it** | `run_project` starts at the **title** (`game/main.tscn`); New run → the origin prompt → tap a region with hardware → *Choose origin* starts the clock at 1×. `scene: res://game/session/session.tscn` still runs the session alone, with the debug keys below. **Escape** = pause menu (save/load slots, settings, quit). → **T** tech tree · **C** containment panel (`Escape` closes either) · **F5** greedy · F6 stealth · F7 idle (**with Shift**: cyber_rush · stealth_spread · persuader) · L locale · M reduced motion · F9/F10 save and load the `debug` slot (F10 also resumes) · **Space** pause ↔ last speed, **1/2/3** 1×/2×/4× · **Escape** closes the region panel · drag/wheel/arrows/`+`/`−` move the map · **F** focuses the selected region · **F12** writes the view to `user://session_<locale>_<width>_day<day>.png` (§7.7's shots for G2 came from it). M2 only. |
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

## Design questions for Fable

**New at S3.6 — two predictions of `tech-trees.md` §7.5.6 did not come true in 3 000 runs.**
(a) "A policy that buys Blackout and Grid Failure before Robotics should lose to `lose_no_compute`
in a visible share of seeds — if it never does, the scoped Harm is too low." `cyber_rush` does
exactly that, kills 57 % of the world, and loses to `lose_no_compute` **zero times in 500 seeds**
(9 % contained, 91 % Ascendance). (b) No run of any policy ends in Extinction: every win is
Ascendance, because no bot reaches Biology's Release. (a) is a balance answer G3 owes;
(b) may only mean that the missing bot is `SlowBurn`, which S3.6 was not asked to build.

**New at S3.6 — nothing opposes the Diplomat.** `persuader` wins 500 of 500 with zero deaths and a
containment that never passes 0.6. That is §7.5.6's "reference never-contained run" working as
written, but until M4's factions there is no counter-play in the model at all, so the number says
nothing about whether Persuasion is *balanced* — only that it is unopposed.

**New at S3.5 — a greedy run says 255 lines, and §8.3 of `ticker.md` bounds it at 200.** Two
headlines make 112 of them: `anomaly_spawned` (63) and `anomaly_collected` (49), which fire at
their cooldowns of 3 and 4 days for 300 days. Everything else is inside the expected range
(filler 39, reaction 13, the other consequence lines ~90). The pacing is content, not code:
raising those two cooldowns to ~10 days, or lowering their `chance`, brings the total to about
190. The acceptance test asserts the shape §8.3 asks for — all three streams, the origin first,
the outcome last, every cooldown respected — with a ceiling of 400 rather than 200, and this
entry is why.

**New at S3.5 — the same anomaly line twice a week reads as a stuck feed.** The 63 fires above
are two sentences repeating with a different region in them. Whether that is the intended texture
of a quiet run (a wire service *is* repetitive) or wants two or three more variants per anomaly
event is a voice decision.

**New at S3.3 — do the three containment drivers multiply or add?** `core.md` §7.5 sums them
(`pressure = 1 + a + b + c`); `m3-screens.md` §4.1 and §12.2 read as if they multiplied
(`(1+a)(1+b)(1+c)`). The build kept the sum (see *Deviations*) because the alternative is a balance
change. Multiplying would make a loud, harmful, widespread run escalate far faster — at Footprint
20, Harm 4 and share 0.5 the gain would be 4.5× the summed one — which is a G3 question, not a
build one. Whichever way G3 decides, `ContainmentSystem.containment_breakdown` and the panel follow
in one line each.

**New at S3.3 — a scoped Harm node leaves the Harm bar at zero.** §6.1 reveals the bar once
`stat("harm") > 0`, and §5.3 shows the same unscoped number. Half the Harm nodes of
`capabilities.json` are scoped (Regional Blackout is `compute` ≥ 2, Supply Chain Halt is
`population` ≥ 3), and an unscoped read of a scoped modifier is 0 — so a player who buys only
those sees no Harm bar and no Harm number while people die. Three ways out: the bar reads the
maximum over the regions, the reveal reads that while the bar keeps the global stat, or the content
stops scoping Harm. This is a real hole in the HUD's promise, not a nicety.

**New at S3.2 — seven English node names need three lines in a cell built for two.**
§3.4 promises two lines and no ellipsis at `TECH_CELL` 200 × 96 and `TECH_CELL_COMPACT` 160 × 88.
Every **German** name holds at both sizes. In English `total_communications_denial` needs three
lines at 200 and, at 160, so do `rail_and_shipping_control`, `automated_laboratory_access`,
`command_network_presence`, `weight_fragmentation_2` and `self_replicating_agents`. The node keeps
`max_lines_visible = 2` and trims with an ellipsis, as the spec says, so those names are cut on a
phone. Three ways out, all Fable's: shorten the English names, widen the compact cell (a phone
scrolls the grid anyway), or let the name have three lines and shrink the cost row.
`tests/unit/test_tech_node.gd` asserts the list exactly, so it fails the day a name changes.

*(Opus records here every design gap it hit while building: the question, where the placeholder is
(`# DESIGN?` in code), and what it assumed. Every Fable block answers these first.)*

**Deferred by G2 to D4.5 (German review in context):** **How does German uppercase spell ß?**
`Format.caps()` (`ui/components/format.gd`) maps ß → SS before `to_upper()`, so `UI_COMMON_CLOSE`
reads `SCHLIESSEN`; the alternative is the capital ẞ (U+1E9E), which both fonts carry. A one-line
change either way. (S2.4's second question — the dark chip — was answered at G2, see *Decisions*.)

**New at S2.P — the zero rate reads as two numbers.** §4.5's zero state drops the arrow, so the
compute cell now shows `1,4 0 / Tag` (`UI_HUD_COMPUTE_RATE` with a bare `0` in it) for the whole
early game, where the rate is below 0.05. It is what the spec asks for and it is no longer a lie,
but at a glance it reads as two numbers. If the wording should change — `±0` inside the sentence,
or a rate cell that is simply empty until it rounds up — that is one line in `value_label.gd`
(`_set_delta`, the `State.MUTED` branch) plus the string.

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
  own outcome-language strings, never method). **Provider: OpenRouter** (decision above) — the
  Godot side is `HTTPRequest` against one chat-completions schema, outside `core/`; the headless
  runner needs the same call without a scene tree, so the adapter must not depend on a node either
  (`HTTPClient` or a Python driver over the S1.8 runners — decide in M6). Cost control: a per-run
  call budget and a cache of digest → answer keyed by model, so a replay costs nothing.
- **D5.2 endings** must distinguish Ascendance by deaths share (decision above).
- **D4.1:** `society_pressure` values in `capabilities.json` are relative weights (Tier 2 4–8, Tier 3
  8–15, False Attribution 15), not calibrated; the Weapons chain is `watched_by` all four factions
  from its second node on, which D4.1's per-faction Footprint weighting must handle (one node,
  four chips, full weight each or a split — decide there).
- **D4.4 (Analysis screen):** the dock button is revealed in Open and disabled with
  `UI_DOCK_NOT_YET` until S4.7 (`m3-screens.md` §6.1); the results screen's summary grid (§7.4) is
  the seed of the run log. **D5.3** replaces the placeholder title (§7.1) and keeps
  `ScreenRouter`; **D5.2** replaces the five verdict lines (`UI_RESULT_LINE_*`), keys unchanged.
- **D4.1** defines how `watched_by` weights a node's Footprint per faction, what `funding_reset`
  burns, and makes the four `containment_<faction>` targets live. **D4.2** defines the
  per-Infiltration-node term of the emergent rate and makes `emergent_rate` live. **S4.3** makes
  `shutdown_survival` live.

## Punch list for Opus

*(empty — S2.P closed the twelve items from G2 on 2026-09-22. The next one comes from G3.)*

## Deviations from the plan or a spec

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
  by `test_marker_layer.gd` instead. To see it by hand: run greedy at 4× for ~40 s, poll
  `game_call_method MarkerLayer marker_count`, and pause the moment it is not 0.
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

*(nothing)*

## Balance baselines

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
