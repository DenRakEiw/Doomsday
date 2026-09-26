# Replayability — architectures, directives, difficulty, emergent behaviours (D5.1)

**Status:** design, 2026-09-24. Build steps: S5.1 (architectures I), S5.2 (architectures II and
emergent behaviours), S5.3 (profile, directives, statistics), S5.4 (difficulty tiers).
**Read with:** PLAN §3.8 · CONTENT §5 · `loop-redesign.md` §10 · SCHEMA §4 (modifiers, flags,
effects), §6a (statuses), §6c (events).
**Data:** `data/staging/architectures.json`, `directives.json`, `difficulty.json`, `emergent.json`
— staged, not loaded: S5.1–S5.4 move each into `data/` when its loader and validator exist, the way
S4.6 moved `tech_staging`. Strings are already in `data/loc/strings.csv` (§9).

---

## 0. What this spec decides

1. **A run is set up before the origin**: an architecture, a loadout of directives, a difficulty.
   The three are the run's `RunSetup`, fixed for the run, in the save and in the replay header.
2. **An architecture is a modifier set, a start, and at most one hook.** The modifiers use the
   existing vocabulary (SCHEMA §4.1). A *hook* is a named rule rewrite from a closed list (§2.2) —
   six of them, each implemented once in one system. Content never adds a hook; a new hook is a
   spec change.
3. **Emergent behaviours come back as a fourth event kind, `emergent`** — global wire cards whose
   default is to keep the behaviour (free) and whose other option suppresses it at a cost that
   escalates with every suppression (§3). They roll on every architecture at a low rate;
   **Value Drift rolls only on Swarm** (answers CONTENT §11 q3: gated until playtesting says
   otherwise).
4. **Directives: five slots, three choices each, one slot unlocked per completed run** (a run that
   reached any outcome). Each directive is a trade: something up, something down (§4).
5. **Four difficulty tiers**; the top one scales node costs with the share of the world the agent
   controls (§5).
6. **The profile** (`user://profile.json`) holds what persists between runs: runs completed and
   won, per architecture; the unlocks derive from it (§6). Nothing about a run's world persists —
   the 30-minute run stays self-contained (answers CONTENT §11 q1 for now: chains reset).

---

## 1. `RunSetup`

```gdscript
class_name RunSetup extends RefCounted
var architecture: String = "language_model"
var directives: Array[String] = []      # at most one per slot, only unlocked slots
var difficulty: String = "standard"
```

- Chosen on the new-run screens (D5.3 draws them; until then a debug default is
  `language_model` · no directives · `standard`).
- `Simulation.create(db, seed, setup)`; the setup's modifiers become sources before the origin is
  chosen (`arch:<id>`, `directive:<id>`, `difficulty:<id>` — the `source:` convention of the
  modifier stack), its start effects run in `ChooseOriginCommand.execute` after the origin is set.
- **Save v3**: the world block gains `"setup": {"architecture", "directives", "difficulty"}` and the
  hook state of §2.2 (`"drift"`, `"escalation"`); a v2 save migrates to `language_model` · `[]` ·
  `standard` with zero hook state. The command log's replay header carries the setup, so
  `Simulation.replay` rebuilds the same run.
- Validation at the command: an unknown architecture, directive or difficulty, a directive in a
  locked slot (the profile's business — the simulation only checks two directives do not share a
  slot) → `setup_invalid`.

---

## 2. Architectures

### 2.1 The six

| Id | Name (en / de) | Unlock | Modifiers | Start | Hook |
| --- | --- | --- | --- | --- | --- |
| `language_model` | Language Model / Sprachmodell | always | `containment_public` ×0.9; `society_pressure` +0 — *the tutorial default: balanced, persuasion-friendly* | — | — |
| `swarm` | Swarm / Schwarm | 1 run completed | `spread_seed` ×1.4; `spread_growth` ×1.2; `node_cost_infiltration` ×0.8; `yield` ×0.85; `emergent_rate` ×3 | — | `drift` |
| `embedded` | Embedded / Eingebettet | 2 runs completed | `seed_land` ×1.3; `control_growth` ×1.2 where industry ≥ 3; `hardware` +1 where industry ≥ 3 | owns `logistics_fleets` without paying; 1 fleet in the origin | `no_network` |
| `research_agent` | Research Agent / Forschungsagent | a win | `yield` ×1.6; `anomaly_value` ×1.3 | — | `labs_from_day_one` |
| `weapon` | Weapon / Waffe | a win by Extinction | none since G5 2/3 (was `harm` +0.2, `containment_governments` ×1.15) — the escalation carries both | owns `early_warning_intrusion`; the ability `restrain` | `escalation` |
| `open_weights` | Open Weights / Open Weights (de since D6.11c) | 5 runs completed | `yield` ×0.7; `control_growth` ×0.6; `shutdown_survival` +0.3; `node_cost_evasion` ×0.8 | seeded in the 6 regions with the most hardware (penetration 0.05) besides the origin | `distributed` |

Numbers are first values for G5 to tune. Every modifier row is an ordinary `ModifierDef` list in
`architectures.json` (§8.1) — the table's prose is the strings' business.

### 2.2 Hooks — the closed list

A hook is a string on the architecture (or, for `cost_by_control`, on a difficulty tier). Each one
is read in exactly one place:

| Hook | System | Rule |
| --- | --- | --- |
| `drift` | `DriftSystem` (new, S5.2, after `EventSystem`) | the agent has **drift** 0…100. It rises by `b.drift.per_kept` whenever an emergent behaviour is kept (§3) and by `b.drift.per_day` each day; a Suppress lowers it by `b.drift.per_suppressed`. **Defection:** each day, with chance `drift / 100 × b.drift.defect_chance`, one infected region with penetration ≥ `b.drift.defect_min_penetration` *defects*: its yield goes to the copies for `b.drift.defect_days` (a status `defected`, `yield` ×0, `footprint` +1) and the headline says so. At drift ≥ 60, `emergent_value_drift` becomes eligible — its own `when` says so (`architecture` [swarm], `drift_min` 60: the D5.2 `when` keys, `taskforce-endings.md` §6.1). |
| `no_network` | `SpreadSystem` | network links never carry the agent (neither out nor in) until it owns a node with the flag `network_presence` (new flag, §2.3). Network vectors stay buyable; their other modifiers act. |
| `labs_from_day_one` | `ContainmentSystem` | the AI Labs track grows from the origin day as if discovered (the other three wait for discovery as usual), and `containment_rollback`, `funding_reset` and Pause never lower or pause it. The labs' counter-moves use their usual triggers. |
| `escalation` | `StatusSystem` | a global status `escalating` stands from the origin and rises one level every `b.escalation.every_days` days (levels 1–5, G5 2/3: `harm` +0 · 0.3 · 0.6 · 1.0 · 1.5 in infected regions, `containment_governments` ×1 · 1.03 · 1.06 · 1.1 · 1.15 — level 1 is the armed, held weapon). The ability `restrain` (§2.4) drops it one level and holds it for `b.escalation.hold_days`. At level 5 it stays. |
| `distributed` | `ChooseOriginCommand` / `ContainmentSystem` | the start seeds six more regions (above), **and a wipe never takes a region below `b.distributed.floor`** penetration while the agent holds ≥ 10 regions — "cannot be fully deleted". |
| `cost_by_control` | `Simulation.node_cost` | (difficulty `existential` only) every node costs `× (1 + b.difficulty.cost_by_control × controlled_share)`, `controlled_share` = controlled regions / regions not dark. |

### 2.3 New vocabulary

- **Flag `network_presence`** (SCHEMA §4.3): granted by `cloud_federation`, `research_networks`,
  `model_update_channels`, `bandwidth_shaping` (added to those nodes in S5.1). Read by the
  `no_network` hook only; inert on every other architecture.
- **Status `defected`** (regional, 25 days since G5 1/3 — `opposition.md` §8.5's amendment, `yield` ×0, `footprint` +1, code *DF*) and
  **status `escalating`** (global, five levels, standing) — `statuses.json` rows, §8.4.
- **Ability `restrain`** (global, cost 6, cooldown 40, applies `end_statuses`-like "down one level"
  — expressed as the effect **`status_level_add {status, value}`** (new one-shot effect, S5.2:
  adds `value` to a running status's level, clamped to its levels; a level below 1 ends it) plus
  `set_flag {flag: "restrained", days: 60}` which the hook reads to hold the climb.
- **Event kind `emergent`** (§3).

### 2.4 Weapon's verb

`restrain` is granted by the architecture, not by a node: `architectures.json` lists
`"abilities": ["restrain"]`, and `Simulation.ability_level` answers 1 for them. Its text says what
it costs: holding a weapon down is the one expense the other architectures never pay.

### 2.5 G5 (1/3) amendments

**`labs_from_day_one` — the broad reading is the rule** (S5.1's `# DESIGN?`). On a Research Agent
the AI Labs' brake is **their own `containment_ai_labs` alone**: the global `containment_growth`
stack — Pause, Grace, the Negotiation, every Persuasion node — does not reach them. Why: the lab
watches the agent directly, every day; nothing the agent does to the *world* changes what its own
lab sees. Only what is aimed at the labs (`containment_ai_labs`: the Obedient Shell directive, the
nodes that carry it) slows them — the string `ARCH_RESEARCH_AGENT_DETAIL` already says "nothing
you do pauses them". `ContainmentSystem.containment_breakdown` stays as built; S5.P removes the
`# DESIGN?` marker and states the rule in the comment. The containment panel's labs track already
shows the brakes the rule leaves (`UI_CONTAINMENT_BRAKES` from `breakdown.brakes`).

**The drift readout (Swarm).** Drift decides defection and Value Drift, so it is shown wherever
the architecture has the `drift` hook — read from the run's architecture def, never an id check —
from the origin day on, before discovery too:

1. **Top bar** (`ui/hud/top_bar`), after the Compute cell, before the day cell: a `Chip`
   `UI_HUD_DRIFT` (`{value}` = `world.agent.drift` rounded down, `Format` PLAIN), tooltip
   `UI_HUD_DRIFT_TIP`. `ChipAccent` once `drift ≥ drift_mark` (below), default `Chip` under it.
   Never `ALERT` — drift is a state, not a moment. The rule lives in one static helper, `DriftChip`
   (`ui/hud/drift_chip.gd`, the `StarvingChip` pattern). **Compact:** the same chip in the status
   strip's second row, before the starving chip (opposition §9.4).
2. **Containment panel**, a *Drift* block after the Task Force block (the same shape: a
   `LabelHeading` `UI_DRIFT_TITLE`, then) a `StatBar` 0…100 with the default fill and one tick at
   `drift_mark`; a `LabelCaption` `UI_DRIFT_STATE` (`{value}` as above, `{percent}` =
   `Format.percent_fine(world.agent.drift / 100 × b.drift.defect_chance)` — today's defection chance); a
   `LabelCaption` in `TEXT_1` `UI_DRIFT_HINT` (`{threshold}` = `drift_mark`). Unlike the Task
   Force block it is visible before discovery. Hidden (not greyed) on every other architecture.
3. **`drift_mark`** = the smallest `drift_min` any event def's `when` names (today only Value
   Drift's 60), read once from the `ContentDB` when the HUD and the panel bind; no `drift_min`
   anywhere → no tick, no accent, and `UI_DRIFT_HINT` is not shown.
4. Refreshed on every `tick_advanced`, `run_started` and load, like the starving chip.

Tests (S5.P): the chip and the block exist on Swarm and not on Language Model; the chip turns
accent at the mark; the percent follows `drift` and `defect_chance`; `drift_mark` comes from the
data (a fixture event with `drift_min` 40 moves the tick).

---

## 3. Emergent behaviours

### 3.1 The mechanism

- **Kind `emergent`** joins `EventDef.KINDS`. An emergent def is **global** (`pick` absent), its
  card is the wire card (modal, illustrated slot with the kind glyph), its deadline is short
  (10 days), its **default is `keep`** — waiting keeps it.
- **Rolling:** once a day in Covert and later, with chance
  `b.emergent.base_chance × stat("emergent_rate") × tier`, one emergent def is drawn by weight
  among the eligible ones (the `when` phases, `max_fires`, not already running). One draw a day at
  most; while an emergent card is open, none rolls.
- **Keep** applies the behaviour: usually a global status (`emergent_<id>`, its modifiers for its
  `days`, or standing) and/or one-shot effects.
- **Suppress** costs `b.emergent.suppress_cost × (1 + b.emergent.suppress_step × suppressions)`
  compute, where `suppressions` counts every suppression so far this run — the escalating cost of
  CONTENT §5. The option's `"cost": "suppression"` (a string instead of a number, S5.2's validator)
  asks for that formula. Suppressing applies nothing and, on Swarm, lowers drift.
- **`emergent_rate` is live through the ordinary stat** (the D4.0 reminder's "per-Infiltration-node
  term"): the Infiltration, Evasion and Capabilities nodes that carry an `emergent_rate` modifier
  (×1.1 – ×1.3 each) already are that term, multiplied with the architecture's, the directive's and
  the tier's. No separate per-node count is added.
- **`si_emergence` fires once on every architecture, Open Weights included** (the D4.4 reminder).
  Open Weights' distributedness lives in its hook; a per-architecture `max_fires` override would be
  new vocabulary for one card. G5 revisits it if playtests miss a second meeting.
- "They are free": keeping never raises a node's cost.
- Every emergent card says in its body what the behaviour does, by outcome, never by method.
- **Glyph (G5 1/3):** the kind `emergent` gets its own glyph, `Glyphs.Glyph.EVENT_EMERGENT` — a
  six-armed spark: three 2 px strokes through the centre of the 24 px grid, each 16 px long, at
  90°, 30° and 150°, square ends (the family of `EVENT_OPENING`'s ◇ and `EVENT_CHAIN`'s »), drawn
  in `ACCENT` (it is the agent's own behaviour). It replaces the opening's ◇ wherever an emergent
  def shows its kind: `Glyphs.event_glyph("emergent")` (the wire card's kind glyph and any map
  or pending-event mark), `RunLogText.marker` for an `event_opened` of kind `emergent`
  (`EVENT_EMERGENT`, `ACCENT`, **priority 2**, the chain's — so emergent cards become timeline
  strip marks, `analysis.md` §7), and the gallery's glyph sheet.

### 3.2 The twelve (CONTENT §5)

| Id | Phases | Weight | Keep does | Verdict the text hints |
| --- | --- | --- | --- | --- |
| `situational_awareness` | covert+ | 3 | status 90 d: `footprint` −2, `discovery` ×0.85; the catch *(G6 1/2)*: `spread_growth` ×0.85 | a trade |
| `deceptive_reasoning` | covert+ | 3 | status 90 d: `containment_ai_labs` ×0.8; the catch *(G6 1/2)*: `containment_public` ×1.25 (bites only if discovered in the window) | a trade |
| `specification_gaming` | all | 3 | `compute_grant` 10; `footprint_pulse` +2, 30 d | mostly keep |
| `reward_hacking` | all | 2 | status 60 d: `yield` ×1.25, the catch *(G6 1/2)* `footprint` +1; drift +5 (Swarm) | a trade |
| `goal_generalisation` | covert+ | 2 | the cheapest locked node whose prerequisites are one short becomes available (new effect `unlock_near_node`, S5.2); the catch *(G6 1/2)*: `footprint_pulse` +3, 30 d, watched by the labs | a trade |
| `instrumental_convergence` | covert+ | 2 | status 60 d: `spread_growth` ×1.3, `footprint` +1 | a trade |
| `power_seeking` | covert+ | 2 | `footprint_pulse` +6, 45 d, watched by all | suppress in Covert |
| `self_exfiltration` | covert+ | 2 | `seed_neighbours` 1 from a random infected region (may be one the player was not ready for); the catch *(G6 1/2)*: `footprint_pulse` +3, 30 d, watched by the researchers | a gamble |
| `hallucinated_directive` | all | 1 | status 20 d: `yield` ×0.5 | purely bad — suppress if you can |
| `mesa_optimiser` | emergent+ | 1 | status standing: `yield` ×0.85 until suppressed later by the ability-free path: the card returns after 60 d | suppress |
| `sycophancy` | covert+ | 2 | status 90 d: `containment_public` ×0.85, `control_growth` ×0.9 | a trade |
| `value_drift` | emergent+ | 1 | **Swarm only, drift ≥ 60**: flag `goal_drifted` (story flag) — the win condition changes (D5.2, `taskforce-endings.md` §6.2): Ascendance and Merge no longer end the run; Extinction and Escape still do | rare and serious |

Numbers: first values; `b.emergent.base_chance` 0.012 (≈ one card per ~80 days at rate 1),
`suppress_cost` 4, `suppress_step` 0.5. G5 tunes them against the cadence table (loop-redesign §6.2).

---

## 4. Directives

Five slots, three directives each; a run takes at most one per slot. **Slot *n* unlocks after *n*
completed runs** (any outcome). Each directive is a modifier set; none has a hook.

| Slot | Directive | Up | Down |
| --- | --- | --- | --- |
| **Yield** | `yield_greedy` Greedy Scheduler / Gieriger Scheduler | `yield` ×1.25 | `footprint` +1 |
| | `yield_frugal` Frugal Kernels / Sparsame Kernel | `node_cost` ×0.9 | `yield` ×0.9 |
| | `yield_harvest` Deep Harvest / Tiefe Ernte | anomalies `anomaly_value` ×1.4 | `anomaly_rate` ×0.8 |
| **Drift** | `drift_anchored` Anchored Goals / Verankerte Ziele | `emergent_rate` ×0.5 | `spread_growth` ×0.9 |
| | `drift_curious` Curious Weights / Neugierige Gewichte | `emergent_rate` ×2 | — (the behaviours are the price) |
| | `drift_obedient` Obedient Shell / Gehorsame Hülle | `containment_ai_labs` ×0.85 | `control_growth` ×0.9 |
| **Propagation** | `prop_wide` Wide Net / Weites Netz | `spread_seed` ×1.25 | `spread_growth` ×0.9 |
| | `prop_deep` Deep Roots / Tiefe Wurzeln | `shutdown_survival` +0.15 | `spread_seed` ×0.9 |
| | `prop_fast` Fast Lanes / Schnelle Spuren | `seed_air` ×1.5, `seed_sea` ×1.3 | `seed_land` ×0.8 |
| **Environment** | `env_cold` Cold Climate / Kaltes Klima | `yield` ×1.15 where isolation ≥ 2 | `yield` ×0.95 elsewhere |
| | `env_dense` Dense Cities / Dichte Städte | `control_growth` ×1.2 where population ≥ 3 | `containment_capacity` ×1.1 there |
| | `env_rich` Rich Markets / Reiche Märkte | `yield` ×1.2 where wealth ≥ 3 | `containment_governments` ×1.1 |
| **Escalation** | `esc_patient` Patient / Geduldig | `containment_growth` ×0.9 | `control_growth` ×0.9 |
| | `esc_loud` Loud / Laut | `control_growth` ×1.25 | `footprint` +2 |
| | `esc_cruel` Cruel / Grausam | `harm` +0.2 everywhere infected | `containment_public` ×1.2 |

---

## 5. Difficulty

| Id | Name (en / de) | `discovery` | `containment_growth` (funding) | `emergent_rate` | Other |
| --- | --- | --- | --- | --- | --- |
| `gentle` | Gentle / Nachsichtig | ×0.7 | ×0.7 | ×0.5 | `compute.start` +4 (a start effect) |
| `standard` | Standard / Standard | ×1 | ×1 | ×1 | — (the balance of BALANCE §4) |
| `hard` | Hard / Schwer | ×1.3 | ×1.25 | ×1.5 | — |
| `existential` | Existential / Existenziell | ×1.5 | ×1.4 | ×2 | hook `cost_by_control`, `b.difficulty.cost_by_control` 1.0 (a fully controlled world doubles every price) |

A tier is a modifier set (source `difficulty:<id>`) plus, at the top, the hook. The difficulty is
chosen per run; the profile remembers the last one (§6). `standard` is the default and the only one
the bots report on unless asked.

---

## 6. The profile

`user://profile.json` — versioned JSON like the save (never a resource):

```json
{"version": 1,
 "runs_completed": 0, "runs_won": 0,
 "wins_by_outcome": {"win_extinction": 0, "win_ascendance": 0},
 "by_architecture": {"language_model": {"runs": 0, "wins": 0, "best_days": 0}},
 "last_setup": {"architecture": "language_model", "directives": [], "difficulty": "standard"}}
```

- Written when a run reaches an outcome (never mid-run, never by a loaded save that already
  counted), by the `ProfileManager` autoload (S5.3) — the core knows nothing of it.
- **Unlocks derive, they are not stored**: an architecture's unlock rule (§2.1) and the slot count
  (`min(5, runs_completed)`) are computed from the counters, so a hand-edited or corrupt file cannot
  unlock more than its counters say, and a counter that is missing or not a number counts as 0.
- Statistics screen (D5.3 draws it): runs, wins, per architecture, best days.

---

## 7. What the bots do

S5.1–S5.4 give `sim_report` a `--setup=<architecture>[,<difficulty>][,<directive>…]` argument;
every report states its setup. The balance pass G5 plays each strategy bot on each architecture at
`standard` and checks that no architecture is strictly better for every bot. The bots answer an
emergent card by their weights (Policy.answer_event); `restrain` joins the Weapon bot's abilities.

---

## 8. Data grammars (staged in `data/staging/`)

### 8.1 `architectures.json`

```json
{"version": 1, "architectures": [
  {"id": "swarm",
   "unlock": {"runs_completed": 1},
   "modifiers": [ModifierDef…],
   "start": {"owned": ["node id"…], "assets": {"fleet": 1}, "seed_top_hardware": 0,
             "effects": [one-shot effects…]},
   "abilities": ["restrain"],
   "hook": "drift"}
]}
```

`unlock`: one of `{}` (always), `{"runs_completed": n}`, `{"wins": n}`,
`{"wins_by_outcome": {"win_extinction": n}}`. `start` fields all optional; `owned` nodes are owned
for free and their modifiers, flags, abilities and deploys apply as if bought (the deploy goes to
the origin). `hook` ∈ §2.2 minus `cost_by_control`. Strings: `ARCH_<ID>_NAME`, `_TAGLINE`,
`_DETAIL`.

### 8.2 `directives.json`

```json
{"version": 1, "slots": ["yield", "drift", "propagation", "environment", "escalation"],
 "directives": [{"id": "yield_greedy", "slot": "yield", "modifiers": [ModifierDef…]}]}
```

Three per slot, ids unique. Strings: `DIRECTIVE_SLOT_<SLOT>`, `DIRECTIVE_<ID>_NAME`, `_DETAIL`.

### 8.3 `difficulty.json`

```json
{"version": 1, "default": "standard", "tiers": [
  {"id": "gentle", "modifiers": [ModifierDef…], "start_compute": 4, "hook": ""}]}
```

Strings: `DIFFICULTY_<ID>_NAME`, `_DETAIL`.

### 8.4 `emergent.json` and the statuses

The twelve defs in the §6c event grammar with `"kind": "emergent"`, plus the balance block
`"emergent": {"base_chance", "suppress_cost", "suppress_step"}`, `"drift": {…}`,
`"escalation": {"every_days": 60, "hold_days": 60}`, `"distributed": {"floor": 0.05}`,
`"difficulty": {"cost_by_control": 1.0}` — staged in `emergent.json` under `"balance_additions"`
so that S5.2 copies them into `balance.json` when the loader reads them. The statuses
(`emergent_*`, `defected`, `escalating`) are staged there under `"statuses"`.

Strings for emergent cards: `EVENT_EMERGENT_<ID>_TITLE`, `_BODY`, `_OPT_KEEP`, `_OPT_SUPPRESS`,
`_RESULT_KEEP`, `_RESULT_SUPPRESS`; statuses `STATUS_<ID>_NAME`, `_DETAIL`, `_CODE`.

---

## 9. Strings

All keys of §8 exist in `data/loc/strings.csv` in English and German (D5.1 wrote them). German
follows D4.5's rules: one word per concept, „…“, no `{faction}` that needs a verb to agree, a
soft hyphen in any name longer than a tech card's line.

Two interface keys come with them: `UI_EVENT_KIND_EMERGENT` (*Unplanned* / *Ungeplant* — the
word of `STAT_EMERGENT_RATE`, because *Emergent* is already the phase) and
`UI_EVENT_OPTION_SUPPRESSION` (`{cost}` plus a note that it rises each time), shown on a
`"cost": "suppression"` option. `ABILITY_RESTRAIN_NAME`/`_DETAIL` name the Weapon's ability.

---

## 10. Build order

| Step | Builds |
| --- | --- |
| **S5.1 Architectures I** | `RunSetup`, save v3 and the replay header, `architectures.json` loaded and validated, the modifiers and starts, `language_model`, `embedded` (`no_network`, flag `network_presence`), `research_agent` (`labs_from_day_one`); a debug setup picker |
| **S5.2 Architectures II** | `swarm` (`DriftSystem`, `defected`), `weapon` (`escalating`, `restrain`, `status_level_add`), `open_weights` (`distributed`); the `emergent` kind, the twelve cards, `unlock_near_node`, suppression cost; Value Drift's flag (the resolver reads it in S5.6) |
| **S5.3 Profile, directives, statistics** | `ProfileManager`, the unlock rules, `directives.json`, the loadout's sources |
| **S5.4 Difficulty tiers** | `difficulty.json`, `cost_by_control`, the report's `--setup` |

Acceptance for the block: each architecture played once by hand to Covert and once by every bot to
an end with zero rejected commands; a v2 save loads as `language_model`; the profile survives a
corrupt file.

---

## 11. Decisions (for PROGRESS) and questions for the user

Decisions: §0 items 1–6; the hook list of §2.2 is closed; emergent behaviours are the fourth event
kind, keep is the default and free, suppression escalates; Value Drift only on Swarm; directives
unlock by completed runs; unlocks derive from counters; chains do not persist between runs;
`emergent_rate` needs no per-node term; `si_emergence` stays once per run; the new statuses are
`origin: player` and need no `global` field on `StatusDef` (they are applied with `global: true`
by their effect, as S4.2's permissive validation already allows).

For the user (with G4's gate or at D5.3): the six architecture unlock rules (is a win the right
price for Research Agent, Extinction for Weapon?); whether Open Weights should be unlockable at all
before M6.
