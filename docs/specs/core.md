# Spec: simulation core (M1)

**Step:** D1.1 · **Builds:** S1.1, S1.2, S1.3, S1.4, S1.5, S1.8 · **Status:** ready to build

This is the hand-over for the headless simulation core. Each build step reads the sections named in
§2 and nothing else. Data formats and the modifier vocabulary are in
[`data/SCHEMA.md`](../../data/SCHEMA.md), which is part of this spec. File naming, typing and test
conventions are the *Coding standard* in `CLAUDE.md`.

Delivered with this spec, finished, not to be retyped: `data/SCHEMA.md`, `data/balance.json`,
`data/tech/placeholder.json`, and the fixture `tests/fixtures/world_small/` (§9).

---

## 1. Scope

**In:** content loading and validation; the world model; the tick loop, commands, event outbox,
RNG and state hash; spread; the Compute economy, modifiers and purchasing; Harm and population; one
containment track, phases and outcomes; save/load; three bot policies and two headless runners.

**Not in — do not build, do not stub beyond what is stated:** the four factions and their
counter-moves, Societal Function, Harvest, Autophagy as its own outcome, emergent behaviour,
suppression, events and headlines, architectures, directives, difficulty, the Merge and Escape
endings, anything under `game/` or `ui/`, autoloads, localisation. `core/` must not know they are
coming, except in two places: `World.factions` is an array (of one), and the system list in
`Simulation` has comments marking the later slots (§6.2).

`data/tech/placeholder.json` is the fixture technology under `m1_` ids. It exists only so that S1.8
can play the real world to a terminal state; D3.1 replaces it. It has no strings.

## 2. Files per build step

All under `res://`. One class per file, file name = snake_case of the `class_name`.

| Step | Read | Creates |
| --- | --- | --- |
| S1.1 | §3, §4, §9, SCHEMA | `core/content/`: `content_loader.gd`, `content_load_result.gd`, `schema_validator.gd`, `validation_error.gd`, `content_db.gd`, `region_def.gd`, `link_def.gd`, `tech_node_def.gd`, `modifier_def.gd`, `milestone_def.gd`, `balance_def.gd` · `tests/support/fixtures.gd` · `tests/unit/test_content_*.gd` |
| S1.2 | §3, §5, §6 | `core/model/`: `world.gd`, `region.gd`, `link.gd`, `agent.gd`, `faction.gd`, `anomaly.gd`, `history_sample.gd` · `core/`: `simulation.gd`, `sim_system.gd`, `sim_rng.gd`, `sim_event.gd`, `command.gd`, `command_result.gd`, `command_codec.gd` · `core/modifiers/modifier_stack.gd` **as a shell**: the full API of §8, with sources and flags working, but `value()` returning the unmodified base |
| S1.3 | §6.3 (`choose_origin`), §7.1, §7.2 | `core/commands/choose_origin_command.gd` · `core/systems/spread_system.gd` |
| S1.4 | §7.3, §8, §6.3 | `core/modifiers/modifier_stack.gd` (complete) · `core/systems/compute_system.gd` · `core/commands/purchase_node_command.gd`, `collect_anomaly_command.gd` |
| S1.5 | §7.4–§7.8 | `core/systems/`: `population_system.gd`, `containment_system.gd`, `phase_system.gd`, `outcome_system.gd`, `history_system.gd` |
| S1.8 | §10, §11 | `core/save/world_serializer.gd`, `load_result.gd` · `core/policy/`: `policy.gd`, `idle_policy.gd`, `greedy_policy.gd`, `stealth_policy.gd` · `tools/sim_run.gd`, `tools/sim_batch.gd` |

Tests for each step: §12.

## 3. Conventions inside `core/`

- Every class `extends RefCounted` and has a `class_name`. No `Node`, no autoload access, no
  `get_tree()`, no signals, no global `randf()`/`randi()`/`randomize()`. `FileAccess` and
  `DirAccess` are allowed in `ContentLoader` only; `WorldSerializer` works on strings.
- **Definitions** (`*Def`, in `core/content/`) are immutable after load and shared. **State**
  (`core/model/`) is owned by one `World`. State refers to definitions; definitions never refer to
  state.
- **Systems are stateless.** Everything that must survive a tick lives in `World`.
- Typed collections everywhere: `Array[Region]`, `Dictionary[String, float]`.
- **Region index 0 is "no region".** `ContentDB.regions[0]` and `World.regions[0]` are `null`; every
  loop over regions is `for i: int in range(1, world.regions.size())`. A forgotten `1` crashes
  loudly on `null` instead of silently simulating a phantom region.
- **RNG discipline.** The only source of randomness is `world.rng`. The spec states for every roll
  *whether* it happens and *in which order*; a roll that the spec does not mention must not exist,
  and a mentioned roll must not be skipped. `SimRng.chance(p)` always consumes exactly one value.
- Floats are 64-bit; never round state. Rounding is a presentation matter.
- Enum values are serialised as their lower-case id string, never as a number.

## 4. Content (S1.1)

### 4.1 Definitions

Fields are public, typed, and set only by `ContentLoader`.

```gdscript
class_name RegionDef
var index: int
var id: String
var continent: String
var population: int
var air_gapped: bool
var anchor: Vector2i
var attributes: Dictionary[String, int]   # the eight authored tiers plus derived "population"
func attr(attribute: String) -> int        # 0 for an unknown name

class_name LinkDef
const KINDS: Array[String] = ["land", "sea", "air", "network"]
var id: String            # "<a>|<b>|<kind>"
var a: int                # region index
var b: int
var kind: String

class_name ModifierDef
enum Op { ADD, MUL }
enum ScopeKind { NONE, ATTR, REGION, CONTINENT }
var target: String
var op: Op
var value: float
var scope_kind: ScopeKind
var scope_attr: String
var scope_min: int        # 0 when the file gave no "min"
var scope_max: int        # 4 when the file gave no "max"
var scope_region: int     # region index
var scope_continent: String
func matches(region: RegionDef) -> bool   # NONE → true; a null region matches only NONE

class_name TechNodeDef
const TREES: Array[String] = ["infiltration", "capabilities", "evasion"]
var id: String
var tree: String
var tier: int
var cost: int
var requires: Array[String]
var requires_any: Array[String]
var modifiers: Array[ModifierDef]
var flags: Array[String]

class_name MilestoneDef
var id: String
var kind: String          # "regions_infected" | "world_share" | "continent_foothold"
var threshold: float
var reward: float

class_name BalanceDef
# One typed field per constant in SCHEMA §5, named <section>_<key>:
# spread_base_growth: float, anomaly_max_active: int, control_complete: float, …
var stats: Dictionary[String, float]
var population_tiers: Array[int]
var spread_seed_chance: Dictionary[String, float]
var compute_hardware_by_tier: Array[float]
var containment_research_weight_by_tier: Array[float]
var containment_thresholds: Array[float]
var milestones: Array[MilestoneDef]

class_name ContentDB
var regions: Array[RegionDef]                      # regions[i].index == i; regions[0] == null
var region_index_by_id: Dictionary[String, int]
var links: Array[LinkDef]                          # file order
var tech_nodes: Array[TechNodeDef]                 # tech files by name, then order in file
var tech_by_id: Dictionary[String, TechNodeDef]
var balance: BalanceDef
var population_total: float                        # Σ RegionDef.population
var content_hash: String
func region_by_id(id: String) -> RegionDef         # null if unknown
func tech(id: String) -> TechNodeDef               # null if unknown
```

`content_hash`: SHA-256 (`String.sha256_text()`) of the concatenation of
`JSON.stringify(parsed, "", true, true)` for `balance.json`, `regions.json`, `links.json` and then
each tech file in load order. Whitespace and key order in the files therefore do not matter.

### 4.2 Loading and validation

```gdscript
class_name ValidationError
var file: String      # path as given to the loader
var path: String      # "regions[2].attributes.compute", "" for whole-file problems
var message: String   # English, for developers; never shown to players
func _to_string() -> String   # "<file>: <path>: <message>"

class_name ContentLoadResult
var db: ContentDB                     # null if errors is not empty
var errors: Array[ValidationError]
func ok() -> bool

class_name ContentLoader
static func load_root(root: String) -> ContentLoadResult
static func load_from_dicts(balance: Dictionary, regions: Dictionary, links: Dictionary,
		tech_files: Array[Dictionary], label: String = "memory") -> ContentLoadResult

class_name SchemaValidator
# Static functions, one per file kind, each appending to an errors array. The split into
# functions is the builder's choice; the contract is the behaviour below.
```

Behaviour:

1. Files are read with `FileAccess.get_file_as_string` and parsed with a `JSON` instance so that a
   syntax error yields one `ValidationError` carrying the line (`path` = `"line <n>"`). **Never
   `load()`, never `ResourceLoader`.** A missing required file is one error. A missing or empty
   `tech/` directory is valid (zero nodes).
2. **All errors are collected**; validation never stops at the first and never crashes on
   malformed input (every access is type-checked before it is cast). A structural error in one
   entry skips cross-reference checks *for that entry* only.
3. Order: `balance.json` → `regions.json` (needs `population_tiers`) → `links.json` → tech files.
   Then cross-file checks: link endpoints, scope regions and continents, prerequisite ids, cycles.
   If `balance.json` is broken, the other files are still validated structurally.
4. Definitions are built only if there are zero errors.
5. Cycle detection is a depth-first search over `requires` ∪ `requires_any`; one error per cycle
   found, at the path of the first node of the cycle in file order, naming the cycle's ids.

Error classes the tests cover (each must name the right `file` and `path`): JSON syntax; missing
file; missing field; wrong type; fractional number in an integer field; value out of range; unknown
field; bad id syntax; duplicate id / index / link id; index gap or index 0; dangling region id in a
link; `a` not before `b`; unknown link kind; unknown tree, target, op, flag, attribute; scope on a
global target; scope with neither `min` nor `max`; `mul` value ≤ 0; dangling or self prerequisite;
prerequisite cycle; `stats` key set not equal to the target list; array of the wrong length;
non-ascending `population_tiers`.

## 5. Model (S1.2)

```gdscript
class_name Region
var def: RegionDef
var penetration: float = 0.0   # [0, 1] share of the region's hardware the agent runs on
var control: float = 0.0       # [0, 1] hold over the region's infrastructure
var alive: float               # people; starts at def.population
var deaths: float = 0.0
var seeded_day: int = -1       # day of first infection; -1 = never
var air_gapped: bool           # starts at def.air_gapped
var dark: bool = false         # depopulated: no hardware, no people, inert (§7.4)

class_name Link
var def: LinkDef
var open: bool = true          # nothing in M1 closes links; tests and M4 do

class_name Agent
var compute: float = 0.0
var compute_earned: float = 0.0        # lifetime total, never decreases
var origin: int = 0                    # region index; 0 = not chosen
var owned_nodes: Array[String] = []    # purchase order

class_name Faction
var id: String                 # M1: exactly one, "unified"
var containment: float = 0.0   # [0, 1]

class_name Anomaly
var id: int
var region: int                # region index
var value: float
var spawn_day: int
var expires_day: int           # removed by the tick whose day >= expires_day

class_name HistorySample       # fields: §7.8; to_dict()/from_dict()

class_name World
enum Phase { BOXED, COVERT, EMERGENT, OPEN }
enum Outcome { NONE, WIN_EXTINCTION, WIN_ASCENDANCE, LOSE_CONTAINED, LOSE_NO_COMPUTE }
const PHASE_IDS: Array[String] = ["boxed", "covert", "emergent", "open"]
const OUTCOME_IDS: Array[String] = ["none", "win_extinction", "win_ascendance",
		"lose_contained", "lose_no_compute"]

var day: int = 0
var origin_day: int = -1
var rng: SimRng
var phase: Phase = Phase.BOXED
var outcome: Outcome = Outcome.NONE
var discovered: bool = false
var discovery_day: int = -1
var agent: Agent
var regions: Array[Region]             # regions[0] == null
var links: Array[Link]                 # same order as ContentDB.links
var factions: Array[Faction]
var anomalies: Array[Anomaly]          # spawn order
var next_anomaly_id: int = 1
var milestones_fired: Array[String]    # firing order
var history: Array[HistorySample]
var modifiers: ModifierStack           # derived, not serialised (§8)

static func create(db: ContentDB, seed_value: int) -> World
static func from_dict(d: Dictionary, db: ContentDB) -> World   # null on any missing or ill-typed field
func to_dict() -> Dictionary
func state_hash() -> String
func check_invariants() -> Array[String]                       # empty = healthy

# Queries used by several systems — defined here so they are computed one way only.
func infected_share(db: ContentDB) -> float
func seeded_count() -> int
func alive_total() -> float
func deaths_total() -> float
func footprint() -> float      # modifiers.value("footprint")
func anomaly_in_region(region_index: int) -> Anomaly   # null if none
```

`create` builds one `Region` per definition, one `Link` per definition, one `Faction` `"unified"`,
an `Agent` with `compute = balance.compute_start`, a `ModifierStack` over `balance.stats`, and a
`SimRng` from the seed.

**`infected_share`** = Σ `hardware(r) × penetration(r)` / Σ `hardware(r)`, both sums over regions
that are not dark, `hardware(r) = balance.compute_hardware_by_tier[r.def.attr("compute")]`; 0 if
the denominator is 0. **`seeded_count`** = regions with `seeded_day >= 0`. `alive_total` and
`deaths_total` sum over all regions in index order.

### 5.1 `to_dict` — also the `world` block of a save

```json
{
	"day": 120, "origin_day": 0,
	"rng": {"seed": "1", "state": "-6044729461038352412"},
	"phase": "covert", "outcome": "none",
	"discovered": false, "discovery_day": -1,
	"agent": {"compute": "400c000000000000", "compute_earned": "4034800000000000",
		"origin": "fx_alder", "owned_nodes": ["fx_vector_net"]},
	"regions": [{"id": "fx_alder", "penetration": "3fed1eb851eb851f",
		"control": "3fc999999999999a", "alive": "418c9c3800000000",
		"deaths": "0000000000000000", "seeded_day": 0, "air_gapped": false, "dark": false}],
	"closed_links": ["fx_alder|fx_elm|air"],
	"factions": [{"id": "unified", "containment": "0000000000000000"}],
	"anomalies": [{"id": 3, "region": "fx_alder", "value": "4008000000000000",
		"spawn_day": 110, "expires_day": 130}],
	"next_anomaly_id": 4,
	"milestones_fired": ["regions_2"],
	"history": [{"day": 7, "…": "…"}]
}
```

That example reads 3.5 Compute, 20.5 earned, penetration 0.91, control 0.2, 60 000 000 alive and an
anomaly worth 3.0.

**Every `float` is written as its IEEE-754 bits** — 16 lower-case hex characters, big-endian,
`FloatBits.to_hex` (`core/save/float_bits.gd`) — because Godot 4.7 cannot read a double back out of
JSON: full precision writes every digit, but the parser loses the last bit of most values below 0.1,
and so do `String.to_float`, `str_to_var` and `String.num_scientific`. Whole numbers, ids, flags and
the RNG strings stay readable. `from_dict` accepts the bit form **and** a plain JSON number, so
hand-written fixtures and saves written before S1.P keep loading; anything else in a float field is
a refusal, not a zero. `HistorySample.to_dict` follows the same rule. *(Decided at G1, built in
S1.P.)*

Regions and links are referred to **by id**, never by index. `regions` lists every region in index
order. `agent.origin` is `""` before the origin is chosen. `from_dict` casts every integer
(`int(d["day"])`), requires `regions` to match the content exactly (same ids, same order) and
returns `null` otherwise; it does **not** build `modifiers` — `Simulation.rebuild_modifiers()` does.

**`state_hash`** = `JSON.stringify(to_dict(), "", true, true).sha256_text()` — no indent, sorted
keys, full precision. Two worlds are equal iff their hashes are.

**`check_invariants`** reports, as English sentences: `penetration`, `control`, `containment`
outside [0, 1] or not finite; `alive < 0`; `|alive + deaths − def.population| > 0.5`; `compute < 0`
or not finite; `dark` with `penetration != 0` or `alive != 0`; two anomalies in one region; more
anomalies than `anomaly_max_active`; an anomaly in a dark region; an owned node unknown to the
content; `discovered` with `discovery_day < 0`; `phase` behind what §7.6 requires.

## 6. Simulation (S1.2)

### 6.1 RNG and events

```gdscript
class_name SimRng
static func from_seed(seed_value: int) -> SimRng
static func from_strings(seed_text: String, state_text: String) -> SimRng
func seed_string() -> String     # str(seed)
func state_string() -> String    # str(state)
func randf() -> float            # [0, 1]
func randi_range(from: int, to: int) -> int
func chance(p: float) -> bool    # randf() < p — ALWAYS consumes exactly one value
```

Wraps one `RandomNumberGenerator`. `from_strings` sets `seed` **first**, then `state` (assigning
the seed resets the state). Strings round-trip through `String.to_int()`; both values are signed
64-bit and must never pass through a JSON number or a float.

```gdscript
class_name SimEvent
var type: String
var day: int
var data: Dictionary        # plain values only: String, int, float, bool
func to_dict() -> Dictionary
```

### 6.2 `Simulation`

```gdscript
class_name SimSystem
func tick(world: World, db: ContentDB, events: Array[SimEvent]) -> void   # base: does nothing

class_name Simulation
var db: ContentDB
var world: World
var systems: Array[SimSystem]        # the fixed order below; tests may append a probe system
var outbox: Array[SimEvent]          # events of the most recent tick()
var command_log: Array[Command]      # accepted commands only, in order, each with its day

static func create(db: ContentDB, seed_value: int) -> Simulation
static func from_world(db: ContentDB, world: World, log: Array[Command]) -> Simulation
static func replay(db: ContentDB, seed_value: int, log: Array[Command], until_day: int) -> Simulation
func tick() -> bool
func apply(command: Command) -> CommandResult
func can_apply(command: Command) -> String      # failure reason, "" if it would be accepted
func node_cost(node_id: String) -> float        # §7.3; -1.0 for an unknown id
func available_nodes() -> Array[TechNodeDef]    # not owned, prerequisites met; ContentDB order
func rebuild_modifiers() -> void                # clear, then add "tech:<id>" per owned node in order
func state_hash() -> String                     # world.state_hash()
```

**`tick()`:** if `world.outcome != NONE`, return `false` and change nothing. Otherwise clear
`outbox`, `world.day += 1`, run every system in order with `outbox` as `events`, return `true`.

**System order** — an explicit `Array[SimSystem]` built in `_init`, in this order, with one comment
line per later slot so that M4 knows where its systems go:

```
(commands — applied between ticks, see 6.3)
SpreadSystem            S1.3
ComputeSystem           S1.4
PopulationSystem        S1.5
# slot: SocietalFunctionSystem (M4)
ContainmentSystem       S1.5
# slot: CounterActionSystem (M4)
# slot: BehaviourSystem (M4)
# slot: EventSystem (M4)
PhaseSystem             S1.5
OutcomeSystem           S1.5
HistorySystem           S1.5
```

S1.2 ships the list empty; each later step appends its systems at the right position. `tick()`
**always** advances the day, also before an origin is chosen — systems simply find nothing to do
(§7). Drivers choose the origin on day 0 before the first tick; the core does not enforce it.

**`replay`:** create from the seed; loop: apply every logged command whose `day == world.day`, in
log order; stop if `world.day == until_day` or the game is over; `tick()`. A command that is
rejected during replay is a determinism failure: `push_error` and return `null`.

### 6.3 Commands

There is no queue. `apply()` runs between ticks and takes effect immediately, which is what
"commands first" in the tick order means: everything applied while `world.day == d` is visible to
every system of the tick that produces day `d + 1`.

```gdscript
class_name Command
var day: int = -1                                   # set by Simulation.apply on acceptance
func type_id() -> String                            # "choose_origin" …
func validate(sim: Simulation) -> String            # failure reason or ""
func execute(sim: Simulation, events: Array[SimEvent]) -> void
func to_dict() -> Dictionary                        # {"type", "day", …fields}

class_name CommandResult
var ok: bool
var reason: String               # "" when ok
var events: Array[SimEvent]      # what the command caused; NOT put in the outbox

class_name CommandCodec
static func from_dict(d: Dictionary) -> Command     # null for an unknown type or bad fields
```

**`apply(command)`:** `reason = can_apply(command)`; if not empty → `CommandResult` with
`ok = false`, nothing changes, nothing is logged. Otherwise set `command.day = world.day`, call
`execute` with a fresh events array, append the command to `command_log`, return the result.
`can_apply` returns `"game_over"` if `world.outcome != NONE`, else `command.validate(self)`.
Command events travel in the result, tick events in the outbox; the `Game` autoload (S2.1) re-emits
both. Nothing is ever emitted twice, and nothing accumulates when nobody listens.

Checks run in the order listed; the first failure is the reason.

| Command · `type_id` · fields | Checks → reason | Effect |
| --- | --- | --- |
| `ChooseOriginCommand` · `choose_origin` · `region: String` (region id) | origin already set → `origin_already_chosen` · unknown id → `invalid_region` · region air-gapped or `compute` tier 0 → `region_not_eligible` | `agent.origin`, `world.origin_day = day`; region: `penetration = spread_origin_penetration`, `seeded_day = day`. Event `origin_chosen` |
| `PurchaseNodeCommand` · `purchase_node` · `node: String` | no origin → `no_origin` · unknown → `unknown_node` · owned → `already_owned` · any `requires` missing, or `requires_any` non-empty with none owned → `missing_prerequisite` · `compute < node_cost` → `insufficient_compute` | `compute -= cost`; append to `owned_nodes`; `modifiers.add_source("tech:<id>", node.modifiers, node.flags)`. Event `node_purchased` |
| `CollectAnomalyCommand` · `collect_anomaly` · `anomaly: int` | no origin → `no_origin` · no such active anomaly (never existed, expired, collected) → `unknown_anomaly` | `compute` and `compute_earned` `+= value`; remove the anomaly. Event `anomaly_collected` |

Constructors take the fields (`ChooseOriginCommand.new("fx_alder")`). Commands carry ids, not
indices, so logs survive a re-indexed world.

### 6.4 Event catalogue v1

`day` is always `world.day` at emission. Region values are region **ids**.

| `type` | `data` | Emitted by |
| --- | --- | --- |
| `origin_chosen` | `region` | command |
| `node_purchased` | `node`, `cost: float` | command |
| `anomaly_collected` | `anomaly: int`, `region`, `value: float` | command |
| `region_seeded` | `region`, `from`, `link_kind` | Spread |
| `region_controlled` | `region` | Spread — the tick `control` first reaches `control_complete` |
| `anomaly_spawned` | `anomaly`, `region`, `value`, `expires_day` | Compute |
| `anomaly_expired` | `anomaly`, `region` | Compute, Population |
| `milestone_reached` | `milestone` (fired id), `reward` | Compute |
| `region_depopulated` | `region` | Population |
| `discovered` | `cause`: `"scrutiny"` \| `"deaths"` | Containment |
| `containment_threshold` | `faction`, `threshold: float` | Containment |
| `phase_changed` | `from`, `to` (phase ids) | Phase |
| `outcome_reached` | `outcome` (outcome id) | Outcome |

## 7. Systems and formulas

`b` is `db.balance`; `stat(t, r)` is `world.modifiers.value(t, r.def)` and `stat(t)` is
`world.modifiers.value(t)`. "In index order" means region index 1…N. Every system returns at once
if `agent.origin == 0`. Until S1.4 lands, `stat` returns the base — S1.3's tests are written
against that and stay valid.

### 7.1 Spread — growth and control (S1.3)

**A. Growth.** For each region in index order, not dark, `penetration > 0`:

```
p ← min(1, p + b.spread_base_growth × stat("spread_growth", r) × p × (1 − p))
if p ≥ b.spread_saturation_snap:  p ← 1
```

**B. Seeding** (§7.2) — after all growth.

**C. Control.** For each region in index order, not dark, `p > b.control_threshold`:

```
control ← min(1, control + b.control_rate × (p − threshold) / (1 − threshold) × stat("control_growth", r))
```

Emit `region_controlled` if `control` was below `b.control_complete` before and is not now.

### 7.2 Spread — seeding across links (S1.3)

Runs only if `world.modifiers.has_flag("breakout")` — this is what "Boxed" means mechanically.
(Until S1.4 nothing can be purchased: S1.3's tests grant the flag through
`world.modifiers.add_source("test", [], ["breakout"])`, which the shell from S1.2 supports.)

For each link in `world.links` order, if `open`: for `(src, dst)` first `(a, b)`, then `(b, a)`:
the pair is **eligible** if neither is dark, `src.penetration > 0` and `dst.penetration == 0`.

```
chance = b.spread_seed_chance[kind] × src.penetration
         × stat("spread_seed", dst) × stat("seed_" + kind, dst)
if dst.air_gapped:  chance ×= stat("airgap_cross", dst)
chance = clamp(chance, 0, 1)
```

**Roll `rng.chance(chance)` iff `chance > 0`.** Successes are collected and applied after the loop,
so a region seeded today cannot seed another today. If several pairs hit the same `dst`, the first
in loop order wins (the others have still rolled). Applying: `dst.penetration =
b.spread_seed_penetration`, `dst.seeded_day = day`, event `region_seeded`.

Consequences to rely on: an unlinked region or one behind closed links is never seeded; an
air-gapped region is never seeded while `airgap_cross` is 0, and consumes no roll.

### 7.3 Compute (S1.4)

**Cost of a node:** `maxf(1, ceilf((node.cost + b.compute_cost_step × owned_nodes.size()) ×
stat("node_cost")))`. Every purchase therefore raises the price of everything else by one.

Each tick, in this order:

**A. Yield.** `income = b.compute_yield_scale × Σ hardware(r) × r.penetration × stat("yield", r)`
over regions not dark, in index order. Add to `compute` and `compute_earned`.

**B. Expiry.** Remove every anomaly with `expires_day <= day`, in list order, emitting
`anomaly_expired`.

**C. Spawning.** In index order; **stop** as soon as `anomalies.size() >= b.anomaly_max_active`;
skip regions that are dark, have `penetration <= 0`, or already hold an anomaly.
`chance = clamp(b.anomaly_spawn_chance × stat("anomaly_rate", r), 0, 1)`; roll iff `chance > 0`.
On success:

```
value = b.anomaly_base_value × (0.5 + b.anomaly_tier_bonus × r.def.attr("compute"))
        × (1 + b.anomaly_footprint_bonus × min(1, footprint / b.anomaly_footprint_reference))
        × stat("anomaly_value", r)
```

`id = next_anomaly_id` (then increment), `spawn_day = day`, `expires_day = day +
b.anomaly_lifetime_days`. Event `anomaly_spawned`. Visibility pays: the Footprint term is the
tension PLAN §3.2 asks for.

**D. Milestones**, in `b.milestones` order. `regions_infected`: `seeded_count() >= threshold`.
`world_share`: `infected_share() >= threshold`. Both fire once, recording their `id`.
`continent_foothold`: for each region in index order with `seeded_day >= 0` whose continent differs
from the origin's, fired id `"<id>_<continent>"`, once each. Firing adds `reward` to `compute` and
`compute_earned`, appends the fired id to `milestones_fired`, emits `milestone_reached`.

### 7.4 Harm and population (S1.5)

For each region in index order, not dark, `alive > 0`:

```
d = min(alive, b.harm_daily_rate × stat("harm", r) × r.penetration × r.def.population)
alive −= d;  deaths += d
if alive < 1:  deaths += alive;  alive = 0;  → the region goes dark
```

Deaths are linear in the *initial* population, so a saturated region at Harm `h` empties in
`1 / (daily_rate × h)` days (500 days at Harm 1, 125 at Harm 4) instead of decaying forever.

**Going dark:** `dark = true`, `penetration = 0`; `control` keeps its value; an anomaly in the region
is removed with `anomaly_expired`; event `region_depopulated`. A dark region is inert for good: no
growth, no seeding into, out of or through it, no yield, no anomalies, no research capacity, left
out of `infected_share`, and counted as *satisfied* for Ascendance. This is the seed of Autophagy:
kill a region before the infection has moved on and the route is gone.

### 7.5 Discovery and containment (S1.5)

`share = world.infected_share(db)`, `fp = world.footprint()`.

**Not yet discovered:**

1. If `deaths_total() / db.population_total >= b.discovery_deaths_certain_share` → discovered,
   cause `"deaths"`, **no roll**.
2. Else `risk = clamp((b.discovery_scrutiny_per_day × (day − origin_day) + b.discovery_per_footprint
   × fp + b.discovery_breadth_rate × max(0, share − b.discovery_breadth_free)) × stat("discovery"),
   0, 1)`; roll iff `risk > 0`; success → cause `"scrutiny"`.

On discovery: `discovered = true`, `discovery_day = day`, event `discovered`. Containment does not
grow on the day of discovery. The scrutiny term grows with time, so even a perfectly quiet agent is
found (median around day 340 at the starting values) — a run cannot stall.

**Discovered:** for each faction:

```
capacity = Σ w(r) × (r.alive / r.def.population) × (1 − r.control)  /  Σ w(r)
           with w(r) = b.containment_research_weight_by_tier[r.def.attr("research")], all regions
gain = b.containment_base_rate
       × (1 + b.containment_per_footprint × fp + b.containment_per_harm × stat("harm")
            + b.containment_per_share × share)
       × capacity × stat("containment_growth")
containment ← min(1, containment + gain)
```

`stat("harm")` without a region is the unscoped Harm. For each value in
`b.containment_thresholds` that lies in `(old, new]`, emit `containment_threshold`. Containment
never falls in M1. Killing or controlling the regions that do the research is what slows it — the
race both win conditions are built on.

### 7.6 Phases (S1.5)

```
target = OPEN      if discovered and (max containment ≥ b.phase_open_containment
                                      or share ≥ b.phase_open_world_share)
         EMERGENT  if discovered
         COVERT    if has_flag("breakout")
         BOXED     otherwise
if target > phase:  emit phase_changed(from, to);  phase = target
```

The phase never regresses and may skip steps (discovered while Boxed → Emergent).

### 7.7 Outcomes (S1.5)

First match wins — a win beats a loss on the same tick:

1. `alive_total() <= 0` → `WIN_EXTINCTION`
2. at least one region is not dark, and every region is dark or has `control >=
   b.control_complete` → `WIN_ASCENDANCE`
3. any faction's `containment >= 1` → `LOSE_CONTAINED`
4. no region has `penetration > 0` → `LOSE_NO_COMPUTE`

Set `world.outcome`, emit `outcome_reached`. From then on `tick()` returns `false` and every command
is rejected with `game_over`.

### 7.8 History (S1.5)

If `day % b.history_interval_days == 0` **or** the outcome was just set, append a `HistorySample`:
`day: int`, `compute: float`, `compute_earned: float`, `seeded: int`, `share: float`,
`alive: float`, `deaths: float`, `containment: float` (max over factions), `footprint: float`,
`phase: String`. No events.

## 8. Modifiers (S1.4)

```gdscript
class_name ModifierStack
const CLAMPS: Dictionary[String, Vector2]      # target → (min, max), the table in SCHEMA §4.1
func _init(bases: Dictionary[String, float]) -> void
func add_source(source_id: String, modifiers: Array[ModifierDef], flags: Array[String]) -> void
func remove_source(source_id: String) -> void  # unknown id: no-op
func has_source(source_id: String) -> bool
func clear() -> void
func value(target: String, region: RegionDef = null) -> float
func has_flag(flag: String) -> bool
```

`value` = `clamp((base + Σ add) × Π mul)` over every modifier of every active source for which
`modifier.target == target and modifier.matches(region)`, sources in activation order, modifiers in
definition order. With `region == null` only unscoped modifiers apply. An unknown target is a
programming error: `push_error` and return 0. Adding an existing `source_id` replaces it in place.

The stack is rebuilt, never saved. Keep a per-target index so `value` touches only the modifiers of
that target; do not cache results across calls unless profiling (S1.8 budget, §11.3) demands it.

A source is anything that carries modifiers: in M1 only `tech:<node id>`; later `directive:…`,
`architecture:…`, `difficulty:…`, `behaviour:…`. None of them needs a change here.

## 9. The fixture world

`tests/fixtures/world_small/` — a content root like `res://data`. **Frozen:** tests depend on its
shape and on its own `balance.json`, which is deliberately a *copy* so that retuning the game never
breaks a unit test. Change it only through a spec.

| # | id | continent | population (tier) | compute | conn. | reg. | research | role |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | `fx_alder` | west | 60 M (2) | 4 | 4 | 3 | 4 | the hub and default origin |
| 2 | `fx_birch` | west | 25 M (2) | 2 | 3 | 2 | 1 | land neighbour |
| 3 | `fx_cedar` | west | 120 M (3) | 1 | 1 | 0 | 0 | populous, poor, end of a land chain |
| 4 | `fx_dogwood` | east | 40 M (2) | 3 | 3 | 4 | 2 | second continent; the only door to `fx_fir` |
| 5 | `fx_elm` | east | 2 M (0) | 1 | 1 | 1 | 0 | **the island** — sea and air links only |
| 6 | `fx_fir` | east | 8 M (1) | 3 | 0 | 4 | 3 | **air-gapped**, one land link |

```
fx_cedar ─land─ fx_birch ─land─ fx_alder ─network─ fx_dogwood ─land─ fx_fir (air-gapped)
                fx_birch ─────────sea───────────── fx_dogwood
                                fx_alder ─air─ fx_elm ─sea─ fx_dogwood
```

Links in file order: alder–birch land · birch–cedar land · alder–dogwood network · birch–dogwood
sea · dogwood–elm sea · alder–elm air · dogwood–fir land.

Technology (`tech/fixture.json`): `fx_vector_net` and `fx_vector_mass` (tier 1, `breakout`, a
scoped `spread_growth` each — connectivity ≥ 3, population ≥ 3) · `fx_reach` (`requires_any` either
vector; `spread_seed` ×2) · `fx_bridge` (requires `fx_reach`; `airgap_cross` +0.5) ·
`fx_efficiency` (`yield` ×1.5) · `fx_grip` (`control_growth` ×3) · `fx_harm_1` (`harm` +1) ·
`fx_harm_2` (**cross-tree**: requires `fx_harm_1` and `fx_reach`; `harm` +3) · `fx_quiet`
(`containment_growth` ×0.6, `discovery` ×0.5). Footprint adds: reach 1, bridge 1, grip 2, harm_1 3,
harm_2 5.

`tests/support/fixtures.gd` (`class_name Fixtures`): `static func db() -> ContentDB` (loads once,
asserts no errors), `static func sim(seed_value: int = 1) -> Simulation`,
`static func sim_with_origin(region_id: String = "fx_alder", seed_value: int = 1) -> Simulation`,
`static func grant(sim: Simulation, compute: float) -> void`, `static func buy(sim: Simulation,
node_ids: Array[String]) -> void` (asserts each purchase is accepted). Tests may write state
directly to set up a situation; nothing outside `tests/` may.

**Outcome recipes** — checked with a throwaway prototype of §7 on 100 seeds each, every seed gave
the stated outcome. Origin `fx_alder`, `grant` 1000 Compute first, then tick until the game is over
(fail the test after 4000 days):

| Outcome | Script | Typical length |
| --- | --- | --- |
| `win_ascendance` | buy `fx_vector_net`, `fx_reach`, `fx_bridge`, `fx_grip`, `fx_quiet` on day 0 | 300–570 days |
| `win_extinction` | buy `fx_vector_net`, `fx_reach`, `fx_bridge`, `fx_quiet` on day 0; tick until every region has `seeded_day >= 0`; then buy `fx_harm_1`, `fx_harm_2` | 330–510 days |
| `lose_no_compute` | set every link `open = false`; buy `fx_vector_net`, `fx_reach`, `fx_harm_1`, `fx_harm_2`, `fx_quiet` on day 0 | about 185 days |
| `lose_contained` | buy nothing | 1200–2300 days |

If a recipe fails on seed 1 under Godot's generator, try seeds 2 and 3 before suspecting the
recipe; if it fails on all three, the implementation differs from §7 — find that first.

## 10. Save format v1 (S1.8)

```json
{
	"format": "doomsday-save",
	"version": 1,
	"build": "0.1.0",
	"content_hash": "9f2c…",
	"seed": "1",
	"world": { "…": "World.to_dict(), §5.1" },
	"commands": [{"type": "choose_origin", "day": 0, "region": "fx_alder"}]
}
```

`build` is the project setting `application/config/version`. Written with
`JSON.stringify(d, "\t", true, true)`.

```gdscript
class_name LoadResult
var sim: Simulation             # null unless ok
var reason: String              # "" when ok
var content_mismatch: bool      # loaded, but content_hash differs: a replay would not reproduce
func ok() -> bool

class_name WorldSerializer
const FORMAT: String = "doomsday-save"
const CURRENT_VERSION: int = 1
static func to_json(sim: Simulation) -> String
static func from_json(text: String, db: ContentDB) -> LoadResult
static func migrate(save: Dictionary, migrations: Dictionary[int, Callable]) -> String  # reason or ""

class_name FloatBits                                  # S1.P, the float form of §5.1
const LENGTH: int = 16
static func to_hex(value: float) -> String            # 16 lower-case hex characters, big-endian
static func from_hex(text: String) -> float
static func from_variant(value: Variant) -> float     # the bit form or a plain JSON number
static func is_readable(value: Variant) -> bool       # exactly what from_variant can read
```

`from_json`, in order: not parseable or not an object → `save_invalid_json` · `format` differs →
`save_wrong_format` · `version` missing, not a whole number or < 1 → `save_corrupt` · `version >
CURRENT_VERSION` → `save_from_future` · `migrate` · `World.from_dict` returns null, or a command
fails to decode → `save_corrupt` · an owned node or a region id unknown to the content →
`save_content_missing`. Then `Simulation.from_world`, `rebuild_modifiers()`, set `content_mismatch`.
**A refused save changes nothing and never crashes** — every access is type-checked first.

**Migrations:** a table `from_version → Callable(Dictionary) -> Dictionary`. `migrate` applies
`table[v]` while `v < CURRENT_VERSION`, writing `version = v + 1` after each; a missing entry →
`save_migration_missing`. v1's table is empty. The table is a parameter so that a test can run a
fabricated v0 → v1 migration without touching production code. Migrations work on raw dictionaries
and never instantiate model classes.

File I/O (`user://`) belongs to the `SaveManager` autoload (M2+), not to `core/`.

## 11. Policies and runners (S1.8)

### 11.1 Interface

```gdscript
class_name Policy
func policy_id() -> String
func setup(db: ContentDB, policy_seed: int) -> void    # seeds the policy's OWN RandomNumberGenerator
func next_command(sim: Simulation) -> Command          # null = done for today
```

A policy never touches `world.rng` and never mutates the simulation. The runner's day loop:

```
policy.setup(db, seed_value * 7919 + 17)
while game not over and world.day < max_days:
	repeat at most 64 times:  c = policy.next_command(sim);  if c == null: break;  sim.apply(c)
	sim.tick()
```

A rejected command counts as `rejected_commands` in the summary; it signals a policy bug.
"Eligible origin" = passes `ChooseOriginCommand.validate`. Anomalies are collected oldest first.

### 11.2 The three policies

| | `idle` | `greedy` | `stealth` |
| --- | --- | --- | --- |
| **Origin** | uniformly random eligible region (own RNG, `randi_range` over eligible regions in index order) | eligible region with the highest `compute` tier, then highest `connectivity`, then lowest index | eligible region with the lowest `regulation` tier, then highest `compute`, then lowest index |
| **Anomalies** | once per day, decides for each active anomaly with a 50 % roll (own RNG, list order) whether to collect it today; returns those, then null | collects every anomaly | collects every anomaly |
| **Purchases** | never | after collecting: among `available_nodes()` with `node_cost <= compute`, the one with the lowest cost; ties by tree order infiltration, capabilities, evasion; then by id. One per call, so costs are re-read after each purchase | the same rule with tree order infiltration, evasion, capabilities — and no `capabilities` node at all while `infected_share < 0.8` |

`idle` is the floor (what happens if the player does nothing: it must lose, by containment);
`greedy` is the impatient player; `stealth` is the careful one. `0.8` and `0.5` are policy
constants, declared as `const` in the policy — they are not game balance.

### 11.3 Runners

`tools/sim_run.gd` and `tools/sim_batch.gd` extend `SceneTree` (`-s` scripts), parse
`OS.get_cmdline_user_args()`, and call `quit(code)`.

`sim_run.gd -- --seed=<int=1> --policy=<idle|greedy|stealth=greedy> --data=<root=res://data>
--max-days=<int=5000> [--check] [--replay]` prints **one line of JSON**:

`seed`, `policy`, `outcome` (outcome id, or `"timeout"`), `days`, `discovery_day`, `phase`,
`nodes_owned`, `regions_seeded`, `regions_dark`, `deaths_share`, `containment`, `compute_earned`,
`rejected_commands`, `hash`.

`--check` runs `check_invariants()` after every tick and stops at the first report. `--replay`
replays the finished run's command log and compares hashes. Exit codes: 0 finished (timeout
included) · 1 content errors (printed one per line) or bad arguments · 2 invariant violation ·
3 replay mismatch.

`sim_batch.gd -- --seeds=<a>..<b> --policy=… --out=<csv path> [--data] [--max-days]` writes one CSV
row per seed with the same fields as columns, then prints per outcome the count and share, and
p10 / p50 / p90 of `days`.

**Budget:** one `greedy` run on the real world under 3 s, a 200-seed batch under 10 min on the dev
machine. If missed, profile `ModifierStack.value` first; if still missed, record it under *Known
issues* rather than restructuring.

The CI job added in S1.8 runs `sim_run` with `--seed=1 --check --replay` twice and compares the two
`hash` values.

## 12. Tests

GUT, under `tests/unit/` unless marked *(integration)*. One file per class or system; names in the
coding standard. Every test builds its own `Simulation` from `Fixtures`; no shared mutable state.

**S1.1 — `test_content_loader.gd`, `test_schema_validator.gd`**
- the fixture loads with zero errors; 6 regions, 7 links, 9 nodes; `regions[0] == null`;
  `regions[3].id == "fx_cedar"`; derived `population` tiers are 2, 2, 3, 2, 0, 1
- `res://data` loads with zero errors *(skipped with a message while `data/world/` does not exist —
  it arrives in S1.7)*
- link ids are derived as specified; `ModifierDef.matches` for each scope kind, including a null
  region
- `content_hash` is equal for two loads and changes when a value changes; it does not change when
  only whitespace or key order changes (`load_from_dicts` with reordered dictionaries)
- one test per error class in §4.2, each asserting `file` and `path`; two errors in one file are
  both reported; malformed input of every JSON type at the top level does not crash

**S1.2 — `test_sim_rng.gd`, `test_world.gd`, `test_simulation.gd`**
- same seed → same sequence; different seed → different sequence; `from_strings(seed_string(),
  state_string())` continues the sequence exactly; `chance(0.0)` and `chance(1.0)` both advance the
  state
- 100 ticks of the empty system list change only `day`; hash equal for equal seeds and different for
  different seeds (the RNG state is in the hash)
- `to_dict` → `from_dict` → equal hash; `from_dict` returns null for a missing field, a wrong type, a
  region list that does not match the content
- the outbox holds only the last tick's events (use a test system that emits one event per tick)
- `apply` of an invalid command changes neither the hash nor the log; an accepted command gets
  `day` and is logged; after an outcome is set `tick()` returns false, the hash stays, and `apply`
  gives `game_over`
- `check_invariants` is empty for a fresh world and reports each violation when state is corrupted
  by hand

**S1.3 — `test_choose_origin.gd`, `test_spread_system.gd`**
- each failure reason of `choose_origin`; its effect and event
- penetration is monotone non-decreasing and stays in [0, 1] over 2000 ticks; saturation snaps to
  exactly 1.0
- without `breakout`, nothing is ever seeded; with it, all of regions 1–5 are seeded within 1500
  ticks and `fx_fir` never is
- with both `fx_elm` links closed, `fx_elm` is never seeded; an unlinked region never is
- the air-gapped region consumes no roll: with `fx_dogwood` infected, the RNG state after a tick is
  the same whether the `fx_dogwood`–`fx_fir` link is open or closed
- a region seeded on day `d` seeds nobody on day `d`; `region_seeded` names the source and kind
- control stays 0 at or below the threshold, rises above it, and `region_controlled` fires once
- same seed → same `seeded_day` for every region

**S1.4 — `test_modifier_stack.gd`, `test_purchase_node.gd`, `test_compute_system.gd`**
- `(base + Σ add) × Π mul`; clamping at both ends; scoped modifiers apply only to matching regions
  and never to a null region; `remove_source` restores the previous value exactly; re-adding a
  source replaces it; flags follow their source
- cost = base + number owned, and `node_cost` stat scales it; each failure reason of
  `purchase_node` in check order; `requires_any` with none / one owned; the cross-tree
  prerequisite of `fx_harm_2`; Compute is deducted exactly
- `fx_reach` measurably shortens the mean day on which region 4 is seeded (20 seeds, with vs.
  without) — the step's *done when*
- yield matches the formula by hand for a two-region state; dark regions yield nothing
- anomalies: never more than `max_active`; never two in a region; none in clean or dark regions;
  expire on the right day with an event; value follows the formula including the Footprint term;
  collecting twice → `unknown_anomaly`; collecting an expired one → `unknown_anomaly`
- milestones fire once each, in order, reward once; the continent milestone fires for `east` and
  not for the origin's continent

**S1.5 — `test_population_system.gd`, `test_containment_system.gd`, `test_phase_system.gd`,
`test_outcome_system.gd`, `test_outcomes.gd` *(integration)***
- no deaths at Harm 0; deaths follow the formula; `alive + deaths` stays the initial population; a
  region goes dark exactly once, loses its anomaly, stops yielding and relaying
- no containment before discovery and none on the day of discovery; deaths above the threshold
  discover without a roll; at zero Footprint and share the risk is the scrutiny term alone
- capacity falls with deaths and with control; threshold events fire once each, in order
- phases never regress over a full run; discovery while Boxed jumps to Emergent with one event
- outcome priority: a state that satisfies both Extinction and Contained yields Extinction
- *(integration)* the four recipes of §9 reach their outcomes; after each, nothing ticks;
  `check_invariants` is empty after every tick of all four runs

**S1.8 — `test_world_serializer.gd`, `test_policies.gd`, `test_replay.gd` *(integration)***
- run 300 ticks ≡ run 120, save, load, run 180 — by hash, on a `greedy` fixture run (so commands,
  anomalies and modifiers are all in play)
- seed and RNG state are JSON **strings** in the file; floats survive bit-exactly (a value like
  0.1 + 0.2 round-trips)
- each refusal reason of §10; a fabricated v0 save passes through an injected migration; a future
  version is refused; a truncated file does not crash
- `content_mismatch` is set when the hash differs and the save still loads
- replaying the command log of a finished run reproduces the final hash; a tampered log returns null
- each policy finishes the fixture with zero rejected commands; `idle` loses by containment; the
  same seed and policy give the same hash twice; a policy draws nothing from the world's generator
  (`world.rng.state_string()` is unchanged across every `next_command` call of a full `idle` run)

**S1.P — `test_float_bits.gd`, `test_save_continue.gd` *(integration)***
- the codec: the written form is 16 lower-case hex characters; 0.1, 1e-9 and 7 676 945 548.0
  round-trip exactly, as do 500 computed values and the edges of the range (±0, ±INF, NAN, a
  denormal); a plain number is still read; anything else is refused rather than read as a number
- *(integration)* **on the real world**, `greedy`, seed 1: 200 + 100 ticks ≡ 200 ticks, save to text,
  load, 100 ticks — by hash, with `check_invariants` after every tick of both runs
- a long run's `history` survives the file field for field; a float field that is neither a number
  nor the bit form makes the save `save_corrupt`

## 13. Acceptance

A step is done when its tests in §12 pass, the definition of done in IMPLEMENTATION §1.5 holds, and:

- **S1.1** bad data of every class is rejected with file and path; nothing under `core/content/`
  calls `load()`.
- **S1.2** an empty simulation ticks deterministically; `grep` finds no `randf(`, `randi(`,
  `randomize(` outside `sim_rng.gd` and the policies.
- **S1.3** a seeded fixture fills regions 1–5 along its links, reproducibly, and leaves `fx_fir` clean.
- **S1.4** a scripted purchase sequence changes spread speed measurably.
- **S1.5** the fixture can be won twice and lost twice by script.
- **S1.8** as IMPLEMENTATION S1.8 — baselines for all three policies recorded in `PROGRESS.md`.

Anything this spec does not decide is a design gap: conservative placeholder, `# DESIGN?`, entry in
`PROGRESS.md`.
