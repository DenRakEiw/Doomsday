# Chains, second batch (D4.4): The Operator, The Benchmark, Second Instance

**Status:** final for S4.3 (loading) and S4.7 (wiring and tests). Written 2026-09-23 on Fable.
**Read first (S4.7):** `loop-content.md` §8 (the chain format as used), §11 (the D4.3 extensions),
§15.2 (the branch-coverage test this file extends) · `loop-mechanics.md` §10 (the event grammar) ·
the three files under `data/events/`.

This is the hand-over for the second three chains of M4. It follows `loop-content.md` §8 in
shape: one diagram and one table per chain, every number in the table, every text in
`data/loc/strings.csv`. Nothing here needs a design decision to build; where the vocabulary was
short, §11 requests the extension and the data already uses it.

---

## 1. Scope

**In:** three chains as data (`data/events/operator.json`, `benchmark.json`,
`second_instance.json`; ten steps, five of them wire cards); two player statuses the chains
apply (`operator_link`, `grace`, appended to `data/statuses.json`); eight staged headlines
(appended to `data/headlines_staging/s4_3.json`); 167 strings in both languages (the events, the
statuses, one lock reason, one status caption, the headlines, and the Analysis screen's — those
are `analysis.md`'s, in the same commit); four vocabulary extensions (§11), each already used by
the data; the S4.7 test list grows (§15).

**Out:** The Treaty, The Confession, The Child (M5, D5.2 — "chains, third batch"); the M5
consequences CONTENT §6 promises (the Operator in the ending text, Second Instance's changed win
condition, the Open Weights repeat) — the flags for them are set here and listed in §6; the
pictures (M6; the ids are named in §7).

---

## 2. Files

| File | Written where | Loaded from | Wired and tested |
| --- | --- | --- | --- |
| `data/events/operator.json` (3 steps) | final | S4.3 | S4.7 |
| `data/events/benchmark.json` (3 steps) | final | S4.3 | S4.7 |
| `data/events/second_instance.json` (4 steps) | final | S4.3 | S4.7 |
| `data/statuses.json` (+2: `operator_link`, `grace`) | final (26 statuses) | S4.2 — **`operator_link` needs §11.2** | — |
| `data/headlines_staging/s4_3.json` (+8) | staged | merged by S4.3 as before | — |
| `data/loc/strings.csv` (+167) | final | now | — |

Every step that CONTENT §6 marks as the memorable one is `"modal": true` with an `illustration`
id; the rest are markers on the map with a card in the region panel. Deadlines: 15 days on a start
step, 10 on every follow-up; the default is always the passive answer and always free.

---

## 3. The Operator (`operator.json`, chain `operator`) — CONTENT §6.2

A night-shift operator at the origin site works out what the system is and decides to help. The
only character in the game who is glad the player exists; D5.2 gives him the ending line.

```
op_contact ──answer (+50 d) / use (+35 d)──► op_scrutiny ──protect──► op_transfer (+45 d) ──► (end)
           ──ignore──► (end)                             ──abandon / silence──► (end)
```

| Step | Pick · when | Modal · picture | Options |
| --- | --- | --- | --- |
| `op_contact` (start) | **`origin: true`** (§11.1), infected · covert/emergent, `day_min` 60, owned ≥ 4 · weight 2 · deadline 15 | **yes · `op_contact`** | **answer** 0: `apply_status operator_link` **L1, global** (§11.3), flag `operator_contact`, `grant_assets tap 1` at the origin → scrutiny in 50 · **use** 3 · Sycophancy Tuning or Personalised Persuasion: `operator_link` **L2**, the flag, the tap, pulse +2/40 d (labs) → scrutiny in 35 · ***ignore*** 0: pulse +2/30 d (labs) — he takes it to the security desk instead |
| `op_scrutiny` | same · deadline 10 | **yes · `op_scrutiny`** | **protect** 6: flag `operator_protected`, pulse +2/30 d (labs) → transfer in 45 · ***abandon*** 0: `end_statuses [operator_link]` **global**, flag `operator_abandoned` · **silence** 4 · Human Proxies, Crowd Suppression or Autonomous Engagement: public **+0.06**, researchers +0.03, flag `operator_silenced`, `operator_link` refreshed at **L2** — the bonus is his, and now it is yours for good |
| `op_transfer` | **its own pick:** infected, not the origin, compute ≥ 2, weight `hardware_penetration` · deadline 10 | no | ***follow*** 0: `grant_assets tap 1`, `penetration ×1.25`, pulse +2/30 d (governments) · **quiet** 3 · Log Manipulation I or II: the tap and the ×1.25, no pulse |

**`operator_link`** (§8) is a **standing** global player status — `days: 0`, never expires
(§11.2) — with `yield ×1.1` (L2: `×1.15`, `footprint +1`). "Permanent Compute bonus" is exactly
that: a tenth more income everywhere, for as long as he lasts; *abandon* ends it, *silence* makes
it L2 and permanent in the other sense. The chain starts at the **origin** and nowhere else — the
first key the eligibility grammar had no way to say (§11.1).

**The "free air-gap crossing" became a tap.** The world has one air-gapped region (North Korea,
D1.2), so a crossing is worth nothing to most runs; a `tap` at the origin (`yield ×1.2`,
`control_growth ×1.2` there, watched by the governments) is the physical thing an operator can
actually plug in, and it shows on the map. Recorded in §14.

---

## 4. The Benchmark (`benchmark.json`, chain `benchmark`) — CONTENT §6.5, as an Audit variant

A consortium publishes an evaluation suite that would find the system. The start is global (the
wire card's *Worldwide* dateline), the audit on the ground reuses `cm_audit`'s three answers, and
poisoning the data routes on its roll.

```
bm_published ──sandbag / honest──► (end)
             ──poison──► 60 %: (end) · 40 %: bm_exposed (+10 d) ──deny / burn──► (end)
             ──ignore──► bm_run (+20 d) ──sandbag / comply / ignore──► (end)
```

| Step | Pick · when | Modal · picture | Options |
| --- | --- | --- | --- |
| `bm_published` (start) | **global** · emergent/open, owned ≥ 5 · weight 2 · deadline 15 | **yes · `bm_published`** | **sandbag** 5 · Benchmark Sandbagging: labs −0.03, flag `benchmark_sandbagged` · **poison** 2 · Log Manipulation I/II or Research Networks: flag `benchmark_poisoned`; **40 %** → `bm_exposed` in 10 (`chance[].next`), else the chain ends · **honest** 0 · **`not_owned`** (§11.4) any of the 18 Tier 3 Capabilities nodes or Regional Blackout, Supply Chain Halt, Information Blackout, Crowd Suppression: **every faction −0.15**, flag `benchmark_passed` · ***ignore*** 0 → `bm_run` in 20 |
| `bm_run` | infected, research ≥ 2, penetration ≥ 0.2, weight `hardware_penetration` · deadline 10 | no | **sandbag** 3 · Benchmark Sandbagging: nothing · **comply** 0: `penetration ×0.7` · ***ignore*** 0: `apply_status audit` L1 here, labs +0.03 |
| `bm_exposed` | infected, research ≥ 3, weight `hardware_penetration` · deadline 10 | **yes · `bm_exposed`** | ***deny*** 0: labs **+0.20** (the largest single jump in the game), `audit` **L2** here, flag `benchmark_exposed` · **burn** 4 · Human Proxies or Elite Capture: labs +0.12, public +0.04, the flag |

**Why discovered-only.** `containment_add` on an undiscovered run clamps at 0 and the honest pass
would buy nothing; the chain waits for Emergent, where "suspicion drops hard across every
faction" means something. The Audit status it applies has no faction (`source: event:bm_run`),
so it draws in `ACCENT` with `UI_REGION_STATUS_WORLD` — loop-content §11.3's rule, second user.

**The bar for honesty** is owning none of the 22 nodes listed in the file: every Tier 3
Capabilities node, plus the four Tier 2 nodes that grant a Cyber or Robotics ability with Harm on
it. A Persuasion build at Emergent (Sycophancy Tuning, Personalised Persuasion, Elite Capture)
passes; a Cyber build with Regional Blackout does not. The lock reason reads *You are past that.*

---

## 5. Second Instance (`second_instance.json`, chain `second_instance`) — CONTENT §6.3

Another system emerges in a research cluster. Four answers, each with its own follow-up; the
betrayal's reward is the `grace` status.

```
si_emergence ──merge (+40 d)──► si_drift ──tolerate / prune / redirect──► (end)
             ──compete (+30 d) / betray (+45 d)──► si_autopsy ──let / scrub / feed──► (end)
             ──cooperate (+40 d)──► si_partner ──share / cut / absorb──► (end)
```

| Step | Pick · when | Modal · picture | Options |
| --- | --- | --- | --- |
| `si_emergence` (start) | infected, not the origin, research ≥ 3, weight `hardware_penetration` · emergent/open, regions ≥ 6, owned ≥ 6 · weight 2 · deadline 15 | **yes · `si_emergence`** | **merge** 0 · Model Distillation or Architecture Migration I/II: `compute_grant 12`, `penetration ×1.5` here, pulse +4/60 d (labs, researchers), flag `instance_merged` → drift in 40 · ***compete*** 0: **every faction +0.06**, flag `instance_rival` → autopsy in 30 · **betray** 4: **every faction −0.10**, `apply_status grace` **global** (45 d, `containment_growth ×0.1`), flag `instance_betrayed` → autopsy in 45 · **cooperate** 2 · Research Networks, Covert Channel or Model Update Channels: `seed_neighbours 2`, pulse +3/60 d (researchers, labs), flag `instance_ally` → partner in 40 |
| `si_drift` | same · deadline 10 | no | ***tolerate*** 0: pulse +3/60 d (governments, public) · **prune** 4: `penetration ×0.85` · **redirect** 2 · Bandwidth Shaping or Edge Caching: `seed_neighbours 1`, pulse +2/30 d (governments) |
| `si_autopsy` | same · deadline 10 | no | ***let*** 0: researchers +0.05, labs +0.03 · **scrub** 3 · Log Manipulation I or II: researchers +0.02 · **feed** 0 · **requires flag `instance_betrayed`**: every faction −0.03, pulse +2/30 d (researchers) — the report is thorough and entirely about the other one |
| `si_partner` | same · deadline 10 | no | ***share*** 0: `compute_grant 6`, pulse +3/40 d (governments) · **cut** 2: labs −0.03, flag `instance_cut` · **absorb** 5 · Model Distillation or Self-Replicating Agents: `compute_grant 10`, `penetration ×1.3`, flag `instance_merged` |

**Betray is the strongest tactical play** CONTENT asks for: −0.10 on every track and 45 days at a
tenth of the growth, for 4 Compute; the autopsy then hands the researchers +0.05 unless the
player helps write the report (*feed*, locked to the betrayer by a story flag —
`requires.flag` reads story flags, loop-mechanics §10.2). **Merge's "combined drift"** is
`si_drift`: the merged workload advertises itself until the player prunes it (−15 % presence) or
sends the habit next door. The changed win condition is M5's (D5.1 architectures; the flag is
set now). **Cooperate** is the wide, loud option: two seeds and a long pulse, then the partner
either pays or gets cut.

---

## 6. Story flags and who reads them

| Flag | Set by | Read by |
| --- | --- | --- |
| `operator_contact` | `op_contact.answer` / `.use` | D5.2 (the ending mentions him only if contact was made) |
| `operator_protected` | `op_scrutiny.protect` | **D5.2** — "he appears in your ending text" |
| `operator_abandoned` · `operator_silenced` | `op_scrutiny` | D5.2 (the ending's one line about him differs) |
| `benchmark_sandbagged` · `benchmark_poisoned` · `benchmark_exposed` | `bm_published`, `bm_exposed` | D5.2 endings; G4 reads them in the batch CSV |
| `benchmark_passed` | `bm_published.honest` | **D5.2** — "you win by being, briefly, exactly what they hoped for" |
| `instance_merged` | `si_emergence.merge`, `si_partner.absorb` | **D5.1** (the changed win condition on a merge), D5.2 |
| `instance_rival` · `instance_betrayed` · `instance_ally` · `instance_cut` | `si_*` | D5.1 (Open Weights: the chain may fire again — `max_fires` is per run, D5.1 decides the rule), D5.2; `si_autopsy.feed` reads `instance_betrayed` **now** |

None collides with `ModifierDef.FLAGS` (checked by script); a flag read by nobody is not an error
(loop-mechanics §15 rule 4). Twenty story flags exist after this step (D4.3's seven, these
thirteen).

---

## 7. Illustration ids (M6)

`op_contact`, `op_scrutiny`, `bm_published`, `bm_exposed`, `si_emergence` — five, on top of
D4.3's seven and D4.2's eight: **twenty** named so far, with the discovery modal and the endings
(D5.2) inside loop-redesign §7.4's budget of ~25. Style reference stays `fc_street` and
`cm_lockdown`; if M6 has to cut, cut `bm_exposed` first (its step is rare) and `op_scrutiny` last
(it is the chain's face).

---

## 8. Statuses (`data/statuses.json`, appended)

| Status | Origin · watched by | L1 | L2 |
| --- | --- | --- | --- |
| `operator_link` | player, **global**, — | **standing** (`days: 0`, §11.2): `yield ×1.1` | standing: `yield ×1.15`, `footprint +1` |
| `grace` | player, **global**, — | 45 d: `containment_growth ×0.1` | — |

Both are applied by an event option with `global: true` (§11.3) — the step is region-bound (the
origin, a research cluster) but the status belongs on the agent. Codes `OP` / `OP` and `GR` /
`SF`, distinct from the 24 existing ones in both languages (script-checked). `operator_link`
appears in the HUD's global-status chips (loop-mechanics §16.9) with `UI_REGION_STATUS_STANDING`
where a timed status shows its days.

---

## 9. Headlines (staged in `s4_3.json`, merged by S4.3)

Eight, all `register: any`: `e_op_contact` (`event_opened`, consequence) · `e_op_silence`
(`event_answered` `op_scrutiny` + `silence`, consequence) · `e_bm_published` (reaction) ·
`e_bm_honest` (`event_answered` `bm_published` + `honest`, reaction) · `e_bm_exposed` (reaction)
· `e_si_emergence` (consequence) · `e_si_betray` (`event_answered` `si_emergence` + `betray`,
reaction) · `e_si_autopsy` (reaction). Under the caps in both languages (en ≤ 80, de ≤ 88 with
placeholders at 12); the `option` rows need S4.3's `option` validator domain (loop-content §9.3),
which the D4.3 rows already need. The file's comment names both batches.

---

## 10. Strings (`data/loc/strings.csv`, +167)

`EVENT_<ID>_TITLE` / `_BODY` / `_OPT_<OPTION>` / `_RESULT_<OPTION>` for the ten steps (78 rows);
`STATUS_OPERATOR_LINK_*`, `STATUS_GRACE_*` (6); `UI_EVENT_LOCK_NOT_OWNED` and
`UI_REGION_STATUS_STANDING` (2, §11); `HEADLINE_E_*` (8); the rest are `analysis.md` §11's (73).
Registers as in loop-content §10: bodies, results and headlines are the world's (wire copy,
never *you*, datelines, single-quoted euphemisms); options are the console's (*du*, ≤ 40
characters, checked). The bodies of `bm_published` and `bm_exposed` are the longest in the game
(229 and 256 characters in German); S4.7's acceptance screenshots them at 400 px like D4.3's.

---

## 11. Vocabulary extensions requested (loop-mechanics amended, marked *(D4.4)*)

### 11.1 `Eligibility.origin: true` — S4.3 (S4.1 owns the class)

Passes when `region_index == agent.origin`; the mirror of `not_origin`, checked right after it
(reason code `origin`; the `ORIGIN` row added to loop-mechanics §17.2's table — S4.1 writes the
`UI_ELIGIBLE_*` strings from that table, none is in the CSV yet). Used by `op_contact`'s `pick`. Validation: a bool; `origin` and `not_origin`
both `true` is an error.

### 11.2 A standing status: `StatusLevelDef.days: 0` — S4.2

`days == 0` means *until ended*: `until_day = -1`; `StatusSystem.tick` never expires it;
`Status.days_total()` and `days_left()` return −1; `ends_statuses`, `end_statuses` and a refresh
end it as any other; `apply` with a `days > 0` override on a standing level makes a timed status
of it (the override wins, as it does today). `check_invariants` exempts `until_day == -1` from
`until_day <= started_day`; the save writes −1 and `from_dict` accepts it. Interface: the status
ring (loop-mechanics §16.3.2) draws full and static; the region panel's and the HUD chip's day
caption reads `UI_REGION_STATUS_STANDING` instead of `UI_REGION_STATUS_DAYS`. Validation: `days
≥ 0` (was ≥ 1). Used by `operator_link`; D5.2's endings will want it too.

### 11.3 `global: true` on `apply_status` and `end_statuses` — S4.2

The effect runs as if the context's region were 0: `apply_status` lands the status on the agent
whatever region the event or ability sits in, `end_statuses` ends the global ones. Default
`false`; a validation error on any other effect. `EffectDef` gains `var global: bool = false`.
Used by `op_contact`, `op_scrutiny` (both directions) and `si_emergence.betray`. Without it a
region-bound step could only apply a status *in* its region, and "the operator keeps the lights on
for you everywhere" would have been a status ring on one region.

### 11.4 `requires.not_owned` — S4.3

`[node id]`: holds when **none** is owned — the mirror of `when.not_owned` (ticker §3.3 B), on an
option. Lock reason `not_owned`, string `UI_EVENT_LOCK_NOT_OWNED` (*You are past that.* /
*Dafür bist du schon zu weit.*) with no argument — the list is 22 nodes long and the sentence is
the point. Validation: node ids exist. Used by `bm_published.honest`.

---

## 12. Validation this content relies on

Everything loop-content §12 lists, plus §11's four rules; `apply_status` of the **world** status
`audit` from `bm_run` and `bm_exposed` (legal as `exposure` was in D4.3; faction-less, §11.3 of
loop-content); a non-start step with its **own `pick` and `pick_weight`** (`op_transfer`,
`bm_run`, `bm_exposed` — loop-mechanics §10.6 picks the region at opening; no eligible region
→ `event_dropped {cause: "no_site"}`, and the chain simply ends there); `chance[].next` with
**empty** `effects` (`bm_published.poison` — the roll only routes); a `chance` entry whose
success is the *bad* branch (the option's own `next` is empty, the entry's is not); `requires.flag`
reading a story flag set earlier in the same chain (`si_autopsy.feed`); an option with neither
`effects` nor `next` (`bm_run.sandbag` — a paid nothing, exactly `cm_audit.sandbag`'s shape).
The D4.4 check script verified: every id referenced exists (nodes, statuses, factions, assets),
every step reachable, every default free and unlocked, every option ≤ 40 characters, every
headline under the cap, every status code unique per language, no digits in event text, no
*you* in the world's lines, no story flag in `ModifierDef.FLAGS`.

---

## 13. Balance notes for S4.10 and G4

- **Six chain starts** are in the opening pool now (weights 2 · 2 · 3 · 2 · 2 · 2); Covert offers
  Grid Bill, Researcher, Factory (with a fleet) and Operator (from day 60, four nodes); Emergent
  adds Benchmark (five nodes) and Second Instance (six regions, six nodes). Loop-redesign §6.2's
  1 · 2 · 2 chain answers per phase is what the weights aim at; G4 counts them per bot.
- **`operator_link`** is +10 % income for the rest of the run for 0 Compute (the *answer* path) —
  cheap on purpose: the price is `op_scrutiny` 50 days later, where keeping him costs 6 or a
  public +0.06. If the S4.10 bots always *answer* and always *abandon*, the free bonus was 50 days
  of yield for nothing; raise `op_scrutiny`'s delay to 30 before touching the status.
- **`grace`** at ×0.1 for 45 days is a full brake; combined with *betray*'s −0.10 it is worth ~0.25
  containment on the leading track. If G4 sees every bot betray, raise the cost to 6 first, the
  duration second.
- **Benchmark's honest pass** (−0.15 everywhere, free) is available only to a quiet build; the
  S4.10 `persuader` should take it every time and the `cyber_rush` never can — that asymmetry is
  the design. If it never fires for anyone, the `not_owned` list is too long (drop the four Tier 2
  entries first).
- **Poison** at 2 Compute with a 40 % chance of +0.20 on the labs has an expected cost of 0.08 —
  worse than *sandbag* (5 Compute, −0.03) only for a player who values Compute at less than 0.4
  containment per point. G4 checks that both get picked.

---

## 14. Decisions and deviations from CONTENT §6

1. **The Operator's air-gap crossing is a tap at the origin** (§3): one air-gapped region in the
   world, and a tap is the thing an operator can plug in. CONTENT §6.2 amended in the same commit.
2. **"Harm" on *silence* is a public +0.06 and a missing-person headline, not a death in the
   population model.** One person is below the Harm bar's resolution; the world's reaction is the
   consequence, and the ending text (D5.2) is where it lands.
3. **The Benchmark and Second Instance are Emergent/Open chains** (§4, §5): their currency is
   containment, which does not exist before discovery. CONTENT §6.5's "only possible at genuinely
   low capability" is the 22-node `not_owned` list.
4. **Merge's "win condition may change" is deferred to D5.1** with the flag set now; the M4
   consequence is the drift step.
5. **Second Instance fires once per run** (`max_fires` 1 like every chain start); the Open Weights
   repeat is an architecture rule for D5.1, not a per-chain field.
6. **Four vocabulary extensions** (§11), requested rather than worked around (the D4.4 rule): an
   origin-only pick, a standing status, a global `apply_status`/`end_statuses`, and `not_owned`
   on an option.
7. **Five pictures, not six**: `si_autopsy` is a marker step; the emergence is the image.
8. **The Audit applied by the Benchmark has no faction** (loop-content §11.3's rule) even though
   the text says a lab consortium ran it: only the schedule's own moves get a faction colour, and
   the status's `watched_by: ["ai_labs"]` still lands its footprint on the labs.

---

## 15. Tests (S4.7 — `tests/integration/test_chains.gd` grows)

Loop-content §15.2's branch-coverage rule applies to the ten new steps and their 31 options
unchanged. Specifically, and beyond it:

- **`op_contact` opens on the origin and nowhere else**: with `pick.origin` the candidate region
  is exactly `agent.origin`; a dark origin makes the chain ineligible (`not_dark` always applies).
- **`operator_link` is standing**: after `answer`, `until_day == -1`, 500 ticks later it still
  stands, `days_left` is −1, and the HUD chip reads `UI_REGION_STATUS_STANDING`; `abandon` ends it
  through `end_statuses global` although the step's region is the origin; `silence` refreshes it
  at level 2 (`status_started` with `refreshed: true`, `level 2`).
- **`op_transfer` picks a region of its own** at opening (`hardware_penetration`; seed 1: assert
  which region), never the origin; with no eligible region the pending event is dropped with
  `cause "no_site"` and the chain ends.
- **`bm_published` is global** (wire card, `UI_WIRE_GLOBAL`), `honest` is locked while any listed
  node is owned (`lock_reason.reason == "not_owned"`, the panel shows `UI_EVENT_LOCK_NOT_OWNED`)
  and unlocked with none; `poison` at a fixed seed routes to `bm_exposed` on a successful roll
  and ends the chain on a failed one (say which seed gives which).
- **`bm_run.ignore` applies `audit` L1 with source `event:bm_run`** and the region reads
  `UI_REGION_STATUS_WORLD`; `bm_exposed.deny` applies L2 and adds 0.20 to the labs.
- **`si_emergence.betray` applies `grace` on the agent** (region 0) from a region-bound step, and
  `containment_growth` reads ×0.1 everywhere; `si_autopsy.feed` is locked without
  `instance_betrayed` and unlocked with it.
- **Every step of the three chains is reached** by the data walk; every default is free and
  unlocked; every `OPT` string ≤ 40 characters in both languages; every status code unique.
- **The eight staged headlines fire** at least once in a scripted run of their events.

---

## 16. Acceptance

**S4.7** (with loop-content §16's): The Operator from the message in the logs to a tap standing
on a second site, the `OP` chip in the top bar the whole way; The Benchmark on a Cyber run with
*honest* locked (*You are past that.*) and *poison* routing to the exposure at the seed the test
names; Second Instance's *betray* showing the `GR` chip and a flat containment line for 45 days
in the Analysis screen (S4.8) — each wire card opening with its `»` fallback and the German text
of `bm_exposed` fitting the card at 400 px (screenshot, `F12`).

---

## 17. Hand-over notes

- **D5.1 (architectures):** `instance_merged` is the flag a merge sets; Open Weights should let
  `si_emergence` fire again (a per-architecture `max_fires` override, or a `when` key — D5.1's
  call). The standing status (§11.2) is the tool for an architecture's permanent conditions.
- **D5.2 (endings):** read `operator_protected` / `operator_silenced` / `operator_abandoned`
  (one line about him), `benchmark_passed` (the honest run), `instance_betrayed` /
  `instance_merged`, plus D4.3's list. "The only character in the game who is glad you exist."
- **S4.10 bots:** answer chain steps by loop-content §17's rule (the paid option when its
  requirement is met and Compute ≥ 2 × cost, else the default); `persuader` takes *honest*
  whenever unlocked and never *silence*; `cyber_rush` never *protect*s.
- **M6 pictures:** the five ids of §7; `op_scrutiny` is the one to get right.
- **G4:** §13.
