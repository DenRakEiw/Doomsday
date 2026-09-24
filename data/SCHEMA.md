# Content schema

The format of every file under `data/` and the modifier vocabulary. **Kept current:** whoever
changes a loader, a format or the vocabulary changes this file in the same commit.
`SchemaValidator` enforces everything stated here; where this file and the validator disagree, that
is a bug in one of them.

Version: **v6** (D1.1 — regions, links, technology nodes, balance; D3.1 — the node grid, the
factions that watch a node, one-shot effects, the targets and flags of the three trees; D3.4 —
`headlines.json` and the `headlines` balance section; D4.1 — `assets.json`, the `asset` scope, the
eligibility grammar, the effect vocabulary as one list, the tree v3 fields, and — written up here
at S4.2 — `statuses.json` and `abilities.json`; at S4.3 — `events/*.json`, the `events`
balance section and the `when` keys of loop-mechanics §10.3; at S4.4 — `factions.json`, the
`factions` balance section, `capacity_weight_by_tier`, the four brakes and `funding_reset` live;
at S4.5 — the `society` balance section, `society_pressure` and `compute_independent` live, the
outcome `lose_autophagy`).
Later specs add sections.

## 1. General rules

- UTF-8, tab-indented JSON, one top-level object per file.
- **JSON has no integers.** Loaders cast every integer field explicitly (`int(d["index"])`). A
  number with a fractional part in an integer field is a validation error.
- Ids are lower snake case, `^[a-z][a-z0-9_]*$`, unique within their kind, and never reused for
  something else once a save format containing them has shipped.
- **Unknown fields are errors** (they are almost always typos) — except keys starting with `_`
  (`_comment`), which are ignored everywhere.
- Optional fields have the default given in the tables; "required" means the validator reports the
  file if the field is absent.
- Content files hold **no player-visible text**. Text lives in `data/loc/strings.csv` under keys
  derived from the id (§6).

Layout of a content root (`res://data` or a test fixture directory — both have the same shape):

```
<root>/balance.json
<root>/world/regions.json
<root>/world/links.json
<root>/assets.json
<root>/statuses.json
<root>/abilities.json
<root>/tech/*.json          every file, in ascending file-name order
<root>/events/*.json        every file, in ascending file-name order; the directory must exist
<root>/headlines.json
```

Every file added from M4 on carries `"version": 1` at its top level. `balance.json`,
`world/*.json`, `tech/*.json` and `headlines.json` keep the shapes they have.

## 2. `world/regions.json`

```json
{
	"regions": [
		{
			"index": 1,
			"id": "fx_alder",
			"continent": "west",
			"population": 60000000,
			"air_gapped": false,
			"anchor": [100, 100],
			"attributes": {"compute": 4, "connectivity": 4, "wealth": 4, "regulation": 3,
				"research": 4, "manufacturing": 1, "industry": 2, "isolation": 0}
		}
	]
}
```

| Field | Type | Required | Rule |
| --- | --- | --- | --- |
| `index` | int | yes | 1…65535, unique, and the set of indices is exactly 1…N with no gaps, N ≥ 1. **0 is reserved for "no region".** Equals the colour index in the ID map. Stable once published |
| `id` | id | yes | unique |
| `continent` | id | yes | free vocabulary; used by scopes and the continent milestone |
| `population` | int | yes | ≥ 1 |
| `air_gapped` | bool | no (`false`) | initial state; refuses seeding unless `airgap_cross` > 0 |
| `anchor` | [int, int] | yes | pixel position on the ID map for markers and link ends; both ≥ 0 |
| `attributes` | object | yes | **exactly** the eight keys below, each an int tier 0…4 |

Attributes: `compute` (hardware density), `connectivity`, `wealth`, `regulation`, `research`,
`manufacturing`, `industry`, `isolation`. Tier 0 = negligible, 4 = world-leading.

A ninth attribute, **`population`**, is *derived* at load: the number of thresholds in
`balance.population_tiers` that the region's population reaches (0…4). It can be used in scopes like
the other eight but must not appear in the file.

## 3. `world/links.json`

```json
{"links": [{"a": "fx_alder", "b": "fx_birch", "kind": "land"}]}
```

| Field | Type | Required | Rule |
| --- | --- | --- | --- |
| `a`, `b` | region id | yes | both exist; `a` sorts strictly before `b` (so a pair has one spelling) |
| `kind` | string | yes | `land` · `sea` · `air` · `network` |

The link id is derived, not stored: `"<a>|<b>|<kind>"`. It must be unique — two regions may be joined
by several links of different kinds, never by two of the same kind. Links are undirected. The file
order is the iteration order of the simulation and therefore part of the determinism contract.

## 4. `tech/*.json`

```json
{
	"nodes": [
		{
			"id": "fx_reach",
			"tree": "infiltration",
			"tier": 2,
			"cost": 7,
			"grid": [1, 0],
			"requires_any": ["fx_vector_net", "fx_vector_mass"],
			"watched_by": ["public_sentiment"],
			"on_purchase": [],
			"modifiers": [
				{"target": "spread_seed", "op": "mul", "value": 2.0},
				{"target": "footprint", "op": "add", "value": 1.0}
			]
		}
	]
}
```

| Field | Type | Required | Rule |
| --- | --- | --- | --- |
| `id` | id | yes | unique across **all** tech files |
| `tree` | string | yes | `infiltration` · `capabilities` · `evasion` |
| `tier` | int | yes | 1…3 |
| `cost` | int | yes | ≥ 1; the base cost before escalation |
| `grid` | [int, int] | yes | `[column, row]`, column 0…7, row 0…11, **unique within the tree**; a node's column is ≥ the column of every prerequisite, so the interface's lines run left to right. Tier 1 sits in column 0 |
| `requires` | [node id] | no (`[]`) | all must be owned; ids exist (any tree); no self-reference |
| `requires_any` | [node id] | no (`[]`) | if non-empty, at least one must be owned |
| `watched_by` | [faction id] | no (`[]`) | which factions notice the node: `ai_labs` · `governments` · `security_researchers` · `public_sentiment`, no duplicates. Shown as chips; carries no mechanism before M4 |
| `on_purchase` | [effect] | no (`[]`) | §4.4 |
| `modifiers` | [modifier] | no (`[]`) | §4.1 |
| `flags` | [flag] | no (`[]`) | §4.3 |
| `group` | group id | no (`""`) | at most `groups[group].max` nodes of the group may be owned; the group must be declared in some tech file (below) |
| `excludes` | [node id] | no (`[]`) | owning this node closes every listed one for good. **Symmetric:** every node listed must list this one back; no self-reference |
| `deploy` | object | no | `{"kind": <asset kind>, "count": int ≥ 1, "eligible": <eligibility>}` (§8, §9). Buying the node places the assets in a region the player or the bot chooses; the node's `on_purchase` effects then run in that region |
| `ability` | object | no | `{"id": <ability id>, "level": int ≥ 1}` — the ability this node grants (S4.2) |
| `requires_assets` | kind → int ≥ 1 | no (`{}`) | the agent must hold that many of the kind **in total, over all regions**, to buy the node |

A tech file may also carry a `groups` header:

```json
{"groups": {"vectors": {"max": 2}}, "nodes": [ … ]}
```

Group ids are declared **once**, in whichever file wants them, and `max` is ≥ 1. Every node's
`group` must name a declared one.

The prerequisite graph over `requires` ∪ `requires_any` must be acyclic. How a file groups nodes is
free; the `tree` field, not the file name, decides the tree.

**`breakout` is a tier 1 Infiltration node's job:** every one of them grants it, and no node of
another tree may.

### 4.1 Modifier

`{"target": <target>, "op": "add" | "mul", "value": <number>, "scope": <scope>?}`

A stat is computed as **`(base + Σ add) × Π mul`, then clamped** to the target's range. `base` is
`balance.stats[target]`. `add` values are summed in activation order, `mul` values are factors
(`1.25` = +25 %, `0.6` = −40 %) and multiply. `mul` values must be > 0. There is no other operator
and no ordering between sources: the result does not depend on which source came first, apart from
floating-point summation order, which is fixed (activation order).

**Targets v1.** *Regional* targets are evaluated for one region and accept scoped modifiers.
*Global* targets are evaluated once; a scope on them is a validation error.

| Target | Kind | Base | Clamp | Meaning |
| --- | --- | --- | --- | --- |
| `spread_growth` | regional | 1 | 0…20 | multiplier on growth inside the region |
| `spread_seed` | regional | 1 | 0…20 | multiplier on the chance of **being seeded** (evaluated for the target region) |
| `seed_land` `seed_sea` `seed_air` `seed_network` | regional | 1 | 0…20 | the same, for one link kind only |
| `airgap_cross` | regional | 0 | 0…1 | factor applied to the seeding chance into an air-gapped region; 0 = impossible |
| `control_growth` | regional | 1 | 0…20 | multiplier on control gain |
| `yield` | regional | 1 | 0…20 | multiplier on passive Compute from the region |
| `anomaly_value` | regional | 1 | 0…20 | multiplier on the value of anomalies spawned there |
| `anomaly_rate` | regional | 1 | 0…20 | the region's **weight** in the one daily draw that places an anomaly (D4.1 §12); it was a per-region spawn chance until then |
| `harm` | regional | 0 | 0…100 | Harm: deaths per day as a multiple of `harm.daily_rate` |
| `footprint` | global | 0 | 0…100 | Footprint: how visible the agent is |
| `discovery` | global | 1 | 0…20 | multiplier on the daily discovery risk |
| `containment_growth` | global | 1 | 0…20 | multiplier on containment gain |
| `node_cost` | global | 1 | 0.1…10 | multiplier on every node's cost |

**Targets v2** (D3.1). The *System* column names the step that makes the target live; until then it
is **inert**: loaded, validated and evaluated by `ModifierStack`, read by nothing. `ModifierStack`
lists the inert ones in `INERT_TARGETS`, and a system's spec deletes its row from there.

| Target | Kind | Base | Clamp | System | Meaning |
| --- | --- | --- | --- | --- | --- |
| `hardware` | regional | 0 | 0…10 | live | hardware the agent brings to the region; added to the region's hardware in the **yield** sum only, never to `infected_share` |
| `node_cost_infiltration` `node_cost_capabilities` `node_cost_evasion` | global | 1 | 0.1…10 | live | multiplier on the cost of that tree's nodes, on top of `node_cost` |
| `shutdown_survival` | regional | 0 | 0…1 | live | share of penetration the region keeps when a shutdown hits it |
| `emergent_rate` | global | 1 | 0…20 | `emergent` (S4.4) | multiplier on the daily chance of an emergent behaviour |
| `containment_ai_labs` `containment_governments` `containment_researchers` `containment_public` | global | 1 | 0…20 | `ContainmentSystem` (S4.4) | multiplier on that faction's containment gain, after `containment_growth` — the faction's `brake` in `factions.json` |
| `society_pressure` | regional | 0 | 0…100 | `society` (S4.5) | daily pressure on Societal Function in the region |

**Targets v3** (D4.1 §7.5). The three the status system reads; the steps in the *System* column
are the ones that make them live.

| Target | Kind | Base | Clamp | System | Meaning |
| --- | --- | --- | --- | --- | --- |
| `containment_capacity` | regional | 1 | 0…20 | live | multiplier on the region's weight in the containment numerator; the denominator keeps the plain tier weight |
| `penetration_decay` | regional | 0 | 0…1 | live | share of penetration the region loses each day, reduced by `shutdown_survival` |
| `control_decay` | regional | 0 | 0…1 | live | control lost each day, before the day's gain |

An `add` may be negative — the clamp decides what comes of it; only a `mul` of 0 or less is an
error.

Adding a target means: a row here, a base in `balance.stats`, the clamp in `ModifierStack`, and the
one place in a system that reads it. Content must never need a new `if` in a system. Adding an
*inert* target means the same but with an entry in `INERT_TARGETS` and no read site at all.

### 4.2 Scope

Absent = applies to every region (or to the global stat). Otherwise exactly one of:

| Form | Matches |
| --- | --- |
| `{"attr": <attribute>, "min": n}` / `{"attr": …, "max": n}` / both | regions whose tier lies in the inclusive range; at least one of `min`/`max`; `attr` is one of the nine attributes |
| `{"region": <region id>}` | that region |
| `{"continent": <continent id>}` | regions on that continent (must occur in `regions.json`) |
| `{"asset": <asset kind>, "min": n?}` | regions holding at least `n` (default 1) assets of that kind (§8). `min` ≥ 1; there is no `max`. This is the one scope that depends on state rather than on the region's definition, so the modifier stack answers it and `ModifierDef.matches` does not |

Archetype affinity ("favours high-connectivity regions") is expressed this way — there is no
affinity field.

### 4.3 Flags

Boolean unlocks that a source grants while it is active.

| Flag | System | Effect |
| --- | --- | --- |
| `breakout` | live | ends the Boxed phase: seeding across links becomes possible |
| `dormancy` | live | unlocks `set_dormancy` (§4.5) |
| `compute_independent` | `autophagy` (S4.5) | the agent no longer starves when the infrastructure it runs on collapses |
| `legal_standing` | `endings` (S5.6) | reserved |
| `merge_path` | `endings` (S5.6) | reserved: opens the Merge ending |
| `network_presence` | live (S5.1) | the `no_network` hook of an architecture: network links carry the agent only while it is set (`replayability.md` §2.3). Inert on every other architecture |

An unknown flag is a validation error. An inert flag is answered truthfully by
`ModifierStack.has_flag` and asked by nobody; `INERT_FLAGS` names them.

### 4.4 One-shot effects

`"on_purchase": [{"effect": <effect>, …fields}]` — applied once, in list order, when the node is
bought, after its modifiers become active and after it has deployed. Never undone, never part of
the modifier stack, never re-applied on load: a save carries the state they produced.

The same list is used by a status level's `on_start` / `on_end`, an ability's `applies.effects`
and an event option's `effects` (D4.1 §8): one vocabulary, one runner. An effect marked **R** needs
a region — on a node that means the node must also `deploy`, because a node's effects run in the
region it deployed into and in no other.

| Effect | Fields | R | System | Does |
| --- | --- | --- | --- | --- |
| `compute_grant` | `value` ≥ 0, `per_hardware`? | if `per_hardware` | live | `compute` and `compute_earned` both rise by `value`, times the region's hardware when `per_hardware` |
| `containment_rollback` | `value` (0, 1] | | live | every faction: `containment ← containment × (1 − value)`. A threshold that is crossed again is announced again |
| `harm_burst` | `value` (0, 1] | | live | one wave of deaths at once: every region that is not dark, not dormant and infected loses `value × penetration × alive` people; a region that empties goes dark as in `docs/specs/core.md` §7.4 |
| `funding_reset` | `value` (0, 1] | | `EffectRunner` (S4.4) | every faction's preparation is cancelled (`counter_move_cancelled`) and no faction prepares for `round(value × factions.reset_days)` days; a later cooldown is kept (opposition.md §6.5) |
| `destroy_assets` | `kind`, `count` ≥ 0 | R | live | removes `min(count, held)` of the kind; 0 means every one held |
| `grant_assets` | `kind`, `count` ≥ 1 | R | live | the mirror: the region gains that many |
| `seed_neighbours` | `count` ≥ 1 | R | live | seeds the best uninfected neighbours over open links |
| `penetration_mul` | `value` ≥ 0 | R | live | `penetration ← penetration × value` |
| `control_add` | `value` | R | live | `control ← clamp(control + value, 0, 1)` |
| `spread_status` | `status`, `level`?, `days`? | R | live | applies the status to every neighbour over an open link |
| `end_statuses` | `ids`, `global`? | R | live | ends every listed status in the region |
| `apply_status` | `status`, `level`?, `days`?, `global`? | | live | applies it in the context's region, or on the agent when `global` |
| `wipe` | `value` [0, 1] | R | live | a shutdown: `penetration ← penetration × (value + shutdown_survival)` |
| `containment_add` | `faction`, `value` | | live | adds to one faction's containment, or to every one with `"all"` |
| `footprint_pulse` | `value`, `days` ≥ 1, `watched_by`? | | live | a timed Footprint bump with no status behind it |
| `set_flag` | `flag`, `days` ≥ 1 (0 = permanent) | | live | a timed flag, or a story flag that never expires |
| `status_level_add` | `status`, `value`, `global`? | | live (S5.2) | a running status moves by `value` whole levels, clamped to its levels; below 1 it ends. Nothing running, nothing happens |
| `unlock_near_node` | — | | live (S5.2) | of the unowned nodes exactly one `requires` short — that one available itself and placing nothing — the cheapest gets its missing prerequisite owned for free (content order breaks ties) |

`global: true` on `apply_status`, `end_statuses` or `status_level_add` runs it on the agent, so it
needs no region even where the table says R.

A field an effect does not take is an unknown field and therefore an error. A `flag` that collides
with a §4.3 modifier flag is an error.

### 4.5 Commands the content unlocks

`set_dormancy` (`{"region": <region id>, "dormant": <bool>}`) needs the `dormancy` flag. A dormant
region is frozen — no growth, no control, no seeding out, no yield, no anomalies, no deaths — and
leaves the numerator of the infected share while staying in its denominator.

## 5. `balance.json`

Every tunable constant. Systems contain **no magic numbers**: a literal other than 0, 1 or a clamp
bound from §4.1 belongs here. All keys below are required; all numbers are validated as finite, and
as ≥ 0 unless stated. The meaning of each constant is defined by the formula that uses it, in
`docs/specs/core.md` §7.

| Key | Type | Notes |
| --- | --- | --- |
| `stats` | object | one float per target in §4.1 — exactly that key set |
| `population_tiers` | [int × 4] | strictly ascending |
| `spread.base_growth` `.origin_penetration` `.seed_penetration` `.saturation_snap` | float | the last three in (0, 1] |
| `spread.seed_chance` | object | one float in [0, 1] per link kind — exactly the four kinds |
| `control.threshold` `.rate` `.complete` | float | `threshold` in [0, 1); `complete` in (0, 1] |
| `compute.start` `.yield_scale` `.cost_step` | float | |
| `compute.hardware_by_tier` | [float × 5] | index = `compute` tier |
| `anomaly.spawn_chance` `.base_value` `.tier_bonus` `.footprint_bonus` `.footprint_reference` | float | `spawn_chance` in [0, 1] and is rolled **once a day for the whole world** (D4.1 §12), not once per region; `footprint_reference` > 0 |
| `anomaly.max_active` `.lifetime_days` | int | ≥ 1 |
| `milestones` | [milestone] | below |
| `harm.daily_rate` | float | |
| `discovery.scrutiny_per_day` `.per_footprint` `.breadth_rate` `.breadth_free` `.deaths_certain_share` | float | the last two are shares of the world, in [0, 1] |
| `containment.base_rate` | float | the gain per day at pressure 1, capacity 1, brakes 1 (opposition.md §5.4) |
| `containment.brake_floor` | float | in [0, 1]; a faction's brakes (`containment_growth` × its own brake) never go below it — G4, BALANCE §4.3. The test fixtures keep 0 |
| `containment.capacity_weight_by_tier` | [float × 5] | index = the tier of a faction's `capacity_attr`; sum > 0 — one table for all four attributes |
| `containment.thresholds` | [float] | ascending, each in (0, 1); announced once when crossed |
| `factions.prepare_days` `.prepare_min_days` | int | ≥ 1; a move is prepared for `max(min, round(prepare × (1 − containment)))` days (S4.5) |
| `factions.cooldown_days` | int | ≥ 0; days after a move before the faction prepares again (S4.5) |
| `factions.max_active_moves` | int | ≥ 1; world statuses that may stand at once (S4.5) |
| `factions.level_thresholds` | [float] | ascending, each in (0, 1); containment from which a move is at level 2, 3 … (S4.5) |
| `factions.reset_days` | int | ≥ 1; `funding_reset` value 1 is this many days of quiet |
| `factions.protest_deaths_share` | float | in (0, 1]; the Protest's target rule (S4.5) |
| `society.stage_thresholds` | [float] | ascending, each in (0, 100]; a region's stage is how many it has reached (opposition.md §8.2) |
| `society.gain_scale` `.recovery_per_day` `.deaths_weight` | float | ≥ 0; a day's disorder change is `gain_scale × (society_pressure + deaths_weight × deaths share) − recovery_per_day`, clamped to 0…100 |
| `society.stages` | [{`capacity_mul`, `yield_mul`}] | exactly one more than `stage_thresholds`, each in [0, 1]: the humans' containment capacity and the humans' hardware in the yield at that stage |
| `society.autophagy_days` | int | ≥ 1; this many consecutive days of zero income end the run in `lose_autophagy`, unless the flag `compute_independent` is set |
| `phase.open_containment` `.open_world_share` | float | in (0, 1] |
| `headlines.max_per_tick` `.max_per_command` | int | ≥ 1; how many lines one tick or one command may say |
| `headlines.reaction_gap_days` | int | ≥ 0; days between two state-triggered reactions |
| `headlines.filler.gap_days` | {phase id: float > 0} | exactly the four phase ids; days between two filler lines |
| `headlines.filler.per_dark_region` | float | added to the gap per dark region |
| `headlines.filler.silence_dark_regions` | int | ≥ 1; this many dark regions and the filler stops |
| `headlines.filler.silence_deaths_share` | float | in (0, 1]; so does this share of the world dead |
| `results.ashes_share` | float | in (0, 1]; Ascendance above it reads as ashes (m3-screens §7.4) |
| `history.interval_days` | int | ≥ 1; the *initial* days between two samples from the origin (1 since S4.8) |
| `history.max_samples` | int | ≥ 2; past this many samples every second one goes and the stride doubles (analysis.md §3.1) |
| `history.log_max` | int | ≥ 1; the run log keeps its newest this many entries (analysis.md §4.3) |
| `events.opening_chance` | {phase id: float} | exactly the four phase ids, each in [0, 1]; the daily opening roll (`boxed` 0) |
| `events.opening_from_regions` | int | ≥ 1; openings roll only once this many regions were seeded |
| `events.max_open` | int | ≥ 1; how many map events may stand at once |
| `emergent.base_chance` · `.suppress_cost` · `.suppress_step` | float | the daily chance at `emergent_rate` 1 in [0, 1]; the suppression price and its step ≥ 0 (S5.2) |
| `drift.per_kept` · `.per_day` · `.per_suppressed` | float | in [0, 100]: how the Swarm's drift moves (S5.2) |
| `drift.defect_chance` · `.defect_min_penetration` · `.defect_days` | float · float · int | the daily defection chance at drift 100, the penetration a region needs to defect, how long it does (S5.2) |
| `escalation.every_days` · `.hold_days` | int | ≥ 1: the Weapon's climb, and how long Restraint's flag holds it (S5.2) |
| `difficulty.cost_by_control` | float | ≥ 0: Existential's price per share of the world controlled (S5.4) |
| `distributed.floor` · `.start_penetration` · `.hold_regions` | float · float · int | Open Weights: the penetration a wipe cannot go under while the agent holds `hold_regions` regions, and the start's penetration in its six regions (S5.2) |

Milestone: `{"id": <id>, "kind": <kind>, "threshold": <number>, "reward": <float>}`, ids unique.

| Kind | Fires when | Threshold |
| --- | --- | --- |
| `regions_infected` | the number of regions ever seeded (the origin included) reaches it | int ≥ 1 |
| `world_share` | the infected share of the world's hardware reaches it | float in (0, 1] |
| `continent_foothold` | a region is seeded on a continent other than the origin's — **once per continent**; the fired id is `<id>_<continent>` | ignored, write 1 |

## 6. `assets.json`

The four kinds of asset the agent can have standing in a region, and what each is worth where it
stands (D4.1 §6). Required; exactly the four kinds, each once.

```json
{"version": 1, "assets": [
	{"kind": "fleet", "watched_by": ["public_sentiment"], "glyph": "ASSET_FLEET",
	 "modifiers": [{"target": "hardware", "op": "add", "value": 1.0}]}
]}
```

| Field | Type | Required | Rule |
| --- | --- | --- | --- |
| `kind` | id | yes | exactly one of `fleet` · `lab` · `tap` · `office`, each appearing once |
| `glyph` | string | yes | one of `Glyphs.ASSET_NAMES` |
| `watched_by` | [faction id] | no (`[]`) | as on a node; read by S4.4's per-faction Footprint |
| `modifiers` | [modifier] | yes | every target regional, and **no scope**: the loader scopes each one `{"asset": <kind>}`, so a scope in the file would be a second, silent one |

The sources are always active — an asset-scoped modifier matches nothing until a region holds one,
so "active while the agent has at least one" needs no bookkeeping.

## 6a. `statuses.json`

Every timed condition a region or the agent can be under (D4.1 §7.1). Required from S4.2 on.
A status is the only timed thing in the game: the player's abilities apply them, the world's
counter-moves apply them, an event's option applies them.

```json
{"version": 1, "statuses": [
	{"id": "blackout", "origin": "player", "watched_by": ["governments"],
	 "levels": [
		{"days": 20,
		 "modifiers": [{"target": "yield", "op": "mul", "value": 0.5}],
		 "closes_links": ["sea"],
		 "ends_statuses": ["quiet"],
		 "on_start": [{"effect": "spread_status", "status": "blackout", "level": 1, "days": 10}],
		 "on_end": []}
	 ]}
]}
```

| Field | Type | Required | Rule |
| --- | --- | --- | --- |
| `id` | id | yes | unique |
| `origin` | string | yes | `player` or `world`. What the content *means*; which colour a running status takes is read off the **source** it was applied with, so a chain may hand a world status to a region with no faction behind it |
| `levels` | [level] | yes | at least one; level *n* is `levels[n − 1]` |
| `watched_by` | [faction id] | no (`[]`) | as on a node |
| `border` | bool | no (`false`) | draw the region's border in the status colour |
| `blocks` | [status id] | no (`[]`) | status ids the world's moves skip in the region (read from S4.5) |
| `cancellable` | bool | no (`false`) | reserved for the region panel's *Cancel*; no status has it |

A level:

| Field | Type | Required | Rule |
| --- | --- | --- | --- |
| `days` | int ≥ 0 | yes | how long it runs. **0 means standing**: it never expires by itself and only something that ends it can (D4.4) |
| `modifiers` | [modifier] | no (`[]`) | **no scope** — a regional target is scoped to the region when the status is applied, and a status on the agent scopes nothing, which is how a global `spread_growth ×0.5` reaches every region. Unlike a node's, a `mul` of **0** is allowed here: "no capacity at all" is a thing a status says, and the clamp's floor is 0 |
| `on_start` / `on_end` | [effect] | no (`[]`) | §4.4. `on_end` runs **only** on expiry: a status cut short never had its consequence come to pass |
| `closes_links` | [link kind] | no (`[]`) | kinds of the region's links this level closes, or `["all"]` alone. A link stays closed until the last status holding it is gone |
| `ends_statuses` | [status id] | no (`[]`) | ended in the same region, first, when this level starts |

Strings per status: `STATUS_<ID>_NAME` · `_DETAIL` · `_CODE` (the two or three capitals the ring
carries), each in `en` and `de`.

## 6b. `abilities.json`

The player's verbs (D4.1 §9.1). Required from S4.2 on. An ability is bought once as a technology
node and used again and again: it costs Compute, it has a cooldown, and it applies exactly one of
three things.

```json
{"version": 1, "abilities": [
	{"id": "blackout", "target": "region", "cost": 6, "cooldown_days": 45,
	 "eligible": {"infected": true, "status_absent": ["blackout"]},
	 "applies": {"status": "blackout"},
	 "levels_from": ["regional_blackout", "cascading_grid_failure"]}
]}
```

| Field | Type | Required | Rule |
| --- | --- | --- | --- |
| `id` | id | yes | unique |
| `target` | string | yes | `region` or `global` |
| `cost` | number ≥ 0 | yes | Compute, paid on use |
| `cooldown_days` | int ≥ 0 | yes | 0 leaves no cooldown behind at all |
| `eligible` | eligibility | no (`{}`) | §7. A `region` ability only; on a `global` one it is an error |
| `applies` | object | yes | **exactly one** of `status` (a status id), `deploy` (`{"kind", "count" ≥ 1}`; a `region` ability only) or `effects` (§4.4) |
| `levels_from` | [node id] | yes | one node per level, in level order. Each names this ability back through its own `ability` field (§4), at its own position; and from the second on, each must `require` the one before it, or its level could never be reached. **Empty** only for an ability an architecture grants (§6e `abilities`): it has one level and no node |
| `level_cap` | int ≥ 1 | no | the highest status level this ability applies. Without it the status must have at least `levels_from.size()` levels |

The level a run has reached is how many **leading** entries of `levels_from` are owned — which is
why the prerequisite rule above is enforced rather than assumed.

Strings per ability: `ABILITY_<ID>_NAME` · `_DETAIL`, each in `en` and `de`.

## 6c. `events/*.json`

Map events (D4.1 §10, loop-mechanics.md). Every file under `events/` is read in name order, each
`{"version": 1, "events": [ … ]}`; ids are unique **across** files. Three kinds share one format.

```json
{"id": "opening_unattended_cluster", "kind": "opening",
 "pick": {"infected": true, "attr_min": {"compute": 2}},
 "when": {"phase": ["covert", "emergent"]},
 "weight": 3, "max_fires": 2, "cooldown_days": 40, "deadline_days": 20, "default": "leave",
 "options": [
	{"id": "take", "cost": 0, "effects": [{"effect": "compute_grant", "value": 4}]},
	{"id": "seed", "cost": 2, "effects": [{"effect": "seed_neighbours", "count": 1}],
	 "chance": [{"p": 0.3, "effects": [{"effect": "footprint_pulse", "value": 3, "days": 30}]}]},
	{"id": "leave", "cost": 0}]}
```

| Field | Type | Required | Rule |
| --- | --- | --- | --- |
| `id` | id | yes | unique across every events file |
| `kind` | `opening` · `counter_move` · `chain` · `emergent` | yes | `emergent` (S5.2): the agent's own behaviour, never drawn with the openings — once a day from Covert on, with chance `emergent.base_chance × emergent_rate`, one by weight among those whose `when` holds, never while one is open |
| `chain` | id | chain steps | the chain every step of it shares; only on `chain` |
| `start` | bool | no (false) | `chain` only: this step is rolled with the openings. Exactly one per chain |
| `pick` | eligibility · `"same"` · `{"rule": id}` | no (global) | §7; `"same"` only on a chain step that is not the start (the region of the step that scheduled it); `{"rule"}` only on a counter-move, one of `lockdown_target` `richest_infected` `audit_target` `purge_target` `exposure_target` `protest_target` |
| `pick_weight` | `uniform` · `hardware_penetration` | no (`uniform`) | how the region is drawn among the eligible |
| `when` | object | no (`{}`) | the state conditions of §8's `when`, evaluated at the draw; a flag list may name a story flag |
| `weight` | float > 0 | no (1) | its share of the opening draw |
| `max_fires` | int ≥ 0 | no (1 on a chain step, else 0 = unlimited) | |
| `cooldown_days` | int ≥ 0 | no (0) | days between two openings |
| `deadline_days` | int ≥ 1 | yes | the tick whose day reaches it chooses `default` |
| `default` | option id | yes | an option with cost 0 and no `requires` |
| `modal` | bool | no (false) | opens the wire card even with a region |
| `illustration` | id | no | `assets/illustrations/<id>.png`, from M6 |
| `status` · `faction` | status id · faction id | counter-moves only, both required | a status whose `origin` is `world` |
| `flags` | [id] | no | story flags set when it opens; never a modifier flag |
| `options` | [option] | yes | 2…4, ids unique within the event |

Option:

| Field | Type | Required | Rule |
| --- | --- | --- | --- |
| `id` | id | yes | |
| `cost` | number ≥ 0, or `"suppression"` | no (0) | Compute. `"suppression"` only on an `emergent` event: `emergent.suppress_cost × (1 + suppress_step × suppressions so far)`, and choosing it counts one more. Never on the default |
| `requires` | object | no | `owned` `owned_any` `not_owned` [node id] · `flag` [id] (modifier, timed or story flag) · `asset_min` {kind: int} (in the event's region; an error on a global event) · `compute_min` number · `ability` ability id (unlocked) |
| `effects` | [effect] | no | §4.4; an effect that needs a region is an error on a global event |
| `chance` | [{`p` (0, 1], `effects`, `next`?}] | no | every entry is rolled, in order; a successful entry's `next` replaces the option's for this answer (chain steps only; `[]` ends the chain) |
| `flags` | [id] | no | story flags set when chosen |
| `status_level` · `status_days` | int ≥ 0 | no (0) | counter-moves only: 0 = the event's level / the level's days |
| `skip_status` | bool | no | counter-moves only: the move's status is not applied |
| `next` | [{`step` event id, `delay_days` int ≥ 0}] | no | chain steps only; every step a step of the same chain |

A chain step that is not `start` and that no `next` names is an error.

Strings per event: `EVENT_<ID>_TITLE` · `_BODY`, per option `EVENT_<ID>_OPT_<OPTION>` ·
`EVENT_<ID>_RESULT_<OPTION>`, each in `en` and `de`; `{region}` in a text is the event's region.

## 6d. `factions.json`

The four containment tracks (opposition.md §4). `{"version": 1, "factions": [ … ]}` with exactly
the four faction ids **in `Faction.FACTION_IDS` order**: `ai_labs`, `governments`,
`security_researchers`, `public_sentiment`.

```json
{"id": "security_researchers", "capacity_attr": "connectivity", "brake": "containment_researchers",
 "terms": [{"source": "footprint", "weight": 0.15}, {"source": "share", "weight": 1.5}],
 "moves": [{"event": "cm_disclosure_network", "trigger": {"containment": 0.25},
            "variants": {"select": "seeds_by_kind_max", "events": {"sea": "cm_disclosure_sea"}}}]}
```

| Field | Type | Required | Rule |
| --- | --- | --- | --- |
| `id` | faction id | yes | in order, no repeats |
| `capacity_attr` | attribute | yes | a region attribute of §2, `population` included; weighs each region's capacity by `containment.capacity_weight_by_tier` |
| `brake` | target | yes | a global target of §4.1 — the faction's own `containment_<…>` |
| `terms` | [term] | yes, ≥ 1 | the pressure is `1 + Σ weight × value` |
| `moves` | [move] | no, 0…4 | `trigger.containment` ascending where given |

Term: `{"source", "weight" ≥ 0, "tree"?, "kind"?}`, nothing else.

| `source` | Value |
| --- | --- |
| `footprint` | the Footprint this faction sees: a source's additive Footprint counts in full for a faction in its `watched_by`, a quarter for every faction when `watched_by` is empty, not at all otherwise; multipliers for all |
| `harm` | the alive-weighted mean of the scoped Harm over regions not dark |
| `share` | the infected share of the world's hardware |
| `deaths_share` | deaths / world population |
| `seeded_share` | regions ever seeded / regions |
| `owned_nodes` | owned nodes of `tree` (required with this source only) |
| `watched_statuses` | active statuses of `origin` `player` whose `watched_by` names this faction |
| `assets` | the agent's total of `kind` (required with this source only) |

Move: `{"event", "trigger": {"containment"? in (0, 1), "risk"? in (0, 1]}, "variants"?}`. `event`
is a `counter_move` event whose `faction` is this faction; `trigger` needs at least one key
(`risk` is the daily discovery risk, before discovery only). `variants`: `{"select":
"seeds_by_kind_max", "events": {link kind: counter-move event of this faction}}` — a key the
selector produces and the map lacks falls back to `event`. An event named by two factions' moves
is an error; so is a counter-move event no move names. Strings: `FACTION_<ID>` in `en` and `de`.

## 6e. `architectures.json`

What the agent is (`docs/specs/replayability.md` §2, §8.1). **Optional**: a root without it plays
the default architecture `language_model` alone, with no modifiers and no start. With the file,
`language_model` must be in it.

```json
{"version": 1, "architectures": [
	{"id": "embedded", "unlock": {"runs_completed": 2},
	 "modifiers": [{"target": "seed_land", "op": "mul", "value": 1.3}],
	 "start": {"owned": ["logistics_fleets"], "assets": {"fleet": 1}, "seed_top_hardware": 0,
	           "effects": []},
	 "abilities": [],
	 "hook": "no_network"}
]}
```

| Field | Type | Required | Rule |
| --- | --- | --- | --- |
| `id` | id | yes | unique |
| `unlock` | object | no (`{}`) | `{}` or exactly one of `runs_completed` · `wins` (int ≥ 1) · `wins_by_outcome` ({winning outcome id: int ≥ 1}). The profile's business (S5.3); the simulation never reads it |
| `modifiers` | [modifier] | no | §4.1, active from the run's creation under the source `arch:<id>`, first in the stack |
| `start` | object | no | `owned` [node id] — owned at the origin as if bought (cost 0, deploys into the origin, grants their ability); `assets` {kind: int ≥ 1} placed in the origin; `seed_top_hardware` int ≥ 0 (S5.2); `effects` [effect] run in the origin, a region is available |
| `abilities` | [ability id] | no | granted at level 1 without a node |
| `hook` | string | no | one of `drift` · `no_network` · `labs_from_day_one` · `escalation` · `distributed` (§2.2 of the spec; each read in one system) |

The run's architecture is `World.setup.architecture` (save v3); an unknown one refuses the origin
with `setup_invalid`. Strings per architecture: `ARCH_<ID>_NAME` · `_TAGLINE` · `_DETAIL`.

## 6f. `directives.json`

The loadout (`docs/specs/replayability.md` §4, §8.2). **Optional**: a root without it has no
directives. `{"version": 1, "slots": [slot id…], "directives": [{"id", "slot", "modifiers"}]}` —
slots unique, every directive in one of them, every slot with at least one directive, ids unique;
modifiers as §4.1, active under `directive:<id>` after the architecture's. A run names its loadout
in `setup.directives`; two in one slot, or an unknown one, refuses the origin with
`setup_invalid`. Which slots are open is the profile's (`user://profile.json`), never the
simulation's. Strings: `DIRECTIVE_SLOT_<SLOT>`, `DIRECTIVE_<ID>_NAME` · `_DETAIL`.

## 6g. `difficulty.json`

The tiers (`docs/specs/replayability.md` §5, §8.3). **Optional**: a root without it plays every run
at `standard` and refuses any other tier. `{"version": 1, "default": id, "tiers": [{"id",
"start_compute" ≥ 0, "hook" ("" or `cost_by_control`), "modifiers"}]}` — ids unique, `standard`
among them, the default one of them. The tier's modifiers are active under `difficulty:<id>`,
after the architecture's and the loadout's; `start_compute` is added to `compute.start` when the
world is created; `cost_by_control` multiplies every node's price by `1 + difficulty.cost_by_control
× controlled share` (controlled regions over the regions not dark). Strings:
`DIFFICULTY_<ID>_NAME` · `_DETAIL`.

## 7. Eligibility

Where something may be placed, used or picked: a `deploy` site, an ability's target, an event's
pick. Every key is optional and an absent key never fails; the keys are checked in the order below
and the **first** failure is the reason the interface shows.

| Key | Type | Region passes when |
| --- | --- | --- |
| `infected` | bool | `penetration > 0` |
| `not_dark` | bool | not dark. **Always applied**, whether given or not |
| `not_dormant` | bool | not dormant |
| `attr_min` / `attr_max` | attribute → tier 0…4 | every entry holds |
| `asset_min` / `asset_max` | asset kind → int ≥ 0 | every entry holds |
| `status_absent` / `status_present` | [status id] | none / all of them are running there |
| `penetration_min` / `control_min` | float [0, 1] | the value is at least that |
| `continent` | continent id | the region is on it |
| `not_origin` | bool | the region is not the origin |
| `origin` | bool | the region **is** the origin |

`attr_min` above `attr_max` for one attribute, `asset_min` above `asset_max`, a status id in both
lists, and `origin` together with `not_origin` are all errors: a rule that can never hold is a
mistake, not a design.

## 8. `headlines.json`

What the world says about the run (spec `docs/specs/ticker.md` §3.2). One file per root, required.
Root: `{"version": 1, "headlines": [ … ]}`, the array non-empty and in firing order — file order is
the order the system checks them in, and two headlines eligible for the same slot are separated by
`weight`, never by position.

| Field | Type | Required | Rule |
| --- | --- | --- | --- |
| `id` | id | yes | unique; its text is `HEADLINE_<ID>` (§7) |
| `stream` | `consequence` · `reaction` · `filler` | yes | what kind of line it is |
| `register` | `institutional` · `emergency` · `any` | no (`any`) | `emergency` only while the phase is Open, `institutional` only while it is not |
| `on` | object | one of `on`/`when` | event trigger, below. **Never on a `filler`** |
| `when` | object | one of `on`/`when` | state conditions, below; with `on`, both must hold |
| `weight` | float > 0 | no (1) | the share of the choice it takes |
| `chance` | float in (0, 1] | no (1) | rolled per matching event; only with `on` |
| `cooldown_days` | int ≥ 0 | no (0) | days between two fires of this headline |
| `max_fires` | int ≥ 0 | no (0) | 0 = unlimited, 1 = once per run |
| `fallback` | bool | no (false) | eligible only while no ordinary headline is, for the same event; only with `on` |

**`on` — the event trigger.** `event` is required and is one of the catalogue (`core.md` §6.4);
`headline` itself is not allowed. The rest narrow it:

| Field | Type | Matches when |
| --- | --- | --- |
| `data` | object | for every `field → value(s)`: the event carries `field` and its value is one of them. A scalar is a one-element list. Ids are checked against the content: `node`, `region`, `milestone`, `status`, `ability`, `def` (an event id), `option` (an option of the `def` beside it — without a `def` an error), `link_kind`, `cause`, `outcome`, a `phase_changed` `to`/`from`, and a `threshold` against `balance.containment.thresholds` |
| `region_attr_min` `region_attr_max` | attr → tier 0…4 | the event's `region` has that attribute at or above (below) the tier. Only on an event that carries a region |
| `node_tree` | tree id | the event's `node` is in that tree. Only on `node_purchased` |
| `node_tier` | int 1…3 | that node's tier. Only on `node_purchased` |

**`when` — the state conditions.** All keys are ANDed, every key optional, an empty `when` always
true. A state-only headline is checked only once the run has an origin. `_min` is `>=`, `_max` is
`<=`, and a `_min` above its `_max` is an error.

| Key | Type | Reads |
| --- | --- | --- |
| `phase` | [phase id] | the phase is one of them |
| `discovered` | bool | |
| `day_min` `day_max` | int | days since the origin |
| `days_since_discovery_min` | int | never true while undiscovered |
| `share_min` `share_max` | float | the infected share of the world's hardware |
| `regions_min` `regions_max` | int | regions ever seeded |
| `dark_min` `dark_max` | int | dark regions |
| `dormant_min` | int | dormant regions |
| `deaths_share_min` `deaths_share_max` | float | the dead as a share of the world |
| `containment_min` `containment_max` | float | the highest faction containment |
| `footprint_min` `footprint_max` | float | |
| `harm_min` | float | the unscoped `harm` stat |
| `compute_min` `compute_max` | float | |
| `owned` `owned_any` `not_owned` | [node id] | all of them · at least one · none |
| `owned_count_min` | int | nodes bought |
| `flag` `not_flag` | [flag] | all of them set · none set — a modifier flag, a timed flag or a story flag |
| `faction_min` `faction_max` | {faction id: float} | that faction's containment |
| `asset_min` `asset_max` | {kind: int} | the agent's total of that kind |
| `status_active` `status_inactive` | [status id] | each running somewhere · none running anywhere |
| `ability_unlocked` | [ability id] | each at level 1 or more |
| `story_flag` `not_story_flag` | [id] | all set · none set |
| `architecture` | [architecture id] | the run's architecture is one of them (S5.2) |
| `drift_min` | float | the agent's drift, 0…100; 0 on every architecture but Swarm (S5.2) |

Anything else under `on` or `when` is an error. The vocabulary grows by a row here and a row in
`HeadlineConditions`, never by an `if` per headline.

## 9. Localisation keys

`data/loc/strings.csv`, header `keys,en,de`. Keys are `UPPER_SNAKE`, prefixed by domain, and derived
from content ids so that data files never carry text:

| Content | Keys |
| --- | --- |
| region `fx_alder` | `REGION_FX_ALDER` |
| continent `europe` | `CONTINENT_EUROPE` |
| tech node `cloud_federation` | `TECH_CLOUD_FEDERATION_NAME` · `…_EFFECT` · `…_FLAVOUR` — all three required, in `en` **and** `de`, for every shipped node |
| asset kind `fleet` | `ASSET_FLEET_NAME` · `…_PLURAL` |
| status `blackout` | `STATUS_BLACKOUT_NAME` · `…_DETAIL` · `…_CODE` — all three required, in both languages |
| ability `blackout` | `ABILITY_BLACKOUT_NAME` · `…_DETAIL` — both required, in both languages |
| exclusive group `vectors` | `GROUP_VECTORS` |
| headline `seed_first` | `HEADLINE_SEED_FIRST` — required, in `en` **and** `de`, for every shipped headline |
| command failure `insufficient_compute` | `CMD_FAIL_INSUFFICIENT_COMPUTE` |
| interface text | `UI_<SCREEN>_<ELEMENT>` |

Placeholders are named: `{region}`, `{count}` — never positional. A content root without a
`loc/strings.csv` — every test fixture — skips the string check entirely: the fixtures have no
strings and nothing displays them.
