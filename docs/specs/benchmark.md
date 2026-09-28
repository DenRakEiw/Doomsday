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

**D6.9c (2026-09-26)** adds **§17, the decision-model backend** (TypeSafe's Jev: one request of
choice questions per decision, each offering only legal moves) and touches §0 item 14, §1, §3,
§8.1, §9, §10.2–§10.3, §11, §11.3 and §13. Builds from it: **S6.12c** (mock only).

**S6.12d (2026-09-27)** adds **§18, effort levels** (*normal / high / ultra*, shown on every
entry and row), **the model catalogue, `run_models.ps1` and `submit_runs.ps1`** (with a local
verification while the deploy key is missing) and the user guide *Running your own models*
(§18.9); it touches §3, §8.3, §10.2–§10.3, §11, §12.5, §12.7, §13 and §16.6. Its choices are
pending user confirmation (§18.10).

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
14. **Decision models play too** (D6.9c, §17): a backend of kind `choice` (TypeSafe Jev) gets the
    same brief and digest as text and one choice question per kind of move, each offering only
    what `sim.can_apply` accepts now; its answer is ranked options, never text, and it ranks on
    the same board (`backend: "typesafe"`).

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
| `game/bench/bench_choice.gd` | 6.12c | `class_name BenchChoice` — the plan, the reader, the combiner (§17.3, §17.5, §17.6) |
| `game/bench/bench_choice_plan.gd` · `bench_choice_read.gd` | 6.12c | `class_name BenchChoicePlan` / `BenchChoiceRead` (§17.3, §17.5) |
| `game/bench/mock_choice_backend.gd` | 6.12c | `class_name MockChoiceBackend` (§17.10) |
| `tools/bench/typesafe_backend.gd` | 6.12c | `extends ModelBackend`, no `class_name`, preloaded (§17.8); the shared transport may move to `tools/bench/bench_http.gd` |
| `tools/bench/set_api_key.ps1` | 6.12c | the user's helper: a small dialog that stores `OPENROUTER_API_KEY` or `TYPESAFE_API_KEY` as a user environment variable (§11.4) |

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
| *D6.9c — the next rows enter the file in S6.12c, together with their reader: `test_bench_config` requires a reader and a reason for every key the file holds.* | | | |
| `choice.choice_version` | int ≥ 1 | 1 | bumped by any change to §17.2–§17.6 or a `BENCH_CHOICE_*` string's meaning; goes into a choice run's `params` (§17.7) |
| `choice.max_options` | int ≥ 2 | 255 | options per question, the control key included (TypeSafe's limit, §17.3) |
| `choice.max_picks` | object of int ≥ 1 | `buy` 3 · `use` 2 · `wake` 2 · `sleep` 2 | picks of a multi-pick question per decision (§17.6); into `params` |
| `typesafe.model_prefix` | string | `typesafe/` | a model id with it uses the TypeSafe backend; the rest is sent as `model` (§17.9) |
| `typesafe.base_url` · `typesafe.path` | string | `https://api.typesafe.ai/v1` · `/systemone` | the endpoint (§17.8) |
| `typesafe.key_env` | string | `TYPESAFE_API_KEY` | the environment variable read for the key |
| `typesafe.price_input_usd_per_mtok` · `typesafe.price_output_usd_per_mtok` | float | 0.042 · 0.0 | the published price (docs.typesafe.ai/models, 2026-09-26); negative = unknown (§17.9) |
| `typesafe.max_requests` | int ≥ 1 | 3000 | HTTP requests per invocation, retries included (§17.8); `--max-requests` overrides |
| `typesafe.question_tokens_per_call` | int ≥ 0 | 1500 | the estimate's allowance for the questions (§17.9) |
| `typesafe.state_limit_tokens` · `typesafe.request_limit_tokens` | int | 32000 · 64000 | the service's limits, checked in the dry run (§17.9) |
| `effort.high` · `effort.ultra` | object | `reasoning` ["high"] · ["max", "xhigh", "high"]; `max_completion_tokens` 16000 · 32000; `output_tokens_per_call` 3000 · 8000; `timeout_s` 600 · 900 | S6.12d, §18.1: what a level sends and what it likely costs |

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

**Since D6.9c** a backend has a kind: `chat` (everything above) or `choice` (`choose(plan, …)`,
and three more `ModelReply` fields) — §17.4.

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
when `--reasoning` is given (or the effort level's, §18.1: `high`, or `max`/`xhigh`/`high` for
`ultra`); `top_p` only when `--top-p` is given. `seed` always (providers that
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
  retry's extra message is a different key. *Since D6.9c* the `messages` member is one case of a
  **basis** (a choice request's is its `state` and `questions`, §17.7); a chat request's key is
  unchanged.
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
- A decision-model entry (§17.7) has `backend: "typesafe"` and one optional key more,
  `model_version` (the version the service reported), written only when not empty and read as
  optional — every other entry is unchanged byte for byte.
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
- **Since S6.12d** a chat row carries `effort` and `LEADERBOARD.md` an *Effort* column (§18.2).
- **Since D6.9c** a row whose runs report a `model_version` also carries `model_versions` (sorted,
  distinct; absent otherwise), and `LEADERBOARD.md` shows a choice row's params its own way —
  §17.7.

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
    --model=<id> [--backend=openrouter|typesafe|mock:cheapest|mock:wait|mock:invalid|mock:mixed|mock-choice:<mode>]
    [--suite=standard|quick] [--seeds=a..b] [--locale=en|de]
    [--temperature=<f>] [--max-tokens=<n>] [--json-mode=true|false] [--effort=normal|high|ultra | --reasoning=low|medium|high] [--top-p=<f>]
    [--base-url=<url>] [--key-env=<VAR>] [--max-cost=<usd>] [--yes]
    [--out=<dir=res://benchmark>] [--cache=<dir=res://benchmark/cache>] [--fresh]
    [--data=<root=res://data>] [--dry-run] [--no-rebuild]
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
was unavailable after the retries · 6 the cost cap (or, for TypeSafe, the request cap — §17.8) was reached · 7 the pre-flight estimate is
above the cost cap and `--yes` was not given (nothing was requested). With 4–6, entries finished
before the stop are kept and the leaderboard is rebuilt; the interrupted run leaves no file.

### 11.4 Cost and time, for the user

A standard-suite run of one model ≈ 10 runs × 60–90 calls × (≈10 k brief + ≈2–3 k digest)
tokens ≈ 8–12 M input tokens, a few hundred thousand output. What that costs depends on the
model and on whether its provider caches the unchanging brief; `--suite=quick` (3 seeds) and
`--dry-run` are the cheap ways to look first. Wall clock is dominated by the model's latency
(≈ 800 calls × its seconds per answer); shards (`--seeds`) run in parallel processes.

**The key** is a user environment variable. The easy way to set it (Windows):
`powershell -ExecutionPolicy Bypass -File tools\bench\set_api_key.ps1 -Name OPENROUTER_API_KEY`
(or `-Name TYPESAFE_API_KEY`) opens a small dialog — paste with Ctrl+V, *Show key* to check it —
and stores the key for the user. It prints only that it was saved, the key's length and whether
it starts with the service's known prefix, never the key. Only processes started afterwards see
it: open a new PowerShell window before running the tool.

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
   *(S6.12d: after the seed, a `LabelCaption` `UI_BENCH_EFFORT` — the model's effort level, a
   dash for a bot or a decision model, §18.8.)*
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

**The decision-model questions** (D6.9c, §17.2–§17.3; the model reads them, no player does) —
`BENCH_CHOICE_RULES` · `_STANCE` · `_STANCE_OPTION` (`{name}`, `{hint}`) · `_ORIGIN` · `_EVENT`
(`{event}`, `{title}`, `{days}`) · `_EVENT_OPTION` (`{text}`, `{cost}`, `{notes}`) ·
`_EVENT_DEFAULT` · `_LATER` (`{default}`) · `_WAKE` · `_NONE_WAKE` · `_SLEEP` · `_NONE_SLEEP` ·
`_REGION_OPTION` (`{name}`, `{continent}`) · `_USE` · `_ABILITY_OPTION` (`{name}`, `{cost}`,
`{detail}`) · `_NONE_USE` · `_TARGET` (`{name}`) · `_BUY` · `_NODE_OPTION` (`{name}`, `{cost}`,
`{effect}`) · `_NONE_BUY` · `_SITE` (`{name}`). No player-visible string is new: a Jev run shows
its model id as data, like any model.

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
   *(The FLUX 3 Action track that followed (D7.F, a "trained agents" category) was cut on
   2026-09-26 — not planned. Decision models such as TypeSafe Jev, §17, stay.)*
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
var rows: Array[GlobalBoardRow] = []        # standard- and quick-suite rows, in file order (S6.12e)
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
`"standard"` or, since S6.12e, `"quick"` (any other suite is skipped silently, not `dropped`), whole `runs`, `of`,
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
3a. **Quick-suite rows for this content** (S6.12e, user decision 2026-09-27), after item 3's rows,
   under `CapsLabel` `UI_BENCH_GLOBAL_QUICK_TITLE` and `LabelCaption` `UI_BENCH_GLOBAL_QUICK_NOTE`
   (both hidden without such a row): as item 3, with their own `{rank}` from 1 — a quick score
   never ranks against a standard one. In item 4, `{rank}` counts per suite and a quick row adds
   `UI_BENCH_GLOBAL_QUICK_TITLE` as a caption.
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

---

## 17. The decision-model backend — TypeSafe Jev (D6.9c)

D6.9c (2026-09-26). The user's decision (2026-09-25, *Decisions*): decision models play too —
TypeSafe's **Jev** as a second backend kind, ranked on the same leaderboard. Builds from it:
**S6.12c** (mock only — no live request in any test or build step). TypeSafe's documentation was
read on the day (`docs.typesafe.ai`: `api.md`, `models.md`, `primitives/choice.md`,
`concepts/state.md`, `confidence.md`, `cookbooks/parallel_questions.md`,
`cookbooks/consistency_choice_cookbook.md`, the Python SDK's `retries` and `exceptions` pages);
what it says is marked *TypeSafe:* below. Nothing it leaves open is guessed at a cost — §17.11.

### 17.1 What Jev is, and what that changes

*TypeSafe:* `POST https://api.typesafe.ai/v1/systemone`, `Authorization: Bearer <key>`, body
`{"model", "state", "questions"}`; `state` is a string, an object or an array of text ("use an
object for most requests so each part of the state has a descriptive name"); `questions` is a map
*id → question*; a **choice** question has `instructions` and `criteria` (a map *option key →
description*, at most **255** options; "option names and descriptions are both visible to the
model"). The reply is `{"model": "<version>", "answers": {<id>: {"type": "choice", "choice",
"probabilities": {<key>: p, …} (sum 1), "confidence": 0–1}}, "usage": {"input_tokens",
"output_tokens"}}`. "Jev ingests the `state` once and evaluates every question against it in
parallel"; each question is "scored on its own … its answer doesn't depend on what else is in the
request". Limits: 64 k tokens a request, **32 k for `state` plus the longest question**; text
only, English the primary language. Models: `jev-latest` (the stable alias, today `jev-1.13.0`)
and `jev-preview`; versioned ids are accepted and pin a version. **Price:** 0.042 USD per million
**input** tokens, **output tokens free**. Rate limit 1 200 requests a minute. Not deterministic:
repeated identical requests flip on borderline questions (their consistency cookbook).
Errors 400 · 401 · 403 · 404 · 422 · 429 · 5xx · 529.

So Jev writes no text at all: **it can only pick from the options it is given**. That turns §7's
problem around — instead of parsing what a model wrote, the policy asks one question per kind of
move and offers **only moves that can be made now** (§17.3). What stays the same: `ModelPolicy`
(§4 — the rhythm, the triggers, the housekeeping, the budget of 250 calls, one call per
decision), the digest (§6), `BenchAnswer`/`BenchAction` and the day's command queue (§4.2, §7.3),
the entry, the verifier, the leaderboard, the spectator.

### 17.2 One decision is one request

At a decision, after the digest is built (§6.1), the policy builds a **plan**
(`BenchChoice.plan`, §17.3) — the request's `state` and `questions` — asks the backend once,
reads the reply into one **ranking** per question (§17.5), and combines the rankings into one
`BenchAnswer` (§17.6), whose actions are queued exactly like a chat model's (§4.2 steps 2–3).

**`state`** — an object with two text members, in the run's locale:

| Member | What |
| --- | --- |
| `rules` | the brief (§5) items 1–8 — role, loop, win, the rule paragraphs, the run, the world, the tree, the abilities — then `BENCH_CHOICE_RULES` as its last paragraph. §5 items 9–10 (stances, the JSON format and the verbs) are left out: the stances are a question's options, and there is no format. `BenchPrompt.rules(db, setup, config) -> String`, built once per run |
| `situation` | the digest text (§6.3) items 1–10 — **without** item 11 (`BENCH_DIGEST_ASK`, which asks for JSON). `BenchPrompt.digest_text(d, db, ask: bool = true)`; the choice path passes `false` |

The same outcome-language strings as the chat prompt, so the content rule holds as it does there:
game words in, ids out. Two text members, not the typed digest as JSON: the text is what a player
reads and what the chat models read, so both kinds of model are judged on the same information.
Expected size: `rules` ≈ 9–10 k tokens, `situation` 2–5 k — well under the 32 k limit (the dry
run checks it, §17.9).

### 17.3 The questions — legal moves only

`BenchChoice.plan(sim: Simulation, digest: BenchDigest, rules: String, situation: String,
config: BenchConfig) -> BenchChoicePlan` — pure: it reads the simulation and never changes it
(`state_hash()` and the command log unchanged). **An option is offered only when the command it
stands for passes `sim.can_apply` now** — the one code path that decides what the player may do
(§7.3). The questions, in this order (also the order of the `questions` map sent):

| Id | Asked when | Options (key → description), in this order | Control key (last) |
| --- | --- | --- | --- |
| `stance` | always | the seven §7.1 stance ids → `BENCH_CHOICE_STANCE_OPTION` (`{name}` `BENCH_STANCE_<ID>`, `{hint}` `BENCH_STANCE_<ID>_HINT`) | — |
| `origin` | only before the origin (then it is the only other question) | `digest.origins` → `BENCH_CHOICE_REGION_OPTION` (`{name}` `REGION_<ID>`, `{continent}` `CONTINENT_<ID>`) | — |
| `event_<event id>` | per open event, digest order, when at least one option is legal | its options (digest order) with `ChooseEventOptionCommand(event, option)` legal **and not short** → `BENCH_CHOICE_EVENT_OPTION` (`{text}` the option text, `{cost}` `EventView.cost_text`, `{notes}` `BENCH_CHOICE_EVENT_DEFAULT` for the default option, else "") | `later` → `BENCH_CHOICE_LATER` (`{default}` the default option's text) |
| `wake` | when a region can be woken | regions `r` of the digest (index order) with `SetDormancyCommand(r, false)` legal → region option | `none` → `BENCH_CHOICE_NONE_WAKE` |
| `sleep` | when a region can sleep | regions with `SetDormancyCommand(r, true)` legal → region option | `none` → `BENCH_CHOICE_NONE_SLEEP` |
| `use` | when an ability can be used | the digest's abilities (digest order) with `ready_in == 0`, `cost` ≤ compute and a legal command — global: `UseAbilityCommand(id, "")`; region: at least one legal target → `BENCH_CHOICE_ABILITY_OPTION` (`{name}` `ABILITY_<ID>_NAME`, `{cost}`, `{detail}` `ABILITY_<ID>_DETAIL`) | `none` → `BENCH_CHOICE_NONE_USE` |
| `target_<ability>` | per region ability offered under `use` | its digest `targets` with `UseAbilityCommand(id, r)` legal → region option | — |
| `buy` | when a node can be bought | the digest's offers (offer order) with `affordable` and a legal command — plain: `PurchaseNodeCommand(node, "")`; deploying: at least one legal site → `BENCH_CHOICE_NODE_OPTION` (`{name}` `TECH_<ID>_NAME`, `{cost}` the offer's cost, `{effect}` `TECH_<ID>_EFFECT`) | `none` → `BENCH_CHOICE_NONE_BUY` |
| `site_<node>` | per deploying node offered under `buy` | its digest `sites` (best-site order) with `PurchaseNodeCommand(node, r)` legal → region option | — |

Each question is `{"type": "choice", "instructions": <text>, "criteria": {<key>: <description>}}`
with plain-string descriptions. Instructions: `BENCH_CHOICE_STANCE`, `_ORIGIN`, `_EVENT`
(`{event}` the id, `{title}`, `{days}` days left), `_WAKE`, `_SLEEP`, `_USE`, `_TARGET` (`{name}`
the ability's name), `_BUY`, `_SITE` (`{name}` the node's name). Costs through `Format.number(…,
COMPUTE)`, as in the digest.

- **Option keys are content ids** (node, ability, region, option and stance ids), so whatever Jev
  picks is a valid id by construction. The control keys `none` and `later` are reserved; a test
  asserts no content id equals one (§17.10).
- **Why one question per kind** (not one question over every possible action): TypeSafe advises
  that "each question asks one specific, well-scoped thing"; the state is paid for once however
  many questions there are; and a flat list of every action (nodes × sites, abilities × targets)
  would pass 255 options.
- **The conditional questions** (`site_<node>`, `target_<ability>`) are asked in the same request,
  because the questions are answered in parallel and cannot see one another's answers; one whose
  node or ability is not picked is simply not used. They cost only their own tokens.
- **Only affordable nodes** are offered: saving for a dearer node is `none`. Locked or short event
  options are not offered; `later` is — not answering is a legal move (the default follows at the
  deadline).
- **A question with no legal option** (only its control key, or nothing) is **left out**. `stance`
  is always asked, so a request is never empty.
- **Past 255 options** (`choice.max_options`, the control key included): the first 254 legal keys
  in the order above are kept, the rest dropped. On today's content no question comes near it (72
  nodes, 61 regions, the digest's `targets_max` of 20); the rule exists so the builder never sends
  what the service refuses.
- **Question ids** are `[a-z0-9_]`: `event_17`, `target_harvest`, `site_market_microstructure`.

`BenchChoicePlan` (`RefCounted`): `state: Dictionary`, `questions: Dictionary` (the wire form),
`keys: Dictionary[String, Array]` (question id → its option keys in order — the tie-break order),
`costs: Dictionary` (question id → key → compute cost, for `event_*`, `use`, `buy`),
`deploying: Array[String]`, `regional: Array[String]`; `func body(model: String) -> Dictionary` =
`{"model", "state", "questions"}`; `func basis() -> Dictionary` = `{"state", "questions"}` (§17.7).

### 17.4 The backend interface

§8.1 gains a second kind:

```gdscript
# ModelBackend
const KIND_CHAT: String = "chat"
const KIND_CHOICE: String = "choice"
func kind() -> String                        # KIND_CHAT unless overridden
func choose(plan: BenchChoicePlan, digest: BenchDigest, params: Dictionary) -> ModelReply   # choice backends; the base returns ModelReply.fatal("no_backend")

# ModelReply — three additions, left at their defaults by the chat backends
var body: Dictionary = {}                    # a choice backend's parsed reply (§17.1's shape)
var invalid: String = ""                     # "" or a §17.5 answer error — the reply was unreadable
var model_version: String = ""               # the reply's `model`, e.g. "jev-1.13.0"
```

`ModelPolicy._decide` branches once on `_backend.kind()`: the chat path is §4–§7 as built; the
choice path builds the plan (§17.2–§17.3), asks (cache first, §17.7), reads (§17.5) and combines
(§17.6). Retries (`retry_invalid`), the call count, `budget_exhausted`, `fatal`, tokens and cost
are the same code for both.

### 17.5 Reading the reply — rankings

`BenchChoice.read(body: Dictionary, plan: BenchChoicePlan) -> BenchChoiceRead` (`RefCounted`:
`rankings: Dictionary[String, Array]`, `confidence: Dictionary[String, float]`, `model_version:
String`, `problems: Array[Dictionary]`, `error: String`). Never crashes on any body.

1. `answers` missing or not an object → `error = "bad_reply"`: the whole answer is unreadable
   (§7.4: one retry, then the decision does nothing and `invalid_answers` += 1).
2. Per question of the plan: its answer missing or not an object → problem `missing_answer`
   (the question is unanswered — §17.6).
3. **The ranking** is the question's option keys ordered by `probabilities[key]` (a number in 0–1;
   anything else, or a key not given, counts 0) **descending, ties in the plan's key order**. Keys
   in `probabilities` the plan did not offer are ignored.
4. All probabilities 0 (none given or none usable): when `choice` is one of the plan's keys, the
   ranking is that key, then the others in plan order; otherwise problem `unknown_choice`, and the
   question is unanswered.
5. `confidence` (a number) is kept per question; `model` (a string) → `model_version`.

**The reply's `choice` field does not decide** — the probabilities do, so that the pick and its
ties are ours and reproducible from a cached answer. (They agree whenever the service's `choice`
is its top probability, as documented.)

### 17.6 From rankings to one answer

`BenchChoice.combine(plan: BenchChoicePlan, read: BenchChoiceRead, digest: BenchDigest,
params: Dictionary, max_actions: int) -> BenchAnswer` — deterministic; `valid` true.
**The pick** of a question is the first key of its ranking. **The picks** of a multi-pick question
(`wake`, `sleep`, `use`, `buy`) are its ranking's keys **before the control key**, at most
`params.max_picks[<question id>]`. Jev ranks every option, so "more likely right than doing
nothing" is the rule for a second purchase in the same report: a chat model can buy several
things at once, and one purchase per ten days would handicap Jev for the adapter's sake, not its
judgement.

`remaining` starts at `digest.compute`. In this fixed order (also `BENCH_CHOICE_RULES`'s):

1. **stance** = the pick of `stance` ("" when unanswered).
2. **origin** = the pick of `origin` → `origin`.
3. **Events**, digest order: the pick of `event_<id>`; `later` → nothing; otherwise, when its cost
   ≤ `remaining` → `answer`, `remaining` −= cost; else nothing.
4. **wake**, then **sleep**: each pick → `wake` / `sleep` (free).
5. **use**: per pick, when its cost ≤ `remaining`: a global ability → `use`; a region ability →
   `use` with the pick of `target_<ability>` (unanswered → skipped with problem `missing_answer`);
   `remaining` −= cost.
6. **buy**: per pick, when its cost ≤ `remaining`: `buy`, with the pick of `site_<node>` for a
   deploying node (unanswered → skipped, `missing_answer`); `remaining` −= cost.
7. More than `max_actions` actions → the rest dropped with `over_limit` (§7.2 item 7).

- **A pick the compute no longer covers is left out silently** — not a refusal: the questions are
  answered in parallel, so Jev could not know that its event answer would leave too little for the
  node. (What `can_apply` still refuses at its turn — a node another purchase closed, a price that
  rose — is refused and fed back as for any model, §4.2 step 3.)
- **Problems** (`missing_answer`, `unknown_choice`) become `BenchAnswer.dropped` entries
  `{"index": -1, "reason": <id>, "question": <question id>}`; they count in `rejected_actions`, and
  the next digest's feedback shows them with the question id as the action's form (the policy uses
  `question` when present, `DROPPED_FORM` otherwise). `to_cache`/`from_cache` keep the key.
- **Why this order:** answers to events first (they have deadlines, and their options were offered
  as affordable now); waking and sleep cost nothing; abilities before purchases because an ability
  is timely (cooldowns) and a purchase can wait for the next report.

### 17.7 Determinism, the cache, the entry

**Jev is not deterministic** (§17.1). As for the chat models, what makes a run reproducible is not
the service but (a) the command log — a replay never asks the model (§0 item 1) — and (b) the
cache, which serves the recorded answer to the same request.

- **The cache key** (§9, generalised): SHA-256 of the sorted JSON of `{"model", "params",
  "prompt_version", "parser_version"}` **plus a basis** — a chat request's basis is
  `{"messages": messages}` (so the object, and every existing cache file's key, is unchanged); a
  choice request's is `plan.basis()` (`state`, `questions`) plus `"attempt": n` for a retry
  (n ≥ 1). The cache hooks take the basis instead of the messages. `model` is the entry's model id
  (`typesafe/jev-latest`), `params` the run's params (below) — so a new combination rule or limit
  is a new key.
- **The value:** `{"answer": BenchAnswer.to_cache(), "tokens_in", "tokens_out", "cost_usd",
  "finish": "", "model_version", "confidence": {<question id>: float}}` — the combined answer (so
  a cached decision replays exactly), not the probabilities.
- **`params`** of a choice run = `{"choice_version": <choice.choice_version>, "max_picks": {"buy",
  "use", "wake", "sleep"}}` (whole numbers, cast at the boundary). `choice_version` is bumped by any
  change to §17.2–§17.6 or to a `BENCH_CHOICE_*` string's meaning; it lives in `params`, so a bump
  gives a new `params_id` — a new row, new files, new cache keys — and the entry format needs no
  field for it. The chat-only flags (`--temperature`, `--max-tokens`, `--json-mode`, `--reasoning`,
  `--top-p`) are refused for a choice backend (exit 1): Jev takes no such parameter.
- **The entry** is §10.2's, unchanged but for two values and one optional key:
  `"model": "typesafe/jev-latest"` (what was asked for — the ranked row), `"backend": "typesafe"`,
  and **`"model_version": "jev-1.13.0"`** — the version the service reported (from the cache value
  on a cached call). Several versions within one run (the alias moved mid-run) → joined with `+`
  in first-seen order, and the tool prints `benchmark: the service changed the model version during
  the run (<a> → <b>)`. `BenchEntry` writes `model_version` **only when it is not empty** (chat and
  bot entries, the canary and every existing file stay byte-identical) and reads it as optional
  (missing → ""). `decisions` carry the stance as always; confidence is not in the entry.
- **Pinning:** `--model=typesafe/jev-1.13.0` sends `jev-1.13.0` (the part after `typesafe/`) and
  ranks as its own row. The alias is the ranked default (the user's decision); pinning is for a
  comparison.
- **The leaderboard** (§10.3): the grouping is unchanged; a row gains `model_versions` (the sorted
  distinct non-empty `model_version`s of its runs), written only when not empty — so boards
  without such a row are byte-identical and the no-rewrite rule (§16.3) holds. `LEADERBOARD.md`
  shows it after the model (`typesafe/jev-latest (jev-1.13.0)`) and a choice row's params as
  `choice v<choice_version>, picks <buy>/<use>/<wake>/<sleep>`.
- **The verifier** (§16.4) judges commands, not claims: `backend` may be any string but `bot` for
  a non-bot model (the existing rule), and `model_version` is a claim like `model`, never compared.
  **The public `validate.py`** (read 2026-09-26) checks the required keys by type and ignores keys
  it does not know; `backend` is any string, `decisions` any objects — a Jev entry passes
  unchanged. **The game** (the list, the spectator, `GlobalBoard.parse`) ignores `model_version`
  and `model_versions`; the strip shows `typesafe/jev-latest` as it shows any model id (data, not
  translated) — no new player-visible string.

### 17.8 The TypeSafe backend — `tools/bench/typesafe_backend.gd`

`extends ModelBackend`, no `class_name`, preloaded; `kind()` = `choice`, `backend_id()` =
`"typesafe"`. Never exported (`tools/*`).

- **Transport:** §8.3's `HTTPClient` loop (the builder may move it into a shared preloaded
  `tools/bench/bench_http.gd`; OpenRouter's behaviour stays exactly as it is). URL
  `typesafe.base_url` + `typesafe.path` (`--base-url` overrides the base, §8.3's rules).
  `http.timeout_s` per request.
- **Headers:** `Content-Type: application/json`, `Authorization: Bearer <key>`. Nothing else. The
  key from `OS.get_environment(typesafe.key_env)` (**`TYPESAFE_API_KEY`**, or `--key-env`), read
  once by the tool — never an argument, a file, a log line, a cache value or an entry; §8.3's
  masking of error strings applies.
- **Body:** `plan.body(<model id after the prefix>)` — `{"model": "jev-latest", "state": {…},
  "questions": {…}}`; no other key (no seed, no temperature: none is documented).
- **Reading:** 200 with a JSON object → `ModelReply.body`; `usage.input_tokens` /
  `usage.output_tokens` (whole numbers, missing → 0); `cost_usd` = input tokens ×
  `price_input_usd_per_mtok` / 10⁶ + output tokens × `price_output_usd_per_mtok` / 10⁶ (the service
  reports no cost; the price is the published one in `data/benchmark.json`). A 200 whose body is
  not a JSON object is treated as a 502 (retried).
- **Failures** (§8.3's table with TypeSafe's statuses): 401 → `FATAL auth`, 402 → `credits`,
  403 → `forbidden` (exit 4); 400 · 404 · 413 · **422** (validation — a malformed request, or one
  above the size limits) → `FATAL bad_request` with the body's `message`, `detail` or
  `error.message` if one is a string, else the status, truncated to 200 characters (exit 4);
  408 · **429** · 500 · 502 · 503 · 504 · **529** (overloaded) · connect/TLS error · timeout →
  retried `http.retries` times after `http.backoff_s × 2^(n−1)` s, honouring `Retry-After`
  (seconds) **and `retry-after-ms`** when larger (both named by TypeSafe's SDK), then
  `FATAL unavailable` (exit 5). The SDKs retry twice from 0.5 s; ours waits longer on purpose — a
  benchmark run is not latency-bound.
- **Caps, checked before every request:** cost so far ≥ `max_cost_usd` → `FATAL cost_cap`;
  requests sent this invocation (every HTTP attempt, transport retries included) ≥
  `typesafe.max_requests` (3 000; `--max-requests` overrides) → `FATAL request_cap`; both exit 6.
  The request cap is the backstop that holds even if the price were unknown or wrong: 3 000
  requests of ≈ 20 k tokens ≈ 2.5 USD at today's price. (A standard suite needs at most
  10 × 250 calls plus transport retries.)

### 17.9 The tool

```
"$GODOT" --headless --path . -s tools/bench/bench_run.gd -- --model=typesafe/jev-latest
    [--suite=…] [--seeds=a..b] [--max-cost=<usd>] [--max-requests=<n>] [--yes] [--dry-run]
    [--key-env=<VAR>] [--base-url=<url>] [--fresh] [--out=…] [--cache=…] [--locale=en|de]
"$GODOT" --headless --path . -s tools/bench/bench_run.gd -- --model=mock --backend=mock-choice:<mode> …
```

- **The backend follows the model id:** a model beginning with `typesafe.model_prefix`
  (`typesafe/`) uses `--backend=typesafe` unless `--backend` says otherwise; `--backend=typesafe`
  with another model id → exit 1 (`benchmark: the typesafe backend takes typesafe/<model>`).
  `--locale=de` runs (unranked, as for chat models); TypeSafe names English its primary language.
- **Key:** `TYPESAFE_API_KEY` unset → `benchmark: set TYPESAFE_API_KEY in the environment`,
  exit 1 (not for `--dry-run`, not for a mock).
- **Through OpenRouter** (added 2026-09-28, user request): OpenRouter serves the same endpoint
  (`https://openrouter.ai/api/v1/systemone`, ids `typesafe/jev-1.13`, `~typesafe/jev-latest`).
  `--via-openrouter` takes `base_url` and `key_env` from the chat side (`OPENROUTER_API_KEY`) and
  sends the model id whole instead of after its prefix; the row's model is the same id.
  OpenRouter reports the charge as `usage.cost`, which then replaces the price-table cost. With
  a chat model id → exit 1.
- **`--dry-run`:** prints `rules` and `situation` with `≈<tokens>` each (§11.1 step 3), then the
  day-0 request as JSON (`BenchChoicePlan.body`, tab-indented — its two questions, `stance` and
  `origin`), then `benchmark: state ≈<s> + longest question ≈<q> = ≈<s+q> tokens (limit 32000);
  request ≈<r> tokens (limit 64000)` — plus `benchmark: above the service's limit` when either is
  — then the estimate lines; exit 0, no request, no key.
- **Estimate** (§11.5 for this backend — no price lookup, the price is data): per call `input` =
  `brief_tokens` (of `rules`) + `digest_tokens` × `digest_growth` +
  `typesafe.question_tokens_per_call` (1 500 — a mid-run request's questions); **likely** = n ×
  `calls_per_run` × input × input price; **at most** = n × `max_calls` × input × input price
  (output is free). Printed and decided exactly as §11.5 items 4–5 (exit 7 above the cap without
  `--yes`). A negative price in the data means **unknown**: no block, and the line says what
  guards the run instead — `benchmark: estimate for <n> runs of <model>: price unknown
  (≈<calls> calls, ≈<tokens> input tokens) — only the request cap (<max_requests>) and 250 calls
  a run guard this run`.
- **Worked example** (the unit test's): `rules` 10 000 tokens, day-0 `situation` 2 000 → input
  10 000 + 3 000 + 1 500 = 14 500 a call. Standard suite: likely 10 × 80 × 14 500 = 11.6 M tokens
  = **0.49 USD**, at most 10 × 250 × 14 500 = 36.25 M = **1.52 USD** — under the 2 USD cap, it runs.
  One seed: ≈ 0.05 USD, at most 0.15 USD.
- **Output** (§11.2): the per-run line gains `model_version` when it is not empty. **Exit codes:**
  §11.3, with 6 also for the request cap.

### 17.10 `MockChoiceBackend` — tests without a key

`game/bench/mock_choice_backend.gd`, `class_name MockChoiceBackend extends ModelBackend`;
`MockChoiceBackend.new(mode)`, `kind()` = `choice`, `backend_id()` = `"mock-choice:" + mode`,
`static func mode_of(backend: String) -> String` ("" when not one). It answers
`choose(plan, digest, params)` with a **service-shaped body** (§17.1: `model` = `"mock-choice-1"`,
`answers`, `usage` 0/0), so every reply goes through the real reader (§17.5) and combiner (§17.6).
No clock, no random numbers; tokens and cost 0; no cache (as §9's mocks).

| Mode | Probabilities per question |
| --- | --- |
| `first` | the plan's keys in order get 2⁻¹, 2⁻², … (normalised), the control key last — so the first legal option is the pick and a multi-pick question takes as many as `max_picks` allows; stance `spread` |
| `idle` | the control key 1 (`none`, `later`), `stance` `wait`; `origin` its first key (a run needs an origin) |
| `shuffled` | each key's weight = the first 8 hex digits of SHA-256 of `"<seed>:<day>:<question id>:<key>"` as a whole number (seed = `params.seed`, day = `digest.day`), normalised — a varied, reproducible player |
| `broken` | `first`, but every third call (1-based) answers a body without `answers` (`bad_reply` → retry), and every fourth leaves out the `buy` answer and gives `stance` a `choice` it was not offered, all probabilities 0 (`missing_answer`, `unknown_choice`) |

`--backend=mock-choice:<mode>` in the tool, with any `--model` (the tests use `mock`); a fresh mock
per seed (§11.1).

**Tests (S6.12c) — no live request anywhere:**

- `tests/unit/test_bench_choice.gd` (fixture content; `plan`, `read`, `combine`): before the origin
  the plan holds exactly `stance` and `origin`, the origin keys equal `digest.origins`; after an
  origin, `buy` offers exactly the affordable offers with a legal command, `none` last; a deploying
  node gets its `site_<node>` with only legal sites; a region ability its `target_<ability>`; an
  ability cooling down or too dear is not offered; a locked and a short event option are not
  offered, `later` is; a question with no legal option is left out; no question has more than 255
  keys (a synthetic plan over the cap keeps 254 + the control key); `plan` changes neither
  `state_hash()` nor the command log; two plans of the same state are equal. **The legality
  property:** over a `mock-choice:shuffled` 300-day run, every key of every plan stands for a
  command that `sim.can_apply` accepts at planning time. Reader: ranking by probability, ties in
  plan order; unknown keys ignored; all-zero with a valid `choice`; an unknown `choice` →
  `unknown_choice`; a missing answer → `missing_answer`; no `answers` → `bad_reply`; confidence and
  model version kept. Combiner: §17.6's order; multi-picks stop at the control key and at
  `max_picks`; the compute walk leaves out what no longer fits; `later` gives nothing; sites and
  targets come from their questions; `over_limit` past `max_actions`; problems land in `dropped`
  with their question id; `to_cache` → `from_cache` equal.
- The reserved keys: no node, ability, region, option or stance id of the real content is `none`
  or `later`; every question id of a real plan matches `^[a-z0-9_]+$`.
- `tests/unit/test_mock_choice_backend.gd`: each mode's body; `shuffled` is the same for the same
  seed and day and differs for another seed; `broken`'s call pattern.
- `tests/unit/test_typesafe_backend.gd` (no network, through pure helpers as §14.1's OpenRouter
  test): the body (the model id after the prefix, `state`, `questions`, no other key); the headers
  (the key only in `Authorization`); the reply reader (usage, cost = input × price, output free,
  `model_version`, a non-JSON 200 → the retry class); the status table (401/402/403/400/404/413/422
  fatal with their reasons, 408/429/5xx/529 retried; the backoff sequence; `Retry-After` and
  `retry-after-ms`); the request cap and the cost cap → `FATAL`; no error string contains a sample
  key.
- `test_bench_cache` (extend): a chat request's key is unchanged by the basis change (a key
  computed before the change, pinned in the test); a choice basis differs by `state`, by
  `questions`, by `attempt` and by `params`; the stored value holds no probabilities.
- `test_model_policy` (extend, `MockChoiceBackend`): the choice path decides on the same days as
  the chat mock (§4.1); `broken`: one retry after `bad_reply`, then `invalid_answers` + 1 and no
  commands; a `missing_answer` counts in `rejected_actions` and appears in the next digest's
  feedback under its question id; the harness's `rejected` stays 0 in every mode.
- `test_bench_entry` (extend): `model_version` round trip; an entry without it reads `""`; an
  entry with an empty one writes no such key (byte-identical to before).
- `test_bench_score` / the writer (extend): `model_versions` on a row only when a run has one.
- `test_bench_estimate` (extend): §17.9's worked example; a negative price → unknown, no block.
- `tests/integration/test_bench_run.gd` (extend): `--model=mock --backend=mock-choice:first
  --suite=quick`, `max_days` 300: three entries with `backend` `mock-choice:first` and
  `model_version` `mock-choice-1`; each replays to its hash; a second invocation gives
  byte-identical files except `recorded`; the leaderboard ranks the row beside a `mock:cheapest`
  row and the bot rows; `BenchVerifier.check` verifies each; the cache is untouched. The tool's
  argument rules: `typesafe/…` picks the backend; a chat-only flag with it → exit 1; the key
  missing → exit 1 with the message; `--dry-run` without a key → exit 0 and prints the request.
- The strings check covers the `BENCH_CHOICE_*` rows (en and de, the same placeholders — in
  `strings.csv` since D6.9c).

**Done when (S6.12c):** `bench_run.gd --model=mock --backend=mock-choice:first --suite=standard`
run twice gives identical entries and rows, which rank beside the chat mock and the bot rows;
`BenchVerifier.check` verifies them; a copy of one passes the public `validate.py` run on a
temporary directory (read-only use of `F:\doomsday-leaderboard`, when Python is at hand);
`--dry-run --model=typesafe/jev-latest` prints the request and the estimate without a key;
`tools/test.sh` green. **No request to TypeSafe** — the first live run is the user's (§17.11).

### 17.11 Decisions and questions (D6.9c)

**Decisions:** Jev plays through one request per decision whose `state` is the chat brief (items
1–8) and the digest as two text members, and whose questions offer only moves `sim.can_apply`
accepts now — one question per kind, the conditional site and target questions asked alongside;
option keys are content ids, so an answer cannot name an impossible move — only a missing or
unreadable reply can fail; the probabilities, not the reply's `choice`, rank the options (ties in
plan order), and a multi-pick question takes the options ranked above doing nothing, up to 3
purchases, 2 abilities, 2 wakes and 2 sleeps a report, while the compute lasts; confidence is kept
in the cache only; the entry is §10.2's with `backend: "typesafe"` and an optional
`model_version`, the combination rules in `params`; the published price (0.042 USD per million
input tokens, output free) feeds the estimate and the 2 USD cap, and a 3 000-request cap per
invocation backs it; tests use `MockChoiceBackend` only.

**Waiting on the user:**

1. **`TYPESAFE_API_KEY`** — in the environment, entered the same way as the OpenRouter key: with
   the helper, `powershell -ExecutionPolicy Bypass -File tools\bench\set_api_key.ps1 -Name TYPESAFE_API_KEY` (§11.4), then a new
   PowerShell window. Then, from `F:\Doomsday`, a free look first and a one-seed run (≈ 0.05 USD):
   `& $env:GODOT --headless --path . -s tools/bench/bench_run.gd -- --model=typesafe/jev-latest --suite=quick --seeds=1001 --dry-run`,
   then the same without `--dry-run`.
2. *(A recommendation, the default unless the user says otherwise.)* The ranked Jev row is the
   alias `typesafe/jev-latest` with the served version recorded, not a pinned
   `typesafe/jev-1.13.0`; and the per-report limits 3 / 2 / 2 / 2 — enough that Jev is not
   handicapped against chat models, few enough that one report on a flat distribution cannot spend
   everything at once.

---

## 18. Effort levels, the model catalogue, running and submitting (S6.12d)

S6.12d (2026-09-27, a build step that also wrote this section; its choices are recorded as
*pending user confirmation*, §18.10). The user's requests (2026-09-26): *"wir brauchen das
AI-Modell-Leaderboard, OpenRouter-Verbindung und AI-Testläufe; ich würde die Testmodelle
auswählen, wenn alles fertig ist"* and *"schreibe auch den Aufwand dazu, also normal / hoch /
ultra"* — every entry and every leaderboard row shows the model's **effort level**.

### 18.1 The three levels

| Level | What is sent to OpenRouter (§8.3's body) | `max_completion_tokens` | Timeout | Output a call, for the estimate |
| --- | --- | --- | --- | --- |
| `normal` | no `reasoning` member — the provider's default (a model that reasons by default, `mandatory` or `default_enabled`, reasons at its `default_effort`) | 1 200 (`defaults`) | 180 s | 300; 1 200 (the limit) for a model that reasons by default |
| `high` | `"reasoning": {"effort": "high"}` — or the model's `default_effort` when it reasons by default at a higher one | 16 000 | 600 s | 3 000 |
| `ultra` | `"reasoning": {"effort": <the first of max, xhigh, high that the model's public list names>}` — never below its default either | 32 000 | 900 s | 8 000 |

The numbers are `data/benchmark.json` → `effort.high` / `effort.ultra` (`reasoning` the efforts
to try, best first; `max_completion_tokens`; `output_tokens_per_call`; `timeout_s`), read by
`BenchConfig.effort_*`. A larger `--max-tokens` given by hand stays.

**From OpenRouter's documentation** (read 2026-09-27):
- *Reasoning tokens* (`https://openrouter.ai/docs/use-cases/reasoning-tokens`): `reasoning.effort`
  takes `"max"`, `"xhigh"`, `"high"`, `"medium"`, `"low"`, `"minimal"`, `"none"` (`none` switches
  reasoning off). "When a model doesn't support a specific effort level: OpenRouter will map your
  requested effort to the nearest supported level." "Reasoning tokens are considered output
  tokens and charged accordingly"; "on most providers they also count against the request's
  `max_tokens`", and a limit spent on reasoning ends with `finish_reason: "length"` and empty
  content, still billed — hence the larger limits above (at 1 200 a reasoning model would often
  answer nothing). For models with a token budget (Anthropic, Gemini) the effort becomes
  `max(min(max_tokens × ratio, 128 000), 1 024)` with ratio 0.95 for `max`/`xhigh` and 0.8 for
  `high` — so the limit also sets how long such a model thinks.
- The public model list (`GET https://openrouter.ai/api/v1/models`, no key) carries per model a
  `reasoning` object (`supported_efforts`, `default_effort`, `mandatory`, …); non-reasoning models
  omit it and do not list `reasoning` in `supported_parameters`. The live list of 2026-09-27: 458
  models, 326 with that object; efforts range from `["high"]` to `["max", "xhigh", "high",
  "medium", "low", "none"]`.
- *Provider routing* (`https://openrouter.ai/docs/features/provider-routing`): "providers that
  don't support all the LLM parameters specified in your request can still receive the request,
  but will ignore unknown parameters" (unless `provider.require_parameters`, which we do not
  send). **So a model without reasoning would silently play a "High" run as a normal one.**

**Therefore:**
- `ultra` resolves per model from that list: `max` where listed, else `xhigh`, else `high`
  (`BenchEffort.reasoning_for`). The params record **what was sent**, so a row says it
  (`reasoning xhigh`). The model not in the list → the first of the list (`max`), which
  OpenRouter maps down; the tool prints so.
- **Normal ≤ high ≤ ultra for every model** (review of S6.12d, 2026-09-27): the list's
  `reasoning.default_effort` is what a model that reasons by default (`mandatory` or
  `default_enabled`; 100 non-mandatory models on the live list of 2026-09-27) thinks at when
  nothing is sent — 21 models have `xhigh` or `max` there. A level never sends less than that
  (`reasoning_for`'s `floor`, compared by OpenRouter's order `none < minimal < low < medium <
  high < xhigh < max`, `BenchEffort.EFFORT_ORDER`). So `high` for such a model sends its
  default, and may equal `ultra` apart from the limit.
- **Resolved once per batch** (same review): a live `high`/`ultra` whose list cannot be read
  **stops** (exit 1: `OpenRouter's model list could not be read, so what --effort=… sends …
  is unknown — try again, or pin it with --effort-reasoning=<effort>`) instead of guessing —
  a guess in one shard would give its seeds another `params_id` than its siblings'.
  `--effort-reasoning=<effort>` pins the value (an effort at or above the lowest the level
  lists; only with `--effort=high|ultra`); `run_models.ps1` resolves it once from
  `model_list.gd`'s `reasoning_sent` and gives it to every shard, `-Mock` included (so a
  rehearsal records what the live run would). A mock run without the pin still takes the
  first of the list.
- At **normal**, a model that reasons by default is **warned about, not refused**
  (`bench_run.gd`, `run_models.ps1`): its 1 200-token limit may end answers with
  `finish_reason: length` and empty content, still billed. Normal itself stays unchanged
  (no parameter, the old `params_id`).
- `high` and `ultra` are **refused** (exit 1) for a model the list names without reasoning
  support: `benchmark: <model> takes no reasoning parameter (OpenRouter's model list) — play it
  with --effort=normal`. An unlisted model is not refused.
- A decision model (`typesafe/…`) and the bots have no effort: `--effort` is one of the chat flags
  a choice backend refuses (§17.7); their lists show a dash.

### 18.2 Params, entry, row

- **Params** (§10.2): `normal` changes nothing — the params, `params_id`, file name and cache key
  of a normal run are exactly those before S6.12d (the canary's params id is the test). `high` and
  `ultra` add `"effort": "<level>"` and set `reasoning` and `max_completion_tokens` as above. So
  each level is a row of its own (§10.3 groups by `params_id`), a file of its own and a cache key
  of its own.
- **`--reasoning=low|medium|high`** stays the low-level form: that effort as given, no `effort`
  key, the default limit. It cannot be combined with `--effort` (exit 1). Its runs show the raw
  value marked, so `--reasoning=high` is never read as the level High: `BenchEffort.of_run`
  gives `reasoning-high`, the row's `effort` is that, lists show *reasoning high* / *Reasoning
  high* (`BENCH_EFFORT_RAW`), `LEADERBOARD.md` `reasoning high`. An unmarked word from a board
  written before the marker is still shown as it is.
- **Entry** (§10.2): one optional key more, **`effort`**, written after `backend` (and after
  `model_version`) **only for `high` and `ultra`**; read as optional — missing (every older entry)
  or `"normal"` → normal; another value or type → `from_dict` null (`effort: not normal, high or
  ultra`). `BenchEffort.of_entry` says what a list shows: `""` for a bot or a decision model, the
  level, or a `--reasoning` run's raw value.
- **Verifier** (§16.4, `rules`): an entry's `effort` must equal its params' `effort` (`the effort
  is not the one in params`), and for `high`/`ultra` the params must be what the level sends
  (`BenchEffort.params_broken`): `reasoning` an effort at or above the lowest the level lists
  (`effort ultra does not send that reasoning`), `max_completion_tokens` at least the level's
  (`effort ultra needs max_completion_tokens of at least 32000`).
- **Row** (§10.3): chat rows gain `"effort": "normal" | "high" | "ultra" | <raw>` after `backend`
  (and `model_versions`); bot and choice rows have no such key, so the published board of bot rows
  stays byte-identical. `LEADERBOARD.md` gains an **Effort** column after *Model* (`Normal`,
  `High`, `Ultra`, a raw value, or `—`). A public `LEADERBOARD.md` is regenerated only when its
  rows change (§16.3), so it shows the new column from its next change.
- **`GlobalBoard.parse`** (§16.6) reads `effort` as optional: a string that is a level, a marked
  raw value (`reasoning-` + a short word) or a short lower-case word (`^[a-z]{1,16}$`) is kept,
  anything else is left empty (shown as the dash) — never a reason to drop the row.
- **The public `validate.py`** (read 2026-09-27) checks the required keys by type and ignores keys
  it does not know; `params` is any object. An entry with `effort` passes unchanged — **no change
  is needed there** (the smoke run in §18.7 proves it on a clone).

### 18.3 The estimate per level

§11.5's figures take the level's numbers: *likely* uses `effort.<level>.output_tokens_per_call`
(3 000 / 8 000 instead of 300), *at most* the level's `max_completion_tokens`. The model list is
asked once per invocation (`Estimate.fetch_model`: prices, `listed`, `reasoning`, `efforts`,
`mandatory`), so the price and the effort come from the same request. Example (§11.5's model, 1 /
4 USD per million, 13 000 input tokens a call, standard suite): normal ≈ 11.36 USD, high ≈ 20.00
USD (10 × 80 × (0.013 + 0.012)), ultra ≈ 36.00 USD.

### 18.4 The catalogue — `tools/bench/models.ps1`

`models.ps1` runs `tools/bench/model_list.gd` (the parsing and the figures are
`tools/bench/model_catalogue.gd`, preloaded, pure): OpenRouter's public list, asked without a key,
one row per model — id (`*` = free: a `:free` id or both prices zero), context, input and output
price per million tokens, reasoning (`—`, `yes`, `default` — it reasons when nothing is sent,
`default_enabled` — or `always` — `mandatory` —, and the highest listed effort), and
the likely cost of the quick and the standard suite at normal and of the standard suite at high
and ultra (`—` where the level does not apply, `?` where the price is unknown), by §11.5's rule
measured on the real brief and day-0 digest. `typesafe/jev-latest` is listed first at its
published price (§17.9's estimate). Filters: `-Search <text>` (id or name), `-Free`,
`-MaxCost <usd>` (likely cost of `-Suite` at `-Effort`; unknown prices are left out), `-Effort
<level>` (both suites at that level). `--json --models=a,b` gives `run_models.ps1` one line per
model (with `reasoning_sent`, `reasons_by_default`, `default_effort`).

### 18.5 Running — `tools/bench/run_models.ps1`

`-Models a,b [-Effort normal|high|ultra] [-Suite quick|standard] [-Parallel N] [-MaxTotal usd]
[-Yes] [-Mock]`:

1. **Estimate** per model from `model_list.gd --json` (the same rule as the tool's pre-flight),
   printed with the reasoning each level sends and the total; a model the list says cannot reason
   at the chosen level stops the batch before anything starts.
2. **Keys** from the process environment, else from the user's (`HKCU\Environment`, where
   `set_api_key.ps1` stores them) — handed to the child processes, never printed.
3. **One confirmation** (`-Yes` skips it). `-MaxTotal` refuses a batch whose likely total is above
   it (exit 7) and scales the caps below so that together they stay within it.
4. **Caps:** each model gets `max(1 USD, likely × 1.5)` (the tool's default cap when the price is
   unknown); its shards share it. `bench_run.gd` gets `--yes` and that `--max-cost`, so its
   pre-flight never stops a confirmed run and its cap still does (exit 6). A **free** model
   (both list prices 0) plays under any cap, 0 included (`-MaxTotal 0` = spend nothing; the
   backend's `cap_reached`); a batch where a paid or unknown-price model's share per process
   rounds to 0.00 USD is refused before anything starts (exit 1).
5. **Runs** `bench_run.gd` per model, one after the other; `-Parallel N` starts N processes, each
   with its own `--seeds` range and `--no-rebuild` (new in S6.12d: parallel shards must not write
   the board at once) and, at high or ultra, the same `--effort-reasoning` (§18.1). Output goes
   to **`user://benchmark`** (`%APPDATA%\Doomsday\benchmark\`), so the runs show in the game
   under *Benchmark → Recorded runs*. Each process's output is kept in a log folder under
   `%TEMP%` (`-LogDir`).
6. **Stops at the first fatal error:** a shard exiting non-zero stops its siblings, and no later
   model starts; runs finished before are kept (§11.3).
7. **Rebuilds** the local board once (`--rebuild`) and prints a summary: model, effort, runs,
   score, wins, cost.

`-Mock` plays `mock:cheapest` under the given model ids with the fixture price list: no key, no
request — the whole flow, for tests and for a look. Its runs go to `<log folder>\benchmark`
unless `-Out` is given — never into the game's list, where mock runs under a real model id would
read as that model's (score 0) and, at another effort than the live run, would stay as a row
of their own.

### 18.6 Submitting — `tools/bench/submit_runs.ps1`

`[-Model id] [-Push] [-VerifyLocally] [-SkipBots] [-NoDispatch] [-Board <clone>] [-Runs <dir>]`:
pulls the leaderboard clone (default `..\doomsday-leaderboard`; it must be clean), copies the model
runs from `%APPDATA%\Doomsday\benchmark\runs` into its `runs\` (bot and mock runs left out —
`-IncludeMock` is for tests), runs its own `tools/validate.py --all` (`uv run --no-project
python`, else `python`; neither on `PATH` → exit 1 — the check fails closed), and shows what
would be committed. **Without `-Push` it takes the copies back** — a dry
run leaves the clone as it was. With `-Push` it commits the runs and pushes them to `main` of the
public repository (the owner's direct push, instead of §16.2's pull request), then either:

- **(default) dispatches the private workflow** `leaderboard.yml` with `gh workflow run` (or says
  how to start it by hand). It verifies and publishes **only when the secret
  `LEADERBOARD_DEPLOY_KEY` exists** (§16.5); without it a dispatch is a read-only dry run and the
  runs wait. `-NoDispatch` leaves them to the daily run.
- **`-VerifyLocally`** — new, because the deploy key does not exist yet: this machine does the
  workflow's work — the bot reference rows (`bench_run.gd --bots --suite=standard --if-missing
  --no-rebuild`, ≈ 3 minutes; `-SkipBots` leaves them out), the verifier (`verify_runs.gd
  --board=<clone> --game-commit=<HEAD> --message=<file>`, with a scratch `APPDATA`), then commits
  `runs verified leaderboard.json LEADERBOARD.md` with the verifier's message and pushes. It warns
  when the game checkout is not `origin/main` or `data/` has uncommitted changes — the verdicts
  are only as good as the checkout. The user's own GitHub credentials push; no deploy key is
  involved. **With nothing new to copy** it still verifies and publishes whatever runs on the
  board have no record yet — runs pushed earlier with a plain `-Push`.

**A refused push** (`Publish-BenchBoard`, `bench_common.ps1`): one `pull --rebase`, then once more.
A rebase that stops on a conflict is **aborted** — nothing is pushed, the clone is left on its own
commits, not mid-rebase (exit 1). After a clean rebase `-VerifyLocally` verifies again, so the
published board is built on the new base. **Local commits** that never reached origin (a failed
verification, a refused push) are pushed by the next `-Push`; without it the script says how many
there are.

### 18.7 Tests

`test_bench_effort` (levels, what they send, params ids, labels in both languages),
`test_model_catalogue` (the fixture `tests/fixtures/bench/openrouter_models.json`: parsing, free,
reasoning, estimates per level, filters, `model_list.gd`'s arguments and JSON line), additions to
`test_bench_entry` (round trip, old entries, bad values), `test_bench_verifier` (effort ≠ params),
`test_bench_score` (row key, Effort column), `test_global_board`, `test_bench_run` (an ultra run is
its own row and verifies; bad arguments; `--no-rebuild`), `test_benchmark_list` and
`test_spectator` (the lines), and `test_bench_scripts` (every `tools/bench/*.ps1` parses — where
PowerShell exists; CI's Linux container has none). **`tools/bench/smoke_scripts.ps1`** (by hand,
≈ 2 min): parses the scripts, `models.ps1` on the fixture, `run_models.ps1 -Mock` (two models,
effort high, quick, `-Parallel 2`, into the log folder), `fixture/ponder` at ultra in two
processes (one `params_id`, the plan's reasoning), the default-reasoning warning, the 0.00-cap
refusal and a free model under `-MaxTotal 0`, then a bare clone of the leaderboard repository as
a stand-in origin and `submit_runs.ps1` against a clone of it — without uv or python on `PATH`
(refused, nothing changed), dry run (clone unchanged), `-Push -VerifyLocally -SkipBots` (the
stand-in receives the runs, six verified records and rows with `"effort": "high"`), runs pushed
with a plain `-Push` verified by a later `-Push -VerifyLocally`, and `Publish-BenchBoard` after
someone else's push (a conflicting rebase aborted, a clean one rebuilt and published). No model
is asked, no key used. The fixture list has `fixture/deep` (reasons by default at `xhigh`).

### 18.8 Strings (en/de)

`UI_BENCH_EFFORT` (`{effort}`) *Effort: {effort}* / *Aufwand: {effort}* — a caption under every
row of the list (global, other versions, recorded runs) and a caption in the spectator strip after
the seed; `BENCH_EFFORT_NORMAL` / `_HIGH` / `_ULTRA` *Normal / High / Ultra* — *Normal / Hoch /
Ultra* (the user's words); `BENCH_EFFORT_NONE` *—* (bots, decision models, a board from before the
levels); `BENCH_EFFORT_RAW` (`{reasoning}`) *reasoning {reasoning}* / *Reasoning {reasoning}* (a
`--reasoning` run; *Reasoning* stays English, `plain-language.md` §10). `UI_A11Y_SPECTATOR` gains `{effort}` (*…, effort: {effort}, …* / *…, Aufwand: {effort},
…*).

### 18.9 Running your own models — the guide

Everything from `F:\Doomsday` in PowerShell. Nothing here costs money until step 4.

1. **Keys, once** (a dialog; stored for your Windows user; open a new window afterwards):
   `powershell -ExecutionPolicy Bypass -File tools\bench\set_api_key.ps1 -Name OPENROUTER_API_KEY`
   (and `-Name TYPESAFE_API_KEY` for Jev).
2. **Choose models:** `powershell -ExecutionPolicy Bypass -File tools\bench\models.ps1 -Search claude`
   (or `-Free`, or `-MaxCost 5 -Effort high`). The columns are the likely cost of a whole suite.
   A model marked `default` or `always` reasons even at *normal*, where its 1 200-token limit may
   cut its answers short (still billed) — prefer `-Effort high` for it; `run_models.ps1` warns.
3. **Look first, free:** `powershell -ExecutionPolicy Bypass -File tools\bench\run_models.ps1
   -Models <id> -Effort high -Suite quick -Mock -Yes` plays the whole flow with a mock (no key,
   no cost); its runs go to a scratch folder (the log folder it prints), not into the game.
4. **Play:** `powershell -ExecutionPolicy Bypass -File tools\bench\run_models.ps1 -Models
   <id>,<id> -Effort high -Suite quick` — read the estimate, answer `y`. The ranked suite is
   `-Suite standard` (10 seeds); `-Parallel 5` plays five seeds at once; `-MaxTotal 20` refuses a
   batch likely above 20 USD. The runs appear in the game: title → *Benchmark* → *Recorded runs* →
   *Watch*.
5. **Publish:** `powershell -ExecutionPolicy Bypass -File tools\bench\submit_runs.ps1` (a dry run:
   validated, nothing committed), then `… submit_runs.ps1 -Push -VerifyLocally` (verified on this
   PC and published — standard-suite rows rank; quick rows are listed as practice). With the deploy
   key set up (§16.5) `-Push` alone lets GitHub verify them. Runs already pushed with a plain
   `-Push` (no deploy key: the workflow only dry-runs) are published by running `… submit_runs.ps1
   -Push -VerifyLocally` again — it verifies whatever on the board has no record yet.

### 18.10 Decisions (pending user confirmation)

The three levels as in §18.1 (ultra = the model's highest listed effort, max over xhigh over
high); the limits 16 000 / 32 000 tokens and the timeouts 600 / 900 s; the estimate's 3 000 /
8 000 output tokens a call (a guess until the first live runs — to be corrected from their
`tokens_out`); refusing high and ultra for a model the list names without reasoning; normal writes
no `effort` (older entries and boards stay byte-identical); `--reasoning` kept as the low-level
form, exclusive with `--effort`; run_models' caps `max(1, likely × 1.5)` per model;
`submit_runs.ps1` pushes to the public `main` directly (the owner) and `-VerifyLocally` stands in
for the missing deploy key. From the S6.12d review (2026-09-27): a level never sends less than
the model's default effort when it reasons by default (high may then equal ultra's effort);
normal stays parameter-free and only warns for such models, whose normal estimate counts the
whole 1 200-token limit as output; what a level sends is resolved once per batch and a live run
without the list stops rather than guessing; the verifier checks the params against the level;
`--reasoning` runs are shown as *reasoning <value>*; a free model plays under a cap of 0;
`-Mock` runs stay out of the game's list.
