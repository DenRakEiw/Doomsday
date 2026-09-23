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
| `docs/BALANCE.md` | Balance passes: targets, method, sweeps, what changed and why (from G3) |

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

GDScript follows the official Godot style guide; what follows is what that guide leaves open or
what we tighten.

- **Files:** `snake_case.gd` / `.tscn`, **one class per file**, file name = snake_case of the
  `class_name` (`SpreadSystem` → `spread_system.gd`). Never PascalCase file names — Windows forgives
  a case mismatch, the exported game and Linux CI do not.
- **`class_name`:** on every script in `core/` and on every reusable `ui/` component. Not on
  autoloads (the autoload name is the global), not on scene-specific scripts, tools or tests.
  Refer to classes by name, not by `preload` path.
- **Naming:** classes `PascalCase`; functions, variables, signals `snake_case`; constants and enum
  values `UPPER_SNAKE`; enum types `PascalCase`; private members `_leading_underscore`; booleans
  read as a statement (`is_open`, `has_origin`, `discovered`). Content ids lower snake case,
  localisation keys `UPPER_SNAKE` with a domain prefix (`data/SCHEMA.md` §7).
- **Typing:** every variable, parameter and return type is declared, `-> void` included. `:=` is
  allowed where the right-hand side makes the type obvious. Typed collections (`Array[Region]`,
  `Dictionary[String, float]`). Loop variables are typed (`for i: int in …`). Values from JSON or a
  `Dictionary` are cast at the boundary (`int(d["day"])`) and typed from then on.
- **Signals:** past tense for what happened (`region_selected`, `phase_changed`), `_requested` for
  what the interface asks for (`purchase_requested`). Typed parameters. Handlers are
  `_on_<emitter>_<signal>`. `core/` has no signals — it has the event outbox.
- **Constants:** anything a designer might tune lives in `data/balance.json` and is read through
  `BalanceDef`; a numeric literal other than 0 or 1 in a system is a defect. Presentation constants
  (durations, sizes) live in the theme or in one `const` block at the top of the script.
  Identifiers shared between files (event types, failure reasons, flags) are `const` strings on the
  class that owns them, never retyped literals.
- **Order inside a script:** `class_name`/`extends`, doc comment, signals, enums, constants,
  `@export`, public variables, private variables, `@onready`, `_init`/`_ready`, other virtuals,
  public methods, private methods. Tabs.
- **Comments** explain why, not what, in English. Public API of `core/` gets a `##` doc comment.
  `# DESIGN?` marks a placeholder for a design gap and always has a matching entry in `PROGRESS.md`.
- **Errors:** `core/` never crashes on bad data — loaders and the save reader return results with
  reasons. `push_error` is for programming errors; `assert` only in tests and tools.
- **Tests (GUT):** `tests/unit/test_<file under test>.gd`, `tests/integration/test_<behaviour>.gd`,
  functions `test_<what>_<expected>` (`test_purchase_without_compute_is_rejected`). One behaviour
  per test. Fixtures through `tests/support/fixtures.gd`; tests may set state directly to build a
  situation, nothing else may. A test depending on randomness fixes its seed and says so.

## Tooling

- Godot is driven through the `godot` MCP server. `$GODOT` holds the executable for headless runs
  (per machine, in `.claude/settings.local.json`); on Windows it must be the `_console.exe` build.
- Commands for import, tests and simulation runs: `docs/IMPLEMENTATION.md` §2.
