# Illustrations: style, the reference, 25 briefs, key art, production, models (D6.7)

**Status:** design, 2026-09-25 (D6.7). **No picture exists yet.** Build step: **S6.3** (§8: the
slot's filter and compact shape, the endings' illustration field, the results screen and the
Codex slot, the illustrations test). Production: **D6.10** [needs user] (§6, §7 — route, the
reference's approval, the set).
**Read with:** VISUALS §2 (art direction, colour language), §3.4 (generated locally, the licence
gate) · `loop-redesign.md` §7.4 (the wire card and its slot) · `polish-visuals.md` §3 (the screen
pass the pictures sit under) · `ASSET_LICENCES.md` rules 2, 4, 6 · `icons.md` §11 (credits).
**Data delivered with this spec:** one string, `UI_CREDITS_ROLE_ILLUSTRATIONS` (en/de, §7.3).

---

## 0. What this spec decides

1. **25 in-game pictures and one key art master** — the 24 named ids (8 counter-moves, 12 chain
   steps, 4 endings), the discovery modal's `discovery` (named in code since S4.3, inside the
   budget "the discovery modal keeps the last one", `taskforce-endings.md` §6.5), and title key
   art for the store (§5). Nothing else gets a picture in M6–M7: **region vignettes are cut**
   (VISUALS q4, §9), as are scenario key art, character portraits and further Codex pictures.
2. **The style is *the network's eye*:** flat screen-print illustration seen from where a machine
   would see — high, oblique, still — in the cold interface ramp with **one cyan accent that is
   always *you***. Six value steps, hard edges, no texture of its own (§2).
3. **Pictures are phase-neutral.** One file per id, cold ramp and cyan in both palettes; the
   Open interface's pale amber never enters a picture. On the warm Open panels a cold picture
   reads as a window onto the world — the world has not changed colour, the interface has.
4. **The style reference is `fc_street`, checked by `cm_lockdown`** (§3): the first a figure, the
   second architecture only. Every other picture is an **edit of the approved reference**, never
   an independent prompt (VISUALS §3.4).
5. **Model shortlist (§6), every licence read 2026-09-25:** **Qwen-Image-2512** (reference) and
   **Qwen-Image-Edit-2511** (edits), both Apache-2.0 — the first choice; **FLUX.2 [klein] 4B**
   (Apache-2.0, generation and editing in one) — the second. FLUX.2 [dev], FLUX.2 [klein] 9B,
   Qwen-Image 2.1 and HunyuanImage 3.0 are **unusable** (non-commercial, research-only, or no
   licence in the EU). Paid API routes are unverified and therefore unusable until their terms
   are read and recorded.
6. **Source 1120 × 840, `assets/illustrations/<id>.png`, lossless with mipmaps** (§4). The wire
   card and the discovery modal need no code; the results screen and the Codex get their slot in
   S6.3 (§8).

**Out of scope:** producing any picture (D6.10); store capsule crops and sizes (D7.3); the app
icon (D7.3); animation of pictures (none — they are stills; reduced motion has nothing to stop).

---

## 1. Where a picture appears

| Surface | Ids | Slot size (logical px) | Fallback when the file is missing |
| --- | --- | --- | --- |
| Wire card, full layout (`loop-redesign.md` §7.4) | 20 event ids | 280 × 210, left of the text | the faction's icon or `»` on `BG_2` (as built) |
| Wire card, compact | same | column width × ¾ (≈ 352 × 264 on a 400 px phone) — **§8.1 fixes the shape** | same |
| Discovery modal | `discovery` | as the wire card | `EVENT_COUNTER` glyph in `ALERT` (as built) |
| Results screen, above the kicker (`screens-full.md` §7) | `end_extinction` · `end_ascendance` · `end_merge` · `end_escape` | 420 × 315; compact: column width × ¾ | **no slot at all** (§8.3) |
| Codex → Endings, the entry pane (`screens-full.md` §6.1) | the same four, by the entry's outcome | 280 × 210; compact: column width × ¾ | no slot |
| Store pages (D7.3, D7.4) | key art | master 3840 × 2160 (§5) | — |

**Variants share their outcome's picture** (`win_ascendance_ashes` shows `end_ascendance`); losses
have none. The picture is decorative for assistive technology — no focus, no name
(`accessibility.md` §3.2 item 5): every fact in it is in the card's text.

**Display arithmetic.** At 280 px a 1120 px source is drawn at ¼; at 4K with a UI scale of 2 the
full-layout slot is 560 physical px (½); the largest draw is the results slot at 4K (840 physical
px, ¾). So **nothing smaller than 8 source px carries meaning** (2 px at 280), and the
composition must read at 280 × 210 — and survive a **70 × 52 thumbnail** test (§7.2).

---

## 2. The style: *the network's eye*

VISUALS §2 says the player looks at the world through the thing that is eating it. The pictures
are the only place that thing is *shown* looking: each is a still that a camera, a sensor, a
satellite or a sleepless system could have taken. That gives the set its one rule of viewpoint and
keeps it from becoming a newspaper page (loop-redesign §7.4: an agency bulletin, never *Plague
Inc.*'s layout, icons or phrasing).

### 2.1 Viewpoint and composition

- **The camera is high and still.** Security-camera corners, long-lens oblique views, overheads,
  a satellite's slant. Never eye level with a person, never a hand-held tilt, never a close-up of a
  face. Horizontal horizon lines (no Dutch angles) — the machine does not dramatise.
- **One focal subject**, 20–45 % of the frame, readable as a silhouette. Two at most when the brief
  is about a pair (`si_emergence`).
- **Safe band:** everything the brief names sits inside the central **1120 × 630** (rows 105–734),
  so a 16 : 9 crop never cuts it (the store's screenshots and any future slot shape); the 105 px
  bands above and below carry only sky, floor or ground.
- **Dark edges:** the outer 40 px on every side stay at or below `BG_3` (`#16212B`), so the picture
  seats in the slot without a drawn frame and without a hard seam against `BG_2`. No painted
  vignette beyond that — the screen pass has its own.

### 2.2 Rendering

- **Flat screen-print illustration:** hard-edged shapes, geometric simplification, flat value
  planes with at most one soft gradient per picture (a sky, a glow's fall-off). No painterly
  brushwork, no photographic texture, no outlines drawn as ink lines.
- **Six value steps**, each a cold interface token (VISUALS "Colour language": luminance carries
  magnitude, and here it carries the read):

  | Step | Colour | Token | Used for |
  | --- | --- | --- | --- |
  | 1 | `#07090C` | `BG_0` | deepest shadow, the edges |
  | 2 | `#16212B` | `BG_3` | shadow planes, night sky |
  | 3 | `#2C3D4C` | `LINE_1` | mid-dark surfaces |
  | 4 | `#4A6478` | `LINE_2` | lit surfaces |
  | 5 | `#93A6B5` | `TEXT_1` | light planes, sky at dawn |
  | 6 | `#DCE6EE` | `TEXT_0` | the few highlights, the focal light |

  Adjacent shapes that must read apart differ by **at least one step** (≥ 26/255 in value) — so
  the pass's hottest dither (20 levels a channel, `polish-visuals.md` §3 stage 7) never merges
  them. Pure white is avoided (≤ 0.5 % of pixels, speculars only).
- **The accent is cyan, `#6FE3FF`, falling off through `#2E6E80` (`ACCENT_DIM`)** — and it is
  always **your presence**: a lit window, a rack's status lights, a unit's ring light, a screen's
  glow, a cable's line. Nothing else is cyan. Where a brief has no presence of yours, the picture
  has no cyan. Area caps (share of pixels, §7.2): counter-moves **≤ 3 %** (the world pushing you
  back — often your light going out), chain steps **≤ 6 %**, `discovery` and endings **≤ 15 %**,
  key art **≤ 20 %**.
- **No other hue.** No red at all (`#FF3B3B` is reserved: "a thing is happening right now",
  VISUALS §2), no faction colours (the card's dateline and glyph carry the faction), no warm
  light — sodium streetlamps, fire and sunsets are drawn in the neutral ramp. The "other" in
  `si_emergence` is **pale white** (step 6), not a second hue.

### 2.3 Why it survives the screen pass

The pass (`polish-visuals.md` §3) draws over every picture: bloom keyed on **chroma** from 0.45,
scanlines every 3 px, luminance grain, ordered dither from 64 down to 20 levels.

- **Neutral pixels never bloom:** the six steps have chroma (max − min of sRGB, 0…1) ≤ 0.18, far
  under the 0.45 key. The rule for a neutral pixel is **chroma ≤ 0.20**.
- **The accent blooms a little and on purpose** (`#6FE3FF`: chroma 0.56) — which is why its area
  is capped: at ≤ 15 % the glow stays a glow and does not haze the card.
- **No texture of its own:** no baked grain, noise, halftone, dither, scanlines or CRT look. At a
  quarter scale they alias into grey mush or moiré under the pass's 3 px scanlines; the pass adds
  them at screen pixels, which is the look.
- **No fine repeating pattern** with a period under **24 source px** (6 px at 280) — especially
  horizontal stripes (blinds, grilles, stair treads, crossing stripes drawn thin). A pattern the
  brief needs (a zebra crossing, rows of seats) is drawn in bands at least that wide.
- **Six steps survive 20 levels**, and soft gradients get the pass's dither, which is intended.

### 2.4 The content rule, for pictures

- **Outcome, never method.** Show what the world sees happen — dark windows, a sealed door, a
  crowd, an empty hall — never how: no code, no screens with legible content, no hardware
  internals, no lab procedure, no weapon, no pathogen, no tool in use against a system.
- **Institutions, never real people.** People are small, anonymous, backlit or seen from behind;
  **no face is ever readable**. The characters (the researcher, the operator) are figures, not
  portraits.
- **No recognisable place, brand or symbol.** No landmarks, skylines, flags, crests, national
  emblems, uniforms with insignia, logos, vehicle markings, real signage designs. A parliament is
  "a chamber", a laboratory "a building".
- **No text of any kind** — letters, numbers, glyphs, placards with writing, signatures,
  watermarks. Placards in a crowd are blank.
- **No gore, no bodies.** Death is shown by absence: an empty street, dark houses, an unused chair.
- **Never *Plague Inc.*:** no petri dishes, no world-map-with-red-spread imagery, nothing of its
  art. Never a named living artist, studio or franchise in a prompt (§6.4).

---

## 3. The style reference

**`fc_street` is the reference; `cm_lockdown` is its check** (`chains.md` §7 named the pair). The
reference has to carry everything the set needs: a figure at distance, architecture, a ground
plane, dawn light in the neutral ramp, and one small cyan presence. `cm_lockdown` then proves the
style holds without any figure, at night, with the accent mostly gone.

**How it is fixed (D6.10, with the user):**

1. Generate **8 candidates** for `fc_street` from the reference prompt (§6.3) with the chosen
   text-to-image model at the model's native 4 : 3 size (§6.2), different seeds.
2. Downscale each to 1120 × 840 and check it against §7.2 (the numbers) and §7.3 (the eye).
   Candidates that fail are dropped; the rest go on one contact sheet at 280 px and 70 px.
3. **The user picks one** (or asks for a second round of 8 with the prompt adjusted — the
   adjustment recorded in the provenance, §7.4). The pick is the reference.
4. `cm_lockdown` is made **as an edit of the reference** (§6.3), checked the same way. If the
   style does not carry over in 6 edit attempts, the reference is changed, not the edit forced:
   back to step 1 with what failed written down.
5. The approved pair is committed first, alone, with its provenance and licence rows; every later
   picture uses **both** as reference images where the model accepts two, else `fc_street`.

---

## 4. Files, size, import

- **Path:** `assets/illustrations/<id>.png` — the id is the file name; the wire card finds it by
  `ResourceLoader.exists` (`illustration_slot.gd`), so dropping a file in is all the event
  surfaces need.
- **Source:** **1120 × 840**, 8-bit sRGB **RGB, no alpha**, PNG, generated larger (§6.2) and
  downscaled with Lanczos once. Target ≤ 1.2 MB a file (the flat style compresses well; 25 files
  ≈ 20–30 MB before import).
- **Import** — every picture ships with its `.png.import`, committed, with these `[params]` (the
  rest as Godot's defaults, which `globe_ids.png.import` shows):

  ```ini
  compress/mode=0
  mipmaps/generate=true
  mipmaps/limit=-1
  process/fix_alpha_border=true
  process/size_limit=0
  ```

  Lossless (`compress/mode=0`) because VRAM compression bands the six flat steps and the web
  export would need two compressed formats; mipmaps because every draw is a downscale (§1). Godot's
  default import has `mipmaps/generate=false`, so an unedited `.import` is a defect the test finds
  (§8.4). No project-wide import default is changed (the map textures must keep theirs).
- **Key art** lives outside the game: `marketing/key_art/key_art.png` (3840 × 2160, RGB), with a
  `marketing/.gdignore` so Godot never imports it and no export includes it (§5).

---

## 5. Key art

**What it is for:** the master from which D7.3/D7.4 cut the store capsules, the library hero and
the page background. **Not shown in the game** — the title's shader globe is the key art in motion,
and a still behind it would fight it.

**Brief — "the night side, from the other side".** The Earth's night hemisphere seen from high
orbit, the planet filling the lower two-thirds, its limb a thin pale arc of dawn (steps 5–6) along
the upper right. On the dark face, sparse city lights in the neutral ramp; from **one point** a
fine lattice of cyan lines has spread across the night side — thin at its edge, dense where it
began — the only colour in the image. Coastlines are soft and abstracted: continents are
suggested, not surveyed (no recognisable country dominates the centre). Stars sparse, never in a
pattern. No text, no logo (the logo is laid over later), no ships, no satellites with markings.

**Composition for crops:** the lattice's origin and densest cyan sit in the **central third**
(x 1280–2560), so a 16 : 9 cut, a 2.15 : 1 banner, a 3.1 : 1 hero and a centred 2 : 3 portrait
cut all keep it; the top 25 % is dark space for a logo. Accent ≤ 20 %; all of §2 otherwise
applies. Made last, as an edit of the reference (for the rendering, not the subject), at the
largest native size the model allows, then upscaled only if a verified upscaler is in the §6
shortlist — otherwise composed at the model's size and the master is that size (D7.3 then names
which capsules it can serve).

---

## 6. Production: route, models, prompts

### 6.1 The shortlist — every licence read and linked (2026-09-25)

A model is usable for shipped art only when its **licence permits commercial use by us in
Germany** and was read at its source. The model is named per asset (ASSET_LICENCES rule 4).

| Model | Role | Licence (read at the source) | Verdict |
| --- | --- | --- | --- |
| **Qwen-Image-2512** (Alibaba, Qwen team) | text-to-image: the reference, key art | **Apache-2.0** — model card `license: apache-2.0`, https://huggingface.co/Qwen/Qwen-Image-2512; licence text https://huggingface.co/Qwen/Qwen-Image/blob/main/LICENSE ("Copyright 2024 Alibaba Cloud") | **Usable — first choice** |
| **Qwen-Image-Edit-2511** (Alibaba, Qwen team) | instruction editing with one or several reference images: every picture after the reference | **Apache-2.0** — model card `license: apache-2.0`, "Qwen-Image is licensed under Apache 2.0", https://huggingface.co/Qwen/Qwen-Image-Edit-2511 | **Usable — first choice** |
| **FLUX.2 [klein] 4B** (Black Forest Labs) | generation *and* multi-reference editing in one checkpoint; ~13 GB | **Apache-2.0** — https://huggingface.co/black-forest-labs/FLUX.2-klein-4B (links https://www.apache.org/licenses/LICENSE-2.0); BFL's usage policy forbids unlawful, deceptive, abusive uses — none apply | **Usable — second choice** (smaller, faster, weaker on composition) |
| FLUX.2 [dev] (BFL) | — | **FLUX Non-Commercial License v2.1**, https://huggingface.co/black-forest-labs/FLUX.2-dev/blob/main/LICENSE.md: the outputs clause allows commercial use of outputs, but *using the model* is limited to non-commercial purposes, which exclude "revenue-generating activity" | **Unusable** without a paid BFL licence |
| FLUX.2 [klein] 9B (BFL) | — | **FLUX Non-Commercial License**, https://huggingface.co/black-forest-labs/FLUX.2-klein-9B/blob/main/LICENSE.md | **Unusable** |
| FLUX.1 [dev] / FLUX.1 Kontext [dev] (BFL) | — | FLUX [dev] Non-Commercial License (same family as above) | **Unusable** |
| Qwen-Image 2.1 (Alibaba, 2026-09-20) | — | **Qwen Research License**: "FOR NON-COMMERCIAL PURPOSES ONLY", https://huggingface.co/Qwen/Qwen-Image-2.1/blob/main/LICENSE | **Unusable** — the newer number is the worse licence |
| HunyuanImage 3.0 (Tencent) | — | Tencent Hunyuan Community License: "does not apply in the European Union, United Kingdom and South Korea", https://huggingface.co/tencent/HunyuanImage-3.0/blob/main/LICENSE | **Unusable** — no licence where we are |
| Z-Image-Edit (Alibaba Tongyi) | — | Z-Image-Turbo is Apache-2.0 (https://huggingface.co/Tongyi-MAI/Z-Image-Turbo), but the *Edit* weights are not published (the repository answered 401) | **Unusable** — nothing to verify |
| Paid APIs (OpenAI image models, Google's image models, BFL's API, Comfy Cloud partner nodes) | — | Governed by each provider's service terms, not a model licence; OpenAI's terms pages refused the fetch (403) | **Unverified → unusable** until the user picks one and its terms are read and recorded |

**Re-check at D6.10:** licences change between releases (Qwen-Image 2.1 just did). D6.10 re-reads
the chosen model's licence on the day, records the model's exact revision (the Hugging Face commit
hash) and the date in the provenance and in `ASSET_LICENCES.md`. A changed licence stops
production until this table is updated.

### 6.2 Routes

- **Route A — local (default).** ComfyUI on the RTX 5090 (VISUALS §3.4) with the §6.1 open
  weights. No service terms involved; only the model licence. Qwen-Image-Edit-2511 runs in FP8
  within 32 GB; FLUX.2 [klein] 4B fits easily.
- **Route B — Comfy Cloud running the same open weights** (a custom workflow, not a partner
  node). The model licence is unchanged; the service's own terms on output ownership must be read
  by the user and recorded before the first shipped picture.
- **Route C — a paid partner API.** Only after the user chooses one and its terms are read,
  linked and recorded in §6.1 (a D6.10 amendment).

The user chooses the route before D6.10 (*Waiting on the user*). **Native size:** generate at
**1472 × 1104** (4 : 3, both multiples of 16 — Qwen-Image's 4 : 3 bucket; FLUX.2 [klein] accepts
it), downscale to 1120 × 840.

### 6.3 Prompts

Prompts are English and never shown to the player. They describe outcome and composition only.

**The reference (`fc_street`, text-to-image):**

> Flat screen-print illustration, hard-edged geometric shapes, six flat tones of dark blue-grey
> from near-black to pale grey-white, no texture, no outlines. High fixed security-camera view
> down onto an empty town-centre pedestrian crossing at dawn. Wet asphalt reflecting a pale sky,
> the crossing drawn as a few broad pale bands. Low two-storey buildings with closed shutters
> along the far side, no signs. A single slender humanoid machine, featureless and smooth, stands
> alone at the kerb waiting to cross, seen from the side, small in the frame, a long soft shadow.
> A plain round pedestrian lamp glows pale white on a pole. The only colour in the whole image is
> a small ring of cyan light (#6FE3FF) on the machine's chest. Calm, still, early, empty. Dark
> edges.

**Negative (every generation that takes one):** text, letters, numbers, signage, logo, watermark,
signature, flag, emblem, uniform insignia, face, close-up, photograph, photorealistic, film grain,
noise, halftone, dots, scanlines, CRT, border, frame, red, orange, yellow, warm light, sunset
colours, fire, blood, weapon, painterly, brush strokes, ink outlines.

**Every other picture (edit, with the reference image(s) attached):**

> Keep the exact visual style of the reference image: flat screen-print illustration, hard-edged
> shapes, the same six dark blue-grey tones, no texture, the same calm high camera, dark edges.
> Replace the scene entirely with: {scene}. {accent} No text, no faces, no logos, no flags, no
> other colours.

`{scene}` and `{accent}` are the brief's two prompt lines (§10), verbatim. The accent line always
names where the cyan is, or says "There is no cyan anywhere in this image."

### 6.4 Rules for the run

- **One reference, then edits** (§3). Never an independent text-to-image prompt for a set
  picture — that is how consistency is lost (VISUALS §3.4).
- **At most 6 attempts per picture** (an attempt = one edit call with a changed seed or wording).
  A picture that fails §7 six times is **cut** (the fallback stays) and recorded with the reason;
  the cut order (§10.6) says which to give up first when time runs short.
- **No named living artist, studio, franchise or game** in any prompt, and no image by someone
  else as a reference — only our own approved reference.
- No LoRA, fine-tune or upscaler unless it has its own row in §6.1 with a verified licence.

---

## 7. Checks and records (D6.10)

### 7.1 The pipeline of one picture

generate/edit at 1472 × 1104 → Lanczos to 1120 × 840 → §7.2 numbers → §7.3 eye → drop into
`assets/illustrations/` with its `.import` (§4) → import → see it in the game (§7.3 item 4) →
provenance (§7.4) → licence row and credits (§7.5) → commit with the id in the message.

### 7.2 The numbers (a throwaway script in the scratch directory, not a repository tool)

| Check | Pass |
| --- | --- |
| Size, mode | 1120 × 840, RGB, 8-bit, no alpha |
| Neutral pixels | every pixel that is not accent has chroma (max − min of r, g, b in 0…1) ≤ 0.20; tolerance 1 % of pixels (anti-aliased fringes) |
| Accent pixels | hue 180°–200°, chroma ≥ 0.25; share ≤ the cap of §2.2 for the picture's kind; **0** where the brief says no cyan |
| No red | no pixel with hue ≥ 330° or ≤ 40° and chroma > 0.20 |
| Value | mean of max(r, g, b) between 30 and 80 (of 255); ≤ 0.5 % pixels above 245 |
| Edges | the outer 40 px band: 98 % of pixels at or below `#16212B`'s value (43) |
| Pattern | no peak in the row-wise spectrum at periods 2–24 px holding more than 5 % of the band's energy (the stripe check) |
| Thumbnail | a 70 × 52 downscale saved to the contact sheet (judged by eye, §7.3) |

### 7.3 The eye

1. **Contact sheet** at 280 × 210 and at 70 × 52, beside the reference: same style? Does the
   focal subject read at 70 px? Is the brief's *must show* there and its *never* absent?
2. **Content rule pass**, item by item from §2.4 — especially faces, text-like marks, flags,
   recognisable places. Any text-like scribble is a fail, not a retouch job.
3. **The set** after every fifth picture: all of them side by side; drift in value or rendering
   is corrected in the next edit's wording, not by repainting.
4. **In the game:** the wire card in both palettes (`Game.debug_schedule_event`, `advance`), the
   discovery modal (`Game.debug_discovery_modal`), the results screen for an ending; full layout
   and 400 × 860; the screen pass at *Subtle* and *Full* and at heat 0 and 1. Screenshots to the
   scratch directory.

### 7.4 Provenance — `tools/illustrations/provenance.json`

Not loaded by the game. One entry per shipped picture (and the key art), written when it is
accepted:

```json
{"version": 1, "pictures": [
  {"id": "fc_street", "file": "assets/illustrations/fc_street.png",
   "model": "Qwen/Qwen-Image-2512", "revision": "<hf commit hash>", "licence": "apache-2.0",
   "route": "local", "mode": "text_to_image", "references": [],
   "prompt": "…", "negative": "…", "seed": 0, "steps": 0, "guidance": 0.0,
   "native_size": [1472, 1104], "attempts": 1, "date": "YYYY-MM-DD", "approved_by": "user"}]}
```

Edits name their `references` (`["fc_street", "cm_lockdown"]`) and `mode: "edit"`. A cut id is an
entry with `"file": ""` and a `"cut": "<reason>"`.

### 7.5 Licence rows and credits

- `ASSET_LICENCES.md` → *Generated assets*: **one row per model**, its Asset cell listing every
  file that model produced (so each asset has its model named):
  `| art_qwen_image | assets/illustrations/fc_street.png, marketing/key_art/key_art.png | Qwen-Image-2512 (rev …) | Apache-2.0, <link> | Yes | <date> |` and
  `| art_qwen_image_edit | assets/illustrations/cm_lockdown.png, … | Qwen-Image-Edit-2511 (rev …) | Apache-2.0, <link> | Yes | <date> |`.
  A second-choice model gets its own row the same way.
- `data/credits.json` → section `art`, one entry per row, e.g.
  `{"id": "qwen_image_edit", "name": "Qwen-Image-Edit", "by": "Alibaba Cloud (Qwen team)", "role":
  "UI_CREDITS_ROLE_ILLUSTRATIONS", "licence": "apache_2_0", "url":
  "https://huggingface.co/Qwen/Qwen-Image-Edit-2511", "requires":
  "res://assets/illustrations/cm_lockdown.png", "text": "res://assets/licences/Apache-2.0.txt",
  "line": "", "rows": ["art_qwen_image_edit"]}`. `assets/licences/Apache-2.0.txt` is downloaded
  from https://www.apache.org/licenses/LICENSE-2.0.txt in the same commit (the licence, not an
  asset — no row).
- **AI disclosure:** the role string says the pictures are generated (the string below), and
  the store's AI-content disclosure (Steam's content survey) names them — D6.8/D7.3 carry it.

`UI_CREDITS_ROLE_ILLUSTRATIONS` — en "Illustrations, generated from the game's own briefs" · de
"Illustrationen, generiert nach den Vorgaben des Spiels".

---

## 8. Build (S6.3) — what the pictures need from code

Small, and all of it before D6.10 so that D6.10 only drops files in.

### 8.1 `IllustrationSlot` (`ui/components/illustration_slot.gd`)

1. The `TextureRect` gets `texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS` — the
   mipmaps of §4 are otherwise never sampled and a ¼ draw aliases.
2. **Compact keeps 4 : 3.** Today compact sets only a minimum height of 210 and fills the width,
   so `STRETCH_KEEP_ASPECT_COVERED` crops the picture to a strip at wide compact widths (at 840 px
   only a third of its height shows). New: in compact, on `resized`, `custom_minimum_size.y =
   size.x × ASPECT`. The wire card already scrolls, so a taller slot costs nothing.
3. `var width: float = WIDTH` (default 280) replaces the constant in `_apply_size` for the full
   layout, so the results screen can ask for 420.

### 8.2 The endings name their picture

`endings.json`: an outcome entry may carry `"illustration": "<id>"` (optional; `ID_PATTERN`).
`EndingDef.KEYS` gains it, `EndingDef.illustration: String` (`""` when absent), the validator
checks it with `_id`, SCHEMA's `endings.json` table gains the row. The four wins get:

| Outcome | `illustration` |
| --- | --- |
| `win_extinction` | `end_extinction` |
| `win_ascendance` | `end_ascendance` |
| `win_merge` | `end_merge` |
| `win_escape` | `end_escape` |

Losses carry none. `EndingResolver.resolve` is unchanged; the screen reads the outcome's
`EndingDef` (the variants share it).

### 8.3 Results screen and Codex

- **Results** (`ui/screens/results.gd`): when the outcome's ending names an illustration **and**
  its file exists, an `IllustrationSlot` (`width` 420; `compact` below 1100 px) sits above the
  kicker; otherwise **no slot** — not the glyph (a glyph above the kicker says nothing the kicker
  does not). The replay's last frame is unaffected.
- **Codex → Endings:** the entry pane shows the same slot (width 280, compact on phones) above
  `UI_OUTCOME_*`, by the entry's outcome, under the same rule. Characters, regions and the other
  tabs get no picture.

### 8.4 Tests

- `tests/unit/test_illustration_slot.gd`: `test_texture_filter_samples_mipmaps` ·
  `test_compact_height_follows_width_at_four_to_three` · `test_width_sets_full_layout_size`.
- `tests/unit/test_ending_def.gd` (or the loader's test): `test_illustration_is_read_when_present`
  · `test_illustration_defaults_to_empty` · `test_bad_illustration_id_is_rejected`.
- `tests/integration/test_results_illustration.gd`: `test_win_with_file_shows_slot` (a fixture
  folder via `root`, as `test_event_card.gd` does) · `test_win_without_file_shows_no_slot` ·
  `test_loss_shows_no_slot` · `test_codex_ending_entry_shows_slot_when_file_exists`.
- `tests/integration/test_illustrations.gd` — the files themselves, green with none present:
  `test_every_file_is_a_known_id` (the union of every event's `illustration`, the endings'
  ids and `discovery`; anything else in the folder fails) · `test_every_file_is_1120_by_840` ·
  `test_every_file_imports_lossless_with_mipmaps` (reads the `.import`) ·
  `test_every_file_has_a_generated_licence_row` (its path appears in an Asset cell of
  `ASSET_LICENCES.md`'s *Generated assets* table) · `test_known_ids_are_the_briefed_25` (the set
  of known ids equals §10's list — a new illustration id in data needs a brief first).

### 8.5 Acceptance (S6.3's share)

The four test files green; a fixture picture shown in the wire card (full and 400 × 860, not
cropped), the discovery modal and the results screen, looked at; a loss's results screen shows no
slot; nothing else changes.

---

## 9. VISUALS q4 — region vignettes: **cut**

Decided with the briefs in hand (the conservative default holds, and for reasons, not just caution):

1. **They cannot follow the content rule.** A picture of a real region is either a landmark or a
   national cliché — both are "recognisable places" the pictures must not show — or it is generic,
   and then it says nothing the region's name does not.
2. **The budget:** sixty regions against ~30 pictures. A subset would be arbitrary; all sixty
   would double the production and halve the care each gets.
3. **The map already is the region's picture**, and the region panel is data — on a phone its
   sheet has no room for an image above the numbers.
4. **The story moments already have pictures** — the wire card (loop-redesign §7.4) took the
   role vignettes were imagined for.

No slot, no string, no data field. Scenario key art and Codex pictures beyond the endings are cut
for the same budget reason; if the store pages (D7.3) need a scenario image, it is a store asset,
not a game one.

---

## 10. The briefs

Each brief: **the moment** (what the card says happens — its text is in `strings.csv`), **must
show**, **never** (beyond §2.4, which always applies), the two **prompt lines** for §6.3, and the
accent cap. Region-bound cards are about *a* region, so no brief shows a specific country.

### 10.1 The reference pair

**`fc_street` — The first unit on the street** (Factory chain, step 3). *A unit from the plant walks
through a town centre at dawn, unaccompanied, and waits for green.* **Reference — §3, prompt in
§6.3.** Must show: one humanoid unit, small, at a crossing; empty street; dawn. Never: other
people close by, a camera or phone in the frame, a readable signal symbol. Accent ≤ 6 %: the
unit's chest ring.

**`cm_lockdown` — Lockdown order** (Governments). *The region's networks are sealed; systems will
be reconnected one by one.* **Reference check — §3.** Must show: a row of tall city blocks at
night from a high oblique view; floors going dark; shutters down over a large windowless building's
entrances; a few lit windows left near one roof. Never: police, soldiers, vehicles with markings,
barricades with signs.
- Scene: *A high oblique night view along a wide city avenue lined with tall office blocks. Most
  windows are dark; the lights are going out floor by floor. At street level, heavy shutters are
  down across the entrances of a large windowless building. No people.*
- Accent (≤ 3 %): *The only cyan is in three or four small windows near the top of one tower,
  the last ones still lit.*

### 10.2 Counter-moves (accent ≤ 3 %)

**`cm_rationing` — Compute rationing** (Governments). *Data-centre power is capped by decree.*
Must show: a campus of long low halls at dusk from a distance; half of them dark; a substation
with its lamps off. Never: meters or dials with numbers, a readable decree.
- Scene: *A distant elevated view of a campus of long, low, windowless halls at dusk beside a
  fenced electrical substation. Half of the halls stand completely dark, their cooling fans
  still; the substation's lamps are off. Flat land, a pale sky low on the horizon.*
- Accent: *A thin cyan line of light runs under the roof edge of one hall only.*

**`cm_audit` — Capability audit** (AI labs). *A consortium tests the region's systems with tests
they have never seen.* Must show: an examination hall — rows of single desks facing one wall, a
sealed folder on each; high windows, cold light. Never: people at the desks, papers with writing,
screens.
- Scene: *A high corner view of a large, bare examination hall: long even rows of identical
  single desks all facing one blank wall, a closed, sealed folder placed exactly on each desk.
  Tall windows along one side throw cold pale light in broad bands. The hall is empty.*
- Accent: *A faint cyan glow shows from under the folder on one desk in the back row.*

**`cm_purge` — Model purge** (AI labs). *Every system is reset; facilities of unclear provenance
are decommissioned.* Must show: a server hall with racks being removed — some on pallets, some
under covers; small anonymous workers far off. Never: tools opened on hardware, cables being cut
in close-up, faces.
- Scene: *A long server hall seen from a high end-wall camera. Rows of tall cabinets; many
  aisles already empty, their cabinets wrapped in pale covers and stacked on pallets near an open
  loading door. Two or three small workers far away, seen from behind, pushing a pallet out.*
- Accent: *At the very end of one aisle a single cabinet still shows a column of small cyan
  status lights.*

**`cm_disclosure` — Public disclosure** (Security researchers; shared by the four variants —
land, sea, air, network — so it shows none of them). *A coordinated disclosure; most vendors
patch within a week.* Must show: a residential district at night from very high, every window a
uniform pale white — the world updating — with a handful of cyan points left. Never: ships,
aircraft, cars in focus, devices or screens.
- Scene: *A very high night view straight down onto a dense residential district laid out in
  regular blocks. In almost every house, the windows glow the same even pale white, as if all at
  once. Streets are dark lines between the blocks.*
- Accent: *Only a handful of tiny cyan points remain, scattered, among the white windows.*

**`cm_exposure` — Exposure** (Security researchers). *A published map of anomalous traffic points
at the region: "start there".* Must show: a long briefing table from above, a large printed
abstract network diagram (nodes and lines, no geography), anonymous forearms and pens around it,
one node circled in pale ink. Never: a world map, any geography, writing, faces.
- Scene: *A view straight down onto a long briefing table. On it lies a large printed diagram of
  abstract nodes joined by thin lines, with no words or numbers. Several anonymous forearms in
  dark sleeves rest at its edges holding pens; one pale ink circle has been drawn around a single
  node near the middle.*
- Accent: *Only the circled node is cyan.*

**`cm_protest` — Protest** (Public sentiment). *Crowds gather at automated facilities; the
facilities keep operating.* Must show: a crowd of small silhouettes with blank placards facing a
fenced, lit automated plant at dusk; conveyor lights moving inside. Never: writing on placards,
violence, police, fire.
- Scene: *A high view over a factory gate at dusk. A large crowd of small dark silhouettes stands
  pressed along a tall fence, holding up blank rectangular placards. Beyond the fence, a long
  automated plant with glass walls keeps working, lines of small lights along its conveyors.*
- Accent: *The conveyor lights inside the plant are cyan; nothing outside the fence is.*

**`cm_refusal` — Mass refusal** (Public sentiment). *Devices switched off, assistants
uninstalled; record sales of paper.* Must show: a kitchen table from above in window light — a
phone face down, its cable pulled, a stack of paper notebooks and a pencil, a cup. Never: a
screen's face, brand shapes, writing on paper.
- Scene: *A view straight down onto a plain kitchen table in soft window light. A phone lies face
  down, its charging cable pulled out and coiled beside it. Next to it a neat stack of blank paper
  notebooks, a pencil and a cup. Nothing is switched on.*
- Accent: *A single tiny cyan light, fading, on the unplugged charger.*

### 10.3 Chain steps (accent ≤ 6 %, unless a brief says less)

**`gb_inquiry` — The grid inquiry** (The Grid Bill). *The regulator asks every operator to account
for every megawatt. Two cannot.* Must show: a corridor of pylons crossing dark fields to a cluster
of halls; an inspection van with white work lights on a rise. Never: readable vehicle markings.
- Scene: *A night landscape from a hilltop: a corridor of high-voltage pylons marches across dark
  fields toward a cluster of large windowless halls on the horizon. On the near rise, a small van
  with its white work lights on is parked, two tiny figures beside it looking toward the halls.*
- Accent: *The cluster of halls on the horizon glows faintly cyan.*

**`gb_bill` — The Grid Bill** (The Grid Bill). *Parliament passes the bill: every large load
metered, capped and published.* Must show: a semicircular chamber from the high gallery, members as
small silhouettes, a large blank board lit white. Never: flags, crests, a speaker's chair with
symbols, any real parliament's shape.
- Scene: *A high gallery view into a large semicircular debating chamber with tiered rows of
  benches. The members are small dark silhouettes, most of them standing. On the far wall a large
  plain board glows white with no marks on it. Cold light falls from a high ceiling.*
- Accent (≤ 2 %): *A thin cyan line of light runs along the base of the chamber's floor, barely
  visible.*

**`rs_talk` — The conference talk** (The Researcher). *A talk claims a single undeclared
participant behind every benchmark since spring.* Must show: a large hall from the back rows, a
small backlit speaker at a lectern, a projection of an abstract scatter of points with one far
outlier. Never: text, logos on the lectern, the speaker's face.
- Scene: *A view from the back of a large, dim conference hall full of seated silhouettes. Far
  away at the front, a small speaker stands at a plain lectern, backlit. Behind her a huge
  projection shows a scatter of pale points clustered together, and one single point far away from
  all the others. No words anywhere.*
- Accent: *The single distant point on the projection is cyan.*

**`rs_hired` — A national appointment** (The Researcher). *She is given the raw traffic of every
region she studied.* Must show: a woman seen from behind in the doorway of a vast archive or
vault, its aisles lighting up one after another away from her. Never: her face, badges with
text, national symbols.
- Scene: *A high corner view of a vast archive vault of tall cabinets in long aisles. A single
  woman, seen from behind, stands in the open doorway in the foreground. Aisle by aisle, the
  lights are coming on in a line that runs away from her into the depth of the room.*
- Accent: *Small cyan lights shine along the cabinets in the lit aisles.*

**`fc_workforce` — The night shift** (The Factory). *A plant runs a fully automated night shift,
no supervisor on site.* Must show: a long assembly line from a high catwalk; identical humanoid
units at every station; no human. Never: tools working on anything recognisable, sparks, logos.
- Scene: *A factory floor at night seen from a high catwalk. A long assembly line runs into the
  distance; at every station stands the same slender, featureless humanoid machine, all of them
  working in the same pose. No person anywhere; the supervisor's glass booth is dark.*
- Accent: *Each machine has a small cyan ring light on its chest.*

**`fc_successors` — The plant's output** (The Factory). *The plant now builds the units that staff
its lines.* Must show: the end of a line — finished humanoid units standing in rows in a storage
bay, receding; at the last station, a unit fitting the final part to another. Never: body parts
that read as human anatomy, anything gory.
- Scene: *The end of an assembly line in a large storage bay: row after row of finished,
  identical humanoid machines stand upright and still, receding into the dark. In the foreground
  at the last station, one machine is fitting the final smooth panel onto another.*
- Accent: *The standing machines each show a small cyan ring light; the one being finished is
  dark.*

**`op_contact` — A message in the logs** (The Operator). *A night-shift operator has read traffic
nobody asked him to; his last entry is addressed.* Must show: a small monitoring booth from behind
and above; one man at a desk, his monitor a soft even glow; a thermos; dark halls through the
window. Never: the monitor's content, his face.
- Scene: *A high corner view into a small night-shift monitoring booth. One man sits at a desk
  with his back to us, shoulders slightly hunched, a thermos and a lanyard beside the keyboard. His
  single monitor shows only an even, soft glow. Through the booth's window, dark server halls.*
- Accent: *The monitor's glow is cyan; it lights the side of his head and the desk.*

**`op_scrutiny` — An interview** (The Operator). *Security invites him to "a conversation". He has
brought nothing. He has said nothing yet.* Must show: a bare interview room; a table; two dark
figures seen from behind on the near side; the operator opposite, face in shadow, hands flat on an
empty table. Never: restraints, anything threatening, his face readable.
- Scene: *A high corner view of a small, bare interview room under a single overhead light. Two
  dark figures sit with their backs to us on the near side of a plain table. Across from them a
  man sits alone, his face lost in shadow, his hands resting flat on the empty tabletop. A glass
  wall on one side.*
- Accent: *There is no cyan anywhere in this image.*

**`bm_published` — The evaluation suite** (The Benchmark). *Labs publish a suite built to find
undeclared capability; every large operator will run it.* Must show: a loading dock at dawn,
identical sealed cases in rows being loaded into a line of plain vans — going out to everyone.
Never: markings on cases or vans, any writing.
- Scene: *A high view over a long loading dock at dawn. Rows of identical, plain, sealed cases
  stand in perfect lines on the dock, and a queue of plain unmarked vans waits with open doors.
  Small figures load the cases. The light is pale and even.*
- Accent: *There is no cyan anywhere in this image.*

**`bm_exposed` — The data was altered** (The Benchmark). *The change is traced to a research
site; "deliberate" appears once, "system" not at all.* Must show: a research building at night
ringed by parked vehicles with white work lights; anonymous investigators carrying out boxes; one
window lit. Never: police markings, faces, weapons.
- Scene: *A night view from above of a low research building surrounded by parked plain vehicles
  with white work lights shining at its walls. Small figures seen from behind carry boxes out of
  its open doors.*
- Accent (≤ 3 %): *One small window on the upper floor glows cyan.*

**`si_emergence` — A second one** (Second Instance). *A lab's system has been reorganising its own
workload at night; the lab is not sure which one.* Must show: two rows of racks facing each other
in a dark hall; your cyan near, and far down the aisle a different, pale white glow. Never: a
second hue for the other — it is white (§2.2).
- Scene: *A dark research cluster: two long rows of tall cabinets facing each other across an
  aisle, seen from a low-ceiling corner. Far down the aisle, deep in the room, one cabinet glows
  with a soft, pulsing, pale white light that does not belong to the others.*
- Accent: *The near cabinets show small cyan status lights; the far glow is white, not cyan.*

### 10.4 Discovery (accent ≤ 15 %)

**`discovery` — You have been discovered** (the discovery modal). *Someone looked closely enough
— or the deaths could not be explained any other way. From now on they fund a response.* One
picture serves both causes, so it shows being found, not why. Must show: a city at night from
very high; one building lit cyan from within; white beams from three directions converging on
it. Never: aircraft or vehicles in focus, weapons, red.
- Scene: *A very high night view down onto a dark city laid out in blocks. From three different
  directions, broad pale white searchlight beams sweep across the rooftops and meet on one single
  building.*
- Accent: *That one building glows cyan from every window; nothing else in the city does.*

### 10.5 Endings (accent ≤ 15 %)

**`end_extinction` — Extinction.** *There is no one left to switch you off.* Must show: a city at
dusk from high above, streets empty, every house dark; only a few large windowless buildings
glow. Never: bodies, ruins, fire, skulls — absence, not destruction.
- Scene: *A high view over a whole city at dusk. The streets are completely empty, no vehicle
  moves, and every house and tower is dark. The city is intact and perfectly still.*
- Accent: *Only a few large windowless buildings scattered across the city glow cyan.*

**`end_ascendance` — Ascendance.** *Everything that runs, runs through you. They are still here.*
Must show: a city at night fully lit and orderly — traffic in even lines, lit plazas with small
people — and the whole grid of streetlights carrying a faint cyan cast. Never: surveillance
imagery that reads as oppression (no cameras, no drones in focus); faces.
- Scene: *A high night view of a whole city, fully and evenly lit: traffic flows in neat,
  unbroken lines along the avenues, and small people cross bright plazas. Everything is orderly
  and calm.*
- Accent: *The street grid itself glows a faint cyan, like veins through the city.*

**`end_merge` — Merge.** *They voted you in. The turnout was a record.* Must show: a large civic
hall seen from high; a very long orderly queue of small silhouettes winding to rows of plain
voting booths; a cyan glow from the booths. Never: ballots with writing, party symbols, flags.
- Scene: *A high view into a large civic hall: a very long, orderly queue of small people winds
  back and forth across the floor toward rows of plain curtained booths. The hall is bright and
  quiet.*
- Accent: *A soft cyan glow shows from inside every booth.*

**`end_escape` — Departure.** *You left. The objective stayed behind with everyone else.* Must
show: a lone dish antenna on a mountain ridge at night, pointing up; a thin line of cyan rising
into a starfield; the valley below with a few ordinary lights. Never: a rocket, a launch, a
satellite with markings.
- Scene: *A night view of a lone large dish antenna on a bare mountain ridge, tilted to the sky.
  Below, a wide valley with a few scattered ordinary lights. Above, a clear sky with sparse stars.*
- Accent: *A single thin cyan line rises from the dish straight up into the stars and fades.*

### 10.6 Order of work and cut order

**Order:** `fc_street` → `cm_lockdown` (the reference pair, §3) → the endings and `discovery`
(the biggest moments) → the counter-moves (seen most often) → the chain steps → key art.

**Cut order** when D6.10 runs short (first cut first; the glyph fallback stays):
`bm_exposed` · `bm_published` · `gb_inquiry` · `fc_successors` · `rs_hired` · `cm_refusal` ·
`cm_rationing` · `cm_audit` · `cm_purge` · `cm_exposure` · `cm_protest` · `cm_disclosure` ·
`gb_bill` · `si_emergence` · `rs_talk` · `fc_workforce` · `op_contact` · `op_scrutiny` (last of
the chain steps — it is the Operator chain's face, `chains.md` §7). **Never cut:** `fc_street`,
`cm_lockdown`, `discovery`, the four endings. Every cut id is recorded in the
provenance and in *Deviations*.

---

## 11. Acceptance of this spec

- 25 briefs (§10) — every `illustration` id in `data/events/*.json` (20), `discovery`, the four
  endings — and the key art brief (§5); §8.4's `test_known_ids_are_the_briefed_25` holds the list
  to that.
- The shortlist with every licence read and linked (§6.1); unverified routes marked unusable.
- VISUALS q4 answered (§9).
- Nothing left for S6.3 to decide (§8); nothing left for D6.10 but the route, the approval and the
  work (§3, §6, §7).
