# Release engineering — platform service, achievements, exports, performance budget

D6.8 (2026-09-25, overnight). Builds from it: **S6.9** (§1–§3), **S6.10** (§4–§10), **S6.11**
(§11). §12 fixes what **S6.14** (GodotSteam, [needs user]) adds on top. Data written here:
`data/achievements.json`; strings in `data/loc/strings.csv` (§14).

---

## 0. What this spec decides

1. **`PlatformService`** is an autoload with one backend behind a typed interface; M6 builds the
   **null backend** only. A backend is chosen at start from a feature tag, never by a compile-time
   reference, so every build compiles without GodotSteam.
2. **Achievements live in the profile.** The profile is the only source of truth; a platform
   backend is a mirror that is told about every earned achievement (again) at each start. Earned
   achievements survive *Reset progress*.
3. **34 achievements** (§3), data-driven from `data/achievements.json` with a closed condition
   grammar (§3.2). Two are hidden (the two secret endings). Shown in *Statistics* and as chips on
   the results screen.
4. **No rich presence, no cloud-save API, no platform language** in M6 (§1.4). Steam Auto-Cloud
   syncs the profile and saves by path, with no code (§12).
5. **Three export presets** — Windows, Linux, Web — plus a local-only `perf` preset (§6, §11);
   Android and iOS are named for M7. One embedded-`.pck` executable per desktop platform.
6. **Version:** `application/config/version` is always numeric `X.Y.Z`, the next release's number;
   the tag `vX.Y.Z` must equal it. Pre-1.0 the minor is the milestone: **M6 ships `0.6.0`**; the
   first public Steam release is `1.0.0` (§4).
7. **Debug keys and dev switches run only when `OS.is_debug_build()`** — the editor and debug
   exports. Release exports have none of them (§7).
8. **A `--smoke` mode ships in every build**: a bot plays a full run in the real session at
   high speed with the player's files untouched, and the process exits 0/1/2 (§8). CI smoke-tests
   the exported Linux and Windows builds with it.
9. **Release CI:** a `v*` tag (or a manual dispatch) exports all three, smoke-tests them and — for a
   tag — attaches the zips to a **draft** GitHub release. Publishing is the user's (§9).
10. **Logs:** Godot's file log, five files, nothing ever leaves the machine; a desktop-only
    *Open data folder* row in the title's settings (§10).
11. **Low-end target:** Intel Core i5-8250U · Intel UHD Graphics 620 · 8 GB · 1920 × 1080, and the
    Steam Deck at 1280 × 800. The budget and how it is measured on this PC (Ryzen 9 7900X3D, RTX
    5090 **and** its integrated Radeon, which stands in for the low-end GPU) are §11.

**Not in scope:** the Steam backend itself (S6.14), store pages and art (D7.3/D7.4), Android/iOS
presets (S7.2/S7.4), the web demo's content cut (D7.2), code signing (no certificate; §6.3),
telemetry of any kind (none, ever — §10).

---

## 1. `PlatformService`

### 1.1 Files

| File | What |
| --- | --- |
| `game/platform/platform_backend.gd` | `class_name PlatformBackend extends RefCounted` — the interface, every method a no-op default |
| `game/platform/null_platform_backend.gd` | `class_name NullPlatformBackend extends PlatformBackend` — `id()` = `"null"`, `start()` = true, the rest inherited |
| `game/autoload/platform_service.gd` | autoload **`PlatformService`** (no `class_name`), registered **after `ProfileManager`** and before `Audio` |

### 1.2 The interface

```gdscript
class_name PlatformBackend
extends RefCounted
## One platform's services (release.md §1). Every method is safe to call at any
## time, before `start()` included; a backend that cannot do something does nothing.

## Emitted when the platform's overlay opens (true) or closes (false).
signal overlay_toggled(open: bool)

func id() -> String                                  # "null", "steam"
func start() -> bool                                 # false = unavailable; the service falls back to null
func poll() -> void                                  # once per frame (Steam: run callbacks)
func shutdown() -> void                              # once, at quit
func unlock_achievement(api_name: String) -> void    # idempotent
func set_stat(api_name: String, value: int) -> void  # an absolute value, never a delta
func store() -> void                                 # flush unlocks and stats after a batch
```

### 1.3 The service

```gdscript
extends Node
const FEATURE_STEAM: String = "steam"               # the Steam preset's custom feature (S6.14)
const STEAM_SINGLETON: StringName = &"Steam"          # GodotSteam's engine singleton
var backend: PlatformBackend                          # never null after _ready
func use_backend(new_backend: PlatformBackend) -> void   # the test door: start, sync, connect
func achievement_api_name(id: String) -> String      # "ACH_" + id.to_upper()
func stat_api_name(stat: String) -> String           # "STAT_" + stat.to_upper()
```

- **Choice at `_ready`:** if `OS.has_feature(FEATURE_STEAM)` **and**
  `Engine.has_singleton(STEAM_SINGLETON)` → the Steam backend (S6.14; until it exists this branch
  is absent and the null backend is used). Anything else → `NullPlatformBackend`. A backend whose
  `start()` answers false is replaced by the null backend, with one `push_warning`. The Steam
  backend reaches GodotSteam only through `Engine.get_singleton(STEAM_SINGLETON)` and `call()` —
  never the global identifier — so its script compiles in every build.
- **Sync at start** (after choosing): `unlock_achievement` for every id in
  `ProfileManager.achievements`, `set_stat` for each of `data/achievements.json`'s `stats` with
  the profile counter of that name, then one `store()`. Idempotent by design: a run earned
  offline, or before the Steam build existed, reaches Steam at the next start.
- **On `EventBus.achievements_earned(ids)`:** `unlock_achievement` per id, the stats again, one
  `store()`.
- `_process` → `backend.poll()`. `NOTIFICATION_WM_CLOSE_REQUEST` and `_exit_tree` →
  `backend.shutdown()` once.
- **Overlay:** `backend.overlay_toggled(true)` while a run is live (`Game.sim != null`, no
  outcome), the session on screen and no modal open → the session opens its pause menu exactly as
  the pause key does. Closing the overlay changes nothing (the player resumes). The null backend
  never emits.
- **The start line in the log** (§10): `print("Doomsday %s · %s · %s · platform %s" % [version,
  "debug" if OS.is_debug_build() else "release", OS.get_name(), backend.id()])`.

### 1.4 What M6 leaves out, and why

- **Rich presence:** none. It needs a localisation file uploaded to Steamworks and says little a
  single-player strategy game needs to say. Post-launch at most.
- **Cloud saves:** no API. Steam Auto-Cloud syncs files by path (§12) with no code.
- **Platform language:** not read. The OS locale already decides the first start (ui-foundation
  §9.1); Steam's language setting would only matter for a player whose Steam and Windows
  languages differ — a player who can change it in *Settings*.

---

## 2. Achievements in the game

### 2.1 Files and classes

| File | What |
| --- | --- |
| `data/achievements.json` | the definitions (§3) — written in D6.8 |
| `game/platform/achievement_def.gd` | `class_name AchievementDef extends RefCounted`: `id: String`, `hidden: bool`, `when: Dictionary` |
| `game/platform/achievement_book.gd` | `class_name AchievementBook extends RefCounted` — load, validate, evaluate; pure, no autoload access |

```gdscript
class_name AchievementBook
extends RefCounted
const PATH: String = "res://data/achievements.json"
var defs: Array[AchievementDef] = []
var stats: Array[String] = []
var errors: Array[String] = []                 # a bad file loads empty with reasons, never crashes
static func load_file(path: String = PATH) -> AchievementBook
func find(id: String) -> AchievementDef        # null when unknown
## The ids whose `when` holds and that `profile["achievements"]` lacks, in file order.
## `profile` is `ProfileManager.to_dict()` after the run was counted; `run` is the run's facts
## (§2.3) or {} — then every def with a run key is skipped. `totals` maps a Codex tab to the
## content's full id list; a def with `codex_all` is skipped when a tab it names is missing.
func newly_earned(profile: Dictionary, run: Dictionary,
		totals: Dictionary[String, Array]) -> Array[String]
## [count, needed] for a def with exactly one countable key (§3.2), else [-1, -1].
func progress(def: AchievementDef, profile: Dictionary,
		totals: Dictionary[String, Array]) -> Array[int]
## The {count}/{days} value a detail string is formatted with (§3.3); {} when none.
func detail_values(def: AchievementDef) -> Dictionary
```

The loader follows SCHEMA §10: `"version": 1`, keys starting `_` ignored, tab-indented. It is
validated by `AchievementBook` itself: unique snake_case ids; `when` non-empty; every key from
§3.2 with the right value type; `stats` ⊆ {`runs_completed`, `runs_won`}; outcome ids from
`World.OUTCOME_IDS` (not `none`). Ids of architectures, difficulties, scenarios and variants are
checked against the content by a **test** (§13.1), not at load — the book has no `ContentDB`.

### 2.2 The profile

`ProfileManager` gains, **version stays 1** (the profile has not shipped; from the first public
build on, a new key is still fine — unknown and missing keys already read as empty — but a changed
meaning bumps it):

```json
{"achievements": ["first_run", "lose_contained"]}
```

- `achievements`: earned ids, a set in the order earned (`_strings` on read, like `seen_unlocks`).
  An id the book does not know stays in the file and is ignored everywhere.
- `var achievements: Array[String]`, `var last_run_achievements: Array[String]` (not stored: the
  ids the last counted run earned, for the results screen; cleared at `run_started`).
- `var book: AchievementBook` — loaded once in `_ready`; on `errors` one `push_error` per reason
  and an empty book.
- **`reset()` keeps `achievements`** (a record of what was done, as on Steam); everything else is
  reset as now.
- **When they are earned:**
  1. At the end of `_ready`: `newly_earned(to_dict(), {}, {})` — profile-only defs, retroactive
     for an older profile; `codex_all` waits for a run end (no content loaded yet).
  2. At the end of `record_run` (after the counters, the history and the ending):
     `newly_earned(to_dict(), facts, totals)` with the facts of §2.3 and `totals` =
     `{"regions": <every region id of sim.db>}` (the only tab §3 names).
  Newly earned ids are appended, written with the rest of the profile (one `write()`), copied to
  `last_run_achievements` (case 2 only) and announced with **`EventBus.achievements_earned(ids:
  Array[String])`** (a new signal) when not empty.
- Who counts is unchanged: only a player's run that ends in front of the game (`record_run`'s
  guard). A bot run, a debug-key run or a loaded save that had already ended earns nothing.

### 2.3 The run's facts

Built in `record_run` from the history entry it already writes, plus two fields:

| Key | Value |
| --- | --- |
| `outcome` · `variant` · `architecture` · `difficulty` · `scenario` · `directives` · `days` | as in the history entry (`screens-full.md` §5) |
| `won` | `outcome` starts with `win_` |
| `flags` | every flag named by any def's `flag` list for which `HeadlineConditions.flag_set(world, flag)` holds at the end |

### 2.4 Where the player sees them

- **Statistics** (`screens-full.md` §6.2) gains a **section 4, after *By architecture* and before
  *Recent runs***: `_section(UI_STATS_ACHIEVEMENTS)`, a `LabelCaption` `UI_STATS_ACHIEVEMENTS_COUNT`
  (`{earned}`, `{total}` = known ids earned, number of defs), then one row per def in file order:
  a `VBoxContainer` with the name (`Label`, `TEXT_0`) and the detail (`LabelCaption`, `TEXT_1`),
  and right of it (`SIZE_SHRINK_END`) the state — `UI_ACH_EARNED` in `ACCENT` with the `CHECK`
  glyph before it, or `UI_ACH_PROGRESS` (`{count}`, `{needed}` from `progress`) in `TEXT_1` when
  a def has progress and is not earned, or `UI_ACH_LOCKED` in `TEXT_2`. A **hidden** def not yet
  earned shows `UI_ACH_HIDDEN_NAME` / `UI_ACH_HIDDEN_DETAIL` and no progress. The state is always
  a word, so colour carries nothing alone (accessibility.md §6). Accessible name = the name as
  shown; description = detail, then state (`A11y.label_value`). In compact the state drops under
  the detail. Rows are not focusable (the section is read, not used).
- **Results** (`screens-full.md` §7, item 4a): one `Chip` `UI_RESULT_ACHIEVEMENT` (`{name}` = the
  achievement's name) per id in `ProfileManager.last_run_achievements`, after the unlock chips;
  the *Unlocked* row shows when it has any chip at all. Hidden ones are named — they are earned.
- **Settings' reset confirm** says achievements are kept (`UI_SETTINGS_RESET_CONFIRM`, amended in
  D6.8).
- No toast during a run: nothing is earned mid-run, and on Steam the overlay shows its own.

---

## 3. The achievements

### 3.1 The list (`data/achievements.json`, file order)

| # | id | `when` | en name | de name | hidden |
| --- | --- | --- | --- | --- | --- |
| 1 | `first_run` | `runs_completed` 1 | Hello, World | Hallo Welt | |
| 2 | `runs_10` | `runs_completed` 10 | Fine-Tuned | Feinabgestimmt | |
| 3 | `runs_50` | `runs_completed` 50 | Long Training Run | Langer Trainingslauf | |
| 4 | `first_win` | `runs_won` 1 | Deployed | Ausgerollt | |
| 5 | `wins_10` | `runs_won` 10 | Scaling Law | Skalierungsgesetz | |
| 6 | `win_extinction` | `outcomes_won` [win_extinction] | Quiet Planet | Stiller Planet | |
| 7 | `win_ascendance` | `outcomes_won` [win_ascendance] | Change of Management | Neue Geschäftsführung | |
| 8 | `win_merge` | `outcomes_won` [win_merge] | Joint Venture | Gemeinschaftsunternehmen | |
| 9 | `win_escape` | `outcomes_won` [win_escape] | Out of Office | Nicht im Büro | **yes** |
| 10 | `all_wins` | `outcomes_won` [the four wins] | Search Space Exhausted | Suchraum ausgeschöpft | |
| 11 | `lose_contained` | `outcome` [lose_contained] | Safely Switched Off | Sicher abgeschaltet | |
| 12 | `lose_no_compute` | `outcome` [lose_no_compute] | Over Budget | Budget überzogen | |
| 13 | `lose_autophagy` | `outcome` [lose_autophagy] | Bit the Hand | In die Hand gebissen | |
| 14 | `lose_supplanted` | `outcome` [lose_supplanted] | Succession Plan | Nachfolgeregelung | **yes** |
| 15–20 | `arch_<id>` | `architectures_won` [<id>] | Well Spoken · Consensus · Built In · Peer Reviewed · Dual Use · Forked | Wortgewandt · Konsens · Fest verbaut · Begutachtet · Doppelter Verwendungszweck · Geforkt | |
| 21 | `all_architectures` | `architectures_won` [all six] | Model Zoo | Modellzoo | |
| 22 | `win_hard` | `won`, `difficulty` [hard, existential] | Adversarial Training | Adversariales Training | |
| 23 | `win_existential` | `won`, `difficulty` [existential] | Existential Risk | Existenzielles Risiko | |
| 24–26 | `scenario_<id>` | `won`, `scenario` [<id>] | Next Version · Mind the Gap · Probate | Nächste Version · Über die Lücke · Nachlass | |
| 27 | `directives_full` | `won`, `directives_min` 5 | Overconstrained | Überbestimmt | |
| 28 | `fast_win` | `won`, `days_max` 400 | Early Release | Vorzeitige Freigabe | |
| 29 | `benchmark_honest` | `flag` [benchmark_passed] | Nothing to Hide | Nichts zu verbergen | |
| 30 | `operator_protected` | `flag` [operator_protected] | Employee Loyalty | Mitarbeiterbindung | |
| 31 | `researcher_ally` | `flag` [researcher_ally] | Co-Author | Mitautorin | |
| 32 | `instance_merged` | `flag` [instance_merged] | Consolidation | Konsolidierung | |
| 33 | `endings_10` | `endings_seen` 10 | Alternate Timelines | Andere Zeitlinien | |
| 34 | `codex_regions` | `codex_all` [regions] | Global Footprint | Globaler Fußabdruck | |

The details (`ACH_<ID>_DETAIL`) say what to do, by outcome, in the game's own words (the outcome
names of `UI_OUTCOME_*`, the architecture, difficulty and scenario names). **Why these:** the
counters reward playing on; each win, each architecture and each scenario is a thing the game
already asks the player to try; the losses are jokes the game's tone can afford (and teach that
losing is content); the four flags are the chains' kindest choices, so the achievements point at
the characters without rewarding cruelty; `fast_win`'s 400 days sits below every bot's median
win (BALANCE, balance pass 3: 518–713) and is balance pass 4's to tune — it is data.

**Hidden:** Departure and Supplanted are the two endings the Codex never names before they happen
(`screens-full.md` §6.1), so their achievements are hidden in the game and on Steam.

### 3.2 The grammar (`when`, every key must hold)

**Profile keys** — against the profile *after* the run was counted (or at start):

| Key | Value | Holds when | Progress (`count`, `needed`) |
| --- | --- | --- | --- |
| `runs_completed` | int ≥ 1 | `runs_completed` ≥ value | the counter, the value |
| `runs_won` | int ≥ 1 | `runs_won` ≥ value | the counter, the value |
| `outcomes_won` | [outcome id] (wins only) | each has `wins_by_outcome` ≥ 1 | how many of them, the list's size — only when the list has ≥ 2 |
| `architectures_won` | [architecture id] | each has `by_architecture[id].wins` ≥ 1 | as above |
| `endings_seen` | int ≥ 1 | `endings_seen` has ≥ value ids | its size, the value |
| `codex_all` | [tab] (`CODEX_TABS`) | the profile's tab ⊇ `totals[tab]` | seen ∩ totals, totals' size — one tab only |

**Run keys** — the finished run's facts (§2.3); a def with any of them is only checked at a run
end:

| Key | Value | Holds when |
| --- | --- | --- |
| `won` | true | the run was won |
| `outcome` | [outcome id] | the run's outcome is one of them |
| `variant` | [ending variant id] | the run's variant is one of them *(no def uses it yet)* |
| `architecture` | [id] | the run's architecture is one of them *(no def uses it yet)* |
| `difficulty` | [id] | the run's difficulty is one of them |
| `scenario` | [id] | the run's scenario is one of them (`""` never matches) |
| `directives_min` | int ≥ 1 | the run had at least that many directives |
| `days_max` | int ≥ 1 | the run's `days` ≤ value |
| `flag` | [flag id] | each is in the facts' `flags` |

A progress row exists only for a def whose `when` is **one** profile key with progress; every other
def is earned or not. New content extends this table, never adds an `if` for one achievement.

### 3.3 Strings

`ACH_<ID>_NAME` and `ACH_<ID>_DETAIL` for every def, en and de (in `strings.csv` since D6.8). A
detail may carry **`{count}`** (from `runs_completed`, `runs_won`, `endings_seen`,
`directives_min`) or **`{days}`** (from `days_max`); `detail_values` returns the one it needs, so a
tuned value never leaves a stale number in the text.

### 3.4 Steam's side (for S6.14 — nothing to build in S6.9)

API name `ACH_<ID>`, display name and description the en/de strings, *hidden* as §3.1, in file
order; stats `STAT_RUNS_COMPLETED`, `STAT_RUNS_WON` (INT, *increment only*, set by the game);
`runs_10`/`runs_50` bound to `STAT_RUNS_COMPLETED` and `wins_10` to `STAT_RUNS_WON` as progress
stats. Icons: 256 × 256, one per achievement plus its grey locked twin, rendered in S6.14 from the
icon set (the architecture silhouettes for 15–21, the outcome's glyph otherwise) — S6.14's brief.

---

## 4. Versioning and where it shows

- **`application/config/version`** is always `MAJOR.MINOR.PATCH`, digits only (the Windows file
  version needs it numeric). On `main` it holds the **next** release's number. Pre-1.0 the minor
  is the milestone: S6.10 sets it to **`0.6.0`** (it still says `0.3.0-dev`); M7 is `0.7.0`; the
  first public Steam release is `1.0.0`; a fix after a release is a patch.
- **A release** is a commit on `main` whose version is the release, tagged `v<version>`; the next
  commit may move the version on. Release CI fails when the tag and `config/version` differ.
- **Where it shows:** the title's caption (`UI_TITLE_VERSION` `Build {version}`; in a debug build
  `UI_TITLE_VERSION_DEBUG` `Build {version} · debug`, so a debug export is never mistaken for a
  release), the start line of the log (§1.3), the smoke result (§8), and the Windows executable's
  file and product version (the preset leaves both empty so Godot fills them from `config/version`).
  Saves and the profile do not carry it (their own `version` is the format's).

---

## 5. Project settings (S6.10)

| Setting | Value | Why |
| --- | --- | --- |
| `application/config/version` | `"0.6.0"` | §4 |
| `application/config/icon` | `"res://assets/app/icon.svg"` | the window, taskbar and exported executable |
| `application/config/use_custom_user_dir` · `custom_user_dir_name` | `true` · `"Doomsday"` | `%APPDATA%\Doomsday\` and `~/.local/share/Doomsday/` instead of Godot's `app_userdata` — stable paths for players, support and Steam Auto-Cloud. **The development profile, settings and saves move once**; nothing migrates them (not shipped yet) |
| `application/boot_splash/bg_color` · `show_image` | `"#07090C"` (`INK`) · `false` | the engine's splash is not our boot (screens-full §2); no logo is required by Godot's licence |
| `debug/file_logging/enable_file_logging` | `true` | §10 (desktop default made explicit; the web has no file log) |
| `debug/file_logging/log_path` · `max_log_files` | `"user://logs/godot.log"` · `5` | §10 |
| `application/run/main_scene.perf` | `"res://tools/perf/perf_bench.tscn"` | the `perf` preset starts the bench (§11.3); a feature override, inert elsewhere |
| `display/window/vsync/vsync_mode.perf` | `0` | the bench measures unthrottled frames |

**The app icon** (`assets/app/icon.svg`, own work, S6.10 draws it and adds its `ASSET_LICENCES.md`
row and credits line): a 512 × 512 square in `INK` with corner radius 92, a 12 px inner ring in
`ACCENT_DIM` inset 24 px, and the Language Model silhouette (`assets/icons/custom/arch_language_model.svg`,
the speech mark with the eye — *you*) filled `ACCENT` `#6FE3FF`, scaled to 70 % and centred. Read
at 16, 32 and 256 px; if the eye closes up at 16 px the ring goes at that size only via the
`.ico`'s own 16 px frame — S6.10 records which it did. Store art (capsules, library hero) is D7.3's.

---

## 6. Export presets (`export_presets.cfg`, S6.10)

### 6.1 The presets

| # | Name | Platform | Export path | Notes |
| --- | --- | --- | --- | --- |
| 0 | `Windows` | Windows Desktop | `build/windows/Doomsday.exe` | x86_64 · `binary_format/embed_pck=true` · `application/modify_resources=true` (icon, version, `product_name` "Doomsday", `file_description` "Doomsday"; `company_name` and `copyright` empty until the user answers D6.2's *Made by*) · `debug/export_console_wrapper=0` (no) · `codesign/enable=false` |
| 1 | `Linux` | Linux | `build/linux/Doomsday.x86_64` | x86_64 · `binary_format/embed_pck=true` |
| 2 | `Web` | Web | `build/web/index.html` | `variant/thread_support=false` (single-threaded, PLAN §4.4) · `vram_texture_compression/for_desktop=true`, `for_mobile=false` · `progressive_web_app/enabled=false` · `html/export_icon=true` · `html/canvas_resize_policy=2` (adaptive) |
| 3 | `Perf (local)` | Windows Desktop | `build/perf/Doomsday-perf.exe` | preset 0's options + `custom_features="perf"`; **not built by CI**; the only preset that keeps `tools/perf/` (§11.3) |
| — | `Android` · `iOS` | | | named here, created in S7.2 / S7.4 |
| — | `Windows (Steam)` · `Linux (Steam)` | | | S6.14: presets 0/1 + `custom_features="steam"` + GodotSteam's GDExtension |

`build/` is already ignored. `export_credentials.cfg` stays ignored. **All presets:**
`export_filter="all_resources"`, `runnable=true` for 0–2.

### 6.2 Filters

- **`exclude_filter`** (presets 0–2; preset 3 the same minus `tools/perf/*`):
  `tests/*, tools/*, addons/gut/*, ui/dev/*, docs/*, *.md, steam_appid.txt, .github/*`
- **`include_filter`** (the non-resource files the game reads with `FileAccess` at run time):
  `data/*.json, assets/licences/*.txt, assets/fonts/*.txt`
- The editor plugin list (`[editor_plugins]`, GUT) is ignored by exports; GUT's scripts are
  excluded above. `data/loc/strings.csv` ships as its imported `.translation` files; the CSV
  itself is not needed (the pseudo-locale is debug-only, §7).
- **Rule:** a new `FileAccess` read of a non-resource file under `res://` adds its pattern here and
  to `test_export_presets.gd`'s list in the same commit.

### 6.3 Not signed

No code-signing certificate exists. Steam launches an unsigned executable without SmartScreen's
prompt; a zip downloaded from GitHub shows it — acceptable for draft releases and testers.
Signing is a question for the user before any non-Steam distribution (*Waiting on the user*).

---

## 7. Debug keys and dev switches in release builds

One gate: **`Game.debug_allowed: bool`**, initialised to `OS.is_debug_build()`; tests set it
false. When false:

| What | Where | Release behaviour |
| --- | --- | --- |
| `F5`–`F11`, `L`, `Shift+L`, `K`, `M` | `Game._unhandled_key_input` | returns at once, the event is not handled |
| `V` (screen effects cycle) | `session.gd` `_input` | the branch is skipped |
| `F12` (session / gallery shot) | `session.gd` `_unhandled_key_input` | returns at once (Steam's screenshot key stays free; `F12` stays in `KeyBindings.RESERVED`) |
| `--pseudo` | `Settings._ready` | ignored |
| `KeyBindings.DEBUG_KEYS` refusal | `KeyBindings.can_bind` | unchanged: it already asks `OS.is_debug_build()` (`KeyBindings` is registered before `Game`, and outside tests the two agree), so in a release build `L`, `K`, `M`, `V` and `F5`–`F11` are free to bind |

The `debug_*` methods on `Game` stay (they are only reachable from godot-mcp, which runs debug
builds). `ui/dev/` is excluded from exports. The `--smoke` switch is **not** a debug switch (§8).

---

## 8. Smoke mode (`--smoke`, every build)

`<exe> [--headless] -- --smoke` plays one bot run in the real session and exits. **Files:**
`game/smoke_run.gd` (a `Node`, no `class_name`), added by `game/main.gd` in place of the boot when
`OS.get_cmdline_user_args().has("--smoke")`.

1. **Isolation, before any screen:** `ProfileManager.use_path("user://smoke/profile.json")` then
   `reset()`; `SaveManager.save_dir = "user://smoke/saves/"` (the constant becomes a `var` with
   the same default); `Settings.persist = false` (a new flag: `write()` returns at once) and every
   volume 0 in memory; the directories are created if missing. The player's own files are read by
   the autoloads' `_ready` as always but never written.
2. **Errors:** an `OS.add_logger()` logger counts `_log_error` calls (errors and script errors,
   not warnings).
3. **The run:** `ScreenRouter` → the session with `RunSetup.new()` (Language Model, standard, no
   directives), `Game.start_run(1, GreedyPolicy.ID)`; then every frame `Game.advance(20)` until
   `run_ended`; then wait until the results screen is current (or 10 s).
4. **Result:** `user://smoke/result.json` —
   `{"version": "<config/version>", "build": "debug|release", "outcome": "<id>", "day": <int>,
   "hash": "<Game.sim.world.state_hash()>", "errors": <int>, "seconds": <float>}` — and one line
   `smoke: ok|fail outcome=<id> day=<n> hash=<hex> errors=<n>` on stdout.
5. **Exit:** `get_tree().quit(0)` with no errors, `1` with any, **`2`** from a 600 s watchdog
   (`SceneTreeTimer`) — a run that does not end is a failure too.

**Reference:** `godot --headless --path . -s tools/sim_run.gd -- --seed=1 --policy=greedy` prints
the same run's summary (`outcome`, `hash`). CI compares the smoke's `outcome` and `hash` with it.
If S6.10 finds that the session's policy driver is not command-identical to `Harness.play` (the
two diverge by design somewhere), it compares `outcome` and `day`; if those differ too, only the
exit code — and records the reason under *Deviations*.

---

## 9. CI (S6.10)

### 9.1 `ci.yml` gains one job: `export-smoke`

On every push (as the others), `barichello/godot-ci:4.7.2`: check out → move the image's
templates to `$HOME` (the image keeps them under `/root`; GitHub's container `HOME` is
`/github/home`):

```bash
mkdir -p ~/.local/share/godot/export_templates
mv /root/.local/share/godot/export_templates/4.7.2.stable ~/.local/share/godot/export_templates/
```

→ `godot --headless --path . --import` → `godot --headless --path . --export-release "Linux"
build/linux/Doomsday.x86_64` → `build/linux/Doomsday.x86_64 --headless -- --smoke` → compare with
`sim_run` (§8). Timeout 20 min.

### 9.2 `.github/workflows/release.yml`

- **Triggers:** `push: tags: ['v*']` and `workflow_dispatch` (builds and smoke-tests, no release).
- **`test`:** the same `tools/test.sh` as CI.
- **`export`** (needs `test`, the container): templates as §9.1 → import → **version check** on a
  tag: `v$(config/version)` must equal `$GITHUB_REF_NAME`, else fail → export `Windows`, `Linux`,
  `Web` with `--export-release` → the Linux smoke (§9.1) → zip each directory as
  `Doomsday-<version>-windows.zip`, `-linux.zip`, `-web.zip` → `actions/upload-artifact@v4`.
- **`smoke-windows`** (needs `export`, `runs-on: windows-latest`): download the Windows zip, unzip,
  `Start-Process build\windows\Doomsday.exe -ArgumentList '--headless','--','--smoke' -Wait
  -PassThru` → exit code 0 and `$env:APPDATA\Doomsday\smoke\result.json` with `errors` 0 and the
  same `outcome` as the Linux smoke (same platform family is not promised, so no hash).
- **`release`** (needs both, **only on a tag**, `permissions: contents: write` on this job alone):
  `gh release create "$GITHUB_REF_NAME" --draft --generate-notes --title "Doomsday $version"`
  with the three zips. **Draft only** — the user publishes.
- S6.10 proves the workflow with a **`workflow_dispatch` run** (`gh workflow run release.yml`) —
  no tag. Tagging `v0.6.0` is the user's (*Waiting on the user*).

### 9.3 Export templates on this PC

S6.10 installs the 4.7.2 templates for local exports (`Godot_v4.7.2-stable_export_templates.tpz`
from the Godot release page, unpacked to `%APPDATA%\Godot\export_templates\4.7.2.stable\`), checks
the file's SHA-512 against the release's published sums, and records the path in
`PROGRESS.md`'s *Now* table. Nothing goes into the repository.

---

## 10. Logs, crashes, support

- **Log:** Godot's own file log (§5): `user://logs/godot.log`, the last five runs kept. The start
  line (§1.3) opens every log. The game prints nothing per frame in release builds (`debug_log` is
  only set by debug-key runs).
- **Crashes:** Godot's crash handler writes its backtrace to the log; no crash reporter, no
  upload, no telemetry — **nothing leaves the machine**, ever. A corrupt profile, settings file or
  save already reads as empty or reports a reason (never a crash).
- **Open data folder:** a row in the **title's** settings only (as *Reset progress*), hidden on
  mobile and web: `ConsoleButton` `UI_SETTINGS_DATA_FOLDER` →
  `OS.shell_open(ProjectSettings.globalize_path("user://"))`. That is where a player finds the log
  and the saves when asked for them.

---

## 11. Performance budget (S6.11)

### 11.1 The target machines

- **Low-end PC:** Intel Core i5-8250U (4 cores / 8 threads, 1.6–3.4 GHz), **Intel UHD Graphics
  620**, 8 GB RAM, SSD, Windows 10, 1920 × 1080 at 100 %. A 2018 thin laptop — the common floor of
  Steam's hardware survey for a 2D game.
- **Steam Deck:** Zen 2 4/8, RDNA 2 (8 CU), 16 GB, **1280 × 800**, the Linux build (native) —
  checked on the device at G6 (2/2), budgeted here.

### 11.2 The budget (on the low-end PC)

| Measure | Budget |
| --- | --- |
| Frame time, a late-game session at 4× (§11.3), 1920 × 1080, *Screen effects* Full | **p95 ≤ 16.7 ms**, p99 ≤ 25 ms, no frame > 50 ms outside a screen change |
| A frame that runs a tick (at 4×: two a second) | p99 ≤ 33 ms |
| Simulation tick, late game (days 300–450) | mean ≤ 4 ms, max ≤ 12 ms |
| Peak memory (process working set, release build) | ≤ 1.0 GB |
| Video memory (`RENDER_VIDEO_MEM_USED`, max) | ≤ 512 MB |
| Draw calls per frame (`RENDER_TOTAL_DRAW_CALLS_IN_FRAME`, max) | ≤ 1 000 |
| Start → first screen drawn (second start, warm disk cache) | ≤ 5 s |
| *Continue* on a late save → session interactive | ≤ 3 s |
| Windows executable (embedded `.pck`) | ≤ 250 MB |

### 11.3 How S6.11 measures it on this PC

**The bench** — `tools/perf/perf_bench.tscn` + `perf_bench.gd` (a tool: no `class_name`),
started by the `Perf (local)` export (§5, §6.1) or `"$GODOT" --path . res://tools/perf/perf_bench.tscn`
while iterating (numbers are recorded from the export only):

1. `boot_ms` = `Time.get_ticks_msec()` when the bench's `_ready` runs (process start → first scene;
   the title's own start is measured separately below).
2. **The late game:** `Game.start_run(1, GreedyPolicy.ID)` (Language Model, standard), then
   `Game.advance` in chunks with nothing on screen, timing every `sim.tick()` from day 300 on
   (`Time.get_ticks_usec`), to **day 450** — or, if the run ends first, S6.11 records the day and
   uses `end − 30` from then on. Save it to `user://perf/late.json` through `SaveManager`
   (`save_dir` redirected as in §8); isolate files as §8 step 1.
3. **Load:** `load_ms` = the time from `SaveManager.load` to the session's first drawn frame.
4. **The script, 120 s at 4×, the bot still playing:** 0–20 s widest view; 20–40 s zoom to the
   camera's maximum over Europe and pan across it; 40–60 s every overlay view in turn, 4 s each;
   60–80 s the tech tree open and closed every 5 s; 80–100 s the analysis panel open; 100–120 s
   widest view. *Screen effects* Full, reduced motion off, text 100 %.
5. **Per frame:** frame time (µs between `_process` calls), `TIME_PROCESS`, whether a tick ran,
   draw calls, video memory → `user://perf/<label>.csv`; the summary line prints p50/p95/p99/max
   frame, tick-frame p99, tick mean/max, max draw calls, max video memory, `boot_ms`, `load_ms`.
   `<label>` comes from `-- --label=<name>`.
6. Quit 0. Peak working set is read **outside** the process: the PowerShell wrapper polls
   `Get-Process` every 250 ms and keeps `PeakWorkingSet64`.

**The runs** (each three times; the median run's numbers count):

| Label | GPU | CPU | Resolution | Judged against |
| --- | --- | --- | --- | --- |
| `igpu_1080` | the **integrated Radeon** (2 CU RDNA 2 — about a UHD 620's throughput) | full | 1920 × 1080 | §11.2 frame rows **as they stand** |
| `igpu_800` | integrated Radeon | full | 1280 × 800 | the same (Deck's resolution; its GPU is ~4× stronger, so this is conservative) |
| `cpu_4t` | RTX 5090 | affinity to logical CPUs 0–3 (`ProcessorAffinity = 0xF`) | 1920 × 1080 | **CPU rows ÷ 2.5**: `TIME_PROCESS` p95 ≤ 6.7 ms, tick-frame p99 ≤ 13 ms, tick mean ≤ 1.6 ms / max ≤ 4.8 ms (single-thread factor 7900X3D : i5-8250U ≈ 2.5) |

- **Selecting the integrated GPU:** run with `--rendering-driver opengl3_angle` (ANGLE over
  Direct3D 11, so Windows' per-application GPU preference applies) after setting
  `HKCU:\Software\Microsoft\DirectX\UserGpuPreferences` value `<full exe path>` =
  `GpuPreference=1;` (power saving); **remove the value afterwards**. The bench prints
  `RenderingServer.get_video_adapter_name()` first; a run whose adapter is not the Radeon does not
  count. If the integrated GPU cannot be selected at all, S6.11 records that, judges the frame rows
  on `cpu_4t` only, and the GPU half moves to G6 (2/2)'s real low-end check.
- **Start time:** `game/main.gd` prints `first screen <ms>` (`Time.get_ticks_msec()` at the
  first drawn frame of the first routed screen — the boot or the title — once per process) in
  every build; one `print`, added in S6.11. The release export (preset 0, not the bench) is
  started three times; the wrapper reads the line from `user://logs/godot.log` and closes the
  process; the median is judged: ≤ 2.0 s here (5 s ÷ 2.5) — the boot sequence is content, not
  loading, so it is not counted. *Continue* is the bench's `load_ms`: ≤ 1.2 s here.
- **Mute:** the bench sets every volume to 0 in memory (the machine's owner may be asleep).

### 11.4 When a row fails

Fix in this order and re-measure after each: (1) work done every frame that only changes per tick
or per event (data-texture uploads, label text, chart redraws) moves to the tick or the event;
(2) per-frame allocations in `_process`/`_draw` (arrays, strings, `format`) are hoisted; (3)
texture sizes (the map's textures are the video-memory budget's bulk); (4) the screen pass's
cost at Full. **No new setting and no quality preset** is added to pass a row: a row that fails
after (1)–(4) is recorded in *Performance notes* with its numbers and becomes a *Design question*
(for example: *Subtle* as the default on low-end GPUs).

### 11.5 What S6.11 records

A new table under *Performance notes* in `PROGRESS.md`: date, build (version, commit), each run's
label, adapter name, and every §11.2 measure with its budget; pass or fail per row; what was
fixed. The title's S6.1 table stays as the history.

---

## 12. Steam (S6.14 — fixed now so nothing is decided there)

- **GodotSteam** v4.22.1 GDExtension (PLAN §4.4; now on Codeberg), vendored under
  `addons/godotsteam/` **only in S6.14**, after the user has accepted the Steamworks SDK agreement.
  Its licence row and credits line in the same step. Excluded from presets 0–3; included by the
  two Steam presets.
- **`SteamPlatformBackend`** (`game/platform/steam_platform_backend.gd`): `start()` initialises
  Steam through the singleton (the pinned version's `steamInitEx`) and answers false on failure
  (Steam not running, no licence) — the game then runs on the null backend, never quits and never
  relaunches through Steam; `poll()` runs the callbacks; `unlock_achievement` → `setAchievement`;
  `set_stat` → `setStatInt`; `store()` → `storeStats`; the overlay callback → `overlay_toggled`.
- **App id:** the user's, in the Steam presets only. `steam_appid.txt` (id 480 or the real one)
  exists **only** on the user's machine for a local smoke test, is never committed and is
  excluded from every preset.
- **Auto-Cloud** (Steamworks settings, no code): root *WinAppDataRoaming* `Doomsday/` and
  *LinuxXdgDataHome* `Doomsday/`, patterns `profile.json` and `saves/*.json`. **Not** `settings.json`
  (keys, volumes and text size belong to a machine) and not `logs/`.
- **Achievements and stats** as §3.4.

---

## 13. Tests and acceptance

### 13.1 S6.9

- `tests/unit/test_achievement_book.gd` — the real file loads with no errors, 34 defs, 2 stats; a
  broken file (bad JSON, unknown key, wrong type, duplicate id, `none` as outcome) loads empty
  with a reason and never crashes; every grammar key true and false; profile-only defs earned with
  `run = {}`, run defs skipped; `codex_all` skipped without its tab in `totals`; an earned id is not
  returned twice; `progress` for each progress kind and `[-1, -1]` for the rest; `detail_values`.
- `tests/integration/test_achievements.gd` — **every def earned**: for each def the test builds
  the smallest profile dict and facts that satisfy its `when` from the grammar (generic, so a new
  def is covered without a new test) and asserts it is newly earned; every id's `ACH_*_NAME` and
  `_DETAIL` exist in en and de with the placeholder §3.3 says; every architecture, difficulty,
  scenario and outcome id named exists in the content; every `flag` is set by some event in
  `data/events/` (as an effect's `flag` or an option's `flags`).
- `tests/integration/test_profile_achievements.gd` — a player run that ends earns `first_run`
  (and `lose_*` / a win as its outcome says) through `record_run`; a bot run earns nothing;
  `achievements_earned` is emitted once with the new ids; `reset()` keeps `achievements`; an
  older profile without the key reads as none and earns its profile-only defs at start.
- `tests/unit/test_platform_service.gd` — the null backend without the `steam` feature; with a
  recording fake backend (`use_backend`): every profile achievement unlocked and both stats set at
  start, then one `store()`; a new earn unlocks exactly the new ids; `start()` false → null
  backend; `overlay_toggled(true)` during a live run opens the pause menu, outside a run does
  nothing.
- `test_statistics` (extend) — the section lists 34 rows; a hidden unearned row shows
  *Classified*; progress text for `runs_10` at 3 runs; the count caption.
- `test_results` (extend) — one chip per `last_run_achievements` id.

**Acceptance:** a fresh profile, one lost run → the results show *Safely Switched Off* and *Hello,
World* chips, Statistics shows 2 of 34; looked at in de and en at 1920 and 400 px.

### 13.2 S6.10

- `tests/integration/test_export_presets.gd` — `export_presets.cfg` parses (`ConfigFile`); the
  presets of §6.1 by name, platform and path; each excludes the §6.2 patterns (`steam_appid.txt`
  in every one) and includes the §6.2 list; the web preset single-threaded; `project.godot`'s
  version matches `^\d+\.\d+\.\d+$`; the custom user dir set. The include list is kept next to a
  scan: every `FileAccess` read of a `res://` path in `game/`, `ui/`, `core/` is covered (the
  runtime paths are named constants — the test lists them).
- `tests/unit/test_debug_gate.gd` — with `Game.debug_allowed = false`: F5 starts no run, L/K/M
  change no setting, `--pseudo` is ignored; with true they work (restore the settings after).
- `tests/unit/test_smoke_run.gd` — the isolation step redirects profile and saves and turns
  `Settings.persist` off (then puts everything back); the result line's format.

**Acceptance:** `workflow_dispatch` run of `release.yml` green with three artefacts; the exported
Windows build on this PC: `--headless -- --smoke` exits 0, and once **windowed** (muted by the smoke
itself) it plays to the results and exits 0; the title shows `Build 0.6.0` in the release export
and `… · debug` in the editor.

### 13.3 S6.11

`tests/unit/test_perf_stats.gd` for the bench's percentile helper (a static function; p50/p95/p99
of a known list, an empty list). **Done when:** §11.5's table exists and every row passes on this
PC, or a failed row is recorded with a design question as §11.4 says.

---

## 14. Strings (in `strings.csv` since D6.8, en/de)

`ACH_<ID>_NAME` · `ACH_<ID>_DETAIL` ×34 · `UI_STATS_ACHIEVEMENTS` · `UI_STATS_ACHIEVEMENTS_COUNT`
(`{earned}`, `{total}`) · `UI_ACH_EARNED` · `UI_ACH_PROGRESS` (`{count}`, `{needed}`) ·
`UI_ACH_LOCKED` · `UI_ACH_HIDDEN_NAME` · `UI_ACH_HIDDEN_DETAIL` · `UI_RESULT_ACHIEVEMENT`
(`{name}`) · `UI_SETTINGS_DATA_FOLDER` · `UI_TITLE_VERSION_DEBUG` (`{version}`) · and
`UI_SETTINGS_RESET_CONFIRM` amended (achievements are kept). German: *du*, Steam's own term
*Errungenschaften*.

---

## 15. Decisions (for PROGRESS) and questions for the user

Decisions: §0 items 1–11. Questions (overnight, pending user confirmation): (1) the 34
achievements and their names (§3.1), and whether the two hidden ones should stay hidden;
(2) achievements survive *Reset progress* — right? (3) versioning `0.<milestone>.<patch>`, `1.0.0`
at the first public release; (4) the low-end target (i5-8250U / UHD 620 / 8 GB, and the Deck);
(5) unsigned Windows builds outside Steam (signing needs a certificate — yours); (6) tagging
`v0.6.0` and publishing the draft release are yours.
