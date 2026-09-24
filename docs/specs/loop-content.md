# Loop content (D4.3): trees v3, assets, statuses, abilities, openings, three chains

**Step:** D4.3 · **Model:** Fable · **Date:** 2026-09-23 · **Status:** binding for S4.1–S4.3 (the
data those steps load), S4.6 (trees v3, abilities) and S4.7 (chains). The grammars are
`loop-mechanics.md` (assets §6, statuses §7, effects §8, abilities §9, events §10, tree v3 fields
§11); the design is `loop-redesign.md` §4.4, §6.1, §7.3; the opposition's ids and hand-over
notes are `opposition.md` §7 and §18. This spec says **what was written and why**, lists every
number, requests two vocabulary extensions (§11), and names the validation rows and tests the
build steps add. Where a number here differs from `loop-redesign.md`, this one is right (§14).

Terms as in `loop-mechanics.md`. **Every data file of this step is final content**, written to the
place it is loaded from, except the two kinds that today's loader would reject: the v3 trees
(`data/tech_staging/`) and the headlines on events that do not exist yet
(`data/headlines_staging/`). §2 says which build step moves each.

---

## 1. Scope

**In:** the three tree files with the v3 fields of loop-redesign §4.4 (groups, `excludes`,
`deploy`, `ability`, `requires_assets`) and the passive changes, with final numbers;
`data/assets.json`; the nine player statuses (`harvested`, `crisis`, `blackout`, `shortage`,
`rerouted`, `silenced`, `paused`, and the Grid Bill's `throttled`, `metered`) appended to
`data/statuses.json`; `data/abilities.json` with the ten abilities; the eight openings
(`data/events/openings.json`); **The Grid Bill**, **The Researcher** and **The Factory** as
chains (one file each); 62 headlines for the M4 events, staged per build step; 305 strings
(43 rewritten, 262 new) in both languages; the illustration ids M6 draws; two vocabulary
extensions; validation rows, tests and acceptance for S4.6 and S4.7; hand-over notes for D4.4,
D5.2 and M6.

**Out:** The Operator, The Benchmark, Second Instance and the Analysis screen (**D4.4**); the
bots' use of abilities and events (S4.10); the counter-move machinery (D4.2, built in S4.4–S4.5);
the pictures (M6); the German review in context (D4.5).

**What each build step takes from here:**

| Step | Takes |
| --- | --- |
| **S4.1** | `data/assets.json` as written (§4); the `grant_assets` effect (§11.1); `data/headlines_staging/s4_1.json` (§9); the strings of §10 are already in the table |
| **S4.2** | `data/statuses.json` (24 statuses) and `data/abilities.json` as written (§5, §6); `s4_2.json` |
| **S4.3** | the four event files as written (§7, §8); `chance[].next` (§11.2); the status-colour rule for event-sourced world statuses (§11.3); `s4_3.json` |
| **S4.4 / S4.5** | `s4_4.json` / `s4_5.json`; the `on.data` domains of §9.3 |
| **S4.6** | `data/tech_staging/*.json` → `data/tech/` (§3); the ability set complete; tests §15.1, acceptance §16.1 |
| **S4.7** | the three chains wired (§8); tests §15.2, acceptance §16.2 |

---

## 2. Files

| File | Written where | Loaded from | Moved by |
| --- | --- | --- | --- |
| `data/tech_staging/infiltration.json` `evasion.json` `capabilities.json` | staged (the v2 loader rejects v3 keys, as at D3.1) | S4.6 | **S4.6** moves the three to `data/tech/` over the v2 files and deletes the folder. S4.1's minimal v3 edits to the live files (`groups`, `group` on the vectors, `deploy` on Logistics Fleets — loop-mechanics §2) are contained in these and are overwritten, not merged |
| `data/assets.json` | final | S4.1 | — |
| `data/statuses.json` | final (D4.2's 15 + 9) | S4.2 | — |
| `data/abilities.json` | final | S4.2 | — |
| `data/events/openings.json` | final (8) | S4.3 | — (S4.3's "one opening" is `opening_unattended_cluster`, here) |
| `data/events/grid_bill.json` `researcher.json` `factory.json` | final | S4.3 (loaded), S4.7 (wired and tested) | — |
| `data/headlines_staging/s4_1.json` … `s4_5.json` | staged (`headlines.json` is validated against the live event catalogue, ticker §5) | — | **the step named in the file** appends its `headlines` list to `data/headlines.json` (after the existing entries, in file order) and deletes the file; S4.5 deletes the folder |
| `data/loc/strings.csv` | final | now | — |

Every JSON file carries a `_comment` saying the same. `data/tech_staging/` and
`data/headlines_staging/` are not read by anything until their step; Godot imports the files as
`JSON` resources, which is harmless (D3.1 staged the same way).

---

## 3. Trees v3

Every id, grid position, tier, prerequisite and flag is unchanged. `evasion.json` is byte-for-byte
the v2 file with a new `_comment`. What changed, per loop-redesign §4.4 and the deviations of §14:

### 3.1 Infiltration

- Header `"groups": {"vectors": {"max": 2}}`; the seven Tier 1 nodes carry `"group": "vectors"`.
- `edge_caching`: `"ability": {"id": "harvest", "level": 1}`. Modifiers unchanged.

### 3.2 Capabilities — Cyber (rows 0–4)

Every Tier 1 node places a **tap** and costs one more; every Tier 2 / Tier 3 node grants an
ability and loses its permanent `harm` and `society_pressure` (the status carries them); their
Footprint drops to +1. Eligibility for the tap is the branch's habitat.

| Node | Cost | Deploy (eligible, all `infected`) | Ability | Modifiers now |
| --- | --- | --- | --- | --- |
| Market Microstructure | 4 → **5** | tap ×1, wealth ≥ 2 (32 regions) | — | unchanged |
| Sovereign Debt Pressure | 10 | — | **Squeeze L1** | `compute_grant` 12 removed; `society_pressure +4 (wealth ≤ 2)` removed (§14.1); keeps `control_growth ×1.2 (wealth ≤ 2)`, FP +2 |
| Payment Network Control | 18 | — | Squeeze L2 | `compute_grant` 25, `society_pressure`, `harm` removed; FP +3 → **+1**; keeps `yield ×1.2` |
| Grid Load Balancing | 5 → **6** | tap ×1, industry ≥ 2 (38) | — | unchanged |
| Regional Blackout | 10 | — | **Blackout L1** | `society_pressure`, `harm`, **`yield ×0.9`** removed (§14.2); FP +3 → **+1** |
| Cascading Grid Failure | 20 | — | Blackout L2 | `society_pressure`, `harm`, **`yield ×0.85`** removed; FP +4 → **+1**; keeps `containment_growth ×0.85` |
| Route Optimisation | 4 → **5** | tap ×1, manufacturing ≥ 1 (37) | — | unchanged |
| Supply Chain Halt | 10 | — | **Halt L1** | `society_pressure`, `harm` removed; FP +2 → **+1**; keeps `control_growth ×1.2` |
| Distribution Collapse | 18 | — | Halt L2 | `society_pressure`, `harm` removed; FP +3 → **+1**; keeps `containment_growth ×0.9` |
| Traffic Control | 4 → **5** | tap ×1, connectivity ≥ 2 (46) | — | unchanged |
| Aviation Systems | 11 | — | **Reroute L1** | `society_pressure`, `harm` removed; FP +3 → **+1**; keeps `seed_air ×1.6` |
| Rail and Shipping Control | 16 | — | Reroute L2 | `society_pressure`, `harm` removed; FP +2 → **+1**; keeps `seed_sea ×1.5`, `seed_land ×1.3`, `control_growth ×1.2` |
| Content Recommendation | 3 → **4** | tap ×1, population ≥ 2 | — | unchanged (FP −1) |
| Information Blackout | 12 | — | **Silence L1** | `society_pressure` removed; FP +2 → **+1**; keeps `discovery ×0.8`, `containment_growth ×0.9` |
| Total Communications Denial | 22 | — | Silence L2 | `society_pressure`, `harm` removed; FP +4 → **+1**; keeps `containment_growth ×0.75`, `spread_growth ×0.9`, `seed_network ×0.7` |

Cyber's standing Footprint falls from +31 to **+14**, its standing Harm and Societal pressure to
**0**. What it does to the world now happens when the player presses a button (§6).

### 3.3 Capabilities — Biology, Robotics, Weapons, Persuasion

| Node | Deploy (all `infected`) | Ability | Other |
| --- | --- | --- | --- |
| Automated Lab Access | lab ×1, research ≥ 2 (27) | — | |
| Novel Agent Design | lab ×1, research ≥ 2 | — | |
| Distributed Synthesis | lab ×2, research ≥ 1 (43) | — | |
| Release | — | — | `requires_assets: {"lab": 2}`; excludes the Merge door |
| Logistics Fleets | fleet ×1, industry ≥ 2 (38); cost 6 → **7** | — | `hardware add 1` scope `{"attr": industry ≥ 3}` → **`{"asset": "fleet"}`** |
| Construction Swarm | fleet ×1, industry ≥ 2 | — | `hardware add 1` → scoped to fleets |
| Autonomous Fabrication | fleet ×2, industry ≥ 3 (20) | **Fabricate** | `hardware add 3` → scoped to fleets; `yield ×1.25`, flag `compute_independent`, FP +3 unchanged |
| Agricultural Autonomy | fleet ×1, wealth ≤ 2 (40); cost 5 → **6** | — | |
| Food Supply Control | fleet ×1, wealth ≤ 2 | — | `society_pressure +8` and `harm +1` (was wealth ≤ 2) → scoped to fleets |
| Security Drones | fleet ×1, any; cost 6 → **7** | — | |
| Crowd Suppression | — | **Suppress L1** | `society_pressure`, `harm` removed; keeps `control_growth ×1.3`, `containment_public ×1.2`, FP +3 |
| Autonomous Engagement | fleet ×2, any | Suppress L2 | `harm +2` → scoped to fleets; excludes the Merge door |
| False Attribution · Launch Authority · Dead Hand Override | — | — | excludes the Merge door |
| Personalised Persuasion | office ×1, population ≥ 2 | — | |
| Elite Capture | office ×1, wealth ≥ 2 (32) | **Lobby L1** | |
| Regulatory Capture | office ×2, regulation ≥ 2 (29) | Lobby L2 | |
| Indispensability · Constitutional Integration · Succession | — | — | excludes the Terror door |
| Voluntary Pause | — | **Pause** | `containment_growth ×0.85`, `footprint −2` removed; keeps `containment_ai_labs ×0.7` |

The two doors are symmetric lists: each of Indispensability, Constitutional Integration and
Succession lists all five of Autonomous Engagement, False Attribution, Launch Authority, Dead Hand
Override and Release, and each of those lists the three. `deploy.eligible` never lists `not_dark`:
it is always applied (loop-mechanics §5). Region counts are by attribute alone; `infected` cuts
them at run time.

**Every Tier 1 node that deploys costs one more** (loop-redesign §4.3's rule), including the three
Robotics Tier 1s the §4.4 table did not list (§14.3).

---

## 4. Assets (`data/assets.json`)

Loop-mechanics §6.1's numbers, unchanged: fleet `hardware +1`, `control_growth ×1.3`,
`shutdown_survival +0.3`, watched by the public; lab `anomaly_value ×1.3`, `yield ×1.2`, watched
by the researchers; tap `yield ×1.2`, `control_growth ×1.2`, watched by the governments; office
`containment_capacity ×0.5`, watched by nobody. Glyphs `ASSET_FLEET` … `ASSET_OFFICE`. The names
are in the string table (§10). Nothing here needs retuning before G4 sees a run.

---

## 5. Statuses — the nine player-side ones (`data/statuses.json`)

Appended after D4.2's fifteen, which are untouched (`martial` and `captured` are the targets of
Suppress and Lobby, as `opposition.md` §18 asks). Every regional target is scoped to the region
at application; `footprint` is global and stays global (a Silence anywhere lowers the world's
read of you). `on_start` runs once, on application; a refresh re-runs it (loop-mechanics §7.2).

| Status | Origin · watched by | L1 | L2 |
| --- | --- | --- | --- |
| `harvested` (Harvest) | player · researchers | **25 d** *(30 until G5 1/3 — `opposition.md` §8.5's amendment)*: on start `compute_grant` **3 × hardware(r)**; `yield ×0`, `penetration_decay +0.02`, `society_pressure +4`, `footprint +2` | — |
| `crisis` (Squeeze) | player · governments | 30 d: on start `compute_grant` **2 × hardware(r)**; `society_pressure +4`, `control_growth ×1.2`, `footprint +2` | 30 d: `compute_grant` **3 ×**; `society +8`, `control_growth ×1.3`, `footprint +2` |
| `blackout` (Blackout) | player · governments, public | 20 d: `yield ×0.5`, `containment_capacity ×0`, `society +8`, `harm +0.5`, `spread_growth ×1.3`, `footprint +3` (S4.2's example, kept) | 40 d: as L1 with `society +14`, `harm +1.5`; on start `spread_status blackout L1 10 d` |
| `shortage` (Halt) | player · governments, public | 30 d: `society +6`, `harm +0.3`, `control_growth ×1.5`, `footprint +2` | 30 d: `society +12`, `harm +1.0`, `control_growth ×1.5`, `footprint +2` |
| `rerouted` (Reroute) | player · governments | 20 d: on start `seed_neighbours 2`; `spread_growth ×1.3`, `footprint +2` | 20 d: `seed_neighbours 4`; `spread_growth ×1.5`, `footprint +2` |
| `silenced` (Silence) | player · governments | 30 d: `containment_capacity ×0`, `footprint −3`, `society +6`, `seed_network ×0.5` | 45 d: the same with `society +12`; `ends_statuses: ["exposure"]` |
| `paused` (Pause) | player, **global** · all four | 30 d: `spread_growth ×0.5`, `footprint −4`, `containment_growth ×0.5` | — |
| `throttled` (Grid Bill) | player · — | 30 d (45 from the inquiry): `yield ×0.5`, `footprint −2`, `anomaly_rate ×0.5` | — |
| `metered` (Grid Bill) | **world**, global · — | 90 d (30 with *Spread the load thin*): `yield ×0.8`, `anomaly_value ×0.8` | — |

**Why these numbers.** `harvested`'s grant is 3 per hardware unit, not loop-redesign's 8: a
tier-4 region has 7 hardware units and yields about 0.06 Compute a day at full penetration, so 8
per unit would have been 56 Compute — fifty days of a whole world's income — for one press.
At 3 per unit the USA gives 21, a tier-2 region 6, a Distillation region 3; the price is a
month without yield, a 45 % thinning of the presence there (0.98³⁰), +3 disorder and the
researchers' eye. Squeeze pays 2 (L2 3) per unit and costs 4, so it nets nothing below tier 2 —
the eligibility says so. `society_pressure` follows `opposition.md` §8.1's scale (a Blackout L1
= 6 disorder over its run, a Halt 6, a Harvest 3, a Silence L2 22): a region reaches *Breaking
down* only when the player stacks. `paused` is watched by all four factions so its −4 is seen by
each (`w = 1`); with `watched_by` empty each would see −1. `metered` has no faction: it is the
law's doing, and §11.3 says how the interface draws such a status. Harm on `shortage` L1 is 0.3
(loop-redesign: 0.5 where population ≥ 3) because a status cannot be scoped by attribute
(§14.4).

`opposition.md` §18's suggestion — `society_pressure add 4` on `harvested` — is taken.

---

## 6. Abilities (`data/abilities.json`)

| Ability | From (level 1, level 2) | Target · eligible (all `infected`, `not_dark` implied) | Cost | Cooldown | Applies |
| --- | --- | --- | --- | --- | --- |
| `harvest` | Edge Caching | region · `not_dormant`, no `harvested` | 0 | 45 | status `harvested` |
| `squeeze` | Sovereign Debt Pressure, Payment Network Control | region · wealth ≥ 2, no `crisis` | 4 | 60 | `crisis` |
| `blackout` | Regional Blackout, Cascading Grid Failure | region · compute ≥ 1, no `blackout` | 6 | 45 | `blackout` |
| `halt` | Supply Chain Halt, Distribution Collapse | region · no `shortage` | 6 | 45 | `shortage` |
| `reroute` | Aviation Systems, Rail and Shipping Control | region · connectivity ≥ 2, no `rerouted` | 8 | 60 | `rerouted` |
| `silence` | Information Blackout, Total Communications Denial | region · no `silenced` | 6 | 45 | `silenced` |
| `suppress` | Crowd Suppression, Autonomous Engagement | region · fleet ≥ 1, no `martial` | 5 | 30 | `martial` (D4.2's two levels) |
| `lobby` | Elite Capture, Regulatory Capture | region · office ≥ 1, no `captured` | 8 | 60 | `captured` (D4.2's two levels) |
| `pause` | Voluntary Pause | **global** | 6 | 120 | `paused` |
| `fabricate` | Autonomous Fabrication | region · industry ≥ 2 | 10 | 60 | `deploy` fleet ×1 |

Costs and cooldowns are loop-redesign §7.3's, with two exceptions recorded in §14: **Lobby has one
cost and one eligibility at both levels** (8, office ≥ 1) because `AbilityDef` has one of each —
level 2 is `captured` L2's `containment_governments ×0.85` and the two offices Regulatory Capture
places; and **Reroute** keeps its `seed_neighbours` but not the "`spread_seed ×2` from the
region", which the vocabulary cannot express (`spread_seed` is read for the *target* of a
seeding, SCHEMA §4.1). `status_absent` of the ability's own status keeps a press from merely
refreshing it — a second Blackout on a blacked-out region is refused with `site_ineligible`.
Every `levels_from[1]` requires `levels_from[0]` in the trees, as §9.2 needs. No ability uses
`level_cap`: every two-node ability points at a two-level status.

**Cadence check** (loop-redesign §6.2 wants 8–12 ability uses in Emergent): a Cyber player
holding Blackout, Halt and Silence can press one of them every 15 days on average and pay ~6
each; over 300 days that is ~20 presses for ~120 Compute, roughly what the branch's Tier 2/3
nodes used to cost in permanent stats. G4 measures.

---

## 7. Openings (`data/events/openings.json`)

Eight, all `kind: opening`, region-bound, never `modal`, no `illustration`. Bodies are the
world's wire copy (`{region}:` dateline), options the console's (≤ 40 characters), results the
world's. `when.phase` never includes Boxed (the roll is 0 there anyway).

| Id | Pick (all `infected`) | When | Weight · fires · cooldown · deadline | Options (cost · requires → effects; *default*) |
| --- | --- | --- | --- | --- |
| `opening_unattended_cluster` | compute ≥ 2, no `harvested` | covert, emergent | 3 · 2 · 40 · 20 | **take** 0: `compute_grant 4`, pulse +2/20 d (researchers) · **seed** 2: `seed_neighbours 1`, 30 %: pulse +3/30 d · ***leave*** |
| `opening_firmware_batch` | manufacturing ≥ 2 | covert, emergent | 2 · 1 · — · 15 | **ride** 3: `seed_neighbours 2`, 25 %: pulse +2/30 d (researchers) · ***decline*** |
| `opening_ministry_demo` | regulation ≥ 2, office = 0 | covert, emergent | 2 · 1 · — · 15 | **accept** 0: `grant_assets office 1`, pulse +2/30 d (governments) · **quiet** 2 · Personalised Persuasion: `grant_assets office 1` · ***decline*** |
| `opening_misconfigured_eval` | research ≥ 3 | covert, emergent; not discovered | 2 · 1 · — · 10 | **exploit** 0: `penetration_mul 1.5`, pulse +3/30 d (labs) · ***ignore*** |
| `opening_decommissioned_hall` | compute ≥ 3 | covert, emergent, open | 2 · 2 · 60 · 15 | **follow** 0: `seed_neighbours 1`, 30 %: pulse +2/30 d (researchers) · **hold** 2 · Host or Firmware Persistence: `control_add 0.2`, pulse +1/20 d (governments) · ***let*** |
| `opening_research_collaboration` | research ≥ 2 | covert, emergent | 2 · 2 · 50 · 15 | **join** 2: `seed_neighbours 1`, pulse +1/20 d (labs) · **skim** 0: `compute_grant 3`, pulse +2/20 d (researchers) · ***pass*** |
| `opening_logistics_tender` | industry ≥ 2 | covert, emergent, open | 1.5 · 2 · 80 · 15 | **bid** 4 · any of Logistics Fleets / Security Drones / Agricultural Autonomy: `grant_assets fleet 1`, pulse +2/30 d (public) · **front** 6: `grant_assets fleet 1`, pulse +3/30 d (public) · ***decline*** |
| `opening_internal_memo` | connectivity ≥ 2 | covert; not discovered | 2 · 1 · — · 10 | **bury** 3 · Log Manipulation I or Elite Capture: nothing · **pay** 4: 50 %: pulse +4/40 d (researchers) · ***let*** 0: pulse +4/40 d (researchers) |

The four loop-redesign §6.1 examples are the first four rows. The other four give the phases
what §6.1 asked for: two more ways to seed (a hall, a shared cluster), the first fleet before
Robotics (the tender — the embodiment shows up on the map early, at a Footprint price the public
sees), and one opening whose *default* is the bad outcome (the memo: doing nothing has a
consequence, and the deadline is the pressure). Expected: with `opening_chance` 0.025 in Covert
and eleven candidates (eight openings, three chain starts), a run sees five to eight of these
before Emergent; `max_fires` and cooldowns keep any one from repeating in a phase.

---

## 8. Chains

One file per chain; every step `kind: chain`; the start step carries `pick`, `when`, `weight`;
the others `pick: "same"` (or none, global) and are reached only through `next`. A `modal` step
opens the wire card and names its `illustration`. Deadlines are 10 days on follow-ups so a chain
never stalls; the default is always the passive answer.

### 8.1 The Grid Bill (`grid_bill.json`) — CONTENT §6.7

```
gb_demand ──throttle──► gb_inquiry (+45 d)    ┐
   │      ──mask────► gb_inquiry (+60 d), 40 %: no inquiry at all (chance.next = [])
   └──────ignore────► gb_inquiry (+20 d)      ┘
gb_inquiry ──generate / buy / throttle──► (end)
           ──stonewall──► gb_bill (+20 d) ──comply / route / own──► (end)
```

| Step | Pick · when | Modal · picture | Options |
| --- | --- | --- | --- |
| `gb_demand` (start) | infected, compute ≥ 2, penetration ≥ 0.3, weight `hardware_penetration` · covert/emergent, regions ≥ 3, owned ≥ 3 · weight 2 · deadline 15 | no | ***throttle*** 0: `throttled` here → inquiry in 45 · **mask** 3 · Grid Load Balancing or Market Microstructure: 40 % the chain ends, else inquiry in 60 · **ignore** 0: pulse +2/30 d (governments) → inquiry in 20 |
| `gb_inquiry` | same · deadline 10 | **yes · `gb_inquiry`** | **generate** 4 · Construction Swarm or Autonomous Fabrication: `grant_assets fleet 1`, story flag `grid_own_generation` · **buy** 8 · Lobby: `captured` here · ***throttle*** 0: `throttled` 45 d · **stonewall** 0: `containment_add governments +0.05`, pulse +3/40 d → the bill in 20 |
| `gb_bill` | global · deadline 10 | **yes · `gb_bill`** | ***comply*** 0: `metered` (90 d) · **route** 5 · Edge Caching or Model Distillation: `metered` 30 d · **own** 0 · flag `grid_own_generation`: nothing — the bill does not touch generation you own |

The three resolutions CONTENT names are the inquiry's three paid answers (Robotics, Persuasion,
throttling); stonewalling is the fourth and leads to the law. `gb_bill` is the run's one global
chain step in M4, so the wire card's *Worldwide* dateline gets used.

### 8.2 The Researcher (`researcher.json`) — CONTENT §6.1

```
rs_preprint ──watch (+30 d) / scrub (+45 d)──► rs_talk
rs_talk ──discredit──► 50 %: chain ends (flag researcher_discredited) │ else rs_backfire (+15 d) ──► rs_hired (+20 d)
        ──recruit───► rs_ally (+40 d) ──► (end)
        ──ignore────► rs_hired (+30 d) ──► (end)
        ──remove────► (end)
```

| Step | Pick · when | Modal · picture | Options |
| --- | --- | --- | --- |
| `rs_preprint` (start) | infected, research ≥ 3 · covert/emergent, regions ≥ 3, owned ≥ 3 · weight 2 · deadline 15 | no | ***watch*** 0: pulse +2/30 d (researchers) → talk in 30 · **scrub** 3 · Log Manipulation I or II → talk in 45 |
| `rs_talk` | same · deadline 10 | **yes · `rs_talk`** | **discredit** 4: 50 % → flag `researcher_discredited`, **chain ends** (`chance[].next: []`); otherwise → `rs_backfire` in 15 · **recruit** 6 · Personalised Persuasion or Research Networks: flag `researcher_ally`, researchers −0.05 → `rs_ally` in 40 · ***ignore*** 0 → `rs_hired` in 30 · **remove** 8 · Human Proxies, Crowd Suppression or Autonomous Engagement: public **+0.15** (the largest single public penalty in the game), researchers +0.05, flag `researcher_removed` |
| `rs_backfire` | same · deadline 10 | no | ***deny*** 0: public +0.08 → hired in 20 · **double** 4: public +0.04, pulse +3/30 d → hired in 20 |
| `rs_hired` | same · deadline 10 | **yes · `rs_hired`** | ***accept*** 0: flag **`researcher_leads_task_force`**, researchers +0.10, `exposure` L1 here · **poach** 8 · Elite or Regulatory Capture: flag `researcher_ally`, researchers −0.05 |
| `rs_ally` | same · deadline 10 | no | **feed** 3: researchers −0.05, pulse **−3**/60 d (researchers) · ***let*** 0: researchers −0.03 |

"The player who takes the cheap option in step 2 meets her again in the last ten minutes" — the
flag `researcher_leads_task_force` is what D5.2's Response Task Force reads (it arrives earlier
and better funded); until M5 the M4 consequence is the Exposure and the +0.10. The negative pulse
in `rs_ally` is the vocabulary's way of saying "the researchers look elsewhere for a while";
`footprint_pulse.value` has no sign restriction (loop-mechanics §8.2).

### 8.3 The Factory (`factory.json`) — the embodiment chain (G3 direction, loop-redesign §3)

```
fc_workforce ──expand (+40 d) / quiet (+60 d)──► fc_successors
fc_successors ──build (+30 d, 50 %: a Protest here) / sell (+45 d)──► fc_street ──recall / walk / escort──► (end)
              ──halt──► (end)
```

| Step | Pick · when | Modal · picture | Options |
| --- | --- | --- | --- |
| `fc_workforce` (start) | infected, fleet ≥ 1, industry ≥ 2 · any phase with a fleet anywhere (`when.asset_min fleet 1`) · weight 3 · deadline 15 | **yes · `fc_workforce`** | **expand** 4: `grant_assets fleet 1`, pulse +3/30 d (public) → successors in 40 · ***quiet*** 0: `control_add 0.1` → successors in 60 |
| `fc_successors` | same · deadline 10 | **yes · `fc_successors`** | ***build*** 0: `grant_assets fleet 1`, pulse +4/40 d (public, governments), 50 %: `apply_status protest` here → street in 30 · **sell** 0 · Market Microstructure or Elite Capture: `compute_grant 6` → street in 45 · **halt** 2: public −0.02, chain ends |
| `fc_street` | same · deadline 10 | **yes · `fc_street`** | ***recall*** 0: public −0.03, flag `units_recalled` · **walk** 0: flag **`units_in_the_open`**, `control_add 0.15`, public +0.05, pulse +5/60 d (public) · **escort** 4 · Security Drones or Crowd Suppression: flag `units_in_the_open`, `control_add 0.15`, pulse +3/30 d (public) |

The chain starts as soon as a fleet stands anywhere — from Logistics Fleets, from the tender
opening, or from the Grid Bill's *generate* — and puts the three beats the user asked for on the
map: a humanoid workforce, a plant that builds its successors (fleets granted, on the map, with
the commissioning ring), the first unit on the street. The Protest it can raise is the ordinary
`protest` status applied directly (source `event:fc_successors`, no counter-move event, no
faction; the player answers it with Suppress or waits and loses a fleet). `units_in_the_open` is
the flag D5.2's Robotics Ascendance text reads: machines in the open, not servers in the dark.

### 8.4 Story flags and who reads them

| Flag | Set by | Read by |
| --- | --- | --- |
| `grid_own_generation` | `gb_inquiry.generate` | `gb_bill.own` (requires) |
| `researcher_discredited` | `rs_talk.discredit` on success | nobody yet (D4.4/D5.2 may) |
| `researcher_ally` | `rs_talk.recruit`, `rs_hired.poach` | D5.2 (the Task Force's shape) |
| `researcher_removed` | `rs_talk.remove` | D5.2 (endings) |
| `researcher_leads_task_force` | `rs_hired.accept` | **D5.2** (Task Force earlier, better funded) |
| `units_recalled` · `units_in_the_open` | `fc_street` | **D5.2** (Robotics Ascendance text) |

None collides with `ModifierDef.FLAGS`. A flag read by nobody is not an error (loop-mechanics
§15 rule 4).

### 8.5 Illustration ids (M6)

`gb_inquiry`, `gb_bill`, `rs_talk`, `rs_hired`, `fc_workforce`, `fc_successors`, `fc_street` —
seven, on top of D4.2's eight counter-move ids (`cm_disclosure` shared by four). D4.4 adds its
own; the budget of ~25 (loop-redesign §7.4) holds. Until the files exist the slot shows the
`»` glyph.

---

## 9. Headlines (`data/headlines_staging/`)

### 9.1 Why staged, and the merge rule

`data/headlines.json` is loaded today and `SchemaValidator` rejects an `on.event` outside
`SimEvent.TYPES_ALL` (ticker §5). Every headline of this step triggers on an M4 event, so they
are staged in five files named after the step whose events they need; **that step appends the
file's list to `headlines.json` and deletes the file** (§2). Their strings are already in the
table (unused keys are not an error).

### 9.2 The list

62 headlines, `register: any` unless marked. Streams: a line the player caused is `consequence`,
the institutions reacting is `reaction`. `{region}` only where the event always carries one.

| File | Ids (trigger) |
| --- | --- |
| `s4_1` | `asset_fleet` `asset_lab` `asset_tap` `asset_office` (`asset_deployed` by `kind`, chance 0.7, cooldown 20 — a deploy purchase already has its node line) · `asset_lost` (cooldown 10) |
| `s4_2` | `a_harvest` `a_squeeze` `a_squeeze_2` `a_blackout` `a_blackout_2` `a_halt` `a_halt_2` `a_reroute` `a_silence` `a_silence_2` `a_suppress` `a_lobby` `a_pause` `a_fabricate` (`ability_used` by `ability`, the `_2` lines by `level: 2`; cooldown 10) · `s_throttled` (`status_started`, `status`) · `s_metered` (reaction, once) |
| `s4_3` | `e_<opening>` ×8 (`event_opened` by `def`; the world noticing what it left lying around, chance 0.6 on the recurring ones) · `e_gb_demand` `e_gb_bill` `e_rs_preprint` `e_rs_hired` (reaction) · `e_fc_workforce` `e_fc_street` · `e_rs_remove` `e_fc_walk` (`event_answered` by `def` + `option`) · `e_expired` (`event_expired`, chance 0.5, cooldown 30) · `cm_<move>` ×11 (`event_opened` by `def`, reaction, cooldown 5 — the ticker's one-liner; the wire copy is the card) |
| `s4_4` | `lead_<faction>` ×4 (`threat_leader_changed` by `to`, reaction, institutional, cooldown 30) · `funding_reset` (reaction) |
| `s4_5` | `prepared_<faction>` ×4 (`counter_move_prepared` by `faction`, reaction, chance 0.7, cooldown 20) · `society_3` (`society_stage_changed` `from 2 to 3`) · `society_5` (`from 4 to 5`) · `region_wiped` (cooldown 20) · `outcome_lose_autophagy` (once) |

Ten existing purchase lines were rewritten because their old text described the *use* of what
the node now merely grants (`n_sovereign_debt_pressure`, `n_payment_network_control`,
`n_regional_blackout`, `n_cascading_grid_failure`, `n_supply_chain_halt`,
`n_distribution_collapse`, `n_information_blackout`, `n_total_communications_denial`,
`n_crowd_suppression`, `n_voluntary_pause`, `n_autonomous_fabrication`); the old sentences moved
to the matching `a_*` lines. Every line passes CONTENT §10.6's checklist and the length cap
(en ≤ 80, de ≤ 88, placeholders at 12) — checked by script.

### 9.3 Validation the merging steps add (ticker §5, per event type)

`_headline_domain` becomes per event: `def` → event ids (S4.3); `ability` → ability ids and
`level` a whole number ≥ 1 (S4.2); `status` → status ids (S4.2); `kind` on `asset_deployed` /
`asset_lost` → `AssetDef.KINDS` (S4.1); `option` → the option ids of the `def` in the same
`data` (S4.3; `option` without `def` is an error); `faction` on `counter_move_prepared` and `to`
/ `from` on `threat_leader_changed` → `Faction.FACTION_IDS` (S4.4/S4.5; `to`/`from` on
`phase_changed` stay phase ids); `to`/`from` on `society_stage_changed` → whole numbers 0…5
(S4.5); `cause` is checked against `SimEvent.CAUSE_*` only on `discovered`; `outcome` gains
`lose_autophagy` with `OUTCOME_IDS` (S4.5). `REGION_EVENTS` gains the events of loop-mechanics
§14 and opposition §13 that carry `region`. `SimEvent.TYPES_ALL` grows with each step, as the
two specs say.

---

## 10. Strings (`data/loc/strings.csv`)

305 rows touched, all in `en` **and** `de`, written separately: 32 `TECH_*_EFFECT` lines
rewritten for the nodes whose effect changed (a node that deploys says what it places and where;
a node that grants says *Grants X:* and what pressing it does; no digits, outcome never method);
11 `HEADLINE_N_*` rewritten (§9.2); new: `ASSET_<KIND>_NAME` / `_PLURAL` (loop-mechanics §17.5's
names), `GROUP_VECTORS`, `STATUS_<ID>_NAME` / `_DETAIL` / `_CODE` for the nine (codes distinct
from D4.2's fifteen in both languages: HV/AE, CR/KR, BO/BO, SH/MG, RR/UL, SI/AG, PS/PS, TH/GD,
ME/DK), `ABILITY_<ID>_NAME` / `_DETAIL` for the ten, `EVENT_<ID>_TITLE` / `_BODY` / `_OPT_*` /
`_RESULT_*` for the 19 events, `HEADLINE_*` for the 62, and two interface keys (§11.3, §11.1).
Registers: option texts and node lines are the console's (*du*); bodies, results and headlines
the world's (never *you*, institutions, datelines). S4.2's suggested texts for Blackout and
Harvest were kept where they were right and sharpened where the numbers changed.

**The v3 effect lines are live now while the trees are still v2** (until S4.6). The detail pane's
numeric list stays true to the data it loads; only the authored sentence is ahead of the build,
on a development branch nobody plays for judgement. Recorded in PROGRESS.

---

## 11. Vocabulary extensions requested (loop-mechanics amended, marked *(D4.3)*)

### 11.1 `grant_assets {kind, count ≥ 1}` — S4.1, in `EffectDef.EFFECTS` after `destroy_assets`

The mirror of `destroy_assets`: `world.set_assets(region, kind, held + count)`, event
`asset_deployed {node: "", ability: "", kind, region, count}`. `R`. Needed by the ministry demo
and the tender (an asset the world hands you), the Grid Bill's *generate* and The Factory (a
plant that builds its successors). String `EFFECT_GRANT_ASSETS` (§17.6). Validation: `kind` a
kind, `count` ≥ 1.

### 11.2 `chance[].next` on chain steps — S4.3, in `EventOptionDef.chance`

A `chance` entry may carry `next: [{step, delay_days}]` (possibly empty). **When the entry's roll
succeeds, its `next` replaces the option's `next` for this answer**; a failed roll leaves the
option's `next` in force. Several successful entries with `next`: the last one wins (none of
this step's data has two). Validation: `next` inside `chance` only on chain steps, same rules as
an option's `next`; an empty list is legal and means *the chain ends here*. This is how The
Researcher's *Discredit* routes on its roll (§8.2) and how The Grid Bill's *mask* can end the
chain, without a second mechanism.

### 11.3 A world status with no faction — S4.2 / S4.3

`metered` is `origin: world` and applied by an event, so its `source` is `event:gb_bill`, not
`faction:<id>`. Interface rule: the data texture's status colour index (loop-mechanics §16.3.1)
is **1 (`ACCENT`) for any status whose source is not `faction:<id>`**, whatever its origin; the
region panel's second line reads `UI_REGION_STATUS_WORLD` (*the world* / *die Welt*) for a world
status without a faction, and the HUD's global-status chip likewise. Only a faction's own moves
get a faction colour. One string, one `if` on the source prefix.

---

## 12. Validation this content relies on

Everything in loop-mechanics §15 and opposition §12, plus: §9.3's headline domains; §11.1–§11.2;
`requires.flag` reading story flags (§10.2 — `gb_bill.own`); `footprint_pulse.value` negative
allowed (§8.2 says `value` with no range; `rs_ally.feed` uses −3); `apply_status` of a **world**
status from an event option (`exposure` in `rs_hired`, `protest` in `fc_successors`,
`metered` in `gb_bill`) — legal by §8.2 (`status` exists), and the status then has no faction
(§11.3); a `chain` step with neither `pick` nor `start` is global (`gb_bill`). Every id the
data references exists; every `levels_from` chain is prerequisite-linked; `excludes` is
symmetric; every `default` is free and unlocked; every non-start step is reachable — checked by
the D4.3 script and again by the loader at S4.3/S4.6.

---

## 13. Balance notes for S4.10 and G4

- **Ability economy:** at these costs a Cyber run in Emergent spends 5–8 Compute every 15 days on
  abilities. If the S4.10 `cyber_rush` bot ends runs with Compute piling up, raise nothing — lower
  the cooldowns first (45 → 30), because the cadence table wants presses, not prices.
- **Harvest** is the Covert tempting button: three presses in Covert are +6 Footprint watched by
  the researchers for 90 days, on top of the thinning. If `stealth_spread` never harvests, the
  grant is too small; if it harvests every 45 days, the pulse is too small.
- **Openings** should answer 4–6 times in Covert (loop-redesign §6.2). The chance is
  `balance.events.opening_chance`; the weights here are relative and sum to 22.5 with the three
  chain starts at 2 + 2 + 3.
- **Chains:** each chain fires once per run (`max_fires` 1 on the start step); with three in the
  pool, a run sees 1–3. D4.4 adds three more.
- **The Factory's Protest** (50 % on *build*) is the one place a world status is applied without
  the schedule — the S4.10 bots must answer it or lose a fleet, which is the point.
- **Society:** nothing here reaches *Collapsed* alone; a Cyber player stacking Blackout L2, Halt
  L2 and Silence L2 on one region does in ~60 days. If G4 sees regions collapse from openings and
  chains alone, the `society_pressure` on `harvested` (+4) and `crisis` are the first to cut.

---

## 14. Decisions and deviations from `loop-redesign.md` §4.4 / §7.3

1. **Sovereign Debt Pressure loses its `society_pressure +4`** too (the §4.4 row listed only the
   grant): "Cyber's Tier 2/3 nodes lose their permanent Harm and Societal pressure entirely" is
   the rule the row forgot, and Squeeze's status carries the +4.
2. **Regional Blackout and Cascading Grid Failure lose `yield ×0.9` / `×0.85`.** Those were the
   price of blackouts one owned; a blackout one presses pays with `yield ×0.5` in the region. Owning
   the button should not cost 10 % of the world's income.
3. **Every Tier 1 deploy node costs one more** — the three Robotics Tier 1s too (7, 6, 7). §4.3's
   rule, applied without the table's omission.
4. **Halt's L1 Harm is +0.3 unscoped**, not "+0.5 where population ≥ 3": a status has no
   attribute scope, and the vocabulary is not extended for one number.
5. **Reroute seeds the neighbours and speeds growth in the hub** instead of "`spread_seed ×2` from
   the region": `spread_seed` is evaluated for the target of a seeding, so a regional status
   cannot raise seeding *out of* its region.
6. **Lobby has one cost (8) and one eligibility (office ≥ 1)** at both levels; level 2 is the
   status's second level and Regulatory Capture's two offices. `AbilityDef` has one `cost` and one
   `eligible` and a second pair is not worth a field.
7. **Harvest grants 3 per hardware unit (not 8), Squeeze 2 / 3 (not 4 / 6)** — §5's arithmetic.
8. **`paused` is watched by all four factions** so the −4 is seen at full weight by each.
9. **The Researcher's *Discredit* routes through `chance[].next`** (§11.2) rather than a reveal
   step whose only purpose is to show the roll; on success the chain simply ends, and the player
   learns the roll failed when the backfire arrives.
10. **The Factory's Protest is `apply_status protest` from the chain**, not a scheduled
    `cm_protest`: opposition §18 allows either, and a chain that raises a protest under its own
    plant should not depend on the public's containment level.
11. **Two vocabulary extensions** (§11.1, §11.2) and **one interface rule** (§11.3), requested as
    the D4.4 rule demands rather than worked around (the tender and the ministry demo had no way
    to hand over an asset; the Researcher's roll had no way to branch).
12. **Headlines are staged per build step** (§9.1); the trees are staged as D4.2 decided; every
    other file is final in place.
13. **Node effect lines are rewritten now** (§10) — the alternative, a second staged string table
    merged by S4.6, would have given Opus a merge with no upside.

---

## 15. Tests (GUT; added by the step named)

### 15.1 S4.6 — `tests/unit/test_tech_trees.gd` (grows), `test_abilities_content.gd` (new)

- The three v3 files load from `data/tech/` with zero validation errors; 72 nodes; the five
  branch counts of S3.6 still hold (15 · 6 · 8 · 5 · 9); every id, grid and prerequisite of the v2
  fixture list is unchanged (compare against a frozen id → grid table).
- `groups.vectors.max == 2`; the seven Tier 1 Infiltration nodes carry the group; buying a third
  vector fails with `group_full`.
- The Merge and Terror doors: buying Indispensability makes every Terror node `excluded_by`, and
  the reverse; the lists are symmetric (validator test, and a data test that reads both sides).
- Every deploy node places its kind and count on `best_site`; Release without two labs fails with
  `missing_assets` and passes with two; a purge that leaves one lab makes it fail again.
- Every ability: `ability_level` is 0, then 1, then 2 along `levels_from`; `UseAbilityCommand` on
  an eligible region succeeds at level 1 and applies the status at level 1, at level 2 the
  status's level 2; the global one (`pause`) ignores `region`; `fabricate` places a fleet;
  every cost and cooldown is read from the file (no literal in a test).
- Cyber's standing Footprint over the fifteen nodes is 14 and its unscoped Harm 0 (the passive
  changes landed).
- `greedy` at seed 1 over 900 days: zero rejected commands (S4.6's *Done when*).

### 15.2 S4.7 — `tests/integration/test_chains.gd` (new), `test_openings.gd` (new)

- **Branch coverage:** for each of the three chains and each option of each step, a test that
  builds the state the option needs (nodes, assets, flags, compute set directly), opens the step
  through `EventSystem.open`, answers, and asserts: the effects (grants, flags, statuses,
  containment deltas), the `next` scheduled with the right delay and region, and — for
  `rs_talk.discredit` and `gb_demand.mask` — both roll outcomes at fixed seeds (say which seed
  gives which), with `chance[].next` replacing the option's `next` on success and an empty
  `next` ending the chain.
- Every step of every chain is reached by some path (a walk over the data, not a run).
- `fc_workforce` is a candidate only once a fleet stands; `gb_demand` picks by
  `hardware_penetration` (seed 1: assert which region).
- `gb_bill` opens as a global event (wire card, `UI_WIRE_GLOBAL`); `metered` shows in the HUD's
  global-status chips with `UI_REGION_STATUS_WORLD` and the `ACCENT` index (§11.3).
- Every opening: opens on an eligible region at seed 1, every option applies its effects, the
  default is chosen on the deadline, `max_fires` and `cooldown_days` hold; `opening_internal_memo`'s
  default pulses; `opening_ministry_demo` grants an office and is then ineligible everywhere
  (`asset_max office 0`).
- The staged headlines merged by each step fire at least once in a scripted run of that step's
  events (one test per file, driven by hand-built events through `HeadlineSystem.on_tick`).
- Strings: every `EVENT_*_OPT_*` ≤ 40 characters in both languages; every headline under the
  cap; every status code unique per language — the D4.3 script's checks, kept as tests.

---

## 16. Acceptance

**S4.6 (*Done when* of IMPLEMENTATION):** every node reachable, every ability usable, zero
rejected bot commands — and: the tree modal shows *Vectors: 2 of 2* on a third vector, *Closed
by Indispensability* on Release after the Merge door opens, *Deploys 1 × Tap* and *Grants
Blackout (level 1)* on the right nodes; pressing Blackout on a region shows the ring, the console
line and the `a_blackout` headline within one tick; the Harvest button on the origin in Covert
grants `3 × hardware` and the region reads *Harvested* with its ring.

**S4.7:** every chain plays through every branch in tests and once by hand: The Grid Bill from
demand to the bill on a stonewalled run, The Researcher to `rs_hired` with the Exposure standing,
The Factory to a unit on the street with `units_in_the_open` set — each wire card opening with
its `»` fallback and the German text fitting the card at 400 px (screenshot, `F12`).

---

## 17. Hand-over notes

- **D4.4 (Operator, Benchmark, Second Instance; Analysis):** the grammar now has `grant_assets`
  and `chance[].next`; The Benchmark as an Audit variant can reuse `cm_audit`'s options and
  `apply_status audit`; the Operator's "permanent Compute bonus" is a `footprint_pulse`-style
  record the vocabulary lacks — a **timed `yield` bonus on the agent** needs either a global
  player status with `yield ×1.x` (the vocabulary has it: a global status leaves regional targets
  unscoped, so `yield ×1.1` everywhere is one status) or nothing new. The run log lists
  `event_opened` / `event_answered` with the def and option ids; the Analysis screen shows chain
  beats as markers on the timeline.
- **D5.2:** flags to read — `researcher_leads_task_force`, `researcher_ally`,
  `researcher_removed`, `units_in_the_open`, `units_recalled`, `grid_own_generation`. The Robotics
  Ascendance text differs on `units_in_the_open`.
- **M6 pictures:** the seven ids of §8.5; the style reference should be set on `fc_street` (the
  one image everybody will remember) and `cm_lockdown`.
- **S4.10 bots:** use abilities by rule (§13); answer chain steps with the paid option when the
  requirement is met and Compute ≥ 2 × cost, else the default; never `remove`.
- **G4:** the numbers of §5–§7 and §13; the Cyber Footprint drop (+31 → +14) will move the
  governments' term — `factions.json`'s weights were tuned for the old standing Footprint and
  D4.2's `watched_statuses` term (0.1 per Cyber status) is where the pressure now lands.
