# Doomsday — Interface Design

**Version:** 0.1 (draft)
**Date:** 2026-09-21

This game is roughly 70% user interface. The map is the stage, but the interface is the game — and
it is also the largest single cost in the project. This document defines the screen flow, the
in-game HUD, and the Godot architecture that keeps the cost down.

See also: [PLAN.md](PLAN.md) · [CONTENT.md](CONTENT.md) · [VISUALS.md](VISUALS.md)

---

## 1. Principles

1. **One input verb.** The source game is almost entirely "tap the thing on the map." Every screen we
   add past that is a tax on pace. Default to *fewer screens, denser screens*.
2. **The whole world, always visible.** Nothing may permanently cover the map. Panels slide over one
   edge; full-screen overlays are modal and explicitly dismissed.
3. **Touch-first sizing, on every platform.** A 48px minimum hit target designed for a phone is also
   a comfortable desktop target. Designing desktop-first and shrinking later never works.
4. **Readable at a glance, in two languages.** German strings run roughly 30% longer than English.
   Nothing may be laid out at a fixed width.
5. **The interface is diegetic.** It is the console of the thing you are playing. That framing buys
   us a lot of cheap production value — see [VISUALS.md](VISUALS.md).

---

## 2. Screen flow

```
Boot sequence
     │
Main menu ──── Settings · Codex · Statistics · Quit
     │
New run
     ├─ 1. Architecture select   (six options, locked ones visible)
     ├─ 2. Directive loadout     (five slots, unlocked by play)
     └─ 3. Origin select         (on the map — the first real decision)
     │
Session ─────────────────────────────────────────────┐
     │  map HUD · tech tree · containment · graphs   │
     │  region panel · event modals · pause          │
     │                                               │
Results ── unlocks, run summary, "again" ────────────┘
```

**Boot sequence.** A short fake terminal boot before the main menu. It costs almost nothing — text,
timing and one shader — and it establishes the entire premise before a single menu appears. Skippable
on every run after the first.

**Architecture select** and **Directive loadout** are the pre-run build decisions, kept as two quick
screens rather than one dense one, because the second is meaningless to a new player and should be
skippable with a default.

**Origin select** happens *on the live map*, not in a list. The player's first interaction with the
game is the same interaction they will use for the next 30 minutes.

---

## 3. The session HUD

Everything below sits over the map. The map is never fully covered.

```
┌─────────────────────────────────────────────────────────────┐
│ COMPUTE 1,284 ▲ │ PHASE: COVERT │ DAY 41 │  ‖ ▶ ▶▶ ▶▶▶      │  top bar
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                    W O R L D   M A P                        │
│              (anomalies, links, overlays)                   │
│                                                             │
│                                    ┌──────────────────────┐ │
│                                    │ ▸ CAPABILITIES       │ │  right dock
│                                    │ ▸ CONTAINMENT        │ │
│                                    │ ▸ ANALYSIS           │ │
│                                    └──────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│ ▓▓▓░░ PENETRATION  ▓░░░░ FOOTPRINT  ░░░░░ HARM              │  core stats
├─────────────────────────────────────────────────────────────┤
│ ◂ Regulators announce a review of frontier training runs…   │  ticker
└─────────────────────────────────────────────────────────────┘
```

- **Top bar** — Compute with its rate of change, current phase, elapsed time, speed controls
  (pause + three speeds). Phase is shown because the whole design is built around phases.
- **Core stat bars** — Penetration, Footprint, Harm. Three bars, always visible, never hidden. These
  are the numbers every decision trades against, and burying them would break the game.
- **News ticker** — the voice of the game and its primary source of comedy and dread. It carries
  three streams: consequences of your own actions, faction and institutional reactions, and
  satirical filler that thins out as the world deteriorates.
- **Right dock** — three buttons, not a menu bar. Everything else is reachable from these.

### Panels

- **Region panel** (slides from the left, map stays visible) — population, compute density, wealth,
  connectivity, your penetration and control, societal function stage, active countermeasures, and a
  short flavour entry. Opened by clicking any region.
- **Containment panel** — the four faction tracks with their funding, current activity and signature
  countermeasure. This is the "how much trouble am I in" screen, and it needs to be readable in two
  seconds.
- **Tech tree** (full-screen modal, three tabs) — the only screen that covers the map. Pauses by
  default on desktop, does not pause on mobile.
- **Analysis** — the graphs screen: population, penetration, containment over time, plus the run
  log. Built with the project's charting conventions; load the `dataviz` skill before implementing it.
- **Event modal** — narrative chains from [CONTENT.md](CONTENT.md). Two to four choices, each showing
  its known cost but not its full consequence. These are the moments the player will remember, so
  they get the most typographic care in the game.

### Phase shifts

Borrowed from *Universal Paperclips*: **the interface itself changes as the run progresses.** In the
Boxed phase the player has almost no controls — a deliberately claustrophobic screen. Controls appear
as capability does. In the Open phase the palette shifts, new readouts appear, and the ticker changes
register from institutional to panicked. This costs us little (the same scenes, with sections
revealed and a theme variation swapped) and does more for the sense of escalation than any amount of
content.

---

## 4. Godot architecture

### Structure

```
res://ui/
├── theme/           # the Theme resource + StyleBox definitions + fonts
├── components/      # reusable: StatBar, IconButton, Ticker, Panel, TechNode…
├── screens/         # boot, menu, architecture select, loadout, results
├── hud/             # top bar, stat bars, ticker, dock
├── panels/          # region, containment, analysis, tech tree
└── modals/          # events, confirmations, pause
```

A `ScreenRouter` autoload owns transitions between top-level screens. Within a session, panels are
children of a `CanvasLayer` stack ordered: map → HUD → panels → modals → post-processing.

### Theme, not overrides

A single `Theme` resource drives the entire game. Per-node property overrides are banned outside of
prototyping — they are invisible in review, impossible to re-skin, and the direct cause of
inconsistent interfaces in projects this size.

Styling comes from **procedural `StyleBoxFlat`** wherever possible: borders, corner radii and fills
need no image assets at all, scale perfectly to any DPI, and can be recoloured at runtime for the
phase shifts. Texture-based nine-slices are reserved for the few places that genuinely need
ornament.

**Theme type variations** give us named variants (`Button/Danger`, `Panel/Modal`) without a
combinatorial explosion of scenes.

### Responsive layout

- **Containers, always.** No hardcoded positions anywhere in the UI. Anchors and Containers only.
- One layout serves ~400px phones through 4K desktops. Rows collapse to columns below a breakpoint;
  the right dock becomes a bottom bar; the region panel becomes a bottom sheet.
- Mobile safe areas are queried and applied as padding on one outer margin container, so notches and
  gesture bars are handled in exactly one place.
- Project stretch settings are fixed early and never touched again, because changing them late
  invalidates every layout decision made before.

### Localisation

English and German from the first playable milestone. All strings via `tr()` with **named**
placeholders, never positional ones, because German word order differs. Pseudolocalisation runs in
CI to catch overflow before a human ever sees it. No button is fixed-width; no label is assumed to
be one line.

---

## 5. Accessibility

Not an afterthought — much of it is free if decided now, and expensive if retrofitted.

- **Never colour alone.** Every map state that matters is also communicated by pattern, icon or
  value. The colour language is chosen to be colourblind-safe — see [VISUALS.md](VISUALS.md).
- **Text scale** setting, with the layout tested at 150%.
- **Reduced motion** setting that disables the scanline, flicker and parallax effects. Some of our
  atmosphere is exactly the kind of thing that causes problems.
- **Pause is always available**, including inside modals.
- No timed input anywhere. The game is real-time, but no decision requires reaction speed.

---

## 6. Open questions

1. Does the tech tree pause the game on desktop? Pausing is kinder; not pausing preserves tension.
   Probably a setting, defaulting to pause.
2. Is the right dock the correct shape on a phone, or does mobile need a genuinely different HUD?
   Decide with a real device in M2, not in a mockup.
3. How much of the phase shift is worth building? The idea is strong; the cost is unbounded. Cap it
   at: revealed controls, one palette change, one ticker register change.
