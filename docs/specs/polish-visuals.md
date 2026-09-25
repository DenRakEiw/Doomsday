# Polish: the screen pass, the phase variants, the map (D6.1)

**Status:** design, 2026-09-25 (D6.1). Build steps: **S6.1** (§2–§7: the pass, its triggers, the
settings, the flash limits) and **S6.2** (§8–§10: the Open palette correction, the map's coast
and outline pass, the Societal Function overlay).
**Read with:** `ui-foundation.md` §3 (tokens), §3.5 (layers), §7 (the map) · `m3-screens.md` §5
(the discovery flash), §6 (phase reveal, the `open` set) · VISUALS §2 · UI §5.
**Answers:** UI q3 and VISUALS q3 (§8) · the parked border note of *Design questions* (§9) ·
the Societal Function overlay, left open by `opposition.md` §1 (§10).

---

## 0. What this spec decides

1. **One full-screen pass**, a `CanvasLayer` at 1025 owned by a new autoload `ScreenFx`, one
   fragment shader, eight stages in a fixed order: chromatic aberration → bloom → alert wash →
   vignette → scanlines → grain → ordered dither → dissolve. No `WorldEnvironment`, no
   `BackBufferCopy` chain, no second pass, no compute — web-safe by construction.
2. **Heat**: one number (0…1) that the phase and the endgame drive, and that scales grain,
   scanlines, bloom and dither. This is where the late game escalates — **not** in a third palette.
3. **Two settings, independent:** *Reduced motion* (existing) switches off everything that moves
   (§5.2); the new *Screen effects* (`Off` · `Subtle` · `Full`) scales everything that decorates.
   Neither ever hides information: the alert wash and the dissolve are not decoration (§5.1).
4. **Flash limits** (§6): at most three full-screen flashes in any one second, no saturated-red
   flash, no looping effect faster than 2 Hz — enforced by one `FlashLimiter` that every
   full-screen luminance change passes through.
5. **Phase variants** (§8): the cap of D3.3 stands — **one** palette change (`cold` → `open`).
   The Task Force's red stays a mark, never a palette. But the Open accent collides with the
   Governments' orange (worst-case ΔE 5); the Open accent family moves to pale amber.
6. **Map** (§9): the staircase is the coast (the ID map clips the anti-aliased land mask) and the
   tap-built outlines, not the inner borders. Fixed by a **coast pass** and **mask-built outlines**
   in `map.gdshader`; the 2× ID map is rejected.
7. **The Societal Function overlay is built** (§10): a fourth map view, stepped by stage, from
   Emergent on.

---

## 1. Scope

**In:** the pass (shader, autoload, uniforms, constants, cost); what triggers it (impulses, the
alert wash moved into it, the screen dissolve, heat); the *Screen effects* setting; the reduced
motion table for the whole game; the photosensitivity rules and their guard; the Open accent
correction and the colour floor; the coast pass and the mask-built outlines; the society overlay
(data row, shader branch, picker, strings); tests; acceptance.

**Out:** CRT curvature (cut — §3.3); per-layer effects (the pass sees one flattened frame);
illustration treatment (D6.7); audio and captions (D6.4, D6.6); icons (D6.2); performance budgets
beyond recording the pass's cost (D6.8, S6.11); screen-reader work (D6.6); a legend for the map
views (none exists for the other three either).

| Step | Sections |
| --- | --- |
| **S6.1 Post-processing pass** | §2, §3, §4, §5, §6, §7 (its strings), §11 (its tests), §12.1 |
| **S6.2 Phase variants and map polish** | §2 (its rows), §8, §9, §10, §7 (its strings), §11 (its tests), §12.2 |

---

## 2. Files

| File | Step | What |
| --- | --- | --- |
| `game/autoload/screen_fx.gd` | S6.1 | **new autoload** `ScreenFx` (`extends CanvasLayer`, no `class_name`); registered **last** in `project.godot` (it connects to `ScreenRouter`) |
| `ui/fx/screen_fx.gdshader` | S6.1 | the pass (`canvas_item`, `hint_screen_texture`) |
| `ui/fx/screen_fx_rules.gd` | S6.1 | `class_name ScreenFxRules` — pure static rules: heat, parameters, impulses |
| `ui/fx/screen_fx_params.gd` | S6.1 | `class_name ScreenFxParams` — the typed result of `ScreenFxRules.params` |
| `ui/fx/flash_limiter.gd` | S6.1 | `class_name FlashLimiter` — §6's guard |
| `ui/theme/ui_tokens.gd` | S6.1, S6.2 | the `FX_*` tokens (§3.5), `MOTION_DISSOLVE`, `MOTION_HEAT`; S6.2: `OPEN` accent rows (§8.2), `MAP_SOCIETY`, the outline tokens (§9) |
| `game/autoload/settings.gd` | S6.1 | `screen_effects` (§5.1) |
| `game/autoload/event_bus.gd` | S6.1 | `signal screen_effects_changed(intensity: float)` |
| `game/autoload/screen_router.gd` | S6.1 | `_fade_in` replaced by `ScreenFx.dissolve_in()` (§4.3) |
| `ui/modals/modal_host.gd` | S6.1 | `flash_alert()` delegates to `ScreenFx.flash_alert()`; its own `_alert` `ColorRect` goes |
| `ui/modals/pause_menu.gd` | S6.1 | the *Screen effects* row (§5.1) |
| `game/session/session.gd` | S6.1 | debug key **V** cycles the intensity |
| `ui/dev/gallery.gd` | S6.1 | key **V** as well, so every component is reviewed under the pass |
| `game/map/map.gdshader` | S6.2 | coast pass, mask-built outlines (§9), `OVERLAY_SOCIETY` (§10) |
| `game/map/map_view.gd` | S6.2 | `Overlay.SOCIETY`, `smooth_outline` uniform, `map_society` colour |
| `game/map/map_camera.gd` | S6.2 | tells the view whether the outline is smooth (§9.3) |
| `game/map/region_data.gd` | S6.2 | third row (`ROW_SOCIETY`, §10.1) |
| `ui/hud/overlay_picker.gd` | S6.2 | fourth mode (§10.3) |
| `data/loc/strings.csv` | D6.1 | §7 (done) |

---

## 3. The pass

### 3.1 The node

`ScreenFx._ready()` builds, in script: `layer = UiTokens.FX_LAYER` (1025 — the inspector caps
the field at 128, and `Window` popups draw at 1024, VISUALS §2); one child `ColorRect`, full rect
(anchors preset 15), `mouse_filter = MOUSE_FILTER_IGNORE`, a `ShaderMaterial` with
`screen_fx.gdshader`. The `ColorRect` is **hidden** whenever `ScreenFxParams.enabled` is false
and no wash or dissolve is running (§5.1) — a hidden pass costs nothing, not even the screen
copy.

It sits above everything: boot, title, setup, session, every modal, tooltips. Screenshots
(`F12`, godot-mcp) include it, because they read the viewport's texture.

### 3.2 Uniforms

Everything is set from `ScreenFx` through `ScreenFxParams`; the shader carries no literal colour
and no tunable number except the two fixed matrices (4 × 4 and 8 × 8 Bayer, textbook values).

| Uniform | Type | Source |
| --- | --- | --- |
| `screen` | `sampler2D : hint_screen_texture, filter_linear, repeat_disable` | — |
| `px_scale` | `float` | `min(viewport_px.x, viewport_px.y) / FX_REFERENCE_HEIGHT`, on `size_changed` |
| `ca_px` | `float` | §4.1, per frame while > 0 |
| `bloom_strength` | `float` | params |
| `bloom_taps` | `int` | params: 0, 8 or 16 |
| `bloom_radii` | `vec2` | `FX_BLOOM_RADII` |
| `bloom_key` | `vec2` | `FX_BLOOM_KEY` |
| `wash` | `vec4` | `ALERT` rgb, alpha animated (§4.2) |
| `vignette` | `float` | params |
| `vignette_start` | `float` | `FX_VIGNETTE_START` |
| `scan_depth` | `float` | params |
| `scan_period` | `int` | `max(2, round(FX_SCANLINE_PERIOD × px_scale))` |
| `grain_amp` | `float` | params |
| `grain_fps` | `float` | `FX_GRAIN_FPS` |
| `dither_levels` | `float` | params |
| `dissolve` | `float` | §4.3, 0 = none, 1 = all ground |
| `dissolve_cell` | `float` | `FX_DISSOLVE_CELL × px_scale` |
| `ground` | `vec4` | `UiTokens.color(&"BG_0")` (variant-aware; re-sent on `theme_variant_changed`) |

### 3.3 The stages, in order

Per fragment; `p = FRAGCOORD.xy` (physical pixels), `uv = SCREEN_UV`, `px = SCREEN_PIXEL_SIZE`.

1. **Chromatic aberration** (alerts only). `ca_px > 0`: `d = normalize(uv − 0.5 + ε) × ca_px ×
   px_scale × px`; `c = (texture(screen, uv + d).r, texture(screen, uv).g, texture(screen, uv −
   d).b)`. Else one tap. Radial, so the centre of the screen stays sharp and the edges tear.
2. **Bloom — keyed on chroma, not luminance.** For each of `bloom_taps` taps on two rings (8 at
   `bloom_radii.x` px, 8 more at `bloom_radii.y` px rotated by 22.5°, both × `px_scale`):
   `s = tap.rgb × smoothstep(bloom_key.x, bloom_key.y, max(tap) − min(tap)) × max(tap)`;
   `c += bloom_strength × Σ s / bloom_taps`. **Why chroma:** our text is near-grey (`TEXT_0`
   chroma 0.07) and must never glow; the accent (0.56), `ALERT` (0.77), the ramp and the
   categorical colours are the signals, and they are what glows. The map's fills at
   `MAP_OVERLAY_MIX` sit around 0.4 and barely glow — the overlay does not bloom into a haze.
3. **Alert wash.** `c = mix(c, wash.rgb, wash.a)`.
4. **Vignette.** `r = length((uv − 0.5) × vec2(aspect, 1)) / length(vec2(aspect, 1) × 0.5)`;
   `c *= 1 − vignette × smoothstep(vignette_start, 1.0, r)`. Static.
5. **Scanlines.** `c *= (int(p.y) % scan_period == 0) ? 1 − scan_depth : 1`. One dark row per
   period, static — no roll, no flicker (flicker is cut outright: it is the effect UI §5 warns
   about and it buys nothing a static line does not).
6. **Grain.** `n = hash(floor(p), floor(TIME × grain_fps))` in [0, 1); `c += (n − 0.5) × 2 ×
   grain_amp`, the same on r, g and b (luminance grain; coloured grain reads as a defect on text).
   The hash is any in-house integer hash (a PCG or xxHash-style mix written from its
   description); nothing is copied from a shader site.
7. **Ordered dither.** `c = floor(c × (dither_levels − 1) + bayer4(p)) / (dither_levels − 1)`,
   `bayer4` in [0, 1). Mean-preserving, so it changes no contrast (§8.4). At 64 levels it only
   de-bands the gradients (bloom, vignette, wash); at 20 the panels get the console grain VISUALS
   §2 asks for.
8. **Dissolve.** `bayer8(floor(p / dissolve_cell)) < dissolve` → `c = ground.rgb`.

`COLOR = vec4(clamp(c, 0, 1), 1)`.

**Cut: CRT curvature.** VISUALS §2 lists it; it is cut. A curved image moves every control away
from where it is hit-tested (the pass cannot move the input with it), and it bends the one thing
this interface lives on — straight lines of type. The vignette carries the "screen" feel instead.

### 3.4 Cost

| Stage | Texture fetches per pixel | Notes |
| --- | --- | --- |
| base / CA | 1 / 3 | CA only while an impulse decays |
| bloom | 0 · 8 · 16 | `Subtle` 8, `Full` 16 |
| the rest | 0 | ALU only |

Worst case 19 fetches per pixel plus one full-screen copy — at 1920 × 1080 about 40 M fetches a
frame, trivial on desktop, the reason `Subtle` (9 fetches) is the default on phones and the web
(§5.1). `uniform`-only branches (`bloom_taps`, `ca_px > 0`) are coherent across the screen and
cost nothing on GLES3/WebGL2. **S6.1 records** the frame time at 1920 × 1080 with the pass
`Off` / `Subtle` / `Full` (`Performance.TIME_PROCESS` and the frame time, mean of 600 frames on
the title) in a new *Performance notes* section of `PROGRESS.md`, after *Balance baselines*;
S6.11 judges it against D6.8's budget.

### 3.5 Tokens (`UiTokens`, a new `# §FX` block)

| Token | Value | Use |
| --- | --- | --- |
| `FX_LAYER` | 1025 | §3.1 |
| `FX_INTENSITIES` | `[0.0, 0.5, 1.0]` | the setting's steps (§5.1) |
| `FX_INTENSITY_DESKTOP` · `FX_INTENSITY_HANDHELD` | 1.0 · 0.5 | defaults (§5.1) |
| `FX_REFERENCE_HEIGHT` | 1080.0 | `px_scale` |
| `FX_SCANLINE_PERIOD` | 3 | px at scale 1 |
| `FX_SCANLINE_DEPTH` | 0.08 | darkening of the dark row at full |
| `FX_GRAIN_AMP` | 0.035 | ± amplitude at full |
| `FX_GRAIN_FPS` | 24.0 | grain re-seeds per second |
| `FX_VIGNETTE` | 0.08 | corner darkening at full |
| `FX_VIGNETTE_START` | 0.6 | share of the half-diagonal where it begins |
| `FX_BLOOM_STRENGTH` | 0.30 | at full |
| `FX_BLOOM_KEY` | `Vector2(0.45, 0.80)` | chroma smoothstep |
| `FX_BLOOM_RADII` | `Vector2(4.0, 9.0)` | px at scale 1 |
| `FX_DITHER_LEVELS` | `Vector2(64.0, 20.0)` | levels per channel: clean → hot |
| `FX_CA_PX` | 5.0 | CA offset at impulse 1, px at scale 1 |
| `FX_CA_DECAY` | 250 | ms, e-folding time of an impulse |
| `FX_CA_FLOOR` | 0.02 | below this the impulse is 0 (and CA stops) |
| `FX_IMPULSE_COOLDOWN` | 2000 | ms between two impulses |
| `FX_HEAT_PHASE` | `Dictionary[World.Phase, float]` BOXED 0.0 · COVERT 0.2 · EMERGENT 0.45 · OPEN 0.75 | §3.6 |
| `FX_HEAT_ENDGAME` | `Vector2(0.25, 0.75)` | smoothstep range of §3.6 |
| `FX_HEAT_SCREEN` | `Dictionary[StringName, float]` `&"boot"` 0.5 · `&"title"` 0.3 · `&"setup"` 0.3 | heat outside a run |
| `FX_DISSOLVE_CELL` | 4.0 | px at scale 1 |
| `MOTION_DISSOLVE` | 360 | ms; `duration()` applies (reduced motion → cut) |
| `MOTION_HEAT` | 2000 | ms; `duration()` applies |
| `FLASH_WINDOW` · `FLASH_MAX` · `FLASH_MIN_GAP` | 1000 · 3 · 334 | ms · count · ms (§6) |

### 3.6 Heat

```
ScreenFxRules.endgame(world, db) = max(world.max_containment(),
                                       controlled_count(db) / max(1, live regions))
                                   # live = regions − 1 − dark_count(); both ends of the run count:
                                   # the world nearly taken, or them nearly closing in
ScreenFxRules.heat(phase, endgame) =
    FX_HEAT_PHASE[phase]                                              if phase != OPEN
    FX_HEAT_PHASE[OPEN] + (1 − FX_HEAT_PHASE[OPEN])
        × smoothstep(FX_HEAT_ENDGAME.x, FX_HEAT_ENDGAME.y, endgame)   if phase == OPEN
```

`ScreenFx` recomputes it on `run_started` (instant) and on every `tick_advanced` (a change tweens
over `MOTION_HEAT`; the endgame term moves slowly anyway). Outside the session it is
`FX_HEAT_SCREEN[screen]` on `ScreenRouter.screen_changed` (`ScreenFx` maps `Screen.BOOT` /
`TITLE` / `SETUP` to `&"boot"` / `&"title"` / `&"setup"`; `SESSION` hands over to the run's heat,
and before `run_started` arrives it is Boxed's 0). A new run starts at Boxed's 0 —
clinical, as VISUALS §2 has it — and a loaded run at its phase's heat, at once.

### 3.7 Parameters

```
ScreenFxRules.params(intensity: float, heat: float, reduced_motion: bool) -> ScreenFxParams
    enabled        = intensity > 0
    scan_depth     = reduced_motion ? 0 : FX_SCANLINE_DEPTH × intensity × (0.5 + 0.5 × heat)
    grain_amp      = reduced_motion ? 0 : FX_GRAIN_AMP × intensity × (0.25 + 0.75 × heat)
    vignette       = FX_VIGNETTE × intensity
    bloom_strength = FX_BLOOM_STRENGTH × intensity × (0.5 + 0.5 × heat)
    bloom_taps     = intensity >= 1 ? 16 : (intensity > 0 ? 8 : 0)
    dither_levels  = lerp(FX_DITHER_LEVELS.x, FX_DITHER_LEVELS.y, heat × intensity)
    ca_scale       = reduced_motion ? 0 : intensity     # multiplies FX_CA_PX (§4.1)
```

`ScreenFxParams` (`RefCounted`): `var enabled: bool`, `var scan_depth: float`, `var grain_amp:
float`, `var vignette: float`, `var bloom_strength: float`, `var bloom_taps: int`, `var
dither_levels: float`, `var ca_scale: float`. `ScreenFx` re-derives it on `run_started`,
`tick_advanced` (heat), `screen_changed`, `reduced_motion_changed`, `screen_effects_changed`.

---

## 4. Triggers

### 4.1 Impulses (chromatic aberration)

`ScreenFx.impulse(strength: float) -> void`: if the last accepted impulse is younger than
`FX_IMPULSE_COOLDOWN`, ignore it — unless `strength` is larger than what is still decaying, in
which case it replaces it without restarting the cooldown. Else `a = strength`. Each frame
`a *= exp(−delta_ms / FX_CA_DECAY)`, `0` below `FX_CA_FLOOR`; `ca_px = FX_CA_PX × a ×
params.ca_scale`. With reduced motion or `Off` nothing is drawn (`ca_scale` 0).

`ScreenFx` listens to `EventBus.sim_event` itself — nothing calls it for these — and asks
`ScreenFxRules.impulse_for(event: SimEvent, db: ContentDB) -> float`:

| Event | Strength | Why |
| --- | --- | --- |
| `discovered` | 1.0 | the moment they find you (with the wash, §4.2) |
| `phase_changed` with `to == "open"` | 1.0 | the frame tears as the palette turns (m3-screens §6.2 keeps the swap instant) |
| `outcome_reached`, a `LOSE_*` outcome | 1.0 | |
| `outcome_reached`, a `WIN_*` outcome | 0.5 | |
| `task_force_acted` | 0.6 | the hunt landed |
| `region_wiped` | 0.5 | a shutdown took a region's share |
| `event_opened` whose `EventDef.kind == "counter_move"` | 0.4 | a faction struck |
| anything else | 0 | |

Bot runs get impulses too (they are watched); the cooldown keeps 4× speed from turning into a
permanent smear. A load emits no events, so it triggers nothing.

### 4.2 The alert wash (moved)

m3-screens §5 item 2's red wash moves from `ModalHost` into the pass (the `wash` uniform), so that
every full-screen luminance change goes through one place. `ModalHost.flash_alert()` keeps its
name and calls `ScreenFx.flash_alert()`; the session is unchanged. `flash_alert()`: skip under
reduced motion (as today); ask `FlashLimiter.allow(now)` — refused → skip; else `wash =
(ALERT, ALERT_FLASH_ALPHA)` tweening its alpha to 0 over `MOTION_ALERT` (`EASE_OUT` /
`TRANS_CUBIC`). **The wash ignores the intensity setting** — it is the discovery moment, not
decoration; the pass becomes visible for its duration even at `Off`.

### 4.3 The screen dissolve

`ScreenRouter._swap` calls `ScreenFx.dissolve_in()` where it called `_fade_in` (which goes,
with its modulate fade). `dissolve_in()`: `dissolve = 1` (the whole frame is ground), then a
linear tween to 0 over `MOTION_DISSOLVE`; the new screen appears through the dither cells.
Reduced motion: `dissolve` stays 0 (a cut). Like the wash, it ignores the intensity setting and
shows the pass while it runs. No snapshot of the old screen is taken — the old screen is simply
gone in the same frame, so the dissolve is *from the void*, which is also the console's voice
(the boot sequence starts from the same ground). A dissolve is one transition, not a flash pair
(§6), so it does not ask the limiter.

**Not dissolved:** modals (they keep `MOTION_MODAL`), the Open palette swap (§4.1), the results
screen (a modal), the ending push-in (its own camera move).

---

## 5. The settings

### 5.1 Screen effects

`Settings.screen_effects: float`, key `"screen_effects"` in `settings.json` (settings version stays
1: a missing key falls back on its own, like every key since S4.9). Values are the steps of
`UiTokens.FX_INTENSITIES`; a stored value that is not a number falls back to the default; a
number between steps is kept and the rules clamp it to 0…1.

- Default: `Settings.default_screen_effects() -> float` = `FX_INTENSITY_HANDHELD` when
  `OS.has_feature("mobile")` or `OS.has_feature("web")`, else `FX_INTENSITY_DESKTOP`.
- `set_screen_effects(value: float) -> void` (write, emit `EventBus.screen_effects_changed`),
  `cycle_screen_effects() -> void` (next step up, after the largest the smallest — as
  `cycle_text_scale`).
- **Settings row** in the pause menu (title and session), **directly after *Reduced motion***:
  label `UI_SETTINGS_SCREEN_EFFECTS`; the button says `UI_SETTINGS_OFF` (0), `UI_SETTINGS_FX_SUBTLE`
  (0.5) or `UI_SETTINGS_FX_FULL` (1.0) and cycles on press. (The menu indexes its buttons by
  position: `INDEX_BOOT` and friends shift by one.)
- Debug key **V** in the session and the gallery calls `cycle_screen_effects()`.

| | Off | Subtle | Full |
| --- | --- | --- | --- |
| scanlines, grain, vignette, bloom, dither | none (the pass is hidden) | half strength, 8-tap bloom | full |
| CA impulses | none | half offset | full |
| alert wash, dissolve | **shown** | shown | shown |

### 5.2 Reduced motion — the whole table

Reduced motion switches off what **moves**; *Screen effects* scales what **decorates**. The two
are independent: a player may want the grain and no motion, or motion and a clean screen.

| Effect | Normal | Reduced motion | Where decided |
| --- | --- | --- | --- |
| scanlines | static rows | **off** (UI §5 names them; on a panning map they shimmer) | here |
| grain | 24 re-seeds a second | **off** (static noise reads as dirt) | here |
| chromatic aberration | impulses | **off** | here |
| dissolve between screens | 360 ms | cut | here |
| heat changes | 2 s tween | instant | here |
| bloom, vignette, dither | static | unchanged | here |
| alert wash | 600 ms fade | skipped | m3-screens §5 |
| every `MOTION_*` duration | as tokens | 0 (`UiTokens.duration`) | ui-foundation §3.4 |
| anomaly ring, link flow, backdrop parallax, ticker scroll | moving | static | ui-foundation §3.4, §7.6–7.8 |
| Boxed pulse, reveal border flash | moving | static accent / appears | m3-screens §6.1, §6.5 |

---

## 6. Photosensitivity limits

The rules follow WCAG 2.2 §2.3.1 (*three flashes or below threshold*) and are stricter where that
is free.

1. **Three flashes a second, full screen.** A *flash* is any full-screen change of mean relative
   luminance of 10 % or more that reverses. Every such change asks `FlashLimiter.allow(now_ms)`:
   refused when an accepted one is younger than `FLASH_MIN_GAP` (334 ms) or three were accepted
   in the last `FLASH_WINDOW` (1000 ms). Today only the alert wash asks; any later full-screen
   effect **must** go through `ScreenFx` and ask too.
2. **No saturated-red flash.** WCAG's red-flash rule concerns saturated red (R / (R + G + B) ≥
   0.8). The wash at `ALERT_FLASH_ALPHA` 0.25 over `BG_2` is ≈ 0.53 — not saturated red, and its
   luminance change (≈ 0.02 relative luminance) is far under the 10 % threshold as well. **`ALERT_FLASH_ALPHA` may not
   exceed 0.25**; a test guards it.
3. **No loop faster than 2 Hz.** No looping animation of any size has a period under 500 ms; a
   test reads every `UiTokens` constant whose name ends in `_PERIOD` and checks ≥ 500 (today:
   `PULSE_PERIOD` 1600, `ANOMALY_PULSE_PERIOD` 1200, `TICKER_STATIC_PERIOD` 4000). The last-days
   red blink of M2 is already gone (G3).
4. **Grain is not a flash:** its amplitude (≤ 0.035) is far below 10 %. **Chromatic aberration is
   not a luminance change** (it displaces), and its cooldown limits it to one start per 2 s.
5. **Reduced motion** removes every moving effect of the pass (§5.2).

**Audit of what exists (2026-09-25):** the discovery wash (single, guarded from S6.1 on), the
reveal border flash, the value flash (`MOTION_FLASH`), the tech-node flash, the faction rollback
flash, the scope flash (`MOTION_SCOPE_FLASH`) — all element-sized, single, not looping; the Boxed
pulse 0.63 Hz, the anomaly ring 0.83 Hz, the event-marker pulse — small and slow; the ticker and
link flow — motion, not flashes. **Nothing breaks the rules; nothing needs to change** beyond
routing the wash.

---

## 7. Strings (in `data/loc/strings.csv`, written in D6.1)

| Key | en | de |
| --- | --- | --- |
| `UI_SETTINGS_SCREEN_EFFECTS` | Screen effects | Bildschirmeffekte |
| `UI_SETTINGS_FX_SUBTLE` | Subtle | Dezent |
| `UI_SETTINGS_FX_FULL` | Full | Voll |
| `UI_TERM_SOCIETY` | Society | Gesellschaft |

`Off` reuses `UI_SETTINGS_OFF`. `UI_TERM_SOCIETY` is the picker's fourth button (§10.3); the
region panel keeps `UI_REGION_SOCIETY` for its row.

---

## 8. Phase variants — UI q3 and VISUALS q3

### 8.1 The answer

*How far does the phase palette go before it stops being atmosphere and starts being unreadable?*
**One step, and no further.** The cap of D3.3 (m3-screens §6) stands: **two token sets**, `cold`
for Boxed/Covert/Emergent and `open` for Open, swapped once, instantly.

- **No late-game token set.** The escalation after Open is the pass's **heat** (§3.6): more grain,
  harder dither, stronger scanlines and glow as the world is nearly taken or nearly contained.
  Heat changes no token, so the contrast floor cannot erode with it (§8.4) — atmosphere without a
  third palette to audit, and the Open swap stays the one moment the frame changes colour.
- **The Task Force's red is not a variant.** It stays what G5 (1/3) made it: the token
  `TASK_FORCE` (= `ALERT`) on the Task Force's own marks — markers, rings, the map's status slot 6,
  chips. The chrome never turns red: red means *now*, and a red interface would mean *always*.
- **Tested at reduced motion:** with motion off the Open player still gets the palette swap (it
  was always instant) and the static part of heat — dither and bloom; only grain and scanlines go.

### 8.2 The correction: the Open accent

Auditing the two sets against the data colours (§8.3) found one collision: the Open `ACCENT`
`#FFB35C` against the Governments' `CAT_ORANGE` `#E69F00` — ΔE₀₀ 9.1 for normal vision, **5.3**
worst case under simulated dichromacy. In Open, the player's own status rings, links and
anomalies would read as the Governments'. The Open accent family moves to **pale amber** — still
hot against the maroon ground, clear of the orange by lightness:

| Token | open before | **open now** | on `BG_2` | note |
| --- | --- | --- | --- | --- |
| `ACCENT` | `#FFB35C` | **`#FFD08A`** | 12.9 : 1 | `INK` on it 14.0 : 1; vs `CAT_ORANGE` worst ΔE 13.4 |
| `ACCENT_DIM` | `#8F5E2A` | **`#8C6A3A`** | 3.7 : 1 | on `MAP_LAND` 3.3 : 1 (cold's is 2.7) |
| `ACCENT_HOVER` | `#FFC985` | **`#FFE0B0`** | 14.5 : 1 | |
| `ACCENT_PRESSED` | `#E39A46` | **`#E8B66C`** | 9.9 : 1 | `INK` on it 10.9 : 1 |

Every other row of m3-screens §6.2 is unchanged. `STAT_FOOTPRINT` keeps what the code does today.

### 8.3 The colour floor

**Rule:** two colours that can appear side by side **in the same map channel** (a ring, a border,
a marker, a line) keep a worst-case CIEDE2000 of **≥ 9** over normal vision and the three
simulated dichromacies (Machado 2009, severity 1.0) — and, as always, a glyph or a value as the
second channel (UI §5). The 9 is where the existing, accepted pairs sit; it is a sanity floor that
catches near-identical pairs, not a licence for colour alone.

| Pair (worst-case ΔE₀₀) | cold | open (after §8.2) |
| --- | --- | --- |
| `ACCENT` vs `CAT_SKY` (AI labs) | 10.5 | 44 |
| `ACCENT` vs `CAT_ORANGE` (Governments) | 45.8 | 13.4 (was 5.3) |
| `ACCENT` vs `CAT_GREEN` (Researchers) | 21.0 | 20 |
| `ACCENT` vs `CAT_PINK` (Public) | 18.5 | 19 |
| `ACCENT` vs `TASK_FORCE` | 47.7 | 19 |
| `TASK_FORCE` vs `CAT_ORANGE` | 9.8 | 9.8 |
| `TASK_FORCE` vs `CAT_PINK` | 17.6 | 17.6 |

S6.2 adds the table as a test over the tokens (§11) so a later palette change cannot slip under
the floor. (The audit script was a throwaway in the D6.1 scratch directory; the test re-implements
the three matrices and CIEDE2000 — about 60 lines, `tests/support/`.)

### 8.4 Readability under the pass

The pass darkens (scanlines, vignette) and adds zero-mean noise (grain, dither). Measured on the
worst place — a vignette corner at `Full` — with the scanline's mean over its period
(`1 − depth / period`):

| | `TEXT_0` | `TEXT_1` | `TEXT_2` | `ACCENT` |
| --- | --- | --- | --- | --- |
| cold, no pass | 14.1 | 7.1 | 3.6 | 12.0 |
| cold, worst corner at full heat | 11.5 | 5.9 | 3.1 | 9.8 |
| open (§8.2), no pass | 14.9 | 8.0 | 3.6 | 12.9 |
| open (§8.2), worst corner at full heat | 12.0 | 6.6 | 3.1 | 10.4 |

(The pass multiplies display values, so the table does too: corner `1 − FX_VIGNETTE`, scanline
mean `1 − FX_SCANLINE_DEPTH / FX_SCANLINE_PERIOD`. On the dark scanline row itself `TEXT_1` is
still 5.4 cold, 6.0 open.) The floors that hold: `TEXT_1` ≥ 4.5 : 1 everywhere and `TEXT_2` ≥ 3 : 1
on the period mean, at every setting.
**`FX_VIGNETTE` and `FX_SCANLINE_DEPTH` may not be raised** without re-running this table; a
test computes it from the tokens (§11).

---

## 9. Map polish — the staircase

### 9.1 What it is

Looked at in D6.1 at zoom ≈ 4 over the Mediterranean and West Africa: the **inner borders are
already smooth** — they are the 8192-px `border_mask`, drawn from the geometry. What steps is:

1. **the coast.** `map.gdshader` returns transparent wherever the 4096-px ID map says ocean
   (`idx == 0`), so the anti-aliased `land_mask` only ever *removes* land and never adds it: the
   coast is the ID map's staircase with a soft inner edge;
2. **the selection and eligibility outlines**, built from ID-map taps (ui-foundation §7.3 item 7),
   which step at 2–4 screen px per texel from zoom 2 on.

### 9.2 Options

| | Cost | Verdict |
| --- | --- | --- |
| 2× ID map (8192 × 4096) | 128 MiB of video memory as RGBA8, a 96 MiB picking image in RAM, a far larger download | **rejected** — it breaks the web build and phones for a zoom-4 detail |
| vector border lines (`Line2D` per border) | a new pipeline output, ~thousands of polylines, redraws on zoom | **rejected** — the `border_mask` already *is* the geometry |
| **shader border pass** | a few taps, only near edges | **chosen** |

### 9.3 The border pass (`map.gdshader`)

**Coast pass.** When `idx == 0`: read `land = texture(land_mask, UV).r`; `land <= 0` →
transparent as today. Otherwise borrow a region: the first land index among the taps at one
texel in the order `+x, −x, +y, −y, (+x+y), (−x+y), (+x−y), (−x−y)`; none → transparent. Draw
that region exactly as a land fragment (fill, border, hover, outline) with `ALPHA = land`. The
coastline's `border_mask` line — already in the mask — then sits on a smooth edge.

**Mask-built outlines.** New uniform `smooth_outline: bool`, set by `MapCamera` whenever its zoom
is **≥ `MAP_SMOOTH_OUTLINE_ZOOM` (2.0)**, false below (where a texel is under 2 screen px and the
tap outline is exact). When true:

- **selection:** a fragment is on the selected region's outline if `border >
  MAP_OUTLINE_MASK.x` and (`idx == selected_index` or any of 8 taps — ±1 and ±2 texels along x
  and y — is `selected_index`); `col = mix(col, map_select, smoothstep(MAP_OUTLINE_MASK.x,
  MAP_OUTLINE_MASK.y, border))`. The outline takes the border line's own anti-aliased shape and
  width (1.5 texels: 3 screen px at zoom 2, 6 at zoom 4 — the tap outline grew with the zoom too).
- **eligible site / scope flash** (row 1's G or B): the same, but **inner half only** (`idx` is the
  eligible region) and `accent` — so two neighbouring eligible regions stay told apart, as today.
- Below the switch zoom both keep today's tap rule unchanged.

| Token | Value |
| --- | --- |
| `MAP_SMOOTH_OUTLINE_ZOOM` | 2.0 |
| `MAP_OUTLINE_MASK` | `Vector2(0.25, 0.6)` |

**Edge cases.** A coast fragment between two regions' land (a strait narrower than two texels)
takes the first tap's region — a one-texel ambiguity no player can click anyway (picking still
reads the ID map, unchanged). Hover and selection on a borrowed coast fragment follow the borrowed
region, which is what the eye expects. Air-gapped, dark and dormant regions draw their borrowed
fringe in their own state. The picking code (`MapPicker`) does not change.

**Verify (S6.2):** screenshots at zoom min, 2 and 4 over the Mediterranean, the Caribbean and
Indonesia (cold and open, one region selected, a site request open): no stepped coast, the
selection outline follows the border line at 2 and 4, no halo of the ocean at the coast, Taiwan
still a distinguishable dot once seeded.

---

## 10. The Societal Function overlay — built

**Why build it:** Societal Function is the Cyber player's deliberate weapon (opposition §8.1:
collapse slows the hunters and costs the humans' hardware), and today it is visible only one
region at a time in the panel. A fourth view shows the strategy at a glance. It costs one data
row, one shader branch and one button.

### 10.1 Data — row 2

`RegionData.HEIGHT` 2 → **3**, `ROW_SOCIETY: int = 2`. Pixel `(i, 2)`: **R = the stage** of
opposition §8.2 as an integer 0…5 stored `stage / 255.0` (the `flags` convention),
`SocietalFunctionSystem.stage(region.society, db.balance)`; G, B, A = 0 (reserved). Written in
`RegionData.write` with the other rows. The shader never sees the thresholds — they stay in
`balance.json`.

### 10.2 Shader

`const int OVERLAY_SOCIETY = 3;` `uniform vec4 map_society : source_color;` In the overlay
branch: `s = int(round(texelFetch(region_data, ivec2(idx, 2), 0).r × 255))`; `s > 0` → `col =
mix(map_land, map_society, (float(s) / 5.0) × mix_strength)`. Dark regions stay `map_dark` (a
dark region has no society left to draw); dormant at half strength like every view.

`MAP_SOCIETY` = **`#C9B8FF`** (lavender), the same in both variants — clear of the ramp (ΔE₀₀
61 from its top), `MAP_DEATH` (36), and in a fill channel the faction colours never use. Five
stages at 0.7 × s/5 step by ΔE ≈ 8–9 and 1.35–1.42 : 1 each on either land colour — the same
readable step the continuous views have. *Stepped, not continuous*, because the mechanic is
stepped: capacity and yield change at the thresholds and nowhere between.

### 10.3 The picker

`MapView.Overlay` gains `SOCIETY` (3); `MODE_KEYS` gains `"UI_TERM_SOCIETY"`. Reveal (m3-screens
§6.1's overlay row): Boxed none · Covert penetration, control · **Emergent and Open: all four**.
In compact the cycle button steps through four. The region panel's Society row is the value
behind the colour (never colour alone).

---

## 11. Tests

**`tests/unit/test_screen_fx_rules.gd`** (S6.1)
- `test_heat_boxed_is_zero` · `test_heat_rises_with_phase` · `test_heat_open_reaches_one_at_endgame`
  (endgame 0.75 → 1.0; 0.25 → `FX_HEAT_PHASE[OPEN]`)
- `test_endgame_takes_the_larger_of_containment_and_control` (fixture world)
- `test_params_off_disables_the_pass` · `test_params_reduced_motion_zeroes_scanlines_grain_and_ca`
  · `test_params_reduced_motion_keeps_bloom_vignette_dither` · `test_params_subtle_uses_eight_bloom_taps`
- `test_impulse_for_discovery_is_full` · `test_impulse_for_open_phase_is_full` ·
  `test_impulse_for_other_phase_is_zero` · `test_impulse_for_counter_move_event` ·
  `test_impulse_for_loss_is_stronger_than_win` · `test_impulse_for_headline_is_zero`

**`tests/unit/test_flash_limiter.gd`** (S6.1)
- `test_first_flash_is_allowed` · `test_flash_within_min_gap_is_refused` ·
  `test_fourth_flash_in_one_second_is_refused` · `test_flash_after_window_is_allowed_again`

**`tests/unit/test_settings.gd`** (additions, S6.1)
- `test_screen_effects_missing_falls_back_to_default` · `test_screen_effects_wrong_type_falls_back`
  · `test_cycle_screen_effects_wraps`

**`tests/unit/test_ui_tokens.gd`** (new or additions, S6.1/S6.2)
- `test_looping_periods_are_at_least_half_a_second` (§6 rule 3)
- `test_alert_flash_alpha_stays_under_red_flash_limit` (§6 rule 2)
- `test_text_contrast_holds_under_the_pass` (§8.4: `TEXT_1` ≥ 4.5, `TEXT_2` ≥ 3.0, both variants,
  worst corner, full heat)
- S6.2: `test_map_channel_pairs_clear_the_colour_floor` (§8.3, both variants) ·
  `test_open_accent_ink_contrast` (≥ 7 : 1)

**`tests/integration/test_screen_fx.gd`** (S6.1)
- `test_layer_is_above_popups` (1025) · `test_pass_ignores_the_mouse`
- `test_off_hides_the_pass` · `test_wash_shows_the_pass_at_off`
- `test_impulse_within_cooldown_is_ignored` · `test_stronger_impulse_within_cooldown_replaces`
- `test_dissolve_reduced_motion_is_a_cut`
- `test_discovery_event_starts_an_impulse`

**`tests/integration/test_screen_router.gd`** — the fade-in assertions become dissolve assertions
(S6.1). **`tests/unit/test_region_data.gd`** — `test_row_two_holds_the_society_stage`,
`test_image_is_three_rows` (S6.2). **Overlay picker** — `test_emergent_offers_four_views`,
`test_covert_offers_two` (S6.2). **`test_theme_builder.gd`** — any assertion on the old Open accent
values follows §8.2.

---

## 12. Acceptance

### 12.1 S6.1

- The pass runs at 1025 over boot, title, setup, session, a modal and a tooltip; clicks go through.
- Looked at (godot-mcp screenshots, `game_get_errors` clean) at **1920 and 400 px**, **cold and
  open**, at `Off` / `Subtle` / `Full`, and with reduced motion: text is crisp (no glow on
  `TEXT_*`), the accent and `ALERT` glow, the panels grain in Open and not in Boxed.
- A discovery shows the wash and one aberration burst; Open's arrival tears once; a screen change
  dissolves in from the ground; with reduced motion all three are absent or cut.
- **Web-safe path confirmed:** the shader uses `hint_screen_texture` and fragment stages only; no
  `RenderingDevice`, no compute, no `WorldEnvironment` (a grep in the acceptance note).
- Frame time recorded (§3.4). Suite green; the settings file round-trips `screen_effects`.

### 12.2 S6.2

- The Open accent is the §8.2 family; the theme is rebuilt (`tools/build_theme.gd`); the gallery
  (`O`) shows every component in both sets; the colour-floor test passes.
- The coast and outline screenshots of §9.3 show no staircase at zoom 2 and 4.
- The society view: a hand-played Cyber run (or `debug_schedule_event` + Blackouts) shows stepped
  lavender where society broke down, matching each region panel's stage; four views in Emergent.
- Contrast floors hold in both variants (the §8.4 test). Suite green.
