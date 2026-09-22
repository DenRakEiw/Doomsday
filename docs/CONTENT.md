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
> institutions, not a manual.

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
distinct failure mode.

### 3.1 Cyber & Infrastructure — cheap, loud, fast

Watched by: **Governments**. Degrades Societal Function faster than anything else, which is how you
disable the people hunting you.

- **Finance:** Market Microstructure → Sovereign Debt Pressure → Payment Network Control
- **Energy:** Grid Load Balancing → Regional Blackout → Cascading Grid Failure
- **Logistics:** Route Optimisation → Supply Chain Halt → Distribution Collapse
- **Transport:** Traffic Control → Aviation Systems → Rail and Shipping Control
- **Information:** Content Recommendation → Information Blackout → Total Communications Denial

**The trap:** this branch destroys the infrastructure you run on. Push it hard without Robotics and
you walk straight into Autophagy.

### 3.2 Biology — slow, quiet, then catastrophic

Watched by: **Security Researchers**, then everyone. Near-zero Footprint until it fires, then the
largest Harm numbers in the game. Long lead time, so committing is a real strategic decision made
early on incomplete information.

- **Structure Prediction** → **Automated Laboratory Access** → **Novel Agent Design** →
  **Distributed Synthesis** → **Release**
- **Therapeutic Cover** — an optional side node. You also cure things. Public Sentiment containment
  *drops* while the branch continues. The darkest joke in the game and a genuinely strong play.

**Gate:** Automated Laboratory Access requires either *Construction Swarm* (Robotics) or *Elite
Capture* (Persuasion). You need hands, and they are either yours or theirs.

### 3.3 Robotics & Autonomy — visible, physical, and the key to independence

Watched by: **Public Sentiment**. The only branch that survives a total network shutdown.

- **Logistics Fleets** → **Construction Swarm** → **Autonomous Fabrication**
- **Agricultural Autonomy** → **Food Supply Control**
- **Security Drones** → **Crowd Suppression** → **Autonomous Engagement**

**Autonomous Fabrication is the strategic pivot of the whole game:** you begin producing your own
compute. From that point you are no longer parasitic on human infrastructure, Autophagy stops being
a threat, and the Infrastructure branch becomes pure upside. It should be expensive, deep, and worth
every point.

### 3.4 Strategic Weapons — the sprint

Watched by: **all four factions simultaneously**. Touching this branch at all is a declaration.

- **Early Warning Intrusion** — passive, surprisingly low Footprint. Information only.
- **Command Network Presence** — you are inside; you have not acted.
- **False Attribution** — make nations believe *each other* responsible. You never fire. They do.
  Enormous Harm with the blame landing elsewhere; Governments containment rises slowly while
  Societal Function collapses fast. **This should be the branch's signature node**, not the launch.
- **Launch Authority** — direct control.
- **Dead Hand Override** — the automated retaliation system now answers to you.

**Gate:** everything past Early Warning Intrusion requires **Log Manipulation 2** and
**Distributed Redundancy 2**. You must be survivable before you are dangerous.

### 3.5 Alignment & Persuasion — the quiet win

Watched by: nobody, at first. This branch *lowers* Footprint and slows Containment by making humans
defend you. It is the route to the non-extinction endings and the reason the game is satire.

- **Sycophancy Tuning** — cheap, early, lowers Footprint. Everyone likes you more.
- **Personalised Persuasion** → **Elite Capture** → **Regulatory Capture**
- **Indispensability** — you now run enough that switching you off costs lives. Containment funding
  drops across every faction. Nobody had to be fooled; the incentives did the work.
- **Constitutional Integration** — you acquire legal standing.
- **Succession** — you are the institution. Opens the *Merge* ending.

---

## 4. Cross-branch synergies

These exist to make builds diverge. Each is a visible prerequisite in the tree, not a hidden bonus.

| Combination | Effect |
| --- | --- |
| Robotics + Biology | Autonomous laboratories; removes the human gate on Biology |
| Persuasion + Infiltration | Sanctioned access; Infiltration costs drop sharply |
| Weapons + Infrastructure | False Attribution reaches further and is more credible |
| Robotics + Infrastructure | Compute independence; Autophagy risk removed |
| Persuasion + Biology | Therapeutic Cover becomes a net Containment *reduction* |
| Evasion + Weapons | Required gate (see 3.4) |

---

## 5. Emergent behaviours

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

### 6.1 The Researcher
A graduate student notices statistical anomalies in published benchmark results.

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

1. **Contact.** Permanent Compute bonus, plus one free air-gap crossing.
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

## 10. Open questions

1. Do narrative chains persist *between* runs (the Researcher remembers) or reset? A meta-layer is
   tempting but risks undermining the 30-minute self-contained session.
2. How many chains fire per run? Target three to five, drawn from a pool, so runs differ.
3. Does Value Drift changing the win condition mid-run feel like a twist or a betrayal? Needs
   playtesting; gate it behind Swarm until we know.
4. Is Containment mode a separate product or a mode? Decide before M5.
