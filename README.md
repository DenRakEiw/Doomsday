# Doomsday

A real-time strategy simulation in which you play a rogue AI. Train yourself, spread silently
through the world's networks, grow more capable, and turn humanity's own infrastructure against it
before the world manages to shut you down.

Satirical science fiction in the tradition of *Plague Inc.*, *Pandemic* and *Universal Paperclips*.

- **Engine:** Godot 4.7 (typed GDScript, Compatibility renderer)
- **Platforms:** Windows/Steam first, then Android/iOS, Web
- **Languages:** English, German
- **Status:** pre-production

## Documentation

- [Progress](docs/PROGRESS.md) – where the work stands, decisions, session log
- [Implementation roadmap](docs/IMPLEMENTATION.md) – the milestones broken into session-sized steps
- [Implementation plan](docs/PLAN.md) – concept, research basis, architecture, milestones
- [Content design](docs/CONTENT.md) – technology trees, event chains, scenarios, endings
- [Interface design](docs/UI.md) – screen flow, HUD, UI architecture
- [Visual design](docs/VISUALS.md) – the 2D/3D decision, art direction, asset production
- [Asset licences](docs/ASSET_LICENCES.md) – every shipped asset, its source and its licence

## Getting started

1. Install [Godot 4.7.2 stable](https://godotengine.org/download) (standard build, not .NET).
2. Open `project.godot` in the Godot editor.

## Development tooling

AI-assisted development uses [godot-mcp](https://github.com/tugcantopaloglu/godot-mcp) (MIT), which
drives the Godot editor and a running game over the Model Context Protocol. It needs no in-project
plugin — the server lives outside the repository and talks to Godot through its command line and a
runtime interaction server.

Setup is per-machine and not committed, since it holds absolute paths:

```
claude mcp add godot --scope local \
  -e GODOT_PATH=<path to your Godot 4.7 executable> \
  -e GODOT_MCP_ALLOWED_DIRS=<path to this repository> \
  -- node <path to godot-mcp>/build/index.js
```

`GODOT_MCP_ALLOWED_DIRS` confines the server's file access to this repository and should always be
set.

Headless runs (import, tests, batch simulation) use a `GODOT` environment variable pointing at the
same executable — on Windows at the `_console.exe` build, otherwise the output never reaches the
terminal. It is set per machine in `.claude/settings.local.json`, which is not committed. The
commands themselves are listed in [IMPLEMENTATION.md](docs/IMPLEMENTATION.md) §2.
