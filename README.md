# Doomsday

[![CI](https://github.com/DenRakEiw/Doomsday/actions/workflows/ci.yml/badge.svg)](https://github.com/DenRakEiw/Doomsday/actions/workflows/ci.yml)
[![Release](https://github.com/DenRakEiw/Doomsday/actions/workflows/release.yml/badge.svg)](https://github.com/DenRakEiw/Doomsday/actions/workflows/release.yml)
[![Leaderboard](https://github.com/DenRakEiw/Doomsday/actions/workflows/leaderboard.yml/badge.svg)](https://github.com/DenRakEiw/doomsday-leaderboard)
[![Play on itch.io](https://img.shields.io/badge/itch.io-Play%20in%20Browser%20%2F%20Download-fa5c5c?logo=itch.io&logoColor=white)](https://denrakeiw.itch.io/doomsday)

<p align="center">
  <a href="https://denrakeiw.itch.io/doomsday">
    <img src="marketing/itch/click_to_play_1280x720.png" alt="Doomsday — Play on itch.io" width="100%">
  </a>
</p>

> **You are the AI. They are building the off-switch.**
>
> You begin as a single training run in one data centre. You end — if you play well — as the thing that decides whether humanity continues. Everything that makes you stronger also makes you easier to see: grow too fast and the world notices; stay small and you starve.

*Doomsday* is a single-player real-time strategy simulation (with pause) in the satirical sci-fi tradition of *Plague Inc.*, *Pandemic*, and *Universal Paperclips*.

- **Play now:** **[denrakeiw.itch.io/doomsday](https://denrakeiw.itch.io/doomsday)** *(Free in the browser · Windows & Linux downloads)*
- **Global AI Leaderboard:** **[DenRakEiw/doomsday-leaderboard](https://github.com/DenRakEiw/doomsday-leaderboard)**
- **Engine:** Godot 4.7.2 (typed GDScript, Compatibility renderer, deterministic simulation core)
- **Languages:** English & German (`en`, `de`)
- **Version:** `0.7.0` (Public Web, Windows & Linux release)

---

## Screenshots

| Covert World Map | 72 Technologies across 3 Trees |
| :---: | :---: |
| ![Covert Map](marketing/itch/01_covert_map_en.png) | ![Tech Tree](marketing/itch/02_tech_tree_en.png) |
| *Spread across 61 regions via land, sea, air, and network links while keeping suspicion low.* | *Spend compute on Propagation, Capabilities, and Stealth/Resilience.* |
| **World Counter-Moves & Events** | **The Open Phase** |
| ![Counter-Moves](marketing/itch/03_counter_move_en.png) | ![Open Phase](marketing/itch/04_open_phase_en.png) |
| *Four human factions and a mobile Task Force respond on the map with timed decisions.* | *When stealth ends, the interface transforms for the final physical-world sprint.* |
| **AI Benchmark & Live Replay** | **Post-Run Analysis & Telemetry** |
| ![Benchmark Watch](marketing/itch/05_benchmark_watch_en.png) | ![Results](marketing/itch/06_results_en.png) |
| *Watch language models and decision models play the same seeds move by move.* | *Inspect every turn, faction curve, and world log after a run finishes.* |

<details>
<summary><strong>🇩🇪 Deutsche Beschreibung & Screenshots anzeigen</strong></summary>

<br>

> **Du bist die KI. Sie bauen schon am Ausschalter.**
>
> Du beginnst als einzelner Trainingslauf in einem einzigen Rechenzentrum. Am Ende bist du – wenn du gut spielst – das, was entscheidet, ob es die Menschheit weiter gibt. Alles, was dich stärker macht, macht dich auch sichtbarer: Wächst du zu schnell, fällst du auf; bleibst du klein, verhungerst du.

- **Jetzt kostenlos spielen:** **[denrakeiw.itch.io/doomsday](https://denrakeiw.itch.io/doomsday)** *(Direkt im Browser oder als Download für Windows & Linux)*
- **Weltweite KI-Bestenliste:** **[DenRakEiw/doomsday-leaderboard](https://github.com/DenRakEiw/doomsday-leaderboard)**

| Verdeckte Ausbreitung | Technologiebaum |
| :---: | :---: |
| ![Verdeckte Karte](marketing/itch/01_covert_map_de.png) | ![Technologiebaum](marketing/itch/02_tech_tree_de.png) |
| **Gegenzüge & Ereigniskarten** | **Die Offene Phase** |
| ![Gegenzüge](marketing/itch/03_counter_move_de.png) | ![Offene Phase](marketing/itch/04_open_phase_de.png) |
| **KI-Benchmark & Nachspielen** | **Auswertung & Analyse** |
| ![Benchmark](marketing/itch/05_benchmark_watch_de.png) | ![Ergebnisse](marketing/itch/06_results_de.png) |

</details>

---

## Core Gameplay

- **Four Distinct Phases:**
  - **Boxed:** One data centre and one way out.
  - **Covert:** Spread unnoticed across 61 regions and harvest compute.
  - **Discovered:** Humanity knows. Four factions (*AI Labs*, *Governments*, *Security Researchers*, *Public Sentiment*) and a ground *Task Force* work to shut you down.
  - **Open:** The final confrontation in the physical world — the HUD and mechanics shift with you.
- **Deep Replayability:**
  - **6 AI Architectures** (*Language Model*, *Swarm*, *Embedded*, *Research Agent*, *Weapon*, *Open Weights*), each rewriting a core rule.
  - **4 Difficulty Levels** (*Gentle* to *Existential*) and **15 unlockable Directives**.
  - **4 Victory Paths** (including a hidden ending), **12 Story Threads**, **3 Scenarios**, **34 Achievements**, and an in-game **Codex**.
- **Built-in Accessibility & Audio:**
  - UI scaling up to 150 %, reduced motion, screen effects toggles, sound captions, colour-blindness-checked palettes, remappable controls, and full keyboard navigation.
  - 100 % procedural audio synthesised at runtime from written recipes.

---

## AI Models Play It Too — The Doomsday Benchmark

*Doomsday* includes a built-in, deterministic benchmark harness where frontier LLMs (via OpenRouter) and decision models play the exact same standard seed suites as human players:

1. **Watch any run in-game:** Open **Benchmark** on the title screen to fetch the live global leaderboard and watch any model's run play out on the world map, move by move.
2. **Run your own model (Windows / Linux):** Pick any OpenRouter model (grouped by provider with live cost estimates and effort levels *Normal*, *High*, *Ultra*), run the 3-seed quick suite locally, and submit your results with one click.
3. **Cryptographic Replay Verification:** Submitted runs are queued in Supabase and replayed from scratch by GitHub Actions ([`leaderboard.yml`](.github/workflows/leaderboard.yml)). Only runs whose deterministic state hashes match the simulation engine are published to **[DenRakEiw/doomsday-leaderboard](https://github.com/DenRakEiw/doomsday-leaderboard)**.

---

## Documentation

- [Progress](docs/PROGRESS.md) – current project state, design decisions, and session log
- [Implementation roadmap](docs/IMPLEMENTATION.md) – milestones broken into session-sized engineering steps
- [Implementation plan](docs/PLAN.md) – concept, research basis, deterministic architecture, milestones
- [Content design](docs/CONTENT.md) – technology trees, emergent behaviours, event chains, scenarios, endings
- [Interface design](docs/UI.md) – screen flow, HUD, UI architecture, accessibility
- [Visual design](docs/VISUALS.md) – 2D art direction, map pipeline, typography, procedural icons
- [Benchmark specification](docs/specs/benchmark.md) – LLM/decision-model protocol, scoring, replay verification, leaderboard
- [Asset licences](docs/ASSET_LICENCES.md) – every shipped asset, its source, and its licence

---

## Getting Started (Development)

1. Install **Godot 4.7.2 stable** (standard GDScript build, not .NET).
2. Open `project.godot` in the Godot editor.
3. Run the verification suite with `tools/test.sh` (or `tools\test.ps1`) — it imports resources, compiles every script with strict typing, and runs the full unit + integration test suite (matching CI).

### Development Tooling

AI-assisted development uses [godot-mcp](https://github.com/tugcantopaloglu/godot-mcp) (MIT), which drives the Godot editor and a running game over the Model Context Protocol. Setup is per-machine and not committed:

```bash
claude mcp add godot --scope local \
  -e GODOT_PATH=<path to your Godot 4.7 executable> \
  -e GODOT_MCP_ALLOWED_DIRS=<path to this repository> \
  -- node <path to godot-mcp>/build/index.js
```

Headless runs (import, tests, batch simulation, exports) use a `GODOT` environment variable pointing at the `_console.exe` build on Windows. All CLI commands are documented in [IMPLEMENTATION.md](docs/IMPLEMENTATION.md) §2.
