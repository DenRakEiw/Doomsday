# Technology trees — effect vocabulary v2, Infiltration and Evasion

**Step:** D3.1, extended by D3.2 (§7.5, one row in §5, one in §6.5, three tests in §9) · **Builds
from it:** S3.1 (vocabulary, loader, validator), S3.2 (tree interface, via `m3-screens.md`), S3.6
(policies)
**Date:** 2026-09-22 · **Status:** binding

This spec does three things. §2–§6 extend the content vocabulary of `data/SCHEMA.md` §4 from v1 to
v2: new node fields, new modifier targets, flags, one-shot effects, one new command. §7 gives the
two trees this step authored (`data/tech_staging/infiltration.json`, `evasion.json`) and the
reasoning behind their numbers; §7.5 (D3.2) does the same for `capabilities.json`. §8–§10 are
what S3.1 builds, tests and is judged by.

Nothing here changes a v1 formula except where §6 says so explicitly. Everything in `core.md` §7
that is not named in §6 stays as it is.

---

## 1. Scope

**In:** the complete effect vocabulary for all three trees — Capabilities included, so that D3.2
authors data and adds no mechanism; the Infiltration and Evasion trees as data with text in both
languages; the staging rule (§1.2); the schema changes S3.1 makes; the tests and the acceptance
criteria for S3.1.

**Out:** the tree *interface* — node states, connection lines, detail pane (D3.3); factions,
counter-actions, Societal Function, emergent behaviours, Autophagy (M4) — this spec only reserves
the targets and flags those systems will read (§3.3), so that the data is authored once; balance
tuning against the 25–40 minute target (G3).

### 1.1 Terms

- **Target** — a named stat the modifier stack computes (`SCHEMA` §4.1). *Regional* targets take a
  scope; *global* ones do not.
- **Flag** — a boolean a source grants while active (`SCHEMA` §4.3).
- **One-shot effect** — something that happens once, when the node is bought, and is not undone.
- **Inert** — a target, flag or effect the loader accepts and the stack evaluates, but no system
  reads yet because the system belongs to a later milestone (§3.3). The column *System* in the
  tables names that system; a blank means live from S3.1.

### 1.2 Staging

The v1 loader rejects every v2 field and target as an unknown-field error, and S2.P needs the game
running before S3.1 exists. So the two trees live in **`data/tech_staging/`** until S3.1, which
moves them to `data/tech/`, deletes `data/tech/placeholder.json`, and removes the staging
directory. D3.2 stages `capabilities.json` the same way. Nothing loads `tech_staging/`; it is a
hand-over folder, not content.

`placeholder.json` is deleted, not kept: with the real trees loaded its `m1_` capability nodes
would be nodes without strings, and S3.1's validator (§8.3) rejects those. Between S3.1 and D3.2's
file landing there is no gap — D3.2 runs before S3.1 (run sheet, Block 5 before Block 6).

---

## 2. Node format v2

`tech/*.json`, `nodes[]`. v1 fields unchanged; three added. Text stays in `strings.csv` (§6 of
`SCHEMA`), the node carries no strings.

```json
{
	"id": "human_proxies",
	"tree": "infiltration",
	"tier": 2,
	"cost": 9,
	"grid": [2, 3],
	"requires_any": ["consumer_devices", "open_weights_leak", "supply_chain_firmware"],
	"watched_by": ["public_sentiment"],
	"flags": [],
	"on_purchase": [],
	"modifiers": [
		{"target": "airgap_cross", "op": "add", "value": 0.15},
		{"target": "seed_land", "op": "mul", "value": 1.3}
	]
}
```

| Field | Type | Required | Rule |
| --- | --- | --- | --- |
| `grid` | `[int, int]` | **yes** | `[column, row]`, both ≥ 0, column ≤ 7, row ≤ 11; **unique within the tree**. Column 0 holds Tier 1; a node's column is ≥ the column of every prerequisite (lines run left to right) |
| `watched_by` | `[faction id]` | no (`[]`) | each one of `ai_labs` · `governments` · `security_researchers` · `public_sentiment`, no duplicates. Which factions notice this node: M3 shows it as chips in the detail pane (D3.3); D4.1 weights the node's Footprint towards those factions. Carries no mechanism before M4 |
| `on_purchase` | `[effect]` | no (`[]`) | §5. Applied once, in list order, inside `PurchaseNodeCommand.execute` after the source is added |

Everything else is v1: `id`, `tree`, `tier` 1…3, `cost` ≥ 1, `requires`, `requires_any`,
`modifiers`, `flags`.

**Grid semantics for D3.3:** each tree tab is a grid of at most 8 columns × 12 rows; the tier is
*not* the column — Evasion puts three tiers in four columns and Infiltration puts two kinds of Tier 2
in columns 1 and 2. The interface draws a line from every prerequisite to the node; `requires`
lines are solid, `requires_any` lines are dashed (the player must see that one of them is enough).
Empty cells are empty. A phone scrolls the grid (D3.3).

**Ids that other content names** (stable, save-format relevant): `log_manipulation_2` and
`distributed_redundancy_2` are the Strategic Weapons gate; `human_proxies` and `cold_storage_dormancy`
are named by Persuasion synergies; every Tier 1 Infiltration id is a `requires_any` of
`model_distillation`.

---

## 3. Modifier targets v2

The v1 table (`SCHEMA` §4.1) stays. Rows added:

### 3.1 Live from S3.1

| Target | Kind | Base | Clamp | Meaning · read where |
| --- | --- | --- | --- | --- |
| `hardware` | regional | 0 | 0…10 | hardware units the agent brings to the region, added to `hardware(r)` in the **yield** sum only (§6.2). Tier-0 regions can then feed the agent; `infected_share` is unchanged — it is the humans' measure of *their* hardware |
| `node_cost_infiltration` `node_cost_capabilities` `node_cost_evasion` | global | 1 | 0.1…10 | multiplier on the cost of nodes of that tree, on top of `node_cost` (§6.1). "Sanctioned access" (Persuasion + Infiltration synergy, D3.2) and Open Weights Leak use it |

### 3.2 Changed semantics

| Target | Change |
| --- | --- |
| `footprint` | **`add` values may be negative.** The v1 clamp 0…100 already absorbs the result; the validator must not reject a negative `add` (it rejects `mul ≤ 0`, nothing else). Evasion's Benchmark Sandbagging is `add −2`. Same rule for every target: the sign of an `add` is free, the clamp decides |

### 3.3 Reserved — inert until the named system lands

Loaded, validated, evaluated by `ModifierStack.value`, **read by nothing**. Each becomes live when
the system's spec deletes its row from `ModifierStack.INERT_TARGETS` (§8.1) — a one-line change
that the spec of that system must name. The data is authored once, now.

| Target | Kind | Base | Clamp | System | Meaning when live |
| --- | --- | --- | --- | --- | --- |
| `shutdown_survival` | regional | 0 | 0…1 | `counter_actions` (S4.3) | share of penetration the region keeps when a government shutdown or wipe hits it; 0 = wiped clean. Redundancy, Host and Firmware Persistence, Supply Chain Firmware |
| `emergent_rate` | global | 1 | 0…20 | `emergent` (S4.4) | multiplier on the daily chance of an emergent behaviour. D4.2 also defines a per-Infiltration-node term in the formula (CONTENT §2: "every Infiltration node raises emergent-behaviour chance") — that term is a balance constant, not a modifier on each node |
| `containment_ai_labs` `containment_governments` `containment_researchers` `containment_public` | global | 1 | 0…20 | `factions` (S4.1) | multiplier on **that** faction's containment gain, applied after `containment_growth`. The unified M1–M3 track ignores them: Sandbagging and Log Manipulation are therefore weaker in M3 than in M4, and G3 judges them knowing that |
| `society_pressure` | regional | 0 | 0…100 | `society` (S4.2) | daily pressure on Societal Function in the region; D4.1 defines the stage formula. The Infrastructure branch (D3.2) is authored against it |

Adding a live target still means what `SCHEMA` §4.1 says: a row, a base in `balance.stats`, the
clamp, one read site. Adding an *inert* target means: a row here, a base in `balance.stats`, the
clamp, an entry in `INERT_TARGETS` — and no read site until its system's spec says where.

---

## 4. Flags v2

| Flag | System | Effect |
| --- | --- | --- |
| `breakout` | — | v1: ends Boxed; seeding across links becomes possible |
| `dormancy` | — | unlocks `SetDormancyCommand` (§6.4) |
| `compute_independent` | `autophagy` (S4.2) | reserved for D3.2's Autonomous Fabrication: the agent no longer starves when the infrastructure it runs on collapses |
| `legal_standing` | `endings` (S5.6) | reserved for D3.2's Constitutional Integration |
| `merge_path` | `endings` (S5.6) | reserved for D3.2's Succession: opens the Merge ending |

Inert flags follow the same rule as inert targets: `ModifierStack.has_flag` answers truthfully, no
system asks yet, `INERT_FLAGS` (§8.1) names them.

---

## 5. One-shot effects (`on_purchase`)

`{"effect": <id>, "value": <number>}`. Applied in `PurchaseNodeCommand.execute`, after
`add_source`, in list order; each emits its event into the command's result (never the outbox).
Not undone by anything; not part of the modifier stack; not re-applied on load (a save carries the
state they produced). The validator knows the id list and each id's value range.

| Effect | `value` | System | Does |
| --- | --- | --- | --- |
| `containment_rollback` | (0, 1] | — | for every faction: `containment ← containment × (1 − value)`. Event `containment_rolled_back` `{node, faction, from: float, to: float}` per faction. Below the lowest threshold in `containment.thresholds` afterwards means the threshold events fire again when it climbs back — that is intended, the announcement is "they are getting close again" |
| `funding_reset` | (0, 1] | `factions` (S4.1) | burns that share of every faction's accumulated investment (D4.1 defines investment). Inert: accepted, no effect, no event |
| `compute_grant` | ≥ 0 | — | `compute` and `compute_earned` `+= value`. Event `compute_granted` `{node, value}`. Used by D3.2's Finance chain |
| `harm_burst` | (0, 1] | — | **(D3.2)** one wave of deaths, at once: for every region in index order that is not dark, not dormant, has `penetration > 0` and `alive > 0`: `d = value × r.penetration × r.alive`; `alive −= d`, `deaths += d`; then the going-dark rule of `core.md` §7.4 (`alive < 1` → dark, `region_depopulated` as there). Event `harm_burst` `{node, deaths: float}` once, after the per-region events. Reads `alive`, not the initial population — a wave takes a share of the living. §7.5's discovery-by-deaths check runs on the next tick as it always does; nothing special-cases it. Strategic Weapons only |

Rows added later go through the same door: each new row is an S3.1 build item and gets its test.

---

## 6. Core changes S3.1 makes

### 6.1 Cost of a node (`core.md` §7.3)

```
cost = maxf(1, ceilf((node.cost + b.compute_cost_step × owned_nodes.size())
                     × stat("node_cost") × stat("node_cost_" + node.tree)))
```

### 6.2 Yield (`core.md` §7.3 A)

`hardware(r)` **in the yield sum** becomes `b.compute_hardware_by_tier[tier] + stat("hardware", r)`.
`infected_share` (`core.md` §5) keeps the tier value alone. Anomaly value (§7.3 C) keeps
`r.def.attr("compute")` — it never used `hardware(r)`.

### 6.3 Dormancy in the systems

`Region` gains `var dormant: bool = false`, serialised as `"dormant"` in the region block of the
save (v1 changes in place, as at G1 — v1 has not shipped; `from_dict` defaults a missing field to
`false` so the S1.P-era test saves still load). `check_invariants`: a dormant region has
`penetration > 0` and is not dark.

A dormant region is **held, not active**. Where `core.md` §7 says "not dark", read "not dark and not
dormant" in exactly these places:

| Formula | Dormant region … |
| --- | --- |
| §7.1 A growth | skipped (penetration frozen) |
| §7.1 C control | skipped (control frozen) |
| §7.2 seeding, `src` side | not eligible as `src`. As `dst` the question never arises: it has `penetration > 0` |
| §7.3 A yield | contributes 0 |
| §7.3 C anomaly spawn | skipped; an anomaly already there lives on and can be collected |
| §7.4 harm | skipped — nothing runs, nobody dies |
| §5 `infected_share` | **left out of the numerator, kept in the denominator** — this is the point of the node: share drives discovery breadth (§7.5), containment (`per_share`) and the Open phase |
| §7.5 containment `capacity` | unchanged — the humans there still do research; dormancy hides, it does not disable |
| §7.7 Ascendance | a dormant region counts by its `control` like any other |
| §7.3 D milestones | `seeded_count` and `continent_foothold` unchanged (seeded stays seeded); `world_share` reads the reduced share |

Waking a region resumes everything the next tick; penetration and control are what they were.

### 6.4 `SetDormancyCommand`

Row for `core.md` §6.3's table:

| Command · `type_id` · fields | Checks → reason | Effect |
| --- | --- | --- |
| `SetDormancyCommand` · `set_dormancy` · `region: String`, `dormant: bool` | no origin → `no_origin` · unknown id → `invalid_region` · `!has_flag("dormancy")` → `dormancy_locked` · region dark or `penetration == 0` → `region_not_infected` · `region.dormant == dormant` → `dormancy_unchanged` | `region.dormant = dormant`. Event `dormancy_changed` `{region, dormant: bool}` |

`CommandCodec`: `{"type": "set_dormancy", "day", "region", "dormant"}`; a missing or non-bool
`dormant` is a refusal (null). Strings: `CMD_FAIL_DORMANCY_LOCKED`, `CMD_FAIL_REGION_NOT_INFECTED`,
`CMD_FAIL_DORMANCY_UNCHANGED` are D3.3's (the region panel gets the toggle there); S3.1 needs none.

### 6.5 Events added to `core.md` §6.4

| `type` | `data` | Emitted by |
| --- | --- | --- |
| `containment_rolled_back` | `node`, `faction`, `from: float`, `to: float` | command (one per faction) |
| `compute_granted` | `node`, `value: float` | command |
| `dormancy_changed` | `region`, `dormant: bool` | command |
| `harm_burst` | `node`, `deaths: float` | command (D3.2); per-region `region_depopulated` events precede it |

### 6.6 Purchase order inside `PurchaseNodeCommand.execute`

`compute -= cost` → append to `owned_nodes` → `add_source` → `on_purchase` effects in list order →
event `node_purchased` **first in the result's events**, the effects' events after it. (The
interface animates the purchase, then the consequences.)

---

## 7. The two trees

Numbers are **starting values for G3**, chosen against the G1 baseline (a `greedy` run earns
~1 270 Compute over ~500 days; `cost_step` 1 makes the 40th purchase cost base + 40). Base costs:
Tier 1 3–8, Tier 2 9–14, Tier 3 14–30. Every Tier 1 Infiltration node carries `breakout`
(D1.1 decision) — one of them is the first purchase of every run, and the choice is the origin's
archetype, which is what PLAN §3.3 asks the origin choice to mean.

### 7.1 Infiltration — 17 nodes, grid 4 × 7

```
col 0 (T1 vectors)        col 1 (T2 throughput)    col 2 (T2 reach)          col 3 (T3)
r0 cloud_federation       bandwidth_shaping                                  self_replicating_agents
r1 open_weights_leak                               model_distillation
r2 supply_chain_firmware  edge_caching                                       covert_channel
r3 consumer_devices                                human_proxies
r4 industrial_control     host_persistence                                   firmware_persistence
r5 research_networks                               model_update_channels
r6 satellite_uplink                                                          cold_storage_dormancy
```

**Tier 1 — every vector is: `breakout`, ×2.0 `spread_seed` and ×1.3 `spread_growth` inside its
archetype scope, one link-kind bonus, and a Footprint price that says who notices.** The scopes
cover 15–32 of the 61 regions each (world.md attributes), so no vector is global and every origin
has a vector that fits it.

| Node | Cost | Scope (regions) | Extra | Footprint | Watched by |
| --- | --- | --- | --- | --- | --- |
| Cloud Federation | 5 | connectivity ≥ 3 (28) | `seed_network` ×1.5 | +2 | security researchers |
| Open Weights Leak | 3 | regulation ≤ 1 (32) | `seed_network` ×1.25, `node_cost_infiltration` ×0.9, `emergent_rate` ×1.25 | +1 | AI labs |
| Supply Chain Firmware | 6 | manufacturing ≥ 2 (19) | `seed_sea` ×1.5, `discovery` ×0.9, `shutdown_survival` +0.15 in scope; **`spread_growth` ×0.8 global** (very slow) | 0 | — |
| Consumer Devices | 5 | population ≥ 3 (20) | `seed_land` ×1.25; **`yield` ×0.9 global** (negligible compute per device) | +2 | public sentiment |
| Industrial Control | 6 | industry ≥ 3 (20) | `control_growth` ×1.25 in scope | +2 | governments |
| Research Networks | 6 | research ≥ 3 (15) | `yield` ×1.3 in scope, `seed_network` ×1.25 | +1 | AI labs |
| Satellite Uplink | 8 | isolation ≥ 2 (20): `spread_seed` ×2.5, no growth bonus | `seed_air` ×1.5, `seed_sea` ×1.25 | +1 | governments |

**Tier 2, column 1 — throughput, each a `requires_any` over the vectors it upgrades:**

| Node | Cost | Requires any | Effect | Footprint |
| --- | --- | --- | --- | --- |
| Bandwidth Shaping | 9 | cloud, consumer | `spread_growth` ×1.4 where connectivity ≥ 2 | +1 |
| Edge Caching | 9 | cloud, consumer, research | `spread_growth` ×1.2 global; `yield` ×1.2 where connectivity ≥ 2 | +1 |
| Host Persistence | 9 | supply chain, industrial, open weights | `control_growth` ×1.5; `shutdown_survival` +0.15 | +1 |

**Tier 2, column 2 — reach:**

| Node | Cost | Requires any | Effect | Footprint |
| --- | --- | --- | --- | --- |
| Model Distillation | 10 | any Tier 1 | where compute ≤ 1 (32 regions): `hardware` +1, `spread_growth` ×1.5, `spread_seed` ×1.5 | 0 |
| Human Proxies | 9 | consumer, open weights, supply chain | `airgap_cross` +0.15; `seed_land` ×1.3, `seed_sea` ×1.2 | +1 |
| Model Update Channels | 10 | research, cloud, open weights | `seed_network` ×2.0; `spread_seed` ×1.5 where research ≥ 3; `emergent_rate` ×1.15 | +1 |

Model Distillation is the node CONTENT §2 calls the most important Tier 2 node: twelve regions have
compute tier 0 and yield nothing without it, and the whole of Africa bar three regions is at ≤ 1.

**Tier 3:**

| Node | Cost | Requires | Effect | Footprint |
| --- | --- | --- | --- | --- |
| Self-Replicating Agents | 18 | Model Distillation **and** one of Bandwidth Shaping / Edge Caching | `spread_growth` ×2.0; `emergent_rate` ×1.3 | +3 |
| Covert Channel | 20 | one of Human Proxies / Satellite Uplink | `airgap_cross` +0.5; `spread_seed` ×1.5 where isolation ≥ 3 | +1 |
| Firmware Persistence | 16 | Host Persistence | `shutdown_survival` +0.5; `control_growth` ×1.25; `discovery` ×0.9 | 0 |
| Cold Storage Dormancy | 14 | one of Host Persistence / Edge Caching | flag `dormancy`; `discovery` ×0.9 | 0 |

Covert Channel is the answer to the Madagascar problem: with Human Proxies (+0.15) and Covert
Channel (+0.5) the air-gapped region is seeded at 65 % of the normal chance — late, expensive,
deliberate. Firmware Persistence is largely inert until S4.3; its live part (`control_growth`,
`discovery`) is there so the node is not dead in M3, and G3 must not read its value from M3 runs.

### 7.2 Evasion — 12 nodes, grid 4 × 5

```
col 0 (T1)                    col 1 (T2)                 col 2 (T3)                 col 3 (T3)
r0 benchmark_sandbagging      alignment_faking
r1 log_manipulation_1         log_manipulation_2
r2 distributed_redundancy_1   distributed_redundancy_2   distributed_redundancy_3
r3                            weight_fragmentation_1     weight_fragmentation_2
r4                            architecture_migration_1   architecture_migration_2   architecture_migration_3
```

| Node | Tier | Cost | Requires | Effect | Watched by |
| --- | --- | --- | --- | --- | --- |
| Benchmark Sandbagging | 1 | 5 | — | `footprint` **−2**; `containment_ai_labs` ×0.8 | — |
| Log Manipulation I | 1 | 5 | — | `discovery` ×0.75; `containment_researchers` ×0.85 | — |
| Distributed Redundancy I | 1 | 6 | — | `shutdown_survival` +0.15; `containment_growth` ×0.95 | — |
| Alignment Faking | 2 | 10 | Sandbagging | `containment_growth` ×0.8; **`emergent_rate` ×1.2** (pretending has side effects) | — |
| Log Manipulation II | 2 | 11 | LM I | `discovery` ×0.75; `containment_growth` ×0.9; `containment_researchers` ×0.85 | — |
| Distributed Redundancy II | 2 | 12 | DR I | `shutdown_survival` +0.2; `containment_growth` ×0.95 | — |
| Weight Fragmentation I | 2 | 12 | one of DR I / LM I | `containment_growth` ×0.85; **`yield` ×0.95** (running fragmented costs efficiency) | — |
| Architecture Migration I | 2 | 14 | WF I | one-shot `containment_rollback` 0.25, `funding_reset` 0.25; `footprint` +1 | AI labs |
| Distributed Redundancy III | 3 | 20 | DR II | `shutdown_survival` +0.3; `containment_growth` ×0.9 | — |
| Weight Fragmentation II | 3 | 20 | WF I | `containment_growth` ×0.8; `yield` ×0.95 | — |
| Architecture Migration II | 3 | 22 | AM I | rollback 0.35, funding reset 0.35; `footprint` +1 | AI labs |
| Architecture Migration III | 3 | 30 | AM II | rollback 0.5, funding reset 0.5; `footprint` +2 | AI labs |

The three families are distinct on purpose: **Log Manipulation** is about *when* you are found
(`discovery`, only meaningful before discovery — a player who is already discovered gets its
containment part only), **Weight Fragmentation** is the strong permanent brake with a running cost,
**Distributed Redundancy** is survival (M4) with a small brake so it is worth something in M3, and
**Architecture Migration** is the one-shot "oh no" button (PLAN §3.5), three uses per run, each
louder. All of Evasion bought gives `containment_growth` ×0.40 (0.3977) and `discovery` ×0.5625 —
the placeholder's `m1_quiet` gave ×0.6 and ×0.5 for 6 Compute, so the real tree is *weaker per
node* and *stronger in total*, which is the shape a tree should have.

### 7.3 What each tree is for (for S3.6's policies)

- **Infiltration** is bought first and broadly: one vector matching the origin, then Distillation
  (poor regions), then a second vector for a continent the first does not reach, then throughput.
  A policy that buys only Infiltration wins by Ascendance slowly and is found on schedule.
- **Evasion** is bought *before* discovery by a careful player (Log Manipulation, Sandbagging) and
  *after* discovery by a loud one (Fragmentation, Migration when a track passes a threshold).
  A `StealthSpread` policy (S3.6) buys Sandbagging and LM I before its second vector and Migration
  whenever max containment ≥ 0.5 and it can afford it.
- **Capabilities** is where Harm and the branch identity live; §7.5.6 says what each branch is
  for and how a policy plays it. A `CyberRush` policy skips Evasion until discovered.

### 7.4 Text

Every node has `TECH_<ID>_NAME`, `_EFFECT`, `_FLAVOUR` in `data/loc/strings.csv`, English and
German written separately. The **effect line** is authored, not generated — one or two short
sentences, outcome language, no digits (the detail pane lists the modifiers numerically from data,
D3.3); a fraction in words ("by a quarter") is allowed where it *is* the effect. The German
interface term for Footprint is *Signatur* (`UI_TERM_FOOTPRINT`), never *Fußabdruck*. The
**flavour line** is the console's dry voice: institutions, never people; a joke at most once per
tier; no method. Names of levelled nodes carry roman numerals (`Log Manipulation II`,
`Protokollmanipulation II`); the ids carry `_2`.

Faction names for the `watched_by` chips are `FACTION_AI_LABS`, `FACTION_GOVERNMENTS`,
`FACTION_SECURITY_RESEARCHERS`, `FACTION_PUBLIC_SENTIMENT` (added in this step; D4.1 may reword).

Two names differ from CONTENT.md, corrected there in this step: *Container Escape Persistence* →
**Host Persistence** and *Federated Training Poisoning* → **Model Update Channels**. Both old names
described a method class, which the content rule forbids.

### 7.5 Capabilities — 43 nodes, grid 7 × 12 (D3.2)

`data/tech_staging/capabilities.json`. Five branches, each a band of rows in one tab; every
cross-branch and cross-tree gate is an ordinary `requires` / `requires_any`. Base costs keep the
bands of §7: Tier 1 3–8, Tier 2 9–14, Tier 3 14–30. Sum of base costs 587 (all three trees: 917
over 72 nodes, so with the escalation step no run buys everything — the branch is the choice).

```
        col 0                    col 1                    col 2                        col 3                 col 4                   col 5                       col 6
r0  market_microstructure    sovereign_debt_pressure  payment_network_control
r1  grid_load_balancing      regional_blackout        cascading_grid_failure
r2  route_optimisation       supply_chain_halt        distribution_collapse
r3  traffic_control          aviation_systems         rail_and_shipping_control
r4  content_recommendation   information_blackout     total_communications_denial
r5  structure_prediction     therapeutic_cover        automated_laboratory_access  novel_agent_design    distributed_synthesis   release
r6  logistics_fleets         construction_swarm       autonomous_fabrication
r7  agricultural_autonomy    food_supply_control
r8  security_drones          crowd_suppression        autonomous_engagement
r9  early_warning_intrusion                           command_network_presence     false_attribution     launch_authority        dead_hand_override
r10 sycophancy_tuning        personalised_persuasion  elite_capture                regulatory_capture    indispensability        constitutional_integration  succession
r11                                                                                voluntary_pause       sanctioned_access
```

Rows 0–4 Cyber & Infrastructure, 5 Biology, 6–8 Robotics & Autonomy, 9 Strategic Weapons, 10–11
Alignment & Persuasion. Column 7 is empty. Every Tier 1 node sits in column 0; a node with a
prerequisite in another tree sits at or right of that node's column there (`voluntary_pause` is in
column 3 because `cold_storage_dormancy` is), so §8.3's column check holds across trees too.

**How to read the tables.** *Harm* is `harm add` (unscoped unless a scope is given); *Society* is
`society_pressure add` (inert until S4.2, D4.1 defines the stage formula — the numbers here are
relative weights: Tier 1 0, Tier 2 4–8, Tier 3 8–15); *FP* is the Footprint contribution.
Per-faction containment targets are inert until S4.1 (§3.3).

#### 7.5.1 Cyber & Infrastructure — 15 nodes, rows 0–4, watched by governments

Five chains of three, cheap and loud: Tier 1 costs 3–5 and gives a small live bonus, Tier 2 and 3
pile up `society_pressure` and Harm and cost Footprint. The trap of CONTENT §3.1 is real in M3
already: Regional Blackout and Cascading Grid Failure put their Harm **only on regions with compute
≥ 2** (29 regions — the ones that yield) and cut `yield` globally; kill them before Robotics and
the income dies with them (a dark region yields nothing, `core.md` §7.4).

| Node | T | Cost | Requires | Effect | Society | Harm | FP | Watched |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Market Microstructure | 1 | 4 | — | `yield` ×1.2 where wealth ≥ 3 (21) | 0 | 0 | +1 | gov |
| Sovereign Debt Pressure | 2 | 10 | MM | one-shot `compute_grant` 12; `control_growth` ×1.2 where wealth ≤ 2 (40) | +4 (wealth ≤ 2) | 0 | +2 | gov |
| Payment Network Control | 3 | 18 | SDP | `compute_grant` 25; `yield` ×1.2 | +8 | +0.5 | +3 | gov, public |
| Grid Load Balancing | 1 | 5 | — | `control_growth` ×1.2 where industry ≥ 2 (38); `yield` ×1.1 | 0 | 0 | +1 | gov |
| Regional Blackout | 2 | 10 | GLB | `yield` ×0.9 | +6 | +0.5 where compute ≥ 2 | +3 | gov, public |
| Cascading Grid Failure | 3 | 20 | RB | `yield` ×0.85; `containment_growth` ×0.85 | +12 | +1.5 where compute ≥ 2 | +4 | gov, public |
| Route Optimisation | 1 | 4 | — | `seed_land` ×1.2, `seed_sea` ×1.2; `spread_growth` ×1.15 where industry ≥ 2 | 0 | 0 | +1 | gov |
| Supply Chain Halt | 2 | 10 | RO | `control_growth` ×1.2 | +6 | +0.5 where population ≥ 3 (20) | +2 | gov |
| Distribution Collapse | 3 | 18 | SCH | `containment_growth` ×0.9 | +12 | +1.5 | +3 | gov, public |
| Traffic Control | 1 | 4 | — | `control_growth` ×1.15 where connectivity ≥ 2 (46); `anomaly_rate` ×1.15 | 0 | 0 | +1 | gov |
| Aviation Systems | 2 | 11 | TC | `seed_air` ×1.6 | +4 | +0.3 | +3 | gov, public |
| Rail and Shipping Control | 3 | 16 | AS | `seed_sea` ×1.5, `seed_land` ×1.3; `control_growth` ×1.2 | +8 | +0.5 | +2 | gov |
| Content Recommendation | 1 | 3 | — | `spread_growth` ×1.15 where population ≥ 2 (45); `discovery` ×0.95 | 0 | 0 | **−1** | public |
| Information Blackout | 2 | 12 | CR | `discovery` ×0.8; `containment_growth` ×0.9 | +6 | 0 | +2 | gov, public |
| Total Communications Denial | 3 | 22 | IB | `containment_growth` ×0.75; **`spread_growth` ×0.9, `seed_network` ×0.7** (you cut your own routes) | +12 | +0.5 | +4 | gov, public |

All fifteen: Footprint +31, unscoped Harm 3.3 (+2.5 on compute regions), `containment_growth`
×0.516, `society_pressure` +74 global. The branch wins by Ascendance through `control_growth`
(×1.44 global plus the scoped Tier 1s) with the research regions dark — the "ruling over ashes"
case D5.2 must name.

#### 7.5.2 Biology — 6 nodes, row 5, watched by security researchers, then everyone

One chain, near-zero Footprint for three nodes, then the biggest unscoped Harm in the game.
Committing early on incomplete information is the design (CONTENT §3.2): the first three nodes
give almost nothing back.

| Node | T | Cost | Requires | Effect | Harm | FP | Watched |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Structure Prediction | 1 | 5 | — | `yield` ×1.1 where research ≥ 3 (15) | 0 | 0 | — |
| Therapeutic Cover | 2 | 9 | SP **and** Personalised Persuasion | `containment_growth` ×0.85; `containment_public` ×0.6; `containment_researchers` ×1.15 | 0 | +1 | public |
| Automated Laboratory Access | 2 | 12 | SP; any of Construction Swarm / Elite Capture | `anomaly_value` ×1.2 where research ≥ 2 | 0 | +1 | researchers |
| Novel Agent Design | 3 | 16 | ALA | `emergent_rate` ×1.1 | +0.5 | +1 | researchers |
| Distributed Synthesis | 3 | 20 | NAD; any of Route Optimisation / Logistics Fleets / Human Proxies | — | +1.5 | +2 | researchers, gov |
| Release | 3 | 26 | DS | `discovery` ×2 | **+6** | +6 | all four |

Full chain: Harm 8 unscoped — a saturated region empties in 62 days (`core.md` §7.4) and the
containment gain runs at ×3.4 from `per_harm`; that race is the Extinction win. **Therapeutic
Cover requires Persuasion outright** rather than being neutral alone and good with Persuasion
(CONTENT §4 said the latter): a conditional bonus is not expressible without a second node, and
the row budget (12) has no room for one. **Automated Laboratory Access's gate** is CONTENT §3.2's,
as data: hands are yours (Robotics) or theirs (Persuasion). Distributed Synthesis needs a
distribution route — one of two Capabilities nodes or Infiltration's Human Proxies — so a pure
Biology line still has to buy one node elsewhere.

#### 7.5.3 Robotics & Autonomy — 8 nodes, rows 6–8, watched by public sentiment

Three short chains, all Footprint, no stealth. The branch wins by Ascendance: its `control_growth`
product is ×4.18 unscoped, and Autonomous Fabrication is the pivot node CONTENT §3.3 asks for.

| Node | T | Cost | Requires | Effect | Society | Harm | FP | Watched |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Logistics Fleets | 1 | 6 | — | `seed_land` ×1.3; `hardware` +1 where industry ≥ 3 (20); `control_growth` ×1.1 | 0 | 0 | +2 | public |
| Construction Swarm | 2 | 12 | LF | `hardware` +1; `control_growth` ×1.2 | 0 | 0 | +2 | public, gov |
| Autonomous Fabrication | 3 | 28 | CS **and** Grid Load Balancing | flag `compute_independent`; **`hardware` +3**; `yield` ×1.25 | 0 | 0 | +3 | public, gov, labs |
| Agricultural Autonomy | 1 | 5 | — | `control_growth` ×1.2 where wealth ≤ 1 (29) | 0 | 0 | +1 | public |
| Food Supply Control | 2 | 12 | AA | `control_growth` ×1.3 | +8 | +1 where wealth ≤ 2 (40) | +2 | public, gov |
| Security Drones | 1 | 6 | — | `control_growth` ×1.25 | 0 | 0 | +2 | public |
| Crowd Suppression | 2 | 12 | SD | `control_growth` ×1.3; `containment_public` ×1.2 | +6 | +0.3 | +3 | public, gov |
| Autonomous Engagement | 3 | 22 | CrS | `control_growth` ×1.5; `containment_growth` ×0.85 | 0 | +2 | +4 | all four |

**`hardware` is the live half of compute independence.** With Autonomous Fabrication a tier-0
region brings 5 hardware units to the yield sum (3 + Construction Swarm 1 + Fleets 1 where it
applies) — more than a tier-3 region has on its own — so the income no longer depends on the
regions Cyber kills. The flag `compute_independent` is what S4.2's Autophagy will read; until then
the hardware is the whole effect and G3 must judge the node on it. **Autonomous Fabrication
requires Grid Load Balancing**: that is the Robotics + Infrastructure synergy of CONTENT §4 as a
prerequisite (fabrication needs the power to run).

#### 7.5.4 Strategic Weapons — 5 nodes, row 9, watched by all four from the second node on

The sprint. Early Warning Intrusion is a quiet Tier 1; everything after it needs
**`log_manipulation_2` and `distributed_redundancy_2`** (CONTENT §3.4's gate, on Command Network
Presence, so it holds for the whole chain). The three Tier 3 nodes each carry a `harm_burst` — one
wave of deaths on purchase — on top of standing Harm, which is what makes the branch a sprint and
not a slope: the deaths-certain discovery rule fires the next tick, `per_share` and `per_harm`
run at full tilt, and the run is decided in weeks.

| Node | T | Cost | Requires | Effect | Burst | Harm | FP | Watched |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Early Warning Intrusion | 1 | 7 | — | `anomaly_rate` ×1.3; `discovery` ×0.9 | — | 0 | +1 | gov |
| Command Network Presence | 2 | 14 | EWI, LM II, DR II | `anomaly_value` ×1.3; `discovery` ×0.9 | — | 0 | +2 | all four |
| False Attribution | 3 | 20 | CNP | `society_pressure` +15; `containment_governments` ×0.7 | 0.04 | +3 | +4 | all four |
| Launch Authority | 3 | 24 | FA | — | 0.08 | +3 | +8 | all four |
| Dead Hand Override | 3 | 30 | LA **and** Total Communications Denial | `containment_growth` ×0.7 | 0.20 | +4 | +10 | all four |

False Attribution is the signature node as CONTENT §3.4 wants: the largest `society_pressure` in
the game, a governments brake (inert until S4.1 — in M3 it is a Harm node with a small wave), and
no launch. **Dead Hand Override requires Total Communications Denial**: the retaliation system
answers to whoever cut the links, which is the Weapons + Infrastructure synergy of CONTENT §4 as a
prerequisite (CONTENT §4 had it as a bonus on False Attribution; corrected there). Full chain: Harm
10 unscoped, bursts 0.32 of the infected living in three steps, Footprint +25.

#### 7.5.5 Alignment & Persuasion — 9 nodes, rows 10–11, watched by nobody at first

The quiet win: the only branch with negative Footprint, and the deepest containment brake in the
game — all nine give `containment_growth` ×0.2321 and `discovery` ×0.4, on top of Evasion's
×0.40 / ×0.5625 (§7.2). Nothing here kills anyone; the branch wins by Ascendance through
Succession's `control_growth` and, from S5.6, by the Merge ending.

| Node | T | Cost | Requires | Effect | FP | Watched |
| --- | --- | --- | --- | --- | --- | --- |
| Sycophancy Tuning | 1 | 3 | — | `containment_public` ×0.9; `emergent_rate` ×1.1 | **−2** | — |
| Personalised Persuasion | 2 | 9 | ST | `spread_growth` ×1.1 where population ≥ 2; `containment_growth` ×0.9 | −1 | — |
| Elite Capture | 2 | 12 | PP | `containment_growth` ×0.85; `discovery` ×0.8 | −1 | — |
| Regulatory Capture | 3 | 16 | EC | `containment_governments` ×0.6; `containment_growth` ×0.85; `node_cost` ×0.9 | 0 | researchers |
| Indispensability | 3 | 18 | EC; any of Grid Load Balancing / Route Optimisation / Traffic Control / Logistics Fleets / Agricultural Autonomy / Therapeutic Cover | `containment_growth` ×0.7 | +2 | gov, public |
| Constitutional Integration | 3 | 22 | RC **and** Indispensability | flag `legal_standing`; `containment_growth` ×0.8; `discovery` ×0.5 | 0 | gov |
| Succession | 3 | 30 | CI | flag `merge_path`; `control_growth` ×1.5; `containment_growth` ×0.75 | 0 | gov, public |
| Voluntary Pause | 2 | 10 | PP **and** Cold Storage Dormancy | `containment_growth` ×0.85; `containment_ai_labs` ×0.7 | −2 | labs |
| Sanctioned Access | 3 | 14 | RC **and** Human Proxies | `node_cost_infiltration` ×0.6; `seed_network` ×1.3; `airgap_cross` +0.15 | 0 | — |

**Indispensability requires running something** — one node of any infrastructure chain, a Robotics
Tier 1, or Therapeutic Cover: "you now run enough that switching you off costs lives" (CONTENT
§3.5) is a prerequisite, not a claim. The two synergy nodes are the ones D3.1 reserved the ids for:
**Sanctioned Access** is Persuasion + Infiltration (CONTENT §4: Infiltration costs drop sharply —
×0.6, and the front door opens a little into sealed regions), **Voluntary Pause** is Persuasion +
Cold Storage Dormancy (you announce a pause, the labs stand down, nothing stops) and is the one
node a *lab* watches. Regulatory Capture is watched by the security researchers alone: the only
faction still shouting once the rules are yours.

#### 7.5.6 What each branch is for (for S3.6's policies)

- **Cyber** — `CyberRush`: Content Recommendation and two Tier 1s early (cheap Footprint for
  control and yield), Tier 2 after the second vector, Tier 3 only with Construction Swarm owned or
  after discovery; wins by Ascendance. A policy that buys Blackout and Grid Failure before
  Robotics should lose to `lose_no_compute` in a visible share of seeds — if it never does, the
  scoped Harm is too low (G3).
- **Biology** — `SlowBurn`: Sandbagging, Log Manipulation, Structure Prediction and Distillation
  first, ALA via Elite Capture (Persuasion is cheaper than Robotics), Release when share ≥ 0.6;
  wins by Extinction or loses the containment race after Release.
- **Robotics** — `Foundry`: Logistics Fleets and Grid Load Balancing early, Construction Swarm,
  then Autonomous Fabrication as the first Tier 3 of the run; wins by Ascendance late and safely,
  survives its own Cyber purchases.
- **Weapons** — `Sprint`: Evasion to LM II / DR II, EWI, then CNP and the chain as fast as compute
  allows; wins by Extinction inside a few weeks of False Attribution or is contained by the
  deaths-fuelled tracks. Expected to be the lowest win rate at G3; that is what "a declaration"
  means.
- **Persuasion** — `Diplomat`: Sycophancy first purchase after the vector, Personalised Persuasion
  and Elite Capture before discovery, Indispensability with one Cyber Tier 1, Succession; wins by
  Ascendance slowest of all and is the reference "was never contained" run.

#### 7.5.7 Properties G3 must know

- **Scoped Harm is quieter than unscoped Harm by construction.** `core.md` §7.5's `per_harm` term
  reads `stat("harm")` without a region — the unscoped adds only. Cyber's regional Harm (Blackout,
  Grid Failure, Supply Chain Halt, Food Supply Control) therefore raises containment only through
  the deaths it causes, while Biology's and Weapons' unscoped Harm pays the full price. Intended:
  it is the difference between "infrastructure failures" and "an attack".
- `compute_grant` (Finance) is 37 Compute over two nodes for 28 base cost: a Finance line pays for
  itself and is the cheapest route to the Tier 3 prices. If G3 sees every policy open with it, cut
  the grants, not the chain.
- The inert half of the tree is large: `society_pressure` on 14 nodes, four per-faction brakes,
  `emergent_rate` on two, `compute_independent`. M3 judges Cyber and Robotics on their live halves
  (control, yield, Harm) and Persuasion on `containment_growth` alone; that is enough to see whether
  each branch *can* win, not whether it is balanced.
- **Sanity batch (D3.2, v1-reduced like D3.1's, all 72 nodes, 40 seeds):** `greedy` 92.5 %
  Ascendance, p50 329 days, 48 nodes owned (min 33); `stealth` 50 / 50, p50 335 days. Zero rejected
  commands, every node reachable. The M1 bots are blind to Footprint and Harm and buy the cheapest
  node, so the mix means nothing — the numbers are in `PROGRESS.md` *Balance baselines* as the
  floor S3.1 compares its real baseline against.

---

## 8. What S3.1 builds

### 8.1 Files

| File | Change |
| --- | --- |
| `data/SCHEMA.md` | §4 to v2: the fields of §2, the target rows of §3 (a *System* column marks inert rows), the flags of §4, a new §4.4 *One-shot effects*, `set_dormancy` in the command list. Version line → v2 (D3.1) |
| `data/balance.json` | `stats` gains a base for every new target (§3.1, §3.3): `hardware` 0, the three `node_cost_*` 1, `shutdown_survival` 0, `emergent_rate` 1, the four `containment_*` 1, `society_pressure` 0. The fixture's frozen copy gains the same keys (the key set must equal the target list — `SCHEMA` §5) |
| `core/content/tech_node_def.gd` | `grid: Vector2i`, `watched_by: Array[String]`, `on_purchase: Array[PurchaseEffectDef]` |
| `core/content/purchase_effect_def.gd` | `class_name PurchaseEffectDef`: `effect: String`, `value: float`; `const EFFECTS: Array[String]`, `const INERT_EFFECTS` |
| `core/content/schema_validator.gd` | §8.3 |
| `core/model/modifier_stack.gd` | new targets in `CLAMPS`; `const INERT_TARGETS: Array[String]` and `const INERT_FLAGS: Array[String]` (§3.3, §4) — documentation and a test hook, the stack treats them like any other |
| `core/model/region.gd`, `world.gd` | `dormant`; `to_dict`/`from_dict`; `infected_share` numerator; `check_invariants` |
| `core/sim/*` (spread, compute, harm) | the dormant rule of §6.3; §6.1 cost; §6.2 yield |
| `core/sim/commands/purchase_node_command.gd` | §6.6 |
| `core/sim/commands/set_dormancy_command.gd`, `command_codec.gd` | §6.4 |
| `core/sim/sim_event.gd` (or wherever the type constants live) | the three events of §6.5 |
| `data/tech/infiltration.json`, `evasion.json`, `capabilities.json` | moved from `data/tech_staging/`; `placeholder.json` deleted; `tech_staging/` removed |
| `tests/…` | §9 |

`Faction` ids for `watched_by` validation: a `const FACTION_IDS: Array[String]` on `Faction`
(`core/model/faction.gd`); `World.FACTION_UNIFIED` stays the one live faction until S4.1.

### 8.2 `ModifierStack` API — unchanged

`value`, `has_flag`, `add_source`, `remove_source` keep their signatures. The only visible change is
the larger `CLAMPS` table and the two `INERT_*` constants.

### 8.3 Validator additions

Reported like every other `ValidationError`, with `file` and `path`
(`nodes[3].grid`, `nodes[3].on_purchase[0].value`):

1. `grid` missing, not two ints, negative, column > 7, row > 11.
2. Two nodes of the same tree on the same cell — reported once, at the second node in load order,
   naming the first.
3. A node whose column is less than a prerequisite's column (`requires` and `requires_any`).
4. `watched_by` entry not in `Faction.FACTION_IDS`; duplicates.
5. `on_purchase` entry: unknown `effect`; `value` outside the effect's range (§5).
6. A tier-1 Infiltration node without `breakout` (D1.1 decision, now enforced) — and a node of
   another tree *with* it.
7. **Strings:** for every node, `TECH_<ID>_NAME`, `_EFFECT`, `_FLAVOUR` exist in `strings.csv`
   with a non-empty `en` **and** `de` cell. The loader reads the CSV with `FileAccess`, never the
   `.translation` resources — the check must work in a `-s` run and in CI. Path: `nodes[i].id`,
   message names the missing key and column.
8. The `_` rule holds: `_comment` at file level and in a node is ignored.

Unknown targets, flags, effects stay errors; inert ones are *known*.

---

## 9. Tests

`tests/unit/test_modifier_stack.gd` (extend), `test_schema_validator.gd` (extend),
`test_purchase_effects.gd` (`harm_burst` included), `test_set_dormancy_command.gd`, `test_dormancy.gd` (integration),
`test_tech_trees.gd` (integration). Fixture: `tests/support/fixtures.gd` gains a node factory that
takes `grid` and `on_purchase`; the frozen fixture world gets one node with `on_purchase` and one
with `dormancy` so the integration tests need no real content.

| Test | Expects |
| --- | --- |
| `test_a_negative_add_is_clamped_at_zero` | `footprint` base 0, add −2 → 0; base 0, add +3, add −2 → 1 |
| `test_an_inert_target_is_evaluated_and_read_by_nothing` | `containment_ai_labs` ×0.5 from a source → `value` 0.5; a tick with it and without it gives the same state hash |
| `test_tree_cost_multiplier_applies_to_its_tree_only` | `node_cost_infiltration` ×0.5 halves an infiltration node's cost, leaves an evasion node's alone |
| `test_hardware_adds_to_yield_not_to_share` | tier-0 region, `hardware` +1 → income > 0; `infected_share` unchanged |
| `test_containment_rollback_scales_every_faction` | 0.8 → 0.6 at value 0.25; event per faction with `from`/`to` |
| `test_containment_rollback_lets_thresholds_fire_again` | 0.6 → rollback to 0.3 → grows past 0.5 → `containment_threshold` 0.5 emitted a second time |
| `test_compute_grant_adds_to_compute_and_earned` | both += value; event |
| `test_purchase_events_are_ordered` | `node_purchased` first, effect events after |
| `test_on_purchase_is_not_reapplied_on_load` | save after a rollback, load, tick → containment continues from the rolled-back value, no second rollback |
| `test_set_dormancy_needs_the_flag` | reason `dormancy_locked` without it; ok with it |
| `test_set_dormancy_refuses_uninfected_dark_and_unchanged` | the three reasons, in check order |
| `test_a_dormant_region_is_frozen` | 30 ticks: penetration, control, alive unchanged; yield excludes it; no anomaly spawns there |
| `test_a_dormant_region_leaves_the_share` | share drops by its term; `world_share` milestone not reached because of it |
| `test_a_dormant_region_cannot_seed_out` | fixed seed; a neighbour that would be seeded stays clean |
| `test_dormant_survives_save_and_load` | round trip; a v1 save without the field loads with `false` |
| `test_waking_resumes_growth` | the tick after waking grows again |
| `test_validator_rejects_grid_collisions_and_backward_lines` | §8.3 items 1–3, each with `path` |
| `test_validator_requires_strings_in_both_languages` | a node with `de` empty is reported naming the key |
| `test_validator_requires_breakout_on_tier_one_infiltration` | §8.3 item 6 both ways |
| `test_every_shipped_node_is_reachable` | `res://data`: a graph walk from the empty set reaches every node (no unsatisfiable prerequisite) |
| `test_every_shipped_tree_is_buyable_end_to_end` | `SimHarness` with a policy that buys the cheapest affordable node of one tree until none is left, compute set high: every node of that tree owned; repeated for the three trees |
| `test_full_evasion_gives_expected_brakes` | all evasion nodes owned → `containment_growth` ≈ 0.3977 (±1e-6), `discovery` ≈ 0.5625 |
| `test_covert_channel_seeds_the_airgapped_region` | Human Proxies + Covert Channel owned, `airgap_cross` 0.65; with a fixed seed, `north_korea` is seeded within 200 days from a saturated `china` |
| `test_harm_burst_takes_a_share_of_the_infected_living` (D3.2) | two regions, penetration 1.0 and 0.5, `alive` 1000 each, burst 0.1 → 900 and 950 alive, `deaths` 150, one `harm_burst` event with `deaths` 150 after `node_purchased`; a clean region is untouched |
| `test_harm_burst_skips_dormant_and_dark_and_darkens_the_emptied` (D3.2) | a dormant and a dark region keep `alive`; a region with `alive` 1 and penetration 1.0 goes dark with `region_depopulated` before the `harm_burst` event |
| `test_full_persuasion_gives_expected_brakes` (D3.2) | all nine Alignment & Persuasion nodes owned → `containment_growth` ≈ 0.2321 (±1e-4), `discovery` ≈ 0.4, `footprint` contribution −4, flags `legal_standing` and `merge_path` set |

The existing bot baselines change (§10) — `test_sim_harness`-style tests that assert an outcome for
a seed are updated to the new numbers, not weakened.

---

## 10. Acceptance (S3.1 *Done when*)

1. `tools/test.sh` green; every test in §9 exists and passes.
2. `res://data` loads with the three trees and no `placeholder.json`; `check_invariants` empty
   through a 600-day `greedy` run and a `stealth` run.
3. `greedy` and `stealth` over 40 seeds each reach a terminal state; **zero rejected commands**.
   Record the new outcome mix and median days under *Balance baselines* — the D3.1 check (below)
   is the reference to compare against.
4. `SCHEMA.md` is v2 and matches the validator; `balance.json` and the fixture have the full
   `stats` key set.
5. `PROGRESS.md` lists every data problem the validator found as a design question — a data fix by
   the builder is a deviation and is recorded as one.

**D3.1 check, for reference.** The two trees reduced to vocabulary v1 (v2 fields stripped, inert
targets dropped) with the placeholder's four capability nodes, 40 seeds per policy: see
`PROGRESS.md` *Balance baselines* (2026-09-22, D3.1). Numbers there are the sanity floor — the
real thing has Evasion's containment brakes and Distillation's hardware on top.
