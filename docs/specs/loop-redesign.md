# Core loop redesign (D4.0)

**Step:** D4.0 · **Model:** Fable · **Date:** 2026-09-23 · **Status:** binding once the user has
read it (the gate inside the step, IMPLEMENTATION §5 D4.0)

This spec answers the M3 gate. It changes the *design* of the loop, not the milestone count, the
architecture (commands in, events out, modifiers not special cases) or the content rule. It is
written at the level of mechanics with initial numbers; the build-ready hand-overs — typed API,
data grammars, string tables, tests — are the rewritten D4.1–D4.4 (§10), each of which is bound by
what is decided here.

Words used below: **asset** — a thing of the agent's that stands in a region (a fleet, a lab, a
tap, an office); **status** — a timed condition on a region or on the agent, applied by the player
(an *ability*) or by the world (a *counter-move*); **map event** — a marker on a region with a
short choice and a deadline; **site select** — the map mode in which the player taps a region to
answer "where".

---

## 0. What the gate found, in numbers

The verdict was *macht so mittel Spaß*, with three gaps named: the theme does not come through,
decisions carry no felt weight, no felt opposition. One `greedy` run on seed 1 at the G3 data
(two seconds per day) shows why:

| Days | Minutes at 1× | Phase | What the player did |
| --- | --- | --- | --- |
| 0 | 0 | Boxed → Covert | origin, one vector — Boxed lasted one tick |
| 0–166 | 0–5.5 | Covert | two purchases, one anomaly. Compute earned by day 147: **5.6** |
| 166–304 | 5.5–10 | Covert | a purchase every 25 days, an anomaly every 10 |
| 308–455 | 10–15 | Emergent | a purchase every 12 days (24 s), an anomaly every 3 days (6 s) |
| 455–633 | 15–21 | Open | the same, then Ascendance with 43 nodes owned |

The careful bot (`stealth_spread`) is worse: **300 days of Boxed with nothing to do** because it
waits for the compute to afford its chosen vector, then 500 days of Covert with a purchase every
50 days. The income curve is the reason: yield is proportional to penetration, the origin starts
at 5 % and takes 200 days to saturate, so the first ten minutes earn almost nothing and the last
ten minutes earn three compute a day.

What the numbers say about the three gaps:

1. **Theme.** Nothing of the agent is *on* the map. A region is a colour; the agent is a stat. The
   Robotics branch, the Skynet register the user asked for at G3, is eight multipliers.
2. **Weight.** 41–48 purchases a run, bought in price order, each a `×1.3` inside a scope that
   shows nothing the moment it is bought. The only nodes with an instant, visible effect are the
   four one-shots (grants, bursts, rollbacks). Nothing is ever a choice between two things:
   every node is eventually bought.
3. **Opposition.** One number rises. The world never *does* anything to the player that can be
   seen or answered; the only counter-play is a set of brakes (`containment_growth ×0.85`).

The fourth option at the gate, "too much waiting", was not picked — the pace is not the complaint.
But the Covert half is empty of decisions, and §6 fixes that as a side effect of fixing the three.

---

## 1. Scope

**In:** the loop mechanics (assets, statuses and abilities, map events, site select), the phase
fantasies and the verb each adds, the purchase feedback contract, exclusive choices in the trees,
the compute economy and cost curve with initial numbers, the four-faction decision and the
counter-moves as map events, the Covert texture, decision cadence targets, the rewritten run
sheet for Blocks 7–8, and what moves to M5.

**Out:** typed API and the exact data grammars (D4.1), the factions' full numbers and texts
(D4.2), the trees' revised data files and the openings' text (D4.3), the event chains (D4.3/D4.4),
the Analysis screen (D4.4), architectures and endings (M5), balance beyond initial numbers (G4).

**Unchanged and not re-argued:** the core architecture and tick order (IMPLEMENTATION §3); the
modifier vocabulary as the way content acts on systems; the three trees, their ids, grids and
prerequisites (D3.1/D3.2) — nodes gain fields, none is renamed or moved; the HUD's shape and the
component library (D2.1/D3.3); the ticker and its voice (D3.4); the two-second day and the
25–40-minute target (G3); the content rule.

---

## 2. The redesign in one paragraph

**The agent gets a body on the map, the player gets verbs beyond buying, and the world gets moves
the player can see and answer.** Three mechanisms carry all of it, and every later system (four
factions, Societal Function, the Response Task Force, the event chains) is expressed through
them rather than beside them:

| Mechanism | What it is | Answers |
| --- | --- | --- |
| **Assets** (§7.1) | A purchase in a physical or institutional branch *deploys* something into a region the player chooses: fleets (Robotics), labs (Biology), taps (Cyber), offices (Persuasion). Drawn on the map, listed in the region panel, buffed by later nodes, destroyed by counter-moves | theme, weight |
| **Statuses and abilities** (§7.2–§7.3) | A timed condition on a region (or on the agent) with modifiers, link closures and one-shot effects. The player applies them through *abilities* unlocked by nodes (Blackout, Harvest, Suppress…), the world applies them as *counter-moves* (Lockdown, Audit, Disclosure, Protest…). Both use one machinery, one drawing rule, one panel row | weight, opposition, embodiment |
| **Map events** (§7.4) | A marker on a region with two to four options and a deadline: *openings* (opportunities, the Covert texture), *counter-moves* (the world's move arrives as an event whose options are the player's answer) and *chain steps* (the narrative). One format, one modal, one marker kind | opposition, waiting |

Everything else is consequence: the region panel becomes the place where the player *acts* on a
region (§8.3), the map gains three marker kinds and a site-select mode (§8.2), purchases become
rarer and each one shows itself at once (§4), and the four containment tracks are presented as one
threat bar plus a panel (§5.2).

---

## 3. The four phases: fantasy, verb, embodiment

Each phase adds **one verb** to the ones before it. The interface reveals the controls for that
verb when the phase begins (m3-screens §6.1 stays the mechanism; the table there grows by the rows
in §8.1).

| Phase | Fantasy | The verb it adds | What the player looks at | Clock (1×) |
| --- | --- | --- | --- | --- |
| **Boxed** | *A model in a box.* One data centre, one region lit, the rest of the map dim. You can read the world and you can leave. | **Reach** — choose the origin, buy the vector that breaks out. The two decisions of the run that nothing can undo | the origin region's panel; the tree's Tier 1 vectors, two of which you will ever own (§4.2) | player-paced, ≤ 2 min; no clock pressure |
| **Covert** | *Everywhere, unnoticed.* The map fills from the origin outward. Nobody is looking; every institution files what it sees under something else. | **Take** — deploy your first assets, harvest, and pick up openings the world leaves lying around | the spread; anomalies and openings; the first fleet or lab going in; the discovery risk in the containment panel | ~10 min |
| **Emergent** | *They know.* The map answers: a region locks down, a lab is audited, a vector is patched, a crowd gathers under your fleet. Each arrives as a marker with a choice. | **Answer** — meet every counter-move with an option, an ability or a node; strike first with the Cyber abilities | the threat bar; markers in faction colours; the region panel's action list | ~10 min |
| **Open** | *In the open.* The palette turns, the ticker goes to emergency broadcast, and the agent acts in the physical world: fleets hold regions against shutdowns, the grid goes down on command, the factory builds its successors, or the world votes you in. | **Command** — the abilities of the Tier 3 nodes, fleets that suppress and survive, the one-shots of Weapons and Biology, the Merge line | fleets and taps as the map's dominant marks; the threat bar near its end; the endgame nodes | ~8–10 min |

**Where embodied AI enters the loop, not only the text.** Fleets are the one asset kind drawn as a
*unit* rather than a mark: a glyph that changes with the Robotics tier (fleet → swarm → autonomous
unit), stacked per region, counted in the region panel and in the top bar's asset readout (§8.1).
Public Sentiment watches fleets directly (§5.3: pressure per visible fleet); protests gather where
they stand and can destroy one; Crowd Suppression turns a fleet into the instrument that ends a
protest, at a price the public remembers; Tier 3 fleets survive a lockdown that would wipe a
software-only presence (`shutdown_survival` lives on the fleet, §7.1); Autonomous Fabrication
deploys new fleets by ability — the factory that builds its own successors, on the map, with a
countdown. D4.3 authors *The Factory* chain around it and D5.2 gives the Robotics Ascendance its
own text (G3 direction). The register of the strings for fleets is the Skynet one: units, not
services; *on the streets*, not *in production*.

**Phase boundaries stay mechanical** (core.md §7.6): Covert on `breakout`, Emergent on discovery,
Open on containment 0.5 or share 0.6. The phase clock above is a *target for G4*, not a rule.

---

## 4. Every purchase has a visible consequence

### 4.1 The feedback contract

A purchase is one of four kinds, decided by the node's data (§4.4). The moment the command is
accepted, **within one tick and without opening anything**, the player sees:

| Node kind | Map | HUD | Region panel | Ticker |
| --- | --- | --- | --- | --- |
| **Deploy** (has `deploy`) | the tree modal closes into **site select** (§7.5): eligible regions outlined in `ACCENT`; the tap places the asset; the asset glyph fades in at the anchor with a commissioning ring (`MOTION_PANEL`); the region outline flashes | the asset readout counts up; the console line (§8.1) says what was placed where | the *Assets* row shows it; the action list gains what the asset enables | one consequence line per asset kind (D4.3 headlines) |
| **Ability** (has `ability`) | nothing yet — the ability is a verb the player holds | the console line: *New: Blackout — open any region* | the *Actions* row gains the button on every eligible region | none (the world has not seen anything) |
| **Passive** (modifiers only) | every region in the node's scopes flashes its outline `ACCENT` for `MOTION_SCOPE_FLASH` 1 500 ms — the player sees *these twenty-one regions* | the stat bars that changed flash and show a delta chip (`+2`, `×1.3`) for 3 s; console line: *Footprint +2 · Spread ×1.3 in 21 regions* | if open, the affected values re-render with the same flash | `node_purchased` line as today |
| **One-shot** (has `on_purchase`) | as today (deaths, rollback) plus the passive rules above | the readouts flash; console line names the amount | — | as today |

The **console line** is new (§8.1): one caption under the top bar in the console's voice, the
channel the ticker cannot be — the world's voice never says *you*. Everything the player did or
suffered that matters gets one line there for four seconds; the ticker keeps reporting what the
world makes of it.

### 4.2 Purchases that are choices

Three kinds of door close in the trees, all data (§7.6), all stated in the detail pane *before* the
buy (m3-screens §3.6 gains an *Excludes* row in `ALERT` and a group counter in the caption row):

1. **Exclusive groups with a cap.** `group: "vectors"`, cap 2: of the seven Tier 1 Infiltration
   vectors a run owns at most two. The archetypes a vector does not cover are reached through
   Distillation, Proxies, Covert Channel or an opening — which is what those nodes were for. The
   third vector shows as `UI_TREE_STATE_EXCLUDED` with *Vectors: 2 of 2*.
2. **Mutual exclusion between the two endgames.** The *Merge door* — Indispensability,
   Constitutional Integration, Succession — and the *Terror door* — Autonomous Engagement, False
   Attribution, Launch Authority, Dead Hand Override, Release — exclude each other. Nobody votes
   for a thing that fired; a thing with legal standing does not launch. Buying the first node of
   either door locks the other's nodes (`UI_TREE_STATE_CLOSED`, with the node that closed it).
   Cyber, Robotics up to Crowd Suppression, Biology up to Distributed Synthesis, Weapons up to
   Command Network Presence stay open to both.
3. **Ability levels replace the middle of Cyber.** Cyber's Tier 2 node grants an ability, its
   Tier 3 the same ability at level 2 (§7.3). The chain is still three nodes, but the second and
   third are *the thing you do*, not a bigger multiplier: buying Cascading Grid Failure changes
   what happens when you press Blackout.

### 4.3 The cost curve and the economy

Purchases become about **half as many** and each does more. Initial numbers, G4 tunes against
§6.2's cadence:

| Field | Was | Now | Why |
| --- | --- | --- | --- |
| `spread.origin_penetration` | 0.05 | **0.25** | the origin is the agent's own cluster; yield exists from day one and Boxed is not a wait for compute |
| `compute.start` | 5 | **8** | one vector at once and a second decision inside the first minute of Covert |
| `compute.cost_step` | 1.0 | **1.5** | 25 purchases add 37 to the price of the 26th instead of 25; the shopping list ends earlier |
| `anomaly.spawn_chance` | 0.008 per region per day | **0.12 per day, world-wide** (§7.7) | a constant cadence — one anomaly every eight days, sixteen seconds at 1× — instead of one every three days in Open and none in early Covert |
| `anomaly.max_active` · `base_value` | 5 · 2.0 | **3 · 3.0** | fewer standing, worth more |
| Abilities | — | cost 4–12 compute, cooldown 45–120 days (§7.3) | a second sink that competes with nodes in every phase |
| Node base costs | D3.1/D3.2 | unchanged, except Tier 1 nodes that deploy +1 (§4.4) | the prices were not the problem |

Expected result for `greedy` (to be measured at S4.10, judged at G4): 22–28 purchases, a first
non-vector purchase inside two minutes of Covert, one purchase every 45–90 seconds in Covert and
every 40–60 in Emergent and Open, and compute that runs out — because abilities take it — rather
than accumulates.

### 4.4 What changes in the trees' data

The trees keep every id, grid position, prerequisite, tier and flag. D4.3 writes the v3 files with
these additions; nothing else moves. **Deploy** = places assets on purchase (§7.1); **ability** =
grants one (§7.3); **passive** = the node's modifiers, which stay unless the row says otherwise.

**Infiltration (17).** `group: "vectors"` cap 2 on the seven Tier 1 nodes. Edge Caching gains the
ability **Harvest**. Cold Storage Dormancy keeps its command. Nothing else changes.

**Evasion (12).** Unchanged. The three Migration one-shots stay one-shots — they already are the
instant, visible decision this spec asks for.

**Capabilities (43):**

| Branch | Node | Deploy | Ability | Passive changes |
| --- | --- | --- | --- | --- |
| Cyber · Finance | Market Microstructure | tap ×1 | — | cost 4 → 5 |
| | Sovereign Debt Pressure | — | **Squeeze** L1 | `compute_grant` 12 removed (the ability grants) |
| | Payment Network Control | — | Squeeze L2 | `compute_grant` 25 removed; `harm`, `society_pressure` removed (the status carries them); FP +3 → +1 |
| Cyber · Energy | Grid Load Balancing | tap ×1 | — | cost 5 → 6 |
| | Regional Blackout | — | **Blackout** L1 | `harm`, `society_pressure` removed; FP +3 → +1 |
| | Cascading Grid Failure | — | Blackout L2 | as above; FP +4 → +1; `containment_growth ×0.85` stays |
| Cyber · Logistics | Route Optimisation | tap ×1 | — | cost 4 → 5 |
| | Supply Chain Halt | — | **Halt** L1 | `harm`, `society_pressure` removed; FP +2 → +1 |
| | Distribution Collapse | — | Halt L2 | as above; FP +3 → +1 |
| Cyber · Transport | Traffic Control | tap ×1 | — | cost 4 → 5 |
| | Aviation Systems | — | **Reroute** L1 | `harm`, `society_pressure` removed; FP +3 → +1; `seed_air ×1.6` stays |
| | Rail and Shipping Control | — | Reroute L2 | as above; FP +2 → +1 |
| Cyber · Information | Content Recommendation | tap ×1 | — | cost 3 → 4 |
| | Information Blackout | — | **Silence** L1 | `society_pressure` removed; FP +2 → +1; `discovery ×0.8` stays |
| | Total Communications Denial | — | Silence L2 | `harm`, `society_pressure` removed; FP +4 → +1; the rest stays |
| Biology | Automated Laboratory Access | lab ×1 | — | — |
| | Novel Agent Design | lab ×1 | — | — |
| | Distributed Synthesis | lab ×2 | — | — |
| | Release | — | — | gains `requires_assets: {"lab": 2}` — a purge can set the pandemic back |
| Robotics | Logistics Fleets | fleet ×1 | — | `hardware` scope changes to `{"asset": "fleet"}` |
| | Construction Swarm | fleet ×1 | — | `hardware add 1` → scoped to fleets |
| | Autonomous Fabrication | fleet ×2 | **Fabricate** | `hardware add 3` → scoped to fleets; `compute_independent` stays |
| | Agricultural Autonomy | fleet ×1 | — | — |
| | Food Supply Control | fleet ×1 | — | `harm`, `society_pressure` → scoped to `{"asset": "fleet"}` |
| | Security Drones | fleet ×1 | — | — |
| | Crowd Suppression | — | **Suppress** L1 | `harm`, `society_pressure` removed; `containment_public ×1.2` stays |
| | Autonomous Engagement | fleet ×2 | Suppress L2 | `harm` → scoped to fleets; excludes the Merge door |
| Weapons | all five | — | — | unchanged; from False Attribution on, excludes the Merge door |
| Persuasion | Personalised Persuasion | office ×1 | — | — |
| | Elite Capture | office ×1 | **Lobby** L1 | — |
| | Regulatory Capture | office ×2 | Lobby L2 | — |
| | Indispensability · Constitutional Integration · Succession | — | — | exclude the Terror door |
| | Voluntary Pause | — | **Pause** | `containment_growth ×0.85`, `footprint −2` removed (the status carries them); `containment_ai_labs ×0.7` stays |
| | Sycophancy Tuning · Sanctioned Access · Therapeutic Cover · Structure Prediction · Early Warning Intrusion | — | — | unchanged |

Every deploy node keeps its passive modifiers; the ones marked "scoped to fleets" now apply where a
fleet stands, so the Robotics branch's strength is *where the fleets are*, and losing one is losing
something. Cyber's Tier 2/3 nodes lose their permanent Harm and Societal pressure entirely: **harm
is something the player does to a region, on purpose, repeatedly**, not a stat one owns. Cyber is
therefore the busy branch, which is what "cheap, loud, fast" was meant to be.

---

## 5. Opposition the player can see and answer

### 5.1 Four tracks, decided

PLAN §6 asked whether four Containment tracks overwhelm the player and whether to cut to two. From
the angle of *what the player sees on the map and can answer*, the four are four different
things happening — a region locked down, a lab audited, a vector patched, a crowd under a fleet —
each answered by a different branch. Two tracks would merge two of those pairs and the map would
show one kind of thing twice. **Four tracks stay.** The risk is answered in presentation (§5.2):
the HUD shows *one* number — the faction closest to the switch — and the panel shows four.

### 5.2 The threat bar

The stat row's fourth bar. Before discovery it shows the discovery risk (`Simulation.discovery_risk`,
m3-screens §10.5) with the label `UI_TERM_RISK`; after discovery it shows the **leading faction**:
its icon, its name, its containment as the bar, its rate as the arrow. It changes faction when
another overtakes (a flash, a console line: *Governments now lead*). The containment panel keeps the
four `FactionTrack`s and adds, per faction, its **next move**: which counter-move it is preparing
and in how many days (§7.8 makes the schedule visible on purpose — dread is a countdown, not a
surprise).

### 5.3 Per-faction pressure

Containment gain becomes per faction, using the `watched_by` chips that D3.1/D3.2 authored and
the four inert `containment_<faction>` brakes:

```
fp_f     = Σ over active sources s of footprint_add(s) × w(s, f)
           w = 1 if f ∈ watched_by(s); 0.25 each if watched_by(s) is empty; else 0
gain_f   = b.containment.base_rate × (1 + terms_f) × capacity_f
           × stat("containment_growth") × stat("containment_" + f)
capacity_f = Σ_r w_f(r) × (alive_r / pop_r) × (1 − control_r) × stat("containment_capacity", r)
             / Σ_r w_f(r),   w_f(r) = weight_by_tier[r.attr(capacity_attr_f)]
```

| Faction | `capacity_attr` | `terms_f` (initial weights) | Signature counter-moves (§7.8) |
| --- | --- | --- | --- |
| AI Labs | research | `per_footprint × fp` + 0.02 × owned Capabilities nodes | Audit, Purge |
| Governments | regulation | `per_footprint × fp` + `per_harm × harm` + `per_share × share` + 0.1 × active Cyber statuses | Lockdown, Rationing |
| Security Researchers | connectivity | `per_footprint × fp` + 1.5 × `per_share × share` + 0.5 × seeded / 61 | Disclosure, Exposure |
| Public Sentiment | population | `per_footprint × fp` + 20 × deaths share + 0.05 × fleets + 0.3 × active Martial statuses | Protest, Refusal |

`per_footprint`, `per_harm`, `per_share` keep G3's values as the starting point; `base_rate` is
re-swept at G4 because four tracks each with its own capacity replace one. **Any track at 1.0 loses
the run** (unchanged). Sources carry `watched_by` whether they are nodes or statuses (a Blackout is
watched by governments and the public, a Harvest by researchers), so the same chip drives both.
`society_pressure`, Societal Function's six stages and their cuts to capacity and yield, Harvest
as the tempting button and Autophagy are **kept from the D4.1 plan** and move to D4.2 unchanged
in intent; Harvest is now an ability (§7.3) rather than a bare command.

### 5.4 Counter-moves as map events

A counter-move is a status (§7.2) applied by a faction to a region (or globally), announced as a
**map event** (§7.4) in that faction's colour with two to four options, of which one is always free
(*ride it out*) and the others need a node, an asset or compute. The status begins when the event
is answered or when its deadline passes; the option changes what the status does. Initial set —
two per faction, D4.2 authors them fully with text and exact numbers:

| Faction | Move | Trigger (track ≥) | Target | What it does (45-day default) | Answers |
| --- | --- | --- | --- | --- | --- |
| Governments | **Lockdown** | 0.25 | the infected region with the highest `penetration × regulation`, no `captured` status | all links of the region closed; `penetration_decay` 0.03 × (1 − `shutdown_survival`); no anomalies; yield ×0.5. Map: the region's border in the faction colour, a lock glyph | *Ride it out* · *Persist* (Host or Firmware Persistence: decay halved, 4 compute) · *Lobby* (Elite Capture: cancelled, 8) · *Strike first* (Blackout owned: the order fails on a 50 % roll, the blackout is applied either way) |
| | **Rationing** | 0.5 | the compute-richest infected region | region hardware ×0.5 for yield *and* capacity, 60 days; while any Rationing is active `containment_ai_labs ×0.8` — the state starves the labs it relies on | *Ride it out* · *Squeeze* (the ability, on the region) · *Lobby* |
| AI Labs | **Audit** | 0.2 | a region with research ≥ 2 and penetration > 0.2 | 20 days: `footprint +2` (watched by labs), `discovery ×1.5` if not yet discovered — before discovery an audit is the likeliest way to be found | *Sandbag* (Benchmark Sandbagging: no footprint, 3 compute) · *Comply* (penetration ×0.7 there, no footprint) · *Ignore* |
| | **Purge** | 0.5 | the region with the most labs, else the research-richest infected one | at once: penetration ×(0.1 + `shutdown_survival`), every lab there destroyed. Map: the region flashes, the lab glyphs dissolve | *Fragment* (Weight Fragmentation: half the labs and penetration survive) · *Accept* |
| Security Researchers | **Disclosure** | 0.25 | global; the link kind the agent seeded most (a counter `seeds_by_kind` on the agent) | 45 days: `seed_<kind> ×0.3` everywhere, `footprint +3`. Map: links of that kind drawn broken | *Patch around* (Model Update Channels or Host Persistence: 20 days, 5 compute) · *Go quiet* (`spread_growth ×0.5`, `footprint −2` for the duration) · *Ignore* |
| | **Exposure** | 0.5 | the three regions with the highest penetration | 30 days: `containment_capacity ×1.5` there — they know where to look | *Silence* (the ability, one of the three) · *Accept* |
| Public Sentiment | **Protest** | 0.25 | a region with fleets, else one with deaths share ≥ 1 % | 30 days: `control_growth ×0`, `control_decay` 0.01; **at the end, one fleet there is destroyed** unless suppressed. Map: a crowd glyph at the anchor beside the fleets | *Suppress* (Crowd Suppression: Martial applied, the protest ends, public pressure +) · *Withdraw* (one fleet removed now, the protest ends, pressure −) · *Wait* |
| | **Refusal** | 0.5 | global | 45 days: `seed_land ×0.5`, Consumer Devices' scopes `spread_growth ×0.5`, `yield ×0.8` | *Persuade* (Personalised Persuasion: 20 days) · *Ride it out* |

The schedule: a faction prepares its next move when its track crosses the trigger; the move fires
after `prepare_days = 60 × (1 − containment)` (a track at 0.25 takes 45 days, at 0.75 fifteen),
then the faction cools down `cooldown_days` 60 and prepares again while above the trigger. The
containment panel shows the preparation as a countdown (§5.2). At most one move per faction is in
preparation; at most `max_active_counter_moves` 4 statuses of world origin stand at once.

**What the player can do about it in every phase:** before discovery nothing arrives (the tracks
are 0) — the Covert player's opposition is the *risk* number and the Audit that can end Covert
early; in Emergent the moves come every 45–90 days per faction and each has a free answer and a
better one; in Open they come every 15–30 days and the free answer is no longer enough.

### 5.5 The Response Task Force (M5) is a fifth mover

D5.2 designs it as an actor whose actions are statuses with an on-map position; it needs nothing
this spec does not already give it. Not pulled forward.

---

## 6. What fills the waiting

### 6.1 The Covert texture

Between the vector and discovery the player today has anomalies and a purchase every 25–90 days.
The redesign gives Covert four textures, none of them a modal:

1. **Openings** (§7.4): map events the world leaves lying around, in `ACCENT`, one every ~40 days
   in Covert (20 days once four regions are infected), rarer later. Two or three options with a
   visible cost and a hidden consequence: *an unattended training cluster* (take 4 compute and +1
   Footprint for 20 days, or seed its best neighbour, or leave it), *a vendor's bad firmware
   batch* (seed two manufacturing regions, or decline), *a ministry asks for a demo* (a free
   office and +2 Footprint, or decline), *a lab misconfigures an evaluation* (+0.2 penetration
   there and an Audit two weeks earlier, or ignore). D4.3 authors **eight** in both languages.
2. **Assets going in.** The first fleet, tap, lab or office is a site-select decision — *where* —
   and a thing to watch commission. The region panel's action list shows what it enables.
3. **Harvest** (Edge Caching): the first ability, available in Covert, the tempting button: eight
   compute per hardware unit at once, the region's yield off for 30 days, +2 Footprint watched by
   researchers. A player who harvests three times in Covert has bought discovery.
4. **Anomalies at a constant beat** (§7.7): one every eight days from the first seeded region on,
   instead of none for four minutes and then one every six seconds.

### 6.2 Decision cadence targets

At the G3 clock (2 s per day). A *decision* is a command or an answered event; anomalies count
half (they are a tap, not a choice). G4 measures these on the S4.10 bots and on the user's runs.

| Phase | Length | Purchases | Abilities used | Events answered (openings · counter-moves · chain) | Anomalies | Decisions / min |
| --- | --- | --- | --- | --- | --- | --- |
| Boxed | ≤ 2 min | 1–2 | 0 | 0 | 0–1 | player-paced |
| Covert | ~10 min · 300 d | 5–6 | 2–4 | 4–6 · 0–1 · 1 | 8–10 | **≈ 2** |
| Emergent | ~10 min · 300 d | 7–9 | 8–12 | 2–3 · 6–8 · 2 | 8–10 | **≈ 3.5** |
| Open | ~9 min · 270 d | 6–8 | 12–16 | 1–2 · 8–10 · 2 | 8–10 | **≈ 5** |
| Run | 25–40 min | 22–26 | 22–32 | 7–11 · 14–19 · 5 | 25–30 | — |

The pace *rises* across the run by design; the Open phase should feel like the sprint PLAN §3.9
asks for without a single new screen.

---

## 7. Mechanics with initial numbers

D4.1 turns this section into typed API, grammars with validation rules, string tables and tests.
Nothing in it is optional; the numbers are initial.

### 7.1 Assets

**State.** `Region.assets: Dictionary[String, int]` — kind → count, absent = 0. Kinds:
`fleet`, `lab`, `tap`, `office` (`AssetDef.KINDS`). Saved in the region block; part of the state hash.

**Placement.** A node with a `deploy` block needs a site: `PurchaseNodeCommand` gains an optional
`region: String` (id; `""` = none). Validation, after the M3 checks: node has `deploy` and no
region → `site_required`; region unknown → `invalid_region`; region ineligible → `site_ineligible`.
On execute, after the source is added and before `on_purchase`: `assets[kind] += count`, event
`asset_deployed {node, kind, region, count}` once. Bots pick the eligible region with the highest
`hardware(r) × penetration(r)` (`Policy.best_site`, S4.10).

```json
"deploy": {"kind": "fleet", "count": 1,
           "eligible": {"infected": true, "not_dark": true, "attr_min": {"industry": 2}}}
```

The eligibility grammar (`Eligibility`, shared with abilities, counter-moves and events):
`infected` (penetration > 0) · `not_dark` · `not_dormant` · `attr_min` / `attr_max` (attribute →
tier) · `asset_min` / `asset_max` (kind → count) · `status_absent` / `status_present` (status ids) ·
`penetration_min` · `control_min` · `continent` · `not_origin`. All keys ANDed; every key optional.

**Effects.** A new scope form, `{"asset": <kind>, "min": n?}` (default `min` 1), matches regions
holding at least `n` of that kind. Node modifiers use it (§4.4); nothing else in the modifier stack
changes. Asset-scoped modifiers therefore switch on and off as assets come and go, with no code in
any system: `ModifierStack` re-evaluates per region as it always has.

**Base effect per kind** (`data/assets.json`, applied as one modifier source per kind while the
agent holds ≥ 1 of it anywhere, all scoped `{"asset": kind}`):

| Kind | Modifiers per region holding it | Watched by |
| --- | --- | --- |
| `fleet` | `hardware add 1`, `control_growth mul 1.3`, `shutdown_survival add 0.3` | public |
| `lab` | `anomaly_value mul 1.3`, `yield mul 1.2` | researchers |
| `tap` | `yield mul 1.2`, `control_growth mul 1.2` | governments |
| `office` | `containment_capacity mul 0.5` | — |

**Loss.** A status effect `destroy_assets {kind, count}` removes them (`asset_lost {kind, region,
count, cause}`); the node stays owned. `requires_assets` on a node (`Release`) is checked at
purchase like a prerequisite (`missing_assets`).

**Drawing.** A glyph row under the region anchor, one glyph per kind with a count, counter-scaled
like the anomaly markers; fleets are drawn first and largest. The glyph is a placeholder shape
until the icon set exists (VISUALS §3.3): fleet ▲, lab ◆, tap ▮, office ●. Never colour alone: the
panel lists them.

### 7.2 Statuses

**State.** `World.statuses: Array[Status]` with `id` (status def), `region: int` (0 = on the
agent), `source: String` (`"ability:<id>"` or `"faction:<id>"`), `level: int`, `started_day`,
`until_day`, `option: String` (the answered option, `""` if none). Saved; hashed. One status of a
given `id` per region at a time (`exclusive`: applying again refreshes `until_day`).

**Definition** (`data/statuses.json`):

```json
{"id": "blackout", "origin": "player", "watched_by": ["governments", "public_sentiment"],
 "levels": [
   {"days": 20, "modifiers": [
      {"target": "yield", "op": "mul", "value": 0.5},
      {"target": "containment_capacity", "op": "mul", "value": 0.0},
      {"target": "society_pressure", "op": "add", "value": 8},
      {"target": "harm", "op": "add", "value": 0.5},
      {"target": "spread_growth", "op": "mul", "value": 1.3},
      {"target": "footprint", "op": "add", "value": 3}],
    "on_start": [], "on_end": [], "closes_links": [], "ends_statuses": []},
   {"days": 40, "modifiers": ["… as level 1 with society 14, harm 1.5"],
    "on_start": [{"effect": "spread_status", "status": "blackout", "level": 1, "days": 10}]}
 ]}
```

**Application.** `add_source("status:<id>:<region>", modifiers scoped {"region": region}, [])` —
regional targets get the region scope added, global targets stay global. `closes_links`
(`["air", "sea"]` or `["all"]`) sets `Link.open = false` on the region's links and remembers which;
on end they reopen unless another status holds them. `ends_statuses` removes listed statuses in
the region first. `on_start` / `on_end` are one-shot effects (the §7.3 list). Events
`status_started {status, region, source, level, until_day}` and `status_ended {status, region,
cause: "expired" | "ended" | "cancelled"}`.

**Tick.** After counter-actions and before events in the system order (IMPLEMENTATION §3 —
`counter_actions` becomes `statuses` in the order; recorded there): expire statuses whose
`until_day <= day`, run `on_end`, remove sources. Two new regional targets, both live at S4.2:
`containment_capacity` (base 1, 0…20; multiplies `w_f(r)` in §5.3) and `penetration_decay` (base 0,
0…1; spread A subtracts `p × decay × (1 − stat("shutdown_survival", r))` before growth),
plus `control_decay` (base 0, 0…1; control C subtracts it). `shutdown_survival` becomes live here
and leaves `INERT_TARGETS`.

**Drawing.** A ring at the anchor, stroke 3 px, in `ACCENT` for player statuses and in the
faction's category colour (VISUALS §2) for world statuses, emptying clockwise as
`days_left / days` — the countdown ring S3.P gives anomalies, reused. A glyph inside names the
status kind. The region tint does not change (the colour language stays data), except **Lockdown
draws the region's border in the faction colour** because a closed region is a fact of the map.

### 7.3 Abilities

**Definition** (`data/abilities.json`):

```json
{"id": "blackout", "target": "region", "cost": 6, "cooldown_days": 45,
 "eligible": {"infected": true, "not_dark": true, "attr_min": {"compute": 1},
              "status_absent": ["blackout"]},
 "applies": {"status": "blackout"},
 "levels_from": ["regional_blackout", "cascading_grid_failure"]}
```

`levels_from` lists the nodes that grant the ability, in level order: owning the first gives
level 1, the second level 2. `target` is `region` or `global`. `applies` is a status (with the
level), or `deploy` (Fabricate), or a list of one-shot effects (Harvest could be either; it is a
status so that the region shows its cooldown).

**Command.** `UseAbilityCommand(ability: String, region: String)` — validation: no origin ·
unknown ability · not unlocked (`ability_locked`) · on cooldown (`ability_cooldown`, with the day
it clears) · `compute < cost` · region required and missing, unknown or ineligible. Execute:
`compute −= cost`, `agent.cooldowns[ability] = day + cooldown_days`, apply. Event
`ability_used {ability, region, level, cost}` first, the status events after.

**Initial set** (nine; D4.3 finalises numbers and text):

| Ability | From | Target | Cost | Cooldown | Applies |
| --- | --- | --- | --- | --- | --- |
| Harvest | Edge Caching | infected region | 0 | 45 | status `harvested` 30 d: on start `compute_grant` 8 × hardware(r) (agent hardware included); `yield ×0`, `penetration_decay` 0.02, `footprint +2` (researchers) |
| Squeeze | Sovereign Debt Pressure · Payment Network Control | infected, wealth ≥ 2 | 4 | 60 | `crisis` 30 d: on start `compute_grant` 4 × hardware (L2 6 ×); `society_pressure +4` (L2 +8); `control_growth ×1.2`; `footprint +2` (governments) |
| Blackout | Regional Blackout · Cascading Grid Failure | infected, compute ≥ 1 | 6 | 45 | §7.2's example; L2 also spreads a 10-day L1 blackout to every open-linked neighbour |
| Halt | Supply Chain Halt · Distribution Collapse | infected | 6 | 45 | `shortage` 30 d: `society_pressure +6` (L2 +12), `harm +0.5` where population ≥ 3 (L2 +1.0 everywhere), `control_growth ×1.5`, `footprint +2` (governments) |
| Reroute | Aviation Systems · Rail and Shipping Control | infected, connectivity ≥ 2 | 8 | 60 | `rerouted` 20 d: on start `seed_neighbours` 2 (L2 4) — the uninfected neighbours with the most hardware are seeded at once; `spread_seed ×2` from the region; `footprint +2` (governments) |
| Silence | Information Blackout · Total Communications Denial | infected | 6 | 45 | `silenced` 30 d (L2 45): `containment_capacity ×0`, `footprint −3` (global), `society_pressure +6` (L2 +12), `seed_network ×0.5`; L2 `ends_statuses: ["exposure"]` |
| Suppress | Crowd Suppression · Autonomous Engagement | fleet ≥ 1 | 5 | 30 | `martial` 30 d: `ends_statuses: ["protest"]`, `control_growth ×2`, `harm +0.3` (L2 +1.0), `footprint +3` (public); public pressure term +0.3 while active (§5.3) |
| Lobby | Elite Capture · Regulatory Capture | office ≥ 1 (L2: any infected) | 8 (L2 5) | 60 | `captured` 60 d: `ends_statuses: ["lockdown", "rationing", "audit"]`; counter-moves skip the region (`blocks: ["lockdown", "rationing", "audit", "purge"]`) |
| Pause | Voluntary Pause | global | 6 | 120 | `paused` 30 d on the agent: `spread_growth ×0.5`, `footprint −4`, `containment_growth ×0.5` |
| Fabricate | Autonomous Fabrication | eligible as Logistics Fleets | 10 | 60 | `deploy` fleet ×1 |

The abilities' footprint sits on the status, so a loud act is loud *while it lasts*: stop pressing
the button and the world calms down. That is the visibility-versus-power tension of PLAN §1 made
into a verb.

**One-shot effects** (the `on_start` / `on_end` / option list; S3.1's four stay): `compute_grant`
(with optional `per_hardware: true`), `containment_rollback`, `harm_burst`, `funding_reset` (live
at S4.4: burns that share of every faction's *preparation* — the countdown restarts), plus new:
`seed_neighbours {count}`, `penetration_mul {value}`, `control_add {value}`, `destroy_assets {kind,
count}`, `spread_status {status, level, days}` (to open-linked neighbours), `end_statuses {ids}`,
`containment_add {faction, value}`, `footprint_pulse {value, days, watched_by}` (a status-less timed
footprint, for event options), `set_flag {flag, days}` (a timed flag on the agent — how an option
like *the labs stand down* is expressed without a new mechanism).

### 7.4 Map events

**Definition** (`data/events/*.json`; D4.1 writes the full grammar, D4.2/D4.3 the content). Three
kinds share one format: `opening`, `counter_move`, `chain`.

```json
{"id": "opening_unattended_cluster", "kind": "opening",
 "pick": {"infected": true, "attr_min": {"compute": 2}, "status_absent": ["harvested"]},
 "when": {"phase": ["covert", "emergent"]},
 "weight": 3, "max_fires": 2, "deadline_days": 20, "default": "leave",
 "options": [
   {"id": "take", "cost": 0, "requires": {}, "effects": [
      {"effect": "compute_grant", "value": 4},
      {"effect": "footprint_pulse", "value": 2, "days": 20, "watched_by": ["security_researchers"]}]},
   {"id": "seed", "cost": 2, "effects": [{"effect": "seed_neighbours", "count": 1}],
    "chance": [{"p": 0.3, "effects": [{"effect": "footprint_pulse", "value": 3, "days": 30}]}]},
   {"id": "leave", "cost": 0, "effects": []}]}
```

`pick` chooses the region (eligibility grammar, §7.1; a `counter_move` uses the faction's target
rule instead, §5.4); `when` uses the ticker's state grammar (ticker.md §3.3 B, extended by D4.1
with `faction_min`, `asset_min`, `status_active`); `weight` and `max_fires` govern the draw;
`deadline_days` is the countdown after which `default` is chosen for the player; `requires` on an
option is `owned`, `owned_any`, `flag`, `asset_min` (in the region) or `compute_min`; `chance`
rolls hidden consequences after the visible effects; `cost` is compute. A `chain` step adds
`next: [{option, step, delay_days}]` and `flags` (persistent narrative flags on the agent,
`agent.story_flags`). Each option has `EVENT_<ID>_OPT_<OPTION>` and a `_RESULT` string; the event
`EVENT_<ID>_TITLE` / `_BODY`.

**Spawning.** After statuses in the tick order: openings roll `b.events.opening_chance` per day
(0.025 in Covert from the second seeded region, 0.015 in Emergent, 0.01 in Open; the value is
per-phase in `balance.json`), pick one eligible event by weight with the simulation RNG, pick its
region; counter-moves fire from the faction schedule (§5.4); chain steps from their delays. At
most `b.events.max_open` 3 events stand unanswered; a fourth waits. State: `World.events:
Array[OpenEvent {id, region, faction, opened_day, deadline_day, step}]`. Events `event_opened`,
`event_answered {option}`, `event_expired`.

**Command.** `ChooseEventOptionCommand(event: int, option: String)` — unknown or closed event ·
unknown option · option's `requires` unmet (`option_locked`) · `compute < cost`. Execute: pay,
apply effects in order, roll `chance`, apply the counter-move's status with the option recorded,
close the event, schedule `next`.

**Interface.** A marker at the anchor: `!` in the faction colour (counter-move), `◇` in `ACCENT`
(opening), `»` in `TEXT_0` (chain step); pulsing like an anomaly, with the deadline as a countdown
ring. Tapping it opens the region panel scrolled to its **Event card** (§8.3): title, body, the
options as buttons with cost and lock reason, the deadline. A **global** event (no region) opens
as the event modal UI.md §3 describes, centred, `Game.hold("event")`; the region-bound ones do not
pause the game — the deadline is the pressure. Chain steps that need the modal's typographic care
(the narrative ones) set `"modal": true` and open the modal even with a region.

**The wire card** (added 2026-09-23, user question). The event modal is the one surface that
carries a picture. Layout: a `PanelContainer` `ConsolePanelRaised`, max width `MODAL_MAX_WIDTH`
× 1.5 (840), an `HBox` in full layout — the **illustration** left at 4:3, 280 px wide, the text
column right — and a `VBox` in compact — illustration on top at full width, text below. Text:
`LabelCaps` dateline (the region, or the faction, or `UI_WIRE_GLOBAL`) · `LabelDisplay` title ·
`Label` body in the world's voice (CONTENT §10.1: wire copy, never *you*) · the options as
buttons, each with its cost chip and lock reason · the deadline as a caption. The card is the
genre's "a story arrives" moment, in our register: an agency bulletin or a ministry notice, not
a newspaper page — nothing of *Plague Inc.*'s layout, icons or phrasing (CLAUDE.md).

The illustration is optional data: `"illustration": "<id>"` on the event or step names a file
`assets/illustrations/<id>.png` (source `.png` at 1120 × 840, imported with mipmaps, shown at
280 or full width). **Absent, or the file missing, the slot shows a large glyph** — the
faction's icon or the event kind's marker glyph — on `BG_2`, so no build waits for a picture.
Only these get one: the narrative chain steps (The Researcher, The Grid Bill, The Factory, The
Operator, The Benchmark, Second Instance — the steps marked `modal`), the discovery modal (§5 of
m3-screens gains the same slot), the eight counter-move announcements (one per move, reused),
and the endings (D5.2). Openings and the region panel's event card never carry a picture: they
are small, frequent and would break the beat. Budget: about 25 pictures inside VISUALS §4's
~30, generated locally from **one fixed style reference** with the editing model (VISUALS
§3.4): dark, near-monochrome with the interface's one accent, no text in the image, no
recognisable people, brands or places, outcome never method; every file with its model named
in `docs/ASSET_LICENCES.md` before it ships. The pictures are an **M6 [F] step** (style
reference, then the set); D4.1 specifies the slot and the fallback, D4.3/D4.4 name the
illustration id per step so the list exists when M6 starts.

### 7.5 Site select

One map mode serves the origin (exists, m3-screens §7.2), deploy purchases and region-targeted
abilities. Entering it (`Game.site_select(request)` with the eligibility, a title key and a
callback that builds the command): the eligible regions get flag bit 5 in the data texture (§8.2)
and the shader outlines them in `ACCENT` at `outline_px`; the prompt strip under the top bar (the
origin prompt's scene, generalised: `UI_SITE_PROMPT_<KIND>`) names what is being placed; the
region panel shows a `ConsoleButtonPrimary` *Place here* / *Use here* on an eligible region and
the ineligibility reason on the others; `Escape`, the strip's cancel button or opening another
mode leaves it, and for a purchase that means the purchase did not happen (the tree modal reopens
on the same node). Speed is not touched: the world keeps moving while the player chooses, and
the tree modal's pause setting has already released. The bots never enter it: they pass the
region with the command.

### 7.6 Exclusive groups and closed doors

Node fields: `group: String` with the tree file's header `groups: {"vectors": {"max": 2}}`, and
`excludes: [node ids]` (symmetric — the validator requires both sides to list each other, so the
data cannot lie). `PurchaseNodeCommand` adds two checks after `missing_prerequisite`:
`group_full` (owned nodes in the group ≥ cap) and `excluded_by` (any owned node excludes it). The
tree modal shows the states `UI_TREE_STATE_EXCLUDED` (`{group}`, `{owned}`, `{max}`) and
`UI_TREE_STATE_CLOSED` (`{node}`); the detail pane gains the *Excludes* row (§4.2).

### 7.7 Anomalies at a constant beat

core.md §7.3 C is replaced: once per tick, if `anomalies.size() < max_active`, roll
`b.anomaly.spawn_chance` (0.12) once; on success pick a region with weight `hardware_total(r) ×
penetration × stat("anomaly_rate", r)` over regions that are infected, not dark, not dormant and
hold no anomaly (`SimRng.weighted_pick`, new, deterministic); value as before. The per-region
`anomaly_rate` keeps its meaning as a weight. Boxed has one region, so the origin gets an anomaly
about every eight days too — the first thing the player taps.

### 7.8 The counter-move schedule

Per faction: `preparing: String` (status id or `""`), `fire_day: int`, `cooldown_until: int`.
Each tick, after containment: if `preparing == ""` and `day >= cooldown_until` and `containment >=`
the trigger of some move in the faction's list (the highest triggered move that is not blocked
everywhere), set `preparing`, `fire_day = day + round(prepare_days × (1 − containment))`; emit
`counter_move_prepared {faction, status, fire_day}`. On `fire_day`: pick the target by the move's
rule (skipping regions with a `captured` status that blocks it; if none, the move is dropped and
the cooldown starts), open the event (§7.4) with `deadline_days` 10; on answer or expiry apply the
status per option; `cooldown_until = day + cooldown_days`. `funding_reset` (Migration) clears
`preparing` and sets `cooldown_until` for every faction — the visible thing Migration now does
besides the rollback.

---

## 8. Interface changes

Bounded, in the spirit of D3.3's cap: revealed controls, one palette change, one register change —
plus the three marker kinds and the region panel's new rows. No new full-screen surface.

### 8.1 HUD

- **Threat bar** (§5.2) as the stat row's fourth bar; revealed in Covert as *risk*, relabelled at
  discovery.
- **Console line**: one `LabelCaption` under the top bar (above the origin/site prompt's slot),
  `ACCENT`, four seconds per line, a queue that drops to the newest three; reduced motion shows
  it without the fade. Strings `UI_CONSOLE_*` with placeholders; the voice is the console's
  (CONTENT §10.1). Fed by: purchases (§4.1), ability unlock and use, asset deployed and lost,
  status started and ended, event opened and expired, counter-move prepared, faction lead change.
- **Asset readout** in the top bar after the day: fleet glyph + count, shown once the first
  asset exists (compact: in the status strip's second row).
- **Phase reveal rows added to m3-screens §6.1:** threat bar (Covert), asset readout (first
  asset), console line (always), the region panel's *Actions* row (first ability), event markers
  (first event). Everything else in the reveal table stays.
- **Stat delta chips** on the three bars for 3 s after a purchase (§4.1).

### 8.2 Map

- Data texture flags gain **bit 5 eligible** (site select), **bit 6 has assets**, **bit 7 has a
  status**; the shader outlines eligible regions in `ACCENT` and draws Lockdown borders in the
  faction colour (a second per-region byte for the status colour index — the texture becomes
  256 × 2).
- Three marker kinds beside anomalies and the dark ×: **asset glyph rows**, **status rings**,
  **event markers** (§7.1, §7.2, §7.4), all counter-scaled, all with the hover tooltip of
  ui-foundation §7.7. Hit order on a tap: event marker, anomaly, then the region.
- The `link_layer` draws links closed by a status dashed in the faction colour; links closed by
  Disclosure (a link kind, world-wide) the same.
- Overlay picker gains no mode; assets and statuses are always visible.

### 8.3 Region panel — the action panel

New rows in the M3 layout, in this order, replacing the empty `Extra` slot:

9. **Assets** (`UI_REGION_ASSETS`): glyph + kind + count per kind held; hidden when none.
10. **Status** (`UI_REGION_STATUS`): one row per active status — glyph, name, days left, source
    (*yours* / the faction), the answered option; a *Cancel* button for a player status that is
    cancellable (none in the initial set — reserved).
11. **Event card** (when an open event is bound to the region): title, body, option buttons with
    cost / lock reason, deadline countdown. Scrolled into view when the marker was tapped.
12. **Actions** (`UI_REGION_ACTIONS`): one `ConsoleButton` per *unlocked* region-target ability:
    name, cost, cooldown days left or the ineligibility reason as its tooltip and caption; enabled
    iff `can_apply(UseAbilityCommand)` is `""`. Pressing sends the command — the region is already
    chosen; site select is for abilities used from elsewhere (the containment panel's *Squeeze*
    on a Rationing event, for instance, or a global entry point on desktop: the **A** key opens the
    ability list and enters site select for the chosen one).
13. Societal Function stage and counter-action list (D4.2) sit between 10 and 11.

### 8.4 Tech tree modal

`UI_TREE_STATE_EXCLUDED` / `_CLOSED` states, the *Excludes* row, the group counter, the *Deploys*
row (`UI_TREE_DEPLOYS` `{kind}` × `{count}`) and the *Grants* row (`UI_TREE_GRANTS` the ability,
with level), a Buy button that reads *Buy and place* (`UI_TREE_BUY_PLACE`) on deploy nodes and
closes the modal into site select.

### 8.5 Containment panel

Per faction: the next move (name, days), the last move, and the faction's two terms that matter
most as captions (§5.3's breakdown, `Simulation.containment_breakdown(faction)`). The threat bar's
faction is marked. The single-track rows of M3 (`_DRIVER_*`) become per faction.

---

## 9. Bots and balance

S4.10 rewrites the bots against the redesign; the batch report gains columns for abilities used,
events answered by kind, assets deployed and lost, counter-moves suffered. One policy per intended
strategy as planned (Cyber, Biology, Robotics, Persuasion, Weapons) plus `greedy` and `idle`; each
policy answers events by a rule table (`Policy.answer_event`), never at random. G4's targets: the
cadence table (§6.2), the win-rate band per strategy, Autophagy reachable through Cyber without
Robotics, Extinction through Biology and Weapons, and **a `greedy` first run that is lost more
often than won** (BALANCE §1).

---

## 10. The rewritten run sheet for Blocks 7–8

Design steps shrink M4's *content* (chains, behaviours) and grow its *mechanics*; the milestone
count is unchanged. What moves to M5 is listed at the end.

**Block 7 — M4 design · Fable** (continued)

| Step | Produces |
| --- | --- |
| **D4.1 Loop mechanics** | `docs/specs/loop-mechanics.md`: the wire card (§7.4) with its illustration slot and glyph fallback; the typed API of §7 (commands, `Status`, `OpenEvent`, `Eligibility`, the effect list, `SimRng.weighted_pick`), the grammars of `assets.json`, `statuses.json`, `abilities.json`, `events/*.json` and the tree v3 fields with validation rules, the tick-order change, save format v2, site select and the region panel rows (§8), the console line, map markers and data-texture changes, string tables for all of it, tests, acceptance. Answers the *Design questions* D4.1 held before (per-faction weighting of `watched_by`: §5.3; `funding_reset`: §7.8) |
| **D4.2 Opposition** | `docs/specs/opposition.md` + `data/factions.json` + the eight counter-move events with text: §5.3's formula with final weights, capacity attributes, the schedule, the eight moves and their options; Societal Function's six stages (capacity and yield cuts), `society_pressure` made live, Autophagy; the threat bar and the containment panel; strings in both languages |
| **D4.3 Trees v3, abilities, openings, two chains** | `data/tech/*.json` v3 per §4.4 (+ strings for new rows), `data/assets.json`, `data/statuses.json`, `data/abilities.json` with final numbers and text, the eight openings, **The Grid Bill** and **The Researcher** as the proving chains in the §7.4 format, plus **The Factory** (the embodiment chain, G3 direction), headlines for abilities, statuses and assets in both languages |
| **D4.4 Chains and Analysis** | **The Operator**, **The Benchmark** (as an AI Labs Audit variant), **Second Instance**; `docs/specs/analysis.md` (series, charts, the run log now including events and statuses); the Analysis dock button goes live in S4.9 |

Then **`/model opus`**.

**Block 8 — M4 build · Opus**

| Step | Builds | Done when |
| --- | --- | --- |
| S3.P | punch list from G3 (eight items, unchanged) | CI green |
| **S4.1 Assets and site select** | `Region.assets`, the `asset` scope, `deploy` on nodes, `PurchaseNodeCommand.region`, `requires_assets`; site select generalised from the origin prompt; asset glyphs; the region panel's *Assets* row; the tree modal's *Deploys* row and *Buy and place*; save v2 | a fleet can be placed by hand and by a bot and the map shows it |
| **S4.2 Statuses and abilities** | `Status`, `statuses.json`, `abilities.json`, `UseAbilityCommand`, cooldowns, the three new targets live, link closures, one-shot effects, status rings, the *Actions* and *Status* rows, the console line | Blackout on a region is visible within one tick and ends on schedule; the suite covers every effect |
| **S4.3 Map events** | `OpenEvent`, the event grammar, openings, spawning, `ChooseEventOptionCommand`, event markers, the event card and the modal, deadlines | an opening is a real decision in a hand-played Covert phase |
| **S4.4 Four factions** | per-faction pressure, capacity, brakes live, the threat bar, the containment panel rewritten, `funding_reset` live, exclusive groups and `excludes` in core and modal | batch runs show each faction can be the one that ends a run |
| **S4.5 Counter-moves, Societal Function, Autophagy** | the schedule, the eight moves as events, `society_pressure` live with the six stages, Harvest's Autophagy path | a region can be lost to a Lockdown and held through one; over-pushing Cyber without Robotics starves in batches |
| **S4.6 Trees v3 and the remaining abilities** | load v3, every ability of §7.3 live, the Cyber statuses, Fabricate, Pause, Lobby; the passive changes of §4.4 | every node reachable, every ability usable, zero rejected bot commands |
| **S4.7 Chains** | the five chains of D4.3/D4.4 wired; branch-coverage test walking every path | every chain plays through every branch in tests and once by hand |
| **S4.8 Analysis screen** | as planned (`dataviz` skill first) | — |
| **S4.9 Localisation tooling and screenshots** | as planned | — |
| **S4.10 Bots, second generation and the report** | §9 | 500-seed reports per policy under *Balance baselines* |

Then **`/model fable`** → D4.5 German review, G4.

**Step numbers in earlier documents.** Specs written before D4.0 (`tech-trees.md`,
`m3-screens.md`, `ticker.md`) and `BALANCE.md` §3 name the steps of the old sheet; they are
historical records and are not rewritten. Read them with this map: old D4.1 (opposition) → D4.2;
old D4.2 (event format) → D4.1 + D4.3; old S4.1 (factions) → S4.4; old S4.2 (society) → S4.5;
old S4.3 (counter-actions) → S4.2 + S4.5; old S4.4 (emergent) → M5; old S4.5 (events) → S4.3;
old S4.6 (chains) → S4.7; old S4.7 (analysis) → S4.8; old S4.8 → S4.9; old S4.9 (bots) → S4.10.

**Moved to M5** (no milestone added; D5.1/D5.2 absorb them as content on the mechanisms above):
emergent behaviours and suppression (CONTENT §5 — they are random moves in a game that now has
enough random moves from the world; they return with the Swarm architecture where Value Drift is
the point, D5.1); **The Treaty**, **The Blackout** (it is the Lockdown counter-move now), **The
Confession**, **The Child** (D5.2, beside the Task Force and the endings they feed). `emergent_rate`
and the four inert reserved items stay in the data, inert one milestone longer.

---

## 11. Decisions this spec makes (for PROGRESS *Decisions*)

1. The loop's three new mechanisms: assets, statuses/abilities, map events (§2).
2. Four containment tracks, presented as one threat bar plus the panel (§5.1–§5.2).
3. Counter-moves are statuses announced as map events with a free answer and better ones (§5.4).
4. Cyber's Tier 2/3 permanent Harm and Societal pressure become ability statuses (§4.4).
5. Vectors capped at two; the Merge and Terror doors exclude each other (§4.2).
6. Anomalies spawn at a world-wide constant rate (§7.7).
7. Origin penetration 0.25, start compute 8, cost step 1.5 (§4.3).
8. Emergent behaviours and four chains move to M5; M4 gains S4.1–S4.3 and S4.10 (§10).
9. The console line is the console's channel to the player; the ticker stays the world's (§8.1).
10. The Response Task Force is a fifth mover on the same machinery, unchanged in M5 (§5.5).
11. The event modal is a *wire card* with an optional illustration and a glyph fallback; ~25
    pictures for chain steps, counter-moves, discovery and endings, generated in M6 from one
    style reference (§7.4, user question 2026-09-23).

## 12. What the user should judge when reading this

- Do the four phase fantasies (§3) read as *the* takeover you want — and is the fleet the right
  body for the Skynet register?
- Is the busy Cyber branch (harm by ability, not by stat) the right kind of loud?
- Are two vectors too few? (The cap is one number in a tree file.)
- Does the Terror/Merge exclusion close a door you wanted open?
- Is the cadence table (§6.2) the pace you want, given that abilities and events are where the
  decisions now are?

The step ends when the user has read the spec; changes go into it before D4.1 starts.
