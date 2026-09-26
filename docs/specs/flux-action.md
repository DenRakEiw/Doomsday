# FLUX 3 Action track — data contract, recorder, control bridge, training plan

**Status: cut from the plan on 2026-09-26 (user decision). Kept for reference; nothing in it is scheduled.**

D7.F (2026-09-25). The user's decision (2026-09-25): prepare everything so that Black Forest Labs'
**FLUX 3 Action** can be trained to play Doomsday, and later play it, on the user's RTX 5090
(32 GB). A separate research track after the itch.io browser release, and a **separate leaderboard
category ("trained agents")** beside the zero-shot chat-model benchmark of `benchmark.md`.

Builds from it: **S7.F1** (contract, actuator, capture, clock), **S7.F2** (puppeteer, recorder,
replay checks), **S7.F3** (converter, dataset stats, trainer plug, training configs), **S7.F4**
(control bridge, Python driver, mock policies), **S7.F5** (the leaderboard category). User steps
(recording, training, evaluation) are §9 and §11.6.

Sources read on 2026-09-25 (cited as [card], [guide], [setup], [emb], [lora], [games], [cfg],
[licence]):
[card] huggingface.co/black-forest-labs/flux-3-action-base ·
[guide] docs.bfl.ai/flux_3/flux3_action_finetuning ·
[setup] github.com/black-forest-labs/flux-action `docs/setup.md` ·
[emb] same repo `docs/embodiments.md` · [lora] `docs/so101-lora.md` ·
[games] `examples/games/README.md` + `examples/games/dataset.py` · [cfg] `configs/games/train.json`
and `src/flux_action/config.py`, `models/wiring.py` · [licence] the base repository's `LICENSE.md`.

---

## 0. What this spec decides

1. **The game is the environment; the pixels and the pointer are the only interface.** The model
   sees one 512×288 RGB frame of the real session and moves a pointer: absolute x/y, one button, a
   vertical and a horizontal wheel — **D = 5** (§3.3). No keys, no game-state vector: everything a
   player does in a run has a pointer route (dock, top bar, modal buttons), and a model that reads
   numbers from a side channel would be a different category.
2. **One contract file** `tools/flux/contract.json`, read by GDScript and Python alike; its SHA-256
   is the contract's identity in every run, dataset, head and leaderboard entry (§3).
3. **Fixed step, 15 Hz, lockstep.** The game runs with `--fixed-fps 15`, and the environment owns
   the simulation clock (`Game.external_clock`, §4.1): frame *t* is observed, action *t* is applied,
   the clock advances exactly 1/15 s. Recording and play are deterministic and replayable whatever
   the inference speed. The run's speed is **2×** (a day is exactly 15 frames).
4. **Recording and play share one environment** (`FluxEnv`, §4.5): the same profile, reset,
   actuator, input guard, clock and capture. The recorder's agent is the **puppeteer** (bots →
   human-like pointer routines, §5); the bridge's agent is a remote driver (§8). What differs
   between them is only who chooses the action.
5. **The puppeteer drives the real UI and nothing else.** It reads the scene to find where to
   point, but it acts only by `FluxAction`s through the actuator — never a method call on a UI
   node, never `Game.apply`. Each bot command becomes one routine whose result is checked against
   the command log (§5.6), and every recorded run passes an **action-only replay** (the recorded
   actions, and nothing else, reproduce the run's command log and frames, §6.5).
6. **Episodes of 240 frames (16 s at 15 Hz)**, cut consecutively from long runs; the state at an
   episode's first frame is the true previous action (stored as `prev_action`), not zero (§3.6).
   Idle episodes are capped at 25 % of the dataset (§7.2). **Training seeds never touch a
   benchmark suite** (2001–2007; the converter refuses benchmark seeds, §7.2).
7. **Target: ≥ 800 training episodes** (the published game recipe's count); the plan records
   **42 runs** (6 bots × 7 seeds) ≈ 590 k frames ≈ 2 400 episodes before filtering; ≈ 3–7 hours in
   one process, 35–120 GB of frames (§6.6).
8. **Python lives in `tools/flux/py/`** (uv, Python 3.12, wheels only, `.gdignore`d); the
   converter and the driver's protocol need only numpy and Pillow. Training and inference run in
   **BFL's own `flux-action` environment on Linux** — on the user's PC that is **WSL2** with
   mirrored networking (§8.6).
9. **The bridge is a local TCP server in the game, bound to `127.0.0.1` only**, debug builds
   only, in `tools/` (never exported); one client, fixed binary messages, size caps, no paths or
   code from the socket (§8).
10. **The RTX 5090 verdict** (§9.3): inference fits (estimate); the documented 4-update test and the
    documented recipe (FP32 weights, trunk unfrozen after update 200) do **not** fit in 32 GB; a
    **trunk-frozen, heads-only** variant in BF16 with activation checkpointing and batch 1 ×
    accumulation is the local path (estimate — the local smoke test decides). The full recipe runs
    on **8×H200 rented, ≈ 100–300 USD per training run** (estimate, §9.4).
11. **Leaderboard:** a run played through the bridge is an ordinary benchmark entry (commands,
    replay-verified) with `category: "trained"` and an `agent` block (base model, export hash,
    dataset hash, contract hash, caption). It ranks in its own table; the in-game list shows the
    category only once the user has answered the licence question (§10, §13).
12. **Nothing FLUX-related ships** in any exported build: all code is under `tools/flux/`, which
    every export excludes (release.md §6.2); `main.gd` loads it by path only in debug builds.

**Not in scope:** training or evaluating anything in CI; an in-game "watch the model play live"
mode; keyboard or gamepad actions; a game-state vector (recorded in `meta.jsonl` for a later
ablation, never fed in v1); title, setup and results screens in episodes (the environment resets
straight into the session and stops at `run_ended`); German-locale episodes; data augmentation;
LoRA through LeRobot (named as fallback B, §9.3, not built); shipping weights; any change to
BFL's code.

---

## 1. Facts and estimates

Everything below the line **"estimate"** in a table is this spec's judgement, not a documented
number. The smoke test of §9.2 replaces the memory estimates with measurements.

### 1.1 Documented

| Fact | Source |
| --- | --- |
| 7B open-weights "world action model"; inputs camera frames + state + text; outputs "the next chunk of actions, denoised together with the next video frames" | [card] |
| Base repo: `flux-3-action-base.safetensors` (trunk; "video and text streams, a shared action trunk, and ee50/gaming action heads"), `video_vae.safetensors`, `text_encoder/` = Qwen3-VL-4B-Instruct (Apache-2.0) | [card] |
| "New embodiments require their own action heads": `emb_in.<modality>`, `emb_in.<modality>_cond`, `final_layer.<modality>(_cond)` are **fresh, sized to your channels**; the modality's mode blocks are initialised from the co-trained `action_prediction` branch; everything else loads as is | [card], [cfg] `wiring.py` |
| Episode NPZ: `frames (T,H,W,3) uint8`, `action (T,D) float32`; `index.json` with `length`, `action_dim`, `episodes[{file}]`; ≥ 33 frames; uniform length per root. The game loader also reads `frames_png` + `frames_off` (lossless PNG per frame, "about 2.6× smaller") and a per-episode `task` caption | [guide], [games] |
| Window = 33 frames, 32 actions; state = "last executed action; zero at the first frame of an episode" | [guide], [games] |
| Games: 15 Hz, 800 episodes of 16 s per game, one RGB frame recorded at 256×256 onto a 512×512 canvas, `camera_layout "single"`, D = 4 (VECTOR padded with a mask), caption per game | [guide], [games] |
| Game config: `action_modality "game"`, `canvas_hw [512,512]` (any `[h,w]`, multiples of 32), `chunk_size 32`, `n_action_steps 8`, `fps 15`, `action_scale 2.0`, `caption_dropout 0`, `augment false`, lr 5e-5 (heads × 5), `num_inference_steps 1`, `single_frame_encode true`, steps 3000, phases frozen 200 / trunk warm-up 600 / heads warm-up 200, cool-down from 2600 over 400, `windows_per_rank 4`, `param_dtype float32`, `compute_dtype bfloat16`, `activation_checkpointing true` | [cfg] |
| Reference hardware: 7×H200, global batch 126, 2 000 updates ≈ 5 h; 32×H200 (4 nodes), batch 128, 3 000 updates ≈ 1 h 45 | [guide] |
| 4-update test: `torchrun … train --override steps=4 … frozen_steps=0 trunk_warmup_steps=1 heads_warmup_steps=1 cooldown_start=null` | [guide] |
| "Fix action order, units, camera layout, and control rate before recording" | [guide] |
| Export: FP32 training weights → BF16 (`flux-action export-checkpoint --dtype bfloat16`); inference `FluxActionPolicy.from_pretrained(export, device="cuda")`, `prepare_inference()` (irreversible), `predict_action_chunk` → `(1, 32, D)` | [games], [setup] |
| Eager inference is reproducible; `--compile-dit` runs differ between processes; `--offload-text-encoder` keeps the text encoder on the CPU between caption misses | [setup] |
| Setup: **Linux required**, CUDA 12.8, Python 3.12, torch 2.10.0+cu128, NATTEN 0.21.6 wheels, installed with `uv sync --locked --extra encoders --extra data` | [setup] |
| Single-GPU path documented only for **SO-101 LoRA via LeRobot**: rank/alpha 32, BF16, activation checkpointing, batch 2 × accumulation 4, policy/VAE/text encoder frozen; GPU memory not stated | [lora] |
| Action normalisation per channel optional (`action_normalization` q01/q99, `None` = identity); `action_parameterization "absolute"` default | [cfg] `config.py` |

### 1.2 Licence (FLUX Kommunity License v1.0 — weights; not legal advice)

The repository code (`flux-action`) is **Apache-2.0**, the text encoder **Apache-2.0**, the weights
(base trunk, VAE) the **FLUX Kommunity License v1.0** [licence]:

- **Allowed without asking:** use, fine-tune and evaluate for a *Non-Commercial Purpose* — personal
  research and hobby use "not directly or indirectly connected to any commercial activities", and
  "use by commercial or for-profit entities for testing, evaluation, or non-commercial research and
  development in a non-production environment" (§1.c). Recording data, training a head and running
  the benchmark on the developer's machine fall here.
- **Not a Non-Commercial Purpose:** "(a) revenue-generating activity (including … a production
  environment), (b) direct interactions with or … impact on end users, or (c) to train, fine tune,
  or distill other models for commercial use" (§1.c). Shipping the model, a head, or live model
  play in the sold game is this — it needs a separate licence from BFL (§2.b).
- **Outputs** (explicitly including "action-prediction outputs") are not Derivatives; BFL claims
  no ownership (§2.d). **Only a Qualifying User** (with affiliates, gross annualised revenue
  < US$5 M, §1.e) may use Outputs commercially (§2.a(ii)), and must then keep content filtering or
  review of Outputs before display and disclose AI generation where the law requires it (§2.e).
  A FLUX-played run shown in the sold game (a command log replayed in the spectator view, a row
  in the in-game list) is a commercial use of Outputs → **only as a Qualifying User**, labelled as
  AI-played, reviewed (the verifier and the fixed game content are the review).
- **Distributing a fine-tuned head** (a Derivative) is allowed for non-commercial purposes with a
  copy of the licence, the Attribution Notice plus a statement that it was modified, and no
  implication of BFL endorsement (§3).
- **Restrictions** (§4): no military or surveillance purposes, no biometric processing, and no use
  of Outputs "to improve any other artificial intelligence model that performs any function similar
  to a FLUX Model or Derivative" — so FLUX-played runs never become training data for another model.
- *Robotics Uses* (production physical systems) are separately restricted; a pointer in a video
  game is not a physical system.

**Consequence here:** everything in this track stays in `tools/` and on the developer's machine;
FLUX entries reach the public leaderboard only as command logs with claims (like chat-model runs);
the in-game list shows the trained category only after the user confirms Qualifying-User status
(§13 Q2).

### 1.3 Estimates (this spec's)

| Estimate | Value | Reasoning |
| --- | --- | --- |
| BF16 DiT weights | ≈ 14 GB | 7 B × 2 bytes |
| FP32 weights + grads + Adam | ≈ 112 GB | 7 B × 16 bytes, before activations |
| Text encoder BF16 | ≈ 8–9 GB | 4 B × 2 bytes |
| H200 cost per training window | ≈ 0.5 GPU-s at 512×512 | both documented configurations: 35 GPU-h / (2 000 × 126), 56 GPU-h / (3 000 × 128) |
| Same at 288×512 | ≈ 0.3–0.4 GPU-s | 56 % of the pixels; attention is not all of the cost |
| RTX 5090 vs H200 (BF16 dense) | ≈ 0.5–0.6× | public spec sheets; no FLUX measurement exists |
| H200 rental, on demand, 2026 | ≈ 2.5–4.5 USD per GPU-hour | provider list prices vary; spot is lower |

---

## 2. Files

All GDScript under `tools/flux/` is **preloaded, no `class_name`** (CLAUDE.md: none on tools),
never exported, and never named by anything outside `tools/` and `tests/` except `game/main.gd`'s
path strings (§4.6).

| File | S | What |
| --- | --- | --- |
| `tools/flux/contract.json` | 7.F1 | the data contract (§3) — its values are written here |
| `tools/flux/flux_contract.gd` | 7.F1 | loads and validates the contract; its SHA-256 |
| `tools/flux/flux_action.gd` | 7.F1 | one action vector; normalisation; sanitising |
| `tools/flux/flux_input.gd` | 7.F1 | the actuator: action transitions → `InputEvent`s pushed into the viewport |
| `tools/flux/input_guard.gd` | 7.F1 | drops every input event not stamped by the actuator |
| `tools/flux/flux_frame.gd` | 7.F1 | capture: viewport → 512×288 RGB8, cursor glyph composed, digest |
| `tools/flux/flux_env.gd` | 7.F1 | the environment node: profile, reset, step, capture, end (§4.5) |
| `tools/flux/flux_caption.gd` | 7.F1 | the caption for a setup and a plan (§3.5) |
| `game/autoload/game.gd` | 7.F1 | **amended:** `external_clock`, `step_clock(delta)` (§4.1) |
| `game/main.gd` | 7.F1 | **amended:** `--record-episodes` / `--flux-bridge` dispatch (§4.6) |
| `tools/flux/pointer_path.gd` | 7.F2 | human-like pointer timing and paths (§5.2) |
| `tools/flux/ui_probe.gd` | 7.F2 | read-only lookups of where things are on screen (§5.3) |
| `tools/flux/puppeteer.gd` | 7.F2 | bot commands → routines → one `FluxAction` per frame (§5) |
| `tools/flux/run_writer.gd` | 7.F2 | one run directory: frames, actions, meta, run.json (§6.4) |
| `tools/flux/action_file_agent.gd` | 7.F2 | plays a recorded `actions.f32` back (the action-only replay, §6.5) |
| `tools/flux/flux_recorder.gd` | 7.F2 | the `--record-episodes` node (§6) |
| `tools/flux/py/.gdignore` · `pyproject.toml` · `uv.lock` · `README.md` | 7.F3 | the Python project (§7.1); `.gdignore` keeps Godot out of it and its `.venv` |
| `tools/flux/py/doomsday_flux/contract.py` | 7.F3 | reads `../../contract.json` |
| `tools/flux/py/doomsday_flux/convert.py` · `stats.py` · `cli.py` | 7.F3 | runs → episodes, index, manifest, stats (§7) |
| `tools/flux/py/doomsday_flux/train_plug.py` | 7.F3 | the trainer's dataset hook `build(config, **kwargs)` (§7.5) |
| `tools/flux/py/configs/doomsday_h200.json` · `doomsday_5090_smoke.json` · `doomsday_5090_heads.json` | 7.F3 | training configurations (§9) |
| `tools/flux/py/tests/test_convert.py` · `test_contract.py` · `test_train_plug.py` | 7.F3 | stdlib `unittest` |
| `tools/flux/bridge_protocol.gd` | 7.F4 | message encoding and parsing (§8.2) |
| `tools/flux/flux_bridge.gd` | 7.F4 | the `--flux-bridge` node (§8) |
| `tools/flux/py/doomsday_flux/protocol.py` · `drive.py` · `mock_policies.py` · `flux_agent.py` | 7.F4 | the driver (§8.5) |
| `tools/flux/py/tests/test_protocol.py` · `test_drive.py` | 7.F4 | stdlib `unittest` |
| `game/bench/bench_entry.gd` · `tools/bench/bench_verifier.gd` · `leaderboard_writer.gd` · `ui/modals/benchmark.gd` · `data/benchmark.json` · `data/loc/strings.csv` | 7.F5 | the category (§10) |
| `.gitignore` | 7.F3 | gains `/tools/flux/py/.venv/` |

Output directories are **outside the repository** (`--out` is required; the README suggests
`F:/doomsday-flux/`).

---

## 3. The data contract (`tools/flux/contract.json`)

```json
{
	"_comment": "docs/specs/flux-action.md §3. Changing any value is a new contract version.",
	"version": 1,
	"fps": 15,
	"game_speed": 2,
	"logical_size": [1920, 1080],
	"window_size": [1280, 720],
	"frame_size": [512, 288],
	"canvas_hw": [288, 512],
	"camera_key": "images.game",
	"action_dim": 5,
	"dims": ["pointer_x", "pointer_y", "button", "wheel_y", "wheel_x"],
	"button_threshold": 0.0,
	"wheel_threshold": 0.5,
	"episode_frames": 240,
	"warmup_frames": 6,
	"frame_cap": 60000,
	"idle_share_max": 0.25,
	"profile": {"locale": "en", "text_scale": 1.0, "tutorial": false, "hints": false,
		"reduced_motion": true, "screen_effects": "off", "pseudo_locale": false, "bench_online": false},
	"caption": "play the strategy game Doomsday as the {architecture}: spread, stay unseen, reach an ending. plan: {plan}",
	"plans": {"cyber": "cyber", "biology": "biology", "robotics": "robotics", "weapons": "weapons",
		"persuasion": "persuasion", "greedy": "cheapest first"},
	"train_seeds": [2001, 2006],
	"val_seeds": [2007, 2007]
}
```

`FluxContract.load_file()` validates: every key present and typed; `fps` > 0; `frame_size` and
`canvas_hw` describe the same picture (`canvas_hw == [frame_size.y, frame_size.x]`) and are
multiples of 32; `action_dim == dims.size() == 5`; `window_size.x ≥ UiTokens.COMPACT_WIDTH` (the
full layout, not the compact one); `episode_frames ≥ 33`; the train and val seed ranges are
disjoint from every suite in `data/benchmark.json`. Errors are returned as `errors: Array[String]`,
never a crash. **`sha256`** = hex SHA-256 of the file's bytes — the contract's identity.

### 3.1 The frame

- The game renders its usual logical 1920×1080 layout (`canvas_items` stretch) in a **1280×720
  window** (≥ the 1 100 px compact breakpoint, so the full layout; fits any desktop monitor).
- **Capture** = the root viewport's texture after the frame is drawn (`frame_post_draw`) → RGB8 →
  resized to **512×288** (`Image.INTERPOLATE_LANCZOS`) → the **cursor glyph** drawn on top (§4.4).
  The canvas is `canvas_hw [288, 512]` with `camera_layout "single"`: no resize, no letterbox, no
  distortion.
- **Why not 256×256 like the published games:** at 256 px a 16:9 interface loses a third of its
  width to letterboxing and every button shrinks to a few pixels; 512×288 keeps buttons, markers
  and the map's colours distinct at 56 % of the 512×512 canvas's pixels. **Text is not legible**
  at this size (body text ≈ 4 px) — the model reads layout, colour and state, not numbers.
- **A larger variant** (`frame_size [1024, 576]`) is contract v2, not built: runs are
  deterministic, so frames can be re-rendered from a run's actions (§6.5) without re-recording.

### 3.2 Timing and alignment

- `--fixed-fps 15`: every engine frame is exactly 1/15 s of game time, and the engine runs as fast
  as it can (no real-time sync). The environment advances the simulation clock itself by 1/15 s per
  frame (§4.1); at **2×** a day is exactly 15 frames.
- Frame index *t* counts engine frames after reset and warm-up. **`obs[t]`** is drawn at the end of
  engine frame *t*. **`action[t]`** is applied at the start of engine frame *t + 1*, before the clock
  step; its effect is first visible in `obs[t + 1]`. **`state[t]`** = `action[t − 1]` (the
  executed, sanitised one). This is [guide]'s window: frames `s…s+32`, actions `s…s+31`, state at
  `s`.

### 3.3 The action vector (D = 5)

| # | Name | Range | Meaning, applied by the actuator (§4.3) |
| --- | --- | --- | --- |
| 0 | `pointer_x` | [−1, 1] | absolute pointer position, **−1 = left edge, +1 = right edge** of the logical viewport: `px = (x + 1) / 2 × 1920` |
| 1 | `pointer_y` | [−1, 1] | **−1 = top, +1 = bottom**: `py = (y + 1) / 2 × 1080` |
| 2 | `button` | [−1, 1] | the primary button is **held while > 0** (`button_threshold`); a rise is a press, a fall a release, at the pointer's position |
| 3 | `wheel_y` | [−1, 1] | ≥ +0.5: one notch **up** (map zooms in, lists scroll up); ≤ −0.5: one notch down; at most one notch per frame |
| 4 | `wheel_x` | [−1, 1] | ≥ +0.5: one notch **right**; ≤ −0.5: one notch left (the tree board scrolls sideways) |

- **Absolute, not relative, pointer:** the head predicts where to point on the frame it sees — the
  analogue of absolute joint targets ([cfg] `action_parameterization "absolute"`). No integration
  drift, and a chunk that is replanned lands where it should.
- **Recorded values are exact:** the puppeteer writes `button` as −1 or +1 and wheels as −1, 0 or
  +1; the model's continuous outputs are thresholded by the actuator. **Normalisation: identity**
  (`action_normalization: null`) — every channel is already in [−1, 1].
- **Sanitising** (both modes): a non-finite value becomes the previous executed value for 0–1, −1
  for 2, 0 for 3–4; everything is clamped to [−1, 1]; pixels are clamped to `[0, size − 1]`.
- **Why no keys:** every action the session offers has a pointer route (dock buttons for tree,
  abilities, containment and analysis; the top bar's pause and speed; every modal and panel has a
  close or continue button), `Escape` with nothing open opens the pause menu (a trap a model would
  find), and each extra channel is one more thing to learn. S7.F2 checks the claim route by route;
  a routine that has none is a `# DESIGN?` entry, not a key.
- **Why a horizontal wheel:** the tech board scrolls both ways (`BoardScroll`), and a pointer-only
  horizontal scroll would otherwise mean dragging a scroll bar.

### 3.4 State

**The last executed action** (5 floats), as documented — no compute, day or phase. Those are
written per frame into `meta.jsonl` (§6.4) so an ablation can add them later without re-recording;
v1 does not. Reason: the category is "plays from the screen", and a side channel of numbers the
player reads from the HUD would make it a different one.

### 3.5 The caption (per episode, from the game's own words)

`FluxCaption.for_run(setup: RunSetup, plan: String, contract) -> String`: `caption` with
`{architecture}` = `tr("ARCH_<ID>_NAME")` in `en` (e.g. *Language Model*) and `{plan}` =
`plans[plan]`. Example: *play the strategy game Doomsday as the Language Model: spread, stay unseen,
reach an ending. plan: cyber*. The caption is **not player-visible** (a training artefact, English
only, never in `strings.csv`); it is outcome language (content rule). The plan names the bot's
branch because the model's only memory is one frame and the last action: without it, demonstrations
of five strategies would average into none. At evaluation the plan is a parameter of the entry
(§10.1).

### 3.6 Episodes

- A run of *N* recorded frames is cut into ⌊*N* / 240⌋ consecutive, non-overlapping episodes of
  **240 frames** (16 s); the rest is dropped.
- Each episode stores **`prev_action`** — the action executed before its first frame (zeros with
  `button −1` for a run's first episode, which is also what the environment's reset produces: the
  pointer at the centre, nothing held). The trainer plug uses it as the state at window start 0,
  instead of [guide]'s zero, because a cut episode's first frame has a real previous action.
- An episode is **active** when any of its frames has a button edge or a wheel notch; otherwise
  **idle** (§7.2).

### 3.7 The recording profile

Applied in memory, never written (release.md §8's `isolate()`: `Settings.persist = false`, volumes
0, profile and saves redirected): `profile` above, plus `Settings.bench_online` off. `tutorial` and
`hints` off keep coach cards out of the frame; `reduced_motion` cuts camera and panel tweens;
screen effects off. The same profile in play mode is part of the contract — a model trained
without screen effects is evaluated without them.

---

## 4. Shared runtime (S7.F1)

### 4.1 The external clock (`game.gd`, amended)

```gdscript
## When true, `_process` does not advance the run; the owner calls `step_clock` once per frame.
## flux-action.md §4.1: the recorder and the bridge own time, so a run is the same run at any
## frame rate and in a test.
var external_clock: bool = false

## `_process`'s body: the accumulator step at the current speed, then `advance`.
func step_clock(delta: float) -> void
```

`_process(delta)` becomes `if not external_clock: step_clock(delta)`. Nothing else changes; the
existing clock tests keep passing. `stop_run` leaves `external_clock` as its owner set it.

### 4.2 `FluxAction` (`flux_action.gd`)

```gdscript
extends RefCounted
var x: float = 0.0
var y: float = 0.0
var button: float = -1.0
var wheel_y: float = 0.0
var wheel_x: float = 0.0
static func neutral() -> FluxAction                                    # centre, released, no wheel
static func from_array(values: PackedFloat32Array, previous: FluxAction) -> FluxAction   # sanitised (§3.3); wrong length → previous with button −1
func to_array() -> PackedFloat32Array
func is_held(threshold: float) -> bool
func logical_point(logical: Vector2i) -> Vector2                       # clamped to the viewport
static func at_logical(point: Vector2, logical: Vector2i, held: bool) -> FluxAction
```

(`FluxAction` in signatures means the preloaded script constant, as in `tools/bench/`.)

### 4.3 The actuator (`flux_input.gd`) and the guard (`input_guard.gd`)

```gdscript
extends RefCounted
## Every event the actuator makes carries this device id; the guard drops all others.
const DEVICE: int = 7151
var executed: FluxAction                                             # the last applied action
func _init(p_contract: FluxContract) -> void
func reset(at: FluxAction) -> void
## The events that turn `previous` into `current`, in logical pixels: a motion when the point moved
## (button mask set while held, relative = the move), then a press or release on a threshold
## crossing, then one wheel notch per axis (press + release, factor 1.0) at the point. Pure.
static func events_for(previous: FluxAction, current: FluxAction, contract: FluxContract) -> Array[InputEvent]
## Sanitises, pushes `events_for` into `viewport` (positions through `get_final_transform()`,
## as the click tests do), stores and returns the executed action.
func apply(current: FluxAction, viewport: Viewport) -> FluxAction
```

**The guard** is a `Node` added as the **last child of the root** (so its `_input` runs first) that
marks every event whose `device != FluxInput.DEVICE` as handled — the player's own mouse, keyboard
and pads never reach a recorded or played run. The environment also sets the window flags
`WINDOW_FLAG_NO_FOCUS` and `WINDOW_FLAG_MOUSE_PASSTHROUGH` so the OS sends it nothing. If
passthrough stops pushed motion from hovering controls (S7.F1 checks it with the click tests), the
flag is dropped and the guard alone stays — recorded in PROGRESS. Polled input (the arrow and
right-stick pan in `MapCamera`) cannot be guarded: the environment **refuses to start while a
joypad is connected** (`Input.get_connected_joypads()`, override `--allow-pads`), and the window has
no focus, so no key reaches it. The action-only replay (§6.5) catches anything that still leaks.

### 4.4 Capture (`flux_frame.gd`)

```gdscript
extends RefCounted
static func capture(viewport: Viewport, contract: FluxContract, cursor: FluxAction) -> Image   # RGB8, frame_size
static func compose_cursor(image: Image, cursor: FluxAction, contract: FluxContract) -> void
static func rgb_bytes(image: Image) -> PackedByteArray                                        # H×W×3, row-major
static func digest(image: Image) -> String                                                    # first 16 hex of SHA-256 of rgb_bytes
```

**The cursor glyph** (the OS cursor is not in the viewport texture, and the model must see where it
points): an arrow 8×12 frame pixels, hotspot at its tip on the pointer's frame pixel
`round((x + 1) / 2 × (512 − 1))`, `round((y + 1) / 2 × (288 − 1))`; **released**: white fill, 1 px
black outline; **held**: black fill, 1 px white outline. The bitmap is one `const` block in
`flux_frame.gd` (original work, nothing to license). Drawn in the frame, never in the game, so the
game's look is untouched and the Python side never draws.

### 4.5 The environment (`flux_env.gd`)

```gdscript
extends Node
## The agent: an object with `act(env) -> FluxAction` (called once per frame, before the clock
## step) and `observe(env, index: int, image: Image, digest: String) -> void` (after the frame is
## drawn). The puppeteer (§5), the action-file agent (§6.5) and the bridge (§8) are agents.
var agent: Object = null
var contract: FluxContract
var frame_index: int = -1               # −1 until frame 0 is captured
var executed: FluxAction                # state for the next observation
var capture_frames: bool = true         # false: logic only (tests, `--no-frames`)
var end_reason: String = ""             # "" running · "outcome" · "frame_cap" · "aborted"
func begin(seed_value: int, setup: RunSetup) -> String   # "" or a reason; see below
func is_over() -> bool
func summary() -> Dictionary            # outcome, day, days, end_day, hash, commands (Command.to_dict list), frames
```

- **Setup, once:** `SmokeRun.isolate()` (release.md §8), the profile (§3.7), the window size and
  flags, the guard, `Game.external_clock = true`, `process_priority = -1000` (its `_process` runs
  before every other node's), `RenderingServer.frame_post_draw` connected.
- **`begin`:** `Game.stop_run()`; `setup.validate(db)` (a reason is returned); `ScreenRouter
  .start_new_run(setup, seed)` (the title's own path); the actuator reset to `neutral()`;
  `warmup_frames` (6) frames stepped with the neutral action and not observed; then frame 0.
- **Per engine frame (`_process`):** unless over — `executed = actuator.apply(agent.act(self),
  get_viewport())`, then `Game.step_clock(1.0 / fps)`.
- **After drawing (`frame_post_draw`):** `frame_index += 1`; with `capture_frames`,
  `FluxFrame.capture` (cursor = `executed`); `agent.observe(…)`. Then the end checks: `run_ended`
  was emitted → `end_reason = "outcome"`; `frame_index + 1 == frame_cap` → `"frame_cap"`. An ended
  run takes no further action and captures nothing more.
- **The environment's one rule about speed:** when a `ChooseOriginCommand` is applied
  (`EventBus.command_applied`), `Game.set_speed(game_speed)` (2) — the session would set 1×. After
  that the speed is the UI's: the pause and speed buttons work for any agent as for a player.
- A run is a **player run** (`Game.policy == null`): wire cards, the discovery modal and the
  origin hold appear exactly as for a person.

### 4.6 `main.gd` (amended)

```gdscript
const ARG_RECORD: String = "--record-episodes"
const ARG_BRIDGE: String = "--flux-bridge"
const FLUX_RECORDER: String = "res://tools/flux/flux_recorder.gd"
const FLUX_BRIDGE: String = "res://tools/flux/flux_bridge.gd"
const FLUX_MISSING: String = "flux: not available in this build"
```

In `_ready`, before the boot and only when `Game.debug_allowed`: either switch → `load(path)`
(not `preload`: an export has no `tools/`); a null script prints `FLUX_MISSING` and quits 1; else
the node is added in place of the boot, as `--smoke` does. A release build ignores both switches.

---

## 5. The puppeteer (S7.F2)

### 5.1 Principles

1. **Bots decide, the puppeteer only performs.** The bot is any `Policy.create(id)` with
   `setup(db, Policy.seed_for(seed))` — never `Game.policy`. The recording bots are
   `Policy.ids()` minus `idle`: `greedy`, `cyber`, `biology`, `robotics`, `weapons`,
   `persuasion` (plan = the bot id).
2. **Read the scene, write only pointer actions.** `UiProbe` may read rects, visibility, ids and
   the camera; the puppeteer never calls a UI method, never sets a property, never calls
   `Game.apply`. A test greps `puppeteer.gd` and `ui_probe.gd` for `.call(`, `emit`, `Game.apply`,
   `set_` on nodes — none allowed.
3. **Deterministic:** its randomness (reaction frames, aim jitter) comes from its own `SimRng`
   seeded `Policy.seed_for(seed) + 1`, never the world's and never the bot's.
4. **Human-like, not superhuman:** eased paths with Fitts-law durations, a reaction delay after
   something appears, a hover before a press, a press held two frames, a short wait after a click.

### 5.2 Pointer model (`pointer_path.gd`, pure)

```gdscript
extends RefCounted
const FITTS_A_S: float = 0.12        # seconds
const FITTS_B_S: float = 0.10        # seconds per bit
const MOVE_MIN_FRAMES: int = 3
const MOVE_MAX_FRAMES: int = 18
const REACT_MIN_FRAMES: int = 3      # after a surface appears, before moving to it
const REACT_MAX_FRAMES: int = 5
const HOVER_FRAMES: int = 2
const PRESS_FRAMES: int = 2
const SETTLE_FRAMES: int = 2         # after a release, before the next move
const WHEEL_GAP_FRAMES: int = 1      # a notch frame is followed by a frame without one
static func duration_frames(from: Vector2, to: Vector2, target_width: float, fps: int) -> int  # clamp(round((A + B·log2(d / w + 1)) · fps))
static func points(from: Vector2, to: Vector2, frames: int) -> PackedVector2Array               # minimum-jerk; last = to
static func aim(rect: Rect2, rng: SimRng) -> Vector2                                            # uniform in the rect's middle half
static func react_frames(rng: SimRng) -> int
```

A press never moves (the map's drag slop is 8 px; a click is press, hold, release on one point).

### 5.3 Where things are (`ui_probe.gd`, read-only)

```gdscript
extends RefCounted
func _init(p_session: Node) -> void
static func centre(control: Control) -> Vector2            # global rect centre, logical px
func rect(control: Control) -> Rect2                        # global rect, logical px; empty if hidden
func dock_button(destination: StringName) -> Control        # &"tree", &"abilities", &"containment", &"analysis"
func pause_button() -> Control                              # the top bar's pause/resume control
func tree_tab(tree: String) -> Control
func tree_card(node_id: String) -> Control                  # the card on the shown tab, or null
func tree_buy() -> Control
func tree_close() -> Control
func board_scroll() -> ScrollContainer
func region_panel_index() -> int                            # 0 when closed
func region_button(kind: StringName) -> Control             # &"site" (OriginButton), &"collect", &"dormancy", &"close"
func region_option(event_id: int, option_id: String) -> Control
func wire_event() -> int                                    # 0 when no wire card is up
func wire_option(option_id: String) -> Control
func wire_dismiss() -> Control                              # the card's continue after a result
func discovery_continue() -> Control
func ability_row(ability_id: String) -> Control
func region_point(index: int) -> Vector2                    # a point that picks `index` and is not under visible interface; (-1, -1) if none
func anomaly_point(anomaly_id: int) -> Vector2              # its marker, (-1, -1) if covered or off screen
func event_point(event_id: int) -> Vector2
func is_covered(point: Vector2) -> bool                     # a visible control of HudLayer/PanelLayer/ModalLayer/CoachLayer takes it
func region_screen_size(index: int) -> float                # the smaller side of the region's on-screen bounding box
```

`region_point` searches a spiral of points around the region's anchor (`MapCamera
.canvas_transform() * anchor`, step 6 px, radius ≤ 60 px) for one that `MapPicker` maps to the
region and `is_covered` does not — the same rule the anomaly click test uses for "reachable".
S7.F2 fills in the node paths; a surface that has no pointer route is a `# DESIGN?` + PROGRESS
question.

### 5.4 Routines

A routine is a list of steps (`move_to(target)`, `hover(n)`, `click`, `wheel(axis, notches)`,
`wait_until(predicate, max_frames)`, `drag(from, to)`); each step yields one action per frame.
**Pause rule:** a routine that touches the map or the region panel (not the anomaly click) and
starts while the clock runs begins with a click on the pause control and ends with one; routines
inside a clock-holding modal (the tree, a wire card, the ability picker, the discovery modal) need
none. **Small regions:** when `region_screen_size < 24` logical px, two wheel notches up over the
point before the click and two down after (zoom keeps the point under the pointer, so the view
returns). **Home view:** the camera is never moved otherwise; a target off screen or covered is
reached by one `drag` on open map toward it (rare; logged).

| Bot command | Routine (pointer only) |
| --- | --- |
| `ChooseOriginCommand(r)` | (origin site select is already up) → click `region_point(r)` → wait for the region panel → click `region_button(&"site")` |
| `PurchaseNodeCommand(n, "")` | tree open? else click `dock_button(&"tree")` → click `tree_tab(tree of n)` → wheel until `tree_card(n)` is inside `board_scroll()`'s visible rect (≤ 40 notches, y then x) → click the card → click `tree_buy()` → stay open if the bot's next command is another plain purchase, else click `tree_close()` |
| `PurchaseNodeCommand(n, site)` | pause (the site select runs outside the modal) → as above up to `tree_buy()` → wait for site select → click `region_point(site)` → wait for the panel → click `region_button(&"site")` → resume |
| `ChooseEventOptionCommand(e, o)` | wire card showing `e`? → click `wire_option(o)` → click `wire_dismiss()` when a result shows. Else pause → click `event_point(e)` (or `region_point` of its region) → click `region_option(e, o)` → resume |
| `CollectAnomalyCommand(a)` | click `anomaly_point(a)`; covered → pause, click `region_point`, click `region_button(&"collect")`, resume |
| `UseAbilityCommand(ab, r)` | pause → click `dock_button(&"abilities")` → click `ability_row(ab)` → targeted: wait for site select → click `region_point(r)` → click `region_button(&"site")` → resume |
| `SetDormancyCommand(r, on)` | pause → click `region_point(r)` → click `region_button(&"dormancy")` → close the panel → resume |

**Interrupts, checked every frame before the routine continues:** the discovery modal → click
`discovery_continue()`; a wire card for an event other than the routine's → answer it with the
bot's own choice function `bot.answer_event(sim, event, def)` (the modal blocks everything else;
this is the one place the puppeteer's order differs from the bot's, recorded per routine as
`interrupt`). The results screen never appears inside a recording (the run ends first).

### 5.5 When the bot is asked

Mirrors `Harness.advance`: the bot's `next_command(Game.sim)` is asked on the **first frame after a
day changes** and **after each routine ends**, until it returns null for that day, at most
`Policy.MAX_COMMANDS_PER_DAY` times a day. A command that `sim.can_apply` refuses before its
routine starts is **stale** (counted, not performed); the bot is asked again.

### 5.6 The routine check

Before a routine: `n = sim.command_log.size()`. After it: `n + 1` entries, and the last one's
`to_dict()` equals the intended command's with `day` ignored — **`ok`**. Otherwise **`refused`**
(the command log shows a refusal reason through `EventBus.command_applied`), **`missed`** (a target
not found, a wait that ran out, or 300 frames without finishing — the puppeteer then closes what it
opened and moves on) or **`stale`**. Per routine the run keeps `{kind, intended, applied, result,
interrupt, start_frame, end_frame}`.

### 5.7 Between routines

After a routine the pointer moves to its **rest point** — the origin region's `region_point`, or the
map's centre before the origin — and stays there. Idle frames are frames of a still pointer, as a
player who watches.

---

## 6. The recorder (S7.F2)

### 6.1 Command line

```
"$GODOT" --path . --fixed-fps 15 --resolution 1280x720 --audio-driver Dummy -- --record-episodes
    --out=<dir> [--bots=greedy,cyber,biology,robotics,weapons,persuasion] [--seeds=2001..2007]
    [--setups=plan] [--frame-cap=60000] [--no-frames] [--allow-pads]
"$GODOT" --path . --fixed-fps 15 --resolution 1280x720 --audio-driver Dummy -- --record-episodes
    --replay-actions=<run dir> [--no-frames]
```

Not `--headless` (the dummy renderer has no pixels); `--no-frames` runs logic only (tests, quick
checks) and works headless.

### 6.2 The run plan (`--setups=plan`)

Runs = bots × seeds, in bot order then seed order. Seeds 2001–2004: **the benchmark setup**
(`data/benchmark.json` `setup`: Language Model, standard, no directives). Seeds 2005–2007: the
architecture `db.architectures[(seed + bot_index) % count]`, standard, no directives — so every
architecture appears. Seed 2007 is the **validation** seed (§7.2). 6 bots × 7 seeds = **42 runs**.
Every seed in a benchmark suite is refused at start (exit 1).

### 6.3 One run

`FluxEnv.begin(seed, setup)` with the puppeteer as agent; frames until `env.is_over()`; then the
checks (§6.5); then the run directory; one line on stdout:
`flux: run <bot> s<seed> <arch> frames=<n> outcome=<id> day=<d> routines ok=<k>/<n> ok|fail`.
Exit codes: 0 every run passed · 1 bad arguments or contract · 3 a replay check failed · 4 a run's
routine success was below 99 % (the run is written with `"accepted": false`).

### 6.4 The run directory — `<out>/runs/<bot>__s<seed>__<arch>/`

| File | Content |
| --- | --- |
| `frames/000000.png` … | the captured frames, PNG (lossless), encoded on `WorkerThreadPool`, at most 32 pending |
| `actions.f32` | little-endian float32, `N × 5`, `action[t]` in contract order |
| `meta.jsonl` | one JSON line per frame: `t`, `day`, `speed`, `held` (`Game.is_held()`), `routine` (index or −1), `edge` (button edge or wheel notch this frame), `digest` (§4.4), `hud` {`compute`, `discovered`, `max_containment`, `phase`} |
| `run.json` | `version` 1, `contract_sha256`, `game_version`, `content_hash`, `bot`, `plan`, `seed`, `setup`, `caption`, `frames`, `end_reason`, `outcome`, `day`, `days`, `hash`, `commands` (`Command.to_dict()` list), `routines` (§5.6), counts per result, `accepted`, `replay` {`hash_ok`, `actions_ok`} |

`run_writer.gd`:

```gdscript
extends RefCounted
func _init(p_dir: String, p_contract: FluxContract, p_frames: bool) -> void
func add_frame(index: int, image: Image) -> void          # queued PNG write
func add_step(index: int, executed: FluxAction, meta: Dictionary) -> void
func finish(run: Dictionary) -> String                    # waits for every PNG; writes run.json; "" or error
```

### 6.5 The checks

1. **Hash replay** (as `bench_run.gd` §11.1 step 4): `Simulation.replay(db, seed, command_log,
   world.day, setup)` reaches the run's `state_hash()`.
2. **Routine success** ≥ 99 % `ok` over the run (stale routines do not count against it — the bot
   changed its mind, not the puppeteer); below → `accepted: false`.
3. **Action-only replay** (`--replay-actions`): a fresh `FluxEnv` with the same seed and setup and
   `ActionFileAgent` (reads `actions.f32`, returns row *t*; nothing else) must produce the **same
   command log** (dictionaries equal, days included) and — with frames — the **same `digest` on
   every frame**. This proves the five numbers per frame are the whole interface. The recorder runs
   it for the first run of every invocation and on request; S7.F2's acceptance runs it on three.

```gdscript
# action_file_agent.gd
extends RefCounted
func _init(p_path: String, p_contract: FluxContract) -> void   # the whole file read; bad length → error
var error: String
func act(env: Node) -> FluxAction
func observe(env: Node, index: int, image: Image, digest: String) -> void
```

### 6.6 Volume, disk and time (estimates)

- **Run length:** the median bot run is ≈ 700 days (BALANCE); at 2× that is ≈ 700 s of clock plus
  held and paused time (tree browsing, cards, pauses: ≈ 3–5 min) → **≈ 13–16 k frames**, ≈ 55–65
  episodes a run.
- **42 runs ≈ 590 k frames ≈ 2 400 episodes** before filtering (≈ 11 h of play at 15 Hz). With the
  idle cap and the validation seed held out, ≈ 1 400–2 000 training episodes remain — the **≥ 800
  target** is met with room even if runs are half as long as estimated.
- **Disk:** a 512×288 interface PNG ≈ 60–200 KB → **35–120 GB** of run frames; the dataset (the
  same PNG bytes inside NPZ, §7.3) adds the kept share again. Plan **≈ 200 GB free**. Run frames can
  be deleted after conversion: `actions.f32` + `run.json` regenerate them (§6.5).
- **Time:** per frame ≈ 3–5 ms render at 1280×720, 5–15 ms readback, 5–10 ms resize, PNG off the
  main thread → ≈ 25–50 frames/s → **≈ 3–7 hours for the 42 runs in one process**; runs are
  independent, so 3 processes (disjoint `--bots`) take ≈ 1–3 hours.

---

## 7. Converter and dataset (S7.F3)

### 7.1 The Python project (`tools/flux/py/`)

`pyproject.toml`: Python `>=3.12,<3.13`, dependencies `numpy`, `pillow`, console script
`doomsday-flux = doomsday_flux.cli:main`; `[tool.uv] no-build = true` (**wheels only**); `uv.lock`
committed; `.gdignore` (empty) so Godot never scans the folder or its `.venv`. Tests: stdlib
`unittest` (`uv run python -m unittest discover -s tests`). `train_plug.py` and `flux_agent.py`
import `torch` / `flux_action` **lazily** and run only in BFL's environment (§8.6); their tests skip
when those are missing.

### 7.2 `doomsday-flux convert`

```
uv run doomsday-flux convert --runs=<out>/runs --out=<dataset> [--raw-frames] [--min-success=0.99]
```

1. Read `contract.json`; every run's `contract_sha256` must equal it (else the run is skipped with
   a line). Skip runs with `accepted: false`, and **refuse** (exit 1) any run whose seed is in a
   `data/benchmark.json` suite — the leakage guard.
2. Split by **seed**: `val_seeds` → `val/`, `train_seeds` → `train/` (whole runs, never episodes of
   one run on both sides).
3. Cut episodes (§3.6); mark active/idle; within each split keep every active episode and the idle
   ones in order of `sha256(run name + ":" + start)` until idle ≤ `idle_share_max` (25 %) of the
   split — deterministic.
4. Write episodes, `index.json`, `manifest.json`, `stats.json`; print the summary.

### 7.3 Formats

- **`ep_000000.npz`** (numbered in (run, start) order): `frames_png` (uint8, the frames' PNG bytes
  concatenated — the run's own files, not re-encoded) + `frames_off` (int64, `T + 1` offsets), or
  with `--raw-frames` `frames` (`T × 288 × 512 × 3` uint8, [guide]'s plain form); `action`
  (`T × 5` float32); `prev_action` (`5` float32); `day` (`T` int32, not read by the trainer).
- **`index.json`**: `{"length": 240, "action_dim": 5, "fps": 15, "contract_sha256": "…",
  "episodes": [{"file": "ep_000000.npz", "task": "<caption>", "run": "<run dir name>",
  "start": 0, "active": true}, …]}`.
- **`manifest.json`**: contract hash; per source run: name, `run.json` SHA-256, seed, bot, arch,
  frames; per episode: file and SHA-256; SHA-256 of both `index.json` files. **`data_sha256`** (the
  dataset's identity on a leaderboard entry) = SHA-256 of `manifest.json`'s bytes.
- **`stats.json`** + printed: episodes per split, bot, plan and architecture; active share; button
  presses, wheel notches and pointer distance per episode (mean, p10, p90); an 8×4 grid histogram
  of pointer positions and of press positions; day coverage (p10–p90 of `day`); routine results
  summed; total bytes.

### 7.4 Dataset acceptance

≥ 800 training episodes; every bot ≥ 10 % of them; idle ≤ 25 %; no NaN; every action in [−1, 1];
`button` ∈ {−1, +1}; wheels ∈ {−1, 0, +1}; `frames_png` decodes to 288×512×3 for a sample of 1 %.

### 7.5 The trainer plug (`train_plug.py`)

`build(config, **kwargs)` — the hook `TrainConfig.dataset = "doomsday_flux.train_plug:build"`
names ([emb]). The same slicing contract as BFL's game loader ([games] `GameWindowDataset`):
episodes in a seeded epoch order `Random(f"{seed}:{epoch}")`, sliced by rank then worker, fixed
`windows_per_rank`, `batches_per_rank`, exact resume through `skip_batches`. A window:
`s = Random(f"{seed}:{epoch}:{position}").randrange(0, 240 − 33 + 1)`; `images.game` = frames
`s…s+32` as `(33, 3, 288, 512)` uint8; `state` = `prev_action` when `s == 0`, else `action[s − 1]`;
`action` = `action[s : s + 32]`; `action_mask` = ones(5); `task` = the episode's caption;
`window_seed`, `episode_index`, `start`. `config.source_root` = the split directory. Written fresh
from the documented contract; if code is adapted from BFL's Apache-2.0 example, its notice goes in
the file header.

---

## 8. The control bridge (S7.F4)

### 8.1 Command line and lifecycle

```
"$GODOT" --path . --fixed-fps 15 --resolution 1280x720 --audio-driver Dummy -- --flux-bridge
    [--port=47815] [--out=<dir = user://flux/runs/>] [--timeout-s=300]
```

The node starts a `TCPServer` on **`127.0.0.1` only** (the bind address is a constant, not an
argument), accepts **one** client whose `get_connected_host()` is `127.0.0.1` (anything else is
closed at once), and plays sessions: `HELLO` → `RESET` → frames and actions → `END` → `RESET` or
`BYE`. The environment is `FluxEnv` (§4.5) with the bridge as agent.

### 8.2 Messages (`bridge_protocol.gd`, little-endian)

Header 12 bytes: magic `DFX1` · type u8 · 3 reserved zero bytes · payload length u32.

| Type | Dir | Payload |
| --- | --- | --- |
| 1 `HELLO` | game → driver | JSON: `protocol` 1, `contract_sha256`, `game_version`, `content_hash`, `frame_size` |
| 2 `HELLO_OK` | driver → game | JSON: `protocol` 1, `contract_sha256` (must equal, else `ERROR contract`) |
| 3 `RESET` | driver → game | JSON: `seed` (int ≥ 1), `architecture` (`""` = the benchmark setup, else a content id), `plan` (a key of `plans`), `frame_cap` (≤ 120 000), `model` (printable ASCII, ≤ 200), `params` (object, ≤ 32 keys of scalars), `agent` (object, §10.1) |
| 4 `FRAME` | game → driver | `step` u32 · `day` i32 · `flags` u32 (bit 0 run over, bit 1 clock held, bit 2 speed 0) · `state` 5 × f32 (the executed action) · width u16 · height u16 · RGB8 bytes |
| 5 `ACTION` | driver → game | `step` u32 (must equal the last FRAME's) · 5 × f32 |
| 6 `END` | game → driver | JSON: `end_reason`, `outcome`, `day`, `days`, `hash`, `commands`, `frames`, `entry` (file name) |
| 7 `BYE` | driver → game | empty; the game quits 0 |
| 8 `ERROR` | game → driver | JSON: `reason` (`magic`, `type`, `size`, `json`, `contract`, `step`, `setup`, `timeout`); the connection is closed |

```gdscript
extends RefCounted
const MAGIC: PackedByteArray = [0x44, 0x46, 0x58, 0x31]
const HEADER_BYTES: int = 12
const MAX_DRIVER_PAYLOAD: int = 65536
enum Type {HELLO = 1, HELLO_OK = 2, RESET = 3, FRAME = 4, ACTION = 5, END = 6, BYE = 7, ERROR = 8}
static func message(type: Type, payload: PackedByteArray) -> PackedByteArray
static func frame_payload(step: int, day: int, flags: int, state: FluxAction, image: Image) -> PackedByteArray
static func parse_header(bytes: PackedByteArray) -> Dictionary      # {type, length} or {error}
static func parse_action(payload: PackedByteArray) -> Dictionary    # {step, values: PackedFloat32Array} or {error}
static func parse_json(payload: PackedByteArray) -> Dictionary      # {value} or {error}; objects only
static func json_payload(value: Dictionary) -> PackedByteArray
```

### 8.3 Lockstep

After `RESET`, frame 0 is sent from `frame_post_draw`. In the next engine frame the bridge's
`act()` **blocks** (poll + `OS.delay_usec(500)`) until the `ACTION` for that step arrives, then
returns it; the environment applies it and steps the clock. So game time advances one frame per
action, however long inference takes — runs are deterministic and replayable, and a slow model is
only slow. No `ACTION` within `--timeout-s` → `ERROR timeout`, the run is abandoned (no entry).
At the end (`env.is_over()`), the bridge writes the entry (§10.1) to `--out` and sends `END`.

### 8.4 Safety

Loopback bind and peer check; one client; debug builds only, from the project (never exported);
payload caps (`MAX_DRIVER_PAYLOAD`; a larger length → `ERROR size`, close); JSON parsed as data
(objects of scalars, lengths capped), never evaluated; **no path, file name or code from the
socket** — the entry's file name is built from checked fields (§10.1's §10.2-style rule) and
written only under `--out`; `seed`, `architecture` and `plan` validated against content and
contract (`ERROR setup`). The driver refuses any host but `127.0.0.1`, `localhost` or `::1`, and
loads nothing with pickle (`numpy.load(…, allow_pickle=False)` everywhere).

### 8.5 The driver (`tools/flux/py/doomsday_flux/`)

```
uv run doomsday-flux drive --policy=mock:idle|mock:random|mock:replay|flux
    [--run=<recorded run dir>]           # mock:replay
    [--export=<head export dir>]         # flux
    [--suite=standard|quick | --seeds=a..b] [--architecture=] [--plan=cyber]
    [--frame-cap=60000] [--model=<id>] [--port=47815]
```

```python
class Agent(Protocol):
    def reset(self, caption: str) -> None: ...
    def act(self, frame: np.ndarray, state: np.ndarray) -> np.ndarray: ...   # (288,512,3) uint8, (5,) f32 -> (5,) f32

class IdleAgent: ...          # neutral action every frame: the floor row
class RandomAgent: ...        # seeded (seed of the run) random pointer walk, a click every ~2 s: the noise row
class ReplayAgent: ...        # a recorded run's actions.f32, row by step: the end-to-end contract check
class FluxAgent:              # flux_agent.py, lazy imports, BFL environment only
    def __init__(self, export_dir: Path, device: str = "cuda", compile_dit: bool = False,
                 offload_text_encoder: bool = True) -> None: ...
    def reset(self, caption: str) -> None: ...          # policy.reset(); the plan queue cleared
    def act(self, frame: np.ndarray, state: np.ndarray) -> np.ndarray: ...
```

`FluxAgent.act`: when its queue is empty, `predict_action_chunk({"images.game": frame as
(1, 3, 288, 512) uint8, "state": (1, 5), "task": [caption]})` → `(1, 32, 5)`; the first
`n_action_steps` (the export's, 8) are queued; one is returned per frame. The state is always the
game's executed action from `FRAME`, never the model's own prediction. **Eager** (`compile_dit`
false) for leaderboard runs: [setup] says compiled runs differ between processes.

`drive` plays the suite's seeds in order with the benchmark setup (or `--architecture`), one
`RESET` each, prints one JSON line per run (seed, outcome, days, frames, end_reason, entry, seconds,
mean ms per chunk), then `BYE`. `mock:replay` compares the `END`'s `commands` and `hash` with the
recorded `run.json` and exits 1 on a difference.

### 8.6 Where it runs on the user's PC

BFL's code requires Linux [setup]: the driver with `--policy=flux`, training and export run in
**WSL2 (Ubuntu 24.04)** in BFL's checkout (`uv sync --locked --extra encoders --extra data` plus
the NATTEN wheel), invoked as `uv run --project ~/flux-action python -m doomsday_flux.drive …`
with `PYTHONPATH` at `tools/flux/py` (our modules need only numpy there). The game runs on
Windows. WSL2 reaches the game's `127.0.0.1` only with **mirrored networking**
(`%USERPROFILE%\.wslconfig`: `[wsl2]` `networkingMode=mirrored`, Windows 11 22H2+). The mock
policies also run natively on Windows from `tools/flux/py`.

---

## 9. Training plan for the user

### 9.1 Once

1. WSL2 Ubuntu 24.04, NVIDIA driver with WSL CUDA support, mirrored networking (§8.6).
2. Accept the FLUX Kommunity License for the base repository on Hugging Face with the user's
   account (§13 Q2), `hf auth login`.
3. `git clone https://github.com/black-forest-labs/flux-action ~/flux-action`, the setup commands of
   [setup], the base download of [setup] *Full fine-tuning setup* (`flux-3-action-base.safetensors`,
   `video_vae.safetensors`, `text_encoder/*`; ≈ 30–45 GB, estimate).
4. Record (§6, ≈ 3–7 h) and convert (§7) on Windows; copy `<dataset>` into WSL's filesystem
   (`/home/…`, not `/mnt/f` — far faster reads).

### 9.2 (a) The smoke test on the 5090 — first, always

The documented 4-update test uses `frozen_steps=0` (the trunk trains from update 1): that is the
full-parameter path and **will not fit in 32 GB** (§9.3). The local smoke test is
`configs/doomsday_5090_smoke.json`: `nproc_per_node 1`, `windows_per_rank 1`, `grad_accumulation
1`, `steps 4`, `frozen_steps 4` (the trunk never unfreezes), `param_dtype "bfloat16"`,
`activation_checkpointing true`, `num_workers 2`, `checkpoint_every 4`, `log_every 1`, the dataset
of §7. Run:

```sh
uv run torchrun --nproc_per_node 1 -m flux_action.cli train --config <repo>/tools/flux/py/configs/doomsday_5090_smoke.json \
  --override output_dir=outputs/doomsday-smoke --override resume=none
```

It passes when 4 updates finish, a checkpoint is written, `flux-action export-checkpoint --dtype
bfloat16` exports it, and `drive --policy=flux --seeds=2007..2007 --frame-cap=900` plays 900 frames
through the bridge. Note the peak memory (`nvidia-smi --query-gpu=memory.used --format=csv -l 1`)
and the seconds per update in PROGRESS: they replace §9.3's estimates. If `param_dtype bfloat16` is
refused by the trainer, the fallback is `float32` with the text encoder offloaded; if that does not
fit either, **fallback B** is the documented single-GPU LoRA path through LeRobot [lora] (a
conversion to a LeRobot dataset — a design step of its own, not planned).

### 9.3 (b) What fits in 32 GB (estimates unless marked)

| Use | Memory | Verdict |
| --- | --- | --- |
| **Inference**, BF16 export, eager, 1 sampler step | DiT ≈ 14 GB + VAE ≈ 1 GB + text encoder ≈ 8–9 GB (≈ 0 with `--offload-text-encoder` [setup]; one caption per run) + activations ≈ 1–3 GB → **≈ 16–27 GB** | **fits** |
| Inference speed | ≈ 0.2–1 s per 32-step chunk, one chunk every 8 frames → a 15 000-frame run ≈ 6–30 min | estimate |
| **Documented 4-update test** (`frozen_steps 0`) and **documented recipe** (trunk unfrozen after 200, FP32 weights + Adam) | ≥ 112 GB before activations (§1.3); the recipe shards across GPUs (`reshard_after_forward`) | **does not fit** |
| **Heads-only** (trunk frozen throughout), BF16 frozen weights, activation checkpointing, 1 window × accumulation | DiT 14 + text encoder 8–9 (or offloaded) + VAE 1 + trainable heads and the modality's mode blocks with Adam ≈ 1–5 + activations for one 33-frame 288×512 window ≈ 2–6 → **≈ 20–35 GB** | **borderline — the smoke test decides** |
| Heads-only, time | backward through the frozen trunk is still needed (the fresh `emb_in` sits at its input); ≈ 0.6–0.9 s per window → 2 000 updates × 16 windows ≈ **5–8 h, one night** | estimate |

**`configs/doomsday_5090_heads.json`** (the local training): as the smoke config with `steps 2000`,
`frozen_steps 2000`, `heads_warmup_steps 200`, `cooldown_start 1600`, `cooldown_steps 400`,
`grad_accumulation 16` (global batch 16), `checkpoint_every 250`. Expected quality: below the full
recipe — the trunk never adapts to the interface; it is the local proof of the pipeline and a
first leaderboard row, not the final agent.

### 9.4 (c) The documented recipe on rented H200s

`configs/doomsday_h200.json` = [cfg] with our values: `dataset "doomsday_flux.train_plug:build"`,
`source_root "<DATA>/train"`, `action_modality "doomsday"`, `action_dim 5`, `camera_layout
"single"`, `camera_keys ["images.game"]`, `canvas_hw [288, 512]`, `chunk_size 32`,
`n_action_steps 8`, `fps 15.0`, `action_scale 2.0`, `gripper_flip_dims []`, `caption_dropout 0.0`,
`augment false`, `trunk_weights` = `flux-3-action-base.safetensors` (the public base, [setup]), the
base's VAE and text encoder, and [cfg]'s optimiser, schedule (3 000 steps, 200 / 600 / 200,
cool-down 2 600 + 400), precision and checkpointing unchanged; `windows_per_rank 16` on 8 GPUs →
**global batch 128** (the documented scale).

1. One node of **8×H200** (Linux image with CUDA 12.8), the dataset uploaded (≈ 20–60 GB), the
   setup of §9.1 steps 2–3 on the node.
2. The **documented 4-update test** first, as [guide] gives it, with `--nproc_per_node 8`.
3. `torchrun --nproc_per_node 8 -m flux_action.cli train --config …/doomsday_h200.json`; export at
   the end in BF16; download the export (≈ 15 GB) and the run log.
4. **Time and cost (estimate):** 3 000 × 128 windows × 0.3–0.5 H200-s ≈ 32–53 GPU-h → **≈ 4–7 h**
   on 8 GPUs, plus ≈ 1 h of setup and download → at 2.5–4.5 USD per GPU-h **≈ 100–300 USD per
   training run**. Budget one failed attempt. The documented 7×H200 / 2 000-update variant is
   ≈ 35 GPU-h (the lower end).

### 9.5 (d) Evaluation

1. **Quick look:** `drive --policy=flux --suite=quick --plan=<p>` for each plan; pick the best
   plan.
2. **Leaderboard run:** `drive --policy=flux --suite=standard --plan=<best>` — seeds 1001–1010, the
   benchmark setup, locale `en`, `max_days 2000`, `frame_cap 60000`; score = `BenchScore.run_score`
   (benchmark.md §10.1), mean over the suite. Estimated ≈ 1–5 h for the ten runs.
3. **Reference rows in the same category:** `mock:idle` and `mock:random` (the floor and noise),
   and the bot rows of benchmark.md §10.4 (the ceiling the demonstrations came from).
4. **Diagnostics** (printed by `drive`, not ranked): origin chosen by frame, commands per 100 days
   by type, anomalies collected against spawned, share of frames with the clock held (a model
   stuck in a modal shows here).
5. Entries go to `benchmark/runs/` via `--out` and the board is rebuilt with `bench_run.gd
   --rebuild`; submission to the global board as benchmark.md §16.2.

---

## 10. The leaderboard category (S7.F5)

### 10.1 The entry

A bridge run writes an ordinary `BenchEntry` (benchmark.md §10.2) with these additions (additive,
`version` stays 1; readers ignore unknown keys; absent `category` = `"chat"`):

| Key | Value |
| --- | --- |
| `category` | `"trained"` |
| `backend` | `"flux-action"` |
| `model` | the driver's `--model`, default `flux-3-action+doomsday-<export_sha256 first 8>` |
| `params` | `{"plan": "<p>", "sampler": "<export's>", "steps": <int>, "n_action_steps": <int>, "inference_seed": <int>, "compiled": false, "contract": 1}` → `params_id` as §10.2 |
| `prompt_version` · `parser_version` | 0 · 0 |
| `decisions` · `calls` · tokens · `cost_usd` | `[]` · 0 · 0 · 0.0 |
| `agent` | `{"base_model": "black-forest-labs/flux-3-action-base@<hf revision>", "export_sha256": "<§10.2>", "data_sha256": "<manifest hash, §7.3>", "contract_sha256": "…", "caption": "<the caption>", "train_recipe": "8xH200-full" \| "1x5090-heads" \| "<free text ≤ 40 ASCII>", "train_updates": <int>, "frames": <int>, "frame_cap": <int>, "end_reason": "outcome" \| "frame_cap", "chunks": <int>, "mean_chunk_ms": <float>}` |

The file name keeps §10.2's rule (model slug, params_id, `p0`, suite, seed).

### 10.2 `export_sha256`

SHA-256 over the UTF-8 text of sorted lines `"<hex sha256>  <relative path>\n"`, one per file in
the export directory (README and notice files included, the path with `/`). Computed by the driver
(`doomsday_flux.hashes.export_sha256(dir)`), reported in the entry. Like every model claim on the
board, unverifiable (benchmark.md §16.1) — the replay verifies the commands and the score only.

### 10.3 Changes

- **`BenchEntry`:** reads and writes `category` and `agent` (a dictionary of the keys above, types
  checked, strings capped at 200); `from_dict` still never crashes.
- **`BenchVerifier` rules** (benchmark.md §16.4): `category` ∈ {`chat`, `trained`}; `trained`
  requires `backend "flux-action"`, `prompt_version` and `parser_version` 0, empty `decisions`;
  **a trained run that stops before `max_days` without an outcome is accepted when `agent
  .end_reason == "frame_cap"` and its score is 0** (a frame-capped run is a timeout, never a better
  score); everything else as today.
- **`leaderboard_writer.gd`:** `category` joins the group key; `LEADERBOARD.md` puts trained rows
  in their own table *Trained agents (screen in, pointer out)* after the language models, same
  columns with *calls/cost* replaced by *frames* and *recipe*.
- **The in-game list** (`ui/modals/benchmark.gd`): trained rows under their own heading, **only
  when `data/benchmark.json` `global.show_trained` is true — default `false`** until the user
  answers §13 Q2. Strings (en / de):
  - `UI_BENCH_CATEGORY_CHAT` — *Language models* / *Sprachmodelle*
  - `UI_BENCH_CATEGORY_TRAINED` — *Trained agents* / *Trainierte Agenten*
  - `UI_BENCH_TRAINED_NOTE` — *These agents see only the screen and move the pointer. Their runs
    are checked like every other run.* / *Diese Agenten sehen nur den Bildschirm und bewegen den
    Zeiger. Ihre Läufe werden geprüft wie alle anderen.*
- **The public repository's `validate.py`** must accept `category` and `agent` — a maintainer
  change there, not a build step of this repository (a note for the user).

---

## 11. Build steps

One session each; each ends with the full test suite green (`tools/test.sh`) plus its own
acceptance.

### 11.1 S7.F1 — contract, actuator, capture, clock

**Scope:** `contract.json`, `flux_contract.gd`, `flux_action.gd`, `flux_input.gd`,
`input_guard.gd`, `flux_frame.gd`, `flux_caption.gd`, `flux_env.gd`, `Game.external_clock` /
`step_clock`, `main.gd` dispatch (the two scripts may not exist yet: `FLUX_MISSING`).
**Tests:**
- `tests/unit/test_flux_contract.gd` — the file loads with no errors; `action_dim` 5; canvas and
  frame agree; a copy with `frame_size [500, 288]`, with a benchmark seed in `train_seeds`, with
  `window_size [1000, 720]` each gives an error; `sha256` is 64 hex and stable.
- `tests/unit/test_flux_action.gd` — logical ↔ normalised round trip at the corners and centre;
  clamping; NaN/INF per channel (§3.3); wrong array length.
- `tests/unit/test_flux_input.gd` — `events_for`: no events when unchanged; motion only when moved;
  press on the rise, release on the fall, none while held; the mask on motion while held; one
  wheel notch at ±0.5, none at ±0.49; both axes in one frame in the order motion, button, y, x;
  every event carries `DEVICE`.
- `tests/unit/test_input_guard.gd` — an event with another device is handled (dropped), one with
  `DEVICE` passes.
- `tests/unit/test_flux_frame.gd` — a synthetic 1280×720 image → 512×288 RGB8; the glyph's tip
  pixel at the expected place for five pointer positions, released and held; `digest` stable.
- `tests/unit/test_game_external_clock.gd` — with `external_clock`, `_process` changes nothing;
  `step_clock(1/15)` at speed 2 ticks exactly once per 15 calls over 300 calls.
- `tests/integration/test_flux_env_click.gd` — the real main scene through `FluxEnv` (logic only)
  with a scripted agent: the origin chosen, the tree opened by its dock button and a plain node
  bought, an anomaly collected — pointer actions only; the command log shows each.
**Acceptance:** the above; `tools/check_scripts.gd` clean; a windowed `--fixed-fps 15` launch with a
scripted 60-frame agent writes 60 PNGs of 512×288 whose glyph follows the pointer (looked at).

### 11.2 S7.F2 — puppeteer, recorder, replay checks

**Scope:** `pointer_path.gd`, `ui_probe.gd`, `puppeteer.gd`, `run_writer.gd`,
`action_file_agent.gd`, `flux_recorder.gd`; every routine of §5.4 on the real UI.
**Tests:**
- `tests/unit/test_pointer_path.gd` — durations follow Fitts within the clamp; paths end on the
  target, stay in the viewport, are monotone in progress; `aim` stays in the middle half; the same
  seed gives the same numbers.
- `tests/integration/test_puppeteer_routines.gd` — per routine kind, on the main scene with a fixed
  seed and fixtures (as `test_deploy_click.gd` builds its situations): the intended command is the
  last in the command log and the result is `ok` — origin; plain purchase; deploying purchase;
  wire-card answer (with its result dismissed); regional event answer; anomaly (open and covered);
  targeted and global ability; dormancy on and off; the discovery interrupt; a wire-card interrupt
  during another routine.
- `tests/unit/test_puppeteer_purity.gd` — `puppeteer.gd` and `ui_probe.gd` contain none of
  `.call(`, `.emit(`, `Game.apply`, `Game.site_`, `set_deferred`, `.set(` (text scan).
- `tests/integration/test_flux_recorder_run.gd` — logic only, greedy, one seed, 150 days: routines
  ≥ 99 % `ok`, hash replay equal, `run.json` and `actions.f32` consistent (`frames × 5` floats),
  and the action-only replay reproduces the command log.
**Acceptance:** three full windowed runs (greedy s2001, cyber s2005, persuasion s2007) with frames:
exit 0, routine success ≥ 99 %, action-only replay equal on commands and every frame digest; the
same run recorded twice gives byte-identical `actions.f32` and `meta.jsonl`; frames/s and bytes
per frame noted in PROGRESS (they replace §6.6's estimates).

### 11.3 S7.F3 — converter, dataset stats, trainer plug, configs

**Scope:** `tools/flux/py/` project (§7.1), `convert`, `stats`, `train_plug.py`, the three
configs, `.gitignore`.
**Tests** (`unittest`, synthetic runs made by the test: 3 runs × 700 frames of 16×9 PNGs with a
test contract): episodes cut at 240, remainders dropped; `prev_action` of the first and of a later
episode; idle cap exactly met and deterministic; val/train split by seed; a benchmark seed refused;
a run with another contract hash skipped; NPZ keys, dtypes, shapes; `frames_png` decodes to the
source frames; `manifest.json` hashes match the files; `data_sha256` stable across two conversions.
`test_train_plug.py` (skipped without torch): windows of the right shapes, state at `s == 0` is
`prev_action`, same `(seed, epoch, rank)` → same windows, `skip_batches` resumes exactly.
**Acceptance:** `uv sync` resolves with `no-build`; tests pass; the three S7.F2 runs convert and
`stats` prints sensible numbers; the configs parse as JSON and name only keys that exist in
`flux_action.config` (checked against the pinned `flux-action` commit, recorded in the README).

### 11.4 S7.F4 — control bridge, driver, mock policies

**Scope:** `bridge_protocol.gd`, `flux_bridge.gd`, `protocol.py`, `drive.py`, `mock_policies.py`,
`flux_agent.py` (written against [setup]'s API; not run without a GPU), `hashes.py`; the entry
written with §10.1's keys (added after `BenchEntry.to_dict()` until S7.F5).
**Tests:**
- `tests/unit/test_bridge_protocol.gd` — every message round-trips; bad magic, unknown type,
  oversize length, a short `ACTION`, a non-object JSON each give the `error`.
- `tests/integration/test_flux_bridge.gd` — the bridge (logic only, frames off → `FRAME` with
  width/height 0) and a GDScript `StreamPeerTCP` client in the test: `HELLO` → `HELLO_OK` → `RESET`
  → 90 actions → steps in order, `state` echoes the sanitised action, a wrong `step` → `ERROR step`,
  a wrong contract → `ERROR contract`, an unknown architecture → `ERROR setup`.
- Python `test_protocol.py` (against a fake server socket) and `test_drive.py` (mock agents'
  determinism; the host check refuses `192.168.0.1`).
**Acceptance:** windowed bridge + `drive --policy=mock:replay --run=<an S7.F2 run>` reproduces that
run's commands and hash; `drive --policy=mock:random --suite=quick` writes three entries that
`verify_runs.gd` accepts once S7.F5 is in (until then: `Simulation.replay` of their commands gives
their hash).

### 11.5 S7.F5 — the leaderboard category

**Scope:** §10.3 — `BenchEntry`, `BenchVerifier`, `leaderboard_writer.gd`, the list, the strings,
`global.show_trained`.
**Tests:** `test_bench_entry.gd` (the new keys round-trip; a bad `agent` → null with the reason);
`test_bench_verifier.gd` (a trained entry verified; a frame-capped trained entry with score 0
verified, with score > 0 rejected `rules`; a chat entry with `category "trained"` but no `agent`
rejected); `test_leaderboard_writer.gd` (two categories, two tables, grouping by category);
`test_benchmark_list.gd` (trained rows hidden while `show_trained` is false, shown under their
heading when true); `check_strings` passes.
**Acceptance:** the S7.F4 mock entries appear in the local `LEADERBOARD.md` under *Trained agents*.

### 11.6 User steps (not build steps)

- **U7.F1 — record:** the §6.2 plan (42 runs), then `convert`; numbers into PROGRESS.
- **U7.F2 — local smoke and heads-only training** on the 5090 (§9.2–§9.3).
- **U7.F3 — rented recipe** (§9.4), after the user's go and budget.
- **U7.F4 — evaluation and submission** (§9.5).

---

## 12. Rules this track must not break

- `core/` untouched and pure; the puppeteer is presentation-side and reads `Game.sim` like any UI.
- Static typing everywhere, one class per file, tests per CLAUDE.md naming.
- Content rule: captions and every string are outcome language; nothing in data, captions or
  comments describes a real method.
- Never load player-supplied resources: run files, entries and messages are JSON or raw arrays.
- Nothing in `tools/flux/` ships; nothing FLUX-related is added to an export filter.

---

## 13. Decisions (for PROGRESS) and questions for the user

**Decisions (D7.F):** D = 5 pointer-only action space (absolute x/y, button, wheel y, wheel x),
identity normalisation; 512×288 frames on a 288×512 canvas, cursor glyph composed at capture;
15 Hz lockstep with an environment-owned clock at 2× (15 frames a day); state = last executed
action, `prev_action` at episode start; 240-frame episodes; idle ≤ 25 %; captions from the
architecture name and the bot's plan; training seeds 2001–2006, validation 2007, benchmark seeds
refused; 42-run plan; Python wheels-only uv project in `tools/flux/py/`, BFL's environment in WSL2
for training and inference; loopback-only TCP bridge in debug builds; `category: "trained"` entries
with an `agent` block, shown in the game only with `global.show_trained`.

**Questions for the user:**

1. **GPU cloud provider and budget** for §9.4 — e.g. RunPod, Lambda, Vast.ai, Nebius or another;
   8×H200 for ≈ 5–8 h, ≈ 100–300 USD per training run (estimate). A spending cap per run?
2. **Licence:** will you accept the FLUX Kommunity License on Hugging Face? And are you (with
   affiliates) a *Qualifying User* (< US$5 M gross annual revenue)? Only then may FLUX-played runs
   be shown inside the sold game (`show_trained`), labelled as AI-played.
3. **What goes public:** recommendation — nothing FLUX-related in any game build; FLUX runs on the
   public leaderboard as command logs with claims (like chat models); the trained head **not**
   published (publishing is allowed non-commercially with the licence and the modified-model
   notice, if you want it).
4. **WSL2 with mirrored networking** on this PC for the Linux-only training and inference — fine?
5. **Disk:** ≈ 200 GB free for frames and dataset — on F:?
6. **Plans in the caption:** train with the bot's plan named (recommended), or one plan-free
   caption for all?
