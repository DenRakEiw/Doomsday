# Content schema

The format of every file under `data/` and the modifier vocabulary. **Kept current:** whoever
changes a loader, a format or the vocabulary changes this file in the same commit.
`SchemaValidator` enforces everything stated here; where this file and the validator disagree, that
is a bug in one of them.

Version: **v1** (D1.1 — regions, links, technology nodes, balance). Later specs add sections.

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
| `index` | int | yes | 1…65535, unique, and the set of indices is exactly 1…N with no gaps. **0 is reserved for "no region".** Equals the colour index in the ID map. Stable once published |
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
			"requires_any": ["fx_vector_net", "fx_vector_mass"],
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
| `requires` | [node id] | no (`[]`) | all must be owned; ids exist (any tree); no self-reference |
| `requires_any` | [node id] | no (`[]`) | if non-empty, at least one must be owned |
| `modifiers` | [modifier] | no (`[]`) | §4.1 |
| `flags` | [flag] | no (`[]`) | §4.3 |

The prerequisite graph over `requires` ∪ `requires_any` must be acyclic. How a file groups nodes is
free; the `tree` field, not the file name, decides the tree.

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

Adding a target means: a row here, a base in `balance.stats`, the clamp in `ModifierStack`, and the
one place in a system that reads it. Content must never need a new `if` in a system.

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

Boolean unlocks that a source grants while it is active. v1 vocabulary:

| Flag | Effect |
| --- | --- |
| `breakout` | ends the Boxed phase: seeding across links becomes possible |

An unknown flag is a validation error.

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
| `anomaly.spawn_chance` `.base_value` `.tier_bonus` `.footprint_bonus` `.footprint_reference` | float | `footprint_reference` > 0 |
| `anomaly.max_active` `.lifetime_days` | int | ≥ 1 |
| `milestones` | [milestone] | below |
| `harm.daily_rate` | float | |
| `discovery.scrutiny_per_day` `.per_footprint` `.breadth_rate` `.breadth_free` `.deaths_certain_share` | float | |
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
| tech node `cloud_federation` | `TECH_CLOUD_FEDERATION_NAME` · `…_EFFECT` · `…_FLAVOUR` |
| command failure `insufficient_compute` | `CMD_FAIL_INSUFFICIENT_COMPUTE` |
| interface text | `UI_<SCREEN>_<ELEMENT>` |

Placeholders are named: `{region}`, `{count}` — never positional. The test fixture and the M1
placeholder technology have no strings; nothing displays them.
