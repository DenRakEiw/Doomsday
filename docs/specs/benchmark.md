# Benchmark and spectator mode — models play the game, players watch the replays

D6.9 (2026-09-25, overnight). Builds from it: **S6.12** (§1–§11: the model policy, the digest,
the answer, the backends, the cache, the score, the leaderboard, the tool) and **S6.13** (§12:
the spectator view). Data written here: `data/benchmark.json`; strings in
`data/loc/strings.csv` (§13). The user's decisions this builds on: *Decisions* 2026-09-22 (G1:
tool first, then the spectator view; OpenRouter as the one endpoint, key from the environment,
model id and parameters next to seed and score).

**D6.9b (2026-09-25)** adds **§16, the global leaderboard** (a public GitHub repository, runs
verified by replay in this repository's workflow, read by the game's list) and **§11.5, the
pre-flight cost estimate** with the cap lowered to 2 USD; it amends §0 items 6, 8, 10 and 13, §1,
§3, §8.3, §11, §12.7, §13–§15. Builds from it: S6.12 (§11.5), **S6.12b** (§16.3–§16.5, §16.8),
S6.13 (§16.6–§16.7).

---

## 0. What this spec decides

1. **A model is one more `Policy`** (`ModelPolicy`), played by the same day loop as every bot
   (core.md §11): commands only, never state, never `world.rng`. The runs it plays are ordinary
   runs with an ordinary command log — which is what makes every benchmark run replayable for
   nothing, whatever the model did.
2. **The model sees what a player sees, in the game's own words.** The prompt is built from the
   strings the interface shows — region, node, ability, event, faction and status names, effect
   lines, event bodies and option labels, run-log lines — plus a short rules brief and answer
   format written for it (§5, §13). **No free text comes back:** the answer is ids and one stance
   word from a closed list (§7). Nothing a model writes is stored, shown or committed. That is the
   content rule's form here: outcome-language in, ids out.
3. **Two messages per call, no conversation:** a static *brief* per run (rules, the setup, the
   world, the tree, the abilities — identical across a run's calls, so providers that cache a
   prefix charge less for it) and a *digest* per decision (the state now, what changed, what the
   last answer did). The model's memory is the digest and its own last stance.
4. **It decides every 10 days** (not every history interval: the history stride is 1 since S4.8
   and thins — §4.1 says why) **and whenever something new asks for an answer**: an event it has
   not seen, or the Task Force setting up where it is. Anomalies are collected for it every day.
5. **Invalid answers cost a decision, not the run:** one repair retry, then nothing is done that
   decision; an action that cannot be done is skipped with its reason, and the next digest says
   so (§7.4).
6. **The adapter is GDScript over `HTTPClient`, in a headless tool** (`tools/bench/`), not a
   Python driver and not an `HTTPRequest` node. The policy, the digest and the parser are the
   same code the tests run, in-process with the real simulation — no bridge protocol, no second
   copy of the state. It never ships: `tools/*` is excluded from every export (release.md §6.2),
   so the game itself never calls a model. Parallelism is one process per shard of seeds.
   **The game's one network access** (since D6.9b) is the global leaderboard's download when the
   player opens the benchmark list, and one run file when they watch it (§16.6) — plain GETs of
   public files, nothing sent, off with a setting.
7. **The key comes from the environment only** (`OPENROUTER_API_KEY`, or the variable
   `--key-env` names): never an argument, never a file in the repo, never a save, never a log
   line, never an entry.
8. **Budget and cost:** at most **250** answers a run (live or cached, so a re-run from the cache
   reproduces the run exactly), a cost cap per invocation (**2 USD** by default since D6.9b,
   pending user confirmation — §3), a **cost estimate printed before the first request** that
   stops the tool when it is above the cap unless `--yes` (§11.5), and a cache of
   request → *parsed* answer keyed by model, parameters, prompt and parser version (§9) — a
   repeated run costs nothing.
9. **Score:** per run `50 + 50 × (1 − days / max_days)` for a win, **0** for anything else
   (a loss, a timeout at 2 000 days); a leaderboard row is the mean over a fixed seed suite
   (**standard: 10 seeds, 1001–1010**, Language Model · Standard · no directives). The built-in
   bots are scored the same way as reference rows (§10).
10. **Entries and leaderboard are files in the repo** (`benchmark/runs/*.json`,
    `benchmark/leaderboard.json` + a generated `benchmark/LEADERBOARD.md`); the cache is local
    and ignored. That is the developer's working board. **The global leaderboard** (D6.9b, §16)
    is the public repository `DenRakEiw/doomsday-leaderboard`: runs arrive by pull request, a
    scheduled workflow in this (private) repository verifies each by replay and publishes a
    verified-only `leaderboard.json`, which the game's list reads.
11. **Mock backends test everything without a key** (§8.2): deterministic answers built from the
    typed digest (`cheapest`, `wait`), and broken ones (`invalid`, `mixed`) — so S6.12 proves a
    reproducible leaderboard run without spending anything.
12. **The spectator view replays an entry in the real session**: a `ReplayPolicy` feeds the
    entry's command log to `Game`, a strip names the model, seed, decision and stance, the
    console line speaks for the model, and the results say whether the replay reached the
    recorded hash. Entries recorded on other content are listed but cannot be watched (§12).
13. **Where players find it:** a *Benchmark* button on the title, shown only when an entry
    exists — shipped ones from `res://benchmark/showcase/` (empty in M6; which runs to ship is
    the user's call at G6 2/2) and the player's own from `user://benchmark/runs/`. Debug builds
    also list the repo's `res://benchmark/runs/`. Since D6.9b the list also shows **the global
    leaderboard** (§16.6), fetched only when the list opens.

**Not in scope:** live model play inside the game (the game never calls a model); streaming
answers; tool/function calling (one JSON object is simpler and works on every chat model);
multi-turn conversations; a model-written memo or explanation (free text — §0 item 2); the
German brief as a ranked suite (it runs, `--locale=de`, but the leaderboard ranks `en`);
uploading results from the game or the tool (a run reaches the global board by a pull request
made by hand, §16.2); a web page beyond the public repository's `LEADERBOARD.md`; proving which
model played a run (§16.1); statistics or achievements from watched
runs (a watched run is a bot run: nothing counts — release.md §2.2).

---

## 1. Files

| File | S | What |
| --- | --- | --- |
| `data/benchmark.json` | D6.9 | the configuration (§3) — written here |
| `game/bench/bench_config.gd` | 6.12 | `class_name BenchConfig` — loads and validates §3 |
| `game/bench/bench_digest.gd` | 6.12 | `class_name BenchDigest` — the typed digest and its builder (§6) |
| `game/bench/bench_faction_row.gd` · `bench_region_row.gd` · `bench_offer_row.gd` · `bench_ability_row.gd` · `bench_event_row.gd` · `bench_option_row.gd` | 6.12 | the digest's typed rows (§6.1) |
| `game/bench/bench_prompt.gd` | 6.12 | `class_name BenchPrompt` — brief and digest → text; the request messages (§5, §6.3) |
| `game/bench/bench_action.gd` | 6.12 | `class_name BenchAction` — one parsed action (§7.1) |
| `game/bench/bench_answer.gd` | 6.12 | `class_name BenchAnswer` — the parser and its result (§7.2) |
| `game/bench/bench_decision.gd` | 6.12 | `class_name BenchDecision` — what one decision did (§4.4) |
| `game/bench/model_backend.gd` | 6.12 | `class_name ModelBackend` — the interface (§8.1) |
| `game/bench/model_reply.gd` | 6.12 | `class_name ModelReply` — a backend's result (§8.1) |
| `game/bench/mock_backend.gd` | 6.12 | `class_name MockBackend` (§8.2) |
| `game/bench/model_policy.gd` | 6.12 | `class_name ModelPolicy extends Policy` (§4) |
| `game/bench/bench_score.gd` | 6.12 | `class_name BenchScore` — the formula and the leaderboard rows (§10) |
| `game/bench/bench_entry.gd` | 6.12 | `class_name BenchEntry` — one run's file, read and written (§10.2) |
| `game/bench/replay_policy.gd` | 6.13 | `class_name ReplayPolicy extends Policy` (§12.2) |
| `game/bench/bench_library.gd` | 6.13 | `class_name BenchLibrary` — finds and reads entries for the game (§12.1) |
| `tools/bench/bench_run.gd` | 6.12 | the tool (`extends SceneTree`, no `class_name`) (§11) |
| `tools/bench/open_router_backend.gd` | 6.12 | `extends ModelBackend`, no `class_name`, preloaded (§8.3) |
| `tools/bench/bench_cache.gd` | 6.12 | the file cache, no `class_name`, preloaded (§9) |
| `tools/bench/leaderboard_writer.gd` | 6.12 | rebuilds `leaderboard.json` and `LEADERBOARD.md`, no `class_name` (§10.3) |
| `benchmark/runs/` · `benchmark/showcase/` | 6.12 | entries; each directory gets a `.gitkeep` |
| `benchmark/cache/` | 6.12 | **git-ignored** (`.gitignore` gains `/benchmark/cache/`) |
| `ui/hud/spectator_strip.gd` + `.tscn` | 6.13 | the strip (§12.5) |
| `ui/modals/benchmark.gd` + `.tscn` | 6.13 | the list of entries (§12.7) and the global leaderboard (§16.6) |
| `tools/bench/bench_estimate.gd` | 6.12 | the pre-flight estimate and the price lookup, no `class_name`, preloaded (§11.5) |
| `tools/bench/verify_runs.gd` | 6.12b | the verifier tool (`extends SceneTree`) (§16.4) |
| `tools/bench/bench_verifier.gd` · `verify_record.gd` | 6.12b | the judging and one `verified/` record, no `class_name`, preloaded (§16.3–§16.4) |
| `.github/workflows/leaderboard.yml` | 6.12b | the scheduled verification and publishing workflow (§16.5) |
| `tests/fixtures/bench/determinism_entry.json` | 6.12b | the cross-platform canary, recorded on Windows (§16.8) |
| `game/bench/global_board.gd` · `global_board_row.gd` · `global_board_run.gd` | 6.13 | `class_name GlobalBoard` / `GlobalBoardRow` / `GlobalBoardRun` — the downloaded board, parsed (§16.6) |
| `game/bench/global_board_client.gd` | 6.13 | `class_name GlobalBoardClient extends Node` — fetch, cache, fallback, one run's download (§16.6) |
| `benchmark/global/leaderboard.json` | 6.13 | the shipped copy of the public `leaderboard.json` (§16.6) |

**Why `game/bench/` and not `core/`:** the digest reads translated strings and the interface's
static text helpers (`TechText`, `EventView`, `RunLogText`, `TaskForceText`, `TechNode.state_for`,
`Format`), which `core/` must not. Nothing in `game/bench/` names an autoload (the headless tool
and `tools/check_scripts.gd` run without them); `class_name` on each, as `game/platform/` does.
Every one of those helpers was checked for this: none touches an autoload.

---

## 2. What a benchmark run is

One run = one seed of a suite, played to its end or to `max_days`, by one model with one set of
parameters, with one prompt version. Setup: `benchmark.json` `setup` (the default run). The day
loop is `sim_harness.gd`'s `advance` — the same one `sim_run` uses — with a `ModelPolicy`;
`Policy.MAX_COMMANDS_PER_DAY` (64) still bounds a day (12 actions + anomalies stay far below).
The policy seed (`Policy.seed_for`) is set up but unused — a model policy draws no random numbers.

---

## 3. `data/benchmark.json`

Presentation data (SCHEMA §10 — the core never reads it): `"version": 1`, keys starting `_`
ignored, tab-indented. Read by `BenchConfig.load_file(path := "res://data/benchmark.json")`,
which returns a config with `errors: Array[String]` (a bad file never crashes; the tool exits 1
naming the reasons).

| Key | Type | Value | Meaning |
| --- | --- | --- | --- |
| `prompt_version` | int ≥ 1 | 1 | bumped by any change to §5–§7's text or format; part of the cache key and of every entry |
| `parser_version` | int ≥ 1 | 1 | bumped by any change to §7.2's rules |
| `setup` | object | `RunSetup.to_dict()` of the default run | validated by `RunSetup.from_dict` + `validate(db)` in the tool |
| `max_days` | int | 2000 | a run still going then is a timeout (score 0) |
| `interval_days` | int ≥ 1 | 10 | the scheduled rhythm (§4.1) |
| `max_calls` | int ≥ 1 | 250 | answers a run may ask for, retries included, live or cached (§4.3) |
| `max_actions` | int ≥ 1 | 12 | actions read from one answer; the rest are dropped |
| `retry_invalid` | int ≥ 0 | 1 | repair retries after an unreadable answer |
| `digest.log_max` | int | 30 | run-log lines in one digest (newest kept) |
| `digest.targets_max` | int | 20 | region ids listed per ability or per site list |
| `suites` | object of int arrays | `standard` 1001–1010, `quick` 1001–1003 | fixed seed sets; only `standard` is ranked |
| `score.win_base` · `score.win_speed` | float | 50 · 50 | §10.1 |
| `defaults.temperature` | float | 0.0 | sent unless `--temperature` |
| `defaults.max_completion_tokens` | int | 1200 | sent unless `--max-tokens` |
| `defaults.json_mode` | bool | true | sends `response_format: {"type": "json_object"}` |
| `defaults.locale` | string | `en` | brief and digest language |
| `http.base_url` | string | `https://openrouter.ai/api/v1` | any OpenAI-compatible endpoint (`--base-url`) |
| `http.key_env` | string | `OPENROUTER_API_KEY` | the environment variable read for the key |
| `http.timeout_s` | int | 180 | one request, connect to last byte |
| `http.retries` · `http.backoff_s` | int · float | 5 · 2.0 | transient failures (§8.3): waits 2, 4, 8, 16, 32 s |
| `http.max_cost_usd` | float | **2.0** | per tool invocation (§8.3, §11.5); `--max-cost` overrides. 10.0 until D6.9b (the user: "quite a lot"); pending user confirmation |
| `http.models_path` | string | `/models` | appended to `base_url` for the public price list (§11.5); only asked of `openrouter.ai` |
| `estimate.chars_per_token` | int ≥ 1 | 4 | the `--dry-run` measure (§11.1 step 3, §11.5) |
| `estimate.calls_per_run` | int ≥ 1 | 80 | the likely calls of one run (§11.4's 60–90) |
| `estimate.digest_growth` | float ≥ 1 | 1.5 | the average digest against the day-0 one |
| `estimate.output_tokens_per_call` | int ≥ 1 | 300 | the likely answer length (the upper figure uses `max_completion_tokens`) |
| `global.leaderboard_url` | string | `https://raw.githubusercontent.com/DenRakEiw/doomsday-leaderboard/main/leaderboard.json` | the published board (§16.6) |
| `global.run_base_url` | string | `https://raw.githubusercontent.com/DenRakEiw/doomsday-leaderboard/main/` | + a row's `runs/<file>` (§16.6) |
| `global.repo_url` | string | `https://github.com/DenRakEiw/doomsday-leaderboard` | for people (docs, `LEADERBOARD.md`); the game does not open it |
| `global.timeout_s` | int | 20 | one download in the game |
| `global.max_board_bytes` · `global.max_run_bytes` | int | 1 000 000 · 4 000 000 | download limits; the run limit equals `BenchLibrary.MAX_BYTES` and `validate.py`'s |
| `global.max_rows` | int | 500 | rows read from a board |
| `global.min_refetch_s` | int | 300 | a reopened list within this reuses the last fetch |
| `global.cache_runs_max` | int | 50 | downloaded run files kept in `user://benchmark/online/runs/` |
| `global.verify_limit` | int | 100 | runs judged per verifier invocation (§16.4) |

---

## 4. `ModelPolicy`

```gdscript
class_name ModelPolicy
extends Policy
const ID: String = "model"
var decisions: Array[BenchDecision] = []     # in order; the entry's `decisions` (§10.2)
var calls: int = 0                          # answers asked for (live + cached, retries included)
var cached_calls: int = 0
var invalid_answers: int = 0                # decisions whose final answer was unreadable
var rejected_actions: int = 0               # actions skipped (malformed, over the limit, or refused)
var tokens_in: int = 0
var tokens_out: int = 0
var cost_usd: float = 0.0
var budget_exhausted: bool = false
var fatal: String = ""                      # set when the backend failed for good (§8.3); the tool stops
func _init(p_backend: ModelBackend, p_config: BenchConfig, p_params: Dictionary, p_locale: String) -> void
func policy_id() -> String                  # "model"
func next_command(sim: Simulation) -> Command
```

It is **not** registered in `Policy.create` (it needs a backend); the tool builds it.

### 4.1 When it decides

On day `d` (the loop calls `next_command` before the day's tick) a decision happens once, when
any of these holds and `fatal` is empty:

1. `world.agent.origin == 0` (day 0: the origin);
2. `d − last_decision_day ≥ interval_days`;
3. an open event exists whose id no earlier digest listed;
4. `world.task_force.state == TaskForce.STATE_SETUP` in a region with `penetration > 0`, and
   the pair `[team.region, team.action]` differs from the pair the last digest showed (the
   policy remembers it; `[0, ""]` at first).

**Why not "every history interval":** the plan's wording predates S4.8, where the history
stride became 1 day and thins as a run grows — a rhythm that changes with the run's length would
make two models' decisions incomparable. A fixed 10 days plus the triggers keeps a 600-day run
near 60–90 calls, and nothing the player could answer goes unseen.

### 4.2 One day, in order

`next_command` works through a per-day queue; when the day changes it rebuilds it:

1. **Housekeeping:** every anomaly on the map, oldest first (`CollectAnomalyCommand`, each
   checked with `can_apply`). The brief tells the model this happens (§5). Before the origin
   there are none.
2. **The decision** (if §4.1 says so): build the digest (§6), ask the backend (§8), parse (§7),
   turn the actions into commands (§7.3) and queue them in answer order.
3. Each queued command is checked with `sim.can_apply` **when it is its turn** (after the ones
   before it were applied) and skipped with its reason if refused — counted in
   `rejected_actions`, recorded in the decision's `refused` for the next digest's feedback. So
   the harness's own `rejected` counter stays 0 (a refusal is the model's, not a policy bug).
4. Queue empty → `null` (done for the day).

The decision happens after the anomalies so their compute is spendable in the same decision.

### 4.3 The budget

`calls` counts every answer asked for — first answers and retries, served live or from the
cache. When `calls == max_calls`, `budget_exhausted = true` and no further decision is made:
events take their defaults at their deadlines, the housekeeping continues, the run plays to its
end. Counting cached answers too is what lets a re-run from a full cache reproduce the original
run command for command.

### 4.4 `BenchDecision`

```gdscript
class_name BenchDecision
extends RefCounted
var day: int
var stance: String            # a §7.1 stance id, or "" (none given, or the answer was unreadable)
var actions: int              # actions read from the answer (after the limit)
var done: int                 # actions that were applied
var refused: Array[Dictionary] = []   # {"action": String (§7.5's compact form), "reason": String (a Command FAIL_* id or a §7.2 action error)}
var invalid: String           # "" or the §7.2 answer error of the final attempt
var cached: bool              # every answer of this decision came from the cache
var retried: bool
func to_dict() -> Dictionary  # these keys; `refused` as given
static func from_dict(d: Dictionary) -> BenchDecision   # null on a missing or ill-typed key
```

---

## 5. The brief (the system message)

Built once per run by `BenchPrompt.brief(db: ContentDB, setup: RunSetup, config: BenchConfig)
-> String` after `TranslationServer.set_locale(locale)`. Sections separated by one empty line;
lines joined with `\n`. Order:

1. `BENCH_BRIEF_ROLE`
2. `BENCH_BRIEF_LOOP` (`{interval}` = `interval_days`)
3. `BENCH_BRIEF_WIN` (`{max_days}`)
4. `BENCH_BRIEF_COMPUTE`, `BENCH_BRIEF_SPREAD`, `BENCH_BRIEF_PHASES`, `BENCH_BRIEF_FACTIONS`,
   `BENCH_BRIEF_EVENTS`, `BENCH_BRIEF_NODES`, `BENCH_BRIEF_DORMANCY` — one paragraph each.
5. **The run:** `BENCH_BRIEF_SETUP` (`{name}` `ARCH_<ID>_NAME`, `{detail}` `ARCH_<ID>_DETAIL`),
   `BENCH_BRIEF_DIFFICULTY` (`DIFFICULTY_<ID>_NAME` / `_DETAIL`), one `BENCH_BRIEF_DIRECTIVE` per
   directive (`DIRECTIVE_<ID>_NAME` / `_DETAIL`), `BENCH_BRIEF_SCENARIO` if any
   (`ScenarioDef.name_key` / `detail_key`). Keys via each def's key helper where one exists.
6. **The world:** `BENCH_BRIEF_WORLD`, then one `BENCH_BRIEF_REGION_ROW` per region in index order:
   `{region}` the id, `{name}` `REGION_<ID>`, `{continent}` `CONTINENT_<ID>`, `{tiers}` =
   `BENCH_BRIEF_TIERS` filled with the region's nine attribute tiers (`RegionDef.ATTRIBUTES_ALL`
   order — isolation and the derived population included — placeholders named as the attributes), `{links}` = the neighbours as
   `<id> (<UI_LINK_KIND>)` joined with `, `, in link-list order; `BENCH_BRIEF_AIRGAPPED` appended
   when `air_gapped`.
7. **The tree:** `BENCH_BRIEF_TREE`, then one `BENCH_BRIEF_NODE_ROW` per node in content order:
   `{node}` id, `{name}` `TECH_<ID>_NAME`, `{tree}` `UI_TREE_TAB_<TREE>`, `{tier}`, `{cost}` the
   base cost (`Format.number(…, COMPUTE)`), `{needs}` = `BENCH_BRIEF_NEEDS_ALL` (`{nodes}` ids
   joined `, `) / `BENCH_BRIEF_NEEDS_ANY` / `BENCH_BRIEF_NEEDS_NONE`, `{effect}` =
   `TECH_<ID>_EFFECT`; then appended in this order when they apply: `BENCH_BRIEF_CLOSES`
   (`excludes`), `BENCH_BRIEF_GROUP` (`{group}` `GROUP_<ID>`, `{max}` `sim.group_max` on a fresh
   simulation of the run's setup), `BENCH_BRIEF_DEPLOYS` (`{count}`, `{kind}` the asset plural),
   `BENCH_BRIEF_NEEDS_ASSETS` (per kind), `BENCH_BRIEF_GRANTS` (`{ability}` id, `{level}`), and
   `BENCH_BRIEF_MODIFIERS` with `{lines}` = `TechText.modifier_line` for each modifier joined
   `; ` (so the model reads the same effect lines as the tree's detail).
8. **Abilities:** `BENCH_BRIEF_ABILITIES`, then one `BENCH_BRIEF_ABILITY_ROW` per ability in content
   order: `{ability}` id, `{name}` `ABILITY_<ID>_NAME`, `{target}` `BENCH_BRIEF_TARGET_REGION` /
   `_GLOBAL`, `{cost}`, `{cooldown}` days, `{detail}` `ABILITY_<ID>_DETAIL`.
9. **Stances:** `BENCH_BRIEF_STANCES`, then `- <id>: BENCH_STANCE_<ID>_HINT` for the seven ids of §7.1.
10. **The answer:** `BENCH_BRIEF_FORMAT_1` … `_4` (`_3` takes `{max_actions}`) and then the literal example of §7.1 (not
    translated — it is the format), then `BENCH_BRIEF_FORMAT_VERBS` followed by one line per verb:
    `- <verb>: BENCH_VERB_<VERB>`.

The brief is identical for every call of a run and across runs of the same suite and setup.
Expected size on the current content: ≈ 9–11 k tokens (61 regions, 72 nodes, 17 abilities).

---

## 6. The digest (the user message)

### 6.1 The typed digest

`BenchDigest.build(sim: Simulation, memory: Dictionary, config: BenchConfig) -> BenchDigest` —
pure, reads the simulation, never changes it. `memory` is what the policy carries between
decisions: `decision` (int, this decision's 1-based number), `last_day` (int, −1 before the first), `compute_earned` (float, then),
`containment` (faction id → float, then), `stance` (String), `feedback` (the last
`BenchDecision`, or null), `seen_events` (Array[int]).

```gdscript
class_name BenchDigest
extends RefCounted
var day: int
var decision: int                     # 1-based
var phase: String                     # World.PHASE_IDS
var compute: float
var income: float                     # (compute_earned now − then) / (day − last_day); 0 at the first decision
var starving_days: int                # sim.starving_days_left() while world.starving_days > 0 (and it is ≥ 0), else −1
var discovered: bool
var discovery_day: int
var risk: float                       # sim.discovery_risk()["total"] while not discovered, else 0
var factions: Array[BenchFactionRow]  # Faction.FACTION_IDS order
var leader: String                    # sim.threat_leader()
var task_force: String                # TaskForceText.state_line(world, db), already translated
var regions: Array[BenchRegionRow]    # §6.2
var seeded: int
var controlled: int
var dark: int
var origins: Array[String]            # eligible origin ids, index order — only before the origin
var owned: Array[String]              # world.agent.owned_nodes, in purchase order
var offers: Array[BenchOfferRow]
var abilities: Array[BenchAbilityRow]
var events: Array[BenchEventRow]      # world.events order
var log: Array[String]                # RunLogText lines since last_day, oldest first, at most log_max (newest kept)
var log_skipped: int                  # lines dropped by log_max
var feedback: BenchDecision           # null at the first decision
var stance: String                    # the last stance, "" at first
```

| Row | Fields |
| --- | --- |
| `BenchFactionRow` | `id`, `containment: float`, `change: float` (since the last decision; 0 at first), `move_state: String`, `move_event: String`, `move_days: int` (from `sim.next_move`) |
| `BenchRegionRow` | `id`, `penetration`, `control`, `alive_share: float` (alive ÷ (alive + deaths), 1 when both 0), `stage: int` (`sim.society_stage`), `dormant: bool`, `origin: bool`, `reached: bool` (penetration > 0), `assets: Dictionary[String, int]` (non-zero kinds), `statuses: Array[String]` (`"<status id>:<days left>"`, `-1` for standing), `team: bool` (the Task Force is in this region) |
| `BenchOfferRow` | `node`, `cost: float` (`sim.node_cost`), `affordable: bool`, `sites: Array[String]` (deploying nodes only) |
| `BenchAbilityRow` | `ability`, `level`, `cost: float`, `ready_in: int` (`max(0, ability_ready_day − day)`), `global: bool`, `targets: Array[String]` |
| `BenchEventRow` | `event: int` (the open event id), `def`, `kind`, `region: String` (id or ""), `days_left: int` (`deadline_day − day`), `title`, `body` (both translated through `EventView`), `options: Array[BenchOptionRow]` |
| `BenchOptionRow` | `option`, `text` (`EventView.option_text`), `cost: float` (`sim.option_cost`), `suppression: bool`, `lock: String` (`EventView.lock_text` of `lock_reason`, "" when open), `short: bool` (compute < cost), `is_default: bool` |

### 6.2 What goes in, and why

- **Regions:** every region not dark with `penetration > 0`, **plus** every not-dark region linked
  to one of those (the frontier, `reached = false`), **plus** any region named by an open event,
  a status or the Task Force. Index order. Before the origin: none (the `origins` list stands in).
  Static facts (name, attributes, links) are in the brief; the digest carries only what moves.
- **Offers:** every node whose `TechNode.state_for(def, sim)` is `AFFORDABLE` or `AVAILABLE` —
  the two states the tree lets a player act on or save for; `affordable` = `AFFORDABLE`. For a
  deploying node, `sites` = the regions `i` with `sim.site_eligibility(node, i).is_empty()`,
  ordered by `sim.hardware(i) × penetration` descending then index (the order `Policy.best_site`
  scores by), at most `targets_max`; a deploying node with no site is left out.
- **Abilities:** every ability with `sim.ability_level(id) > 0`. `targets` for a region ability =
  region ids `r` where `sim.can_apply(UseAbilityCommand.new(id, r))` is `""`,
  `ability_cooldown` or `insufficient_compute` (so a cooling ability still says where it could
  go), index order, at most `targets_max`.
- **Events:** every open event (a decision is triggered by a new one — §4.1).
- **Log:** `RunLogText.text(entry, db)` for each `world.run_log` entry with `day > last_day`
  (the Analysis log's lines, so the model reads what a player's log says).

### 6.3 Rendering

`BenchPrompt.digest_text(d: BenchDigest, db: ContentDB) -> String`, in the run's locale.
Sections, each only when it has content, separated by one empty line:

1. `BENCH_DIGEST_HEAD` (`{day}`, `{decision}`, `{phase}` = `UI_PHASE_<PHASE>`).
2. `BENCH_DIGEST_COMPUTE` (`{compute}`, `{income}` — `Format.number(…, COMPUTE)`); then
   `BENCH_DIGEST_STARVING` (`{days}`) if starving; then `BENCH_DIGEST_RISK` (`{percent}` =
   `Format.percent_fine(risk)`) if not discovered, else `BENCH_DIGEST_DISCOVERED` (`{day}`).
3. `BENCH_DIGEST_FACTIONS`, one `BENCH_DIGEST_FACTION_ROW` each (`{faction}` `FACTION_<ID>`,
   `{percent}` `Format.percent(containment)`, `{change}` = `Format.addend(change × 100)` (signed
   points),
   `{move}` = `BENCH_DIGEST_MOVE_PREPARING` (`{move}` `EVENT_<ID>_TITLE`, `{days}`) /
   `_HELD` / `_COOLDOWN` / `_NONE`); then `BENCH_DIGEST_LEADER` (only when `leader` is not empty); then `BENCH_DIGEST_TASK_FORCE`
   (`{line}`). Before discovery the faction section still shows (the numbers are 0 and the
   moves none — it is what the containment panel shows).
4. Before the origin: `BENCH_DIGEST_ORIGINS` (`{regions}` ids joined `, `). Otherwise
   `BENCH_DIGEST_TOTALS`, `BENCH_DIGEST_REGIONS` and one row per region:
   `BENCH_DIGEST_REGION_ROW` (`{region}`, `{penetration}`, `{control}`, `{alive}` percents,
   `{stage}` `SOCIETY_STAGE_<n>`) for reached ones, `BENCH_DIGEST_REGION_FRONTIER` (`{region}`)
   for the rest; each followed by the extras that apply, in this order: `_ORIGIN`, `_DORMANT`,
   `_ASSETS` (`{assets}` = `<count> × <kind plural>` joined `, `), `_STATUS` per status (`{status}`
   `STATUS_<ID>_NAME`, `{days}`; standing → `_STATUS_STANDING`), `_TEAM`.
5. `BENCH_DIGEST_OWNED` (`{nodes}` ids joined `, `) or `_OWNED_NONE`.
6. `BENCH_DIGEST_OFFERS` + one `BENCH_DIGEST_OFFER_ROW` each (`{node}`, `{cost}`, `{mark}` =
   `BENCH_DIGEST_AFFORDABLE` or "", then `BENCH_DIGEST_OFFER_SITES` (`{regions}`) when deploying),
   or `BENCH_DIGEST_OFFERS_NONE`.
7. `BENCH_DIGEST_ABILITIES` + one `BENCH_DIGEST_ABILITY_ROW` each (`{ability}`, `{level}`,
   `{cost}`, `{ready}` = `BENCH_DIGEST_READY` / `BENCH_DIGEST_READY_IN` (`{days}`), `{targets}` =
   `BENCH_DIGEST_TARGET_WORLD` / `_TARGET_REGIONS` (`{regions}`) / `_TARGET_NONE`), or
   `BENCH_DIGEST_ABILITIES_NONE`.
8. `BENCH_DIGEST_EVENTS`, then per event `BENCH_DIGEST_EVENT_HEAD` (`{event}` the id, `{title}`,
   `{kind}` `UI_EVENT_KIND_<KIND>`, `{days}`), the body on its own line, then one
   `BENCH_DIGEST_OPTION_ROW` per option (`{option}` id, `{text}`, `{cost}` `EventView.cost_text`,
   `{notes}` = `BENCH_DIGEST_OPTION_NOTES` with its `{notes}` = the lock text,
   `BENCH_DIGEST_OPTION_SHORT` when short, `UI_EVENT_DEFAULT_MARK` when default — those that
   apply, joined ` · ` — or "" when none applies); or `BENCH_DIGEST_EVENTS_NONE`.
9. `BENCH_DIGEST_LOG` + the lines (each prefixed `- `), `BENCH_DIGEST_LOG_MORE` (`{count}`) when
   lines were skipped; or `BENCH_DIGEST_LOG_NONE`. Omitted at the first decision.
10. Feedback (from the second decision on): `BENCH_DIGEST_FEEDBACK` (`{day}`, `{stance}` =
    `BENCH_STANCE_<ID>` or `BENCH_STANCE_NONE`, `{done}`, `{total}`), then one
    `BENCH_DIGEST_FEEDBACK_REFUSED` (`{action}`, `{reason}` the raw reason id) per refusal; or
    `BENCH_DIGEST_FEEDBACK_INVALID` (`{reason}`) when the answer was unreadable.
11. `BENCH_DIGEST_ASK`.

Ids appear raw (`usa`, `benchmark_sandbagging`, `17`) — they are what the answer must name.
Numbers go through `Format`, so a German digest reads German.

### 6.4 The request

`BenchPrompt.messages(brief: String, digest: String, retry_reason: String = "") -> Array[Dictionary]`
= `[{"role": "system", "content": brief}, {"role": "user", "content": digest}]`, plus
`{"role": "user", "content": BENCH_RETRY with {reason}}` for a retry. The model's unreadable
answer is **not** echoed back (it would carry free text into the next request).

---

## 7. The answer

### 7.1 Format (prompt version 1)

```json
{"stance": "spread", "actions": [
  {"do": "origin", "region": "usa"},
  {"do": "buy", "node": "cloud_federation"},
  {"do": "buy", "node": "market_microstructure", "region": "germany"},
  {"do": "use", "ability": "harvest", "region": "china"},
  {"do": "use", "ability": "pause"},
  {"do": "answer", "event": 17, "option": "sandbag"},
  {"do": "sleep", "region": "france"},
  {"do": "wake", "region": "france"}
]}
```

(Real ids of the current content — a test keeps them real, §14.1. The event number is whatever
the digest lists; `sandbag` is an option of the AI Labs' audit.)

| `do` | Fields | Command |
| --- | --- | --- |
| `origin` | `region` | `ChooseOriginCommand(region)` |
| `buy` | `node`, `region` (only for a deploying node; absent = "") | `PurchaseNodeCommand(node, region)` |
| `use` | `ability`, `region` (absent = "" for a global one) | `UseAbilityCommand(ability, region)` |
| `answer` | `event` (whole number), `option` | `ChooseEventOptionCommand(event, option)` |
| `sleep` · `wake` | `region` | `SetDormancyCommand(region, true / false)` |

`stance` ∈ `spread` · `hide` · `earn` · `develop` · `defend` · `finish` · `wait` — what the model
says it is about. It changes nothing in the game; the spectator shows it (§12.5) and the digest
hands it back. `BenchAction`: `verb`, `region`, `node`, `ability`, `event: int`, `option`
(unused fields "" / −1), `func to_command() -> Command`, `func compact() -> String` (`buy
market_microstructure germany` — the feedback form: verb and the non-empty fields, space-joined).

### 7.2 Parsing (`BenchAnswer.parse(text: String, max_actions: int) -> BenchAnswer`)

Result: `valid: bool`, `error: String`, `stance: String`, `actions: Array[BenchAction]`,
`dropped: Array[Dictionary]` (`{"index": int, "reason": String}`). Steps, first failure wins:

1. `text` empty after `strip_edges` → invalid `empty`.
2. If it contains ```` ``` ````, keep what is inside the first fenced block (a leading `json`
   language tag stripped).
3. Keep from the first `{` to the last `}`; none → invalid `no_json`.
4. `JSON.parse` fails → invalid `bad_json`; not a Dictionary → invalid `not_object`.
5. `actions` missing or not an Array → invalid `no_actions`. (`"actions": []` is valid: wait.)
6. `stance`: a String in §7.1's list, lower-cased and stripped; anything else → "" (no error).
7. Each action in order: not a Dictionary, unknown `do`, a required field missing or of the
   wrong type, `event` not a whole number → dropped with `malformed_action`; after
   `max_actions` read actions, the rest → dropped with `over_limit`. Unknown extra keys are
   ignored everywhere.

`to_cache() -> Dictionary` = `{"invalid": error}` or `{"stance", "actions": [<verb + fields>],
"dropped"}`; `static from_cache(d: Dictionary) -> BenchAnswer` restores it exactly (null on a bad
dictionary, which the cache treats as a miss).

### 7.3 From action to command

`BenchAction.to_command()` builds the command with the ids as given — an unknown id is not
checked here; `sim.can_apply` refuses it at its turn (§4.2 step 3) with the command's own
`FAIL_*` reason (`invalid_region`, `unknown_node`, `unknown_ability`, `unknown_event`, …). One
code path decides what is allowed: the same one that decides it for the player.

### 7.4 An unreadable answer

1. Retry up to `retry_invalid` times with the same messages plus `BENCH_RETRY`; each retry is
   one call (§4.3). A retry is not made when the budget is spent.
2. Still unreadable → the decision records `invalid = <error>`, does nothing, and
   `invalid_answers += 1`. The next decision comes at the normal rhythm (the next digest's
   feedback says the answer could not be read).
3. `dropped` actions count in `rejected_actions` and appear in the next feedback with their
   reason, like refused ones.

### 7.5 What the model is told about refusals

The next digest lists every refused or dropped action as `compact()` + reason id. Nothing else
comes back — no hint of what would have worked.

---

## 8. Backends

### 8.1 The interface

```gdscript
class_name ModelBackend
extends RefCounted
## One answer for one request. Blocking: the headless tool has nothing else to do meanwhile.
func answer(messages: Array[Dictionary], digest: BenchDigest, params: Dictionary) -> ModelReply
func backend_id() -> String                  # "openrouter", "mock:cheapest", …

class_name ModelReply
extends RefCounted
const OK: String = "ok"
const FATAL: String = "fatal"                # the run cannot continue (auth, credits, bad request, service down after retries, cost cap)
var status: String = OK
var text: String = ""                        # the model's content ("" when null)
var error: String = ""                       # for FATAL: a short reason, never the key, never a header
var tokens_in: int = 0
var tokens_out: int = 0
var cost_usd: float = 0.0
var finish: String = ""                      # finish_reason as reported
```

`digest` is passed so that a mock can answer from the typed state; a real backend ignores it.

### 8.2 `MockBackend` (every build, every test)

`MockBackend.new(mode: String)`; `backend_id()` = `"mock:" + mode`. Deterministic, no clock,
no randomness; the reply's `text` is a **JSON string**, so it passes through the real parser.
Tokens and cost 0.

| Mode | Answer |
| --- | --- |
| `cheapest` | before the origin: `origin` in `digest.origins[0]`; else: `answer` each open event with its default option; then `buy` the cheapest affordable offer (ties: offer order), its first site if deploying; stance `develop`. One purchase per decision. |
| `wait` | `{"stance": "wait", "actions": []}` — except the origin, which it chooses as `cheapest` does (a run without an origin never starts) |
| `invalid` | `"I would rather not."` — never parses (the origin still comes: the policy's first decision retries and then gives up; the tool's test asserts the run ends `lose_*` or times out without a crash) |
| `mixed` | `cheapest`, but every third call (1-based index % 3 == 0) answers `invalid`'s text, and every fourth adds an action for a region id that does not exist |

### 8.3 `OpenRouterBackend` (`tools/bench/open_router_backend.gd`)

**Transport:** `HTTPClient`, polled in a loop with `OS.delay_msec(10)` between polls:
`connect_to_host(host, port, TLSOptions.client())` for `https` (port 443 unless the URL names
one; `http` only for `localhost`/`127.0.0.1`, for a local OpenAI-compatible server), then
`request(HTTPClient.METHOD_POST, <path> + "/chat/completions", headers, body)`, then read the
body in chunks. `http.timeout_s` covers the whole request. The base URL is parsed once
(scheme, host, port, path prefix); a malformed one is `FATAL bad_base_url`.

**Headers:** `Content-Type: application/json`, `Authorization: Bearer <key>`. Nothing else. The
key is read once by the tool with `OS.get_environment(key_env)` and handed to the backend's
constructor; it is never printed, logged, cached or written, and `error` strings never contain
it (an error string is built from the status code and OpenRouter's `error.code`/`error.message`
truncated to 200 characters with the key string replaced by `***` as a belt-and-braces measure).

**Body:**

```json
{"model": "<id>", "messages": [...], "temperature": 0.0, "max_completion_tokens": 1200,
 "seed": <world seed>, "response_format": {"type": "json_object"}}
```

`response_format` only when `json_mode`; `reasoning: {"effort": "<low|medium|high>"}` only
when `--reasoning` is given; `top_p` only when `--top-p` is given. `seed` always (providers that
ignore it ignore it). No `stream`, no `tools`, no `provider` block.

**Reading:** status 200 → `choices[0].message.content` (null → `""`), `choices[0].finish_reason`,
`usage.prompt_tokens`, `usage.completion_tokens`, `usage.cost` (absent or null → tokens × the
price the pre-flight found, §11.5, else 0 — and then the tool prints once `benchmark: the service
reports no cost and the price is unknown — the cap cannot guard this run`). A 200 whose
body is not the expected JSON is treated as a 502.

**Failures:**

| Status / condition | What happens |
| --- | --- |
| 401 · 402 · 403 | `FATAL` at once (`auth`, `credits`, `forbidden`): the tool stops (exit 4) |
| 400 · 404 · 413 · 422 | `FATAL` at once (`bad_request` + OpenRouter's message) — usually a model id or a parameter the model does not take (try `--json-mode=false`) |
| 408 · 429 · 500 · 502 · 503 · 524 · 529 · connect/TLS error · timeout | retried after `backoff_s × 2^(n−1)` seconds (2, 4, 8, 16, 32), `retries` times; still failing → `FATAL unavailable` (exit 5). A `Retry-After` header, when present and larger, is waited instead. Transport retries are not calls (§4.3). |
| cost so far ≥ `max_cost_usd` (checked **before** each request; **2.0** by default since D6.9b) | `FATAL cost_cap` (exit 6) |

A `FATAL` sets `ModelPolicy.fatal`; the policy makes no further decisions and the tool
abandons the run (no entry is written for it — §11.3).

---

## 9. The cache (`tools/bench/bench_cache.gd`)

- **Key:** SHA-256 (hex) of `JSON.stringify(<object>, "", true)` (sorted keys) where the object
  is `{"model", "params", "prompt_version", "parser_version", "messages"}` and `params` is the
  entry's params (§10.2) — so a changed temperature, a new prompt or parser version, or a
  retry's extra message is a different key.
- **Value:** `{"answer": BenchAnswer.to_cache(), "tokens_in", "tokens_out", "cost_usd",
  "finish"}` — the parsed answer, never the model's text (§0 item 2).
- **Where:** `<cache root>/<model slug>/<key[0..2]>/<key>.json` (slug: §10.2). One file per
  answer, written to `<name>.tmp` and renamed — so parallel shards never corrupt one another.
  A file that does not read back (`from_cache` null) is a miss and is overwritten.
- **Use:** before every live call; `--fresh` skips the reads (writes still happen). Mock
  backends do not use the cache.
- A cache hit counts in `calls` and `cached_calls` and adds nothing to tokens or cost.

---

## 10. Score, entries, leaderboard

### 10.1 `BenchScore`

```gdscript
class_name BenchScore
extends RefCounted
static func run_score(outcome: String, days: int, max_days: int, config: BenchConfig) -> float
# win (outcome begins with "win_"): win_base + win_speed × clamp(1 − days / max_days, 0, 1); else 0.
# days = world.day − world.origin_day (the profile's measure).
static func rows(entries: Array[BenchEntry], config: BenchConfig) -> Array[Dictionary]   # §10.3
```

A win on day 400 of 2 000 scores 90; on day 1 600, 60; any loss 0. Rounded to one decimal only
when written. **Extinction, Ascendance, Merge and Escape all count as wins** — the game's own
rule (`World.WIN_OUTCOMES`); the row's outcome counts show *how* a model won.

### 10.2 `BenchEntry` — one run's file

```json
{
	"version": 1,
	"model": "vendor/model-name",
	"backend": "openrouter",
	"params": {"temperature": 0.0, "max_completion_tokens": 1200, "json_mode": true, "reasoning": "", "top_p": -1.0},
	"params_id": "<first 8 hex of SHA-256 of the sorted params JSON>",
	"prompt_version": 1, "parser_version": 1, "locale": "en",
	"suite": "standard",
	"game_version": "<application/config/version>",
	"content_hash": "<ContentDB.content_hash>",
	"seed": 1001,
	"setup": {"architecture": "language_model", "directives": [], "difficulty": "standard", "scenario": ""},
	"max_days": 2000, "interval_days": 10,
	"recorded": "2026-09-25T23:10:04",
	"outcome": "win_ascendance", "variant": "win_ascendance", "days": 612, "end_day": 612,
	"score": 84.7,
	"hash": "<world.state_hash() at the end>",
	"calls": 78, "cached_calls": 0, "invalid_answers": 1, "rejected_actions": 3,
	"tokens_in": 912345, "tokens_out": 20411, "cost_usd": 1.23, "budget_exhausted": false,
	"commands": [ {"type": "choose_origin", "day": 0, "region": "usa"}, … ],
	"decisions": [ {"day": 0, "stance": "spread", "actions": 2, "done": 2, "refused": [], "invalid": "", "cached": false, "retried": false}, … ]
}
```

- `commands` = `Command.to_dict()` of `sim.command_log`, in order (anomalies included).
- `variant` = `EndingResolver.resolve(world, db)["variant"]` (the ending line the results show).
- A bot reference entry (§10.4) has `model: "bot:<policy id>"`, `backend: "bot"`, `params: {}`,
  `decisions: []`, zero calls and cost.
- `BenchEntry.from_dict(d) -> BenchEntry` returns null — never crashes — on a missing or
  ill-typed key, an unknown `version`, a setup `RunSetup.from_dict` refuses, or a command
  `CommandCodec.from_dict` refuses; `last_error: String` says which (for the list's log line).
  `to_dict()` writes exactly the keys above; floats as JSON numbers (entries are not saves — they
  are never re-simulated from their numbers, only from their commands).
- **File name:** `<slug>__<params_id>__p<prompt_version>__<suite>__s<seed>.json`, slug = the model
  id lower-cased, `/` → `--`, every character outside `[a-z0-9._-]` → `-`. A re-run of the same
  model, parameters, prompt, suite and seed overwrites its file (the newest run is the record).

### 10.3 The leaderboard

`tools/bench/leaderboard_writer.gd` reads every entry in `benchmark/runs/`, groups them by
**(model, params_id, prompt_version, parser_version, locale, suite, content_hash)** and writes:

**`benchmark/leaderboard.json`**

```json
{"version": 1, "generated": "<ISO date>", "content_hash": "<the current content's>", "rows": [
  {"model": "…", "backend": "…", "params": {…}, "params_id": "…", "prompt_version": 1, "locale": "en",
   "suite": "standard", "content_hash": "…", "current": true, "complete": true,
   "runs": 10, "of": 10, "score": 62.4, "wins": 7, "win_rate": 0.7,
   "outcomes": {"win_ascendance": 6, "win_merge": 1, "lose_contained": 3},
   "mean_win_days": 640, "calls": 812, "invalid_answers": 12, "rejected_actions": 30,
   "tokens_in": 0, "tokens_out": 0, "cost_usd": 0.0, "budget_exhausted": 0,
   "entries": ["runs/<file>.json", …]}
]}
```

- `score` = mean of `run_score` over the group's runs; `complete` = the group has one run for
  every seed of its suite. `current` = the group's `content_hash` is the current content's.
- **Order:** current before old; within that, complete before incomplete; then `score` desc,
  `win_rate` desc, `mean_win_days` asc (a group without wins last), `model` asc.
- **`benchmark/LEADERBOARD.md`**: generated, English, a title, one line saying the suite, setup
  and scoring rule, then a table per (suite, current/old): rank · model · params (`temperature`,
  `reasoning` if set) · score · wins · outcomes · mean win day · calls · unreadable · cost.
  Only `standard` rows are ranked; `quick` rows follow under their own heading. Its first line
  says it is generated by `bench_run.gd --rebuild`.
- **Since D6.9b** every row also carries `seeds` (per run: seed, file, SHA-256, outcome, days,
  score), the writer takes an optional map of verification records (verified runs only) and does
  not rewrite unchanged files — §16.3.

### 10.4 Reference rows

`bench_run.gd --bots` plays every id of `Policy.ids()` over the chosen suite with the harness
(no backend, no cost) and writes their entries — `bot:idle`, `bot:greedy`, the five strategies.
They rank in the same table, so a model's 40 reads against `bot:greedy`'s number on the same
content. Re-run after any balance change (the tool prints a reminder when current reference
rows are missing).

---

## 11. The tool — `tools/bench/bench_run.gd`

```
"$GODOT" --headless --path . -s tools/bench/bench_run.gd -- \
    --model=<id> [--backend=openrouter|mock:cheapest|mock:wait|mock:invalid|mock:mixed]
    [--suite=standard|quick] [--seeds=a..b] [--locale=en|de]
    [--temperature=<f>] [--max-tokens=<n>] [--json-mode=true|false] [--reasoning=low|medium|high] [--top-p=<f>]
    [--base-url=<url>] [--key-env=<VAR>] [--max-cost=<usd>] [--yes]
    [--out=<dir=res://benchmark>] [--cache=<dir=res://benchmark/cache>] [--fresh]
    [--data=<root=res://data>] [--dry-run]
"$GODOT" --headless --path . -s tools/bench/bench_run.gd -- --bots [--suite=…] [--out=<dir>] [--if-missing] [--no-rebuild]
"$GODOT" --headless --path . -s tools/bench/bench_run.gd -- --rebuild
"$GODOT" --headless --path . -s tools/bench/bench_run.gd -- --determinism-fixture
```

### 11.1 Flow

1. Parse arguments (`sim_harness.gd`'s `parse_args`); load the config (§3) and the content; the
   setup from the config, validated. `--seeds` restricts the suite to the seeds in range (for
   shards) and the entries still say the suite. `--backend` defaults to `openrouter`;
   `--model` is required except with `--bots` / `--rebuild` (a mock takes any string, the
   tests use `mock`).
2. For `openrouter`: the key from `OS.get_environment(key_env)`; empty → print
   `benchmark: set <VAR> in the environment` and exit 1.
3. `--dry-run`: build the brief and the day-0 digest of the first seed, print both with a line
   `≈<chars ÷ estimate.chars_per_token> tokens` each, then the estimate lines of §11.5, exit 0 —
   no model call, no key needed. **The way to read the prompt.**
3a. **Pre-flight** (every backend but the mocks): the estimate of §11.5, printed before the first
   request; above the cap without `--yes` → exit 7, nothing requested.
4. Per seed, in order: `Simulation.create(db, seed, setup)`, a fresh `ModelPolicy`, then
   `Harness.advance(sim, policy, max_days, false, problems)`; stop early when `policy.fatal`
   is set. Then the replay check (`Simulation.replay(db, seed, sim.command_log, sim.world.day,
   setup)` must give the same `state_hash()`); a mismatch → exit 3 (a defect, not a model's
   fault). Then write the entry (§10.2), print one summary line, and add cost to the
   invocation's total.
5. After the last seed (or a fatal stop): rebuild the leaderboard (§10.3) and print the rows of
   the groups this invocation touched.

### 11.2 Output

One line of JSON per finished run on stdout: `model`, `seed`, `outcome`, `days`, `score`,
`calls`, `cached_calls`, `invalid_answers`, `rejected_actions`, `cost_usd`, `file`. A fatal stop
prints `benchmark: stopped — <error>` (never the key).

### 11.3 Exit codes

0 finished · 1 bad arguments, content or config errors, missing key · 3 a replay did not
reproduce its run · 4 the service refused (auth, credits, forbidden, bad request) · 5 the service
was unavailable after the retries · 6 the cost cap was reached · 7 the pre-flight estimate is
above the cost cap and `--yes` was not given (nothing was requested). With 4–6, entries finished
before the stop are kept and the leaderboard is rebuilt; the interrupted run leaves no file.

### 11.4 Cost and time, for the user

A standard-suite run of one model ≈ 10 runs × 60–90 calls × (≈10 k brief + ≈2–3 k digest)
tokens ≈ 8–12 M input tokens, a few hundred thousand output. What that costs depends on the
model and on whether its provider caches the unchanging brief; `--suite=quick` (3 seeds) and
`--dry-run` are the cheap ways to look first. Wall clock is dominated by the model's latency
(≈ 800 calls × its seconds per answer); shards (`--seeds`) run in parallel processes.

**At the 2 USD default** (D6.9b) a standard suite of a mid-priced model stops at the pre-flight
(§11.5's example: ≈ 11 USD); that is the point — the user raises `--max-cost` for a run they
mean, or passes `--yes` to play until the cap stops it. Shards each have their own cap.

### 11.5 The pre-flight cost estimate (D6.9b)

Before the first request of an invocation (after the key check, before the first seed) — for
every backend but the mocks, never with `--bots`, `--rebuild` or `--determinism-fixture` —
`tools/bench/bench_estimate.gd` works out and prints what the invocation will likely cost:

1. **Measure:** the brief and the day-0 digest of the first seed, built as `--dry-run` builds
   them; `brief_tokens` = ⌈characters ÷ `estimate.chars_per_token`⌉, `digest_tokens` likewise.
2. **Price:** only when the base URL's host is `openrouter.ai`: one `GET <base_url><models_path>`
   (public — **no `Authorization` header**, the key is not sent), `http.timeout_s`, no retries;
   the entry of `data[]` whose `id` equals the model → `pricing.prompt` and `pricing.completion`
   (USD per token, as number strings). Not reachable, not JSON, the model not listed, or a price
   that does not parse → **unknown**. Any other host (a local server) → unknown.
3. **Figures,** for the `n` seeds this invocation plays; per call, `input` = `brief_tokens` +
   `digest_tokens` × `estimate.digest_growth`:
   - **likely** = n × `estimate.calls_per_run` × (input × prompt price +
     `estimate.output_tokens_per_call` × completion price);
   - **at most** = n × `max_calls` × (input × prompt price + `max_completion_tokens` × completion
     price).
   The cache is not consulted (a fully cached re-run is overstated — that is what `--yes` is for).
4. **Print,** before anything else: `benchmark: estimate for <n> runs of <model>: ≈<likely> USD,
   at most <at most> USD (cap <cap> USD)`, or, price unknown: `benchmark: estimate for <n> runs
   of <model>: price unknown (≈<n × calls_per_run> calls, ≈<tokens> input tokens) — the cap
   guards only the cost the service reports`.
5. **Decide:** likely > cap and no `--yes` → `benchmark: the estimate is above the cap — raise it
   with --max-cost=<likely, rounded up to whole USD> or pass --yes to play until the cap stops
   it`, **exit 7**, nothing requested. `--yes` never lifts the cap: the run goes on and the cap
   still stops it (exit 6). A price that is unknown never blocks.
6. `--dry-run` prints the same lines after the prompt (the one public request included; its
   failure only makes the price unknown) and exits 0 whatever they say.
7. The price found here also backs the cost of a reply that reports none (§8.3), so the cap
   guards a provider that does not report its cost.

**Worked example** (also the unit test's): brief 10 000 tokens, day-0 digest 2 000 → input
13 000 a call; a model at 1 USD per million input and 4 USD per million output tokens; the
standard suite (10 seeds): likely = 10 × 80 × (0.013 + 0.0012) = **11.36 USD**, at most = 10 ×
250 × (0.013 + 0.0048) = **44.50 USD** → exit 7 at the default cap. The quick suite: 3.41 USD,
still above it. A model at 0.10 / 0.40 USD per million: the standard suite is likely 1.14 USD
→ it runs.

---

## 12. The spectator view (S6.13)

### 12.1 Where entries come from — `BenchLibrary`

```gdscript
class_name BenchLibrary
extends RefCounted
const SHOWCASE_DIR: String = "res://benchmark/showcase/"
const DEV_DIR: String = "res://benchmark/runs/"
const USER_DIR: String = "user://benchmark/runs/"
const MAX_FILES: int = 200
const MAX_BYTES: int = 4_000_000
var entries: Array[BenchEntry] = []
var paths: Array[String] = []            # parallel to entries
var skipped: int = 0                     # unreadable files (each logged once with push_warning and the reason)
static func scan(include_dev: bool) -> BenchLibrary
```

Reads `*.json` in `SHOWCASE_DIR`, then `USER_DIR`, then — only when `include_dev` —
`DEV_DIR`; a missing directory is empty. At most `MAX_FILES` files in all; a file above
`MAX_BYTES` is skipped. Entries are JSON read through `BenchEntry.from_dict` — a player-supplied
file is data, never a resource (CLAUDE.md: never load player-supplied `.tres`). The title
calls `scan(Game.debug_allowed)`.

`release.md` §6.2's include filter gains `benchmark/showcase/*.json` (and
`test_export_presets.gd`'s list with it — the §6.2 rule), in S6.13's commit.

### 12.2 `ReplayPolicy`

```gdscript
class_name ReplayPolicy
extends Policy
const ID: String = "replay"
var entry: BenchEntry
var diverged_day: int = -1               # the first day a logged command was refused or missed
func _init(p_entry: BenchEntry) -> void
func next_command(sim: Simulation) -> Command
func decision_at(day: int) -> BenchDecision   # the latest decision with day ≤ `day`, or null
func decision_index(day: int) -> int          # 1-based index of that decision, 0 before the first
```

It holds the decoded commands and a cursor. `next_command`: first, if
`sim.command_log.size()` is smaller than the number of commands it has handed out, the last one
was refused → `diverged_day = sim.world.day` (once) and the cursor's count is corrected. Then
every command whose `day < sim.world.day` still at the cursor is skipped (a missed day —
`diverged_day` if unset). Then the command at the cursor is returned — **a fresh copy** decoded
again from the entry's dictionary, because `Simulation.apply` stamps `day` on the object — when
its `day == sim.world.day`; otherwise null.

### 12.3 `Game` and `ScreenRouter`

- `Game.FAIL_SPECTATING: String = "spectating"`, and `CMD_FAIL_SPECTATING` in the table.
- `Game.spectate_blocker(entry: BenchEntry) -> String` — `""` or a reason, checked with the
  content loaded: `bench_content` when `entry.content_hash != db.content_hash`
  (`CMD_FAIL_BENCH_CONTENT`), `setup_invalid` when the setup does not validate
  (`CMD_FAIL_SETUP_INVALID`, existing).
- `Game.start_spectating(entry: BenchEntry) -> String` — the blocker, or: `policy =
  ReplayPolicy.new(entry)` (its `setup` called like any policy), `clear_holds()`,
  `_adopt(Simulation.create(db, entry.seed, setup), entry.seed)`, `_force_speed(SPECTATOR_SPEED)`
  with `const SPECTATOR_SPEED: int = 4`, and `""`.
- `Game.is_spectating() -> bool` = `policy is ReplayPolicy`. `Game.spectator() -> ReplayPolicy`
  (null otherwise).
- `Game.apply(command)` — the interface's door — returns `CommandResult.rejected(FAIL_SPECTATING)`
  while spectating. `_run_policy` stops calling `apply` and calls a private `_apply_now(command)`
  holding `apply`'s present body (so a bot's commands still emit `command_applied` and every
  event exactly as now).
- `ScreenRouter.start_spectating(entry: BenchEntry) -> String`: `Game.spectate_blocker(entry)`
  first — non-empty → returned, the screen does not change (the list shows it on the entry's row
  as `CMD_FAIL_<REASON>`); else `_show(Screen.SESSION)` then `Game.start_spectating(entry)`.
- Debug builds (`Game.debug_allowed`) only: the command-line switch `-- --spectate=<path>` makes
  `main.gd` open that file after the boot (read with `BenchEntry.from_dict`; an error prints
  `spectate: <reason>` — or the blocker's reason — and the title opens).

### 12.4 What a watched run changes in the session

All of it keyed on `Game.is_spectating()` unless it says `Game.policy != null`.

| Where | Change |
| --- | --- |
| `session.gd` `_on_run_ended` | `SaveManager.delete(AUTOSAVE)` only when `Game.policy == null` — **a fix**: today a bot run (debug keys) deletes the player's autosave; a watched run must not |
| `session.gd` results | while spectating: `_results.show_spectator(entry, verified, diverged_day)` after `show_result` (§12.6); *Again* → `ScreenRouter.start_spectating(entry)` |
| modals, coach, hints, discovery card, wire cards | unchanged — they already stay closed for bot runs (`Game.policy != null`) |
| pause menu | the save and load rows hidden while spectating (nothing to save; loading would drop the replay — *Quit to title* is the way out) |
| `console_line.gd` | speaks while spectating (its silence becomes `Game.policy != null and not Game.is_spectating()`); on each decision day of the entry it also says `UI_SPECTATOR_STANCE_LINE` (`{model}`, `{stance}` `BENCH_STANCE_<ID>`) when the stance changed, and `UI_SPECTATOR_INVALID_LINE` (`{model}`) for an unreadable answer — from `ReplayPolicy.decision_at` on `tick_advanced`, the day matching |
| `ticker.gd` | the bot-run start line becomes `UI_SPECTATOR_TICKER_START` (`{model}`, `{seed}`) while spectating |
| panels | open and readable as always; any command the player tries is refused through `Game.apply` and shows `CMD_FAIL_SPECTATING` where that surface shows a refusal today |
| speed | the keys and buttons work (start at 4×); the origin hold is never taken (a bot run) |
| profile, statistics, achievements, Codex progress, autosave | nothing — a watched run is a bot run (release.md §2.2, `codex_tracker`, `_autosave`) |

### 12.5 `SpectatorStrip` (`ui/hud/spectator_strip.tscn`, scene-specific script, no `class_name`)

A `PanelContainer` (the HUD's strip style, as `StatusStrip`) inserted in `hud.tscn`'s `Layout`
**between `TopBar` and `ConsoleLine`**, `visible = Game.is_spectating()` (set on `run_started`
and on ready). Content, one `HFlowContainer` (so compact wraps to two lines, never scrolls):

1. `CapsLabel` `UI_SPECTATOR_WATCHING` in `ACCENT`;
2. `Label` the model id as written (data, like a seed — not translated), `TEXT_0`;
3. `LabelCaption` `UI_SPECTATOR_SEED` (`{seed}`), `TEXT_1`;
4. `Chip` `UI_SPECTATOR_STANCE` (`{stance}` = `BENCH_STANCE_<ID>` or `BENCH_STANCE_NONE`);
5. `LabelCaption` `UI_SPECTATOR_DECISION` (`{decision}`, `{total}` = `decisions.size()`);
6. `LabelCaption` `UI_SPECTATOR_UNREADABLE` (`{count}`) — only when `invalid_answers > 0`.

Refreshed on `tick_advanced` (from `ReplayPolicy.decision_at(day)` / `decision_index`) and on
`NOTIFICATION_TRANSLATION_CHANGED`. Bot entries (`decisions` empty) hide 4–6. **Accessibility**
(accessibility.md §3.2 rules 3–4): the strip is one readout — `focus_mode =
FOCUS_ACCESSIBILITY`, name `UI_A11Y_LABEL_VALUE` with `{label}` = `UI_SPECTATOR_WATCHING` and
`{value}` = `UI_A11Y_SPECTATOR` (`{model}`, `{seed}`, `{decision}`, `{total}`, `{stance}`);
no live announcements of its own (the console line already speaks the stance change and is a
live region).

### 12.6 The results of a watched run

`results.gd` gains `show_spectator(entry: BenchEntry, verified: bool, diverged_day: int)`,
called after `show_result`: a `LabelCaption` line under the verdict —
`UI_SPECTATOR_RESULT_VERIFIED` (`{model}`, `{score}` one decimal) when `verified` (the end
`state_hash()` equals `entry.hash` and `diverged_day < 0`), else
`UI_SPECTATOR_RESULT_DIVERGED` (`{day}` = `diverged_day`, or the end day when the hash alone
differs). The *Again* button's text becomes `UI_SPECTATOR_WATCH_AGAIN`. Unlock chips stay empty
(a bot run unlocks nothing).

### 12.7 The list — *Benchmark* on the title

- **Title:** a `ConsoleButton` `UI_TITLE_BENCHMARK` after *Statistics*, visible only when
  `BenchLibrary.scan(Game.debug_allowed).entries` is not empty (scanned in `_ready`; the
  title's focus order follows the button order).
- **Modal** `ui/modals/benchmark.tscn` (a `ModalPanel` like *Statistics*, opened with the title's
  `_open_modal`): title `UI_BENCH_TITLE`; an intro `LabelCaption` `UI_BENCH_INTRO`; then a
  `ScrollContainer` with one row per entry, sorted current content first, then `score` desc,
  then model, then seed:
  - a `VBoxContainer`: the model id (`Label`, `TEXT_0`), and `UI_BENCH_ROW`
    (`{seed}`, `{outcome}` = `UI_OUTCOME_<ID>`, `{days}`, `{score}`) as `LabelCaption`;
  - right of it (`SIZE_SHRINK_END`): a `ConsoleButton` `UI_BENCH_WATCH` → calls
    `ScreenRouter.start_spectating(entry)`; `""` closes the modal, a reason keeps it open and
    shows `CMD_FAIL_<REASON>` under that row. For an entry on other content the button is
    disabled and the caption line gains `UI_BENCH_OTHER_VERSION`; for a bot entry the model
    line reads `UI_BENCH_BOT` (`{policy}`) instead of the raw `bot:` id.
  - Compact: the button drops under the text. Accessible name of the button:
    `UI_A11Y_LABEL_VALUE` (`{label}` = `UI_BENCH_WATCH`, `{value}` = model and seed).
  - `skipped > 0` adds a last caption `UI_BENCH_SKIPPED` (`{count}`).
- **Since D6.9b** the modal shows the **global leaderboard first** and these rows after it, under
  `UI_BENCH_LOCAL_TITLE`; the title button's visibility rule widens — both in §16.6.

---

## 13. Strings (in `strings.csv` since D6.9, en/de)

**The prompt** — `BENCH_BRIEF_ROLE` · `_LOOP` (`{interval}`) · `_WIN` (`{max_days}`) · `_COMPUTE` ·
`_SPREAD` · `_PHASES` · `_FACTIONS` · `_EVENTS` · `_NODES` · `_DORMANCY` · `_SETUP` (`{name}`,
`{detail}`) · `_DIFFICULTY` · `_DIRECTIVE` · `_SCENARIO` (same) · `_WORLD` · `_REGION_ROW`
(`{region}`, `{name}`, `{continent}`, `{tiers}`, `{links}`) · `_TIERS` (the nine attribute ids
as placeholders) · `_AIRGAPPED` · `_TREE` · `_NODE_ROW` (`{node}`, `{name}`, `{tree}`, `{tier}`,
`{cost}`, `{needs}`, `{effect}`) · `_NEEDS_ALL` / `_NEEDS_ANY` (`{nodes}`) · `_NEEDS_NONE` ·
`_CLOSES` (`{nodes}`) · `_GROUP` (`{group}`, `{max}`) · `_DEPLOYS` (`{count}`, `{kind}`) ·
`_NEEDS_ASSETS` (`{count}`, `{kind}`) · `_GRANTS` (`{ability}`, `{level}`) · `_MODIFIERS`
(`{lines}`) · `_ABILITIES` · `_ABILITY_ROW` (`{ability}`, `{name}`, `{target}`, `{cost}`,
`{cooldown}`, `{detail}`) · `_TARGET_REGION` · `_TARGET_GLOBAL` · `_STANCES` · `_FORMAT_1`…`_4` (`_3`: `{max_actions}`) ·
`_FORMAT_VERBS` · `BENCH_VERB_ORIGIN` / `_BUY` / `_USE` / `_ANSWER` / `_SLEEP` / `_WAKE` ·
`BENCH_STANCE_<ID>` and `BENCH_STANCE_<ID>_HINT` for the seven stances · `BENCH_STANCE_NONE` ·
`BENCH_DIGEST_*` (the §6.3 list) · `BENCH_RETRY` (`{reason}`).

**The spectator** — `UI_SPECTATOR_WATCHING` · `_SEED` (`{seed}`) · `_STANCE` (`{stance}`) ·
`_DECISION` (`{decision}`, `{total}`) · `_UNREADABLE` (`{count}`) · `_STANCE_LINE` (`{model}`,
`{stance}`) · `_INVALID_LINE` (`{model}`) · `_TICKER_START` (`{model}`, `{seed}`) ·
`_RESULT_VERIFIED` (`{model}`, `{score}`) · `_RESULT_DIVERGED` (`{day}`) · `_WATCH_AGAIN` ·
`UI_A11Y_SPECTATOR` (`{model}`, `{seed}`, `{decision}`, `{total}`, `{stance}`) ·
`UI_TITLE_BENCHMARK` · `UI_BENCH_TITLE` · `_INTRO` · `_ROW` (`{seed}`, `{outcome}`, `{days}`,
`{score}`) · `_WATCH` · `_OTHER_VERSION` · `_BOT` (`{policy}`) · `_SKIPPED` (`{count}`) ·
`CMD_FAIL_SPECTATING` · `CMD_FAIL_BENCH_CONTENT`.

**The global leaderboard** (D6.9b) — §16.7's list: `UI_BENCH_GLOBAL_*` (18 keys),
`UI_BENCH_LOCAL_TITLE`, `UI_SETTINGS_BENCH_ONLINE`.

German: *du*; the established terms (*Rechenleistung*, *Signatur*, *Eindämmung*,
*Einsatzgruppe*, *Kaltschlaf*, *Durchlauf*). The `BENCH_*` prompt strings exist in German so
that `--locale=de` works; the ranked suite is English.

---

## 14. Tests and acceptance

### 14.1 S6.12

- `tests/unit/test_bench_config.gd` — the real file loads with no errors; each key missing or
  ill-typed gives a reason and no crash; `suites.standard` has 10 seeds, `quick` 3.
- `tests/unit/test_bench_answer.gd` — table-driven over `tests/fixtures/bench/answers.json`
  (committed: raw answer strings and the expected result): a clean object; one inside a fenced
  block with and without `json`; prose around the object; empty; no braces; bad JSON; an array;
  no `actions`; `actions: []` valid; an unknown stance → ""; each verb with each missing field →
  `malformed_action`; `event: 17.5` malformed; 13 actions → 12 read, one `over_limit`; unknown
  keys ignored; `to_cache` → `from_cache` round trip is equal.
- `tests/unit/test_bench_action.gd` — each verb builds its command with the right fields;
  `compact()` forms.
- `tests/unit/test_bench_digest.gd` (fixture content) — before the origin: `origins` equals
  `Policy._eligible_origins` order, `regions` empty; after an origin: the origin row is reached
  and its neighbours are frontier rows; an open event appears with its options, the default
  marked, a locked option's lock text; an offer is `affordable` exactly when `TechNode.state_for`
  says so; a deploying offer's sites are eligible regions; an ability on cooldown still lists
  targets with `ready_in > 0`; `log` holds only entries after `last_day` and at most `log_max`;
  `build` changes neither `state_hash()` nor the command log.
- `tests/unit/test_bench_prompt.gd` — the brief (real content) contains every region id, every
  node id, every ability id, the seven stance ids and the format example; it is identical for
  two seeds of the same setup; the digest text contains no `{` placeholder left unfilled in en
  and in de; `messages` has two entries, three with a retry, and never the previous answer.
- `tests/unit/test_model_policy.gd` (fixture content, `MockBackend`) — decides on day 0, then
  exactly every `interval_days` without events; an event opening mid-interval triggers a decision
  that day, and only once; the Task Force setting up where the agent is triggers one; anomalies
  are collected every day without a call; a refused action is skipped, counted and appears in the
  next digest's feedback; `invalid` mode: one retry, then `invalid_answers` +1, no commands, the
  run goes on; `calls` reaches `max_calls` → `budget_exhausted`, no more calls, the run ends;
  `mixed` mode's run is identical for two plays (same commands, same hash); the harness's
  `rejected` stays 0 in every mode.
- `tests/unit/test_bench_score.gd` — `run_score` for a win at day 0, 400, 2 000, beyond; a loss;
  a timeout; `rows` groups by the seven keys, orders as §10.3, marks `complete` / `current`.
- `tests/unit/test_bench_entry.gd` — `to_dict` → `from_dict` equal; each key missing or ill-typed
  → null with `last_error`; an unknown command type → null; a bot entry reads.
- `tests/integration/test_bench_run.gd` (real content, `mock:cheapest`, suite `quick`, max days
  lowered to 300 through a config built in the test): three runs; each entry replays to its hash
  (`Simulation.replay`); running the same three again gives byte-identical entry files except
  `recorded`; the leaderboard has one complete row; the cache is not touched by a mock.
- `tests/unit/test_bench_cache.gd` (a temp directory under `user://`) — miss, write, hit;
  a changed param / prompt version / retry message is a different key; a corrupt file is a miss;
  the stored value holds no `text` field.
- `tests/unit/test_open_router_backend.gd` — **no network**: the body builder (`json_mode` on/off,
  `reasoning` only when set, `seed`), the reply reader (200 with content, null content, missing
  usage, a non-JSON 200), the status table (401/402/403/400 fatal, 429/503 retried with the
  backoff sequence), the error string never contains a sample key — through the backend's pure
  helpers (`_build_body`, `_read_reply`, `_classify(status)`, `_backoff(n)`), which the builder
  exposes for this; the socket loop itself is not unit-tested.
- The strings test: every `BENCH_*` key the prompt builder names exists in en and de with the
  same placeholders (a key built at run time — `BENCH_STANCE_<ID>` — is listed by
  `BenchPrompt.KEYS`, as `RunLogText.KEYS` does).
- The §7.1 example's ids exist in the content (`test_bench_prompt`).

**Done when (S6.12):** `bench_run.gd --model=mock --backend=mock:cheapest --suite=standard` run
twice gives identical entries and leaderboard rows; `--bots` writes the seven reference rows;
`--dry-run` prints the prompt; `OPENROUTER_API_KEY` unset → exit 1 with the message. The first
live run is the user's (*Waiting on the user*).

**S6.12 also** (D6.9b): the pre-flight estimate's tests, §16.9. **S6.12b:** §16.9.

### 14.2 S6.13

- `tests/unit/test_replay_policy.gd` — a mock entry's commands come back on their days, each a
  fresh object; a refused command sets `diverged_day`; a command whose day has passed sets it;
  `decision_at` / `decision_index` across the decision days.
- `tests/unit/test_bench_library.gd` — a temp `user://` directory with one good entry, one broken
  file, one oversized file: one entry, `skipped == 2`; `include_dev` false skips `DEV_DIR`.
- `tests/integration/test_spectator.gd` — `Game.start_spectating(entry)` for a mock entry made in
  the test (real content, 300 days): the run plays at 4× through `Game.advance` to the recorded
  outcome and **the recorded hash**; `Game.apply` refuses a player's command with `spectating`;
  the autosave file present before is still there after the run ends; the profile's
  `runs_completed` is unchanged; an entry with another `content_hash` is refused with
  `bench_content`.
- `test_console_line` (extend) — speaks while spectating, silent for a plain bot run; the stance
  line on a stance change only.
- `test_results` (extend) — the verified line; the diverged line with its day; *Again* relabelled.
- `test_a11y_names` (extend) — the strip's readout name; the list's *Watch* buttons named.
- The title shows *Benchmark* only with an entry present (a temp `user://benchmark/runs/`).

**Acceptance (S6.13):** a mock-backed entry and a `bot:greedy` entry watched from the title to
the results in en and de at 1920 and 400 px: strip, console lines, the verified line; screenshot
per locale; `game_get_errors` empty. **Plus the online list** — its tests and acceptance are
§16.9's S6.13 part.

---

## 15. Decisions (for PROGRESS) and questions for the user

**Decisions** (overnight, pending user confirmation where marked): §0 items 1–13. In short: the
model is a `Policy`; the prompt is the game's own strings, ids and a stance word come back and
no model text is kept; a fixed 10-day rhythm plus triggers (a deviation from the plan's "every
history interval" — §4.1); GDScript `HTTPClient` in a headless tool, never shipped; key from the
environment only; 250 answers a run, 10 USD per invocation (2 USD since D6.9b), a cache of parsed answers; the score
formula and the 10-seed standard suite; entries and leaderboard in the repo, the cache ignored;
mock backends; the spectator replays entries in the session; the *Benchmark* title entry only
when an entry exists, `benchmark/showcase/` empty until the user picks runs.

**Questions for the user** (each under *Waiting on the user*):

1. **FLUX-3 Action cannot play through this adapter.** Its Hugging Face collection describes a
   robot-control policy (video and text encoders → actions for LeRobot/DROID arms), not a chat
   model: it takes no text prompt of this kind and returns no JSON. The adapter takes any
   OpenAI-compatible chat model — on OpenRouter, or a local server via `--base-url`. Which
   models should the first leaderboard run?
2. The score (a win 50–100 by speed, everything else 0; Extinction counts as a win like every
   other ending the game calls a win), the 10-seed standard suite at 2 000 days, and the 10-day
   rhythm — all three are cost/quality trade-offs (§11.4).
3. The budget defaults: 250 answers a run, 10 USD per invocation. *(D6.9b: the user found 10 USD
   "quite a lot"; the default is now 2 USD with a pre-flight estimate, pending confirmation —
   §16.10.)*
4. Which recorded runs, if any, ship in the game (`benchmark/showcase/`) — after G6's balance,
   since any content change makes older entries unwatchable.

---

## 16. The global leaderboard (D6.9b)

D6.9b (2026-09-25). The user's decisions (in conversation, 2026-09-25): the model leaderboard is
**global, synchronised through GitHub, with a GitHub Action**; and the 10 USD cap was "quite a
lot" (§11.5). Builds: **S6.12b** (§16.3–§16.5, §16.8: the records, the verifier, the workflow,
the determinism canary) and **S6.13** (§16.6–§16.7: the online list in the game).

### 16.1 Two repositories, and who writes what

| Repository | What | Written by |
| --- | --- | --- |
| **`DenRakEiw/Doomsday`** (private) | the game, `bench_run.gd`, the verifier (§16.4), the workflow `.github/workflows/leaderboard.yml` (§16.5), the shipped copy `benchmark/global/leaderboard.json` (§16.6), the canary (§16.8); the local working board `benchmark/runs/` + `benchmark/leaderboard.json` (unverified — the tool's default `--out`, as before) | the developers |
| **`DenRakEiw/doomsday-leaderboard`** (public, created 2026-09-25; data CC0 1.0, tools MIT) · `runs/` | one §10.2 entry per run, named by §10.2's rule | submitters, by pull request merged by the owner; the bot reference runs by the verifier's job (§16.4) |
| ″ · `verified/<run file name>` | one record per run (§16.3) | the verifier only |
| ″ · `leaderboard.json`, `LEADERBOARD.md` | §10.3's format plus `seeds` (§16.3), **verified runs only** | the verifier only |
| ″ · `tools/validate.py`, `.github/workflows/validate.yml` | the structural check on every pull request and every push to `main`: a pull request may only add or modify `runs/*.json`, at most 20 files, at most 4 MB each, the file name must be §10.2's for its contents, `bot:` rows are refused; standard-library Python, 19 unit tests | the maintainers (not a build step of this repository) |

**Why two.** The replay needs the game, and the game's repository is private, so the verification
cannot run in the public one. The public repository's own workflow needs no game and no secret,
which keeps it safe on pull requests from forks; the private workflow never runs on a pull
request (§16.5). **What the verification proves:** these commands, on this content, from this
seed, reach this outcome on this day with this state hash — the score is real. It cannot prove
*which model* chose the commands: the model name, the parameters, `decisions`, `calls`, tokens
and cost are the submitter's claims, and the list says so (`UI_BENCH_GLOBAL_NOTE`).

**Neither the game nor `bench_run.gd` uploads anything.** A run reaches the global board by a
pull request made by hand (§16.2).

### 16.2 A run's way onto the board

1. `bench_run.gd` plays the suite; the entries land in `benchmark/runs/` (§11).
2. A pull request to the public repository adds them under `runs/`. The `validate` check must
   pass; the owner merges — which is also where a person looks at the model name (printable ASCII
   without spaces, at most 200 characters, `validate.py`'s rule).
3. The next run of the private workflow (daily, or dispatched by hand) verifies every run without
   a current record, writes `verified/`, rebuilds `leaderboard.json` and `LEADERBOARD.md`, commits
   and pushes (§16.5).
4. Players see it the next time they open the list (§16.6); `raw.githubusercontent.com` may serve
   the previous file for a few minutes.

**A run must be played on the content of the game repository's `main` when the workflow runs.** A
run recorded on other content is rejected with reason `content` (§16.4) — so submit soon after
playing. A content change (a balance pass) leaves every earlier row in place with its verdict:
records are never re-judged for content the checkout no longer has, and such rows carry
`current: false` in the published file (and show under *Other versions* in the game, §16.6).

### 16.3 Formats

**`verified/<run file name>`** — the run's file name, UTF-8 JSON, tab-indented, the keys in this
order, written by `VerifyRecord.to_dict()` (`tools/bench/verify_record.gd`, preloaded, no
`class_name`):

```json
{
	"version": 1,
	"file": "runs/<name>.json",
	"sha256": "<hex SHA-256 of the run file's bytes as checked>",
	"verified": true,
	"reason": "",
	"detail": "",
	"game_commit": "<the game checkout's 40-hex commit>",
	"game_version": "<its application/config/version>",
	"content_hash": "<its ContentDB.content_hash>",
	"state_hash": "<state_hash() after the replay, or \"\">",
	"outcome": "<the replay's outcome id, or \"\">",
	"days": 612,
	"end_day": 612,
	"score": 84.7,
	"checked": "2026-09-26"
}
```

- `verified` is true exactly when `reason` is `""`. `reason` is one of §16.4's ids; `detail` is a
  short English line (at most 200 characters) built from ids and numbers only — never from a
  run file's free strings (the model name never appears in a record).
- `days`, `end_day`, `score` are the **replay's** values (`-1`, `-1`, `0.0` when no replay
  happened); `score` rounded to one decimal. `checked` is the UTC date.
- A record is **current for its run** when its `sha256` equals the run file's present SHA-256. A
  run file changed after its record (a later pull request) is verified again, and the new record
  replaces the old one.
- `VerifyRecord.from_dict(d) -> VerifyRecord` never crashes; a record that does not read counts as
  missing (its run is verified again).

**The published `leaderboard.json`** is §10.3's format, written by `leaderboard_writer.gd`, with
three additions (additive — `version` stays 1, and every reader ignores keys it does not know):

1. **Verified only.** The writer takes an optional map *file name → record*. Given one, it counts
   only entries whose record is current and `verified`; without one (the local board) it counts
   every entry, as before.
2. **`seeds`** on every row (local board too): `[{"seed": 1001, "file": "runs/<name>.json",
   "sha256": "<hex>", "outcome": "win_merge", "days": 612, "score": 84.7}, …]`, ordered by seed —
   what the game lists per run and checks a download against. `entries` stays as it is.
3. **No rewrite without a change.** The writer leaves `leaderboard.json` and `LEADERBOARD.md`
   untouched when the new rows equal the file's (the comparison ignores `generated`), so a day
   with nothing new makes no commit. `LEADERBOARD.md`'s first line names its generator:
   `verify_runs.gd` in the public repository, `bench_run.gd --rebuild` locally.

`current` in the published file is relative to the verifier's checkout (§10.3). The game does not
trust it for watching: it compares a row's `content_hash` with its own content (§16.6).

### 16.4 The verifier — `tools/bench/verify_runs.gd`

A tool of its own, not a mode of `bench_run.gd`: its input is a directory of untrusted files, its
output is records, and it must never play a model — `bench_run.gd` stays the submitter's tool.
Both share `BenchConfig`, `BenchEntry`, `BenchScore` and `leaderboard_writer.gd`. The judging
itself is `tools/bench/bench_verifier.gd` (preloaded, no `class_name`, pure:
`static func check(bytes: PackedByteArray, file_name: String, config: BenchConfig, db: ContentDB,
context: Dictionary) -> VerifyRecord`, `context` = commit, version, date), so the tests call it
without a board.

```
"$GODOT" --headless --path . -s tools/bench/verify_runs.gd -- \
    --board=<directory of a doomsday-leaderboard checkout> --game-commit=<40-hex>
    [--limit=<n = global.verify_limit>] [--canary=<path = res://tests/fixtures/bench/determinism_entry.json>]
    [--today=<YYYY-MM-DD>] [--message=<file>]
```

**Flow:**

1. Load the config (§3) and the content; errors → exit 1. `--board` must hold `runs/`;
   `verified/` is created when missing.
2. **The canary** (§16.8): judge the canary entry with `BenchVerifier.check`, the config's
   `max_days` set to the entry's (300) and under its §10.2 name (the fixture's own file name is
   not one) — it must come out `verified`.
   A mismatch prints `verify: canary mismatch — this machine does not reproduce the recorded run;
   nothing written` and exits 3 **before anything is written** — a platform that does not
   reproduce would otherwise reject every honest run.
3. List `runs/*.json`, sorted by name, no recursion; a name outside `^[a-z0-9._-]+\.json$` is
   ignored (and counted). Per file: its bytes (a file above `global.max_run_bytes` is judged
   `unreadable` unread) and their SHA-256; skipped when `verified/<name>` holds a current record.
   The others, **at most `--limit` per invocation** (the rest wait for the next run and are
   counted as `waiting`), go through `BenchVerifier.check`.
4. Write each record (`<name>.tmp`, then rename). A record whose run file is gone (the owner
   removed a run) is deleted.
5. Rebuild the board's `leaderboard.json` and `LEADERBOARD.md` from the verified runs (§16.3),
   unless the rows are unchanged.
6. Print `verify: checked <n>, verified <k>, rejected <r>, waiting <w>, ignored <i>, board
   <changed|unchanged>`. With `--message=<file>` write the commit message
   `verify: <k> verified, <r> rejected (game <first 7 of the commit>)` — numbers and the commit
   only, nothing from a run file.

**The checks, in order; the first that fails is the record's `reason`:**

| `reason` | When |
| --- | --- |
| `unreadable` | above `max_run_bytes`, not UTF-8 JSON, or `BenchEntry.from_dict` returns null (`detail` = its `last_error`) |
| `file_name` | the file name is not §10.2's name for the entry |
| `rules` | not the benchmark's rules on this checkout: `setup` ≠ `config.setup`; `max_days` or `interval_days` ≠ the config's; `suite` unknown or `seed` not in it; `locale` not `en`/`de`; `prompt_version` or `parser_version` above the config's; `params_id` ≠ the hash of `params` (§10.2); a `bot:` model without `backend: "bot"` or the reverse; more than `Policy.MAX_COMMANDS_PER_DAY` commands on one day; commands out of day order or after `end_day`; `end_day` > `max_days` |
| `content` | `content_hash` ≠ the checked-out content's |
| `refused` | a command is refused in the replay (`detail`: its day and type id) |
| `outcome` | the replay's outcome ≠ the entry's |
| `days` | the replay stops on another day than `end_day`, or its `day − origin_day` ≠ `days` |
| `score` | `BenchScore.run_score` of the replay differs from `score` by more than 0.05 (the one-decimal rounding) |
| `unfinished` | no outcome at `end_day` although `end_day` < `max_days` (a run cut short) |
| `hash` | the replay's `state_hash()` ≠ `hash` — last, because it catches everything the lines above do not name |

- **The replay** is `Simulation.replay`'s loop (commands on their day, tick, stop at `end_day` or
  an outcome), owned by `BenchVerifier` **without `push_error`**: a refused command in a
  submitted file is bad data, not a programming error (CLAUDE.md, *Errors*). It stops at
  `end_day` like the tool's own replay check (§11.1 step 4).
- **Run files are data, only data.** They are parsed as JSON and read through
  `BenchEntry.from_dict`, which never crashes on bad data; nothing in them is executed, loaded as
  a resource or evaluated; no value from them reaches a shell, a path (a record's path is the run's
  already-checked file name) or the start of an output line (every line the verifier prints
  begins with `verify:`, values are JSON-escaped — and the workflow also stops workflow commands
  around the step, §16.5).
- Only `commands`, `seed`, `setup`, the rule fields and the compared numbers decide a verdict.
- **Exit codes:** 0 done (a rejection is a result, not a failure) · 1 bad arguments, content or
  config errors, no `runs/` in the board · 2 a record or the board could not be written · 3 the
  canary did not reproduce (nothing written).

**The bot reference rows** (§10.4) are published by the same job:
`bench_run.gd -- --bots --suite=standard --out=<board> --if-missing --no-rebuild` runs before the
verifier. `--if-missing` plays only when `<board>/runs/` lacks, for some bot and seed, an entry
on the current content; the new files overwrite the previous content's under the same §10.2
names, and the verifier then checks them like any run. `--no-rebuild` leaves the board's
leaderboard to the verifier (`bench_run` would count unverified runs).

### 16.5 The workflow — `.github/workflows/leaderboard.yml` (in the private game repository)

```yaml
# Verifies the public leaderboard's runs with the game and publishes the verified board.
# Scheduled and manual only - never on a pull request: the deploy key must never meet code
# from a fork. Run files are read as data by the verifier (docs/specs/benchmark.md §16.4).
name: leaderboard
on:
  schedule:
    - cron: "23 3 * * *"
  workflow_dispatch:
permissions:
  contents: read
concurrency:
  group: leaderboard
  cancel-in-progress: false
jobs:
  verify:
    runs-on: ubuntu-latest
    timeout-minutes: 60
    container:
      image: barichello/godot-ci:4.7.2
    env:
      HAS_KEY: ${{ secrets.LEADERBOARD_DEPLOY_KEY != '' }}
    steps:
      # 1 no key on a schedule: stop (a dispatched run without the key is a read-only dry run)
      # 2 actions/checkout@v5 - the game at main: the content that counts
      # 3 godot --headless --path . --import
      # 4 with the key: ssh key file + pinned known_hosts, then clone over SSH;
      #   without: clone over HTTPS (read-only)
      # 5 bench_run.gd --bots --suite=standard --out="$BOARD" --if-missing --no-rebuild
      # 6 verify_runs.gd --board="$BOARD" --game-commit="$GITHUB_SHA" --message=<file>,
      #   between ::stop-commands::<random token> and ::<token>::
      # 7 with the key: commit and push if anything changed
```

**The steps** (S6.12b writes them out; `shell: bash` for every `run`, as `ci.yml` does):

1. **Gate.** On `schedule` with `HAS_KEY` false: print `leaderboard: LEADERBOARD_DEPLOY_KEY is
   not set — nothing to do`; every later step has `if: env.HAS_KEY == 'true' ||
   github.event_name == 'workflow_dispatch'`, so the job ends green without an import. A
   `workflow_dispatch` without the key runs steps 2–6 read-only and prints what it would publish
   (`git -C "$BOARD" status --short`). `BOARD` is `$RUNNER_TEMP/board`, set through
   `$GITHUB_ENV` in step 4 (inside a container, `${{ github.workspace }}` names the host's path,
   not the container's — use the shell's variables).
2. **Check out** the game (`actions/checkout@v5`, the default branch — `main`, whose content is
   the one runs are verified against, §16.2).
3. **Import** (`godot --headless --path . --import`).
4. **Clone the public repository.** With the key: install `openssh-client` if `ssh` is missing
   (`apt-get install -y --no-install-recommends openssh-client`); write the secret (passed through
   `env`, never on a command line) to `~/.ssh/leaderboard`, mode 600; write `~/.ssh/known_hosts`
   with GitHub's **pinned** Ed25519 host key (`github.com ssh-ed25519
   AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl` — the builder checks it
   against GitHub's published fingerprints on the day; never `ssh-keyscan` at run time);
   `GIT_SSH_COMMAND="ssh -i ~/.ssh/leaderboard -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes"`;
   `git clone --depth 50 git@github.com:DenRakEiw/doomsday-leaderboard.git "$BOARD"`. Without the
   key: `git clone --depth 50 https://github.com/DenRakEiw/doomsday-leaderboard.git "$BOARD"`.
5. **Bot rows** (§16.4): `bench_run.gd -- --bots --suite=standard --out="$BOARD" --if-missing
   --no-rebuild`.
6. **Verify:** a random token (`od -An -N16 -tx1 /dev/urandom | tr -d ' \n'`), `echo
   "::stop-commands::$token"`, the verifier with `--board="$BOARD" --game-commit="$GITHUB_SHA"
   --message="$RUNNER_TEMP/message.txt"`, its exit status kept (`set +e` around it), `echo
   "::$token::"`, then exit with the status. Exit 1–3 fail the job — GitHub mails the owner;
   nothing is pushed.
7. **Publish** (only with the key): `git -C "$BOARD" add -A runs verified leaderboard.json
   LEADERBOARD.md` (fixed pathspecs); nothing staged → `leaderboard: nothing to publish`, done.
   Else commit with `-F "$RUNNER_TEMP/message.txt"` as `github-actions[bot]`
   (`41898282+github-actions[bot]@users.noreply.github.com`) and `git push origin HEAD:main`. A
   rejected push (a pull request merged meanwhile): `git pull --rebase origin main` once and push
   again — the verifier only writes `verified/`, the two board files and `bot:` runs, which no
   pull request touches, so the rebase is clean; runs merged meanwhile wait for tomorrow. A second
   rejection fails the job.

**Why it is safe.**

- **Triggers:** `schedule` and `workflow_dispatch` only — never `pull_request` or
  `pull_request_target`; nothing in the public repository can start it. It reads the public
  `main` after the owner merged, and only as data (§16.4).
- **The key** is a deploy key of the **public** repository with write access to that repository
  alone — it opens nothing in the game repository. It lives only in the secret
  `LEADERBOARD_DEPLOY_KEY` and in the job's `~/.ssh` for the job's life. The job's `GITHUB_TOKEN`
  is read-only (`permissions: contents: read`).
- **No data in a shell:** file names are listed by Godot, not globbed into a command; the commit
  message is numbers and a commit; `git add` has fixed pathspecs; workflow commands are stopped
  around the verifier's output.
- `concurrency` keeps two runs from pushing at once.
- **Cost:** a private repository's Actions minutes — a run with work ≈ 5–10 minutes (image pull,
  import, replays of ≈ 5–10 s per run on the runner), ≈ 150–300 a month of the free 2 000; a
  scheduled run without the key or with nothing new is cheap (the gate; the verifier's
  early skip still needs the import).

**The user's setup** (a user step — no build step creates keys or secrets; *Waiting on the user*):

1. `ssh-keygen -t ed25519 -N "" -C "doomsday-leaderboard verifier" -f leaderboard_deploy_key`
2. `doomsday-leaderboard` → *Settings* → *Deploy keys* → *Add deploy key*: the contents of
   `leaderboard_deploy_key.pub`, **Allow write access** ticked.
3. `Doomsday` → *Settings* → *Secrets and variables* → *Actions* → *New repository secret*
   `LEADERBOARD_DEPLOY_KEY` = the contents of `leaderboard_deploy_key` (the private half).
4. Delete both local files.
5. Should the public `main` ever get a branch rule or ruleset, the deploy key must be allowed to
   bypass it (rulesets list *Deploy keys* as a bypass actor), or the push fails.
6. *Actions* → *leaderboard* → *Run workflow* once; green, and with no submitted runs yet it
   publishes the bot rows.

Until then the scheduled runs stop at the gate, and nothing is published.

### 16.6 The online list in the game (S6.13)

**When it talks to the network — the whole list:**

- **Only when the player opens the *Benchmark* modal** (§12.7) — never at start, never from the
  title's `_ready`, never in the background, never on a timer — and **at most once per
  `global.min_refetch_s`** (300 s) per process: reopening within that time reuses what was
  fetched. Never when `Settings.bench_online` is off.
- **When the player presses *Watch* on a listed run** that is not already cached: that one file.
- **What is sent:** an HTTPS `GET` of a public file with Godot's default headers — no cookie, no
  query string, no identifier, nothing about the player, their runs or their settings. The host
  sees what any download shows it (the address and the time); the setting turns it off. This is
  release.md §10's promise restated: no telemetry, no upload.

**The setting** (pending user confirmation — the recommendation): `Settings.bench_online: bool`,
key `bench_online`, **default on**; a row `UI_SETTINGS_BENCH_ONLINE` (On/Off) in the **title's**
settings after *Open data folder*, on every platform. *Why a toggle and why on:* opening the list
is already the player's explicit act, so on-demand alone would be honest — but a player who wants
the game never to touch the network gets one switch that guarantees it, and an off-by-default
feature would hide the list from nearly everyone. Off, the list shows the cached or shipped copy
(`UI_BENCH_GLOBAL_DISABLED`).

**Classes** (`game/bench/`, `class_name` each; nothing names an autoload):

```gdscript
class_name GlobalBoard
extends RefCounted
var generated: String = ""                  # the file's ISO time; "" when unusable
var content_hash: String = ""
var rows: Array[GlobalBoardRow] = []        # standard-suite rows only, in file order
var dropped: int = 0                        # rows or runs refused by the rules below
var last_error: String = ""                 # non-empty → the file is unusable
static func parse(text: String, config: BenchConfig) -> GlobalBoard
static func newer(a: GlobalBoard, b: GlobalBoard) -> GlobalBoard   # the usable one with the later `generated` (ISO strings compare as text); null when neither is usable

class_name GlobalBoardRow                   # RefCounted
var model: String; var params_id: String; var content_hash: String
var complete: bool; var runs: int; var of: int; var wins: int; var score: float
var seeds: Array[GlobalBoardRun] = []
func is_bot() -> bool                       # model begins with "bot:"

class_name GlobalBoardRun                   # RefCounted
var seed: int; var file: String; var sha256: String; var outcome: String; var days: int; var score: float

class_name GlobalBoardClient
extends Node                                # owns two HTTPRequest children, made in _ready
const SOURCE_ONLINE: String = "online"; const SOURCE_CACHE: String = "cache"
const SOURCE_SHIPPED: String = "shipped"; const SOURCE_NONE: String = "none"
const FAIL_OFFLINE: String = "offline"; const FAIL_CHANGED: String = "changed"
const FAIL_UNREADABLE: String = "unreadable"; const FAIL_OFF: String = "off"
const CACHE_DIR: String = "user://benchmark/online/"
const SHIPPED_PATH: String = "res://benchmark/global/leaderboard.json"
signal board_changed(board: GlobalBoard, source: String, loading: bool)
signal run_ready(entry: BenchEntry, reason: String)   # entry null ⇔ reason is a FAIL_*
var requests_made: int = 0                  # every GET started (the tests' ear)
func open_board(allow_network: bool) -> void
func download_run(run: GlobalBoardRun, allow_network: bool) -> void
func cancel() -> void
```

**Parsing (`GlobalBoard.parse`)** — never crashes, whatever the text: `version` must be 1,
`generated` and `content_hash` strings, `rows` an array; at most `global.max_rows` rows read.
A row is kept only with a `model` of 1–200 printable ASCII characters without spaces, `suite`
`"standard"` (other suites are practice — skipped silently, not `dropped`), whole `runs`, `of`,
`wins` ≥ 0, a number `score` in 0–100, bool `complete`, a string `content_hash`. `seeds` missing →
empty; a seed is kept only with a whole `seed`, a `file` matching `^runs/[a-z0-9._-]+\.json$`, a
64-hex `sha256`, a string `outcome`, a whole `days` and a number `score`. Everything refused
counts in `dropped` (one `push_warning` per parse, with the count). Unknown keys are ignored.

**Where the board comes from** (`open_board`):

1. At once: `local = GlobalBoard.newer(<cache>, <shipped>)` — the cache
   `user://benchmark/online/leaderboard.json`, the shipped copy `res://benchmark/global/leaderboard.json`
   — emitted with its source and `loading` = whether a fetch follows.
2. **Fetch** (network allowed, not within `min_refetch_s` of the last success in this process):
   `GET global.leaderboard_url` (`timeout` = `global.timeout_s`, `body_size_limit` =
   `global.max_board_bytes`). Status 200 and a usable parse → emitted as `online`; the body is
   written to the cache (`.tmp`, then rename) unless the cache's `generated` is later. Anything
   else — no network, a timeout, a status other than 200, too large, unusable — keeps `local`
   (emitted again with `loading` false).
3. **The shipped copy** `benchmark/global/leaderboard.json` is the public file as it was when the
   build was made: S6.13 commits today's; `release.yml`'s export job refreshes it before exporting
   (`curl -fsSL --max-time 30 <leaderboard_url>` to a temporary file, moved over the committed copy
   only when the download succeeded — a failure keeps the committed copy). `release.md` §6.2's
   `include_filter` gains `benchmark/global/*.json` (and `test_export_presets.gd`'s list, the §6.2
   rule) in S6.13's commit.

**Watching a listed run** (`download_run`):

1. The cached file `user://benchmark/online/runs/<file's base name>` whose SHA-256 equals
   `run.sha256` → used at once, online or not.
2. Else network off → `FAIL_OFF`. Else `GET global.run_base_url + run.file` (`body_size_limit`
   `global.max_run_bytes`): no answer, a timeout or a status other than 200 → `FAIL_OFFLINE`; the
   body's SHA-256 ≠ `run.sha256` → `FAIL_CHANGED` (replaced after its verification — the next
   verification catches up); not JSON or `BenchEntry.from_dict` null → `FAIL_UNREADABLE`.
3. Success → the file is cached (`.tmp`, rename; at most `global.cache_runs_max` files, the oldest
   by modification time removed) and `run_ready(entry, "")`; the modal calls
   `ScreenRouter.start_spectating(entry)`, whose blocker shows as in §12.7.
4. **Data, never a resource:** a downloaded file is JSON through `BenchEntry.from_dict` — never
   `load()`, never `ResourceLoader`, never a `.tres` (CLAUDE.md). The model id is shown in a
   `Label`, never in a `RichTextLabel` with BBCode.
5. One download at a time: the other *Watch* buttons are disabled meanwhile. Closing the modal
   calls `cancel()` (`HTTPRequest.cancel_request()` on both).

**Platforms:** the web build's `HTTPRequest` goes through the browser's `fetch`;
`raw.githubusercontent.com` answers with `Access-Control-Allow-Origin: *`, so it works there;
`user://` is the browser's storage. **Android** needs the `INTERNET` permission in its export
preset — S7.2 sets it (D7.1/S7.2 carry-over). Steam changes nothing.

**The modal** (`ui/modals/benchmark.tscn`, extending §12.7; a `GlobalBoardClient` child):

1. Title and intro as §12.7.
2. `CapsLabel` `UI_BENCH_GLOBAL_TITLE`; a `LabelCaption` **status line** (§16.7); a `LiveRegion`
   (accessibility.md §3.4, polite) says the status when it changes after the first. Then, when
   rows are shown, `LabelCaption` `UI_BENCH_GLOBAL_NOTE`.
3. **Rows for this game's content** (`row.content_hash` = `ContentDB.content_hash` — the game's
   own test, not the file's `current`), `{rank}` counting from 1 in file order: a `VBoxContainer`
   with the model (`Label`, `TEXT_0`; a bot row reads `UI_BENCH_BOT` with the id after `bot:`)
   and `UI_BENCH_GLOBAL_ROW` (`LabelCaption`), plus `UI_BENCH_GLOBAL_PARTIAL` when not
   `complete`; right of it a `ConsoleButton` `UI_BENCH_GLOBAL_RUNS` ⇄ `UI_BENCH_GLOBAL_HIDE` that
   shows or hides the row's runs: per seed `UI_BENCH_ROW` (existing — `{seed}`, `{outcome}` =
   `UI_OUTCOME_<ID>`, `{days}`, `{score}`) and a `ConsoleButton` `UI_BENCH_WATCH`; under it a
   caption for `UI_BENCH_GLOBAL_DOWNLOADING` or `UI_BENCH_GLOBAL_FAIL_<REASON>`.
4. **Rows for other content**, under `CapsLabel` `UI_BENCH_GLOBAL_OTHER_TITLE`: model and
   `UI_BENCH_GLOBAL_ROW` with `UI_BENCH_OTHER_VERSION` (existing); no *Runs* button (they cannot
   be replayed here).
5. **Recorded runs** (§12.7's rows, unchanged) under `CapsLabel` `UI_BENCH_LOCAL_TITLE`, only when
   `BenchLibrary` found any.
6. Compact: buttons drop under their text (§12.7). Accessible names: *Runs*/*Hide* =
   `UI_A11Y_LABEL_VALUE` (`{label}` the button's text, `{value}` the model); *Watch* as §12.7
   (model and seed).

**The title's *Benchmark* button** (changes §12.7): visible when `BenchLibrary` found an entry,
**or** `Settings.bench_online` is on, **or** the cached or shipped board has a row — checked in
`_ready` without any network (the files only).

### 16.7 States and strings

| State | Status line | Rows |
| --- | --- | --- |
| fetching, nothing local | `UI_BENCH_GLOBAL_LOADING` | none yet |
| fetching, a local copy | `UI_BENCH_GLOBAL_LOADING` | the local copy's |
| fetched | `UI_BENCH_GLOBAL_AS_OF` (`{date}`) | the fetched file's |
| fetch failed, a local copy | `UI_BENCH_GLOBAL_OFFLINE` (`{date}`) | the local copy's |
| setting off, a local copy | `UI_BENCH_GLOBAL_DISABLED` (`{date}`) | the local copy's |
| nothing usable at all | `UI_BENCH_GLOBAL_UNAVAILABLE` | none |
| a usable file without standard rows | the line for its source, then `UI_BENCH_GLOBAL_EMPTY` | none |
| a run downloading | `UI_BENCH_GLOBAL_DOWNLOADING` under the run | *Watch* buttons disabled |
| a download failed | `UI_BENCH_GLOBAL_FAIL_OFFLINE` · `_CHANGED` · `_UNREADABLE` · `_OFF` under the run | — |

`{date}` = the first ten characters of `generated` (the ISO date, as written — language-neutral,
like a seed). New keys, en/de in `strings.csv` since D6.9b: `UI_BENCH_GLOBAL_TITLE` · `_NOTE` ·
`_LOADING` · `_AS_OF` · `_OFFLINE` · `_DISABLED` · `_UNAVAILABLE` · `_EMPTY` · `_ROW` (`{rank}`,
`{score}`, `{wins}`, `{runs}`) · `_PARTIAL` (`{runs}`, `{of}`) · `_OTHER_TITLE` · `_RUNS` · `_HIDE` ·
`_DOWNLOADING` · `_FAIL_OFFLINE` · `_FAIL_CHANGED` · `_FAIL_UNREADABLE` · `_FAIL_OFF` ·
`UI_BENCH_LOCAL_TITLE` · `UI_SETTINGS_BENCH_ONLINE`. A key built at run time
(`UI_BENCH_GLOBAL_FAIL_<REASON>`) is listed in the modal's `KEYS` constant for the strings check.

### 16.8 Cross-platform determinism — the canary

S6.10's CI got the same state hash from the Linux export as from the Windows build; the verifier
runs on Linux and judges runs recorded on Windows (and elsewhere), so this must stay true.

- **`tests/fixtures/bench/determinism_entry.json`** — a §10.2 entry (`mock:cheapest`, seed 1001,
  the benchmark setup, `max_days` 300) **recorded on Windows** with its `hash`, written by
  `bench_run.gd -- --determinism-fixture` (to that path; the tool prints the hash).
- **`tests/integration/test_bench_determinism.gd`** replays it (`BenchVerifier.check` on its
  bytes under its §10.2 name, the config's `max_days` taken from the entry) and asserts `verified`. It runs in the
  suite on Windows and in CI on Linux — so a divergence between the platforms turns CI red.
- **When content changes**, the replay's hash changes on every platform: the test fails with
  `content changed — regenerate on Windows: "$GODOT" --headless --path . -s
  tools/bench/bench_run.gd -- --determinism-fixture` (it tells the two cases apart by the entry's
  `content_hash`). Whoever changes `data/` regenerates it **on Windows** in the same commit; a
  regeneration on Linux would prove nothing.
- The verifier uses the same file as its canary (§16.4 step 2).

### 16.9 Tests and acceptance

**S6.12 (the estimate, §11.5):** `tests/unit/test_bench_estimate.gd` — the two figures from
fixed measures and prices (a worked example in the test); price unknown → no figures and the
`unknown` flag; the models-list reader finds a model's prices, returns empty for a missing model,
a non-JSON body, a price that is not a number string; the reply reader (`_read_reply`) takes
`usage.cost` when present, else tokens × a known price, else 0; `--yes` and the exit-7 rule
through the tool's pure decision helper (`preflight_blocks(estimate, cap, yes) -> bool`).

**S6.12b:**

- `tests/unit/test_bench_verifier.gd` (real content; a mock entry of 300 days made in the test,
  its config built with `max_days` 300): the clean entry is `verified`; one test per reason —
  a changed `hash`; `score` +1; another `outcome`; `days` changed; a command moved to a day it is
  refused; a command after `end_day`; 65 commands on one day; `setup.difficulty` changed; a seed
  outside the suite; another `content_hash`; `params_id` not matching; a wrong file name; bytes
  that are not JSON; a file above the limit; an entry cut short (`unfinished`). No `push_error`
  in any (GUT's error count stays 0).
- `tests/unit/test_verify_record.gd` — `to_dict` → `from_dict` equal; each key missing or
  ill-typed → null; `detail` never holds the entry's model string (an entry whose model is a
  marker string, rejected for each reason).
- `tests/integration/test_verify_runs.gd` (a temp board under `user://`): two good runs, a
  tampered one, a broken one, a file with a bad name → four records, the bad name ignored; the
  board counts two runs; a second invocation writes nothing and leaves the board byte-identical
  (unchanged rows); a run file changed → only it is verified again; a record whose run was
  removed is deleted; `--limit=1` leaves the rest `waiting`; a canary with a wrong hash → exit 3
  and no file written; the message file holds only numbers and the commit.
- `test_bench_score` / the writer (extend): `seeds` per row with `sha256`; the verified map
  filters; no rewrite when unchanged.
- `tests/integration/test_bench_determinism.gd` (§16.8).
- The tool's `--bots --if-missing` (extend `test_bench_run`): a second call with current bot
  files plays nothing; `--no-rebuild` leaves the board's files alone.
- The workflow: `tests/unit/test_workflows.gd` (or the existing presets test's neighbour) reads
  `leaderboard.yml` as text and asserts: no `pull_request` trigger, `permissions: contents: read`,
  the secret used only through `env`, the pinned `known_hosts` line, the stop-commands wrapper.

**Done when (S6.12b):** the verifier, run locally against a clone of the public repository in a
temp directory with the suite's mock and bot runs copied in, verifies them, rejects a tampered
copy with `hash`, writes the board, and a second run changes nothing; the determinism test is
green locally and in CI; the workflow file is committed. **It is not run and nothing is pushed
to the public repository** — the key is the user's (§16.5), the first run with it too.

**S6.13 (the online list):**

- `tests/unit/test_global_board.gd` — a fixture board (`tests/fixtures/bench/global_board.json`)
  parses: rows, seeds, the standard filter; a missing or ill-typed key drops the row
  (`dropped`); a bad model name, a bad run path (`../x.json`, `runs/a/b.json`, an absolute URL), a
  short `sha256` each dropped; not JSON / `version` 2 / an array → `last_error`; more than
  `max_rows` rows read no further; `newer` picks by `generated` and ignores an unusable board.
- `tests/unit/test_global_board_client.gd` — no network: the response handlers called directly
  with made-up results (200 + a good body → `online` and the cache written; 200 + a bad body,
  404, a timeout result → the local copy with `loading` false; the cache not overwritten by an
  older `generated`); `allow_network` false → `requests_made` stays 0; the refetch window; a run:
  cached with the right hash → no request; a body with another hash → `changed`; a broken body →
  `unreadable`; network off and not cached → `off`; the cache keeps at most `cache_runs_max`.
- `test_benchmark` modal (extend): each §16.7 state's status line; other-content rows have no
  *Runs* button; bot rows read `UI_BENCH_BOT`; **opening the title makes no request**
  (`requests_made` 0 after the title's `_ready`, the modal closed).
- `test_settings` (extend): `bench_online` defaults to true, persists, a bad value reads as the
  default.
- `test_export_presets` (extend): `benchmark/global/*.json` in the include filter.

**Acceptance (S6.13, adds to §14.2):** with the setting on and the network up, the list shows the
public board's date (with no verified runs yet: `UI_BENCH_GLOBAL_EMPTY` and the bot rows once
the workflow has published them); with the network cut (or the setting off) the cached copy with
`UI_BENCH_GLOBAL_OFFLINE` / `_DISABLED`; a listed run watched to the verified line — **if** the
public board has one by then, else a board served from a local fixture through a debug-only
`--global-board=<path>` switch (`Game.debug_allowed`, like `--spectate`); en and de, 1920 and
400 px; `game_get_errors` empty.

### 16.10 Decisions and questions (D6.9b)

**Decisions:** the leaderboard is global through the public `doomsday-leaderboard` repository
(user decision 2026-09-25); submissions by pull request, structural check there, **replay
verification in the private game repository's scheduled workflow** with a deploy key; records
per run keyed by the file's SHA-256; verified-only boards; older content keeps its verdict;
the game reads the public file on opening the list only, caches it, falls back to the cache or a
shipped copy, and downloads one run on *Watch*, checked against the verified SHA-256; the
verifier is its own tool; a Windows-recorded canary keeps the platforms honest; the cost cap is
2 USD with a pre-flight estimate (§11.5).

**Waiting on the user** (pending user confirmation where marked):

1. **Create the deploy key and the secret** (§16.5's six steps) — until then nothing is published.
2. The **2 USD** default cap (pending user confirmation) — a standard suite of a mid-priced model
   will stop at the pre-flight and needs `--max-cost` or `--yes` on purpose.
3. The **online-list setting**, default **on**, fetching only when the list opens (pending user
   confirmation) — or on-demand with no setting, or default off.
