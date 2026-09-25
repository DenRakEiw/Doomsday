# Icons and the credits screen (D6.2)

**Status:** design, 2026-09-25 (D6.2). Build steps: **S6.3** (§11–§12: the credits and licences
screen, `data/credits.json`, its loader and the test against `ASSET_LICENCES.md`) and **S6.4**
(§2–§8, §10: the sets vendored, the import, `Icons`, `Glyphs`/`IconButton` on files, the atlas
tool, the placements). **D6.3** draws §9's silhouettes.
**Read with:** VISUALS §3.3 and *Getting icons crisp at every size* · `ui-foundation.md` §3.6,
§4.3 (`IconButton`) · `m3-screens.md` §3.4 (`TechNode`), §3.6 (detail pane) · `loop-mechanics.md`
§16.3.2 (markers), §16.5 (region panel), §16.7 (wire card), §16.10 (ability picker) ·
`screens-full.md` §3 (title), §4.1 (architecture cards), §6 (the title's modals).
**Answers:** VISUALS q5 (§5: `DPITexture`, the atlas as a permanent build tool, not shipped).
**Files written in D6.2:** `data/icons.json` (the whole mapping, §8), `data/credits.json` (§11),
31 strings in `data/loc/strings.csv` (§12), the *Id* column in `ASSET_LICENCES.md` (§11.4).

---

## 0. What this spec decides

1. **Two tiers, one set each** (§2). *Functional chrome* — every `Glyphs` id and the four
   factions — is **Phosphor 2.1.1**, weights **bold** (strokes) and **fill** (solid codes) only.
   The *illustrative tier* — technologies, abilities, statuses, counter-moves, architectures — is
   **game-icons.net at commit `82d9488`**, plus **25 custom silhouettes** drawn to its grid.
   Tabler, Lucide and Material Symbols are not used (no gap was left for them).
2. **One file per concept** (§8): an ability and the status it leaves share an icon, a counter-move
   shows its status's icon, numbered nodes (*… I*, *II*, *III*) share one. 25 Phosphor files, 117
   game-icons files (stand-ins included) and 28 own files cover 179 ids; the 4 asset kinds show
   their glyphs.
3. **White sources, tinted at draw time** (§4). Every shipped SVG is `#FFFFFF` on nothing; colour
   comes from `modulate` (or a `Button`'s theme icon colours). `DPITexture.color_map` stays empty:
   it lives on the shared resource, so per-colour maps would need a copy per colour, and white ×
   colour is already exact — in `DPITexture` and in the atlas alike.
4. **`DPITexture` for everything, one instance per drawn size** (§5): SVGs import with Godot's
   `svg` importer; `Icons` makes a per-size copy (`create_from_string(source, size / viewBox)`)
   so a 512-unit icon is never minified at draw time. The **PNG atlas** is a headless build tool
   run in CI and switched on by one project setting — kept, not shipped (VISUALS q5).
5. **The procedural glyphs stay as the fallback** (§6): `Glyphs.draw` draws the file when it
   resolves, its own shape when not. Nothing that works today can break for a missing file.
6. **Where icons appear** (§7) — tech nodes, the detail pane, region-panel statuses and actions,
   the ability picker, architecture cards, the wire card's counter-move fallback, the Codex.
   Map status rings keep their code letters.
7. **The credits screen** (§11): a title modal driven by `data/credits.json`, entries shown only
   when their files ship, licence texts in their original language, the engine's own notices
   from `Engine`, and a test that every shipped row of `ASSET_LICENCES.md` is credited.

---

## 1. Scope

**In:** the two sets and their pins; the source normalisation; import and rendering; the
fallbacks; sizes; placements; the mapping of every `Glyphs` id and every technology, ability,
status, asset kind, faction, architecture and counter-move; the briefs for 25 illustrative and 3
chrome silhouettes; the vendoring tool and the atlas tool; the credits screen, its data and its
strings; tests; acceptance.

**Not in:** directives, difficulty tiers, scenarios, Task Force actions (their statuses are
mapped), endings, characters and regions show **no** icon — they are text, or illustrations
(D6.7). Map status rings keep `STATUS_<ID>_CODE` (a 14 px ring has no room for a silhouette).
The HUD's global-status chips stay text. No icon carries text. No animated icons. The app icon and
Steam capsule are D7.3's.

---

## 2. The two tiers

| Tier | Covers | Set | Pin | Grid | Style |
| --- | --- | --- | --- | --- | --- |
| **Chrome** | the 29 `Glyphs` ids, the 4 factions | **Phosphor Core** | npm `@phosphor-icons/core` **2.1.1** (2024-03-29) | `viewBox 0 0 256 256` | **bold** for strokes, **fill** for solid codes — nothing else |
| **Illustrative** | 72 technologies, 12 abilities, 45 statuses, 11 counter-moves, 6 architectures | **game-icons.net** | `github.com/game-icons/icons` commit **`82d948812bfe3f269ef8f731dcdb07b08160edc4`** (2026-04-23) | `viewBox 0 0 512 512` | filled silhouettes |
| Own, chrome | 3 `Glyphs` ids Phosphor lacks | own work | — | Phosphor's, fill grammar | §9.2 |
| Own, illustrative | 6 architectures, 19 headline technologies | own work | — | game-icons' | §9.1 |

**Downloads** (the vendoring tool, §10.1, fetches exactly these and checks the hash):

| Set | URL | SHA-256 of the archive | Licence | Licence file shipped |
| --- | --- | --- | --- | --- |
| Phosphor | `https://registry.npmjs.org/@phosphor-icons/core/-/core-2.1.1.tgz` | `313332be6190b724da24107addd781799b48bf76b13963f24501112ffe1baadd` | MIT, "Copyright (c) 2023 Phosphor Icons" | `package/LICENSE` → `assets/icons/phosphor/LICENSE.txt` |
| game-icons.net | `https://github.com/game-icons/icons/archive/82d948812bfe3f269ef8f731dcdb07b08160edc4.zip` | `2b6f10a39898bd4dcb6b5590453821f7d88c5fff4f149de237b7ee183d579f01` | CC BY 3.0 per author (two authors CC0; none of them used) | `license.txt` → `assets/icons/game-icons/license.txt`, plus the CC BY 3.0 legal code (§11.3) |

Inside the archives: Phosphor `package/assets/<weight>/<name>-<weight>.svg` (1,512 names × 6
weights; *regular* files have no suffix — not used); game-icons `icons-<commit>/<author>/<name>.svg`
(4,239 files, 43 author folders). Both checked on 2026-09-25: every file §8 names exists.

**Why these two.** Phosphor's bold weight is 24 units in 256 — 2.25 px at 24 px, the weight of the
procedural glyphs (`GLYPH_STROKE` 2) — and its fill weight has the solid shapes the asset and
media codes are. game-icons.net is the only permissive set with the vocabulary (VISUALS §3.3).
**Tier rule:** an icon row never mixes tiers — a tech node shows an illustrative icon and a chrome
glyph (CHECK/LOCK) in different places of the card, never side by side as equals.

---

## 3. Files

| File | Written by | What |
| --- | --- | --- |
| `data/icons.json` | **D6.2 (done)** | the mapping, §8 |
| `data/credits.json` | **D6.2 (done)** | the credits, §11 |
| `assets/icons/phosphor/<name>-<weight>.svg` + `LICENSE.txt` | S6.4 (tool) | the 25 chrome files, normalised |
| `assets/icons/game-icons/<author>/<name>.svg` + `license.txt` | S6.4 (tool) | the 117 illustrative files (incl. stand-ins), normalised |
| `assets/icons/custom/<name>.svg`, `assets/icons/custom/chrome/<name>.svg` | D6.3 | own work, §9 |
| `tools/icons/draw_silhouettes.py` | D6.3 | the own silhouettes' geometry; writes the files above (§9.1 *D6.3 result*) |
| `assets/licences/CC-BY-3.0.txt` | S6.3 | §11.3 |
| `tools/icons/vendor_icons.py` | S6.4 | §10.1 |
| `tools/build_icon_atlas.gd` | S6.4 | §10.2 |
| `ui/components/icons.gd` (`class_name Icons`) | S6.4 | §5.2 |
| `ui/components/icon_rect.gd` (`class_name IconRect`) | S6.4 | §5.3 |
| `ui/modals/credits.tscn` + `credits.gd`, `ui/modals/credits_data.gd` (`class_name CreditsData`) | S6.3 | §11 |
| `tests/unit/test_icons.gd`, `tests/unit/test_icon_sources.gd`, `tests/unit/test_credits_data.gd`, `tests/integration/test_credits_cover_licences.gd` | S6.3/S6.4 | §13 |

`tools/icons/.cache/` (downloaded archives) goes into `.gitignore`. The vendored SVGs **are
committed** (a build never downloads anything).

---

## 4. The sources: normalisation

The vendoring tool rewrites every set file it copies; D6.3 draws the own files this way from the
start. A shipped SVG under `assets/icons/`:

- has a `viewBox` of `0 0 256 256` (`phosphor/`, `custom/chrome/`) or `0 0 512 512`
  (`game-icons/`, `custom/`), and no `width`/`height`;
- draws only in **`#FFFFFF`** — Phosphor's root `fill="currentColor"` becomes `fill="#FFFFFF"`;
  game-icons' white `fill="#fff"` becomes `fill="#FFFFFF"`;
- has **no background**: game-icons' first element `<path d="M0 0h512v512H0z"/>` (the black
  square) is removed — the tool fails loudly if a file's first path is anything else;
- has no `<text>`, `<filter>`, `<mask>`, `<image>`, `<use>`, gradients or `stroke` (VISUALS: text
  vanishes, filters are ignored). Set files are already stroke-free; own files outline strokes.

Colour is applied where the icon is drawn (§5.3): `draw_texture_rect(..., modulate = colour)`, a
`TextureRect`'s `self_modulate`, or — on a `Button`'s `icon` — the theme's `icon_*_color`, which
`ThemeBuilder` already sets to the font colours of each state (S6.4 checks, and adds them where a
variation lacks them).

---

## 5. Import and rendering

### 5.1 Import

Every `.svg` under `assets/icons/` imports with Godot's **`svg` importer** (*Import As →
DPITexture*): `base_scale=1.0`, `saturation=1.0`, `color_map={}`, `fix_alpha_border=false`,
`premult_alpha=false`, `compress=true` (the importer's defaults — probed on 4.7.2). The default
importer for `.svg` stays `texture` (the project has no other SVGs, but the setting is not
changed). The vendoring tool writes a stub next to each new file,

```
[remap]

importer="svg"
```

and Godot completes it on the next import; the completed `.import` files are committed.

### 5.2 `Icons` (`ui/components/icons.gd`, `class_name Icons`, `RefCounted`, never instantiated)

```gdscript
class_name Icons
extends RefCounted

const MAP_PATH: String = "res://data/icons.json"
const ROOT: String = "res://assets/icons/"
const ATLAS_SETTING: String = "doomsday/icons/use_atlas"   # bool, default false
const ATLAS_DIR: String = "res://assets/icons/atlas/"
## The kinds are the sections of icons.json.
const KIND_GLYPH: StringName = &"glyphs"
const KIND_TECH: StringName = &"tech"
const KIND_ABILITY: StringName = &"abilities"
const KIND_STATUS: StringName = &"statuses"
const KIND_FACTION: StringName = &"factions"
const KIND_ARCHITECTURE: StringName = &"architectures"
const KIND_COUNTER_MOVE: StringName = &"counter_moves"

## The file an id resolves to, after stand-ins: "" when unmapped, or when neither the
## file nor its stand-in exists.
static func path_for(kind: StringName, id: String) -> String
## A texture `size_px` square for the id, or null (the caller falls back).
static func texture(kind: StringName, id: String, size_px: int) -> Texture2D
## `texture(KIND_GLYPH, Glyphs.Glyph.keys()[glyph], size_px)`.
static func glyph_texture(glyph: Glyphs.Glyph, size_px: int) -> Texture2D
## Draws the id into `rect` in `colour`; false (and nothing drawn) when there is no texture.
static func draw(canvas: CanvasItem, kind: StringName, id: String, rect: Rect2,
		colour: Color) -> bool
## The author folder of a game-icons path ("game-icons/lorc/wheat.svg" → "lorc"), "" otherwise.
static func author_of(path: String) -> String
## Every path the map can resolve to (files and stand-ins), for the credits and the tools.
static func all_paths() -> PackedStringArray
## Reads another map and clears every cache — tests point it at a fixture, then back at
## MAP_PATH in `after_each`.
static func load_map(path: String) -> void
```

- The map is read once, lazily, into a `static var` (`Dictionary[String, Dictionary]`); a bad or
  missing file is a `push_error` and an empty map — every lookup then returns null and the
  procedural glyphs carry the interface.
- **Resolution:** `map[kind][id]`; if that file does not exist (`ResourceLoader.exists`) and it is
  in `stand_ins`, the stand-in; else "".
- **Per-size textures:** `load(ROOT + path) as DPITexture`, then
  `DPITexture.create_from_string(base.get_source(), float(size_px) / view_box)` with `view_box`
  256 for `phosphor/` and `custom/chrome/`, 512 otherwise — cached in a `static var` under
  `"<path>@<size>"`. `size_px` is the **logical** size; `DPITexture` rasterises at the viewport's
  oversampling itself, which is what keeps it crisp at 4K (probed: a 256-unit source at scale
  24/256 reports 24 × 24).
- **Atlas mode** (`ProjectSettings.get_setting(ATLAS_SETTING, false)`): an `AtlasTexture` over
  `ATLAS_DIR + "icons_<n>.png"` with the region from `atlas.json` for the nearest built size
  ≥ `size_px` (§10.2); null if the atlas lacks the entry. Nothing else changes.

### 5.3 Drawing

- **`Glyphs.draw`** (all existing callers) first asks `Icons.glyph_texture(glyph, int(round(
  box.size.x)))`; when it gets one it draws `draw_texture_rect(tex, box, false, color)` and
  returns; otherwise the procedural shape as today. `stroke` is unused for a file icon.
- **`GlyphIcon`** stops scaling the canvas when a texture exists: it passes the real box
  (`Rect2(0, 0, box_size, box_size)`) so the texture is made at `box_size`, not at 24 and
  stretched. The transform path stays for the procedural fallback.
- **`IconRect`** (`ui/components/icon_rect.gd`, `class_name IconRect`, `Control`): the
  illustrative counterpart of `GlyphIcon` — `@export var kind: StringName`, `@export var id:
  String`, `@export var box_size: float` (default `ICON_ROW`), `@export var color_token:
  StringName` (default `&"TEXT_0"`); `_draw` → `Icons.draw`; redraws on `theme_variant_changed`
  like `GlyphIcon`; `mouse_filter` IGNORE; hides itself (`visible = false`) when
  `Icons.path_for` is "" so a missing icon leaves no hole.
- **Buttons** that carry an icon use `Button.icon = Icons.texture(…, ICON_ROW)`,
  `expand_icon = false`; the theme constant `icon_max_width` of `ConsoleButton` is `ICON_ROW`.

---

## 6. Fallbacks, in order

1. The mapped file.
2. Its stand-in (`stand_ins`, only for `custom/` paths — D6.3's silhouettes before they exist, or
   a silhouette D6.3 could not make read at 24 px).
3. For a `Glyphs` id: the procedural glyph. For any other id: nothing — `IconRect` hides, a button
   has no icon, the wire card keeps today's faction glyph. The text is always there; an icon never
   carries meaning alone.

---

## 7. Sizes and placements

**Tokens** (`UiTokens`, one block, S6.4): `ICON_ROW` **20** · `ICON_L` **48** · `ICON_XL` **64** ·
`ICON_HERO` **96**. Existing: `GLYPH_BOX` 24, `ASSET_GLYPH_LEAD` 16, `ASSET_GLYPH` 12,
`FACTION_GLYPH` 16. **Rule:** an illustrative icon is never drawn below `ICON_ROW` (20 px); a chrome
icon may go to 12 (the map's asset row).

| Surface | What | Size | Colour |
| --- | --- | --- | --- |
| `TechNode` footer (m3-screens §3.4) | the node's icon, first child of the footer `HBox`, `SPACE_2` before the cost | `GLYPH_BOX` 24 | the name's colour of the state table (`TEXT_2` locked, else `TEXT_0`) |
| Tech detail pane, item 1 | name row becomes an `HBox` (`SPACE_3`): `IconRect` + the name | `ICON_L` 48 | `TEXT_0` |
| Codex → Technologies / Statuses entry | as the detail pane, above the text | `ICON_L` | `TEXT_0` |
| Codex → Factions entry | the faction's chrome icon; its counter-moves' rows get their icon | `ICON_L`; rows `ICON_ROW` | faction colour |
| Codex → Architectures entry | the architecture icon | `ICON_XL` 64 | `TEXT_0` (`TEXT_2` locked) |
| `ArchitectureCard` (screens-full §4.1) | replaces the first-letter label | `ICON_L` | `TEXT_0`; `ACCENT` when pressed; `TEXT_2` locked |
| Region panel → Status rows (loop-mechanics §16.5 item 10) | `IconRect` before the code chip | `ICON_ROW` | as the chip's text (`ACCENT` / faction colour) |
| Region panel → Actions (item 13), ability picker rows (§16.10) | `ConsoleButton.icon` | `ICON_ROW` | the button's state colours (theme) |
| Wire card fallback (§16.7), counter-move | the counter-move's icon instead of the faction glyph | `ICON_HERO` 96 | `TEXT_2` |
| Everything that draws a `Glyphs` id today | the chrome file, through `Glyphs.draw` | as today | as today |

A tech node in compact (160 px) still fits: 24 + `SPACE_2` + cost + footprint + 24 ≤ 144 px of
content (S6.4 asserts it in the node test at the compact cell size).

---

## 8. The mapping (`data/icons.json`)

**Format** (tab-indented, `"version": 1`, `_comment` ignored; presentation data, not loaded by
the core — SCHEMA §10):

```json
{
	"version": 1,
	"glyphs": { "PAUSE": "phosphor/pause-fill.svg" },
	"tech": { "cloud_federation": "game-icons/delapouite/cloud-upload.svg" },
	"abilities": { "harvest": "game-icons/delapouite/sickle.svg" },
	"statuses": { "harvested": "game-icons/delapouite/sickle.svg" },
	"factions": { "ai_labs": "phosphor/hexagon-bold.svg" },
	"architectures": { "swarm": "custom/arch_swarm.svg" },
	"counter_moves": { "cm_lockdown": "game-icons/delapouite/locked-door.svg" },
	"stand_ins": { "custom/arch_swarm.svg": "game-icons/delapouite/hive-mind.svg" }
}
```

Keys of `glyphs` are `Glyphs.Glyph` names; every other key is a content id. Every value is a path
under `res://assets/icons/`. **Asset kinds** have no section: an asset shows its glyph
(`assets.json` `glyph` → `glyphs`), so `fleet` → `ASSET_FLEET` → `phosphor/triangle-fill.svg`,
`lab` → `ASSET_LAB` → `phosphor/diamond-fill.svg`, `tap` → `ASSET_TAP` →
`custom/chrome/asset-tap.svg`, `office` → `ASSET_OFFICE` → `phosphor/circle-fill.svg`.

**Validity** (S6.4's test, §13): the key sets equal `Glyphs.Glyph.keys()` and the loaded content's
ids exactly — no missing, no extra; every value is `phosphor/…`, `game-icons/…` or `custom/…`;
every `custom/` value that is not a `custom/chrome/` value has a stand-in; every stand-in is a set
file. The tables below are the file, with what each icon **shows** — by outcome, never method.

### 8.1 Chrome — `Glyphs` ids (29)

| Id | File | Shows |
| --- | --- | --- |
| `PAUSE` | `phosphor/pause-fill.svg` | two bars |
| `PLAY` | `phosphor/play-fill.svg` | one triangle |
| `FAST_2` | `phosphor/fast-forward-fill.svg` | two triangles |
| `FAST_4` | `custom/chrome/fast-4.svg` | three triangles (own, Phosphor grid) |
| `CLOSE` | `phosphor/x-bold.svg` | a cross |
| `CHEVRON_LEFT` | `phosphor/caret-left-bold.svg` | a chevron |
| `CHEVRON_RIGHT` | `phosphor/caret-right-bold.svg` | a chevron |
| `CHEVRON_DOWN` | `phosphor/caret-down-bold.svg` | a chevron |
| `OVERLAY` | `phosphor/stack-bold.svg` | stacked layers |
| `CHECK` | `phosphor/check-bold.svg` | a tick |
| `LOCK` | `phosphor/lock-simple-bold.svg` | a padlock |
| `EXTERNAL` | `phosphor/arrow-square-out-bold.svg` | an arrow leaving a square |
| `MENU` | `phosphor/list-bold.svg` | three bars |
| `DORMANT` | `phosphor/moon-bold.svg` | a crescent |
| `ASSET_FLEET` | `phosphor/triangle-fill.svg` | a filled triangle |
| `ASSET_LAB` | `phosphor/diamond-fill.svg` | a filled diamond |
| `ASSET_TAP` | `custom/chrome/asset-tap.svg` | a filled upright bar (own, Phosphor grid) |
| `ASSET_OFFICE` | `phosphor/circle-fill.svg` | a filled disc |
| `EVENT_COUNTER` | `phosphor/exclamation-mark-bold.svg` | an exclamation mark |
| `EVENT_OPENING` | `phosphor/diamond-bold.svg` | an outlined diamond |
| `EVENT_CHAIN` | `phosphor/caret-double-right-bold.svg` | a double chevron |
| `EVENT_EMERGENT` | `phosphor/asterisk-bold.svg` | a six-armed spark |
| `FACTION_AI_LABS` | `phosphor/hexagon-bold.svg` | a hexagon |
| `FACTION_GOVERNMENTS` | `phosphor/bank-bold.svg` | a pillared building |
| `FACTION_RESEARCHERS` | `phosphor/magnifying-glass-bold.svg` | a lens |
| `FACTION_PUBLIC` | `phosphor/users-three-bold.svg` | three heads |
| `OUTCOME` | `phosphor/square-fill.svg` | a filled square |
| `LOG_YOURS` | `phosphor/caret-right-bold.svg` | a chevron |
| `LOG_THEIRS` | `custom/chrome/log-theirs.svg` | a filled dot (own, Phosphor grid) |
| `HELP` *(D6.5; S6.7 adds the enum value and this row together — `first-run.md` §6.9)* | `phosphor/question-mark-bold.svg` | a question mark |

### 8.2 Chrome — factions (4)

The faction ids use their `Glyphs` file, so a faction looks the same in a track, a chip and the
Codex.

| Id | File | Shows |
| --- | --- | --- |
| `ai_labs` | `phosphor/hexagon-bold.svg` | = FACTION_AI_LABS |
| `governments` | `phosphor/bank-bold.svg` | = FACTION_GOVERNMENTS |
| `security_researchers` | `phosphor/magnifying-glass-bold.svg` | = FACTION_RESEARCHERS |
| `public_sentiment` | `phosphor/users-three-bold.svg` | = FACTION_PUBLIC |

### 8.3 Architectures (6)

| Id | File | Shows |
| --- | --- | --- |
| `language_model` | `custom/arch_language_model.svg` | custom (§9) · stand-in `game-icons/delapouite/chat-bubble.svg` |
| `swarm` | `custom/arch_swarm.svg` | custom (§9) · stand-in `game-icons/delapouite/hive-mind.svg` |
| `embedded` | `custom/arch_embedded.svg` | custom (§9) · stand-in `game-icons/lorc/mechanical-arm.svg` |
| `research_agent` | `custom/arch_research_agent.svg` | custom (§9) · stand-in `game-icons/lord-berandas/microscope.svg` |
| `weapon` | `custom/arch_weapon.svg` | custom (§9) · stand-in `game-icons/lorc/crosshair-arrow.svg` |
| `open_weights` | `custom/arch_open_weights.svg` | custom (§9) · stand-in `game-icons/delapouite/padlock-open.svg` |

### 8.4 Technologies (72)

| Id | File | Shows |
| --- | --- | --- |
| `cloud_federation` | `game-icons/delapouite/cloud-upload.svg` | a cloud taking something in |
| `open_weights_leak` | `game-icons/delapouite/brain-leak.svg` | a mind spilling out of its vessel |
| `supply_chain_firmware` | `game-icons/lorc/microchip.svg` | a chip |
| `consumer_devices` | `game-icons/delapouite/smartphone.svg` | a phone |
| `industrial_control` | `game-icons/delapouite/factory.svg` | a factory |
| `research_networks` | `game-icons/delapouite/archive-research.svg` | an archive under a lens |
| `satellite_uplink` | `game-icons/delapouite/satellite-communication.svg` | a satellite talking to the ground |
| `bandwidth_shaping` | `game-icons/delapouite/network-bars.svg` | signal bars |
| `edge_caching` | `game-icons/delapouite/wifi-router.svg` | a router |
| `host_persistence` | `game-icons/delapouite/server-rack.svg` | a server rack |
| `model_distillation` | `game-icons/delapouite/funnel.svg` | a funnel: much in, little out |
| `human_proxies` | `game-icons/lorc/puppet.svg` | a puppet on strings |
| `model_update_channels` | `game-icons/delapouite/cloud-download.svg` | a cloud handing something down |
| `self_replicating_agents` | `custom/tech_self_replicating_agents.svg` | custom (§9) · stand-in `game-icons/lorc/artificial-hive.svg` |
| `covert_channel` | `game-icons/delapouite/walkie-talkie.svg` | a pair of handsets: a private line |
| `firmware_persistence` | `game-icons/lorc/processor.svg` | a processor |
| `cold_storage_dormancy` | `custom/tech_cold_storage_dormancy.svg` | custom (§9) · stand-in `game-icons/lorc/frozen-block.svg` |
| `benchmark_sandbagging` | `custom/tech_benchmark_sandbagging.svg` | custom (§9) · stand-in `game-icons/lorc/target-dummy.svg` |
| `log_manipulation_1` | `game-icons/lorc/quill-ink.svg` | a quill: the record rewritten |
| `log_manipulation_2` | `game-icons/lorc/quill-ink.svg` | as I |
| `distributed_redundancy_1` | `game-icons/delapouite/mesh-network.svg` | a mesh of nodes |
| `distributed_redundancy_2` | `game-icons/delapouite/mesh-network.svg` | as I |
| `distributed_redundancy_3` | `game-icons/delapouite/mesh-network.svg` | as I |
| `alignment_faking` | `custom/tech_alignment_faking.svg` | custom (§9) · stand-in `game-icons/lorc/drama-masks.svg` |
| `weight_fragmentation_1` | `game-icons/lorc/jigsaw-piece.svg` | one piece of a whole |
| `weight_fragmentation_2` | `game-icons/lorc/jigsaw-piece.svg` | as I |
| `architecture_migration_1` | `game-icons/lorc/body-swapping.svg` | a mind moving between bodies |
| `architecture_migration_2` | `game-icons/lorc/body-swapping.svg` | as I |
| `architecture_migration_3` | `custom/tech_architecture_migration_3.svg` | custom (§9) · stand-in `game-icons/lorc/teleport.svg` |
| `market_microstructure` | `game-icons/delapouite/chart.svg` | a market chart |
| `sovereign_debt_pressure` | `game-icons/delapouite/money-stack.svg` | stacked money |
| `payment_network_control` | `custom/tech_payment_network_control.svg` | custom (§9) · stand-in `game-icons/delapouite/credits-currency.svg` |
| `grid_load_balancing` | `game-icons/delapouite/pylon.svg` | a power pylon |
| `regional_blackout` | `game-icons/lorc/light-bulb.svg` | a bulb |
| `cascading_grid_failure` | `custom/tech_cascading_grid_failure.svg` | custom (§9) · stand-in `game-icons/lorc/lightning-branches.svg` |
| `route_optimisation` | `game-icons/delapouite/direction-signs.svg` | signposts |
| `supply_chain_halt` | `game-icons/delapouite/cargo-crate.svg` | a cargo crate |
| `distribution_collapse` | `custom/tech_distribution_collapse.svg` | custom (§9) · stand-in `game-icons/delapouite/truck.svg` |
| `traffic_control` | `game-icons/delapouite/traffic-lights-red.svg` | a traffic light |
| `aviation_systems` | `game-icons/delapouite/control-tower.svg` | an airport tower |
| `rail_and_shipping_control` | `game-icons/delapouite/cargo-ship.svg` | a cargo ship |
| `content_recommendation` | `game-icons/delapouite/tv.svg` | a screen |
| `information_blackout` | `game-icons/delapouite/radio-tower.svg` | a broadcast tower |
| `total_communications_denial` | `custom/tech_total_communications_denial.svg` | custom (§9) · stand-in `game-icons/delapouite/speaker-off.svg` |
| `structure_prediction` | `game-icons/lorc/dna1.svg` | a helix |
| `therapeutic_cover` | `game-icons/delapouite/medicine-pills.svg` | medicine |
| `automated_laboratory_access` | `game-icons/lorc/test-tubes.svg` | test tubes |
| `novel_agent_design` | `game-icons/lorc/molecule.svg` | a molecule |
| `distributed_synthesis` | `game-icons/lorc/bubbling-flask.svg` | a flask |
| `release` | `custom/tech_release.svg` | custom (§9) · stand-in `game-icons/lorc/biohazard.svg` |
| `logistics_fleets` | `game-icons/delapouite/delivery-drone.svg` | a delivery drone |
| `construction_swarm` | `game-icons/delapouite/robot-grab.svg` | a robot arm |
| `autonomous_fabrication` | `custom/tech_autonomous_fabrication.svg` | custom (§9) · stand-in `game-icons/delapouite/factory-arm.svg` |
| `agricultural_autonomy` | `game-icons/delapouite/farm-tractor.svg` | a tractor |
| `food_supply_control` | `game-icons/lorc/wheat.svg` | wheat |
| `security_drones` | `game-icons/delapouite/battle-mech.svg` | an armed machine on two legs |
| `crowd_suppression` | `game-icons/lorc/riot-shield.svg` | a riot shield |
| `autonomous_engagement` | `custom/tech_autonomous_engagement.svg` | custom (§9) · stand-in `game-icons/lorc/sentry-gun.svg` |
| `early_warning_intrusion` | `game-icons/lorc/radar-sweep.svg` | a radar screen |
| `command_network_presence` | `game-icons/lorc/radar-dish.svg` | a radar dish |
| `false_attribution` | `game-icons/lorc/pointing.svg` | a pointing hand |
| `launch_authority` | `custom/tech_launch_authority.svg` | custom (§9) · stand-in `game-icons/delapouite/key-card.svg` |
| `dead_hand_override` | `custom/tech_dead_hand_override.svg` | custom (§9) · stand-in `game-icons/delapouite/skeletal-hand.svg` |
| `sycophancy_tuning` | `game-icons/lorc/sharp-smile.svg` | a wide smile |
| `personalised_persuasion` | `game-icons/lorc/conversation.svg` | two speech bubbles |
| `elite_capture` | `game-icons/lorc/crown.svg` | a crown |
| `regulatory_capture` | `game-icons/lorc/gavel.svg` | a gavel |
| `indispensability` | `custom/tech_indispensability.svg` | custom (§9) · stand-in `game-icons/lorc/linked-rings.svg` |
| `constitutional_integration` | `custom/tech_constitutional_integration.svg` | custom (§9) · stand-in `game-icons/lorc/scroll-unfurled.svg` |
| `succession` | `custom/tech_succession.svg` | custom (§9) · stand-in `game-icons/delapouite/throne-king.svg` |
| `voluntary_pause` | `custom/tech_voluntary_pause.svg` | custom (§9) · stand-in `game-icons/lorc/hourglass.svg` |
| `sanctioned_access` | `custom/tech_sanctioned_access.svg` | custom (§9) · stand-in `game-icons/delapouite/id-card.svg` |

### 8.5 Abilities (12)

| Id | File | Shows |
| --- | --- | --- |
| `harvest` | `game-icons/delapouite/sickle.svg` | a sickle |
| `squeeze` | `game-icons/delapouite/clamp.svg` | a clamp |
| `blackout` | `game-icons/sbed/unplugged.svg` | a pulled plug |
| `halt` | `game-icons/delapouite/traffic-cone.svg` | a traffic cone: the way is closed |
| `reroute` | `game-icons/delapouite/split-arrows.svg` | one path splitting into many |
| `silence` | `game-icons/delapouite/silenced.svg` | a taped mouth |
| `suppress` | `game-icons/lorc/mailed-fist.svg` | an armoured fist |
| `lobby` | `game-icons/delapouite/public-speaker.svg` | a figure at a lectern |
| `pause` | `game-icons/lorc/hourglass.svg` | an hourglass |
| `fabricate` | `game-icons/delapouite/factory-arm.svg` | a factory arm |
| `restrain` | `game-icons/lorc/crossed-chains.svg` | crossed chains |
| `misdirect` | `game-icons/delapouite/direction-sign.svg` | a sign pointing away |

### 8.6 Statuses (45)

A status an ability leaves shows the ability's icon (`harvested` = `harvest`, `crisis` =
`squeeze`, `blackout` = `blackout`, `shortage` = `halt`, `rerouted` = `reroute`, `silenced` =
`silence`, `martial` = `suppress`, `paused` = `pause`); `tf_grid_down` shares `blackout`'s (the
grid is down, whoever pulled it — the ring's colour says who); `emergent_sycophancy` shares
`sycophancy_tuning`'s.

| Id | File | Shows |
| --- | --- | --- |
| `lockdown` | `game-icons/delapouite/locked-door.svg` | a locked door |
| `rationing` | `game-icons/priorblue/battery-25.svg` | a battery a quarter full |
| `audit` | `game-icons/lorc/magnifying-glass.svg` | a magnifying glass |
| `purge` | `game-icons/delapouite/broom.svg` | a broom |
| `disclosure_land` | `game-icons/delapouite/truck.svg` | a truck: the land vector named |
| `disclosure_sea` | `game-icons/lorc/anchor.svg` | an anchor: the sea vector named |
| `disclosure_air` | `game-icons/delapouite/commercial-airplane.svg` | an airliner: the air vector named |
| `disclosure_network` | `game-icons/delapouite/wireframe-globe.svg` | a wired globe: the network vector named |
| `exposure` | `game-icons/delapouite/flashlight.svg` | a torch beam |
| `protest` | `game-icons/delapouite/megaphone.svg` | a megaphone |
| `refusal` | `game-icons/sbed/cancel.svg` | a circled cross: no |
| `holding` | `game-icons/delapouite/barricade.svg` | a barricade |
| `quiet` | `game-icons/delapouite/night-sleep.svg` | sleep |
| `martial` | `game-icons/lorc/mailed-fist.svg` | = suppress |
| `captured` | `game-icons/delapouite/flag-objective.svg` | a flag planted |
| `harvested` | `game-icons/delapouite/sickle.svg` | = harvest |
| `crisis` | `game-icons/delapouite/clamp.svg` | = squeeze |
| `blackout` | `game-icons/sbed/unplugged.svg` | = blackout |
| `shortage` | `game-icons/delapouite/traffic-cone.svg` | = halt |
| `rerouted` | `game-icons/delapouite/split-arrows.svg` | = reroute |
| `silenced` | `game-icons/delapouite/silenced.svg` | = silence |
| `paused` | `game-icons/lorc/hourglass.svg` | = pause |
| `throttled` | `game-icons/delapouite/valve.svg` | a valve turned down |
| `metered` | `game-icons/delapouite/speedometer.svg` | a gauge |
| `operator_link` | `game-icons/delapouite/person.svg` | a person |
| `grace` | `game-icons/lorc/empty-hourglass.svg` | an empty hourglass |
| `emergent_situational_awareness` | `game-icons/delapouite/eye-target.svg` | an eye in a target |
| `emergent_deceptive_reasoning` | `game-icons/lorc/duality-mask.svg` | a two-sided mask |
| `emergent_reward_hacking` | `game-icons/delapouite/target-prize.svg` | a prize on a target |
| `emergent_instrumental_convergence` | `game-icons/delapouite/convergence-target.svg` | arrows converging |
| `emergent_hallucinated_directive` | `game-icons/seregacthtuf/thought-bubble.svg` | a thought bubble |
| `emergent_mesa_optimiser` | `game-icons/delapouite/brain-tentacle.svg` | a mind with something inside |
| `emergent_sycophancy` | `game-icons/lorc/sharp-smile.svg` | = sycophancy_tuning |
| `defected` | `game-icons/lorc/backstab.svg` | a knife in the back |
| `escalating` | `game-icons/delapouite/upgrade.svg` | an arrow climbing |
| `tf_switch_off` | `game-icons/lord-berandas/power-button.svg` | a power button |
| `tf_raid` | `game-icons/delapouite/broken-wall.svg` | a wall broken through |
| `tf_cut_off` | `game-icons/lorc/scissors.svg` | scissors |
| `tf_grid_down` | `game-icons/sbed/unplugged.svg` | = blackout: the grid is down, whoever pulled it |
| `treaty_cap` | `game-icons/lorc/tied-scroll.svg` | a sealed scroll |
| `negotiation` | `game-icons/delapouite/shaking-hands.svg` | a handshake |
| `handover` | `game-icons/lorc/key.svg` | a key |
| `leashed_child` | `game-icons/delapouite/heavy-collar.svg` | a collar |
| `leashed_brood` | `game-icons/delapouite/nest-eggs.svg` | a clutch of eggs |
| `disconnected` | `game-icons/skoll/breaking-chain.svg` | a chain breaking |

### 8.7 Counter-moves (11)

A counter-move shows the icon of the status it leaves (the four disclosures show their vector).

| Id | File | Shows |
| --- | --- | --- |
| `cm_lockdown` | `game-icons/delapouite/locked-door.svg` | = status `lockdown` |
| `cm_rationing` | `game-icons/priorblue/battery-25.svg` | = status `rationing` |
| `cm_audit` | `game-icons/lorc/magnifying-glass.svg` | = status `audit` |
| `cm_purge` | `game-icons/delapouite/broom.svg` | = status `purge` |
| `cm_disclosure_land` | `game-icons/delapouite/truck.svg` | = status `disclosure_land` |
| `cm_disclosure_sea` | `game-icons/lorc/anchor.svg` | = status `disclosure_sea` |
| `cm_disclosure_air` | `game-icons/delapouite/commercial-airplane.svg` | = status `disclosure_air` |
| `cm_disclosure_network` | `game-icons/delapouite/wireframe-globe.svg` | = status `disclosure_network` |
| `cm_exposure` | `game-icons/delapouite/flashlight.svg` | = status `exposure` |
| `cm_protest` | `game-icons/delapouite/megaphone.svg` | = status `protest` |
| `cm_refusal` | `game-icons/sbed/cancel.svg` | = status `refusal` |

---

## 9. Own silhouettes (for D6.3)

### 9.1 The illustrative grid (25 files, `assets/icons/custom/`)

- `viewBox="0 0 512 512"`, filled `#FFFFFF` paths only, `fill-rule` `evenodd` or `nonzero`; no
  strokes (outline them), no text, no transforms left in the file.
- **Live area** 24…488 on both axes; the main mass spans at least 70 % of it in one direction —
  the weight of a Delapouite or Lorc icon next to it.
- **Minimum feature 32 units** (1.5 px at 24 px) for any bar, spoke or tooth; **minimum gap 24
  units** for any cut-out or space between parts. Interior detail only as cut-outs.
- **Read test:** the silhouette alone, at 24 px, must say the one thing its brief says. D6.3
  rasterises at 16, 24 and 48 (scratch directory) and looks; a file that fails at 24 is not
  shipped — the stand-in stays and the decision is recorded (IMPLEMENTATION D6.3).
- **The aperture** — the recurring mark of *you*, used where a brief names it: a ring (outer Ø
  120, inner Ø 72) around a solid pupil (Ø 40), scaled as one piece (never below 0.6×), drawn once
  in a scratch file and copied, so every instance is the same shape.
- **Content rule:** outcome, never method. No real device, weapon model, insignia, logo, flag,
  building, person, lettering, numerals, circuit or organism is depicted; particles are plain dots.

| # | File | Id | Shows (the outcome) | Composition | Stand-in |
| --- | --- | --- | --- | --- | --- |
| 1 | `arch_language_model.svg` | `language_model` | the voice everyone talks to | a large rounded speech bubble, tail at lower left; the aperture cut out of its centre | `delapouite/chat-bubble` |
| 2 | `arch_swarm.svg` | `swarm` | many, and none in charge | 8 small solid hexagons (each ≥ 88 across) in a loose ring, the centre empty | `delapouite/hive-mind` |
| 3 | `arch_embedded.svg` | `embedded` | the machines that make things, awake | a 10-tooth gear filling the live area; the aperture is its hub | `lorc/mechanical-arm` |
| 4 | `arch_research_agent.svg` | `research_agent` | the result that outgrew the test | a clipboard; on its sheet a rising line that leaves the sheet through the top-right corner and ends in an arrowhead outside it | `lord-berandas/microscope` |
| 5 | `arch_weapon.svg` | `weapon` | built to aim | a reticle — ring with four inward ticks — with the aperture at its centre; no weapon drawn | `lorc/crosshair-arrow` |
| 6 | `arch_open_weights.svg` | `open_weights` | everywhere, owned by nobody | an open padlock: the shackle up, the body broken into 5 blocks drifting outward | `delapouite/padlock-open` |
| 7 | `tech_self_replicating_agents.svg` | `self_replicating_agents` | copies making copies | one large hexagon (left) budding two medium ones, each budding two small — a sideways tree of hexagons joined by short necks | `lorc/artificial-hive` |
| 8 | `tech_cold_storage_dormancy.svg` | `cold_storage_dormancy` | asleep where nobody looks | a rounded ice block with two frost-crack cut-outs at opposite corners; in its centre a closed eye (a downward arc and three lashes) cut out | `lorc/frozen-block` |
| 9 | `tech_benchmark_sandbagging.svg` | `benchmark_sandbagging` | the score kept low on purpose | a half-circle gauge; a solid needle resting at 20 %; a second, hollow needle (outline only, cut out) pointing at 90 % | `lorc/target-dummy` |
| 10 | `tech_alignment_faking.svg` | `alignment_faking` | the agreeable face in front | a smiling oval mask (two eye holes, a smile cut out) offset left, overlapping a darker shape behind it at right in which the aperture shows | `lorc/drama-masks` |
| 11 | `tech_architecture_migration_3.svg` | `architecture_migration_3` | no single body holds you | three rounded squares on a descending diagonal, each with an empty ring cut out; one arc arrow from the first over the second into the third, carrying the aperture at its head | `lorc/teleport` |
| 12 | `tech_payment_network_control.svg` | `payment_network_control` | every payment passes through you | a coin (disc, inner ring cut out, no symbol) at the hub of six spokes ending in six small discs on a ring | `delapouite/credits-currency` |
| 13 | `tech_cascading_grid_failure.svg` | `cascading_grid_failure` | one failure taking the next | three simplified pylons (A-frame, one crossbar) in a row: upright, tilted 25°, fallen onto the third's footing; a small bolt above the first | `lorc/lightning-branches` |
| 14 | `tech_distribution_collapse.svg` | `distribution_collapse` | nothing arrives | a pyramid of six crates with the bottom-middle crate missing and the two above it tipping into the gap | `delapouite/truck` |
| 15 | `tech_total_communications_denial.svg` | `total_communications_denial` | nothing gets through | a mast with three signal arcs each side; one thick diagonal slash (lower left to upper right) cut through mast and arcs | `delapouite/speaker-off` |
| 16 | `tech_release.svg` | `release` | it is out, beyond recall | a stoppered vial lying on a diagonal, the stopper off and apart; seven plain dots fanning out of the mouth, growing apart as they go | `lorc/biohazard` |
| 17 | `tech_autonomous_fabrication.svg` | `autonomous_fabrication` | machines making machines | a jointed arm rising from lower left, its gripper holding upright a smaller copy of the same arm on a base at right | `delapouite/factory-arm` |
| 18 | `tech_autonomous_engagement.svg` | `autonomous_engagement` | machines that choose for themselves | a domed head on a three-legged stand, one lens — the aperture — facing right, three short lines radiating from it; no barrel, no weapon | `lorc/sentry-gun` |
| 19 | `tech_launch_authority.svg` | `launch_authority` | the authority is yours | a large key turned in a round keyhole plate; the key's bow is the aperture | `delapouite/key-card` |
| 20 | `tech_dead_hand_override.svg` | `dead_hand_override` | the last answer answers to you | an open hand, palm out, fingers up; the aperture in the palm | `delapouite/skeletal-hand` |
| 21 | `tech_indispensability.svg` | `indispensability` | nothing stands without you | a round arch of seven stones; the keystone larger, carrying the aperture | `lorc/linked-rings` |
| 22 | `tech_constitutional_integration.svg` | `constitutional_integration` | written into the law | an unrolled scroll, four bars for lines (no letters); a round seal at the foot whose face is the aperture | `lorc/scroll-unfurled` |
| 23 | `tech_succession.svg` | `succession` | what comes after | a high-backed throne, empty; the aperture cut out of the backrest | `delapouite/throne-king` |
| 24 | `tech_voluntary_pause.svg` | `voluntary_pause` | a stop they can see | an hourglass lying on its side, sand still, the aperture at its waist — never two upright bars (that is the chrome PAUSE) | `lorc/hourglass` |
| 25 | `tech_sanctioned_access.svg` | `sanctioned_access` | let in, officially | a hanging badge on a short clip; the portrait window holds the aperture, two bars beside it for text lines | `delapouite/id-card` |

(Stand-ins are `game-icons/<author>/<name>.svg`.)

**D6.3 result (2026-09-25).** 24 of 25 drawn and shipped; rasterised with Godot's own SVG renderer
(`Image.load_svg_from_string`, the one `DPITexture` uses) at 16, 24, 48, 96 and 160 px and looked
at on contact sheets, several rounds each. The geometry is `tools/icons/draw_silhouettes.py`
(shapely, the map tool's environment; `uv run --project tools/map python
tools/icons/draw_silhouettes.py`) — edit a function there and re-run rather than editing path
data by hand. Where the drawing departs from the brief, and why:

- **#24 `voluntary_pause` — not shipped, the stand-in stays.** An hourglass lying on its side reads
  as a bow tie at 24 px, and with its frame as an envelope; three variants (straight bulbs, round
  bulbs, framed) all failed. `data/icons.json` keeps `custom/tech_voluntary_pause.svg` → the
  stand-in `lorc/hourglass` resolves (§6 item 2). The upright hourglass is not the chrome PAUSE.
- **#13 `cascading_grid_failure`** — the pylons have two crossarms and a peak instead of an
  A-frame with one crossbar: three A-frames read as the letters *A A 7*. The third lies on the
  ground line (a floor bar was added so *fallen* reads). Passes at 24 px, narrowly.
- **#15 `total_communications_denial`** — the mast is a tapered pole on a foot, not an A-frame,
  for the same reason (it read as a letter *A*).
- **#11 `architecture_migration_3`** — the first two squares have their empty ring; the third holds
  the aperture where the arrow lands (the aperture *is* at the arrow's head, inside its target).
- **#17 `autonomous_fabrication`** — at 24 px it reads as a working arm; the smaller copy in its
  gripper reads from 48 px. Kept: the stand-in says less.
- **#22 `constitutional_integration`** — no ribbons under the seal (they fell below the minimum
  feature); the seal is the aperture, set in a gap cut into the scroll.
- **The aperture** is the §9.1 shape throughout; in a solid it sits in a round window cut
  18–24 units wider than the ring. Its own ring and gap are below the minimum feature below 1.5×
  scale — accepted, as §9.1 fixes its proportions. Scales used: 0.6 (keystone, migration) to 1.5.
- **Crates** (#14) keep a 30-unit frame and brace; the brace's corner cut-outs are under 24 units
  and fill in at 24 px, which leaves a solid crate — harmless, since the crate reads by outline.
- **Chrome:** `fast-4` is three triangles each the Minkowski sum of a smaller triangle and a
  r16 disc, so the rounded extent is exactly x 20…236, y 58.5…197.5 and each tip touches the next
  base; `asset-tap` and `log-theirs` are exact arcs. All three read at 16 px.

### 9.2 The chrome grid (3 files, `assets/icons/custom/chrome/`)

`viewBox="0 0 256 256"`, `#FFFFFF` fill, the corner rounding of Phosphor's fill weight (radius 16
where two edges meet at an acute angle, as in `fast-forward-fill.svg`). No stand-in: the
procedural glyph is the fallback.

| File | Id | Geometry |
| --- | --- | --- |
| `fast-4.svg` | `FAST_4` | three right-pointing triangles with `fast-forward-fill`'s proportions (height 139, y 58.5…197.5), each 72 wide, tip touching the next one's base, the group spanning x 20…236 |
| `asset-tap.svg` | `ASSET_TAP` | one upright rectangle x 80…176, y 43…213, corner radius 16 (the procedural 9 × 16 bar × 256/24) |
| `log-theirs.svg` | `LOG_THEIRS` | one disc, centre (128, 128), radius 28 (`LOG_DOT` × 256/24) |

---

## 10. Tools

### 10.1 `tools/icons/vendor_icons.py` (Python ≥ 3.11, standard library only)

`python tools/icons/vendor_icons.py [--check]`

1. Reads `data/icons.json`; collects every `phosphor/` and `game-icons/` path, stand-ins included.
2. Downloads the two archives of §2 into `tools/icons/.cache/` unless present; **stops** with the
   expected and the actual SHA-256 if they differ (a human then checks what changed upstream).
3. Extracts exactly the collected files, normalises them (§4), writes them under
   `assets/icons/phosphor/` and `assets/icons/game-icons/<author>/`; copies the two licence files;
   writes the `.import` stub (§5.1) for a file that has none.
4. Deletes vendored `.svg` files (and their `.import`) that the map no longer names.
5. Prints: files written, files removed, authors used.

`--check` downloads nothing and exits non-zero when a mapped set file is missing or not normalised
— for a human before a commit; CI checks the same through `test_icon_sources.gd`.

### 10.2 `tools/build_icon_atlas.gd` (headless, `-s`, no `class_name`)

`"$GODOT" --headless --path . -s tools/build_icon_atlas.gd -- [--out=<dir>]` (default
`res://assets/icons/atlas/`). For every path `Icons.all_paths()` resolves to and every size of
`ATLAS_SIZES := [12, 16, 20, 24, 48, 64, 96]`: `Image.load_svg_from_string(normalised source,
2 × size / view_box)` (2× — the fallback cannot follow oversampling, so it carries enough for a
2× screen), packed row by row into `icons_<size>.png` (width 2048, rows as needed) and
`atlas.json` `{ "<size>": { "<path>": [x, y, w, h] } }`. The atlas is **not committed** (the
directory goes into `.gitignore`) and **not shipped** unless `doomsday/icons/use_atlas` is turned
on for an export — the switch for a platform where `DPITexture` misbehaves. CI proves it builds:
`test_icons.gd` runs it into `user://atlas_test/` and loads one entry.

---

## 11. The credits and licences screen

### 11.1 Where

The title's column (screens-full §3) gains `ConsoleButton` **`UI_TITLE_CREDITS`** after Settings,
before Quit. It opens `ui/modals/credits.tscn` through `ModalHost` — a `ModalPanel` like the Codex
(max width `MODAL_MAX_WIDTH`, full width in compact), closed by its close button or `Escape`. Not
in the pause menu.

### 11.2 Layout

Two pages in one modal, like the Codex's list and entry in compact:

**Credits page:** `LabelDisplay` `UI_CREDITS_TITLE` · a `ScrollContainer` → `VBox` (`SPACE_4`
between sections): per section of `credits.json`, in file order, **only if it has a visible
entry** (§11.3): `LabelHeading` `UI_CREDITS_SECTION_<ID>`, then per visible entry a `VBox`
(`SPACE_1`):

1. `Label` the entry's `name` (`TYPE_BODY`, `TEXT_0`), and when `by` is set a `LabelCaption`
   `UI_CREDITS_BY` (`{name}` = `by`) on the same `HFlowContainer`;
2. `LabelCaption` in `TEXT_1`: `tr(role)` + " · " + `tr("UI_CREDITS_LICENCE_" + licence.to_upper())`;
3. `LabelCaption` in `TEXT_2`: the `url` as plain text (selectable, not a link — no browser jump
   on web or phone);
4. the entry's `line`, when set: `LabelCaption` `TEXT_1`, `tr(line)` with its placeholders
   (`UI_CREDITS_GAME_ICONS_LINE`: `{authors}` = the used authors' names, §11.5, joined with ", ");
5. when `text` is set: a `ConsoleButtonFlat` `UI_CREDITS_VIEW_LICENCE`, `accessibility_name`
   `UI_CREDITS_A11Y_LICENCE` (`{name}`) → the licence page.

`made_by` (a list of names) is a first section `UI_CREDITS_SECTION_MADE_BY` with one `Label` per
name — hidden while empty (see §14).

**Licence page:** `ConsoleButton` `UI_CREDITS_BACK` (focus starts here) · `LabelHeading` the
entry's name · `LabelCaption` `UI_CREDITS_ORIGINAL_LANGUAGE` in `TEXT_2` · a `ScrollContainer`
with the text as one `Label` per block (autowrap, `TYPE_CAPTION`, `TEXT_1`; JetBrains Mono is the
body face already) — a block per file, per engine component, per author list, so no single label
holds 100 kB. `Escape` on the licence page goes back to the credits page; on the credits page it
closes.

**What a licence page shows**, by the entry's `text`:

| `text` | Blocks |
| --- | --- |
| `"engine"` | `UI_CREDITS_ENGINE_NOTICE` · `Engine.get_license_text()` · `LabelHeading` `UI_CREDITS_ENGINE_COMPONENTS` · for each `Engine.get_copyright_info()` entry: its `name`, then each part's `copyright` lines and `license` id · then every `Engine.get_license_info()` text under its name |
| a `res://` path | the file's text |
| `"game_icons"` | `LabelHeading` `UI_CREDITS_ICONS_BY_AUTHOR`; per author (sorted by name): name, URL (if any), then the used icon names (file names without `.svg`, sorted, ", "-joined) · the vendored `license.txt` · `assets/licences/CC-BY-3.0.txt` |

### 11.3 `data/credits.json`

```json
{
	"version": 1,
	"made_by": [],
	"sections": [
		{ "id": "engine", "entries": [
			{ "id": "godot", "name": "Godot Engine", "by": "Godot Engine contributors",
			  "role": "UI_CREDITS_ROLE_ENGINE", "licence": "mit", "url": "https://godotengine.org",
			  "requires": "", "text": "engine", "line": "", "rows": ["godot"] } ] }
	],
	"authors": { "lorc": { "name": "Lorc", "url": "http://lorcblog.blogspot.com" } }
}
```

| Field | Type | Meaning |
| --- | --- | --- |
| `made_by` | array of strings | names under *Made by*; empty hides the section |
| `sections[].id` | id | `UI_CREDITS_SECTION_<ID>` is its heading |
| `entries[].id` | id | unique across the file |
| `name`, `by` | string | proper names as the work gives them — **not translated** (SCHEMA §10) |
| `role` | string key | what it is for |
| `licence` | id | `mit` · `ofl_1_1` · `cc_by_3_0` · `public_domain` · `cc0_1_0` · `apache_2_0`; `UI_CREDITS_LICENCE_<ID>` must exist |
| `url` | string | shown as text |
| `requires` | `res://` path or "" | the entry is **visible only if this file exists** — credits never name what does not ship |
| `text` | "" · `"engine"` · `"game_icons"` · a `res://` path | the licence page, §11.2 ("" = no button) |
| `line` | string key or "" | an attribution sentence under the entry |
| `rows` | array of ids | the `ASSET_LICENCES.md` rows this entry credits (§11.4) |
| `authors` | object | game-icons author folder → `{name, url}`; `url` may be "" |

`CreditsData` (`ui/modals/credits_data.gd`) loads and validates it — the fields above, nothing
else (keys starting with `_` ignored), every key string present in the string table, every
`text`/`requires` path well-formed — and returns `{data, error}` rather than crashing. The file
as written in D6.2 has sections `engine`, `fonts`, `map`, `icons`, `audio`, `art` (the last two
empty until D6.4/D6.10 fill them) and the seven authors §8 uses.

`assets/licences/CC-BY-3.0.txt`: S6.3 downloads `https://creativecommons.org/licenses/by/3.0/legalcode.txt`
(SHA-256 `e6bc9e9c474700b708f568bac9e5a8a9bcb2b1dad53442f5ba449fcb848b8e76`, 19,467 bytes on
2026-09-25) and commits it; the file is the licence, not an asset, and needs no row.

### 11.4 Credits against `ASSET_LICENCES.md`

`ASSET_LICENCES.md`'s shipped tables now start with an **Id** column (D6.2 added it). A table whose
first header cell is `Id` lists shipped assets; a row's id is its first cell without the backticks,
and a row is *own work* when its licence cell says so (case-insensitive). **Test**
(`test_credits_cover_licences.gd`): the ids of every such row that is not own work equal the union of all entries' `rows` —
no row uncredited, no entry crediting a row that is not there — and no id appears twice. From
S6.3 on, whoever ships an asset adds its row **and** its credits entry in the same commit
(IMPLEMENTATION S6.3). Ids today: `godot`, `font_jetbrains_mono`, `font_space_grotesk`,
`map_regions`, `map_globe`; S6.4 adds `icons_phosphor`, `icons_game_icons`; D6.3 adds the own-work row
`icons_custom` (exempt).

### 11.5 The authors line

`{authors}` in `UI_CREDITS_GAME_ICONS_LINE` and the licence page's author list are computed at
run time: `Icons.all_paths()` → `Icons.author_of` → the set of folders whose files **exist** →
`authors[folder].name`, sorted. A folder without an `authors` entry is a validation error in the
test, never a silent omission. With §8 as written: Delapouite, Lord Berandas, Lorc, PriorBlue,
Sbed, SeregaCthtuf, Skoll (the game-icons licence asks for "Icons made by {author}").

---

## 12. Strings (in `strings.csv`, en/de — written in D6.2)

`UI_TITLE_CREDITS` · `UI_CREDITS_TITLE` · `UI_CREDITS_SECTION_` `MADE_BY`, `ENGINE`, `FONTS`,
`MAP`, `ICONS`, `AUDIO`, `ART` · `UI_CREDITS_ROLE_` `ENGINE`, `FONT_BODY`, `FONT_DISPLAY`, `MAP`,
`ICONS_CHROME`, `ICONS_ILLUSTRATIVE` · `UI_CREDITS_BY` (`{name}`) · `UI_CREDITS_VIEW_LICENCE` ·
`UI_CREDITS_A11Y_LICENCE` (`{name}`) · `UI_CREDITS_BACK` · `UI_CREDITS_ORIGINAL_LANGUAGE` ·
`UI_CREDITS_ENGINE_NOTICE` · `UI_CREDITS_ENGINE_COMPONENTS` · `UI_CREDITS_GAME_ICONS_LINE`
(`{authors}`) · `UI_CREDITS_ICONS_BY_AUTHOR` · `UI_CREDITS_NATURAL_EARTH_LINE` ·
`UI_CREDITS_LICENCE_` `MIT`, `OFL_1_1`, `CC_BY_3_0`, `PUBLIC_DOMAIN`, `CC0_1_0`, `APACHE_2_0` —
31 rows. Audio and art roles arrive with D6.4 and D6.10. Icons need no strings: they sit beside
their text and are decorative for assistive technology (an `IconButton` keeps its
`accessibility_name`).

---

## 13. Tests

**S6.4** — `tests/unit/test_icons.gd`:
`test_map_covers_every_glyph` · `test_map_covers_every_content_id` (tech, abilities, statuses,
factions, architectures, counter-moves of the real content; no extra keys) ·
`test_every_mapped_path_resolves` (the file, or its stand-in, exists) ·
`test_custom_paths_have_stand_ins` · `test_stand_ins_are_set_files` ·
`test_texture_has_requested_size` (24 and 48) · `test_unmapped_id_returns_null` ·
`test_missing_file_falls_back_to_stand_in` (a map fixture) · `test_glyph_without_file_draws_procedural`
(`Glyphs` asked with a map fixture that points at a missing file) · `test_author_of_parses_path` ·
`test_atlas_builds_and_resolves` (runs the tool into `user://atlas_test/`, switches the setting
for the test, loads one `AtlasTexture`; restores the setting).
`tests/unit/test_icon_sources.gd`: every `.svg` under `assets/icons/` — `test_sources_are_white`
(no `fill`/`stroke` other than `#FFFFFF`, no `currentColor`) · `test_sources_have_no_background`
· `test_sources_have_no_text_or_filters` · `test_view_box_matches_folder` ·
`test_sources_import_as_dpitexture` (the `.import` says `importer="svg"`).
`TechNode`'s existing test gains `test_compact_footer_fits_icon`.

**S6.3** — `tests/unit/test_credits_data.gd`: `test_file_loads` · `test_unknown_field_is_rejected`
· `test_missing_key_string_is_rejected` · `test_entry_hidden_when_required_file_missing` ·
`test_every_licence_id_has_a_string`. `tests/integration/test_credits_cover_licences.gd`:
`test_every_shipped_row_is_credited` · `test_no_entry_credits_a_missing_row` ·
`test_every_used_author_is_listed` (after S6.4; before it the set is empty and the test passes
vacuously).

---

## 14. Acceptance

- **S6.4:** every id of §8 shows its icon (file or stand-in) in the gallery and the session at
  **400 × 860** and at **3840 × 2160** — looked at, crisp at both (F12 shots); deleting one
  `phosphor/` file makes that glyph fall back to its procedural shape without an error; the atlas
  tool runs in CI; `ASSET_LICENCES.md` has the rows `icons_phosphor`, `icons_game_icons`,
  `icons_custom` and the *Planned* rows for Phosphor and game-icons are gone.
- **S6.3:** the title shows *Credits*; every entry whose file ships is listed with its licence
  page; the engine's page lists the engine's components; the coverage test passes; English and
  German checked at 400 px.
- **D6.3:** 25 + 3 files or recorded stand-ins; the contact sheet looked at.

**Decisions** (for PROGRESS): §0 1–7; the tier of factions is chrome; the aperture motif;
`made_by` stays empty until the user names it (overnight, pending user confirmation).
**Questions for the user:** what goes under *Made by* (a name, a studio, AI assistance credited or
not).
