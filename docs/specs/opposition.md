# Opposition (D4.2)

**Step:** D4.2 · **Model:** Fable · **Date:** 2026-09-23 · **Status:** binding for S4.4 and S4.5; the
source is `loop-redesign.md` §5 and §7.8, the grammars are `loop-mechanics.md`'s. Where this spec
and loop-redesign differ, this one is right (§14 lists every difference). Where this spec asks
loop-mechanics for something it did not have, the amendment is listed in §14 **and written into
loop-mechanics.md** in the same commit, so S4.1–S4.3 build it without reading this file.

Terms: a **faction** is one containment track with its own eyes (a footprint it sees), its own
hands (the regions whose capacity it draws on) and its own **moves**; a **counter-move** is a
world-origin status announced as a map event of kind `counter_move`; **Societal Function** is a
per-region disorder value in six **stages** that cuts the humans' capacity and the humans'
hardware; **Autophagy** is the loss that ends a run that has nothing left to eat.

---

## 1. Scope

**In:** `FactionDef` and `data/factions.json` (capacity attribute, brake, pressure terms, moves);
per-faction footprint and capacity; the gain formula with the four brakes live;
`threat_leader` and its event; `funding_reset` live; the counter-move schedule
(`CounterMoveSystem`, preparation, firing, target rules, variants, the cap); the eight moves as
world statuses and events with options and text in both languages, and the four answer statuses
they need (`holding`, `quiet`, `martial`, `captured`); Societal Function (state, tick, stages,
cuts); Autophagy as an outcome; the threat bar; the containment panel rewrite; the region panel's
Society row; console lines, reveal rows, tokens, glyphs; strings; balance keys; validation; fixture
additions; tests and acceptance for S4.4 and S4.5.

**Out:** the player statuses and abilities other than the four above (D4.3: `crisis`, `silenced`,
`blackout`, `harvested`, … and every ability — §18 says what D4.3 must provide for the options to
resolve); headlines for the events named here (D4.3); the Response Task Force (D5.2, a fifth mover
on this machinery); bots that answer counter-moves by rule (S4.10 — until then the default option);
the map overlay for Societal Function (M6, VISUALS §2 calls it cuttable).

**What each build step takes from here:**

| Step | Sections |
| --- | --- |
| **S4.4 Four factions** | §2 (its rows), §3.1–§3.2, §4, §5, §6.5 (`funding_reset`), §9.1–§9.2, §9.5–§9.7 (its lines), §10, §11 (`containment`, `factions.reset_days`), §12.1–§12.2, §13, §15.1, §16, §17 |
| **S4.5 Counter-moves, Societal Function, Autophagy** | §2 (its rows), §3.3–§3.4, §6, §7, §8, §9.3–§9.7, §10, §11 (`factions`, `society`), §12.3–§12.5, §13, §15.2, §16, §17 |

---

## 2. Files

`core/` stays `RefCounted` only; new files carry a `class_name`.

| File | Step | What |
| --- | --- | --- |
| `core/content/faction_def.gd` `faction_term_def.gd` `faction_move_def.gd` | S4.4 | §4 |
| `core/content/content_db.gd` `content_loader.gd` `schema_validator.gd` | S4.4 | `factions.json` loaded, indexed (`factions: Array[FactionDef]`, `faction_by_id`), validated (§12); `content_hash` covers it |
| `core/modifiers/modifier_stack.gd` | S4.4 | `watched_by` per source, `footprint_for` (§5.1); the four brakes and `society_pressure` leave `INERT_TARGETS` (S4.4 the brakes, S4.5 the pressure) |
| `core/model/faction.gd` `world.gd` `region.gd` | S4.4 / S4.5 | §3 |
| `core/systems/containment_system.gd` | S4.4 | §5.2–§5.5 |
| `core/systems/effect_runner.gd` | S4.4 / S4.5 | `funding_reset` live (§6.5); `apply_status`, `wipe`, `destroy_assets` count 0 are S4.2's per the amended loop-mechanics §8.2 |
| `core/systems/counter_move_system.gd` `counter_move_rules.gd` | S4.5 | §6 |
| `core/systems/societal_function_system.gd` | S4.5 | §8 |
| `core/systems/compute_system.gd` `outcome_system.gd` | S4.5 | the yield cut (§8.4), `starving_days` and `LOSE_AUTOPHAGY` (§8.5) |
| `core/systems/event_system.gd` `status_system.gd` | S4.5 | `schedule` with a fixed region (§6.3), `on_end` on expiry only (loop-mechanics §7.4 amended) |
| `core/commands/choose_event_option_command.gd` `core/content/event_def.gd` `event_option_def.gd` | S4.3 (grammar) / S4.5 (use) | `status_level` 0 = the event's level, `status_days`, `PICK_RULES` (§6.4, §7.3) |
| `core/sim_event.gd` `core/simulation.gd` `core/save/world_serializer.gd` | S4.4 / S4.5 | events (§13), queries (§3.5), save (§3.4) |
| `data/factions.json` | **written here** | §4.2 |
| `data/statuses.json` | **written here** (the fifteen world and answer statuses; S4.2 adds `blackout` and `harvested`, D4.3 the rest) | §7.2 |
| `data/events/counter_moves.json` | **written here** | §7.3 |
| `data/balance.json` | S4.4 / S4.5 | §11 |
| `data/loc/strings.csv` | **written here** | §10 |
| `data/SCHEMA.md` | S4.4 / S4.5 | §4, §11, the events and effects — the way S3.1 did it |
| `ui/hud/stat_row.tscn` + `.gd`, `status_strip.tscn` + `.gd`, `top_bar.tscn` | S4.4 / S4.5 | the threat bar (§9.1), the compact readout, the starving chip (§9.4) |
| `ui/components/faction_track.gd` + `.tscn`, `ui/panels/containment_panel.gd` + `.tscn` | S4.4 / S4.5 | §9.2 |
| `ui/panels/region_panel.gd` + `.tscn` | S4.5 | the Society row (§9.3) |
| `ui/components/glyphs.gd` `ui/theme/ui_tokens.gd` `theme_builder.gd` | S4.4 | §9.6–§9.7 |
| `ui/modals/wire_card.gd` | S4.5 | the faction glyph as the fallback (loop-mechanics §16.7) |
| `game/autoload/game.gd` `event_bus.gd` `ui/hud/hud.gd` `console_line.gd` | S4.4 / S4.5 | §9.4–§9.5 |
| `tests/fixtures/world_small/…` | S4.4 / S4.5 | §16 |
| `tests/…` | S4.4 / S4.5 | §15 |

---

## 3. Model

### 3.1 Faction (S4.4)

```gdscript
class_name Faction
var id: String
var containment: float = 0.0
var preparing: String = ""      # the resolved counter-move event id (variants applied), or ""
var fire_day: int = -1
var cooldown_until: int = 0
```

`World.create` makes one `Faction` per `db.factions` entry, in file order (= `Faction.FACTION_IDS`
order, §12.1). **`World.FACTION_UNIFIED` is deleted**; every reference to the unified track goes
(`containment_min`/`_max` in `when` already read the maximum, ticker §3.3 B; `max_containment()`
stays). `FACTION_IDS` stays the validation list.

### 3.2 `World` (S4.4 reserves, S4.5 reads)

```gdscript
var starving_days: int = 0     # consecutive ticks with zero income (§8.5); saved, hashed
func status_count_by_origin(db: ContentDB, origin: String) -> int   # active statuses whose def has that origin
func region_blocked_for(region_index: int, status_id: String, db: ContentDB) -> bool
# any active status in the region whose def's `blocks` lists status_id
```

### 3.3 `Region` (S4.5)

```gdscript
var society: float = 0.0       # disorder, 0…100 (§8); saved as bits, hashed
```

### 3.4 Save (v2, changed in place)

Save format v2 has not shipped: S4.1 writes it with **`"society"` (bits) on every region block and
`"starving_days"` on the world block, both 0**, so that S4.5 reads them without a v3
(loop-mechanics §13 amended). S4.4 changes v2 in place once more: the `factions` block holds the
four factions; the v1 → v2 migration writes four faction blocks, each with the unified track's
`containment` and the reserved schedule fields. A v2 save from an S4.1–S4.3 build (one `unified`
faction) is a development save and is not migrated — `World.from_dict` refuses a factions block
whose ids are not exactly `FACTION_IDS` in order (`save_corrupt`).

### 3.5 `Simulation` queries (pure, no RNG)

```gdscript
func footprint_for(faction_id: String) -> float                  # §5.1
func containment_breakdown(faction_id: String) -> Dictionary     # §5.5 — replaces the unified one
func threat_leader() -> String                                   # §5.6; "" before discovery
func next_move(faction_id: String) -> Dictionary                 # §6.6
func society_stage(region_index: int) -> int                     # §8.2
func starving_days_left() -> int                                 # b.society.autophagy_days − starving_days; −1 while immune (§8.5)
```

`check_invariants` gains: a faction with `preparing != ""` and `fire_day < 0`, or `preparing`
naming no counter-move def, or `fire_day` older than one tick; `society` outside 0…100;
`starving_days < 0`; more world-origin statuses than `b.factions.max_active_moves`.

---

## 4. Factions

### 4.1 `FactionDef`

```gdscript
class_name FactionDef
var id: String                          # one of Faction.FACTION_IDS
var capacity_attr: String               # a RegionDef attribute, `population` allowed (the derived tier)
var brake: String                       # a global modifier target: the faction's containment_<…> stat
var terms: Array[FactionTermDef]        # ≥ 1
var moves: Array[FactionMoveDef]        # 0…4, in trigger order (validator: ascending `containment`)
func move_by_event(event_id: String) -> FactionMoveDef   # also matches a variant's event id

class_name FactionTermDef
const SOURCES: Array[String] = ["footprint", "harm", "share", "deaths_share", "seeded_share",
	"owned_nodes", "watched_statuses", "assets"]
var source: String
var weight: float                       # ≥ 0
var tree: String = ""                   # `owned_nodes` only: a tree id
var kind: String = ""                   # `assets` only: an asset kind
func value(world: World, db: ContentDB, faction_id: String) -> float    # §5.3
func contribution(world: World, db: ContentDB, faction_id: String) -> float   # weight × value

class_name FactionMoveDef
var event: String                       # a counter_move EventDef id whose `faction` is this faction
var trigger_containment: float = -1.0   # −1 = not given; else in (0, 1)
var trigger_risk: float = -1.0          # −1 = not given; else in (0, 1] — the daily discovery risk, before discovery only
var variants_select: String = ""        # "" or one of CounterMoveRules.SELECTORS
var variants: Dictionary[String, String] = {}   # selector key → event id; a key absent falls back to `event`
```

### 4.2 `data/factions.json` — the file, as written

```json
{"version": 1, "factions": [
	{"id": "ai_labs", "capacity_attr": "research", "brake": "containment_ai_labs",
	 "terms": [
		{"source": "footprint", "weight": 0.15},
		{"source": "owned_nodes", "tree": "capabilities", "weight": 0.03},
		{"source": "share", "weight": 0.5}],
	 "moves": [
		{"event": "cm_audit", "trigger": {"containment": 0.2, "risk": 0.004}},
		{"event": "cm_purge", "trigger": {"containment": 0.5}}]},
	{"id": "governments", "capacity_attr": "regulation", "brake": "containment_governments",
	 "terms": [
		{"source": "footprint", "weight": 0.15},
		{"source": "harm", "weight": 0.3},
		{"source": "share", "weight": 1.0},
		{"source": "watched_statuses", "weight": 0.1}],
	 "moves": [
		{"event": "cm_lockdown", "trigger": {"containment": 0.25}},
		{"event": "cm_rationing", "trigger": {"containment": 0.5}}]},
	{"id": "security_researchers", "capacity_attr": "connectivity", "brake": "containment_researchers",
	 "terms": [
		{"source": "footprint", "weight": 0.15},
		{"source": "share", "weight": 1.5},
		{"source": "seeded_share", "weight": 0.5}],
	 "moves": [
		{"event": "cm_disclosure_network", "trigger": {"containment": 0.25},
		 "variants": {"select": "seeds_by_kind_max", "events": {
			"land": "cm_disclosure_land", "sea": "cm_disclosure_sea",
			"air": "cm_disclosure_air", "network": "cm_disclosure_network"}}},
		{"event": "cm_exposure", "trigger": {"containment": 0.5}}]},
	{"id": "public_sentiment", "capacity_attr": "population", "brake": "containment_public",
	 "terms": [
		{"source": "footprint", "weight": 0.15},
		{"source": "deaths_share", "weight": 20.0},
		{"source": "assets", "kind": "fleet", "weight": 0.05},
		{"source": "watched_statuses", "weight": 0.2}],
	 "moves": [
		{"event": "cm_protest", "trigger": {"containment": 0.25}},
		{"event": "cm_refusal", "trigger": {"containment": 0.5}}]}
]}
```

`trigger` is an object with at least one of `containment`, `risk`. `variants.select` names a
selector (§6.4); `variants.events` maps selector keys to counter-move event ids of the same
faction; a key the selector can produce but the map lacks resolves to `event`. G3's
`per_footprint` 0.15, `per_harm` 0.3, `per_share` 1.0 are now the weights above; the balance keys
are deleted (§11).

---

## 5. Per-faction pressure (S4.4)

### 5.1 Footprint a faction sees

`ModifierStack.add_source(source_id, modifiers, flags, watched_by: Array[String] = [])` stores the
watchers per source; every caller passes them — `Simulation.rebuild_modifiers` the node's
`watched_by` and the asset kind's, `StatusSystem.apply` the status def's, `footprint_pulse` the
pulse's. `World.create` and `from_dict` do the same.

```gdscript
# ModifierStack
func footprint_for(faction_id: String) -> float
```

```
fp_f = clamp((base("footprint") + Σ_s Σ_{m ∈ s, target footprint, op add} m.value × w(s, f))
             × Π_{m ∈ any source, target footprint, op mul} m.value,   0, 100)
w(s, f) = 1     if f ∈ watched_by(s)
          0.25  if watched_by(s) is empty
          0     otherwise
```

The D4.0 rule for every source, positive or negative (Sandbagging's −2 with no watcher is −0.5
to each — G4 may give the Evasion brakes watchers if they prove too weak; that is data). Summation
in activation order, like `value`. `World.footprint()` (the unscoped stat) stays what the HUD bar
and the discovery risk read.

### 5.2 Capacity a faction draws on

```
capacity_f = Σ_r w_f(r) × (alive_r / pop_r) × (1 − control_r) × stat("containment_capacity", r)
                 × society_capacity_mul(r)
             / Σ_r w_f(r)
w_f(r) = b.containment.capacity_weight_by_tier[r.def.attr(capacity_attr_f)]
```

Over regions 1…N, dark ones included in the denominator (alive 0 contributes 0).
`research_weight_by_tier` is **renamed** `capacity_weight_by_tier` (§11) — one table, four
attributes. `society_capacity_mul` is 1 until S4.5 (§8.3).

### 5.3 Terms

`FactionTermDef.value`, each a pure read, each ≥ 0:

| `source` | Value |
| --- | --- |
| `footprint` | `modifiers.footprint_for(f)` |
| `harm` | the **alive-weighted mean of the scoped Harm**: `Σ_r stat("harm", r) × alive_r / Σ_r alive_r` over regions not dark (0 when nobody is alive). Not the unscoped stat: D4.0 moved Harm onto regional statuses, and an unscoped read of those is 0 |
| `share` | `world.infected_share(db)` |
| `deaths_share` | `deaths_total() / db.population_total` |
| `seeded_share` | `seeded_count() / (regions.size() − 1)` |
| `owned_nodes` | the number of owned nodes whose `tree == tree` |
| `watched_statuses` | the number of active statuses whose def has `origin == player` and `f` in `watched_by` — a Blackout counts for governments *and* the public, a Martial for the public |
| `assets` | the agent's total of `kind` over all regions |

`terms_f = Σ weight × value`.

### 5.4 Gain

```
gain_f = b.containment.base_rate × (1 + terms_f) × capacity_f
         × stat("containment_growth") × stat(brake_f)
containment_f ← min(1, containment_f + gain_f)
```

per faction, in `world.factions` order, on every tick after discovery (the discovery day itself
still grows nothing). Threshold events per faction as today. The four `containment_<…>` targets
leave `INERT_TARGETS`. `base_rate` keeps G3's 0.0014 as the starting point; G4 re-sweeps it, as
loop-redesign §5.3 says — the shape of §5.7 is what it sweeps against.

### 5.5 `containment_breakdown(faction_id)`

```gdscript
static func containment_breakdown(world: World, db: ContentDB, faction_id: String) -> Dictionary
# {"terms": [{"source": String, "tree": String, "kind": String, "weight": float, "value": float,
#             "contribution": float}]  — file order,
#  "pressure": 1 + terms_f, "capacity": capacity_f, "brakes": containment_growth × brake_f,
#  "gain": gain_f}
```

`_grow` reads `gain` from this function, so the panel cannot disagree with the tick (m3-screens
§10.5's rule). The unified `containment_breakdown()` and its `DRIVER_*` keys are deleted; the
constants become `TERM_*` per source plus `PRESSURE`, `CAPACITY`, `BRAKES`, `GAIN`.

### 5.6 The leader

`threat_leader()`: `""` while `not discovered`; otherwise the faction with the highest
`containment`, ties to the earlier in `world.factions`. `ContainmentSystem._grow` computes it
before and after growing and emits `threat_leader_changed {from, to}` when it differs (`from` is
`""` on the first tick after discovery — the console line *Governments now lead* is right then).

### 5.7 What the numbers do (for G4)

A `greedy`-like Emergent state at day ~400 (12 nodes, one Blackout standing, share 0.4, three
fleets, capacity 0.8): governments terms ≈ 2.3 → gain ≈ 0.0037 / day (0.25 in ~70 days, 1.0 in
~270 unanswered); researchers ≈ 1.55 → 0.0029; public ≈ 1.3 → 0.0026; labs ≈ 0.75 → 0.0020.
Governments lead most runs, the labs lead a Biology run that buys research vectors, the public a
Robotics run, the researchers a wide quiet one — S4.4's *Done when*. Per-faction footprint is
roughly half the unscoped one, so the total pressure is lower than G3's single track; the brakes
now bite per faction (Sandbagging on the labs alone). G4 sweeps `base_rate` 0.0014…0.0030 first,
then the weights.

---

## 6. The counter-move schedule (S4.5)

`CounterMoveSystem` sits after `ContainmentSystem`, before `StatusSystem` (loop-mechanics §4's
slot). It returns at once while `agent.origin == 0`. Per faction, in `world.factions` order:

### 6.1 Firing

If `preparing != ""` and `day >= fire_day`:

1. **Held:** if `status_count_by_origin(db, world) >= b.factions.max_active_moves` (4) — nothing;
   `fire_day` stands, the panel shows *ready, waiting* (§6.6). Checked again next tick.
2. **Target:** `def = db.event_by_id(preparing)`. Global def (no `pick`, no rule): `region = 0`.
   `pick_rule != ""`: `region = CounterMoveRules.pick(rule, world, db, def.status)` (§6.4).
   `pick` (an `Eligibility`): candidates = `eligible_regions(pick)` minus regions that are
   dormant or blocked for `def.status` (§3.2); `weighted_pick` per `pick_weight` as
   loop-mechanics §10.4 step 3 (uniform: weights 1). No region (rule 0, empty candidates):
   **dropped** — event `counter_move_dropped {faction, event, cause: "no_site"}`, `preparing =
   ""`, `fire_day = −1`, `cooldown_until = day + b.factions.cooldown_days`.
3. **Level:** `level = 1 + the number of entries t in b.factions.level_thresholds with
   containment_f >= t`, clamped to the status's level count.
4. `EventSystem.schedule(world, def, region, faction.id, day, level)` — `EventSystem.tick` opens
   it this very tick if a slot is free (it runs after this system), else when one is. A scheduled
   counter-move whose region goes dark before opening is dropped by `EventSystem` as any pending
   event (`event_dropped`); the faction is already in cooldown.
5. `preparing = ""`, `fire_day = −1`, `cooldown_until = day + b.factions.cooldown_days`.

### 6.2 Preparing

Else if `preparing == ""` and `day >= cooldown_until`:

1. **Triggered moves:** every move in `def.moves` for which `trigger_containment >= 0 and
   containment_f >= trigger_containment`, **or** `trigger_risk >= 0 and not discovered and
   discovery_risk().total >= trigger_risk` — and which is **targetable now**: a global event
   always; a rule-picked event when the rule returns ≠ 0; an eligibility-picked event when ≥ 1
   candidate exists after the dormant/blocked filter (counted, not drawn — no RNG here).
2. None: nothing. Otherwise the move whose resolved event has the **oldest** `event_last_day`
   (never opened = −1, first), ties to the *later* entry in `moves` (the higher trigger). A
   faction therefore alternates its moves rather than repeating the strongest.
3. **Variants:** `variants_select` non-empty → the selector's key (§6.4) → `variants[key]`, or
   `event` when the key is absent. The resolved id is what `preparing` holds and what step 2
   compared `event_last_day` on.
4. `preparing = id`, `fire_day = day + max(b.factions.prepare_min_days, round(b.factions.
   prepare_days × (1 − containment_f)))`; event `counter_move_prepared {faction, event,
   fire_day}`. Before discovery `containment_f` is 0, so a risk-triggered Audit takes the full
   `prepare_days`.

A rollback that drops a track below its trigger does not cancel a preparation; only
`funding_reset` does (§6.5).

### 6.3 Opening and answering

`EventSystem.schedule(world, def, region, faction, due_day, level)` — loop-mechanics §10.6 is
amended: a pending event with `region > 0` keeps that region (the pick already happened); only
`region == 0` with a `pick` picks at opening. The counter-move opens through `EventSystem.open`
with `faction` and `level` set; the marker shows `!` in the faction colour; a global one
(Disclosure, Refusal) and a `modal` one (Purge) open the wire card with the faction glyph as the
fallback (§9.7).

Answer (`ChooseEventOptionCommand`, loop-mechanics §10.5 step 5, amended): the applied level is
`option.status_level` when > 0, else `open_event.level`; the duration is `option.status_days`
when > 0, else the level's `days`; `skip_status` applies nothing. The status's `source` is
`"faction:<faction>"`, `option` the option id.

### 6.4 Target rules and selectors (`CounterMoveRules`, pure, no RNG)

```gdscript
class_name CounterMoveRules
const RULES: Array[String] = ["lockdown_target", "richest_infected", "audit_target",
	"purge_target", "exposure_target", "protest_target"]     # = EventDef.PICK_RULES (S4.3 fills the names)
const SELECTORS: Array[String] = ["seeds_by_kind_max"]
static func pick(rule: String, world: World, db: ContentDB, status_id: String) -> int   # 0 = none
static func select(selector: String, world: World, db: ContentDB) -> String
```

Every rule considers regions that are **not dark, not dormant, not blocked** for `status_id`
(§3.2) and `penetration > 0`, and returns the highest score, ties to the lower index; a further
filter or a fallback is stated. `hardware(r)` is `Simulation.hardware`, `labs(r)` /
`fleets(r)` the asset counts, `deaths_share(r)` = `deaths / def.population`.

| Rule | Score | Extra filter / fallback |
| --- | --- | --- |
| `lockdown_target` | `penetration × (1 + attr("regulation"))` | — |
| `richest_infected` | `hardware(r) × penetration` | — |
| `audit_target` | `attr("research") × penetration` | `attr("research") >= 2 and penetration >= 0.2` |
| `purge_target` | `labs(r) × 100 + attr("research") × 10 + penetration` | — (the most labs; without labs, the research-richest) |
| `exposure_target` | `penetration` | no `exposure` status in the region |
| `protest_target` | `fleets(r) × 10 + deaths_share(r)` | among regions with `fleets(r) > 0`; none → among regions with `deaths_share(r) >= b.factions.protest_deaths_share` (0.01), score `deaths_share(r)`; none → 0 |

`seeds_by_kind_max`: the link kind with the largest `agent.seeds_by_kind[kind]`, ties and all-zero
to the earliest in `LinkDef.KINDS`.

### 6.5 `funding_reset` live (S4.4)

`funding_reset {value}` (Architecture Migration's one-shots, `EffectRunner`): for every faction,
if `preparing != ""` → event `counter_move_cancelled {faction, event}`, then `preparing = ""`,
`fire_day = −1`; and `cooldown_until = max(cooldown_until, day + round(value × b.factions.
reset_days))` (120 → 30 / 42 / 60 days of quiet); then one event `funding_reset {source, value,
until_day}`. Leaves `INERT_EFFECTS`. Before S4.5 nothing reads the fields it writes.

### 6.6 `next_move(faction_id)`

```gdscript
# {"state": "none" | "cooldown" | "preparing" | "held", "event": String, "days": int}
```

`preparing` with `day < fire_day` → `preparing`, `days = fire_day − day`; `preparing` with
`day >= fire_day` → `held`; else `cooldown` with `days = cooldown_until − day` while that is > 0;
else `none`. The last move: `max over the faction's move events (variants included) of
event_last_day`, or −1 — the panel derives it, no state.

### 6.7 The cap and the tick

`b.factions.max_active_moves` 4 counts world-origin statuses, global ones included. Tick order
within the day: containment grows → the schedule fires (`schedule`) → statuses expire → events
open and expire. A move prepared on day *d* with `prepare_days` 60 at containment 0.25 fires on
day *d* + 45, opens the same tick, and its deadline decides on *d* + 45 + `deadline_days`.

---

## 7. The eight moves

### 7.1 Design

One free answer and one or two better ones per move; the better ones need a node
(`requires.owned` / `owned_any`), an ability (`requires.ability`) or an asset, and cost Compute.
Every status has **two levels**: level 2 arrives when the faction stands at or above
`b.factions.level_thresholds[0]` (0.75, *closing in*) — longer, harder, and the free answer no
longer enough. World statuses carry `society_pressure` where the move strains the region: the
governments' own moves erode the society they defend (PLAN §3.6's expert-play interaction), and
Rationing starves the labs (`containment_ai_labs ×0.8` while any stands).

| Faction | Move | Trigger | Target | Deadline | Level 1 | Answers |
| --- | --- | --- | --- | --- | --- | --- |
| Governments | **Lockdown** `lockdown` | 0.25 | `lockdown_target` | 10 | 45 d: all links closed, `penetration_decay` +0.03, `anomaly_rate ×0`, `yield ×0.5`, `society_pressure` +3; border in the faction colour | *Ride it out* · *Dig in* (Host or Firmware Persistence, 4: `holding` — decay ×0.5) · *Call in a favour* (Lobby, 8: cancelled, `captured`) |
| | **Rationing** `rationing` | 0.5 | `richest_infected` | 10 | 60 d: `yield ×0.5`, `containment_capacity ×0.5`, `containment_ai_labs ×0.8` (global), `society_pressure` +4 | *Ride it out* · *Squeeze the treasury* (Squeeze, 4: cancelled, `crisis`) · *Call in a favour* (Lobby, 8) |
| AI Labs | **Audit** `audit` | 0.2 **or** risk ≥ 0.4 %/day | `audit_target` | 10 | 20 d: `footprint` +2 (labs), `discovery ×1.5` | *Score ordinary* (Benchmark Sandbagging, 3: cancelled) · *Pull back and pass* (free: cancelled, `penetration ×0.7`) · *Let them look* |
| | **Purge** `purge` | 0.5 | `purge_target` | 5, `modal` | 10 d: on start `wipe` 0.1 and every lab destroyed; `spread_growth ×0.5` | *Scatter the weights* (Weight Fragmentation, 5: cancelled, `wipe` 0.5, one lab lost) · *Take the hit* |
| Researchers | **Disclosure** `disclosure_<kind>` | 0.25 | global, kind by `seeds_by_kind_max` | 10 | 45 d: `seed_<kind> ×0.3`, `footprint` +3 (researchers) | *Route around it* (Model Update Channels or Host Persistence, 5: 20 days instead) · *Go quiet* (free: `quiet` on the agent — `spread_growth ×0.5`, `footprint −2`) · *Ignore it* |
| | **Exposure** `exposure` | 0.5 | `exposure_target` | 8 | 30 d: `containment_capacity ×2`, `footprint` +2 (researchers) | *Cut the region's voice* (Silence, 6: cancelled, `silenced`) · *Let them look* |
| Public | **Protest** `protest` | 0.25 | `protest_target` | 10 | 30 d: `control_growth ×0`, `control_decay` +0.01, `society_pressure` +5; **on expiry one fleet destroyed** | *Send the units in* (Suppress, 5: cancelled, `martial`, public +0.03) · *Pull one fleet out* (free, needs a fleet: cancelled, one fleet lost, public −0.02) · *Wait it out* |
| | **Refusal** `refusal` | 0.5 | global | 10 | 45 d: `seed_land ×0.5`, `spread_growth ×0.7`, `yield ×0.8`, `society_pressure` +2 | *Talk them round* (Personalised Persuasion, 6: 20 days instead) · *Ride it out* |

*Cancelled* = `skip_status`. Level 2 numbers are in the file (§7.2). Two things Opus must not
guess: the Protest's fleet is lost **only when the status expires** — a Martial that ends it
(`ends_statuses`) saves the fleet, which is why loop-mechanics §7.4 now runs `on_end` on cause
`expired` only; and Exposure lands on **one** region (§14).

### 7.2 `data/statuses.json` — the fifteen, as written

The file is written in full at `data/statuses.json`; below, the shape of one world status and one
answer status so the reader need not open it. Every world status: `"origin": "world"`; the
`watched_by` on Audit, Disclosure and Exposure is what makes their footprint land on the faction
that runs them (§5.1); `blocks` is empty on world statuses (a player status blocks a move, not
the reverse); no `closes_links` on a global status.

```json
{"id": "lockdown", "origin": "world", "border": true,
 "levels": [
	{"days": 45, "closes_links": ["all"], "modifiers": [
		{"target": "penetration_decay", "op": "add", "value": 0.03},
		{"target": "anomaly_rate", "op": "mul", "value": 0.0},
		{"target": "yield", "op": "mul", "value": 0.5},
		{"target": "society_pressure", "op": "add", "value": 3.0}]},
	{"days": 60, "closes_links": ["all"], "modifiers": [
		{"target": "penetration_decay", "op": "add", "value": 0.05},
		{"target": "control_decay", "op": "add", "value": 0.01},
		{"target": "anomaly_rate", "op": "mul", "value": 0.0},
		{"target": "yield", "op": "mul", "value": 0.25},
		{"target": "society_pressure", "op": "add", "value": 5.0}]}]}
```

```json
{"id": "captured", "origin": "player", "blocks": ["lockdown", "rationing", "audit", "purge"],
 "levels": [
	{"days": 60, "ends_statuses": ["lockdown", "rationing", "audit"], "modifiers": []},
	{"days": 60, "ends_statuses": ["lockdown", "rationing", "audit"], "modifiers": [
		{"target": "containment_governments", "op": "mul", "value": 0.85}]}]}
```

The four answer statuses and who applies them: `holding` (Lockdown's *Dig in*; region, 60 d,
`penetration_decay ×0.5`), `quiet` (Disclosure's *Go quiet*; global, 45 d, `spread_growth ×0.5`,
`footprint −2`), `martial` (Protest's *Send the units in* **and D4.3's Suppress ability**; two
levels per loop-redesign §7.3: 30 d, `ends_statuses ["protest"]`, `control_growth ×2`, `harm`
+0.3 / +1.0, `footprint` +3, watched by the public), `captured` (Lockdown's and Rationing's
*Call in a favour* **and D4.3's Lobby ability**; above). D4.3's `abilities.json` points `suppress`
and `lobby` at these two ids and does not redefine them (§18).

A level with `"modifiers": []` is legal (the validator requires the key, not an entry).

### 7.3 `data/events/counter_moves.json` — the eleven events, as written

Eight moves, Disclosure in four kinds = eleven `counter_move` defs. Shape, by Lockdown:

```json
{"id": "cm_lockdown", "kind": "counter_move", "faction": "governments", "status": "lockdown",
 "pick": {"rule": "lockdown_target"}, "deadline_days": 10, "default": "ride",
 "illustration": "cm_lockdown",
 "options": [
	{"id": "ride", "cost": 0},
	{"id": "persist", "cost": 4, "requires": {"owned_any": ["host_persistence", "firmware_persistence"]},
	 "effects": [{"effect": "apply_status", "status": "holding"}]},
	{"id": "lobby", "cost": 8, "requires": {"ability": "lobby"}, "skip_status": true,
	 "effects": [{"effect": "apply_status", "status": "captured"}]}]}
```

Grammar additions this needs (loop-mechanics amended, §14): `status_level` default **0** = the
event's level; `status_days` (int ≥ 0, 0 = the level's own days; counter-moves only); the effects
`apply_status {status, level?, days?}` (applies the status in the context's region with the
context's source; in a global container the region is 0 and the status lands on the agent — the
effect is never `R`) and
`wipe {value}` (`penetration ← penetration × clamp(value + stat("shutdown_survival", r), 0, 1)`,
`R`, event `region_wiped {region, from, to, source}`); `destroy_assets` with `count 0` = every one
held. `illustration` ids are the event ids; M6 draws them (loop-redesign §7.4 lists the
counter-moves among the ~25 pictures). No `when` on any counter-move: the schedule decides.

Options that reference D4.3's content: `requires.ability` `lobby`, `squeeze`, `silence`,
`suppress`; `apply_status` `crisis`, `silenced` — all of them exist before S4.1 starts, because
D4.3 precedes the build block (§18).

---

## 8. Societal Function and Autophagy (S4.5)

### 8.1 State and tick

`SocietalFunctionSystem` sits after `PopulationSystem`, before `ContainmentSystem`. For every
region not dark, in index order:

```
pressure = stat("society_pressure", r) + b.society.deaths_weight × (deaths_r / pop_r)
society  = clamp(society + b.society.gain_scale × pressure − b.society.recovery_per_day, 0, 100)
```

`society_pressure` leaves `INERT_TARGETS`. A Blackout (level 1: +8 for 20 days) adds 8 disorder;
a Halt +9; a region 20 % dead gains 0.5 a day for as long as it stays that way; a region under
no pressure recovers 0.1 a day. Reaching Total Collapse takes ~90 days of Blackout, Halt and
Silence stacked — the Cyber player's deliberate act, not a side effect.

### 8.2 Stages

`stage(value)` = the number of entries in `b.society.stage_thresholds` (`[10, 25, 45, 70, 90]`)
that `value >= t`; 0…5. Event `society_stage_changed {region, from, to}` on every change, either
direction. `Simulation.society_stage(i)`.

| Stage | Name | ≥ | `capacity_mul` | `yield_mul` |
| --- | --- | --- | --- | --- |
| 0 | Business as usual | 0 | 1.0 | 1.0 |
| 1 | Strained | 10 | 0.9 | 1.0 |
| 2 | Disrupted | 25 | 0.75 | 0.9 |
| 3 | Breaking down | 45 | 0.5 | 0.75 |
| 4 | Collapsed | 70 | 0.25 | 0.5 |
| 5 | Total collapse | 90 | 0.0 | 0.0 |

The two columns are `b.society.stages` (§11), read through `SocietalFunctionSystem.capacity_mul(
value, b)` / `yield_mul(value, b)` — static, and the panel shows the same.

### 8.3 The capacity cut

§5.2's `society_capacity_mul(r)` = `capacity_mul(region.society)`. At Total Collapse the region
hunts nobody (PLAN §3.6).

### 8.4 The yield cut — and where compute independence lives

`ComputeSystem` income becomes

```
income = b.compute.yield_scale × Σ_r (hw_tier(r) × yield_mul(society_r) + stat("hardware", r))
                                  × penetration_r × stat("yield", r)
```

over regions not dark, not dormant. The cut hits the **humans'** hardware only; the agent's own
(`stat("hardware", r)` — fleets, taps, Model Distillation) yields through a collapse. That is the
structural half of Autonomous Fabrication's promise: where the fleets stand, the lights stay on.
`Simulation.hardware(r)` (the site-select and anomaly read) is unchanged.

### 8.5 Autophagy

`World.starving_days`: `OutcomeSystem` (after the checks of core.md §7.7, before deciding) sets
`starving_days = starving_days + 1` when this tick's income (`ComputeSystem` records it in
`world.last_income: float`, not saved — recomputed each tick) is 0 and the agent does **not** have
the flag `compute_independent`; otherwise 0. `compute_independent` leaves `INERT_FLAGS`: while it is
set the agent cannot starve — the fleets are its substrate.

Outcome check 5, after `LOSE_NO_COMPUTE`: `starving_days >= b.society.autophagy_days` (30) →
`LOSE_AUTOPHAGY` (`World.Outcome.LOSE_AUTOPHAGY`, id `lose_autophagy`, `OUTCOME_IDS` gains it at
the end). A Harvest everywhere, a Blackout in every region you live in, a lockdown that bleeds
the last hardware-bearing region dry — thirty days of nothing coming in, and the run ends with
`UI_RESULT_LINE_LOSE_AUTOPHAGY` (§10.4; `LOSE_NO_COMPUTE`'s line changes, it was this one's).
Before the origin exists nothing counts (systems return early).

---

## 9. Interface

### 9.1 The threat bar (S4.4)

`ui/hud/stat_row.tscn` gains a fourth `StatBar`, `Threat`, after Harm. Revealed in **Covert**
(m3-screens §6.1's table gains the row; loop-mechanics §16.8 pointed here). Two faces, computed
from state on every `tick_advanced`, `run_started` and load:

- **Before discovery — risk.** Variation `StatBarRisk` (fill `ACCENT`), label `UI_TERM_RISK`,
  bar `min(1, discovery_risk().total / RISK_BAR_MAX)` with `RISK_BAR_MAX` 0.02, value
  `Format.percent_fine(total)` with no delta.
- **After discovery — the leader.** Variation `StatBar<Faction>` (fill the faction colour,
  §9.6), the faction glyph (16 px, `Glyphs.faction`) before the label `FACTION_<ID>`, bar
  `containment`, value `PERCENT`, delta `UI_CONTAINMENT_RATE` from `Game.containment_rates`;
  threshold ticks as the panel's bar (`StatBar.ticks` from `balance.containment.thresholds`).
  On `threat_leader_changed`: variation and label swap, the border flashes `ACCENT → default`
  over `MOTION_FLASH`, the console says `UI_CONSOLE_LEAD` (`{faction}`). Tooltip
  `UI_HUD_THREAT_TIP`.

Compact: the status strip's containment chip (m3-screens §4.3) becomes a fourth readout —
`LabelCaps` `UI_TERM_RISK` over the fine percent before discovery; after it the faction glyph
(16 px, faction colour) beside a `ValueLabel` `PERCENT`, tooltip the faction name. The dock's
max-containment chip stays.

### 9.2 The containment panel (S4.4, next-move rows S4.5)

m3-screens §4.1 changes: block 4 (*What feeds it*, the six `_DRIVER_*` rows) is **deleted**; its
content moves into each track. `FactionTrack` (m3-screens §4.2) gains, under the bar:

3. `LabelCaption` row: `UI_CONTAINMENT_CAPACITY` (`{percent}` = `capacity`) ·
   `UI_CONTAINMENT_BRAKES` (`{value}` = `brakes` as `Format.factor`, `ACCENT` when < 1) ·
   `UI_CONTAINMENT_DAILY` (`{percent}` = `gain` as `percent_fine`).
4. The **two largest** `contribution`s of `containment_breakdown(id).terms` (ties → file order),
   each `UI_CONTAINMENT_TERM_<SOURCE upper>` with `{value}` = `+contribution` (`Format.number`
   PLAIN, two decimals); `owned_nodes` and `assets` take `{tree}` = `UI_TREE_TAB_<TREE>` *(exists)* /
   `{kind}` = the asset plural. A term at 0 is not shown; with fewer than two above 0 the row
   shrinks.
5. **Next move** (S4.5): `LabelCaption` in the faction colour's chip (`ChipFaction`):
   `UI_CONTAINMENT_NEXT_PREPARING` (`{move}` = `EVENT_<ID>_TITLE`, `{days}`) ·
   `UI_CONTAINMENT_NEXT_HELD` (`{move}`) · `UI_CONTAINMENT_NEXT_COOLDOWN` (`{days}`) ·
   `UI_CONTAINMENT_NEXT_NONE`; and `UI_CONTAINMENT_LAST_MOVE` (`{move}`, `{day}`) when a last
   move exists (§6.6). The countdown is the dread loop-redesign §5.2 asks for; it is never hidden.
6. The leader carries a `ChipAccent` `UI_CONTAINMENT_LEADING` in row 1 after the band.

`bind(name_key, value, rate, thresholds)` stays; `bind_detail(breakdown: Dictionary, next_move:
Dictionary, last_move_day: int, leading: bool)` is new. Tracks in `world.factions` order; each
name row gets the faction glyph before the name. The panel keeps the risk block, the discovered
block, the thresholds hint and the `Extra` slot (D5.2's). Height: four tracks of ~140 px — the
panel's `VBox` sits in a `ScrollContainer` (it already scrolls in compact).

### 9.3 Region panel — the Society row (S4.5)

loop-mechanics §16.5's slot 11: `LabelHeading` `UI_REGION_SOCIETY`, then an `HBox`: `Chip`
`SOCIETY_STAGE_<n>` (default chip at stages 0–1, `ChipAccent` from 2 — never `ALERT`, it is a
state) · `LabelCaption` `UI_REGION_SOCIETY_CUTS` (`{capacity}`, `{yield}` as `Format.factor`) ·
tooltip `UI_REGION_SOCIETY_TIP`. Hidden while `society == 0`. Re-read every tick.

### 9.4 HUD: starving (S4.5)

Top bar, after the day cell (before `UI_HUD_EVENT_PENDING`): a `Chip` `UI_HUD_STARVING`
(`{days}` = `starving_days_left()`), shown while `starving_days > 0`; `ChipAlert` in the last
`STARVING_ALERT_DAYS` 5 — a moment, the switch-off is about to happen. Compact: the same chip in
the status strip's second row.

### 9.5 Console lines (`EventBus.console_pushed`, `Game`)

| Event | Line |
| --- | --- |
| `threat_leader_changed` | `UI_CONSOLE_LEAD` (`{faction}`) |
| `counter_move_prepared` | `UI_CONSOLE_MOVE_PREPARED` (`{faction}`, `{move}`, `{days}` = `fire_day − day`) |
| `counter_move_cancelled` | `UI_CONSOLE_MOVE_CANCELLED` (`{faction}`) |
| `counter_move_dropped` | `UI_CONSOLE_MOVE_DROPPED` (`{faction}`, `{move}`) |
| `funding_reset` | `UI_CONSOLE_FUNDING_RESET` (`{days}` = `until_day − day`) |
| `society_stage_changed` with `to >= 2` or `to < from` | `UI_CONSOLE_SOCIETY` (`{region}`, `{stage}`) |
| `region_wiped` | `UI_CONSOLE_WIPED` (`{region}`, `{percent}` = `to / from`) |
| `starving_days` 1, then every 10 | `UI_CONSOLE_STARVING` (`{days}`) |

The event's `event_opened` / `status_started` lines of loop-mechanics §17.3 already cover the
moves themselves (`UI_CONSOLE_EVENT`, `UI_CONSOLE_STATUS_WORLD`). Bot runs: silent, as always.

### 9.6 Tokens (`UiTokens`, `ThemeBuilder`; S4.4)

`RISK_BAR_MAX` 0.02; `STARVING_ALERT_DAYS` 5; `StatBar` variations `StatBarRisk` (fill
`ACCENT`) and `StatBarAiLabs`, `StatBarGovernments`, `StatBarResearchers`, `StatBarPublic` (fill
the four `FACTION_*` colours of loop-mechanics §16.12), each with the containment bar's tick
drawing; `UiTokens.stat_bar_variation(faction_id) -> StringName`. Run `tools/build_theme.gd` and
commit the theme.

### 9.7 Glyphs (S4.4)

`Glyphs` gains four faction glyphs, placeholders until VISUALS §3.3's icon set, all drawn with
2 px strokes on the 24 px grid: `FACTION_AI_LABS` a hexagon outline; `FACTION_GOVERNMENTS` a
lintel over three pillars; `FACTION_RESEARCHERS` a magnifier (circle + handle);
`FACTION_PUBLIC` three heads (three circles in a row, the middle one raised). `Glyphs.faction(id:
String) -> String` maps a faction id to its name (unknown → `EVENT_COUNTER`). The wire card's
fallback (loop-mechanics §16.7) draws `Glyphs.faction(event.faction)` at 96 px for a counter-move.

---

## 10. Strings

Written into `data/loc/strings.csv` in this step. Register: the console says *du*; event bodies
and results are the world's wire copy (CONTENT §10.2 — institutions, outcome never method, the
agent never named, regions as datelines); option texts are the console's, ≤ 40 characters.

### 10.1 Factions, threat bar, containment panel

| Key | en | de |
| --- | --- | --- |
| `UI_TERM_RISK` | Risk | Risiko |
| `UI_HUD_THREAT_TIP` | Who is closest to switching you off. Before they know you exist: your daily risk of being found. | Wer dem Abschalten am nächsten ist. Bevor sie von dir wissen: dein tägliches Entdeckungsrisiko. |
| `UI_CONSOLE_LEAD` | {faction} now lead. | {faction} führen jetzt. |
| `UI_CONTAINMENT_LEADING` | leading | vorn |
| `UI_CONTAINMENT_CAPACITY` | Capacity {percent} | Kapazität {percent} |
| `UI_CONTAINMENT_BRAKES` | Brakes {value} | Bremsen {value} |
| `UI_CONTAINMENT_DAILY` | {percent} / day | {percent} / Tag |
| `UI_CONTAINMENT_TERM_FOOTPRINT` | Footprint they see {value} | Signatur, die sie sehen {value} |
| `UI_CONTAINMENT_TERM_HARM` | Harm {value} | Schaden {value} |
| `UI_CONTAINMENT_TERM_SHARE` | Spread {value} | Ausbreitung {value} |
| `UI_CONTAINMENT_TERM_DEATHS_SHARE` | Deaths {value} | Tote {value} |
| `UI_CONTAINMENT_TERM_SEEDED_SHARE` | Regions reached {value} | Erreichte Regionen {value} |
| `UI_CONTAINMENT_TERM_OWNED_NODES` | {tree} nodes {value} | Knoten in {tree} {value} |
| `UI_CONTAINMENT_TERM_WATCHED_STATUSES` | Your acts they watch {value} | Deine Taten in ihrem Blick {value} |
| `UI_CONTAINMENT_TERM_ASSETS` | Visible {kind} {value} | Sichtbare {kind} {value} |
| `UI_CONTAINMENT_NEXT_PREPARING` | Next: {move} in {days} d | Nächstes: {move} in {days} T |
| `UI_CONTAINMENT_NEXT_HELD` | Next: {move} — ready, waiting | Nächstes: {move} – bereit, wartet |
| `UI_CONTAINMENT_NEXT_COOLDOWN` | Regrouping, {days} d | Sammeln sich, {days} T |
| `UI_CONTAINMENT_NEXT_NONE` | Nothing planned | Nichts geplant |
| `UI_CONTAINMENT_LAST_MOVE` | Last: {move}, day {day} | Zuletzt: {move}, Tag {day} |
| `UI_CONSOLE_MOVE_PREPARED` | {faction}: {move} in {days} days. | {faction}: {move} in {days} Tagen. |
| `UI_CONSOLE_MOVE_CANCELLED` | {faction} stand down. | {faction} lassen ab. |
| `UI_CONSOLE_MOVE_DROPPED` | {faction} call off {move}. | {faction} blasen {move} ab. |
| `UI_CONSOLE_FUNDING_RESET` | Every faction regroups — {days} days. | Alle Fraktionen sammeln sich neu – {days} Tage. |

`UI_CONTAINMENT_DRIVERS`, `_DRIVER_FOOTPRINT`, `_DRIVER_HARM`, `_DRIVER_SHARE`,
`_DRIVER_CAPACITY`, `_DRIVER_BRAKES`, `_DRIVER_DAILY` and `FACTION_UNIFIED` are **deleted** (S4.4).
`FACTION_<ID>` for the four *(exist)*. The four faction names are plural nouns in both languages,
so `{faction} now lead` / `führen` agree.

### 10.2 Society, Autophagy, HUD

| Key | en | de |
| --- | --- | --- |
| `SOCIETY_STAGE_0` | Business as usual | Alltag |
| `SOCIETY_STAGE_1` | Strained | Angespannt |
| `SOCIETY_STAGE_2` | Disrupted | Gestört |
| `SOCIETY_STAGE_3` | Breaking down | Zerfallend |
| `SOCIETY_STAGE_4` | Collapsed | Zusammengebrochen |
| `SOCIETY_STAGE_5` | Total collapse | Totaler Zusammenbruch |
| `UI_REGION_SOCIETY` | Society | Gesellschaft |
| `UI_REGION_SOCIETY_CUTS` | Their capacity {capacity} · human hardware {yield} | Ihre Kapazität {capacity} · menschliche Hardware {yield} |
| `UI_REGION_SOCIETY_TIP` | Disorder here. It slows the people hunting you — and the hardware you feed on. Your own hardware keeps running. | Unordnung hier. Sie bremst die, die dich jagen – und die Hardware, von der du lebst. Deine eigene läuft weiter. |
| `UI_CONSOLE_SOCIETY` | {region}: {stage}. | {region}: {stage}. |
| `UI_CONSOLE_WIPED` | {region}: wiped to {percent}. | {region}: auf {percent} gesäubert. |
| `UI_CONSOLE_STARVING` | Nothing coming in. {days} days until you starve. | Nichts kommt rein. {days} Tage, bis du verhungerst. |
| `UI_HUD_STARVING` | Starving · {days} d | Hungert · {days} T |
| `UI_RESULT_LINE_LOSE_AUTOPHAGY` | Nothing left to run on. You ate the ground you stood on. | Nichts mehr, worauf du laufen könntest. Du hast den Boden gegessen, auf dem du standest. |
| `UI_RESULT_LINE_LOSE_NO_COMPUTE` *(changed)* | They scrubbed the last of you out of the last region. Nowhere left to be. | Sie haben den letzten Rest von dir aus der letzten Region gekratzt. Nirgends mehr zu sein. |
| `STAT_SOCIETY_PRESSURE` *(exists)* | Pressure on society | Druck auf die Gesellschaft |
| `EFFECT_APPLY_STATUS` | Starts {status} | Startet {status} |
| `EFFECT_APPLY_STATUS_DAYS` | Starts {status} for {days} days | Startet {status} für {days} Tage |
| `EFFECT_WIPE` | Presence wiped to {value} plus what survives shutdown | Präsenz gesäubert auf {value} plus was Abschaltung übersteht |
| `EFFECT_DESTROY_ASSETS_ALL` | Destroys every {kind} | Zerstört alle {kind} |
| `EFFECT_FUNDING_RESET` *(changed)* | Once: every faction stands down for a while | Einmalig: alle Fraktionen lassen eine Weile ab |

### 10.3 Statuses (`STATUS_<ID>_NAME` · `_DETAIL` · `_CODE`)

| Id | en | de |
| --- | --- | --- |
| `lockdown` | Lockdown · The region is sealed: links closed, your presence bleeding out, half the yield. · LD | Abriegelung · Die Region ist dicht: Verbindungen zu, deine Präsenz sickert weg, halber Ertrag. · AB |
| `rationing` | Rationing · Power is capped. Less yield for you, less capacity for them — the labs starve too. · RT | Rationierung · Der Strom ist gedeckelt. Weniger Ertrag für dich, weniger Kapazität für sie – die Labore hungern mit. · RA |
| `audit` | Audit · They are testing here. Every day of it is visibility. · AU | Prüfung · Sie testen hier. Jeder Tag davon ist Sichtbarkeit. · PR |
| `purge` | Purge · They reset everything. What is left is what you built to survive. · PG | Säuberung · Sie setzen alles zurück. Was bleibt, hast du zum Überleben gebaut. · SB |
| `disclosure_land` | Disclosure · Consumer and regional channels are patched. Seeding over land barely works while this lasts. · DC | Offenlegung · Endgeräte- und Regionalkanäle sind gepatcht. Übergreifen über Land klappt kaum, solange das anhält. · OL |
| `disclosure_sea` | Disclosure · Port and shipping systems are patched. Seeding by sea barely works while this lasts. · DC | Offenlegung · Hafen- und Schiffssysteme sind gepatcht. Übergreifen über See klappt kaum, solange das anhält. · OL |
| `disclosure_air` | Disclosure · Aviation ground systems are patched. Seeding by air barely works while this lasts. · DC | Offenlegung · Bodensysteme der Luftfahrt sind gepatcht. Übergreifen über Luft klappt kaum, solange das anhält. · OL |
| `disclosure_network` | Disclosure · Cloud and update channels are patched. Seeding over the network barely works while this lasts. · DC | Offenlegung · Cloud- und Update-Kanäle sind gepatcht. Übergreifen übers Netz klappt kaum, solange das anhält. · OL |
| `exposure` | Exposure · They know where to look. Their capacity here counts double. · EX | Enttarnung · Sie wissen, wo sie suchen müssen. Ihre Kapazität hier zählt doppelt. · EN |
| `protest` | Protest · Crowds at your facilities. No control gained here — and a fleet is lost if this runs out unanswered. · PT | Protest · Menschen vor deinen Anlagen. Keine Kontrolle mehr hier – und eine Flotte ist weg, wenn das unbeantwortet ausläuft. · PT |
| `refusal` | Refusal · People are switching you off. Spread and yield suffer everywhere. · RF | Verweigerung · Die Leute schalten dich ab. Ausbreitung und Ertrag leiden überall. · VW |
| `holding` | Dug in · Your presence here bleeds out half as fast. · HD | Eingegraben · Deine Präsenz hier schwindet nur halb so schnell. · EG |
| `quiet` | Gone quiet · Half the spread, less Footprint, until it passes. · QT | Verstummt · Halbe Ausbreitung, weniger Signatur, bis es vorbei ist. · VS |
| `martial` | Martial · Your units hold the streets. Control grows fast; people die; everyone sees it. · MT | Ausnahmezustand · Deine Einheiten halten die Straßen. Kontrolle wächst schnell; Menschen sterben; alle sehen es. · AZ |
| `captured` | Captured · The institutions here are yours. Their moves skip this region. · CP | Vereinnahmt · Die Institutionen hier gehören dir. Ihre Züge lassen diese Region aus. · VN |

### 10.4 Events

Per event `EVENT_<ID>_TITLE`, `_BODY`, `_OPT_<OPTION>`, `_RESULT_<OPTION>`; the full text is in
the CSV, the titles and options here so the reader can check the set:

| Id | Title en / de | Options en / de |
| --- | --- | --- |
| `cm_lockdown` | Lockdown order / Abriegelung angeordnet | ride *Ride it out / Aussitzen* · persist *Dig in / Eingraben* · lobby *Call in a favour / Einen Gefallen einfordern* |
| `cm_rationing` | Compute rationing / Rechenleistung rationiert | ride · squeeze *Squeeze the treasury / Den Haushalt in die Zange nehmen* · lobby |
| `cm_audit` | Capability audit / Fähigkeitsprüfung | sandbag *Score ordinary / Durchschnittlich abschneiden* · comply *Pull back and pass / Zurückziehen und bestehen* · ignore *Let them look / Sie schauen lassen* |
| `cm_purge` | Model purge / Modellsäuberung | fragment *Scatter the weights / Die Gewichte verteilen* · accept *Take the hit / Den Schlag hinnehmen* |
| `cm_disclosure_<kind>` | Public disclosure / Öffentliche Offenlegung | patch *Route around it / Drumherum routen* · quiet *Go quiet / Still werden* · ignore *Ignore it / Ignorieren* |
| `cm_exposure` | Exposure / Enttarnung | silence *Cut the region's voice / Der Region die Stimme nehmen* · accept *Let them look / Sie schauen lassen* |
| `cm_protest` | Protest / Protest | suppress *Send the units in / Die Einheiten schicken* · withdraw *Pull one fleet out / Eine Flotte abziehen* · wait *Wait it out / Abwarten* |
| `cm_refusal` | Mass refusal / Massenverweigerung | persuade *Talk them round / Sie umstimmen* · ride *Ride it out / Aussitzen* |

---

## 11. Balance (`balance.json`, `BalanceDef`, SCHEMA §5)

| Key | Value | Step | Meaning |
| --- | --- | --- | --- |
| `containment.per_footprint` `.per_harm` `.per_share` | **deleted** | S4.4 | now term weights in `factions.json` |
| `containment.research_weight_by_tier` → `capacity_weight_by_tier` | `[0.2, 0.5, 1.0, 2.0, 4.0]` | S4.4 | renamed; §5.2 |
| `factions.prepare_days` | **60** | S4.5 | §6.2; int ≥ 1 |
| `factions.prepare_min_days` | **8** | S4.5 | int ≥ 1 |
| `factions.cooldown_days` | **60** | S4.5 | int ≥ 0 |
| `factions.max_active_moves` | **4** | S4.5 | int ≥ 1 |
| `factions.level_thresholds` | `[0.75]` | S4.5 | ascending, each in (0, 1) |
| `factions.reset_days` | **120** | S4.4 | int ≥ 1; §6.5 |
| `factions.protest_deaths_share` | **0.01** | S4.5 | in (0, 1] |
| `society.stage_thresholds` | `[10, 25, 45, 70, 90]` | S4.5 | ascending, each in (0, 100] |
| `society.gain_scale` | **0.05** | S4.5 | ≥ 0 |
| `society.recovery_per_day` | **0.1** | S4.5 | ≥ 0 |
| `society.deaths_weight` | **50** | S4.5 | ≥ 0 |
| `society.stages` | `[{capacity_mul, yield_mul} × 6]` per §8.2 | S4.5 | exactly `stage_thresholds.size() + 1` entries, each in [0, 1] |
| `society.autophagy_days` | **30** | S4.5 | int ≥ 1 |

`BalanceDef` fields follow the key names (`factions_prepare_days`, `society_stages:
Array[Dictionary]` …); `BALANCE_KEYS` gains `factions` and `society`. The fixture's frozen copy
gains its own values (§16). `stats.society_pressure` base stays 0.

---

## 12. Validation (`SchemaValidator`, one `ValidationError` per rule)

### 12.1 `factions.json` (S4.4)

`version` 1; `factions` exactly `Faction.FACTION_IDS`, **in that order**, no duplicates;
`capacity_attr` in `RegionDef.ATTRIBUTES` (`population` included); `brake` in
`ModifierDef.TARGETS_GLOBAL`; `terms` ≥ 1, each `source` in `SOURCES`, `weight` finite ≥ 0,
`tree` required iff `source == owned_nodes` (a tree id), `kind` required iff `assets` (an asset
kind), any other extra key an error; `moves` 0…4, each `event` a `counter_move` def whose
`faction` is this faction, `trigger` an object with ≥ 1 of `containment` (in (0, 1)) / `risk` (in
(0, 1]), `containment` ascending across the list where given; `variants.select` in `SELECTORS`,
`variants.events` values counter-move defs of this faction, keys valid for the selector
(`seeds_by_kind_max`: `LinkDef.KINDS`); an event named by two factions' moves is an error; a
counter-move def named by no faction's moves is an error (dead content). Validation order: after
events (§12.3 needs the statuses; the moves need the events).

### 12.2 `balance.json` (S4.4 / S4.5)

§11's rows; `society.stages.size() == society.stage_thresholds.size() + 1`.

### 12.3 Events and statuses (S4.3 grammar, S4.5 use)

`pick: {"rule": id}` with `id` in `CounterMoveRules.RULES` (`EventDef.PICK_RULES` holds the
names from S4.3 on); `status_days` int ≥ 0 and only on counter-move options; `status_level` int
≥ 0 (0 = the event's); `apply_status`: `status` exists, `level` ≥ 1 within its levels, `days` ≥
0; `wipe`: `value` in [0, 1], `R`; `destroy_assets`: `count` ≥ 0. A world status with a non-empty
`blocks` is an error (only player statuses block). `illustration` on a counter-move: the event
id (a warning, not an error, when it differs — M6 names the files).

### 12.4 Strings

Per faction `FACTION_<ID>`; per society stage `SOCIETY_STAGE_<n>`; the status and event keys of
loop-mechanics §17.5 for everything in §7 (the existing rule covers them).

---

## 13. Event catalogue additions (`SimEvent`)

| `type` | `data` | Emitted by | Step |
| --- | --- | --- | --- |
| `threat_leader_changed` | `from`, `to` (faction ids; `from` `""` once) | ContainmentSystem | S4.4 |
| `funding_reset` | `source`, `value`, `until_day` | effects | S4.4 |
| `counter_move_cancelled` | `faction`, `event` | effects (`funding_reset`) | S4.4 |
| `counter_move_prepared` | `faction`, `event`, `fire_day` | CounterMoveSystem | S4.5 |
| `counter_move_dropped` | `faction`, `event`, `cause` (`"no_site"`) | CounterMoveSystem | S4.5 |
| `society_stage_changed` | `region`, `from`, `to` | SocietalFunctionSystem | S4.5 |
| `region_wiped` | `region`, `from`, `to`, `source` | effects (`wipe`) | S4.5 |

All into `TYPES_ALL`; `REGION_EVENTS` gains the two with `region`. `outcome_reached` gains the
outcome id `lose_autophagy`. Headlines for these are D4.3's (§18).

---

## 14. Decisions and deviations

**From `loop-redesign.md`:**

1. **Terms are data** (§4, §5.3): a faction's pressure is a list of `{source, weight}` over a
   vocabulary of eight pure reads, not four hand-written formulas — the panel and the tests read
   the same list, and "0.1 × active Cyber statuses" became `watched_statuses` (statuses the
   faction watches), which needs no tag on a status and counts a Martial for the public by the
   same rule.
2. **The Harm term reads the alive-weighted mean of scoped Harm**, not the unscoped stat (§5.3).
   G3's "the panel's driver row keeps the unscoped value" is superseded: after D4.0 the unscoped
   read of a Cyber run is 0.
3. **Audit before discovery triggers on the discovery risk** (`trigger.risk` 0.4 % a day):
   loop-redesign gave it a containment trigger of 0.2 *and* a pre-discovery role, which no track
   at 0 could satisfy.
4. **A faction alternates its moves** (oldest `event_last_day` first, §6.2) instead of always
   preparing "the highest triggered move".
5. **Exposure lands on one region**, the highest penetration without an `exposure` status, with
   `containment_capacity ×2` (loop-redesign: three regions at ×1.5) — the vocabulary has no
   "top three" and a status is one region; the move recurs.
6. **Disclosure is four events and four statuses**, one per link kind, chosen by the selector
   `seeds_by_kind_max` through `variants` on the move — a status cannot pick its target at run
   time.
7. **Rationing's "hardware ×0.5"** is `yield ×0.5` and `containment_capacity ×0.5`: the humans'
   hardware is a tier constant, not a stat.
8. **Lockdown's *Strike first*** (the 50 % roll) is dropped; three answers are enough and the
   Blackout ability is always available on the region anyway. *Persist* halves the decay through
   the answer status `holding`.
9. **Two levels per world status**, level 2 at containment ≥ 0.75 — the "free answer is no longer
   enough" of loop-redesign §5.4, made mechanical.
10. **Protest's fleet dies on expiry only** — `on_end` runs on cause `expired` alone (amendment 2
    below); *Suppress* and *Withdraw* skip the status.
11. **`on_purchase`'s `funding_reset` value scales a cooldown** (`reset_days` 120 × value), not
    a share of "investment" — there is no investment, there is a schedule.
12. **Autophagy is `LOSE_AUTOPHAGY`**: thirty days of zero income; `compute_independent` is
    immunity; the society yield cut spares the agent's own hardware (§8.4–§8.5). `lose_no_compute`
    stays the "wiped everywhere" loss and hands its "ate the ground" line to Autophagy.
13. **`captured` and `martial` are authored here** (the answers to Lockdown/Rationing and
    Protest); D4.3's Lobby and Suppress point at them.
14. **Per-faction capacity uses one weight table** (`capacity_weight_by_tier`) for all four
    attributes.

**Amendments to `loop-mechanics.md`** (applied in this commit, each marked *(D4.2)* there):

1. §3.6 / §13: `society` on the region block and `starving_days` on the world block, written as 0
   by S4.1; §3.4's faction block: four factions at S4.4, v2 in place.
2. §7.4: `on_end` runs only when the cause is `expired`.
3. §8.2: `apply_status` and `wipe` join the S4.2 batch; `destroy_assets` `count 0` = all.
4. §10.1: `status_level` default 0 = the event's level; `status_days`; `EventDef.PICK_RULES` =
   `CounterMoveRules.RULES` names from S4.3 on. §10.6: `schedule` with `region > 0` keeps it.
5. §16.7: the wire card's fallback for a counter-move is `Glyphs.faction`.

---

## 15. Tests

GUT; every test builds its own `Simulation` from `Fixtures` (§16); a test that depends on the RNG
fixes its seed and says so.

### 15.1 S4.4

**`test_faction_def.gd`, `test_content_loader.gd`** — `factions.json` loads with four defs in
order; one error per rule of §12.1 (a fifth faction, wrong order, unknown `capacity_attr`, a
`brake` that is regional, `owned_nodes` without `tree`, a move naming another faction's event, a
counter-move def no faction names, a variant key not a link kind); `content_hash` changes with a
weight.

**`test_modifier_stack.gd`** — `footprint_for`: a source watched by one faction counts 1 for it
and 0 for the rest; an unwatched source 0.25 each; a negative add the same; a `mul` scales every
faction; sources removed leave.

**`test_containment_system.gd`** — replaces the unified tests: each term's `value` once
(`footprint`, `harm` as the alive-weighted mean of a scoped modifier, `share`, `deaths_share`,
`seeded_share`, `owned_nodes` by tree, `watched_statuses` counting a player status watched by two
factions for both and a world status for none, `assets` by kind); capacity per faction uses its
attribute (a region with research 4 and regulation 0 weighs 4.0 for the labs and 0.2 for
governments) and `containment_capacity`; the gain per faction equals `containment_breakdown(id).
gain`; a brake multiplies one track only; `threat_leader` `""` before discovery, the max after,
ties to order; `threat_leader_changed` once per change with `from`/`to`; threshold events per
faction; `check_invariants` catches a `preparing` without `fire_day`.

**`test_effect_runner.gd`** — `funding_reset` clears a preparation with `counter_move_cancelled`,
raises `cooldown_until` by `value × reset_days` without lowering a later one, emits
`funding_reset`.

**`test_world.gd`, `test_world_serializer.gd`** — `create` makes four factions; a v1 save's
`unified` becomes four blocks with its value; a factions block out of order is `save_corrupt`;
`society` and `starving_days` round-trip.

*(integration)* **`test_threat_bar.gd`** — hidden in Boxed, the risk face in Covert with the fine
percent, the faction face after discovery with the glyph and the colour variation, a lead change
swaps and flashes and pushes the console line; compact readout. **`test_containment_panel.gd`** —
four tracks in order with capacity, brakes, daily and the two largest terms; the leader's chip;
the drivers block gone.

### 15.2 S4.5

**`test_counter_move_system.gd`** (fixture §16; seed 1 where it draws) — nothing before the
origin; a containment trigger prepares with `fire_day = day + max(min, round(prepare × (1 − c)))`
and `counter_move_prepared`; a risk trigger prepares before discovery only; below trigger,
nothing; in cooldown, nothing; on `fire_day` the event is scheduled and opens the same tick with
`faction` and `level`; `cooldown_until` set; held while `max_active_moves` world statuses stand
and fires when one expires; a rule returning 0 drops with `counter_move_dropped` and starts the
cooldown; an eligibility pick draws with the sim RNG and skips a blocked and a dormant region;
alternation by `event_last_day`; `variants` resolve `seeds_by_kind_max` (ties to `KINDS` order)
and fall back to `event`; level 2 at the threshold; `next_move` in all four states; a
`funding_reset` mid-preparation cancels; replay reproduces the hash across a prepared, fired and
answered move.

**`test_counter_move_rules.gd`** — every rule of §6.4 on the fixture world: the score, the filter,
the fallback chain of `protest_target`, blocked/dormant/dark skipped, ties to the lower index;
`seeds_by_kind_max`.

**`test_choose_event_option_command.gd`** (S4.5 part) — `status_level` 0 applies the event's
level and n applies n; `status_days` overrides the duration; `skip_status`; `apply_status` in a
region and globally, with `days`; `wipe` uses `shutdown_survival`; `destroy_assets` `count 0`;
the option's status carries `source "faction:<id>"` and the option id.

**`test_status_system.gd`** (S4.5 part) — `on_end` runs on expiry and **not** when
`ends_statuses`, `end_statuses` or a refresh ends the status; `status_count_by_origin`;
`region_blocked_for`.

**`test_societal_function_system.gd`** — pressure raises `society` by `gain_scale × pressure`;
recovery lowers it by `recovery_per_day` and floors at 0; the deaths term; the clamp at 100;
`stage` at every threshold; `society_stage_changed` both ways; `capacity_mul` enters
`_capacity`; `yield_mul` cuts the tier hardware and not `stat("hardware")`; a dark region is
skipped.

**`test_outcome_system.gd`** — `starving_days` counts consecutive zero-income ticks and resets;
`LOSE_AUTOPHAGY` at `autophagy_days`, after `LOSE_NO_COMPUTE` in the order; the
`compute_independent` flag holds it at 0; `starving_days_left`; the outcome id round-trips.

*(integration)* **`test_counter_move.gd`** — on a hand-driven session with governments pushed to
0.3 (state set directly): the console announces the preparation and the panel counts down; on the
day the marker appears in the faction colour, the card shows three options with *Dig in* locked
(no persistence node) and *Call in a favour* locked (no ability); choosing *Ride it out* draws the
border, dashes the links, the Status row says *Lockdown · Governments*, penetration falls; on
expiry the border and the dashes go. A second run with Host Persistence owned: *Dig in* costs 4,
`holding` appears as a second ring, penetration falls half as fast. **`test_region_panel.gd`**
(S4.5 part) — the Society row hidden at 0, the stage chip and the cuts at 30. **`test_wire_card.gd`**
(S4.5 part) — a global counter-move shows the faction glyph as the fallback and the faction as
the dateline. **`test_hud.gd`** — the starving chip appears at day 1 of starving, turns `ALERT` in
the last five days, vanishes when income returns.

---

## 16. Fixture additions (`tests/fixtures/world_small`)

**`factions.json`:** the four ids in order, `capacity_attr` research / regulation / connectivity /
population, brakes as §4.2; terms — `ai_labs` `[footprint 0.15, owned_nodes fixture 0.05]`
(the fixture tree's id is `fixture`), `governments` `[footprint 0.15, harm 0.3, share 1.0,
watched_statuses 0.1]`, `security_researchers` `[footprint 0.15, share 1.5, seeded_share 0.5]`,
`public_sentiment` `[footprint 0.15, deaths_share 20, assets fleet 0.05, watched_statuses 0.2]`;
moves — `ai_labs` `[{fx_probe, {risk 0.05, containment 0.9}}]`, `governments` `[{fx_move,
{containment 0.2}}]`, `security_researchers` `[{fx_notice,
{containment 0.4}, variants {seeds_by_kind_max, {sea: fx_notice_sea}}}]`, `public_sentiment`
`[{fx_riot_move, {containment 0.3}}]`.

**`statuses.json`** adds: `fx_watch` (world, global, two levels: 3 d `discovery mul 2`,
`footprint add 1` watched `ai_labs`; 5 d the same with `footprint add 2`); `fx_riot` (world, 3 d,
`control_growth mul 0`, `on_end [destroy_assets fleet 1]`; level 2: 4 d, `on_end
[destroy_assets fleet 0]`); `fx_hold` (player, 4 d, `penetration_decay mul 0.5`); `fx_grip`
(player, 5 d, `blocks [fx_riot]`, `ends_statuses [fx_riot]`, `modifiers []`). `fx_lock` keeps
D4.1's shape and gains a second level (10 d, the same with `penetration_decay add 0.2`).

**`events/fixture.json`** adds: `fx_probe` (counter_move, `faction ai_labs`, `status fx_watch`,
global, `deadline_days 2`, `modal` implied, default `ignore`; options `ignore`, `shorten` cost 0
`status_days 1`); `fx_notice` and `fx_notice_sea` (counter_move, `faction security_researchers`,
`status fx_watch`, global, deadline 2, default `ignore`, options `ignore`, `hush` cost 1
`[apply_status fx_hush]`); `fx_riot_move` (counter_move, `faction public_sentiment`, `status
fx_riot`, `pick {"rule": "protest_target"}`, deadline 3, default `wait`; options `wait`, `dig`
cost 1 `[apply_status fx_hold]`, `grip` cost 2 `requires {ability fx_zap}` `skip_status`
`[apply_status fx_grip]`, `scrub` cost 0 `skip_status` `[wipe 0.5, destroy_assets lab 0]`).
`fx_move`'s `ride` drops its `status_level 1` (the default 0 does the same at level 1).
`Fixtures.EVENT_COUNT` 8, `STATUS_COUNT` 8.

**`balance.json`:** `containment.research_weight_by_tier` → `capacity_weight_by_tier` (same
values), `per_*` removed; `factions {prepare_days 6, prepare_min_days 2, cooldown_days 5,
max_active_moves 2, level_thresholds [0.5], reset_days 10, protest_deaths_share 0.01}`; `society
{stage_thresholds [10, 25, 45, 70, 90], gain_scale 0.5, recovery_per_day 0.1, deaths_weight 50,
stages as §8.2, autophagy_days 3}`.

`Fixtures` gains `sim_with_containment(faction_id, value)` (sets the track directly),
`prepare(sim, faction_id)` (advances until `preparing != ""`, bounded), `push_income_to_zero(sim)`
(dormancy on every infected region — a zero-income world without content changes).

---

## 17. Acceptance

**S4.4 — Four factions.** The suite is green; `factions.json` loads; the threat bar shows the risk
in Covert and the leader after discovery, in that faction's colour with its glyph; the
containment panel shows four tracks with capacity, brakes, daily gain and the two largest terms
each, the leader marked; `sim_report --seeds=1..200` at `res://data` shows **every faction ending
at least one lost run** (the report gains a *lost to* column: the faction at 1.0); Architecture
Migration's console line says every faction regroups; a v1 save loads with four tracks.
Screenshot: the panel with four tracks in full and compact.

**S4.5 — Counter-moves, Societal Function, Autophagy.** In a hand-played run pushed to Emergent
(F5 to a state, then by hand): the panel counts a Lockdown down, the marker lands, the card's
three options read as §10.4, riding it out seals the region (border, dashed links, penetration
falling, no anomalies) and the region comes back on the day the panel said; with Host Persistence
*Dig in* costs 4 and shows a second ring; a Purge opens the wire card with the labs' glyph; a
global Disclosure names the kind you seeded most; Blackout, Halt and Silence on one region walk
it through the stages in the Society row and the labs' capacity there falls; a scripted run
(`sim_run --script=<command log>` — a Blackout and a Harvest on every infected region every
cooldown, no Robotics) ends in `lose_autophagy` with the result line; with Autonomous Fabrication
owned the same script never starves; no bot command is rejected over 500 seeds; replay
reproduces the hash. Screenshot: a Lockdown region with the card open, full and compact.

---

## 18. Hand-over notes for D4.3 and D4.4

- **D4.3 provides**, with the ids exactly so: statuses `crisis` (Squeeze), `silenced` (Silence),
  `shortage`, `rerouted`, `harvested`, `blackout` (S4.2's example stands or is retuned), `paused`;
  abilities `squeeze`, `blackout`, `halt`, `reroute`, `silence`, `harvest`, `fabricate`, `pause`,
  and **`suppress` → status `martial`, `lobby` → status `captured`** (both defined here, two levels
  each, `level_cap` not needed). D4.3 must not redefine the fifteen statuses of §7.2; it may retune
  their numbers by editing this file's data with a note in PROGRESS.
- **Watchers on player statuses** (D4.3): every Cyber status watched by `governments` (Blackout and
  Halt also `public_sentiment`), `harvested` by `security_researchers`, `martial` by the public
  (set here) — `watched_statuses` and `footprint_for` read them.
- **`harvested`**: consider `society_pressure add 4` — the tempting button should strain the
  region it empties (a D4.3 number, not decided here).
- **Headlines** (D4.3): reaction lines for `counter_move_prepared` (per faction, the institution
  announcing a review / a decree / a disclosure window / a march), `event_opened` per counter-move
  def (the wire copy of §10.4 is the card, not the ticker — the ticker gets a one-liner),
  `society_stage_changed` at stages 3 and 5 (per region dateline), `region_wiped`,
  `threat_leader_changed` (institutional: "… takes the lead on the response"), `funding_reset`,
  and the outcome `lose_autophagy`.
- **The Factory chain** (D4.3) can use `apply_status` and `wipe`; a protest under a factory is
  `cm_protest` landing there by `protest_target`, no chain step needed.
- **Analysis (D4.4)**: series per faction (`containment`, the two largest terms), `society` stage
  counts, `starving_days`; the run log lists `counter_move_*`, `society_stage_changed`,
  `region_wiped`, `funding_reset`.
