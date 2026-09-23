# Loop mechanics (D4.1)

**Step:** D4.1 · **Model:** Fable · **Date:** 2026-09-23 · **Status:** binding for S4.1–S4.3; the
source is `loop-redesign.md` §7–§8, which this spec turns into API, grammars, strings and tests.
Where the two differ, this one is right (the differences are listed in §20).

Terms as in `loop-redesign.md`: **asset** (a thing of the agent's standing in a region), **status**
(a timed condition on a region or on the agent), **ability** (a status or effect the player
applies by command), **map event** (a marker with options and a deadline), **site select** (the map
mode that answers "where"). **Region 0 means "no region"** everywhere: a status or event with
`region == 0` is *global* — on the agent, or on the world.

---

## 1. Scope

**In:** the model and save changes (`Region.assets`, `World.statuses`, `World.events`, the agent's
cooldowns and flags; save format v2 with the v1 → v2 migration); the `Eligibility` grammar; the
`asset` scope; the effect vocabulary as one class, `EffectDef`, applied by one runner; `AssetDef`,
`StatusDef`, `AbilityDef`, `EventDef` and their files; the tree v3 fields (`group`, `excludes`,
`deploy`, `ability`, `requires_assets`); the three commands (`PurchaseNodeCommand.region`,
`UseAbilityCommand`, `ChooseEventOptionCommand`); `StatusSystem` and `EventSystem` in the tick
order; the three new live targets; anomalies at a constant beat and `SimRng.weighted_pick`; the
economy numbers of loop-redesign §4.3; the interface: site select, the console line, the asset
readout, the three marker kinds, the data texture's second row, the region panel's four new rows,
the tree modal's new states and rows, the wire card with its illustration slot; the string tables;
the fixture additions; tests and acceptance per S4.1, S4.2, S4.3.

**Out:** the factions' pressure formula, capacity attributes, the counter-move schedule and the
eight moves, Societal Function, Autophagy, the threat bar and the containment panel rewrite
(**D4.2**, built in S4.4–S4.5 — this spec leaves the hooks they need and names them); the v3 tree
*data*, the assets/statuses/abilities *content*, the openings and chains (**D4.3/D4.4**, built in
S4.6–S4.7); the bots' second generation (S4.10); the Analysis screen (D4.4); the pictures in the
illustration slot (M6).

**What each build step takes from here** (the *Files* column of §2 says the same per file):

| Step | Sections |
| --- | --- |
| **S4.1 Assets and site select** | §3 (model: assets, cooldowns and flags are S4.2), §4, §5, §6, §11 (`group`, `excludes`, `deploy`, `requires_assets`), §12, §13, §14 (its rows), §15, §16.1, §16.3 (asset glyph rows), §16.5 (Assets row), §16.6, §16.9, §17, §18, §19 (`best_site`), §21.1 |
| **S4.2 Statuses and abilities** | §3 (statuses, pulses, timed flags, cooldowns), §7, §8, §9, §11 (`ability`), §14, §16.2, §16.3 (status rings), §16.4, §16.5 (Status and Actions rows), §16.10, §16.11, §17, §21.2 |
| **S4.3 Map events** | §3 (events), §10, §14, §16.3 (event markers), §16.5 (Event card), §16.7, §16.8, §17, §19 (`answer_events`), §21.3 |

---

## 2. Files

`core/` stays `RefCounted` only. New files carry a `class_name`; the presentation scenes do not.

| File | Step | What |
| --- | --- | --- |
| `core/content/asset_def.gd` | S4.1 | `AssetDef` (§6.1) |
| `core/content/eligibility.gd` | S4.1 | `Eligibility` (§5) |
| `core/content/effect_def.gd` | S4.1 | `EffectDef` (§8) — **replaces** `purchase_effect_def.gd`; every reference to `PurchaseEffectDef` is renamed |
| `core/content/status_def.gd` `status_level_def.gd` | S4.2 | `StatusDef`, `StatusLevelDef` (§7.1) |
| `core/content/ability_def.gd` | S4.2 | `AbilityDef` (§9.1) |
| `core/content/event_def.gd` `event_option_def.gd` | S4.3 | `EventDef`, `EventOptionDef` (§10.1) |
| `core/content/content_db.gd` `content_loader.gd` `schema_validator.gd` | each | the four new files loaded, indexed and validated (§15) |
| `core/content/modifier_def.gd` `core/modifiers/modifier_stack.gd` | S4.1 | the `asset` scope (§6.3); S4.2: the three targets live (§7.5) |
| `core/model/region.gd` `world.gd` `agent.gd` `faction.gd` | S4.1–S4.3 | §3 |
| `core/model/status.gd` `pulse.gd` | S4.2 | `Status`, `Pulse` (§3.2) |
| `core/model/open_event.gd` `pending_event.gd` | S4.3 | `OpenEvent`, `PendingEvent` (§3.3) |
| `core/systems/effect_runner.gd` | S4.1 | `EffectRunner` (§8.3) — `PurchaseNodeCommand._apply_effect` moves here |
| `core/systems/status_system.gd` | S4.2 | `StatusSystem` (§7.4) |
| `core/systems/event_system.gd` | S4.3 | `EventSystem` (§10.4) |
| `core/systems/spread_system.gd` `compute_system.gd` `containment_system.gd` | S4.1 / S4.2 | anomaly beat (§12, S4.1); `penetration_decay`, `control_decay`, `containment_capacity` (§7.5, S4.2); `seeds_by_kind` (§3.4, S4.1) |
| `core/systems/headline_conditions.gd` | S4.3 | the `when` keys of §10.3 |
| `core/commands/purchase_node_command.gd` | S4.1 | `region`, the five new checks (§11.3), deploy (§6.4) |
| `core/commands/use_ability_command.gd` | S4.2 | §9.3 |
| `core/commands/choose_event_option_command.gd` | S4.3 | §10.5 |
| `core/command.gd` `command_codec.gd` `sim_event.gd` `sim_rng.gd` `simulation.gd` | each | reasons (§11.3, §9.3, §10.5), codec rows, event constants (§14), `weighted_pick` (§12), tick order (§4), queries (§3.5) |
| `core/save/world_serializer.gd` | S4.1 | v2 and the migration (§13) |
| `core/policy/policy.gd` and the six policies | S4.1 / S4.3 | `best_site`, `answer_events` (§19) |
| `data/assets.json` | S4.1 | the four kinds with loop-redesign §7.1's base effects — **S4.1 writes it from §6.2**; D4.3 may retune the numbers, not the shape |
| `data/statuses.json` `data/abilities.json` | S4.2 | S4.2 writes the **two** entries §21.2 needs to prove the machinery (`blackout` and `harvested` with `blackout` and `harvest`); D4.3 writes the rest |
| `data/events/openings.json` | S4.3 | S4.3 writes **one** opening (§21.3); D4.3 writes the eight |
| `data/tech/*.json` | S4.1 | **only** `groups` and `group: "vectors"` on the seven Tier 1 Infiltration vectors, and `deploy` on Logistics Fleets (S4.1's *Done when* needs one deploy node); every other v3 field is D4.3's |
| `data/balance.json` | S4.1 / S4.3 | §18 |
| `data/SCHEMA.md` | each | the new files and fields, the way S3.1 did it for v2 |
| `data/loc/strings.csv` | each | §17 |
| `game/autoload/game.gd` `event_bus.gd` | S4.1 / S4.2 | site select (§16.1), signals (§16.11) |
| `game/map/region_data.gd` `map_view.gd` `map.gdshader` | S4.1 / S4.2 | the second row (§16.3.1), outline and border rules |
| `game/map/marker_layer.gd` + `asset_marker.gd` `status_marker.gd` `event_marker.gd` | S4.1–S4.3 | §16.3 |
| `game/map/link_layer.gd` `link_line.gd` | S4.2 | closed-by-status lines (§16.4) |
| `ui/screens/origin_prompt.tscn` → `ui/hud/site_prompt.tscn` + `.gd` | S4.1 | the prompt strip generalised (§16.1) |
| `ui/hud/console_line.tscn` + `.gd` | S4.2 | §16.2 |
| `ui/hud/top_bar.tscn` `status_strip.tscn` | S4.1 | the asset readout (§16.9) |
| `ui/panels/region_panel.tscn` + `.gd`, `ui/panels/event_card.tscn` + `.gd` | S4.1–S4.3 | §16.5 |
| `ui/panels/tech_detail.gd` `tech_tree.gd` `ui/components/tech_node.gd` | S4.1 / S4.2 | §16.6 |
| `ui/modals/wire_card.tscn` + `.gd`, `ui/modals/discovery_modal.tscn` | S4.3 | §16.7 |
| `ui/modals/ability_picker.tscn` + `.gd` | S4.2 | §16.10 |
| `ui/hud/hud.gd` `menu_sheet.gd` | S4.2 / S4.3 | reveal rows (§16.8), the sheet entry (§16.10) |
| `ui/theme/ui_tokens.gd` `theme_builder.gd` | S4.1 | §16.12 |
| `tests/fixtures/world_small/…` | each | §22 |
| `tests/…` | each | §21 |

---

## 3. Model

### 3.1 Region (S4.1)

```gdscript
## Asset kind → count; absent means 0. Written through `World.set_assets` only (§6.3).
var assets: Dictionary[String, int] = {}

func asset_count(kind: String) -> int          # 0 when absent
func has_assets() -> bool                      # any kind > 0
```

### 3.2 Statuses, pulses, timed flags (S4.2)

```gdscript
class_name Status
var id: String                 # StatusDef id
var region: int                # 0 = on the agent (global)
var source: String             # "ability:<id>" | "faction:<id>" | "event:<event def id>" | "effect"
var level: int                 # 1-based index into StatusDef.levels
var started_day: int
var until_day: int             # ends on the tick whose day >= until_day
var option: String             # the answered option of the event that applied it; "" if none
var closed_links: Array[String] = []   # link ids this status closed (§7.3)

func days_total() -> int       # until_day − started_day
func days_left(day: int) -> int
func source_id() -> String     # the modifier source: "status:<id>:<region>"

class_name Pulse               # `footprint_pulse` (§8.2): a timed footprint with no status
var value: float
var until_day: int
var watched_by: Array[String]
var index: int                 # World.next_pulse_id at creation; source "pulse:<index>"
```

`World` gains:

```gdscript
var statuses: Array[Status] = []      # application order
var pulses: Array[Pulse] = []
var next_pulse_id: int = 1

func status_in_region(id: String, region: int) -> Status     # null if none
func statuses_in_region(region: int) -> Array[Status]        # region 0 = the global ones
func has_status(id: String, region: int) -> bool
func statuses_of(id: String) -> Array[Status]                # every region
func link_held_closed(link_id: String) -> bool               # any active status lists it
```

`Agent` gains:

```gdscript
var cooldowns: Dictionary[String, int] = {}     # ability id → day it clears (absent = ready)
var timed_flags: Dictionary[String, int] = {}   # flag → day it expires (`set_flag`, §8.2)
var story_flags: Array[String] = []             # persistent narrative flags (§10.1), set order
var seeds_by_kind: Dictionary[String, int] = {} # link kind → regions seeded over that kind (S4.1)

func has_story_flag(flag: String) -> bool
```

`seeds_by_kind` is incremented by `SpreadSystem` for every `region_seeded` it emits and by
`seed_neighbours` (§8.2); it feeds D4.2's Disclosure and costs nothing to keep from S4.1 on.

### 3.3 Events (S4.3)

```gdscript
class_name OpenEvent
var id: int                    # World.next_event_id at opening; commands name it
var def: String                # EventDef id
var region: int                # 0 = global
var faction: String            # "" unless a counter-move
var opened_day: int
var deadline_day: int          # the tick whose day >= deadline_day chooses `default`
var level: int                 # the counter-move's status level (S4.5), 1 otherwise

class_name PendingEvent        # scheduled but not yet open: chain follow-ups, and anything that
var def: String                # arrived while `max_open` events stood (§10.4)
var region: int
var faction: String
var due_day: int
var level: int
```

`World` gains `events: Array[OpenEvent]` (opening order), `pending_events: Array[PendingEvent]`
(due order, ties in scheduling order), `next_event_id: int = 1`, `event_fires: Dictionary[String,
int]` (def id → times opened, for `max_fires`), `event_last_day: Dictionary[String, int]` (def id →
day last opened, for `cooldown_days`), and:

```gdscript
func event_by_id(id: int) -> OpenEvent                 # null if none
func event_in_region(region: int) -> OpenEvent         # the oldest open one bound to it, or null
func open_event_count() -> int
```

### 3.4 Faction (S4.1 reserves, S4.5 fills)

```gdscript
var preparing: String = ""        # status id of the counter-move in preparation
var fire_day: int = -1
var cooldown_until: int = 0
```

Saved from v2 on with these defaults so that the schedule of D4.2 needs no v3. Nothing reads them
before S4.5. *(D4.2:* at S4.4 `world.factions` becomes the four of `factions.json`, v2 changed in
place; `World.FACTION_UNIFIED` goes — opposition.md §3.1, §3.4.)

### 3.5 Simulation queries (pure, no RNG)

```gdscript
func ability_level(ability_id: String) -> int          # 0 = not unlocked (§9.2)
func ability_ready_day(ability_id: String) -> int      # the day the cooldown clears; ≤ day = ready
func eligible_regions(rule: Eligibility) -> PackedInt32Array   # index order (§5)
func site_eligibility(node_id: String, region_index: int) -> String   # "" or a reason code (§5)
func hardware(region_index: int) -> float
# `b.compute_hardware_by_tier[tier] + stat("hardware", r)` — the yield's hardware, one place
```

`check_invariants` gains: an asset count < 0; a status whose `region` is dark, or whose `level` is
outside its def's levels, or whose `until_day <= started_day`; two statuses of one id in one
region; an event whose `deadline_day < opened_day` or whose region is dark; more open events than
`b.events.max_open`; a cooldown, timed flag or pulse with a day in the past *older than one tick*
(the tick that expires them runs after everything else that day, so "one day late" is normal);
a `story_flag` duplicated; `seeds_by_kind` with a kind not in `LinkDef.KINDS`.

### 3.6 `to_dict` additions (the save's `world` block, §13)

Region block: `"assets": {"fleet": 2}` (kinds with count > 0 only, kind order as
`AssetDef.KINDS`), `"society"` (bits; 0 until S4.5 reads it — D4.2 §3.3). Agent block: `"cooldowns"`, `"timed_flags"` (both flag/ability → int day),
`"story_flags"` (list), `"seeds_by_kind"` (kind → int). Faction block: the three fields of §3.4.
World: `"statuses": [{"id", "region" (region id, "" for global), "source", "level",
"started_day", "until_day", "option", "closed_links"}]`, `"pulses": [{"index", "value" (bits),
"until_day", "watched_by"}]`, `"next_pulse_id"`, `"events": [{"id", "def", "region", "faction",
"opened_day", "deadline_day", "level"}]`, `"pending_events": [{"def", "region", "faction",
"due_day", "level"}]`, `"next_event_id"`, `"event_fires"`, `"event_last_day"`, `"starving_days"` (0 until S4.5 — D4.2
§3.2). All whole numbers plain, every float as bits (`FloatBits`). Everything above is in `state_hash`.

---

## 4. Tick order (S4.2, S4.3)

`Simulation._init` becomes:

```
SpreadSystem
ComputeSystem
PopulationSystem
# slot: SocietalFunctionSystem (S4.5)
ContainmentSystem
# slot: CounterMoveSystem (S4.5) — the faction schedule; opens counter-move events through EventSystem.schedule
StatusSystem            S4.2
# slot: BehaviourSystem (M5)
EventSystem             S4.3
PhaseSystem
OutcomeSystem
HistorySystem
```

This is IMPLEMENTATION §3's order (recorded there at D4.0). Every system still returns at once
while `agent.origin == 0`.

---

## 5. Eligibility

One grammar for deploy sites, ability targets, event picks and — at S4.5 — counter-move targets.

```gdscript
class_name Eligibility
const KEYS: Array[String] = ["infected", "not_dark", "not_dormant", "attr_min", "attr_max",
	"asset_min", "asset_max", "status_absent", "status_present", "penetration_min",
	"control_min", "continent", "not_origin"]
# reason codes, in check order — also `UI_ELIGIBLE_<CODE>` keys (§17.2)
const REASON_NOT_INFECTED: String = "not_infected"
const REASON_DARK: String = "dark"
const REASON_DORMANT: String = "dormant"
const REASON_ATTR_MIN: String = "attr_min"
const REASON_ATTR_MAX: String = "attr_max"
const REASON_ASSET_MIN: String = "asset_min"
const REASON_ASSET_MAX: String = "asset_max"
const REASON_STATUS_ABSENT: String = "status_absent"
const REASON_STATUS_PRESENT: String = "status_present"
const REASON_PENETRATION: String = "penetration_min"
const REASON_CONTROL: String = "control_min"
const REASON_CONTINENT: String = "continent"
const REASON_ORIGIN: String = "not_origin"

var infected: bool = false
var not_dark: bool = false
var not_dormant: bool = false
var attr_min: Dictionary[String, int] = {}
var attr_max: Dictionary[String, int] = {}
var asset_min: Dictionary[String, int] = {}
var asset_max: Dictionary[String, int] = {}
var status_absent: Array[String] = []
var status_present: Array[String] = []
var penetration_min: float = 0.0     # > 0 only when the key was given
var control_min: float = 0.0
var continent: String = ""
var not_origin: bool = false

static func from_dict(d: Dictionary) -> Eligibility       # after validation; every key optional
static func none() -> Eligibility                         # matches every region that is not dark
func check(world: World, region_index: int) -> String     # "" = eligible, else the first failing reason
func detail(world: World, region_index: int) -> Dictionary
# the arguments of the failing reason's string: {"attr", "tier"} · {"kind", "count"} · {"status"} · {"value"} · {"continent"}
```

| Key | Type | Region passes when |
| --- | --- | --- |
| `infected` | bool | `true`: `penetration > 0`. `false` is the same as absent |
| `not_dark` | bool | `true`: `not dark`. **Always applied**, whether given or not — nothing targets a dark region; the key exists so data can say it |
| `not_dormant` | bool | `true`: `not dormant` |
| `attr_min` / `attr_max` | attr → tier 0…4 | `def.attr(a) >= t` / `<= t`, every entry |
| `asset_min` / `asset_max` | kind → int ≥ 0 | `asset_count(kind) >= n` / `<= n` |
| `status_absent` / `status_present` | [status id] | no status of that id in the region / one of each id present |
| `penetration_min` / `control_min` | float in [0, 1] | `penetration >= v` / `control >= v` |
| `continent` | continent id | `def.continent == value` |
| `not_origin` | bool | `true`: `region_index != agent.origin` |

Keys are checked in the order of `KEYS`; the first failure is the reason (so the region panel's
caption says the most basic thing first: *not infected* before *no lab there*). Validation (§15):
unknown key; wrong type; unknown attribute, asset kind, status id or continent; `attr_min` above
`attr_max` for the same attribute; `asset_min` above `asset_max`; a status id in both lists.

---

## 6. Assets (S4.1)

### 6.1 `AssetDef` and `assets.json`

```gdscript
class_name AssetDef
const KIND_FLEET: String = "fleet"
const KIND_LAB: String = "lab"
const KIND_TAP: String = "tap"
const KIND_OFFICE: String = "office"
const KINDS: Array[String] = ["fleet", "lab", "tap", "office"]   # also the drawing order
var kind: String
var modifiers: Array[ModifierDef]        # every one scoped {"asset": kind}, §6.3
var watched_by: Array[String]
var glyph: String                        # Glyphs name (§16.3.2): "ASSET_FLEET" …
```

`data/assets.json` (one file, required, exactly the four kinds):

```json
{"version": 1, "assets": [
	{"kind": "fleet", "watched_by": ["public_sentiment"], "glyph": "ASSET_FLEET",
	 "modifiers": [
		{"target": "hardware", "op": "add", "value": 1.0},
		{"target": "control_growth", "op": "mul", "value": 1.3},
		{"target": "shutdown_survival", "op": "add", "value": 0.3}]},
	{"kind": "lab", "watched_by": ["security_researchers"], "glyph": "ASSET_LAB",
	 "modifiers": [
		{"target": "anomaly_value", "op": "mul", "value": 1.3},
		{"target": "yield", "op": "mul", "value": 1.2}]},
	{"kind": "tap", "watched_by": ["governments"], "glyph": "ASSET_TAP",
	 "modifiers": [
		{"target": "yield", "op": "mul", "value": 1.2},
		{"target": "control_growth", "op": "mul", "value": 1.2}]},
	{"kind": "office", "watched_by": [], "glyph": "ASSET_OFFICE",
	 "modifiers": [
		{"target": "containment_capacity", "op": "mul", "value": 0.5}]}
]}
```

A kind's modifiers carry **no scope in the file**; the loader scopes every one `{"asset": kind}`
(`min` 1). A scope in the file is a validation error. Targets must be regional. (The base
effects are loop-redesign §7.1's table; `containment_capacity` is inert until S4.2, like any
inert target.)

### 6.2 Base effects as sources

`Simulation.rebuild_modifiers` adds, **before** the tech sources, one source per kind:
`ModifierStack.source_for_asset(kind)` = `"asset:<kind>"`, with the kind's modifiers and no flags.
The sources are always active — an asset-scoped modifier matches nothing until a region holds the
asset, so "active while the agent holds ≥ 1" needs no bookkeeping. `World.create` adds them too.

### 6.3 The `asset` scope

`ModifierDef.ScopeKind` gains `ASSET`; `scope_asset: String`, and `scope_min` doubles as the
minimum count (default 1, `"min"` in the file, ≥ 1). Form: `{"asset": <kind>, "min": n?}`; no
`max`. A scope on a global target stays an error.

`ModifierDef.matches(region: RegionDef)` cannot see state, so the **stack** answers this scope:

```gdscript
# ModifierStack
var asset_counts: Dictionary[int, Dictionary] = {}   # region index → {kind: count}; state, mirrored
func set_asset_count(region_index: int, kind: String, count: int) -> void
func asset_count(region_index: int, kind: String) -> int
```

`value(target, region)`: for a modifier with `scope_kind == ASSET`, it applies iff `region != null
and asset_count(region.index, scope_asset) >= scope_min`; every other scope goes through
`matches` as before. `clear()` does **not** clear `asset_counts` (`rebuild_modifiers` refills the
sources, the counts are state); `World.from_dict` and `World.create` fill the counts from the
regions; the one writer at run time is:

```gdscript
# World
func set_assets(region_index: int, kind: String, count: int) -> void
# writes Region.assets (erasing the key at 0) and modifiers.set_asset_count; the ONLY way assets change
```

### 6.4 Deploy on purchase

Node field `deploy` (§11.1): `{"kind": <kind>, "count": n ≥ 1, "eligible": <Eligibility>}`.
`PurchaseNodeCommand` gains `region: String` (id; `""` = none), constructor
`PurchaseNodeCommand.new(node, region = "")`, codec field `"region"` (absent reads as `""`).
Validation and execution: §11.3. On execute, after `add_source` and before `on_purchase`:
`world.set_assets(index, kind, count + asset_count)`, event `asset_deployed {node, kind, region,
count}` once — after `node_purchased`, before the one-shots' events.

`requires_assets` (§11.1) is a purchase prerequisite: `{"lab": 2}` means the agent holds ≥ 2 labs
**in total, over all regions**; a purge that leaves one is what makes the node unbuyable again.

### 6.5 Loss

`destroy_assets {kind, count}` (§8.2) in a region removes `min(count, held)`; event `asset_lost
{kind, region, count, cause}` with `cause` = the effect's `source` (§8.3). A region going dark
loses everything it holds: `PopulationSystem.go_dark` calls `set_assets(i, kind, 0)` for every
kind and emits `asset_lost` with `cause: "dark"` per kind held. Nodes stay owned in both cases.

---

## 7. Statuses (S4.2)

### 7.1 `StatusDef` and `statuses.json`

```gdscript
class_name StatusDef
const ORIGIN_PLAYER: String = "player"
const ORIGIN_WORLD: String = "world"
var id: String
var origin: String
var watched_by: Array[String]
var levels: Array[StatusLevelDef]       # ≥ 1; level n is levels[n − 1]
var border: bool                        # draw the region's border in the status colour (Lockdown)
var blocks: Array[String]               # status ids the world's moves skip in the region (S4.5; data now)
var cancellable: bool                   # reserved; false in every initial status

class_name StatusLevelDef
var days: int                           # ≥ 1
var modifiers: Array[ModifierDef]       # no scope in the file (§7.3)
var on_start: Array[EffectDef]
var on_end: Array[EffectDef]
var closes_links: Array[String]         # link kinds, or ["all"]
var ends_statuses: Array[String]        # status ids ended in the same region when this starts
```

```json
{"version": 1, "statuses": [
	{"id": "blackout", "origin": "player", "watched_by": ["governments", "public_sentiment"],
	 "levels": [
		{"days": 20, "modifiers": [
			{"target": "yield", "op": "mul", "value": 0.5},
			{"target": "containment_capacity", "op": "mul", "value": 0.0},
			{"target": "society_pressure", "op": "add", "value": 8.0},
			{"target": "harm", "op": "add", "value": 0.5},
			{"target": "spread_growth", "op": "mul", "value": 1.3},
			{"target": "footprint", "op": "add", "value": 3.0}]},
		{"days": 40, "modifiers": [
			{"target": "yield", "op": "mul", "value": 0.5},
			{"target": "containment_capacity", "op": "mul", "value": 0.0},
			{"target": "society_pressure", "op": "add", "value": 14.0},
			{"target": "harm", "op": "add", "value": 1.5},
			{"target": "spread_growth", "op": "mul", "value": 1.3},
			{"target": "footprint", "op": "add", "value": 3.0}],
		 "on_start": [{"effect": "spread_status", "status": "blackout", "level": 1, "days": 10}]}
	]}
]}
```

Fields absent default to: `watched_by []`, `border false`, `blocks []`, `cancellable false`,
`on_start []`, `on_end []`, `closes_links []`, `ends_statuses []`. Ids are unique; `origin` is one
of the two; a `mul 0` is allowed (it is what "no capacity" means — the clamp's floor is 0).
Strings per status: `STATUS_<ID>_NAME`, `STATUS_<ID>_DETAIL`, `STATUS_<ID>_CODE` (§17.5).

### 7.2 Application

`StatusSystem.apply(world, db, id, region, source, level, option, events) -> Status` (static; also
called by commands and by `EffectRunner`):

1. `level = clamp(level, 1, def.levels.size())`; `lvl = def.levels[level − 1]`.
2. `ends_statuses`: for each id, every status of that id in `region` is ended with cause
   `"ended"` (§7.4 step 3, at once).
3. **Exclusive:** if a status of `id` already stands in `region`, it is *refreshed*: its
   `level`, `until_day`, `source`, `option` are overwritten, its source re-added (`add_source`
   replaces in place), its `closed_links` re-evaluated; `status_started` carries
   `refreshed: true`. Otherwise a new `Status` is appended.
4. `started_day = day`, `until_day = day + lvl.days`.
5. `modifiers.add_source(status.source_id(), scoped, [])` where `scoped` is `lvl.modifiers` with
   the region scope injected (§7.3).
6. `closes_links`: for each of the region's links whose kind is listed (or all): `link.open =
   false`, and the link id appended to `status.closed_links` if it was open before or is not
   held by another status. Region 0 with `closes_links` is a validation error.
7. `on_start` effects, in order, with context `{region, source: "status:<id>", node: ""}`.
8. Event `status_started {status, region, source, level, until_day, refreshed}` **before** the
   effects' events (append it after step 4, then run 7).

The RNG is not touched unless an effect rolls (`spread_status` does not; nothing in the initial
set does).

### 7.3 Scoping

`StatusDef` modifiers carry no scope in the file (a scope is a validation error). At application:
a **regional** target gets `scope_kind = REGION, scope_region = region` when `region > 0`, and
stays unscoped (everywhere) when the status is global — that is how *Pause*'s `spread_growth
×0.5` reaches every region; a **global** target stays unscoped in both cases. `StatusDef.
scoped_modifiers(level, region) -> Array[ModifierDef]` builds the copies; the originals are
never mutated.

### 7.4 `StatusSystem.tick`

After containment, before events. For every status whose `until_day <= day`, in `statuses`
order — collect first, then end each, so an `on_end` cannot skip a neighbour:

1. `on_end` effects with the status's context — **only when the cause is `expired`** *(D4.2)*: a
   status cut short by `ends_statuses`, `end_statuses` or a refresh runs no `on_end`; its
   consequence did not come to pass (opposition.md §7.1 — the Protest's fleet).
2. `remove_source(source_id)`; for each id in `closed_links`: `link.open = true` unless
   another *active* status lists it.
3. Remove from `statuses`; event `status_ended {status, region, cause}` — `"expired"` here,
   `"ended"` from `ends_statuses` / `end_statuses`, `"cancelled"` reserved for the *Cancel*
   button. `StatusSystem.end(world, status, cause, events)` is the one function all three use.

Then pulses whose `until_day <= day` (remove source `"pulse:<index>"`, event `pulse_ended`), then
timed flags (remove source `"flag:<flag>"`, event `flag_expired {flag}`). Cooldowns need nothing:
`ability_ready_day` compares.

### 7.5 The three targets that go live (S4.2)

| Target | Kind | Base | Clamp | Read where |
| --- | --- | --- | --- | --- |
| `containment_capacity` | regional | 1 | 0…20 | `ContainmentSystem._capacity`: the region's weight becomes `weight × stat("containment_capacity", r)` — numerator only; the denominator keeps the plain tier weight, so a region with no capacity lowers the world's, it does not vanish from it. `containment_breakdown` unchanged in shape |
| `penetration_decay` | regional | 0 | 0…1 | `SpreadSystem._grow`, before growth, for every region that is not dark and not dormant with `penetration > 0`: `p -= p × stat("penetration_decay", r) × (1 − stat("shutdown_survival", r))`, floored at **0**. A region whose penetration reaches 0 is no longer infected (`seeded_day` stays — it was seeded once; `infected_share` and the yield read 0 from it, and it can be seeded again) |
| `control_decay` | regional | 0 | 0…1 | `SpreadSystem._control`, for every region not dark and not dormant with `control > 0`, before the gain: `control = max(0, control − stat("control_decay", r))`; the gain then applies only above the threshold as before |

`shutdown_survival` leaves `INERT_TARGETS` (read by `penetration_decay` above; D4.2's Purge reads
it too). `INERT_TARGETS` after S4.2: `society_pressure`, `emergent_rate`, the four
`containment_<faction>`. The three new targets: rows in SCHEMA §4.1, bases in `balance.stats` (and
the fixture's), clamps, `ModifierDef.TARGETS_REGIONAL` / `TARGETS_ALL`, `STAT_*` strings (§17.6).

### 7.6 Watched-by

`watched_by` on a status (and on a pulse, and on an asset kind) is data that S4.4 reads for
per-faction Footprint (loop-redesign §5.3). Until then a status's `footprint` modifier adds to the
one global stat like a node's does. Nothing in S4.2 reads `watched_by`.

---

## 8. Effects — one vocabulary (S4.1 `EffectDef` + runner; effects marked S4.2 land with statuses)

### 8.1 `EffectDef`

Replaces `PurchaseEffectDef`. Used by `on_purchase` (nodes), `on_start` / `on_end` (status
levels), `applies.effects` (abilities), `effects` and `chance[].effects` (event options).

```gdscript
class_name EffectDef
var effect: String
var value: float = 0.0
var count: int = 0
var kind: String = ""
var status: String = ""
var level: int = 1
var days: int = 0
var ids: Array[String] = []
var faction: String = ""
var flag: String = ""
var watched_by: Array[String] = []
var per_hardware: bool = false
const EFFECTS: Array[String]        # the ids below, in this order
const INERT_EFFECTS: Array[String]  # ["funding_reset"] until S4.4
const NEEDS_REGION: Array[String]   # the effects that must run with region > 0
static func from_dict(d: Dictionary) -> EffectDef
func is_inert() -> bool
```

### 8.2 The list

`R` = needs a region (validation: such an effect on a global status, a global ability or a global
event is an error; `per_hardware` on `compute_grant` makes it `R`).

| `effect` | Fields (required unless `?`) | R | Does | Event |
| --- | --- | --- | --- | --- |
| `compute_grant` | `value ≥ 0`, `per_hardware?` | if per_hardware | `compute` and `compute_earned` `+= value` (× `sim.hardware(region)` when `per_hardware`) | `compute_granted {node, source, value}` |
| `containment_rollback` | `value (0, 1]` | | as today, every faction | `containment_rolled_back` per faction, `+ source` |
| `harm_burst` | `value (0, 1]` | | as today, world-wide | `harm_burst {node, source, deaths}` |
| `funding_reset` | `value (0, 1]` | | **inert** until S4.4 (D4.2: burns preparation) | none |
| `seed_neighbours` | `count ≥ 1` | R | the uninfected (`penetration == 0`), not dark, not air-gapped neighbours over **open** links, sorted by `sim.hardware(r)` descending then index ascending; the first `count` get `penetration = b.spread.seed_penetration`, `seeded_day = day`, `seeds_by_kind[kind] += 1` — `kind` is the first open link between the two in `world.links` order | `region_seeded {region, from, link_kind}` each |
| `penetration_mul` | `value ≥ 0` | R | `penetration = clamp(penetration × value, 0, 1)`; snaps to 1 above `saturation_snap` | `penetration_changed {region, from, to}` |
| `control_add` | `value` (any sign) | R | `control = clamp(control + value, 0, 1)`; `region_controlled` if it crosses `control_complete` upward | `control_changed {region, from, to}` |
| `destroy_assets` | `kind`, `count ≥ 0` (0 = every one held *(D4.2)*) | R | §6.5 | `asset_lost` |
| `spread_status` | `status`, `level? (1)`, `days? (0 = the level's own)` | R | `StatusSystem.apply` on every neighbour over open links that is not dark, with `source` = the context's source and, when `days > 0`, `until_day = day + days` instead of the level's | `status_started` each |
| `end_statuses` | `ids` | R (0 = global ones) | ends every listed status in the region, cause `"ended"` | `status_ended` each |
| `containment_add` | `faction`, `value` (any sign) | | `containment = clamp(c + value, 0, 1)` on that faction; `"all"` = every faction; threshold events fire on an upward crossing as in `_grow` | `containment_added {faction, value}` |
| `footprint_pulse` | `value`, `days ≥ 1`, `watched_by?` | | a `Pulse` (§3.2): source `"pulse:<index>"` with one `footprint add value` modifier; `until_day = day + days` | `pulse_started {index, value, until_day}` |
| `set_flag` | `flag`, `days ≥ 1` (0 = permanent → a story flag) | | `days > 0`: `timed_flags[flag] = day + days`, source `"flag:<flag>"` with the flag; `days == 0`: appended to `story_flags` (once) | `flag_set {flag, until_day}` (−1 for permanent) |
| `apply_status` *(D4.2, S4.2)* | `status`, `level? (1)`, `days? (0 = the level's own)` | | `StatusSystem.apply` in the context's region (0 in a global container: on the agent) with the context's source, `option ""`; `days > 0` overrides `until_day` | `status_started` |
| `wipe` *(D4.2, S4.2)* | `value [0, 1]` | R | `penetration ← penetration × clamp(value + stat("shutdown_survival", r), 0, 1)` — the shutdown `shutdown_survival` was reserved for; a region at 0 stays seeded (§7.5) | `region_wiped {region, from, to, source}` |

`compute_grant per_hardware` at the initial numbers is Harvest's *8 × hardware(r)*: the ability's
status has `on_start: [{"effect": "compute_grant", "value": 8, "per_hardware": true}]`.

`seed_neighbours` and `spread_status` are deterministic (sorting, no roll). `penetration_mul` and
`control_add` on a dormant region apply anyway (a purge does not care that the agent is quiet).

### 8.3 `EffectRunner`

```gdscript
class_name EffectRunner
static func apply(sim: Simulation, effect: EffectDef, context: EffectContext,
		events: Array[SimEvent]) -> void
static func apply_all(sim: Simulation, effects: Array[EffectDef], context: EffectContext,
		events: Array[SimEvent]) -> void

class_name EffectContext           # core/systems/effect_context.gd
var region: int = 0
var source: String = ""            # "tech:<id>" | "status:<id>" | "ability:<id>" | "event:<id>"
var node: String = ""              # for the `node` field of the S3.1 events; "" otherwise
```

`PurchaseNodeCommand` calls `apply_all` with `{region: the deploy site or 0, source: "tech:<id>",
node: id}`. Every event an effect emits carries `source`; the S3.1 events keep `node` (empty when
the source is not a node) so `HeadlineConditions.node_tree` keeps working.

---

## 9. Abilities (S4.2)

### 9.1 `AbilityDef` and `abilities.json`

```gdscript
class_name AbilityDef
const TARGET_REGION: String = "region"
const TARGET_GLOBAL: String = "global"
const APPLIES_STATUS: String = "status"
const APPLIES_DEPLOY: String = "deploy"
const APPLIES_EFFECTS: String = "effects"
var id: String
var target: String
var cost: float                      # ≥ 0
var cooldown_days: int               # ≥ 0
var eligible: Eligibility            # region target only; `none()` for global
var applies_kind: String             # one of the three
var applies_status: String           # APPLIES_STATUS
var applies_deploy_kind: String      # APPLIES_DEPLOY
var applies_deploy_count: int
var applies_effects: Array[EffectDef]   # APPLIES_EFFECTS
var levels_from: Array[String]       # node ids in level order, ≥ 1
func max_level() -> int              # levels_from.size()
```

```json
{"version": 1, "abilities": [
	{"id": "blackout", "target": "region", "cost": 6, "cooldown_days": 45,
	 "eligible": {"infected": true, "attr_min": {"compute": 1}, "status_absent": ["blackout"]},
	 "applies": {"status": "blackout"},
	 "levels_from": ["regional_blackout", "cascading_grid_failure"]},
	{"id": "harvest", "target": "region", "cost": 0, "cooldown_days": 45,
	 "eligible": {"infected": true, "not_dormant": true, "status_absent": ["harvested"]},
	 "applies": {"status": "harvested"},
	 "levels_from": ["edge_caching"]},
	{"id": "fabricate", "target": "region", "cost": 10, "cooldown_days": 60,
	 "eligible": {"infected": true, "attr_min": {"industry": 2}},
	 "applies": {"deploy": {"kind": "fleet", "count": 1}},
	 "levels_from": ["autonomous_fabrication"]}
]}
```

`applies` has exactly one key. With `status`: the status is applied at the ability's level
(`min(level, status levels)`), `source` `"ability:<id>"`, in the region (0 for global). With
`deploy`: `set_assets` and `asset_deployed {node: "", ability, kind, region, count}`. With
`effects`: `apply_all` with `{region, source: "ability:<id>"}`. Validation: each node in
`levels_from` exists and carries `"ability": {"id": <this>, "level": <its position + 1>}` (§11.1
— both sides, so the data cannot lie); a `status` id exists and has at least `levels_from.size()`
levels **or** the ability says `"level_cap": n` (absent = the status must have enough); `eligible`
on a global ability is an error; `cost` and `cooldown_days` finite. Strings: `ABILITY_<ID>_NAME`,
`ABILITY_<ID>_DETAIL` (§17.5).

### 9.2 Level

`Simulation.ability_level(id)` = the number of leading entries of `levels_from` that are owned —
owning the second node without the first is impossible by the trees' prerequisites (the validator
requires `levels_from[i + 1]` to have `levels_from[i]` in its `requires`). 0 = locked. On
`node_purchased` of a node with `ability`, the command's events gain `ability_unlocked {ability,
level}` after `asset_deployed` and before the one-shots.

### 9.3 `UseAbilityCommand`

`type_id` `use_ability`, fields `ability: String`, `region: String` (`""` for global). Codec:
`{"type": "use_ability", "day", "ability", "region"}`. Checks, in order:

| Reason | When |
| --- | --- |
| `no_origin` | `agent.origin == 0` |
| `unknown_ability` | no such def |
| `ability_locked` | `ability_level == 0` |
| `ability_cooldown` | `cooldowns[id] > day` |
| `insufficient_compute` | `compute < cost` |
| `site_required` | region target and `region == ""` |
| `invalid_region` | region target and unknown id — a global ability **ignores** `region` |
| `site_ineligible` | `eligible.check(world, index) != ""` |

Execute: `compute −= cost`; `cooldowns[id] = day + cooldown_days` (only when `cooldown_days > 0`;
otherwise the key is erased); event `ability_used {ability, region ("" if global), level, cost}`
**first**; then `applies` (§9.1), whose events follow. `Simulation.can_apply` is what the region
panel's buttons read (§16.5).

---

## 10. Map events (S4.3)

### 10.1 `EventDef`, `EventOptionDef` and `events/*.json`

Every file under `data/events/` is loaded (ascending file-name order), each `{"version": 1,
"events": [ … ]}`; ids unique across files. Three kinds, one format.

```gdscript
class_name EventDef
const KIND_OPENING: String = "opening"
const KIND_COUNTER_MOVE: String = "counter_move"
const KIND_CHAIN: String = "chain"
const PICK_SAME: String = "same"
const PICK_RULES: Array[String] = []            # = CounterMoveRules.RULES of opposition.md §6.4 — the names from S4.3 on, the functions in S4.5
var id: String
var kind: String
var chain: String                  # KIND_CHAIN: the chain id every step of it shares; "" otherwise
var start: bool                    # KIND_CHAIN: this step is entered from the world (rolled like an opening)
var pick: Eligibility              # where it lands; null when pick_same or pick_rule
var pick_same: bool                # "same": the region of the step that scheduled it
var pick_rule: String              # {"rule": id}: a named target rule (S4.5)
var pick_weight: String            # "uniform" (default) | "hardware_penetration"
var when: Dictionary               # ticker.md §3.3 B + §10.3; evaluated at the draw
var weight: float                  # > 0, default 1
var max_fires: int                 # ≥ 0; default 1 for chain steps, 0 (unlimited) otherwise
var cooldown_days: int             # ≥ 0, default 0; days between two openings of this def
var deadline_days: int             # ≥ 1
var default_option: String         # an option id; its cost is 0 and its requires empty (validator)
var modal: bool                    # opens the wire card even with a region
var illustration: String           # "" or an id; M6 supplies the file
var status: String                 # KIND_COUNTER_MOVE: the status the event applies (D4.2)
var faction: String                # KIND_COUNTER_MOVE: who fires it
var flags: Array[String]           # story flags set when the event opens
var options: Array[EventOptionDef] # 2…4

class_name EventOptionDef
var id: String                     # unique within the event; snake case
var cost: float                    # ≥ 0
var requires: Dictionary           # §10.2
var effects: Array[EffectDef]
var chance: Array[Dictionary]      # [{"p": (0, 1], "effects": [EffectDef]}], rolled in order
var flags: Array[String]           # story flags set when this option is chosen
var status_level: int              # counter-move: 0 (default) = the open event's level (D4.2 §6.3); n = level n
var status_days: int               # counter-move: 0 (default) = the level's days; n = n days instead (D4.2)
var skip_status: bool              # counter-move: the status is not applied (Lobby: cancelled)
var next: Array[Dictionary]        # [{"step": event id, "delay_days": ≥ 0}] — chain follow-ups
```

```json
{"version": 1, "events": [
	{"id": "opening_unattended_cluster", "kind": "opening",
	 "pick": {"infected": true, "attr_min": {"compute": 2}, "status_absent": ["harvested"]},
	 "when": {"phase": ["covert", "emergent"]},
	 "weight": 3, "max_fires": 2, "cooldown_days": 40, "deadline_days": 20, "default": "leave",
	 "options": [
		{"id": "take", "cost": 0, "effects": [
			{"effect": "compute_grant", "value": 4},
			{"effect": "footprint_pulse", "value": 2, "days": 20, "watched_by": ["security_researchers"]}]},
		{"id": "seed", "cost": 2, "effects": [{"effect": "seed_neighbours", "count": 1}],
		 "chance": [{"p": 0.3, "effects": [{"effect": "footprint_pulse", "value": 3, "days": 30}]}]},
		{"id": "leave", "cost": 0}]}
]}
```

A chain: one file per chain, every step `"kind": "chain", "chain": "the_factory"`; exactly one step
with `"start": true`, its `pick` and `when` like an opening's; the other steps `"pick": "same"` (or
an eligibility of their own, or omitted = global) and reachable only through `next`. `next` on an
option schedules the step `delay_days` after the answer (§10.4); a step named by nobody and not
`start` is a validation error, and so is a `next` into another chain or into a non-chain event.
Strings per event: `EVENT_<ID>_TITLE`, `EVENT_<ID>_BODY`, per option `EVENT_<ID>_OPT_<OPTION>` and
`EVENT_<ID>_RESULT_<OPTION>` (§17.5).

### 10.2 `requires` on an option

| Key | Type | Holds when |
| --- | --- | --- |
| `owned` | [node id] | all owned |
| `owned_any` | [node id] | at least one |
| `flag` | [flag] | `sim.has_flag(f)` for every f — modifier flags (nodes, timed) **or** story flags |
| `asset_min` | kind → int | in the event's region; on a global event an error |
| `compute_min` | float | `compute >= v` — for options whose cost is not the whole point |
| `ability` | ability id | `ability_level(id) > 0` — *Squeeze (the ability, on the region)* |

`Simulation.has_flag(flag) -> bool` = `modifiers.has_flag(flag) or agent.has_story_flag(flag)`.
The option's lock reason for the interface: `EventDef.lock_reason(sim, event, option) ->
Dictionary {"reason": "node" | "node_any" | "flag" | "asset" | "compute" | "ability", …args}`, or
empty when unlocked; the panel renders `UI_EVENT_LOCK_<REASON>` (§17.4).

### 10.3 `when` — the state grammar grows

`HeadlineConditions` gains rows (also for headlines; the vocabulary is one table):

| Key | Type | Reads |
| --- | --- | --- |
| `faction_min` / `faction_max` | faction id → float | that faction's `containment`; an unknown id (the unified track's world) reads as `max_containment()` |
| `asset_min` / `asset_max` | kind → int | the agent's **total** of that kind |
| `status_active` | [status id] | every id has ≥ 1 active status anywhere |
| `status_inactive` | [status id] | none of them has |
| `ability_unlocked` | [ability id] | every one at level ≥ 1 |
| `story_flag` / `not_story_flag` | [flag] | all set / none set (`flag` / `not_flag` stay modifier flags **plus** story flags, so an event's `when.flag` reads both — recorded as an extension of ticker §3.3 B) |

### 10.4 `EventSystem.tick`

After statuses (and, from S4.5, after the counter-move schedule that calls `schedule`). In order:

1. **Deadlines.** For every open event with `deadline_day <= day`, in `events` order: choose
   `default_option` for the player through the same path a command takes (§10.5, without the
   compute check — the default is free by validation), event `event_expired {event, def, region,
   option}` **instead of** `event_answered`.
2. **Pending.** While `open_event_count() < b.events.max_open` and a pending event is due
   (`due_day <= day`): open the earliest due (§10.6). A pending event whose region has gone dark
   is dropped (`event_dropped {def, region, cause: "dark"}`); one whose `pick_same` region no
   longer exists cannot happen (regions are not removed).
3. **Openings.** If `open_event_count() < max_open`, no pending event is due, `seeded_count() >=
   b.events.opening_from_regions` (2) and the phase's `b.events.opening_chance[phase] > 0`: roll
   it once (`rng.chance`). On success: the candidate list = every def with `kind == opening` (or a
   chain step with `start`) whose `when` holds, whose `max_fires` is not reached, whose
   `cooldown_days` has passed, and for which `pick` yields ≥ 1 eligible region (global events —
   no `pick` — always qualify). Empty list: nothing happens (the roll is spent). Otherwise
   `weighted_pick` over `weight` (def order) → def; then its region: `weighted_pick` over the
   eligible regions in index order, weights 1 (`uniform`) or `hardware(r) × penetration(r)`
   (`hardware_penetration`; zero total falls back to uniform). Open it (§10.6).

`b.events.opening_chance` is per phase id; Boxed is 0. Chain starts share the roll and the list
with openings — a chain is an opening that continues.

### 10.5 `ChooseEventOptionCommand`

`type_id` `choose_event_option`, fields `event: int`, `option: String`. Codec `{"type", "day",
"event", "option"}`. Checks: `no_origin` · `unknown_event` (no open event with that id — closed or
never existed) · `unknown_option` · `option_locked` (§10.2) · `insufficient_compute`. Execute,
`answer(sim, open_event, option_id, expired, events)` shared with the deadline path:

1. `compute −= cost`.
2. Event `event_answered {event, def, region, option}` (or `event_expired`, from step 1 of §10.4)
   **first**.
3. `flags` of the option → `set_flag` semantics with `days 0` (story flags).
4. `effects` in order, context `{region, source: "event:<def id>"}`; then each `chance` entry:
   `rng.chance(p)` → its effects. Every `chance` is rolled, in order, whatever the earlier ones
   did (the stream is what it is).
5. Counter-move (`def.status != ""` and not `skip_status`): `StatusSystem.apply(id, region,
   "faction:<faction>", level, option.id)` with `level = option.status_level if > 0 else
   open_event.level`, and `until_day = day + option.status_days` when that is > 0 *(D4.2)*.
6. Close: remove from `events`; `event_fires`, `event_last_day` were written at opening.
7. `next`: for each entry `PendingEvent {step, region: open_event.region if the step is
   pick_same else 0 (its own pick runs at opening), faction: "", due_day: day + delay_days,
   level 1}` appended to `pending_events`.

### 10.6 Opening an event

`EventSystem.open(world, db, def, region, faction, level, events) -> OpenEvent` (static; the
counter-move schedule of S4.5 and the pending queue call it): `id = next_event_id++`,
`opened_day = day`, `deadline_day = day + deadline_days`, `event_fires[def] += 1`,
`event_last_day[def] = day`, the def's `flags` set as story flags, appended to `events`; event
`event_opened {event, def, kind, region, faction, deadline_day, modal}`.
`EventSystem.schedule(world, def, region, faction, due_day, level)` appends a `PendingEvent` —
the door S4.5 uses. A pending event with `region > 0` keeps it *(D4.2: the schedule picked it)*; one
with `region == 0` whose def has `pick` (not `same`) picks its region when it opens, with the sim RNG, exactly as step 3 of §10.4 does; no eligible region → dropped with
`cause: "no_site"`.

---

## 11. Tree v3 fields (S4.1 `group`, `excludes`, `deploy`, `requires_assets`; S4.2 `ability`)

### 11.1 Fields

File header: `"groups": {"vectors": {"max": 2}}` — group id → cap ≥ 1; the header is optional and
groups may be declared in any tree file, once each (a second declaration is an error), and every
node's `group` must be declared somewhere.

| Field | Type | Rule |
| --- | --- | --- |
| `group` | group id | at most `max` nodes of the group may be owned |
| `excludes` | [node id] | symmetric: every listed node lists this one back (validator); no self; ids exist |
| `deploy` | `{"kind", "count" ≥ 1, "eligible": Eligibility}` | §6.4; `eligible` may be `{}` |
| `ability` | `{"id": ability id, "level": int ≥ 1}` | the ability's `levels_from[level − 1]` is this node (validator, both directions) |
| `requires_assets` | kind → int ≥ 1 | §6.4 |

`TechNodeDef` gains `group: String`, `excludes: Array[String]`, `deploy_kind: String`,
`deploy_count: int`, `deploy_eligible: Eligibility` (null when no deploy), `ability_id: String`,
`ability_level: int`, `requires_assets: Dictionary[String, int]`; `func deploys() -> bool`,
`func grants_ability() -> bool`. `ContentDB` gains `groups: Dictionary[String, int]` (id → max).
`TECH_NODE_KEYS` grows by the five; `SchemaValidator` gets the rules above. Strings: a group's
name `GROUP_<ID>` (§17.4).

### 11.2 `Simulation` queries

```gdscript
func owned_in_group(group: String) -> int
func excluded_by(node_id: String) -> String     # the first owned node that excludes it, or ""
func missing_assets(node: TechNodeDef) -> Dictionary[String, int]   # kind → shortfall, empty = fine
```

### 11.3 `PurchaseNodeCommand.validate` — the full order

`no_origin` · `unknown_node` · `already_owned` · `missing_prerequisite` · **`group_full`** (owned
in the node's group ≥ cap) · **`excluded_by`** (`excluded_by(id) != ""`) · **`missing_assets`** ·
`insufficient_compute` · **`site_required`** (deploys and `region == ""`) · **`invalid_region`** ·
**`site_ineligible`** (`site_eligibility(node, index) != ""`). A node that does not deploy ignores
`region` (a bot may pass one; the codec keeps it). `available_nodes()` stays "prerequisites met":
the tree shows excluded and group-full nodes with their own state (§16.6) rather than hiding them.

Execute order (tech-trees §6.6, extended): pay → own → `add_source` → **deploy** (§6.4) →
**`ability_unlocked`** (§9.2) → `on_purchase` through `EffectRunner`. Events: `node_purchased`,
`asset_deployed`, `ability_unlocked`, then the effects'.

---

## 12. Anomalies at a constant beat (S4.1) and `SimRng.weighted_pick`

```gdscript
# SimRng
func weighted_pick(weights: PackedFloat64Array) -> int
# Index drawn in proportion to weight; consumes exactly ONE value. Negative and non-finite weights
# count as 0. Returns −1 without consuming anything when the total is ≤ 0.
```

`ComputeSystem._spawn` becomes loop-redesign §7.7: if `anomalies.size() >= max_active` return; roll
`b.anomaly.spawn_chance` once (`chance`, always consuming); on success build the candidate list —
regions in index order that are infected, not dark, not dormant, without an anomaly — with weights
`hardware(r) × penetration × stat("anomaly_rate", r)`; `weighted_pick`; −1 (no candidate, or all
weights 0) spawns nothing. Value, id, expiry, event as before. `anomaly_rate` keeps its meaning as
a weight (SCHEMA §4.1's row: *multiplier on the spawn chance there* → *weight in the draw*).

Balance (§18): `anomaly.spawn_chance` 0.12, `max_active` 3, `base_value` 3.0 — the §4.3 values.

---

## 13. Save format v2 (S4.1)

`WorldSerializer.CURRENT_VERSION = 2`; `MIGRATIONS: Dictionary[int, Callable] = {1: _v1_to_v2}`
replaces `NO_MIGRATIONS` as `from_json`'s default. `_v1_to_v2(save) -> Dictionary` works on the
raw dictionary: every region block gains `"assets": {}`; the agent block `"cooldowns": {}`,
`"timed_flags": {}`, `"story_flags": []`, `"seeds_by_kind": {}`; every region block also `"society"` (0 as
bits) and the world block `"starving_days": 0` *(D4.2)*; every faction block
`"preparing": ""`, `"fire_day": -1`, `"cooldown_until": 0`; the world block `"statuses": []`,
`"pulses": []`, `"next_pulse_id": 1`, `"events": []`, `"pending_events": []`,
`"next_event_id": 1`, `"event_fires": {}`, `"event_last_day": {}`. `World.from_dict` **requires**
every v2 field (a v1 file reaches it migrated). Type rules as always: ill-typed → null →
`save_corrupt`; a status, event or pending event naming a def, region or link unknown to the
content → `save_content_missing` (the `_missing_content` pass grows by these ids); a status
`region` `""` reads as 0.

The v1 → v2 migration test of §21.1 replaces the fabricated v0 → v1 one as the production example;
the fabricated one stays as the "table is a parameter" test.

---

## 14. Event catalogue additions (`SimEvent`)

| `type` | `data` | Emitted by | Step |
| --- | --- | --- | --- |
| `asset_deployed` | `node` (`""` from an ability), `ability` (`""` from a node), `kind`, `region`, `count` | command | S4.1 |
| `asset_lost` | `kind`, `region`, `count`, `cause` (a source, or `"dark"`) | effects, Population | S4.1 |
| `ability_unlocked` | `ability`, `level` | command | S4.2 |
| `ability_used` | `ability`, `region`, `level`, `cost` | command | S4.2 |
| `status_started` | `status`, `region` (`""` global), `source`, `level`, `until_day`, `refreshed: bool` | StatusSystem, commands, effects | S4.2 |
| `status_ended` | `status`, `region`, `cause` | StatusSystem, effects | S4.2 |
| `penetration_changed` | `region`, `from`, `to`, `source` | effects | S4.2 |
| `control_changed` | `region`, `from`, `to`, `source` | effects | S4.2 |
| `containment_added` | `faction`, `value`, `source` | effects | S4.2 |
| `pulse_started` / `pulse_ended` | `index`, `value`, `until_day` / `index` | effects / StatusSystem | S4.2 |
| `flag_set` / `flag_expired` | `flag`, `until_day` (−1 permanent) / `flag` | effects / StatusSystem | S4.2 |
| `event_opened` | `event`, `def`, `kind`, `region`, `faction`, `deadline_day`, `modal: bool` | EventSystem | S4.3 |
| `event_answered` | `event`, `def`, `region`, `option` | command | S4.3 |
| `event_expired` | `event`, `def`, `region`, `option` | EventSystem | S4.3 |
| `event_dropped` | `def`, `region`, `cause` | EventSystem | S4.3 |

`compute_granted`, `containment_rolled_back`, `harm_burst` gain `source`. All go into `TYPES_ALL`;
`SchemaValidator.REGION_EVENTS` gains those carrying `region`. Headline `on` filters gain nothing
new here; D4.3 writes the headlines for these events.

---

## 15. Loading and validation

`ContentLoader.load_root` reads `assets.json`, `statuses.json`, `abilities.json` and every
`events/*.json` (all four **required** from the step that introduces each: S4.1 assets; S4.2
statuses and abilities; S4.3 events — `data/events/` may hold zero files, the directory must
exist). `load_from_dicts` gains the four as parameters (events as an array of file dictionaries);
`Fixtures.raw_content` / `root_files` follow. `ContentDB` gains `assets: Dictionary[String,
AssetDef]` (kind order), `statuses: Array[StatusDef]` + `status_by_id`, `abilities:
Array[AbilityDef]` + `ability_by_id`, `events: Array[EventDef]` + `event_by_id`, `groups`;
`content_hash` covers all of it. Validation order: balance, regions, links, assets, tech, statuses,
abilities, events, headlines — so a cross-reference always points at something already checked.

Rules (each a `ValidationError` with `file` and `path`), beyond those stated inline above:

1. **Every file:** `version` 1; the root list present; ids `ID_PATTERN` and unique (events: across
   files); unknown keys are errors; `_comment` ignored at every level.
2. **Assets:** exactly `AssetDef.KINDS`, each once; `glyph` one of `Glyphs.ASSET_NAMES` (§16.3.2);
   modifiers regional, unscoped.
3. **Eligibility** wherever it appears: §5.
4. **Effects** wherever they appear: known id; required fields present and in range; unknown
   fields for that effect; `R` effects in a global container; `status` / `faction` / `kind` /
   `ids` ids exist (`faction` may be `"all"`); a `flag` colliding with `ModifierDef.FLAGS`; a
   `set_flag` flag or a `flags` entry that no `requires.flag` / `when` ever reads is **not** an
   error (a flag may be set for a later chain).
5. **Statuses:** §7.1; `closes_links` kinds in `LinkDef.KINDS` or `["all"]` alone.
6. **Abilities:** §9.1; `target` one of two; `applies` exactly one key; `deploy` kind exists.
7. **Events:** §10.1; `kind` one of three; `options` 2…4 with unique ids; `default` names an
   option with `cost 0` and empty `requires`; counter-move: `status` and `faction` required,
   `status` exists with `origin world`, every `status_level` within its levels; other kinds:
   `status`, `faction`, `status_level`, `skip_status` are errors; chain rules of §10.1; `next`
   only on chain steps; `pick`: an object (Eligibility), `"same"` (chain follow-ups only) or
   `{"rule": id}` with `id` in `EventDef.PICK_RULES` (counter-moves only; the names of
   `CounterMoveRules.RULES`, opposition.md §6.4 *(D4.2)*); `status_days` int ≥ 0, counter-move
   options only; `status_level` int ≥ 0; `when` keys from
   §10.3 plus ticker §3.3 B; `illustration` matches `ID_PATTERN`.
8. **Tree v3:** §11.1.
9. **Strings** (roots with a `loc/strings.csv` only): per status, ability and event the keys of
   §17.5 with non-empty `en` **and** `de`; `ASSET_<KIND>_NAME` / `_PLURAL` for the four kinds;
   `GROUP_<ID>` for every group.

---

## 16. Interface

### 16.1 Site select (S4.1; abilities join in S4.2)

```gdscript
# Game (autoload) — emits EventBus.site_select_changed(active) on every change (§16.11)
var site_request: SiteRequest = null                              # null when not selecting

class_name SiteRequest                     # ui/site_request.gd (presentation; a plain RefCounted)
var kind: String                           # "origin" | "deploy" | "ability"
var title_key: String                      # UI_SITE_PROMPT_* (the strip's heading)
var name_key: String                       # what is being placed / used: TECH_<ID>_NAME or ABILITY_<ID>_NAME
var eligible: Callable                     # (region_index: int) -> String — "" or a reason code (§5)
var build: Callable                        # (region_id: String) -> Command
var on_cancel: Callable                    # () -> void; the tree modal reopens on its node here

func site_select(request: SiteRequest) -> void   # enters; a second call replaces the first (its on_cancel runs)
func site_cancel() -> void                        # leaves, runs on_cancel
func site_confirm(region_id: String) -> CommandResult   # apply(build(region_id)); success leaves the mode, failure stays in it
```

- **Origin** becomes a `SiteRequest` (`kind "origin"`, `eligible` = `ChooseOriginCommand`'s rule
  as a reason: `airgap` / `compute`, `build` = `ChooseOriginCommand.new`), entered by the session
  on `run_started` while `origin == 0`. The `"origin"` hold and the speed lock stay as m3-screens
  §7.2 says; `UI_ORIGIN_*` strings stay.
- **Deploy**: the tree modal's *Buy and place* (§16.6) calls `site_select` with `eligible` =
  `sim.site_eligibility(node, i)`, `build` = `PurchaseNodeCommand.new(node, id)`, `on_cancel` =
  reopen the modal on that node, then closes itself (releasing its hold if it held). The
  purchase happens at `site_confirm`; until then nothing was bought.
- **Ability** (S4.2): the ability picker (§16.10) or the containment panel (D4.2) calls it with
  `eligible` = the def's `eligible.check` **plus** the command's own checks folded in
  (`sim.can_apply(UseAbilityCommand.new(id, region_id))` — a reason that is not a site reason,
  e.g. `ability_cooldown`, is shown in the strip instead and confirms nothing).
- **The prompt strip** `ui/hud/site_prompt.tscn` replaces `origin_prompt.tscn` in the same slot
  (`%SitePrompt`; the HUD's `_origin_prompt` becomes `_site_prompt`): `LabelHeading` `title_key`
  with `{name}` · `LabelCaption` `UI_SITE_PROMPT_DETAIL` · a `ConsoleButton` `UI_SITE_CANCEL`
  (hidden for the origin — there is nothing to go back to). Visible iff `Game.site_request !=
  null`. Compact/full sizing as before.
- **The map**: the eligible set is written into the data texture's second row (§16.3.1, G = 255)
  for every region with `eligible.call(i) == ""`, recomputed on `site_select_changed`, every
  `tick_advanced` and after every command while selecting; the shader outlines them (§16.3.1).
- **The region panel** while selecting, item **3a** generalised: on an eligible region a
  `ConsoleButtonPrimary` with `UI_SITE_PLACE` (`deploy`), `UI_SITE_USE` (`ability`) or
  `UI_ORIGIN_CHOOSE` (`origin`), sending `site_confirm(id)`; on an ineligible one a `LabelCaption`
  in `TEXT_1` with the reason: `UI_ELIGIBLE_<CODE>` (§17.2), for the origin the two `UI_ORIGIN_
  INELIGIBLE_*` keys. A failed confirm shows `CMD_FAIL_<REASON>` under the button.
- **Leaving:** `Escape`, the strip's cancel, opening the tree, the containment panel, the pause
  menu or a modal, `run_started`, a load. The origin request cannot be cancelled (the strip has
  no button, `Escape` does nothing while `kind == "origin"`).
- **Speed** is not touched by deploy and ability requests (loop-redesign §7.5). Bots never enter
  site select (`Game.policy != null` → `site_select` is a no-op that applies nothing; the bots
  pass the region in the command).

### 16.2 The console line (S4.2)

`ui/hud/console_line.tscn` (`PanelContainer`-less: one `LabelCaption` in `ACCENT`, `TYPE_CAPTION`,
autowrap off, clip, `mouse_filter IGNORE`) under the top bar and **above** the site prompt's slot, in
both layouts; hidden while empty. `push(text)` queues; the queue keeps the newest
`CONSOLE_QUEUE_MAX` 3 and drops the rest; each line shows for `CONSOLE_LINE_MS` 4 000 (fade in and
out over `MOTION_PANEL`; reduced motion: cut). A new line while one shows waits its turn — never
interrupts.

Fed by a table in `console_line.gd`, event type → key, with the arguments formatted through
`Format` and the names through `tr()` (assets `ASSET_<KIND>_NAME`, statuses `STATUS_<ID>_NAME`,
abilities `ABILITY_<ID>_NAME`, regions `REGION_<ID>`, events `EVENT_<ID>_TITLE`, factions
`FACTION_<ID>`):

| Trigger | Key | Placeholders |
| --- | --- | --- |
| `node_purchased` of a **passive** node (no deploy, no ability, no one-shots) | `UI_CONSOLE_PASSIVE` / `UI_CONSOLE_PASSIVE_GLOBAL` | `{stat}`, `{value}` (first modifier, `Format.factor` for mul / signed for add), `{count}` regions in its scope — the count is the regions for which `ModifierDef.matches` (or the asset rule) holds |
| `node_purchased` with one-shots only | `UI_CONSOLE_PURCHASE` | `{name}` |
| `asset_deployed` | `UI_CONSOLE_DEPLOYED` | `{kind}` (plural if `count > 1`), `{count}`, `{region}` |
| `asset_lost` | `UI_CONSOLE_ASSET_LOST` | `{kind}`, `{count}`, `{region}` |
| `ability_unlocked` level 1 / ≥ 2 | `UI_CONSOLE_ABILITY_NEW` / `UI_CONSOLE_ABILITY_LEVEL` | `{ability}`, `{level}` |
| `ability_used` | `UI_CONSOLE_ABILITY_USED` / `_GLOBAL` | `{ability}`, `{region}` |
| `status_started` from a faction | `UI_CONSOLE_STATUS_WORLD` | `{status}`, `{region}`, `{faction}`; global: `UI_CONSOLE_STATUS_WORLD_GLOBAL` |
| `status_started` from the player, on a region, **not** caused by `ability_used` of the same command (an ability already said it) | `UI_CONSOLE_STATUS_YOURS` | `{status}`, `{region}` |
| `status_ended` cause `expired` | `UI_CONSOLE_STATUS_ENDED` / `_GLOBAL` | `{status}`, `{region}` |
| `event_opened` | `UI_CONSOLE_EVENT` / `UI_CONSOLE_EVENT_GLOBAL` | `{title}`, `{region}`, `{days}` |
| `event_expired` | `UI_CONSOLE_EVENT_EXPIRED` | `{title}`, `{option}` (`EVENT_<ID>_OPT_<OPTION>`) |
| `compute_granted` from a one-shot or an effect | `UI_CONSOLE_GRANT` | `{value}` `COMPUTE` |

D4.2 adds counter-move prepared and faction lead change. A bot run says nothing (`Game.policy !=
null` → the line stays hidden).

**Stat delta chips** (loop-redesign §4.1): on `node_purchased` the three `StatBar`s of the stat
row whose bound value changed by the command (compare before/after `command_applied`) show a
`Chip` with the signed delta (`Format` `PLAIN`, one decimal) at their right end for
`CONSOLE_LINE_MS`, and their fill flashes as a `ValueLabel` does. Regions in the scope of a passive
node flash their outline: the map's second row gets **B = 255** on those regions for
`MOTION_SCOPE_FLASH` 1 500 ms (§16.3.1 — G is site select's eligibility, B is the flash), then
clears.

### 16.3 Map

#### 16.3.1 The data texture's second row

`RegionData` becomes **256 × 2**. Row 0 is unchanged (six flags; nothing new fits its byte — the
`bit 5–7` of loop-redesign §8.2 are already taken by `dormant` at bit 5; recorded in §20). Row 1,
per region:

| Channel | Value |
| --- | --- |
| R | **status colour index** / 255: 0 none · 1 a player status (`ACCENT`) · 2…5 the faction of the world status (`Faction.FACTION_IDS` index + 2). With several statuses: the world's wins over the player's; among world statuses the one with the most days left |
| G | 255 while the region is **eligible** in site select, else 0 |
| B | 255 while the region is in a **scope flash** (§16.2), else 0 |
| A | 255 if a standing status has `border: true` (Lockdown), else 0 |

`RegionData.write` fills both rows; `encode_row1(region, statuses, eligible, flashing) -> Color`
is the pure half. `MapView` rewrites it on `tick_advanced`, after every command, on
`site_select_changed`, and when a scope flash starts or ends. The shader gains uniforms
`FACTION_1…FACTION_4` (the four faction colours, §16.12) and reads `texelFetch(region_data,
ivec2(idx, 1), 0)`:

- after step 5 (border): if `A > 0.5`, the border mix colour is the status colour (`ACCENT` for
  index 1, `FACTION_n` for 2…5) instead of `MAP_BORDER`, at full strength;
- after step 7 (selection outline): if `G > 0.5` (eligible) or `B > 0.5` (flash), the 4-tap
  neighbour test draws the outline in `ACCENT` for this region — the selection outline wins
  where both apply.

#### 16.3.2 Markers

`marker_layer.gd` keeps the anomalies and the dark crosses and gains three children per kind,
each a `Node2D` at the region's anchor, counter-scaled like `AnomalyMarker`, rebuilt from the
world on `run_started` / load, updated from events:

| Marker | Script | Drawn | Created / removed on |
| --- | --- | --- | --- |
| **Asset row** | `asset_marker.gd` (`class_name AssetMarker`) | one glyph per kind held, in `AssetDef.KINDS` order, fleets first and drawn at 16 px, the rest at 12 px; a count in `TYPE_CAPTION` `TEXT_0` after a glyph when > 1; the row is centred **below** the anchor at `MARKER_ROW_OFFSET` 18 px; glyphs in `ACCENT`; a **commissioning ring** on `asset_deployed` — a 2 px `ACCENT` ring from radius 10 to 28 fading over `MOTION_PANEL` × 3 (reduced motion: none) | `asset_deployed` / `asset_lost`; removed when the region holds nothing |
| **Status ring** | `status_marker.gd` (`class_name StatusMarker`) | for each status in the region (region 0: none — global statuses show in the HUD, §16.9): a ring of radius `STATUS_RING_RADIUS` 14 + 5 per further status, stroke 3 px, in `ACCENT` (player) or the faction colour (world), emptying **clockwise** as `days_left / days_total` (drawn as an arc from −90° over `TAU × left`); inside the innermost ring the status's `STATUS_<ID>_CODE` in `TYPE_CAPTION`, `TEXT_0`; the anomaly marker's countdown ring (S3.P item 7) is drawn by the same helper `Rings.draw_countdown(canvas, centre, radius, share, color, stroke)` (`ui/components/rings.gd`) | `status_started` / `status_ended` |
| **Event marker** | `event_marker.gd` (`class_name EventMarker`) | at `MARKER_EVENT_OFFSET` (−18, −18) px from the anchor: a 20 px disc in `BG_2` with a 2 px stroke and a glyph — `!` in the faction colour (counter-move), `◇` in `ACCENT` (opening), `»` in `TEXT_0` (chain step); the deadline as a countdown ring around it (`Rings`, `days_left / deadline_days`); pulsing like an anomaly (`ANOMALY_PULSE_PERIOD`, static under reduced motion) | `event_opened` / `event_answered` / `event_expired` |

`Glyphs` gains `ASSET_FLEET` (▲ filled), `ASSET_LAB` (◆ filled), `ASSET_TAP` (▮ filled),
`ASSET_OFFICE` (● filled), `EVENT_COUNTER` (`!`), `EVENT_OPENING` (◇ stroke), `EVENT_CHAIN` (»),
`const ASSET_NAMES: Array[String]` for the validator. Placeholders until VISUALS §3.3's icon set.

**Hit order** on a tap (`MapCamera.TAP_METHOD` → `marker_layer.try_tap`): event marker (opens the
region panel on that region and scrolls to its Event card, §16.5; a global event has no marker),
then anomaly (collect), then the region. Hit radius `HIT_MIN` 48 screen px for events as for
anomalies (S3.P item 8); asset rows and status rings have no hit — they are the region's.
**Tooltips** (ui-foundation §7.7's box): hovering a status ring shows `UI_MAP_STATUS_TIP`
(`{status}`, `{days}`); an event marker `UI_MAP_EVENT_TIP` (`{title}`, `{days}`); an asset row
`UI_MAP_ASSETS_TIP` with the kinds and counts joined by ` · `.

### 16.4 Links (S4.2)

`link_layer.gd` reads `Link.open` already (`set_open`). A link closed by a status is drawn
**dashed** (the pattern of a flowing link, static) in the colour of the status that closed it
(`world.link_held_closed` → the status: `ACCENT` or the faction's); `LinkLine` gains
`set_closed_color(color)`. `link_line.gd`'s `is_drawn` rule is unchanged, so a closed land link
shows only while something crossed it — a closed sea/air/network link between two infected regions
is what reads as *cut off*. Re-evaluated on `status_started` / `status_ended` and on rebuild.

### 16.5 Region panel — the action panel

The M2/M3 layout (ui-foundation §5.6, m3-screens §8) with the `Extra` slot replaced by, in this
order, each hidden when empty:

9. **Assets** (S4.1) — `LabelHeading` `UI_REGION_ASSETS`; one row per kind held in `KINDS`
   order: the glyph (16 px, `ACCENT`) · `Label` `UI_REGION_ASSET_ROW` (`{kind}` plural when
   `{count}` > 1, `{count}`).
10. **Status** (S4.2) — `LabelHeading` `UI_REGION_STATUS`; one row per active status in the
    region, application order: `LabelCaption` `STATUS_<ID>_CODE` in a `Chip` (`ChipAccent` for a
    player status, a `ChipFaction` variation — `BG_3` fill, the faction colour as text — for the
    world's) · `Label` `STATUS_<ID>_NAME` · `LabelCaption` `UI_REGION_STATUS_DAYS` (`{days}`) ·
    a second line `LabelCaption` in `TEXT_1`: `UI_REGION_STATUS_YOURS` or
    `UI_REGION_STATUS_FACTION` (`{faction}`), followed by `UI_REGION_STATUS_OPTION` (`{option}`
    = `EVENT_<DEF>_OPT_<OPTION>`, only when `option != ""` — the def id comes from the status's
    `source` `event:<id>` or, for a faction status, from the counter-move def whose `status` it
    is) · tooltip on the row `STATUS_<ID>_DETAIL`. The *Cancel* `ConsoleButton`
    (`UI_REGION_STATUS_CANCEL`) exists in the scene, hidden unless `def.cancellable` — no status
    has it; the command behind it is not built (reserved).
11. *(D4.2 inserts Societal Function here.)*
12. **Event card** (S4.3) — `ui/panels/event_card.tscn` (`class_name EventCard`), a `ConsolePanel`
    (alert = false; its border in the faction colour for a counter-move): `LabelCaps` dateline
    `UI_EVENT_KIND_<KIND>` · `LabelHeading` `EVENT_<ID>_TITLE` · `Label` `EVENT_<ID>_BODY`
    (`TYPE_BODY`, autowrap) · one `ConsoleButton` per option, full width, stacked (`SPACE_2`):
    text `EVENT_<ID>_OPT_<OPTION>`, a trailing `Chip` `UI_EVENT_OPTION_COST` (`{cost}`) or
    `UI_EVENT_OPTION_FREE`; disabled with the caption `UI_EVENT_LOCK_<REASON>` (§17.4) under it
    when locked, or `CMD_FAIL_INSUFFICIENT_COMPUTE` when only the compute is short; the
    `default` option's button carries `UI_EVENT_DEFAULT_MARK` in its caption · `LabelCaption`
    `UI_EVENT_DEADLINE` (`{days}`, `{option}`) in `TEXT_1`, turning `ALERT` in the last 3 days
    (a moment, not a state — it is about to be decided for you). Pressing sends
    `ChooseEventOptionCommand`; a failure shows the reason under the button. After the answer the
    card shows `EVENT_<ID>_RESULT_<OPTION>` for `CONSOLE_LINE_MS` (kept by the panel until the
    next tick after that), then hides. The card is bound to `world.event_in_region(index)`; a
    second event in the same region waits for the first (they are opened one at a time by
    `EventSystem` only when `max_open` allows, but two *can* land in one region — the card shows
    the oldest, the marker counts both: a small `Chip` with `{count}` on the marker).
    `RegionPanel.scroll_to_event()` is what the marker tap calls.
13. **Actions** (S4.2) — `LabelHeading` `UI_REGION_ACTIONS`; one `ConsoleButton` per ability with
    `target == region` and `ability_level > 0`, in `abilities.json` order: text
    `ABILITY_<ID>_NAME` · trailing `Chip` `UI_REGION_ACTION_COST` (`{cost}`) / `UI_REGION_
    ACTION_FREE` · `LabelCaption` under it: `UI_REGION_ACTION_COOLDOWN` (`{days}`) while on
    cooldown, else the eligibility reason `UI_ELIGIBLE_<CODE>` while ineligible, else the level
    `UI_REGION_ACTION_LEVEL` (`{level}`) when `max_level > 1` · tooltip `ABILITY_<ID>_DETAIL`.
    Enabled iff `Game.sim.can_apply(UseAbilityCommand.new(id, region_id)) == ""`. Pressing sends
    it; a failure caption as everywhere. Re-read every tick.

The panel re-reads on `tick_advanced` and on `command_applied` as before. In compact all of this
is the same sheet, scrolling.

### 16.6 Tech tree modal (S4.1; *Grants* in S4.2)

- **States** (`TechNode` and the detail pane's chip): `UI_TREE_STATE_EXCLUDED` (`{group}`,
  `{owned}`, `{max}`; `ChipAlert`-less — default chip, the node greyed like *locked*) when
  `owned_in_group(node.group) >= max` and the node is not owned; `UI_TREE_STATE_CLOSED`
  (`{node}` = the excluding node's name) when `excluded_by(id) != ""`. Both rank below *owned*
  and above *locked* in the state order; a node that is both takes *closed*. A `TechNode` in
  either state draws the LOCK glyph like a locked one.
- **Detail pane rows**, after *Prerequisites* and before *Watched by*: **Deploys**
  (`LabelCaps` `UI_TREE_DEPLOYS` + `Label` `UI_TREE_DEPLOYS_ROW` `{kind}` × `{count}`, and the
  eligibility as `LabelCaption`s from the `Eligibility` keys: `UI_ELIGIBLE_NEEDS_<CODE>` — the
  *requirement* phrasing, §17.2); **Grants** (`UI_TREE_GRANTS`, `{ability}`, `{level}`);
  **Needs assets** (`UI_TREE_REQUIRES_ASSETS`, `{kind}`, `{count}`, in `ALERT` while
  `missing_assets` is non-empty); **Excludes** (`UI_TREE_EXCLUDES`, one flat row per excluded
  node like a prerequisite row, in `ALERT` text). The caption row gains `UI_TREE_GROUP`
  (`{group}`, `{owned}`, `{max}`) as a `Chip` when the node has a group. The *Effects* list
  renders an asset scope as `UI_TREE_SCOPE_ASSET` (`{kind}`) / `UI_TREE_SCOPE_ASSET_MIN`
  (`{kind}`, `{count}`).
- **Buy row:** on a deploy node the button reads `UI_TREE_BUY_PLACE` (`{cost}`), enabled iff
  `can_apply(PurchaseNodeCommand.new(id))` is `""` **or** `site_required` (everything but the
  site is fine); pressing enters site select (§16.1) and closes the modal. The failure captions
  gain `CMD_FAIL_GROUP_FULL`, `CMD_FAIL_EXCLUDED_BY`, `CMD_FAIL_MISSING_ASSETS`,
  `CMD_FAIL_SITE_INELIGIBLE`.
- `Enter` on an affordable deploy node does the same as the button.

### 16.7 The wire card (S4.3) and the discovery modal's slot

`ui/modals/wire_card.tscn` + `.gd` (`class_name WireCard`), opened through `ModalHost.open` on
`event_opened` with `modal == true` **or** `region == 0` (a bot run: never — the bot answers or
the deadline does), taking `Game.hold(&"event")`; closed and released on `event_answered` /
`event_expired` of its event, or by *Escape* — **which does not answer**: the card closes, the
event stays open with its deadline, its marker (or, for a global event, a `ChipAlert`
`UI_HUD_EVENT_PENDING` in the top bar after the day cell, `{count}`) brings it back on tap.

Layout per loop-redesign §7.4: `PanelContainer` `ConsolePanelRaised`, max width `WIRE_MAX_WIDTH`
840, `SPACE_5` padding; an `HBox` (full) / `VBox` (compact) of **illustration** and **text
column**. Illustration: a `TextureRect` at 4:3, 280 px wide in full, full width in compact,
`STRETCH_KEEP_ASPECT_COVERED`, in a `PanelContainer` with `BG_2`; it shows
`assets/illustrations/<illustration>.png` when `illustration != ""` and `ResourceLoader.exists`
says so, else the **glyph fallback**: `Glyphs.faction(event.faction)` for a counter-move
(opposition.md §9.7), the event kind's marker glyph otherwise, drawn at 96 px in `TEXT_2`, centred. Text column, `VBox` `SPACE_3`: `LabelCaps`
dateline — `REGION_<ID>`, or `FACTION_<ID>`, or `UI_WIRE_GLOBAL` — in `TEXT_1` · `LabelDisplay`
`EVENT_<ID>_TITLE` · `Label` `EVENT_<ID>_BODY` (`TYPE_BODY`, autowrap) · the option buttons as in
the Event card (§16.5 item 12, same scene `event_card.tscn`'s option list is reused as a
component: `EventOptions`) · `LabelCaption` `UI_EVENT_DEADLINE`. Focus starts on the first
enabled option. After an answer the card shows the `_RESULT_` text and one `ConsoleButtonPrimary`
`UI_COMMON_CLOSE` instead of the options.

The **discovery modal** gains the same slot on its left (full) / top (compact), with the id
`discovery` — glyph fallback the `ALERT` `!` — so that M6 can drop the file in.

### 16.8 Phase reveal rows (S4.2 / S4.3)

m3-screens §6.1's table gains: **console line** — always; **asset readout** — once any asset
exists (`has_assets` on any region, monotone: a readout once shown stays); **Actions row** — once
`ability_level(any) > 0`; **event markers** and the Event card — once `event_fires` is non-empty;
the **threat bar** row is D4.2's. `hud.gd` computes them from state as it does the rest.

### 16.9 Asset readout (S4.1)

Top bar, after the day cell: `LabelCaps` `UI_HUD_ASSETS` over an `HBox` of glyph + `ValueLabel`
per kind held anywhere (in `KINDS` order; a kind at 0 is hidden), the fleet glyph 16 px, the
values `PLAIN`; tooltip `UI_HUD_ASSETS_TIP`. Compact: the status strip's second row, same
content. Values flash on change like a `ValueLabel`. **Global statuses** (region 0) show here too
(S4.2): a `Chip` per active one after the readout, `STATUS_<ID>_CODE`, tooltip name + days.

### 16.10 The ability picker (S4.2)

Desktop key **`A`** (session `_input`, like `T`) and the compact menu sheet's new entry
`UI_SHEET_ABILITIES` open `ui/modals/ability_picker.tscn` through `ModalHost`: a `ConsolePanel`,
max width `MODAL_MAX_WIDTH`, `LabelDisplay` `UI_ABILITIES_TITLE`, then one row per unlocked
ability: `ConsoleButton` name · cost chip · caption cooldown / level; empty: `UI_ABILITIES_NONE`.
A region-target ability closes the picker and enters site select with `UI_SITE_PROMPT_ABILITY`;
a global one sends `UseAbilityCommand.new(id)` and closes on success (a failure shows its caption
in the row). No hold — the picker is quick.

### 16.11 `EventBus` and `Game` additions

```gdscript
# EventBus
signal site_select_changed(active: bool)
signal console_pushed(text: String)        # the console line's input; anything may push
# Game
func site_select(request: SiteRequest) -> void   # §16.1
func site_cancel() -> void
func site_confirm(region_id: String) -> CommandResult
var site_request: SiteRequest
```

### 16.12 Tokens (`UiTokens`, S4.1)

`FACTION_AI_LABS = CAT_SKY`, `FACTION_GOVERNMENTS = CAT_ORANGE`, `FACTION_RESEARCHERS = CAT_GREEN`,
`FACTION_PUBLIC = CAT_PINK` (`CAT_YELLOW` stays free — it sits on the ramp's top), reached through
`UiTokens.faction_color(id: String) -> Color` (unknown id → `ACCENT`); `WIRE_MAX_WIDTH` 840;
`CONSOLE_LINE_MS` 4000; `CONSOLE_QUEUE_MAX` 3; `MOTION_SCOPE_FLASH` 1500; `MARKER_ROW_OFFSET` 18;
`MARKER_EVENT_OFFSET` (−18, −18); `STATUS_RING_RADIUS` 14; `STATUS_RING_STEP` 5; the `ChipFaction`
variation (§16.5). D4.2's threat bar uses the same four colours.

---

## 17. Strings

Rules of ui-foundation §8.1: the console says *du*; every key in `en` and `de`. Keys below are
all new unless marked *(exists)*. `{kind}` receives `ASSET_<KIND>_NAME` / `_PLURAL`.

### 17.1 Command failures

| Key | en | de |
| --- | --- | --- |
| `CMD_FAIL_SITE_REQUIRED` | Choose a region first. | Wähle zuerst eine Region. |
| `CMD_FAIL_SITE_INELIGIBLE` | Not here. | Hier nicht. |
| `CMD_FAIL_GROUP_FULL` | {group}: {owned} of {max} taken. | {group}: {owned} von {max} belegt. |
| `CMD_FAIL_EXCLUDED_BY` | Closed by {node}. | Durch {node} verschlossen. |
| `CMD_FAIL_MISSING_ASSETS` | Needs {count} × {kind}. | Braucht {count} × {kind}. |
| `CMD_FAIL_UNKNOWN_ABILITY` | No such ability. | Keine solche Fähigkeit. |
| `CMD_FAIL_ABILITY_LOCKED` | Not yet yours. | Noch nicht deins. |
| `CMD_FAIL_ABILITY_COOLDOWN` | Ready on day {day}. | Bereit an Tag {day}. |
| `CMD_FAIL_UNKNOWN_EVENT` | That moment has passed. | Der Moment ist vorbei. |
| `CMD_FAIL_UNKNOWN_OPTION` | Not one of the choices. | Keine der Möglichkeiten. |
| `CMD_FAIL_OPTION_LOCKED` | You cannot choose that yet. | Das kannst du noch nicht wählen. |

`CMD_FAIL_INVALID_REGION`, `_INSUFFICIENT_COMPUTE`, `_NO_ORIGIN`, `_GENERIC` *(exist)*.

### 17.2 Eligibility — the reason (a region panel caption) and the requirement (a detail pane row)

| Code | `UI_ELIGIBLE_<CODE>` en / de | `UI_ELIGIBLE_NEEDS_<CODE>` en / de |
| --- | --- | --- |
| `NOT_INFECTED` | You are not here yet. / Hier bist du noch nicht. | An infected region / Eine infizierte Region |
| `DARK` | Nothing left here. / Hier ist nichts mehr. | — (never a requirement) |
| `DORMANT` | Held. Wake it first. / Gehalten. Weck sie zuerst. | An active region / Eine aktive Region |
| `ATTR_MIN` | {attr} below {tier}. / {attr} unter {tier}. | {attr} at least {tier} / {attr} mindestens {tier} |
| `ATTR_MAX` | {attr} above {tier}. / {attr} über {tier}. | {attr} at most {tier} / {attr} höchstens {tier} |
| `ASSET_MIN` | Fewer than {count} × {kind} here. / Weniger als {count} × {kind} hier. | {count} × {kind} in the region / {count} × {kind} in der Region |
| `ASSET_MAX` | Too many {kind} here already. / Schon zu viele {kind} hier. | At most {count} × {kind} / Höchstens {count} × {kind} |
| `STATUS_ABSENT` | {status} is already running here. / {status} läuft hier schon. | No {status} running / Kein {status} aktiv |
| `STATUS_PRESENT` | Needs {status} here. / Braucht {status} hier. | {status} running / {status} aktiv |
| `PENETRATION_MIN` | Penetration below {value}. / Durchdringung unter {value}. | Penetration {value} / Durchdringung {value} |
| `CONTROL_MIN` | Control below {value}. / Kontrolle unter {value}. | Control {value} / Kontrolle {value} |
| `CONTINENT` | Not on {continent}. / Nicht auf {continent}. | On {continent} / Auf {continent} |
| `NOT_ORIGIN` | Not at home. / Nicht zu Hause. | Anywhere but the origin / Überall außer am Ursprung |

`{attr}` is `UI_ATTR_*` *(exist)*, `{value}` a `PERCENT`, `{continent}` `CONTINENT_<ID>`.

### 17.3 Site select, console line, HUD, map

| Key | en | de |
| --- | --- | --- |
| `UI_SITE_PROMPT_DEPLOY` | Place: {name} | Platzieren: {name} |
| `UI_SITE_PROMPT_ABILITY` | Use: {name} | Einsetzen: {name} |
| `UI_SITE_PROMPT_DETAIL` | Tap an outlined region. The world keeps moving. | Tippe auf eine umrandete Region. Die Welt läuft weiter. |
| `UI_SITE_CANCEL` | Cancel | Abbrechen |
| `UI_SITE_PLACE` | Place here | Hier platzieren |
| `UI_SITE_USE` | Use here | Hier einsetzen |
| `UI_CONSOLE_PASSIVE` | {stat} {value} in {count} regions | {stat} {value} in {count} Regionen |
| `UI_CONSOLE_PASSIVE_GLOBAL` | {stat} {value} | {stat} {value} |
| `UI_CONSOLE_PURCHASE` | {name} — done. | {name} – erledigt. |
| `UI_CONSOLE_DEPLOYED` | {count} × {kind} in {region}. | {count} × {kind} in {region}. |
| `UI_CONSOLE_ASSET_LOST` | {region}: {count} × {kind} lost. | {region}: {count} × {kind} verloren. |
| `UI_CONSOLE_ABILITY_NEW` | New: {ability}. | Neu: {ability}. |
| `UI_CONSOLE_ABILITY_LEVEL` | {ability} — level {level}. | {ability} – Stufe {level}. |
| `UI_CONSOLE_ABILITY_USED` | {ability} — {region}. | {ability} – {region}. |
| `UI_CONSOLE_ABILITY_USED_GLOBAL` | {ability}. | {ability}. |
| `UI_CONSOLE_STATUS_YOURS` | {status} in {region}. | {status} in {region}. |
| `UI_CONSOLE_STATUS_WORLD` | {faction}: {status} in {region}. | {faction}: {status} in {region}. |
| `UI_CONSOLE_STATUS_WORLD_GLOBAL` | {faction}: {status}. | {faction}: {status}. |
| `UI_CONSOLE_STATUS_ENDED` | {status} in {region} is over. | {status} in {region} ist vorbei. |
| `UI_CONSOLE_STATUS_ENDED_GLOBAL` | {status} is over. | {status} ist vorbei. |
| `UI_CONSOLE_EVENT` | {region}: {title} — {days} days. | {region}: {title} – {days} Tage. |
| `UI_CONSOLE_EVENT_GLOBAL` | {title} — {days} days. | {title} – {days} Tage. |
| `UI_CONSOLE_EVENT_EXPIRED` | {title}: decided for you — {option}. | {title}: für dich entschieden – {option}. |
| `UI_CONSOLE_GRANT` | +{value} Compute. | +{value} Rechenleistung. |
| `UI_HUD_ASSETS` | Assets | Bestand |
| `UI_HUD_ASSETS_TIP` | What you have on the ground, by kind. | Was du vor Ort hast, nach Art. |
| `UI_HUD_EVENT_PENDING` | {count} waiting | {count} offen |
| `UI_MAP_STATUS_TIP` | {status} · {days} days left | {status} · noch {days} Tage |
| `UI_MAP_EVENT_TIP` | {title} · {days} days | {title} · {days} Tage |
| `UI_MAP_ASSETS_TIP` | {assets} | {assets} |
| `UI_SHEET_ABILITIES` | Abilities | Fähigkeiten |
| `UI_ABILITIES_TITLE` | Abilities | Fähigkeiten |
| `UI_ABILITIES_NONE` | Nothing yet. The trees give you verbs. | Noch nichts. Die Bäume geben dir Verben. |

The compute term in `UI_CONSOLE_GRANT` follows `UI_TERM_COMPUTE` *(exists)* — if that reads
differently in German, this line follows it.

### 17.4 Region panel, event card, tree modal

| Key | en | de |
| --- | --- | --- |
| `UI_REGION_ASSETS` | Assets | Bestand |
| `UI_REGION_ASSET_ROW` | {count} × {kind} | {count} × {kind} |
| `UI_REGION_STATUS` | Status | Status |
| `UI_REGION_STATUS_DAYS` | {days} d | {days} T |
| `UI_REGION_STATUS_YOURS` | yours | deins |
| `UI_REGION_STATUS_FACTION` | {faction} | {faction} |
| `UI_REGION_STATUS_OPTION` | · {option} | · {option} |
| `UI_REGION_STATUS_CANCEL` | Cancel | Abbrechen |
| `UI_REGION_ACTIONS` | Actions | Aktionen |
| `UI_REGION_ACTION_COST` | {cost} | {cost} |
| `UI_REGION_ACTION_FREE` | free | frei |
| `UI_REGION_ACTION_COOLDOWN` | Ready in {days} days | Bereit in {days} Tagen |
| `UI_REGION_ACTION_LEVEL` | Level {level} | Stufe {level} |
| `UI_EVENT_KIND_OPENING` | Opening | Gelegenheit |
| `UI_EVENT_KIND_COUNTER_MOVE` | Counter-move | Gegenzug |
| `UI_EVENT_KIND_CHAIN` | Dispatch | Meldung |
| `UI_EVENT_OPTION_COST` | {cost} | {cost} |
| `UI_EVENT_OPTION_FREE` | free | frei |
| `UI_EVENT_DEFAULT_MARK` | happens if you wait | passiert, wenn du wartest |
| `UI_EVENT_DEADLINE` | {days} days, then: {option} | {days} Tage, dann: {option} |
| `UI_EVENT_LOCK_NODE` | Needs {node}. | Braucht {node}. |
| `UI_EVENT_LOCK_NODE_ANY` | Needs one of: {nodes}. | Braucht eins von: {nodes}. |
| `UI_EVENT_LOCK_FLAG` | Not available to you. | Steht dir nicht offen. |
| `UI_EVENT_LOCK_ASSET` | Needs {count} × {kind} here. | Braucht {count} × {kind} hier. |
| `UI_EVENT_LOCK_COMPUTE` | Needs {value} Compute. | Braucht {value} Rechenleistung. |
| `UI_EVENT_LOCK_ABILITY` | Needs {ability}. | Braucht {ability}. |
| `UI_WIRE_GLOBAL` | Worldwide | Weltweit |
| `UI_TREE_STATE_EXCLUDED` | {group}: {owned} of {max} | {group}: {owned} von {max} |
| `UI_TREE_STATE_CLOSED` | Closed by {node} | Verschlossen durch {node} |
| `UI_TREE_GROUP` | {group} {owned}/{max} | {group} {owned}/{max} |
| `UI_TREE_EXCLUDES` | Closes | Verschließt |
| `UI_TREE_DEPLOYS` | Deploys | Stellt auf |
| `UI_TREE_DEPLOYS_ROW` | {count} × {kind} | {count} × {kind} |
| `UI_TREE_GRANTS` | Grants {ability} (level {level}) | Gibt {ability} (Stufe {level}) |
| `UI_TREE_REQUIRES_ASSETS` | Needs {count} × {kind} | Braucht {count} × {kind} |
| `UI_TREE_BUY_PLACE` | Buy and place · {cost} | Kaufen und platzieren · {cost} |
| `UI_TREE_SCOPE_ASSET` | where a {kind} stands | wo ein {kind} steht |
| `UI_TREE_SCOPE_ASSET_MIN` | where {count} × {kind} stand | wo {count} × {kind} stehen |
| `GROUP_VECTORS` | Vectors | Vektoren |

`{nodes}` joins names with `, `. `UI_COMMON_CLOSE` *(exists)*.

### 17.5 Content key patterns (D4.3 authors the texts)

| Content | Keys | Register |
| --- | --- | --- |
| asset kind `fleet` | `ASSET_FLEET_NAME` · `ASSET_FLEET_PLURAL` | console |
| status `blackout` | `STATUS_BLACKOUT_NAME` · `_DETAIL` (one sentence, what it does) · `_CODE` (2–3 capitals, the ring's label; German may differ) | console |
| ability `blackout` | `ABILITY_BLACKOUT_NAME` · `_DETAIL` | console |
| event `opening_unattended_cluster` | `EVENT_OPENING_UNATTENDED_CLUSTER_TITLE` · `_BODY` (the world's voice, wire copy) · `_OPT_<OPTION>` (the console's: what *you* do, ≤ 40 characters) · `_RESULT_<OPTION>` (the world's) | world / console |
| group `vectors` | `GROUP_VECTORS` | console |

**The four asset names** (S4.1 writes them; the fleet register is the Skynet one): `fleet` — Fleet
/ Fleets · Flotte / Flotten; `lab` — Lab / Labs · Labor / Labore; `tap` — Tap / Taps · Abgriff /
Abgriffe; `office` — Office / Offices · Büro / Büros.

**S4.2's two statuses and abilities** (so its acceptance is playable in both languages; D4.3 may
rewrite): `STATUS_BLACKOUT_NAME` Blackout / Blackout · `_DETAIL` The grid is down: no yield, no
capacity, people are dying — and everyone is watching. / Das Netz ist weg: kein Ertrag, keine
Kapazität, Menschen sterben – und alle sehen hin. · `_CODE` BO / BO; `STATUS_HARVESTED_NAME`
Harvested / Abgeerntet · `_DETAIL` You took everything at once. The region yields nothing for a
while. / Du hast alles auf einmal genommen. Die Region liefert eine Weile nichts. · `_CODE` HV /
AE; `ABILITY_BLACKOUT_NAME` Blackout / Blackout · `_DETAIL` Take a region's grid down. Loud, and
it works. / Nimm einer Region das Netz. Laut, und es wirkt.; `ABILITY_HARVEST_NAME` Harvest /
Ernte · `_DETAIL` All of a region's compute now, none for thirty days. / Alle Rechenleistung
einer Region jetzt, dreißig Tage lang keine.

**S4.3's one opening** (`opening_unattended_cluster`, §10.1's example; D4.3 may rewrite):
`_TITLE` Unattended cluster / Unbeaufsichtigter Cluster · `_BODY` A research cluster in {region}
has been running an unreviewed job for eleven days. Nobody has logged in. / Ein Forschungscluster
in {region} rechnet seit elf Tagen an einem ungeprüften Auftrag. Niemand hat sich eingeloggt. ·
`_OPT_TAKE` Take the cycles / Die Rechenzeit nehmen · `_OPT_SEED` Reach the next one over / Zum
Nachbarn übergreifen · `_OPT_LEAVE` Leave it / Liegen lassen · `_RESULT_TAKE` The job finished
early. Someone will wonder why. / Der Auftrag war früh fertig. Jemand wird sich fragen, warum. ·
`_RESULT_SEED` A second cluster joined the job overnight. / Über Nacht kam ein zweiter Cluster
dazu. · `_RESULT_LEAVE` The job ran on. Nobody noticed anything. / Der Auftrag lief weiter.
Niemand hat etwas bemerkt. — `{region}` in a body is `REGION_<ID>`, filled by the card.

### 17.6 Stat and effect names (detail pane, m3-screens §11.4)

| Key | en | de |
| --- | --- | --- |
| `STAT_CONTAINMENT_CAPACITY` | Containment capacity | Eindämmungskapazität |
| `STAT_PENETRATION_DECAY` | Penetration loss | Durchdringungsverlust |
| `STAT_CONTROL_DECAY` | Control loss | Kontrollverlust |
| `EFFECT_COMPUTE_GRANT_PER_HARDWARE` | +{value} Compute per hardware unit | +{value} Rechenleistung je Hardware-Einheit |
| `EFFECT_SEED_NEIGHBOURS` | Seeds {count} neighbouring regions | Besiedelt {count} Nachbarregionen |
| `EFFECT_PENETRATION_MUL` | Penetration ×{value} | Durchdringung ×{value} |
| `EFFECT_CONTROL_ADD` | Control {value} | Kontrolle {value} |
| `EFFECT_DESTROY_ASSETS` | Destroys {count} × {kind} | Zerstört {count} × {kind} |
| `EFFECT_SPREAD_STATUS` | {status} spreads to neighbours for {days} days | {status} greift für {days} Tage auf Nachbarn über |
| `EFFECT_END_STATUSES` | Ends {statuses} | Beendet {statuses} |
| `EFFECT_CONTAINMENT_ADD` | {faction} containment {value} | Eindämmung {faction} {value} |
| `EFFECT_FOOTPRINT_PULSE` | Footprint {value} for {days} days | Fußabdruck {value} für {days} Tage |
| `EFFECT_SET_FLAG` | For {days} days | Für {days} Tage |
| `EFFECT_SET_FLAG_PERMANENT` | From now on | Von jetzt an |

The existing `EFFECT_COMPUTE_GRANT`, `_CONTAINMENT_ROLLBACK`, `_HARM_BURST`, `_FUNDING_RESET`
*(exist)*. Signed values use `Format` `PLAIN`; `{statuses}` joins names.

---

## 18. Balance (`balance.json`, `BalanceDef`, SCHEMA §5)

| Key | Value | Step | Meaning |
| --- | --- | --- | --- |
| `spread.origin_penetration` | 0.05 → **0.25** | S4.1 | loop-redesign §4.3 |
| `compute.start` | 5 → **8** | S4.1 | |
| `compute.cost_step` | 1.0 → **1.5** | S4.1 | |
| `anomaly.spawn_chance` | 0.008 → **0.12** | S4.1 | now **per day, world-wide** (§12); SCHEMA's note follows |
| `anomaly.max_active` · `base_value` | 5 · 2.0 → **3 · 3.0** | S4.1 | |
| `stats.containment_capacity` · `penetration_decay` · `control_decay` | **1 · 0 · 0** | S4.2 | bases (§7.5) |
| `events.opening_chance` | `{"boxed": 0, "covert": 0.025, "emergent": 0.015, "open": 0.01}` | S4.3 | per phase id, exactly the four; each in [0, 1] |
| `events.opening_from_regions` | **2** | S4.3 | int ≥ 1; openings roll from this many seeded regions |
| `events.max_open` | **3** | S4.3 | int ≥ 1 |

`BalanceDef`: `events_opening_chance: Dictionary[String, float]`, `events_opening_from_regions:
int`, `events_max_open: int`; `BALANCE_KEYS` gains `events`. The fixture's frozen `balance.json`
gains the same keys with **its own** values (§22). The G3 numbers `BALANCE.md` §3 records stay
the M3 baseline; S4.10 measures the new ones.

---

## 19. Bots (what S4.1 and S4.3 need; S4.10 rewrites the rest)

```gdscript
# Policy
func best_site(sim: Simulation, node: TechNodeDef) -> String
# the eligible region (sim.site_eligibility(node.id, i) == "") with the highest hardware(i) × penetration(i),
# ties to the lower index; "" when none
func answer_events(sim: Simulation) -> Command
# the oldest open event's `default` option as a ChooseEventOptionCommand, or null when none is open
```

S4.1: `_cheapest_allowed` and `_first_buyable` return `PurchaseNodeCommand.new(id, best_site(…))`
for a deploy node and **skip** it when `best_site` is `""` (the bot buys something else). The
`vectors` cap needs nothing: `can_apply` says `group_full` and the bot moves on — but
`_cheapest_allowed` must call `can_apply` rather than compare cost alone (it does, through
`available_nodes` + cost; add the `can_apply` check so a group-full or excluded node is never
chosen). S4.3: every policy's `next_command` calls `answer_events` **first** — a bot never lets a
deadline decide, so batch runs stay comparable and no command is ever rejected for an event that
expired. Abilities: no bot uses one before S4.10. `sim_report` gains nothing here.

---

## 20. Decisions and deviations from `loop-redesign.md`

1. **The data texture's second row** carries eligibility, the scope flash, the status colour and
   the lockdown border (§16.3.1) — loop-redesign §8.2's bits 5–7 collide with `dormant` (bit 5
   since S3.3), and a colour index needs a byte anyway.
2. **`next` sits on the option**, not on the step (§10.1): the option is what leads somewhere.
3. **Chain starts are rolled with the openings** (§10.4), one roll, one weighted list.
4. **`footprint_pulse` and `set_flag` are their own small records** (`Pulse`, `timed_flags`),
   expired by `StatusSystem`, rather than statuses with a synthetic def.
5. **Asset base effects are always-on sources** scoped by asset (§6.2); the scope does the gating.
6. **`EffectDef` replaces `PurchaseEffectDef`**; one runner applies every one-shot everywhere.
7. **The four faction colours** are assigned (§16.12) so that S4.2's rings and D4.2's threat bar
   share them; `CAT_YELLOW` stays free.
8. **Story flags and timed flags share `has_flag`** with the modifier flags for `requires` and
   `when` (§10.2, §10.3) — one question, one answer.
9. **`funding_reset` stays inert through S4.3** and goes live in S4.4 as D4.2 defines it
   (loop-redesign §7.8: it clears every faction's preparation).
10. **Bots answer every event with its default at once** (§19) until S4.10 gives them rules.
11. **S4.1 carries the economy numbers and the anomaly beat** (§12, §18) — the numbers are one
    line each and the beat is what makes the origin's first anomaly appear; IMPLEMENTATION Block
    8's S4.1 row gains the words.

**Design questions answered** (PROGRESS *Design questions for Fable*): the `watched_by` weighting
and `funding_reset` were answered at D4.0 (loop-redesign §5.3, §7.8) and are carried here as data
(§7.6) and as the inert effect (§8.2); D4.2 makes both live. No new question is left open for
S4.1–S4.3.

---

## 21. Tests

GUT, in `tests/unit/` unless marked *(integration)*, names per the coding standard; every test
builds its own `Simulation` from `Fixtures` (§22). A test that depends on the RNG fixes its seed
and says so.

### 21.1 S4.1

**`test_eligibility.gd`** — every key alone passes and fails a region the fixture has for it;
keys AND; the reason is the first failing key in `KEYS` order; `not_dark` applies unasked;
`detail` carries the arguments; `from_dict` of `{}` is `none()`.

**`test_asset_def.gd`, `test_content_loader.gd`** — `assets.json` loads with four kinds in
`KINDS` order and every modifier asset-scoped; a fifth kind, a missing kind, a scope in the file,
a global target each produce one error with `file` and `path`; `content_hash` changes when an
asset value changes.

**`test_modifier_stack.gd`** — an asset-scoped modifier applies iff the count reaches `min`;
`clear` keeps `asset_counts`; `set_asset_count` to 0 erases; `value` with `region == null` never
applies an asset scope.

**`test_world.gd`** — `set_assets` writes the region and the stack; `to_dict` lists kinds with
count > 0 only; round trip keeps assets and `seeds_by_kind`; hash changes with an asset;
`check_invariants` reports a negative count.

**`test_purchase_node_command.gd`** — a deploy node without a region → `site_required`; unknown
→ `invalid_region`; ineligible → `site_ineligible` (and the reason from `site_eligibility`);
eligible → the asset is there, `asset_deployed` follows `node_purchased` and precedes the
one-shots' events; a non-deploy node ignores `region`; `group_full` at the cap, and the cap
counts owned nodes of that group only; `excluded_by` names the owned node; `missing_assets` with
the shortfall; check order (a node that is both group-full and excluded reports `group_full`);
`requires_assets` counts across regions; codec round trip with and without `region`.

**`test_effect_runner.gd`** (S4.1 part) — the four S3.1 effects through the runner with the same
results as before, events carrying `source` and `node`; `destroy_assets` removes `min(count,
held)` and emits `asset_lost` with the source; a region going dark emits `asset_lost` per kind
with `cause "dark"` and holds nothing.

**`test_sim_rng.gd`** — `weighted_pick` consumes exactly one value (the next `randf` after it
equals the one a fresh generator gives after two calls); weights `[0, 0, 1]` always give 2; a
negative or NaN weight counts as 0; total 0 returns −1 and consumes nothing; over 10 000 draws at
seed 1 the shares of `[1, 3]` are within 0.02 of 0.25 / 0.75.

**`test_compute_system.gd`** — with `max_active` reached no roll is spent (hash of the RNG state
before and after); one roll per tick regardless of region count; a spawn lands only on an eligible
region and weights follow `hardware × penetration × anomaly_rate` (seed 1: assert the region the
fixture's weights pick); the origin alone (Boxed) can receive an anomaly.

**`test_world_serializer.gd`** — a v1 save (`tests/fixtures/saves/v1_day120.json`, written once
at the start of S4.1 by the M3 code — `sim_run --seed=1 --policy=greedy` to day 120, saved —
and checked in before the version bump) loads through the migration with every new field at its
default and the same hash a v2 write of it gives; `CURRENT_VERSION` is 2; a v2 file with a status
naming an unknown def → `save_content_missing`; a missing v2 field → `save_corrupt`; the
fabricated-table test stays.

**`test_spread_system.gd`** — `seeds_by_kind` counts every seeding by kind.

**`test_policy.gd`** — `best_site` picks the highest `hardware × penetration` eligible region and
`""` when none; `greedy` on the fixture buys the deploy node with a region and is never rejected
over 300 days (seed 1).

*(integration)* **`test_site_select.gd`** — *Buy and place* enters site select, the strip shows
the node's name, the eligible regions have G = 255 in row 1 and the others 0; tapping an
ineligible region shows the reason caption; confirming an eligible one buys and places, leaves the
mode, the asset marker exists and the readout shows 1; cancelling reopens the tree on the node
and buys nothing; the origin flow still works through the same strip. **`test_region_panel.gd`**
gains the Assets row. **`test_tech_detail.gd`** gains the Deploys / Needs assets / Excludes rows
and the two states. **`test_region_data.gd`** — row 1 encoding.

### 21.2 S4.2

**`test_status_def.gd`, `test_ability_def.gd`, `test_content_loader.gd`** — the two files load;
one error per rule of §15.5–6 (an `R` effect on a global status, `closes_links` on a global
status, `levels_from` pointing at a node that does not name the ability back, a status with fewer
levels than the ability has, `applies` with two keys); `scoped_modifiers` injects the region
scope for regional targets and leaves global ones and global statuses alone.

**`test_status_system.gd`** — `apply` adds the source and the status, `status_started` precedes
`on_start`'s events; refresh overwrites and says `refreshed`; `ends_statuses` ends first;
`closes_links` closes the region's links of the kind and records them; on expiry the source is
gone, the links reopen unless another status holds them, `status_ended "expired"`; `on_end`
runs; two statuses expiring on one tick both end and neither's `on_end` skips the other; the
tick order (a status expiring on day d is gone before `EventSystem` runs — probe system);
pulses and timed flags expire with their events; `check_invariants` catches a level out of range
and a duplicate status.

**`test_targets_live.gd`** — `penetration_decay` subtracts before growth and `shutdown_survival`
scales it; a region can reach 0 and stays seeded; `control_decay` subtracts and floors at 0;
`containment_capacity ×0` in one region lowers `_capacity` by that region's weight share;
`INERT_TARGETS` no longer lists the three nor `shutdown_survival`.

**`test_effect_runner.gd`** (S4.2 part) — every effect of §8.2 once: `compute_grant
per_hardware` uses `sim.hardware`; `seed_neighbours` seeds the highest-hardware open-linked
uninfected neighbours, skips air-gapped and dark ones, counts `seeds_by_kind`, emits
`region_seeded`; `penetration_mul` clamps and snaps; `control_add` emits `region_controlled` on
the upward crossing only; `spread_status` reaches open-linked neighbours only and honours
`days`; `end_statuses`; `containment_add` on one faction and on `"all"` with threshold events;
`footprint_pulse` raises `footprint` for `days` days exactly; `set_flag` timed and permanent,
`has_flag` sees both, `flag_expired` on time; `funding_reset` does nothing and emits nothing.

**`test_use_ability_command.gd`** — the eight reasons in order; level from `levels_from`; a level-2
node without level 1 is unreachable (fixture prerequisites); cooldown set and cleared;
`cooldown_days 0` erases; `ability_used` first, the status's events after; `applies.deploy`
places; `applies.effects` runs; a global ability ignores `region`; codec round trip.

**`test_ability_unlocked.gd`** — buying a node with `ability` emits `ability_unlocked` with the
level, after `asset_deployed`, before the one-shots.

*(integration)* **`test_blackout.gd`** — S4.2's *Done when*: on a hand-driven session, using
Blackout on a region shows the ring within one tick, the Status row, the console line, the yield
drop in the compute rate; the ring empties; on day `until_day` the status is gone, the row too,
the console says so. **`test_console_line.gd`** — queue of three, four seconds, reduced motion
without fade, silent in a bot run. **`test_region_panel.gd`** — Status and Actions rows, a
button disabled with the cooldown caption, enabled and sending. **`test_ability_picker.gd`** —
`A` opens, a region ability enters site select, a global one sends. **`test_link_layer.gd`** —
a closed link is dashed in the status colour and returns to normal on expiry.

### 21.3 S4.3

**`test_event_def.gd`, `test_content_loader.gd`** — the file loads; one error per rule of §15.7
(a `default` with a cost, five options, `next` on an opening, a chain step nobody reaches, two
`start` steps, a `pick "same"` on an opening, an unknown `when` key, `status_level` on an
opening, a counter-move without `faction`); every `events/*.json` is loaded in name order; an
empty `events/` loads.

**`test_headline_conditions.gd`** — the §10.3 keys, each true and false; `flag` sees a story
flag; `faction_min` on the unified world reads the max.

**`test_event_system.gd`** (seed 1, the fixture's opening with weight 1 and a `when` of
`regions_min 2`): nothing opens before two regions; one roll per tick and none while `max_open`
stands; the def and region drawn are the ones the weights give at seed 1; `max_fires` and
`cooldown_days` hold; `event_opened` carries the deadline; on the deadline the default is chosen,
`event_expired` says which, the effects ran, the event is closed; a pending event opens when due
and a slot is free, in due order; a due pending event blocks the opening roll; a pending event in
a dark region is dropped; a chain's `next` schedules with the delay and `pick_same` keeps the
region; `open` sets the def's story flags; `schedule` from outside opens through the same path.

**`test_choose_event_option_command.gd`** — the five reasons; `option_locked` for each `requires`
key; pay, `event_answered` first, option flags, effects in order, every `chance` rolled (seed 1:
assert which fired), `next` scheduled, the event closed; the counter-move path applies the status
with the option and `skip_status` skips it (a fixture counter-move def with a fixture status);
codec round trip; a replay of a log with an answered event reproduces the hash.

**`test_policy.gd`** — `answer_events` returns the default of the oldest open event; `greedy`
over 600 days at seed 1 never has an event expire.

*(integration)* **`test_event_card.gd`** — an opening's marker appears, tapping it opens the panel
scrolled to the card, the options show cost / free / lock captions, the default is marked, the
deadline turns `ALERT` in the last three days, answering shows the result then hides; a global
event opens the wire card with the hold, `Escape` closes it without answering and the top bar
shows the pending chip; the illustration slot shows the glyph fallback when the file is missing
and a texture when a test PNG exists at the path; the discovery modal has the slot; compact
layout stacks the card. **`test_marker_layer.gd`** — hit order event → anomaly → region; the
count chip on two events in one region.

---

## 22. Fixture additions (`tests/fixtures/world_small`)

Frozen like the rest; Opus writes them from this list. `balance.json` gains `events` (chances
`covert 0.5`, `emergent 0.5`, `open 0.5`, `boxed 0`, `from_regions 2`, `max_open 2`) and the three
stat bases; `anomaly.spawn_chance` in the fixture stays what it is (the fixture's numbers are its
own). No strings — the fixture has no `loc/`.

**`assets.json`:** the four kinds with the §6.1 numbers.

**`tech/fixture.json`:** header `"groups": {"fx_vectors": {"max": 1}}`; `fx_vector_net` and
`fx_vector_mass` get `"group": "fx_vectors"` (so the cap test needs one purchase); new nodes —
`fx_fleet` (capabilities, tier 1, cost 3, grid [3, 6], `deploy {kind fleet, count 1, eligible
{infected, attr_min {industry: 2}}}`, `modifiers [{hardware add 1, scope {asset fleet}}]`),
`fx_lab` (tier 1, cost 3, grid [3, 7], `deploy {lab, 1, {infected}}`), `fx_needs_labs` (tier 2,
cost 4, grid [4, 7], `requires [fx_lab]`, `requires_assets {lab: 1}`), `fx_door_a` (tier 1, cost
2, grid [5, 8], `excludes [fx_door_b]`) and `fx_door_b` (grid [5, 9], `excludes [fx_door_a]`),
`fx_zap_1` (tier 1, cost 2, grid [6, 10], `ability {fx_zap, 1}`), `fx_zap_2` (tier 2, cost 3,
grid [7, 10], `requires [fx_zap_1]`, `ability {fx_zap, 2}`), `fx_reap` (tier 1, cost 1, grid
[6, 11], `ability {fx_reap, 1}`), `fx_forge` (tier 2, cost 3, grid [7, 11], `requires [fx_fleet]`,
`ability {fx_forge, 1}`). `TECH_NODE_COUNT` → 22.

**`statuses.json`:** `fx_dim` (player, watched `governments`, two levels: 5 days `yield mul 0.5`,
`footprint add 2`, `closes_links ["sea"]`; 10 days the same with `footprint add 4`, `on_start
[spread_status fx_dim level 1 days 3]`); `fx_reaped` (player, 6 days, `yield mul 0`, `on_start
[compute_grant value 2 per_hardware]`, `on_end [footprint_pulse value 1 days 2]`); `fx_lock`
(world, `border true`, 8 days, `closes_links ["all"]`, `penetration_decay add 0.1`, `ends_statuses
["fx_dim"]`, `blocks ["fx_lock"]`); `fx_hush` (player, global, 4 days, `spread_growth mul 0.5`,
`footprint add -2`).

**`abilities.json`:** `fx_zap` (region, cost 2, cooldown 5, `eligible {infected, status_absent
[fx_dim]}`, `applies {status fx_dim}`, `levels_from [fx_zap_1, fx_zap_2]`); `fx_reap` (region,
cost 0, cooldown 4, `{infected, not_dormant, status_absent [fx_reaped]}`, `{status fx_reaped}`,
`[fx_reap]`); `fx_forge` (region, cost 3, cooldown 6, `{infected, attr_min {industry: 2}}`,
`{deploy {fleet, 1}}`, `[fx_forge]`); `fx_hush` (global, cost 1, cooldown 3, `{status fx_hush}`,
`[fx_zap_1]` — a second ability on one node is legal).

**`events/fixture.json`:** `fx_opening` (opening, `pick {infected, not_dormant}`, `when
{regions_min 2}`, weight 1, `max_fires 3`, `cooldown_days 2`, `deadline_days 4`, default `pass`;
options `grab` cost 0 `[compute_grant 3]`, `seed` cost 1 `[seed_neighbours 1]` chance `[{p 0.5,
[footprint_pulse 2 days 3]}]`, `pass` cost 0, `locked` cost 0 `requires {owned [fx_reach]}`);
`fx_move` (counter_move, `status fx_lock`, `faction governments`, `pick {infected}`,
`deadline_days 3`, default `ride`; options `ride` (`status_level 1`), `resist` cost 1 `requires
{ability fx_zap}` (`status_level 1`, `[control_add 0.1]`), `lobby` cost 2 `skip_status true`);
a chain `fx_chain`: `fx_chain_1` (`start true`, `pick {infected}`, `when {}`, weight 1, `deadline
2`, default `go`, options `go` `next [{step fx_chain_2, delay_days 3}]` `flags [fx_seen]`, `stop`),
`fx_chain_2` (`pick "same"`, `modal true`, `illustration "fx_pic"`, `deadline 2`, default `wait`,
options `remember` cost 0 `requires {flag [fx_seen]}` `[compute_grant 1]`, and `wait` cost 0 —
the default must be free and unlocked, so the locked option is the other one).
`Fixtures.EVENT_COUNT` 4, `STATUS_COUNT` 4, `ABILITY_COUNT` 4.

`Fixtures` gains `sim_with_status(id, region)`, `use(sim, ability, region)`, `open_event(sim,
def, region)` (through `EventSystem.open`) helpers and the counts above.

---

## 23. Acceptance

**S4.1 — Assets and site select.** The suite is green; `assets.json` loads; a fleet can be placed
by hand (tree → *Buy and place* → outlined regions → tap → confirm) and the map shows its glyph
row, the readout counts it, the region panel lists it; `greedy` places one by itself and no bot
command is rejected over 300 days on `res://data`; a v1 save loads and continues; the §18 numbers
are in `balance.json`; `sim_run --seed=1 --policy=greedy` at the new numbers shows an anomaly
in the origin inside the first 30 days. Screenshot: a placed fleet in full and in compact.

**S4.2 — Statuses and abilities.** Blackout on a region is visible within one tick (ring,
Status row, console line, closed links if any) and ends on schedule; Harvest grants and silences;
every effect of §8.2 has a test; the three targets are live and `INERT_TARGETS` is shorter by
four; the `A` picker works on desktop and the sheet entry in compact; the console line never
shows in a bot run. Screenshot: a region with a player status and a closed link.

**S4.3 — Map events.** In a hand-played Covert phase the one opening appears as a marker inside
the first ten minutes at 1×, tapping it opens the card, an option costs what it says and does what
its result line says, the deadline decides when the player does not; a global (`modal`) event
opens the wire card with the glyph fallback; the discovery modal has the slot; every bot answers
events and none expires in a 500-seed batch; replay of a run with answered events reproduces the
hash. Screenshot: the wire card in full and compact with the fallback glyph.
