# Content schema

The format of every file under `data/` and the modifier vocabulary. **Kept current:** whoever
changes a loader, a format or the vocabulary changes this file in the same commit.
`SchemaValidator` enforces everything stated here; where this file and the validator disagree, that
is a bug in one of them.

Version: **v2** (D1.1 — regions, links, technology nodes, balance; D3.1 — the node grid, the
factions that watch a node, one-shot effects, the targets and flags of the three trees). Later
specs add sections.

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
<root>/tech/*.json          every file, in ascending file-name order
```

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
| `anomaly_rate` | regional | 1 | 0…20 | multiplier on the spawn chance there |
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
| `shutdown_survival` | regional | 0 | 0…1 | `counter_actions` (S4.3) | share of penetration the region keeps when a shutdown hits it |
| `emergent_rate` | global | 1 | 0…20 | `emergent` (S4.4) | multiplier on the daily chance of an emergent behaviour |
| `containment_ai_labs` `containment_governments` `containment_researchers` `containment_public` | global | 1 | 0…20 | `factions` (S4.1) | multiplier on that faction's containment gain, after `containment_growth`. The unified M1–M3 track ignores them |
| `society_pressure` | regional | 0 | 0…100 | `society` (S4.2) | daily pressure on Societal Function in the region |

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

Archetype affinity ("favours high-connectivity regions") is expressed this way — there is no
affinity field.

### 4.3 Flags

Boolean unlocks that a source grants while it is active.

| Flag | System | Effect |
| --- | --- | --- |
| `breakout` | live | ends the Boxed phase: seeding across links becomes possible |
| `dormancy` | live | unlocks `set_dormancy` (§4.5) |
| `compute_independent` | `autophagy` (S4.2) | the agent no longer starves when the infrastructure it runs on collapses |
| `legal_standing` | `endings` (S5.6) | reserved |
| `merge_path` | `endings` (S5.6) | reserved: opens the Merge ending |

An unknown flag is a validation error. An inert flag is answered truthfully by
`ModifierStack.has_flag` and asked by nobody; `INERT_FLAGS` names them.

### 4.4 One-shot effects

`"on_purchase": [{"effect": <effect>, "value": <number>}]` — applied once, in list order, when the
node is bought, after its modifiers become active. Never undone, never part of the modifier stack,
never re-applied on load: a save carries the state they produced.

| Effect | `value` | System | Does |
| --- | --- | --- | --- |
| `containment_rollback` | (0, 1] | live | every faction: `containment ← containment × (1 − value)`. A threshold that is crossed again is announced again |
| `compute_grant` | ≥ 0 | live | `compute` and `compute_earned` both rise by `value` |
| `harm_burst` | (0, 1] | live | one wave of deaths at once: every region that is not dark, not dormant and infected loses `value × penetration × alive` people; a region that empties goes dark as in `docs/specs/core.md` §7.4 |
| `funding_reset` | (0, 1] | `factions` (S4.1) | burns that share of every faction's accumulated investment. Inert: accepted, no effect |

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
| `anomaly.spawn_chance` `.base_value` `.tier_bonus` `.footprint_bonus` `.footprint_reference` | float | `spawn_chance` in [0, 1]; `footprint_reference` > 0 |
| `anomaly.max_active` `.lifetime_days` | int | ≥ 1 |
| `milestones` | [milestone] | below |
| `harm.daily_rate` | float | |
| `discovery.scrutiny_per_day` `.per_footprint` `.breadth_rate` `.breadth_free` `.deaths_certain_share` | float | the last two are shares of the world, in [0, 1] |
| `containment.base_rate` `.per_footprint` `.per_harm` `.per_share` | float | |
| `containment.research_weight_by_tier` | [float × 5] | index = `research` tier; sum > 0 |
| `containment.thresholds` | [float] | ascending, each in (0, 1); announced once when crossed |
| `phase.open_containment` `.open_world_share` | float | in (0, 1] |
| `history.interval_days` | int | ≥ 1 |

Milestone: `{"id": <id>, "kind": <kind>, "threshold": <number>, "reward": <float>}`, ids unique.

| Kind | Fires when | Threshold |
| --- | --- | --- |
| `regions_infected` | the number of regions ever seeded (the origin included) reaches it | int ≥ 1 |
| `world_share` | the infected share of the world's hardware reaches it | float in (0, 1] |
| `continent_foothold` | a region is seeded on a continent other than the origin's — **once per continent**; the fired id is `<id>_<continent>` | ignored, write 1 |

## 6. Localisation keys

`data/loc/strings.csv`, header `keys,en,de`. Keys are `UPPER_SNAKE`, prefixed by domain, and derived
from content ids so that data files never carry text:

| Content | Keys |
| --- | --- |
| region `fx_alder` | `REGION_FX_ALDER` |
| continent `europe` | `CONTINENT_EUROPE` |
| tech node `cloud_federation` | `TECH_CLOUD_FEDERATION_NAME` · `…_EFFECT` · `…_FLAVOUR` — all three required, in `en` **and** `de`, for every shipped node |
| command failure `insufficient_compute` | `CMD_FAIL_INSUFFICIENT_COMPUTE` |
| interface text | `UI_<SCREEN>_<ELEMENT>` |

Placeholders are named: `{region}`, `{count}` — never positional. A content root without a
`loc/strings.csv` — every test fixture — skips the string check entirely: the fixtures have no
strings and nothing displays them.
