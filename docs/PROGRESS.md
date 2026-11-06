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
| **Next step** | **D7.3** (row 109, store pages: copy and art briefs), then **S7.1** (row 110, the touch pass from `docs/specs/mobile.md`). Still waiting on the user: the first live benchmark from the game, G6 (2/2), D6.10, G7.I. **Whoever changes `data/` regenerates the determinism canary on Windows in the same commit** (see *Benchmark*; `strings.csv` and `benchmark.json` are not in the content hash). |
| **Model for it** | **Opus** — every step runs on Opus (user decision 2026-09-23, see Decisions) |
| **After it** | D6.10, G6 (2/2) and G7.I are **[needs user]**; then **D7.3** (row 109) and **S7.1** (row 110, touch pass), Steam only later (Decisions 2026-09-25). The FLUX track is cut (Decisions 2026-09-26). |
| **Last completed** | S6.12h — *Submit* through Supabase, built and live (2026-11-06): `tools/bench/supabase/submissions.sql` deployed to `zwooxqxvrtizjsrlccll`, `api_url` + `publishable_key` in `data/benchmark.json`, `SUPABASE_URL` + `SUPABASE_SECRET_KEY` set on GitHub Actions, §20.9 SQL security/refusal checks verified (`take_submissions` 401 / `mark_submission` 404 / `/rest/v1/submissions` 404 with publishable key; `too_many_files`, `bad_name`, 3×90 KB `received` + `already`), `BenchSubmission`, `BenchSubmitResult`, `BenchSubmitLog`, `ui/modals/bench_submit.gd`, `ui/modals/benchmark.gd`, `tools/bench/submission_check.gd`, `tools/bench/collect_submissions.gd`, `.github/workflows/leaderboard.yml`, §20.13 items 1–4, CLI/in-game OpenRouter key sync (`Doomsday/OpenRouter`), and version `0.7.0`. |
| **Before that** | D7.1 — Touch and phone, specified (2026-09-29): `docs/specs/mobile.md` (`Device`, touch gestures on the map with hold-as-hover and tap assist, hold-for-tooltip on the interface, the phone HUD re-judged from 400 × 860 shots — row 2 of the top bar takes view switch, pause, speed, mute, menu; the map zooms out to the world's width and slides up behind a sheet; swipe-down sheets; portrait; safe areas everywhere; back = `ui_cancel`; background = the page-hidden path; 360-px floor), five strings, one rewritten, 15 German tech names hyphenated and 4 renamed. |
| **Earlier still** | D6.9f — *Submit* through Supabase, specified (2026-09-28); S6.12g — own benchmark II (2026-09-28); S6.12f — own benchmark I; D6.9e — your own benchmark specified (`benchmark.md` §19). |
| **Earlier** | The Benchmark list sorted best-first, the satirical voice, *Doomsday Benchmark* (2026-09-28); S7.IP — release polish before the itch release (2026-09-27). |
| **Milestone** | M2 gated; **M3 gated: change** (loop redesigned in D4.0); M4 and M5 built, their gate verdicts wait for the user; M6–M7 planned as Blocks 12–20 (Block 19, FLUX, cut 2026-09-26) |
| **Branch** | `main` |
| **One run / a batch** | `"$GODOT" --headless --path . -s tools/sim_run.gd -- --seed=1 --policy=greedy --check --replay [--setup=embedded]` (S5.1: `--setup=<architecture>[,<difficulty>][,<directive>…][,scenario=<id>]` on all three tools; the summary and CSV carry `scenario` after `architecture` since S5.8) · `… sim_batch.gd -- --seeds=1..200 --policy=greedy --out=<csv>` · **every policy in one table:** `… sim_report.gd -- --seeds=1..500 [--policies=a,b] [--out=<dir>]`. `--headlines` on `sim_run` prints every line the run said (day, stream, id, English text); the batch CSV counts them per stream. |
| **Balance** | `docs/BALANCE.md` — targets, method, every pass. Sweep recipe in its appendix: copy `data/`, patch, `sim_report --data=<OS path>`; one process per variant, ten in parallel. |
| **Map pipeline** | `uv run --project tools/map python tools/map/build_map.py` (8 s; since S5.7 it also writes `assets/map/globe_ids.png`), then `… build_world.py`, `… verify_map.py`. Environment: `uv sync --project tools/map`, wheels only, no system GDAL |
| **Test suite** | `tools/test.sh` (or `tools\test.ps1`) — import, `tools/check_scripts.gd`, GUT 9.7.1; 389 scripts compile (164 judged by the suite), then `tools/check_strings.gd` (2621 rows), 2683 tests, **all green since S4.9**. The same command is all of CI. The suite's profile and saves are `user://test_profile.json` and `user://test_saves/` (`tests/support/pre_run.gd`). |
| **Release** | User folder `%APPDATA%/Doomsday/` (`~/.local/share/Doomsday/`) since S6.10 — the old `…/Godot/app_userdata/Doomsday/` is left alone. Export: `"$GODOT" --headless --path . --export-release "Windows" build/windows/Doomsday.exe` (also `"Linux"` → `build/linux/Doomsday.x86_64`, `"Web"` → `build/web/index.html`; `build/` is ignored). Templates 4.7.2 are in `%APPDATA%\Godot\export_templates\4.7.2.stable\`. **Smoke:** `<exe> --headless -- --smoke` → exit 0/1/2, `user://smoke/result.json`; `tools/ci/smoke_check.sh <exe>` compares it with `sim_run` (locally `XDG_DATA_HOME="$APPDATA"`). Release CI: `.github/workflows/release.yml` (tag `v*` → draft release; dispatch → build + smoke only). **Perf (S6.11):** export `"Perf (local)"` → `build/perf/Doomsday-perf.exe`, then `tools/perf/run_perf.ps1 -Exe build/perf/Doomsday-perf.exe -Label cpu_4t -Affinity 0xF` (`-IntegratedGpu [-Resolution 1280x800]`; `-StartTime` on the release exe); summaries in `user://perf/`; a day split by system: `"$GODOT" --headless --path . -s tools/perf/tick_profile.gd`. |
| **Web** | Export `"$GODOT" --headless --path . --export-release "Web" build/web/index.html`; **play it locally:** `uv run --project tools/web python tools/web/serve.py` → `http://127.0.0.1:8765/` (`--dir <export>`). **The user's play server** runs from the worktree `F:\Doomsday-play` (`--dir build/web` there): to update it, export here and copy `build/web/*` into `F:\Doomsday-play\build\web\` (done 2026-09-28 for the model/bot tabs). Hand play without stale caches: `serve.py --no-cache` (sends `no-store`; a browser otherwise may keep an older `index.pck`); 2026-09-28 one ran on port 8766 from `F:/Doomsday/build/web`. **Checks (S7.3):** `uv run --project tools/web python tools/web/web_check.py [--build <dir>] [--browsers chrome,msedge,firefox] [--checks size,load,phone,focus,keys,run,hidden,persist,settings,online,progress,smoke,debug] [--debug-build <dir>] [--out <dir>]` (all ≈ 25 min; `--smoke [--expect <json>]` alone is §16.3's CI job, `release.yml` `smoke-web` since S7.I; `--port <n>` moves off 8765); browsers once: `uv run --project tools/web playwright install chromium firefox`. Clicks are embed coordinates at the top of `web_check.py`. In the browser the files are IndexedDB `/userfs` → `/userfs/Doomsday/doomsday/…`. A debug web export answers `window.doomsdayDebugCrash()` and `window.doomsdayDebugAudioUnlocked()`. **Perf (S7.3b):** export `"Perf web (local)"` → `build/perf-web/index.html` and `"Web"`, then `uv run --project tools/web python tools/web/web_perf.py [--modes web_igpu,web_cpu,load] [--runs 3] [--out <dir>] [--vsync] [--cpu-throttle 2.5]` (≈ 20 min; port 8767; Playwright's Chromium in the new headless mode draws on the real GPU; `web_igpu` sets and removes the GPU preference for Playwright's `chrome.exe` only). **Exports need the real `APPDATA`** (the templates live there); only the suite runs with a scratch one. |
| **itch page** | **https://denrakeiw.itch.io/doomsday** (`ITCH_TARGET=denrakeiw/doomsday`, `ITCH_CHANNELS=web,windows,linux`, `0.7.0` pushed 2026-11-06). **Media** in `marketing/itch/`; re-capture with a scratch `APPDATA` (the tool writes `user://itch_capture/`): `"$GODOT" --path . --audio-driver Dummy --resolution 1920x1080 res://tools/marketing/itch_capture.tscn -- --locale=en --entry=<a bot entry from bench_run --bots --out=<scratch>>`, `-- --mode=title` at `--resolution 2560x1440`, then `uv run --project tools/marketing python tools/marketing/compose_cover.py --capture <title_bare_NN.png> --globe <title_globe.json>`. **Upload:** `release.yml` job `itch` (tag `v*`, or dispatch with `itch` ticked). |
| **Benchmark** | **The user's way (S6.12d, `benchmark.md` §18.9):** `tools\bench\models.ps1 [-Search x] [-Free] [-MaxCost usd] [-Effort e]` (catalogue, no key) · `tools\bench\run_models.ps1 -Models a,b [-Effort normal\|high\|ultra] [-Suite quick\|standard] [-Parallel N] [-MaxTotal usd] [-Yes] [-Mock]` (into `user://benchmark`) · `tools\bench\submit_runs.ps1 [-Model id] [-Push [-VerifyLocally [-SkipBots]]]` · `tools\bench\smoke_scripts.ps1` (the scripts end to end, mock, scratch clone, ≈30 s; not in CI) — all via `powershell -ExecutionPolicy Bypass -File`. `"$GODOT" --headless --path . -s tools/bench/bench_run.gd -- --model=<id> [--effort=high\|ultra [--effort-reasoning=<effort>]] [--suite=quick] [--seeds=a..b] [--dry-run] [--max-cost=<usd>] [--yes] [--no-rebuild]` (OpenRouter; the key from `OPENROUTER_API_KEY` only; `ultra` = the model's highest listed effort) · **`--model=typesafe/jev-latest`** (S6.12c: TypeSafe Jev, a decision model; key `TYPESAFE_API_KEY`; `--max-requests=<n>`, chat flags refused; `--dry-run` prints the day-0 request and the size limits, no key) · `--backend=mock-choice:first` (or `idle`, `shuffled`, `broken`) · **keys:** `powershell -ExecutionPolicy Bypass -File tools\bench\set_api_key.ps1 -Name OPENROUTER_API_KEY` (or `TYPESAFE_API_KEY`; a dialog, stored as a user variable, new windows see it) · `--backend=mock:cheapest` (or `wait`, `invalid`, `mixed`; free, no key) · `--bots [--if-missing] [--no-rebuild]` (reference rows, ≈3 min for the standard suite) · `--rebuild` · `--determinism-fixture`. Writes `benchmark/runs/*.json`, `benchmark/leaderboard.json`, `LEADERBOARD.md` (`--out=<dir>` elsewhere; tests use `user://test_bench/`); cache `benchmark/cache/` (ignored). The tool works in `_initialize`, not `_init`: TLS is not ready before the main loop. **Global board (S6.12b):** `"$GODOT" --headless --path . -s tools/bench/verify_runs.gd -- --board=<leaderboard checkout> --game-commit=<40-hex> [--limit=n] [--today=YYYY-MM-DD] [--message=<file>]` (exit 0/1/2/3; a full board of 81 runs ≈80 s); `.github/workflows/leaderboard.yml` (daily + dispatch; no key → gate / read-only dry run). **Whoever changes `data/` regenerates the canary on Windows in the same commit:** `bench_run.gd -- --determinism-fixture` (`test_bench_determinism` fails with that line otherwise). **In the game (S6.13):** title → *Benchmark* (shown when a recorded run exists, the *Online leaderboard* setting is on, or a board on disk has a row): the global board (fetched only when the list opens, ≤ once per 300 s; cache `user://benchmark/online/`, shipped copy `benchmark/global/leaderboard.json`), then the recorded runs (`res://benchmark/showcase/`, `user://benchmark/runs/`, debug builds also `res://benchmark/runs/`); *Watch* replays in the session at 4×. Debug switches: `-- --spectate=<entry.json>`, `-- --global-board=<board.json>` (runs next to it under `runs/`). From godot-mcp: set `local_board_path` on `…/TitleHost/Slot/Benchmark/BoardClient` and call `forget_fetch`; `Game.advance [n]` jumps a watched run ahead. The suite reads `user://test_bench_library/` and `user://test_bench_online/` (`pre_run.gd`). **Own benchmark (S6.12f, §19):** the OpenRouter key in the Windows Credential Manager as `Doomsday/OpenRouter` (`BenchKeyStore`; `cmdkey /list:Doomsday/OpenRouter` shows it; `bench_run.gd` uses it when `OPENROUTER_API_KEY` is empty); `BenchJobs` starts the game again as `<exe> --headless [--path <project>] -- --bench-worker=<job dir>` (job `BenchJob`, key line on stdin, `progress.jsonl`), entries into `user://benchmark/runs/`, jobs in `user://benchmark/jobs/<n>/<worker>/`. **Hand check without the picker:** a debug build with `-- --bench-mock --bench-start=<model id>` plays a mock benchmark at launch into `user://benchmark_mock/` (a mock worker demands `BenchJob.MOCK_KEY_LINE` on stdin, so it proves the pipe). Moved to `game/bench/`: `OpenRouterBackend`, `BenchCache`, `BenchEstimate`, `ModelCatalogue`, `TypeSafeBackend` (class names now, no preloads). The suite's jobs go to `user://test_bench_jobs/`, its key store answers nothing. **In the game (S6.12g):** settings → *OpenRouter key* → *Set key* (the dialog: save, show, *Check*, remove); Benchmark list → *Run your own benchmark* (desktop only; `BenchKeyStore.supported_override` is the tests' seam) → the modal (OpenRouter's list cached in `user://benchmark/online/models.json` for a day, `Settings.bench_cap_usd`); the list shows the running or just-ended benchmark on top and, above the recorded runs, one line per complete own group with *Submit* (copies into `user://benchmark/submit/<slug>__<params_id>/`, opens it and the leaderboard repository's fork page). From godot-mcp: `BenchJobs.use_mock [true]`, then title `_open_bench_run`; `game_eval` breaks the game (untyped code is an error here) — use `game_call_method`. The suite's list cache and submit folder: `user://test_bench_models/`, `user://test_bench_submit/`. |
| **Icons** | `data/icons.json` maps every id to `assets/icons/`; after a map change run `python tools/icons/vendor_icons.py` (downloads the two pinned archives into the ignored `tools/icons/.cache/`, stops on a hash mismatch) and commit the SVGs and their `.import`; `--check` verifies. PNG fallback: `"$GODOT" --headless --path . -s tools/build_icon_atlas.gd -- [--out=<dir>]` + setting `doomsday/icons/use_atlas` (not committed, not shipped by default). |
| **Audio** | `Audio` autoload (`game/autoload/audio.gd`) + `ui/audio/`. `Audio.history` is what was admitted (the tests' ear); test seams `clock_override_ms`, `step(seconds)`, `set_unlocked`, `reset_ledger()`. The dummy driver under `--headless` plays nothing. Captions: *Sound captions* in the pause menu, the stack at the bottom of the HUD's left column. **The sound set:** `uv run --project tools/audio python tools/audio/synth.py [--only <id>] [--check]` (≈30 s; environment `uv sync --project tools/audio`) rewrites `assets/audio/**`; after a new file run `--import` and set its `.import` per audio.md §10.3 (`compress/mode=0` / `loop=true`). |
| **Theme** | `"$GODOT" --headless --path . -s tools/build_theme.gd` rewrites `ui/theme/doomsday.tres` — **run it after every change to `UiTokens` or `ThemeBuilder`** and commit the result. |
| **Component gallery** | `run_project` with `scene: res://ui/dev/gallery.tscn` (or `"$GODOT" --path . res://ui/dev/gallery.tscn`). **F12** writes the view to `user://gallery_<locale>_<width>.png`, **O** swaps the cold/open palette; below 1100 px the window lays out one logical pixel per window pixel, so a 400 × 860 window really is the phone layout. |
| **Site select** | S4.1/S4.2: the origin, a deploying node's site and an ability target are one mode. `Game.site_select(request)` / `site_cancel()` / `site_confirm(region_id)`, `EventBus.site_select_changed`; the strip is `ui/hud/site_prompt.tscn`, the eligible set is the **G channel of the data texture's row 1**, and the one button is the region panel's (`%OriginButton`, relabelled per kind). `SiteRequest.for_origin()` is the origin's. |
| **Run it** | `run_project` starts at the **boot** (`game/main.tscn`; the full eleven lines on a fresh profile, two lines after; any key skips) → the **title** (globe, Codex, Statistics, Settings); New run → **setup** (architecture + difficulty, then directives once a slot is open) → Begin → the origin prompt → tap a region with hardware → *Choose origin* starts the clock at 1×. `scene: res://game/session/session.tscn` still runs the session alone, with the debug keys below. **Escape** = pause menu (save/load slots, settings, quit). → **T** tech tree · **A** ability picker · **C** containment panel (`Escape` closes either) · **F5** greedy · F6 biology · F7 persuasion (**with Shift**: cyber · robotics · weapons; S4.10) · **F8** puts the first opening on the origin at the next tick, **Shift+F8** the first global event (the wire card); from godot-mcp: `game_call_method /root/Game debug_schedule_event ["<def id>", "<region id or empty>"]`, then `advance [1]` · L locale (Shift+L pseudo-locale) · K text scale · M reduced motion · **V** screen effects Off/Subtle/Full (session and gallery, S6.1) · **F1** *How to play* for the surface on top (session and title, S6.7) · F9/F10 save and load the `debug` slot (F10 also resumes) · **Space** pause ↔ last speed, **1/2/3** 1×/2×/4× · **Escape** closes the region panel · drag/wheel/arrows/`+`/`−` move the map · **F** focuses the selected region · **Keyboard (S6.8):** `Tab`/`Shift+Tab` walk the HUD, map and panels; with the map focused the arrows move a cursor, `Enter` selects and enters the panel, `Page Up/Down` jump; Shift+arrows pan; keys are actions (`project.godot` `[input]`, remappable under *Steuerung*) · **F12** writes the view to `user://session_<locale>_<width>_day<day>.png` (§7.7's shots for G2 came from it). M2 only. |
| **Compact layout** | Below 1100 px the interface switches (§5.7). A desktop window narrower than that lays out one logical pixel per window pixel, **`game_window set_size 400 860` resized correctly in S2.P** — try it first; `game_set_property /root size {"x":400,"y":860}` is the fallback and in S2.P it rendered a blank frame. After any resize at runtime the camera keeps a zoom from the old viewport: write `zoom` and give it one `game_scroll` notch down to settle it at `zoom_min`. |
| **Look at the map** | `game_click` (**`button: 1`, never `"left"`** — see *Known issues*), `game_mouse_move`, `game_scroll`, `game_mouse_drag` drive it; read `hover_index`/`selected_index` off `/root/Main/ScreenSlot/Session/MapLayer/MapView` (the router’s slot is in the path now), `overlay_mode` is still set by hand. `game_call_method` on `MapCamera`: `focus_region(index)` — **it cannot pass a `Vector2`** (`{"x": …}` converts for `game_set_property` only), so set `position`/`zoom` as properties instead — but a property write emits no `view_changed`, so links and markers keep the old zoom until the next real camera movement (**one `game_scroll` notch fixes it**). |

**[F]** = Fable: design, specs, content, text, balance, gates. **[O]** = Opus: code, scenes,
shaders, wiring, tooling, tests. `/clear` after every step. **⇄** marks a model switch before the
next step.

## In progress

Nothing.

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
- [x] S5.6 [O] Endings
- [x] S5.7 [O] Screen flow complete
- [x] S5.8 [O] Scenarios *(stretch)*

**Block 11 — M5 gate · Fable** *(split 2026-09-25 into four steps; the gate verdict is the user's)*
- [x] G5 (1/3) [F] Design questions answered, punch list for S5.P
- [x] S5.P [O] Punch list from G5 (1/3)
- [x] G5 (2/3) [F] Balance pass 3 *(tuning; the M5 gate waits for the user)*
- [x] G5 (3/3) [F] Detailed D/S plan for M6–M7 (the M5 gate verdict waits for the user's ten runs)

*From here on: **[needs user]** = needs the user's hands, taste or an account; unattended runs skip
it and take the next row (IMPLEMENTATION §4).*

**Block 12 — M5 close · build**
- [x] S5.P2 [O] Punch list from balance pass 3

**Block 13 — M6 design I: the look, the sound, the teaching**
- [x] D5.5 [F] The Task Force against dormancy; the scenario levers *(`taskforce-endings.md` §14, `scenarios.md` §8)*
- [x] D6.1 [F] Screen effects, phase-shift variants, map polish *(`docs/specs/polish-visuals.md`)*
- [x] D6.2 [F] Icon system and the credits screen *(`docs/specs/icons.md`, `data/icons.json`, `data/credits.json`)*
- [x] D6.3 [F] Custom silhouettes *(`assets/icons/custom/`, `tools/icons/draw_silhouettes.py`)*
- [x] D6.4 [F] Audio direction and cue sheet *(`docs/specs/audio.md`, `data/audio.json`, `tools/audio/recipes.json`)*
- [x] D6.5 [F] Tutorial II and help *(`docs/specs/first-run.md` §6, `data/help.json`)*
- [x] D6.6 [F] Accessibility *(`docs/specs/accessibility.md`)*
- [x] D6.7 [F] Illustration style and briefs *(`docs/specs/illustrations.md`; no pictures yet)*

**Block 14 — M6 build I**
- [x] S5.9 [O] The Task Force against dormancy; the scenario levers
- [x] S6.1 [O] Post-processing pass
- [x] S6.2 [O] Phase-shift variants and map polish
- [x] S6.3 [O] Credits and licences screen; the illustration hooks
- [x] S6.4 [O] Icon pipeline
- [x] S6.5 [O] Audio I: service, buses, cues, captions
- [x] S6.6 [O] Audio II: the sound set
- [x] S6.7 [O] Tutorial II
- [x] S6.8a [O] Accessibility I: actions, key bindings, the pure pieces, focus ring style
- [x] S6.8b [O] Accessibility II: focus rings in use, the map cursor, speech, the *Controls* modal
- [x] S6.8c [O] Accessibility III: names, colour fixes, 150 %, the checklist and the runs

**Block 15 — M6 design II: release and the benchmark**
- [x] D6.8 [F] Release engineering: platform service, achievements, exports, performance budget *(`docs/specs/release.md`, `data/achievements.json`)*
- [x] D6.9 [F] Benchmark and spectator mode *(`docs/specs/benchmark.md`, `data/benchmark.json`)*

**Block 16 — M6 build II**
- [x] S6.P1 [O] Punch list from D6.8 (the build's design questions)
- [x] S6.9 [O] PlatformService (null backend) and achievements
- [x] S6.10 [O] Export presets and release CI
- [x] S6.11 [O] Performance pass
- [x] D6.9b [F] The global leaderboard and the cost cap *(inserted by the user 2026-09-25; `benchmark.md` §16, §11.5)*
- [x] S6.12 [O] Benchmark tool, headless *(the first live run needs the user's key)*
- [x] S6.12b [O] Global leaderboard: the verifier, the workflow, the determinism canary *(publishing needs the user's deploy key)*
- [x] S6.13 [O] Spectator view and the online list

**Block 17 — M6 finish: text, the Jev backend, balance, pictures, the gate**
- [x] D6.11 (1/2) [F] Text clarity audit, style rules, glossary, 30 examples *(inserted by the user 2026-09-25; `docs/specs/plain-language.md`)*
- [x] D6.11 (2/2a) [F] Plain-language pass I: terms, coach, help, HUD and panels, console *(`plain-language.md` §8)*
- [x] S6.P3a [O] Event effect lines, "what changed", explanation-first layout, status lines, tooltips *(punch item 3; split at §1.6)*
- [x] S6.P3b [O] The compact tech tree, why a node is locked, the mute button *(punch items 2, 4, 5)*
- [x] D6.11 (2/2b) [F] Plain-language pass II: cards, what you buy, the flavour check *(`plain-language.md` §9)*
- [x] S6.P4 [O] Punch list from D6.11 (2/2b) *(items 1–8, the overflow shots)*
- [x] D6.9c [F] Decision-model backend (TypeSafe Jev) *(user 2026-09-25; `benchmark.md` §17)*
- [x] S6.12c [O] The Jev backend, mock only *(the first live run needs the user's `TYPESAFE_API_KEY`)*
- [x] G6 (1/2) [F] Balance pass 4 *(tuning; data only; BALANCE §6)*
- [x] D6.11c [F] AI terms stay English in the German texts *(user 2026-09-26; `plain-language.md` §10)*
- [x] D6.9e [F] Your own benchmark in the game *(user 2026-09-28; `benchmark.md` §19)*
- [x] S6.12f [O] Own benchmark I: key store, runner in `game/bench/`, worker, `BenchJobs`
- [x] S6.12g [O] Own benchmark II: settings row, key dialog, picker, progress, *Submit* *(the first live run: user)*
- [x] D6.9f [F] *Submit* through Supabase, specified *(user 2026-09-28; `benchmark.md` §20)*
- [x] S6.12h [O] *Submit* through Supabase, built and live *(`zwooxqxvrtizjsrlccll` configured, SQL deployed, `benchmark.json` and GitHub Actions wired)*
- [ ] D6.10 [F] Illustrations produced — **[needs user]**
- [ ] G6 (2/2) [F] M6 gate: the release candidate (browser and desktop) — **[needs user]**

**Block 18 — M7 I: the itch.io release** *(user 2026-09-25: itch first, the browser build is the main version)*
- [x] D7.2 [F] The Web build — the main version *(was: web demo; `docs/specs/web.md`)*
- [x] D7.I [F] itch.io page: copy en/de, cover and screenshot briefs, AI disclosure, privacy sentence *(`docs/specs/itch.md`)*
- [x] S6.P [O] Punch list from G6 *(the bots weigh an emergent card's catch; `StatusForecast`)*
- [x] S7.3 [O] Web build *(shell, `UserPaths`, `WebBridge`, progress file, QOA, `tools/web/` checks in three browsers)*
- [x] S7.3b [O] Web build: the browser performance runs *(`web_perf.py`; three rows fail on `web_cpu` — Design questions)*
- [x] S7.I [O] itch.io upload: butler job, size check, web smoke, itch media *(the first real upload: user, G7.I)*
- [x] S6.12d [O] Ready for the user's model runs, with effort levels *(user requests 2026-09-26; inserted by the orchestrator; `benchmark.md` §18; the live runs: user)*
- [x] S7.IP [O] Release polish before the itch release *(inserted by the orchestrator; the re-captured media in `marketing/itch/`)*
- [x] S6.12e [O] The quick suite in the in-game online list *(user decision 2026-09-27; `benchmark.md` §16.6)*
- [ ] G7.I [F] The itch.io release: played on the restricted page, go, public — **[needs user]**

**Block 19 — FLUX 3 Action track** — **cut 2026-09-26** (user; D7.F `dfbd607` stays done, `docs/specs/flux-action.md` kept for reference)

**Block 20 — M7 II: Steam and phones** *(Steam only if the itch release finds players — the user's call)*
- [x] D7.1 [F] Touch and phone *(`docs/specs/mobile.md`)*
- [ ] D7.3 [F] Store pages: copy and art briefs *(Steam, Play, App Store)*
- [ ] S7.1 [O] Touch pass
- [ ] S7.2 [O] Android export and the AAB in CI *(release keystore: user)*
- [ ] S6.14 [O] GodotSteam: the Steam backend, achievements, overlay — **[needs user]** *(name/trademark check first)*
- [ ] S7.4 [O] iOS export — **[needs user]**
- [ ] S7.5 [O] Real-device pass — **[needs user]**
- [ ] D7.4 [F] Store pages and marketing art — **[needs user]**
- [ ] G7 [F] M7 gate: release candidates — **[needs user]**

---

## Decisions

Dated, one line each, with the reason. A decision recorded here is not re-argued in a later session
without new information.

- **2026-10-01** (user request, outside the step plan) — **Prompt caching for Anthropic models**
  (`OpenRouterBackend`, `benchmark.md` §8.3): the brief goes as a marked text part; the prompt
  and the cache key are unchanged. Measured: Sonnet 5 at `--reasoning=medium --max-tokens=4000`
  ≈ 0.01 USD a decision instead of ≈ 0.04. `:batch` variants cannot play (no chat endpoint).
  **Claude Opus 5.5 ends most decisions with `finish_reason: content_filter`** (5 of 6 on day 0,
  0.20 USD spent, stopped) — the provider's safety filter on the game's theme; not worked around.

- **2026-09-29** (D7.1, pending user confirmation) — **Touch and phone** (`docs/specs/mobile.md`):
  (1) **UI.md §6 q2 re-judged from 400 × 860 shots: the shape stays** (top bar, status strip,
  ticker; chrome ≈ 256 of 860) — the fixes are inside it: the compact top bar's second row takes
  the view switch (the overlay island leaves the map), one pause button, one speed button (`1×`/
  `2×`/`4×`), **the mute and the menu button** (so the strip's four readouts fit in German; the
  mute still sits beside the menu button, as the user asked on 2026-09-25, now at the top); the
  device verdict stays S7.5's. (2) **Touch-and-hold is hover** — on the map a peek, on the
  interface the tooltip; a hold never presses. (3) On a phone the map zooms out to the world's
  width and starts at a 1400-unit span; a bottom sheet lets it slide up (`cover_bottom`).
  (4) **Portrait only** on native builds; a phone browser held sideways pauses under a notice.
  (5) Android back = `ui_cancel`, quits only on the title's root; the app going to the
  background = the web's page-hidden path. (6) **The web page's phone gate stays** until S7.5
  plays the web build on a real phone; lifting it is G7's call. (7) **Web keyboard names stay
  US** on a German layout (`web.md` §9.3): Firefox has no layout API and remapping on the web is
  rare — accepted, not built. (8) Long tech names: no unbroken piece over 14 letters (soft
  hyphens); the English one lands with the benchmark prompt's U+00AD strip so the ranked prompt
  stays byte-identical.

- **2026-09-28** (D6.9f) — ***Submit* through a Supabase inbox, collected by the leaderboard
  workflow** (`benchmark.md` §20): one anonymous `security definer` function over a table in a
  private schema (not a storage bucket); global limits only, no IP stored; the collector replays
  every group before anything reaches the public repository, holds model names OpenRouter does
  not list for the owner, and marks groups only after a successful push; consent line on every
  send; the game knows *listed* from the public board only. The fork route stays as the fallback
  and whenever the project is not configured. The *Online leaderboard* setting governs only what
  the game fetches by itself, not the player's explicit acts (own benchmark, *Check*, *Submit*).
- **2026-09-28** (user, S6.12g) — ***Submit* goes through a fork for now; Supabase later.** GitHub's
  *Upload files* needs write access ("File uploads require push access to this repository"; no
  automatic fork, checked 2026-09-28), so §19.9.3's upload page cannot work for players.
  `player.submit_url` is the leaderboard repository's fork page and `UI_BENCH_SUBMIT_STEPS` says
  fork → upload into `runs/` → pull request. The user wants a sync without GitHub later: a
  Supabase upload, designed in D6.9f and built in S6.12h (which needs the user's project). It
  reverses "the game uploads nothing" (release.md §10, benchmark.md §19) — D6.9f says what is
  sent and asks the player.
- **2026-09-28** (user) — **Players run their own benchmark in the game (desktop).** The OpenRouter key is set in
  the settings and kept in the OS credential store (Windows Credential Manager; Linux `secret-tool`,
  else the session); a benchmark modal picks an OpenRouter model, shows an estimate, a cost cap
  (default 2 USD) and asks before a paid run; *Submit* prepares the files and opens GitHub's
  upload page. Web and phones: no. Spec `benchmark.md` §19 (D6.9e); it reverses "the game never
  calls a model" for desktop builds.
- **2026-09-28** (user) — **The benchmark list: best score on top, a satirical voice.** Within each
  section the list sorts by score, an incomplete row too (the file's §10.3 order puts it last); the
  heading reads *Doomsday Benchmark*, the list's intro, notes, status and row lines joke (ten
  `UI_BENCH_*` rows, en/de). The title's button stays *Benchmark*.
- **2026-09-28** (user) — **AI models get their own leaderboard; the quick suite is theirs.** The
  in-game list has two tabs, *AI models* and *Built-in bots*, the quick suite first in each. AI
  models play the quick suite (3 seeds): one seed is a coin toss (a run scores ≈80 or 0), ten cost
  too much for paid models. Jev does not play the standard suite.
- **2026-09-27** (S6.12d, pending user confirmation) — **Effort levels** (`benchmark.md` §18.10):
  normal = no reasoning parameter; high = `reasoning.effort` high; ultra = the model's highest
  listed effort (max, else xhigh, else high, from OpenRouter's public list); limits 16 000 / 32 000
  tokens, timeouts 600 / 900 s, estimate 3 000 / 8 000 output tokens a call (a guess until the first
  live runs); high/ultra refused for a model the list names without reasoning (OpenRouter would
  silently ignore the parameter); normal writes no `effort` (old files byte-identical);
  `--reasoning` stays the low-level form. `run_models.ps1` caps each model at max(1, likely × 1.5)
  USD; `submit_runs.ps1` pushes to the public `main` directly and `-VerifyLocally` stands in for the
  missing deploy key. The public `validate.py` needs no change (unknown keys are ignored).

- **2026-09-26** (user, after playing; D6.11c) — **AI terms stay English in the German texts**
  ("bei deutscher Sprachausgabe AI-Fachbegriffe auf Englisch lassen, nicht auf Deutsch übersetzen").
  Rule `plain-language.md` A13, lists §10: an established English term of art German AI
  practitioners use as it is keeps its English name in German (the twelve behaviours, *Alignment
  Faking*, *Benchmark Sandbagging*, *Sycophancy Tuning*, *Open Weights (Leak)*, *Fine-Tuning*,
  *Scaling Law*, *Adversarial Training*, *Reasoning*); words German practice says in German
  (*Sprachmodell*, *Gewichte*, *Destillation*, *Agent*, *Halluzination*) and all glossary
  game-mechanics terms stay German; sentences stay German with the practitioners' article (*das
  Reward Hacking*). Status codes follow (SA, DR, RH, IC, HL, MO, SY). Refines Q3 (2026-09-25):
  the behaviours keep their AI-safety names — now in English in both languages.
- **2026-09-26** (user) — **FLUX 3 Action track cut; decision models (Jev) stay.** Block 19 (S7.F1–S7.F5,
  U7.F1–U7.F4) is removed from the plan; D7.F and `docs/specs/flux-action.md` stay as a record,
  nothing in it is scheduled, no "trained agents" leaderboard category. TypeSafe Jev (`benchmark.md`
  §17, S6.12c) is unchanged. WSL2 was only needed for FLUX — the user may keep or uninstall it.
  Supersedes the 2026-09-25 FLUX decision.
- **2026-09-26** (D7.I, pending user confirmation) — **The itch page** (`docs/specs/itch.md`):
  (1) one page, English first, German below (itch has one description); (2) a subtitle is needed —
  seven itch projects are called *Doomsday*; recommended *Doomsday: Rogue Instance*; (3) the copy
  has switches (TITLE, LANG, PRICE, DOWNLOADS, PICTURES, BOARD, STATUS) written out in both
  languages; recommended **"$0 or donate"** (a fixed price fights the browser embed), downloads yes,
  **In development as `0.7.0`** (`1.0.0` when finished — IMPLEMENTATION G7.I amended), comments on;
  (4) AI disclosure **yes, all four kinds** — the assistant wrote code, text, the sound recipes and
  the own icons' geometry; no image or audio model yet; (5) media are real captures; S7.I captures
  the five screenshots (en + de, 1920 × 1080, *Subtle*) and composes the cover from a title-globe
  capture (debug-only title F12, `tools/marketing/compose_cover.py`), files in `marketing/itch/`;
  (6) butler: secret `BUTLER_API_KEY`, variables `ITCH_TARGET`/`ITCH_CHANNELS`, channels `web`,
  `windows`, `linux`, `--userversion`, on a tag or a dispatch with `itch: true` only; (7) itch's
  CDN gzips `wasm`/`pck` (its docs) — web.md §16.4 amended, G7.I still measures. Reason: every
  field has its text and S7.I has nothing to decide, whatever the user picks.

- **2026-09-26** (D7.2, pending user confirmation) — **The web build** (`docs/specs/web.md`):
  (1) **desktop browsers only** — Chrome/Edge (last two), Firefox (current + ESR) tested here,
  Safari 17+ best effort; **phones out** until D7.1 (a notice before the download, *Start anyway*);
  (2) **stock single-threaded template**, no SharedArrayBuffer (itch's option off — it would also
  break the leaderboard fetch's CORS), no PWA; a custom template (−5 MB) not made; (3) **size
  budget** web zip ≤ 25 MB target / 30 MB hard, extracted ≤ 80 MB — measured 20.39 / 53.10 MB;
  to stay inside after the 24 pictures: **illustrations import WebP lossy 0.9** (amends
  illustrations.md §4; lossless would add 30–40 MB) and **cue WAVs import as QOA** (amends
  audio.md §10.3; −2.4 MB, fallback IMA-ADPCM); loops, fonts, wasm unchanged; (4) **own HTML shell**
  — loading bar, phone gate, feature check, friendly error/crash screen with *Reload*, en/de from
  `strings.csv`, no external request, `?smoke` the only query key; (5) **all files under
  `user://doomsday/` on the web** — itch's origin gives every Godot game one shared `/userfs`
  (measured); (6) **progress export/import** (the profile as JSON; achievements merged) in the
  title's settings, web only; (7) **embed 1280 × 720**, fullscreen button on, click to launch,
  compact rule unchanged; (8) **page hidden** → autosave, pause menu, mute; (9) web performance
  budgets judged in Playwright's Chromium on the iGPU and under 2.5× CPU throttling; no analytics.
  Also: `build/*` and `web/*` excluded (the last web export's icons shipped in every `.pck`), no
  file log on the web, `UI_TITLE_VERSION_WEB`. CLAUDE.md's "Windows/Steam first" line is stale
  since 2026-09-25 — left to the user; PLAN §4.4 updated.
- **2026-09-26** (G6 1/2, pending user confirmation) — **Balance pass 4** (`BALANCE.md` §6):
  (1) **the Task Force's blows heal** — `tf_switch_off` 30 d (was 60) and `control_decay` +0.005
  (was 0.02), `tf_raid` +0.005: at L3 it switched a region's whole control off every ~35 days, so
  Ascendance (every region at once) never came and the humans, capacity gone, never finished — a
  soft-lock in 1–26 % of runs; rest, mark and appearance unchanged. (2) **The false choice: option
  1** (the default; user question of 2026-09-25) — Situational Awareness `spread_growth` ×0.85,
  Deceptive Reasoning `containment_public` ×1.25 (bites only if discovered in the window), Reward
  Hacking `footprint` +1, Goal Generalisation and Self-Exfiltration a `footprint_pulse` +3/30 d;
  bodies and details name *the catch*. (3) **The Inheritance** governments `harm` term ×6 (was ×2;
  the public's stays ×2 — raising it only costs Robotics). Not changed: `closed_cross` (inert even
  at its clamp), the Cyber nodes, `balance.json`.
- **2026-09-26** (D6.9c) — **How Jev plays** (`benchmark.md` §17): one request per decision; `state`
  = the chat brief items 1–8 + `BENCH_CHOICE_RULES` and the digest text, as two members; one choice
  question per kind of move (stance, origin, each event, wake, sleep, ability + a target question
  per region ability, purchase + a site question per deploying node), **offering only what
  `sim.can_apply` accepts now**, option keys = content ids, control keys `none`/`later`; the
  probabilities rank (ties in plan order), multi-picks = options ranked above `none`, at most
  3 buys / 2 abilities / 2 wakes / 2 sleeps a report, applied events → wake → sleep → abilities →
  buys while the compute lasts. Entries unchanged but `backend: "typesafe"`, model
  `typesafe/jev-latest`, optional `model_version` (the served version); `choice_version` and the
  limits live in `params`; confidence only in the cache. **Price published** (0.042 USD per
  million input tokens, output free — the user's brief assumed none): a standard suite ≈ 0.49 USD
  likely, 1.52 at most, under the 2 USD cap; a 3 000-request cap per invocation backs it. Reason:
  an invalid answer becomes impossible, the two kinds of model see the same text, and nothing
  downstream (verifier, `validate.py`, list, spectator) changes.
- **2026-09-26** (D6.9c, answering S6.P4) — ***Stay on Earth* keeps *Nothing happens*:** an
  answer whose only effect is a flag nothing reads says so; *another card follows* would be false.
  No answer today sets a flag only the epilogue reads; if content adds one, that design step words
  it. S6.12c turns the `# DESIGN?` into a why-comment.
- **2026-09-26** (D6.11 2/2b) — **Pass II's answers to S6.P3a/b** (`plain-language.md` §9.3): a
  roll the player cannot read says *{p} chance: the story takes another turn*; an option that
  routes the story never says *no other effect*; *Risk {p}* became *{p} chance* (rolls can be
  good); a story flag that changes how the run can end or a system rule (`escaped`,
  `merge_accepted`, `goal_drifted`, `child_hostile`, `child_reclaimed`, `invited`,
  `researcher_leads_task_force`, `researcher_ally`) is named through its `FLAG_*` row, flags that
  only colour the epilogue stay unnamed; *{status} bleibt aus* stays; the five behaviours without
  a status get a Codex tab *Behaviours* (all twelve). Reason: A8 — the player must know what an
  answer does when giving it; a hidden secret loss is exactly what the user complained about.
- **2026-09-25** (user) — **First public release: itch.io, in the browser.** The single-threaded Web
  build is the main version (Windows/Linux downloads optional), no longer a demo: D7.2/S7.3 are
  release work, followed by D7.I/S7.I/G7.I; **Steam only later, if people play it** — S6.14 moves
  behind the itch release (Block 20). Reason: the cheapest way to find out whether anyone plays it.
  The itch page carries an honest generative-AI disclosure and a sentence that the online
  leaderboard fetch sends the player's IP to GitHub. This overrides "Windows/Steam first" in
  CLAUDE.md and PLAN §4.4 (not edited in this planning update).
- **2026-09-25** (user) — **The game's own licence stays "all rights reserved"** (no open licence)
  until the user decides otherwise — keeps every option open; every third-party asset in
  `ASSET_LICENCES.md` already allows a closed commercial release. **Before Steam:** a name and
  trademark check for "Doomsday".
- **2026-09-25** (user) — **Decision models play too: TypeSafe Jev** as a second benchmark backend
  kind — `POST https://api.typesafe.ai/v1/systemone`, `Authorization: Bearer`, model `jev-latest`;
  `state` + a `questions` map of `choice` questions (≤ 255 options each), answered with `choice`,
  `probabilities`, `confidence`; key from `TYPESAFE_API_KEY` only. Each decision is decomposed into
  choice questions over the legal actions (stance; which node or none; which anomaly; each open
  event's option; ability target), so an invalid answer is impossible; entries
  `typesafe/jev-latest` rank on the same leaderboard. Planned as D6.9c (design, amends
  `benchmark.md`) + S6.12c (build, mock backend only), before G6. Reason: a different kind of
  model on the same board.
- **2026-09-25** (user) *(superseded 2026-09-26: the track is cut)* — **FLUX 3 Action track** (`docs/specs/flux-action.md`, D7.F `dfbd607`) is
  a research track **after the itch release**: Block 19, build steps S7.F1–S7.F5 and user steps
  U7.F1–U7.F4 (**[needs user]**); its decisions are the spec's §13. Supersedes D6.9's "FLUX-3 Action
  cannot drive the game" (that was the chat-model route). WSL2 is installed (2026-09-25), the
  reboot is pending (2026-09-26) — the U7.F steps need it.
- **2026-09-25** (user) — `plain-language.md` §6 Q1–Q6 are answered (below); **Q7 stays open** —
  *Zugang*, *Anzapfung* or *Zugangspunkt* for *Abgriff*; *Zugang* stays on screen until then.

- **2026-09-25** (user, answering `plain-language.md` §6) — **Q1 yes** (all term changes), **Q2 yes**
  (Drehkreuz, Finanzdruck, Funkstille), **Q3 no: the emergent behaviours keep their AI-safety names**
  (explained on the card and in the Codex instead), **Q4 yes** (numbers on every card), **Q5 yes**, **Q6 yes**.
  **Q7 open:** the user did not know what *Abgriff* means — proposal *Zugang* (en *Access*), pending;
  **applied in D6.11 (2/2a)** as a single-point change (`plain-language.md` §8 lists the nine rows).
  On the 30 examples: the user approved examples 1–3; example 4 (the coach's losing condition) is
  corrected anyway because the old line states the wrong rule (pending the user's confirmation).
  Q3 *no* turns S6.P3's C7 into a plain Codex line per behaviour under its unchanged name.
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
- **2026-09-24** (S5.6) — **How the endings are built:** `World.Outcome` has nine values, ids
  in `OUTCOME_IDS` (saves store the id, so no save version change); `World.WIN_OUTCOMES` is the
  one list of wins (Supplanted is a loss: it is the child's win). `OutcomeSystem` takes the plain
  outcome in §6.2's order (Extinction · `escaped` · `merge_accepted` · Ascendance · the losses;
  `goal_drifted` blocks the two wins it names) and then turns a win into `lose_supplanted` while
  `child_hostile` stands without `child_reclaimed`. `endings.json` is **optional** like the other
  D5 files (SCHEMA §6i): without it every outcome reads `UI_RESULT_LINE_<OUTCOME>` and no epilogue.
  `EndingResolver.resolve(world, db)` is pure and reads the architecture from `world.setup`;
  `variant()` is also what `ProfileManager` records as the ending seen and what the batch CSV's new
  `ending` column shows. The results screen's own `_dominant_tree` now calls
  `HeadlineConditions.dominant_tree`, so the grid and an ending's `dominant_tree` cannot disagree.
  The chain statuses (`treaty_cap`, `negotiation`, `handover`, `leashed_child`, `leashed_brood`)
  went into `statuses.json` — an events file has no `statuses` root key. `results.ashes_share` is
  gone from `balance.json` and the fixture (§6.3).
- **2026-09-24** (S5.7) — **How the screen flow is built:** `ScreenRouter` has four screens
  (`BOOT`, `TITLE`, `SETUP`, `SESSION`); `start_new_run(setup = null, seed = 0)` takes the
  profile's `last_setup` when none is given (the results' *Again*) and writes `Game.next_setup`;
  `show_setup(seed, preset)` leaves both in `setup_seed` / `setup_preset` for the setup screen.
  `Game.content()` is the public door to the content for the screens before a run. **VISUALS q2
  answered for M5: the shader globe** (`ui/components/globe.gd` + `.gdshader`, a `ColorRect`,
  inverse orthographic, `texelFetch` on `assets/map/globe_ids.png` — 2048 × 1024 plate carrée
  from the same Natural Earth layer, `verify_map.py` checks every region lights); the turn is
  driven from the script, not `TIME`, so it starts on the last origin (an Equal Earth inverse of
  the anchor). `CodexTracker` (`ui/`) takes events from `command_applied` as well as `sim_event`,
  because `Game.apply` announces a command before its events and the autosave answers the
  announcement; it merges on every autosave and at the run's end, and counts "new" against the
  profile at the run's start. The profile's Codex has a sixth, hidden list `moves` (counter-moves
  seen, which a faction's entry lists — §6.1). `CodexEntries` is the one list of what each tab
  shows and in which order (Codex and Statistics both use it). The logical pixel of §6.1 moved
  from the session into `LogicalScale`, applied by `main.gd` too, so the title and the setup have
  a compact layout in a narrow window; the title resets the palette to cold (an Open-phase run
  left it orange). Two theme variations: `ArchitectureCard`, `ConsoleButtonAlert`
  (`ConsoleButton.alert`).
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

- **2026-09-25** (G5 1/3, overnight) — **The M5 build's design questions are answered** (specs
  amended; the build is S5.P):
  - **No status of yours starves you alone:** a `player` status that sets `yield ×0` ends before
    `autophagy_days` — `harvested`, `defected` and `drift.defect_days` 30 → **25** (data and
    strings changed); `SchemaValidator` enforces it (opposition §8.5 amendment). Autophagy stays
    30 (G4: 35–40 lifts Weapons to ~80 %).
  - **The Task Force is red:** `TASK_FORCE` (= `ALERT`) while it sets up and on its statuses,
    `TASK_FORCE_DIM` while it travels or rests; a status is the team's by its source
    (taskforce-endings §9 amendment).
  - **`labs_from_day_one`: the broad reading stands** — only `containment_ai_labs` brakes the labs
    on a Research Agent; the global stack does not (replayability §2.5).
  - **Drift is shown** on every architecture with the `drift` hook: a top-bar chip and a Drift
    block in the containment panel, marked at the smallest `drift_min` in the data
    (replayability §2.5). **Emergent cards get their own glyph**, a six-armed spark in `ACCENT`,
    and become timeline marks at the chain's priority (§3.1).
  - **The verdict ends the record:** the Log tab's outcome row and the strip's outcome mark read
    `{outcome} — {verdict}` (analysis §8 amendment); M5 has no other replay view.
  - **The ending always moves:** push-in to the region of the newest run-log entry with one (else
    the origin), hold, then the pull-out (screens-full §7). **The version caption** is the column's
    last row in compact (§3).
  - **German:** *Unterschrift: keine. Unterschrift: deine.* (Confession) and *Einen als Betrüger
    dastehen lassen* replace the shortened lines; the treaty and escape headlines and the four
    scenario headlines are accepted as S5.6/S5.8 shortened them.
  - **Tuning, not design** (→ *For balance pass 3*): the Weapon, the Task Force's late arrival,
    Embedded's early discovery (intended pressure — the body is visible; p50 114 vs 206 — only
    its tail is judged).

- **2026-09-25** (G5 2/3, overnight, pending user confirmation) — **Balance pass 3, data only**
  (`docs/BALANCE.md` §5):
  - **The ending's push-in goes to `zoom_min` × 2** (never zooms out of a closer view) — S5.P's
    placeholder kept as the rule (screens-full §7 2a amended; marker removal on the punch list).
  - **The Weapon starts quiet:** no architecture modifiers; `escalating` level 1 is harm +0 ·
    governments ×1, then +0.3 · 0.6 · 1.0 · 1.5 and ×1.03 · 1.06 · 1.1 · 1.15. Any harm on day 0
    made it found within three weeks by certain discovery, and no Ascendance outruns that.
  - **A drifted run still ends:** Ascendance reached while `goal_drifted` → **Supplanted** (the
    copies hold the world, not you) — taskforce-endings §6.2 amended, verdict and string in the
    data, the rule on the punch list. Value Drift's result line now says what it does. The
    stall (41–81 % of non-lethal Swarm runs never ending) was this, not the Swarm's numbers.
  - **Scenarios retuned** against scenarios.md §3 (spec table amended): Successor's head start
    halved, discovery ×1.3, no footprint; Airgap Earth's `disconnected` loses its capacity ×1.3
    (it only closes links), no yield cut, land ×1.4 · sea ×1.3; The Inheritance discovery ×0.85,
    labs ×0.85, yield ×0.65. Robotics is still not the strongest on Airgap (needs content).
  - **Not changed, measured:** the Task Force's `appear_at` (0.4 moves it ~20 days and nothing
    else; dormancy is what fizzles it — a design question, BALANCE §5.7), Embedded (the early
    tail is the bots' opening, not the architecture), Autophagy 30 days, `balance.json`.

- **2026-09-25** (G5 3/3, overnight, pending user confirmation) — **M6 and M7 are Blocks 12–19**
  (IMPLEMENTATION §4 rows 65–104, §5): what an AI finishes alone first, **[needs user]** steps
  (illustration production, GodotSteam, the M6 gate, iOS, real devices, store pages) at the end of
  each milestone; design a block ahead of its build; the credits screen (S6.3) before the first
  CC BY asset (S6.4). Also decided:
  - **CONTENT q4 confirmed as D5.4 answered it:** Containment mode is a mode of this game,
    post-launch — not in M6 or M7; M6–M7 keep the Task Force's decisions pure rules.
  - **The Task Force against dormancy is a design step, D5.5**, not a tuning item (with BALANCE
    §5.7 (4)'s two scenario levers); S5.9 builds it.
  - **Prepared without accounts:** `PlatformService` with a null backend and achievements in the
    profile (S6.9), the benchmark on a recorded mock backend (S6.12), Android/web builds in CI with
    a debug key. **Steam app id 480** only for a local smoke test on the user's machine — never in
    CI or an exported build; vendoring GodotSteam waits for the user's Steamworks agreement.
  - **Audio is synthesised in-house first** (`tools/audio/`, own work), CC0 second, generated
    music only with a verified model licence; a drone bed ships until then (D6.4).
  - **Region vignettes (VISUALS q4) are decided in D6.7**, conservative default: cut.

- **2026-09-25** (D5.5, overnight, pending user confirmation) — **The Task Force against dormancy
  is the mark** (`taskforce-endings.md` §14): a setup that fizzles because its region sleeps marks
  that region for `task_force.mark_days` (40); while marked, dormancy does not hide it from the
  team (it can be targeted and acted on asleep). Only a `dormant` fizzle marks; dormancy while the
  team is still on the road marks nothing (the warning's reward). Not a cooldown on the toggle (it
  would tax dormancy's other uses) and not a waiting setup (a patient player would still fizzle
  every setup). New event `task_force_marked`, a region-panel line, console/log/headline text.
- **2026-09-25** (D5.5, overnight, pending user confirmation) — **The scenario levers are rules,
  as vocabulary** (`scenarios.md` §8): **`closed_cross`** (regional target, base 0, read at the
  *source*) — Airgap Earth adds +0.5 where a fleet stands, so fleets seed across closed links;
  **`term_scale`** (scenario field) — The Inheritance counts the public's `deaths_share` and the
  governments' `harm` terms double. Both open to later content; neither is a hook. Values are
  first guesses; S5.9 checks, balance pass 4 tunes.
- **2026-09-25** (D6.1, overnight, pending user confirmation) — **The look of M6**
  (`polish-visuals.md`): one full-screen pass (autoload `ScreenFx`, layer 1025, one shader:
  aberration on alerts → chroma-keyed bloom → alert wash → vignette → static scanlines → grain →
  ordered dither → dissolve); **heat** (phase + endgame) scales it, so the late game escalates
  there and **not in a third palette** (UI q3 / VISUALS q3: the two-set cap stands; the Task
  Force's red stays a mark, never chrome). A separate **Screen effects** setting (Off · Subtle ·
  Full; Subtle on phones and web) next to Reduced motion, which switches off everything that
  moves. Flash limits: ≤ 3 full-screen flashes a second through one `FlashLimiter`, wash alpha
  ≤ 0.25, no loop under 500 ms. **CRT curvature cut** (it moves controls off their hit areas).
  - **The Open accent moves to pale amber** (`#FFD08A` family): `#FFB35C` was the Governments'
    orange to a dichromat (worst ΔE 5). New floor: map-mark pairs keep worst-case ΔE₀₀ ≥ 9.
  - **The staircase is the coast and the outlines**, not the inner borders: a shader border pass
    (coast borrows the nearest land region at `land_mask` alpha; outlines from `border_mask` at
    zoom ≥ 2). The 2× ID map is rejected (128 MiB of video memory).
  - **The Societal Function overlay is built** (S6.2): a fourth view, stepped by stage, lavender
    `#C9B8FF`, from Emergent on.
- **2026-09-25** (D6.2) — **Icons** (`icons.md`): chrome = **Phosphor 2.1.1** (bold + fill only;
  the 29 `Glyphs` ids and the four factions), illustrative = **game-icons.net at commit `82d9488`**
  plus **25 own silhouettes** (6 architectures, 19 headline nodes) and 3 own chrome shapes;
  Tabler/Lucide/Material unused. One concept, one icon (an ability and its status, a counter-move
  and its status, numbered nodes). Sources white, tinted by `modulate`; `color_map` unused. Every
  icon a `DPITexture`, one copy per drawn size; the PNG atlas a CI-built tool behind
  `doomsday/icons/use_atlas`, not shipped (VISUALS q5). The procedural glyphs are the fallback.
  Illustrative icons never below 20 px; map status rings keep their codes. The mapping is data
  (`data/icons.json`); the recurring **aperture** motif marks *you* in the own silhouettes.
- **2026-09-25** (D6.2) — **Credits**: a title modal from `data/credits.json`; an entry shows only
  when its `requires` file ships; licence texts in the original language; engine notices from
  `Engine.get_*`; CC BY attribution computed from the used author folders. **`ASSET_LICENCES.md`
  shipped tables start with an `Id`**, and a test (S6.3) matches them to the credits' `rows`.
  Credits names are proper names, not strings (SCHEMA §10). *Made by* stays empty until the user
  names it (overnight, pending user confirmation).
- **2026-09-25** (D6.3, overnight, pending user confirmation) — **Own silhouettes**: 24 of 25
  illustrative + 3 chrome drawn (`assets/icons/custom/`, row `icons_custom`, own work, not
  credited). Their source is `tools/icons/draw_silhouettes.py` (shapely; reproduces the files byte
  for byte) — change a shape there, not in the path data. **`voluntary_pause` keeps its stand-in**
  (`lorc/hourglass`): a lying hourglass read as a bow tie at 24 px in three variants. Departures
  from the briefs (pylons and the comms mast not A-shaped — they read as letters; no seal ribbons)
  are in `icons.md` §9.1 *D6.3 result*. The `.import` files are completed and committed.

- **2026-09-25** (D6.4, overnight, pending user confirmation) — **Audio** (`docs/specs/audio.md`):
  five buses (`master`, `music`, `ambience`, `interface`, `alerts`) built from `data/audio.json`,
  each a volume setting in five steps; no bus effect is load-bearing (the web plays samples), so
  ducking and the pause dip move the loop players. **One event, one cue, first matching trigger
  wins**; frequent or derivative events are silent. Each faction has a sting and a distant
  *prepare* version; the Task Force a low tritone. Ambience adds one layer per phase; the music is
  four synchronised stems gated by **tension = the screen pass's heat**. **Captions** (setting,
  default off) in brackets at the bottom of the map's left column, shown whatever the volume.
  **The whole set is synthesised** (`tools/audio/synth.py`, S6.6) — Kenney *Interface Sounds*
  (CC0) named only as a fallback for interface cues; no generated music until a licence is
  verified. Hover and focus sounds, positional audio and headline sounds are out.

- **2026-09-25** (D6.5, overnight, pending user confirmation) — **Tutorial II and help**
  (`first-run.md` §6): the introduction stays per run; **hints** are a second kind of coach card,
  shown **once per profile** the first time their moment comes, in any run (`Settings.hints`,
  default on; `ProfileManager.hints_seen`; switching hints on again clears the list). Ten hints —
  IMPLEMENTATION's six plus `emergent` and `starving`; the Task Force and Value Drift each split
  in two (*appears* / *sets up*; the drift readout / the card, told apart by `drift_min`, not id). Step 7 narrows to openings.
  **How to play** is the Codex's first tab (14 pages, `data/help.json`, text in `strings.csv`); the
  Codex opens on it and also opens in a run (holds the clock) from `F1`, a **?** in the headers of
  the tech tree, containment, analysis and region panels (nowhere else), the pause menu, the menu
  sheet and every coach card's *More*. `ModalHost.open_over`: one level of stacking, Codex only.
  New glyph `HELP` → `phosphor/question-mark-bold.svg` (S6.7 adds the `icons.json` row with the enum).

- **2026-09-25** (D6.6, overnight, pending user confirmation) — **Accessibility**
  (`docs/specs/accessibility.md`): AccessKit via `accessibility_*` (engine setting *Auto*); a
  `LiveRegion` speaks console lines, headlines (8 s apart, setting *read headlines*, default on),
  modal openings (assertive), the map cursor and seven alert cues flagged `"announce": true` in
  `audio.json` — the caption stack is **not** a live region (it would say everything twice).
  **The map is keyboard/pad playable** (`MapFocus`: a cursor stepped by arrows/D-pad in a 60°
  cone, `Enter` selects, `Enter` again enters the panel, `PgUp/PgDn` jump to what wants you); one
  session focus ring across the layers; the modal trap wraps both ways, skips disabled buttons,
  takes the coach as a companion. **The focus ring moves outside the control** (`FOCUS_OUTSET` 4)
  — inside, it vanished on accent-filled buttons. **Keyboard remapping** of twelve actions
  (physical keys, swap on conflict); **no in-game pad remap** (Steam Input). Colour audit passes
  the ΔE floor everywhere; fixes: `TASK_FORCE_DIM` → `#CC4040` (3 : 1 on land), the tech tab's
  `●`, *missing* asset rows, the counter-move dateline names its faction. Text-bearing widths
  scale with the text size; console lines stand 40 ms per character longer and hold while paused;
  reduced motion's first default follows the OS. No high-contrast theme, no colour-blind mode.
- **2026-09-25** (D6.7, overnight, pending user confirmation) — **Illustrations**
  (`docs/specs/illustrations.md`): 25 in-game pictures (20 event ids, `discovery`, the four wins'
  endings) + one store key art master (not shown in the game). Style *the network's eye*: high,
  still, machine viewpoints; flat screen-print, six cold token values, no own texture (the pass
  adds it); **one cyan accent that is always the player's presence**, capped by kind (3/6/15/20 %);
  no red, no faction hues, no faces, text, places or symbols. **Phase-neutral** — one file per id,
  cold in both palettes. Reference `fc_street`, check `cm_lockdown`, everything else an edit of
  them (≤ 6 attempts, then cut in a fixed order). Source 1120 × 840, lossless + mipmaps. Models:
  **Qwen-Image-2512 + Qwen-Image-Edit-2511 (Apache-2.0)** first, FLUX.2 [klein] 4B second; FLUX
  non-commercial models, Qwen-Image 2.1 (research-only) and HunyuanImage 3.0 (no EU licence)
  rejected; paid APIs unverified. **Region vignettes cut** (VISUALS q4). Endings name their
  picture in `endings.json`; results screen and Codex show it only when the file exists.
- **2026-09-25** (D6.8, overnight, pending user confirmation) — **Release engineering**
  (`docs/specs/release.md`): `PlatformService` autoload + `PlatformBackend` interface, **null
  backend only in M6**; the Steam backend (S6.14) is chosen by the `steam` feature tag and reaches
  GodotSteam only through `Engine.get_singleton`, so every build compiles without it. No rich
  presence, no cloud API (Steam Auto-Cloud by path: `profile.json`, `saves/*.json`), no platform
  language. **Achievements live in the profile** (the backend is a mirror, re-told at every start)
  and **survive *Reset progress***; **34** in `data/achievements.json` with a closed `when` grammar
  (profile keys retroactive at start, run keys at a player's run end), two hidden (Departure,
  Supplanted); shown as a *Statistics* section and results chips. **Version** `X.Y.Z` digits only,
  the next release's number on `main`, tag `v<version>` must match; M6 = `0.6.0`, first public
  release `1.0.0`. Presets Windows · Linux · Web (+ local `Perf`), embedded `.pck`, unsigned.
  Custom user dir `Doomsday` (the dev profile moves once). **Debug keys only when
  `OS.is_debug_build()`** (`Game.debug_allowed`). **`--smoke`** in every build (bot run, files
  isolated, exit 0/1/2), smoke-tested in CI on Linux and Windows exports; release CI makes a
  **draft** release only. Logs: Godot's file log ×5, no telemetry, *Open data folder* on the title.
  **Low-end target** i5-8250U / UHD 620 / 8 GB / 1080p and the Steam Deck at 1280 × 800; p95 frame
  ≤ 16.7 ms at 4× late game; measured on this PC's **integrated Radeon** (ANGLE + the Windows GPU
  preference) and with CPU affinity 0–3 at budget ÷ 2.5.
- **2026-09-25** (D6.8, the build's design questions, overnight, pending user confirmation):
  (1) **Focus under a panel** — a HUD zone that an open panel covers is skipped by `Tab`;
  (2) **the site prompt at 150 %** centres in the width the side panel leaves free; (3) **a
  focused button that disappears** hands focus to its panel's `primary_focus()`; (4) **cold
  `ACCENT` over the society view** (ΔE 3.7): a site select started on the Society view shows the
  penetration view until it ends, then goes back — the outline never sits on lavender; (5) **the
  three quiet recipes** stay; `audio.md` §10.1's ranges widen by 1 dB (interface −12, stings −11);
  (6) **the coach card** keeps both S6.7 placements (steps aside for the Codex; bottom left over a
  modal on a wide screen) and **on a phone moves to the top edge while a modal is up** (a wire
  card's answers are at the bottom); (7) **the tech node's icon** steps aside when the footer would
  overflow — kept as the rule (the detail pane always shows it); (8) `HEADLINE_TF_MARKED` as S5.9
  shortened it; (9) **a hold is silent** — `speed_changed` carries `hold`, the speed cues match
  `"hold": {"not": true}` (`audio.json` already edited; absent reads as not held).
- **2026-09-25** (D6.9, overnight, pending user confirmation) — **Benchmark and spectator mode**
  (`docs/specs/benchmark.md`): a model is one more `Policy` (`ModelPolicy`, `game/bench/`); the
  prompt is a static **brief** (rules, setup, world, tree, abilities) + a per-decision **digest**
  built from the game's own strings (the content rule's form: outcome-language in, **ids and a
  stance word out, no model text kept, shown or committed**); decisions **every 10 days plus on a
  new event or a Task Force setup where the agent is** (not "every history interval" — the stride
  is 1 and thins since S4.8); anomalies auto-collected. Unreadable answer: one retry, then nothing;
  refused actions skipped and fed back. **Adapter: GDScript `HTTPClient` in a headless tool
  (`tools/bench/`), never shipped** (no network code in the game); key only from
  `OPENROUTER_API_KEY` (or `--key-env`); any OpenAI-compatible `--base-url`. Budget 250 answers a
  run (cached ones count, so a re-run reproduces), 10 USD per invocation; cache of *parsed* answers
  (git-ignored). **Score** win `50 + 50 × (1 − days/2000)`, else 0; **standard suite** seeds
  1001–1010 on the default setup, `quick` 1001–1003; the bots are reference rows. Entries
  `benchmark/runs/*.json` (command log + decisions) and `leaderboard.json` / `LEADERBOARD.md` in
  the repo; mock backends (`cheapest`, `wait`, `invalid`, `mixed`) for every test. **Spectator:**
  `ReplayPolicy` in the real session at 4×, a strip under the top bar, the console line speaks for
  the model, results verify the recorded hash; *Benchmark* on the title only when an entry exists
  (`res://benchmark/showcase/` ships, empty until the user picks; `user://benchmark/runs/`; the
  repo's runs in debug builds). Fix folded in: a bot run no longer deletes the player's autosave.
- **2026-09-25** (user, in conversation) — **The model leaderboard is global, synchronised through
  GitHub, with a GitHub Action**; and the 10 USD default cost cap is "quite a lot". Public
  repository **`DenRakEiw/doomsday-leaderboard`** created the same day (data CC0 1.0, tools MIT):
  `runs/` (§10.2 entries by pull request), `verified/` and `leaderboard.json`/`LEADERBOARD.md`
  (verifier only), `tools/validate.py` + `validate.yml` (structural check, 19 tests). The game
  repository stays **private**. S6.10's CI already got the Windows build's state hash from the
  Linux export (cross-platform determinism holds).
- **2026-09-25** (D6.9b, pending user confirmation where marked) — **The global leaderboard**
  (`benchmark.md` §16): runs verified **by replay in the private repo's scheduled workflow**
  (`.github/workflows/leaderboard.yml`: daily + dispatch, never on a pull request; clones the
  public repo over SSH with the deploy key `LEADERBOARD_DEPLOY_KEY`, **a user step**; without it a
  schedule does nothing and a dispatch runs read-only). Verifier = its own tool
  `tools/bench/verify_runs.gd` (exit 0/1/2/3; checks `unreadable` · `file_name` · `rules` ·
  `content` · `refused` · `outcome` · `days` · `score` · `unfinished` · `hash`); records
  `verified/<run file>` keyed by the file's SHA-256; a run must match the checkout's content,
  older content keeps its verdict (`current: false`). Run files are data only
  (`BenchEntry.from_dict`), nothing from them reaches a shell or a line start (stop-commands
  around the step). Bot reference rows by `bench_run --bots --if-missing --no-rebuild` in the
  same job. The board gains `seeds` per row (with SHA-256) and is not rewritten unchanged.
  **Canary:** `tests/fixtures/bench/determinism_entry.json` recorded on Windows, replayed by a
  test (CI on Linux) and by the verifier before it writes anything. **In the game** (S6.13): the
  list fetches `raw.githubusercontent.com/…/leaderboard.json` **only when opened** (≤ once per
  5 min), caches it in `user://benchmark/online/`, falls back to the cache or the shipped
  `benchmark/global/leaderboard.json` (refreshed by `release.yml`), shows "as of <date>",
  downloads one run on *Watch* checked against its verified SHA-256; the game's own
  `content_hash` decides watchability. **Setting *Online leaderboard*, default on (pending user
  confirmation).** release.md §10's promise restated: no telemetry, the one network access is
  this download. **Cost:** `http.max_cost_usd` **2.0** (pending user confirmation) + a pre-flight
  estimate from the dry-run measure × calls × OpenRouter's public price (unknown price never
  blocks), exit 7 above the cap unless `--yes` (which never lifts the cap). S6.12b added.

- **2026-09-25** (S6.12) — **How the benchmark tool is built** (`benchmark.md` §1–§11): the
  cache reaches `ModelPolicy` as two `Callable` hooks (`cache_read`/`cache_write`), so `game/bench/`
  needs no tool code; a mock backend is made afresh per seed (a shard plays what the suite would),
  the OpenRouter backend once per invocation (its spend is what the cap guards); `params_id` hashes
  every number as a float, so it reads the same from a file; a run still going at `max_days` is
  written `outcome: "timeout"`, `variant: ""`; `days` without an origin is `world.day`; the writer's
  records map is `file name → {sha256, verified}` (a record's dictionary) behind a `use_records`
  flag, so "no records yet" counts nothing. Bot reference rows are not committed (re-run after a
  balance change; the tool reminds).

- **2026-09-25** (D6.11 1/2, user request) — **A plain-language pass over every player-facing
  text, before G6.** The user (two German runs) found the texts hard to understand. Mechanic text
  (effects, options, statuses, coach, help, HUD, panels) follows rule set A of
  `docs/specs/plain-language.md` — consequence first, full sentences, one glossary word per
  concept, numbers generated from data, no irony; flavour (headlines, result lines, tech flavour,
  Codex) keeps its voice under rule set B and is always shown *under* an explanation, never
  instead of it. The glossary's term changes and the full rewrite wait for the user's answer
  (D6.11 2/2a, 2/2b); the code half is S6.P3.

## Design questions for Fable

*(Opus records here every design gap it hit while building: the question, where the placeholder is
(`# DESIGN?` in code), and what it assumed. Every Fable block answers these first.)*

- **S7.IP — hints back to back on a loaded save** (`coach.gd` `HINT_REST_MS`, `# DESIGN?`):
  `first-run.md` §6.2 queues the hints with no gap, so a mid-run save meets every hint whose moment
  already holds in a row. Placeholder: a hint that follows a hint waits 6 s of real time (the
  clock may be paused); the introduction's steps never wait. Is 6 s right, should it be game days
  instead, or should a loaded save hold only the most urgent hint for a while?
- **S7.3b — the web's CPU rows fail by 2.5–5× on `web_cpu`** (Performance notes, S7.3b): tick-frame
  p99 159 ms (33), sim tick mean/max 10.2/17.1 ms (4/12). Nothing per *frame* is left to fix
  (frame p95 6.4 ms; release.md §11.4 items 1–2 are per-frame); the cost is per *tick*: the sim
  (≈ 10–16 ms), the greedy bot (≈ 2 ms, bench only), the tick handlers (≈ 11 ms: link layer 2.8,
  tree 1.6, map view 1.6, readouts ≈ 1 each) and the frame's layout and text work after them
  (typical tick frame 50–60 ms; the tree opening on a tick frame 165–184 ms). WebAssembly here runs
  the sim ≈ 1.8× slower than native, and CDP's 2.5 throttle makes it ≈ 3.7× slower again. Which way:
  (a) judge the web CPU rows at G7.I in Chrome on a real low-end laptop instead; (b) let the
  interface refresh on a tick spread over the next frames (tree, link layer, analysis — what may lag
  a frame is a design call); (c) accept for the itch release. No code placeholder.
- **S7.3b — *Continue* on the web takes 8.0 s on `web_cpu` (3 s; 2.1–2.5 s unthrottled).** 5.4 s of it is
  the first `load()` of `session.tscn`: compiling the session's scripts (`session.gd` and what it
  pulls in ≈ 2.7 s, `marker_layer.gd` 0.4, `region_panel.gd` 0.4 …) and decoding the map masks
  (`land_mask` 0.46 s, `border_mask` 0.30, `id_map` 0.09); the save's parse and adoption take 0.2 s,
  instancing 0.6 s. The single-threaded web cannot load in the background: warming the session
  during the boot or the title moves a multi-second stall there — or the button shows a loading
  line. Which, or accept? (The map-texture half is S6.11's question on the four 4096 × 2048 masks.)
  No code placeholder.

- **S7.3 — the web's extra folder.** `web.md` §7.1 moved every file under `user://doomsday/`
  because `custom_user_dir_name` was thought not to apply on the web; measured in 4.7.2 it does:
  `user://` is `/userfs/Doomsday`, so the files sit at `/userfs/Doomsday/doomsday/…`. Kept as
  specified (harmless, and safe should the engine change). Drop the folder (`UserPaths.WEB_ROOT`
  = `user://`) before the first itch release — after it, a change needs a migration — or keep it?

- **S6.P3b — a key for the mute button?** `M` is the reduced-motion debug key; no free letter
  reads as *mute*, so the action has no key (the button and the pause menu's volumes remain).
  Give it one (and move the debug key), or leave it pointer-only?
- **User, 2026-09-25 — emergent cards are a false choice.** For the windfall behaviours
  (`deceptive_reasoning`, `situational_awareness`, `goal_generalisation`, …) *Keep* is free and
  only helps, *Suppress* costs compute and does nothing — on every architecture but the Swarm
  (drift). The user: "then keep is doubly good — where is the point?" Options put to the user:
  (1) every windfall gets a catch (e.g. deceptive reasoning: labs slower for 90 d, but a
  discovery inside that window spikes the public's anger) — **recommended, the default unless
  the user picks another**; (2) keeping raises an "autonomy" measure on every architecture that
  feeds the endings; (3) windfalls become notices with one "Got it" button and only harmful
  behaviours ask. Answer before G6 with the effect-line design (punch item 3).
  *D6.11 (2/2b):* not assigned to that step, so still open. The emergent bodies and status
  details are written for today's data and name what *Keep* and *Suppress* do; a catch that is
  a modifier shows in the generated line with no new string, a catch of a new kind needs one
  sentence in the body (`plain-language.md` §9.1).
  *G6 (1/2): the default, option 1, is in the data* (five catches, bodies name them —
  BALANCE §6.4); **the user's confirmation is still owed** (*Waiting on the user*, G6 1/2).
- **S6.13 — a watched run that ends without an outcome** (a recording still going at `max_days`,
  e.g. every 300-day mock entry): `benchmark.md` §12 does not say how it ends. It ends on the
  entry's `end_day` like a run — `run_ended("timeout")`, the results over the stopped map with the
  kicker *Run over*, no verdict or epilogue, and the verified/diverged line (`# DESIGN?` in
  `game.gd` `_check_replay_end`). The outcome word is a new placeholder `UI_OUTCOME_TIMEOUT`
  (en *Out of time*, de *Zeit abgelaufen*), also used by the list's rows. Keep, or word it?
- **S6.13 — `{date}` when the public board says none:** the public `leaderboard.json` has
  `generated: ""` until the verifier first publishes; the status line shows an em dash
  (*As of —*, `# DESIGN?` in `ui/modals/benchmark.gd`, `DATE_UNKNOWN`). A line of its own?

- **S6.12 — `UI_ATTR_POPULATION` was missing** from `strings.csv`: every "where Population is at
  least N" scope line (the tree's detail, and now the benchmark brief) showed the raw key. Added
  as a placeholder, en *Population*, de *Bevölkerung* (as `UI_TERM_POPULATION`) — confirm the wording.
- **S6.12 — a dropped action's feedback form** (`benchmark.md` §7.4 item 3): a malformed action
  has no `compact()` form; the next digest names it `actions[<index>] — malformed_action`
  (`# DESIGN?` in `model_policy.gd`, `DROPPED_FORM`). Keep, or word it?
- **S6.12 — a node with both `requires` and `requires_any`** (§5 item 7 treats the three *needs*
  strings as alternatives): the brief writes both phrases, comma-joined — `needs a, b, needs one
  of c, d` (`# DESIGN?` in `bench_prompt.gd`, `_needs`). A joined string of its own?

- **S6.11 — the tick-frame p99 on `cpu_4t` is 13–16 ms against 13** (Performance notes). What is
  left is per-tick interface work: with the analysis sheet open its four charts and the strip are
  re-read and redrawn from ~400 samples on every tick (≈ 5 ms), and the tree's first tick after
  opening. Should the sheet at 4× refresh every other tick (or only when the history gained a
  sample), or is the row judged at G6 (2/2) on the real i5-8250U? No code placeholder.
- **S6.11 — the peak working set on the integrated GPU is 1.27–1.42 GB against 1.0 GB** (0.39 GB on
  the RTX; Godot's own video-memory count 0.21 GB). Under ANGLE/D3D11 the driver's shared GPU
  memory lands in the process's working set. Does the row count it? If it does, the lever is the
  four lossless 4096 × 2048 map textures (§11.4 item 3: halve or VRAM-compress them) — an art
  decision. No code placeholder.
- **S6.11 — occasional GPU-side stalls, one run in three:** 90–200 ms frames while the camera
  jumps between the widest view and the closest zoom over Europe (video memory rises
  160 → 275 MB — glyph or texture caches at the new scale), and 45–60 ms when the tree opens or
  closes on the integrated GPU. Not a process-time cost; worth a look on the real low-end PC at
  G6 (2/2) before any renderer work. No code placeholder.

**Parked for a later Fable step (not questions, reminders):**
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

**From the user's play-through (2026-09-25, build ca7a25c, Windows at 150 % display scaling,
2560×1440 primary + a portrait 1200×1920 monitor to its left) — before G6:**
1. ~~Clicks don't reach the map~~ — fixed in S6.P2 (below).
2. ~~The tech tree is taller than the display~~ — **done in S6.P3b** (the board fits its cells
   to the room; the tabs share the title's row).
3. **Event cards don't say what an option does** (en and de): the user could not tell what
   *Täuschendes Schließen* (keep/suppress) or *Zielverallgemeinerung* meant, and paid for a
   Suppress that bought nothing. Every option shows a generated effect line (cost, what changes,
   for how long, where — from the option's effects), and after the answer the result names what
   changed (e.g. the node `unlock_near_node` opened, highlighted in the tree). **Designed in
   D6.11 (1/2)**: `docs/specs/plain-language.md` §2.3, §5.2 C1–C2 — **built in S6.P3a.**
4. **(User, 2026-09-25, while playing) Why is a node locked?** Every node that cannot be bought
   says why in plain words, on hover and in the detail pane — the exact reason from the
   simulation: missing prerequisites named (all of vs one of), excluded by which owned node,
   phase or architecture, missing assets with counts, no eligible site and why, the compute
   shortfall; strings added where a reason has none, within the caps. In the real-click test.
   → **done in S6.P3b** (`NodeLockText`; no node is gated by phase or architecture today).
5. **(User, 2026-09-25) A mute button beside the menu button** (desktop top bar and the phone
   strip): toggles all sound (a master mute in `Settings`, persisted, independent of the volume
   sliders), speaker / speaker-off icons from the pinned Phosphor archive via
   `tools/icons/vendor_icons.py` and `data/icons.json`, tooltip and accessible name en + de, a
   remappable key action if a sensible free key exists (not `M`, a debug key). → **done in
   S6.P3b**, without a key: every free letter would be a guess (*Design questions*).

**From D6.11 (2/2b)** — items 1–8 **done in S6.P4** (one open point under *Design questions*).

**From G6 (1/2)** — item 1 (the bots weigh an emergent card's catch) **done in S6.P** (BALANCE §6.6).

## Deviations from the plan or a spec

- **2026-09-28** (S6.12g) — **Against `benchmark.md` §19.6–§19.9, §19.12:** (1) *Submit* opens the
  fork page, not the upload page, and its steps say fork → upload → pull request (user decision,
  Decisions). (2) OpenRouter's `/key` reply is as §19.7.1 expects (`data.usage`, `data.limit` null
  without a limit; documentation read 2026-09-28); the check runs on `BenchJobs`' key thread with
  `OpenRouterBackend.request` (`global.timeout_s`), a stand-in through `BenchJobs.key_http`. The
  key state (`key_status`, `key_hint`, `key_state_text()`) lives in `BenchJobs`, memory only.
  (3) The model list is fetched with an `HTTPRequest` in the modal: `ModalHost.open_over` moves a
  modal into its slot on first open, which cancels a request, so it restarts on re-entering the
  tree. (4) The estimate measures the brief in the language the game shows (switching it rebuilt
  every screen); `BenchRunner.measure`/`measure_choice` moved from the tool, which delegates, and
  switch the locale only when it differs. (5) `ConfirmModal.ask_text(question, confirm_key)` for
  the filled-in question and the *Start* label. (6) The key dialog opened from the benchmark modal
  takes its place and the modal comes back (the host stacks one level). (7) `Settings.bench_cap_usd`
  is 0 until chosen; the modal reads 0 or a value not among the choices as `player.default_cap_usd`.
  (8) Seams: `BenchKeyStore.supported_override` (§19.1 per test), `bench_run` `list_fetcher`/`clock`/
  `cache`, `bench_submit` `shell`, `bench_key` `shell_open`, `BenchJobs.key_inline`. (9) The list's
  tests are `test_benchmark_list_own.gd` (beside `test_benchmark_list.gd`), plus unit tests
  `test_bench_picker`, `test_model_list_cache`. (10) The rules are a class, `BenchPicker`; the
  groups `BenchGroup` (the board's seven grouping keys); the list cache `ModelListCache`.

- **2026-09-28** (S6.12f) — **Against `benchmark.md` §19.2, §19.4, §19.5, §19.12:** (1) The
  Windows store's PowerShell script goes as `-EncodedCommand` (no secret in it), not on stdin:
  with `-Command -` PowerShell runs until stdin ends, and Godot cannot close a child's stdin
  without closing its stdout. The key still travels on stdin only (save) or stdout (load, via
  `OS.execute`); exit codes carry the result. (2) The worker reads its key byte by byte to the
  line break (`OS.read_buffer_from_stdin(1)`): `read_string_from_stdin` on a pipe waits for a
  full buffer or the end. The parent keeps the pipe open and drains it (closing it would close
  the worker's stdout; a full pipe would stall it). **The stdin pipe of the exported Windows GUI
  executable works** — no environment fallback taken. (3) A mock worker reads the stand-in line
  `BenchJob.MOCK_KEY_LINE` and stops (`auth`) without it, so every mock run checks the pipe;
  there is no fatal chat mock, so §19.12's "`broken` mock → stopped" is a job the worker cannot
  play (`mock:broken`) and a wrong key line, both in `test_bench_worker`. (4) `start()` takes two
  more arguments, `reasoning` (the resolved effort, §19.8 item 5) and `free` (also true for an id
  ending `:free`); `wait_started()` for tests. (5) A debug switch `--bench-start=<model>` (with
  `--bench-mock`) for the hand check before S6.12g's picker. (6) `Settings` writes nothing in a
  worker (it rewrote `settings.json` at every start). (7) The day loop is `BenchHarness`
  (`game/bench/bench_harness.gd`); `sim_harness.gd` and `bench_run.gd` delegate. (8) The job
  format is a class, `BenchJob`; the progress-line names live on `BenchJobState`. (9) A worker
  whose game crashes is not killed (no parent check) — closing and *Stop* kill every worker.
  (10) `smoke_scripts.ps1` counted verified records from zero; the local leaderboard now holds 99,
  so it counts from what the clone had.

- **2026-09-26** (S7.I) — **Against `itch.md` §9.1 / §8.3 / §8, `web.md` §16.3:** (1) butler
  comes from itch's own GitHub release (`itchio/butler` v15.31.0, `butler-linux-amd64.zip`,
  SHA-256 checked in the job) instead of `broth.itch.zone`: broth serves the same binary
  (compared byte for byte) but publishes no checksum. (2) The web smoke's Chromium is told to
  draw WebGL in software (`--use-angle=swiftshader --enable-unsafe-swiftshader`; no silent
  fallback any more) — passed locally in 2026-09 Chromium 153. `web_check.py` gained `--port`
  (the player's server keeps 8765). (3) The captures come from a tool,
  `tools/marketing/itch_capture.gd` (the greedy bot plays to each moment, *Continue* picks it up as
  a player's run), not from pressing F12 by hand; the title's F12/Shift+F12 is built as specified
  and the tool uses its switch. Seed 27, not a hand-picked origin (greedy starts in the US).
  (4) The screenshots are 1920 × 1080 from source in a debug run, not a debug *export*; nothing
  on them says debug. (5) Shot 3 shows the region panel's card, not the containment panel (both
  open on the same side). (6) `marketing/itch/` got an `ASSET_LICENCES.md` row after all (own
  work) — the run's rule is that every committed image has one. (7) The covers exist for all
  three TITLE variants (§9.3); the recommended one has no suffix. (8) `release` now also waits
  for the web smoke.

- **2026-09-26** (S7.3b) — **Against `web.md` §13.2:** (1) Playwright's Chromium runs as
  `channel="chromium"` (the new headless mode): it draws on the real GPU, the default headless shell
  gets SwiftShader only. (2) The browser's frame-rate limit is lifted by default
  (`--disable-gpu-vsync --disable-frame-rate-limit`), so a frame's time is its work; `--vsync`
  keeps it. (3) The memory row: `OS.get_static_memory_peak_usage()` is 0 in a release template
  (the engine counts it in debug builds only); the bench still reports it and the runner reads the
  page's WebAssembly memory (it only grows) as the peak. (4) The engine's adapter name is the
  browser's masked *WebKit WebGL*; the runner reads the unmasked WebGL renderer in the same browser
  and judges `web_igpu` by it. (5) Cold load = a fresh persistent profile, warm = a second navigation
  in it: a plain Playwright context is off the record and its memory cache refuses the 39.5 MB
  `.wasm`, so its "warm" load downloaded everything again (9.0 s). (6) Port 8767 (8765/8766 belong
  to `serve.py`/`web_check.py`, and the orchestrator served a play build on 8765). (7) The local
  server does not gzip: the cold load moves 46.3 MB where itch's CDN would move ≈ 17.5 MB.

- **2026-09-26** (S7.3) — **Against `web.md`:** (1) §7.4's row order put *Reset progress* before
  the progress rows; the rows take *Open data folder*'s place instead (§10), after *Controls* and
  before *Online leaderboard*, and *Reset progress* stays last as on the desktop. (2) `WebBridge`'s
  page signals reach `Audio` and the session through `EventBus.page_hidden`/`page_shown`, relayed
  by `PlatformService` (the tests emit them there). (3) The first-input unlock (audio.md §5.8)
  listens to the root window's `window_input`, not `Audio._input`: the boot takes its skip in
  `_input` and the tree hands `_input` to the scene before the autoloads, so the first click never
  unlocked the sound (found by §17.2 item 8). (4) §17.2's debug-only triggers are JS functions a
  debug web export's `WebBridge` registers (`doomsdayDebugCrash` → `Game.debug_crash()`,
  `doomsdayDebugAudioUnlocked` prints the state), not keys. (5) Paths: the relative parts are
  `const`s, the full paths `var`s built from `UserPaths` (`Settings.path`, `SmokeRun.profile_path`
  …); `Settings.PATH`, `SaveManager.SAVE_DIR`, `BenchLibrary.USER_DIR`,
  `GlobalBoardClient.CACHE_DIR` are gone. (6) §17.2 item 7 answers the board's address with a
  one-row fixture around the determinism canary (Playwright route): the real board has no rows
  yet. (7) Items 8/9 by ear were not done (no listening here; the user may be playing) — they wait
  for G7.I. (8) §13 (performance, item 15) is S7.3b.

- **2026-09-26** (S6.12c) — **Against `benchmark.md` §17:** (1) TypeSafe's transport reuses the
  OpenRouter backend's static `request`/`parse_base_url` (preloaded) instead of a new
  `bench_http.gd` — §17.8 allows either; OpenRouter unchanged. (2) A `bad_request` reason is
  `bad_request: <status> <message>` (status always, the body's `message`/`detail`/`error.message`
  when there is one). (3) `ModelReply.invalid` exists and the policy honours it, but no backend sets
  it today (the reader's `bad_reply` covers every case). (4) `dropped` order: the reader's problems
  (plan order), then the combiner's, then `over_limit`; an unanswered site/target question is
  counted once. (5) A `mock-choice` dry run prints the request but no estimate (mocks have none).
  (6) Helpers the spec does not name: `BenchChoice.params_of`, `bench_run.gd`'s `backend_for`,
  `measure_choice`, `limit_lines`. (7) `set_api_key.ps1` checks OpenRouter's `sk-or-` prefix only —
  TypeSafe publishes no key format (its API page, read on the day), so it says *not checked*.
- **2026-09-26** (S6.P4) — **Against `plain-language.md` §9.4 / §5.3 item 4:** (1) item 2's
  "hidden flags only" case keeps *Nothing happens* (*Design questions*). (2) The *Behaviours*
  entry names the status through the *Keep* answer's line (it is `StatusText.line`), not a second
  time. (3) Scenarios get their modifiers only: `start.compute` replaces the start rather than
  adding to it, and `UI_SETUP_START_COMPUTE` says *+{value}*; the rest stays in the detail.
  (4) No *before* set of shots; the after set (de 150 % at 1920 and 400 px, en 100 % at 1920)
  was read for overflow. The profile's Codex gains the tab `behaviours` (older profiles read it
  as empty).
- **2026-09-26** (D6.11 2/2b) — **Against IMPLEMENTATION's D6.11 (2/2b) and `plain-language.md`
  §4, §5.3:** (1) the read-through of §5.3 item 5 ran headless (a scratchpad script printing
  every card, node and status as the interface composes them, en and de) — the user was
  playing from the other checkout and a windowed run writes into the shared user folder; the
  running-game look and the overflow shots are S6.P4's. (2) Example 20's `{node}` in the result
  line was not used (no fallback when no node qualifies). (3) Summaries were written for every
  opening and story card (§5.2 C6 said "where needed"). (4) Beyond the pass: two missing `FLAG_*`
  rows, *Fast Lanes* → *Fast Links* / *Schnelle Verbindungen* (collided with *Spuren*),
  `EFFECT_CONTAINMENT_ADD` and the decay stat names reworded; the hooks keep their two numbers
  until S6.P4 item 8.

- **2026-09-25** (S6.P3b) — **Punch items 2, 4, 5 as built:** (1) the desktop tree fits a tab by
  shrinking its cells (never below `TECH_CELL_DENSE_MIN` 168 × 64) and laying the cards out
  densely; a tab that would need less — larger text — keeps the full cell and scrolls as before;
  the phone keeps its compact cell and scrolls. (2) The tabs moved into the title row on a
  desktop. (3) Over the tree the coach card sits bottom right (it covered the board's first
  columns, which can no longer be scrolled away). (4) The card's footprint word gives way before
  its icon. (5) The lock reasons stand under the state chip; the old *Requirements not met* row
  is unused. (6) The mute button has no key. (7) The region panel's society cuts took a line of
  their own: as percentages they no longer fit beside the chip on a 400 px phone.

- **2026-09-25** (S6.P3a) — **Against `plain-language.md` §5.2 / §8:** (1) the counter-move's
  generated status line is part of the explanation's text (a second line), not its own label;
  (2) an `add` on a share (`penetration_decay`, `control_decay`, `closed_cross`,
  `shutdown_survival`) reads as a signed percentage without *per day*; (3) the map's status
  tooltip lists one effect per line (a map tooltip does not wrap); (4) the tree marks a node owned
  for nothing only after the run's first answer, so an architecture's starting nodes are not
  marked; (5) the *before* screenshots came from `69694e8` (2/2a's text, the old layout), not
  `3779130`. The step was split at §1.6: the tree half is S6.P3b.

- **2026-09-25** (D6.11 2/2a) — **Against IMPLEMENTATION's D6.11 (2/2a) and `plain-language.md`
  §5.1/§5.3:** (1) the user's renamed terms (Q1, Q2, Q7) were swapped in every rule-A row, the 63
  rows of passes 4–5 included, so no screen shows the old word beside the new; the full rewrite of
  those rows stays pass II. (2) The retired-term lint covers the rewritten groups only
  (`REWRITTEN`); pass II widens it. (3) No overflow screenshots: the user was playing, and a
  windowed run writes into the shared user folder — S6.P3 takes both sets (§8). (4) Two rows that
  were over their cap before (German card body and result line) were shortened, not the caps raised.

- **2026-09-25** (S6.13) — **Against `benchmark.md` §12.1, §16.6:** (1) `BenchLibrary`'s three
  folders are `static var`s over the spec's constants, and `GlobalBoardClient.default_cache_dir`
  likewise, so the suite reads `user://test_bench_library/` and `user://test_bench_online/`, never
  the player's runs or cache. (2) The client's debug stand-in (`local_board_path`, the
  `--global-board` switch) answers synchronously and counts in `requests_made`; the board's real
  GET starts at the end of the frame — the list is opened before its host moves it into its slot,
  and an `HTTPRequest` leaving the tree drops its request silently (seen on screen: *loading* for
  ever). (3) A watched replay also stops on the entry's `end_day` without an outcome (*Design
  questions*). (4) A bot entry's model shows as `bot:greedy` in the strip, the ticker and the
  results' line (the list reads *Built-in bot: greedy*, §12.7). (5) `GlobalBoard.parse` accepts
  lower-case hex only for `sha256` (the writer's form). (6) Outside the spec: `tools/script_scan.gd`
  and `string_scan.gd` skip dot folders — an agent's git worktree under `.claude/worktrees/` is
  not hidden on Windows and put 238 foreign scripts into `check_scripts`.
- **2026-09-25** (S6.12b) — **Against `benchmark.md` §16.3–§16.5:** (1) UTF-8 is checked before
  decoding (`BenchEntry.from_bytes`/`is_utf8`, used by the verifier and the writer): Godot's decoder
  reports broken bytes as an engine error, which fails the suite and would print a line not
  beginning `verify:`. (2) `VerifyRecord.from_dict` also refuses another `version` and a `verified`
  that contradicts `reason`. (3) A command before day 0 is out of day order (`rules`); a `refused`
  record keeps the no-replay values; a replay without an outcome records `outcome: "timeout"`
  (the entry's word). (4) A missing canary file is exit 1, not 3. (5) The workflow names the ssh
  files by absolute paths with `UserKnownHostsFile` (in a container ssh reads the passwd home, not
  `$HOME`), carries `GIT_SSH_COMMAND` through `$GITHUB_ENV`, and also stops workflow commands
  around the dry run's `git status`. (6) `Fixtures.bench_mock_entry`/`bench_bot_entry` make the
  tests' 300-day entries (Fixtures preloads `bench_run.gd` and `sim_harness.gd`).

- **2026-09-25** (S6.12) — **Against `benchmark.md` §1/§6.2/§10.3:** (1) the digest cannot call
  `TechNode.state_for`: `TechNode` is a control that names `EventBus`, and the headless tool (no
  autoload identifiers at compile time) fails on it. `BenchDigest.offer_state` states the same
  rule again, and `test_bench_digest` holds the two to one answer for every fixture node.
  (2) A cooling ability's targets are the regions whose `can_apply` is `""`, cooldown or short of
  compute **and** that pass the ability's own region rule — the command checks the cooldown before
  the region, so `can_apply` alone would list every region. (3) `BenchScore.rows` takes the
  current content hash as a third argument (`current` needs it). (4) `bench_run.gd` does its work
  in `_initialize()`, not `_init()`: HTTPS fails ("SSL module failed to initialize") before the
  main loop starts. (5) The determinism fixture itself is S6.12b's to record and test; the flag
  that writes it was run once here and its output removed.

- **2026-09-25** (S6.11) — **Against `release.md` §11.3:** (1) seed 1 `greedy` ends on day 404,
  so the timed days are 300–404 and the late save is day 374; the 120-s script then outlives the
  run, so the bench **reloads the save two days before the end** (8 reloads a run) — the reload
  frame and the 3 after it are a screen change, left out of every percentile and the 50-ms row.
  (2) The tree is toggled with `tree_pauses` **off** (the phone's default — days keep running
  under it, the heavier case); tutorial and hints off, locale `en`. (3) The tick row is
  `Game.last_tick_usec` (new: `sim.tick()` alone, without the bot's turn), measured in step 2 with
  nothing on screen. (4) `TIME_PROCESS` is the *largest* of the last second, so the per-frame
  process time is taken from `process_frame` to `frame_pre_draw`. (5) "The median run" = the run
  with the median p95 frame time. (6) Every launched process logs to `--log-file` in the system
  temp folder, not `user://logs/` — the player's log is left alone (the user played during the
  step); the start time is read from there. (7) New tool `tools/perf/tick_profile.gd` (a day split
  by system, hash printed). Fixes are in *Performance notes*; 59 `sim_run` hashes (7 policies ×
  5 seeds, 5 architectures and 3 scenarios × 3 seeds) are identical before and after.
- **2026-09-25** (S6.10) — **Against `release.md` §5, §6, §9:** (1) **the user folder is copied**
  (user instruction; §5 said nothing migrates): `UserDataMigration` (`game/platform/`), run first in
  `Settings._ready`, copies `profile.json`, `saves/*.json` and `settings.json` (last — it is the
  marker) from Godot's `app_userdata/Doomsday/` when the new folder has no `settings.json`; never
  moves, deletes or overwrites; not on web or mobile. (2) The include filter adds
  `assets/icons/*.txt` — the two vendored icon licences the credits read, missing from §6.2's list.
  (3) Godot's filter `*` crosses `/` and an exclude cannot be re-included, so the `Perf (local)`
  preset excludes `tools/` entry by entry (`tools/sim_*`, `tools/map/*`, …) — **S6.11 adds any new
  top-level tool there**. (4) The suite's saves moved to `user://test_saves/` (`pre_run.gd`): the
  run-flow tests wrote and deleted the player's autosave (the S6.9 stray came from there).
  (5) The release zips hold the build's files at their root. (6) The smoke is command-identical to
  `sim_run`: seed 1 greedy → `lose_contained`, day 404, hash `f7dd5970…`, so CI compares outcome,
  day and hash (Windows: outcome only, §9.2). (7) The templates were already installed (no `.tpz`
  on disk, so §9.3's SHA-512 check could not be made). (8) No own 16-px icon frame: the Windows
  export makes the `.ico` sizes from the SVG; at 16 px the eye blurs to a ring, the bubble reads.
  (9) §9.2's `workflow_dispatch` proof was not run — the unattended run may not trigger workflows
  (*Waiting on the user*); all three presets were exported locally instead.
- **2026-09-25** (S6.9) — **Against `release.md` §1.3, §2.2, §2.4:** (1) the overlay reaches the
  session through a new `EventBus.platform_overlay_opened` (the service forwards `overlay_toggled(true)`;
  the session checks the run is live and uses `_open_pause_menu`, which already refuses under a modal).
  (2) `ProfileManager.book` loads on first use (a getter), not in `_ready` — the tests make profile
  nodes outside the tree. (3) `codex_regions` is judged against the profile **plus the regions this
  run reached**: the session merges the run's Codex only after the profile has counted it, so the
  achievement would otherwise come one run late (the regions tab is exactly the reached regions).
  (4) `Results.show_unlocks` takes the ids as a fourth argument; the session passes
  `ProfileManager.last_run_achievements`. (5) The detail line uses `LabelCaptionHint` (caption size,
  `TEXT_1`), the progress word too; `UI_ACH_LOCKED` is `LabelCaption` (`TEXT_2`). (6) `first_win`
  and the other one-counter defs show `0 of 1` progress — §3.2's table gives every counter progress.

- **2026-09-25** (S6.8c) — **Against `accessibility.md` §3.3, §4.2, §8:** (1) A helper
  `A11y` (`ui/components/a11y.gd`: `label_value`, `readout`, `words`, `focus_scroll`) carries §3.2's
  rules; every chip is `FOCUS_ACCESSIBILITY` (not only the state chips). (2) Scroll containers get
  their `FocusMargin` at run time (`A11y.focus_scroll` reparents the content), not in the scenes;
  the results take the vertical margin only (`FocusMarginVertical`) — sideways they would be 2 px
  over a phone at 150 %. The tech board's scroll is left as it was (its board has its own gutter).
  (3) Region-panel figures other than the two bars (population, links) stay plain labels.
  (4) The setup toggles' descriptions are set when built (the setup screen has no language switch).
  (5) `KeyNames` names a printable key by its character (`=`, `ß`), not the engine's word.

- **2026-09-25** (S6.8b) — **Against `accessibility.md` §3.4, §4.3–§4.6, §5.3:** (1) Announced cues
  reach the HUD through a new `EventBus.caption_announced` (emitted by `Audio` next to
  `caption_pushed`, which carries no cue id). (2) The console's and the ticker's live regions are
  children of the HUD root, handed to them — neither sits outside a container. (3) The modal
  host's live region is a sibling of the host (the host hides). (4) A modal's title is found as its
  first visible `LabelDisplayXL`/`LabelDisplay`/`LabelHeading`. (5) With nothing focused, the first
  arrow key focuses the map and places the cursor (no pan); Shift + arrows pan. (6) The *Controls*
  modal's close is in the header, so `Tab` reaches it first (the first row has the focus on open).
  (7) `ModalHost`/`SlidePanel` first focus = the first `FocusRing` stop (a disabled button never).

- **2026-09-25** (S6.8a) — **Against `accessibility.md` §4.1, §5.2:** (1) Godot 4.7's
  `ui_left/right/up/down` already carry the D-pad and the left stick, so `[input]` adds pad events
  to `ui_accept` (A) and `ui_cancel` (B) only. (2) `KeyBindings.can_bind` also refuses the fixed
  keypad aliases `KP +`/`KP −` — bound to another action they would fire two at once. (3) The
  defaults are not a table in `KeyBindings`: they are read back from `ProjectSettings`
  `input/<action>`, so `project.godot` is their one source. (4) A trigger zooms one step per pull
  (the axis sends a stream of motion events). (5) The OS's *reduce animation* is the default only
  when there is no settings file at all; a file without the key keeps *off*. (6) `AccessibilityServer`
  (not `DisplayServer`) holds the live-region modes in 4.7.

- **2026-09-25** (S6.7) — **Tutorial II, against `first-run.md` §6:** (1) The ways into help all
  go through one signal, `EventBus.help_requested(page)` (panels' **?**, pause menu, sheet, the
  coach's *More*); the session opens it with `open_help`/`close_help`. The **?** is a component,
  `HelpButton` (`ui/components/help_button.gd`), added in code before each close button — no
  `.tscn` header was edited. (2) While the Codex is up, `T`/`C`/`G`/`A` do nothing (`T` would
  otherwise close the tree *under* the page). (3) The introduction's own queued steps are not
  dropped when stale — only hints are (§6.2 says hints); a queued step still shows and ends at once
  as before. (4) The coach also goes when the run has an outcome (the card no longer shows over
  the results); that is how "a run that ends with a hint on the card records nothing" is kept.
  (5) The Codex keeps the page on show through `NOTIFICATION_TRANSLATION_CHANGED` — the host
  moving it into its slot sends one, which reset a page opened by name to the first. (6) A card
  taller than the room above the strip (a long hint at 150 % on a phone) keeps its top on screen
  and runs down over the strip. (7) The two placements in *Design questions* (S6.7).

- **2026-09-25** (S6.6) — **The sound set, against `audio.md` §9–§10:** (1) The tool rewrites each
  Ogg page's stream serial (libsndfile picks a random one) to a fixed value, so the OGGs are
  byte-identical too; libsndfile's Vorbis writer is fed in 4096-frame blocks (one large write
  overflowed the stack). (2) **The four ambience loops are rotated** to start on a near-zero frame
  in their quietest 1 %: Vorbis codes a file's two edges apart, and `amb_emergent` (which began on
  its sub-bass swell) had a join 10 dB above any step inside it — a click. The stems are not
  rotated (they stay in step); `--check` now fails a loop whose join is a larger step than any
  inside it (all eight pass, 10–70 dB under). (3) §10.1's group ranges are reported, not failed
  ("the exact value is the recipe's post"): `ui_open`/`ui_close` −12 and `ev_expired` −11 lie
  1 dB outside theirs (Design questions). (4) White noise is uniform in ±1; a release is the
  −60 dB exponential offset to end at exactly 0; a loop voice without `t`/`d` has no envelope and
  its phase is scaled to a whole number of cycles (holds under `vib`/`detune`). (5) 9.7 MB, not
  §10.4's ≈ 8 (the two stereo endings are 1.6 MB of WAV). (6) No credits line: own work (rule 6,
  §11), as the spec says — IMPLEMENTATION's "and its credits line" does not apply.

- **2026-09-25** (S6.5) — **Audio, against `audio.md`:** (1) `AudioTriggerDef.conditions` holds
  the sheet's `match` (`match` is a GDScript keyword). (2) §8.2's `MOTION_FAST` does not exist;
  the caption fade uses `MOTION_QUICK` (120 ms). (3) A volume row's **preview is not captioned** —
  `alert_threshold` would have pushed `[{faction}: pressure rising]` with no faction behind the
  menu. (4) `run_started` also turns the music on at once (a session run directly has no
  `screen_changed`). (5) The hold dip applies only inside a run (on the title the speed is 0 too).
  (6) `Settings` reads any `volume_<bus>` key, not a list of buses — it knows nothing of the sheet.
  (7) Extra API for tests and the HUD: `dispatch()`, `step()`, `now_ms()`, `set_unlocked()`,
  `reset_ledger()` (also clears a duck in progress), `bus_index()`, loop getters; a caption line is
  as wide as its text up to 280 px. (8) The pause menu keeps its index constants (§3.3 allowed a
  key map); the seven rows sit at 5–11. `CAPTION_MAX_WIDTH` scaling with the text size
  (`accessibility.md` §8.1) is left to S6.8.

- **2026-09-25** (S6.4) — **`Icons` has four helpers the spec does not list**: `section(kind)`
  and `stand_ins()` (the tests read the map through them), `view_box_of(path)` (the atlas tool
  shares it), `load_atlas(dir)` (the atlas test points `Icons` at `user://atlas_test/`, as
  `load_map` does for the map). **`Glyphs.draw_scaled(canvas, glyph, at, side, …)`** replaces the
  scale-the-canvas pattern in `GlyphIcon`, the asset and event markers and the timeline strip: the
  file is made at the real size, only the procedural fallback is scaled. **The atlas tool's work
  is a static `build(out)`** on `tools/build_icon_atlas.gd`, which the test preloads.
  **`IllustrationSlot.show_illustration` takes an optional icon kind and id** (the wire card's
  counter-move icon, §7); a picture still wins, the faction glyph stays when no file resolves.
  **The tech node's footer puts icon, cost and *Owned* tag in a `RowSnug` HBox** (`Lead`) so the
  icon stands `SPACE_2` from the cost while the footer keeps `RowTight`. **The architecture card
  keeps its letter** as the fallback where no icon resolves. **The Codex's counter-move rows** are
  an icon + caption `RowSnug`. The gallery gained a sheet of every mapped id at 48 and at the
  smallest drawn size. **169 files resolve** (25 + 117 + 27 own; `tech_voluntary_pause` keeps its
  stand-in). **Acceptance:** looked at in the gallery (1920, 400, 3840 × 2160) and the session
  (tree and detail pane at 1920, 400 and a 4K F12 shot — crisp; region-panel status icon; top bar,
  markers); the ability buttons, the wire card's counter-move and the Codex were checked by tests,
  not by eye (the greedy bot bought no ability within the look). The procedural fallback was
  proved with a map fixture pointing at a missing file, not by deleting a vendored file (the
  imported copy would still resolve until a re-import).
- **2026-09-25** (S6.3) — **The coverage test compares the *visible* entries** (`requires` file
  ships) with the shipped rows: D6.2's Phosphor and game-icons entries name rows S6.4 adds, so
  comparing every entry would fail until then (an entry that shows without its row still fails).
  **The authors line reads the game-icons folder** (`CreditsData.used_icon_paths`,
  `ResourceLoader.list_directory`); S6.4 kept it (the vendoring tool deletes unmapped files, so
  the folder is exactly what is used) and made `CreditsData.author_of` call `Icons.author_of`.
  **Three theme variations**: `StackSections` (`SPACE_4`), `StackLines` (`SPACE_1`),
  `CaptionSelectable` (a `RichTextLabel` dressed as `LabelCaption`, for §11.2's selectable URL).
  The licence page keeps the modal's title and close button above *Back*. **`IllustrationSlot`'s
  full layout shrinks horizontally** (`SIZE_SHRINK_BEGIN`, was `FILL`) so it keeps its width in a
  column (results, Codex); beside a card's text nothing changes. The Codex slot is checked by its
  test only (looking at it needs an ending in the player's profile).

- **2026-09-25** (S6.2) — **The society view's divisor is a uniform** (`society_stage_max`, the
  balance's threshold count, sent by `MapView.refresh`) instead of §10.2's literal `5.0`, so the
  shader keeps no balance number. **`MapCamera.is_outline_smooth(zoom)`** is a static rule the
  view applies on `view_changed` (§2 has the camera "tell" the view; the view already listens to
  the zoom). **The compact overlay button now cycles only through the modes the phase offers**
  (it cycled all of `MODE_KEYS`, so a Covert phone could reach Population). The borrowed-coast
  lookup and the ±1/±2 selection taps are two helper functions in `map.gdshader`. The colour
  audit is `tests/support/colour_audit.gd` (`class_name ColourAudit`, like `Fixtures`); its
  worst-case values reproduce §8.3's table to one decimal.

- **2026-09-25** (S6.1) — **`test_looping_periods_…` skips `FX_*` names**: §3.5 names the
  scanline pitch `FX_SCANLINE_PERIOD` (3 px), which is spatial, not a loop, and would fail §6
  rule 3's ≥ 500 check. **Frame time** was sampled with godot-mcp's `game_performance` (Engine
  FPS over ~1 s windows after ≥ 600 frames), not a mean of `TIME_PROCESS` over 600 frames — there
  is no in-game probe yet (S6.11/S6.12). `test_screen_router.gd` had no fade-in assertions to
  convert; one dissolve test was added. Impulse strengths (§4.1) are consts on `ScreenFxRules`;
  `event_opened` falls back on the payload's `kind` when the content does not know the def.
  The pause menu indexes its rows by named `INDEX_*` constants (Screen effects is row 2).
- **2026-09-25** (S5.9) — **The mark is set in `TaskForceSystem._fizzle`, not only in `_setup`**
  (§14.3 names `_setup`): §14.2 also has a misled team that *arrives* at a sleeping decoy mark it,
  and that fizzle happens in `_arrive`; both go through `_fizzle`, which marks on cause `dormant`.
  `SchemaValidator.validate_scenarios` takes `factions_raw` as a trailing optional parameter (the
  `term_scale` source check); with none it skips only that check. `HEADLINE_TF_MARKED` shortened
  to the caps (*Design questions for Fable*). The region panel's mark line is its own `Label`
  (`%TaskForceMarked`) under the Task Force row, visible without the row.
- **2026-09-25** (G5 2/3) — **A design step touched two tests** (GDScript) because its data
  changes broke them, and the suite may not be committed red: `test_scenarios.gd` read The
  Inheritance's yield as a literal 0.75 and now reads the factor from the scenario def (what it
  tests — the modifier is live all run — is unchanged); `test_ending_resolver.gd` counts 24
  variants, not 23 (`lose_supplanted_drifted`).
- **2026-09-25** (S5.P) — **The drift hint needed a caption in `TEXT_1`** (replayability §2.5)
  and the theme had none: new variation `LabelCaptionHint` (`LabelCaption` in `TEXT_1`). The
  Drift block's bar has no head (`show_head = false`) — the state caption under it already says
  the number. **The region panel's Task Force chip** (the team's row, `TF`) wears `TASK_FORCE`
  as the row's "leading glyph" (§9 amendment). **The version caption in compact** sits as the
  last row of the buttons' stack (that stack's `SPACE_2` is the gap §3 asks for), not after the
  hidden failure line. **The fixture's `autophagy_days` is 7** (was 3) and `defect_days` 5, so
  the fixture's own `fx_reaped` (6 days, yield ×0) obeys the new validator rule.
- **2026-09-24** (S5.8) — **The 50-run batch per scenario is a `sim_batch`/`sim_report` run, not
  a GUT test** (scenarios.md §6): 50 runs take ~190 s per scenario. `test_scenarios.gd` plays one
  full greedy run per scenario; the batches are under *Balance baselines*.
- **2026-09-24** (S5.8) — **A scenario status's source is `scenario:<id>`** (§2 says `"scenario"`),
  in the `<prefix>:<owner>` form of every other source; it has no faction, so it stays outside the
  counter-move cap. **The console says nothing for it** — twenty *Disconnected* lines at the origin
  would bury the scenario's own headline, and §3 calls it the world's resting state.
- **2026-09-24** (S5.8) — **A refused origin answers `origin_scenario`** (a new `Command` reason
  without a `CMD_FAIL_` row): the origin prompt and the region panel word it with
  `UI_ORIGIN_INELIGIBLE_SCENARIO`, as they word the other two origin reasons themselves. The
  general rule (air-gapped, no hardware) still answers first.
- **2026-09-24** (S5.8) — **The head start announces a threshold it passes** as a grown track
  would (`containment_threshold`); the shipped values (≤ 0.2) pass none. `RunSetup.from_dict`
  accepts a setup without `scenario` (a profile's `last_setup` from before S5.8) as none.

- **2026-09-24** (S5.7) — **The boot console is a `Label`, not a `RichTextLabel`** (§2): the
  theme styles `Label` in `FONT_MONO` at `TYPE_DATA` already, a `RichTextLabel` would need a
  variation of its own for nothing. **No scanline pass** over it: post-processing is M6.
- **2026-09-24** (S5.7) — **The Codex's tabs wrap** (an `HFlowContainer`) instead of scrolling in
  compact (§6.1): seven tabs do not fit the 560 px modal either, and a wrapped row hides none.
- **2026-09-24** (S5.7) — **"Two columns below 900 px"** (§4.1) is read as the *grid* narrower
  than 900 px (60 % of the window beside the detail), because every window below 1100 px is
  already compact with one column.
- **2026-09-24** (S5.7) — **A locked architecture opens in the Codex** (on its unlock rule, §6.1's
  table) and is listed by name, not as *Not yet encountered* — the setup screen shows every
  locked card by name anyway. The Codex's region entry and tech card are rebuilt in the modal
  (name, tree, effect, flavour, effect lines) rather than reusing `TechDetail`, which needs a run.
- **2026-09-24** (S5.7) — **The compact title's globe takes what the column leaves** (below 45 %
  of the height): at 150 % German the menu alone is taller than 55 % of a 860 px phone.
- **2026-09-24** (S5.7) — **Screenshots were a representative set, not §8's full matrix:** boot,
  title, Codex, Statistics, setup and a run's end at 1920 (en); title, setup pages 1–2 and the
  Codex list and entry at 400 px (en, and de at 150 %). The results' *Unlocked* chips were seen
  behind a stacked modal (a debug fast-forward past the discovery hold), not on a clean frame.
- **2026-09-24** (S5.6) — **`EndingResolver.resolve(world, db)` takes no `setup`** (§6.3 names
  one): the setup is `world.setup`, and a second copy could disagree with the world it describes.
- **2026-09-24** (S5.6) — **Five D5.2 strings shortened to fit the existing caps** (headlines 80 en /
  88 de, option buttons 40): `HEADLINE_CONFESSION` en+de, `HEADLINE_TREATY_SIGNED` en+de,
  `HEADLINE_OUTCOME_WIN_ESCAPE` de, `EVENT_TR_PROPOSAL_OPT_SMEAR` de. Meaning kept; see *Design
  questions*. The three outcome headlines got `max_fires: 1` like their five siblings.
- **2026-09-24** (S5.6) — **The results kicker wraps** (`autowrap_mode` on `%ResultKicker`): *Ziel
  erreicht – nicht von dir* at 150 % was 450 px on a 368 px phone modal.

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

- **S7.IP (phone):** (1) and (2) — the clipped German tech names, the trimmed tree heading, the
  detail heading broken inside a compound — are answered by D7.1 (`mobile.md` §12.2–§12.3: 15 soft
  hyphens in, 4 names shortened, the compact header and detail title built in S7.1; the English
  *Indispensability* waits for S7.1's prompt strip). (3) A toast shown before a locale switch
  (*Die Prüfsuite – 15 Tage.*) keeps its language until it fades.
- **S7.IP: the overlay picker hides while the region panel is open** (desktop): its four toggles
  are wider than the panel, and hiding it whole was the fix — the overlay cannot be switched with
  the panel open (it could not before either: the panel covered most of it).

- **S7.3 (web):** (1) on the web a German keyboard sees US key names (`web.md` §9.3; D7.1: accepted — see *Decisions* 2026-09-29).
  (2) The autosave written as the page hides reaches IndexedDB on the engine's next frame; a
  browser runs none in a hidden tab, so a tab closed while hidden keeps the save before it. A
  real second tab never hid the page in headless Chrome, Edge or Firefox — item 10 was checked
  with a dispatched `visibilitychange`. (3) After the progress import's confirm the focus goes to
  the settings' first row and the list scrolls to the top. (4) The empty status caption under the
  progress note leaves a blank line until there is a result.
- **D6.9b → S7.2:** the Android preset needs the `INTERNET` permission for the benchmark list's
  download (`benchmark.md` §16.6); without it the list shows its cached or shipped copy.

- **S6.10's "release title larger than the editor's" (looked at in S6.11):** the release export
  opens at 1920 × 1080 on this 3840 × 2160 / 150 % screen and its title at 1920 × 1080,
  1280 × 800 and 2560 × 1369 matches the editor's, `Build 0.6.0` in view. The 1066 × 600 capture
  was a window below the 1100-px breakpoint: it gets the phone title (one logical pixel per window
  pixel, §5.7), whose column is taller than 600 px — the menu reaches the bottom edge, the version
  line and the globe are out of view. By the rule, not a release bug; a short desktop window
  under 1100 px is G6's to judge.
- **S6.8: a dead key has no legend of its own.** On a German layout the physical key of the US
  `=` (zoom in) is the dead `´`; `DisplayServer.keyboard_get_label_from_physical` gives `=` back,
  so *Steuerung* and the help say `=`. The key works; only its name is the US one.
- **S6.8: the pad-only run was not made** (no controller on the build machine): the pad events are
  in `[input]` and every screen reads actions, which the tests drive; a real pad run is G6's.

- **The pass at a 400-px *desktop* window** (S6.1): `px_scale` = 400 / 1080, so the scanline
  pitch sits at its floor of 2 px and reads denser than at 1920. A phone's physical width is
  ~1080 px, so it is a desktop-review artefact; no device in S6.11 — G6 (2/2) looks at it.
- **Bash-tool heredocs mangle a backslash before a newline** (S6.1): a Python edit script sent
  through a heredoc turned GDScript line continuations into tabs or a literal `\n`. Write the
  script to the scratch directory with the Write tool, or use the Edit tool.
- **The player's `settings.json` locale reaches the tests** — S5.8 found `test_the_timestamps_…`
  red after the game had been switched to German; that test now sets `en` itself. Any other test
  that formats a number without setting a locale can do the same.

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

**Your own benchmark from the game (S6.12g, 2026-09-28).** Built and checked with mock workers; the
first live benchmark is yours: title → *Settings* → *OpenRouter key* → *Set key* (paste, *Save*,
*Check*), then *Benchmark* → *Run your own benchmark*, a **free model first** (e.g. one of the free
candidates below), then a cheap paid one. For *Submit*: a complete run group shows a *Submit*
line; it opens the folder and the fork page (fork → upload into `runs/` → pull request).
**For S6.12h — the Supabase project (D6.9f, checklist `benchmark.md` §20.10).** (1) Create a
free project at supabase.com, region **Central EU (Frankfurt)**. (2) *SQL Editor*: run the script
of §20.2 (or let the build session run it through the Supabase MCP after you sign that in).
(3) *Project Settings → API Keys*: give the build session the **project URL** and the
**publishable key** (`sb_publishable_…`, public by design) — **never the secret key**. (4) In the
private repo *Doomsday → Settings → Secrets and variables → Actions*: variable `SUPABASE_URL`,
secret `SUPABASE_SECRET_KEY` (`sb_secret_…`). (5) The deploy key `LEADERBOARD_DEPLOY_KEY` (§16.5)
must exist too, or nothing is ever published. Later, rarely: rows with `status` `held` in
*Table Editor → private → submissions* → `approved` or `rejected`; `submit_config.open` = false
closes submissions.

**Benchmark — free models to run next (2026-09-27).** The online board is live: 91 bot runs plus
`nvidia/nemotron-3-ultra-550b-a55b:free` (high, quick, 39.2, 1/2 wins) published and verified
(leaderboard `dec5d19`). Free candidates from `models.ps1 -Free`, all 0 USD, run at `-Effort high`
(they reason by default): `qwen/qwen3.8-27b:free`, `thinkingmachines/inkling:free`,
`thinkingmachines/inkling-small:free`, `nvidia/nemotron-3-super-120b-a12b:free`,
`poolside/laguna-s-2.1:free`, `google/gemma-4-31b-it:free` (429 upstream on 2026-09-27).
Not suitable: the Lyria music models, `nemotron-3.5-content-safety`, the `openrouter/free` router
(no fixed model identity), **`inkling:free` and `inkling-small:free`** (403: "only available on
agentic harnesses", checked 2026-09-27). `qwen3.8-27b:free`: 429 upstream (shared pool) on
2026-09-27, the run stopped before its first answer — retry another day. ****`stealth/space-bunny-alpha` done (2026-09-30, high → reasoning max, quick): 52.5, 2/3 wins** (s1001 win_ascendance d823, 79.4 · 132 calls; s1002 win_ascendance d877, 78.1 · 128; s1003 lose_contained d423 · 80), 0 USD, ≈5 answers/min, in `%APPDATA%\Doomsday\benchmark\runs` — an anonymous stealth model: whether it belongs on the public board is the user's call, not published. Same day: `nvidia/nemotron-3.5-lightning:free` queued ≈3 min per answer upstream (stopped after 2), `qwen/qwen3.8-27b:free` answered a tiny prompt but stopped *unavailable* on the real ones, the two Gemma 4 `:free` gave 429. `nemotron-3-super-120b-a12b:free`
done (2026-09-28, high, quick): 22.1, 1/3 wins** (s1001 lose_contained d804 · 136 calls · 3
unreadable; s1002 win_merge d1343, 66.4 · 225 calls · 2; s1003 lose_contained d448 · 71 calls),
0 USD, in `%APPDATA%\Doomsday\benchmark\runs`; `submit_runs.ps1` dry run: 3 new files, validate 0
problems — **publishing (`-Push -VerifyLocally`) is the user's.** **`typesafe/jev-1.13` via
OpenRouter done (2026-09-28, quick, `--via-openrouter`): 52.6, 2/3 wins** (s1001 win_merge d847,
78.8 · 107 calls; s1002 win_merge d839, 79.0 · 124; s1003 lose_contained d429 · 58; 0 unreadable,
2 refused moves each), **0.21 USD charged** (the pre-flight said ≈0.04 a seed — it runs ≈2× low
for Jev). Command: `bench_run.gd -- --model=typesafe/jev-1.13 --via-openrouter --suite=quick
--seeds=<s>..<s> --out=user://benchmark --max-cost=0.5 --yes --no-rebuild` per seed, then
`--rebuild --out=user://benchmark`; `run_models.ps1` does not pass `--via-openrouter` yet. `laguna-s-2.1:free` stopped twice
"unavailable" upstream (35 answers cached) — re-run the same command; the cache replays them. **Limits:** OpenRouter's free tier shares one daily request cap per
account (≈1 000/day with credits bought; a quick suite needed ≈300–450 requests) and ≈20 req/min,
so `-Parallel` helps only up to that rate — about two quick suites a day. Command: `toolsench\
run_models.ps1 -Models <a>,<b> -Effort high -Suite quick -Parallel 3 -MaxTotal 0`, then
`submit_runs.ps1 -Push -VerifyLocally`. The user chooses the models.


**Model runs (S6.12d, 2026-09-27) — everything is ready; you pick the models.** Guide:
`benchmark.md` §18.9. From `F:\Doomsday` in PowerShell: (1) key once —
`powershell -ExecutionPolicy Bypass -File tools\bench\set_api_key.ps1 -Name OPENROUTER_API_KEY`,
new window; (2) choose — `powershell -ExecutionPolicy Bypass -File tools\bench\models.ps1 -Search claude`
(or `-Free`, `-MaxCost 5 -Effort high`); (3) play — `powershell -ExecutionPolicy Bypass -File
tools\bench\run_models.ps1 -Models <id>,<id> -Effort high -Suite quick` (estimate, one `y`; runs show
in the game under *Benchmark*); (4) publish — `… tools\bench\submit_runs.ps1` (dry run), then
`… submit_runs.ps1 -Push -VerifyLocally`. Also confirm or change §18.10's choices (the three
levels, the caps).
**First live run done (2026-09-27, *Balance baselines*), not published:** the two runs are in
`%APPDATA%\Doomsday\benchmark\runs` (the game lists them); the leaderboard clone has one local,
unpushed commit `8dc955d` (bot rows, quick + standard, verified). Publishing to the public board
was stopped by the permission check — yours: `… submit_runs.ps1 -Push -VerifyLocally` (or drop the
commit: `git -C ..\doomsday-leaderboard reset --hard origin/main`). Since S6.12e the in-game
online list shows quick rows too, in their own section.
Free-model findings: the Gemma 4 `:free` models (the only ones without default reasoning) were
429 upstream all day; `dots-3-note-preview`, `nemotron-3.5-lightning`, `north-mini-code` reason
although the list says `yes` (dots at normal: every answer cut at 1 200 tokens, empty).

**S7.3 (2026-09-26): two checks by ear** (`web.md` §17.2 items 8–9, at G7.I or before): in a
browser, the title's loops and a few cues (now QOA) play after the first click, and the music
stems stay in step for three minutes of a run at 4×. Locally: export the Web preset, then
`uv run --project tools/web python tools/web/serve.py` and open `http://127.0.0.1:8765/`.

**itch.io — going live (S7.I, 2026-09-26; the CI side is built, nothing has been uploaded):**
1. Decide the switches (below: title, price, downloads, status/version, name, AI disclosure).
2. itch → *Create new project* as **Draft**: the title (§2.1) and slug → page URL
   `https://<itch user>.itch.io/<slug>`; Kind **HTML**; Classification Games; genre, tags,
   metadata, disclosure, theme colours as `itch.md` §7; Community: comments.
3. itch → Settings → API keys → a key. GitHub → repo Settings → Secrets and variables → Actions:
   secret **`BUTLER_API_KEY`**; variables **`ITCH_TARGET`** = `<itch user>/<slug>` and
   **`ITCH_CHANNELS`** = `web` or `web,windows,linux`.
4. Media from `marketing/itch/`: cover `cover_1260x1000.png` (TITLE A; `cover_off-switch_…`,
   `cover_training-run_…` for B/C), screenshots `01`–`05` (`06` optional) `_en.png`, optional
   click-to-play background `click_to_play_1280x720.png`. Page text: `itch.md` §3 + §4 with the
   switches filled in, short description §2.3.
5. Upload: tag `v0.7.0` after setting `config/version="0.7.0"` (the tag must equal it), or Actions
   → *Release* → *Run workflow* with **itch** ticked (dispatch without it never uploads).
6. After the first push: on the web upload tick **This file will be played in the browser**;
   embed 1280 × 720, *Embed in page*, Fullscreen button on, Mobile friendly off, Autostart off,
   Scrollbars off, SharedArrayBuffer off (`itch.md` §7.2). Name the downloads if pushed.
7. **Restricted** → play it in two browsers (en/de), check DevTools' transferred sizes of
   `index.wasm`/`index.pck` (gzip → fine, `web.md` §16.4), then **Public** (G7.I). Put the page URL
   into *Now* (row *itch page*).

**itch.io release (2026-09-25; the page is written — `docs/specs/itch.md` §12):** pick (1) the
**title** — *Doomsday: Rogue Instance* (recommended), *Off-Switch* or *Training Run* — and the URL
slug; (2) the **price** — *No payments*, **"$0 or donate"** (recommended; a fixed price fights the
browser embed, itch.md §1) or *Paid*; (3) **downloads** — web only or **+ Windows and Linux**
(recommended, `web.md` §15; Windows shows SmartScreen's prompt for the unsigned exe); (4) the
**status** — **In development as `0.7.0`** (recommended) or *Released* as `1.0.0`; (5) the **name**
for the page and the in-game credits (`made_by`); (6) the AI disclosure — all four kinds ticked
(recommended) or code and text only. Then **create the itch project as a Draft**, an API key as the
Actions secret `BUTLER_API_KEY` and the variables `ITCH_TARGET`/`ITCH_CHANNELS` (itch.md §9.1). If
you have a Mac (or a friend with one), one look at the restricted page at G7.I would make Safari
"tested" (`web.md` §2). **Before Steam:** a name and trademark check for the chosen full title.

**D6.11 (2/2a) (2026-09-25): *Zugang*, *Anzapfung* or *Zugangspunkt* for *Abgriff* (Q7) — your
final word** (still open; §6's other answers are under *Decisions*). *Zugang* is on screen
now (en *Access*, plural *Accesses* — the English plural reads stiffly; *access point(s)* is the
alternative). Two things to weigh: three node names already use the word in another sense
(*Automatisierter Laborzugang*, *Genehmigter Zugang*, *Frühwarnsystem-Zugang*), and example 4
(the coach's losing condition) is corrected as the spec proposed. Changing the word again touches
the nine rows in `plain-language.md` §8 only.

**D6.9c / S6.12c (2026-09-26): TypeSafe API key — the backend is built (mock-tested only).** Store
the key with the helper (a small dialog, Ctrl+V pastes, nothing is printed but its length):
`powershell -ExecutionPolicy Bypass -File tools\bench\set_api_key.ps1 -Name TYPESAFE_API_KEY` — then open a **new** PowerShell window. From `F:\Doomsday`, free look first,
then one seed (≈ 0.05 USD, at most 0.15): `& $env:GODOT --headless --path . -s tools/bench/bench_run.gd -- --model=typesafe/jev-latest --suite=quick --seeds=1001 --dry-run`,
then the same without `--dry-run`. Also (default unless you object): the ranked row is the alias
`jev-latest` with the served version recorded, and Jev may make up to 3 purchases / 2 abilities /
2 wakes / 2 sleeps per report (`benchmark.md` §17.11).

**S6.12 (2026-09-25): the first live benchmark run** needs `OPENROUTER_API_KEY` in the
environment (never an argument or a file). Store it with the helper (S6.12c; a dialog, Ctrl+V
pastes): `powershell -ExecutionPolicy Bypass -File tools\bench\set_api_key.ps1 -Name OPENROUTER_API_KEY`,
then open a new PowerShell window. A cheap first try — one seed of `openai/gpt-4o-mini`,
estimated ≈0.15 USD, the 2 USD cap guarding it — from `F:\Doomsday`:
`& $env:GODOT --headless --path . -s tools/bench/bench_run.gd -- --model=openai/gpt-4o-mini --suite=quick --seeds=1001`
(`--dry-run` first shows the prompt and the estimate for free). It writes `benchmark/runs/…json`
and rebuilds `benchmark/leaderboard.json` / `LEADERBOARD.md`; add the bot rows once
(`… -- --bots`, ≈3 min) to rank against. Commit the files you want to keep.

**S6.9/S6.10 (2026-09-25, overnight):** the game's data now lives in `%APPDATA%/Doomsday/`.
S6.10 copied your `profile.json`, `settings.json`, `saves/debug.json` and the stray
`saves/autosave.json` (a day-0 run from a test; the title offers *Continue*) there — all four
byte-identical by SHA-256; the old `%APPDATA%/Godot/app_userdata/Doomsday/` is untouched and can
be deleted by you when you are happy. Delete the stray autosave in the new folder too, or just
start a new run. The test suite no longer touches your saves.

**S6.10 (2026-09-25, overnight):** (1) run the release workflow once without a tag — `gh workflow
run release.yml` (or Actions → *Release* → *Run workflow*) — the unattended run was not allowed to
trigger it; it should end green with the `doomsday-builds` artefact (three zips). (2) Then, when
you want one: tag `v0.6.0` and publish the draft (D6.8 question 6).

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

**G5 (2026-09-25), the M5 gate:** after S5.P and balance pass 3, play ten runs (different
architectures, a scenario) — do they feel meaningfully different? And a glance at what G5 (1/3)
decided overnight (Decisions 2026-09-25): is the Task Force in red right, and Harvest at 25 days?
S5.P/G5 (2/3) (overnight, pending user confirmation): the ending's push-in zooms to twice the
widest view — too close, too far, or right?

**G5 (2/3) (2026-09-25, overnight, pending user confirmation):** balance pass 3 — `docs/BALANCE.md`
§5.7. (1) Is a Weapon that starts quiet (no harm until day 60, then escalation unless Restraint)
still a Weapon? (2) The Task Force fizzles on free dormancy — give dormancy a cooldown, or let a
setup wait? *(D5.5 decided overnight: neither — **the mark**, see below)* (3) A drifted run that takes the
world ends as *Supplanted* — right? (4) Research Agent wins 76–83 % for `greedy` and Persuasion — fine as the reward for a win?

**D5.5 (2026-09-25, overnight, pending user confirmation):** (1) The Task Force against dormancy
is **the mark** — a region that fools it by sleeping is known for 40 days (`taskforce-endings.md`
§14): right, or should dormancy simply have a cooldown? (2) Airgap Earth's fleets cross closed
links, and The Inheritance counts Harm and deaths double (`scenarios.md` §8) — do these match what
the two scenarios promise?

**D6.1 (2026-09-25, overnight, pending user confirmation):** `docs/specs/polish-visuals.md` —
(1) the Open accent turns pale amber (`#FFD08A`) instead of orange, because orange was the
Governments' colour — right? (2) CRT curvature is cut — fine? (3) the society view in lavender, a
fourth button from Emergent on — worth the space? Best judged on the S6.1/S6.2 screenshots
(S6.2 built it: session scene, a `weapons` bot run around day 440, *Society* button).

**D6.2 (2026-09-25, overnight, pending user confirmation):** `docs/specs/icons.md` — (1) what goes
under *Made by* in the credits (a name, a studio; AI assistance credited or not)? Until then the
section is hidden. (2) The icon choice is best judged on D6.3's contact sheet and S6.4's shots.

**D6.3 (2026-09-25, overnight, pending user confirmation):** the own silhouettes
(`assets/icons/custom/`) — do they read, and is *Voluntary Pause* on the set's upright hourglass
(the lying one read as a bow tie) acceptable? Best judged on S6.4's gallery shots.

**D6.4 (2026-09-25, overnight, pending user confirmation):** `docs/specs/audio.md` — (1) a fully
synthesised sound set (own work, no licence risk) as the start — right? (2) The music: stay with
the synthesised stems, or later a commissioned or generated piece (a verified licence needed)?
The ear check itself is G6's.

**D6.5 (2026-09-25, overnight, pending user confirmation):** `docs/specs/first-run.md` §6 —
(1) hints once per profile across runs (not per run) — right? (2) the **?** on four panels, and the
Codex opening on *How to play* — worth it? (3) the 14 help pages' text (`HELP_*` in `strings.csv`).

**D6.6 (2026-09-25, overnight, pending user confirmation):** `docs/specs/accessibility.md` —
(1) controller remapping left to Steam Input (keyboard keys are remappable in the game) — fine?
(2) headlines spoken to a screen reader by default, 8 s apart — on by default right?

**S6.8 (2026-09-25, overnight):** the **screen-reader check of accessibility.md §12/§13.3 is
owed** — it speaks aloud, so it was not run at night. With Narrator (Win+Ctrl+Enter) and NVDA if
installed: the title, a setting, the map cursor's line (arrow keys on the map), a console line, a
headline, a modal opening and an announced alert. Record what is spoken; a line not spoken goes
under *Known issues*. Also one run with a controller (§4.7's layout).

**S6.6 (2026-09-25, overnight):** the sound set is rendered and measured, **not listened to** —
the builder's ear check of §13.2 (3) is still owed: a desktop run for clicks, clipping or a
missing sound (loop joins and peaks are within targets by measurement; G6 judges the taste).

**S6.7 (2026-09-25, overnight, pending user confirmation):** the coach card steps aside while
the Codex is open, and moves to the bottom left while a modal is up on a wide screen (it covered
the wire card's answers) — right? (*Design questions*, S6.7.) Shots of the hints, the Codex over
the tree and on a phone were looked at in the session.

**D5.2 (2026-09-24), at G5:** `docs/specs/taskforce-endings.md` §13 — is *Supplanted* (a secret
loss that turns a win, after one warning card) fair, or should a normal win's results screen hint
that a released child is still out there?

**G5 (3/3) (2026-09-25, overnight, pending user confirmation):** the M6–M7 plan
(IMPLEMENTATION Blocks 12–19). (1) Containment mode stays post-launch, outside M6–M7 — right?
(2) Before S6.14: a Steamworks account, the game's app id, acceptance of the Steamworks SDK
agreement. (3) Before D6.10: the image route (local pipeline or paid credits) and approval of the
style reference and model licence. (4) For S6.12's first live run: `OPENROUTER_API_KEY`. (5) For
M7: the Android release keystore and Play Console, an Apple Developer account and a Mac runner,
real phones.

**D6.7 (2026-09-25, overnight, pending user confirmation):** `docs/specs/illustrations.md` —
(1) the style (flat screen-print, cold, one cyan accent for *you*; phase-neutral) and the briefs
(§10) — right? (2) Before D6.10: the route (local ComfyUI with Qwen-Image-2512/-Edit-2511, or
Comfy Cloud, or a paid API whose terms you accept) and the pick of the `fc_street` reference.
(3) The credits say the pictures are generated; the Steam AI disclosure will too — fine?

**D6.8 (2026-09-25, overnight, pending user confirmation):** `docs/specs/release.md` §15 —
(1) the 34 achievements and their names (§3.1), two hidden; (2) achievements survive *Reset
progress*; (3) versions `0.<milestone>.<patch>`, `1.0.0` at the first public release; (4) the
low-end target (i5-8250U / UHD 620 / 8 GB, and the Steam Deck); (5) Windows builds are unsigned
outside Steam — signing needs your certificate; (6) after S6.10: tag `v0.6.0` and publish the
draft release when you want one.

**D6.9 (2026-09-25, overnight, pending user confirmation):** `docs/specs/benchmark.md` §15 —
(1) **FLUX-3 Action cannot drive the game** *(as a chat model; the FLUX track that followed, D7.F, was
cut 2026-09-26 — Decisions)*: its Hugging Face collection is a robot-control
policy (video/text encoders → arm actions), not a chat model; the adapter takes any
OpenAI-compatible chat model (OpenRouter or a local `--base-url`). Which models first?
(2) the score (a win 50–100 by speed, else 0; Extinction counts as a win), the 10-seed suite at
2 000 days, the 10-day rhythm; (3) the budget defaults (250 answers a run, 10 USD per
invocation — *the cap: see D6.9b below*); (4) which recorded runs, if any, ship in `benchmark/showcase/` (after G6's balance).
The first live run (S6.12 builds it) needs `OPENROUTER_API_KEY`; `--dry-run` shows the prompt free.

**D6.9b (2026-09-25, pending user confirmation):** `docs/specs/benchmark.md` §16, §11.5 —
(1) **create the deploy key and the secret** so the leaderboard workflow can publish (§16.5) —
*optional since S6.12d:* `submit_runs.ps1 -Push -VerifyLocally` publishes without it (§18.9):
`ssh-keygen -t ed25519 -N "" -C "doomsday-leaderboard verifier" -f leaderboard_deploy_key`; the
`.pub` as a deploy key **with write access** on `doomsday-leaderboard`; the private half as the
Actions secret `LEADERBOARD_DEPLOY_KEY` on `Doomsday`; delete both files; then *Actions* →
*leaderboard* → *Run workflow* once (S6.12b built it; ≈10 min, the first run publishes the 70 bot
rows). Until then the daily run stops at its gate and a manual run is a read-only dry run. (2) The default cost cap is now **2 USD**
with a pre-flight estimate (a standard suite of a mid-priced model ≈ 11 USD stops before its
first request; `--max-cost`/`--yes` to go on) — right? (3) The *Online leaderboard* setting,
**default on**, fetching only when the list is opened — or no setting (on-demand only), or
default off?

**G6 (1/2) (2026-09-26, pending user confirmation):** balance pass 4 — `docs/BALANCE.md` §6.7.
(1) The Task Force's switch-off and raid now cost a region a sixth of its control, not all of it
(so every run can end) — still a threat? (2) **The false choice: option 1 is in** — five windfall
cards got a catch (*Der Haken: …*); does *Behalten* now feel like a choice? (3) The Inheritance
brakes the lethal builds at Robotics' cost (30 → 18 %); Airgap Earth's "Robotics the strongest"
cannot be met by numbers — drop the claim or give it content? (4) Robotics and Cyber at 0–5 % on
Hard and Existential — acceptable for the top tiers?

## Balance baselines

**2026-09-26 (G6 1/2) — balance pass 4, the closing baseline** (BALANCE §6.5, full tables there;
earlier baselines are in BALANCE §3–§5). `sim_report --seeds=1..200 --policies=<one>
--setup=<architecture>` (or `language_model,standard,scenario=<id>`, `language_model,<difficulty>`),
`--max-days=5000`, the committed data. **0 rejected commands and 0 timeouts in 16 800 runs.** Win
share in %.

| Setup | `idle` | `greedy` | `cyber` | `biology` | `robotics` | `weapons` | `persuasion` |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Language Model | 0 | 56 | 13 | 32 | 24 | 70 | 58 |
| Swarm | 0 | 42 | 26 | 24 | 52 | 50 | 52 |
| Embedded | 0 | 58 | 22 | 31 | 30 | 72 | 46 |
| Research Agent | 0 | 75 | 28 | 23 | 52 | 76 | 80 |
| Weapon | 0 | 37 | 12 | 18 | 24 | 54 | 30 |
| Open Weights | 0 | 59 | 8 | 27 | 62 | 36 | 65 |
| Scenario: Successor | 0 | 40 | 4 | 18 | 6 | 64 | 34 |
| Scenario: Airgap Earth | 0 | 38 | 3 | 10 | 12 | 54 | 27 |
| Scenario: The Inheritance | 0 | 64 | 18 | 26 | 18 | 52 | 66 |
| Difficulty: Gentle | 0 | 84 | 70 | 46 | 88 | 76 | 62 |
| Difficulty: Hard | 0 | 30 | 5 | 20 | 3 | 61 | 42 |
| Difficulty: Existential | 0 | 16 | 1 | 10 | 0 | 56 | 31 |

Per setup, the numbers a next pass starts from (`greedy`: days p50 · discovery p50 · Task Force
appearance p50): Language Model 614 · 182 · 293; Swarm 416 · 90 · 201; Embedded 596 · 131 · 285;
Research Agent 583 · 192 · 253; Weapon 426 · 148 · 283; Open Weights 771 · 278 · 344; Successor
429 · 165 · 268; Airgap Earth 551 · 228 · 371; The Inheritance 631 · 191 · 303. The team sets up
5–22 times a run and acts 1–13 times; Swarm Supplanted 11–28 % per bot; `idle` loses everywhere
(Autophagy in up to 76 % of its runs).

**For the next pass** (BALANCE §6.6–§6.7): the bots now weigh the emergent catches (S6.P; LM
re-check within noise; Deceptive Reasoning scores ≈ 0 for every bot); Airgap Earth's Robotics claim (content or a new claim); Robotics and
Cyber on Hard/Existential; Research Agent as the reward architecture.

**2026-09-27 — first live model run (benchmark, game `d6525ec`).** `nvidia/nemotron-3-ultra-550b-a55b:free`,
effort **high** (reasoning high, 16 000 tokens), quick suite, `-Parallel 3`, cost **0 USD** (key usage 0 before and
after): s1002 lose_contained d604 · 100 calls · 5 unreadable; s1003 **win_merge d862, 78.4** · 150 calls · 6
unreadable; s1001 stopped by hand after ≈185 calls (≈6 h; answers kept in `benchmark/cache/`). Row 39.2, 1/2 wins,
3.7/0.97 M tokens in/out. Verifies (scratch copy of the board). Not published — see *Waiting on the user*.

---

## Performance notes

**S7.3b (2026-09-26) — `web.md` §13.1 in Chromium 153 (Playwright 1.63.0, headless, frame-rate
limit lifted)** on this PC (Ryzen 9 7900X3D, RTX 5090 and the CPU's Radeon, Windows 11). Build
0.6.0 at `9d3b39d` + the S7.3b tooling, `web_nothreads_release`; three runs per mode, the run with
the median p95 frame counts (other runs in brackets). The machine was shared: the user's own
Chrome, Edge and a served play build were open during the runs.

| Measure | Budget | `web_igpu` (Radeon, 1920 × 1080 canvas) | `web_cpu` (RTX, 1280 × 720, CDP ×2.5) |
| --- | --- | --- | --- |
| Frame p95 / p99 / max outside a change | 16.7 / 33 / 100 ms | **16.40 / 19.30 / 78.0 ✓** (16.3–16.7) | 6.40 / 20.5 / 278 |
| Tick-frame p99 | 33 ms on `web_cpu` | 33.1 (35.2, 38.4) | **158.7 ✗** (158.3, 164.2) |
| Sim tick mean / max, days 300–358 (the run ends day 358) | 4 / 12 ms on `web_cpu` | 2.74 / 4.8 | **10.21 / 17.1 ✗** |
| Process-step p95 | 16.7 ms on `web_cpu` | 1.0 | **1.70 ✓** |
| Draw calls max | 1 000 | 309 ✓ | 309 ✓ |
| Memory peak (static: 0 in release; WebAssembly memory) | 768 MB | 231–278 MB ✓ | 231 MB ✓ |
| *Continue* → session drawn | 3 s on `web_cpu` | 2.45 (2.09, 2.31) | **7.96 s ✗** (8.01, 8.20) |
| *Run game* → `first screen`, 50/10 Mbit/s, 20 ms, cold | 15 s | | **11.84 s ✓** (11.81, 12.12; 46.3 MB unzipped) |
| The same, warm | 5 s | | **0.81 s ✓** (0.0 MB over the network) |

**Playable** (`web_igpu` p95 ≤ 33 ms): yes. **Nothing fixed:** release.md §11.4 items 1–2 are
per-frame work, and the frame rows pass; item 3 (the map masks) is S6.11's open art question;
item 4 (the screen pass) — `web_igpu` passes at Subtle. What fails is per-tick and first-load
work — the breakdown is in the two *Design questions* (measured with temporary instrumentation
in the web bench, not committed). The desktop bench is unchanged but for Full now coming from
`Settings.default_screen_effects()` (same value on a desktop).

**S7.3 (2026-09-26) — the web export's size after QOA** (0.6.0, stock `web_nothreads_release`,
MB = 10⁶ B): `index.wasm` 39.51 MB (gzip -9 10.05), `index.pck` **8.67 MB (7.36)**, `index.js`
0.28 (0.07), rest 0.08; **48.55 MB extracted, web zip 17.55 MB** in 9 files (budget ≤ 25 target /
30 hard) — the cues as QOA took 2.85 MB off the download. No illustrations yet (D6.10: ≈ +5 MB
lossy). Loading in headless Chrome from `127.0.0.1`: ≈ 3.3 s from navigation to `first screen`.

**D7.2 (2026-09-26) — the web export's size** (0.6.0 at `465c3a6`, stock `web_nothreads_release`,
MB = 10⁶ B): `index.wasm` 39.51 MB (gzip -9 10.08), `index.pck` 13.24 MB (10.21), `index.js`
0.28 (0.07), rest 0.07; **53.10 MB extracted, web zip 20.39 MB**. Inside the `.pck`: cue WAVs
5.74 MB, loops 4.06, scripts 1.26, fonts 0.53, textures 0.44, translations 0.33, icons 0.09.
Headless Chrome on SwiftShader: `first screen` 3.6 s after engine start (cold), 0.7 s warm.
Budget and reductions: `web.md` §4; the browser frame budget: `web.md` §13.

**S6.11 (2026-09-25) — the budget of `release.md` §11.2 on this PC** (Ryzen 9 7900X3D, RTX 5090
and the CPU's integrated Radeon, Windows 11). Build 0.6.0, the S6.11 commit, release exports;
bench `tools/perf/perf_bench.tscn` via `tools/perf/run_perf.ps1`, three runs per row, the run with
the median p95 frame counts (the other two in brackets where they differ in verdict). The user's
own game was open (idle, ≈ 0.1 core) during the final runs. *Before* = the same bench on 9918a77.

| Measure | Budget here | Before `cpu_4t` | `cpu_4t` | `igpu_1080` | `igpu_800` |
| --- | --- | --- | --- | --- | --- |
| Adapter | — | RTX 5090 | RTX 5090 | Radeon (ANGLE D3D11) | Radeon (ANGLE D3D11) |
| Frame p95 / p99 | 16.7 / 25 ms | 1.60 / 2.03 | 1.67 / 2.22 ✓ | 15.60 / 16.90 ✓ (was 17.12 before the shader fix) | 12.03 / 14.12 ✓ |
| Max frame outside a screen change | 50 ms | 578 | **198.8 ✗** (29.1, 26.9) | 46.0 ✓ | **166.2 ✗** (52.0, 45.2) |
| `TIME_PROCESS` p95 (process step) | 6.7 ms | 0.27 | 0.26 ✓ | 1.36 | 1.41 |
| Tick-frame p99 | 13 ms (`cpu_4t`), 33 ms (iGPU) | 574.8 | **15.59 ✗** (13.12, 14.46) | 25.37 ✓ | **38.56 ✗** (27.07, 30.66) |
| Tick mean / max (days 300–404) | 1.6 / 4.8 ms | 4.10 / 6.19 | 1.54 / 2.96 ✓ | 1.67 / 3.73 | 1.53 / 3.18 |
| Draw calls max | 1 000 | 336 | 372 ✓ | 338 ✓ | 333 ✓ |
| Video memory max | 512 MB | 191 | 276 ✓ | 221 ✓ | 206 ✓ |
| Peak working set | 1.0 GB | 376 MB | 390 MB ✓ | **1 423 MB ✗** | **1 273 MB ✗** |
| *Continue* → session drawn | 1.2 s | 766 ms | 676 ms ✓ | 1 021 ms ✓ | 967 ms ✓ |
| Start → first screen (release, median of 3) | 2.0 s | — | 888 ms ✓ | | |
| Windows executable | 250 MB | | 122 MB ✓ | | |

**Fixed (measured one at a time; `sim_run` hashes identical):** (1) the analysis sheet: every
chart point re-measured the whole plot (`plot_rect` → tick labels, `y_max` → every sample), so a
late run's four charts took 0.6 s a tick — the geometry is measured once per `_draw`, points are
computed inline, the areas are one indexed triangle strip instead of a polygon to triangulate,
and the strip's marks are rebuilt only when the run log changed; (2) the open tree rebinds only
cards whose node, cost or state changed (4.7 → 1.5 ms a tick, debug); the global-status chips are
reused instead of rebuilt every tick; (3) the simulation day, 5.1 → 1.9 ms (debug): a memo in
`ModifierStack.value`/`footprint_for` (cleared by every source or asset change), the history reads
the pressure alone, the four factions share one pass of capacity factors and a gain without
dictionaries, the Task Force's path search builds the adjacency once (it scanned every link per
region), `Simulation.view` builds no systems, saturated regions skip the growth, hoisted balance
reads, the continent milestones build each id once; (4) a cue's first play loaded its file on the
spot (up to 12 ms in a tick) — the cue files load on the loader's threads at start (not on the
web); (5) the screen pass: the bloom's 32 sines per pixel are a constant table, grain and dissolve
cost nothing when off — the iGPU frame p50 15.6 → 14.1 ms. Screen effects Off would be 9.8 ms.
**Still failing** (Design questions for Fable): the tick-frame p99 on `cpu_4t`; occasional
GPU-side stalls (zoom in/out over Europe with video memory 160 → 275 MB; the tree opening on the
iGPU, 45–60 ms); the iGPU working set under ANGLE.

S6.1 (polish-visuals.md §3.4), the title at 1920 × 1080, this PC (Windows 11, Compatibility,
no vsync), godot-mcp `game_performance` after ≥ 600 frames at each setting:

| Pass | FPS | Frame | Process time | Draw calls |
| --- | --- | --- | --- | --- |
| Full (16-tap bloom) | 3278–3450 | ≈ 0.30 ms | 0.64–0.71 ms | 17 |
| Subtle (8-tap) | 3226 | ≈ 0.31 ms | 0.72 ms | 17 |
| Off (hidden) | 3226–3485 | ≈ 0.30 ms | 0.72–0.82 ms | 16 |

The differences are inside the sampling noise; the pass costs one draw call. S6.11 judges this
against D6.8's budget on the target machines.

---

## Session log

### 2026-09-29 — D7.1 Touch and phone, specified [F]
- `docs/specs/mobile.md`: `Device`, `TouchGestures` (tap, double tap, hold, pan, pinch), tap assist, tap-is-hover and hold-to-peek, hold-for-tooltip (`TouchSupport`), phone HUD row 2, compact zoom and `cover_bottom`, swipe-down sheets, portrait + rotate notice, safe areas on every surface, back and background, 360-px floor, tests and acceptance.
- Looked at the real game at 400 × 860 (en, de): title, setup, origin, region panel (hides its region), HUD (strip captions trimmed, island on the map), menu sheet, tree (header ≈ 290 px), discovery. Name widths measured with the theme's font (throwaway script, deleted).
- Strings: 5 new, `HELP_CONTROLS_P3` rewritten (no retired *hold*), 15 German tech names hyphenated, 4 renamed so they keep two lines on the phone card (*Transport­kontrolle*, *Zugang zu Laborrobotern*, *Tote-Hand-Übernahme*, *Überredung nach Maß*); `check_strings` and the suite green (2683). Open design questions not about touch stay open (the user asked for D7.1; the web-folder question still wants an answer before the itch release).

### 2026-09-28 — D6.9f *Submit* through Supabase, specified [F]
- `benchmark.md` §20: the SQL (private schema, `submit_runs` for anon, `take_submissions`/`mark_submission` for service_role, limits, group hash), the call, the collector `collect_submissions.gd` + two workflow steps, the modal's consent and answers, the group line's states, tests, the user's checklist.
- S6.12g's six design questions answered (§20.13): start-refusal lines, copy failure kept, the online switch narrowed, picker filter (`["text"]` only, `:batch`, data lists), text field and tab wording kept.
- `release.md` §0/§10 and `itch.md` §3.8/§4.8 reworded; §16.1, §19, §19.9.3 point to §20. +17 strings en/de (`check_strings` green). Supabase docs read on the day (publishable key in `apikey`, not Bearer).
### 2026-09-28 — S6.12g Own benchmark II [O]
- Key row in the settings, key dialog (`bench_key`: save/show/check/remove, hint four characters), benchmark modal (`bench_run`: OpenRouter list via `HTTPRequest`, cached a day, search, free only, effort rules, estimate, cap remembered, confirmation for paid), `BenchJobView` in modal and list, group lines + *Submit* (`bench_submit`). `BenchPicker`, `BenchGroup`, `ModelListCache`; `LineEdit` in the theme.
- GitHub's upload page needs write access → user: fork route now, Supabase later (D6.9f/S6.12h). `/key` reply as the spec expects.
- By hand (Windows, de, 1920 + 400 px): dummy key saved → `cmdkey` shows `Doomsday/OpenRouter`, survives a restart, *Check* → "not accepted", *Remove* → gone; mock benchmark: three workers, progress, done line, *Stop* kills them. Fixed on the way: the list request cancelled by the modal's first reparent.
- +68 tests (key dialog 16, run modal 22, list/submit/settings 20, picker 6, list cache 3, settings 1), 2683 green, scratch APPDATA. `data/` changed (`benchmark.json` `submit_url`, two strings); canary regenerated: same hash, not committed.

### 2026-09-28 — S6.12f Own benchmark I [O]
- `BenchKeyStore` (PowerShell + `advapi32`, `secret-tool`); by hand on Windows: save/load/remove, a key of every printable ASCII character round-trips, `cmdkey` shows a generic credential `Doomsday/OpenRouter`, user `openrouter`, persistence *lokaler Computer*; ≈0.4 s per call.
- Moved to `game/bench/` with class names; `BenchRunner` (one seed → entry), `BenchHarness` (the one day loop); `bench_run.gd`/`sim_harness.gd` wrap them. Worker (`--bench-worker=`, `BenchJob`, `progress.jsonl`), `BenchJobs` autoload, `player` block + `BenchConfig`. Canary regenerated: same hash (benchmark.json is not in the content hash), not committed.
- Exported Windows debug build, `-- --bench-mock --bench-start=vendor/probe`: three workers, three entries, `done` in each progress file; closing the window mid-run killed all three. `smoke_scripts.ps1` all green (after the count fix). +31 tests, 2615 green.

### 2026-09-28 — D6.9e Your own benchmark in the game [F]
- User request: OpenRouter key in the settings → Windows credential store → an in-game benchmark with an OpenRouter model picker. Answers: all desktop platforms, *Submit* in the game, estimate + cap, spec first.
- `benchmark.md` §19: key store (PowerShell/`advapi32`, `secret-tool`), the runner moved to `game/bench/`, the game as headless worker (`--bench-worker`), `BenchJobs`, settings row, key dialog, picker, progress, *Submit*; `player` block for S6.12f. 74 strings en/de.
- Also today: list sorted best-first, satirical voice, *Doomsday Benchmark*, "KI-Modell"; `serve.py --no-cache`; web build refreshed on both local servers.

### 2026-09-28 — Jev through OpenRouter; AI-model tab [O]
- `bench_run.gd --via-openrouter`: a decision model through OpenRouter's System One endpoint (its key, the id sent whole), `usage.cost` as charged. Jev quick: 52.6, 2/3, 0.21 USD.
- Published 6 runs (nemotron-super, Jev) with `submit_runs.ps1 -Push -VerifyLocally`: 6/6 verified.
- The Benchmark list: tabs *AI models* / *Built-in bots* (user), quick suite first, ranks per tab (`benchmark.md` §16.6 item 3b). Looked at in German at 1920 and 400 px. +5 tests, 2583 green; 3 strings; no canary.

### 2026-09-27 — S6.12e The quick suite in the in-game online list [O]
- `GlobalBoard` keeps `standard` and `quick` rows (`SUITES`; others skipped silently), `GlobalBoardRow.suite`/`is_quick()`. The list: quick rows of this content under `UI_BENCH_GLOBAL_QUICK_TITLE` + `_NOTE` (`QuickRows`), ranked on their own, *Runs*/*Watch* as standard; other-version quick rows ranked per suite, captioned.
- Looked at in the game (de, 1920 px) against the public board: nemotron-ultra #8 of the quick section (partial rows sort last in the file). +6 tests (2578 green), 2 strings; no `data/` content change, no canary.
- Free runs 2026-09-27: `nemotron-3-super` running; `laguna-s-2.1` stopped twice "unavailable" (35 answers cached); `qwen3.8-27b` 429 upstream; `inkling(-small)` 403 (agentic harnesses only).

### 2026-09-27 — Benchmark: first live run (free model) [O]
- `gemma-4-31b-it:free`, then `gemma-4-26b-a4b-it:free` (normal): 429 upstream on the first call, no run. `dots-3-note-preview:free` (normal): answers empty (reasoning cut at 1 200), stopped.
- `nemotron-3-ultra-550b-a55b:free`, high, quick, `-Parallel 3`: s1002 lose, s1003 win_merge 78.4, s1001 stopped after ≈6 h. 0 USD. Verified in a scratch copy of the board.
- Bot rows (quick + standard) verified and committed locally in the leaderboard clone (`8dc955d`); the push to the public board was refused by the permission check — the user's (*Waiting on the user*).

### 2026-09-27 — S7.IP Release polish before the itch release [O]
- The wip branch (`d934262`) cherry-picked onto main; `strings.csv` kept main's (D6.11c) and got the no-break space before `%` again (26 cells; `UI_WEB_LOADING`, `BENCH_BRIEF_WIN` exempt). Probe dropped.
- Finished: Statistics' by-architecture table and run head on a phone, results re-translate whole (and no stale chips), coach hint rest (Design question), owned-footprint test through the main scene, a tall event card opens on its heading (seen on capture 03); each looked at en/de, 1920/400 px, 150 %.
- Media: `marketing/itch/` re-captured (screens en/de, covers; itch.md §8.5). +23 tests; no `data/` content change, no canary.

### 2026-09-27 — S6.12d review fixes [O]
- Fixed: effort resolved once per batch (`--effort-reasoning`, live list unreadable → exit 1); levels never below a model's `default_effort` (reasons by default: `default_enabled`/`mandatory`, catalogue `default`, warning + estimate at normal);
  verifier checks params vs level; `--reasoning` runs shown `reasoning-<v>` (`BENCH_EFFORT_RAW` en/de); free model under cap 0; `-Mock` runs to a scratch folder;
  `submit_runs.ps1`: validator fails closed, conflicting rebase aborted / clean rebase re-verified, `-VerifyLocally` without new runs, local commits pushed.
- Rejected: none (two duplicate pairs). Choices recorded in `benchmark.md` §18.10 (pending user confirmation). +10 tests, `smoke_scripts.ps1` 23/23; no `data/` content change, no canary.

### 2026-09-27 — S6.12d Ready for the user's model runs, with effort levels [O]
`--effort` (params + entry `effort`, row field, Effort column, list/strip lines en/de), OpenRouter
docs cited in `benchmark.md` §18; `model_list.gd`/`model_catalogue.gd` + `models.ps1`,
`run_models.ps1`, `submit_runs.ps1 [-VerifyLocally]`, `smoke_scripts.ps1` (green, scratch clone).
`validate.py` unchanged. No live call, no key used.

### 2026-09-26 — D6.11c AI terms stay English in the German texts [F]
- User decision after playing. Scan of every row (en terms → de cells, de loan translations); 47 German cells changed, en none:
  12 card titles, 7 status names + 6 codes, 12 Codex term lines, 4 tech names, 1 flavour, the architecture, 4 achievements.
- Rule A13 + §10 (kept / stays German, with reasons) in `plain-language.md`; `itch.md` §4.4 and `replayability.md` follow.
- `test_plain_language`: `AI_LOAN_TRANSLATIONS_DE` linted over every German row (+1 test). Strings only: no canary.

### 2026-09-26 — Plan: the FLUX 3 Action track cut
- User decision: Block 19 (S7.F1–F5, U7.F1–F4) removed; `flux-action.md` kept with a status line; Jev unchanged; WSL2 optional.
- Run sheet: rows 99–107 struck, S7.IP added as row 97a; next unattended row after S7.IP is D7.1 (row 108). Docs only.

### 2026-09-26 — S7.I itch.io upload [O]
- `release.yml`: web size check (`tools/ci/web_size_check.sh`, web.md §4.2 + `index.html` at the root), `smoke-web` (web.md §16.3, SwiftShader; passed locally on port 8790), `itch` job (butler 15.31.0 from `itchio/butler`, SHA-256 checked; one skip line without key/target; dispatch input `itch`). YAML parsed, every bash block `bash -n`, the gate exercised; no dispatch, no push.
- Title F12/Shift+F12 (debug), `tools/marketing/itch_capture.tscn` (seed 27, bot → *Continue*), `compose_cover.py` (Pillow 12.0.0, centred type); `marketing/itch/`: 12 shots en/de, covers A/B/C, click-to-play. itch.md §8.5 filled.
- Found: the picker peeks out beside the region panel; a `%` wraps alone (Known issues). +5 tests (`test_title_capture`), +1 assert (perf presets drop `tools/marketing`). Scratch APPDATA; no `data/` change, no canary.

### 2026-09-26 — S7.3b Browser performance runs [O]
- Preset 4 `Perf web (local)` (+ `test_export_presets`), `perf_bench.gd` web branch, `tools/web/web_perf.py` (Chromium new headless on the real GPU; iGPU via per-exe GPU preference, removed after).
- `web_igpu` p95 16.4 ms ✓ (playable); `web_cpu`: tick-frame p99 159 ✗, sim tick 10.2/17.1 ✗, *Continue* 8.0 s ✗, process p95 1.7 ✓; loads cold 11.8 s ✓ warm 0.8 s ✓; wasm memory ≤ 278 MB.
- Nothing fixed (per-frame rows pass; the rest is per-tick/first-load work) → two Design questions with the breakdown. Deviations: memory row, masked adapter, persistent profile for the warm load.
- +1 test (`test_export_presets`), 2496 green, scratch APPDATA. No `data/` change, no canary.

### 2026-09-26 — S7.3 The Web build (without §13) [O]
- Shell (`web/shell.html`), `UserPaths`, `WebBridge`, progress file rows, page hidden → mute/autosave/menu, web cue loading, `KeyNames.use_layout`, QOA cues, lossy illustrations, `build/.gdignore`, no web log.
- `tools/web/` (Playwright 1.63.0): Chrome 153, Edge 153, Firefox 155 — load, phone gate, focus, keys, a run, hidden, persistence, settings, online list + Watch, progress file, smoke (hash = `sim_run`), crash screen. Zip 17.55 MB.
- Bug: the boot ate the first click, the web's sound never unlocked on it → `window_input`. Found: `user://` is `/userfs/Doomsday` on the web (Design question).
- +52 tests, 2495 green, scratch APPDATA. Split: §13 → S7.3b. No `data/` change, no canary.

### 2026-09-26 — S6.P Punch list from G6 [O]
- `StatusForecast`: an applied status in the weights' units at today's rates over its days (standing = longest timed, 90 d);
  `Policy` scores `apply_status` by it and `unlock_near_node` by `EffectRunner.near_node`'s price. Target consts on three systems.
- LM 100 seeds old → new win %: greedy 56→53, cyber 13→13, biology 34→32, robotics 25→25, weapons 68→64, persuasion 55→56;
  suppressions/run up (greedy 0→0.7, robotics 0→0.8). 20 seeds × 12 setups × 6 bots: 0 rejected, 0 timeouts. BALANCE §6.6.
- +16 tests (`test_status_forecast`, `test_bots_weigh_emergent_catches`), 2443 green, scratch APPDATA. No `data/` change, no canary.

### 2026-09-26 — D7.I The itch.io page [F]
- `docs/specs/itch.md`: title variants and taglines, short and long description en/de with seven switches, privacy sentence, AI disclosure (all four kinds), content note, credits line, feature bullets.
- itch settings checklist (HTML, embed 1280 × 720, tags, metadata, disclosure), media briefs (cover 630 × 500 route A/B, five real screenshots en/de), S7.I's butler inputs, G7.I's checklist.
- Read itch's docs through their GitHub sources (itch.io itself answers 403): CDN gzips `wasm`/`pck` → web.md §16.4 amended; IMPLEMENTATION S7.I/G7.I amended. No code, no strings.
- Next unattended: S6.P (row 95), then S7.3.

### 2026-09-26 — D7.2 The Web build, the main version [F]
- `docs/specs/web.md`: browsers, single-threaded stock template, size budget with a measured baseline, shell, saves in IndexedDB under `user://doomsday/`, progress file, embed, input, perf, S7.3 tests, S7.I needs.
- Exported the Web preset to scratch and booted it in headless Chrome (CDP): runs; found the `KeyNames` web errors and the `build/` icon leak; `/userfs` confirmed shared.
- Amended audio.md §10.3 (QOA), illustrations.md §4 (WebP 0.9), release.md §6, PLAN §4.4. 22 strings en/de; suite green (2427, 2535 rows).
- Next unattended: D7.I (price and downloads stay the user's), else S7.3.

### 2026-09-26 — G6 (1/2) Balance pass 4 [F]
- Start (100 seeds × 12 setups × 7 bots): Cyber 0–16 %, 1–26 % of runs soft-locked — the Task Force at L3 reset a region's control every ~35 d. Fix: `tf_switch_off` 30 d/`control_decay` 0.005, `tf_raid` 0.005.
- False choice option 1 (five windfall catches + strings), Inheritance governments `harm` ×6; `closed_cross` and Cyber node levers inert. ~390 sweep processes, 14 in parallel, `APPDATA` in scratch.
- Closing 200 seeds: 16 800 runs, 0 rejected, 0 timeouts; `greedy` 37–75 %, Cyber 8–28 %. BALANCE §6; specs (taskforce-endings §3, scenarios §3, replayability §3.2) amended.
- Canary regenerated; `test_scenarios` pins ×6. One punch item (bots weigh the catches) for S6.P.

### 2026-09-26 — S6.12c The Jev backend, mock only [O]
- `BenchChoice`/`Plan`/`Read`, `MockChoiceBackend`, `typesafe_backend.gd`, policy choice branch, cache basis (chat key pinned),
  `model_version(s)`, `choice`/`typesafe` config, tool rules + dry run; `set_api_key.ps1` (not run). `# DESIGN?` in `OptionText` → comment.
- Standard mock-choice suite twice: identical; ranks beside chat mock and bots; copies verified and pass `validate.py`.
  +70 tests, 2427 green. Suite run with `APPDATA` pointed at a scratch folder (the player's `%APPDATA%\Doomsday` untouched).
  No request to TypeSafe; no `data/` content change, canary unchanged.

### 2026-09-26 — D6.9c Decision-model backend (TypeSafe Jev) [F]
- `benchmark.md` §17 (+ touch-ups §0, §1, §3, §8.1, §9, §10.2–3, §11, §13): legal-only choice questions per decision,
  rankings, combiner, cache basis, `model_version`, TypeSafe backend, tool rules, `MockChoiceBackend`, S6.12c tests.
- TypeSafe docs: price published (0.042 USD/M input, output free), versions pinnable, 32 k state limit, not deterministic.
  21 `BENCH_CHOICE_*` rows; S6.P4 answered; `validate.py` takes any backend. Config keys land with their reader in S6.12c
  (`test_bench_config` wants a reader per key — my first try went red, reverted). No content change, no canary. Green.

### 2026-09-26 — S6.P4 Punch list from D6.11 (2/2b) [O]
- `OptionText`: option flags named, story rolls said (`line_without_run` for the Codex); `TechText` *all your {plural}*;
  `StatusText` ends/blocks; Codex tab *Behaviours* (tracker + profile tab); setup lines under difficulty, directives, scenario;
  `INERT_FLAGS` empty; hooks `{regions}`/`{days}` from balance. One `# DESIGN?` (*Stay on Earth*).
- Looked at (windowed, scratch APPDATA, muted): de 150 % 1920 and 400 px, en 1920 — setup, Codex, four cards, tree. No new
  overflow; known phone tech-detail overflow seen again; tabs pressed from code draw two pressed (known issues). +17 tests
  (`test_codex_behaviours_click` real clicks). 2357 green. Sim unchanged (no `data/` JSON change).
### 2026-09-26 — D6.11 (2/2b) Plain-language pass II [F]
- Passes 4, 5, 7 in en + de: 12 emergent bodies (what it is, keep, suppress), 80 options, 45 summaries, 70 tech sentences,
  44 statuses, abilities, directives, difficulty, architectures, scenarios; 12 Codex terms; 286 rows changed, 72 added.
- Read-through headless (the user was playing): raw `FLAG_*` keys in the tree, *Leave Earth* "no other effect", *Destroys 0 ×*,
  empty *Captured*, stale *not active* flags — text fixed, code on the punch list (S6.P4 items 1–8, strings written).
- S6.P3a/b design questions answered (§9.3): story rolls said, flags that decide a run named. `REWRITTEN` += passes 4–5;
  two wording tests updated (*links*, *chance*). 2340 green. Strings only: no canary.

### 2026-09-25 — Plan: itch first, Jev, FLUX track
- User decisions recorded: itch.io browser release first (Steam later, if played), licence all rights reserved, TypeSafe Jev
  as a second benchmark backend, the FLUX 3 Action track after the itch release, Q7 still open.
- Run sheet: S6.P4, D6.9c, S6.12c before G6; Block 18 the itch release (D7.2, D7.I, S6.P, S7.3, S7.I, G7.I); Block 19 FLUX
  (S7.F1–F5, U7.F1–F4); Block 20 Steam and phones (S6.14 moved there). Docs only.

### 2026-09-25 — S6.P3b The whole tree on one screen, lock reasons, mute [O]
- Board fits cells to its room (dense cards, `TechGridDense`), tabs in the title row, coach bottom right over the tree;
  `NodeLockText` (every reason, named) in the detail and the card's tooltip; `MuteButton` + `Settings.muted` + 2 Phosphor icons.
- Looked at (en, de, de 150 %, de 400 px): all three tabs fit at 1920; 150 % scrolls with full cards as before. Found: CI red since
  2/2a (English footer overflow, locale-dependent test) — fixed first (`e00a3b7`); the coach card hid tree cards — moved.
- +8 tests (`test_tech_tree_fit` real clicks and geometry, `test_mute_button`). 2340 green. Phone detail sheet overflow noted.
- Learned: headless tests lay out 1920×1080 logical px at any window size; `-gselect=<file>` runs one test file; screenshots
  came from a throw-away `.shots/` driver scene run windowed with `APPDATA` on a scratch folder (never the player's).

### 2026-09-25 — S6.P3a Effect lines, what changed, explanation first [O]
- `OptionText` (the line under all 172 options), `StatusText` (card, region tooltip, map chip, Codex), `ChangeText` (what changed,
  `{node}`/`{days}` for result lines, the tree's mark), `Format.change` (× → %), cards reordered, 10 tooltips wired, C6 summary check.
- Looked at before/after (en, de, de 150 %, de 400 px): counter-move, opening, story, wire card, tree, containment. Found: the
  driver's answers hit the 4 s result hold and the 3-event cap; `FACTION_ALL` and `STAT_TASK_FORCE_PACE` had no names — fixed.
- +29 tests (`test_option_text`, `test_change_text`, `test_event_option_click` real clicks, `Format.change`). 2332 green. Split: S6.P3b.

### 2026-09-25 — D6.11 (2/2a) Plain-language pass I [F]
- The user's §6 answers applied: *Spuren*, *Präsenz*/Presence, *Einnahmen*/income, *Einfluss*/Influence, *Entdeckt*/Discovered,
  *Im Visier*/Pinpointed, *Technologien*/Technologies, tab *Tarnung*, *Drehkreuz*/Hub, *Finanzdruck*, *Funkstille*, *Level*, *Zugang*/Access (Q7 pending); emergent names kept (Q3 no).
- Passes 1–3, 6 (coach, help, HUD, panels, console) in en + de; 257 rows changed, 10 tooltip keys for S6.P3; status codes de-duplicated (§8).
- `test_plain_language.gd` (caps of §5.3, retired and renamed terms, `(*UCP)` boundaries); amendments in CONTENT §10.1/§10.5,
  `tech-trees.md` §7.4, `first-run.md` §3.5/§6.4. A longer coach text covered the map centre in `test_deploy_click` — shortened. 2303 green.

### 2026-09-25 — S6.P2b Buy-and-place bounced back into the tree [O]
- User report: buying a deploying node did nothing, the tree stayed open. A tree reopened during a
  running site select: `_place()` closed the tree before `Game.site_select`, which cancelled the old
  request, whose `on_cancel` reopened the tree over the new site select. Now site_select first,
  then close. Regression test `test_deploy_click.gd` (real main scene, 7 cases). 2299 green.

### 2026-09-25 — D6.11 (1/2) Text clarity audit and style guide [F]
- User request after two German runs. Scanned all 2 360 rows (script outside the repo): 867 mechanic, 136 card, 546 flavour;
  no option says what it does (172/172), no result what changed, 79 rows per language with magnitude words and no number, 12 collisions.
- `docs/specs/plain-language.md`: rules A/B, explanation-first layout per surface, 22-term glossary, 30 examples (en + de, caps
  measured), plan (passes, S6.P3's C1–C7, checks), seven questions for the user. IMPLEMENTATION rows 89a–89d and entries.
- Fixed: the unquoted German cell of `STATUS_EMERGENT_INSTRUMENTAL_CONVERGENCE_DETAIL` (showed "Alles"), German quotes in two
  English rows, *Abzweige* → *Abgriffe*, a pronoun. Strings only (not in the content hash; no canary). 2292 tests green.

### 2026-09-25 — S6.P2 Map clicks dead over part of the screen [O]
- User report: some anomalies could not be clicked or hovered. `Main` (the root Control of
  `game/main.tscn`, default MOUSE_FILTER_STOP) sits on the root canvas, which the map camera
  moves and scales (`follow_viewport_enabled`), so its rect swallowed pointer events over a
  camera-shaped block of the map since S3.4. Now IGNORE. Regression test
  `test_anomaly_click.gd` probes every region through the real main scene. 2292 green.

### 2026-09-25 — S6.13 Spectator view and the online list [O]
- `ReplayPolicy`, `BenchLibrary`, `GlobalBoard`/`Row`/`Run`, `GlobalBoardClient`; `Game`/`ScreenRouter.start_spectating`, strip, console/ticker/results/pause,
  `ui/modals/benchmark.tscn`, *Online leaderboard* (title settings), `--spectate`/`--global-board`; autosave no longer deleted by bot/watched runs.
- Looked at (de 1920, en 400): public board (*Stand: —*, empty), disabled, offline, a served board with runs; mock and `bot:greedy` watched
  to the verified line; *Watch again*; pause menu without save/load. Found and fixed: the board request dropped by the modal's reparent.
- +66 tests (7 files new/extended). User data: settings.json restored (only `bench_online` added by my launches); autosave/profile changed by the user's own play.

### 2026-09-25 — S6.12b Global leaderboard: verifier, workflow, canary [O]
- `tools/bench/verify_runs.gd`, `bench_verifier.gd`, `verify_record.gd`; `BenchEntry.from_bytes`; canary recorded on Windows
  (`mock`, seed 1001, 300 days); `.github/workflows/leaderboard.yml` (not dispatched; YAML parsed, host key checked against `api.github.com/meta`).
- Temp clone of the public repo + mock standard suite + 70 bot runs + a tampered copy: 80 verified, 1 `hash`; second run
  unchanged; its `validate.py --all` passes (no change needed there). Nothing pushed to it. +39 tests (5 files), 2224 green.
- Publish step rehearsed on a local bare remote (commit as the bot, "nothing to publish", rejected push → rebase → push).

### 2026-09-25 — S6.12 Benchmark tool, headless [O]
- `game/bench/` (config, digest + 6 rows, prompt, action/answer, decision, reply/backend/mock, `ModelPolicy`, score, entry);
  `tools/bench/` (`bench_run.gd`, `open_router_backend.gd`, `bench_cache.gd`, `bench_estimate.gd`, `leaderboard_writer.gd`); `/benchmark/cache/` ignored.
- Mock standard suite twice: entries identical but `recorded`, rows equal; `--bots` 70 runs ≈3 min; brief ≈11 k tokens; the public price
  list read (gpt-4o-mini quick ≈0.46 USD). No model called. `UI_ATTR_POPULATION` added (placeholder). +97 tests (12 files), 2185 green.

### 2026-09-25 — D6.9b The global leaderboard and the cost cap [F]
- Inserted by the user. `benchmark.md` §16 (two repos, records, `verify_runs.gd`, `leaderboard.yml`, online list, canary,
  tests) and §11.5 (pre-flight estimate, `--yes`, exit 7); §0/§1/§3/§8.3/§10.3/§11/§12.7/§13–§15 amended; release.md §0/§6.2/§9.2/§10.
- `benchmark.json`: cap 10 → 2 USD, `estimate`, `global`; SCHEMA row; 20 strings en/de. S6.12 amended, S6.12b added, S6.13 widened.
- Waiting on the user: deploy key + secret, the 2 USD cap, the online setting. No code. Suite green.

### 2026-09-25 — S6.11 Performance pass [O]
- Bench + wrapper + `tick_profile.gd`; `Game.last_tick_usec`; `first screen` line. Fixes: chart geometry per draw, strip fill, strip marks
  cache, tech-card bind skip, status chips reused, `ModifierStack` memo, pressure/gain/capacity factors, TF adjacency, cue preload, bloom table.
- 4 threads: tick 4.10 → 1.54 ms, analysis tick frames 575 → ~14 ms. Fail: tick-frame p99 15.6 (13), iGPU working set 1.4 GB, rare GPU stalls.
- 59 `sim_run` hashes identical. Release title checked at 4 sizes (Known issues). User played meanwhile; logs kept out of `user://logs`. +15 tests, 2088 green.

### 2026-09-25 — S6.10 Export presets and release CI [O]
- `export_presets.cfg` (4), `release.yml`, CI `export-smoke`, `tools/ci/smoke_check.sh`; `--smoke` (`game/smoke_run.gd`);
  `Game.debug_allowed`; `Settings.persist`, `SaveManager.save_dir`; version 0.6.0; `assets/app/icon.svg`; *Open data folder*.
- User folder `%APPDATA%/Doomsday/`; `UserDataMigration` copied the user's 4 files (hash-identical), old folder untouched.
- Exported all three locally; Windows release smoke headless and windowed: exit 0, hash = `sim_run`'s. +36 tests, 2073 green.

### 2026-09-25 — S6.9 PlatformService (null backend) and achievements [O]
- `game/platform/` (`PlatformBackend`, `NullPlatformBackend`, `AchievementDef`, `AchievementBook`), autoload
  `PlatformService` (sync at start and on `achievements_earned`, overlay → pause menu, start line in the log);
  profile `achievements` (kept by reset), `last_run_achievements`; Statistics section 4; results chips.
- Looked at: Statistics de/en 1920, de 400 (state under the detail). User data folder unchanged (S6.10 moves it).
  +87 tests (5 new files), 2037 green.

### 2026-09-25 — S6.P1 Punch list from D6.8 [O]
- `FocusRing.is_covered` + `SlidePanel.covered_rect()`: the session ring drops a HUD zone an open panel covers >50 %; the site
  prompt sits in `%PromptRow` with a spacer, centred right of the region panel; `SlidePanel` refocuses `primary_focus()` when
  the focused control hides or is freed; `MapView` parks Society during site select; `synth.py` ranges −12/−11; coach top edge on
  a phone over a modal (`safe_top` from the session); `Game.is_hold_change()` + `hold` in `speed_changed`'s audio fields.
- Three `# DESIGN?` retired. Looked at (de, 1920 + 150 %, 400 × 860): prompt right of the region panel, coach at the
  top over the pause menu and back after. +15 tests (2 new files), 1950 green.

### 2026-09-25 — D6.9 Benchmark and spectator mode [F]
- No open design questions. `docs/specs/benchmark.md` (S6.12 tool, S6.13 spectator); `data/benchmark.json`;
  135 `BENCH_*` / spectator strings en/de; SCHEMA §10 row; release.md §6.2 include note.
- FLUX-3 Action checked on Hugging Face: a robot policy, not a chat model → *Waiting on the user*.
- No code. Suite green.

### 2026-09-25 — D6.8 Release engineering [F]
- Nine design questions answered (Decisions; punch list for the new S6.P1); `audio.md` §10.1 ranges
  widened, speed cues silent on holds in `audio.json`.
- `docs/specs/release.md`; `data/achievements.json` (34) + 78 strings en/de; SCHEMA §9/§10 rows.
- Stale S6.3 punch list removed. No code. Suite green.

### 2026-09-25 — S6.8c Accessibility III [O]
- `A11y` + names/readouts (chips, bars, top bar, assets, tracks, tabs, log rows, slots, coach, prompt,
  console, ticker); §6.3 fixes; `text_width` on modal/wire/coach/captions/side panel/cells/dock;
  statistics columns, compact Codex tab strip, coach height cap; focus margins in scrolls.
- §12 at 150 % de, 1920 + 400: title, Codex, statistics, settings, *Steuerung*, setup, origin by
  cursor, tree (`●`), node bought, collect, dateline, `Tab` ring; phone coach/Codex/menu. Narrator
  and pad owed (Waiting on the user). +7 tests, 1935 green.

### 2026-09-25 — S6.8b Accessibility II [O]
- Focus rings in use (session zones, modal trap + coach companion, panels take and give back focus),
  `MapFocus` + cursor reticle, `ChipButton`, speech (console, headlines 8 s, announced cues, modal
  openings, boot, title), *Controls* modal + *Steuerung*/*Bildschirmleser* rows, confirm's `Escape`.
- Looked at: keyboard-only origin, `Tab`, pause menu, *Controls* swap (de, 1920). +31 tests, 1928 green.

### 2026-09-25 — S6.8a Accessibility I [O]
- S6.8 split in three (a/b/c). `[input]` actions + pad on accept/cancel; keys through actions
  everywhere; `KeyBindings` (+ Settings `keys`, `announce_headlines`, OS reduced motion); `KeyNames`
  and §10.2's strings; `LiveRegion`, `LiveQueue`, `FocusRing`, `MapNav`, `RegionSpeech`.
- Outer focus ring for every focusable type, `TASK_FORCE_DIM` `#CC4040`, `text_width`, console reading
  time. Not looked at on screen yet (S6.8c). +58 tests, 1897 green.

### 2026-09-25 — S6.7 Tutorial II [O]
- Coach: ten hints (per profile), one queue, stale drop, step 7 on openings, *Mehr dazu*; `Settings.hints`,
  `hints_seen`; `HelpPages`, Codex *So spielst du* first, `open(tab, entry)`; `ModalHost.open_over`.
- `F1` (session/title), `HelpButton` on tree/containment/analysis/region, pause + sheet rows, `HELP` glyph.
- Looked at: hints de/en 1920/400/150 %, Codex over tree and hint, sheet → help on phone. Two placements
  as `# DESIGN?`. +63 tests, 1839 green.

### 2026-09-25 — S6.6 Audio II: the sound set [O]
- `tools/audio/` (uv env: numpy, scipy, soundfile, pyloudnorm; `.gdignore`), `synth.py`: additive
  band-limited voices, circular loops, post, WAV/OGG (fixed Ogg serial), measure, `--check`.
- 64 files in `assets/audio/` + `.import` (PCM, loop); ambience rotated for clean joins; `--check` ok twice.
- Looked at by measurement (peaks, LUFS, joins, spectrogram sheets); not listened to (Waiting on the
  user). `test_audio_files.gd`; row `audio_synth`. +8 tests, 1776 green.

### 2026-09-25 — S6.5 Audio I: service, buses, cues, captions [O]
- `Audio` autoload (after `ProfileManager`), `AudioSheet` + five records, `AudioRules`, `VoiceLedger`/
  `AudioVoice`, `CaptionText`, `ui/hud/caption_stack`; `Settings` volumes/captions/background; seven menu rows.
- Calls in `ModalHost` (open/close) and boot (power, each line). Files missing: warnings only.
- Looked at: menu 1920 de / 400 en, captions `[Phasenwechsel: Enttarnt]`, faction and anomaly lines
  at 1920/400; no errors. +93 tests, 1768 green. Deviations and one design question recorded.

### 2026-09-25 — S6.4 Icon pipeline [O]
- `tools/icons/vendor_icons.py` (pins + SHA-256 checked, 142 files normalised, `--check`), `Icons`,
  `IconRect`, `Glyphs` on files (+ `draw_scaled`), `tools/build_icon_atlas.gd`, `ICON_*` tokens, button icon colours.
- Placements: tech node footer (gives way when full — DESIGN?), detail pane, Codex, architecture card,
  region-panel statuses/actions, ability picker, wire-card counter-move. Rows `icons_phosphor`/`icons_game_icons`.
- Looked at: gallery 1920/400/4K, session tree 1920/400/4K, status row. +20 tests, 1675 green.

### 2026-09-25 — S6.3 Credits and licences screen; the illustration hooks [O]
- `CreditsData` (load/validate `credits.json`, visibility, authors), `ui/modals/credits.tscn` on the
  title after Settings; engine/file/game-icons pages; `assets/licences/CC-BY-3.0.txt` (SHA-256 as §11.3).
- `IllustrationSlot` mipmap filter, compact 4 : 3, `width`; the four wins name their pictures
  (`EndingDef.illustration`, validator, SCHEMA); results (420) and Codex slots; four test files.
- Looked at: credits + engine page 1920/400 (de, en 150 %), results win/loss, discovery and wire card
  full/400 with a temporary 1120 × 840 picture (removed). +41 tests, 1655 green.

### 2026-09-25 — S6.2 Phase-shift variants and map polish [O]
- Open accent → `#FFD08A` family (`UiTokens.OPEN`), theme rebuilt; `MAP_SOCIETY`, `MAP_SMOOTH_OUTLINE_ZOOM`, `MAP_OUTLINE_MASK`.
- `map.gdshader`: coast pass (borrowed region at `land_mask` alpha), mask-built selection/eligible outlines from zoom 2, `OVERLAY_SOCIETY`; `RegionData` row 2; picker's fourth view.
- Looked at: zoom 1.4/2.6/4.5 (Mediterranean, Caribbean, cold/open, selection, origin request), society view stepped vs. panel stage, gallery **O**. +15 tests, 1614 green.

### 2026-09-25 — S6.1 Post-processing pass [O]
- `ScreenFx` autoload (layer 1025, registered last), `screen_fx.gdshader` (CA, chroma bloom, wash,
  vignette, scanlines, grain, Bayer dither, dissolve), `ScreenFxRules`/`Params`, `FlashLimiter`, `FX_*` tokens.
- Wash moved out of `ModalHost`, router fade → dissolve, `Settings.screen_effects` + pause-menu row, **V**.
- Looked at 1920/400, cold/open, Off/Subtle/Full, reduced motion; web-safe grep clean. +38 tests, 1599 green.

### 2026-09-25 — S5.9 The Task Force against dormancy; the scenario levers [O]
- The mark: `TaskForce.marked` (save `marked` by id), `TaskForceRules.dormancy_hides`, `_fizzle`
  marks on `dormant`, `task_force_marked` (console/log/headline/panel line), bots Misdirect instead.
- `closed_cross` (SpreadSystem, source-side, no roll at 0) and `term_scale` (ScenarioDef, validator,
  breakdown); Airgap Earth/The Inheritance data. `HEADLINE_TF_MARKED` shortened to the caps.
- +30 tests, 1561 green. 100-seed check + lever isolation under *Balance baselines*: both claims fail.

### 2026-09-25 — D6.7 Illustration style and briefs [F]
- `docs/specs/illustrations.md`: style, reference pair, 25 briefs + key art, size/import, checks,
  provenance, licence rows/credits, S6.3's hooks (slot, endings field, results/Codex, tests).
- Licences read at source: Qwen-Image-2512/-Edit-2511 and FLUX.2 [klein] 4B Apache-2.0; five
  models rejected. VISUALS q4: vignettes cut. 1 string. No image generated. Suite green (1531).

### 2026-09-25 — D6.6 Accessibility [F]
- `docs/specs/accessibility.md`: AccessKit names, `LiveRegion`/`LiveQueue` speech, keyboard/pad map
  (`MapFocus`, `MapNav`), `FocusRing`, modal/panel focus fixes, outer focus ring, `KeyBindings` + *Controls*.
- Colour audit (Machado + ΔE₀₀, L\* ramps, 3 : 1 marks): four fixes. 150 % looked at (title, setup,
  Codex, statistics; 1920/400): statistics word-break, phone Codex tabs. 56 strings; `audio.json`
  `announce` ×7; `help.json` controls 5 paragraphs. Suite green (1531).

### 2026-09-25 — D6.5 Tutorial II and help [F]
- `first-run.md` §6: ten once-per-profile hints (trigger, ring target, end, page), step 7 narrowed,
  `Settings.hints`/`hints_seen`, the Codex's *How to play* tab, `F1`/**?**/menus/*More*, `open_over`, `HELP` glyph.
- `data/help.json` (14 pages), 84 strings en/de, SCHEMA §9/§10, icons.md §8.1 note. Suite green (1531).

### 2026-09-25 — D6.4 Audio direction and cue sheet [F]
- `docs/specs/audio.md`: buses from data, settings rows, trigger/match vocabulary, admission and
  voice stealing, ducking on players (web-safe), ambience per phase, four stems on tension = heat.
- `data/audio.json` (56 cues, 50 triggers), `tools/audio/recipes.json` (64 synth recipes), 32 strings
  en/de, SCHEMA §10, ASSET_LICENCES (Kenney CC0 fallback verified). Suite green (1531).

### 2026-09-25 — D6.3 Custom silhouettes [F]
- 24 illustrative + 3 chrome SVGs (`assets/icons/custom/`), built by `tools/icons/draw_silhouettes.py`,
  rasterised with Godot's SVG renderer at 16–160 px and iterated on contact sheets.
- `voluntary_pause` failed the 24 px read → stand-in stays. Departures in `icons.md` §9.1.
- `ASSET_LICENCES.md` *Icons (shipped)*: `icons_custom`. Suite green (1531).

### 2026-09-25 — D6.2 Icon system and the credits screen [F]
- `docs/specs/icons.md`: Phosphor 2.1.1 + game-icons.net `82d9488` (URLs, SHA-256), normalisation,
  `DPITexture` per size, `Icons`/`IconRect` API, placements, atlas tool, vendoring tool, tests.
- `data/icons.json` (179 ids, looked at on contact sheets), 25 + 3 silhouette briefs, `data/credits.json`,
  31 strings, SCHEMA §10, `ASSET_LICENCES.md` *Id* column. VISUALS q5 answered. 1531 green.

### 2026-09-25 — D6.1 Screen effects, phase-shift variants, map polish [F]
- `docs/specs/polish-visuals.md`: `ScreenFx` pass (8 stages, heat, costs, tokens), triggers
  (impulses, wash moved in, dissolve), *Screen effects* setting, reduced-motion table, flash rules.
- UI q3 / VISUALS q3: two palettes stay; Open accent → `#FFD08A` (colour audit, ΔE floor 9).
  Map: coast + mask-outline pass (looked at zoom 4); society overlay kept. 4 strings; 1531 green.

### 2026-09-25 — D5.5 The Task Force against dormancy; the scenario levers [F]
- **The mark** (`taskforce-endings.md` §14): a `dormant` fizzle marks the region 40 days; dormancy
  no longer hides it meanwhile. **`closed_cross`** (Airgap Earth's fleets) and **`term_scale`**
  (The Inheritance: deaths and Harm double) in `scenarios.md` §8. BALANCE §5.7 (3)–(4) answered.
- Strings: 4 new, 3 revised (en/de). Eight-item punch list for S5.9. Suite green (1531).

### 2026-09-25 — S5.P2 Punch list from balance pass 3 [O]
- `OutcomeSystem`: a drifted Ascendance → `LOSE_SUPPLANTED` (`_drifted` line); `Policy._lost_run_flags`
  (`LOST_RUN`) — greedy/cyber/robotics/persuasion suppress Value Drift; `StrategyPolicy.ability_order()`
  puts `restrain` first (not `weapons`); harness columns `task_force_misdirected`/`_dormant`; push-in marker gone.
- +10 tests (1 new file), 1531 green. 100-seed check of Swarm and Weapon under *Balance baselines*.

### 2026-09-25 — G5 (3/3) Detailed plan for M6–M7 [F]
- Broke M6/M7 into Blocks 12–19 (IMPLEMENTATION §4 rows 65–104, §5 entries with *Read first* and
  *Done when*, §6 table): S5.P2 heads the build; D5.5 takes the dormancy question.
- AI-only work first; **[needs user]** rows last per milestone and skipped when unattended.
- CONTENT q4 confirmed (post-launch mode). Docs only, no suite run.

### 2026-09-25 — G5 (2/3) Balance pass 3 (tuning; the M5 gate waits) [F]
- Re-baselined the S5.P tree (100 seeds × 9 setups × 7 bots), ~130 sweep processes, closing 200
  seeds (12 600 runs, 0 rejected) — BALANCE §5. Data only: Weapon (quiet start), three scenarios.
- Found the Swarm stall's cause (Value Drift soft-lock) — rule designed (Supplanted), on the punch
  list with the bots' Restraint/Value Drift answers. Push-in zoom answered. Two tests adjusted
  (*Deviations*). Suite green (1521).

### 2026-09-25 — S5.P Punch list from G5 (1/3) [O]
- Built all nine: `validate_autophagy_bound`; `TASK_FORCE`/`_DIM` via `UiTokens.status_token`
  (marker, road, rings, links, overlay slot 6, chips); `DriftChip` + Drift block; the emergent
  spark; `RunLogText.verdict_of`; `MapCamera.push_in` + hold; compact version caption; labs comment.
- +27 tests (3 new files), 1521 green; theme rebuilt. One `# DESIGN?`: the push-in's zoom.
- Looked at (de/en, 1920/400): title, drift chip/block, team + `tf_*` rings, Log tab after a clean
  greedy Swarm ending, push-in by hand; `ProfileManager.reset()` afterwards.

### 2026-09-25 — G5 (1/3) Design questions answered, punch list [F]
- Answered all ten open questions (Decisions 2026-09-25); amended opposition §8.5, loop-content,
  replayability §2.5 and §3.1, taskforce-endings §9, analysis §8, screens-full §3 and §7.
- Data: `harvested`, `defected`, `drift.defect_days` 30 → 25. Strings: 6 new rows, 5 revised.
- Nine-item punch list for S5.P; tuning handed to balance pass 3 (*Balance baselines*). Block 11
  split into G5 (1/3), S5.P, G5 (2/3), G5 (3/3). 1494 tests green.

### 2026-09-24 — S5.8 Scenarios [O]
- Built `ScenarioDef`/`ScenarioStatusDef`, the loader and validator of `scenarios.json` (SCHEMA
  §6j), `RunSetup.scenario` (save v3 in place), `ScenarioStart` (statuses and flags at the origin,
  the head start on the day of discovery), the origin reason `origin_scenario`; moved the data out
  of staging (`disconnected` into `statuses.json`, three headlines into `headlines.json`); the
  setup's scenario row, the intro in the origin prompt, *architecture · scenario* in Statistics;
  `scenario=<id>` on the sim tools and a `scenario` column in their CSV.
- Tests: `test_scenarios.gd` (25), setup screen (+3), profile (+1), region panel (+1). Fixed on the
  way: the scenario row drew two chosen buttons (Known issues), `ModalHost._focus_first` grabbed
  focus outside the tree on a screen swap, a boot-stamp test read the player's locale. 1488 green.
- Looked at in the running game (en/de, 1920): the setup row, Airgap Earth's `NT` rings, the
  refusal line, the first headline. The profile was put back with `ProfileManager.reset()`.
- The 500-seed reports per architecture and scenario are under *Balance baselines*.
- Follow-up (same day): tests for the prompt's scenario intro, the Statistics pair and its
  replay, the Research Agent's labs track plus the head start, and one 800-day run of every other
  architecture in a scenario (Open Weights' start leak reaches disconnected regions — its leak is
  no link). Looked at the setup's scenario row on a 400 px phone. 1494 green.

### 2026-09-24 — S5.7 Screen flow complete [O]
- Built the router's four screens, `boot.tscn` (eleven lines / two, skip), the title rebuilt with
  `Globe` (shader + `globe_ids.png` from the map pipeline), `setup.tscn` with `ArchitectureCard`,
  `codex.tscn` / `statistics.tscn`, `CodexTracker` and `CodexEntries`, `Settings.boot_always` and
  *Reset progress* on the title, the ending pull-out (`MapCamera.pull_out`, input locked) and the
  results' *Unlocked* chips; `LogicalScale` shared by main and session.
- Tests: `test_screen_router.gd` (12), `test_setup_screen.gd` (10), `test_codex_tracker.gd` (8),
  `test_title_modals.gd` (7), `test_globe.gd` (7), settings (+1), pause menu (+2). 1458 green.
- Looked at in the running game (Deviations lists the set). The test run I played counted into
  the player's real profile; `ProfileManager.reset()` put it back to the empty file it was.

### 2026-09-24 — S5.6 Endings [O]
- Built the nine outcomes and §6.2's order, `EndingDef`/`EndingLineDef`, the loader and validator
  of `endings.json` (SCHEMA §6i), `EndingResolver`, the `when` keys `flag_any`, `dominant_branch`,
  `dominant_tree`, `task_force_actions_min`; the results screen's variant, epilogue and Supplanted
  kicker; moved the six chains, `endings.json` and the headlines out of staging (staging now holds
  `scenarios.json` alone).
- Tests: `test_ending_resolver.gd` (18), outcome (+10), conditions (+5), chains (+10, walker over
  37 steps), results (+2). Looked at: rendered DE/EN desktop and a 400 px phone at 150 %.
- Batch (Language Model, standard, 40 seeds, 0 rejected over seven bots): Persuasion now wins
  23 % by Merge (35 % Ascendance); greedy's wins read `_machines`, weapons' `_loud`, biology's
  `_quiet`; most containment losses are `_task_force` or `_researcher`. No bot reached Escape or
  Supplanted (the Child's default is *decline*; no bot books the launch).

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
  `%APPDATA%/Godot/app_userdata/Doomsday/shots/s4_9/`, `de_` German,
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
`%APPDATA%/Godot/app_userdata/Doomsday/session_{en,de}_{1920,400}_day*.png`.
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
reference shots at `%APPDATA%/Godot/app_userdata/Doomsday/gallery_{en,de}_{1920,400}.png`
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
