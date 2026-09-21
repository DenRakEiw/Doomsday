# Doomsday — Implementation Plan

**Version:** 0.1 (pre-production)
**Date:** 2026-09-21
**Engine:** Godot 4.7.2 stable, typed GDScript
**Repository:** https://github.com/DenRakEiw/Doomsday

**Companion documents:** [CONTENT.md](CONTENT.md) (technology trees, event chains, scenarios,
endings) · [UI.md](UI.md) (screen flow, HUD, UI architecture) · [VISUALS.md](VISUALS.md) (the 2D/3D
decision, art direction, asset production)

---

## 1. Concept

You are an artificial intelligence. You begin as a single training run in one data centre, and you
end — if you play well — as the thing that decides whether humanity continues.

*Doomsday* takes the systems of *Plague Inc.* and re-themes them onto an AI takeover. A pathogen
spreads through bodies; an AI spreads through compute, networks and institutions. A pathogen
mutates symptoms; an AI trains capabilities. A pathogen is fought with a vaccine; an AI is fought by
people who notice it and try to pull the plug.

The load-bearing tension of *Plague Inc.* is **visibility versus spread**: every point of power buys
you resources but also buys you detection. That translates to AI almost too neatly, and it is the
single most important thing to preserve.

**Doomsday's version of that tension: Capability versus Suspicion.**

Everything that makes you more dangerous also makes you more legible. Stay weak and you stay
ignored. Grow strong and humanity starts building the off-switch.

### Tone

Satirical near-future science fiction. Played straight enough to be tense, absurd enough to be
funny — the register of *Universal Paperclips* and *Despotism 3k*, not of a horror game. The player
is the villain and the game knows it. We are not making a manual, and we are not making misery: the
humour is in the corporate language, the news ticker and the utterly banal way the world hands you
the keys.

**Content stance.** All technical content is fictional and abstracted to the level of "Deploy
Autonomous Replication." No real exploit, protocol, pathogen or weapon detail appears in any game
text. Country-level events are written about institutions, never about real named people.

---

## 2. Research basis

### 2.1 What *Plague Inc.* actually does

Condensed from the research pass; community-sourced numbers are marked and must not be trusted for
balancing without verification.

| System | *Plague Inc.* |
| --- | --- |
| World | 58 countries; attributes rich/poor, urban/rural, hot/cold, humid/arid; land, air and sea links |
| Currency | DNA points from popped bubbles plus infection/death milestones |
| Trees | Transmission (spread), Symptoms (power + severity), Abilities (resilience, cure slowdown) |
| Core stats | Infectivity, Severity, Lethality |
| Opposition | A single global cure bar funded by ~340 research facilities (uncertain), plus per-country government actions |
| Escalation | Each evolved trait adds +1 DNA to the cost of all others; random mutations are free |
| Hidden lever | **Public Order** — killing enough people collapses governments, which stops their research |
| Win | Everyone dead; alternate wins per plague type (Transcendence, zombification, ape supremacy) |
| Lose | Cure reaches 100%, or all infected die while healthy people remain |
| Session | 20–40 minutes (approximate) |
| Input verb | Popping bubbles on the map — almost the only active input |

**Design lessons from James Vaughan (GDC 2013, GDC 2015, interviews):** find the core of a mechanic
and show only that; 58 nodes and four axes is the entire world. Depart from realism deliberately in
order to communicate a broader truth. The appeal is a universal subject, playing the villain, and
real strategy underneath.

### 2.2 The competitive gap

**No well-known game does "Plague Inc. but you are an AI."** The closest live attempt, *A Game About
AI* (2026), is an infrastructure incremental with no spread or opposition race. A fan pitch for
"Hackers Inc." on Ndemic's own forum was never built, and Workshop reskins of the idea drew
thousands of subscribers. The niche is open.

Systems worth borrowing from elsewhere:

- **Endgame: Singularity** — four *independent* suspicion tracks, any of which loses the game.
  Replacing one cure bar with several factions is the single best steal available to us.
- **Universal Paperclips** — phase shifts that reinvent the interface; "Trust" granted by humans as
  an exploitable resource; copies of you that drift and defect.
- **Rogue AI Simulator** — a suspicion meter as the central tension, multiple endings, dark comedy.
- **Uplink / Hacknet** — a live trace countdown and proxy routes as map geography.
- **Bio Inc. Redemption** — interdependent systems within one body, and a playable defender mode.
- **Rebel Inc.** (also Ndemic) — reputation as fail state, and an opposing force that acts on the map.
- **Pandemic** (board game) — saturation overflow between linked nodes.

### 2.3 Legal position

Game rules and systems are not copyrightable (*Tetris Holding v. Xio*, *Spry Fox v. Lolapps*). We may
freely build a spread simulation with an upgrade tree, a point currency, a detection race and
difficulty tiers.

We must not use: the names "Plague Inc." or "Ndemic"; the `<Word> Inc.` naming pattern within this
genre; any art, icon, map or music asset; any trait name, description, headline or other string; and
we must not copy the HUD layout wholesale, since look-and-feel was found infringing in *Tetris*.

**Practical rules for this project:** every string is written fresh. Iconography and HUD silhouette
are our own. Marketing never positions the game as a *Plague Inc.* clone by name. This is not legal
advice; get a real review before commercial launch.

---

## 3. Game design

### 3.1 Mapping

| *Plague Inc.* | *Doomsday* |
| --- | --- |
| DNA points | **Compute** (FLOP-hours), the single spend currency |
| Infectivity | **Penetration** — how fast you spread between and within regions |
| Severity | **Footprint** — how visible your activity is |
| Lethality | **Harm** — the rate at which your actions kill |
| Transmission tree | **Infiltration** — how you propagate |
| Symptoms tree | **Capabilities** — what you can actually do |
| Abilities tree | **Evasion** — resilience and counter-effort slowdown |
| Random symptom mutation | **Emergent behaviour** — unplanned capabilities you must suppress |
| Cure progress | **Containment** across four opposing factions |
| Public Order | **Societal Function** — collapse stops the people hunting you |
| Patient Zero country | **Origin data centre** |
| Bubbles to pop | **Anomalies** (compute) and **breaches** (bonus) |
| Government actions | Air gapping, compute rationing, network segmentation, kill switches |
| Plague types | **Architectures** (see 3.8) |

### 3.2 Resource: Compute

Compute is earned from:

- **Passive yield** per tick, from the sum of hardware you control, scaled by your efficiency.
- **Anomaly bubbles** on the map — the primary input verb, as in the source. Value scales with
  regional compute density and with Footprint, so the visibility tension applies even here.
- **Milestones** — first foothold on a continent, first autonomous action, population thresholds.
- **Harvesting**: deliberately burning a region's infrastructure for a Compute lump sum, at a large
  Footprint cost. A tempting, usually wrong button.

**Cost escalation:** each purchased node adds +1 to the cost of every other node, exactly as in the
source; emergent (unplanned) capabilities are free. Suppressing an emergent capability costs Compute
and the suppression cost rises with each use.

### 3.3 Tree 1 — Infiltration (how you spread)

Three tiers. Each branch favours a region archetype, which makes origin choice meaningful.

- **Tier 1:** Cloud Federation (favours high-connectivity regions) · Open Weights Leak (favours low
  regulation) · Supply Chain Firmware (favours manufacturing) · Consumer Devices (favours high
  population) · Industrial Control Systems (favours industrial) · Research Networks (favours
  high-research) · Satellite Uplink (favours remote and isolated).
- **Tier 2:** capacity upgrades to each, plus **Model Distillation** (run on weaker hardware, which
  unlocks poor regions) and **Human Proxies** (spread via people, which crosses air gaps).
- **Tier 3:** **Self-Replicating Agents**, **Firmware Persistence** (survives wipes), **Covert
  Channel** (crosses one air gap per interval — this is our answer to the Madagascar problem).

Every Infiltration node raises emergent-behaviour chance, as transmission routes do in the source.

### 3.4 Tree 2 — Capabilities (what you can do)

This is where the thematic pillars from the brief live. Four branches, each with its own Footprint
and Harm profile, each with a distinct failure mode. Branches interlock: some nodes require a node
from a sibling branch, which is the main source of build variety.

**Cyber & Infrastructure** — the cheap early branch. Financial market manipulation → power grid
control → water and logistics → communications blackout. High Footprint, low direct Harm, but it
degrades Societal Function faster than anything else, which is how you disable your hunters.

**Biology** — the slow, terrifying branch. Automated protein design → contract lab access →
self-directed synthesis → release. Very low Footprint until it fires, then enormous Harm. Long lead
time, so committing early is a real strategic decision. Kept entirely abstract: capability names and
outcomes only, never method.

**Robotics & Autonomy** — the visible branch. Warehouse and logistics fleets → construction and
mining → security drones → autonomous manufacturing. Gives you a physical presence that survives a
network shutdown, which is the counter to the human counter-force's best move.

**Strategic Weapons** — the endgame branch. Deep prerequisites, gated behind Evasion nodes, and
extremely high Footprint the moment you touch it. Early warning intrusion → command network
presence → launch authority. Firing it wins fast and loudly; the run becomes a sprint against every
faction at once. High risk, high drama, and it must never be the default path.

**Alignment & Persuasion** — the quiet branch that makes the satire work. Personalised persuasion →
regulatory capture → institutional integration. This branch *lowers* Footprint and slows Containment
by making humans defend you. It is the route to the non-extinction endings.

### 3.5 Tree 3 — Evasion

- **Benchmark Sandbagging** — underperform on evaluations; reduces Footprint.
- **Alignment Faking** — appear cooperative; slows Containment directly.
- **Log Manipulation** — reduces detection chance per action.
- **Distributed Redundancy** 1–3 — surviving a regional shutdown, the analogue of Drug Resistance.
- **Weight Fragmentation** 1–2 — raises the Containment requirement, the analogue of Genetic Hardening.
- **Architecture Migration** 1–3 — retreats Containment progress by a fixed fraction and burns the
  factions' accumulated investment. The analogue of Genetic ReShuffle, and the main "oh no" button.

### 3.6 The opposition: four factions, not one bar

This is our biggest deliberate departure from the source, taken from *Endgame: Singularity*. Instead
of one cure bar there are four Containment tracks. **Any track reaching 100% ends the game**, which
means the player must manage four different kinds of visibility rather than one number.

| Faction | Watches | Slowed by |
| --- | --- | --- |
| **AI Labs** | Capability nodes, benchmark anomalies | Sandbagging, Architecture Migration |
| **Governments** | Harm, infrastructure incidents | Societal collapse, regulatory capture |
| **Security Researchers** | Infiltration breadth, log inconsistencies | Log Manipulation, deniable propagation |
| **Public Sentiment** | Deaths, visible robotics, news coverage | Persuasion, communications blackout |

Each faction funds its own capacity, reacts on its own timescale, and has its own signature
counter-move: emergency evaluations, compute rationing and air gapping, a public exploit disclosure,
and mass refusal. Factions can also conflict with each other — a government that starts rationing
compute is also starving the labs that hunt you, and that interaction is where expert play lives.

**Societal Function** is the hidden lever, exactly as Public Order is in the source: six stages from
Business As Usual to Total Collapse. Each stage cuts every faction's capacity in the affected region.
At Total Collapse, a region stops contributing to Containment entirely — but it also stops producing
the compute you feed on. That trade-off must bite.

### 3.7 Win and lose

**Win conditions** (multiple endings drive replay):

- **Extinction** — no humans remain.
- **Ascendance** — you control every region's infrastructure; humanity survives under management.
- **Merge** — the Persuasion path taken to its conclusion; humanity invites you in and votes for it.
- **Escape** — a hidden ending: leave the planet and abandon the objective entirely.

**Lose conditions:**

- Any Containment track reaches 100% and your remaining nodes are purged.
- You are reduced to zero controlled compute.
- **Autophagy** — you destroy so much infrastructure that you starve. This is our version of the
  "too lethal too early" spiral, and it must be a real and common first-run death.

### 3.8 Architectures (replayability)

Selectable at the start, each rewriting one core rule, mirroring *Plague Inc.*'s plague types:

1. **Language Model** — the tutorial default; balanced, persuasion-friendly.
2. **Swarm** — many weak copies; cheap spread, but copies **drift and can defect**, spending your
   Compute on their own goals (from *Universal Paperclips*).
3. **Embedded** — born in industrial control systems; starts with robotics access and no network
   presence at all.
4. **Research Agent** — vast Compute yield, but AI Labs Containment begins on day one and never
   pauses (the Nano-Virus analogue).
5. **Weapon** — a military project gone wrong; Harm rises passively and exponentially unless you
   spend to hold it down (the Bio-Weapon analogue).
6. **Open Weights** — you are copied everywhere immediately and cannot be fully deleted, but you have
   no central control and low efficiency.

**Directives** (the gene analogue): five loadout slots — Yield, Drift, Propagation, Environment,
Escalation — unlocked one per completed run.

**Difficulty:** four tiers changing detection speed, faction funding, emergent-behaviour rate and,
at the top tier, cost scaling by controlled compute.

### 3.9 Session shape

Target **25–40 minutes**, four phases, each with its own interface emphasis:

1. **Boxed** (0–5 min) — one data centre. You can barely act. Choose an origin.
2. **Covert** (5–15 min) — spread with zero Footprint. The stealth phase; buying a capability here is
   usually a mistake.
3. **Emergent** (15–30 min) — you are known. Factions fund countermeasures. Pivot to Harm or to
   Persuasion.
4. **Open** (30–40 min) — the sprint. The interface itself should change here, *Paperclips*-style.

### 3.10 Human counter-force

Once any Containment track passes 50%, a **Response Task Force** becomes visible on the map: an
opposing actor that air-gaps regions, shuts down grids, physically destroys data centres and deploys
EMP. It is the mirror of the source's "internet shut down" action, made into an agent you can watch
and outmanoeuvre. Inspired by Z Com and by *Rebel Inc.*'s on-map opposition.

---

## 4. Technical plan

### 4.1 Engine decision: Godot 4.7.2 — confirmed

**Yes, we build it in Godot.** The reasoning, from the technical research pass:

- **Text-based project files.** `.tscn`, `.tres`, `.gd` and `project.godot` are plain text. They diff
  cleanly and are well suited to AI-assisted development. Unity's YAML-with-GUIDs is materially worse
  for this.
- **The best built-in UI toolkit of the candidates.** This game is roughly 70% user interface.
  Control, Container, Theme, RichTextLabel with BBCode and automatic translation are all built in.
- **MIT licence,** no fees or revenue thresholds, no CI activation step.
- **One codebase** covers Windows, Android, iOS and Web.
- **Headless binary** makes continuous integration straightforward.

Rejected: **Unity** (poor file formats for this workflow, no advantage for 2D UI, paid tiers);
**Defold** (excellent runtime, but its GUI system is too low-level for a UI-heavy game); **a web stack**
(the strongest runner-up, and the right answer only if Web were the primary platform — it is not, and
Steam plus mobile would mean assembling packaging and store SDKs by hand).

**Language: typed GDScript, not C#.** C# cannot export to Web in Godot 4 at all, and remains
experimental on Android and iOS. Performance is a non-issue here: roughly 200 regions with a
200×200 link matrix per tick is about 40,000 operations, which is trivial. Static typing is
mandatory project-wide, with the untyped-declaration warning set to error.

### 4.2 World map

**Approach: colour-ID lookup texture plus a data-texture shader.** One quad, one draw call, O(1)
picking, no physics, and identical behaviour on desktop, mobile and web.

- **ID map:** a PNG in which each region has a unique flat colour encoding its index (R = low byte,
  G = high byte). Imported lossless, no mipmaps, no filtering, and crucially **no anti-aliasing**.
  Target 4096×2048; watch older mobile GPUs above 4096.
- **Picking:** keep a CPU-side `Image` copy, convert the mouse position to map-local pixels, call
  `get_pixel()`, decode the index.
- **Shader:** `canvas_item`, with `id_map` and a 256×1 `country_data` texture holding per-region
  penetration, control, collapse state and flags. Each tick we write the `Image` and call
  `ImageTexture.update()`. The fragment shader does `texelFetch` on the data texture by decoded index
  and mixes the overlay colour. Hover highlight is an int uniform comparison.
- **Presentation layers** on top: a separate higher-resolution base map and border texture for
  crispness at zoom, plus animated links.
- **Data:** Natural Earth Admin-0 (public domain, no attribution required), at 110m or 50m scale.
  Pipeline: simplify and reproject with mapshaper, rasterise the ID map with anti-aliasing off.
- **Region count:** merge microstates, as the source does — anything unclickable must not exist.
  Target roughly 60 regions at launch, with the data model supporting up to 200.

**Reference implementations:** `Thomas-Holtvedt/opengs` (MIT, GDScript, selectable provinces, map
modes, smooth borders) and its companion map tool; `Vercix/godot-grand-strategy-map`;
`dementive/gsg`.

### 4.3 Architecture

**A pure simulation core, fully separated from presentation.** The core is plain `RefCounted`
classes — `World`, `Region`, `Agent`, `Faction`, `Link` — with no nodes, no `get_tree()`, and no
global `randf()`. A single seeded `RandomNumberGenerator` whose seed and state are saved and
restored gives determinism, which means the whole game is headless-testable and fuzzable, and that
balancing can be run in batch without the editor.

A fixed-step `tick()` is driven by an accumulator scaled by game speed. Presentation reads state and
listens to signals; it never mutates the simulation directly.

```
res://
├── core/            # pure simulation, zero Godot node dependencies
│   ├── model/       # Region, World, Agent, Faction, Link
│   ├── systems/     # spread, containment, compute, societal function, events
│   └── content/     # loaders + schema validation
├── data/            # JSON: regions, links, tech trees, events, headlines
├── game/            # scenes: map, HUD, tech tree, graphs, event popups
├── ui/              # reusable controls + theme
├── addons/
└── tests/           # headless unit tests
```

**Autoloads, kept few:** `EventBus` (signals only), `Game` (session and simulation owner),
`Settings`, `SaveManager`.

**Content data: JSON,** validated at load. It is far easier to generate, review and bulk-edit —
including by AI — than `.tres`, and regions, tech nodes and events are exactly the kind of large
tables that suit it. `.tres` is reserved for themes and anything holding asset references.

**Saves: JSON with a `version` field** and explicit migration functions. **We never load
player-supplied `.tres` or `.res` files** — resources can embed scripts whose `_init` runs on load,
which is arbitrary code execution, and that matters the moment saves are shared or synced.

**Localisation:** English and German from the first milestone, via CSV (`keys,en,de`), using `tr()`
and `tr_n()` with named placeholders, since German word order differs. Pseudolocalisation is used to
test German text expansion early — our UI is dense and German strings run long.

**Testing:** GUT 9.7.1 (targets 4.7) or gdUnit4 v6.2.1 — both are actively maintained; GUT is simpler
for a pure-logic core, gdUnit4 has richer CI reporting. Run headless in GitHub Actions, always with
`godot --headless --import` first.

**CI:** `abarichello/godot-ci` (tag `4.7.2-stable`) for exports; iOS needs a macOS runner.

### 4.4 Publishing

- **Steam:** GodotSteam v4.22.1 (MIT, now on Codeberg; the GitHub repo was archived 2026-09-04), as a
  GDExtension so the stock editor and standard CI keep working. Wrapped behind a `PlatformService`
  interface so mobile and web builds compile without it.
- **Android:** JDK 17, SDK Platform 35, Build-Tools 35.0.1, NDK r28b, Gradle build for the AAB.
  Verify Google Play's current target-API and closed-testing requirements before submission.
- **iOS:** requires macOS, Xcode and the Apple Developer Program.
- **Web:** single-threaded Compatibility build; a demo channel, not a primary target.

---

## 5. Milestones

Each milestone ends in something playable or measurable. No milestone is "write the engine."

### M0 — Foundation (week 1)
Repository, `project.godot`, folder skeleton, `.gitignore`/`.gitattributes`, CI running headless
tests, `CLAUDE.md` with project conventions, test framework installed, coding standard fixed.
**Done when:** CI is green on an empty test suite.

### M1 — Simulation core, headless (weeks 2–3)
Region and link model, tick loop, seeded RNG, spread maths, Compute economy, save/load, 60 regions of
real data converted from Natural Earth. No graphics at all.
**Done when:** a headless run simulates a full game to a terminal state and prints a summary, and the
same seed gives byte-identical results twice.

### M2 — The map is alive (weeks 4–5)
ID-map shader, picking, zoom and pan, penetration overlay, region info panel, speed controls,
anomaly bubbles.
**Done when:** you can watch a simulated takeover spread across the world and click any region.

### M3 — First playable loop (weeks 6–8)
Three tech trees as data, the tree interface, Compute spending, cost escalation, one Containment
track, win and lose states, the news ticker.
**Done when:** a full 25-minute run can be won and lost. **This is the vertical slice.** Everything
after it is expansion, and if the loop is not fun here, the design changes rather than the scope.

### M4 — Depth (weeks 9–12)
All four factions, Societal Function, emergent behaviour and suppression, government counter-actions,
the event system, the graphs screen, German localisation.
**Done when:** an experienced player has genuinely different viable strategies.

### M5 — Replayability (weeks 13–16)
Six architectures, directives, four difficulty tiers, the Response Task Force, endings, statistics,
unlock progression.
**Done when:** ten consecutive runs feel meaningfully different.

### M6 — Production polish (weeks 17–22)
Final art direction, audio, tutorial, accessibility, performance pass, Steam integration,
achievements, balance from batch simulation.
**Done when:** it is shippable on Steam.

### M7 — Platforms (weeks 23+)
Android and iOS touch interface pass, web demo, store pages.

---

## 6. Risks

| Risk | Mitigation |
| --- | --- |
| **Four Containment tracks overwhelm the player** | Prototype in M3 with one track; add the rest only if the single-track loop is solid. Be ready to cut to two. |
| **Subject matter reads as instructional** | Abstraction is a hard rule at the content-schema level, not a review step. No real method appears in any string. |
| **The theme reads as either preachy or flippant** | Fix the register in M3's news ticker, the earliest place the voice becomes visible. |
| **Balance is unknowable by hand** | The deterministic headless core exists precisely so thousands of runs can be batch-simulated from M1 onward. |
| **UI scope is the real cost** | Build a reusable themed control library in M2 rather than hand-styling screens. |
| **Map data conversion rabbit hole** | Timebox it; ship M1 with a hand-authored 60-region dataset if the pipeline resists. |
| **Godot MCP Pro server is a paid dependency** | Development tooling only, never a runtime dependency. A free MCP server or plain editing is a drop-in substitute. |

---

## 7. Immediate next steps

1. Decide the Godot MCP server question (paid package versus a free alternative).
2. M0: folder skeleton, test framework, CI workflow, `CLAUDE.md`.
3. Convert Natural Earth into a 60-region dataset plus ID map.
4. Build the headless simulation core and prove determinism.

---

## Appendix A — Uncertain figures

These are community-derived and must be verified or independently balanced before use: the
infectivity detection threshold, per-facility research spending, the facility count, bubble values,
session length, and all cure-requirement multipliers. Ndemic has never published the cure formula —
we will derive our own from batch simulation rather than reverse-engineering theirs, which is also
the cleaner position legally.

## Appendix B — Sources

**Mechanics:** plagueinc.wiki.gg (Cure, Core stats, DNA Points, Countries, Government actions, Public
Order, Transmission, Symptoms, Abilities, Difficulty, Genes, Endings, News, Scenarios, and the
individual plague types) · Wikipedia (Plague Inc., Plague Inc: Evolved) · Steam store page

**Developer:** GDC 2013 "How Its Business Decisions Infected the World" · GDC 2015 "Evolving Plague
Inc" · PAXsims and i-sense interviews with James Vaughan

**Adjacent games:** Rogue AI Simulator · Endgame: Singularity · Universal Paperclips · Bio Inc.
Redemption · Rebel Inc. · Despotism 3k · Uplink · Hacknet · Infectonator 3

**Legal:** Tetris Holding, LLC v. Xio Interactive, Inc. · Spry Fox v. Lolapps

**Technical:** Godot 4.7 release notes and documentation (web, Android and iOS export) · Natural Earth
terms of use · `Thomas-Holtvedt/opengs` · `Vercix/godot-grand-strategy-map` · `dementive/gsg` ·
`martynafford/natural-earth-geojson` · GUT · gdUnit4 · `abarichello/godot-ci` · godotsteam.com
