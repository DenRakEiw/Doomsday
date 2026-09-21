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
| **Next step** | **D1.1 — Core spec and coding standard** |
| **Model for it** | **Fable** (`/model fable`) |
| **After it** | `/clear`, stay on Fable → D1.2 |
| **Last completed** | — (planning only) |
| **Milestone** | M1 design (ahead of the M0/M1 build block) |
| **Branch** | `main` |
| **Test suite** | not set up yet (arrives in S0.2) |

**[F]** = Fable: design, specs, content, text, balance, gates. **[O]** = Opus: code, scenes,
shaders, wiring, tooling, tests. `/clear` after every step. **⇄** marks a model switch before the
next step.

## In progress

*(empty — if a session stops mid-step, the handover goes here: what is finished, what is left,
which file was being edited, and anything learned that the files do not show)*

---

## Steps

**Block 1 — design for M0/M1 · Fable**
- [ ] D1.1 [F] Core spec and coding standard
- [ ] D1.2 [F] World design: the ~60 regions — ⇄ **then `/model opus`**

**Block 2 — M0 and M1 build · Opus**
- [ ] S0.1 [O] Project skeleton and settings
- [ ] S0.2 [O] Test framework
- [ ] S0.3 [O] Continuous integration *(needs a push — ask first)*
- [ ] S1.1 [O] Content schema, loaders, validation
- [ ] S1.2 [O] World model, tick loop, RNG, state hash
- [ ] S1.3 [O] Spread
- [ ] S1.4 [O] Compute economy, modifiers, purchasing
- [ ] S1.5 [O] Harm, single containment track, phases, outcomes
- [ ] S1.6 [O] Map pipeline 1: geometry *(timeboxed)*
- [ ] S1.7 [O] Map pipeline 2: attributes and links
- [ ] S1.8 [O] Save/load, headless runner, bots — ⇄ **then `/model fable`**

**Block 3 — M1 gate, M2 design · Fable**
- [ ] G1 + D2.1 [F] M1 gate, then the interface foundation spec — ⇄ **then `/model opus`**

**Block 4 — M2 build · Opus**
- [ ] S1.P [O] Punch list from G1 *(skip if empty)*
- [ ] S2.1 [O] Autoloads and session driver
- [ ] S2.2 [O] Map rendering
- [ ] S2.3 [O] Picking, camera, backdrop
- [ ] S2.4 [O] Theme and component library
- [ ] S2.5 [O] HUD and region panel
- [ ] S2.6 [O] Anomalies and links — ⇄ **then `/model fable`**

**Block 5 — M2 gate, M3 design · Fable**
- [ ] G2 [F] Visual review and M2 gate
- [ ] D3.1 [F] Effect vocabulary; Infiltration and Evasion trees
- [ ] D3.2 [F] Capabilities tree
- [ ] D3.3 [F] M3 screens
- [ ] D3.4 [F] Ticker voice and headlines — ⇄ **then `/model opus`**

**Block 6 — M3 build · Opus**
- [ ] S2.P [O] Punch list from G2 *(skip if empty)*
- [ ] S3.1 [O] Effect vocabulary in the core; load the trees
- [ ] S3.2 [O] Tech tree interface
- [ ] S3.3 [O] Containment and phases in the interface
- [ ] S3.4 [O] Run flow: origin, outcome, results
- [ ] S3.5 [O] Ticker component and headline system
- [ ] S3.6 [O] Strategy bots and batch reporting — ⇄ **then `/model fable`**

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

## Design questions for Fable

*(empty — Opus records here every design gap it hit while building: the question, where the
placeholder is (`# DESIGN?` in code), and what it assumed. Every Fable block answers these first.)*

## Punch list for Opus

*(empty — reviews and gates write concrete, file-level fixes here; they become the `S<m>.P` step at
the head of the next Opus block)*

## Deviations from the plan or a spec

*(none yet — anything built differently is listed here with the reason, and the plan or spec is
corrected in the same commit)*

## Known issues and carry-overs

*(none yet)*

## Waiting on the user

- S0.3 needs a push to GitHub to prove CI — will be asked for when the step comes up.

## Balance baselines

*(first entry arrives with S1.8: run length in ticks and terminal-state distribution over 200 seeds
per policy)*

---

## Session log

Newest first. Five lines at most per entry: what was done, what was learned, what is next.

### 2026-09-21 — Planning [F]
Verified godot-mcp (Godot 4.7.2, project recognised, no scenes or scripts yet). Wrote
IMPLEMENTATION.md v0.2 (D/G steps on Fable, S steps on Opus, run sheet with clear and switch
points; M0–M5 in session-sized steps, M6–M7 outlined), this file, and CLAUDE.md.
Environment: Python 3.12 + `uv`, Node 24, `gh` present; GDAL CLI and mapshaper absent.
Next: D1.1 on Fable.
