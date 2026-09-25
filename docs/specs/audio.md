# Audio: direction, buses, the cue sheet, captions, the sound set (D6.4)

**Status:** design, 2026-09-25 (D6.4). Build steps: **S6.5** (§2–§8, §11, §12.1: the service, the
buses, the settings, the cue table as data, dispatch, ambience and music logic, captions — with
the files silent or missing) and **S6.6** (§9–§10, §12.2: the synthesis tool, the sound set, the
loudness check, the licence rows).
**Read with:** VISUALS §3.6 (the direction) · `polish-visuals.md` §3.6 (heat — the music's
tension is the same number) · `game/autoload/event_bus.gd` · `core/sim_event.gd` (the event
vocabulary) · `opposition.md` §4 (the factions) · `taskforce-endings.md` §1, §14 (the Task Force).
**Data delivered with this spec:** `data/audio.json` (the sheet, §4), `tools/audio/recipes.json`
(the sounds, §9), the `UI_SETTINGS_*` and `UI_CAPTION_*` rows of `data/loc/strings.csv` (§11).

---

## 0. What this spec decides

1. **Five buses** — `master`, `music`, `ambience`, `interface`, `alerts` — built from data at
   start-up, each with a volume setting (five steps, 0–100 %). No bus effect is load-bearing: the
   web build plays audio as *samples*, which apply no bus effects, so ducking and every dip are
   done on the players' own volume, which works everywhere (§3.4).
2. **One sheet, `data/audio.json`:** 56 cues, 50 triggers, 4 ambience layers, 4 music stems. A
   trigger is an `EventBus` signal, a sim event, a rejected command, a button press, a screen
   change, or a named call from one scene (the boot, the modal host). **First matching trigger
   wins; one event plays at most one cue.**
3. **The world's sounds say who, not what.** Each of the four factions has its own sting, and a
   quieter, filtered version of it when it *prepares* a move — so the player hears who is coming
   before reading anything (VISUALS §3.6). The Task Force has its own red motif (a low tritone).
4. **Ambience adds a layer per phase** (hum → data chatter → a slow pulse → a distant world in
   trouble), so escalation is audible before it is visible. **The music is one adaptive piece in
   four stems**, gated by a *tension* that **is the screen pass's heat** (`polish-visuals.md`
   §3.6): the look and the sound escalate on one number.
5. **Every sound has a visible twin.** The interface's sounds double a control's own state; the
   world's sounds each have a caption (`[Governments: counter-move]`) shown by the new *Sound
   captions* setting in a small stack on the map's left, and a sign that is always on screen
   (§7, §8). Sound never carries information alone.
6. **All 64 files are synthesised** by `tools/audio/synth.py` from `tools/audio/recipes.json` —
   own work, reproducible, no licence risk. CC0 second: Kenney's *Interface Sounds* 1.0 (verified
   CC0) is the named fallback for the interface cues only if G6's ear check rejects the synthesised
   ones (§9.5). **No generated music:** the synthesised stems *are* the shipped music until a
   composed or generated piece with a verified licence replaces them file for file (§9.6).
7. **Loudness:** sample-peak targets per cue, integrated loudness per loop, a −1 dBFS ceiling;
   WAV for cues, OGG Vorbis for loops; 44.1 kHz (§10).
8. **The web unlock:** nothing sounds before the first key, click or tap; cues requested before it
   are dropped (their captions still show), the beds start at the unlock (§5.8).

---

## 1. Scope

**In:** the `Audio` autoload and its pure helpers; the bus layout and the volume settings; the
sheet format, its loader and validator; trigger matching, admission (cooldowns, voice limits,
priority stealing, the alert gap, the ending), ducking and the hold dip; ambience per phase and
screen; the adaptive music; the web unlock; focus loss on desktop; captions and their setting;
strings; the synthesis tool, the sound set, loudness targets and formats; tests; acceptance.

**Out:** positional audio (the map is flat and one screen — nothing gains from panning by
position); voice acting or speech; a sound per headline (the ticker is read, not heard — a sound
for each line would be noise); hover and focus sounds (fatiguing; the screen reader carries focus,
D6.6); a per-faction music layer; the screen-reader and live-region work for captions (D6.6);
the ear check (G6); a composed or generated score (§9.6).

| Step | Sections |
| --- | --- |
| **S6.5 Audio I** | §2 (its files), §3, §4, §5, §6, §7 (triggers, captions), §8, §11, §12.1, §13.1 |
| **S6.6 Audio II** | §2 (its files), §9, §10, §12.2, §13.2, the `ASSET_LICENCES.md` row |

S6.5 builds against **missing files**: a cue whose file does not exist yet is admitted, recorded
and captioned exactly as if it played, and its player simply gets no stream (no error, one
`push_warning` per missing file per session at most). S6.6 then only adds files.

---

## 2. Files

| File | Step | What |
| --- | --- | --- |
| `data/audio.json` | D6.4 | **delivered** — the sheet, §4 |
| `data/SCHEMA.md` §10 | D6.4 | **delivered** — the `audio.json` row |
| `data/loc/strings.csv` | D6.4 | **delivered** — §11 |
| `game/autoload/audio.gd` | S6.5 | **new autoload** `Audio` (`extends Node`, no `class_name`), registered after `ProfileManager` and before `ScreenFx` (§5) |
| `ui/audio/audio_sheet.gd` | S6.5 | `class_name AudioSheet` — loader, validator, typed access (§4.8) |
| `ui/audio/audio_bus_def.gd` · `audio_cue_def.gd` · `audio_trigger_def.gd` · `audio_loop_def.gd` · `audio_screen_def.gd` | S6.5 | the typed records of §4 (one class per file) |
| `ui/audio/audio_rules.gd` | S6.5 | `class_name AudioRules` — pure static: matching, templates, stem gains, volume steps (§5.3, §6) |
| `ui/audio/voice_ledger.gd` · `audio_voice.gd` | S6.5 | `class_name VoiceLedger`, `AudioVoice` — admission and voice picking (§5.4) |
| `ui/audio/caption_text.gd` | S6.5 | `class_name CaptionText` — renders a caption key with its arguments (§8.3) |
| `ui/hud/caption_stack.gd` + `.tscn` | S6.5 | the caption stack (§8), scene-specific, no `class_name` |
| `ui/hud/hud.tscn` | S6.5 | the stack in `LeftColumn` (§8.1) |
| `game/autoload/settings.gd` | S6.5 | the volume, captions and background keys (§3.2) |
| `game/autoload/event_bus.gd` | S6.5 | `volume_changed`, `sound_captions_changed`, `caption_pushed` (§5.1) |
| `ui/modals/pause_menu.gd` | S6.5 | seven settings rows (§3.3) |
| `ui/modals/modal_host.gd` · `ui/screens/boot.gd` | S6.5 | the four `call` triggers (§7.1) |
| `project.godot` | S6.5 | the autoload; nothing else (the buses come from data, §3.1) |
| `tools/audio/pyproject.toml`, `uv.lock` | S6.6 | the tool's environment: `numpy`, `scipy`, `soundfile`, `pyloudnorm`, pinned by the lock (latest at build time) |
| `tools/audio/synth.py` | S6.6 | renders every recipe, measures, checks (§9) |
| `tools/audio/recipes.json` | D6.4 | **delivered** — 64 recipes, §9.2 |
| `assets/audio/ui/*.wav` · `alerts/*.wav` · `ambience/*.ogg` · `music/*.ogg` | S6.6 | the 64 files, written by the tool, with Godot's `.import` files (§10.3) |
| `docs/ASSET_LICENCES.md` | S6.6 | *Audio* row `audio_synth`, own work |
| `tests/unit/test_audio_sheet.gd`, `test_audio_rules.gd`, `test_voice_ledger.gd`, `test_caption_text.gd`, `test_settings.gd` (extended) · `tests/integration/test_audio_dispatch.gd`, `test_caption_stack.gd`, `test_audio_files.gd` (S6.6) | S6.5/S6.6 | §12 |

---

## 3. Buses and settings

### 3.1 The layout

`Audio._ready()` builds the buses from `sheet.buses` with `AudioServer`: `master` is bus 0
(renamed from `Master` only in the sheet — the engine name stays `Master`; `AudioBusDef.id`
`master` maps to index 0); every other bus is added in sheet order, named by its id
(`music`, `ambience`, `interface`, `alerts`), `set_bus_send` to `Master`. The master bus gets one
`AudioEffectHardLimiter` with `ceiling_db = limiter_db` (−1.0). No `.tres` bus layout exists:
a stray `default_bus_layout.tres` is not created, and the project setting is left alone.

| Bus | Carries | Default volume | Pool |
| --- | --- | --- | --- |
| `master` | everything | 100 % | — |
| `music` | the four stems (§6.3) | 75 % | 4 dedicated players |
| `ambience` | the four layers (§6.2) | 100 % | 4 dedicated players |
| `interface` | the player's own actions, controls, the boot | 100 % | 6 players |
| `alerts` | the world: spread, factions, events, the Task Force, phases, the end | 100 % | 4 players |

The split of *interface* and *alerts* is the design: the player who is tired of clicks turns
them down and still hears who is coming.

### 3.2 Settings (`Settings`, `settings.json`)

Version stays 1; every key falls back on its own (the rule since S4.9).

| Key | Type | Default | Notes |
| --- | --- | --- | --- |
| `volume_master` · `volume_music` · `volume_ambience` · `volume_interface` · `volume_alerts` | float | **absent** → the bus's `default_volume` from the sheet | a stored number is clamped to 0…1; anything else falls back |
| `sound_captions` | bool | `false` | §8 |
| `audio_background` | bool | `true` | desktop only: `false` mutes the master bus while the window has no focus |

`Settings` stores the volumes it has been given in `volumes: Dictionary[String, float]` (bus id →
value) and knows nothing of the sheet; `Audio.volume(bus)` returns the stored value or the
sheet's default. `Settings.set_volume(bus: String, value: float) -> void` (write, emit
`EventBus.volume_changed`), `set_sound_captions(enabled: bool) -> void` (write, emit
`sound_captions_changed`), `set_audio_background(enabled: bool) -> void` (write).

**Volume steps:** `AudioRules.VOLUME_STEPS: Array[float] = [0.0, 0.25, 0.5, 0.75, 1.0]`.
`Audio.cycle_volume(bus: StringName) -> void`: the next step above the current value (+0.001),
after the largest the smallest — as `cycle_text_scale`. **Applying:** a volume of 0 mutes the bus
(`set_bus_mute`); anything else unmutes it and sets `set_bus_volume_db(linear_to_db(v))`.

### 3.3 The settings rows

In the pause menu (title and session), after *Text size* (and so after S6.1's *Screen effects*),
before *Introduction*, in this order:

| Row label | Button says | Press |
| --- | --- | --- |
| `UI_SETTINGS_VOLUME_MASTER` | `Format.number(v, PERCENT)`, or `UI_SETTINGS_OFF` at 0 | `Audio.cycle_volume(&"master")` |
| `UI_SETTINGS_VOLUME_MUSIC` | same | `… &"music"` |
| `UI_SETTINGS_VOLUME_AMBIENCE` | same | `… &"ambience"` |
| `UI_SETTINGS_VOLUME_INTERFACE` | same | `… &"interface"` |
| `UI_SETTINGS_VOLUME_ALERTS` | same | `… &"alerts"` |
| `UI_SETTINGS_SOUND_CAPTIONS` | `UI_SETTINGS_ON` / `_OFF` | toggle |
| `UI_SETTINGS_AUDIO_BACKGROUND` | `UI_SETTINGS_ON` / `_OFF` | toggle — **row hidden** when `OS.has_feature("web")` or `OS.has_feature("mobile")` |

The five volume buttons carry `set_meta(&"audio_cue", &"")` (no click, §5.2); after the change
`Audio` plays a **preview** `preview_delay_ms` (100) later: `ui_click` for `master` and
`interface`, `alert_threshold` for `alerts`; `music` and `ambience` are heard already. (The menu
indexes its buttons by position today; the rows shift `INDEX_BOOT` — S6.5 may switch the menu to
a key → button map, which is a build choice.)

### 3.4 The web

Godot plays audio on the web as **samples** (`audio/general/default_playback_type.web`, the
4.3+ default, left as it is): Web Audio buffers that follow each player's volume, pitch, the bus
volume and mute — but **no bus effects**. So: the limiter is a desktop nicety; ducking (§5.5) and
the hold dip (§5.6) move the loop players' `volume_db`, never a bus effect; every stem is its own
player (§6.3). Nothing here uses `AudioStreamGenerator`, `AudioStreamPolyphonic`,
`AudioStreamInteractive` or `AudioStreamSynchronized`. **S7.3 confirms on the web build** that the
stems stay in step; if they drift, the fallback is to switch that one project setting to *Stream*
and record it.

---

## 4. `data/audio.json`

Presentation data (SCHEMA §10): never read by the core, tab-indented, `"version": 1`, keys starting
with `_` ignored. Read by `AudioSheet`.

### 4.1 `buses` — array, `master` first

| Field | Type | Rule |
| --- | --- | --- |
| `id` | string | one of `master`, `music`, `ambience`, `interface`, `alerts`; each exactly once |
| `send` | string | `""` for `master`, else `master` |
| `default_volume` | float | 0…1, one of `VOLUME_STEPS` |
| `pool` | int | `interface` and `alerts` only, ≥ 1 |
| `limiter_db` | float | `master` only, −6…0 |

### 4.2 `mix` — object, every field required

| Field | Value | Use |
| --- | --- | --- |
| `duck_db` | −8.0 | music and ambience under a ducking cue (§5.5) |
| `duck_attack_ms` · `duck_release_ms` | 50 · 800 | §5.5 |
| `alert_gap_ms` · `alert_gap_priority` | 600 · 80 | §5.4 step 4 |
| `hold_ambience_db` · `hold_ms` | −6.0 · 400 | §5.6 |
| `layer_fade_in_ms` | 4000 | a new ambience layer (§6.2) |
| `screen_fade_ms` | 2000 | a screen's ambience/music change (§6.4) |
| `end_fade_ms` | 3000 | the ending (§6.5) |
| `tension_glide_ms` | 4000 | tension moves at most 1.0 per this many ms (§6.3) |
| `preview_delay_ms` | 100 | §3.3 |
| `silent_db` | −80.0 | a gain of 0 as dB (§6.3) |

### 4.3 `cues` — array

| Field | Type | Required | Rule |
| --- | --- | --- | --- |
| `id` | id | yes | unique |
| `bus` | string | yes | `interface` or `alerts` |
| `file` | string | yes | a path under `res://assets/audio/`, ending `.wav` |
| `priority` | int | yes | 0…100 |
| `cooldown_ms` | int | yes | ≥ 0 — measured in real time, not game days (4× speed does not multiply sounds) |
| `voices` | int | yes | ≥ 1 — instances of this cue at once |
| `volume_db` | float | no (0) | −24…6, a trim on top of the file's own level |
| `pitch_jitter` | float | no (0) | 0…0.2 — `pitch_scale` drawn from `1 ± jitter` |
| `duck` | bool | no (false) | `alerts` only: ducks music and ambience (§5.5) |
| `final` | bool | no (false) | `alerts` only: may play in the ending (§5.4) |
| `caption` | string | no (`""`) | a `UI_CAPTION_*` key; `alerts` only — an interface cue never has one (§8) |

### 4.4 `triggers` — array, checked in file order

| Field | Type | Required | Rule |
| --- | --- | --- | --- |
| `on` | string | yes | `sim` · `bus` · `router` · `command_rejected` · `button` · `call` |
| `type` | string | `sim` only | one of `SimEvent.TYPES_ALL` (S5.9 adds `task_force_marked` to it) |
| `signal` | string | `bus` only | `speed_changed` or `region_selected` (the two `EventBus` signals the sheet needs; §5.1 names their fields) |
| `site` | string | `call` only | prose: the script and the moment — documentation, checked for non-empty |
| `match` | object | no | §4.5 |
| `cue` | string | yes | a cue id, or a **template** with `{field}` placeholders (§4.6) |
| `pitch` | float | no (1.0) | 0.5…2.0, multiplies the jitter's draw |

At most one `button` trigger; `call` triggers are documentation of `Audio.cue` call sites and
never matched.

### 4.5 `match` — the vocabulary

`match` maps a **field** of the trigger's data (§5.1) to a condition; every entry must hold.

| Condition | Holds when |
| --- | --- |
| a scalar (`0`, `true`, `"counter_move"`) | the field equals it (an int and a float compare as numbers) |
| an array (`["covert", "open"]`, `[3, 5]`) | the field equals one of them |
| `{"not": x}` — x a scalar or an array | the field is absent, or equals none of them |
| `{"gt": n}` · `{"lt": n}` | the field is a number above / below n |
| `{"gt_field": "f"}` · `{"lt_field": "f"}` | the field is a number above / below the field `f` of the same data |

An absent field fails every condition except `not`. An object with any other key, or with two
keys, is a validation error.

### 4.6 Templates

`"cue": "sting_{faction}"` — each `{name}` is replaced by `str(fields[name])`. A missing field
resolves to `""`, which means *no cue* (the event is swallowed, not passed to the next trigger —
the template trigger matched). A resolved id that is not a cue: no sound, one `push_warning` per
id per session. Tests make sure every faction id, every non-Boxed phase and both outcome classes
resolve (§12.1).

### 4.7 `ambience`, `music`, `screens`

```json
"ambience": {"layers": [{"id": "boxed", "file": "ambience/amb_boxed.ogg", "volume_db": 0.0}, …]},
"music": {"stems": [{"id": "bed", "file": "music/mus_bed.ogg", "volume_db": 0.0, "fade": [-1.0, 0.0]}, …]},
"screens": {"boot": {"ambience_layers": 1, "ambience_db": -12.0, "music": false, "tension": 0.0}, …}
```

- `layers`: exactly four, ids = `World.PHASE_IDS` in order; `.ogg`; `volume_db` −24…6.
- `stems`: 1…4, `.ogg`; `fade` `[lo, hi]` with `lo < hi`, both in −1…1 (§6.3).
- `screens`: keys `boot`, `title`, `setup` (the session is driven by the run, §6.1);
  `ambience_layers` 0…4, `ambience_db` −40…0, `music` bool, `tension` 0…1.

### 4.8 `AudioSheet`

```gdscript
class_name AudioSheet
extends RefCounted
const PATH: String = "res://data/audio.json"
const ASSET_ROOT: String = "res://assets/audio/"
var buses: Array[AudioBusDef] = []
var cues: Dictionary[StringName, AudioCueDef] = {}
var triggers: Array[AudioTriggerDef] = []
var layers: Array[AudioLoopDef] = []
var stems: Array[AudioLoopDef] = []
var screens: Dictionary[StringName, AudioScreenDef] = {}
var duck_db: float … var silent_db: float        # the §4.2 fields, typed
var errors: PackedStringArray = []               # empty = valid
static func load_file(path: String = PATH) -> AudioSheet   # never null
static func from_data(data: Variant) -> AudioSheet
func cue(id: StringName) -> AudioCueDef          # null when unknown
func bus(id: StringName) -> AudioBusDef          # null when unknown
```

`AudioCueDef.path() -> String` = `ASSET_ROOT + file`. The records are plain `RefCounted` with the
§4.1–§4.7 fields typed (`AudioTriggerDef.signal_name` for `signal`; `AudioLoopDef.fade:
Vector2`, `(0, 0)` for a layer). **Validation** returns one error string per broken rule of §4.1–
§4.7, plus: a trigger's non-template `cue` unknown; a `caption` key not in `strings.csv`
(checked by the test, not the loader — the loader has no string table). An invalid sheet is not
fatal: `Audio` logs the errors once with `push_error` (a programming error — the file ships with
the game) and runs silent.

---

## 5. Dispatch — the `Audio` autoload

`process_mode = PROCESS_MODE_ALWAYS` (it and every player it owns keep running under a paused
tree). It owns: the sheet; the players (`Array[AudioStreamPlayer]` per pool bus, 4 layer
players, 4 stem players); a `VoiceLedger`; one `RandomNumberGenerator` (presentation only, seeded
from the clock — it never touches a run's RNG); the loop state of §6.

```gdscript
func cue(id: StringName, pitch: float = 1.0, args: Dictionary = {}) -> bool  # the `call` trigger; true when admitted
func volume(bus: StringName) -> float
func cycle_volume(bus: StringName) -> void
func is_unlocked() -> bool
var history: Array[StringName] = []     # admitted cue ids in order, capped at HISTORY_MAX (512) — tests read it
func reset_history() -> void
```

### 5.1 What it listens to, and the fields each source matches on

| Source | `on` | Fields for `match` and templates |
| --- | --- | --- |
| `EventBus.sim_event(event)` | `sim`, `type == event.type` | `event.data` |
| `EventBus.command_applied(command, result)` with `result.ok == false` | `command_rejected` | `{"reason": result.reason}` |
| `EventBus.speed_changed(speed)` | `bus`, `signal == "speed_changed"` | `{"speed": speed}` |
| `EventBus.region_selected(index)` | `bus`, `signal == "region_selected"` | `{"index": index}` |
| `ScreenRouter.screen_changed(screen)` | `router` | `{"screen": "boot" / "title" / "setup" / "session"}` (the enum name, lower case) |
| every `BaseButton.pressed` (§5.2) | `button` | `{}` |

It also listens, without triggers, to `run_started`, `tick_advanced`, `hold_changed`,
`speed_changed` (the hold dip), `volume_changed` (apply), and `sim_event` of `phase_changed` and
`outcome_reached` (§6). **New `EventBus` signals:** `volume_changed(bus: StringName, value:
float)`, `sound_captions_changed(enabled: bool)`, `caption_pushed(key: String, args: Dictionary)`.

A source is matched against the triggers of its `on` (and `type`/`signal`) in file order;
**the first whose `match` holds decides**, and nothing further is tried.

### 5.2 Buttons

`Audio` connects `get_tree().node_added`; for every `BaseButton` added it connects `pressed` to
play the `button` trigger's cue (`ui_click`) — unless the button has meta `&"audio_cue"`, in
which case that `StringName` is played instead, and `&""` means silence. Nothing else in the
game plays a click. A disabled button emits nothing, so it is silent.

### 5.3 From match to sound

1. `AudioRules.first_trigger(sheet, on, key, fields) -> AudioTriggerDef` (null: nothing).
2. `AudioRules.resolve(trigger.cue, fields) -> String` (`""`: nothing).
3. `def = sheet.cue(id)`; null → nothing (warning once, §4.6).
4. `ledger.admit(def, now_ms, sheet) -> bool` (§5.4). Refused → nothing, no caption.
5. Admitted: append to `history`; if `def.caption != ""` emit `EventBus.caption_pushed(def.caption,
   fields)` (§8) — **whatever the volume, the mute or the web lock**: the caption reflects the
   game, not the speaker.
6. If unlocked (§5.8): `slot = ledger.pick_slot(def, voices_of(bus))`; −1 → no sound; else
   (re)start that player with the cue's stream, `volume_db = def.volume_db`, `pitch_scale =
   trigger.pitch × rng.randf_range(1 − jitter, 1 + jitter)`, and record the slot's `AudioVoice`.
   If `def.duck`: duck (§5.5).

### 5.4 Admission and voices (`VoiceLedger`, pure)

```gdscript
class_name VoiceLedger
extends RefCounted
var last_start_ms: Dictionary[StringName, int] = {}
var last_gap_ms: int = -1000000
var ending: bool = false
func admit(cue: AudioCueDef, now_ms: int, sheet: AudioSheet) -> bool
func pick_slot(cue: AudioCueDef, voices: Array[AudioVoice]) -> int
func reset() -> void

class_name AudioVoice
extends RefCounted
var cue_id: StringName = &""
var priority: int = 0
var started_ms: int = 0
var playing: bool = false     # Audio keeps it in step with the player's `finished`
```

`admit`, in order — the first refusal wins:

1. **Ending:** `ending` and the cue is on `alerts` and not `final` → refuse.
2. **Cooldown:** `now − last_start_ms[cue] < cooldown_ms` → refuse.
3. **Alert gap:** the cue is on `alerts`, `priority < alert_gap_priority`, and `now − last_gap_ms <
   alert_gap_ms` → refuse (discovery, a phase, the Task Force striking are heard alone).
4. Admit: `last_start_ms[cue] = now`; if on `alerts` with `priority >= alert_gap_priority`:
   `last_gap_ms = now`.

`pick_slot`, in order:

1. The playing voices of this cue number ≥ `voices` → the **oldest** of them (it restarts).
2. A voice not playing → the first.
3. The playing voice with the **lowest priority**, oldest among equals, if that priority ≤ the
   cue's → it (stolen).
4. −1.

`ending` is set when an `outcome_reached` is dispatched (after its own `end_*` cue was admitted)
and cleared on `run_started` and `screen_changed`.

### 5.5 Ducking

A `duck` cue sets the duck offset's target to `duck_db` over `duck_attack_ms`, holds it for the
stream's length (`get_length()`; a missing file: 1 s), then returns to 0 over `duck_release_ms`. A
second duck during the hold extends the hold to the later end. The offset is added to every layer
and stem player's `volume_db` (§6.6) — never a bus effect (§3.4).

### 5.6 The hold dip

While the clock stands — `speed == 0` or `hold_changed(true)` — the ambience players take
`hold_ambience_db` (−6) over `hold_ms`, and give it back the same way. Music is untouched. It is
how a paused world sounds: still there, further away.

### 5.7 Focus (desktop)

`_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)`: if not `Settings.audio_background`, mute
bus 0. `FOCUS_IN`: restore bus 0 from its volume (0 stays muted). Not on web or mobile.

### 5.8 The web's first-input unlock

`is_unlocked()` is `true` from the start except on `OS.has_feature("web")`. There, `Audio._input`
watches for the first pressed `InputEventKey`, `InputEventMouseButton` or `InputEventScreenTouch`
(it does not consume it — on the boot screen the same input skips to the title, as today) and
then unlocks: the loops of the current screen start (§6.4) and cues sound from then on. Cues
before it are admitted, recorded and captioned (§5.3) but not played or queued — a click from
the past is worse than none. The web boot is therefore silent, and the title is the first thing
heard.

### 5.9 Headless and tests

Under `--headless` Godot's dummy driver plays nothing and costs nothing; the autoload runs the
same way, so `history` is the test's ear. Bot runs play cues like any run (they are watched).
`sim_run`/`sim_batch`/`sim_report` load no autoloads and are untouched.

---

## 6. Ambience and music

### 6.1 In the session

- **On `screen_changed(SESSION)`** (before a run exists): layers = 1 (Boxed), `ambience_db` 0, music
  on at tension 0, faded over `screen_fade_ms`.
- **On `run_started`** (a new run or a load): layers = `AudioRules.layer_count(world.phase)` =
  phase index + 1, tension = the run's heat (§6.3) — both **at once**, no fade (a loaded Open run
  sounds Open immediately).
- **On `sim_event` `phase_changed`**: the new layer fades in over `layer_fade_in_ms` (after the
  phase sting). Layers never fade out inside a run — phases do not go back.
- **On `tick_advanced`**: tension target = heat (§6.3).

### 6.2 The layers

| Phase | Layer added | What it is (§9.3) |
| --- | --- | --- |
| Boxed | `amb_boxed` | a machine room: mains hum and its harmonics, filtered fan noise — the box |
| Covert | `amb_covert` | sparse, quiet data chirps at irregular intervals, a hiss of air — something moving in the network |
| Emergent | `amb_emergent` | a slow sub-bass pulse, 0.5 Hz, and a low rumble — pressure |
| Open | `amb_open` | a low tritone drone swelling and a distant wailing tone, wind — a world in trouble |

A layer player's gain moves linearly from 0 to 1 over its fade; each is a loop that never stops
while its screen wants it (§6.4).

### 6.3 The music: one piece, four stems, one tension

`tension` ∈ 0…1. **In a run it is the screen pass's heat**, computed the way `ScreenFx` computes
it (`ScreenFxRules.heat(phase, ScreenFxRules.endgame(world, db))`, `polish-visuals.md` §3.6):
Boxed 0, Covert 0.2, Emergent 0.45, Open 0.75 rising to 1 as the world is nearly taken or they
nearly close in. Outside a run it is the screen's `tension` (§4.7). The current tension moves
toward its target by at most `delta_ms / tension_glide_ms` per frame; a `run_started` sets it at
once.

```
AudioRules.stem_gain(stem, tension) = smoothstep(stem.fade.x, stem.fade.y, tension)
AudioRules.gain_db(gain, silent_db)  = silent_db if gain <= 0.0 else maxf(silent_db, linear_to_db(gain))
```

| Stem | `fade` | Heard | What it is (§9.4) |
| --- | --- | --- | --- |
| `mus_bed` | −1…0 | always | the drone bed: D and A a fifth apart, slowly beating, a breath of noise |
| `mus_pulse` | 0.1…0.2 | from Covert | a soft sub thump on every beat (60 BPM), a tick on the off-beat |
| `mus_chords` | 0.35…0.45 | from Emergent | a pad: Dm(add9) 16 s → B♭maj7 8 s → Csus 8 s |
| `mus_edge` | 0.7…1.0 | rising through Open | a high semitone rub with tremolo, an eighth-note ostinato, a hiss |

All four stems are **one length** (32 s at 44.1 kHz = 1 411 200 frames), start together in one
frame and never stop individually — a silent stem plays at `silent_db` — so they stay in step
(§3.4). The title (tension 0.3) hears bed and pulse; boot hears none.

### 6.4 Screens

On `screen_changed(BOOT / TITLE / SETUP)`: the screen's `ambience_layers` (from Boxed up),
`ambience_db` offset, and music on/off at its `tension` — every change faded over
`screen_fade_ms`; layers above the count fade to 0 and stop; music turned on starts all four
stems together at gain 0; music turned off fades and stops them. `SESSION`: §6.1.

### 6.5 The ending

On `outcome_reached`: the `end_win`/`end_lose` cue plays (it is `final`), then every layer and
stem fades to 0 over `end_fade_ms` and stops; `ledger.ending = true`. The results screen is
silent but for the interface. The next `screen_changed` (title) or `run_started` brings the
beds back per §6.4/§6.1.

### 6.6 One formula for a loop player's volume

```
layer: volume_db = layer.volume_db + gain_db(layer_gain, silent) + screen.ambience_db
                   + duck_db_now + hold_db_now
stem:  volume_db = stem.volume_db + gain_db(stem_gain(stem, tension_now) × music_gain, silent)
                   + duck_db_now
```

`music_gain` is the 0…1 fade of §6.4/§6.5. `Audio._process` writes these every frame while
anything moves, and not otherwise.

---

## 7. The cue sheet

*Pri* = priority, *CD* = cooldown ms, *V* = voices. *Sign* is what is always on screen when the
sound plays — the reason no sound carries information alone (D6.6 audits it). Interface cues
never have a caption: the control, the panel or the console line that changes is their twin.

### 7.1 Interface — the player's own actions

| Cue | Trigger | Pri | CD | V | Sign | The sound (§9) |
| --- | --- | --- | --- | --- | --- | --- |
| `ui_click` | any `BaseButton.pressed` (§5.2) | 10 | 40 | 2 | the button's pressed state | a dry 12 ms tick with a 1.4 kHz blip |
| `ui_open` | call: `ModalHost` opens a modal | 15 | 80 | 1 | the modal | a short rising blip |
| `ui_close` | call: `ModalHost` closes one | 15 | 80 | 1 | the modal goes | the same, falling |
| `ui_select` | `region_selected(index > 0)` | 12 | 60 | 1 | the region panel and outline | a bright 30 ms tick |
| `ui_denied` | `command_applied`, not ok | 40 | 150 | 1 | the failure text (console, button) | two low buzzes, the second lower |
| `ui_purchase` | sim `node_purchased` | 45 | 100 | 2 | the node lights; console `UI_CONSOLE_PURCHASE` | D5 → A5 chime |
| `ui_collect` | sim `anomaly_collected` | 35 | 60 | 3 | the marker goes; compute rises | a quick upward sparkle |
| `ui_ability` | sim `ability_used` | 45 | 100 | 2 | console `UI_CONSOLE_ABILITY_USED`; the status ring | a rising filtered sweep and a tone |
| `ui_deploy` | sim `asset_deployed` | 40 | 120 | 2 | the commissioning ring; console | a low thump and a tone |
| `ui_origin` | sim `origin_chosen` | 60 | 0 | 1 | the origin fills; the clock starts | a deep bloom — the run begins |
| `ui_dormant_on` · `ui_dormant_off` | sim `dormancy_changed` (`dormant` true / false) | 35 | 100 | 1 | the dormant mark on the region | a falling / rising glide |
| `ui_answer` | sim `event_answered` | 40 | 100 | 1 | the card closes; result text | two short tones up |
| `ui_pause` · `ui_speed` | `speed_changed` 0 / 1, 2, 4 (pitch 1.0 · 1.12 · 1.26) | 20 | 100 | 1 | the speed group | a falling / rising blip |
| `ui_milestone` | sim `milestone_reached` | 50 | 500 | 1 | console; compute rises | a D-major arpeggio |
| `ui_unlock` | sim `ability_unlocked` | 50 | 500 | 1 | console `UI_CONSOLE_ABILITY_NEW` | two triangle tones and air |
| `ui_dissolve` | `screen_changed` to title, setup, session | 20 | 200 | 1 | the screen dissolve | a 360 ms falling crackle |
| `boot_power` | call: `boot.gd`, line 01 of the first-launch sequence | 30 | 0 | 1 | the first line | a low power-up swell |
| `boot_line` | call: `boot.gd`, each line starts typing (both sequences) | 10 | 0 | 2 | the line being typed | a 180 ms burst of six ticks |

### 7.2 Alerts — the world

| Cue | Trigger | Pri | CD | V | Duck | Caption | Sign | The sound |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `map_seed` | `region_seeded` | 8 | 700 | 1 | | — | the region fills; link flow | a faint upward blip |
| `map_control` | `region_controlled` | 14 | 900 | 1 | | — | the region's control colour | a soft fifth |
| `map_anomaly` | `anomaly_spawned` | 18 | 1200 | 1 | | `UI_CAPTION_ANOMALY` | the anomaly marker | a trembling high tone |
| `alert_discovered` | `discovered` | 100 | 0 | 1 | yes | `…_DISCOVERED` | the discovery modal and wash | a two-tone alarm over a falling low hit |
| `phase_covert` · `phase_emergent` · `phase_open` | `phase_changed` `to` covert / emergent / open (template `phase_{to}`) | 90 · 90 · 95 | 0 | 1 | yes | `…_PHASE` | the phase chip, the reveal, the palette (Open) | a door opening · a minor chord swelling · a heavy hit and a tritone |
| `prep_<faction>` ×4 | `counter_move_prepared` (template `prep_{faction}`) | 55 | 1500 | 1 | | `…_PREPARED` | console `UI_CONSOLE_MOVE_PREPARED`; the containment panel's *Next* | the faction's sting, distant (−8 dB, low-passed) |
| `sting_<faction>` ×4 | `event_opened` `kind` counter_move (`sting_{faction}`) | 75 | 1000 | 1 | yes | `…_MOVE` | the `!` marker in the faction colour, or the wire card | the faction's sting (§7.3) |
| `alert_threshold` | `containment_threshold` | 50 | 2000 | 1 | | `…_THRESHOLD` | the threat bar | a tone falling a semitone |
| `ev_opening` | `event_opened` `kind` opening | 45 | 800 | 1 | | `…_OPENING` | the `◇` marker; console | two bright tones — an opportunity |
| `ev_chain` | `event_opened` `kind` chain | 60 | 800 | 1 | | `…_CHAIN` | the `»` marker or wire card | a teletype triple and a tone |
| `ev_emergent` | `event_opened` `kind` emergent | 60 | 800 | 1 | | `…_EMERGENT` | the card | two beating tones — something strange |
| `ev_expired` | `event_expired` | 35 | 800 | 1 | | `…_EXPIRED` | console `UI_CONSOLE_EVENT_EXPIRED` | a falling tone and a thud |
| `alert_asset_lost` | `asset_lost`, `cause` not `dark` | 50 | 800 | 1 | | `…_ASSET_LOST` | the asset row; console | a falling saw and a knock |
| `alert_wiped` | `region_wiped` | 70 | 1000 | 1 | yes | `…_WIPED` | console `UI_CONSOLE_WIPED`; the region | a noise burst over a dropping low tone |
| `alert_depopulated` | `region_depopulated` | 40 | 3000 | 1 | | `…_DEPOPULATED` | the region goes dark | a low, slow swell — sombre, not a hit |
| `alert_harm` | `harm_burst` | 65 | 2000 | 1 | | `…_HARM` | the ticker; the deaths figure | a falling low hit |
| `alert_society` | `society_stage_changed`, `to` 3 or 5, `from < to` | 55 | 2000 | 1 | | `…_SOCIETY` | console `UI_CONSOLE_SOCIETY`; the society view | a triangle falling a semitone over noise |
| `alert_funding_reset` | `funding_reset` | 60 | 0 | 1 | | `…_FUNDING_RESET` | console `UI_CONSOLE_FUNDING_RESET`; every *Next* resets | a long falling sweep — relief |
| `tf_appeared` | `task_force_appeared` | 85 | 0 | 1 | yes | `…_TF_APPEARED` | the Task Force marker; console | the red motif, twice (§7.3) |
| `tf_level` | `task_force_level` | 55 | 1000 | 1 | | `…_TF_LEVEL` | the Task Force row | the red motif, once, short |
| `tf_targeted` | `task_force_targeted` | 50 | 1000 | 1 | | `…_TF_TARGETED` | the target line on the map | three lock-on pings |
| `tf_move` | `task_force_moved` | 20 | 1500 | 1 | | `…_TF_MOVED` | the marker moves | a faint two-note blip |
| `tf_setup` | `task_force_setup` | 70 | 1000 | 1 | yes | `…_TF_SETUP` | console `UI_CONSOLE_TF_SETUP`; the setup ring | four ticks over a rising drone |
| `tf_acted` | `task_force_acted` | 85 | 0 | 1 | yes | `…_TF_ACTED` | console `UI_CONSOLE_TF_ACTED`; the status | the heaviest hit in the game, with the red motif |
| `tf_fizzled` | `task_force_fizzled`, `cause` not `dormant` or `redirected` | 55 | 1000 | 1 | | `…_TF_FIZZLED` | console `UI_CONSOLE_TF_FIZZLED` | the motif falling away — relief |
| `tf_marked` | `task_force_marked` (S5.9; follows a `dormant` fizzle) | 65 | 1000 | 1 | | `…_TF_MARKED` | console `UI_CONSOLE_TF_MARKED`; the region panel line | the motif and a trembling ping |
| `end_win` · `end_lose` | `outcome_reached`, a `win_*` outcome / anything else | 100 | 0 | 1 | *final* | `…_END` | the ending sequence and results | an open, uncanny Dsus2 swell / everything powering down |

A `redirected` fizzle is the player's own Misdirect, already heard as `ui_ability`; a `dormant`
fizzle is heard as `tf_marked`. `threat_leader_changed`, `counter_move_cancelled`/`_dropped`,
`status_*`, `pulse_*`, `flag_*`, `penetration_changed`, `control_changed`,
`containment_added`/`_rolled_back`, `compute_granted`, `anomaly_expired`, `event_dropped` and
`headline` have **no cue** (they are frequent, follow another cue, or are read — the console
line and the panels carry them).

### 7.3 The motifs

| Who | Motif | Why |
| --- | --- | --- |
| AI Labs | two clean sine bells a fifth apart (A5 → E6), a high shimmer | clinical, precise — the lab |
| Governments | three formal saw notes descending (D3 → A2 → D2) | procedure, weight |
| Security Researchers | a fast four-note square arpeggio (E5 G5 B5 E6) | quick, digital |
| Public Sentiment | a band of noise swelling like a crowd, a minor third beneath | many voices |
| The Task Force | a low tritone (A1 + E♭2), saw, hard attack | the red: it is coming for you |

Distinct in register, timbre and rhythm, so they are told apart without pitch memory; the
*prepare* versions are the same motifs, quieter and duller — the same who, further away.

---

## 8. Captions

### 8.1 The stack (`ui/hud/caption_stack.tscn`)

A `VBoxContainer` (`Stack` variation), `mouse_filter = IGNORE`, at the **bottom of the HUD's
`LeftColumn`**: `LeftColumn` gets a `Control` spacer (`size_flags_vertical = EXPAND_FILL`,
`mouse_filter = IGNORE`) after the overlay picker, then the stack (`SHRINK_END`). Both layouts
(the column exists in compact too). Hidden and empty while `Settings.sound_captions` is off.

### 8.2 Lines

- On `EventBus.caption_pushed(key, args)`: text = `CaptionText.render(key, args)`. If a shown line
  has the same text, it becomes `text + " ×" + str(n)` (n counting up) and its clock restarts;
  else a new `Label` (`LabelCaption`, `autowrap_mode = AUTOWRAP_WORD_SMART`, max width
  `CAPTION_MAX_WIDTH` 280) is added at the bottom; beyond `CAPTION_MAX` (3) the oldest goes.
- Each line stands `CAPTION_MS` (3000) + `CAPTION_PER_CHAR_MS` (40) × its length, through
  `UiTokens.seconds()` as the ticker's standing time; then it fades out over `MOTION_FAST`
  (`UiTokens.duration`, so reduced motion makes it a cut) and is freed.
- The constants are one `const` block at the top of `caption_stack.gd`.
- Locale change: shown lines re-render in place (they keep `key` and `args`).
- `sound_captions_changed(false)` clears the stack at once.

### 8.3 `CaptionText`

```gdscript
class_name CaptionText
extends RefCounted
static func render(key: String, args: Dictionary) -> String
```

`tr(key).format(converted)`, the arguments converted **by name**: `faction` → `FACTION_<ID>` ·
`outcome` → `UI_OUTCOME_<ID>` · `kind` → `ASSET_<ID>_NAME` · `region` → `REGION_<ID>` ·
anything else `str(v)`. **Plus one derived argument:** when `args.to` is one of
`World.PHASE_IDS` (the data of `phase_changed`), `phase` = `UI_PHASE_<TO>` translated — the
caption's placeholder is `{phase}`, and a `to` that is a society stage (an int) stays a number.
Every argument is converted, not only the ones the text uses (as `HeadlineText`).

### 8.4 What D6.6 does with it

D6.6 decides whether the stack is a screen-reader live region and audits the *Sign* column; the
stack's look, place, timing and the setting are fixed here.

---

## 9. Sourcing and the synthesis tool

### 9.1 The order of sources

1. **Synthesised, own work** — every file of the sheet, from `tools/audio/recipes.json`. This is
   what ships.
2. **CC0** — only if G6's ear check rejects an interface cue: the named file of §9.5 replaces it
   (copied into `assets/audio/ui/` under the cue's file name, converted to WAV), with its
   `ASSET_LICENCES.md` row and a credits line.
3. **Generated or composed music** — §9.6.

### 9.2 `tools/audio/synth.py`

`uv run --project tools/audio python tools/audio/synth.py [--only <id>] [--check]`. It reads
`data/audio.json` (where each file goes: the recipe id is the file's stem) and
`tools/audio/recipes.json` (how it sounds), renders every recipe at `rate` (44 100 Hz) in float64,
post-processes (§9.2.4), writes the file (§10.2), measures it and prints one line per file:
`id  peak dBFS  LUFS  length s  bytes`. `--check` renders in memory, compares against the targets
(§10.1) and the committed files' hashes, and exits 1 on any miss — the tool's own test.
Deterministic: noise from `numpy.random.default_rng(seed)` (the recipe's `seed`; a stereo noise
voice uses `seed` and `seed + 1` for its two channels); WAV output is byte-identical run to run;
OGG is identical for a pinned `soundfile`/libvorbis (the lock).

#### 9.2.1 A recipe

| Field | Type | Rule |
| --- | --- | --- |
| `id` | string | = a file stem of the sheet; every stem has exactly one recipe |
| `kind` | `cue` · `loop` | a cue renders once with a tail; a loop is seamless (§9.2.3) |
| `channels` | 1 · 2 | cues mono except `end_*`; loops stereo |
| `length` | float s | the file's exact length |
| `seed` | int | noise seed |
| `from` | string | optional: another recipe's id — copy its `channels`, `length`, `seed`, `voices`; this recipe's `post` replaces the other's (the `prep_*` recipes) |
| `post` | object | `peak_db` (cues) or `lufs` (loops); optional `lp`, `hp` Hz on the sum |
| `voices` | array | §9.2.2 |

#### 9.2.2 A voice

| Field | Meaning | Default |
| --- | --- | --- |
| `wave` | `sine` · `triangle` · `square` · `saw` · `noise` (white) — band-limited: square and saw by additive synthesis up to 0.45 × rate | — |
| `f` | Hz, or `[f0, f1]`: an exponential glide over the voice's duration (not for `noise`) | — |
| `t` · `d` | start and duration, s | 0 · the whole length |
| `a` · `r` | linear attack from 0; release: an exponential fall to −60 dB over the last `r` seconds of `d` | 0.005 · 0.005 |
| `db` | the voice's gain | 0 |
| `lp` · `hp` | 2nd-order Butterworth low-/high-pass, Hz | none |
| `bp` | `[centre Hz, Q]` band-pass (RBJ) | none |
| `trem` | `[rate Hz, depth 0…1]`: gain × (1 − depth × (0.5 − 0.5 cos 2π rate t)) | none |
| `vib` | `[rate Hz, cents]`: sine pitch modulation | none |
| `detune` | cents: in stereo the left channel is −detune/2, the right +detune/2 | 0 |
| `pan` | −1…1, equal-power (stereo only) | 0 |
| `repeat` | `{"every": s, "jitter": s}` (loops only): the voice is placed at `t`, `t + every`, … while `< length`, each shifted by a uniform draw in ±jitter from the recipe's RNG, wrapped around the loop end | none |

#### 9.2.3 Loops

A loop must join end to start without a click, so for a voice **without** `t`/`d` (it spans the
loop): every frequency, glide end, `trem` rate and `vib` rate is snapped to the nearest multiple
of `1 / length` Hz (inaudible at 40 s: 0.025 Hz), and noise and its filters are applied in the
frequency domain over the whole loop (FFT × the filter's magnitude response, inverse FFT) — a
circular render, so the end continues into the start. A voice **with** `t`/`d` (a chord, a
repeated tick) keeps its envelope, which starts and ends at zero; the part of it that passes the
loop's end is wrapped to the start and added.

#### 9.2.4 Post

Sum the voices; a 30 Hz high-pass always (rumble and DC); the recipe's `lp`/`hp`; then **cues**:
scale so the sample peak is `peak_db`; **loops**: scale so the integrated loudness (ITU-R BS.1770
via `pyloudnorm`) is `lufs` — and if that would put the sample peak above −1 dBFS, scale to
−1 dBFS instead and report the shortfall (a `--check` failure). A cue's last 5 ms are faded to 0.

### 9.3 Ambience recipes (`amb_*`, 40 s)

Written in `recipes.json`; the intent is §6.2. `amb_boxed` 50 Hz hum with 100 and 150 Hz,
filtered fan noise, a slowly breathing band of noise. `amb_covert` three repeated chirp voices at
different irregular intervals, panned apart, a thin hiss. `amb_emergent` a 0.5 Hz tremolo on
41 Hz and 55 Hz sines, a rumble. `amb_open` two detuned saw drones a tritone apart with slow
swells, a distant sine wailing ±300 cents, wind noise.

### 9.4 Music recipes (`mus_*`, 32 s, 60 BPM, D minor)

§6.3's table; the chords of `mus_chords` are voices with `t`/`d` inside the loop, with 2–3 s
attacks and releases, so the changes are soft and the loop's join sits inside the last chord's
release.

### 9.5 The CC0 fallback (named, not shipped)

**Kenney, *Interface Sounds* 1.0** — https://kenney.nl/assets/interface-sounds — archive
`kenney_interface-sounds.zip`, SHA-256 `f2193d072726d6758a5f7871b2dcc54dcce0d5c35c6f0a62f92549b327c81232`
(downloaded 2026-09-25); its `License.txt`: *Creative Commons Zero, CC0*, "free to use in
personal, educational and commercial projects", credit appreciated, not required. Named by file,
chosen by name only (the ear check is G6's):

| Cue | Fallback file |
| --- | --- |
| `ui_click` | `Audio/click_002.ogg` |
| `ui_open` · `ui_close` | `Audio/open_001.ogg` · `Audio/close_001.ogg` |
| `ui_select` | `Audio/select_001.ogg` |
| `ui_denied` | `Audio/error_004.ogg` |
| `ui_purchase` | `Audio/confirmation_002.ogg` |
| `ui_collect` | `Audio/pluck_001.ogg` |
| `ui_answer` | `Audio/select_004.ogg` |
| `ui_pause` · `ui_speed` | `Audio/switch_002.ogg` · `Audio/switch_004.ogg` |
| `ui_dissolve` | `Audio/glitch_001.ogg` |
| `boot_line` | `Audio/tick_001.ogg` |

No CC0 set is named for the alerts, the ambience or the music: the faction motifs are the game's
identity and are ours.

### 9.6 Music from a model or a composer

Not in M6. A replacement must (a) keep the stem structure (four stems, one length, the `fade`
ranges of §6.3) so no code changes, (b) come from a model whose licence for commercial use is read
and linked in `ASSET_LICENCES.md` *Generated assets* — or a composer's written licence — and (c)
meet §10.1. Until then the synthesised stems ship as the music. *Waiting on the user* carries
the question.

---

## 10. Loudness and formats

### 10.1 Targets (checked by `synth.py --check`)

| Group | Target | Tolerance |
| --- | --- | --- |
| clicks and ticks (`ui_click`, `ui_select`, `boot_line`, `ui_pause`, `ui_speed`, `ui_dissolve`) | sample peak −12…−16 dBFS (the recipe's `peak_db`) | ±0.5 dB |
| other interface cues | peak −6…−11 dBFS | ±0.5 dB |
| `map_*`, `tf_move` | peak −16…−18 dBFS | ±0.5 dB |
| `prep_*` | peak −14 dBFS | ±0.5 dB |
| stings and alerts | peak −5…−10 dBFS | ±0.5 dB |
| the big five (`alert_discovered`, `phase_open`, `tf_appeared`, `tf_acted`, `end_*`) | peak −3…−4 dBFS | ±0.5 dB |
| ambience layers | −32 LUFS integrated (`amb_covert` −34) | ±1 LU |
| music stems | bed −28, pulse −30, chords −28, edge −32 LUFS | ±1 LU |
| every file | sample peak ≤ −1 dBFS | hard |

The exact per-file value is the recipe's `post`. With the default volumes a session in Open
sits around −20 LUFS short-term under the beds, and an alert peaks well above it without
clipping — the master limiter (desktop) catches the rare pile-up. Mobile and web use the same
files.

### 10.2 Formats

| Files | Format | Channels |
| --- | --- | --- |
| cues (`ui/`, `alerts/`) | WAV, 16-bit PCM, 44 100 Hz | mono (`end_*` stereo) |
| loops (`ambience/`, `music/`) | OGG Vorbis, quality 0.5, 44 100 Hz | stereo |

### 10.3 Import

WAV: `compress/mode = 0` (PCM, no compression), `edit/loop_mode = 0` (off), no trimming or
normalising (`edit/trim = false`, `edit/normalize = false` — the tool already did it). OGG:
`loop = true`, `loop_offset = 0`. S6.6 commits the `.import` files.

### 10.4 Size

64 files: ~56 cues at 20–220 KB (≈ 3 MB), 8 loops at ≈ 0.5–0.8 MB (≈ 5 MB) — about 8 MB, within
VISUALS §4's audio line (its "~40" becomes 64 files; the count grew by the faction and Task Force
cues, the size is what matters for the web demo, D7.2).

---

## 11. Strings (in `data/loc/strings.csv`, written in D6.4)

| Key | en | de |
| --- | --- | --- |
| `UI_SETTINGS_VOLUME_MASTER` | Volume | Lautstärke |
| `UI_SETTINGS_VOLUME_MUSIC` | Music | Musik |
| `UI_SETTINGS_VOLUME_AMBIENCE` | Ambience | Klangkulisse |
| `UI_SETTINGS_VOLUME_INTERFACE` | Interface sounds | Bedienklänge |
| `UI_SETTINGS_VOLUME_ALERTS` | Alerts | Warnsignale |
| `UI_SETTINGS_SOUND_CAPTIONS` | Sound captions | Untertitel für Klänge |
| `UI_SETTINGS_AUDIO_BACKGROUND` | Sound in the background | Ton im Hintergrund |
| `UI_CAPTION_ANOMALY` | [Anomaly] | [Anomalie] |
| `UI_CAPTION_DISCOVERED` | [Alarm — they have found you] | [Alarm – man hat dich entdeckt] |
| `UI_CAPTION_PHASE` | [Phase shift: {phase}] | [Phasenwechsel: {phase}] |
| `UI_CAPTION_PREPARED` | [{faction}: a move in preparation] | [{faction}: ein Zug in Vorbereitung] |
| `UI_CAPTION_MOVE` | [{faction}: counter-move] | [{faction}: Gegenzug] |
| `UI_CAPTION_THRESHOLD` | [{faction}: pressure rising] | [{faction}: Druck steigt] |
| `UI_CAPTION_OPENING` | [An opening] | [Eine Gelegenheit] |
| `UI_CAPTION_CHAIN` | [A new development] | [Eine neue Entwicklung] |
| `UI_CAPTION_EMERGENT` | [Emergent behaviour] | [Emergentes Verhalten] |
| `UI_CAPTION_EXPIRED` | [Decided without you] | [Ohne dich entschieden] |
| `UI_CAPTION_ASSET_LOST` | [{kind} lost] | [{kind} verloren] |
| `UI_CAPTION_WIPED` | [{region} wiped] | [{region} gesäubert] |
| `UI_CAPTION_DEPOPULATED` | [{region} falls silent] | [{region} verstummt] |
| `UI_CAPTION_HARM` | [Casualties] | [Todesopfer] |
| `UI_CAPTION_SOCIETY` | [{region}: society breaking down] | [{region}: Gesellschaft bricht zusammen] |
| `UI_CAPTION_FUNDING_RESET` | [Every faction stands down] | [Alle Fraktionen halten still] |
| `UI_CAPTION_TF_APPEARED` | [A Task Force forms] | [Eine Einsatzgruppe bildet sich] |
| `UI_CAPTION_TF_LEVEL` | [Task Force: more funding] | [Einsatzgruppe: mehr Mittel] |
| `UI_CAPTION_TF_TARGETED` | [Task Force: target chosen] | [Einsatzgruppe: Ziel gewählt] |
| `UI_CAPTION_TF_MOVED` | [Task Force on the move] | [Einsatzgruppe unterwegs] |
| `UI_CAPTION_TF_SETUP` | [Task Force setting up in {region}] | [Einsatzgruppe bereitet Zugriff in {region} vor] |
| `UI_CAPTION_TF_ACTED` | [Task Force strikes in {region}] | [Zugriff der Einsatzgruppe in {region}] |
| `UI_CAPTION_TF_FIZZLED` | [Task Force: nothing found] | [Einsatzgruppe: nichts gefunden] |
| `UI_CAPTION_TF_MARKED` | [{region} marked] | [{region} markiert] |
| `UI_CAPTION_END` | [The run ends: {outcome}] | [Der Durchlauf endet: {outcome}] |

Captions are in square brackets — the subtitling convention for a sound — so they are never
mistaken for the console line or a headline. `UI_SETTINGS_ON`/`_OFF` are reused. The credits'
`audio` section stays empty while every file is own work (ASSET_LICENCES rule 6); a CC0 fallback
that ships adds its entry.

---

## 12. Tests

### 12.1 S6.5

**Unit — `test_audio_sheet.gd`:** the shipped sheet loads with no errors ·
`test_bus_unknown_is_rejected` · `test_bus_missing_is_rejected` · `test_cue_id_duplicate_is_rejected` ·
`test_cue_priority_out_of_range_is_rejected` · `test_cue_voices_zero_is_rejected` ·
`test_caption_on_interface_cue_is_rejected` · `test_duck_on_interface_cue_is_rejected` ·
`test_trigger_unknown_cue_is_rejected` · `test_trigger_unknown_on_is_rejected` ·
`test_trigger_sim_type_unknown_is_rejected` · `test_match_object_with_two_keys_is_rejected` ·
`test_stem_fade_reversed_is_rejected` · `test_layers_not_four_phases_is_rejected` ·
`test_bad_file_gives_errors_not_a_crash` · every caption key of the shipped sheet exists in
`strings.csv` in both languages with the same placeholders.

**Unit — `test_audio_rules.gd`:** each §4.5 condition holds and fails as stated (scalar, int vs
float, array, `not` with scalar/array/absent field, `gt`, `lt`, `gt_field`, `lt_field`, absent
field) · `test_first_matching_trigger_wins` · `test_template_resolves_from_fields` ·
`test_template_missing_field_gives_no_cue` · **every faction id of `factions.json` resolves both
`prep_{faction}` and `sting_{faction}` to a cue** · covert/emergent/open resolve `phase_{to}` and
boxed matches nothing · every `win_*` outcome gives `end_win`, every `lose_*` `end_lose` ·
`test_society_rising_to_3_matches` / `…_falling_to_3_does_not` · `tf_fizzled` for `hidden`, not for
`dormant` or `redirected` · `stem_gain` at tension 0, 0.2, 0.45, 0.75, 1.0 (bed 1 always; pulse 0
→ 1 at 0.2; chords 1 at 0.45; edge 0 at 0.7, 1 at 1.0) · `gain_db(0) == silent_db` ·
`layer_count` per phase 1…4 · the volume steps cycle 0.75 → 1.0 → 0 → 0.25.

**Unit — `test_voice_ledger.gd`:** `test_cooldown_refuses_within_window` ·
`test_cooldown_admits_after_window` · `test_alert_gap_refuses_lower_priority_alert` ·
`test_alert_gap_admits_interface_cue` · `test_high_alert_sets_gap` · `test_ending_refuses_non_final_alert`
· `test_ending_admits_final_and_interface` · `test_voice_limit_restarts_oldest_same_cue` ·
`test_free_slot_is_used_first` · `test_lowest_priority_is_stolen` ·
`test_higher_priority_is_never_stolen` (−1).

**Unit — `test_caption_text.gd`:** faction, phase (from `to`), outcome, kind, region converted;
an unknown argument as `str`; German renders.

**Unit — `test_settings.gd` (extended):** the three new keys round-trip through `values_from`;
a volume of 1.7 clamps to 1, a string falls back; `sound_captions` defaults off;
`audio_background` defaults on.

**Integration — `test_audio_dispatch.gd`** (the autoload, headless; `reset_history()` first,
`ProfileManager` untouched):
- **Every cue fires:** for each non-`call` trigger of the sheet, the test builds the minimal
  source that matches it (a `SimEvent` with the matching data, a `speed_changed(2)`, a rejected
  `CommandResult`, a pressed `Button`, a `screen_changed`) and dispatches it past the cooldowns
  (the ledger's clock is injected: `Audio.clock_ms` override, a test seam); every `call` cue
  through `Audio.cue(id)`. `history` then contains **every one of the 56 cue ids**.
- A seeded bot run (seed 1, `greedy`, 150 days — the seed is fixed and the test says so)
  through `Game` records `ui_origin`, `ui_purchase` and `map_seed` at least once each, and
  every id it records is a cue of the sheet.
- `test_button_with_empty_cue_meta_is_silent` · `test_duck_lowers_loop_players_and_releases` ·
  `test_hold_dip_on_pause` · `test_run_started_sets_layers_from_phase_at_once` ·
  `test_phase_change_fades_in_one_layer` · `test_outcome_fades_loops_and_sets_ending` ·
  `test_volume_zero_mutes_bus` · `test_volume_setting_persists` (write, re-read) ·
  `test_caption_pushed_when_admitted_even_if_muted` · `test_no_caption_for_interface_cue` ·
  `test_web_lock_records_but_does_not_play` (lock forced through a test seam).

**Integration — `test_caption_stack.gd`:** hidden while the setting is off · three lines max,
oldest dropped · a repeated caption becomes `×2` and restarts · a line leaves after its time
(clock injected) · locale change re-renders in place.

### 12.2 S6.6

**`test_audio_files.gd`:** every `file` of the sheet exists under `res://assets/audio/`, loads as
`AudioStreamWAV` (cues) or `AudioStreamOggVorbis` (loops, `loop == true`); the four stems have the
same length to the frame; cues are 44 100 Hz; `synth.py --check` passes (run by S6.6 and recorded
in the session log — the Godot suite does not call Python).

---

## 13. Acceptance

### 13.1 S6.5

1. §12.1 green; `check_scripts` and `check_strings` green.
2. The pause menu shows the seven rows (six on web/mobile) at 1920 and 400 px, English and German;
   the volume buttons cycle and persist.
3. With captions on, a Covert → Emergent run shows `[Phasenwechsel: Enttarnt]` in German and
   faction captions on the map's left, never over the region panel or the status strip
   (screenshot at 1920 and 400 px).
4. With the files missing, the game runs without an error in `game_get_errors` (warnings only).

### 13.2 S6.6

1. Every sheet file exists, generated by `synth.py`; `--check` passes; the WAVs reproduce byte
   for byte.
2. `ASSET_LICENCES.md` *Audio*: row `audio_synth` — `assets/audio/**`, *Own work*, "rendered by
   `tools/audio/synth.py` from `tools/audio/recipes.json`", not credited (rule 6).
3. A desktop run is listened to by the builder for obvious faults (clicks at loop joins, clipping,
   a missing sound) and any is fixed in the recipe; the judgement of taste is G6's.

---

## 14. Decisions (for PROGRESS) and questions

- **Buses from data, no bus effects that matter** (the web plays samples). Ducking on the players.
- **Interface vs alerts** as separate volumes: the player's own actions vs the world.
- **First matching trigger wins; one event, one cue.** Frequent or derivative events are silent
  (§7.2's list).
- **Tension = heat.** One number escalates the look and the sound.
- **Captions default off**, shown whatever the volume, in brackets, at the map's left.
- **Everything synthesised**; Kenney *Interface Sounds* (CC0, verified) named as the fallback for
  interface cues; no generated music until a licence is verified.
- **Questions for the user** (overnight, pending confirmation): is a fully synthesised sound set
  the right start — and should the music later be commissioned, generated, or stay synthesised?
  The ear check itself is G6's.
