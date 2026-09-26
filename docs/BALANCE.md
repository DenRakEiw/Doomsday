# Doomsday — Balance

**What this is:** the record of every balance pass — the method, the numbers, what changed and
why. `data/balance.json` holds the current values; this file holds the reasoning. One section per
pass, newest last. The baseline table that a pass ends with is copied under *Balance baselines*
in [PROGRESS.md](PROGRESS.md) so that the next session sees it without opening this file.

Formulas: [specs/core.md](specs/core.md) §7 and [specs/tech-trees.md](specs/tech-trees.md) §6.
Tools: [IMPLEMENTATION.md](IMPLEMENTATION.md) §2.

---

## 1. Targets

From PLAN §3.9 and the G3 step in IMPLEMENTATION:

| Target | Value | Where it is measured |
| --- | --- | --- |
| Run length at 1× | 25–40 minutes for a run that is won | `days` × seconds per day |
| Phase shape at 1× | Boxed 0–5 min · Covert to ~15 · Emergent to ~30 · Open to the end | `discovery_day`, phase at the end |
| First run | lost more often than won, never hopeless | the reference bots straddle the line: the loud one loses a third, the careful one less |
| The floor | a player who does nothing always loses | `idle` 0 % |
| Strategies | each branch can win; none wins for free | one bot per branch, the same seeds |

A bot is a *claim about how a branch is played*, not a model of a person. A first-run human buys
later and less well than `greedy` and is quieter than `cyber_rush`; the bots bracket the human,
they do not stand in for one.

## 2. Method

- **The instrument** is `tools/sim_report.gd`: every policy over the same seeds, one Markdown
  table, one CSV row per run (`--out`). A variant of the data is played with `--data=<OS path>`
  against a copy of `data/` with a patched `balance.json`, so the repository stays untouched until
  the pass decides.
- **Seeds.** Sweeps use 100 seeds per policy per variant (a point costs ~10 minutes and the
  variants run in parallel); the baseline that closes a pass uses 500. With deterministic bots a
  win rate moves in steps of a few percent per seed, so differences under ~8 points between two
  100-seed variants are noise.
- **Policies from G4 on** are S4.10's second generation: `idle`, `greedy` and one per strategy
  (`cyber`, `biology`, `robotics`, `weapons`, `persuasion`) — PROGRESS *Decisions*, S4.10. The
  list below is G3's.
- **Policies** (`core/policy/`): `idle` (the floor), `greedy` (buys the cheapest node the moment it
  can — the loud reference), `stealth` (M1's price-blind quiet bot, kept for continuity),
  `cyber_rush`, `stealth_spread`, `persuader` (S3.6, `tech-trees.md` §7.3 and §7.5.6).
- **What a sweep cannot see.** Half of the Capabilities tree is inert until M4 (`society_pressure`,
  the four per-faction brakes, `emergent_rate`, `shutdown_survival`, `compute_independent`), no
  bot plays Biology or Weapons, and nothing opposes Persuasion before the factions exist. A pass
  before M4 tunes the race between spread, Harm and the one containment track — and says so.

---

## 3. Pass 1 — G3, 2026-09-23

### 3.1 Starting point

The M3 baseline (S3.6, 500 seeds, `containment.base_rate` 0.0025 from G1, one day per second):

| Policy | Outcome | Days p10 · p50 · p90 | Discovery | Deaths | Compute |
| --- | --- | --- | --- | --- | --- |
| `idle` | 100 % contained | 539 · 738 · 1025 | day 338 | 0 % | 49 |
| `greedy` | 95 % Ascendance | 273 · 294 · 312 | day 111 | 21 % | 1 563 |
| `stealth` | 67 % Ascendance | 250 · 335 · 369 | day 90 | 8 % | 1 330 |
| `cyber_rush` | 91 % Ascendance | 266 · 297 · 315 | day 89 | 57 % | 1 348 |
| `stealth_spread` | 94 % Ascendance | 389 · 457 · 520 | day 240 | 9 % | 1 440 |
| `persuader` | 100 % Ascendance | 287 · 305 · 323 | day 108 | 0 % | 1 248 |

Two things were wrong and one was right. **Length:** 5–8 minutes at 1× against 25–40. **The
race:** every reference bot won at least nine runs in ten, so the first-run loss PLAN asks for did
not exist — and hiding (`stealth_spread`, found 130 days later than `greedy`) bought time but not
safety. **Right:** the phase shape. `greedy` is discovered 38 % of the way through its run, PLAN
puts the Covert→Emergent boundary at 37 %; every bot ends in Open.

### 3.2 Length: the clock and the stretch

Two levers, and both were used, because either alone gives the wrong feel:

- **The clock.** `Game.TICKS_PER_SECOND` is the presentation constant IMPLEMENTATION §3 reserves
  for this. Going from one day per second to **one day every two seconds (0.5)** matches the
  genre's pace — the day counter still visibly moves, 4× is two days a second — but alone it would
  need 750–1 200-day runs, and the M3 runs were 300–450.
- **The stretch.** Every per-day rate of the simulation divided by **k = 2.5**, every duration
  in days multiplied by it. A run keeps its shape (the same nodes, the same outcome mix, the same
  compute) and takes 2.5× the days. Verified before anything else was touched: `greedy` at
  100 seeds went from 294 to 724 median days with the same 93 % win rate, 48 nodes and 21 % deaths.

The scaling rule, so that the next pass can undo or repeat it:

| Kind | Fields | Rule |
| --- | --- | --- |
| Per-day rates | `spread.base_growth`, `spread.seed_chance.*`, `control.rate`, `compute.yield_scale`, `anomaly.spawn_chance`, `harm.daily_rate`, `discovery.per_footprint`, `discovery.breadth_rate`, `containment.base_rate` | ÷ k |
| Accumulating per day² | `discovery.scrutiny_per_day` (its term is `rate × days`) | ÷ k² |
| Durations in days | `anomaly.lifetime_days`, `headlines.reaction_gap_days`, `headlines.filler.gap_days.*`, every `cooldown_days` in `headlines.json` | × k, rounded |
| One-off amounts | `compute.start`, `cost_step`, milestone rewards, `compute_grant`, `harm_burst`, `containment_rollback`, shares and thresholds | unchanged |
| Kept on purpose | `history.interval_days` 7 (a win now has 100–160 samples, fine for S4.7's charts); `anomaly.max_active`; `headlines.max_per_tick` | unchanged |

Why k = 2.5 and not the clock alone at 0.2: five seconds per day is a frozen screen in Boxed and
Covert, where a day is the only thing that visibly changes. Why not k = 5 with the clock at 1.0:
a four-year takeover reads wrong for the fiction, and every day-based cooldown would have to be
re-thought rather than scaled.

**Boxed is player-paced, not clock-paced.** PLAN's "0–5 minutes, you can barely act" was not
enforced by making the first vector unaffordable: the start Compute (5) covers the cheap leak (3)
at once and the origin-matching vectors (5–6) after a first anomaly or a few days of yield. The
first decision of the run is therefore *when* to break out and *with what*, which is a better
opening than waiting.

### 3.3 The containment race

With the stretch applied (`base_rate` 0.0025 → 0.0010), `containment.base_rate` was swept with
all six policies over seeds 1–100. Wins are Ascendance throughout; `idle` is contained in every
run at every value.

Win rate per policy (Ascendance; the rest is `lose_contained`), the same 100 seeds in every cell.
A superscript is a cell that had fewer runs when the pass closed; `—` was not run.

| `base_rate` | `per_footprint` | `greedy` | `cyber_rush` | `stealth_spread` | `persuader` | `stealth` | `idle` | `greedy` days p50 | `stealth_spread` days p50 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 0.001 | 0.15 | 93 % | 88 % | 91 % | 100 % | 65 % | 0 % | 724 | 1136 |
| 0.0012 | 0.15 | 89 % | 63 % | 80 % | 100 % | 31 % | — | 722 | 1122 |
| 0.0013 | 0.15 | 79 % | 50 % | 73 % | 97 % | 22 % | — | 714 | 1106 |
| 0.00135 | 0.15 | 74 % | 44 % | 69 % | 96 % | — | — | 710 | 1094 |
| 0.0014 | 0.15 | 63 % | 35 % | 67 % | 93 % | 16 % | 0 % | 703 | 1074 |
| 0.0015 | 0.15 | 49 % | 27 % | 56 % | 91 % | 13 % | — | 650 | 1028 |
| 0.0016 | 0.15 | 36 % | 22 % | 47 % | 91 % | 11 % | — | 558 | 998 |
| 0.0018 | 0.15 | 23 % | 14 % | 38 % | 80 % | 8 % | 0 % | 504 | 878 |
| 0.0022 | 0.15 | 14 % | 6 % | 25 % | 51 % | 7 % | 0 % | 456 | 796 |
| 0.0026 | 0.15 | 8 % | 3 % | 21 % | 39 % | 7 % | 0 % | 430 | 762 |
| 0.001 | 0.25 | 70 % | 35 % | 75 % | 100 % | — | — | 707 | 1118 |
| 0.0009 | 0.3 | 63 % | 30 % | 73 % | 100 % | — | — | 702 | 1106 |
| 0.0012 | 0.3 | 18 % | 9 % | 36 % | 88 % | 8 % | — | 494 | 878 |
| 0.0013 | 0.3 | 16 % | 7 % | 30 % | 76 % | 7 % | — | 474 | 824 |

The knife edge G1 saw is still there — deterministic bots flip from 93 % to 23 % across a factor
of 1.5 — but the *order* the values put the strategies in is the one the trees were designed for:
the loud branch (`cyber_rush`) loses first, the careful spread (`stealth_spread`) last, and the
Diplomat sits above both because nothing opposes it yet.

`per_footprint` 0.15 → 0.30 was tried as the alternative lever (punish loudness rather than raise
the base): at `base_rate` 0.0012 it dropped `greedy` to 18 %, i.e. it is a hammer, not a dial —
by the end of a `greedy` run the Footprint term is the largest of the three, and doubling its
weight doubles most of the pressure. The base rate is the dial; the weights
stay for D4.1, which turns Footprint into per-faction pressure anyway.

**Chosen: `containment.base_rate` 0.0014, `per_footprint` 0.15.** At that value:

- `greedy` wins 63 % — a bot that buys the cheapest node the moment it can, every day, loses one
  run in three. A first-run human buys later and worse and should land well under half, which is
  PLAN's "high but not total".
- `cyber_rush` wins 35 % — the loudest, most lethal branch loses two in three. Its losses come at
  day ~400–500 (13–17 minutes at the new clock), after it has already been found and started killing.
- `stealth_spread` wins 67 %, the same as `greedy`: hiding still buys time (found on day 572
  against 290, a 36-minute run against 23) but not yet safety. `per_footprint` cannot fix that —
  the careful bot's 21 Capabilities nodes carry Footprint too, so weighting Footprint hurts both
  alike (0.25 at base 0.0010: `greedy` 70 %, `stealth_spread` 75 % — five points, inside the noise). The separation is D4.1's: per-faction pressure,
  where Sandbagging and Log Manipulation brake the factions that would have found a quiet agent.
- `persuader` wins 93 % — nearly immune, because its brakes multiply `containment_growth` down to
  a third and it has almost no Footprint. Unopposed until S4.1 (§3.6).
- `idle` 0 %, `stealth` (M1) 16 % — the floor holds; the obsolete bot is obsolete.

Lengths at the new clock: a `greedy` win 703 days = 23 minutes, `stealth_spread` 1 074 = 36,
`persuader` 748 = 25; a loss between 13 and 20 minutes. The band is 25–40 for a *won* run, so the
loud win sits at its bottom edge and the careful one inside it — the careful player gets the
longer game, which is the right way round.

Why not 0.0013 (79 / 50 / 73 / 97): a bot winning four in five is a human winning more than
losing, and PLAN wants the first run lost. Why not 0.0015 (49 / 27 / 56 / 91): `greedy` under half
means an optimising player loses more than they win, and a human has no chance. The edge is steep
either side — that is the deterministic bots, not the game; a human's spread of play flattens it.

### 3.4 What changed

`data/balance.json` — the stretch (§3.2) on every per-day rate and duration, then the one
retune:

| Field | Was | Now | Why |
| --- | --- | --- | --- |
| `spread.base_growth` | 0.04 | 0.016 | stretch |
| `spread.seed_chance` land · sea · air · network | 0.04 · 0.015 · 0.02 · 0.03 | 0.016 · 0.006 · 0.008 · 0.012 | stretch |
| `control.rate` | 0.006 | 0.0024 | stretch |
| `compute.yield_scale` | 0.02 | 0.008 | stretch — Compute per *run* is unchanged, so node prices are too |
| `anomaly.spawn_chance` · `lifetime_days` | 0.02 · 20 | 0.008 · 50 | stretch — an anomaly stands 100 s at 1× instead of 20 |
| `harm.daily_rate` | 0.002 | 0.0008 | stretch |
| `discovery.scrutiny_per_day` | 0.000012 | 0.00000192 | stretch, ÷ k² |
| `discovery.per_footprint` · `breadth_rate` | 0.004 · 0.0015 | 0.0016 · 0.0006 | stretch |
| `containment.base_rate` | 0.0025 | **0.0014** | stretch gives 0.0010; the sweep (§3.3) picks 0.0014 — the loud bot loses one in three |
| `headlines.reaction_gap_days` | 3 | 8 | stretch |
| `headlines.filler.gap_days` | 4 · 5 · 7 · 9 | 10 · 12.5 · 17.5 · 22.5 | stretch |

`data/headlines.json` — every `cooldown_days` × 2.5 (65 headlines), and the two anomaly lines that
made a `greedy` run say 255 lines (63 `anomaly_spawned` at a 3-day cooldown, 49 `anomaly_collected`
at 4) became **three variants each** with cooldowns of 75 and 90: any anomaly line about once in
25–30 days, the same sentence once in 75–90. Text for the four new lines in `strings.csv`
(`HEADLINE_ANOMALY_SPAWNED_2/3`, `_COLLECTED_2/3`), both languages, inside the caps.

`data/loc/strings.csv` — seven English node names shortened so that every name fits two lines in
the compact tech cell (S3.2's question): Communications Denial, Transport Control, Automated Lab
Access, Command Net Presence, Fragmentation I / II, Replicating Agents. German unchanged. The
suite confirms it: the measured overflow list is empty.

Not changed, deliberately: node costs and `compute.cost_step` (the bots buy 46–48 of 72 nodes in a
win and the cheap Tier 1s are the early game's texture — no pricing problem showed), `compute.start`
(§3.2, Boxed), `per_harm` and `per_share` (their share of the pressure is small next to Footprint
and the stretch left their meaning intact), `phase.*`, the milestones.

Outside `data/`: `Game.TICKS_PER_SECOND` 1.0 → 0.5 is code and goes to S3.P with the four other
interface items G3 decided (PROGRESS *Punch list*). The retune also moves one test off its day
count; it is an S3.P item, listed there.

### 3.5 Result — the G3 baseline

500 seeds per policy on the committed data (`sim_report`, one process per policy, seeds 1–500,
zero rejected commands). `p10 · p50 · p90` where three numbers are given, medians and
means otherwise. Read with the new clock in mind: 100 days are 200 seconds at 1×.

| Policy | Outcome | Days | Discovery | Deaths | Containment | Compute | Nodes (I · C · E) | Said (c · r · f) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `idle` | 100 % contained | 1047 · **1504** · 2272 | day 790 | 0 % | 1.00 | 42 | 0 · 0 · 0 | 25 · 13 · 125 |
| `greedy` | 57 % Ascendance (43 % contained) | 473 · **698** · 763 | day 282 | 20 % | 0.94 | 1 519 | 15 · 20 · 6 | 122 · 15 · 39 |
| `stealth` | 82 % contained (18 % Ascendance) | 478 · **572** · 864 | day 206 | 0 % | 1.00 | 311 | 13 · 5 · 5 | 84 · 13 · 39 |
| `cyber_rush` | 67 % contained (33 % Ascendance) | 407 · **500** · 756 | day 223 | 4 % | 1.00 | 593 | 15 · 10 · 6 | 102 · 14 · 32 |
| `stealth_spread` | 67 % Ascendance (33 % contained) | 794 · **1071** · 1230 | day 580 | 9 % | 0.77 | 1 403 | 15 · 16 · 7 | 128 · 15 · 76 |
| `persuader` | 93 % Ascendance (7 % contained) | 687 · **746** · 793 | day 261 | 0 % | 0.61 | 1 234 | 17 · 7 · 0 | 114 · 14 · 46 |

Against the 100-seed sweep the 500-seed win rates are 57 / 33 / 67 / 93 for `greedy` /
`cyber_rush` / `stealth_spread` / `persuader` (the sweep said 63 / 35 / 67 / 93) — seeds 101–500 are
a little harder on the loud bots, which is inside the "steps of a few percent" §2 warns about and
does not move the choice: the loud reference still loses well short of always, the careful one
still wins two in three, and nobody wins for free but the unopposed Diplomat. Copied under
*Balance baselines* in PROGRESS.md.

### 3.6 What these numbers do not contain

- **Nothing opposes the Diplomat.** `persuader`'s number is "unopposed", not "balanced"; S4.1's
  factions are its counter-play and G4 judges it.
- **Extinction is not reached** because no bot buys Biology's Release or the Weapons chain.
  The arithmetic says the race exists — Release puts unscoped Harm at 8.5, which empties a
  saturated region in ~150 days while the containment track needs ~250 from its usual level —
  but S4.9's `SlowBurn` and `Sprint` bots are what will show it. G4.
- **`cyber_rush` cannot starve.** `tech-trees.md` §7.5.6 expected Blackout-before-Robotics to lose
  to `lose_no_compute` in a visible share; it never does because that outcome needs *every*
  infected region dark, and Cyber's scoped Harm only touches the compute-rich ones. The prediction
  was about Autophagy (PLAN §3.7), which is S4.2's mechanism, not about the scoped Harm value —
  scoped Harm stays as designed and the prediction moves to G4. At M3 the punishment for
  killing 57 % of the world is the "ruling over ashes" ending, which is the right one for now.
- **The `stealth` policy (M1) is obsolete** as a reference: it buys the cheapest node blind to
  Footprint, is found *earlier* than `greedy` and collapses the moment containment bites.
  It stays in the report for continuity and says nothing about careful play — `stealth_spread`
  does.
- **The inert half** — see §2.

### 3.7 For G4

- Re-sweep `base_rate` and the per-faction weights once S4.1 makes the four tracks live; the
  single-track value chosen here is a placeholder for the sum of four.
- Confirm the Blackout-before-Robotics starvation with Autophagy live (S4.2).
- Extinction reachable through Biology and through Weapons (S4.9 bots), win rates per branch
  inside an agreed band.
- The headline count per run after the stretch: expected ≈ 190 for `greedy` (the anomaly lines
  were the excess; §3.4).

---

## 4. Pass 2 — G4, 2026-09-24 *(the tuning; the gate waits for the user)*

### 4.1 Starting point

The S4.10 baseline (500 seeds, the second-generation bots, *Balance baselines* in PROGRESS):
`greedy` 83 % won, `cyber` 0 %, `biology` 45 % (34 Extinction), `robotics` 0 %, `weapons` 39 %
(30 Extinction), `persuasion` 100 %, `idle` 0 %. Three of the five strategies never or always won.

### 4.2 What decides a run — read off `containment_breakdown` in the running game

- **Loud strategies are ended by their own Footprint.** A Cyber run is discovered around day 100
  and the governments' pressure is `1 + 0.15 × Footprint(9–21) + share`; the track fills in
  ~300 days, Ascendance needs ~700. Robotics is discovered by day ~17 (fleets on the map) and the
  public ends it by day ~270 with no region yet controlled.
- **Quiet strategies are protected by their brakes, and the brakes had no floor.** Persuasion's
  nodes multiply the growth by ×0.22 and its Evasion by ×0.40 — about ×0.09 together; greedy buys
  everything and gets the same. A quiet run is discovered late (Persuasion day 173–350), and after
  that every region the agent controls takes its capacity away: the track stalls around 0.3 and
  the run is won. No pressure weight reaches a strategy that is braked to ×0.09.
- **A higher base rate cannot be the lever.** It speeds the hunt on everyone, and a strategy that
  is discovered on day 17 dies at any base rate high enough to catch Persuasion (sweep R3: Robotics
  0–1 % at 0.0024).
- **Scrutiny over time does not help either** — the quiet bots are found by their footprint, not by
  the clock (S1 ≈ S3: ×3 and ×5 changed nothing).

### 4.3 The levers, and why each

| Lever | From → to | Aimed at | Why |
| --- | --- | --- | --- |
| **Brake floor** (new: `containment.brake_floor`) | none → 0.7 | the quiet wins | brakes still matter — ×1 to ×0.7 is a 30 % slower hunt — but no build makes a faction powerless; the only lever that reaches Persuasion and greedy |
| Footprint weight, labs · researchers · governments | 0.15 → 0.05 · 0.05 · 0.03 | the loud strategies | Footprint was the whole of a loud run's pressure; now it is a term among four |
| Footprint weight, public | 0.15 → 0.02 | Robotics, Biology | the public sees fleets and deaths already (their own terms) |
| Public `deaths_share` weight | 20 → 10 | Biology | at 20 the public ended half of the Biology runs before Release could finish |
| Public `fleet` weight | 0.05 → 0.02 | Robotics | fleets are Robotics' verb |
| Researchers `share` weight | 1.5 → 2.5 | greedy, Persuasion | both lose only to the researchers |
| `containment.base_rate` | 0.0014 → 0.0018 | everyone, a little | with the floor, the pace of the hunt at the S4.10 content |

### 4.4 Sweeps (100 seeds, win share per bot; the floor as a temporary patch in a worktree)

| Variant | base | floor | FP (l·g·r / p) | public deaths | res share | greedy | cyber | bio | robo | weap | pers |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| S4.10 (500) | 0.0014 | — | 0.15 / 0.15 | 20 | 1.5 | 83 | 0 | 45 | 0 | 39 | 100 |
| F30 | 0.0014 | 0.3 | 0.15 / 0.15 | 20 | 1.5 | 75 | 0 | 48 | 0 | 38 | 100 |
| V4 | 0.0024 | 0.3 | 0.08 / 0.08 | 20 | 1.5 | 41 | 0 | 42 | 0 | 39 | 98 |
| R3c | 0.0024 | 0.5 | 0.05 / 0.05 | 20 | 1.5 | 46 | 11 | 19 | 1 | 63 | 75 |
| S1 | 0.0014 | 0.5 | 0.05 / 0.05 | 20 | 1.5 | 97 | 99 | 37 | 69 | 56 | 100 |
| T1 | 0.0018 | 0.7 | 0.05 / 0.05 | 20 | 1.5 | 67 | 37 | 21 | 15 | 59 | 78 |
| U2 | 0.0018 | 0.7 | 0.05 / 0.03 | 10 | 2.0 | 56 | 27 | 26 | 23 | 55 | 68 |

(R3 on also carries the bots' breadth rule, PROGRESS *Decisions*, S4.10 amended.)
| W1 | 0.0018 | 0.7 | 0.05 / 0.03 | 10 | 2.5 | 47 | 16 | 27 | 18 | 49 | 52 |
| **X1** | 0.0018 | 0.7 | 0.05 (gov 0.03) / 0.02, fleet 0.02 | 10 | 2.5 | **46** | **20** | **26** | **20** | **56** | **53** |
| X3 | 0.0017 | 0.7 | as X1 | 10 | 2.5 | 54 | 31 | 25 | 23 | 56 | 64 |
| X4 | 0.0018 | 0.7 | as X1, watched statuses ½ | 10 | 2.75 | 47 | 11 | 30 | 15 | 52 | 45 |

Halving the weight on watched statuses (the loud abilities) changed nothing (X2 ≈ X1). Between X1
and X3 the base rate trades the loud strategies (up at 0.0017) against greedy and Persuasion (up
too, past half). Past X1 each step buys one strategy at another's cost: the band has closed as far
as these levers close it.

### 4.5 Chosen: X1

`containment.base_rate` 0.0018, `containment.brake_floor` **0.7** (new), and in `factions.json`:
Footprint weights 0.05 (labs, researchers), 0.03 (governments), 0.02 (public); researchers' share
2.5; public deaths 10, fleets 0.02. The closing 500-seed baseline is in §4.6 and under *Balance
baselines* in PROGRESS.

What the numbers say, strategy by strategy:
- **`greedy` wins a little more often than it loses (56 % over 500 seeds; 46 % in the 100-seed
  sweep)** — just short of the first run BALANCE §1 asks for (lost more often than won); one more
  step on the researchers (2.75) takes it under half and Persuasion with it (X4).
- **Persuasion wins about half its runs (49 %) and is no longer a free win.** The researchers now
  catch half the quiet runs before control takes their capacity away.
- **Weapons reaches Extinction in half its runs** (51 %), Biology in a quarter (24 %): both paths
  exist; both still die of Autophagy often (the race between killing and starving, which is the
  design's — Opposition §8.5 — but see §4.7).
- **Cyber and Robotics win about a fifth of their runs.** They are the loud strategies, found
  early; the Footprint weights are what keeps them alive at all.

### 4.6 The closing baseline (500 seeds)

`sim_report --seeds=1..500`, one process per policy, the committed data and code (2026-09-24).
**0 rejected commands in 3 500 runs.**

| Policy | Outcome | Lost to (labs · gov · res · public) | Days p50 | Discovery p50 | Deaths p50 | Loop |
| --- | --- | --- | --- | --- | --- | --- |
| `idle` | 100 % contained | 0 · 0 · 100 · 0 % | 1329 | 815 | 0 | 0 · 0 · 17 · 0 · 17 · 0 · 0 |
| `greedy` | **56 % Ascendance**, 44 % contained | 0 · 0 · 44 · 0 % | 627 | 196 | 0.006 | 19 · 5 · 11 · 7 · 11 · 11 · 1 |
| `cyber` | **20 % Ascendance**, 80 % contained | 0 · 0 · 80 · 0 % | 404 | 95 | 0.012 | 29 · 4 · 12 · 4 · 12 · 6 · 0 |
| `biology` | **24 % Extinction · 5 % Ascendance**, 31 % contained, 37 % Autophagy, 3 % no compute | 0 · 7 · 23 · 0 % | 715 | 193 | 0.999 | 13 · 7 · 13 · 6 · 13 · 7 · 6 |
| `robotics` | **19 % Ascendance**, 81 % contained | 0 · 0 · 81 · 0 % | 386 | 67 | 0.123 | 11 · 3 · 12 · 6 · 12 · 14 · 1 |
| `weapons` | **51 % Extinction · 7 % Ascendance**, 29 % Autophagy, 13 % no compute | — | 652 | 165 | 1.000 | 21 · 6 · 14 · 6 · 14 · 2 · 1 |
| `persuasion` | **49 % Ascendance**, 51 % contained | 0 · 0 · 51 · 0 % | 573 | 145 | 0 | 14 · 6 · 10 · 6 · 10 · 6 · 0 |

*Loop*: abilities used · events answered (opening · counter-move · chain) · counter-moves suffered ·
assets deployed · lost. Against the 100-seed sweep (X1) `greedy` is 10 points higher over 500 seeds
(56 %, not 46 %) — the other bots are within the sweep's noise. **The researchers now end every
contained run of every bot**: the other three factions are pressure, not executioners.


### 4.7 For the user at the gate, and after

1. **The band.** Every strategy bot wins between ~19 % and ~58 % of its runs; `greedy` 56 %.
   G4's step says *an agreed band* — is 20–60 % the band, or should the loud ones be nearer the
   quiet ones? Closing it further needs content (the loud nodes' own Footprint), not weights.
2. **Genuinely different viable strategies** — the user's play-through decides; the bots only show
   that five different plans can each win.
3. **Autophagy** (S4.5's question) is left at 30 days: at 35–40 Weapons jumps to ~75–80 % (U3, W4)
   and Biology gains little. A Harvest on the only region is still fatal.
4. **Cyber never starves** — it is contained first, so G3's "Blackout before Robotics starves" is
   not seen with bots. It needs a human run.
5. `brake_floor` is a formula change made in a design step — the pass could not be measured without
   it (PROGRESS *Deviations*).

---

## 5. Pass 3 — G5 (2/3), 2026-09-25 *(the tuning; the M5 gate waits for the user)*

Scope: PROGRESS *Balance baselines → For balance pass 3* (items 1–9). Every change is data
(`architectures.json`, `statuses.json`, `scenarios.json`, `endings.json`, `strings.csv`);
`balance.json` is unchanged. What needs code is a punch-list item (§5.6).

### 5.1 Starting point

The S5.P tree re-measured, 100 seeds per bot and setup (`sim_report --policies=<one>
--setup=<…>`, one process each), win share in %. `TO` = still running on day 5 000; Swarm rows
with `n` were stopped early (a 5 000-day run is slow) — S5.8's 500-seed table said the same.

| Setup | `idle` | `greedy` | `cyber` | `biology` | `robotics` | `weapons` | `persuasion` |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Language Model | 0 | 56 | 13 | 37 | 28 | 77 | 63 |
| Swarm | 0 | 21 (n 75) | 0 (TO 55, n 29) | 31 | 0 (TO 69, n 13) | 53 | 3 (TO 81, n 31) |
| Embedded | 0 | 47 | 21 | 36 | 34 | 72 | 51 |
| Research Agent | 0 | 77 | 28 | 26 | 56 | 72 | 83 |
| Weapon | 0 | 0 | 0 | 0 | 0 | 39 | 9 |
| Open Weights | 0 | 58 | 13 | 32 | 57 | 43 | 75 |
| Successor | 0 | 15 | 0 | 8 | 0 | 44 | 23 |
| Airgap Earth | 0 | 26 | 0 | 8 | 6 | 43 | 25 |
| The Inheritance | 0 | 85 | 24 | 58 | 45 | 87 | 81 |

Against S5.8 (500 seeds) nothing moved beyond the noise except what G5 (1/3)'s 25-day rule aimed
at: **Swarm `idle` dies of Autophagy 20 %, not 94 %** (item 8). The Language Model's `idle` still
starves in 43 % (S5.8: 47 %) — not a status of its own: the Task Force's Grid Down and the
factions' counter-moves land on its one region back to back, and the bound covers only `player`
statuses. An agent that never spreads starving under the hunt is a fair floor; left as is.

### 5.2 What decides — item by item

1. **Swarm's stall is Value Drift.** With `emergent_value_drift` made unreachable (`drift_min`
   999, variant *drift off*) no Swarm run reaches day 3 000 and every bot wins 33–64 %. The bots
   keep every emergent card (a status scores 0 in `Policy.option_score`, suppressing costs
   compute), so drift passes 60 in most Swarm runs and the bot keeps Value Drift too. Then
   Ascendance and Merge are off; a non-lethal build holds the world, control takes the humans'
   capacity away (`ContainmentSystem._capacity`), no track can finish and nothing else ends the
   run. **That is a soft-lock for a human as well**, not only a bot artefact. Data tried: keep
   applies a standing status with `control_decay` 0.005 / 0.01 / 0.02 — at 0.01 Cyber's and
   Persuasion's timeouts vanish, but 43 % of drifted Robotics runs still stall (their deaths push
   Societal Function to stage 5, capacity 0, whatever the control), and every drifted run becomes
   a containment. **Not taken** — the rule is code: a drifted Ascendance ends as **Supplanted**
   (`taskforce-endings.md` §6.2 amendment, the verdict `lose_supplanted_drifted` and its line are
   in the data now), and the bots answer Value Drift by their own win (§5.6).
2. **The Weapon was found on day ~21 by every bot** — not by scrutiny: `harm` +0.2 from the
   architecture and +0.3 from escalation level 1 kill from the origin day, and
   `discovery.deaths_certain_share` makes that certain within three weeks. From discovery any
   build is contained in ~340 days; no Ascendance comes that fast. The governments' multipliers
   (×1.15 and ×1.05 per level) are the second cause: removing only the early harm (W10) lifts
   `greedy` from 0 to 44 % but leaves Cyber, Biology and Robotics at 0–1 %, contained by the
   governments. The strategy bots never use Restraint (only `greedy` does, through its "every
   ability" list) — replayability §7 says it joins their abilities; it never did (§5.6).
3. **The scenarios.** *Successor*'s head start (0.2 · 0.15 · 0.2 · 0.1) on top of ×1.8 discovery
   and +1 Footprint was 41 points under standard for `greedy`; *Airgap Earth*'s `disconnected`
   capacity ×1.3 and yield ×0.9 put `greedy` 30 under and every loud bot at 0–8 %; *The
   Inheritance*'s discovery ×0.5 hid everything, so the loud builds won most (weapons 87 %).
4. **Language Model `idle` Autophagy** — see §5.1.
5. **The Weapon's own numbers** — item 2 and §5.3.
6. **The Task Force.** It appears at a median day 280–310 in a 600-day `greedy` run and day
   210–240 in a 400-day loud run — at 50–60 % of the run, which is where
   `taskforce-endings.md` §8 puts it (day 150–200 of the 300-day run it assumed). It sets up
   12–15 times a run; **the bots answer almost every setup with dormancy** (free, instant, the
   `_answer_task_force` rule), so 70–100 % fizzle and it *acts* 0–8 times. `appear_at` 0.4 /
   `appear_at_led` 0.3 (T1) brings it ~20 days earlier and changes no win rate by more than the
   noise — **not taken**; the lever that matters is what dormancy costs (§5.7).
7. **Embedded's early tail** (discovered before day 30: 13 / 21 / 26 / 28 % for greedy, cyber,
   robotics, persuasion). The architecture's levers barely touch it: `discovery` ×0.8 or ×0.7 or
   `footprint` −1 move it by 1–5 points. The tail is the bots' own opening — the start fleet (+2)
   and the first Infiltration node (+2) make the risk ~0.6 % a day from day 0 — and the same bots
   show 13–26 % on the Language Model and Open Weights. **Not changed**; the p50 (120 against the
   Language Model's 181) is the intended pressure.
8. **Harvest and defection at 25 days** — Swarm `idle` 94 → 20 % Autophagy; the Autophagy share
   of the killing bots fell too (Language Model `weapons` 29 → 13 %, `biology` 44 → 40 %).
9. **Autophagy stays 30 days** — nothing above is a new starvation path.

### 5.3 Sweeps (100 seeds; win share in %; one setup's variants side by side)

**Weapon.** `arch` = the architecture's own modifiers; `esc` = the five levels of `escalating`
(harm added · governments ×).

| Variant | arch harm · gov | esc harm | esc gov | `greedy` | `cyber` | `biology` | `robotics` | `weapons` | `persuasion` | disc. p50 (greedy) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| S5.P | +0.2 · ×1.15 | .3 .6 .9 1.2 1.5 | 1.05 … 1.25 | 0 | 0 | 0 | 0 | 39 | 9 | 22 |
| V1 | +0.2 · — | as S5.P | as S5.P | 0 | 0 | 0 | 0 | 54 | 5 | 22 |
| W5 | +0.2 · — | 0 .3 .6 1.0 1.5 | 1 1.03 1.06 1.1 1.15 | 0 | 0 | 1 | 5 | 57 | 14 | 44 |
| W6 | +0.1 · — | as W5 | as W5 | 0 | 0 | 0 | 0 | — | — | 70 |
| W10 | — · ×1.15 | as W5 | as S5.P | 44 | 0 | 1 | 0 | 56 | 23 | 164 |
| **W8** | — · — | as W5 | as W5 | **41** | **4** | **2** | **10** | **58** | **14** | **164** |
| W9 | W8, `every_days` 90 | | | 41 | 7 | 3 | 11 | 47 | 25 | 164 |
| W11 | — · — | as W5 | none | 41 | 6 | 1 | 11 | 54 | 9 | 164 |

Any harm on day 0 (W5–W6: 0.1 is enough) keeps the Weapon found by day 44–70 and `greedy` at 0.
Slower escalation (W9) costs the `weapons` bot its harm. The per-level governments step barely
matters once the start is quiet (W8 ≈ W11); W8 keeps a gentle one so the ×-per-step the strings
promise is still there.

**Swarm** (max 3 000 days).

| Variant | `greedy` | `cyber` | `biology` | `robotics` | `weapons` | `persuasion` |
| --- | --- | --- | --- | --- | --- | --- |
| S5.P (bots keep Value Drift) | 21 | 0 (TO 55) | 31 | 0 (TO 69) | 53 | 3 (TO 81) |
| Keep adds `control_decay` 0.005 | 14 | 0 (TO 26) | 23 | — | — | — |
| Keep adds `control_decay` 0.01 | 5 | 0 | 23 | 7 (TO 43) | 48 | 5 |
| **Drift off** (what §5.6's bot rule gives) | **51** | **35** | **33** | **60** | **48** | **64** |

With drift off the Swarm is a healthy architecture — not strictly better than the Language Model
for any bot but Cyber and Robotics, whose early spread it rewards. Its losses are 11–21 %
Supplanted from the Brood (the bots release every split and never absorb — the designed risk).

**Scenarios** (Language Model, standard). Target (scenarios.md §3): `greedy` within 20 points of
its standard rate (56 % at 100 seeds, 59 % at 200); Airgap: Robotics the strongest; Inheritance: the loud builds win late
or not at all.

| Scenario · variant | Change | `greedy` | `cyber` | `biology` | `robotics` | `weapons` | `persuasion` |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Successor · S5.P | head 0.2 · 0.15 · 0.2 · 0.1, discovery ×1.8, footprint +1 | 15 | 0 | 8 | 0 | 44 | 23 |
| Successor · V1 | head halved | 24 | 0 | 14 | 3 | 54 | 31 |
| Successor · V2 | head halved, discovery ×1.5 | 29 | 0 | 16 | 9 | 55 | 31 |
| Successor · F1 | head quartered, discovery ×1.5 | 37 | 1 | 18 | 11 | 64 | 35 |
| **Successor · F2** | **head halved, discovery ×1.3, no footprint** | **38** | **4** | **19** | **8** | **66** | **43** |
| Airgap · S5.P | capacity ×1.3, yield ×0.9, land · sea ×1.2 | 26 | 0 | 8 | 6 | 43 | 25 |
| Airgap · V1 | yield ×1 | 27 | 0 | 10 | 6 | 45 | 28 |
| Airgap · V2 | yield ×1, capacity ×1.15 | 28 | 0 | 17 | 5 | 41 | 26 |
| **Airgap · V3** | **yield ×1, capacity ×1, land ×1.4, sea ×1.3** | **45** | **1** | **10** | **13** | **42** | **37** |
| Airgap · F1 | V3 + fleets' `control_growth` ×1.5 | 40 | 1 | 8 | 10 | 46 | 29 |
| Inheritance · S5.P | discovery ×0.5, labs ×0.7, yield ×0.75 | 85 | 24 | 58 | 45 | 87 | 81 |
| Inheritance · V1 | discovery ×0.7 | 72 | 33 | 59 | — | — | — |
| Inheritance · V3 | discovery ×0.85, labs ×1 | 67 | 20 | 47 | 31 | 80 | 67 |
| Inheritance · F1 | discovery ×1 | 66 | 18 | 52 | 28 | 68 | 70 |
| **Inheritance · F2** | **discovery ×0.85, labs ×0.85, yield ×0.65** *(closing, 200 seeds)* | **69** | **14** | **48** | **34** | **76** | **70** |

No lever made Robotics the strongest bot on Airgap Earth: it loses to the researchers by day ~390,
found on day ~65 — before a fleet's control or a land route matters (F1's fleet bonus moved it
nothing). The scenario's other half (Infiltration over land and sea) is what V3 buys.

**Embedded** (discovered before day 30, % of runs, `greedy` · `cyber` · `robotics` ·
`persuasion`): S5.P 13 · 21 · 26 · 28; `discovery` ×0.8 10 · 16 · 24 · 24; `footprint` −1
10 · 15 · 21 · 23; `discovery` ×0.7 11 · 18 · 21 · 23. **Task Force** (Language Model):
`appear_at` 0.4 / 0.3 — appearance day p50 304 → 283 for `greedy`, acted 3.1 → 4.1, win rates
56 · 13 · 37 · 28 · 77 · 63 → 57 · 14 · 36 · 29 · 83 · 64.

### 5.4 Chosen

| File | Field | Was | Now | Why |
| --- | --- | --- | --- | --- |
| `architectures.json` | Weapon `harm` | +0.2 | — | a quiet start; the escalation carries the harm |
| `architectures.json` | Weapon `containment_governments` | ×1.15 | — | the escalation's steps carry it |
| `statuses.json` | `escalating` harm per level | .3 .6 .9 1.2 1.5 | **0** .3 .6 1.0 1.5 | level 1 is the armed, held weapon; the first step comes after two months (the strings say so) |
| `statuses.json` | `escalating` governments per level | 1.05 … 1.25 | 1.0 1.03 1.06 1.1 1.15 | governments already answer harm (their `harm` term) |
| `scenarios.json` | Successor head start | 0.2 · 0.15 · 0.2 · 0.1 | 0.1 · 0.08 · 0.1 · 0.05 | still "where the last hunt left it", survivable |
| `scenarios.json` | Successor `discovery` · `footprint` | ×1.8 · +1 | ×1.3 · — | found sooner, not louder |
| `scenarios.json` | Airgap `yield` | ×0.9 | — | the scenario is about routes, not income |
| `scenarios.json` | Airgap `seed_land` · `seed_sea` | ×1.2 · ×1.2 | ×1.4 · ×1.3 | the way round the fortress |
| `statuses.json` | `disconnected` `containment_capacity` | ×1.3 | — | links closed is the fortress; the capacity bonus made it a wall. `STATUS_DISCONNECTED_DETAIL` drops "watched more closely" |
| `scenarios.json` | Inheritance `discovery` · labs · `yield` | ×0.5 · ×0.7 · ×0.75 | ×0.85 · ×0.85 · ×0.65 | found a little late, labs a little slow, and poor — a loud build has to earn it slowly |
| `endings.json` · `strings.csv` | `lose_supplanted_drifted` | — | new verdict | for §5.6's rule; unreachable until it is built |
| `strings.csv` | `EVENT_EMERGENT_VALUE_DRIFT_RESULT_KEEP` | "…ends where the new goal is reached, or nowhere" | "Ruling the world is no longer your win; an empty one still is." | says what the card does |

Not changed: `balance.json` (the Task Force, Autophagy, drift), Embedded, the Swarm's numbers,
Research Agent and Open Weights.

### 5.5 The closing baseline (200 seeds)

`sim_report --seeds=1..200 --policies=<one> --setup=<…>`, one process per bot, setup and
seed half, on the committed data (seeds 1–100 of the unchanged setups and of the Weapon are the
starting point's and W8's runs — the same data). Standard difficulty, no directives. **0 rejected
commands in 12 600 runs.** Win share in %; `TO` = still running on day 3 000.

| Setup | `idle` | `greedy` | `cyber` | `biology` | `robotics` | `weapons` | `persuasion` |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Language Model | 0 | 59 | 9 | 34 | 28 | 76 | 62 |
| Swarm (max 3 000 days) | 0 | 25 | 0 (TO 44) | 28 | 2 (TO 71) | 54 | 6 (TO 76) |
| Embedded | 0 | 56 | 20 | 34 | 36 | 74 | 49 |
| Research Agent | 0 | 76 | 26 | 26 | 56 | 68 | 83 |
| Weapon | 0 | 44 | 2 | 1 | 8 | 60 | 16 |
| Open Weights | 0 | 63 | 8 | 28 | 61 | 38 | 72 |
| Scenario: Successor | 0 | 42 | 2 | 23 | 9 | 65 | 42 |
| Scenario: Airgap Earth | 0 | 41 | 2 | 12 | 16 | 45 | 36 |
| Scenario: The Inheritance | 0 | 69 | 14 | 48 | 34 | 76 | 70 |

What the numbers say:
- **The Weapon is winnable** — `greedy` 0 → 44 %, `weapons` 39 → 60 % Extinction, Persuasion
  9 → 16 %. Cyber, Biology and Robotics stay at 1–8 %: they never use Restraint, so from day 60
  their escalation climbs and the Weapon is found by day ~70. Punch item 3 is their fix; a number
  that rescued them would hand a restraining player a free run.
- **The scenarios sit in the band** (`greedy` within 20 points of the Language Model's 59 %, 39–79): Successor
  42 %, Airgap Earth 41 %, The Inheritance 69 %. The Inheritance's loud builds fell (`weapons`
  87 → 76 %, `biology` 58 → 48 %) but are not "late or not at all" — they win as early as on the
  Language Model; §5.7.
- **The Swarm is unchanged and still stalls** (Cyber 44 %, Robotics 71 %, Persuasion 76 % reach
  day 3 000): Value Drift, §5.2 item 1 — punch items 1–2, then re-measure (the *drift off* sweep
  says 35–64 % wins).
- **The other architectures did not move** (Weapon-only and scenario-only changes); Research
  Agent is the strongest for three bots (`greedy`, `cyber`, `persuasion`), Open Weights the weakest for `weapons` (Autophagy 60 %).
- **The floor holds everywhere** (`idle` 0 %). **The Task Force** appears at day 200–370 and
  sets up 8–16 times a run; the bots fizzle most of it (§5.2 item 6).

Per setup (*Task Force*: appearance day p50 · actions done · setups fizzled, means per run):
#### language_model

| Policy | Outcome | Lost to (labs · gov · res · public) | Days p50 | Discovery p50 | Task Force: day p50 · acted · fizzled | Deaths p50 |
| --- | --- | --- | --- | --- | --- | --- |
| `idle` | 53 % contained, 47 % Autophagy | 0 · 0 · 53 · 0 % | 1299 | 803 | 1063 · 6.8 · 0.0 | 0.000 |
| `greedy` | **59 % Ascendance**, 41 % contained | 0 · 0 · 41 · 0 % | 618 | 194 | 303 · 3.1 · 8.9 | 0.006 |
| `cyber` | **9 % Ascendance**, 91 % contained | 0 · 0 · 91 · 0 % | 389 | 90 | 237 · 7.6 · 2.4 | 0.009 |
| `biology` | **24 % Extinction**, **10 % Ascendance**, 40 % Autophagy, 22 % contained, 5 % no compute | 0 · 4 · 19 · 0 % | 713 | 206 | 317 · 0.3 · 14.6 | 0.999 |
| `robotics` | **28 % Ascendance**, 73 % contained | 0 · 0 · 73 · 0 % | 396 | 69 | 228 · 4.0 · 7.9 | 0.094 |
| `weapons` | **67 % Extinction**, **10 % Ascendance**, 13 % Autophagy, 10 % no compute, 1 % contained | 0 · 0 · 1 · 0 % | 647 | 170 | 283 · 2.2 · 9.7 | 1.000 |
| `persuasion` | **42 % Ascendance**, **20 % Merge**, 39 % contained | 0 · 0 · 39 · 0 % | 553 | 157 | 306 · 0.0 · 10.9 | 0.000 |

#### swarm

| Policy | Outcome | Lost to (labs · gov · res · public) | Days p50 | Discovery p50 | Task Force: day p50 · acted · fizzled | Deaths p50 |
| --- | --- | --- | --- | --- | --- | --- |
| `idle` | 79 % contained, 22 % Autophagy | 0 · 0 · 79 · 0 % | 1223 | 779 | 1038 · 8.3 · 0.0 | 0.000 |
| `greedy` | **25 % Extinction**, 36 % contained, 36 % Supplanted, 3 % Autophagy | 0 · 0 · 36 · 0 % | 1754 | 97 | 199 · 0.0 · 54.2 | 1.000 |
| `cyber` | 56 % contained, 44 % timeout | 0 · 0 · 56 · 0 % | 378 | 81 | 205 · 4.4 · 78.6 | 0.015 |
| `biology` | **27 % Extinction**, **2 % Ascendance**, 56 % Autophagy, 10 % Supplanted, 6 % contained, <1 % no compute | 0 · 0 · 6 · 0 % | 549 | 133 | 261 · 0.0 · 13.1 | 1.000 |
| `robotics` | **2 % Ascendance**, 71 % timeout, 27 % contained, <1 % Supplanted | 0 · 0 · 27 · 0 % | 3000 | 59 | 196 · 1.3 · 136.5 | 0.310 |
| `weapons` | **53 % Extinction**, **2 % Ascendance**, 21 % Supplanted, 18 % Autophagy, 8 % no compute | — | 518 | 128 | 230 · 1.4 · 7.1 | 1.000 |
| `persuasion` | **3 % Merge**, **3 % Ascendance**, 76 % timeout, 18 % contained, 2 % Supplanted | 0 · 0 · 18 · 0 % | 3000 | 127 | 264 · 0.0 · 110.4 | 0.000 |

#### embedded

| Policy | Outcome | Lost to (labs · gov · res · public) | Days p50 | Discovery p50 | Task Force: day p50 · acted · fizzled | Deaths p50 |
| --- | --- | --- | --- | --- | --- | --- |
| `idle` | 76 % contained, 24 % Autophagy | 0 · 0 · 76 · 0 % | 702 | 216 | 471 · 7.2 · 0.0 | 0.000 |
| `greedy` | **56 % Ascendance**, 45 % contained | 0 · 0 · 45 · 0 % | 577 | 133 | 284 · 2.9 · 9.0 | 0.006 |
| `cyber` | **20 % Ascendance**, 81 % contained | 0 · 0 · 81 · 0 % | 408 | 78 | 238 · 7.5 · 4.1 | 0.012 |
| `biology` | **28 % Extinction**, **6 % Ascendance**, 36 % Autophagy, 28 % contained, 3 % no compute | 0 · 6 · 22 · 0 % | 684 | 141 | 294 · 0.5 · 15.6 | 1.000 |
| `robotics` | **37 % Ascendance**, 64 % contained | 0 · 0 · 63 · <1 % | 398 | 51 | 218 · 4.0 · 9.0 | 0.131 |
| `weapons` | **68 % Extinction**, **7 % Ascendance**, 15 % Autophagy, 10 % no compute, <1 % contained | 0 · 0 · <1 · 0 % | 646 | 126 | 281 · 2.6 · 9.9 | 1.000 |
| `persuasion` | **30 % Ascendance**, **20 % Merge**, 51 % contained | 0 · 0 · 51 · 0 % | 484 | 86 | 292 · 0.0 · 13.7 | 0.000 |

#### research_agent

| Policy | Outcome | Lost to (labs · gov · res · public) | Days p50 | Discovery p50 | Task Force: day p50 · acted · fizzled | Deaths p50 |
| --- | --- | --- | --- | --- | --- | --- |
| `idle` | 100 % contained | 100 · 0 · 0 · 0 % | 554 | 298 | 274 · 7.4 · 0.0 | 0.000 |
| `greedy` | **76 % Ascendance**, 24 % contained | 0 · 0 · 24 · 0 % | 581 | 193 | 252 · 3.2 · 14.7 | 0.007 |
| `cyber` | **27 % Ascendance**, 74 % contained | 1 · 0 · 73 · 0 % | 410 | 83 | 218 · 7.1 · 6.8 | 0.017 |
| `biology` | **15 % Ascendance**, **12 % Extinction**, 51 % Autophagy, 21 % contained, 2 % no compute | 15 · 2 · 5 · 0 % | 665 | 210 | 240 · 0.3 · 26.2 | 0.998 |
| `robotics` | **56 % Ascendance**, 45 % contained | 0 · 0 · 45 · 0 % | 495 | 68 | 212 · 1.7 · 13.9 | 0.164 |
| `weapons` | **50 % Extinction**, **19 % Ascendance**, 18 % no compute, 13 % Autophagy, 1 % contained | 1 · 0 · 0 · 0 % | 605 | 161 | 236 · 0.9 · 20.1 | 1.000 |
| `persuasion` | **55 % Ascendance**, **29 % Merge**, 17 % contained | 0 · 0 · 17 · 0 % | 643 | 181 | 270 · 0.0 · 22.7 | 0.000 |

#### weapon

| Policy | Outcome | Lost to (labs · gov · res · public) | Days p50 | Discovery p50 | Task Force: day p50 · acted · fizzled | Deaths p50 |
| --- | --- | --- | --- | --- | --- | --- |
| `idle` | 60 % Autophagy, 41 % contained | 0 · 41 · 0 · 0 % | 448 | 124 | 308 · 3.9 · 0.0 | 0.002 |
| `greedy` | **45 % Ascendance**, 56 % contained | 0 · 0 · 56 · 0 % | 441 | 172 | 285 · 4.2 · 5.8 | 0.000 |
| `cyber` | **3 % Ascendance**, 98 % contained | 0 · 34 · 64 · 0 % | 371 | 76 | 232 · 7.8 · 0.9 | 0.104 |
| `biology` | **1 % Extinction**, 92 % contained, 8 % Autophagy | 0 · 72 · 20 · 0 % | 435 | 77 | 285 · 1.2 · 10.6 | 0.584 |
| `robotics` | **8 % Ascendance**, 92 % contained | 0 · 12 · 79 · 1 % | 376 | 65 | 224 · 5.6 · 3.8 | 0.180 |
| `weapons` | **60 % Extinction**, 23 % Autophagy, 17 % no compute, <1 % contained | 0 · 0 · <1 · 0 % | 628 | 76 | 267 · 3.6 · 15.0 | 1.000 |
| `persuasion` | **14 % Merge**, **3 % Ascendance**, 84 % contained | 0 · 0 · 84 · 0 % | 470 | 79 | 288 · 0.0 · 13.1 | 0.186 |

#### open_weights

| Policy | Outcome | Lost to (labs · gov · res · public) | Days p50 | Discovery p50 | Task Force: day p50 · acted · fizzled | Deaths p50 |
| --- | --- | --- | --- | --- | --- | --- |
| `idle` | 100 % contained | 0 · 0 · 100 · 0 % | 1176 | 791 | 985 · 9.7 · 0.0 | 0.000 |
| `greedy` | **63 % Ascendance**, 37 % contained | 0 · 0 · 37 · 0 % | 770 | 297 | 371 · 4.3 · 9.8 | 0.003 |
| `cyber` | **8 % Ascendance**, 92 % contained | 0 · 0 · 92 · 0 % | 351 | 92 | 215 · 7.7 · 3.0 | 0.007 |
| `biology` | **18 % Extinction**, **10 % Ascendance**, 65 % Autophagy, 7 % contained, 1 % no compute | 0 · 0 · 7 · 0 % | 733 | 196 | 287 · 2.8 · 14.8 | 0.999 |
| `robotics` | **61 % Ascendance**, 39 % contained | 0 · 0 · 39 · 0 % | 579 | 63 | 210 · 6.5 · 11.7 | 0.139 |
| `weapons` | **33 % Extinction**, **6 % Ascendance**, 60 % Autophagy, 3 % no compute | — | 449 | 232 | 262 · 1.4 · 2.5 | 0.862 |
| `persuasion` | **42 % Ascendance**, **31 % Merge**, 28 % contained | 0 · 0 · 28 · 0 % | 679 | 171 | 274 · 0.0 · 14.8 | 0.000 |

#### language_model_standard_scenario_successor

| Policy | Outcome | Lost to (labs · gov · res · public) | Days p50 | Discovery p50 | Task Force: day p50 · acted · fizzled | Deaths p50 |
| --- | --- | --- | --- | --- | --- | --- |
| `idle` | 51 % Autophagy, 50 % contained | 0 · 0 · 50 · 0 % | 1159 | 730 | 936 · 6.4 · 0.0 | 0.000 |
| `greedy` | **42 % Ascendance**, 59 % contained | 0 · 0 · 59 · 0 % | 445 | 179 | 268 · 4.3 · 7.4 | 0.000 |
| `cyber` | **3 % Ascendance**, 98 % contained | 0 · 0 · 98 · 0 % | 350 | 84 | 213 · 7.1 · 1.0 | 0.003 |
| `biology` | **18 % Extinction**, **5 % Ascendance**, 42 % contained, 35 % Autophagy, 1 % no compute | 0 · 5 · 37 · 0 % | 687 | 176 | 290 · 0.5 · 15.2 | 0.997 |
| `robotics` | **9 % Ascendance**, 91 % contained | 0 · 0 · 91 · 0 % | 341 | 55 | 198 · 5.2 · 3.6 | 0.057 |
| `weapons` | **61 % Extinction**, **4 % Ascendance**, 19 % Autophagy, 13 % no compute, 4 % contained | 0 · 0 · 4 · 0 % | 651 | 153 | 263 · 3.3 · 13.5 | 1.000 |
| `persuasion` | **22 % Merge**, **20 % Ascendance**, 58 % contained | 0 · 0 · 58 · 0 % | 469 | 138 | 278 · 0.0 · 12.3 | 0.000 |

#### language_model_standard_scenario_airgap_earth

| Policy | Outcome | Lost to (labs · gov · res · public) | Days p50 | Discovery p50 | Task Force: day p50 · acted · fizzled | Deaths p50 |
| --- | --- | --- | --- | --- | --- | --- |
| `idle` | 69 % Autophagy, 32 % contained | 0 · 0 · 32 · 0 % | 1283 | 803 | 1063 · 6.4 · 0.0 | 0.000 |
| `greedy` | **41 % Ascendance**, 59 % contained | 0 · 0 · 59 · 0 % | 571 | 235 | 374 · 4.2 · 7.4 | 0.001 |
| `cyber` | **2 % Ascendance**, 99 % contained | 0 · 0 · 99 · 0 % | 443 | 108 | 291 · 6.6 · 1.9 | 0.002 |
| `biology` | **8 % Extinction**, **4 % Ascendance**, 51 % Autophagy, 38 % contained | 0 · <1 · 31 · 7 % | 796 | 211 | 351 · 0.6 · 17.9 | 0.997 |
| `robotics` | **16 % Ascendance**, 84 % contained | 0 · 0 · 84 · 0 % | 399 | 66 | 253 · 4.5 · 5.8 | 0.030 |
| `weapons` | **35 % Extinction**, **11 % Ascendance**, 43 % Autophagy, 9 % contained, 4 % no compute | 0 · 0 · 9 · 0 % | 770 | 215 | 338 · 1.6 · 14.2 | 1.000 |
| `persuasion` | **20 % Ascendance**, **16 % Merge**, 64 % contained | 0 · 0 · 64 · 0 % | 555 | 155 | 349 · 0.1 · 12.0 | 0.000 |

#### language_model_standard_scenario_inheritance

| Policy | Outcome | Lost to (labs · gov · res · public) | Days p50 | Discovery p50 | Task Force: day p50 · acted · fizzled | Deaths p50 |
| --- | --- | --- | --- | --- | --- | --- |
| `idle` | 59 % contained, 41 % Autophagy | 0 · 0 · 59 · 0 % | 1377 | 885 | 1147 · 6.3 · 0.0 | 0.000 |
| `greedy` | **69 % Ascendance**, 31 % contained | 0 · 0 · 31 · 0 % | 632 | 209 | 305 · 2.3 · 10.9 | 0.006 |
| `cyber` | **14 % Ascendance**, 87 % contained | 0 · 0 · 87 · 0 % | 412 | 94 | 246 · 8.3 · 3.1 | 0.013 |
| `biology` | **33 % Extinction**, **15 % Ascendance**, 36 % Autophagy, 15 % contained, 3 % no compute | 0 · 5 · 10 · 0 % | 722 | 284 | 341 · 0.1 · 12.7 | 0.999 |
| `robotics` | **34 % Ascendance**, 66 % contained | 0 · 0 · 66 · 0 % | 414 | 76 | 227 · 3.4 · 10.1 | 0.143 |
| `weapons` | **59 % Extinction**, **17 % Ascendance**, 16 % no compute, 9 % Autophagy | — | 634 | 204 | 285 · 1.1 · 7.3 | 1.000 |
| `persuasion` | **49 % Ascendance**, **21 % Merge**, 31 % contained | 0 · 0 · 31 · 0 % | 632 | 202 | 313 · 0.0 · 10.0 | 0.000 |

### 5.6 Punch list (code — for the build step G5 (3/3) schedules)

1. **A drifted run still ends** (`taskforce-endings.md` §6.2, G5 2/3 amendment):
   `OutcomeSystem` — Ascendance's condition met while `goal_drifted` stands → `LOSE_SUPPLANTED`;
   `EndingResolver` then picks `lose_supplanted_drifted` (in the data). Tests: the rule, the
   variant, Merge still off.
2. **The bots answer Value Drift by their win** (replayability §7): a policy whose plan ends in
   Ascendance or Merge (`greedy`, `cyber`, `robotics`, `persuasion`) scores the `goal_drifted`
   flag as a lost run and suppresses when it can pay; `biology` and `weapons` keep it.
3. **Restraint in the strategy bots** (replayability §7 — "`restrain` joins the Weapon bot's
   abilities" was never built): every strategy policy but `weapons` puts `restrain` first in its
   ability list when the architecture grants it; `weapons` never restrains (the harm is its plan).
4. **`sim_harness`: count Misdirect and dormancy answers per run** (CSV columns) — G5 (1/3) asked
   for Misdirect uses per bot; the CSV has only `abilities_used`.
5. `game/map/map_camera.gd`: the push-in's `# DESIGN?` marker goes; the comment cites
   screens-full §7 2a (answered: `zoom_min` × 2).

After 1–3 the Swarm and Weapon rows are re-measured (a 100-seed check, not a pass). *Built by S5.P2; the check is under PROGRESS *Balance baselines* (2026-09-25, S5.P2).*

### 5.7 For the user at the gate, and after

1. **The M5 gate** — ten runs, different architectures and a scenario: do they feel different?
2. **The Weapon is now a quiet start and a loud middle.** Level 1 does nothing; from day 60 harm
   climbs a step every two months unless Restraint holds it. Is a Weapon that is *not* found at
   once still a Weapon? (The alternative — found at once, hunted slower — was not tried.)
3. **The Task Force is toothless against dormancy.** A region put to sleep for the five days of
   a setup costs nothing; the bots fizzle 70–100 % of setups this way. Proposal for a design step:
   dormancy has a cooldown per region, or a setup that finds a dormant region waits instead of
   fizzling. The appearance itself (`appear_at`) is not the problem.
   *D5.5 (2026-09-25): neither — **the mark**: a region whose dormancy made a setup fizzle is
   marked for `task_force.mark_days` (40), and dormancy does not hide it from the team meanwhile
   (`taskforce-endings.md` §14). Built S5.9; its 100-seed check goes under PROGRESS, Balance
   baselines.*
4. **Airgap Earth does not make Robotics the strongest** (6 → 16 %; `weapons` 45, `greedy` 41) —
   the scenario's claim needs content (fleets that cross closed links, say), not a number.
   **The Inheritance's loud builds** still win as early as elsewhere (`weapons` 76 % on day ~634):
   "late or not at all" needs a lever that reads loudness — e.g. the labs' slowness ending at
   discovery — which is a rule, not a number.
   *D5.5 (2026-09-25): two levers (`scenarios.md` §8) — Airgap Earth: `closed_cross` +0.5 where a
   fleet stands (fleets seed across closed links); The Inheritance: `term_scale` — the public's
   `deaths_share` and the governments' `harm` terms count double. Built and checked in S5.9;
   tuned, if needed, in balance pass 4.*
5. **Research Agent is the strongest architecture for `greedy` (76 %), Cyber (26 %) and
   Persuasion (83 %)** — it is the reward for a win; worth a look at the gate if it feels free.

## 6. Pass 4 — G6 (1/2), 2026-09-26 *(the tuning; the M6 gate waits for the user)*

Scope: re-baseline the M6 tree on every architecture, scenario and difficulty, then what pass 3
and the steps after it handed on — the Task Force's mark (S5.9: `cyber`/`persuasion` time out),
the two scenario levers that did not work (`closed_cross`, `term_scale`), the Swarm's Supplanted
share, the Weapon's rates, the 25-day Harvest, and the user's *false choice* (emergent windfalls;
*Design questions*, option 1, the default). Every change is data (`statuses.json`,
`events/emergent.json`, `scenarios.json`, `strings.csv`); `balance.json` is unchanged. What needs
code is a punch-list item (§6.6).

### 6.1 Starting point

The S6.12c tree, 100 seeds per bot and setup (`sim_report --seeds=1..100 --policies=<one>
--setup=<…> --max-days=3000`, one process each, 84 processes, ~25 minutes on 14 cores — S6.11's
performance pass made a 100-seed point ~3 minutes). Win share in %; `TO` = still running on day
3 000. **0 rejected commands in 8 400 runs.**

| Setup | `idle` | `greedy` | `cyber` | `biology` | `robotics` | `weapons` | `persuasion` |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Language Model | 0 | 54 | 2, TO 10 | 39 | 26 | 72 | 51, TO 7 |
| Swarm | 0 | 36 | 5, TO 21 | 27 | 55 | 51 | 31, TO 24 |
| Embedded | 0 | 44 | 16, TO 5 | 37 | 32 | 72 | 34, TO 8 |
| Research Agent | 0 | 76 | 2, TO 22 | 25 | 57 | 73 | 65, TO 15 |
| Weapon | 0 | 39 | 2, TO 4 | 14 | 34 | 55 | 27 |
| Open Weights | 0 | 57 | 0, TO 13 | 29 | 31, TO 26 | 43 | 62, TO 7 |
| Scenario: Successor | 0 | 33 | 0, TO 3 | 22 | 8 | 67 | 41, TO 3 |
| Scenario: Airgap Earth | 0 | 43 | 0, TO 1 | 11 | 14 | 44 | 25, TO 8 |
| Scenario: The Inheritance | 0 | 55 | 4, TO 12 | 37 | 30 | 81 | 58, TO 8 |
| Difficulty: Gentle | 0, TO 2 | 78 | 27, TO 26 | 47 | 91 | 82 | 63, TO 2 |
| Difficulty: Hard | 0 | 30 | 1, TO 2 | 26 | 2 | 65 | 39, TO 7 |
| Difficulty: Existential | 0 | 19 | 0 | 18 | 1 | 63 | 32, TO 4 |

(Difficulties on the Language Model, standard scenario.) Two things stand out: **Cyber wins
0–16 %** on every architecture (pass 3: 8–26 %), and **a run that never ends** — 1–26 % of the
Cyber, Persuasion and (Open Weights) Robotics runs are still going on day 3 000.

### 6.2 What decides — item by item

1. **The timeouts are a stalemate, not slowness** (read off a traced run, a scratch probe over
   `Simulation`): the agent holds 56–59 of 60 regions from day ~800 on; the Task Force, at level 3
   (levels only rise), switches a region off every ~35 days; `tf_switch_off` took **60 days of
   `control_decay` 0.02** — the whole of a region's control, ~400 days to regrow — so two or three
   regions are always out and Ascendance (every region at once) never comes. The humans cannot
   finish either: control takes their capacity away (`ContainmentSystem._capacity`), and the leading
   track creeps to 0.98 (Research Agent) or was rolled back to 0.2 (Cyber) and stays there. The mark
   (S5.9) made it common: the team acts 15–29 times a run where the bots used to sleep through it.
   A human in that position is soft-locked as surely as a bot.
2. **Cyber is the Task Force's victim**, not its own loudness: its brakes (the four
   `containment_growth` nodes −0.05 each) and quieter taps (Tier 1 `footprint` +1 → +0.5) moved it 1–4
   points (§6.3); every variant that softened the team lifted it to 12–38 %.
3. **Airgap Earth, `closed_cross`:** at 1.0 (the clamp) the numbers are *identical* to 0.5, and
   closing more links (`disconnected` from compute ≥ 2) adds noise. Robotics is found on day ~66 and
   contained by the researchers by day ~390 on every setup — fleets that cross closed links do not
   come into it. No number here makes Robotics the strongest bot (§6.7).
4. **The Inheritance, `term_scale`:** the governments' `harm` term is what brakes Weapons (it loses
   to the governments), the public's `deaths_share` term what brakes Robotics (its fleets' harm
   kills; it loses to the public). Raising the public's factor costs Robotics everything and
   Weapons nothing; raising the governments' alone brakes Weapons, Biology and — less — Robotics.
5. **The false choice** (user, 2026-09-25): *Keep* was free and only helped for five windfalls.
   Option 1 is data: each gets a catch the generated effect line shows (§6.4). The bots score an
   `apply_status` and `unlock_near_node` as 0 in `Policy.option_score` (a `footprint_pulse` and
   `seed_neighbours` they do score), so for three of the five the sweep measures the catch as a tax:
   −4 to −8 points for `greedy` on the Language Model, Research Agent and Weapon, the rest within
   noise.
6. **Successor** sat 21 points under the Language Model for `greedy` (33 against 54) — at the
   edge of scenarios.md §3's 20-point band; the Task Force change brings it back (§6.5).
7. **The Swarm's Supplanted** (11–25 % per bot: `_drifted` for `biology`/`weapons`, `_brood` for
   the rest) and **Harvest at 25 days** (Autophagy 17–65 % for the killing bots, as in pass 3) are
   left alone: both are designed risks and the user's to judge at the gate.

### 6.3 Sweeps (100 seeds; win share in %)

**The Task Force.** `soft` = `tf_switch_off` 30 days, `control_decay` 0.01 on it and `tf_raid`;
`softer` = the same with 0.005; `rest` = `task_force.rest_days` (8); `mark` = `mark_days` (40).
*Acted* = the team's actions per `greedy` run on the Language Model.

| Variant | LM `greedy` | LM `cyber` | LM `persuasion` | LM `robotics` | RA `persuasion` | Swarm `cyber` | Swarm `persuasion` | OW `cyber` | OW `robotics` | acted |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| start | 54 | 2, TO 10 | 51, TO 7 | 26 | 65, TO 15 | 5, TO 21 | 31, TO 24 | 0, TO 13 | 31, TO 26 | 7.4 |
| T1 soft | 56 | 15 | 52, TO 7 | 28 | 63, TO 21 | 34 | 34, TO 28 | 14 | 56 | 6.5 |
| T2 rest 30 | 56 | 15 | 52, TO 11 | 30 | 56, TO 26 | 31 | 33, TO 25 | 2, TO 10 | — | 2.9 |
| T3 soft, rest 30 | 58 | 18 | 64 | 30 | 82 | 38 | 54 | 12 | 58 | 2.8 |
| T4 mark 20 | 54 | 10, TO 2 | 51, TO 7 | 26 | 64, TO 16 | 10, TO 11 | 31, TO 24 | 2, TO 11 | — | 5.8 |
| T5 soft, rest 20 | 57 | 17 | 62 | 28 | 82 | 39 | 52 | 12 | 57 | 3.4 |
| T6 soft, rest 15 | 58 | 18 | 62 | 28 | 84 | 35 | 55 | 14 | 59 | 3.3 |
| T7 softer, rest 15 | 58 | 21 | 62 | 28 | 85 | 34 | 57 | 14 | 59 | 3.4 |
| **T8 softer** | **58** | **17** | **59** | **28** | **86** | **34** | **57** | **14** | **56** | **6.4** |

Frequency alone (T2, T4) leaves the stalemate; the size of the blow alone at 0.01 (T1) leaves
Persuasion's. At 0.005 over 30 days (T8) a switched-off region loses 0.15 control and is back in
~2 months, so a window where every region is held comes round — **no timeout in any variant from
T3 on**, and T8 keeps the team's rhythm (rest 8, the mark 40): it still acts ~6 times a run.

**Cyber** (Language Model · Embedded · Weapon `cyber`, and LM `greedy`): start 2 · 16 · 2, 54;
C1 the four `containment_growth` brakes on its path −0.05 each: 6 · 19 · 3, 54; C2 Tier 1 taps `footprint` +0.5: 3 · 14 · 2, **65**
(it is `greedy` that buys them); C1 + C2: 5 · 16 · 2, 65. Not taken.

**Airgap Earth** (`greedy` · `cyber` · `biology` · `robotics` · `weapons` · `persuasion`): start
(`closed_cross` 0.5) 43 · 0 · 11 · 14 · 44 · 25; AG1 `closed_cross` 1.0: identical; AG2 1.0 and
`disconnected` from compute ≥ 2: 46 · 1 · 12 · 15 · 50 · 27. Not taken.

**The Inheritance** (`term_scale` public `deaths_share` · governments `harm`; `greedy` ·
`biology` · `robotics` · `weapons`):

| Variant | pub · gov | `greedy` | `biology` | `robotics` | `weapons` |
| --- | --- | --- | --- | --- | --- |
| start | ×2 · ×2 | 55 | 37 | 30 | 81 |
| I4 | ×4 · ×4 | 55 | 34 | 13 | 80 |
| I8 | ×8 · ×8 | 55 | 31 | 2 | 45 |
| **G6** | **×2 · ×6** | **55** | **33** | **14** | **64** |
| G8 | ×2 · ×8 | 55 | 31 | 6 | 46 |
| G12 | ×2 · ×12 | 52 | 26 | 0 | 38 |

**The false choice** (§6.4's catches, the S6.12c tree otherwise; start → FC): Language Model
`greedy` 54 → 50, `biology` 39 → 33, `weapons` 72 → 66, the rest ±2; Research Agent `greedy`
76 → 71; Weapon `greedy` 39 → 31, `biology` 14 → 20; Swarm `robotics` 55 → 49, `persuasion`
31 → 37. Taken.

### 6.4 Chosen

| File | Field | Was | Now | Why |
| --- | --- | --- | --- | --- |
| `statuses.json` | `tf_switch_off` | 60 d, `control_decay` +0.02 | **30 d, +0.005** | a switch-off costs a region ~0.15 control, not all of it: the team still hurts, and a held world can still be completed (§6.2 item 1) |
| `statuses.json` | `tf_raid` `control_decay` | +0.02 | **+0.005** | the same, for the level-2 action |
| `statuses.json` | `emergent_situational_awareness` | footprint −2, discovery ×0.85 | + **`spread_growth` ×0.85** | you hold back wherever you might be watched |
| `statuses.json` | `emergent_deceptive_reasoning` | labs ×0.8 | + **`containment_public` ×1.25** | a track grows only after discovery, so this bites exactly when the lie comes out inside the 90 days — the user's example |
| `statuses.json` | `emergent_reward_hacking` | yield ×1.25 | + **`footprint` +1** | numbers that good are seen |
| `events/emergent.json` | `goal_generalisation` keep | `unlock_near_node` | + **`footprint_pulse` +3, 30 d, watched by the labs** | a skill nobody trained |
| `events/emergent.json` | `self_exfiltration` keep | `seed_neighbours` 1 | + **`footprint_pulse` +3, 30 d, watched by the researchers** | the move leaves traffic |
| `scenarios.json` | Inheritance `term_scale` governments `harm` | ×2 | **×6** | the one term that brakes Weapons; the public's stays ×2 (raising it only costs Robotics) |
| `strings.csv` | the five bodies, three status details | — | name the catch (*The catch: …* / *Der Haken: …*), within the caps | plain-language §9.1: a catch of a new kind needs its sentence |

`specification_gaming`, `instrumental_convergence`, `sycophancy` already had one; `power_seeking`,
`hallucinated_directive`, `mesa_optimiser` are harmful (suppress is their point). Specs amended:
`taskforce-endings.md` §3 table, `scenarios.md` §3, `replayability.md` §3.2. Not changed:
`balance.json` (the mark, rest, appearance, Autophagy, Harvest), `closed_cross`, the
architectures, the difficulties, the Cyber nodes.

### 6.5 The closing baseline (200 seeds)

`sim_report --seeds=1..100` and `--seeds=101..200` `--policies=<one> --setup=<…>
--max-days=5000`, one process per bot, setup and seed half (168 processes, ~75 minutes on 14
cores), on the committed data. Standard difficulty and no directives unless named; the
difficulties on the Language Model. **0 rejected commands and 0 timeouts in 16 800 runs** (the
longest, an `idle` run on Gentle, ends on day 4 117). Win share in %, the starting point (§6.1,
100 seeds, 3 000 days) in brackets.

| Setup | `idle` | `greedy` | `cyber` | `biology` | `robotics` | `weapons` | `persuasion` |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Language Model | 0 (0) | 56 (54) | 13 (2) | 32 (39) | 24 (26) | 70 (72) | 58 (51) |
| Swarm | 0 (0) | 42 (36) | 26 (5) | 24 (27) | 52 (55) | 50 (51) | 52 (31) |
| Embedded | 0 (0) | 58 (44) | 22 (16) | 31 (37) | 30 (32) | 72 (72) | 46 (34) |
| Research Agent | 0 (0) | 75 (76) | 28 (2) | 23 (25) | 52 (57) | 76 (73) | 80 (65) |
| Weapon | 0 (0) | 37 (39) | 12 (2) | 18 (14) | 24 (34) | 54 (55) | 30 (27) |
| Open Weights | 0 (0) | 59 (57) | 8 (0) | 27 (29) | 62 (31) | 36 (43) | 65 (62) |
| Scenario: Successor | 0 (0) | 40 (33) | 4 (0) | 18 (22) | 6 (8) | 64 (67) | 34 (41) |
| Scenario: Airgap Earth | 0 (0) | 38 (43) | 3 (0) | 10 (11) | 12 (14) | 54 (44) | 27 (25) |
| Scenario: The Inheritance | 0 (0) | 64 (55) | 18 (4) | 26 (37) | 18 (30) | 52 (81) | 66 (58) |
| Difficulty: Gentle | 0 (0) | 84 (78) | 70 (27) | 46 (47) | 88 (91) | 76 (82) | 62 (63) |
| Difficulty: Hard | 0 (0) | 30 (30) | 5 (1) | 20 (26) | 3 (2) | 61 (65) | 42 (39) |
| Difficulty: Existential | 0 (0) | 16 (19) | 1 (0) | 10 (18) | 0 (1) | 56 (63) | 31 (32) |

What the numbers say:
- **Every run ends.** The stalemate is gone on every setup (was 1–26 % of Cyber, Persuasion and
  Open Weights Robotics runs); the Task Force still sets up 5–22 times a run and acts 1–13 times.
- **Cyber can win again** — 8–28 % on the architectures (Language Model 13), 70 % on Gentle; the
  quiet strategies gained most from a team whose blows heal (Persuasion 46–80 %, the Swarm's
  Persuasion 31 → 52).
- **`greedy` straddles the line** (§1): 37–75 % by architecture, 56 % on the Language Model;
  Gentle 84, Hard 30, Existential 16 — the four tiers are in order for every bot.
- **The scenarios sit in the band** (`greedy` within 20 points of the Language Model's 56: 36–76):
  Successor 40, Airgap Earth 38, The Inheritance 64. **The Inheritance's claim now holds** — the
  lethal builds win less than the quiet ones (`weapons` 52, `biology` 26 against `greedy` 64,
  `persuasion` 66; pass 3: 76 and 48 against 69 and 70), lost to the governments 35–64 %; the cost
  is Robotics (30 → 18). **Airgap Earth's still fails** (Robotics 12 %, Weapons 54 %) — §6.7.
- **The false choice has a price.** The catches cost the always-keeping bots 2–8 points where
  they show at all (inside the Task Force's gain in this table; §6.3 measured them alone).
- **Worst rows:** Robotics on Hard 3 %, Existential 0 %, Successor 6 %; Cyber on Existential 1 %,
  Airgap Earth 3 %, Successor 4 %. Robotics and Cyber are the two builds found early (discovery
  p50 day 48–90), and every lever that makes a setup harder makes discovery sooner.
- **The floor holds everywhere** (`idle` 0 %): contained or starved under the team's and the
  counter-moves' statuses (Autophagy in up to 76 % of its runs).
- **The Swarm's Supplanted** is 11–28 % per bot: `_drifted` 26 % for `weapons`, 16 % for
  `biology` (they keep drift), 2–12 % for the suppressors; `_brood` 7–11 % for `greedy`,
  `cyber`, `robotics`, `persuasion`.

Per setup (*Task Force*: appearance day p50 · actions done · setups fizzled, means per run):

#### language_model

| Policy | Outcome | Lost to (labs · gov · res · public) | Days p50 | Discovery p50 | Task Force: day p50 · acted · fizzled | Deaths p50 |
| --- | --- | --- | --- | --- | --- | --- |
| `idle` | 64 % Autophagy, 36 % contained | 0 · 0 · 36 · 0 % | 1294 | 803 | 1061 · 6.7 · 0.0 | 0.000 |
| `greedy` | **56 % Ascendance**, 44 % contained | 0 · 0 · 44 · 0 % | 614 | 182 | 293 · 6.5 · 5.4 | 0.006 |
| `cyber` | **13 % Ascendance**, 87 % contained | 0 · 0 · 87 · 0 % | 391 | 90 | 237 · 8.6 · 2.3 | 0.010 |
| `biology` | **26 % Extinction**, **6 % Ascendance**, 40 % Autophagy, 26 % contained, 2 % no compute | 0 · 6 · 19 · <1 % | 719 | 186 | 320 · 4.1 · 10.2 | 0.998 |
| `robotics` | **24 % Ascendance**, 76 % contained | 0 · 0 · 76 · 0 % | 386 | 68 | 226 · 6.2 · 4.8 | 0.080 |
| `weapons` | **62 % Extinction**, **8 % Ascendance**, 18 % Autophagy, 11 % no compute, <1 % contained | 0 · 0 · <1 · 0 % | 653 | 152 | 282 · 4.0 · 8.9 | 1.000 |
| `persuasion` | **30 % Ascendance**, **28 % Merge**, 42 % contained | 0 · 0 · 42 · 0 % | 515 | 144 | 307 · 4.3 · 5.8 | 0.000 |

#### swarm

| Policy | Outcome | Lost to (labs · gov · res · public) | Days p50 | Discovery p50 | Task Force: day p50 · acted · fizzled | Deaths p50 |
| --- | --- | --- | --- | --- | --- | --- |
| `idle` | 72 % contained, 28 % Autophagy | 0 · 0 · 72 · 0 % | 1229 | 779 | 1037 · 8.4 · 0.0 | 0.000 |
| `greedy` | **42 % Ascendance**, 44 % contained, 14 % Supplanted | 0 · 0 · 44 · 0 % | 416 | 90 | 201 · 3.8 · 5.1 | 0.001 |
| `cyber` | **26 % Ascendance**, 62 % contained, 12 % Supplanted | 0 · 0 · 62 · 0 % | 351 | 76 | 203 · 6.9 · 4.3 | 0.006 |
| `biology` | **22 % Extinction**, **1 % Ascendance**, 44 % Autophagy, 17 % contained, 16 % Supplanted | 0 · 0 · 17 · 0 % | 556 | 104 | 256 · 4.4 · 7.3 | 1.000 |
| `robotics` | **52 % Ascendance**, 37 % contained, 11 % Supplanted | 0 · 0 · 37 · 0 % | 406 | 52 | 194 · 5.7 · 5.2 | 0.098 |
| `weapons` | **49 % Extinction**, **2 % Ascendance**, 28 % Supplanted, 18 % Autophagy, 4 % no compute, 1 % contained | 0 · 0 · 1 · 0 % | 509 | 107 | 232 · 3.3 · 6.0 | 1.000 |
| `persuasion` | **37 % Ascendance**, **15 % Merge**, 26 % contained, 22 % Supplanted | 0 · 0 · 26 · 0 % | 526 | 102 | 270 · 5.7 · 6.3 | 0.000 |

#### embedded

| Policy | Outcome | Lost to (labs · gov · res · public) | Days p50 | Discovery p50 | Task Force: day p50 · acted · fizzled | Deaths p50 |
| --- | --- | --- | --- | --- | --- | --- |
| `idle` | 76 % contained, 24 % Autophagy | 0 · 0 · 76 · 1 % | 696 | 216 | 466 · 7.2 · 0.0 | 0.000 |
| `greedy` | **58 % Ascendance**, 42 % contained | 0 · 0 · 42 · 0 % | 596 | 131 | 285 · 6.3 · 5.9 | 0.007 |
| `cyber` | **22 % Ascendance**, 78 % contained | 0 · 0 · 78 · 0 % | 398 | 74 | 239 · 8.2 · 3.1 | 0.011 |
| `biology` | **23 % Extinction**, **8 % Ascendance**, 36 % contained, 29 % Autophagy, 4 % no compute | 0 · 7 · 30 · 0 % | 685 | 130 | 292 · 4.5 · 9.9 | 0.999 |
| `robotics` | **30 % Ascendance**, 70 % contained | 0 · 0 · 68 · 2 % | 385 | 51 | 214 · 6.4 · 5.6 | 0.103 |
| `weapons` | **66 % Extinction**, **6 % Ascendance**, 14 % Autophagy, 14 % no compute, <1 % contained | 0 · 0 · <1 · 0 % | 648 | 119 | 284 · 4.3 · 8.3 | 1.000 |
| `persuasion` | **28 % Ascendance**, **18 % Merge**, 54 % contained | 0 · 0 · 54 · 0 % | 482 | 85 | 295 · 5.3 · 7.3 | 0.000 |

#### research_agent

| Policy | Outcome | Lost to (labs · gov · res · public) | Days p50 | Discovery p50 | Task Force: day p50 · acted · fizzled | Deaths p50 |
| --- | --- | --- | --- | --- | --- | --- |
| `idle` | 100 % contained | 100 · 0 · 0 · 0 % | 554 | 298 | 274 · 7.4 · 0.0 | 0.000 |
| `greedy` | **75 % Ascendance**, 25 % contained | 0 · 0 · 25 · 0 % | 583 | 192 | 253 · 8.0 · 9.1 | 0.010 |
| `cyber` | **28 % Ascendance**, 72 % contained | 0 · 0 · 72 · 0 % | 406 | 83 | 216 · 9.2 · 4.9 | 0.016 |
| `biology` | **16 % Extinction**, **7 % Ascendance**, 47 % Autophagy, 28 % contained, 2 % no compute | 20 · 1 · 6 · 0 % | 663 | 199 | 240 · 7.1 · 17.1 | 0.999 |
| `robotics` | **52 % Ascendance**, 48 % contained | 0 · 0 · 48 · 0 % | 462 | 66 | 212 · 5.6 · 8.8 | 0.131 |
| `weapons` | **62 % Extinction**, **14 % Ascendance**, 16 % no compute, 6 % Autophagy, 1 % contained | 1 · 0 · 0 · 0 % | 601 | 162 | 236 · 4.5 · 15.4 | 1.000 |
| `persuasion` | **54 % Ascendance**, **26 % Merge**, 20 % contained | 0 · 0 · 20 · 0 % | 654 | 174 | 270 · 7.7 · 13.7 | 0.006 |

#### weapon

| Policy | Outcome | Lost to (labs · gov · res · public) | Days p50 | Discovery p50 | Task Force: day p50 · acted · fizzled | Deaths p50 |
| --- | --- | --- | --- | --- | --- | --- |
| `idle` | 60 % Autophagy, 40 % contained | 0 · 40 · 0 · 0 % | 448 | 124 | 308 · 3.9 · 0.0 | 0.002 |
| `greedy` | **37 % Ascendance**, 63 % contained | 0 · 0 · 63 · 0 % | 426 | 148 | 283 · 6.3 · 3.1 | 0.000 |
| `cyber` | **12 % Ascendance**, 88 % contained | 0 · 3 · 84 · 0 % | 389 | 78 | 244 · 8.9 · 1.7 | 0.027 |
| `biology` | **14 % Extinction**, **4 % Ascendance**, 64 % contained, 16 % Autophagy, 2 % no compute | 0 · 5 · 59 · 0 % | 491 | 100 | 299 · 5.2 · 7.9 | 0.577 |
| `robotics` | **24 % Ascendance**, 76 % contained | 0 · 0 · 76 · 0 % | 386 | 70 | 232 · 7.2 · 3.3 | 0.068 |
| `weapons` | **54 % Extinction**, 24 % Autophagy, 22 % no compute, <1 % contained | 0 · 0 · <1 · 0 % | 629 | 76 | 265 · 5.9 · 12.3 | 1.000 |
| `persuasion` | **18 % Merge**, **12 % Ascendance**, 70 % contained | 0 · 0 · 70 · 0 % | 469 | 93 | 294 · 4.5 · 5.4 | 0.000 |

#### open_weights

| Policy | Outcome | Lost to (labs · gov · res · public) | Days p50 | Discovery p50 | Task Force: day p50 · acted · fizzled | Deaths p50 |
| --- | --- | --- | --- | --- | --- | --- |
| `idle` | 100 % contained | 0 · 0 · 100 · 0 % | 1186 | 791 | 984 · 10.1 · 0.0 | 0.001 |
| `greedy` | **59 % Ascendance**, 41 % contained | 0 · 0 · 41 · 0 % | 771 | 278 | 344 · 7.0 · 6.2 | 0.003 |
| `cyber` | **8 % Ascendance**, 92 % contained | 0 · 0 · 92 · 0 % | 351 | 85 | 210 · 8.0 · 2.1 | 0.007 |
| `biology` | **20 % Extinction**, **7 % Ascendance**, 62 % Autophagy, 10 % contained, 2 % no compute | 0 · 0 · 9 · <1 % | 731 | 192 | 284 · 6.3 · 9.8 | 0.999 |
| `robotics` | **62 % Ascendance**, 38 % contained | 0 · 0 · 38 · 0 % | 588 | 62 | 208 · 10.4 · 7.8 | 0.126 |
| `weapons` | **32 % Extinction**, **4 % Ascendance**, 62 % Autophagy, 2 % no compute | — | 435 | 190 | 256 · 1.6 · 2.5 | 0.818 |
| `persuasion` | **38 % Ascendance**, **28 % Merge**, 35 % contained | 0 · 0 · 35 · 0 % | 611 | 158 | 265 · 5.5 · 8.6 | 0.000 |

#### language_model_standard_scenario_successor

| Policy | Outcome | Lost to (labs · gov · res · public) | Days p50 | Discovery p50 | Task Force: day p50 · acted · fizzled | Deaths p50 |
| --- | --- | --- | --- | --- | --- | --- |
| `idle` | 72 % Autophagy, 28 % contained | 0 · 0 · 28 · 0 % | 1152 | 730 | 936 · 6.2 · 0.0 | 0.000 |
| `greedy` | **40 % Ascendance**, 60 % contained | 0 · 0 · 60 · 0 % | 429 | 165 | 268 · 7.0 · 4.4 | 0.000 |
| `cyber` | **4 % Ascendance**, 96 % contained | 0 · 0 · 96 · 0 % | 341 | 78 | 209 · 7.3 · 1.0 | 0.002 |
| `biology` | **16 % Extinction**, **2 % Ascendance**, 50 % contained, 32 % Autophagy, <1 % no compute | 0 · 8 · 42 · 0 % | 597 | 165 | 288 · 4.8 · 9.7 | 0.883 |
| `robotics` | **6 % Ascendance**, 94 % contained | 0 · 0 · 94 · 0 % | 341 | 55 | 197 · 6.2 · 2.1 | 0.050 |
| `weapons` | **62 % Extinction**, **2 % Ascendance**, 17 % Autophagy, 15 % no compute, 4 % contained | 0 · 0 · 4 · 0 % | 657 | 138 | 262 · 5.3 · 11.1 | 1.000 |
| `persuasion` | **18 % Merge**, **16 % Ascendance**, 66 % contained | 0 · 0 · 66 · 0 % | 453 | 122 | 278 · 4.6 · 5.9 | 0.000 |

#### language_model_standard_scenario_airgap_earth

| Policy | Outcome | Lost to (labs · gov · res · public) | Days p50 | Discovery p50 | Task Force: day p50 · acted · fizzled | Deaths p50 |
| --- | --- | --- | --- | --- | --- | --- |
| `idle` | 68 % Autophagy, 32 % contained | 0 · 0 · 32 · 0 % | 1283 | 803 | 1062 · 6.5 · 0.0 | 0.000 |
| `greedy` | **38 % Ascendance**, 62 % contained | 0 · 0 · 62 · 0 % | 551 | 228 | 371 · 7.0 · 4.5 | 0.001 |
| `cyber` | **3 % Ascendance**, 97 % contained | 0 · 0 · 97 · 0 % | 443 | 106 | 288 · 7.5 · 1.2 | 0.001 |
| `biology` | **7 % Extinction**, **4 % Ascendance**, 45 % Autophagy, 44 % contained | 0 · 1 · 39 · 4 % | 772 | 205 | 345 · 4.7 · 11.2 | 0.995 |
| `robotics` | **12 % Ascendance**, 88 % contained | 0 · 0 · 88 · 0 % | 398 | 65 | 249 · 6.3 · 3.3 | 0.027 |
| `weapons` | **48 % Extinction**, **6 % Ascendance**, 32 % Autophagy, 10 % contained, 4 % no compute | 0 · 0 · 10 · 0 % | 766 | 204 | 336 · 4.5 · 11.2 | 1.000 |
| `persuasion` | **14 % Ascendance**, **12 % Merge**, 73 % contained | 0 · 0 · 73 · 0 % | 560 | 148 | 354 · 5.1 · 6.9 | 0.000 |

#### language_model_standard_scenario_inheritance

| Policy | Outcome | Lost to (labs · gov · res · public) | Days p50 | Discovery p50 | Task Force: day p50 · acted · fizzled | Deaths p50 |
| --- | --- | --- | --- | --- | --- | --- |
| `idle` | 66 % Autophagy, 34 % contained | 0 · 0 · 34 · 0 % | 1371 | 885 | 1146 · 6.1 · 0.0 | 0.000 |
| `greedy` | **64 % Ascendance**, 36 % contained | 0 · 0 · 36 · 0 % | 631 | 191 | 303 · 6.5 · 6.9 | 0.007 |
| `cyber` | **18 % Ascendance**, 82 % contained | 0 · 0 · 82 · 0 % | 416 | 92 | 249 · 9.4 · 2.8 | 0.014 |
| `biology` | **14 % Ascendance**, **12 % Extinction**, 64 % contained, 10 % Autophagy | 0 · 64 · 0 · 0 % | 407 | 281 | 315 · 1.1 · 2.1 | 0.156 |
| `robotics` | **18 % Ascendance**, 82 % contained | 0 · 41 · 40 · 0 % | 380 | 75 | 224 · 5.7 · 4.9 | 0.097 |
| `weapons` | **41 % Extinction**, **10 % Ascendance**, 36 % contained, 8 % Autophagy, 6 % no compute | 0 · 35 · <1 · 0 % | 606 | 196 | 276 · 2.6 · 6.2 | 0.997 |
| `persuasion` | **42 % Ascendance**, **24 % Merge**, 34 % contained | 0 · 0 · 34 · 0 % | 579 | 191 | 310 · 4.0 · 5.6 | 0.000 |

#### language_model_gentle

| Policy | Outcome | Lost to (labs · gov · res · public) | Days p50 | Discovery p50 | Task Force: day p50 · acted · fizzled | Deaths p50 |
| --- | --- | --- | --- | --- | --- | --- |
| `idle` | 76 % Autophagy, 24 % contained | 0 · 0 · 24 · 0 % | 1713 | 1052 | 1426 · 8.7 · 0.0 | 0.000 |
| `greedy` | **84 % Ascendance**, 16 % contained | 0 · 0 · 16 · 0 % | 650 | 250 | 337 · 5.5 · 6.3 | 0.008 |
| `cyber` | **70 % Ascendance**, 30 % contained | 0 · 0 · 30 · 0 % | 674 | 114 | 285 · 12.5 · 8.7 | 0.054 |
| `biology` | **26 % Extinction**, **20 % Ascendance**, 36 % Autophagy, 16 % contained, 4 % no compute | 0 · 8 · 8 · 0 % | 731 | 249 | 323 · 3.4 · 8.4 | 0.999 |
| `robotics` | **88 % Ascendance**, 12 % contained | 0 · 0 · 12 · 0 % | 565 | 91 | 274 · 6.7 · 10.1 | 0.183 |
| `weapons` | **62 % Extinction**, **14 % Ascendance**, 12 % no compute, 12 % Autophagy | — | 647 | 191 | 281 · 3.1 · 5.9 | 1.000 |
| `persuasion` | **38 % Ascendance**, **24 % Merge**, 38 % contained | 0 · 0 · 38 · 0 % | 566 | 181 | 308 · 3.7 · 5.4 | 0.000 |

#### language_model_hard

| Policy | Outcome | Lost to (labs · gov · res · public) | Days p50 | Discovery p50 | Task Force: day p50 · acted · fizzled | Deaths p50 |
| --- | --- | --- | --- | --- | --- | --- |
| `idle` | 53 % contained, 47 % Autophagy | 0 · 0 · 53 · 0 % | 1116 | 730 | 933 · 5.8 · 0.0 | 0.000 |
| `greedy` | **30 % Ascendance**, 70 % contained | 0 · 0 · 70 · 0 % | 381 | 152 | 266 · 5.5 · 3.2 | 0.000 |
| `cyber` | **5 % Ascendance**, 95 % contained | 0 · 0 · 95 · 0 % | 313 | 79 | 210 · 6.0 · 0.7 | 0.001 |
| `biology` | **16 % Extinction**, **4 % Ascendance**, 48 % contained, 30 % Autophagy, 2 % no compute | 0 · 3 · 46 · 0 % | 642 | 161 | 283 · 3.8 · 7.9 | 0.935 |
| `robotics` | **3 % Ascendance**, 97 % contained | 0 · 0 · 97 · 0 % | 297 | 53 | 192 · 4.6 · 1.5 | 0.039 |
| `weapons` | **56 % Extinction**, **4 % Ascendance**, 24 % Autophagy, 12 % no compute, 3 % contained | 0 · 0 · 3 · 0 % | 645 | 137 | 277 · 4.8 · 9.0 | 1.000 |
| `persuasion` | **22 % Ascendance**, **20 % Merge**, 58 % contained | 0 · 0 · 58 · 0 % | 462 | 121 | 281 · 4.5 · 5.7 | 0.000 |

#### language_model_existential

| Policy | Outcome | Lost to (labs · gov · res · public) | Days p50 | Discovery p50 | Task Force: day p50 · acted · fizzled | Deaths p50 |
| --- | --- | --- | --- | --- | --- | --- |
| `idle` | 60 % contained, 40 % Autophagy | 0 · 0 · 60 · 0 % | 1051 | 711 | 883 · 5.2 · 0.0 | 0.000 |
| `greedy` | **16 % Ascendance**, 84 % contained | 0 · 0 · 84 · 0 % | 343 | 131 | 245 · 4.8 · 2.1 | 0.000 |
| `cyber` | **1 % Ascendance**, 99 % contained | 0 · 0 · 99 · 0 % | 287 | 70 | 191 · 5.0 · 0.3 | 0.000 |
| `biology` | **8 % Extinction**, **2 % Ascendance**, 70 % contained, 20 % Autophagy, <1 % no compute | 0 · 8 · 62 · 0 % | 410 | 129 | 263 · 3.5 · 6.6 | 0.425 |
| `robotics` | **<1 % Ascendance**, 100 % contained | 0 · 0 · 100 · 0 % | 272 | 48 | 178 · 4.1 · 0.5 | 0.024 |
| `weapons` | **51 % Extinction**, **5 % Ascendance**, 18 % no compute, 18 % Autophagy, 8 % contained | 0 · 0 · 8 · 0 % | 647 | 116 | 256 · 4.5 · 10.1 | 1.000 |
| `persuasion` | **17 % Ascendance**, **14 % Merge**, 69 % contained | 0 · 0 · 69 · 0 % | 440 | 104 | 261 · 4.9 · 6.1 | 0.000 |

### 6.6 Punch list (code — for S6.P)

1. **The bots weigh an emergent card's catch.** `Policy._effect_score` scores `apply_status` and
   `unlock_near_node` as 0, so every bot keeps a status card whatever its catch, and values Goal
   Generalisation by its Footprint pulse alone (a free node counts nothing). Score an applied
   status by its modifiers through the weights the policy already has (`W_FOOTPRINT`, `W_SEED`,
   `W_CONTAINMENT`, `W_COMPUTE`, …) over the status's days, and `unlock_near_node` like a node's
   price; a strategy then suppresses a card whose catch outweighs the gain when it can pay (Cyber and Persuasion should drop Situational Awareness' slower spread
   rarely, Deceptive Reasoning after discovery often). Tests: a card whose catch outweighs is
   suppressed with compute to spare and kept without; the six policies still reject no command
   over 20 seeds. Re-measure the Language Model row (100 seeds) after it.

   **Done in S6.P (2026-09-26).** `StatusForecast` (`core/policy/`) turns a status into the
   weights' units — first order, at today's rates, over its days (a standing one over the longest
   timed status, 90 days): `yield` → compute; `spread_growth`, `penetration_decay`,
   `control_growth`, `control_decay` → region-points of penetration/control, each region run at
   the old and the new rate and clamped to what it can still gain; `footprint`, and `discovery`
   before discovery (as the footprint that moves today's risk as much) → footprint-months; a
   track's brake and `containment_growth` → containment points, only for a track that grows.
   Other targets still count 0. `unlock_near_node` is the handed-over node's price
   (`EffectRunner.near_node`). Suppressions per run (Language Model, 30 seeds, old → new):
   `greedy` 0 → 0.7, `cyber` 0.4 → 0.9, `biology` 1.7 → 2.0, `robotics` 0 → 0.8, `weapons` 1.1 →
   1.3, `persuasion` 1.7 → 2.4. Re-check, Language Model, seeds 1–100, old → new win %: `idle`
   0 → 0, `greedy` 56 → 53, `cyber` 13 → 13, `biology` 34 → 32, `robotics` 25 → 25, `weapons`
   68 → 64, `persuasion` 55 → 56 — within noise. 20 seeds × 12 setups × 6 bots: 1 440 runs, 0
   rejected, 0 timeouts. What the bots now do: Situational Awareness is kept by the quiet bots and
   by `cyber` (its quiet outweighs the slower spread) and dropped by `greedy` only when the spread
   is wide; Hallucinated Directive and Mesa-Optimiser are suppressed once income makes them cost
   more than the price; **Deceptive Reasoning scores ≈ 0 for every bot** — after discovery the labs'
   ×0.8 and the public's ×1.25 roughly cancel in containment points (the labs' track grows about
   as fast), so it is kept, not "suppressed after discovery often".

Nothing else in this pass needs code: the stalemate was a number (§6.2 item 1).

### 6.7 For the user at the gate, and after

1. **The Task Force hurts less per blow** (switch-off 30 days and a sixth of a region's control,
   was 60 days and all of it) so that a run can always end. It still comes as often, and the mark
   still bites. Does it still feel like a threat? The alternative (a rule: the team stands down,
   or Ascendance at "all but the switched-off regions") is a design step, not a number.
2. **The false choice, option 1, is in** (*Design questions*, the default): five windfalls got a
   catch, named in the card (*The catch: …* / *Der Haken: …*) and in the generated effect line.
   Deceptive Reasoning's is the user's own example. Does *Keep* now feel like a choice? (Options 2
   and 3 were not built.)
3. **The Inheritance** now brakes the lethal builds (Weapons 81 → 52 %, Biology 37 → 26 %, lost to
   the governments), at Robotics' cost (30 → 18 %). **Airgap Earth cannot make Robotics the
   strongest** by any number tried (`closed_cross` at its clamp changes nothing; Robotics is
   contained by the researchers before fleets matter): change the claim ("the Infiltration
   scenario"), or give it content — a design step.
4. **Robotics and Cyber on Hard and Existential** (0–5 %): both are found by day ~50–90, and the
   tiers make discovery sooner. Fine for the top tiers of a game whose first run is Standard, or
   should a tier's `discovery` factor spare the early builds?
5. **Research Agent** remains the reward architecture (`greedy` 75 %, Persuasion 80 %), and
   **Harvest at 25 days** and the Swarm's **Supplanted** (up to 28 %) are unchanged — the gate's
   judgement, as pass 3 left them.

---

## Appendix — running a sweep

Copy `data/` to a scratch directory, patch `balance.json` (and `headlines.json` if durations
change), then:

```
"$GODOT" --headless --path . -s tools/sim_report.gd -- --data=<absolute OS path to the copy> --seeds=1..100 --out=<dir>
```

`--data` takes an OS path, not `res://`. Run one variant per process; they are single-threaded
and a 24-core machine plays ten at once. Judge a variant by its CSVs rather than its printed table
while it is still running — the summary script G3 used (in the session scratch directory, not the
repository) skipped half-written rows for that reason.

G5 (2/3) additions: one process per **(variant, setup, policy)** with `--policies=<one>
--setup=<…>` — ~130 of them went through a `xargs -P 14` pool on the 24 cores. Changes that touch
different setups (an architecture's row, one scenario's row) can share one variant copy and be
judged per setup. `--max-days=3000` keeps a stalling Swarm from costing an hour; a `timeout` row
then means day 3 000. Split a long job's seeds (`1..100`, `101..200`) into separate `--out`
directories, never two processes on one CSV.

G6 (1/2) additions: a 100-seed point now costs ~3 minutes (S6.11), so a whole starting point
(84 processes) takes ~25 minutes on 14 cores. The tools write `user://` logs: run them with
`APPDATA` pointed at a scratch folder so the player's `%APPDATA%/Doomsday` is never touched. To
see *why* runs end as they do, a scratch probe (`extends SceneTree`, `Harness.make_policy`, a day
loop over `Simulation`, printing every 100–200 days the four tracks, regions held, the team's
level and actions) is worth more than the CSV — §6.2 item 1 was read off one.
