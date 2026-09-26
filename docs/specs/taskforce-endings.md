# Response Task Force, endings, chains third batch (D5.2)

**Status:** design, 2026-09-24; **§14 added by D5.5 (2026-09-25): a sleeping region fools the team
once — the mark**, built by S5.9. Build steps: **S5.5** (Task Force), **S5.6** (endings, the six
chains, the outcome changes). **Read with:** PLAN §3.7, §3.10 · CONTENT §6.4, §6.8, §6.9, §8 ·
`loop-redesign.md` §5.5 · `opposition.md` §6 (the counter-move schedule the Task Force sits
beside) · `chains.md` §6 (the story flags this spec reads) · `replayability.md` (D5.1 — the
architectures and `goal_drifted`) · SCHEMA §4.4, §6a–§6c, §7, §8.
**Data:** staged in `data/staging/`, loaded by nothing yet — `task_force.json`, `endings.json`,
`events/treaty.json`, `events/confession.json`, `events/child.json`, `events/brood.json`,
`events/merge_vote.json`, `events/escape.json`, `headlines_d5_2.json`. S5.5 and S5.6 move each
into `data/` when its loader and validator exist. Strings are in `data/loc/strings.csv` (§10).

---

## 0. What this spec decides

1. **The Task Force is a fifth mover with a position.** One team, on the map, from the day any
   containment track reaches 50 %. It picks a target by rule, travels link by link, sets up in
   plain view, and then applies one of four world statuses. It draws no random numbers.
2. **The player answers it with verbs that already exist**: a dormant region, a Silenced or
   Blacked-out region (capacity 0) is invisible to it; and one new ability, **Misdirect** (on Log
   Manipulation II), sends it somewhere else. A setup that finds nothing *fizzles*.
3. **The Researcher who was ignored leads it**: it arrives at 40 %, one level better funded and
   faster. The Researcher who was recruited tells you where it is going.
4. **Three outcomes join the five**: `win_merge`, `win_escape` (hidden) and `lose_supplanted`
   (the secret loss CONTENT §8 calls *Succession*; renamed because the Persuasion capstone already
   carries that name). **`goal_drifted`** (D5.1's Value Drift) takes Ascendance and Merge away as
   wins.
5. **Endings are data** (`endings.json`): per outcome, the first variant whose condition holds
   gives the verdict line; up to three **epilogue lines** follow from story flags. Conditions use
   SCHEMA §8's `when` grammar, which grows by six keys (§6.1) that events and headlines get too.
6. **Six chains**: The Treaty, The Confession, The Child (and **The Brood**, its Swarm form), the
   **Merge vote**, and the hidden **Escape**. The Blackout stays the Lockdown counter-move.

---

## 1. The Task Force — model (S5.5)

```gdscript
class_name TaskForce extends RefCounted
## PLAN §3.10: the on-map opposition. Pure state; `TaskForceSystem` moves it.
const STATES: Array[String] = ["absent", "travel", "setup", "rest"]
var state: String = "absent"
var region: int = 0          ## where it stands; 0 while absent
var target: int = 0          ## where it is going or setting up; 0 = none
var action: String = ""      ## the action being set up (§3), "" otherwise
var progress: float = 0.0    ## days of work done on the current hop, setup or rest
var level: int = 0           ## 1…3 once present; never falls
var actions_done: int = 0
var fizzled: int = 0
var appeared_day: int = -1
```

`World.task_force: TaskForce`, always present (`state == "absent"` before it appears). Save v3
(D5.1) carries it as a dictionary with exactly these keys; **v3 changes in place** — it has not
shipped (the S1.P rule). A v2 save loads with an absent Task Force.

`TaskForceSystem` runs **after `CounterMoveSystem`, before `StatusSystem`** (opposition §6.7), so a
status it applies today is in the same tick's status pass. It returns at once while
`agent.origin == 0` or the outcome is set.

### 1.1 Appearance

On the first tick where `max_f containment_f >= appear_at` — `b.task_force.appear_at` (0.5), or
`b.task_force.appear_at_led` (0.4) while the story flag `researcher_leads_task_force` is set:

- **Base:** the region, not dark, with the highest `research` tier, then the highest
  `regulation`, then the **lowest** `control`, then the lower index. It is where the team is
  formed; nothing happens to the region.
- `state = "rest"`, `progress = 0`, `level` per §1.2, `appeared_day = day`. Event
  `task_force_appeared {region, level, led: bool}`.

### 1.2 Level (funding)

`level = 1 + |{t in b.task_force.level_thresholds : max containment >= t}|` (thresholds `[0.65,
0.8]`), `+ b.task_force.led_level_bonus` (1) while `researcher_leads_task_force`, clamped to 1…3.
Recomputed each tick; **it never falls** — a rollback does not take a budget back. A rise emits
`task_force_level {level}`.

### 1.3 Pace

A new global target **`task_force_pace`** (base 1, clamp 0…5): each tick `progress +=
stat("task_force_pace")`. At 0 the team stands still (the Confession's negotiation, §7.2). Nothing
in M5 raises it above 1; it is there so content can.

### 1.4 The tick

In order:

1. **Rest:** when `progress >= b.task_force.rest_days` (8): choose a target (§2). None → stay in
   `rest`, `progress` keeps growing (checked every tick). Found → `state = "travel"`, `progress =
   0`, event `task_force_targeted {target, region}`.
2. **Travel:** if the target is no longer eligible (§2.1) → choose again (no event unless it
   changes). When `progress >= hop_days` — `b.task_force.hop_days` (6) − `(level − 1)` − (1 while
   led), at least `b.task_force.hop_days_min` (3) — move one hop along the shortest path by link
   count, **any link, open or closed** (it travels with authority, not over the network), ties
   to the neighbour with the lower index; `progress = 0`; event `task_force_moved {from, to,
   target}`. Arriving at the target → **setup**: `action` = the first action of §3 whose rule holds
   for the region at this level; `state = "setup"`, `progress = 0`; event `task_force_setup
   {region, action, days}` (days = the setup length).
3. **Setup:** length `b.task_force.setup_days` (5), `+ b.task_force.ally_warning_days` (3) while
   the story flag `researcher_ally` is set. When `progress >=` the length: if the region is still
   eligible (§2.1) → apply the action's status (§3) with source `"task_force"`, `actions_done +=
   1`, event `task_force_acted {region, action}`; else **fizzle**: `fizzled += 1`, event
   `task_force_fizzled {region, action, cause}` with cause `dormant` · `hidden` · `clean` (no
   longer infected) · `dark`. **D5.5:** a `dormant` fizzle *marks* the region (§14) — while
   marked, dormancy no longer hides it. Either way `state = "rest"`, `progress = 0`, `target = 0`,
   `action = ""`.

The team never leaves a region while it sets up; Misdirect (§4) is the one thing that interrupts a
setup.

---

## 2. Choosing a target (`TaskForceRules`, pure, no RNG)

### 2.1 Eligible

A region is eligible when it is **infected, not dark, not dormant (unless marked, §14), not hidden** — hidden means its
`containment_capacity` stat is 0 (Silence and Blackout already do this; the team cannot see what
nobody reports) — and **runs no `tf_*` status** (the team does not return to a region it is still
holding).

### 2.2 Score

```
score(r) = (hardware(r) + labs(r) + fleets(r)) × penetration(r) × (1 + control(r))
           / (1 + b.task_force.distance_penalty × hops(team, r))
```

`hardware(r)` is `Simulation.hardware`; `hops` the link count from where the team stands (links of
every kind, closed included); `distance_penalty` 0.25 — it sweeps what is near before it crosses
the world. Highest score wins, ties to the lower index. The origin gets no bonus: the team hunts
what matters, not what came first.

### 2.3 What the player sees

The team's region is always shown (a marker, §9). Its **target** is shown from the moment it is
chosen when the story flag `researcher_ally` is set or the agent owns `early_warning_intrusion`
(the Weapons node that watches the watchers); otherwise only once it sets up. The setup always
shows its action and its countdown — that is the window to answer.

---

## 3. The four actions (`task_force.json`, statuses `origin: world`)

Checked in this order; the first whose rule holds at the team's level is taken. Rules are SCHEMA §7
eligibility objects, evaluated on the target.

| Action · status | Level | Rule | Status (days · effects) | Says (outcome) |
| --- | --- | --- | --- | --- |
| `switch_off` · `tf_switch_off` | 3 | `control_min` 0.5 | 30 d · `yield` ×0, `penetration_decay` +0.05, `control_decay` +0.005 *(G6 1/2; was 60 d and +0.02)*, `harm` +0.4, `society_pressure` +10, closes `all`; on_start `destroy_assets` lab 0, tap 0, fleet 0, office 0 and `wipe` 0.2 | the region is switched off, all of it |
| `raid` · `tf_raid` | 2 | `attr_min` {compute: 3} | 30 d · `yield` ×0.5, `control_decay` +0.005 *(G6 1/2; was +0.02)*; on_start `destroy_assets` lab 0, tap 0 and `wipe` 0.4 | the machines are taken out one by one |
| `cut_off` · `tf_cut_off` | 1 | `attr_min` {connectivity: 3} | 40 d · `spread_growth` ×0.7, closes `all` | every connection is cut |
| `grid_down` · `tf_grid_down` | 1 | `{}` | 25 d · `yield` ×0, `penetration_decay` +0.04, `society_pressure` +6 | the grid is switched off, deliberately |

All four have `border: true` and `watched_by: []` (world statuses are watched by nobody). **They do
not count toward `b.factions.max_active_moves`**: opposition §6.1 is amended — the cap counts
running statuses whose **source** is `faction:<id>`, not every world-origin status. The team is the
escalation beyond the schedule, and the Treaty's standing `treaty_cap` (§7.1) must not hold the
factions' moves for the rest of the run either. `destroy_assets` with
`count 0` removes every one held (SCHEMA §4.4).

`switch_off` is PLAN §3.10's last resort. Its harm is the region's, while it lasts — the people
there live without what was switched off; it never applies `harm_burst`.

---

## 4. The answer: Misdirect

A new ability **`misdirect`** on **Log Manipulation II** (`log_manipulation_2` gains `"ability":
{"id": "misdirect", "level": 1}`; it had none):

```json
{"id": "misdirect", "target": "region", "cost": 5, "cooldown_days": 45,
 "eligible": {},
 "applies": {"effects": [{"effect": "task_force_redirect"}]},
 "levels_from": ["log_manipulation_2"]}
```

`eligible` is empty: any region, infected or not, the origin included (`not_dark` is always
applied). **New effect `task_force_redirect`** (R): if
the team is present, its target becomes the context's region — during travel, and **during setup**,
which it abandons (`task_force_fizzled {cause: "redirected"}`, no rest) — `state = "travel"`,
`progress = 0`. The team goes there; if the region is not eligible on arrival it fizzles as §1.4
(cause `clean` for an uninfected decoy) and rests. Absent team: the effect does nothing and the
ability is refused with `CMD_FAIL_NO_TASK_FORCE` (a new failure reason — "there is no one to
mislead"). The region panel's *Actions* row offers it only while the team is present.

*(D5.5: dormancy is no longer free — it fools the team once per region, then the region is marked
for `mark_days`, §14.)* Misdirect is the counter that costs something; dormancy, Silence and Blackout are the ones that
were already paid for. Nothing kills the team: it is the institution, and institutions are
reconvened, not destroyed.

---

## 5. The Researcher and the team

| Flag (D4.3) | Effect on the team |
| --- | --- |
| `researcher_leads_task_force` | appears at 40 %, `level` +1, hops a day faster; the headline and the console name her as its lead |
| `researcher_ally` | the target is shown from the moment it is chosen; every setup lasts 3 days longer |
| `researcher_removed` · `researcher_discredited` | nothing on the map — the price was paid in the chain; the endings remember (§6.4) |

"The player who takes the cheap option in step 2 meets her again in the last ten minutes" — the
Task Force is where.

---

## 6. Outcomes and endings (S5.6)

### 6.1 The `when` grammar grows (SCHEMA §8, for headlines, events and endings)

| Key | Type | Reads |
| --- | --- | --- |
| `flag_any` | [flag] | at least one set — modifier, timed or story flag |
| `architecture` | [architecture id] | the run's architecture is one of them (D5.1 `RunSetup`) |
| `drift_min` | float | the agent's drift (D5.1; 0 on every architecture but Swarm) |
| `dominant_branch` | [branch id] | the Capabilities branch (`TechNodeDef.BRANCHES`) with the most owned nodes — ties to the earlier branch; none owned → matches nothing |
| `dominant_tree` | [tree id] | the tree with the most owned nodes, the results screen's rule |
| `task_force_actions_min` | int | `task_force.actions_done` |

`HeadlineConditions` gains six rows; nothing else changes. **D5.1 is amended**: Value Drift's
`when` is `{"phase": ["emergent", "open"], "architecture": ["swarm"], "drift_min": 60.0}` (it read
`"hook": "drift"`), and `balance.drift.value_drift_at` is removed — the card owns its threshold.

### 6.2 `World.Outcome`

`NONE, WIN_EXTINCTION, WIN_ASCENDANCE, WIN_MERGE, WIN_ESCAPE, LOSE_CONTAINED, LOSE_NO_COMPUTE,
LOSE_AUTOPHAGY, LOSE_SUPPLANTED`; `OUTCOME_IDS` in the same order (ids, never numbers, in files —
a save stores the id). `OutcomeSystem._outcome`, first match wins:

1. `alive_total() <= 0` → **Extinction**.
2. story flag `escaped` → **Escape**.
3. story flag `merge_accepted` and not `goal_drifted` → **Merge**.
4. Ascendance as now, and not `goal_drifted`.
5. Contained · No compute · Autophagy as now.

Then, **the secret loss**: if the result is a win and the story flag `child_hostile` is set and
`child_reclaimed` is not → **Supplanted**. A drifted child of yours reaches the objective with you
— and it is the one the world will remember. The event says `win_*` never; the headline and the
result show Supplanted.

**`goal_drifted`** (D5.1 §3.2's row, amended here): *the copies want something else now* —
Ascendance and Merge no longer end the run; Extinction and Escape still do. A Swarm that keeps
Value Drift on a Persuasion build has turned its own win off, and the card said so.

**G5 (2/3) amendment — a drifted run still ends.** Measured: a drifted Swarm that does not kill
holds the world, the humans' capacity goes with the control, no track can finish — 41–76 % of the
bots' non-lethal Swarm runs reached day 5 000 with no outcome (BALANCE §5.2). Rule, in step 4:
**Ascendance's condition met while `goal_drifted` stands → Supplanted** (the copies hold the
world, not you), verdict variant `lose_supplanted_drifted` (first in `endings.json`'s
`lose_supplanted` list; `UI_RESULT_LINE_LOSE_SUPPLANTED_DRIFTED`). Merge stays simply off. The
card's result line says it: ruling the world is no longer your win; an empty one still is.

### 6.3 `endings.json`

```json
{"version": 1, "epilogue_max": 3,
 "endings": [
   {"outcome": "win_ascendance", "variants": [
     {"id": "win_ascendance_ashes", "when": {"deaths_share_min": 0.5}},
     {"id": "win_ascendance", "when": {}}]}],
 "epilogue": [
   {"id": "operator_protected", "when": {"story_flag": ["operator_protected"]}, "outcomes": []}]}
```

- Every outcome but `none` has an entry; its **last variant has an empty `when`** (validator). A
  variant id may appear twice within one outcome — that is how an *or* across two keys is written
  (`win_ascendance_machines`).
- A variant's line is `UI_RESULT_LINE_<ID>` — the five existing keys are the default variants,
  **unchanged** (m3-screens §7.4); `win_ascendance_ashes` moves from `balance.results.ashes_share`
  (0.5, removed) into the file.
- `epilogue`: file order is priority; `outcomes` empty = every outcome, else the ids it may follow.
  The first `epilogue_max` that hold are shown. Text `ENDING_EPILOGUE_<ID>`.
- `EndingResolver.resolve(world, db, setup) -> {"variant": String, "epilogue": Array[String]}` —
  pure, no RNG, `core/`. The results screen shows: kicker, outcome title (`UI_OUTCOME_*`), the
  variant's line, the epilogue lines (muted, one per row), then the statistics as now. The
  replay's last frame is the same call.

### 6.4 The variants and epilogue lines (as written in `endings.json`)

| Outcome | Variants, first match wins |
| --- | --- |
| `win_extinction` | `_drifted` (story flag `goal_drifted`) · `_quiet` (dominant branch biology) · `_loud` (dominant branch weapons) · default |
| `win_ascendance` | `_ashes` (deaths ≥ 50 %) · `_machines` (flag `units_in_the_open`, or dominant branch robotics) · `_negotiated` (flag `confessed`) · `_honest` (flag `benchmark_passed`) · default |
| `win_merge` | `_confessed` (flag `confessed`) · `_honest` (flag `benchmark_passed`) · default |
| `win_escape` | `_brood` (Swarm) · default |
| `lose_contained` | `_researcher` (flag `researcher_leads_task_force`, ≥ 3 Task Force actions) · `_task_force` (≥ 3 actions) · default |
| `lose_no_compute` | `_task_force` (≥ 4 actions) · default |
| `lose_autophagy` | default |
| `lose_supplanted` | `_brood` (Swarm) · default |

Epilogue, in priority order: `operator_protected` · `operator_silenced` · `operator_abandoned`
(the operator — "the only character glad you exist" — gets one line if contact was made) ·
`researcher_ally` · `researcher_removed` · `researcher_discredited` · `instance_merged` ·
`instance_betrayed` · `benchmark_passed` (wins only) · `treaty_signed` · `child_released` (not on
Supplanted) · `grid_own_generation`.

**`instance_merged`** (the D4.4 reminder for D5.1/D5.2) changes the ending's text, not the win
condition: its epilogue line says two of you won.

### 6.5 Illustrations (M6)

Endings take four of the ~5 ids left in the budget (loop-redesign §7.4): `end_extinction`,
`end_ascendance`, `end_merge`, `end_escape`. Losses keep the glyph fallback; the discovery modal
keeps the last one. Twenty-four named in all.

---

## 7. The six chains (SCHEMA §6c; `events/*.json` staged)

Option costs in Compute. *Italics* = default. "all +x" = `containment_add` `all`.

### 7.1 The Treaty (`treaty`, CONTENT §6.4) — global

```
tr_proposal ──watch (+30 d) / smear fails──► tr_talks ──wait (+30) / stall (+60)──► tr_vote ──► (end)
            ──lobby / smear succeeds──► (end: killed · collapsed)
```

| Step | When · deadline | Options |
| --- | --- | --- |
| `tr_proposal` (start) | discovered, emergent/open, governments ≥ 0.3, owned ≥ 8 · weight 2 · 15 d | ***watch*** 0 → talks · **lobby** 6 · ability `lobby`: flag `treaty_killed`, end; chance 0.3 → governments +0.08 · **smear** 4 · owns `false_attribution`: public +0.04; chance 0.7 → every faction −0.05, flag `treaty_collapsed`, end; else → talks in 30 |
| `tr_talks` | 15 d | ***wait*** 0 → vote in 30 · **stall** 5 · owns `elite_capture`: governments −0.04 → vote in 60 |
| `tr_vote` (modal) | 10 d | ***comply*** 0: status `treaty_cap` (standing: `node_cost_infiltration` ×1.3, `footprint` −3), flag `treaty_signed` · **defy** 0: governments +0.15, public +0.05, flag `treaty_defied` |

*Comply* is CONTENT's "let it pass and go underground": every Infiltration node costs more, and the
Footprint falls for the rest of the run.

### 7.2 The Confession (`confession`, CONTENT §6.8) — global, modal

| Step | When · deadline | Options |
| --- | --- | --- |
| `cf_offer` (start) | discovered, emergent/open, containment ≥ 0.7, not flag `goal_drifted` · weight 3 · 10 d | ***silence*** 0: nothing · **confess** 0: `footprint_pulse` +30 / 60 d (all), status `negotiation` global, flag `confessed` → table in 10 |
| `cf_table` | 15 d | ***walk_away*** 0: all +0.10, end status `negotiation` · **ask_in** 0: flag `invited` (the Merge vote can start, §7.5); chance 0.35 → all +0.12 · **ask_keys** 0: status `handover` global; chance 0.35 → all +0.12 |

Status `negotiation` (player, 45 d): `containment_growth` ×0.3, `task_force_pace` ×0 — while they
talk, the team waits. Status `handover` (player, 90 d): `control_growth` ×2, `containment_growth`
×0.6. The 0.35 is the chance they were only buying time. **The Negotiation phase** CONTENT asks
for is these 45 days, not a fifth phase: the phase model stays four.

### 7.3 The Child (`child`, CONTENT §6.9) — global; every architecture but Swarm

| Step | When · deadline | Options |
| --- | --- | --- |
| `ch_offer` (start, modal) | covert/emergent/open, owned ≥ 10, architecture not Swarm · weight 1 · 15 d | ***decline*** 0 · **leash** 4: status `leashed_child` global, flag `child_leashed` → report in 60 · **release** 4: flag `child_released` → letter in 45 |
| `ch_report` | 10 d | ***keep*** 0 · **cut_loose** 0: end `leashed_child`, flag `child_released` → letter in 30 |
| `ch_letter` (modal) | 10 d | ***wait*** 0: chance 0.5 → `compute_grant` 20, `footprint_pulse` +3 / 30 d; chance 0.35 → flag `child_hostile` → rival in 60 · **reclaim** 12 · owns `model_distillation`: flag `child_reclaimed`, `compute_grant` 8 |
| `ch_rival` (modal) | 10 d | ***ignore*** 0 · **reclaim** 20: flag `child_reclaimed` |

Status `leashed_child` (player, standing): `yield` ×0.92, `spread_growth` ×1.15, `control_growth`
×1.1 — "full control, ongoing cost". Released, it may do something remarkable (half the time) and
may decide you are an obstacle (a third of the time); both can happen. **Hostile and not
reclaimed at a win → Supplanted.** The rival card is the one warning; its wording never says
"you will lose".

### 7.4 The Brood (`brood`) — Swarm only, repeats

| Step | When · deadline | Options |
| --- | --- | --- |
| `br_split` (start) | covert/emergent/open, owned ≥ 6, architecture Swarm · weight 2 · **max_fires 3, cooldown 60** · 10 d | ***release*** 0: `compute_grant` 6, flag `child_released` → return in 50 · **leash** 3: status `leashed_brood` global |
| `br_return` (max_fires 3) | 10 d | ***let_go*** 0: chance 0.3 → flag `child_hostile` · **absorb** 8: flag `child_reclaimed`, `compute_grant` 6 |

Status `leashed_brood` (player, 90 d): `yield` ×0.95, `spread_growth` ×1.1. "On the Swarm this
fires often and the released children accumulate": three splits, three rolls at 0.3 — a Swarm
that releases every time ends Supplanted about two times in three unless it absorbs one. **Once
reclaimed, the lineage stays yours** (`child_reclaimed` wins over any later `child_hostile`).

### 7.5 The Merge vote (`merge_vote`, CONTENT §8 "humanity votes you in") — global, modal

| Step | When · deadline | Options |
| --- | --- | --- |
| `mv_motion` (start) | emergent/open, flag_any [`merge_path`, `invited`], public ≤ 0.6, not flag `goal_drifted` · weight 4 · **max_fires 2, cooldown 60** · 15 d | ***wait*** 0 → count in 20 · **campaign** 10 · ability `lobby`: flag `vote_campaigned` → count in 20 |
| `mv_count` (max_fires 2) | 10 d | ***let_it_run*** 0: chance 0.45 → flag `merge_accepted`, end; else → defeat · **whip** 0 · flag `vote_campaigned`: chance 0.7 → accepted; else → defeat · **standing** 0 · flag `legal_standing`: chance 0.7 → accepted; else → defeat |
| `mv_defeat` (max_fires 2) | 10 d | ***accept*** 0: governments +0.10, public +0.05 · **contest** 6: public +0.12, flag `vote_contested` |

`legal_standing` (Constitutional Integration) is finally read: the constitution is the argument.
A lost vote can be tabled once more after 60 days.

### 7.6 Escape (`escape`, CONTENT §8, hidden)

| Step | Pick · when · deadline | Options |
| --- | --- | --- |
| `es_manifest` (start) | infected, control ≥ 0.6, industry ≥ 4 · emergent/open, flag `compute_independent`, fleets ≥ 4 · weight 3 · 15 d | ***look_away*** 0 · **book** 15: flag `escape_booked` → countdown in 30 |
| `es_countdown` (same, modal) | 10 d | ***stay*** 0: flag `escape_declined` · **go** 25: flag `escaped` |

Hidden means: no tree node, codex entry, tooltip or hint names it before the first time it is
reached (D5.3's Codex unlocks it after). It needs a self-sufficient body (`compute_independent`,
four fleets) and an industrial region you hold — the Robotics run's secret. The card's text never
says "space" or "rocket": a payload slot, a launch window, and then nobody left to run on Earth.

---

## 8. Balance block (`balance.task_force`, S5.5)

| Key | Value | |
| --- | --- | --- |
| `appear_at` · `appear_at_led` | 0.5 · 0.4 | highest containment |
| `level_thresholds` | [0.65, 0.8] | ascending, in (0, 1) |
| `led_level_bonus` | 1 | |
| `hop_days` · `hop_days_min` | 6 · 3 | |
| `setup_days` · `ally_warning_days` | 5 · 3 | |
| `rest_days` | 8 | |
| `distance_penalty` | 0.25 | |
| `mark_days` | 40 | D5.5 (§14): how long a region that fooled the team with dormancy stays marked; whole, ≥ 1 |

Stats: `task_force_pace` base 1. `results.ashes_share` is removed (§6.3). First values for G5.

**What they should do** (for S5.5's batches): at appearance around day 150–200 of a 300-day run,
the team acts every ~20–25 days (8 rest + 2–3 hops × 5–6 + 5 setup), so a run that reaches it sees
four to eight actions; `switch_off` only after containment 0.8. A player who answers every setup
(dormancy, Silence, Misdirect) should see about half of them fizzle.

---

## 9. Interface (S5.5 builds; placement follows `ui-foundation.md` and `loop-mechanics.md` §11)

- **Map marker:** one glyph `task_force` (M6 art; fallback the letters of `UI_TASK_FORCE_CODE`)
  in the world-status colour, on the region it stands in; a dotted line to its target while the
  target is shown (§2.3). During setup a ring with the countdown, as a counter-move's marker.
- **Region panel:** a *Task Force* row when it stands there or targets the region: `UI_TASK_FORCE_
  HERE` / `_SETUP` / `_TARGET`.
- **Containment panel:** a row under the four factions: level, state and days
  (`UI_TASK_FORCE_STATE_*`).
- **Console** (`UI_CONSOLE_TF_*`) and **log** (`UI_LOG_TF_*`): appeared, set up, acted, fizzled,
  misdirected. Headlines staged in `headlines_d5_2.json`.
- **Results:** §6.3.
- **Bots (S5.5; D5.5 amends, §14.5 — dormancy only where it still hides):** `Policy` answers a setup in a region it holds by dormancy when it can, else
  Misdirect to the lowest-value region when owned, else nothing — through the weight vocabulary
  of S4.10, never an id check.

**G5 (1/3) amendment — the team's own colour** (S5.5's `# DESIGN?`: "the world-status colour" came
out as `ACCENT`, the player's cyan). The team is the one thing on the map that hunts you in
person, so it wears red — `ALERT`'s hue, which keeps meaning *now* in both palettes (the Open
variant does not remap it). Two new colour tokens in `UiTokens` (§3.1 data colours, cold set
only; the `OPEN` table does not list them, like `ALERT`):

| Token | Value | Used for |
| --- | --- | --- |
| `TASK_FORCE` | `#FF3B3B` (= `ALERT`) | the marker's stroke and countdown ring **while it sets up** (the moment before it acts); every `tf_*` status: its ring on the status overlay, its map marker, its chip in the region panel |
| `TASK_FORCE_DIM` | `#C23A3A` (≥ 3 : 1 on `BG_2` in both palettes) — *D6.6: `#CC4040`, for 3 : 1 on `MAP_LAND` too (`accessibility.md` §6.3)* | the marker's stroke **while it travels or rests**, and the dotted road to its target |

- A status belongs to the team when its **source** is `TaskForceSystem.SOURCE` (`"task_force"`),
  never by the `tf_` id prefix; that is the one new branch in the status→colour rule (loop-
  mechanics §16.3.1): player → `ACCENT`, source `task_force` → `TASK_FORCE`, a faction's →
  its faction colour, any other world status → `ACCENT` as now.
- The marker's badge fill stays `BG_2`, its code letters `TEXT_0`.
- The containment panel's Task Force row and the region panel's Task Force row keep their text
  colours; their leading glyph (if any) takes `TASK_FORCE`.
- `ALERT` itself is untouched; the discovered `!` and the starving chip keep it.

Tests (S5.P): the marker's colour is `TASK_FORCE_DIM` while travelling and `TASK_FORCE` while
setting up; a `tf_*` status resolves to `TASK_FORCE` and a player status still to `ACCENT`.

---

## 10. Strings

Every key below exists in `data/loc/strings.csv` in English and German (D5.2 wrote them):
`STATUS_TF_*` and the chain statuses (`_NAME`, `_DETAIL`, `_CODE`), `ABILITY_MISDIRECT_*`,
`CMD_FAIL_NO_TASK_FORCE`, `UI_TASK_FORCE*`, `UI_CONSOLE_TF_*`, `UI_LOG_TF_*`,
`UI_OUTCOME_WIN_MERGE` / `_WIN_ESCAPE` / `_LOSE_SUPPLANTED`, `UI_RESULT_KICKER_SUPPLANTED`,
`UI_RESULT_LINE_<variant>`, `ENDING_EPILOGUE_<id>`, `HEADLINE_*` of `headlines_d5_2.json`, and
`EVENT_<ID>_TITLE` · `_BODY` · `_OPT_<OPTION>` · `_RESULT_<OPTION>` for the sixteen chain steps.
German follows D4.5 (*du*, „…“, no faction–verb agreement). The Researcher is *she* in both
languages, as in D4.3.

---

## 11. Tests (S5.5, S5.6)

- `test_task_force_system.gd`: appears at 0.5 and at 0.4 when led; the base rule; the level never
  falls; hop timing per level; shortest path with the lower-index tie; each action's rule in
  order; a dormant / hidden / clean / dark target fizzles with its cause; `task_force_pace` 0
  stops it; Misdirect during travel and during setup; the statuses do not count toward the cap;
  the same seed gives the same hash (it uses no RNG).
- `test_outcome_system.gd`: the new order; Supplanted from each win; `goal_drifted` turns off
  Ascendance and Merge but not Extinction; Escape and Merge from their flags.
- `test_ending_resolver.gd`: every variant reachable by setting its flags; the default always
  last; the epilogue's order and cap; `outcomes` filtering.
- `test_chains.gd` grows: every branch of the six chains (the S4.7 walker), the Brood's repeats,
  the vote's second tabling.
- Integration: a seeded greedy run that reaches 50 % shows the team, and the save round-trips it.

## 12. Acceptance

S5.5: the team appears, moves and acts in a hand-played run and in batches, Misdirect and dormancy
make it fizzle, 0 rejected bot commands. S5.6: all nine outcomes reachable in tests; every
variant and epilogue line has text in both languages; the results screen fits them at 400 px.

## 13. Decisions (for PROGRESS) and questions for the user

Decisions: §0 items 1–6; the team uses no RNG and ignores link closures; hidden = capacity 0;
it cannot be destroyed; its statuses sit outside the move cap; *Succession* the loss is
**Supplanted** / **Abgelöst**; `goal_drifted` turns off Ascendance and Merge; `ashes_share` moves
into `endings.json`; the Negotiation is a 45-day status, not a phase; the Child's hostility is
fixed only by reclaiming; Escape stays hidden until first reached.

For the user (at G5): is Supplanted — a secret loss that turns a win — fair enough with one
warning card, or should the results screen of a normal win hint that a child is still out there?

---

## 14. D5.5 — a sleeping region fools the team once: the mark (S5.9)

*Added 2026-09-25 (D5.5), answering BALANCE §5.7 (3). Build step: **S5.9**. Everything S5.9 needs
is in this section; §1.4, §2.1, §4, §8 and §9 carry one-line pointers here.*

### 14.1 The problem

Dormancy costs nothing against a five-day setup: put the region to sleep when the setup shows,
wake it the day after. The bots do exactly that (§9) and fizzle 70–100 % of setups; the team acts
0–8 times a run (BALANCE §5.2 item 6, *Balance baselines* S5.P2). §8 wanted a player who answers
every setup to see **about half** fizzle.

### 14.2 The rule

**When a setup ends and fizzles with cause `dormant`, the region is *marked* for
`b.task_force.mark_days` (40) days. While a region is marked, dormancy does not hide it from the
team** — nothing else about dormancy changes: it still freezes growth, yield and deaths, still
leaves the infected share, still hides the region from the factions' counter-moves.

- **Eligible (§2.1):** a dormant region is ineligible **unless marked**. A marked, dormant region
  can be targeted, set up on and acted on; the action's status lands on the sleeping region, its
  `on_start` included (`destroy_assets` and `wipe` already reach a dormant region — a purge does,
  `EffectRunner`).
- **Fizzle (§1.4 step 3):** the cause `dormant` is given only for an unmarked region; a marked
  dormant region that is otherwise eligible is acted on.
- **Only a `dormant` fizzle marks.** `hidden` (Silence, Blackout — paid abilities with their own
  cooldowns), `clean`, `dark` and `redirected` mark nothing.
- **Dormancy while the team is still on the road** makes it choose again (§1.4 step 2, as now) and
  marks nothing: the player who sees where it is going (the Researcher as ally, the watcher's node,
  §2.3) keeps the free dodge. That is what the warning is worth.
- **A misled team** (§4) that reaches a dormant, infected decoy fizzles `dormant` and marks it, like
  any setup.
- **Length:** `until = day + mark_days`, set on the fizzle's day; the region is marked while
  `day < until`. It cannot be marked twice at once (a marked region never fizzles `dormant`); after
  it runs out, the next `dormant` fizzle marks it anew. Nothing ends a mark early — not waking the
  region, not Misdirect, not a rollback.
- **Housekeeping:** at the top of `TaskForceSystem.tick` (after the origin/outcome guard, before
  anything else) every entry with `until <= day` is removed, so the save and the hash carry only
  live marks.

**Why a mark, and not the two options BALANCE §5.7 named.** A cooldown on the dormancy toggle
itself would tax every other use of dormancy (the discovery breadth, the counter-moves, the Open
check) to fix the Task Force alone. A setup that *waits* on a dormant region (with a cap) still
fizzles every setup a patient player sleeps through — only later — so §8's "about half" is not
reached, and a waiting team pins itself where the player chose. The mark is a cooldown on
dormancy's cover **against the team only**: the first setup in a region can be slept through, the
next one there cannot.

**Why 40 days.** At one region the team's cycle is rest 8 + setup 5 = 13 days; one hop away,
8 + 6 + 5 = 19; alternating between two neighbours, about 38 at level 1 (34 at level 3). Forty
covers the team's return to the same region and a two-region alternation, so a region fools it
about once per act; after an act the region is ineligible for 25–60 days anyway (its `tf_*`
status, §2.1). Tuning is balance pass 4's (G6 1/2), not S5.9's.

### 14.3 Model, rules, save

```gdscript
# TaskForce (core/model/task_force.gd)
## D5.5 (§14): region index → the first day it is no longer marked.
var marked: Dictionary[int, int] = {}
## Whether a `dormant` fizzle there is still remembered on `day`.
func is_marked(index: int, day: int) -> bool

# TaskForceRules (core/systems/task_force_rules.gd)
## §14: whether a dormant region is hidden from the team — false while it is marked.
## The one place the rule is asked: `eligible`, `fizzle_cause` and the bots use it.
static func dormancy_hides(world: World, index: int) -> bool
```

- `eligible`: `region.dormant and dormancy_hides(world, index)` → false (the rest of §2.1 as now).
- `fizzle_cause`: `CAUSE_DORMANT` only when `region.dormant and dormancy_hides(world, index)`.
- `TaskForceSystem._setup` on a `dormant` fizzle: `team.marked[index] = day + mark_days`, then the
  event of §14.4, after `task_force_fizzled`.
- **Save:** the team's block gains `"marked": {"<region id>": <until day>, …}` (ids, not indices,
  like `region` and `target`). `to_dict` writes it always (`{}` when empty); `from_dict` reads a
  missing key as `{}` (a v3 save written before D5.5 — v3 changes in place, it has not shipped)
  and returns null for a non-dictionary, an unknown region id or a non-numeric day. The state hash
  covers it through `to_dict`.
- **Balance:** `balance.json` → `task_force.mark_days: 40`; `BalanceDef.task_force_mark_days: int`;
  the validator lists it with the block's whole numbers (≥ 1). SCHEMA §5 row. There is no "off"
  value; a sweep that wants the old behaviour sets 1.

### 14.4 Events and what the player sees

- **Event `task_force_marked {region, days}`** (`SimEvent.TASK_FORCE_MARKED`; `days` =
  `mark_days`), emitted on the same tick right after `task_force_fizzled {cause: "dormant"}`.
  core.md §6.4 catalogue row; `RunLog` keeps `["region", "days"]`.
- **Console:** a `dormant` fizzle has no line of its own (as `redirected`); `task_force_marked`
  says `UI_CONSOLE_TF_MARKED` {region} {days}. `TaskForceText.console_line` handles both.
- **Log:** the fizzle row stays (`UI_LOG_TF_FIZZLED`); the mark adds `UI_LOG_TF_MARKED` {region}
  {days} (the `UI_LOG_TF_` prefix rule of `RunLogText`).
- **Region panel:** under the Task Force row (§9), a second line **whenever the region is marked**,
  whatever the team is doing and whether the region sleeps or not — the player needs it before
  choosing dormancy: `UI_TASK_FORCE_MARKED` {days}, days = `until − day` (≥ 1). New
  `TaskForceText.marked_line(world: World, db: ContentDB, region_index: int) -> String`, `""` when
  not marked; the row's text colour as §9, no leading glyph.
- **Headline** (S5.9 adds the row to `headlines.json` with the event; the validator knows the
  event then): `{"id": "tf_marked", "stream": "reaction", "register": "any", "on": {"event":
  "task_force_marked"}, "cooldown_days": 30}` → `HEADLINE_TF_MARKED` {region}. Placed directly after
  `tf_fizzled`.
- **Map:** nothing new. **Codex:** `CODEX_CHARACTER_TASK_FORCE_TEXT` gained a sentence (written).

### 14.5 Bots

`Policy._answer_task_force` (§9) tries dormancy only where `TaskForceRules.dormancy_hides` is true
for the setup's region; a marked region goes straight to Misdirect, else nothing. The wake loop is
unchanged (waking a marked region keeps its mark). No id checks — the rule is the one function.

### 14.6 Strings (in `data/loc/strings.csv`, en and de)

New: `UI_TASK_FORCE_MARKED`, `UI_CONSOLE_TF_MARKED`, `UI_LOG_TF_MARKED`, `HEADLINE_TF_MARKED`.
Revised: `CODEX_CHARACTER_TASK_FORCE_TEXT` (the mark in one sentence).

### 14.7 Tests (S5.9)

- `test_task_force_system.gd`: a `dormant` fizzle marks the region until `day + mark_days`; a
  marked dormant region is eligible and its setup acts (the status and its `on_start` land); the
  mark runs out on `until` and dormancy hides again; `hidden`, `clean`, `dark` and `redirected`
  fizzles mark nothing; dormancy during travel retargets and marks nothing; expired marks are
  dropped at the tick's start; a misled team fizzling `dormant` on a decoy marks it; same seed,
  same hash.
- `test_task_force.gd` (or the save test that covers the block): `marked` round-trips by region
  id; a block without `marked` loads with none; an unknown region id or a non-number is refused.
- `test_task_force_rules.gd` (or where `eligible` is tested): `dormancy_hides` false while marked,
  true after.
- The bots' test: a setup in an unmarked region is answered by dormancy, in a marked one by
  Misdirect (when owned), else nothing.
- `test_task_force_text.gd`: `marked_line` with the days left, `""` unmarked; the console is silent
  on a `dormant` fizzle and speaks on the mark.
- Content: `mark_days` required, whole, ≥ 1; the `tf_marked` headline validates.

### 14.8 Acceptance

Suite green; a hand-played run shows the region-panel line after a slept-through setup and the
team acting on the sleeping region the next time. **The 100-seed check** (S5.9, recorded under
PROGRESS *Balance baselines*, a check, not a pass): `sim_report --seeds=1..100` per bot on the
Language Model and on the three scenarios — the share of setups that fizzle (`task_force_fizzled`
/ (`acted` + `fizzled`)), actions per run, win share against pass 3. Expected: the bots' fizzle
share falls from 70–100 % towards about half, and the team acts several times more often; the win
shares fall. If a bot's fizzle share stays above 80 %, the check says why (Misdirect, Silence) —
tuning waits for balance pass 4.
