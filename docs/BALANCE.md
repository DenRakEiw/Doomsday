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
