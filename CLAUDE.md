# Doomsday

A *Plague Inc.*-style strategy simulation in which the player is a rogue AI. Godot 4.7.2, typed
GDScript, Compatibility renderer. Windows/Steam first, then mobile and web. English and German.

## Every session starts here

Work proceeds in short sessions with the conversation cleared after every step. **Nothing is
remembered except what is written down.**

1. Read `docs/PROGRESS.md` — it names the next step, **the model it runs on**, and holds all
   decisions so far.
2. **Check the model.** Design steps (`D…`, `G…`, tagged **[F]**) run on **Fable**; build steps
   (`S…`, tagged **[O]**) run on **Opus**. If you are not the model the step asks for, say so and
   stop — the user switches with `/model fable` or `/model opus`.
3. Read that step in `docs/IMPLEMENTATION.md`, then only what its *Read first* lists. Do not read
   the design documents end to end.
4. Do the step. Session rules and the definition of done: `docs/IMPLEMENTATION.md` §1.
5. Finish: update `docs/PROGRESS.md`, commit as `<step id>: <summary>` (no need to ask; pushing is
   always asked for), then tell the user: step done → `/clear` → model switch if the run sheet
   says so → next step id.

**Fable designs, Opus builds, and the hand-over is a file.** On Fable: write specs
(`docs/specs/`), content data, text in both languages, balance values, reviews — no GDScript,
scenes or shaders. On Opus: build from the spec, make no design decisions; a design gap gets a
conservative placeholder marked `# DESIGN?` and an entry under *Design questions for Fable* in
`PROGRESS.md`.

If the user asks for something outside the current step, do it — then record in `PROGRESS.md`
whatever a future session would need to know about it.

## Documents

| File | What it is |
| --- | --- |
| `docs/PROGRESS.md` | **State.** Next step and model, decisions, design questions, punch list, log |
| `docs/IMPLEMENTATION.md` | **Plan.** Run sheet with clear/switch points, steps, binding technical decisions, toolbox |
| `docs/specs/` | **Hand-overs.** One spec per design step; what Opus builds from |
| `docs/PLAN.md` | Concept, game design, architecture, milestones |
| `docs/CONTENT.md` | Technology trees, emergent behaviours, event chains, scenarios, endings |
| `docs/UI.md` | Screen flow, HUD, UI architecture, accessibility |
| `docs/VISUALS.md` | 2D decision, art direction, map pipeline gotchas, fonts, icons |
| `docs/ASSET_LICENCES.md` | Every third-party or generated asset — nothing ships without a row |

## Rules that are easy to break

- **`core/` is pure simulation.** `RefCounted` only. No nodes, no `get_tree()`, no autoloads, no
  global `randf()`/`randi()`. Presentation sends `Command`s and reads state; it never mutates it.
- **Static typing everywhere.** An untyped declaration is a build error.
- **Content is data.** Technology, events, headlines, balance constants live in `data/*.json`. New
  content must not need a new `if` in a system — extend the modifier vocabulary instead.
- **One `Theme`, no per-node overrides.** Layout through containers, never fixed positions or widths.
- **Every player-visible string uses `tr()`** with named placeholders and exists in `en` and `de`.
- **Content rule:** capabilities are described by *outcome*, never *method*. No real exploit,
  protocol, pathogen or weapon detail in any string, file or comment. Institutions, never real
  named people.
- **Never load player-supplied `.tres`/`.res`.** Saves are versioned JSON.
- **Never copy from *Plague Inc.*:** no names, strings, icons, or HUD layout.
- Repository text (docs, comments, commit messages) is English; conversation with the user is
  German.

## Coding standard

*(written in D1.1)*

## Tooling

- Godot is driven through the `godot` MCP server. `$GODOT` holds the executable for headless runs
  (per machine, in `.claude/settings.local.json`); on Windows it must be the `_console.exe` build.
- Commands for import, tests and simulation runs: `docs/IMPLEMENTATION.md` §2.
