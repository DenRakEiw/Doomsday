# The Web build — the main version (itch.io, in the browser)

D7.2 (2026-09-26, unattended). Builds from it: **S7.3** (everything below except §16) and
**S7.I** (§16: the itch settings, the size check and the web smoke in `release.yml`). **D7.I**
takes §2, §4.5 and §7.4 for the page text. Strings in `data/loc/strings.csv` (§18). Builds on the
user's decision of 2026-09-25 (*Decisions*: itch.io in the browser first, the single-threaded Web
build is the main version, Steam later), `release.md` (presets, filters, CI, the performance
budget), `audio.md` §3.4/§5.8 (samples, the first-input unlock), `benchmark.md` §16.6 (the online
fetch) and `accessibility.md` §1 (screen readers on the web are not a release criterion).

This spec replaces the "web demo" of PLAN §4.4/M7: **no demo limits — the whole game.**

---

## 0. What this spec decides

1. **Desktop browsers only at release:** Chrome and Edge (last two major versions), Firefox
   (current and ESR), tested on this PC; Safari 17+ supported on a best-effort basis (no Mac here).
   **Phones and tablets are out** until D7.1/S7.1: the page warns before downloading (§5.3).
2. **Single-threaded Compatibility build** from Godot's stock `web_nothreads_release` template —
   no SharedArrayBuffer, no cross-origin isolation, itch's *SharedArrayBuffer support* **off**, no
   PWA, no GDExtension. A custom engine template (3D and unused modules stripped) is **not** made.
3. **Size budget:** the web zip (deflate, ≈ what a browser downloads when the host compresses)
   **≤ 25 MB target, 30 MB hard**; extracted ≤ 80 MB; no file over 64 MB; ≤ 50 files. Measured
   baseline **20.39 MB zip / 53.10 MB extracted** (§4). To stay inside it after the pictures:
   **illustrations import lossy (WebP 0.9)** instead of lossless (§4.4) and **cue WAVs import as
   QOA** (§4.4); the loops, fonts and wasm stay as they are.
4. **A custom HTML shell** (`web/shell.html`): the game's own loading screen with progress, a
   phone gate, a feature check, a friendly error and crash screen with a *Reload* button, en/de,
   **no external request** of its own (§5).
5. **Saves, profile and settings live in the browser** (IndexedDB behind `user://`). Because every
   Godot game on itch's origin shares one `/userfs`, **all our files move under
   `user://doomsday/` on the web** (§7.1). **Progress export/import** (the profile as a JSON file)
   is **in scope** — two rows in the title's settings, web only (§7.4).
6. **The itch embed: 1280 × 720**, fullscreen button on, click to launch, not mobile-friendly
   (§8, §16). The 1100-px compact rule is unchanged.
7. **Page hidden** (another tab, minimised): the run is autosaved, the pause menu opens, the sound
   is muted until the page is visible again (§6.3).
8. **What the web turns off:** *Quit*, *Open data folder*, *Background audio* (already), the file
   log, debug keys (release export), the benchmark tool (never shipped). **Kept:** the online
   leaderboard list (CORS works), *Watch*, achievements (in the profile), every setting (§10).
9. **Performance** is judged in a browser on this PC's integrated GPU and under 2.5× CPU
   throttling, against web budgets in §13. **No analytics, no telemetry**, as everywhere.
10. **Two engine gaps found while measuring** are fixed in S7.3: `DisplayServer.keyboard_get_label_from_physical`
    errors on the web (§9.3), and the cue files load on first play on the web (§6.2).

**Not in scope:** touch controls and a phone layout (D7.1/S7.1), a PWA or offline mode, cloud
saves, the itch page text and art (D7.I), the upload job itself (S7.I), screen-reader support in
the browser beyond what the engine gives (accessibility.md §1).

| Step | Sections |
| --- | --- |
| **S7.3 Web build** | §3–§15, §17 (tests and acceptance), §18 (strings are already in the CSV) |
| **S7.I itch.io upload** | §16 (settings, channels, the size check, the web smoke job); reads §4.3 |
| **D7.I itch.io page** | §2 (which browsers), §4.5 (the download size), §7.4 (progress lives in the browser), §11 (the privacy sentence's facts) |
| **G7.I** | §17.3 (what the user checks on the restricted page) |

---

## 1. Files

| File | What |
| --- | --- |
| `web/shell.html` | **new** — the custom HTML shell (§5); not a resource, never in the `.pck` |
| `game/platform/user_paths.gd` | **new**, `class_name UserPaths` (`RefCounted`, static): the `user://` root per platform (§7.1) |
| `game/platform/web_bridge.gd` | **new**, `class_name WebBridge extends Node`: the one place that calls `JavaScriptBridge` (§6.3, §7.3, §7.4) |
| `game/autoload/platform_service.gd` | adds a `WebBridge` child on the web; `PlatformService.web: WebBridge` (null elsewhere) |
| `game/autoload/profile_manager.gd` | `import_dict(raw: Variant) -> String` and `export_text() -> String` (§7.4) |
| `game/autoload/audio.gd` | the web's cue preload after the unlock (§6.2); mute while the page is hidden (§6.3) |
| `game/session/session.gd` | page hidden → autosave + pause menu (§6.3) |
| `ui/modals/pause_menu.gd` | the two progress rows and their note, title settings, web only (§7.4) |
| `ui/screens/title.gd` | `UI_TITLE_VERSION_WEB` (§12) |
| `ui/components/key_names.gd` | no layout lookup on the web (§9.3) |
| `tools/perf/perf_bench.gd` | a web branch (§13.2) |
| `tools/web/` | **new** — `pyproject.toml` (uv, Playwright pinned), `serve.py`, `iframe_host.html`, `web_check.py`, `web_perf.py` (§13, §17.2) |
| `export_presets.cfg`, `project.godot`, `.gitignore` | §3 |
| `assets/audio/ui/*.wav.import`, `assets/audio/alerts/*.wav.import` | `compress/mode=2` (§4.4) |
| `tests/…` | §17.1 |

Every place that asks "am I in a browser" uses `OS.has_feature("web")` through a `FEATURE_WEB`
constant as the code already does (five files have one). Pure decisions get a static seam that
takes the answer as a parameter (`has_data_folder()` is the pattern), so a headless desktop test
can check the web branch.

---

## 2. Which browsers, which devices

| | Status at the itch release | How it is checked |
| --- | --- | --- |
| **Chrome** (Windows, macOS, Linux; last two major versions) | supported | S7.3 on this PC (§17.2), G7.I by the user |
| **Edge** (last two) | supported | S7.3 on this PC |
| **Firefox** (current and ESR) | supported | S7.3 on this PC (Playwright's Firefox) |
| **Safari 17+** (macOS) | best effort — expected to work, not tested | nobody here has a Mac; a player's report goes to the punch list |
| **Phones and tablets** (any browser) | **not supported** — a notice before the download, *Start anyway* possible (§5.3) | D7.1/S7.1 (touch) |
| **itch.io desktop app** | not a target (it plays the same page in its own Chromium; saves are separate from the browser's) | — |

**What a browser must have** (the shell checks the first three before downloading, through the
engine loader's own `Engine.getMissingFeatures({threads: false})`): WebAssembly, WebGL 2, a secure
context (itch serves HTTPS); and in practice hardware acceleration switched on — WebGL 2 on a
software rasteriser runs, but far below the §13 budget.

**Minimum machine:** the desktop low-end target of `release.md` §11.1 (i5-8250U, UHD 620, 8 GB)
in Chrome — the budgets of §13 are for it. Windows 10+, macOS 13+, a current Linux desktop.

---

## 3. The export

### 3.1 The `Web` preset (`export_presets.cfg`, preset 2)

`release.md` §6.1 stands; S7.3 changes or confirms:

| Option | Value | Why |
| --- | --- | --- |
| `variant/thread_support` | `false` | §0 item 2; no SharedArrayBuffer, so itch's option stays off and the leaderboard fetch needs no CORP headers |
| `variant/extensions_support` | `false` | no GDExtension on the web (GodotSteam is Steam-only) |
| `vram_texture_compression/for_desktop` · `for_mobile` | `true` · `false` | unchanged; nothing in the game is VRAM-compressed today (the map is lossless, the icons are `DPITexture`s) |
| `html/custom_html_shell` | `"res://web/shell.html"` | §5 |
| `html/head_include` | `""` | the shell carries everything |
| `html/canvas_resize_policy` | `2` (adaptive) | the canvas fills the iframe and follows every resize (§8) |
| `html/focus_canvas_on_start` | `true` | unchanged; the first click still decides (§9.1) |
| `html/experimental_virtual_keyboard` | `false` | no phones (§2) |
| `html/export_icon` | `true` | the favicon is the app icon |
| `progressive_web_app/enabled` | `false` | no offline copy, no service worker, nothing cached beyond the browser's own cache |
| `exclude_filter` | release.md §6.2's list **+ `build/*, web/*`** | §3.3 |

### 3.2 Project settings

| Setting | Value | Why |
| --- | --- | --- |
| `debug/file_logging/enable_file_logging.web` | `false` | the web has no log a player could send; a log in `/userfs` would be written into a store shared with other games (§7.1). The browser console has every line (§14) |
| `audio/general/default_playback_type.web` | unchanged (samples) | audio.md §3.4; S7.3 confirms the stems stay in step (§17.2 item 9) |
| `display/window/dpi/allow_hidpi` | unchanged (`true`) | the canvas renders at device pixels, so a 150 % laptop is sharp (§8.2) |

### 3.3 Filters

- **`build/*` joins every preset's `exclude_filter`.** Measured: `build/` has no `.gdignore`, so
  the last local web export's `index.icon.png`, `index.png` and `index.apple-touch-icon.png` were
  imported as project resources and **ship inside every `.pck`** (20 KB today, and whatever a
  future export leaves there). Also add `build/.gdignore` (with `!build/.gdignore` in
  `.gitignore`, which ignores `build/`) so the editor stops importing it.
- **`web/*`** joins the exclude list (the shell is read by the exporter, not the game).
- `test_export_presets.gd`'s lists gain both patterns (release.md §6.2's rule).

### 3.4 Engine template

The stock `web_nothreads_release.zip` of 4.7.2 (installed, `release.md` §9.3). **Not made: a
custom template** built with `disable_3d=yes` and unused modules off. It would roughly halve the
wasm (39.5 MB → ~20 MB raw, 10.1 → ~5 MB compressed) — **cost:** an Emscripten toolchain and a
SCons build on this PC and in CI, a template to rebuild and re-verify at every engine update, and
a second engine binary whose bugs are ours. At a 23 MB download (§4.5) it buys ~5 MB. It is the
first lever if §4's budget is ever missed or itch serves the wasm uncompressed (§16.4).

---

## 4. Size

### 4.1 Measured baseline (2026-09-26)

Build `0.6.0` at `465c3a6`, `--export-release "Web"` into a scratch folder, stock template.
MB = 10⁶ bytes. *Compressed* = `gzip -9`, which is what a host serving `Content-Encoding: gzip`
sends; the zip is deflate at level 9 over the same files.

| File | Raw | Compressed |
| --- | --- | --- |
| `index.wasm` (the engine) | 39.51 MB | 10.08 MB |
| `index.pck` (the game) | 13.24 MB | 10.21 MB |
| `index.js` (the loader) | 0.28 MB | 0.07 MB |
| `index.html`, two worklets, three icons | 0.07 MB | — |
| **Total** | **53.10 MB** (9 files) | **web zip 20.39 MB** |

**Inside the `.pck`** (1 175 files, parsed from the pack's directory):

| Contributor | Raw | Deflated | Note |
| --- | --- | --- | --- |
| Cue WAVs (56 files, PCM 16-bit 44.1 kHz) | 5.74 MB | 3.59 MB | the largest: `end_win` 0.88, `end_lose` 0.71 (the two stereo cues) |
| Loops (8 OGG Vorbis q0.5 stereo) | 4.06 MB | 3.87 MB | `amb_covert` 0.83, `amb_open` 0.68, `amb_boxed` 0.66, `mus_edge` 0.61 |
| Scripts (compressed tokens) | 1.26 MB | 1.26 MB | |
| Fonts (JetBrains Mono ×3, Space Grotesk) | 0.53 MB | 0.53 MB | already Latin subsets |
| Textures (map masks, ID maps, app icon) | 0.44 MB | 0.44 MB | lossless; `border_mask` 0.23, `land_mask` 0.13, `id_map` 0.04 |
| Translations (en, de) | 0.33 MB | 0.16 MB | |
| Data JSON, scenes, other | 0.59 MB | 0.16 MB | |
| Icons (SVG → `DPITexture`) | 0.09 MB | 0.09 MB | ~160 icons, a few hundred bytes each |

So the download is **half engine, half game — and the game is three-quarters sound.** The map,
icons and fonts are negligible. What is **not in it yet:** the 24 illustrations (D6.10).

### 4.2 The budget

| Measure | Target | Hard limit | itch's own limit (forum answers, 2026) |
| --- | --- | --- | --- |
| Web zip (deflate -9) | **≤ 25 MB** | **30 MB** | 500 MB extracted per upload |
| Extracted total | ≤ 70 MB | 80 MB | 500 MB |
| Largest single file | — | 64 MB | 200 MB |
| Files in the zip | — | 50 | 1 000 |

*Why 25 MB:* on a 16 Mbit/s line that is ~13 s of download, on 50 Mbit/s ~4 s — the range where
a browser game still starts "now". The wasm alone is 10 MB compressed and cannot shrink without
§3.4's template, so the game's share is ~15 MB. *Why not lower:* every further MB costs sound or
picture quality (§4.4) or the custom template.

### 4.3 How it is checked (S7.I builds, S7.3 records)

`tools/ci/web_size_check.sh <zip>` (S7.I): unzip to a temporary folder, fail with one line per
breach of a *hard* column, print a warning when the zip passes 25 MB; print the four numbers
either way. Runs in `release.yml` after the web zip is made. S7.3 records the export's numbers in
*Performance notes* (the table of §4.1, re-measured) after its changes.

### 4.4 Reductions — taken and not taken

| Reduction | Saves (download) | Cost | Decision |
| --- | --- | --- | --- |
| **Illustrations lossy** — `compress/mode=1` (WebP lossy), `compress/lossy_quality=0.9`, mipmaps on, instead of illustrations.md §4's lossless | the 24 pictures would add ~30–40 MB lossless (1120 × 840, ≤ 1.2 MB PNG each, + ⅓ mipmaps, PNG does not deflate); lossy ≈ 4–6 MB | slight ringing at hard edges on the six flat steps — under the screen pass's scanlines, grain and dither (polish-visuals.md) it is not visible at the slot sizes (≤ ¾ of the source at 4K). Same file on desktop | **Taken** (amends illustrations.md §4; D6.10 checks each picture at 0.9 on its contact sheet and raises that picture to 0.95 if a flat edge rings) |
| **Cue WAVs as QOA** — `compress/mode=2` in every cue's `.import` | 3.59 → ~1.2 MB (QOA is 3.2 bits a sample, ~5× smaller than PCM; it does not deflate further) ≈ **2.4 MB** | QOA is lossy but near-transparent on synthetic clicks and stings; decoding costs next to nothing. Same files on desktop. **Risk:** the web plays *samples*; if a QOA WAV does not sound there (§17.2 item 8), fall back to IMA-ADPCM (`mode=1`, 4:1), and if that fails too keep PCM and record it | **Taken** (amends audio.md §10.3) |
| Loops at Vorbis q0.3 instead of q0.5 | ~1.5 MB | audible on the drones' air and the music's chords, the one place the sound design lives; a new `synth.py` run and a listening pass | **Not taken** — revisit only if §4.2's target is missed |
| Loops at 22.05 kHz | ~1.5 MB | dulls the top end of the ambience | **Not taken** |
| Custom engine template | ~5 MB | §3.4 | **Not taken** |
| Loading on demand (a second `.pck` for pictures or music, fetched after the title) | moves ~5–9 MB after the first screen | a patch-pack loader, a "still loading" state for every picture and stem, offline failure cases, two files to version | **Not taken** — the whole download is small enough to take in one |
| Brotli/gzip pre-compressed files | — | the host decides the encoding (§16.4); a `.br` file served without its header breaks the load | **Not taken** |
| Font subsetting further / fewer weights | < 0.2 MB | a weight or glyph range lost | **Not taken** |
| Remove the `build/` leak | 0.02 MB | none | **Taken** (§3.3) |

### 4.5 Projection

20.39 (baseline) − 2.4 (QOA) + ~5 (illustrations, lossy) − 0.02 ≈ **23 MB download, ~50 MB
extracted** at the itch release. D7.I may write "about 25 MB" on the page.

---

## 5. The page: `web/shell.html`

Starts from 4.7.2's own shell (`godot.html` in the template zip — its `$GODOT_*` placeholders,
`Engine` start and progress hooks) and replaces its look and its messages. **One file**: inline
CSS and JS, no web fonts, no images beyond what the export writes, **no request to any host but
its own folder**. Colours are the tokens' hex values (`INK` `#07090C` background, `ACCENT`
`#6FE3FF` bar and focus, `TEXT_1`-grey text); type is the system monospace stack
(`ui-monospace, "Cascadia Mono", Menlo, Consolas, monospace`).

### 5.1 Language

`localStorage["doomsday_locale"]` when it holds `en` or `de` (the game writes it on every locale
change, §7.3), else `de` when `navigator.language` starts with `de`, else `en`. The shell's strings
are a small table `{en: {...}, de: {...}}` whose texts are **exactly** the `UI_WEB_*` rows of
`strings.csv` (§18) — the CSV is the source; `test_web_shell.gd` fails when they drift (§17.1).
Placeholders are the CSV's named ones (`{percent}`, `{mb}`, `{features}`), replaced in JS.

### 5.2 Loading

1. The page shows at once on `INK`: the word **Doomsday** (the page's only heading), under it a
   2-px bar in `ACCENT` on `BG_2`, 320 px wide (max 80 % of the width), and one status line.
2. **Progress:** the loader's `onProgress(current, total)` → `UI_WEB_LOADING` (`{percent}` whole
   numbers) when `total > 0`, else `UI_WEB_LOADING_SIZE` (`{mb}` downloaded, one decimal) and an
   indeterminate bar: a 25 % segment sliding once a second, no flashing; with
   `prefers-reduced-motion: reduce` it stands still at full width and pulses nothing (the page
   cannot read the game's own *Reduced motion* before the engine runs).
3. When the files are in: `UI_WEB_STARTING` until the engine's first frame; then the shell's
   layer fades out in 200 ms and is removed. Godot's own boot splash is `INK`, no image
   (`release.md` §5), so there is no visible seam. The game's boot sequence follows (silent, §6.1).
4. No *Click to start* button of our own: itch's *Run game* is the click that starts the page
   (§16.1) and a second click would only be a toll.

### 5.3 The phone gate

Before anything is downloaded: if `matchMedia("(any-pointer: fine)").matches` is false (no mouse
or trackpad at all — phones and plain tablets), show `UI_WEB_PHONE_TITLE`, `UI_WEB_PHONE_BODY`
(`{mb}` = the download's size from the loader config's file sizes, rounded) and one button
`UI_WEB_PHONE_START`. Pressing it starts the normal load; the game then runs with the engine's
touch-to-mouse emulation, unsupported. A tablet with a keyboard and trackpad passes the gate.

### 5.4 Errors

| When | What the page shows |
| --- | --- |
| `Engine.getMissingFeatures` is not empty | `UI_WEB_ERR_TITLE` + `UI_WEB_ERR_FEATURES` (`{features}` = the loader's list, as it gives it, English) — nothing downloaded |
| a file fails to download or the start promise rejects | `UI_WEB_ERR_TITLE` + `UI_WEB_ERR_LOAD` + button `UI_WEB_RELOAD` |
| **a crash**: the engine's `onExit` with a non-zero status, an abort (`RuntimeError`, out of memory) or an uncaught error on `window` after the start | an overlay over the canvas: `UI_WEB_CRASH_TITLE`, `UI_WEB_CRASH_BODY`, a `<details>` with summary `UI_WEB_DETAILS` holding the last 20 lines the engine printed to `onPrintError` plus the error text (selectable, monospace), and `UI_WEB_RELOAD` |

`onExit` with status 0 (only `--smoke` quits, §5.5) shows nothing. The *Reload* button calls
`location.reload()` — inside itch's iframe that reloads the game, not the page. GDScript errors do
not crash a release build; they only reach the console (§14).

### 5.5 Arguments from the address — a whitelist

The shell passes command-line user arguments from the query string for exactly one key:
**`?smoke`** → `args: ["--", "--smoke"]` (release.md §8, isolated files, a bot run, then
`quit()`). Nothing else is read — the debug switches stay debug-only, and a release build given
`?spectate=…` ignores it. The smoke prints `smoke: ok|fail …` to the console, which is how the
browser smoke reads it (§17.2, §16.3).

---

## 6. Boot and sound on the web

### 6.1 Boot

Unchanged from `screens-full.md` §2 and audio.md §5.8: the boot plays **silently** (no input has
unlocked the sound yet), any key or click skips it, and that same first input unlocks the audio;
the title is the first thing heard. The first click is usually the one that also moves keyboard
focus into the iframe (§9.1), so no key press is lost to the itch page.

### 6.2 Cue files after the unlock

S6.11 loads the cue files on the loader's threads at start, **not on the web**, so on the web a
cue's first play loads its file on the spot (measured up to 12 ms in a tick on desktop). On the
web, from the unlock on, `Audio` loads the cue files it has not loaded yet **two per frame**
(`WEB_CUE_LOADS_PER_FRAME = 2`, a presentation constant in `audio.gd`), in cue-sheet order; a cue
requested before its turn loads at once as today. ~56 files → ~28 frames, all before a run can
start. Loops keep loading when their screen needs them (as today).

### 6.3 The page hidden

`WebBridge` listens to `document.visibilitychange` (through `JavaScriptBridge.create_callback`,
the callback kept in a member so it is not collected) and emits `page_hidden` / `page_shown`.

- **`Audio`:** hidden → mute bus 0; shown → restore it from its volume (audio.md §5.7's desktop
  focus rule, for the web; there is no *Background audio* row on the web). Needed because the
  browser keeps playing looping Web Audio samples in a background tab while the engine's frames
  stop.
- **The session:** hidden, with the player's own run live (not spectating, not a bot, origin
  chosen, outcome none) → `_autosave()` at once, then open the pause menu exactly as the
  menu key does, unless a modal is already open. Shown → nothing (the player resumes).
  Reason: the browser stops the frames of a hidden tab, and at the return the clock would take up
  to `Game.MAX_TICKS_PER_FRAME` days in one frame — the player should come back to a paused game,
  not a jump.
- A spectated run just continues; the title and setup do nothing.

---

## 7. Saves, profile and settings in the browser

### 7.1 Where the files are — and the shared `/userfs`

Godot's web `user://` is `/userfs`, mirrored into IndexedDB database `/userfs` **of the page's
origin** — measured in this export (Chrome, 2026-09-26). itch serves every HTML game from one
origin, so **all Godot games on itch share one `user://`** (godot-proposals #2207): another game's
`user://settings.json` would be ours, and `custom_user_dir_name` does not apply on the web.

**Rule:** on the web every file the game writes lives under **`user://doomsday/`**; elsewhere
under `user://` as today (desktop already has its own folder, `release.md` §5).

```gdscript
class_name UserPaths
extends RefCounted
## release.md §5 and web.md §7.1: where the game's files live.
const WEB_ROOT: String = "user://doomsday/"
const DESKTOP_ROOT: String = "user://"
static func root() -> String                         # root_for(OS.has_feature("web"))
static func root_for(is_web: bool) -> String
static func at(relative: String) -> String           # root().path_join(relative)
```

`Settings.PATH`, `ProfileManager.PATH`, `SaveManager.SAVE_DIR`, `BenchLibrary.USER_DIR`,
`GlobalBoardClient.CACHE_DIR` and the smoke's four paths are built from `UserPaths.at(…)` with
their current relative parts (`settings.json`, `profile.json`, `saves/`, `benchmark/runs/`,
`benchmark/online/`, `smoke/…`). Tests keep their own `user://test_*` paths (`pre_run.gd`).
Debug-only shot paths stay as they are. `UserDataMigration` is already off on the web. No
migration: nothing was ever released on the web.

### 7.2 What persists, and what loses it

| Situation | Progress (profile, settings, saves) |
| --- | --- |
| Reload, close and reopen the tab, restart the browser | **kept** |
| A new version uploaded to itch | **kept** — the upload's path changes, the origin does not |
| Played on itch's page vs. the game's direct frame address | **two separate stores** (browsers partition an iframe's storage by the top-level site) |
| The player clears the browser's site data / cookies for itch | **lost** |
| A private / incognito window | kept for that window only, **lost** when it closes |
| Safari: 7 days without visiting itch | may be **deleted** by Safari's tracking prevention |
| Storage pressure (disk nearly full) | the browser *may* evict unless persistent storage was granted (§7.3) |
| Another Godot game on itch | untouched, since §7.1 |

**Writes reach IndexedDB asynchronously** a moment after the file is closed (the engine syncs
`/userfs` on the next frames). A tab closed in that fraction of a second loses that one write;
nothing else is at risk. The autosave cadence (every player command, every seventh day, and now
the page-hidden autosave of §6.3) keeps the loss to the last moments.

### 7.3 `WebBridge`

```gdscript
class_name WebBridge
extends Node
## web.md §6.3, §7.3, §7.4: every JavaScriptBridge call of the game.
signal page_hidden
signal page_shown
signal file_picked(text: String, reason: String)     # reason "" on success
const REASON_CANCELLED: String = "cancelled"
const REASON_TOO_LARGE: String = "too_large"
const MAX_IMPORT_BYTES: int = 1048576                 # 1 MiB; a profile is a few KB
func request_persistent_storage() -> void             # once per launch, after the first successful write
func remember_locale(locale: String) -> void          # localStorage["doomsday_locale"] (§5.1)
func download_text(file_name: String, text: String) -> bool   # JavaScriptBridge.download_buffer
func pick_text_file() -> void                         # emits file_picked later
```

- `request_persistent_storage()` calls `navigator.storage.persist()` (if present) and ignores the
  answer — it only lowers the chance of eviction; there is no UI for it.
- `pick_text_file()` creates a hidden `<input type="file" accept=".json,application/json">`,
  calls its `click()` in the same frame as the button press (browsers allow a file picker for a
  few seconds after a user gesture), reads the chosen file with `FileReader.readAsText` and calls
  back; a file over `MAX_IMPORT_BYTES` → `REASON_TOO_LARGE` without reading it; the dialog closed
  without a file (`cancel` event) → `REASON_CANCELLED`.
- `Settings.set_locale` calls `PlatformService.web.remember_locale(locale)` when `web` is not null.

### 7.4 Progress to a file and back (in scope)

**Why in scope:** in a browser the player's whole history — runs, unlocks, Codex, achievements —
hangs on site data that a cleanup tool, a private window or Safari may delete, and there is no
folder to back up. One button to save it and one to bring it back is the whole remedy.

**Where:** the **title's settings only** (like *Reset progress* and *Open data folder*), **web
only** (`static func has_progress_rows() -> bool` = `OS.has_feature("web")`; desktop has the
folder). Order: … *Controls*, *Reset progress*, **Save progress as a file**, **Load progress from
a file**, their note (`LabelCaption`), *Online leaderboard*. Both are `ConsoleButton`s with the
row labels as their text (they are actions, not toggles); the note is `UI_SETTINGS_PROGRESS_NOTE`.
A status caption under the note shows the last result (empty until one).

**Save:** `ProfileManager.export_text()` = `JSON.stringify(to_dict(), "\t")` →
`download_text("doomsday-progress-<YYYY-MM-DD>.json", text)` (local date). `false` →
`UI_SETTINGS_PROGRESS_EXPORT_FAILED` in the status caption.

**Load:** `pick_text_file()` → on `file_picked`:
1. `REASON_CANCELLED` → nothing. `REASON_TOO_LARGE` → `UI_SETTINGS_PROGRESS_NOT_A_PROFILE`.
2. `JSON.parse_string(text)` not a `Dictionary`, or its `version` not a whole number ≥ 1, or no
   `runs_completed` key → `UI_SETTINGS_PROGRESS_NOT_A_PROFILE`. `version` > `ProfileManager.VERSION`
   → `UI_SETTINGS_PROGRESS_NEWER`.
3. Else the confirm dialog (the menu's existing `_confirm.ask`) with
   `UI_SETTINGS_PROGRESS_IMPORT_CONFIRM`; *no* → nothing.
4. *Yes* → `ProfileManager.import_dict(raw)`: the achievements become the **union** of the
   current and the file's (release.md §0 item 2 — earned achievements survive *Reset progress*, so
   they survive an import too); everything else is read through the existing tolerant `_apply`
   (unknown keys ignored, bad values dropped — **never a resource, never `load()`**); `write()`;
   `earn_at_start()`. Returns `""` or a reason. Success → `UI_SETTINGS_PROGRESS_IMPORTED`; the
   title refreshes what it shows from the profile (the *Continue*/*Benchmark* visibility, the
   unlocks the setup reads next).

Saves (runs in progress) and settings are **not** in the file: a save belongs to the browser it
was played in, and settings are quick to set again. The file is the same JSON as the desktop's
`profile.json`, so it also moves progress from the browser to a desktop download (by copying it
over `%APPDATA%\Doomsday\profile.json` — not a feature, not documented on the page).

---

## 8. The frame: size, resize, fullscreen

### 8.1 The embed size

**Recommendation for itch: 1280 × 720** (the embed's CSS size). Reasons: it fits the common
laptop viewport (1366 × 768 and up) beside itch's page chrome; it is above the 1100-px compact
breakpoint on a 100 % screen, so the full layout shows; and its scale (⅔ of the 1920 base) is the
Steam Deck's, which `release.md` §11.1 already accepts. A smaller embed (960 × 540) would drop to
0.5 scale — text too small — and anything under 1100 px wide at 100 % would switch to the phone
layout on a desktop. The fullscreen button (§8.3) is the comfortable way to play; the page says
so (D7.I).

### 8.2 Resize and pixel density

`canvas_resize_policy = 2`: the canvas follows the iframe and, in fullscreen, the screen. The
engine sees the canvas in **device pixels** (`allow_hidpi`), so `LogicalScale` and every
`COMPACT_WIDTH` test see device pixels too: a 1280 × 720 embed on a 150 % laptop is a 1920 × 1080
window (scale 1.0), on a 200 % screen 2560 × 1440. **The compact rule is unchanged on the web**
(the phone case it would get wrong at a high density is out, §2). Every resize goes through the
existing `size_changed` → `LogicalScale.apply` path; nothing new.

### 8.3 Fullscreen

itch's own fullscreen button (§16.1) puts the iframe in fullscreen; the game needs no button of
its own and gets none (no fullscreen setting exists on desktop either). `Escape` in fullscreen is
the browser's — it leaves fullscreen and may not reach the game; the pause menu is still on the
HUD's button and the key after that. The browser's `F11` fullscreens the whole itch page — also
fine.

### 8.4 Legibility

At ⅔ scale the smallest captions are small. It is the Deck's scale and G6 (2/2) judges it there;
**G7.I judges it in the embed.** If it is too small, the lever is a design question for then (for
example a higher default *Text size* on the web) — not something S7.3 changes.

---

## 9. Input

### 9.1 Focus inside an iframe

A cross-origin iframe does not get keyboard focus by itself; until the player clicks into the
game, keys go to itch's page (Space and the arrows scroll it). The first click focuses the canvas
(the engine's canvas takes focus on pointer down) — and is also the first input of §6.1. The
shell adds nothing. S7.3 checks it in the iframe host (§17.2 item 3).

### 9.2 What the engine takes and what the browser keeps

With the canvas focused, the engine calls `preventDefault` on key events, the wheel and the
context menu, so: **F1** (help) does not open the browser's help, **Tab**/**Shift+Tab** walk the
game's focus and do not leave the iframe, **Space** and the arrows do not scroll the page, the
**wheel** zooms the map and does not scroll the page, **right-click** shows no browser menu,
**F5** does not reload. The browser keeps what no page can take: `Ctrl+W`, `Ctrl+T`, `Ctrl+Tab`,
`Alt+F4`, `F11`, `Escape` in fullscreen. No default binding needs any of those; the *Controls*
modal's reserved list is unchanged. **Pointer lock** is not used (the map pans by dragging).
**Gamepad** works through the browser's Gamepad API in Chrome, Edge and Firefox — best effort,
not a criterion. S7.3 verifies each claim of this paragraph (§17.2 item 4) and records any that
does not hold under *Known issues*.

### 9.3 Key names on the web (bug found in D7.2)

`KeyNames` asks `DisplayServer.keyboard_get_label_from_physical` for the layout's label; the web
display server does not implement it and prints `ERROR: Not supported by this display server`
once per key shown (measured: eleven errors when the title opened). On the web `KeyNames` skips
the lookup and shows the physical key's US name (`OS.get_keycode_string`). The seam:
`KeyNames` gains a `static var use_layout: bool` (default `not OS.has_feature("web") and`
not headless), which the test sets. Cost: a German keyboard sees *Z*/*Y* and the punctuation keys
by their US names on the web — recorded under *Known issues* (for D7.1, which revisits input).

---

## 10. What the web build turns off, and what it keeps

| | On the web | State |
| --- | --- | --- |
| *Quit* (title, pause menu's quit to desktop) | hidden | done (S5.7/S6.9) |
| *Open data folder* | hidden; the progress rows take its place (§7.4) | hidden since S6.9 |
| *Background audio* | hidden; page-hidden mutes instead (§6.3) | hidden since S6.5 |
| File log | off (§3.2) | S7.3 |
| Debug keys and dev switches | absent — only a **release** export is ever uploaded (release.md §7) | done |
| The benchmark tool, verifier, perf tools | never shipped (`tools/*` excluded) | done |
| `UserDataMigration` | off | done |
| *Online leaderboard* list, *Watch* | **kept** (§11) | — |
| Achievements | **kept** — in the profile, shown in *Statistics* and on the results; no platform mirror (null backend) | — |
| *Screen effects* default | *Subtle* on the web (polish-visuals.md §5.1) | done |
| Screen reader, spoken alerts | whatever the engine gives (accessibility.md §1); not a criterion | — |
| `--smoke` | through `?smoke` only (§5.5) | S7.3 |

---

## 11. The online leaderboard from the browser

`benchmark.md` §16.6 holds: the fetch happens only when the player opens the *Benchmark* list (at
most once per 300 s) or presses *Watch*; plain GETs, no identifier; the setting turns it off. In
the browser, `HTTPRequest` goes through `fetch`; `raw.githubusercontent.com` answers with
`Access-Control-Allow-Origin: *`, so the request works from itch's origin. **It works only
because the build is single-threaded without cross-origin isolation** (§3.1): with itch's
*SharedArrayBuffer* option the page would be `COEP: require-corp`, and every cross-origin
response would need matching headers. What GitHub sees is what any download shows it — the
player's IP address and the time; D7.I's privacy sentence says so. S7.3 checks the list fetches
and a run downloads and plays in the iframe host (§17.2 item 7).

---

## 12. The version shown

The title's caption on a web release build reads `UI_TITLE_VERSION_WEB` — *Build {version} ·
browser* — so a player's report says which build it is; a debug web export keeps
`UI_TITLE_VERSION_DEBUG`. The start line of the log already names the platform (*Web*). The
first itch release is `1.0.0` (release.md §4; G7.I tags it).

---

## 13. Performance in the browser

### 13.1 The web budget (the low-end target of release.md §11.1, in Chrome)

| Measure | Budget | Judged on |
| --- | --- | --- |
| Frame time, late game at 4× (the bench's script) | **p95 ≤ 16.7 ms**, p99 ≤ 33 ms, no frame > 100 ms outside a screen change | `web_igpu` |
| A frame that runs a tick | p99 ≤ 33 ms | `web_cpu` |
| Simulation tick, days 300–450 | mean ≤ 4 ms, max ≤ 12 ms | `web_cpu` |
| `TIME_PROCESS` p95 | ≤ 16.7 ms | `web_cpu` |
| Draw calls per frame, max | ≤ 1 000 | either |
| Engine memory peak (`OS.get_static_memory_peak_usage()`) | ≤ 768 MB | either |
| *Continue* on a late save → session drawn | ≤ 3 s | `web_cpu` |
| *Run game* → title drawn, **cold** cache, network throttled to 50 Mbit/s down, 20 ms latency | ≤ 15 s | `web_cpu` without CPU throttling |
| The same, **warm** cache | ≤ 5 s | the same |

*Screen effects* at the web default (*Subtle*), reduced motion off, text 100 %, sound on but
muted by the bench. The p99 and the long-frame row are looser than the desktop's because a
browser adds its own compositing and garbage collection pauses.

### 13.2 How S7.3 measures it on this PC

- **A local preset `Perf web (local)`** (preset 4, not built by CI): the Web preset's options +
  `custom_features="perf"`, export path `build/perf-web/index.html`, the `Perf (local)` preset's
  exclude filter (it keeps `tools/perf/`). `application/run/main_scene.perf` starts the bench as
  on desktop.
- **The bench on the web** (`perf_bench.gd`, a web branch): the same script and summary line;
  **no CSV** (it would sit in IndexedDB); the working set is replaced by
  `OS.get_static_memory_peak_usage()`; the label is `web` (the runner names the run). It quits at
  the end; the summary line reaches the console.
- **The runner** `tools/web/web_perf.py` (uv project `tools/web/`, Playwright for Python, version
  pinned; its browsers download into Playwright's own cache, outside the repository):
  1. `serve.py` serves `build/perf-web/` on `127.0.0.1` (Python's server with the `.wasm` MIME
     type).
  2. **`web_igpu`**: Playwright's bundled Chromium, viewport 1280 × 720 at device scale 1.5
     (a 1920 × 1080 canvas — the realistic mid-laptop case), with this PC's **integrated Radeon**
     forced by `HKCU:\Software\Microsoft\DirectX\UserGpuPreferences` value `<Playwright's
     chrome.exe path>` = `GpuPreference=1;` — **the user's own Chrome is never touched**; the
     value is removed afterwards (in a `finally`). The bench prints the adapter (WebGL's renderer
     string, e.g. *ANGLE (AMD, … Radeon …)*); a run on another adapter does not count.
  3. **`web_cpu`**: the same Chromium on the default (RTX 5090) GPU, 1280 × 720 at scale 1, with
     the DevTools protocol's `Emulation.setCPUThrottlingRate` **2.5** (release.md §11.3's single-
     thread factor 7900X3D : i5-8250U) — judged against §13.1 directly, no division.
  4. **Load time**: the release `Web` export (not the perf one), fresh browser context, DevTools
     `Network.emulateNetworkConditions` (50 Mbit/s down, 10 Mbit/s up, 20 ms), the clock from
     navigation to the console's `first screen` line (release.md §11.3's print); cold with the
     cache disabled, warm on a second navigation.
  5. Three runs each; the run with the median p95 frame counts.
- **Recorded** under *Performance notes* as S6.11 did: date, build, label, adapter, every row
  with its budget, pass/fail, what was fixed. **When a row fails:** release.md §11.4's order;
  no new setting or quality preset; a row still failing becomes a *Design question* with its
  numbers and does not block S7.3's *done when* unless the game is unplayable (p95 frame > 33 ms
  on `web_igpu`).

### 13.3 What D7.2 measured (no budget judged)

The export booted in headless Chrome on SwiftShader (software WebGL 2, the only GPU a headless
browser here gets): `first screen` at **3.6 s** after the engine started on a cold cache,
0.7–0.8 s warm; the title drew correctly in German (the system locale); IndexedDB database
`/userfs`; 1258 × 622 canvas at device scale 1. The same run found §9.3's errors.

---

## 14. Errors and logs

- No file log on the web (§3.2). Every engine line goes to the browser console (`print` →
  `console.log`, errors → `console.error`); a player can be asked for a screenshot of the crash
  screen's details (§5.4), which carries the last 20 error lines.
- A corrupt profile, settings file or save reads as empty or reports a reason, as on desktop.
- **No analytics, no telemetry, no crash upload** — the shell loads nothing from anywhere else
  and sends nothing. (itch's own page has itch's own statistics; that is itch's, and D7.I's
  privacy sentence can say so.)

---

## 15. Windows and Linux downloads

The release workflow already builds, smoke-tests and zips both (release.md §9.2), unsigned.
**Recommendation (pending the user, *Waiting on the user*):** offer them on the same itch page as
downloads — they cost nothing, run better on weak GPUs than the browser, and keep a player's
progress in a real folder. Cost: Windows shows SmartScreen's *unknown publisher* prompt for an
unsigned download (release.md §6.3). If the user says no, S7.I pushes the web channel only.

---

## 16. What S7.I needs from this spec

### 16.1 The itch project's settings (the user sets them once; S7.I writes them into its step notes)

| itch field | Value |
| --- | --- |
| Kind of project | HTML |
| The web upload | `Doomsday-<version>-web.zip` (index.html at its root, release.md §9.2), ticked *This file will be played in the browser* |
| Embed options | **Embed in page**; viewport **1280 × 720**; *Mobile friendly* **off**; *Automatically start on page load* **off** (a visitor who does not play downloads nothing); *Fullscreen button* **on**; *Enable scrollbars* **off**; **SharedArrayBuffer support off** |
| Downloads (if the user wants them, §15) | the Windows and Linux zips as separate uploads |

### 16.2 Channels (butler)

`butler push <zip> <user>/<game>:web` (and `:windows`, `:linux` if §15 is yes), with
`--userversion <version>`. The first push of the web channel needs the user to tick *played in
the browser* once in the dashboard. No push from an unattended run; without `BUTLER_API_KEY` the
job skips with one clear line (IMPLEMENTATION S7.I).

### 16.3 CI

- The size check of §4.3 after the web zip is made (fails the job on a hard limit).
- **A web smoke** job (needs `export`): serve the web build, run `tools/web/web_check.py --smoke`
  in Playwright's headless Chromium (software WebGL is fine), which opens `index.html?smoke`,
  waits (≤ 10 min) for the console's `smoke:` line and compares `outcome`, `day` and `hash` with
  the Linux smoke's `result.json`. The hash is expected to match (wasm floats are IEEE like the
  desktop's); a mismatch **fails the job** — the spectator's *Watch* on the web depends on it
  (benchmark.md §12, §16.8).

### 16.4 Compression on itch — measured by S7.I on the restricted page

Whether itch's servers send the `.wasm` and `.pck` compressed is not documented (the docs page
refused an automated read on 2026-09-26). S7.I (or G7.I, with the user's key) opens the
restricted page with DevTools and records the *transferred* size of each file. Compressed →
§4.5's ~23 MB holds. **Uncompressed (~50 MB)** → recorded as a *Design question*: the answer
then is §3.4's custom template and/or the loop reductions of §4.4, not something S7.I decides.

---

## 17. Tests and acceptance (S7.3)

### 17.1 GUT (headless, desktop — the web branches through their seams)

- `test_user_paths.gd`: `root_for(true)` = `user://doomsday/`, `root_for(false)` = `user://`;
  `at("saves/")` joins; every production path constant listed in §7.1 is built from `UserPaths`
  (read each class's value and check it starts with `UserPaths.root()`).
- `test_export_presets.gd` (extend): the Web preset's options of §3.1 (thread support off,
  extensions off, PWA off, the custom shell path, resize policy 2); `build/*` and `web/*` in every
  preset's exclude filter; the `Perf web (local)` preset exists with `custom_features="perf"`;
  `project.godot` has `debug/file_logging/enable_file_logging.web=false`.
- `test_web_shell.gd` (new): `web/shell.html` exists; contains `$GODOT_URL` and `$GODOT_CONFIG`;
  **every `UI_WEB_*` row's English and German text appears verbatim** in it (JSON-escaped);
  contains no `http://` or `https://` (no external request — the shell is fully relative); reads
  exactly one query key, `smoke`.
- `test_profile_import.gd` (new): a valid file replaces the counts and keeps the union of
  achievements; the result is written; not JSON / not a dictionary / no `runs_completed` →
  the not-a-profile reason; `version` above `VERSION` → the newer reason; `export_text()` parses
  back to `to_dict()`.
- `test_pause_menu.gd` (extend): the two progress rows and the note exist in the title's settings
  when `has_progress_rows()` is forced true (a seam like the data folder's), are absent in a
  run's pause menu, and are absent on desktop.
- `test_key_names.gd` (extend): with `use_layout = false` the name is the US keycode string and
  no `DisplayServer` layout call is made.
- `test_audio_web.gd` (new, through the test seams of S6.5): after `set_unlocked(true)` on a
  forced-web `Audio`, the unloaded cues load `WEB_CUE_LOADS_PER_FRAME` per `step`; the page-hidden
  handler mutes bus 0 and the shown handler restores its volume.
- `test_session_page_hidden.gd` (new): a live player run + `page_hidden` → an autosave was written
  and the pause menu is open; a spectated run → neither.
- `test_audio_files.gd` (change): `test_cues_are_uncompressed_and_do_not_loop` becomes
  *are_qoa_and_do_not_loop* (`compress/mode=2`), or mode 1/0 if S7.3 had to fall back (§4.4 —
  then the test says which and why).
- `test_illustrations.gd` (change): the expected import is `compress/mode=1`,
  `compress/lossy_quality=0.9` (or 0.95 per picture, a list in the test), mipmaps on; the fixture
  `.import` follows.
- `test_title_*` (extend): the web caption key on a forced-web, release title.

### 17.2 In the browser (`tools/web/web_check.py`, Playwright, this PC)

Run against the release `Web` export served on `127.0.0.1:8765`, inside
`tools/web/iframe_host.html` served from `localhost:8766` (a **different origin**, like itch; the
host page is 1280 × 720 of iframe plus 600 px of text above and below so the page can scroll).
Chrome (`channel="chrome"`), Edge (`channel="msedge"`) and Playwright's Firefox; a fresh profile
each; `APPDATA` is irrelevant here (browser storage), the player's own browsers are not used —
Playwright launches separate instances with temporary profiles.

1. **Loads:** the shell's progress reaches 100 %, the `first screen` line arrives, no
   `console.error` from the game (the §9.3 errors gone). Screenshot of the title.
2. **Phone gate:** a context with `has_touch=True`, `is_mobile=True` shows the notice and
   downloads nothing until *Start anyway*.
3. **Focus:** before any click, a Space press scrolls the host page; after one click into the
   game, Space pauses the game and the host page does not scroll.
4. **Keys and mouse** (§9.2): F1 opens the game's help, not the browser's; Tab walks the HUD;
   the wheel zooms the map and the host page does not scroll; right-click shows no menu.
5. **A run:** New run → setup → Begin → an origin → a purchase; speed 4× for 60 s; screenshot.
6. **Persistence:** reload → *Continue* appears and loads the same day; the settings changed
   before the reload (language, text size) are kept; the files are under `/userfs/doomsday/`
   (read through the page's IndexedDB), nothing at `/userfs/` root.
7. **Online list:** open *Benchmark* → the status reaches *as of {date}* from the network; *Watch*
   a listed run → the spectator plays; with the setting off, no request is made (Playwright's
   request log).
8. **Sound:** in a **debug** web export, `Audio.is_unlocked()` is false before the first click
   and true after it (read through `JavaScriptBridge` or a debug `print`); **once by ear** with the
   machine's sound on: the title's loops and a few QOA cues play (else §4.4's fallback chain).
9. **The stems** stay in step for 3 minutes of a run at 4× (audio.md §3.4) — by ear, once.
10. **Page hidden:** switching the Playwright page to another tab and back → the pause menu is
    open and an autosave exists.
11. **Progress file:** *Save progress as a file* downloads a JSON that parses as the profile;
    *Load progress from a file* with a doctored copy (one more run) → confirm → the Statistics
    show it; a non-profile JSON → the not-a-profile line.
12. **Crash screen:** a debug web export with a debug-only trigger (`Game.debug_crash()` →
    `OS.crash("test")`, debug builds only) shows the crash overlay with its details and *Reload*.
13. **Smoke:** `index.html?smoke` → `smoke: ok`, outcome, day and hash equal `sim_run`'s seed-1
    greedy summary (§16.3).
14. **Size:** the export's zip and extracted sizes against §4.2, recorded.
15. **Performance:** §13.2's runs, recorded.

### 17.3 Acceptance

- S7.3 is done when §17.1 is green in `tools/test.sh`, §17.2 items 1–7, 10, 11, 13 and 14 pass in
  Chrome, Edge and Firefox (item 2 in Chrome), items 8, 9, 12 and 15 were done once and recorded,
  and the web zip is inside the hard limits of §4.2.
- Anything that does not hold in one browser is recorded under *Known issues* with the browser
  and version; a failure in Chrome of items 1, 5 or 6 blocks.
- **G7.I (the user):** the restricted itch page in two browsers, German and English: loads, the
  first click unlocks the sound, a run plays, the progress survives a reload, the fullscreen
  button works, the embed's text is legible (§8.4), the transferred size (§16.4).

---

## 18. Strings (in `data/loc/strings.csv` since D7.2, en/de)

**The shell's** (copied verbatim into `web/shell.html`, §5.1): `UI_WEB_LOADING` (`{percent}`) ·
`UI_WEB_LOADING_SIZE` (`{mb}`) · `UI_WEB_STARTING` · `UI_WEB_PHONE_TITLE` · `UI_WEB_PHONE_BODY`
(`{mb}`) · `UI_WEB_PHONE_START` · `UI_WEB_ERR_TITLE` · `UI_WEB_ERR_FEATURES` (`{features}`) ·
`UI_WEB_ERR_LOAD` · `UI_WEB_CRASH_TITLE` · `UI_WEB_CRASH_BODY` · `UI_WEB_DETAILS` ·
`UI_WEB_RELOAD`.

**The game's:** `UI_TITLE_VERSION_WEB` (`{version}`) · `UI_SETTINGS_PROGRESS_EXPORT` ·
`UI_SETTINGS_PROGRESS_IMPORT` · `UI_SETTINGS_PROGRESS_NOTE` · `UI_SETTINGS_PROGRESS_IMPORT_CONFIRM`
· `UI_SETTINGS_PROGRESS_IMPORTED` · `UI_SETTINGS_PROGRESS_NOT_A_PROFILE` ·
`UI_SETTINGS_PROGRESS_NEWER` · `UI_SETTINGS_PROGRESS_EXPORT_FAILED`.

---

## 19. Amendments to other documents (made in D7.2)

- **audio.md** §10.2/§10.3: cue WAVs import with `compress/mode=2` (QOA); §10.4 the size line.
- **illustrations.md** §4: the pictures import lossy (WebP 0.9, mipmaps) for the web's size.
- **release.md** §6.1/§6.2: the Web preset's shell and the `build/*`, `web/*` excludes point here.
- **PLAN** §4.4: the web line — the main version, not a demo (the user's 2026-09-25 decision).
  CLAUDE.md's first paragraph ("Windows/Steam first") is left to the user.

---

## 20. Decisions (for PROGRESS) and questions for the user

Decisions, pending user confirmation: §0 items 1–10. Questions (*Waiting on the user*):

1. **Downloads beside the browser build** (§15): Windows and Linux zips on the itch page — the
   recommendation is yes.
2. The itch account, the price model and `BUTLER_API_KEY` — already asked (2026-09-25).
3. **Safari:** if you (or a friend) have a Mac, one look at the restricted page at G7.I would move
   Safari from "best effort" to "tested".
