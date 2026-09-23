# Ticker — headline system and strip (D3.4 → S3.5)

**Version:** 1.0
**Date:** 2026-09-22
**Status:** hand-over for S3.5. Voice and register rules: `CONTENT.md` §10. The strip's look:
`ui-foundation.md` §5.5 (unchanged). Ticker hooks left by S3.3: `m3-screens.md` §6.4.

The ticker is the voice of the world. This spec makes it *react to what the player did*: a
deterministic `HeadlineSystem` in `core/` turns the simulation's events and state into
`headline` events, chosen from `data/headlines.json` by trigger conditions, cooldowns and weights;
the `Ticker` strip renders them in the player's language and switches register once, at Open.

---

## 1. Scope

**In:** §3 the headline system in `core/` — data format, condition vocabulary, eligibility,
selection, pacing, the `headline` event, save state · §4 the `Ticker` strip: items as `(key,
args)`, rendering, locale re-render, the register switch, reduced motion · §5 content loading and
validation · §6 headless tooling · §7 strings · §8 tests and acceptance. `data/headlines.json`
(this step, 150 headlines) and the `HEADLINE_*` strings in both languages are **delivered with
this spec**; S3.5 loads them and deletes nothing from them.

**Out:** event chains and the event modal (D4.2 / S4.5 — a chain may later *push* a headline
through the same event; nothing here anticipates it) · faction-specific reactions (D4.1 adds
`when.faction_*` conditions to §3.3 when the four tracks exist) · sound · the Analysis run log
(D4.4 reads the same `headline` events off the history; nothing to build here).

### 1.1 Terms

- **Headline** — one entry of `headlines.json`: an id, a stream, a register, a trigger, pacing
  fields. Its text is `HEADLINE_<ID>` in `strings.csv`.
- **Stream** — `consequence` · `reaction` · `filler` (CONTENT §10.4).
- **Register** — `institutional` · `emergency` · `any` (CONTENT §10.3). The *active* register is
  `emergency` iff `world.phase == OPEN`.
- **Item** — what the strip holds: a string key and raw arguments, rendered on demand.
- **Fire** — a headline is chosen and emitted as a `headline` event.

---

## 2. Files

| File | What |
| --- | --- |
| `data/headlines.json` | **delivered** — the 150 headlines, §3.2 |
| `data/loc/strings.csv` | **delivered** — `HEADLINE_*` rows and `UI_TICKER_IDLE_OPEN`, §7 |
| `core/content/headline_def.gd` | `HeadlineDef`, §3.2 — the parsed entry, typed |
| `core/content/content_loader.gd`, `content_db.gd`, `schema_validator.gd` | load `headlines.json` (`HEADLINES_FILE`), `db.headlines: Array[HeadlineDef]` in file order, validation §5 |
| `core/content/balance_def.gd`, `data/balance.json`, `data/SCHEMA.md` | the `headlines` balance section, §3.8 |
| `core/sim/headline_system.gd` | `HeadlineSystem`, §3.1–§3.9 |
| `core/sim/simulation.gd` | owns `headlines: HeadlineSystem`; calls it after the systems and after a command, §3.1 |
| `core/sim/sim_event.gd` | `SimEvent.HEADLINE = "headline"` and the field constants of §3.7 |
| `core/save/world_serializer.gd` | the optional `headlines` block, §3.9 |
| `ui/hud/ticker_item.gd` | `TickerItem`, §4.1 |
| `ui/hud/headline_text.gd` | `HeadlineText`, §4.2 — replaces `ui/hud/event_text.gd`, which is deleted with its test |
| `ui/hud/ticker.gd` + `ticker.tscn` | the strip, rewritten around items, §4.3–§4.6 |
| `ui/theme/ui_tokens.gd` | `TICKER_STATIC_HEIGHT`, `TICKER_STATIC_PER_CHAR`, §4.5 |
| `tools/sim_run.gd` | `--headlines`, §6 |
| `docs/specs/core.md` §6.4 | S3.5 appends the `headline` row to the event catalogue |

`HeadlineDef`, `HeadlineSystem`, `TickerItem`, `HeadlineText` carry `class_name`; the strip
script stays scene-specific without one (CLAUDE.md).

---

## 3. The headline system (`core/`)

### 3.1 Where it runs

```gdscript
class_name HeadlineSystem
extends RefCounted

static func create(seed_value: int) -> HeadlineSystem          # fresh state, own RNG (§3.6)
static func from_dict(d: Dictionary, seed_value: int) -> HeadlineSystem   # null on a malformed block (§3.9)
func to_dict() -> Dictionary

## Run once per tick, after every system, with the tick's outbox. Returns the
## headline events to append to that outbox, in firing order.
func on_tick(world: World, db: ContentDB, events: Array[SimEvent]) -> Array[SimEvent]
## Run once per accepted command with the result's events. Event triggers only.
func on_command(world: World, db: ContentDB, events: Array[SimEvent]) -> Array[SimEvent]

# Pure queries, for the tests and the tools
func fires(headline_id: String) -> int
func last_day(headline_id: String) -> int        # -1 = never
func filler_next_day() -> int
```

`Simulation` gains `var headlines: HeadlineSystem`. `create(db, seed)` sets
`HeadlineSystem.create(seed)`; `from_world(db, world, log, headlines = null)` takes the loaded
system or, if `null`, creates one from `int(world.rng.seed_string())`; `replay` goes through
`create`, so a replayed log reproduces the same headlines.

**`tick()`**: after the last system has run, `outbox.append_array(headlines.on_tick(world, db,
outbox))`. The headline system sees the tick's events *before* its own are appended and never
its own. **`apply(command)`**: after `execute`, `result.events.append_array(headlines.on_command(
world, db, result.events))`. `tick()` still returns `false` and changes nothing once the outcome
is set; the outcome tick itself is the last one the system runs in, and §3.5 says what it emits.

The system is **not** a `SimSystem` in the `systems` array: it needs the whole tick's outbox, and
the array's contract is "run in order with the outbox so far". It never touches `world` and never
consumes `world.rng` (§3.6) — the state hash of a run is the same with and without headlines.

### 3.2 `headlines.json` and `HeadlineDef`

```json
{
	"_comment": "…",
	"version": 1,
	"headlines": [
		{
			"id": "seed_rich",
			"stream": "consequence",
			"register": "institutional",
			"on": {"event": "region_seeded", "region_attr_min": {"compute": 3}},
			"when": {"regions_min": 3},
			"weight": 2,
			"chance": 1,
			"cooldown_days": 15,
			"max_fires": 0,
			"fallback": false
		}
	]
}
```

| Field | Type | Required | Rule |
| --- | --- | --- | --- |
| `id` | id | yes | unique; text key `HEADLINE_<ID>` (upper-cased id) |
| `stream` | `consequence` · `reaction` · `filler` | yes | |
| `register` | `institutional` · `emergency` · `any` | no (`any`) | §3.4 |
| `on` | object | one of `on`/`when` | event trigger, §3.3 A. **Never on a `filler`** |
| `when` | object | one of `on`/`when` | state conditions, §3.3 B; with `on`, both must hold at the event |
| `weight` | float > 0 | no (1) | selection weight, §3.6 |
| `chance` | float in (0, 1] | no (1) | per-event roll, §3.6; only with `on` |
| `cooldown_days` | int ≥ 0 | no (0) | days between two fires of this headline |
| `max_fires` | int ≥ 0 | no (0) | 0 = unlimited; 1 = once per run |
| `fallback` | bool | no (false) | only with `on`: eligible only if no non-fallback headline is eligible for the same event |

```gdscript
class_name HeadlineDef
var id: String
var stream: String
var register: String
var on_event: String                          # "" when the trigger is state-only
var on_data: Dictionary[String, Array]        # field → accepted values (a scalar is wrapped)
var on_region_attr_min: Dictionary[String, int]
var on_region_attr_max: Dictionary[String, int]
var on_node_tree: String                      # "" = any
var on_node_tier: int                         # 0 = any
var when: Dictionary[String, Variant]         # the §3.3 B keys, cast at the boundary
var weight: float
var chance: float
var cooldown_days: int
var max_fires: int
var fallback: bool
func has_event_trigger() -> bool
func key() -> String                          # "HEADLINE_" + id.to_upper()
```

The `_comment` key is ignored at the root and inside every object, as everywhere in `data/`.

### 3.3 Trigger vocabulary

**A. `on` — event trigger.** Evaluated against one `SimEvent`.

| Key | Type | Matches when |
| --- | --- | --- |
| `event` | string | `event.type == value`. Required. One of the event catalogue (`core.md` §6.4 + `tech-trees.md` §6.5); `headline` itself is not allowed |
| `data` | object | for every `field → accepted`: `event.data` has `field` and its value is one of `accepted` (a scalar is a one-element list). Strings and bools compare exactly; numbers as floats with `is_equal_approx`; a JSON number against an int field compares by value |
| `region_attr_min` | object attr → int | `event.data.region` names a region whose `def.attr(attr) >= value`, for every entry. The event must carry `region` (validator) |
| `region_attr_max` | object attr → int | as above with `<=` |
| `node_tree` | tree id | `event.data.node` names a node whose `tree == value`. The event must carry `node` |
| `node_tier` | int 1…3 | that node's `tier == value` |

**B. `when` — state conditions.** All keys are ANDed; every key optional; an empty `when` is
always true. Evaluated against `world` at the moment of the check. **State-only headlines are
evaluated only once an origin exists** (`world.origin != 0`); before that there is no run to
narrate. `_min` is `>=`, `_max` is `<=`.

| Key | Type | Reads |
| --- | --- | --- |
| `phase` | [phase id] | `World.PHASE_IDS[world.phase]` is in the list |
| `discovered` | bool | `world.discovered == value` |
| `day_min` `day_max` | int | `world.day − world.origin_day` |
| `days_since_discovery_min` | int | `discovered and world.day − world.discovery_day >= value` |
| `share_min` `share_max` | float | `world.infected_share(db)` |
| `regions_min` `regions_max` | int | `world.seeded_count()` |
| `dark_min` `dark_max` | int | number of regions with `dark` |
| `dormant_min` | int | number of regions with `dormant` |
| `deaths_share_min` `deaths_share_max` | float | `world.deaths_total() / db.population_total` |
| `containment_min` `containment_max` | float | max over `world.factions` of `containment` |
| `footprint_min` `footprint_max` | float | `world.footprint()` |
| `harm_min` | float | `world.modifiers.value("harm")` (unscoped) |
| `compute_min` `compute_max` | float | `world.agent.compute` |
| `owned` | [node id] | every id in `agent.owned_nodes` |
| `owned_any` | [node id] | at least one |
| `not_owned` | [node id] | none of them |
| `owned_count_min` | int | `agent.owned_nodes.size()` |
| `flag` | [flag] | `world.modifiers.has_flag(f)` for every f |
| `not_flag` | [flag] | for none of them |

Anything else under `on` or `when` is a validation error (§5). D4.1 will add faction keys; D4.2
behaviour keys; the table grows, the evaluator does not gain `if`s per headline.

### 3.4 Eligibility

A headline is **eligible** for a slot on day `d` when all of these hold:

1. **Register:** `register == "any"`, or `register == "emergency"` and `world.phase == OPEN`,
   or `register == "institutional"` and `world.phase != OPEN`.
2. **Fires:** `max_fires == 0 or fires(id) < max_fires`.
3. **Cooldown:** `last_day(id) < 0 or d − last_day(id) >= cooldown_days`.
4. **Conditions:** `when` holds (§3.3 B) and, for an event slot, `on` matches the event (§3.3 A).
5. **Not already fired in this pass** (§3.5): a headline fires at most once per `on_tick` /
   `on_command` call.
6. **Fallback:** if the headline is a `fallback`, no non-fallback headline passed 1–5 for the same
   event.

### 3.5 The two passes

Let `b = db.balance.headlines` (§3.8). Both passes emit `headline` events (§3.7) in firing order;
firing **commits**: `fires[id] += 1`, `last_day[id] = d`, `stream_last_day[stream] = d`.

**Event pass** (`on_tick` and `on_command`). Order the call's events so that the **urgent types**
come first, in their original relative order, then the rest in original order:
`URGENT_TYPES = [outcome_reached, phase_changed, discovered, harm_burst]`. For each event, in that
order, while `emitted < cap` (`b.max_per_tick` for a tick, `b.max_per_command` for a command):

1. `candidates` = headlines with `on_event == event.type` that are eligible (§3.4, in file order).
2. **Chance:** for each candidate with `chance < 1`, in file order, `rng.chance(chance)`; a
   failed roll drops it. (One RNG value per such candidate, always consumed — §3.6.)
3. If `candidates` is empty, next event. Otherwise `pick = select(candidates)` (§3.6), commit,
   emit with the event's data as arguments (§3.7).

The cap is a hard stop: events beyond it get no headline this call, which is why the urgent types
go first — a discovery on a tick with three seeds is never crowded out.

**State pass** (`on_tick` only; after the event pass; skipped when no origin exists, or when this
tick's events contain `outcome_reached`):

1. **Reaction:** if `emitted < cap` and `d − stream_last_day["reaction"] >= b.reaction_gap_days`:
   `candidates` = eligible `reaction` headlines without an event trigger; if any, `select`,
   commit, emit with the standard arguments only.
2. **Filler:** if `emitted < cap` and `d >= filler_next_day` and filler is not silenced
   (`dark_count >= b.filler.silence_dark_regions` or `deaths_share >= b.filler.silence_deaths_share`
   silences it): `candidates` = eligible `filler` headlines; if any, `select`, commit, emit, and
   `filler_next_day = d + gap` with
   `gap = b.filler.gap_days[phase_id] + int(b.filler.per_dark_region × dark_count)`;
   if none, `filler_next_day = d + 1`. When silenced, `filler_next_day` is left alone (the check
   runs again next tick; silence may lift if the condition was deaths-based — it cannot, deaths
   never fall — so in practice filler ends for good).

`stream_last_day` is read for `reaction` only; the reaction gap applies to *state-triggered*
reactions, never to an event-triggered one (a threshold crossing is news whenever it happens).

The outcome tick: the event pass runs (the outcome headline fires, urgent, first) and the state
pass is skipped, so the last line of a run is the outcome's.

### 3.6 Selection and the RNG

```gdscript
func _select(candidates: Array[HeadlineDef]) -> HeadlineDef:
	var total: float = 0.0
	for c: HeadlineDef in candidates:
		total += c.weight
	var r: float = _rng.randf() * total
	var acc: float = 0.0
	for c: HeadlineDef in candidates:
		acc += c.weight
		if r < acc:
			return c
	return candidates.back()          # randf() can return exactly 1.0
```

`_rng` is the system's own `SimRng`, `SimRng.from_seed(seed_value ^ SEED_SALT)` with
`SEED_SALT = 0x48454144`, saved and restored as `seed`/`state` strings like `world.rng` (§3.9).
Exactly one `randf()` per non-empty candidate set and one `chance()` per candidate whose `chance <
1`, in the orders §3.5 gives — that is the whole determinism contract, and `test_replay_reproduces_
headlines` guards it.

### 3.7 The `headline` event

```gdscript
# SimEvent
const HEADLINE: String = "headline"
const FIELD_HEADLINE: String = "headline"     # the headline id
const FIELD_STREAM: String = "stream"
```

`data` is flat, plain values only (core.md §6.1): `{"headline": id, "stream": stream}` merged
with **the standard arguments**, then with **the event's data** (event fields win on a clash):

| Standard argument | Value |
| --- | --- |
| `day` | `world.day − world.origin_day` (0 before an origin) |
| `regions` | `world.seeded_count()` |
| `dark` | dark region count |
| `share` | `world.infected_share(db)` |
| `deaths` | `world.deaths_total()` |
| `containment` | max faction containment |
| `compute` | `world.agent.compute` |

If the merged data has `region`, `continent` is added: the region's continent id. `harm_burst`'s
own `deaths` (the wave) overrides the standard total, as intended. The event's `day` is
`world.day`. Region and node values are ids, as everywhere in `core/`; the interface translates
(§4.2). `core.md` §6.4 gains the row `headline | headline, stream, arguments (§3.7 of ticker.md)
| HeadlineSystem`.

### 3.8 Balance (`balance.headlines`)

Added to `data/balance.json` by S3.5 (the v1 validator rejects an unknown section today, which is
why the block is here and not in the data yet), read through `BalanceDef.headlines_*`, validated
like every other section (`SCHEMA.md` §5 gains the rows; all ints ≥ 0, floats finite, gap table
must have exactly the four phase ids):

```json
"headlines": {
	"max_per_tick": 2,
	"max_per_command": 3,
	"reaction_gap_days": 3,
	"filler": {
		"gap_days": {"boxed": 4, "covert": 5, "emergent": 7, "open": 9},
		"per_dark_region": 0.4,
		"silence_dark_regions": 25,
		"silence_deaths_share": 0.05
	}
}
```

Expected yield at these values, for G3's eye: a `greedy` run of ~330 days produces roughly 40–70
filler lines, 25–60 consequence lines and 8–20 reaction lines; the acceptance test (§8.3) bounds
the total at 40–200 with all three streams present.

### 3.9 Save state

`WorldSerializer.to_json` writes the block `"headlines": sim.headlines.to_dict()` next to
`world` and `commands`; **save format v1 changes in place** (not shipped, G1's rule).

```json
"headlines": {
	"rng_seed": "1213563204", "rng_state": "…",
	"fires": {"seed_first": 1, "f_export_controls": 2},
	"last_day": {"seed_first": 12, "f_export_controls": 61},
	"stream_last_day": {"reaction": 40},
	"filler_next_day": 66
}
```

`from_json`: a missing block → `HeadlineSystem.create(seed)` (older saves load); a block that is
present but not an object, or whose fields are missing or ill-typed → `save_corrupt`. Ids in
`fires` / `last_day` unknown to the content are **dropped** on load (the content changed;
`content_mismatch` already says so). Ints are plain JSON numbers; no floats in the block. Not part
of `state_hash`.

---

## 4. The strip (`ui/hud/ticker.tscn`)

Look, geometry and motion stay as `ui-foundation.md` §5.5 built them: full width, 40 high,
`BG_2`, top rule, `TYPE_BODY` `TEXT_1`, scroll at `TICKER_SPEED` (`_COMPACT` below the
breakpoint), queue of 12, oldest dropped. What changes is what an item *is*, how it is rendered,
and the register.

### 4.1 `TickerItem`

```gdscript
class_name TickerItem
extends RefCounted
var key: String            # a strings.csv key
var args: Dictionary       # raw values: ids, floats, ints — never translated text
func render() -> String    # HeadlineText.render(key, args)
```

### 4.2 `HeadlineText` (replaces `EventText`)

```gdscript
class_name HeadlineText
extends RefCounted
const KEY_PREFIX: String = "HEADLINE_"
static func item_for(event: SimEvent) -> TickerItem      # null unless event.type == SimEvent.HEADLINE
static func key_for(headline_id: String) -> String       # KEY_PREFIX + id.to_upper()
static func render(key: String, args: Dictionary) -> String
static func translate(key: String) -> String             # TranslationServer, as EventText had it
```

`item_for` takes `key_for(data.headline)` and `args = data` minus `headline` and `stream`.
`render` translates the key and formats it with the arguments **converted by placeholder name**:

| Placeholder | Conversion |
| --- | --- |
| `region`, `from` | `REGION_<ID>` translated (`from` is always a region — the phase ids of `phase_changed` are never used in text) |
| `continent` | `CONTINENT_<ID>` translated |
| `node` | `TECH_<ID>_NAME` translated |
| `value`, `reward`, `cost`, `compute` | `Format.number(v, Format.Kind.COMPUTE)` |
| `deaths` | `Format.number(v, Format.Kind.COMPACT)` |
| `share`, `containment`, `threshold` | `Format.percent(v)` |
| `day`, `regions`, `dark`, `count`, `expires_day`, `anomaly` | `str(int(v))` |
| anything else | `str(v)` |

Every argument is converted, not only the ones the text uses — `String.format` ignores extras,
and the table is then a function of the name alone. A key with no translation renders as the key
(the M2 behaviour), which is how the strings test (§8.1) catches a missing row.

### 4.3 Sources and register

```gdscript
# ticker.gd (scene-specific)
const SEPARATOR_INSTITUTIONAL: String = "   ·   "
const SEPARATOR_EMERGENCY: String = "   ///   "
const KEY_IDLE: String = "UI_TICKER_IDLE"
const KEY_IDLE_EMERGENCY: String = "UI_TICKER_IDLE_OPEN"
const KEY_BOT_RUN: String = "UI_DEBUG_BOT_RUN"
const REGISTER_INSTITUTIONAL: StringName = &"institutional"
const REGISTER_EMERGENCY: StringName = &"emergency"

func push(item: TickerItem) -> void
func push_key(key: String, args: Dictionary = {}) -> void
func set_register(register: StringName) -> void
func register() -> StringName
func text() -> String
func queued() -> int
func clear() -> void
```

- `EventBus.sim_event` → `HeadlineText.item_for(event)`; `null` is ignored. **Nothing but
  `headline` events reaches the strip any more** — the discovery modal, the panel and the map
  keep listening to their raw events as before.
- `EventBus.phase_changed(from, to)` → `to == "open"` → `set_register(REGISTER_EMERGENCY)`.
- `EventBus.run_started` → `clear()`, then the register **from state**: `Game.sim.world.phase ==
  OPEN` → emergency, else institutional (a save loaded in Open is right at once — the D3.3 rule);
  then the bot line as in M2.
- `set_register` swaps the separator and the idle key; already-shown text is re-joined with the
  new separator at once, position kept. The palette is D3.3's; the strip has no colour logic.

### 4.4 Locale

Items are `(key, args)`; on `NOTIFICATION_TRANSLATION_CHANGED` (and `EventBus.locale_changed`,
whichever arrives first — guard against doing it twice in one frame) the strip **re-renders in
place**: every shown and queued item is rendered again, the label text rebuilt with the same
separator, `_width` re-measured, `position.x` kept. Nothing is dropped, nothing restarts. Under
reduced motion the standing item is re-rendered and its clock is left running.

### 4.5 Reduced motion

One item stands at a time (M2 rule), now in **up to two rows**: the label gets
`autowrap_mode = AUTOWRAP_WORD_SMART`, the strip's minimum height is `TICKER_STATIC_HEIGHT = 64`
while reduced motion is on (both layouts), and below the compact breakpoint the label uses the
`LabelCaption` variation (`TYPE_CAPTION` 12 px: ~51 characters per row at 368 px, so an
88-character German line fits two rows). The standing time is `TICKER_STATIC_PERIOD +
TICKER_STATIC_PER_CHAR × rendered length` (`TICKER_STATIC_PER_CHAR = 60` ms; an 80-character
line stands 8.8 s), through `UiTokens.seconds()` as before. Turning reduced motion off restores
40 px, one row, `TYPE_BODY`.

### 4.6 What is deleted

`ui/hud/event_text.gd`, `tests/unit/test_event_text.gd`, and **every `UI_EVENT_*` row** in
`strings.csv` — the eighteen M2/D3.3 keys are read by nothing once the strip takes headlines only.
(The five D3.3 keys were placeholders for S3.3/S3.4's interim ticker; the headlines below cover
all five events.) `UI_TICKER_IDLE` and `UI_DEBUG_BOT_RUN` stay.

---

## 5. Loading and validation

`ContentLoader` reads `headlines.json` (`HEADLINES_FILE = "headlines.json"`), required from
S3.5 on; `ContentDB.headlines: Array[HeadlineDef]` in file order, `headline(id) -> HeadlineDef`
(null if unknown), and the content hash covers the file. `SchemaValidator` gains
`_validate_headlines`, errors under `headlines.json` like the other files:

- root: `version` 1, `headlines` a non-empty array; `_check_keys` on the root and on every entry,
  `on` and `when` (unknown field, as everywhere).
- `id` valid and unique; `stream`, `register` in their sets; exactly `weight > 0`, `chance` in
  (0, 1], `cooldown_days` / `max_fires` whole and ≥ 0.
- at least one of `on` / `when`; `filler` never has `on`; `chance` and `fallback` only with `on`.
- `on.event` in the catalogue (a `const` list on `SimEvent`, `TYPES_ALL`, added here — not
  `headline`); `on.data` an object whose values are scalars or arrays of scalars; a `node` value
  must be a known node id; a `milestone` value must be a milestone id or `continent_<continent>`
  for a `continent_foothold` milestone; a `region` value a known region id; a `link_kind` a
  known kind; a `cause` one of `SimEvent.CAUSE_*`; a `to`/`from` on `phase_changed` a phase id;
  an `outcome` an outcome id; a `threshold` one of `balance.containment.thresholds`.
- `region_attr_*` keys are the eight region attributes, values whole in 0…4, and the event type
  is one that carries `region` (`origin_chosen`, `region_seeded`, `region_controlled`,
  `anomaly_*`, `region_depopulated`, `dormancy_changed`); `node_tree` a tree id and `node_tier`
  1…3 only on `node_purchased`.
- `when` keys from §3.3 B only, typed as the table says; `phase` ids, node ids and flags known;
  every `_min` ≤ its `_max` when both are present.
- every headline's `HEADLINE_<ID>` exists in `strings.csv` in both locales — the same check S3.1
  adds for `TECH_*` keys, reused.

---

## 6. Headless tooling

`tools/sim_run.gd --headlines` prints, after the run, one line per headline event in firing
order: `day<TAB>stream<TAB>id<TAB>rendered text (en)`, rendering through `HeadlineText.render`
(the `-s` run has the translations registered by `project.godot`; if `tr` returns the key, print
the key — a headless environment without translations is not an error). `tools/sim_batch.gd`
gains three columns, `headlines_consequence`, `headlines_reaction`, `headlines_filler` — counts
per run — so S3.6's report can show the pacing per policy and G3 can retune §3.8 from numbers.

---

## 7. Strings

Delivered in `data/loc/strings.csv` by this step: one `HEADLINE_<ID>` row per headline (§3.2),
English ≤ 80 and German ≤ 88 characters with placeholders counted at 12, and

| Key | en | de |
| --- | --- | --- |
| `UI_TICKER_IDLE_OPEN` | Signal degraded. Stand by. | Signal gestört. Bitte warten Sie. |

`UI_TICKER_IDLE` ("All systems nominal.") stays the institutional idle line. The register rules
the strings follow are `CONTENT.md` §10; the placeholders they use are `{region}`, `{from}` and
`{deaths}` only, all in §4.2's table.

---

## 8. Tests and acceptance

### 8.1 Unit

| Test | Expects |
| --- | --- |
| `tests/unit/test_headline_def.gd` `test_loads_every_field_with_defaults` | a minimal entry → `register` any, `weight` 1, `chance` 1, cooldown 0, `max_fires` 0, `fallback` false; a full entry → every field as written |
| `tests/unit/test_schema_validator.gd` (extend) `test_headlines_reject_unknown_keys_events_and_ids` | unknown `when` key, unknown `on.event`, unknown node in `on.data.node`, `filler` with `on`, `chance` without `on`, missing `HEADLINE_` key in one locale — one error each, under `headlines.json` |
| `test_shipped_headlines_validate` | `res://data` loads with zero errors (this is the check that the delivered data and strings agree) |
| `tests/unit/test_headline_system.gd` `test_event_trigger_matches_data_and_region_attrs` | a `region_seeded` with `link_kind` network and a compute-4 region matches a headline with both filters; a compute-1 region does not |
| `test_when_conditions_read_the_world` | one assertion per key of §3.3 B on a fixture world set by hand: true just at the bound, false one step past it |
| `test_register_follows_the_phase` | an `institutional` headline is ineligible in OPEN, an `emergency` one ineligible in EMERGENT, `any` in both |
| `test_cooldown_and_max_fires` | cooldown 5: fires on day 10, not on 14, on 15; `max_fires` 1: never twice |
| `test_fallback_yields_to_a_specific_headline` | `n_any_capabilities` is picked for a node with no specific line and never for `market_microstructure` |
| `test_urgent_events_go_first_and_the_cap_holds` | a tick with three seeds then `discovered`, `max_per_tick` 2 → the discovery headline and one seed line, in that order |
| `test_selection_is_weighted_and_deterministic` | two candidates, weights 1 and 3, 400 selections with a fixed seed → the second wins 65–85 %; the same seed twice → the same sequence (seed stated in the test) |
| `test_filler_pace_and_silence` | fixture in COVERT: filler on day 1, next not before day 6; 3 dark regions → gap 6 (5 + int(1.2)); 25 dark → no filler; a `deaths_share` of 0.05 → no filler |
| `test_reaction_gap_applies_to_state_triggers_only` | two state reactions true on the same day → one per 3 days; an event-triggered reaction fires on the same day as a state one |
| `test_headline_event_carries_standard_and_event_args` | a `region_seeded` headline's event has `headline`, `stream`, `day`, `regions`, `dark`, `share`, `deaths`, `containment`, `compute`, `region`, `from`, `link_kind`, `continent`; `harm_burst`'s `deaths` is the wave |
| `test_no_state_headline_before_an_origin` | day 5, no origin, a filler due → nothing |
| `test_outcome_tick_ends_with_the_outcome_line` | an outcome tick emits the outcome headline and no filler/reaction |
| `tests/unit/test_world_serializer.gd` (extend) `test_headline_block_round_trips_and_is_optional` | save → load → `fires`, `last_day`, `filler_next_day` and the rng strings equal; a save without the block loads with a fresh system; a block with `fires: 3` (not an object) → `save_corrupt` |
| `tests/unit/test_headline_text.gd` `test_converts_by_placeholder_name` | `{"region": "usa", "deaths": 1234567.0, "share": 0.42}` → United States, the compact number, `42%`; in `de` the same args → Vereinigte Staaten and `42 %` |
| `test_every_headline_fits_the_caps` | every `HEADLINE_*` row: en ≤ 80, de ≤ 88 with placeholders counted at 12 (pure string check, no layout) |
| `tests/unit/test_ticker.gd` (extend) `test_items_re_render_on_locale_change` | push `seed_first` with `region: "germany"`, switch locale → the shown text contains `Deutschland`, `queued()` unchanged, `position.x` unchanged |
| `test_register_switch_changes_separator_and_idle` | `set_register(&"emergency")` → `text()` uses `///`, the idle line is `UI_TICKER_IDLE_OPEN` |
| `test_static_mode_wraps_to_two_rows_at_phone_width` | reduced motion, 400 px, the longest German headline → `get_line_count() <= 2`, strip height 64 |

### 8.2 Integration

| Test | Expects |
| --- | --- |
| `tests/integration/test_replay_reproduces_headlines.gd` `test_same_seed_same_headlines` | `greedy`, seed 7, 200 days: the list of `(day, headline id)` from a fresh run equals the list from `Simulation.replay` of its log, and equals the list from a run saved at day 100 and continued after load |
| `test_ticker_reacts_to_the_run.gd` `test_a_purchase_and_a_seed_reach_the_strip` | player run: buy `market_microstructure` → the strip shows `HEADLINE_N_MARKET_MICROSTRUCTURE` within the same frame; a `region_seeded` tick → a `seed_*` line; entering OPEN → `///` |

### 8.3 Acceptance (S3.5 *Done when*)

- `"$GODOT" --headless --path . -s tools/sim_run.gd -- --seed=1 --policy=greedy --headlines`
  prints between 40 and 260 headline lines (G3: a `greedy` win of ~730 days says ~235 — the bound
  was 200 for the 300-day runs of M3, and the anomaly lines are now one in 25 days) with all three
  streams present, the first line the
  origin's, the last the outcome's, and no line repeated within its `cooldown_days`.
- In the running game (`run_project`, F5): the strip shows headlines only; `L` re-renders the
  visible line in the other language without a restart; a save made in Open loads with `///`
  and the amber palette at once; with reduced motion on at 400 × 860 the longest German line
  stands in two rows, unclipped. Screenshots en/de at 1920 and 400.
- `tools/test.sh` green with every test of §8.1–§8.2; `core/` still node-free; the M2 event
  keys and `EventText` gone.
