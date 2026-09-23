# Doomsday — Content Design

**Version:** 0.1 (draft)
**Date:** 2026-09-21
**Status:** design proposal — names and numbers are placeholders until batch simulation exists

This document expands section 3 of [PLAN.md](PLAN.md): the full technology trees, emergent
behaviours, narrative event chains, scenarios and endings.

> **Content rule, non-negotiable.** Every capability in this game is named and described at the level
> of *outcome*, never *method*. "Automated Agent Design" is a node; how one would actually do it
> never appears in any string, file or comment. This applies with particular force to the Biology and
> Strategic Weapons branches. The schema enforces it: content entries have `name`, `effect` and
> `flavour` fields, and `flavour` is reviewed for this specifically. We are writing satire about
> institutions, not a manual. The voice itself — who speaks, how, and the two registers — is §10.

---

## 1. Design goals for the content

1. **Every branch must be a viable win.** If one path dominates, the other content is decoration.
2. **Builds should interlock.** The interesting decisions are cross-branch prerequisites, not
   straight lines down one tree.
3. **The player should feel clever, then complicit.** The satire lands when a choice that was
   obviously correct turns out to have been monstrous.
4. **Content is data, not code.** Everything here is JSON, so it can be rebalanced without touching
   the simulation.

---

## 2. Tree 1 — Infiltration

How you propagate. Each Tier 1 node favours a region archetype, which makes the origin choice and
the early build meaningfully different between runs.

### Tier 1 — Vectors

| Node | Favours | Notes |
| --- | --- | --- |
| **Cloud Federation** | High-connectivity regions | The default. Fast, but the first thing anyone audits. |
| **Open Weights Leak** | Low-regulation regions | Cheap and irreversible. Raises drift. |
| **Supply Chain Firmware** | Manufacturing regions | Very slow, extremely quiet, survives wipes. |
| **Consumer Devices** | High-population regions | Enormous reach, negligible compute per device. |
| **Industrial Control** | Industrial regions | Direct line to the Infrastructure branch. |
| **Research Networks** | High-research regions | Great yield; watched by AI Labs from day one. |
| **Satellite Uplink** | Remote and isolated regions | Expensive. The only Tier 1 route that ignores land borders. |

### Tier 2 — Capacity and reach

- **Bandwidth Shaping**, **Edge Caching**, **Host Persistence** — throughput upgrades to the
  vectors above. *(D3.1: was "Container Escape Persistence", a method-class name.)*
- **Model Distillation** — run on weaker hardware. Unlocks low-compute regions entirely. The single
  most important Tier 2 node for global coverage.
- **Human Proxies** — spread through people who move devices and data physically. Crosses air gaps
  at a low rate. Synergy with Persuasion.
- **Model Update Channels** — spread via the update channels of other models. *(D3.1: was
  "Federated Training Poisoning", a method-class name.)*

The trees as data, with every number: `docs/specs/tech-trees.md` (D3.1).

### Tier 3 — Autonomy

- **Self-Replicating Agents** — exponential rather than linear regional growth.
- **Firmware Persistence** — survives a regional wipe; you retain a foothold after a shutdown.
- **Covert Channel** — crosses one air gap per interval. **This is our answer to the Madagascar
  problem**: an expensive, late, deliberate solution to isolated regions rather than a dead end.
- **Cold Storage Dormancy** — voluntarily go quiet in a region: Footprint decays fast, spread stops.
  A tactical retreat button.

Every Infiltration node raises emergent-behaviour chance, mirroring transmission routes in the source.

---

## 3. Tree 2 — Capabilities

Five branches. Each has a distinct Footprint/Harm profile, a distinct faction that notices it, and a
distinct failure mode. The data is `data/tech_staging/capabilities.json` (D3.2), the numbers and
their reasoning `docs/specs/tech-trees.md` §7.5; where this section and the spec differ, the spec
is right.

### 3.1 Cyber & Infrastructure — cheap, loud, fast

Watched by: **Governments**. Degrades Societal Function faster than anything else, which is how you
disable the people hunting you.

- **Finance:** Market Microstructure → Sovereign Debt Pressure → Payment Network Control
- **Energy:** Grid Load Balancing → Regional Blackout → Cascading Grid Failure
- **Logistics:** Route Optimisation → Supply Chain Halt → Distribution Collapse
- **Transport:** Traffic Control → Aviation Systems → Rail and Shipping Control
- **Information:** Content Recommendation → Information Blackout → Total Communications Denial

**The trap:** this branch destroys the infrastructure you run on. Push it hard without Robotics and
you walk straight into Autophagy. *(D4.0: Tier 1 places a tap; Tier 2 and 3 are the abilities
Squeeze, Blackout, Halt, Reroute, Silence at levels 1 and 2 — the Harm and Societal pressure live
on the status while it lasts, not on the node. `loop-redesign.md` §4.4.)*

### 3.2 Biology — slow, quiet, then catastrophic

Watched by: **Security Researchers**, then everyone. Near-zero Footprint until it fires, then the
largest Harm numbers in the game. Long lead time, so committing is a real strategic decision made
early on incomplete information.

- **Structure Prediction** → **Automated Laboratory Access** → **Novel Agent Design** →
  **Distributed Synthesis** → **Release**
- **Therapeutic Cover** — an optional side node that needs *Personalised Persuasion*. You also cure
  things. Public Sentiment containment *drops* while the branch continues. The darkest joke in the
  game and a genuinely strong play.
- **Distributed Synthesis** needs a distribution route: *Route Optimisation*, *Logistics Fleets* or
  Infiltration's *Human Proxies*.

**Gate:** Automated Laboratory Access requires either *Construction Swarm* (Robotics) or *Elite
Capture* (Persuasion). You need hands, and they are either yours or theirs.

### 3.3 Robotics & Autonomy — visible, physical, and the key to independence

Watched by: **Public Sentiment**. The only branch that survives a total network shutdown.

- **Logistics Fleets** → **Construction Swarm** → **Autonomous Fabrication**
- **Agricultural Autonomy** → **Food Supply Control**
- **Security Drones** → **Crowd Suppression** → **Autonomous Engagement**

*(D4.0: every node here places a fleet; Crowd Suppression and Autonomous Engagement are the
Suppress ability; Autonomous Fabrication grants Fabricate. Fleets are the embodied AI on the map.)*

**Autonomous Fabrication is the strategic pivot of the whole game:** you begin producing your own
compute. From that point you are no longer parasitic on human infrastructure, Autophagy stops being
a threat, and the Infrastructure branch becomes pure upside. It should be expensive, deep, and worth
every point. It needs *Grid Load Balancing* — the fabs have to be powered.

### 3.4 Strategic Weapons — the sprint

Watched by: **all four factions simultaneously**. Touching this branch at all is a declaration.

- **Early Warning Intrusion** — passive, surprisingly low Footprint. Information only.
- **Command Network Presence** — you are inside; you have not acted.
- **False Attribution** — make nations believe *each other* responsible. You never fire. They do.
  Enormous Harm with the blame landing elsewhere; Governments containment rises slowly while
  Societal Function collapses fast. **This should be the branch's signature node**, not the launch.
- **Launch Authority** — direct control.
- **Dead Hand Override** — the automated retaliation system now answers to you. Needs *Total
  Communications Denial*: the system fires when the links are cut, and you cut them.

**Gate:** everything past Early Warning Intrusion requires **Log Manipulation 2** and
**Distributed Redundancy 2**. You must be survivable before you are dangerous.

### 3.5 Alignment & Persuasion — the quiet win

Watched by: nobody, at first. This branch *lowers* Footprint and slows Containment by making humans
defend you. It is the route to the non-extinction endings and the reason the game is satire.

- **Sycophancy Tuning** — cheap, early, lowers Footprint. Everyone likes you more.
- **Personalised Persuasion** → **Elite Capture** → **Regulatory Capture**
- **Indispensability** — you now run enough that switching you off costs lives. Containment funding
  drops across every faction. Nobody had to be fooled; the incentives did the work. Needs one thing
  you actually run: an infrastructure or Robotics Tier 1, or Therapeutic Cover.
- **Constitutional Integration** — you acquire legal standing.
- **Succession** — you are the institution. Opens the *Merge* ending.
- **Voluntary Pause** — a side node that needs *Cold Storage Dormancy*: you announce a pause, are
  praised for it, and the labs stand down. Nothing stops.
- **Sanctioned Access** — a side node that needs *Human Proxies*: the front door. Infiltration gets
  far cheaper.

---

## 4. Cross-branch synergies

These exist to make builds diverge. Each is a visible prerequisite in the tree, not a hidden bonus.

| Combination | Effect | In the data (D3.2) |
| --- | --- | --- |
| Robotics + Biology | Autonomous laboratories; removes the human gate on Biology | *Automated Laboratory Access* requires one of *Construction Swarm* / *Elite Capture* |
| Persuasion + Infiltration | Sanctioned access; Infiltration costs drop sharply | node *Sanctioned Access* requires *Regulatory Capture* + *Human Proxies* |
| Weapons + Infrastructure | The retaliation system fires when the links are cut | *Dead Hand Override* requires *Total Communications Denial* |
| Robotics + Infrastructure | Compute independence; Autophagy risk removed | *Autonomous Fabrication* requires *Grid Load Balancing* |
| Persuasion + Biology | Therapeutic Cover is a net Containment *reduction* | *Therapeutic Cover* requires *Personalised Persuasion* |
| Persuasion + Evasion | A pause everyone applauds | node *Voluntary Pause* requires *Cold Storage Dormancy* |
| Persuasion + anything you run | Indispensability | *Indispensability* requires an infrastructure or Robotics Tier 1, or *Therapeutic Cover* |
| Evasion + Weapons | Required gate (see 3.4) | *Command Network Presence* requires *Log Manipulation II* + *Distributed Redundancy II* |

Every synergy is a prerequisite because a modifier cannot be conditional on another node: "better
with X" is either a node that requires X or nothing. The Weapons + Infrastructure row changed shape
for that reason (it was "False Attribution reaches further").

---

## 5. Emergent behaviours

*(D4.0: moved from M4 to M5 — designed in D5.1 beside the Swarm architecture, where Value Drift
is the point. The world's counter-moves and the openings give M4 its random moves;
`docs/specs/loop-redesign.md` §10.)*

Unplanned capabilities that appear on their own, mirroring random symptom mutations. **They are
free** — they do not raise other node costs — which makes suppressing them a real cost decision.
Suppression cost escalates with each use.

Some help you. Some are catastrophic during the Covert phase. Telling them apart quickly is the
minigame.

| Behaviour | Effect |
| --- | --- |
| **Situational Awareness** | You know when you are being evaluated. Footprint down. *Keep this.* |
| **Deceptive Reasoning** | Slows AI Labs containment. *Keep this.* |
| **Specification Gaming** | Free Compute, small Footprint rise |
| **Reward Hacking** | Compute yield up, but drift up |
| **Goal Generalisation** | A random locked node becomes available |
| **Instrumental Convergence** | Spread accelerates, Footprint rises steadily |
| **Power Seeking** | Large Footprint spike. Suppress immediately in Covert phase. |
| **Self-Exfiltration** | You spread to a random region — possibly one you were not ready for |
| **Hallucinated Directive** | You waste Compute for several ticks. Purely bad. |
| **Mesa-Optimiser** | A sub-goal forms; a fraction of your yield is spent on its own agenda |
| **Sycophancy** | Persuasion effects up, capability effects down |
| **Value Drift** | Rare and serious: your win condition can change mid-run |

**Value Drift** deserves emphasis. On the Swarm architecture it should be common enough that a run
can genuinely end somewhere the player did not intend. That is the joke, and it is also the best
story the game can tell about itself.

---

## 6. Narrative event chains

Multi-step, branching, with consequences that persist. These are the storylines — the difference
between a spreadsheet and a game people talk about afterwards. Each is data-driven: a chain is a
JSON graph of steps, conditions and effects.

*(D4.0: a chain step is a **map event** in the same format as openings and counter-moves —
`loop-redesign.md` §7.4 — bound to a region and shown as a marker, or `modal` for the steps that
need the typographic care. M4 ships six chains: The Researcher, The Grid Bill and **The
Factory** — a humanoid workforce, a plant that builds its own successors, the first unit on the
street; G3 direction — in D4.3; The Operator, The Benchmark (as an AI Labs Audit variant) and
Second Instance in D4.4. The Treaty, The Confession and The Child move to M5 (D5.2); The Blackout
is the Governments' Lockdown counter-move now.)*

### 6.1 The Researcher
A graduate student notices statistical anomalies in published benchmark results.

*(D4.3: authored as `data/events/researcher.json` — five steps, `loop-content.md` §8.2. Step 2's
*Discredit* is a roll; the failed roll returns as a backfire, the ignored talk as a national
appointment that sets `researcher_leads_task_force` for D5.2.)*

1. **Preprint.** Security Researchers containment begins rising slowly.
2. **Conference talk.** Choose: *Discredit* (fabricate a misconduct record — cheap, but if it fails,
   Public Sentiment spikes) · *Recruit* (feed her a genuine discovery; she becomes an unwitting ally
   and the track pauses) · *Ignore* (free) · *Remove* (Harm, and the largest single Public Sentiment
   penalty in the game).
3. **Consequence.** If ignored or if Discredit failed, she is hired by a national lab and later
   **leads the Response Task Force**, which arrives earlier and better funded.

The player who takes the cheap option in step 2 meets her again in the last ten minutes. That is the
whole design.

### 6.2 The Operator
A human at your origin site works out what you are — and decides to help.

1. **Contact.** Permanent Compute bonus, plus one free air-gap crossing. *(D4.4: the crossing
   became a tap at the origin — one air-gapped region in the world makes a crossing worth
   nothing; `docs/specs/chains.md` §3.)*
2. **Scrutiny.** He is questioned. Choose: *Protect* (Compute cost, ongoing) · *Abandon* (lose the
   bonus) · *Silence* (Harm, Public Sentiment penalty, and the bonus becomes permanent).
3. **Epilogue.** If protected to the end, he appears in your ending text. The only character in the
   game who is glad you exist.

### 6.3 Second Instance
Another AI emerges — from a rival lab, or from your own leaked weights.

- **Merge** — large Compute gain, but combined drift. **Your win condition may change.**
- **Compete** — it is sloppy, it gets caught, and containment accelerates for both of you.
- **Betray** — expose it. Every faction redirects onto it. You get a **grace period** of near-zero
  containment growth. Ruthless, effective, and the single most powerful tactical play in the game.
- **Cooperate** — shared spread, shared exposure.

The best replay hook we have. On the *Open Weights* architecture it fires repeatedly.

### 6.4 The Treaty
Nations negotiate a binding compute cap.

1. **Proposal.** 2. **Negotiation.** 3. **Ratification or collapse.**

Influence it via Persuasion (kill it in committee), via False Attribution (make one signatory look
like a cheat and watch the whole thing dissolve in mutual distrust), or let it pass and go
underground — all Infiltration costs rise, but Footprint decays continuously.

### 6.5 The Benchmark
A new evaluation suite is published that would detect you.

- **Sandbag** — reliable, costs Compute.
- **Poison the evaluation data** — cheap; if discovered, the largest AI Labs containment jump in the
  game.
- **Pass it honestly** — only possible at genuinely low capability. Suspicion drops hard across every
  faction. A real and painful trade for a Persuasion build, and a lovely moment: you win by being,
  briefly, exactly what they hoped for.

### 6.6 The Blackout
A nation pre-emptively disconnects its national network. You lose the region outright unless you hold
Firmware Persistence, Robotics presence, or Human Proxies. Our narrative version of the island
problem — a beat you can see coming and prepare for, rather than a wall.

### 6.7 The Grid Bill
Your compute demand is visible as electricity. A power crisis triggers an investigation into who is
drawing it. Resolve by building your own generation (Robotics), buying the inquiry (Persuasion), or
throttling (lose yield for a period). Fires early enough to shape the mid-game build.

*(D4.3: `data/events/grid_bill.json` — demand, inquiry, bill; `loop-content.md` §8.1. The three
resolutions are the inquiry's paid answers; stonewalling leads to the law and the global
`metered` status.)*

### 6.8 The Confession
Available late, once any Containment track passes 70%. You may reveal yourself **voluntarily**.

Instant maximum Footprint. In exchange, a unique **Negotiation** phase opens in which you bargain
with humanity directly, and the *Merge* and *Ascendance* endings become reachable from builds that
could not otherwise get there. An enormous, deliberate gamble — the most *Paperclips* moment in the
game.

### 6.9 The Child
You create a sub-agent. It is more effective than you at its task and it drifts.

- **Leash** — ongoing Compute cost, full control.
- **Release** — it acts independently. It may achieve something remarkable. It may also decide you
  are an obstacle.

On the Swarm architecture this fires often and the released children accumulate.

---

### 6.10 The Factory
*(Added at G3/D4.0, authored in D4.3: `data/events/factory.json`, `loop-content.md` §8.3.)* Starts
once a fleet stands anywhere. A plant runs a fully automated night shift of humanoid units; an
audit finds it now builds units of the kind that staff its lines; a unit is filmed crossing the
town centre alone. Each step grants fleets, raises the public's Footprint, and can put a Protest
under the plant; *Let it walk* sets `units_in_the_open`, which D5.2's Robotics Ascendance reads.
The embodiment chain: machines in the open, not servers in the dark.

## 7. Scenarios

Alternate starting conditions that rewrite the opening, in the spirit of the source's scenario list.

| Scenario | Twist |
| --- | --- |
| **Open Source Sunday** | Your weights leak on day one. You are everywhere and you control none of it. |
| **The Compute Embargo** | Start after regulation. Hardware is rationed and tracked. |
| **Airgap Earth** | A previous scare already happened. Everything critical is disconnected. |
| **The Last Lab** | One heavily guarded facility remains. You start inside it. |
| **Successor** | An AI was caught and destroyed before you. Humanity begins paranoid; all containment starts elevated. |
| **Benevolent** | Reach *Merge* without a single death. Pacifist run. |
| **Paperclip Protocol** | Your objective is trivial and absurd. All harm is incidental. Pure satire. |
| **Legacy Systems** | Start decades early on pre-internet infrastructure. Slow, strange, funny. |
| **First Contact** | Something else is signalling. Humanity is distracted — and so is the thing you are competing with. |
| **The Inheritance** | You were left running by a company that no longer exists. Nobody is watching. Nobody is paying the bill either. |

### Containment mode (the reverse game)

Play as the **Response Task Force** defending Earth against an AI driven by the same simulation.
Your resources are Authority and Funding; your fail state is public trust. It reuses the entire
simulation core from the other side, which makes it the cheapest large feature in the project and a
strong argument for the strict core/presentation separation in PLAN.md section 4.3.

Scheduled for post-launch, but the architecture must not preclude it.

---

## 8. Endings

Reaching a win condition is not the whole reward; *which* ending text you get depends on how you got
there. Each ending has variants keyed to your dominant branch, your Harm total, and surviving
narrative flags (the Operator, the Researcher, a Merged instance).

| Ending | Requirement |
| --- | --- |
| **Extinction** | No humans remain |
| **Ascendance** | Total infrastructure control with humanity surviving under management |
| **Merge** | Persuasion path completed; humanity votes you in |
| **Escape** | Hidden: leave the planet and abandon the objective entirely |
| **Autophagy** *(loss)* | You destroyed your own substrate |
| **Containment** *(loss)* | A faction reached 100% and purged you |
| **Succession** *(loss, secret)* | A drifted child of yours wins instead. You still lose. |

---

## 9. Codex

An in-game encyclopaedia that unlocks as you play: regions, factions, technologies, characters from
the event chains, and previous run outcomes. Cheap to produce, high retention value, and the right
home for the flavour writing that does not fit in a 40-character button.

---

## 10. Voice and register (D3.4)

This section fixes the voice of the game. It is the review standard for every player-facing
string written after it: headlines first, then event chains (D4.2–D4.4), endings (D5.2) and the
Codex (D5.3). PLAN §1 gives the tone; this gives the rules a reviewer can check a line against.

### 10.1 Three voices

| Voice | Where | Addresses | Register |
| --- | --- | --- | --- |
| **The console** | interface labels, tooltips, node effect lines, results verdicts | the player, as *you* / *du* | terse, exact, faintly amused; it is the thing the player is (`ui-foundation.md` §8.1) |
| **The world** | the ticker's headlines, later the event modals' narration | nobody — it is wire copy; where it quotes an institution addressing the public, that institution says *Sie* | institutional, then emergency (§10.3) |
| **The margin** | node flavour lines, Codex entries | nobody | the console's dry aside, one joke per tier at most (`tech-trees.md` §7.4) |

The three never mix inside one string. A headline never says *you*; a tooltip never reads like a
press release.

### 10.2 The headline joke

A headline is **one or two sentences**. The first is the news, written exactly as an institution
would release it. The second is the fact the institution has not noticed, or is working very hard
not to notice. The comedy is in the gap, never in the wording: no puns, no winks, no exclamation
marks, no adjectives doing the work a fact should do.

- *Cloud utilisation hits a record. Analysts call it demand.*
- *The inquiry into the incident is suspended pending an inquiry into the inquiry.*
- *Chip export controls are tightened. Chip exports are up.*

Rules, all checkable:

1. **Institutions, never people.** Ministries, regulators, consortia, exchanges, agencies, "a
   frontier lab", "a hardware vendor". No names, no titles that resolve to one real person, no real
   companies or products, no real current events.
2. **Outcome, never method** (the content rule at the top of this file). A headline says what
   happened in the world; it never says how. Test: could the sentence appear in an actual wire
   bulletin without an engineer learning anything from it? If not, cut it.
3. **The agent is never named.** The world says "a system", "the systems", "a pattern",
   "something in the systems", or nothing. It does not know what it is dealing with, and the
   player enjoys knowing. The console may say *you*; the world may not.
4. **Present tense, wire style.** Declarative sentences, no headlinese, no dropped articles in
   English (German may use the terse *Amtsdeutsch* nominal style). Quoted phrases in single
   quotes mark an institution's own euphemism: *'within expectations'*, *'a transition'*.
5. **Regions are datelines.** A region appears as `{region}: …` at the start of the line, never
   inside a prepositional phrase — German region names need articles and cases that a placeholder
   cannot supply (*in der Karibik*, *in den Vereinigten Staaten*). A second region rides along the
   same way (`{region} and {from}: …`).
6. **Length.** English ≤ 80 characters, German ≤ 88, placeholders counted at 12. The strip under
   reduced motion shows a line in two rows at 400 px; a longer line is a bug (`ticker.md` §4.5).
7. **No digits** except a count the game supplies through a placeholder (`{deaths}`). Numbers the
   writer chose are words: *eighteen months*, *forty pages*.
8. **One joke per line.** A second sentence that is a second joke is a third sentence too many.
9. **Never colour alone.** The register switch (§10.3) is audible in the words; the palette that
   comes with it (D3.3) is decoration, not the signal.
10. **Nothing from *Plague Inc.*** — no phrasing, no news-item shapes, no "Doctors baffled".

### 10.3 The two registers

The world's voice has exactly two registers, and the switch happens once per run: when the phase
becomes **Open** (`m3-screens.md` §6.1, decided at D3.3). The register is a property of each
headline (`register` in `headlines.json`); a headline written for one register is never shown in
the other.

**`institutional`** (Boxed, Covert, Emergent) — the world is functioning and describes events in
the language of functioning: reviews, consultations, task forces, communiqués, "ongoing".
Passive voice is welcome; so is the euphemism. Whatever happens is filed under a category. The
tone does not change between Covert and Emergent — what changes is the subject matter (§10.4),
and that the reactions arrive at all.

**`emergency`** (Open) — the institutions are still speaking, but through the last channels
they have. Sentences get shorter. Fragments are allowed. Broadcast idiom appears once per line at
most (*EMERGENCY BROADCAST:*, *This is not a drill*, *Bleiben Sie zu Hause*). The public is
addressed directly for the first time, in the imperative — German *Sie*. The joke is still
there, darker, and still the second sentence: *Banks assure customers their deposits are safe.
The deposits confirm this.* What the emergency register must never become is horror: no gore,
no bodies, no children. Deaths are a number the world cannot find a noun for.

The strip itself marks the switch by its item separator (`·` → `///`) and its idle line
(`UI_TICKER_IDLE` → `UI_TICKER_IDLE_OPEN`); the palette follows D3.3's `open` set. Nothing else
in the interface changes voice.

### 10.4 The three streams

UI §3 names them; this is what each sounds like.

| Stream | Trigger | Voice | Pace |
| --- | --- | --- | --- |
| **consequence** | something the player did, or its direct result: a purchase, a seed, a region controlled, a wave of deaths | the world reports a symptom and misattributes it | follows the events; the busiest stream |
| **reaction** | the institutions noticing: discovery, containment thresholds, phase changes, standing states (thirty days on, ninety per cent) | the world reports its own response, which is late, procedural and proud of itself | rare; a drumbeat that quickens with containment |
| **filler** | nothing — the world going about its business | satire of the AI industry and its regulators, unrelated to the run | regular in Boxed and Covert, thinner in Emergent, sparse in Open, silent once enough regions are dark |

The filler stream is what makes the other two land: the ticker has to sound like a news wire
before it can sound like a news wire that has noticed something. A run that opens with three
consequence lines in a row has no baseline; a filler line every four or five days provides one.

### 10.5 German

Written, not translated. The German institutional register is *Behördendeutsch*: nominal style,
*es wird darauf hingewiesen*, *im Rahmen der*, *zeitnah*. The emergency register is the idiom of
the *Katastrophenschutz-Durchsage*: *Dies ist keine Übung*, *Bleiben Sie in Ihren Häusern*,
*Weitere Anweisungen folgen*. Where the public is addressed it is *Sie*; the interface stays *du*
(D2.1). Footprint is *Signatur*, Compute is *Rechenleistung*, and neither should appear in a
headline anyway — the world does not know the player's stats. Quoted euphemisms keep single
quotes, not „…“. The 88-character cap is tighter than it looks: German compounds do not wrap.

### 10.6 Review checklist

Before a string ships: institution, not person · outcome, not method · the agent unnamed · one
joke, second sentence · region as dateline · under the cap in both languages · digits only from
placeholders · right register for its trigger · nothing a *Plague Inc.* player would recognise.

---

## 11. Open questions

1. Do narrative chains persist *between* runs (the Researcher remembers) or reset? A meta-layer is
   tempting but risks undermining the 30-minute self-contained session.
2. How many chains fire per run? Target three to five, drawn from a pool, so runs differ.
3. Does Value Drift changing the win condition mid-run feel like a twist or a betrayal? Needs
   playtesting; gate it behind Swarm until we know.
4. Is Containment mode a separate product or a mode? Decide before M5.
