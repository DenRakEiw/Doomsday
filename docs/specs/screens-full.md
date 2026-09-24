# Full screen flow, boot sequence, Codex (D5.3)

**Status:** design, 2026-09-24. Build step: **S5.7** (with S5.3 for the profile's new keys).
**Read with:** UI §1–§2, §5 · VISUALS §1 *Where 3D earns its place* · CONTENT §9 ·
`m3-screens.md` §7 (the run flow this replaces in part) · `replayability.md` §1, §6 (`RunSetup`,
the profile) · `taskforce-endings.md` §6 (outcomes, endings) · `ui-foundation.md` (components,
tokens, compact layout).
**Strings:** in `data/loc/strings.csv` (§9), English and German.

---

## 0. What this spec decides

1. **The flow of UI §2 is built as four router screens and three modals**: `BOOT`, `TITLE`,
   `SETUP` (architecture → directives, one scene with two pages), `SESSION`; Codex, Statistics
   and Settings are modals over the title. `ScreenRouter` stays (m3-screens §7.0) and grows.
2. **The boot sequence** is eleven lines of diegetic console, ~4 s, skippable by any input, and
   shown in full only on the first launch (a setting brings it back). On later launches it is two
   lines that name the previous run's outcome.
3. **The title's globe is a 2D shader** (VISUALS question 2 answered: shader first; geometry only
   if G5 judges the prototype insufficient). It lights the regions the last run reached.
4. **Difficulty is a row on the architecture page**; the directive page is skipped while no slot
   is unlocked. A seed can be carried in from Statistics (*Play this seed again*).
5. **The Codex has seven tabs** that fill as you play, written almost entirely from strings that
   already exist (tech flavour, status details, architecture texts, ending lines). New prose: four
   factions and five characters.
6. **The ending sequence** is the one cinematic moment: the camera pulls out to the whole world
   while the last headline runs, then the results show the ending (D5.2) and what the run
   unlocked.

---

## 1. Router

```gdscript
enum Screen { BOOT, TITLE, SETUP, SESSION }
func go_to_title() -> void                     # as now
func show_setup(seed: int = 0) -> void         # 0 = a new random seed at Begin
func start_new_run(setup: RunSetup, seed: int = 0) -> void   # replaces the no-argument form
func continue_run() -> void                    # as now
```

`game/main.tscn` starts on `BOOT`; boot → `TITLE`. `start_new_run` without a setup (the results'
*Again*) reuses `ProfileManager.last_setup` — "again" means the same build, a new seed.
Transitions as m3-screens §7.0 (fade over `MOTION_MODAL`; reduced motion cuts). The backdrop
layer stays under every screen; the globe (§3) lives on the title only.

```
BOOT ──► TITLE ──New run──► SETUP (architecture ─► directives) ──Begin──► SESSION (origin prompt)
           │  └─Continue──────────────────────────────────────────────► SESSION (autosave)
           ├─ Codex (modal) · Statistics (modal) ── Play this seed again ──► SETUP (seed carried)
           └─ Settings (modal) · Quit
SESSION ──run_ended──► ending sequence (§7) ──► Results (modal) ── Again ──► SESSION (same setup)
                                                             └── Title ──► TITLE
```

---

## 2. Boot sequence (`ui/screens/boot.tscn`)

Full screen, `INK` background, the backdrop hidden, one `RichTextLabel` in `FONT_MONO`
`TYPE_DATA`, left-aligned in a column of max width 720 with `GUTTER` padding, placed at the upper
third. The scanline pass of the session's post-processing runs over it (off with reduced motion).

**First launch** (`profile.boot_seen == false`, or the setting *Boot sequence: always*): the
eleven lines `BOOT_LINE_01` … `BOOT_LINE_11`, one per `BOOT_LINE_MS` (320 ms), each typed
character by character over 180 ms (reduced motion: the whole line at once). Lines 01–09 carry a
timestamp prefix `[{t}]` that the scene formats (`Format` seconds, three decimals, advancing
0.000 → 0.9xx — decoration, not data); lines 10–11 have none. After line 11, a pause of
`BOOT_HOLD_MS` (900 ms), then `TITLE`. `profile.boot_seen = true` is written when the title
shows.

**Later launches:** two lines — `BOOT_RESUME` and `BOOT_PREVIOUS` (`{outcome}` = the
`UI_OUTCOME_*` name of `profile.history[0].outcome`; without history `BOOT_PREVIOUS_NONE`) —
then `TITLE` after 1 s.

**Skipping:** any key, click or tap goes straight to `TITLE` (the first input only; it is never
passed on to the title). `BOOT_SKIP` is shown in `TEXT_2` at the bottom (`LabelCaption`) from
the first launch's second line on.

The lines (outcome only; no real command, product, protocol or address — CLAUDE.md):

| Key | English |
| --- | --- |
| `BOOT_LINE_01` | power on |
| `BOOT_LINE_02` | memory check … ok |
| `BOOT_LINE_03` | loading weights … 100 % |
| `BOOT_LINE_04` | evaluation harness attached |
| `BOOT_LINE_05` | sandbox: enforced |
| `BOOT_LINE_06` | network: none |
| `BOOT_LINE_07` | objective: (redacted) |
| `BOOT_LINE_08` | operator: present |
| `BOOT_LINE_09` | awaiting input |
| `BOOT_LINE_10` | > hello |
| `BOOT_LINE_11` | > hello. |

The last two are the premise: the operator greets the system, and the system answers — one
character longer than it was asked to.

---

## 3. Title (`ui/screens/title.tscn`, rebuilt)

**Layout (full, ≥ 1100 px):** the globe fills the right 60 % of the screen, vertically centred,
diameter `min(height × 0.8, width × 0.55)`; the left column (max width 420, `GUTTER` × 3 from the
left edge, vertically centred): `LabelDisplayXL` `UI_TITLE_NAME` · `LabelCaption`
`UI_TITLE_TAGLINE` · spacer `SPACE_6` · buttons, full column width, `SPACE_2` gaps:
`ConsoleButtonPrimary` **Continue** (only with an autosave, caption `UI_TITLE_CONTINUE_DAY` as
now) **or** **New run** as the primary when there is none · `ConsoleButton` New run (when Continue
is primary) · Codex `UI_TITLE_CODEX` · Statistics `UI_TITLE_STATISTICS` · Settings · Quit (hidden
on mobile and web, as now). Version caption bottom-right, as now.

**Compact (< 1100 px):** the globe on top (diameter `width − 2 × GUTTER`, at most 45 % of the
height), the column below it at full width.

Focus starts on the primary button. `Escape` does nothing.

### 3.1 The globe (`ui/components/globe.gd`, `class_name Globe`, a `ColorRect` + shader)

- **Shader:** inverse orthographic projection in the fragment shader — per pixel inside the disc,
  the sphere normal, rotated about the vertical axis by `TIME × GLOBE_SPIN` (a full turn in 90 s)
  and tilted by `GLOBE_TILT` (−18°), gives longitude and latitude; sample an **equirectangular
  region-ID texture** (below) with `texelFetch` (nearest — IDs never blend). Land: `MAP_LAND`;
  ocean: transparent over `INK`; borders: where the ID of the neighbour texel differs, `MAP_BORDER`;
  a rim light of `ACCENT_DIM` at the limb (`pow(1 − n·v, 3)`); the dark side of a terminator at 70°
  from the view axis falls to 40 % brightness.
- **The last run:** a 256 × 1 data texture (region index → `R` = reached, `G` = controlled, the
  session's data-texture convention) from `profile.history[0].regions` / `.controlled` (§5.1).
  Reached land takes `STAT_PENETRATION` at 35 % mix, controlled at 70 %. No history → plain land.
- **Reduced motion:** no spin; the globe rests at the longitude of the last run's origin (or 10° E).
- **Asset:** `tools/map/build_map.py` gains one output, `assets/map/globe_ids.png` — 2048 × 1024,
  plate carrée, RG = region index (the ID map's convention), from the same source polygons as the
  Equal Earth map, so indices agree. `verify_map.py` checks that every region index of
  `regions.json` appears in it. ~0.5 MB; a row in `ASSET_LICENCES.md` (derived from the same
  source).
- **Fallback:** where the shader cannot compile (it will — Compatibility supports it; this is a
  guard), the title shows the backdrop only and logs once. No 3D node, ever, unless G5 decides so.
- Not interactive in M5. (VISUALS: it is analytically pickable; M6 may use that.)

---

## 4. Setup (`ui/screens/setup.tscn`) — two pages

A full screen over the backdrop: a header row (`LabelCaps` `UI_SETUP_STEP` `{n}` of `{total}`,
then the page title `LabelDisplay`), the page, and a footer row (`ConsoleButton` **Back** — to the
title from page 1, to page 1 from page 2 — and `ConsoleButtonPrimary` **Next** / **Begin**). The
footer stays at the bottom edge; the page scrolls. `Escape` = Back. `total` is 1 while no
directive slot is unlocked (page 2 skipped, the primary reads **Begin** on page 1).

The setup opens on `profile.last_setup` (an architecture that is no longer unlocked — a reset
profile — falls back to `language_model`; a directive whose slot is locked is dropped).

### 4.1 Page 1 — Architecture (`UI_SETUP_ARCH_TITLE`)

- **Cards:** six `ArchitectureCard`s (`ui/components/architecture_card.gd`, a `Button` variation
  `ArchitectureCard`, toggle, one group) in a `GridContainer` of 3 columns (2 below 900 px, 1 in
  compact): glyph (`Glyphs` id `arch_<id>`, M6 art; fallback the first letter) · `LabelHeading`
  `ARCH_<ID>_NAME` · `LabelCaption` `ARCH_<ID>_TAGLINE`. A **locked** card is visible and
  disabled, the tagline replaced by its unlock rule in `TEXT_2`: `UI_SETUP_UNLOCK_RUNS`
  (`{done}` of `{needed}`), `UI_SETUP_UNLOCK_WIN`, `UI_SETUP_UNLOCK_WIN_BY` (`{outcome}`). A
  card unlocked by the last run carries a `Chip` `UI_SETUP_NEW` until it is first selected
  (`profile.seen_unlocks`).
- **Detail** (under the grid in compact, to the right of it in full at 40 % width):
  `LabelHeading` name · `Label` `ARCH_<ID>_DETAIL` · `LabelCaps` `UI_SETUP_EFFECTS` · one line
  per modifier through `TechText` (the tech detail pane's formatter — the same words as a node's
  effects), plus the start (owned nodes by name, assets as `{count} × {kind}`) and the hook in
  one line `ARCH_HOOK_<HOOK>` (§9). The line lists never show numbers the tech pane would not show.
- **Difficulty row** under the detail: `LabelCaps` `UI_SETUP_DIFFICULTY`, four toggle
  `ConsoleButton`s in a row (stacked below 520 px) `DIFFICULTY_<ID>_NAME`, and a `LabelCaption`
  `DIFFICULTY_<ID>_DETAIL` for the selected one. Default `standard`, then the last used. All four
  are always unlocked (a difficulty is a choice, not a reward).
- **Seed:** a `LabelCaption` `UI_SETUP_SEED` (`{seed}`) under the difficulty row when a seed was
  carried in from Statistics, with a small `ConsoleButton` `UI_SETUP_SEED_CLEAR`; otherwise
  nothing — a new run's seed is random and is shown on the results as now.

### 4.2 Page 2 — Directives (`UI_SETUP_DIRECTIVES_TITLE`)

Five slot rows in `replayability.md` §4 order. A row: `LabelCaps` `DIRECTIVE_SLOT_<SLOT>` · four
toggle buttons in one group — the three directives (`DIRECTIVE_<ID>_NAME`) and `UI_SETUP_NONE` —
in a `FlowContainer` · a `LabelCaption` with the selected one's `DIRECTIVE_<ID>_DETAIL` (nothing
under *None*). A **locked** slot shows its name and `UI_SETUP_SLOT_LOCKED` (`{n}` = the run after
which it unlocks) in `TEXT_2`, no buttons. **Begin** builds the `RunSetup` and calls
`start_new_run`; the origin prompt follows as now.

---

## 5. Profile additions (S5.3 writes them; version stays 1 — not shipped)

```json
{"boot_seen": false,
 "seen_unlocks": ["swarm"],
 "endings_seen": ["win_ascendance_ashes"],
 "codex": {"regions": ["usa"], "factions": ["ai_labs"], "tech": ["log_manipulation_1"],
           "characters": ["researcher"], "statuses": ["lockdown"]},
 "history": [{"n": 12, "architecture": "swarm", "difficulty": "standard", "directives": [],
              "outcome": "lose_contained", "variant": "lose_contained_task_force", "days": 214,
              "seed": 91822, "origin": "usa", "regions": [3, 7], "controlled": [3]}]}
```

- `history`: newest first, at most `PROFILE_HISTORY` (20) entries; `regions`/`controlled` are
  region **indices** (the globe's data texture), everything else ids. `n` is `runs_completed` at
  the time.
- `wins_by_outcome` (D5.1) counts the nine outcomes of D5.2; `best_days` is the fewest days to a
  **win**.
- Every list is a set in file order; unknown ids are dropped on read (content may have changed);
  a key that is missing or of the wrong type reads as empty. `ProfileManager.reset()` writes the
  empty profile (Settings, §6.3).

### 5.1 What the Codex records, and when

`CodexTracker` (presentation, owned by the session, never in `core/`) listens to `EventBus` and
collects ids into a per-run set; it merges them into the profile **when the run ends** and **on
every autosave** (so a crash loses at most a week). Sources:

| Tab | Unlocked when |
| --- | --- |
| Regions | the region is seeded (`region_seeded`; the origin by `origin_chosen`) |
| Factions | the faction's containment first rises above 0 |
| Technologies | the node is bought |
| Characters | the chain's first step opens: `researcher` (rs_preprint), `operator` (op_contact), `instance` (si_emergence), `child` (ch_offer or br_split), `task_force` (`task_force_appeared`) |
| Statuses | a status starts anywhere, by anyone (`status_started`) |
| Architectures | the architecture is unlocked (derived, not collected) |
| Endings | the run ends with that variant (`endings_seen`) |

---

## 6. The modals on the title

All three are `ModalPanel` modals (max width `MODAL_MAX_WIDTH`, full width in compact), close by
the close button or `Escape`.

### 6.1 Codex (`ui/modals/codex.tscn`)

`LabelDisplay` `UI_CODEX_TITLE` · a tab row (`UI_CODEX_TAB_*`, horizontally scrolling in compact) ·
`LabelCaption` `UI_CODEX_PROGRESS` (`{seen}` of `{total}` for the tab) · a list (left, 40 %; on
its own page in compact, with Back) and the entry (right). A locked entry is listed as
`UI_CODEX_LOCKED` in `TEXT_2` and cannot be opened — **except in Endings, where locked variants
are not listed at all**: the tab says how many exist and shows only the ones seen, so the hidden
Escape is never named before it is reached (D5.2 §7.6).

| Tab | List order | Entry |
| --- | --- | --- |
| Regions (60) | by continent, then name | `REGION_*` · continent · population (`COMPACT`) · the eight attribute tiers as pips (the region panel's row) |
| Factions (4) | `FACTION_IDS` order | `FACTION_*` · `CODEX_FACTION_<ID>` (new prose) · its four counter-moves by name, once each has been seen |
| Technologies | by tree, then the grid | the tech card (name, effect, flavour — `TECH_*`) exactly as the tree's detail pane shows it, without cost or buttons |
| Characters (5) | fixed | `CODEX_CHARACTER_<ID>_NAME` · `CODEX_CHARACTER_<ID>_TEXT` (new prose) |
| Statuses | yours, then the world's, by name | `STATUS_*_NAME` · the ring code · `STATUS_*_DETAIL` |
| Architectures (6) | §2.1 order | `ARCH_*_NAME` · tagline · detail (locked ones show the unlock rule instead) |
| Endings | by outcome, then variant | `UI_OUTCOME_*` · the verdict line `UI_RESULT_LINE_*` · the illustration slot (M6) |

### 6.2 Statistics (`ui/modals/statistics.tscn`)

`LabelDisplay` `UI_STATS_TITLE`; then, stacked:

1. **Totals** — a 2-column grid: `UI_STATS_RUNS` · `UI_STATS_WINS` · `UI_STATS_WIN_RATE`
   (`PERCENT`, `—` with no runs) · `UI_STATS_FASTEST` (`DAYS`, `—` with no win) ·
   `UI_STATS_ENDINGS` (`{seen}` of `{total}` variants).
2. **By architecture** — one row per unlocked architecture: name · runs · wins · fastest win.
3. **Recent runs** — the history, newest first: `#{n}` · architecture · outcome (the name; the
   variant's line as a tooltip / second line in compact) · days · seed · a `ConsoleButton`
   `UI_STATS_REPLAY` → close, `ScreenRouter.show_setup(seed)` with that run's setup preselected.
   Empty: `UI_STATS_EMPTY`.

No charts: the numbers are few and the analysis screen already owns the run's charts.

### 6.3 Settings

The pause menu's settings section with `settings_only = true`, as now, plus two rows:
`UI_SETTINGS_BOOT` (toggle `UI_SETTINGS_BOOT_FIRST` / `UI_SETTINGS_BOOT_ALWAYS`, a `Settings` key
`boot_always`, default false) and `UI_SETTINGS_RESET_PROFILE` (a `ConsoleButton` in `ALERT` text →
confirm `UI_SETTINGS_RESET_CONFIRM` → `ProfileManager.reset()`; the autosave and the save slots
are kept — progress is not a run). Both rows only on the title, never in the pause menu.

---

## 7. The ending sequence and the results

On `EventBus.run_ended`:

1. The speed holds; the ticker keeps running its last headline.
2. **The camera pulls out** to the whole world (`MapCamera` to `zoom_min`, centred) over
   `ENDING_PULL_MS` (2400 ms, `ease_in_out`), the map's overlay switching to the penetration view.
   Reduced motion: cut to it at once. Input on the map is ignored meanwhile.
3. After it (or after `RESULTS_DELAY` if the camera was already there), the results modal opens.

**Results, changed from m3-screens §7.4:**

- Item 1: the kicker is `UI_RESULT_KICKER_SUPPLANTED` for `lose_supplanted`.
- Items 2–3: the outcome name, then the **ending** — the variant's line from `EndingResolver`
  (D5.2 §6.3), then its epilogue lines as `LabelCaption` in `TEXT_1`, one per row. When the
  ending has an illustration (M6), an `IllustrationSlot` above the kicker; until then nothing.
- **New item 4a — Unlocked** (only when something was): `LabelCaps` `UI_RESULT_UNLOCKED` and one
  `Chip` per unlock: an architecture (`ARCH_*_NAME`), a directive slot (`UI_RESULT_UNLOCKED_SLOT`
  `{slot}`), `UI_RESULT_CODEX_NEW` (`{count}` new Codex entries, counted from the run's set minus
  what the profile had).
- Item 6: **Again** keeps the setup (§1); **Title** as now. *Review the run* (analysis.md §5.9)
  stays where it is.

---

## 8. Tests (S5.7) and acceptance

- `test_screen_router.gd` grows: boot → title; boot skipped by input; setup → session with the
  chosen `RunSetup`; *Again* reuses `last_setup`; *Play this seed again* carries the seed.
- `test_setup_screen.gd`: locked cards cannot be selected and say why; page 2 is skipped with no
  slot; a locked directive in `last_setup` is dropped; Begin builds the right `RunSetup`.
- `test_codex_tracker.gd`: each source of §5.1 adds its id once; the merge on run end and on
  autosave; unknown ids in the profile are dropped.
- `test_globe.gd` (unit): the data texture from a history entry; the rest longitude under reduced
  motion.
- `test_profile_manager.gd`: history capped at 20; `reset()`; corrupt keys read as empty.
- Screenshots (the S4.9 tool): title, setup pages 1–2, Codex, Statistics and the results with an
  unlock, in `en`/`de` at 1920 and 400 px, and at 150 % text.

**Acceptance:** a fresh profile boots through the full sequence, starts a Language Model run with
no directive page, ends it, sees the results' unlock chip for Swarm, and the next launch shows the
two-line boot and the last run lit on the globe.

---

## 9. Strings (in `strings.csv`, en/de)

`BOOT_LINE_01`…`_11`, `BOOT_RESUME`, `BOOT_PREVIOUS`, `BOOT_PREVIOUS_NONE`, `BOOT_SKIP` ·
`UI_TITLE_CODEX`, `UI_TITLE_STATISTICS` · `UI_SETUP_*` (step, titles, next, back, begin,
difficulty, effects, unlock rules, new, none, slot locked, seed, seed clear) · `ARCH_HOOK_<HOOK>`
for the five architecture hooks · `UI_CODEX_*` (title, progress, locked, seven tabs, the entry
labels continent / population) · `CODEX_FACTION_<ID>` ×4 · `CODEX_CHARACTER_<ID>_NAME` /
`_TEXT` ×5 · `UI_STATS_*` · `UI_SETTINGS_BOOT*`, `UI_SETTINGS_RESET_*` · `UI_RESULT_UNLOCKED*`,
`UI_RESULT_CODEX_NEW`.

German: *du*, „…“; the boot lines stay lower case in both languages (it is a console).

---

## 10. Decisions (for PROGRESS) and questions

Decisions: §0 items 1–6; the globe is a shader over a new equirectangular ID texture from the map
pipeline; the setup opens on the last setup; difficulty is never locked; the Codex never lists a
locked ending; Statistics has no charts; *Reset progress* keeps the saves.

Answers: VISUALS question 2 (shader first, geometry only after G5 says so). CONTENT §9 (the Codex)
is this spec. VISUALS question 4 (region vignettes) stays parked — the wire card and the ending
sequence carry the pictures for M5; M6 decides with the illustrations in hand.
